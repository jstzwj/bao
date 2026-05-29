// 严格翻译自: src/runtime/api/bun/h2_frame_parser.rs
// TODO: 恢复完整 HTTP/2 帧解析、设置校验和 socket 集成。
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}

public enum BinaryType { | Buffer | ArrayBuffer | Uint8Array }
public enum IpcMode { | IpcNone | Basic | Full }

public class TLSSocket { public init() {} }
public class TCPSocket { public init() {} }

public enum PaddingStrategy { | PaddingNone | Aligned | Max }
public enum FrameType { | data | headers | settings | unknown }
public enum PingFrameFlags { | ack }
public enum DataFrameFlags { | endStream | padded }
public enum HeadersFrameFlags { | endStream | endHeaders | padded | priority }
public enum SettingsFlags { | ack }

public class ErrorCode {
    public var value: UInt32

    public init() {
        value = 0
    }

    public init(value: UInt32) {
        this.value = value
    }

    public static let NO_ERROR = ErrorCode(0)
    public static let PROTOCOL_ERROR = ErrorCode(1)
    public static let INTERNAL_ERROR = ErrorCode(2)
    public static let FLOW_CONTROL_ERROR = ErrorCode(3)
    public static let SETTINGS_TIMEOUT = ErrorCode(4)
    public static let STREAM_CLOSED = ErrorCode(5)
    public static let FRAME_SIZE_ERROR = ErrorCode(6)
    public static let REFUSED_STREAM = ErrorCode(7)
    public static let CANCEL = ErrorCode(8)
    public static let COMPRESSION_ERROR = ErrorCode(9)
    public static let CONNECT_ERROR = ErrorCode(10)
    public static let ENHANCE_YOUR_CALM = ErrorCode(11)
    public static let INADEQUATE_SECURITY = ErrorCode(12)
    public static let HTTP_1_1_REQUIRED = ErrorCode(13)
    public static let MAX_PENDING_SETTINGS_ACK = ErrorCode(14)

    public func equals(other!: ErrorCode): Bool {
        return value == other.value
    }
}

public class SettingsType {
    public var value: UInt16

    public init() {
        value = 0
    }

    public init(value: UInt16) {
        this.value = value
    }
}

public class UInt31WithReserved {
    public var value: UInt32 = 0
    public init() {}
}

public class StreamPriority {
    public init() {}
}

public class FrameHeader {
    public var size: UInt32 = 0
    public var streamId: UInt32 = 0
    public init() {}
}

public class SettingsPayloadUnit {
    public static let BYTE_SIZE: Int64 = 6
    public var type_: UInt16 = 0
    public var value: UInt32 = 0
    public init() {}
}

public class FullSettingsPayload {
    public static let BYTE_SIZE: Int64 = 42
    public var headerTableSize: UInt32 = 4096
    public var enablePush: UInt32 = 1
    public var maxConcurrentStreams: UInt32 = 0
    public var initialWindowSize: UInt32 = 65535
    public var maxFrameSize: UInt32 = 16384
    public var maxHeaderListSize: UInt32 = 0
    public var enableConnectProtocol: UInt32 = 0

    public init() {}

    public func updateWith(option!: SettingsPayloadUnit): Unit {}
    public func toJs(globalThis!: JsGlobalObject): JsValue {
        return JsValue.jsUndefined()
    }
}

public enum BunSocket { | BunSocketNone }
public enum FlushState { | FlushNone }
public enum StreamState { | idle | open | closed }

public class PendingFrame { public init() {} }
public class PendingQueue {
    public init() {}
    public func deinit(): Unit {}
}

public class Stream {
    public var id: UInt32 = 0
    public var rstCode: UInt32 = 0
    public init() {}
}

public class Handlers {
    public init() {}
    public init(globalObject: JsGlobalObject) {}
}

public class H2FrameParser {
    public var localSettings: FullSettingsPayload = FullSettingsPayload()
    public var remoteSettings: ?FullSettingsPayload = None

    public init() {}
    public init(globalObject: JsGlobalObject) {}

    public func finalize(): Unit {}
    public func sendSettingsAck(): Unit {}
    public func sendGoAway(lastStreamId!: UInt32, code!: ErrorCode, data!: Array<UInt8>, streamId!: UInt32, close!: Bool): Unit {}
    public func sendPrefaceAndSettings(): Unit {}
    public func setSettings(settings!: FullSettingsPayload): Bool { return true }
    public func endStream(stream_!: Stream, rstCode!: ErrorCode): Unit {}

    public static func toValidHeaderName(name!: Array<UInt8>): ?Array<UInt8> {
        return Some(name)
    }
}

public func JSC__JSGlobalObject__getHTTP2CommonString(jsGlobalObject!: JsGlobalObject, hpackIndex!: UInt32): JsValue {
    return JsValue.jsUndefined()
}

public func Bun__wrapAbortError(jsGlobalObject!: JsGlobalObject, cause!: JsValue): JsValue {
    return JsValue.jsUndefined()
}

public func getHTTP2CommonString(jsGlobalObject!: JsGlobalObject, hpackIndex!: UInt32): ?JsValue {
    return None
}

public func jsGetUnpackedSettings(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    return FullSettingsPayload().toJs(globalThis: jsGlobalObject)
}

public func jsAssertSettings(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    return JsValue.jsUndefined()
}

public func jsGetPackedSettings(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    return JsValue.jsUndefined()
}
