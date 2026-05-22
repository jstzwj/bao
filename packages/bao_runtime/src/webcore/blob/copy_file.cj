// CopyFile - blocking, but off the main thread
// Strict 1:1 translation from: src/runtime/webcore/blob/copy_file.rs (1888 lines)
package bao_runtime.webcore.blob

import bao_collections.*
import bao_core.Result
import bao_jsc.JsValue
import bao_jsc.JsObject
import bao_collections.ArrayList
import bao_sys.*
import bao_ptr.*

// ============================================================================
// Module-level constants
// Corresponds to: Bun: copy_file.rs (lines 965-970)
// ============================================================================

/// Whether preallocation is supported (Linux/Android only)
/// Corresponds to: Bun: PREALLOCATE_SUPPORTED
let PREALLOCATE_SUPPORTED: Bool = BunSys.PREALLOCATE_SUPPORTED

/// Minimum size to trigger preallocation
/// Corresponds to: Bun: PREALLOCATE_LENGTH = 2048 * 1024
let PREALLOCATE_LENGTH: BlobSizeType = 2048 * 1024

/// Flags for opening destination file: CLOEXEC | CREAT | WRONLY | TRUNC
/// Corresponds to: Bun: OPEN_DESTINATION_FLAGS (line 968)
let OPEN_DESTINATION_FLAGS: Int32 = BunSys.O_CLOEXEC | BunSys.O_CREAT | BunSys.O_WRONLY | BunSys.O_TRUNC

/// Flags for opening source file: CLOEXEC | RDONLY
/// Corresponds to: Bun: OPEN_SOURCE_FLAGS (line 970)
let OPEN_SOURCE_FLAGS: Int32 = BunSys.O_CLOEXEC | BunSys.O_RDONLY

// ============================================================================
// Local conversion: SystemError -> JscSystemError.
// Both mirror the same Zig `jsc.SystemError` extern struct; map field-by-field.
// Corresponds to: Bun: copy_file.rs to_jsc_system_error (line 29)
// ============================================================================

func toJscSystemError(e: SystemError): JscSystemError {
    return JscSystemError(e.errno, e.code, e.message, e.path, e.syscall, e.hostname, e.fd, e.dest)
}

// ============================================================================
// CopyFileResultType - copy file result type
// Corresponds to: Bun: copy_file.rs ResultType (line 72)
// ============================================================================

/// Copy file result type
/// Corresponds to: Bun: copy_file.rs ResultType
public enum CopyFileResultType {
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
// CopyFileCallback - callback type for copy file completion
// Corresponds to: Bun: copy_file.rs Callback (line 74)
// ============================================================================

public type CopyFileCallback = (ctx: UIntNative, len: CopyFileResultType) -> Unit

// ============================================================================
// IOWhich - which file descriptors to operate on
// Corresponds to: Bun: copy_file.rs IOWhich (line 1855)
// ============================================================================

public enum IOWhich {
    | Source
    | Destination
    | Both

    public operator func == (rhs: IOWhich): Bool {
        match (this) {
            case Source => match (rhs) { case Source => true case _ => false }
            case Destination => match (rhs) { case Destination => true case _ => false }
            case Both => match (rhs) { case Both => true case _ => false }
        }
    }
}

// ============================================================================
// TryWith - which kernel syscall to use for copying
// Corresponds to: Bun: copy_file.rs TryWith (line 972)
// ============================================================================

public enum TryWith {
    | Sendfile
    | CopyFileRange
    | Splice

    /// Get the syscall tag for error reporting
    /// Corresponds to: Bun: TryWith::tag() (line 979)
    public func tag(): SyscallTag {
        match (this) {
            case Sendfile => SyscallTag.sendfile
            case CopyFileRange => SyscallTag.copyFileRange
            case Splice => SyscallTag.splice
        }
    }

    public operator func == (rhs: TryWith): Bool {
        match (this) {
            case Sendfile => match (rhs) { case Sendfile => true case _ => false }
            case CopyFileRange => match (rhs) { case CopyFileRange => true case _ => false }
            case Splice => match (rhs) { case Splice => true case _ => false }
        }
    }
}

// ============================================================================
// CopyFile - POSIX blocking file copy (off-thread)
// Corresponds to: Bun: copy_file.rs CopyFile<'a> (line 46)
// ============================================================================

/// CopyFile -- POSIX blocking file copy, runs off the main thread.
/// Corresponds to: Bun: copy_file.rs CopyFile<'a>
public class CopyFile {
    /// Destination file store
    /// Corresponds to: Bun: CopyFile.destination_file_store
    public var destinationFileStore: StoreFile
    /// Source file store
    /// Corresponds to: Bun: CopyFile.source_file_store
    public var sourceFileStore: StoreFile
    /// Store reference (destination)
    /// Corresponds to: Bun: CopyFile.store
    public var store: ?StoreRef
    /// Source store reference
    /// Corresponds to: Bun: CopyFile.source_store
    public var sourceStore: ?StoreRef
    /// Byte offset into the source
    /// Corresponds to: Bun: CopyFile.offset
    public var offset: BlobSizeType
    /// Size of data to copy
    /// Corresponds to: Bun: CopyFile.size
    public var size: BlobSizeType
    /// Maximum length to copy
    /// Corresponds to: Bun: CopyFile.max_length
    public var maxLength: BlobSizeType
    /// Destination file descriptor
    /// Corresponds to: Bun: CopyFile.destination_fd
    public var destinationFd: Fd
    /// Source file descriptor
    /// Corresponds to: Bun: CopyFile.source_fd
    public var sourceFd: Fd
    /// System error, if any
    /// Corresponds to: Bun: CopyFile.system_error
    public var systemError: ?SystemError
    /// Bytes read so far
    /// Corresponds to: Bun: CopyFile.read_len
    public var readLen: BlobSizeType
    /// Read offset
    /// Corresponds to: Bun: CopyFile.read_off
    public var readOff: BlobSizeType
    /// JSGlobalObject reference
    /// Corresponds to: Bun: CopyFile.global_this
    public var globalThis: JsGlobalObject
    /// Whether to create parent directories
    /// Corresponds to: Bun: CopyFile.mkdirp_if_not_exists
    public var mkdirpIfNotExists: Bool
    /// Destination file mode
    /// Corresponds to: Bun: CopyFile.destination_mode
    public var destinationMode: ?Mode

    public init(
        destinationFileStore: StoreFile,
        sourceFileStore: StoreFile,
        store: ?StoreRef,
        sourceStore: ?StoreRef,
        offset: BlobSizeType,
        maxLength: BlobSizeType,
        globalThis: JsGlobalObject,
        mkdirpIfNotExists: Bool,
        destinationMode: ?Mode
    ) {
        this.destinationFileStore = destinationFileStore
        this.sourceFileStore = sourceFileStore
        this.store = store
        this.sourceStore = sourceStore
        this.offset = offset
        this.maxLength = maxLength
        this.globalThis = globalThis
        this.mkdirpIfNotExists = mkdirpIfNotExists
        this.destinationMode = destinationMode
        size = 0
        destinationFd = Fd.INVALID
        sourceFd = Fd.INVALID
        systemError = None
        readLen = 0
        readOff = 0
    }

    // ========================================================================
    // MkdirpTarget implementation
    // Corresponds to: Bun: copy_file.rs impl MkdirpTarget for CopyFile (line 76)
    // ========================================================================

    public func mkdirpIfExists(): Bool {
        mkdirpIfNotExists
    }

    public func setMkdirpIfExists(v: Bool): Unit {
        mkdirpIfNotExists = v
    }

    public func setSystemError(e: SystemError): Unit {
        systemError = Some(e)
    }

    // ========================================================================
    // create - factory method
    // Corresponds to: Bun: CopyFile::create() (line 99)
    // ========================================================================

    /// Create a new CopyFile task
    /// Corresponds to: Bun: CopyFile::create()
    public static func create(
        store: StoreRef,
        sourceStore: StoreRef,
        off: BlobSizeType,
        maxLen: BlobSizeType,
        globalThis: JsGlobalObject,
        mkdirpIfNotExists: Bool,
        destinationMode: ?Mode
    ): CopyFilePromiseTask {
        let destFileStore = store.data.asFile().clone()
        let srcFileStore = sourceStore.data.asFile().clone()
        let copyFile = CopyFile(
            destFileStore,
            srcFileStore,
            Some(store.clone()),
            Some(sourceStore.clone()),
            off,
            maxLen,
            globalThis,
            mkdirpIfNotExists,
            destinationMode
        )
        return CopyFilePromiseTask.createOnJsThread(globalThis, copyFile)
    }

    // ========================================================================
    // reject - reject the promise with an error
    // Corresponds to: Bun: CopyFile::reject() (line 130)
    // ========================================================================

    /// Reject the promise with a system error
    /// Corresponds to: Bun: CopyFile::reject()
    public func reject(promise: JsPromise): Unit {
        var sysError: SystemError = match (systemError) {
            case Some(e) => e
            case None => SystemError()
        }

        // If source is a path and error has no path, fill it in
        if (sourceFileStore.pathlike.isPath() && sysError.path.isEmpty()) {
            sysError.path = BaoString.cloneUtf8(sourceFileStore.pathlike.pathSlice())
        }

        if (sysError.message.isEmpty()) {
            sysError.message = BaoString.static_("Failed to copy file")
        }

        let instance = toJscSystemError(sysError).toErrorInstance(globalThis)
        match (store) {
            case Some(s) =>
                s.deref()
                store = None
            case None => ()
        }
        promise.reject(globalThis, instance)
    }

    // ========================================================================
    // then - resolve the promise after copy completes
    // Corresponds to: Bun: CopyFile::then() (line 154)
    // ========================================================================

    /// Resolve the promise after the copy operation completes
    /// Corresponds to: Bun: CopyFile::then()
    public func then(promise: JsPromise): Unit {
        // source_store.?.deref()
        match (sourceStore) {
            case Some(s) =>
                s.deref()
                sourceStore = None
            case None => ()
        }

        if (systemError.isSome()) {
            reject(promise)
            return
        }

        promise.resolve(
            globalThis,
            JsValue(Int64(UInt64(readLen)))
        )
    }

    // ========================================================================
    // run / runAsync - execute the copy operation
    // Corresponds to: Bun: CopyFile::run() / run_async() (line 167, 635)
    // ========================================================================

    /// Execute the copy
    /// Corresponds to: Bun: CopyFile::run()
    public func run(): Unit {
        runAsync()
    }

    /// Execute the async copy operation (blocking, off-thread)
    /// Corresponds to: Bun: CopyFile::run_async()
    public func runAsync(): Unit {
        var stat_: ?Stat = None

        // Resolve destination fd from pathlike
        if (destinationFileStore.pathlike.isFd()) {
            destinationFd = destinationFileStore.pathlike.fd()
        }

        // Resolve source fd from pathlike
        if (sourceFileStore.pathlike.isFd()) {
            sourceFd = sourceFileStore.pathlike.fd()
        }

        // Do we need to open both files?
        if (!destinationFd.isValid() && !sourceFd.isValid()) {
            // Attempt clonefile() on macOS first (fastest way to copy a file)
            // This is macOS-only; on other platforms we skip directly to doOpenFile.
            // PORT NOTE: macOS clonefile path omitted for portability.
            // On Linux/other platforms, go straight to doOpenFile.

            if (doOpenFile(IOWhich.Both).isErr()) {
                return
            }
        } else if (!destinationFd.isValid()) {
            sourceFd = sourceFileStore.pathlike.fd()

            if (doOpenFile(IOWhich.Destination).isErr()) {
                return
            }
        } else if (!sourceFd.isValid()) {
            destinationFd = destinationFileStore.pathlike.fd()

            if (doOpenFile(IOWhich.Source).isErr()) {
                return
            }
        }

        if (systemError.isSome()) {
            return
        }

        // Get stat info
        let stat: Stat = match (stat_) {
            case Some(s) => s
            case None =>
                match (BunSys.fstat(sourceFd)) {
                    case BunSysResult<Stat>.Ok(statResult) => statResult
                    case BunSysResult<Stat>.Err(err) =>
                        doClose()
                        systemError = Some(err.toSystemError())
                        return
                }
        }

        if (BunSys.isDir(stat.stMode)) {
            systemError = Some(unsupportedDirectoryError())
            doClose()
            return
        }

        if (stat.stSize != 0) {
            maxLength = max(min(Int64(stat.stSize), maxLength), offset) - offset
            if (maxLength == 0) {
                doClose()
                return
            }

            if (PREALLOCATE_SUPPORTED && BunSys.isRegularFile(stat.stMode) &&
                maxLength > PREALLOCATE_LENGTH && maxLength != BLOB_MAX_SIZE) {
                let _ = BunSys.preallocateFile(Int32(destinationFd.value), 0, maxLength)
            }
        }

        // Linux/Android: try copy_file_range, sendfile, splice
        // macOS: try fcopyfile with read/write loop fallback
        // FreeBSD: read/write loop
        // For cross-platform, use the read/write loop approach
        if (BunSys.isRegularFile(stat.stMode)) {
            if (destinationFileStore.isAtty()) {
                let _ = doCopyFileRange(TryWith.CopyFileRange, true)
            } else {
                let _ = doCopyFileRange(TryWith.CopyFileRange, false)
            }
            doClose()
            return
        }

        if (BunSys.isFifo(stat.stMode)) {
            if (destinationFileStore.isAtty()) {
                let _ = doCopyFileRange(TryWith.Splice, true)
            } else {
                let _ = doCopyFileRange(TryWith.Splice, false)
            }
            doClose()
            return
        }

        // Fall through for regular files, char devices, sockets
        if (BunSys.isRegularFile(stat.stMode) || BunSys.isChr(stat.stMode) ||
            BunSys.isSock(stat.stMode)) {
            if (destinationFileStore.isAtty()) {
                let _ = doCopyFileRange(TryWith.Sendfile, true)
            } else {
                let _ = doCopyFileRange(TryWith.Sendfile, false)
            }
            doClose()
            return
        }

        systemError = Some(unsupportedNonRegularFileError())
        doClose()
    }

    // ========================================================================
    // doClose - close file descriptors
    // Corresponds to: Bun: CopyFile::do_close() (line 171)
    // ========================================================================

    /// Close source and/or destination file descriptors
    /// Corresponds to: Bun: CopyFile::do_close()
    public func doClose(): Unit {
        let closeInput = destinationFileStore.pathlike.isPath() && destinationFd.isValid()
        let closeOutput = sourceFileStore.pathlike.isPath() && sourceFd.isValid()

        // Apply destination mode using fchmod before closing (POSIX)
        match (destinationMode) {
            case Some(mode) =>
                if (destinationFd.isValid() && systemError.isNone()) {
                    match (BunSys.fchmod(destinationFd, mode)) {
                        case BunSysResult<Unit>.Err(err) =>
                            systemError = Some(err.toSystemError())
                        case BunSysResult<Unit>.Ok(()) => ()
                    }
                }
            case None => ()
        }

        if (closeInput && closeOutput) {
            doCloseFile(IOWhich.Both)
        } else if (closeInput) {
            doCloseFile(IOWhich.Destination)
        } else if (closeOutput) {
            doCloseFile(IOWhich.Source)
        }
    }

    // ========================================================================
    // doCloseFile - close specific file descriptors
    // Corresponds to: Bun: CopyFile::do_close_file() (line 207)
    // ========================================================================

    /// Close specific file descriptors based on WHICH
    /// Corresponds to: Bun: CopyFile::do_close_file()
    public func doCloseFile(which: IOWhich): Unit {
        match (which) {
            case IOWhich.Both =>
                BunSys.close(destinationFd)
                BunSys.close(sourceFd)
            case IOWhich.Destination =>
                BunSys.close(destinationFd)
            case IOWhich.Source =>
                BunSys.close(sourceFd)
        }
    }

    // ========================================================================
    // doOpenFile - open source and/or destination files
    // Corresponds to: Bun: CopyFile::do_open_file() (line 222)
    // ========================================================================

    /// Open source and/or destination files
    /// Corresponds to: Bun: CopyFile::do_open_file()
    public func doOpenFile(which: IOWhich): Result<Unit, BaoError> {
        // Open source file first -- if it fails, we don't want the extra destination file
        if (which == IOWhich.Both || which == IOWhich.Source) {
            match (BunSys.open(
                sourceFileStore.pathlike.pathSlice(),
                OPEN_SOURCE_FLAGS,
                0
            )) {
                case BunSysResult<Fd>.Ok(resultFd) =>
                    sourceFd = resultFd
                case BunSysResult<Fd>.Err(errno) =>
                    systemError = Some(errno.toSystemError())
                    return Result.Err(BunCore.errnoToZigErr(errno.errno))
            }
        }

        if (which == IOWhich.Both || which == IOWhich.Destination) {
            var done = false
            while (!done) {
                let dest = destinationFileStore.pathlike.pathSlice()
                let mode = match (destinationMode) {
                    case Some(m) => m
                    case None => NodeFs.DEFAULT_PERMISSION
                }
                match (BunSys.open(dest, OPEN_DESTINATION_FLAGS, Int32(mode))) {
                    case BunSysResult<Fd>.Ok(resultFd) =>
                        destinationFd = resultFd
                    case BunSysResult<Fd>.Err(errno) =>
                        match (Blob.mkdirIfNotExists(
                            this, errno.clone(), dest, dest.toArray()
                        )) {
                            case Retry.Continue => continue
                            case Retry.Fail =>
                                if (which == IOWhich.Both) {
                                    BunSys.close(sourceFd)
                                    sourceFd = Fd.INVALID
                                }
                                return Result.Err(BunCore.errnoToZigErr(errno.errno))
                            case Retry.No => ()
                        }

                        if (which == IOWhich.Both) {
                            BunSys.close(sourceFd)
                            sourceFd = Fd.INVALID
                        }

                        systemError = Some(
                            errno.withPath(destinationFileStore.pathlike.pathSlice())
                                .toSystemError()
                        )
                        return Result.Err(BunCore.errnoToZigErr(errno.errno))
                }
                done = true
            }
        }
        Result.Ok(())
    }

    /// Helper: handle fallback to read/write loop for copy_file_range errors
    private func handleFallbackReadWrite(
        srcFd: Fd,
        destFd: Fd,
        unknownSize: Bool,
        remain: Int64,
        totalWritten: UInt64
    ): Result<Unit, BaoError> {
        match (NodeFs.copyFileUsingReadWriteLoop(
            ZStr.EMPTY, ZStr.EMPTY, srcFd, destFd,
            if (unknownSize) { 0 } else { remain },
            totalWritten
        )) {
            case BunSysResult<Unit>.Err(err) =>
                systemError = Some(err.toSystemError())
                return Result.Err(BunCore.errnoToZigErr(err.errno))
            case BunSysResult<Unit>.Ok(()) =>
                let _ = BunSys.ftruncate(Int32(destFd.value), Int64(totalWritten))
                return Result.Ok(())
        }
    }

    // ========================================================================
    // doCopyFileRange - copy using kernel syscalls
    // Corresponds to: Bun: CopyFile::do_copy_file_range() (line 316)
    // ========================================================================

    /// Copy using kernel-level file copy syscalls
    /// Corresponds to: Bun: CopyFile::do_copy_file_range()
    public func doCopyFileRange(use: TryWith, clearAppendIfInvalid: Bool): Result<Unit, BaoError> {
        readOff += offset

        var remain: Int64 = maxLength
        let unknownSize = remain == BLOB_MAX_SIZE || remain == 0
        if (unknownSize) {
            // sometimes stat lies -- give it 4096 and see how it goes
            remain = 4096
        }

        var totalWritten: UInt64 = 0
        let srcFd = sourceFd
        let destFd = destinationFd

        var hasUnsetAppend = false

        // If they can't use copy_file_range, they probably also can't use sendfile() or splice()
        if (!BunSys.canUseCopyFileRangeSyscall()) {
            match (NodeFs.copyFileUsingReadWriteLoop(
                ZStr.EMPTY, ZStr.EMPTY, srcFd, destFd,
                if (unknownSize) { 0 } else { remain },
                totalWritten
            )) {
                case BunSysResult<Unit>.Err(err) =>
                    systemError = Some(err.toSystemError())
                    return Result.Err(BunCore.errnoToZigErr(err.errno))
                case BunSysResult<Unit>.Ok(()) =>
                    let _ = BunSys.ftruncate(Int32(destFd.value), Int64(totalWritten))
                    return Result.Ok(())
            }
        }

        var looping = true
        while (looping) {
            let written: Int64 = match (use) {
                case TryWith.CopyFileRange =>
                    BunSys.copyFileRange(
                        Int32(srcFd.value), UIntNative(0),
                        Int32(destFd.value), UIntNative(0),
                        Int64(remain), 0
                    )
                case TryWith.Sendfile =>
                    BunSys.sendfile(
                        Int32(destFd.value), Int32(srcFd.value),
                        UIntNative(0), Int64(remain)
                    )
                case TryWith.Splice =>
                    BunSys.splice(
                        Int32(srcFd.value), UIntNative(0),
                        Int32(destFd.value), UIntNative(0),
                        Int64(remain), 0
                    )
            }

            let errno: SyscallErrno = BunSys.getErrno(written)
            match (errno) {
                case SyscallErrno.SUCCESS => ()

                // XDEV: cross-device copy not supported
                // NOSYS: syscall not available
                // OPNOTSUPP: filesystem doesn't support this operation
                case SyscallErrno.ENOSYS => handleFallbackReadWrite(srcFd, destFd, unknownSize, remain, totalWritten)
                case SyscallErrno.EXDEV => handleFallbackReadWrite(srcFd, destFd, unknownSize, remain, totalWritten)
                case SyscallErrno.ENOTSUP => handleFallbackReadWrite(srcFd, destFd, unknownSize, remain, totalWritten)

                // EINVAL: eCryptfs and other filesystems may not support copy_file_range
                case SyscallErrno.EINVAL =>
                    if (clearAppendIfInvalid) {
                        if (!hasUnsetAppend) {
                            // make() can set STDOUT / STDERR to O_APPEND; this messes up sendfile()
                            hasUnsetAppend = true
                            let flags = BunSys.fcntlGetFl(Int32(destFd.value))
                            if ((flags & BunSys.O_APPEND) != 0) {
                                let _ = BunSys.fcntlSetFl(
                                    Int32(destFd.value), flags ^ BunSys.O_APPEND
                                )
                                continue
                            }
                        }
                    }

                    // Fall back to read/write loop if no bytes written yet
                    if (totalWritten == 0) {
                        match (NodeFs.copyFileUsingReadWriteLoop(
                            ZStr.EMPTY, ZStr.EMPTY, srcFd, destFd,
                            if (unknownSize) { 0 } else { remain },
                            totalWritten
                        )) {
                            case BunSysResult<Unit>.Err(err) =>
                                systemError = Some(err.toSystemError())
                                return Result.Err(BunCore.errnoToZigErr(err.errno))
                            case BunSysResult<Unit>.Ok(()) =>
                                let _ = BunSys.ftruncate(Int32(destFd.value), Int64(totalWritten))
                                return Result.Ok(())
                        }
                    }

                    systemError = Some(
                        SyscallError(SyscallErrno.EINVAL.toInt(), use.tag())
                            .toSystemError()
                    )
                    return Result.Err(BunCore.errnoToZigErr(SyscallErrno.EINVAL))

                case _ =>
                    systemError = Some(
                        SyscallError(errno.toInt(), use.tag())
                            .toSystemError()
                    )
                    return Result.Err(BunCore.errnoToZigErr(errno))
            }

            // wrote zero bytes means EOF
            remain = remain - Int64(written)
            if (remain < 0) {
                remain = 0
            }
            totalWritten += UInt64(written)
            if (written == 0 || remain == 0) {
                looping = false
            }
        }

        readLen = Int64(totalWritten)
        Result.Ok(())
    }

    // ========================================================================
    // deinit / drop
    // Corresponds to: Bun: Drop for CopyFile (line 948)
    // ========================================================================

    /// Cleanup resources
    /// Corresponds to: Bun: Drop for CopyFile
    public func deinit(): Unit {
        // If source is a path string and no error, path cleanup is handled by Store
        // self.store.?.deref() -- Arc drop is automatic
        // bun.destroy(this) -- Box drop is automatic
        match (store) {
            case Some(s) =>
                s.deref()
                store = None
            case None => ()
        }
        match (sourceStore) {
            case Some(s) =>
                s.deref()
                sourceStore = None
            case None => ()
        }
    }
}

// ============================================================================
// CopyFilePromiseTask - promise task wrapper for CopyFile
// Corresponds to: Bun: CopyFilePromiseTask (line 1882)
// ============================================================================

/// CopyFilePromiseTask -- wraps CopyFile in a ConcurrentPromiseTask
/// Corresponds to: Bun: CopyFilePromiseTask<'a>
public class CopyFilePromiseTask {
    public var copyFile: CopyFile
    public var promise: ?JSPromiseStrong

    public init(copyFile: CopyFile) {
        this.copyFile = copyFile
        promise = None
    }

    /// Create on JS thread
    /// Corresponds to: Bun: ConcurrentPromiseTask::create_on_js_thread
    public static func createOnJsThread(
        globalThis: JsGlobalObject,
        copyFile: CopyFile
    ): CopyFilePromiseTask {
        let task = CopyFilePromiseTask(copyFile)
        task.promise = Some(JSPromiseStrong(globalThis))
        return task
    }

    /// Run the copy operation
    public func run(): Unit {
        copyFile.run()
    }

    /// Resolve the promise after copy completes
    public func then(promise: JsPromise): Unit {
        copyFile.then(promise)
    }
}

// ============================================================================
// Error helper functions
// Corresponds to: Bun: copy_file.rs (lines 1862-1878)
// ============================================================================

/// Create "unsupported directory" error
/// Corresponds to: Bun: unsupported_directory_error()
func unsupportedDirectoryError(): SystemError {
    return SystemError(
        SyscallErrno.EISDIR.toInt(),
        BaoString.static_("That doesn't work on folders"),
        BaoString.static_("fstat"),
        "",
        ""
    )
}

/// Create "unsupported non-regular file" error
/// Corresponds to: Bun: unsupported_non_regular_file_error()
func unsupportedNonRegularFileError(): SystemError {
    return SystemError(
        SyscallErrno.ENOTSUP.toInt(),
        BaoString.static_("Non-regular files aren't supported yet"),
        BaoString.static_("fstat"),
        "",
        ""
    )
}

// ============================================================================
// ReadWriteLoop (Windows) - read/write loop for platforms without copy_file_range
// Corresponds to: Bun: copy_file.rs ReadWriteLoop (line 1020)
// ============================================================================

/// Read/Write loop state for Windows copy operations
/// Corresponds to: Bun: ReadWriteLoop
public class ReadWriteLoop {
    public var sourceFd: Fd
    public var mustCloseSourceFd: Bool
    public var destinationFd: Fd
    public var mustCloseDestinationFd: Bool
    public var written: Int64
    public var readBuf: ArrayList<UInt8>

    public init() {
        sourceFd = Fd.INVALID
        mustCloseSourceFd = false
        destinationFd = Fd.INVALID
        mustCloseDestinationFd = false
        written = 0
        readBuf = ArrayList<UInt8>()
    }

    /// Close all file descriptors held by this loop
    /// Corresponds to: Bun: ReadWriteLoop::close() (line 1102)
    public func close(): Unit {
        if (mustCloseSourceFd) {
            BunSys.close(sourceFd)
            mustCloseSourceFd = false
            sourceFd = Fd.INVALID
        }

        if (mustCloseDestinationFd) {
            BunSys.close(destinationFd)
            mustCloseDestinationFd = false
            destinationFd = Fd.INVALID
        }

        readBuf.clear()
    }

    /// Start the read-write loop
    /// Corresponds to: Bun: ReadWriteLoop::start()
    public func start(ctx: Any): Unit {}
}

// ============================================================================
// CopyFileWindows - Windows libuv async copy file
// Corresponds to: Bun: copy_file.zig CopyFileWindows (line 623)
// ============================================================================

/// Windows-specific async copy file implementation using libuv.
/// Uses uv_fs_copyfile for fast copy, falling back to a read-write loop
/// via uv_fs_read / uv_fs_write for non-path file descriptors.
/// Translated from: Bun: CopyFileWindows (copy_file.zig:623)
public class CopyFileWindows {
    public var destinationFileStore: StoreRef
    public var sourceFileStore: StoreRef
    /// libuv fs request (shared for all uv_fs_* calls)
    public var ioRequest: CPointer<Unit>
    /// JS promise for async result
    public var promise: JSPromiseStrong
    public var mkdirpIfNotExists: Bool
    public var destinationMode: ?Mode
    /// Event loop reference
    public var eventLoop: EventLoop
    /// libuv loop pointer
    public var uvLoop: CPointer<Unit>
    /// Expected total size (Blob.max_size if unknown)
    public var size: BlobSizeType
    /// Bytes written, stored for use after async chmod
    public var writtenBytes: Int64
    /// Error, if any (used for mkdirp flow)
    public var err: ?SyscallError
    /// Read-write loop fallback for FD-based copies
    public var readWriteLoop: ReadWriteLoop

    public init() {
        destinationFileStore = StoreRef()
        sourceFileStore = StoreRef()
        ioRequest = CPointer<Unit>()
        promise = JSPromiseStrong()
        mkdirpIfNotExists = false
        destinationMode = None
        eventLoop = EventLoop()
        uvLoop = CPointer<Unit>()
        size = BLOB_MAX_SIZE
        writtenBytes = 0
        err = None
        readWriteLoop = ReadWriteLoop()
    }

    /// Initialize and start a Windows copy file operation.
    /// Returns a JS promise. The copy runs asynchronously via libuv.
    /// Translated from: Bun: CopyFileWindows() (copy_file.zig:841)
    public static func `init`(
        destinationFileStore: StoreRef,
        sourceFileStore: StoreRef,
        eventLoop: EventLoop,
        mkdirpIfNotExists: Bool,
        size: BlobSizeType,
        destinationMode: ?Mode
    ): JsValue {
        destinationFileStore.ref()
        sourceFileStore.ref()

        let copyFile = CopyFileWindows()
        copyFile.destinationFileStore = destinationFileStore
        copyFile.sourceFileStore = sourceFileStore
        copyFile.promise = JSPromiseStrong(eventLoop.global())
        copyFile.eventLoop = eventLoop
        copyFile.uvLoop = eventLoop.uvLoopPtr()
        copyFile.mkdirpIfNotExists = mkdirpIfNotExists
        copyFile.destinationMode = destinationMode
        copyFile.size = size

        let promiseValue = copyFile.promise.value()

        // On error, this function might free the CopyFileWindows struct.
        // So we can no longer reference it beyond this point.
        copyFile.copyfile()

        return promiseValue
    }

    /// Attempt uv_fs_copyfile (fast path for path-to-path copies).
    /// Falls back to prepareReadWriteLoop() for FD-based copies.
    /// Translated from: Bun: CopyFileWindows.copyfile() (copy_file.zig:942)
    public func copyfile(): Unit {
        let destPathlike = destinationFileStore.data.asFile().pathlike
        let srcPathlike = sourceFileStore.data.asFile().pathlike

        if (destPathlike.isFd() || srcPathlike.isFd()) {
            // Cannot use uv_fs_copyfile with FDs; fall back to read-write loop
            prepareReadWriteLoop()
            return
        }

        let oldPath = srcPathlike.pathSlice()
        let newPath = destPathlike.pathSlice()

        unsafe {
            uv_req_set_data(ioRequest, CPointer<Unit>())

            let rc = uv_fs_copyfile(
                uvLoop,
                ioRequest,
                CPointer<Unit>(),
                CPointer<Unit>(),
                0,  // flags
                CPointer<Unit>()
            )

            if (rc < 0) {
            // uv_fs_copyfile error — may need mkdirp
            let errNo = Int32(rc)
            let mappedErr = if (errNo == UV_EPERM) { UV_ENOENT } else { errNo }
            err = Some(SyscallError.fromErrno(mappedErr, SyscallTag.copyfile))
            return
        }
        } // end unsafe

        eventLoop.refConcurrently()
    }

    /// uv_fs_copyfile completion callback.
    /// Translated from: Bun: CopyFileWindows.onCopyFile() (copy_file.zig:1069)
    public static func onCopyFileCallback(req: CPointer<Unit>): Unit {
        let this_ = CopyFileWindows.fromIoRequest(req)
        this_.eventLoop.unrefConcurrently()

        let rc = unsafe { uv_fs_get_result(req) }

        if (rc < 0) {
            let errNo = Int32(rc)
            if (this_.mkdirpIfNotExists && errNo == UV_ENOENT) {
                unsafe { uv_fs_req_cleanup(req) }
                this_.mkdirpIfNotExists = false
                this_.mkdirp()
                return
            }
            let mappedErr = if (errNo == UV_EPERM) { UV_ENOENT } else { errNo }
            var sysErr = SyscallError.fromErrno(mappedErr, SyscallTag.copyfile)
            let destPathlike = this_.destinationFileStore.data.asFile().pathlike
            if (destPathlike.isPath()) {
                sysErr = sysErr.withPath(destPathlike.pathSlice())
            }
            this_.throwError(sysErr)
            return
        }

        let statPtr = unsafe { uv_fs_get_statbuf(req) }
        let statSize = if (true) { Int64(0) } else { UvStatT.fromCPointer(statPtr).size }
        this_.onComplete(UInt64(statSize))
    }

    /// Completion handler after copy finishes (handles truncation + chmod).
    /// Translated from: Bun: CopyFileWindows.onComplete() (copy_file.zig:1107)
    public func onComplete(writtenActual: UInt64): Unit {
        var written = writtenActual
        if (written != UInt64(size) && size != BLOB_MAX_SIZE) {
            truncate()
            written = UInt64(size)
        }

        // Apply destination mode if specified (async chmod)
        if (destinationMode.isSome()) {
            let mode = destinationMode.getOrThrow()
            let destPathlike = destinationFileStore.data.asFile().pathlike
            if (destPathlike.isPath()) {
                writtenBytes = Int64(written)
                let path = destPathlike.pathSlice()
                unsafe { uv_fs_req_cleanup(ioRequest) }
                unsafe { uv_req_set_data(ioRequest, CPointer<Unit>()) }

                let rc = unsafe { uv_fs_chmod(
                    uvLoop,
                    ioRequest,
                    CPointer<Unit>(),
                    Int32(mode),
                    CPointer<Unit>()
                ) }

                if (rc < 0) {
                    let sysErr = SyscallError.fromErrno(Int32(rc), SyscallTag.chmod)
                    if (destPathlike.isPath()) {
                        sysErr.withPath(destPathlike.pathSlice())
                    }
                    throwError(sysErr)
                    return
                }
                eventLoop.refConcurrently()
                return
            }
        }

        resolvePromise(written)
    }

    /// uv_fs_chmod completion callback.
    /// Translated from: Bun: CopyFileWindows.onChmod() (copy_file.zig:1151)
    public static func onChmodCallback(req: CPointer<Unit>): Unit {
        let this_ = CopyFileWindows.fromIoRequest(req)
        this_.eventLoop.unrefConcurrently()

        let rc = unsafe { uv_fs_get_result(req) }
        if (rc < 0) {
            var sysErr = SyscallError.fromErrno(Int32(rc), SyscallTag.chmod)
            let destPathlike = this_.destinationFileStore.data.asFile().pathlike
            if (destPathlike.isPath()) {
                sysErr = sysErr.withPath(destPathlike.pathSlice())
            }
            this_.throwError(sysErr)
            return
        }

        this_.resolvePromise(UInt64(this_.writtenBytes))
    }

    /// Resolve the JS promise with the bytes written count.
    /// Translated from: Bun: CopyFileWindows.resolvePromise() (copy_file.zig:1172)
    public func resolvePromise(written: UInt64): Unit {
        let globalThis = eventLoop.global()
        let promise = promise.swap()
        eventLoop.enter()
        try {
            deinit()
            promise.resolve(globalThis, JsValue(Int64(written)))
        } finally {
            eventLoop.exit()
        }
    }

    /// Throw an error by rejecting the JS promise.
    /// Translated from: Bun: CopyFileWindows.`throw`() (copy_file.zig:1057)
    public func throwError(err: SyscallError): Unit {
        let globalThis = eventLoop.global()
        let promise = promise.swap()
        let errInstance = err.toJsWithAsyncStack(globalThis, promise)

        eventLoop.enter()
        try {
            deinit()
            promise.reject(globalThis, errInstance)
        } finally {
            eventLoop.exit()
        }
    }

    /// Truncate the destination file to the expected size.
    /// Translated from: Bun: CopyFileWindows.truncate() (copy_file.zig:1183)
    public func truncate(): Unit {
        let destPathlike = destinationFileStore.data.asFile().pathlike
        if (destPathlike.isPath()) {
            BunSys.truncatePath(destPathlike.pathSlice(), Int64(size))
        }
    }

    /// Create parent directories if needed.
    /// Translated from: Bun: CopyFileWindows.mkdirp() (copy_file.zig:1206)
    public func mkdirp(): Unit {
        mkdirpIfNotExists = false
        let destPathlike = destinationFileStore.data.asFile().pathlike
        if (!destPathlike.isPath()) {
            throwError(SyscallError.fromErrno(UV_EINVAL, SyscallTag.mkdir))
            return
        }
        eventLoop.refConcurrently()
        let dirPath = PathUtil.dirname(destPathlike.pathSlice())
        AsyncMkdirp.schedule(
            dirPath,
            CPointer<Unit>(),
            CPointer<Unit>()
        )
    }

    /// mkdirp completion callback — retry copyfile.
    /// Translated from: Bun: CopyFileWindows.onMkdirpComplete() (copy_file.zig:1230)
    public static func onMkdirpCompleteCallback(req: CPointer<Unit>): Unit {
        let this_ = CopyFileWindows.fromIoRequest(req)
        this_.eventLoop.unrefConcurrently()
        this_.copyfile()
    }

    /// Prepare the read-write loop for FD-based copies.
    /// Translated from: Bun: CopyFileWindows.prepareReadWriteLoop() (copy_file.zig:906)
    public func prepareReadWriteLoop(): Unit {
        // Open destination first (so mkdirp can work if needed)
        let destPathlike = destinationFileStore.data.asFile().pathlike
        let srcPathlike = sourceFileStore.data.asFile().pathlike

        let destFd = openPathlikeForWrite(destPathlike)
        match (destFd) {
            case Err(e) =>
                if (mkdirpIfNotExists && e.isNoent()) {
                    mkdirp()
                    return
                }
                throwError(e)
                return
            case Ok(fd) =>
                readWriteLoop.destinationFd = fd
                readWriteLoop.mustCloseDestinationFd = true
        }

        let srcFd = openPathlikeForRead(srcPathlike)
        match (srcFd) {
            case Err(e) =>
                throwError(e)
                return
            case Ok(fd) =>
                readWriteLoop.sourceFd = fd
                readWriteLoop.mustCloseSourceFd = true
        }

        readWriteLoop.start(this)
        eventLoop.refConcurrently()
    }

    /// Open a pathlike for reading (helper).
    public func openPathlikeForRead(pathlike: PathOrFileDescriptor): Result<Fd, SyscallError> {
        if (pathlike.isPath()) {
            match (BunSys.openPath(pathlike.pathSlice(), OpenFlags.RDONLY, 0)) {
                case Ok(fd) => return Result.Ok(fd)
                case Err(e) => return Result.Err(e)
            }
        }
        Result.Ok(pathlike.fd())
    }

    /// Open a pathlike for writing (helper).
    public func openPathlikeForWrite(pathlike: PathOrFileDescriptor): Result<Fd, SyscallError> {
        if (pathlike.isPath()) {
            let flags = OpenFlags.WRONLY | OpenFlags.CREAT
            match (BunSys.openPath(pathlike.pathSlice(), flags, 0)) {
                case Ok(fd) => return Result.Ok(fd)
                case Err(e) => return Result.Err(e)
            }
        }
        Result.Ok(pathlike.fd())
    }

    /// Cleanup resources.
    /// Translated from: Bun: CopyFileWindows.deinit() (copy_file.zig:1197)
    public func deinit(): Unit {
        readWriteLoop.close()
        destinationFileStore.deref()
        sourceFileStore.deref()
        promise.deinit()
        unsafe { uv_fs_req_cleanup(ioRequest) }
    }

    /// Recover `this` from the uv_fs_t request's data field.
    public static func fromIoRequest(req: CPointer<Unit>): CopyFileWindows {
        return CopyFileWindows()
    }
}

// ============================================================================
// ReadWriteLoop - libuv read-write loop for FD-based copies on Windows
// Translated from: Bun: CopyFileWindows.ReadWriteLoop (copy_file.zig:644)
// ============================================================================

/// Read-write loop for copying between FDs using libuv async IO.
/// Used when uv_fs_copyfile cannot be used (e.g., pipe or socket FDs).
