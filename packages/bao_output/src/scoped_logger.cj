// 严格翻译自: src/bun_core/output.rs:1490-1731
//   pub type LogFunction = fn(fmt::Arguments<'_>);
//   pub enum Visibility { Hidden, Visible }
//   pub struct ScopedLogger { ... }
//   declare_scope! / scoped_log! / define_scoped_log! macros
//
// 也翻译自: src/bun_core/output.zig:810-936
//   pub const Visibility = enum { hidden, visible };
//   pub fn Scoped(comptime tag, comptime visibility) type { ... }
//   fn ScopedLogger(comptime tagname, comptime visibility) type { ... }
package bao_output

import bao_core.*
import bao_core.Output
import bao_core.Environment

import std.console.*
import std.sync.*
import std.env.*

// ============================================================================
// Visibility - 作用域可见性
// 严格翻译自: src/bun_core/output.zig:812-822 + src/bun_core/output.rs:1499-1516
//   pub const Visibility = enum {
//       hidden,
//       visible,
//       pub fn visibleIf(condition: bool) Visibility { ... }
//   };
// ============================================================================

/// 作用域可见性 - 对应 Bun Visibility
/// pub const Visibility = enum { hidden, visible };
public enum Visibility {
    | Hidden     // 对应 Bun hidden - 默认隐藏日志
    | Visible    // 对应 Bun visible - 默认显示日志

    /// 条件可见 - 对应 Bun Visibility.visibleIf()
    /// pub fn visibleIf(condition: bool) Visibility {
    ///     return if (condition) .visible else .hidden;
    /// }
    public static func visibleIf(condition: Bool): Visibility {
        if (condition) {
            return Visible
        } else {
            return Hidden
        }
    }
}

// ============================================================================
// ScopedLogger - 作用域调试日志器
// 严格翻译自: src/bun_core/output.rs:1518-1635
//   pub struct ScopedLogger {
//       pub tagname: &'static str,
//       really_disable: AtomicBool,
//       is_visible_once: std::sync::Once,
//       lock: Mutex<()>,
//       out_set: AtomicBool,
//   }
//
// 也翻译自: src/bun_core/output.zig:840-936
//   fn ScopedLogger(comptime tagname: []const u8, comptime visibility: Visibility) type {
//       return struct {
//           var really_disable = std.atomic.Value(bool).init(visibility == .hidden);
//           var lock = bun.Mutex{};
//           var is_visible_once = std.once(evaluateIsVisible);
//           pub fn isVisible() bool { ... }
//           pub fn log(comptime fmt: string, args: anytype) void { ... }
//       };
//   }
// ============================================================================

/// 作用域调试日志器 - 对应 Bun ScopedLogger
/// pub struct ScopedLogger { tagname, really_disable, ... }
///
/// 用于按模块/子系统控制调试日志的输出.
/// 通过环境变量 BAO_DEBUG_<TAG> 或 --debug-<tag> 命令行参数控制可见性.
public class ScopedLogger {
    /// 标签名 - 对应 Bun tagname: &'static str
    public let tagName: String
    /// 是否禁用 - 对应 Bun really_disable: AtomicBool
    private var reallyDisable: Bool
    /// 可见性 - 对应 Bun visibility
    private let visibility: Visibility
    /// 互斥锁 - 对应 Bun lock: Mutex
    private let lock: ReentrantMutex
    /// 是否已评估可见性
    private var visibilityEvaluated: Bool

    public init(tagName: String, visibility: Visibility) {
        this.tagName = tagName.toAsciiLower()
        this.visibility = visibility
        this.reallyDisable = match (visibility) {
            case Visibility.Hidden => true
            case Visibility.Visible => false
        }
        this.lock = ReentrantMutex()
        this.visibilityEvaluated = false
    }

    /// 评估可见性 - 对应 Bun ScopedLogger.evaluateIsVisible()
    /// fn evaluateIsVisible() void {
    ///     if (bun.getenvZAnyCase("BUN_DEBUG_" ++ tagname)) |val| {
    ///         really_disable.store(strings.eqlComptime(val, "0"), .monotonic);
    ///     } else if (bun.env_var.BUN_DEBUG_ALL.get()) |val| {
    ///         really_disable.store(!val, .monotonic);
    ///     } else if (bun.env_var.BUN_DEBUG_QUIET_LOGS.get()) |val| {
    ///         really_disable.store(really_disable.load(.monotonic) or val, .monotonic);
    ///     } else {
    ///         for (bun.argv) |arg| {
    ///             if (strings.eqlCaseInsensitiveASCII(arg, "--debug-" ++ tagname, true)) {
    ///                 really_disable.store(false, .monotonic); break;
    ///             }
    ///         }
    ///     }
    /// }
    private func evaluateVisibility(): Unit {
        let envKey = "BAO_DEBUG_${tagName}"

        // 检查 BAO_DEBUG_<tag> 环境变量
        // 对应 Bun: if (bun.getenvZAnyCase("BUN_DEBUG_" ++ tagname)) |val| { ... }
        let envValue = getVariable(envKey)
        match (envValue) {
            case Some(v) =>
                reallyDisable = (v == "0")
                return
            case None => ()
        }

        // 检查 BAO_DEBUG_ALL
        // 对应 Bun: else if (bun.env_var.BUN_DEBUG_ALL.get()) |val| { ... }
        let debugAll = getVariable("BAO_DEBUG_ALL")
        match (debugAll) {
            case Some(v) =>
                reallyDisable = (v == "0" || v == "false" || v == "")
                return
            case None => ()
        }

        // 检查 BAO_DEBUG_QUIET_LOGS
        // 对应 Bun: else if (bun.env_var.BUN_DEBUG_QUIET_LOGS.get()) |val| { ... }
        let quietLogs = getVariable("BAO_DEBUG_QUIET_LOGS")
        match (quietLogs) {
            case Some(v) =>
                if (v == "1" || v == "true") {
                    reallyDisable = reallyDisable || true
                }
                return
            case None => ()
        }

        // 检查命令行参数 --debug-<tag> / --debug-all
        // 对应 Bun: for (bun.argv) |arg| { if (strings.eqlCaseInsensitiveASCII(arg, "--debug-" ++ tagname, true)) { ... } }
        let args = getCommandLine()
        let debugFlag = "--debug-${tagName}"
        for (arg in args) {
            if (arg.toAsciiLower() == debugFlag || arg == "--debug-all") {
                reallyDisable = false
                return
            }
        }
    }

    /// 是否可见 - 对应 Bun ScopedLogger.isVisible()
    /// pub fn isVisible() bool {
    ///     is_visible_once.call();
    ///     return !really_disable.load(.monotonic);
    /// }
    public func isVisible(): Bool {
        if (!Environment.IS_DEBUG) {
            return false
        }
        if (!visibilityEvaluated) {
            evaluateVisibility()
            visibilityEvaluated = true
        }
        return !reallyDisable
    }

    /// 写日志 - 对应 Bun ScopedLogger.log()
    /// pub fn log(comptime fmt: string, args: anytype) void {
    ///     if (!source_set) return;
    ///     if (ScopedDebugWriter.disable_inside_log > 0) return;
    ///     if (bun.crash_handler.isPanicking()) return;
    ///     if (!isVisible()) return;
    ///     lock.lock(); defer lock.unlock();
    ///     out.print(comptime prettyFmt("<r><d>[" ++ tagname ++ "]<r> " ++ fmt, use_ansi), args) catch { ... };
    ///     out.flush() catch { ... };
    /// }
    public func log(message: String): Unit {
        if (!Environment.IS_DEBUG) {
            return
        }

        // 检查 disable_inside_log 计数器
        if (ScopedDebugWriterHelper.disableInsideLog > 0) {
            return
        }

        if (!isVisible()) {
            return
        }

        // 防止重入
        ScopedDebugWriterHelper.disableInsideLog += 1
        try {
            lock.lock()
            try {
                var msg = message
                if (!msg.endsWith("\n")) {
                    msg = msg + "\n"
                }

                let useAnsi = Output.enableAnsiColorsStdout
                let prefix = if (useAnsi) {
                    "\u{1b}[0m\u{1b}[2m[${tagName}]\u{1b}[0m "
                } else {
                    "[${tagName}] "
                }

                let fullMsg = prefix + msg
                let formatted = Output.prettyFmt(fullMsg, useAnsi)
                Output.print(formatted)
            } finally {
                lock.unlock()
            }
        } finally {
            ScopedDebugWriterHelper.disableInsideLog -= 1
        }
    }
}

// ============================================================================
// ScopedDebugWriterHelper - 作用域调试写入器辅助
// 严格翻译自: src/bun_core/output.zig:1273-1286 + src/bun_core/output.rs:2657-2694
//   pub const ScopedDebugWriter = struct {
//       pub var scoped_file_writer: File.QuietWriter = undefined;
//       pub threadlocal var disable_inside_log: isize = 0;
//   };
//   pub fn disableScopedDebugWriter() void { ScopedDebugWriter.disable_inside_log += 1; }
//   pub fn enableScopedDebugWriter() void { ScopedDebugWriter.disable_inside_log -= 1; }
// ============================================================================

/// 作用域调试写入器辅助 - 对应 Bun ScopedDebugWriter
public class ScopedDebugWriterHelper {
    /// 禁用内部日志计数 - 对应 Bun disable_inside_log: isize
    public static var disableInsideLog: Int64 = 0
}
