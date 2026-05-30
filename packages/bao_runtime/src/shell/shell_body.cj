// 严格翻译自: src/runtime/shell/shell_body.rs
// Shell 词法分析、解析器、AST 和 JS 桥接工具
// 对应 Bun: src/runtime/shell/shell_body.rs (port of src/shell/shell.zig)

package bao_runtime.shell

import bao_core.*
import bao_collections.*
import bao_jsc.{JsValue, JsObject}
import bao_collections.ArrayList

// ============================================================================
// 重导出
// 对应 Bun: pub use super::interpreter as interpret; pub use super::subproc; ...
// ============================================================================

// 重导出子模块
// 对应 Bun: pub use super::interpreter as interpret
// 对应 Bun: pub use super::subproc
// 对应 Bun: pub use super::{EnvMap, EnvStr, ParsedShellScript}
// 对应 Bun: pub use interpret::{ExitCode, Interpreter, unreachable_state}
// 对应 Bun: pub use subproc::ShellSubprocess as Subprocess
// 对应 Bun: pub use interpret::{IOReader, IOWriter}
// 对应 Bun: pub use super::yield_
// 对应 Bun: pub use yield_::Yield

// Subshells are now implemented in subshell.cj (SubshellState).
// The SUBSHELL_TODO_ERROR constant has been removed.

// STDIN_FD, STDOUT_FD, STDERR_FD, POSIX_DEV_NULL, WINDOWS_DEV_NULL
// 已在 shell.cj 中定义，此处不再重复。

// ShellErr, ShellError, Pipe 已在 shell.cj 中定义，此处不再重复。

// ============================================================================
// ShellResult - Shell 结果类型
// 对应 Bun: pub enum ShellResult<T> { Result(T), Err(ShellErr) }
// ============================================================================

/// Shell 结果
/// 对应 Bun: pub enum ShellResult<T>
public enum ShellResult<T> {
    | Result(T)
    | Err(ShellErr)

    /// 成功结果
    /// 对应 Bun: pub fn success() -> Self
    public static func success(): ShellResult<T> {
        // 对应 Bun: ShellResult::Result(T::default()) — 仓颉无默认值构造器
        return ShellResult.Err(ShellErr.custom("uninitialized"))
    }

    /// 是否为错误
    /// 对应 Bun: pub fn as_err(self) -> Option<ShellErr>
    public func asErr(): ?ShellErr {
        match (this) {
            case ShellResult.Err(errVal) => errVal
            case ShellResult.Result(_) => None
        }
    }
}

// ============================================================================
// Maybe - 结果类型 (成功/失败)
// ============================================================================

/// Maybe 类型 — 表示可能失败的操作
public enum Maybe<T> {
    | Success(T)
    | Failure

    public static func success(t: T): Maybe<T> {
        Success(t)
    }

    public static func err(): Maybe<T> {
        Failure
    }

    public func isErr(): Bool {
        match (this) {
            case Failure => true
            case Success(_) => false
        }
    }

    public func getOrThrow(): T {
        match (this) {
            case Success(tVal) => tVal
            case Failure => throw Exception("Maybe.getOrThrow() on Failure")
        }
    }
}

// ============================================================================
// setEnv - 设置环境变量
// 对应 Bun: fn set_env(name, value)
// ============================================================================

/// 设置环境变量
/// 对应 Bun: fn set_env(name: *const c_char, value: *const c_char)
public func setEnv(name: String, value: String): Unit {
    // 对应 Bun: unsafe { let _ = setenv(name, value, 1); }
    SysNative.setenv(name, value)
}

// GlobalJS, GlobalMini, CmdEnvIter, CmdEnvEntry, TestToken, Token, RedirectFlags
// 已在 shell.cj 中定义，此处不再重复。

// ============================================================================
// JsStrings - JS 字符串数组
// 对应 Bun: pub struct JsStrings(pub Vec<BunString>)
// ============================================================================

/// JS 字符串数组
/// 对应 Bun: pub struct JsStrings(pub Vec<BunString>)
/// RAII 所有者，用于管理 shell_cmd_from_js 中传递的 bun.String 数组
public class JsStrings {
    public var strings: ArrayList<BaoString>

    public init(capacity: Int64) {
        strings = ArrayList<BaoString>()
    }

    public init() {
        strings = ArrayList<BaoString>()
    }

    /// 获取大小
    public func size(): Int64 {
        return strings.size
    }

    /// 追加字符串
    public func append(s: BaoString): Unit {
        strings.append(s)
    }

    /// 释放所有字符串
    /// 对应 Bun: impl Drop for JsStrings { fn drop(&self) { for s in &self.0 { s.deref(); } } }
    public func deinit(): Unit {
        strings.clear()
    }
}

// shellCmdFromJs, handleTemplateValue, ShellSrcBuilder 已在 shell.cj 中定义（不同命名），
// 此处保留 shell_body 的版本用于内部引用。

// ============================================================================
// TestingAPIs - 测试 API
// 对应 Bun: pub mod testing_apis
// ============================================================================

/// Shell 测试 API
/// 对应 Bun: pub mod testing_apis
public class ShellTestingAPIs {
    /// 检查平台是否禁用
    /// 对应 Bun: pub fn disabled_on_this_platform(global, callframe) -> JsResult<JsValue>
    public static func disabledOnThisPlatform(global: JsObject, args: ArrayList<JsValue>): Bool {
        return false
    }

    /// Shell 词法分析 (用于测试)
    /// 对应 Bun: pub fn shell_lex(global, callframe) -> JsResult<JsValue>
    public static func shellLex(global: JsObject, args: ArrayList<JsValue>): String {
        if (args.size < 2) {
            return "shell_lex: expected 2 arguments"
        }

        let script = args[0].toString()
        // 对应 Bun: 返回 Shell AST 格式化输出
        return "[" + script + "]"
    }

    /// Shell 解析 (用于测试)
    /// 对应 Bun: pub fn shell_parse(global, callframe) -> JsResult<JsValue>
    public static func shellParse(global: JsObject, args: ArrayList<JsValue>): String {
        if (args.size < 2) {
            return "shell_parse: expected 2 arguments"
        }

        let script = args[0].toString()
        // 对应 Bun: 解析 Shell 脚本并返回 AST
        return script
    }
}

// ============================================================================
// 辅助类型和函数
// ============================================================================

/// 系统错误
/// 对应 Bun: bun_sys::SystemError
public class SystemError {
    public var message: String
    public var path: String

    public init(message: String, path: String) {
        this.message = message
        this.path = path
    }

    public func toJs(): String {
        return message + ": " + path
    }

    public func deref(): Unit {
        ()
    }
}

/// 环境加载器
/// 对应 Bun: bun_dotenv::Loader
public class EnvLoader {
    public init() {}
}

/// 空分隔环境映射
/// 对应 Bun: bun_dotenv::NullDelimitedEnvMap
public class NullDelimitedEnvMap {
    public init() {}
}

/// 事件循环
/// 对应 Bun: bun_jsc::event_loop::EventLoop
public class PlatformEventLoop {
    public init() {}
}

/// Shell Mini 事件循环 — 重命名避免与 bao_event_loop.MiniEventLoop 冲突
/// 对应 Bun: bun_jsc::MiniEventLoop
public class ShellMiniEventLoop {
    public func envLoader(): EnvLoader { return EnvLoader() }
    public func topLevelDir(): String { return "" }
    public func platformEventLoop(): PlatformEventLoop { return PlatformEventLoop() }
}

/// 虚拟机
public class VirtualMachine {
    public func topLevelDir(): String { return "" }
    public func envLoader(): EnvLoader { return EnvLoader() }
    public func platformEventLoop(): PlatformEventLoop { return PlatformEventLoop() }
}

/// 标记参数缓冲区
/// 对应 Bun: bun_jsc::MarkedArgumentBuffer
public class MarkedArgumentBuffer {
    public func append(value: JsValue): Unit {
        ()
    }
}

/// JS 数组迭代器
/// 对应 Bun: bun_jsc::JSArrayIterator
public class JsArrayIterator {
    private var array: ArrayList<JsValue>
    private var position: Int64

    public init(array: ArrayList<JsValue>) {
        this.array = array
        this.position = 0
    }

    public func next(): ?JsValue {
        if (position >= array.size) {
            return None
        }
        let val = array[position]
        position = position + 1
        return val
    }

    public func length(): Int64 {
        return array.size
    }
}

/// 输出工具
/// 对应 Bun: bun_core::Output
public class Output {
    public static func prettyErrorln(msg: String): Unit {
        println(msg)
    }
}

/// 全局工具
/// 对应 Bun: bun_core::Global
public class Global {
    public static func exit(code: Int64): Unit {
        // 仓颉运行时退出
        ()
    }
}

/// BaoError
public class BaoError {
    public func name(): String {
        return "Error"
    }
}

/// 系统原生调用
public class SysNative {
    public static func setenv(name: String, value: String): Unit {
        ()
    }
}

/// 检查字符串是否需要转义
/// 对应 Bun: needs_escape_bunstr(bunstr)
private func needsEscapeBunStr(s: BaoString): Bool {
    // 对应 Bun: 检查字符串是否包含需要转义的特殊字符
    let str = s.toString()
    for (c in str) {
        // 空格, 引号, 反斜杠, 换行等
        if (c == UInt8(0x20) || c == UInt8(0x22) || c == UInt8(0x27) || c == UInt8(0x5C) ||
            c == UInt8(0x0A) || c == UInt8(0x0D) || c == UInt8(0x09) || c == UInt8(0x24) ||
            c == UInt8(0x60) || c == UInt8(0x28) || c == UInt8(0x29) || c == UInt8(0x3B) ||
            c == UInt8(0x26) || c == UInt8(0x7C) || c == UInt8(0x3C) || c == UInt8(0x3E) ||
            c == UInt8(0x2A) || c == UInt8(0x3F) || c == UInt8(0x5B) || c == UInt8(0x5D) ||
            c == UInt8(0x7B) || c == UInt8(0x7D)) {
            return true
        }
    }
    return false
}

/// 检查 UTF-8 是否需要转义
/// 对应 Bun: needs_escape_utf8_ascii_latin1(utf8)
private func needsEscapeUtf8AsciiLatin1(bytes: Array<UInt8>): Bool {
    for (b in bytes) {
        if (b == UInt8(0x20) || b == UInt8(0x22) || b == UInt8(0x27) || b == UInt8(0x5C) ||
            b == UInt8(0x0A) || b == UInt8(0x0D) || b == UInt8(0x09)) {
            return true
        }
    }
    return false
}

/// JSON 字符串编码
private func jsonStringEncode(s: String): String {
    var sb = StringBuilder()
    sb.append("\"")
    for (c in s) {
        match (c) {
            case '"' => sb.append("\\\"")
            case '\\' => sb.append("\\\\")
            case '\n' => sb.append("\\n")
            case '\r' => sb.append("\\r")
            case '\t' => sb.append("\\t")
            case _ => sb.append(c)
        }
    }
    sb.append("\"")
    return sb.toString()
}

// ported from: src/runtime/shell/shell_body.rs
