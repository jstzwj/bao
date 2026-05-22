// 严格翻译自: src/runtime/api/bun/subprocess/Readable.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_sys.*
import bao_io.*

// ============================================================================
// Readable - 子进程可读流 (stdout/stderr)
// 对应 Bun: src/runtime/api/bun/subprocess/Readable.zig
// ============================================================================

/// Readable 表示子进程的可读输出流
public enum Readable {
    | else
}
    }

    /// 是否有待处理活动
    public func hasPendingActivity(): Bool {
        return match (this) {
            case pipe => this.pipe.hasPendingActivity()
            else => false
        }
    }

    /// 引用
    public func ref() {
        match (this) {
            case pipe => this.pipe.updateRef(true)
            else => ()
        }
    }

    /// 取消引用
    public func unref() {
        match (this) {
            case pipe => this.pipe.updateRef(false)
            else => ()
        }
    }

    /// 初始化 Readable
    public static func initFunc(
        stdio: Stdio,
        eventLoop: EventLoop,
        process: Subprocess,
        result: StdioResult,
        allocator: Allocator,
        maxSize: MaxBuf,
        isSync: Bool,
    ): Readable {
        Subprocess.assertStdioResult(result)

        if (Environment.isPosix) {
            if (stdio == pipe) {
                _ = Sys.setNonblocking(result)
            }
        }

        return match (stdio) {
            case inherit => Readable.inherit()
            case ignore, .ipc, .path => Readable.ignore()
            case fd(fd) => if (Environment.isPosix) Readable.fd(result) else Readable.fd(fd)
            case memfd => if (Environment.isPosix) Readable.memfd(stdio.memfd) else Readable.ignore()
            case dup2(dup2) => if (Environment.isPosix) {
                // 严格翻译自 Bun src/runtime/api/bun/subprocess/Readable.zig Readable.init: POSIX dup2 stdout/stderr has no JS readable handle.
                Readable.ignore()
            } else {
                Readable.fd(dup2.out.toFd())
            }
            case pipe => Readable.pipe(PipeReader.create(eventLoop, process, result, maxSize))
            case array_buffer(arrayBuffer) =>
                // 严格翻译自 Bun src/runtime/api/bun/subprocess/Readable.zig Readable.init + buffer variant: buffered stdio becomes Readable.buffer.
                Readable.buffer(CowString.initOwned(arrayBuffer.array_buffer.byteSlice(), default_allocator))
            case blob(blob) =>
                // 严格翻译自 Bun src/runtime/api/bun/subprocess/Readable.zig Readable.init + buffer variant: buffered stdio becomes Readable.buffer.
                Readable.buffer(CowString.initOwned(blob.slice(), default_allocator))
            case capture(buf) =>
                // 严格翻译自 Bun src/runtime/api/bun/subprocess/Readable.zig Readable.init + buffer variant: captured bytes are exposed as Readable.buffer.
                Readable.buffer(CowString.initOwned(buf.slice(), default_allocator))
            case readable_stream => Readable.ignore()  // ReadableStream 单独处理
        }
    }

    /// 关闭回调
    public func onClose(err: SysError) {
        this = .closed
    }

    /// 就绪回调
    public func onReady(size: BlobSizeType, totalSize: BlobSizeType) {}

    /// 开始回调
    public func onStart() {}

    /// 关闭
    public func close() {
        match (this) {
            case memfd(fd) =>
                this = .closed()
                fd.close()
            case fd =>
                this = .closed()
            case pipe =>
                this.pipe.close()
            else => ()
        }
    }

    /// 终结化
    public func finalize() {
        match (this) {
            case memfd(fd) =>
                this = .closed()
                fd.close()
            case fd =>
                this = .closed()
            case pipe(pipe) =>
                defer pipe.detach()
                this = .closed()
            case buffer(buf) =>
                buf.deinit(default_allocator)
            else => ()
        }
    }

    /// 转换为 JS 值
    public func toJS(globalThis: JsGlobalObject, exited: Bool): JsValue {
        match (this) {
            case memfd => return this.toBufferedValue(globalThis)

            case fd(fd) =>
                return fd.toJS(globalThis)
            case pipe(pipe) =>
                defer pipe.detach()
                this = .closed()
                return pipe.toJS(globalThis)
            case buffer(buffer) =>
                defer this = .closed()

                if (buffer.size() == 0) {
                    return ReadableStream.empty(globalThis)
                }

                let own = try buffer.takeSlice(default_allocator)
                return ReadableStream.fromOwnedSlice(globalThis, own, 0)
            else => {
                return JsValue.jsUndefined()
            }
        }
    }

    /// 转换为缓冲区 JS 值
    public func toBufferedValue(globalThis: JsGlobalObject): JsValue {
        match (this) {
            case fd(fd) =>
                return fd.toJS(globalThis)
            case memfd(fd) =>
                if (!Environment.isPosix) {
                    panic("memfd is only supported on Linux")
                }
                this = .closed()
                return ArrayBuffer.toJSBufferFromMemfd(fd, globalThis)
            case pipe(pipe) =>
                defer pipe.detach()
                this = .closed()
                return pipe.toBuffer(globalThis)
            case buffer(buf) =>
                defer this = .closed()
                let own = buf.takeSlice(default_allocator) catch {
                    return globalThis.throwOutOfMemory()
                }
                return MarkedArrayBuffer.fromBytes(own, default_allocator, .Uint8Array).toNodeBuffer(globalThis)
            else => {
                return JsValue.jsUndefined()
            }
        }
    }
}

// ============================================================================
// 类型别名
// ========================================================================

public type CowString = CowString
public type StdioResult = StdioResult
public type MaxBuf = MaxBuf
public type PipeReader = PipeReader
public type BlobSizeType = BlobSizeType
public let default_allocator = default_allocator
