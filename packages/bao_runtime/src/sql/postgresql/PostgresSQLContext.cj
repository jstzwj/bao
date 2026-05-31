// PostgreSQL SQL 上下文 JSC 绑定
// 严格翻译自: bun/src/sql_jsc/postgres/PostgresSQLContext.zig
//   onQueryResolveFn: jsc.Strong.Optional = .empty,
//   onQueryRejectFn: jsc.Strong.Optional = .empty,
package bao_runtime.sql.postgresql

/// PostgreSQL SQL 上下文
/// 对应 Bun PostgresSQLContext
/// 每个 VM 实例一个，存储查询回调函数
/// 不与特定连接关联，而是跨连接共享
public class PostgresSQLContext {
    /// 查询成功回调 (JS Function 引用)
    public var onQueryResolveFn: Int64
    /// 查询失败回调 (JS Function 引用)
    public var onQueryRejectFn: Int64

    public init() {
        onQueryResolveFn = 0
        onQueryRejectFn = 0
    }

    /// 初始化上下文 — 设置查询回调
    /// 对应 Bun PostgresSQLContext.init()
    ///
    /// 参数:
    ///   resolveFn - 查询成功时的 JS 回调
    ///   rejectFn - 查询失败时的 JS 回调
    public func init(resolveFn: Int64, rejectFn: Int64) {
        onQueryResolveFn = resolveFn
        onQueryRejectFn = rejectFn
    }

    /// 是否已设置回调
    public func hasCallbacks(): Bool {
        onQueryResolveFn != 0 && onQueryRejectFn != 0
    }

    /// 获取 resolve 回调
    public func getResolveFn(): ?Int64 {
        if (onQueryResolveFn != 0) {
            onQueryResolveFn
        } else {
            None
        }
    }

    /// 获取 reject 回调
    public func getRejectFn(): ?Int64 {
        if (onQueryRejectFn != 0) {
            onQueryRejectFn
        } else {
            None
        }
    }
}
