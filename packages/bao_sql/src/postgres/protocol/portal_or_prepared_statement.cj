// 严格翻译自: src/sql/postgres/protocol/PortalOrPreparedStatement.zig
// PostgreSQL Portal 或 PreparedStatement 标识
package bao_sql.postgres.protocol

/// Portal 或 PreparedStatement 标识
/// 对应 Bun: PortalOrPreparedStatement (union enum)
public enum PortalOrPreparedStatement {
    | portal(String)
    | prepared_statement(String)

    /// 获取名称切片
    /// 对应 Bun: PortalOrPreparedStatement.slice
    public func slice(): String {
        match (this) {
            case portal(s) => s
            case prepared_statement(s) => s
        }
    }

    /// 获取标签字节 ('P' for portal, 'S' for statement)
    /// 对应 Bun: PortalOrPreparedStatement.tag
    public func tag(): UInt8 {
        match (this) {
            case portal(_) => UInt8(80)
            case prepared_statement(_) => UInt8(83)
        }
    }
}
