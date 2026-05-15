// 严格翻译自: src/runtime/api/bun/h2_frame_parser.zig
package bao_runtime

import bao_jsc.*
import bao_core.*
import bao_sys.*

// ============================================================================
// h2_frame_parser - HTTP/2 帧解析器
// 对应 Bun: src/runtime/api/bun/h2_frame_parser.zig
// ============================================================================

/// HTTP/2 帧解析器常量和类型
public class H2FrameParser {

    // ========================================================================
    // 常量
    // ========================================================================

    public static let MAX_PAYLOAD_SIZE_WITHOUT_FRAME: Int = 16384 - FrameHeader.byteSize - 1
    public static let MAX_WINDOW_SIZE: Int = Int32.maxValue
    public static let MAX_HEADER_TABLE_SIZE: UInt32 = UInt32.maxValue
    public static let MAX_STREAM_ID: Int = Int32.maxValue
    public static let MAX_FRAME_SIZE: UInt32 = UInt32.maxValue & 0x00FFFFFF
    public static let DEFAULT_WINDOW_SIZE: Int = UInt16.maxValue
    public static let MAX_WINDOW_SIZE_F64: Float64 = Float64(MAX_WINDOW_SIZE)
    public static let MAX_HEADER_TABLE_SIZE_F64: Float64 = Float64(MAX_HEADER_TABLE_SIZE)
    public static let MAX_FRAME_SIZE_F64: Float64 = Float64(MAX_FRAME_SIZE)
    public static let HPACK_ENTRY_OVERHEAD: Int = 32
    public static let MAX_CUSTOM_SETTINGS: Int = 10
    public static let MAX_CUSTOM_SETTING_ID: Float64 = 0xFFFF

    // ========================================================================
    // 枚举
    // ========================================================================

    /// 填充策略
    public enum PaddingStrategy {
        case none
        case aligned
        case max
    }

    /// 帧类型
    public enum FrameType: UInt8 {
        case data = 0x00
        case headers = 0x01
        case priority = 0x02
        case rstStream = 0x03
        case settings = 0x04
        case pushPromise = 0x05
        case ping = 0x06
        case goaway = 0x07
        case windowUpdate = 0x08
        case continuation = 0x09
        case altsvc = 0x0A
        case origin = 0x0C
    }

    /// Ping 帧标志
    public enum PingFrameFlags: UInt8 {
        case ack = 0x1
    }

    /// Data 帧标志
    public enum DataFrameFlags: UInt8 {
        case endStream = 0x1
        case padded = 0x8
    }

    /// Headers 帧标志
    public enum HeadersFrameFlags: UInt8 {
        case endStream = 0x1
        case endHeaders = 0x4
        case padded = 0x8
        case priority = 0x20
    }

    /// Settings 帧标志
    public enum SettingsFlags: UInt8 {
        case ack = 0x1
    }

    /// 错误码
    public enum ErrorCode: UInt32 {
        case noError = 0x0
        case protocolError = 0x1
        case internalError = 0x2
        case flowControlError = 0x3
        case settingsTimeout = 0x4
        case streamClosed = 0x5
        case frameSizeError = 0x6
        case refusedStream = 0x7
        case cancel = 0x8
        case compressionError = 0x9
        case connectError = 0xa
        case enhanceYourCalm = 0xb
        case inadequateSecurity = 0xc
        case http11Required = 0xd
        case maxPendingSettingsAck = 0xe
    }

    /// 设置类型
    public enum SettingsType: UInt16 {
        case headerTableSize = 0x1
        case enablePush = 0x2
        case maxConcurrentStreams = 0x3
        case initialWindowSize = 0x4
        case maxFrameSize = 0x5
        case maxHeaderListSize = 0x6
    }

    // ========================================================================
    // JS 桥接
    // ========================================================================

    /// 获取 HTTP/2 通用字符串
    public static func getHTTP2CommonString(globalObject: JsGlobalObject, hpackIndex: UInt32): ?JsValue {
        if (hpackIndex == 255) { return none }
        let value = JSC__JSGlobalObject__getHTTP2CommonString(globalObject, hpackIndex)
        if (value.isEmptyOrUndefinedOrNull()) { return none }
        return value
    }

    @Extern
    public static func JSC__JSGlobalObject__getHTTP2CommonString(globalObject: JsGlobalObject, hpackIndex: UInt32): JsValue
}

/// BunSocket 联合类型
public enum BunSocket {
    case none
    case tls(TLSSocket)
    case tlsWriteonly(TLSSocket)
    case tcp(TCPSocket)
    case tcpWriteonly(TCPSocket)
}
