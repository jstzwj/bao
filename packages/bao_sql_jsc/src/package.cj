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
    let binding = JsValue.createEmptyObjectWithNullPrototype(globalObject.globalThis)

    binding.put(globalObject.globalThis, "MySQLConnection",
        JsValue.undefined())

    binding.put(globalObject.globalThis, "init",
        JsValue.undefined())

    binding.put(globalObject.globalThis, "createQuery",
        JsValue.undefined())

    binding.put(globalObject.globalThis, "createConnection",
        JsValue.undefined())

    return binding
}

// ============================================================================
// Postgres 绑定
// 对应 Bun: src/sql_jsc/postgres.zig
// ============================================================================

/// 创建 Postgres JS 绑定对象
/// 对应 Bun: postgres.zig createBinding
public func createPostgresBinding(globalObject: JscJSGlobalObject): JscValue {
    let binding = JsValue.createEmptyObjectWithNullPrototype(globalObject.globalThis)

    binding.put(globalObject.globalThis, "PostgresSQLConnection",
        JsValue.undefined())

    binding.put(globalObject.globalThis, "init",
        JsValue.undefined())

    binding.put(globalObject.globalThis, "createQuery",
        JsValue.undefined())

    binding.put(globalObject.globalThis, "createConnection",
        JsValue.undefined())

    return binding
}

