// MySQL 状态标志 (protocol 包本地副本，用于打破循环依赖)
// 对应 Bun: StatusFlags (struct)
package bao_sql.mysql.protocol

/// MySQL 状态标志集合
/// 对应 Bun: StatusFlags (struct)
public class StatusFlags {
    /// 底层值
    public var _value: UInt16

    public init() {
        _value = 0
    }

    public init(value: UInt16) {
        _value = value
    }

    /// 转为整数
    public func toInt(): UInt16 {
        return _value
    }

    /// 从整数创建
    public static func fromInt(flags: UInt16): StatusFlags {
        return StatusFlags(flags)
    }
}
