// 严格翻译自: src/sql_jsc/postgres/PostgresSQLContext.zig
// Postgres SQL 上下文

package bao_sql_jsc.postgres

import bao_core.*
import bao_jsc.*

/// Postgres SQL 上下文
/// 对应 Bun: PostgresSQLContext
/// 存储 VM 级别的 resolve/reject 回调函数
public class PostgresSQLContext {
    public var onQueryResolveFn: ?JscValue = None
    public var onQueryRejectFn: ?JscValue = None

    public init() {}

    /// 初始化回调
    /// 对应 Bun: PostgresSQLContext.init
    public static func init_(globalObject: JscJSGlobalObject,
                              callFrame: JscCallFrame): JscValue {
        // Stub: would get VM's rareData postgresqlContext
        return JscValue.undefined()
    }
}
