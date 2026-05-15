// SSL 模式
// 对应 Bun: src/sql/mysql/SSLMode.zig
package bao_sql.mysql

/// MySQL SSL 连接模式
/// 对应 Bun: SSLMode (enum u8)
public enum SSLMode {
    | None
}

    /// 从整数值创建
    public static func fromInt(value: UInt8): SSLMode {
        match (value) {
            | 0 => SSLMode.disable(0)
            | 1 => SSLMode.prefer(1)
            | 2 => SSLMode.require(2)
            | 3 => SSLMode.verify_ca(3)
            | 4 => SSLMode.verify_full(4)
            | _ => SSLMode.disable(0)
        }
    }

    /// 获取整数值
    public func toInt(): UInt8 {
        match (this) {
            | disable(v) => v
            | prefer(v) => v
            | require(v) => v
            | verify_ca(v) => v
            | verify_full(v) => v
        }
    }
}
