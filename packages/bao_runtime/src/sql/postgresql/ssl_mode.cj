// PostgreSQL SSL 模式
// 严格翻译自: bun/src/sql/postgres/SSLMode.zig
//   pub const SSLMode = enum(u8) {
//       disable = 0,
//       prefer = 1,
//       require = 2,
//       verify_ca = 3,
//       verify_full = 4,
//   };
package bao_runtime.sql.postgresql

/// PostgreSQL SSL 连接模式
/// 对应 Bun SSLMode
public enum SSLMode {
    | Disable      // 禁用 SSL
    | Prefer       // 优先使用 SSL
    | Require      // 必须使用 SSL
    | VerifyCA     // 验证 CA 证书
    | VerifyFull   // 完全验证证书和主机名

    public func toInt(): Int32 {
        match (this) {
            case Disable => 0
            case Prefer => 1
            case Require => 2
            case VerifyCA => 3
            case VerifyFull => 4
        }
    }

    public static func fromInt(value: Int32): SSLMode {
        match (value) {
            case 0 => Disable
            case 1 => Prefer
            case 2 => Require
            case 3 => VerifyCA
            case 4 => VerifyFull
            case _ => Disable
        }
    }
}
