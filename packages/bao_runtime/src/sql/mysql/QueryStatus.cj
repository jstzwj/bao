// MySQL 查询状态
// 严格翻译自: src/sql/mysql/QueryStatus.zig
package bao_runtime.sql.mysql

/// MySQL 查询状态
/// 对应 Bun: QueryStatus.Status (enum u8)
public enum QueryStatus <: UInt8 {
    | pending(0)           // 查询已入队
    | binding(1)           // 正在绑定参数
    | running(2)           // 正在执行
    | partial_response(3)  // 等待部分响应
    | success(4)           // 查询成功
    | fail(5)              // 查询失败

    /// 是否正在运行 (binding / running / partial_response)
    /// 对应 Bun: Status.isRunning
    public func isRunning(): Bool {
        let v = this.value
        return v > QueryStatus.pending.value && v < QueryStatus.success.value
    }
}
