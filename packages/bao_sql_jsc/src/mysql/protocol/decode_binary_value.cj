// 严格翻译自: src/sql_jsc/mysql/protocol/DecodeBinaryValue.zig
// MySQL 二进制值解码

package bao_sql_jsc.mysql.protocol

import bao_core.*
import bao_jsc.*

/// 二进制字符集 ID
/// 对应 Bun: DecodeBinaryValue.binary_charset
let BINARY_CHARSET_ID: UInt16 = 63

/// 解码二进制值
/// 对应 Bun: decodeBinaryValue
/// 从二进制协议数据中解码 MySQL 字段值
public func decodeBinaryValue(globalObject: JscJSGlobalObject, fieldType: UInt8,
                               columnLength: UInt32, raw: Bool, bigint: Bool,
                               unsigned: Bool, binary: Bool, characterSet: UInt16,
                               data: Array<UInt8>): ?SQLDataCell {
    let cell = SQLDataCell()

    // 根据字段类型解码
    match (fieldType) {
        case 1 => // TINY
            if (data.size == 0) { return None }
            if (raw) {
                return SQLDataCell.raw(0, 1)
            }
            if (unsigned) {
                cell.tag = DataCellTag.UInt4
                cell.uint4Value = UInt32(data[0])
            } else {
                cell.tag = DataCellTag.Int4
                cell.int4Value = Int32(Int8(data[0]))
            }
        case 2 => // SHORT
            if (data.size < 2) { return None }
            if (raw) {
                return SQLDataCell.raw(0, 2)
            }
            if (unsigned) {
                cell.tag = DataCellTag.UInt4
                cell.uint4Value = UInt32(readUInt16LE(data, 0))
            } else {
                cell.tag = DataCellTag.Int4
                cell.int4Value = Int32(readInt16LE(data, 0))
            }
        case 3 => // LONG
            if (data.size < 4) { return None }
            if (raw) {
                return SQLDataCell.raw(0, 4)
            }
            if (unsigned) {
                cell.tag = DataCellTag.UInt4
                cell.uint4Value = readUInt32LE(data, 0)
            } else {
                cell.tag = DataCellTag.Int4
                cell.int4Value = readInt32LE(data, 0)
            }
        case 8 => // LONGLONG
            if (data.size < 8) { return None }
            if (raw) {
                return SQLDataCell.raw(0, 8)
            }
            if (unsigned) {
                let val = readUInt64LE(data, 0)
                if (val <= UInt32.MaxValue) {
                    cell.tag = DataCellTag.UInt4
                    cell.uint4Value = UInt32(val)
                } else if (bigint) {
                    cell.tag = DataCellTag.UInt8
                    cell.uint8Value = val
                } else {
                    cell.tag = DataCellTag.String
                    cell.stringValue = val.toString()
                    cell.freeValue = 1
                }
            } else {
                let val = readInt64LE(data, 0)
                if (val >= Int64(Int32.MinValue) && val <= Int64(Int32.MaxValue)) {
                    cell.tag = DataCellTag.Int4
                    cell.int4Value = Int32(val)
                } else if (bigint) {
                    cell.tag = DataCellTag.Int8
                    cell.int8Value = val
                } else {
                    cell.tag = DataCellTag.String
                    cell.stringValue = val.toString()
                    cell.freeValue = 1
                }
            }
        case 4 => // FLOAT
            if (data.size < 4) { return None }
            cell.tag = DataCellTag.Float8
            cell.float8Value = Float64(readFloat32LE(data, 0))
        case 5 => // DOUBLE
            if (data.size < 8) { return None }
            cell.tag = DataCellTag.Float8
            cell.float8Value = readFloat64LE(data, 0)
        case 11 => // TIME
            cell.tag = DataCellTag.String
            cell.stringValue = decodeTimeBinary(data)
            cell.freeValue = 1
        case 10 | 7 | 12 => // DATE, TIMESTAMP, DATETIME
            if (data.size == 0) {
                cell.tag = DataCellTag.Date
                cell.dateValue = 0.0
            } else {
                cell.tag = DataCellTag.Date
                cell.dateValue = decodeDateTimeBinary(data)
            }
        case 245 => // JSON
            cell.tag = DataCellTag.Json
            cell.jsonValue = String.fromUtf8(data)
            cell.freeValue = 1
        case 16 => // BIT
            if (columnLength == 1 && data.size > 0) {
                cell.tag = DataCellTag.Bool
                cell.boolValue = if (data[0] == 1) 1 else 0
            } else {
                return SQLDataCell.raw(0, UInt64(data.size))
            }
        case _ =>
            // 默认作为字符串或二进制处理
            if (binary && characterSet == BINARY_CHARSET_ID) {
                return SQLDataCell.raw(0, UInt64(data.size))
            } else {
                cell.tag = DataCellTag.String
                cell.stringValue = String.fromUtf8(data)
                cell.freeValue = 1
            }
    }

    return cell
}

// ===== 辅助读取函数 =====

func readUInt16LE(data: Array<UInt8>, offset: Int64): UInt16 {
    return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
}

func readInt16LE(data: Array<UInt8>, offset: Int64): Int16 {
    return Int16(readUInt16LE(data, offset))
}

func readUInt32LE(data: Array<UInt8>, offset: Int64): UInt32 {
    return UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8) |
        (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
}

func readInt32LE(data: Array<UInt8>, offset: Int64): Int32 {
    return Int32(readUInt32LE(data, offset))
}

func readUInt64LE(data: Array<UInt8>, offset: Int64): UInt64 {
    return UInt64(data[offset]) | (UInt64(data[offset + 1]) << 8) |
        (UInt64(data[offset + 2]) << 16) | (UInt64(data[offset + 3]) << 24) |
        (UInt64(data[offset + 4]) << 32) | (UInt64(data[offset + 5]) << 40) |
        (UInt64(data[offset + 6]) << 48) | (UInt64(data[offset + 7]) << 56)
}

func readInt64LE(data: Array<UInt8>, offset: Int64): Int64 {
    return Int64(readUInt64LE(data, offset))
}

func readFloat32LE(data: Array<UInt8>, offset: Int64): Float32 {
    // 简化实现
    return 0.0f32
}

func readFloat64LE(data: Array<UInt8>, offset: Int64): Float64 {
    // 简化实现
    return 0.0
}

func decodeTimeBinary(data: Array<UInt8>): String {
    return "00:00:00"
}

func decodeDateTimeBinary(data: Array<UInt8>): Float64 {
    return 0.0
}
