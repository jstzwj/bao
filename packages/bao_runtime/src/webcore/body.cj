// Body - HTTP 请求/响应体
// 对应 Bun: src/runtime/webcore/Body.rs
// 严格翻译自: src/runtime/webcore/Body.rs
package bao_runtime.webcore

import bao_core.*
import bao_collections.*

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
}

// ============================================================================
// BodyValueError - Body 值错误
// 对应 Bun: Body.Value.ValueError
// ============================================================================

/// Body 值错误类型
/// 对应 Bun: Body.Value.ValueError
public enum BodyValueError {
    | AbortReason(CommonAbortReason)       // 中止原因
    | SystemError(SyscallError)            // 系统错误
    | Message(String)                      // 错误消息
    | TypeError(String)                    // 类型错误
    | JsValue(JsStrongOptional)            // JS 值 (强引用)

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        match (this) {
            case AbortReason(msg) =>
                let obj = JsObject()
                obj.set("name", JsValue(BaoString("AbortError")))
                obj.set("message", JsValue(BaoString(msg.reason)))
                return JsValue(obj)
            case SystemError(err) =>
                let obj = JsObject()
                obj.set("name", JsValue(BaoString("SystemError")))
                obj.set("message", JsValue(BaoString(err.message)))
                return JsValue(obj)
            case Message(msg) =>
                let obj = JsObject()
                obj.set("message", JsValue(BaoString(msg)))
                return JsValue(obj)
            case TypeError(msg) =>
                let obj = JsObject()
                obj.set("name", JsValue(BaoString("TypeError")))
                obj.set("message", JsValue(BaoString(msg)))
                return JsValue(obj)
            case JsValue(jsRef) =>
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
            case SystemError(e) => BodyValueError.SystemError(e)
            case Message(m) => BodyValueError.Message(m)
            case TypeError(m) => BodyValueError.TypeError(m)
            case JsValue(jsRef) =>
                match (jsRef.get()) {
                    case Some(v) => BodyValueError.JsValue(JsStrongOptional.create(v))
                    case None => BodyValueError.JsValue(JsStrongOptional.empty())
                }
        }
    }

    /// 重置/释放资源
    /// 对应 Bun: Body.Value.ValueError.reset()
    public func reset(): Unit {
        match (this) {
            case JsValue(jsRef) => jsRef.deinit()
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
        match (readable.get()) {
            case Some(stream) =>
                match (stream.source.getTag()) {
                    case ReadableStreamSourceTag.Bytes => stream.source.sizeHint
                    case _ => sizeHint
                }
            case None => sizeHint
        }
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
                let blob = s.toAnyBlob()
                match (blob) {
                    case Some(b) =>
                        readable.deinit()
                        Some(b)
                    case None => None
                }
            case None => None
        }
    }

    /// 检查是否已被消费
    /// 对应 Bun: Body.PendingValue.is_disturbed()
    public func isDisturbed(): Bool {
        match (promise) {
            case Some(_) => true
            case None =>
                match (readable.get()) {
                    case Some(stream) => stream.isDisturbed()
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
            case Some(readable) =>
                match (actionTag) {
                    case GetText =>
                        readable.done()
                        readable.deinit()
                        let p = JsPromise.resolved(JsValue(BaoString("")))
                        p.toJsValue()
                    case GetJSON =>
                        readable.done()
                        readable.deinit()
                        let p = JsPromise.resolved(JsValue.UNDEFINED)
                        p.toJsValue()
                    case GetArrayBuffer =>
                        readable.done()
                        readable.deinit()
                        let p = JsPromise.resolved(JsValue.UNDEFINED)
                        p.toJsValue()
                    case GetBytes =>
                        readable.done()
                        readable.deinit()
                        let p = JsPromise.resolved(JsValue.UNDEFINED)
                        p.toJsValue()
                    case GetBlob =>
                        readable.done()
                        readable.deinit()
                        let p = JsPromise.resolved(JsValue.UNDEFINED)
                        p.toJsValue()
                    case GetFormData =>
                        readable.done()
                        readable.deinit()
                        let p = JsPromise.resolved(JsValue.UNDEFINED)
                        p.toJsValue()
                    case None =>
                        // 创建新的 Promise
                        let p = JsPromise.create()
                        let promiseValue = p.toJsValue()
                        promise = Some(promiseValue)
                        promiseValue
                }
            case None =>
                // 创建新的 Promise
                let p = JsPromise.create()
                let promiseValue = p.toJsValue()
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
                    case Some(b) => b.getSizeForBindings()
                    case None => 0
                }
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) => b.sliceConst().size
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
                    case Some(b) => b.sliceConst().size
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
                    case Some(b) => b.sliceConst().size
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
                    case Some(b) => b.sliceConst().size == 0
                    case None => true
                }
            case Blob =>
                match (blob) {
                    case Some(b) => b.size == 0
                    case None => true
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) => s.size() == 0
                    case None => true
                }
            case Error => false
            case Locked => false
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
                    match (utf8) {
                        case Some(bytes) =>
                            tag = BodyValueTag.InternalBlob
                            internalBlob = Some(InternalBlob(bytes, true))
                            wtfStringImpl = None
                        case None => ()
                    }
                case None => ()
            }
        }

        // Locked → Blob (如果可以从 ReadableStream 转换)
        if (tag == BodyValueTag.Locked) {
            match (locked) {
                case Some(pending) =>
                    let anyBlob = pending.toAnyBlob()
                    match (anyBlob) {
                        case Some(b) =>
                            match (b.tag) {
                                case AnyBlobTag.Blob =>
                                    tag = BodyValueTag.Blob
                                    blob = Some(b.blob)
                                    locked = None
                                case AnyBlobTag.InternalBlob =>
                                    tag = BodyValueTag.InternalBlob
                                    internalBlob = Some(b.internalBlob)
                                    locked = None
                                case AnyBlobTag.WTFStringImpl =>
                                    tag = BodyValueTag.WTFStringImpl
                                    wtfStringImpl = Some(b.wtfStringImpl)
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
                        let resultBlob = match (utf8) {
                            case Some(bytes) => Blob(bytes, "text/plain")
                            case None => Blob(wtf.latin1Slice(), "text/plain")
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
                        let result = AnyBlob.fromBlob(b.dupe())
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
                    case Some(pending) =>
                        let blob = pending.toAnyBlobAllowPromise()
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
                    case Some(b) => AnyBlob.fromBlob(b.dupe())
                    case None => AnyBlob.fromBlob(Blob.initEmpty())
                }
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) => AnyBlob.fromInternalBlob(b)
                    case None => AnyBlob.fromBlob(Blob.initEmpty())
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) =>
                        let utf8 = s.toUtf8IfNeeded()
                        match (utf8) {
                            case Some(bytes) =>
                                AnyBlob.fromInternalBlob(InternalBlob(bytes, true))
                            case None =>
                                AnyBlob.fromWTFStringImpl(s)
                        }
                    case None => AnyBlob.fromBlob(Blob.initEmpty())
                }
            case Locked =>
                match (locked) {
                    case Some(pending) =>
                        let blob = pending.toAnyBlobAllowPromise()
                        match (blob) {
                            case Some(b) => b
                            case None => AnyBlob.fromBlob(Blob.initEmpty())
                        }
                    case None => AnyBlob.fromBlob(Blob.initEmpty())
                }
            case _ => AnyBlob.fromBlob(Blob.initEmpty())
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
                    case Some(b) => AnyBlob.fromBlob(b.dupe())
                    case None => AnyBlob.fromBlob(Blob.initEmpty())
                }
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) => AnyBlob.fromInternalBlob(b)
                    case None => AnyBlob.fromBlob(Blob.initEmpty())
                }
            case WTFStringImpl =>
                match (wtfStringImpl) {
                    case Some(s) =>
                        AnyBlob.fromWTFStringImpl(s)
                    case None => AnyBlob.fromBlob(Blob.initEmpty())
                }
            case Locked =>
                match (locked) {
                    case Some(pending) =>
                        let blob = pending.toAnyBlobAllowPromise()
                        match (blob) {
                            case Some(b) => b
                            case None => AnyBlob.fromBlob(Blob.initEmpty())
                        }
                    case None => AnyBlob.fromBlob(Blob.initEmpty())
                }
            case _ => AnyBlob.fromBlob(Blob.initEmpty())
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
                    case Some(b) => b.sliceConst()
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
    public static func blob(b: Blob): BodyValue {
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
                        return BodyValue(wtfString: s)
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
                        BodyValue(wtfString: s)
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
                        if (readable.isDisturbed()) {
                            let v = BodyValue()
                            v.tag = BodyValueTag.Used
                            return v
                        }

                        let (stream1, stream2) = readable.tee()
                        // 保持当前流，返回第二个
                        lockedValue.readable.set(stream1)
                        let newPending = PendingBodyValue()
                        newPending.readable.set(stream2)
                        return BodyValue(pendingValue: newPending)
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
                        let (stream1, stream2) = readable.tee()
                        lockedValue.readable.set(stream1)
                        let newPending = PendingBodyValue()
                        newPending.readable.set(stream2)
                        return BodyValue(pendingValue: newPending)
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
                        let (stream1, stream2) = readable.tee()
                        lockedValue.readable.set(stream1)
                        let newPending = PendingBodyValue()
                        newPending.readable.set(stream2)
                        return BodyValue(pendingValue: newPending)
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
                ReadableStream.used().toJsValue()
            case Empty =>
                ReadableStream.empty().toJsValue()
            case Null =>
                JsValue.NULL
            case InternalBlob =>
                let usedBlob = use()
                let stream = ReadableStream.fromBlobCopyRef(usedBlob)
                let pendingValue = PendingBodyValue()
                pendingValue.readable.set(stream)
                tag = BodyValueTag.Locked
                locked = Some(pendingValue)
                stream.toJsValue()
            case Blob =>
                let usedBlob = use()
                let stream = ReadableStream.fromBlobCopyRef(usedBlob)
                let pendingValue = PendingBodyValue()
                pendingValue.readable.set(stream)
                tag = BodyValueTag.Locked
                locked = Some(pendingValue)
                stream.toJsValue()
            case WTFStringImpl =>
                let usedBlob = use()
                let stream = ReadableStream.fromBlobCopyRef(usedBlob)
                let pendingValue = PendingBodyValue()
                pendingValue.readable.set(stream)
                tag = BodyValueTag.Locked
                locked = Some(pendingValue)
                stream.toJsValue()
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
                                return ReadableStream.used().toJsValue()
                            case None =>
                                if (!lockedValue.action.isNone()) {
                                    return ReadableStream.used().toJsValue()
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
                                return ReadableStream.empty().toJsValue()
                            case DrainResult.Aborted =>
                                tag = BodyValueTag.Null
                                return ReadableStream.empty().toJsValue()
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
                                    case Some(t) => source.cancelCallback = Some(cb)
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
                    case None => ReadableStream.empty().toJsValue()
                }
            case Error =>
                ReadableStream.empty().toJsValue()
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
                                readable.done()
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
                                                p.resolve(JsValue(BaoString(anyBlob.slice().toString())))
                                            case GetJSON =>
                                                let anyBlob = newValue.useAsAnyBlobAllowNonUtf8String()
                                                p.resolve(JsValue.UNDEFINED)
                                            case GetArrayBuffer =>
                                                let anyBlob = newValue.useAsAnyBlobAllowNonUtf8String()
                                                p.resolve(JsValue.UNDEFINED)
                                            case GetBytes =>
                                                let anyBlob = newValue.useAsAnyBlobAllowNonUtf8String()
                                                p.resolve(JsValue.UNDEFINED)
                                            case GetFormData =>
                                                p.resolve(JsValue.UNDEFINED)
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
                                                p.resolve(newBlob.toJsValue())
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
                                                p.resolve(newBlob.toJsValue())
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
                                match (readable.source.getTag()) {
                                    case ReadableStreamSourceTag.Bytes =>
                                        match (readable.source.byteStream) {
                                            case Some(bs) =>
                                                bs.onData(StreamResult.err(err.toStreamError()))
                                            case None => readable.abort()
                                        }
                                    case _ => readable.abort()
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
        toErrorInstance(BodyValueError.SystemError(err))
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

        if (value.isStringLike()) {
            let text = value.toString()
            if (text.size == 0) {
                let v = BodyValue()
                v.tag = BodyValueTag.Empty
                return v
            }
            return BodyValue(text: text)
        }

        if (value.isTypedArrayOrArrayBuffer()) {
            let bytes = value.asArrayBuffer()
            match (bytes) {
                case Some(b) =>
                    if (b.size == 0) {
                        let v = BodyValue()
                        v.tag = BodyValueTag.Empty
                        return v
                    }
                    return BodyValue(internalBlob: InternalBlob(b, false))
                case None => ()
            }
        }

        // 尝试 Blob
        if (value.isDOMWrapper()) {
            if (value.isInstanceOf(Blob.`class`())) {
                let b = Blob.fromJs(value)
                match (b) {
                    case Some(blob) => return BodyValue(blob.dupeWithContentType(true))
                    case None => ()
                }
            }
        }

        // 尝试 ReadableStream
        let readable = ReadableStream.fromJsValue(value)
        match (readable) {
            case Some(stream) =>
                if (stream.isDisturbed()) {
                    // ReadableStream 已被使用
                    let v = BodyValue()
                    v.tag = BodyValueTag.Used
                    return v
                }

                // 尝试从 Source::Blob 提取
                match (stream.source.getTag()) {
                    case ReadableStreamSourceTag.Blob =>
                        let anyBlob = stream.toAnyBlob()
                        match (anyBlob) {
                            case Some(b) =>
                                stream.forceDetach()
                                match (b.tag) {
                                    case AnyBlobTag.Blob => return BodyValue(b.blob)
                                    case AnyBlobTag.InternalBlob => return BodyValue(internalBlob: b.internalBlob)
                                    case AnyBlobTag.WTFStringImpl => return BodyValue(wtfString: b.wtfStringImpl)
                                    case _ => ()
                                }
                            case None => ()
                        }
                    case _ => ()
                }

                return fromReadableStreamWithoutLockCheck(stream)
            case None => ()
        }

        // 尝试 FormData / URLSearchParams
        let formData = DOMFormData.fromJs(value)
        match (formData) {
            case Some(fd) => return BodyValue(Blob.fromDOMFormData(fd))
            case None => ()
        }

        let searchParams = URLSearchParams.fromJs(value)
        match (searchParams) {
            case Some(sp) => return BodyValue(Blob.fromURLSearchParams(sp))
            case None => ()
        }

        // 尝试 Blob.get
        let blob = Blob.get(value)
        match (blob) {
            case Some(b) => return BodyValue(b)
            case None => ()
        }

        let v = BodyValue()
        v.tag = BodyValueTag.Empty
        v
    }

    /// 从 ReadableStream 创建 (不检查锁定)
    /// 对应 Bun: Body.Value.from_readable_stream_without_lock_check()
    public static func fromReadableStreamWithoutLockCheck(readable: ReadableStream): BodyValue {
        let pendingValue = PendingBodyValue()
        pendingValue.readable.set(readable)
        return BodyValue(pendingValue: pendingValue)
    }

    /// 从 Request 或 Response 获取 Body 值
    /// 对应 Bun: Body.Value.from_request_or_response()
    public static func fromRequestOrResponse(value: JsValue): ?BodyValue {
        if (value.isEmptyOrUndefinedOrNull()) {
            return None
        }
        if (value.isInstanceOf(Request.`class`())) {
            let req = Request.fromJs(value)
            match (req) {
                case Some(r) => return Some(r.getBodyValue())
                case None => return None
            }
        }
        if (value.isInstanceOf(Response.`class`())) {
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
                    case Some(s) => JsValue(BaoString(s.toString()))
                    case None => JsValue.UNDEFINED
                }
            case InternalBlob =>
                match (internalBlob) {
                    case Some(b) => JsValue(BaoString(b.sliceConst().toString()))
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
                streamSetCached(jsRef, JsValue.ZERO)
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
        match (jsRef()) {
            case Some(jsValue) =>
                let value = getBodyValue()
                if (value.tag == BodyValueTag.Locked) {
                    match (value.locked) {
                        case Some(lockedValue) =>
                            match (lockedValue.readable.get()) {
                                case Some(stream) =>
                                    streamSetCached(jsValue, stream.toJsValue())
                                    lockedValue.readable.deinit()
                                    lockedValue.readable = ReadableStreamStrong()
                                case None => ()
                            }
                        case None => ()
                    }
                }
            case None => ()
        }
    }

    /// 同步克隆的 Body Stream 缓存
    /// 对应 Bun: Body.BodyMixin.sync_cloned_body_stream_caches()
    func syncClonedBodyStreamCaches(thisValue: JsValue, jsWrapper: JsValue): Unit {
        if (!jsWrapper.isEmpty()) {
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
                    if (readable.isDisturbed()) {
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
                        return locked.setPromise(BodyActionTag.GetText, None)
                    case None => ()
                }
            }
        }

        let v = getBodyValue()
        let anyBlob = v.useAsAnyBlobAllowNonUtf8String()
        let text = anyBlob.slice().toString()
        JsPromise.resolved(JsValue(BaoString(text))).toJsValue()
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
                    if (readable.isDisturbed()) {
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
                                case Some(locked2) => return locked2.setPromise(BodyActionTag.GetJSON, None)
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
        JsPromise.resolved(JsValue(BaoString(text))).toJsValue()
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
                    if (readable.isDisturbed()) {
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
                                case Some(locked2) => return locked2.setPromise(BodyActionTag.GetArrayBuffer, None)
                                case None => ()
                            }
                        }
                    case None => ()
                }
            }
        }

        let v = getBodyValue()
        let anyBlob = v.useAsAnyBlobAllowNonUtf8String()
        JsPromise.resolved(JsValue.arrayBuffer(anyBlob.slice())).toJsValue()
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
                    if (readable.isDisturbed()) {
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
                                case Some(locked2) => return locked2.setPromise(BodyActionTag.GetBytes, None)
                                case None => ()
                            }
                        }
                    case None => ()
                }
            }
        }

        let v = getBodyValue()
        let anyBlob = v.useAsAnyBlobAllowNonUtf8String()
        JsPromise.resolved(JsValue.arrayBuffer(anyBlob.slice())).toJsValue()
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
                                if (!locked.action.isNone() || readable.isDisturbed()) {
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
                                case Some(locked2) => return locked2.setPromise(BodyActionTag.GetBlob, None)
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
        if (newBlob.getContentType().isEmpty()) {
            match (getFetchHeaders()) {
                case Some(headers) =>
                    let contentType = headers.fastGet(HTTPHeaderName.ContentType)
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
        }
        JsPromise.resolved(newBlob.toJsValue()).toJsValue()
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
                    if (readable.isDisturbed()) {
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
                let jsValue = FormData.toJs(bytes, encoding)
                anyBlob.detach()
                return JsPromise.resolved(jsValue).toJsValue()
            case None =>
                return JsPromise.rejected(JsValue(BaoString("Can't decode form data from body because of incorrect MIME type/boundary"))).toJsValue()
        }
    }

    /// 获取 body
    /// 对应 Web API: body.body (getter)
    /// 对应 Bun: Body.BodyMixin.get_body()
    func getBody(): JsValue {
        let value = getBodyValue()

        if (value.tag == BodyValueTag.Used) {
            return ReadableStream.used().toJsValue()
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
                                case Some(readable) => readable.isDisturbed()
                                case None =>
                                    match (value.locked) {
                                        case Some(locked2) =>
                                            match (locked2.readable.get()) {
                                                case Some(stream) => stream.isDisturbed()
                                                case None => false
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
    JsPromise.rejected(JsValue(BaoString("Body already used"))).toJsValue()
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
                    case Some(err) =>
                        let errCopy = err.dupe()
                        onFinishedBuffering(ctx, Array<UInt8>(), Some(errCopy), false)
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
        match (result) {
            case ReadFileResultType.Err(err) =>
                onFinishedBuffering(ctx, Array<UInt8>(), Some(BodyValueError.SystemError(err)), true)
            case ReadFileResultType.Result(data) =>
                onFinishedBuffering(ctx, data, None, true)
        }
    }

    /// 流管道回调
    /// 对应 Bun: Body.ValueBufferer.on_stream_pipe()
    public func onStreamPipe(stream: StreamResult): Unit {
        let chunk = stream.slice()
        streamBuffer.write(chunk)
        if (stream.isDone()) {
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
        onFinishedBuffering(ctx, Array<UInt8>(), Some(BodyValueError.JsValue(jsRef)), isAsync)
    }

    /// 接收值回调
    /// 对应 Bun: Body.ValueBufferer.on_receive_value()
    public func onReceiveValue(value: BodyValue): Unit {
        match (value.tag) {
            case Error =>
                match (value.error) {
                    case Some(err) =>
                        let errCopy = err.dupe()
                        onFinishedBuffering(ctx, Array<UInt8>(), Some(errCopy), true)
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
                let readableStream = match (locked.readable.get()) {
                    case Some(stream) =>
                        readableStreamRef.set(stream)
                        Some(stream)
                    case None =>
                        match (ownedReadableStream) {
                            case Some(ownedStream) =>
                                readableStreamRef.set(ownedStream)
                                Some(ownedStream)
                            case None => None
                        }
                }

                match (readableStream) {
                    case Some(stream) =>
                        value.tag = BodyValueTag.Used

                        if (stream.isLocked()) {
                            return
                        }

                        match (stream.source.getTag()) {
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
                                        let bytes = bs.buffer.toArray()
                                        // 如果已经收到完整数据
                                        if (bs.hasReceivedLastChunk) {
                                            onFinishedBuffering(ctx, bytes, None, false)
                                            stream.done()
                                            return
                                        }
                                        // 设置管道回调
                                        bs.pipeCallback = Some(ByteStreamPipeCallback.wrap(this))
                                        streamBuffer.write(bytes)
                                        return
                                    case None => ()
                                }
                        }
                    case None => ()
                }

                // 检查是否有其他等待者
                match (value.locked) {
                    case Some(locked2) =>
                        match (locked2.onReceiveValue) {
                            case Some(_) =>
                                // 有其他等待者，转为 ReadableStream
                                let readable = value.toReadableStream()
                                bufferLockedBodyValue(value, None)
                                return
                            case None => ()
                        }
                        match (locked2.task) {
                            case Some(_) =>
                                let readable = value.toReadableStream()
                                bufferLockedBodyValue(value, None)
                                return
                            case None => ()
                        }
                        // 设置回调等待
                        locked2.task = Some(UIntPtr.from(this))
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
        return Body(value: value.clone())
    }

    /// 带 ReadableStream 克隆 Body
    /// 对应 Bun: Body.clone_with_readable_stream()
    public func cloneWithReadableStream(readable: ?ReadableStream): Body {
        return Body(value: value.cloneWithReadableStream(readable))
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
        return JsValue(BaoString(text))
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
        return Body(value: bodyValue)
    }
}

// ============================================================================
// InternalBlob - 内部 Blob (单次使用)
// 对应 Bun: InternalBlob
// ============================================================================

/// 内部 Blob — 单次使用的 Blob，避免堆分配
/// 对应 Bun: InternalBlob
public class InternalBlob {
    /// 字节数据
    public var bytes: Array<UInt8>
    /// 是否由字符串创建
    public var wasString: Bool

    public init() {
        bytes = Array<UInt8>()
        wasString = false
    }

    public init(bytes: Array<UInt8>, wasStr: Bool) {
        this.bytes = bytes
        wasString = wasStr
    }

    /// 获取不可变字节切片
    /// 对应 Bun: InternalBlob.slice_const()
    public func sliceConst(): Array<UInt8> {
        bytes
    }

    /// 获取自有切片 (克隆)
    /// 对应 Bun: InternalBlob.to_owned_slice()
    public func toOwnedSlice(): Array<UInt8> {
        let copy = Array<UInt8>()
        for (b in bytes) {
            copy.append(b)
        }
        copy
    }

    /// 获取内存开销
    /// 对应 Bun: InternalBlob.memory_cost()
    public func memoryCost(): Int64 {
        bytes.size
    }
}

// ============================================================================
// AnyBlob - Blob 联合类型
// 对应 Bun: AnyBlob
// ============================================================================

/// AnyBlob 标签
/// 对应 Bun: AnyBlob tag
public enum AnyBlobTag {
    | Blob
    | InternalBlob
    | WTFStringImpl
}

/// AnyBlob — Blob / InternalBlob / WTFStringImpl 的联合类型
/// 对应 Bun: AnyBlob
public class AnyBlob {
    public var tag: AnyBlobTag
    /// Blob 引用
    public var blob: Blob
    /// InternalBlob 引用
    public var internalBlob: InternalBlob
    /// WTFStringImpl 引用
    public var wtfStringImpl: WTFStringImpl

    public init() {
        tag = AnyBlobTag.Blob
        blob = Blob.initEmpty()
        internalBlob = InternalBlob()
        wtfStringImpl = WTFStringImpl.empty()
    }

    public static func fromBlob(b: Blob): AnyBlob {
        let r = AnyBlob()
        r.tag = AnyBlobTag.Blob
        r.blob = b
        r
    }

    public static func fromInternalBlob(ib: InternalBlob): AnyBlob {
        let r = AnyBlob()
        r.tag = AnyBlobTag.InternalBlob
        r.internalBlob = ib
        r
    }

    public static func fromWTFStringImpl(s: WTFStringImpl): AnyBlob {
        let r = AnyBlob()
        r.tag = AnyBlobTag.WTFStringImpl
        r.wtfStringImpl = s
        r
    }

    /// 获取字节切片
    /// 对应 Bun: AnyBlob.slice()
    public func slice(): Array<UInt8> {
        match (tag) {
            case Blob => blob.sharedView()
            case InternalBlob => internalBlob.sliceConst()
            case WTFStringImpl => wtfStringImpl.toUtf8Slice()
        }
    }

    /// 是否需要读取文件
    /// 对应 Bun: AnyBlob.needs_to_read_file()
    public func needsToReadFile(): Bool {
        match (tag) {
            case Blob => blob.needsToReadFile()
            case _ => false
        }
    }

    /// 分离资源
    /// 对应 Bun: AnyBlob.detach()
    public func detach(): Unit {
        match (tag) {
            case Blob => blob.detach()
            case _ => ()
        }
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

    /// 是否已被消费
    /// 对应 Bun: ReadableStream.Strong.is_disturbed()
    public func isDisturbed(): Bool {
        match (stream) {
            case Some(s) => s.isDisturbed()
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
        str.toUtf8().size
    }

    public func byteSlice(): Array<UInt8> {
        str.toUtf8()
    }

    public func latin1Slice(): Array<UInt8> {
        str.toUtf8()
    }

    public func toUtf8Slice(): Array<UInt8> {
        str.toUtf8()
    }

    public func toString(): String {
        str
    }

    public func canUseAsUtf8(): Bool {
        true
    }

    public func toUtf8IfNeeded(): ?Array<UInt8> {
        // 总是返回 UTF8
        Some(str.toUtf8())
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

/// ReadFileResultType 占位
public enum ReadFileResultType {
    | Err(SyscallError)
    | Result(Array<UInt8>)
}

/// CommonAbortReason 占位
public class CommonAbortReason {
    public var reason: String

    public init() {
        reason = ""
    }

    public init(reason: String) {
        this.reason = reason
    }
}

/// SyscallError 占位
public class SyscallError {
    public var message: String

    public init() {
        message = ""
    }

    public init(message: String) {
        this.message = message
    }
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
        buffer.toArray()
    }
}

/// FormDataEncoding 占位
public enum FormDataEncoding {
    | URLEncoded
    | Multipart(String)
}

/// FormData 占位
public class FormData {
    public init() {}

    public static func toJs(bytes: Array<UInt8>, encoding: FormDataEncoding): JsValue {
        JsValue.UNDEFINED
    }
}

/// DOMFormData 占位
public class DOMFormData {
    public init() {}

    public static func fromJs(value: JsValue): ?DOMFormData {
        None
    }
}

/// URLSearchParams 占位
public class URLSearchParams {
    public init() {}

    public static func fromJs(value: JsValue): ?URLSearchParams {
        None
    }

    public func asPtr(): UIntPtr {
        UIntPtr(0)
    }
}

/// ByteStreamPipeCallback 占位
public class ByteStreamPipeCallback {
    public init() {}

    public static func wrap(bufferer: ValueBufferer): ByteStreamPipeCallback {
        ByteStreamPipeCallback()
    }

    public func onPipe(data: Array<UInt8>, isDone: Bool): Unit {}
}

/// DrainResult - 排水结果
/// 对应 Bun: DrainResult
public enum DrainResult {
    | Empty                          // 空
    | Aborted                        // 已中止
    | EstimatedSize(BlobSizeType)    // 估算大小
    | Owned(ArrayList<UInt8>, BlobSizeType)  // 已有数据
}

/// UIntPtr 占位
public type UIntPtr = UIntNative

/// Request 占位
public class Request {
    public init() {}

    public static func `class`(): String {
        "Request"
    }

    public static func fromJs(value: JsValue): ?Request {
        None
    }

    public func getBodyValue(): BodyValue {
        BodyValue()
    }
}

/// Response 占位
public class Response {
    public init() {}

    public static func `class`(): String {
        "Response"
    }

    public static func fromJs(value: JsValue): ?Response {
        None
    }

    public func getBodyValue(): BodyValue {
        BodyValue()
    }
}
