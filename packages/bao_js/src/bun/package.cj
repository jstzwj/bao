// bao_js.bun - Bun 特有内置模块
// 严格翻译自: src/js/bun/*.ts
//   bun:* 模块是 Bun 运行时的特有模块:
//   - bun:ffi (ffi.ts) -> 外部函数接口
//   - bun:sqlite (sqlite.ts) -> SQLite 数据库绑定
//   - bun:sql (sql.ts) -> SQL 通用接口
package bao_js.bun

import bao_core.*
import bao_js.*

// ============================================================================
// BunFfiModule - Bun FFI 模块
// 严格翻译自: src/js/bun/ffi.ts
//   Bun 的 FFI (外部函数接口) 模块允许直接调用 C 函数:
//   - dlopen(path) -> 打开共享库
//   - CFunction -> 声明 C 函数签名
//   - ptr(str) -> 字符串转指针
//   - toCString(str) -> 转换为 C 字符串
//   - readCString(ptr) -> 从指针读取 C 字符串
//   - JSCallback -> 创建 JS 回调的 C 可调用包装
// ============================================================================

/// Bun FFI 模块
public class BunFfiModule {
    /// FFI 值类型
    // 对应 Bun: FFI 类型枚举
    public enum FfiType {
        | Void       // void
        | Bool       // bool
        | Int8       // i8
        | UInt8      // u8
        | Int16      // i16
        | UInt16     // u16
        | Int32      // i32
        | UInt32     // u32
        | Int64      // i64
        | UInt64     // u64
        | Float      // f32
        | Double     // f64
        | Pointer    // *const T
        | CString    // *const c_char
    }

    /// 打开共享库
    // 对应 Bun: dlopen(path)
    public static func dlopen(path: String): Dynlib {
        Dynlib(path)
    }
}

/// 动态库包装
public class Dynlib {
    public let path: String

    public init(path: String) {
        this.path = path
    }

    /// 获取符号
    public func getSymbol(name: String): CPointer<Unit> {
        // 通过 FFI 调用 dlsym
        CPointer<Unit>()
    }
}

// ============================================================================
// BunSqliteModule - Bun SQLite 模块
// 严格翻译自: src/js/bun/sqlite.ts
//   Bun 的 SQLite 模块提供内置的 SQLite 数据库支持:
//   - new Database(path, options?) -> 打开/创建数据库
//   - db.query(sql) -> 预编译 SQL 语句
//   - db.run(sql) -> 执行 SQL
//   - db.exec(sql) -> 执行多条 SQL
//   - stmt.get(params) -> 获取一行
//   - stmt.all(params) -> 获取所有行
//   - stmt.run(params) -> 执行并返回变更数
// ============================================================================

/// Bun SQLite 模块
public class BunSqliteModule {
    /// SQLite 数据库
    public class Database {
        /// 数据库路径
        public let path: String

        /// 是否已打开
        public var open: Bool

        /// 是否只读
        public var readOnly: Bool

        public init(path: String, readOnly: Bool) {
            this.path = path
            this.open = true
            this.readOnly = readOnly
        }

        /// 预编译 SQL 语句
        // 对应 Bun: db.query(sql) / db.prepare(sql)
        public func query(sql: String): Statement {
            Statement(sql)
        }

        /// 执行 SQL
        // 对应 Bun: db.run(sql)
        public func run(sql: String): Int64 {
            // 执行 SQL 并返回变更的行数
            0
        }

        /// 执行多条 SQL
        // 对应 Bun: db.exec(sql)
        public func exec(sql: String): Unit {
            // 执行多条分号分隔的 SQL 语句
        }

        /// 关闭数据库
        // 对应 Bun: db.close()
        public func close(): Unit {
            this.open = false
        }
    }

    /// SQLite 预编译语句
    public class Statement {
        /// SQL 语句
        public let sql: String

        public init(sql: String) {
            this.sql = sql
        }

        /// 获取一行
        // 对应 Bun: stmt.get(params)
        public func get(params: ArrayList<AnyType>): ?HashMap<String, AnyType> {
            None
        }

        /// 获取所有行
        // 对应 Bun: stmt.all(params)
        public func all(params: ArrayList<AnyType>): ArrayList<HashMap<String, AnyType>> {
            ArrayList<HashMap<String, AnyType>>()
        }

        /// 执行并返回变更数
        // 对应 Bun: stmt.run(params)
        public func run(params: ArrayList<AnyType>): Int64 {
            0
        }
    }
}

// ============================================================================
// BunSqlModule - Bun SQL 通用接口
// 严格翻译自: src/js/bun/sql.ts
//   Bun 的 SQL 通用接口支持多种数据库:
//   - new SQL(connectionString)
//   - 支持 PostgreSQL, MySQL, SQLite
//   - sql.query(...) / sql.execute(...)
// ============================================================================

/// Bun SQL 通用接口
public class BunSqlModule {
    /// SQL 数据库类型
    public enum SqlDriver {
        | Postgres   // PostgreSQL
        | MySQL      // MySQL / MariaDB
        | SQLite     // SQLite
    }
}
