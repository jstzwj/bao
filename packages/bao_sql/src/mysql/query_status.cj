// MySQL 查询状态
// 对应 Bun: src/sql/mysql/QueryStatus.zig
package bao_sql.mysql

/// MySQL 查询状态枚举
/// 对应 Bun: QueryStatus.Status (enum u8)
public enum QueryStatus {
    | None
}

    /// 判断查询是否正在运行
    /// 对应 Bun: Status.isRunning
    public func isRunning(): Bool {
        let val = this.toUInt8()
        return val > QueryStatus.pending(0).toUInt8() && val < QueryStatus.success(4).toUInt8()
    }
}
