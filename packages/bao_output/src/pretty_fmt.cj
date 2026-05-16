// 严格翻译自: src/bun_core/output.rs:1857-2158
//   pub fn pretty_fmt_runtime(fmt: &[u8], is_enabled: bool) -> Vec<u8>
//   pub trait PrettyFmtInput { fn into_pretty_buf(self, is_enabled: bool) -> PrettyBuf; }
//   pub struct PrettyBuf(pub Vec<u8>);
//   pub struct TemplateDisplay<'a, A: FmtTuple> { ... }
//   pub fn substitute_template(template, args, f) -> fmt::Result { ... }
//
// 也翻译自: src/bun_core/output.zig:982-1057
//   pub fn prettyFmt(comptime fmt: string, comptime is_enabled: bool) [:0]const u8
package bao_output

import bao_core.*

import std.collection.*

// ============================================================================
// PrettyBuf - Pretty 格式化结果缓冲区
// 严格翻译自: src/bun_core/output.rs:1888-1917
//   pub struct PrettyBuf(pub Vec<u8>);
//   impl Deref for PrettyBuf { type Target = [u8]; ... }
//   impl Display for PrettyBuf { ... }
// ============================================================================

/// Pretty 格式化结果缓冲区 - 对应 Bun PrettyBuf
/// pub struct PrettyBuf(pub Vec<u8>);
public class PrettyBuf {
    /// 内容
    public var content: String

    public init(content: String) {
        this.content = content
    }

    /// 是否以换行结尾
    public func endsWithNewline(): Bool {
        return content.endsWith("\n")
    }

    /// 转字符串
    public func toString(): String {
        return content
    }
}

// ============================================================================
// PrettyFmtRuntime - Pretty 格式化运行时
// 严格翻译自: src/bun_core/output.rs:2090-2158
//   pub fn pretty_fmt_runtime(fmt: &[u8], is_enabled: bool) -> Vec<u8>
//
// 也翻译自: src/bun_core/output.zig:982-1057
//   pub fn prettyFmt(comptime fmt: string, comptime is_enabled: bool) [:0]const u8
//   comptime var new_fmt: [fmt.len * 4]u8 = undefined;
//   comptime var i: usize = 0;
//   while (i < fmt.len) {
//       switch (fmt[i]) {
//           '\\' => { ... }
//           '>' => { i += 1; }
//           '{' => { while (fmt.len > i and fmt[i] != '}') { ... } }
//           '<' => { ... color_map.get(color_name) ... }
//           else => { ... }
//       }
//   }
// ============================================================================

/// Pretty 格式化运行时 - 对应 Bun prettyFmt / pretty_fmt_runtime
/// 独立于 bao_core.Output.prettyFmt 以便扩展
public class PrettyFmtRuntime {

    /// ANSI 颜色映射 - 对应 Bun color_map
    /// pub const color_map = ComptimeStringMap(string, .{
    ///     .{"b", CSI ++ "1m"}, .{"d", CSI ++ "2m"}, ...
    /// });
    private static func ansiColor(name: String): String {
        let CSI = "\u{1b}["
        if (name == "b") { return "${CSI}1m" }      // bold
        if (name == "d") { return "${CSI}2m" }      // dim
        if (name == "i") { return "${CSI}3m" }      // italic
        if (name == "u") { return "${CSI}4m" }      // underline
        if (name == "black") { return "${CSI}30m" }
        if (name == "red") { return "${CSI}31m" }
        if (name == "green") { return "${CSI}32m" }
        if (name == "yellow") { return "${CSI}33m" }
        if (name == "blue") { return "${CSI}34m" }
        if (name == "magenta") { return "${CSI}35m" }
        if (name == "cyan") { return "${CSI}36m" }
        if (name == "white") { return "${CSI}37m" }
        if (name == "bgred") { return "${CSI}41m" }
        if (name == "bggreen") { return "${CSI}42m" }
        return ""
    }

    /// ANSI 重置序列 - 对应 Bun RESET
    private static let RESET: String = "\u{1b}[0m"

    /// 重写格式字符串 - 对应 Bun prettyFmt / pretty_fmt_runtime
    /// pub fn pretty_fmt_runtime(fmt: &[u8], is_enabled: bool) -> Vec<u8>
    ///
    /// 将 <red>, <b>, <r> 等标签转为 ANSI 转义码 (当 isEnabled=true)
    /// 或移除标签 (当 isEnabled=false)
    public static func rewrite(fmt: String, isEnabled: Bool): String {
        if (!isEnabled) {
            return stripTags(fmt)
        }

        var result = StringBuilder()
        var i = 0
        let bytes = fmt.toArray()
        let len = bytes.size

        while (i < len) {
            let b = bytes[i]
            if (b == UInt8(92)) { // '\'
                // 反斜杠转义: \< 或 \> 输出字面 < 或 >
                i += 1
                if (i < len) {
                    let next = bytes[i]
                    if (next == UInt8(60) || next == UInt8(62)) { // '<' or '>'
                        result.append(Rune(Int32(next)))
                        i += 1
                    } else {
                        result.append(Rune(Int32(b)))
                        result.append(Rune(Int32(next)))
                        i += 1
                    }
                } else {
                    result.append(Rune(Int32(b)))
                }
            } else if (b == UInt8(62)) { // '>' - 忽略 (Bun 的约定)
                i += 1
            } else if (b == UInt8(123)) { // '{' - 格式化占位符, 保留
                while (i < len && bytes[i] != UInt8(125)) { // '}'
                    result.append(Rune(Int32(bytes[i])))
                    i += 1
                }
                // 包含 '}'
                if (i < len) {
                    result.append(Rune(Int32(bytes[i])))
                    i += 1
                }
            } else if (b == UInt8(60)) { // '<' - 开始标签
                i += 1
                var isReset = false
                if (i < len && bytes[i] == UInt8(47)) { // '/'
                    isReset = true
                    i += 1
                }
                let start = i
                while (i < len && bytes[i] != UInt8(62)) { // '>'
                    i += 1
                }
                var colorNameBuilder = StringBuilder()
                var nameIndex = start
                while (nameIndex < i) {
                    colorNameBuilder.append(Rune(Int32(bytes[nameIndex])))
                    nameIndex += 1
                }
                let colorName = colorNameBuilder.toString()
                if (colorName == "r") {
                    isReset = true
                }
                let colorStr = ansiColor(colorName)
                if (isReset) {
                    result.append(RESET)
                } else if (colorStr.size > 0) {
                    result.append(colorStr)
                }
                // 跳过 '>'
                if (i < len) {
                    i += 1
                }
            } else {
                result.append(Rune(Int32(b)))
                i += 1
            }
        }

        return result.toString()
    }

    /// 移除 Pretty 标签 (不启用颜色时)
    /// 对应 Bun prettyFmt(fmt, false) - 剥离所有 <tag> 标签
    private static func stripTags(fmt: String): String {
        var result = StringBuilder()
        var i = 0
        let bytes = fmt.toArray()
        let len = bytes.size

        while (i < len) {
            let b = bytes[i]
            if (b == UInt8(92)) { // '\'
                i += 1
                if (i < len) {
                    let next = bytes[i]
                    if (next == UInt8(60) || next == UInt8(62)) {
                        result.append(Rune(Int32(next)))
                        i += 1
                    } else {
                        result.append(Rune(Int32(b)))
                        result.append(Rune(Int32(next)))
                        i += 1
                    }
                } else {
                    result.append(Rune(Int32(b)))
                }
            } else if (b == UInt8(62)) { // '>' - 忽略
                i += 1
            } else if (b == UInt8(123)) { // '{' - 格式化占位符, 保留
                while (i < len && bytes[i] != UInt8(125)) {
                    result.append(Rune(Int32(bytes[i])))
                    i += 1
                }
                if (i < len) {
                    result.append(Rune(Int32(bytes[i])))
                    i += 1
                }
            } else if (b == UInt8(60)) { // '<' - 标签, 跳过
                i += 1
                if (i < len && bytes[i] == UInt8(47)) { // '/'
                    i += 1
                }
                while (i < len && bytes[i] != UInt8(62)) {
                    i += 1
                }
                if (i < len) {
                    i += 1
                }
            } else {
                result.append(Rune(Int32(b)))
                i += 1
            }
        }

        return result.toString()
    }
}

// ============================================================================
// TemplateSubstituter - 模板参数替换
// 严格翻译自: src/bun_core/output.rs:1919-2050
//   pub trait FmtTuple { fn write_nth(&self, idx, f) -> Result<bool, Error>; fn len(&self); }
//   fn substitute_template(template: &[u8], args: &impl FmtTuple, f: &mut dyn fmt::Write) -> fmt::Result
// ============================================================================

/// 模板参数替换 - 对应 Bun substitute_template
/// 将模板中的 {} / {s} / {d} 占位符替换为参数
public class TemplateSubstituter {

    /// 替换模板中的占位符
    /// fn substitute_template(template: &[u8], args: &impl FmtTuple, f: &mut dyn fmt::Write) -> fmt::Result
    public static func substitute(template: String, args: Array<String>): String {
        var result = StringBuilder()
        var i = 0
        let bytes = template.toArray()
        let len = bytes.size
        var argIdx = 0

        while (i < len) {
            let b = bytes[i]
            if (b == UInt8(123)) { // '{'
                if (i + 1 < len && bytes[i + 1] == UInt8(123)) { // '{{' -> literal '{'
                    result.append("{")
                    i += 2
                } else {
                    // 找到结束 '}'
                    var j = i + 1
                    while (j < len && bytes[j] != UInt8(125)) {
                        j += 1
                    }
                    // 替换占位符
                    if (argIdx < args.size) {
                        result.append(args[argIdx])
                        argIdx += 1
                    }
                    if (j < len) {
                        j += 1
                    }
                    i = j
                }
            } else if (b == UInt8(125)) { // '}'
                if (i + 1 < len && bytes[i + 1] == UInt8(125)) { // '}}' -> literal '}'
                    result.append("}")
                    i += 2
                } else {
                    result.append(Rune(Int32(b)))
                    i += 1
                }
            } else {
                result.append(Rune(Int32(b)))
                i += 1
            }
        }

        return result.toString()
    }
}
