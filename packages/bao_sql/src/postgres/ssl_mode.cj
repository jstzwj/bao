// 严格翻译自: src/sql/postgres/SSLMode.zig
// PostgreSQL SSL 模式
package bao_sql.postgres

/// PostgreSQL SSL 连接模式
/// 对应 Bun: SSLMode (enum u8)
public enum PostgresSSLMode {
    | disable
    | prefer
    | require
    | verify_ca
    | verify_full

    /// 获取整数值
    public func toInt(): UInt8 {
        match (this) {
            case disable => 0
            case prefer => 1
            case require => 2
            case verify_ca => 3
            case verify_full => 4
        }
    }

    /// 从整数值创建
    public static func fromInt(value: UInt8): PostgresSSLMode {
        match (value) {
            case 0 => PostgresSSLMode.disable
            case 1 => PostgresSSLMode.prefer
            case 2 => PostgresSSLMode.require
            case 3 => PostgresSSLMode.verify_ca
            case 4 => PostgresSSLMode.verify_full
            case _ => PostgresSSLMode.disable
        }
    }
}
