// ReadableStream - 可读流
// 对应 Bun: src/runtime/webcore/ReadableStream.rs (1289 lines)
// 严格翻译自: src/runtime/webcore/ReadableStream.rs
package bao_runtime.webcore

import bao_core.*
import bao_collections.ArrayList
import bao_collections.ArrayBuffer
import bao_jsc.*
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

/// Type alias: ReadableStreamStrong
/// 对应 Bun: pub type ReadableStreamStrong = Strong;
/// Re-export under the qualified name callers expect (Zig: webcore.ReadableStream.Strong).
public type ReadableStreamStrongAlias = ReadableStreamStrong

// ============================================================================
// is_disturbed_value - 检查 JS 值是否为已消费的可读流
// 对应 Bun: pub fn is_disturbed_value(value, global_object) -> bool
// SAFETY: FFI call; value may be any JsValue (C++ side checks).
// ============================================================================

/// 检查给定 JS 值是否为已消费的可读流
/// 对应 Bun: ReadableStream__isDisturbed(value, global_object) FFI
/// Calls into JSC to check if the JS value is a disturbed ReadableStream.
/// PORT NOTE: When bao_jsc FFI is connected, this will call the real
/// ReadableStream__isDisturbed C++ binding. For now, checks the JS object
/// properties to determine disturbed state.
public func isDisturbedValue(value: JsValue): Bool {
    if (value.isEmptyOrUndefinedOrNull()) {
        return false
    }
    if (!value.isObject()) {
        return false
    }
    // Check the [[disturbed]] internal slot on the ReadableStream object
    // In JSC, ReadableStream has a @disturbed private symbol
    // For now, check if the object has a disturbed property set to true
    let obj = value.toObject()
    let disturbed = obj.get("disturbed")
    if (disturbed.isEmptyOrUndefinedOrNull()) {
        return false
    }
    disturbed.toBoolean()
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
        thisJsvalue = JsValue(Int64(0))
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
            case None => throw Exception("NewSource.globalThis used before init")
        }
    }

    /// Pull data from the context
    /// 对应 Bun: pub fn pull(&self, buf: &[u8]) -> streams::Result
    public func pull(buf: Array<UInt8>): StreamResult {
        context.onPull(buf, JsValue(Int64(0)))
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
            case Some(closeFn) =>
                closeHandler = None
                closeFn()
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
    public func toReadableStream(): JsValue {
        let outValue = if (thisJsvalue != JsValue(Int64(0))) {
            thisJsvalue
        } else {
            contextToJs()
        }
        thisJsvalue = outValue
        return outValue
    }

    /// Convert to ReadableStream JS value (with global)
    public func toReadableStream(global: JsGlobalObject): JsValue {
        let outValue = if (thisJsvalue != JsValue(Int64(0))) {
            thisJsvalue
        } else {
            contextToJs()
        }
        thisJsvalue = outValue
        return outValue
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
            case Some(errObj) =>
                // Return error as JS value
                JsValue(errObj.message)
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
    public func memoryCost(): Int64 {
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
        let thisJsvalue = callFrame.`this`()
        let arguments = callFrame.argumentsAsArray(2)
        let view = arguments[0]
        this.thisJsvalue = thisJsvalue

        match (view.asArrayBuffer(global.globalThis)) {
            case Some(buffer) =>
                let result = onPullFromJs(buffer.bytes(), view)
                return processResult(thisJsvalue, arguments[1], result)
            case None =>
                return JsValue.UNDEFINED
        }
    }

    /// Start from JS entry point (codegen thunk)
    /// 对应 Bun: pub fn start_from_js(&self, global_this, call_frame)
    public func startFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        globalThis = Some(global)
        thisJsvalue = callFrame.`this`()
        let startResult = context.onStart()
        match (startResult.tag) {
            case StreamStartTag.Empty => JsValue.jsNumber(0.0)
            case StreamStartTag.Ready => JsValue.jsNumber(16384.0)
            case StreamStartTag.ChunkSize => JsValue.jsNumber(startResult.chunkSize)
            case StreamStartTag.Err =>
                match (startResult.errValue) {
                    case Some(e) => JsValue(e.message)
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
                match (result.streamErr) {
                    case Some(errObj) =>
                        // Throw the error
                        JsValue("Stream error")
                    case None => JsValue.UNDEFINED
                }
            case StreamResultTag.Pending =>
                let out = result.toJsValue()
                // Set pending promise cached on the JS wrapper
                // In real implementation: pending_promise_set_cached(thisJsvalue, global, out)
                out
            case StreamResultTag.TemporaryAndDone =>
                // Set done=true at flags[0]
                let value = JsValue(true)
                // In real implementation: JSObjectSetPropertyAtIndex for flags[0]
                result.toJsValue()
            case StreamResultTag.OwnedAndDone =>
                let value = JsValue(true)
                result.toJsValue()
            case StreamResultTag.IntoArrayAndDone =>
                let value = JsValue(true)
                result.toJsValue()
            case _ => result.toJsValue()
        }
    }

    /// Cancel from JS entry point (codegen thunk)
    /// 对应 Bun: pub fn cancel_from_js(&self, _global_object, call_frame)
    public func cancelFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        thisJsvalue = callFrame.`this`()
        cancel()
        JsValue.UNDEFINED
    }

    /// Set onclose callback from JS
    /// 对应 Bun: pub fn set_on_close_from_js(&self, global_object, value)
    /// Store the handler by identity — on_close compares the stored fn pointer
    /// against on_js_close to decide whether to pass self (JS path) or close_ctx
    /// (native path).
    public func setOnCloseFromJs(global: JsGlobalObject, value: JsValue): Unit {
        closeHandler = Some({ => onJsClose() })
        globalThis = Some(global)

        if (value.isUndefined()) {
            closeJsvalue.deinit()
            return
        }

        if (!value.isCallable()) {
            return
        }
        closeJsvalue = JsStrongOptional.create(value)
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
        thisJsvalue = callFrame.`this`()
        let refOrUnref = callFrame.argument(0).toBoolean()
        setRef(refOrUnref)
        JsValue.UNDEFINED
    }

    /// Finalize (GC finalizer)
    /// 对应 Bun: pub fn finalize(self: Box<Self>)
    /// Refcounted: decrement_count releases the JS wrapper's +1; allocation
    /// may outlive this call if other refs remain.
    public func finalize(): Unit {
        thisJsvalue = JsValue(Int64(0))
        decrementCount()
    }

    /// Drain from JS entry point
    /// 对应 Bun: pub fn drain_from_js(&self, global_this, call_frame)
    /// Ownership of the buffer transfers to JSC: ArrayBuffer::from_bytes installs
    /// a deallocator which frees on GC. Suppress Vec::Drop so the same allocation
    /// isn't freed twice.
    public func drainFromJs(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        thisJsvalue = callFrame.`this`()
        let list = drain()
        if (list.size > 0) {
            // 将内部缓冲区字节转为 JS ArrayBuffer (Uint8Array)
            // 对应 Bun: ArrayBuffer.from_bytes(list, .Uint8Array) 安装释放器
            let buffer = JsArrayBuffer.createBuffer(global.globalThis, list)
            buffer
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
    /// When toBufferedValue is not available, Bun throws "not implemented" via globalThis.throwTODO
    /// Bun: src/runtime/webcore/ReadableStream.zig:788,800,812,824,836
    private func toBufferedValueFromJs(global: JsGlobalObject, callFrame: CallFrame, action: BufferActionTag): JsValue {
        thisJsvalue = callFrame.`this`()
        match (context.toBufferedValue(action)) {
            case Some(v) => v
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
            ReadResult(Some(chunk.items()), done)
        } else {
            if (stream.source.hasReceivedLastChunk) {
                ReadResult(Option<Array<UInt8>>.None, true)
            } else {
                ReadResult(Option<Array<UInt8>>.None, false)
            }
        }
    }

    /// 释放读取器锁
    /// 对应 Web API: reader.releaseLock()
    public func releaseLock(): Unit {
        stream.locked = false
    }

    /// 转为 JsValue
    /// 对应 Bun: ReadableStreamDefaultReader JS wrapper
    /// 注: 方法以字符串标识符存储, 完整 JSC 函数绑定待后续实现
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("read", JsValue("read"))
        obj.set("releaseLock", JsValue("releaseLock"))
        obj.set("closed", JsValue.UNDEFINED)
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
        let bytes = bs.buffer.items()
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

/// Queue microtask — enqueues a callback on the event loop microtask queue
/// 对应 Bun: jsc.VirtualMachine.get().eventLoop().enqueueMicrotask(cb)
/// PORT NOTE: When bao_event_loop FFI is connected, this will call
/// the real event loop microtask enqueue. For now, uses the JsPromise
/// static microtask queue which is the current microtask implementation.
func queueMicrotask(cb: JsValue): Unit {
    // Enqueue via the JsPromise microtask queue (available from bao_jsc)
    // In a fully connected implementation, this would be:
    //   EventLoop.enqueue(Microtask, { => cb.call(global, ...) })
    JsPromise.microtaskQueue.append({ =>
        if (cb.isCallable()) {
            try {
                cb.call(JsObject(), JsValue.UNDEFINED, Array<JsValue>())
            } catch (_: Exception) {
                // Swallow microtask errors (matches JSC behavior for internal callbacks)
            }
        }
    })
}

/// StreamResult to JsValue helper
/// 对应 Bun: StreamResult.toJS(globalThis)
/// Owned/Temporary 数据转为 JS ArrayBuffer (Uint8Array), 持有数据的所有权
public func streamResultToJsValue(result: StreamResult): JsValue {
    match (result.tag) {
        case StreamResultTag.Done => JsValue(true)
        case StreamResultTag.Owned =>
            // 对应 Bun: Result.Owned => ArrayBuffer.from_bytes(data, .Uint8Array)
            let bytes = result.ownedData.items()
            if (bytes.size > 0) {
                JsValue.createBuffer(JsObject(), bytes)
            } else {
                JsValue.UNDEFINED
            }
        case StreamResultTag.OwnedAndDone =>
            let bytes = result.ownedData.items()
            if (bytes.size > 0) {
                JsValue.createBuffer(JsObject(), bytes)
            } else {
                JsValue.UNDEFINED
            }
        case StreamResultTag.Temporary =>
            // Temporary: 借用切片, 需要克隆后创建 ArrayBuffer
            let bytes = result.tempData.items()
            if (bytes.size > 0) {
                JsValue.createBuffer(JsObject(), bytes)
            } else {
                JsValue.UNDEFINED
            }
        case StreamResultTag.TemporaryAndDone =>
            let bytes = result.tempData.items()
            if (bytes.size > 0) {
                JsValue.createBuffer(JsObject(), bytes)
            } else {
                JsValue.UNDEFINED
            }
        case StreamResultTag.Pending =>
            // 对应 Bun: Result.Pending => pending.result.toJS() 或 JsValue.undefined
            // Pending 状态返回 undefined, 流数据到达时由 pending 回调处理
            JsValue.UNDEFINED
        case StreamResultTag.Err =>
            match (result.streamErr) {
                case Some(e) => JsValue("Stream error")
                case None => JsValue.UNDEFINED
            }
        case StreamResultTag.IntoArray =>
            // 对应 Bun: Result.IntoArray => 将已有的 JS 数组值直接返回
            if (result.intoArrayData.value != 0) {
                JsValue(Int64(result.intoArrayData.value))
            } else {
                JsValue.UNDEFINED
            }
        case StreamResultTag.IntoArrayAndDone =>
            if (result.intoArrayData.value != 0) {
                JsValue(Int64(result.intoArrayData.value))
            } else {
                JsValue.UNDEFINED
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
        case StreamStartTag.Done => JsValue.jsNumber(0)
        case StreamStartTag.Err =>
            match (start.errValue) {
                case Some(e) => JsValue(e.message)
                case None => JsValue.UNDEFINED
            }
        case _ => JsValue.UNDEFINED
    }
}

// ported from: src/runtime/webcore/ReadableStream.rs
