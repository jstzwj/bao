// PostgreSQL 命令标签 JSC 绑定
// 严格翻译自: bun/src/sql_jsc/postgres/command_tag_jsc.zig
//   pub fn toJSTag(this: CommandTag, globalObject: *jsc.JSGlobalObject) bun.JSError!jsc.JSValue
//   pub fn toJSNumber(this: CommandTag) JSValue
package bao_runtime.sql.postgresql


/// PostgreSQL 命令标签 JSC 转换器
/// 对应 Bun command_tag_jsc (文件级函数)
/// 将 CommandTag 转为 JS 可用的值
public class CommandTagJSC {

    /// 将 CommandTag 转为 JS 标签值
    /// 对应 Bun CommandTag.toJSTag()
    ///
    /// 返回值:
    ///   INSERT -> 1, DELETE -> 2, UPDATE -> 3, MERGE -> 4,
    ///   SELECT -> 5, MOVE -> 6, FETCH -> 7, COPY -> 8,
    ///   其他 -> 字符串标签
    public static func toJSTag(tag: CommandTag): JSTagValue {
        match (tag) {
            case CommandTag.INSERT(_) => JSTagValue.Number(1)
            case CommandTag.DELETE(_) => JSTagValue.Number(2)
            case CommandTag.UPDATE(_) => JSTagValue.Number(3)
            case CommandTag.MERGE(_) => JSTagValue.Number(4)
            case CommandTag.SELECT(_) => JSTagValue.Number(5)
            case CommandTag.MOVE(_) => JSTagValue.Number(6)
            case CommandTag.FETCH(_) => JSTagValue.Number(7)
            case CommandTag.COPY(_) => JSTagValue.Number(8)
            case CommandTag.Other(s) => JSTagValue.String(s)
        }
    }

    /// 将 CommandTag 转为 JS 数字 (受影响行数)
    /// 对应 Bun CommandTag.toJSNumber()
    ///
    /// 返回值:
    ///   已知命令 -> 行数
    ///   其他 -> 0
    public static func toJSNumber(tag: CommandTag): UInt64 {
        match (tag) {
            case CommandTag.INSERT(n) => n
            case CommandTag.DELETE(n) => n
            case CommandTag.UPDATE(n) => n
            case CommandTag.MERGE(n) => n
            case CommandTag.SELECT(n) => n
            case CommandTag.MOVE(n) => n
            case CommandTag.FETCH(n) => n
            case CommandTag.COPY(n) => n
            case CommandTag.Other(_) => 0
        }
    }

    /// 将 CommandTag 转为完整的 JS 结果对象
    /// 组合标签和行数信息
    public static func toJSResult(tag: CommandTag): JSCommandResult {
        JSCommandResult(
            tag: toJSTag(tag),
            rowCount: toJSNumber(tag)
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
