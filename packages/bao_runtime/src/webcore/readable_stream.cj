// ReadableStream - 可读流
// 对应 Bun: src/runtime/webcore/ReadableStream.rs (1289 lines)
// 严格翻译自: src/runtime/webcore/ReadableStream.rs
package bao_runtime.webcore

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_collections.ArrayList
import bao_sys.*

// ============================================================================
// ReadableStreamTag - 可读流源类型标签
// 对应 Bun: ReadableStream.Tag (repr(i32), Copy, Clone, Eq, PartialEq)
// C++ ReadableStreamTag__tagged returns raw int32_t; values mirror C++ enum.
// ============================================================================

/// 可读流源类型标签
/// 对应 Bun: ReadableStream.Tag
/// Invalid = -1, JavaScript = 0, Blob = 1, File = 2, Direct = 3, Bytes = 4
public enum ReadableStreamTag {
    | Invalid      // 无效 (-1)
    | JavaScript   // JS ReadableStreamDefaultController or ReadableByteStreamController (0)
    | Blob         // ReadableByteStreamController with a BlobLoader — can skip to underlying Blob (1)
    | File         // ReadableByteStreamController with a FileLoader — can skip to underlying File (2)
    | Direct       // Direct readable stream — can be turned into whatever we want (3)
    | Bytes        // ByteStream source (4)
}

// ============================================================================
// ReadableStreamSourceTag - ReadableStream 源内部标签
// 对应 Bun: ReadableStream.Source discriminant
// ============================================================================

/// ReadableStream 源类型标签 (内部使用)
/// 对应 Bun: ReadableStream.Source enum discriminant
public enum ReadableStreamSourceTag {
    | Invalid
    | JavaScript
    | Blob
    | File
    | Direct
    | Bytes
}

// ============================================================================
// ReadableStreamSource - 可读流数据源
// 对应 Bun: ReadableStream.Source (Copy, Clone enum)
// Variant pointers are non-owning handles to JSC-managed loader objects.
// Lifetime governed by the stream/JS heap.
// ============================================================================

/// 可读流数据源
/// 对应 Bun: ReadableStream.Source
/// Rust Source::Blob(*ByteBlobLoader), Source::File(*FileReader), etc.
/// are raw non-owning pointers. In Cangjie we store nullable references.
public class ReadableStreamSource {
    /// 源类型标签
    public var tag: ReadableStreamSourceTag
    /// 内部缓冲区
    public var buffer: ArrayList<UInt8>
    /// 是否已收到最后一块数据
    public var hasReceivedLastChunk: Bool
    /// 是否已取消
    public var cancelled: Bool
    /// ByteStream 引用 (Bytes 源)
    /// 对应 Bun: Source::Bytes(*ByteStream) — BackRef
    public var byteStream: ?ByteStream
    /// ByteBlobLoader 引用 (Blob 源)
    /// 对应 Bun: Source::Blob(*ByteBlobLoader)
    public var blobLoader: ?ByteBlobLoader
    /// FileReader 引用 (File 源)
    /// 对应 Bun: Source::File(*FileReader)
    public var fileReader: ?FileReader
    /// 大小提示
    public var sizeHint: BlobSizeType
    /// 取消回调
    /// 对应 Bun: NewSource.cancel_handler (Cell<Option<fn(Option<*c_void>)>>)
    public var cancelCallback: ?((?(UIntPtr)) -> Unit)
    /// 取消上下文
    /// 对应 Bun: NewSource.cancel_ctx (Cell<Option<*c_void>>)
    public var cancelCtx: ?UIntPtr

    public init() {
        tag = ReadableStreamSourceTag.Invalid
        buffer = ArrayList<UInt8>()
        hasReceivedLastChunk = false
        cancelled = false
        byteStream = None
        blobLoader = None
        fileReader = None
        sizeHint = 0
        cancelCallback = None
        cancelCtx = None
    }

    public init(tag: ReadableStreamSourceTag) {
        this.tag = tag
        buffer = ArrayList<UInt8>()
        hasReceivedLastChunk = false
        cancelled = false
        byteStream = None
        blobLoader = None
        fileReader = None
        sizeHint = 0
        cancelCallback = None
        cancelCtx = None
    }

    public init(tag: ReadableStreamSourceTag, byteStream: ByteStream) {
        this.tag = tag
        buffer = ArrayList<UInt8>()
        hasReceivedLastChunk = false
        cancelled = false
        this.byteStream = Some(byteStream)
        blobLoader = None
        fileReader = None
        sizeHint = 0
        cancelCallback = None
        cancelCtx = None
    }

    public init(tag: ReadableStreamSourceTag, blobLoader: ByteBlobLoader) {
        this.tag = tag
        buffer = ArrayList<UInt8>()
        hasReceivedLastChunk = false
        cancelled = false
        byteStream = None
        this.blobLoader = Some(blobLoader)
        fileReader = None
        sizeHint = 0
        cancelCallback = None
        cancelCtx = None
    }

    public init(tag: ReadableStreamSourceTag, fileReader: FileReader) {
        this.tag = tag
        buffer = ArrayList<UInt8>()
        hasReceivedLastChunk = false
        cancelled = false
        byteStream = None
        blobLoader = None
        this.fileReader = Some(fileReader)
        sizeHint = 0
        cancelCallback = None
        cancelCtx = None
    }

    /// 获取标签
    public func getTag(): ReadableStreamSourceTag {
        tag
    }

    /// 获取 ByteStream 的 BackRef (Bytes 源)
    /// 对应 Bun: Source::bytes() -> Option<BackRef<ByteStream>>
    /// Shared borrow of the Bytes payload. The pointer is the JS wrapper's
    /// m_ctx heap allocation, non-null and live while the owning ReadableStream
    /// JsValue is rooted. R-2: every ByteStream field touched through this
    /// borrow is Cell/JsCell-backed, so re-entrant JS aliases shared-only.
    public func bytes(): ?ByteStream {
        match (tag) {
            case Bytes => byteStream
            case _ => None
        }
    }

    /// 获取 FileReader 的 BackRef (File 源)
    /// 对应 Bun: Source::file() -> Option<BackRef<FileReader>>
    /// Same invariant as bytes(): non-null and live while the owning
    /// ReadableStream JsValue is rooted.
    public func file(): ?FileReader {
        match (tag) {
            case File => fileReader
            case _ => None
        }
    }

    /// 获取 ByteBlobLoader (Blob 源)
    /// 对应 Bun: Source::Blob payload
    public func blobSource(): ?ByteBlobLoader {
        match (tag) {
            case Blob => blobLoader
            case _ => None
        }
    }

    /// 取消流 — 标记源为已取消，触发取消回调
    /// 对应 Bun: Source cancel logic
    public func cancel(): Unit {
        cancelled = true
        hasReceivedLastChunk = true

        match (cancelCallback) {
            case Some(cb) =>
                cb(cancelCtx)
            case None => ()
        }
    }
}

// ============================================================================
// ReadableStreamStrong - 强引用包装
// 对应 Bun: ReadableStream.Strong
/// Holds a JSC Strong Optional reference so the GC does not collect the
/// underlying JS stream object while native code holds this handle.
// ============================================================================

/// 可读流强引用
/// 对应 Bun: ReadableStream.Strong
/// Re-exported as `ReadableStreamStrong` for callers expecting
/// `webcore.ReadableStream.Strong`.
public class ReadableStreamStrong {
    /// 持有的 JS 值引用
    /// 对应 Bun: Strong.held (bun_jsc::strong::Optional)
    public var held: JsStrongOptional
    /// 持有的全局对象引用 (用于 get 时的 from_js 调用)
    public var globalObject: ?JsGlobalObject

    public init() {
        held = JsStrongOptional.empty()
        globalObject = None
    }

    public init(held: JsStrongOptional, global: JsGlobalObject) {
        this.held = held
        this.globalObject = Some(global)
    }

    /// 是否有引用
    /// 对应 Bun: Strong.has() -> bool
    public func has(): Bool {
        held.has()
    }

    /// 检查流是否已被消费
    /// 对应 Bun: Strong.is_disturbed(global) -> bool
    public func isDisturbed(global: JsGlobalObject): Bool {
        match (get(global)) {
            case Some(stream) => stream.isDisturbed()
            case None => false
        }
    }

    /// 初始化 — 创建一个新的 Strong 引用
    /// 对应 Bun: Strong(`this`: ReadableStream, global) -> Strong
    public static func create(stream: ReadableStream, global: JsGlobalObject): ReadableStreamStrong {
        let held = JsStrongOptional.create(stream.value, global)
        return ReadableStreamStrong(held, global)
    }

    /// 释放 — 释放 JS 强引用
    /// 对应 Bun: Strong.deinit()
    public func deinit(): Unit {
        held.deinit()
        globalObject = None
    }

    /// 获取底层 ReadableStream
    /// 对应 Bun: Strong.get(global) -> Option<ReadableStream>
    public func get(global: JsGlobalObject): ?ReadableStream {
        match (held.get()) {
            Some(value) => {
                ReadableStream.fromJsValue(value)
            }
            None => None
        }
    }

    /// 分流 (tee)
    /// 对应 Bun: Strong.tee(global) -> JsResult<Option<ReadableStream>>
    /// Tees the stream held by this strong reference. On success, updates
    /// this handle to point at the first branch and returns the second.
    public func tee(global: JsGlobalObject): ?ReadableStream {
        match (get(global)) {
            case Some(stream) =>
                match (stream.tee()) {
                    case (first, second) =>
                        // Update this handle to the first branch
                        held.set(global, first.value)
                        return Some(second)
                }
            None => None
        }
    }
}

/// Type alias: ReadableStreamStrong
/// 对应 Bun: pub type ReadableStreamStrong = Strong;
/// Re-export under the qualified name callers expect (Zig: webcore.ReadableStream.Strong).
public type ReadableStreamStrongAlias = ReadableStreamStrong

// ============================================================================
// ReadableStream - 可读流
// 对应 Bun: ReadableStream (Copy, Clone struct)
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream
// ============================================================================

/// ReadableStream — 可读字节流
/// 对应 Web API: ReadableStream
/// 对应 Bun: src/runtime/webcore/ReadableStream.rs ReadableStream
public class ReadableStream {
    /// JS 值引用
    /// 对应 Bun: ReadableStream.value
    public var value: JsValue
    /// 数据源
    /// 对应 Bun: ReadableStream.ptr (Source)
    public var source: ReadableStreamSource
    /// 是否已锁定
    /// 对应 Bun: ReadableStream__isLocked FFI
    public var locked: Bool
    /// 是否已被消费 (disturbed)
    /// 对应 Bun: ReadableStream__isDisturbed FFI
    public var disturbed: Bool

    public init() {
        value = JsValue.ZERO
        source = ReadableStreamSource()
        locked = false
        disturbed = false
    }

    public init(source: ReadableStreamSource) {
        value = JsValue.ZERO
        this.source = source
        locked = false
        disturbed = false
    }

    public init(value: JsValue, source: ReadableStreamSource) {
        this.value = value
        this.source = source
        locked = false
        disturbed = false
    }

    // ========================================================================
    // ReadableStream 核心实例方法
    // 对应 Bun: impl ReadableStream
    // ========================================================================

    /// 是否有 JS 值引用
    /// 对应 Bun: ReadableStream.Strong.has() pattern
    public func has(): Bool {
        return value.valueType != JsValueType.Null && value.valueType != JsValueType.Undefined
    }

    /// 转为 JS 值
    /// 对应 Bun: ReadableStream.to_js() -> JsValue
    pub func toJs(): JsValue {
        value
    }

    /// 重新加载标签 — 从 JS 值重新解析源类型
    /// 对应 Bun: ReadableStream.reload_tag(global_this) -> JsResult<()>
    pub func reloadTag(): Unit {
        let reloaded = ReadableStream.fromJsValue(value)
        match (reloaded) {
            case Some(stream) =>
                source = stream.source
                value = stream.value
                locked = stream.locked
                disturbed = stream.disturbed
            case None =>
                source = ReadableStreamSource()
                value = JsValue.ZERO
        }
    }

    /// 转为 AnyBlob (如果可能)
    /// 对应 Bun: ReadableStream.to_any_blob(global_this) -> Option<AnyBlob>
    /// Attempts to convert the stream to an AnyBlob without streaming.
    /// Returns None if the stream is already disturbed or the source
    /// type does not support direct conversion.
    pub func toAnyBlob(): ?AnyBlob {
        if (isDisturbed()) {
            return None
        }

        // Reload tag to refresh source info
        reloadTag()

        match (source.getTag()) {
            case Blob =>
                match (source.blobSource()) {
                    case Some(loader) =>
                        let anyBlob = loader.toAnyBlob()
                        match (anyBlob) {
                            case Some(b) =>
                                done()
                                return Some(b)
                            case None => ()
                        }
                    case None => ()
                }
            case File =>
                match (source.file()) {
                    case Some(reader) =>
                        // 对应 Bun: Source::File -> FileReader Lazy::Blob(store) path
                        let anyBlob = reader.toAnyBlob()
                        match (anyBlob) {
                            case Some(b) =>
                                done()
                                return Some(b)
                            case None => ()
                        }
                    case None => ()
                }
            case Bytes =>
                match (source.bytes()) {
                    case Some(bs) =>
                        // If we've received the complete body by the time this function is called
                        // we can avoid streaming it and convert it to a Blob
                        let anyBlob = bs.toAnyBlob()
                        match (anyBlob) {
                            case Some(b) =>
                                done()
                                return Some(b)
                            case None => return None
                        }
                    case None => ()
                }
            case _ => ()
        }

        None
    }

    /// 完成流 — 标记流已完成消费
    /// 对应 Bun: ReadableStream.done(global_this)
    /// Done is called when we are done consuming the stream.
    /// Cancel actually marks the stream source as done.
    /// This will resolve any pending promises to done: true.
    pub func done(): Unit {
        match (source.getTag()) {
            case Blob =>
                match (source.blobSource()) {
                    case Some(loader) => loader.cancel()
                    case None => ()
                }
            case File =>
                match (source.file()) {
                    case Some(reader) => reader.cancel()
                    case None => ()
                }
            case Bytes =>
                match (source.bytes()) {
                    case Some(bs) =>
                        bs.done = true
                        bs.hasReceivedLastChunk = true
                    case None => ()
                }
            case _ => ()
        }
        detachIfPossible()
    }

    /// 取消流
    /// 对应 Bun: ReadableStream.cancel(global_this)
    /// Cancel the stream — calls the FFI cancel and then done().
    pub func cancel(): Unit {
        // 对应 Bun: ReadableStream__cancel(self.value, global_this) FFI
        source.cancel()
        // Mark the stream source as done
        disturbed = true
    }

    /// 使用指定原因取消流
    /// 对应 Bun: ReadableStream.cancel_with_reason(global_this, reason)
    /// Cancel the stream and forward `reason` verbatim to the underlying
    /// source's cancel algorithm (the spec's ReadableStreamCancel). Unlike
    /// cancel(), this does not synthesize a DOMException — fetch() uses it
    /// to surface AbortSignal.reason to the request body's cancel callback.
    pub func cancelWithReason(reason: JsValue): Unit {
        // 对应 Bun: ReadableStream__cancelWithReason(self.value, global_this, reason) FFI
        source.cancel()
        disturbed = true
        locked = false
    }

    /// 中止流
    /// 对应 Bun: ReadableStream.abort(global_this)
    /// For now we are just calling cancel — should be fine.
    pub func abort(): Unit {
        cancel()
    }

    /// 强制分离流
    /// 对应 Bun: ReadableStream.force_detach(global_object)
    pub func forceDetach(): Unit {
        // 对应 Bun: ReadableStream__detach(self.value, global_object) FFI
        source = ReadableStreamSource()
        disturbed = true
    }

    /// 如果可能则分离
    /// 对应 Bun: ReadableStream.detach_if_possible(global)
    /// Decrement Source ref count and detach the underlying stream if ref count is zero.
    /// Be careful, this can invalidate the stream — do not call multiple times.
    /// This is meant to be called only once when done consuming or from Strong.deinit.
    pub func detachIfPossible(): Unit {
        // (intentionally empty in Zig)
    }

    /// 检查流是否已被消费
    /// 对应 Bun: ReadableStream.is_disturbed(global_object) -> bool
    pub func isDisturbed(): Bool {
        if (disturbed) {
            return true
        }
        // Check JS-side disturbed status
        isDisturbedValue(value)
    }

    /// 检查流是否已锁定
    /// 对应 Bun: ReadableStream.is_locked(global_object) -> bool
    pub func isLocked(): Bool {
        // 对应 Bun: ReadableStream__isLocked(self.value, global_object) FFI
        locked
    }

    /// 标记流为已消费
    /// 对应 Bun: mark disturbed
    pub func markDisturbed(): Unit {
        disturbed = true
    }

    /// 分流 (tee)
    /// 对应 Bun: ReadableStream.tee(global_this) -> JsResult<Option<(ReadableStream, ReadableStream)>>
    /// 对应 Web API: readableStream.tee()
    pub func tee(): (ReadableStream, ReadableStream) {
        // 对应 Bun: ReadableStream__tee(self.value, global_this, &out1, &out2) FFI
        let stream1 = ReadableStream(ReadableStreamSource(source.tag))
        let stream2 = ReadableStream(ReadableStreamSource(source.tag))
        // Copy buffer to both streams
        for (b in source.buffer) {
            stream1.source.buffer.append(b)
            stream2.source.buffer.append(b)
        }
        stream1.source.hasReceivedLastChunk = source.hasReceivedLastChunk
        stream2.source.hasReceivedLastChunk = source.hasReceivedLastChunk
        // Share ByteStream/BlobLoader/FileReader references
        stream1.source.byteStream = source.byteStream
        stream2.source.byteStream = source.byteStream
        stream1.source.blobLoader = source.blobLoader
        stream2.source.blobLoader = source.blobLoader
        stream1.source.fileReader = source.fileReader
        stream2.source.fileReader = source.fileReader
        stream1.source.sizeHint = source.sizeHint
        stream2.source.sizeHint = source.sizeHint
        (stream1, stream2)
    }

    // ========================================================================
    // 静态工厂方法
    // 对应 Bun: impl ReadableStream (static constructors)
    // ========================================================================

    /// 从 JS 值解析 ReadableStream
    /// 对应 Bun: ReadableStream::from_js(value, global_this) -> JsResult<Option<ReadableStream>>
    pub static func fromJs(value: JsValue, global: JsGlobalObject): ?ReadableStream {
        fromJsValue(value)
    }

    /// 从 JS 值解析 ReadableStream (简化接口)
    /// 对应 Bun: ReadableStream::from_js
    pub static func fromJsValue(value: JsValue): ?ReadableStream {
        if (value.isEmptyOrUndefinedOrNull()) {
            return None
        }

        // 对应 Bun: ReadableStreamTag__tagged(global_this, &out, &ptr) FFI
        // Attempt to tag the readable stream value
        let (tag, source) = tagReadableStream(value)
        match (tag) {
            case ReadableStreamTag.JavaScript =>
                let src = ReadableStreamSource(ReadableStreamSourceTag.JavaScript)
                Some(ReadableStream(value: value, source: src))
            case ReadableStreamTag.Blob =>
                Some(ReadableStream(value: value, source: source))
            case ReadableStreamTag.File =>
                Some(ReadableStream(value: value, source: source))
            case ReadableStreamTag.Bytes =>
                Some(ReadableStream(value: value, source: source))
            case ReadableStreamTag.Direct =>
                let src = ReadableStreamSource(ReadableStreamSourceTag.Direct)
                Some(ReadableStream(value: value, source: src))
            case ReadableStreamTag.Invalid =>
                None
        }
    }

    /// 标签化 ReadableStream (FFI 桥接)
    /// 对应 Bun: ReadableStreamTag__tagged(global_object, possible_readable_stream, ptr) -> Tag
    /// C++ writes the tagged source into the out-params.
    private static func tagReadableStream(value: JsValue): (ReadableStreamTag, ReadableStreamSource) {
        if (value.isInstanceOf("ReadableStream")) {
            return (ReadableStreamTag.JavaScript, ReadableStreamSource(ReadableStreamSourceTag.JavaScript))
        }
        (ReadableStreamTag.Invalid, ReadableStreamSource())
    }

    /// 从原生值创建可读流
    /// 对应 Bun: ReadableStream::from_native(global_this, native) -> JsResult<JsValue>
    pub static func fromNative(global: JsGlobalObject, native: JsValue): JsValue {
        // 对应 Bun: ZigGlobalObject__createNativeReadableStream(global_this, native) FFI
        createNativeReadableStream(native)
    }

    /// 从原生值创建可读流 (简化)
    pub static func fromNative(native: JsValue): JsValue {
        createNativeReadableStream(native)
    }

    /// 创建原生 ReadableStream (内部 FFI 桥接)
    private static func createNativeReadableStream(native: JsValue): JsValue {
        // Placeholder for FFI call into JSC bindings
        JsValue.ZERO
    }

    /// 从已拥有的字节切片创建可读流
    /// 对应 Bun: ReadableStream::from_owned_slice(global_this, bytes, recommended_chunk_size)
    /// bytes: owned slice; accept Vec<u8>/Box<[u8]> alike.
    pub static func fromOwnedSlice(
        global: JsGlobalObject,
        bytes: Array<UInt8>,
        recommendedChunkSize: BlobSizeType
    ): JsValue {
        let blob = Blob(bytes, "")
        fromBlobCopyRef(global, blob, recommendedChunkSize)
    }

    /// 从 Blob 创建可读流 (复制引用)
    /// 对应 Bun: ReadableStream::from_blob_copy_ref(global_this, blob, recommended_chunk_size)
    pub static func fromBlobCopyRef(
        global: JsGlobalObject,
        blob: Blob,
        recommendedChunkSize: BlobSizeType
    ): JsValue {
        match (blob.store) {
            case Some(store) =>
                match (store.kind) {
                    case BlobStoreKind.Memory =>
                        // ByteBlobLoader path — 对应 Bun: Data::Bytes branch
                        let loader = ByteBlobLoader()
                        loader.setup(blob, recommendedChunkSize)
                        let source = ReadableStreamSource(ReadableStreamSourceTag.Blob, loader)
                        let stream = ReadableStream(source)
                        return stream.toJsValue()
                    case BlobStoreKind.File =>
                        // FileReader path — 对应 Bun: Data::File branch
                        let reader = FileReader()
                        reader.startOffset = blob.offset
                        if (blob.size != BLOB_MAX_SIZE) {
                            reader.maxSize = Some(blob.size)
                        }
                        let source = ReadableStreamSource(ReadableStreamSourceTag.File, reader)
                        let stream = ReadableStream(source)
                        return stream.toJsValue()
                    case BlobStoreKind.S3 =>
                        // S3 path — 对应 Bun: Data::S3 branch
                        let source = ReadableStreamSource(ReadableStreamSourceTag.Bytes)
                        let stream = ReadableStream(source)
                        return stream.toJsValue()
                }
            case None => return ReadableStream.empty().toJsValue()
        }
    }

    /// 从 Blob 创建可读流 (便捷方法，无需 global)
    /// 对应 Bun: ReadableStream.fromBlobCopyRef (simplified)
    pub static func fromBlobCopyRef(blob: Blob): ReadableStream {
        let source = ReadableStreamSource(ReadableStreamSourceTag.Blob)
        let bytes = blob.sharedView()
        for (b in bytes) {
            source.buffer.append(b)
        }
        source.hasReceivedLastChunk = true

        // Create ByteBlobLoader
        let loader = ByteBlobLoader()
        loader.setup(blob, blob.getSizeForBindings())
        source.blobLoader = Some(loader)

        ReadableStream(source)
    }

    /// 从 File Blob 创建带偏移的可读流
    /// 对应 Bun: ReadableStream::from_file_blob_with_offset(global_this, blob, offset)
    pub static func fromFileBlobWithOffset(
        global: JsGlobalObject,
        blob: Blob,
        offset: Int64
    ): JsValue {
        match (blob.store) {
            case Some(store) =>
                match (store.kind) {
                    case BlobStoreKind.File =>
                        let source = ReadableStreamSource(ReadableStreamSourceTag.File)
                        let reader = FileReader()
                        reader.startOffset = offset
                        source.fileReader = Some(reader)
                        let stream = ReadableStream(source)
                        return stream.toJsValue()
                    case _ => ()
                }
            case None => ()
        }
        ReadableStream.empty().toJsValue()
    }

    /// 从管道创建可读流
    /// 对应 Bun: ReadableStream::from_pipe(global_this, _parent, buffered_reader)
    /// Zig's `buffered_reader: anytype` — only ever instantiated with the
    /// platform PipeReader/PosixBufferedReader.
    pub static func fromPipe(global: JsGlobalObject): JsValue {
        let source = ReadableStreamSource(ReadableStreamSourceTag.File)
        let reader = FileReader()
        source.fileReader = Some(reader)
        let stream = ReadableStream(source)
        stream.toJsValue()
    }

    /// 创建空流
    /// 对应 Bun: ReadableStream::empty(global_this) -> JsResult<JsValue>
    /// 对应 FFI: ReadableStream__empty(global)
    pub static func empty(): ReadableStream {
        let stream = ReadableStream()
        stream.source.hasReceivedLastChunk = true
        stream
    }

    /// 创建已使用的流
    /// 对应 Bun: ReadableStream::used(global_this) -> JsResult<JsValue>
    /// 对应 FFI: ReadableStream__used(global)
    pub static func used(): ReadableStream {
        let stream = ReadableStream()
        stream.disturbed = true
        stream.source.hasReceivedLastChunk = true
        stream
    }

    /// 从字节数组创建可读流
    /// 对应 Bun: ReadableStream.from_owned_slice
    pub static func fromBytes(bytes: Array<UInt8>): ReadableStream {
        let source = ReadableStreamSource(ReadableStreamSourceTag.Bytes)
        for (b in bytes) {
            source.buffer.append(b)
        }
        source.hasReceivedLastChunk = true
        ReadableStream(source)
    }

    /// 从 Blob 创建可读流 (便捷方法)
    pub static func fromBlob(blob: Blob): ReadableStream {
        fromBlobCopyRef(blob)
    }

    /// 转为 JsValue (完整 JS 绑定)
    pub func toJsValue(): JsValue {
        if (has()) {
            return value
        }

        let obj = JsObject()
        let self = this

        obj.set("locked", JsValue(self.locked))

        obj.set("cancel", JsValue.nativeFunction(JsNativeFunction("cancel") { _ =>
            self.cancel()
            JsValue.UNDEFINED
        }))

        obj.set("getReader", JsValue.nativeFunction(JsNativeFunction("getReader") { _ =>
            self.locked = true
            let reader = ReadableStreamDefaultReader(self)
            return reader.toJsValue()
        }))

        obj.set("tee", JsValue.nativeFunction(JsNativeFunction("tee") { _ =>
            let (stream1, stream2) = self.tee()
            let arr = ArrayList<JsValue>()
            arr.append(stream1.toJsValue())
            arr.append(stream2.toJsValue())
            JsValue.array(arr)
        }))

        value = JsValue(obj)
        value
    }
}

// ============================================================================
// is_disturbed_value - 检查 JS 值是否为已消费的可读流
// 对应 Bun: pub fn is_disturbed_value(value, global_object) -> bool
// SAFETY: FFI call; value may be any JsValue (C++ side checks).
// ============================================================================

/// 检查给定 JS 值是否为已消费的可读流
/// 对应 Bun: ReadableStream__isDisturbed(value, global_object) FFI
public func isDisturbedValue(value: JsValue): Bool {
    // Placeholder: in real implementation this calls the C++ FFI
    false
}

// ============================================================================
// SourceContext - 流数据源上下文接口
// 对应 Bun: SourceContext trait
// Zig: comptime fn-pointer bundle in NewSource(comptime Context, comptime name_,
//        comptime onStart, onPull, onCancel, deinit_fn, setRefUnrefFn?,
//        drainInternalBuffer?, memoryCostFn?, toBufferedValue?)
// ============================================================================

/// 流数据源上下文接口
/// 对应 Bun: SourceContext trait
/// Each context type (ByteBlobLoader, FileReader, ByteStream) implements this.
/// The comptime fn-pointer bundle from Zig becomes a trait in Rust/Cangjie.
public interface SourceContext {
    /// Context name — used to look up jsc.Codegen.JS{NAME}InternalReadableStreamSource
    /// 对应 Bun: const NAME: &'static str
    func name(): String

    /// Whether setRefUnrefFn is supported
    /// 对应 Bun: const SUPPORTS_REF: bool = false
    func supportsRef(): Bool

    /// Start callback — 对应 Bun: fn on_start(&self) -> streams::Start
    func onStart(): StreamStart

    /// Pull callback — 对应 Bun: fn on_pull(&self, buf: &[u8], view: JsValue) -> streams::Result
    func onPull(buf: Array<UInt8>, view: JsValue): StreamResult

    /// Cancel callback — 对应 Bun: fn on_cancel(&self)
    func onCancel(): Unit

    /// Per-context teardown side-effects. Must NOT free the enclosing
    /// NewSource<Self> allocation — that is done by the caller (decrement_count)
    /// after this returns.
    /// 对应 Bun: fn deinit_fn(&self)
    func onDeinit(): Unit

    /// setRefUnrefFn — default no-op (Zig: ?fn, null => ref/unref are no-ops)
    /// 对应 Bun: fn set_ref_unref(&self, _enable: bool) {}
    func setRefUnref(enable: Bool): Unit

    /// drainInternalBuffer — default returns empty (Zig: ?fn, null => .{})
    /// 对应 Bun: fn drain_internal_buffer(&self) -> Vec<u8> { Vec::default() }
    func drainInternalBuffer(): Array<UInt8>

    /// memoryCostFn — default returns 0; NewSource::memory_cost adds size_of::<Self>()
    /// 对应 Bun: fn memory_cost_fn(&self) -> usize { 0 }
    func memoryCostFn(): Int64

    /// toBufferedValue — 返回 None 表示 "not implemented" (调用方会抛出未实现错误).
    /// 对应 Bun: fn to_buffered_value(global, action) -> Option<JsResult<JsValue>> { None }
    func toBufferedValue(action: BufferActionTag): ?JsValue

    /// setRawMode — default: not present (returns None).
    /// 对应 Bun: fn set_raw_mode(&self, _flag: bool) -> Option<SyscallResult<()>> { None }
    func setRawMode(flag: Bool): ?SyscallError

    /// setFlowing — default no-op.
    /// 对应 Bun: fn set_flowing(&self, _flag: bool) {}
    func setFlowing(flag: Bool): Unit
}

// ============================================================================
// NewSourceCodegen - codegen 面向的接口
// 对应 Bun: pub trait NewSourceCodegen
// Zig: js = @field(jsc.Codegen, "JS" ++ name ++ "InternalReadableStreamSource")
// ============================================================================

/// Codegen-facing interface for NewSource
/// 对应 Bun: NewSourceCodegen trait
/// Binds the four SourceContext::js_* accessors to the codegen'd module.
public interface NewSourceCodegen {
    /// 对应 Bun: fn to_js(&self, global_this) -> JsValue
    func toJs(global: JsGlobalObject): JsValue
    /// 对应 Bun: fn pending_promise_set_cached(this, global, value)
    func pendingPromiseSetCached(thisValue: JsValue, global: JsGlobalObject, value: JsValue): Unit
    /// 对应 Bun: fn on_drain_callback_set_cached(this, global, value)
    func onDrainCallbackSetCached(thisValue: JsValue, global: JsGlobalObject, value: JsValue): Unit
    /// 对应 Bun: fn on_drain_callback_get_cached(this) -> Option<JsValue>
    func onDrainCallbackGetCached(thisValue: JsValue): ?JsValue
}

// ============================================================================
// NewSource - 泛型流数据源包装
// 对应 Bun: NewSource<C: SourceContext> (repr(C))
// Zig: pub fn NewSource(comptime Context: type, ...) type { return struct {...} }
//
// repr(C) keeps `context` at offset 0: C++ wrapped() returns *NewSource<C>
// and ReadableStream::from_js casts that straight to *C.
// ============================================================================

/// 泛型流数据源包装
/// 对应 Bun: NewSource<C: SourceContext>
/// Heap-allocated; ownership transfers to the JS wrapper as m_ctx.
/// The GC finalizer drives teardown through decrement_count -> context deinit_fn.
public class NewSource {
    /// 上下文 (第一个字段，偏移为 0)
    /// 对应 Bun: pub context: C
    public var context: SourceContext
    /// 是否已取消
    /// 对应 Bun: pub cancelled: bool
    public var cancelled: Bool
    /// 引用计数
    /// 对应 Bun: pub ref_count: u32
    public var refCount: UInt32
    /// 待处理错误
    /// 对应 Bun: pub pending_err: Option<syscall::Error>
    public var pendingErr: ?SyscallError
    /// 关闭处理函数
    /// 对应 Bun: pub close_handler: Option<fn(Option<*c_void>)>
    public var closeHandler: ?(() -> Unit)
    /// 关闭上下文指针
    /// 对应 Bun: pub close_ctx: Option<NonNull<c_void>>
    public var closeCtx: ?UIntPtr
    /// 关闭 JS 值 (Strong Optional)
    /// 对应 Bun: pub close_jsvalue: bun_jsc::strong::Optional
    public var closeJsvalue: JsStrongOptional
    /// 取消处理函数 (interior-mutable via Cell)
    /// 对应 Bun: pub cancel_handler: Cell<Option<fn(Option<*c_void>)>>
    public var cancelHandler: ?(() -> Unit)
    /// 取消上下文指针 (interior-mutable via Cell)
    /// 对应 Bun: pub cancel_ctx: Cell<Option<*c_void>>
    public var cancelCtx: ?UIntPtr
    /// 全局对象引用 (BackRef)
    /// 对应 Bun: pub global_this: Option<bun_ptr::BackRef<JSGlobalObject>>
    public var globalThis: ?JsGlobalObject
    /// 自身 JS 值 (points at the JSCell that owns this m_ctx)
    /// 对应 Bun: pub this_jsvalue: JsValue
    public var thisJsvalue: JsValue
    /// 是否已关闭 (interior-mutable via Cell)
    /// 对应 Bun: pub is_closed: Cell<bool>
    public var isClosed: Bool

    public init(context: SourceContext) {
        this.context = context
        cancelled = false
        refCount = 1
        pendingErr = None
        closeHandler = None
        closeCtx = None
        closeJsvalue = JsStrongOptional.empty()
        cancelHandler = None
        cancelCtx = None
        globalThis = None
        thisJsvalue = JsValue.ZERO
        isClosed = false
    }

    /// Default constructor — 对应 Bun: impl Default for NewSource<C>
    public static func create(context: SourceContext): NewSource {
        NewSource(context)
    }

    // ========================================================================
    // 生命周期管理 — 对应 Bun: impl NewSource<C>
    // ========================================================================

    /// 获取全局对象 (safe accessor)
    /// 对应 Bun: pub fn global_this(&self) -> &JSGlobalObject
    /// BackRef gives a safe Deref projection without propagating a lifetime.
    public func getGlobalThis(): JsGlobalObject {
        match (globalThis) {
            case Some(g) => g
            None => throw Exception("NewSource.globalThis used before init")
        }
    }

    /// Pull data from the context
    /// 对应 Bun: pub fn pull(&self, buf: &[u8]) -> streams::Result
    public func pull(buf: Array<UInt8>): StreamResult {
        context.onPull(buf, JsValue.ZERO)
    }

    /// Increment ref (r#ref in Rust, ref is a keyword)
    /// 对应 Bun: pub fn r#ref(&self)
    public func refSource(): Unit {
        if (context.supportsRef()) {
            context.setRefUnref(true)
        }
    }

    /// Decrement ref (unref)
    /// 对应 Bun: pub fn unref(&self)
    public func unrefSource(): Unit {
        if (context.supportsRef()) {
            context.setRefUnref(false)
        }
    }

    /// Set ref to specified value
    /// 对应 Bun: pub fn set_ref(&self, value: bool)
    public func setRef(value: Bool): Unit {
        if (context.supportsRef()) {
            context.setRefUnref(value)
        }
    }

    /// Start the source
    /// 对应 Bun: pub fn start(&self) -> streams::Start
    public func start(): StreamStart {
        context.onStart()
    }

    /// Pull from JS callback
    /// 对应 Bun: pub fn on_pull_from_js(&self, buf, view) -> streams::Result
    public func onPullFromJs(buf: Array<UInt8>, view: JsValue): StreamResult {
        context.onPull(buf, view)
    }

    /// Start from JS callback
    /// 对应 Bun: pub fn on_start_from_js(&self) -> streams::Start
    public func onStartFromJs(): StreamStart {
        context.onStart()
    }

    /// Cancel the source
    /// 对应 Bun: pub fn cancel(&self)
    public func cancel(): Unit {
        if (cancelled) {
            return
        }
        cancelled = true
        context.onCancel()
        match (cancelHandler) {
            case Some(handler) =>
                handler()
                cancelHandler = None
            case None => ()
        }
    }

    /// Handle close
    /// 对应 Bun: pub fn on_close(&self)
    /// Zig: if (close == &JSReadableStreamSource.onClose) — identity check
    /// against the exact fn pointer stored by set_on_close_from_js, so the
    /// JS path receives self (not close_ctx, which is unset on that path).
    public func onClose(): Unit {
        if (cancelled) {
            return
        }
        match (closeHandler) {
            case Some(close) =>
                closeHandler = None
                close()
            case None => ()
        }
    }

    /// JS close handler (on_js_close)
    /// 对应 Bun: fn on_js_close(ptr: Option<*c_void>)
    /// Invoked via close_handler when the JS side registered an onclose callback.
    public func onJsClose(): Unit {
        match (closeJsvalue.get()) {
            case Some(cb) =>
                // Queue microtask with the callback
                // In real implementation: globalThis().queue_microtask(cb, &[])
                queueMicrotask(cb)
            case None => ()
        }
        closeJsvalue.deinit()
    }

    /// Increment reference count
    /// 对应 Bun: pub fn increment_count(&self)
    public func incrementCount(): Unit {
        refCount = refCount + 1
    }

    /// Decrement reference count
    /// 对应 Bun: pub unsafe fn decrement_count(`this`: *Self) -> u32
    /// Release one reference. If the count hits zero, runs context teardown
    /// and frees the allocation (bun.destroy(this)).
    /// SAFETY: caller must ensure `this` is live and not accessed after return.
    public func decrementCount(): UInt32 {
        if (refCount == 0) {
            throw Exception("Attempted to decrement ref count below zero")
        }
        refCount = refCount - 1
        if (refCount == UInt32(0)) {
            // Still live; run side-effect teardown while fields are valid
            closeJsvalue.deinit()
            context.onDeinit()
            // In real implementation: drop(Box::from_raw(this))
            return 0
        }
        refCount
    }

    /// Get pending error
    /// 对应 Bun: pub fn get_error(&self) -> Option<syscall::Error>
    public func getError(): ?SyscallError {
        let err = pendingErr
        pendingErr = None
        err
    }

    /// Drain the internal buffer
    /// 对应 Bun: pub fn drain(&self) -> Vec<u8>
    public func drain(): Array<UInt8> {
        context.drainInternalBuffer()
    }

    /// Convert to ReadableStream JS value
    /// 对应 Bun: pub fn to_readable_stream(&self, global_this) -> JsResult<JsValue>
    pub func toReadableStream(): JsValue {
        let outValue = if (thisJsvalue != JsValue.ZERO) {
            thisJsvalue
        } else {
            contextToJs()
        }
        thisJsvalue = outValue
        ReadableStream.fromNative(outValue)
    }

    /// Convert to ReadableStream JS value (with global)
    pub func toReadableStream(global: JsGlobalObject): JsValue {
        let outValue = if (thisJsvalue != JsValue.ZERO) {
            thisJsvalue
        } else {
            contextToJs()
        }
        thisJsvalue = outValue
        ReadableStream.fromNative(global, outValue)
    }

    /// Context to JS (internal helper)
    /// 对应 Bun: NewSourceCodegen::to_js implementation
    private func contextToJs(): JsValue {
        // Create JS wrapper for the internal readable stream source
        let obj = JsObject()
        JsValue(obj)
    }

    /// Set raw mode from JS
    /// 对应 Bun: pub fn set_raw_mode_from_js(this, global, call_frame)
    public func setRawModeFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        let flag = callFrame.argument(0)
        match (context.setRawMode(flag.toBoolean())) {
            case Some(err) =>
                // Return error as JS value
                JsValue(BaoString(err.message))
            case None =>
                // Zig: @compileError — should never reach here
                JsValue.UNDEFINED
        }
    }

    /// Set flowing mode from JS
    /// 对应 Bun: pub fn set_flowing_from_js(this, global, call_frame)
    public func setFlowingFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        let flag = callFrame.argument(0)
        context.setFlowing(flag.toBoolean())
        JsValue.UNDEFINED
    }

    /// Memory cost
    /// 对应 Bun: pub fn memory_cost(&self) -> usize
    pub func memoryCost(): Int64 {
        context.memoryCostFn() + 128  // approximate sizeof(Self)
    }

    // ========================================================================
    // codegen-facing inherent methods
    // 对应 Bun: impl NewSource<C> (codegen-facing inherent methods)
    // Zig: pub const drainFromJS = JSReadableStreamSource.drain; etc.
    // The .classes.ts -> generated_classes.rs thunks call these by exact name.
    // ========================================================================

    /// Pull from JS entry point (codegen thunk)
    /// 对应 Bun: pub fn pull_from_js(&self, global_this, call_frame)
    public func pullFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        let thisJsvalue = callFrame.this()
        let arguments = callFrame.arguments(2)
        let view = arguments[0]
        this.thisJsvalue = thisJsvalue

        match (view.asArrayBuffer()) {
            case Some(buffer) =>
                let result = onPullFromJs(buffer, view)
                return processResult(thisJsvalue, arguments[1], result)
            case None =>
                return JsValue.UNDEFINED
        }
    }

    /// Start from JS entry point (codegen thunk)
    /// 对应 Bun: pub fn start_from_js(&self, global_this, call_frame)
    public func startFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        globalThis = Some(global)
        thisJsvalue = callFrame.this()
        let startResult = context.onStart()
        match (startResult.tag) {
            case StreamStartTag.Empty => JsValue.jsNumber(0.0)
            case StreamStartTag.Ready => JsValue.jsNumber(16384.0)
            case StreamStartTag.ChunkSize => JsValue.jsNumber(startResult.chunkSize)
            case StreamStartTag.Err =>
                match (startResult.err) {
                    case Some(e) => JsValue(BaoString(e.message))
                    case None => JsValue.UNDEFINED
                }
            case StreamStartTag.OwnedAndDone => JsValue.jsNumber(startResult.ownedData.size)
            case _ => JsValue.UNDEFINED
        }
    }

    /// Get isClosed from JS (codegen thunk)
    /// 对应 Bun: pub fn get_is_closed_from_js(&self, _global_object) -> JsValue
    public func getIsClosedFromJs(): JsValue {
        JsValue(isClosed)
    }

    /// Process stream result — centralised error/done/pending handling
    /// 对应 Bun: fn process_result(this_jsvalue, global_this, flags, result)
    /// PORT NOTE: Zig matches on the union and falls through to result.toJS
    /// for non-handled tags.
    public func processResult(
        thisJsvalue: JsValue,
        flags: JsValue,
        result: StreamResult
    ): JsValue {
        match (result.tag) {
            case StreamResultTag.Err =>
                match (result.err) {
                    case Some(err) =>
                        // Throw the error
                        JsValue(BaoString("Stream error"))
                    case None => JsValue.UNDEFINED
                }
            case StreamResultTag.Pending =>
                let out = result.toJsValue()
                // Set pending promise cached on the JS wrapper
                // In real implementation: pending_promise_set_cached(thisJsvalue, global, out)
                out
            case StreamResultTag.TemporaryAndDone =>
                // Set done=true at flags[0]
                let value = JsValue.TRUE
                // In real implementation: JSObjectSetPropertyAtIndex for flags[0]
                result.toJsValue()
            case StreamResultTag.OwnedAndDone =>
                let value = JsValue.TRUE
                result.toJsValue()
            case StreamResultTag.IntoArrayAndDone =>
                let value = JsValue.TRUE
                result.toJsValue()
            case _ => result.toJsValue()
        }
    }

    /// Cancel from JS entry point (codegen thunk)
    /// 对应 Bun: pub fn cancel_from_js(&self, _global_object, call_frame)
    public func cancelFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        thisJsvalue = callFrame.this()
        cancel()
        JsValue.UNDEFINED
    }

    /// Set onclose callback from JS
    /// 对应 Bun: pub fn set_on_close_from_js(&self, global_object, value)
    /// Store the handler by identity — on_close compares the stored fn pointer
    /// against on_js_close to decide whether to pass self (JS path) or close_ctx
    /// (native path).
    public func setOnCloseFromJs(global: JsGlobalObject, value: JsValue): Unit {
        closeHandler = Some({
            onJsClose()
        })
        globalThis = Some(global)

        if (value.isUndefined()) {
            closeJsvalue.deinit()
            return
        }

        if (!value.isCallable()) {
            return
        }
        closeJsvalue = JsStrongOptional.create(value, global)
    }

    /// Set onDrain callback from JS
    /// 对应 Bun: pub fn set_on_drain_from_js(&self, global_object, value)
    public func setOnDrainFromJs(global: JsGlobalObject, value: JsValue): Unit {
        globalThis = Some(global)

        if (value.isUndefined()) {
            // In real implementation: on_drain_callback_set_cached(thisJsvalue, global, UNDEFINED)
            return
        }

        if (!value.isCallable()) {
            return
        }
        // In real implementation: on_drain_callback_set_cached(thisJsvalue, global, cb)
    }

    /// Get onclose callback from JS
    /// 对应 Bun: pub fn get_on_close_from_js(&self, _global_object) -> JsValue
    public func getOnCloseFromJs(): JsValue {
        match (closeJsvalue.get()) {
            case Some(v) => v
            case None => JsValue.UNDEFINED
        }
    }

    /// Get onDrain callback from JS
    /// 对应 Bun: pub fn get_on_drain_from_js(&self, _global_object) -> JsValue
    public func getOnDrainFromJs(): JsValue {
        // In real implementation: on_drain_callback_get_cached(thisJsvalue)
        JsValue.UNDEFINED
    }

    /// Update ref from JS entry point
    /// 对应 Bun: pub fn update_ref_from_js(&self, _global_object, call_frame)
    public func updateRefFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        thisJsvalue = callFrame.this()
        let refOrUnref = callFrame.argument(0).toBoolean()
        setRef(refOrUnref)
        JsValue.UNDEFINED
    }

    /// Finalize (GC finalizer)
    /// 对应 Bun: pub fn finalize(self: Box<Self>)
    /// Refcounted: decrement_count releases the JS wrapper's +1; allocation
    /// may outlive this call if other refs remain.
    public func finalize(): Unit {
        thisJsvalue = JsValue.ZERO
        decrementCount()
    }

    /// Drain from JS entry point
    /// 对应 Bun: pub fn drain_from_js(&self, global_this, call_frame)
    /// Ownership of the buffer transfers to JSC: ArrayBuffer::from_bytes installs
    /// a deallocator which frees on GC. Suppress Vec::Drop so the same allocation
    /// isn't freed twice.
    public func drainFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        thisJsvalue = callFrame.this()
        let list = drain()
        if (list.size > 0) {
            JsValue.arrayBuffer(list)
        } else {
            JsValue.UNDEFINED
        }
    }

    // ========================================================================
    // to_buffered_value_from_js series methods
    // 对应 Bun: text/arrayBuffer/blob/bytes/json_from_js
    // PORT NOTE: All share the same body modulo BufferActionTag.
    // Collapsed into one helper to avoid 5x drift.
    // ========================================================================

    /// Text from JS
    /// 对应 Bun: pub fn text_from_js
    public func textFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        toBufferedValueFromJs(global, callFrame, BufferActionTag.Text)
    }

    /// ArrayBuffer from JS
    /// 对应 Bun: pub fn array_buffer_from_js
    public func arrayBufferFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        toBufferedValueFromJs(global, callFrame, BufferActionTag.ArrayBuffer)
    }

    /// Blob from JS
    /// 对应 Bun: pub fn blob_from_js
    public func blobFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        toBufferedValueFromJs(global, callFrame, BufferActionTag.Blob)
    }

    /// Bytes from JS
    /// 对应 Bun: pub fn bytes_from_js
    public func bytesFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        toBufferedValueFromJs(global, callFrame, BufferActionTag.Bytes)
    }

    /// JSON from JS
    /// 对应 Bun: pub fn json_from_js
    public func jsonFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        toBufferedValueFromJs(global, callFrame, BufferActionTag.Json)
    }

    /// Common buffered value helper
    /// 对应 Bun: fn to_buffered_value_from_js(global, call_frame, action)
    /// When toBufferedValue is not available, Bun throws TODO via globalThis.throwTODO
    private func toBufferedValueFromJs(global: JsGlobalObject, callFrame: CallFrame, action: BufferActionTag): JsValue {
        thisJsvalue = callFrame.this()
        match (context.toBufferedValue(action)) {
            case Some(v) => v
            // Bun original - not implemented in upstream: globalThis.throwTODO("This is not implemented yet"); return .zero
            // Bun: src/runtime/webcore/ReadableStream.zig:788,800,812,824,836
            case None => global.createErrorInstance("This is not implemented yet")
        }
    }
}

// ============================================================================
// ReadableStreamDefaultReader - 可读流默认读取器
// 对应 Web API: ReadableStreamDefaultReader
// ============================================================================

/// ReadableStreamDefaultReader — 可读流默认读取器
/// 对应 Web API: ReadableStreamDefaultReader
public class ReadableStreamDefaultReader {
    /// 关联的流
    public var stream: ReadableStream
    /// 读取位置
    public var position: Int64

    public init(stream: ReadableStream) {
        this.stream = stream
        position = 0
    }

    /// 读取下一个块
    /// 对应 Web API: reader.read()
    public func read(): ReadResult {
        if (position < stream.source.buffer.size) {
            let chunk = ArrayList<UInt8>()
            let chunkSize = 4096
            var count = 0
            while (position < stream.source.buffer.size && count < chunkSize) {
                chunk.append(stream.source.buffer[position])
                position += 1
                count += 1
            }
            let done = position >= stream.source.buffer.size && stream.source.hasReceivedLastChunk
            ReadResult(Some(chunk.toArray()), done)
        } else {
            if (stream.source.hasReceivedLastChunk) {
                ReadResult(None, true)
            } else {
                ReadResult(None, false)
            }
        }
    }

    /// 释放读取器锁
    /// 对应 Web API: reader.releaseLock()
    public func releaseLock(): Unit {
        stream.locked = false
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("read", JsValue.nativeFunction(JsNativeFunction("read") { _ =>
            let result = self.read()
            let resultObj = JsObject()
            match (result.value) {
                case Some(bytes) =>
                    let arr = ArrayList<JsValue>()
                    for (b in bytes) {
                        arr.append(JsValue(Float64(Int64(b))))
                    }
                    resultObj.set("value", JsValue.array(arr))
                case None => resultObj.set("value", JsValue.UNDEFINED)
            }
            resultObj.set("done", JsValue(result.done))
            JsValue(resultObj)
        }))

        obj.set("releaseLock", JsValue.nativeFunction(JsNativeFunction("releaseLock") { _ =>
            self.releaseLock()
            JsValue.UNDEFINED
        }))

        obj.set("closed", JsValue(JsPromise.resolved(JsValue.UNDEFINED).toJsValue()))

        JsValue(obj)
    }
}

// ============================================================================
// ReadResult - 读取结果
// 对应 Web API: ReadableStreamDefaultReader 返回值
// ============================================================================

/// 读取结果
/// 对应 Web API: ReadableStreamDefaultReader 返回值 { value, done }
public class ReadResult {
    /// 值 (字节数组)
    public var value: ?Array<UInt8>
    /// 是否完成
    public var done: Bool

    public init(value: ?Array<UInt8>, done: Bool) {
        this.value = value
        this.done = done
    }
}

// ============================================================================
// BufferActionTag - 缓冲动作标签
// 对应 Bun: streams.BufferActionTag
// ============================================================================

/// 缓冲动作标签
/// 对应 Bun: streams.BufferActionTag
public enum BufferActionTag {
    | Text
    | ArrayBuffer
    | Blob
    | Bytes
    | Json
}

// ============================================================================
// 辅助函数
// ============================================================================

/// ByteBlobLoader toAnyBlob helper
/// 对应 Bun: ByteBlobLoader.to_any_blob()
public func blobLoaderToAnyBlob(loader: ByteBlobLoader): ?AnyBlob {
    if (loader.done) {
        return None
    }
    match (loader.store) {
        case Some(store) =>
            let data = store.bytes
            if (data.size > 0) {
                let b = Blob(data, loader.contentType)
                return Some(AnyBlob.fromBlob(b))
            }
        case None => ()
    }
    None
}

/// FileReader toAnyBlob helper
/// 对应 Bun: FileReader path in to_any_blob
public func fileReaderToAnyBlob(reader: FileReader): ?AnyBlob {
    None
}

/// ByteStream toAnyBlob helper
/// 对应 Bun: ByteStream.to_any_blob()
public func byteStreamToAnyBlob(bs: ByteStream): ?AnyBlob {
    if (bs.hasReceivedLastChunk) {
        let bytes = bs.buffer.toArray()
        if (bytes.size > 0) {
            let b = Blob(bytes, "")
            return Some(AnyBlob.fromBlob(b))
        }
    }
    None
}

/// ByteStream cancel helper
/// 对应 Bun: ByteStream parent cancel
public func byteStreamCancel(bs: ByteStream): Unit {
    bs.done = true
}

/// ByteStream unpipe without deref
/// 对应 Bun: ByteStream.unpipeWithoutDeref()
public func byteStreamUnpipeWithoutDeref(bs: ByteStream): Unit {
    bs.pipeCallback = None
}

/// Queue microtask (placeholder)
func queueMicrotask(cb: JsValue): Unit {
    // Placeholder: in real implementation queues on the event loop
}

/// StreamResult to JsValue helper
public func streamResultToJsValue(result: StreamResult): JsValue {
    match (result.tag) {
        case StreamResultTag.Done => JsValue.TRUE
        case StreamResultTag.Owned => JsValue.arrayBuffer(result.ownedData.toArray())
        case StreamResultTag.OwnedAndDone => JsValue.arrayBuffer(result.ownedData.toArray())
        case StreamResultTag.Temporary => JsValue.arrayBuffer(result.tempData.toArray())
        case StreamResultTag.TemporaryAndDone => JsValue.arrayBuffer(result.tempData.toArray())
        case StreamResultTag.Pending =>
            match (result.pending) {
                case Some(p) => p.toJsValue()
                case None => JsValue.UNDEFINED
            }
        case StreamResultTag.Err =>
            match (result.err) {
                case Some(e) => JsValue(BaoString("Stream error"))
                case None => JsValue.UNDEFINED
            }
        case _ => JsValue.UNDEFINED
    }
}

/// StreamStart to JsValue helper
public func streamStartToJsValue(start: StreamStart): JsValue {
    match (start.tag) {
        case StreamStartTag.Empty => JsValue.jsNumber(0.0)
        case StreamStartTag.Ready => JsValue.jsNumber(16384.0)
        case StreamStartTag.ChunkSize => JsValue.jsNumber(start.chunkSize)
        case StreamStartTag.OwnedAndDone => JsValue.jsNumber(start.ownedData.size)
        case StreamStartTag.Done => JsValue.jsNumber(start.doneData.size)
        case StreamStartTag.Err =>
            match (start.err) {
                case Some(e) => JsValue(BaoString(e.message))
                case None => JsValue.UNDEFINED
            }
        case _ => JsValue.UNDEFINED
    }
}

// ported from: src/runtime/webcore/ReadableStream.rs
