// MySQL 状态标志
// 严格翻译自: src/sql/mysql/StatusFlags.zig
package bao_runtime.sql.mysql

import bao_core.*

/// MySQL 服务器状态标志位
/// 对应 Bun: StatusFlag (enum u16)
public enum StatusFlag {
    | SERVER_STATUS_IN_TRANS(UInt16)
    | SERVER_STATUS_AUTOCOMMIT(UInt16)
    | SERVER_MORE_RESULTS_EXISTS(UInt16)
    | SERVER_STATUS_NO_GOOD_INDEX_USED(UInt16)
    | SERVER_STATUS_NO_INDEX_USED(UInt16)
    | SERVER_STATUS_CURSOR_EXISTS(UInt16)
    | SERVER_STATUS_LAST_ROW_SENT(UInt16)
    | SERVER_STATUS_DB_DROPPED(UInt16)
    | SERVER_STATUS_NO_BACKSLASH_ESCAPES(UInt16)
    | SERVER_STATUS_METADATA_CHANGED(UInt16)
    | SERVER_QUERY_WAS_SLOW(UInt16)
    | SERVER_PS_OUT_PARAMS(UInt16)
    | SERVER_STATUS_IN_TRANS_READONLY(UInt16)
    | SERVER_SESSION_STATE_CHANGED(UInt16)

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
    public var value: UInt16

    public init() {
        value = 0
    }

    public init(val: UInt16) {
        this.value = val
    }

    /// 检查是否包含指定标志
    /// 对应 Bun: StatusFlags.has
    public func has(flag: StatusFlag): Bool {
        return (value & flag.value()) != 0
    }

    /// 转为整数
    /// 对应 Bun: StatusFlags.toInt
    public func toInt(): UInt16 {
        return value
    }

    /// 从整数创建
    /// 对应 Bun: StatusFlags.fromInt
    public static func fromInt(flags: UInt16): StatusFlags {
        return StatusFlags(flags)
    }
}
