// 严格翻译自: src/bun_core/output.zig:221-262 (Source.Stdio)
//   pub const Stdio = struct {
//       extern "c" var bun_is_stdio_null: [3]i32;
//       pub fn isStderrNull() bool { ... }
//       pub fn isStdoutNull() bool { ... }
//       pub fn isStdinNull() bool { ... }
//       pub extern "c" fn bun_initialize_process() void;
//       pub fn init() void { ... }
//       pub extern "c" fn bun_restore_stdio() void;
//       pub fn restore() void { ... }
//   };
//
// 也翻译自: src/bun_core/output.rs:697-761 (stdio module)
//   pub mod stdio { ... }
package bao_output

import bao_core.*
import bao_core.Output
import bao_core.OutputSource
import bao_core.Environment

import std.console.*
import std.env.*

// ============================================================================
// C FFI 声明 - isatty 用于检测 fd 是否为终端
// ============================================================================

@C
foreign func isatty(fd: Int32): Int32

// ============================================================================
// Stdio - 标准 I/O 管理
// 严格翻译自: src/bun_core/output.zig:221-262 + src/bun_core/output.rs:697-761
//   pub const Stdio = struct { ... }
// ============================================================================

/// 标准 I/O 管理 - 对应 Bun Output.Source.Stdio
/// pub const Stdio = struct {
///     extern "c" var bun_is_stdio_null: [3]i32;
///     pub fn isStderrNull() bool { ... }
///     pub fn init() void { ... }
///     pub fn restore() void { ... }
/// };
public class Stdio {
    /// stdio null 标记 - 对应 Bun bun_is_stdio_null: [3]i32
    /// [0]=stdin, [1]=stdout, [2]=stderr, 1 表示 null
    private static var stdioNull: Array<Bool> = [false, false, false]

    /// 是否 stderr 为 null - 对应 Bun Stdio.isStderrNull()
    /// pub fn isStderrNull() bool { return bun_is_stdio_null[2] == 1; }
    public static func isStderrNull(): Bool {
        return stdioNull[2]
    }

    /// 是否 stdout 为 null - 对应 Bun Stdio.isStdoutNull()
    /// pub fn isStdoutNull() bool { return bun_is_stdio_null[1] == 1; }
    public static func isStdoutNull(): Bool {
        return stdioNull[1]
    }

    /// 是否 stdin 为 null - 对应 Bun Stdio.isStdinNull()
    /// pub fn isStdinNull() bool { return bun_is_stdio_null[0] == 1; }
    public static func isStdinNull(): Bool {
        return stdioNull[0]
    }

    /// 初始化 - 对应 Bun Stdio.init()
    /// pub fn init() void {
    ///     bun_initialize_process();
    ///     const stdout = bun.sys.File.from(std.fs.File.stdout());
    ///     const stderr = bun.sys.File.from(std.fs.File.stderr());
    ///     Source.setInit(stdout, stderr);
    /// }
    public static func `init`(): Unit {
        // 仓颉中标准流自动初始化, 这里只设置 TTY 检测和颜色配置
        // 使用 isatty() 检测 fd 是否连接到终端:
        //   stdout = fd 1, stderr = fd 2, stdin = fd 0
        let isStdoutTty = unsafe { isatty(Int32(1)) } != Int32(0)
        let isStderrTty = unsafe { isatty(Int32(2)) } != Int32(0)
        let isStdinTty = unsafe { isatty(Int32(0)) } != Int32(0)

        if (isStdinTty) {
            Output.STDIO_TTY[0] = Int32(1)
        }
        if (isStdoutTty) {
            Output.STDIO_TTY[1] = Int32(1)
            Output.stdoutDescriptorType = OutputStreamDescriptor.Terminal
        }
        if (isStderrTty) {
            Output.STDIO_TTY[2] = Int32(1)
            Output.stderrDescriptorType = OutputStreamDescriptor.Terminal
        }

        // 颜色检测逻辑 - 对应 Bun Source.setInit 中的颜色逻辑
        var enableColor: ?Bool = Option<Bool>.None
        if (OutputSource.isForceColor()) {
            enableColor = Option<Bool>.Some(true)
        } else if (OutputSource.isNoColor()) {
            enableColor = Option<Bool>.Some(false)
        } else if (OutputSource.isColorTerminal() && (isStdoutTty || isStderrTty)) {
            enableColor = Option<Bool>.Some(true)
        }

        match (enableColor) {
            case Some(c) =>
                Output.enableAnsiColorsStdout = c
                Output.enableAnsiColorsStderr = c
            case None =>
                Output.enableAnsiColorsStdout = isStdoutTty
                Output.enableAnsiColorsStderr = isStderrTty
        }
    }

    /// 恢复 - 对应 Bun Stdio.restore()
    /// pub fn restore() void { bun_restore_stdio(); }
    public static func restore(): Unit {
        // 仓颉中标准流恢复由运行时自动处理
        // 此处为空操作, 保持接口一致性
    }
}

// ============================================================================
// SourceStdio - 对应 Bun output::source::stdio 模块 (Rust)
// 翻译自: src/bun_core/output.rs:260-267
//   pub mod source {
//       pub mod stdio {
//           pub fn restore() { crate::output::stdio::restore(); }
//       }
//   }
// ============================================================================

/// Source.Stdio 恢复别名 - 对应 Bun Output.Source.Stdio.restore
public class SourceStdio {
    /// 恢复标准 I/O - 委托给 Stdio.restore()
    public static func restore(): Unit {
        Stdio.restore()
    }
}
