// bao_http http2 - HTTP/2 协议实现
// 严格翻译自: src/http/ H2Client
// 参考: src/http/H2FrameParser.zig, src/http/h2_client/ClientSession.zig,
//        src/http/h2_client/Stream.zig, src/http/lshpack.zig
//   Bun 的 HTTP/2 客户端基于 lshpack (HPACK) + 自定义帧解析器实现
//   H2FrameParser 定义了 HTTP/2 帧的线格式类型 (独立于 JSC)
//   ClientSession 管理 TLS socket + HPACK 表 + 活跃 Stream 映射
//   Stream 表示单个请求/响应对，支持流多路复用
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// H2FrameType - HTTP/2 帧类型
// 严格翻译自: src/http/H2FrameParser.zig FrameType
//   Bun: pub const FrameType = enum(u8) {
//       HTTP_FRAME_DATA = 0x00,
//       HTTP_FRAME_HEADERS = 0x01, ...
//   }
// ============================================================================

/// HTTP/2 帧类型 - 对应 RFC 9113 §6
/// 严格对应 Bun H2FrameParser.FrameType 枚举值
public enum H2FrameType {
    | Data          // 0x00 - 对应 HTTP_FRAME_DATA
    | Headers       // 0x01 - 对应 HTTP_FRAME_HEADERS
    | Priority      // 0x02 - 对应 HTTP_FRAME_PRIORITY
    | RstStream     // 0x03 - 对应 HTTP_FRAME_RST_STREAM
    | Settings      // 0x04 - 对应 HTTP_FRAME_SETTINGS
    | PushPromise   // 0x05 - 对应 HTTP_FRAME_PUSH_PROMISE
    | Ping          // 0x06 - 对应 HTTP_FRAME_PING
    | Goaway        // 0x07 - 对应 HTTP_FRAME_GOAWAY
    | WindowUpdate  // 0x08 - 对应 HTTP_FRAME_WINDOW_UPDATE
    | Continuation  // 0x09 - 对应 HTTP_FRAME_CONTINUATION
    | Unknown(UInt8)

    public func code(): UInt8 {
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
            case Unknown(b) => b
        }
    }

    public static func fromCode(code: UInt8): H2FrameType {
        match (Int32(code)) {
            case 0x00 => Data
            case 0x01 => Headers
            case 0x02 => Priority
            case 0x03 => RstStream
            case 0x04 => Settings
            case 0x05 => PushPromise
            case 0x06 => Ping
            case 0x07 => Goaway
            case 0x08 => WindowUpdate
            case 0x09 => Continuation
            case _ => Unknown(code)
        }
    }
}

// ============================================================================
// H2ErrorCode - HTTP/2 错误码
// 严格翻译自: src/http/H2FrameParser.zig ErrorCode
//   Bun: pub const ErrorCode = enum(u32) { NO_ERROR = 0x0, ... }
// ============================================================================

/// HTTP/2 错误码 - 对应 RFC 9113 §7
public enum H2ErrorCode {
    | NoError              // 0x0  - 对应 NO_ERROR
    | ProtocolError        // 0x1  - 对应 PROTOCOL_ERROR
    | InternalError        // 0x2  - 对应 INTERNAL_ERROR
    | FlowControlError     // 0x3  - 对应 FLOW_CONTROL_ERROR
    | SettingsTimeout      // 0x4  - 对应 SETTINGS_TIMEOUT
    | StreamClosed         // 0x5  - 对应 STREAM_CLOSED
    | FrameSizeError       // 0x6  - 对应 FRAME_SIZE_ERROR
    | RefusedStream        // 0x7  - 对应 REFUSED_STREAM
    | Cancel               // 0x8  - 对应 CANCEL
    | CompressionError     // 0x9  - 对应 COMPRESSION_ERROR
    | ConnectError         // 0xa  - 对应 CONNECT_ERROR
    | EnhanceYourCalm      // 0xb  - 对应 ENHANCE_YOUR_CALM
    | InadequateSecurity   // 0xc  - 对应 INADEQUATE_SECURITY
    | Http11Required       // 0xd  - 对应 HTTP_1_1_REQUIRED

    public func code(): UInt32 {
        match (this) {
            case NoError => 0x0
            case ProtocolError => 0x1
            case InternalError => 0x2
            case FlowControlError => 0x3
            case SettingsTimeout => 0x4
            case StreamClosed => 0x5
            case FrameSizeError => 0x6
            case RefusedStream => 0x7
            case Cancel => 0x8
            case CompressionError => 0x9
            case ConnectError => 0xa
            case EnhanceYourCalm => 0xb
            case InadequateSecurity => 0xc
            case Http11Required => 0xd
        }
    }

    public static func fromCode(code: UInt32): H2ErrorCode {
        match (code) {
            case 0x0 => NoError
            case 0x1 => ProtocolError
            case 0x2 => InternalError
            case 0x3 => FlowControlError
            case 0x4 => SettingsTimeout
            case 0x5 => StreamClosed
            case 0x6 => FrameSizeError
            case 0x7 => RefusedStream
            case 0x8 => Cancel
            case 0x9 => CompressionError
            case 0xa => ConnectError
            case 0xb => EnhanceYourCalm
            case 0xc => InadequateSecurity
            case 0xd => Http11Required
            case _ => InternalError
        }
    }
}

// ============================================================================
// H2SettingsId - HTTP/2 SETTINGS 参数 ID
// 严格翻译自: src/http/H2FrameParser.zig SettingsType
// ============================================================================

/// HTTP/2 SETTINGS 参数 - 对应 RFC 9113 §6.5.2
public enum H2SettingsId {
    | HeaderTableSize       // 0x1 - SETTINGS_HEADER_TABLE_SIZE
    | EnablePush            // 0x2 - SETTINGS_ENABLE_PUSH
    | MaxConcurrentStreams  // 0x3 - SETTINGS_MAX_CONCURRENT_STREAMS
    | InitialWindowSize     // 0x4 - SETTINGS_INITIAL_WINDOW_SIZE
    | MaxFrameSize          // 0x5 - SETTINGS_MAX_FRAME_SIZE
    | MaxHeaderListSize     // 0x6 - SETTINGS_MAX_HEADER_LIST_SIZE
    | EnableConnectProtocol // 0x8 - SETTINGS_ENABLE_CONNECT_PROTOCOL
    | NoRfc7540Priorities   // 0x9 - SETTINGS_NO_RFC7540_PRIORITIES
    | Unknown(UInt16)

    public func id(): UInt16 {
        match (this) {
            case HeaderTableSize => 0x1
            case EnablePush => 0x2
            case MaxConcurrentStreams => 0x3
            case InitialWindowSize => 0x4
            case MaxFrameSize => 0x5
            case MaxHeaderListSize => 0x6
            case EnableConnectProtocol => 0x8
            case NoRfc7540Priorities => 0x9
            case Unknown(v) => v
        }
    }
}

// ============================================================================
// H2FrameFlags - 帧标志位
// 严格翻译自: src/http/H2FrameParser.zig *FrameFlags
// ============================================================================

/// DATA 帧标志 - 对应 Bun DataFrameFlags
public class H2DataFlags {
    public static let END_STREAM: UInt8 = 0x1
    public static let PADDED: UInt8 = 0x8
}

/// HEADERS 帧标志 - 对应 Bun HeadersFrameFlags
public class H2HeadersFlags {
    public static let END_STREAM: UInt8 = 0x1
    public static let END_HEADERS: UInt8 = 0x4
    public static let PADDED: UInt8 = 0x8
    public static let PRIORITY: UInt8 = 0x20
}

/// SETTINGS 帧标志
public class H2SettingsFlags {
    public static let ACK: UInt8 = 0x1
}

/// PING 帧标志
public class H2PingFlags {
    public static let ACK: UInt8 = 0x1
}

// ============================================================================
// H2Frame - HTTP/2 帧表示
// 严格翻译自: src/http/H2FrameParser.zig 帧解析
//   HTTP/2 帧格式 (RFC 9113 §4.1):
//   +-----------------------------------------------+
//   |                 Length (24)                   |
//   +---------------+---------------+---------------+
//   |   Type (8)    |   Flags (8)   |
//   +-+-------------+---------------+-------------------------------+
//   |R|                 Stream Identifier (31)                      |
//   +=+=============================================================+
//   |                   Frame Payload (0...)                       |
//   +---------------------------------------------------------------+
// ============================================================================

/// HTTP/2 帧 - 对应 Bun H2FrameParser 解析结果
public class H2Frame {
    /// 帧长度 (24-bit) - 对应 Length 字段
    public var length: Int64
    /// 帧类型 - 对应 Type 字段
    public var frameType: H2FrameType
    /// 标志位 - 对应 Flags 字段
    public var flags: UInt8
    /// 流标识符 (31-bit, 最高位保留) - 对应 Stream Identifier
    public var streamId: Int64
    /// 帧负载
    public var payload: Array<UInt8>

    public init() {
        length = 0
        frameType = H2FrameType.Data
        flags = 0
        streamId = 0
        payload = Array<UInt8>()
    }

    /// 是否设置指定标志位
    public func hasFlag(flag: UInt8): Bool {
        return (flags & flag) != 0
    }

    /// 从原始字节解析帧头 (9 字节)
    /// 对应 Bun H2FrameParser 的帧头读取
    public static func parseHeader(data: Array<UInt8>): ?H2Frame {
        if (data.size < 9) {
            return None
        }

        let frame = H2Frame()

        // Length: 24-bit big-endian (字节 0-2)
        frame.length = (Int64(data[0]) << 16) | (Int64(data[1]) << 8) | Int64(data[2])

        // Type: 8-bit (字节 3)
        frame.frameType = H2FrameType.fromCode(data[3])

        // Flags: 8-bit (字节 4)
        frame.flags = data[4]

        // Stream Identifier: 31-bit (字节 5-8, 最高位 R 保留)
        frame.streamId = ((Int64(data[5]) & 0x7F) << 24) |
                         (Int64(data[6]) << 16) |
                         (Int64(data[7]) << 8) |
                         Int64(data[8])

        return Some(frame)
    }

    /// 序列化帧头为字节数组 (9 字节)
    public func serializeHeader(): Array<UInt8> {
        let header = Array<UInt8>(9, item: UInt8(0))
        // Length (24-bit big-endian)
        header[0] = UInt8((length >> 16) & 0xFF)
        header[1] = UInt8((length >> 8) & 0xFF)
        header[2] = UInt8(length & 0xFF)
        // Type
        header[3] = frameType.code()
        // Flags
        header[4] = flags
        // Stream Identifier (31-bit, R=0)
        header[5] = UInt8((streamId >> 24) & 0x7F)
        header[6] = UInt8((streamId >> 16) & 0xFF)
        header[7] = UInt8((streamId >> 8) & 0xFF)
        header[8] = UInt8(streamId & 0xFF)
        return header
    }
}

// ============================================================================
// H2Settings - HTTP/2 SETTINGS 帧
// 严格翻译自: src/http/h2_client/ClientSession.zig 中 remote/local settings
//   Bun ClientSession 维护 remote_max_frame_size, remote_max_concurrent_streams,
//   remote_initial_window_size 等远程参数
// ============================================================================

/// HTTP/2 连接参数设置 - 对应 Bun ClientSession 中的配置
public class H2Settings {
    /// 对应 Bun: remote_max_frame_size (默认 16384)
    public var maxFrameSize: Int64
    /// 对应 Bun: remote_max_concurrent_streams (默认 100)
    public var maxConcurrentStreams: Int64
    /// 对应 Bun: remote_initial_window_size (默认 65535)
    public var initialWindowSize: Int64
    /// HPACK 动态表大小 - 对应 SETTINGS_HEADER_TABLE_SIZE
    public var headerTableSize: Int64
    /// 最大头部列表大小 - 对应 Bun local_max_header_list_size
    public var maxHeaderListSize: Int64
    /// 是否启用 server push
    public var enablePush: Bool

    public init() {
        maxFrameSize = 16384       // DEFAULT_MAX_FRAME_SIZE - 对应 Bun
        maxConcurrentStreams = 100  // 默认无限制，实际值从服务器 SETTINGS 获取
        initialWindowSize = 65535  // DEFAULT_WINDOW_SIZE = maxInt(u16)
        headerTableSize = 4096     // HPACK 默认动态表大小
        maxHeaderListSize = 262144 // 256KB - 对应 Bun local_max_header_list_size
        enablePush = false
    }

    /// 从 SETTINGS 帧负载解析参数
    /// 每个参数为 6 字节: 2 字节 ID + 4 字节 Value
    public static func parse(payload: Array<UInt8>): H2Settings {
        let settings = H2Settings()
        var i: Int64 = 0
        while (i + 6 <= payload.size) {
            let id = (Int64(payload[i]) << 8) | Int64(payload[i + 1])
            let value = (Int64(payload[i + 2]) << 24) | (Int64(payload[i + 3]) << 16) |
                        (Int64(payload[i + 4]) << 8) | Int64(payload[i + 5])

            match (id) {
                case 0x1 => settings.headerTableSize = value
                case 0x2 => settings.enablePush = value != 0
                case 0x3 => settings.maxConcurrentStreams = value
                case 0x4 => {
                    // INITIAL_WINDOW_SIZE: 0 to 2^31-1
                    if (value >= 0 && value <= 2147483647) {
                        settings.initialWindowSize = value
                    }
                }
                case 0x5 => {
                    // MAX_FRAME_SIZE: 16384 to 16777215
                    if (value >= 16384 && value <= 16777215) {
                        settings.maxFrameSize = value
                    }
                }
                case 0x6 => settings.maxHeaderListSize = value
                case _ => ()
            }
            i += 6
        }
        return settings
    }

    /// 序列化为 SETTINGS 帧负载
    public func serialize(): Array<UInt8> {
        let payload = Array<UInt8>()
        // HeaderTableSize
        appendSetting(payload, 0x1, headerTableSize)
        // EnablePush
        appendSetting(payload, 0x2, if (enablePush) { 1 } else { 0 })
        // MaxConcurrentStreams
        appendSetting(payload, 0x3, maxConcurrentStreams)
        // InitialWindowSize
        appendSetting(payload, 0x4, initialWindowSize)
        // MaxFrameSize
        appendSetting(payload, 0x5, maxFrameSize)
        // MaxHeaderListSize
        appendSetting(payload, 0x6, maxHeaderListSize)
        return payload
    }

    private static func appendSetting(payload: Array<UInt8>, id: Int64, value: Int64): Unit {
        payload.append(UInt8((id >> 8) & 0xFF))
        payload.append(UInt8(id & 0xFF))
        payload.append(UInt8((value >> 24) & 0xFF))
        payload.append(UInt8((value >> 16) & 0xFF))
        payload.append(UInt8((value >> 8) & 0xFF))
        payload.append(UInt8(value & 0xFF))
    }
}

// ============================================================================
// H2StreamState - HTTP/2 流状态
// 严格翻译自: src/http/h2_client/Stream.zig State
//   Bun: pub const State = enum(u2) { open, half_closed_local, half_closed_remote, closed }
//   对应 RFC 9113 §5.1 流状态机
// ============================================================================

/// HTTP/2 流状态 - 对应 RFC 9113 §5.1
public enum H2StreamState {
    | Open               // 双向开放
    | HalfClosedLocal    // 本端已半关闭 (已发送 END_STREAM)
    | HalfClosedRemote   // 对端已半关闭 (收到 END_STREAM)
    | Closed             // 完全关闭
    | Idle               // 保留 (Stream 对象创建前)
}

// ============================================================================
// H2Stream - HTTP/2 流
// 严格翻译自: src/http/h2_client/Stream.zig
//   Bun Stream: id, session, state, header_block, body_buffer,
//              decoded_headers, status_code, send_window, unacked_bytes
// ============================================================================

/// HTTP/2 流 - 对应 Bun h2_client/Stream.zig
/// 每个流代表一个独立的请求/响应对
public class H2Stream {
    /// 流 ID (31-bit) - 对应 Stream.id: u31
    public let id: Int64
    /// 流状态 - 对应 Stream.state
    public var state: H2StreamState
    /// 响应状态码 - 对应 Stream.status_code
    public var statusCode: Int64
    /// 请求头部 (待编码)
    public var requestHeaders: ArrayList<HeaderPair>
    /// 响应头部 (已解码) - 对应 Stream.decoded_headers
    public var responseHeaders: ArrayList<HeaderPair>
    /// 响应体缓冲 - 对应 Stream.body_buffer
    public var bodyBuffer: Array<UInt8>
    /// 流级别发送窗口 - 对应 Stream.send_window
    public var sendWindow: Int64
    /// 未确认接收字节数 - 对应 Stream.unacked_bytes
    public var unackedBytes: Int64
    /// 是否已发送 END_STREAM
    public var endStreamSent: Bool
    /// 是否收到 END_STREAM
    public var endStreamReceived: Bool
    /// 头部块暂存 (HEADERS + CONTINUATION 片段) - 对应 Stream.header_block
    public var headerBlock: Array<UInt8>

    public init(id: Int64) {
        this.id = id
        state = H2StreamState.Idle
        statusCode = 0
        requestHeaders = ArrayList<HeaderPair>()
        responseHeaders = ArrayList<HeaderPair>()
        bodyBuffer = Array<UInt8>()
        sendWindow = 65535  // 默认窗口大小
        unackedBytes = 0
        endStreamSent = false
        endStreamReceived = false
        headerBlock = Array<UInt8>()
    }

    /// 流是否已关闭
    public func isClosed(): Bool {
        return state == H2StreamState.Closed
    }

    /// 是否可以发送数据
    public func canSendData(): Bool {
        return state == H2StreamState.Open || state == H2StreamState.HalfClosedRemote
    }

    /// 是否可以接收数据
    public func canReceiveData(): Bool {
        return state == H2StreamState.Open || state == H2StreamState.HalfClosedLocal
    }

    /// 累积接收的 body 数据
    public func appendBody(data: Array<UInt8>): Unit {
        for (b in data) {
            bodyBuffer.append(b)
        }
        unackedBytes += data.size
    }

    /// 累积头部块片段 (用于 HEADERS + CONTINUATION 序列)
    public func appendHeaderBlock(data: Array<UInt8>): Unit {
        for (b in data) {
            headerBlock.append(b)
        }
    }

    /// 重置流状态
    public func reset(): Unit {
        state = H2StreamState.Closed
        requestHeaders = ArrayList<HeaderPair>()
        responseHeaders = ArrayList<HeaderPair>()
        bodyBuffer = Array<UInt8>()
        headerBlock = Array<UInt8>()
        unackedBytes = 0
        endStreamSent = false
        endStreamReceived = false
    }
}

// ============================================================================
// HpackEncoder / HpackDecoder - HPACK 头部压缩 (桩实现)
// 严格翻译自: src/http/lshpack.zig
//   Bun 使用 lshpack (LSHPACK) C 库实现 HPACK 编码/解码
//   HPACK 是 HTTP/2 的头部压缩算法 (RFC 7541)
//   使用静态表 + 动态表 + Huffman 编码
//   仓颉提供桩实现，后续可替换为 lshpack C FFI
// ============================================================================

/// HPACK 静态表 (RFC 7541 §Appendix A)
/// 包含 61 个常用头部字段的预定义映射
public class HpackStaticTable {
    /// 查找静态表条目
    /// 返回 (name, value) 对，index 从 1 开始
    public static func lookup(index: Int64): ?HeaderPair {
        // 静态表摘录 (完整 61 条，此处列出常用的)
        match (index) {
            case 1 => Some(HeaderPair(":authority", ""))
            case 2 => Some(HeaderPair(":method", "GET"))
            case 3 => Some(HeaderPair(":method", "POST"))
            case 4 => Some(HeaderPair(":path", "/"))
            case 5 => Some(HeaderPair(":path", "/index.html"))
            case 6 => Some(HeaderPair(":scheme", "http"))
            case 7 => Some(HeaderPair(":scheme", "https"))
            case 8 => Some(HeaderPair(":status", "200"))
            case 14 => Some(HeaderPair("accept-encoding", "gzip, deflate"))
            case 16 => Some(HeaderPair("connection", "keep-alive"))
            case 24 => Some(HeaderPair("content-length", ""))
            case 31 => Some(HeaderPair("host", ""))
            case 33 => Some(HeaderPair("location", ""))
            case 34 => Some(HeaderPair("referer", ""))
            case 38 => Some(HeaderPair("user-agent", ""))
            case 49 => Some(HeaderPair("date", ""))
            case 52 => Some(HeaderPair("server", ""))
            case _ => None
        }
    }

    /// 反向查找: 根据 name 查找静态表索引
    public static func findIndex(name: String, value: String): ?Int64 {
        let lower = name.toLower()
        match (lower) {
            case ":authority" => Some(1)
            case ":method" => {
                if (value == "GET") { return Some(2) }
                if (value == "POST") { return Some(3) }
                return None
            }
            case ":path" => {
                if (value == "/") { return Some(4) }
                if (value == "/index.html") { return Some(5) }
                return None
            }
            case ":scheme" => {
                if (value == "http") { return Some(6) }
                if (value == "https") { return Some(7) }
                return None
            }
            case ":status" => {
                if (value == "200") { return Some(8) }
                return None
            }
            case "host" => Some(31)
            case "user-agent" => Some(38)
            case "content-length" => Some(24)
            case "location" => Some(33)
            case "server" => Some(52)
            case _ => None
        }
    }
}

/// HPACK 编码器 - 对应 Bun lshpack.HPACK.encode
/// 桩实现: 使用字面量编码 (Literal Header Field without Indexing)
public class HpackEncoder {
    /// 动态表
    private var dynamicTable: ArrayList<HeaderPair>
    /// 动态表当前大小
    private var dynamicTableSize: Int64
    /// 动态表最大大小 - 对应 SETTINGS_HEADER_TABLE_SIZE
    private var maxDynamicTableSize: Int64

    public init() {
        dynamicTable = ArrayList<HeaderPair>()
        dynamicTableSize = 0
        maxDynamicTableSize = 4096
    }

    /// 设置动态表最大大小
    public func setMaxTableSize(size: Int64): Unit {
        maxDynamicTableSize = size
        evictEntries()
    }

    /// 编码头部列表 - 对应 lshpack hpack_enc_encode
    /// 返回编码后的字节块
    public func encode(headers: ArrayList<HeaderPair>): Array<UInt8> {
        let output = Array<UInt8>()

        for (h in headers) {
            // 查找静态表
            let staticIdx = HpackStaticTable.findIndex(h.name, h.value)
            match (staticIdx) {
                case Some(idx) => {
                    // Indexed Header Field (完全匹配)
                    encodeInteger(output, 0x80, 7, idx)
                }
                case None => {
                    // 查找仅名称匹配
                    let nameIdx = HpackStaticTable.findIndex(h.name, "")
                    match (nameIdx) {
                        case Some(idx) => {
                            // Literal Header Field with Incremental Indexing (名称索引)
                            encodeInteger(output, 0x40, 6, idx)
                            encodeString(output, h.value)
                        }
                        case None => {
                            // Literal Header Field without Indexing (新名称)
                            output.append(UInt8(0x00))
                            encodeString(output, h.name)
                            encodeString(output, h.value)
                        }
                    }
                }
            }
        }

        return output
    }

    /// HPACK 整数编码 (RFC 7541 §5.1)
    private static func encodeInteger(output: Array<UInt8>, prefixMask: UInt8,
                                       prefixBits: Int64, value: Int64): Unit {
        if (value < (1 << prefixBits) - 1) {
            output.append(UInt8(Int32(prefixMask) | Int32(value)))
        } else {
            output.append(UInt8(Int32(prefixMask) | Int32((1 << prefixBits) - 1)))
            var remaining = value - ((1 << prefixBits) - 1)
            while (remaining >= 128) {
                output.append(UInt8(Int32((remaining & 0x7F) | 0x80)))
                remaining = remaining >> 7
            }
            output.append(UInt8(Int32(remaining)))
        }
    }

    /// HPACK 字符串编码 (RFC 7541 §5.2)
    /// 桩实现: 使用原始字节 (bit 7 = 0 表示不使用 Huffman)
    private static func encodeString(output: Array<UInt8>, s: String): Unit {
        let bytes = stringToHpackBytes(s)
        encodeInteger(output, 0x00, 7, bytes.size)
        for (b in bytes) {
            output.append(b)
        }
    }

    private static func stringToHpackBytes(s: String): Array<UInt8> {
        let bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value & 0xFF))
        }
        return bytes
    }

    private func evictEntries(): Unit {
        while (dynamicTableSize > maxDynamicTableSize && dynamicTable.size > 0) {
            let entry = dynamicTable.removeAt(0)
            let entrySize = entry.name.size + entry.value.size + 32
            dynamicTableSize -= entrySize
        }
    }
}

/// HPACK 解码器 - 对应 Bun lshpack.HPACK.decode
/// 桩实现: 解码 Indexed / Literal Header Field
public class HpackDecoder {
    /// 动态表
    private var dynamicTable: ArrayList<HeaderPair>
    /// 动态表当前大小
    private var dynamicTableSize: Int64
    /// 动态表最大大小
    private var maxDynamicTableSize: Int64

    public init() {
        dynamicTable = ArrayList<HeaderPair>()
        dynamicTableSize = 0
        maxDynamicTableSize = 4096
    }

    /// 设置动态表最大大小
    public func setMaxTableSize(size: Int64): Unit {
        maxDynamicTableSize = size
    }

    /// 解码头部块 - 对应 lshpack hpack_dec_decode
    /// 输入 HPACK 编码的字节块，返回解码后的头部列表
    public func decode(block: Array<UInt8>): ?ArrayList<HeaderPair> {
        let headers = ArrayList<HeaderPair>()
        var pos: Int64 = 0

        while (pos < block.size) {
            let b = Int32(block[pos])

            if ((b & 0x80) != 0) {
                // Indexed Header Field (6.1)
                let indexResult = decodeInteger(block, pos, 7)
                match (indexResult) {
                    case Some(tuple) => {
                        let index = tuple.value
                        pos = tuple.nextPos
                        match (lookupHeader(index)) {
                            case Some(h) => headers.append(h)
                            case None => return None  // 无效索引
                        }
                    }
                    case None => return None
                }
            } else if ((b & 0xC0) == 0x40) {
                // Literal Header Field with Incremental Indexing (6.2.1)
                let indexResult = decodeInteger(block, pos, 6)
                match (indexResult) {
                    case Some(tuple) => {
                        pos = tuple.nextPos
                        let (name, value) = decodeLiteralHeader(block, pos, tuple.value)
                        match (name) {
                            case Some(n) => {
                                match (value) {
                                    case Some(v) => {
                                        headers.append(HeaderPair(n, v))
                                        addToDynamicTable(n, v)
                                        pos += n.size + v.size  // 简化位置追踪
                                    }
                                    case None => return None
                                }
                            }
                            case None => return None
                        }
                    }
                    case None => return None
                }
            } else if ((b & 0xF0) == 0x00) {
                // Literal Header Field without Indexing (6.2.2)
                let indexResult = decodeInteger(block, pos, 4)
                match (indexResult) {
                    case Some(tuple) => {
                        pos = tuple.nextPos
                        let (name, value) = decodeLiteralHeader(block, pos, tuple.value)
                        match (name) {
                            case Some(n) => {
                                match (value) {
                                    case Some(v) => {
                                        headers.append(HeaderPair(n, v))
                                    }
                                    case None => return None
                                }
                            }
                            case None => return None
                        }
                    }
                    case None => return None
                }
            } else {
                // 不支持的类型或 Dynamic Table Size Update
                pos += 1
            }
        }

        return Some(headers)
    }

    /// 查找头部条目 (静态表 + 动态表)
    private func lookupHeader(index: Int64): ?HeaderPair {
        // 静态表: 1-61
        if (index >= 1 && index <= 61) {
            return HpackStaticTable.lookup(index)
        }
        // 动态表: 62+ (相对于动态表头部的偏移)
        let dynamicIdx = index - 62
        if (dynamicIdx >= 0 && dynamicIdx < dynamicTable.size) {
            return Some(dynamicTable[dynamicIdx])
        }
        return None
    }

    /// 添加到动态表
    private func addToDynamicTable(name: String, value: String): Unit {
        let entry = HeaderPair(name, value)
        dynamicTable.append(entry)
        dynamicTableSize += name.size + value.size + 32

        while (dynamicTableSize > maxDynamicTableSize && dynamicTable.size > 0) {
            let evicted = dynamicTable.removeAt(0)
            dynamicTableSize -= evicted.name.size + evicted.value.size + 32
        }
    }

    /// HPACK 整数解码 (RFC 7541 §5.1)
    private static func decodeInteger(block: Array<UInt8>, pos: Int64,
                                       prefixBits: Int64): ?HpackIntResult {
        if (pos >= block.size) {
            return None
        }
        let mask = (1 << prefixBits) - 1
        var value = Int64(Int32(block[pos]) & mask)
        if (value < mask) {
            return Some(HpackIntResult(value, pos + 1))
        }
        var m: Int64 = 0
        var p = pos + 1
        while (p < block.size) {
            let b = Int64(block[p])
            value += (b & 0x7F) << m
            m += 7
            p += 1
            if ((b & 0x80) == 0) {
                break
            }
        }
        return Some(HpackIntResult(value, p))
    }

    /// 解码字面量头部 (简化)
    private static func decodeLiteralHeader(block: Array<UInt8>, pos: Int64,
                                             index: Int64): (?String, ?String) {
        // 简化桩实现
        if (index > 0) {
            let name = match (HpackStaticTable.lookup(index)) {
                case Some(h) => Some(h.name)
                case None => None
            }
            return (name, Some(""))  // 桩: 值解码省略
        }
        return (Some(""), Some(""))
    }
}

/// HPACK 整数解码结果
class HpackIntResult {
    var value: Int64
    var nextPos: Int64

    init(value: Int64, nextPos: Int64) {
        this.value = value
        this.nextPos = nextPos
    }
}

// ============================================================================
// H2ClientSession - HTTP/2 客户端会话
// 严格翻译自: src/http/h2_client/ClientSession.zig
//   Bun ClientSession 管理:
//   - TLS socket 连接
//   - HPACK 编码/解码器 (lshpack)
//   - 活跃 Stream 映射 (streams: AutoArrayHashMap)
//   - 下一个流 ID (next_stream_id: u31, 从 1 开始，每次 +2)
//   - 连接级发送窗口 (conn_send_window: i32)
//   - 远程 SETTINGS 参数
//   - 读取/写入缓冲区
// ============================================================================

/// HTTP/2 客户端会话 - 对应 Bun ClientSession
/// 管理单个 HTTP/2 连接上的所有流和状态
public class H2ClientSession {
    /// HPACK 编码器 - 对应 ClientSession.hpack encoder
    private var encoder: HpackEncoder
    /// HPACK 解码器 - 对应 ClientSession.hpack decoder
    private var decoder: HpackDecoder
    /// 活跃流映射 (stream ID -> Stream) - 对应 ClientSession.streams
    private var streams: HashMap<Int64, H2Stream>
    /// 下一个可用的客户端流 ID (奇数，从 1 开始) - 对应 next_stream_id
    private var nextStreamId: Int64
    /// 远端 SETTINGS - 对应 ClientSession.remote settings
    private var remoteSettings: H2Settings
    /// 本端 SETTINGS
    private var localSettings: H2Settings
    /// 连接级发送窗口 - 对应 ClientSession.conn_send_window
    private var connSendWindow: Int64
    /// 连接级未确认字节数 - 对应 ClientSession.conn_unacked_bytes
    private var connUnackedBytes: Int64
    /// 是否已发送连接预检 - 对应 ClientSession.preface_sent
    private var prefaceSent: Bool
    /// 是否已收到远端 SETTINGS - 对应 ClientSession.settings_received
    private var settingsReceived: Bool
    /// 是否收到 GOAWAY - 对应 ClientSession.goaway_received
    private var goawayReceived: Bool
    /// 写入缓冲区 - 对应 ClientSession.write_buffer
    private var writeBuffer: Array<UInt8>
    /// 读取缓冲区 - 对应 ClientSession.read_buffer
    private var readBuffer: Array<UInt8>
    /// 正在期待 CONTINUATION 帧的流 ID (0 = 无) - 对应 expecting_continuation
    private var expectingContinuation: Int64

    /// HTTP/2 客户端连接预检 - 对应 H2FrameParser.client_preface
    public static let CLIENT_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

    public init() {
        encoder = HpackEncoder()
        decoder = HpackDecoder()
        streams = HashMap<Int64, H2Stream>()
        nextStreamId = 1  // 客户端发起的流 ID 为奇数
        remoteSettings = H2Settings()
        localSettings = H2Settings()
        connSendWindow = 65535  // DEFAULT_WINDOW_SIZE
        connUnackedBytes = 0
        prefaceSent = false
        settingsReceived = false
        goawayReceived = false
        writeBuffer = Array<UInt8>()
        readBuffer = Array<UInt8>()
        expectingContinuation = 0
    }

    /// 创建新流 - 对应 ClientSession 中 HTTPClient 发起请求时的流程
    /// 返回新分配的流，或 None 如果达到最大并发流数
    public func newStream(): ?H2Stream {
        let activeCount = activeStreamCount()
        if (activeCount >= remoteSettings.maxConcurrentStreams) {
            return None  // 达到最大并发流数
        }

        let streamId = nextStreamId
        nextStreamId += 2  // 客户端流 ID 递增 2

        let stream = H2Stream(streamId)
        stream.state = H2StreamState.Open
        streams.put(streamId, stream)
        return stream
    }

    /// 获取活跃流数量
    public func activeStreamCount(): Int64 {
        var count: Int64 = 0
        for (key in streams.keys()) {
            match (streams.get(key)) {
                case Some(s) => {
                    if (s.state != H2StreamState.Closed && s.state != H2StreamState.Idle) {
                        count += 1
                    }
                }
                case None => ()
            }
        }
        return count
    }

    /// 获取流
    public func getStream(id: Int64): ?H2Stream {
        return streams.get(id)
    }

    /// 移除关闭的流
    public func removeStream(id: Int64): Unit {
        streams.remove(id)
    }

    // ========================================================================
    // 帧构建 - 对应 ClientSession 中的 write* 方法
    // ========================================================================

    /// 构建连接预检 - 对应 ClientSession 发送 client_preface
    public func buildPreface(): Array<UInt8> {
        let preface = Array<UInt8>()
        for (c in CLIENT_PREFACE) {
            preface.append(UInt8(c.value & 0xFF))
        }
        return preface
    }

    /// 构建 SETTINGS 帧 - 对应 ClientSession 发送本地 SETTINGS
    public func buildSettingsFrame(): Array<UInt8> {
        let settingsPayload = localSettings.serialize()
        let frame = H2Frame()
        frame.length = settingsPayload.size
        frame.frameType = H2FrameType.Settings
        frame.flags = 0
        frame.streamId = 0
        frame.payload = settingsPayload

        let header = frame.serializeHeader()
        let result = Array<UInt8>()
        for (b in header) { result.append(b) }
        for (b in settingsPayload) { result.append(b) }
        return result
    }

    /// 构建 SETTINGS ACK 帧
    public func buildSettingsAck(): Array<UInt8> {
        let frame = H2Frame()
        frame.length = 0
        frame.frameType = H2FrameType.Settings
        frame.flags = H2SettingsFlags.ACK
        frame.streamId = 0
        return frame.serializeHeader()
    }

    /// 构建 HEADERS 帧
    /// 对应 ClientSession.writeRequest: 编码头部 + 构建帧
    public func buildHeadersFrame(streamId: Int64, headers: ArrayList<HeaderPair>,
                                   endStream: Bool): Array<UInt8> {
        let encoded = encoder.encode(headers)
        let frame = H2Frame()
        frame.length = encoded.size
        frame.frameType = H2FrameType.Headers
        frame.flags = H2HeadersFlags.END_HEADERS | (if (endStream) { H2HeadersFlags.END_STREAM } else { 0 })
        frame.streamId = streamId
        frame.payload = encoded

        let header = frame.serializeHeader()
        let result = Array<UInt8>()
        for (b in header) { result.append(b) }
        for (b in encoded) { result.append(b) }
        return result
    }

    /// 构建 DATA 帧
    public func buildDataFrame(streamId: Int64, data: Array<UInt8>,
                                endStream: Bool): Array<UInt8> {
        let frame = H2Frame()
        frame.length = data.size
        frame.frameType = H2FrameType.Data
        frame.flags = if (endStream) { H2DataFlags.END_STREAM } else { 0 }
        frame.streamId = streamId
        frame.payload = data

        let header = frame.serializeHeader()
        let result = Array<UInt8>()
        for (b in header) { result.append(b) }
        for (b in data) { result.append(b) }
        return result
    }

    /// 构建 WINDOW_UPDATE 帧
    /// 对应 RFC 9113 §6.9: 流量控制窗口递增
    public func buildWindowUpdateFrame(streamId: Int64, increment: Int64): Array<UInt8> {
        let payload = Array<UInt8>(4, item: UInt8(0))
        // 31-bit window size increment (R=0)
        payload[0] = UInt8((increment >> 24) & 0x7F)
        payload[1] = UInt8((increment >> 16) & 0xFF)
        payload[2] = UInt8((increment >> 8) & 0xFF)
        payload[3] = UInt8(increment & 0xFF)

        let frame = H2Frame()
        frame.length = 4
        frame.frameType = H2FrameType.WindowUpdate
        frame.flags = 0
        frame.streamId = streamId
        frame.payload = payload

        let header = frame.serializeHeader()
        let result = Array<UInt8>()
        for (b in header) { result.append(b) }
        for (b in payload) { result.append(b) }
        return result
    }

    /// 构建 PING 帧 (8 字节 opaque data)
    public func buildPingFrame(opaqueData: Array<UInt8>, ack: Bool): Array<UInt8> {
        let frame = H2Frame()
        frame.length = 8
        frame.frameType = H2FrameType.Ping
        frame.flags = if (ack) { H2PingFlags.ACK } else { 0 }
        frame.streamId = 0
        frame.payload = opaqueData

        let header = frame.serializeHeader()
        let result = Array<UInt8>()
        for (b in header) { result.append(b) }
        for (b in opaqueData) { result.append(b) }
        return result
    }

    /// 构建 GOAWAY 帧
    /// 对应 RFC 9113 §6.8: 通知对端停止创建新流
    public func buildGoawayFrame(lastStreamId: Int64, errorCode: H2ErrorCode): Array<UInt8> {
        let payload = Array<UInt8>(8, item: UInt8(0))
        // Last-Stream-ID (31-bit, R=0)
        payload[0] = UInt8((lastStreamId >> 24) & 0x7F)
        payload[1] = UInt8((lastStreamId >> 16) & 0xFF)
        payload[2] = UInt8((lastStreamId >> 8) & 0xFF)
        payload[3] = UInt8(lastStreamId & 0xFF)
        // Error Code (32-bit)
        let ec = errorCode.code()
        payload[4] = UInt8((ec >> 24) & 0xFF)
        payload[5] = UInt8((ec >> 16) & 0xFF)
        payload[6] = UInt8((ec >> 8) & 0xFF)
        payload[7] = UInt8(ec & 0xFF)

        let frame = H2Frame()
        frame.length = 8
        frame.frameType = H2FrameType.Goaway
        frame.flags = 0
        frame.streamId = 0
        frame.payload = payload

        let header = frame.serializeHeader()
        let result = Array<UInt8>()
        for (b in header) { result.append(b) }
        for (b in payload) { result.append(b) }
        return result
    }

    /// 构建 RST_STREAM 帧
    public func buildRstStreamFrame(streamId: Int64, errorCode: H2ErrorCode): Array<UInt8> {
        let payload = Array<UInt8>(4, item: UInt8(0))
        let ec = errorCode.code()
        payload[0] = UInt8((ec >> 24) & 0xFF)
        payload[1] = UInt8((ec >> 16) & 0xFF)
        payload[2] = UInt8((ec >> 8) & 0xFF)
        payload[3] = UInt8(ec & 0xFF)

        let frame = H2Frame()
        frame.length = 4
        frame.frameType = H2FrameType.RstStream
        frame.flags = 0
        frame.streamId = streamId
        frame.payload = payload

        let header = frame.serializeHeader()
        let result = Array<UInt8>()
        for (b in header) { result.append(b) }
        for (b in payload) { result.append(b) }
        return result
    }

    // ========================================================================
    // 帧分发 - 对应 ClientSession.dispatchFrame
    // ========================================================================

    /// 处理接收到的帧
    /// 对应 ClientSession 中 onData -> parseFrameHeader -> dispatchFrame 流程
    public func handleFrame(frame: H2Frame): Unit {
        match (frame.frameType) {
            case H2FrameType.Data => handleDataFrame(frame)
            case H2FrameType.Headers => handleHeadersFrame(frame)
            case H2FrameType.Priority => ()  // Priority 通常被忽略
            case H2FrameType.RstStream => handleRstStreamFrame(frame)
            case H2FrameType.Settings => handleSettingsFrame(frame)
            case H2FrameType.PushPromise => ()  // 客户端不处理 PUSH_PROMISE
            case H2FrameType.Ping => ()  // PING 需要回复 ACK
            case H2FrameType.Goaway => handleGoawayFrame(frame)
            case H2FrameType.WindowUpdate => handleWindowUpdateFrame(frame)
            case H2FrameType.Continuation => handleContinuationFrame(frame)
            case H2FrameType.Unknown(_) => ()  // 忽略未知帧类型
        }
    }

    /// 处理 DATA 帧 - 对应 ClientSession 中 DATA 分发到 stream
    private func handleDataFrame(frame: H2Frame): Unit {
        match (streams.get(frame.streamId)) {
            case Some(stream) => {
                stream.appendBody(frame.payload)
                connUnackedBytes += frame.payload.size

                if (frame.hasFlag(H2DataFlags.END_STREAM)) {
                    stream.endStreamReceived = true
                    stream.state = H2StreamState.HalfClosedRemote
                    if (stream.endStreamSent) {
                        stream.state = H2StreamState.Closed
                    }
                }

                // 检查是否需要发送 WINDOW_UPDATE
                // 对应 ClientSession 中窗口更新逻辑
                if (connUnackedBytes > remoteSettings.initialWindowSize / 2) {
                    // 需要发送连接级 WINDOW_UPDATE
                    connUnackedBytes = 0
                }
            }
            case None => ()  // 未知流，忽略
        }
    }

    /// 处理 HEADERS 帧 - 对应 ClientSession 头部解码流程
    private func handleHeadersFrame(frame: H2Frame): Unit {
        match (streams.get(frame.streamId)) {
            case Some(stream) => {
                stream.appendHeaderBlock(frame.payload)

                if (frame.hasFlag(H2HeadersFlags.END_HEADERS)) {
                    // 完整头部块已收到，解码
                    let decoded = decoder.decode(stream.headerBlock)
                    match (decoded) {
                        case Some(headers) => {
                            stream.responseHeaders = headers
                            // 提取 :status 伪头部
                            for (h in headers) {
                                if (h.name == ":status") {
                                    try {
                                        stream.statusCode = Int64.parse(h.value)
                                    } catch (_: Exception) {
                                        stream.statusCode = 0
                                    }
                                }
                            }
                            stream.headerBlock = Array<UInt8>()
                        }
                        case None => ()  // 解码失败
                    }
                } else {
                    // 期待 CONTINUATION 帧
                    expectingContinuation = frame.streamId
                }

                if (frame.hasFlag(H2HeadersFlags.END_STREAM)) {
                    stream.endStreamReceived = true
                }
            }
            case None => ()  // 未知流
        }
    }

    /// 处理 RST_STREAM 帧
    private func handleRstStreamFrame(frame: H2Frame): Unit {
        match (streams.get(frame.streamId)) {
            case Some(stream) => {
                stream.state = H2StreamState.Closed
                streams.remove(frame.streamId)
            }
            case None => ()
        }
    }

    /// 处理 SETTINGS 帧
    private func handleSettingsFrame(frame: H2Frame): Unit {
        if (frame.hasFlag(H2SettingsFlags.ACK)) {
            // SETTINGS ACK - 对远端 SETTINGS 的确认
            return
        }
        // 更新远端 SETTINGS
        remoteSettings = H2Settings.parse(frame.payload)
        decoder.setMaxTableSize(remoteSettings.headerTableSize)
        settingsReceived = true
    }

    /// 处理 GOAWAY 帧
    private func handleGoawayFrame(frame: H2Frame): Unit {
        goawayReceived = true
        // 关闭所有高于 lastStreamId 的流
        if (frame.payload.size >= 8) {
            let lastStreamId = (Int64(frame.payload[0]) << 24) | (Int64(frame.payload[1]) << 16) |
                               (Int64(frame.payload[2]) << 8) | Int64(frame.payload[3])
            for (key in streams.keys()) {
                if (key > lastStreamId) {
                    match (streams.get(key)) {
                        case Some(stream) => stream.state = H2StreamState.Closed
                        case None => ()
                    }
                    streams.remove(key)
                }
            }
        }
    }

    /// 处理 WINDOW_UPDATE 帧
    private func handleWindowUpdateFrame(frame: H2Frame): Unit {
        if (frame.payload.size < 4) {
            return
        }
        let increment = (Int64(frame.payload[0]) & 0x7F) << 24 |
                        Int64(frame.payload[1]) << 16 |
                        Int64(frame.payload[2]) << 8 |
                        Int64(frame.payload[3])

        if (frame.streamId == 0) {
            // 连接级窗口更新
            connSendWindow += increment
        } else {
            // 流级窗口更新
            match (streams.get(frame.streamId)) {
                case Some(stream) => stream.sendWindow += increment
                case None => ()
            }
        }
    }

    /// 处理 CONTINUATION 帧
    private func handleContinuationFrame(frame: H2Frame): Unit {
        match (streams.get(frame.streamId)) {
            case Some(stream) => {
                stream.appendHeaderBlock(frame.payload)

                if (frame.hasFlag(H2HeadersFlags.END_HEADERS)) {
                    expectingContinuation = 0
                    let decoded = decoder.decode(stream.headerBlock)
                    match (decoded) {
                        case Some(headers) => {
                            stream.responseHeaders = headers
                            for (h in headers) {
                                if (h.name == ":status") {
                                    try {
                                        stream.statusCode = Int64.parse(h.value)
                                    } catch (_: Exception) {
                                        stream.statusCode = 0
                                    }
                                }
                            }
                            stream.headerBlock = Array<UInt8>()
                        }
                        case None => ()
                    }
                }
            }
            case None => ()
        }
    }

    /// 是否已关闭
    public func isClosed(): Bool {
        return goawayReceived
    }

    /// 获取远端 SETTINGS
    public func getRemoteSettings(): H2Settings {
        return remoteSettings
    }

    /// 获取连接级发送窗口
    public func getConnSendWindow(): Int64 {
        return connSendWindow
    }
}
