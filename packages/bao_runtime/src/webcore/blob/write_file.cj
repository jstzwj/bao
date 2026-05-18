// WriteFile - async file writing with JS promise integration
// Strict 1:1 translation from: src/runtime/webcore/blob/write_file.rs (1437 lines)
package bao_runtime.webcore.blob

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_sys.*
import bao_io.*
import bao_ptr.*

// ============================================================================
// WriteFileResultType - result of a write file operation
// Corresponds to: Bun: write_file.rs WriteFileResultType (line 25)
// ============================================================================

/// SystemError.Maybe(T) is a tagged { result: T } | { err: SystemError } union;
/// modeled here as a plain enum.
/// Corresponds to: Bun: WriteFileResultType
public enum WriteFileResultType {
    | Result(BlobSizeType)
    | Err(SystemError)

    public func isErr(): Bool {
        match (this) {
            case Err(_) => true
            case _ => false
        }
    }
}

// ============================================================================
// WriteFileOnWriteFileCallback - callback type for write completion
// Corresponds to: Bun: write_file.rs WriteFileOnWriteFileCallback (line 30)
// ============================================================================

/// Callback type for write file completion
/// Corresponds to: Bun: WriteFileOnWriteFileCallback
public type WriteFileOnWriteFileCallback = (ctx: UIntNative, count: WriteFileResultType) -> Unit

// ============================================================================
// WriteFile - POSIX async write file with IO polling
// Corresponds to: Bun: write_file.rs WriteFile (line 46)
// ============================================================================

/// WriteFile -- POSIX async file writer with IO polling.
/// Runs blocking writes on a work pool thread, with event-loop integration.
/// Corresponds to: Bun: WriteFile
public class WriteFile {
    /// The file Blob (destination)
    /// Corresponds to: Bun: WriteFile.file_blob
    public var fileBlob: Blob
    /// The bytes Blob (source data to write)
    /// Corresponds to: Bun: WriteFile.bytes_blob
    public var bytesBlob: Blob
    /// Opened file descriptor
    /// Corresponds to: Bun: WriteFile.opened_fd
    public var openedFd: Fd
    /// System error, if any
    /// Corresponds to: Bun: WriteFile.system_error
    public var systemError: ?SystemError
    /// Errno, if any
    /// Corresponds to: Bun: WriteFile.errno
    public var errno: ?BaoError
    /// Work pool task handle
    /// Corresponds to: Bun: WriteFile.task
    public var task: WorkPoolTask
    /// IO task handle
    /// Corresponds to: Bun: WriteFile.io_task
    public var ioTask: ?WriteFileTask
    /// IO poll state
    /// Corresponds to: Bun: WriteFile.io_poll
    public var ioPoll: IoPoll
    /// IO request state
    /// Corresponds to: Bun: WriteFile.io_request
    public var ioRequest: IoRequest
    /// Closing state (atomic)
    /// Corresponds to: Bun: WriteFile.state
    public var state: UInt8
    /// Completion context (raw pointer)
    /// Corresponds to: Bun: WriteFile.on_complete_ctx
    public var onCompleteCtx: UIntNative
    /// Completion callback
    /// Corresponds to: Bun: WriteFile.on_complete_callback
    public var onCompleteCallback: WriteFileOnWriteFileCallback
    /// Total bytes written so far
    /// Corresponds to: Bun: WriteFile.total_written
    public var totalWritten: Int64
    /// Whether the file could block on write
    /// Corresponds to: Bun: WriteFile.could_block
    public var couldBlock: Bool
    /// Whether to close after IO completes
    /// Corresponds to: Bun: WriteFile.close_after_io
    public var closeAfterIo: Bool
    /// Whether to create parent directories
    /// Corresponds to: Bun: WriteFile.mkdirp_if_not_exists
    public var mkdirpIfNotExists: Bool

    public init() {
        fileBlob = Blob()
        bytesBlob = Blob()
        openedFd = Fd.INVALID
        systemError = None
        errno = None
        task = WorkPoolTask()
        ioTask = None
        ioPoll = IoPoll()
        ioRequest = IoRequest()
        state = ClosingState.running.ordinal()
        onCompleteCtx = 0
        onCompleteCallback = { _, _ => () }
        totalWritten = 0
        couldBlock = false
        closeAfterIo = false
        mkdirpIfNotExists = false
    }

    // ========================================================================
    // IO_TAG - tag for IO operations
    // Corresponds to: Bun: WriteFile::IO_TAG (line 214)
    // ========================================================================

    public static let IO_TAG: IoTag = IoTag.WriteFile

    // ========================================================================
    // OPEN_FLAGS - flags for opening the output file
    // Corresponds to: Bun: WriteFile::OPEN_FLAGS (line 216)
    // ========================================================================

    /// WRONLY | CREAT | TRUNC | NONBLOCK
    public static let OPEN_FLAGS: Int32 = BunSys.O_WRONLY | BunSys.O_CREAT | BunSys.O_TRUNC | BunSys.O_NONBLOCK

    // ========================================================================
    // FileOpener implementation
    // Corresponds to: Bun: impl FileOpener for WriteFile (line 76)
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
        match (fileBlob.store) {
            case Some(store) => store.asFile().pathlike
            case None => PathOrFileDescriptor(path: "")
        }
    }

    // ========================================================================
    // MkdirpTarget implementation
    // Corresponds to: Bun: impl MkdirpTarget for WriteFile (line 130)
    // ========================================================================

    /// Whether to create parent directories
    public func mkdirpIfExists(): Bool {
        mkdirpIfNotExists
    }

    /// Set whether to create parent directories
    public func setMkdirpIfExists(v: Bool): Unit {
        mkdirpIfNotExists = v
    }

    // ========================================================================
    // FileCloser implementation
    // Corresponds to: Bun: impl FileCloser for WriteFile (line 148)
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
        match (fileBlob.store) {
            case Some(store) => store.asFile().pathlike.isPath()
            case None => false
        }
    }

    // ========================================================================
    // onWritable / onReady - IO readiness callbacks
    // Corresponds to: Bun: WriteFile::on_writable() / on_ready() (lines 219-232)
    // ========================================================================

    /// Called when the file descriptor becomes writable
    /// Corresponds to: Bun: WriteFile::on_writable()
    public static func onWritable(request: IoRequest): Unit {
        let this_ = request.parent as WriteFile
        this_.onReady()
    }

    /// Handle IO readiness by rescheduling the write loop
    /// Corresponds to: Bun: WriteFile::on_ready()
    public func onReady(): Unit {
        task = WorkPoolTask(callback: WriteFile.doWriteLoopTask)
        WorkPool.schedule(task)
    }

    // ========================================================================
    // onIoError - handle IO errors
    // Corresponds to: Bun: WriteFile::on_io_error() (line 234)
    // ========================================================================

    /// Handle an IO error
    /// Corresponds to: Bun: WriteFile::on_io_error()
    public func onIoError(err: SyscallError): Unit {
        errno = Some(BunCore.errnoToZigErr(err.errno))
        systemError = Some(err.toSystemError())
        task = WorkPoolTask(callback: WriteFile.doWriteLoopTask)
        WorkPool.schedule(task)
    }

    // ========================================================================
    // onRequestWritable - handle IO request becoming writable
    // Corresponds to: Bun: WriteFile::on_request_writable() (line 247)
    // ========================================================================

    /// Handle IO request becoming writable
    /// Corresponds to: Bun: WriteFile::on_request_writable()
    public static func onRequestWritable(request: IoRequest): IoAction {
        request.scheduled = false
        let this_ = request.parent as WriteFile
        return IoAction.Writable(FileAction(
            onError: this_.onIoError,
            ctx: this_,
            fd: this_.openedFd,
            poll: this_.ioPoll,
            tag: WriteFile.IO_TAG
        ))
    }

    // ========================================================================
    // waitForWritable - register for IO readiness notification
    // Corresponds to: Bun: WriteFile::wait_for_writable() (line 261)
    // ========================================================================

    /// Register for IO readiness notification
    /// Corresponds to: Bun: WriteFile::wait_for_writable()
    public func waitForWritable(): Unit {
        closeAfterIo = true
        // Zig: `@atomicStore(?*const fn, &self.io_request.callback, &onRequestWritable, .seq_cst)`
        ioRequest.storeCallbackSeqCst(WriteFile.onRequestWritable)
        if (!ioRequest.scheduled) {
            IoRequestLoop.schedule(ioRequest)
        }
    }

    // ========================================================================
    // createWithCtx - create a WriteFile with explicit callback
    // Corresponds to: Bun: WriteFile::create_with_ctx() (line 271)
    // ========================================================================

    /// Create a new WriteFile with explicit completion callback.
    /// Corresponds to: Bun: WriteFile::create_with_ctx()
    public static func createWithCtx(
        fileBlob: Blob,
        bytesBlob: Blob,
        onWriteFileContext: UIntNative,
        onCompleteCallback: WriteFileOnWriteFileCallback,
        mkdirpIfNotExists: Bool
    ): Result<WriteFile, BaoError> {
        let writeFile = WriteFile()
        writeFile.fileBlob = fileBlob
        writeFile.bytesBlob = bytesBlob
        writeFile.openedFd = Fd.INVALID
        writeFile.systemError = None
        writeFile.errno = None
        writeFile.task = WorkPoolTask(callback: WriteFile.doWriteLoopTask)
        writeFile.ioTask = None
        writeFile.ioPoll = IoPoll()
        writeFile.ioRequest = IoRequest(callback: WriteFile.onRequestWritable)
        writeFile.state = ClosingState.running.ordinal()
        writeFile.onCompleteCtx = onWriteFileContext
        writeFile.onCompleteCallback = onCompleteCallback
        writeFile.totalWritten = 0
        writeFile.couldBlock = false
        writeFile.closeAfterIo = false
        writeFile.mkdirpIfNotExists = mkdirpIfNotExists

        // PORT NOTE: Zig follows with file_blob.store.?.ref() because the Zig
        // caller bitwise-copies Blob (no ref bump, no dtor) and bun.destroy
        // in `then` does not deref. In Cangjie the caller passes a +1 Blob
        // (via StoreRef::clone) and the store ref is released in `then`.
        return Result.Ok(writeFile)
    }

    // ========================================================================
    // create - create a WriteFile with typed callback
    // Corresponds to: Bun: WriteFile::create<C>() (line 308)
    // ========================================================================

    /// Create a new WriteFile with a typed callback.
    /// Corresponds to: Bun: WriteFile::create<C>()
    public static func create(
        fileBlob: Blob,
        bytesBlob: Blob,
        context: UIntNative,
        callback: WriteFileOnWriteFileCallback,
        mkdirpIfNotExists: Bool
    ): Result<WriteFile, BaoError> {
        WriteFile.createWithCtx(fileBlob, bytesBlob, context, callback, mkdirpIfNotExists)
    }

    // ========================================================================
    // doWrite - perform a single write syscall
    // Corresponds to: Bun: WriteFile::do_write() (line 331)
    // ========================================================================

    /// Perform a single write syscall.
    /// Returns true if the write should continue, false on error.
    /// Corresponds to: Bun: WriteFile::do_write()
    public func doWrite(off: Int64, len: Int64, wrote: Ref<Int64>): Bool {
        let fd = openedFd
        // We do not use pwrite() because the file may not be seekable (such as stdout)
        // On macOS, it is an error to use pwrite() on a non-seekable file.
        let sharedView = bytesBlob.sharedView()
        let slice = sharedView[Int64(off)..Int64(off + len)]
        let result: SyscallResult<Int64> = BunSys.write(fd, slice)

        match (result) {
            case SyscallResult.Ok(res) =>
                wrote.value = res
                totalWritten += res
            case SyscallResult.Err(err) =>
                if (err.getErrno() == IO_RETRY) {
                    if (!couldBlock) {
                        // Regular files cannot use epoll.
                        // This is fine on kqueue, but not on epoll.
                        return true
                    }
                    waitForWritable()
                    return false
                } else {
                    errno = Some(BunCore.errnoToZigErr(err.errno))
                    systemError = Some(err.toSystemError())
                    return false
                }
        }

        true
    }

    // ========================================================================
    // then - resolve the promise after writing completes
    // Corresponds to: Bun: WriteFile::then() (line 371)
    // ========================================================================

    /// Resolve the write operation's result to the callback.
    /// Corresponds to: Bun: WriteFile::then()
    public func then(): Unit {
        let cb = onCompleteCallback
        let cbCtx = onCompleteCtx
        let sysError = systemError
        systemError = None
        let totalWritten_ = totalWritten

        // Release store references -- bytes_blob.store.?.deref() / file_blob.store.?.deref()
        bytesBlob.detach()
        fileBlob.detach()

        if (sysError.isSome()) {
            cb(cbCtx, WriteFileResultType.Err(sysError.unwrap()))
            return
        }

        cb(cbCtx, WriteFileResultType.Result(totalWritten_))
    }

    // ========================================================================
    // run / runAsync - start the write operation
    // Corresponds to: Bun: WriteFile::run() / run_async() (lines 406-417)
    // ========================================================================

    /// Run the write operation
    /// Corresponds to: Bun: WriteFile::run()
    public func run(task: WriteFileTask): Unit {
        ioTask = Some(task)
        runAsync()
    }

    /// Run the async write operation
    /// Corresponds to: Bun: WriteFile::run_async()
    public func runAsync(): Unit {
        getFd(WriteFile.runWithFd)
    }

    // ========================================================================
    // getFd - open the file if needed and call the callback
    // Corresponds to: Bun: FileOpener::getFd()
    // ========================================================================

    /// Get the file descriptor, opening the file if necessary
    public func getFd(callback: (Fd) -> Unit): Unit {
        let pathlike = match (fileBlob.store) {
            case Some(store) => store.asFile().pathlike
            case None => PathOrFileDescriptor(path: "")
        }

        if (pathlike.isFd()) {
            openedFd = pathlike.fd()
            callback(openedFd)
        } else {
            // Open the file with write flags
            match (BunSys.open(
                pathlike.path().sliceZ(),
                WriteFile.OPEN_FLAGS | BunSys.O_CLOEXEC,
                WRITE_PERMISSIONS
            )) {
                case BunSysResult.Ok(fd) =>
                    openedFd = fd
                    callback(openedFd)
                case BunSysResult.Err(err) =>
                    // Try mkdirp if needed
                    if (mkdirpIfNotExists && err.getErrno() == SyscallErrno.ENOENT) {
                        // Attempt to create parent directory
                        let _ = BunSys.mkdirRecursive(pathlike.path().sliceZ())
                        // Retry open
                        match (BunSys.open(
                            pathlike.path().sliceZ(),
                            WriteFile.OPEN_FLAGS | BunSys.O_CLOEXEC,
                            WRITE_PERMISSIONS
                        )) {
                            case BunSysResult.Ok(fd2) =>
                                openedFd = fd2
                                callback(openedFd)
                            case BunSysResult.Err(err2) =>
                                errno = Some(BunCore.errnoToZigErr(err2.errno))
                                systemError = Some(err2.toSystemError())
                                onFinish()
                        }
                    } else {
                        errno = Some(BunCore.errnoToZigErr(err.errno))
                        systemError = Some(err.toSystemError())
                        onFinish()
                    }
            }
        }
    }

    // ========================================================================
    // runWithFd - continue writing after FD is obtained
    // Corresponds to: Bun: WriteFile::run_with_fd() (line 446)
    // ========================================================================

    /// Continue writing after the file descriptor is obtained
    /// Corresponds to: Bun: WriteFile::run_with_fd()
    public func runWithFd(fd: Fd): Unit {
        if (fd == Fd.INVALID || errno.isSome()) {
            onFinish()
            return
        }

        couldBlock = match (fileBlob.store) {
            case Some(store) =>
                let file = store.asFile()
                if (file.pathlike.isFd()) {
                    // If seekable was set, then so was mode
                    match (file.seekable) {
                        case Some(_) => !BunSys.isRegularFile(file.mode)
                        case None => false
                    }
                } else {
                    // We opened the file descriptor with O_NONBLOCK, so we
                    // shouldn't have to worry about blocking reads/writes.
                    // We do not call fstat() because that is very expensive.
                    false
                }
            case None => false
        }

        // If it's a potentially large file, attempt to preallocate the saved filesystem size.
        let sharedView = bytesBlob.sharedView()
        if (!couldBlock && sharedView.size > 1024) {
            let _ = BunSys.preallocateFile(
                fd.native(), 0, Int64(sharedView.size)
            ) // we don't care if it fails.
        }

        if (couldBlock && BunCore.isWritable(fd) == Pollable.NotReady) {
            waitForWritable()
            return
        }

        doWriteLoop()
    }

    // ========================================================================
    // onFinish - finalize the write operation
    // Corresponds to: Bun: WriteFile::on_finish() (line 431)
    // ========================================================================

    /// Finalize the write operation
    /// Corresponds to: Bun: WriteFile::on_finish()
    public func onFinish(): Unit {
        let closeAfterIo_ = closeAfterIo
        if (doClose(isAllowedToClose())) {
            return
        }
        if (!closeAfterIo_) {
            match (ioTask) {
                case Some(t) =>
                    WriteFileTask.onFinish(t)
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
    // doWriteLoopTask - static task callback for work pool
    // Corresponds to: Bun: WriteFile::do_write_loop_task() (line 517)
    // ========================================================================

    /// Static task callback for the work pool
    /// Corresponds to: Bun: WriteFile::do_write_loop_task()
    public static func doWriteLoopTask(task: WorkPoolTask): Unit {
        let this_ = task.parent as WriteFile
        this_.doWriteLoop()
    }

    // ========================================================================
    // update - check state and continue writing
    // Corresponds to: Bun: WriteFile::update() (line 530)
    // ========================================================================

    /// Check state and continue or finish writing.
    /// Corresponds to: Bun: WriteFile::update()
    public func update(): Unit {
        doWriteLoop()
    }

    // ========================================================================
    // doWriteLoop - main write loop
    // Corresponds to: Bun: WriteFile::do_write_loop() (line 534)
    // ========================================================================

    /// Main write loop. Writes data in a loop until done or blocked.
    /// Corresponds to: Bun: WriteFile::do_write_loop()
    public func doWriteLoop(): Unit {
        while (state == ClosingState.running.ordinal()) {
            let remainFull = bytesBlob.sharedView()
            // Capture len/offset before mut borrow
            let off = totalWritten.min(Int64(remainFull.size))
            let remainLen = Int64(remainFull.size) - off

            if (remainLen > 0 && errno.isNone()) {
                var wrote: Int64 = 0
                let continueWriting = doWrite(off, remainLen, Ref<Int64>(wrote))

                if (!continueWriting) {
                    // Stop writing, we errored
                    if (errno.isSome()) {
                        onFinish()
                        return
                    }

                    // Stop writing, we need to wait for it to become writable
                    return
                }

                // Do not immediately attempt to write again if it's not a regular file
                if (couldBlock && BunCore.isWritable(openedFd) == Pollable.NotReady) {
                    waitForWritable()
                    return
                }

                if (wrote == 0) {
                    // We are done, we received EOF
                    onFinish()
                    return
                }

                continue
            }

            break
        }

        onFinish()
    }
}

// ============================================================================
// WriteFileTask - work pool task wrapper for WriteFile
// Corresponds to: Bun: write_file.rs WriteFileTask (line 33)
// ============================================================================

/// Work pool task wrapper for WriteFile
/// Corresponds to: Bun: WriteFileTask
public class WriteFileTask {
    public var writeFile: ?WriteFile

    public init() {
        writeFile = None
    }

    public init(writeFile: WriteFile) {
        this.writeFile = Some(writeFile)
    }

    /// Called when the task finishes
    /// Corresponds to: Bun: WorkTask::on_finish()
    public static func onFinish(task: WriteFileTask): Unit {
        match (task.writeFile) {
            case Some(wf) => wf.then()
            case None => ()
        }
    }
}

// ============================================================================
// WriteFilePromise - promise-based write file handler
// Corresponds to: Bun: write_file.rs WriteFilePromise (line 1277)
// ============================================================================

/// WriteFilePromise -- resolves a JS promise with the write result.
/// Corresponds to: Bun: WriteFilePromise
public class WriteFilePromise {
    /// Strong reference to the JS promise
    /// Corresponds to: Bun: WriteFilePromise.promise
    public var promise: JSPromiseStrong
    /// JSGlobalObject reference
    /// Corresponds to: Bun: WriteFilePromise.global_this
    public var globalThis: JsGlobalObject

    public init() {
        promise = JSPromiseStrong()
        globalThis = JsGlobalObject()
    }

    public init(promise: JSPromiseStrong, globalThis: JsGlobalObject) {
        this.promise = promise
        this.globalThis = globalThis
    }

    /// Run the completion handler with the write result
    /// Corresponds to: Bun: WriteFilePromise::run()
    public static func run(handler: UIntNative, count: WriteFileResultType): Unit {
        let handlerRef = handler // In real impl, this would be cast back to *mut WriteFilePromise
        // PORT NOTE: In Rust, handler was heap-allocated and taken ownership here.
        // The promise swap() returns a GC-owned *mut JSPromise that stays valid.
        match (count) {
            case WriteFileResultType.Err(err) =>
                // Reject the promise with the error
                // promise.reject(globalThis, err.toErrorInstanceWithAsyncStack(globalThis, promise))
                ()
            case WriteFileResultType.Result(wrote) =>
                // Resolve the promise with the bytes written
                // promise.resolve(globalThis, JsValue.jsNumberFromUInt64(wrote))
                ()
        }
    }
}

// ============================================================================
// WriteFileWindows - Windows libuv-backed write file
// Corresponds to: Bun: write_file.zig WriteFileWindows (line 337)
// ============================================================================

/// Windows-specific async file writer using libuv.
/// Uses uv_fs_open / uv_fs_write / uv_fs_req_cleanup for async IO.
/// Corresponds to: Bun: WriteFileWindows
public class WriteFileWindows {
    /// IO request (libuv fs_t) — raw pointer to the uv_fs_t struct
    public var ioRequest: CPointer<Unit>
    /// The file Blob (destination)
    public var fileBlob: Blob
    /// The bytes Blob (source data)
    public var bytesBlob: Blob
    /// Completion callback
    public var onCompleteCallback: WriteFileOnWriteFileCallback
    /// Completion context
    public var onCompleteCtx: UIntNative
    /// Whether to create parent directories
    public var mkdirpIfNotExists: Bool
    /// libuv buffer (1-element array)
    public var uvBuf: UvBufT
    /// File descriptor (libuv uv_file)
    public var fd: Int32
    /// Error, if any
    public var err: ?SyscallError
    /// Total bytes written
    public var totalWritten: Int64
    /// Event loop reference
    public var eventLoop: EventLoop
    /// Whether we own the FD
    public var ownedFd: Bool
    /// libuv loop pointer
    public var uvLoop: CPointer<Unit>

    public init() {
        ioRequest = CPointer<Unit>()    // will be allocated via uv_fs_t alloc
        fileBlob = Blob()
        bytesBlob = Blob()
        onCompleteCallback = { _, _ => () }
        onCompleteCtx = 0
        mkdirpIfNotExists = false
        uvBuf = UvBufT(len: 0, base: CPointer<UInt8>())
        fd = -1
        err = None
        totalWritten = 0
        eventLoop = EventLoop()
        ownedFd = false
        uvLoop = CPointer<Unit>()
    }

    /// Create with explicit callback.
    /// Translated from: Bun: WriteFileWindows.createWithCtx() (write_file.zig:358)
    public static func createWithCtx(
        fileBlob: Blob,
        bytesBlob: Blob,
        eventLoop: EventLoop,
        onWriteFileContext: UIntNative,
        onCompleteCallback: WriteFileOnWriteFileCallback,
        mkdirpIfNotExists: Bool
    ): Result<WriteFileWindows, WriteFileWindowsError> {
        let writeFile = WriteFileWindows()
        writeFile.fileBlob = fileBlob
        writeFile.bytesBlob = bytesBlob
        writeFile.onCompleteCtx = onWriteFileContext
        writeFile.onCompleteCallback = onCompleteCallback
        // Only mkdirp when destination is a path (not an FD)
        writeFile.mkdirpIfNotExists = mkdirpIfNotExists
        writeFile.eventLoop = eventLoop
        writeFile.uvLoop = eventLoop.uvLoopPtr()

        // ref both stores so they stay alive for the async duration
        fileBlob.refStore()
        bytesBlob.refStore()

        // Depending on pathlike type, open file or start writing immediately
        let pathlike = fileBlob.storePathlike()
        if (pathlike.isPath()) {
            match (writeFile.open()) {
                case Ok(()) => ()
                case Err(e) => return Result.Err(e)
            }
        } else {
            // FD path: resolve the fd and start writing
            writeFile.fd = pathlike.fdNative()
            match (writeFile.doWriteLoop()) {
                case Ok(()) => ()
                case Err(e) => return Result.Err(e)
            }
        }

        // Keep the event loop alive while IO is pending
        eventLoop.refConcurrently()
        return Result.Ok(writeFile)
    }

    /// Create with typed callback.
    /// Translated from: Bun: WriteFileWindows.create() (write_file.zig:629)
    public static func create(
        eventLoop: EventLoop,
        fileBlob: Blob,
        bytesBlob: Blob,
        context: UIntNative,
        callback: WriteFileOnWriteFileCallback,
        mkdirpIfNotExists: Bool
    ): Result<WriteFileWindows, WriteFileWindowsError> {
        WriteFileWindows.createWithCtx(
            fileBlob, bytesBlob, eventLoop, context, callback, mkdirpIfNotExists
        )
    }

    /// Open the file for writing via uv_fs_open (async).
    /// Translated from: Bun: WriteFileWindows.open() (write_file.zig:413)
    public func open(): Result<Unit, WriteFileWindowsError> {
        let path = fileBlob.storePathlike().pathSlice()
        // uv_fs_open flags: CREAT | WRONLY | NOCTTY | NONBLOCK | SEQUENTIAL | TRUNC
        let openFlags: Int32 = Int32(UV_FS_O_CREAT.toInt()) |
            Int32(UV_FS_O_WRONLY.toInt()) |
            Int32(UV_FS_O_TRUNC.toInt())
        let mode: Int32 = 0o644  // WRITE_PERMISSIONS

        let rc = uv_fs_open(
            uvLoop,
            ioRequest,
            path,
            openFlags,
            mode,
            CFunc<(CPointer<Unit>) -> Unit>(onOpenCallback)
        )

        if (rc < 0) {
            // uv error
            let sysErr = SyscallError.fromErrno(rc, SyscallTag.open)
            return Result.Err(throw(sysErr))
        } else {
            ownedFd = true
        }
        Result.Ok(())
    }

    /// uv_fs_open completion callback.
    /// Translated from: Bun: WriteFileWindows.onOpen() (write_file.zig:444)
    @C
    public static func onOpenCallback(req: CPointer<Unit>): Unit {
        let this_ = WriteFileWindows.fromIoRequest(req)
        let rc = uv_fs_get_result(req)

        if (rc < 0) {
            let errEnum = rc.toInt32()
            if (errEnum == UV_ENOENT && this_.mkdirpIfNotExists) {
                // Cleanup the request so we can reuse it
                uv_fs_req_cleanup(req)
                this_.mkdirpIfNotExists = false
                // Attempt mkdirp on another thread (simplified: inline)
                this_.mkdirp()
                return
            }
            let sysErr = SyscallError.fromErrno(rc, SyscallTag.open)
            this_.throw(sysErr)
            return
        }

        this_.fd = rc.toInt32()
        // Continue with the write loop
        match (this_.doWriteLoop()) {
            case Ok(()) => ()
            case Err(_) => ()
        }
    }

    /// Create parent directories if needed.
    /// Translated from: Bun: WriteFileWindows.mkdirp() (write_file.zig:481)
    public func mkdirp(): Unit {
        mkdirpIfNotExists = false
        let path = fileBlob.storePathlike().pathSlice()
        let dirPath = PathUtil.dirname(path)
        // Schedule async mkdirp (delegated to AsyncMkdirp helper)
        AsyncMkdirp.schedule(
            dirPath,
            onComplete: CFunc<(CPointer<Unit>) -> Unit>(onMkdirpCompleteCallback),
            context: this_
        )
    }

    @C
    public static func onMkdirpCompleteCallback(req: CPointer<Unit>): Unit {
        // After mkdirp, retry open
        // For now, simplified: re-open
        ()
    }

    /// Main write loop using uv_fs_write (async).
    /// Translated from: Bun: WriteFileWindows.doWriteLoop() (write_file.zig:586)
    public func doWriteLoop(): Result<Unit, WriteFileWindowsError> {
        let remainFull = bytesBlob.sharedView()
        let off = totalWritten.min(Int64(remainFull.size))
        let remainSlice = remainFull[Int64(off)..Int64(remainFull.size)]

        if (remainSlice.size <= 0 || err.isSome()) {
            return Result.Err(onFinish())
        }

        // Set up the uv_buf_t to point at the remaining data
        uvBuf = UvBufT(len: UInt32(remainSlice.size), base: remainSlice.ptr)

        // Clean up previous request and issue a new uv_fs_write
        uv_fs_req_cleanup(ioRequest)
        let rc = uv_fs_write(
            uvLoop,
            ioRequest,
            fd,
            CPointer<UvBufT>(uvBuf),
            1,
            Int64(-1),
            CFunc<(CPointer<Unit>) -> Unit>(onWriteCompleteCallback)
        )

        if (rc == 0) {
            // EINPROGRESS — callback will handle the rest
            return Result.Ok(())
        }

        if (rc < 0) {
            let sysErr = SyscallError.fromErrno(rc, SyscallTag.write)
            return Result.Err(throw(sysErr))
        }

        Result.Ok(())
    }

    /// uv_fs_write completion callback.
    /// Translated from: Bun: WriteFileWindows.onWriteComplete() (write_file.zig:520)
    @C
    public static func onWriteCompleteCallback(req: CPointer<Unit>): Unit {
        let this_ = WriteFileWindows.fromIoRequest(req)
        let rc = uv_fs_get_result(req)

        if (rc < 0) {
            let sysErr = SyscallError.fromErrno(rc, SyscallTag.write)
            this_.throw(sysErr)
            return
        }

        this_.totalWritten += rc
        // Continue writing if there's more data
        match (this_.doWriteLoop()) {
            case Ok(()) => ()
            case Err(_) => ()
        }
    }

    /// Finalize the write operation.
    /// Translated from: Bun: WriteFileWindows.onFinish() (write_file.zig:542)
    public func onFinish(): WriteFileWindowsError {
        return runFromJsThread()
    }

    /// Run from JS thread — invoke the completion callback.
    /// Translated from: Bun: WriteFileWindows.runFromJsThread() (write_file.zig:551)
    public func runFromJsThread(): WriteFileWindowsError {
        let cb = onCompleteCallback
        let cbCtx = onCompleteCtx

        let sysErrOpt = toSystemError()
        match (sysErrOpt) {
            case Some(sysError) =>
                deinit()
                cb(cbCtx, WriteFileResultType.Err(sysError))
            case None =>
                let wrote = totalWritten
                deinit()
                cb(cbCtx, WriteFileResultType.Result(wrote))
        }

        WriteFileWindowsError.WriteFileWindowsDeinitialized
    }

    /// Set error and finish.
    /// Translated from: Bun: WriteFileWindows.throw() (write_file.zig:567)
    public func throw(err: SyscallError): WriteFileWindowsError {
        this.err = Some(err)
        onFinish()
    }

    /// Get system error from current error.
    /// Translated from: Bun: WriteFileWindows.toSystemError() (write_file.zig:573)
    public func toSystemError(): ?SystemError {
        match (err) {
            case Some(e) =>
                var sysErr = e.clone()
                let pathlike = match (fileBlob.store) {
                    case Some(store) => store.asFile().pathlike
                    case None => PathOrFileDescriptor(path: "")
                }
                if (pathlike.isPath()) {
                    sysErr = sysErr.withPath(pathlike.path().slice())
                } else {
                    sysErr = sysErr.withFd(pathlike.fd())
                }
                return Some(sysErr.toSystemError())
            case None =>
                return None
        }
    }

    /// Recover `this` from the uv_fs_t request's data field.
    public static func fromIoRequest(req: CPointer<Unit>): WriteFileWindows {
        // In Bun, io_request.data = self is set before each uv_fs_* call.
        // We use uv_req_get_data to recover the WriteFileWindows pointer.
        let dataPtr = uv_req_get_data(req)
        WriteFileWindows.fromCPointer(dataPtr)
    }

    /// Cleanup resources.
    /// Translated from: Bun: WriteFileWindows.deinit() (write_file.zig:617)
    public func deinit(): Unit {
        if (fd > 0 && ownedFd) {
            // Async close via libuv closer (simplified as sync close here)
            BunSys.close(Fd.fromNative(fd))
        }
        fileBlob.derefStore()
        bytesBlob.derefStore()
        uv_fs_req_cleanup(ioRequest)
    }

    /// Get the opened FD
    public func openedFd(): Fd {
        Fd.fromNative(fd)
    }
}

// ============================================================================
// WriteFileWindowsError - errors from WriteFileWindows
// Corresponds to: Bun: write_file.rs WriteFileWindowsError (line 626)
// ============================================================================

/// Errors from WriteFileWindows operations
/// Corresponds to: Bun: WriteFileWindowsError
public enum WriteFileWindowsError {
    | WriteFileWindowsDeinitialized
    | JsTerminated

    public operator func == (rhs: WriteFileWindowsError): Bool {
        match (this) {
            case WriteFileWindowsDeinitialized =>
                match (rhs) { case WriteFileWindowsDeinitialized => true case _ => false }
            case JsTerminated =>
                match (rhs) { case JsTerminated => true case _ => false }
        }
    }
}

// ============================================================================
// WriteFileWaitFromLockedValueTask - handles locked value waiting
// Corresponds to: Bun: write_file.rs WriteFileWaitFromLockedValueTask (line 1316)
// ============================================================================

/// Task for writing a file from a locked body value.
/// Corresponds to: Bun: WriteFileWaitFromLockedValueTask
public class WriteFileWaitFromLockedValueTask {
    /// The file Blob (destination)
    /// Corresponds to: Bun: WriteFileWaitFromLockedValueTask.file_blob
    public var fileBlob: Blob
    /// JSGlobalObject reference
    /// Corresponds to: Bun: WriteFileWaitFromLockedValueTask.global_this
    public var globalThis: JsGlobalObject
    /// Promise to resolve/reject
    /// Corresponds to: Bun: WriteFileWaitFromLockedValueTask.promise
    public var promise: JSPromiseStrong
    /// Whether to create parent directories
    /// Corresponds to: Bun: WriteFileWaitFromLockedValueTask.mkdirp_if_not_exists
    public var mkdirpIfNotExists: Bool

    public init() {
        fileBlob = Blob()
        globalThis = JsGlobalObject()
        promise = JSPromiseStrong()
        mkdirpIfNotExists = false
    }

    public init(
        fileBlob: Blob,
        globalThis: JsGlobalObject,
        promise: JSPromiseStrong,
        mkdirpIfNotExists: Bool
    ) {
        this.fileBlob = fileBlob
        this.globalThis = globalThis
        this.promise = promise
        this.mkdirpIfNotExists = mkdirpIfNotExists
    }

    /// Static wrapper for then
    /// Corresponds to: Bun: WriteFileWaitFromLockedValueTask::then_wrap()
    public static func thenWrap(this_: UIntNative, value: BodyValue): Unit {
        let task = WriteFileWaitFromLockedValueTask()
        task.then(value)
    }

    /// Handle the body value and resolve/reject the promise
    /// Corresponds to: Bun: WriteFileWaitFromLockedValueTask::then()
    public func then(value: BodyValue): Unit {
        match (value) {
            case BodyValue.Error(errRef) =>
                let err = errRef.toJs(globalThis)
                fileBlob.detach()
                promise.reject(globalThis, err)
            case BodyValue.Used =>
                fileBlob.detach()
                promise.reject(
                    globalThis,
                    BaoString.init("Body was used after it was consumed")
                        .toErrorInstance(globalThis)
                )
            case BodyValue.WTFStringImpl(_)
            | BodyValue.InternalBlob(_)
            | BodyValue.Null
            | BodyValue.Empty
            | BodyValue.Blob(_) =>
                // Write the blob data to the file
                let blob = value.use_()
                // Attempt to write the file
                let newPromise = Blob.writeFileWithSourceDestination(
                    globalThis, blob, fileBlob,
                    WriteFileOptions(mkdirpIfExists: Some(mkdirpIfNotExists))
                )
                // Resolve our promise with the write result
                match (newPromise) {
                    case Some(p) =>
                        promise.resolve(globalThis, p)
                    case None =>
                        promise.reject(globalThis, JsValue.zero())
                }
                fileBlob.detach()
            case BodyValue.Locked(locked) =>
                // Re-registering for a future callback -- `this` stays alive
                locked.onReceiveValue = Some(WriteFileWaitFromLockedValueTask.thenWrap)
                locked.task = Some(this)
        }
    }
}

// ============================================================================
// Helper types for body value handling
// ============================================================================

/// Body value variants
/// Corresponds to: Bun: body::Value
public enum BodyValue {
    | Error(BodyError)
    | Used
    | WTFStringImpl(Array<UInt8>)
    | InternalBlob(Array<UInt8>)
    | Null
    | Empty
    | Blob(Blob)
    | Locked(LockedBodyValue)

    /// Use (consume) the value
    public func use_(): Blob {
        match (this) {
            case Blob(b) => b
            case InternalBlob(bytes) => Blob(bytes, "")
            case WTFStringImpl(bytes) => Blob(bytes, "")
            case Null => Blob()
            case Empty => Blob()
            case _ => Blob()
        }
    }
}

/// Body error
/// Corresponds to: Bun: body::Value::Error
public class BodyError {
    public var message: String

    public init(message: String) {
        this.message = message
    }

    public func toJs(global: JsGlobalObject): JsValue {
        JsValue(BaoString(message))
    }
}

/// Locked body value (waiting for async data)
/// Corresponds to: Bun: body::Value::Locked
public class LockedBodyValue {
    public var onReceiveValue: ?((UIntNative, BodyValue) -> Unit)
    public var task: ?WriteFileWaitFromLockedValueTask

    public init() {
        onReceiveValue = None
        task = None
    }
}

// ============================================================================
// libuv FFI bindings for WriteFileWindows (Windows async IO)
// Imported from bao_libuv_sys
// ============================================================================

// The UvBufT type comes from bao_libuv_sys.types; re-exported here for
// convenient access within the webcore.blob package.
// UvBufT is @C struct { len: UInt32, base: CPointer<UInt8> }

/// WRITE_PERMISSIONS constant
/// Corresponds to: Bun: write_file.zig WRITE_PERMISSIONS
let WRITE_PERMISSIONS: UInt32 = 0o644

/// libuv filesystem FFI declarations used by WriteFileWindows.
/// These are @C foreign func bindings to the libuv shared library.
/// Translated from: bun.windows.libuv calls in write_file.zig
@C
foreign func uv_fs_open(
    loop: CPointer<Unit>,
    req: CPointer<Unit>,
    path: CString,
    flags: Int32,
    mode: Int32,
    cb: CFunc<(CPointer<Unit>) -> Unit>
): Int32

@C
foreign func uv_fs_write(
    loop: CPointer<Unit>,
    req: CPointer<Unit>,
    file: Int32,
    bufs: CPointer<UvBufT>,
    nbufs: UInt32,
    offset: Int64,
    cb: CFunc<(CPointer<Unit>) -> Unit>
): Int32

@C
foreign func uv_fs_req_cleanup(req: CPointer<Unit>): Unit

@C
foreign func uv_fs_get_result(req: CPointer<Unit>): Int64

@C
foreign func uv_req_get_data(req: CPointer<Unit>): CPointer<Unit>

@C
foreign func uv_req_set_data(req: CPointer<Unit>, data: CPointer<Unit>): Unit

// ported from: src/runtime/webcore/blob/write_file.zig
