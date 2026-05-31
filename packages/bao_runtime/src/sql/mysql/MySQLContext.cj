// MySQL JS 上下文绑定
// 严格翻译自: src/sql_jsc/mysql/MySQLContext.zig
//
// MySQLContext 保存全局的 MySQL JS 回调函数引用，
// 在 JS 层初始化时注册 resolve/reject 回调。
package bao_runtime.sql.mysql

import bao_core.*

/// MySQL 上下文
/// 对应 Bun: MySQLContext
/// 保存查询 resolve/reject 的全局回调函数
public class MySQLContext {
    /// 查询成功回调
    public var onQueryResolveFn: JSValueRef
    /// 查询失败回调
    public var onQueryRejectFn: JSValueRef

    public init() {
        onQueryResolveFn = JSValueRef()
        onQueryRejectFn = JSValueRef()
    }

    /// 初始化 (注册 JS 回调)
    /// 对应 Bun: MySQLContext.init
    public static func initContext(globalObject: JSValueRef, arguments: ArrayList<JSValueRef>): JSValueRef {
        if (arguments.size < 2) {
            return JSValueRef.UNDEFINED
        }
        let ctx = MySQLContext()
        ctx.onQueryResolveFn = arguments[0]
        ctx.onQueryRejectFn = arguments[1]
        return JSValueRef.UNDEFINED
    }
}
