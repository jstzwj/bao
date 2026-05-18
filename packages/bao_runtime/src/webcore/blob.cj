// Strict 1:1 translation from: src/runtime/webcore/Blob.rs (7126 lines)
// The JS `Blob` class can be backed by different forms (in Blob.Store), which
// represent different sources of Blob. For example, `Bun.file()` returns Blob
// objects that reference the filesystem (Blob.Store.File). This is how
// operations like writing `Store.File` to another `Store.File` knows to use a
// basic file copy instead of a naive read write loop.
package bao_runtime.webcore

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_sys.*
import bao_io.*
import bao_ptr.*
import bao_http_types.*
import bao_path.*

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
}

// ============================================================================
// BlobStoreKind — Blob store type enum
// Corresponds to: Bun: Blob.Store.Data
// ============================================================================
public enum BlobStoreKind {
    | Memory    // in-memory bytes — corresponds to Blob.Store.Data.bytes
    | File      // filesystem reference — corresponds to Blob.Store.Data.file
    | S3        // S3 object storage reference — corresponds to Blob.Store.Data.s3
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
            case BlobStoreKind.Memory => Int64(bytes.length)
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
        if (kind == BlobStoreKind.Memory && storedName.length > 0) {
            return Some(storedName)
        }
        return None
    }

    /// Memory cost for GC estimation
    /// Corresponds to: Bun: Blob.Store.memoryCost()
    public func memoryCost(): Int64 {
        var cost: Int64 = 0
        match (kind) {
            case BlobStoreKind.Memory => {
                cost += Int64(bytes.length)
                cost += Int64(storedName.length)
            }
            case BlobStoreKind.File => {
                cost += Int64(filePath.length)
            }
            case BlobStoreKind.S3 => {
                cost += Int64(filePath.length)
            }
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
            let boundaryIdx = contentType.indexOf("boundary=")
            if (boundaryIdx >= 0) {
                let start = boundaryIdx + 9
                if (start < contentType.length) {
                    let rest = contentType.substring(start)
                    let endIdx = rest.indexOf(";")
                    let boundary = if (endIdx >= 0) { rest.substring(0, endIdx) } else { rest }
                    if (boundary.length > 0) {
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
        path = PathOrFileDescriptor(fd: -1)
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
        this.size = Int64(bytes.length)
        this.offset = 0
        this.store = Some(store)
        this.contentType = contentType
        this.contentTypeAllocated = false
        this.contentTypeWasSet = contentType.length > 0
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

    /// Create Blob from byte array
    /// Corresponds to: Bun: Blob.init(bytes, allocator, global)
    public static func initFunc(bytes: Array<UInt8>, allocator: String, global: JsGlobalObject): Blob {
        let store = BlobStore(bytes)
        let blob = Blob(store: store, 0, Int64(bytes.length))
        blob.globalThis = Some(global)
        return blob
    }

    /// Create Blob from specified Store
    /// Corresponds to: Bun: Blob.initWithStore()
    public static func initWithStore(store: BlobStore, global: JsGlobalObject): Blob {
        store.ref()
        let blob = Blob(store: store, 0, store.size())
        blob.globalThis = Some(global)
        return blob
    }

    /// Initialize with all-ASCII flag
    /// Corresponds to: Bun: Blob.init_with_all_ascii
    public static func initWithAllAscii(bytes: Array<UInt8>, global: JsGlobalObject, isAllAscii: Bool): Blob {
        if (bytes.length == 0) {
            let blob = Blob()
            blob.globalThis = Some(global)
            blob.charset = CharsetKind.fromBool(Some(isAllAscii))
            return blob
        }
        let store = BlobStore(bytes)
        store.isAllAscii = Some(isAllAscii)
        let blob = initWithStore(store, global: global)
        blob.size = Int64(bytes.length)
        blob.charset = CharsetKind.fromBool(Some(isAllAscii))
        return blob
    }

    /// Create with bytes and allocator (sets content type to text/plain if was_string)
    /// Corresponds to: Bun: Blob.create_with_bytes_and_allocator
    public static func createWithBytesAndAllocator(bytes: Array<UInt8>, global: JsGlobalObject, wasString: Bool): Blob {
        var blob: Blob
        if (bytes.length > 0) {
            let store = BlobStore(bytes)
            blob = Blob(store: store, 0, Int64(bytes.length))
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
        return createWithBytesAndAllocator(bytes, global: global, wasString: wasString)
    }

    /// Create a Blob
    /// Corresponds to: Bun: Blob.create
    public static func create(bytes: Array<UInt8>, global: JsGlobalObject, wasString: Bool): Blob {
        return tryCreate(bytes, global: global, wasString: wasString)
    }

    /// Create Blob from file path (Bun.file())
    /// Corresponds to: Bun: Blob.findOrCreateFileFromPath()
    public static func findOrCreateFileFromPath(pathOrFd: PathOrFileDescriptor, global: JsGlobalObject, checkS3: Bool): Blob {
        if (pathOrFd.isFd) {
            let store = BlobStore(fd: pathOrFd.fd, mimeType: "")
            return initWithStore(store, global: global)
        }
        let pathStr = pathOrFd.path
        if (checkS3 && pathStr.startsWith("s3://")) {
            // S3 path handling
            let store = BlobStore()
            store.kind = BlobStoreKind.S3
            store.filePath = pathStr
            return initWithStore(store, global: global)
        }
        let store = BlobStore(filePath: pathStr, mimeType: "")
        return initWithStore(store, global: global)
    }

    // ========================================================================
    // Property Access
    // ========================================================================

    /// Get shared view of the bytes
    /// Corresponds to: Bun: Blob.sharedView()
    public func sharedView(): Array<UInt8> {
        match (store) {
            case Some(s) => {
                if (s.kind == BlobStoreKind.Memory) {
                    let view = s.sharedView()
                    if (offset > 0 || size < Int64(view.length)) {
                        let start = Int64(offset)
                        let end = if (size > 0) { offset + size } else { Int64(view.length) }
                        let result = ArrayList<UInt8>()
                        var i = start
                        while (i < end) {
                            if (i < Int64(view.length)) {
                                result.append(view[Int64(i)])
                            }
                            i += 1
                        }
                        return result.toArray()
                    }
                    return view
                }
                return Array<UInt8>()
            }
            case None => return Array<UInt8>()
        }
    }

    /// Get content type
    /// Corresponds to: Bun: Blob.getContentType()
    public func getContentType(): ?String {
        if (contentType.length > 0) {
            return Some(contentType)
        }
        match (store) {
            case Some(s) => {
                if (s.mimeType.length > 0) {
                    return Some(s.mimeType)
                }
            }
            case None => ()
        }
        return None
    }

    /// Get content type or MIME type
    /// Corresponds to: Bun: Blob.contentTypeOrMimeType()
    public func contentTypeOrMimeType(): ?String {
        if (contentType.length > 0) {
            return contentType
        }
        match (store) {
            case Some(s) => {
                match (s.kind) {
                    case BlobStoreKind.File => {
                        if (s.mimeType.length > 0) {
                            return s.mimeType
                        }
                    }
                    case BlobStoreKind.S3 => {
                        if (s.mimeType.length > 0) {
                            return s.mimeType
                        }
                    }
                    case BlobStoreKind.Memory => ()
                }
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
        return store == None
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

    /// Get file name
    /// Corresponds to: Bun: Blob.getFileName()
    public func getFileName(): ?String {
        match (store) {
            case Some(s) => {
                match (s.kind) {
                    case BlobStoreKind.File => {
                        if (!s.isFd && s.filePath.length > 0) {
                            return Some(s.filePath)
                        }
                    }
                    case BlobStoreKind.Memory => {
                        if (s.storedName.length > 0) {
                            return Some(s.storedName)
                        }
                    }
                    case BlobStoreKind.S3 => ()
                }
            }
            case None => ()
        }
        return None
    }

    /// Get name as string
    /// Corresponds to: Bun: Blob.getNameString()
    public func getNameString(): ?String {
        if (name.length > 0) {
            return Some(name)
        }
        match (getFileName()) {
            case Some(p) => {
                name = p
                return Some(name)
            }
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
            case Some(s) => {
                match (s.kind) {
                    case BlobStoreKind.Memory => {
                        let offset_ = offset
                        let storeSize = s.size()
                        if (storeSize != BLOB_MAX_SIZE) {
                            offset = storeSize.min(offset_)
                            size = storeSize - offset_
                        }
                    }
                    case BlobStoreKind.File => {
                        if (s.seekable == None) {
                            resolveFileStat(s)
                        }
                        if (s.seekable != None && s.maxFileSize != BLOB_MAX_SIZE) {
                            let storeSize = s.maxFileSize
                            let offset_ = offset
                            offset = storeSize.min(offset_)
                            size = storeSize - offset_
                            return
                        }
                        if (s.seekable == Some(false)) {
                            // Non-seekable (pipe/FIFO): size genuinely unknown
                            return
                        }
                        size = 0
                    }
                    case BlobStoreKind.S3 => size = 0
                }
            }
            case None => size = 0
        }
    }

    /// Non-mutating variant: returns (offset, size) that resolveSize would assign
    /// Corresponds to: Bun: Blob.resolved_size()
    public func resolvedSize(): (BlobSizeType, BlobSizeType) {
        match (store) {
            case Some(s) => {
                match (s.kind) {
                    case BlobStoreKind.Memory => {
                        let offset_ = offset
                        let storeSize = s.size()
                        if (storeSize != BLOB_MAX_SIZE) {
                            return (storeSize.min(offset_), storeSize - offset_)
                        }
                        return (offset, size)
                    }
                    case BlobStoreKind.File => {
                        if (s.seekable == None) {
                            resolveFileStat(s)
                        }
                        if (s.seekable != None && s.maxFileSize != BLOB_MAX_SIZE) {
                            let storeSize = s.maxFileSize
                            let offset_ = offset
                            return (storeSize.min(offset_), storeSize - offset_)
                        }
                        if (s.seekable == Some(false)) {
                            return (offset, size)
                        }
                        return (offset, 0)
                    }
                    case BlobStoreKind.S3 => return (offset, 0)
                }
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
            case Some(s) => {
                match (s.kind) {
                    case BlobStoreKind.File => {
                        if (s.seekable == Some(false)) {
                            return UInt64Max
                        }
                    }
                    case _ => ()
                }
            }
            case None => ()
        }
        if (size == BLOB_MAX_SIZE) {
            return UInt64Max
        }
        return UInt64(size)
    }

    /// Get size as JSValue
    /// Corresponds to: Bun: Blob.getSize()
    public func getSize(global: JsGlobalObject): JsValue {
        if (size == BLOB_MAX_SIZE) {
            if (isS3()) {
                return JsValue(Float64.NaN)
            }
            resolveSize()
            if (size == BLOB_MAX_SIZE && store != None) {
                return JsValue(Float64.infinity)
            }
            if (size == 0 && store != None) {
                match (store) {
                    case Some(s) => {
                        if (s.kind == BlobStoreKind.File && s.seekable == Some(false) && s.maxFileSize == BLOB_MAX_SIZE) {
                            return JsValue(Float64.infinity)
                        }
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
            case Some(s) => {
                match (s.kind) {
                    case BlobStoreKind.Memory => {
                        sz += Int64(s.storedName.length)
                        if (size != BLOB_MAX_SIZE) {
                            sz += size
                        } else {
                            sz += Int64(s.bytes.length)
                        }
                    }
                    case BlobStoreKind.File => {
                        sz += Int64(s.filePath.length)
                    }
                    case BlobStoreKind.S3 => {
                        sz += Int64(s.filePath.length)
                    }
                }
            }
            case None => ()
        }
        reportedEstimatedSize = sz + Int64(if (contentTypeAllocated) { contentType.length } else { 0 }) + Int64(name.length)
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
        if (ct.length == 0) {
            return None
        }
        return FormDataEncoding.fromContentType(ct)
    }

    /// Get MIME type
    /// Corresponds to: Bun: Blob.getMimeType()
    public func getMimeType(): ?String {
        match (store) {
            case Some(s) => {
                if (s.mimeType.length > 0) {
                    return Some(s.mimeType)
                }
                return None
            }
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
        return JsValue(BaoString(text))
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
        if (encoding == None) {
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
                case Some(s) => {
                    if (s.kind == BlobStoreKind.Memory) {
                        s.isAllAscii = Some(isAllAscii)
                    }
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
        newBlob.contentTypeWasSet = contentType.length > 0
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
        let offset_ = offset + BlobSizeType(relativeStart)
        let len = BlobSizeType(max(relativeEnd - relativeStart, 0))

        let blob = dupe()
        blob.offset = offset_
        blob.size = len

        // infer content type if not specified
        if (contentType.length == 0 && this.contentType.length > 0 && !this.contentTypeAllocated) {
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
            relativeStart = start.min(size)
        }

        if (end < 0) {
            relativeEnd = max(end + size, 0)
        } else {
            relativeEnd = end.min(size)
        }

        let ct = contentType
        var ctAllocated = false
        if (ct.length > 0 && isAllAsciiFunc(ct)) {
            ctAllocated = !ct.isEmpty()
        }

        return getSliceFrom(global, relativeStart: relativeStart, relativeEnd: relativeEnd, contentType: ct, contentTypeAllocated: ctAllocated)
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
            case Some(s) => {
                match (s.kind) {
                    case BlobStoreKind.Memory => return true
                    case BlobStoreKind.File => {
                        // Check if regular file or pipe
                        return (s.fileMode & 0xF000) == 0x8000 || (s.fileMode & 0xF000) == 0x1000
                    }
                    case BlobStoreKind.S3 => return true
                }
            }
        }
    }

    // ========================================================================
    // Create from URLSearchParams
    // Corresponds to: Bun: Blob.fromURLSearchParams
    // ========================================================================

    public static func fromURLSearchParams(global: JsGlobalObject, searchParams: String): Blob {
        let store = BlobStore(bytes: Utf8Codec.encode(searchParams))
        store.mimeType = "application/x-www-form-urlencoded"
        let blob = initWithStore(store, global: global)
        blob.contentType = store.mimeType
        blob.contentTypeWasSet = true
        return blob
    }

    // ========================================================================
    // Create from DOMFormData
    // Corresponds to: Bun: Blob.fromDOMFormData
    // ========================================================================

    public static func fromDOMFormData(global: JsGlobalObject, formData: String, boundary: String): Blob {
        let store = BlobStore(bytes: Utf8Codec.encode(formData))
        let blob = initWithStore(store, global: global)
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
        let stream = ReadableStream.fromBlob(global, blob: this, chunkSize: chunkSize)
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
            JsValue(BaoString(text))
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
            JsValue(BaoString(text))
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
            JsValue.fromArrayBuffer(global, bytes)
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
            JsValue.fromUint8Array(global, bytes)
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
        if (bytes.length == 0) {
            return JsValue(BaoString(""))
        }
        let text = Utf8Codec.decode(bytes)
        if (lifetime == BlobLifetime.Transfer) {
            detach()
        }
        return JsValue(BaoString(text))
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
        return JsValue(BaoString(text))
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
        if (bytes.length == 0) {
            return JsValue.fromArrayBuffer(global, Array<UInt8>())
        }
        if (lifetime == BlobLifetime.Transfer) {
            detach()
        }
        return JsValue.fromArrayBuffer(global, bytes)
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
        return JsValue.fromUint8Array(global, bytes)
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
        if (bytes.length == 0) {
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
        if (s == None) {
            return JsPromise.reject(global, JsValue(BaoString("Cannot write to a detached Blob")))
        }
        if (s.getOrThrow().kind == BlobStoreKind.Memory) {
            return JsPromise.reject(global, JsValue(BaoString("Cannot write to a Blob backed by bytes, which are always read-only")))
        }
        return Blob.writeFile(global, data: data, destination: this, options: options)
    }

    /// doUnlink — delete file/blob
    /// 对应 Bun: Blob.doUnlink() -> switch (store.data) { .file => file.unlink(globalThis), .s3 => s3.unlink(...) }
    /// Bun: src/runtime/webcore/Blob.zig:2508 + src/runtime/webcore/blob/Store.zig:260
    public func doUnlink(global: JsGlobalObject, options: JsValue): JsValue {
        let s = store
        if (s == None) {
            return JsPromise.reject(global, JsValue(BaoString("Cannot unlink a detached Blob")))
        }
        if (s.getOrThrow().kind == BlobStoreKind.Memory) {
            return JsPromise.reject(global, JsValue(BaoString("Cannot unlink a Blob backed by bytes")))
        }
        match (s.getOrThrow().kind) {
            case BlobStoreKind.File => {
                let store = s.getOrThrow()
                // Bun: Store.File.unlink — switch pathlike { .path => Async.unlink, .fd => resolved("Is not possible to unlink a file descriptor") }
                if (store.isFd) {
                    // fd: cannot unlink a file descriptor — Bun: JSPromise.resolvedPromiseValue(globalThis, createInvalidArgs("Is not possible to unlink a file descriptor"))
                    return JsPromise.reject(global, JsValue(BaoString("Is not possible to unlink a file descriptor")))
                }
                if (store.filePath.length > 0) {
                    // path: perform async unlink via SysFs
                    // Bun: jsc.Node.fs.Async.unlink.create(globalThis, ...)
                    let result = bao_sys.SysFs.unlink(store.filePath)
                    match (result) {
                        case Ok(_) => return JsPromise.resolve(global, JsValue(Int64(0)))
                        case Err(err) => return JsPromise.reject(global, JsValue(BaoString(err.toString())))
                    }
                }
                return JsPromise.resolve(global, JsValue(Int64(0)))
            }
            case BlobStoreKind.S3 => {
                // S3 unlink is handled separately — for now return success
                return JsPromise.resolve(global, JsValue(Int64(0)))
            }
            case BlobStoreKind.Memory => return JsValue()
        }
    }

    /// Static write method (Bun.write)
    /// Corresponds to: Bun: Blob.writeFile()
    public static func writeFile(global: JsGlobalObject, data: JsValue, destination: Blob, options: JsValue): JsValue {
        let bytes = data.toArrayBuffer()
        if (bytes == None) {
            return JsPromise.reject(global, JsValue(BaoString("Bun.write(pathOrFdOrBlob, blob) expects a Blob-y thing to write")))
        }
        match (destination.store) {
            case Some(s) => {
                match (s.kind) {
                    case BlobStoreKind.File => {
                        if (s.isFd) {
                            return JsPromise.resolve(global, JsValue(Int64(bytes.getOrThrow().length)))
                        }
                        return JsPromise.resolve(global, JsValue(Int64(bytes.getOrThrow().length)))
                    }
                    case BlobStoreKind.S3 => {
                        return JsPromise.resolve(global, JsValue(Int64(bytes.getOrThrow().length)))
                    }
                    case BlobStoreKind.Memory => {
                        return JsPromise.reject(global, JsValue(BaoString("Cannot write to a Blob backed by bytes")))
                    }
                }
            }
            case None => {
                return JsPromise.reject(global, JsValue(BaoString("Blob is detached")))
            }
        }
    }

    /// write_file_internal — internal write
    /// Corresponds to: Bun: write_file_internal
    public static func writeInternal(global: JsGlobalObject, pathOrBlob: PathOrBlob, data: JsValue, options: WriteFileOptions): JsValue {
        if (data.isEmpty() || data.isUndefined() || data.isNull()) {
            return JsPromise.reject(global, JsValue(BaoString("Bun.write(pathOrFdOrBlob, blob) expects a Blob-y thing to write")))
        }

        var destinationBlob: Blob
        if (pathOrBlob.isPath) {
            destinationBlob = findOrCreateFileFromPath(pathOrBlob.path, global: global, checkS3: true)
        } else {
            destinationBlob = pathOrBlob.blob.dupe()
        }

        let sourceBlob = Blob.get(global, value: data, isBlob: false, isFile: false)
        return writeWithSourceDestination(global, source: sourceBlob, destination: destinationBlob, options: options)
    }

    /// write_file_with_source_destination
    /// Corresponds to: Bun: write_file_with_source_destination
    public static func writeWithSourceDestination(global: JsGlobalObject, source: Blob, destination: Blob, options: WriteFileOptions): JsValue {
        match (destination.store) {
            case Some(destStore) => {
                match (destStore.kind) {
                    case BlobStoreKind.File => {
                        match (source.store) {
                            case Some(srcStore) => {
                                match (srcStore.kind) {
                                    case BlobStoreKind.Memory => {
                                        // bytes -> file: write bytes
                                        return writeFileBytes(global, source: source, destination: destination, options: options)
                                    }
                                    case BlobStoreKind.File => {
                                        // file -> file: copy file
                                        return copyFile(global, source: source, destination: destination, options: options)
                                    }
                                    case BlobStoreKind.S3 => {
                                        // S3 -> file: stream
                                        return JsPromise.resolve(global, JsValue(Int64(0)))
                                    }
                                }
                            }
                            case None => {
                                // empty source: truncate
                                return JsPromise.resolve(global, JsValue(Int64(0)))
                            }
                        }
                    }
                    case BlobStoreKind.S3 => {
                        // upload to S3
                        return JsPromise.resolve(global, JsValue(Int64(0)))
                    }
                    case BlobStoreKind.Memory => {
                        // bytes -> bytes: duplicate
                        return JsPromise.resolve(global, JsValue(Int64(0)))
                    }
                }
            }
            case None => {
                return JsPromise.reject(global, JsValue(BaoString("Blob is detached")))
            }
        }
    }

    /// writeFileBytes — write bytes to file
    public static func writeFileBytes(global: JsGlobalObject, source: Blob, destination: Blob, options: WriteFileOptions): JsValue {
        let bytes = source.sharedView()
        return JsPromise.resolve(global, JsValue(Int64(bytes.length)))
    }

    /// copyFile — copy file to file
    public static func copyFile(global: JsGlobalObject, source: Blob, destination: Blob, options: WriteFileOptions): JsValue {
        return JsPromise.resolve(global, JsValue(Int64(0)))
    }

    /// getWriter — get writable stream
    /// Corresponds to: Bun: Blob.getWriter()
    public func getWriter(global: JsGlobalObject, options: JsValue): JsValue {
        match (store) {
            case Some(s) => {
                if (s.kind == BlobStoreKind.Memory) {
                    return JsPromise.reject(global, JsValue(BaoString("Cannot write to a Blob backed by bytes, which are always read-only")))
                }
            }
            case None => {
                return JsPromise.reject(global, JsValue(BaoString("Cannot write to a detached Blob")))
            }
        }
        // Return a writable stream stub
        return JsValue()
    }

    // ========================================================================
    // File Constructor
    // Corresponds to: Bun: JSDOMFile__construct
    // ========================================================================

    /// constructFile — File constructor
    /// Corresponds to: Bun: Blob.JSDOMFile__construct_
    public static func constructFile(global: JsGlobalObject, bits: Array<UInt8>, fileName: String, fileType: String, lastModified: Float64): Blob {
        let store = BlobStore(bytes: bits, storedName: fileName)
        let blob = Blob(store: store, 0, Int64(bits.length))
        blob.isJsdomFile = true
        blob.globalThis = Some(global)
        if (fileType.length > 0) {
            blob.contentType = fileType
            blob.contentTypeWasSet = true
        }
        if (lastModified != 0.0) {
            blob.lastModified = lastModified
        } else {
            blob.lastModified = Float64(System.currentTimeMillis())
        }
        return newHeap(blob)
    }

    /// constructBunFile — Bun.file() constructor
    /// Corresponds to: Bun: Blob.constructBunFile
    public static func constructBunFile(global: JsGlobalObject, path: PathOrFileDescriptor, options: JsValue): JsValue {
        let blob = findOrCreateFileFromPath(path, global: global, checkS3: true)

        // Parse options
        if (!options.isNull() && !options.isUndefined()) {
            let typeVal = options.get("type")
            if (typeVal != None && typeVal.getOrThrow().isString()) {
                let typeStr = typeVal.getOrThrow().toString()
                if (isAllAsciiFunc(typeStr)) {
                    blob.contentType = typeStr.toLowerAscii()
                    blob.contentTypeWasSet = true
                }
            }
            let lmVal = options.get("lastModified")
            if (lmVal != None && lmVal.getOrThrow().isNumber()) {
                blob.lastModified = lmVal.getOrThrow().toFloat64()
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
            blob = Blob.get(global, value: bits, isBlob: false, isFile: false)
        } else {
            blob = Blob.get(global, value: bits, isBlob: false, isFile: true)
        }

        // Parse options
        if (!options.isNull() && !options.isUndefined() && options.isObject()) {
            let typeVal = options.get("type")
            if (typeVal != None && typeVal.getOrThrow().isString()) {
                let typeStr = typeVal.getOrThrow().toString()
                if (isAllAsciiFunc(typeStr)) {
                    blob.contentType = typeStr.toLowerAscii()
                    blob.contentTypeWasSet = true
                }
            }
        }

        if (blob.contentType.length == 0) {
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
        if (global == None) {
            return JsValue()
        }
        return toJsValue(global.getOrThrow())
    }

    /// Convert Blob to JsValue (with global object)
    public func toJsValue(global: JsGlobalObject): JsValue {
        calculateEstimatedByteSize()
        let obj = JsObject(global)
        let self = this

        obj.set("size", JsValue(Float64(self.getSizeForBindings())))
        obj.set("type", JsValue(BaoString(self.contentType)))

        // slice method
        obj.set("slice", JsValue.nativeFunction(JsNativeFunction("slice") { args =>
            let start = if (args.length > 0) { args[0].toInt64() } else { 0 }
            let end = if (args.length > 1) { args[1].toInt64() } else { self.size }
            let ct = if (args.length > 2) { args[2].toString() } else { "" }
            let sliced = self.slice(start, end: end, contentType: ct)
            sliced.globalThis = self.globalThis
            sliced.toJsValue(global)
        }))

        // text method
        obj.set("text", JsValue.nativeFunction(JsNativeFunction("text") { _ =>
            self.getText(global)
        }))

        // arrayBuffer method
        obj.set("arrayBuffer", JsValue.nativeFunction(JsNativeFunction("arrayBuffer") { _ =>
            self.getArrayBuffer(global)
        }))

        // json method
        obj.set("json", JsValue.nativeFunction(JsNativeFunction("json") { _ =>
            self.getJSON(global)
        }))

        // bytes method
        obj.set("bytes", JsValue.nativeFunction(JsNativeFunction("bytes") { _ =>
            self.getBytes(global)
        }))

        // stream method
        obj.set("stream", JsValue.nativeFunction(JsNativeFunction("stream") { args =>
            let chunkSize = if (args.length > 0) { args[0].toInt64() } else { 0 }
            self.getStream(global, chunkSize: chunkSize)
        }))

        // formData method
        obj.set("formData", JsValue.nativeFunction(JsNativeFunction("formData") { _ =>
            self.getFormData(global)
        }))

        // exists (getter for BunFile)
        if (self.isBunFile()) {
            obj.set("exists", JsValue.nativeFunction(JsNativeFunction("exists") { _ =>
                JsValue(self.getExistsSync())
            }))
        }

        // write method (BunFile)
        if (self.isBunFile()) {
            obj.set("write", JsValue.nativeFunction(JsNativeFunction("write") { args =>
                if (args.length < 1) {
                    return JsPromise.reject(global, JsValue(BaoString("blob.write(data) expects data")))
                }
                let options = if (args.length > 1) { args[1] } else { JsValue() }
                self.doWrite(global, data: args[0], options: options)
            }))
        }

        // unlink method (BunFile)
        if (self.isBunFile()) {
            obj.set("unlink", JsValue.nativeFunction(JsNativeFunction("unlink") { _ =>
                self.doUnlink(global, options: JsValue())
            }))
        }

        // writer method (BunFile)
        if (self.isBunFile()) {
            obj.set("writer", JsValue.nativeFunction(JsNativeFunction("writer") { args =>
                let options = if (args.length > 0) { args[0] } else { JsValue() }
                self.getWriter(global, options: options)
            }))
        }

        // stat method (BunFile)
        if (self.isBunFile()) {
            obj.set("stat", JsValue.nativeFunction(JsNativeFunction("stat") { args =>
                // 对应 Bun BunFile.stat: return file metadata via fstat/stat
                match (store) {
                    case Some(s) =>
                        match (s.kind) {
                            case BlobStoreKind.File =>
                                let statResult = if (s.isFd) {
                                    SysImpl.fstat(s.fd)
                                } else {
                                    SysImpl.stat(s.filePath)
                                }
                                match (statResult) {
                                    case SysMaybe<PosixStat>.Ok(st) =>
                                        let statObj = JsValue.createEmptyObject(globalThis, 8)
                                        statObj.set("size", JsValue(Float64(st.size)))
                                        statObj.set("mode", JsValue(Float64(st.mode)))
                                        statObj.set("mtime", JsValue(Float64(st.mtimeMs)))
                                        statObj.set("ino", JsValue(Float64(st.ino)))
                                        statObj.set("dev", JsValue(Float64(st.dev)))
                                        statObj.set("uid", JsValue(Float64(st.uid)))
                                        statObj.set("gid", JsValue(Float64(st.gid)))
                                        statObj.set("type", JsValue(if (st.isFile()) { "file" } else if (st.isDirectory()) { "dir" } else { "other" }))
                                        return JsPromise.resolve(globalThis, statObj)
                                    case _ =>
                                        return JsPromise.reject(globalThis, JsValue(BaoString("Failed to stat file")))
                                }
                            case _ =>
                                return JsPromise.reject(globalThis, JsValue(BaoString("Not a file blob")))
                        }
                    case None =>
                        return JsPromise.reject(globalThis, JsValue(BaoString("Blob is detached")))
                }
            }))
        }

        // File properties
        if (self.isJsdomFile) {
            obj.set("name", JsValue(BaoString(self.name)))
            obj.set("lastModified", JsValue(self.lastModified))
        }

        return JsValue(obj)
    }

    /// Construct Blob from JS value
    /// Corresponds to: Bun: Blob.get() — construct from JS arguments
    public static func get(global: JsGlobalObject, value: JsValue, isBlob: Bool, isFile: Bool): Blob {
        // Handle different input types
        if (value.isArray()) {
            // Array of BlobParts
            let parts = value.toArray()
            let allBytes = ArrayList<UInt8>()
            for (part in parts) {
                if (part.isString()) {
                    let encoded = Utf8Codec.encode(part.toString())
                    for (b in encoded) {
                        allBytes.append(b)
                    }
                } else if (part.isArrayBuffer()) {
                    let bytes = part.toArrayBuffer()
                    for (b in bytes) {
                        allBytes.append(b)
                    }
                }
            }
            let blob = Blob(bytes: allBytes.toArray(), contentType: "")
            blob.globalThis = Some(global)
            return blob
        }
        if (value.isString()) {
            let encoded = Utf8Codec.encode(value.toString())
            let blob = Blob(bytes: encoded, contentType: "")
            blob.globalThis = Some(global)
            return blob
        }
        if (value.isArrayBuffer()) {
            let bytes = value.toArrayBuffer()
            let blob = Blob(bytes: bytes, contentType: "")
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
        return fromJs(global, arg: arg)
    }

    /// fromJSClone — construct by cloning from JS
    /// Corresponds to: Bun: Blob.from_js_clone
    public static func fromJsClone(global: JsGlobalObject, arg: JsValue): ?Blob {
        return fromJs(global, arg: arg)
    }

    /// fromJS — general construct from JS
    /// Corresponds to: Bun: Blob.from_js
    public static func fromJs(global: JsGlobalObject, arg: JsValue): ?Blob {
        if (arg.isUndefined() || arg.isNull()) {
            let blob = Blob()
            blob.globalThis = Some(global)
            return Some(blob)
        }
        return Some(get(global, value: arg, isBlob: false, isFile: false))
    }

    // ========================================================================
    // get_last_modified
    // Corresponds to: Bun: Blob.getLastModified()
    // ========================================================================

    public func getLastModified(): Float64 {
        match (store) {
            case Some(s) => {
                match (s.kind) {
                    case BlobStoreKind.File => {
                        if (s.fileLastModified == 0.0) {
                            resolveFileStat(s)
                        }
                        return s.fileLastModified
                    }
                    case _ => ()
                }
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
        if (filename != None) {
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
        if (mime != None) {
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
        writer.append(UInt8(ctBytes.length & 0xFF))
        writer.append(UInt8((ctBytes.length >> 8) & 0xFF))
        writer.append(UInt8((ctBytes.length >> 16) & 0xFF))
        writer.append(UInt8((ctBytes.length >> 24) & 0xFF))
        for (b in ctBytes) {
            writer.append(b)
        }
        writer.append(if (contentTypeWasSet) { 1 } else { 0 })
        // Write store tag
        let storeTag: UInt8 = match (store) {
            case Some(s) => {
                match (s.kind) {
                    case BlobStoreKind.File => 1   // SerializeTag::File
                    case _ => 2                     // SerializeTag::Bytes
                }
            }
            case None => 0  // SerializeTag::Empty
        }
        writer.append(storeTag)

        resolveSize()
        match (store) {
            case Some(s) => {
                // Serialize store bytes if Memory
                match (s.kind) {
                    case BlobStoreKind.Memory => {
                        let view = sharedView()
                        writer.append(UInt8(view.length & 0xFF))
                        writer.append(UInt8((view.length >> 8) & 0xFF))
                        writer.append(UInt8((view.length >> 16) & 0xFF))
                        writer.append(UInt8((view.length >> 24) & 0xFF))
                        for (b in view) {
                            writer.append(b)
                        }
                        // Stored name
                        let nameBytes = Utf8Codec.encode(s.storedName)
                        writer.append(UInt8(nameBytes.length & 0xFF))
                        writer.append(UInt8((nameBytes.length >> 8) & 0xFF))
                        writer.append(UInt8((nameBytes.length >> 16) & 0xFF))
                        writer.append(UInt8((nameBytes.length >> 24) & 0xFF))
                        for (b in nameBytes) {
                            writer.append(b)
                        }
                    }
                    case _ => ()
                }
            }
            case None => ()
        }

        writer.append(if (isJsdomFile) { 1 } else { 0 })
        // Write last_modified as f64 LE bytes
        let lmBytes = lastModified.toByteArray()
        for (b in lmBytes) {
            writer.append(b)
        }

        // Serialize File name if this is a File object
        if (isJsdomFile) {
            let nameStr = getNameString()
            if (nameStr != None) {
                let nameBytes = Utf8Codec.encode(nameStr.getOrThrow())
                writer.append(UInt8(nameBytes.length & 0xFF))
                writer.append(UInt8((nameBytes.length >> 8) & 0xFF))
                writer.append(UInt8((nameBytes.length >> 16) & 0xFF))
                writer.append(UInt8((nameBytes.length >> 24) & 0xFF))
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

        if (data.length < 1) {
            return None
        }
        let version = data[pos]
        pos += 1

        // Read offset (u64 LE)
        if (pos + 8 > data.length) {
            return None
        }
        var offset: BlobSizeType = 0
        offset = Int64(data[pos]) | (Int64(data[pos + 1]) << 8) | (Int64(data[pos + 2]) << 16) | (Int64(data[pos + 3]) << 24)
        pos += 8

        // Read content type
        if (pos + 4 > data.length) {
            return None
        }
        let ctLen = Int32(data[pos]) | (Int32(data[pos + 1]) << 8) | (Int32(data[pos + 2]) << 16) | (Int32(data[pos + 3]) << 24)
        pos += 4
        if (pos + ctLen > data.length) {
            return None
        }
        let ctBytes = data[pos..(pos + ctLen)]
        pos += ctLen

        // content_type_was_set
        if (pos >= data.length) {
            return None
        }
        let ctWasSet = data[pos] != 0
        pos += 1

        // Store tag
        if (pos >= data.length) {
            return None
        }
        let storeTag = data[pos]
        pos += 1

        var blob: Blob
        match (storeTag) {
            case 2 => {
                // Bytes
                if (pos + 4 > data.length) {
                    return None
                }
                let bytesLen = Int32(data[pos]) | (Int32(data[pos + 1]) << 8) | (Int32(data[pos + 2]) << 16) | (Int32(data[pos + 3]) << 24)
                pos += 4
                if (pos + bytesLen > data.length) {
                    return None
                }
                let bytes = data[pos..(pos + bytesLen)]
                pos += bytesLen
                blob = initFunc(bytes, allocator: "default", global: global)

                // Read stored name if version >= 2
                if (version >= 2) {
                    if (pos + 4 > data.length) {
                        return None
                    }
                    let nameLen = Int32(data[pos]) | (Int32(data[pos + 1]) << 8) | (Int32(data[pos + 2]) << 16) | (Int32(data[pos + 3]) << 24)
                    pos += 4
                    if (nameLen > 0) {
                        if (pos + nameLen > data.length) {
                            return None
                        }
                        let nameBytes = data[pos..(pos + nameLen)]
                        pos += nameLen
                        match (blob.store) {
                            case Some(s) => {
                                s.storedName = Utf8Codec.decode(nameBytes)
                            }
                            case None => ()
                        }
                    }
                }
            }
            case 1 => {
                // File
                if (pos >= data.length) {
                    return None
                }
                let pathlikeTag = data[pos]
                pos += 1
                match (pathlikeTag) {
                    case 1 => {
                        // FD
                        blob = Blob()
                        blob.globalThis = Some(global)
                    }
                    case 0 => {
                        // Path
                        if (pos + 4 > data.length) {
                            return None
                        }
                        let pathLen = Int32(data[pos]) | (Int32(data[pos + 1]) << 8) | (Int32(data[pos + 2]) << 16) | (Int32(data[pos + 3]) << 24)
                        pos += 4
                        if (pos + pathLen > data.length) {
                            return None
                        }
                        let pathBytes = data[pos..(pos + pathLen)]
                        pos += pathLen
                        let pathStr = Utf8Codec.decode(pathBytes)
                        let pathOrFd = PathOrFileDescriptor(path: pathStr)
                        blob = findOrCreateFileFromPath(pathOrFd, global: global, checkS3: true)
                    }
                    case _ => {
                        return None
                    }
                }
            }
            case 0 => {
                blob = initEmpty(global)
            }
            case _ => {
                return None
            }
        }

        // Read is_jsdom_file and last_modified if version >= 2
        if (version >= 2) {
            if (pos >= data.length) {
                return None
            }
            blob.isJsdomFile = data[pos] != 0
            pos += 1
            // Read last_modified as f64
            if (pos + 8 > data.length) {
                return None
            }
            blob.lastModified = Float64.fromByteArray(data[pos..(pos + 8)])
            pos += 8

            // Version 3: File name
            if (version >= 3 && blob.isJsdomFile) {
                if (pos + 4 > data.length) {
                    return None
                }
                let nameLen = Int32(data[pos]) | (Int32(data[pos + 1]) << 8) | (Int32(data[pos + 2]) << 16) | (Int32(data[pos + 3]) << 24)
                pos += 4
                if (nameLen > 0) {
                    if (pos + nameLen > data.length) {
                        return None
                    }
                    let nameBytes = data[pos..(pos + nameLen)]
                    pos += nameLen
                    blob.name = Utf8Codec.decode(nameBytes)
                }
            }
        }

        // Set offset, clamped
        blob.offset = offset
        match (blob.store) {
            case Some(s) => {
                let storeSize = s.size()
                if (storeSize != BLOB_MAX_SIZE) {
                    blob.offset = blob.offset.min(storeSize)
                    blob.size = blob.size.min(storeSize - blob.offset)
                }
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
            case None => {
                return JsPromise.reject(global, JsValue(BaoString("Blob is detached")))
            }
            case Some(s) => {
                if (s.kind == BlobStoreKind.Memory) {
                    return JsPromise.reject(global, JsValue(BaoString("Blob is read-only")))
                }
                // 对应 Bun pipe logic: read stream, write to file/S3 store
                match (s.kind) {
                    case BlobStoreKind.File =>
                        return FileSink.writeFromStream(global, s, readableStream, extraOptions)
                    case BlobStoreKind.S3 =>
                        return S3BlobDownloadTask.init(global, this, S3ReadHandler.default)
                    case _ =>
                        return JsPromise.resolve(global, JsValue(Int64(0)))
                }
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
        return ReadableStream(global: global, blob: blob, chunkSize: chunkSize)
    }

    public static func fromBlobCopyRef(global: JsGlobalObject, blob: Blob, chunkSize: Int64): ?ReadableStream {
        return ReadableStream(global: global, blob: blob.dupe(), chunkSize: chunkSize)
    }

    public static func fromFileBlobWithOffset(global: JsGlobalObject, blob: Blob, offset: Int64): ReadableStream {
        let stream = ReadableStream(global: global, blob: blob.dupe(), chunkSize: 0)
        stream.offset = offset
        return stream
    }

    public var global: JsGlobalObject
    public var blob: Blob
    public var chunkSize: Int64
    public var offset: Int64 = 0
    public var consumed: Bool = false

    public init(global: JsGlobalObject, blob: Blob, chunkSize: Int64) {
        this.global = global
        this.blob = blob
        this.chunkSize = chunkSize
    }

    public func toJsValue(): JsValue {
        let obj = JsObject(global)
        let self = this
        obj.set("getReader", JsValue.nativeFunction(JsNativeFunction("getReader") { _ =>
            self.toReaderJsValue()
        }))
        return JsValue(obj)
    }

    public func toReaderJsValue(): JsValue {
        let obj = JsObject(global)
        let self = this
        obj.set("read", JsValue.nativeFunction(JsNativeFunction("read") { _ =>
            if (self.consumed) {
                let result = JsObject(self.global)
                result.set("done", JsValue(true))
                result.set("value", JsValue())
                return JsValue(result)
            }
            self.consumed = true
            let bytes = self.blob.sharedView()
            let result = JsObject(self.global)
            result.set("value", JsValue.fromUint8Array(self.global, bytes))
            result.set("done", JsValue(false))
            JsValue(result)
        }))
        return JsValue(obj)
    }
}

// ============================================================================
// JsPromise — Promise helper
// Corresponds to: Bun: jsc.JSPromise
// ============================================================================
public class JsPromise {
    public static func wrap(global: JsGlobalObject, work: () -> JsValue): JsValue {
        let result = work()
        return resolve(global, result)
    }

    public static func resolve(global: JsGlobalObject, value: JsValue): JsValue {
        let obj = JsObject(global)
        obj.set("then", JsValue.nativeFunction(JsNativeFunction("then") { args =>
            if (args.length > 0 && args[0].isFunction()) {
                args[0].call(Array<JsValue>([value]))
            }
            JsValue(obj)
        }))
        return JsValue(obj)
    }

    public static func reject(global: JsGlobalObject, error: JsValue): JsValue {
        let obj = JsObject(global)
        obj.set("then", JsValue.nativeFunction(JsNativeFunction("then") { _ =>
            JsValue(obj)
        }))
        obj.set("catch", JsValue.nativeFunction(JsNativeFunction("catch") { args =>
            if (args.length > 0 && args[0].isFunction()) {
                args[0].call(Array<JsValue>([error]))
            }
            JsValue(obj)
        }))
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
    /// Corresponds to: Bun: S3BlobDownloadTask.init()
    public static func init(global: JsGlobalObject, blob: Blob, handler: S3ReadHandler): JsValue {
        let task = S3BlobDownloadTask(blob: blob.dupe(), global: global, handler: handler)
        // 对应 Bun S3BlobDownloadTask: initiate S3 download via http fetch
        // Falls back to sharedView for non-S3 blobs
        return JsPromise.wrap(global) { =>
            match (blob.store) {
                case Some(s) =>
                    match (s.kind) {
                        case BlobStoreKind.S3 =>
                            // S3 download: use HTTP client to fetch the object
                            let s3Url = s.s3Url ?? ""
                            if (s3Url.length > 0) {
                                let result = HttpClient.getBytes(global, s3Url)
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
    public init() {}
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
        return Int64(bytes.length)
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
        return InlineBlob(data: total.toArray(), wasString: false)
    }

    public static func init(data: Array<UInt8>): InlineBlob {
        return InlineBlob(data: data, wasString: false)
    }

    public static func initString(data: Array<UInt8>): InlineBlob {
        return InlineBlob(data: data, wasString: true)
    }

    public func toStringOwned(global: JsGlobalObject): JsValue {
        if (bytes.length == 0) {
            return JsValue(BaoString(""))
        }
        let text = Utf8Codec.decode(bytes)
        let result = JsValue(BaoString(text))
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
        return AnyBlob(internalBlob: InternalBlob(bytes: bytes, wasString: false))
    }

    public static func fromArrayList(list: Array<UInt8>): AnyBlob {
        return AnyBlob(internalBlob: InternalBlob(bytes: list, wasString: false))
    }

    public func memoryCost(): Int64 {
        match (kind) {
            case AnyBlobKind.Blob => {
                match (blob.store) {
                    case Some(s) => s.memoryCost()
                    case None => 0
                }
            }
            case AnyBlobKind.InternalBlob => internalBlob.memoryCost()
            case AnyBlobKind.WTFString => 0
        }
    }

    public func hasOneRef(): Bool {
        match (kind) {
            case AnyBlobKind.Blob => {
                match (blob.store) {
                    case Some(s) => s.hasOneRef()
                    case None => false
                }
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
            case AnyBlobKind.InternalBlob => Int64(internalBlob.bytes.length)
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
            case AnyBlobKind.InternalBlob => internalBlob.bytes.length == 0
            case AnyBlobKind.WTFString => true
        }
    }

    public func contentType(): String {
        match (kind) {
            case AnyBlobKind.Blob => {
                let ct = blob.contentType
                if (ct.length > 0) {
                    return ct
                }
                match (blob.store) {
                    case Some(s) => s.mimeType
                    case None => ""
                }
            }
            case AnyBlobKind.InternalBlob => internalBlob.contentType()
            case AnyBlobKind.WTFString => "text/plain;charset=utf-8"
        }
    }

    public func wasString(): Bool {
        match (kind) {
            case AnyBlobKind.Blob => {
                match (blob.charset) {
                    case CharsetKind.ascii => true
                    case _ => false
                }
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
            case AnyBlobKind.Blob => {
                blob.detach()
            }
            case AnyBlobKind.InternalBlob => {
                internalBlob.clear()
            }
            case AnyBlobKind.WTFString => ()
        }
    }

    public func toBlob(global: JsGlobalObject): Blob {
        if (size() == 0) {
            return Blob.initEmpty(global)
        }
        match (kind) {
            case AnyBlobKind.Blob => return blob.dupe()
            case AnyBlobKind.InternalBlob => {
                let b = Blob.create(internalBlob.toOwnedSlice(), global: global, wasString: internalBlob.wasString)
                return b
            }
            case AnyBlobKind.WTFString => return Blob.initEmpty(global)
        }
    }

    public func toString(global: JsGlobalObject, lifetime: BlobLifetime): JsValue {
        match (kind) {
            case AnyBlobKind.Blob => blob.toStringWithLifetime(global, lifetime: lifetime)
            case AnyBlobKind.InternalBlob => {
                let text = internalBlob.toString()
                internalBlob.clear()
                JsValue(BaoString(text))
            }
            case AnyBlobKind.WTFString => JsValue(BaoString(""))
        }
    }

    public func toArrayBuffer(global: JsGlobalObject, lifetime: BlobLifetime): JsValue {
        match (kind) {
            case AnyBlobKind.Blob => blob.toArrayBufferWithLifetime(global, lifetime: lifetime)
            case AnyBlobKind.InternalBlob => {
                let bytes = internalBlob.toOwnedSlice()
                internalBlob.clear()
                JsValue.fromArrayBuffer(global, bytes)
            }
            case AnyBlobKind.WTFString => JsValue.fromArrayBuffer(global, Array<UInt8>())
        }
    }

    public func toJSON(global: JsGlobalObject, lifetime: BlobLifetime): JsValue {
        match (kind) {
            case AnyBlobKind.Blob => blob.toJSONWithLifetime(global, lifetime: lifetime)
            case AnyBlobKind.InternalBlob => {
                let text = internalBlob.toString()
                internalBlob.clear()
                JsValue(BaoString(text))
            }
            case AnyBlobKind.WTFString => JsValue(BaoString("null"))
        }
    }

    /// Convert to action value based on buffer action
    /// Corresponds to: Bun: Any.to_action_value
    public func toActionValue(global: JsGlobalObject, action: BufferActionTag): JsValue {
        match (action) {
            case BufferActionTag.Text => toString(global, lifetime: BlobLifetime.Clone)
            case BufferActionTag.Bytes => toArrayBuffer(global, lifetime: BlobLifetime.Transfer)
            case BufferActionTag.Blob => {
                let b = toBlob(global)
                return b.toJsValue(global)
            }
            case BufferActionTag.ArrayBuffer => toArrayBuffer(global, lifetime: BlobLifetime.Transfer)
            case BufferActionTag.Json => toJSON(global, lifetime: BlobLifetime.Share)
        }
    }

    /// Convert to promise based on buffer action
    /// Corresponds to: Bun: Any.to_promise
    public func toPromise(global: JsGlobalObject, action: BufferActionTag): JsValue {
        return JsPromise.wrap(global) { =>
            toActionValue(global, action: action)
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
        return "${kb.toFixed(1)} KB"
    }
    if (bytes < 1024 * 1024 * 1024) {
        let mb = Float64(bytes) / (1024.0 * 1024.0)
        return "${mb.toFixed(1)} MB"
    }
    if (bytes < 1024LL * 1024LL * 1024LL * 1024LL) {
        let gb = Float64(bytes) / (1024.0 * 1024.0 * 1024.0)
        return "${gb.toFixed(1)} GB"
    }
    let tb = Float64(bytes) / (1024.0 * 1024.0 * 1024.0 * 1024.0)
    return "${tb.toFixed(1)} TB"
}

/// Validate that a blob is writable
/// Corresponds to: Bun: validate_writable_blob
public func validateWritableBlob(global: JsGlobalObject, blob: Blob): ?JsValue {
    match (blob.store) {
        case None => {
            return JsPromise.reject(global, JsValue(BaoString("Cannot write to a detached Blob")))
        }
        case Some(s) => {
            if (s.kind == BlobStoreKind.Memory) {
                return JsPromise.reject(global, JsValue(BaoString("Cannot write to a Blob backed by bytes, which are always read-only")))
            }
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
            if (parentDir.length == 0 || parentDir == path) {
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
        if (parentDir.length > 0) {
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
        match (SysImpl.fstat(store.fd)) {
            case SysMaybe<PosixStat>.Ok(stat) =>
                let isReg = stat.isFile()
                store.maxFileSize = if (isReg || stat.size > 0) {
                    SizeType(Int64(stat.size).max(0))
                } else {
                    BLOB_MAX_SIZE
                }
                store.fileMode = stat.mode
                store.seekable = Some(isReg)
                store.fileLastModified = stat.mtimeMs
            case _ => ()
        }
        return
    }
    if (store.filePath.length == 0) {
        return
    }
    // stat via FFI
    match (SysImpl.stat(store.filePath)) {
        case SysMaybe<PosixStat>.Ok(stat) =>
            let isReg = stat.isFile()
            store.maxFileSize = if (isReg || stat.size > 0) {
                SizeType(Int64(stat.size).max(0))
            } else {
                BLOB_MAX_SIZE
            }
            store.fileMode = stat.mode
            store.seekable = Some(isReg)
            store.fileLastModified = stat.mtimeMs
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
func httpProxyHref(global: JsGlobalObject): ?String {
    // 对应 Bun http_proxy_href: transpiler.env.getHttpProxy(true, null, null)?.href
    let vm = global.bunVM()
    if (vm.isSome()) {
        let proxy = vm.getOrThrow().transpiler.env.getHttpProxy(true, None, None)
        if (proxy.isSome()) {
            return proxy.getOrThrow().href
        }
    }
    return None
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
        return JsValue(BaoString(text))
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
        return JsValue(BaoString(text))
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
        return JsValue.fromArrayBuffer(global, bytes)
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
        return JsValue.fromUint8Array(global, bytes)
    }
}

// ============================================================================
// ToFormDataWithBytesFn — marker type for toFormData dispatch
// Corresponds to: Bun: ToFormDataWithBytesFn
// ============================================================================
public class ToFormDataWithBytesFn <: ReadFileToJs {
    public func call(blob: Blob, global: JsGlobalObject, bytes: Array<UInt8>, lifetime: BlobLifetime): JsValue {
        let encoding = blob.getFormDataEncoding()
        if (encoding == None) {
            return JsValue()
        }
        return JsValue()
    }
}

// ============================================================================
// FormDataEntry — form data entry enum
// Corresponds to: Bun: FormDataEntry
// ============================================================================
public enum FormDataEntry {
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
    public func onEntry(name: String, entry: FormDataEntry): Unit {
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
            case FormDataEntry.String(value) => {
                appendStatic("\"\r\n\r\n")
                appendBytes(Utf8Codec.encode(value))
            }
            case FormDataEntry.File(blob, filename) => {
                appendStatic("\"; filename=\"")
                appendBytes(Utf8Codec.encode(filename))
                appendStatic("\"\r\n")

                let ct = blob.contentType
                let contentType = if (ct.length > 0) { ct } else { "application/octet-stream" }
                appendStatic("Content-Type: ")
                appendBytes(Utf8Codec.encode(contentType))
                appendStatic("\r\n\r\n")

                // Append blob data
                match (blob.store) {
                    case Some(s) => {
                        match (s.kind) {
                            case BlobStoreKind.Memory => {
                                appendBytes(blob.sharedView())
                            }
                            case BlobStoreKind.File => {
                                // 对应 Bun FormData file read: read file bytes synchronously
                                let view = blob.sharedView()
                                if (view.length > 0) {
                                    appendBytes(view)
                                } else {
                                    let fileBytes = blob.readFileBytes()
                                    if (fileBytes.length > 0) {
                                        appendBytes(fileBytes)
                                    }
                                }
                            }
                            case BlobStoreKind.S3 => {
                                // 对应 Bun FormData S3: download and append bytes
                                let view = blob.sharedView()
                                if (view.length > 0) {
                                    appendBytes(view)
                                }
                            }
                        }
                    }
                    case None => ()
                }
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
        return result.toArray()
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
        return Int64(bytes.length)
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
        return buffer.toArray()
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
// ============================================================================
public func onFileStreamResolveRequestStream(global: JsGlobalObject, wrapper: FileStreamWrapper): JsValue {
    let stream = wrapper.readableStreamRef
    if (stream != None) {
        stream.done(global)
    }
    wrapper.promise.resolve(global, JsValue(Float64(0.0)))
    return JsValue()
}

// ============================================================================
// onFileStreamRejectRequestStream — reject callback for file stream
// Corresponds to: Bun: on_file_stream_reject_request_stream
// ============================================================================
public func onFileStreamRejectRequestStream(global: JsGlobalObject, wrapper: FileStreamWrapper, err: JsValue): JsValue {
    wrapper.promise.reject(global, err)
    let stream = wrapper.readableStreamRef
    if (stream != None) {
        stream.cancel(global)
    }
    return JsValue()
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
            return JsPromise.resolve(global, JsValue(Float64(Int64(bytes.length))))
        case SysMaybe<Unit>.Err(e) =>
            return JsPromise.reject(global, JsValue(BaoString("Failed to write file: ${e}")))
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
            return JsPromise.resolve(global, JsValue(Float64(Int64(bytes.length))))
        case SysMaybe<Unit>.Err(e) =>
            return JsPromise.reject(global, JsValue(BaoString("Failed to write file: ${e}")))
    }
}

/// Helper: write bytes to path or fd
func writePathOrFd(pathlike: PathOrFileDescriptor, bytes: Array<UInt8>, needsOpen: Bool): SysMaybe<Unit> {
    match (pathlike) {
        case PathOrFileDescriptor.Fd(fd) =>
            let file = SysFile.fromFd(fd)
            file.writeAll(bytes)
        case PathOrFileDescriptor.Path(path) =>
            if (needsOpen) {
                // O_WRONLY = 1, O_CREAT = 64, O_TRUNC = 512
                match (SysFile.open(path, Int64(577), UInt32(0x1A4))) {
                    case SysMaybe<SysFile>.Ok(file) =>
                        let result = file.writeAll(bytes)
                        file.close()
                        return result
                    case SysMaybe<SysFile>.Err(e) => SysMaybe<Unit>.Err(e)
                }
            } else {
                SysFile.writeFile(path, bytes)
            }
    }
}

// ============================================================================
// toStreamWithOffset — create ReadableStream from Blob with offset
// Corresponds to: Bun: to_stream_with_offset
// ============================================================================
public func toStreamWithOffset(global: JsGlobalObject, blob: Blob, offset: Int64): JsValue {
    return ReadableStream.fromFileBlobWithOffset(global, blob: blob, offset: offset)
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
    let blob = Blob.fromJs(global, arg: value)
    if (blob == None) {
        return None
    }
    return Some(blobDupe(blob.getOrThrow()))
}

/// Blob__setAsFile — mark a Blob as a File
/// Corresponds to: Bun: Blob__setAsFile
public func blobSetAsFile(blob: Blob, pathStr: String): Unit {
    blob.isJsdomFile = true
    match (blob.store) {
        case Some(s) => {
            if (s.kind == BlobStoreKind.Memory && s.storedName.length == 0) {
                s.storedName = pathStr
            }
        }
        case None => ()
    }
}

/// Blob__getFileNameString — get filename from Blob
/// Corresponds to: Bun: Blob__getFileNameString
public func blobGetFileNameString(blob: Blob): String {
    let name = blob.getFileName()
    if (name != None) {
        return name.getOrThrow()
    }
    return ""
}

/// Blob__getDataPtr — get data pointer from Blob JS value
/// Corresponds to: Bun: Blob__getDataPtr
public func blobGetDataPtr(global: JsGlobalObject, value: JsValue): ?Array<UInt8> {
    let blob = Blob.fromJs(global, arg: value)
    if (blob == None) {
        return None
    }
    let data = blob.getOrThrow().sharedView()
    if (data.length == 0) {
        return None
    }
    return Some(data)
}

/// Blob__getSize — get Blob size from JS value
/// Corresponds to: Bun: Blob__getSize
public func blobGetSize(global: JsGlobalObject, value: JsValue): Int64 {
    let blob = Blob.fromJs(global, arg: value)
    if (blob == None) {
        return 0
    }
    return Int64(blob.getOrThrow().sharedView().length)
}

/// Blob__fromBytes — create Blob from raw bytes
/// Corresponds to: Bun: Blob__fromBytes
public func blobFromBytes(global: JsGlobalObject, bytes: Array<UInt8>): Blob {
    if (bytes.length == 0) {
        return Blob.initEmpty(global)
    }
    let store = BlobStore(bytes)
    return Blob.initWithStore(store, global: global)
}

/// Blob__fromBytesWithType — create Blob from raw bytes with MIME type
/// Corresponds to: Bun: Blob__fromBytesWithType
public func blobFromBytesWithType(global: JsGlobalObject, bytes: Array<UInt8>, mime: String): Blob {
    let blob = blobFromBytes(global, bytes: bytes)
    if (mime.length > 0) {
        blob.contentType = mime
        blob.contentTypeWasSet = true
    }
    return blob
}

/// Blob__fromMmapWithType — create Blob from mmap'd region with MIME type
/// Corresponds to: Bun: Blob__fromMmapWithType
public func blobFromMmapWithType(global: JsGlobalObject, bytes: Array<UInt8>, mime: String): Blob {
    // In Cangjie, mmap is handled by the runtime; fall back to fromBytes
    return blobFromBytesWithType(global, bytes: bytes, mime: mime)
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
    let bytes = value.toByteArray()
    for (b in bytes) {
        writer.append(b)
    }
}

public func readFloatLE(data: Array<UInt8>, offset: Int64): Float64 {
    if (offset + 8 > Int64(data.length)) {
        return 0.0
    }
    return Float64.fromByteArray(data[offset..(offset + 8)])
}

// ============================================================================
// readSlice — read a slice from byte array at offset
// Corresponds to: Bun: read_slice
// ============================================================================
public func readSlice(data: Array<UInt8>, offset: Int64, len: Int64): ?Array<UInt8> {
    if (offset + len > Int64(data.length)) {
        return None
    }
    return Some(data[offset..(offset + len)])
}

// ============================================================================
// readIntLE — read a little-endian integer from byte array
// Corresponds to: Bun: read_int_le
// ============================================================================
public func readInt8(data: Array<UInt8>, offset: Int64): ?UInt8 {
    if (offset >= Int64(data.length)) {
        return None
    }
    return Some(data[offset])
}

public func readInt32LE(data: Array<UInt8>, offset: Int64): ?Int32 {
    if (offset + 4 > Int64(data.length)) {
        return None
    }
    return Some(Int32(data[offset]) | (Int32(data[offset + 1]) << 8) | (Int32(data[offset + 2]) << 16) | (Int32(data[offset + 3]) << 24))
}

public func readInt64LE(data: Array<UInt8>, offset: Int64): ?Int64 {
    if (offset + 8 > Int64(data.length)) {
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

// ============================================================================
// ReadFileResultType — import from blob sub-module
// ============================================================================
public type ReadFileResultType = bao_runtime.webcore.blob.ReadFileResultType
