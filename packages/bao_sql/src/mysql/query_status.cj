// MySQL 查询状态
// 对应 Bun: src/sql/mysql/QueryStatus.zig
package bao_sql

/// MySQL 查询状态枚举
/// 对应 Bun: QueryStatus.Status (enum u8)
public enum QueryStatus <: UInt8 {
    | pending(UInt8)            // 0 - 查询已入队
    | binding(UInt8)            // 1 - 正在绑定参数
    | running(UInt8)            // 2 - 查询执行中
    | partial_response(UInt8)   // 3 - 等待部分响应
    | success(UInt8)            // 4 - 查询成功
    | fail(UInt8)               // 5 - 查询失败

    public init() {
        pending(0)
    }

    /// 判断查询是否正在运行
    /// 对应 Bun: Status.isRunning
    public func isRunning(): Bool {
        let val = this.toUInt8()
        return val > QueryStatus.pending(0).toUInt8() && val < QueryStatus.success(4).toUInt8()
    }
}
