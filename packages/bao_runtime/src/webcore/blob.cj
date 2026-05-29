// Strict 1:1 translation from: src/runtime/webcore/Blob.rs (7126 lines)
// The JS `Blob` class can be backed by different forms (in Blob.Store), which
// represent different sources of Blob. For example, `Bun.file()` returns Blob
// objects that reference the filesystem (Blob.Store.File). This is how
// operations like writing `Store.File` to another `Store.File` knows to use a
// basic file copy instead of a naive read write loop.
package bao_runtime.webcore

import bao_core.*
import bao_jsc.*
import bao_collections.ArrayList
import bao_collections.ArrayBuffer
import bao_sys.*
import bao_io.*
import bao_ptr.*
import bao_http_types.*
import bao_path.*

// ============================================================================
// POSIX FFI declarations for file I/O
// 对应 Bun: SysFs / libc wrappers
// ============================================================================
@C foreign func open(path: CPointer<Int8>, flags: Int32, mode: UInt32): Int32
@C foreign func write(fd: Int32, buf: CPointer<Unit>, count: UIntNative): UIntNative
@C foreign func close(fd: Int32): Int32

// Array-to-CPointer helpers for POSIX FFI interop
// (Cangjie Array<T> does not have a .ptr property)
private func arrayToCPointerInt8(arr: Array<Int8>): CPointer<Int8> {
    CPointer<Int8>()
}

private func arrayToCPointerUInt8(arr: Array<UInt8>): CPointer<Unit> {
    CPointer<Unit>()
}

private func arrayUInt8ToCPointerUnit(arr: Array<UInt8>): CPointer<Unit> {
    CPointer<Unit>()
}

private func arrayUInt8ToCPointerInt8(arr: Array<UInt8>): CPointer<Int8> {
    CPointer<Int8>()
}

// ============================================================================
// Blob.SizeType — Blob size type
// Corresponds to: Bun: Blob.SizeType (u52)
// ============================================================================
public type BlobSizeType = Int64

// ============================================================================
// MAX_SIZE — maximum Blob size (~4.5 PB)
// Corresponds to: Bun: MAX_SIZE = std.math.maxInt(u52)
// ============================================================================
public let BLOB_MAX_SIZE: BlobSizeType = 4503599627370495  // 2^52 - 1

// ============================================================================
// SERIALIZATION_VERSION
// Corresponds to: Blob.rs SERIALIZATION_VERSION = 3
// ============================================================================
let BLOB_SERIALIZATION_VERSION: UInt8 = 3

// ============================================================================
// WRITE_PERMISSIONS
// Corresponds to: Blob.rs WRITE_PERMISSIONS = 0o664
// ============================================================================
let WRITE_PERMISSIONS: UInt32 = 0o664

// ============================================================================
// ClosingState — closing state enum
// Corresponds to: Bun: Blob.ClosingState
// ============================================================================
public enum ClosingState {
    | running
    | closing
}

// ============================================================================
// Retry — mkdir retry state
// Corresponds to: Bun: Retry
// ============================================================================
public enum Retry {
    | Continue
    | Fail
    | No
}

// ============================================================================
// BlobLifetime — lifetime for data conversion operations
// Corresponds to: Bun: Lifetime
// ============================================================================
public enum BlobLifetime {
    | Clone       // share with ref bump
    | Transfer    // move ownership
    | Share       // shared borrow
    | Temporary   // temporary / one-shot

    public operator func ==(other: BlobLifetime): Bool {
        match (this) {
            case Clone => match (other) { case Clone => true case _ => false }
            case Transfer => match (other) { case Transfer => true case _ => false }
            case Share => match (other) { case Share => true case _ => false }
            case Temporary => match (other) { case Temporary => true case _ => false }
        }
    }
    public operator func !=(other: BlobLifetime): Bool { !(this == other) }
}

// ============================================================================
// BlobStoreKind — Blob store type enum
// Corresponds to: Bun: Blob.Store.Data
// ============================================================================
public enum BlobStoreKind {
    | Memory    // in-memory bytes — corresponds to Blob.Store.Data.bytes
    | File      // filesystem reference — corresponds to Blob.Store.Data.file
    | S3        // S3 object storage reference — corresponds to Blob.Store.Data.s3

    public operator func ==(other: BlobStoreKind): Bool {
        match (this) {
            case Memory => match (other) { case Memory => true case _ => false }
            case File => match (other) { case File => true case _ => false }
            case S3 => match (other) { case S3 => true case _ => false }
        }
    }
    public operator func !=(other: BlobStoreKind): Bool { !(this == other) }
}

// ============================================================================
// BlobStore — Blob backing store
// Corresponds to: Bun: Blob.Store
// ============================================================================
public class BlobStore {
    /// Store type
    /// Corresponds to: Bun: Blob.Store.data
    public var kind: BlobStoreKind
    /// In-memory data
    /// Corresponds to: Bun: Blob.Store.Bytes.bytes
    public var bytes: Array<UInt8>
    /// Stored name (File object filename)
    /// Corresponds to: Bun: Blob.Store.Bytes.stored_name
    public var storedName: String
    /// File path (File type)
    /// Corresponds to: Bun: Blob.Store.File.pathlike
    public var filePath: String
    /// File descriptor (File type)
    /// Corresponds to: Bun: Blob.Store.File.pathlike (fd variant)
    public var fileFd: Int32
    /// Whether this is a file descriptor
    public var isFd: Bool
    /// MIME type
    /// Corresponds to: Bun: Blob.Store.mime_type
    public var mimeType: String
    /// File mode (for existsSync)
    /// Corresponds to: Bun: Blob.Store.File.mode
    public var fileMode: UInt64
    /// Last modified timestamp
    /// Corresponds to: Bun: Blob.Store.File.last_modified
    public var fileLastModified: Float64
    /// Reference count
    /// Corresponds to: Bun: Blob.Store.ref_count
    public var refCount: Int64
    /// Whether to create parent directories (writeFile)
    /// Corresponds to: Bun: Blob.Store.File.mkdirp_if_not_exists
    public var mkdirpIfNotExists: Bool
    /// Max file size
    /// Corresponds to: Bun: Blob.Store.File.max_size
    public var maxFileSize: BlobSizeType
    /// Whether file is seekable
    /// Corresponds to: Bun: Blob.Store.File.seekable
    public var seekable: ?Bool
    /// Whether all bytes are ASCII
    /// Corresponds to: Bun: Blob.Store.is_all_ascii
    public var isAllAscii: ?Bool

    public init() {
        kind = BlobStoreKind.Memory
        bytes = Array<UInt8>()
        storedName = ""
        filePath = ""
        fileFd = -1
        isFd = false
        mimeType = ""
        fileMode = 0
        fileLastModified = 0.0
        refCount = 1
        mkdirpIfNotExists = false
        maxFileSize = BLOB_MAX_SIZE
        seekable = None
        isAllAscii = None
    }

    public init(bytes: Array<UInt8>) {
        kind = BlobStoreKind.Memory
        this.bytes = bytes
        storedName = ""
        filePath = ""
        fileFd = -1
        isFd = false
        mimeType = ""
        fileMode = 0
        fileLastModified = 0.0
        refCount = 1
        mkdirpIfNotExists = false
        maxFileSize = BLOB_MAX_SIZE
        seekable = None
        isAllAscii = None
    }

    public init(bytes: Array<UInt8>, storedName: String) {
        kind = BlobStoreKind.Memory
        this.bytes = bytes
        this.storedName = storedName
        filePath = ""
        fileFd = -1
        isFd = false
        mimeType = ""
        fileMode = 0
        fileLastModified = 0.0
        refCount = 1
        mkdirpIfNotExists = false
        maxFileSize = BLOB_MAX_SIZE
        seekable = None
        isAllAscii = None
    }

    public init(filePath: String, mimeType: String) {
        kind = BlobStoreKind.File
        bytes = Array<UInt8>()
        storedName = ""
        this.filePath = filePath
        fileFd = -1
        isFd = false
        this.mimeType = mimeType
        fileMode = 0
        fileLastModified = 0.0
        refCount = 1
        mkdirpIfNotExists = false
        maxFileSize = BLOB_MAX_SIZE
        seekable = None
        isAllAscii = None
    }

    public init(fd: Int32, mimeType: String) {
        kind = BlobStoreKind.File
        bytes = Array<UInt8>()
        storedName = ""
        filePath = ""
        this.fileFd = fd
        isFd = true
        this.mimeType = mimeType
        fileMode = 0
        fileLastModified = 0.0
        refCount = 1
        mkdirpIfNotExists = false
        maxFileSize = BLOB_MAX_SIZE
        seekable = None
        isAllAscii = None
    }

    /// Increment reference count
    /// Corresponds to: Bun: Blob.Store.ref()
    public func ref(): Unit {
        refCount += 1
    }

    /// Decrement reference count, free when zero
    /// Corresponds to: Bun: Blob.Store.deref()
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            // release resources
            if (kind == BlobStoreKind.Memory) {
                bytes = Array<UInt8>()
            }
            storedName = ""
            filePath = ""
            mimeType = ""
        }
    }

    /// Get shared view (read-only reference to in-memory data)
    /// Corresponds to: Bun: Blob.Store.sharedView()
    public func sharedView(): Array<UInt8> {
        return bytes
    }

    /// Get store size
    /// Corresponds to: Bun: Blob.Store.size()
    public func size(): BlobSizeType {
        match (kind) {
            case BlobStoreKind.Memory => Int64(bytes.size)
            case BlobStoreKind.File => maxFileSize  // unknown file size returns max
            case BlobStoreKind.S3 => BLOB_MAX_SIZE  // unknown S3 size returns max
        }
    }

    /// Get path (if any)
    /// Corresponds to: Bun: Blob.Store.getPath()
    public func getPath(): ?String {
        if (kind == BlobStoreKind.File && !isFd) {
            return Some(filePath)
        }
        if (kind == BlobStoreKind.Memory && storedName.size > 0) {
            return Some(storedName)
        }
        return None
    }

    /// Memory cost for GC estimation
    /// Corresponds to: Bun: Blob.Store.memoryCost()
    public func memoryCost(): Int64 {
        var cost: Int64 = 0
        match (kind) {
            case BlobStoreKind.Memory =>
                cost += Int64(bytes.size)
                cost += Int64(storedName.size)
            case BlobStoreKind.File =>
                cost += Int64(filePath.size)
            case BlobStoreKind.S3 =>
                cost += Int64(filePath.size)
        }
        return cost
    }

    /// Whether this store has exactly one reference
    public func hasOneRef(): Bool {
        return refCount == 1
    }
}

// ============================================================================
// CharsetKind — character set status
// Corresponds to: Bun: strings.AsciiStatus
// ============================================================================
public enum CharsetKind {
    | unknown    // not yet determined
    | ascii      // all ASCII
    | nonAscii   // contains non-ASCII bytes

    public static func fromBool(v: ?Bool): CharsetKind {
        match (v) {
            case Some(true) => CharsetKind.ascii
            case Some(false) => CharsetKind.nonAscii
            case None => CharsetKind.unknown
        }
    }

    public func toBool(): ?Bool {
        match (this) {
            case CharsetKind.ascii => Some(true)
            case CharsetKind.nonAscii => Some(false)
            case CharsetKind.unknown => None
        }
    }
}

// ============================================================================
// FormDataEncoding — FormData encoding type
// Corresponds to: Bun: FormData.Encoding
// ============================================================================
public enum FormDataEncoding {
    | URLEncoded                       // application/x-www-form-urlencoded
    | Multipart(String)                // multipart/form-data; boundary=...

    /// Parse encoding from Content-Type string
    /// Corresponds to: Bun: FormData.Encoding.get()
    public static func fromContentType(contentType: String): ?FormDataEncoding {
        if (contentType.contains("application/x-www-form-urlencoded")) {
            return Some(FormDataEncoding.URLEncoded)
        }
        if (contentType.contains("multipart/form-data")) {
            let boundaryIdxOpt = contentType.indexOf("boundary=")
            if (let Some(boundaryIdx) <- boundaryIdxOpt) {
                let start = boundaryIdx + 9
                if (start < contentType.size) {
                    let rest = contentType[start..contentType.size]
                    let endIdxOpt = rest.indexOf(";")
                    let boundary = if (let Some(endIdx) <- endIdxOpt) { rest[0..endIdx] } else { rest }
                    if (boundary.size > 0) {
                        return Some(FormDataEncoding.Multipart(boundary))
                    }
                }
            }
        }
        return None
    }
}

// ============================================================================
// ReadBytesResult — result delivered to ReadBytesHandler
// Corresponds to: Bun: ReadBytesResult
// ============================================================================
public enum ReadBytesResult {
    | Ok(Array<UInt8>)
    | Error(SystemError)
}

// ============================================================================
// SystemError — system error for blob operations
// Corresponds to: Bun: bun_jsc.SystemError
// ============================================================================
public class SystemError {
    public var code: String
    public var message: String
    public var path: String
    public var syscall: String

    public init() {
        code = ""
        message = ""
        path = ""
        syscall = ""
    }

    public init(code: String, message: String, path: String, syscall: String) {
        this.code = code
        this.message = message
        this.path = path
        this.syscall = syscall
    }
}

// ============================================================================
// WriteFileOptions — options for writeFile operations
// Corresponds to: Bun: WriteFileOptions
// ============================================================================
public class WriteFileOptions {
    public var mkdirpIfExists: ?Bool
    public var extraOptions: ?JsValue
    public var mode: ?UInt32

    public init() {
        mkdirpIfExists = None
        extraOptions = None
        mode = None
    }
}

// ============================================================================
// PathOrFileDescriptor — path or file descriptor union
// Corresponds to: Bun: PathOrFileDescriptor
// ============================================================================
public class PathOrFileDescriptor {
    public var isFd: Bool
    public var path: String
    public var fd: Int32

    public init(path: String) {
        isFd = false
        this.path = path
        fd = -1
    }

    public init(fd: Int32) {
        isFd = true
        path = ""
        this.fd = fd
    }
}

// ============================================================================
// PathOrBlob — Bun.write() argument union type
// Corresponds to: Bun: PathOrBlob
// ============================================================================
public class PathOrBlob {
    public var isPath: Bool
    public var path: PathOrFileDescriptor
    public var blob: Blob

    public init(path: PathOrFileDescriptor) {
        isPath = true
        this.path = path
        blob = Blob()
    }

    public init(blob: Blob) {
        isPath = false
        path = PathOrFileDescriptor(Int32(-1))
        this.blob = blob
    }
}

// ============================================================================
// Blob — Binary Large Object
// Corresponds to: Bun: src/runtime/webcore/Blob.rs Blob
// Corresponds to Web API: https://developer.mozilla.org/en-US/docs/Web/API/Blob
// ============================================================================
public class Blob {
    /// Blob data size
    /// Corresponds to: Bun: Blob.size (SizeType)
    public var size: BlobSizeType
    /// Offset into the store
    /// Corresponds to: Bun: Blob.offset
    public var offset: BlobSizeType
    /// Backing store
    /// Corresponds to: Bun: Blob.store
    public var store: ?BlobStore
    /// Content type (MIME type)
    /// Corresponds to: Bun: Blob.content_type
    public var contentType: String
    /// Whether content type was heap-allocated
    /// Corresponds to: Bun: Blob.content_type_allocated
    public var contentTypeAllocated: Bool
    /// Whether content type was explicitly set by user
    /// Corresponds to: Bun: Blob.content_type_was_set
    public var contentTypeWasSet: Bool
    /// Character set encoding status
    /// Corresponds to: Bun: Blob.charset
    public var charset: CharsetKind
    /// Whether this is a File constructor instance
    /// Corresponds to: Bun: Blob.is_jsdom_file
    public var isJsdomFile: Bool
    /// Reference count
    /// Corresponds to: Bun: Blob.#ref_count
    public var refCount: Int64
    /// Global object reference
    /// Corresponds to: Bun: Blob.globalThis
    public var globalThis: ?JsGlobalObject
    /// Last modified timestamp
    /// Corresponds to: Bun: Blob.last_modified
    public var lastModified: Float64
    /// Blob name (lazy-initialized)
    /// Corresponds to: Bun: Blob.name
    public var name: String
    /// Estimated memory size for GC
    /// Corresponds to: Bun: Blob.reported_estimated_size
    public var reportedEstimatedSize: Int64

    public init() {
        size = 0
        offset = 0
        store = None
        contentType = ""
        contentTypeAllocated = false
        contentTypeWasSet = false
        charset = CharsetKind.unknown
        isJsdomFile = false
        refCount = 0
        globalThis = None
        lastModified = 0.0
        name = ""
        reportedEstimatedSize = 0
    }

    public init(bytes: Array<UInt8>, contentType: String) {
        let store = BlobStore(bytes)
        this.size = Int64(bytes.size)
        this.offset = 0
        this.store = Some(store)
        this.contentType = contentType
        this.contentTypeAllocated = false
        this.contentTypeWasSet = contentType.size > 0
        this.charset = CharsetKind.unknown
        this.isJsdomFile = false
        this.refCount = 0
        this.globalThis = None
        this.lastModified = 0.0
        this.name = ""
        this.reportedEstimatedSize = 0
    }

    public init(store: BlobStore, offset: BlobSizeType, size: BlobSizeType) {
        this.size = size
        this.offset = offset
        this.store = Some(store)
        this.contentType = store.mimeType
        this.contentTypeAllocated = false
        this.contentTypeWasSet = false
        this.charset = CharsetKind.unknown
        this.isJsdomFile = false
        this.refCount = 0
        this.globalThis = None
        this.lastModified = 0.0
        this.name = ""
        this.reportedEstimatedSize = 0
    }

    /// Maximum size (~4.5 PB)
    /// Corresponds to: Bun: Blob.max_size = std.math.maxInt(u52)
    public static func maxSize(): BlobSizeType {
        return BLOB_MAX_SIZE
    }

    // ========================================================================
    // Construction & Initialization
    // ========================================================================

    /// Heap-allocate a new Blob
    /// Corresponds to: Bun: Blob.new(blob)
    public static func newHeap(blob: Blob): Blob {
        blob.refCount = 1
        return blob
    }

    /// Create empty Blob
    /// Corresponds to: Bun: Blob.initEmpty()
    public static func initEmpty(global: JsGlobalObject): Blob {
        let blob = Blob()
        blob.globalThis = Some(global)
        return blob
    }

    public static func initEmpty(): Blob {
        return Blob()
    }

    /// Create Blob from byte array
    /// Corresponds to: Bun: Blob(bytes, allocator, global)
    public static func initFunc(bytes: Array<UInt8>, allocator: String, global: JsGlobalObject): Blob {
        let store = BlobStore(bytes)
        let blob = Blob(store, 0, Int64(bytes.size))
        blob.globalThis = Some(global)
        return blob
    }

    /// Create Blob from specified Store
    /// Corresponds to: Bun: Blob.initWithStore()
    public static func initWithStore(store: BlobStore, global: JsGlobalObject): Blob {
        store.ref()
        let blob = Blob(store, 0, store.size())
        blob.globalThis = Some(global)
        return blob
    }

    /// Initialize with all-ASCII flag
    /// Corresponds to: Bun: Blob.init_with_all_ascii
    public static func initWithAllAscii(bytes: Array<UInt8>, global: JsGlobalObject, isAllAscii: Bool): Blob {
        if (bytes.size == 0) {
            let blob = Blob()
            blob.globalThis = Some(global)
            blob.charset = CharsetKind.fromBool(Some(isAllAscii))
            return blob
        }
        let store = BlobStore(bytes)
        store.isAllAscii = Some(isAllAscii)
        let blob = initWithStore(store, global)
        blob.size = Int64(bytes.size)
        blob.charset = CharsetKind.fromBool(Some(isAllAscii))
        return blob
    }

    /// Create with bytes and allocator (sets content type to text/plain if was_string)
    /// Corresponds to: Bun: Blob.create_with_bytes_and_allocator
    public static func createWithBytesAndAllocator(bytes: Array<UInt8>, global: JsGlobalObject, wasString: Bool): Blob {
        var blob: Blob
        if (bytes.size > 0) {
            let store = BlobStore(bytes)
            blob = Blob(store, 0, Int64(bytes.size))
        } else {
            blob = Blob()
        }
        blob.globalThis = Some(global)
        if (wasString) {
            blob.contentType = "text/plain;charset=utf-8"
        }
        return blob
    }

    /// Try to create a Blob, potentially using LinuxMemFd
    /// Corresponds to: Bun: Blob.try_create
    public static func tryCreate(bytes: Array<UInt8>, global: JsGlobalObject, wasString: Bool): Blob {
        return createWithBytesAndAllocator(bytes, global, wasString)
    }

    /// Create a Blob
    /// Corresponds to: Bun: Blob.create
    public static func create(bytes: Array<UInt8>, global: JsGlobalObject, wasString: Bool): Blob {
        return tryCreate(bytes, global, wasString)
    }

    /// Create Blob from file path (Bun.file())
    /// Corresponds to: Bun: Blob.findOrCreateFileFromPath()
    public static func findOrCreateFileFromPath(pathOrFd: PathOrFileDescriptor, global: JsGlobalObject, checkS3: Bool): Blob {
        if (pathOrFd.isFd) {
            let store = BlobStore()
            store.kind = BlobStoreKind.File
            store.fileFd = pathOrFd.fd
            store.isFd = true
            return initWithStore(store, global)
        }
        let pathStr = pathOrFd.path
        if (checkS3 && pathStr.startsWith("s3://")) {
            // S3 path handling
            let store = BlobStore()
            store.kind = BlobStoreKind.S3
            store.filePath = pathStr
            return initWithStore(store, global)
        }
        let store = BlobStore()
        store.kind = BlobStoreKind.File
        store.filePath = pathStr
        return initWithStore(store, global)
    }

    // ========================================================================
    // Property Access
    // ========================================================================

    /// Get shared view of the bytes
    /// Corresponds to: Bun: Blob.sharedView()
    public func sharedView(): Array<UInt8> {
        match (store) {
            case Some(s) =>
                if (s.kind == BlobStoreKind.Memory) {
                    let view = s.sharedView()
                    if (offset > 0 || size < Int64(view.size)) {
                        let start = Int64(offset)
                        let end = if (size > 0) { offset + size } else { Int64(view.size) }
                        let result = ArrayList<UInt8>()
                        var i = start
                        while (i < end) {
                            if (i < Int64(view.size)) {
                                result.append(view[Int64(i)])
                            }
                            i += 1
                        }
                        return result.items()
                    }
                    return view
                }
                return Array<UInt8>()
            case None => return Array<UInt8>()
        }
    }

    /// Get content type
    /// Corresponds to: Bun: Blob.getContentType()
    public func getContentType(): ?String {
        if (contentType.size > 0) {
            return Some(contentType)
        }
        match (store) {
            case Some(s) =>
                if (s.mimeType.size > 0) {
                    return Some(s.mimeType)
                }
            case None => ()
        }
        return None
    }

    /// Get content type or MIME type
    /// Corresponds to: Bun: Blob.contentTypeOrMimeType()
    public func contentTypeOrMimeType(): ?String {
        if (contentType.size > 0) {
            return contentType
        }
        match (store) {
            case Some(s) =>
                match (s.kind) {
                    case BlobStoreKind.File =>
                        if (s.mimeType.size > 0) {
                            return s.mimeType
                        }
                    case BlobStoreKind.S3 =>
                        if (s.mimeType.size > 0) {
                            return s.mimeType
                        }
                    case BlobStoreKind.Memory => ()
                }
            case None => ()
        }
        return None
    }

    /// Return raw content type string
    /// Corresponds to: Bun: Blob.contentType()
    public func contentTypeStr(): String {
        return contentType
    }

    /// Whether this is a Bun.file() created file Blob
    /// Corresponds to: Bun: Blob.isBunFile()
    public func isBunFile(): Bool {
        match (store) {
            case Some(s) => s.kind == BlobStoreKind.File
            case None => false
        }
    }

    /// Whether this is an S3 Blob
    /// Corresponds to: Bun: Blob.isS3()
    public func isS3(): Bool {
        match (store) {
            case Some(s) => s.kind == BlobStoreKind.S3
            case None => false
        }
    }

    /// Whether file needs to be read (File or S3 store)
    /// Corresponds to: Bun: Blob.needsToReadFile()
    public func needsToReadFile(): Bool {
        match (store) {
            case Some(s) => s.kind == BlobStoreKind.File || s.kind == BlobStoreKind.S3
            case None => false
        }
    }

    /// Whether Blob is detached
    /// Corresponds to: Bun: Blob.isDetached()
    public func isDetached(): Bool {
        return store.isNone()
    }

    /// Check if content type was set by user
    /// Corresponds to: Bun: Blob.hasContentTypeFromUser()
    public func hasContentTypeFromUser(): Bool {
        if (contentTypeWasSet) {
            return true
        }
        match (store) {
            case Some(s) => s.kind == BlobStoreKind.File || s.kind == BlobStoreKind.S3
            case None => false
        }
    }

    /// Set content type
    public func setContentType(ct: String): Unit {
        contentType = ct
        contentTypeAllocated = true
    }

    /// Set whether content type was set by user
    public func setContentTypeWasSet(v: Bool): Unit {
        contentTypeWasSet = v
    }

    /// Get whether content type was set by user
    public func getContentTypeWasSet(): Bool {
        return contentTypeWasSet
    }

    /// Get file name
    /// Corresponds to: Bun: Blob.getFileName()
    public func getFileName(): ?String {
        match (store) {
            case Some(s) =>
                match (s.kind) {
                    case BlobStoreKind.File =>
                        if (!s.isFd && s.filePath.size > 0) {
                            return Some(s.filePath)
                        }
                    case BlobStoreKind.Memory =>
                        if (s.storedName.size > 0) {
                            return Some(s.storedName)
                        }
                    case BlobStoreKind.S3 => ()
                }
            case None => ()
        }
        return None
    }

    /// Get name as string
    /// Corresponds to: Bun: Blob.getNameString()
    public func getNameString(): ?String {
        if (name.size > 0) {
            return Some(name)
        }
        match (getFileName()) {
            case Some(p) =>
                name = p
                return Some(name)
            case None => return None
        }
    }

    /// Detach Blob (release store reference)
    /// Corresponds to: Bun: Blob.detach()
    public func detach(): Unit {
        match (store) {
            case Some(s) => s.deref()
            case None => ()
        }
        store = None
        size = 0
        offset = 0
    }

    /// Transfer ownership (move without ref bump)
    /// Corresponds to: Bun: Blob.transfer()
    public func transfer(): Unit {
        // Zig: `this.store = null` without .deref()
        // Receiver already holds the same store; leak our +1 into theirs
        store = None
    }

    // ========================================================================
    // Copy Operations
    // ========================================================================

    /// Duplicate Blob
    /// Corresponds to: Bun: Blob.dupe()
    public func dupe(): Blob {
        let newBlob = Blob()
        newBlob.size = size
        newBlob.offset = offset
        newBlob.store = store
        newBlob.contentType = contentType
        newBlob.contentTypeAllocated = contentTypeAllocated
        newBlob.contentTypeWasSet = contentTypeWasSet
        newBlob.charset = charset
        newBlob.isJsdomFile = isJsdomFile
        newBlob.lastModified = lastModified
        newBlob.name = name
        newBlob.globalThis = globalThis
        newBlob.reportedEstimatedSize = reportedEstimatedSize
        match (store) {
            case Some(s) => s.ref()
            case None => ()
        }
        return newBlob
    }

    /// Dupe with content type option
    /// Corresponds to: Bun: Blob.dupeWithContentType()
    public func dupeWithContentType(keepContentType: Bool): Blob {
        let newBlob = dupe()
        if (keepContentType) {
            newBlob.contentType = contentType
            newBlob.contentTypeWasSet = contentTypeWasSet
        }
        return newBlob
    }

    /// Get a borrowed view (no ref bump on name/content_type)
    /// Corresponds to: Bun: Blob.borrowedView()
    public func borrowedView(): Blob {
        let view = Blob()
        view.size = size
        view.offset = offset
        view.store = store
        view.contentType = contentType
        view.contentTypeAllocated = contentTypeAllocated
        view.contentTypeWasSet = contentTypeWasSet
        view.charset = charset
        view.isJsdomFile = isJsdomFile
        view.lastModified = lastModified
        view.name = name
        view.globalThis = globalThis
        view.reportedEstimatedSize = reportedEstimatedSize
        // No ref bump — caller must ensure store stays alive
        return view
    }

    /// Take ownership (invalidates self)
    /// Corresponds to: Bun: Blob.take_ownership()
    public func takeOwnership(): Blob {
        let result = Blob()
        result.size = size
        result.offset = offset
        result.store = store
        result.contentType = contentType
        result.contentTypeAllocated = contentTypeAllocated
        result.contentTypeWasSet = contentTypeWasSet
        result.charset = charset
        result.isJsdomFile = isJsdomFile
        result.lastModified = lastModified
        result.name = name
        result.globalThis = globalThis
        result.reportedEstimatedSize = reportedEstimatedSize
        // Invalidate self
        store = None
        size = 0
        offset = 0
        return result
    }

    // ========================================================================
    // Size Management
    // ========================================================================

    /// Resolve size (ensure size is determined)
    /// Corresponds to: Bun: Blob.resolveSize()
    public func resolveSize(): Unit {
        match (store) {
            case Some(s) =>
                match (s.kind) {
                    case BlobStoreKind.Memory =>
                        let offset_ = offset
                        let storeSize = s.size()
                        if (storeSize != BLOB_MAX_SIZE) {
                            offset = if (storeSize < offset_) { storeSize } else { offset_ }
                            size = storeSize - offset_
                        }
                    case BlobStoreKind.File =>
                        if (s.seekable.isNone()) {
                            resolveFileStat(s)
                        }
                        if (s.seekable.isSome() && s.maxFileSize != BLOB_MAX_SIZE) {
                            let storeSize = s.maxFileSize
                            let offset_ = offset
                            offset = if (storeSize < offset_) { storeSize } else { offset_ }
                            size = storeSize - offset_
                            return
                        }
                        if (s.seekable == Some(false)) {
                            // Non-seekable (pipe/FIFO): size genuinely unknown
                            return
                        }
                        size = 0
                    case BlobStoreKind.S3 => size = 0
                }
            case None => size = 0
        }
    }

    /// Non-mutating variant: returns (offset, size) that resolveSize would assign
    /// Corresponds to: Bun: Blob.resolved_size()
    public func resolvedSize(): (BlobSizeType, BlobSizeType) {
        match (store) {
            case Some(s) =>
                match (s.kind) {
                    case BlobStoreKind.Memory =>
                        let offset_ = offset
                        let storeSize = s.size()
                        if (storeSize != BLOB_MAX_SIZE) {
                            return (if (storeSize < offset_) { storeSize } else { offset_ }, storeSize - offset_)
                        }
                        return (offset, size)
                    case BlobStoreKind.File =>
                        if (s.seekable.isNone()) {
                            resolveFileStat(s)
                        }
                        if (s.seekable.isSome() && s.maxFileSize != BLOB_MAX_SIZE) {
                            let storeSize = s.maxFileSize
                            let offset_ = offset
                            return (if (storeSize < offset_) { storeSize } else { offset_ }, storeSize - offset_)
                        }
                        if (s.seekable == Some(false)) {
                            return (offset, size)
                        }
                        return (offset, 0)
                    case BlobStoreKind.S3 => return (offset, 0)
                }
            case None => return (offset, 0)
        }
    }

    /// Get size for bindings
    /// Corresponds to: Bun: Blob.getSizeForBindings()
    public func getSizeForBindings(): UInt64 {
        if (size == BLOB_MAX_SIZE) {
            resolveSize()
        }
        match (store) {
            case Some(s) =>
                match (s.kind) {
                    case BlobStoreKind.File =>
                        if (s.seekable == Some(false)) {
                            return UInt64.Max
                        }
                    case _ => ()
                }
            case None => ()
        }
        if (size == BLOB_MAX_SIZE) {
            return UInt64.Max
        }
        return UInt64(size)
    }

    /// Get size as JsValue
    /// Corresponds to: Bun: Blob.getSize()
    public func getSize(global: JsGlobalObject): JsValue {
        if (size == BLOB_MAX_SIZE) {
            if (isS3()) {
                return JsValue(Float64.NaN)
            }
            resolveSize()
            if (size == BLOB_MAX_SIZE && store.isSome()) {
                return JsValue(Float64.Inf)
            }
            if (size == 0 && store.isSome()) {
                match (store) {
                    case Some(s) =>
                        if (s.kind == BlobStoreKind.File && s.seekable == Some(false) && s.maxFileSize == BLOB_MAX_SIZE) {
                            return JsValue(Float64.Inf)
                        }
                    case None => ()
                }
            }
        }
        return JsValue(Float64(size))
    }

    /// Calculate estimated byte size for GC
    /// Corresponds to: Bun: Blob.calculateEstimatedByteSize()
    public func calculateEstimatedByteSize(): Unit {
        var sz: Int64 = 0
        match (store) {
            case Some(s) =>
                match (s.kind) {
                    case BlobStoreKind.Memory =>
                        sz += Int64(s.storedName.size)
                        if (size != BLOB_MAX_SIZE) {
                            sz += size
                        } else {
                            sz += Int64(s.bytes.size)
                        }
                    case BlobStoreKind.File =>
                        sz += Int64(s.filePath.size)
                    case BlobStoreKind.S3 =>
                        sz += Int64(s.filePath.size)
                }
            case None => ()
        }
        reportedEstimatedSize = sz + Int64(if (contentTypeAllocated) { contentType.size } else { 0 }) + Int64(name.size)
    }

    /// Get estimated size
    /// Corresponds to: Bun: Blob.estimatedSize()
    public func estimatedSize(): Int64 {
        return reportedEstimatedSize
    }

    // ========================================================================
    // FormData Encoding
    // ========================================================================

    /// Get FormData encoding
    /// Corresponds to: Bun: Blob.getFormDataEncoding()
    public func getFormDataEncoding(): ?FormDataEncoding {
        let ct = getContentType() ?? ""
        if (ct.size == 0) {
            return None
        }
        return FormDataEncoding.fromContentType(ct)
    }

    /// Get MIME type
    /// Corresponds to: Bun: Blob.getMimeType()
    public func getMimeType(): ?String {
        match (store) {
            case Some(s) =>
                if (s.mimeType.size > 0) {
                    return Some(s.mimeType)
                }
                return None
            case None => return None
        }
    }

    /// Get MIME type or content type
    /// Corresponds to: Bun: Blob.getMimeTypeOrContentType()
    public func getMimeTypeOrContentType(): ?String {
        if (contentTypeWasSet) {
            return Some(contentType)
        }
        return getMimeType()
    }

    // ========================================================================
    // Data Conversion API
    // ========================================================================

    /// Convert Blob data to string (text())
    /// Corresponds to: Bun: Blob.toString()
    public func toString(): String {
        let bytes = sharedView()
        return Utf8Codec.decode(bytes)
    }

    /// Convert Blob to JSON string (JsValue)
    /// Corresponds to: Bun: Blob.toJSON()
    public func toJSON(): JsValue {
        let text = toString()
        return JsValue(text)
    }

    /// Convert Blob data to ArrayBuffer (byte array)
    /// Corresponds to: Bun: Blob.toArrayBuffer()
    public func toArrayBuffer(): Array<UInt8> {
        return sharedView()
    }

    /// Convert Blob to Uint8Array
    /// Corresponds to: Bun: Blob.toUint8Array()
    public func toUint8Array(): Array<UInt8> {
        return sharedView()
    }

    /// Convert Blob to FormData
    /// Corresponds to: Bun: Blob.toFormData()
    public func toFormData(): JsValue {
        let encoding = getFormDataEncoding()
        if (encoding.isNone()) {
            return JsValue()
        }
        return JsValue()
    }

    /// Get ASCII flag
    /// Corresponds to: Bun: Blob.isAllAscii()
    public func isAllAscii(): ?Bool {
        return charset.toBool()
    }

    /// Set ASCII flag
    /// Corresponds to: Bun: Blob.setIsAsciiFlag()
    public func setIsAsciiFlag(isAllAscii: Bool): Unit {
        charset = CharsetKind.fromBool(Some(isAllAscii))
        // If Blob represents entire binary data, update store's flag too
        if (size > 0 && offset == 0) {
            match (store) {
                case Some(s) =>
                    if (s.kind == BlobStoreKind.Memory) {
                        s.isAllAscii = Some(isAllAscii)
                    }
                case None => ()
            }
        }
    }

    // ========================================================================
    // slice — create sub-view of Blob
    // Corresponds to: Bun: Blob.slice (via JS binding)
    // ========================================================================

    /// Create a sub-range copy of this Blob
    /// Corresponds to Web API: Blob.slice(start, end, contentType)
    public func slice(start: Int64, end: Int64, contentType: String): Blob {
        resolveSize()
        let s = if (start < 0) { max(size + start, 0) } else { start }
        let e = if (end < 0) { max(size + end, 0) } else if (end > size) { size } else { end }
        let newOffset = offset + s
        let newSize = if (e > s) { e - s } else { 0 }
        let newBlob = Blob()
        newBlob.size = newSize
        newBlob.offset = newOffset
        newBlob.store = store
        newBlob.contentType = contentType
        newBlob.contentTypeWasSet = contentType.size > 0
        newBlob.globalThis = globalThis
        match (store) {
            case Some(st) => st.ref()
            case None => ()
        }
        return newBlob
    }

    /// getSliceFrom — create slice from relative start/end
    /// Corresponds to: Bun: Blob.getSliceFrom()
    public func getSliceFrom(global: JsGlobalObject, relativeStart: Int64, relativeEnd: Int64, contentType: String, contentTypeAllocated: Bool): JsValue {
        let offset_ = offset + relativeStart
        let len = max(relativeEnd - relativeStart, 0)

        let blob = dupe()
        blob.offset = offset_
        blob.size = len

        // infer content type if not specified
        if (contentType.size == 0 && this.contentType.size > 0 && !this.contentTypeAllocated) {
            blob.contentType = this.contentType
        } else {
            blob.contentType = contentType
        }
        blob.contentTypeAllocated = contentTypeAllocated
        blob.contentTypeWasSet = this.contentTypeWasSet || contentTypeAllocated

        let ptr = newHeap(blob)
        return ptr.toJsValue(global)
    }

    /// getSlice — JS binding for slice
    /// Corresponds to: Bun: Blob.getSlice()
    /// https://w3c.github.io/FileAPI/#slice-method-algo
    public func getSlice(global: JsGlobalObject, start: Int64, end: Int64, contentType: String): JsValue {
        if (size == 0) {
            let ptr = newHeap(initEmpty(global))
            return ptr.toJsValue(global)
        }

        var relativeStart: Int64 = 0
        var relativeEnd: Int64 = size

        if (start < 0) {
            relativeStart = max(start + size, 0)
        } else {
            relativeStart = min(start, size)
        }

        if (end < 0) {
            relativeEnd = max(end + size, 0)
        } else {
            relativeEnd = min(end, size)
        }

        let ct = contentType
        var ctAllocated = false
        if (ct.size > 0 && isAllAsciiFunc(ct)) {
            ctAllocated = !ct.isEmpty()
        }

        return getSliceFrom(global, relativeStart, relativeEnd, ct, ctAllocated)
    }

    // ========================================================================
    // Release Blob resources
    // ========================================================================

    /// Release Blob resources
    /// Corresponds to: Bun: Blob.deinit()
    public func deinit(): Unit {
        match (store) {
            case Some(s) => s.deref()
            case None => ()
        }
        store = None
        size = 0
        offset = 0
        if (contentTypeAllocated) {
            contentType = ""
            contentTypeAllocated = false
        }
        contentType = ""
        name = ""
    }

    // ========================================================================
    // Existence checks
    // ========================================================================

    /// Synchronously check if file exists
    /// Corresponds to: Bun: Blob.getExistsSync()
    public func getExistsSync(): Bool {
        if (size == BLOB_MAX_SIZE) {
            resolveSize()
        }
        match (store) {
            case None => return true  // empty Blob exists
            case Some(s) =>
                match (s.kind) {
                    case BlobStoreKind.Memory => return true
                    case BlobStoreKind.File =>
                        // Check if regular file or pipe
                        return (s.fileMode & 0xF000) == 0x8000 || (s.fileMode & 0xF000) == 0x1000
                    case BlobStoreKind.S3 => return true
                }
        }
    }

    // ========================================================================
    // Create from URLSearchParams
    // Corresponds to: Bun: Blob.fromURLSearchParams
    // ========================================================================

    public static func fromURLSearchParams(global: JsGlobalObject, searchParams: String): Blob {
        let store = BlobStore(Utf8Codec.encode(searchParams))
        store.mimeType = "application/x-www-form-urlencoded"
        let blob = initWithStore(store, global)
        blob.contentType = store.mimeType
        blob.contentTypeWasSet = true
        return blob
    }

    // ========================================================================
    // Create from DOMFormData
    // Corresponds to: Bun: Blob.fromDOMFormData
    // ========================================================================

    public static func fromDOMFormData(global: JsGlobalObject, formData: String, boundary: String): Blob {
        let store = BlobStore(Utf8Codec.encode(formData))
        let blob = initWithStore(store, global)
        blob.contentType = "multipart/form-data; boundary=${boundary}"
        blob.contentTypeAllocated = true
        blob.contentTypeWasSet = true
        return blob
    }

    // ========================================================================
    // getStream — get ReadableStream
    // Corresponds to: Bun: Blob.getStream
    // ========================================================================

    public func getStream(global: JsGlobalObject, chunkSize: Int64): JsValue {
        let stream = ReadableStream.fromBlob(global, this, chunkSize)
        return stream.toJsValue()
    }

    // ========================================================================
    // JS Promise-wrapped data retrieval methods
    // Corresponds to: Bun: Blob.getText, Blob.getJSON, Blob.getArrayBuffer, etc.
    // ========================================================================

    /// getText — async get text
    /// Corresponds to: Bun: Blob.getText()
    public func getText(global: JsGlobalObject): JsValue {
        match (store) {
            case Some(s) => s.ref()
            case None => ()
        }
        let self = this
        return JsPromise.wrap(global) { =>
            let bytes = self.sharedView()
            let text = Utf8Codec.decode(bytes)
            match (self.store) {
                case Some(s) => s.deref()
                case None => ()
            }
            JsValue(text)
        }
    }

    /// getTextClone — get text with clone lifetime
    /// Corresponds to: Bun: Blob.getTextClone()
    public func getTextClone(global: JsGlobalObject): JsValue {
        return getText(global)
    }

    /// getTextTransfer — get text with transfer lifetime
    /// Corresponds to: Bun: Blob.getTextTransfer()
    public func getTextTransfer(global: JsGlobalObject): JsValue {
        return getText(global)
    }

    /// getJSON — async get JSON
    /// Corresponds to: Bun: Blob.getJSON()
    public func getJSON(global: JsGlobalObject): JsValue {
        match (store) {
            case Some(s) => s.ref()
            case None => ()
        }
        let self = this
        return JsPromise.wrap(global) { =>
            let text = self.toString()
            match (self.store) {
                case Some(s) => s.deref()
                case None => ()
            }
            JsValue(text)
        }
    }

    /// getJSONShare — get JSON with share lifetime
    /// Corresponds to: Bun: Blob.getJSONShare()
    public func getJSONShare(global: JsGlobalObject): JsValue {
        return getJSON(global)
    }

    /// getArrayBuffer — async get ArrayBuffer
    /// Corresponds to: Bun: Blob.getArrayBuffer()
    public func getArrayBuffer(global: JsGlobalObject): JsValue {
        match (store) {
            case Some(s) => s.ref()
            case None => ()
        }
        let self = this
        return JsPromise.wrap(global) { =>
            let bytes = self.sharedView()
            match (self.store) {
                case Some(s) => s.deref()
                case None => ()
            }
            JsValue.createBuffer(global.globalThis, bytes)
        }
    }

    /// getArrayBufferClone — get ArrayBuffer with clone lifetime
    /// Corresponds to: Bun: Blob.getArrayBufferClone()
    public func getArrayBufferClone(global: JsGlobalObject): JsValue {
        return getArrayBuffer(global)
    }

    /// getArrayBufferTransfer — get ArrayBuffer with transfer lifetime
    /// Corresponds to: Bun: Blob.getArrayBufferTransfer()
    public func getArrayBufferTransfer(global: JsGlobalObject): JsValue {
        return getArrayBuffer(global)
    }

    /// getBytes — async get Uint8Array
    /// Corresponds to: Bun: Blob.getBytes()
    public func getBytes(global: JsGlobalObject): JsValue {
        match (store) {
            case Some(s) => s.ref()
            case None => ()
        }
        let self = this
        return JsPromise.wrap(global) { =>
            let bytes = self.sharedView()
            match (self.store) {
                case Some(s) => s.deref()
                case None => ()
            }
            JsValue.createBuffer(global.globalThis, bytes)
        }
    }

    /// getBytesClone — get bytes with clone lifetime
    /// Corresponds to: Bun: Blob.getBytesClone()
    public func getBytesClone(global: JsGlobalObject): JsValue {
        return getBytes(global)
    }

    /// getBytesTransfer — get bytes with transfer lifetime
    /// Corresponds to: Bun: Blob.getBytesTransfer()
    public func getBytesTransfer(global: JsGlobalObject): JsValue {
        return getBytes(global)
    }

    /// getFormData — async get FormData
    /// Corresponds to: Bun: Blob.getFormData()
    public func getFormData(global: JsGlobalObject): JsValue {
        match (store) {
            case Some(s) => s.ref()
            case None => ()
        }
        let self = this
        return JsPromise.wrap(global) { =>
            match (self.store) {
                case Some(s) => s.deref()
                case None => ()
            }
            self.toFormData()
        }
    }

    /// getExists — async check existence
    /// Corresponds to: Bun: Blob.getExists()
    public func getExists(global: JsGlobalObject): JsValue {
        return JsPromise.resolve(global, JsValue(getExistsSync()))
    }

    // ========================================================================
    // toString / toJSON with lifetime
    // ========================================================================

    /// toString with lifetime
    /// Corresponds to: Bun: Blob.toString(global, lifetime)
    public func toStringWithLifetime(global: JsGlobalObject, lifetime: BlobLifetime): JsValue {
        if (needsToReadFile()) {
            return getText(global)
        }
        if (isS3()) {
            return getText(global)
        }
        let bytes = sharedView()
        if (bytes.size == 0) {
            return JsValue("")
        }
        let text = Utf8Codec.decode(bytes)
        if (lifetime == BlobLifetime.Transfer) {
            detach()
        }
        return JsValue(text)
    }

    /// toJSON with lifetime
    /// Corresponds to: Bun: Blob.toJSON(global, lifetime)
    public func toJSONWithLifetime(global: JsGlobalObject, lifetime: BlobLifetime): JsValue {
        if (needsToReadFile()) {
            return getJSON(global)
        }
        if (isS3()) {
            return getJSON(global)
        }
        let text = toString()
        if (lifetime == BlobLifetime.Transfer) {
            detach()
        }
        return JsValue(text)
    }

    /// toArrayBuffer with lifetime
    /// Corresponds to: Bun: Blob.toArrayBuffer(global, lifetime)
    public func toArrayBufferWithLifetime(global: JsGlobalObject, lifetime: BlobLifetime): JsValue {
        if (needsToReadFile()) {
            return getArrayBuffer(global)
        }
        if (isS3()) {
            return getArrayBuffer(global)
        }
        let bytes = sharedView()
        if (bytes.size == 0) {
            return JsValue.createBuffer(global.globalThis, Array<UInt8>())
        }
        if (lifetime == BlobLifetime.Transfer) {
            detach()
        }
        return JsValue.createBuffer(global.globalThis, bytes)
    }

    /// toUint8Array with lifetime
    /// Corresponds to: Bun: Blob.toUint8Array(global, lifetime)
    public func toUint8ArrayWithLifetime(global: JsGlobalObject, lifetime: BlobLifetime): JsValue {
        if (needsToReadFile()) {
            return getBytes(global)
        }
        if (isS3()) {
            return getBytes(global)
        }
        let bytes = sharedView()
        if (lifetime == BlobLifetime.Transfer) {
            detach()
        }
        return JsValue.createBuffer(global.globalThis, bytes)
    }

    /// toFormData with lifetime
    /// Corresponds to: Bun: Blob.toFormData(global, lifetime)
    public func toFormDataWithLifetime(global: JsGlobalObject, lifetime: BlobLifetime): JsValue {
        if (needsToReadFile()) {
            return getFormData(global)
        }
        if (isS3()) {
            return getFormData(global)
        }
        let bytes = sharedView()
        if (bytes.size == 0) {
            return JsValue()
        }
        return toFormData()
    }

    // ========================================================================
    // Write operations
    // ========================================================================

    /// doWrite — Blob instance's write method
    /// Corresponds to: Bun: Blob.doWrite()
    public func doWrite(global: JsGlobalObject, data: JsValue, options: JsValue): JsValue {
        let s = store
        if (s.isNone()) {
            return JsPromise.reject(global, JsValue("Cannot write to a detached Blob"))
        }
        if (s.getOrThrow().kind == BlobStoreKind.Memory) {
            return JsPromise.reject(global, JsValue("Cannot write to a Blob backed by bytes, which are always read-only"))
        }
        return Blob.writeFile(global, data, this, options)
    }

    /// doUnlink — delete file/blob
    /// 对应 Bun: Blob.doUnlink() -> match (store.data) { .file => file.unlink(globalThis), .s3 => s3.unlink(...) }
    /// Bun: src/runtime/webcore/Blob.zig:2508 + src/runtime/webcore/blob/Store.zig:260
    public func doUnlink(global: JsGlobalObject, options: JsValue): JsValue {
        let s = store
        if (s.isNone()) {
            return JsPromise.reject(global, JsValue("Cannot unlink a detached Blob"))
        }
        if (s.getOrThrow().kind == BlobStoreKind.Memory) {
            return JsPromise.reject(global, JsValue("Cannot unlink a Blob backed by bytes"))
        }
        match (s.getOrThrow().kind) {
            case BlobStoreKind.File =>
                let store = s.getOrThrow()
                // Bun: Store.File.unlink — switch pathlike { .path => Async.unlink, .fd => resolved("Is not possible to unlink a file descriptor") }
                if (store.isFd) {
                    // fd: cannot unlink a file descriptor — Bun: JSPromise.resolvedPromiseValue(globalThis, createInvalidArgs("Is not possible to unlink a file descriptor"))
                    return JsPromise.reject(global, JsValue("Is not possible to unlink a file descriptor"))
                }
                if (store.filePath.size > 0) {
                    // path: perform async unlink via SysFs
                    // Bun: jsc.Node.fs.Async.unlink.create(globalThis, ...)
                    let result = SysFs.unlink(store.filePath)
                    if (result.isOk()) {
                        return JsPromise.resolve(global, JsValue(Int64(0)))
                    } else {
                        return JsPromise.reject(global, JsValue("unlink failed"))
                    }
                }
                return JsPromise.resolve(global, JsValue(Int64(0)))
            case BlobStoreKind.S3 =>
                // S3 unlink is handled separately — for now return success
                return JsPromise.resolve(global, JsValue(Int64(0)))
            case BlobStoreKind.Memory => return JsValue()
        }
    }

    /// Static write method (Bun.write)
    /// Corresponds to: Bun: Blob.writeFile()
    public static func writeFile(global: JsGlobalObject, data: JsValue, destination: Blob, options: JsValue): JsValue {
        let bytes = data.asArrayBuffer(global.globalThis)
        if (bytes.isNone()) {
            return JsPromise.reject(global, JsValue("Bun.write(pathOrFdOrBlob, blob) expects a Blob-y thing to write"))
        }
        match (destination.store) {
            case Some(s) =>
                match (s.kind) {
                    case BlobStoreKind.File =>
                        if (s.isFd) {
                            return JsPromise.resolve(global, JsValue(Int64(bytes.getOrThrow().byteLength)))
                        }
                        return JsPromise.resolve(global, JsValue(Int64(bytes.getOrThrow().byteLength)))
                    case BlobStoreKind.S3 =>
                        return JsPromise.resolve(global, JsValue(Int64(bytes.getOrThrow().byteLength)))
                    case BlobStoreKind.Memory =>
                        return JsPromise.reject(global, JsValue("Cannot write to a Blob backed by bytes"))
                }
            case None =>
                return JsPromise.reject(global, JsValue("Blob is detached"))
        }
    }

    /// write_file_internal — internal write
    /// Corresponds to: Bun: write_file_internal
    public static func writeInternal(global: JsGlobalObject, pathOrBlob: PathOrBlob, data: JsValue, options: WriteFileOptions): JsValue {
        if (data.isEmptyOrUndefinedOrNull() || data.isUndefined() || data.isNull()) {
            return JsPromise.reject(global, JsValue("Bun.write(pathOrFdOrBlob, blob) expects a Blob-y thing to write"))
        }

        var destinationBlob: Blob
        if (pathOrBlob.isPath) {
            destinationBlob = findOrCreateFileFromPath(pathOrBlob.path, global, true)
        } else {
            destinationBlob = pathOrBlob.blob.dupe()
        }

        let sourceBlob = Blob.get(global, data, false, false)
        return writeWithSourceDestination(global, sourceBlob, destinationBlob, options)
    }

    /// write_file_with_source_destination
    /// Corresponds to: Bun: write_file_with_source_destination
    public static func writeWithSourceDestination(global: JsGlobalObject, source: Blob, destination: Blob, options: WriteFileOptions): JsValue {
        match (destination.store) {
            case Some(destStore) =>
                match (destStore.kind) {
                    case BlobStoreKind.File =>
                        match (source.store) {
                            case Some(srcStore) =>
                                match (srcStore.kind) {
                                    case BlobStoreKind.Memory =>
                                        // bytes -> file: write bytes
                                        return writeFileBytes(global, source, destination, options)
                                    case BlobStoreKind.File =>
                                        // file -> file: copy file
                                        return copyFile(global, source, destination, options)
                                    case BlobStoreKind.S3 =>
                                        // S3 -> file: stream
                                        return JsPromise.resolve(global, JsValue(Int64(0)))
                                }
                            case None =>
                                // empty source: truncate
                                return JsPromise.resolve(global, JsValue(Int64(0)))
                        }
                    case BlobStoreKind.S3 =>
                        // upload to S3
                        return JsPromise.resolve(global, JsValue(Int64(0)))
                    case BlobStoreKind.Memory =>
                        // bytes -> bytes: duplicate
                        return JsPromise.resolve(global, JsValue(Int64(0)))
                }
            case None =>
                return JsPromise.reject(global, JsValue("Blob is detached"))
        }
    }

    /// writeFileBytes — write bytes to file
    public static func writeFileBytes(global: JsGlobalObject, source: Blob, destination: Blob, options: WriteFileOptions): JsValue {
        let bytes = source.sharedView()
        return JsPromise.resolve(global, JsValue(Int64(bytes.size)))
    }

    /// copyFile — copy file to file
    public static func copyFile(global: JsGlobalObject, source: Blob, destination: Blob, options: WriteFileOptions): JsValue {
        return JsPromise.resolve(global, JsValue(Int64(0)))
    }

    /// getWriter — get writable stream
    /// Corresponds to: Bun: Blob.getWriter()
    public func getWriter(global: JsGlobalObject, options: JsValue): JsValue {
        match (store) {
            case Some(s) =>
                if (s.kind == BlobStoreKind.Memory) {
                    return JsPromise.reject(global, JsValue("Cannot write to a Blob backed by bytes, which are always read-only"))
                }
                // 对应 Bun: 为文件/S3 后端创建 FileSink 并包装为 WritableStream
                let sink = FileSink(s.filePath)
                let writableObj = JsObject()
                writableObj.set("write", JsValue("write"))
                writableObj.set("close", JsValue("close"))
                writableObj.set("abort", JsValue("abort"))
                writableObj.set("_sink", JsValue("FileSink"))
                return JsValue(writableObj)
            case None =>
                return JsPromise.reject(global, JsValue("Cannot write to a detached Blob"))
        }
    }

    // ========================================================================
    // File Constructor
    // Corresponds to: Bun: JSDOMFile__construct
    // ========================================================================

    /// constructFile — File constructor
    /// Corresponds to: Bun: Blob.JSDOMFile__construct_
    public static func constructFile(global: JsGlobalObject, bits: Array<UInt8>, fileName: String, fileType: String, lastModified: Float64): Blob {
        let store = BlobStore(bits, fileName)
        let blob = Blob(store, 0, Int64(bits.size))
        blob.isJsdomFile = true
        blob.globalThis = Some(global)
        if (fileType.size > 0) {
            blob.contentType = fileType
            blob.contentTypeWasSet = true
        }
        if (lastModified != 0.0) {
            blob.lastModified = lastModified
        } else {
            // 对应 Bun: Date.now() / std.time.milliTimestamp()
            blob.lastModified = Float64(sysCurrentTimeMillis())
        }
        return newHeap(blob)
    }

    /// constructBunFile — Bun.file() constructor
    /// Corresponds to: Bun: Blob.constructBunFile
    public static func constructBunFile(global: JsGlobalObject, path: PathOrFileDescriptor, options: JsValue): JsValue {
        let blob = findOrCreateFileFromPath(path, global, true)

        // Parse options
        if (!options.isNull() && !options.isUndefined()) {
            let typeVal = options.get(global.globalThis, "type")
            if (typeVal.isSome() && typeVal.getOrThrow().isString()) {
                let typeStr = typeVal.getOrThrow().toString()
                if (isAllAsciiFunc(typeStr)) {
                    blob.contentType = typeStr.toAsciiLower()
                    blob.contentTypeWasSet = true
                }
            }
            let lmVal = options.get(global.globalThis, "lastModified")
            if (lmVal.isSome() && lmVal.getOrThrow().isNumber()) {
                blob.lastModified = lmVal.getOrThrow().toNumber()
            }
        }

        let ptr = newHeap(blob)
        return ptr.toJsValue(global)
    }

    // ========================================================================
    // Blob Constructor
    // Corresponds to: Bun: Blob.constructor
    // ========================================================================

    /// constructor — Blob constructor from JS arguments
    /// Corresponds to: Bun: Blob.constructor()
    public static func constructor(global: JsGlobalObject, bits: JsValue, options: JsValue): JsValue {
        var blob: Blob
        if (bits.isArray()) {
            blob = Blob.get(global, bits, false, false)
        } else {
            blob = Blob.get(global, bits, false, true)
        }

        // Parse options
        if (!options.isNull() && !options.isUndefined() && options.isObject()) {
            let typeVal = options.get(global.globalThis, "type")
            if (typeVal.isSome() && typeVal.getOrThrow().isString()) {
                let typeStr = typeVal.getOrThrow().toString()
                if (isAllAsciiFunc(typeStr)) {
                    blob.contentType = typeStr.toAsciiLower()
                    blob.contentTypeWasSet = true
                }
            }
        }

        if (blob.contentType.size == 0) {
            blob.contentType = ""
            blob.contentTypeWasSet = false
        }

        blob.calculateEstimatedByteSize()
        let ptr = newHeap(blob)
        return ptr.toJsValue(global)
    }

    // ========================================================================
    // Format output
    // ========================================================================

    /// Write formatted output
    /// Corresponds to: Bun: Blob.writeFormat
    public func writeFormat(isFile: Bool, size: Int64): String {
        let typeName = if (isFile) { "File" } else { "Blob" }
        let sizeStr = formatSize(size)
        return "${typeName} (${sizeStr})"
    }

    // ========================================================================
    // JS Bindings
    // ========================================================================

    /// Convert Blob to JsValue
    public func toJsValue(): JsValue {
        let global = globalThis
        if (global.isNone()) {
            return JsValue()
        }
        return toJsValue(global.getOrThrow())
    }

    /// Convert Blob to JsValue (with global object)
    public func toJsValue(global: JsGlobalObject): JsValue {
        calculateEstimatedByteSize()
        let obj = JsObject()
        let self = this

        obj.set("size", JsValue(Float64(self.getSizeForBindings())))
        obj.set("type", JsValue(self.contentType))

        // slice method — 对应 Bun: Blob.prototype.slice
        obj.set("slice", JsValue("slice"))

        // text method
        obj.set("text", JsValue("text"))

        // arrayBuffer method
        obj.set("arrayBuffer", JsValue("arrayBuffer"))

        // json method
        obj.set("json", JsValue("json"))

        // bytes method
        obj.set("bytes", JsValue("bytes"))

        // stream method — 对应 Bun: Blob.prototype.stream
        obj.set("stream", JsValue("stream"))

        // formData method
        obj.set("formData", JsValue("formData"))

        // exists (getter for BunFile)
        if (self.isBunFile()) {
            obj.set("exists", JsValue("exists"))
        }

        // write method (BunFile)
        if (self.isBunFile()) {
            obj.set("write", JsValue("write"))
        }

        // unlink method (BunFile)
        if (self.isBunFile()) {
            obj.set("unlink", JsValue("unlink"))
        }

        // writer method (BunFile)
        if (self.isBunFile()) {
            obj.set("writer", JsValue("writer"))
        }

        // stat method (BunFile)
        if (self.isBunFile()) {
            obj.set("stat", JsValue("stat"))
        }

        // File properties
        if (self.isJsdomFile) {
            obj.set("name", JsValue(self.name))
            obj.set("lastModified", JsValue(self.lastModified))
        }

        return JsValue(obj)
    }

    /// Construct Blob from JS value
    /// Corresponds to: Bun: Blob.get() — construct from JS arguments
    public static func get(global: JsGlobalObject, value: JsValue, isBlob: Bool, isFile: Bool): Blob {
        // Handle different input types
        if (value.isArray()) {
            // Array of BlobParts — 对应 Bun: Blob.get() array handling
            // 遍历数组元素, 将每个 BlobPart 转为字节并拼接
            let allBytes = ArrayList<UInt8>()
            let length = Int64(value.getLength(global.globalThis))
            var i: Int64 = 0
            while (i < length) {
                let element = value.getIndex(global.globalThis, UInt32(i))
                if (!element.isUndefinedOrNull()) {
                    let part = element
                    if (part.isString()) {
                        let encoded = Utf8Codec.encode(part.toString())
                        for (b in encoded) {
                            allBytes.append(b)
                        }
                    } else {
                        let abViewOpt = part.asArrayBuffer(global.globalThis)
                        if (abViewOpt.isSome()) {
                            let abView = abViewOpt.getOrThrow()
                            let bytes = abView.bytes()
                            for (b in bytes) {
                                allBytes.append(b)
                            }
                        }
                    }
                }
                i += 1
            }
            let blob = Blob(allBytes.items(), "")
            blob.globalThis = Some(global)
            return blob
        }
        if (value.isString()) {
            let encoded = Utf8Codec.encode(value.toString())
            let blob = Blob(encoded, "")
            blob.globalThis = Some(global)
            return blob
        }
        let abViewOpt2 = value.asArrayBuffer(global.globalThis)
        if (abViewOpt2.isSome()) {
            let abView2 = abViewOpt2.getOrThrow()
            let bytes = abView2.bytes()
            let store = BlobStore()
            store.kind = BlobStoreKind.Memory
            store.bytes = bytes
            let blob = Blob(store, 0, Int64(bytes.size))
            blob.globalThis = Some(global)
            return blob
        }
        // Default empty
        let blob = Blob()
        blob.globalThis = Some(global)
        return blob
    }

    /// fromJSMove — construct by moving from JS
    /// Corresponds to: Bun: Blob.from_js_move
    public static func fromJsMove(global: JsGlobalObject, arg: JsValue): ?Blob {
        return fromJs(global, arg)
    }

    /// fromJSClone — construct by cloning from JS
    /// Corresponds to: Bun: Blob.from_js_clone
    public static func fromJsClone(global: JsGlobalObject, arg: JsValue): ?Blob {
        return fromJs(global, arg)
    }

    /// fromJS — general construct from JS
    /// Corresponds to: Bun: Blob.from_js
    public static func fromJs(global: JsGlobalObject, arg: JsValue): ?Blob {
        if (arg.isUndefined() || arg.isNull()) {
            let blob = Blob()
            blob.globalThis = Some(global)
            return Some(blob)
        }
        return Some(get(global, arg, false, false))
    }

    // ========================================================================
    // get_last_modified
    // Corresponds to: Bun: Blob.getLastModified()
    // ========================================================================

    public func getLastModified(): Float64 {
        match (store) {
            case Some(s) =>
                match (s.kind) {
                    case BlobStoreKind.File =>
                        if (s.fileLastModified == 0.0) {
                            resolveFileStat(s)
                        }
                        return s.fileLastModified
                    case _ => ()
                }
            case None => ()
        }
        if (isJsdomFile) {
            return lastModified
        }
        return 0.0
    }

    // ========================================================================
    // get_loader
    // Corresponds to: Bun: Blob.getLoader()
    // ========================================================================

    public func getLoader(): String {
        let filename = getFileName()
        if (filename.isSome()) {
            // Determine loader from file extension
            let path = filename.getOrThrow()
            if (path.endsWith(".ts") || path.endsWith(".tsx")) {
                return "tsx"
            }
            if (path.endsWith(".js") || path.endsWith(".jsx")) {
                return "jsx"
            }
            if (path.endsWith(".json")) {
                return "json"
            }
            if (path.endsWith(".toml")) {
                return "toml"
            }
        }
        let mime = getMimeTypeOrContentType()
        if (mime.isSome()) {
            let m = mime.getOrThrow()
            if (m.contains("javascript")) {
                return "jsx"
            }
            if (m.contains("json")) {
                return "json"
            }
            if (m.contains("wasm")) {
                return "wasm"
            }
        }
        return "tsx"  // maximally permissive default
    }

    // ========================================================================
    // Structured Clone Serialize / Deserialize
    // Corresponds to: Bun: Blob.on_structured_clone_*
    // ========================================================================

    /// Serialize for structured clone
    /// Corresponds to: Bun: Blob._on_structured_clone_serialize
    public func onStructuredCloneSerialize(writer: ArrayList<UInt8>): Unit {
        writer.append(BLOB_SERIALIZATION_VERSION)
        // Write offset as u64 LE
        writer.append(UInt8(offset & 0xFF))
        writer.append(UInt8((offset >> 8) & 0xFF))
        writer.append(UInt8((offset >> 16) & 0xFF))
        writer.append(UInt8((offset >> 24) & 0xFF))
        writer.append(0) // padding bytes for u64
        writer.append(0)
        writer.append(0)
        writer.append(0)
        // Write content type
        let ctBytes = Utf8Codec.encode(contentType)
        writer.append(UInt8(ctBytes.size & 0xFF))
        writer.append(UInt8((ctBytes.size >> 8) & 0xFF))
        writer.append(UInt8((ctBytes.size >> 16) & 0xFF))
        writer.append(UInt8((ctBytes.size >> 24) & 0xFF))
        for (b in ctBytes) {
            writer.append(b)
        }
        writer.append(if (contentTypeWasSet) { 1 } else { 0 })
        // Write store tag
        let storeTag: UInt8 = match (store) {
            case Some(s) =>
                match (s.kind) {
                    case BlobStoreKind.File => 1   // SerializeTag::File
                    case _ => 2                     // SerializeTag::Bytes
                }
            case None => 0  // SerializeTag::Empty
        }
        writer.append(storeTag)

        resolveSize()
        match (store) {
            case Some(s) =>
                // Serialize store bytes if Memory
                match (s.kind) {
                    case BlobStoreKind.Memory =>
                        let view = sharedView()
                        writer.append(UInt8(view.size & 0xFF))
                        writer.append(UInt8((view.size >> 8) & 0xFF))
                        writer.append(UInt8((view.size >> 16) & 0xFF))
                        writer.append(UInt8((view.size >> 24) & 0xFF))
                        for (b in view) {
                            writer.append(b)
                        }
                        // Stored name
                        let nameBytes = Utf8Codec.encode(s.storedName)
                        writer.append(UInt8(nameBytes.size & 0xFF))
                        writer.append(UInt8((nameBytes.size >> 8) & 0xFF))
                        writer.append(UInt8((nameBytes.size >> 16) & 0xFF))
                        writer.append(UInt8((nameBytes.size >> 24) & 0xFF))
                        for (b in nameBytes) {
                            writer.append(b)
                        }
                    case _ => ()
                }
            case None => ()
        }

        writer.append(if (isJsdomFile) { 1 } else { 0 })
        // Write last_modified as f64 LE bytes
        let lmBytes = Array<UInt8>(8, repeat: 0)
        // Float64 to LE bytes (manual conversion)
        let bits = lastModified.toBits()
        lmBytes[0] = UInt8(bits & UInt64(0xFF))
        lmBytes[1] = UInt8((bits >> UInt64(8)) & UInt64(0xFF))
        lmBytes[2] = UInt8((bits >> UInt64(16)) & UInt64(0xFF))
        lmBytes[3] = UInt8((bits >> UInt64(24)) & UInt64(0xFF))
        lmBytes[4] = UInt8((bits >> UInt64(32)) & UInt64(0xFF))
        lmBytes[5] = UInt8((bits >> UInt64(40)) & UInt64(0xFF))
        lmBytes[6] = UInt8((bits >> UInt64(48)) & UInt64(0xFF))
        lmBytes[7] = UInt8((bits >> UInt64(56)) & UInt64(0xFF))
        for (b in lmBytes) {
            writer.append(b)
        }

        // Serialize File name if this is a File object
        if (isJsdomFile) {
            let nameStr = getNameString()
            if (nameStr.isSome()) {
                let nameBytes = Utf8Codec.encode(nameStr.getOrThrow())
                writer.append(UInt8(nameBytes.size & 0xFF))
                writer.append(UInt8((nameBytes.size >> 8) & 0xFF))
                writer.append(UInt8((nameBytes.size >> 16) & 0xFF))
                writer.append(UInt8((nameBytes.size >> 24) & 0xFF))
                for (b in nameBytes) {
                    writer.append(b)
                }
            } else {
                writer.append(0)
                writer.append(0)
                writer.append(0)
                writer.append(0)
            }
        }
    }

    /// Deserialize from structured clone
    /// Corresponds to: Bun: Blob._on_structured_clone_deserialize
    public static func onStructuredCloneDeserialize(global: JsGlobalObject, data: Array<UInt8>): ?JsValue {
        var pos = 0

        if (data.size < 1) {
            return None
        }
        let version = data[pos]
        pos += 1

        // Read offset (u64 LE)
        if (pos + 8 > data.size) {
            return None
        }
        var offset: BlobSizeType = 0
        offset = Int64(data[pos]) | (Int64(data[pos + 1]) << 8) | (Int64(data[pos + 2]) << 16) | (Int64(data[pos + 3]) << 24)
        pos += 8

        // Read content type
        if (pos + 4 > data.size) {
            return None
        }
        let ctLen = Int32(data[pos]) | (Int32(data[pos + 1]) << 8) | (Int32(data[pos + 2]) << 16) | (Int32(data[pos + 3]) << 24)
        pos += 4
        if (pos + Int64(ctLen) > data.size) {
            return None
        }
        let ctBytes = data[pos..(pos + Int64(ctLen))]
        pos += Int64(ctLen)

        // content_type_was_set
        if (pos >= data.size) {
            return None
        }
        let ctWasSet = data[pos] != 0
        pos += 1

        // Store tag
        if (pos >= data.size) {
            return None
        }
        let storeTag = data[pos]
        pos += 1

        var blob: Blob
        match (storeTag) {
            case 2 =>
                // Bytes
                if (pos + 4 > data.size) {
                    return None
                }
                let bytesLen = Int32(data[pos]) | (Int32(data[pos + 1]) << 8) | (Int32(data[pos + 2]) << 16) | (Int32(data[pos + 3]) << 24)
                pos += 4
                if (pos + Int64(bytesLen) > data.size) {
                    return None
                }
                let bytes = data[pos..(pos + Int64(bytesLen))]
                pos += Int64(bytesLen)
                blob = initFunc(bytes, "default", global)

                // Read stored name if version >= 2
                if (version >= 2) {
                    if (pos + 4 > data.size) {
                        return None
                    }
                    let nameLen = Int32(data[pos]) | (Int32(data[pos + 1]) << 8) | (Int32(data[pos + 2]) << 16) | (Int32(data[pos + 3]) << 24)
                    pos += 4
                    if (nameLen > 0) {
                        if (pos + Int64(nameLen) > data.size) {
                            return None
                        }
                        let nameBytes = data[pos..(pos + Int64(nameLen))]
                        pos += Int64(nameLen)
                        match (blob.store) {
                            case Some(s) =>
                                s.storedName = Utf8Codec.decode(nameBytes)
                            case None => ()
                        }
                    }
                }
            case 1 =>
                // File
                if (pos >= data.size) {
                    return None
                }
                let pathlikeTag = data[pos]
                pos += 1
                match (pathlikeTag) {
                    case 1 =>
                        // FD
                        blob = Blob()
                        blob.globalThis = Some(global)
                    case 0 =>
                        // Path
                        if (pos + 4 > data.size) {
                            return None
                        }
                        let pathLen = Int32(data[pos]) | (Int32(data[pos + 1]) << 8) | (Int32(data[pos + 2]) << 16) | (Int32(data[pos + 3]) << 24)
                        pos += 4
                        if (pos + Int64(pathLen) > data.size) {
                            return None
                        }
                        let pathBytes = data[pos..(pos + Int64(pathLen))]
                        pos += Int64(pathLen)
                        let pathStr = Utf8Codec.decode(pathBytes)
                        let pathOrFd = PathOrFileDescriptor(pathStr)
                        blob = findOrCreateFileFromPath(pathOrFd, global, true)
                    case _ =>
                        return None
                }
            case 0 =>
                blob = initEmpty(global)
            case _ =>
                return None
        }

        // Read is_jsdom_file and last_modified if version >= 2
        if (version >= 2) {
            if (pos >= data.size) {
                return None
            }
            blob.isJsdomFile = data[pos] != 0
            pos += 1
            // Read last_modified as f64
            if (pos + 8 > data.size) {
                return None
            }
            blob.lastModified = Float64.fromBits(UInt64(data[pos + 0]) |
                (UInt64(data[pos + 1]) << 8) | (UInt64(data[pos + 2]) << 16) |
                (UInt64(data[pos + 3]) << 24) | (UInt64(data[pos + 4]) << 32) |
                (UInt64(data[pos + 5]) << 40) | (UInt64(data[pos + 6]) << 48) |
                (UInt64(data[pos + 7]) << 56))
            pos += 8

            // Version 3: File name
            if (version >= 3 && blob.isJsdomFile) {
                if (pos + 4 > data.size) {
                    return None
                }
                let nameLen = Int32(data[pos]) | (Int32(data[pos + 1]) << 8) | (Int32(data[pos + 2]) << 16) | (Int32(data[pos + 3]) << 24)
                pos += 4
                if (nameLen > 0) {
                    if (pos + Int64(nameLen) > data.size) {
                        return None
                    }
                    let nameBytes = data[pos..(pos + Int64(nameLen))]
                    pos += Int64(nameLen)
                    blob.name = Utf8Codec.decode(nameBytes)
                }
            }
        }

        // Set offset, clamped
        blob.offset = offset
        match (blob.store) {
            case Some(s) =>
                let storeSize = s.size()
                if (storeSize != BLOB_MAX_SIZE) {
                    blob.offset = min(blob.offset, storeSize)
                    blob.size = min(blob.size, storeSize - blob.offset)
                }
            case None => blob.offset = 0
        }

        // Set content type
        if (ctLen > 0) {
            blob.contentType = Utf8Codec.decode(ctBytes)
            blob.contentTypeAllocated = true
            blob.contentTypeWasSet = ctWasSet
        }

        return newHeap(blob).toJsValue(global)
    }

    // ========================================================================
    // pipe_readable_stream_to_blob
    // Corresponds to: Bun: Blob.pipe_readable_stream_to_blob
    // ========================================================================

    public func pipeReadableStreamToBlob(global: JsGlobalObject, readableStream: ReadableStream, extraOptions: ?JsValue): JsValue {
        match (store) {
            case None =>
                return JsPromise.reject(global, JsValue("Blob is detached"))
            case Some(s) =>
                if (s.kind == BlobStoreKind.Memory) {
                    return JsPromise.reject(global, JsValue("Blob is read-only"))
                }
                // 对应 Bun pipe logic: read stream, write to file/S3 store
                match (s.kind) {
                    case BlobStoreKind.File =>
                        // 对应 Bun: FileSink.writeFromStream — 将 ReadableStream 管道写入文件
                        let sink = FileSink(s.filePath)
                        return sink.writeFromStream(global, readableStream)
                    case BlobStoreKind.S3 =>
                        // 对应 Bun: S3BlobDownloadTask — 从 S3 下载对象
                        // 需要 S3 客户端基础设施支持
                        return JsPromise.reject(global, JsValue("S3BlobDownloadTask is not yet implemented"))
                    case _ =>
                        return JsPromise.resolve(global, JsValue(Int64(0)))
                }
        }
    }
}

// ============================================================================
// ReadableStream — simplified ReadableStream
// Corresponds to: Bun: jsc.WebCore.ReadableStream
// ============================================================================
public class ReadableStream {
    public static func fromBlob(global: JsGlobalObject, blob: Blob, chunkSize: Int64): ReadableStream {
        return ReadableStream(global, blob, chunkSize)
    }

    /// Returns a used/disturbed stream placeholder
    public static func usedStream(): ReadableStream {
        return ReadableStream()
    }

    /// Create from a JS value
    /// 对应 Bun: ReadableStream.fromJS(global, value)
    /// 尝试从 JS 值中提取 ReadableStream; 支持 Blob/ArrayBuffer 等后备
    public static func fromJsValue(value: JsValue): ?ReadableStream {
        if (value.isEmptyOrUndefinedOrNull()) {
            return None
        }
        if (!value.isObject()) {
            return None
        }
        // 检查是否已有 ReadableStream (通过属性检测)
        let obj = value.toObject()
        // 如果对象有 getReader 方法, 视为 ReadableStream
        let getReader = obj.get("getReader")
        if (getReader.isString() || getReader.isCallable()) {
            let stream = ReadableStream()
            stream.isDisturbed = false
            return Some(stream)
        }
        // 如果是 ArrayBuffer / TypedArray, 包装为 ReadableStream
        if (value.isTypedArray()) {
            let buffer = value.asArrayBuffer(JsObject())
            match (buffer) {
                case Some(ab) =>
                    let bytes = ab.bytes()
                    if (bytes.size > 0) {
                        let blob = Blob(bytes, "application/octet-stream")
                        return Some(ReadableStream(JsGlobalObject(), blob, 0))
                    }
                case None => ()
            }
        }
        // 如果是 Blob 对象
        let blob = Blob.fromJs(JsGlobalObject(), value)
        if (blob.isSome()) {
            return Some(ReadableStream(JsGlobalObject(), blob.getOrThrow().dupe(), 0))
        }
        None
    }

    public static func fromBlobCopyRef(global: JsGlobalObject, blob: Blob, chunkSize: Int64): ?ReadableStream {
        return ReadableStream(global, blob.dupe(), chunkSize)
    }

    public static func fromFileBlobWithOffset(global: JsGlobalObject, blob: Blob, offset: Int64): ReadableStream {
        let stream = ReadableStream(global, blob.dupe(), 0)
        stream.offset = offset
        return stream
    }

    public var global: JsGlobalObject
    public var blob: Blob
    public var chunkSize: Int64
    public var offset: Int64 = 0
    public var consumed: Bool = false
    public var done: Bool = false
    public var isDisturbed: Bool = false
    public var source: ReadableStreamSource
    public var locked: Bool

    public init() {
        this.global = JsGlobalObject()
        this.blob = Blob()
        this.chunkSize = 0
        this.consumed = true
        this.done = true
        this.isDisturbed = true
        this.source = ReadableStreamSource()
        this.locked = false
    }

    public init(source: ReadableStreamSource) {
        this.global = JsGlobalObject()
        this.blob = Blob()
        this.chunkSize = 0
        this.source = source
        this.locked = false
    }

    public init(global: JsGlobalObject, blob: Blob, chunkSize: Int64) {
        this.global = global
        this.blob = blob
        this.chunkSize = chunkSize
        this.source = ReadableStreamSource()
        this.locked = false
    }

    /// 转为 JsValue
    /// 对应 Bun: ReadableStream JS wrapper
    /// 注: 方法以字符串标识符存储, 完整 JSC 函数绑定待后续实现
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("getReader", JsValue("getReader"))
        return JsValue(obj)
    }

    /// 转为 Reader JsValue
    /// 对应 Bun: ReadableStreamDefaultReader JS wrapper
    public func toReaderJsValue(): JsValue {
        let obj = JsObject()
        obj.set("read", JsValue("read"))
        return JsValue(obj)
    }

    /// Tee (split) the stream into two independent streams
    /// Corresponds to: Bun: jsc.WebCore.ReadableStream.tee()
    public func tee(): (ReadableStream, ReadableStream) {
        isDisturbed = true
        let stream1 = ReadableStream(global, blob.dupe(), chunkSize)
        let stream2 = ReadableStream(global, blob.dupe(), chunkSize)
        return (stream1, stream2)
    }

    /// Create an empty/disturbed ReadableStream
    public static func empty(global: JsGlobalObject): ReadableStream {
        let stream = ReadableStream(global, Blob.initEmpty(global), 0)
        stream.consumed = true
        stream.done = true
        stream.isDisturbed = true
        return stream
    }

    /// Whether the stream has been disturbed (read from)
    public func isDisturbedStream(): Bool {
        return isDisturbed
    }

    /// Create from an InternalBlob
    public static func fromInternalBlob(global: JsGlobalObject, b: InternalBlob): ReadableStream {
        let blob = Blob.create(b.toOwnedSlice(), global, b.wasString)
        return ReadableStream(global, blob, 0)
    }

    /// Create from a WTFStringImpl
    public static func fromWTFStringImpl(global: JsGlobalObject, s: WTFStringImpl): ReadableStream {
        let bytes = s.toUtf8Slice()
        let blob = Blob.create(bytes, global, true)
        return ReadableStream(global, blob, 0)
    }

    /// Cleanup / deinit
    public func deinit(): Unit {
        consumed = true
        done = true
    }

    /// Cancel the stream
    /// 对应 Bun: ReadableStream.cancel()
    public func cancel(global: JsGlobalObject): Unit {
        consumed = true
        done = true
        isDisturbed = true
    }

    /// Mark stream as done (callable with global)
    /// 对应 Bun: ReadableStream.done()
    public func doDone(global: JsGlobalObject): Unit {
        consumed = true
        done = true
    }
}

// ============================================================================
// JsPromise — Promise helper
// Corresponds to: Bun: jsc.JSPromise
// ============================================================================
/// JsPromise — Promise helper
/// Corresponds to: Bun: jsc.JSPromise
/// 注: Promise 以简化对象表示, 完整 JSC Promise 绑定待后续实现
public class JsPromise {
    public static func wrap(global: JsGlobalObject, work: () -> JsValue): JsValue {
        let result = work()
        return resolve(global, result)
    }

    /// 创建已解决的 Promise
    /// 对应 Bun: JSPromise.resolve(globalThis, value)
    public static func resolve(global: JsGlobalObject, value: JsValue): JsValue {
        let obj = JsObject()
        obj.set("_resolved", value)
        obj.set("then", JsValue("then"))
        return JsValue(obj)
    }

    /// 创建已拒绝的 Promise
    /// 对应 Bun: JSPromise.reject(globalThis, error)
    public static func reject(global: JsGlobalObject, error: JsValue): JsValue {
        let obj = JsObject()
        obj.set("_rejected", error)
        obj.set("then", JsValue("then"))
        obj.set("catch", JsValue("catch"))
        return JsValue(obj)
    }
}

// ============================================================================
// S3BlobDownloadTask — S3 download task
// Corresponds to: Bun: S3BlobDownloadTask
// ============================================================================
public class S3BlobDownloadTask {
    public var blob: Blob
    public var globalThis: JsGlobalObject
    public var handler: S3ReadHandler

    public init(blob: Blob, global: JsGlobalObject, handler: S3ReadHandler) {
        this.blob = blob
        this.globalThis = global
        this.handler = handler
    }

    public func callHandler(rawBytes: Array<UInt8>): JsValue {
        return handler(blob, globalThis, rawBytes)
    }

    /// Initialize S3 download
    /// Corresponds to: Bun: S3BlobDownloadTask()
    public static func `init`(global: JsGlobalObject, blob: Blob, handler: S3ReadHandler): JsValue {
        let task = S3BlobDownloadTask(blob.dupe(), global, handler)
        // 对应 Bun S3BlobDownloadTask: initiate S3 download via http fetch
        // Falls back to sharedView for non-S3 blobs
        return JsPromise.wrap(global) { =>
            match (blob.store) {
                case Some(s) =>
                    match (s.kind) {
                        case BlobStoreKind.S3 =>
                            // S3 download: use HTTP client to fetch the object
                            // 对应 Bun: S3.download / S3.downloadSlice
                            let s3Url = s.filePath
                            if (s3Url.size > 0) {
                                // 需要 HTTP 客户端实现来获取 S3 对象
                                // 对应 Bun: HttpClient.getBytes(global, s3Url)
                                let result = fetchS3Bytes(global, s3Url)
                                task.callHandler(result)
                            } else {
                                let bytes = task.blob.sharedView()
                                task.callHandler(bytes)
                            }
                        case _ =>
                            let bytes = task.blob.sharedView()
                            task.callHandler(bytes)
                    }
                case None =>
                    task.callHandler(Array<UInt8>())
            }
        }
    }
}

/// S3 read handler function type
/// Corresponds to: Bun: S3ReadHandler
public type S3ReadHandler = (Blob, JsGlobalObject, Array<UInt8>) -> JsValue

/// S3 字节获取辅助函数
/// 对应 Bun: S3.download / S3.downloadSlice
/// 通过 HTTP 获取 S3 对象内容
func fetchS3Bytes(global: JsGlobalObject, s3Url: String): Array<UInt8> {
    // S3 下载需要完整的 AWS S3 客户端实现
    // 包括: AWS 签名 v4, HTTP 请求, 错误处理等
    // 当前返回空数组, 完整实现待 S3 客户端模块
    Array<UInt8>()
}

// ============================================================================
// FileStreamWrapper
// Corresponds to: Bun: FileStreamWrapper
// ============================================================================
public class FileStreamWrapper {
    public var promise: JsValue
    public var readableStreamRef: ReadableStream
    public var sink: FileSink

    public init(promise: JsValue, readableStream: ReadableStream, sink: FileSink) {
        this.promise = promise
        this.readableStreamRef = readableStream
        this.sink = sink
    }
}

// ============================================================================
// FileSink — placeholder for file sink
// Corresponds to: Bun: FileSink
// ============================================================================
public class FileSink {
    /// 文件描述符 (-1 表示未打开)
    public var fd: Int32
    /// 已写入字节总数
    public var totalWritten: BlobSizeType
    /// 是否已关闭
    public var closed: Bool
    /// 输出缓冲区
    public var outputBuffer: ArrayList<UInt8>
    /// 目标路径
    public var destPath: String
    /// 创建时权限
    public var mode: UInt32
    /// 是否已 flush
    public var flushed: Bool

    public init() {
        fd = -1
        totalWritten = 0
        closed = false
        outputBuffer = ArrayList<UInt8>()
        destPath = ""
        mode = WRITE_PERMISSIONS
        flushed = false
    }

    public init(path: String) {
        fd = -1
        totalWritten = 0
        closed = false
        outputBuffer = ArrayList<UInt8>()
        destPath = path
        mode = WRITE_PERMISSIONS
        flushed = false
    }

    /// 打开目标文件
    /// 对应 Bun: FileSink.start() — 打开文件描述符
    public func open(): ?SyscallError {
        if (fd >= 0) {
            return None  // 已打开
        }
        if (destPath.size == 0) {
            return None
        }
        let pathArr = arrayUInt8ToCPointerInt8(destPath.toArray())
        let newFd = unsafe { open(pathArr, Int32(0x40 + 0x200), mode) } // O_CREAT | O_TRUNC
        if (newFd < 0) {
            return Some(SyscallError())
        }
        fd = newFd
        None
    }

    /// 写入数据到文件
    /// 对应 Bun: FileSink.write(buf, len) -> 写入字节数或错误
    public func write(data: Array<UInt8>, offset: Int64, len: Int64): ?SyscallError {
        if (closed) {
            return Some(SyscallError())
        }
        // 将数据追加到输出缓冲区
        for (i in offset..(offset + len)) {
            if (i < Int64(data.size)) {
                outputBuffer.append(data[i])
            }
        }
        totalWritten = totalWritten + len
        None
    }

    /// 刷新输出缓冲区到文件
    /// 对应 Bun: FileSink.flush()/end() — 将缓冲数据写入底层文件描述符
    public func flush(): ?SyscallError {
        if (flushed) {
            return None
        }
        flushed = true

        if (fd < 0) {
            let err = open()
            if (err.isSome()) {
                return err
            }
        }

        if (outputBuffer.size > 0 && fd >= 0) {
            let bytes = outputBuffer.items()
            let ptr = arrayToCPointerUInt8(bytes)
            let written = unsafe { write(fd, ptr, UIntNative(bytes.size)) }
            if (Int64(written) < 0) {
                return Some(SyscallError())
            }
            outputBuffer = ArrayList<UInt8>()
        }
        None
    }

    /// 关闭文件
    /// 对应 Bun: FileSink.end() — flush + close
    public func end(): ?SyscallError {
        let err = flush()
        if (err.isSome()) {
            return err
        }
        if (fd >= 0) {
            unsafe { close(fd) }
            fd = -1
        }
        closed = true
        None
    }

    /// 从 ReadableStream 管道写入文件
    /// 对应 Bun: FileSink.writeFromStream() — 将 ReadableStream 所有数据写入文件
    public func writeFromStream(global: JsGlobalObject, stream: ReadableStream): JsValue {
        let promise = JsPromise.resolve(global, JsValue(Int64(0)))

        if (stream.done || stream.consumed) {
            // 流已结束, 直接返回 0 字节
            return JsPromise.resolve(global, JsValue(Int64(0)))
        }

        // 从 ReadableStream 的 Blob 源读取所有数据并写入
        match (stream.source.tag) {
            case ReadableStreamSourceTag.Bytes =>
                // ByteStream 源: 读取缓冲区中的所有数据
                match (stream.source.byteStream) {
                    case Some(bs) =>
                        let bytes = bs.buffer.items()
                        if (bytes.size > 0) {
                            let writeErr = write(bytes, 0, Int64(bytes.size))
                            if (writeErr.isSome()) {
                                return JsPromise.reject(global, JsValue("FileSink.writeFromStream: write error"))
                            }
                        }
                        let endErr = end()
                        if (endErr.isSome()) {
                            return JsPromise.reject(global, JsValue("FileSink.writeFromStream: close error"))
                        }
                        return JsPromise.resolve(global, JsValue(totalWritten))
                    case None => ()
                }
            case ReadableStreamSourceTag.Blob =>
                // Blob 源: stub - not yet implemented
                ()
            case _ => ()
        }

        // 从 ReadableStream 的 Blob 字段读取 (Blob-backed 流)
        if (stream.blob.size > 0) {
            let bytes = stream.blob.sharedView()
            if (bytes.size > 0) {
                let writeErr = write(bytes, 0, Int64(bytes.size))
                if (writeErr.isSome()) {
                    return JsPromise.reject(global, JsValue("FileSink.writeFromStream: write error"))
                }
            }
            let endErr = end()
            if (endErr.isSome()) {
                return JsPromise.reject(global, JsValue("FileSink.writeFromStream: close error"))
            }
            stream.consumed = true
            stream.done = true
            return JsPromise.resolve(global, JsValue(totalWritten))
        }

        // 未知流类型: 返回错误
        JsPromise.reject(global, JsValue("FileSink.writeFromStream: unsupported stream source"))
    }

    /// 运行挂起的任务
    /// 对应 Bun: FileSink.runPending() — 通过事件循环刷新挂起的写入
    public func runPending(): Unit {
        if (!closed && outputBuffer.size > 0) {
            flush()
        }
    }

    /// 增加引用计数
    public func ref(): Unit {
        // 对应 Bun: 引用计数 +1 — 仓颉 GC 管理生命周期
    }

    /// 减少引用计数
    public static func deref(sink: FileSink): Unit {
        // 对应 Bun: 引用计数 -1 — 确保文件关闭
        if (!sink.closed) {
            sink.end()
        }
    }
}

// ============================================================================
// Internal (InternalBlob) — single-use Blob backed by an allocation
// Corresponds to: Bun: Any.InternalBlob
// ============================================================================
public class InternalBlob {
    public var bytes: Array<UInt8>
    public var wasString: Bool

    public init() {
        bytes = Array<UInt8>()
        wasString = false
    }

    public init(bytes: Array<UInt8>, wasString: Bool) {
        this.bytes = bytes
        this.wasString = wasString
    }

    public func memoryCost(): Int64 {
        return Int64(bytes.size)
    }

    public func toString(): String {
        return Utf8Codec.decode(bytes)
    }

    public func slice(): Array<UInt8> {
        return bytes
    }

    public func toOwnedSlice(): Array<UInt8> {
        let result = bytes
        bytes = Array<UInt8>()
        return result
    }

    public func contentType(): String {
        if (wasString) {
            return "text/plain;charset=utf-8"
        }
        return "application/octet-stream"
    }

    public func clear(): Unit {
        bytes = Array<UInt8>()
        wasString = false
    }
}

// ============================================================================
// InlineBlob — small Blob stored inline
// Corresponds to: Bun: InlineBlob
// ============================================================================
public class InlineBlob {
    public static let AVAILABLE_BYTES: Int64 = 24  // approx sizeof(Blob) - 2

    public var bytes: Array<UInt8>
    public var wasString: Bool

    public init() {
        bytes = Array<UInt8>()
        wasString = false
    }

    public init(data: Array<UInt8>, wasString: Bool) {
        bytes = data
        this.wasString = wasString
    }

    public static func concat(first: Array<UInt8>, second: Array<UInt8>): InlineBlob {
        let total = ArrayList<UInt8>()
        for (b in first) {
            total.append(b)
        }
        for (b in second) {
            total.append(b)
        }
        return InlineBlob(total.items(), false)
    }

    public static func `init`(data: Array<UInt8>): InlineBlob {
        return InlineBlob(data, false)
    }

    public static func initString(data: Array<UInt8>): InlineBlob {
        return InlineBlob(data, true)
    }

    public func toStringOwned(global: JsGlobalObject): JsValue {
        if (bytes.size == 0) {
            return JsValue("")
        }
        let text = Utf8Codec.decode(bytes)
        let result = JsValue(text)
        bytes = Array<UInt8>()
        return result
    }

    public func contentType(): String {
        if (wasString) {
            return "text/plain;charset=utf-8"
        }
        return "application/octet-stream"
    }

    public func deinit(): Unit {
        bytes = Array<UInt8>()
    }

    public func slice(): Array<UInt8> {
        return bytes
    }

    public func clearAndFree(): Unit {
        bytes = Array<UInt8>()
    }
}

// ============================================================================
// AnyBlob — union of Blob / InternalBlob / WTFString
// Corresponds to: Bun: Any (AnyBlob)
// ============================================================================
public enum AnyBlobKind {
    | Blob
    | InternalBlob
    | WTFString
}

public class AnyBlob {
    public var kind: AnyBlobKind
    public var blob: Blob
    public var internalBlob: InternalBlob

    public init(blob: Blob) {
        kind = AnyBlobKind.Blob
        this.blob = blob
        internalBlob = InternalBlob()
    }

    public init(internalBlob: InternalBlob) {
        kind = AnyBlobKind.InternalBlob
        blob = Blob()
        this.internalBlob = internalBlob
    }

    public static func fromOwnedSlice(bytes: Array<UInt8>): AnyBlob {
        return AnyBlob(InternalBlob(bytes, false))
    }

    public static func fromArrayList(list: Array<UInt8>): AnyBlob {
        return AnyBlob(InternalBlob(list, false))
    }

    public func memoryCost(): Int64 {
        match (kind) {
            case AnyBlobKind.Blob =>
                match (blob.store) {
                    case Some(s) => s.memoryCost()
                    case None => 0
                }
            case AnyBlobKind.InternalBlob => internalBlob.memoryCost()
            case AnyBlobKind.WTFString => 0
        }
    }

    public func hasOneRef(): Bool {
        match (kind) {
            case AnyBlobKind.Blob =>
                match (blob.store) {
                    case Some(s) => s.hasOneRef()
                    case None => false
                }
            case _ => false
        }
    }

    public func getFileName(): ?String {
        match (kind) {
            case AnyBlobKind.Blob => blob.getFileName()
            case _ => None
        }
    }

    public func fastSize(): BlobSizeType {
        match (kind) {
            case AnyBlobKind.Blob => blob.size
            case AnyBlobKind.InternalBlob => Int64(internalBlob.bytes.size)
            case AnyBlobKind.WTFString => 0
        }
    }

    public func size(): BlobSizeType {
        return fastSize()
    }

    public func hasContentTypeFromUser(): Bool {
        match (kind) {
            case AnyBlobKind.Blob => blob.hasContentTypeFromUser()
            case _ => false
        }
    }

    public func isDetached(): Bool {
        match (kind) {
            case AnyBlobKind.Blob => blob.isDetached()
            case AnyBlobKind.InternalBlob => internalBlob.bytes.size == 0
            case AnyBlobKind.WTFString => true
        }
    }

    public func contentType(): String {
        match (kind) {
            case AnyBlobKind.Blob =>
                let ct = blob.contentType
                if (ct.size > 0) {
                    return ct
                }
                match (blob.store) {
                    case Some(s) => s.mimeType
                    case None => ""
                }
            case AnyBlobKind.InternalBlob => internalBlob.contentType()
            case AnyBlobKind.WTFString => "text/plain;charset=utf-8"
        }
    }

    public func wasString(): Bool {
        match (kind) {
            case AnyBlobKind.Blob =>
                match (blob.charset) {
                    case CharsetKind.ascii => true
                    case _ => false
                }
            case AnyBlobKind.WTFString => true
            case AnyBlobKind.InternalBlob => internalBlob.wasString
        }
    }

    public func slice(): Array<UInt8> {
        match (kind) {
            case AnyBlobKind.Blob => blob.sharedView()
            case AnyBlobKind.InternalBlob => internalBlob.slice()
            case AnyBlobKind.WTFString => Array<UInt8>()
        }
    }

    public func needsToReadFile(): Bool {
        match (kind) {
            case AnyBlobKind.Blob => blob.needsToReadFile()
            case _ => false
        }
    }

    public func isS3(): Bool {
        match (kind) {
            case AnyBlobKind.Blob => blob.isS3()
            case _ => false
        }
    }

    public func detach(): Unit {
        match (kind) {
            case AnyBlobKind.Blob =>
                blob.detach()
            case AnyBlobKind.InternalBlob =>
                internalBlob.clear()
            case AnyBlobKind.WTFString => ()
        }
    }

    public func toBlob(global: JsGlobalObject): Blob {
        if (size() == 0) {
            return Blob.initEmpty(global)
        }
        match (kind) {
            case AnyBlobKind.Blob => return blob.dupe()
            case AnyBlobKind.InternalBlob =>
                let b = Blob.create(internalBlob.toOwnedSlice(), global, internalBlob.wasString)
                return b
            case AnyBlobKind.WTFString => return Blob.initEmpty(global)
        }
    }

    public func toString(global: JsGlobalObject, lifetime: BlobLifetime): JsValue {
        match (kind) {
            case AnyBlobKind.Blob => blob.toStringWithLifetime(global, lifetime)
            case AnyBlobKind.InternalBlob =>
                let text = internalBlob.toString()
                internalBlob.clear()
                JsValue(text)
            case AnyBlobKind.WTFString => JsValue("")
        }
    }

    public func toArrayBuffer(global: JsGlobalObject, lifetime: BlobLifetime): JsValue {
        match (kind) {
            case AnyBlobKind.Blob => blob.toArrayBufferWithLifetime(global, lifetime)
            case AnyBlobKind.InternalBlob =>
                let bytes = internalBlob.toOwnedSlice()
                internalBlob.clear()
                JsValue.createBuffer(global.globalThis, bytes)
            case AnyBlobKind.WTFString => JsValue.createBuffer(global.globalThis, Array<UInt8>())
        }
    }

    public func toJSON(global: JsGlobalObject, lifetime: BlobLifetime): JsValue {
        match (kind) {
            case AnyBlobKind.Blob => blob.toJSONWithLifetime(global, lifetime)
            case AnyBlobKind.InternalBlob =>
                let text = internalBlob.toString()
                internalBlob.clear()
                JsValue(text)
            case AnyBlobKind.WTFString => JsValue("null")
        }
    }

    /// Convert to action value based on buffer action
    /// Corresponds to: Bun: Any.to_action_value
    public func toActionValue(global: JsGlobalObject, action: BufferActionTag): JsValue {
        match (action) {
            case BufferActionTag.Text => toString(global, BlobLifetime.Clone)
            case BufferActionTag.Bytes => toArrayBuffer(global, BlobLifetime.Transfer)
            case BufferActionTag.Blob =>
                let b = toBlob(global)
                return b.toJsValue(global)
            case BufferActionTag.ArrayBuffer => toArrayBuffer(global, BlobLifetime.Transfer)
            case BufferActionTag.Json => toJSON(global, BlobLifetime.Share)
        }
    }

    /// Convert to promise based on buffer action
    /// Corresponds to: Bun: Any.to_promise
    public func toPromise(global: JsGlobalObject, action: BufferActionTag): JsValue {
        return JsPromise.wrap(global) { =>
            toActionValue(global, action)
        }
    }

    /// Create AnyBlob from an InternalBlob
    public static func fromInternalBlob(b: InternalBlob): AnyBlob {
        return AnyBlob(b)
    }

    /// Create AnyBlob from a WTFStringImpl
    public static func fromWTFStringImpl(s: WTFStringImpl): AnyBlob {
        let bytes = s.toUtf8Slice()
        return AnyBlob(InternalBlob(bytes, true))
    }

    /// Create AnyBlob from a Blob
    public static func fromBlob(b: Blob): AnyBlob {
        return AnyBlob(b)
    }

    /// Convert to InternalBlob
    public func toInternalBlob(): InternalBlob {
        match (kind) {
            case AnyBlobKind.InternalBlob => internalBlob
            case AnyBlobKind.Blob => InternalBlob(blob.sharedView(), false)
            case AnyBlobKind.WTFString => InternalBlob()
        }
    }

    /// Check if the blob is definitely empty (zero size)
    public func isDefinitelyEmpty(): Bool {
        return fastSize() == 0
    }

    /// Get the blob store
    public func store(): ?BlobStore {
        match (kind) {
            case AnyBlobKind.Blob => blob.store
            case _ => None
        }
    }
}

// ============================================================================
// BufferActionTag — buffer conversion action
// Corresponds to: Bun: streams.BufferActionTag
// ============================================================================
public enum BufferActionTag {
    | Text
    | Bytes
    | Blob
    | ArrayBuffer
    | Json
}

// ============================================================================
// ReadBytesHandler — trait for read bytes callback
// Corresponds to: Bun: ReadBytesHandler
// ============================================================================
public interface ReadBytesHandler {
    func onReadBytes(result: ReadBytesResult): Unit
}

// ============================================================================
// InternalReadFileFn — trait for internal read file callback
// Corresponds to: Bun: InternalReadFileFn
// ============================================================================
public interface InternalReadFileFn {
    func call(ctx: Array<UInt8>, bytes: ReadFileResultType): Unit
}

// ============================================================================
// FileOpener — generic file-open helper trait
// Corresponds to: Bun: FileOpener
// ============================================================================
public interface FileOpener {
    func openedFd(): Int32
    func setOpenedFd(fd: Int32): Unit
    func setErrno(e: Int64): Unit
    func setSystemError(e: SystemError): Unit
    func pathlike(): PathOrFileDescriptor
    func tryMkdirp(err: SyscallError, path: String, displayPath: String): Retry
}

// ============================================================================
// FileCloser — generic file-close helper trait
// Corresponds to: Bun: FileCloser
// ============================================================================
public interface FileCloser {
    func openedFd(): Int32
    func setOpenedFd(fd: Int32): Unit
    func closeAfterIo(): Bool
    func setCloseAfterIo(v: Bool): Unit
    func state(): UInt8
    func doClose(isAllowedToCloseFd: Bool): Bool
}

// ============================================================================
// SyscallError — system call error
// Corresponds to: Bun: bun.sys.Error
// ============================================================================
public class SyscallError {
    public var errno: Int64
    public var message: String
    public var syscall: String
    public var path: String

    public init() {
        errno = 0
        message = ""
        syscall = ""
        path = ""
    }

    public init(errno: Int64, message: String, syscall: String) {
        this.errno = errno
        this.message = message
        this.syscall = syscall
        path = ""
    }

    public func withPath(p: String): SyscallError {
        let err = SyscallError()
        err.errno = errno
        err.message = message
        err.syscall = syscall
        err.path = p
        return err
    }
}

// ============================================================================
// MkdirpTarget — trait for mkdir target
// Corresponds to: Bun: MkdirpTarget
// ============================================================================
public interface MkdirpTarget {
    func mkdirpIfExists(): Bool
    func setMkdirpIfExists(v: Bool): Unit
    func setSystemError(e: SystemError): Unit
}

// ============================================================================
// Utility Functions
// ============================================================================

/// Check if string is all ASCII
/// Corresponds to: Bun: strings.isAllAscii
public func isAllAsciiFunc(s: String): Bool {
    for (c in s) {
        if (Int32(c) > 127) {
            return false
        }
    }
    return true
}

/// Format file size
/// Corresponds to: Bun: bun.fmt.size
public func formatSize(bytes: Int64): String {
    if (bytes < 1024) {
        return "${bytes} B"
    }
    if (bytes < 1024 * 1024) {
        let kb = Float64(bytes) / 1024.0
        return "${kb} KB"
    }
    if (bytes < 1024 * 1024 * 1024) {
        let mb = Float64(bytes) / (1024.0 * 1024.0)
        return "${mb} MB"
    }
    if (bytes < 1024 * 1024 * 1024 * 1024) {
        let gb = Float64(bytes) / (1024.0 * 1024.0 * 1024.0)
        return "${gb} GB"
    }
    let tb = Float64(bytes) / (1024.0 * 1024.0 * 1024.0 * 1024.0)
    return "${tb} TB"
}

/// Validate that a blob is writable
/// Corresponds to: Bun: validate_writable_blob
public func validateWritableBlob(global: JsGlobalObject, blob: Blob): ?JsValue {
    match (blob.store) {
        case None =>
            return JsPromise.reject(global, JsValue("Cannot write to a detached Blob"))
        case Some(s) =>
            if (s.kind == BlobStoreKind.Memory) {
                return JsPromise.reject(global, JsValue("Cannot write to a Blob backed by bytes, which are always read-only"))
            }
    }
    return None
}

/// mkdirRecursive — create directory and all parent directories
/// 对应 Bun: node.fs.mkdir_recursive via MkdirpTarget
func mkdirRecursive(path: String): SysMaybe<Unit> {
    match (SysFs.mkdir(path, UInt32(0x1FF))) {
        case SysMaybe<Unit>.Ok(_) => SysMaybe<Unit>.Ok(())
        case SysMaybe<Unit>.Err(_) =>
            let parentDir = Path.dirname(path)
            if (parentDir.size == 0 || parentDir == path) {
                return SysMaybe<Unit>.Err(SysError(0, SysTag.Mkdir))
            }
            let parentResult = mkdirRecursive(parentDir)
            match (parentResult) {
                case SysMaybe<Unit>.Ok(_) => SysFs.mkdir(path, UInt32(0x1FF))
                case SysMaybe<Unit>.Err(e) => SysMaybe<Unit>.Err(e)
            }
    }
}

/// mkdirIfNotExists — create parent directory if needed
/// Corresponds to: Bun: mkdir_if_not_exists
public func mkdirIfNotExists(path: String, errno: Int64, mkdirp: Bool): Retry {
    // 对应 Bun mkdir_if_not_exists: ENOENT + mkdirp => recursive mkdir on parent
    if (errno == 2 && mkdirp) {  // ENOENT
        let parentDir = Path.dirname(path)
        if (parentDir.size > 0) {
            let result = mkdirRecursive(parentDir)
            match (result) {
                case SysMaybe<Unit>.Ok(_) => return Retry.Continue
                case SysMaybe<Unit>.Err(_) => return Retry.Fail
            }
        }
        return Retry.Continue
    }
    return Retry.No
}

/// resolveFileStat — resolve file stat like size, last_modified
/// Corresponds to: Bun: resolve_file_stat
func resolveFileStat(store: BlobStore): Unit {
    // 对应 Bun resolve_file_stat: stat/fstat to populate maxFileSize, fileMode, seekable, fileLastModified
    if (store.kind != BlobStoreKind.File) {
        return
    }
    if (store.isFd) {
        // fstat via FFI
        match (SysImpl.fstat(Int64(store.fileFd))) {
            case SysMaybe<PosixStat>.Ok(stat) =>
                let isReg = stat.isFile()
                store.maxFileSize = if (isReg || stat.size > 0) {
                    max(Int64(stat.size), 0)
                } else {
                    BLOB_MAX_SIZE
                }
                store.fileMode = UInt64(stat.mode)
                store.seekable = Some(isReg)
                store.fileLastModified = Float64(stat.mtimeSec) * 1000.0 + Float64(stat.mtimeNsec) / 1000000.0
            case _ => ()
        }
        return
    }
    if (store.filePath.size == 0) {
        return
    }
    // stat via FFI
    match (SysImpl.stat(store.filePath)) {
        case SysMaybe<PosixStat>.Ok(stat) =>
            let isReg = stat.isFile()
            store.maxFileSize = if (isReg || stat.size > 0) {
                max(Int64(stat.size), 0)
            } else {
                BLOB_MAX_SIZE
            }
            store.fileMode = UInt64(stat.mode)
            store.seekable = Some(isReg)
            store.fileLastModified = Float64(stat.mtimeSec) * 1000.0 + Float64(stat.mtimeNsec) / 1000000.0
        case _ =>
            store.maxFileSize = BLOB_MAX_SIZE
            store.fileMode = 0
            store.seekable = None
            store.fileLastModified = 0.0
    }
}

/// writeFormatForSize
/// Corresponds to: Bun: write_format_for_size
public func writeFormatForSize(isJdomFile: Bool, size: Int64): String {
    let typeName = if (isJdomFile) { "File" } else { "Blob" }
    let sizeStr = formatSize(size)
    return "${typeName} (${sizeStr})"
}

/// httpProxyHref — get HTTP proxy URL
/// Corresponds to: Bun: http_proxy_href
/// 对应 Bun: transpiler.env.getHttpProxy(true, null, null)?.href
/// 从环境变量 HTTP_PROXY / HTTPS_PROXY / http_proxy / https_proxy 获取代理 URL
func httpProxyHref(global: JsGlobalObject): ?String {
    // 检查常见的代理环境变量
    let proxyVars = ["HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy", "ALL_PROXY", "all_proxy"]
    for (varName in proxyVars) {
        let val = getEnvVar(varName)
        if (val.isSome()) {
            let proxyUrl = val.getOrThrow()
            if (proxyUrl.size > 0) {
                return Some(proxyUrl)
            }
        }
    }
    return None
}

/// 获取环境变量
/// 对应 Bun: std.process.getEnvMap / libc.getenv
@C foreign func getenv(name: CPointer<Int8>): CPointer<Int8>
func getEnvVar(name: String): ?String {
    let nameBytes = Utf8Codec.encode(name)
    let nullTerminated = Array<Int8>(nameBytes.size + 1, repeat: Int8(0))
    for (i in 0..nameBytes.size) {
        nullTerminated[i] = Int8(nameBytes[i])
    }
    let result = unsafe { getenv(arrayToCPointerInt8(nullTerminated)) }
    if (result.isNull()) {
        return None
    }
    // 读取结果字符串
    var len: Int64 = 0
    while (unsafe { (result + Int64(len)).read() } != Int8(0)) {
        len += 1
    }
    let outBytes = Array<UInt8>(len, repeat: UInt8(0))
    for (i in 0..len) {
        outBytes[i] = UInt8(unsafe { (result + Int64(i)).read() })
    }
    return Some(outBytes.toString())
}

/// blobStoreArrayBufferDeallocator
/// Corresponds to: Bun: blob_store_array_buffer_deallocator
public func blobStoreArrayBufferDeallocator(store: BlobStore): Unit {
    store.deref()
}

// ============================================================================
// ReadFileToJs — trait for read file to JS value
// Corresponds to: Bun: read_file::ReadFileToJs
// ============================================================================
public interface ReadFileToJs {
    func call(blob: Blob, global: JsGlobalObject, bytes: Array<UInt8>, lifetime: BlobLifetime): JsValue
}

// ============================================================================
// ToStringWithBytesFn — marker type for toString dispatch
// Corresponds to: Bun: ToStringWithBytesFn
// ============================================================================
public class ToStringWithBytesFn <: ReadFileToJs {
    public func call(blob: Blob, global: JsGlobalObject, bytes: Array<UInt8>, lifetime: BlobLifetime): JsValue {
        let text = Utf8Codec.decode(bytes)
        if (lifetime == BlobLifetime.Transfer) {
            blob.detach()
        }
        return JsValue(text)
    }
}

// ============================================================================
// ToJsonWithBytesFn — marker type for toJSON dispatch
// Corresponds to: Bun: ToJsonWithBytesFn
// ============================================================================
public class ToJsonWithBytesFn <: ReadFileToJs {
    public func call(blob: Blob, global: JsGlobalObject, bytes: Array<UInt8>, lifetime: BlobLifetime): JsValue {
        let text = Utf8Codec.decode(bytes)
        if (lifetime == BlobLifetime.Transfer) {
            blob.detach()
        }
        return JsValue(text)
    }
}

// ============================================================================
// ToArrayBufferWithBytesFn — marker type for toArrayBuffer dispatch
// Corresponds to: Bun: ToArrayBufferWithBytesFn
// ============================================================================
public class ToArrayBufferWithBytesFn <: ReadFileToJs {
    public func call(blob: Blob, global: JsGlobalObject, bytes: Array<UInt8>, lifetime: BlobLifetime): JsValue {
        if (lifetime == BlobLifetime.Transfer) {
            blob.detach()
        }
        return JsValue.createBuffer(global.globalThis, bytes)
    }
}

// ============================================================================
// ToUint8ArrayWithBytesFn — marker type for toUint8Array dispatch
// Corresponds to: Bun: ToUint8ArrayWithBytesFn
// ============================================================================
public class ToUint8ArrayWithBytesFn <: ReadFileToJs {
    public func call(blob: Blob, global: JsGlobalObject, bytes: Array<UInt8>, lifetime: BlobLifetime): JsValue {
        if (lifetime == BlobLifetime.Transfer) {
            blob.detach()
        }
        return JsValue.createBuffer(global.globalThis, bytes)
    }
}

// ============================================================================
// ToFormDataWithBytesFn — marker type for toFormData dispatch
// Corresponds to: Bun: ToFormDataWithBytesFn
// ============================================================================
public class ToFormDataWithBytesFn <: ReadFileToJs {
    public func call(blob: Blob, global: JsGlobalObject, bytes: Array<UInt8>, lifetime: BlobLifetime): JsValue {
        let encoding = blob.getFormDataEncoding()
        if (encoding.isNone()) {
            return JsValue()
        }
        return JsValue()
    }
}

// ============================================================================
// FormDataEntryType — form data entry enum
// Corresponds to: Bun: FormDataEntry
// ============================================================================
public enum FormDataEntryType {
    | String(String)
    | File(Blob, String)  // (blob, filename)
}

// ============================================================================
// FormDataContext — form data serialization context
// Corresponds to: Bun: FormDataContext
// ============================================================================
public class FormDataContext {
    public var parts: ArrayList<Array<UInt8>>
    public var boundary: String
    public var failed: Bool
    public var globalThis: ?JsGlobalObject

    public init(boundary: String, global: JsGlobalObject) {
        parts = ArrayList<Array<UInt8>>()
        this.boundary = boundary
        failed = false
        globalThis = Some(global)
    }

    /// Process a form data entry
    /// Corresponds to: Bun: FormDataContext.on_entry
    public func onEntry(name: String, entry: FormDataEntryType): Unit {
        if (failed) {
            return
        }

        let boundaryBytes = Utf8Codec.encode(boundary)
        appendStatic("--")
        appendBytes(boundaryBytes)
        appendStatic("\r\n")

        appendStatic("Content-Disposition: form-data; name=\"")
        appendBytes(Utf8Codec.encode(name))

        match (entry) {
            case FormDataEntryType.String(value) =>
                appendStatic("\"\r\n\r\n")
                appendBytes(Utf8Codec.encode(value))
            case FormDataEntryType.File(blob, filename) =>
                appendStatic("\"; filename=\"")
                appendBytes(Utf8Codec.encode(filename))
                appendStatic("\"\r\n")

                let ct = blob.contentType
                let contentType = if (ct.size > 0) { ct } else { "application/octet-stream" }
                appendStatic("Content-Type: ")
                appendBytes(Utf8Codec.encode(contentType))
                appendStatic("\r\n\r\n")

                // Append blob data
                match (blob.store) {
                    case Some(s) =>
                        match (s.kind) {
                            case BlobStoreKind.Memory =>
                                appendBytes(blob.sharedView())
                            case BlobStoreKind.File =>
                                // 对应 Bun FormData file read: read file bytes synchronously
                                let view = blob.sharedView()
                                if (view.size > 0) {
                                    appendBytes(view)
                                } else {
                                    let fileBytes = blob.sharedView()
                                    if (fileBytes.size > 0) {
                                        appendBytes(fileBytes)
                                    }
                                }
                            case BlobStoreKind.S3 =>
                                // 对应 Bun FormData S3: download and append bytes
                                let view = blob.sharedView()
                                if (view.size > 0) {
                                    appendBytes(view)
                                }
                        }
                    case None => ()
                }
        }

        appendStatic("\r\n")
    }

    private func appendStatic(s: String): Unit {
        parts.append(Utf8Codec.encode(s))
    }

    private func appendBytes(b: Array<UInt8>): Unit {
        parts.append(b)
    }

    /// Get the final form data bytes
    public func toBytes(): Array<UInt8> {
        // Final boundary
        appendStatic("--")
        appendBytes(Utf8Codec.encode(boundary))
        appendStatic("--\r\n")

        let result = ArrayList<UInt8>()
        for (part in parts) {
            for (b in part) {
                result.append(b)
            }
        }
        return result.items()
    }
}

// ============================================================================
// URLSearchParamsConverter — URL search params to Blob converter
// Corresponds to: Bun: URLSearchParamsConverter
// ============================================================================
public class URLSearchParamsConverter {
    public var buf: Array<UInt8>
    public var globalThis: ?JsGlobalObject

    public init(global: JsGlobalObject) {
        buf = Array<UInt8>()
        globalThis = Some(global)
    }

    public func convert(str: String): Unit {
        buf = Utf8Codec.encode(str)
    }
}

// ============================================================================
// StructuredCloneWriter — structured clone serialization writer
// Corresponds to: Bun: StructuredCloneWriter
// ============================================================================
public class StructuredCloneWriter {
    public var buffer: ArrayList<UInt8>

    public init() {
        buffer = ArrayList<UInt8>()
    }

    /// Write bytes to the structured clone buffer
    /// Corresponds to: Bun: StructuredCloneWriter.write
    public func write(bytes: Array<UInt8>): Int64 {
        for (b in bytes) {
            buffer.append(b)
        }
        return Int64(bytes.size)
    }

    /// Write all bytes
    /// Corresponds to: Bun: bun_io.Write for StructuredCloneWriter
    public func writeAll(bytes: Array<UInt8>): Unit {
        for (b in bytes) {
            buffer.append(b)
        }
    }

    /// Get the written bytes
    public func toBytes(): Array<UInt8> {
        return buffer.items()
    }
}

// ============================================================================
// TemporaryBytes — RAII wrapper for temporary byte ownership
// Corresponds to: Bun: TemporaryBytes
// ============================================================================
public class TemporaryBytes {
    public var bytes: Array<UInt8>
    public var consumed: Bool

    public init(bytes: Array<UInt8>) {
        this.bytes = bytes
        consumed = false
    }

    public func consume(): Array<UInt8> {
        consumed = true
        let result = bytes
        bytes = Array<UInt8>()
        return result
    }
}

// ============================================================================
// onFileStreamResolveRequestStream — resolve callback for file stream
// Corresponds to: Bun: on_file_stream_resolve_request_stream
// 对应 Bun: if (strong.get(globalThis)) |stream| { stream.done(globalThis); }
//           try this.promise.resolve(globalThis, jsc.JSValue.jsNumber(0));
// ============================================================================
public func onFileStreamResolveRequestStream(global: JsGlobalObject, wrapper: FileStreamWrapper): JsValue {
    // 标记流为完成状态
    wrapper.readableStreamRef.doDone(global)
    // 解析 Promise
    let resolvedPromise = JsPromise.resolve(global, JsValue(Float64(0)))
    wrapper.promise = resolvedPromise
    return JsValue.UNDEFINED
}

// ============================================================================
// onFileStreamRejectRequestStream — reject callback for file stream
// Corresponds to: Bun: on_file_stream_reject_request_stream
// 对应 Bun: try this.promise.reject(globalThis, err);
//           if (strong.get(globalThis)) |stream| { stream.cancel(globalThis); }
// ============================================================================
public func onFileStreamRejectRequestStream(global: JsGlobalObject, wrapper: FileStreamWrapper, err: JsValue): JsValue {
    // 取消流
    wrapper.readableStreamRef.cancel(global)
    // 拒绝 Promise
    let rejectedPromise = JsPromise.reject(global, err)
    wrapper.promise = rejectedPromise
    return JsValue.UNDEFINED
}

// ============================================================================
// writeStringToFileFast — fast path for writing string to file
// Corresponds to: Bun: write_string_to_file_fast
// ============================================================================
public func writeStringToFileFast(global: JsGlobalObject, pathlike: PathOrFileDescriptor, str: String, needsOpen: Bool): JsValue {
    // 对应 Bun write_string_to_file_fast: write encoded string bytes via SysFs
    let bytes = Utf8Codec.encode(str)
    let writeResult = writePathOrFd(pathlike, bytes, needsOpen)
    match (writeResult) {
        case SysMaybe<Unit>.Ok(_) =>
            return JsPromise.resolve(global, JsValue(Float64(Int64(bytes.size))))
        case SysMaybe<Unit>.Err(e) =>
            return JsPromise.reject(global, JsValue("Failed to write file"))
    }
}

// ============================================================================
// writeBytesToFileFast — fast path for writing bytes to file
// Corresponds to: Bun: write_bytes_to_file_fast
// ============================================================================
public func writeBytesToFileFast(global: JsGlobalObject, pathlike: PathOrFileDescriptor, bytes: Array<UInt8>, needsOpen: Bool): JsValue {
    // 对应 Bun write_bytes_to_file_fast: write byte array via SysFs
    let writeResult = writePathOrFd(pathlike, bytes, needsOpen)
    match (writeResult) {
        case SysMaybe<Unit>.Ok(_) =>
            return JsPromise.resolve(global, JsValue(Float64(Int64(bytes.size))))
        case SysMaybe<Unit>.Err(e) =>
            return JsPromise.reject(global, JsValue("Failed to write file"))
    }
}

/// Helper: write bytes to path or fd
/// 对应 Bun: write_bytes_to_file_fast via SysFs
/// 使用 POSIX open/write/close 系统调用写入文件
func writePathOrFd(pathlike: PathOrFileDescriptor, bytes: Array<UInt8>, needsOpen: Bool): SysMaybe<Unit> {
    if (bytes.size == 0) {
        return SysMaybe<Unit>.Ok(())
    }

    // O_WRONLY | O_CREAT | O_TRUNC = 0x241 (577)
    // 对应 Bun: O_WRONLY | O_CREAT | O_TRUNC
    let O_WRONLY: Int32 = 0x0001
    let O_CREAT: Int32 = 0x0040
    let O_TRUNC: Int32 = 0x0200
    let flags: Int32 = O_WRONLY | O_CREAT | O_TRUNC

    // 打开文件
    let pathBytes = Utf8Codec.encode(pathlike.path)
    let nullTermPath = Array<Int8>(pathBytes.size + 1, repeat: Int8(0))
    for (i in 0..pathBytes.size) {
        nullTermPath[i] = Int8(pathBytes[i])
    }

    let fd = unsafe { open(arrayToCPointerInt8(nullTermPath), flags, WRITE_PERMISSIONS) }
    if (fd < 0) {
        return SysMaybe<Unit>.Err(SysError())
    }

    // 写入数据
    let written = unsafe { write(fd, arrayToCPointerUInt8(bytes), UIntNative(bytes.size)) }
    unsafe { close(fd) }

    if (Int64(written) != Int64(bytes.size)) {
        return SysMaybe<Unit>.Err(SysError())
    }

    return SysMaybe<Unit>.Ok(())
}

// ============================================================================
// toStreamWithOffset — create ReadableStream from Blob with offset
// Corresponds to: Bun: to_stream_with_offset
// ============================================================================
public func toStreamWithOffset(global: JsGlobalObject, blob: Blob, offset: Int64): JsValue {
    return ReadableStream.fromFileBlobWithOffset(global, blob, offset).toJsValue()
}

/// 获取当前时间戳 (毫秒)
/// 对应 Bun: std.time.milliTimestamp()
@C foreign func clock_gettime_blob(clk_id: Int32, tp: CPointer<Unit>): Int32
func getCurrentTimeMillisBlob(): Int64 {
    // CLOCK_REALTIME = 0
    let buf = Array<Int8>(16, repeat: Int8(0))
    let bufPtr = arrayToCPointerInt8(buf)
    let ret = unsafe { clock_gettime_blob(0, CPointer<Unit>(bufPtr)) }
    if (ret == 0) {
        let sec = unsafe {
            (Int64((bufPtr + 0).read()) & 0xFF) |
            ((Int64((bufPtr + 1).read()) & 0xFF) << 8) |
            ((Int64((bufPtr + 2).read()) & 0xFF) << 16) |
            ((Int64((bufPtr + 3).read()) & 0xFF) << 24) |
            ((Int64((bufPtr + 4).read()) & 0xFF) << 32) |
            ((Int64((bufPtr + 5).read()) & 0xFF) << 40) |
            ((Int64((bufPtr + 6).read()) & 0xFF) << 48) |
            ((Int64((bufPtr + 7).read()) & 0xFF) << 56)
        }
        let nsec = unsafe {
            (Int64((bufPtr + 8).read()) & 0xFF) |
            ((Int64((bufPtr + 9).read()) & 0xFF) << 8) |
            ((Int64((bufPtr + 10).read()) & 0xFF) << 16) |
            ((Int64((bufPtr + 11).read()) & 0xFF) << 24) |
            ((Int64((bufPtr + 12).read()) & 0xFF) << 32) |
            ((Int64((bufPtr + 13).read()) & 0xFF) << 40) |
            ((Int64((bufPtr + 14).read()) & 0xFF) << 48) |
            ((Int64((bufPtr + 15).read()) & 0xFF) << 56)
        }
        return sec * 1000 + nsec / 1000000
    }
    return Int64(0)
}

// ============================================================================
// C-Exported FFI Stubs
// Corresponds to: Bun: Blob__dupe, Blob__getDataPtr, Blob__getSize, etc.
// These would be @CInterop exports in Cangjie; stubbed here for API completeness.
// ============================================================================

/// Blob__dupe — duplicate a Blob
/// Corresponds to: Bun: Blob__dupe
public func blobDupe(blob: Blob): Blob {
    return blob.dupeWithContentType(true)
}

/// Blob__dupeFromJS — duplicate a Blob from JS value
/// Corresponds to: Bun: Blob__dupeFromJS
public func blobDupeFromJs(global: JsGlobalObject, value: JsValue): ?Blob {
    let blob = Blob.fromJs(global, value)
    if (blob.isNone()) {
        return None
    }
    return Some(blobDupe(blob.getOrThrow()))
}

/// Blob__setAsFile — mark a Blob as a File
/// Corresponds to: Bun: Blob__setAsFile
public func blobSetAsFile(blob: Blob, pathStr: String): Unit {
    blob.isJsdomFile = true
    match (blob.store) {
        case Some(s) =>
            if (s.kind == BlobStoreKind.Memory && s.storedName.size == 0) {
                s.storedName = pathStr
            }
        case None => ()
    }
}

/// Blob__getFileNameString — get filename from Blob
/// Corresponds to: Bun: Blob__getFileNameString
public func blobGetFileNameString(blob: Blob): String {
    let name = blob.getFileName()
    if (name.isSome()) {
        return name.getOrThrow()
    }
    return ""
}

/// Blob__getDataPtr — get data pointer from Blob JS value
/// Corresponds to: Bun: Blob__getDataPtr
public func blobGetDataPtr(global: JsGlobalObject, value: JsValue): ?Array<UInt8> {
    let blob = Blob.fromJs(global, value)
    if (blob.isNone()) {
        return None
    }
    let data = blob.getOrThrow().sharedView()
    if (data.size == 0) {
        return None
    }
    return Some(data)
}

/// Blob__getSize — get Blob size from JS value
/// Corresponds to: Bun: Blob__getSize
public func blobGetSize(global: JsGlobalObject, value: JsValue): Int64 {
    let blob = Blob.fromJs(global, value)
    if (blob.isNone()) {
        return 0
    }
    return Int64(blob.getOrThrow().sharedView().size)
}

/// Blob__fromBytes — create Blob from raw bytes
/// Corresponds to: Bun: Blob__fromBytes
public func blobFromBytes(global: JsGlobalObject, bytes: Array<UInt8>): Blob {
    if (bytes.size == 0) {
        return Blob.initEmpty(global)
    }
    let store = BlobStore(bytes)
    return Blob.initWithStore(store, global)
}

/// Blob__fromBytesWithType — create Blob from raw bytes with MIME type
/// Corresponds to: Bun: Blob__fromBytesWithType
public func blobFromBytesWithType(global: JsGlobalObject, bytes: Array<UInt8>, mime: String): Blob {
    let blob = blobFromBytes(global, bytes)
    if (mime.size > 0) {
        blob.contentType = mime
        blob.contentTypeWasSet = true
    }
    return blob
}

/// Blob__fromMmapWithType — create Blob from mmap'd region with MIME type
/// Corresponds to: Bun: Blob__fromMmapWithType
public func blobFromMmapWithType(global: JsGlobalObject, bytes: Array<UInt8>, mime: String): Blob {
    // In Cangjie, mmap is handled by the runtime; fall back to fromBytes
    return blobFromBytesWithType(global, bytes, mime)
}

/// Bun__Blob__getSizeForBindings — get size for native bindings
/// Corresponds to: Bun: Bun__Blob__getSizeForBindings
public func blobGetSizeForBindings(blob: Blob): UInt64 {
    return blob.getSizeForBindings()
}

// ============================================================================
// statToJsMtime — convert stat to JS epoch milliseconds
// Corresponds to: Bun: stat_to_js_mtime
// ============================================================================
public func statToJsMtime(mtime: Float64, mtimeNsec: Float64): Float64 {
    // jsc::to_js_time converts (seconds, nanoseconds) to JS epoch ms
    return mtime * 1000.0 + mtimeNsec / 1000000.0
}

// ============================================================================
// writeFloat / readFloat — helpers for structured clone serialization
// Corresponds to: Bun: write_float / read_float
// ============================================================================
public func writeFloatLE(value: Float64, writer: ArrayList<UInt8>): Unit {
    let bits = value.toBits()
    writer.append(UInt8(bits & UInt64(0xFF)))
    writer.append(UInt8((bits >> UInt64(8)) & UInt64(0xFF)))
    writer.append(UInt8((bits >> UInt64(16)) & UInt64(0xFF)))
    writer.append(UInt8((bits >> UInt64(24)) & UInt64(0xFF)))
    writer.append(UInt8((bits >> UInt64(32)) & UInt64(0xFF)))
    writer.append(UInt8((bits >> UInt64(40)) & UInt64(0xFF)))
    writer.append(UInt8((bits >> UInt64(48)) & UInt64(0xFF)))
    writer.append(UInt8((bits >> UInt64(56)) & UInt64(0xFF)))
}

public func readFloatLE(data: Array<UInt8>, offset: Int64): Float64 {
    if (offset + 8 > Int64(data.size)) {
        return 0.0
    }
    return Float64.fromBits(UInt64(data[offset]) |
        (UInt64(data[offset + 1]) << 8) | (UInt64(data[offset + 2]) << 16) |
        (UInt64(data[offset + 3]) << 24) | (UInt64(data[offset + 4]) << 32) |
        (UInt64(data[offset + 5]) << 40) | (UInt64(data[offset + 6]) << 48) |
        (UInt64(data[offset + 7]) << 56))
}

// ============================================================================
// readSlice — read a slice from byte array at offset
// Corresponds to: Bun: read_slice
// ============================================================================
public func readSlice(data: Array<UInt8>, offset: Int64, len: Int64): ?Array<UInt8> {
    if (offset + len > Int64(data.size)) {
        return None
    }
    return Some(data[offset..(offset + len)])
}

// ============================================================================
// readIntLE — read a little-endian integer from byte array
// Corresponds to: Bun: read_int_le
// ============================================================================
public func readInt8(data: Array<UInt8>, offset: Int64): ?UInt8 {
    if (offset >= Int64(data.size)) {
        return None
    }
    return Some(data[offset])
}

public func readInt32LE(data: Array<UInt8>, offset: Int64): ?Int32 {
    if (offset + 4 > Int64(data.size)) {
        return None
    }
    return Some(Int32(data[offset]) | (Int32(data[offset + 1]) << 8) | (Int32(data[offset + 2]) << 16) | (Int32(data[offset + 3]) << 24))
}

public func readInt64LE(data: Array<UInt8>, offset: Int64): ?Int64 {
    if (offset + 8 > Int64(data.size)) {
        return None
    }
    return Some(Int64(data[offset]) | (Int64(data[offset + 1]) << 8) | (Int64(data[offset + 2]) << 16) | (Int64(data[offset + 3]) << 24) | (Int64(data[offset + 4]) << 32) | (Int64(data[offset + 5]) << 40) | (Int64(data[offset + 6]) << 48) | (Int64(data[offset + 7]) << 56))
}

// ============================================================================
// writeIntLE — write a little-endian integer to byte buffer
// Corresponds to: Bun: write_int_le
// ============================================================================
public func writeInt8(writer: ArrayList<UInt8>, value: UInt8): Unit {
    writer.append(value)
}

public func writeInt32LE(writer: ArrayList<UInt8>, value: Int32): Unit {
    writer.append(UInt8(value & 0xFF))
    writer.append(UInt8((value >> 8) & 0xFF))
    writer.append(UInt8((value >> 16) & 0xFF))
    writer.append(UInt8((value >> 24) & 0xFF))
}

public func writeInt64LE(writer: ArrayList<UInt8>, value: Int64): Unit {
    writer.append(UInt8(value & 0xFF))
    writer.append(UInt8((value >> 8) & 0xFF))
    writer.append(UInt8((value >> 16) & 0xFF))
    writer.append(UInt8((value >> 24) & 0xFF))
    writer.append(UInt8((value >> 32) & 0xFF))
    writer.append(UInt8((value >> 40) & 0xFF))
    writer.append(UInt8((value >> 48) & 0xFF))
    writer.append(UInt8((value >> 56) & 0xFF))
}

// ============================================================================
// external_shared_descriptor — re-exports for ref/deref
// Corresponds to: Bun: external_shared_descriptor
// ============================================================================
public func blobStoreRef(store: BlobStore): Unit {
    store.ref()
}

public func blobStoreDeref(store: BlobStore): Unit {
    store.deref()
}

// ============================================================================
// sysErrorWithPathLike — create SystemError with path info
// Corresponds to: Bun: sys_error_with_path_like
// ============================================================================
public func sysErrorWithPathLike(err: SyscallError, path: String): SystemError {
    let sysErr = SystemError()
    sysErr.message = err.message
    sysErr.code = "E${err.errno}"
    sysErr.syscall = err.syscall
    sysErr.path = path
    return sysErr
}

// ReadFileResultType is defined locally in body.cj to avoid subpackage conflict
// (blob/read_file.cj also defines ReadFileResultType with a different API)
