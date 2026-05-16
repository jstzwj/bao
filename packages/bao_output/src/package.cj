// 严格翻译自: src/output/lib.rs (Bun facade crate)
//   bun_output — thin facade over bun_core::output.
//   This crate re-exports it so downstream crates can depend on bun_output
//   without pulling all of bun_core into their public surface.
//
// 同时翻译自: src/bun_core/output.zig + src/bun_core/output.rs
//   补充 bao_core 中尚未包含的类型:
//   - ScopedLogger / Visibility (作用域调试日志)
//   - EnableBufferingScope / DisableBufferingScope (缓冲作用域)
//   - FlushGuard (刷新守卫)
//   - BufferedStdin / StdinReader (缓冲标准输入)
//   - Stdio (标准 I/O 初始化)
//   - PrettyFmt / PrettyBuf (Pretty 格式化)
//   - ErrName / SysErrInfo (错误名称 trait)
//   - Synchronized / DebugTimer / ElapsedFormatter 等
package bao_output

import bao_core.*
import bao_core.Environment
import bao_core.Global
import bao_core.Output
import bao_core.OutputSource
import bao_core.Destination
import bao_core.OutputStreamDescriptor
import bao_core.ColorDepth
import bao_core.Synchronized

import std.console.*
import std.collection.*
import std.sync.*
import std.time.*

// ============================================================================
// 重新导出 bao_core 中的 Output 类型
// 翻译自: src/output/lib.rs:27-45
//   pub use bun_core::output::{ScopedLogger, Visibility};
//   pub use bun_core::output::*;
//   pub use bun_core::{debug, debug_warn, err_generic, note, pretty, ...};
// ============================================================================

/// 输出源类型别名 - 对应 Bun Source
public type BaoOutputSource = OutputSource

/// 输出目标类型别名 - 对应 Bun Destination
public type BaoDestination = Destination

/// 输出流描述符类型别名 - 对应 Bun OutputStreamDescriptor
public type BaoDescriptorType = OutputStreamDescriptor

/// 颜色深度类型别名 - 对应 Bun ColorDepth
public type BaoColorDepth = ColorDepth

// ============================================================================
// OutputFacade - 输出门面
// 严格翻译自: src/output/lib.rs (整个 bun_output crate 的公共 API)
//   所有函数都委托给 bao_core.Output 或 bao_output 中扩展的类型
//
// Bun 的 bun_output 只做 re-export, 不添加新功能。
// 仓颉的包系统与 Rust 不同，这里用 class 提供等价的静态 API 面板。
// ============================================================================

/// 输出门面 - 对应 Bun bun_output crate 的全部公共 API
///
/// 下游包只需 import bao_output.* 即可获得所有输出功能:
///   - OutputFacade.print/println/pretty/prettyError/note/warn/err/...
///   - ScopedLogger / Visibility (作用域日志)
///   - Stdio.init/restore (标准 I/O 初始化)
///   - BufferedStdin (缓冲标准输入)
///   - enableBuffering/disableBuffering/flush (缓冲控制)
///   - prettyFmt (Pretty 格式化)
public class OutputFacade {

    // ========================================================================
    // 直接转发: 打印函数
    // 翻译自: src/output/lib.rs → bun_core::output 的 print/println 等
    // ========================================================================

    /// 打印到 stdout - 对应 Bun Output.print()
    public static func print(message: String): Unit {
        Output.print(message)
    }

    /// 打印到 stdout (带换行) - 对应 Bun Output.println()
    public static func println(message: String): Unit {
        Output.println(message)
    }

    /// 打印到 stderr - 对应 Bun Output.printError()
    public static func printError(message: String): Unit {
        Output.printError(message)
    }

    /// 打印到 stderr (带换行) - 对应 Bun Output.printErrorln()
    public static func printErrorln(message: String): Unit {
        Output.printErrorln(message)
    }

    /// Debug 打印 - 对应 Bun Output.debug()
    public static func debug(message: String): Unit {
        Output.debug(message)
    }

    /// 打印到指定目标 - 对应 Bun Output.printTo()
    public static func printTo(dest: Destination, message: String): Unit {
        Output.printTo(dest, message)
    }

    // ========================================================================
    // 直接转发: Pretty 打印
    // ========================================================================

    /// Pretty 打印到 stdout - 对应 Bun Output.pretty()
    public static func pretty(fmt: String): Unit {
        Output.pretty(fmt)
    }

    /// Pretty 打印到 stdout (带换行) - 对应 Bun Output.prettyln()
    public static func prettyln(fmt: String): Unit {
        Output.prettyln(fmt)
    }

    /// Pretty 打印到 stderr - 对应 Bun Output.prettyError()
    public static func prettyError(fmt: String): Unit {
        Output.prettyError(fmt)
    }

    /// Pretty 打印到 stderr (带换行) - 对应 Bun Output.prettyErrorln()
    public static func prettyErrorln(fmt: String): Unit {
        Output.prettyErrorln(fmt)
    }

    // ========================================================================
    // 直接转发: 错误/警告/备注
    // ========================================================================

    /// 打印备注 - 对应 Bun Output.note()
    public static func note(message: String): Unit {
        Output.note(message)
    }

    /// 打印警告 - 对应 Bun Output.warn()
    public static func warn(message: String): Unit {
        Output.warn(message)
    }

    /// Debug 警告 - 对应 Bun Output.debugWarn()
    public static func debugWarn(message: String): Unit {
        Output.debugWarn(message)
    }

    /// 打印错误 - 对应 Bun Output.err()
    public static func err(errorName: String, message: String): Unit {
        Output.err(errorName, message)
    }

    /// 打印通用错误 - 对应 Bun Output.errGeneric()
    public static func errGeneric(message: String): Unit {
        Output.errGeneric(message)
    }

    /// 打印格式化错误 - 对应 Bun Output.errFmt()
    public static func errFmt(formatter: String): Unit {
        errGeneric(formatter)
    }

    // ========================================================================
    // 直接转发: 命令打印
    // ========================================================================

    /// 打印命令 - 对应 Bun Output.command()
    public static func command(argv: Array<String>): Unit {
        Output.command(argv)
    }

    /// 打印命令到 stdout - 对应 Bun Output.commandOut()
    public static func commandOut(argv: Array<String>): Unit {
        Output.commandOut(argv)
    }

    // ========================================================================
    // 直接转发: 终端控制
    // ========================================================================

    /// 重置终端 - 对应 Bun Output.resetTerminal()
    public static func resetTerminal(): Unit {
        Output.resetTerminal()
    }

    /// 重置终端 (全部) - 对应 Bun Output.resetTerminalAll()
    public static func resetTerminalAll(): Unit {
        Output.print("\u{1B}[2J\u{1B}[3J\u{1B}[H")
        Output.printError("\u{1B}[2J\u{1B}[3J\u{1B}[H")
    }

    /// 向上移动光标 - 对应 Bun Output.up()
    public static func up(n: Int64): Unit {
        Output.up(n)
    }

    /// 清除到行尾 - 对应 Bun Output.clearToEnd()
    public static func clearToEnd(): Unit {
        Output.clearToEnd()
    }

    // ========================================================================
    // 直接转发: 时间打印
    // ========================================================================

    /// 打印耗时 - 对应 Bun Output.printElapsed()
    public static func printElapsed(elapsed: Float64): Unit {
        Output.printElapsed(elapsed)
    }

    /// 打印耗时到 stdout - 对应 Bun Output.printElapsedStdout()
    public static func printElapsedStdout(elapsed: Float64): Unit {
        Output.printElapsedStdout(elapsed)
    }

    /// 打印开始/结束时间差 - 对应 Bun Output.printStartEnd()
    public static func printStartEnd(start: Int64, end: Int64): Unit {
        Output.printStartEnd(start, end)
    }

    /// 打印开始/结束时间差到 stdout - 对应 Bun Output.printStartEndStdout()
    public static func printStartEndStdout(start: Int64, end: Int64): Unit {
        let elapsedMs = (end - start)
        Output.printElapsedStdout(Float64(elapsedMs))
    }

    // ========================================================================
    // 直接转发: 缓冲控制
    // ========================================================================

    /// 启用缓冲模式 - 对应 Bun Output.enableBuffering()
    public static func enableBufferingMode(): Unit {
        Output.enableBufferingMode()
    }

    /// 禁用缓冲模式 - 对应 Bun Output.disableBuffering()
    public static func disableBufferingMode(): Unit {
        Output.disableBufferingMode()
    }

    /// 刷新输出 - 对应 Bun Output.flush()
    public static func flush(): Unit {
        Output.flush()
    }

    /// 获取刷新守卫 - 对应 Bun Output.flushGuard()
    /// RAII guard: 在作用域结束时自动调用 flush()
    public static func flushGuard(): FlushGuard {
        return FlushGuard()
    }

    /// 获取启用缓冲作用域 - 对应 Bun Output.enableBufferingScope()
    public static func enableBufferingScope(): EnableBufferingScope {
        return EnableBufferingScope()
    }

    /// 获取禁用缓冲作用域 - 对应 Bun Output.disableBufferingScope()
    public static func disableBufferingScope(): DisableBufferingScope {
        return DisableBufferingScope()
    }

    // ========================================================================
    // 直接转发: 同步输出
    // ========================================================================

    /// 开始同步输出 - 对应 Bun Output.synchronized()
    public static func `synchronized`(): BaoSynchronized {
        return BaoSynchronized.begin()
    }

    // ========================================================================
    // 直接转发: Panic
    // ========================================================================

    /// Panic - 对应 Bun Output.panic()
    public static func panic(message: String): Unit {
        Output.panic(message)
    }

    // ========================================================================
    // 直接转发: Pretty 格式化
    // ========================================================================

    /// Pretty 格式化字符串 - 对应 Bun Output.prettyFmt()
    public static func prettyFmt(fmt: String, isEnabled: Bool): String {
        return Output.prettyFmt(fmt, isEnabled)
    }

    /// Pretty 格式化运行时 - 对应 Bun Output.prettyFmtRt()
    public static func prettyFmtRt(input: String, isEnabled: Bool): String {
        return PrettyFmtRuntime.rewrite(input, isEnabled)
    }

    /// Pretty 格式化带参数 - 对应 Bun Output.prettyFmtArgs()
    public static func prettyFmtArgs(fmt: String, isEnabled: Bool, args: Array<String>): String {
        let rewritten = PrettyFmtRuntime.rewrite(fmt, isEnabled)
        var result = rewritten
        for (i in 0..args.size) {
            let placeholder = "{}"
            let idx = result.indexOf(placeholder)
            match (idx) {
                case Some(pos) =>
                    result = result[0..pos] + args[i] + result[(pos + Int64(placeholder.size))..result.size]
                case None => ()
            }
        }
        return result
    }

    // ========================================================================
    // 直接转发: TTY / 环境
    // ========================================================================

    /// 是否 stdout 是 TTY - 对应 Bun Output.isStdoutTTY()
    public static func isStdoutTTY(): Bool {
        return Output.isStdoutTTY()
    }

    /// 是否 stderr 是 TTY - 对应 Bun Output.isStderrTTY()
    public static func isStderrTTY(): Bool {
        return Output.isStderrTTY()
    }

    /// 是否 stdin 是 TTY - 对应 Bun Output.isStdinTTY()
    public static func isStdinTTY(): Bool {
        return Output.isStdinTTY()
    }

    /// 是否 GitHub Actions - 对应 Bun Output.isGithubAction()
    public static func isGithubActionCheck(): Bool {
        return Output.isGithubActionCheck()
    }

    /// 是否 AI 代理 - 对应 Bun Output.isAIAgent()
    public static func isAIAgent(): Bool {
        return Output.isAIAgent()
    }

    /// 是否详细输出 - 对应 Bun Output.isVerbose()
    public static func isVerboseCheck(): Bool {
        return Output.isVerboseCheck()
    }

    /// 启用 ANSI 颜色 (stdout) - 对应 Bun Output.enable_ansi_colors_stdout
    public static func enableAnsiColorsStdout(): Bool {
        return Output.enableAnsiColorsStdout
    }

    /// 启用 ANSI 颜色 (stderr) - 对应 Bun Output.enable_ansi_colors_stderr
    public static func enableAnsiColorsStderr(): Bool {
        return Output.enableAnsiColorsStderr
    }

    /// 颜色深度 - 对应 Bun Output.colorDepth()
    public static func colorDepth(): ColorDepth {
        return OutputSource.colorDepth()
    }

    /// 是否无颜色 - 对应 Bun Output.isNoColor()
    public static func isNoColor(): Bool {
        return OutputSource.isNoColor()
    }

    /// 是否强制颜色 - 对应 Bun Output.isForceColor()
    public static func isForceColor(): Bool {
        return OutputSource.isForceColor()
    }

    /// 是否彩色终端 - 对应 Bun Output.isColorTerminal()
    public static func isColorTerminal(): Bool {
        return OutputSource.isColorTerminal()
    }

    // ========================================================================
    // 作用域日志 - 对应 Bun declare_scope! / scoped_log! / scope_is_visible!
    // 翻译自: src/output/lib.rs:27-34 + src/bun_core/output.rs:1490-1731
    // ========================================================================

    /// 声明作用域日志 - 对应 Bun declare_scope!(X, hidden/visible)
    /// 创建一个 ScopedLogger 实例, 可通过 scopedLog 写日志
    public static func declareScope(tagName: String, visibility: Visibility): ScopedLogger {
        return ScopedLogger(tagName, visibility)
    }

    /// 作用域日志 - 对应 Bun scoped_log!(X, "fmt", args...)
    /// 仅在 debug 构建且作用域可见时打印
    public static func scopedLog(scope: ScopedLogger, message: String): Unit {
        scope.log(message)
    }

    /// 作用域是否可见 - 对应 Bun scope_is_visible!(X)
    public static func scopeIsVisible(scope: ScopedLogger): Bool {
        return scope.isVisible()
    }

    /// 禁用作用域调试写入器 - 对应 Bun Output.disableScopedDebugWriter()
    public static func disableScopedDebugWriter(): Unit {
        ScopedDebugWriterHelper.disableInsideLog += 1
    }

    /// 启用作用域调试写入器 - 对应 Bun Output.enableScopedDebugWriter()
    public static func enableScopedDebugWriter(): Unit {
        ScopedDebugWriterHelper.disableInsideLog -= 1
    }

    // ========================================================================
    // 标准输入 - 对应 Bun Output.buffered_stdin / stdin_reader
    // ========================================================================

    /// 获取缓冲标准输入 - 对应 Bun Output.bufferedStdin()
    public static func bufferedStdin(): BufferedStdinReader {
        return BufferedStdinReader()
    }

    /// 获取标准输入读取器 - 对应 Bun Output.stdinReader()
    public static func stdinReader(): BaoStdinReader {
        return BaoStdinReader()
    }
}
