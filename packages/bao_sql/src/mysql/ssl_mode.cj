// SSL 模式
// 对应 Bun: src/sql/mysql/SSLMode.zig
package bao_sql

/// MySQL SSL 连接模式
/// 对应 Bun: SSLMode (enum u8)
public enum SSLMode <: UInt8 {
    | disable(UInt8)       // 0 - 禁用 SSL
    | prefer(UInt8)        // 1 - 优先使用 SSL
    | require(UInt8)       // 2 - 要求 SSL
    | verify_ca(UInt8)     // 3 - 验证 CA
    | verify_full(UInt8)   // 4 - 完整验证

    public init() {
        disable(0)
    }

    /// 从整数值创建
    public static func fromInt(value: UInt8): SSLMode {
        match (value) {
            case 0 => SSLMode.disable(0)
            case 1 => SSLMode.prefer(1)
            case 2 => SSLMode.require(2)
            case 3 => SSLMode.verify_ca(3)
            case 4 => SSLMode.verify_full(4)
            case _ => SSLMode.disable(0)
        }
    }

    /// 获取整数值
    public func toInt(): UInt8 {
        match (this) {
            case disable(v) => v
            case prefer(v) => v
            case require(v) => v
            case verify_ca(v) => v
            case verify_full(v) => v
        }
    }
}
