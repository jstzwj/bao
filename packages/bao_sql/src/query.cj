// 严格翻译自: src/sql/query.zig
// SQL 查询构建器
package bao_sql

import bao_core.*
import bao_collections.*

// ============================================================================
// QueryBuilder — SQL 查询构建器
// 严格翻译自: src/sql/query.zig
// 对应 Bun: bun:sqlite 中的查询构建辅助功能
//
// 设计思路:
//   Bun 的 bun:sqlite 模块本身不提供查询构建器，而是直接使用 SQL 字符串。
//   但 Bun 的 ORM 替代方案 (如 Drizzle) 会使用查询构建模式。
//   此处提供基础的查询构建器作为工具，方便使用。
// ============================================================================

/// SQL 查询类型
/// 对应 Bun: SQL 语句分类
public enum QueryType {
    | Select
    | Insert
    | Update
    | Delete
    | Raw

    public func toString(): String {
        match (this) {
            case Select => "SELECT"
            case Insert => "INSERT"
            case Update => "UPDATE"
            case Delete => "DELETE"
            case Raw => "RAW"
        }
    }
}

/// JOIN 类型
public enum JoinType {
    | Inner
    | Left
    | Right
    | Full
    | Cross

    public func toString(): String {
        match (this) {
            case Inner => "INNER JOIN"
            case Left => "LEFT JOIN"
            case Right => "RIGHT JOIN"
            case Full => "FULL JOIN"
            case Cross => "CROSS JOIN"
        }
    }
}

/// ORDER BY 方向
public enum OrderDirection {
    | Asc
    | Desc

    public func toString(): String {
        match (this) {
            case Asc => "ASC"
            case Desc => "DESC"
        }
    }
}

/// WHERE 条件运算符
public enum WhereOperator {
    | Eq          // =
    | Ne          // !=
    | Lt          // <
    | Gt          // >
    | Le          // <=
    | Ge          // >=
    | Like        // LIKE
    | NotLike     // NOT LIKE
    | In          // IN
    | NotIn       // NOT IN
    | IsNull      // IS NULL
    | IsNotNull   // IS NOT NULL
    | Between     // BETWEEN

    public func toString(): String {
        match (this) {
            case Eq => "="
            case Ne => "!="
            case Lt => "<"
            case Gt => ">"
            case Le => "<="
            case Ge => ">="
            case Like => "LIKE"
            case NotLike => "NOT LIKE"
            case In => "IN"
            case NotIn => "NOT IN"
            case IsNull => "IS NULL"
            case IsNotNull => "IS NOT NULL"
            case Between => "BETWEEN"
        }
    }
}

/// WHERE 条件
class WhereClause {
    public var column: String
    public var op: WhereOperator
    public var value: SqlValue
    public var andOr: String  // "AND" | "OR" | ""

    public init(column: String, op: WhereOperator, value: SqlValue) {
        this.column = column
        this.op = op
        this.value = value
        this.andOr = "AND"
    }
}

/// JOIN 子句
class JoinClause {
    public var type_: JoinType
    public var table: String
    public var onLeft: String
    public var onRight: String

    public init(type_: JoinType, table: String, onLeft: String, onRight: String) {
        this.type_ = type_
        this.table = table
        this.onLeft = onLeft
        this.onRight = onRight
    }
}

/// ORDER BY 子句
class OrderByClause {
    public var column: String
    public var direction: OrderDirection

    public init(column: String, direction: OrderDirection) {
        this.column = column
        this.direction = direction
    }
}

/// SQL 查询构建器
/// 对应 Bun: 查询构建辅助工具
///
/// 示例:
///   let sql = QueryBuilder()
///       .select(["id", "name", "email"])
///       .from("users")
///       .where("age", WhereOperator.Ge, SqlValue.Integer(18))
///       .orderBy("name", OrderDirection.Asc)
///       .limit(10)
///       .build()
///   // sql = "SELECT id, name, email FROM users WHERE age >= 18 ORDER BY name ASC LIMIT 10"
public class QueryBuilder {
    /// 查询类型
    private var queryType: QueryType

    /// SELECT 列
    private var selectColumns: ArrayList<String>

    /// FROM 表名
    private var table_: String

    /// INSERT 列与值
    private var insertColumns: ArrayList<String>
    private var insertValues: ArrayList<SqlValue>

    /// UPDATE 列与值
    private var updateSets: ArrayList<(String, SqlValue)>

    /// WHERE 条件
    private var whereClauses: ArrayList<WhereClause>

    /// JOIN 子句
    private var joinClauses: ArrayList<JoinClause>

    /// ORDER BY 子句
    private var orderByClauses: ArrayList<OrderByClause>

    /// GROUP BY 列
    private var groupByColumns: ArrayList<String>

    /// HAVING 条件
    private var havingClauses: ArrayList<WhereClause>

    /// LIMIT
    private var limitValue: ?Int64

    /// OFFSET
    private var offsetValue: ?Int64

    /// DISTINCT
    private var distinct_: Bool

    /// 原始 SQL
    private var rawSQL: String

    /// 参数值 (参数化查询)
    private var params_: ArrayList<SqlValue>

    /// 参数占位符索引
    private var paramIndex: Int64

    public init() {
        queryType = QueryType.Select
        selectColumns = ArrayList<String>()
        table_ = ""
        insertColumns = ArrayList<String>()
        insertValues = ArrayList<SqlValue>()
        updateSets = ArrayList<(String, SqlValue)>()
        whereClauses = ArrayList<WhereClause>()
        joinClauses = ArrayList<JoinClause>()
        orderByClauses = ArrayList<OrderByClause>()
        groupByColumns = ArrayList<String>()
        havingClauses = ArrayList<WhereClause>()
        limitValue = None
        offsetValue = None
        distinct_ = false
        rawSQL = ""
        params_ = ArrayList<SqlValue>()
        paramIndex = 1
    }

    /// SELECT 子句
    /// 对应 SQL: SELECT col1, col2, ...
    public func select(columns: Array<String>): QueryBuilder {
        queryType = QueryType.Select
        for (col in columns) {
            selectColumns.append(col)
        }
        return this
    }

    /// SELECT 单列
    public func select(column: String): QueryBuilder {
        queryType = QueryType.Select
        selectColumns.append(column)
        return this
    }

    /// SELECT * (所有列)
    public func selectAll(): QueryBuilder {
        queryType = QueryType.Select
        selectColumns.append("*")
        return this
    }

    /// SELECT DISTINCT
    public func distinct(): QueryBuilder {
        distinct_ = true
        return this
    }

    /// FROM 子句
    /// 对应 SQL: FROM table
    public func from(table: String): QueryBuilder {
        table_ = table
        return this
    }

    /// 表名别名
    public func from(table: String, alias: String): QueryBuilder {
        table_ = "${table} AS ${alias}"
        return this
    }

    /// INSERT INTO
    /// 对应 SQL: INSERT INTO table (col1, col2) VALUES (?, ?)
    public func insert(table: String): QueryBuilder {
        queryType = QueryType.Insert
        table_ = table
        return this
    }

    /// 设置 INSERT 的列和值
    public func values(data: ArrayList<(String, SqlValue)>): QueryBuilder {
        for ((col, val) in data) {
            insertColumns.append(col)
            insertValues.append(val)
        }
        return this
    }

    /// UPDATE
    /// 对应 SQL: UPDATE table SET col1 = ?, col2 = ?
    public func update(table: String): QueryBuilder {
        queryType = QueryType.Update
        table_ = table
        return this
    }

    /// 设置 UPDATE 的列
    public func set(column: String, value: SqlValue): QueryBuilder {
        updateSets.append((column, value))
        return this
    }

    /// DELETE FROM
    /// 对应 SQL: DELETE FROM table
    public func delete(table: String): QueryBuilder {
        queryType = QueryType.Delete
        table_ = table
        return this
    }

    /// WHERE 条件 (AND 连接)
    /// 对应 SQL: WHERE column = value
    public func where(column: String, op: WhereOperator, value: SqlValue): QueryBuilder {
        let clause = WhereClause(column, op, value)
        if (whereClauses.size > 0) {
            clause.andOr = "AND"
        }
        whereClauses.append(clause)
        params_.append(value)
        return this
    }

    /// WHERE 等于简写
    public func where(column: String, value: SqlValue): QueryBuilder {
        return where(column, WhereOperator.Eq, value)
    }

    /// OR WHERE 条件
    public func orWhere(column: String, op: WhereOperator, value: SqlValue): QueryBuilder {
        let clause = WhereClause(column, op, value)
        clause.andOr = "OR"
        whereClauses.append(clause)
        params_.append(value)
        return this
    }

    /// WHERE NULL
    public func whereNull(column: String): QueryBuilder {
        let clause = WhereClause(column, WhereOperator.IsNull, SqlValue.Null)
        if (whereClauses.size > 0) { clause.andOr = "AND" }
        whereClauses.append(clause)
        return this
    }

    /// WHERE NOT NULL
    public func whereNotNull(column: String): QueryBuilder {
        let clause = WhereClause(column, WhereOperator.IsNotNull, SqlValue.Null)
        if (whereClauses.size > 0) { clause.andOr = "AND" }
        whereClauses.append(clause)
        return this
    }

    /// JOIN 子句
    /// 对应 SQL: INNER JOIN table ON left = right
    public func join(table: String, onLeft: String, onRight: String): QueryBuilder {
        joinClauses.append(JoinClause(JoinType.Inner, table, onLeft, onRight))
        return this
    }

    /// LEFT JOIN
    public func leftJoin(table: String, onLeft: String, onRight: String): QueryBuilder {
        joinClauses.append(JoinClause(JoinType.Left, table, onLeft, onRight))
        return this
    }

    /// RIGHT JOIN
    public func rightJoin(table: String, onLeft: String, onRight: String): QueryBuilder {
        joinClauses.append(JoinClause(JoinType.Right, table, onLeft, onRight))
        return this
    }

    /// CROSS JOIN
    public func crossJoin(table: String): QueryBuilder {
        joinClauses.append(JoinClause(JoinType.Cross, table, "", ""))
        return this
    }

    /// ORDER BY
    /// 对应 SQL: ORDER BY column ASC/DESC
    public func orderBy(column: String, direction: OrderDirection): QueryBuilder {
        orderByClauses.append(OrderByClause(column, direction))
        return this
    }

    /// ORDER BY ASC 简写
    public func orderBy(column: String): QueryBuilder {
        return orderBy(column, OrderDirection.Asc)
    }

    /// GROUP BY
    /// 对应 SQL: GROUP BY col1, col2
    public func groupBy(columns: Array<String>): QueryBuilder {
        for (col in columns) {
            groupByColumns.append(col)
        }
        return this
    }

    /// GROUP BY 单列
    public func groupBy(column: String): QueryBuilder {
        groupByColumns.append(column)
        return this
    }

    /// HAVING 条件
    /// 对应 SQL: HAVING condition
    public func having(column: String, op: WhereOperator, value: SqlValue): QueryBuilder {
        havingClauses.append(WhereClause(column, op, value))
        params_.append(value)
        return this
    }

    /// LIMIT
    /// 对应 SQL: LIMIT n
    public func limit(count: Int64): QueryBuilder {
        limitValue = Some(count)
        return this
    }

    /// OFFSET
    /// 对应 SQL: OFFSET n
    public func offset(count: Int64): QueryBuilder {
        offsetValue = Some(count)
        return this
    }

    /// 原始 SQL
    /// 对应 Bun: 直接执行原始 SQL
    public func raw(sql: String): QueryBuilder {
        queryType = QueryType.Raw
        rawSQL = sql
        return this
    }

    /// 构建 SQL 字符串
    /// 对应 Bun: 生成最终 SQL 文本
    public func build(): String {
        match (queryType) {
            case QueryType.Select => buildSelect()
            case QueryType.Insert => buildInsert()
            case QueryType.Update => buildUpdate()
            case QueryType.Delete => buildDelete()
            case QueryType.Raw => rawSQL
        }
    }

    /// 获取参数列表 (参数化查询)
    public func params(): ArrayList<SqlValue> {
        return params_
    }

    /// 构建 SELECT 语句
    private func buildSelect(): String {
        var sql = StringBuilder()
        sql.append("SELECT ")
        if (distinct_) {
            sql.append("DISTINCT ")
        }
        if (selectColumns.size == 0) {
            sql.append("*")
        } else {
            sql.append(joinStrings(selectColumns, ", "))
        }
        sql.append(" FROM ")
        sql.append(table_)

        buildJoins(sql)
        buildWhere(sql)
        buildGroupBy(sql)
        buildHaving(sql)
        buildOrderBy(sql)
        buildLimitOffset(sql)

        return sql.toString()
    }

    /// 构建 INSERT 语句
    private func buildInsert(): String {
        var sql = StringBuilder()
        sql.append("INSERT INTO ")
        sql.append(table_)
        sql.append(" (")

        // 列名
        for (i in 0..insertColumns.size) {
            if (i > 0) { sql.append(", ") }
            sql.append(insertColumns[i])
        }
        sql.append(") VALUES (")

        // 参数占位符
        for (i in 0..insertValues.size) {
            if (i > 0) { sql.append(", ") }
            sql.append("?")
        }
        sql.append(")")

        return sql.toString()
    }

    /// 构建 UPDATE 语句
    private func buildUpdate(): String {
        var sql = StringBuilder()
        sql.append("UPDATE ")
        sql.append(table_)
        sql.append(" SET ")

        for (i in 0..updateSets.size) {
            if (i > 0) { sql.append(", ") }
            let (col, _) = updateSets[i]
            sql.append(col)
            sql.append(" = ?")
        }

        buildWhere(sql)

        return sql.toString()
    }

    /// 构建 DELETE 语句
    private func buildDelete(): String {
        var sql = StringBuilder()
        sql.append("DELETE FROM ")
        sql.append(table_)

        buildWhere(sql)

        return sql.toString()
    }

    /// 构建 WHERE 子句
    private func buildWhere(sql: StringBuilder): Unit {
        if (whereClauses.size == 0) { return }
        sql.append(" WHERE ")

        for (i in 0..whereClauses.size) {
            let clause = whereClauses[i]
            if (i > 0) {
                sql.append(" ")
                sql.append(clause.andOr)
                sql.append(" ")
            }
            match (clause.op) {
                case WhereOperator.IsNull =>
                    sql.append("${clause.column} IS NULL")
                case WhereOperator.IsNotNull =>
                    sql.append("${clause.column} IS NOT NULL")
                case WhereOperator.In | WhereOperator.NotIn =>
                    let opStr = clause.op.toString()
                    sql.append("${clause.column} ${opStr} (?)")
                case WhereOperator.Between =>
                    sql.append("${clause.column} BETWEEN ? AND ?")
                case _ =>
                    sql.append("${clause.column} ${clause.op.toString()} ?")
            }
        }
    }

    /// 构建 JOIN 子句
    private func buildJoins(sql: StringBuilder): Unit {
        for (clause in joinClauses) {
            sql.append(" ${clause.type_.toString()} ${clause.table}")
            if (clause.onLeft.length > 0) {
                sql.append(" ON ${clause.onLeft} = ${clause.onRight}")
            }
        }
    }

    /// 构建 GROUP BY 子句
    private func buildGroupBy(sql: StringBuilder): Unit {
        if (groupByColumns.size == 0) { return }
        sql.append(" GROUP BY ")
        sql.append(joinStrings(groupByColumns, ", "))
    }

    /// 构建 HAVING 子句
    private func buildHaving(sql: StringBuilder): Unit {
        if (havingClauses.size == 0) { return }
        sql.append(" HAVING ")
        for (i in 0..havingClauses.size) {
            if (i > 0) {
                sql.append(" ${havingClauses[i].andOr} ")
            }
            sql.append("${havingClauses[i].column} ${havingClauses[i].op.toString()} ?")
        }
    }

    /// 构建 ORDER BY 子句
    private func buildOrderBy(sql: StringBuilder): Unit {
        if (orderByClauses.size == 0) { return }
        sql.append(" ORDER BY ")
        for (i in 0..orderByClauses.size) {
            if (i > 0) { sql.append(", ") }
            sql.append("${orderByClauses[i].column} ${orderByClauses[i].direction.toString()}")
        }
    }

    /// 构建 LIMIT / OFFSET 子句
    private func buildLimitOffset(sql: StringBuilder): Unit {
        match (limitValue) {
            case Some(n) => sql.append(" LIMIT ${n}")
            case None => ()
        }
        match (offsetValue) {
            case Some(n) => sql.append(" OFFSET ${n}")
            case None => ()
        }
    }

    /// 连接字符串列表
    private func joinStrings(list: ArrayList<String>, sep: String): String {
        var result = ""
        for (i in 0..list.size) {
            if (i > 0) { result += sep }
            result += list[i]
        }
        return result
    }
}

// ============================================================================
// QueryResult — 查询执行结果
// 严格翻译自: src/sql/SqlResult
// 对应 Bun: bun:sqlite Statement.run() 返回值
// ============================================================================

/// 查询执行结果 (针对非 SELECT 操作)
/// 对应 Bun: Statement.run() 返回的 { changes, lastInsertRowid }
public class QueryResult {
    /// 受影响的行数
    /// 对应 Bun: result.changes
    public var affectedRows: Int64

    /// 最后插入行 ID
    /// 对应 Bun: result.lastInsertRowid
    public var lastInsertId: Int64

    /// 执行耗时 (毫秒)
    public var elapsedMs: Float64

    public init() {
        affectedRows = 0
        lastInsertId = 0
        elapsedMs = 0.0
    }

    public init(affectedRows: Int64, lastInsertId: Int64) {
        this.affectedRows = affectedRows
        this.lastInsertId = lastInsertId
        this.elapsedMs = 0.0
    }

    public func toString(): String {
        return "QueryResult(changes=${affectedRows}, lastInsertId=${lastInsertId}, elapsed=${elapsedMs}ms)"
    }
}

// ============================================================================
// StringBuilder — 字符串构建辅助
// ============================================================================

/// 字符串构建器
class StringBuilder {
    private var parts: ArrayList<String>

    public init() {
        parts = ArrayList<String>()
    }

    public func append(s: String): Unit {
        parts.append(s)
    }

    public func toString(): String {
        var result = ""
        for (part in parts) {
            result += part
        }
        return result
    }
}
