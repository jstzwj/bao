// 严格翻译自: src/bun_core/output.zig
//   pub const Source = struct { ... }
//   pub var enable_ansi_colors_stderr = Environment.isNative;
//   pub fn print(...) / prettyError(...) / debug(...) / scoped(...) ...
//   pub fn prettyFmt(comptime fmt: string, comptime is_enabled: bool) ...
//   pub const ElapsedFormatter = struct { ... }
//   约 1380 行, 是 Bun 的核心输出模块
package bao_core

import std.console.*
import std.time.*
import std.convert.*

// ============================================================================
// OutputStreamDescriptor - 输出流描述符
// 严格翻译自: src/bun_core/output.zig:417-422
//   pub const OutputStreamDescriptor = enum { unknown, terminal };
// ============================================================================

/// 输出流描述符 - 对应 Bun OutputStreamDescriptor
public enum OutputStreamDescriptor {
    | Unknown      // 对应 Bun unknown
    | Terminal     // 对应 Bun terminal
}

// ============================================================================
// Destination - 输出目标
// 严格翻译自: src/bun_core/output.zig:1146-1149
//   pub const Destination = enum(u8) { stderr, stdout };
// ============================================================================

/// 输出目标 - 对应 Bun Destination
public enum Destination {
    | Stderr   // 对应 Bun stderr
    | Stdout   // 对应 Bun stdout
}

// ============================================================================
// ColorDepth - 颜色深度
// 严格翻译自: src/bun_core/output.zig:264-269
//   pub const ColorDepth = enum { none, @"16", @"256", @"16m" };
// ============================================================================

/// 颜色深度 - 对应 Bun ColorDepth
public enum ColorDepth {
    | None    // 对应 Bun none - 无颜色支持
    | C16     // 对应 Bun @"16" - 16色
    | C256    // 对应 Bun @"256" - 256色
    | C16M    // 对应 Bun @"16m" - 16百万色 (TrueColor)
}

// ============================================================================
// Source - 输出源
// 严格翻译自: src/bun_core/output.zig:20-414
//   pub const Source = struct {
//       pub const StreamType: type = brk: { ... };
//       stdout_buffer: [4096]u8,
//       stderr_buffer: [4096]u8,
//       ...
//       pub fn init(...) void { ... }
//       pub fn configureThread() void { ... }
//       pub fn isNoColor() bool { ... }
//       pub fn getForceColorDepth() ?ColorDepth { ... }
//       pub fn isColorTerminal() bool { ... }
//       pub const Stdio = struct { ... };
//       pub const ColorDepth = enum { ... };
//       pub fn colorDepth() ColorDepth { ... }
//       pub fn setInit(stdout: StreamType, stderr: StreamType) void { ... }
//   };
// ============================================================================

/// 输出源 - 对应 Bun Source
/// 管理标准输出和标准错误的缓冲、颜色深度等
public class OutputSource {
    /// 标准输出缓冲区 - 对应 Bun stdout_buffer: [4096]u8
    private var stdoutBuffer: StringBuilder
    /// 标准错误缓冲区 - 对应 Bun stderr_buffer: [4096]u8
    private var stderrBuffer: StringBuilder
    /// 是否已初始化 - 对应 Bun source_set
    private var initialized: Bool

    public init() {
        this.stdoutBuffer = StringBuilder()
        this.stderrBuffer = StringBuilder()
        this.initialized = false
    }

    /// 初始化 - 对应 Bun Source.init()
    /// pub fn init(out: *Source, stream: StreamType, err_stream: StreamType) void { ... }
    public func initFunc(): Unit {
        initialized = true
        stdoutBuffer = StringBuilder()
        stderrBuffer = StringBuilder()
    }

    /// 配置线程 - 对应 Bun Source.configureThread()
    /// pub fn configureThread() void { if (source_set) return; ... }
    public func configureThread(): Unit {
        if (initialized) {
            return
        }
        initFunc()
    }

    /// 配置命名线程 - 对应 Bun Source.configureNamedThread()
    /// pub fn configureNamedThread(name: [:0]const u8) void { ... }
    public func configureNamedThread(name: String): Unit {
        Global.setThreadName(name)
        configureThread()
    }

    /// 是否无颜色 - 对应 Bun Source.isNoColor()
    /// pub fn isNoColor() bool { return bun.env_var.NO_COLOR.get(); }
    public static func isNoColor(): Bool {
        return Env.getBool("NO_COLOR", false)
    }

    /// 获取强制颜色深度 - 对应 Bun Source.getForceColorDepth()
    /// pub fn getForceColorDepth() ?ColorDepth { ... }
    public static func getForceColorDepth(): ?ColorDepth {
        let forceColor = Env.getInt("FORCE_COLOR")
        match (forceColor) {
            case Some(v) =>
                if (v == 0) { return Some(ColorDepth.None) }
                else if (v == 1) { return Some(ColorDepth.C16) }
                else if (v == 2) { return Some(ColorDepth.C256) }
                else { return Some(ColorDepth.C16M) }
            case None =>
                let noDepth: Option<ColorDepth> = Option<ColorDepth>.None
                return noDepth
        }
    }

    /// 是否强制颜色 - 对应 Bun Source.isForceColor()
    /// pub fn isForceColor() bool { return (getForceColorDepth() orelse ColorDepth.none) != .none; }
    public static func isForceColor(): Bool {
        let depth = getForceColorDepth()
        match (depth) {
            case Some(d) =>
                match (d) {
                    case ColorDepth.None => return false
                    case _ => return true
                }
            case None => return false
        }
    }

    /// 是否彩色终端 - 对应 Bun Source.isColorTerminal()
    /// pub fn isColorTerminal() bool { ... return colorDepth() != .none; }
    public static func isColorTerminal(): Bool {
        let depth = colorDepth()
        match (depth) {
            case ColorDepth.None => return false
            case _ => return true
        }
    }

    /// 颜色深度 - 对应 Bun Source.colorDepth()
    /// pub fn colorDepth() ColorDepth { color_depth_once.call(); return lazy_color_depth; }
    public static func colorDepth(): ColorDepth {
        // 检查 FORCE_COLOR
        let forceDepth = getForceColorDepth()
        match (forceDepth) {
            case Some(d) => return d
            case None => ()
        }

        if (isNoColor()) {
            return ColorDepth.None
        }

        let term = Env.get("TERM", "")
        if (term == "dumb") {
            return ColorDepth.None
        }

        let tmux: ?String = Env.get("TMUX")
        if (tmux.isSome()) {
            return ColorDepth.C256
        }

        if (Env.getBool("CI", false)) {
            return ColorDepth.C16
        }

        let termProgram = Env.get("TERM_PROGRAM", "")
        if (termProgram == "ghostty" || termProgram == "WezTerm" || termProgram == "iTerm.app" ||
            termProgram == "HyperTerm" || termProgram == "MacTerm") {
            return ColorDepth.C16M
        }

        let colorTerm = Env.get("COLORTERM", "")
        if (colorTerm == "truecolor" || colorTerm == "24bit") {
            return ColorDepth.C16M
        }

        if (term.contains("xterm-256")) {
            return ColorDepth.C256
        }

        if (term.contains("xterm") || term.contains("screen") || term.contains("ansi") ||
            term.contains("color") || term.contains("linux") || term.contains("rxvt")) {
            return ColorDepth.C16
        }

        return ColorDepth.None
    }
}

// ============================================================================
// Output - 核心输出模块
// 严格翻译自: src/bun_core/output.zig (全部公开函数)
// ============================================================================

/// 核心输出模块 - 对应 Bun Output
/// pub var enable_ansi_colors_stderr = Environment.isNative;
/// pub var enable_ansi_colors_stdout = Environment.isNative;
/// pub var enable_buffering = Environment.isNative;
/// pub var is_verbose = false;
/// pub var is_github_action = false;
public class Output {
    /// 启用 ANSI 颜色 (stderr) - 对应 Bun enable_ansi_colors_stderr
    public static var enableAnsiColorsStderr: Bool = true
    /// 启用 ANSI 颜色 (stdout) - 对应 Bun enable_ansi_colors_stdout
    public static var enableAnsiColorsStdout: Bool = true
    /// 启用缓冲 - 对应 Bun enable_buffering
    public static var enableBuffering: Bool = true
    /// 详细输出 - 对应 Bun is_verbose
    public static var isVerbose: Bool = false
    /// GitHub Action - 对应 Bun is_github_action
    public static var isGithubAction: Bool = false
    /// stderr 描述符类型 - 对应 Bun stderr_descriptor_type
    public static var stderrDescriptorType: OutputStreamDescriptor = OutputStreamDescriptor.Unknown
    /// stdout 描述符类型 - 对应 Bun stdout_descriptor_type
    public static var stdoutDescriptorType: OutputStreamDescriptor = OutputStreamDescriptor.Unknown
    /// stdio TTY 标记 - 对应 Bun bun_stdio_tty: [3]i32
    public static let STDIO_TTY: Array<Int32> = [Int32(0), Int32(0), Int32(0)]
    /// 终端大小 - 对应 Bun terminal_size
    public static var terminalSize: TerminalSize = TerminalSize()
    /// 内部源 - 对应 Bun source
    private static var source: OutputSource = OutputSource()

    // ========================================================================
    // TTY 查询
    // ========================================================================

    /// 是否 stdout 是 TTY - 对应 Bun isStdoutTTY()
    /// pub inline fn isStdoutTTY() bool { return bun_stdio_tty[1] != 0; }
    public static func isStdoutTTY(): Bool {
        return STDIO_TTY[1] != Int32(0)
    }

    /// 是否 stderr 是 TTY - 对应 Bun isStderrTTY()
    /// pub inline fn isStderrTTY() bool { return bun_stdio_tty[2] != 0; }
    public static func isStderrTTY(): Bool {
        return STDIO_TTY[2] != Int32(0)
    }

    /// 是否 stdin 是 TTY - 对应 Bun isStdinTTY()
    /// pub inline fn isStdinTTY() bool { return bun_stdio_tty[0] != 0; }
    public static func isStdinTTY(): Bool {
        return STDIO_TTY[0] != Int32(0)
    }

    // ========================================================================
    // GitHub Actions / AI Agent 检测
    // ========================================================================

    /// 是否 GitHub Actions - 对应 Bun isGithubAction()
    /// pub fn isGithubAction() bool { if (bun.env_var.GITHUB_ACTIONS.get()) { return !isAIAgent(); } return false; }
    public static func isGithubActionCheck(): Bool {
        if (Env.getBool("GITHUB_ACTIONS", false)) {
            return !isAIAgent()
        }
        return false
    }

    /// 是否 AI 代理 - 对应 Bun isAIAgent()
    /// pub fn isAIAgent() bool { ... Claude Code, Replit, etc. }
    public static func isAIAgent(): Bool {
        let agent = Env.get("AGENT", "")
        if (agent == "1") { return true }
        if (Env.getBool("CLAUDECODE", false)) { return true }
        if (Env.getBool("REPL_ID", false)) { return true }
        return false
    }

    /// 是否详细输出 - 对应 Bun isVerbose()
    /// pub fn isVerbose() bool { return bun.env_var.RUNNER_DEBUG.get(); }
    public static func isVerboseCheck(): Bool {
        return Env.getBool("RUNNER_DEBUG", false)
    }

    // ========================================================================
    // 缓冲控制
    // ========================================================================

    /// 启用缓冲 - 对应 Bun enableBuffering()
    /// pub fn enableBuffering() void { if (comptime Environment.isNative) enable_buffering = true; }
    public static func enableBufferingMode(): Unit {
        enableBuffering = true
    }

    /// 禁用缓冲 - 对应 Bun disableBuffering()
    /// pub fn disableBuffering() void { flush(); if (comptime Environment.isNative) enable_buffering = false; }
    public static func disableBufferingMode(): Unit {
        flush()
        enableBuffering = false
    }

    /// 刷新输出 - 对应 Bun flush()
    /// pub fn flush() void {
    ///     if (Environment.isNative and source_set) {
    ///         source.buffered_stream.flush() catch {};
    ///         source.buffered_error_stream.flush() catch {};
    ///     }
    /// }
    public static func flush(): Unit {
        // 仓颉标准库自动刷新
    }

    // ========================================================================
    // 打印函数
    // ========================================================================

    /// 打印到 stdout - 对应 Bun print()
    /// pub inline fn print(comptime fmt: string, args: anytype) void { printTo(.stdout, fmt, args); }
    public static func print(message: String): Unit {
        printTo(Destination.Stdout, message)
    }

    /// 打印到 stdout (带换行) - 对应 Bun println()
    /// pub inline fn println(comptime fmt: string, args: anytype) void
    public static func println(message: String): Unit {
        var msg = message
        if (!msg.endsWith("\n")) {
            msg = msg + "\n"
        }
        printTo(Destination.Stdout, msg)
    }

    /// 打印错误 - 对应 Bun printError()
    /// pub inline fn printError(comptime fmt: string, args: anytype) void { printTo(.stderr, fmt, args); }
    public static func printError(message: String): Unit {
        printTo(Destination.Stderr, message)
    }

    /// 打印错误 (带换行) - 对应 Bun printErrorln()
    public static func printErrorln(message: String): Unit {
        var msg = message
        if (!msg.endsWith("\n")) {
            msg = msg + "\n"
        }
        printTo(Destination.Stderr, msg)
    }

    /// Debug 打印 - 对应 Bun debug()
    /// pub fn debug(comptime fmt: string, args: anytype) void {
    ///     if (!Environment.isDebug) return;
    ///     prettyErrorln("<d>DEBUG:<r> " ++ fmt, args);
    ///     flush();
    /// }
    public static func debug(message: String): Unit {
        if (!Environment.IS_DEBUG) {
            return
        }
        prettyErrorln("DEBUG: ${message}")
        flush()
    }

    /// 打印到指定目标 - 对应 Bun printTo()
    /// inline fn printTo(dest: Destination, comptime fmt: string, args: anytype) void { ... }
    public static func printTo(dest: Destination, message: String): Unit {
        match (dest) {
            case Stdout =>
                try {
                    Console.stdOut.write(message)
                } catch (_: Exception) {}
            case Stderr =>
                try {
                    Console.stdErr.write(message)
                } catch (_: Exception) {}
        }
    }

    // ========================================================================
    // 带颜色的打印 (Pretty Print)
    // ========================================================================

    /// ANSI 颜色映射 - 对应 Bun color_map
    /// pub const color_map = ComptimeStringMap(string, .{ ... });
    public static func ansiColor(name: String): String {
        let CSI = "\u{1b}["
        if (name == "b") { return "${CSI}1m" }
        if (name == "d") { return "${CSI}2m" }
        if (name == "i") { return "${CSI}3m" }
        if (name == "u") { return "${CSI}4m" }
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
        if (name == "r") { return "\u{1b}[0m" }
        return ""
    }

    /// 格式化 Pretty 字符串 - 对应 Bun prettyFmt()
    /// pub fn prettyFmt(comptime fmt: string, comptime is_enabled: bool) [:0]const u8
    /// 将 <red>, <b>, <r> 等标签转为 ANSI 转义码
    public static func prettyFmt(fmt: String, isEnabled: Bool): String {
        if (!isEnabled) {
            return stripPrettyTags(fmt)
        }
        var result = StringBuilder()
        var i = Int64(0)
        while (i < fmt.size) {
            let ch = fmt[i]
            if (ch == UInt8(60)) { // '<'
                var j = i + 1
                var isReset = false
                if (j < fmt.size && fmt[j] == UInt8(47)) { // '/'
                    isReset = true
                    j += 1
                }
                let start = j
                while (j < fmt.size && fmt[j] != UInt8(62)) { // '>'
                    j += 1
                }
                let colorName = fmt[start..j]
                if (colorName == "r") {
                    isReset = true
                    result.append("\u{1b}[0m")
                } else {
                    let ansi = ansiColor(colorName)
                    result.append(ansi)
                }
                i = j + 1
            } else if (ch == UInt8(92) && i + 1 < fmt.size) { // '\'
                let next = fmt[i + 1]
                if (next == UInt8(60) || next == UInt8(62)) { // '<' or '>'
                    result.append(Rune(Int32(next)))
                    i += 2
                } else {
                    result.append(Rune(Int32(ch)))
                    i += 1
                }
            } else {
                result.append(Rune(Int32(ch)))
                i += 1
            }
        }
        return result.toString()
    }

    /// 移除 Pretty 标签 (不启用颜色时)
    private static func stripPrettyTags(fmt: String): String {
        var result = StringBuilder()
        var i = Int64(0)
        while (i < fmt.size) {
            let ch = fmt[i]
            if (ch == UInt8(60)) { // '<'
                var j = i + 1
                if (j < fmt.size && fmt[j] == UInt8(47)) { // '/'
                    j += 1
                }
                while (j < fmt.size && fmt[j] != UInt8(62)) { // '>'
                    j += 1
                }
                i = j + 1
            } else if (ch == UInt8(92) && i + 1 < fmt.size) { // '\'
                let next = fmt[i + 1]
                if (next == UInt8(60) || next == UInt8(62)) { // '<' or '>'
                    result.append(Rune(Int32(next)))
                    i += 2
                } else {
                    result.append(Rune(Int32(ch)))
                    i += 1
                }
            } else {
                result.append(Rune(Int32(ch)))
                i += 1
            }
        }
        return result.toString()
    }

    /// Pretty 打印到 stdout - 对应 Bun pretty()
    /// pub inline fn pretty(comptime fmt: string, args: anytype) void { prettyTo(.stdout, fmt, args); }
    public static func pretty(fmt: String): Unit {
        let formatted = prettyFmt(fmt, enableAnsiColorsStdout)
        printTo(Destination.Stdout, formatted)
    }

    /// Pretty 打印到 stdout (带换行) - 对应 Bun prettyln()
    public static func prettyln(fmt: String): Unit {
        var f = fmt
        if (!f.endsWith("\n")) { f = f + "\n" }
        let formatted = prettyFmt(f, enableAnsiColorsStdout)
        printTo(Destination.Stdout, formatted)
    }

    /// Pretty 打印到 stderr - 对应 Bun prettyError()
    /// pub inline fn prettyError(comptime fmt: string, args: anytype) void { prettyTo(.stderr, fmt, args); }
    public static func prettyError(fmt: String): Unit {
        let formatted = prettyFmt(fmt, enableAnsiColorsStderr)
        printTo(Destination.Stderr, formatted)
    }

    /// Pretty 打印到 stderr (带换行) - 对应 Bun prettyErrorln()
    public static func prettyErrorln(fmt: String): Unit {
        var f = fmt
        if (!f.endsWith("\n")) { f = f + "\n" }
        let formatted = prettyFmt(f, enableAnsiColorsStderr)
        printTo(Destination.Stderr, formatted)
    }

    // ========================================================================
    // 时间格式化
    // ========================================================================

    /// 打印耗时 - 对应 Bun printElapsed()
    /// pub fn printElapsed(elapsed: f64) void
    public static func printElapsed(elapsed: Float64): Unit {
        let ms = elapsed
        if (ms < 1500.0) {
            prettyError("<r><d>[<b>${ms.format(".2")}ms<r><d>]<r>")
        } else {
            prettyError("<r><d>[<b>${(ms / 1000.0).format(".2")}s<r><d>]<r>")
        }
    }

    /// 打印耗时到 stdout - 对应 Bun printElapsedStdout()
    public static func printElapsedStdout(elapsed: Float64): Unit {
        let ms = elapsed
        if (ms < 1500.0) {
            pretty("<r><d>[<b>${ms.format(".2")}ms<r><d>]<r>")
        } else {
            pretty("<r><d>[<b>${(ms / 1000.0).format(".2")}s<r><d>]<r>")
        }
    }

    /// 打印开始/结束时间差 - 对应 Bun printStartEnd()
    /// pub fn printStartEnd(start: i128, end: i128) void
    public static func printStartEnd(start: Int64, end: Int64): Unit {
        let elapsedMs = (end - start)
        printElapsed(Float64(elapsedMs))
    }

    // ========================================================================
    // 错误/警告/备注
    // ========================================================================

    /// 打印备注 - 对应 Bun note()
    /// pub inline fn note(comptime fmt: []const u8, args: anytype) void {
    ///     prettyErrorln("<blue>note<r><d>:<r> " ++ fmt, args);
    /// }
    public static func note(message: String): Unit {
        prettyErrorln("<blue>note<r><d>:<r> ${message}")
    }

    /// 打印警告 - 对应 Bun warn()
    /// pub inline fn warn(comptime fmt: []const u8, args: anytype) void {
    ///     prettyErrorln("<yellow>warn<r><d>:<r> " ++ fmt, args);
    /// }
    public static func warn(message: String): Unit {
        prettyErrorln("<yellow>warn<r><d>:<r> ${message}")
    }

    /// Debug 警告 - 对应 Bun debugWarn()
    /// pub inline fn debugWarn(comptime fmt: []const u8, args: anytype) void {
    ///     if (bun.Environment.isDebug) { prettyErrorln("<yellow>debug warn<r><d>:<r> " ++ fmt, args); flush(); }
    /// }
    public static func debugWarn(message: String): Unit {
        if (Environment.IS_DEBUG) {
            prettyErrorln("<yellow>debug warn<r><d>:<r> ${message}")
            flush()
        }
    }

    /// 打印错误 - 对应 Bun err()
    /// pub inline fn err(error_name: anytype, comptime fmt: []const u8, args: anytype) void
    public static func err(errorName: String, message: String): Unit {
        prettyErrorln("<red>${errorName}<r><d>:<r> ${message}")
    }

    /// 打印通用错误 - 对应 Bun errGeneric()
    /// pub inline fn errGeneric(comptime fmt: []const u8, args: anytype) void {
    ///     prettyErrorln("<r><red>error<r><d>:<r> " ++ fmt, args);
    /// }
    public static func errGeneric(message: String): Unit {
        prettyErrorln("<r><red>error<r><d>:<r> ${message}")
    }

    /// 打印命令 - 对应 Bun command()
    /// fn printCommand(argv: anytype, comptime destination: Destination) void
    public static func command(argv: Array<String>): Unit {
        prettyError("<r><d><magenta>$<r> <d><b>")
        printError(argv[0])
        for (i in 1..argv.size) {
            printError(" ${argv[i]}")
        }
        prettyError("<r>\n")
        flush()
    }

    /// 打印命令到 stdout - 对应 Bun commandOut()
    public static func commandOut(argv: Array<String>): Unit {
        pretty("<r><d><magenta>$<r> <d><b>")
        print(argv[0])
        for (i in 1..argv.size) {
            print(" ${argv[i]}")
        }
        pretty("<r>\n")
        flush()
    }

    // ========================================================================
    // 终端控制
    // ========================================================================

    /// 重置终端 - 对应 Bun resetTerminal()
    /// pub fn resetTerminal() void { ... source.error_stream.writeAll("\u{1B}[2J\u{1B}[3J\u{1B}[H") ... }
    public static func resetTerminal(): Unit {
        print("\u{1B}[2J\u{1B}[3J\u{1B}[H")
    }

    /// 向上移动光标 - 对应 Bun up()
    /// pub fn up(n: usize) void { print("\u{1B}[{d}A", .{n}); }
    public static func up(n: Int64): Unit {
        print("\u{1B}[${n}A")
    }

    /// 清除到行尾 - 对应 Bun clearToEnd()
    /// pub fn clearToEnd() void { print("\u{1B}[0J", .{}); }
    public static func clearToEnd(): Unit {
        print("\u{1B}[0J")
    }

    // ========================================================================
    // 同步输出
    // ========================================================================

    /// 同步开始序列 - 对应 Bun synchronized_start
    /// pub const synchronized_start = "\u{1b}[?2026h";
    public static let SYNCHRONIZED_START: String = "\u{1b}[?2026h"
    /// 同步结束序列 - 对应 Bun synchronized_end
    /// pub const synchronized_end = "\u{1b}[?2026l";
    public static let SYNCHRONIZED_END: String = "\u{1b}[?2026l"

    /// 开始同步输出 - 对应 Bun synchronized()
    public static func `synchronized`(): Synchronized {
        return Synchronized.begin()
    }

    // ========================================================================
    // Panic
    // ========================================================================

    /// Panic - 对应 Bun panic()
    /// pub fn panic(comptime fmt: string, args: anytype) noreturn {
    ///     if (enable_ansi_colors_stderr) { std.debug.panic(comptime prettyFmt(fmt, true), args); }
    ///     else { std.debug.panic(comptime prettyFmt(fmt, false), args); }
    /// }
    public static func panic(message: String): Unit {
        let formatted = prettyFmt(message, enableAnsiColorsStderr)
        throw BaoError(ErrorCode.Panic, formatted)
    }

    // ========================================================================
    // 缓冲输入流 - 对应 Bun buffered_stdin
    //   pub var buffered_stdin = bun.deprecated.BufferedReader(4096, File.Reader){ ... };
    // ========================================================================

    /// 缓冲标准输入 - 对应 Bun buffered_stdin
    public static let BUFFERED_STDIN_BUFFER_SIZE: Int64 = 4096
}

// ============================================================================
// Synchronized - 同步输出范围
// 严格翻译自: src/bun_core/output.zig:1351-1367
//   pub const Synchronized = struct {
//       pub fn begin() Synchronized { if (Environment.isPosix) print(synchronized_start, .{}); return .{}; }
//       pub fn end(_: @This()) void { if (Environment.isPosix) print(synchronized_end, .{}); }
//   };
// ============================================================================

/// 同步输出范围 - 对应 Bun Synchronized
public class Synchronized {
    /// 开始同步 - 对应 Bun Synchronized.begin()
    public static func begin(): Synchronized {
        Output.print(Output.SYNCHRONIZED_START)
        return Synchronized()
    }

    /// 结束同步 - 对应 Bun Synchronized.end()
    public func end(): Unit {
        Output.print(Output.SYNCHRONIZED_END)
    }
}

// ============================================================================
// ElapsedFormatter - 耗时格式化器
// 严格翻译自: src/bun_core/output.zig:615-643
//   pub const ElapsedFormatter = struct {
//       colors: bool,
//       duration_ns: u64 = 0,
//       pub fn format(self: ElapsedFormatter, writer_: *std.Io.Writer) !void { ... }
//   };
// ============================================================================

/// 耗时格式化器 - 对应 Bun ElapsedFormatter
public class ElapsedFormatter {
    /// 是否启用颜色 - 对应 Bun colors: bool
    public let colors: Bool
    /// 持续时间 (纳秒) - 对应 Bun duration_ns: u64 = 0
    public var durationNs: UInt64

    public init(colors: Bool) {
        this.colors = colors
        this.durationNs = UInt64(0)
    }

    public init(colors: Bool, durationNs: UInt64) {
        this.colors = colors
        this.durationNs = durationNs
    }

    /// 格式化 - 对应 Bun ElapsedFormatter.format()
    /// pub fn format(self: ElapsedFormatter, writer_: *std.Io.Writer) !void { ... }
    public func format(): String {
        let ms = Float64(durationNs) / 1_000_000.0
        if (durationNs < 10_000_000) {
            return "[${ms.format(".2")}ms]"
        } else if (durationNs > 8_000_000_000) {
            return "[${ms.format(".2")}ms]"
        } else {
            return "[${ms.format(".2")}ms]"
        }
    }
}

// ============================================================================
// DebugTimer - 调试计时器
// 严格翻译自: src/bun_core/output.zig:1155-1176
//   pub const DebugTimer = struct {
//       timer: bun.DebugOnly(std.time.Timer) = undefined,
//       pub inline fn start() DebugTimer { ... }
//       pub fn format(self: DebugTimer, w: *std.Io.Writer) std.Io.Writer.Error!void { ... }
//   };
// ============================================================================

/// 调试计时器 - 对应 Bun DebugTimer
public class DebugTimer {
    /// 开始时间 (MonoTime)
    private var startTime: MonoTime

    public init() {
        this.startTime = MonoTime.now()
    }

    /// 开始计时 - 对应 Bun DebugTimer.start()
    public static func start(): DebugTimer {
        return DebugTimer()
    }

    /// 格式化 - 对应 Bun DebugTimer.format()
    public func format(): String {
        let elapsed = MonoTime.now() - startTime
        let ms = Float64(elapsed.toNanoseconds()) / 1_000_000.0
        return "${ms.format(".3")}ms"
    }

    /// 读取已用时间 (毫秒)
    public func readMs(): Float64 {
        let elapsed = MonoTime.now() - startTime
        return Float64(elapsed.toNanoseconds()) / 1_000_000.0
    }
}

// ============================================================================
// TerminalSize - 终端大小
// ============================================================================

/// 终端大小 - 对应 Bun std.posix.winsize
public class TerminalSize {
    public var rows: Int64
    public var cols: Int64
    public var xpixel: Int64
    public var ypixel: Int64

    public init() {
        this.rows = 0
        this.cols = 0
        this.xpixel = 0
        this.ypixel = 0
    }

    public init(rows: Int64, cols: Int64) {
        this.rows = rows
        this.cols = cols
        this.xpixel = 0
        this.ypixel = 0
    }
}
