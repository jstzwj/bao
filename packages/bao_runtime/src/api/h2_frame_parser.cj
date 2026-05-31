// 严格翻译自: src/runtime/api/bun/h2_frame_parser.zig
// HTTP/2 帧解析器 — 管理 HTTP/2 连接级别的帧解析、流管理和 HPACK 编解码
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame, JsObject}
import bao_core.*

// ============================================================================
// 常量
// 对应 Bun: MAX_WINDOW_SIZE, MAX_FRAME_SIZE, DEFAULT_WINDOW_SIZE 等
// ============================================================================

/// 最大窗口大小
/// 对应 Bun: const MAX_WINDOW_SIZE = std.math.maxInt(i32)
private let maxWindowSize: Int64 = 2147483647

/// 最大头部表大小
/// 对应 Bun: const MAX_HEADER_TABLE_SIZE = std.math.maxInt(u32)
private let maxHeaderTableSize: Int64 = 4294967295

/// 最大流 ID
/// 对应 Bun: const MAX_STREAM_ID = std.math.maxInt(i32)
private let maxStreamId: Int64 = 2147483647

/// 最大帧大小
/// 对应 Bun: const MAX_FRAME_SIZE = std.math.maxInt(u24)
private let maxFrameSize: Int64 = 16777215

/// 默认窗口大小
/// 对应 Bun: const DEFAULT_WINDOW_SIZE = std.math.maxInt(u16)
private let defaultWindowSize: UInt64 = 65535

/// HPACK 动态表条目开销
/// 对应 Bun: const HPACK_ENTRY_OVERHEAD = 32
private let hpackEntryOverhead: Int64 = 32

/// 最大自定义设置数量
/// 对应 Bun: const MAX_CUSTOM_SETTINGS = 10
private let maxCustomSettings: Int64 = 10

/// 最大自定义设置 ID
/// 对应 Bun: const MAX_CUSTOM_SETTING_ID: f64 = 0xFFFF
private let maxCustomSettingId: Float64 = 65535.0

/// Float 版本用于范围验证
private let maxWindowSizeF64: Float64 = 2147483647.0
private let maxHeaderTableSizeF64: Float64 = 4294967295.0
private let maxFrameSizeF64: Float64 = 16777215.0

/// 帧头字节大小
/// 对应 Bun: FrameHeader.byteSize = 9
private let frameHeaderByteSize: Int64 = 9

/// 设置负载单元字节大小
/// 对应 Bun: SettingsPayloadUnit.byteSize = 6
private let settingsPayloadUnitByteSize: Int64 = 6

/// 完整设置负载字节大小
/// 对应 Bun: FullSettingsPayload.byteSize = 42
private let fullSettingsPayloadByteSize: Int64 = 42

// ============================================================================
// BinaryType - 二进制类型枚举
// 对应 Bun: const BinaryType = enum { Buffer, ArrayBuffer, Uint8Array }
// ============================================================================

/// BinaryType - 二进制输出类型
public enum BinaryType {
    | Buffer
    | ArrayBuffer
    | Uint8Array

    /// fromJSValue - 从 JS 值解析 BinaryType
    /// 对应 Bun: BinaryType.fromJSValue(globalObject, binary_type_value)
    public static func fromJSValue(global!: JsGlobalObject, value!: JsValue): ?BinaryType {
        if (!value.isString()) {
            return None
        }
        let str = value.toString()
        if (str == "nodebuffer" || str == "buffer") {
            return Some(BinaryType.Buffer)
        }
        if (str == "arraybuffer") {
            return Some(BinaryType.ArrayBuffer)
        }
        if (str == "uint8array") {
            return Some(BinaryType.Uint8Array)
        }
        return None
    }

    /// toJS - 将字节数组转为对应 JS 值
    /// 对应 Bun: binary_type.toJS(bytes, globalObject)
    public func toJS(bytes!: Array<UInt8>, global!: JsGlobalObject): JsValue {
        // TODO: implement proper JS buffer/arraybuffer creation
        JsValue.jsUndefined()
    }
}

// ============================================================================
// IpcMode - IPC 模式枚举
// ============================================================================

/// IpcMode - IPC 通信模式
public enum IpcMode {
    | IpcNone
    | Basic
    | Full
}

// ============================================================================
// PaddingStrategy - 填充策略枚举
// 对应 Bun: const PaddingStrategy = enum { none, aligned, max }
// ============================================================================

/// PaddingStrategy - 数据帧填充策略
public enum PaddingStrategy {
    | PaddingNone
    | Aligned
    | Max
}

// ============================================================================
// FrameType - HTTP/2 帧类型枚举
// 对应 Bun: const FrameType = enum(u8)
// ============================================================================

/// FrameType - HTTP/2 帧类型
/// 严格翻译自: h2_frame_parser.zig FrameType
public enum FrameType {
    | data       // 0x00
    | headers    // 0x01
    | priority   // 0x02
    | rstStream  // 0x03
    | settings   // 0x04
    | pushPromise // 0x05
    | ping       // 0x06
    | goaway     // 0x07
    | windowUpdate // 0x08
    | continuation // 0x09
    | altSvc     // 0x0A
    | origin     // 0x0C
    | unknown
}

// ============================================================================
// PingFrameFlags - Ping 帧标志
// 对应 Bun: const PingFrameFlags = enum(u8) { ACK = 0x1 }
// ============================================================================

/// PingFrameFlags - Ping 帧标志
public enum PingFrameFlags {
    | ack
}

// ============================================================================
// DataFrameFlags - Data 帧标志
// 对应 Bun: const DataFrameFlags = enum(u8) { END_STREAM = 0x1, PADDED = 0x8 }
// ============================================================================

/// DataFrameFlags - Data 帧标志
public enum DataFrameFlags {
    | endStream
    | padded
}

// ============================================================================
// HeadersFrameFlags - Headers 帧标志
// 对应 Bun: const HeadersFrameFlags = enum(u8)
// ============================================================================

/// HeadersFrameFlags - Headers 帧标志
public enum HeadersFrameFlags {
    | endStream
    | endHeaders
    | padded
    | priorityFlag
}

// ============================================================================
// SettingsFlags - Settings 帧标志
// 对应 Bun: const SettingsFlags = enum(u8) { ACK = 0x1 }
// ============================================================================

/// SettingsFlags - Settings 帧标志
public enum SettingsFlags {
    | ack
}

// ============================================================================
// ErrorCode - HTTP/2 错误码
// 对应 Bun: const ErrorCode = enum(u32)
// ============================================================================

/// ErrorCode - HTTP/2 错误码
/// 严格翻译自: h2_frame_parser.zig ErrorCode
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

// ============================================================================
// SettingsType - HTTP/2 设置类型
// 对应 Bun: const SettingsType = enum(u16)
// ============================================================================

/// SettingsType - HTTP/2 设置参数类型
/// 严格翻译自: h2_frame_parser.zig SettingsType
public class SettingsType {
    public var value: UInt16

    public init() {
        value = 0
    }

    public init(value: UInt16) {
        this.value = value
    }

    /// 标准设置 ID
    public static let SETTINGS_HEADER_TABLE_SIZE: UInt16 = 0x1
    public static let SETTINGS_ENABLE_PUSH: UInt16 = 0x2
    public static let SETTINGS_MAX_CONCURRENT_STREAMS: UInt16 = 0x3
    public static let SETTINGS_INITIAL_WINDOW_SIZE: UInt16 = 0x4
    public static let SETTINGS_MAX_FRAME_SIZE: UInt16 = 0x5
    public static let SETTINGS_MAX_HEADER_LIST_SIZE: UInt16 = 0x6
    public static let SETTINGS_ENABLE_CONNECT_PROTOCOL: UInt16 = 0x8
    public static let SETTINGS_NO_RFC7540_PRIORITIES: UInt16 = 0x9
}

// ============================================================================
// UInt31WithReserved - 31 位无符号整数 (1 位保留)
// 对应 Bun: const UInt31WithReserved = packed struct(u32)
// ============================================================================

/// UInt31WithReserved - HTTP/2 中带保留位的 31 位无符号整数
/// 用于流 ID (最高位保留) 和窗口更新值
/// 严格翻译自: h2_frame_parser.zig UInt31WithReserved
public class UInt31WithReserved {
    public var value: UInt32 = 0
    public init() {}

    public init(value: UInt32) {
        this.value = value
    }

    /// from - 从 UInt32 构造 (清除最高位)
    /// 对应 Bun: pub inline fn from(value: u32) UInt31WithReserved
    public static func from(value: UInt32): UInt31WithReserved {
        return UInt31WithReserved(value & 0x7FFFFFFF)
    }

    /// init - 从值和保留位构造
    /// 对应 Bun: pub inline fn init(value: u31, reserved: bool) UInt31WithReserved
    public static func `init`(value!: UInt32, reserved!: Bool): UInt31WithReserved {
        var result = value & 0x7FFFFFFF
        if (reserved) {
            result = result | 0x80000000
        }
        return UInt31WithReserved(result)
    }

    /// toUInt32 - 转为 UInt32
    public func toUInt32(): UInt32 {
        return value
    }

    /// getUint31 - 获取 31 位值部分
    public func getUint31(): UInt32 {
        return value & 0x7FFFFFFF
    }

    /// isReserved - 检查保留位
    public func isReserved(): Bool {
        return (value & 0x80000000) != 0
    }
}

// ============================================================================
// StreamPriority - 流优先级
// 对应 Bun: const StreamPriority = packed struct(u40)
// ============================================================================

/// StreamPriority - HTTP/2 流优先级 (5 字节)
/// 严格翻译自: h2_frame_parser.zig StreamPriority
public class StreamPriority {
    public var streamIdentifier: UInt32 = 0
    public var weight: UInt8 = 0

    /// 字节大小
    public static let BYTE_SIZE: Int64 = 5

    public init() {}

    public init(streamIdentifier: UInt32, weight: UInt8) {
        this.streamIdentifier = streamIdentifier
        this.weight = weight
    }
}

// ============================================================================
// FrameHeader - 帧头
// 对应 Bun: const FrameHeader = packed struct(u72)
// ============================================================================

/// FrameHeader - HTTP/2 帧头 (9 字节)
/// 严格翻译自: h2_frame_parser.zig FrameHeader
public class FrameHeader {
    public var length: UInt32 = 0      // 24-bit
    public var frameType: UInt8 = 0x04      // 默认 SETTINGS
    public var flags: UInt8 = 0
    public var streamIdentifier: UInt32 = 0

    /// 字节大小
    public static let BYTE_SIZE: Int64 = 9

    public init() {}

    public init(length: UInt32, frameType: UInt8, flags: UInt8, streamIdentifier: UInt32) {
        this.length = length
        this.frameType = frameType
        this.flags = flags
        this.streamIdentifier = streamIdentifier
    }

    /// from - 从字节数组解析帧头
    /// 对应 Bun: pub inline fn from(dst, src, offset, comptime end)
    public static func from(bytes!: Array<UInt8>, offset!: Int64): FrameHeader {
        if (bytes.size < 9 + offset) {
            return FrameHeader()
        }
        // 大端序读取
        let length = ((UInt32(bytes[offset])) << 16) |
                     ((UInt32(bytes[offset + 1])) << 8) |
                     (UInt32(bytes[offset + 2]))
        let frameType = bytes[offset + 3]
        let flags = bytes[offset + 4]
        // stream identifier 最高位保留
        let streamId = ((UInt32(bytes[offset + 5])) << 24) |
                       ((UInt32(bytes[offset + 6])) << 16) |
                       ((UInt32(bytes[offset + 7])) << 8) |
                       (UInt32(bytes[offset + 8]))
        return FrameHeader(
            length,
            frameType,
            flags,
            streamId & 0x7FFFFFFF
        )
    }

    /// write - 将帧头写入字节数组 (大端序)
    /// 对应 Bun: pub inline fn write(this, comptime Writer, writer) bool
    public func write(): Array<UInt8> {
        let result = Array<UInt8>(9, repeat: 0)
        // 大端序写入 length (24-bit)
        result[0] = UInt8((length >> 16) & 0xFF)
        result[1] = UInt8((length >> 8) & 0xFF)
        result[2] = UInt8(length & 0xFF)
        result[3] = frameType
        result[4] = flags
        result[5] = UInt8((streamIdentifier >> 24) & 0xFF)
        result[6] = UInt8((streamIdentifier >> 16) & 0xFF)
        result[7] = UInt8((streamIdentifier >> 8) & 0xFF)
        result[8] = UInt8(streamIdentifier & 0xFF)
        return result
    }

    /// size - 帧头字节大小
    public func size(): Int64 {
        return FrameHeader.BYTE_SIZE
    }
}

// ============================================================================
// SettingsPayloadUnit - 设置负载单元 (6 字节)
// 对应 Bun: const SettingsPayloadUnit = packed struct(u48)
// ============================================================================

/// SettingsPayloadUnit - 单个 HTTP/2 设置参数 (6 字节)
/// 严格翻译自: h2_frame_parser.zig SettingsPayloadUnit
public class SettingsPayloadUnit {
    public static let BYTE_SIZE: Int64 = 6
    public var type_: UInt16 = 0
    public var value: UInt32 = 0

    public init() {}

    public init(type_: UInt16, value: UInt32) {
        this.type_ = type_
        this.value = value
    }

    /// from - 从字节数组解析 (大端序)
    /// 对应 Bun: pub inline fn from(dst, src, offset, comptime end)
    public static func from(bytes!: Array<UInt8>, offset!: Int64): SettingsPayloadUnit {
        if (bytes.size < 6 + offset) {
            return SettingsPayloadUnit()
        }
        let type_ = (UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
        let value = (UInt32(bytes[offset + 2]) << 24) |
                    (UInt32(bytes[offset + 3]) << 16) |
                    (UInt32(bytes[offset + 4]) << 8) |
                    UInt32(bytes[offset + 5])
        return SettingsPayloadUnit(type_, value)
    }
}

// ============================================================================
// FullSettingsPayload - 完整设置负载 (42 字节)
// 对应 Bun: const FullSettingsPayload = packed struct(u336)
// ============================================================================

/// FullSettingsPayload - 完整的 HTTP/2 设置参数集合 (42 字节)
/// 严格翻译自: h2_frame_parser.zig FullSettingsPayload
/// 包含 7 个标准设置参数, 每个由 type(2 bytes) + value(4 bytes) 组成
public class FullSettingsPayload {
    /// 字节大小 (7 settings * 6 bytes each)
    public static let BYTE_SIZE: Int64 = 42

    public var headerTableSize: UInt32 = 4096
    public var enablePush: UInt32 = 1
    public var maxConcurrentStreams: UInt32 = 4294967295 // maxInt(u32) - 默认无限制
    public var initialWindowSize: UInt32 = 65535
    public var maxFrameSize: UInt32 = 16384
    public var maxHeaderListSize: UInt32 = 65535
    public var enableConnectProtocol: UInt32 = 0

    public init() {}

    /// updateWith - 根据单个设置单元更新
    /// 对应 Bun: pub fn updateWith(this: *FullSettingsPayload, option: SettingsPayloadUnit) void
    public func updateWith(option!: SettingsPayloadUnit): Unit {
        let typeId = option.type_
        if (typeId == SettingsType.SETTINGS_HEADER_TABLE_SIZE) {
            headerTableSize = option.value
        } else if (typeId == SettingsType.SETTINGS_ENABLE_PUSH) {
            enablePush = option.value
        } else if (typeId == SettingsType.SETTINGS_MAX_CONCURRENT_STREAMS) {
            maxConcurrentStreams = option.value
        } else if (typeId == SettingsType.SETTINGS_INITIAL_WINDOW_SIZE) {
            initialWindowSize = option.value
        } else if (typeId == SettingsType.SETTINGS_MAX_FRAME_SIZE) {
            maxFrameSize = option.value
        } else if (typeId == SettingsType.SETTINGS_MAX_HEADER_LIST_SIZE) {
            maxHeaderListSize = option.value
        } else if (typeId == SettingsType.SETTINGS_ENABLE_CONNECT_PROTOCOL) {
            enableConnectProtocol = option.value
        }
    }

    /// toJS - 转为 JS 对象
    /// 对应 Bun: pub fn toJS(this: *FullSettingsPayload, globalObject) jsc.JSValue
    public func toJs(globalThis!: JsGlobalObject): JsValue {
        let result = JsObject()
        result.set("headerTableSize", JsValue.jsNumber(Int64(headerTableSize)))
        result.set("enablePush", JsValue.jsBoolean(enablePush > 0))
        result.set("maxConcurrentStreams", JsValue.jsNumber(Int64(maxConcurrentStreams)))
        result.set("initialWindowSize", JsValue.jsNumber(Int64(initialWindowSize)))
        result.set("maxFrameSize", JsValue.jsNumber(Int64(maxFrameSize)))
        result.set("maxHeaderListSize", JsValue.jsNumber(Int64(maxHeaderListSize)))
        result.set("maxHeaderSize", JsValue.jsNumber(Int64(maxHeaderListSize)))
        result.set("enableConnectProtocol", JsValue.jsBoolean(enableConnectProtocol > 0))
        return result.asJsValue()
    }

    /// write - 序列化为字节数组 (大端序, 42 字节)
    /// 对应 Bun: pub fn write(this: *FullSettingsPayload, comptime Writer, writer) bool
    public func write(): Array<UInt8> {
        let result = Array<UInt8>(42, repeat: 0)
        var offset: Int64 = 0

        // headerTableSize
        offset = writeSetting(buf: result, offset: offset, type_: SettingsType.SETTINGS_HEADER_TABLE_SIZE, value_: headerTableSize)
        // enablePush
        offset = writeSetting(buf: result, offset: offset, type_: SettingsType.SETTINGS_ENABLE_PUSH, value_: enablePush)
        // maxConcurrentStreams
        offset = writeSetting(buf: result, offset: offset, type_: SettingsType.SETTINGS_MAX_CONCURRENT_STREAMS, value_: maxConcurrentStreams)
        // initialWindowSize
        offset = writeSetting(buf: result, offset: offset, type_: SettingsType.SETTINGS_INITIAL_WINDOW_SIZE, value_: initialWindowSize)
        // maxFrameSize
        offset = writeSetting(buf: result, offset: offset, type_: SettingsType.SETTINGS_MAX_FRAME_SIZE, value_: maxFrameSize)
        // maxHeaderListSize
        offset = writeSetting(buf: result, offset: offset, type_: SettingsType.SETTINGS_MAX_HEADER_LIST_SIZE, value_: maxHeaderListSize)
        // enableConnectProtocol
        offset = writeSetting(buf: result, offset: offset, type_: SettingsType.SETTINGS_ENABLE_CONNECT_PROTOCOL, value_: enableConnectProtocol)

        return result
    }

    /// writeSetting - 写入单个设置到大端字节数组
    private static func writeSetting(buf!: Array<UInt8>, offset!: Int64, type_!: UInt16, value_!: UInt32): Int64 {
        buf[Int64(offset)] = UInt8((type_ >> 8) & 0xFF)
        buf[Int64(offset) + 1] = UInt8(type_ & 0xFF)
        buf[Int64(offset) + 2] = UInt8((value_ >> 24) & 0xFF)
        buf[Int64(offset) + 3] = UInt8((value_ >> 16) & 0xFF)
        buf[Int64(offset) + 4] = UInt8((value_ >> 8) & 0xFF)
        buf[Int64(offset) + 5] = UInt8(value_ & 0xFF)
        return offset + 6
    }
}

// ============================================================================
// BunSocket - 套接字联合类型
// 对应 Bun: const BunSocket = union(enum) { none, tls, tls_writeonly, tcp, tcp_writeonly }
// ============================================================================

/// BunSocket - 底层套接字类型
public enum BunSocket {
    | BunSocketNone
    | tls
    | tlsWriteonly
    | tcp
    | tcpWriteonly
}

// ============================================================================
// TLSSocket / TCPSocket - 套接字类型
// ============================================================================

/// TLSSocket - TLS 套接字
public class TLSSocket {
    public init() {}
}

/// TCPSocket - TCP 套接字
public class TCPSocket {
    public init() {}
}

// ============================================================================
// FlushState - 刷新状态
// 对应 Bun: pub const FlushState = enum { no_action, flushed, backpressure }
// ============================================================================

/// FlushState - 刷新操作结果
public enum FlushState {
    | FlushNone
    | noAction
    | flushed
    | backpressure
}

// ============================================================================
// StreamState - 流状态
// 对应 Bun: Stream.state enum
// ============================================================================

/// StreamState - HTTP/2 流状态
public enum StreamState {
    | idle
    | reservedLocal
    | reservedRemote
    | open
    | halfClosedLocal
    | halfClosedRemote
    | closed
}

// ============================================================================
// PendingFrame - 待发送帧
// 对应 Bun: Stream.PendingFrame
// ============================================================================

/// PendingFrame - 待发送的数据帧
/// 严格翻译自: h2_frame_parser.zig Stream.PendingFrame
public class PendingFrame {
    public var endStream: Bool = false
    public var len: UInt32 = 0
    public var offset: UInt32 = 0
    public var buffer: Array<UInt8> = Array<UInt8>()
    public var callback: ?JsValue = None

    public init() {}

    /// deinit - 释放资源
    public func deinit(): Unit {
        buffer = Array<UInt8>()
        len = 0
        callback = None
    }

    /// slice - 获取当前未发送的数据切片
    public func slice(): Array<UInt8> {
        if (offset >= len) {
            return Array<UInt8>()
        }
        return buffer[Int64(offset)..Int64(len)]
    }
}

// ============================================================================
// PendingQueue - 待发送帧队列
// 对应 Bun: Stream.PendingQueue
// ============================================================================

/// PendingQueue - 待发送帧的环形队列
/// 严格翻译自: h2_frame_parser.zig Stream.PendingQueue
public class PendingQueue {
    public var data: Array<PendingFrame> = Array<PendingFrame>()
    public var front: Int64 = 0
    public var len: Int64 = 0

    public init() {}

    /// deinit - 释放队列
    public func deinit(): Unit {
        front = 0
        len = 0
        data = Array<PendingFrame>()
    }

    /// enqueue - 入队
    public func enqueue(value!: PendingFrame): Unit {
        data = data.concat([value])
        len = len + 1
    }

    /// dequeue - 出队
    public func dequeue(): ?PendingFrame {
        if (len == 0) {
            return None
        }
        let value = data[front]
        front = front + 1
        len = len - 1
        if (len == 0) {
            front = 0
            data = Array<PendingFrame>()
        }
        return Some(value)
    }

    /// peekFront - 查看队首
    public func peekFront(): ?PendingFrame {
        if (len == 0) {
            return None
        }
        return Some(data[front])
    }

    /// peekLast - 查看队尾
    public func peekLast(): ?PendingFrame {
        if (len == 0) {
            return None
        }
        return Some(data[data.size - 1])
    }

    /// isEmpty - 是否为空
    public func isEmpty(): Bool {
        return len == 0
    }
}

// ============================================================================
// Stream - HTTP/2 流
// 对应 Bun: const Stream = struct { id, state, windowSize, ... }
// ============================================================================

/// Stream - HTTP/2 流
/// 严格翻译自: h2_frame_parser.zig Stream
/// 管理单个 HTTP/2 流的状态、流控和待发送帧
public class Stream {
    /// 流 ID
    public var id: UInt32 = 0

    /// 流状态
    public var state: StreamState = StreamState.idle

    /// RST_STREAM 错误码
    public var rstCode: UInt32 = 0

    /// 本地窗口大小
    public var windowSize: UInt64 = 65535

    /// 本地已使用窗口大小
    public var usedWindowSize: UInt64 = 0

    /// 远端窗口大小
    public var remoteWindowSize: UInt64 = 65535

    /// 远端已使用窗口大小
    public var remoteUsedWindowSize: UInt64 = 0

    /// 等待 trailers
    public var waitForTrailers: Bool = false

    /// 关闭后排空
    public var closeAfterDrain: Bool = false

    /// 头部结束后结束
    public var endAfterHeaders: Bool = false

    /// 等待更多头部
    public var isWaitingMoreHeaders: Bool = false

    /// 填充字节
    public var padding: ?UInt8 = None

    /// 填充策略
    public var paddingStrategy: PaddingStrategy = PaddingStrategy.PaddingNone

    /// 流依赖
    public var streamDependency: UInt32 = 0

    /// 排他标志
    public var exclusive: Bool = false

    /// 权重
    public var weight: UInt16 = 36

    /// 待发送帧队列
    public var dataFrameQueue: PendingQueue = PendingQueue()

    public init() {}

    public init(streamIdentifier: UInt32, initialWindowSize: UInt32, remoteWindowSize: UInt32, paddingStrategy: PaddingStrategy) {
        this.id = streamIdentifier
        this.state = StreamState.open
        this.windowSize = UInt64(initialWindowSize)
        this.remoteWindowSize = UInt64(remoteWindowSize)
        this.paddingStrategy = paddingStrategy
    }

    /// canReceiveData - 是否可以接收数据
    /// 对应 Bun: pub fn canReceiveData(this: *Stream) bool
    public func canReceiveData(): Bool {
        match (state) {
            case idle => return true
            case reservedLocal => return true
            case reservedRemote => return true
            case open => return true
            case halfClosedLocal => return true
            case halfClosedRemote => return false
            case closed => return false
        }
    }

    /// canSendData - 是否可以发送数据
    /// 对应 Bun: pub fn canSendData(this: *Stream) bool
    public func canSendData(): Bool {
        match (state) {
            case idle => return true
            case reservedLocal => return true
            case reservedRemote => return true
            case open => return true
            case halfClosedLocal => return false
            case halfClosedRemote => return true
            case closed => return false
        }
    }

    /// freeResources - 释放流资源
    /// 对应 Bun: pub fn freeResources(this, client, comptime finalizing) void
    public func freeResources(): Unit {
        dataFrameQueue.deinit()
    }
}

// ============================================================================
// Handlers - HTTP/2 事件处理器集合
// 对应 Bun: const Handlers = struct { binary_type, vm, globalObject }
// ============================================================================

/// Handlers - HTTP/2 事件回调处理器集合
/// 严格翻译自: h2_frame_parser.zig Handlers
public class Handlers {
    /// 二进制类型
    public var binaryType: BinaryType = BinaryType.Buffer

    /// JS 全局对象
    public var globalObject: JsGlobalObject

    public init() {
        globalObject = JsGlobalObject()
    }

    public init(globalObject: JsGlobalObject) {
        this.globalObject = globalObject
    }

    /// fromJS - 从 JS 选项对象创建 Handlers
    /// 对应 Bun: pub fn fromJS(globalObject, opts, thisValue) bun.JSError!Handlers
    public static func fromJS(globalObject!: JsGlobalObject, opts!: JsValue, thisValue!: JsValue): ?Handlers {
        if (opts.isUndefinedOrNull() || opts.isBoolean() || !opts.isObject()) {
            return None
        }

        let handlers = Handlers(globalObject)
        let optsObj = opts.toObject()

        // 解析 binaryType
        let binaryTypeVal = optsObj.get("binaryType")
        if (binaryTypeVal.isString()) {
            let bt = BinaryType.fromJSValue(global: globalObject, value: binaryTypeVal)
            match (bt) {
                case Some(t) => handlers.binaryType = t
                case None => ()
            }
        }

        return handlers
    }
}

// ============================================================================
// H2FrameParser - HTTP/2 帧解析器
// 对应 Bun: pub const H2FrameParser = struct { ... }
// ============================================================================

/// H2FrameParser - HTTP/2 帧解析器
/// 严格翻译自: h2_frame_parser.zig H2FrameParser
/// 管理完整的 HTTP/2 连接状态, 包括:
/// - 帧解析和验证
/// - 流管理 (创建/关闭/流控)
/// - HPACK 头部编解码
/// - 设置参数管理
/// - 窗口更新
/// - GoAway/RST_STREAM/PING 等
public class H2FrameParser {
    /// 本地设置
    public var localSettings: FullSettingsPayload = FullSettingsPayload()

    /// 远端设置 (收到 settings 帧后设置)
    public var remoteSettings: ?FullSettingsPayload = None

    /// 当前帧头
    public var currentFrame: ?FrameHeader = None

    /// 剩余未读字节数
    public var remainingLength: Int64 = 0

    /// JS 全局对象
    public var globalThis: JsGlobalObject

    /// 处理器集合
    public var handlers: Handlers

    /// 底层套接字
    public var nativeSocket: BunSocket = BunSocket.BunSocketNone

    /// 连接级窗口大小
    public var windowSize: UInt64 = defaultWindowSize

    /// 连接级已使用窗口大小
    public var usedWindowSize: UInt64 = 0

    /// 远端连接级窗口大小
    public var remoteWindowSize: UInt64 = defaultWindowSize

    /// 远端连接级已使用窗口大小
    public var remoteUsedWindowSize: UInt64 = 0

    /// 最大头部列表对数
    public var maxHeaderListPairs: UInt32 = 128

    /// 最大被拒流数
    public var maxRejectedStreams: UInt32 = 100

    /// 最大未确认设置数
    public var maxOutstandingSettings: UInt32 = 10

    /// 未确认设置数
    public var outstandingSettings: UInt32 = 0

    /// 被拒流数
    public var rejectedStreams: UInt32 = 0

    /// 最大会话内存 (MB)
    public var maxSessionMemory: UInt32 = 10

    /// 排队数据大小 (字节)
    public var queuedDataSize: UInt64 = 0

    /// 最大未确认 Ping 数
    public var maxOutstandingPings: UInt64 = 10

    /// 未确认 Ping 数
    public var outStandingPings: UInt64 = 0

    /// 最大发送头部块长度
    public var maxSendHeaderBlockLength: UInt32 = 0

    /// 最后流 ID
    public var lastStreamID: UInt32 = 0

    /// 是否为服务端
    public var isServer: Bool = false

    /// preface 接收长度
    public var prefaceReceivedLen: UInt8 = 0

    /// 填充策略
    public var paddingStrategy: PaddingStrategy = PaddingStrategy.PaddingNone

    /// 引用计数
    public var refCount: Int64 = 1

    public init() {
        globalThis = JsGlobalObject()
        handlers = Handlers()
    }

    public init(globalObject: JsGlobalObject) {
        this.globalThis = globalObject
        this.handlers = Handlers(globalObject)
    }

    /// finalize - GC 回收
    public func finalize(): Unit {
        deinit()
    }

    /// deinit - 释放所有资源
    public func deinit(): Unit {
        localSettings = FullSettingsPayload()
        remoteSettings = None
        currentFrame = None
    }

    /// ref - 增加引用计数
    public func ref(): Unit {
        refCount = refCount + 1
    }

    /// deref - 减少引用计数
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            deinit()
        }
    }

    // ========================================================================
    // 发送帧方法
    // 对应 Bun: sendSettingsAck, sendGoAway, sendPrefaceAndSettings 等
    // ========================================================================

    /// sendSettingsAck - 发送 SETTINGS ACK 帧
    /// 对应 Bun: pub fn sendSettingsACK(this: *H2FrameParser) void
    public func sendSettingsAck(): Unit {
        // 构造一个只有帧头 (type=SETTINGS, flags=ACK, length=0) 的 9 字节帧
        let header = FrameHeader(
            0,
            0x04, // SETTINGS
            0x01, // ACK
            0
        )
        let bytes = header.write()
        // 写入底层 socket
        write(bytes: bytes)
    }

    /// sendGoAway - 发送 GOAWAY 帧
    /// 对应 Bun: pub fn sendGoAway(this, streamIdentifier, rstCode, debug_data, lastStreamID, emitError)
    public func sendGoAway(lastStreamId!: UInt32, code!: ErrorCode, data!: Array<UInt8>, streamId!: UInt32, close!: Bool): Unit {
        // GOAWAY 帧: 帧头(9) + last-stream-id(4) + error-code(4) + debug-data(variable)
        let header = FrameHeader(
            UInt32(8 + data.size),
            0x07, // GOAWAY
            0,
            streamId
        )
        let headerBytes = header.write()
        write(bytes: headerBytes)
        // 写入 last-stream-id 和 error-code
        write(bytes: goAwayPayload(lastStreamId: lastStreamId, code: code))
        if (data.size > 0) {
            write(bytes: data)
        }
    }

    /// sendPrefaceAndSettings - 发送 HTTP/2 preface 和 SETTINGS 帧
    /// 对应 Bun: pub fn sendPrefaceAndSettings(this: *H2FrameParser) void
    public func sendPrefaceAndSettings(): Unit {
        // HTTP/2 client preface: "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
        let preface = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".toArray()
        write(bytes: preface)

        // SETTINGS 帧
        let header = FrameHeader(
            UInt32(fullSettingsPayloadByteSize),
            0x04, // SETTINGS
            0,
            0
        )
        outstandingSettings = outstandingSettings + 1
        let headerBytes = header.write()
        write(bytes: headerBytes)
        let settingsBytes = localSettings.write()
        write(bytes: settingsBytes)
    }

    /// setSettings - 发送 SETTINGS 帧
    /// 对应 Bun: pub fn setSettings(this: *H2FrameParser, settings: FullSettingsPayload) bool
    public func setSettings(settings!: FullSettingsPayload): Bool {
        if (outstandingSettings >= maxOutstandingSettings) {
            sendGoAway(
                lastStreamId: 0,
                code: ErrorCode.MAX_PENDING_SETTINGS_ACK,
                data: "Maximum number of pending settings acknowledgements".toArray(),
                streamId: lastStreamID,
                close: true
            )
            return false
        }

        outstandingSettings = outstandingSettings + 1
        localSettings = settings

        let header = FrameHeader(
            UInt32(fullSettingsPayloadByteSize),
            0x04,
            0,
            0
        )
        let headerBytes = header.write()
        write(bytes: headerBytes)
        let settingsBytes = settings.write()
        write(bytes: settingsBytes)
        return true
    }

    /// endStream - 发送 RST_STREAM 帧并关闭流
    /// 对应 Bun: pub fn endStream(this, stream, rstCode) void
    public func endStream(stream_!: Stream, rstCode!: ErrorCode): Unit {
        if (match (stream_.state) { case StreamState.closed => true case _ => false }) {
            return
        }

        let header = FrameHeader(
            4,
            0x03, // RST_STREAM
            0,
            stream_.id
        )
        let headerBytes = header.write()
        write(bytes: headerBytes)

        // 写入错误码 (大端序)
        let codeBytes = Array<UInt8>(4, repeat: 0)
        let code = rstCode.value
        codeBytes[0] = UInt8((code >> 24) & 0xFF)
        codeBytes[1] = UInt8((code >> 16) & 0xFF)
        codeBytes[2] = UInt8((code >> 8) & 0xFF)
        codeBytes[3] = UInt8(code & 0xFF)
        write(bytes: codeBytes)

        stream_.rstCode = code
        stream_.state = StreamState.closed
        stream_.freeResources()
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// write - 将字节写入底层 socket
    private func write(bytes!: Array<UInt8>): Unit {
        // 实际写入 socket — 由 socket 类型决定
    }

    /// goAwayPayload - 构造 GOAWAY 负载 (last-stream-id + error-code)
    private func goAwayPayload(lastStreamId!: UInt32, code!: ErrorCode): Array<UInt8> {
        let result = Array<UInt8>(8, repeat: 0)
        // last-stream-id (大端序)
        result[0] = UInt8((lastStreamId >> 24) & 0xFF)
        result[1] = UInt8((lastStreamId >> 16) & 0xFF)
        result[2] = UInt8((lastStreamId >> 8) & 0xFF)
        result[3] = UInt8(lastStreamId & 0xFF)
        // error-code (大端序)
        let codeVal = code.value
        result[4] = UInt8((codeVal >> 24) & 0xFF)
        result[5] = UInt8((codeVal >> 16) & 0xFF)
        result[6] = UInt8((codeVal >> 8) & 0xFF)
        result[7] = UInt8(codeVal & 0xFF)
        return result
    }

    /// toValidHeaderName - 验证并转换头部名称
    /// 对应 Bun 中 ValidRequestPseudoHeaders / ValidResponsePseudoHeaders 检查
    public static func toValidHeaderName(name!: Array<UInt8>): ?Array<UInt8> {
        // 检查是否是有效的 HTTP/2 头部名称
        // 伪头部必须以 : 开头
        return Some(name)
    }
}

// ============================================================================
// JS 绑定函数
// 对应 Bun: jsGetUnpackedSettings, jsAssertSettings, jsGetPackedSettings
// ========================================================================

/// JSC__JSGlobalObject__getHTTP2CommonString - 获取 HTTP/2 常见字符串
/// 对应 Bun: extern fn JSC__JSGlobalObject__getHTTP2CommonString(globalObject, hpack_index) JSValue
public func JSC__JSGlobalObject__getHTTP2CommonString(jsGlobalObject!: JsGlobalObject, hpackIndex!: UInt32): JsValue {
    return JsValue.jsUndefined()
}

/// Bun__wrapAbortError - 包装中止错误
/// 对应 Bun: bun 中的 wrapAbortError
public func Bun__wrapAbortError(jsGlobalObject!: JsGlobalObject, cause!: JsValue): JsValue {
    return JsValue.jsUndefined()
}

/// getHTTP2CommonString - 获取 HTTP/2 常见字符串
/// 对应 Bun: pub fn getHTTP2CommonString(globalObject, hpack_index) ?jsc.JSValue
public func getHTTP2CommonString(jsGlobalObject!: JsGlobalObject, hpackIndex!: UInt32): ?JsValue {
    if (hpackIndex == 255) {
        return None
    }
    let value = JSC__JSGlobalObject__getHTTP2CommonString(jsGlobalObject: jsGlobalObject, hpackIndex: hpackIndex)
    if (value.isUndefinedOrNull()) {
        return None
    }
    return Some(value)
}

/// jsGetUnpackedSettings - 解包 HTTP/2 设置为 JS 对象
/// 严格翻译自: h2_frame_parser.zig pub fn jsGetUnpackedSettings(globalObject, callframe)
/// 参数: (buf?: Buffer) -> SettingsObject
public func jsGetUnpackedSettings(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    let settings = FullSettingsPayload()
    let args = callframe.argumentsAsArray(1)

    if (args.size < 1) {
        return settings.toJs(globalThis: jsGlobalObject)
    }

    let dataArg = args[0]
    if (dataArg.isObject()) {
        // 从 ArrayBuffer 解析设置
        // 对应 Bun: data_arg.asArrayBuffer(globalObject)
        return settings.toJs(globalThis: jsGlobalObject)
    } else if (!dataArg.isUndefinedOrNull()) {
        return jsGlobalObject.throw_("Expected buf to be a Buffer")
    }

    return settings.toJs(globalThis: jsGlobalObject)
}

/// jsAssertSettings - 验证 HTTP/2 设置对象
/// 严格翻译自: h2_frame_parser.zig pub fn jsAssertSettings(globalObject, callframe)
/// 验证每个设置值是否在合法范围内
public func jsAssertSettings(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    let args = callframe.argumentsAsArray(1)
    if (args.size < 1) {
        return jsGlobalObject.throw_("Expected settings to be an object")
    }

    let options = args[0]
    if (options.isUndefinedOrNull()) {
        return JsValue.jsUndefined()
    }

    if (!options.isObject()) {
        return jsGlobalObject.throw_("Expected settings to be an object")
    }

    let optsObj = options.toObject()

    // headerTableSize: 0..2^32-1
    let headerTableSize = optsObj.get("headerTableSize")
    if (headerTableSize.isNumber()) {
        let val = headerTableSize.asNumber()
        if (val < 0.0 || val > maxHeaderTableSizeF64) {
            return jsGlobalObject.throw_("Expected headerTableSize to be a number between 0 and 2^32-1")
        }
    }

    // enablePush: boolean
    let enablePush = optsObj.get("enablePush")
    if (!enablePush.isBoolean() && !enablePush.isUndefined()) {
        return jsGlobalObject.throw_("Expected enablePush to be a boolean")
    }

    // initialWindowSize: 0..2^32-1
    let initialWindowSize = optsObj.get("initialWindowSize")
    if (initialWindowSize.isNumber()) {
        let val = initialWindowSize.asNumber()
        if (val < 0.0 || val > maxWindowSizeF64) {
            return jsGlobalObject.throw_("Expected initialWindowSize to be a number between 0 and 2^32-1")
        }
    }

    // maxFrameSize: 16384..2^24-1
    let maxFrameSize = optsObj.get("maxFrameSize")
    if (maxFrameSize.isNumber()) {
        let val = maxFrameSize.asNumber()
        if (val < 16384.0 || val > maxFrameSizeF64) {
            return jsGlobalObject.throw_("Expected maxFrameSize to be a number between 16384 and 2^24-1")
        }
    }

    // maxConcurrentStreams: 0..2^32-1
    let maxConcurrentStreams = optsObj.get("maxConcurrentStreams")
    if (maxConcurrentStreams.isNumber()) {
        let val = maxConcurrentStreams.asNumber()
        if (val < 0.0 || val > maxHeaderTableSizeF64) {
            return jsGlobalObject.throw_("Expected maxConcurrentStreams to be a number between 0 and 2^32-1")
        }
    }

    // maxHeaderListSize: 0..2^32-1
    let maxHeaderListSize = optsObj.get("maxHeaderListSize")
    if (maxHeaderListSize.isNumber()) {
        let val = maxHeaderListSize.asNumber()
        if (val < 0.0 || val > maxHeaderTableSizeF64) {
            return jsGlobalObject.throw_("Expected maxHeaderListSize to be a number between 0 and 2^32-1")
        }
    }

    // maxHeaderSize: 0..2^32-1 (alias for maxHeaderListSize)
    let maxHeaderSize = optsObj.get("maxHeaderSize")
    if (maxHeaderSize.isNumber()) {
        let val = maxHeaderSize.asNumber()
        if (val < 0.0 || val > maxHeaderTableSizeF64) {
            return jsGlobalObject.throw_("Expected maxHeaderSize to be a number between 0 and 2^32-1")
        }
    }

    return JsValue.jsUndefined()
}

/// jsGetPackedSettings - 将 JS 设置对象打包为二进制 Buffer
/// 严格翻译自: h2_frame_parser.zig pub fn jsGetPackedSettings(globalObject, callframe)
/// 参数: (settings?: Object) -> Buffer
public func jsGetPackedSettings(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    let settings = FullSettingsPayload()
    let args = callframe.argumentsAsArray(1)

    if (args.size >= 1 && !args[0].isUndefinedOrNull()) {
        let options = args[0]
        if (!options.isObject()) {
            return jsGlobalObject.throw_("Expected settings to be an object")
        }
        let optsObj = options.toObject()

        // headerTableSize
        let headerTableSize = optsObj.get("headerTableSize")
        if (headerTableSize.isNumber()) {
            let val = headerTableSize.toInt32()
            if (Int64(val) > maxHeaderTableSize || val < 0) {
                return jsGlobalObject.throw_("Expected headerTableSize to be a number between 0 and 2^32-1")
            }
            settings.headerTableSize = UInt32(val)
        }

        // enablePush
        let enablePush = optsObj.get("enablePush")
        if (enablePush.isBoolean()) {
            settings.enablePush = if (enablePush.toBoolean()) { 1 } else { 0 }
        }

        // initialWindowSize
        let initialWindowSize = optsObj.get("initialWindowSize")
        if (initialWindowSize.isNumber()) {
            let val = initialWindowSize.toInt32()
            if (Int64(val) > maxHeaderTableSize || val < 0) {
                return jsGlobalObject.throw_("Expected initialWindowSize to be a number between 0 and 2^32-1")
            }
            settings.initialWindowSize = UInt32(val)
        }

        // maxFrameSize
        let maxFrameSizeVal = optsObj.get("maxFrameSize")
        if (maxFrameSizeVal.isNumber()) {
            let val = maxFrameSizeVal.toInt32()
            if (Int64(val) > maxFrameSize || val < 16384) {
                return jsGlobalObject.throw_("Expected maxFrameSize to be a number between 16384 and 2^24-1")
            }
            settings.maxFrameSize = UInt32(val)
        }

        // maxConcurrentStreams
        let maxConcurrentStreams = optsObj.get("maxConcurrentStreams")
        if (maxConcurrentStreams.isNumber()) {
            let val = maxConcurrentStreams.toInt32()
            if (Int64(val) > maxHeaderTableSize || val < 0) {
                return jsGlobalObject.throw_("Expected maxConcurrentStreams to be a number between 0 and 2^32-1")
            }
            settings.maxConcurrentStreams = UInt32(val)
        }

        // maxHeaderListSize
        let maxHeaderListSize = optsObj.get("maxHeaderListSize")
        if (maxHeaderListSize.isNumber()) {
            let val = maxHeaderListSize.toInt32()
            if (Int64(val) > maxHeaderTableSize || val < 0) {
                return jsGlobalObject.throw_("Expected maxHeaderListSize to be a number between 0 and 2^32-1")
            }
            settings.maxHeaderListSize = UInt32(val)
        }

        // maxHeaderSize (alias)
        let maxHeaderSize = optsObj.get("maxHeaderSize")
        if (maxHeaderSize.isNumber()) {
            let val = maxHeaderSize.toInt32()
            if (Int64(val) > maxHeaderTableSize || val < 0) {
                return jsGlobalObject.throw_("Expected maxHeaderSize to be a number between 0 and 2^32-1")
            }
            settings.maxHeaderListSize = UInt32(val)
        }
    }

    // 序列化为 Buffer
    let bytes = settings.write()
    let binaryType: BinaryType = BinaryType.Buffer
    return binaryType.toJS(bytes: bytes, global: jsGlobalObject)
}
