// 严格翻译自: src/runtime/api/bun/subprocess/StaticPipeWriter.zig
package bao_runtime

import bao_jsc.*
import bao_core.*
import bao_io.*
import bao_sys.*

// ============================================================================
// StaticPipeWriter - 静态管道写入器 (用于子进程 stdin)
// 对应 Bun: src/runtime/api/bun/subprocess/StaticPipeWriter.zig
// ============================================================================

/// NewStaticPipeWriter - 为指定进程类型创建静态管道写入器
/// 用于将静态数据写入子进程的 stdin
public class StaticPipeWriter<ProcessType> {
    public var refCount: WriterRefCount
    public var writer: IOWriter
    public var stdioResult: StdioResult
    public var source: Source
    public var process: ProcessType
    public var eventLoop: EventLoopHandle
    public var buffer: String

    // ========================================================================
    // 创建和启动
    // ========================================================================

    /// 创建 StaticPipeWriter
    public static func create(eventLoop: EventLoop, subprocess: ProcessType, result: StdioResult, source: Source): StaticPipeWriter {
        let writer = StaticPipeWriter(
            refCount: RefCount.init(),
            eventLoop: EventLoopHandle.init(eventLoop),
            process: subprocess,
            stdioResult: result,
            source: source,
        )
        writer.writer.setParent(writer)
        return writer
    }

    /// 启动写入器
    public func start(): Maybe<Unit> {
        ref()
        buffer = source.slice()
        if (Environment.isWindows) {
            return writer.startWithCurrentPipe()
        }
        match (writer.start(stdioResult, true)) {
            case .err(let err) => return Maybe<Unit>.err(err)
            case .result =>
                if (Environment.isPosix) {
                    writer.handle.poll.flags.insert(.nonblocking)
                }
                return Maybe<Unit>.success
        }
    }

    // ========================================================================
    // IOWriter 回调
    // ========================================================================

    /// onWrite - 写入完成回调
    public func onWrite(amount: Int, status: WriteStatus): Unit {
        buffer = buffer.substring(min(amount, buffer.count))
        if (status == .endOfFile || buffer.count == 0) {
            writer.close()
        }
    }

    /// onError - 错误回调
    public func onError(err: SysError): Unit {
        source.detach()
    }

    /// onClose - 关闭回调
    public func onClose(): Unit {
        source.detach()
        process.onCloseIO(.stdin)
    }

    /// getBuffer - 获取当前缓冲区
    public func getBuffer(): String {
        return buffer
    }

    /// close - 关闭写入器
    public func close(): Unit {
        writer.close()
    }

    /// flush - 刷新缓冲区
    public func flush(): Unit {
        if (buffer.count > 0) {
            writer.write()
        }
    }

    /// watch - 监视可写事件
    public func watch(): Unit {
        if (buffer.count > 0) {
            writer.watch()
        }
    }

    /// updateRef - 更新引用
    public func updateRef(add: Bool): Unit {
        writer.updateRef(eventLoop, add)
    }

    /// memoryCost - 内存开销
    public func memoryCost(): Int {
        return sizeof(StaticPipeWriter) + source.memoryCost() + writer.memoryCost()
    }

    /// deinit - 内部释放
    public func deinit(): Unit {
        writer.end()
        source.detach()
        destroy(this)
    }

    /// ref - 增加引用
    public func ref(): Unit {
        refCount.ref()
    }

    /// deref - 减少引用
    public func deref(): Unit {
        refCount.deref()
    }
}
