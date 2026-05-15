// shell.cj - Shell主入口
// 对应 Bun: src/runtime/shell/shell.zig
// 严格翻译Bun shell模块到仓颉

package bao_runtime

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_jsc.*

// ============================================================================
// Shell 子模块引用
// ============================================================================

/// 解释器模块
public let interpret = Interpreter

/// 子进程模块
public let subproc = Subproc

/// 分配作用域
public let AllocScope = AllocScopeImpl

/// 环境变量映射
public typealias EnvMap = Interpreter.EnvMap

/// 环境变量字符串
public typealias EnvStr = Interpreter.EnvStr

/// 解释器
public typealias InterpreterType = Interpreter

/// 已解析的Shell脚本
public typealias ParsedShellScript = Interpreter.ParsedShellScript

/// 子进程
public typealias Subprocess = Subproc.ShellSubprocess

/// 退出码
public typealias ExitCode = Interpreter.ExitCode

/// IO写入器
public typealias IOWriter = Interpreter.IOWriter

/// IO读取器
public typealias IOReader = Interpreter.IOReader

/// 协程Yield
public typealias Yield = YieldType

/// 不可达状态错误
public func unreachableState(context: String, state: String) {
    panic("Bao shell已到达不可达状态\"\(state)\"在\(context)上下文中。这表示一个bug，请提交GitHub issue。")
}

/// Shell子shell未实现的错误信息
public const SUBSHELL_TODO_ERROR = "子Shell尚未实现，请提交GitHub issue！"

/// 标准输入文件描述符
public func STDIN_FD(): FD {
    FD.fromUV(0)
}

/// 标准输出文件描述符
public func STDOUT_FD(): FD {
    FD.fromUV(1)
}

/// 标准错误文件描述符
public func STDERR_FD(): FD {
    FD.fromUV(2)
}

/// POSIX空设备路径
public const POSIX_DEV_NULL = "/dev/null"

/// Windows空设备路径
public const WINDOWS_DEV_NULL = "NUL"

// ============================================================================
// Shell错误类型
// 对应 Bun: shell.ShellErr
// ============================================================================

/// Shell错误类型
/// 字符串使用事件循环上下文分配器分配
public enum ShellErr {
    /// 系统错误
    case sys(SystemError)
    /// 自定义错误消息
    case custom(String)
    /// 无效参数
    case invalid_arguments(val: String)
    /// 未实现的功能
    case todo(String)

    /// 从系统错误创建
    public static func newSys(e: SystemError): ShellErr {
        ShellErr.sys(e)
    }

    /// 转换为字符串
    public func toString(): String {
        switch (this) {
            case .sys(let e) =>
                "bao: \(e.message): \(e.path)"
            case .custom(let msg) =>
                "bao: \(msg)"
            case .invalid_arguments(let args) =>
                "bao: invalid arguments: \(args.val)"
            case .todo(let msg) =>
                "bao: TODO: \(msg)"
        }
    }

    /// 向JS抛出错误
    public func throwJS(globalThis: JSGlobalObject): Unit {
        // 将错误转换为JS错误并抛出
        switch (this) {
            case .sys(let e) =>
                let err = e.toErrorInstance(globalThis)
                globalThis.throwValue(err)
            case .custom(let msg) =>
                let errValue = String.cloneUTF8(msg).toErrorInstance(globalThis)
                globalThis.throwValue(errValue)
            case .invalid_arguments(let args) =>
                globalThis.throwInvalidArguments("\(args.val)")
            case .todo(let msg) =>
                globalThis.throwTODO(msg)
        }
    }

    /// 向Mini事件循环抛出错误
    public func throwMini(): Unit {
        switch (this) {
            case .sys(let err) =>
                Output.prettyErrorln("<r><red>error<r>: Failed due to error: <b>baosh: \(err.message): \(err.path)<r>")
            case .custom(let custom) =>
                Output.prettyErrorln("<r><red>error<r>: Failed due to error: <b>\(custom)<r>")
            case .invalid_arguments(let invalid_arguments) =>
                Output.prettyErrorln("<r><red>error<r>: Failed due to error: <b>baosh: invalid arguments: \(invalid_arguments.val)<r>")
            case .todo(let todo) =>
                Output.prettyErrorln("<r><red>error<r>: Failed due to error: <b>TODO: \(todo)<r>")
        }
        Global.exit(1)
    }

    /// 释放资源
    public func deinit(allocator: Allocator) {
        switch (this) {
            case .sys(let e) =>
                e.deref()
            case .custom(let msg) =>
                allocator.free(msg)
            case .invalid_arguments(_) =>
                // 无需释放
            case .todo(let msg) =>
                allocator.free(msg)
        }
    }
}

// ============================================================================
// Shell结果类型
// 对应 Bun: shell.Result
// ============================================================================

/// Shell操作结果
public class Result<T> {
    public var result: T
    public var err: ShellErr

    /// 成功结果
    public static prop success: Result<T> {
        Result<T>(result: Zeroes.zeroes<T>())
    }

    /// 是否为错误
    public func asErr(): ?ShellErr {
        if (this == .err) {
            return this.err
        }
        return None
    }
}

/// Shell错误类型枚举
public enum ShellError {
    case Init
    case Process
    case GlobalThisThrown
    case Spawn
}

/// Shell解析错误类型
public enum ParseError {
    case Unsupported
    case Expected
    case Unexpected
    case Unknown
    case Lex
}

/// 管道类型 [0] => 读端 [1] => 写端
public typealias Pipe = Array<FD>

// ============================================================================
// Shell全局JS上下文
// 对应 Bun: shell.GlobalJS
// ============================================================================

/// Shell全局JS上下文
public class GlobalJS {
    public var globalThis: JSGlobalObject

    public init(g: JSGlobalObject) {
        this.globalThis = g
    }

    public func allocator(): Allocator {
        this.globalThis.bunVM().allocator
    }

    public func eventLoopCtx(): VirtualMachine {
        this.globalThis.bunVM()
    }

    public func throwInvalidArguments(fmt: String, args: Array<Any>): ShellErr {
        ShellErr.invalid_arguments(val: "\(fmt)")
    }

    public func throwTODO(msg: String): ShellErr {
        ShellErr.todo(msg)
    }

    public func throwError(err: SyscallError) {
        this.globalThis.throwValue(err.toJS(this.globalThis))
    }

    public func handleError(err: Any, fmt: String): ShellErr {
        ShellErr.custom("\(err) \(fmt)")
    }

    public func `throw`(fmt: String, args: Array<Any>): ShellErr {
        ShellErr.custom("\(fmt)")
    }
}
