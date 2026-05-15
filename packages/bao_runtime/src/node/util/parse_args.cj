// 命令行参数解析器
// 对应 Bun: src/runtime/node/util/parse_args.zig
// 严格翻译自: src/runtime/node/util/parse_args.zig
package bao_runtime

// ============================================================================
// 参数解析结果
// 对应 Bun: src/runtime/node/util/parse_args.zig
// ============================================================================
public class ParseArgsResult {
    public var values: Map<String, ParseArgValue> = HashMap<String, ParseArgValue>()
    public var positionals: Array<String> = Array<String>()

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
    public var arrayValues: Array<String> = Array<String>()

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
}

// ============================================================================
// 参数解析器
// 对应 Bun: src/runtime/node/util/parse_args.zig
// ============================================================================
public class ParseArgs {
    // 解析命令行参数
    // 对应 Bun: src/runtime/node/util/parse_args.zig 主入口
    public static func parse(args: Array<String>, options: Map<String, ParseArgOption>, strict: Bool = true): ParseArgsResult {
        let result = ParseArgsResult()
        var i: Int64 = 0
        var allowPositionals: Bool = true
        var optionTerminatorSeen: Bool = false

        while (i < args.size) {
            let arg = args[i]

            // "--" 终止选项
            if (arg == "--" && !optionTerminatorSeen) {
                optionTerminatorSeen = true
                i += 1
                continue
            }

            // 如果已到选项终止符之后，作为位置参数
            if (optionTerminatorSeen || !arg.startsWith("-")) {
                if (strict) {
                    result.positionals.add(arg)
                } else {
                    result.positionals.add(arg)
                }
                i += 1
                continue
            }

            // 处理长选项 "--option"
            if (arg.startsWith("--")) {
                let eqIdx = arg.indexOf('=')
                if (eqIdx != None) {
                    let idx = eqIdx!
                    let name = arg.substring(2, idx)
                    let value = arg.substring(idx + 1, arg.size)
                    setOption(result: result, name: name, value: value, options: options, strict: strict)
                } else {
                    let name = arg.substring(2)
                    let optDef = options.get(name)
                    if (optDef != None && optDef!.type == ParseArgType.string && i + 1 < args.size) {
                        i += 1
                        setOption(result: result, name: name, value: args[i], options: options, strict: strict)
                    } else {
                        setOption(result: result, name: name, value: "", options: options, strict: strict)
                    }
                }
                i += 1
                continue
            }

            // 处理短选项 "-o"
            if (arg.startsWith("-") && arg.size > 1) {
                let shortName = arg.substring(1, 2)
                let optDef = findOptionByShortName(shortName, options: options)
                if (optDef != None) {
                    let name = optDef!.longName
                    if (optDef!.type == ParseArgType.string) {
                        var value = ""
                        if (arg.size > 2) {
                            value = arg.substring(2)
                        } else if (i + 1 < args.size) {
                            i += 1
                            value = args[i]
                        }
                        setOption(result: result, name: name, value: value, options: options, strict: strict)
                    } else {
                        setOption(result: result, name: name, value: "", options: options, strict: strict)
                    }
                } else if (strict) {
                    throw NodeError(code: "ERR_PARSE_ARGS_UNKNOWN_OPTION", message: "Unknown option: ${arg}")
                }
                i += 1
                continue
            }

            // 位置参数
            result.positionals.add(arg)
            i += 1
        }

        // 设置默认值
        for ((name, optDef) in options) {
            if (!result.values.contains(name) && optDef.defaultValue != None) {
                result.values.put(name, optDef.defaultValue!)
            }
        }

        return result
    }

    // 设置选项值
    private static func setOption(result: ParseArgsResult, name: String, value: String, options: Map<String, ParseArgOption>, strict: Bool): Unit {
        let optDef = options.get(name)
        if (optDef == None) {
            if (strict) {
                throw NodeError(code: "ERR_PARSE_ARGS_UNKNOWN_OPTION", message: "Unknown option: --${name}")
            }
            return
        }

        if (optDef.type == ParseArgType.boolean) {
            result.values.put(name, ParseArgValue.fromBool(true))
        } else {
            if (value.size == 0) {
                if (strict) {
                    throw NodeError(code: "ERR_PARSE_ARGS_INVALID_OPTION_VALUE", message: "Option '--${name}' requires a value")
                }
            }
            result.values.put(name, ParseArgValue.fromString(value))
        }
    }

    // 根据短名称查找选项
    private static func findOptionByShortName(shortName: String, options: Map<String, ParseArgOption>): ?ParseArgOption {
        for ((_, optDef) in options) {
            if (optDef.shortName == shortName) {
                return optDef
            }
        }
        return None
    }
}
