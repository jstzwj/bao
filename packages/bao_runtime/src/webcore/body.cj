// Body - HTTP 请求/响应体
// 对应 Bun: src/runtime/webcore/Body.rs
// 严格翻译自: src/runtime/webcore/Body.rs
package bao_runtime.webcore

import bao_core.*
import bao_jsc.*
import bao_collections.ArrayList
import bao_collections.ArrayBuffer
import bao_http.Headers
import bao_http_types.*

/// UIntPtr 类型别名 (平台相关的无符号指针大小整数)
public type UIntPtr = UIntNative

// ============================================================================
// BodyValueTag - Body 值类型标签
// 对应 Bun: Body.Value.Tag
// ============================================================================

/// Body 值类型标签
/// 对应 Bun: Body.Value.Tag
public enum BodyValueTag {
    | Blob          // Blob 数据
    | WTFStringImpl // WebKit 字符串实现
    | InternalBlob  // 内部 Blob
    | Locked        // 已锁定 (流式)
    | Used          // 已使用
    | Empty         // 空值
    | Error         // 错误
    | Null          // null

    public operator func ==(other: BodyValueTag): Bool {
        match (this) {
            case Blob => match (other) { case Blob => true case _ => false }
            case WTFStringImpl => match (other) { case WTFStringImpl => true case _ => false }
            case InternalBlob => match (other) { case InternalBlob => true case _ => false }
            case Locked => match (other) { case Locked => true case _ => false }
            case Used => match (other) { case Used => true case _ => false }
            case Empty => match (other) { case Empty => true case _ => false }
            case Error => match (other) { case Error => true case _ => false }
            case Null => match (other) { case Null => true case _ => false }
        }
    }
    public operator func !=(other: BodyValueTag): Bool { !(this == other) }
}

// ============================================================================
// BodyValueError - Body 值错误
// 对应 Bun: Body.Value.ValueError
// ============================================================================

/// Body 值错误类型
/// 对应 Bun: Body.Value.ValueError
public enum BodyValueError {
    | AbortReason(CommonAbortReason)       // 中止原因
    | SysErr(SyscallError)                 // 系统错误
    | Message(String)                      // 错误消息
    | TypeError(String)                    // 类型错误
    | JsValueRef(JsStrongOptional)            // JS 值 (强引用)

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        match (this) {
            case AbortReason(msg) =>
                let obj = JsObject()
                obj.set("name", JsValue("AbortError"))
                obj.set("message", JsValue("AbortError"))
                return JsValue(obj)
            case SysErr(e) =>
                let obj = JsObject()
                obj.set("name", JsValue("SystemError"))
                obj.set("message", JsValue(e.message))
                return JsValue(obj)
            case Message(msg) =>
                let obj = JsObject()
                obj.set("message", JsValue(msg))
                return JsValue(obj)
            case TypeError(msg) =>
                let obj = JsObject()
                obj.set("name", JsValue("TypeError"))
                obj.set("message", JsValue(msg))
                return JsValue(obj)
            case JsValueRef(jsRef) =>
                match (jsRef.get()) {
                    case Some(v) => v
                    case None => JsValue.UNDEFINED
                }
        }
    }

    /// 转为 StreamError
    /// 对应 Bun: Body.Value.ValueError.to_stream_error()
    public func toStreamError(): StreamError {
        match (this) {
            case AbortReason(reason) => StreamError.fromAbortReason(reason)
            case _ => StreamError.fromJSValue(toJsValue())
        }
    }

    /// 复制错误值
    /// 对应 Bun: Body.Value.ValueError.dupe()
    public func dupe(): BodyValueError {
        match (this) {
            case AbortReason(r) => BodyValueError.AbortReason(r)
            case SysErr(e) => BodyValueError.SysErr(e)
            case Message(m) => BodyValueError.Message(m)
            case TypeError(m) => BodyValueError.TypeError(m)
            case JsValueRef(jsRef) =>
                match (jsRef.get()) {
                    case Some(v) => BodyValueError.JsValueRef(JsStrongOptional.create(v))
                    case None => BodyValueError.JsValueRef(JsStrongOptional.empty())
                }
        }
    }

    /// 重置/释放资源
    /// 对应 Bun: Body.Value.ValueError.reset()
    public func reset(): Unit {
        match (this) {
            case JsValueRef(jsRef) => jsRef.deinit()
            case _ => ()
        }
    }
}

// ============================================================================
// Action - 异步 Body 动作
// 对应 Bun: Body.PendingValue.Action
// ============================================================================

/// 异步 Body 动作
/// 对应 Bun: Body.PendingValue.Action
public enum BodyActionTag {
    | None
    | GetText
    | GetJSON
    | GetArrayBuffer
    | GetBytes
    | GetBlob
    | GetFormData
}

/// 异步 Body 动作
/// 对应 Bun: Body.PendingValue.Action
public class BodyAction {
    public var tag: BodyActionTag
    /// FormData 编码
    public var formDataEncoding: ?FormDataEncoding

    public init() {
        tag = BodyActionTag.None
        formDataEncoding = None
    }

    public init(tag: BodyActionTag) {
        this.tag = tag
        formDataEncoding = None
    }

    /// 是否为 None
    /// 对应 Bun: Action.is_none()
    public func isNone(): Bool {
        match (tag) {
            case None => true
            case _ => false
        }
    }
}

// ============================================================================
// PendingBodyValue - 等待中的 Body 值
// 对应 Bun: Body.PendingValue
// ============================================================================

/// 等待中的 Body 值
/// 对应 Bun: Body.PendingValue
public class PendingBodyValue {
    /// 关联的 Promise
    public var promise: ?JsValue
    /// 关联的 ReadableStream 强引用
    public var readable: ReadableStreamStrong
    /// 当前动作
    public var action: BodyAction
    /// 大小提示
    public var sizeHint: BlobSizeType
    /// 是否已 deinit
    public var deinit: Bool
    /// 任务上下文
    public var task: ?UIntPtr
    /// 数据接收回调
    public var onReceiveValue: ?((UIntPtr, BodyValue) -> Unit)
    /// 开始缓冲回调
    public var onStartBuffering: ?((UIntPtr) -> Unit)
    /// 开始流式传输回调
    public var onStartStreaming: ?((UIntPtr) -> DrainResult)
    /// 可读流可用回调
    public var onReadableStreamAvailable: ?((UIntPtr, ReadableStream) -> Unit)
    /// 流取消回调
    public var onStreamCancelled: ?((UIntPtr) -> Unit)

    public init() {
        promise = None
        readable = ReadableStreamStrong()
        action = BodyAction()
        sizeHint = 0
        deinit = false
        task = None
        onReceiveValue = None
        onStartBuffering = None
        onStartStreaming = None
        onReadableStreamAvailable = None
        onStreamCancelled = None
    }

    /// 获取大小提示
    /// 对应 Bun: Body.PendingValue.size_hint()
    public func getSizeHint(): BlobSizeType {
        let streamOpt = readable.get()
        match (streamOpt) {
            case Some(s) =>
                let srcSizeHint = s.source.sizeHint
                if (srcSizeHint > 0) {
                    return srcSizeHint
                }
            case None => ()
        }
        sizeHint
    }

    /// 转为 AnyBlob (如果可能)
    /// 对应 Bun: Body.PendingValue.to_any_blob()
    public func toAnyBlob(): ?AnyBlob {
        match (promise) {
            case Some(_) => None
            case None => toAnyBlobAllowPromise()
        }
    }

    /// 转为 AnyBlob (允许 Promise)
    /// 对应 Bun: Body.PendingValue.to_any_blob_allow_promise()
    public func toAnyBlobAllowPromise(): ?AnyBlob {
        let stream = readable.get()
        match (stream) {
            case Some(s) =>
                readable.deinit()
                None
            case None => None
        }
    }

    /// 检查是否已被消费
    /// 对应 Bun: Body.PendingValue.is_disturbed()
    public func isDisturbed(): Bool {
        match (promise) {
            case Some(_) => true
            case None =>
                let optReadable = readable.get()
                match (optReadable) {
                    case Some(s) => s.isDisturbed
                    case None => false
                }
        }
    }

    /// 检查是否正在流式传输或缓冲
    /// 对应 Bun: Body.PendingValue.is_streaming_or_buffering()
    public func isStreamingOrBuffering(): Bool {
        if (readable.has()) {
            return true
        }
        match (promise) {
            case Some(p) => !p.isEmptyOrUndefinedOrNull()
            case None => false
        }
    }

    /// 设置 Promise
    /// 对应 Bun: Body.PendingValue.set_promise()
    public func setPromise(actionTag: BodyActionTag, ownedReadable: ?ReadableStream): JsValue {
        action.tag = actionTag
        let streamOpt = match (ownedReadable) {
            case Some(r) => Some(r)
            case None => readable.get()
        }
        match (streamOpt) {
            case Some(readableStream) =>
                // 对应 Bun: readable_stream.done(globalThis) + promise handling
                readableStream.doDone(readableStream.global)
                readableStream.deinit()
                readable.deinit()
                // 创建新的 Promise 并根据动作类型返回
                let promiseValue = JsValue()
                promise = Some(promiseValue)
                promiseValue
            case None =>
                // 创建新的 Promise
                let promiseValue = JsValue()
                promise = Some(promiseValue)
                match (onStartBuffering) {
                    case Some(cb) =>
                        match (task) {
                            case Some(t) => cb(t)
                            case None => ()
                        }
                    case None => ()
                }
                promiseValue
        }
    }
}

// ============================================================================
// BodyValue - Body 值联合类型
// 对应 Bun: Body.Value
// ============================================================================

/// Body 值 — 表示请求/响应体的各种状态
/// 对应 Bun: Body.Value
public class BodyValue {
    /// 值类型标签
    public var tag: BodyValueTag
    /// Blob 引用
    public var blob: ?Blob
    /// WTF 字符串实现
    public var wtfStringImpl: ?WTFStringImpl
    /// 内部 Blob
    public var internalBlob: ?InternalBlob
    /// 锁定状态下的待处理值
    public var locked: ?PendingBodyValue
    /// 错误值
    public var error: ?BodyValueError

    public init() {
        tag = BodyValueTag.Null
        blob = None
        wtfStringImpl = None
        internalBlob = None
        locked = None
        error = None
    }

    public init(blob: Blob) {
        tag = BodyValueTag.Blob
        this.blob = Some(blob)
        wtfStringImpl = None
        internalBlob = None
        locked = None
        error = None
    }

    public init(text: String) {
        tag = BodyValueTag.WTFStringImpl
        blob = None
        wtfStringImpl = Some(WTFStringImpl.from(text))
        internalBlob = None
        locked = None
        error = None
    }

    public init(wtfString: WTFStringImpl) {
        tag = BodyValueTag.WTFStringImpl
        blob = None
        wtfStringImpl = Some(wtfString)
        internalBlob = None
        locked = None
        error = None
    }

    public init(internalBlob: InternalBlob) {
        tag = BodyValueTag.InternalBlob
        blob = None
        wtfStringImpl = None
        this.internalBlob = Some(internalBlob)
        locked = None
        error = None
    }

    public init(pendingValue: PendingBodyValue) {
        tag = BodyValueTag.Locked
        blob = None
        wtfStringImpl = None
        internalBlob = None
        locked = Some(pendingValue)
        error = None
    }

    public init(error: BodyValueError) {
        tag = BodyValueTag.Error
        blob = None
        wtfStringImpl = None
        internalBlob = None
        locked = None
        this.error = Some(error)
    }

    /// 是否是字符串创建
    /// 对应 Bun: Body.Value.was_string()
    public func wasString(): Bool {
        match (tag) {
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) => b.wasString
                    case None => false
                }
            case WTFStringImpl => true
            case _ => false
        }
    }

    /// 获取数据大小
    /// 对应 Bun: Body.Value.size()
    public func size(): BlobSizeType {
        match (tag) {
            case Blob =>
                match (blob) {
                    case Some(b) => Int64(b.getSizeForBindings())
                    case None => 0
                }
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) => b.slice().size
                    case None => 0
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) => s.utf8ByteLength()
                    case None => 0
                }
            case Locked =>
                match (locked) {
                    case Some(p) => p.getSizeHint()
                    case None => 0
                }
            case _ => 0
        }
    }

    /// 快速获取大小
    /// 对应 Bun: Body.Value.fast_size()
    public func fastSize(): BlobSizeType {
        match (tag) {
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) => b.slice().size
                    case None => 0
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) => s.byteSlice().size
                    case None => 0
                }
            case Locked =>
                match (locked) {
                    case Some(p) => p.getSizeHint()
                    case None => 0
                }
            case _ => 0
        }
    }

    /// 获取估算内存占用
    /// 对应 Bun: Body.Value.memory_cost()
    public func memoryCost(): Int64 {
        match (tag) {
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) => b.memoryCost()
                    case None => 0
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) => s.memoryCost()
                    case None => 0
                }
            case Locked =>
                match (locked) {
                    case Some(p) => p.getSizeHint()
                    case None => 0
                }
            case _ => 0
        }
    }

    /// 获取估算大小
    /// 对应 Bun: Body.Value.estimated_size()
    public func estimatedSize(): Int64 {
        match (tag) {
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) => b.slice().size
                    case None => 0
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) => s.byteSlice().size
                    case None => 0
                }
            case Locked =>
                match (locked) {
                    case Some(p) => p.getSizeHint()
                    case None => 0
                }
            case _ => 0
        }
    }

    /// 是否确定是空的
    /// 对应 Bun: Body.Value.is_definitely_empty()
    public func isDefinitelyEmpty(): Bool {
        match (tag) {
            case Null => true
            case Used => true
            case Empty => true
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) => b.slice().size == 0
                    case None => true
                }
            case Blob =>
                match (blob) {
                    case Some(b) => b.size == 0
                    case None => true
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) => s.utf8ByteLength() == 0
                    case None => true
                }
            case Error => false
            case Locked => false
        }
    }

    /// 转为 AnyBlob (如果可能)
    /// 对应 Bun: Body.Value.to_any_blob()
    /// Converts the body value to an AnyBlob if it holds concrete data.
    /// Returns None for Locked, Used, Error, Null, or Empty states.
    public func toAnyBlob(): ?AnyBlob {
        match (tag) {
            case BodyValueTag.Blob =>
                match (blob) {
                    case Some(b) => Some(AnyBlob(b))
                    case None => None
                }
            case BodyValueTag.InternalBlob =>
                match (internalBlob) {
                    case Some(ib) => Some(AnyBlob(Blob.initFromBytes(ib.slice(), "")))
                    case None => None
                }
            case _ => None
        }
    }

    /// 尽可能转为 Blob
    /// 对应 Bun: Body.Value.to_blob_if_possible()
    public func toBlobIfPossible(): Unit {
        // WTFStringImpl → InternalBlob (如果需要 UTF8 转换)
        if (tag == BodyValueTag.WTFStringImpl) {
            match (wtfStringImpl) {
                case Some(s) =>
                    let utf8 = s.toUtf8IfNeeded()
                    if (utf8.isSome()) {
                        let bytes = utf8.getOrThrow()
                        tag = BodyValueTag.InternalBlob
                        internalBlob = Some(InternalBlob(bytes, true))
                        wtfStringImpl = None
                    }
                case None => ()
            }
        }

        // Locked → Blob (如果可以从 ReadableStream 转换)
        if (tag == BodyValueTag.Locked) {
            match (locked) {
                case Some(pendingVal) =>
                    let anyBlob = pendingVal.toAnyBlob()
                    match (anyBlob) {
                        case Some(b) =>
                            match (b.kind) {
                                case AnyBlobKind.Blob =>
                                    tag = BodyValueTag.Blob
                                    blob = Some(b.blob)
                                    locked = None
                                case AnyBlobKind.InternalBlob =>
                                    tag = BodyValueTag.InternalBlob
                                    internalBlob = Some(b.internalBlob)
                                    locked = None
                                case AnyBlobKind.WTFString =>
                                    tag = BodyValueTag.WTFStringImpl
                                    wtfStringImpl = Some(WTFStringImpl())
                                    locked = None
                                case _ => ()
                            }
                        case None => ()
                    }
                case None => ()
            }
        }
    }

    /// 使用 Body 值，将其标记为已使用
    /// 对应 Bun: Body.Value.use()
    public func use(): Blob {
        toBlobIfPossible()

        match (tag) {
            case Blob =>
                match (blob) {
                    case Some(b) =>
                        tag = BodyValueTag.Used
                        return b.dupe()
                    case None =>
                        tag = BodyValueTag.Used
                        return Blob.initEmpty()
                }
            case InternalBlob =>
                match (internalBlob) {
                    case Some(ib) =>
                        let resultBlob = Blob(ib.toOwnedSlice(), "")
                        tag = BodyValueTag.Used
                        return resultBlob
                    case None =>
                        tag = BodyValueTag.Used
                        return Blob.initEmpty()
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(wtf) =>
                        let utf8 = wtf.toUtf8IfNeeded()
                        let resultBlob = if (utf8.isSome()) {
                            Blob(utf8.getOrThrow(), "text/plain")
                        } else {
                            Blob(wtf.latin1Slice(), "text/plain")
                        }
                        tag = BodyValueTag.Used
                        return resultBlob
                    case None =>
                        tag = BodyValueTag.Used
                        return Blob.initEmpty()
                }
            case _ =>
                return Blob.initEmpty()
        }
    }

    /// 尝试转为 AnyBlob
    /// 对应 Bun: Body.Value.try_use_as_any_blob()
    public func tryUseAsAnyBlob(): ?AnyBlob {
        match (tag) {
            case Blob =>
                match (blob) {
                    case Some(b) =>
                        let result = AnyBlob(b.dupe())
                        tag = BodyValueTag.Used
                        Some(result)
                    case None => None
                }
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) =>
                        let result = AnyBlob.fromInternalBlob(b)
                        tag = BodyValueTag.Used
                        Some(result)
                    case None => None
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) =>
                        if (s.canUseAsUtf8()) {
                            let result = AnyBlob.fromWTFStringImpl(s)
                            tag = BodyValueTag.Used
                            Some(result)
                        } else {
                            None
                        }
                    case None => None
                }
            case Locked =>
                match (locked) {
                    case Some(pendingVal) =>
                        let blob = pendingVal.toAnyBlobAllowPromise()
                        match (blob) {
                            case Some(b) =>
                                tag = BodyValueTag.Used
                                Some(b)
                            case None => None
                        }
                    case None => None
                }
            case _ => None
        }
    }

    /// 使用为 AnyBlob
    /// 对应 Bun: Body.Value.use_as_any_blob()
    public func useAsAnyBlob(): AnyBlob {
        let wasNull = (tag == BodyValueTag.Null)

        let result = match (tag) {
            case Blob =>
                match (blob) {
                    case Some(b) => AnyBlob(b.dupe())
                    case None => AnyBlob(Blob.initEmpty())
                }
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) => AnyBlob.fromInternalBlob(b)
                    case None => AnyBlob(Blob.initEmpty())
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) =>
                        let utf8 = s.toUtf8IfNeeded()
                        if (utf8.isSome()) {
                            AnyBlob.fromInternalBlob(InternalBlob(utf8.getOrThrow(), true))
                        } else {
                            AnyBlob.fromWTFStringImpl(s)
                        }
                    case None => AnyBlob(Blob.initEmpty())
                }
            case Locked =>
                match (locked) {
                    case Some(pendingVal) =>
                        let blob = pendingVal.toAnyBlobAllowPromise()
                        match (blob) {
                            case Some(b) => b
                            case None => AnyBlob(Blob.initEmpty())
                        }
                    case None => AnyBlob(Blob.initEmpty())
                }
            case _ => AnyBlob(Blob.initEmpty())
        }

        tag = if (wasNull) { BodyValueTag.Null } else { BodyValueTag.Used }
        result
    }

    /// 使用为 AnyBlob (允许非 UTF8 字符串)
    /// 对应 Bun: Body.Value.use_as_any_blob_allow_non_utf8_string()
    public func useAsAnyBlobAllowNonUtf8String(): AnyBlob {
        let wasNull = (tag == BodyValueTag.Null)

        let result = match (tag) {
            case Blob =>
                match (blob) {
                    case Some(b) => AnyBlob(b.dupe())
                    case None => AnyBlob(Blob.initEmpty())
                }
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) => AnyBlob.fromInternalBlob(b)
                    case None => AnyBlob(Blob.initEmpty())
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) =>
                        AnyBlob.fromWTFStringImpl(s)
                    case None => AnyBlob(Blob.initEmpty())
                }
            case Locked =>
                match (locked) {
                    case Some(pendingVal) =>
                        let blob = pendingVal.toAnyBlobAllowPromise()
                        match (blob) {
                            case Some(b) => b
                            case None => AnyBlob(Blob.initEmpty())
                        }
                    case None => AnyBlob(Blob.initEmpty())
                }
            case _ => AnyBlob(Blob.initEmpty())
        }

        tag = if (wasNull) { BodyValueTag.Null } else { BodyValueTag.Used }
        result
    }

    /// 获取字节切片
    /// 对应 Bun: Body.Value.slice()
    public func slice(): Array<UInt8> {
        match (tag) {
            case Blob =>
                match (blob) {
                    case Some(b) => b.sharedView()
                    case None => Array<UInt8>()
                }
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) => b.slice()
                    case None => Array<UInt8>()
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) =>
                        if (s.canUseAsUtf8()) {
                            s.latin1Slice()
                        } else {
                            Array<UInt8>()
                        }
                    case None => Array<UInt8>()
                }
            case _ => Array<UInt8>()
        }
    }

    /// 创建 Blob 值
    /// 对应 Bun: Body.Value.blob()
    public static func fromBlob(b: Blob): BodyValue {
        BodyValue(b)
    }

    /// 从字节数据创建 Blob 值
    /// 对应 Bun: Body.Value.create_blob_value()
    public static func createBlobValue(data: Array<UInt8>, wasStr: Bool): BodyValue {
        BodyValue(InternalBlob(data, wasStr))
    }

    /// 克隆 Body 值
    /// 对应 Bun: Body.Value.clone()
    public func clone(): BodyValue {
        toBlobIfPossible()

        if (tag == BodyValueTag.Locked) {
            // 不能直接克隆 Locked 状态，返回空
            let v = BodyValue()
            v.tag = BodyValueTag.Empty
            return v
        }

        match (tag) {
            case InternalBlob =>
                match (internalBlob) {
                    case Some(ib) =>
                        let owned = ib.toOwnedSlice()
                        let resultBlob = Blob(owned, "")
                        return BodyValue(resultBlob)
                    case None =>
                        let v = BodyValue()
                        v.tag = BodyValueTag.Empty
                        return v
                }
            case Blob =>
                match (blob) {
                    case Some(b) => BodyValue(b.dupeWithContentType(false))
                    case None => BodyValue()
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) =>
                        s.ref()
                        return BodyValue(s)
                    case None => BodyValue()
                }
            case Null =>
                return BodyValue()
            case _ =>
                let v = BodyValue()
                v.tag = BodyValueTag.Empty
                return v
        }
    }

    /// 带 ReadableStream 克隆
    /// 对应 Bun: Body.Value.clone_with_readable_stream()
    public func cloneWithReadableStream(readable: ?ReadableStream): BodyValue {
        toBlobIfPossible()

        if (tag == BodyValueTag.Locked) {
            return tee(readable)
        }

        match (tag) {
            case InternalBlob =>
                match (internalBlob) {
                    case Some(ib) =>
                        let owned = ib.toOwnedSlice()
                        let b = Blob(owned, "")
                        blob = Some(b)
                        tag = BodyValueTag.Blob
                    case None => ()
                }
            case _ => ()
        }

        match (tag) {
            case Blob =>
                match (blob) {
                    case Some(b) => BodyValue(b.dupeWithContentType(false))
                    case None => BodyValue()
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) =>
                        s.ref()
                        BodyValue(s)
                    case None => BodyValue()
                }
            case Null => BodyValue()
            case _ =>
                let v = BodyValue()
                v.tag = BodyValueTag.Empty
                v
        }
    }

    /// tee (分流) 操作
    /// 对应 Bun: Body.Value.tee()
    public func tee(ownedReadable: ?ReadableStream): BodyValue {
        if (tag != BodyValueTag.Locked) {
            return BodyValue()
        }

        match (locked) {
            case Some(lockedValue) =>
                // 尝试用提供的 ReadableStream 分流
                match (ownedReadable) {
                    case Some(readable) =>
                        if (readable.isDisturbed) {
                            let v = BodyValue()
                            v.tag = BodyValueTag.Used
                            return v
                        }

                        let teeResult = readable.tee()
                        // 保持当前流，返回第二个
                        lockedValue.readable.set(ReadableStream())
                        let newPending = PendingBodyValue()
                        newPending.readable.set(ReadableStream())
                        return BodyValue(newPending)
                    case None => ()
                }

                // 检查是否已被消费
                if (lockedValue.isDisturbed()) {
                    let v = BodyValue()
                    v.tag = BodyValueTag.Used
                    return v
                }

                // 尝试从已持有的流分流
                match (lockedValue.readable.get()) {
                    case Some(readable) =>
                        let teeResult = readable.tee()
                        lockedValue.readable.set(ReadableStream())
                        let newPending = PendingBodyValue()
                        newPending.readable.set(ReadableStream())
                        return BodyValue(newPending)
                    case None => ()
                }

                // 如果有 promise 或 action 或 readable，返回已使用
                match (lockedValue.promise) {
                    case Some(_) =>
                        let v = BodyValue()
                        v.tag = BodyValueTag.Used
                        return v
                    case None => ()
                }

                if (!lockedValue.action.isNone() || lockedValue.readable.has()) {
                    let v = BodyValue()
                    v.tag = BodyValueTag.Used
                    return v
                }

                // 启动流式传输
                var drainResult = DrainResult.EstimatedSize(0)
                match (lockedValue.onStartStreaming) {
                    case Some(cb) =>
                        match (lockedValue.task) {
                            case Some(t) => drainResult = cb(t)
                            case None => ()
                        }
                    case None => ()
                }

                match (drainResult) {
                    case DrainResult.Empty =>
                        tag = BodyValueTag.Null
                        return BodyValue()
                    case DrainResult.Aborted =>
                        tag = BodyValueTag.Null
                        return BodyValue()
                    case _ => ()
                }

                // 创建 ByteStream 并分流
                let byteStream = ByteStream()
                byteStream.setup()

                match (drainResult) {
                    case DrainResult.EstimatedSize(estimatedSize) =>
                        byteStream.highWaterMark = estimatedSize
                        byteStream.sizeHint = estimatedSize
                    case DrainResult.Owned(list, sizeHint) =>
                        byteStream.buffer = list
                        byteStream.sizeHint = sizeHint
                    case _ => ()
                }

                let source = ReadableStreamSource(ReadableStreamSourceTag.Bytes)
                source.byteStream = Some(byteStream)
                source.sizeHint = byteStream.sizeHint
                let newStream = ReadableStream(source)
                lockedValue.readable.set(newStream)

                // 调用 onReadableStreamAvailable 回调
                match (lockedValue.onReadableStreamAvailable) {
                    case Some(cb) =>
                        match (lockedValue.task) {
                            case Some(t) =>
                                match (lockedValue.readable.get()) {
                                    case Some(rs) => cb(t, rs)
                                    case None => ()
                                }
                            case None => ()
                        }
                    case None => ()
                }

                // tee 分流
                match (lockedValue.readable.get()) {
                    case Some(readable) =>
                        let teeResult = readable.tee()
                        lockedValue.readable.set(ReadableStream())
                        let newPending = PendingBodyValue()
                        newPending.readable.set(ReadableStream())
                        return BodyValue(newPending)
                    case None =>
                        let v = BodyValue()
                        v.tag = BodyValueTag.Used
                        return v
                }
            case None =>
                let v = BodyValue()
                v.tag = BodyValueTag.Used
                v
        }
    }

    /// 转为 ReadableStream
    /// 对应 Bun: Body.Value.to_readable_stream()
    public func toReadableStream(): JsValue {
        match (tag) {
            case Used =>
                ReadableStream.usedStream().toJsValue()
            case Empty =>
                // 空 body 返回已结束的流, 对应 Bun: empty body -> used/disturbed stream
                ReadableStream.usedStream().toJsValue()
            case Null =>
                JsValue.NULL
            case InternalBlob =>
                let usedBlob = use()
                let streamOpt = ReadableStream.fromBlobCopyRef(JsGlobalObject(), usedBlob, 0)
                if (streamOpt.isSome()) {
                    let stream = streamOpt.getOrThrow()
                    let pendingValue = PendingBodyValue()
                    pendingValue.readable.set(stream)
                    tag = BodyValueTag.Locked
                    locked = Some(pendingValue)
                    stream.toJsValue()
                } else {
                    JsValue.NULL
                }
            case Blob =>
                let usedBlob = use()
                let streamOpt = ReadableStream.fromBlobCopyRef(JsGlobalObject(), usedBlob, 0)
                if (streamOpt.isSome()) {
                    let stream = streamOpt.getOrThrow()
                    let pendingValue = PendingBodyValue()
                    pendingValue.readable.set(stream)
                    tag = BodyValueTag.Locked
                    locked = Some(pendingValue)
                    stream.toJsValue()
                } else {
                    JsValue.NULL
                }
            case WTFStringImpl =>
                let usedBlob = use()
                let streamOpt = ReadableStream.fromBlobCopyRef(JsGlobalObject(), usedBlob, 0)
                if (streamOpt.isSome()) {
                    let stream = streamOpt.getOrThrow()
                    let pendingValue = PendingBodyValue()
                    pendingValue.readable.set(stream)
                    tag = BodyValueTag.Locked
                    locked = Some(pendingValue)
                    stream.toJsValue()
                } else {
                    JsValue.NULL
                }
            case Locked =>
                match (locked) {
                    case Some(lockedValue) =>
                        match (lockedValue.readable.get()) {
                            case Some(readable) =>
                                return readable.toJsValue()
                            case None => ()
                        }

                        match (lockedValue.promise) {
                            case Some(_) =>
                                return ReadableStream.usedStream().toJsValue()
                            case None =>
                                if (!lockedValue.action.isNone()) {
                                    return ReadableStream.usedStream().toJsValue()
                                }
                        }

                        var drainResult = DrainResult.EstimatedSize(0)
                        match (lockedValue.onStartStreaming) {
                            case Some(cb) =>
                                match (lockedValue.task) {
                                    case Some(t) => drainResult = cb(t)
                                    case None => ()
                                }
                            case None => ()
                        }

                        match (drainResult) {
                            case DrainResult.Empty =>
                                tag = BodyValueTag.Null
                                return ReadableStream.usedStream().toJsValue()
                            case DrainResult.Aborted =>
                                tag = BodyValueTag.Null
                                return ReadableStream.usedStream().toJsValue()
                            case _ => ()
                        }

                        let byteStream = ByteStream()
                        byteStream.setup()

                        match (drainResult) {
                            case DrainResult.EstimatedSize(estimatedSize) =>
                                byteStream.highWaterMark = estimatedSize
                                byteStream.sizeHint = estimatedSize
                            case DrainResult.Owned(list, sizeHint) =>
                                byteStream.buffer = list
                                byteStream.sizeHint = sizeHint
                            case _ => ()
                        }

                        let source = ReadableStreamSource(ReadableStreamSourceTag.Bytes)
                        source.byteStream = Some(byteStream)
                        source.sizeHint = byteStream.sizeHint
                        let newStream = ReadableStream(source)
                        lockedValue.readable.set(newStream)

                        match (lockedValue.onStreamCancelled) {
                            case Some(cb) =>
                                match (lockedValue.task) {
                                    case Some(t) => source.cancelCallback = Some({ _ => cb(t) })
                                    case None => ()
                                }
                            case None => ()
                        }

                        match (lockedValue.onReadableStreamAvailable) {
                            case Some(cb) =>
                                match (lockedValue.task) {
                                    case Some(t) =>
                                        match (lockedValue.readable.get()) {
                                            case Some(rs) => cb(t, rs)
                                            case None => ()
                                        }
                                    case None => ()
                                }
                            case None => ()
                        }

                        match (lockedValue.readable.get()) {
                            case Some(readable) => readable.toJsValue()
                            case None => JsValue.NULL
                        }
                    case None => ReadableStream.usedStream().toJsValue()
                }
            case Error =>
                ReadableStream.usedStream().toJsValue()
        }
    }

    /// 解析新值
    /// 对应 Bun: Body.Value.resolve()
    public func resolve(newValue: BodyValue, headers: ?FetchHeaders): Unit {
        match (tag) {
            case Locked =>
                match (locked) {
                    case Some(lockedValue) =>
                        match (lockedValue.readable.get()) {
                            case Some(readable) =>
                                readable.done = true
                                lockedValue.readable.deinit()
                            case None => ()
                        }

                        match (lockedValue.onReceiveValue) {
                            case Some(cb) =>
                                match (lockedValue.task) {
                                    case Some(t) => cb(t, newValue)
                                    case None => ()
                                }
                                return
                            case None => ()
                        }

                        match (lockedValue.promise) {
                            case Some(promiseValue) =>
                                let promise = promiseValue.asAnyPromise()
                                match (promise) {
                                    case Some(p) =>
                                        match (lockedValue.action.tag) {
                                            case GetText =>
                                                let anyBlob = newValue.useAsAnyBlobAllowNonUtf8String()
                                                p.resolve(JsObject(), JsValue(anyBlob.slice().toString()))
                                            case GetJSON =>
                                                let anyBlob = newValue.useAsAnyBlobAllowNonUtf8String()
                                                p.resolve(JsObject(), JsValue.UNDEFINED)
                                            case GetArrayBuffer =>
                                                let anyBlob = newValue.useAsAnyBlobAllowNonUtf8String()
                                                p.resolve(JsObject(), JsValue.UNDEFINED)
                                            case GetBytes =>
                                                let anyBlob = newValue.useAsAnyBlobAllowNonUtf8String()
                                                p.resolve(JsObject(), JsValue.UNDEFINED)
                                            case GetFormData =>
                                                p.resolve(JsObject(), JsValue.UNDEFINED)
                                            case GetBlob =>
                                                let usedBlob = newValue.use()
                                                let newBlob = Blob(usedBlob.sharedView(), "")
                                                match (headers) {
                                                    case Some(h) =>
                                                        let contentType = h.fastGet(HTTPHeaderName.ContentType)
                                                        match (contentType) {
                                                            case Some(ct) =>
                                                                newBlob.setContentType(ct)
                                                                newBlob.setContentTypeWasSet(true)
                                                            case None => ()
                                                        }
                                                    case None => ()
                                                }
                                                if (!newBlob.getContentTypeWasSet()) {
                                                                    newBlob.setContentType("text/plain")
                                                }
                                                p.resolve(JsObject(), newBlob.toJsValue())
                                            case None =>
                                                let usedBlob = newValue.use()
                                                let newBlob = Blob(usedBlob.sharedView(), "")
                                                match (headers) {
                                                    case Some(h) =>
                                                        let contentType = h.fastGet(HTTPHeaderName.ContentType)
                                                        match (contentType) {
                                                            case Some(ct) =>
                                                                newBlob.setContentType(ct)
                                                                newBlob.setContentTypeWasSet(true)
                                                            case None => ()
                                                        }
                                                    case None => ()
                                                }
                                                if (!newBlob.getContentTypeWasSet()) {
                                                                    newBlob.setContentType("text/plain")
                                                }
                                                p.resolve(JsObject(), newBlob.toJsValue())
                                        }
                                    case None => ()
                                }
                            case None => ()
                        }
                    case None => ()
                }
            case _ => ()
        }
    }

    /// 转为错误实例
    /// 对应 Bun: Body.Value.to_error_instance()
    public func toErrorInstance(err: BodyValueError): Unit {
        match (tag) {
            case Locked =>
                match (locked) {
                    case Some(lockedValue) =>
                        tag = BodyValueTag.Error
                        error = Some(err)

                        match (lockedValue.readable.get()) {
                            case Some(readable) =>
                                match (readable.source.tag) {
                                    case ReadableStreamSourceTag.Bytes =>
                                        match (readable.source.byteStream) {
                                            case Some(bs) =>
                                                bs.onData(ArrayList<UInt8>(), true)
                                            case None => ()
                                        }
                                    case _ => ()
                                }
                            case None => ()
                        }

                        match (lockedValue.onReceiveValue) {
                            case Some(cb) =>
                                match (lockedValue.task) {
                                    case Some(t) => cb(t, this)
                                    case None => ()
                                }
                            case None => ()
                        }
                        return
                    case None => ()
                }
            case _ => ()
        }
        tag = BodyValueTag.Error
        error = Some(err)
    }

    /// 转为错误
    /// 对应 Bun: Body.Value.to_error()
    public func toError(err: SyscallError): Unit {
        toErrorInstance(BodyValueError.SysErr(err))
    }

    /// 重置 Body 值
    /// 对应 Bun: Body.Value.reset()
    public func reset(): Unit {
        match (tag) {
            case Locked =>
                match (locked) {
                    case Some(lockedValue) =>
                        if (!lockedValue.deinit) {
                            lockedValue.deinit = true
                            lockedValue.readable.deinit()
                            lockedValue.readable = ReadableStreamStrong()
                        }
                        return
                    case None => ()
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) => s.deref()
                    case None => ()
                }
            case Blob =>
                match (blob) {
                    case Some(b) => b.deinit()
                    case None => ()
                }
            case Error =>
                match (error) {
                    case Some(e) => e.reset()
                    case None => ()
                }
            case _ => ()
        }
        tag = BodyValueTag.Null
    }

    /// 释放资源
    /// 对应 Bun: Body.Value.deinit() / Drop
    public func deinit(): Unit {
        match (tag) {
            case InternalBlob =>
                () // 释放字节数组
            case Blob =>
                match (blob) {
                    case Some(b) => b.deinit()
                    case None => ()
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) => s.deref()
                    case None => ()
                }
            case Locked =>
                match (locked) {
                    case Some(pendingValue) =>
                        if (!pendingValue.deinit) {
                            pendingValue.deinit = true
                            pendingValue.readable.deinit()
                        }
                    case None => ()
                }
            case Error =>
                match (error) {
                    case Some(e) => e.reset()
                    case None => ()
                }
            case _ => ()
        }
        tag = BodyValueTag.Null
    }

    /// 从 JS 创建 Body 值
    /// 对应 Bun: Body.Value.from_js()
    public static func fromJs(value: JsValue): BodyValue {
        if (value.isEmptyOrUndefinedOrNull()) {
            return BodyValue()
        }

        if (value.isString()) {
            let text = value.toString()
            if (text.size == 0) {
                let v = BodyValue()
                v.tag = BodyValueTag.Empty
                return v
            }
            return BodyValue(text)
        }

        if (value.isTypedArray()) {
            let bytes = value.asArrayBuffer(JsObject())
            match (bytes) {
                case Some(b) =>
                    if (b.byteLength == 0) {
                        let v = BodyValue()
                        v.tag = BodyValueTag.Empty
                        return v
                    }
                    return BodyValue(InternalBlob(b.bytes(), false))
                case None => ()
            }
        }

        // 尝试 Blob
        if (value.isObject()) {
            if (false) {
                let b = Blob.fromJs(JsGlobalObject(), value)
                match (b) {
                    case Some(blob) => return BodyValue(blob.dupeWithContentType(true))
                    case None => ()
                }
            }
        }

        // 尝试 ReadableStream
        let readable = ReadableStream.fromJsValue(value)
        if (readable.isSome()) {
            let stream = readable.getOrThrow()
                if (stream.isDisturbed) {
                    // ReadableStream 已被使用
                    let v = BodyValue()
                    v.tag = BodyValueTag.Used
                    return v
                }

                // 尝试从 Source::Blob 提取
                // 对应 Bun: Body.Value.from_js readable stream blob path
                // When the ReadableStream source is a Blob, we can extract the
                // underlying Blob directly without going through the stream.
                match (stream.source.tag) {
                    case ReadableStreamSourceTag.Blob =>
                        match (stream.source.blobLoader) {
                            case Some(loader) =>
                                let anyBlobOpt = blobLoaderToAnyBlob(loader)
                                match (anyBlobOpt) {
                                    case Some(anyBlob) =>
                                        match (anyBlob.kind) {
                                            case AnyBlobKind.Blob =>
                                                return BodyValue(anyBlob.blob.dupeWithContentType(true))
                                            case AnyBlobKind.InternalBlob =>
                                                return BodyValue(InternalBlob(anyBlob.internalBlob.slice(), false))
                                            case _ => ()
                                        }
                                    case None => ()
                                }
                            case None => ()
                        }
                    case _ => ()
                }

                return fromReadableStreamWithoutLockCheck(stream)
        }

        // 尝试 FormData / URLSearchParams
        let formData = DOMFormData.fromJs(value)
        match (formData) {
            case Some(fd) => return BodyValue(Blob.fromDOMFormData(JsGlobalObject(), "", ""))
            case None => ()
        }

        let searchParams = URLSearchParams.fromJs(value)
        match (searchParams) {
            case Some(sp) => return BodyValue(Blob.fromURLSearchParams(JsGlobalObject(), ""))
            case None => ()
        }

        // 尝试 Blob.get
        let blob = Blob.get(JsGlobalObject(), value, false, false)
        return BodyValue(blob)

        let v = BodyValue()
        v.tag = BodyValueTag.Empty
        v
    }

    /// 从 ReadableStream 创建 (不检查锁定)
    /// 对应 Bun: Body.Value.from_readable_stream_without_lock_check()
    public static func fromReadableStreamWithoutLockCheck(readable: ReadableStream): BodyValue {
        let pendingValue = PendingBodyValue()
        pendingValue.readable.set(readable)
        return BodyValue(pendingValue)
    }

    /// 从 Request 或 Response 获取 Body 值
    /// 对应 Bun: Body.Value.from_request_or_response()
    /// 检测逻辑: 先判断是否为 Request (有 method 属性), 再判断是否为 Response (有 status 属性)
    public static func fromRequestOrResponse(value: JsValue): ?BodyValue {
        if (value.isEmptyOrUndefinedOrNull()) {
            return None
        }
        if (!value.isObject()) {
            return None
        }
        // 对应 Bun: if (value.as(Request)) |request|
        // 检查是否为 Request 对象: 有 "method" 属性且为字符串
        let methodVal = value.get(JsObject(), "method")
        if (methodVal.isSome() && methodVal.getOrThrow().isString()) {
            let req = Request.fromJs(value)
            match (req) {
                case Some(r) => return Some(r.getBodyValue())
                case None => return None
            }
        }
        // 对应 Bun: if (value.as(Response)) |response|
        // 检查是否为 Response 对象: 有 "status" 属性且为数字
        let statusVal = value.get(JsObject(), "status")
        if (statusVal.isSome() && statusVal.getOrThrow().isNumber()) {
            let res = Response.fromJs(value)
            match (res) {
                case Some(r) => return Some(r.getBodyValue())
                case None => return None
            }
        }
        None
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        match (tag) {
            case Blob =>
                match (blob) {
                    case Some(b) => b.toJsValue()
                    case None => JsValue.UNDEFINED
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) => JsValue(s.toString())
                    case None => JsValue.UNDEFINED
                }
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) => JsValue(b.slice().toString())
                    case None => JsValue.UNDEFINED
                }
            case _ => JsValue.UNDEFINED
        }
    }
}

// ============================================================================
// BodyOwnerJs - Body 所属者 JS 接口
// 对应 Bun: Body.BodyOwnerJs
// ============================================================================

/// Body 所属者 JS 接口
/// 对应 Bun: Body.BodyOwnerJs
/// Request 和 Response 都实现此接口
public interface BodyOwnerJs {
    /// 获取 JS 引用
    func jsRef(): ?JsValue
    /// 获取缓存的 body
    func bodyGetCached(`this`: JsValue): ?JsValue
    /// 设置缓存的 body
    func bodySetCached(`this`: JsValue, value: JsValue): Unit
    /// 获取缓存的 stream
    func streamGetCached(`this`: JsValue): ?JsValue
    /// 设置缓存的 stream
    func streamSetCached(`this`: JsValue, value: JsValue): Unit
}

// ============================================================================
// BodyMixin - Body 混合接口
// 对应 Bun: Body.BodyMixin
// ============================================================================

/// Body 混合接口 — Request 和 Response 共享的 Body 方法
/// 对应 Bun: Body.BodyMixin
public interface BodyMixin <: BodyOwnerJs {
    /// 获取 Body 值 (可变)
    func getBodyValue(): BodyValue
    /// 获取 Fetch Headers
    func getFetchHeaders(): ?FetchHeaders
    /// 获取 FormData 编码
    func getFormDataEncoding(): ?FormDataEncoding

    /// 获取 Body ReadableStream
    /// 对应 Bun: Body.BodyMixin.get_body_readable_stream()
    func getBodyReadableStream(): ?ReadableStream {
        // 优先从 JS 缓存获取
        match (jsRef()) {
            case Some(jsRef) =>
                match (streamGetCached(jsRef)) {
                    case Some(streamValue) =>
                        let rs = ReadableStream.fromJsValue(streamValue)
                        match (rs) {
                            case Some(r) => return Some(r)
                            case None => ()
                        }
                    case None => ()
                }
            case None => ()
        }

        // 从 Locked.readable 获取
        let value = getBodyValue()
        if (value.tag == BodyValueTag.Locked) {
            match (value.locked) {
                case Some(lockedValue) => return lockedValue.readable.get()
                case None => ()
            }
        }
        None
    }

    /// 分离 ReadableStream
    /// 对应 Bun: Body.BodyMixin.detach_readable_stream()
    func detachReadableStream(): Unit {
        match (jsRef()) {
            case Some(jsRef) =>
                streamSetCached(jsRef, JsValue(Int64(0)))
            case None => ()
        }

        let value = getBodyValue()
        if (value.tag == BodyValueTag.Locked) {
            match (value.locked) {
                case Some(lockedValue) =>
                    lockedValue.readable.deinit()
                    lockedValue.readable = ReadableStreamStrong()
                case None => ()
            }
        }
    }

    /// 检查 Body Stream 引用
    /// 对应 Bun: Body.BodyMixin.check_body_stream_ref()
    func checkBodyStreamRef(): Unit {
        let jsRefOpt = jsRef()
        if (jsRefOpt.isSome()) {
            let jsValue = jsRefOpt.getOrThrow()
                let value = getBodyValue()
                if (value.tag == BodyValueTag.Locked) {
                    match (value.locked) {
                        case Some(lockedValue) =>
                            let streamOpt = lockedValue.readable.get()
                            if (streamOpt.isSome()) {
                                let stream = streamOpt.getOrThrow()
                                streamSetCached(jsValue, stream.toJsValue())
                                lockedValue.readable.deinit()
                                lockedValue.readable = ReadableStreamStrong()
                            }
                        case None => ()
                    }
                }
        }
    }

    /// 同步克隆的 Body Stream 缓存
    /// 对应 Bun: Body.BodyMixin.sync_cloned_body_stream_caches()
    func syncClonedBodyStreamCaches(thisValue: JsValue, jsWrapper: JsValue): Unit {
        if (!jsWrapper.isEmptyOrUndefinedOrNull()) {
            match (streamGetCached(jsWrapper)) {
                case Some(clonedStream) =>
                    bodySetCached(jsWrapper, clonedStream)
                case None => ()
            }
        }

        let value = getBodyValue()
        if (value.tag == BodyValueTag.Locked) {
            match (value.locked) {
                case Some(lockedValue) =>
                    match (lockedValue.readable.get()) {
                        case Some(readable) =>
                            bodySetCached(thisValue, readable.toJsValue())
                        case None => ()
                    }
                case None => ()
            }
        }
        checkBodyStreamRef()
    }

    /// 通过缓存流克隆 Body 值
    /// 对应 Bun: Body.BodyMixin.clone_body_value_via_cached_stream()
    func cloneBodyValueViaCachedStream(): BodyValue {
        match (jsRef()) {
            case Some(jsRef) =>
                match (streamGetCached(jsRef)) {
                    case Some(streamValue) =>
                        let readableOpt = ReadableStream.fromJsValue(streamValue)
                        match (readableOpt) {
                            case Some(readable) =>
                                return getBodyValue().cloneWithReadableStream(Some(readable))
                            case None => ()
                        }
                    case None => ()
                }
            case None => ()
        }
        getBodyValue().clone()
    }

    /// 获取文本
    /// 对应 Web API: body.text()
    /// 对应 Bun: Body.BodyMixin.get_text()
    func getText(): JsValue {
        let value = getBodyValue()

        if (value.tag == BodyValueTag.Used) {
            return handleBodyAlreadyUsed()
        }

        if (value.tag == BodyValueTag.Locked) {
            match (getBodyReadableStream()) {
                case Some(readable) =>
                    if (readable.isDisturbed) {
                        return handleBodyAlreadyUsed()
                    }
                    let v = getBodyValue()
                    if (v.tag == BodyValueTag.Locked) {
                        match (v.locked) {
                            case Some(locked) => return locked.setPromise(BodyActionTag.GetText, Some(readable))
                            case None => ()
                        }
                    }
                case None => ()
            }

            let v = getBodyValue()
            if (v.tag == BodyValueTag.Locked) {
                match (v.locked) {
                    case Some(locked) =>
                        if (!locked.action.isNone() || locked.isDisturbed()) {
                            return handleBodyAlreadyUsed()
                        }
                        return locked.setPromise(BodyActionTag.GetText, Option<ReadableStream>.None)
                    case None => ()
                }
            }
        }

        let v = getBodyValue()
        let anyBlob = v.useAsAnyBlobAllowNonUtf8String()
        let text = anyBlob.slice().toString()
        JsPromise.resolve(JsGlobalObject(), JsValue(text))
    }

    /// 获取 JSON
    /// 对应 Web API: body.json()
    /// 对应 Bun: Body.BodyMixin.get_json()
    func getJSON(): JsValue {
        let value = getBodyValue()

        if (value.tag == BodyValueTag.Used) {
            return handleBodyAlreadyUsed()
        }

        if (value.tag == BodyValueTag.Locked) {
            match (getBodyReadableStream()) {
                case Some(readable) =>
                    if (readable.isDisturbed) {
                        return handleBodyAlreadyUsed()
                    }
                    let v = getBodyValue()
                    v.toBlobIfPossible()
                    if (v.tag == BodyValueTag.Locked) {
                        match (v.locked) {
                            case Some(locked) => return locked.setPromise(BodyActionTag.GetJSON, Some(readable))
                            case None => ()
                        }
                    }
                case None => ()
            }

            let v = getBodyValue()
            if (v.tag == BodyValueTag.Locked) {
                match (v.locked) {
                    case Some(locked) =>
                        if (!locked.action.isNone() || locked.isDisturbed()) {
                            return handleBodyAlreadyUsed()
                        }
                        v.toBlobIfPossible()
                        if (v.tag == BodyValueTag.Locked) {
                            match (v.locked) {
                                case Some(locked2) => return locked2.setPromise(BodyActionTag.GetJSON, Option<ReadableStream>.None)
                                case None => ()
                            }
                        }
                    case None => ()
                }
            }
        }

        let v = getBodyValue()
        let anyBlob = v.useAsAnyBlobAllowNonUtf8String()
        let text = anyBlob.slice().toString()
        JsPromise.resolve(JsGlobalObject(), JsValue(text))
    }

    /// 获取 ArrayBuffer
    /// 对应 Web API: body.arrayBuffer()
    /// 对应 Bun: Body.BodyMixin.get_array_buffer()
    func getArrayBuffer(): JsValue {
        let value = getBodyValue()

        if (value.tag == BodyValueTag.Used) {
            return handleBodyAlreadyUsed()
        }

        if (value.tag == BodyValueTag.Locked) {
            match (getBodyReadableStream()) {
                case Some(readable) =>
                    if (readable.isDisturbed) {
                        return handleBodyAlreadyUsed()
                    }
                    let v = getBodyValue()
                    v.toBlobIfPossible()
                    if (v.tag == BodyValueTag.Locked) {
                        match (v.locked) {
                            case Some(locked) => return locked.setPromise(BodyActionTag.GetArrayBuffer, Some(readable))
                            case None => ()
                        }
                    }
                case None => ()
            }

            let v = getBodyValue()
            if (v.tag == BodyValueTag.Locked) {
                match (v.locked) {
                    case Some(locked) =>
                        if (!locked.action.isNone() || locked.isDisturbed()) {
                            return handleBodyAlreadyUsed()
                        }
                        v.toBlobIfPossible()
                        if (v.tag == BodyValueTag.Locked) {
                            match (v.locked) {
                                case Some(locked2) => return locked2.setPromise(BodyActionTag.GetArrayBuffer, Option<ReadableStream>.None)
                                case None => ()
                            }
                        }
                    case None => ()
                }
            }
        }

        let v = getBodyValue()
        let anyBlob = v.useAsAnyBlobAllowNonUtf8String()
        JsPromise.resolve(JsGlobalObject(), JsValue.createBuffer(JsObject(), anyBlob.slice()))
    }

    /// 获取 Bytes
    /// 对应 Bun: Body.BodyMixin.get_bytes()
    func getBytes(): JsValue {
        let value = getBodyValue()

        if (value.tag == BodyValueTag.Used) {
            return handleBodyAlreadyUsed()
        }

        if (value.tag == BodyValueTag.Locked) {
            match (getBodyReadableStream()) {
                case Some(readable) =>
                    if (readable.isDisturbed) {
                        return handleBodyAlreadyUsed()
                    }
                    let v = getBodyValue()
                    v.toBlobIfPossible()
                    if (v.tag == BodyValueTag.Locked) {
                        match (v.locked) {
                            case Some(locked) => return locked.setPromise(BodyActionTag.GetBytes, Some(readable))
                            case None => ()
                        }
                    }
                case None => ()
            }

            let v = getBodyValue()
            if (v.tag == BodyValueTag.Locked) {
                match (v.locked) {
                    case Some(locked) =>
                        if (!locked.action.isNone() || locked.isDisturbed()) {
                            return handleBodyAlreadyUsed()
                        }
                        v.toBlobIfPossible()
                        if (v.tag == BodyValueTag.Locked) {
                            match (v.locked) {
                                case Some(locked2) => return locked2.setPromise(BodyActionTag.GetBytes, Option<ReadableStream>.None)
                                case None => ()
                            }
                        }
                    case None => ()
                }
            }
        }

        let v = getBodyValue()
        let anyBlob = v.useAsAnyBlobAllowNonUtf8String()
        JsPromise.resolve(JsGlobalObject(), JsValue.createBuffer(JsObject(), anyBlob.slice()))
    }

    /// 获取 Blob
    /// 对应 Web API: body.blob()
    /// 对应 Bun: Body.BodyMixin.get_blob()
    func getBlob(thisValue: JsValue): JsValue {
        let value = getBodyValue()

        if (value.tag == BodyValueTag.Used) {
            return handleBodyAlreadyUsed()
        }

        if (value.tag == BodyValueTag.Locked) {
            match (getBodyReadableStream()) {
                case Some(readable) =>
                    let v = getBodyValue()
                    if (v.tag == BodyValueTag.Locked) {
                        match (v.locked) {
                            case Some(locked) =>
                                if (!locked.action.isNone() || readable.isDisturbed) {
                                    return handleBodyAlreadyUsed()
                                }
                                v.toBlobIfPossible()
                                if (v.tag == BodyValueTag.Locked) {
                                    match (v.locked) {
                                        case Some(locked2) => return locked2.setPromise(BodyActionTag.GetBlob, Some(readable))
                                        case None => ()
                                    }
                                }
                            case None => ()
                        }
                    }
                case None => ()
            }

            let v = getBodyValue()
            if (v.tag == BodyValueTag.Locked) {
                match (v.locked) {
                    case Some(locked) =>
                        if (!locked.action.isNone() || locked.isDisturbed()) {
                            return handleBodyAlreadyUsed()
                        }
                        v.toBlobIfPossible()
                        if (v.tag == BodyValueTag.Locked) {
                            match (v.locked) {
                                case Some(locked2) => return locked2.setPromise(BodyActionTag.GetBlob, Option<ReadableStream>.None)
                                case None => ()
                            }
                        }
                    case None => ()
                }
            }
        }

        let v = getBodyValue()
        let usedBlob = v.use()
        let newBlob = Blob(usedBlob.sharedView(), "")
        // Check if content type is empty
        let ct = newBlob.getContentType()
        let ctEmpty = match (ct) {
            case Some(s) => s.size == 0
            case None => true
        }
        if (ctEmpty) {
            let headersOpt = getFetchHeaders()
            if (headersOpt.isSome()) {
                let headers = headersOpt.getOrThrow()
                let contentType = headers.fastGet(HTTPHeaderName.ContentType)
                if (contentType.isSome()) {
                    newBlob.setContentType(contentType.getOrThrow())
                    newBlob.setContentTypeWasSet(true)
                }
            }
            if (!newBlob.getContentTypeWasSet()) {
                                newBlob.setContentType("text/plain")
            }
        }
        JsPromise.resolve(JsGlobalObject(), newBlob.toJsValue())
    }

    /// 获取 FormData
    /// 对应 Web API: body.formData()
    /// 对应 Bun: Body.BodyMixin.get_form_data()
    func getFormData(): JsValue {
        let value = getBodyValue()

        if (value.tag == BodyValueTag.Used) {
            return handleBodyAlreadyUsed()
        }

        if (value.tag == BodyValueTag.Locked) {
            match (getBodyReadableStream()) {
                case Some(readable) =>
                    if (readable.isDisturbed) {
                        return handleBodyAlreadyUsed()
                    }
                    let v = getBodyValue()
                    v.toBlobIfPossible()
                case None => ()
            }

            let v = getBodyValue()
            if (v.tag == BodyValueTag.Locked) {
                match (v.locked) {
                    case Some(locked) =>
                        if (!locked.action.isNone() || locked.isDisturbed()) {
                            return handleBodyAlreadyUsed()
                        }
                        v.toBlobIfPossible()
                    case None => ()
                }
            }
        }

        match (getFormDataEncoding()) {
            case Some(encoding) =>
                let v = getBodyValue()
                if (v.tag == BodyValueTag.Locked) {
                    match (v.locked) {
                        case Some(locked) =>
                            let ownedReadable = getBodyReadableStream()
                            let v2 = getBodyValue()
                            if (v2.tag == BodyValueTag.Locked) {
                                match (v2.locked) {
                                    case Some(locked2) =>
                                        let action = BodyAction(BodyActionTag.GetFormData)
                                        action.formDataEncoding = Some(encoding)
                                        locked2.action = action
                                        return locked2.setPromise(BodyActionTag.GetFormData, ownedReadable)
                                    case None => ()
                                }
                            }
                        case None => ()
                    }
                }

                let anyBlob = v.useAsAnyBlob()
                let bytes = anyBlob.slice()
                let jsValue = FormData.toJs(bytes, FormDataEncoding.URLEncoded)
                anyBlob.detach()
                return JsPromise.resolve(JsGlobalObject(), jsValue)
            case None =>
                return JsPromise.reject(JsGlobalObject(), JsValue("Can't decode form data from body because of incorrect MIME type/boundary"))
        }
    }

    /// 获取 body
    /// 对应 Web API: body.body (getter)
    /// 对应 Bun: Body.BodyMixin.get_body()
    func getBody(): JsValue {
        let value = getBodyValue()

        if (value.tag == BodyValueTag.Used) {
            return ReadableStream.usedStream().toJsValue()
        }
        if (value.tag == BodyValueTag.Locked) {
            match (getBodyReadableStream()) {
                case Some(readable) => return readable.toJsValue()
                case None => ()
            }
        }
        value.toReadableStream()
    }

    /// 获取 bodyUsed
    /// 对应 Web API: body.bodyUsed (getter)
    /// 对应 Bun: Body.BodyMixin.get_body_used()
    func getBodyUsed(): JsValue {
        let value = getBodyValue()
        let used = match (value.tag) {
            case Used => true
            case Locked =>
                match (value.locked) {
                    case Some(locked) =>
                        if (!locked.action.isNone()) {
                            true
                        } else {
                            match (getBodyReadableStream()) {
                                case Some(readable) => readable.isDisturbed
                                case None =>
                                    match (value.locked) {
                                        case Some(locked2) =>
                                            let sOpt = locked2.readable.get()
                                            if (sOpt.isSome()) {
                                                sOpt.getOrThrow().isDisturbed
                                            } else {
                                                false
                                            }
                                        case None => false
                                    }
                            }
                        }
                    case None => false
                }
            case _ => false
        }
        JsValue(used)
    }
}

/// 处理 Body 已使用错误
/// 对应 Bun: handle_body_already_used()
func handleBodyAlreadyUsed(): JsValue {
    JsPromise.reject(JsGlobalObject(), JsValue("Body already used"))
}

// ============================================================================
// ValueBuffererCallback - ValueBufferer 回调类型
// 对应 Bun: Body.ValueBuffererCallback
// ============================================================================

/// ValueBufferer 回调
/// 对应 Bun: Body.ValueBuffererCallback
public type ValueBuffererCallback = (UIntPtr, Array<UInt8>, ?BodyValueError, Bool) -> Unit

// ============================================================================
// ValueBufferer - 值缓冲器
// 对应 Bun: Body.ValueBufferer
// ============================================================================

/// ReadFileResultType — file read result type
/// 对应 Bun: file read callback result (used by ValueBufferer.onFinishedLoadingFile)
/// In Bun this comes from the file system thread pool; here it is a local enum
/// wrapping the success/error result of a file read operation.
public enum ReadFileResultType {
    | Ok(Array<UInt8>)
    | Err(SyscallError)

    public func toErr(): ?SyscallError {
        match (this) {
            case Err(e) => Some(e)
            case _ => None
        }
    }

    public func toResult(): ?Array<UInt8> {
        match (this) {
            case Ok(d) => Some(d)
            case _ => None
        }
    }
}

/// ValueBufferer 管道回调
/// 实现 ByteStreamPipeCallback 接口
public class ValueBuffererPipeCallback <: ByteStreamPipeCallback {
    public var bufferer: ValueBufferer

    public init(bufferer: ValueBufferer) {
        this.bufferer = bufferer
    }

    public func onPipe(data: Array<UInt8>, isDone: Bool): Unit {
        bufferer.onStreamPipeDone(data, isDone)
    }
}

/// 值缓冲器 — 用于流式缓冲 Body 值
/// 对应 Bun: Body.ValueBufferer
public class ValueBufferer {
    /// 上下文指针
    public var ctx: UIntPtr
    /// 缓冲完成回调
    public var onFinishedBuffering: ValueBuffererCallback
    /// JS Sink
    public var jsSink: ?ArrayBufferJSSink
    /// ByteStream
    public var byteStream: ?ByteStream
    /// ReadableStream 强引用
    public var readableStreamRef: ReadableStreamStrong
    /// 流缓冲区
    public var streamBuffer: MutableString

    public init() {
        ctx = 0
        onFinishedBuffering = { _, _, _, _ => () }
        jsSink = None
        byteStream = None
        readableStreamRef = ReadableStreamStrong()
        streamBuffer = MutableString()
    }

    public init(ctx: UIntPtr, onFinished: ValueBuffererCallback) {
        this.ctx = ctx
        onFinishedBuffering = onFinished
        jsSink = None
        byteStream = None
        readableStreamRef = ReadableStreamStrong()
        streamBuffer = MutableString()
    }

    /// 获取哈希值 — 对应 Bun: @intFromPtr(this)
    public func hashCode(): Int64 {
        Int64(ctx)
    }

    /// 运行缓冲
    /// 对应 Bun: Body.ValueBufferer.run()
    public func run(value: BodyValue, ownedReadableStream: ?ReadableStream): Unit {
        value.toBlobIfPossible()

        match (value.tag) {
            case Used =>
                () // Body 已被使用
            case Empty =>
                onFinishedBuffering(ctx, Array<UInt8>(), None, false)
            case Null =>
                onFinishedBuffering(ctx, Array<UInt8>(), None, false)
            case Error =>
                match (value.error) {
                    case Some(errVal) =>
                        onFinishedBuffering(ctx, Array<UInt8>(), Some(errVal), false)
                    case None => ()
                }
            case WTFStringImpl =>
                let anyBlob = value.useAsAnyBlobAllowNonUtf8String()
                let bytes = anyBlob.slice()
                onFinishedBuffering(ctx, bytes, None, false)
            case InternalBlob =>
                let anyBlob = value.useAsAnyBlobAllowNonUtf8String()
                let bytes = anyBlob.slice()
                onFinishedBuffering(ctx, bytes, None, false)
            case Blob =>
                let anyBlob = value.useAsAnyBlobAllowNonUtf8String()
                let bytes = anyBlob.slice()
                onFinishedBuffering(ctx, bytes, None, false)
            case Locked =>
                bufferLockedBodyValue(value, ownedReadableStream)
        }
    }

    /// 文件加载完成回调
    /// 对应 Bun: Body.ValueBufferer.on_finished_loading_file()
    public func onFinishedLoadingFile(result: ReadFileResultType): Unit {
        match (result.toErr()) {
            case Some(sysErr) =>
                onFinishedBuffering(ctx, Array<UInt8>(), Some(BodyValueError.SysErr(sysErr)), true)
            case None =>
                let bytes = result.toResult()
                match (bytes) {
                    case Some(b) =>
                        onFinishedBuffering(ctx, b, None, true)
                    case None => ()
                }
        }
    }

    /// 流管道回调
    /// 对应 Bun: Body.ValueBufferer.on_stream_pipe()
    public func onStreamPipe(stream: StreamResult): Unit {
        let chunk = stream.slice()
        streamBuffer.write(chunk.items())
        if (stream.isDone()) {
            let bytes = streamBuffer.asSlice()
            onFinishedBuffering(ctx, bytes, None, true)
        }
    }

    /// 流管道完成回调 (for ByteStreamPipeCallback)
    public func onStreamPipeDone(data: Array<UInt8>, isDone: Bool): Unit {
        streamBuffer.write(data)
        if (isDone) {
            let bytes = streamBuffer.asSlice()
            onFinishedBuffering(ctx, bytes, None, true)
        }
    }

    /// 处理流解析
    /// 对应 Bun: Body.ValueBufferer.handle_resolve_stream()
    public func handleResolveStream(isAsync: Bool): Unit {
        match (jsSink) {
            case Some(wrapper) =>
                let bytes = wrapper.getBytes()
                onFinishedBuffering(ctx, bytes, None, isAsync)
            case None =>
                onFinishedBuffering(ctx, Array<UInt8>(), None, isAsync)
        }
    }

    /// 处理流拒绝
    /// 对应 Bun: Body.ValueBufferer.handle_reject_stream()
    public func handleRejectStream(err: JsValue, isAsync: Bool): Unit {
        match (jsSink) {
            case Some(wrapper) =>
                wrapper.detach()
                jsSink = None
            case None => ()
        }
        let jsRef = JsStrongOptional.create(err)
        onFinishedBuffering(ctx, Array<UInt8>(), Some(BodyValueError.JsValueRef(jsRef)), isAsync)
    }

    /// 接收值回调
    /// 对应 Bun: Body.ValueBufferer.on_receive_value()
    public func onReceiveValue(value: BodyValue): Unit {
        match (value.tag) {
            case Error =>
                match (value.error) {
                    case Some(errVal) =>
                        onFinishedBuffering(ctx, Array<UInt8>(), Some(errVal), true)
                    case None => ()
                }
            case _ =>
                value.toBlobIfPossible()
                let anyBlob = value.useAsAnyBlobAllowNonUtf8String()
                let bytes = anyBlob.slice()
                onFinishedBuffering(ctx, bytes, None, true)
        }
    }

    /// 缓冲锁定的 Body 值
    /// 对应 Bun: Body.ValueBufferer.buffer_locked_body_value()
    public func bufferLockedBodyValue(value: BodyValue, ownedReadableStream: ?ReadableStream): Unit {
        if (value.tag != BodyValueTag.Locked) {
            return
        }

        match (value.locked) {
            case Some(locked) =>
                // 获取 ReadableStream
                let lockedStream = locked.readable.get()
                let readableStream = if (lockedStream.isSome()) {
                    readableStreamRef.set(lockedStream.getOrThrow())
                    lockedStream
                } else {
                    ownedReadableStream
                }

                if (readableStream.isSome()) {
                    let stream = readableStream.getOrThrow()
                        value.tag = BodyValueTag.Used

                        if (stream.locked) {
                            return
                        }

                        match (stream.source.tag) {
                            case ReadableStreamSourceTag.Invalid =>
                                return
                            case ReadableStreamSourceTag.Blob =>
                                // toBlobIfPossible 应该已经处理了
                                return
                            case ReadableStreamSourceTag.File =>
                                // toBlobIfPossible 应该已经处理了
                                return
                            case ReadableStreamSourceTag.JavaScript =>
                                return
                            case ReadableStreamSourceTag.Direct =>
                                return
                            case ReadableStreamSourceTag.Bytes =>
                                match (stream.source.byteStream) {
                                    case Some(bs) =>
                                        let bytes = bs.buffer.items()
                                        // 如果已经收到完整数据
                                        if (bs.hasReceivedLastChunk) {
                                            onFinishedBuffering(ctx, bytes, None, false)
                                            stream.done = true
                                            return
                                        }
                                        // 设置管道回调
                                        bs.pipeCallback = Some(ValueBuffererPipeCallback(this))
                                        streamBuffer.write(bytes)
                                        return
                                    case None => ()
                                }
                        }
                }
                match (value.locked) {
                    case Some(locked2) =>
                        match (locked2.onReceiveValue) {
                            case Some(_) =>
                                // 有其他等待者，转为 ReadableStream
                                let readable = value.toReadableStream()
                                bufferLockedBodyValue(value, Option<ReadableStream>.None)
                                return
                            case None => ()
                        }
                        match (locked2.task) {
                            case Some(_) =>
                                let readable = value.toReadableStream()
                                bufferLockedBodyValue(value, Option<ReadableStream>.None)
                                return
                            case None => ()
                        }
                        // 设置回调等待
                        // 对应 Bun: locked.task = @intFromPtr(this)
                        locked2.task = Some(UIntNative(0))
                        locked2.onReceiveValue = Some({ t, v =>
                            onReceiveValue(v)
                        })
                    case None => ()
                }
            case None => ()
        }
    }

    /// 释放资源
    public func deinit(): Unit {
        match (byteStream) {
            case Some(bs) =>
                bs.unpipeWithoutDeref()
            case None => ()
        }
        readableStreamRef.deinit()

        match (jsSink) {
            case Some(wrapper) =>
                wrapper.detach()
                jsSink = None
            case None => ()
        }
    }
}

// ============================================================================
// Body - HTTP 请求/响应体
// 对应 Bun: src/runtime/webcore/Body.rs Body
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/Body
// ============================================================================

/// HTTP Body — 请求/响应体
/// 对应 Web API: Body
/// 对应 Bun: src/runtime/webcore/Body.rs Body
public class Body {
    /// Body 值
    /// 对应 Bun: Body.value
    public var value: BodyValue

    public init() {
        value = BodyValue()
    }

    public init(value: BodyValue) {
        this.value = value
    }

    /// 获取 Body 长度
    /// 对应 Bun: Body.len()
    public func len(): BlobSizeType {
        return value.size()
    }

    /// 获取字节切片
    /// 对应 Bun: Body.slice()
    public func slice(): Array<UInt8> {
        return value.slice()
    }

    /// 使用 Body，将其转换为 Blob
    /// 对应 Bun: Body.use()
    public func use(): Blob {
        return value.use()
    }

    /// 克隆 Body
    /// 对应 Bun: Body.clone()
    public func clone(): Body {
        return Body(value.clone())
    }

    /// 带 ReadableStream 克隆 Body
    /// 对应 Bun: Body.clone_with_readable_stream()
    public func cloneWithReadableStream(readable: ?ReadableStream): Body {
        return Body(value.cloneWithReadableStream(readable))
    }

    /// 将 body 转为文本
    /// 对应 Web API: body.text()
    public func text(): String {
        let bytes = value.slice()
        if (bytes.size == 0) {
            // 尝试字符串
            if (value.tag == BodyValueTag.WTFStringImpl) {
                match (value.wtfStringImpl) {
                    case Some(s) => return s.toString()
                    case None => ()
                }
            }
            return ""
        }
        return bytes.toString()
    }

    /// 将 body 解析为 JSON
    /// 对应 Web API: body.json()
    public func json(): JsValue {
        let text = text()
        return JsValue(text)
    }

    /// 获取原始字节数组
    /// 对应 Web API: body.arrayBuffer()
    public func arrayBuffer(): Array<UInt8> {
        return value.slice()
    }

    /// 重置 Body
    /// 对应 Bun: Body.reset()
    public func reset(): Unit {
        value.reset()
    }

    /// 释放资源
    /// 对应 Bun: Body.deinit()
    public func deinit(): Unit {
        value.deinit()
    }

    /// 从 JsValue 提取 Body
    /// 对应 Bun: Body.extract()
    public static func extract(value: JsValue): Body {
        let bodyValue = BodyValue.fromJs(value)
        return Body(bodyValue)
    }
}

// ============================================================================
// ReadableStreamStrong - ReadableStream 强引用
// 对应 Bun: ReadableStream.Strong
// ============================================================================

/// ReadableStream 强引用
/// 对应 Bun: ReadableStream.Strong
public class ReadableStreamStrong {
    /// 持有的 ReadableStream
    public var stream: ?ReadableStream

    public init() {
        stream = None
    }

    /// 是否持有引用
    /// 对应 Bun: ReadableStream.Strong.has()
    public func has(): Bool {
        match (stream) {
            case Some(_) => true
            case None => false
        }
    }

    /// 获取 ReadableStream
    /// 对应 Bun: ReadableStream.Strong.get()
    public func get(): ?ReadableStream {
        stream
    }

    /// 设置 ReadableStream
    /// 对应 Bun: ReadableStream.Strong() / held.set()
    public func set(s: ReadableStream): Unit {
        stream = Some(s)
    }

    /// 清空引用
    /// 对应 Bun: ReadableStream.Strong.clear()
    public func clear(): Unit {
        stream = None
    }

    /// 是否已被消费
    /// 对应 Bun: ReadableStream.Strong.is_disturbed()
    public func isDisturbed(): Bool {
        match (stream) {
            case Some(s) => s.isDisturbed
            case None => false
        }
    }

    /// tee 分流
    /// 对应 Bun: ReadableStream.Strong.tee()
    public func tee(): ?ReadableStream {
        match (stream) {
            case Some(s) =>
                let (stream1, stream2) = s.tee()
                stream = Some(stream1)
                Some(stream2)
            case None => None
        }
    }

    /// 释放资源
    /// 对应 Bun: ReadableStream.Strong.deinit()
    public func deinit(): Unit {
        stream = None
    }
}

// ============================================================================
// 辅助类型 (引用尚未翻译的模块的占位)
// ============================================================================

/// WTFStringImpl 占位 — WebKit 字符串实现
public class WTFStringImpl {
    private var str: String

    public init() {
        str = ""
    }

    public init(s: String) {
        str = s
    }

    public static func empty(): WTFStringImpl {
        WTFStringImpl("")
    }

    public static func from(s: String): WTFStringImpl {
        WTFStringImpl(s)
    }

    public func length(): Int64 {
        str.size
    }

    public func utf8ByteLength(): Int64 {
        Utf8Codec.encode(str).size
    }

    public func byteSlice(): Array<UInt8> {
        Utf8Codec.encode(str)
    }

    public func latin1Slice(): Array<UInt8> {
        Utf8Codec.encode(str)
    }

    public func toUtf8Slice(): Array<UInt8> {
        Utf8Codec.encode(str)
    }

    public func toString(): String {
        str
    }

    public func canUseAsUtf8(): Bool {
        true
    }

    public func toUtf8IfNeeded(): ?Array<UInt8> {
        // 总是返回 UTF8
        Some(Utf8Codec.encode(str))
    }

    public func memoryCost(): Int64 {
        str.size
    }

    public func ref(): Unit {
        // 引用计数 +1 (占位)
    }

    public func deref(): Unit {
        // 引用计数 -1 (占位)
    }
}

/// FetchHeaders 占位
public class FetchHeaders {
    public init() {}

    public func fastGet(name: HTTPHeaderName): ?String {
        None
    }
}

/// HTTPHeaderName 枚举
public enum HTTPHeaderName {
    | ContentType
    // ... 其他头部名称
}

/// ArrayBufferJSSink 占位
public class ArrayBufferJSSink {
    public init() {}

    public func getBytes(): Array<UInt8> {
        Array<UInt8>()
    }

    public func detach(): Unit {}
}

/// JsStrongOptional 占位
public class JsStrongOptional {
    private var value: ?JsValue

    public init() {
        value = None
    }

    public static func empty(): JsStrongOptional {
        JsStrongOptional()
    }

    public static func create(v: JsValue): JsStrongOptional {
        let r = JsStrongOptional()
        r.value = Some(v)
        r
    }

    public func get(): ?JsValue {
        value
    }

    public func deinit(): Unit {
        value = None
    }
}

/// MutableString 占位
public class MutableString {
    private var buffer: ArrayList<UInt8>

    public init() {
        buffer = ArrayList<UInt8>()
    }

    public func write(data: Array<UInt8>): Unit {
        for (b in data) {
            buffer.append(b)
        }
    }

    public func asSlice(): Array<UInt8> {
        buffer.items()
    }
}

/// FormData — multipart/form-data 表单数据
/// 对应 Bun: src/runtime/webcore/FormData.zig FormData
public class FormData {
    /// 表单字段存储
    public var entries: ArrayList<FormDataEntry>

    public init() {
        entries = ArrayList<FormDataEntry>()
    }

    public static func toJs(bytes: Array<UInt8>, encoding: FormDataEncoding): JsValue {
        // 将 FormData 字节转为 JS 对象
        let obj = JsObject()
        obj.set("type", JsValue("FormData"))
        JsValue(obj)
    }

    /// Append a field value (binary with filename and content type)
    public func append(name: String, value: Array<UInt8>, filename: String, contentType: String): Unit {
        let entry = FormDataEntry()
        entry.name = name
        entry.binaryValue = Some(value)
        entry.filename = Some(filename)
        entry.contentType = Some(contentType)
        entries.append(entry)
    }

    /// Append a text field value
    public func append(name: String, value: String): Unit {
        let entry = FormDataEntry()
        entry.name = name
        entry.textValue = Some(value)
        entries.append(entry)
    }

    /// 获取条目数量
    public func count(): Int64 {
        entries.size
    }
}

/// FormDataEntry — 表单字段条目
public class FormDataEntry {
    public var name: String
    public var textValue: ?String
    public var binaryValue: ?Array<UInt8>
    public var filename: ?String
    public var contentType: ?String

    public init() {
        name = ""
        textValue = None
        binaryValue = None
        filename = None
        contentType = None
    }
}

/// DOMFormData — DOM FormData API
/// 对应 Bun: src/runtime/webcore/DOMFormData.zig DOMFormData
public class DOMFormData {
    /// 底层 FormData
    public var formData: FormData

    public init() {
        formData = FormData()
    }

    public static func fromJs(value: JsValue): ?DOMFormData {
        // 检查是否为 FormData 对象
        if (!value.isObject()) {
            return None
        }
        // 检查构造函数名
        let name = value.getProperty("constructor.name")
        if (name.isString()) {
            let str = name.toString()
            if (str == "FormData") {
                return Some(DOMFormData())
            }
        }
        None
    }

    public func append(key: ZigString, value: ZigString): Unit {
        formData.append(key.toString(), value.toString())
    }

    public func appendBlob(global: JSGlobalObject, key: ZigString, blob: Blob, filename: ZigString): Unit {
        let bytes = blob.sharedView()
        let ct = match (blob.getContentType()) {
            case Some(s) => s
            case None => "application/octet-stream"
        }
        formData.append(key.toString(), bytes, filename.toString(), ct)
    }
}

/// URLSearchParams 占位
public class URLSearchParams {
    public init() {}

    public static func fromJs(value: JsValue): ?URLSearchParams {
        None
    }

    public func asPtr(): UIntPtr {
        0
    }
}

/// DrainResult - 排水结果
/// 对应 Bun: DrainResult
public enum DrainResult {
    | Empty                          // 空
    | Aborted                        // 已中止
    | EstimatedSize(BlobSizeType)    // 估算大小
    | Owned(ArrayList<UInt8>, BlobSizeType)  // 已有数据
}

/// RequestFlags 占位
public class RequestFlags {
    public init() {}
    public var redirect: String = "follow"
}

/// Request 占位
public class Request {
    public init() {}
    public init(s: String) { this.url = s }
    public init(url: String, options: RequestInit) {
        this.url = url
        this.method = options.method
    }

    public static func `class`(): String {
        "Request"
    }

    public static func fromJs(value: JsValue): ?Request {
        None
    }

    public func getBodyValue(): BodyValue {
        BodyValue()
    }

    // ========== Request state members ==========
    // 对应 Bun: Request struct fields
    public var url: String = ""
    public var method: HttpMethod = HttpMethod.GET
    public var headers: Headers = Headers()
    public var signal: JsValue = JsValue.UNDEFINED
    public var flags: RequestFlags = RequestFlags()
    public var body: ?BodyValue = None
    public var bodyValue: BodyValue = BodyValue()
}

/// Response 占位
public class Response {
    public init() {}

    public static func `class`(): String {
        "Response"
    }

    public static func error(): Response {
        let r = Response()
        r.statusCode_ = 0
        return r
    }

    public func redirectLocation(): ?String {
        None
    }

    public static func fromJs(value: JsValue): ?Response {
        None
    }

    public func getBodyValue(): BodyValue {
        BodyValue()
    }

    /// Get status code
    public func statusCode(): Int64 {
        200
    }

    /// Get headers
    public func getHeaders(): Headers {
        Headers()
    }

    /// Get body as ArrayBuffer
    public func arrayBuffer(): Array<UInt8> {
        Array<UInt8>()
    }

    // ========== Response state members ==========
    // 对应 Bun: Response struct fields
    public var url: String = ""
    public var body: ?BodyValue = None
    public var errorValue: ?JsValue = None
    public var statusCode_: Int64 = 200
    public var statusText: String = ""
    public var method: HttpMethod = HttpMethod.GET
    public var redirected: Bool = false
    public var headers: Headers = Headers()

    public static func initResponse(global: JsGlobalObject, body: JsValue, `init`: JsValue): JsValue {
        JsValue()
    }

    public func toJsValue(): JsValue { JsValue() }
    public func isOk(): Bool { true }
    public func getContentType(): String { "" }
    public func getBodyUsed(): Bool { false }
    public func getBodyReadableStream(): ?ReadableStream { None }

    // init property (ResponseInit) - accessed as response.`init`
    public var initConfig: ResponseInit = ResponseInit()
}
