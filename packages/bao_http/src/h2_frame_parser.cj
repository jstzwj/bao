// bao_http h2_frame_parser - HTTP/2 帧解析器
// 严格翻译自: src/http/H2FrameParser.zig (154 行)
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// HTTP/2 帧解析器
// 严格翻译自: bun/src/http/H2FrameParser.zig
//
// H2FrameParser.zig 定义 HTTP/2 线格式类型:
//   - client_preface: "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
//   - 常量: MAX_WINDOW_SIZE, MAX_HEADER_TABLE_SIZE, MAX_STREAM_ID, etc.
//   - FrameType: 帧类型枚举
//   - PingFrameFlags, DataFrameFlags, HeadersFrameFlags, SettingsFlags
//   - ErrorCode: H2 错误码枚举
//   - SettingsType: H2 设置类型枚举
//   - UInt31WithReserved: 31 位无符号整数 + 1 位保留
//   - StreamPriority: 流优先级
//   - FrameHeader: 帧头
//   - SettingsPayloadUnit: 设置载荷单元
// ============================================================================

/// HTTP/2 客户端前言
/// 严格翻译自: pub const client_preface = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
public let H2_CLIENT_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

/// 最大窗口大小
/// 严格翻译自: pub const MAX_WINDOW_SIZE = std.math.maxInt(i32)
public let H2_MAX_WINDOW_SIZE: Int32 = Int32(2147483647)

/// 最大头部表大小
/// 严格翻译自: pub const MAX_HEADER_TABLE_SIZE = std.math.maxInt(u32)
public let H2_MAX_HEADER_TABLE_SIZE: UInt32 = UInt32(4294967295)

/// 最大流 ID
/// 严格翻译自: pub const MAX_STREAM_ID = std.math.maxInt(i32)
public let H2_MAX_STREAM_ID: Int32 = Int32(2147483647)

/// 最大帧大小
/// 严格翻译自: pub const MAX_FRAME_SIZE = std.math.maxInt(u24)
public let H2_MAX_FRAME_SIZE: Int64 = 16777215

/// 默认窗口大小
/// 严格翻译自: pub const DEFAULT_WINDOW_SIZE = std.math.maxInt(u16)
public let H2_DEFAULT_WINDOW_SIZE: Int64 = 65535

/// 默认最大帧大小
/// 严格翻译自: pub const DEFAULT_MAX_FRAME_SIZE: u24 = 16384
public let H2_DEFAULT_MAX_FRAME_SIZE: Int64 = 16384

// ============================================================================
// PingFrameFlags - PING 帧标志
// 严格翻译自: pub const PingFrameFlags = enum(u8) { ACK = 0x1 }
// ============================================================================

/// PING 帧标志
public enum H2PingFrameFlags {
    | ACK
}

// ============================================================================
// DataFrameFlags - DATA 帧标志
// 严格翻译自:
//   pub const DataFrameFlags = enum(u8) { END_STREAM = 0x1, PADDED = 0x8 }
// ============================================================================

/// DATA 帧标志
public enum H2DataFrameFlags {
    | END_STREAM
    | PADDED
}

// ============================================================================
// HeadersFrameFlags - HEADERS 帧标志
// 严格翻译自:
//   pub const HeadersFrameFlags = enum(u8) {
//       END_STREAM = 0x1, END_HEADERS = 0x4, PADDED = 0x8, PRIORITY = 0x20,
//   }
// ============================================================================

/// HEADERS 帧标志
public enum H2HeadersFrameFlags {
    | END_STREAM
    | END_HEADERS
    | PADDED
    | PRIORITY
}

// ============================================================================
// SettingsType - HTTP/2 设置类型
// 严格翻译自:
//   pub const SettingsType = enum(u16) {
//       SETTINGS_HEADER_TABLE_SIZE = 0x1,
//       SETTINGS_ENABLE_PUSH = 0x2,
//       ...
//   }
// ============================================================================

/// HTTP/2 设置类型
/// 严格翻译自: H2FrameParser.SettingsType
public enum H2SettingsType {
    | HEADER_TABLE_SIZE          // 0x1
    | ENABLE_PUSH                // 0x2
    | MAX_CONCURRENT_STREAMS     // 0x3
    | INITIAL_WINDOW_SIZE        // 0x4
    | MAX_FRAME_SIZE             // 0x5
    | MAX_HEADER_LIST_SIZE       // 0x6
    | ENABLE_CONNECT_PROTOCOL    // 0x8
    | NO_RFC7540_PRIORITIES      // 0x9
    | UNKNOWN

    public func toUInt16(): UInt16 {
        match (this) {
            case HEADER_TABLE_SIZE => UInt16(0x1)
            case ENABLE_PUSH => UInt16(0x2)
            case MAX_CONCURRENT_STREAMS => UInt16(0x3)
            case INITIAL_WINDOW_SIZE => UInt16(0x4)
            case MAX_FRAME_SIZE => UInt16(0x5)
            case MAX_HEADER_LIST_SIZE => UInt16(0x6)
            case ENABLE_CONNECT_PROTOCOL => UInt16(0x8)
            case NO_RFC7540_PRIORITIES => UInt16(0x9)
            case UNKNOWN => UInt16(0)
        }
    }

    public static func fromUInt16(v: UInt16): H2SettingsType {
        if (v == UInt16(0x1)) { return HEADER_TABLE_SIZE }
        if (v == UInt16(0x2)) { return ENABLE_PUSH }
        if (v == UInt16(0x3)) { return MAX_CONCURRENT_STREAMS }
        if (v == UInt16(0x4)) { return INITIAL_WINDOW_SIZE }
        if (v == UInt16(0x5)) { return MAX_FRAME_SIZE }
        if (v == UInt16(0x6)) { return MAX_HEADER_LIST_SIZE }
        if (v == UInt16(0x8)) { return ENABLE_CONNECT_PROTOCOL }
        if (v == UInt16(0x9)) { return NO_RFC7540_PRIORITIES }
        return UNKNOWN
    }
}

// ============================================================================
// UInt31WithReserved - 31 位无符号整数 + 1 位保留
// 严格翻译自:
//   pub const UInt31WithReserved = packed struct(u32) {
//       reserved: bool = false,
//       uint31: u31 = 0,
//       pub inline fn from(value: u32) UInt31WithReserved
//       pub inline fn init(value: u31, reserved: bool) UInt31WithReserved
//       pub inline fn toUInt32(value: UInt31WithReserved) u32
//       pub inline fn fromBytes(src: []const u8) UInt31WithReserved
//   };
// ============================================================================

/// 31 位无符号整数 + 1 位保留
/// 严格翻译自: H2FrameParser.UInt31WithReserved
public class H2UInt31WithReserved {
    /// 保留位
    public var reserved: Bool
    /// 31 位值
    public var uint31: Int64

    public init() {
        reserved = false
        uint31 = 0
    }

    public init(reserved: Bool, uint31: Int64) {
        this.reserved = reserved
        this.uint31 = uint31
    }

    /// 从 UInt32 创建
    /// 严格翻译自: UInt31WithReserved.from
    public static func from(value: UInt32): H2UInt31WithReserved {
        return H2UInt31WithReserved(
            (value & UInt32(0x80000000)) != UInt32(0),
            Int64(value & UInt32(0x7FFFFFFF))
        )
    }

    /// 转为 UInt32
    /// 严格翻译自: UInt31WithReserved.toUInt32
    public func toUInt32(): UInt32 {
        var result = UInt32(uint31)
        if (reserved) {
            result = result | UInt32(0x80000000)
        }
        return result
    }

    /// 从字节解析
    /// 严格翻译自: UInt31WithReserved.fromBytes
    public static func fromBytes(src: Array<UInt8>): H2UInt31WithReserved {
        let value = u32FromBytes(src)
        return from(value)
    }
}

// ============================================================================
// StreamPriority - 流优先级
// 严格翻译自:
//   pub const StreamPriority = packed struct(u40) {
//       streamIdentifier: u32 = 0,
//       weight: u8 = 0,
//       pub const byteSize: usize = 5,
//       pub inline fn from(dst: *StreamPriority, src: []const u8) void
//   };
// ============================================================================

/// HTTP/2 流优先级
/// 严格翻译自: H2FrameParser.StreamPriority
public class H2StreamPriority {
    /// 流依赖的流标识符
    public var streamIdentifier: UInt32
    /// 权重 (1-256)
    public var weight: UInt8

    /// 字节大小
    /// 严格翻译自: pub const byteSize: usize = 5
    public static let BYTE_SIZE: Int64 = 5

    public init() {
        streamIdentifier = UInt32(0)
        weight = UInt8(0)
    }

    public init(streamIdentifier: UInt32, weight: UInt8) {
        this.streamIdentifier = streamIdentifier
        this.weight = weight
    }

    /// 从字节解析
    /// 严格翻译自: StreamPriority.from
    public static func fromBytes(src: Array<UInt8>): H2StreamPriority {
        let streamId = u32FromBytes(src)
        let w = if (src.size > 4) { src[4] } else { UInt8(0) }
        return H2StreamPriority(streamId, w)
    }
}

// ============================================================================
// FrameHeader - HTTP/2 帧头
// 严格翻译自:
//   pub const FrameHeader = packed struct(u72) {
//       length: u24 = 0,
//       type: u8 = @intFromEnum(FrameType.HTTP_FRAME_SETTINGS),
//       flags: u8 = 0,
//       streamIdentifier: u32 = 0,
//       pub const byteSize: usize = 9,
//   };
// ============================================================================

/// HTTP/2 帧头
/// 严格翻译自: H2FrameParser.FrameHeader
public class H2FrameHeader {
    /// 帧载荷长度 (24 位)
    public var length: Int64

    /// 帧类型
    public var type_: H2FrameType

    /// 标志位
    public var flags: UInt8

    /// 流标识符
    public var streamIdentifier: UInt32

    /// 字节大小
    /// 严格翻译自: pub const byteSize: usize = 9
    public static let BYTE_SIZE: Int64 = 9

    public init() {
        length = 0
        type_ = H2FrameType.Settings
        flags = UInt8(0)
        streamIdentifier = UInt32(0)
    }

    public init(length: Int64, type_: H2FrameType, flags: UInt8, streamIdentifier: UInt32) {
        this.length = length
        this.type_ = type_
        this.flags = flags
        this.streamIdentifier = streamIdentifier
    }

    /// 从字节解析 (大端序)
    /// 严格翻译自: FrameHeader.from
    public static func fromBytes(src: Array<UInt8>): H2FrameHeader {
        if (src.size < 9) {
            return H2FrameHeader()
        }
        // 长度: 3 字节大端序
        let len = (Int64(src[0]) << 16) | (Int64(src[1]) << 8) | Int64(src[2])
        let frameType = H2FrameType.fromCode(src[3])
        let flags = src[4]
        // 流标识符: 4 字节大端序 (最高位保留)
        let streamId = u32FromBytesAt(src, 5) & UInt32(0x7FFFFFFF)
        return H2FrameHeader(len, frameType, flags, streamId)
    }

    /// 序列化为字节
    public func toBytes(): Array<UInt8> {
        let buf = ArrayList<UInt8>()
        // 长度: 3 字节大端序
        buf.append(UInt8((length >> 16) & 0xFF))
        buf.append(UInt8((length >> 8) & 0xFF))
        buf.append(UInt8(length & 0xFF))
        // 类型
        buf.append(type_.code())
        // 标志
        buf.append(flags)
        // 流标识符: 4 字节大端序
        let sid = streamIdentifier
        buf.append(UInt8((sid >> 24) & 0xFF))
        buf.append(UInt8((sid >> 16) & 0xFF))
        buf.append(UInt8((sid >> 8) & 0xFF))
        buf.append(UInt8(sid & 0xFF))
        return buf.toOwnedSlice()
    }

    /// 检查 END_STREAM 标志
    public func isEndStream(): Bool {
        return (flags & UInt8(0x1)) != UInt8(0)
    }

    /// 检查 END_HEADERS 标志
    public func isEndHeaders(): Bool {
        return (flags & UInt8(0x4)) != UInt8(0)
    }

    /// 检查 ACK 标志
    public func isAck(): Bool {
        return (flags & UInt8(0x1)) != UInt8(0)
    }

    /// 检查 PADDED 标志
    public func isPadded(): Bool {
        return (flags & UInt8(0x8)) != UInt8(0)
    }

    /// 检查 PRIORITY 标志
    public func hasPriority(): Bool {
        return (flags & UInt8(0x20)) != UInt8(0)
    }
}

// ============================================================================
// SettingsPayloadUnit - 设置载荷单元
// 严格翻译自:
//   pub const SettingsPayloadUnit = packed struct(u48) {
//       type: u16,
//       value: u32,
//       pub const byteSize: usize = 6,
//       pub inline fn encode(dst: *[byteSize]u8, setting: SettingsType, value: u32) void
//   };
// ============================================================================

/// HTTP/2 设置载荷单元
/// 严格翻译自: H2FrameParser.SettingsPayloadUnit
public class H2SettingsPayloadUnit {
    /// 设置类型
    public var type_: H2SettingsType
    /// 设置值
    public var value: UInt32

    /// 字节大小
    /// 严格翻译自: pub const byteSize: usize = 6
    public static let BYTE_SIZE: Int64 = 6

    public init() {
        type_ = H2SettingsType.UNKNOWN
        value = UInt32(0)
    }

    public init(type_: H2SettingsType, value: UInt32) {
        this.type_ = type_
        this.value = value
    }

    /// 编码为字节 (大端序)
    /// 严格翻译自: SettingsPayloadUnit.encode
    public static func encode(setting: H2SettingsType, value: UInt32): Array<UInt8> {
        let buf = ArrayList<UInt8>()
        let t = setting.toUInt16()
        buf.append(UInt8((t >> 8) & 0xFF))
        buf.append(UInt8(t & 0xFF))
        buf.append(UInt8((value >> 24) & 0xFF))
        buf.append(UInt8((value >> 16) & 0xFF))
        buf.append(UInt8((value >> 8) & 0xFF))
        buf.append(UInt8(value & 0xFF))
        return buf.toOwnedSlice()
    }

    /// 从字节解析
    public static func fromBytes(src: Array<UInt8>): H2SettingsPayloadUnit {
        if (src.size < 6) {
            return H2SettingsPayloadUnit()
        }
        let typeVal = UInt16((UInt16(src[0]) << 8) | UInt16(src[1]))
        let valueVal = u32FromBytesAt(src, 2)
        return H2SettingsPayloadUnit(H2SettingsType.fromUInt16(typeVal), valueVal)
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 从 4 字节大端序读取 UInt32
/// 严格翻译自: pub inline fn u32FromBytes(src: []const u8) u32
public func u32FromBytes(src: Array<UInt8>): UInt32 {
    if (src.size < 4) {
        return UInt32(0)
    }
    return (UInt32(src[0]) << 24) | (UInt32(src[1]) << 16) |
           (UInt32(src[2]) << 8) | UInt32(src[3])
}

/// 从指定偏移量读取 4 字节大端序 UInt32
public func u32FromBytesAt(src: Array<UInt8>, offset: Int64): UInt32 {
    if (offset + 4 > src.size) {
        return UInt32(0)
    }
    return (UInt32(src[offset]) << 24) | (UInt32(src[offset + 1]) << 16) |
           (UInt32(src[offset + 2]) << 8) | UInt32(src[offset + 3])
}
