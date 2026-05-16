// H2 - HTTP/2 线格式类型 (RFC 7540 / 9113)
// 严格翻译自: src/http_types/h2.rs
//   纯数据层模块 — 无 JSC/Socket/IO 依赖。
//   由 bao_http (fetch HTTP/2 客户端) 和 bao_runtime (node:http2 绑定) 共享。
package bao_http_types

import bao_core.*

// ============================================================================
// 连接/大小常量
// 严格翻译自: h2.rs - connection/sizing constants
//   pub const CLIENT_PREFACE: &[u8] = b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n";
//   pub const MAX_WINDOW_SIZE: u32 = i32::MAX as u32;
//   ...
// ============================================================================

/// HTTP/2 客户端连接前缀 (RFC 7540 §3.5)
public let CLIENT_PREFACE: Array<UInt8> = [
    80 /*'P'*/, 82 /*'R'*/, 73 /*'I'*/, 32 /*' '*/,
    42 /*'*'*/, 32 /*' '*/, 72 /*'H'*/, 84 /*'T'*/,
    84 /*'T'*/, 80 /*'P'*/, 47 /*'/'*/, 50 /*'2'*/,
    46 /*'.'*/, 48 /*'0'*/, 13 /*'\r'*/, 10 /*'\n'*/,
    13 /*'\r'*/, 10 /*'\n'*/, 83 /*'S'*/, 77 /*'M'*/,
    13 /*'\r'*/, 10 /*'\n'*/, 13 /*'\r'*/, 10 /*'\n'*/
]

/// 最大流控窗口大小 (2^31 - 1)
public const MAX_WINDOW_SIZE: UInt32 = 0x7FFFFFFF
/// 最大 HPACK 头表大小
public const MAX_HEADER_TABLE_SIZE: UInt32 = 0xFFFFFFFF
/// 最大流 ID
public const MAX_STREAM_ID: UInt32 = 0x7FFFFFFF
/// 最大帧大小 (2^24 - 1)
public const MAX_FRAME_SIZE: UInt32 = 0x00FFFFFF
/// 默认流控窗口大小 (2^16 - 1)
public const DEFAULT_WINDOW_SIZE: UInt32 = 0xFFFF
/// 默认最大帧大小 (2^14)
public const DEFAULT_MAX_FRAME_SIZE: UInt32 = 16384

// ============================================================================
// FrameType - 帧类型
// 严格翻译自: h2.rs - FrameType
//   #[repr(u8)]
//   pub enum FrameType { HTTP_FRAME_DATA = 0x00, ... }
// ============================================================================

/// HTTP/2 帧类型 - 对应 Bun FrameType
public enum FrameType {
    | Data             // 0x00 - DATA 帧
    | Headers          // 0x01 - HEADERS 帧
    | Priority         // 0x02 - PRIORITY 帧
    | RstStream        // 0x03 - RST_STREAM 帧
    | Settings         // 0x04 - SETTINGS 帧
    | PushPromise      // 0x05 - PUSH_PROMISE 帧
    | Ping             // 0x06 - PING 帧
    | Goaway           // 0x07 - GOAWAY 帧
    | WindowUpdate     // 0x08 - WINDOW_UPDATE 帧
    | Continuation     // 0x09 - CONTINUATION 帧
    | Altsvc           // 0x0A - ALTSVC 帧 (RFC 7838)
    | Origin           // 0x0C - ORIGIN 帧 (RFC 8336)
    | Unknown          // 未知帧类型

    /// 从原始字节值构造帧类型
    public static func fromRaw(value: UInt8): FrameType {
        match (value) {
            case 0x00 => FrameType.Data
            case 0x01 => FrameType.Headers
            case 0x02 => FrameType.Priority
            case 0x03 => FrameType.RstStream
            case 0x04 => FrameType.Settings
            case 0x05 => FrameType.PushPromise
            case 0x06 => FrameType.Ping
            case 0x07 => FrameType.Goaway
            case 0x08 => FrameType.WindowUpdate
            case 0x09 => FrameType.Continuation
            case 0x0A => FrameType.Altsvc
            case 0x0C => FrameType.Origin
            case _ => FrameType.Unknown
        }
    }

    /// 转换为原始字节值
    public func toRaw(): UInt8 {
        match (this) {
            case Data => 0x00
            case Headers => 0x01
            case Priority => 0x02
            case RstStream => 0x03
            case Settings => 0x04
            case PushPromise => 0x05
            case Ping => 0x06
            case Goaway => 0x07
            case WindowUpdate => 0x08
            case Continuation => 0x09
            case Altsvc => 0x0A
            case Origin => 0x0C
            case Unknown => 0xFF
        }
    }
}

// ============================================================================
// PingFrameFlags - PING 帧标志
// 严格翻译自: h2.rs - PingFrameFlags
//   pub enum PingFrameFlags { ACK = 0x1 }
// ============================================================================

/// PING 帧标志 - 对应 Bun PingFrameFlags
public enum PingFrameFlags {
    | Ack    // 0x1 - 确认响应

    public func toRaw(): UInt8 {
        match (this) {
            case Ack => 0x01
        }
    }
}

// ============================================================================
// DataFrameFlags - DATA 帧标志
// 严格翻译自: h2.rs - DataFrameFlags
//   pub enum DataFrameFlags { END_STREAM = 0x1, PADDED = 0x8 }
// ============================================================================

/// DATA 帧标志 - 对应 Bun DataFrameFlags
public enum DataFrameFlags {
    | EndStream   // 0x1 - 流结束
    | Padded      // 0x8 - 填充

    public func toRaw(): UInt8 {
        match (this) {
            case EndStream => 0x01
            case Padded => 0x08
        }
    }
}

// ============================================================================
// HeadersFrameFlags - HEADERS 帧标志
// 严格翻译自: h2.rs - HeadersFrameFlags
//   pub enum HeadersFrameFlags {
//       END_STREAM = 0x1, END_HEADERS = 0x4, PADDED = 0x8, PRIORITY = 0x20,
//   }
// ============================================================================

/// HEADERS 帧标志 - 对应 Bun HeadersFrameFlags
public enum HeadersFrameFlags {
    | EndStream    // 0x1 - 流结束
    | EndHeaders   // 0x4 - 头部结束
    | Padded       // 0x8 - 填充
    | Priority     // 0x20 - 优先级

    public func toRaw(): UInt8 {
        match (this) {
            case EndStream => 0x01
            case EndHeaders => 0x04
            case Padded => 0x08
            case Priority => 0x20
        }
    }
}

// ============================================================================
// SettingsFlags - SETTINGS 帧标志
// 严格翻译自: h2.rs - SettingsFlags
//   pub enum SettingsFlags { ACK = 0x1 }
// ============================================================================

/// SETTINGS 帧标志 - 对应 Bun SettingsFlags
public enum SettingsFlags {
    | Ack    // 0x1 - 确认

    public func toRaw(): UInt8 {
        match (this) {
            case Ack => 0x01
        }
    }
}

// ============================================================================
// ErrorCode - HTTP/2 错误码
// 严格翻译自: h2.rs - ErrorCode
//   pub struct ErrorCode(pub u32);
//   impl ErrorCode { pub const NO_ERROR: Self = Self(0x0); ... }
// ============================================================================

/// HTTP/2 错误码 (RFC 7540 §7) - 对应 Bun ErrorCode
public class ErrorCode {
    public var value: UInt32

    public init(value: UInt32) {
        this.value = value
    }

    /// 无错误
    public static let NO_ERROR: ErrorCode = ErrorCode(0x0)
    /// 协议错误
    public static let PROTOCOL_ERROR: ErrorCode = ErrorCode(0x1)
    /// 内部错误
    public static let INTERNAL_ERROR: ErrorCode = ErrorCode(0x2)
    /// 流控错误
    public static let FLOW_CONTROL_ERROR: ErrorCode = ErrorCode(0x3)
    /// 设置超时
    public static let SETTINGS_TIMEOUT: ErrorCode = ErrorCode(0x4)
    /// 流已关闭
    public static let STREAM_CLOSED: ErrorCode = ErrorCode(0x5)
    /// 帧大小错误
    public static let FRAME_SIZE_ERROR: ErrorCode = ErrorCode(0x6)
    /// 拒绝流
    public static let REFUSED_STREAM: ErrorCode = ErrorCode(0x7)
    /// 取消
    public static let CANCEL: ErrorCode = ErrorCode(0x8)
    /// 压缩错误
    public static let COMPRESSION_ERROR: ErrorCode = ErrorCode(0x9)
    /// 连接错误
    public static let CONNECT_ERROR: ErrorCode = ErrorCode(0xA)
    /// 增强平静度
    public static let ENHANCE_YOUR_CALM: ErrorCode = ErrorCode(0xB)
    /// 安全不足
    public static let INADEQUATE_SECURITY: ErrorCode = ErrorCode(0xC)
    /// 需要 HTTP/1.1
    public static let HTTP_1_1_REQUIRED: ErrorCode = ErrorCode(0xD)
    /// 最大待处理设置确认
    public static let MAX_PENDING_SETTINGS_ACK: ErrorCode = ErrorCode(0xE)
}

// ============================================================================
// SettingsType - HTTP/2 设置参数类型
// 严格翻译自: h2.rs - SettingsType
//   pub struct SettingsType(pub u16);
//   impl SettingsType { pub const SETTINGS_HEADER_TABLE_SIZE: Self = Self(0x1); ... }
// ============================================================================

/// HTTP/2 设置参数类型 (RFC 7540 §6.5.2) - 对应 Bun SettingsType
public class SettingsType {
    public var value: UInt16

    public init(value: UInt16) {
        this.value = value
    }

    /// 头部表大小
    public static let HEADER_TABLE_SIZE: SettingsType = SettingsType(0x1)
    /// 启用推送
    public static let ENABLE_PUSH: SettingsType = SettingsType(0x2)
    /// 最大并发流数
    public static let MAX_CONCURRENT_STREAMS: SettingsType = SettingsType(0x3)
    /// 初始窗口大小
    public static let INITIAL_WINDOW_SIZE: SettingsType = SettingsType(0x4)
    /// 最大帧大小
    public static let MAX_FRAME_SIZE: SettingsType = SettingsType(0x5)
    /// 最大头部列表大小
    public static let MAX_HEADER_LIST_SIZE: SettingsType = SettingsType(0x6)
    /// 启用连接协议 (非标准扩展)
    public static let ENABLE_CONNECT_PROTOCOL: SettingsType = SettingsType(0x8)
    /// 禁用 RFC 7540 优先级 (非标准扩展)
    public static let NO_RFC7540_PRIORITIES: SettingsType = SettingsType(0x9)
}

// ============================================================================
// UInt31WithReserved - 31位无符号整数 + 保留位
// 严格翻译自: h2.rs - UInt31WithReserved
//   pub struct UInt31WithReserved(u32);
//   RFC 7540: reserved 位在最高位, uint31 在低 31 位
// ============================================================================

/// 31位无符号整数 + 保留位 - 对应 Bun UInt31WithReserved
/// RFC 7540 合规布局: (reserved << 31) | uint31
public class UInt31WithReserved {
    private var raw: UInt32

    public init() {
        raw = 0
    }

    public init(raw: UInt32) {
        this.raw = raw
    }

    public init(value: UInt32, reserved: Bool) {
        raw = (value & 0x7FFFFFFF) | if (reserved) { 0x80000000 } else { 0 }
    }

    /// 获取保留位
    public func reserved(): Bool {
        (raw & 0x80000000) != 0
    }

    /// 获取 31 位值
    public func uint31(): UInt32 {
        raw & 0x7FFFFFFF
    }

    /// 转换为完整 UInt32
    public func toUInt32(): UInt32 {
        raw
    }

    /// 从大端字节数组解码
    public static func fromBytes(src: Array<UInt8>): UInt31WithReserved {
        let val = (UInt32(src[0]) << 24) |
                  (UInt32(src[1]) << 16) |
                  (UInt32(src[2]) << 8) |
                  UInt32(src[3])
        return UInt31WithReserved(val)
    }

    /// 编码为大端字节数组
    public func encodeInto(dst: Array<UInt8>): Unit {
        dst[0] = UInt8((raw >> 24) & 0xFF)
        dst[1] = UInt8((raw >> 16) & 0xFF)
        dst[2] = UInt8((raw >> 8) & 0xFF)
        dst[3] = UInt8(raw & 0xFF)
    }
}

// ============================================================================
// StreamPriority - 流优先级 (5字节打包结构)
// 严格翻译自: h2.rs - StreamPriority
//   pub struct StreamPriority {
//       pub stream_identifier: u32,
//       pub weight: u8,
//   };
// ============================================================================

/// 流优先级 (RFC 7540 §6.3) - 对应 Bun StreamPriority
public class StreamPriority {
    /// 流标识符
    public var streamIdentifier: UInt32
    /// 权重 (1-256)
    public var weight: UInt8

    public init() {
        streamIdentifier = 0
        weight = 0
    }

    public init(streamIdentifier: UInt32, weight: UInt8) {
        this.streamIdentifier = streamIdentifier
        this.weight = weight
    }

    /// 字节大小
    public static let BYTE_SIZE: Int64 = 5

    /// 从原始字节数组解码 (大端)
    public static func fromBytes(src: Array<UInt8>): StreamPriority {
        let sp = StreamPriority()
        sp.streamIdentifier = (UInt32(src[0]) << 24) |
                              (UInt32(src[1]) << 16) |
                              (UInt32(src[2]) << 8) |
                              UInt32(src[3])
        sp.weight = src[4]
        return sp
    }

    /// 编码为大端字节数组
    public func encodeInto(dst: Array<UInt8>): Unit {
        dst[0] = UInt8((streamIdentifier >> 24) & 0xFF)
        dst[1] = UInt8((streamIdentifier >> 16) & 0xFF)
        dst[2] = UInt8((streamIdentifier >> 8) & 0xFF)
        dst[3] = UInt8(streamIdentifier & 0xFF)
        dst[4] = weight
    }
}

// ============================================================================
// FrameHeader - HTTP/2 帧头 (9字节)
// 严格翻译自: h2.rs - FrameHeader
//   pub struct FrameHeader {
//       pub length: u32,      // u24 on wire
//       pub type_: u8,
//       pub flags: u8,
//       pub stream_identifier: u32,
//   };
// ============================================================================

/// HTTP/2 帧头 (RFC 7540 §4.1) - 对应 Bun FrameHeader
/// 线上格式: 3字节长度 + 1字节类型 + 1字节标志 + 4字节流ID = 9字节
public class FrameHeader {
    /// 帧载荷长度 (u24 on wire, 最大 16MB)
    public var length: UInt32
    /// 帧类型
    public var typeValue: UInt8
    /// 帧标志
    public var flags: UInt8
    /// 流标识符
    public var streamIdentifier: UInt32

    public init() {
        length = 0
        typeValue = 0x04  // SETTINGS
        flags = 0
        streamIdentifier = 0
    }

    public init(length: UInt32, typeValue: UInt8, flags: UInt8, streamIdentifier: UInt32) {
        this.length = length
        this.typeValue = typeValue
        this.flags = flags
        this.streamIdentifier = streamIdentifier
    }

    /// 帧头字节大小
    public static let BYTE_SIZE: Int64 = 9

    /// 获取帧类型枚举
    public func frameType(): FrameType {
        FrameType.fromRaw(typeValue)
    }

    /// 从 9 字节大端帧头解码
    public static func decode(raw: Array<UInt8>): FrameHeader {
        FrameHeader((UInt32(raw[0]) << 16) | (UInt32(raw[1]) << 8) | UInt32(raw[2]), raw[3], raw[4], (UInt32(raw[5]) << 24) | (UInt32(raw[6]) << 16) | (UInt32(raw[7]) << 8) | UInt32(raw[8]))
    }

    /// 编码为 9 字节大端帧头
    public func encodeInto(dst: Array<UInt8>): Unit {
        dst[0] = UInt8((length >> 16) & 0xFF)
        dst[1] = UInt8((length >> 8) & 0xFF)
        dst[2] = UInt8(length & 0xFF)
        dst[3] = typeValue
        dst[4] = flags
        dst[5] = UInt8((streamIdentifier >> 24) & 0xFF)
        dst[6] = UInt8((streamIdentifier >> 16) & 0xFF)
        dst[7] = UInt8((streamIdentifier >> 8) & 0xFF)
        dst[8] = UInt8(streamIdentifier & 0xFF)
    }
}

// ============================================================================
// SettingsPayloadUnit - 设置参数单元 (6字节)
// 严格翻译自: h2.rs - SettingsPayloadUnit
//   pub struct SettingsPayloadUnit {
//       pub type_: u16,
//       pub value: u32,
//   };
// ============================================================================

/// 设置参数单元 (RFC 7540 §6.5.1) - 对应 Bun SettingsPayloadUnit
/// 线上格式: 2字节类型 + 4字节值 = 6字节
public class SettingsPayloadUnit {
    /// 设置参数类型
    public var typeValue: UInt16
    /// 设置参数值
    public var value: UInt32

    public init() {
        typeValue = 0
        value = 0
    }

    public init(typeValue: UInt16, value: UInt32) {
        this.typeValue = typeValue
        this.value = value
    }

    /// 字节大小
    public static let BYTE_SIZE: Int64 = 6

    /// 从大端字节流解码
    public static func fromBytes(src: Array<UInt8>, offset: Int64): SettingsPayloadUnit {
        let spu = SettingsPayloadUnit()
        spu.typeValue = (UInt16(src[offset]) << 8) | UInt16(src[offset + 1])
        spu.value = (UInt32(src[offset + 2]) << 24) |
                    (UInt32(src[offset + 3]) << 16) |
                    (UInt32(src[offset + 4]) << 8) |
                    UInt32(src[offset + 5])
        return spu
    }

    /// 编码设置参数为大端字节
    public static func encode(dst: Array<UInt8>, setting: SettingsType, value: UInt32): Unit {
        dst[0] = UInt8((setting.value >> 8) & 0xFF)
        dst[1] = UInt8(setting.value & 0xFF)
        dst[2] = UInt8((value >> 24) & 0xFF)
        dst[3] = UInt8((value >> 16) & 0xFF)
        dst[4] = UInt8((value >> 8) & 0xFF)
        dst[5] = UInt8(value & 0xFF)
    }
}

// ============================================================================
// FullSettingsPayload - 完整 SETTINGS 帧载荷 (42字节 = 7 × 6)
// 严格翻译自: h2.rs - FullSettingsPayload
//   pub struct FullSettingsPayload { ... } // 7 个 (u16 type + u32 value) = 42 bytes
// ============================================================================

/// 完整 SETTINGS 帧载荷 (RFC 7540 §6.5) - 对应 Bun FullSettingsPayload
/// 7 个设置参数: (2字节ID + 4字节值) × 7 = 42字节
public class FullSettingsPayload {
    /// HPACK 头部表大小 (默认 4096)
    public var headerTableSize: UInt32
    /// 是否启用服务器推送 (默认 1)
    public var enablePush: UInt32
    /// 最大并发流数 (默认 UInt32.MAX)
    public var maxConcurrentStreams: UInt32
    /// 初始窗口大小 (默认 65535)
    public var initialWindowSize: UInt32
    /// 最大帧大小 (默认 16384)
    public var maxFrameSize: UInt32
    /// 最大头部列表大小 (默认 65535)
    public var maxHeaderListSize: UInt32
    /// 启用连接协议 (默认 0)
    public var enableConnectProtocol: UInt32

    public init() {
        headerTableSize = 4096
        enablePush = 1
        maxConcurrentStreams = 0xFFFFFFFF  // UInt32.MAX
        initialWindowSize = 65535
        maxFrameSize = 16384
        maxHeaderListSize = 65535
        enableConnectProtocol = 0
    }

    /// 字节大小
    public static let BYTE_SIZE: Int64 = 42

    /// 使用单个设置参数更新
    public func updateWith(option: SettingsPayloadUnit): Unit {
        let t = option.typeValue
        if (t == SettingsType.HEADER_TABLE_SIZE.value) {
            headerTableSize = option.value
        } else if (t == SettingsType.ENABLE_PUSH.value) {
            enablePush = option.value
        } else if (t == SettingsType.MAX_CONCURRENT_STREAMS.value) {
            maxConcurrentStreams = option.value
        } else if (t == SettingsType.INITIAL_WINDOW_SIZE.value) {
            initialWindowSize = option.value
        } else if (t == SettingsType.MAX_FRAME_SIZE.value) {
            maxFrameSize = option.value
        } else if (t == SettingsType.MAX_HEADER_LIST_SIZE.value) {
            maxHeaderListSize = option.value
        } else if (t == SettingsType.ENABLE_CONNECT_PROTOCOL.value) {
            enableConnectProtocol = option.value
        }
    }

    /// 编码为大端字节流
    public func encodeInto(dst: Array<UInt8>): Unit {
        var offset: Int64 = 0
        encodeSetting(dst, offset, SettingsType.HEADER_TABLE_SIZE, headerTableSize)
        offset += 6
        encodeSetting(dst, offset, SettingsType.ENABLE_PUSH, enablePush)
        offset += 6
        encodeSetting(dst, offset, SettingsType.MAX_CONCURRENT_STREAMS, maxConcurrentStreams)
        offset += 6
        encodeSetting(dst, offset, SettingsType.INITIAL_WINDOW_SIZE, initialWindowSize)
        offset += 6
        encodeSetting(dst, offset, SettingsType.MAX_FRAME_SIZE, maxFrameSize)
        offset += 6
        encodeSetting(dst, offset, SettingsType.MAX_HEADER_LIST_SIZE, maxHeaderListSize)
        offset += 6
        encodeSetting(dst, offset, SettingsType.ENABLE_CONNECT_PROTOCOL, enableConnectProtocol)
    }

    private static func encodeSetting(dst: Array<UInt8>, offset: Int64,
                                       setting: SettingsType, value: UInt32): Unit {
        dst[offset] = UInt8((setting.value >> 8) & 0xFF)
        dst[offset + 1] = UInt8(setting.value & 0xFF)
        dst[offset + 2] = UInt8((value >> 24) & 0xFF)
        dst[offset + 3] = UInt8((value >> 16) & 0xFF)
        dst[offset + 4] = UInt8((value >> 8) & 0xFF)
        dst[offset + 5] = UInt8(value & 0xFF)
    }
}
