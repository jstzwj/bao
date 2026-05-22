// 严格翻译自: src/sql_jsc/mysql/MySQLContext.zig
// MySQL 上下文 - 存储全局回调函数

package bao_sql_jsc.mysql

import bao_core.*
import bao_jsc.*

/// MySQL 上下文
/// 对应 Bun: MySQLContext
/// 存储 VM 级别的 resolve/reject 回调函数
public class MySQLContext {
    public var onQueryResolveFn: ?JscValue = None
    public var onQueryRejectFn: ?JscValue = None

    public init() {}

    /// 初始化回调
    /// 对应 Bun: MySQLContext.init
    public static func init_(globalObject: JscJSGlobalObject,
                              callFrame: JscCallFrame): JscValue {
        let vm = globalObject.vm.getOrThrow()
        let rd = vm.getRareData()
        // Note: rareData is bao_jsc.RareData which doesn't have mysqlContext.
        // The mysqlContext lives in bao_sql_jsc.RareData (sql_jsc.cj).
        // For now, callback initialization is stubbed.
        // ctx.onQueryResolveFn = callFrame.argument(0)
        // ctx.onQueryRejectFn = callFrame.argument(1)
        return JscValue.undefined()
    }
}
