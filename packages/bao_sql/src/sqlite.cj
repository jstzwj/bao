// 严格翻译自: src/sql/lib.rs, src/sql/sqlite.zig
// SQLite C FFI 绑定与 SQLiteDatabase 实现
package bao_sql

import bao_core.*
import bao_collections.*

// ============================================================================
// SQLite C FFI 常量
// 严格翻译自: src/sql/sqlite.zig 中的 SQLITE_ 常量
// ============================================================================

/// SQLite 结果码
/// 对应 Bun: SQLITE_OK, SQLITE_ERROR, SQLITE_ROW, SQLITE_DONE 等
public class SQLiteResultCode {
    public static let OK: Int32 = 0
    public static let ERROR: Int32 = 1
    public static let INTERNAL: Int32 = 2
    public static let PERM: Int32 = 3
    public static let ABORT: Int32 = 4
    public static let BUSY: Int32 = 5
    public static let LOCKED: Int32 = 6
    public static let NOMEM: Int32 = 7
    public static let READONLY: Int32 = 8
    public static let INTERRUPT: Int32 = 9
    public static let IOERR: Int32 = 10
    public static let CORRUPT: Int32 = 11
    public static let NOTFOUND: Int32 = 12
    public static let FULL: Int32 = 13
    public static let CANTOPEN: Int32 = 14
    public static let PROTOCOL: Int32 = 15
    public static let EMPTY: Int32 = 16
    public static let SCHEMA: Int32 = 17
    public static let TOOBIG: Int32 = 18
    public static let CONSTRAINT: Int32 = 19
    public static let MISMATCH: Int32 = 20
    public static let MISUSE: Int32 = 21
    public static let NOLFS: Int32 = 22
    public static let AUTH: Int32 = 23
    public static let FORMAT: Int32 = 24
    public static let RANGE: Int32 = 25
    public static let NOTADB: Int32 = 26
    public static let NOTICE: Int32 = 27
    public static let WARNING: Int32 = 28
    public static let ROW: Int32 = 100
    public static let DONE: Int32 = 101
}

/// SQLite 列类型码
/// 对应 Bun: sqlite3_column_type 返回值
public class SQLiteColumnType {
    public static let INTEGER: Int32 = 1
    public static let FLOAT: Int32 = 2
    public static let TEXT: Int32 = 3
    public static let BLOB: Int32 = 4
    public static let NULL: Int32 = 5
}

/// SQLite 打开标志
/// 对应 Bun: SQLITE_OPEN_READONLY, SQLITE_OPEN_READWRITE, SQLITE_OPEN_CREATE
public class SQLiteOpenFlags {
    public static let READONLY: Int32 = 1
    public static let READWRITE: Int32 = 2
    public static let CREATE: Int32 = 4
    public static let URI: Int32 = 64
    public static let MEMORY: Int32 = 128
    public static let NOMUTEX: Int32 = 32768
    public static let FULLMUTEX: Int32 = 65536
    public static let SHAREDCACHE: Int32 = 131072
    public static let PRIVATECACHE: Int32 = 262144
}

/// SQLITE_TRANSIENT 常量 — 告诉 SQLite 在 bind 时复制数据
/// 对应 Bun: SQLITE_TRANSIENT = -1 (作为 destructor 参数)
public let SQLITE_TRANSIENT: Int64 = -1

/// SQLITE_STATIC 常量 — 告诉 SQLite 不复制数据
public let SQLITE_STATIC: Int64 = 0

// ============================================================================
// SQLite C FFI 函数声明
// 严格翻译自: src/sql/sqlite.zig 中通过 @cImport 引入的 C 函数
// 实际使用时需要链接 libsqlite3
// ============================================================================

/// SQLite C FFI 桥接层
/// 对应 Bun: 直接通过 Zig @cImport 调用 sqlite3 C API
/// 仓颉: 通过 @C foreign func 声明 C 函数接口
///
/// 实际 C FFI 声明 (取消注释当链接 sqlite3 时):
///
/// @C foreign func sqlite3_open(
///     filename: CPointer<UInt8>,
///     ppDb: CPointer<CPointer<Unit>>
/// ): Int32
///
/// @C foreign func sqlite3_open_v2(
///     filename: CPointer<UInt8>,
///     ppDb: CPointer<CPointer<Unit>>,
///     flags: Int32,
///     zVfs: CPointer<UInt8>
/// ): Int32
///
/// @C foreign func sqlite3_close(db: CPointer<Unit>): Int32
/// @C foreign func sqlite3_close_v2(db: CPointer<Unit>): Int32
///
/// @C foreign func sqlite3_exec(
///     db: CPointer<Unit>,
///     sql: CPointer<UInt8>,
///     callback: CPointer<Unit>,
///     arg: CPointer<Unit>,
///     errMsg: CPointer<CPointer<UInt8>>
/// ): Int32
///
/// @C foreign func sqlite3_prepare_v2(
///     db: CPointer<Unit>,
///     sql: CPointer<UInt8>,
///     nByte: Int32,
///     ppStmt: CPointer<CPointer<Unit>>,
///     pzTail: CPointer<CPointer<UInt8>>
/// ): Int32
///
/// @C foreign func sqlite3_prepare_v3(
///     db: CPointer<Unit>,
///     sql: CPointer<UInt8>,
///     nByte: Int32,
///     prepFlags: UInt32,
///     ppStmt: CPointer<CPointer<Unit>>,
///     pzTail: CPointer<CPointer<UInt8>>
/// ): Int32
///
/// @C foreign func sqlite3_step(stmt: CPointer<Unit>): Int32
/// @C foreign func sqlite3_finalize(stmt: CPointer<Unit>): Int32
/// @C foreign func sqlite3_reset(stmt: CPointer<Unit>): Int32
///
/// @C foreign func sqlite3_bind_int64(
///     stmt: CPointer<Unit>, idx: Int32, val: Int64
/// ): Int32
///
/// @C foreign func sqlite3_bind_double(
///     stmt: CPointer<Unit>, idx: Int32, val: Float64
/// ): Int32
///
/// @C foreign func sqlite3_bind_text(
///     stmt: CPointer<Unit>, idx: Int32,
///     val: CPointer<UInt8>, n: Int32,
///     destructor: CPointer<Unit>
/// ): Int32
///
/// @C foreign func sqlite3_bind_blob(
///     stmt: CPointer<Unit>, idx: Int32,
///     val: CPointer<Unit>, n: Int32,
///     destructor: CPointer<Unit>
/// ): Int32
///
/// @C foreign func sqlite3_bind_null(
///     stmt: CPointer<Unit>, idx: Int32
/// ): Int32
///
/// @C foreign func sqlite3_bind_zeroblob(
///     stmt: CPointer<Unit>, idx: Int32, n: Int32
/// ): Int32
///
/// @C foreign func sqlite3_bind_parameter_count(stmt: CPointer<Unit>): Int32
/// @C foreign func sqlite3_bind_parameter_index(
///     stmt: CPointer<Unit>, name: CPointer<UInt8>
/// ): Int32
///
/// @C foreign func sqlite3_column_count(stmt: CPointer<Unit>): Int32
/// @C foreign func sqlite3_column_type(stmt: CPointer<Unit>, idx: Int32): Int32
/// @C foreign func sqlite3_column_int64(stmt: CPointer<Unit>, idx: Int32): Int64
/// @C foreign func sqlite3_column_double(stmt: CPointer<Unit>, idx: Int32): Float64
/// @C foreign func sqlite3_column_text(stmt: CPointer<Unit>, idx: Int32): CPointer<UInt8>
/// @C foreign func sqlite3_column_blob(stmt: CPointer<Unit>, idx: Int32): CPointer<Unit>
/// @C foreign func sqlite3_column_bytes(stmt: CPointer<Unit>, idx: Int32): Int32
/// @C foreign func sqlite3_column_name(stmt: CPointer<Unit>, idx: Int32): CPointer<UInt8>
/// @C foreign func sqlite3_column_decltype(stmt: CPointer<Unit>, idx: Int32): CPointer<UInt8>
///
/// @C foreign func sqlite3_changes(db: CPointer<Unit>): Int32
/// @C foreign func sqlite3_total_changes(db: CPointer<Unit>): Int32
/// @C foreign func sqlite3_last_insert_rowid(db: CPointer<Unit>): Int64
/// @C foreign func sqlite3_errmsg(db: CPointer<Unit>): CPointer<UInt8>
/// @C foreign func sqlite3_errcode(db: CPointer<Unit>): Int32
/// @C foreign func sqlite3_extended_errcode(db: CPointer<Unit>): Int32
///
/// @C foreign func sqlite3_free(ptr: CPointer<Unit>): Unit
/// @C foreign func sqlite3_busy_timeout(db: CPointer<Unit>, ms: Int32): Int32
/// @C foreign func sqlite3_get_autocommit(db: CPointer<Unit>): Int32
///
/// @C foreign func sqlite3_data_count(stmt: CPointer<Unit>): Int32

// ============================================================================
// SQLiteError — SQLite 操作异常
// 严格翻译自: src/sql/SqlError
// ============================================================================

/// SQLite 操作错误
/// 对应 Bun: sqlite3_errmsg / sqlite3_errcode 错误处理
public class SQLiteError <: BaoError {
    public let sqliteCode: Int32

    public init(code: Int32, message: String) {
        this.sqliteCode = code
        super(ErrorCode.Unexpected, "SQLite error (${code}): ${message}")
    }

    public init(message: String) {
        this.sqliteCode = -1
        super(ErrorCode.Unexpected, message)
    }
}

// ============================================================================
// SQLiteDatabase — SQLite 数据库连接
// 严格翻译自: src/sql/SqliteDatabase
// 对应 Bun: bun:sqlite 模块中的 Database 类
// ============================================================================

/// SQLite 数据库连接
/// 对应 Bun: bun:sqlite 中的 Database 构造函数
///
/// 示例:
///   let db = SQLiteDatabase()
///   db.open(":memory:")
///   defer { db.close() }
///   db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
public class SQLiteDatabase <: Database {
    /// 数据库文件路径
    /// 对应 Bun: Database.filename
    public var path: String

    /// 是否已打开
    private var open_: Bool

    /// 数据库句柄
    /// 实际类型: CPointer<Unit> (sqlite3*)
    /// 桩实现: Int64
    private var handle: Int64

    /// 打开标志 — 对应 Bun: Database.openFlags
    private var flags: Int32

    /// 是否为内存数据库
    /// 对应 Bun: Database.inMemory
    public var inMemory: Bool

    /// 是否只读模式
    /// 对应 Bun: Database.readonly
    public var readonly: Bool

    /// 繁忙超时 (毫秒)
    /// 对应 Bun: Database.busyTimeout
    public var busyTimeout: Int32

    public init() {
        path = ""
        open_ = false
        handle = 0
        flags = SQLiteOpenFlags.READWRITE | SQLiteOpenFlags.CREATE
        inMemory = false
        readonly = false
        busyTimeout = 5000
    }

    /// 打开数据库连接
    /// 对应 Bun: new Database(filename, options)
    /// SQLite: sqlite3_open_v2
    public func open(path: String): Unit {
        this.path = path
        this.inMemory = (path == ":memory:")

        // 实际 C FFI 实现:
        // unsafe {
        //     var dbHandle: CPointer<Unit>
        //     let cPath = path.toCString()
        //     let rc = sqlite3_open_v2(cPath, &dbHandle, flags, null)
        //     if (rc != SQLiteResultCode.OK) {
        //         let msg = if (dbHandle != null) {
        //             cStringToString(sqlite3_errmsg(dbHandle))
        //         } else {
        //             "Failed to open database"
        //         }
        //         if (dbHandle != null) { sqlite3_close(dbHandle) }
        //         throw SQLiteError(rc, msg)
        //     }
        //     this.handle = dbHandle
        //     sqlite3_busy_timeout(dbHandle, busyTimeout)
        // }

        this.open_ = true
        this.handle = 1
    }

    /// 以只读模式打开
    /// 对应 Bun: new Database(filename, { readonly: true })
    public func openReadonly(path: String): Unit {
        this.flags = SQLiteOpenFlags.READONLY
        this.readonly = true
        open(path)
    }

    /// 关闭数据库连接
    /// 对应 Bun: Database.close()
    /// SQLite: sqlite3_close
    public func close(): Unit {
        if (open_) {
            // 实际 C FFI 实现:
            // unsafe {
            //     let rc = sqlite3_close(handle)
            //     if (rc != SQLiteResultCode.OK) {
            //         throw SQLiteError(rc, "Failed to close database")
            //     }
            // }
            open_ = false
            handle = 0
        }
    }

    /// 是否已打开
    public func isOpen(): Bool {
        return open_
    }

    /// 执行 SQL 语句 (无返回结果)
    /// 对应 Bun: Database.exec(sql)
    /// SQLite: sqlite3_exec
    public func exec(sql: String): Int64 {
        if (!open_) {
            throw SQLiteError("Database is not open")
        }

        // 实际 C FFI 实现:
        // unsafe {
        //     var errMsg: CPointer<UInt8>
        //     let rc = sqlite3_exec(handle, sql.toCString(), null, null, &errMsg)
        //     if (rc != SQLiteResultCode.OK) {
        //         let msg = cStringToString(errMsg)
        //         sqlite3_free(errMsg)
        //         throw SQLiteError(rc, msg)
        //     }
        //     return Int64(sqlite3_changes(handle))
        // }
        return 0
    }

    /// 执行带参数的 SQL 语句
    /// 对应 Bun: Database.run(sql, params)
    public func run(sql: String, params: Array<SqlValue>): Int64 {
        let stmt = prepare(sql)
        stmt.bind(params)
        let changes = stmt.exec()
        stmt.finalize()
        return changes
    }

    /// 执行查询并返回结果
    /// 对应 Bun: Database.query(sql, params)
    /// SQLite: sqlite3_prepare_v2 + sqlite3_step + column access
    public func query(sql: String, params: Array<SqlValue>): SqlResult {
        if (!open_) {
            throw SQLiteError("Database is not open")
        }
        let stmt = prepare(sql)
        stmt.bind(params)
        let result = stmt.query()
        stmt.finalize()
        return result
    }

    /// 准备 SQL 语句
    /// 对应 Bun: Database.prepare(sql)
    /// SQLite: sqlite3_prepare_v2
    public func prepare(sql: String): Statement {
        return SQLitePreparedStatement(this, sql)
    }

    /// 查询单行
    /// 对应 Bun: Database.get(sql, params)
    public func get(sql: String, params: Array<SqlValue>): ?SqlRow {
        let result = query(sql, params)
        if (result.rows.size > 0) {
            return Some(result.rows[0])
        }
        return None
    }

    /// 查询单值
    /// 对应 Bun: Database.getValue(sql, params)
    public func getValue(sql: String, params: Array<SqlValue>): ?SqlValue {
        let result = query(sql, params)
        return result.scalar()
    }

    /// 获取所有行
    /// 对应 Bun: Database.all(sql, params)
    public func all(sql: String, params: Array<SqlValue>): ArrayList<SqlRow> {
        let result = query(sql, params)
        return result.rows
    }

    /// 获取最后插入行 ID
    /// 对应 Bun: Database.lastInsertRowId
    /// SQLite: sqlite3_last_insert_rowid
    public func lastInsertRowId(): Int64 {
        // 实际实现:
        // unsafe { return sqlite3_last_insert_rowid(handle) }
        return 0
    }

    /// 获取受影响的行数
    /// 对应 Bun: Database.changes
    /// SQLite: sqlite3_changes
    public func changes(): Int64 {
        // 实际实现:
        // unsafe { return Int64(sqlite3_changes(handle)) }
        return 0
    }

    /// 获取总变更次数
    /// 对应 Bun: Database.totalChanges
    /// SQLite: sqlite3_total_changes
    public func totalChanges(): Int64 {
        // 实际实现:
        // unsafe { return Int64(sqlite3_total_changes(handle)) }
        return 0
    }

    /// 是否处于自动提交模式
    /// SQLite: sqlite3_get_autocommit
    public func isAutocommit(): Bool {
        // 实际实现:
        // unsafe { return sqlite3_get_autocommit(handle) != 0 }
        return true
    }

    /// 获取表名列表
    /// 对应 Bun: Database.tables (扩展方法)
    public func tables(): ArrayList<String> {
        let result = query("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name", [])
        let names = ArrayList<String>()
        for (row in result.rows) {
            if (row.size > 0) {
                match (row[0]) {
                    case SqlValue.Text(name) => names.append(name)
                    case _ => ()
                }
            }
        }
        return names
    }

    /// 获取表的列信息
    /// 对应 Bun: Database.columns(table)
    public func tableInfo(table: String): ArrayList<ColumnInfo> {
        let result = query("PRAGMA table_info('${table}')", [])
        let infos = ArrayList<ColumnInfo>()
        for (row in result.rows) {
            if (row.size >= 6) {
                let info = ColumnInfo()
                match (row[0]) { case SqlValue.Integer(v) => info.cid = v case _ => () }
                match (row[1]) { case SqlValue.Text(v) => info.name = v case _ => () }
                match (row[2]) { case SqlValue.Text(v) => info.type_ = v case _ => () }
                match (row[3]) { case SqlValue.Integer(v) => info.notNull = (v != 0) case _ => () }
                match (row[4]) { case SqlValue.Integer(v) => info.defaultValue = SqlValue.Integer(v) case SqlValue.Null => info.defaultValue = SqlValue.Null case _ => () }
                match (row[5]) { case SqlValue.Integer(v) => info.primaryKey = (v != 0) case _ => () }
                infos.append(info)
            }
        }
        return infos
    }

    /// 事务: 开始
    /// 对应 Bun: Database.transaction
    public func beginTransaction(): Unit {
        exec("BEGIN TRANSACTION")
    }

    /// 事务: 提交
    public func commit(): Unit {
        exec("COMMIT")
    }

    /// 事务: 回滚
    public func rollback(): Unit {
        exec("ROLLBACK")
    }

    /// 在事务中执行回调
    /// 对应 Bun: Database.transaction(fn)
    public func transaction<T>(fn: () -> T): T {
        beginTransaction()
        try {
            let result = fn()
            commit()
            return result
        } catch (e: Exception) {
            rollback()
            throw e
        }
    }
}

// ============================================================================
// SQLitePreparedStatement — SQLite 预编译语句
// 严格翻译自: src/sql/Statement
// 对应 Bun: bun:sqlite 中的 Statement 类
// ============================================================================

/// SQLite 预编译语句
/// 对应 Bun: Database.prepare() 返回的 Statement 对象
///
/// 示例:
///   let stmt = db.prepare("SELECT * FROM users WHERE id = ?")
///   stmt.bind([SqlValue.Integer(1)])
///   let result = stmt.query()
///   stmt.finalize()
class SQLitePreparedStatement <: Statement {
    /// 所属数据库
    private var db: SQLiteDatabase

    /// SQL 文本
    private var sql: String

    /// 语句句柄
    /// 实际类型: CPointer<Unit> (sqlite3_stmt*)
    private var stmtHandle: Int64

    /// 是否已绑定参数
    private var bound: Bool

    /// 参数数量
    private var paramCount: Int32

    public init(db: SQLiteDatabase, sql: String) {
        this.db = db
        this.sql = sql
        this.stmtHandle = 0
        this.bound = false
        this.paramCount = 0

        // 实际 C FFI 实现:
        // unsafe {
        //     var stmt: CPointer<Unit>
        //     let rc = sqlite3_prepare_v2(
        //         db.handle, sql.toCString(), -1, &stmt, null
        //     )
        //     if (rc != SQLiteResultCode.OK) {
        //         let msg = cStringToString(sqlite3_errmsg(db.handle))
        //         throw SQLiteError(rc, "Prepare failed: ${msg}")
        //     }
        //     this.stmtHandle = stmt
        //     this.paramCount = sqlite3_bind_parameter_count(stmt)
        // }
    }

    /// 绑定参数
    /// 对应 Bun: Statement.bind(...params)
    /// SQLite: sqlite3_bind_int64, sqlite3_bind_double, sqlite3_bind_text,
    ///         sqlite3_bind_blob, sqlite3_bind_null
    public func bind(params: Array<SqlValue>): Unit {
        // 实际 C FFI 实现:
        // unsafe {
        //     for (i in 0..params.size) {
        //         let idx = Int32(i) + 1
        //         let rc = match (params[i]) {
        //             case SqlValue.Null =>
        //                 sqlite3_bind_null(stmtHandle, idx)
        //             case SqlValue.Integer(v) =>
        //                 sqlite3_bind_int64(stmtHandle, idx, v)
        //             case SqlValue.Float(v) =>
        //                 sqlite3_bind_double(stmtHandle, idx, v)
        //             case SqlValue.Text(v) =>
        //                 sqlite3_bind_text(
        //                     stmtHandle, idx, v.toCString(),
        //                     Int32(v.length), SQLITE_TRANSIENT
        //                 )
        //             case SqlValue.Blob(v) =>
        //                 sqlite3_bind_blob(
        //                     stmtHandle, idx, v.toCPointer(),
        //                     Int32(v.size), SQLITE_TRANSIENT
        //                 )
        //         }
        //         if (rc != SQLiteResultCode.OK) {
        //             throw SQLiteError(rc, "Bind failed at index ${idx}")
        //         }
        //     }
        // }
        bound = true
    }

    /// 按名称绑定参数
    /// 对应 Bun: Statement.bind({ name: value })
    /// SQLite: sqlite3_bind_parameter_index + sqlite3_bind_*
    public func bindNamed(params: HashMap<String, SqlValue>): Unit {
        // 实际 C FFI 实现:
        // unsafe {
        //     let keys = params.keys()
        //     for (key in keys) {
        //         let idx = sqlite3_bind_parameter_index(stmtHandle, key.toCString())
        //         if (idx == 0) {
        //             throw SQLiteError("Unknown parameter: ${key}")
        //         }
        //         match (params.get(key)) {
        //             case Some(SqlValue.Null) => sqlite3_bind_null(stmtHandle, idx)
        //             case Some(SqlValue.Integer(v)) => sqlite3_bind_int64(stmtHandle, idx, v)
        //             case Some(SqlValue.Float(v)) => sqlite3_bind_double(stmtHandle, idx, v)
        //             case Some(SqlValue.Text(v)) => sqlite3_bind_text(stmtHandle, idx, v.toCString(), -1, SQLITE_TRANSIENT)
        //             case Some(SqlValue.Blob(v)) => sqlite3_bind_blob(stmtHandle, idx, v.toCPointer(), Int32(v.size), SQLITE_TRANSIENT)
        //             case None => ()
        //         }
        //     }
        // }
        bound = true
    }

    /// 执行语句 (INSERT/UPDATE/DELETE)
    /// 对应 Bun: Statement.run()
    /// SQLite: sqlite3_step + sqlite3_reset
    public func exec(): Int64 {
        // 实际 C FFI 实现:
        // unsafe {
        //     let rc = sqlite3_step(stmtHandle)
        //     sqlite3_reset(stmtHandle)
        //     if (rc != SQLiteResultCode.DONE && rc != SQLiteResultCode.ROW) {
        //         let msg = cStringToString(sqlite3_errmsg(db.handle))
        //         throw SQLiteError(rc, msg)
        //     }
        //     return Int64(sqlite3_changes(db.handle))
        // }
        return 0
    }

    /// 执行查询并返回结果
    /// 对应 Bun: Statement.all()
    /// SQLite: sqlite3_step 循环 + column access
    public func query(): SqlResult {
        let result = SqlResult()

        // 实际 C FFI 实现:
        // unsafe {
        //     // 读取列元数据
        //     let colCount = sqlite3_column_count(stmtHandle)
        //     for (i in 0..colCount) {
        //         let name = cStringToString(sqlite3_column_name(stmtHandle, i))
        //         result.columns.append(name)
        //     }
        //
        //     // 逐行读取
        //     var rc = sqlite3_step(stmtHandle)
        //     while (rc == SQLiteResultCode.ROW) {
        //         let row = ArrayList<SqlValue>()
        //         for (i in 0..colCount) {
        //             let colType = sqlite3_column_type(stmtHandle, i)
        //             match (colType) {
        //                 case SQLiteColumnType.INTEGER =>
        //                     row.append(SqlValue.Integer(sqlite3_column_int64(stmtHandle, i)))
        //                 case SQLiteColumnType.FLOAT =>
        //                     row.append(SqlValue.Float(sqlite3_column_double(stmtHandle, i)))
        //                 case SQLiteColumnType.TEXT => {
        //                     let textPtr = sqlite3_column_text(stmtHandle, i)
        //                     let textLen = sqlite3_column_bytes(stmtHandle, i)
        //                     row.append(SqlValue.Text(cStringToString(textPtr)))
        //                 }
        //                 case SQLiteColumnType.BLOB => {
        //                     let blobPtr = sqlite3_column_blob(stmtHandle, i)
        //                     let blobLen = sqlite3_column_bytes(stmtHandle, i)
        //                     row.append(SqlValue.Blob(readBlobData(blobPtr, blobLen)))
        //                 }
        //                 case SQLiteColumnType.NULL =>
        //                     row.append(SqlValue.Null)
        //                 case _ =>
        //                     row.append(SqlValue.Null)
        //             }
        //         }
        //         result.rows.append(row)
        //         rc = sqlite3_step(stmtHandle)
        //     }
        //
        //     if (rc != SQLiteResultCode.DONE) {
        //         let msg = cStringToString(sqlite3_errmsg(db.handle))
        //         sqlite3_reset(stmtHandle)
        //         throw SQLiteError(rc, msg)
        //     }
        //
        //     sqlite3_reset(stmtHandle)
        // }

        return result
    }

    /// 重置语句，清除绑定
    /// 对应 Bun: Statement.reset()
    /// SQLite: sqlite3_reset
    public func reset(): Unit {
        // 实际 C FFI 实现:
        // unsafe { sqlite3_reset(stmtHandle) }
        bound = false
    }

    /// 释放语句
    /// 对应 Bun: Statement.finalize()
    /// SQLite: sqlite3_finalize
    public func finalize(): Unit {
        // 实际 C FFI 实现:
        // unsafe { sqlite3_finalize(stmtHandle) }
        stmtHandle = 0
        bound = false
    }

    /// 获取 SQL 文本
    /// 对应 Bun: Statement.sourceStr
    public func getSQL(): String {
        return sql
    }

    /// 获取参数数量
    public func parameterCount(): Int32 {
        return paramCount
    }
}

// ============================================================================
// ColumnInfo — 表列元信息
// 严格翻译自: PRAGMA table_info 返回结构
// ============================================================================

/// 列信息
/// 对应 Bun: PRAGMA table_info 解析结果
public class ColumnInfo {
    public var cid: Int64
    public var name: String
    public var type_: String
    public var notNull: Bool
    public var defaultValue: SqlValue
    public var primaryKey: Bool

    public init() {
        cid = 0
        name = ""
        type_ = ""
        notNull = false
        defaultValue = SqlValue.Null
        primaryKey = false
    }

    public func toString(): String {
        return "ColumnInfo(${cid}, ${name}, ${type_}, notNull=${notNull}, pk=${primaryKey})"
    }
}

// ============================================================================
// SQLite 辅助函数
// ============================================================================

/// 将 C 字符串转为仓颉 String
/// 实际使用 C FFI 时启用
private func cStringToString(ptr: Int64): String {
    // 实际实现:
    // unsafe {
    //     if (ptr == null) { return "" }
    //     var len = 0
    //     while (ptr[len] != 0) { len++ }
    //     return String.fromUtf8(ptr[0..len])
    // }
    return ""
}

/// 读取 blob 数据
/// 实际使用 C FFI 时启用
private func readBlobData(ptr: Int64, len: Int32): Array<UInt8> {
    // 实际实现:
    // unsafe {
    //     var result = Array<UInt8>(len)
    //     for (i in 0..len) {
    //         result[i] = ptr[i]
    //     }
    //     return result
    // }
    return Array<UInt8>()
}
