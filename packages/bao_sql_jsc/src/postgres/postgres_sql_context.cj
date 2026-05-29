// 严格翻译自: src/sql_jsc/postgres/PostgresSQLContext.zig
// Postgres SQL 上下文

package bao_sql_jsc.postgres

import bao_core.*
import bao_jsc.*
import bao_sql_jsc.SqlRareDataRegistry

/// Postgres SQL 上下文
/// 对应 Bun: PostgresSQLContext
/// 存储 VM 级别的 resolve/reject 回调函数
public class PostgresSQLContext {
    public var onQueryResolveFn: ?JscValue = None
    public var onQueryRejectFn: ?JscValue = None

    public init() {}

    /// 初始化回调
    /// 对应 Bun: PostgresSQLContext.init
    /// 从 JS 参数设置 SQL RareData 的 postgresqlContext 的 onQueryResolveFn 和 onQueryRejectFn
    public static func init_(globalObject: JscJSGlobalObject,
                              callFrame: JscCallFrame): JscValue {
        let sqlRareData = SqlRareDataRegistry.getOrInit(globalObject)
        let ctx = sqlRareData.postgresqlContext
        // 设置 resolve 和 reject 回调函数
        // 对应 Bun: vm.rareData().postgresql_context.onQueryResolveFn.set(callframe.argument(0))
        //           vm.rareData().postgresql_context.onQueryRejectFn.set(callframe.argument(1))
        let args = callFrame.arguments()
        if (args.size >= 1) {
            ctx.onQueryResolveFn = args[0]
        }
        if (args.size >= 2) {
            ctx.onQueryRejectFn = args[1]
        }
        return JscValue.undefined()
    }
}
