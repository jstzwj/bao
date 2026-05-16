// 参数解析工具
// 对应 Bun: src/runtime/node/util/parse_args_utils.zig
// 严格翻译自: src/runtime/node/util/parse_args_utils.zig
package bao_runtime.node.util

// ============================================================================
// 参数选项类型
// 对应 Bun: src/runtime/node/util/parse_args_utils.zig - OptionValueType
// ============================================================================
public enum ParseArgType {
    | boolean_
    | string_

    public operator func ==(right: ParseArgType): Bool {
        match (this) {
            case boolean_ => match (right) { case boolean_ => true case _ => false }
            case string_ => match (right) { case string_ => true case _ => false }
        }
    }

    public operator func !=(right: ParseArgType): Bool {
        !(this == right)
    }
}

// ============================================================================
// 参数选项定义
// 对应 Bun: src/runtime/node/util/parse_args_utils.zig - OptionDefinition
// ============================================================================
public class ParseArgOption {
    public var longName: String = ""
    public var shortName: String = ""
    public var `type`: ParseArgType = ParseArgType.boolean_
    public var multiple: Bool = false
    public var defaultValue: ?ParseArgValue = None

    public init() {}

    public init(longName: String, shortName: String, `type`: ParseArgType, multiple: Bool) {
        this.longName = longName
        this.shortName = shortName
        this.`type` = `type`
        this.multiple = multiple
    }
}

// ============================================================================
// Token 子类型
// 对应 Bun: src/runtime/node/util/parse_args_utils.zig - TokenSubtype
// ============================================================================
public enum TokenSubtype {
    | optionTerminator
    | loneShortOption
    | shortOptionGroup
    | shortOptionAndValue
    | loneLongOption
    | longOptionAndValue
    | positional

    public operator func ==(right: TokenSubtype): Bool {
        match (this) {
            case optionTerminator => match (right) { case optionTerminator => true case _ => false }
            case loneShortOption => match (right) { case loneShortOption => true case _ => false }
            case shortOptionGroup => match (right) { case shortOptionGroup => true case _ => false }
            case shortOptionAndValue => match (right) { case shortOptionAndValue => true case _ => false }
            case loneLongOption => match (right) { case loneLongOption => true case _ => false }
            case longOptionAndValue => match (right) { case longOptionAndValue => true case _ => false }
            case positional => match (right) { case positional => true case _ => false }
        }
    }

    public operator func !=(right: TokenSubtype): Bool {
        !(this == right)
    }
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
                let firstChar = arg[1..2]
                let optIdx = findOptionByShortName(firstChar, options)
                if (optIdx.isSome()) {
                    if (options[Int64(optIdx.getOrThrow())].`type` == ParseArgType.string_) {
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
