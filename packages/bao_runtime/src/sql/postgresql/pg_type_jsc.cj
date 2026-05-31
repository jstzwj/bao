// PostgreSQL 类型 JSC 转换辅助
// 翻译自: bun/src/sql_jsc/postgres/types/ 下的类型文件
//   bool.zig, bytea.zig, date.zig, json.zig, PostgresString.zig, tag_jsc.zig
package bao_runtime.sql.postgresql

import bao_core.*

/// PostgreSQL 类型 JSC 转换辅助函数
/// 对应 Bun sql_jsc/postgres/types/ 下的各个文件
/// 将 PG 数据类型转换为 JS 可用的中间表示
public class PGTypeJSC {

    /// PostgreSQL 纪元日期 (2000-01-01 00:00:00 UTC) 的 Unix 毫秒时间戳
    /// 对应 Bun date.zig: POSTGRES_EPOCH_DATE
    public static let POSTGRES_EPOCH_DATE: Int64 = 946684800000

    /// 每毫秒微秒数
    public static let US_PER_MS: Int64 = 1000

    // ========================================================================
    // Bool 类型 (对应 types/bool.zig)
    // OID: 16
    // ========================================================================

    /// 将布尔值转为 JS 表示
    /// 对应 Bun bool.toJS()
    public static func boolToJS(value: Bool): JSBool {
        JSBool(value)
    }

    // ========================================================================
    // Bytea 类型 (对应 types/bytea.zig)
    // OID: 17
    // ========================================================================

    /// 将 bytea 转为 JS Buffer 表示
    /// 对应 Bun bytea.toJS()
    public static func byteaToJS(bytes: Array<UInt8>): JSBuffer {
        JSBuffer(bytes)
    }

    // ========================================================================
    // Date/Timestamp 类型 (对应 types/date.zig)
    // OID: 1082 (date), 1114 (timestamp), 1184 (timestamptz)
    // ========================================================================

    /// 从二进制数据解析 PostgreSQL 时间戳
    /// 对应 Bun date.fromBinary()
    /// PostgreSQL 存储时间戳为自 2000-01-01 以来的微秒数
    public static func dateFromBinary(bytes: Array<UInt8>): Float64 {
        if (bytes.size < 8) {
            return 0.0
        }
        let microseconds = readInt64BE(bytes, 0)
        return Float64(microseconds) / Float64(US_PER_MS) + Float64(POSTGRES_EPOCH_DATE)
    }

    /// 从 JS 值转为 PostgreSQL 时间戳
    /// 对应 Bun date.fromJS()
    /// 返回自 2000-01-01 以来的微秒数
    public static func dateFromJS(jsTimestamp: Float64): Int64 {
        let unixMs = Int64(jsTimestamp)
        return (unixMs - POSTGRES_EPOCH_DATE) * US_PER_MS
    }

    /// 将 Int64 微秒时间戳转为 JS Date
    /// 对应 Bun date.toJS(i64)
    public static func dateToJS(microseconds: Int64): JSTimestamp {
        let ms = microseconds / US_PER_MS + POSTGRES_EPOCH_DATE
        JSTimestamp(Float64(ms))
    }

    /// 将字符串日期转为 JS Date
    /// 对应 Bun date.toJS(*Data)
    public static func dateStringToJS(dateStr: String): JSTimestamp {
        // 简化: 尝试解析 ISO 8601 日期字符串
        JSTimestamp(Float64(0))
    }

    // ========================================================================
    // JSON 类型 (对应 types/json.zig)
    // OID: 114 (json), 3802 (jsonb)
    // ========================================================================

    /// 将 JSON 字符串转为 JS 对象
    /// 对应 Bun json.toJS()
    public static func jsonToJS(jsonStr: String): JSJsonResult {
        // 简化: 返回 JSON 字符串
        // 实际实现需要 JSON.parse
        JSJsonResult(jsonStr)
    }

    // ========================================================================
    // String 类型 (对应 types/PostgresString.zig)
    // OID: 25 (text)
    // ========================================================================

    /// 将字符串转为 JS String
    /// 对应 Bun PostgresString.toJS()
    public static func stringToJS(str: String): JSString {
        JSString(str)
    }

    // ========================================================================
    // Tag 推断 (对应 types/tag_jsc.zig)
    // ========================================================================

    /// 从 JS 值推断 PostgreSQL 类型标签
    /// 对应 Bun Tag.fromJS()
    public static func tagFromJSValue(value: JSValueKind): PGTag {
        match (value) {
            case JSValueKind.Null | JSValueKind.Undefined => PGTag.Text
            case JSValueKind.String => PGTag.Text
            case JSValueKind.Date => PGTag.Timestamptz
            case JSValueKind.Int32Array => PGTag.Int4Array
            case JSValueKind.ArrayBuffer | JSValueKind.TypedArray => PGTag.Bytea
            case JSValueKind.BigInt => PGTag.Int8
            case JSValueKind.Array => PGTag.JSON
            case JSValueKind.Boolean => PGTag.Bool
            case JSValueKind.Int32 => PGTag.Int4
            case JSValueKind.Int64 => PGTag.Int8
            case JSValueKind.Float64 => PGTag.Float8
            case JSValueKind.Number => PGTag.Float8
            case _ => PGTag.Numeric
        }
    }

    /// 将 Tag 转为 JS TypedArray 类型
    /// 对应 Bun Tag.toJSTypedArrayType()
    public static func tagToJSTypedArrayType(tag: PGTag): ?JSTypedArrayType {
        match (tag) {
            case PGTag.Int4Array => JSTypedArrayType.Int32Array
            case PGTag.Float4Array => JSTypedArrayType.Float32Array
            case _ => None
        }
    }

    // ========================================================================
    // 内部辅助
    // ========================================================================

    private static func readInt64BE(bytes: Array<UInt8>, offset: Int64): Int64 {
        let b0 = Int64(bytes[offset]) << 56
        let b1 = Int64(bytes[offset + 1]) << 48
        let b2 = Int64(bytes[offset + 2]) << 40
        let b3 = Int64(bytes[offset + 3]) << 32
        let b4 = Int64(bytes[offset + 4]) << 24
        let b5 = Int64(bytes[offset + 5]) << 16
        let b6 = Int64(bytes[offset + 6]) << 8
        let b7 = Int64(bytes[offset + 7])
        return b0 | b1 | b2 | b3 | b4 | b5 | b6 | b7
    }
}

// ========================================================================
// JS 值中间表示类型
// ========================================================================

/// JS 布尔值
public struct JSBool {
    public var value: Bool
    public init(value: Bool) { this.value = value }
}

/// JS Buffer 值
public struct JSBuffer {
    public var bytes: Array<UInt8>
    public init(bytes: Array<UInt8>) { this.bytes = bytes }
}

/// JS 时间戳值
public struct JSTimestamp {
    public var unixMilliseconds: Float64
    public init(unixMilliseconds: Float64) { this.unixMilliseconds = unixMilliseconds }
}

/// JS JSON 结果
public struct JSJsonResult {
    public var jsonString: String
    public init(jsonString: String) { this.jsonString = jsonString }
}

/// JS 字符串值
public struct JSString {
    public var value: String
    public init(value: String) { this.value = value }
}

/// JS 值类型标识
/// 对应 Bun 中的 JSValue.jsType() 判断
public enum JSValueKind {
    | Null
    | Undefined
    | String
    | Boolean
    | Int32
    | Int64
    | Float64
    | Number
    | BigInt
    | Date
    | Array
    | ArrayBuffer
    | TypedArray
    | Int32Array
    | Object
    | Function
    | Unknown
}
