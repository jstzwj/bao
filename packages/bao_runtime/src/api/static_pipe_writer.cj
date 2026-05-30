// 翻译自: src/runtime/api/bun/subprocess/StaticPipeWriter.zig
//   StaticPipeWriter — 静态管道写入器
//   将 blob/array_buffer 数据一次性写入子进程 stdin
package bao_runtime.api

import bao_io.WriteStatus
import bao_sys.*

// ============================================================================
// StaticPipeWriterSource — 数据源
// 翻译自: src/runtime/api/bun/subprocess/StaticPipeWriter.zig Source 类型
//   pub const Source = union(enum) { blob, array_buffer, detached }
// ============================================================================

public enum StaticPipeWriterSource {
    | blob(BlobAny)
    | arrayBuffer(ArrayBufferStrong)

    /// 获取字节切片
    /// 翻译自: Source.slice()
    ///   pub fn slice(this: *const Source) -> []const u8
    public func slice(): String {
        match (this) {
            case blob(b) =>
                let bytes = b.slice()
                // 将字节数组转为字符串
                var s = ""
                for (b in bytes) {
                    s += String(Rune(Int32(b)))
                }
                return s
            case arrayBuffer(ab) =>
                let bytes = ab.byteSlice()
                var s = ""
                for (b in bytes) {
                    s += String(Rune(Int32(b)))
                }
                return s
        }
    }

    /// 分离 (释放底层数据)
    /// 翻译自: Source.detach()
    ///   pub fn detach(this: *@This()) -> void
    public func detach(): Unit {
        match (this) {
            case blob(b) => b.detach()
            case arrayBuffer(ab) => ab.deinit()
        }
    }

    /// 内存占用
    /// 翻译自: Source.memoryCost()
    ///   pub fn memoryCost(this: *const Source) -> usize
    public func memoryCost(): Int {
        match (this) {
            case blob(b) => 256  // blob 内存由 GC 管理
            case arrayBuffer(_) => 0  // ArrayBuffer 由 GC 管理
        }
    }
}

// ============================================================================
// StaticPipeWriter — 静态管道写入器
// 翻译自: src/runtime/api/bun/subprocess/StaticPipeWriter.zig:1-131
//   pub fn NewStaticPipeWriter(comptime ProcessType: type) type
//   将 blob/array_buffer 数据一次性写入子进程 stdin 的 fd
// ============================================================================

public class StaticPipeWriter {
    public var stdioResult: StdioResult = StdioResult.unavailable
    public var process: ?Subprocess = None
    public var eventLoop: EventLoop = EventLoop()
    public var buffer: String = ""
    private var source: StaticPipeWriterSource = StaticPipeWriterSource.blob(BlobAny())

    public init() {}

    /// 创建 StaticPipeWriter
    /// 翻译自: StaticPipeWriter.create()
    ///   pub fn create(event_loop, subprocess, result, source) -> *This
    public static func create(eventLoop!: EventLoop, subprocess!: Subprocess, result!: StdioResult, source!: StaticPipeWriterSource): StaticPipeWriter {
        let writer = StaticPipeWriter()
        writer.eventLoop = eventLoop
        writer.process = Some(subprocess)
        writer.stdioResult = result
        writer.source = source
        writer.buffer = source.slice()
        writer
    }

    /// 开始写入
    /// 翻译自: StaticPipeWriter.start()
    ///   pub fn start(this: *This) -> bun.sys.Maybe(void)
    public func start(): Maybe<Unit> {
        // 引用自身以防止过早释放
        // TODO(bao-runtime-api): 启动 IO writer
        //   1. this.ref()
        //   2. this.buffer = this.source.slice()
        //   3. this.writer.start(this.stdio_result.?, true)
        SysMaybe<Unit>.Ok(())
    }

    /// 写入完成回调
    /// 翻译自: StaticPipeWriter.onWrite()
    ///   pub fn onWrite(this: *This, amount: usize, status: WriteStatus) -> void
    public func onWrite(amount!: Int, status!: WriteStatus): Unit {
        // 移除已写入的字节
        if (amount >= 0 && amount <= buffer.size) {
            buffer = buffer[amount..buffer.size]
        }
        // 全部写完或 EOF
        if (status == WriteStatus.EndOfFile || buffer.size == 0) {
            close()
        }
    }

    /// 错误回调
    /// 翻译自: StaticPipeWriter.onError()
    ///   pub fn onError(this: *This, err: bun.sys.Error) -> void
    public func onError(err!: SysError): Unit {
        // 分离数据源以释放内存
        source.detach()
    }

    /// 关闭回调
    /// 翻译自: StaticPipeWriter.onClose()
    ///   pub fn onClose(this: *This) -> void
    public func onClose(): Unit {
        // 分离数据源
        source.detach()
        // 通知子进程 stdin 已关闭
        match (process) {
            case Some(proc) => proc.onCloseIO(kind: ApiStdioKind.apiStdin)
            case None => ()
        }
    }

    /// 获取待写入的缓冲区
    /// 翻译自: StaticPipeWriter.getBuffer()
    ///   pub fn getBuffer(this: *This) -> []const u8
    public func getBuffer(): String { buffer }

    /// 关闭写入器
    /// 翻译自: StaticPipeWriter.close()
    ///   pub fn close(this: *This) -> void
    public func close(): Unit {
        // TODO(bao-runtime-api): 调用 writer.close()
    }

    /// 刷新缓冲区
    /// 翻译自: StaticPipeWriter.flush()
    ///   pub fn flush(this: *This) -> void
    public func flush(): Unit {
        if (buffer.size > 0) {
            // TODO(bao-runtime-api): 调用 writer.write()
        }
    }

    /// 注册 poll 监控
    /// 翻译自: StaticPipeWriter.watch()
    ///   pub fn watch(this: *This) -> void
    public func watch(): Unit {
        if (buffer.size > 0) {
            // TODO(bao-runtime-api): 调用 writer.watch()
        }
    }

    /// 更新引用
    /// 翻译自: StaticPipeWriter.updateRef()
    ///   pub fn updateRef(this: *This, add: bool) -> void
    public func updateRef(add!: Bool): Unit {
        // TODO(bao-runtime-api): 调用 writer.updateRef(event_loop, add)
    }

    /// 内存占用
    /// 翻译自: StaticPipeWriter.memoryCost()
    ///   pub fn memoryCost(this: *const This) -> usize
    public func memoryCost(): Int {
        return 256 + source.memoryCost() + buffer.size
    }

    /// 释放资源
    /// 翻译自: StaticPipeWriter._deinit()
    ///   fn _deinit(this: *This) -> void
    public func deinit(): Unit {
        // TODO(bao-runtime-api): 调用 writer.end()
        source.detach()
    }

    /// 引用
    /// 翻译自: StaticPipeWriter.ref()
    public func ref(): Unit {}

    /// 取消引用
    /// 翻译自: StaticPipeWriter.deref()
    public func deref(): Unit {}
}
