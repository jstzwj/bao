// 严格翻译自: src/sql_jsc/postgres/PostgresSQLContext.zig
// Postgres SQL 上下文

package bao_sql_jsc

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
        let ctx = globalObject.bunVM().rareData().postgresqlContext
        ctx.onQueryResolveFn = callFrame.argument(0)
        ctx.onQueryRejectFn = callFrame.argument(1)
        return JscValue.undefined()
    }
}
