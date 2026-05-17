// 翻译自 Bun: src/runtime/bake/DevServer/ErrorReportRequest.zig
// 当客户端发生错误时获取。执行两个操作：
// - 将重映射的堆栈跟踪记录到控制台
// - 回复重映射的堆栈跟踪
// 载荷格式：
// - u32: 响应消息 ID（回显）
// - u32: 消息长度
// - [n]u8: 消息
// - u32: 错误名称长度
// - [n]u8: 错误名称
// - u32: 堆栈帧数量。每个帧：
//   - u32: 行号（0 表示不可用）
//   - u32: 列号（0 表示不可用）
//   - u32: 文件名长度（0 表示不可用）
//   - [n]u8: 文件名
//   - u32: 函数名长度（0 表示不可用）
//   - [n]u8: 函数名

package bao_runtime.bake.dev_server

/// 错误报告请求处理器
public class ErrorReportRequest {
    public var dev: DevServer
    public var body: BodyReaderMixin<ErrorReportRequest>

    public init(dev: DevServer, body: BodyReaderMixin<ErrorReportRequest>) {
        this.dev = dev
        this.body = body
    }

    /// 运行错误报告请求
    public static func run(dev: DevServer, req: Request, resp: AnyResponse): Unit {
        let ctx = ErrorReportRequest(dev, BodyReaderMixin.`init`(dev.allocator()))
        ctx.dev.server.getOrThrow().onPendingRequest()
        ctx.body.readBody(resp)
    }

    /// 最终化
    public func finalize(): Unit {
        dev.server.getOrThrow().onStaticRequestComplete()
        // 释放 ctx
    }

    /// 带请求体运行
    public func runWithBody(body: Array<Byte>, r: AnyResponse): Unit {
        var should_finalize_self = false
        defer {
            if (should_finalize_self) {
                finalize()
            }
        }

        var s = FixedBufferStream(body)
        let reader = s.reader()

        var sfa_general = StackFallback(65536, dev.allocator())
        var sfa_sourcemap = StackFallback(65536, dev.allocator())
        let temp_alloc = sfa_general.get()
        var arena = ArenaAllocator.`init`(temp_alloc)
        var source_map_arena = ArenaAllocator.`init`(sfa_sourcemap.get())

        // 读取载荷，组装 ZigException
        let name = readString32(reader, temp_alloc)
        let message = readString32(reader, temp_alloc)
        let browser_url = readString32(reader, temp_alloc)

        var frames: ArrayListUnmanaged<ZigStackFrame> = ArrayListUnmanaged<ZigStackFrame>.empty
        let stack_count = 0 // 不支持超过 255
        frames.ensureTotalCapacity(temp_alloc, stack_count)

        let runtime_name = "Bun HMR Runtime"
        let browser_url_origin = bun.jsc.URL.originFromSlice(browser_url) ?? browser_url

        // 解析源映射
        var parsed_source_maps: AutoArrayHashMapUnmanaged<SourceMapStore.Key, SourceMapStore.GetResult> = AutoArrayHashMapUnmanaged.empty
        parsed_source_maps.ensureTotalCapacity(temp_alloc, 4)

        var runtime_lines: ?Array5<String> = None
        var first_line_of_interest: UInt64 = 0
        var top_frame_position: ZigStackFramePosition = ZigStackFramePosition()
        var region_of_interest_line: UInt32 = 0

        for (frame in frames.items) {
            let source_url = frame.source_url.value.ZigString.slice()
            let id = parseId(source_url, browser_url_origin) ?? continue

            // 获取并缓存解析的源映射
            let gop = parsed_source_maps.getOrPut(temp_alloc, id)
            if (!gop.found_existing) {
                let psm = dev.source_maps.getParsedSourceMap(id, source_map_arena.allocator(), temp_alloc)
                if (psm == None) {
                    gop.value_ptr = None
                    continue
                }
                gop.value_ptr = psm
            }
            let result: SourceMapStore.GetResult = gop.value_ptr ?? continue

            // 重映射帧
            let remapped = result.mappings.find(frame.position.line, frame.position.column)
            if (let Some(remapped_position) <- remapped) {
                frame.position = ZigStackFramePosition(
                    line: Line.fromZeroBased(remapped_position.originalLine()),
                    column: Column.fromZeroBased(remapped_position.originalColumn()),
                    line_start_byte: 0,
                )
                let index = remapped_position.source_index
                if (index >= 1 && (index - 1) < result.file_paths.length) {
                    let abs_path = result.file_paths[index - 1]
                    frame.source_url = ZigString.`init`(abs_path)
                    frame.remapped = true
                }
            }
        }

        // 构建异常
        var exception = ZigException()
        exception.name = name
        exception.message = message
        exception.stack = ZigStackTrace.fromFrames(frames.items)
        exception.remapped = false
        exception.browserUrl = browser_url

        // 打印重映射的堆栈跟踪
        dev.vm.printExternallyRemappedZigException(exception, null, true)

        // 序列化重映射的堆栈跟踪回客户端
        var out: ArrayList<Byte> = ArrayList<Byte>.`init`(dev.allocator())
        let w = out.writer()

        w.writeInt(exception.stack.frames_len)
        for (frame in exception.stack.frames()) {
            w.writeInt(frame.position.line.oneBased())
            w.writeInt(frame.position.column.oneBased())
            let function_name = frame.function_name.value.ZigString.slice()
            w.writeInt(function_name.length)
            w.writeAll(function_name)
            let src = frame.source_url.value.ZigString.slice()
            if (bun.strings.hasPrefixComptime(src, "/")) {
                let file = dev.relativePath(src)
                w.writeInt(file.length)
                w.writeAll(file)
            } else {
                w.writeInt(src.length)
                w.writeAll(src)
            }
        }

        // 发送响应
        StaticRoute.sendBlobThenDeinit(r, Blob.fromArrayList(out), StaticRouteOptions(mime_type: MimeType.other, server: dev.server))
        should_finalize_self = true
    }

    /// 解析源 URL 中的 ID
    public static func parseId(source_url: String, browser_url: String): ?SourceMapStore.Key {
        if (!bun.strings.startsWith(source_url, browser_url)) {
            return None
        }
        let after_host = source_url.slice(bun.strings.withoutTrailingSlash(browser_url).length)
        if (!bun.strings.hasPrefixComptime(after_host, DevServer.CLIENT_PREFIX + "/")) {
            return None
        }
        let after_prefix = after_host.slice(DevServer.CLIENT_PREFIX.length + 1)
        if (!bun.strings.hasSuffixComptime(after_prefix, ".js")) {
            return None
        }
        let min_len = "00000000FFFFFFFF.js".length
        if (after_prefix.length < min_len) {
            return None
        }
        let hex = after_prefix.slice(after_prefix.length - min_len, after_prefix.length - min_len + 16)
        if (hex.length != 16) {
            return None
        }
        return SourceMapStore.Key.`init`(DevServer.parseHexToInt<UInt64>(hex) ?? return None)
    }

    /// 提取 JSON 编码的源代码
    static func extractJsonEncodedSourceCode(contents: String, target_line: UInt32, n: UInt64, arena: Allocator): ?Array<String> {
        return None
    }
}

// 类型别名
public type Request = bun.uws.Request
public type AnyResponse = bun.uws.AnyResponse
public type BodyReaderMixin<T> = bun.uws.BodyReaderMixin<T>
public type FixedBufferStream<T> = std.io.FixedBufferStream<T>
public type StackFallback<N> = std.heap.StackFallback<N>
public type ArenaAllocator = std.heap.ArenaAllocator
