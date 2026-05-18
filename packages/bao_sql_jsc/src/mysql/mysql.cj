// 严格翻译自: src/sql_jsc/mysql.zig
// MySQL 模块入口 - MySQL 绑定对象创建

package bao_sql_jsc.mysql

import bao_core.*
import bao_jsc.*
import bao_sql.*

/// 创建 MySQL 绑定对象
/// 对应 Bun: mysql.zig createBinding
public func createBinding(globalObject: JscJSGlobalObject): JscValue {
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

    return binding
}
