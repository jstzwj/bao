// MySQL 认证方法
// 对应 Bun: src/sql/mysql/AuthMethod.zig
package bao_sql

/// MySQL 认证方法枚举
/// 对应 Bun: AuthMethod (enum)
public enum AuthMethod {
    | mysql_native_password      // MySQL 原生密码认证
    | caching_sha2_password      // 缓存 SHA2 密码认证
    | sha256_password            // SHA256 密码认证

    /// 获取 scramble 结果长度
    /// 对应 Bun: AuthMethod.scrambleLength
    public func scrambleLength(): Int64 {
        match (this) {
            case mysql_native_password => 20
            case caching_sha2_password => 32
            case sha256_password => 32
        }
    }

    /// 从字符串解析认证方法
    /// 对应 Bun: AuthMethod.fromString (通过 ComptimeEnumMap)
    public static func fromString(name: String): ?AuthMethod {
        match (name) {
            case "mysql_native_password" => Some(AuthMethod.mysql_native_password)
            case "caching_sha2_password" => Some(AuthMethod.caching_sha2_password)
            case "sha256_password" => Some(AuthMethod.sha256_password)
            case _ => None
        }
    }
}
