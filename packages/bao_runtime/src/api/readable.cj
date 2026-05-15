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
    /// 使用文件描述符
    case fd(FD)
    /// 使用内存文件描述符 (Linux)
    case memfd(FD)
    /// 使用管道读取器
    case pipe(PipeReader)
    /// 继承父进程
    case inherit
    /// 忽略
    case ignore
    /// 已关闭
    case closed
    /// 使用缓冲区
    case buffer(CowString)

    // ========================================================================
    // 方法
    // ========================================================================

    /// 内存占用
    public func memoryCost(): Int64 {
        return switch (this) {
            case .pipe => sizeof(PipeReader) + this.pipe.memoryCost()
            case .buffer => this.buffer.length()
            else => 0
        }
    }

    /// 是否有待处理活动
    public func hasPendingActivity(): Bool {
        return switch (this) {
            case .pipe => this.pipe.hasPendingActivity()
            else => false
        }
    }

    /// 引用
    public func ref() {
        switch (this) {
            case .pipe => this.pipe.updateRef(true)
            else => {}
        }
    }

    /// 取消引用
    public func unref() {
        switch (this) {
            case .pipe => this.pipe.updateRef(false)
            else => {}
        }
    }

    /// 初始化 Readable
    public static func init(
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
            if (stdio == .pipe) {
                _ = Sys.setNonblocking(result)
            }
        }

        return switch (stdio) {
            case .inherit => Readable.inherit()
            case .ignore, .ipc, .path => Readable.ignore()
            case .fd(let fd) => if (Environment.isPosix) Readable.fd(result) else Readable.fd(fd)
            case .memfd => if (Environment.isPosix) Readable.memfd(stdio.memfd) else Readable.ignore()
            case .dup2(let dup2) => if (Environment.isPosix) {
                panic("TODO: implement dup2 support in Stdio readable")
            } else {
                Readable.fd(dup2.out.toFd())
            }
            case .pipe => Readable.pipe(PipeReader.create(eventLoop, process, result, maxSize))
            case .array_buffer, .blob => panic("TODO: implement ArrayBuffer & Blob support in Stdio readable")
            case .capture => panic("TODO: implement capture support in Stdio readable")
            case .readable_stream => Readable.ignore()  // ReadableStream 单独处理
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
        switch (this) {
            case .memfd(let fd) => {
                this = .closed()
                fd.close()
            }
            case .fd => {
                this = .closed()
            }
            case .pipe => {
                this.pipe.close()
            }
            else => {}
        }
    }

    /// 终结化
    public func finalize() {
        switch (this) {
            case .memfd(let fd) => {
                this = .closed()
                fd.close()
            }
            case .fd => {
                this = .closed()
            }
            case .pipe(let pipe) => {
                defer pipe.detach()
                this = .closed()
            }
            case .buffer(let buf) => {
                buf.deinit(default_allocator)
            }
            else => {}
        }
    }

    /// 转换为 JS 值
    public func toJS(globalThis: JsGlobalObject, exited: Bool): JsValue {
        switch (this) {
            case .memfd => return this.toBufferedValue(globalThis)

            case .fd(let fd) => {
                return fd.toJS(globalThis)
            }
            case .pipe(let pipe) => {
                defer pipe.detach()
                this = .closed()
                return pipe.toJS(globalThis)
            }
            case .buffer(let buffer) => {
                defer this = .closed()

                if (buffer.length() == 0) {
                    return ReadableStream.empty(globalThis)
                }

                let own = try buffer.takeSlice(default_allocator)
                return ReadableStream.fromOwnedSlice(globalThis, own, 0)
            }
            else => {
                return JsValue.jsUndefined()
            }
        }
    }

    /// 转换为缓冲区 JS 值
    public func toBufferedValue(globalThis: JsGlobalObject): JsValue {
        switch (this) {
            case .fd(let fd) => {
                return fd.toJS(globalThis)
            }
            case .memfd(let fd) => {
                if (!Environment.isPosix) {
                    panic("memfd is only supported on Linux")
                }
                this = .closed()
                return ArrayBuffer.toJSBufferFromMemfd(fd, globalThis)
            }
            case .pipe(let pipe) => {
                defer pipe.detach()
                this = .closed()
                return pipe.toBuffer(globalThis)
            }
            case .buffer(let buf) => {
                defer this = .closed()
                let own = buf.takeSlice(default_allocator) catch {
                    return globalThis.throwOutOfMemory()
                }
                return MarkedArrayBuffer.fromBytes(own, default_allocator, .Uint8Array).toNodeBuffer(globalThis)
            }
            else => {
                return JsValue.jsUndefined()
            }
        }
    }
}

// ============================================================================
// 类型别名
// ========================================================================

public typealias CowString = CowString
public typealias StdioResult = StdioResult
public typealias MaxBuf = MaxBuf
public typealias PipeReader = PipeReader
public typealias BlobSizeType = BlobSizeType
public let default_allocator = default_allocator
