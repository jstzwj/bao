// 严格翻译自: src/jsc/ipc.zig + host_fn.zig + FFI.zig + javascript_core_c_api.zig
// JavaScriptCore IPC 通信、宿主函数和 FFI 绑定

package bao_jsc

// ========== IPC 消息类型 ==========
// 严格翻译自 ipc.zig
public enum IPCMessageType {
    | Version(0)
    | Data(1)
    | Internal(2)
    | Buffer(3)
    | Close(4)
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
        data = Array<UInt8>(capacity, item: 0)
    }

    // 写入数据
    public func write(bytes: Array<UInt8>) {
        for (b in bytes) {
            data.append(b)
        }
        writePos += Int64(bytes.size)
    }

    // 读取数据
    public func read(count: Int64) -> Array<UInt8> {
        var result = Array<UInt8>()
        let end = readPos + count
        while (readPos < end && readPos < Int64(data.size)) {
            result.append(data[Int64(readPos)])
            readPos++
        }
        result
    }

    // 可读字节数
    public func readableBytes() -> Int64 {
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
        messages.append(message)
    }

    public func dequeue() -> ?IPCEncodedMessage {
        if (messages.size == 0) { return None }
        let msg = messages[0]
        messages = messages.slice(1)
        Some(msg)
    }

    public func drain() -> Array<IPCEncodedMessage> {
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
    public func call(global: JsObject, callFrame: CallFrame) -> JsValue {
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
    | Void
    | Int8
    | Int16
    | Int32
    | Int64
    | UInt8
    | UInt16
    | UInt32
    | UInt64
    | Float32
    | Float64
    | Pointer
    | Bool
    | SizeT

    // 获取大小
    public func size() -> Int64 {
        match (this) {
            case Void => 0
            case Int8 | UInt8 | Bool => 1
            case Int16 | UInt16 => 2
            case Int32 | UInt32 | Float32 => 4
            case Int64 | UInt64 | Float64 | Pointer | SizeT => 8
        }
    }

    // 是否为整数类型
    public func isInteger() -> Bool {
        match (this) {
            case Int8 | Int16 | Int32 | Int64 | UInt8 | UInt16 | UInt32 | UInt64 | Bool | SizeT => true
            case _ => false
        }
    }

    // 是否为浮点类型
    public func isFloat() -> Bool {
        this == Float32 || this == Float64
    }
}

// FFI 函数描述
public class FFIFunction {
    public var name: String = ""
    public var library: String = ""
    public var returnType: FFIValueType = FFIValueType.Void
    public var paramTypes: Array<FFIValueType> = []
    public var convention: FFICallingConvention = FFICallingConvention.C

    public init() {}

    // 获取参数总大小
    public func paramsSize() -> Int64 {
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
    public var type: FFIValueType = FFIValueType.Void
    public var intValue: Int64 = 0
    public var floatValue: Float64 = 0.0
    public var ptrValue: CPointer<UInt8> = CPointer<UInt8>()

    public init() {}

    public init(v: Int64) {
        this.type = FFIValueType.Int64
        this.intValue = v
    }

    public init(v: Float64) {
        this.type = FFIValueType.Float64
        this.floatValue = v
    }

    public init(v: Bool) {
        this.type = FFIValueType.Bool
        this.intValue = if (v) { 1 } else { 0 }
    }

    // 从 JsValue 转换
    public static func fromJS(value: JsValue) -> FFIValue {
        if (value.isNumber()) {
            return FFIValue(value.toNumber())
        }
        if (value.isBoolean()) {
            return FFIValue(value.toBoolean())
        }
        FFIValue()
    }

    // 转为 JsValue
    public func toJS() -> JsValue {
        match (type) {
            case Bool => JsValue(b: intValue != 0)
            case Int8 | Int16 | Int32 | Int64 => JsValue(n: intValue)
            case UInt8 | UInt16 | UInt32 | UInt64 | SizeT => JsValue(n: intValue)
            case Float32 | Float64 => JsValue(n: floatValue)
            case Pointer => JsValue(n: intValue)
            case Void => JsValue.undefined()
        }
    }
}

// ========== C API 辅助 ==========
// 严格翻译自 javascript_core_c_api.zig

// JSValue 来源标记
public enum JSValueTag {
    | Boolean(0)
    | Null(1)
    | Undefined(2)
    | Number(3)
    | String(4)
    | Object(5)
    | Symbol(6)
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
