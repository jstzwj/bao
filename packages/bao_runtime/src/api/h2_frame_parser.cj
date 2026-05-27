// 严格翻译自: src/runtime/api/bun/h2_frame_parser.rs
package bao_runtime.api

import bao_jsc.*
import bao_collections.ArrayList
import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*

// ============================================================================
// h2_frame_parser - HTTP/2 帧解析器
// 对应 Bun: src/runtime/api/bun/h2_frame_parser.rs
// ============================================================================

// ============================================================================
// 常量
// ============================================================================

let MAX_PAYLOAD_SIZE_WITHOUT_FRAME: Int = 16384 - 9 - 1
let MAX_WINDOW_SIZE: UInt32 = UInt32(Int32.maxValue)
let MAX_HEADER_TABLE_SIZE: UInt32 = UInt32.maxValue
let MAX_STREAM_ID: UInt32 = UInt32(Int32.maxValue)
let MAX_FRAME_SIZE: UInt32 = 0x00FFFFFF
let DEFAULT_WINDOW_SIZE: UInt64 = UInt64(UInt16.maxValue)
let MAX_WINDOW_SIZE_F64: Float64 = Float64(MAX_WINDOW_SIZE)
let MAX_HEADER_TABLE_SIZE_F64: Float64 = Float64(MAX_HEADER_TABLE_SIZE)
let MAX_FRAME_SIZE_F64: Float64 = Float64(MAX_FRAME_SIZE)
let HPACK_ENTRY_OVERHEAD: Int = 32
let MAX_CUSTOM_SETTINGS: Int = 10
let MAX_CUSTOM_SETTING_ID: Float64 = 0xFFFF
let ENABLE_AUTO_CORK: Bool = false
let ENABLE_ALLOCATOR_POOL: Bool = true
let MAX_BUFFER_SIZE: UInt32 = 32768
let SINGLE_VALUE_HEADERS_LEN: Int = 40

// ============================================================================
// 填充策略
// ============================================================================

public enum PaddingStrategy {
    | None
    | Aligned
    | Max
}

// ============================================================================
// 帧类型
// ============================================================================

public enum FrameType {
    | data(UInt8)
    | headers(UInt8)
    | priority(UInt8)
    | rstStream(UInt8)
    | settings(UInt8)
    | pushPromise(UInt8)
    | ping(UInt8)
    | goaway(UInt8)
    | windowUpdate(UInt8)
    | continuation(UInt8)
    | altsvc(UInt8)
    | origin(UInt8)

    public static func fromValue(value: UInt8): FrameType {
        match (value) {
            case 0x00 => FrameType.data(0x00)
            case 0x01 => FrameType.headers(0x01)
            case 0x02 => FrameType.priority(0x02)
            case 0x03 => FrameType.rstStream(0x03)
            case 0x04 => FrameType.settings(0x04)
            case 0x05 => FrameType.pushPromise(0x05)
            case 0x06 => FrameType.ping(0x06)
            case 0x07 => FrameType.goaway(0x07)
            case 0x08 => FrameType.windowUpdate(0x08)
            case 0x09 => FrameType.continuation(0x09)
            case 0x0A => FrameType.altsvc(0x0A)
            case 0x0C => FrameType.origin(0x0C)
            case _ => FrameType.data(value)
        }
    }

    public func toUInt8(): UInt8 {
        match (this) {
            case data(v) => v
            case headers(v) => v
            case priority(v) => v
            case rstStream(v) => v
            case settings(v) => v
            case pushPromise(v) => v
            case ping(v) => v
            case goaway(v) => v
            case windowUpdate(v) => v
            case continuation(v) => v
            case altsvc(v) => v
            case origin(v) => v
        }
    }
}

// ============================================================================
// Ping 帧标志
// ============================================================================

public enum PingFrameFlags {
    | ack
}

// ============================================================================
// Data 帧标志
// ============================================================================

public enum DataFrameFlags {
    | endStream
    | padded
}

// ============================================================================
// Headers 帧标志
// ============================================================================

public enum HeadersFrameFlags {
    | endStream
    | endHeaders
    | padded
    | priority
}

// ============================================================================
// Settings 帧标志
// ============================================================================

public enum SettingsFlags {
    | ack
}

// ============================================================================
// 错误码 (非穷举枚举 — newtype over UInt32)
// ============================================================================

public class ErrorCode {
    public var value: UInt32

    public init(value: UInt32) {
        this.value = value
    }

    public static let NO_ERROR = ErrorCode(value: 0x0)
    public static let PROTOCOL_ERROR = ErrorCode(value: 0x1)
    public static let INTERNAL_ERROR = ErrorCode(value: 0x2)
    public static let FLOW_CONTROL_ERROR = ErrorCode(value: 0x3)
    public static let SETTINGS_TIMEOUT = ErrorCode(value: 0x4)
    public static let STREAM_CLOSED = ErrorCode(value: 0x5)
    public static let FRAME_SIZE_ERROR = ErrorCode(value: 0x6)
    public static let REFUSED_STREAM = ErrorCode(value: 0x7)
    public static let CANCEL = ErrorCode(value: 0x8)
    public static let COMPRESSION_ERROR = ErrorCode(value: 0x9)
    public static let CONNECT_ERROR = ErrorCode(value: 0xa)
    public static let ENHANCE_YOUR_CALM = ErrorCode(value: 0xb)
    public static let INADEQUATE_SECURITY = ErrorCode(value: 0xc)
    public static let HTTP_1_1_REQUIRED = ErrorCode(value: 0xd)
    public static let MAX_PENDING_SETTINGS_ACK = ErrorCode(value: 0xe)

    public func equals(other: ErrorCode): Bool {
        this.value == other.value
    }
}

// ============================================================================
// 设置类型 (非穷举枚举 — newtype over UInt16)
// ============================================================================

public class SettingsType {
    public var value: UInt16

    public init(value: UInt16) {
        this.value = value
    }

    public static let SETTINGS_HEADER_TABLE_SIZE = SettingsType(value: 0x1)
    public static let SETTINGS_ENABLE_PUSH = SettingsType(value: 0x2)
    public static let SETTINGS_MAX_CONCURRENT_STREAMS = SettingsType(value: 0x3)
    public static let SETTINGS_INITIAL_WINDOW_SIZE = SettingsType(value: 0x4)
    public static let SETTINGS_MAX_FRAME_SIZE = SettingsType(value: 0x5)
    public static let SETTINGS_MAX_HEADER_LIST_SIZE = SettingsType(value: 0x6)
    public static let SETTINGS_ENABLE_CONNECT_PROTOCOL = SettingsType(value: 0x8)
    public static let SETTINGS_NO_RFC7540_PRIORITIES = SettingsType(value: 0x9)
}

// ============================================================================
// 辅助函数
// ============================================================================

func u32FromBytes(src: Array<UInt8>): UInt32 {
    (UInt32(src[0]) << 24) | (UInt32(src[1]) << 16) | (UInt32(src[2]) << 8) | UInt32(src[3])
}

/// 判断是否为有效的响应伪头部
func isValidResponsePseudoHeader(name: Array<UInt8>): Bool {
    name.size == 7 && name[0] == UInt8(':') && name[1] == UInt8('s') &&
        name[2] == UInt8('t') && name[3] == UInt8('a') && name[4] == UInt8('t') &&
        name[5] == UInt8('u') && name[6] == UInt8('s')
}

/// 判断是否为有效的请求伪头部
func isValidRequestPseudoHeader(name: Array<UInt8>): Bool {
    if (name.size == 5) {
        return name[0] == UInt8(':') && name[1] == UInt8('p') && name[2] == UInt8('a') &&
               name[3] == UInt8('t') && name[4] == UInt8('h')
    }
    if (name.size == 7) {
        let isMethod = name[1] == UInt8('m') && name[2] == UInt8('e') && name[3] == UInt8('t') &&
                       name[4] == UInt8('h') && name[5] == UInt8('o') && name[6] == UInt8('d')
        let isScheme = name[1] == UInt8('s') && name[2] == UInt8('c') && name[3] == UInt8('h') &&
                       name[4] == UInt8('e') && name[5] == UInt8('m') && name[6] == UInt8('e')
        return isMethod || isScheme
    }
    if (name.size == 9) {
        return name[1] == UInt8('p') && name[2] == UInt8('r') && name[3] == UInt8('o') &&
               name[4] == UInt8('t') && name[5] == UInt8('o') && name[6] == UInt8('c') &&
               name[7] == UInt8('o') && name[8] == UInt8('l')
    }
    if (name.size == 10) {
        return name[1] == UInt8('a') && name[2] == UInt8('u') && name[3] == UInt8('t') &&
               name[4] == UInt8('h') && name[5] == UInt8('o') && name[6] == UInt8('r') &&
               name[7] == UInt8('i') && name[8] == UInt8('t') && name[9] == UInt8('y')
    }
    false
}

/// 单值头部索引查找
func singleValueHeadersIndexOf(name: Array<UInt8>): ?Int {
    match (name.size) {
        case 2 => if (name[0] == UInt8('t') && name[1] == UInt8('k')) { 36 } else { none }
        case 3 =>
            if (name[0] == UInt8('a') && name[1] == UInt8('g') && name[2] == UInt8('e')) { 9 }
            else if (name[0] == UInt8('d') && name[1] == UInt8('n') && name[2] == UInt8('t')) { 19 }
            else { none }
        case 4 =>
            if (name[0] == UInt8('d') && name[1] == UInt8('a') && name[2] == UInt8('t') && name[3] == UInt8('e')) { 18 }
            else if (name[0] == UInt8('e') && name[1] == UInt8('t') && name[2] == UInt8('a') && name[3] == UInt8('g')) { 20 }
            else if (name[0] == UInt8('f') && name[1] == UInt8('r') && name[2] == UInt8('o') && name[3] == UInt8('m')) { 22 }
            else if (name[0] == UInt8('h') && name[1] == UInt8('o') && name[2] == UInt8('s') && name[3] == UInt8('t')) { 23 }
            else { none }
        case 5 =>
            if (name[0] == UInt8(':') && name[1] == UInt8('p') && name[2] == UInt8('a') && name[3] == UInt8('t') && name[4] == UInt8('h')) { 4 }
            else if (name[0] == UInt8('r') && name[1] == UInt8('a') && name[2] == UInt8('n') && name[3] == UInt8('g') && name[4] == UInt8('e')) { 33 }
            else { none }
        case 7 =>
            if (name[0] == UInt8(':') && name[1] == UInt8('s') && name[2] == UInt8('t') && name[3] == UInt8('a') && name[4] == UInt8('t') && name[5] == UInt8('u') && name[6] == UInt8('s')) { 0 }
            else if (name[0] == UInt8(':') && name[1] == UInt8('m') && name[2] == UInt8('e') && name[3] == UInt8('t') && name[4] == UInt8('h') && name[5] == UInt8('o') && name[6] == UInt8('d')) { 1 }
            else if (name[0] == UInt8(':') && name[1] == UInt8('s') && name[2] == UInt8('c') && name[3] == UInt8('h') && name[4] == UInt8('e') && name[5] == UInt8('m') && name[6] == UInt8('e')) { 3 }
            else if (name[0] == UInt8('e') && name[1] == UInt8('x') && name[2] == UInt8('p') && name[3] == UInt8('i') && name[4] == UInt8('r') && name[5] == UInt8('e') && name[6] == UInt8('s')) { 21 }
            else if (name[0] == UInt8('r') && name[1] == UInt8('e') && name[2] == UInt8('f') && name[3] == UInt8('e') && name[4] == UInt8('r') && name[5] == UInt8('e') && name[6] == UInt8('r')) { 34 }
            else { none }
        case 8 =>
            if (name[0] == UInt8('i') && name[1] == UInt8('f') && name[2] == UInt8('-') && name[3] == UInt8('m') && name[4] == UInt8('a') && name[5] == UInt8('t') && name[6] == UInt8('c') && name[7] == UInt8('h')) { 24 }
            else if (name[0] == UInt8('i') && name[1] == UInt8('f') && name[2] == UInt8('-') && name[3] == UInt8('r') && name[4] == UInt8('a') && name[5] == UInt8('n') && name[6] == UInt8('g') && name[7] == UInt8('e')) { 27 }
            else if (name[0] == UInt8('l') && name[1] == UInt8('o') && name[2] == UInt8('c') && name[3] == UInt8('a') && name[4] == UInt8('t') && name[5] == UInt8('i') && name[6] == UInt8('o') && name[7] == UInt8('n')) { 30 }
            else { none }
        case 9 =>
            if (name[0] == UInt8(':') && name[1] == UInt8('p') && name[2] == UInt8('r') && name[3] == UInt8('o') && name[4] == UInt8('t') && name[5] == UInt8('o') && name[6] == UInt8('c') && name[7] == UInt8('o') && name[8] == UInt8('l')) { 5 }
            else { none }
        case 10 =>
            if (name[0] == UInt8(':') && name[1] == UInt8('a') && name[2] == UInt8('u') && name[3] == UInt8('t') && name[4] == UInt8('h') && name[5] == UInt8('o') && name[6] == UInt8('r') && name[7] == UInt8('i') && name[8] == UInt8('t') && name[9] == UInt8('y')) { 2 }
            else if (name[0] == UInt8('u') && name[1] == UInt8('s') && name[2] == UInt8('e') && name[3] == UInt8('r') && name[4] == UInt8('-') && name[5] == UInt8('a') && name[6] == UInt8('g') && name[7] == UInt8('e') && name[8] == UInt8('n') && name[9] == UInt8('t')) { 38 }
            else { none }
        case 11 =>
            if (name[0] == UInt8('c') && name[1] == UInt8('o') && name[2] == UInt8('n') && name[3] == UInt8('t') && name[4] == UInt8('e') && name[5] == UInt8('n') && name[6] == UInt8('t') && name[7] == UInt8('-') && name[8] == UInt8('m') && name[9] == UInt8('d') && name[10] == UInt8('5')) { 15 }
            else if (name[0] == UInt8('r') && name[1] == UInt8('e') && name[2] == UInt8('t') && name[3] == UInt8('r') && name[4] == UInt8('y') && name[5] == UInt8('-') && name[6] == UInt8('a') && name[7] == UInt8('f') && name[8] == UInt8('t') && name[9] == UInt8('e') && name[10] == UInt8('r')) { 35 }
            else { none }
        case 12 =>
            if (name[0] == UInt8('c') && name[1] == UInt8('o') && name[2] == UInt8('n') && name[3] == UInt8('t') && name[4] == UInt8('e') && name[5] == UInt8('n') && name[6] == UInt8('t') && name[7] == UInt8('-') && name[8] == UInt8('t') && name[9] == UInt8('y') && name[10] == UInt8('p') && name[11] == UInt8('e')) { 17 }
            else if (name[0] == UInt8('m') && name[1] == UInt8('a') && name[2] == UInt8('x') && name[3] == UInt8('-') && name[4] == UInt8('f') && name[5] == UInt8('o') && name[6] == UInt8('r') && name[7] == UInt8('w') && name[8] == UInt8('a') && name[9] == UInt8('r') && name[10] == UInt8('d') && name[11] == UInt8('s')) { 31 }
            else { none }
        case 13 =>
            if (name[0] == UInt8('a') && name[1] == UInt8('u') && name[2] == UInt8('t') && name[3] == UInt8('h') && name[4] == UInt8('o') && name[5] == UInt8('r') && name[6] == UInt8('i') && name[7] == UInt8('z') && name[8] == UInt8('a') && name[9] == UInt8('t') && name[10] == UInt8('i') && name[11] == UInt8('o') && name[12] == UInt8('n')) { 10 }
            else if (name[0] == UInt8('c') && name[1] == UInt8('o') && name[2] == UInt8('n') && name[3] == UInt8('t') && name[4] == UInt8('e') && name[5] == UInt8('n') && name[6] == UInt8('t') && name[7] == UInt8('-') && name[8] == UInt8('r') && name[9] == UInt8('a') && name[10] == UInt8('n') && name[11] == UInt8('g') && name[12] == UInt8('e')) { 16 }
            else if (name[0] == UInt8('i') && name[1] == UInt8('f') && name[2] == UInt8('-') && name[3] == UInt8('n') && name[4] == UInt8('o') && name[5] == UInt8('n') && name[6] == UInt8('e') && name[7] == UInt8('-') && name[8] == UInt8('m') && name[9] == UInt8('a') && name[10] == UInt8('t') && name[11] == UInt8('c') && name[12] == UInt8('h')) { 26 }
            else if (name[0] == UInt8('l') && name[1] == UInt8('a') && name[2] == UInt8('s') && name[3] == UInt8('t') && name[4] == UInt8('-') && name[5] == UInt8('m') && name[6] == UInt8('o') && name[7] == UInt8('d') && name[8] == UInt8('i') && name[9] == UInt8('f') && name[10] == UInt8('i') && name[11] == UInt8('e') && name[12] == UInt8('d')) { 29 }
            else { none }
        case 14 =>
            if (name[0] == UInt8('c') && name[1] == UInt8('o') && name[2] == UInt8('n') && name[3] == UInt8('t') && name[4] == UInt8('e') && name[5] == UInt8('n') && name[6] == UInt8('t') && name[7] == UInt8('-') && name[8] == UInt8('l') && name[9] == UInt8('e') && name[10] == UInt8('n') && name[11] == UInt8('g') && name[12] == UInt8('t') && name[13] == UInt8('h')) { 13 }
            else { none }
        case 16 =>
            if (name[0] == UInt8('c') && name[1] == UInt8('o') && name[2] == UInt8('n') && name[3] == UInt8('t') && name[4] == UInt8('e') && name[5] == UInt8('n') && name[6] == UInt8('t') && name[7] == UInt8('-') && name[8] == UInt8('e') && name[9] == UInt8('n') && name[10] == UInt8('c') && name[11] == UInt8('o') && name[12] == UInt8('d') && name[13] == UInt8('i') && name[14] == UInt8('n') && name[15] == UInt8('g')) { 11 }
            else if (name[0] == UInt8('c') && name[1] == UInt8('o') && name[2] == UInt8('n') && name[3] == UInt8('t') && name[4] == UInt8('e') && name[5] == UInt8('n') && name[6] == UInt8('t') && name[7] == UInt8('-') && name[8] == UInt8('l') && name[9] == UInt8('a') && name[10] == UInt8('n') && name[11] == UInt8('g') && name[12] == UInt8('u') && name[13] == UInt8('a') && name[14] == UInt8('g') && name[15] == UInt8('e')) { 12 }
            else if (name[0] == UInt8('c') && name[1] == UInt8('o') && name[2] == UInt8('n') && name[3] == UInt8('t') && name[4] == UInt8('e') && name[5] == UInt8('n') && name[6] == UInt8('t') && name[7] == UInt8('-') && name[8] == UInt8('l') && name[9] == UInt8('o') && name[10] == UInt8('c') && name[11] == UInt8('a') && name[12] == UInt8('t') && name[13] == UInt8('i') && name[14] == UInt8('o') && name[15] == UInt8('n')) { 14 }
            else { none }
        case 17 =>
            if (name[0] == UInt8('i') && name[1] == UInt8('f') && name[2] == UInt8('-') && name[3] == UInt8('m') && name[4] == UInt8('o') && name[5] == UInt8('d') && name[6] == UInt8('i') && name[7] == UInt8('f') && name[8] == UInt8('i') && name[9] == UInt8('e') && name[10] == UInt8('d') && name[11] == UInt8('-') && name[12] == UInt8('s') && name[13] == UInt8('i') && name[14] == UInt8('n') && name[15] == UInt8('c') && name[16] == UInt8('e')) { 25 }
            else { none }
        case 19 =>
            if (name[0] == UInt8('i') && name[1] == UInt8('f') && name[2] == UInt8('-') && name[3] == UInt8('u') && name[4] == UInt8('n') && name[5] == UInt8('m') && name[6] == UInt8('o') && name[7] == UInt8('d') && name[8] == UInt8('i') && name[9] == UInt8('f') && name[10] == UInt8('i') && name[11] == UInt8('e') && name[12] == UInt8('d') && name[13] == UInt8('-') && name[14] == UInt8('s') && name[15] == UInt8('i') && name[16] == UInt8('n') && name[17] == UInt8('c') && name[18] == UInt8('e')) { 28 }
            else if (name[0] == UInt8('p') && name[1] == UInt8('r') && name[2] == UInt8('o') && name[3] == UInt8('x') && name[4] == UInt8('y') && name[5] == UInt8('-') && name[6] == UInt8('a') && name[7] == UInt8('u') && name[8] == UInt8('t') && name[9] == UInt8('h') && name[10] == UInt8('o') && name[11] == UInt8('r') && name[12] == UInt8('i') && name[13] == UInt8('z') && name[14] == UInt8('a') && name[15] == UInt8('t') && name[16] == UInt8('i') && name[17] == UInt8('o') && name[18] == UInt8('n')) { 32 }
            else { none }
        case 22 =>
            if (name[0] == UInt8('a') && name[1] == UInt8('c') && name[2] == UInt8('c') && name[3] == UInt8('e') && name[4] == UInt8('s') && name[5] == UInt8('s') && name[6] == UInt8('-') && name[7] == UInt8('c') && name[8] == UInt8('o') && name[9] == UInt8('n') && name[10] == UInt8('t') && name[11] == UInt8('r') && name[12] == UInt8('o') && name[13] == UInt8('l') && name[14] == UInt8('-') && name[15] == UInt8('m') && name[16] == UInt8('a') && name[17] == UInt8('x') && name[18] == UInt8('-') && name[19] == UInt8('a') && name[20] == UInt8('g') && name[21] == UInt8('e')) { 7 }
            else if (name[0] == UInt8('x') && name[1] == UInt8('-') && name[2] == UInt8('c') && name[3] == UInt8('o') && name[4] == UInt8('n') && name[5] == UInt8('t') && name[6] == UInt8('e') && name[7] == UInt8('n') && name[8] == UInt8('t') && name[9] == UInt8('-') && name[10] == UInt8('t') && name[11] == UInt8('y') && name[12] == UInt8('p') && name[13] == UInt8('e') && name[14] == UInt8('-') && name[15] == UInt8('o') && name[16] == UInt8('p') && name[17] == UInt8('t') && name[18] == UInt8('i') && name[19] == UInt8('o') && name[20] == UInt8('n') && name[21] == UInt8('s')) { 39 }
            else { none }
        case 25 =>
            if (name[0] == UInt8('u') && name[1] == UInt8('p') && name[2] == UInt8('g') && name[3] == UInt8('r') && name[4] == UInt8('a') && name[5] == UInt8('d') && name[6] == UInt8('e') && name[7] == UInt8('-') && name[8] == UInt8('i') && name[9] == UInt8('n') && name[10] == UInt8('s') && name[11] == UInt8('e') && name[12] == UInt8('c') && name[13] == UInt8('u') && name[14] == UInt8('r') && name[15] == UInt8('e') && name[16] == UInt8('-') && name[17] == UInt8('r') && name[18] == UInt8('e') && name[19] == UInt8('q') && name[20] == UInt8('u') && name[21] == UInt8('e') && name[22] == UInt8('s') && name[23] == UInt8('t') && name[24] == UInt8('s')) { 37 }
            else { none }
        case 29 =>
            if (name[0] == UInt8('a') && name[1] == UInt8('c') && name[2] == UInt8('c') && name[3] == UInt8('e') && name[4] == UInt8('s') && name[5] == UInt8('s') && name[6] == UInt8('-') && name[7] == UInt8('c') && name[8] == UInt8('o') && name[9] == UInt8('n') && name[10] == UInt8('t') && name[11] == UInt8('r') && name[12] == UInt8('o') && name[13] == UInt8('l') && name[14] == UInt8('-') && name[15] == UInt8('r') && name[16] == UInt8('e') && name[17] == UInt8('q') && name[18] == UInt8('u') && name[19] == UInt8('e') && name[20] == UInt8('s') && name[21] == UInt8('t') && name[22] == UInt8('-') && name[23] == UInt8('m') && name[24] == UInt8('e') && name[25] == UInt8('t') && name[26] == UInt8('h') && name[27] == UInt8('o') && name[28] == UInt8('d')) { 8 }
            else { none }
        case 32 =>
            if (name[0] == UInt8('a') && name[1] == UInt8('c') && name[2] == UInt8('c') && name[3] == UInt8('e') && name[4] == UInt8('s') && name[5] == UInt8('s') && name[6] == UInt8('-') && name[7] == UInt8('c') && name[8] == UInt8('o') && name[9] == UInt8('n') && name[10] == UInt8('t') && name[11] == UInt8('r') && name[12] == UInt8('o') && name[13] == UInt8('l') && name[14] == UInt8('-') && name[15] == UInt8('a') && name[16] == UInt8('l') && name[17] == UInt8('l') && name[18] == UInt8('o') && name[19] == UInt8('w') && name[20] == UInt8('-') && name[21] == UInt8('c') && name[22] == UInt8('r') && name[23] == UInt8('e') && name[24] == UInt8('d') && name[25] == UInt8('e') && name[26] == UInt8('n') && name[27] == UInt8('t') && name[28] == UInt8('i') && name[29] == UInt8('a') && name[30] == UInt8('l') && name[31] == UInt8('s')) { 6 }
            else { none }
        case _ => none
    }
}

// ============================================================================
// UInt31WithReserved — 保留位的 31 位无符号整数
// ============================================================================

public class UInt31WithReserved {
    public var value: UInt32

    public init(value: UInt32) {
        this.value = value
    }

    public func reserved(): Bool {
        (this.value & 0x80000000) != 0
    }

    public func uint31(): UInt32 {
        this.value & 0x7FFFFFFF
    }

    public static func from(value: UInt32): UInt31WithReserved {
        UInt31WithReserved(value: value)
    }

    public static func `init`(value: UInt32, reserved: Bool): UInt31WithReserved {
        UInt31WithReserved(value: (value & 0x7FFFFFFF) | (reserved ? 0x80000000 : UInt32(0)))
    }

    public func toUInt32(): UInt32 {
        this.value
    }

    public static func fromBytes(src: Array<UInt8>): UInt31WithReserved {
        UInt31WithReserved(value: u32FromBytes(src))
    }
}

// ============================================================================
// StreamPriority — packed struct(u40): streamIdentifier: UInt32, weight: UInt8
// ============================================================================

public class StreamPriority {
    public static let BYTE_SIZE: Int = 5
    public var streamIdentifier: UInt32 = 0
    public var weight: UInt8 = 0
}

// ============================================================================
// FrameHeader — packed struct(u72): length: u24, type: UInt8, flags: UInt8, streamIdentifier: UInt32
// ============================================================================

public class FrameHeader {
    public static let BYTE_SIZE: Int = 9
    public var length: UInt32 = 0
    public var type_: UInt8 = 0x04 // HTTP_FRAME_SETTINGS
    public var flags: UInt8 = 0
    public var streamIdentifier: UInt32 = 0

    public init() {}
    public init(length: UInt32, type_: UInt8, flags: UInt8, streamIdentifier: UInt32) {
        this.size = length
        this.type_ = type_
        this.flags = flags
        this.streamIdentifier = streamIdentifier
    }

    public static func decode(raw: Array<UInt8>): FrameHeader {
        FrameHeader(
            length: (UInt32(raw[0]) << 16) | (UInt32(raw[1]) << 8) | UInt32(raw[2]),
            type_: raw[3],
            flags: raw[4],
            streamIdentifier: (UInt32(raw[5]) << 24) | (UInt32(raw[6]) << 16) | (UInt32(raw[7]) << 8) | UInt32(raw[8])
        )
    }
}

// ============================================================================
// SettingsPayloadUnit — packed struct(u48): type: UInt16, value: UInt32
// ============================================================================

public class SettingsPayloadUnit {
    public static let BYTE_SIZE: Int = 6
    public var type_: UInt16 = 0
    public var value: UInt32 = 0

    public init() {}
}

// ============================================================================
// FullSettingsPayload — packed struct(u336) — 7 * (UInt16 type + UInt32 value) = 42 bytes
// ============================================================================

public class FullSettingsPayload {
    public static let BYTE_SIZE: Int = 42

    public var headerTableSizeType: UInt16 = SettingsType.SETTINGS_HEADER_TABLE_SIZE.value
    public var headerTableSize: UInt32 = 4096
    public var enablePushType: UInt16 = SettingsType.SETTINGS_ENABLE_PUSH.value
    public var enablePush: UInt32 = 1
    public var maxConcurrentStreamsType: UInt16 = SettingsType.SETTINGS_MAX_CONCURRENT_STREAMS.value
    public var maxConcurrentStreams: UInt32 = UInt32.maxValue
    public var initialWindowSizeType: UInt16 = SettingsType.SETTINGS_INITIAL_WINDOW_SIZE.value
    public var initialWindowSize: UInt32 = 65535
    public var maxFrameSizeType: UInt16 = SettingsType.SETTINGS_MAX_FRAME_SIZE.value
    public var maxFrameSize: UInt32 = 16384
    public var maxHeaderListSizeType: UInt16 = SettingsType.SETTINGS_MAX_HEADER_LIST_SIZE.value
    public var maxHeaderListSize: UInt32 = 65535
    public var enableConnectProtocolType: UInt16 = SettingsType.SETTINGS_ENABLE_CONNECT_PROTOCOL.value
    public var enableConnectProtocol: UInt32 = 0

    public init() {}

    public func toJs(JsGlobalObject): JsValue {
        let result = JsValue.createEmptyObject(globalObject, 8)
        result.put(globalObject, "headerTableSize", JsValue.jsNumber(Float64(headerTableSize)))
        result.put(globalObject, "enablePush", JsValue.from(enablePush > 0))
        result.put(globalObject, "maxConcurrentStreams", JsValue.jsNumber(Float64(maxConcurrentStreams)))
        result.put(globalObject, "initialWindowSize", JsValue.jsNumber(Float64(initialWindowSize)))
        result.put(globalObject, "maxFrameSize", JsValue.jsNumber(Float64(maxFrameSize)))
        result.put(globalObject, "maxHeaderListSize", JsValue.jsNumber(Float64(maxHeaderListSize)))
        result.put(globalObject, "maxHeaderSize", JsValue.jsNumber(Float64(maxHeaderListSize)))
        result.put(globalObject, "enableConnectProtocol", JsValue.from(enableConnectProtocol > 0))
        result
    }

    public func updateWith(option: SettingsPayloadUnit) {
        match (option.type_) {
            case SettingsType.SETTINGS_HEADER_TABLE_SIZE.value => this.headerTableSize = option.value
            case SettingsType.SETTINGS_ENABLE_PUSH.value => this.enablePush = option.value
            case SettingsType.SETTINGS_MAX_CONCURRENT_STREAMS.value => this.maxConcurrentStreams = option.value
            case SettingsType.SETTINGS_INITIAL_WINDOW_SIZE.value => this.initialWindowSize = option.value
            case SettingsType.SETTINGS_MAX_FRAME_SIZE.value => this.maxFrameSize = option.value
            case SettingsType.SETTINGS_MAX_HEADER_LIST_SIZE.value => this.maxHeaderListSize = option.value
            case SettingsType.SETTINGS_ENABLE_CONNECT_PROTOCOL.value => this.enableConnectProtocol = option.value
            case _ => ()
        }
    }
}

// ============================================================================
// BunSocket 联合类型
// ============================================================================

public enum BunSocket {
    | None
    | Tls(TLSSocket)
    | TlsWriteonly(TLSSocket)
    | Tcp(TCPSocket)
    | TcpWriteonly(TCPSocket)
}

// ============================================================================
// 获取 HTTP/2 通用字符串 (FFI)
// ============================================================================

@Extern
public func JSC__JSGlobalObject__getHTTP2CommonString(JsGlobalObject, hpackIndex: UInt32): JsValue

@Extern
public func Bun__wrapAbortError(JsGlobalObject, cause: JsValue): JsValue

public func getHTTP2CommonString(JsGlobalObject, hpackIndex: UInt32): ?JsValue {
    if (hpackIndex == 255) { return none }
    let value = JSC__JSGlobalObject__getHTTP2CommonString(globalObject, hpackIndex)
    if (value.isEmptyOrUndefinedOrNull()) { return none }
    value
}

// ============================================================================
// FlushState — flush 结果
// ============================================================================

public enum FlushState {
    | NoAction
    | Flushed
    | Backpressure
}

// ============================================================================
// StreamState — 流状态
// ============================================================================

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
// PendingFrame — 待发送帧
// ============================================================================

public class PendingFrame {
    public var endStream: Bool = false
    public var len: UInt32 = 0
    public var offset: UInt32 = 0
    public var buffer: ArrayList<UInt8> = ArrayList<UInt8>()
    public var callback: JsValue = JsValue.jsUndefined()

    public func slice(): Array<UInt8> {
        buffer.toArray()[Int64(offset)..Int64(len)]
    }
}

// ============================================================================
// PendingQueue — 帧队列
// ============================================================================

public class PendingQueue {
    public var data: ArrayList<PendingFrame> = ArrayList<PendingFrame>()
    public var front: Int = 0
    public var len: Int = 0

    public func enqueue(value: PendingFrame) {
        data.append(value)
        len += 1
    }

    public func peek(): ?PendingFrame {
        if (len == 0) { return none }
        data[0]
    }

    public func peekLast(): ?PendingFrame {
        if (len == 0) { return none }
        data[data.size - 1]
    }

    public func peekFront(): ?PendingFrame {
        if (len == 0) { return none }
        data[front]
    }

    public func dequeue(): ?PendingFrame {
        if (len == 0) { return none }
        let value = data[front]
        len -= 1
        if (len == 0) {
            front = 0
            data.clear()
        } else {
            front += 1
        }
        value
    }

    public func isEmpty(): Bool {
        len == 0
    }
}

// ============================================================================
// Stream — HTTP/2 流
// ============================================================================

public class Stream {
    public var id: UInt32 = 0
    public var state: StreamState = StreamState.open
    public var jsContext: JsValue = JsValue.jsUndefined()
    public var waitForTrailers: Bool = false
    public var closeAfterDrain: Bool = false
    public var endAfterHeaders: Bool = false
    public var isWaitingMoreHeaders: Bool = false
    public var padding: ?UInt8 = none
    public var paddingStrategy: PaddingStrategy = PaddingStrategy.None
    public var rstCode: UInt32 = 0
    public var streamDependency: UInt32 = 0
    public var exclusive: Bool = false
    public var weight: UInt16 = 0
    public var windowSize: UInt64 = 0
    public var usedWindowSize: UInt64 = 0
    public var remoteWindowSize: UInt64 = 0
    public var remoteUsedWindowSize: UInt64 = 0
    public var dataFrameQueue: PendingQueue = PendingQueue()

    public init() {}

    public static func `init`(
        streamIdentifier: UInt32,
        initialWindowSize: UInt32,
        remoteWindowSize: UInt32,
        paddingStrategy: PaddingStrategy
    ): Stream {
        let s = Stream()
        s.id = streamIdentifier
        s.state = StreamState.open
        s.windowSize = UInt64(initialWindowSize)
        s.remoteWindowSize = UInt64(remoteWindowSize)
        s.weight = 16
        s.streamDependency = 0
        return s
    }

    public func canReceiveData(): Bool {
        match (state) {
            case idle | reservedLocal | reservedRemote | open | halfClosedLocal => true
            case _ => false
        }
    }

    public func canSendData(): Bool {
        match (state) {
            case idle | reservedLocal | reservedRemote | open | halfClosedRemote => true
            case _ => false
        }
    }

    public func getPadding(frameLen: Int, maxLen: Int): UInt8 {
        match (paddingStrategy) {
            case None => UInt8(0)
            case Aligned =>
                let diff = (frameLen + 9) % 8
                if (diff == 0) { return UInt8(0) }
                var paddedLen = frameLen + (8 - diff)
                paddedLen = Math.min(paddedLen, maxLen)
                UInt8(Math.min(paddedLen - frameLen, 255))
            case Max =>
                UInt8(Math.min(maxLen - frameLen, 255))
        }
    }

    public func getIdentifier(): JsValue {
        JsValue.jsNumber(Float64(id))
    }

    public func freeResources(finalizing: Bool, client: H2FrameParser) {
        cleanQueue(finalizing, client)
    }

    public func cleanQueue(finalizing: Bool, client: H2FrameParser) {
        var queue = dataFrameQueue
        while (true) {
            let item = queue.dequeue()
            if (item.isNone()) { break }
            let frame = item.get()
            let len = frame.slice().size
            client.queuedDataSize = client.queuedDataSize - UInt64(len)
            if (!finalizing) {
                client.dispatchWriteCallback(frame.callback)
            }
        }
    }
}

// ============================================================================
// Handlers — 事件处理器
// ============================================================================

public class Handlers {
    public var binaryType: BinaryType = BinaryType.Buffer
    public var globalObject: JsGlobalObject

    public init(JsGlobalObject) {
        this.globalObject = globalObject
    }

    public func global(): JsGlobalObject {
        globalObject
    }

    public static func fromJs(
        JsGlobalObject,
        opts: JsValue,
        thisValue: JsValue
    ): ?Handlers {
        if (opts.isEmptyOrUndefinedOrNull() || opts.isBoolean() || !opts.isObject()) {
            return none
        }
        let handlers = Handlers(globalObject)
        // 回调注册由 JS 绑定层处理
        handlers
    }
}

// ============================================================================
// H2FrameParser — HTTP/2 帧解析器
// ============================================================================

public class H2FrameParser {
    // 强引用
    public var strongThis: JsValue = JsValue.jsUndefined()
    public var globalThis: JsGlobalObject
    public var handlers: ?Handlers = none
    public var nativeSocket: BunSocket = BunSocket.None
    public var localSettings: FullSettingsPayload = FullSettingsPayload()
    public var remoteSettings: ?FullSettingsPayload = none
    public var currentFrame: ?FrameHeader = none
    public var remainingLength: Int32 = 0
    public var readBuffer: ArrayList<UInt8> = ArrayList<UInt8>()

    // 本地窗口大小
    public var windowSize: UInt64 = DEFAULT_WINDOW_SIZE
    public var usedWindowSize: UInt64 = 0

    // 远端窗口大小
    public var remoteWindowSize: UInt64 = DEFAULT_WINDOW_SIZE
    public var remoteUsedWindowSize: UInt64 = 0

    public var maxHeaderListPairs: UInt32 = 128
    public var maxRejectedStreams: UInt32 = 100
    public var maxOutstandingSettings: UInt32 = 10
    public var outstandingSettings: UInt32 = 0
    public var rejectedStreams: UInt32 = 0
    public var maxSessionMemory: UInt32 = 10
    public var queuedDataSize: UInt64 = 0
    public var maxOutstandingPings: UInt64 = 10
    public var outStandingPings: UInt64 = 0
    public var maxSendHeaderBlockLength: UInt32 = 0
    public var lastStreamId: UInt32 = 0
    public var isServer: Bool = false
    public var prefaceReceivedLen: UInt8 = 0
    public var writeBuffer: ArrayList<UInt8> = ArrayList<UInt8>()
    public var writeBufferOffset: Int = 0
    public var outboundQueueSize: Int = 0
    public var streams: HashMap<UInt32, Stream> = HashMap<UInt32, Stream>()
    public var hasNonnativeBackpressure: Bool = false
    public var paddingStrategy: PaddingStrategy = PaddingStrategy.None

    public init(JsGlobalObject) {
        this.globalThis = globalObject
    }

    // ========================================================================
    // 核心方法
    // ========================================================================

    public func global(): JsGlobalObject {
        this.globalThis
    }

    public func hasBackpressure(): Bool {
        writeBuffer.size > 0 || hasNonnativeBackpressure
    }

    public func getNextStreamId(): UInt32 {
        var streamId = lastStreamId
        if (isServer) {
            if (streamId % 2 == 0) { streamId += 2 }
            else { streamId += 1 }
        } else {
            if (streamId % 2 == 0) { streamId += 1 }
            else if (streamId == 0) { streamId = 1 }
            else { streamId += 2 }
        }
        streamId
    }

    // ========================================================================
    // 帧发送方法
    // ========================================================================

    public func sendSettingsAck() {
        let buffer = Array<UInt8>(9, { _ => UInt8(0) })
        let settingsHeader = FrameHeader(
            length: 0,
            type_: 0x04,
            flags: 0x01,
            streamIdentifier: 0
        )
        writeFrameHeader(settingsHeader, buffer, 0)
        write(buffer)
    }

    public func sendWindowUpdate(streamIdentifier: UInt32, windowSize_: UInt31WithReserved) {
        let buffer = Array<UInt8>(13, { _ => UInt8(0) })
        let header = FrameHeader(
            length: 4,
            type_: 0x08,
            flags: 0,
            streamIdentifier: streamIdentifier
        )
        writeFrameHeader(header, buffer, 0)
        let value = windowSize_.toUInt32().bigEndian()
        buffer[5] = UInt8((value >> 24) & 0xFF)
        buffer[6] = UInt8((value >> 16) & 0xFF)
        buffer[7] = UInt8((value >> 8) & 0xFF)
        buffer[8] = UInt8(value & 0xFF)
        write(buffer)
    }

    public func sendGoAway(
        streamIdentifier: UInt32,
        rstCode: ErrorCode,
        debugData: Array<UInt8>,
        lastStreamId_: UInt32,
        emitError: Bool
    ) {
        let bufferSize = 9 + 8
        var buffer = Array<UInt8>(bufferSize, item: UInt8(0))
        let frame = FrameHeader(
            length: UInt32(8 + debugData.size),
            type_: 0x07,
            flags: 0,
            streamIdentifier: streamIdentifier
        )
        writeFrameHeader(frame, buffer, 0)
        let lastId = UInt31WithReserved(value: lastStreamId_, reserved: false)
        let lastIdValue = lastId.toUInt32().bigEndian()
        buffer[9] = UInt8((lastIdValue >> 24) & 0xFF)
        buffer[10] = UInt8((lastIdValue >> 16) & 0xFF)
        buffer[11] = UInt8((lastIdValue >> 8) & 0xFF)
        buffer[12] = UInt8(lastIdValue & 0xFF)
        let codeValue = rstCode.value.bigEndian()
        buffer[13] = UInt8((codeValue >> 24) & 0xFF)
        buffer[14] = UInt8((codeValue >> 16) & 0xFF)
        buffer[15] = UInt8((codeValue >> 8) & 0xFF)
        buffer[16] = UInt8(codeValue & 0xFF)
        write(buffer)
        if (!debugData.isEmpty()) {
            write(debugData)
        }
        if (emitError) {
            if (!rstCode.equals(ErrorCode.NO_ERROR)) {
                dispatchWith2Extra(
                    JsValue.jsUndefined(),
                    JsValue.jsNumber(Float64(rstCode.value)),
                    JsValue.jsNumber(Float64(lastStreamId))
                )
            }
            dispatchWithExtra(JsValue.jsUndefined(), JsValue.jsNumber(Float64(lastStreamId)))
        }
    }

    public func sendPing(ack: Bool, payload: Array<UInt8>) {
        if (!ack) {
            outStandingPings += 1
        }
        let buffer = Array<UInt8>(17, { _ => UInt8(0) })
        let frame = FrameHeader(
            length: 8,
            type_: 0x06,
            flags: ack ? UInt8(0x1) : UInt8(0),
            streamIdentifier: 0
        )
        writeFrameHeader(frame, buffer, 0)
        for (i in 0..8) {
            if (i < payload.size) {
                buffer[9 + i] = payload[i]
            }
        }
        write(buffer)
    }

    public func sendPrefaceAndSettings() {
        let preface: Array<UInt8> = [
            UInt8('P'), UInt8('R'), UInt8('I'), UInt8(' '),
            UInt8('*'), UInt8(' '), UInt8('H'), UInt8('T'),
            UInt8('T'), UInt8('P'), UInt8('/'), UInt8('2'),
            UInt8('.'), UInt8('0'), UInt8('\r'), UInt8('\n'),
            UInt8('\r'), UInt8('\n'), UInt8('S'), UInt8('M'),
            UInt8('\r'), UInt8('\n'), UInt8('\r'), UInt8('\n')
        ]
        let bufferSize = 24 + 9 + FullSettingsPayload.BYTE_SIZE
        var buffer = Array<UInt8>(bufferSize, item: UInt8(0))
        for (i in 0..24) {
            buffer[i] = preface[i]
        }
        outstandingSettings += 1
        let settingsHeader = FrameHeader(
            length: UInt32(FullSettingsPayload.BYTE_SIZE),
            type_: 0x04,
            flags: 0,
            streamIdentifier: 0
        )
        writeFrameHeader(settingsHeader, buffer, 24)
        write(buffer)
    }

    public func setSettings(settings: FullSettingsPayload): Bool {
        if (outstandingSettings >= maxOutstandingSettings) {
            sendGoAway(
                0,
                ErrorCode.MAX_PENDING_SETTINGS_ACK,
                [],
                lastStreamId,
                true
            )
            return false
        }
        outstandingSettings += 1
        localSettings = settings
        let bufferSize = 9 + FullSettingsPayload.BYTE_SIZE
        let buffer = Array<UInt8>(bufferSize, item: UInt8(0))
        let settingsHeader = FrameHeader(
            length: UInt32(FullSettingsPayload.BYTE_SIZE),
            type_: 0x04,
            flags: 0,
            streamIdentifier: 0
        )
        writeFrameHeader(settingsHeader, buffer, 0)
        write(buffer)
        true
    }

    public func abortStream(stream_: Stream, abortReason: JsValue) {
        let bufferSize = 9 + 4
        let buffer = Array<UInt8>(bufferSize, item: UInt8(0))
        let frame = FrameHeader(
            length: 4,
            type_: 0x03,
            flags: 0,
            streamIdentifier: stream_.id
        )
        writeFrameHeader(frame, buffer, 0)
        let value = ErrorCode.CANCEL.value.bigEndian()
        buffer[9] = UInt8((value >> 24) & 0xFF)
        buffer[10] = UInt8((value >> 16) & 0xFF)
        buffer[11] = UInt8((value >> 8) & 0xFF)
        buffer[12] = UInt8(value & 0xFF)
        stream_.rstCode = ErrorCode.CANCEL.value
        let oldState = stream_.state
        stream_.state = StreamState.closed
        stream_.freeResources(false, this)
        write(buffer)
    }

    public func endStream(stream_: Stream, rstCode: ErrorCode) {
        if (stream_.state == StreamState.closed) { return }
        let bufferSize = 9 + 4
        let buffer = Array<UInt8>(bufferSize, item: UInt8(0))
        let frame = FrameHeader(
            length: 4,
            type_: 0x03,
            flags: 0,
            streamIdentifier: stream_.id
        )
        writeFrameHeader(frame, buffer, 0)
        let value = rstCode.value.bigEndian()
        buffer[9] = UInt8((value >> 24) & 0xFF)
        buffer[10] = UInt8((value >> 16) & 0xFF)
        buffer[11] = UInt8((value >> 8) & 0xFF)
        buffer[12] = UInt8(value & 0xFF)
        stream_.rstCode = rstCode.value
        stream_.state = StreamState.closed
        stream_.freeResources(false, this)
        write(buffer)
    }

    public func sendAltSvc(streamIdentifier: UInt32, originStr: Array<UInt8>, alt: Array<UInt8>) {
        let bufferSize = 9 + 2
        var buffer = Array<UInt8>(bufferSize, item: UInt8(0))
        let frame = FrameHeader(
            length: UInt32(originStr.size + alt.size + 2),
            type_: 0x0A,
            flags: 0,
            streamIdentifier: streamIdentifier
        )
        writeFrameHeader(frame, buffer, 0)
        let originLen = UInt16(originStr.size).bigEndian()
        buffer[9] = UInt8((originLen >> 8) & 0xFF)
        buffer[10] = UInt8(originLen & 0xFF)
        write(buffer)
        if (!originStr.isEmpty()) { write(originStr) }
        if (!alt.isEmpty()) { write(alt) }
    }

    // ========================================================================
    // 帧处理方法
    // ========================================================================

    public func handleIncomingPayload(data: Array<UInt8>, streamIdentifier: UInt32): ?Array<UInt8>> {
        let end = Math.min(Int64(remainingLength), data.size)
        let payload = data[0..end]
        remainingLength = remainingLength - Int32(end)
        if (remainingLength > 0) {
            readBuffer.appendAll(payload)
            return none
        } else if (remainingLength < 0) {
            sendGoAway(
                streamIdentifier,
                ErrorCode.FRAME_SIZE_ERROR,
                [],
                lastStreamId,
                true
            )
            return none
        }
        currentFrame = none
        if (!readBuffer.isEmpty()) {
            readBuffer.appendAll(payload)
            return readBuffer.toArray()
        }
        payload
    }

    public func handleDataFrame(frame: FrameHeader, data: Array<UInt8>, stream_: ?Stream): Int {
        readBuffer.clear()
        if (stream_.isNone()) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.PROTOCOL_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        let stream = stream_.get()
        let settings = remoteSettings ?? localSettings
        if (frame.size > settings.maxFrameSize) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.FRAME_SIZE_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        let end = Math.min(Int64(remainingLength), data.size)
        remainingLength = remainingLength - Int32(end)
        if (remainingLength < 0) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.FRAME_SIZE_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        if (remainingLength == 0) {
            currentFrame = none
            if ((frame.flags & 0x1) != 0) {
                stream.state = StreamState.halfClosedRemote
            }
        }
        end
    }

    public func handleWindowUpdateFrame(frame: FrameHeader, data: Array<UInt8>, stream_: ?Stream): Int {
        if (frame.size != 4) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.FRAME_SIZE_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        if (let some content <- handleIncomingPayload(data, frame.streamIdentifier)) {
            readBuffer.clear()
            if (stream_.isNone()) {
                remoteWindowSize += UInt64(UInt31WithReserved.fromBytes(content).uint31())
            }
            flush()
            return content.size
        }
        data.size
    }

    public func handleSettingsFrame(frame: FrameHeader, data: Array<UInt8>): Int {
        let isAck = (frame.flags & 0x1) != 0
        if (frame.streamIdentifier != 0) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.PROTOCOL_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        let sendAckOnExit = !isAck

        if (frame.size > 0) {
            if (isAck || (frame.size % UInt32(SettingsPayloadUnit.BYTE_SIZE)) != 0) {
                sendGoAway(
                    frame.streamIdentifier,
                    ErrorCode.FRAME_SIZE_ERROR,
                    [],
                    lastStreamId,
                    true
                )
                if (sendAckOnExit) { sendSettingsAck() }
                return data.size
            }
        } else {
            if (isAck) {
                if (outstandingSettings > 0) {
                    outstandingSettings -= 1
                }
            }
            currentFrame = none
            if (sendAckOnExit) { sendSettingsAck() }
            incrementWindowSizeIfNeeded()
            flush()
            return 0
        }

        if (let some content <- handleIncomingPayload(data, frame.streamIdentifier)) {
            var remoteSettings_ = remoteSettings ?? FullSettingsPayload()
            var i: Int = 0
            while (i + SettingsPayloadUnit.BYTE_SIZE <= content.size) {
                let unit = SettingsPayloadUnit()
                unit.type_ = (UInt16(content[i]) << 8) | UInt16(content[i + 1])
                unit.value = (UInt32(content[i + 2]) << 24) | (UInt32(content[i + 3]) << 16) |
                             (UInt32(content[i + 4]) << 8) | UInt32(content[i + 5])
                if (unit.type_ == SettingsType.SETTINGS_MAX_FRAME_SIZE.value &&
                    (unit.value < 16384 || unit.value > MAX_FRAME_SIZE)) {
                    readBuffer.clear()
                    sendGoAway(
                        frame.streamIdentifier,
                        ErrorCode.PROTOCOL_ERROR,
                        [],
                        lastStreamId,
                        true
                    )
                    return content.size
                }
                remoteSettings_.updateWith(unit)
                i += SettingsPayloadUnit.BYTE_SIZE
            }
            readBuffer.clear()
            remoteSettings = remoteSettings_
            incrementWindowSizeIfNeeded()
            flush()
            if (sendAckOnExit) { sendSettingsAck() }
            return content.size
        }
        if (sendAckOnExit) { sendSettingsAck() }
        data.size
    }

    public func handleGoAwayFrame(frame: FrameHeader, data: Array<UInt8>): Int {
        let settings = remoteSettings ?? localSettings
        if (frame.size < 8 || frame.size > settings.maxFrameSize) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.FRAME_SIZE_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        if (let some content <- handleIncomingPayload(data, frame.streamIdentifier)) {
            readBuffer.clear()
            return content.size
        }
        data.size
    }

    public func handlePingFrame(frame: FrameHeader, data: Array<UInt8>): Int {
        if (frame.size != 8) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.FRAME_SIZE_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        if (let some content <- handleIncomingPayload(data, frame.streamIdentifier)) {
            let isNotAck = (frame.flags & 0x1) == 0
            readBuffer.clear()
            if (isNotAck) {
                sendPing(true, content)
            } else {
                if (outStandingPings > 0) { outStandingPings -= 1 }
            }
            return content.size
        }
        data.size
    }

    public func handleRstStreamFrame(frame: FrameHeader, data: Array<UInt8>, stream_: ?Stream): Int {
        if (stream_.isNone()) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.PROTOCOL_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        let stream = stream_.get()
        if (frame.size != 4) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.FRAME_SIZE_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        if (let some content <- handleIncomingPayload(data, frame.streamIdentifier)) {
            let rstCode = u32FromBytes(content)
            stream.rstCode = rstCode
            readBuffer.clear()
            stream.state = StreamState.closed
            stream.freeResources(false, this)
            return content.size
        }
        data.size
    }

    public func handlePriorityFrame(frame: FrameHeader, data: Array<UInt8>, stream_: ?Stream): Int {
        if (stream_.isNone()) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.PROTOCOL_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        let stream = stream_.get()
        if (frame.size != UInt32(StreamPriority.BYTE_SIZE)) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.FRAME_SIZE_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        if (let some content <- handleIncomingPayload(data, frame.streamIdentifier)) {
            readBuffer.clear()
            let streamId = UInt31WithReserved.fromBytes(content)
            if (streamId.uint31() == stream.id) {
                sendGoAway(
                    stream.id,
                    ErrorCode.PROTOCOL_ERROR,
                    [],
                    lastStreamId,
                    true
                )
                return content.size
            }
            stream.streamDependency = streamId.uint31()
            stream.exclusive = streamId.reserved()
            return content.size
        }
        data.size
    }

    public func handleHeadersFrame(frame: FrameHeader, data: Array<UInt8>, stream_: ?Stream): Int {
        if (stream_.isNone()) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.PROTOCOL_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        let stream = stream_.get()
        let settings = remoteSettings ?? localSettings
        if (frame.size > settings.maxFrameSize) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.FRAME_SIZE_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        if (let some content <- handleIncomingPayload(data, frame.streamIdentifier)) {
            readBuffer.clear()
            stream.endAfterHeaders = (frame.flags & 0x1) != 0
            if (stream.endAfterHeaders) {
                if (stream.state == StreamState.halfClosedLocal) {
                    stream.state = StreamState.closed
                    stream.freeResources(false, this)
                } else {
                    stream.state = StreamState.halfClosedRemote
                }
            }
            return content.size
        }
        data.size
    }

    public func handleContinuationFrame(frame: FrameHeader, data: Array<UInt8>, stream_: ?Stream): Int {
        if (stream_.isNone()) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.PROTOCOL_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        let stream = stream_.get()
        if (!stream.isWaitingMoreHeaders) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.PROTOCOL_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        if (let some content <- handleIncomingPayload(data, frame.streamIdentifier)) {
            readBuffer.clear()
            stream.endAfterHeaders = (frame.flags & 0x1) != 0
            if (stream.endAfterHeaders) {
                stream.isWaitingMoreHeaders = false
                if ((frame.flags & 0x1) != 0) {
                    if (stream.state == StreamState.halfClosedRemote) {
                        stream.state = StreamState.closed
                        stream.freeResources(false, this)
                    } else {
                        stream.state = StreamState.halfClosedLocal
                    }
                }
            }
            return content.size
        }
        data.size
    }

    public func handleOriginFrame(frame: FrameHeader, data: Array<UInt8>): Int {
        if (isServer) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.PROTOCOL_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        if (frame.streamIdentifier != 0) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.PROTOCOL_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        if (let some content <- handleIncomingPayload(data, frame.streamIdentifier)) {
            readBuffer.clear()
            return content.size
        }
        data.size
    }

    public func handleAltsvcFrame(frame: FrameHeader, data: Array<UInt8>): Int {
        if (isServer) {
            sendGoAway(
                frame.streamIdentifier,
                ErrorCode.PROTOCOL_ERROR,
                [],
                lastStreamId,
                true
            )
            return data.size
        }
        if (let some content <- handleIncomingPayload(data, frame.streamIdentifier)) {
            readBuffer.clear()
            if (content.size < 2) {
                sendGoAway(
                    frame.streamIdentifier,
                    ErrorCode.FRAME_SIZE_ERROR,
                    [],
                    lastStreamId,
                    true
                )
                return content.size
            }
            return content.size
        }
        data.size
    }

    // ========================================================================
    // 流管理
    // ========================================================================

    public func handleReceivedStreamId(streamIdentifier: UInt32): ?Stream {
        if (streamIdentifier == 0) { return none }
        if (let some existing <- streams.get(streamIdentifier)) { return existing }
        if (streamIdentifier > lastStreamId) {
            lastStreamId = streamIdentifier
        }
        let localWindowSize = if (outstandingSettings > 0) {
            UInt32(65535)
        } else {
            localSettings.initialWindowSize
        }
        let remoteWindowSize_ = if (let some rs <- remoteSettings) {
            rs.initialWindowSize
        } else {
            UInt32(65535)
        }
        let stream = Stream(streamIdentifier, localWindowSize, remoteWindowSize_, paddingStrategy)
        streams.put(streamIdentifier, stream)
        stream
    }

    // ========================================================================
    // 读取字节
    // ========================================================================

    public func readBytes(bytes: Array<UInt8>): Int {
        if (isServer && Int64(prefaceReceivedLen) < 24) {
            let prefaceMissing = 24 - Int64(prefaceReceivedLen)
            let prefaceAvailable = Math.min(prefaceMissing, bytes.size)
            let expected: Array<UInt8> = [
                UInt8('P'), UInt8('R'), UInt8('I'), UInt8(' '),
                UInt8('*'), UInt8(' '), UInt8('H'), UInt8('T'),
                UInt8('T'), UInt8('P'), UInt8('/'), UInt8('2'),
                UInt8('.'), UInt8('0'), UInt8('\r'), UInt8('\n'),
                UInt8('\r'), UInt8('\n'), UInt8('S'), UInt8('M'),
                UInt8('\r'), UInt8('\n'), UInt8('\r'), UInt8('\n')
            ]
            for (i in 0..Int64(prefaceAvailable)) {
                if (bytes[Int64(i)] != expected[Int64(prefaceReceivedLen) + Int64(i)]) {
                    sendGoAway(0, ErrorCode.PROTOCOL_ERROR, [], lastStreamId, true)
                    return Int64(prefaceAvailable)
                }
            }
            prefaceReceivedLen = UInt8(Int64(prefaceReceivedLen) + prefaceAvailable)
            return Int64(prefaceAvailable)
        }

        if (let some header <- currentFrame) {
            let stream = handleReceivedStreamId(header.streamIdentifier)
            return dispatchFrame(header, bytes, stream, 0)
        }

        if (bytes.isEmpty()) { return 0 }

        let bufferedData = readBuffer.size
        if (bufferedData > 0) {
            let total = bufferedData + bytes.size
            if (total < FrameHeader.BYTE_SIZE) {
                readBuffer.appendAll(bytes)
                return bytes.size
            }
            let needed = FrameHeader.BYTE_SIZE - bufferedData
            var raw = Array<UInt8>(FrameHeader.BYTE_SIZE, item: UInt8(0))
            let buffered = readBuffer.toArray()
            for (i in 0..Int64(bufferedData)) { raw[Int64(i)] = buffered[Int64(i)] }
            for (i in 0..Int64(needed)) { raw[Int64(bufferedData) + Int64(i)] = bytes[Int64(i)] }
            let header = FrameHeader.decode(raw)
            let id = UInt31WithReserved.from(header.streamIdentifier)
            header.streamIdentifier = id.uint31()
            readBuffer.clear()
            currentFrame = header
            remainingLength = Int32(header.size)
            let stream = handleReceivedStreamId(header.streamIdentifier)
            return dispatchFrame(header, bytes[Int64(needed)..], stream, Int64(needed))
        }

        if (bytes.size < FrameHeader.BYTE_SIZE) {
            readBuffer.appendAll(bytes)
            return bytes.size
        }

        let header = FrameHeader.decode(bytes[0..FrameHeader.BYTE_SIZE])
        currentFrame = header
        remainingLength = Int32(header.size)
        let stream = handleReceivedStreamId(header.streamIdentifier)
        dispatchFrame(header, bytes[FrameHeader.BYTE_SIZE..], stream, FrameHeader.BYTE_SIZE)
    }

    public func dispatchFrame(header: FrameHeader, bytes: Array<UInt8>, stream: ?Stream, add: Int): Int {
        match (header.type_) {
            case 0x04 => handleSettingsFrame(header, bytes) + add
            case 0x08 => handleWindowUpdateFrame(header, bytes, stream) + add
            case 0x01 => handleHeadersFrame(header, bytes, stream) + add
            case 0x00 => handleDataFrame(header, bytes, stream) + add
            case 0x09 => handleContinuationFrame(header, bytes, stream) + add
            case 0x02 => handlePriorityFrame(header, bytes, stream) + add
            case 0x06 => handlePingFrame(header, bytes) + add
            case 0x07 => handleGoAwayFrame(header, bytes) + add
            case 0x03 => handleRstStreamFrame(header, bytes, stream) + add
            case 0x0A => handleAltsvcFrame(header, bytes) + add
            case 0x0C => handleOriginFrame(header, bytes) + add
            case _ =>
                sendGoAway(
                    header.streamIdentifier,
                    ErrorCode.PROTOCOL_ERROR,
                    [],
                    lastStreamId,
                    true
                )
                bytes.size + add
        }
    }

    // ========================================================================
    // 窗口管理
    // ========================================================================

    public func adjustWindowSize(stream_: ?Stream, payloadSize: UInt32) {
        usedWindowSize = usedWindowSize + UInt64(payloadSize)
        if (usedWindowSize > windowSize) {
            sendGoAway(0, ErrorCode.FLOW_CONTROL_ERROR, [], lastStreamId, true)
            usedWindowSize = usedWindowSize - UInt64(payloadSize)
        }
        if (let some s <- stream_) {
            s.usedWindowSize += UInt64(payloadSize)
            if (s.usedWindowSize > s.windowSize) {
                sendGoAway(s.id, ErrorCode.FLOW_CONTROL_ERROR, [], lastStreamId, true)
                s.usedWindowSize -= UInt64(payloadSize)
            }
        }
    }

    public func incrementWindowSizeIfNeeded() {
        for ((_, stream) in streams) {
            if (stream.usedWindowSize >= stream.windowSize / 2 && stream.usedWindowSize > 0) {
                let consumed = stream.usedWindowSize
                stream.usedWindowSize = 0
                sendWindowUpdate(stream.id, UInt31WithReserved(value: UInt32(consumed), reserved: false))
            }
        }
        if (usedWindowSize >= windowSize / 2 && usedWindowSize > 0) {
            let consumed = usedWindowSize
            usedWindowSize = 0
            sendWindowUpdate(0, UInt31WithReserved(value: UInt32(consumed), reserved: false))
        }
    }

    // ========================================================================
    // 写入方法
    // ========================================================================

    public func write(bytes: Array<UInt8>): Bool {
        _write(bytes)
    }

    public func _write(bytes: Array<UInt8>): Bool {
        match (nativeSocket) {
            case BunSocket.None =>
                if (hasNonnativeBackpressure) {
                    writeBuffer.appendAll(bytes)
                    return false
                }
                true
            case _ =>
                true
        }
    }

    public func flush(): Int {
        match (nativeSocket) {
            case BunSocket.None =>
                hasNonnativeBackpressure = false
                let bytesLen = writeBuffer.size
                if (bytesLen > 0) {
                    writeBuffer.clear()
                }
                if (!hasBackpressure()) {
                    return flushStreamQueue()
                }
                bytesLen
            case _ =>
                let bufferLen = writeBuffer.size - writeBufferOffset
                if (bufferLen > 0) {
                    writeBuffer.clear()
                    writeBufferOffset = 0
                }
                if (!hasBackpressure()) {
                    return flushStreamQueue()
                }
                bufferLen
        }
    }

    public func flushStreamQueue(): Int {
        var written: Int = 0
        var somethingWasFlushed = true
        while (outboundQueueSize > 0 && somethingWasFlushed) {
            somethingWasFlushed = false
            for ((_, stream) in streams) {
                if (stream.canSendData()) {
                    somethingWasFlushed = true
                }
            }
        }
        written
    }

    // ========================================================================
    // 数据发送
    // ========================================================================

    public func sendData(stream_: Stream, payload: Array<UInt8>, close: Bool, callback: JsValue) {
        let streamId = stream_.id
        let canClose = close && !stream_.waitForTrailers

        if (payload.isEmpty()) {
            let dataHeader = FrameHeader(
                length: 0,
                type_: 0x00,
                flags: canClose ? UInt8(0x1) : UInt8(0),
                streamIdentifier: streamId
            )
            let buffer = Array<UInt8>(9, { _ => UInt8(0) })
            writeFrameHeader(dataHeader, buffer, 0)
            write(buffer)
        } else {
            var offset: Int = 0
            while (offset < payload.size) {
                let maxFrameSize = MAX_PAYLOAD_SIZE_WITHOUT_FRAME
                let size = Math.min(payload.size - offset, maxFrameSize)
                let slice = payload[offset..offset + size]
                offset += size
                let endStream = offset >= payload.size && canClose
                let dataHeader = FrameHeader(
                    length: UInt32(size),
                    type_: 0x00,
                    flags: endStream ? UInt8(0x1) : UInt8(0),
                    streamIdentifier: streamId
                )
                let headerBuf = Array<UInt8>(9, { _ => UInt8(0) })
                writeFrameHeader(dataHeader, headerBuf, 0)
                write(headerBuf)
                write(slice)
            }
        }

        if (!payload.isEmpty()) {
            dispatchWriteCallback(callback)
            if (close) {
                if (stream_.waitForTrailers) {
                    // 等待 trailers
                } else {
                    if (stream_.state == StreamState.halfClosedRemote) {
                        stream_.state = StreamState.closed
                        stream_.freeResources(false, this)
                    } else {
                        stream_.state = StreamState.halfClosedLocal
                    }
                }
            }
        }
    }

    // ========================================================================
    // 事件分发
    // ========================================================================

    public func dispatch(event: JsValue, value: JsValue) {
        // 事件分发由 JS 绑定层处理
    }

    public func dispatchWithExtra(event: JsValue, value: JsValue, extra: JsValue) {
        // 事件分发由 JS 绑定层处理
    }

    public func dispatchWith2Extra(event: JsValue, value: JsValue, extra: JsValue, extra2: JsValue) {
        // 事件分发由 JS 绑定层处理
    }

    public func dispatchWith3Extra(event: JsValue, value: JsValue, extra: JsValue, extra2: JsValue, extra3: JsValue) {
        // 事件分发由 JS 绑定层处理
    }

    public func dispatchWriteCallback(callback: JsValue) {
        // 写入回调由 JS 绑定层处理
    }

    // ========================================================================
    // 帧头写入辅助
    // ========================================================================

    public static func writeFrameHeader(header: FrameHeader, buffer: Array<UInt8>, offset: Int) {
        buffer[offset] = UInt8((header.size >> 16) & 0xFF)
        buffer[offset + 1] = UInt8((header.size >> 8) & 0xFF)
        buffer[offset + 2] = UInt8(header.size & 0xFF)
        buffer[offset + 3] = header.type_
        buffer[offset + 4] = header.flags
        let sid = header.streamIdentifier.bigEndian()
        buffer[offset + 5] = UInt8((sid >> 24) & 0xFF)
        buffer[offset + 6] = UInt8((sid >> 16) & 0xFF)
        buffer[offset + 7] = UInt8((sid >> 8) & 0xFF)
        buffer[offset + 8] = UInt8(sid & 0xFF)
    }

    // ========================================================================
    // 会话内存
    // ========================================================================

    public func getSessionMemoryUsage(): Int {
        (writeBuffer.size + Int(queuedDataSize)) / 1024 / 1024
    }

    public func getBufferSize(): Int {
        writeBuffer.size + Int(queuedDataSize)
    }

    // ========================================================================
    // 原生 socket 回调
    // ========================================================================

    public func onNativeRead(data: Array<UInt8>) {
        var bytes = data
        while (!bytes.isEmpty()) {
            let result = readBytes(bytes)
            if (result >= bytes.size) { break }
            bytes = bytes[result..]
        }
        incrementWindowSizeIfNeeded()
    }

    public func onNativeWritable() {
        flush()
    }

    public func onNativeClose() {
        detachNativeSocket()
    }

    public func detachNativeSocket() {
        nativeSocket = BunSocket.None
    }

    // ========================================================================
    // 构造与析构
    // ========================================================================

    public static func constructor(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): ?H2FrameParser {
        let arguments = callframe.argumentsOld(1)
        if (arguments.len < 1) { return none }
        let options = arguments.ptr[0]
        if (options.isEmptyOrUndefinedOrNull() || options.isBoolean() || !options.isObject()) {
            return none
        }
        let parser = H2FrameParser(globalObject)
        parser.handlers = Handlers.fromJs(globalObject, options, thisValue)
        if (parser.handlers.isNone()) { return none }
        parser
    }

    public func detach() {
        readBuffer.clear()
        writeBuffer.clear()
        writeBufferOffset = 0
        remoteSettings = none
    }

    public func deinit() {
        detach()
        for ((_, stream) in streams) {
            stream.freeResources(true, this)
        }
        streams.clear()
    }

    // ========================================================================
    // 验证头部名称
    // ========================================================================

    public static func toValidHeaderName(name: Array<UInt8>): ?Array<UInt8>> {
        if (name.size > 4096) { return none }
        for (i in 0..name.size) {
            let c = name[i]
            if (c >= UInt8('A') && c <= UInt8('Z')) {
                // 需要转小写
                var result = name
                result[i] = c + UInt8(32) // ASCII to lowercase
                var j = i + 1
                while (j < result.size) {
                    let ch = result[j]
                    if (ch >= UInt8('A') && ch <= UInt8('Z')) {
                        result[j] = ch + UInt8(32)
                    } else if (!((ch >= UInt8('a') && ch <= UInt8('z')) ||
                                (ch >= UInt8('0') && ch <= UInt8('9')) ||
                                ch == UInt8('!') || ch == UInt8('#') ||
                                ch == UInt8('$') || ch == UInt8('%') ||
                                ch == UInt8('&') || ch == UInt8('\'') ||
                                ch == UInt8('*') || ch == UInt8('+') ||
                                ch == UInt8('-') || ch == UInt8('.') ||
                                ch == UInt8('^') || ch == UInt8('_') ||
                                ch == UInt8('`') || ch == UInt8('|') ||
                                ch == UInt8('~') || (ch == UInt8(':') && j == 0))) {
                        return none
                    }
                    j += 1
                }
                return result
            } else if (!((c >= UInt8('a') && c <= UInt8('z')) ||
                        (c >= UInt8('0') && c <= UInt8('9')) ||
                        c == UInt8('!') || c == UInt8('#') ||
                        c == UInt8('$') || c == UInt8('%') ||
                        c == UInt8('&') || c == UInt8('\'') ||
                        c == UInt8('*') || c == UInt8('+') ||
                        c == UInt8('-') || c == UInt8('.') ||
                        c == UInt8('^') || c == UInt8('_') ||
                        c == UInt8('`') || c == UInt8('|') ||
                        c == UInt8('~') || (c == UInt8(':') && i == 0))) {
                return none
            }
        }
        name
    }
}

// ============================================================================
// JS Host Functions
// ============================================================================

/// js_get_unpacked_settings — 解包设置
public func jsGetUnpackedSettings(JsGlobalObject, callframe: JsCallFrame): JsValue {
    let settings = FullSettingsPayload()
    let arguments = callframe.argumentsOld(1)
    if (arguments.len < 1) { return settings.toJs(globalObject) }

    let dataArg = arguments.ptr[0]
    if (let some arrayBuffer <- dataArg.asArrayBuffer(globalObject)) {
        let payload = arrayBuffer.byteSlice()
        let settingByteSize = SettingsPayloadUnit.BYTE_SIZE
        if (payload.size < settingByteSize || payload.size % settingByteSize != 0) {
            return globalObject.`throw`("Expected buf to be a Buffer of at least 6 bytes and a multiple of 6 bytes")
        }
        var i: Int = 0
        while (i < payload.size) {
            let unit = SettingsPayloadUnit()
            unit.type_ = (UInt16(payload[i]) << 8) | UInt16(payload[i + 1])
            unit.value = (UInt32(payload[i + 2]) << 24) | (UInt32(payload[i + 3]) << 16) |
                         (UInt32(payload[i + 4]) << 8) | UInt32(payload[i + 5])
            settings.updateWith(unit)
            i += settingByteSize
        }
        return settings.toJs(globalObject)
    } else if (!dataArg.isEmptyOrUndefinedOrNull()) {
        return globalObject.`throw`("Expected buf to be a Buffer")
    }
    settings.toJs(globalObject)
}

/// js_assert_settings — 校验设置
public func jsAssertSettings(JsGlobalObject, callframe: JsCallFrame): JsValue {
    let arguments = callframe.argumentsOld(1)
    if (arguments.len > 0 && !arguments.ptr[0].isEmptyOrUndefinedOrNull()) {
        let options = arguments.ptr[0]
        if (!options.isObject()) {
            return globalObject.`throw`("Expected settings to be a object")
        }

        // headerTableSize
        if (let some headerTableSize <- options.get(globalObject, "headerTableSize")) {
            if (headerTableSize.isNumber()) {
                let value = headerTableSize.asNumber()
                if (value < 0.0 || value > MAX_HEADER_TABLE_SIZE_F64) {
                    return globalObject.`throw`("Expected headerTableSize to be a number between 0 and 2^32-1")
                }
            }
        }

        // enablePush
        if (let some enablePush <- options.get(globalObject, "enablePush")) {
            if (!enablePush.isBoolean() && !enablePush.isUndefined()) {
                return globalObject.`throw`("Expected enablePush to be a boolean")
            }
        }

        // initialWindowSize
        if (let some initialWindowSize <- options.get(globalObject, "initialWindowSize")) {
            if (initialWindowSize.isNumber()) {
                let value = initialWindowSize.asNumber()
                if (value < 0.0 || value > MAX_WINDOW_SIZE_F64) {
                    return globalObject.`throw`("Expected initialWindowSize to be a number between 0 and 2^32-1")
                }
            }
        }

        // maxFrameSize
        if (let some maxFrameSize <- options.get(globalObject, "maxFrameSize")) {
            if (maxFrameSize.isNumber()) {
                let value = maxFrameSize.asNumber()
                if (value < 16384.0 || value > MAX_FRAME_SIZE_F64) {
                    return globalObject.`throw`("Expected maxFrameSize to be a number between 16,384 and 2^24-1")
                }
            }
        }

        // maxConcurrentStreams
        if (let some maxConcurrentStreams <- options.get(globalObject, "maxConcurrentStreams")) {
            if (maxConcurrentStreams.isNumber()) {
                let value = maxConcurrentStreams.asNumber()
                if (value < 0.0 || value > MAX_HEADER_TABLE_SIZE_F64) {
                    return globalObject.`throw`("Expected maxConcurrentStreams to be a number between 0 and 2^32-1")
                }
            }
        }

        // maxHeaderListSize
        if (let some maxHeaderListSize <- options.get(globalObject, "maxHeaderListSize")) {
            if (maxHeaderListSize.isNumber()) {
                let value = maxHeaderListSize.asNumber()
                if (value < 0.0 || value > MAX_HEADER_TABLE_SIZE_F64) {
                    return globalObject.`throw`("Expected maxHeaderListSize to be a number between 0 and 2^32-1")
                }
            }
        }
    }
    JsValue.undefined
}

/// js_get_packed_settings — 打包设置
public func jsGetPackedSettings(JsGlobalObject, callframe: JsCallFrame): JsValue {
    let settings = FullSettingsPayload()
    let arguments = callframe.argumentsOld(1)

    if (arguments.len > 0 && !arguments.ptr[0].isEmptyOrUndefinedOrNull()) {
        let options = arguments.ptr[0]
        if (!options.isObject()) {
            return globalObject.`throw`("Expected settings to be a object")
        }

        if (let some headerTableSize <- options.get(globalObject, "headerTableSize")) {
            if (headerTableSize.isNumber()) {
                let v = headerTableSize.toInt32()
                if (UInt32(v) > MAX_HEADER_TABLE_SIZE || v < 0) {
                    return globalObject.`throw`("Expected headerTableSize to be a number between 0 and 2^32-1")
                }
                settings.headerTableSize = UInt32(v)
            }
        }

        if (let some enablePush <- options.get(globalObject, "enablePush")) {
            if (enablePush.isBoolean()) {
                settings.enablePush = enablePush.asBoolean() ? UInt32(1) : UInt32(0)
            }
        }

        if (let some initialWindowSize <- options.get(globalObject, "initialWindowSize")) {
            if (initialWindowSize.isNumber()) {
                let v = initialWindowSize.toInt32()
                if (UInt32(v) > MAX_HEADER_TABLE_SIZE || v < 0) {
                    return globalObject.`throw`("Expected initialWindowSize to be a number between 0 and 2^32-1")
                }
                settings.initialWindowSize = UInt32(v)
            }
        }

        if (let some maxFrameSize <- options.get(globalObject, "maxFrameSize")) {
            if (maxFrameSize.isNumber()) {
                let v = maxFrameSize.toInt32()
                if (UInt32(v) > MAX_FRAME_SIZE || v < 16384) {
                    return globalObject.`throw`("Expected maxFrameSize to be a number between 16,384 and 2^24-1")
                }
                settings.maxFrameSize = UInt32(v)
            }
        }

        if (let some maxConcurrentStreams <- options.get(globalObject, "maxConcurrentStreams")) {
            if (maxConcurrentStreams.isNumber()) {
                let v = maxConcurrentStreams.toInt32()
                if (UInt32(v) > MAX_HEADER_TABLE_SIZE || v < 0) {
                    return globalObject.`throw`("Expected maxConcurrentStreams to be a number between 0 and 2^32-1")
                }
                settings.maxConcurrentStreams = UInt32(v)
            }
        }

        if (let some maxHeaderListSize <- options.get(globalObject, "maxHeaderListSize")) {
            if (maxHeaderListSize.isNumber()) {
                let v = maxHeaderListSize.toInt32()
                if (UInt32(v) > MAX_HEADER_TABLE_SIZE || v < 0) {
                    return globalObject.`throw`("Expected maxHeaderListSize to be a number between 0 and 2^32-1")
                }
                settings.maxHeaderListSize = UInt32(v)
            }
        }

        if (let some maxHeaderSize <- options.get(globalObject, "maxHeaderSize")) {
            if (maxHeaderSize.isNumber()) {
                let v = maxHeaderSize.toInt32()
                if (UInt32(v) > MAX_HEADER_TABLE_SIZE || v < 0) {
                    return globalObject.`throw`("Expected maxHeaderSize to be a number between 0 and 2^32-1")
                }
                settings.maxHeaderListSize = UInt32(v)
            }
        }
    }

    // 编码设置到二进制
    let buf = Array<UInt8>(FullSettingsPayload.BYTE_SIZE, item: UInt8(0))
    var offset = 0
    let fields: Array<UInt32> = [
        UInt32(settings.headerTableSizeType), settings.headerTableSize,
        UInt32(settings.enablePushType), settings.enablePush,
        UInt32(settings.maxConcurrentStreamsType), settings.maxConcurrentStreams,
        UInt32(settings.initialWindowSizeType), settings.initialWindowSize,
        UInt32(settings.maxFrameSizeType), settings.maxFrameSize,
        UInt32(settings.maxHeaderListSizeType), settings.maxHeaderListSize,
        UInt32(settings.enableConnectProtocolType), settings.enableConnectProtocol
    ]
    for (i in 0..14) {
        let v = fields[Int64(i)]
        if (i % 2 == 0) {
            // UInt16
            buf[offset] = UInt8((v >> 8) & 0xFF)
            buf[offset + 1] = UInt8(v & 0xFF)
            offset += 2
        } else {
            // UInt32
            buf[offset] = UInt8((v >> 24) & 0xFF)
            buf[offset + 1] = UInt8((v >> 16) & 0xFF)
            buf[offset + 2] = UInt8((v >> 8) & 0xFF)
            buf[offset + 3] = UInt8(v & 0xFF)
            offset += 4
        }
    }
    JsValue.createBuffer(globalObject, buf)
}

// ported from: src/runtime/api/bun/h2_frame_parser.rs
