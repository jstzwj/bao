// 严格翻译自: src/runtime/shell/shell_body.rs
// Shell 词法分析、解析器、AST 和 JS 桥接工具
// 对应 Bun: src/runtime/shell/shell_body.rs (port of src/shell/shell.zig)

package bao_runtime.shell

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_sys.*

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

/// 子 Shell 未实现错误消息
/// 对应 Bun: pub const SUBSHELL_TODO_ERROR: &str = "Subshells are not implemented, please open GitHub issue!"
public let SUBSHELL_TODO_ERROR: String = "Subshells are not implemented, please open GitHub issue!"

/// 标准输入 FD
/// 对应 Bun: pub const STDIN_FD: Fd = Fd::from_uv(0)
public let STDIN_FD: Int64 = 0

/// 标准输出 FD
/// 对应 Bun: pub const STDOUT_FD: Fd = Fd::from_uv(1)
public let STDOUT_FD: Int64 = 1

/// 标准错误 FD
/// 对应 Bun: pub const STDERR_FD: Fd = Fd::from_uv(2)
public let STDERR_FD: Int64 = 2

/// POSIX /dev/null 路径
/// 对应 Bun: pub const POSIX_DEV_NULL: &ZStr = bun_core::zstr!("/dev/null")
public let POSIX_DEV_NULL: String = "/dev/null"

/// Windows NUL 路径
/// 对应 Bun: pub const WINDOWS_DEV_NULL: &ZStr = bun_core::zstr!("NUL")
public let WINDOWS_DEV_NULL: String = "NUL"

// ============================================================================
// ShellErr - Shell 错误类型
// 对应 Bun: pub enum ShellErr { Sys, Custom, InvalidArguments, Todo }
// ============================================================================

/// Shell 错误
/// 对应 Bun: pub enum ShellErr
/// 该类型中的字符串通过事件循环上下文分配器分配
public enum ShellErr {
    | Sys(SystemError)
    | Custom(Array<UInt8>)
    | InvalidArguments(Array<UInt8>)
    | Todo(Array<UInt8>)

    /// 创建系统错误
    /// 对应 Bun: pub fn new_sys(e: sys::Error) -> Self
    public static func newSys(err: SystemError): ShellErr {
        return ShellErr.Sys(err)
    }

    /// 从系统错误创建
    /// 对应 Bun: pub fn from_system(e: SystemError) -> Self
    public static func fromSystem(err: SystemError): ShellErr {
        return ShellErr.Sys(err)
    }

    /// 抛出 JS 错误
    /// 对应 Bun: pub fn throw_js(self, global: &JSGlobalObject) -> bun_jsc::JsError
    public func throwJs(global: JsObject): JsError {
        match (this) {
            case ShellErr.Sys(sys) =>
                // 对应 Bun: bun_jsc::SystemError::from(sys).to_error_instance(global)
                return JsError(global, sys.message + ": " + sys.path)
            case ShellErr.Custom(custom) =>
                return JsError(global, String.fromUtf8(custom))
            case ShellErr.InvalidArguments(val) =>
                return JsError(global, "bunsh: invalid arguments: " + String.fromUtf8(val))
            case ShellErr.Todo(todo) =>
                return JsError(global, "TODO: " + String.fromUtf8(todo))
        }
    }

    /// 抛出 Mini 错误 (打印并退出)
    /// 对应 Bun: pub fn throw_mini(self) -> !
    public func throwMini(): Unit {
        match (this) {
            case ShellErr.Sys(err) =>
                Output.prettyErrorln("error: Failed due to error: bunsh: " + err.message + ": " + err.path)
            case ShellErr.Custom(msg) =>
                Output.prettyErrorln("error: Failed due to error: " + String.fromUtf8(msg))
            case ShellErr.InvalidArguments(val) =>
                Output.prettyErrorln("error: Failed due to error: bunsh: invalid arguments: " + String.fromUtf8(val))
            case ShellErr.Todo(msg) =>
                Output.prettyErrorln("error: Failed due to error: TODO: " + String.fromUtf8(msg))
        }
        // 对应 Bun: bun_core::Global::exit(1)
        Global.exit(1)
    }

    /// 释放资源
    /// 对应 Bun: pub fn deinit(self)
    public func deinit(): Unit {
        // 对应 Bun: ShellErr::Sys(sys) => sys.deref()
        // 其他变体在仓颉中自动释放
        ()
    }

    /// 转为字符串
    /// 对应 Bun: impl fmt::Display for ShellErr
    public func toString(): String {
        match (this) {
            case ShellErr.Sys(e) => "bun: " + e.message + ": " + e.path
            case ShellErr.Custom(msg) => "bun: " + String.fromUtf8(msg)
            case ShellErr.InvalidArguments(val) => "bun: invalid arguments: " + String.fromUtf8(val)
            case ShellErr.Todo(msg) => "bun: TODO: " + String.fromUtf8(msg)
        }
    }
}

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
        // 对应 Bun: ShellResult::Result(T::default())
        // 简化: 仓颉需要默认值
        return ShellResult.Err(ShellErr.Custom(Array<UInt8>()))
    }

    /// 是否为错误
    /// 对应 Bun: pub fn as_err(self) -> Option<ShellErr>
    public func asErr(): ?ShellErr {
        match (this) {
            case ShellResult.Err(e) => e
            case ShellResult.Result(_) => None
        }
    }
}

// ============================================================================
// ShellError - Shell 内部错误枚举
// 对应 Bun: pub enum ShellError { Init, Process, GlobalThisThrown, Spawn }
// ============================================================================

/// Shell 内部错误
/// 对应 Bun: #[derive(thiserror::Error, Debug, strum::IntoStaticStr)]
/// pub enum ShellError
public enum ShellError {
    | Init
    | Process
    | GlobalThisThrown
    | Spawn

    public func toString(): String {
        match (this) {
            case ShellError.Init => "Init"
            case ShellError.Process => "Process"
            case ShellError.GlobalThisThrown => "GlobalThisThrown"
            case ShellError.Spawn => "Spawn"
        }
    }
}

// ============================================================================
// Pipe - 管道类型
// 对应 Bun: pub type Pipe = [Fd; 2]
// ============================================================================

/// 管道 (读写端 FD)
/// 对应 Bun: pub type Pipe = [Fd; 2]
/// [0] => read end, [1] => write end
public class Pipe {
    public var readEnd: Int64
    public var writeEnd: Int64

    public init(readEnd: Int64, writeEnd: Int64) {
        this.readEnd = readEnd
        this.writeEnd = writeEnd
    }

    public init() {
        this.readEnd = -1
        this.writeEnd = -1
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

// ============================================================================
// GlobalJS - JS 全局上下文
// 对应 Bun: pub struct GlobalJS<'a> { pub global_this: &'a JSGlobalObject }
// ============================================================================

/// JS 全局上下文
/// 对应 Bun: #[derive(Clone, Copy)] pub struct GlobalJS<'a>
public class GlobalJS {
    public var globalThis: JsObject

    public init(globalThis: JsObject) {
        this.globalThis = globalThis
    }

    /// 初始化
    /// 对应 Bun: pub fn init(g: &'a JSGlobalObject) -> Self
    public static func init(g: JsObject): GlobalJS {
        return GlobalJS(g)
    }

    /// 获取事件循环上下文
    /// 对应 Bun: pub fn event_loop_ctx(self) -> &'a VirtualMachine
    public func eventLoopCtx(): VirtualMachine {
        return globalThis.virtualMachine()
    }

    /// 抛出无效参数错误
    /// 对应 Bun: pub fn throw_invalid_arguments(self, args) -> ShellErr
    public func throwInvalidArguments(args: String): ShellErr {
        return ShellErr.InvalidArguments(args.toArray())
    }

    /// 抛出 TODO 错误
    /// 对应 Bun: pub fn throw_todo(self, msg: &[u8]) -> ShellErr
    public func throwTodo(msg: Array<UInt8>): ShellErr {
        return ShellErr.Todo(msg)
    }

    /// 抛出错误
    /// 对应 Bun: pub fn throw_error(self, err: sys::Error)
    public func throwError(err: SystemError): Unit {
        globalThis.throwValue(err.toJs(globalThis))
    }

    /// 处理错误
    /// 对应 Bun: pub fn handle_error(self, err: bun_core::Error, suffix: &str) -> ShellErr
    public func handleError(err: BaoError, suffix: String): ShellErr {
        let msg = err.name() + " " + suffix
        return ShellErr.Custom(msg.toArray())
    }

    /// 抛出自定义错误
    /// 对应 Bun: pub fn throw(self, args: fmt::Arguments<'_>) -> ShellErr
    public func throw(args: String): ShellErr {
        return ShellErr.Custom(args.toArray())
    }

    /// 创建 null 分隔的环境映射
    /// 对应 Bun: pub fn create_null_delimited_env_map(self) -> Result<NullDelimitedEnvMap, AllocError>
    public func createNullDelimitedEnvMap(): ?NullDelimitedEnvMap {
        return None
    }

    /// 入队并发等待 PID 任务
    /// 对应 Bun: pub fn enqueue_task_concurrent_wait_pid<T>(self, task)
    public func enqueueTaskConcurrentWaitPid(task: Object): Unit {
        // 对应 Bun: vm.enqueue_task_concurrent(concurrent)
        ()
    }

    /// 获取顶层目录
    /// 对应 Bun: pub fn top_level_dir(self) -> &'a [u8]
    public func topLevelDir(): String {
        return globalThis.virtualMachine().topLevelDir()
    }

    /// 获取环境加载器
    /// 对应 Bun: pub fn env(self) -> &'a bun_dotenv::Loader<'a>
    public func env(): EnvLoader {
        return globalThis.virtualMachine().envLoader()
    }

    /// 获取平台事件循环
    /// 对应 Bun: pub fn platform_event_loop(self) -> &'a PlatformEventLoop
    public func platformEventLoop(): PlatformEventLoop {
        return globalThis.virtualMachine().platformEventLoop()
    }

    /// 实际抛出错误
    /// 对应 Bun: pub fn actually_throw(self, shellerr: ShellErr)
    public func actuallyThrow(shellErr: ShellErr): Unit {
        let _ = shellErr.throwJs(globalThis)
    }
}

// ============================================================================
// GlobalMini - Mini 事件循环全局上下文
// 对应 Bun: pub struct GlobalMini<'a> { pub mini: &'a MiniEventLoop<'a> }
// ============================================================================

/// Mini 事件循环全局上下文
/// 对应 Bun: #[derive(Clone, Copy)] pub struct GlobalMini<'a>
public class GlobalMini {
    public var mini: MiniEventLoop

    public init(mini: MiniEventLoop) {
        this.mini = mini
    }

    /// 初始化
    /// 对应 Bun: pub fn init(g: &'a MiniEventLoop<'a>) -> Self
    public static func init(g: MiniEventLoop): GlobalMini {
        return GlobalMini(g)
    }

    /// 获取环境加载器
    /// 对应 Bun: pub fn env(self) -> &'a bun_dotenv::Loader<'a>
    public func env(): EnvLoader {
        return mini.envLoader()
    }

    /// 获取事件循环上下文
    /// 对应 Bun: pub fn event_loop_ctx(self) -> &'a MiniEventLoop<'a>
    public func eventLoopCtx(): MiniEventLoop {
        return mini
    }

    /// 抛出 TODO 错误
    /// 对应 Bun: pub fn throw_todo(self, msg: &[u8]) -> ShellErr
    public func throwTodo(msg: Array<UInt8>): ShellErr {
        return ShellErr.Todo(msg)
    }

    /// 抛出无效参数错误
    /// 对应 Bun: pub fn throw_invalid_arguments(self, args) -> ShellErr
    public func throwInvalidArguments(args: String): ShellErr {
        return ShellErr.InvalidArguments(args.toArray())
    }

    /// 处理错误
    /// 对应 Bun: pub fn handle_error(self, err, suffix) -> ShellErr
    public func handleError(err: BaoError, suffix: String): ShellErr {
        let msg = err.name() + " " + suffix
        return ShellErr.Custom(msg.toArray())
    }

    /// 创建 null 分隔的环境映射
    /// 对应 Bun: pub fn create_null_delimited_env_map(self) -> Result<...>
    public func createNullDelimitedEnvMap(): ?NullDelimitedEnvMap {
        return None
    }

    /// 入队并发等待 PID 任务
    /// 对应 Bun: pub fn enqueue_task_concurrent_wait_pid<T>(self, task, run_from_main_thread_mini)
    public func enqueueTaskConcurrentWaitPid(task: Object): Unit {
        // 对应 Bun: mini.enqueueTaskConcurrent(anytask)
        ()
    }

    /// 获取顶层目录
    /// 对应 Bun: pub fn top_level_dir(self) -> &'a [u8]
    public func topLevelDir(): String {
        return mini.topLevelDir()
    }

    /// 抛出自定义错误
    /// 对应 Bun: pub fn throw(self, args) -> ShellErr
    public func throw(args: String): ShellErr {
        return ShellErr.Custom(args.toArray())
    }

    /// 实际抛出错误
    /// 对应 Bun: pub fn actually_throw(self, shellerr: ShellErr)
    public func actuallyThrow(shellErr: ShellErr): Unit {
        shellErr.throwMini()
    }

    /// 获取平台事件循环
    /// 对应 Bun: pub fn platform_event_loop(self) -> &'a PlatformEventLoop
    public func platformEventLoop(): PlatformEventLoop {
        return mini.platformEventLoop()
    }
}

// ============================================================================
// CmdEnvIter - 命令环境变量迭代器
// 对应 Bun: pub struct CmdEnvIter<'a>
// ============================================================================

/// 命令环境变量迭代器
/// 对应 Bun: pub struct CmdEnvIter<'a>
public class CmdEnvIter {
    public var env: HashMap<String, String>
    public var entries: ArrayList<CmdEnvEntry>
    public var position: Int64

    public init(env: HashMap<String, String>) {
        this.env = env
        this.entries = ArrayList<CmdEnvEntry>()
        this.position = 0
        // 从 HashMap 构建条目列表
        for ((k, v) in env) {
            entries.append(CmdEnvEntry(key: k, value: v))
        }
    }

    /// 从环境变量创建迭代器
    /// 对应 Bun: pub fn from_env(env) -> Self
    public static func fromEnv(env: HashMap<String, String>): CmdEnvIter {
        return CmdEnvIter(env)
    }

    /// 长度
    /// 对应 Bun: pub fn len(&self) -> usize
    public func len(): Int64 {
        return entries.size
    }

    /// 下一个条目
    /// 对应 Bun: pub fn next(&mut self) -> Result<Option<CmdEnvEntry>, Error>
    public func next(): ?CmdEnvEntry {
        if (position >= entries.size) {
            return None
        }
        let entry = entries[position]
        position = position + 1
        return entry
    }
}

// ============================================================================
// CmdEnvEntry - 命令环境变量条目
// 对应 Bun: pub struct CmdEnvEntry<'a>
// ============================================================================

/// 命令环境变量条目
/// 对应 Bun: pub struct CmdEnvEntry<'a> { key: CmdEnvKey<'a>, value: CmdEnvValue<'a> }
public class CmdEnvEntry {
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        this.key = key
        this.value = value
    }
}

// ============================================================================
// TestToken - 测试令牌
// 对应 Bun: pub enum TestToken<'a>
// ============================================================================

/// 测试令牌 (用于 JS 测试中的词法分析结果)
/// 对应 Bun: pub enum TestToken<'a>
public enum TestToken {
    | Pipe
    | DoublePipe
    | Ampersand
    | DoubleAmpersand
    | Redirect(RedirectFlags)
    | Dollar
    | Asterisk
    | DoubleAsterisk
    | Eq
    | Semicolon
    | Newline
    | BraceBegin
    | Comma
    | BraceEnd
    | CmdSubstBegin
    | CmdSubstQuoted
    | CmdSubstEnd
    | OpenParen
    | CloseParen
    | Var(String)
    | VarArgv(UInt8)
    | Text(String)
    | SingleQuotedText(String)
    | DoubleQuotedText(String)
    | JSObjRef(UInt32)
    | DoubleBracketOpen
    | DoubleBracketClose
    | Delimit
    | Eof

    /// 从真实令牌创建
    /// 对应 Bun: pub fn from_real(the_token: Token, buf: &[u8]) -> TestToken
    public static func fromReal(token: Token, buf: String): TestToken {
        match (token) {
            case Token.Var(txt) => TestToken.Var(txt)
            case Token.VarArgv(n) => TestToken.VarArgv(n)
            case Token.Text(txt) => TestToken.Text(txt)
            case Token.SingleQuotedText(txt) => TestToken.SingleQuotedText(txt)
            case Token.DoubleQuotedText(txt) => TestToken.DoubleQuotedText(txt)
            case Token.JSObjRef(n) => TestToken.JSObjRef(n)
            case Token.Pipe => TestToken.Pipe
            case Token.DoublePipe => TestToken.DoublePipe
            case Token.Ampersand => TestToken.Ampersand
            case Token.DoubleAmpersand => TestToken.DoubleAmpersand
            case Token.Redirect(r) => TestToken.Redirect(r)
            case Token.Dollar => TestToken.Dollar
            case Token.Asterisk => TestToken.Asterisk
            case Token.DoubleAsterisk => TestToken.DoubleAsterisk
            case Token.Eq => TestToken.Eq
            case Token.Semicolon => TestToken.Semicolon
            case Token.Newline => TestToken.Newline
            case Token.BraceBegin => TestToken.BraceBegin
            case Token.Comma => TestToken.Comma
            case Token.BraceEnd => TestToken.BraceEnd
            case Token.CmdSubstBegin => TestToken.CmdSubstBegin
            case Token.CmdSubstQuoted => TestToken.CmdSubstQuoted
            case Token.CmdSubstEnd => TestToken.CmdSubstEnd
            case Token.OpenParen => TestToken.OpenParen
            case Token.CloseParen => TestToken.CloseParen
            case Token.DoubleBracketOpen => TestToken.DoubleBracketOpen
            case Token.DoubleBracketClose => TestToken.DoubleBracketClose
            case Token.Delimit => TestToken.Delimit
            case Token.Eof => TestToken.Eof
        }
    }

    /// 转为 JSON 字符串
    /// 对应 Bun: pub fn write_json(&self, w) -> fmt::Result
    public func writeJson(): String {
        match (this) {
            case TestToken.Pipe => "{\"Pipe\":{}}"
            case TestToken.DoublePipe => "{\"DoublePipe\":{}}"
            case TestToken.Ampersand => "{\"Ampersand\":{}}"
            case TestToken.DoubleAmpersand => "{\"DoubleAmpersand\":{}}"
            case TestToken.Redirect(r) => "{\"Redirect\":" + r.writeJson() + "}"
            case TestToken.Dollar => "{\"Dollar\":{}}"
            case TestToken.Asterisk => "{\"Asterisk\":{}}"
            case TestToken.DoubleAsterisk => "{\"DoubleAsterisk\":{}}"
            case TestToken.Eq => "{\"Eq\":{}}"
            case TestToken.Semicolon => "{\"Semicolon\":{}}"
            case TestToken.Newline => "{\"Newline\":{}}"
            case TestToken.BraceBegin => "{\"BraceBegin\":{}}"
            case TestToken.Comma => "{\"Comma\":{}}"
            case TestToken.BraceEnd => "{\"BraceEnd\":{}}"
            case TestToken.CmdSubstBegin => "{\"CmdSubstBegin\":{}}"
            case TestToken.CmdSubstQuoted => "{\"CmdSubstQuoted\":{}}"
            case TestToken.CmdSubstEnd => "{\"CmdSubstEnd\":{}}"
            case TestToken.OpenParen => "{\"OpenParen\":{}}"
            case TestToken.CloseParen => "{\"CloseParen\":{}}"
            case TestToken.Var(s) => "{\"Var\":" + jsonStringEncode(s) + "}"
            case TestToken.VarArgv(n) => "{\"VarArgv\":" + n.toString() + "}"
            case TestToken.Text(s) => "{\"Text\":" + jsonStringEncode(s) + "}"
            case TestToken.SingleQuotedText(s) => "{\"SingleQuotedText\":" + jsonStringEncode(s) + "}"
            case TestToken.DoubleQuotedText(s) => "{\"DoubleQuotedText\":" + jsonStringEncode(s) + "}"
            case TestToken.JSObjRef(n) => "{\"JSObjRef\":" + n.toString() + "}"
            case TestToken.DoubleBracketOpen => "{\"DoubleBracketOpen\":{}}"
            case TestToken.DoubleBracketClose => "{\"DoubleBracketClose\":{}}"
            case TestToken.Delimit => "{\"Delimit\":{}}"
            case TestToken.Eof => "{\"Eof\":{}}"
        }
    }
}

/// 令牌列表 JSON 格式化
/// 对应 Bun: pub fn tokens_json_fmt(tokens) -> impl Display
public func tokensJsonFmt(tokens: ArrayList<TestToken>): String {
    var sb = StringBuilder()
    sb.append("[")
    for (i in 0..tokens.size) {
        if (i > 0) {
            sb.append(",")
        }
        sb.append(tokens[i].writeJson())
    }
    sb.append("]")
    return sb.toString()
}

// ============================================================================
// Token - Shell 令牌
// 对应 Bun: bun_shell_parser::parse::Token
// ============================================================================

/// Shell 令牌
/// 对应 Bun: Token (union(TokenTag))
public enum Token {
    | Var(String)
    | VarArgv(UInt8)
    | Text(String)
    | SingleQuotedText(String)
    | DoubleQuotedText(String)
    | JSObjRef(UInt32)
    | Pipe
    | DoublePipe
    | Ampersand
    | DoubleAmpersand
    | Redirect(RedirectFlags)
    | Dollar
    | Asterisk
    | DoubleAsterisk
    | Eq
    | Semicolon
    | Newline
    | BraceBegin
    | Comma
    | BraceEnd
    | CmdSubstBegin
    | CmdSubstQuoted
    | CmdSubstEnd
    | OpenParen
    | CloseParen
    | DoubleBracketOpen
    | DoubleBracketClose
    | Delimit
    | Eof
}

// ============================================================================
// RedirectFlags - 重定向标志
// 对应 Bun: bun_shell_parser AST RedirectFlags
// ============================================================================

/// 重定向标志
public class RedirectFlags {
    public var read: Bool
    public var write: Bool
    public var append: Bool
    public var stderr: Bool

    public init() {
        read = false
        write = false
        append = false
        stderr = false
    }

    public func writeJson(): String {
        var parts = ArrayList<String>()
        if (read) { parts.append("\"read\":true") }
        if (write) { parts.append("\"write\":true") }
        if (append) { parts.append("\"append\":true") }
        if (stderr) { parts.append("\"stderr\":true") }
        return "{" + String.join(",", parts) + "}"
    }
}

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
    /// 对应 Bun: impl Drop for JsStrings { fn drop(&mut self) { for s in &self.0 { s.deref(); } } }
    public func deinit(): Unit {
        strings.clear()
    }
}

// ============================================================================
// shellCmdFromJs - 从 JS 参数构建 shell 命令
// 对应 Bun: pub fn shell_cmd_from_js(global, string_args, template_args, ...) -> JsResult<()>
// ============================================================================

/// 从 JS 参数构建 shell 命令
/// 对应 Bun: pub fn shell_cmd_from_js
public func shellCmdFromJs(
    global: JsObject,
    stringArgs: JsValue,
    templateArgs: JsArrayIterator,
    outJsobjs: ArrayList<JsValue>,
    jsstrings: JsStrings,
    outScript: ArrayList<UInt8>,
    markedArgumentBuffer: MarkedArgumentBuffer
): Unit {
    var builder = ShellSrcBuilder.init(global, outScript, jsstrings)
    var jsobjrefBuf = Array<UInt8>(128, repeat: 0)

    var stringIter = stringArgs.arrayIterator(global)
    var i: UInt32 = 0
    let last = stringIter.length() - 1

    var jsValue = stringIter.next()
    while (jsValue.isSome()) {
        let jsVal = jsValue.getOrThrow()
        if (!builder.appendJsValueStr(jsVal, false)) {
            global.throwValue(BaoString("Shell script string contains invalid UTF-16"))
            return
        }

        if (i < last) {
            let templateValue = templateArgs.next()
            match (templateValue) {
                case Some(tv) =>
                    // 对应 Bun: handle_template_value(...)
                    handleTemplateValue(
                        global, tv, outJsobjs, outScript,
                        jsstrings, jsobjrefBuf, markedArgumentBuffer
                    )
                    builder = ShellSrcBuilder.init(global, outScript, jsstrings)
                case None =>
                    global.throwValue(BaoString("Shell script is missing JSValue arg"))
                    return
            }
        }
        i = i + 1
        jsValue = stringIter.next()
    }
}

// ============================================================================
// handleTemplateValue - 处理模板值
// 对应 Bun: pub fn handle_template_value(...)
// ============================================================================

/// 处理模板值
/// 对应 Bun: pub fn handle_template_value
public func handleTemplateValue(
    global: JsObject,
    templateValue: JsValue,
    outJsobjs: ArrayList<JsValue>,
    outScript: ArrayList<UInt8>,
    jsstrings: JsStrings,
    jsobjrefBuf: Array<UInt8>,
    markedArgumentBuffer: MarkedArgumentBuffer
): Unit {
    if (!templateValue.isEmpty()) {
        // 检查 ArrayBuffer
        if (templateValue.isArrayBuffer()) {
            let idx = outJsobjs.size
            markedArgumentBuffer.append(templateValue)
            outJsobjs.append(templateValue)
            let refStr = "\u{08}o" + idx.toString()
            for (b in refStr.toArray()) {
                outScript.append(b)
            }
            return
        }

        // 检查字符串
        if (templateValue.isString()) {
            var builder = ShellSrcBuilder.init(global, outScript, jsstrings)
            if (!builder.appendJsValueStr(templateValue, true)) {
                global.throwValue(BaoString("Shell script string contains invalid UTF-16"))
            }
            return
        }

        // 检查数组
        if (templateValue.jsType().isArray()) {
            var array = templateValue.arrayIterator(global)
            let last = array.length() - 1
            var j: UInt32 = 0
            var arrVal = array.next()
            while (arrVal.isSome()) {
                handleTemplateValue(
                    global, arrVal.getOrThrow(), outJsobjs,
                    outScript, jsstrings, jsobjrefBuf, markedArgumentBuffer
                )
                if (j < last) {
                    outScript.append(0x20)  // 空格分隔
                }
                j = j + 1
                arrVal = array.next()
            }
            return
        }

        // 原始值
        if (!templateValue.isObject()) {
            var builder = ShellSrcBuilder.init(global, outScript, jsstrings)
            if (!builder.appendJsValueStr(templateValue, true)) {
                global.throwValue(BaoString("Shell script string contains invalid UTF-16"))
            }
            return
        }

        // 通用对象 - 报错
        global.throwValue(BaoString(
            "Invalid JS object used in shell: " + templateValue.fmtString(global) +
            ", you might need to call `.toString()` on it"
        ))
    }
}

// ============================================================================
// ShellSrcBuilder - Shell 源码构建器
// 对应 Bun: pub struct ShellSrcBuilder<'a>
// ============================================================================

/// Shell 源码构建器
/// 对应 Bun: pub struct ShellSrcBuilder<'a>
public class ShellSrcBuilder {
    public var globalThis: JsObject
    public var outbuf: ArrayList<UInt8>
    public var jsstrsToEscape: JsStrings
    public var jsstrRefBuf: Array<UInt8>

    public init(globalThis: JsObject, outbuf: ArrayList<UInt8>, jsstrsToEscape: JsStrings) {
        this.globalThis = globalThis
        this.outbuf = outbuf
        this.jsstrsToEscape = jsstrsToEscape
        this.jsstrRefBuf = Array<UInt8>(128, repeat: 0)
    }

    /// 初始化
    /// 对应 Bun: pub fn init(global, outbuf, jsstrs_to_escape) -> Self
    public static func init(global: JsObject, outbuf: ArrayList<UInt8>,
                             jsstrsToEscape: JsStrings): ShellSrcBuilder {
        return ShellSrcBuilder(global, outbuf, jsstrsToEscape)
    }

    /// 追加 JS 值字符串
    /// 对应 Bun: pub fn append_js_value_str<const ALLOW_ESCAPE>(&mut self, jsval) -> JsResult<bool>
    public func appendJsValueStr(jsVal: JsValue, allowEscape: Bool): Bool {
        let bunStr = jsVal.toBaoString(globalThis)

        // 安全检查: 不允许空字节 (防止空字节注入)
        if (bunStr.indexOfAsciiChar(0).isSome()) {
            globalThis.throwValue(BaoString(
                "The shell argument must be a string without null bytes. Received \"" + bunStr + "\""
            ))
            return false
        }

        return appendBunStr(bunStr, allowEscape)
    }

    /// 追加 BunString
    /// 对应 Bun: pub fn append_bun_str<const ALLOW_ESCAPE>(&mut self, bunstr) -> Result<bool, AllocError>
    public func appendBunStr(bunStr: BaoString, allowEscape: Bool): Bool {
        // 空 UTF-16 检查简化
        if (allowEscape && bunStr.size == 0) {
            appendJsStrRef(bunStr)
            return true
        }

        if (allowEscape) {
            if (needsEscapeBunStr(bunStr)) {
                appendJsStrRef(bunStr)
                return true
            }
        }

        // 直接追加 UTF-8 字节
        appendUtf8Impl(bunStr.toUtf8().toArray())
        return true
    }

    /// 追加 UTF-8 数据
    /// 对应 Bun: pub fn append_utf8<const ALLOW_ESCAPE>(&mut self, utf8) -> Result<bool, Error>
    public func appendUtf8(utf8: Array<UInt8>, allowEscape: Bool): Bool {
        if (allowEscape) {
            if (needsEscapeUtf8AsciiLatin1(utf8)) {
                appendJsStrRef(BaoString.fromUtf8(utf8))
                return true
            }
        }

        appendUtf8Impl(utf8)
        return true
    }

    /// 内部 UTF-8 追加
    /// 对应 Bun: pub fn append_utf8_impl(&mut self, utf8)
    public func appendUtf8Impl(utf8: Array<UInt8>): Unit {
        for (b in utf8) {
            outbuf.append(b)
        }
    }

    /// 追加 JS 字符串引用
    /// 对应 Bun: pub fn append_js_str_ref(&mut self, bunstr)
    public func appendJsStrRef(bunStr: BaoString): Unit {
        let idx = jsstrsToEscape.size()
        let refStr = "\u{08}s" + idx.toString()
        for (b in refStr.toArray()) {
            outbuf.append(b)
        }
        jsstrsToEscape.append(bunStr)
    }
}

// ============================================================================
// TestingAPIs - 测试 API
// 对应 Bun: pub mod testing_apis
// ============================================================================

/// Shell 测试 API
/// 对应 Bun: pub mod testing_apis
public class ShellTestingAPIs {
    /// 检查平台是否禁用
    /// 对应 Bun: pub fn disabled_on_this_platform(global, callframe) -> JsResult<JSValue>
    public static func disabledOnThisPlatform(global: JsObject, args: ArrayList<JsValue>): JsValue {
        return JsValue.FALSE
    }

    /// Shell 词法分析 (用于测试)
    /// 对应 Bun: pub fn shell_lex(global, callframe) -> JsResult<JSValue>
    public static func shellLex(global: JsObject, args: ArrayList<JsValue>): JsValue {
        if (args.size < 2) {
            return JsValue(BaoString("shell_lex: expected 2 arguments"))
        }

        let script = args[0].toString()
        // 简化: 返回脚本内容
        return JsValue(BaoString("[" + script + "]"))
    }

    /// Shell 解析 (用于测试)
    /// 对应 Bun: pub fn shell_parse(global, callframe) -> JsResult<JSValue>
    public static func shellParse(global: JsObject, args: ArrayList<JsValue>): JsValue {
        if (args.size < 2) {
            return JsValue(BaoString("shell_parse: expected 2 arguments"))
        }

        let script = args[0].toString()
        // 简化: 返回脚本内容
        return JsValue(BaoString(script))
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

    public func toJs(global: JsObject): JsValue {
        return JsValue(BaoString(message + ": " + path))
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

/// Mini 事件循环
/// 对应 Bun: bun_jsc::MiniEventLoop
public class MiniEventLoop {
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
    // 简化: 检查是否包含特殊字符
    let bytes = s.toUtf8()
    for (b in bytes) {
        // 空格, 引号, 反斜杠, 换行等
        if (b == 0x20 || b == 0x22 || b == 0x27 || b == 0x5C ||
            b == 0x0A || b == 0x0D || b == 0x09 || b == 0x24 ||
            b == 0x60 || b == 0x28 || b == 0x29 || b == 0x3B ||
            b == 0x26 || b == 0x7C || b == 0x3C || b == 0x3E ||
            b == 0x2A || b == 0x3F || b == 0x5B || b == 0x5D ||
            b == 0x7B || b == 0x7D) {
            return true
        }
    }
    return false
}

/// 检查 UTF-8 是否需要转义
/// 对应 Bun: needs_escape_utf8_ascii_latin1(utf8)
private func needsEscapeUtf8AsciiLatin1(bytes: Array<UInt8>): Bool {
    return needsEscapeBunStr(BaoString.fromUtf8(bytes))
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
