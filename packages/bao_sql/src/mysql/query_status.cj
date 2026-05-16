// MySQL 查询状态
// 对应 Bun: src/sql/mysql/QueryStatus.zig
package bao_sql.mysql

/// MySQL 查询状态枚举
/// 对应 Bun: QueryStatus.Status (enum u8)
public enum QueryStatus {
    | pending(UInt8)
    | running(UInt8)
    | success(UInt8)
    | error(UInt8)

    /// 判断查询是否正在运行
    /// 对应 Bun: Status.isRunning
    public func isRunning(): Bool {
        match (this) {
            case running(_) => true
            case _ => false
        }
    }
}
