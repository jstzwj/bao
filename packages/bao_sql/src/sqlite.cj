// 严格翻译自: src/sql/lib.rs, src/sql/sqlite.zig
// SQLite C FFI 绑定与 SQLiteDatabaseImpl 实现
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

private func sqliteDestructorStatic(): CPointer<Unit> {
    return CPointer<Unit>()
}

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
/// @C foreign func sqlite3_clear_bindings(stmt: CPointer<Unit>): Int32
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
        super(ErrorCode.Unexpected, "SQLite error (${code}): ${message}")
        this.sqliteCode = code
    }

    public init(message: String) {
        super(ErrorCode.Unexpected, message)
        this.sqliteCode = -1
    }
}

// ============================================================================
// SQLite SQL 查询分类
// 严格翻译自: src/js/internal/sql/sqlite.ts parseSQLQuery
// ============================================================================

public enum SQLiteSQLCommand {
    | Insert
    | Update
    | UpdateSet
    | Where
    | In
    | None
}

public class SQLiteParsedInfo {
    public var command: SQLiteSQLCommand
    public var lastToken: String
    public var canReturnRows: Bool

    public init(command: SQLiteSQLCommand, lastToken: String, canReturnRows: Bool) {
        this.command = command
        this.lastToken = lastToken
        this.canReturnRows = canReturnRows
    }
}

public func parseSQLiteSQLQuery(query: String): SQLiteParsedInfo {
    return parseSQLiteSQLQuery(query, false)
}

public func parseSQLiteSQLQuery(query: String, partial: Bool): SQLiteParsedInfo {
    let text = sqliteUpper(sqliteTrim(query))
    var token = ""
    var command = SQLiteSQLCommand.None
    var lastToken = ""
    var canReturnRows = false
    var quoted: UInt8 = UInt8(0)
    var i = text.size - 1
    while (i >= 0) {
        let c = text[i]
        if (sqliteIsSqlWhitespace(c)) {
            let parsed = sqliteApplyToken(token, command, lastToken, canReturnRows, partial)
            command = parsed.command
            lastToken = parsed.lastToken
            canReturnRows = parsed.canReturnRows
            token = ""
            if (partial && !sqliteIsNoneCommand(command)) {
                return parsed
            }
        } else {
            if (c == UInt8(34) || c == UInt8(39)) {
                if (quoted == c) {
                    quoted = UInt8(0)
                } else {
                    quoted = c
                }
            } else if (quoted == UInt8(0)) {
                token = "${Rune(UInt32(c))}${token}"
            }
        }
        i -= 1
    }
    if (token.size > 0) {
        let parsed = sqliteApplyToken(token, command, lastToken, canReturnRows, false)
        command = parsed.command
        lastToken = parsed.lastToken
        canReturnRows = parsed.canReturnRows
    }
    return SQLiteParsedInfo(command, lastToken, canReturnRows)
}

private func sqliteApplyToken(token: String, command: SQLiteSQLCommand, lastToken: String, canReturnRows: Bool, partial: Bool): SQLiteParsedInfo {
    var nextCommand = command
    var nextLastToken = lastToken
    var nextCanReturnRows = canReturnRows
    match (token) {
        case "INSERT" =>
            if (sqliteIsNoneCommand(nextCommand)) { nextCommand = SQLiteSQLCommand.Insert }
            nextLastToken = token
        case "UPDATE" =>
            if (sqliteIsNoneCommand(nextCommand)) { nextCommand = SQLiteSQLCommand.Update }
            nextLastToken = token
        case "WHERE" =>
            if (sqliteIsNoneCommand(nextCommand)) { nextCommand = SQLiteSQLCommand.Where }
            nextLastToken = token
        case "SET" =>
            if (sqliteIsNoneCommand(nextCommand)) { nextCommand = SQLiteSQLCommand.UpdateSet }
            nextLastToken = token
        case "IN" =>
            if (sqliteIsNoneCommand(nextCommand)) { nextCommand = SQLiteSQLCommand.In }
            nextLastToken = token
        case "SELECT" | "PRAGMA" | "WITH" | "EXPLAIN" | "RETURNING" =>
            nextLastToken = token
            nextCanReturnRows = true
        case _ =>
            nextLastToken = token
    }
    return SQLiteParsedInfo(nextCommand, nextLastToken, nextCanReturnRows)
}

private func sqliteIsNoneCommand(command: SQLiteSQLCommand): Bool {
    match (command) {
        case SQLiteSQLCommand.None => true
        case _ => false
    }
}

private func sqliteTrim(s: String): String {
    var start: Int64 = 0
    var end = s.size
    while (start < end && sqliteIsSqlWhitespace(s[start])) {
        start += 1
    }
    while (end > start && sqliteIsSqlWhitespace(s[end - 1])) {
        end -= 1
    }
    return s[start..end]
}

private func sqliteUpper(s: String): String {
    var result = ""
    for (c in s) {
        if (c >= UInt8(97) && c <= UInt8(122)) {
            result += "${Rune(UInt32(UInt8(c - UInt8(32))))}"
        } else {
            result += "${Rune(UInt32(c))}"
        }
    }
    return result
}

private func sqliteIsSqlWhitespace(c: UInt8): Bool {
    return c == UInt8(32) || c == UInt8(10) || c == UInt8(9) || c == UInt8(13) || c == UInt8(12) || c == UInt8(11)
}

// ============================================================================
// SQLiteDatabaseImpl — SQLite 数据库连接
// 严格翻译自: src/sql/SqliteDatabase
// 对应 Bun: bun:sqlite 模块中的 Database 类
// ============================================================================

/// SQLite 数据库连接
/// 对应 Bun: bun:sqlite 中的 Database 构造函数
///
/// 示例:
///   let db = SQLiteDatabaseImpl()
///   db.open(":memory:")
///   defer { db.close() }
///   db.exec("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
public class SQLiteDatabaseImpl <: Database {
    /// 数据库文件路径
    /// 对应 Bun: Database.filename
    public var path: String

    /// 是否已打开
    private var open_: Bool

    /// 数据库句柄
    public var handle: CPointer<Unit>

    public var lastChanges_: Int64
    public var totalChanges_: Int64
    public var lastInsertRowId_: Int64

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
        handle = CPointer<Unit>()
        lastChanges_ = 0
        totalChanges_ = 0
        lastInsertRowId_ = 0
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

        unsafe {
            let handleBuf = malloc(UIntNative(8))
            let handlePtr = CPointer<CPointer<Unit>>(handleBuf)
            handlePtr.write(CPointer<Unit>())
            let pathBytes = sqlCString(path)
            let pathPtr = sqlArrayPtr(pathBytes)
            let rc = sqlite3_open_v2(pathPtr, handlePtr, flags, CPointer<UInt8>())
            this.handle = handlePtr.read()
            free(CPointer<Unit>(pathPtr))
            free(handleBuf)
            if (rc != SQLiteResultCode.OK) {
                let msg = if (!this.handle.isNull()) { sqlCStringToString(sqlite3_errmsg(this.handle)) } else { "Failed to open database" }
                if (!this.handle.isNull()) { sqlite3_close(this.handle) }
                throw SQLiteError(rc, msg)
            }
            sqlite3_busy_timeout(this.handle, busyTimeout)
        }

        this.open_ = true
        this.lastChanges_ = 0
        this.totalChanges_ = 0
        this.lastInsertRowId_ = 0
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
            unsafe {
                let rc = sqlite3_close(handle)
                if (rc != SQLiteResultCode.OK) {
                    throw SQLiteError(rc, "Failed to close database")
                }
            }
            open_ = false
            handle = CPointer<Unit>()
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

        unsafe {
            let sqlBytes = sqlCString(sql)
            let sqlPtr = sqlArrayPtr(sqlBytes)
            let errBuf = malloc(UIntNative(8))
            let errPtr = CPointer<CPointer<UInt8>>(errBuf)
            errPtr.write(CPointer<UInt8>())
            let rc = sqlite3_exec(handle, sqlPtr, CPointer<Unit>(), CPointer<Unit>(), errPtr)
            let errMsg = errPtr.read()
            free(CPointer<Unit>(sqlPtr))
            free(errBuf)
            if (rc != SQLiteResultCode.OK) {
                let msg = sqlCStringToString(errMsg)
                if (!errMsg.isNull()) { sqlite3_free(CPointer<Unit>(errMsg)) }
                throw SQLiteError(rc, msg)
            }
            lastChanges_ = Int64(sqlite3_changes(handle))
            totalChanges_ = Int64(sqlite3_total_changes(handle))
            lastInsertRowId_ = sqlite3_last_insert_rowid(handle)
            return lastChanges_
        }
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
        if (handle.isNull()) {
            return lastInsertRowId_
        }
        unsafe { return sqlite3_last_insert_rowid(handle) }
    }

    /// 获取受影响的行数
    /// 对应 Bun: Database.changes
    /// SQLite: sqlite3_changes
    public func changes(): Int64 {
        if (handle.isNull()) { return lastChanges_ }
        unsafe { return Int64(sqlite3_changes(handle)) }
    }

    /// 获取总变更次数
    /// 对应 Bun: Database.totalChanges
    /// SQLite: sqlite3_total_changes
    public func totalChanges(): Int64 {
        if (handle.isNull()) { return totalChanges_ }
        unsafe { return Int64(sqlite3_total_changes(handle)) }
    }

    /// 是否处于自动提交模式
    /// SQLite: sqlite3_get_autocommit
    public func isAutocommit(): Bool {
        if (handle.isNull()) { return true }
        unsafe { return sqlite3_get_autocommit(handle) != 0 }
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
    private var db: SQLiteDatabaseImpl

    /// SQL 文本
    private var sql: String

    /// 语句句柄
    private var stmtHandle: CPointer<Unit>

    /// 是否已绑定参数
    private var bound: Bool

    private var boundBuffers: ArrayList<CPointer<Unit>>

    /// 参数数量
    private var paramCount: Int32

    public init(db: SQLiteDatabaseImpl, sql: String) {
        this.db = db
        this.sql = sql
        this.stmtHandle = CPointer<Unit>()
        this.bound = false
        this.boundBuffers = ArrayList<CPointer<Unit>>()
        this.paramCount = 0

        unsafe {
            let stmtBuf = malloc(UIntNative(8))
            let stmtPtr = CPointer<CPointer<Unit>>(stmtBuf)
            stmtPtr.write(CPointer<Unit>())
            let sqlBytes = sqlCString(sql)
            let sqlPtr = sqlArrayPtr(sqlBytes)
            let rc = sqlite3_prepare_v2(db.handle, sqlPtr, -1, stmtPtr, CPointer<CPointer<UInt8>>())
            this.stmtHandle = stmtPtr.read()
            free(CPointer<Unit>(sqlPtr))
            free(stmtBuf)
            if (rc != SQLiteResultCode.OK) {
                let msg = sqlCStringToString(sqlite3_errmsg(db.handle))
                throw SQLiteError(rc, "Prepare failed: ${msg}")
            }
            this.paramCount = sqlite3_bind_parameter_count(stmtHandle)
        }
    }

    /// 绑定参数
    /// 对应 Bun: Statement.bind(...params)
    /// SQLite: sqlite3_bind_int64, sqlite3_bind_double, sqlite3_bind_text,
    ///         sqlite3_bind_blob, sqlite3_bind_null
    public func bind(params: Array<SqlValue>): Unit {
        clearBoundBuffers()
        for (i in 0..params.size) {
            bindValue(Int32(i) + 1, params[i])
        }
        bound = true
    }

    private func bindValue(idx: Int32, value: SqlValue): Unit {
        unsafe {
            let rc = match (value) {
                case SqlValue.Null => sqlite3_bind_null(stmtHandle, idx)
                case SqlValue.Integer(v) => sqlite3_bind_int64(stmtHandle, idx, v)
                case SqlValue.Float(v) => sqlite3_bind_double(stmtHandle, idx, v)
                case SqlValue.Text(v) =>
                    let textBytes = sqlCString(v)
                    let textPtr = sqlArrayPtr(textBytes)
                    boundBuffers.append(CPointer<Unit>(textPtr))
                    sqlite3_bind_text(stmtHandle, idx, textPtr, Int32(v.size), sqliteDestructorStatic())
                case SqlValue.Blob(v) =>
                    let blobPtr = sqlArrayPtr(v)
                    boundBuffers.append(CPointer<Unit>(blobPtr))
                    sqlite3_bind_blob(stmtHandle, idx, CPointer<Unit>(blobPtr), Int32(v.size), sqliteDestructorStatic())
            }
            if (rc != SQLiteResultCode.OK) {
                throw SQLiteError(rc, "Bind failed at index ${idx}")
            }
        }
    }

    /// 按名称绑定参数
    /// 对应 Bun: Statement.bind({ name: value })
    /// SQLite: sqlite3_bind_parameter_index + sqlite3_bind_*
    public func bindNamed(params: HashMap<String, SqlValue>): Unit {
        clearBoundBuffers()
        for (key in params.keys()) {
            let nameBytes = sqlCString(key)
            unsafe {
                let namePtr = sqlArrayPtr(nameBytes)
                let idx = sqlite3_bind_parameter_index(stmtHandle, namePtr)
                free(CPointer<Unit>(namePtr))
                if (idx == 0) {
                    throw SQLiteError(SQLiteResultCode.RANGE, "Unknown parameter: ${key}")
                }
                match (params.get(key)) {
                    case Some(value) => bindValue(idx, value)
                    case None => ()
                }
            }
        }
        bound = true
    }

    /// 执行语句 (INSERT/UPDATE/DELETE)
    /// 对应 Bun: Statement.run()
    /// SQLite: sqlite3_step + sqlite3_reset
    public func exec(): Int64 {
        unsafe {
            let rc = sqlite3_step(stmtHandle)
            sqlite3_reset(stmtHandle)
            if (rc != SQLiteResultCode.DONE && rc != SQLiteResultCode.ROW) {
                let msg = sqlCStringToString(sqlite3_errmsg(db.handle))
                throw SQLiteError(rc, msg)
            }
            db.lastChanges_ = Int64(sqlite3_changes(db.handle))
            db.totalChanges_ = Int64(sqlite3_total_changes(db.handle))
            db.lastInsertRowId_ = sqlite3_last_insert_rowid(db.handle)
            return db.lastChanges_
        }
    }

    /// 执行查询并返回结果
    /// 对应 Bun: Statement.all()
    /// SQLite: sqlite3_step 循环 + column access
    public func query(): SqlResult {
        let result = SqlResult()
        unsafe {
            let colCount = sqlite3_column_count(stmtHandle)
            for (i in 0..colCount) {
                result.columns.append(sqlCStringToString(sqlite3_column_name(stmtHandle, i)))
            }
            var rc = sqlite3_step(stmtHandle)
            while (rc == SQLiteResultCode.ROW) {
                let row = ArrayList<SqlValue>()
                for (i in 0..colCount) {
                    let colType = sqlite3_column_type(stmtHandle, i)
                    if (colType == SQLiteColumnType.INTEGER) {
                        row.append(SqlValue.Integer(sqlite3_column_int64(stmtHandle, i)))
                    } else if (colType == SQLiteColumnType.FLOAT) {
                        row.append(SqlValue.Float(sqlite3_column_double(stmtHandle, i)))
                    } else if (colType == SQLiteColumnType.TEXT) {
                        row.append(SqlValue.Text(sqlCStringToString(sqlite3_column_text(stmtHandle, i))))
                    } else if (colType == SQLiteColumnType.BLOB) {
                        row.append(SqlValue.Blob(sqlReadBlobData(sqlite3_column_blob(stmtHandle, i), sqlite3_column_bytes(stmtHandle, i))))
                    } else {
                        row.append(SqlValue.Null)
                    }
                }
                result.rows.append(row)
                rc = sqlite3_step(stmtHandle)
            }
            sqlite3_reset(stmtHandle)
            if (rc != SQLiteResultCode.DONE) {
                let msg = sqlCStringToString(sqlite3_errmsg(db.handle))
                throw SQLiteError(rc, msg)
            }
        }
        return result
    }

    /// 重置语句，清除绑定
    /// 对应 Bun: Statement.reset()
    /// SQLite: sqlite3_reset
    public func reset(): Unit {
        unsafe {
            sqlite3_reset(stmtHandle)
            sqlite3_clear_bindings(stmtHandle)
        }
        clearBoundBuffers()
        bound = false
    }

    private func clearBoundBuffers(): Unit {
        unsafe {
            for (ptr in boundBuffers) {
                free(ptr)
            }
        }
        boundBuffers.clear()
    }

    /// 释放语句
    /// 对应 Bun: Statement.finalize()
    /// SQLite: sqlite3_finalize
    public func finalize(): Unit {
        if (!stmtHandle.isNull()) {
            unsafe {
                sqlite3_clear_bindings(stmtHandle)
                sqlite3_finalize(stmtHandle)
            }
        }
        clearBoundBuffers()
        stmtHandle = CPointer<Unit>()
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
private func sqlCString(s: String): Array<UInt8> {
    let bytes = ArrayList<UInt8>()
    for (b in s) {
        bytes.append(b)
    }
    bytes.append(UInt8(0))
    return bytes.toOwnedSlice()
}

private func sqlArrayPtr(bytes: Array<UInt8>): CPointer<UInt8> {
    unsafe {
        let ptr = malloc(UIntNative(bytes.size))
        let out = CPointer<UInt8>(ptr)
        for (i in 0..bytes.size) {
            (out + i).write(bytes[i])
        }
        return out
    }
}

private func sqlCStringToString(ptr: CPointer<UInt8>): String {
    if (ptr.isNull()) {
        return ""
    }
    var result = ""
    unsafe {
        var i: Int64 = 0
        var b = (ptr + i).read()
        while (b != UInt8(0)) {
            result += "${Rune(UInt32(b))}"
            i += 1
            b = (ptr + i).read()
        }
    }
    return result
}

private func sqlReadBlobData(ptr: CPointer<Unit>, len: Int32): Array<UInt8> {
    if (len <= 0 || ptr.isNull()) {
        return Array<UInt8>()
    }
    let result = ArrayList<UInt8>()
    unsafe {
        let bytes = CPointer<UInt8>(ptr)
        for (i in 0..Int64(len)) {
            result.append((bytes + i).read())
        }
    }
    return result.toOwnedSlice()
}
