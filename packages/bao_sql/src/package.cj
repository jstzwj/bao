// bao_sql - 数据库支持
// 对应 Bun: src/sql/
package bao_sql

import bao_core.*

// ============================================================================
// SQL 数据库接口
// 对应 Bun: src/sql/sql.zig
// ============================================================================

/// SQL 值类型
public enum SqlValue {
    | Null
    | Integer(Int64)
    | Float(Float64)
    | Text(String)
    | Blob(Array<UInt8>)
}

/// SQL 行类型
public type SqlRow = ArrayList<SqlValue>

/// SQL 查询结果
public class SqlResult {
    public let columns: ArrayList<String>
    public let rows: ArrayList<SqlRow>
    public let changes: Int64

    public init() {
        columns = ArrayList<String>()
        rows = ArrayList<SqlRow>()
        changes = 0
    }
}

/// 数据库连接接口
public interface Database {
    func open(path: String): Unit
    func close(): Unit
    func exec(sql: String): Int64
    func query(sql: String, params: Array<SqlValue>): SqlResult
    func prepare(sql: String): Statement
}

/// 预编译语句接口
public interface Statement {
    func bind(params: Array<SqlValue>): Unit
    func exec(): Int64
    func query(): SqlResult
    func reset(): Unit
    func finalize(): Unit
}

// ============================================================================
// SQLite 实现 (骨架)
// 对应 Bun: src/sql/sqlite.zig
// ============================================================================

/// SQLite 数据库
public class SQLiteDatabase <: Database {
    private var path: String
    private var isOpen: Bool

    public init() {
        path = ""
        isOpen = false
    }

    public func open(path: String): Unit {
        this.path = path
        this.isOpen = true
        // TODO: 通过 C FFI 调用 sqlite3_open
    }

    public func close(): Unit {
        if (isOpen) {
            // TODO: 通过 C FFI 调用 sqlite3_close
            isOpen = false
        }
    }

    public func exec(sql: String): Int64 {
        // TODO: 通过 C FFI 调用 sqlite3_exec
        return 0
    }

    public func query(sql: String, params: Array<SqlValue>): SqlResult {
        // TODO: 通过 C FFI 调用 sqlite3_prepare_v2 + sqlite3_step
        return SqlResult()
    }

    public func prepare(sql: String): Statement {
        // TODO: 实现
        return SQLiteStatement()
    }
}

/// SQLite 预编译语句
class SQLiteStatement <: Statement {
    public func bind(params: Array<SqlValue>): Unit {}
    public func exec(): Int64 { return 0 }
    public func query(): SqlResult { return SqlResult() }
    public func reset(): Unit {}
    public func finalize(): Unit {}
}
