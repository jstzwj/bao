// 严格翻译自: src/sql_jsc/postgres.rs
// Postgres 模块入口 - Postgres 绑定对象创建和子模块树

package bao_sql_jsc

import bao_core.*
import bao_jsc.*
import bao_sql.*

/// 创建 Postgres 绑定对象
/// 对应 Bun: postgres.rs create_binding
public func createPostgresBinding2(globalObject: JscJSGlobalObject): JscValue {
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

    return binding
}

// ============================================================================
// Postgres 子模块重新导出
// 对应 Bun: postgres.rs 中的 pub mod / pub use 声明
// ============================================================================

// SASL 认证
public type SASLClass = SASL

// 认证状态
public type AuthenticationStateClass = AuthenticationState

// Postgres SQL 上下文
public type PostgresSQLContextClass = PostgresSQLContext

// 签名
public type SignatureClass = Signature

// 命令标签 JSC
// 已由 command_tag_jsc.cj 提供

// 错误 JSC
// 已由 error_jsc.cj 提供

// Postgres SQL 语句
public type PostgresSQLStatementClass = PostgresSQLStatement

// Postgres SQL 连接
public type PostgresSQLConnectionClass = PostgresSQLConnection

// Postgres SQL 查询
public type PostgresSQLQueryClass = PostgresSQLQuery

// Postgres 请求
public type PostgresRequestClass = PostgresRequest

// 数据单元格
public type DataCellClass = DataCell
