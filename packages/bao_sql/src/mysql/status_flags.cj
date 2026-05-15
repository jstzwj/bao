// MySQL 状态标志
// 对应 Bun: src/sql/mysql/StatusFlags.zig
package bao_sql

/// MySQL 服务器状态标志位
/// 对应 Bun: StatusFlag (enum u16)
public enum StatusFlag <: UInt16 {
    | SERVER_STATUS_IN_TRANS(UInt16)             // 1 - 事务中
    | SERVER_STATUS_AUTOCOMMIT(UInt16)           // 2 - 自动提交
    | SERVER_MORE_RESULTS_EXISTS(UInt16)         // 8 - 更多结果集
    | SERVER_STATUS_NO_GOOD_INDEX_USED(UInt16)   // 16 - 无好索引
    | SERVER_STATUS_NO_INDEX_USED(UInt16)        // 32 - 全表扫描
    | SERVER_STATUS_CURSOR_EXISTS(UInt16)        // 64 - 游标存在
    | SERVER_STATUS_LAST_ROW_SENT(UInt16)        // 128 - 最后一行已发送
    | SERVER_STATUS_DB_DROPPED(UInt16)           // 256 - 数据库被删除
    | SERVER_STATUS_NO_BACKSLASH_ESCAPES(UInt16) // 512 - 反斜杠转义禁用
    | SERVER_STATUS_METADATA_CHANGED(UInt16)     // 1024 - 元数据变化
    | SERVER_QUERY_WAS_SLOW(UInt16)              // 2048 - 慢查询
    | SERVER_PS_OUT_PARAMS(UInt16)               // 4096 - 输出参数
    | SERVER_STATUS_IN_TRANS_READONLY(UInt16)    // 8192 - 只读事务
    | SERVER_SESSION_STATE_CHANGED(UInt16)       // 16384 - 会话状态变化

    public func value(): UInt16 {
        match (this) {
            case SERVER_STATUS_IN_TRANS(v) => v
            case SERVER_STATUS_AUTOCOMMIT(v) => v
            case SERVER_MORE_RESULTS_EXISTS(v) => v
            case SERVER_STATUS_NO_GOOD_INDEX_USED(v) => v
            case SERVER_STATUS_NO_INDEX_USED(v) => v
            case SERVER_STATUS_CURSOR_EXISTS(v) => v
            case SERVER_STATUS_LAST_ROW_SENT(v) => v
            case SERVER_STATUS_DB_DROPPED(v) => v
            case SERVER_STATUS_NO_BACKSLASH_ESCAPES(v) => v
            case SERVER_STATUS_METADATA_CHANGED(v) => v
            case SERVER_QUERY_WAS_SLOW(v) => v
            case SERVER_PS_OUT_PARAMS(v) => v
            case SERVER_STATUS_IN_TRANS_READONLY(v) => v
            case SERVER_SESSION_STATE_CHANGED(v) => v
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
