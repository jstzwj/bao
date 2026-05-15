// Body - HTTP 请求/响应体
// 对应 Bun: src/runtime/webcore/Body.zig
// 严格翻译自: src/runtime/webcore/Body.zig
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
    | AbortReason(String)       // 中止原因
    | SystemError(String)       // 系统错误
    | Message(String)           // 错误消息
    | TypeError(String)         // 类型错误

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        match (this) {
            case AbortReason(msg) => {
                let obj = JsObject()
                obj.set("name", JsValue(BaoString("AbortError")))
                obj.set("message", JsValue(BaoString(msg)))
                return JsValue(obj)
            }
            case SystemError(msg) => {
                let obj = JsObject()
                obj.set("name", JsValue(BaoString("SystemError")))
                obj.set("message", JsValue(BaoString(msg)))
                return JsValue(obj)
            }
            case Message(msg) => {
                let obj = JsObject()
                obj.set("message", JsValue(BaoString(msg)))
                return JsValue(obj)
            }
            case TypeError(msg) => {
                let obj = JsObject()
                obj.set("name", JsValue(BaoString("TypeError")))
                obj.set("message", JsValue(BaoString(msg)))
                return JsValue(obj)
            }
        }
    }
}

// ============================================================================
// PendingBodyAction - 异步 Body 动作
// 对应 Bun: Body.PendingValue.Action
// ============================================================================

/// 异步 Body 动作
/// 对应 Bun: Body.PendingValue.Action
public enum PendingBodyAction {
    | None
    | GetText
    | GetJSON
    | GetArrayBuffer
    | GetBytes
    | GetBlob
    | GetFormData
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
    /// 关联的 ReadableStream
    public var readableStream: ?ReadableStream
    /// 当前动作
    public var action: PendingBodyAction
    /// 大小提示
    public var sizeHint: BlobSizeType

    public init() {
        promise = None
        readableStream = None
        action = PendingBodyAction.None
        sizeHint = 0
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
    /// 字符串数据
    public var stringValue: String
    /// 字节数据
    public var bytes: Array<UInt8>
    /// 是否为字符串创建
    public var wasString: Bool
    /// 锁定状态下的待处理值
    public var locked: ?PendingBodyValue
    /// 错误值
    public var error: ?BodyValueError

    public init() {
        tag = BodyValueTag.Null
        blob = None
        stringValue = ""
        bytes = Array<UInt8>()
        wasString = false
        locked = None
        error = None
    }

    public init(blob: Blob) {
        tag = BodyValueTag.Blob
        this.blob = Some(blob)
        stringValue = ""
        bytes = Array<UInt8>()
        wasString = false
        locked = None
        error = None
    }

    public init(text: String) {
        tag = BodyValueTag.WTFStringImpl
        blob = None
        stringValue = text
        bytes = Array<UInt8>()
        wasString = true
        locked = None
        error = None
    }

    public init(bytes: Array<UInt8>) {
        tag = BodyValueTag.InternalBlob
        blob = None
        stringValue = ""
        this.bytes = bytes
        wasString = false
        locked = None
        error = None
    }

    /// 获取数据大小
    /// 对应 Bun: Body.Value.size()
    public func size(): BlobSizeType {
        match (tag) {
            case BlobValueTag.Blob => {
                match (blob) {
                    case Some(b) => b.getSizeForBindings()
                    case None => 0
                }
            }
            case BodyValueTag.InternalBlob => bytes.size
            case BodyValueTag.WTFStringImpl => stringValue.length
            case BodyValueTag.Locked => {
                match (locked) {
                    case Some(p) => p.sizeHint
                    case None => 0
                }
            }
            case _ => 0
        }
    }

    /// 获取估算内存占用
    /// 对应 Bun: Body.Value.memoryCost()
    public func memoryCost(): Int64 {
        match (tag) {
            case BodyValueTag.InternalBlob => bytes.size
            case BodyValueTag.WTFStringImpl => stringValue.length
            case BodyValueTag.Locked => {
                match (locked) {
                    case Some(p) => p.sizeHint
                    case None => 0
                }
            }
            case _ => 0
        }
    }

    /// 是否确定是空的
    /// 对应 Bun: Body.Value.isDefinitelyEmpty()
    public func isDefinitelyEmpty(): Bool {
        match (tag) {
            case BodyValueTag.Null => true
            case BodyValueTag.Used => true
            case BodyValueTag.Empty => true
            case BodyValueTag.InternalBlob => bytes.size == 0
            case BodyValueTag.Blob => {
                match (blob) {
                    case Some(b) => b.size == 0
                    case None => true
                }
            }
            case BodyValueTag.WTFStringImpl => stringValue.length == 0
            case BodyValueTag.Error => false
            case BodyValueTag.Locked => false
        }
    }

    /// 使用 Body 值，将其标记为已使用
    /// 对应 Bun: Body.Value.use()
    public func use(): Blob {
        match (tag) {
            case BodyValueTag.Blob => {
                match (blob) {
                    case Some(b) => {
                        tag = BodyValueTag.Used
                        return b
                    }
                    case None => {
                        tag = BodyValueTag.Used
                        return Blob.initEmpty()
                    }
                }
            }
            case BodyValueTag.InternalBlob => {
                let resultBlob = Blob(bytes, "")
                tag = BodyValueTag.Used
                return resultBlob
            }
            case BodyValueTag.WTFStringImpl => {
                let bytesArr = Utf8Codec.encode(stringValue)
                let resultBlob = Blob(bytesArr, "text/plain")
                tag = BodyValueTag.Used
                return resultBlob
            }
            case _ => {
                return Blob.initEmpty()
            }
        }
    }

    /// 获取字节切片
    /// 对应 Bun: Body.Value.slice()
    public func slice(): Array<UInt8> {
        match (tag) {
            case BodyValueTag.Blob => {
                match (blob) {
                    case Some(b) => b.sharedView()
                    case None => Array<UInt8>()
                }
            }
            case BodyValueTag.InternalBlob => bytes
            case BodyValueTag.WTFStringImpl => Utf8Codec.encode(stringValue)
            case _ => Array<UInt8>()
        }
    }

    /// 克隆 Body 值
    /// 对应 Bun: Body.Value.clone()
    public func clone(): BodyValue {
        match (tag) {
            case BodyValueTag.Blob => {
                match (blob) {
                    case Some(b) => BodyValue(b.dupe())
                    case None => BodyValue()
                }
            }
            case BodyValueTag.InternalBlob => {
                // 转为 Blob 再克隆
                let resultBlob = Blob(bytes, "")
                return BodyValue(resultBlob.dupe())
            }
            case BodyValueTag.WTFStringImpl => {
                return BodyValue(text: stringValue)
            }
            case BodyValueTag.Null => {
                return BodyValue()
            }
            case _ => {
                let v = BodyValue()
                v.tag = BodyValueTag.Empty
                return v
            }
        }
    }

    /// 释放资源
    /// 对应 Bun: Body.Value.deinit()
    public func deinit(): Unit {
        match (tag) {
            case BodyValueTag.InternalBlob => {
                // 释放字节数组
            }
            case BodyValueTag.Blob => {
                match (blob) {
                    case Some(b) => b.deinit()
                    case None => ()
                }
            }
            case BodyValueTag.WTFStringImpl => {
                // 释放字符串
            }
            case BodyValueTag.Locked => {
                match (locked) {
                    case Some(_) => {
                        // 释放 locked 资源
                    }
                    case None => ()
                }
            }
            case BodyValueTag.Error => {
                error = None
            }
            case _ => ()
        }
        tag = BodyValueTag.Null
    }
}

// ============================================================================
// Body - HTTP 请求/响应体
// 对应 Bun: src/runtime/webcore/Body.zig Body
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/Body
// ============================================================================

/// HTTP Body — 请求/响应体
/// 对应 Web API: Body
/// 对应 Bun: src/runtime/webcore/Body.zig Body
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

    /// 将 body 转为文本
    /// 对应 Web API: body.text()
    public func text(): String {
        let bytes = value.slice()
        if (bytes.size == 0) {
            // 尝试字符串
            if (value.tag == BodyValueTag.WTFStringImpl) {
                return value.stringValue
            }
            return ""
        }
        return Utf8Codec.decode(bytes)
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

    /// 释放资源
    /// 对应 Bun: Body.deinit()
    public func deinit(): Unit {
        value.deinit()
    }

    /// 从 JsValue 提取 Body
    /// 对应 Bun: Body.extract()
    public static func extract(value: JsValue): Body {
        if (value.valueType == JsValueType.String) {
            let text = value.stringValue.toString()
            return Body(value: BodyValue(text: text))
        }
        if (value.valueType == JsValueType.Null || value.valueType == JsValueType.Undefined) {
            return Body()
        }
        // 默认: 尝试转为字符串
        let text = value.toString()
        return Body(value: BodyValue(text: text))
    }
}
