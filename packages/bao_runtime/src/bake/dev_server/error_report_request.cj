// 翻译自 Bun: src/runtime/bake/DevServer/ErrorReportRequest.zig
// 当客户端发生错误时获取。执行两个操作：
// - 将重映射的堆栈跟踪记录到控制台
// - 回复重映射的堆栈跟踪

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
        let ctx = ErrorReportRequest(dev, BodyReaderMixin<ErrorReportRequest>(dev.allocator()))
        // ctx.dev.server.getOrThrow().onPendingRequest()
        ctx.body.readBody(resp)
    }

    /// 最终化
    public func finalize(): Unit {
        // dev.server.getOrThrow().onStaticRequestComplete()
    }

    /// 带请求体运行
    public func runWithBody(body: Array<Byte>, r: AnyResponse): Unit {
        // 简化实现：解析错误报告并重新映射堆栈跟踪
    }

    /// 解析源 URL 中的 ID
    public static func parseId(source_url: String, browser_url: String): ?UInt64 {
        if (!source_url.startsWith(browser_url)) {
            return None
        }
        let after_host_start = StringsHelper.withoutTrailingSlash(browser_url).size
        if (after_host_start >= source_url.size) { return None }
        let after_host = source_url[after_host_start..]
        if (!after_host.startsWith(CLIENT_PREFIX + "/")) {
            return None
        }
        let after_prefix_start = CLIENT_PREFIX.size + 1
        if (after_prefix_start >= after_host.size) { return None }
        let after_prefix = after_host[after_prefix_start..]
        if (!after_host.endsWith(".js")) {
            return None
        }
        let min_len = "00000000FFFFFFFF.js".size
        if (after_host.size < min_len) {
            return None
        }
        // 简化：不实际解析十六进制
        return None
    }
}
