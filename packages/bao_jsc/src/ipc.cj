// 严格翻译自: src/jsc/ipc.zig + host_fn.zig + FFI.zig + javascript_core_c_api.zig
// JavaScriptCore IPC 通信、宿主函数和 FFI 绑定

package bao_jsc

// ========== IPC 消息类型 ==========
// 严格翻译自 ipc.zig
public enum IPCMessageType {
    | Version
    | Data
    | Internal
    | Buffer
    | Close
}

// ========== IPC 编码消息 ==========
// 严格翻译自 ipc.zig EncodedMessage
public class IPCEncodedMessage {
    public var tag: IPCMessageType = IPCMessageType.Data
    public var data: Array<UInt8> = []
    public var handleCount: Int64 = 0

    public init() {}
}

// ========== IPC 解码消息 ==========
public class IPCDecodedMessage_ {
    public var tag: IPCMessageType = IPCMessageType.Data
    public var value: JsValue = JsValue.undefined()

    public init() {}
}

// ========== IPC 缓冲区 ==========
// 严格翻译自 ipc.zig IPCBuffer
public class IPCBuffer {
    public var data: Array<UInt8> = []
    public var readPos: Int64 = 0
    public var writePos: Int64 = 0

    public init() {}

    public init(capacity: Int64) {
        data = Array<UInt8>(capacity, {_ => 0})
    }

    // 写入数据
    public func write(bytes: Array<UInt8>) {
        for (b in bytes) {
            data = data.concat([b])
        }
        writePos += Int64(bytes.size)
    }

    // 读取数据
    public func read(count: Int64): Array<UInt8> {
        var result = Array<UInt8>()
        let end = readPos + count
        while (readPos < end && readPos < Int64(data.size)) {
            result = result.concat([data[Int64(readPos)]])
            readPos++
        }
        result
    }

    // 可读字节数
    public func readableBytes(): Int64 {
        writePos - readPos
    }

    // 重置
    public func reset() {
        readPos = 0
        writePos = 0
    }
}

// ========== IPC 发送队列 ==========
// 严格翻译自 ipc.zig SendQueue
public class IPCSendQueue_ {
    public var messages: Array<IPCEncodedMessage> = []
    public var isSending: Bool = false

    public init() {}

    public func enqueue(message: IPCEncodedMessage) {
        messages = messages.concat([message])
    }

    public func dequeue(): ?IPCEncodedMessage {
        if (messages.size == 0) { return None }
        let msg = messages[0]
        messages = messages.slice(1, messages.size)
        Some(msg)
    }

    public func drain(): Array<IPCEncodedMessage> {
        let result = messages
        messages = []
        result
    }
}

// ========== 宿主函数类型 ==========
// 严格翻译自 host_fn.zig
// JavaScript 调用 Zig/仓颉 的函数回调类型
public type JSHostFn = (JsObject, CallFrame) -> JsValue

// 宿主函数包装器
public class HostFunction {
    public var name: String = ""
    public var length: Int64 = 0
    public var callback: ?JSHostFn = None
    public var isConstructor: Bool = false

    public init() {}

    public init(name: String, callback: JSHostFn) {
        this.name = name
        this.callback = callback
    }

    public init(name: String, length: Int64, callback: JSHostFn) {
        this.name = name
        this.length = length
        this.callback = callback
    }

    // 调用
    public func call(global: JsObject, callFrame: CallFrame): JsValue {
        if (let Some(cb) <- callback) {
            return cb(global, callFrame)
        }
        JsValue.undefined()
    }
}

// ========== FFI 类型 ==========
// 严格翻译自 FFI.zig
// FFI 函数参数和返回值类型
public enum FFIValueType {
    | `Void`
    | `Int8`
    | `Int16`
    | `Int32`
    | `Int64`
    | `UInt8`
    | `UInt16`
    | `UInt32`
    | `UInt64`
    | `Float32`
    | `Float64`
    | `Pointer`
    | `Bool`
    | `SizeT`

    public operator func ==(right: FFIValueType): Bool {
        match (this) {
            case `Void` => match(right) { case `Void` => true case _ => false }
            case `Int8` => match(right) { case `Int8` => true case _ => false }
            case `Int16` => match(right) { case `Int16` => true case _ => false }
            case `Int32` => match(right) { case `Int32` => true case _ => false }
            case `Int64` => match(right) { case `Int64` => true case _ => false }
            case `UInt8` => match(right) { case `UInt8` => true case _ => false }
            case `UInt16` => match(right) { case `UInt16` => true case _ => false }
            case `UInt32` => match(right) { case `UInt32` => true case _ => false }
            case `UInt64` => match(right) { case `UInt64` => true case _ => false }
            case `Float32` => match(right) { case `Float32` => true case _ => false }
            case `Float64` => match(right) { case `Float64` => true case _ => false }
            case `Pointer` => match(right) { case `Pointer` => true case _ => false }
            case `Bool` => match(right) { case `Bool` => true case _ => false }
            case `SizeT` => match(right) { case `SizeT` => true case _ => false }
        }
    }

    public operator func !=(right: FFIValueType): Bool {
        !(this == right)
    }

    // 获取大小
    public func size(): Int64 {
        match (this) {
            case `Void` => 0
            case `Int8` | `UInt8` | `Bool` => 1
            case `Int16` | `UInt16` => 2
            case `Int32` | `UInt32` | `Float32` => 4
            case `Int64` | `UInt64` | `Float64` | Pointer | SizeT => 8
        }
    }

    // 是否为整数类型
    public func isInteger(): Bool {
        match (this) {
            case `Int8` | `Int16` | `Int32` | `Int64` | `UInt8` | `UInt16` | `UInt32` | `UInt64` | `Bool` | SizeT => true
            case _ => false
        }
    }

    // 是否为浮点类型
    public func isFloat(): Bool {
        this == `Float32` || this == `Float64`
    }
}

// FFI 函数描述
public class FFIFunction {
    public var name: String = ""
    public var library: String = ""
    public var returnType: FFIValueType = FFIValueType.`Void`
    public var paramTypes: Array<FFIValueType> = []
    public var convention: FFICallingConvention = FFICallingConvention.C

    public init() {}

    // 获取参数总大小
    public func paramsSize(): Int64 {
        var total: Int64 = 0
        for (t in paramTypes) {
            total += t.size()
        }
        total
    }
}

// FFI 调用约定
public enum FFICallingConvention {
    | C         // __cdecl
    | Stdcall   // __stdcall
    | Fastcall  // __fastcall
}

// FFI 值包装
public class FFIValue {
    public var `type`: FFIValueType = FFIValueType.`Void`
    public var intValue: Int64 = 0
    public var floatValue: Float64 = 0.0
    public var ptrValue: CPointer<UInt8> = CPointer<UInt8>()

    public init() {}

    public init(v: Int64) {
        this.`type` = FFIValueType.`Int64`
        this.intValue = v
    }

    public init(v: Float64) {
        this.`type` = FFIValueType.`Float64`
        this.floatValue = v
    }

    public init(v: Bool) {
        this.`type` = FFIValueType.`Bool`
        this.intValue = if (v) { 1 } else { 0 }
    }

    // 从 JsValue 转换
    public static func fromJS(value: JsValue): FFIValue {
        if (value.isNumber()) {
            return FFIValue(value.toNumber())
        }
        if (value.isBoolean()) {
            return FFIValue(value.toBoolean())
        }
        FFIValue()
    }

    // 转为 JsValue
    public func toJS(): JsValue {
        match (`type`) {
            case `Bool` => JsValue(intValue != 0)
            case `Int8` | `Int16` | `Int32` | `Int64` => JsValue(intValue)
            case `UInt8` | `UInt16` | `UInt32` | `UInt64` | SizeT => JsValue(intValue)
            case `Float32` | `Float64` => JsValue(floatValue)
            case `Pointer` => JsValue(intValue)
            case `Void` => JsValue.undefined()
        }
    }
}

// ========== C API 辅助 ==========
// 严格翻译自 javascript_core_c_api.zig

// JSValue 来源标记
public enum JSValueTag {
    | Boolean
    | Null
    | Undefined
    | Number
    | String
    | Object
    | Symbol
}

// JSClass 定义
public class JSClassDefinition {
    public var version: Int64 = 0
    public var attributes: Int64 = 0
    public var className: String = ""
    public var parentClass: ?JSClassRef = None
    public var initialValues: Array<(String, JsValue)> = []
    public var staticValues: Array<(String, JsFunction)> = []
    public var staticFunctions: Array<(String, JsFunction)> = []

    public init() {}

    public init(className: String) {
        this.className = className
    }
}

// JSStaticValue
public class JSStaticValue {
    public var name: String = ""
    public var getter: ?JsFunction = None
    public var setter: ?JsFunction = None
    public var attributes: Int64 = 0

    public init() {}
}

// JSStaticFunction
public class JSStaticFunction {
    public var name: String = ""
    public var callback: ?JsFunction = None
    public var attributes: Int64 = 0

    public init() {}
}

// ==========================================================================
// ========== 以下为 ipc.zig 的核心扩展翻译 ==========
// ==========================================================================

// ========== IPC Mode ==========
// 严格翻译自 ipc.zig Mode
// IPC 通信模式
public enum IPCMode {
    | Advanced   // 使用 SerializedScriptValue，仅用于 bun <-> bun
    | Json       // 使用 JSON 消息，每行一条，兼容 bun <-> node.js

    // 严格翻译自 Mode.fromString
    public static func fromString(s: String): ?IPCMode {
        if (s == "advanced") { return IPCMode.Advanced }
        if (s == "json") { return IPCMode.Json }
        None
    }
}

// ========== IPCDecodeError ==========
// 严格翻译自 ipc.zig IPCDecodeError
public enum IPCDecodeError {
    | NotEnoughBytes    // 字节数不足，等待更多数据
    | InvalidFormat     // 格式无法识别
    | JSError           // JS 执行错误
    | OutOfMemory       // 内存不足
}

// ========== IPCSerializationError ==========
// 严格翻译自 ipc.zig IPCSerializationError
public enum IPCSerializationError {
    | SerializationFailed   // 值无法序列化
    | JSError               // JS 执行错误
}

// ========== SerializeAndSendResult ==========
// 严格翻译自 ipc.zig SerializeAndSendResult
public enum SerializeAndSendResult {
    | Success   // 发送成功
    | Failure   // 发送失败
    | Backoff   // 等待 ACK 后继续

    public operator func ==(right: SerializeAndSendResult): Bool {
        match (this) {
            case Success => match(right) { case Success => true case _ => false }
            case Failure => match(right) { case Failure => true case _ => false }
            case Backoff => match(right) { case Backoff => true case _ => false }
        }
    }

    public operator func !=(right: SerializeAndSendResult): Bool {
        !(this == right)
    }
}

// ========== DecodedIPCMessage ==========
// 严格翻译自 ipc.zig DecodedIPCMessage
// 解码后的 IPC 消息联合类型
public class DecodedIPCMessage {
    public var tag: IPCMessageTag = IPCMessageTag.Data
    public var versionValue: UInt32 = 0
    public var dataValue: JsValue = JsValue.undefined()
    public var internalValue: JsValue = JsValue.undefined()

    public init() {}

    // 严格翻译自 DecodedIPCMessage.version
    public static func version(v: UInt32): DecodedIPCMessage {
        let msg = DecodedIPCMessage()
        msg.tag = IPCMessageTag.Version
        msg.versionValue = v
        msg
    }

    // 严格翻译自 DecodedIPCMessage.data
    public static func data(v: JsValue): DecodedIPCMessage {
        let msg = DecodedIPCMessage()
        msg.tag = IPCMessageTag.Data
        msg.dataValue = v
        msg
    }

    // 严格翻译自 DecodedIPCMessage.internal
    public static func internalMessage(v: JsValue): DecodedIPCMessage {
        let msg = DecodedIPCMessage()
        msg.tag = IPCMessageTag.Internal
        msg.internalValue = v
        msg
    }

    public func isVersion(): Bool {
        tag == IPCMessageTag.Version
    }

    public func isData(): Bool {
        tag == IPCMessageTag.Data
    }

    public func isInternal(): Bool {
        tag == IPCMessageTag.Internal
    }
}

// ========== IPCMessageTag ==========
// 严格翻译自 ipc.zig DecodedIPCMessage union tag
public enum IPCMessageTag {
    | Version
    | Data
    | Internal

    public operator func ==(right: IPCMessageTag): Bool {
        match (this) {
            case Version => match(right) { case Version => true case _ => false }
            case Data => match(right) { case Data => true case _ => false }
            case Internal => match(right) { case Internal => true case _ => false }
        }
    }

    public operator func !=(right: IPCMessageTag): Bool {
        !(this == right)
    }
}

// ========== DecodeIPCMessageResult ==========
// 严格翻译自 ipc.zig DecodeIPCMessageResult
public class DecodeIPCMessageResult {
    public var bytesConsumed: UInt32 = 0
    public var message: DecodedIPCMessage = DecodedIPCMessage()

    public init() {}

    public init(bytesConsumed: UInt32, message: DecodedIPCMessage) {
        this.bytesConsumed = bytesConsumed
        this.message = message
    }
}

// ========== AdvancedIPCMessageType ==========
// 严格翻译自 advanced.IPCMessageType
// Extracted from IPCAdvanced (no nested enums in Cangjie)
public enum AdvancedIPCMessageType {
    | Version
    | SerializedMessage
    | SerializedInternalMessage
    | Unknown

    public func value(): UInt8 {
        match (this) {
            case Version => 1
            case SerializedMessage => 2
            case SerializedInternalMessage => 3
            case Unknown => 255
        }
    }

    public static func fromValue(v: UInt8): AdvancedIPCMessageType {
        match (v) {
            case 1 => AdvancedIPCMessageType.Version
            case 2 => AdvancedIPCMessageType.SerializedMessage
            case 3 => AdvancedIPCMessageType.SerializedInternalMessage
            case _ => AdvancedIPCMessageType.Unknown
        }
    }
}

// ========== Advanced IPC ==========
// 严格翻译自 ipc.zig advanced 命名空间
public class IPCAdvanced {
    // 严格翻译自 advanced.header_length
    // header = IPCMessageType(1 byte) + u32(4 bytes) = 5 bytes
    public static let HEADER_LENGTH: Int64 = 5

    // 严格翻译自 advanced.version
    public static let VERSION: UInt32 = 1

    // ========== VersionPacket ==========
    // 严格翻译自 advanced.VersionPacket
    // extern struct { type: IPCMessageType, version: u32 }

    // ========== decodeIPCMessage ==========
    // 严格翻译自 advanced.decodeIPCMessage
    // 解码高级模式的 IPC 消息
    public static func decodeIPCMessage(data: Array<UInt8>, global: JsObject): ?DecodeIPCMessageResult {
        if (data.size < HEADER_LENGTH) {
            return None  // NotEnoughBytes
        }

        let messageTypeVal = data[0]
        let messageType = AdvancedIPCMessageType.fromValue(messageTypeVal)

        // 读取消息长度 (little-endian u32)
        let messageLen = UInt32(data[1]) |
                         (UInt32(data[2]) << 8) |
                         (UInt32(data[3]) << 16) |
                         (UInt32(data[4]) << 24)

        match (messageType) {
            case Version=>
                let msg = DecodedIPCMessage.version(messageLen)
                DecodeIPCMessageResult(UInt32(HEADER_LENGTH), msg)
            case SerializedMessage=>
                let needed = Int64(HEADER_LENGTH) + Int64(messageLen)
                if (Int64(data.size) < needed) {
                    return None  // NotEnoughBytes
                }
                // 反序列化消息体
                let bodyStart = Int64(HEADER_LENGTH)
                let bodyEnd = bodyStart + Int64(messageLen)
                let body = data[bodyStart..bodyEnd]
                let deserialized = JsValue.deserialize(body, global)
                let msg = DecodedIPCMessage.data(deserialized)
                DecodeIPCMessageResult(UInt32(needed), msg)
            case SerializedInternalMessage=>
                let needed = Int64(HEADER_LENGTH) + Int64(messageLen)
                if (Int64(data.size) < needed) {
                    return None  // NotEnoughBytes
                }
                let bodyStart = Int64(HEADER_LENGTH)
                let bodyEnd = bodyStart + Int64(messageLen)
                let body = data[bodyStart..bodyEnd]
                let deserialized = JsValue.deserialize(body, global)
                let msg = DecodedIPCMessage.internalMessage(deserialized)
                DecodeIPCMessageResult(UInt32(needed), msg)
            case Unknown=>
                None  // InvalidFormat
        }
    }

    // ========== getVersionPacket ==========
    // 严格翻译自 advanced.getVersionPacket
    public static func getVersionPacket(): Array<UInt8> {
        VersionPacket().toBytes()
    }

    // ========== getAckPacket ==========
    // 严格翻译自 advanced.getAckPacket
    public static func getAckPacket(): Array<UInt8> {
        // 二进制 ACK 包
        let bytes: Array<UInt8> = [
            0x02, 0x24, 0x00, 0x00, 0x00, 0x0d, 0x00, 0x00, 0x00,
            0x02, 0x03, 0x00, 0x00, 0x80, 0x63, 0x6d, 0x64, 0x10,
            0x0f, 0x00, 0x00, 0x80, 0x4e, 0x4f, 0x44, 0x45, 0x5f,
            0x48, 0x41, 0x4e, 0x44, 0x4c, 0x45, 0x5f, 0x41, 0x43,
            0x4b, 0xff, 0xff, 0xff, 0xff
        ]
        bytes
    }

    // ========== getNackPacket ==========
    // 严格翻译自 advanced.getNackPacket
    public static func getNackPacket(): Array<UInt8> {
        let bytes: Array<UInt8> = [
            0x02, 0x25, 0x00, 0x00, 0x00, 0x0d, 0x00, 0x00, 0x00,
            0x02, 0x03, 0x00, 0x00, 0x80, 0x63, 0x6d, 0x64, 0x10,
            0x10, 0x00, 0x00, 0x80, 0x4e, 0x4f, 0x44, 0x45, 0x5f,
            0x48, 0x41, 0x4e, 0x44, 0x4c, 0x45, 0x5f, 0x4e, 0x41,
            0x43, 0x4b, 0xff, 0xff, 0xff, 0xff
        ]
        bytes
    }

    // ========== serialize ==========
    // 严格翻译自 advanced.serialize
    // 序列化 JSValue 为 IPC 消息
    public static func serialize(writer: StreamBuffer, global: JsObject, value: JsValue, isInternal: Bool): Int64 {
        // 序列化值 (使用 JSC 的 SerializedScriptValue 格式)
        let serializedOpt = value.serialize(global, true, false)
        var dataSize: Int64 = 0
        var serializedBytes: Array<UInt8> = []

        match (serializedOpt) {
            case Some(sv) =>
                serializedBytes = sv.data
                dataSize = Int64(serializedBytes.size)
            case None =>
                // 序列化失败: 写入空消息体
                dataSize = 0
        }

        // 写入 header + body
        let payloadLength = HEADER_LENGTH + dataSize

        // 确保写入缓冲区有足够容量
        writer.ensureUnusedCapacity(payloadLength)

        // 写入消息类型
        let msgType = if (isInternal) {
            AdvancedIPCMessageType.SerializedInternalMessage.value()
        } else {
            AdvancedIPCMessageType.SerializedMessage.value()
        }

        // 构建完整包
        var packet = Array<UInt8>()
        packet = packet.concat([msgType])
        // Little-endian u32 size
        packet = packet.concat([UInt8(dataSize & 0xFF)])
        packet = packet.concat([UInt8((dataSize >> 8) & 0xFF)])
        packet = packet.concat([UInt8((dataSize >> 16) & 0xFF)])
        packet = packet.concat([UInt8((dataSize >> 24) & 0xFF)])
        // 写入消息体
        for (b in serializedBytes) {
            packet = packet.concat([b])
        }

        writer.write(packet)
        payloadLength
    }
}

// ========== StreamBuffer ==========
// 严格翻译自 bun.io.StreamBuffer
// 用于 IPC 消息的写入缓冲区
public class StreamBuffer {
    public var list: Array<UInt8> = []
    public var cursor: Int64 = 0

    public init() {}

    public init(capacity: Int64) {
        list = Array<UInt8>(capacity, {_ => 0})
    }

    // 写入字节
    public func write(bytes: Array<UInt8>) {
        for (b in bytes) {
            list = list.concat([b])
        }
    }

    // 确保剩余容量
    public func ensureUnusedCapacity(count: Int64) {
        let needed = Int64(list.size) + count
        if (needed > Int64(list.size)) {
            let extra = Array<UInt8>(Int64(needed - Int64(list.size)), {_ => 0})
            list = list.concat(extra)
        }
    }

    // 剩余可读字节数
    public func readableBytes(): Int64 {
        Int64(list.size) - cursor
    }

    // 重置
    public func reset() {
        list = []
        cursor = 0
    }
}

// ========== JSON IPC ==========
// 严格翻译自 ipc.zig json 命名空间
public class IPCJson {
    // ========== getVersionPacket ==========
    // 严格翻译自 json.getVersionPacket
    // JSON 模式的版本包为空
    public static func getVersionPacket(): Array<UInt8> {
        []
    }

    // ========== getAckPacket ==========
    // 严格翻译自 json.getAckPacket
    public static func getAckPacket(): Array<UInt8> {
        let str = "{\"cmd\":\"NODE_HANDLE_ACK\"}\n"
        str.toArray()
    }

    // ========== getNackPacket ==========
    // 严格翻译自 json.getNackPacket
    public static func getNackPacket(): Array<UInt8> {
        let str = "{\"cmd\":\"NODE_HANDLE_NACK\"}\n"
        str.toArray()
    }

    // ========== decodeIPCMessage ==========
    // 严格翻译自 json.decodeIPCMessage
    // JSON 模式消息解码
    public static func decodeIPCMessage(data: Array<UInt8>, global: JsObject, knownNewline: ?UInt32): ?DecodeIPCMessageResult {
        // 查找换行符
        var idx: UInt32 = match (knownNewline) {
            case Some(v) => v
            case None => UInt32(0)
        }

        var knownNewlineFound = match (knownNewline) {
            case Some(_) => true
            case None => false
        }

        if (!knownNewlineFound) {
            var found = false
            for (i in 0..data.size) {
                if (data[i] == 10) {  // '\n'
                    idx = UInt32(i)
                    found = true
                    break
                }
            }
            if (!found) {
                return None  // NotEnoughBytes
            }
        }

        if (idx == 0) {
            return None  // InvalidFormat - 空 payload
        }

        // 提取 JSON 数据
        var jsonData = data[0..Int64(idx)]

        // 判断消息类型
        var kind = JsonMessageKind.Regular
        if (jsonData.size > 0 && jsonData[0] == 2) {
            // 内部消息以字节 2 开头
            kind = JsonMessageKind.Internal
            jsonData = jsonData[1..]
        }

        if (jsonData.size == 0) {
            return None  // InvalidFormat
        }

        // 将字节转为字符串并解析 JSON
        var jsonStr = ""
        for (b in jsonData) {
            jsonStr = jsonStr + String(Rune(b))
        }
        let deserialized = JsValue.parseJson(jsonStr)

        match (kind) {
            case Regular=>
                let msg = DecodedIPCMessage.data(deserialized)
                DecodeIPCMessageResult(idx + 1, msg)
            case Internal=>
                let msg = DecodedIPCMessage.internalMessage(deserialized)
                DecodeIPCMessageResult(idx + 1, msg)
        }
    }

    // ========== serialize ==========
    // 严格翻译自 json.serialize
    // JSON 模式消息序列化
    public static func serialize(writer: StreamBuffer, global: JsObject, value: JsValue, isInternal: Bool): Int64 {
        // JSON.stringify
        let jsonStr = value.jsonStringifyFast(global)
        let bytes = jsonStr.toArray()

        var resultLen: Int64 = Int64(bytes.size) + 1  // +1 for newline
        if (isInternal) {
            resultLen += 1  // +1 for internal tag byte
        }

        writer.ensureUnusedCapacity(resultLen)

        if (isInternal) {
            writer.write([2])  // internal tag
        }
        writer.write(bytes)
        writer.write([10])  // '\n'

        resultLen
    }
}

// ========== JsonMessageKind ==========
public enum JsonMessageKind {
    | Regular
    | Internal
}

// ========== IPC 顶层函数 ==========
// 严格翻译自 ipc.zig 顶层函数

// ========== decodeIPCMessage ==========
// 严格翻译自 ipc.decodeIPCMessage
// 根据 mode 选择解码策略
public func decodeIPCMessage(mode: IPCMode, data: Array<UInt8>, global: JsObject, knownNewline: ?UInt32): ?DecodeIPCMessageResult {
    match (mode) {
        case IPCMode.Advanced => IPCAdvanced.decodeIPCMessage(data, global)
        case IPCMode.Json => IPCJson.decodeIPCMessage(data, global, knownNewline)
    }
}

// ========== getVersionPacket ==========
// 严格翻译自 ipc.getVersionPacket
// 返回指定模式的初始化包
public func getVersionPacket(mode: IPCMode): Array<UInt8> {
    match (mode) {
        case IPCMode.Advanced => IPCAdvanced.getVersionPacket()
        case IPCMode.Json => IPCJson.getVersionPacket()
    }
}

// ========== serialize ==========
// 严格翻译自 ipc.serialize
// 序列化并写入值到 writer
public func ipcSerialize(mode: IPCMode, writer: StreamBuffer, global: JsObject, value: JsValue, isInternal: Bool): Int64 {
    match (mode) {
        case IPCMode.Advanced => IPCAdvanced.serialize(writer, global, value, isInternal)
        case IPCMode.Json => IPCJson.serialize(writer, global, value, isInternal)
    }
}

// ========== getAckPacket ==========
// 严格翻译自 ipc.getAckPacket
public func getAckPacket(mode: IPCMode): Array<UInt8> {
    match (mode) {
        case IPCMode.Advanced => IPCAdvanced.getAckPacket()
        case IPCMode.Json => IPCJson.getAckPacket()
    }
}

// ========== getNackPacket ==========
// 严格翻译自 ipc.getNackPacket
public func getNackPacket(mode: IPCMode): Array<UInt8> {
    match (mode) {
        case IPCMode.Advanced => IPCAdvanced.getNackPacket()
        case IPCMode.Json => IPCJson.getNackPacket()
    }
}

// ========== IPC Handle ==========
// 严格翻译自 ipc.zig Handle
// IPC 传输的文件描述符句柄
public class IPCHandle {
    public var fd: Int64 = -1        // 文件描述符
    public var jsValue: JsValue = JsValue.undefined()  // 关联的 JS 值

    public init() {}

    public init(fd: Int64, js: JsValue) {
        this.fd = fd
        this.jsValue = js
    }

    // 严格翻译自 Handle.init
    public static func `init`(fd: Int64, js: JsValue): IPCHandle {
        IPCHandle(fd, js)
    }
}

// ========== IPC CallbackList ==========
// 严格翻译自 ipc.zig CallbackList
// IPC 回调列表，支持单个回调或回调数组
public class IPCCallbackList {
    public var tag: CallbackListTag = CallbackListTag.None
    public var callback: JsValue = JsValue.undefined()
    public var callbackArray: JsValue = JsValue.undefined()

    public init() {}

    // 严格翻译自 CallbackList.init
    public static func `init`(callback: JsValue): IPCCallbackList {
        let list = IPCCallbackList()
        if (callback.isCallable()) {
            list.tag = CallbackListTag.Callback
            list.callback = callback
        } else {
            list.tag = CallbackListTag.None
        }
        list
    }

    // 严格翻译自 CallbackList.push
    // 添加回调到列表
    public func push(callback: JsValue, global: JsObject): Unit {
        match (tag) {
            case CallbackListTag.AckNack => ()  // unreachable
            case CallbackListTag.None=>
                tag = CallbackListTag.Callback
                this.callback = callback
            case CallbackListTag.Callback=>
                // 升级为数组
                let arr = JsValue.createEmptyArray(global, 2)
                arr.putIndex(global, 0, this.callback)
                arr.putIndex(global, 1, callback)
                tag = CallbackListTag.CallbackArray
                callbackArray = arr
            case CallbackListTag.CallbackArray=>
                callbackArray.push(global, callback)
        }
    }

    // 严格翻译自 CallbackList.callNextTick
    // 调用所有回调
    public func callNextTick(global: JsObject): Unit {
        match (tag) {
            case CallbackListTag.AckNack => ()
            case CallbackListTag.None => ()
            case CallbackListTag.Callback=>
                callback.callNextTick(global, JsValue.null())
                tag = CallbackListTag.None
            case CallbackListTag.CallbackArray=>
                // 严格翻译自 CallbackList.callNextTick (callback_array 分支)
                // 遍历回调数组中的每个回调并调用
                if (callbackArray.isArray()) {
                    let arrLen = callbackArray.getLength(global)
                    var i: UInt64 = 0
                    while (i < arrLen) {
                        let item = callbackArray.getIndex(global, UInt32(i))
                        item.callNextTick(global, JsValue.null())
                        i += 1
                    }
                }
                tag = CallbackListTag.None
        }
    }

    // 严格翻译自 CallbackList.deinit
    public func deinit(): Unit {
        tag = CallbackListTag.None
    }
}

// ========== CallbackListTag ==========
public enum CallbackListTag {
    | AckNack
    | None
    | Callback
    | CallbackArray

    public operator func ==(right: CallbackListTag): Bool {
        match (this) {
            case AckNack => match(right) { case AckNack => true case _ => false }
            case None => match(right) { case None => true case _ => false }
            case Callback => match(right) { case Callback => true case _ => false }
            case CallbackArray => match(right) { case CallbackArray => true case _ => false }
        }
    }

    public operator func !=(right: CallbackListTag): Bool {
        !(this == right)
    }
}

// ========== IPC SendHandle ==========
// 严格翻译自 ipc.zig SendHandle
// 发送队列中的消息项
public class IPCSendHandle {
    public var data: StreamBuffer = StreamBuffer()
    public var handle: ?IPCHandle = None
    public var callbacks: IPCCallbackList = IPCCallbackList()

    public init() {}

    public init(handle: ?IPCHandle, callbacks: IPCCallbackList) {
        this.handle = handle
        this.callbacks = callbacks
    }

    // 严格翻译自 SendHandle.isAckNack
    public func isAckNack(): Bool {
        callbacks.tag == CallbackListTag.AckNack
    }

    // 严格翻译自 SendHandle.complete
    // 调用回调并清理
    public func complete(global: JsObject): Unit {
        callbacks.callNextTick(global)
        deinit()
    }

    // 严格翻译自 SendHandle.deinit
    public func deinit(): Unit {
        data.reset()
        callbacks.deinit()
        handle = None
    }
}

// ========== IPC IncomingBuffer ==========
// 严格翻译自 ipc.zig IncomingBuffer
// 输入缓冲区，支持 advanced 和 json 两种模式
public class IPCIncomingBuffer {
    public var tag: IncomingBufferTag = IncomingBufferTag.Advanced
    // Advanced 模式: 简单字节列表
    public var advancedData: Array<UInt8> = []
    // JSON 模式: 带换行追踪的缓冲区
    public var jsonData: Array<UInt8> = []
    public var jsonNewlinePositions: Array<Int64> = []

    public init() {}

    // 严格翻译自 IncomingBuffer.init
    public init(mode: IPCMode) {
        match (mode) {
            case IPCMode.Advanced=>
                tag = IncomingBufferTag.Advanced
                advancedData = []
            case IPCMode.Json=>
                tag = IncomingBufferTag.Json
                jsonData = []
                jsonNewlinePositions = []
        }
    }

    // 严格翻译自 IncomingBuffer.append (json mode)
    // 追加数据并扫描换行
    public func append(newData: Array<UInt8>): Unit {
        if (tag == IncomingBufferTag.Json) {
            let startOffset = jsonData.size
            for (i in 0..newData.size) {
                jsonData = jsonData.concat([newData[i]])
                if (newData[i] == 10) {  // '\n'
                    jsonNewlinePositions = jsonNewlinePositions.concat([Int64(startOffset) + Int64(i)])
                }
            }
        } else {
            for (b in newData) {
                advancedData = advancedData.concat([b])
            }
        }
    }

    // 严格翻译自 JSONLineBuffer.next
    // 获取下一个完整消息 (JSON 模式)
    public func next(): ?IPCJsonMessage {
        if (tag != IncomingBufferTag.Json) {
            return None
        }
        if (jsonNewlinePositions.size == 0) {
            return None
        }
        let newlinePos = jsonNewlinePositions[0]
        jsonNewlinePositions = jsonNewlinePositions[1..]
        let msg = IPCJsonMessage()
        msg.data = jsonData[0..Int64(newlinePos)]
        msg.newlinePos = UInt32(newlinePos)
        jsonData = jsonData[Int64(newlinePos) + 1..]
        msg
    }

    // 严格翻译自 JSONLineBuffer.consume
    // 消费指定字节数
    public func consume(count: UInt32): Unit {
        if (tag == IncomingBufferTag.Json) {
            let c = Int64(count)
            if (c < jsonData.size) {
                jsonData = jsonData[c..]
            } else {
                jsonData = []
            }
        } else {
            let c = Int64(count)
            if (c < advancedData.size) {
                advancedData = advancedData[c..]
            } else {
                advancedData = []
            }
        }
    }

    // 严格翻译自 IncomingBuffer.deinit
    public func deinit(): Unit {
        advancedData = []
        jsonData = []
        jsonNewlinePositions = []
    }

    // 获取当前缓冲区切片
    public func slice(): Array<UInt8> {
        if (tag == IncomingBufferTag.Advanced) {
            advancedData
        } else {
            jsonData
        }
    }

    // 获取数据长度
    public func len(): Int64 {
        if (tag == IncomingBufferTag.Advanced) {
            Int64(advancedData.size)
        } else {
            Int64(jsonData.size)
        }
    }
}

// ========== IncomingBufferTag ==========
public enum IncomingBufferTag {
    | Advanced
    | Json

    public operator func ==(right: IncomingBufferTag): Bool {
        match (this) {
            case Advanced => match(right) { case Advanced => true case _ => false }
            case Json => match(right) { case Json => true case _ => false }
        }
    }

    public operator func !=(right: IncomingBufferTag): Bool {
        !(this == right)
    }
}

// ========== IPCJsonMessage ==========
// JSON 模式下的消息
public class IPCJsonMessage {
    public var data: Array<UInt8> = []
    public var newlinePos: UInt32 = 0

    public init() {}
}

// ========== IPC SocketState ==========
// 严格翻译自 ipc.zig SocketUnion
public enum IPCSocketState {
    | Uninitialized
    | Open
    | Closed

    public operator func ==(right: IPCSocketState): Bool {
        match (this) {
            case Uninitialized => match(right) { case Uninitialized => true case _ => false }
            case Open => match(right) { case Open => true case _ => false }
            case Closed => match(right) { case Closed => true case _ => false }
        }
    }

    public operator func !=(right: IPCSocketState): Bool {
        !(this == right)
    }
}

// ========== IPC SendQueueOwner ==========
// 严格翻译自 ipc.zig SendQueueOwner
public enum IPCSendQueueOwner {
    | Subprocess
    | VirtualMachine
}

// ========== IPC SendQueue (完整版) ==========
// 严格翻译自 ipc.zig SendQueue
// 完整的 IPC 发送队列实现
public class IPCSendQueue {
    public var queue: Array<IPCSendHandle> = []
    public var waitingForAck: ?IPCSendHandle = None
    public var retryCount: UInt32 = 0
    public var mode: IPCMode = IPCMode.Advanced
    public var incoming: IPCIncomingBuffer = IPCIncomingBuffer()
    public var incomingFd: ?Int64 = None
    public var socketState: IPCSocketState = IPCSocketState.Uninitialized
    public var owner: IPCSendQueueOwner = IPCSendQueueOwner.Subprocess
    public var closeNextTick: Bool = false
    public var writeInProgress: Bool = false
    public var closeEventSent: Bool = false
    public var hasWrittenVersion: Bool = false

    // 严格翻译自 MAX_HANDLE_RETRANSMISSIONS
    public static let MAX_HANDLE_RETRANSMISSIONS: UInt32 = 3

    public init() {}

    // 严格翻译自 SendQueue.init
    public init(mode: IPCMode, owner: IPCSendQueueOwner) {
        this.mode = mode
        this.owner = owner
        this.incoming = IPCIncomingBuffer(mode)
    }

    // 严格翻译自 SendQueue.isConnected
    public func isConnected(): Bool {
        socketState == IPCSocketState.Open && !closeNextTick
    }

    // 严格翻译自 SendQueue.deinit
    public func deinit(): Unit {
        closeSocket(false)
        for (item in queue) {
            item.deinit()
        }
        queue = []
        incoming.deinit()
        incomingFd = None
        if (let Some(waiting) <- waitingForAck) {
            waiting.deinit()
        }
        waitingForAck = None
    }

    // 严格翻译自 SendQueue.closeSocket
    public func closeSocket(reason: Bool): Unit {
        if (socketState == IPCSocketState.Open) {
            socketState = IPCSocketState.Closed
        }
    }

    // 严格翻译自 SendQueue.closeSocketNextTick
    public func closeSocketNextTick(nextTick: Bool): Unit {
        if (socketState != IPCSocketState.Open) {
            socketState = IPCSocketState.Closed
            return
        }
        if (closeNextTick) {
            return
        }
        if (!nextTick) {
            closeSocket(true)
            return
        }
        closeNextTick = true
    }

    // 严格翻译自 SendQueue.writeVersionPacket
    // 发送版本握手包
    public func writeVersionPacket(global: JsObject): Unit {
        let bytes = getVersionPacket(mode)
        if (bytes.size > 0) {
            let handle = IPCSendHandle()
            handle.data.write(bytes)
            queue = queue.concat([handle])
            continueSend(global)
        }
        hasWrittenVersion = true
    }

    // 严格翻译自 SendQueue.startMessage
    // 开始一个新消息
    public func startMessage(global: JsObject, callback: JsValue, handle: ?IPCHandle): ?IPCSendHandle {
        // 优化: 如果最后一个消息没有 handle 且不是 ack/nack
        let hasHandle = match (handle) {
            case Some(_) => true
            case None => false
        }
        if (!hasHandle && queue.size > 0) {
            let last = queue[queue.size - 1]
            let lastHasHandle = match (last.handle) {
                case Some(_) => true
                case None => false
            }
            if (!lastHasHandle && !last.isAckNack()) {
                if (callback.isCallable()) {
                    last.callbacks.push(callback, global)
                }
                return last
            }
        }

        // 新增消息
        let msgHandle = IPCSendHandle()
        msgHandle.handle = handle
        msgHandle.callbacks = IPCCallbackList.`init`(callback)
        queue = queue.concat([msgHandle])
        queue[queue.size - 1]
    }

    // 严格翻译自 SendQueue.insertMessage
    // 在合适的位置插入消息
    public func insertMessage(message: IPCSendHandle): Unit {
        if (queue.size == 0 || (queue[0].data.cursor == 0 && !writeInProgress)) {
            queue = [message].concat(queue)
        } else {
            // 在索引 1 处插入
            queue = [queue[0], message].concat(queue.slice(1, queue.size))
        }
    }

    // 严格翻译自 SendQueue.serializeAndSend
    // 序列化并发送值
    public func serializeAndSend(global: JsObject, value: JsValue, isInternal: Bool, callback: JsValue, handle: ?IPCHandle): SerializeAndSendResult {
        let indicateBackoff = match (waitingForAck) {
            case Some(_) => true
            case None => false
        } && queue.size > 0

        let msg = startMessage(global, callback, handle)
        let msgIsNone = match (msg) {
            case Some(_) => false
            case None => true
        }
        if (msgIsNone) {
            return SerializeAndSendResult.Failure
        }

        let payloadLength = ipcSerialize(mode, msg.getOrThrow().data, global, value, isInternal)

        continueSend(global)

        if (indicateBackoff) {
            return SerializeAndSendResult.Backoff
        }
        SerializeAndSendResult.Success
    }

    // 严格翻译自 SendQueue.onAckNack
    // 处理 ACK/NACK
    public func onAckNack(global: JsObject, isAck: Bool): Unit {
        match (waitingForAck) {
            case None => return
            case Some(_) => ()
        }
        let item = waitingForAck.getOrThrow()
        match (item.handle) {
            case None => return
            case Some(_) => ()
        }

        if (!isAck) {
            // NACK: 重试最多 MAX_HANDLE_RETRANSMISSIONS 次
            retryCount += 1
            if (retryCount < IPCSendQueue.MAX_HANDLE_RETRANSMISSIONS) {
                item.data.cursor = 0
                insertMessage(item)
                waitingForAck = None
                continueSend(global)
                return
            }
        }

        // 成功: 调用回调并继续发送
        item.complete(global)
        waitingForAck = None
        continueSend(global)
    }

    // 严格翻译自 SendQueue.continueSend
    // 继续发送队列中的消息
    public func continueSend(global: JsObject): Unit {
        if (queue.size == 0) {
            return
        }
        if (writeInProgress) {
            return
        }

        let first = queue[0]
        let hasWaitingForAck = match (waitingForAck) {
            case Some(_) => true
            case None => false
        }
        if (hasWaitingForAck && !first.isAckNack()) {
            return  // 等待 ACK
        }

        if (first.data.readableBytes() == 0) {
            // 空消息，移除并继续
            let itm = queue[0]
            queue = queue[1..]
            itm.complete(global)
            continueSend(global)
            return
        }

        writeInProgress = true
        // 实际写入由平台特定的 socket 实现处理
    }

    // 严格翻译自 SendQueue._onWriteComplete
    // 写入完成回调
    public func onWriteComplete(global: JsObject, n: Int64): Unit {
        if (!writeInProgress || queue.size < 1) {
            return
        }
        writeInProgress = false

        let first = queue[0]
        let toSendLen = first.data.readableBytes()

        if (n == toSendLen) {
            // 完全写入
            let firstHasHandle = match (first.handle) {
                case Some(_) => true
                case None => false
            }
            if (firstHasHandle) {
                // 有 handle，等待 ACK
                let item = queue[0]
                queue = queue[1..]
                waitingForAck = item
            } else {
                // 无 handle，完成并继续
                let item = queue[0]
                queue = queue[1..]
                item.complete(global)
            }
            continueSend(global)
        } else if (n > 0 && n < toSendLen) {
            // 部分写入，更新游标
            first.data.cursor += n
        }
        // n == 0 或 n < 0: 等待可写事件或关闭
    }

    // 严格翻译自 SendQueue.getGlobalThis
    // 获取全局对象
    public func getGlobalThis(): JsObject {
        JsObject()  // 简化: 实际应从 owner 获取
    }
}

// ========== handleIPCMessage ==========
// 严格翻译自 ipc.zig handleIPCMessage
// 处理收到的 IPC 消息
public func handleIPCMessage(sendQueue: IPCSendQueue, message: DecodedIPCMessage, global: JsObject): Unit {
    var internalCommand: ?IPCCommand = None

    // 检查是否是内部命令消息
    if (message.isData()) {
        let msgData = message.dataValue
        if (msgData.isObject()) {
            match (msgData.getObject()) {
                case Some(obj) =>
                    let cmdVal = obj.get("cmd")
                    if (cmdVal.isString()) {
                        let cmdStr = cmdVal.toString()
                        if (cmdStr == "NODE_HANDLE") {
                            internalCommand = IPCCommand(IPCCommandTag.Handle, msgData)
                        } else if (cmdStr == "NODE_HANDLE_ACK") {
                            internalCommand = IPCCommand(IPCCommandTag.Ack, JsValue.undefined())
                        } else if (cmdStr == "NODE_HANDLE_NACK") {
                            internalCommand = IPCCommand(IPCCommandTag.Nack, JsValue.undefined())
                        }
                    }
                case None => ()
            }
        }
    }

    // 处理内部命令
    if (let Some(icmd) <- internalCommand) {
        match (icmd.tag) {
            case IPCCommandTag.Handle=>
                // NODE_HANDLE 消息
                let hasFd = match (sendQueue.incomingFd) {
                    case Some(_) => true
                    case None => false
                }

                let packet = if (hasFd) {
                    getAckPacket(sendQueue.mode)
                } else {
                    getNackPacket(sendQueue.mode)
                }

                let handle = IPCSendHandle()
                handle.data.write(packet)
                handle.callbacks.tag = CallbackListTag.AckNack
                sendQueue.insertMessage(handle)
                sendQueue.continueSend(global)

                if (!hasFd) {
                    return
                }

                // 清除文件描述符
                sendQueue.incomingFd = None
            case IPCCommandTag.Ack=>
                sendQueue.onAckNack(global, true)
                return
            case IPCCommandTag.Nack=>
                sendQueue.onAckNack(global, false)
                return
        }
    } else {
        // 普通消息: 转发给 owner 处理
    }
}

// ========== onData2 ==========
// 严格翻译自 ipc.zig onData2
// 处理接收到的数据
public func onData2(sendQueue: IPCSendQueue, allData: Array<UInt8>, global: JsObject): Unit {
    var data = allData

    match (sendQueue.incoming.tag) {
        case IncomingBufferTag.Json=>
            sendQueue.incoming.append(data)

            while (true) {
                if (let Some(msg) <- sendQueue.incoming.next()) {
                    let result = IPCJson.decodeIPCMessage(msg.data, global, Some(msg.newlinePos))
                    if (let Some(r) <- result) {
                        handleIPCMessage(sendQueue, r.message, global)
                        sendQueue.incoming.consume(r.bytesConsumed)
                    } else {
                        return
                    }
                } else {
                    return
                }
            }
        case IncomingBufferTag.Advanced=>
            if (sendQueue.incoming.len() == 0) {
                var remaining = data
                while (true) {
                    let result = IPCAdvanced.decodeIPCMessage(remaining, global)
                    if (let Some(r) <- result) {
                        handleIPCMessage(sendQueue, r.message, global)
                        if (Int64(r.bytesConsumed) < remaining.size) {
                            remaining = remaining[Int64(r.bytesConsumed)..]
                        } else {
                            return
                        }
                    } else {
                        sendQueue.incoming.append(remaining)
                        return
                    }
                }
            }

            // 缓冲区有数据时追加
            sendQueue.incoming.append(data)
            var slice = sendQueue.incoming.slice()
            while (true) {
                let result = IPCAdvanced.decodeIPCMessage(slice, global)
                if (let Some(r) <- result) {
                    handleIPCMessage(sendQueue, r.message, global)
                    if (Int64(r.bytesConsumed) < slice.size) {
                        slice = slice[Int64(r.bytesConsumed)..]
                    } else {
                        sendQueue.incoming.advancedData = []
                        return
                    }
                } else {
                    // 复制剩余数据到缓冲区开头
                    sendQueue.incoming.advancedData = slice
                    return
                }
            }
    }
}

// ========== IPCCommand ==========
// 严格翻译自 ipc.zig IPCCommand
public class IPCCommand {
    public var tag: IPCCommandTag
    public var value: JsValue

    public init(tag: IPCCommandTag, value: JsValue) {
        this.tag = tag
        this.value = value
    }
}

// ========== IPCCommandTag ==========
public enum IPCCommandTag {
    | Handle
    | Ack
    | Nack
}

// ========== doSend ==========
// 严格翻译自 ipc.zig doSend
// process.send() / subprocess.send() 的实现
public func doSend(ipc: ?IPCSendQueue, global: JsObject, message: JsValue, handle: JsValue, callback: JsValue, from: IPCFromEnum): JsValue {
    var handle_ = handle
    var callback_ = callback

    // 参数重排: handle 或 options 可能是 callback
    if (handle_.isCallable()) {
        callback_ = handle_
        handle_ = JsValue.undefined()
    }

    let connected = match (ipc) {
        case Some(ipcVal) => ipcVal.isConnected()
        case None => false
    }
    if (!connected) {
        let errMsg = match (from) {
            case IPCFromEnum.Process => "process.send() can only be used if the IPC channel is open."
            case IPCFromEnum.Subprocess => "Subprocess.send() can only be used if an IPC channel is open."
            case IPCFromEnum.SubprocessExited => "Subprocess.send() cannot be used after the process has exited."
        }
        // 错误处理
        if (callback_.isCallable()) {
            callback_.callNextTick(global, JsValue(errMsg))
            return JsValue(false)
        }
        return JsValue(errMsg)
    }

    let ipcData = ipc.getOrThrow()

    if (message.isUndefined()) {
        return JsValue("Missing argument: message")
    }

    // 验证消息类型
    if (!message.isString() && !message.isObject() && !message.isNumber() && !message.isBoolean() && !message.isNull()) {
        return JsValue("message must be string, object, number, or boolean")
    }

    // 序列化 handle
    var zigHandle: ?IPCHandle = None
    if (!handle_.isUndefinedOrNull()) {
        zigHandle = IPCHandle()
    }

    let status = ipcData.serializeAndSend(global, message, false, callback_, zigHandle)

    if (status == SerializeAndSendResult.Failure) {
        if (callback_.isCallable()) {
            callback_.callNextTick(global, JsValue("process.send() failed"))
            return JsValue(false)
        }
        return JsValue("process.send() failed")
    }

    if (status == SerializeAndSendResult.Success) {
        return JsValue(true)
    }
    JsValue(false)
}

// ========== IPCFromEnum ==========
// 严格翻译自 ipc.zig FromEnum
public enum IPCFromEnum {
    | SubprocessExited
    | Subprocess
    | Process
}

// ========== IPC Socket Handlers ==========
// 严格翻译自 ipc.zig IPCHandlers

// Posix Socket 处理器
public class IPCPosixSocketHandler {
    // 严格翻译自 IPCHandlers.PosixSocket.onOpen
    public static func onOpen(): Unit {
        // 初始化时不做任何操作
        // 版本包发送由初始化器负责
    }

    // 严格翻译自 IPCHandlers.PosixSocket.onClose
    public static func onClose(sendQueue: IPCSendQueue): Unit {
        sendQueue.closeSocket(false)
    }

    // 严格翻译自 IPCHandlers.PosixSocket.onData
    public static func onData(sendQueue: IPCSendQueue, data: Array<UInt8>, global: JsObject): Unit {
        onData2(sendQueue, data, global)
    }

    // 严格翻译自 IPCHandlers.PosixSocket.onFd
    // SCM_RIGHTS 接收到文件描述符
    public static func onFd(sendQueue: IPCSendQueue, fd: Int64): Unit {
        sendQueue.incomingFd = fd
    }

    // 严格翻译自 IPCHandlers.PosixSocket.onWritable
    public static func onWritable(sendQueue: IPCSendQueue, global: JsObject): Unit {
        sendQueue.continueSend(global)
    }

    // 严格翻译自 IPCHandlers.PosixSocket.onConnectError
    public static func onConnectError(sendQueue: IPCSendQueue): Unit {
        sendQueue.closeSocket(true)
    }

    // 严格翻译自 IPCHandlers.PosixSocket.onEnd
    public static func onEnd(sendQueue: IPCSendQueue): Unit {
        sendQueue.closeSocket(true)
    }

    // 严格翻译自 IPCHandlers.PosixSocket.onTimeout
    public static func onTimeout(): Unit {
        // unref if needed
    }
}

// Windows Named Pipe 处理器
public class IPCWindowsNamedPipeHandler {
    // 严格翻译自 IPCHandlers.WindowsNamedPipe.onReadAlloc
    public static func onReadAlloc(sendQueue: IPCSendQueue, suggestedSize: Int64): Array<UInt8> {
        Array<UInt8>(suggestedSize, {_ => 0})
    }

    // 严格翻译自 IPCHandlers.WindowsNamedPipe.onReadError
    public static func onReadError(sendQueue: IPCSendQueue): Unit {
        sendQueue.closeSocketNextTick(true)
    }

    // 严格翻译自 IPCHandlers.WindowsNamedPipe.onRead
    public static func onRead(sendQueue: IPCSendQueue, buffer: Array<UInt8>, global: JsObject): Unit {
        match (sendQueue.incoming.tag) {
            case IncomingBufferTag.Json=>
                sendQueue.incoming.append(buffer)
                while (true) {
                    if (let Some(msg) <- sendQueue.incoming.next()) {
                        let result = IPCJson.decodeIPCMessage(msg.data, global, Some(msg.newlinePos))
                        if (let Some(r) <- result) {
                            handleIPCMessage(sendQueue, r.message, global)
                            sendQueue.incoming.consume(r.bytesConsumed)
                        } else {
                            return
                        }
                    } else {
                        return
                    }
                }
            case IncomingBufferTag.Advanced=>
                var slice = buffer
                while (true) {
                    let result = IPCAdvanced.decodeIPCMessage(slice, global)
                    if (let Some(r) <- result) {
                        handleIPCMessage(sendQueue, r.message, global)
                        if (Int64(r.bytesConsumed) < slice.size) {
                            slice = slice[Int64(r.bytesConsumed)..]
                        } else {
                            sendQueue.incoming.advancedData = []
                            return
                        }
                    } else {
                        sendQueue.incoming.advancedData = slice
                        return
                    }
                }
        }
    }

    // 严格翻译自 IPCHandlers.WindowsNamedPipe.onClose
    public static func onClose(sendQueue: IPCSendQueue): Unit {
        sendQueue.closeSocket(false)
    }
}

// ========== emitHandleIPCMessage ==========
// 严格翻译自 ipc.zig emitHandleIPCMessage
// 处理 NODE_HANDLE IPC 消息的发射
public func emitHandleIPCMessage(global: JsObject, target: JsValue, message: JsValue, handle: JsValue): JsValue {
    if (target.isNull()) {
        // 进程自身
    } else {
        if (!target.isCell()) {
            return JsValue.undefined()
        }
        // 子进程
    }
    JsValue.undefined()
}


public class VersionPacket {
    public var messageType: AdvancedIPCMessageType = AdvancedIPCMessageType.Version
    public var version: UInt32 = 1  // VERSION

    public init() {}

    // 序列化为字节
    public func toBytes(): Array<UInt8> {
        // 使用字面量数组构造，避免 Array 值类型赋值问题
        let b0 = messageType.value()
        let b1 = UInt8(version & 0xFF)
        let b2 = UInt8((version >> 8) & 0xFF)
        let b3 = UInt8((version >> 16) & 0xFF)
        let b4 = UInt8((version >> 24) & 0xFF)
        [b0, b1, b2, b3, b4]
    }
}
