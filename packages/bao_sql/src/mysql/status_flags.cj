// MySQL 状态标志
// 对应 Bun: src/sql/mysql/StatusFlags.zig
package bao_sql.mysql

/// MySQL 服务器状态标志位
/// 对应 Bun: StatusFlag (enum u16)
public enum StatusFlag {
    | None

    /// 获取整数值
    public func value(): UInt16 {
        match (this) {
            case None => 0
        }
    }
}

/// MySQL 状态标志集合
/// 对应 Bun: StatusFlags (struct)
public class StatusFlags {
    /// 底层值
    /// 对应 Bun: _value u16
    public var _value: UInt16

    public init() {
        _value = 0
    }

    public init(value: UInt16) {
        _value = value
    }

    /// 检查是否包含指定标志
    /// 对应 Bun: StatusFlags.has
    public func has(flag: StatusFlag): Bool {
        return (_value & flag.value()) != 0
    }

    /// 转为整数
    /// 对应 Bun: StatusFlags.toInt
    public func toInt(): UInt16 {
        return _value
    }

    /// 从整数创建
    /// 对应 Bun: StatusFlags.fromInt
    public static func fromInt(flags: UInt16): StatusFlags {
        return StatusFlags(flags)
    }
}
