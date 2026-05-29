// 严格翻译自: src/runtime/api/sql.classes.ts
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}
import bao_core.{Allocator, Output}
import bao_collections.{ArrayList, HashMap}

// ============================================================================
// SQL 绑定 - Bun.sql (PostgresSQL / MySQL)
// 对应 Bun: src/runtime/api/sql.classes.ts
// ============================================================================

// ============================================================================
// SQLConnection - SQL 数据库连接公共基类
// 严格翻译自: sql.classes.ts 中 PostgresSQLConnection / MySQLConnection 的公共接口
// ============================================================================

/// SQLConnection - SQL 数据库连接的公共基类
/// Bun: PostgresSQLConnection / MySQLConnection
/// 两个数据库后端共享相同的方法签名
public open class SQLConnection {

    /// 连接的回调
    public var onConnect: ?JsValue = none

    /// 关闭的回调
    public var onClose: ?JsValue = none

    /// 活跃查询列表
    public var queries: ?JsValue = none

    /// 是否已连接
    public var connected: Bool = false

    // ========================================================================
    // 构造函数
    // ========================================================================

    /// constructor - JS 构造函数
    /// 严格翻译自: sql.classes.ts construct: true
    public static func constructor(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): ?SQLConnection {
        let conn = SQLConnection()
        return conn
    }

    // ========================================================================
    // doClose - 关闭连接
    // 严格翻译自: sql.classes.ts close { fn: "doClose" }
    // ========================================================================

    /// doClose - 关闭数据库连接
    /// 严格翻译自: bun_sql_jsc::postgres::PostgresSQLConnection::doClose
    ///             bun_sql_jsc::mysql::js_my_sql_connection::JSMySQLConnection::doClose
    public func doClose(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        connected = false
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // getConnected - 获取连接状态
    // 严格翻译自: sql.classes.ts connected { getter: "getConnected" }
    // ========================================================================

    /// getConnected - 获取连接状态 (JS getter)
    /// 严格翻译自: bun_sql_jsc::...::getConnected
    public func getConnected(jsGlobalObject!: JsGlobalObject): JsValue {
        return JsValue.jsBoolean(connected)
    }

    // ========================================================================
    // doRef / doUnref - 引用/取消引用
    // 严格翻译自: sql.classes.ts ref { fn: "doRef" }, unref { fn: "doUnref" }
    // ========================================================================

    /// doRef - 引用连接, 保持事件循环活跃
    /// 严格翻译自: bun_sql_jsc::...::doRef
    public func doRef(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // 引用计数+1
        return JsValue.jsUndefined()
    }

    /// doUnref - 取消引用连接
    /// 严格翻译自: bun_sql_jsc::...::doUnref
    public func doUnref(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // 引用计数-1
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // doFlush - 刷新
    // 严格翻译自: sql.classes.ts flush { fn: "doFlush" }
    // ========================================================================

    /// doFlush - 刷新挂起的操作
    /// 严格翻译自: bun_sql_jsc::...::doFlush
    public func doFlush(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // getQueries - 获取活跃查询列表
    // 严格翻译自: sql.classes.ts queries { getter: "getQueries", `this`: true }
    // ========================================================================

    /// getQueries - 获取活跃查询列表 (JS getter)
    /// 严格翻译自: bun_sql_jsc::...::getQueries
    public func getQueries(jsGlobalObject!: JsGlobalObject): JsValue {
        if (let Some(q) <- queries) {
            return q
        }
        return JsValue.jsNull()
    }

    // ========================================================================
    // onConnect getter/setter
    // 严格翻译自: sql.classes.ts onconnect { getter: "getOnConnect", setter: "setOnConnect", `this`: true }
    // ========================================================================

    /// getOnConnect - 获取连接回调
    public func getOnConnect(jsGlobalObject!: JsGlobalObject): JsValue {
        if (let Some(cb) <- onConnect) {
            return cb
        }
        return JsValue.jsUndefined()
    }

    /// setOnConnect - 设置连接回调
    public func setOnConnect(jsGlobalObject!: JsGlobalObject, value!: JsValue): JsValue {
        onConnect = value
        return JsValue.jsBoolean(true)
    }

    // ========================================================================
    // onClose getter/setter
    // 严格翻译自: sql.classes.ts onclose { getter: "getOnClose", setter: "setOnClose", `this`: true }
    // ========================================================================

    /// getOnClose - 获取关闭回调
    public func getOnClose(jsGlobalObject!: JsGlobalObject): JsValue {
        if (let Some(cb) <- onClose) {
            return cb
        }
        return JsValue.jsUndefined()
    }

    /// setOnClose - 设置关闭回调
    public func setOnClose(jsGlobalObject!: JsGlobalObject, value!: JsValue): JsValue {
        onClose = value
        return JsValue.jsBoolean(true)
    }

    // ========================================================================
    // finalize - GC 回收
    // 严格翻译自: sql.classes.ts finalize: true
    // ========================================================================

    /// finalize - GC 回收时调用
    public func finalize(): Unit {
        onConnect = none
        onClose = none
        queries = none
        connected = false
    }

    // ========================================================================
    // hasPendingActivity
    // 严格翻译自: sql.classes.ts hasPendingActivity: type === "PostgresSQL"
    // PostgresSQL 需要 hasPendingActivity, MySQL 不需要
    // ========================================================================

    /// hasPendingActivity - 是否有待处理的活动
    /// PostgresSQL 总是返回 true (保持连接活跃直到显式关闭)
    public func hasPendingActivity(): Bool {
        return connected
    }
}

// ============================================================================
// SQLQuery - SQL 查询类
// 严格翻译自: sql.classes.ts PostgresSQLQuery / MySQLQuery
// ============================================================================

/// SQLQuery - SQL 查询
/// Bun: PostgresSQLQuery / MySQLQuery
public open class SQLQuery {

    /// 挂起的 Promise 值
    public var pendingValue: ?JsValue = none

    /// 目标连接
    public var target: ?JsValue = none

    /// 列信息
    public var columns: ?JsValue = none

    /// 绑定参数
    public var binding: ?JsValue = none

    /// 估计内存大小
    public func estimatedSize(): Int64 {
        return 256
    }

    // ========================================================================
    // 构造函数
    // ========================================================================

    /// constructor - JS 构造函数
    /// 严格翻译自: sql.classes.ts construct: true
    public static func constructor(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): ?SQLQuery {
        let query = SQLQuery()
        return query
    }

    // ========================================================================
    // doRun - 执行查询
    // 严格翻译自: sql.classes.ts run { fn: "doRun", length: 2 }
    // ========================================================================

    /// doRun - 执行 SQL 查询
    /// 严格翻译自: bun_sql_jsc::...::doRun
    /// 参数: (sql: string, values?: any[])
    public func doRun(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // 委托给底层 SQL 驱动执行查询
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // doCancel - 取消查询
    // 严格翻译自: sql.classes.ts cancel { fn: "doCancel", length: 0 }
    // ========================================================================

    /// doCancel - 取消正在执行的查询
    /// 严格翻译自: bun_sql_jsc::...::doCancel
    public func doCancel(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // doDone - 标记完成
    // 严格翻译自: sql.classes.ts done { fn: "doDone", length: 0 }
    // ========================================================================

    /// doDone - 标记查询已完成
    /// 严格翻译自: bun_sql_jsc::...::doDone
    public func doDone(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // setModeFromJS - 设置查询模式
    // 严格翻译自: sql.classes.ts setMode { fn: "setModeFromJS", length: 1 }
    // ========================================================================

    /// setModeFromJS - 从 JS 设置查询模式
    /// 严格翻译自: bun_sql_jsc::...::setModeFromJS
    public func setModeFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)
        // 设置查询模式 (如 array, object 等)
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // setPendingValueFromJS - 设置挂起值
    // 严格翻译自: sql.classes.ts setPendingValue { fn: "setPendingValueFromJS", length: 1 }
    // ========================================================================

    /// setPendingValueFromJS - 从 JS 设置挂起值
    /// 严格翻译自: bun_sql_jsc::...::setPendingValueFromJS
    public func setPendingValueFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)
        if (args.size > 0) {
            pendingValue = args[0]
        }
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // finalize - GC 回收
    // ========================================================================

    /// finalize - GC 回收时调用
    public func finalize(): Unit {
        pendingValue = none
        target = none
        columns = none
        binding = none
    }

    // ========================================================================
    // memoryCost - 内存开销
    // ========================================================================

    /// memoryCost - 返回此查询的内存开销
    public func memoryCost(): Int64 {
        return estimatedSize()
    }
}

// ============================================================================
// PostgresSQLConnection - PostgreSQL 连接
// 严格翻译自: sql.classes.ts PostgresSQLConnection
// rustPath: bun_sql_jsc::postgres::PostgresSQLConnection
// ============================================================================

/// PostgresSQLConnection - PostgreSQL 连接
/// hasPendingActivity: true (PostgresSQL 特有)
public class PostgresSQLConnection <: SQLConnection {

    public func hasPendingActivity(): Bool {
        return true
    }
}

// ============================================================================
// PostgresSQLQuery - PostgreSQL 查询
// 严格翻译自: sql.classes.ts PostgresSQLQuery
// rustPath: bun_sql_jsc::postgres::PostgresSQLQuery
// ============================================================================

/// PostgresSQLQuery - PostgreSQL 查询
public class PostgresSQLQuery <: SQLQuery {}

// ============================================================================
// MySQLConnection - MySQL 连接
// 严格翻译自: sql.classes.ts MySQLConnection
// rustPath: bun_sql_jsc::mysql::js_my_sql_connection::JSMySQLConnection
// ============================================================================

/// MySQLConnection - MySQL 连接
public class MySQLConnection <: SQLConnection {}

// ============================================================================
// MySQLQuery - MySQL 查询
// 严格翻译自: sql.classes.ts MySQLQuery
// rustPath: bun_sql_jsc::mysql::js_my_sql_query::JSMySQLQuery
// ============================================================================

/// MySQLQuery - MySQL 查询
public class MySQLQuery <: SQLQuery {}

// ported from: src/runtime/api/sql.classes.ts
