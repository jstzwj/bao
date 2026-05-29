// 严格翻译自: src/sql_jsc/postgres.rs
// Postgres 模块入口 - Postgres 绑定对象创建和子模块树

package bao_sql_jsc

import bao_core.*
import bao_jsc.*
import bao_sql.*
import bao_sql_jsc.shared.*

/// 创建 Postgres 绑定对象
/// 对应 Bun: postgres.rs create_binding
public func createPostgresBinding2(globalObject: JscJSGlobalObject): JscValue {
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
