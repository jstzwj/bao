// 严格翻译自: src/cli/colon_list_type.zig
package bao_cli

import bao_core.*

// ============================================================================
// ColonListType — 冒号/等号分隔列表类型
// 严格翻译自: src/cli/colon_list_type.zig - ColonListType
//
// 支持 ":" 或 "=" 作为分隔符的键值对列表解析器
// 例如: --loader .js:jsx --external:react --define KEY=VALUE
// ============================================================================

/// 冒号分隔列表类型
/// 对应 Bun: ColonListType(comptime t, comptime value_resolver)
public class ColonListType {
    /// 键列表
    public var keys: ArrayList<String>

    /// 值列表
    public var values: ArrayList<String>

    public init(count: Int64) {
        keys = ArrayList<String>(count)
        values = ArrayList<String>(count)
    }

    /// 从输入列表加载键值对
    /// 对应 Bun: ColonListType.load()
    /// 支持 ":" 或 "=" 分隔符, 优先使用先出现的
    public func load(input: ArrayList<String>): Unit {
        for (str in input) {
            // 查找分隔符: 支持 ":" 或 "=", 优先使用先出现的
            let colonIdx = str.indexOf(':')
            let equalIdx = str.indexOf('=')

            var midpoint = -1
            if (colonIdx >= 0 && equalIdx >= 0) {
                midpoint = Math.min(colonIdx, equalIdx)
            } else if (colonIdx >= 0) {
                midpoint = colonIdx
            } else if (equalIdx >= 0) {
                midpoint = equalIdx
            }

            if (midpoint < 0) {
                Output.prettyErrorLn("error: expected \":\" separator")
                Global.exit(1)
            }

            let key = str.substring(0, midpoint)
            let value = str.substring(midpoint + 1)

            keys.append(key)
            values.append(value)
        }
    }

    /// 解析并创建 ColonListType
    /// 对应 Bun: ColonListType.resolve()
    public static func resolve(input: ArrayList<String>): ColonListType {
        let list = ColonListType(input.size)
        list.load(input)
        return list
    }
}
