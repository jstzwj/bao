// SQL 查询结果模式
// 严格翻译自: src/sql/shared/SQLQueryResultMode.zig
package bao_runtime.sql.shared

/// SQL 查询结果返回模式
/// 对应 Bun: SQLQueryResultMode (enum u2)
public enum SQLQueryResultMode {
    | objects  // 返回对象数组
    | values   // 返回值数组
    | raw      // 返回原始数据
}
