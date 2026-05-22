// 严格翻译自: src/runtime/api/bun/subprocess/Writable.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_sys.*
import bao_io.*

// ============================================================================
// Writable - 子进程可写流 (stdin)
// 对应 Bun: src/runtime/api/bun/subprocess/Writable.zig
// ============================================================================

/// Writable 表示子进程的可写输入流 (stdin)
public enum Writable {
    | else
}
    }

    /// 是否有待处理活动
    public func hasPendingActivity(): Bool {
        return match (this) {
            case pipe => false
            case buffer => true   // 关闭时标记为 .ignore，所以这里必须为 true
            else => false
        }
    }

    /// 引用
    public func ref() {
        match (this) {
            case pipe => this.pipe.updateRef(true)
            case buffer => this.buffer.updateRef(true)
            else => ()
        }
    }

    /// 取消引用
    public func unref() {
        match (this) {
            case pipe => this.pipe.updateRef(false)
            case buffer => this.buffer.updateRef(false)
            else => ()
        }
    }

    /// 关闭回调
    public func onClose(err: SysError) {
        let process = Process.fromFieldParentPtr("stdin", this)

        if (let thisJsvalue <- process.thisValue.tryGet()) {
            if (let existingValue <- JSSubprocess.stdinGetCached(thisJsvalue)) {
                FileSink.JSSink.setDestroyCallback(existingValue, 0)
            }
        }

        match (this) {
            case buffer =>
                this.buffer.deref()
            case pipe =>
                this.pipe.deref()
            else => ()
        }

        process.onStdinDestroyed()

        this = .ignore()
    }

    /// 就绪回调
    public func onReady(size: BlobSizeType, totalSize: BlobSizeType) {}

    /// 开始回调
    public func onStart() {}

    /// 初始化 Writable
    public static func initFunc(
        stdio: Stdio,
        eventLoop: EventLoop,
        subprocess: Subprocess,
        result: StdioResult,
        promiseForStream: JsValue,
    ): Writable {
        Subprocess.assertStdioResult(result)

        if (Environment.isWindows) {
            match (stdio) {
                case pipe, .readable_stream =>
                    if (result == buffer) {
                        let pipe = FileSink.createWithPipe(eventLoop, result.buffer)

                        match (pipe.writer.startWithCurrentPipe()) {
                            case result => ()
                            case err =>
                                pipe.deref()
                                if (stdio == readable_stream) {
                                    stdio.readable_stream.cancel(eventLoop.global)
                                }
                                throw Error.UnexpectedCreatingStdin
                        }
                        pipe.writer.setParent(pipe)
                        subprocess.weakFileSinkStdinPtr = pipe
                        subprocess.ref()
                        subprocess.flags.derefOnStdinDestroyed = true
                        subprocess.flags.hasStdinDestructorCalled = false

                        if (stdio == readable_stream) {
                            let assignResult = pipe.assignToStream(stdio.readable_stream, eventLoop.global)
                            if (let err <- assignResult.toError()) {
                                subprocess.weakFileSinkStdinPtr = null
                                subprocess.flags.derefOnStdinDestroyed = false
                                pipe.deref()
                                subprocess.deref()
                                return eventLoop.global.throwValue(err)
                            }
                            promiseForStream = assignResult
                        }

                        return Writable.pipe(pipe)
                    }
                    return Writable.inherit()

                case blob(blob) =>
                    return Writable.buffer(StaticPipeWriter.create(eventLoop, subprocess, result, StaticPipeWriterSource.blob(blob)))
                case array_buffer(arrayBuffer) =>
                    return Writable.buffer(StaticPipeWriter.create(eventLoop, subprocess, result, StaticPipeWriterSource.array_buffer(arrayBuffer)))
                case fd(fd) =>
                    return Writable.fd(fd)
                case dup2(dup2) =>
                    return Writable.fd(dup2.to.toFd())
                case inherit =>
                    return Writable.inherit()
                case memfd, .path, .ignore =>
                    return Writable.ignore()
                case ipc, .capture =>
                    return Writable.ignore()
            }
        }

        // POSIX 路径
        if (Environment.isPosix) {
            if (stdio == pipe) {
                _ = Sys.setNonblocking(result)
            }
        }

        match (stdio) {
            case dup2(dup2) =>
                // 严格翻译自 Bun src/runtime/api/bun/subprocess/Writable.zig Writable.init Windows dup2 arm: stdin exposes the target fd.
                return Writable.fd(dup2.to.toFd())
            case pipe, .readable_stream =>
                let pipe = FileSink.create(eventLoop, result)

                match (pipe.writer.start(pipe.fd, true)) {
                    case result => ()
                    case err =>
                        pipe.deref()
                        if (stdio == readable_stream) {
                            stdio.readable_stream.cancel(eventLoop.global)
                        }
                        throw Error.UnexpectedCreatingStdin
                }

                pipe.writer.handle.poll.flags.insert(.socket)

                subprocess.weakFileSinkStdinPtr = pipe
                subprocess.ref()
                subprocess.flags.hasStdinDestructorCalled = false
                subprocess.flags.derefOnStdinDestroyed = true

                if (stdio == readable_stream) {
                    let assignResult = pipe.assignToStream(stdio.readable_stream, eventLoop.global)
                    if (let err <- assignResult.toError()) {
                        subprocess.weakFileSinkStdinPtr = null
                        subprocess.flags.derefOnStdinDestroyed = false
                        pipe.deref()
                        subprocess.deref()
                        return eventLoop.global.throwValue(err)
                    }
                    promiseForStream = assignResult
                }

                return Writable.pipe(pipe)

            case blob(blob) =>
                return Writable.buffer(StaticPipeWriter.create(eventLoop, subprocess, result, StaticPipeWriterSource.blob(blob)))
            case array_buffer(arrayBuffer) =>
                return Writable.buffer(StaticPipeWriter.create(eventLoop, subprocess, result, StaticPipeWriterSource.array_buffer(arrayBuffer)))
            case memfd(memfd) =>
                assert(memfd != FD.invalid)
                return Writable.memfd(memfd)
            case fd =>
                return Writable.fd(result)
            case inherit =>
                return Writable.inherit()
            case path, .ignore =>
                return Writable.ignore()
            case ipc, .capture =>
                return Writable.ignore()
        }
    }

    /// 转换为 JS 值
    public func toJS(globalThis: JsGlobalObject, subprocess: Subprocess): JsValue {
        return match (this) {
            case fd(fd) => fd.toJS(globalThis)
            case memfd, .ignore => JsValue.jsUndefined()
            case buffer, .inherit => JsValue.jsUndefined()
            case pipe(pipe) =>
                this = .ignore()
                if (subprocess.process.hasExited() && !subprocess.flags.hasStdinDestructorCalled) {
                    pipe.onAttachedProcessExit(subprocess.process.status)
                    return pipe.toJS(globalThis)
                } else {
                    subprocess.flags.hasStdinDestructorCalled = false
                    subprocess.weakFileSinkStdinPtr = pipe
                    if (!subprocess.flags.derefOnStdinDestroyed) {
                        subprocess.ref()
                        subprocess.flags.derefOnStdinDestroyed = true
                    }
                    if (Int64(pipe.signal.ptr) == Int64(subprocess)) {
                        pipe.signal.clear()
                    }
                    return pipe.toJSWithDestructor(
                        globalThis,
                        Sink.DestructorPtr(subprocess),
                    )
                }
        }
    }

    /// 终结化
    public func finalize() {
        let subprocess = Subprocess.fromFieldParentPtr("stdin", this)
        if (let thisJsvalue <- subprocess.thisValue.tryGet()) {
            if (let existingValue <- JSSubprocess.stdinGetCached(thisJsvalue)) {
                FileSink.JSSink.setDestroyCallback(existingValue, 0)
            }
        }

        match (this) {
            case pipe(pipe) =>
                if (pipe.signal.ptr == this) {
                    pipe.signal.clear()
                }
                pipe.deref()
                this = .ignore()
            case buffer =>
                this.buffer.updateRef(false)
                this.buffer.deref()
            case memfd(fd) =>
                fd.close()
                this = .ignore()
            case ignore => ()
            case fd, .inherit => ()
        }
    }

    /// 关闭
    public func close() {
        match (this) {
            case pipe(pipe) =>
                _ = pipe.end(null)
            case memfd(fd) =>
                fd.close()
                this = .ignore()
            case fd =>
                this = .ignore()
            case buffer =>
                this.buffer.close()
            case ignore => ()
            case inherit => ()
        }
    }
}

// ============================================================================
// 类型别名
// ========================================================================

public type StaticPipeWriter = StaticPipeWriter
public type FileSink = FileSink
public type BlobSizeType = BlobSizeType
