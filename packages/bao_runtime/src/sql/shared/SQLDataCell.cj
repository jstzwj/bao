// SQL 数据单元格 — PostgreSQL 数据类型到 JS 值的转换核心
// 严格翻译自: bun/src/sql_jsc/shared/SQLDataCell.zig
//   pub const SQLDataCell = extern struct { tag: Tag, value: Value, ... };
package bao_runtime.sql.shared

/// SQL 数据单元格标签
/// 标识单元格中存储的数据类型
/// 对应 Bun SQLDataCell.Tag (enum u8)
public enum SQLDataCellTag {
    | Null
    | String_
    | Float8
    | Int4
    | Int8_
    | Bool_
    | Date
    | DateWithTimeZone
    | Bytea
    | Json
    | Array_
    | TypedArray
    | Raw
    | UInt4_
    | UInt8_
}

/// SQL 数据单元格 — 将 PostgreSQL/MySQL 数据类型存储为可转换的中间表示
/// 对应 Bun SQLDataCell (extern struct)
public class SQLDataCell {
    /// 数据类型标签
    public var tag: SQLDataCellTag
    /// 是否需要释放值内存
    public var freeValue: UInt8
    /// 是否为索引列 (0=命名, 1=索引, 2=重复)
    public var isIndexedColumn: UInt8
    /// 列索引
    public var columnIndex: UInt32

    // 值存储 — 使用类成员变量代替 Zig 的 extern union
    // 因为仓颉没有 C 风格的 union
    public var nullValue: UInt8
    public var stringValue: ?String
    public var float8Value: Float64
    public var int4Value: Int32
    public var int8Value: Int64
    public var boolValue: UInt8
    public var dateValue: Float64
    public var dateWithTimeZoneValue: Float64
    public var byteaPtr: Array<UInt8>
    public var jsonValue: ?String
    public var arrayValue: SQLDataCellArray
    public var typedArrayValue: SQLDataCellTypedArray
    public var rawValue: SQLDataCellRaw
    public var uint4Value: UInt32
    public var uint8Value: UInt64

    public init() {
        tag = SQLDataCellTag.Null
        freeValue = 0
        isIndexedColumn = 0
        columnIndex = 0
        nullValue = 0
        stringValue = None
        float8Value = 0.0
        int4Value = 0
        int8Value = 0
        boolValue = 0
        dateValue = 0.0
        dateWithTimeZoneValue = 0.0
        byteaPtr = Array<UInt8>()
        jsonValue = None
        arrayValue = SQLDataCellArray()
        typedArrayValue = SQLDataCellTypedArray()
        rawValue = SQLDataCellRaw()
        uint4Value = 0
        uint8Value = 0
    }

    /// 创建 null 单元格
    public static func nullCell(): SQLDataCell {
        let cell = SQLDataCell()
        cell.tag = SQLDataCellTag.Null
        cell.nullValue = 0
        return cell
    }

    /// 从字符串创建
    public static func fromString(s: ?String): SQLDataCell {
        let cell = SQLDataCell()
        cell.tag = SQLDataCellTag.String_
        cell.stringValue = s
        cell.freeValue = 1
        return cell
    }

    /// 从 Float64 创建
    public static func fromFloat64(v: Float64): SQLDataCell {
        let cell = SQLDataCell()
        cell.tag = SQLDataCellTag.Float8
        cell.float8Value = v
        return cell
    }

    /// 从 Int32 创建
    public static func fromInt32(v: Int32): SQLDataCell {
        let cell = SQLDataCell()
        cell.tag = SQLDataCellTag.Int4
        cell.int4Value = v
        return cell
    }

    /// 从 Int64 创建
    public static func fromInt64(v: Int64): SQLDataCell {
        let cell = SQLDataCell()
        cell.tag = SQLDataCellTag.Int8_
        cell.int8Value = v
        return cell
    }

    /// 从 Bool 创建
    public static func fromBool(b: Bool): SQLDataCell {
        let cell = SQLDataCell()
        cell.tag = SQLDataCellTag.Bool_
        cell.boolValue = if (b) { UInt8(1) } else { UInt8(0) }
        return cell
    }

    /// 从日期创建
    public static func fromDate(v: Float64): SQLDataCell {
        let cell = SQLDataCell()
        cell.tag = SQLDataCellTag.Date
        cell.dateValue = v
        return cell
    }

    /// 从带时区日期创建
    public static func fromDateWithTimeZone(v: Float64): SQLDataCell {
        let cell = SQLDataCell()
        cell.tag = SQLDataCellTag.DateWithTimeZone
        cell.dateWithTimeZoneValue = v
        return cell
    }

    /// 从 JSON 字符串创建
    public static func fromJson(s: ?String): SQLDataCell {
        let cell = SQLDataCell()
        cell.tag = SQLDataCellTag.Json
        cell.jsonValue = s
        cell.freeValue = 1
        return cell
    }

    /// 从 bytea 创建
    public static func fromBytea(bytes: Array<UInt8>): SQLDataCell {
        let cell = SQLDataCell()
        cell.tag = SQLDataCellTag.Bytea
        cell.byteaPtr = bytes
        return cell
    }

    /// 从原始数据创建
    /// 对应 Bun SQLDataCell.raw()
    public static func fromRaw(data: ?Array<UInt8>): SQLDataCell {
        if (let Some(bytes) <- data) {
            let cell = SQLDataCell()
            cell.tag = SQLDataCellTag.Raw
            cell.rawValue = SQLDataCellRaw(bytes)
            return cell
        }
        let cell = SQLDataCell()
        cell.tag = SQLDataCellTag.Null
        cell.nullValue = UInt8(0)
        return cell
    }

    /// 释放资源
    /// 对应 Bun SQLDataCell.deinit()
    public func deinit() {
        if (freeValue == 0) {
            return
        }
        match (tag) {
            case SQLDataCellTag.String_ =>
                stringValue = None
            case SQLDataCellTag.Json =>
                jsonValue = None
            case SQLDataCellTag.Bytea =>
                byteaPtr = Array<UInt8>()
            case SQLDataCellTag.Array_ =>
                for (cell in arrayValue.cells) {
                    cell.deinit()
                }
                arrayValue.deinit()
            case SQLDataCellTag.TypedArray =>
                typedArrayValue.deinit()
            case _ => ()
        }
        freeValue = 0
    }

    /// 转为 JS 值
    /// 对应 Bun 中通过 JSC__constructObjectFromDataCell 实现的逻辑
    public func toJSValue(): JSCellValue {
        match (tag) {
            case SQLDataCellTag.Null => JSCellValue.Null
            case SQLDataCellTag.String_ =>
                match (stringValue) {
                    case Some(s) => JSCellValue.String_(s)
                    case None => JSCellValue.String_("")
                }
            case SQLDataCellTag.Float8 => JSCellValue.Float64_(float8Value)
            case SQLDataCellTag.Int4 => JSCellValue.Int32_(int4Value)
            case SQLDataCellTag.Int8_ => JSCellValue.Int64_(int8Value)
            case SQLDataCellTag.Bool_ => JSCellValue.Bool_(boolValue != UInt8(0))
            case SQLDataCellTag.Date => JSCellValue.Date(dateValue)
            case SQLDataCellTag.DateWithTimeZone => JSCellValue.DateWithTimeZone(dateWithTimeZoneValue)
            case SQLDataCellTag.Bytea => JSCellValue.Bytea(byteaPtr)
            case SQLDataCellTag.Json =>
                match (jsonValue) {
                    case Some(s) => JSCellValue.Json(s)
                    case None => JSCellValue.Null
                }
            case SQLDataCellTag.Array_ => JSCellValue.Array_(arrayValue)
            case SQLDataCellTag.TypedArray => JSCellValue.TypedArray(typedArrayValue)
            case SQLDataCellTag.Raw => JSCellValue.Raw(rawValue)
            case SQLDataCellTag.UInt4_ => JSCellValue.UInt32_(uint4Value)
            case SQLDataCellTag.UInt8_ => JSCellValue.UInt64_(uint8Value)
        }
    }
}

/// SQL 数据单元格数组
/// 对应 Bun SQLDataCell.Array (extern struct)
public class SQLDataCellArray {
    public var cells: Array<SQLDataCell>
    public var capacity: Int64

    public init() {
        cells = Array<SQLDataCell>()
        capacity = 0
    }

    public init(cells: Array<SQLDataCell>) {
        this.cells = cells
        capacity = cells.size
    }

    /// 获取切片
    public func slice(): Array<SQLDataCell> {
        cells
    }

    /// 释放
    public func deinit() {
        cells = Array<SQLDataCell>()
        capacity = 0
    }
}

/// SQL 数据单元格类型化数组
/// 对应 Bun SQLDataCell.TypedArray (extern struct)
public class SQLDataCellTypedArray {
    public var headPtr: Array<UInt8>
    public var ptr: Array<UInt8>
    public var len: UInt32
    public var byteLen: UInt32
    /// JS TypedArray 类型
    public var jsType: JSTypedArrayType

    public init() {
        headPtr = Array<UInt8>()
        ptr = Array<UInt8>()
        len = 0
        byteLen = 0
        jsType = JSTypedArrayType.Int32Array
    }

    public init(headPtr: Array<UInt8>, ptr: Array<UInt8>, len: UInt32, byteLen: UInt32, jsType: JSTypedArrayType) {
        this.headPtr = headPtr
        this.ptr = ptr
        this.len = len
        this.byteLen = byteLen
        this.jsType = jsType
    }

    public func deinit() {
        headPtr = Array<UInt8>()
        ptr = Array<UInt8>()
        len = 0
        byteLen = 0
    }
}

/// JS TypedArray 类型
/// 对应 Bun JSValue.JSType 中的类型化数组类型
public enum JSTypedArrayType {
    | Int32Array
    | Float32Array
    | Float64Array
    | Uint8Array
    | Uint8ClampedArray
    | Int8Array
    | Uint16Array
    | Int16Array
    | Uint32Array
}

/// SQL 数据单元格原始数据
/// 对应 Bun SQLDataCell.Raw (extern struct)
public class SQLDataCellRaw {
    public var data: Array<UInt8>

    public init() {
        data = Array<UInt8>()
    }

    public init(data: Array<UInt8>) {
        this.data = data
    }
}

/// SQL 数据单元格列标志
/// 对应 Bun SQLDataCell.Flags (packed struct u32)
public class SQLDataCellFlags {
    public var hasIndexedColumns: Bool
    public var hasNamedColumns: Bool
    public var hasDuplicateColumns: Bool

    public init() {
        hasIndexedColumns = false
        hasNamedColumns = false
        hasDuplicateColumns = false
    }
}

/// JS 单元格值 — toJSValue 的返回类型
/// 表示 SQL 数据在 JS 世界中的表现形式
public enum JSCellValue {
    | Null
    | String_(String)
    | Float64_(Float64)
    | Int32_(Int32)
    | Int64_(Int64)
    | Bool_(Bool)
    | Date(Float64)
    | DateWithTimeZone(Float64)
    | Bytea(Array<UInt8>)
    | Json(String)
    | Array_(SQLDataCellArray)
    | TypedArray(SQLDataCellTypedArray)
    | Raw(SQLDataCellRaw)
    | UInt32_(UInt32)
    | UInt64_(UInt64)
}
