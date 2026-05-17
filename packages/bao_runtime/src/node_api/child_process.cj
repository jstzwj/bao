// Node.js child_process 模块 — 子进程管理 API
// 对应 Bun: src/runtime/node/child_process.zig
// 严格翻译自: src/runtime/node/child_process.zig
// 严格翻译 Bun 的 Node.js child_process 兼容层
package bao_runtime.node_api

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_runtime.*

// ============================================================================
// child_process 模块 — Node.js 子进程 API
// 对应 Bun: src/runtime/node/child_process.zig
// ============================================================================

/// child_process 模块 — 提供 Node.js 兼容的子进程管理 API
/// 对应 Bun: src/runtime/node/child_process.zig
public class ChildProcessModule {
    /// child_process.spawn(command, args, options) — 创建子进程
    /// 对应 Bun: spawn -> src/spawn/spawn.zig
    public static func `spawn`(command: String, args: ArrayList<String>, options: NodeSpawnOptions): ChildProcessHandle {
        let sysOpts = SpawnOptions()
        sysOpts.args = Array<String>(args.size, { i => args[i] })
        sysOpts.cwd = if (options.cwd.size > 0) { Some(options.cwd) } else { None }
        // 转换环境变量
        if (options.env.size > 0) {
            for (key in options.env.keys()) {
                match (options.env.get(key)) {
                    case Some(v) => sysOpts.env.put(key, v)
                    case None => ()
                }
            }
        }
        // 转换 stdio 配置
        sysOpts.stdin = options.stdio
        sysOpts.stdout = options.stdio
        sysOpts.stderr = options.stdio

        let sysChild = ProcessSpawner.`spawn`(command, sysOpts)
        let child = ChildProcessHandle()
        child.pid = sysChild.pid
        child.killed = false
        child.exitCode = -1
        child.signalCode = ""

        // 创建管道 I/O — 使用 bao_io 的 PipeReader/PipeWriter
        if (sysChild.stdinFd >= 0) {
            child.stdin = Some(PipeWriter(sysChild.stdinFd))
        }
        if (sysChild.stdoutFd >= 0) {
            child.stdout = Some(PipeReader(sysChild.stdoutFd))
        }
        if (sysChild.stderrFd >= 0) {
            child.stderr = Some(PipeReader(sysChild.stderrFd))
        }

        return child
    }

    /// child_process.spawn(command) — 简化版 spawn
    public static func `spawn`(command: String): ChildProcessHandle {
        return `spawn`(command, ArrayList<String>(), NodeSpawnOptions())
    }

    /// child_process.spawn(command, args) — 带 args 的 spawn
    public static func `spawn`(command: String, args: ArrayList<String>): ChildProcessHandle {
        return `spawn`(command, args, NodeSpawnOptions())
    }

    /// child_process.exec(command, options, callback) — 执行命令 (回调版)
    /// 对应 Bun: exec -> spawn + buffer output + callback
    public static func exec(command: String, options: NodeExecOptions, callback: (NodeExecError, String, String) -> Unit): ChildProcessHandle {
        let spawnOpts = NodeSpawnOptions()
        spawnOpts.cwd = options.cwd
        spawnOpts.shell = true
        // 使用 shell 执行命令
        let child = `spawn`("/bin/sh", ArrayList<String>(["-c", command]), spawnOpts)

        // 收集输出 — 在同步回调中立即读取
        var stdout = ""
        var stderr = ""
        match (child.stdout) {
            case Some(reader) =>
                let result = reader.readToEnd()
                match (result) {
                    case Ok(bytes) =>
                        stdout = byteArrayToString(bytes)
                    case Err(_) => ()
                }
            case None => ()
        }
        match (child.stderr) {
            case Some(reader) =>
                let result = reader.readToEnd()
                match (result) {
                    case Ok(bytes) =>
                        stderr = byteArrayToString(bytes)
                    case Err(_) => ()
                }
            case None => ()
        }

        // 等待进程完成
        let status = child.waitInner()
        match (status) {
            case ExitStatus.Exited(code) => child.exitCode = code
            case ExitStatus.Signaled(sig) =>
                child.exitCode = -1
                child.signalCode = "SIG${sig}"
            case ExitStatus.Running => ()
        }

        // 构造结果并调用回调
        if (child.exitCode == 0) {
            callback(NodeExecError(), stdout, stderr)
        } else {
            let err = NodeExecError()
            err.message = "Command failed: ${command}"
            err.code = if (child.exitCode == -1) { "null" } else { child.exitCode.toString() }
            err.killed = child.killed
            err.stdout = stdout
            err.stderr = stderr
            callback(err, stdout, stderr)
        }

        return child
    }

    /// child_process.exec(command, callback) — 简化版 exec
    public static func exec(command: String, callback: (NodeExecError, String, String) -> Unit): ChildProcessHandle {
        return exec(command, NodeExecOptions(), callback)
    }

    /// child_process.execSync(command, options) — 执行命令 (同步版)
    /// 对应 Bun: execSync -> spawn + read + wait
    public static func execSync(command: String, options: NodeExecOptions): NodeExecResult {
        let spawnOpts = NodeSpawnOptions()
        spawnOpts.cwd = options.cwd
        spawnOpts.shell = true
        spawnOpts.stdio = StdioConfig.Pipe

        let child = `spawn`("/bin/sh", ArrayList<String>(["-c", command]), spawnOpts)

        // 读取输出
        var stdout = ""
        var stderr = ""
        match (child.stdout) {
            case Some(reader) =>
                let result = reader.readToEnd()
                match (result) {
                    case Ok(bytes) => stdout = byteArrayToString(bytes)
                    case Err(_) => ()
                }
            case None => ()
        }
        match (child.stderr) {
            case Some(reader) =>
                let result = reader.readToEnd()
                match (result) {
                    case Ok(bytes) => stderr = byteArrayToString(bytes)
                    case Err(_) => ()
                }
            case None => ()
        }

        // 等待完成
        let status = child.waitInner()
        let exitCode = match (status) {
            case ExitStatus.Exited(code) => code
            case ExitStatus.Signaled(_) => -1
            case ExitStatus.Running => -1
        }

        let result = NodeExecResult()
        result.stdout = stdout
        result.stderr = stderr
        result.exitCode = exitCode
        return result
    }

    /// child_process.execSync(command) — 简化版 execSync
    public static func execSync(command: String): NodeExecResult {
        return execSync(command, NodeExecOptions())
    }

    /// child_process.execFile(file, args, options) — 执行文件 (无 shell)
    /// 对应 Bun: execFile -> spawn without shell
    public static func execFile(file: String, args: ArrayList<String>, options: NodeSpawnOptions): ChildProcessHandle {
        return `spawn`(file, args, options)
    }

    /// child_process.execFile(file) — 简化版 execFile
    public static func execFile(file: String): ChildProcessHandle {
        return `spawn`(file, ArrayList<String>(), NodeSpawnOptions())
    }

    /// child_process.fork(modulePath, args, options) — 创建子 Node 进程
    /// 对应 Bun: fork -> spawn with ipc channel
    public static func fork(modulePath: String, args: ArrayList<String>, options: NodeSpawnOptions): ChildProcessHandle {
        let forkOpts = NodeSpawnOptions()
        forkOpts.cwd = options.cwd
        forkOpts.env = options.env
        forkOpts.stdio = StdioConfig.Pipe
        forkOpts.detached = false

        // 使用当前运行时执行模块
        // 对应 Bun: fork 会 spawn 一个新的 Bun 进程执行模块
        let allArgs = ArrayList<String>()
        allArgs.append(modulePath)
        for (arg in args) {
            allArgs.append(arg)
        }

        return `spawn`("bao", allArgs, forkOpts)
    }

    /// child_process.fork(modulePath) — 简化版 fork
    public static func fork(modulePath: String): ChildProcessHandle {
        return fork(modulePath, ArrayList<String>(), NodeSpawnOptions())
    }

    /// 字节数组转字符串
    public static func byteArrayToString(bytes: Array<UInt8>): String {
        let sb = StringBuilder()
        for (b in bytes) {
            sb.append(String(Rune(Int32(b))))
        }
        return sb.toString()
    }

    /// 将 child_process 模块导出为 JsValue 对象
    /// 用于在解释器中注册 require('child_process')
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        obj.set("spawn", JsValue.nativeFunction(JsNativeFunction("spawn") { args =>
            if (args.size < 1) { return JsValue.NULL }
            let command = Interpreter.jsToString(args[0])
            let spawnArgs = ArrayList<String>()
            if (args.size > 1) {
                match (args[1].arrayData) {
                    case Some(arr) =>
                        for (a in arr) { spawnArgs.append(Interpreter.jsToString(a)) }
                    case None => ()
                }
            }
            let options = if (args.size > 2) { parseSpawnOptions(args[2]) } else { NodeSpawnOptions() }
            let child = `spawn`(command, spawnArgs, options)
            return child.toJsValue()
        }))

        obj.set("exec", JsValue.nativeFunction(JsNativeFunction("exec") { args =>
            if (args.size < 1) { return JsValue.NULL }
            let command = Interpreter.jsToString(args[0])
            let options = if (args.size > 1) { parseExecOptions(args[1]) } else { NodeExecOptions() }
            // 简化: 同步执行，立即调用回调
            let child = exec(command, options) { _, _, _ => }
            return child.toJsValue()
        }))

        obj.set("execSync", JsValue.nativeFunction(JsNativeFunction("execSync") { args =>
            if (args.size < 1) { return JsValue(BaoString("")) }
            let command = Interpreter.jsToString(args[0])
            let options = if (args.size > 1) { parseExecOptions(args[1]) } else { NodeExecOptions() }
            let result = execSync(command, options)
            return JsValue(BaoString(result.stdout))
        }))

        obj.set("execFile", JsValue.nativeFunction(JsNativeFunction("execFile") { args =>
            if (args.size < 1) { return JsValue.NULL }
            let file = Interpreter.jsToString(args[0])
            let fileArgs = ArrayList<String>()
            if (args.size > 1) {
                match (args[1].arrayData) {
                    case Some(arr) =>
                        for (a in arr) { fileArgs.append(Interpreter.jsToString(a)) }
                    case None => ()
                }
            }
            let options = if (args.size > 2) { parseSpawnOptions(args[2]) } else { NodeSpawnOptions() }
            let child = execFile(file, fileArgs, options)
            return child.toJsValue()
        }))

        obj.set("fork", JsValue.nativeFunction(JsNativeFunction("fork") { args =>
            if (args.size < 1) { return JsValue.NULL }
            let modulePath = Interpreter.jsToString(args[0])
            let forkArgs = ArrayList<String>()
            if (args.size > 1) {
                match (args[1].arrayData) {
                    case Some(arr) =>
                        for (a in arr) { forkArgs.append(Interpreter.jsToString(a)) }
                    case None => ()
                }
            }
            let options = if (args.size > 2) { parseSpawnOptions(args[2]) } else { NodeSpawnOptions() }
            let child = fork(modulePath, forkArgs, options)
            return child.toJsValue()
        }))

        // ChildProcess 类 (用于 instanceof 检查)
        obj.set("ChildProcess", JsValue.nativeFunction(JsNativeFunction("ChildProcess") { _ =>
            let child = ChildProcessHandle()
            return child.toJsValue()
        }))

        return JsValue(obj)
    }

    /// 从 JsValue 解析 SpawnOptions
    private static func parseSpawnOptions(v: JsValue): NodeSpawnOptions {
        let opts = NodeSpawnOptions()
        match (v.objectData) {
            case Some(obj) =>
                let cwdVal = obj.get("cwd")
                if (cwdVal.valueType != JsValueType.Undefined) { opts.cwd = Interpreter.jsToString(cwdVal) }
                let shellVal = obj.get("shell")
                if (shellVal.valueType != JsValueType.Undefined) { opts.shell = Interpreter.jsToBoolean(shellVal) }
                let detVal = obj.get("detached")
                if (detVal.valueType != JsValueType.Undefined) { opts.detached = Interpreter.jsToBoolean(detVal) }
                // 解析 env 对象
                let envVal = obj.get("env")
                match (envVal.objectData) {
                    case Some(envObj) =>
                        for (key in envObj.keys()) {
                            let val = envObj.get(key)
                            if (val.valueType != JsValueType.Undefined) { opts.env.put(key, Interpreter.jsToString(val)) }
                        }
                    case None => ()
                }
                // 解析 uid/gid
                let uidVal = obj.get("uid")
                if (uidVal.valueType != JsValueType.Undefined) { opts.uid = Int64(Interpreter.jsToNumber(uidVal)) }
                let gidVal = obj.get("gid")
                if (gidVal.valueType != JsValueType.Undefined) { opts.gid = Int64(Interpreter.jsToNumber(gidVal)) }
            case None => ()
        }
        return opts
    }

    /// 从 JsValue 解析 ExecOptions
    private static func parseExecOptions(v: JsValue): NodeExecOptions {
        let opts = NodeExecOptions()
        match (v.objectData) {
            case Some(obj) =>
                let cwdVal = obj.get("cwd")
                if (cwdVal.valueType != JsValueType.Undefined) { opts.cwd = Interpreter.jsToString(cwdVal) }
                let encVal = obj.get("encoding")
                if (encVal.valueType != JsValueType.Undefined) { opts.encoding = Interpreter.jsToString(encVal) }
                let tVal = obj.get("timeout")
                if (tVal.valueType != JsValueType.Undefined) { opts.timeout = Int64(Interpreter.jsToNumber(tVal)) }
                let mbVal = obj.get("maxBuffer")
                if (mbVal.valueType != JsValueType.Undefined) { opts.maxBuffer = Int64(Interpreter.jsToNumber(mbVal)) }
                let ksVal = obj.get("killSignal")
                if (ksVal.valueType != JsValueType.Undefined) { opts.killSignal = Interpreter.jsToString(ksVal) }
            case None => ()
        }
        return opts
    }
}

// ============================================================================
// Spawn 选项配置
// ============================================================================

/// spawn 选项 — 对应 Node.js child_process.spawn options
public class NodeSpawnOptions {
    /// 工作目录
    public var cwd: String
    /// 环境变量
    public var env: HashMap<String, String>
    /// 标准 IO 配置
    public var stdio: StdioConfig
    /// 用户 ID
    public var uid: Int64
    /// 组 ID
    public var gid: Int64
    /// 是否使用 shell 执行
    public var shell: Bool
    /// 是否分离进程
    public var detached: Bool
    /// 是否隐藏 Windows 窗口 (占位)
    public var windowsHide: Bool

    public init() {
        cwd = ""
        env = HashMap<String, String>()
        stdio = StdioConfig.Pipe
        uid = -1
        gid = -1
        shell = false
        detached = false
        windowsHide = false
    }
}

/// Exec 选项 — 对应 Node.js child_process.exec options
public class NodeExecOptions {
    /// 工作目录
    public var cwd: String
    /// 环境变量
    public var env: HashMap<String, String>
    /// 编码 (默认 "utf8")
    public var encoding: String
    /// 超时时间 (毫秒, 0 表示无超时)
    public var timeout: Int64
    /// 最大缓冲区大小 (字节)
    public var maxBuffer: Int64
    /// 终止信号
    public var killSignal: String

    public init() {
        cwd = ""
        env = HashMap<String, String>()
        encoding = "utf8"
        timeout = 0
        maxBuffer = 1024 * 1024  // 1MB
        killSignal = "SIGTERM"
    }
}

// StdioConfig 使用 bao_sys.StdioConfig，不在此重复定义

// ============================================================================
// 子进程句柄
// ============================================================================

/// 子进程句柄 — 对应 Node.js ChildProcess 实例
/// 封装 ChildProcess，提供 Node.js 兼容 API
public class ChildProcessHandle {
    /// 进程 ID
    public var pid: Int64
    /// 标准输入管道写入端 — 对应 Node.js child.stdin
    public var stdin: ?PipeWriter
    /// 标准输出管道读取端 — 对应 Node.js child.stdout
    public var stdout: ?PipeReader
    /// 标准错误管道读取端 — 对应 Node.js child.stderr
    public var stderr: ?PipeReader
    /// 退出码 — 对应 Node.js child.exitCode
    public var exitCode: Int64
    /// 终止信号 — 对应 Node.js child.signalCode
    public var signalCode: String
    /// 是否已被 kill — 对应 Node.js child.killed
    public var killed: Bool

    /// 内部 bao_sys 子进程引用
    private var sysChild: ?ChildProcess

    public init() {
        pid = -1
        stdin = None
        stdout = None
        stderr = None
        exitCode = -1
        signalCode = ""
        killed = false
        sysChild = None
    }

    public init(sysChild: ChildProcess) {
        pid = sysChild.pid
        stdin = None
        stdout = None
        stderr = None
        exitCode = -1
        signalCode = ""
        killed = false
        this.sysChild = Some(sysChild)
    }

    /// child.kill(signal) — 发送信号终止进程
    /// 对应 Node.js: child.kill(signal)
    public func kill(signal: String): Bool {
        if (killed) { return true }
        match (sysChild) {
            case Some(child) =>
                let sigNum = signalToNumber(signal)
                child.kill(sigNum)
                killed = true
                signalCode = signal
                return true
            case None => return false
        }
    }

    /// child.kill() — 默认使用 SIGTERM 终止
    public func kill(): Bool {
        return kill("SIGTERM")
    }

    /// child.send(message) — 发送 IPC 消息
    /// 对应 Node.js: child.send(message)
    /// Bun 通过序列化 IPC 消息实现
    public func send(message: JsValue): Unit {
        // IPC 通信需要序列化通道
        // 如果 stdin 可用，写入序列化消息
        match (stdin) {
            case Some(writer) =>
                let serialized = JsonParser.stringify(message)
                writer.write((serialized + "\n").toArray())
            case None => ()
        }
    }

    /// child.disconnect() — 断开 IPC 连接
    /// 对应 Node.js: child.disconnect()
    public func disconnect(): Unit {
        // 关闭 stdin 管道以断开 IPC
        match (stdin) {
            case Some(writer) =>
                writer.close()
                stdin = None
            case None => ()
        }
    }

    /// child.ref() — 引用子进程 (保持事件循环运行)
    /// 对应 Node.js: child.ref()
    public func ref(): Unit {
        // 事件循环引用计数 — 委托给底层
        // ChildProcess 不支持 ref/unref，此处为空操作
    }

    /// child.unref() — 取消引用子进程 (允许事件循环退出)
    /// 对应 Node.js: child.unref()
    public func unref(): Unit {
        // ChildProcess 不支持 ref/unref，此处为空操作
    }

    /// 读取 stdout 全部内容
    public func readStdout(): String {
        match (stdout) {
            case Some(reader) =>
                let result = reader.readToEnd()
                match (result) {
                    case Ok(bytes) => return ChildProcessModule.byteArrayToString(bytes)
                    case Err(_) => return ""
                }
            case None => return ""
        }
    }

    /// 读取 stderr 全部内容
    public func readStderr(): String {
        match (stderr) {
            case Some(reader) =>
                let result = reader.readToEnd()
                match (result) {
                    case Ok(bytes) => return ChildProcessModule.byteArrayToString(bytes)
                    case Err(_) => return ""
                }
            case None => return ""
        }
    }

    /// 写入 stdin
    public func writeStdin(data: String): Unit {
        match (stdin) {
            case Some(writer) =>
                writer.write(data.toArray())
            case None => ()
        }
    }

    /// 关闭 stdin 管道
    public func closeStdin(): Unit {
        match (stdin) {
            case Some(writer) =>
                writer.close()
                stdin = None
            case None => ()
        }
    }

    /// 内部等待方法 — 通过 ChildProcess.wait()
    public func waitInner(): ExitStatus {
        match (sysChild) {
            case Some(child) => return child.wait()
            case None => return ExitStatus.Exited(-1)
        }
    }

    /// 将 ChildProcess 导出为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let handle = this

        obj.set("pid", JsValue(Float64(pid)))
        obj.set("exitCode", JsValue(Float64(exitCode)))
        obj.set("signalCode", JsValue(BaoString(signalCode)))
        obj.set("killed", JsValue(killed))

        // stdin — PipeWriter 或 null
        match (stdin) {
            case Some(_) => obj.set("stdin", JsValue(JsObject()))
            case None => obj.set("stdin", JsValue.NULL)
        }

        // stdout — PipeReader 或 null
        match (stdout) {
            case Some(reader) =>
                let stdoutObj = JsObject()
                stdoutObj.set("readable", JsValue(true))
                obj.set("stdout", JsValue(stdoutObj))
            case None => obj.set("stdout", JsValue.NULL)
        }

        // stderr — PipeReader 或 null
        match (stderr) {
            case Some(reader) =>
                let stderrObj = JsObject()
                stderrObj.set("readable", JsValue(true))
                obj.set("stderr", JsValue(stderrObj))
            case None => obj.set("stderr", JsValue.NULL)
        }

        // kill 方法
        obj.set("kill", JsValue.nativeFunction(JsNativeFunction("kill") { args =>
            let sig = if (args.size > 0) { Interpreter.jsToString(args[0]) } else { "SIGTERM" }
            JsValue(handle.kill(sig))
        }))

        // send 方法
        obj.set("send", JsValue.nativeFunction(JsNativeFunction("send") { args =>
            if (args.size > 0) { handle.send(args[0]) }
            JsValue.UNDEFINED
        }))

        // disconnect 方法
        obj.set("disconnect", JsValue.nativeFunction(JsNativeFunction("disconnect") { _ =>
            handle.disconnect()
            JsValue.UNDEFINED
        }))

        // ref/unref 方法
        obj.set("ref", JsValue.nativeFunction(JsNativeFunction("ref") { _ =>
            handle.ref()
            JsValue.UNDEFINED
        }))

        obj.set("unref", JsValue.nativeFunction(JsNativeFunction("unref") { _ =>
            handle.unref()
            JsValue.UNDEFINED
        }))

        return JsValue(obj)
    }

    /// 信号名称转数字
    private static func signalToNumber(signal: String): Int64 {
        match (signal) {
            case "SIGHUP" => 1
            case "SIGINT" => 2
            case "SIGQUIT" => 3
            case "SIGILL" => 4
            case "SIGABRT" => 6
            case "SIGFPE" => 8
            case "SIGKILL" => 9
            case "SIGSEGV" => 11
            case "SIGPIPE" => 13
            case "SIGALRM" => 14
            case "SIGTERM" => 15
            case "SIGUSR1" => 10
            case "SIGUSR2" => 12
            case "SIGCONT" => 18
            case "SIGSTOP" => 19
            case "SIGTSTP" => 20
            case "SIGTTIN" => 21
            case "SIGTTOU" => 22
            case _ => 15  // 默认 SIGTERM
        }
    }
}

// ============================================================================
// 执行结果
// ============================================================================

/// execSync 返回结果 — 对应 Node.js child_process.execSync 返回
public class NodeExecResult {
    /// 标准输出内容
    public var stdout: String
    /// 标准错误内容
    public var stderr: String
    /// 退出码
    public var exitCode: Int64

    public init() {
        stdout = ""
        stderr = ""
        exitCode = 0
    }
}

/// exec 回调错误 — 对应 Node.js child_process.exec 回调的 Error 参数
public class NodeExecError {
    /// 错误消息
    public var message: String
    /// 错误码
    public var code: String
    /// 是否被 kill
    public var killed: Bool
    /// 标准输出
    public var stdout: String
    /// 标准错误
    public var stderr: String

    public init() {
        message = ""
        code = ""
        killed = false
        stdout = ""
        stderr = ""
    }
}
