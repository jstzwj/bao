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
    | fd(FD)
    | memfd(FD)
    | pipe(PipeReader)
    | inherit
    | ignore
    | closed
    | buffer(Array<Byte>)

    /// 是否有待处理活动
    public func hasPendingActivity(): Bool {
        return match (this) {
            case pipe => this.pipe.hasPendingActivity()
            case _ => false
        }
    }

    /// 引用
    public func ref() {
        match (this) {
            case pipe => this.pipe.updateRef(true)
            case _ => ()
        }
    }

    /// 取消引用
    public func unref() {
        match (this) {
            case pipe => this.pipe.updateRef(false)
            case _ => ()
        }
    }

    /// 初始化 Readable
    public static func initFunc(
        stdio!: Stdio,
        eventLoop!: EventLoop,
        process!: Subprocess,
        result!: StdioResult,
        allocator!: Allocator,
        maxSize!: MaxBuf,
        isSync!: Bool
    ): Readable {
        Subprocess.assertStdioResult(result)

        if (Environment.isPosix) {
            if (stdio == Stdio.pipe) {
                _ = Sys.setNonblocking(result)
            }
        }

        var fdResult: Readable = Readable.ignore
        var memfdResult: Readable = Readable.ignore
        let isPosix = Environment.isPosix
        if (isPosix) {
            fdResult = Readable.fd(result)
            memfdResult = Readable.memfd(result)
        }

        return match (stdio) {
            case inherit => Readable.inherit
            case ignore => Readable.ignore
            case ipc => Readable.ignore
            case path => Readable.ignore
            case fd(_) => fdResult
            case memfd(_) => memfdResult
            case dup2(dup2) => if (Environment.isPosix) {
                // 严格翻译自 Bun src/runtime/api/bun/subprocess/Readable.zig Readable.init: POSIX dup2 stdout/stderr has no JS readable handle.
                Readable.ignore
            } else {
                Readable.fd(dup2.out.toFd())
            }
            case pipe => Readable.pipe(PipeReader.create(eventLoop, process, result, maxSize))
            case array_buffer(arrayBuffer) =>
                // 严格翻译自 Bun src/runtime/api/bun/subprocess/Readable.zig Readable.init + buffer variant: buffered stdio becomes Readable.buffer.
                Readable.buffer(arrayBuffer.array_buffer.byteSlice())
            case blob(blob) =>
                // 严格翻译自 Bun src/runtime/api/bun/subprocess/Readable.zig Readable.init + buffer variant: buffered stdio becomes Readable.buffer.
                Readable.buffer(blob.slice())
            case capture(buf) =>
                // 严格翻译自 Bun src/runtime/api/bun/subprocess/Readable.zig Readable.init + buffer variant: captured bytes are exposed as Readable.buffer.
                Readable.buffer(buf.slice())
            case readable_stream => Readable.ignore  // ReadableStream 单独处理
        }
    }

    /// 关闭回调
    public func onClose(err!: SysError) {
        this = Readable.closed
    }

    /// 就绪回调
    public func onReady(size!: BlobSizeType, totalSize!: BlobSizeType) {}

    /// 开始回调
    public func onStart() {}

    /// 关闭
    public func close() {
        match (this) {
            case memfd(fd) =>
                this = Readable.closed
                fd.close()
            case fd =>
                this = Readable.closed
            case pipe =>
                this.pipe.close()
            case _ => ()
        }
    }

    /// 终结化
    public func finalize() {
        match (this) {
            case memfd(fd) =>
                this = Readable.closed
                fd.close()
            case fd =>
                this = Readable.closed
            case pipe(pipe) =>
                this = Readable.closed
                pipe.detach()
            case buffer(buf) =>
                // buf deinit
                ()
            case _ => ()
        }
    }

    /// 转换为 JS 值
    public func toJS(globalThis!: JsGlobalObject, exited!: Bool): JsValue {
        match (this) {
            case memfd => return this.toBufferedValue(globalThis)
            case fd(fd) =>
                return fd.toJS(globalThis)
            case pipe(pipe) =>
                this = Readable.closed
                pipe.detach()
                return pipe.toJS(globalThis)
            case buffer(buffer) =>
                if (buffer.size() == 0) {
                    return ReadableStream.empty(globalThis)
                }
                let own = buffer.takeSlice(default_allocator)
                this = Readable.closed
                return ReadableStream.fromOwnedSlice(globalThis, own, 0)
            case _ =>
                return JsValue.jsUndefined()
        }
    }

    /// 转换为缓冲区 JS 值
    public func toBufferedValue(globalThis!: JsGlobalObject): JsValue {
        match (this) {
            case fd(fd) =>
                return fd.toJS(globalThis)
            case memfd(fd) =>
                if (!Environment.isPosix) {
                    panic("memfd is only supported on Linux")
                }
                this = Readable.closed
                return ArrayBuffer.toJSBufferFromMemfd(fd, globalThis)
            case pipe(pipe) =>
                this = Readable.closed
                pipe.detach()
                return pipe.toBuffer(globalThis)
            case buffer(buf) =>
                let own = buf.takeSlice(default_allocator)
                this = Readable.closed
                return MarkedArrayBuffer.fromBytes(own, default_allocator, MarkedArrayBuffer.Kind.Uint8Array).toNodeBuffer(globalThis)
            case _ =>
                return JsValue.jsUndefined()
        }
    }
}
