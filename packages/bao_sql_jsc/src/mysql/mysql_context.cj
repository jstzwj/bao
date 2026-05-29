// 严格翻译自: src/sql_jsc/mysql/MySQLContext.zig
// MySQL 上下文 - 存储全局回调函数

package bao_sql_jsc.mysql

import bao_core.*
import bao_jsc.*
import bao_sql_jsc.SqlRareDataRegistry

/// MySQL 上下文
/// 对应 Bun: MySQLContext
/// 存储 VM 级别的 resolve/reject 回调函数
public class MySQLContext {
    public var onQueryResolveFn: ?JscValue = None
    public var onQueryRejectFn: ?JscValue = None

    public init() {}

    /// 初始化回调
    /// 对应 Bun: MySQLContext.init
    /// 从 JS 参数设置 SQL RareData 的 mysqlContext 的 onQueryResolveFn 和 onQueryRejectFn
    public static func init_(globalObject: JscJSGlobalObject,
                              callFrame: JscCallFrame): JscValue {
        let sqlRareData = SqlRareDataRegistry.getOrInit(globalObject)
        let ctx = sqlRareData.mysqlContext
        // 设置 resolve 和 reject 回调函数
        // 对应 Bun: vm.rareData().mysql_context.onQueryResolveFn.set(callframe.argument(0))
        //           vm.rareData().mysql_context.onQueryRejectFn.set(callframe.argument(1))
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
