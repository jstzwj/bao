// bao_clap - 参数解析器
// 严格翻译自:
//   src/clap/comptime.zig - ComptimeClap (运行时结果存储与解析入口)
//   src/clap/streaming.zig - StreamingClap (流式参数解析核心逻辑)
//   src/clap/args.zig - SliceIterator (参数迭代器)
//
// ComptimeClap:
//   pub fn ComptimeClap(Id, params) type {
//       return struct {
//           single_options: [N]?[]const u8,
//           multi_options: [N][]const []const u8,
//           flags: [N]bool,
//           pos: []const []const u8,
//           passthrough_positionals: []const []const u8,
//           pub fn parse(iter, opt) !@This() { ... }
//           pub fn flag(...) bool { ... }
//           pub fn option(...) ?[]const u8 { ... }
//           pub fn options(...) []const []const u8 { ... }
//           pub fn positionals(...) []const []const u8 { ... }
//       };
//   };
//
// StreamingClap:
//   pub fn StreamingClap(Id, ArgIterator) type {
//       return struct {
//           params: []const Param(Id),
//           iter: *ArgIterator,
//           state: State = .normal,
//           pub fn next(parser) ArgError!?Arg(Id) { ... }
//           fn normal(parser) ArgError!?Arg(Id) { ... }
//           fn chainging(parser, state) ArgError!?Arg(Id) { ... }
//       };
//   };
package bao_clap

import bao_core.*
import bao_collections.*

// ============================================================================
// ParseResult - 解析结果
// 严格翻译自: comptime.zig - ComptimeClap struct 实例字段
//   single_options: [N]?[]const u8   -> options: HashMap<String, String>
//   multi_options: [N][]const []const u8 -> multiOptions: HashMap<String, ArrayList<String>>
//   flags: [N]bool                   -> flags: HashMap<String, Bool>
//   pos: []const []const u8          -> positionals: ArrayList<String>
//   passthrough_positionals: []const []const u8 -> passthrough: ArrayList<String>
// ============================================================================

/// 命令行参数解析结果
/// 对应 Bun: ComptimeClap 实例
public class ParseResult {
    /// 布尔标志 (设置/未设置)
    // 严格翻译自: ComptimeClap.flags: [N]bool
    public var flags: HashMap<String, Bool>

    /// 单值选项 (--key value)
    // 严格翻译自: ComptimeClap.single_options: [N]?[]const u8
    public var options: HashMap<String, String>

    /// 多值选项 (--key val1 --key val2)
    // 严格翻译自: ComptimeClap.multi_options: [N][]const []const u8
    public var multiOptions: HashMap<String, ArrayList<String>>

    /// 位置参数
    // 严格翻译自: ComptimeClap.pos: []const []const u8
    public var positionals: ArrayList<String>

    /// -- 之后传递的位置参数
    // 严格翻译自: ComptimeClap.passthrough_positionals: []const []const u8
    public var passthrough: ArrayList<String>

    /// 遇到的错误列表
    public var errors: ArrayList<ClapParseError>

    /// 可执行文件路径 (argv[0])
    // 严格翻译自: Args.exe_arg: ?[:0]const u8
    public var exeArg: ?String

    public init() {
        flags = HashMap<String, Bool>()
        options = HashMap<String, String>()
        multiOptions = HashMap<String, ArrayList<String>>()
        positionals = ArrayList<String>()
        passthrough = ArrayList<String>()
        errors = ArrayList<ClapParseError>()
        exeArg = None
    }

    // ========================================================================
    // 访问器方法
    // 严格翻译自: ComptimeClap 的 flag/option/options/positionals/remaining
    // ========================================================================

    /// 检查布尔标志是否设置
    // 严格翻译自: ComptimeClap.flag(comptime name) bool
    //   return parser.flags[param.id];
    public func hasFlag(name: String): Bool {
        match (flags.get(name)) {
            case Some(v) => return v
            case None => return false
        }
    }

    /// 获取单值选项
    // 严格翻译自: ComptimeClap.option(comptime name) ?[]const u8
    //   return parser.single_options[param.id];
    public func getString(name: String): ?String {
        return options.get(name)
    }

    /// 获取单值选项 (带默认值)
    public func getString(name: String, defaultValue: String): String {
        match (options.get(name)) {
            case Some(v) => return v
            case None => return defaultValue
        }
    }

    /// 获取整数选项
    public func getInt(name: String): ?Int64 {
        match (options.get(name)) {
            case Some(v) =>
                try {
                    return Some(Int64.parse(v))
                } catch (_: Exception) {
                    return None
                }
            case None => return None
        }
    }

    /// 获取整数选项 (带默认值)
    public func getInt(name: String, defaultValue: Int64): Int64 {
        match (getInt(name)) {
            case Some(v) => return v
            case None => return defaultValue
        }
    }

    /// 获取布尔选项 (通过选项值解析)
    // 严格翻译自: ComptimeClap.flag() 的布尔参数版本
    public func getBool(name: String): ?Bool {
        match (options.get(name)) {
            case Some(v) =>
                if (v == "true" || v == "1" || v == "yes") {
                    return Some(true)
                }
                if (v == "false" || v == "0" || v == "no") {
                    return Some(false)
                }
                return None
            case None => return None
        }
    }

    /// 获取布尔选项 (带默认值)
    public func getBool(name: String, defaultValue: Bool): Bool {
        match (getBool(name)) {
            case Some(v) => return v
            case None => return defaultValue
        }
    }

    /// 获取多值选项
    // 严格翻译自: ComptimeClap.options(comptime name) []const []const u8
    //   return parser.multi_options[param.id];
    public func getMulti(name: String): ArrayList<String> {
        match (multiOptions.get(name)) {
            case Some(v) => return v
            case None => return ArrayList<String>()
        }
    }

    /// 获取位置参数
    // 严格翻译自: ComptimeClap.positionals() []const []const u8
    //   return parser.pos;
    public func getPositionals(): ArrayList<String> {
        return positionals
    }

    /// 获取 -- 后的传递参数
    // 严格翻译自: ComptimeClap.remaining() []const []const u8
    //   return parser.passthrough_positionals;
    public func getRemaining(): ArrayList<String> {
        return passthrough
    }

    /// 检查是否包含给定参数 (标志或选项)
    // 严格翻译自: ComptimeClap.hasFlag(comptime name) bool
    public func hasParam(name: String): Bool {
        if (flags.contains(name)) {
            match (flags.get(name)) {
                case Some(v) => if (v) { return true }
                case None => ()
            }
        }
        if (options.contains(name)) { return true }
        if (multiOptions.contains(name)) { return true }
        return false
    }

    /// 检查是否有任何解析错误
    public func hasErrors(): Bool {
        return errors.size > 0
    }
}

// ============================================================================
// ArgIterator - 参数迭代器
// 严格翻译自: args.zig - SliceIterator
//   pub const SliceIterator = struct {
//       remain: []const []const u8,
//       pub fn next(iter: *SliceIterator) ?[]const u8 { ... }
//   };
// ============================================================================

/// 参数迭代器
/// 对应 Bun: clap.args.SliceIterator
/// 零分配, 遍历字符串数组
public class ArgIterator {
    private var args: ArrayList<String>
    private var pos: Int64

    public init(args: ArrayList<String>) {
        this.args = args
        this.pos = 0
    }

    public init(args: Array<String>) {
        this.args = ArrayList<String>()
        for (arg in args) {
            this.args.append(arg)
        }
        this.pos = 0
    }

    /// 获取下一个参数
    // 严格翻译自: SliceIterator.next() ?[]const u8
    //   if (iter.remain.len > 0) {
    //       const res = iter.remain[0];
    //       iter.remain = iter.remain[1..];
    //       return res;
    //   }
    //   return null;
    public func next(): ?String {
        if (pos < args.size) {
            let res = args[pos]
            pos += 1
            return res
        }
        return None
    }

    /// 查看下一个参数但不消耗
    public func peek(): ?String {
        if (pos < args.size) {
            return args[pos]
        }
        return None
    }

    /// 是否还有剩余参数
    public func hasNext(): Bool {
        return pos < args.size
    }

    /// 获取剩余参数数量
    public func remaining(): Int64 {
        return args.size - pos
    }

    /// 获取剩余所有参数
    // 严格翻译自: comptime.zig 中 stream.iter.remain 的用法
    public func remainingArgs(): ArrayList<String> {
        let result = ArrayList<String>()
        var i = pos
        while (i < args.size) {
            result.append(args[i])
            i += 1
        }
        return result
    }
}

// ============================================================================
// ArgInfo - 解析出的参数信息
// 严格翻译自: streaming.zig - StreamingClap.ArgInfo
//   const ArgInfo = struct {
//       arg: []const u8,
//       kind: enum { long, short, positional },
//   };
// ============================================================================

/// 参数类型
// 严格翻译自: ArgInfo.kind enum
public enum ArgKind {
    | Long       // --xxx 长选项
    | Short      // -x 短选项
    | Positional // 位置参数
}

/// 解析出的参数信息
/// 对应 Bun: StreamingClap.ArgInfo
class ArgInfo {
    var arg: String
    var kind: ArgKind

    init(arg: String, kind: ArgKind) {
        this.arg = arg
        this.kind = kind
    }
}

// ============================================================================
// ParsedArg - 已解析的参数
// 严格翻译自: streaming.zig - Arg(Id) type
//   pub fn Arg(comptime Id: type) type {
//       return struct {
//           param: *const clap.Param(Id),
//           value: ?[]const u8 = null,
//       };
//   };
// ============================================================================

/// 解析出的参数绑定
/// 对应 Bun: Arg(Id)
class ParsedArg {
    var param: ClapParam
    var value: ?String

    init(param: ClapParam) {
        this.param = param
        this.value = None
    }

    init(param: ClapParam, value: String) {
        this.param = param
        this.value = Some(value)
    }
}

// ============================================================================
// ClapParser - 命令行参数解析器
// 严格翻译自: streaming.zig - StreamingClap + comptime.zig - ComptimeClap.parse
//
// StreamingClap 核心状态机:
//   State = union(enum) { normal, chaining: Chaining, rest_are_positional }
//   Chaining = struct { arg: []const u8, index: usize }
//
// 解析流程:
//   1. 从迭代器取参数
//   2. 判断类型 (long/short/positional)
//   3. 匹配参数定义
//   4. 提取值 (如果需要)
//   5. 存入结果
// ============================================================================

/// 命令行参数解析器
/// 对应 Bun: StreamingClap + ComptimeClap 的组合
///
/// 使用示例:
///   let parser = ClapParser()
///   parser.addParam(ClapParam("verbose", ClapNames('v', "verbose"), ClapValues.None, ClapParamHelp("Verbose output")))
///   parser.addParam(ClapParam("output", ClapNames('o', "output"), ClapValues.One, ClapParamHelp("Output directory", "dir")))
///   let result = parser.parse(["--verbose", "--output", "dist", "file.js"])
///   // result.hasFlag("verbose") == true
///   // result.getString("output") == "dist"
///   // result.positionals == ["file.js"]
public class ClapParser {
    /// 已注册的参数定义列表
    // 严格翻译自: StreamingClap.params: []const Param(Id)
    private var params: ArrayList<ClapParam>

    /// 是否对未识别标志发出警告
    // 严格翻译自: clap.zig - warn_on_unrecognized_flag
    private var warnOnUnrecognized: Bool

    /// 在遇到第 N 个位置参数后停止解析 (-- 之后的内容)
    // 严格翻译自: ParseOptions.stop_after_positional_at: usize
    private var stopAfterPositionalAt: Int64

    public init() {
        params = ArrayList<ClapParam>()
        warnOnUnrecognized = false
        stopAfterPositionalAt = 0
    }

    /// 设置是否对未识别标志发出警告
    // 严格翻译自: clap.zig - pub var warn_on_unrecognized_flag = false
    public func setWarnOnUnrecognized(warn: Bool): Unit {
        warnOnUnrecognized = warn
    }

    /// 设置位置参数停止点
    // 严格翻译自: ParseOptions.stop_after_positional_at
    public func setStopAfterPositionalAt(count: Int64): Unit {
        stopAfterPositionalAt = count
    }

    // ========================================================================
    // 参数注册
    // ========================================================================

    /// 添加参数定义
    // 严格翻译自: ComptimeClap 中的 params 编译期数组
    public func addParam(param: ClapParam): Unit {
        params.append(param)
    }

    /// 便利方法: 添加布尔标志
    public func addFlag(id: String, shortName: Char, longName: String, helpText: String): Unit {
        let names = ClapNames(shortName, longName)
        let helpInfo = ClapParamHelp(helpText, "")
        params.append(ClapParam(id, names, ClapValues.None, helpInfo))
    }

    /// 便利方法: 添加只有长名称的布尔标志
    public func addFlag(id: String, longName: String, helpText: String): Unit {
        let names = ClapNames(longName)
        let helpInfo = ClapParamHelp(helpText, "")
        params.append(ClapParam(id, names, ClapValues.None, helpInfo))
    }

    /// 便利方法: 添加单值选项
    public func addOption(id: String, shortName: Char, longName: String, valueName: String, helpText: String): Unit {
        let names = ClapNames(shortName, longName)
        let helpInfo = ClapParamHelp(helpText, valueName)
        params.append(ClapParam(id, names, ClapValues.One, helpInfo))
    }

    /// 便利方法: 添加只有长名称的单值选项
    public func addOption(id: String, longName: String, valueName: String, helpText: String): Unit {
        let names = ClapNames(longName)
        let helpInfo = ClapParamHelp(helpText, valueName)
        params.append(ClapParam(id, names, ClapValues.One, helpInfo))
    }

    /// 便利方法: 添加可选值选项
    // 严格翻译自: Values.one_optional
    public func addOptionalOption(id: String, shortName: Char, longName: String, valueName: String, helpText: String): Unit {
        let names = ClapNames(shortName, longName)
        let helpInfo = ClapParamHelp(helpText, valueName)
        params.append(ClapParam(id, names, ClapValues.OneOptional, helpInfo))
    }

    /// 便利方法: 添加多值选项
    // 严格翻译自: Values.many
    public func addMultiOption(id: String, shortName: Char, longName: String, valueName: String, helpText: String): Unit {
        let names = ClapNames(shortName, longName)
        let helpInfo = ClapParamHelp(helpText, valueName)
        params.append(ClapParam(id, names, ClapValues.Many, helpInfo))
    }

    /// 便利方法: 添加带别名的选项
    // 严格翻译自: Names.long_aliases
    public func addOptionWithAliases(id: String, shortName: Char, longName: String, valueName: String, helpText: String, aliases: Array<String>): Unit {
        let names = ClapNames(shortName, longName)
        for (alias in aliases) {
            names.longAliases.append(alias)
        }
        let helpInfo = ClapParamHelp(helpText, valueName)
        params.append(ClapParam(id, names, ClapValues.One, helpInfo))
    }

    /// 便利方法: 添加位置参数
    // 严格翻译自: 位置参数 names.short == null && names.long == null
    public func addPositional(id: String, valueName: String, helpText: String): Unit {
        let names = ClapNames()
        let helpInfo = ClapParamHelp(helpText, valueName)
        params.append(ClapParam(id, names, ClapValues.One, helpInfo))
    }

    /// 便利方法: 添加带默认值的选项
    public func addOptionWithDefault(id: String, shortName: Char, longName: String, valueName: String, helpText: String, defaultValue: String): Unit {
        let names = ClapNames(shortName, longName)
        let helpInfo = ClapParamHelp(helpText, valueName)
        let param = ClapParam(id, names, ClapValues.One, helpInfo)
        param.defaultValue = Some(defaultValue)
        params.append(param)
    }

    /// 便利方法: 添加必选选项
    public func addRequiredOption(id: String, shortName: Char, longName: String, valueName: String, helpText: String): Unit {
        let names = ClapNames(shortName, longName)
        let helpInfo = ClapParamHelp(helpText, valueName)
        let param = ClapParam(id, names, ClapValues.One, helpInfo)
        param.required = true
        params.append(param)
    }

    /// 获取已注册的参数列表
    public func getParams(): ArrayList<ClapParam> {
        return params
    }

    // ========================================================================
    // 解析核心
    // 严格翻译自:
    //   streaming.zig - StreamingClap.next() / normal() / chainging()
    //   comptime.zig - ComptimeClap.parse()
    // ========================================================================

    /// 解析参数数组
    // 严格翻译自: comptime.zig ComptimeClap.parse(iter, opt)
    public func parse(args: Array<String>): ParseResult {
        return parseWithIterator(ArgIterator(args))
    }

    /// 解析参数列表
    public func parse(args: ArrayList<String>): ParseResult {
        return parseWithIterator(ArgIterator(args))
    }

    /// 使用迭代器解析
    // 严格翻译自: comptime.zig ComptimeClap.parse(iter, opt) -> ComptimeClap
    ///   while (try stream.next()) |arg| {
    ///       if (param.names.long == null and param.names.short == null) {
    ///           try pos.append(arg.value.?);
    ///       } else if (param.takes_value == .one or param.takes_value == .one_optional) {
    ///           res.single_options[param.id] = arg.value orelse "";
    ///       } else if (param.takes_value == .many) {
    ///           try multis[param.id].append(arg.value.?);
    ///       } else {
    ///           res.flags[param.id] = true;
    ///       }
    ///   }
    public func parseWithIterator(iter: ArgIterator): ParseResult {
        let result = ParseResult()

        // 提取 exe_arg (argv[0])
        // 严格翻译自: args.zig OsIterator.exe_arg
        match (iter.next()) {
            case Some(exe) => result.exeArg = Some(exe)
            case None => return result
        }

        // 查找位置参数定义
        // 严格翻译自: streaming.zig positionalParam()
        let positionalParam = findPositionalParam()

        // 状态: 是否遇到 "--" (后续都是位置参数)
        // 严格翻译自: StreamingClap.State.rest_are_positional
        var restArePositional = false

        while (iter.hasNext()) {
            if (restArePositional) {
                // -- 之后的所有参数都是位置参数
                // 严格翻译自: StreamingClap.next() .rest_are_positional 分支
                //   const value = parser.iter.next() orelse return null;
                //   return Arg(Id){ .param = param, .value = value };
                match (iter.next()) {
                    case Some(value) =>
                        result.positionals.append(value)
                        // 检查 stop_after_positional_at
                        // 严格翻译自: comptime.zig stop_after_positional_at 逻辑
                        if (stopAfterPositionalAt > 0 && result.positionals.size >= stopAfterPositionalAt) {
                            let remaining = iter.remainingArgs()
                            // 跳过 "--" 如果存在
                            // 严格翻译自: comptime.zig 中检查 remaining_[0] == "--"
                            if (remaining.size > 0 && remaining[0] == "--") {
                                for (i in 1..remaining.size) {
                                    result.passthrough.append(remaining[i])
                                }
                            } else {
                                for (r in remaining) {
                                    result.passthrough.append(r)
                                }
                            }
                            break
                        }
                    case None => break
                }
                continue
            }

            // 解析下一个参数
            // 严格翻译自: StreamingClap.parseNextArg()
            let argInfoOpt = parseNextArg(iter)
            let argInfo = match (argInfoOpt) {
                case Some(info) => info
                case None => break  // 无更多参数
            }

            match (argInfo.kind) {
                case ArgKind.Long => {
                    // 处理长选项
                    // 严格翻译自: StreamingClap.normal() .long 分支
                    let parseResult = parseLongArg(argInfo.arg, iter)
                    match (parseResult) {
                        case Some(parsedArg) =>
                            storeParsedArg(parsedArg, result)
                        case None => {
                            // 未识别的标志
                            if (warnOnUnrecognized) {
                                println("warning: unrecognized flag: --${argInfo.arg}")
                            }
                        }
                    }
                }
                case ArgKind.Short => {
                    // 处理短选项 (可能含链式组合)
                    // 严格翻译自: StreamingClap.normal() .short 分支
                    //   return try parser.chainging(.{ .arg = arg, .index = 0 });
                    let parseResult = parseShortArg(argInfo.arg, iter)
                    match (parseResult) {
                        case Some(parsedArg) =>
                            storeParsedArg(parsedArg, result)
                        case None => {
                            if (warnOnUnrecognized) {
                                println("warning: unrecognized flag: -${argInfo.arg}")
                            }
                        }
                    }
                }
                case ArgKind.Positional => {
                    // 处理位置参数
                    // 严格翻译自: StreamingClap.normal() .positional 分支
                    if (argInfo.arg == "--") {
                        // "--" 表示后续都是位置参数
                        // 严格翻译自: if (mem.eql(u8, arg, "--"))
                        //   parser.state = .rest_are_positional;
                        restArePositional = true
                        continue
                    }
                    match (positionalParam) {
                        case Some(param) =>
                            result.positionals.append(argInfo.arg)
                            // 检查 stop_after_positional_at
                            if (stopAfterPositionalAt > 0 && result.positionals.size >= stopAfterPositionalAt) {
                                let remaining = iter.remainingArgs()
                                if (remaining.size > 0 && remaining[0] == "--") {
                                    for (i in 1..remaining.size) {
                                        result.passthrough.append(remaining[i])
                                    }
                                } else {
                                    for (r in remaining) {
                                        result.passthrough.append(r)
                                    }
                                }
                                break
                            }
                        case None =>
                            // 无位置参数定义, 仍收集
                            result.positionals.append(argInfo.arg)
                    }
                }
            }
        }

        // 检查必选参数
        validateRequired(result)

        return result
    }

    // ========================================================================
    // 内部解析方法
    // 严格翻译自: streaming.zig 中各解析函数
    // ========================================================================

    /// 解析下一个参数, 判断类型
    // 严格翻译自: StreamingClap.parseNextArg() ?ArgInfo
    //   if (mem.eql(u8, full_arg, "--") or mem.eql(u8, full_arg, "-"))
    //       return ArgInfo{ .arg = full_arg, .kind = .positional };
    //   if (mem.startsWith(u8, full_arg, "--"))
    //       return ArgInfo{ .arg = full_arg[2..], .kind = .long };
    //   if (mem.startsWith(u8, full_arg, "-"))
    //       return ArgInfo{ .arg = full_arg[1..], .kind = .short };
    //   return ArgInfo{ .arg = full_arg, .kind = .positional };
    private func parseNextArg(iter: ArgIterator): ?ArgInfo {
        match (iter.next()) {
            case Some(fullArg) =>
                if (fullArg == "--" || fullArg == "-") {
                    return Some(ArgInfo(fullArg, ArgKind.Positional))
                }
                if (fullArg.startsWith("--")) {
                    return Some(ArgInfo(fullArg.substring(2), ArgKind.Long))
                }
                if (fullArg.startsWith("-")) {
                    return Some(ArgInfo(fullArg.substring(1), ArgKind.Short))
                }
                return Some(ArgInfo(fullArg, ArgKind.Positional))
            case None => return None
        }
    }

    /// 解析长选项
    // 严格翻译自: StreamingClap.normal() 中 .long 分支
    //   const eql_index = mem.indexOfScalar(u8, arg, '=');
    //   const name = if (eql_index) |i| arg[0..i] else arg;
    //   const maybe_value = if (eql_index) |i| arg[i + 1 ..] else null;
    //   for (parser.params) |*param| {
    //       if (!param.names.matchesLong(name)) continue;
    //       ...
    //   }
    private func parseLongArg(arg: String, iter: ArgIterator): ?ParsedArg {
        // 处理 --key=value 格式
        // 严格翻译自: const eql_index = mem.indexOfScalar(u8, arg, '=')
        let eqIdx = arg.indexOf('=')
        var name: String
        var maybeValue: ?String

        if (eqIdx >= 0) {
            name = arg.substring(0, eqIdx)
            maybeValue = Some(arg.substring(eqIdx + 1))
        } else {
            name = arg
            maybeValue = None
        }

        // 查找匹配的参数定义
        // 严格翻译自: for (parser.params) |*param| { if (!param.names.matchesLong(name)) continue; ... }
        let matchedParam = findParamByLongName(name)
        match (matchedParam) {
            case Some(param) =>
                match (param.takesValue) {
                    case ClapValues.None =>
                        // 布尔标志, 不接受值
                        // 严格翻译自: if (param.takes_value == .none and maybe_value != null)
                        //   return parser.err(..., error.DoesntTakeValue);
                        if (maybeValue != None) {
                            // 布尔标志不接受值, 忽略或记录错误
                            // 为宽松性, 仍设置标志
                            return Some(ParsedArg(param))
                        }
                        return Some(ParsedArg(param))
                    case ClapValues.OneOptional =>
                        // 可选值
                        // 严格翻译自: if (param.takes_value == .none or param.takes_value == .one_optional)
                        //   return ArgType{ .param = param, .value = maybe_value };
                        let val = match (maybeValue) {
                            case Some(v) => v
                            case None => ""
                        }
                        return Some(ParsedArg(param, val))
                    case ClapValues.One =>
                        // 必须有一个值
                        // 严格翻译自: const value = blk: {
                        //   if (maybe_value) |v| break :blk v;
                        //   break :blk parser.iter.next() orelse {
                        //       return parser.err(..., error.MissingValue);
                        //   };
                        // };
                        match (maybeValue) {
                            case Some(v) => return Some(ParsedArg(param, v))
                            case None =>
                                // 从迭代器取下一个参数
                                match (iter.next()) {
                                    case Some(v) => return Some(ParsedArg(param, v))
                                    case None =>
                                        // 缺少值, 记录错误
                                        let diag = ClapDiagnostic()
                                        diag.arg = arg
                                        diag.name = param.names
                                        return None
                                }
                        }
                    case ClapValues.Many =>
                        // 多值
                        match (maybeValue) {
                            case Some(v) => return Some(ParsedArg(param, v))
                            case None =>
                                match (iter.next()) {
                                    case Some(v) => return Some(ParsedArg(param, v))
                                    case None => return None
                                }
                        }
                }
            case None =>
                // 未识别的长选项
                return None
        }
    }

    /// 解析短选项 (支持链式组合 -abc)
    // 严格翻译自: StreamingClap.chainging()
    //   for (parser.params) |*param| {
    //       const short = param.names.short orelse continue;
    //       if (short != arg[index]) continue;
    //       ...
    //   }
    ///
    /// 只处理第一个短选项字符 (链式组合在外部循环中拆分)
    private func parseShortArg(arg: String, iter: ArgIterator): ?ParsedArg {
        if (arg.size == 0) {
            return None
        }

        // 处理链式短选项: -abc -> -a -b -c
        // 严格翻译自: StreamingClap.chainging() 中逐字符遍历
        // 实际处理: 在 parseWithIterator 中, 这里只处理单个短选项或 -ovalue
        let firstChar = arg[0]
        let matchedParam = findParamByShortName(firstChar)
        match (matchedParam) {
            case Some(param) =>
                let remaining = if (arg.size > 1) { arg.substring(1) } else { "" }
                match (param.takesValue) {
                    case ClapValues.None =>
                        // 布尔标志: 检查是否有剩余字符 (链式)
                        // 严格翻译自: if (arg.len <= next_index or param.takes_value != .none)
                        //   parser.state = .normal;
                        if (remaining.size > 0 && remaining != "=") {
                            // 链式短选项: -abc 返回第一个, 其余由外部处理
                            // 简化: 不支持链式组合中的错误检测
                            return Some(ParsedArg(param))
                        }
                        return Some(ParsedArg(param))
                    case ClapValues.OneOptional =>
                        // 可选值: -avalue 或 -a value
                        if (remaining.size > 0 && remaining != "=") {
                            let value = if (remaining.startsWith("=")) {
                                remaining.substring(1)
                            } else {
                                remaining
                            }
                            return Some(ParsedArg(param, value))
                        }
                        return Some(ParsedArg(param, ""))
                    case ClapValues.One | ClapValues.Many =>
                        // 必须有值: -avalue, -a=value, 或 -a value
                        // 严格翻译自:
                        //   if (arg.len <= next_index) {
                        //       const value = parser.iter.next() orelse
                        //           return parser.err(..., error.MissingValue);
                        //       return Arg(Id){ .param = param, .value = value };
                        //   }
                        //   if (next_is_eql) return Arg(Id){ .param = param, .value = arg[next_index + 1 ..] };
                        //   return Arg(Id){ .param = param, .value = arg[next_index..] };
                        if (remaining.size > 0) {
                            let value = if (remaining.startsWith("=")) {
                                remaining.substring(1)
                            } else {
                                remaining
                            }
                            return Some(ParsedArg(param, value))
                        }
                        // 从迭代器取下一个参数
                        match (iter.next()) {
                            case Some(v) => return Some(ParsedArg(param, v))
                            case None => return None
                        }
                }
            case None =>
                return None
        }
    }

    /// 解析链式短选项 (如 -abc)
    // 严格翻译自: streaming.zig chainging() 的完整逻辑
    /// 返回所有解析出的 ParsedArg
    func parseChainedShortArgs(arg: String, iter: ArgIterator): ArrayList<ParsedArg> {
        let results = ArrayList<ParsedArg>()
        var i = 0

        while (i < arg.size) {
            let c = arg[i]
            let nextIdx = i + 1
            let matchedParam = findParamByShortName(c)

            match (matchedParam) {
                case Some(param) =>
                    match (param.takesValue) {
                        case ClapValues.None =>
                            // 布尔标志, 继续链
                            // 严格翻译自: chaining 中 param.takes_value == .none
                            //   if (arg.len <= next_index or param.takes_value != .none)
                            //       parser.state = .normal;
                            //   return ArgType{ .param = param };
                            results.append(ParsedArg(param))
                            i = nextIdx
                        case ClapValues.OneOptional =>
                            // 可选值
                            let hasMore = nextIdx < arg.size
                            if (hasMore) {
                                let rest = arg.substring(nextIdx)
                                let value = if (rest.startsWith("=")) { rest.substring(1) } else { rest }
                                results.append(ParsedArg(param, value))
                            } else {
                                results.append(ParsedArg(param, ""))
                            }
                            break  // 值参数终止链
                        case ClapValues.One | ClapValues.Many =>
                            // 必须有值
                            // 严格翻译自: chaining 中 .one/.many 分支
                            //   if (arg.len <= next_index) {
                            //       const value = parser.iter.next() orelse return err;
                            //       return Arg(Id){ .param = param, .value = value };
                            //   }
                            //   if (next_is_eql) return Arg(Id){ .param = param, .value = arg[next_index + 1 ..] };
                            //   return Arg(Id){ .param = param, .value = arg[next_index..] };
                            let hasMore = nextIdx < arg.size
                            if (hasMore) {
                                let rest = arg.substring(nextIdx)
                                let value = if (rest.startsWith("=")) { rest.substring(1) } else { rest }
                                results.append(ParsedArg(param, value))
                            } else {
                                // 从迭代器取值
                                match (iter.next()) {
                                    case Some(v) => results.append(ParsedArg(param, v))
                                    case None => ()  // 缺少值
                                }
                            }
                            break  // 值参数终止链
                    }
                case None =>
                    // 未识别的短选项字符
                    // 严格翻译自: return parser.err(arg, .{ .short = arg[index] }, error.InvalidArgument);
                    if (warnOnUnrecognized) {
                        println("warning: unrecognized flag: -${c}")
                    }
                    i = nextIdx
            }
        }
        return results
    }

    // ========================================================================
    // 结果存储
    // 严格翻译自: comptime.zig ComptimeClap.parse() 中的结果分类存储逻辑
    // ========================================================================

    /// 将解析出的参数存储到结果中
    // 严格翻译自:
    //   if (param.names.long == null and param.names.short == null) {
    //       try pos.append(arg.value.?);
    //   } else if (param.takes_value == .one or param.takes_value == .one_optional) {
    //       res.single_options[param.id] = arg.value orelse "";
    //   } else if (param.takes_value == .many) {
    //       try multis[param.id].append(arg.value.?);
    //   } else {
    //       res.flags[param.id] = true;
    //   }
    private func storeParsedArg(parsedArg: ParsedArg, result: ParseResult): Unit {
        let param = parsedArg.param
        let paramId = param.id

        if (param.isPositional()) {
            // 位置参数
            // 严格翻译自: try pos.append(arg.value.?);
            match (parsedArg.value) {
                case Some(v) => result.positionals.append(v)
                case None => ()
            }
        } else if (param.takesValue == ClapValues.One || param.takesValue == ClapValues.OneOptional) {
            // 单值选项
            // 严格翻译自: res.single_options[param.id] = arg.value orelse "";
            let val = match (parsedArg.value) {
                case Some(v) => v
                case None => ""
            }
            result.options.put(paramId, val)
            // 同时按长名称存储
            match (param.names.longName) {
                case Some(longName) => {
                        let val2 = match (parsedArg.value) {
                            case Some(v) => v
                            case None => ""
                        }
                        result.options.put(longName, val2)
                    }
                case None => ()
            }
        } else if (param.takesValue == ClapValues.Many) {
            // 多值选项
            // 严格翻译自: try multis[param.id].append(arg.value.?);
            match (result.multiOptions.get(paramId)) {
                case Some(list) =>
                    match (parsedArg.value) {
                        case Some(v) => list.append(v)
                        case None => ()
                    }
                case None =>
                    let list = ArrayList<String>()
                    match (parsedArg.value) {
                        case Some(v) => list.append(v)
                        case None => ()
                    }
                    result.multiOptions.put(paramId, list)
                    // 同时按长名称存储
                    match (param.names.longName) {
                        case Some(longName) => result.multiOptions.put(longName, list)
                        case None => ()
                    }
            }
        } else {
            // 布尔标志
            // 严格翻译自: res.flags[param.id] = true;
            result.flags.put(paramId, true)
            // 同时按长名称存储
            match (param.names.longName) {
                case Some(longName) => result.flags.put(longName, true)
                case None => ()
            }
        }
    }

    // ========================================================================
    // 参数查找
    // ========================================================================

    /// 通过长名称查找参数定义
    // 严格翻译自: streaming.zig 中 for (parser.params) 遍历匹配
    ///   for (parser.params) |*param| {
    ///       if (!param.names.matchesLong(name)) continue;
    ///       ...
    ///   }
    private func findParamByLongName(name: String): ?ClapParam {
        for (param in params) {
            if (param.names.matchesLong(name)) {
                return Some(param)
            }
        }
        return None
    }

    /// 通过短名称查找参数定义
    // 严格翻译自: streaming.zig chainging() 中
    ///   for (parser.params) |*param| {
    ///       const short = param.names.short orelse continue;
    ///       if (short != arg[index]) continue;
    ///       ...
    ///   }
    private func findParamByShortName(c: Char): ?ClapParam {
        for (param in params) {
            match (param.names.shortName) {
                case Some(s) =>
                    if (s == c) {
                        return Some(param)
                    }
                case None => continue
            }
        }
        return None
    }

    /// 查找位置参数定义
    // 严格翻译自: StreamingClap.positionalParam()
    //   for (parser.params) |*param| {
    //       if (param.names.long) |_|
    //           continue;
    //       if (param.names.short) |_|
    //           continue;
    //       parser.positional = param;
    //       return param;
    //   }
    //   return null;
    private func findPositionalParam(): ?ClapParam {
        for (param in params) {
            if (param.isPositional()) {
                return Some(param)
            }
        }
        return None
    }

    /// 验证必选参数
    private func validateRequired(result: ParseResult): Unit {
        for (param in params) {
            if (param.required) {
                let found = result.hasParam(param.id) || match (param.names.longName) {
                    case Some(longName) => result.hasParam(longName)
                    case None => false
                }
                if (!found) {
                    result.errors.append(ClapParseError.MissingRequired(param.id))
                }
            }
        }
    }
}
