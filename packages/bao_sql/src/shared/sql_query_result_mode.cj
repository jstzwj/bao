// 严格翻译自: src/sql/shared/SQLQueryResultMode.zig
// SQL 查询结果模式
package bao_sql.shared

/// SQL 查询结果返回模式
/// 对应 Bun: SQLQueryResultMode (enum u2)
public enum SQLQueryResultMode {
    | objects
    | values
    | raw

    /// 获取整数值
    public func toInt(): UInt8 {
        match (this) {
            case objects => 0
            case values => 1
            case raw => 2
        }
    }

    /// 从整数值创建
    public static func fromInt(value: UInt8): SQLQueryResultMode {
        match (value) {
            case 0 => SQLQueryResultMode.objects
            case 1 => SQLQueryResultMode.values
            case 2 => SQLQueryResultMode.raw
            case _ => SQLQueryResultMode.objects
        }
    }
}
