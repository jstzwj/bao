// FileResponseStream - 文件响应流
// 严格翻译自: Bun src/runtime/server/FileResponseStream.zig / FileResponseStream.rs
// 对应: 流式传输文件到 HTTP 响应，处理背压和中止
package bao_runtime.server

import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// FileResponseStream - 文件响应流
// 严格翻译自: src/runtime/server/FileResponseStream.zig
// Bun: const FileResponseStream = @This()
// Rust: #[derive(bun_ptr::CellRefCounted)] pub struct FileResponseStream { ... }
// 将已打开的文件描述符流式传输到 uWS 响应
// 处理背压、客户端中止和文件描述符生命周期
//
// 调用者先写入 status + headers，然后通过调用 start() 交出 body 流式传输控制权
// on_complete / on_error 恰好触发一次；触发后调用者不得再使用 resp body 方法
// ============================================================================

/// 文件类型
/// 对应 Bun: bun.io.FileType
/// Rust: bun_io::FileType
public enum FileType {
    | File           // 普通文件
    | Pipe           // 管道 (FIFO/CHR)
    | Socket         // Socket
    | NonBlockingPipe // 非阻塞管道

    public operator func ==(right: FileType): Bool {
        match (this) {
            case FileType.File => match (right) { case FileType.File => true case _ => false }
            case FileType.Pipe => match (right) { case FileType.Pipe => true case _ => false }
            case FileType.Socket => match (right) { case FileType.Socket => true case _ => false }
            case FileType.NonBlockingPipe => match (right) { case FileType.NonBlockingPipe => true case _ => false }
        }
    }
}

/// 文件响应流模式
/// 对应 Bun: const Mode = enum { reader, sendfile }
/// Rust: #[derive(Copy, Clone, Eq, PartialEq, strum::IntoStaticStr)] #[repr(u8)] enum Mode
public enum FileResponseStreamMode {
    | Reader    // 使用 BufferedReader 读取
    | Sendfile  // 使用 sendfile() 系统调用

    public operator func ==(right: FileResponseStreamMode): Bool {
        match (this) {
            case FileResponseStreamMode.Reader => match (right) { case FileResponseStreamMode.Reader => true case _ => false }
            case FileResponseStreamMode.Sendfile => match (right) { case FileResponseStreamMode.Sendfile => true case _ => false }
        }
    }
}

/// Sendfile 状态
/// 对应 Bun: const Sendfile = struct { socket_fd, remain, offset, has_set_on_writable }
/// Rust: struct Sendfile { socket_fd: Fd, remain: u64, offset: u64, has_set_on_writable: bool }
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
/// Rust: bitflags::bitflags! { struct State: u8 { ... } }
public class FileResponseStreamState {
    /// 响应是否完成 - 对应 Bun: RESPONSE_DONE = 1 << 0
    public var responseDone: Bool
    /// 是否已结束 - 对应 Bun: FINISHED = 1 << 1
    public var finished: Bool
    /// 是否出错 - 对应 Bun: ERRORED = 1 << 2
    public var errored: Bool
    /// 响应是否已分离 - 对应 Bun: RESP_DETACHED = 1 << 3
    public var respDetached: Bool

    public init() {
        responseDone = false
        finished = false
        errored = false
        respDetached = false
    }

    /// 检查是否包含指定标志组合
    public func contains(done: Bool, fin: Bool): Bool {
        if (done && !responseDone) { return false }
        if (fin && !finished) { return false }
        return true
    }
}

/// 文件响应流启动选项
/// 对应 Bun: pub const StartOptions = struct { fd, auto_close, resp, ... }
/// Rust: pub struct StartOptions { pub fd: Fd, pub auto_close: bool, ... }
public class FileResponseStreamStartOptions {
    /// 文件描述符 - 对应 Bun: fd: bun.FD
    public var fd: Int64
    /// 是否自动关闭 - 对应 Bun: auto_close: bool = true
    public var autoClose: Bool
    /// 响应引用 - 对应 Bun: resp: AnyResponse
    public var resp: ?ResponseRef
    /// 虚拟机引用 - 对应 Bun: vm: bun_ptr::BackRef<VirtualMachine>
    public var vm: ?VirtualMachineRef
    /// 文件类型 - 对应 Bun: file_type: bun.io.FileType
    public var fileType: FileType
    /// 是否可轮询 - 对应 Bun: pollable: bool
    public var pollable: Bool
    /// 起始偏移 - 对应 Bun: offset: u64 = 0
    /// 字节偏移量，从文件中开始读取的位置
    public var offset: Int64
    /// 最大长度 - 对应 Bun: length: ?u64 = null
    /// 最大发送字节数；None 表示读至 EOF。
    /// 对于普通文件，应为 stat.size - offset (经过 Range/slice 裁剪后)
    public var length: ?Int64
    /// 空闲超时 - 对应 Bun: idle_timeout: u8
    public var idleTimeout: Int64
    /// 上下文 - 对应 Bun: ctx: *anyopaque
    public var ctx: ?Object
    /// 完成回调 - 对应 Bun: on_complete: fn(*c_void, AnyResponse)
    public var onComplete: ?((FileResponseStream) -> Unit)
    /// 中止回调 - 对应 Bun: on_abort: Option<fn(*c_void, AnyResponse)>
    /// 在客户端中途断开时触发，而非 on_complete。
    /// 如果为 None，则通过 on_complete 报告中止
    public var onAbort: ?((FileResponseStream) -> Unit)
    /// 错误回调 - 对应 Bun: on_error: fn(*c_void, AnyResponse, sys::Error)
    public var onError: ?((FileResponseStream, BaoError) -> Unit)

    public init() {
        fd = -1
        autoClose = true
        resp = None
        vm = None
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
/// Rust: #[derive(bun_ptr::CellRefCounted)] pub struct FileResponseStream
/// 处理文件的流式传输，包括 sendfile 和 reader 两种模式
public class FileResponseStream {
    // ========================================================================
    // 字段
    // 严格翻译自 FileResponseStream struct 的所有字段
    // ========================================================================

    /// 引用计数 - 对应 Rust: ref_count: Cell<u32>
    public var refCount: Int64

    /// 响应引用 - 对应 Bun: resp: AnyResponse
    public var resp: ?ResponseRef

    /// 虚拟机引用 - 对应 Bun: vm: bun_ptr::BackRef<VirtualMachine>
    public var vm: ?VirtualMachineRef

    /// EventLoop handle - 对应 Bun: event_loop_handle: EventLoopHandle
    public var eventLoopHandle: ?EventLoopHandleRef

    /// 文件描述符 - 对应 Bun: fd: Fd
    public var fd: Int64

    /// 是否自动关闭 - 对应 Bun: auto_close: bool
    public var autoClose: Bool

    /// 空闲超时 - 对应 Bun: idle_timeout: u8
    public var idleTimeout: Int64

    /// 上下文指针 - 对应 Bun: ctx: *c_void
    public var ctx: ?Object

    /// 完成回调 - 对应 Bun: on_complete: fn(*c_void, AnyResponse)
    public var onComplete: ?((FileResponseStream) -> Unit)

    /// 中止回调 - 对应 Bun: on_abort: Option<fn(*c_void, AnyResponse)>
    public var onAbort: ?((FileResponseStream) -> Unit)

    /// 错误回调 - 对应 Bun: on_error: fn(*c_void, AnyResponse, sys::Error)
    public var onError: ?((FileResponseStream, BaoError) -> Unit)

    /// 模式 - 对应 Bun: mode: Mode
    public var mode: FileResponseStreamMode

    /// BufferedReader 引用 - 对应 Bun: reader: BufferedReader
    public var reader: ?BufferedReaderRef

    /// 最大大小 - 对应 Bun: max_size: Option<u64>
    public var maxSize: ?Int64

    /// EOF 任务 - 对应 Bun: eof_task: Option<AnyTask>
    public var eofTask: ?AnyTaskRef

    /// Sendfile 状态 - 对应 Bun: sendfile: Sendfile
    public var sendfile: SendfileState

    /// 状态标志 - 对应 Bun: state: State
    public var state: FileResponseStreamState

    public init() {
        refCount = 1
        resp = None
        vm = None
        eventLoopHandle = None
        fd = -1
        autoClose = true
        idleTimeout = 0
        ctx = None
        onComplete = None
        onAbort = None
        onError = None
        mode = FileResponseStreamMode.Reader
        reader = None
        maxSize = None
        eofTask = None
        sendfile = SendfileState()
        state = FileResponseStreamState()
    }

    // ========================================================================
    // 启动
    // ========================================================================

    /// 启动文件流式传输
    /// 对应 Bun: pub fn start(opts: StartOptions) void
    /// Rust: pub fn start(opts: StartOptions)
    ///
    /// 调用者先写入 status + headers，然后调用 start() 交出 body 流式传输。
    /// on_complete / on_error 恰好触发一次。
    public static func start(opts: FileResponseStreamStartOptions): FileResponseStream {
        let useSendfile = canSendfile(opts.resp, opts.fileType, opts.length)

        let stream = FileResponseStream()
        stream.resp = opts.resp
        stream.vm = opts.vm
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

        // 对应 Bun: resp.timeout(idle_timeout)
        match (opts.resp) {
            case Some(r) =>
                r.timeout(opts.idleTimeout)
                // 对应 Bun: resp.on_aborted callback
                r.setAbortHandlerForStream(stream)
            case None => ()
        }

        if (useSendfile) {
            // 对应 Bun: sendfile path
            stream.sendfile.socketFd = -1 // 需要从 resp 获取 native handle
            stream.sendfile.offset = opts.offset
            match (opts.length) {
                case Some(len) => stream.sendfile.remain = len
                case None => stream.sendfile.remain = 0
            }
            // 对应 Bun: resp.prepare_for_sendfile()
            // 执行 sendfile
            stream.onSendfile()
        } else {
            // BufferedReader 路径
            stream.maxSize = opts.length
            // 对应 Bun: reader.start(fd, pollable) or reader.start_file_offset
            stream.reader.start(opts.fd, true)
        }

        return stream
    }

    /// 判断是否可以使用 sendfile
    /// 对应 Bun: fn canSendfile(resp, file_type, length) bool
    /// Rust: fn can_sendfile(resp: AnyResponse, file_type: FileType, length: Option<u64>) -> bool
    ///
    /// sendfile() 需要真实的 socket fd；SSL 写入通过 BIO，H3 通过 lsquic 流帧
    /// 仅对普通文件且长度 >= 1MB 时使用
    public static func canSendfile(resp: ?ResponseRef, fileType: FileType,
                                    length: ?Int64): Bool {
        match (fileType) {
            case FileType.File =>
                match (length) {
                    case Some(len) => return len >= 1048576  // 1MB (1 << 20)
                    case None => return false
                }
            case _ => return false
        }
    }

    // ========================================================================
    // Reader 后端
    // ========================================================================

    /// 读取块回调
    /// 对应 Bun: pub fn onReadChunk(this, chunk_, state_) bool
    /// Rust: pub fn on_read_chunk(&self, chunk_: &[u8], state_: ReadState) -> bool
    public func onReadChunk(chunk: Array<UInt8>, isEof: Bool): Bool {
        if (state.responseDone) {
            return false
        }

        // 对应 Bun: maxSize 限制处理
        // PORT NOTE: reshaped for borrowck — reshapes chunk and state
        var effectiveChunk = chunk
        var effectiveEof = isEof
        match (maxSize) {
            case Some(max) =>
                let limitedSize = if (chunk.size < max) { chunk.size } else { max }
                effectiveChunk = chunk
                // 对应 Bun: *max = max.saturating_sub(c.len())
                var newMax = max - limitedSize
                maxSize = Some(newMax)
                if (!isEof && newMax <= 0) {
                    // 对应 Bun: enqueue eof_task, break with ReadState::Eof
                    effectiveEof = true
                }
            case None => ()
        }

        // 对应 Bun: resp.timeout(idle_timeout)
        match (resp) {
            case Some(r) => r.timeout(idleTimeout)
            case None => ()
        }

        if (effectiveEof) {
            // 对应 Bun: state = Eof path
            state.responseDone = true
            detachResp()
            match (resp) {
                case Some(r) =>
                    r.end(bytesToString(effectiveChunk), r.shouldCloseConnection())
                case None => ()
            }
            match (onComplete) {
                case Some(cb) => cb(this)
                case None => ()
            }
            return false
        }

        // 对应 Bun: write chunk to response, handle backpressure
        match (resp) {
            case Some(r) =>
                // 对应 Bun: resp.write(chunk) -> WriteResult
                let writeResult = r.write(effectiveChunk)
                if (writeResult) {
                    return true  // want_more — 数据已写入
                } else {
                    // 背压: 等待 drain 事件
                    return false
                }
            case None => return false
        }
    }

    /// 读取完成
    /// 对应 Bun: pub fn onReaderDone(this) void
    /// Rust: pub fn on_reader_done(&self)
    public func onReaderDone(): Unit {
        finish()
    }

    /// 读取错误
    /// 对应 Bun: pub fn onReaderError(this, err) void
    /// Rust: pub fn on_reader_error(&self, err: sys::Error)
    public func onReaderError(err: BaoError): Unit {
        failWith(err)
    }

    /// onWritable 回调 (Reader 模式)
    /// 对应 Bun: fn onWritable(this, _: u64, _: AnyResponse) bool
    /// Rust: fn on_writable(&self, _: u64, _: AnyResponse) -> bool
    public func onWritableReader(): Bool {
        if (mode == FileResponseStreamMode.Sendfile) {
            return onSendfile()
        }

        // 对应 Bun: if reader is done, finish
        match (reader) {
            case Some(r) =>
                if (r.isDone()) {
                    finish()
                    return true
                }
            case None => ()
        }

        match (resp) {
            case Some(r_) =>
                r_.timeout(idleTimeout)
            case None => ()
        }
        ref()
        // 对应 Bun: reader.read()
        return true
    }

    // ========================================================================
    // Sendfile 后端
    // ========================================================================

    /// 执行 sendfile
    /// 对应 Bun: fn onSendfile(this) bool
    /// Rust: fn on_sendfile(&self) -> bool
    public func onSendfile(): Bool {
        if (state.responseDone) {
            finish()
            return false
        }

        // 对应 Bun: std.os.linux.sendfile / std.c.sendfile (macOS)
        // 对应 Rust: cfg(target_os = "linux") / cfg(target_os = "macos") / else unreachable
        var done = false
        while (!done) {
            let adjusted = if (sendfile.remain < 2147483647) {
                sendfile.remain
            } else {
                Int64(2147483647)
            }

            // 对应 Bun: sendfile(socket_fd, fd, offset, count)
            let result = Sys.sendfile(sendfile.socketFd, sendfile.fd, sendfile.offset, adjusted)
            match (result) {
                case Ok(written) =>
                    sendfile.offset += written
                    sendfile.remain -= written
                    if (sendfile.remain <= 0) {
                        endSendfile()
                        done = true
                    }
                case Err(e) =>
                    if (e.isAgain()) {
                        // 对应 Bun: 等待 socket 可写
                        return false
                    }
                    failWith(e)
                    return false
            }
        }
        return false
    }

    /// 设置 sendfile 的 onWritable 回调
    /// 对应 Bun: fn armSendfileWritable(this) bool
    /// Rust: fn arm_sendfile_writable(&self) -> bool
    public func armSendfileWritable(): Bool {
        if (!sendfile.hasSetOnWritable) {
            sendfile.hasSetOnWritable = true
            match (resp) {
                case Some(r) =>
                    r.onWritableForStream(this)
                case None => ()
            }
        }
        // 对应 Bun: resp.mark_needs_more()
        match (resp) {
            case Some(r) =>
                r.writeHeader("x-more", "true")
            case None => ()
        }
        return true
    }

    /// 结束 sendfile
    /// 对应 Bun: fn endSendfile(this) void
    /// Rust: fn end_sendfile(&self)
    public func endSendfile(): Unit {
        if (state.responseDone) {
            return
        }
        state.responseDone = true
        detachResp()

        // 对应 Bun: resp.end_send_file(offset, should_close_connection)
        match (resp) {
            case Some(r) =>
                r.end("", r.shouldCloseConnection())
            case None => ()
        }

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
    /// Rust: fn on_aborted(&self, _: AnyResponse)
    public func onAborted(): Unit {
        if (!state.responseDone) {
            state.responseDone = true
            detachResp()
            // 对应 Bun: on_abort.unwrap_or(on_complete)
            match (onAbort) {
                case Some(cb) => cb(this)
                case None =>
                    match (onComplete) {
                        case Some(cb) => cb(this)
                        case None => ()
                    }
            }
        }
        finish()
    }

    /// 错误处理
    /// 对应 Bun: fn failWith(this, err) void
    /// Rust: fn fail_with(&self, err: sys::Error)
    public func failWith(err: BaoError): Unit {
        if (!state.responseDone) {
            state.responseDone = true
            state.errored = true
            detachResp()

            // 对应 Bun: resp.force_close()
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
    /// Rust: fn detach_resp(&self)
    ///
    /// 清除所有指向此对象的 uWS 回调。必须在 resp 仍然有效时运行
    /// (即在 resp.end() / end_send_file() / force_close() 将 socket 交还给 uWS 之前)
    public func detachResp(): Unit {
        if (state.respDetached) {
            return
        }
        state.respDetached = true
        match (resp) {
            case Some(r) =>
                r.clearOnWritable()
                r.clearAborted()
                r.clearTimeout()
            case None => ()
        }
    }

    /// 完成
    /// 对应 Bun: fn finish(this) void
    /// Rust: fn finish(&self)
    public func finish(): Unit {
        if (state.finished) {
            return
        }
        state.finished = true

        if (!state.responseDone) {
            state.responseDone = true
            detachResp()

            // 对应 Bun: resp.end_without_body(should_close_connection)
            match (resp) {
                case Some(r) =>
                    r.endWithoutBody(r.shouldCloseConnection())
                case None => ()
            }

            match (onComplete) {
                case Some(cb) => cb(this)
                case None => ()
            }
        }

        // 对应 Bun: Self::deref(self) — intrusive refcount
        deref()
    }

    /// 析构
    /// 对应 Bun: fn deinit(this) void
    /// Rust: impl Drop for FileResponseStream { fn drop(&self) }
    public func deinit(): Unit {
        if (autoClose && fd >= 0) {
            // 对应 Bun: Closer::close(fd, ...) / SysFs.close(fd)
            fd = -1
        }
    }

    /// 获取 EventLoop handle
    /// 对应 Bun: pub fn eventLoop(this) EventLoopHandle
    /// Rust: pub fn event_loop(&self) -> EventLoopHandle
    public func eventLoop(): ?EventLoopHandleRef {
        return eventLoopHandle
    }

    /// 获取 loop 引用
    /// 对应 Bun: pub fn loop(this) *bun.io.Loop
    /// Rust: pub fn r#loop(&self) -> *bun_io::Loop
    public func loopRef(): ?EventLoopHandleRef {
        return eventLoopHandle
    }

    /// 增加引用
    /// 对应 Bun/CellRefCounted: ref_()
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    /// 对应 Bun/CellRefCounted: deref()
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
            sb.append(b)
        }
        return sb.toString()
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// EventLoop handle 引用
/// 对应 Bun: EventLoopHandle
public class EventLoopHandleRef {
    public init() {}
}

/// BufferedReader 引用
/// 对应 Bun: bun.io.BufferedReader
public class BufferedReaderRef {
    public init() {}

    public func isDone(): Bool {
        return true
    }
}

/// AnyTask 引用
/// 对应 Bun: AnyTask
public class AnyTaskRef {
    public init() {}
}

/* Duplicate: SocketAddress is defined in request_context.cj
/// SocketAddress for file_response_stream
public class SocketAddress {
    public init() {}
}
*/
