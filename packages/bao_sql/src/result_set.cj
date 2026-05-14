// 严格翻译自: src/sql/result_set.zig
// SQL 结果集与行访问
package bao_sql

import bao_core.*
import bao_collections.*

// ============================================================================
// ColumnMeta — 列元数据
// 严格翻译自: src/sql/ColumnIdentifier.rs
// 对应 Bun: sqlite3_column_name / sqlite3_column_decltype
// ============================================================================

/// 列元数据
/// 对应 Bun: ColumnIdentifier 中的列描述信息
public class ColumnMeta {
    /// 列序号 (从 0 开始)
    public var index: Int64

    /// 列名
    /// 对应 Bun: sqlite3_column_name
    public var name: String

    /// 列声明类型 (如 "INTEGER", "TEXT", "REAL")
    /// 对应 Bun: sqlite3_column_decltype
    public var declaredType: String

    /// 列值的实际类型
    /// 对应 Bun: sqlite3_column_type
    public var actualType: SqlColumnType

    /// 是否允许 NULL
    public var nullable: Bool

    /// 所属表名 (如果可用)
    public var tableName: String

    /// 所属数据库名
    public var databaseName: String

    public init(index: Int64, name: String) {
        this.index = index
        this.name = name
        this.declaredType = ""
        this.actualType = SqlColumnType.Null
        this.nullable = true
        this.tableName = ""
        this.databaseName = ""
    }

    public init(index: Int64, name: String, declaredType: String) {
        this.index = index
        this.name = name
        this.declaredType = declaredType
        this.actualType = SqlColumnType.Null
        this.nullable = true
        this.tableName = ""
        this.databaseName = ""
    }

    public func toString(): String {
        return "ColumnMeta(${index}: ${name} ${declaredType})"
    }
}

/// SQL 列数据类型
/// 对应 Bun: sqlite3_column_type 返回值
public enum SqlColumnType {
    | Null
    | Integer
    | Float
    | Text
    | Blob

    public func toString(): String {
        match (this) {
            case Null => "NULL"
            case Integer => "INTEGER"
            case Float => "FLOAT"
            case Text => "TEXT"
            case Blob => "BLOB"
        }
    }

    /// 从 SQLite 类型码解析
    public static func fromSQLiteType(typeCode: Int32): SqlColumnType {
        match (typeCode) {
            case 1 => Integer   // SQLITE_INTEGER
            case 2 => Float     // SQLITE_FLOAT
            case 3 => Text      // SQLITE_TEXT
            case 4 => Blob      // SQLITE_BLOB
            case 5 => Null      // SQLITE_NULL
            case _ => Null
        }
    }
}

// ============================================================================
// Row — 结果集行
// 严格翻译自: src/sql/Data.rs
// 对应 Bun: bun:sqlite 查询返回的行数据
// ============================================================================

/// 结果集行
/// 对应 Bun: Statement.get() / Statement.all() 返回的单行数据
///
/// 行数据可以通过列索引或列名访问:
///   let row = Row(columns, values)
///   let id = row.getInt(0)
///   let name = row.getString("name")
public class Row {
    /// 列元数据
    private var columns: ArrayList<ColumnMeta>

    /// 列名 -> 索引 映射
    private var nameIndex: HashMap<String, Int64>

    /// 列值
    private var values: ArrayList<SqlValue>

    public init(columns: ArrayList<ColumnMeta>, values: ArrayList<SqlValue>) {
        this.columns = columns
        this.values = values
        this.nameIndex = HashMap<String, Int64>()
        // 建立列名索引
        for (i in 0..columns.size) {
            nameIndex.put(columns[i].name, Int64(i))
        }
    }

    public init() {
        columns = ArrayList<ColumnMeta>()
        values = ArrayList<SqlValue>()
        nameIndex = HashMap<String, Int64>()
    }

    /// 列数量
    public func columnCount(): Int64 {
        return columns.size
    }

    /// 获取列元数据
    public func getColumnMeta(index: Int64): ?ColumnMeta {
        if (index < 0 || index >= columns.size) {
            return None
        }
        return Some(columns[index])
    }

    /// 通过索引获取列元数据
    public func getColumnMeta(name: String): ?ColumnMeta {
        match (nameIndex.get(name)) {
            case Some(idx) => getColumnMeta(idx)
            case None => None
        }
    }

    /// 获取所有列名
    public func columnNames(): ArrayList<String> {
        let names = ArrayList<String>()
        for (col in columns) {
            names.append(col.name)
        }
        return names
    }

    // ---- 按索引访问值 ----

    /// 获取原始 SQL 值
    /// 对应 Bun: row[columnIndex]
    public func getValue(index: Int64): ?SqlValue {
        if (index < 0 || index >= values.size) {
            return None
        }
        return Some(values[index])
    }

    /// 获取 Int64 值
    /// 对应 Bun: Number(row[columnIndex])
    public func getInt(index: Int64): Int64 {
        match (getValue(index)) {
            case Some(SqlValue.Integer(v)) => v
            case Some(SqlValue.Float(v)) => Int64(v)
            case Some(SqlValue.Text(v)) => {
                // 尝试解析字符串为整数
                match (Int64.parse(v)) {
                    case Some(n) => n
                    case None => 0
                }
            }
            case _ => 0
        }
    }

    /// 获取 Float64 值
    public func getFloat(index: Int64): Float64 {
        match (getValue(index)) {
            case Some(SqlValue.Float(v)) => v
            case Some(SqlValue.Integer(v)) => Float64(v)
            case Some(SqlValue.Text(v)) => {
                match (Float64.parse(v)) {
                    case Some(n) => n
                    case None => 0.0
                }
            }
            case _ => 0.0
        }
    }

    /// 获取 String 值
    /// 对应 Bun: String(row[columnIndex])
    public func getString(index: Int64): String {
        match (getValue(index)) {
            case Some(SqlValue.Text(v)) => v
            case Some(SqlValue.Integer(v)) => v.toString()
            case Some(SqlValue.Float(v)) => v.toString()
            case Some(SqlValue.Blob(_)) => "[BLOB]"
            case Some(SqlValue.Null) => ""
            case None => ""
        }
    }

    /// 获取 Blob 值
    /// 对应 Bun: Buffer.from(row[columnIndex])
    public func getBlob(index: Int64): Array<UInt8> {
        match (getValue(index)) {
            case Some(SqlValue.Blob(v)) => v
            case Some(SqlValue.Text(v)) => {
                var result = Array<UInt8>()
                for (c in v) {
                    result.append(UInt8(c.value))
                }
                return result
            }
            case _ => Array<UInt8>()
        }
    }

    /// 获取 Bool 值
    /// 对应 Bun: Boolean(row[columnIndex])
    public func getBool(index: Int64): Bool {
        match (getValue(index)) {
            case Some(SqlValue.Integer(v)) => v != 0
            case Some(SqlValue.Float(v)) => v != 0.0
            case Some(SqlValue.Text(v)) => v == "1" || v == "true" || v == "yes"
            case _ => false
        }
    }

    /// 是否为 NULL
    /// 对应 Bun: row[columnIndex] === null
    public func isNull(index: Int64): Bool {
        match (getValue(index)) {
            case Some(SqlValue.Null) => true
            case None => true
            case _ => false
        }
    }

    // ---- 按列名访问值 ----

    /// 获取原始 SQL 值 (按列名)
    public func getValue(name: String): ?SqlValue {
        match (nameIndex.get(name)) {
            case Some(idx) => getValue(idx)
            case None => None
        }
    }

    /// 获取 Int64 值 (按列名)
    public func getInt(name: String): Int64 {
        match (nameIndex.get(name)) {
            case Some(idx) => getInt(idx)
            case None => 0
        }
    }

    /// 获取 Float64 值 (按列名)
    public func getFloat(name: String): Float64 {
        match (nameIndex.get(name)) {
            case Some(idx) => getFloat(idx)
            case None => 0.0
        }
    }

    /// 获取 String 值 (按列名)
    public func getString(name: String): String {
        match (nameIndex.get(name)) {
            case Some(idx) => getString(idx)
            case None => ""
        }
    }

    /// 获取 Blob 值 (按列名)
    public func getBlob(name: String): Array<UInt8> {
        match (nameIndex.get(name)) {
            case Some(idx) => getBlob(idx)
            case None => Array<UInt8>()
        }
    }

    /// 获取 Bool 值 (按列名)
    public func getBool(name: String): Bool {
        match (nameIndex.get(name)) {
            case Some(idx) => getBool(idx)
            case None => false
        }
    }

    /// 是否为 NULL (按列名)
    public func isNull(name: String): Bool {
        match (nameIndex.get(name)) {
            case Some(idx) => isNull(idx)
            case None => true
        }
    }

    // ---- 类型安全访问 ----

    /// 安全获取值，指定默认值
    public func getIntOrDefault(index: Int64, default: Int64): Int64 {
        if (isNull(index)) { return default }
        return getInt(index)
    }

    public func getFloatOrDefault(index: Int64, default: Float64): Float64 {
        if (isNull(index)) { return default }
        return getFloat(index)
    }

    public func getStringOrDefault(index: Int64, default: String): String {
        if (isNull(index)) { return default }
        return getString(index)
    }

    public func getIntOrDefault(name: String, default: Int64): Int64 {
        if (isNull(name)) { return default }
        return getInt(name)
    }

    public func getStringOrDefault(name: String, default: String): String {
        if (isNull(name)) { return default }
        return getString(name)
    }

    /// 转为 HashMap (列名 -> 值)
    /// 对应 Bun: Object.fromEntries(row)
    public func toMap(): HashMap<String, SqlValue> {
        let map = HashMap<String, SqlValue>()
        for (i in 0..columns.size) {
            map.put(columns[i].name, values[i])
        }
        return map
    }

    /// 转为 JSON 格式字符串
    public func toJson(): String {
        var parts = ArrayList<String>()
        for (i in 0..columns.size) {
            let val = match (values[i]) {
                case SqlValue.Null => "null"
                case SqlValue.Integer(v) => v.toString()
                case SqlValue.Float(v) => v.toString()
                case SqlValue.Text(v) => "\"${v}\""
                case SqlValue.Blob(_) => "null"
            }
            parts.append("\"${columns[i].name}\": ${val}")
        }
        return "{" + parts.toArray().join(", ") + "}"
    }

    /// 转为数组
    public func toArray(): Array<SqlValue> {
        return values.toArray()
    }

    public func toString(): String {
        return toJson()
    }
}

// ============================================================================
// ResultSet — 完整结果集
// 严格翻译自: src/sql/SqlResult
// 对应 Bun: Statement.all() 返回的完整查询结果
// ============================================================================

/// 查询结果集
/// 对应 Bun: bun:sqlite Statement.all() 返回值
///
/// 包含列元数据和所有行的数据，支持迭代访问:
///   let rs = ResultSet(columns, rows)
///   while (rs.hasNext()) {
///       let row = rs.next()
///       println(row.getString("name"))
///   }
public class ResultSet {
    /// 列元数据列表
    private var columnMetas: ArrayList<ColumnMeta>

    /// 所有行数据
    private var rows: ArrayList<Row>

    /// 当前迭代位置
    private var cursor: Int64

    /// 受影响的行数 (非 SELECT 操作)
    public var changes: Int64

    /// 最后插入行 ID
    public var lastInsertRowId: Int64

    public init() {
        columnMetas = ArrayList<ColumnMeta>()
        rows = ArrayList<Row>()
        cursor = 0
        changes = 0
        lastInsertRowId = 0
    }

    public init(columnMetas: ArrayList<ColumnMeta>, rows: ArrayList<Row>) {
        this.columnMetas = columnMetas
        this.rows = rows
        this.cursor = 0
        this.changes = 0
        this.lastInsertRowId = 0
    }

    /// 列数量
    public func columnCount(): Int64 {
        return columnMetas.size
    }

    /// 行数量
    public func rowCount(): Int64 {
        return rows.size
    }

    /// 获取列元数据
    public func getColumn(index: Int64): ?ColumnMeta {
        if (index < 0 || index >= columnMetas.size) {
            return None
        }
        return Some(columnMetas[index])
    }

    /// 获取所有列名
    public func columnNames(): ArrayList<String> {
        let names = ArrayList<String>()
        for (col in columnMetas) {
            names.append(col.name)
        }
        return names
    }

    /// 通过索引获取行
    public func getRow(index: Int64): ?Row {
        if (index < 0 || index >= rows.size) {
            return None
        }
        return Some(rows[index])
    }

    /// 获取第一行
    /// 对应 Bun: Statement.get()
    public func first(): ?Row {
        if (rows.size > 0) {
            return Some(rows[0])
        }
        return None
    }

    /// 获取第一行第一列的标量值
    /// 对应 Bun: Statement.getValue()
    public func scalar(): ?SqlValue {
        match (first()) {
            case Some(row) => row.getValue(0)
            case None => None
        }
    }

    /// 获取所有行
    /// 对应 Bun: Statement.all()
    public func all(): ArrayList<Row> {
        return rows
    }

    /// 转为 JSON 数组字符串
    public func toJson(): String {
        var parts = ArrayList<String>()
        for (row in rows) {
            parts.append(row.toJson())
        }
        return "[" + parts.toArray().join(", ") + "]"
    }

    // ---- 迭代器接口 ----

    /// 是否有下一行
    public func hasNext(): Bool {
        return cursor < rows.size
    }

    /// 获取下一行
    public func next(): ?Row {
        if (cursor >= rows.size) {
            return None
        }
        let row = rows[cursor]
        cursor += 1
        return Some(row)
    }

    /// 重置游标
    public func reset(): Unit {
        cursor = 0
    }

    /// 获取迭代器
    public func iterator(): Iterator<Row> {
        return ResultSetIterator(rows)
    }
}

/// ResultSet 迭代器
class ResultSetIterator <: Iterator<Row> {
    private var rows: ArrayList<Row>
    private var pos: Int64

    public init(rows: ArrayList<Row>) {
        this.rows = rows
        this.pos = 0
    }

    public func hasNext(): Bool {
        return pos < rows.size
    }

    public func next(): Row {
        let row = rows[pos]
        pos += 1
        return row
    }
}
