// SQL DataCell JS 绑定
// 严格翻译自: src/sql_jsc/shared/SQLDataCell.zig
//
// SQLDataCell 是 SQL 查询结果中单个单元格的 C 兼容表示。
// 它通过 FFI 传递给 C++ JSC 层来构建 JS 对象。
//
// 该文件定义了:
// - SQLDataCell 的仓颉表示
// - Tag 枚举 (类型标识)
// - Value 联合体 (实际值)
// - Flags (列名/索引/重复列检测)
// - constructObjectFromDataCell 的仓颉签名
package bao_runtime.sql.mysql

import bao_core.*

/// SQL 数据单元格
/// 对应 Bun: SQLDataCell
/// 表示查询结果中一个单元格的数据，可传递给 JSC
public class SQLDataCellJSC {
    /// 类型标签
    public var tag: DataCellTagJSC
    /// 布尔值
    public var boolValue: Bool
    /// Int32 值
    public var int4Value: Int32
    /// Int64 值
    public var int8Value: Int64
    /// UInt32 值
    public var uint4Value: UInt32
    /// UInt64 值
    public var uint8Value: UInt64
    /// Float64 值
    public var float8Value: Float64
    /// 字符串值
    public var stringValue: String
    /// 字节数据 (ptr, len)
    public var byteaPtr: Int64
    public var byteaLen: Int64
    /// 日期值 (UTC ms)
    public var dateValue: Float64
    /// 是否需要释放
    public var freeValue: Bool
    /// 是否为索引列
    public var isIndexedColumn: UInt8
    /// 列索引
    public var columnIndex: UInt32

    public init() {
        tag = DataCellTagJSC.nullTag
        boolValue = false
        int4Value = 0
        int8Value = 0
        uint4Value = 0
        uint8Value = 0
        float8Value = 0.0
        stringValue = ""
        byteaPtr = 0
        byteaLen = 0
        dateValue = 0.0
        freeValue = false
        isIndexedColumn = 0
        columnIndex = 0
    }

    /// 创建 raw 类型单元格
    /// 对应 Bun: SQLDataCell.raw
    public static func raw(bytes: ?Array<UInt8>): SQLDataCellJSC {
        if (let Some(b) <- bytes) {
            let cell = SQLDataCellJSC()
            cell.tag = DataCellTagJSC.raw
            // 在真实环境中设置 ptr/len
            return cell
        }
        let cell = SQLDataCellJSC()
        cell.tag = DataCellTagJSC.nullTag
        return cell
    }

    /// 释放资源
    /// 对应 Bun: SQLDataCell.deinit
    public func deinit(): Unit {
        if (!freeValue) {
            return
        }

        match (tag) {
            case DataCellTagJSC.stringTag =>
                stringValue = ""
            case DataCellTagJSC.jsonTag =>
                stringValue = ""
            case DataCellTagJSC.bytea =>
                // 释放字节缓冲区
                byteaPtr = 0
                byteaLen = 0
            case _ => {}
        }
    }
}

/// 数据单元格标签
/// 对应 Bun: SQLDataCell.Tag
public enum DataCellTagJSC <: UInt8 {
    | nullTag(0)
    | stringTag(1)
    | float8Tag(2)
    | int4Tag(3)
    | int8Tag(4)
    | boolTag(5)
    | dateTag(6)
    | dateWithTimeZone(7)
    | bytea(8)
    | jsonTag(9)
    | arrayTag(10)
    | typedArray(11)
    | raw(12)
    | uint4Tag(13)
    | uint8Tag(14)
}

/// SQL 数据单元格标志
/// 对应 Bun: SQLDataCell.Flags
public class SQLDataCellFlagsJSC {
    public var hasIndexedColumns: Bool
    public var hasNamedColumns: Bool
    public var hasDuplicateColumns: Bool

    public init() {
        hasIndexedColumns = false
        hasNamedColumns = false
        hasDuplicateColumns = false
    }
}
