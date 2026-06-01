// MySQL 查询状态
// 严格翻译自: src/sql/mysql/QueryStatus.zig
package bao_runtime.sql.mysql

/// MySQL 查询状态
/// 对应 Bun: QueryStatus.Status (enum u8)
public enum QueryStatus {
    | Pending          // 0 查询已入队
    | Binding          // 1 正在绑定参数
    | Running          // 2 正在执行
    | PartialResponse  // 3 等待部分响应
    | Success          // 4 查询成功
    | Fail             // 5 查询失败

    /// 是否正在运行 (binding / running / partial_response)
    /// 对应 Bun: Status.isRunning
    public func isRunning(): Bool {
        match (this) {
            case Binding => true
            case Running => true
            case PartialResponse => true
            case _ => false
        }
    }
}
