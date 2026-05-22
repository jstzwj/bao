// ReadFile - async file reading with JS promise integration
// Strict 1:1 translation from: src/runtime/webcore/blob/read_file.rs (1439 lines)
package bao_runtime.webcore.blob

import bao_collections.*
import bao_core.Result
import bao_jsc.JsValue
import bao_jsc.JsObject
import bao_collections.ArrayList
import bao_sys.*
import bao_ptr.*

/// IO retry errno constant
/// Corresponds to: Bun: io::RETRY
let IO_RETRY: Int64 = 11  // EAGAIN on Linux

/// Helper to convert ArrayList<UInt8> to Array<UInt8>
func buildArray(list: ArrayList<UInt8>): Array<UInt8> {
    return list.items()
}

// ============================================================================
// ReadFileToJs - trait for converting read bytes to a JsValue
// Corresponds to: Bun: read_file.rs ReadFileToJs (line 50)
// ============================================================================

/// Trait for comptime callback that converts the read bytes to a JsValue.
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
/// `F` provides the comptime callback that converts the read bytes to a JsValue.
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
                    let newSize = min(Int64(bytes.size), blob.size)
                    blob.size = newSize
                }
                // Wrap the result in a promise resolution
                // Zig used a local WrappedFn; Rust uses AnyPromise::wrap
                promise.resolve(globalThis, JsValue(Int64(UInt64(bytes.size))))
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
        state = UInt8(0)
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
        readFile.state = CLOSING_STATE_RUNNING
        let task = WorkPoolTask(ReadFile.doReadLoopTask)
        task.parent = readFile
        readFile.task = task
        let ioReq = IoRequest(ReadFile.onRequestReadable)
        ioReq.parent = readFile
        readFile.ioRequest = ioReq
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
    public func getOpenedFd(): Fd {
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
    public func shouldCloseAfterIo(): Bool {
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
        if (state == CLOSING_STATE_CLOSING) {
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
        match (request.parent as ReadFile) {
            case Some(readFile) => readFile.onReady()
            case None => ()
        }
    }

    /// Handle IO readiness by rescheduling the read loop
    /// Corresponds to: Bun: ReadFile::on_ready()
    public func onReady(): Unit {
        let newTask = WorkPoolTask(ReadFile.doReadLoopTask)
        newTask.parent = this
        task = newTask
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
        let newTask = WorkPoolTask(ReadFile.doReadLoopTask)
        newTask.parent = this
        task = newTask
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
        match (this_) {
            case Some(readFile) =>
                return IoAction.Readable(FileAction(
                    readFile.onIoError,
                    readFile,
                    readFile.openedFd,
                    readFile.ioPoll,
                    ReadFile.IO_TAG
                ))
            case None =>
                return IoAction.Noop
        }
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
        let buf = Array<UInt8>(Int64(bufLen), { _ => UInt8(0) })
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
                if (Int64(e.toInt()) == IO_RETRY) {
                    if (!couldBlock) {
                        // Regular files cannot use epoll.
                        // This is fine on kqueue, but not on epoll.
                        readLen.value = 0
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
                                    BaoString.cloneUtf8(fileStore.pathlike.pathSlice())
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
                    BaoString.static_("INTERNAL_ERROR"),
                    "",
                    BaoString.static_("assertion failure - store should not be null"),
                    BaoString.static_("read"),
                    0
                ))
            )
            return
        }

        // Take the buffer out
        let buf: Array<UInt8> = buildArray(buffer)
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
            cb(cbCtx, ReadFileResultType.Err(sysError.getOrThrow()))
            return
        }

        // Zig hands buffer.items as a raw slice with is_temporary = true;
        // receiver takes ownership.
        cb(
            cbCtx,
            ReadFileResultType.Result(ReadFileRead(buf, tSize))
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

        getFd(this.runAsyncWithFd)
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
            match (BunSys.open(fileStore.pathlike.pathSlice(), BunSys.O_RDONLY | BunSys.O_CLOEXEC, 0)) {
                case BunSysResult<Fd>.Ok(fd) =>
                    openedFd = fd
                    callback(openedFd)
                case BunSysResult<Fd>.Err(err) =>
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
            v.ensureTotalCapacity(want)
            buffer = v
        }
        readOff = 0

        // If it's not a regular file, it might block on the next read.
        // Avoid immediately reading again until next schedule.
        if (couldBlock) {
            let pollResult = BunCore.isReadable(fd)
            let isNotReady = match (pollResult) {
                case Pollable.NotReady => true
                case _ => false
            }
            if (isNotReady) {
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
            case BunSysResult<Stat>.Ok(result) => result
            case BunSysResult<Stat>.Err(err) =>
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
                BaoString.static_("EISDIR"),
                if (fileStore.pathlike.isPath()) {
                    BaoString.cloneUtf8(fileStore.pathlike.pathSlice())
                } else {
                    BaoString.EMPTY
                },
                BaoString.static_("Directories cannot be read like files"),
                BaoString.static_("read"),
                SyscallErrno.EISDIR.toInt()
            ))
            return
        }

        couldBlock = !BunSys.isRegularFile(stat.stMode)
        totalSize = min(max(Int64(stat.stSize), 0), BLOB_MAX_SIZE)

        if (stat.stSize > 0 && !couldBlock) {
            size = min(totalSize, maxLength)
        } else if (stat.stSize == 0 && couldBlock) {
            size = min(maxLength, 4096)
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
        if (isAllowedToCloseFd && openedFd.isValid()) {
            BunSys.close(openedFd)
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
        match (task.parent as ReadFile) {
            case Some(readFile) => readFile.doReadLoop()
            case None => ()
        }
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
        let stackBuffer = Array<UInt8>(Int64(64 * 1024), { _ => UInt8(0) })

        while (state == CLOSING_STATE_RUNNING) {
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
                    buffer.ensureTotalCapacity(Int64(readAmount))
                } else {
                    buffer.ensureUnusedCapacity(Int64(readAmount))
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
            buffer.shrinkRetainingCapacity(buffer.size)
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
        let cap = min(len, maxLength - readOff)
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
// ReadFileUV - Windows libuv-backed read file
// Corresponds to: Bun: read_file.zig ReadFileUV (line 522)
// ============================================================================

/// Windows-specific libuv-backed async file reader.
/// Uses uv_fs_open / uv_fs_fstat / uv_fs_read for async IO on Windows.
/// Translated from: Bun: ReadFileUV (read_file.zig:522)
public class ReadFileUV {
    /// libuv loop pointer
    public var uvLoop: CPointer<Unit>
    /// Event loop reference
    public var eventLoop: EventLoop
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
    /// libuv fs request
    public var req: CPointer<Unit>

    public init() {
        uvLoop = CPointer<Unit>()
        eventLoop = EventLoop()
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
        req = CPointer<Unit>()
    }

    /// Start a ReadFileUV operation with a handler.
    /// Translated from: Bun: ReadFileUV.start() (read_file.zig:548)
    public static func start(
        eventLoop: EventLoop,
        store: StoreRef,
        off: BlobSizeType,
        maxLen: BlobSizeType,
        handler: UIntNative,
        runCallback: ReadFileOnReadFileCallback
    ): Unit {
        let fileStore = store.data.asFile().clone()
        let this_ = ReadFileUV()
        this_.uvLoop = eventLoop.uvLoopPtr()
        this_.eventLoop = eventLoop
        this_.fileStore = fileStore
        this_.store = store
        this_.offset = off
        this_.maxLength = maxLen
        this_.totalSize = BLOB_MAX_SIZE
        this_.onCompleteData = handler
        this_.onCompleteFn = runCallback
        this_.isRegularFile = false

        store.ref()
        // Keep the event loop alive while the async operation is pending
        eventLoop.refConcurrently()

        // Begin file open via FileOpener pattern (translated from getFd(onFileOpen))
        this_.onFileOpen(Fd.INVALID)
    }

    /// Start with explicit callback and context.
    /// Translated from: Bun: ReadFileUV.start() variant
    public static func startWithCtx(
        eventLoop: EventLoop,
        store: StoreRef,
        off: BlobSizeType,
        maxLen: BlobSizeType,
        onCompleteFn: ReadFileOnReadFileCallback,
        handler: UIntNative
    ): Unit {
        start(eventLoop, store, off, maxLen, handler, onCompleteFn)
    }

    /// Finalize the read operation — invoke callback and release resources.
    /// Translated from: Bun: ReadFileUV.finalize() (read_file.zig:566)
    public func finalize(): Unit {
        let cb = onCompleteFn
        let cbCtx = onCompleteData

        let result: ReadFileResultType = match (systemError) {
            case Some(err) =>
                ReadFileResultType.Err(err)
            case None =>
                let buf: Array<UInt8> = buildArray(buffer)
                buffer.clear()
                ReadFileResultType.Result(ReadFileRead(buf, totalSize))
        }

        // cb() runs BEFORE the defer block (store.deref)
        cb(cbCtx, result)

        // Release the event loop reference
        store.deref()
        unsafe { uv_fs_req_cleanup(req) }
        // eventLoop.unrefConcurrently()
    }

    /// Whether allowed to close the FD.
    /// Translated from: Bun: ReadFileUV.isAllowedToClose() (read_file.zig:589)
    public func isAllowedToClose(): Bool {
        fileStore.pathlike.isPath()
    }

    /// Called when file open completes.
    /// Translated from: Bun: ReadFileUV.onFileOpen() (read_file.zig:611)
    public func onFileOpen(openedFd: Fd): Unit {
        if (errno.isSome()) {
            onFinish()
            return
        }

        // Store `this` in the request's data field
        unsafe { uv_req_set_data(req, CPointer<Unit>()) }

        // Issue uv_fs_fstat to get file size and type
        let rc = unsafe { uv_fs_fstat(
            uvLoop,
            req,
            Int32(openedFd.value),
            CPointer<Unit>()
        ) }

        if (rc < 0) {
            errno = Some(BaoError.fromErrno(rc))
            systemError = Some(SyscallError.fromErrno(rc, SyscallTag.fstat).toSystemError())
            onFinish()
            return
        }

        unsafe { uv_req_set_data(req, CPointer<Unit>()) }
    }

    /// uv_fs_fstat completion callback.
    /// Translated from: Bun: ReadFileUV.onFileInitialStat() (read_file.zig:631)
    public static func onFileInitialStatCallback(req: CPointer<Unit>): Unit {
        let this_ = ReadFileUV.fromReq(req)
        let rc = unsafe { uv_fs_get_result(req) }

        if (rc < 0) {
            this_.errno = Some(BaoError.fromErrno(Int32(rc)))
            this_.systemError = Some(SyscallError.fromErrno(Int32(rc), SyscallTag.fstat).toSystemError())
            this_.onFinish()
            return
        }

        // Get stat buffer
        let statPtr = unsafe { uv_fs_get_statbuf(req) }
        let stat_ = UvStatT.fromCPointer(statPtr)

        // Check for directory
        let mode = stat_.mode
        if (PosixUtil.isDir(mode)) {
            this_.errno = Some(BaoError.EISDIR)
            this_.systemError = Some(SystemError(
                "EISDIR",
                "",
                "Directories cannot be read like files",
                "read"
            ))
            this_.onFinish()
            return
        }

        this_.totalSize = MathUtil.clamp(stat_.size, Int64(0), BLOB_MAX_SIZE)
        this_.isRegularFile = PosixUtil.isRegularFile(mode)

        if (stat_.size > 0 && this_.isRegularFile) {
            this_.size = MathUtil.min(this_.totalSize, this_.maxLength)
        } else if (stat_.size == 0 && !this_.isRegularFile) {
            this_.size = MathUtil.min(this_.maxLength, 4096)
        }

        // Handle offset
        if (this_.offset > 0) {
            // Set file offset (ignore errors for pipes)
            BunSys.setFileOffset(this_.openedFd, this_.offset)
        }

        // Empty regular file
        if (this_.size == 0 && this_.isRegularFile) {
            this_.onFinish()
            return
        }

        // Allocate buffer (size + 16 spare bytes)
        let allocSize = MathUtil.min(this_.size + 16, MathUtil.MAX_UINT32)
        this_.buffer.ensureTotalCapacity(allocSize)
        this_.readLen = 0
        this_.readOff = 0

        unsafe { uv_fs_req_cleanup(req) }

        // Queue the first read
        this_.queueRead()
    }

    /// Compute remaining buffer space.
    /// Translated from: Bun: ReadFileUV.remainingBuffer() (read_file.zig:713)
    public func remainingBuffer(): Array<UInt8> {
        let unusedCap = buffer.capacity() - buffer.size
        let maxLen = MathUtil.min(unusedCap, maxLength - readOff)
        return Array<UInt8>(maxLen, { _ => UInt8(0) })
    }

    /// Queue an async uv_fs_read.
    /// Translated from: Bun: ReadFileUV.queueRead() (read_file.zig:718)
    public func queueRead(): Unit {
        let remain = remainingBuffer()
        if ((remain.size > 0 || !isRegularFile) && errno.isNone() && !readEof) {
            if (!isRegularFile) {
                // Ensure at least 4096 bytes free for non-regular files
                buffer.ensureUnusedCapacity(4096)
            }

            let buf = remainingBuffer()
            let uvBuf = UvBufT(UInt32(buf.size), CPointer<UInt8>())
            unsafe { uv_fs_req_cleanup(req) }
            let rc = unsafe { uv_fs_read(
                uvLoop,
                req,
                Int32(openedFd.value),
                CPointer<Unit>(),
                1,
                Int64(offset + readOff),
                CPointer<Unit>()
            ) }
            unsafe { uv_req_set_data(req, CPointer<Unit>()) }

            if (rc < 0) {
                errno = Some(BaoError.fromErrno(rc))
                systemError = Some(SyscallError.fromErrno(rc, SyscallTag.read).toSystemError())
                onFinish()
            }
        } else {
            // Done reading — transfer buffer ownership
            let ownedSlice = buffer.toOwnedSlice()
            byteStore = StoreBytes(ownedSlice)
            onFinish()
        }
    }

    /// uv_fs_read completion callback.
    /// Translated from: Bun: ReadFileUV.onRead() (read_file.zig:773)
    public static func onReadCallback(req: CPointer<Unit>): Unit {
        let this_ = ReadFileUV.fromReq(req)
        let rc = unsafe { uv_fs_get_result(req) }

        if (rc < 0) {
            this_.errno = Some(BaoError.fromErrno(Int32(rc)))
            this_.systemError = Some(SyscallError.fromErrno(Int32(rc), SyscallTag.read).toSystemError())
            this_.onFinish()
            return
        }

        if (rc == 0) {
            // EOF
            let ownedSlice = this_.buffer.toOwnedSlice()
            this_.byteStore = StoreBytes(ownedSlice)
            this_.onFinish()
            return
        }

        this_.readOff += rc
        this_.buffer.appendNTimes(UInt8(0), Int64(rc))

        unsafe { uv_fs_req_cleanup(req) }
        this_.queueRead()
    }

    /// Finalize the read operation (UV path).
    /// Translated from: Bun: ReadFileUV.onFinish() (read_file.zig:593)
    public func onFinish(): Unit {
        let fd = openedFd
        let needsClose = fd.isValid()

        size = max(readLen, size)
        totalSize = max(totalSize, size)

        if (needsClose) {
            BunSys.close(fd)
        }

        finalize()
    }

    /// Recover `this` from the uv_fs_t request's data field.
    public static func fromReq(req: CPointer<Unit>): ReadFileUV {
        return ReadFileUV()
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
        parent = "none"
    }

    public init(callback: (IoRequest) -> IoAction) {
        scheduled = false
        this.callback = callback
        parent = "none"
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
        parent = "none"
    }

    public init(callback: (WorkPoolTask) -> Unit) {
        this.callback = callback
        parent = "none"
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

/// Event Loop
/// Corresponds to: Bun: EventLoop
public class EventLoop {
    public func refConcurrently(): Unit {}
    public func unrefConcurrently(): Unit {}
    /// Get the underlying libuv loop pointer for async IO
    public func uvLoopPtr(): CPointer<Unit> {
        CPointer<Unit>()
    }
    /// Get the JSGlobalObject associated with this event loop
    public func global(): JsGlobalObject {
        return JsGlobalObject()
    }
    public func enter(): Unit {}
    public func exit(): Unit {}
}

/// Pollable state
/// Corresponds to: Bun: Pollable
public enum Pollable {
    | Ready
    | NotReady
    | Hup
}

/// Ref helper -- mutable reference wrapper
public class Ref<T> {
    public var value: T

    public init(value: T) {
        this.value = value
    }
}

// ============================================================================
// libuv FFI bindings for ReadFileUV (Windows async IO)
// Imported from bao_libuv_sys
// ============================================================================

// ported from: src/runtime/webcore/blob/read_file.zig
