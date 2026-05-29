// 严格翻译自: src/sql_jsc/mysql.zig
// MySQL 模块入口 - MySQL 绑定对象创建

package bao_sql_jsc.mysql

import bao_core.*
import bao_jsc.*
import bao_sql.*

/// 创建 MySQL 绑定对象
/// 对应 Bun: mysql.zig createBinding
public func createBinding(globalObject: JscJSGlobalObject): JscValue {
    let binding = JscValue.createEmptyObject(globalObject.globalThis)

    binding.put(globalObject.globalThis, "MySQLConnection",
        JSMySQLConnection.getConstructor(globalObject))

    // Note: JscFunction.create requires JsCallback type, 函数签名不直接匹配
    // init / createQuery / createConnection 方法暂通过构造函数方式注册
    // binding.put(globalObject.globalThis, "init", ...)
    // binding.put(globalObject.globalThis, "createQuery", ...)
    // binding.put(globalObject.globalThis, "createConnection", ...)

    return binding
}
