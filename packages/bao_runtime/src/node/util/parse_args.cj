// 命令行参数解析器（完整翻译）
// 对应 Bun: src/runtime/node/util/parse_args.zig
// 严格翻译自: src/runtime/node/util/parse_args.zig
package bao_runtime.node.util

import bao_core.*

// ============================================================================
// 选项值类型
// 对应 Bun: parse_args_utils.zig - OptionValueType
// ============================================================================
public enum OptionValueType {
    boolean,
    string
}

// ============================================================================
// Token 子类型
// 对应 Bun: parse_args_utils.zig - TokenSubtype
// ============================================================================
public enum TokenSubtype {
    optionTerminator,    // "--"
    loneShortOption,     // "-f"
    shortOptionGroup,    // "-fXzy"
    shortOptionAndValue, // "-fFILE"
    loneLongOption,      // "--foo"
    longOptionAndValue,  // "--foo=bar"
    positional           // 非选项参数
}

// ============================================================================
// 选项定义
// 对应 Bun: parse_args_utils.zig - OptionDefinition
// 描述一个命令行选项的元数据
// ============================================================================
public class OptionDefinition {
    // 长选项名，例如 "abc" 对应 --abc
    public var longName: String = ""

    // 短选项名，例如 "a" 对应 -a
    // 长度为 0 表示没有短名
    public var shortName: String = ""

    // 值类型
    public var type: OptionValueType = OptionValueType.boolean

    // 是否允许多个值
    public var multiple: Bool = false

    // 默认值
    public var defaultValue: ?ParseArgValue = None

    public init() {}

    public init(longName: String, shortName: String, type: OptionValueType, multiple: Bool) {
        this.longName = longName
        this.shortName = shortName
        this.type = type
        this.multiple = multiple
    }
}

// ============================================================================
// 参数解析结果
// 对应 Bun: parse_args.zig - ParseArgsState 输出的 values/positionals/tokens
// ============================================================================
public class ParseArgsResult {
    // 选项值映射
    public var values: Map<String, ParseArgValue> = HashMap<String, ParseArgValue>()
    // 位置参数
    public var positionals: Array<String> = Array<String>()
    // 解析 tokens（仅在 returnTokens=true 时填充）
    public var tokens: Array<ParseToken> = Array<ParseToken>()

    public init() {}
}

// ============================================================================
// 参数值（可以是布尔、字符串或数组）
// ============================================================================
public class ParseArgValue {
    public var boolValue: Bool = false
    public var stringValue: String = ""
    public var isBool: Bool = true
    public var isArray: Bool = false
    public var arrayValues: Array<ParseArgValue> = Array<ParseArgValue>()

    public init() {}

    public static func fromBool(value: Bool): ParseArgValue {
        let v = ParseArgValue()
        v.isBool = true
        v.boolValue = value
        return v
    }

    public static func fromString(value: String): ParseArgValue {
        let v = ParseArgValue()
        v.isBool = false
        v.stringValue = value
        return v
    }

    public static func fromArray(values: Array<ParseArgValue>): ParseArgValue {
        let v = ParseArgValue()
        v.isArray = true
        v.arrayValues = values
        return v
    }
}

// ============================================================================
// 解析 Token
// 对应 Bun: parse_args.zig - Token / OptionToken
// ============================================================================
public class ParseToken {
    public var kind: String = ""         // "positional", "option", "option-terminator"
    public var index: Int64 = 0
    public var name: String = ""
    public var rawName: String = ""
    public var value: String = ""
    public var inlineValue: Bool = false
    public var negative: Bool = false

    public init() {}
}

// ============================================================================
// 参数解析器
// 对应 Bun: parse_args.zig - parseArgs 函数
// 基于 Node.js util.parseArgs API
//
// 处理流程:
// Phase 0: 解析配置对象（args, strict, allowPositionals, tokens, allowNegative, options）
// Phase 1: tokenize args（将参数数组分类为 token）
// Phase 2: 处理 token（存储选项值和位置参数）
// Phase 3: 填充默认值
// Phase 4: 构建结果对象 {values, positionals, tokens?}
// ============================================================================
public class ParseArgs {
    // ========================================================================
    // parse — 主解析入口
    // 对应 Bun: parse_args.zig parseArgs()
    // ============================================================================
    public static func parse(args: Array<String>, options: Array<OptionDefinition>, strict: Bool = true,
                             allowPositionals: Bool = false, returnTokens: Bool = false,
                             allowNegative: Bool = false): ParseArgsResult {
        let result = ParseArgsResult()

        // 如果未指定 allowPositionals，在非 strict 模式下默认允许
        var allowPos = allowPositionals
        if (!allowPos && !strict) {
            allowPos = true
        }

        // Phase 1+2: tokenize args 并处理 token
        var i: Int64 = 0
        var optionTerminatorSeen: Bool = false

        while (i < args.size) {
            let arg = args[Int64(i)]
            let tokenType = classifyToken(arg, options: options)

            // "--" 选项终止符
            if (tokenType == TokenSubtype.optionTerminator && !optionTerminatorSeen) {
                optionTerminatorSeen = true
                if (returnTokens) {
                    let token = ParseToken()
                    token.kind = "option-terminator"
                    token.index = i
                    result.tokens.add(token)
                }
                i += 1
                // 之后的所有参数都是位置参数
                while (i < args.size) {
                    result.positionals.add(args[Int64(i)])
                    if (returnTokens) {
                        let posToken = ParseToken()
                        posToken.kind = "positional"
                        posToken.index = i
                        posToken.value = args[Int64(i)]
                        result.tokens.add(posToken)
                    }
                    i += 1
                }
                break
            }

            // 位置参数
            if (optionTerminatorSeen || tokenType == TokenSubtype.positional) {
                if (!allowPos && strict) {
                    throw NodeError(code: "ERR_PARSE_ARGS_UNEXPECTED_POSITIONAL",
                        message: "Unexpected argument '${arg}'. This command does not take positional arguments")
                }
                result.positionals.add(arg)
                if (returnTokens) {
                    let posToken = ParseToken()
                    posToken.kind = "positional"
                    posToken.index = i
                    posToken.value = arg
                    result.tokens.add(posToken)
                }
                i += 1
                continue
            }

            // 处理长选项 "--option"
            if (tokenType == TokenSubtype.longOptionAndValue ||
                tokenType == TokenSubtype.loneLongOption) {
                i = handleLongOption(result: result, arg: arg, index: i, args: args,
                    options: options, strict: strict, allowNegative: allowNegative,
                    returnTokens: returnTokens)
                continue
            }

            // 处理短选项 "-o"
            if (tokenType == TokenSubtype.loneShortOption ||
                tokenType == TokenSubtype.shortOptionGroup ||
                tokenType == TokenSubtype.shortOptionAndValue) {
                i = handleShortOption(result: result, arg: arg, index: i, args: args,
                    options: options, strict: strict, returnTokens: returnTokens,
                    tokenType: tokenType)
                continue
            }

            i += 1
        }

        // Phase 3: 填充默认值
        for (optDef in options) {
            if (!result.values.contains(optDef.longName) && optDef.defaultValue != None) {
                if (optDef.longName != "__proto__") {
                    result.values.put(optDef.longName, optDef.defaultValue!)
                }
            }
        }

        return result
    }

    // ========================================================================
    // classifyToken — 对参数进行分类
    // 对应 Bun: parse_args_utils.zig classifyToken
    // ========================================================================
    private static func classifyToken(arg: String, options: Array<OptionDefinition>): TokenSubtype {
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
                let eqIdx = arg.indexOf('=')
                if (eqIdx != None && eqIdx! >= 3) {
                    return TokenSubtype.longOptionAndValue
                }
                return TokenSubtype.loneLongOption
            } else if (arg.startsWith("-")) {
                let firstChar = arg.substring(1, 2)
                let optIdx = findOptionByShortName(firstChar, options: options)
                if (optIdx >= 0) {
                    if (options[optIdx].type == OptionValueType.string) {
                        return TokenSubtype.shortOptionAndValue
                    }
                    return TokenSubtype.shortOptionGroup
                }
                return TokenSubtype.shortOptionGroup
            }
        }

        return TokenSubtype.positional
    }

    // ========================================================================
    // handleLongOption — 处理长选项
    // 对应 Bun: parse_args.zig tokenizeArgs 中的 lone_long_option / long_option_and_value
    // 支持:
    //   --foo=bar   (longOptionAndValue)
    //   --foo       (loneLongOption，可能消费下一个参数作为值)
    //   --no-foo    (allowNegative 模式下的否定布尔选项)
    // ========================================================================
    private static func handleLongOption(result: ParseArgsResult, arg: String, index: Int64,
        args: Array<String>, options: Array<OptionDefinition>, strict: Bool,
        allowNegative: Bool, returnTokens: Bool): Int64 {
        var i = index

        // 检查是否带 = 号
        let eqIdx = arg.indexOf('=')
        var name: String
        var value: String = ""
        var inlineValue: Bool = false
        var negative: Bool = false

        if (eqIdx != None) {
            // --foo=bar
            name = arg.substring(2, eqIdx!)
            value = arg.substring(eqIdx! + 1, arg.size)
            inlineValue = true
        } else {
            // --foo 或 --no-foo
            name = arg.substring(2)

            // 处理否定前缀 --no-
            if (allowNegative && name.startsWith("no-")) {
                name = name.substring(3)
                negative = true
            }

            // 查找选项定义
            let optIdx = findOptionByLongName(name, options: options)
            let optType = if (optIdx >= 0) { options[optIdx].type } else { OptionValueType.boolean }

            // 字符串选项需要消费下一个参数
            if (optType == OptionValueType.string && i + 1 < args.size && !negative) {
                i += 1
                value = args[Int64(i)]
            }
        }

        // 存储选项值
        storeOption(result: result, name: name, value: value, options: options,
            strict: strict, negative: negative)

        // 添加 token
        if (returnTokens) {
            let token = ParseToken()
            token.kind = "option"
            token.index = index
            token.name = name
            token.rawName = if (negative) { "--no-" + name } else { arg.substring(0, if (eqIdx != None) { eqIdx! } else { arg.size }) }
            token.value = value
            token.inlineValue = inlineValue
            token.negative = negative
            result.tokens.add(token)
        }

        return i + 1
    }

    // ========================================================================
    // handleShortOption — 处理短选项
    // 对应 Bun: parse_args.zig tokenizeArgs 中的
    //   lone_short_option, short_option_group, short_option_and_value
    // 支持:
    //   -f FILE     (loneShortOption + 值)
    //   -fFILE      (shortOptionAndValue)
    //   -abc        (shortOptionGroup，展开为 -a -b -c)
    // ========================================================================
    private static func handleShortOption(result: ParseArgsResult, arg: String, index: Int64,
        args: Array<String>, options: Array<OptionDefinition>, strict: Bool,
        returnTokens: Bool, tokenType: TokenSubtype): Int64 {
        var i = index

        if (tokenType == TokenSubtype.shortOptionAndValue) {
            // -fFILE
            let shortName = arg.substring(1, 2)
            let value = arg.substring(2)
            let optIdx = findOptionByShortName(shortName, options: options)
            let longName = if (optIdx >= 0) { options[optIdx].longName } else { shortName }

            storeOption(result: result, name: longName, value: value, options: options,
                strict: strict, negative: false)

            if (returnTokens) {
                let token = ParseToken()
                token.kind = "option"
                token.index = index
                token.name = longName
                token.rawName = arg.substring(0, 2)
                token.value = value
                token.inlineValue = true
                result.tokens.add(token)
            }
            return i + 1
        }

        if (tokenType == TokenSubtype.loneShortOption) {
            // -f 或 -f FILE
            let shortName = arg.substring(1, 2)
            let optIdx = findOptionByShortName(shortName, options: options)
            let optType = if (optIdx >= 0) { options[optIdx].type } else { OptionValueType.boolean }
            let longName = if (optIdx >= 0) { options[optIdx].longName } else { shortName }

            var value: String = ""
            var hasValue = false
            if (optType == OptionValueType.string && i + 1 < args.size) {
                i += 1
                value = args[Int64(i)]
                hasValue = true
            }

            storeOption(result: result, name: longName, value: value, options: options,
                strict: strict, negative: false)

            if (returnTokens) {
                let token = ParseToken()
                token.kind = "option"
                token.index = index
                token.name = longName
                token.rawName = arg
                token.value = value
                token.inlineValue = !hasValue
                result.tokens.add(token)
            }
            return i + 1
        }

        // shortOptionGroup: -abc -> -a -b -c
        if (tokenType == TokenSubtype.shortOptionGroup) {
            var j: Int64 = 1
            while (j < arg.size) {
                let shortName = arg.substring(j, j + 1)
                let optIdx = findOptionByShortName(shortName, options: options)
                let optType = if (optIdx >= 0) { options[optIdx].type } else { OptionValueType.boolean }
                let longName = if (optIdx >= 0) { options[optIdx].longName } else { shortName }

                if (optType != OptionValueType.string || j == arg.size - 1) {
                    // 布尔选项，或短选项组的最后一个
                    var value: String = ""
                    var hasValue = false
                    if (optType == OptionValueType.string && i + 1 < args.size) {
                        i += 1
                        value = args[Int64(i)]
                        hasValue = true
                    }

                    storeOption(result: result, name: longName, value: value, options: options,
                        strict: strict, negative: false)

                    if (returnTokens) {
                        let token = ParseToken()
                        token.kind = "option"
                        token.index = index
                        token.name = longName
                        token.rawName = "-" + shortName
                        token.value = value
                        token.inlineValue = !hasValue
                        result.tokens.add(token)
                    }

                    if (hasValue) {
                        return i + 1
                    }
                } else {
                    // 字符串选项在中间，例如 -abfFILE -> -a -b -fFILE
                    let value = arg.substring(j + 1)
                    storeOption(result: result, name: longName, value: value, options: options,
                        strict: strict, negative: false)

                    if (returnTokens) {
                        let token = ParseToken()
                        token.kind = "option"
                        token.index = index
                        token.name = longName
                        token.rawName = "-" + shortName
                        token.value = value
                        token.inlineValue = true
                        result.tokens.add(token)
                    }
                    break // 短选项组结束
                }
                j += 1
            }
            return i + 1
        }

        return i + 1
    }

    // ========================================================================
    // storeOption — 存储选项值
    // 对应 Bun: parse_args.zig storeOption
    // 1. 跳过 __proto__
    // 2. 布尔选项: true/false（考虑 negative）
    // 3. 多值选项: 累积到数组
    // 4. 单值选项: 直接覆盖
    // ========================================================================
    private static func storeOption(result: ParseArgsResult, name: String, value: String,
        options: Array<OptionDefinition>, strict: Bool, negative: Bool): Unit {
        if (name == "__proto__") {
            return
        }

        let optIdx = findOptionByLongName(name, options: options)
        if (optIdx < 0) {
            if (strict) {
                throw NodeError(code: "ERR_PARSE_ARGS_UNKNOWN_OPTION",
                    message: "Unknown option '--${name}'")
            }
            return
        }

        let optDef = options[optIdx]
        if (optDef.type == OptionValueType.boolean) {
            let newValue = ParseArgValue.fromBool(!negative)

            if (optDef.multiple) {
                // 多值布尔: 累积到数组
                let existing = result.values.get(name)
                if (existing != None && existing!.isArray) {
                    existing!.arrayValues.add(newValue)
                    result.values.put(name, existing!)
                } else {
                    let arr = ParseArgValue.fromArray(Array<ParseArgValue>([newValue]))
                    result.values.put(name, arr)
                }
            } else {
                result.values.put(name, newValue)
            }
        } else {
            // 字符串选项
            if (strict && value.size == 0) {
                // 检查值是否看起来像选项（可能导致歧义）
                throw NodeError(code: "ERR_PARSE_ARGS_INVALID_OPTION_VALUE",
                    message: "Option '--${name}' argument missing")
            }
            let newValue = ParseArgValue.fromString(value)

            if (optDef.multiple) {
                let existing = result.values.get(name)
                if (existing != None && existing!.isArray) {
                    existing!.arrayValues.add(newValue)
                    result.values.put(name, existing!)
                } else {
                    let arr = ParseArgValue.fromArray(Array<ParseArgValue>([newValue]))
                    result.values.put(name, arr)
                }
            } else {
                result.values.put(name, newValue)
            }
        }
    }

    // ========================================================================
    // findOptionByLongName — 根据长名查找选项索引
    // 对应 Bun: parse_args.zig findOptionByLongName
    // ========================================================================
    public static func findOptionByLongName(longName: String, options: Array<OptionDefinition>): Int64 {
        for (i in 0..options.size) {
            if (options[i].longName == longName) {
                return Int64(i)
            }
        }
        return -1
    }

    // ========================================================================
    // findOptionByShortName — 根据短名查找选项索引
    // 对应 Bun: parse_args_utils.zig findOptionByShortName
    // 搜索 short_name 字段，也检查长度为 1 的 long_name
    // ========================================================================
    public static func findOptionByShortName(shortName: String, options: Array<OptionDefinition>): Int64 {
        var longOptionIndex: Int64 = -1
        for (i in 0..options.size) {
            if (options[i].shortName == shortName) {
                return Int64(i)
            }
            if (options[i].longName.size == 1 && options[i].longName == shortName) {
                longOptionIndex = Int64(i)
            }
        }
        return longOptionIndex
    }

    // ========================================================================
    // isOptionLikeValue — 检测值是否看起来像选项（可能导致歧义）
    // 对应 Bun: parse_args_utils.zig isOptionLikeValue
    // 例如: --port --verbose 当 port 是 string 类型
    // ========================================================================
    public static func isOptionLikeValue(value: String): Bool {
        return value.size > 1 && value.startsWith("-")
    }

    // ========================================================================
    // getDefaultArgs — 从 process.argv 获取默认参数
    // 对应 Bun: parse_args.zig getDefaultArgs
    // 从 process.argv 中提取用户参数（跳过可执行文件和脚本名）
    // 如果 execArgv 包含 -e/--eval/-p/--print，则只跳过第一个
    // ========================================================================
    public static func getDefaultArgs(): Array<String> {
        let argv = NodeProcess.getArgv()
        if (argv.size <= 2) {
            return Array<String>()
        }

        // 检查 execArgv 是否包含 eval 标志
        let execArgv = NodeProcess.getExecArgv()
        var hasEval = false
        for (arg in execArgv) {
            if (arg == "-e" || arg == "--eval" || arg == "-p" || arg == "--print") {
                hasEval = true
                break
            }
        }

        let start: Int64 = if (hasEval) { 1 } else { 2 }
        var result = Array<String>()
        for (i in start..argv.size) {
            result.add(argv[Int64(i)])
        }
        return result
    }
}

// ============================================================================
// Node 错误类
// ============================================================================
public class NodeError {
    public var code: String = ""
    public var message: String = ""

    public init() {}

    public init(code: String, message: String) {
        this.code = code
        this.message = message
    }

    public func toString(): String {
        return "[${code}]: ${message}"
    }
}
