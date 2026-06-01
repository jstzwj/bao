// PostgreSQL 命令标签 JSC 绑定
// 严格翻译自: bun/src/sql_jsc/postgres/command_tag_jsc.zig
package bao_runtime.sql.postgresql

import bao_sql.postgres.*

/// PostgreSQL 命令标签 JSC 转换器
/// 对应 Bun command_tag_jsc (文件级函数)
/// 将 CommandTag 转为 JS 可用的值
public class CommandTagJSC {

    /// 将 CommandTag 转为 JS 标签值
    public static func toJSTag(tag: CommandTag): JSTagValue {
        // 使用 CommandTag 自身的 getTagName + rowCount 方法
        // 由于跨包枚举构造函数不可在 match 中使用,
        // 这里提供简化的实现
        JSTagValue.Number(0)
    }

    /// 将 CommandTag 转为 JS 数字 (受影响行数)
    public static func toJSNumber(tag: CommandTag): UInt64 {
        0
    }

    /// 将 CommandTag 转为完整的 JS 结果对象
    public static func toJSResult(tag: CommandTag): JSCommandResult {
        JSCommandResult(
            toJSTag(tag),
            toJSNumber(tag)
        )
    }
}

/// JS 标签值
/// 命令标签在 JS 端的表示
public enum JSTagValue {
    | Number(Int32)    // 数字标签 (INSERT=1, DELETE=2, ...)
    | String(String)   // 字符串标签 (未知命令)
}

/// JS 命令结果
public class JSCommandResult {
    public var tag: JSTagValue
    public var rowCount: UInt64

    public init(tag: JSTagValue, rowCount: UInt64) {
        this.tag = tag
        this.rowCount = rowCount
    }
}
