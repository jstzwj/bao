// 严格翻译自: src/sql_jsc/mysql.zig + postgres.zig
// bao_sql_jsc 包入口 - SQL JS 绑定层

package bao_sql_jsc

import bao_core.*
import bao_jsc.*
import bao_sql.*

// ============================================================================
// MySQL 绑定
// 对应 Bun: src/sql_jsc/mysql.zig
// ============================================================================

/// 创建 MySQL JS 绑定对象
/// 对应 Bun: mysql.zig createBinding
public func createMySQLBinding(globalObject: JscJSGlobalObject): JscValue {
    let binding = JscObject.createEmptyObjectWithNullPrototype(globalObject)

    binding.put(globalObject, "MySQLConnection",
        JSMySQLConnection.getConstructor(globalObject))

    binding.put(globalObject, "init",
        JscFunction.create(globalObject, "init",
            MySQLContext.init_, 0))

    binding.put(globalObject, "createQuery",
        JscFunction.create(globalObject, "createQuery",
            JSMySQLQuery.createInstance_, 6))

    binding.put(globalObject, "createConnection",
        JscFunction.create(globalObject, "createConnection",
            JSMySQLConnection.createInstance_, 2))

    return binding.toValue()
}

// ============================================================================
// Postgres 绑定
// 对应 Bun: src/sql_jsc/postgres.zig
// ============================================================================

/// 创建 Postgres JS 绑定对象
/// 对应 Bun: postgres.zig createBinding
public func createPostgresBinding(globalObject: JscJSGlobalObject): JscValue {
    let binding = JscObject.createEmptyObjectWithNullPrototype(globalObject)

    binding.put(globalObject, "PostgresSQLConnection",
        PostgresSQLConnection.getConstructor(globalObject))

    binding.put(globalObject, "init",
        JscFunction.create(globalObject, "init",
            PostgresSQLContext.init_, 0))

    binding.put(globalObject, "createQuery",
        JscFunction.create(globalObject, "createQuery",
            PostgresSQLQuery.call_, 6))

    binding.put(globalObject, "createConnection",
        JscFunction.create(globalObject, "createConnection",
            PostgresSQLConnection.call_, 2))

    return binding.toValue()
}

// 公共类型重新导出
public type MySQLConnectionClass = JSMySQLConnection
public type MySQLQueryClass = JSMySQLQuery
public type PostgresConnectionClass = PostgresSQLConnection
public type PostgresQueryClass = PostgresSQLQuery
public type PostgresStatementClass = PostgresSQLStatement
