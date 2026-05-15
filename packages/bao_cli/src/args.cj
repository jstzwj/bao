// 严格翻译自: src/cli/Arguments.zig
// 命令行参数解析器
package bao_cli

import bao_core.*
import bao_collections.*

// ============================================================================
// ParsedArgs — 解析后的命令行参数
// 严格翻译自: src/cli/Arguments.zig - Arguments struct
// 对应 Bun: CLI 参数解析结果
// ============================================================================

/// 已解析的参数
/// 对应 Bun: Arguments struct 中的所有字段
public class ParsedArgs {
    /// 命令
    public var command: String

    /// 位置参数
    /// 对应 Bun: Arguments.positionals
    public var positionals: ArrayList<String>

    /// 命名选项 (--key value)
    /// 对应 Bun: Arguments.options
    public var options: HashMap<String, String>

    /// 布尔标志 (--flag, --no-flag)
    /// 对应 Bun: Arguments.flags
    public var flags: HashMap<String, Bool>

    /// 未识别的参数
    public var unknown: ArrayList<String>

    public init() {
        command = ""
        positionals = ArrayList<String>()
        options = HashMap<String, String>()
        flags = HashMap<String, Bool>()
        unknown = ArrayList<String>()
    }

    /// 获取位置参数 (安全)
    public func positional(index: Int64): ?String {
        if (index < 0 || index >= positionals.size) {
            return None
        }
        return Some(positionals[index])
    }

    /// 获取选项值
    public func getOption(key: String): ?String {
        return options.get(key)
    }

    /// 获取选项值 (带默认值)
    public func getOption(key: String, defaultValue: String): String {
        match (options.get(key)) {
            case Some(v) => v
            case None => defaultValue
        }
    }

    /// 检查标志是否设置
    public func hasFlag(key: String): Bool {
        match (flags.get(key)) {
            case Some(v) => v
            case None => false
        }
    }

    /// 是否有给定选项
    public func hasOption(key: String): Bool {
        return options.contains(key)
    }

    public func toString(): String {
        var s = "ParsedArgs(command=${command}"
        if (positionals.size > 0) {
            s += ", positionals=${positionals}"
        }
        if (!options.isEmpty()) {
            s += ", options=${options}"
        }
        let trueFlags = ArrayList<String>()
        for ((k, v) in flags) {
            if (v) { trueFlags.append(k) }
        }
        if (trueFlags.size > 0) {
            s += ", flags=${trueFlags}"
        }
        s += ")"
        return s
    }
}

// ============================================================================
// ArgSpec — 参数规格
// 严格翻译自: src/cli/Arguments.zig 中各参数的定义
// ============================================================================

/// 参数规格类型
public enum ArgType {
    | Flag       // 布尔标志: --verbose
    | Option     // 带值选项: --outdir <dir>
    | Positional // 位置参数
}

/// 单个参数规格定义
public class ArgSpec {
    /// 长名称 (--help)
    public var longName: String

    /// 短名称 (-h)
    public var shortName: String

    /// 参数类型
    public var argType: ArgType

    /// 描述 (用于帮助文本)
    public var description: String

    /// 默认值 (选项类型)
    public var defaultValue: ?String

    /// 是否必须
    public var required: Bool

    /// 是否允许多值 (如 --external pkg1 --external pkg2)
    // 严格翻译自: clap 中 Values.many
    public var allowsMultiple: Bool

    /// 长名称别名
    // 严格翻译自: clap Names.long_aliases
    public var longAliases: ArrayList<String>

    /// 值名称 (用于帮助文本, 如 <file>, <dir>)
    public var valueName: String

    /// 是否为隐藏选项 (不出现在帮助文本中)
    public var hidden: Bool

    public init(longName: String, shortName: String, argType: ArgType, description: String) {
        this.longName = longName
        this.shortName = shortName
        this.argType = argType
        this.description = description
        this.defaultValue = None
        this.required = false
        this.allowsMultiple = false
        this.longAliases = ArrayList<String>()
        this.valueName = ""
        this.hidden = false
    }
}

// ============================================================================
// ArgParser — 命令行参数解析器
// 严格翻译自: src/cli/Arguments.zig - parse()
// 对应 Bun: CLI 参数解析
//
// Bun 使用 src/clap/ 中的通用参数解析器，
// 此处实现一个简化但功能完备的参数解析器。
//
// 解析规则:
//   - 以 -- 开头的是长选项
//   - 以 - 开头的是短选项
//   - --flag 设置布尔标志为 true
//   - --no-flag 设置布尔标志为 false
//   - --key value 设置命名选项
//   - 其他都是位置参数
//   - -- 结束选项解析，后续都为位置参数
// ============================================================================

/// 命令行参数解析器
/// 对应 Bun: src/clap/ 解析器
///
/// 示例:
///   let parser = ArgParser()
///   parser.addFlag("verbose", "v", "Verbose output")
///   parser.addOption("outdir", "o", "Output directory")
///   let args = parser.parse(["run", "index.js", "--verbose", "--outdir", "dist"])
///   // args.command = "run"
///   // args.positionals = ["index.js"]
///   // args.flags["verbose"] = true
///   // args.options["outdir"] = "dist"
public class ArgParser {
    /// 已注册的参数规格
    private var specs: ArrayList<ArgSpec>

    /// 命令名
    private var commandName: String

    /// 程序描述
    private var description: String

    /// 命令列表 (用于子命令)
    private var commands: ArrayList<(String, String)>

    public init() {
        specs = ArrayList<ArgSpec>()
        commandName = "bao"
        description = "JavaScript Runtime & Toolkit"
        commands = ArrayList<(String, String)>()
    }

    public init(commandName: String, description: String) {
        specs = ArrayList<ArgSpec>()
        this.commandName = commandName
        this.description = description
        this.commands = ArrayList<(String, String)>()
    }

    /// 注册布尔标志
    /// 对应 Bun: clap 中的 flag 定义
    public func addFlag(longName: String, shortName: String, description: String): ArgParser {
        specs.append(ArgSpec(longName, shortName, ArgType.Flag, description))
        return this
    }

    /// 注册命名选项
    /// 对应 Bun: clap 中的 option 定义
    public func addOption(longName: String, shortName: String, description: String): ArgParser {
        specs.append(ArgSpec(longName, shortName, ArgType.Option, description))
        return this
    }

    /// 注册带默认值的选项
    public func addOption(longName: String, shortName: String, description: String, defaultValue: String): ArgParser {
        let spec = ArgSpec(longName, shortName, ArgType.Option, description)
        spec.defaultValue = Some(defaultValue)
        specs.append(spec)
        return this
    }

    /// 注册可变参数选项 (如 --external 可多次使用)
    // 严格翻译自: clap 中 Values.many
    public func addVariadicOption(longName: String, shortName: String, description: String): ArgParser {
        let spec = ArgSpec(longName, shortName, ArgType.Option, description)
        spec.allowsMultiple = true
        specs.append(spec)
        return this
    }

    /// 注册必选选项
    public func addRequiredOption(longName: String, shortName: String, description: String): ArgParser {
        let spec = ArgSpec(longName, shortName, ArgType.Option, description)
        spec.required = true
        specs.append(spec)
        return this
    }

    /// 注册带别名的选项
    // 严格翻译自: clap Names.long_aliases (如 --test-name-pattern/--grep)
    public func addOptionWithAlias(longName: String, shortName: String, description: String, aliases: Array<String>): ArgParser {
        let spec = ArgSpec(longName, shortName, ArgType.Option, description)
        for (alias in aliases) {
            spec.longAliases.append(alias)
        }
        specs.append(spec)
        return this
    }

    /// 注册位置参数
    public func addPositional(name: String, description: String): ArgParser {
        specs.append(ArgSpec(name, "", ArgType.Positional, description))
        return this
    }

    /// 注册子命令
    public func addCommand(name: String, description: String): ArgParser {
        commands.append((name, description))
        return this
    }

    /// 注册隐藏选项 (不出现在帮助文本中)
    public func addHiddenOption(longName: String, shortName: String, description: String): ArgParser {
        let spec = ArgSpec(longName, shortName, ArgType.Option, description)
        spec.hidden = true
        specs.append(spec)
        return this
    }

    /// 解析命令行参数
    /// 对应 Bun: Arguments.parse(allocator, comptime subcommand)
    public func parse(args: ArrayList<String>): ParsedArgs {
        let result = ParsedArgs()
        if (args.size == 0) {
            return result
        }

        // 第一个非选项参数为命令
        var i = 0
        var optionsEnded = false

        // 检查第一个参数是否为命令
        let first = args[0]
        if (!first.startsWith("-")) {
            result.command = first
            i = 1
        }

        while (i < args.size) {
            let arg = args[i]

            // -- 结束选项解析
            if (arg == "--" && !optionsEnded) {
                optionsEnded = true
                i += 1
                continue
            }

            // 选项结束后，所有参数都是位置参数
            if (optionsEnded) {
                result.positionals.append(arg)
                i += 1
                continue
            }

            // 长选项
            if (arg.startsWith("--")) {
                i = parseLongOption(arg, args, i, result)
                continue
            }

            // 短选项
            if (arg.startsWith("-") && arg.length > 1) {
                i = parseShortOption(arg, args, i, result)
                continue
            }

            // 位置参数
            result.positionals.append(arg)
            i += 1
        }

        return result
    }

    /// 从原始字符串数组解析
    public func parse(rawArgs: Array<String>): ParsedArgs {
        let args = ArrayList<String>()
        for (arg in rawArgs) {
            args.append(arg)
        }
        return parse(args)
    }

    /// 解析长选项 (--key 或 --key=value)
    /// 对应 Bun: clap 长选项解析
    private func parseLongOption(arg: String, args: ArrayList<String>, i: Int64, result: ParsedArgs): Int64 {
        var key = arg.substring(2)  // 去除 "--"

        // 处理 --key=value 格式
        let eqIdx = key.indexOf('=')
        if (eqIdx >= 0) {
            let value = key.substring(eqIdx + 1)
            key = key.substring(0, eqIdx)
            result.options.put(key, value)
            return i + 1
        }

        // 处理 --no-flag
        if (key.startsWith("no-")) {
            let flagName = key.substring(3)
            result.flags.put(flagName, false)
            return i + 1
        }

        // 查找参数规格
        let spec = findSpecByLongName(key)
        match (spec) {
            case Some(s) => {
                match (s.argType) {
                    case ArgType.Flag =>
                        result.flags.put(key, true)
                        return i + 1
                    case ArgType.Option => {
                        // 消耗下一个参数作为值
                        if (i + 1 < args.size) {
                            result.options.put(key, args[i + 1])
                            return i + 2
                        } else {
                            println("warning: --${key} requires a value")
                            result.options.put(key, "")
                            return i + 1
                        }
                    }
                    case ArgType.Positional =>
                        result.positionals.append(arg)
                        return i + 1
                }
            }
            case None => {
                // 未知参数 — 尝试猜测是 flag 还是 option
                if (i + 1 < args.size && !args[i + 1].startsWith("-")) {
                    result.options.put(key, args[i + 1])
                    return i + 2
                } else {
                    result.flags.put(key, true)
                    return i + 1
                }
            }
        }
    }

    /// 解析短选项 (-k 或 -kvalue)
    /// 对应 Bun: clap 短选项解析
    /// 支持: -v, -abc (合并短选项), -ovalue
    private func parseShortOption(arg: String, args: ArrayList<String>, i: Int64, result: ParsedArgs): Int64 {
        let key = arg.substring(1)  // 去除 "-"

        // 处理合并短选项: -abc => -a -b -c
        if (key.length > 1) {
            // 检查第一个字符是否为已知的 option
            let firstChar = key.substring(0, 1)
            let spec = findSpecByShortName(firstChar)
            match (spec) {
                case Some(s) => {
                    match (s.argType) {
                        case ArgType.Option => {
                            // -ovalue 格式
                            let value = key.substring(1)
                            result.options.put(s.longName, value)
                            return i + 1
                        }
                        case ArgType.Flag | ArgType.Positional => {
                            // -abc 拆分为 -a -b -c
                            for (c in key) {
                                let charName = c.toString()
                                let cSpec = findSpecByShortName(charName)
                                match (cSpec) {
                                    case Some(cs) => {
                                        match (cs.argType) {
                                            case ArgType.Flag => result.flags.put(cs.longName, true)
                                            case _ => result.unknown.append("-${charName}")
                                        }
                                    }
                                    case None => result.unknown.append("-${charName}")
                                }
                            }
                            return i + 1
                        }
                    }
                }
                case None => {
                    result.unknown.append(arg)
                    return i + 1
                }
            }
        }

        // 单个短选项
        let spec = findSpecByShortName(key)
        match (spec) {
            case Some(s) => {
                match (s.argType) {
                    case ArgType.Flag =>
                        result.flags.put(s.longName, true)
                        return i + 1
                    case ArgType.Option => {
                        if (i + 1 < args.size) {
                            result.options.put(s.longName, args[i + 1])
                            return i + 2
                        } else {
                            println("warning: -${key} requires a value")
                            result.options.put(s.longName, "")
                            return i + 1
                        }
                    }
                    case ArgType.Positional =>
                        result.positionals.append(arg)
                        return i + 1
                }
            }
            case None => {
                result.unknown.append(arg)
                return i + 1
            }
        }
    }

    /// 按长名称查找规格
    private func findSpecByLongName(name: String): ?ArgSpec {
        for (spec in specs) {
            if (spec.longName == name) {
                return Some(spec)
            }
        }
        return None
    }

    /// 按短名称查找规格
    private func findSpecByShortName(name: String): ?ArgSpec {
        for (spec in specs) {
            if (spec.shortName == name) {
                return Some(spec)
            }
        }
        return None
    }

    // ============================================================================
    // 帮助生成
    // 对应 Bun: --help 输出
    // ============================================================================

    /// 生成帮助文本
    public func generateHelp(): String {
        var help = ""
        help += "${commandName} - ${description}\n\n"
        help += "Usage: ${commandName} <command> [options]\n\n"

        if (commands.size > 0) {
            help += "Commands:\n"
            for ((name, desc) in commands) {
                help += "  ${name.padEnd(20)}${desc}\n"
            }
            help += "\n"
        }

        if (specs.size > 0) {
            help += "Options:\n"
            for (spec in specs) {
                // 跳过隐藏选项
                if (spec.hidden) {
                    continue
                }

                // 构建选项名称字符串
                var names = ""
                if (spec.shortName.length > 0) {
                    names += "-${spec.shortName}, "
                }
                names += "--${spec.longName}"

                // 添加值占位符
                if (spec.argType == ArgType.Option) {
                    let valuePlaceholder = if (spec.valueName.length > 0) {
                        spec.valueName
                    } else {
                        "<value>"
                    }
                    names += " ${valuePlaceholder}"
                    if (spec.allowsMultiple) {
                        names += " ..."
                    }
                }

                help += "  ${names.padEnd(32)}${spec.description}"

                // 添加默认值
                match (spec.defaultValue) {
                    case Some(v) => help += " (default: ${v})"
                    case None => ()
                }

                // 添加必需标记
                if (spec.required) {
                    help += " [required]"
                }

                help += "\n"
            }
        }

        return help
    }

    /// 打印帮助
    public func printHelp(): Unit {
        println(generateHelp())
    }
}

// ============================================================================
// String 辅助方法
// ============================================================================

/// 字符串填充到指定长度
private func String.padEnd(width: Int64): String {
    if (this.length >= width) {
        return this
    }
    var result = this
    var i = this.length
    while (i < width) {
        result += " "
        i += 1
    }
    return result
}
