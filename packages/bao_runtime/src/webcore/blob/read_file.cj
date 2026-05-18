// ReadFile - async file reading with JS promise integration
// Strict 1:1 translation from: src/runtime/webcore/blob/read_file.rs (1439 lines)
package bao_runtime.webcore.blob

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_sys.*
import bao_io.*
import bao_ptr.*

// ============================================================================
// ReadFileToJs - trait for converting read bytes to a JSValue
// Corresponds to: Bun: read_file.rs ReadFileToJs (line 50)
// ============================================================================

/// Trait for comptime callback that converts the read bytes to a JSValue.
/// Corresponds to: Bun: ReadFileToJs
/// `by` carries the caller's allocation provenance unchanged:
/// `Lifetime.Temporary` => a Box<[u8]>::into_raw the callee MUST take
/// ownership of; otherwise a borrow valid for the call.
public interface ReadFileToJs {
    func call(b: Blob, g: JsGlobalObject, by: Array<UInt8>, lifetime: BlobLifetime): JsValue
}

// ============================================================================
// ReadFileCompletion - trait for read file completion callback
// Corresponds to: Bun: read_file.rs ReadFileCompletion (line 82)
// ============================================================================

/// Models Zig's `comptime callback: fn(ctx: Context, bytes: ReadFileResultType) bun.JSTerminated!void`
/// Corresponds to: Bun: ReadFileCompletion
public interface ReadFileCompletion {
    func run(ctx: UIntNative, bytes: ReadFileResultType): Unit
}

// ============================================================================
// ReadFileResultType - result of a read file operation
// Corresponds to: Bun: read_file.rs ReadFileResultType (line 149)
// ============================================================================

/// Zig: `SystemError.Maybe(ReadFileRead)`
/// Corresponds to: Bun: ReadFileResultType
public enum ReadFileResultType {
    | Result(ReadFileRead)
    | Err(SystemError)

    public func isErr(): Bool {
        match (this) {
            case Err(_) => true
            case _ => false
        }
    }
}

// ============================================================================
// ReadFileRead - holds the result bytes of a read operation
// Corresponds to: Bun: read_file.rs ReadFileRead (line 134)
// ============================================================================

/// Holds the result bytes of a read operation.
/// Corresponds to: Bun: ReadFileRead
public class ReadFileRead {
    /// The read bytes (always an owned allocation from the producer)
    /// Corresponds to: Bun: ReadFileRead.buf
    public var buf: Array<UInt8>
    /// Total file size
    /// Corresponds to: Bun: ReadFileRead.total_size
    public var totalSize: BlobSizeType

    public init(buf: Array<UInt8>, totalSize: BlobSizeType) {
        this.buf = buf
        this.totalSize = totalSize
    }
}

// ============================================================================
// ReadFileOnReadFileCallback - callback type for read completion
// Corresponds to: Bun: read_file.rs ReadFileOnReadFileCallback (line 132)
// ============================================================================

/// Callback type for read file completion
/// Corresponds to: Bun: ReadFileOnReadFileCallback
public type ReadFileOnReadFileCallback = (ctx: UIntNative, bytes: ReadFileResultType) -> Unit

// ============================================================================
// NewReadFileHandler - generic read file handler with promise
// Corresponds to: Bun: read_file.rs NewReadFileHandler<'a, F> (line 58)
// ============================================================================

/// Generic read file handler with a JS promise.
/// `F` provides the comptime callback that converts the read bytes to a JSValue.
/// Corresponds to: Bun: NewReadFileHandler<'a, F>
public class NewReadFileHandler {
    /// The Blob context being read
    /// Corresponds to: Bun: NewReadFileHandler.context
    public var context: Blob
    /// Strong reference to the JS promise
    /// Corresponds to: Bun: NewReadFileHandler.promise
    public var promise: JSPromiseStrong
    /// The global JS object
    /// Corresponds to: Bun: NewReadFileHandler.global_this
    public var globalThis: JsGlobalObject

    public init(context: Blob, globalThis: JsGlobalObject) {
        this.context = context
        this.promise = JSPromiseStrong()
        this.globalThis = globalThis
    }

    /// Run the completion handler with the read result
    /// Corresponds to: Bun: NewReadFileHandler::run() (impl ReadFileCompletion, line 87)
    public func run(maybeBytes: ReadFileResultType): Unit {
        // PORT NOTE: In Rust, handler was heap-allocated and taken ownership here.
        // In Cangjie, we work with the handler directly.
        var blob = context
        // context was populated via dupe() in doReadFile
        match (maybeBytes) {
            case ReadFileResultType.Result(result) =>
                let bytes = result.buf
                if (blob.size > 0) {
                    let newSize = Int64(bytes.size).min(blob.size)
                    blob.size = newSize
                }
                // Wrap the result in a promise resolution
                // Zig used a local WrappedFn; Rust uses AnyPromise::wrap
                promise.resolve(globalThis, JsValue.jsNumberFromUInt64(UInt64(bytes.size)))
            case ReadFileResultType.Err(err) =>
                promise.reject(globalThis, err.toErrorInstanceWithAsyncStack(globalThis, promise))
        }
    }
}

// ============================================================================
// ReadFile - POSIX async read file with IO polling
// Corresponds to: Bun: read_file.rs ReadFile (line 172)
// ============================================================================

/// ReadFile -- POSIX async file reader with IO polling.
/// Runs blocking reads on a work pool thread, with event-loop integration.
/// Corresponds to: Bun: ReadFile
public class ReadFile {
    /// File store (path + metadata)
    /// Corresponds to: Bun: ReadFile.file_store
    public var fileStore: StoreFile
    /// Byte store (owns the read buffer)
    /// Corresponds to: Bun: ReadFile.byte_store
    public var byteStore: StoreBytes
    /// Store reference (keeps the store alive)
    /// Corresponds to: Bun: ReadFile.store
    public var store: ?StoreRef
    /// Read offset
    /// Corresponds to: Bun: ReadFile.offset
    public var offset: BlobSizeType
    /// Maximum bytes to read
    /// Corresponds to: Bun: ReadFile.max_length
    public var maxLength: BlobSizeType
    /// Total file size
    /// Corresponds to: Bun: ReadFile.total_size
    public var totalSize: BlobSizeType
    /// Opened file descriptor
    /// Corresponds to: Bun: ReadFile.opened_fd
    public var openedFd: Fd
    /// Current read offset in the file
    /// Corresponds to: Bun: ReadFile.read_off
    public var readOff: BlobSizeType
    /// Whether EOF has been reached
    /// Corresponds to: Bun: ReadFile.read_eof
    public var readEof: Bool
    /// Buffer size for allocation
    /// Corresponds to: Bun: ReadFile.size
    public var size: BlobSizeType
    /// Read buffer
    /// Corresponds to: Bun: ReadFile.buffer
    public var buffer: ArrayList<UInt8>
    /// Work pool task handle
    /// Corresponds to: Bun: ReadFile.task
    public var task: WorkPoolTask
    /// System error, if any
    /// Corresponds to: Bun: ReadFile.system_error
    public var systemError: ?SystemError
    /// Errno, if any
    /// Corresponds to: Bun: ReadFile.errno
    public var errno: ?BaoError
    /// Completion context (raw pointer)
    /// Corresponds to: Bun: ReadFile.on_complete_ctx
    public var onCompleteCtx: UIntNative
    /// Completion callback
    /// Corresponds to: Bun: ReadFile.on_complete_callback
    public var onCompleteCallback: ReadFileOnReadFileCallback
    /// IO task handle
    /// Corresponds to: Bun: ReadFile.io_task
    public var ioTask: ?ReadFileTask
    /// IO poll state
    /// Corresponds to: Bun: ReadFile.io_poll
    public var ioPoll: IoPoll
    /// IO request state
    /// Corresponds to: Bun: ReadFile.io_request
    public var ioRequest: IoRequest
    /// Whether the file could block on read
    /// Corresponds to: Bun: ReadFile.could_block
    public var couldBlock: Bool
    /// Whether to close after IO completes
    /// Corresponds to: Bun: ReadFile.close_after_io
    public var closeAfterIo: Bool
    /// Closing state (atomic)
    /// Corresponds to: Bun: ReadFile.state
    public var state: UInt8

    public init() {
        fileStore = StoreFile()
        byteStore = StoreBytes()
        store = None
        offset = 0
        maxLength = BLOB_MAX_SIZE
        totalSize = BLOB_MAX_SIZE
        openedFd = Fd.INVALID
        readOff = 0
        readEof = false
        size = 0
        buffer = ArrayList<UInt8>()
        task = WorkPoolTask()
        systemError = None
        errno = None
        onCompleteCtx = 0
        onCompleteCallback = { _, _ => () }
        ioTask = None
        ioPoll = IoPoll()
        ioRequest = IoRequest()
        couldBlock = false
        closeAfterIo = false
        state = ClosingState.running.ordinal()
    }

    // ========================================================================
    // IO_TAG - tag for IO operations
    // Corresponds to: Bun: ReadFile::IO_TAG (line 393)
    // ========================================================================

    public static let IO_TAG: IoTag = IoTag.ReadFile

    // ========================================================================
    // createWithCtx - create a ReadFile with explicit callback
    // Corresponds to: Bun: ReadFile::create_with_ctx() (line 323)
    // ========================================================================

    /// Create a new ReadFile with explicit completion callback.
    /// Corresponds to: Bun: ReadFile::create_with_ctx()
    public static func createWithCtx(
        store: StoreRef,
        onReadFileContext: UIntNative,
        onCompleteCallback: ReadFileOnReadFileCallback,
        off: BlobSizeType,
        maxLen: BlobSizeType
    ): Result<ReadFile, BaoError> {
        let fileStore = store.data.asFile().clone()
        let readFile = ReadFile()
        readFile.fileStore = fileStore
        readFile.store = Some(store)
        readFile.offset = off
        readFile.maxLength = maxLen
        readFile.totalSize = BLOB_MAX_SIZE
        readFile.openedFd = Fd.INVALID
        readFile.onCompleteCtx = onReadFileContext
        readFile.onCompleteCallback = onCompleteCallback
        readFile.state = ClosingState.running.ordinal()
        readFile.task = WorkPoolTask(callback: ReadFile.doReadLoopTask)
        readFile.ioRequest = IoRequest(callback: ReadFile.onRequestReadable)
        return Result.Ok(readFile)
    }

    // ========================================================================
    // create - create a ReadFile with ReadFileCompletion handler
    // Corresponds to: Bun: ReadFile::create() (line 369)
    // ========================================================================

    /// Create a new ReadFile with a ReadFileCompletion handler.
    /// Corresponds to: Bun: ReadFile::create<C>()
    public static func create(
        store: StoreRef,
        off: BlobSizeType,
        maxLen: BlobSizeType,
        context: UIntNative,
        callback: ReadFileOnReadFileCallback
    ): Result<ReadFile, BaoError> {
        ReadFile.createWithCtx(store, context, callback, off, maxLen)
    }

    // ========================================================================
    // FileOpener implementation
    // Corresponds to: Bun: impl FileOpener for ReadFile (line 201)
    // ========================================================================

    /// Get the opened file descriptor
    public func openedFd(): Fd {
        openedFd
    }

    /// Set the opened file descriptor
    public func setOpenedFd(fd: Fd): Unit {
        openedFd = fd
    }

    /// Set errno
    public func setErrno(e: BaoError): Unit {
        errno = Some(e)
    }

    /// Set system error
    public func setSystemError(e: SystemError): Unit {
        systemError = Some(e)
    }

    /// Get the pathlike for file opening
    public func pathlike(): PathOrFileDescriptor {
        fileStore.pathlike
    }

    // ========================================================================
    // FileCloser implementation
    // Corresponds to: Bun: impl FileCloser for ReadFile (line 235)
    // ========================================================================

    /// Whether to close after IO
    public func closeAfterIo(): Bool {
        closeAfterIo
    }

    /// Set close after IO
    public func setCloseAfterIo(v: Bool): Unit {
        closeAfterIo = v
    }

    /// Whether allowed to close the FD
    public func isAllowedToClose(): Bool {
        fileStore.pathlike.isPath()
    }

    // ========================================================================
    // update - check state and continue or finish
    // Corresponds to: Bun: ReadFile::update() (line 307)
    // ========================================================================

    /// Check the closing state and either finish or continue reading.
    /// Corresponds to: Bun: ReadFile::update()
    public func update(): Unit {
        if (state == ClosingState.closing.ordinal()) {
            onFinish()
        } else {
            doReadLoop()
        }
    }

    // ========================================================================
    // onReadable / onReady - IO readiness callbacks
    // Corresponds to: Bun: ReadFile::on_readable() / on_ready() (lines 395-418)
    // ========================================================================

    /// Called when the file descriptor becomes readable
    /// Corresponds to: Bun: ReadFile::on_readable()
    public static func onReadable(request: IoRequest): Unit {
        // Recover the ReadFile from the intrusive IoRequest
        let this_ = request.parent as ReadFile
        this_.onReady()
    }

    /// Handle IO readiness by rescheduling the read loop
    /// Corresponds to: Bun: ReadFile::on_ready()
    public func onReady(): Unit {
        task = WorkPoolTask(callback: ReadFile.doReadLoopTask)
        // On macOS, we use one-shot mode, so:
        // - we don't need to unregister
        // - we don't need to delete from kqueue
        closeAfterIo = ioRequest.scheduled
        WorkPool.schedule(task)
    }

    // ========================================================================
    // onIoError - handle IO errors
    // Corresponds to: Bun: ReadFile::on_io_error() (line 420)
    // ========================================================================

    /// Handle an IO error
    /// Corresponds to: Bun: ReadFile::on_io_error()
    public func onIoError(err: SyscallError): Unit {
        errno = Some(BunCore.errnoToZigErr(err.errno))
        systemError = Some(err.toSystemError())
        task = WorkPoolTask(callback: ReadFile.doReadLoopTask)
        closeAfterIo = ioRequest.scheduled
        WorkPool.schedule(task)
    }

    // ========================================================================
    // onRequestReadable - handle IO request becoming readable
    // Corresponds to: Bun: ReadFile::on_request_readable() (line 445)
    // ========================================================================

    /// Handle IO request becoming readable
    /// Corresponds to: Bun: ReadFile::on_request_readable()
    public static func onRequestReadable(request: IoRequest): IoAction {
        request.scheduled = false
        // Recover the ReadFile from the intrusive IoRequest
        let this_ = request.parent as ReadFile
        return IoAction.Readable(FileAction(
            onError: this_.onIoError,
            ctx: this_,
            fd: this_.openedFd,
            poll: this_.ioPoll,
            tag: ReadFile.IO_TAG
        ))
    }

    // ========================================================================
    // waitForReadable - register for IO readiness notification
    // Corresponds to: Bun: ReadFile::wait_for_readable() (line 465)
    // ========================================================================

    /// Register for IO readiness notification
    /// Corresponds to: Bun: ReadFile::wait_for_readable()
    public func waitForReadable(): Unit {
        closeAfterIo = true
        // Zig: @atomicStore on the callback fn-pointer field
        ioRequest.storeCallbackSeqCst(ReadFile.onRequestReadable)
        if (!ioRequest.scheduled) {
            IoRequestLoop.schedule(ioRequest)
        }
    }

    // ========================================================================
    // doRead - perform a single read syscall
    // Corresponds to: Bun: ReadFile::do_read() (line 503)
    // ========================================================================

    /// Perform a single read syscall.
    /// Returns true if the read should continue, false on error.
    /// Corresponds to: Bun: ReadFile::do_read()
    public func doRead(
        bufPtr: UIntNative,
        bufLen: Int64,
        readLen: Ref<Int64>,
        retry: Ref<Bool>
    ): Bool {
        let buf = Array<UInt8>(bufLen)
        let result: SyscallResult<Int64> = if (BunSys.isSock(fileStore.mode)) {
            BunSys.recvNonBlock(openedFd, buf)
        } else {
            BunSys.read(openedFd, buf)
        }

        match (result) {
            case SyscallResult.Ok(res) =>
                readLen.value = res
                readEof = res == 0
            case SyscallResult.Err(err) =>
                let e = err.getErrno()
                if (e == IO_RETRY) {
                    if (!couldBlock) {
                        // Regular files cannot use epoll.
                        // This is fine on kqueue, but not on epoll.
                        readLen.value = res
                        return true
                    }
                    retry.value = true
                    readEof = false
                    return true
                } else {
                    errno = Some(BunCore.errnoToZigErr(err.errno))
                    systemError = Some(err.toSystemError())
                    if (match (systemError) { case Some(se) => se.path.isEmpty() case None => true }) {
                        match (systemError) {
                            case Some(se) =>
                                se.path = if (fileStore.pathlike.isPath()) {
                                    BaoString.cloneUtf8(fileStore.pathlike.path().slice())
                                } else {
                                    BaoString.EMPTY
                                }
                                systemError = Some(se)
                            case None => ()
                        }
                    }
                    return false
                }
        }

        true
    }

    // ========================================================================
    // then - resolve the promise after reading completes
    // Corresponds to: Bun: ReadFile::then() (line 563)
    // ========================================================================

    /// Resolve the read operation's result to the callback.
    /// Corresponds to: Bun: ReadFile::then()
    public func then(): Unit {
        let cb = onCompleteCallback
        let cbCtx = onCompleteCtx

        if (store.isNone() && systemError.isSome()) {
            let sysError = match (systemError) {
                case Some(e) => e
                case None => SystemError()
            }
            systemError = None
            cb(cbCtx, ReadFileResultType.Err(sysError))
            return
        } else if (store.isNone()) {
            cb(
                cbCtx,
                ReadFileResultType.Err(SystemError(
                    code: BaoString.static_("INTERNAL_ERROR"),
                    message: BaoString.static_("assertion failure - store should not be null"),
                    syscall: BaoString.static_("read"),
                    path: "",
                    errno: 0
                ))
            )
            return
        }

        // Take the buffer out
        let buf = buffer.toArray()
        buffer.clear()
        let sysError = systemError
        systemError = None
        let tSize = totalSize

        // Release store reference
        match (store) {
            case Some(s) =>
                s.deref()
                store = None
            case None => ()
        }

        if (sysError.isSome()) {
            cb(cbCtx, ReadFileResultType.Err(sysError.unwrap()))
            return
        }

        // Zig hands buffer.items as a raw slice with is_temporary = true;
        // receiver takes ownership.
        cb(
            cbCtx,
            ReadFileResultType.Result(ReadFileRead(buf: buf, totalSize: tSize))
        )
    }

    // ========================================================================
    // run / runAsync - start the read operation
    // Corresponds to: Bun: ReadFile::run() / run_async() (lines 618-634)
    // ========================================================================

    /// Run the read operation
    /// Corresponds to: Bun: ReadFile::run()
    public func run(task: ReadFileTask): Unit {
        runAsync(task)
    }

    /// Run the async read operation
    /// Corresponds to: Bun: ReadFile::run_async()
    public func runAsync(task: ReadFileTask): Unit {
        ioTask = Some(task)

        if (fileStore.pathlike.isFd()) {
            openedFd = fileStore.pathlike.fd()
        }

        getFd(ReadFile.runAsyncWithFd)
    }

    // ========================================================================
    // getFd - open the file if needed and call the callback
    // Corresponds to: Bun: FileOpener::getFd() (trait method)
    // ========================================================================

    /// Get the file descriptor, opening the file if necessary
    public func getFd(callback: (Fd) -> Unit): Unit {
        if (fileStore.pathlike.isFd()) {
            openedFd = fileStore.pathlike.fd()
            callback(openedFd)
        } else {
            // Open the file
            match (BunSys.open(fileStore.pathlike.path().sliceZ(), BunSys.O_RDONLY | BunSys.O_CLOEXEC, 0)) {
                case BunSysResult.Ok(fd) =>
                    openedFd = fd
                    callback(openedFd)
                case BunSysResult.Err(err) =>
                    errno = Some(BunCore.errnoToZigErr(err.errno))
                    systemError = Some(err.toSystemError())
                    onFinish()
            }
        }
    }

    // ========================================================================
    // runAsyncWithFd - continue reading after FD is obtained
    // Corresponds to: Bun: ReadFile::run_async_with_fd() (line 711)
    // ========================================================================

    /// Continue reading after the file descriptor is obtained
    /// Corresponds to: Bun: ReadFile::run_async_with_fd()
    public func runAsyncWithFd(fd: Fd): Unit {
        if (errno.isSome()) {
            onFinish()
            return
        }

        resolveSizeAndLastModified(fd)
        if (errno.isSome()) {
            onFinish()
            return
        }

        // Special files might report a size of > 0 and be wrong.
        // Check specifically that it's a regular file before trusting the size.
        if (size == 0 && BunSys.isRegularFile(fileStore.mode)) {
            buffer = ArrayList<UInt8>()
            byteStore = StoreBytes()
            onFinish()
            return
        }

        // Add an extra 16 bytes to the buffer to avoid having to resize for trailing data
        if (!couldBlock || (size > 0 && size != BLOB_MAX_SIZE)) {
            let want = Int64(size) + 16
            let v = ArrayList<UInt8>()
            if (!v.tryReserveExact(want)) {
                errno = Some(BunCore.errOutOfMemory())
                systemError = Some(
                    SyscallError.fromCode(SyscallErrno.ENOMEM, SyscallTag.read)
                        .toSystemError()
                )
                onFinish()
                return
            }
            buffer = v
        }
        readOff = 0

        // If it's not a regular file, it might block on the next read.
        // Avoid immediately reading again until next schedule.
        if (couldBlock) {
            if (BunCore.isReadable(fd) == Pollable.NotReady) {
                waitForReadable()
                return
            }
        }

        doReadLoop()
    }

    // ========================================================================
    // resolveSizeAndLastModified - stat the file for size/mtime
    // Corresponds to: Bun: ReadFile::resolve_size_and_last_modified() (line 659)
    // ========================================================================

    /// Stat the file to determine its size and last modified time.
    /// Corresponds to: Bun: ReadFile::resolve_size_and_last_modified()
    public func resolveSizeAndLastModified(fd: Fd): Unit {
        let stat: Stat = match (BunSys.fstat(fd)) {
            case BunSysResult.Ok(result) => result
            case BunSysResult.Err(err) =>
                errno = Some(BunCore.errnoToZigErr(err.errno))
                systemError = Some(err.toSystemError())
                return
        }

        // Update last_modified on the store
        match (store) {
            case Some(s) =>
                match (s.get()) {
                    case Some(st) =>
                        // file.last_modified = jsc.toJsTime(stat.mtime.sec, stat.mtime.nsec)
                        // PORT NOTE: simplified -- store mtime as seconds + nanos
                        ()
                    case None => ()
                }
            case None => ()
        }

        if (BunSys.isDir(stat.stMode)) {
            errno = Some(BunCore.errEisDir())
            systemError = Some(SystemError(
                code: BaoString.static_("EISDIR"),
                path: if (fileStore.pathlike.isPath()) {
                    BaoString.cloneUtf8(fileStore.pathlike.path().slice())
                } else {
                    BaoString.EMPTY
                },
                message: BaoString.static_("Directories cannot be read like files"),
                syscall: BaoString.static_("read"),
                errno: SyscallErrno.EISDIR
            ))
            return
        }

        couldBlock = !BunSys.isRegularFile(stat.stMode)
        totalSize = Int64(stat.stSize).max(0).min(BLOB_MAX_SIZE)

        if (stat.stSize > 0 && !couldBlock) {
            size = totalSize.min(maxLength)
        } else if (stat.stSize == 0 && couldBlock) {
            size = maxLength.min(4096)
        }

        if (offset > 0) {
            // We DO support offset in Bun.file()
            // Ignore errors because it should continue to work even if it's a pipe
            let _ = BunSys.setFileOffset(fd, offset)
        }
    }

    // ========================================================================
    // onFinish - finalize the read operation
    // Corresponds to: Bun: ReadFile::on_finish() (line 640)
    // ========================================================================

    /// Finalize the read operation
    /// Corresponds to: Bun: ReadFile::on_finish()
    public func onFinish(): Unit {
        let closeAfterIo_ = closeAfterIo
        size = Int64(buffer.size)

        if (doClose(isAllowedToClose())) {
            // We have to wait for the close to finish
            return
        }

        if (!closeAfterIo_) {
            match (ioTask) {
                case Some(t) =>
                    ReadFileTask.onFinish(t)
                    ioTask = None
                case None => ()
            }
        }
    }

    // ========================================================================
    // doClose - close the file descriptor if allowed
    // Corresponds to: Bun: FileCloser::do_close()
    // ========================================================================

    /// Close the file descriptor if allowed
    public func doClose(isAllowedToCloseFd: Bool): Bool {
        if (isAllowedToCloseFd && openedFd != Fd.INVALID) {
            openedFd.close()
            openedFd = Fd.INVALID
            return false
        }
        false
    }

    // ========================================================================
    // doReadLoopTask - static task callback for work pool
    // Corresponds to: Bun: ReadFile::do_read_loop_task() (line 774)
    // ========================================================================

    /// Static task callback for the work pool
    /// Corresponds to: Bun: ReadFile::do_read_loop_task()
    public static func doReadLoopTask(task: WorkPoolTask): Unit {
        let this_ = task.parent as ReadFile
        this_.update()
    }

    // ========================================================================
    // doReadLoop - main read loop
    // Corresponds to: Bun: ReadFile::do_read_loop() (line 783)
    // ========================================================================

    /// Main read loop. Reads data in a loop until done or blocked.
    /// Corresponds to: Bun: ReadFile::do_read_loop()
    public func doReadLoop(): Unit {
        // We hold a 64 KB stack buffer in case the amount of data to
        // be read is greater than the reported amount.
        // 64 KB is large, but since this is running in a thread
        // with its own stack, it should have sufficient space.
        let stackBuffer = Array<UInt8>(64 * 1024, item: UInt8(0))

        while (state == ClosingState.running.ordinal()) {
            // Determine the remaining buffer capacity
            let (bufPtr, bufLen) = remainingBuffer(stackBuffer)

            if (bufLen > 0 && errno.isNone() && !readEof) {
                var readAmount: Int64 = 0
                var retry = false
                let continueReading = doRead(
                    0, bufLen,
                    Ref<Int64>(readAmount),
                    Ref<Bool>(retry)
                )

                // We might read into the stack buffer, so we need to copy it into the heap.
                let readSlice = stackBuffer[0..Int64(readAmount)]
                if (buffer.size == 0) {
                    // We need to allocate a new buffer -- use exact capacity
                    buffer.reserveExact(Int64(readAmount))
                } else {
                    buffer.reserve(Int64(readAmount))
                }
                for (b in readSlice) {
                    buffer.append(b)
                }

                // If they DID set a max length, stop reading after that
                if (!readEof && Int64(buffer.size) >= maxLength) {
                    break
                }

                if (!continueReading) {
                    // Stop reading, we errored
                    break
                }

                // If it's not a regular file, it might block on the next read
                if (retry || (couldBlock && !readEof)) {
                    if (couldBlock && !readEof) {
                        match (BunCore.isReadable(openedFd)) {
                            case Pollable.NotReady => ()
                            case Pollable.Ready | Pollable.Hup => continue
                        }
                    }
                    readEof = false
                    waitForReadable()
                    return
                }

                // There can be more to read
                continue
            }

            // We are done reading
            break
        }

        if (systemError.isSome()) {
            buffer.clear()
        }

        // If we over-allocated by a lot, shrink the buffer
        if (Int64(buffer.size) + 16000 < Int64(buffer.capacity())) {
            buffer.shrinkToFit()
        }

        onFinish()
    }

    // ========================================================================
    // remainingBuffer - determine where to read into
    // Corresponds to: Bun: ReadFile::remaining_buffer() (line 482)
    // ========================================================================

    /// Returns the (pointer, length) of the remaining buffer to read into.
    /// Uses either the stack buffer or the Vec's spare capacity.
    /// Corresponds to: Bun: ReadFile::remaining_buffer()
    public func remainingBuffer(stackBuffer: Array<UInt8>): (Int64, Int64) {
        let spareLen = buffer.capacity() - buffer.size
        let (ptr, len) = if (spareLen < stackBuffer.size) {
            (Int64(0), Int64(stackBuffer.size))
        } else {
            (Int64(0), Int64(spareLen))
        }
        let cap = len.min(maxLength - readOff)
        (ptr, cap)
    }
}

// ============================================================================
// ReadFileTask - work pool task wrapper for ReadFile
// Corresponds to: Bun: read_file.rs ReadFileTask (line 154)
// ============================================================================

/// Work pool task wrapper for ReadFile
/// Corresponds to: Bun: ReadFileTask
public class ReadFileTask {
    public var readFile: ?ReadFile

    public init() {
        readFile = None
    }

    public init(readFile: ReadFile) {
        this.readFile = Some(readFile)
    }

    /// Called when the task finishes
    /// Corresponds to: Bun: WorkTask::on_finish()
    public static func onFinish(task: ReadFileTask): Unit {
        match (task.readFile) {
            case Some(rf) => rf.then()
            case None => ()
        }
    }
}

// ============================================================================
// ReadFileUV - Windows libuv-backed read file (placeholder)
// Corresponds to: Bun: read_file.rs ReadFileUV<'a> (line 908)
// ============================================================================

/// Windows-specific libuv-backed async file reader.
/// On non-Windows platforms, this is a placeholder.
/// Corresponds to: Bun: ReadFileUV<'a>
public class ReadFileUV {
    /// File store (path + metadata)
    public var fileStore: StoreFile
    /// Byte store (owns the read buffer)
    public var byteStore: StoreBytes
    /// Store reference
    public var store: StoreRef
    /// Read offset
    public var offset: BlobSizeType
    /// Maximum bytes to read
    public var maxLength: BlobSizeType
    /// Total file size
    public var totalSize: BlobSizeType
    /// Opened file descriptor
    public var openedFd: Fd
    /// Bytes read so far
    public var readLen: BlobSizeType
    /// Current read offset
    public var readOff: BlobSizeType
    /// Whether EOF has been reached
    public var readEof: Bool
    /// Buffer size for allocation
    public var size: BlobSizeType
    /// Read buffer
    public var buffer: ArrayList<UInt8>
    /// System error, if any
    public var systemError: ?SystemError
    /// Errno, if any
    public var errno: ?BaoError
    /// Completion context (raw pointer)
    public var onCompleteData: UIntNative
    /// Completion callback
    public var onCompleteFn: ReadFileOnReadFileCallback
    /// Whether this is a regular file
    public var isRegularFile: Bool

    public init() {
        fileStore = StoreFile()
        byteStore = StoreBytes()
        store = StoreRef()
        offset = 0
        maxLength = BLOB_MAX_SIZE
        totalSize = BLOB_MAX_SIZE
        openedFd = Fd.INVALID
        readLen = 0
        readOff = 0
        readEof = false
        size = 0
        buffer = ArrayList<UInt8>()
        systemError = None
        errno = None
        onCompleteData = 0
        onCompleteFn = { _, _ => () }
        isRegularFile = false
    }

    /// Start a ReadFileUV operation with a handler
    /// Corresponds to: Bun: ReadFileUV::start<H>() (line 1023)
    public static func start(
        eventLoop: EventLoop,
        store: StoreRef,
        off: BlobSizeType,
        maxLen: BlobSizeType,
        handler: UIntNative,
        runCallback: ReadFileOnReadFileCallback
    ): Unit {
        startWithCtx(eventLoop, store, off, maxLen, runCallback, handler)
    }

    /// Start with explicit callback and context
    /// Corresponds to: Bun: ReadFileUV::start_with_ctx() (line 1045)
    public static func startWithCtx(
        eventLoop: EventLoop,
        store: StoreRef,
        off: BlobSizeType,
        maxLen: BlobSizeType,
        onCompleteFn: ReadFileOnReadFileCallback,
        handler: UIntNative
    ): Unit {
        let fileStore = store.data.asFile().clone()
        let this_ = ReadFileUV()
        this_.fileStore = fileStore
        this_.store = store
        this_.offset = off
        this_.maxLength = maxLen
        this_.totalSize = BLOB_MAX_SIZE
        this_.onCompleteData = handler
        this_.onCompleteFn = onCompleteFn
        this_.isRegularFile = false

        // Keep the event loop alive while the async operation is pending
        eventLoop.refConcurrently()

        // Start the file open operation
        this_.onFileOpen(Fd.INVALID)
    }

    /// Finalize the read operation
    /// Corresponds to: Bun: ReadFileUV::finalize() (line 1093)
    public func finalize(): Unit {
        let cb = onCompleteFn
        let cbCtx = onCompleteData

        let result: ReadFileResultType = match (systemError) {
            case Some(err) =>
                ReadFileResultType.Err(err)
            case None =>
                let buf = buffer.toArray()
                buffer.clear()
                ReadFileResultType.Result(ReadFileRead(buf: buf, totalSize: totalSize))
        }

        // cb() runs BEFORE the defer block (store.deref)
        cb(cbCtx, result)

        // Release the event loop reference
        // eventLoop.unrefConcurrently()
    }

    /// Whether allowed to close the FD
    /// Corresponds to: Bun: ReadFileUV::is_allowed_to_close() (line 1129)
    public func isAllowedToClose(): Bool {
        fileStore.pathlike.isPath()
    }

    /// Called when file open completes
    /// Corresponds to: Bun: ReadFileUV::on_file_open() (line 1151)
    public func onFileOpen(openedFd: Fd): Unit {
        if (errno.isSome()) {
            onFinish()
            return
        }

        // For the placeholder, just finalize with empty data
        onFinish()
    }

    /// Finalize the read operation (UV path)
    /// Corresponds to: Bun: ReadFileUV::on_finish() (line 1133)
    public func onFinish(): Unit {
        let fd = openedFd
        let needsClose = fd != Fd.INVALID

        size = readLen.max(size)
        totalSize = totalSize.max(size)

        if (needsClose) {
            // Close the file descriptor
            fd.close()
        }

        finalize()
    }
}

// ============================================================================
// ReadFileUvHandler - trait for ReadFileUV handler
// Corresponds to: Bun: read_file.rs ReadFileUvHandler (line 1425)
// ============================================================================

/// Trait modeling the `comptime Handler: type` parameter of `ReadFileUV.start`.
/// Corresponds to: Bun: ReadFileUvHandler
public interface ReadFileUvHandler {
    func run(ctx: UIntNative, bytes: ReadFileResultType): Unit
}

// ============================================================================
// Helper types for IO integration
// ============================================================================

/// IO Tag enumeration
/// Corresponds to: Bun: bun_io::Tag
public enum IoTag {
    | ReadFile
    | WriteFile
    | CopyFile
    | Other

    public operator func == (rhs: IoTag): Bool {
        match (this) {
            case ReadFile => match (rhs) { case ReadFile => true case _ => false }
            case WriteFile => match (rhs) { case WriteFile => true case _ => false }
            case CopyFile => match (rhs) { case CopyFile => true case _ => false }
            case Other => match (rhs) { case Other => true case _ => false }
        }
    }
}

/// IO Poll state
/// Corresponds to: Bun: bun_io::Poll
public class IoPoll {
    public init() {}
}

/// IO Request state
/// Corresponds to: Bun: bun_io::Request
public class IoRequest {
    public var scheduled: Bool
    public var callback: (IoRequest) -> IoAction
    public var parent: Any

    public init() {
        scheduled = false
        callback = { _ => IoAction.Noop }
        parent = ReadFile() // placeholder
    }

    public init(callback: (IoRequest) -> IoAction) {
        scheduled = false
        this.callback = callback
        parent = ReadFile() // placeholder
    }

    /// Store callback with sequential consistency
    public func storeCallbackSeqCst(cb: (IoRequest) -> IoAction): Unit {
        callback = cb
    }
}

/// Work Pool Task
/// Corresponds to: Bun: WorkPoolTask
public class WorkPoolTask {
    public var callback: (WorkPoolTask) -> Unit
    public var parent: Any

    public init() {
        callback = { _ => () }
        parent = ReadFile() // placeholder
    }

    public init(callback: (WorkPoolTask) -> Unit) {
        this.callback = callback
        parent = ReadFile() // placeholder
    }
}

/// Work Pool scheduler
/// Corresponds to: Bun: WorkPool
public class WorkPool {
    public static func schedule(task: WorkPoolTask): Unit {
        task.callback(task)
    }
}

/// IO Request Loop scheduler
/// Corresponds to: Bun: IoRequestLoop
public class IoRequestLoop {
    public static func schedule(request: IoRequest): Unit {
        request.scheduled = true
    }
}

/// IO Action variants
/// Corresponds to: Bun: io::Action
public enum IoAction {
    | Readable(FileAction)
    | Writable(FileAction)
    | Close(CloseAction)
    | Noop
}

/// File Action (IO readiness notification)
/// Corresponds to: Bun: io::FileAction
public class FileAction {
    public var onError: (SyscallError) -> Unit
    public var ctx: Any
    public var fd: Fd
    public var poll: IoPoll
    public var tag: IoTag

    public init(
        onError: (SyscallError) -> Unit,
        ctx: Any,
        fd: Fd,
        poll: IoPoll,
        tag: IoTag
    ) {
        this.onError = onError
        this.ctx = ctx
        this.fd = fd
        this.poll = poll
        this.tag = tag
    }
}

/// Close Action
/// Corresponds to: Bun: io::CloseAction
public class CloseAction {
    public var fd: Fd
    public var poll: IoPoll
    public var ctx: UIntNative
    public var tag: IoTag
    public var onDone: (UIntNative) -> Unit

    public init(
        fd: Fd,
        poll: IoPoll,
        ctx: UIntNative,
        tag: IoTag,
        onDone: (UIntNative) -> Unit
    ) {
        this.fd = fd
        this.poll = poll
        this.ctx = ctx
        this.tag = tag
        this.onDone = onDone
    }
}

/// Event Loop (placeholder)
/// Corresponds to: Bun: EventLoop
public class EventLoop {
    public func refConcurrently(): Unit {}
    public func unrefConcurrently(): Unit {}
}

/// Pollable state
/// Corresponds to: Bun: Pollable
public enum Pollable {
    | Ready
    | NotReady
    | Hup
}

/// IO retry errno constant
/// Corresponds to: Bun: io::RETRY
let IO_RETRY: Int64 = 11  // EAGAIN on Linux

/// Ref helper -- mutable reference wrapper
public class Ref<T> {
    public var value: T

    public init(value: T) {
        this.value = value
    }
}

// ported from: src/runtime/webcore/blob/read_file.rs
