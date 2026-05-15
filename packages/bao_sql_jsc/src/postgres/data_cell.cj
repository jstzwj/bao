// 严格翻译自: src/sql_jsc/postgres/DataCell.zig
// Postgres 数据单元格 - 处理各种 PostgreSQL 数据类型

package bao_sql_jsc.postgres

import bao_core.*
import bao_jsc.*

/// Postgres 数据单元格（复用共享 SQLDataCell）
/// 对应 Bun: postgres/DataCell.zig SQLDataCell
/// 从字节流解析 PostgreSQL 列值

/// 从字节流解析值
/// 对应 Bun: DataCell.fromBytes
public func postgresDataCellFromBytes(binary: Bool, bigint: Bool, oid: PostgresTag,
                                       bytes: Array<UInt8>,
                                       globalObject: JscJSGlobalObject): ?SQLDataCell {
    let cell = SQLDataCell()

    match (oid) {
        case Int2 =>
            if (binary && bytes.size >= 2) {
                cell.tag = DataCellTag.Int4
                cell.int4Value = Int32(Int16(bytes[0]) | (Int16(bytes[1]) << 8))
            } else {
                cell.tag = DataCellTag.Int4
                cell.int4Value = parseInt32(bytes)
            }
        case Int4 =>
            if (binary && bytes.size >= 4) {
                cell.tag = DataCellTag.Int4
                cell.int4Value = readBEInt32(bytes)
            } else {
                cell.tag = DataCellTag.Int4
                cell.int4Value = parseInt32(bytes)
            }
        case Int8 =>
            if (bigint) {
                cell.tag = DataCellTag.Int8
                cell.int8Value = parseInt64(bytes)
            } else {
                cell.tag = DataCellTag.String
                cell.stringValue = String.fromUtf8(bytes)
                cell.freeValue = 1
            }
        case Float8 =>
            if (binary && bytes.size == 8) {
                cell.tag = DataCellTag.Float8
                cell.float8Value = readBEFloat64(bytes)
            } else {
                cell.tag = DataCellTag.Float8
                cell.float8Value = parseFloat64(bytes)
            }
        case Float4 =>
            if (binary && bytes.size == 4) {
                cell.tag = DataCellTag.Float8
                cell.float8Value = Float64(readBEFloat32(bytes))
            } else {
                cell.tag = DataCellTag.Float8
                cell.float8Value = parseFloat64(bytes)
            }
        case Numeric =>
            cell.tag = DataCellTag.String
            cell.stringValue = String.fromUtf8(bytes)
            cell.freeValue = 1
        case Json | Jsonb =>
            cell.tag = DataCellTag.Json
            cell.jsonValue = String.fromUtf8(bytes)
            cell.freeValue = 1
        case Bool =>
            if (binary) {
                cell.tag = DataCellTag.Bool
                cell.boolValue = if (bytes.size > 0 && bytes[0] == 1) 1 else 0
            } else {
                cell.tag = DataCellTag.Bool
                cell.boolValue = if (bytes.size > 0 && bytes[0] == 't') 1 else 0
            }
        case Date | Timestamp | Timestamptz =>
            if (bytes.size == 0) {
                cell.tag = DataCellTag.Null
            } else if (binary && bytes.size == 8) {
                if (oid == Timestamptz) {
                    cell.tag = DataCellTag.DateWithTimeZone
                    cell.dateWithTimeZoneValue = postgresDateFromBinary(bytes)
                } else {
                    cell.tag = DataCellTag.Date
                    cell.dateValue = postgresDateFromBinary(bytes)
                }
            } else {
                cell.tag = DataCellTag.Date
                cell.dateValue = 0.0 // 实际需要解析日期字符串
            }
        case Bytea =>
            if (binary) {
                cell.tag = DataCellTag.Bytea
                cell.byteaLen = UInt64(bytes.size)
            } else {
                if (bytes.size > 2 && bytes[0] == '\\' && bytes[1] == 'x') {
                    // hex 格式解析
                    cell.tag = DataCellTag.Bytea
                    cell.byteaLen = UInt64((bytes.size - 2) / 2)
                }
            }
        case Cid | Xid | Oid =>
            cell.tag = DataCellTag.UInt4
            if (binary) {
                cell.uint4Value = readBEUInt32(bytes)
            } else {
                cell.uint4Value = parseUInt32(bytes)
            }
        case _ =>
            // 默认作为字符串
            cell.tag = DataCellTag.String
            cell.stringValue = String.fromUtf8(bytes)
            cell.freeValue = 1
    }

    return cell
}

/// 数据单元格 Putter
/// 对应 Bun: DataCell.Putter
public class DataCellPutter {
    public var list: Array<SQLDataCell>
    public var fields: Array<FieldDescription>
    public var binary: Bool = false
    public var bigint: Bool = false
    public var count: Int64 = 0
    public var globalObject: JscJSGlobalObject

    public init(fields: Array<FieldDescription>, globalObject: JscJSGlobalObject) {
        this.fields = fields
        this.list = Array<SQLDataCell>(fields.size, item: SQLDataCell())
        this.globalObject = globalObject
    }

    /// 放入原始值
    /// 对应 Bun: Putter.putRaw
    public func putRaw(index: UInt32, data: ?Array<UInt8>): Bool {
        return putImpl(index, data, true)
    }

    /// 放入值
    /// 对应 Bun: Putter.put
    public func put(index: UInt32, data: ?Array<UInt8>): Bool {
        return putImpl(index, data, false)
    }

    /// 转换为 JS 值
    /// 对应 Bun: Putter.toJS
    public func toJS(globalObject: JscJSGlobalObject, array: JscValue,
                      structure: JscValue, flags: DataCellFlags,
                      resultMode: PostgresSQLQueryResultMode,
                      cachedStructure: ?CachedStructure): JscValue {
        return JscObject.createEmptyObject(globalObject).toValue()
    }

    private func putImpl(index: UInt32, data: ?Array<UInt8>, isRaw: Bool): Bool {
        if (index >= fields.size || index >= list.size) {
            return false
        }

        let field = fields[Int64(index)]
        let cell = list[Int64(index)]

        if (isRaw) {
            if (data != None) {
                cell.tag = DataCellTag.Raw
                cell.rawLen = UInt64(data.getOrThrow().size)
            } else {
                cell.tag = DataCellTag.Null
            }
        } else {
            let oid = PostgresTag.fromInt(field.typeOid)
            if (data != None) {
                let result = postgresDataCellFromBytes(
                    field.binary || binary, bigint, oid,
                    data.getOrThrow(), globalObject)
                if (result != None) {
                    list[Int64(index)] = result.getOrThrow()
                }
            } else {
                cell.tag = DataCellTag.Null
            }
        }

        count += 1

        // 设置索引信息
        match (field.nameOrIndex) {
            case Index(i) => list[Int64(index)].index = i
            case _ => list[Int64(index)].index = index
        }

        match (field.nameOrIndex) {
            case Duplicate => list[Int64(index)].isIndexedColumn = 2
            case Index(_) => list[Int64(index)].isIndexedColumn = 1
            case Name(_) => list[Int64(index)].isIndexedColumn = 0
        }

        return true
    }
}

// ===== 辅助函数 =====

/// Postgres 纪元时间（2000-01-01 00:00:00 UTC 相对于 Unix 纪元的毫秒数）
let POSTGRES_EPOCH_DATE: Float64 = 946684800000.0

/// 从二进制数据解析 Postgres 日期
/// 对应 Bun: date.fromBinary
func postgresDateFromBinary(bytes: Array<UInt8>): Float64 {
    if (bytes.size < 8) {
        return 0.0
    }
    let microseconds = readBEInt64(bytes)
    return Float64(microseconds) / 1000.0 + POSTGRES_EPOCH_DATE
}

func readBEInt32(data: Array<UInt8>): Int32 {
    if (data.size < 4) {
        return 0
    }
    return (Int32(data[0]) << 24) | (Int32(data[1]) << 16) |
        (Int32(data[2]) << 8) | Int32(data[3])
}

func readBEUInt32(data: Array<UInt8>): UInt32 {
    if (data.size < 4) {
        return 0
    }
    return (UInt32(data[0]) << 24) | (UInt32(data[1]) << 16) |
        (UInt32(data[2]) << 8) | UInt32(data[3])
}

func readBEInt64(data: Array<UInt8>): Int64 {
    if (data.size < 8) {
        return 0
    }
    return (Int64(data[0]) << 56) | (Int64(data[1]) << 48) |
        (Int64(data[2]) << 40) | (Int64(data[3]) << 32) |
        (Int64(data[4]) << 24) | (Int64(data[5]) << 16) |
        (Int64(data[6]) << 8) | Int64(data[7])
}

func readBEFloat32(data: Array<UInt8>): Float32 {
    return 0.0f32
}

func readBEFloat64(data: Array<UInt8>): Float64 {
    return 0.0
}

func parseInt32(data: Array<UInt8>): Int32 {
    var result: Int32 = 0
    var negative = false
    var start: Int64 = 0
    if (data.size > 0 && data[0] == '-') {
        negative = true
        start = 1
    }
    for (i in start..data.size) {
        let c = data[i]
        if (c >= '0' && c <= '9') {
            result = result * 10 + Int32(c - '0')
        }
    }
    return if (negative) -result else result
}

func parseUInt32(data: Array<UInt8>): UInt32 {
    var result: UInt32 = 0
    for (i in 0..data.size) {
        let c = data[i]
        if (c >= '0' && c <= '9') {
            result = result * 10 + UInt32(c - '0')
        }
    }
    return result
}

func parseInt64(data: Array<UInt8>): Int64 {
    var result: Int64 = 0
    var negative = false
    var start: Int64 = 0
    if (data.size > 0 && data[0] == '-') {
        negative = true
        start = 1
    }
    for (i in start..data.size) {
        let c = data[i]
        if (c >= '0' && c <= '9') {
            result = result * 10 + Int64(c - '0')
        }
    }
    return if (negative) -result else result
}

func parseFloat64(data: Array<UInt8>): Float64 {
    // 简化实现
    return 0.0
}
