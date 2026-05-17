// bao_sql - 数据库支持
// 对应 Bun: src/sql/
package bao_sql

import bao_core.*
import bao_collections.*

foreign func sqlite3_open_v2(filename: CPointer<UInt8>, ppDb: CPointer<CPointer<Unit>>, flags: Int32, zVfs: CPointer<UInt8>): Int32
foreign func sqlite3_close(db: CPointer<Unit>): Int32
foreign func sqlite3_exec(db: CPointer<Unit>, sql: CPointer<UInt8>, callback: CPointer<Unit>, arg: CPointer<Unit>, errMsg: CPointer<CPointer<UInt8>>): Int32
foreign func sqlite3_prepare_v2(db: CPointer<Unit>, sql: CPointer<UInt8>, nByte: Int32, ppStmt: CPointer<CPointer<Unit>>, pzTail: CPointer<CPointer<UInt8>>): Int32
foreign func sqlite3_step(stmt: CPointer<Unit>): Int32
foreign func sqlite3_finalize(stmt: CPointer<Unit>): Int32
foreign func sqlite3_reset(stmt: CPointer<Unit>): Int32
foreign func sqlite3_bind_int64(stmt: CPointer<Unit>, idx: Int32, val: Int64): Int32
foreign func sqlite3_bind_double(stmt: CPointer<Unit>, idx: Int32, val: Float64): Int32
foreign func sqlite3_bind_text(stmt: CPointer<Unit>, idx: Int32, val: CPointer<UInt8>, n: Int32, destructor: CPointer<Unit>): Int32
foreign func sqlite3_bind_null(stmt: CPointer<Unit>, idx: Int32): Int32
foreign func sqlite3_bind_blob(stmt: CPointer<Unit>, idx: Int32, val: CPointer<Unit>, n: Int32, destructor: CPointer<Unit>): Int32
foreign func sqlite3_column_count(stmt: CPointer<Unit>): Int32
foreign func sqlite3_column_type(stmt: CPointer<Unit>, idx: Int32): Int32
foreign func sqlite3_column_int64(stmt: CPointer<Unit>, idx: Int32): Int64
foreign func sqlite3_column_double(stmt: CPointer<Unit>, idx: Int32): Float64
foreign func sqlite3_column_text(stmt: CPointer<Unit>, idx: Int32): CPointer<UInt8>
foreign func sqlite3_column_blob(stmt: CPointer<Unit>, idx: Int32): CPointer<Unit>
foreign func sqlite3_column_bytes(stmt: CPointer<Unit>, idx: Int32): Int32
foreign func sqlite3_column_name(stmt: CPointer<Unit>, idx: Int32): CPointer<UInt8>
foreign func sqlite3_changes(db: CPointer<Unit>): Int32
foreign func sqlite3_total_changes(db: CPointer<Unit>): Int32
foreign func sqlite3_last_insert_rowid(db: CPointer<Unit>): Int64
foreign func sqlite3_get_autocommit(db: CPointer<Unit>): Int32
foreign func sqlite3_bind_parameter_count(stmt: CPointer<Unit>): Int32
foreign func sqlite3_bind_parameter_index(stmt: CPointer<Unit>, name: CPointer<UInt8>): Int32
foreign func sqlite3_clear_bindings(stmt: CPointer<Unit>): Int32
foreign func sqlite3_errmsg(db: CPointer<Unit>): CPointer<UInt8>
foreign func sqlite3_free(ptr: CPointer<Unit>): Unit
foreign func sqlite3_busy_timeout(db: CPointer<Unit>, ms: Int32): Int32
@C
foreign func malloc(size: UIntNative): CPointer<Unit>
@C
foreign func free(ptr: CPointer<Unit>): Unit

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

    public func toString(): String {
        match (this) {
            case Null => "NULL"
            case Integer(i) => i.toString()
            case Float(f) => f.toString()
            case Text(s) => "'${s}'"
            case Blob(b) => "BLOB(${b.size})"
        }
    }
}

/// SQL 行类型
public type SqlRow = ArrayList<SqlValue>

/// SQL 查询结果
/// 对应 Bun: src/sql/SqlResult
public class SqlResult {
    public let columns: ArrayList<String>
    public let rows: ArrayList<SqlRow>
    public var changes: Int64
    public var lastInsertRowId: Int64

    public init() {
        columns = ArrayList<String>()
        rows = ArrayList<SqlRow>()
        changes = 0
        lastInsertRowId = 0
    }

    /// 获取第一行第一列的值
    public func scalar(): ?SqlValue {
        if (rows.size > 0 && rows[0].size > 0) {
            return Some(rows[0][0])
        }
        return None
    }

    /// 行数
    public func rowCount(): Int64 {
        return rows.size
    }
}

/// 数据库连接接口
public interface Database {
    func open(path: String): Unit
    func close(): Unit
    func exec(sql: String): Int64
    func query(sql: String, params: Array<SqlValue>): SqlResult
    func prepare(sql: String): Statement
    func isOpen(): Bool
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
// SQLite C FFI 声明
// 对应 Bun: src/sql/sqlite.zig 通过 C FFI 调用 sqlite3
// ============================================================================

/// SQLite C API 常量
public class SQLiteConstants {
    public static let OK: Int32 = 0
    public static let ERROR: Int32 = 1
    public static let BUSY: Int32 = 5
    public static let ROW: Int32 = 100
    public static let DONE: Int32 = 101
    public static let INTEGER: Int32 = 1
    public static let FLOAT: Int32 = 2
    public static let TEXT: Int32 = 3
    public static let BLOB: Int32 = 4
    public static let NULL: Int32 = 5
    public static let OPEN_READONLY: Int32 = 1
    public static let OPEN_READWRITE: Int32 = 2
    public static let OPEN_CREATE: Int32 = 4
}

// SQLite C FFI 函数声明模板 (实际使用时需要链接 sqlite3 动态库):
//
// @C foreign func sqlite3_open(filename: CPointer<UInt8>, ppDb: CPointer<CPointer<Unit>>): Int32
// @C foreign func sqlite3_close(db: CPointer<Unit>): Int32
// @C foreign func sqlite3_exec(db: CPointer<Unit>, sql: CPointer<UInt8>,
//                               callback: CPointer<Unit>, arg: CPointer<Unit>,
//                               errMsg: CPointer<CPointer<UInt8>>): Int32
// @C foreign func sqlite3_prepare_v2(db: CPointer<Unit>, sql: CPointer<UInt8>,
//                                     nByte: Int32, ppStmt: CPointer<CPointer<Unit>>,
//                                     pzTail: CPointer<CPointer<UInt8>>): Int32
// @C foreign func sqlite3_step(stmt: CPointer<Unit>): Int32
// @C foreign func sqlite3_finalize(stmt: CPointer<Unit>): Int32
// @C foreign func sqlite3_reset(stmt: CPointer<Unit>): Int32
// @C foreign func sqlite3_bind_int64(stmt: CPointer<Unit>, idx: Int32, val: Int64): Int32
// @C foreign func sqlite3_bind_double(stmt: CPointer<Unit>, idx: Int32, val: Float64): Int32
// @C foreign func sqlite3_bind_text(stmt: CPointer<Unit>, idx: Int32,
//                                    val: CPointer<UInt8>, n: Int32,
//                                    destructor: CPointer<Unit>): Int32
// @C foreign func sqlite3_bind_null(stmt: CPointer<Unit>, idx: Int32): Int32
// @C foreign func sqlite3_bind_blob(stmt: CPointer<Unit>, idx: Int32,
//                                    val: CPointer<Unit>, n: Int32,
//                                    destructor: CPointer<Unit>): Int32
// @C foreign func sqlite3_column_count(stmt: CPointer<Unit>): Int32
// @C foreign func sqlite3_column_type(stmt: CPointer<Unit>, idx: Int32): Int32
// @C foreign func sqlite3_column_int64(stmt: CPointer<Unit>, idx: Int32): Int64
// @C foreign func sqlite3_column_double(stmt: CPointer<Unit>, idx: Int32): Float64
// @C foreign func sqlite3_column_text(stmt: CPointer<Unit>, idx: Int32): CPointer<UInt8>
// @C foreign func sqlite3_column_blob(stmt: CPointer<Unit>, idx: Int32): CPointer<Unit>
// @C foreign func sqlite3_column_bytes(stmt: CPointer<Unit>, idx: Int32): Int32
// @C foreign func sqlite3_column_name(stmt: CPointer<Unit>, idx: Int32): CPointer<UInt8>
// @C foreign func sqlite3_changes(db: CPointer<Unit>): Int32
// @C foreign func sqlite3_last_insert_rowid(db: CPointer<Unit>): Int64
// @C foreign func sqlite3_errmsg(db: CPointer<Unit>): CPointer<UInt8>
// @C foreign func sqlite3_errcode(db: CPointer<Unit>): Int32

// ============================================================================
// SQLite 实现
// 对应 Bun: src/sql/sqlite.zig
// ============================================================================

/// SQLite 数据库连接
/// 对应 Bun: src/sql/SqliteDatabase
public class SQLiteDatabase <: Database {
    private var path: String
    private var open_: Bool
    /// 数据库句柄
    public var handle: CPointer<Unit>

    public init() {
        path = ""
        open_ = false
        handle = CPointer<Unit>()
    }

    public func open(path: String): Unit {
        this.path = path
        var dbHandle = CPointer<Unit>()
        let flags = SQLiteConstants.OPEN_READWRITE | SQLiteConstants.OPEN_CREATE
        let pathBytes = cString(path)
        unsafe {
            let handleBuf = malloc(UIntNative(8))
            let handlePtr = CPointer<CPointer<Unit>>(handleBuf)
            handlePtr.write(CPointer<Unit>())
            let pathPtr = arrayPtr(pathBytes)
            let rc = sqlite3_open_v2(pathPtr, handlePtr, flags, CPointer<UInt8>())
            dbHandle = handlePtr.read()
            free(CPointer<Unit>(pathPtr))
            free(handleBuf)
            if (rc != SQLiteConstants.OK) {
                let msg = cStringToString(sqlite3_errmsg(dbHandle))
                sqlite3_close(dbHandle)
                throw BaoError(ErrorCode.InvalidArgument, "SQLite error (${rc}): ${msg}")
            }
            sqlite3_busy_timeout(dbHandle, 5000)
        }
        this.handle = dbHandle
        this.open_ = true
    }

    public func close(): Unit {
        if (open_) {
            unsafe {
                let rc = sqlite3_close(handle)
                if (rc != SQLiteConstants.OK) {
                    throw BaoError(ErrorCode.InvalidArgument, "Failed to close database: ${cStringToString(sqlite3_errmsg(handle))}")
                }
            }
            open_ = false
            handle = CPointer<Unit>()
        }
    }

    public func isOpen(): Bool {
        return open_
    }

    /// 执行 SQL 语句
    /// 对应 Bun: SQLiteDatabase.exec
    public func exec(sql: String): Int64 {
        if (!open_) {
            throw BaoError(ErrorCode.InvalidArgument, "Database is not open")
        }
        var changes: Int64 = 0
        unsafe {
            var errMsg = CPointer<UInt8>()
            let sqlBytes = cString(sql)
            let sqlPtr = arrayPtr(sqlBytes)
            let errBuf = malloc(UIntNative(8))
            let errPtr = CPointer<CPointer<UInt8>>(errBuf)
            errPtr.write(CPointer<UInt8>())
            let rc = sqlite3_exec(handle, sqlPtr, CPointer<Unit>(), CPointer<Unit>(), errPtr)
            errMsg = errPtr.read()
            free(CPointer<Unit>(sqlPtr))
            free(errBuf)
            if (rc != SQLiteConstants.OK) {
                let msg = cStringToString(errMsg)
                if (false) { sqlite3_free(CPointer<Unit>(errMsg)) }
                throw BaoError(ErrorCode.InvalidArgument, "SQL error: ${msg}")
            }
            changes = Int64(sqlite3_changes(handle))
        }
        return changes
    }

    /// 执行查询
    /// 对应 Bun: SQLiteDatabase.query
    public func query(sql: String, params: Array<SqlValue>): SqlResult {
        if (!open_) {
            throw BaoError(ErrorCode.InvalidArgument, "Database is not open")
        }
        let stmt = prepare(sql)
        stmt.bind(params)
        let stmtResult = stmt.query()
        stmt.finalize()
        return stmtResult
    }

    /// 准备语句
    /// 对应 Bun: SQLiteDatabase.prepare
    public func prepare(sql: String): Statement {
        return SQLiteStatement(this, sql)
    }

    /// 便捷: 查询单行
    public func queryOne(sql: String, params: Array<SqlValue>): ?SqlRow {
        let result = query(sql, params)
        if (result.rows.size > 0) {
            return Some(result.rows[0])
        }
        return None
    }

    /// 便捷: 查询单值
    public func queryScalar(sql: String, params: Array<SqlValue>): ?SqlValue {
        let result = query(sql, params)
        return result.scalar()
    }

    /// 获取最后插入的行 ID
    public func lastInsertRowId(): Int64 {
        unsafe {
            return sqlite3_last_insert_rowid(handle)
        }
    }

    /// 获取表名列表
    public func tables(): ArrayList<String> {
        let result = query("SELECT name FROM sqlite_master WHERE type='table'", [])
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
}

private func cString(s: String): Array<UInt8> {
    let bytes = ArrayList<UInt8>()
    for (b in s) {
        bytes.append(b)
    }
    bytes.append(UInt8(0))
    return bytes.toOwnedSlice()
}

private func arrayPtr(bytes: Array<UInt8>): CPointer<UInt8> {
    unsafe {
        let ptr = malloc(UIntNative(bytes.size))
        let out = CPointer<UInt8>(ptr)
        for (i in 0..bytes.size) {
            (out + i).write(bytes[i])
        }
        return out
    }
}

private func cStringToString(ptr: CPointer<UInt8>): String {
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

private func sqliteStaticDestructor(): CPointer<Unit> {
    return CPointer<Unit>()
}

private func readBlob(stmt: CPointer<Unit>, column: Int32): Array<UInt8> {
    unsafe {
        let len = sqlite3_column_bytes(stmt, column)
        let blob = sqlite3_column_blob(stmt, column)
        if (len <= 0 || blob.isNull()) {
            return Array<UInt8>()
        }
        let result = ArrayList<UInt8>()
        let bytes = CPointer<UInt8>(blob)
        for (i in 0..Int64(len)) {
            result.append((bytes + i).read())
        }
        return result.toOwnedSlice()
    }
}

/// SQLite 预编译语句
/// 对应 Bun: src/sql/Statement
class SQLiteStatement <: Statement {
    private var db: SQLiteDatabase
    private var sql: String
    private var stmtHandle: CPointer<Unit>
    private var bound: Bool
    private var boundBuffers: ArrayList<CPointer<Unit>>

    public init(db: SQLiteDatabase, sql: String) {
        this.db = db
        this.sql = sql
        this.stmtHandle = CPointer<Unit>()
        this.bound = false
        this.boundBuffers = ArrayList<CPointer<Unit>>()
        var stmt = CPointer<Unit>()
        let sqlBytes = cString(sql)
        unsafe {
            let stmtBuf = malloc(UIntNative(8))
            let stmtPtr = CPointer<CPointer<Unit>>(stmtBuf)
            stmtPtr.write(CPointer<Unit>())
            let sqlPtr = arrayPtr(sqlBytes)
            let rc = sqlite3_prepare_v2(db.handle, sqlPtr, -1, stmtPtr, CPointer<CPointer<UInt8>>())
            stmt = stmtPtr.read()
            free(CPointer<Unit>(sqlPtr))
            free(stmtBuf)
            if (rc != SQLiteConstants.OK) {
                throw BaoError(ErrorCode.InvalidArgument, "Failed to prepare statement: ${cStringToString(sqlite3_errmsg(db.handle))}")
            }
        }
        this.stmtHandle = stmt
    }

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
                    let textBytes = cString(v)
                    let textPtr = arrayPtr(textBytes)
                    boundBuffers.append(CPointer<Unit>(textPtr))
                    sqlite3_bind_text(stmtHandle, idx, textPtr, Int32(v.size), sqliteStaticDestructor())
                case SqlValue.Blob(v) =>
                    let blobPtr = arrayPtr(v)
                    boundBuffers.append(CPointer<Unit>(blobPtr))
                    sqlite3_bind_blob(stmtHandle, idx, CPointer<Unit>(blobPtr), Int32(v.size), sqliteStaticDestructor())
            }
            if (rc != SQLiteConstants.OK) {
                throw BaoError(ErrorCode.InvalidArgument, "Bind failed at index ${idx}: ${cStringToString(sqlite3_errmsg(db.handle))}")
            }
        }
    }

    public func bindNamed(params: HashMap<String, SqlValue>): Unit {
        clearBoundBuffers()
        for (key in params.keys()) {
            let nameBytes = cString(key)
            unsafe {
                let namePtr = arrayPtr(nameBytes)
                let idx = sqlite3_bind_parameter_index(stmtHandle, namePtr)
                free(CPointer<Unit>(namePtr))
                if (idx == 0) {
                    throw BaoError(ErrorCode.InvalidArgument, "Unknown SQLite parameter: ${key}")
                }
                match (params.get(key)) {
                    case Some(value) => bindValue(idx, value)
                    case None => ()
                }
            }
        }
        bound = true
    }

    public func exec(): Int64 {
        unsafe {
            let rc = sqlite3_step(stmtHandle)
            sqlite3_reset(stmtHandle)
            if (rc != SQLiteConstants.DONE && rc != SQLiteConstants.ROW) {
                throw BaoError(ErrorCode.InvalidArgument, "Statement execution failed: ${cStringToString(sqlite3_errmsg(db.handle))}")
            }
            return Int64(sqlite3_changes(db.handle))
        }
    }

    public func query(): SqlResult {
        let result = SqlResult()
        unsafe {
            let colCount = sqlite3_column_count(stmtHandle)
            for (i in 0..colCount) {
                result.columns.append(cStringToString(sqlite3_column_name(stmtHandle, i)))
            }

            var rc = sqlite3_step(stmtHandle)
            while (rc == SQLiteConstants.ROW) {
                let row = ArrayList<SqlValue>()
                for (i in 0..colCount) {
                    let columnType = sqlite3_column_type(stmtHandle, i)
                    if (columnType == SQLiteConstants.INTEGER) {
                        row.append(SqlValue.Integer(sqlite3_column_int64(stmtHandle, i)))
                    } else if (columnType == SQLiteConstants.FLOAT) {
                        row.append(SqlValue.Float(sqlite3_column_double(stmtHandle, i)))
                    } else if (columnType == SQLiteConstants.TEXT) {
                        row.append(SqlValue.Text(cStringToString(sqlite3_column_text(stmtHandle, i))))
                    } else if (columnType == SQLiteConstants.BLOB) {
                        row.append(SqlValue.Blob(readBlob(stmtHandle, i)))
                    } else {
                        row.append(SqlValue.Null)
                    }
                }
                result.rows.append(row)
                rc = sqlite3_step(stmtHandle)
            }

            sqlite3_reset(stmtHandle)
            if (rc != SQLiteConstants.DONE) {
                throw BaoError(ErrorCode.InvalidArgument, "Query failed: ${cStringToString(sqlite3_errmsg(db.handle))}")
            }
        }
        return result
    }

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

    public func finalize(): Unit {
        if (!stmtHandle.isNull()) {
            unsafe {
                sqlite3_clear_bindings(stmtHandle)
                sqlite3_finalize(stmtHandle)
            }
            clearBoundBuffers()
            stmtHandle = CPointer<Unit>()
        }
    }
}
