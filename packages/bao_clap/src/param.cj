// bao_clap - 参数定义
// 严格翻译自: src/clap/clap.zig
//   pub const Names = struct { short: ?u8, long: ?[]const u8, long_aliases: []const []const u8 }
//   pub const Values = enum { none, one, many, one_optional }
//   pub fn Param(comptime Id: type) type { ... }
//   pub fn parseParam(line: []const u8) !Param(Help) { ... }
//   pub const Help = struct { msg: []const u8, value: []const u8 }
//   pub const Diagnostic = struct { ... }
package bao.clap

import bao_core.*
import bao_collections.*

// ============================================================================
// ClapNames - 参数名称
// 严格翻译自: src/clap/clap.zig - Names struct
//   pub const Names = struct {
//       short: ?u8 = null,
//       long: ?[]const u8 = null,
//       long_aliases: []const []const u8 = &.{},
//       pub fn matchesLong(self: Names, name: []const u8) bool { ... }
//   };
// ============================================================================

/// 参数名称定义
/// 对应 Bun: clap.Names
/// short: '-' 前缀的单字符标志
/// long: '--' 前缀的长名称 (主名称, 用于显示/帮助)
/// longAliases: 额外的 '--' 前缀别名 (如 --grep 作为 --test-name-pattern 的别名)
public class ClapNames {
    /// '-' 前缀的单字符标志
    // 严格翻译自: Names.short: ?u8
    public var shortName: ?Char

    /// '--' 前缀的长名称 (主名称)
    // 严格翻译自: Names.long: ?[]const u8
    public var longName: ?String

    /// 额外的 '--' 前缀别名
    // 严格翻译自: Names.long_aliases: []const []const u8
    public var longAliases: ArrayList<String>

    public init() {
        shortName = None
        longName = None
        longAliases = ArrayList<String>()
    }

    public init(shortName: Char, longName: String) {
        this.shortName = Some(shortName)
        this.longName = Some(longName)
        this.longAliases = ArrayList<String>()
    }

    public init(longName: String) {
        this.shortName = None
        this.longName = Some(longName)
        this.longAliases = ArrayList<String>()
    }

    public init(shortName: Char) {
        this.shortName = Some(shortName)
        this.longName = None
        this.longAliases = ArrayList<String>()
    }

    /// 检查给定名称是否匹配主长名称或任何别名
    // 严格翻译自: Names.matchesLong(name: []const u8) bool
    //   if (self.long) |l| { if (mem.eql(u8, name, l)) return true; }
    //   for (self.long_aliases) |alias| { if (mem.eql(u8, name, alias)) return true; }
    //   return false;
    public func matchesLong(name: String): Bool {
        match (longName) {
            case Some(l) =>
                if (l == name) {
                    return true
                }
            case None => {}
        }
        for (alias in longAliases) {
            if (alias == name) {
                return true
            }
        }
        return false
    }

    /// 是否有短名称
    public func hasShort(): Bool {
        match (shortName) {
            case Some(_) => return true
            case None => return false
        }
    }

    /// 是否有长名称
    public func hasLong(): Bool {
        match (longName) {
            case Some(_) => return true
            case None => return false
        }
    }
}

// ============================================================================
// ClapValues - 参数值类型
// 严格翻译自: src/clap/clap.zig - Values enum
//   pub const Values = enum { none, one, many, one_optional };
// ============================================================================

/// 参数值接收模式
/// 对应 Bun: clap.Values
/// none: 布尔标志, 不接受值 (如 --verbose, -v)
/// one: 必须接受一个值 (如 --output <file>)
/// many: 接受多个值, 可重复指定 (如 --external pkg1 --external pkg2)
/// one_optional: 可选接受一个值 (如 --color[=always])
public enum ClapValues {
    | None         // 不接受值 (布尔标志)
    | One          // 必须接受一个值
    | Many         // 接受多个值 (可重复)
    | OneOptional  // 可选接受一个值
}

// ============================================================================
// ClapParamHelp - 帮助文本数据
// 严格翻译自: src/clap/clap.zig - Help struct
//   pub const Help = struct { msg: []const u8 = "", value: []const u8 = "" };
// ============================================================================

/// 参数帮助信息
/// 对应 Bun: clap.Help
/// msg: 描述文本 (如 "Verbose output")
/// value: 值占位符 (如 "file", "dir")
public class ClapParamHelp {
    /// 描述文本
    // 严格翻译自: Help.msg: []const u8
    public var message: String

    /// 值占位符名称
    // 严格翻译自: Help.value: []const u8
    public var valueName: String

    public init() {
        message = ""
        valueName = ""
    }

    public init(message: String, valueName: String) {
        this.message = message
        this.valueName = valueName
    }
}

// ============================================================================
// ClapParam - 参数定义
// 严格翻译自: src/clap/clap.zig - Param(Id) type
//   pub fn Param(comptime Id: type) type {
//       return struct {
//           id: Id = std.mem.zeroes(Id),
//           names: Names = std.mem.zeroes(Names),
//           takes_value: Values = .none,
//       };
//   }
//
// 同时结合 comptime.zig 中使用的 Param 字段语义:
//   flags: 不接受值的参数 (Values.none)
//   single_options: 接受单个值的参数 (Values.one / Values.one_optional)
//   multi_options: 接受多个值的参数 (Values.many)
//   pos: 位置参数 (无 short/long 名称)
// ============================================================================

/// 命令行参数定义
/// 对应 Bun: clap.Param(Id)
///
/// 参数分三类:
///   * 短选项 ("-a"): 常用参数, 可链式组合 ("-abc"), 最后一个可带值
///   * 长选项 ("--long-param"): 较少使用的参数, 需要更详细描述时使用
///   * 位置参数: 主要参数, 如文件名或表达式, 无 short/long 名称
public class ClapParam {
    /// 唯一标识符 (参数名称)
    // 严格翻译自: Param.id: Id
    public var id: String

    /// 参数名称 (短/长)
    // 严格翻译自: Param.names: Names
    public var names: ClapNames

    /// 值接收模式
    // 严格翻译自: Param.takes_value: Values
    public var takesValue: ClapValues

    /// 帮助文本
    // 严格翻译自: Param(id=Help) 中 id.msg 和 id.value
    public var help: ClapParamHelp

    /// 默认值 (非 Zig 原生字段, 为仓颉便利性添加)
    public var defaultValue: ?String

    /// 是否必须提供
    public var required: Bool

    /// 是否隐藏 (不出现在帮助文本中)
    public var hidden: Bool

    public init(id: String) {
        this.id = id
        names = ClapNames()
        takesValue = ClapValues.None
        help = ClapParamHelp()
        defaultValue = None
        required = false
        hidden = false
    }

    public init(id: String, names: ClapNames, takesValue: ClapValues) {
        this.id = id
        this.names = names
        this.takesValue = takesValue
        help = ClapParamHelp()
        defaultValue = None
        required = false
        hidden = false
    }

    public init(id: String, names: ClapNames, takesValue: ClapValues, help: ClapParamHelp) {
        this.id = id
        this.names = names
        this.takesValue = takesValue
        this.help = help
        defaultValue = None
        required = false
        hidden = false
    }

    /// 是否为位置参数 (无短名称也无长名称)
    // 严格翻译自: streaming.zig 中 positionalParam() 的判断逻辑
    //   if (param.names.long) |_|
    //       continue;
    //   if (param.names.short) |_|
    //       continue;
    public func isPositional(): Bool {
        return !names.hasShort() && !names.hasLong()
    }

    /// 是否接受值
    // 严格翻译自: clap.zig 中 param.takes_value == .none 判断
    public func takesValueFlag(): Bool {
        return match (takesValue) {
            case ClapValues.None => false
            case ClapValues.One => true
            case ClapValues.Many => true
            case ClapValues.OneOptional => true
        }
    }
}

// ============================================================================
// ClapDiagnostic - 诊断信息
// 严格翻译自: src/clap/clap.zig - Diagnostic struct
//   pub const Diagnostic = struct {
//       arg: []const u8 = "",
//       name: Names = Names{},
//       pub fn report(diag: Diagnostic, _: anytype, err: anyerror) !void { ... }
//   };
// ============================================================================

/// 解析错误诊断信息
/// 对应 Bun: clap.Diagnostic
public class ClapDiagnostic {
    /// 导致错误的原始参数字符串
    // 严格翻译自: Diagnostic.arg: []const u8
    public var arg: String

    /// 匹配到的参数名称 (如果有)
    // 严格翻译自: Diagnostic.name: Names
    public var name: ClapNames

    public init() {
        arg = ""
        name = ClapNames()
    }

    /// 生成错误报告消息
    // 严格翻译自: Diagnostic.report() 中的错误消息格式
    //   DoesntTakeValue => "The argument '{s}' does not take a value."
    //   MissingValue => "The argument '{s}' requires a value but none was supplied."
    //   InvalidArgument => "Invalid Argument '{s}'"
    public func report(err: ClapParseError): String {
        let nameStr = formatName()
        match (err) {
            case ClapParseError.DoesntTakeValue =>
                return "error: The argument '${nameStr}' does not take a value."
            case ClapParseError.MissingValue =>
                return "error: The argument '${nameStr}' requires a value but none was supplied."
            case ClapParseError.InvalidArgument =>
                return "error: Invalid Argument '${nameStr}'"
            case ClapParseError.UnknownArgument =>
                return "error: Unknown argument '${nameStr}'"
            case ClapParseError.MissingRequired(paramId) =>
                return "error: Missing required argument '${paramId}'"
        }
    }

    /// 格式化参数名称用于错误输出
    // 严格翻译自: Diagnostic.report() 中的 name_buf 逻辑
    //   if (diag.name.short) |s| short: { name_buf[0..2] = "-s" }
    //   else if (diag.name.long) |l| long: { name_buf[0..2+l.len] = "--long" }
    //   else diag.arg;
    private func formatName(): String {
        match (name.shortName) {
            case Some(s) => return "-${s}"
            case None => {}
        }
        match (name.longName) {
            case Some(l) => return "--${l}"
            case None => {}
        }
        return arg
    }
}

// ============================================================================
// ClapParseError - 解析错误类型
// 严格翻译自: streaming.zig - StreamingClap.ArgError
//   const ArgError = error{ DoesntTakeValue, MissingValue, InvalidArgument };
// 扩展: 增加未知参数和缺少必选参数错误
// ============================================================================

/// 解析错误
/// 对应 Bun: StreamingClap.ArgError
public enum ClapParseError {
    | DoesntTakeValue        // 参数不接受值但提供了值
    | MissingValue           // 参数需要值但未提供
    | InvalidArgument        // 无效的参数
    | UnknownArgument        // 未识别的参数
    | MissingRequired(String) // 缺少必选参数 (参数 ID)

    /// 获取错误消息
    public func message(): String {
        match (this) {
            case DoesntTakeValue => "Does not take a value"
            case MissingValue => "Missing required value"
            case InvalidArgument => "Invalid argument"
            case UnknownArgument => "Unknown argument"
            case MissingRequired(id) => "Missing required argument: ${id}"
        }
    }
}
