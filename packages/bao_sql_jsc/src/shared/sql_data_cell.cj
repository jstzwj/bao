// 严格翻译自: src/sql_jsc/shared/SQLDataCell.zig
// SQL 数据单元格 - 表示查询结果中单个值的类型化容器

package bao_sql_jsc.shared

import bao_core.*
import bao_jsc.*

/// SQL 数据单元格标签
/// 对应 Bun: SQLDataCell.Tag
public enum DataCellTag {
}

/// SQL 数据单元格
/// 对应 Bun: SQLDataCell
/// 用于在 SQL 查询结果和 JS 值之间传递类型化数据
public class SQLDataCell {
    public var tag: DataCellTag = DataCellTag.Null
    public var freeValue: UInt8 = 0
    public var isIndexedColumn: UInt8 = 0
    public var index: UInt32 = 0

    // 值存储
    public var nullValue: UInt8 = 0
    public var stringValue: ?String = None
    public var float8Value: Float64 = 0.0
    public var int4Value: Int32 = 0
    public var int8Value: Int64 = 0
    public var boolValue: UInt8 = 0
    public var dateValue: Float64 = 0.0
    public var dateWithTimeZoneValue: Float64 = 0.0
    public var byteaPtr: UInt64 = 0
    public var byteaLen: UInt64 = 0
    public var jsonValue: ?String = None
    public var arrayValue: ?DataCellArray = None
    public var typedArrayValue: ?DataCellTypedArray = None
    public var rawPtr: UInt64 = 0
    public var rawLen: UInt64 = 0
    public var uint4Value: UInt32 = 0
    public var uint8Value: UInt64 = 0

    public init() {}

    /// 从原始字节创建
    /// 对应 Bun: SQLDataCell.raw
    public static func raw(ptr: UInt64, len: UInt64): SQLDataCell {
        let cell = SQLDataCell()
        cell.tag = DataCellTag.Raw
        cell.rawPtr = ptr
        cell.rawLen = len
        return cell
    }

    /// 释放资源
    /// 对应 Bun: SQLDataCell.deinit
    public func deinit(): Unit {
        if (freeValue == 0) {
            return
        }
        match (tag) {
            | String =>
                // 释放字符串
                stringValue = None
            | Json =>
                jsonValue = None
            | Array =>
                if (arrayValue != None) {
                    for (cell in arrayValue.cells) {
                        cell.deinit()
                    }
                    arrayValue = None
                }
            | _ => ()
        }
    }
}

/// 数据单元格数组
/// 对应 Bun: SQLDataCell.Array
public class DataCellArray {
    public var cells: Array<SQLDataCell>
    public var len: UInt32
    public var cap: UInt32

    public init(cells: Array<SQLDataCell>, len: UInt32, cap: UInt32) {
        this.cells = cells
        this.len = len
        this.cap = cap
    }

    public func slice(): Array<SQLDataCell> {
        if (cells.size == 0) {
            return []
        }
        return cells[0..Int64(len)]
    }

    public func deinit(): Unit {
        cells = []
        len = 0
        cap = 0
    }
}

/// 数据单元格类型化数组
/// 对应 Bun: SQLDataCell.TypedArray
public class DataCellTypedArray {
    public var headPtr: UInt64 = 0
    public var ptr: UInt64 = 0
    public var len: UInt32 = 0
    public var byteLen: UInt32 = 0
    public var jsType: Int64 = 0

    public init() {}
}

/// 数据单元格标志
/// 对应 Bun: SQLDataCell.Flags
public class DataCellFlags {
    public var hasIndexedColumns: Bool = false
    public var hasNamedColumns: Bool = false
    public var hasDuplicateColumns: Bool = false

    public init() {}
}
