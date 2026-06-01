// 严格翻译自: src/runtime/cli/colon_list_type.zig
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// ColonListType — 冒号/等号分隔列表类型
// 严格翻译自: src/runtime/cli/colon_list_type.zig - ColonListType
//
// 支持 ":" 或 "=" 作为分隔符的键值对列表解析器
// 例如: --loader .js:jsx --external:react --define KEY=VALUE
//
// Zig 版本使用 comptime 泛型 (comptime t: type, comptime value_resolver)
// 仓颉版本使用 String 值类型 (泛型简化)
// ============================================================================

/// 冒号分隔列表类型
/// 对应 Bun: ColonListType(comptime t, comptime value_resolver) -> type
/// Zig 版本使用编译期泛型，仓颉版本简化为 String 值类型
public class ColonListType {
    /// 键列表
    public var keys: ArrayList<String>

    /// 值列表
    public var values: ArrayList<String>

    public init(count: Int64) {
        keys = ArrayList<String>()
        values = ArrayList<String>()
    }

    /// 从输入列表加载键值对
    /// 对应 Bun: ColonListType.load()
    /// 支持 ":" 或 "=" 分隔符, 优先使用先出现的
    public func load(input: ArrayList<String>): Unit {
        for (str in input) {
            // 查找分隔符: 支持 ":" 或 "=", 优先使用先出现的
            // 翻译自: @min(strings.indexOfChar(str, ':') orelse maxInt, strings.indexOfChar(str, '=') orelse maxInt)
            let colonIdx: Int64 = str.indexOf(':') ?? -1
            let equalIdx: Int64 = str.indexOf('=') ?? -1

            var midpoint: Int64 = -1
            if (colonIdx >= 0 && equalIdx >= 0) {
                midpoint = if (colonIdx < equalIdx) { colonIdx } else { equalIdx }
            } else if (colonIdx >= 0) {
                midpoint = colonIdx
            } else if (equalIdx >= 0) {
                midpoint = equalIdx
            }

            if (midpoint < 0) {
                // 翻译自: Output.prettyErrorln("<r><red>error<r><d>:<r> expected \":\" separator", .{})
                Output.prettyErrorln("error: expected \":\" separator")
                Global.exit(1)
            }

            // 翻译自: self.keys[i] = str[0..midpoint]
            let key = str[0..midpoint]
            // 翻译自: self.values[i] = value_resolver(str[midpoint + 1 .. str.len])
            let value = str[(midpoint + 1)..]

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
