// 参数解析工具
// 对应 Bun: src/runtime/node/util/parse_args_utils.zig
// 严格翻译自: src/runtime/node/util/parse_args_utils.zig
package bao_runtime.node.util

// ============================================================================
// 参数选项类型
// 对应 Bun: src/runtime/node/util/parse_args_utils.zig - OptionValueType
// ============================================================================
public enum ParseArgType {
    boolean,
    string
}

// ============================================================================
// 参数选项定义
// 对应 Bun: src/runtime/node/util/parse_args_utils.zig - OptionDefinition
// ============================================================================
public class ParseArgOption {
    public var longName: String = ""
    public var shortName: String = ""
    public var type: ParseArgType = ParseArgType.boolean
    public var multiple: Bool = false
    public var defaultValue: ?ParseArgValue = None

    public init() {}

    public init(longName: String, shortName: String, type: ParseArgType, multiple: Bool) {
        this.longName = longName
        this.shortName = shortName
        this.type = type
        this.multiple = multiple
    }
}

// ============================================================================
// Token 子类型
// 对应 Bun: src/runtime/node/util/parse_args_utils.zig - TokenSubtype
// ============================================================================
public enum TokenSubtype {
    optionTerminator,      // "--"
    loneShortOption,       // "-f"
    shortOptionGroup,      // "-fXzy"
    shortOptionAndValue,   // "-fFILE"
    loneLongOption,        // "--foo"
    longOptionAndValue,    // "--foo=bar"
    positional
}

// ============================================================================
// Token 分类
// 对应 Bun: src/runtime/node/util/parse_args_utils.zig - classifyToken
// ============================================================================
public class TokenClassifier {
    // 对参数 token 进行分类
    public static func classifyToken(arg: String, options: Array<ParseArgOption>): TokenSubtype {
        let len = arg.size

        if (len == 2) {
            if (arg.startsWith("-")) {
                if (arg.startsWith("--")) {
                    return TokenSubtype.optionTerminator
                }
                return TokenSubtype.loneShortOption
            }
        } else if (len > 2) {
            if (arg.startsWith("--")) {
                if (arg.contains('=')) {
                    return TokenSubtype.longOptionAndValue
                }
                return TokenSubtype.loneLongOption
            } else if (arg.startsWith("-")) {
                let firstChar = arg.substring(1, 2)
                let optIdx = findOptionByShortName(firstChar, options: options)
                if (optIdx != None) {
                    if (options[Int64(optIdx.getOrThrow())].type == ParseArgType.string) {
                        return TokenSubtype.shortOptionAndValue
                    }
                    return TokenSubtype.shortOptionGroup
                } else {
                    return TokenSubtype.shortOptionGroup
                }
            }
        }

        return TokenSubtype.positional
    }

    // 根据短名称查找选项索引
    private static func findOptionByShortName(shortName: String, options: Array<ParseArgOption>): ?Int64 {
        for (i in 0..options.size) {
            if (options[i].shortName == shortName) {
                return i
            }
        }
        return None
    }
}
