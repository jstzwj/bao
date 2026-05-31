// MySQL 结果集行
// 严格翻译自: src/sql_jsc/mysql/protocol/ResultSet.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 结果集行
/// 对应 Bun: ResultSet.Row
/// 包含一行的值和列元数据
public class MySQLRow {
    /// 单元格值
    public var values: ArrayList<MySQLDataCell>
    /// 列定义
    public var columns: ArrayList<ColumnDefinition41>
    /// 是否为二进制结果集
    public var binary: Bool
    /// 是否为原始模式
    public var raw: Bool
    /// 是否使用 BigInt
    public var bigint: Bool

    public init() {
        values = ArrayList<MySQLDataCell>()
        columns = ArrayList<ColumnDefinition41>()
        binary = false
        raw = false
        bigint = false
    }

    public init(columns: ArrayList<ColumnDefinition41>, binary: Bool, raw: Bool, bigint: Bool) {
        values = ArrayList<MySQLDataCell>()
        this.columns = columns
        this.binary = binary
        this.raw = raw
        this.bigint = bigint
    }

    /// 释放资源
    /// 对应 Bun: Row.deinit
    public func deinit(): Unit {
        for (cell in values) {
            cell.deinit()
        }
        values = ArrayList<MySQLDataCell>()
        // columns 不拥有，不释放
    }

    /// 从 Reader 解码 (文本或二进制)
    /// 对应 Bun: Row.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        if (binary) {
            decodeBinary(reader)
        } else {
            decodeText(reader)
        }
    }

    /// 文本协议解码
    /// 对应 Bun: Row.decodeText
    func decodeText(reader: MySQLPacketReader): Unit {
        values = ArrayList<MySQLDataCell>()

        for (index in 0..columns.size) {
            let column = columns[index]
            let peeked = reader.peek()

            let result = decodeLengthInt(peeked)
            if (let Some(r) <- result) {
                if (r.value == 0xfb) {
                    // NULL 值
                    reader.skip(r.bytesRead)
                    let cell = MySQLDataCell()
                    cell.tag = DataCellTag.nullTag
                    cell.index = Int64(index)
                    values.append(cell)
                } else {
                    reader.skip(r.bytesRead)
                    let data = reader.readBytes(Int64(r.value))
                    let cell = MySQLDataCell()
                    parseValueAndSetCell(cell, column, data)
                    cell.index = Int64(index)
                    values.append(cell)
                }
            }
        }
    }

    /// 二进制协议解码
    /// 对应 Bun: Row.decodeBinary
    func decodeBinary(reader: MySQLPacketReader): Unit {
        // Header (1 字节)
        _ = reader.readInt8()

        // Null bitmap
        let bitmapBytes = (columns.size + 7 + 2) / 8
        let nullBitmap = reader.readBytes(bitmapBytes)
        let bitmapSlice = nullBitmap.slice()

        values = ArrayList<MySQLDataCell>()
        let bitmapOffset = 2

        for (i in 0..columns.size) {
            let bytePos = (bitmapOffset + i) >> 3
            let bitPos = (bitmapOffset + i) & 7
            let isNull = bytePos < bitmapSlice.size &&
                (bitmapSlice[bytePos] & (UInt8(1) << UInt8(bitPos))) != 0

            if (isNull) {
                let cell = MySQLDataCell()
                cell.tag = DataCellTag.nullTag
                cell.index = Int64(i)
                values.append(cell)
                continue
            }

            let column = columns[i]
            let cell = DecodeBinaryValue.decode(
                column.columnType,
                column.columnLength,
                raw,
                bigint,
                column.flags.UNSIGNED,
                column.flags.BINARY,
                column.characterSet,
                reader
            )
            cell.index = Int64(i)
            values.append(cell)
        }
    }

    /// 解析值并设置单元格
    /// 对应 Bun: Row.parseValueAndSetCell
    func parseValueAndSetCell(cell: MySQLDataCell, column: ColumnDefinition41, value: SQLData): Unit {
        let slice = value.slice()
        let sliceStr = stringFromBytes(slice)

        match (column.columnType) {
            case MYSQL_TYPE_FLOAT =>
                cell.tag = DataCellTag.float8
                cell.floatValue = parseFloat64(sliceStr)
            case MYSQL_TYPE_DOUBLE =>
                cell.tag = DataCellTag.float8
                cell.floatValue = parseFloat64(sliceStr)
            case MYSQL_TYPE_TINY =>
                if (column.flags.UNSIGNED) {
                    cell.tag = DataCellTag.uint4
                    cell.uintValue = UInt64(parseUInt16(sliceStr))
                } else {
                    cell.tag = DataCellTag.int4
                    cell.intValue = Int64(parseInt16(sliceStr))
                }
            case MYSQL_TYPE_SHORT =>
                if (column.flags.UNSIGNED) {
                    cell.tag = DataCellTag.uint4
                    cell.uintValue = UInt64(parseUInt16(sliceStr))
                } else {
                    cell.tag = DataCellTag.int4
                    cell.intValue = Int64(parseInt16(sliceStr))
                }
            case MYSQL_TYPE_YEAR =>
                if (column.flags.UNSIGNED) {
                    cell.tag = DataCellTag.uint4
                    cell.uintValue = UInt64(parseUInt16(sliceStr))
                } else {
                    cell.tag = DataCellTag.int4
                    cell.intValue = Int64(parseInt16(sliceStr))
                }
            case MYSQL_TYPE_LONG =>
                if (column.flags.UNSIGNED) {
                    cell.tag = DataCellTag.uint4
                    cell.uintValue = UInt64(parseUInt32(sliceStr))
                } else {
                    cell.tag = DataCellTag.int4
                    cell.intValue = Int64(parseInt32(sliceStr))
                }
            case MYSQL_TYPE_INT24 =>
                if (column.flags.UNSIGNED) {
                    cell.tag = DataCellTag.uint4
                    cell.uintValue = UInt64(parseUInt32(sliceStr))
                } else {
                    cell.tag = DataCellTag.int4
                    cell.intValue = Int64(parseInt32(sliceStr))
                }
            case MYSQL_TYPE_LONGLONG =>
                if (column.flags.UNSIGNED) {
                    let val = parseUInt64(sliceStr)
                    if (val <= UInt64(UInt32.MaxValue)) {
                        cell.tag = DataCellTag.uint4
                        cell.uintValue = val
                    } else if (bigint) {
                        cell.tag = DataCellTag.uint8
                        cell.uintValue = val
                    } else {
                        cell.tag = DataCellTag.stringTag
                        cell.stringValue = sliceStr
                    }
                } else {
                    let val = parseInt64(sliceStr)
                    if (val >= Int64(Int32.MinValue) && val <= Int64(Int32.MaxValue)) {
                        cell.tag = DataCellTag.int4
                        cell.intValue = val
                    } else if (bigint) {
                        cell.tag = DataCellTag.int8
                        cell.intValue = val
                    } else {
                        cell.tag = DataCellTag.stringTag
                        cell.stringValue = sliceStr
                    }
                }
            case MYSQL_TYPE_JSON =>
                cell.tag = DataCellTag.jsonTag
                cell.stringValue = sliceStr
            case MYSQL_TYPE_TIME =>
                cell.tag = DataCellTag.stringTag
                cell.stringValue = sliceStr
            case MYSQL_TYPE_DATE =>
                cell.tag = DataCellTag.stringTag
                cell.stringValue = sliceStr
            case MYSQL_TYPE_DATETIME =>
                cell.tag = DataCellTag.stringTag
                cell.stringValue = sliceStr
            case MYSQL_TYPE_TIMESTAMP =>
                cell.tag = DataCellTag.stringTag
                cell.stringValue = sliceStr
            case MYSQL_TYPE_NEWDECIMAL =>
                cell.tag = DataCellTag.stringTag
                cell.stringValue = sliceStr
            case MYSQL_TYPE_BIT =>
                if (column.columnLength == 1) {
                    cell.tag = DataCellTag.boolTag
                    cell.boolValue = slice.size > 0 && slice[0] == 1
                } else {
                    cell.tag = DataCellTag.rawTag
                    cell.bytesValue = slice
                }
            case _ =>
                if (column.flags.BINARY && column.characterSet == DecodeBinaryValue.BINARY_CHARSET) {
                    cell.tag = DataCellTag.rawTag
                    cell.bytesValue = slice
                } else {
                    cell.tag = DataCellTag.stringTag
                    cell.stringValue = sliceStr
                }
        }
    }
}

/// MySQL 数据单元格
/// 对应 Bun: SQLDataCell
public class MySQLDataCell {
    /// 单元格类型
    public var tag: DataCellTag
    /// 列索引
    public var index: Int64
    /// 布尔值
    public var boolValue: Bool
    /// 整数值
    public var intValue: Int64
    /// 无符号整数值
    public var uintValue: UInt64
    /// 浮点值
    public var floatValue: Float64
    /// 字符串值
    public var stringValue: String
    /// 字节值
    public var bytesValue: Array<UInt8>
    /// 是否为已索引列
    public var isIndexedColumn: Int64

    public init() {
        tag = DataCellTag.nullTag
        index = 0
        boolValue = false
        intValue = 0
        uintValue = 0
        floatValue = 0.0
        stringValue = ""
        bytesValue = Array<UInt8>()
        isIndexedColumn = 0
    }

    /// 释放资源
    public func deinit(): Unit {
        bytesValue = Array<UInt8>()
    }
}

/// 数据单元格标签
/// 对应 Bun: SQLDataCell.tag
public enum DataCellTag {
    | nullTag
    | boolTag
    | int4
    | int8
    | uint4
    | uint8
    | float8
    | stringTag
    | jsonTag
    | rawTag
    | date
}

/// 二进制值解码
/// 对应 Bun: DecodeBinaryValue
public class DecodeBinaryValue {
    /// 二进制字符集 ID
    public static let BINARY_CHARSET: UInt16 = 63

    /// 从二进制结果集解码一个值
    /// 对应 Bun: decodeBinaryValue
    public static func decode(
        columnType: FieldType,
        columnLength: UInt32,
        raw: Bool,
        bigint: Bool,
        unsigned: Bool,
        binary: Bool,
        characterSet: UInt16,
        reader: MySQLPacketReader
    ): MySQLDataCell {
        let cell = MySQLDataCell()

        match (columnType) {
            case MYSQL_TYPE_TINY =>
                if (raw) {
                    let v = reader.readInt8()
                    cell.tag = DataCellTag.rawTag
                    cell.bytesValue = [v]
                } else {
                    let v = reader.readInt8()
                    cell.tag = if (unsigned) DataCellTag.uint4 else DataCellTag.int4
                    if (unsigned) { cell.uintValue = UInt64(v) } else { cell.intValue = Int64(Int8(v)) }
                }
            case MYSQL_TYPE_SHORT =>
                let v = reader.readInt16()
                cell.tag = if (unsigned) DataCellTag.uint4 else DataCellTag.int4
                if (unsigned) { cell.uintValue = UInt64(v) } else { cell.intValue = Int64(Int16(v)) }
            case MYSQL_TYPE_LONG =>
                let v = reader.readInt32()
                cell.tag = if (unsigned) DataCellTag.uint4 else DataCellTag.int4
                if (unsigned) { cell.uintValue = UInt64(v) } else { cell.intValue = Int64(Int32(v)) }
            case MYSQL_TYPE_LONGLONG =>
                let v = reader.readInt64()
                if (unsigned) {
                    if (bigint) {
                        cell.tag = DataCellTag.uint8
                        cell.uintValue = v
                    } else if (v <= UInt64(UInt32.MaxValue)) {
                        cell.tag = DataCellTag.uint4
                        cell.uintValue = v
                    } else {
                        cell.tag = DataCellTag.stringTag
                        cell.stringValue = v.toString()
                    }
                } else {
                    let sv = Int64(v)
                    if (bigint) {
                        cell.tag = DataCellTag.int8
                        cell.intValue = sv
                    } else if (sv >= Int64(Int32.MinValue) && sv <= Int64(Int32.MaxValue)) {
                        cell.tag = DataCellTag.int4
                        cell.intValue = sv
                    } else {
                        cell.tag = DataCellTag.stringTag
                        cell.stringValue = sv.toString()
                    }
                }
            case MYSQL_TYPE_FLOAT =>
                let bits = reader.readInt32()
                cell.tag = DataCellTag.float8
                cell.floatValue = Float32.fromBits(bits)
            case MYSQL_TYPE_DOUBLE =>
                let bits = reader.readInt64()
                cell.tag = DataCellTag.float8
                cell.floatValue = Float64.fromBits(bits)
            case MYSQL_TYPE_DATE =>
                let len = Int64(reader.readInt8())
                let data = reader.readBytes(len)
                let dt = MySQLDateTime.fromBinary(data.slice())
                cell.tag = DataCellTag.stringTag
                cell.stringValue = "${dt.year}-${dt.month}-${dt.day}"
            case MYSQL_TYPE_DATETIME =>
                let len = Int64(reader.readInt8())
                let data = reader.readBytes(len)
                let dt = MySQLDateTime.fromBinary(data.slice())
                cell.tag = DataCellTag.stringTag
                cell.stringValue = "${dt.year}-${dt.month}-${dt.day} ${dt.hour}:${dt.minute}:${dt.second}"
            case MYSQL_TYPE_TIMESTAMP =>
                let len = Int64(reader.readInt8())
                let data = reader.readBytes(len)
                let dt = MySQLDateTime.fromBinary(data.slice())
                cell.tag = DataCellTag.stringTag
                cell.stringValue = "${dt.year}-${dt.month}-${dt.day} ${dt.hour}:${dt.minute}:${dt.second}"
            case MYSQL_TYPE_TIME =>
                let len = Int64(reader.readInt8())
                let data = reader.readBytes(len)
                let t = MySQLTime.fromBinary(data.slice())
                cell.tag = DataCellTag.stringTag
                cell.stringValue = "${t.hours}:${t.minutes}:${t.seconds}"
            case _ =>
                // 长度编码字符串
                let strData = reader.readEncodedString()
                let slice = strData.slice()
                if (binary && characterSet == DecodeBinaryValue.BINARY_CHARSET) {
                    cell.tag = DataCellTag.rawTag
                    cell.bytesValue = slice
                } else {
                    cell.tag = DataCellTag.stringTag
                    cell.stringValue = stringFromBytes(slice)
                }
        }
        return cell
    }
}

// ============================================================================
// 字符串解析辅助函数
// ============================================================================

func stringFromBytes(bytes: Array<UInt8>): String {
    var s = ""
    for (b in bytes) {
        s += String(Char(b))
    }
    return s
}

func parseFloat64(s: String): Float64 {
    return Float64.parse(s).getOr(0.0)
}

func parseInt16(s: String): Int16 {
    return Int16.parse(s).getOr(Int16(0))
}

func parseUInt16(s: String): UInt16 {
    return UInt16.parse(s).getOr(UInt16(0))
}

func parseInt32(s: String): Int32 {
    return Int32.parse(s).getOr(Int32(0))
}

func parseUInt32(s: String): UInt32 {
    return UInt32.parse(s).getOr(UInt32(0))
}

func parseInt64(s: String): Int64 {
    return Int64.parse(s).getOr(Int64(0))
}

func parseUInt64(s: String): UInt64 {
    return UInt64.parse(s).getOr(UInt64(0))
}
