// MySQL 查询结果结构
// 对应 Bun: src/sql/mysql/MySQLQueryResult.zig
package bao_sql.mysql

/// MySQL 查询结果统计
/// 对应 Bun: MySQLQueryResult (struct)
public class MySQLQueryResult {
    public var resultCount: UInt64
    public var lastInsertId: UInt64
    public var affectedRows: UInt64
    public var isLastResult: Bool

    public init() {
        resultCount = 0
        lastInsertId = 0
        affectedRows = 0
        isLastResult = false
    }

    public init(resultCount: UInt64, lastInsertId: UInt64, affectedRows: UInt64, isLastResult: Bool) {
        this.resultCount = resultCount
        this.lastInsertId = lastInsertId
        this.affectedRows = affectedRows
        this.isLastResult = isLastResult
    }
}
