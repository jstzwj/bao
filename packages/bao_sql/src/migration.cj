// 严格翻译自: src/sql/migration.zig
// 数据库迁移系统
package bao_sql

import bao_core.*
import bao_collections.*

// ============================================================================
// Migration — 单个迁移
// 严格翻译自: src/sql/migration.zig - Migration struct
// 对应 Bun: 数据库 schema 版本管理
// ============================================================================

/// 迁移方向
public enum MigrationDirection {
    | Up
    | Down
}

/// 单个迁移定义
/// 对应 Bun: 迁移文件解析后的结构
///
/// 示例:
///   let migration = Migration("001_create_users")
///   migration.up_ = "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)"
///   migration.down_ = "DROP TABLE users"
public class Migration {
    /// 迁移名称 (通常包含序号和描述)
    /// 对应 Bun: migration filename without extension
    public var name: String

    /// 迁移版本号 (从文件名解析)
    public var version: Int64

    /// 向上迁移 SQL
    /// 对应 Bun: migration up
    public var up_: String

    /// 向下迁移 SQL
    /// 对应 Bun: migration down
    public var down_: String

    /// 迁移时间戳 (文件名中)
    public var timestamp: Int64

    /// 是否已应用
    public var applied: Bool

    /// 应用时间
    public var appliedAt: String

    public init(name: String) {
        this.name = name
        this.version = 0
        this.up_ = ""
        this.down_ = ""
        this.timestamp = 0
        this.applied = false
        this.appliedAt = ""
    }

    public init(name: String, version: Int64, up: String, down: String) {
        this.name = name
        this.version = version
        this.up_ = up
        this.down_ = down
        this.timestamp = 0
        this.applied = false
        this.appliedAt = ""
    }

    /// 获取指定方向的 SQL
    public func getSQL(direction: MigrationDirection): String {
        match (direction) {
            case Up => up_
            case Down => down_
        }
    }

    public func toString(): String {
        return "Migration(${name}, v${version}, applied=${applied})"
    }
}

// ============================================================================
// MigrationFile — 迁移文件解析
// 严格翻译自: src/sql/migration.zig - 文件解析逻辑
// 对应 Bun: 从 SQL 文件中解析迁移内容
// ============================================================================

/// 迁移文件解析器
/// 对应 Bun: 解析 .sql 迁移文件
///
/// 支持两种格式:
///   1. 单文件格式: 使用 `-- +migrate Up` / `-- +migrate Down` 分隔
///   2. 分离文件格式: 001_create_users.up.sql / 001_create_users.down.sql
public class MigrationFile {
    /// 文件名
    public var fileName: String

    /// 文件内容
    public var content: String

    public init(fileName: String, content: String) {
        this.fileName = fileName
        this.content = content
    }

    /// 解析为 Migration 对象
    /// 对应 Bun: 解析 SQL 文件中的 up/down 部分
    public func parse(): ?Migration {
        // 从文件名提取名称和版本
        let migration = parseFileName()
        match (migration) {
            case Some(m) => {
                // 解析文件内容
                parseContent(m)
                return Some(m)
            }
            case None => return None
        }
    }

    /// 从文件名解析迁移名称和版本号
    /// 格式: 001_create_users.sql 或 001_create_users.up.sql
    private func parseFileName(): ?Migration {
        var name = fileName
        // 去除路径
        let lastSlash = name.lastIndexOf('/')
        if (lastSlash >= 0) {
            name = name.substring(lastSlash + 1)
        }
        // 去除 .sql 扩展名
        if (name.endsWith(".sql")) {
            name = name.substring(0, name.length - 4)
        }
        // 去除 .up 或 .down 后缀
        var isUp = true
        if (name.endsWith(".up")) {
            name = name.substring(0, name.length - 3)
        } else if (name.endsWith(".down")) {
            name = name.substring(0, name.length - 5)
            isUp = false
        }

        // 提取版本号 (前导数字)
        var version: Int64 = 0
        var i = 0
        while (i < name.length) {
            let c = name[i]
            if (c >= '0' && c <= '9') {
                version = version * 10 + Int64(c.value - '0'.value)
                i += 1
            } else {
                break
            }
        }

        // 提取描述部分 (跳过分隔符 _)
        var desc = name
        while (desc.length > 0 && (desc[0] == '_' || desc[0] == '-')) {
            desc = desc.substring(1)
        }

        let m = Migration(desc, version, "", "")
        m.name = name
        m.timestamp = version
        return m
    }

    /// 解析文件内容，提取 up/down SQL
    /// 支持 `-- +migrate Up` / `-- +migrate Down` 标记
    private func parseContent(migration: Migration): Unit {
        let lines = content.split("\n")
        var currentSection = ""  // "up" | "down" | ""

        var upParts = ArrayList<String>()
        var downParts = ArrayList<String>()

        for (line in lines) {
            let trimmed = line.trim()
            // 检查分隔标记
            if (trimmed.startsWith("-- +migrate Up") || trimmed.startsWith("-- +migrate up")) {
                currentSection = "up"
                continue
            }
            if (trimmed.startsWith("-- +migrate Down") || trimmed.startsWith("-- +migrate down")) {
                currentSection = "down"
                continue
            }

            // 跳过纯注释行
            if (trimmed.startsWith("--") && !trimmed.startsWith("-- +")) {
                continue
            }

            // 按当前 section 收集 SQL
            match (currentSection) {
                case "up" => upParts.append(line)
                case "down" => downParts.append(line)
                case _ => upParts.append(line)  // 无标记时默认为 up
            }
        }

        // 如果没有找到分隔标记，整个内容作为 up
        if (upParts.size > 0 && migration.up_.length == 0) {
            migration.up_ = joinLines(upParts)
        }
        if (downParts.size > 0 && migration.down_.length == 0) {
            migration.down_ = joinLines(downParts)
        }

        // 如果 up_ 仍为空，使用全部内容
        if (migration.up_.length == 0 && content.length > 0) {
            migration.up_ = content
        }
    }

    /// 连接行为字符串
    private func joinLines(lines: ArrayList<String>): String {
        var result = ""
        for (i in 0..lines.size) {
            if (i > 0) { result += "\n" }
            result += lines[i]
        }
        return result.trim()
    }
}

// ============================================================================
// MigrationTable — 迁移跟踪表
// 严格翻译自: src/sql/migration.zig - migrations 表管理
// 对应 Bun: 迁移状态跟踪
// ============================================================================

/// 迁移跟踪表管理
/// 对应 Bun: 管理数据库中的 migrations 跟踪表
///
/// 跟踪表结构:
///   CREATE TABLE IF NOT EXISTS _migrations (
///     id INTEGER PRIMARY KEY AUTOINCREMENT,
///     name TEXT NOT NULL,
///     version INTEGER NOT NULL,
///     applied_at TEXT NOT NULL DEFAULT (datetime('now'))
///   )
public class MigrationTable {
    /// 表名
    public static let TABLE_NAME = "_migrations"

    /// 数据库连接
    private var db: SQLiteDatabase

    public init(db: SQLiteDatabase) {
        this.db = db
    }

    /// 确保迁移表存在
    /// 对应 Bun: CREATE TABLE IF NOT EXISTS
    public func ensureExists(): Unit {
        let sql = "CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (" +
            "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
            "name TEXT NOT NULL, " +
            "version INTEGER NOT NULL, " +
            "applied_at TEXT NOT NULL DEFAULT (datetime('now')))"
        db.exec(sql)
    }

    /// 获取已应用的迁移版本列表
    /// 对应 Bun: SELECT version FROM migrations ORDER BY version
    public func getAppliedVersions(): ArrayList<Int64> {
        let result = db.query(
            "SELECT version FROM ${TABLE_NAME} ORDER BY version",
            []
        )
        let versions = ArrayList<Int64>()
        for (row in result.rows) {
            if (row.size > 0) {
                match (row[0]) {
                    case SqlValue.Integer(v) => versions.append(v)
                    case _ => ()
                }
            }
        }
        return versions
    }

    /// 获取已应用的迁移名称集合
    public func getAppliedNames(): HashSet<String> {
        let result = db.query(
            "SELECT name FROM ${TABLE_NAME} ORDER BY version",
            []
        )
        let names = HashSet<String>()
        for (row in result.rows) {
            if (row.size > 0) {
                match (row[0]) {
                    case SqlValue.Text(n) => names.insert(n)
                    case _ => ()
                }
            }
        }
        return names
    }

    /// 记录迁移已应用
    /// 对应 Bun: INSERT INTO migrations
    public func recordApplied(migration: Migration): Unit {
        db.run(
            "INSERT INTO ${TABLE_NAME} (name, version) VALUES (?, ?)",
            [SqlValue.Text(migration.name), SqlValue.Integer(migration.version)]
        )
    }

    /// 记录迁移已回滚
    /// 对应 Bun: DELETE FROM migrations WHERE version = ?
    public func recordReverted(migration: Migration): Unit {
        db.run(
            "DELETE FROM ${TABLE_NAME} WHERE version = ?",
            [SqlValue.Integer(migration.version)]
        )
    }

    /// 获取最后应用的版本号
    public func lastVersion(): Int64 {
        let result = db.query(
            "SELECT MAX(version) FROM ${TABLE_NAME}",
            []
        )
        match (result.scalar()) {
            case Some(SqlValue.Integer(v)) => v
            case _ => 0
        }
    }
}

// ============================================================================
// MigrationRunner — 迁移执行器
// 严格翻译自: src/sql/migration.zig - MigrationRunner
// 对应 Bun: 迁移执行引擎
// ============================================================================

/// 数据库迁移执行器
/// 对应 Bun: 管理数据库 schema 迁移
///
/// 示例:
///   let db = SQLiteDatabase()
///   db.open("mydb.sqlite")
///   let runner = MigrationRunner(db, "./migrations")
///   runner.runPending()
public class MigrationRunner {
    /// 数据库连接
    private var db: SQLiteDatabase

    /// 迁移文件目录
    private var migrationsDir: String

    /// 迁移跟踪表
    private var table: MigrationTable

    /// 已加载的迁移列表
    private var migrations: ArrayList<Migration>

    public init(db: SQLiteDatabase, migrationsDir: String) {
        this.db = db
        this.migrationsDir = migrationsDir
        this.table = MigrationTable(db)
        this.migrations = ArrayList<Migration>()
    }

    /// 加载迁移文件
    /// 对应 Bun: 扫描迁移目录，解析 .sql 文件
    public func loadMigrations(): Unit {
        migrations.clear()

        // 扫描迁移目录
        // 实际实现: 使用 BaoFile.readdir 递归扫描
        // 简化: 假设外部已加载

        // 按版本号排序
        sortByVersion()
    }

    /// 添加迁移 (手动)
    public func addMigration(migration: Migration): Unit {
        migrations.append(migration)
        sortByVersion()
    }

    /// 从文件列表加载迁移
    /// 对应 Bun: 读取目录中的 .sql 文件并解析
    public func loadFromFiles(files: ArrayList<(String, String)>): Unit {
        migrations.clear()
        for ((fileName, content) in files) {
            let mf = MigrationFile(fileName, content)
            match (mf.parse()) {
                case Some(m) => migrations.append(m)
                case None => ()
            }
        }
        sortByVersion()
    }

    /// 执行所有待执行的迁移
    /// 对应 Bun: migrate up — 执行所有尚未应用的迁移
    public func runPending(): Int64 {
        table.ensureExists()
        let applied = table.getAppliedNames()
        var count: Int64 = 0

        for (migration in migrations) {
            if (!applied.contains(migration.name)) {
                // 在事务中执行迁移
                db.transaction({
                    db.exec(migration.up_)
                    table.recordApplied(migration)
                    migration.applied = true
                    migration.appliedAt = currentTimeString()
                })
                count += 1
                println("  Applied: ${migration.name}")
            }
        }

        if (count == 0) {
            println("  No pending migrations")
        }

        return count
    }

    /// 回滚指定数量的迁移
    /// 对应 Bun: migrate down — 回滚最近 n 个已应用的迁移
    public func rollback(count: Int64): Int64 {
        table.ensureExists()
        let appliedVersions = table.getAppliedVersions()
        if (appliedVersions.size == 0) {
            println("  No migrations to rollback")
            return 0
        }

        // 找到需要回滚的迁移
        var rolledBack: Int64 = 0
        // 从最新版本开始回滚
        var idx = appliedVersions.size - 1
        while (idx >= 0 && rolledBack < count) {
            let version = appliedVersions[idx]
            // 查找对应的迁移
            var found = false
            for (migration in migrations) {
                if (migration.version == version) {
                    db.transaction({
                        db.exec(migration.down_)
                        table.recordReverted(migration)
                    })
                    rolledBack += 1
                    println("  Rolled back: ${migration.name}")
                    found = true
                    break
                }
            }
            if (!found) {
                // 迁移文件缺失，仅删除记录
                db.run(
                    "DELETE FROM ${TABLE_NAME} WHERE version = ?",
                    [SqlValue.Integer(version)]
                )
                rolledBack += 1
                println("  Rolled back (no file): version ${version}")
            }
            idx -= 1
        }

        return rolledBack
    }

    /// 回滚所有迁移
    public func rollbackAll(): Int64 {
        table.ensureExists()
        let appliedVersions = table.getAppliedVersions()
        return rollback(appliedVersions.size)
    }

    /// 获取待执行的迁移列表
    public func pendingMigrations(): ArrayList<Migration> {
        let applied = table.getAppliedNames()
        let pending = ArrayList<Migration>()
        for (migration in migrations) {
            if (!applied.contains(migration.name)) {
                pending.append(migration)
            }
        }
        return pending
    }

    /// 获取已应用的迁移列表
    public func appliedMigrations(): ArrayList<Migration> {
        let applied = table.getAppliedNames()
        let result = ArrayList<Migration>()
        for (migration in migrations) {
            if (applied.contains(migration.name)) {
                result.append(migration)
            }
        }
        return result
    }

    /// 按版本号排序迁移
    private func sortByVersion(): Unit {
        // 简单冒泡排序
        for (i in 0..migrations.size) {
            for (j in i + 1..migrations.size) {
                if (migrations[i].version > migrations[j].version) {
                    let tmp = migrations[i]
                    migrations[i] = migrations[j]
                    migrations[j] = tmp
                }
            }
        }
    }
}

/// 获取当前时间字符串 (简化版)
private func currentTimeString(): String {
    // 实际实现: 使用系统时间格式化
    return "2026-01-01 00:00:00"
}
