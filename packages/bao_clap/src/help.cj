// bao_clap - 帮助文本生成
// 严格翻译自: src/clap/clap.zig
//   pub fn help(stream, Id, params, Error, context, helpText, valueText) !void { ... }
//   pub fn helpEx(stream, Id, params, helpText, valueText) !void { ... }
//   pub fn help(stream, params) !void { ... }
//   pub fn simpleHelp(params: []const Param(Help)) void { ... }
//   pub fn simpleHelpBunTopLevel(params) void { ... }
//   pub fn usage(stream, Id, params, Error, context, valueText) !void { ... }
//   pub fn usageEx(stream, Id, params, valueText) !void { ... }
//   pub fn usage(stream, params) !void { ... }
//   pub fn simplePrintParam(param: Param(Help)) !void { ... }
//   fn printParam(stream, Id, param, Error, context, valueText) !void { ... }
package bao_clap

import bao_core.*
import bao_collections.*

// ============================================================================
// formatHelp - 格式化帮助文本
// 严格翻译自: clap.zig - helpFull / helpEx / help / simpleHelp
//
// helpFull 格式:
//     -s, --long <valueText> helpText
//     -s,                    helpText
//     -s <valueText>         helpText
//         --long             helpText
//         --long <valueText> helpText
//
// simpleHelp 格式:
//   对齐所有选项名称, 然后右侧放描述文本
//   自动计算最大间距
// ============================================================================

/// 格式化参数名称部分 (用于帮助文本)
// 严格翻译自: clap.zig - printParam()
//   if (param.names.short) |s| {
//       try stream.print("-{c}", .{s});
//   } else {
//       try stream.print("  ", .{});
//   }
//   if (param.names.long) |l| {
//       if (param.names.short) |_| {
//           try stream.print(", ", .{});
//       } else {
//           try stream.print("  ", .{});
//       }
//       try stream.print("--{s}", .{l});
//   }
//   switch (param.takes_value) {
//       .none => {},
//       .one => try stream.print(" <{s}>", .{try valueText(context, param)}),
//       .one_optional => try stream.print(" <{s}>?", .{try valueText(context, param)}),
//       .many => try stream.print(" <{s}>...", .{try valueText(context, param)}),
//   }
public func formatParamNames(param: ClapParam): String {
    let sb = StringBuilder()

    // 短名称部分
    // 严格翻译自: if (param.names.short) |s| { try stream.print("-{c}", .{s}); } else { "  " }
    match (param.names.shortName) {
        case Some(s) =>
            sb.append("-")
            sb.append(s.toString())
        case None =>
            sb.append("  ")
    }

    // 长名称部分
    // 严格翻译自: if (param.names.long) |l| { ", "--" or "  " + "--{s}" }
    match (param.names.longName) {
        case Some(l) =>
            match (param.names.shortName) {
                case Some(_) => sb.append(", ")
                case None => sb.append("  ")
            }
            sb.append("--")
            sb.append(l)
        case None =>
            sb.append("    ")
    }

    // 值部分
    // 严格翻译自: switch (param.takes_value)
    let valueName = if (param.help.valueName.size > 0) {
        param.help.valueName
    } else {
        "value"
    }

    match (param.takesValue) {
        case ClapValues.None => {}  // 不追加值部分
        case ClapValues.One =>
            sb.append(" <")
            sb.append(valueName)
            sb.append(">")
        case ClapValues.OneOptional =>
            sb.append(" <")
            sb.append(valueName)
            sb.append(">?")
        case ClapValues.Many =>
            sb.append(" <")
            sb.append(valueName)
            sb.append(">...")
    }

    return sb.toString()
}

/// 计算参数名称部分的最大宽度
// 严格翻译自: clap.zig - helpFull() 中的 max_spacing 计算
//   const max_spacing = blk: {
//       var res: usize = 0;
//       for (params) |param| {
//           var cs = io.countingWriter(io.null_writer);
//           try printParam(cs.writer(), Id, param, Error, context, valueText);
//           if (res < cs.bytes_written)
//               res = @as(usize, @intCast(cs.bytes_written));
//       }
//       break :blk res;
//   };
public func computeMaxParamWidth(params: ArrayList<ClapParam>): Int64 {
    var maxWidth: Int64 = 2  // 最小宽度
    for (param in params) {
        if (param.isPositional()) { continue }
        if (param.hidden) { continue }
        let desc = param.help.message
        if (desc.size == 0) { continue }  // 只打印有描述的参数
        let names = formatParamNames(param)
        if (names.size > maxWidth) {
            maxWidth = names.size
        }
    }
    return maxWidth
}

/// 格式化完整帮助文本
// 严格翻译自: clap.zig - helpFull() + simpleHelp()
//
// simpleHelp 逻辑:
//   1. 计算 max_spacing (所有参数名称的最大宽度)
//   2. 遍历参数, 跳过位置参数和空描述
//   3. 打印: \t names \t padding \t description
//
// helpFull 逻辑:
//   for (params) |param| {
//       if (param.names.short == null and param.names.long == null)
//           continue;
//       const help_text = try helpText(context, param);
//       if (help_text.len > 0) {
//           try stream.print("\t", .{});
//           try printParam(cs.writer(), Id, param, Error, context, valueText);
//           try stream.splatByteAll(' ', max_spacing - cs.bytes_written);
//           try stream.print("\t{s}\n", .{try helpText(context, param)});
//       }
//   }
public func formatHelp(programName: String, description: String, params: ArrayList<ClapParam>): String {
    return formatHelpWithCommands(programName, description, params, ArrayList<(String, String)>())
}

/// 格式化帮助文本 (带子命令)
public func formatHelpWithCommands(programName: String, description: String, params: ArrayList<ClapParam>, commands: ArrayList<(String, String)>): String {
    let sb = StringBuilder()

    // 程序描述头
    // 对应 Bun: simpleHelp 没有显式头, 但 clap 典型输出有
    sb.append("${programName} - ${description}\n\n")

    // Usage 行
    sb.append("Usage: ${programName}")
    if (commands.size > 0) {
        sb.append(" <command>")
    }
    sb.append(" [options]")
    // 检查是否有位置参数
    for (param in params) {
        if (param.isPositional()) {
            sb.append(" <${param.help.valueName}>")
            break
        }
    }
    sb.append("\n\n")

    // 子命令列表
    if (commands.size > 0) {
        sb.append("Commands:\n")
        let maxCmdWidth = computeMaxCommandWidth(commands)
        for ((name, desc) in commands) {
            sb.append("  ")
            sb.append(name)
            // 填充空格对齐
            let padding = maxCmdWidth - name.size
            var p = 0
            while (p < padding) {
                sb.append(" ")
                p += 1
            }
            sb.append("  ")
            sb.append(desc)
            sb.append("\n")
        }
        sb.append("\n")
    }

    // 选项列表
    // 严格翻译自: simpleHelp / helpFull
    sb.append("Options:\n")
    let maxParamWidth = computeMaxParamWidth(params)

    for (param in params) {
        // 跳过位置参数
        // 严格翻译自: if (param.names.short == null and param.names.long == null) continue;
        if (param.isPositional()) { continue }
        if (param.hidden) { continue }

        // 跳过空描述
        // 严格翻译自: if (desc_text.len == 0) continue;
        let descText = param.help.message
        if (descText.size == 0) { continue }

        // 打印参数名称
        // 严格翻译自: simplePrintParam(param) catch unreachable;
        let names = formatParamNames(param)

        // 计算填充
        // 严格翻译自: try stream.splatByteAll(' ', max_spacing - cs.bytes_written);
        let padding = maxParamWidth - names.size

        sb.append("  ")
        sb.append(names)
        var p = 0
        while (p < padding) {
            sb.append(" ")
            p += 1
        }
        sb.append("  ")
        sb.append(descText)

        // 默认值
        match (param.defaultValue) {
            case Some(v) => sb.append(" (default: ${v})")
            case None => {}
        }

        // 必选标记
        if (param.required) {
            sb.append(" [required]")
        }

        sb.append("\n")
    }

    return sb.toString()
}

/// 计算子命令名称最大宽度
private func computeMaxCommandWidth(commands: ArrayList<(String, String)>): Int64 {
    var maxWidth: Int64 = 6  // 最小宽度
    for ((name, _) in commands) {
        if (name.size > maxWidth) {
            maxWidth = name.size
        }
    }
    return maxWidth
}

// ============================================================================
// formatUsage - 格式化用法行
// 严格翻译自: clap.zig - usageFull / usageEx / usage
//
// usageFull 格式:
//   [-abc] [--longa] [-d <valueText>] [--longb <valueText>] <valueText>
//
// 逻辑:
//   1. 首先收集所有不接受值的短选项, 合并为 [-abc]
//   2. 然后输出不接受值的长选项和其他选项
//   3. 最后输出位置参数
//
// 严格翻译自:
//   for (params) |param| {
//       const name = param.names.short orelse continue;
//       if (param.takes_value != .none) continue;
//       if (cos.bytes_written == 0) try stream.writeAll("[-");
//       try cs.writeByte(name);
//   }
//   if (cos.bytes_written != 0) try cs.writeByte(']');
//   ...
//   if (positional) |p| {
//       try cs.print("<{s}>", .{try valueText(context, p)});
//   }
// ============================================================================

/// 格式化用法行
// 严格翻译自: usage() -> usageEx() -> usageFull()
public func formatUsage(programName: String, params: ArrayList<ClapParam>): String {
    let sb = StringBuilder()
    sb.append("Usage: ${programName}")

    // 第一阶段: 收集不接受值的短选项
    // 严格翻译自: for (params) |param| { const name = param.names.short orelse continue; if (param.takes_value != .none) continue; ... }
    let shortFlags = StringBuilder()
    for (param in params) {
        match (param.names.shortName) {
            case Some(s) =>
                if (param.takesValue == ClapValues.None) {
                    shortFlags.append(s.toString())
                }
            case None => continue
        }
    }
    if (shortFlags.size > 0) {
        sb.append(" [-")
        sb.append(shortFlags.toString())
        sb.append("]")
    }

    // 第二阶段: 长选项和带值的选项
    // 严格翻译自: for (params) |param| { if (...short != null) continue; ... }
    var positionalParam: ?ClapParam = None
    for (param in params) {
        if (param.takesValue == ClapValues.None && param.names.hasShort()) {
            continue  // 已在上面处理
        }

        let prefix = if (param.names.hasShort()) { "-" } else { "--" }
        let name = match (param.names.shortName) {
            case Some(s) => s.toString()
            case None =>
                match (param.names.longName) {
                    case Some(l) => l
                    case None =>
                        // 位置参数
                        positionalParam = Some(param)
                        continue
                }
        }

        sb.append(" [${prefix}${name}")

        // 值部分
        // 严格翻译自: switch (param.takes_value)
        let valueName = if (param.help.valueName.size > 0) {
            param.help.valueName
        } else {
            "value"
        }
        match (param.takesValue) {
            case ClapValues.None => {}
            case ClapValues.One => sb.append(" <${valueName}>")
            case ClapValues.OneOptional => sb.append(" <${valueName}>?")
            case ClapValues.Many => sb.append(" <${valueName}>...")
        }

        sb.append("]")
    }

    // 第三阶段: 位置参数
    // 严格翻译自: if (positional) |p| { try cs.print("<{s}>", .{...}); }
    match (positionalParam) {
        case Some(p) =>
            let valueName = if (p.help.valueName.size > 0) { p.help.valueName } else { "arg" }
            sb.append(" <${valueName}>")
        case None => {}
    }

    return sb.toString()
}

// ============================================================================
// simplePrintParam - 简单打印单个参数
// 严格翻译自: clap.zig - simplePrintParam()
//   pub fn simplePrintParam(param: Param(Help)) !void {
//       Output.pretty("\n", .{});
//       if (param.names.short) |s| {
//           if (param.takes_value != .none and param.names.long == null) {
//               Output.pretty("  <cyan>-{c}<r><d><cyan>=\\<val\\><r>", .{s});
//           } else {
//               Output.pretty("  <cyan>-{c}<r>", .{s});
//           }
//       } else {
//           Output.pretty("    ", .{});
//       }
//       if (param.names.long) |l| {
//           if (param.names.short) |_| { Output.pretty(", ", .{}); }
//           else { Output.pretty("  ", .{}); }
//           if (param.takes_value != .none) {
//               Output.pretty("<cyan>--{s}<r><d><cyan>=\\<val\\><r>", .{l});
//           } else {
//               Output.pretty("<cyan>--{s}<r>", .{l});
//           }
//       } else {
//           Output.pretty("    ", .{});
//       }
//   }
// ============================================================================

/// 格式化单个参数 (简单版, 用于顶层帮助)
// 严格翻译自: simplePrintParam()
/// 此版本去除颜色标签 (Bun 使用 Output.pretty 颜色, 仓颉用纯文本)
public func simpleFormatParam(param: ClapParam): String {
    let sb = StringBuilder()

    // 短名称
    match (param.names.shortName) {
        case Some(s) =>
            if (param.takesValueFlag() && !param.names.hasLong()) {
                // 带值的短选项且无长名称
                // 严格翻译自: if (param.takes_value != .none and param.names.long == null)
                sb.append("  -${s}=<val>")
            } else {
                sb.append("  -${s}")
            }
        case None =>
            sb.append("    ")
    }

    // 长名称
    match (param.names.longName) {
        case Some(l) =>
            match (param.names.shortName) {
                case Some(_) => sb.append(", ")
                case None => sb.append("  ")
            }
            if (param.takesValueFlag()) {
                sb.append("--${l}=<val>")
            } else {
                sb.append("--${l}")
            }
        case None =>
            sb.append("    ")
    }

    return sb.toString()
}

/// 简单帮助文本生成 (对应 Bun simpleHelp)
// 严格翻译自: clap.zig simpleHelp(params)
//   const max_spacing = blk: { ... };
//   for (params) |param| {
//       if (param.names.short == null and param.names.long == null) continue;
//       const desc_text = getHelpSimple(param);
//       if (desc_text.len == 0) continue;
//       ...
//       simplePrintParam(param) catch unreachable;
//       Output.pretty("  {s}  {s}", .{ spaces_after, desc_text });
//   }
public func formatSimpleHelp(params: ArrayList<ClapParam>): String {
    let sb = StringBuilder()

    // 计算最大宽度
    // 严格翻译自: simpleHelp 中的 max_spacing 计算
    //   const max_spacing = blk: {
    //       var res: usize = 2;
    //       for (params) |param| {
    //           const flags_len = if (param.names.long) |l| l.len else 0;
    //           const value_len: usize = if (param.takes_value != .none) 6 else 0;
    //           if (res < flags_len + value_len) res = flags_len + value_len;
    //       }
    //       break :blk res;
    //   };
    var maxWidth: Int64 = 2
    for (param in params) {
        if (param.isPositional()) { continue }
        if (param.hidden) { continue }
        let descText = param.help.message
        if (descText.size == 0) { continue }

        let flagsLen = match (param.names.longName) {
            case Some(l) => l.size
            case None => 0
        }
        let valueLen = if (param.takesValueFlag()) { 6 } else { 0 }  // "=<val>"
        let total = flagsLen + valueLen
        if (total > maxWidth) {
            maxWidth = total
        }
    }

    // 输出参数行
    for (param in params) {
        if (param.isPositional()) { continue }
        if (param.hidden) { continue }

        let descText = param.help.message
        if (descText.size == 0) { continue }

        let paramStr = simpleFormatParam(param)

        // 计算填充
        // 严格翻译自: const num_spaces_after = max_spacing - total_len;
        let flagsLen = match (param.names.longName) {
            case Some(l) => l.size
            case None => 0
        }
        let valueLen = if (param.takesValueFlag()) { 6 } else { 0 }
        let total = flagsLen + valueLen
        let padding = maxWidth - total

        sb.append(paramStr)
        var p = 0
        while (p < padding) {
            sb.append(" ")
            p += 1
        }
        sb.append("  ")
        sb.append(descText)
        sb.append("\n")
    }

    return sb.toString()
}

// ============================================================================
// 辅助函数
// ============================================================================

/// String 填充到指定宽度 (右填充空格)
private func String.padEnd(width: Int64): String {
    if (this.size >= width) {
        return this
    }
    let sb = StringBuilder()
    sb.append(this)
    var i = this.size
    while (i < width) {
        sb.append(" ")
        i += 1
    }
    return sb.toString()
}
