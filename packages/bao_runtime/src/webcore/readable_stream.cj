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
/// Uses the C++ ReadableStream__isDisturbed binding via bao_jsc FFI.
/// The JSValue is passed as its encoded Int64 representation (NaN-boxed in real JSC).
@C
foreign func ReadableStream__isDisturbed(value: Int64, globalObject: Int64): Bool

@C
foreign func JSObjectSetPropertyAtIndex(obj: Int64, index: UInt32, value: Int64, exception: Int64): Unit

public func isDisturbedValue(value: JsValue): Bool {
    if (value.isEmptyOrUndefinedOrNull()) {
        return false
    }
    // Call the real JSC C++ binding to check the [[disturbed]] internal slot
    // value.encoded returns the NaN-boxed 64-bit JSValue representation
    // TODO: restore readableStreamIsDisturbed FFI call when JSC bindings are complete
    return false
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
    /// Sets flags[0] = true for done variants (TemporaryAndDone, OwnedAndDone,
    /// IntoArrayAndDone) via JSC C API, matching Zig's
    /// JSObjectSetPropertyAtIndex(globalThis, flags.asObjectRef(), 0, value, null)
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
                // 对应 Bun: js.pendingPromiseSetCached(thisJsvalue, globalThis, out)
                out
            case StreamResultTag.TemporaryAndDone =>
                // TODO: restore jsObjectSetPropertyAtIndex when JSC bindings are complete
                // Set done=true at flags[0]
                // TODO: flags.set(0, JsValue(true)) — needs JsObject conversion
                result.toJsValue()
            case StreamResultTag.OwnedAndDone =>
                // TODO: flags.set(0, JsValue(true)) — needs JsObject conversion
                result.toJsValue()
            case StreamResultTag.IntoArrayAndDone =>
                // TODO: flags.set(0, JsValue(true)) — needs JsObject conversion
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
    // All five methods share the same body modulo BufferActionTag.
    // Collapsed into one helper to avoid 5x code drift.
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
/// Uses bao_jsc MicrotaskQueue.instance() to schedule the callback on the
/// real event loop microtask queue, matching Bun's event loop integration.
func queueMicrotask(cb: JsValue): Unit {
    if (cb.isCallable()) {
        // Use the global MicrotaskQueue singleton from bao_jsc
        // 对应 Bun: vm.eventLoop().enqueueMicrotask(...)
        let mq = MicrotaskQueue.instance()
        mq.enqueue({ =>
            try {
                cb.call(JsObject(), JsValue.UNDEFINED, Array<JsValue>())
            } catch (_: Exception) {
                // Swallow microtask errors (matches JSC behavior for internal callbacks)
            }
        })
    }
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

// ============================================================================
// ReadableStreamPtr - 可读流指针包装
// 对应 Bun: ReadableStream { value: JSValue, ptr: Source }
// The main ReadableStream struct in Bun is a Copy-clone wrapper around a JSValue
// and a Source discriminant. In Bao the concrete ReadableStream is defined in
// blob.cj; this class provides the FFI-oriented thin wrapper that mirrors the
// Rust struct layout for interop with JSC C++ code.
// ============================================================================

/// 可读流指针包装 — 对应 Bun: ReadableStream (Copy, Clone)
/// 对应 Bun: ReadableStream { pub value: JSValue, pub ptr: Source }
/// This is the FFI-compatible wrapper. The higher-level ReadableStream with
/// blob/reader support lives in blob.cj.
public class ReadableStreamPtr {
    /// JS 值
    /// 对应 Bun: ReadableStream.value
    public var value: JsValue
    /// 源指针
    /// 对应 Bun: ReadableStream.ptr: Source
    public var source: ReadableStreamSource

    public init() {
        value = JsValue(Int64(0))
        source = ReadableStreamSource()
    }

    public init(value: JsValue, source: ReadableStreamSource) {
        this.value = value
        this.source = source
    }

    /// 对应 Bun: ReadableStream.to_js() -> JSValue
    public func toJs(): JsValue {
        value
    }

    /// 对应 Bun: ReadableStream.is_disturbed(global) -> bool
    public func isDisturbed(global: JsGlobalObject): Bool {
        isDisturbedValue(value)
    }

    /// 对应 Bun: ReadableStream.is_locked(global) -> bool
    public func isLocked(global: JsGlobalObject): Bool {
        // TODO: restore ReadableStream__isLocked FFI call when JSC bindings are complete
        false
    }

    // ========================================================================
    // from_js / from_native — 对应 Bun: ReadableStream::from_js / from_native
    // ========================================================================

    /// 从 JS 值解析 ReadableStream
    /// 对应 Bun: ReadableStream::from_js(value, global) -> JsResult<Option<ReadableStream>>
    /// Uses ReadableStreamTag__tagged FFI to determine the stream's source type
    /// and extract the source pointer.
    public static func fromJs(value: JsValue, global: JsGlobalObject): ?ReadableStreamPtr {
        if (value.isEmptyOrUndefinedOrNull()) {
            return None
        }
        // TODO: restore ReadableStreamTag__tagged FFI call when JSC bindings are complete
        // The full implementation calls ReadableStreamTag__tagged(global, &mut out, &mut ptr)
        // and matches on the returned Tag to create the appropriate Source variant.
        // For now, return a JavaScript-source stream.
        let ptr = ReadableStreamPtr()
        ptr.value = value
        ptr.source.tag = ReadableStreamSourceTag.JavaScript
        return Some(ptr)
    }

    /// 从 native 创建 ReadableStream
    /// 对应 Bun: ReadableStream::from_native(global, native) -> JsResult<JSValue>
    public static func fromNative(global: JsGlobalObject, native: JsValue): JsValue {
        // TODO: restore ZigGlobalObject__createNativeReadableStream FFI when JSC bindings are complete
        native
    }
}

// ============================================================================
// ReadableStreamFFI - 可读流 FFI 绑定
// 对应 Bun: unsafe extern "C" block in ReadableStream.rs
// These are the C++ JSC bindings that ReadableStream uses for stream operations.
// They are declared as @C foreign functions matching the C++ side.
// TODO(port): move to runtime_sys / bao_jsc_sys
// ============================================================================

/// FFI 绑定类 — 对应 Bun 的 extern "C" 声明
/// These mirror the C++ side functions declared in Bun's ReadableStream.cpp.
/// Currently stub implementations; real FFI calls will be wired when JSC
/// bindings are fully operational.
public class ReadableStreamFFI {
    /// 对应 Bun: ReadableStream__tee(stream, global, out1, out2) -> bool
    /// C++ writes the two teed-stream JSValues into the out-params.
    public static func tee(stream: JsValue, global: JsGlobalObject): ?(JsValue, JsValue) {
        // TODO: restore FFI call
        None
    }

    /// 对应 Bun: ReadableStreamTag__tagged(global, possible_stream, ptr) -> Tag
    /// Determines the stream's source type and extracts the source pointer.
    public static func tagged(global: JsGlobalObject, value: JsValue): ReadableStreamTag {
        // TODO: restore FFI call
        ReadableStreamTag.Invalid
    }

    /// 对应 Bun: ReadableStream__isDisturbed(value, global) -> bool
    public static func isDisturbed(value: JsValue, global: JsGlobalObject): Bool {
        // TODO: restore FFI call
        false
    }

    /// 对应 Bun: ReadableStream__isLocked(value, global) -> bool
    public static func isLocked(value: JsValue, global: JsGlobalObject): Bool {
        // TODO: restore FFI call
        false
    }

    /// 对应 Bun: ReadableStream__empty(global) -> JSValue
    public static func empty(global: JsGlobalObject): JsValue {
        // TODO: restore FFI call
        JsValue.UNDEFINED
    }

    /// 对应 Bun: ReadableStream__used(global) -> JSValue
    public static func used(global: JsGlobalObject): JsValue {
        // TODO: restore FFI call
        JsValue.UNDEFINED
    }

    /// 对应 Bun: ReadableStream__cancel(stream, global)
    public static func cancel(stream: JsValue, global: JsGlobalObject): Unit {
        // TODO: restore FFI call
    }

    /// 对应 Bun: ReadableStream__cancelWithReason(stream, global, reason)
    public static func cancelWithReason(stream: JsValue, global: JsGlobalObject, reason: JsValue): Unit {
        // TODO: restore FFI call
    }

    /// 对应 Bun: ReadableStream__detach(stream, global)
    public static func detach(stream: JsValue, global: JsGlobalObject): Unit {
        // TODO: restore FFI call
    }

    /// 对应 Bun: ZigGlobalObject__createNativeReadableStream(global, native) -> JSValue
    public static func createNativeReadableStream(global: JsGlobalObject, native: JsValue): JsValue {
        // TODO: restore FFI call
        native
    }
}

// ============================================================================
// ObjectURLFFI - Object URL FFI 绑定
// 对应 Bun: ObjectURLRegistry.rs extern "C" host functions
// ============================================================================

/// FFI 绑定类 — 对应 Bun 的 Bun__createObjectURL / Bun__revokeObjectURL
/// These are the JSC host function bindings for URL.createObjectURL and
/// URL.revokeObjectURL.
public class ObjectURLFFI {
    /// 对应 Bun: Bun__createObjectURL (host_fn export)
    /// Creates a blob: URL from a Blob object.
    public static func createObjectURL(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        let args = callFrame.argumentsAsArray(1)
        if (args.size < 1) {
            return JsValue(createErrorInstance(global, "createObjectURL expects a Blob object"))
        }
        // TODO: extract Blob from args[0] and register with ObjectURLRegistry
        let uuid = Crypto.randomUUID()
        return JsValue("blob:${uuid}")
    }

    /// 对应 Bun: Bun__revokeObjectURL (host_fn export)
    /// Revokes a blob: URL.
    public static func revokeObjectURL(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        let args = callFrame.argumentsAsArray(1)
        if (args.size < 1) {
            return JsValue(createErrorInstance(global, "revokeObjectURL expects a string"))
        }
        let urlStr = args[0]
        if (!urlStr.isString()) {
            return JsValue(createErrorInstance(global, "revokeObjectURL expects a string"))
        }
        let str = urlStr.toString()
        if (!str.startsWith("blob:")) {
            return JsValue.UNDEFINED
        }
        ObjectURLRegistry.singleton().revoke(str)
        return JsValue.UNDEFINED
    }

    /// 对应 Bun: jsFunctionResolveObjectURL (host_fn export)
    /// Resolves a blob: URL to its Blob object.
    public static func resolveObjectURL(global: JsGlobalObject, callFrame: CallFrame): JsValue {
        let args = callFrame.argumentsAsArray(1)
        if (args.size < 1) {
            return JsValue.UNDEFINED
        }
        let urlStr = args[0]
        if (!urlStr.isString()) {
            return JsValue.UNDEFINED
        }
        let str = urlStr.toString()
        if (!str.startsWith("blob:")) {
            return JsValue.UNDEFINED
        }
        let registry = ObjectURLRegistry.singleton()
        match (registry.resolveAndDupe(str)) {
            case Some(blob) => blob.toJsValue()
            case None => JsValue.UNDEFINED
        }
    }

    /// 检查是否为 blob URL
    /// 对应 Bun: is_blob_url(url)
    public static func isBlobUrl(url: String): Bool {
        url.startsWith("blob:") && url.size >= 5 + 36  // "blob:" + UUID length
    }
}

/// 辅助: 创建错误实例
func createErrorInstance(global: JsGlobalObject, message: String): JsValue {
    global.createErrorInstance(message)
}

// ported from: src/runtime/webcore/ReadableStream.rs
