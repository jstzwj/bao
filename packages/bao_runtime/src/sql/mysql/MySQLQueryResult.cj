// MySQL 查询结果
// 严格翻译自: src/sql/mysql/MySQLQueryResult.zig
package bao_runtime.sql.mysql

/// MySQL 查询结果结构
/// 对应 Bun: MySQLQueryResult (裸结构体字段)
public class MySQLQueryResult {
    /// 结果数量
    public var resultCount: UInt64
    /// 最后插入 ID
    public var lastInsertId: UInt64
    /// 影响行数
    public var affectedRows: UInt64
    /// 是否为最后一个结果
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
