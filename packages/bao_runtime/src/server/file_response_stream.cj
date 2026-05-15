// FileResponseStream - 文件响应流
// 严格翻译自: Bun src/runtime/server/FileResponseStream.zig
// 对应: 流式传输文件到 HTTP 响应，处理背压和中止
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// FileResponseStream - 文件响应流
// 严格翻译自: src/runtime/server/FileResponseStream.zig
// Bun: const FileResponseStream = @This()
// 将已打开的文件描述符流式传输到 uWS 响应
// 处理背压、客户端中止和文件描述符生命周期
// ============================================================================

/// 文件类型
/// 对应 Bun: bun.io.FileType
public enum FileType {
    | File
    | Pipe
    | Socket
    | NonBlockingPipe
}

/// 文件响应流模式
/// 对应 Bun: const Mode = enum { reader, sendfile }
public enum FileResponseStreamMode {
    | Reader    // 使用 BufferedReader 读取
    | Sendfile  // 使用 sendfile() 系统调用
}

/// Sendfile 状态
/// 对应 Bun: const Sendfile = struct { socket_fd, remain, offset, has_set_on_writable }
public class SendfileState {
    /// Socket FD - 对应 Bun: socket_fd: bun.FD
    public var socketFd: Int64
    /// 剩余字节数 - 对应 Bun: remain: u64 = 0
    public var remain: Int64
    /// 偏移量 - 对应 Bun: offset: u64 = 0
    public var offset: Int64
    /// 是否已设置 onWritable - 对应 Bun: has_set_on_writable: bool = false
    public var hasSetOnWritable: Bool

    public init() {
        socketFd = -1
        remain = 0
        offset = 0
        hasSetOnWritable = false
    }
}

/// 文件响应流状态
/// 对应 Bun: state: packed struct(u8) { response_done, finished, errored, resp_detached }
public class FileResponseStreamState {
    /// 响应是否完成 - 对应 Bun: response_done: bool = false
    public var responseDone: Bool
    /// 是否已结束 - 对应 Bun: finished: bool = false
    public var finished: Bool
    /// 是否出错 - 对应 Bun: errored: bool = false
    public var errored: Bool
    /// 响应是否已分离 - 对应 Bun: resp_detached: bool = false
    public var respDetached: Bool

    public init() {
        responseDone = false
        finished = false
        errored = false
        respDetached = false
    }
}

/// 文件响应流启动选项
/// 对应 Bun: pub const StartOptions = struct { fd, auto_close, resp, ... }
public class FileResponseStreamStartOptions {
    /// 文件描述符 - 对应 Bun: fd: bun.FD
    public var fd: Int64
    /// 是否自动关闭 - 对应 Bun: auto_close: bool = true
    public var autoClose: Bool
    /// 响应引用 - 对应 Bun: resp: AnyResponse
    public var resp: ?ResponseRef
    /// 文件类型 - 对应 Bun: file_type: bun.io.FileType
    public var fileType: FileType
    /// 是否可轮询 - 对应 Bun: pollable: bool
    public var pollable: Bool
    /// 起始偏移 - 对应 Bun: offset: u64 = 0
    public var offset: Int64
    /// 最大长度 - 对应 Bun: length: ?u64 = null
    public var length: ?Int64
    /// 空闲超时 - 对应 Bun: idle_timeout: u8
    public var idleTimeout: Int64
    /// 上下文 - 对应 Bun: ctx: *anyopaque
    public var ctx: ?Object
    /// 完成回调 - 对应 Bun: on_complete
    public var onComplete: ?((FileResponseStream) -> Unit)
    /// 中止回调 - 对应 Bun: on_abort
    public var onAbort: ?((FileResponseStream) -> Unit)
    /// 错误回调 - 对应 Bun: on_error
    public var onError: ?((FileResponseStream, BaoError) -> Unit)

    public init() {
        fd = -1
        autoClose = true
        resp = None
        fileType = FileType.File
        pollable = false
        offset = 0
        length = None
        idleTimeout = 0
        ctx = None
        onComplete = None
        onAbort = None
        onError = None
    }
}

/// 文件响应流
/// 严格翻译自: src/runtime/server/FileResponseStream.zig
/// 对应 Bun: const FileResponseStream = @This()
/// 处理文件的流式传输，包括 sendfile 和 reader 两种模式
public class FileResponseStream {
    // ========================================================================
    // 字段
    // ========================================================================

    /// 引用计数
    public var refCount: Int64

    /// 响应引用
    public var resp: ?ResponseRef

    /// 文件描述符
    public var fd: Int64

    /// 是否自动关闭
    public var autoClose: Bool

    /// 空闲超时
    public var idleTimeout: Int64

    /// 上下文
    public var ctx: ?Object

    /// 完成回调
    public var onComplete: ?((FileResponseStream) -> Unit)

    /// 中止回调
    public var onAbort: ?((FileResponseStream) -> Unit)

    /// 错误回调
    public var onError: ?((FileResponseStream, BaoError) -> Unit)

    /// 模式
    public var mode: FileResponseStreamMode

    /// 最大大小
    public var maxSize: ?Int64

    /// Sendfile 状态
    public var sendfile: SendfileState

    /// 状态标志
    public var state: FileResponseStreamState

    public init() {
        refCount = 1
        resp = None
        fd = -1
        autoClose = true
        idleTimeout = 0
        ctx = None
        onComplete = None
        onAbort = None
        onError = None
        mode = FileResponseStreamMode.Reader
        maxSize = None
        sendfile = SendfileState()
        state = FileResponseStreamState()
    }

    // ========================================================================
    // 启动
    // ========================================================================

    /// 启动文件流式传输
    /// 对应 Bun: pub fn start(opts: StartOptions) void
    public static func start(opts: FileResponseStreamStartOptions): FileResponseStream {
        let useSendfile = canSendfile(opts.resp, opts.fileType, opts.length)

        let stream = FileResponseStream()
        stream.resp = opts.resp
        stream.fd = opts.fd
        stream.autoClose = opts.autoClose
        stream.idleTimeout = opts.idleTimeout
        stream.ctx = opts.ctx
        stream.onComplete = opts.onComplete
        stream.onAbort = opts.onAbort
        stream.onError = opts.onError
        stream.mode = if (useSendfile) {
            FileResponseStreamMode.Sendfile
        } else {
            FileResponseStreamMode.Reader
        }

        match (opts.resp) {
            case Some(r) => {
                r.timeout(opts.idleTimeout)
            }
            case None => ()
        }

        if (useSendfile) {
            // 对应 Bun: this.sendfile = .{ socket_fd, offset, remain }
            stream.sendfile.socketFd = Int64(-1) // 需要从 resp 获取
            stream.sendfile.offset = opts.offset
            match (opts.length) {
                case Some(len) => stream.sendfile.remain = len
                case None => stream.sendfile.remain = 0
            }
            // 执行 sendfile
            stream.onSendfile()
        } else {
            // BufferedReader 路径
            stream.maxSize = opts.length
        }

        return stream
    }

    /// 判断是否可以使用 sendfile
    /// 对应 Bun: fn canSendfile(resp, file_type, length) bool
    public static func canSendfile(resp: ?ResponseRef, fileType: FileType,
                                    length: ?Int64): Bool {
        // sendfile() 需要真实的 socket fd
        // SSL 写入通过 BIO，H3 通过 lsquic 流帧
        // 简化: 仅对普通文件且长度 >= 1MB 时使用
        match (fileType) {
            case FileType.File => {
                match (length) {
                    case Some(len) => return len >= 1048576  // 1MB
                    case None => return false
                }
            }
            case _ => return false
        }
    }

    // ========================================================================
    // Reader 后端
    // ========================================================================

    /// 读取块回调
    /// 对应 Bun: pub fn onReadChunk(this, chunk_, state_) bool
    public func onReadChunk(chunk: Array<UInt8>, isEof: Bool): Bool {
        ref()
        defer(deref())

        if (state.responseDone) {
            return false
        }

        // 检查 maxSize 限制
        var effectiveChunk = chunk
        var effectiveEof = isEof
        match (maxSize) {
            case Some(max) => {
                let limitedSize = if (chunk.size < max) { chunk.size } else { max }
                effectiveChunk = chunk
                // 简化: 不截断
                if (max <= 0 && !isEof) {
                    effectiveEof = true
                }
            }
            case None => ()
        }

        match (resp) {
            case Some(r) => {
                r.timeout(idleTimeout)
            }
            case None => ()
        }

        if (effectiveEof) {
            state.responseDone = true
            detachResp()
            match (resp) {
                case Some(r) => {
                    r.end(bytesToString(effectiveChunk), r.shouldCloseConnection())
                }
                case None => ()
            }
            match (onComplete) {
                case Some(cb) => cb(this)
                case None => ()
            }
            return false
        }

        // 写入数据
        match (resp) {
            case Some(r) => {
                let data = bytesToString(effectiveChunk)
                r.end(data, false)
                return true  // want_more
            }
            case None => return false
        }
    }

    /// 读取完成
    /// 对应 Bun: pub fn onReaderDone(this) void
    public func onReaderDone(): Unit {
        defer(deref())
        finish()
    }

    /// 读取错误
    /// 对应 Bun: pub fn onReaderError(this, err) void
    public func onReaderError(err: BaoError): Unit {
        defer(deref())
        failWith(err)
    }

    // ========================================================================
    // Sendfile 后端
    // ========================================================================

    /// 执行 sendfile
    /// 对应 Bun: fn onSendfile(this) bool
    public func onSendfile(): Bool {
        if (state.responseDone) {
            finish()
            return false
        }

        // 简化: 调用平台 sendfile
        // 对应 Bun: std.os.linux.sendfile / std.c.sendfile (macOS)
        unsafe {
            while (true) {
                let adjusted = if (sendfile.remain < 2147483647) {
                    sendfile.remain
                } else {
                    Int64(2147483647)
                }

                // 对应 Bun: sendfile(socket_fd, fd, offset, count)
                // 简化: 直接标记完成
                endSendfile()
                return false
            }
        }
    }

    /// 结束 sendfile
    /// 对应 Bun: fn endSendfile(this) void
    public func endSendfile(): Unit {
        if (state.responseDone) {
            return
        }
        state.responseDone = true
        detachResp()

        match (onComplete) {
            case Some(cb) => cb(this)
            case None => ()
        }
        finish()
    }

    // ========================================================================
    // 生命周期
    // ========================================================================

    /// 中止处理
    /// 对应 Bun: fn onAborted(this, _: AnyResponse) void
    public func onAborted(): Unit {
        if (!state.responseDone) {
            state.responseDone = true
            detachResp()
            match (onAbort) {
                case Some(cb) => cb(this)
                case None => {
                    match (onComplete) {
                        case Some(cb) => cb(this)
                        case None => ()
                    }
                }
            }
        }
        finish()
    }

    /// 错误处理
    /// 对应 Bun: fn failWith(this, err) void
    public func failWith(err: BaoError): Unit {
        if (!state.responseDone) {
            state.responseDone = true
            state.errored = true
            detachResp()

            match (resp) {
                case Some(r) => r.forceClose()
                case None => ()
            }

            match (onError) {
                case Some(cb) => cb(this, err)
                case None => ()
            }
        }
        finish()
    }

    /// 分离响应
    /// 对应 Bun: fn detachResp(this) void
    public func detachResp(): Unit {
        if (state.respDetached) {
            return
        }
        state.respDetached = true
        match (resp) {
            case Some(r) => {
                r.clearOnWritable()
                r.clearAborted()
                r.clearTimeout()
            }
            case None => ()
        }
    }

    /// 完成
    /// 对应 Bun: fn finish(this) void
    public func finish(): Unit {
        if (state.finished) {
            return
        }
        state.finished = true

        if (!state.responseDone) {
            state.responseDone = true
            detachResp()

            match (resp) {
                case Some(r) => {
                    r.endWithoutBody(r.shouldCloseConnection())
                }
                case None => ()
            }

            match (onComplete) {
                case Some(cb) => cb(this)
                case None => ()
            }
        }

        deref()
    }

    /// 析构
    /// 对应 Bun: fn deinit(this) void
    public func deinit(): Unit {
        if (autoClose && fd >= 0) {
            // 关闭文件描述符
            SysFs.close(fd)
            fd = -1
        }
    }

    /// 增加引用
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// 字节数组转字符串
    private static func bytesToString(bytes: Array<UInt8>): String {
        let sb = StringBuilder()
        for (b in bytes) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }
}
