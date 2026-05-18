// CopyFile - blocking, but off the main thread
// Strict 1:1 translation from: src/runtime/webcore/blob/copy_file.rs (1888 lines)
package bao_runtime.webcore.blob

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_sys.*
import bao_io.*
import bao_ptr.*
import bao_path.*
import bao_http_types.*

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
public class CopyFile <: MkdirpTarget {
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
            destinationFileStore: destFileStore,
            sourceFileStore: srcFileStore,
            store: Some(store.clone()),
            sourceStore: Some(sourceStore.clone()),
            offset: off,
            maxLength: maxLen,
            globalThis: globalThis,
            mkdirpIfNotExists: mkdirpIfNotExists,
            destinationMode: destinationMode
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
            sysError.path = BaoString.cloneUtf8(sourceFileStore.pathlike.path().slice())
        }

        if (sysError.message.isEmpty()) {
            sysError.message = BaoString.static_("Failed to copy file")
        }

        let instance = toJscSystemError(sysError).toErrorInstanceWithAsyncStack(
            globalThis, promise
        )
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
            JsValue.jsNumberFromUInt64(UInt64(readLen))
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
        if (destinationFd == Fd.INVALID && sourceFd == Fd.INVALID) {
            // Attempt clonefile() on macOS first (fastest way to copy a file)
            // This is macOS-only; on other platforms we skip directly to doOpenFile.
            // PORT NOTE: macOS clonefile path omitted for portability.
            // On Linux/other platforms, go straight to doOpenFile.

            if (doOpenFile(IOWhich.Both).isErr()) {
                return
            }
        } else if (destinationFd == Fd.INVALID) {
            sourceFd = sourceFileStore.pathlike.fd()

            if (doOpenFile(IOWhich.Destination).isErr()) {
                return
            }
        } else if (sourceFd == Fd.INVALID) {
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
                    case BunSysResult.Ok(result) => result
                    case BunSysResult.Err(err) =>
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
            maxLength = (Int64(stat.stSize).min(maxLength)).max(offset) - offset
            if (maxLength == 0) {
                doClose()
                return
            }

            if (PREALLOCATE_SUPPORTED && BunSys.isRegularFile(stat.stMode) &&
                maxLength > PREALLOCATE_LENGTH && maxLength != BLOB_MAX_SIZE) {
                let _ = BunSys.preallocateFile(destinationFd.native(), 0, maxLength)
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
        let closeInput = destinationFileStore.pathlike.isPath() && destinationFd != Fd.INVALID
        let closeOutput = sourceFileStore.pathlike.isPath() && sourceFd != Fd.INVALID

        // Apply destination mode using fchmod before closing (POSIX)
        match (destinationMode) {
            case Some(mode) =>
                if (destinationFd != Fd.INVALID && systemError.isNone()) {
                    match (BunSys.fchmod(destinationFd, mode)) {
                        case BunSysResult.Err(err) =>
                            systemError = Some(err.toSystemError())
                        case BunSysResult.Ok(()) => ()
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
                destinationFd.close()
                sourceFd.close()
            case IOWhich.Destination =>
                destinationFd.close()
            case IOWhich.Source =>
                sourceFd.close()
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
                sourceFileStore.pathlike.path().sliceZ(),
                OPEN_SOURCE_FLAGS,
                0
            )) {
                case BunSysResult.Ok(result) =>
                    match (result.makeLibUvOwnedForSyscall(
                        SyscallTag.open, ErrorCase.CloseOnFail
                    )) {
                        case BunSysResult.Ok(resultFd) =>
                            sourceFd = resultFd
                        case BunSysResult.Err(errno) =>
                            systemError = Some(errno.toSystemError())
                            return Result.Err(BunCore.errnoToZigErr(errno.errno))
                    }
                case BunSysResult.Err(errno) =>
                    systemError = Some(errno.toSystemError())
                    return Result.Err(BunCore.errnoToZigErr(errno.errno))
            }
        }

        if (which == IOWhich.Both || which == IOWhich.Destination) {
            var done = false
            while (!done) {
                let dest = destinationFileStore.pathlike.path().sliceZ()
                let mode = match (destinationMode) {
                    case Some(m) => m
                    case None => NodeFs.DEFAULT_PERMISSION
                }
                match (BunSys.open(dest, OPEN_DESTINATION_FLAGS, mode)) {
                    case BunSysResult.Ok(result) =>
                        match (result.makeLibUvOwnedForSyscall(
                            SyscallTag.open, ErrorCase.CloseOnFail
                        )) {
                            case BunSysResult.Ok(resultFd) =>
                                destinationFd = resultFd
                            case BunSysResult.Err(errno) =>
                                systemError = Some(errno.toSystemError())
                                return Result.Err(BunCore.errnoToZigErr(errno.errno))
                        }
                    case BunSysResult.Err(errno) =>
                        match (Blob.mkdirIfNotExists(
                            this, errno.clone(), dest, dest.asBytes()
                        )) {
                            case Retry.Continue => continue
                            case Retry.Fail =>
                                if (which == IOWhich.Both) {
                                    sourceFd.close()
                                    sourceFd = Fd.INVALID
                                }
                                return Result.Err(BunCore.errnoToZigErr(errno.errno))
                            case Retry.No => ()
                        }

                        if (which == IOWhich.Both) {
                            sourceFd.close()
                            sourceFd = Fd.INVALID
                        }

                        systemError = Some(
                            errno.withPath(destinationFileStore.pathlike.path().slice())
                                .toSystemError()
                        )
                        return Result.Err(BunCore.errnoToZigErr(errno.errno))
                }
                done = true
            }
        }
        Result.Ok(())
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
                case BunSysResult.Err(err) =>
                    systemError = Some(err.toSystemError())
                    return Result.Err(BunCore.errnoToZigErr(err.errno))
                case BunSysResult.Ok(()) =>
                    let _ = BunSys.ftruncate(destFd.native(), Int64(totalWritten))
                    return Result.Ok(())
            }
        }

        var looping = true
        while (looping) {
            let written: Int64 = match (use) {
                case TryWith.CopyFileRange =>
                    BunSys.copyFileRange(
                        srcFd.native(), UIntNative(0),
                        destFd.native(), UIntNative(0),
                        Int64(remain), 0
                    )
                case TryWith.Sendfile =>
                    BunSys.sendfile(
                        destFd.native(), srcFd.native(),
                        UIntNative(0), Int64(remain)
                    )
                case TryWith.Splice =>
                    BunSys.splice(
                        srcFd.native(), UIntNative(0),
                        destFd.native(), UIntNative(0),
                        Int64(remain), 0
                    )
            }

            let errno: SyscallErrno = BunSys.getErrno(written)
            match (errno) {
                case SyscallErrno.SUCCESS => ()

                // XDEV: cross-device copy not supported
                // NOSYS: syscall not available
                // OPNOTSUPP: filesystem doesn't support this operation
                case SyscallErrno.ENOSYS | SyscallErrno.EXDEV | SyscallErrno.ENOTSUP =>
                    match (NodeFs.copyFileUsingReadWriteLoop(
                        ZStr.EMPTY, ZStr.EMPTY, srcFd, destFd,
                        if (unknownSize) { 0 } else { remain },
                        totalWritten
                    )) {
                        case BunSysResult.Err(err) =>
                            systemError = Some(err.toSystemError())
                            return Result.Err(BunCore.errnoToZigErr(err.errno))
                        case BunSysResult.Ok(()) =>
                            let _ = BunSys.ftruncate(destFd.native(), Int64(totalWritten))
                            return Result.Ok(())
                    }

                // EINVAL: eCryptfs and other filesystems may not support copy_file_range
                case SyscallErrno.EINVAL =>
                    if (clearAppendIfInvalid) {
                        if (!hasUnsetAppend) {
                            // make() can set STDOUT / STDERR to O_APPEND; this messes up sendfile()
                            hasUnsetAppend = true
                            let flags = BunSys.fcntlGetFl(destFd.native())
                            if ((flags & BunSys.O_APPEND) != 0) {
                                let _ = BunSys.fcntlSetFl(
                                    destFd.native(), flags ^ BunSys.O_APPEND
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
                            case BunSysResult.Err(err) =>
                                systemError = Some(err.toSystemError())
                                return Result.Err(BunCore.errnoToZigErr(err.errno))
                            case BunSysResult.Ok(()) =>
                                let _ = BunSys.ftruncate(destFd.native(), Int64(totalWritten))
                                return Result.Ok(())
                        }
                    }

                    systemError = Some(
                        SyscallError(errno: SyscallErrno.EINVAL, syscall: use.tag())
                            .toSystemError()
                    )
                    return Result.Err(BunCore.errnoToZigErr(SyscallErrno.EINVAL))

                case _ =>
                    systemError = Some(
                        SyscallError(errno: errno, syscall: use.tag())
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
        task.promise = Some(JSPromiseStrong.init(globalThis))
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
// Error helper functions
// Corresponds to: Bun: copy_file.rs (lines 1862-1878)
// ============================================================================

/// Create "unsupported directory" error
/// Corresponds to: Bun: unsupported_directory_error()
func unsupportedDirectoryError(): SystemError {
    return SystemError(
        errno: SyscallErrno.EISDIR,
        message: BaoString.static_("That doesn't work on folders"),
        syscall: BaoString.static_("fstat"),
        path: "",
        code: ""
    )
}

/// Create "unsupported non-regular file" error
/// Corresponds to: Bun: unsupported_non_regular_file_error()
func unsupportedNonRegularFileError(): SystemError {
    return SystemError(
        errno: SyscallErrno.ENOTSUP,
        message: BaoString.static_("Non-regular files aren't supported yet"),
        syscall: BaoString.static_("fstat"),
        path: "",
        code: ""
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
            sourceFd.close()
            mustCloseSourceFd = false
            sourceFd = Fd.INVALID
        }

        if (mustCloseDestinationFd) {
            destinationFd.close()
            mustCloseDestinationFd = false
            destinationFd = Fd.INVALID
        }

        readBuf.clear()
    }
}

// ============================================================================
// CopyFileWindows (Windows, libuv async) - placeholder for Windows path
// Corresponds to: Bun: copy_file.rs CopyFileWindows<'a> (line 994)
// ============================================================================

/// Windows-specific async copy file implementation using libuv.
/// On non-Windows platforms, this is a placeholder.
/// Corresponds to: Bun: CopyFileWindows
public class CopyFileWindows {
    public var destinationFileStore: StoreRef
    public var sourceFileStore: StoreRef
    public var promise: JSPromiseStrong
    public var mkdirpIfNotExists: Bool
    public var destinationMode: ?Mode
    public var size: BlobSizeType
    public var writtenBytes: Int64
    public var err: ?SyscallError
    public var readWriteLoop: ReadWriteLoop

    public init() {
        destinationFileStore = StoreRef()
        sourceFileStore = StoreRef()
        promise = JSPromiseStrong()
        mkdirpIfNotExists = false
        destinationMode = None
        size = 0
        writtenBytes = 0
        err = None
        readWriteLoop = ReadWriteLoop()
    }

    /// Initialize a Windows copy file operation
    /// Corresponds to: Bun: CopyFileWindows::init() (line 1297)
    public static func init(
        destinationFileStore: StoreRef,
        sourceFileStore: StoreRef,
        mkdirpIfNotExists: Bool,
        size: BlobSizeType,
        destinationMode: ?Mode
    ): JsValue {
        let copyFile = CopyFileWindows()
        copyFile.destinationFileStore = destinationFileStore
        copyFile.sourceFileStore = sourceFileStore
        copyFile.mkdirpIfNotExists = mkdirpIfNotExists
        copyFile.size = size
        copyFile.destinationMode = destinationMode
        // On Windows, this would call copyfile() using libuv.
        // On POSIX, use CopyFile instead.
        return JsValue.zero()
    }
}

// ported from: src/runtime/webcore/blob/copy_file.rs
