// MySQL 状态标志
// 严格翻译自: src/sql/mysql/StatusFlags.zig
package bao_runtime.sql.mysql

import bao_core.*

/// MySQL 服务器状态标志位
/// 对应 Bun: StatusFlag (enum u16)
public enum StatusFlag <: UInt16 {
    | SERVER_STATUS_IN_TRANS(1)
    | SERVER_STATUS_AUTOCOMMIT(2)
    | SERVER_MORE_RESULTS_EXISTS(8)
    | SERVER_STATUS_NO_GOOD_INDEX_USED(16)
    | SERVER_STATUS_NO_INDEX_USED(32)
    | SERVER_STATUS_CURSOR_EXISTS(64)
    | SERVER_STATUS_LAST_ROW_SENT(128)
    | SERVER_STATUS_DB_DROPPED(256)
    | SERVER_STATUS_NO_BACKSLASH_ESCAPES(512)
    | SERVER_STATUS_METADATA_CHANGED(1024)
    | SERVER_QUERY_WAS_SLOW(2048)
    | SERVER_PS_OUT_PARAMS(4096)
    | SERVER_STATUS_IN_TRANS_READONLY(8192)
    | SERVER_SESSION_STATE_CHANGED(16384)
}

/// MySQL 状态标志集合
/// 对应 Bun: StatusFlags (struct)
public class StatusFlags {
    public var value: UInt16

    public init() {
        value = 0
    }

    public init(value: UInt16) {
        this.value = value
    }

    /// 检查是否包含指定标志
    /// 对应 Bun: StatusFlags.has
    public func has(flag: StatusFlag): Bool {
        return (value & flag.value) != 0
    }

    /// 转为整数
    /// 对应 Bun: StatusFlags.toInt
    public func toInt(): UInt16 {
        return value
    }

    /// 从整数创建
    /// 对应 Bun: StatusFlags.fromInt
    public static func fromInt(flags: UInt16): StatusFlags {
        return StatusFlags(value: flags)
    }
}
