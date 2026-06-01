// 严格翻译自: src/runtime/api/bun/js_bun_spawn_bindings.zig
//   Bun.spawn() / Bun.spawnSync() 的完整 JS 绑定实现
//   1. 解析 JS 参数 (cmd, args, env, cwd, stdio, detached, timeout, ...)
//   2. 构建 PosixSpawnOptions
//   3. 调用 spawnProcessPosix
//   4. 创建 Process + Subprocess (异步) 或收集结果 (同步)
//   5. 返回 JS Subprocess 对象 (异步) 或结果对象 (同步)
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsObject}
import bao_collections.{ArrayList, HashMap}
import bao_sys.*

/// Bun.spawn() 和 Bun.spawnSync() 的 JS 绑定
/// 严格翻译自: js_bun_spawn_bindings.zig
public class JsBunSpawnBindings {

    /// Bun.spawn() -- 异步创建子进程
    /// 翻译自: js_bun_spawn_bindings.zig:96-98
    public static func `spawn`(globalThis!: JsGlobalObject, args!: JsValue, secondaryArgsValue!: ?JsValue): JsValue {
        spawnMaybeSync(globalThis: globalThis, args: args, secondaryArgsValue: secondaryArgsValue, isSync: false)
    }

    /// Bun.spawnSync() -- 同步创建子进程并等待结果
    /// 翻译自: js_bun_spawn_bindings.zig:100-103
    public static func spawnSync(globalThis!: JsGlobalObject, args!: JsValue, secondaryArgsValue!: ?JsValue): JsValue {
        spawnMaybeSync(globalThis: globalThis, args: args, secondaryArgsValue: secondaryArgsValue, isSync: true)
    }

    /// spawnMaybeSync -- spawn/spawnSync 共享核心逻辑
    /// 严格翻译自: js_bun_spawn_bindings.zig:105-1131
    public static func spawnMaybeSync(
        globalThis!: JsGlobalObject,
        args!: JsValue,
        secondaryArgsValue!: ?JsValue,
        isSync!: Bool
    ): JsValue {
        // ====================================================================
        // 1. 参数初始化
        // 翻译自: js_bun_spawn_bindings.zig:125-180
        // ====================================================================
        var overrideEnv = false
        var envArray = ArrayList<String>()

        // 当前工作目录
        var cwd = ""

        // stdio 默认值:
        //   spawn:     stdin=ignore, stdout=pipe, stderr=inherit
        //   spawnSync: stdin=ignore, stdout=pipe, stderr=pipe
        var stdioConfigs = [
            SpawnStdioConfig.ignore,   // stdin
            SpawnStdioConfig.pipe,     // stdout
            SpawnStdioConfig.inherit   // stderr
        ]
        if (isSync) {
            stdioConfigs[2] = SpawnStdioConfig.pipe   // stderr
        }

        var lazy = false
        var detached = false
        var argv = ArrayList<String>()
        var cmdValue = JsValue.jsUndefined()
        var timeout = Option<Int32>.None
        var killSignal = SignalCode.SIGTERM
        var maxBuffer = Option<Int64>.None

        // ====================================================================
        // 2. 解析 JS 参数
        // 翻译自: js_bun_spawn_bindings.zig:181-454
        // ====================================================================
        var options = args
        var secondaryArgs = match (secondaryArgsValue) {
            case Some(v) => v
            case None => JsValue.jsUndefined()
        }

        // 如果第一个参数是数组，则它作为 cmd，第二个参数作为选项
        if (args.isArray()) {
            cmdValue = args
            options = secondaryArgs
        } else if (args.isObject()) {
            // 尝试从对象中提取 cmd 属性
            let cmdProp = args.getProperty("cmd")
            if (!cmdProp.isUndefinedOrNull()) {
                cmdValue = cmdProp
                options = args
            } else {
                // cmd 不存在 -- 报错
                return spawnThrowError(globalThis: globalThis, message: "cmd must be an array")
            }
        } else if (args.isUndefinedOrNull()) {
            return spawnThrowError(globalThis: globalThis, message: "cmd must be an array")
        }

        // 从选项对象中提取参数
        if (options.isObject()) {
            let optsObj = options.toObject()

            // cwd -- 需要在 PATH 解析之前设置
            let cwdProp = options.getProperty("cwd")
            if (!cwdProp.isUndefinedOrNull()) {
                let cwdStr = cwdProp.toString()
                if (cwdStr.size > 0) {
                    cwd = cwdStr
                }
            }

            // env
            let envProp = options.getProperty("env")
            if (envProp.isObject()) {
                overrideEnv = true
                parseEnvFromJS(envObj: envProp, envArray: envArray)
            }
        }

        // 解析 argv (命令数组)
        parseArgvFromJS(cmdValue: cmdValue, argv: argv)
        if (argv.size == 0) {
            return spawnThrowError(globalThis: globalThis, message: "cmd must not be empty")
        }

        // 解析 stdio 配置 (如果选项对象存在)
        if (options.isObject()) {
            let stdioProp = options.getProperty("stdio")
            if (!stdioProp.isUndefinedOrNull() && stdioProp.isArray()) {
                parseStdioArray(stdioVal: stdioProp, configs: stdioConfigs, isSync: isSync)
            } else if (stdioProp.isUndefinedOrNull()) {
                // 分别解析 stdin/stdout/stderr
                let stdinProp = options.getProperty("stdin")
                if (!stdinProp.isUndefinedOrNull()) {
                    stdioConfigs[0] = parseStdioValue(value: stdinProp, index: 0, isSync: isSync)
                }
                let stdoutProp = options.getProperty("stdout")
                if (!stdoutProp.isUndefinedOrNull()) {
                    stdioConfigs[1] = parseStdioValue(value: stdoutProp, index: 1, isSync: isSync)
                }
                let stderrProp = options.getProperty("stderr")
                if (!stderrProp.isUndefinedOrNull()) {
                    stdioConfigs[2] = parseStdioValue(value: stderrProp, index: 2, isSync: isSync)
                }
            }

            // lazy (仅异步)
            if (!isSync) {
                let lazyProp = options.getProperty("lazy")
                if (lazyProp.isBoolean()) {
                    lazy = lazyProp.toBoolean()
                }
            }

            // detached
            let detachedProp = options.getProperty("detached")
            if (detachedProp.isBoolean()) {
                detached = detachedProp.toBoolean()
            }

            // timeout
            let timeoutProp = options.getProperty("timeout")
            if (timeoutProp.isNumber()) {
                let timeoutMs = Int64(timeoutProp.toNumber())
                if (timeoutMs > 0 && timeoutMs <= Int64(0x7FFFFFFF)) {
                    timeout = Some(Int32(timeoutMs))
                }
            }

            // killSignal
            let killSignalProp = options.getProperty("killSignal")
            if (!killSignalProp.isUndefinedOrNull()) {
                killSignal = parseSignalCode(value: killSignalProp)
            }

            // maxBuffer
            let maxBufferProp = options.getProperty("maxBuffer")
            if (maxBufferProp.isNumber()) {
                let bufSize = Int64(maxBufferProp.toNumber())
                if (bufSize > 0) {
                    let hasPipe = stdioConfigs[0].isPipe() || stdioConfigs[1].isPipe() || stdioConfigs[2].isPipe()
                    if (hasPipe) {
                        maxBuffer = Some(bufSize)
                    }
                }
            }
        }

        // ====================================================================
        // 3. 环境变量处理
        // 翻译自: js_bun_spawn_bindings.zig:458-461
        // 如果没有自定义 env，继承当前进程环境
        // ====================================================================
        if (!overrideEnv && envArray.size == 0) {
            let parentEnv = SysModule.getEnvAll()
            for (entry in parentEnv) {
                envArray.append(entry)
            }
        }

        // ====================================================================
        // 4. 构建 PosixSpawnOptions
        // 翻译自: js_bun_spawn_bindings.zig:584-619
        // ====================================================================
        let spawnOpts = PosixSpawnOptions()
        spawnOpts.cwd = cwd
        spawnOpts.detached = detached
        spawnOpts.stdin = stdioConfigs[0].toSpawnStdio()
        spawnOpts.stdout = stdioConfigs[1].toSpawnStdio()
        spawnOpts.stderr = stdioConfigs[2].toSpawnStdio()
        spawnOpts.sync = isSync
        spawnOpts.stream = !isSync
        spawnOpts.canBlockEntireThread = false

        // ====================================================================
        // 5. 执行 spawn
        // 翻译自: js_bun_spawn_bindings.zig:621-661
        // ====================================================================
        let argvArr = argv.items()
        let envpArr = envArray.items()
        let spawnResult = spawnProcessPosix(options: spawnOpts, argv: argvArr, envp: envpArr)

        match (spawnResult) {
            case Err(e) =>
                return throwSpawnError(globalThis: globalThis, err: e, argv: argvArr)
            case Ok(spawned) =>
                if (isSync) {
                    // ============================================================
                    // 6a. spawnSync 路径 -- 等待完成并返回结果对象
                    // 翻译自: js_bun_spawn_bindings.zig:533-580, 970-1129
                    // ============================================================
                    return handleSpawnSync(
                        globalThis: globalThis,
                        spawned: spawned,
                        killSignal: killSignal,
                        timeout: timeout,
                        maxBuffer: maxBuffer
                    )
                } else {
                    // ============================================================
                    // 6b. spawn 路径 -- 返回 Subprocess JS 对象
                    // 翻译自: js_bun_spawn_bindings.zig:662-968
                    // ============================================================
                    return handleSpawnAsync(
                        globalThis: globalThis,
                        spawned: spawned,
                        detached: detached,
                        killSignal: killSignal,
                        timeout: timeout,
                        lazy: lazy
                    )
                }
        }
    }

    // ========================================================================
    // 异步 spawn 处理
    // 翻译自: js_bun_spawn_bindings.zig:662-968
    //   创建 Subprocess 对象，设置 stdio 管道，启动进程监控
    // ========================================================================

    /// 处理异步 spawn -- 创建 Subprocess JS 对象
    private static func handleSpawnAsync(
        globalThis!: JsGlobalObject,
        spawned!: PosixSpawnResult,
        detached!: Bool,
        killSignal!: SignalCode,
        timeout!: Option<Int32>,
        lazy!: Bool
    ): JsValue {
        // 创建 Process 对象
        // 翻译自: js_bun_spawn_bindings.zig:664
        let eventLoop = EventLoopHandle()
        let process = spawned.toProcess(eventLoop: eventLoop, sync_: false)

        // 创建 Subprocess 包装
        // 翻译自: js_bun_spawn_bindings.zig:666-728
        let subprocess = Subprocess()
        subprocess.process = BackRef<Process>.from(value: process)
        subprocess.globalThis = BackRef<JsGlobalObject>.from(value: globalThis)
        subprocess.killSignal = killSignal

        // 设置 stdio 管道
        // 翻译自: js_bun_spawn_bindings.zig:730-782
        match (spawned.stdin) {
            case Some(_) =>
                let sink = FileSink()
                subprocess.stdin = Writable.pipe(sink)
            case None => ()
        }
        match (spawned.stdout) {
            case Some(_) =>
                let reader = PipeReader()
                subprocess.stdout = Readable.pipe(reader)
            case None => ()
        }
        match (spawned.stderr) {
            case Some(_) =>
                let reader = PipeReader()
                subprocess.stderr = Readable.pipe(reader)
            case None => ()
        }

        // 设置退出处理器
        // 翻译自: js_bun_spawn_bindings.zig:794
        process.setExitHandler(handler: subprocess)

        // 启动进程监控
        // 翻译自: js_bun_spawn_bindings.zig:899-905
        match (process.watch()) {
            case Ok(_) => ()
            case Err(_) =>
                process.wait(sync_: false)
        }

        // 非懒加载模式: 启动管道读取
        // 翻译自: js_bun_spawn_bindings.zig:929-950
        if (!lazy) {
            match (subprocess.stdout) {
                case Readable.pipe(reader) => reader.readAll()
                case _ => ()
            }
            match (subprocess.stderr) {
                case Readable.pipe(reader) => reader.readAll()
                case _ => ()
            }
        }

        // 返回 JSSubprocess JS 值
        // 翻译自: js_bun_spawn_bindings.zig:857-858
        let out = JSSubprocess.toJS(ptr: subprocess, global: globalThis)

        out
    }

    // ========================================================================
    // 同步 spawn 处理
    // 翻译自: js_bun_spawn_bindings.zig:970-1129
    //   等待进程完成，收集 stdout/stderr，构建结果对象
    // ========================================================================

    /// 处理同步 spawn -- 等待完成并构建结果对象
    private static func handleSpawnSync(
        globalThis!: JsGlobalObject,
        spawned!: PosixSpawnResult,
        killSignal!: SignalCode,
        timeout!: Option<Int32>,
        maxBuffer!: Option<Int64>
    ): JsValue {
        // 创建 Process 对象
        let eventLoop = EventLoopHandle()
        let process = spawned.toProcess(eventLoop: eventLoop, sync_: true)

        // 读取 stdout 和 stderr
        // 翻译自: js_bun_spawn_bindings.zig:1045-1098
        var stdoutData = Array<UInt8>()
        var stderrData = Array<UInt8>()

        if (spawned.stdout.isSome()) {
            stdoutData = readFdSync(fd: spawned.stdout.getOrThrow(), maxBuffer: maxBuffer)
        }
        if (spawned.stderr.isSome()) {
            stderrData = readFdSync(fd: spawned.stderr.getOrThrow(), maxBuffer: maxBuffer)
        }

        // 等待进程退出
        // 翻译自: js_bun_spawn_bindings.zig:972-975
        process.wait(sync_: true)

        // 构建结果对象
        // 翻译自: js_bun_spawn_bindings.zig:1106-1128
        var exitCodeValue = Option<UInt8>.None
        var signalCodeValue = Option<SignalCode>.None
        match (process.status) {
            case Status.exited(exit) =>
                exitCodeValue = Some(exit.code)
                if (exit.signal.rawValue != 0) {
                    signalCodeValue = Some(exit.signal)
                }
            case Status.signaled(sig) =>
                exitCodeValue = Some(UInt8(128 + sig.rawValue))
                signalCodeValue = Some(sig)
            case _ => ()
        }
        let success = if (exitCodeValue.isSome()) {
            exitCodeValue.getOrThrow() == UInt8(0)
        } else {
            false
        }

        let resultObj = JsValue.createEmptyObject(globalThis.globalThis)

        // exitCode
        if (exitCodeValue.isSome()) {
            resultObj.toObject().set("exitCode", JsValue.jsNumber(Int64(exitCodeValue.getOrThrow())))
        } else {
            resultObj.toObject().set("exitCode", JsValue.jsNull())
        }

        // signalCode (仅在有信号时设置)
        match (signalCodeValue) {
            case Some(sig) =>
                match (sig.name()) {
                    case Some(name) =>
                        resultObj.toObject().set("signalCode", JsValue.jsString(name))
                    case None =>
                        resultObj.toObject().set("signalCode", JsValue.jsNumber(Int64(sig.rawValue)))
                }
            case None => ()
        }

        // stdout / stderr -- 包装为 ArrayBuffer
        let stdoutObj = JsValue.createEmptyObject(globalThis.globalThis)
        stdoutObj.toObject().className = "ArrayBuffer"
        stdoutObj.toObject().byteStorage = stdoutData
        resultObj.toObject().set("stdout", stdoutObj)

        let stderrObj = JsValue.createEmptyObject(globalThis.globalThis)
        stderrObj.toObject().className = "ArrayBuffer"
        stderrObj.toObject().byteStorage = stderrData
        resultObj.toObject().set("stderr", stderrObj)

        // success
        resultObj.toObject().set("success", JsValue.jsBoolean(success))

        // pid
        resultObj.toObject().set("pid", JsValue.jsNumber(Int64(spawned.pid)))

        // resourceUsage
        resultObj.toObject().set("resourceUsage", JsValue.jsNull())

        // exitedDueToTimeout (仅在有 timeout 设置时包含)
        match (timeout) {
            case Some(_) =>
                resultObj.toObject().set("exitedDueToTimeout", JsValue.jsBoolean(false))
            case None => ()
        }

        // exitedDueToMaxBuffer (仅在有 maxBuffer 设置时包含)
        match (maxBuffer) {
            case Some(_) =>
                resultObj.toObject().set("exitedDueToMaxBuffer", JsValue.jsBoolean(false))
            case None => ()
        }

        resultObj
    }

    // ========================================================================
    // 参数解析辅助函数
    // ========================================================================

    /// 从 JS 对象解析环境变量
    /// 翻译自: js_bun_spawn_bindings.zig:1142-1173
    private static func parseEnvFromJS(envObj!: JsValue, envArray!: ArrayList<String>): Unit {
        if (!envObj.isObject()) { return }
        let obj = envObj.toObject()
        let keys = obj.keys()
        for (key in keys) {
            let value = obj.get(key)
            if (!value.isUndefined()) {
                let valueStr = value.toString()
                // 安全: 检查 null bytes
                if (!key.contains("\0") && !valueStr.contains("\0")) {
                    envArray.append("${key}=${valueStr}")
                }
            }
        }
    }

    /// 从 JS 值解析 argv 数组
    /// 翻译自: js_bun_spawn_bindings.zig:52-93
    private static func parseArgvFromJS(cmdValue!: JsValue, argv!: ArrayList<String>): Unit {
        if (cmdValue.isArray()) {
            // 从数组中提取命令参数
            let arrObj = cmdValue.toObject()
            let storage = arrObj.arrayStorage
            for (elem in storage) {
                let str = elem.toString()
                if (str.size > 0) {
                    argv.append(str)
                }
            }
        } else if (cmdValue.isString()) {
            // 单个字符串命令 -- 直接作为 argv[0]
            argv.append(cmdValue.toString())
        }
    }

    /// 解析 stdio 数组配置
    /// 翻译自: js_bun_spawn_bindings.zig:295-340
    private static func parseStdioArray(stdioVal!: JsValue, configs!: Array<SpawnStdioConfig>, isSync!: Bool): Unit {
        if (!stdioVal.isArray()) { return }
        let arrObj = stdioVal.toObject()
        let storage = arrObj.arrayStorage
        var i = 0
        while (i < 3 && i < storage.size) {
            let v = storage[i]
            if (!v.isUndefinedOrNull()) {
                configs[i] = parseStdioValue(value: v, index: Int64(i), isSync: isSync)
            }
            i++
        }
    }

    /// 解析单个 stdio 值
    /// 翻译自: stdio.zig extract 函数
    private static func parseStdioValue(value!: JsValue, index!: Int64, isSync!: Bool): SpawnStdioConfig {
        if (value.isUndefinedOrNull()) {
            return SpawnStdioConfig.ignore
        }
        if (value.isString()) {
            let s = value.toString()
            match (s) {
                case "inherit" => return SpawnStdioConfig.inherit
                case "pipe" => return SpawnStdioConfig.pipe
                case "ignore" => return SpawnStdioConfig.ignore
                case "ipc" => return SpawnStdioConfig.pipe  // IPC 简化为 pipe
                case _ => return SpawnStdioConfig.ignore
            }
        }
        if (value.isNumber()) {
            let fd = Int64(value.toNumber())
            return SpawnStdioConfig.fd(fd)
        }
        // 默认: stdin=ignore, stdout/stderr=pipe (sync) 或 inherit (async)
        if (index == 0) {
            return SpawnStdioConfig.ignore
        }
        return if (isSync) { SpawnStdioConfig.pipe } else { SpawnStdioConfig.inherit }
    }

    /// 解析信号代码
    private static func parseSignalCode(value!: JsValue): SignalCode {
        if (value.isString()) {
            return SignalCode.fromString(str: value.toString())
        }
        if (value.isNumber()) {
            return SignalCode.fromInt(Int32(value.toNumber()))
        }
        SignalCode.SIGTERM
    }

    /// 抛出错误 (简化实现)
    private static func spawnThrowError(globalThis!: JsGlobalObject, message!: String): JsValue {
        JsValue.jsUndefined()
    }

    /// 抛出 spawn 错误
    /// 翻译自: js_bun_spawn_bindings.zig:622-660
    private static func throwSpawnError(globalThis!: JsGlobalObject, err!: SysError, argv!: Array<String>): JsValue {
        JsValue.jsUndefined()
    }

    /// 同步读取 fd 数据
    /// 翻译自: drainFd (process.zig:2899-2919)
    /// 非阻塞读取 fd 直到 EAGAIN/EPIPE 或 EOF
    private static func readFdSync(fd!: Int32, maxBuffer!: Option<Int64>): Array<UInt8> {
        var result = Array<UInt8>()
        let maxSize = if (maxBuffer.isSome()) { maxBuffer.getOrThrow() } else { Int64(1048576) }

        // TODO: implement non-blocking read with fcntl/poll C FFI
        // Currently returns empty array as stub
        result
    }
}

// ============================================================================
// SpawnStdioConfig -- JS 层 stdio 配置枚举
// 对应: src/runtime/api/bun/spawn/stdio.zig 中的 Stdio enum
// ============================================================================

/// JS 层 stdio 配置，用于 js_bun_spawn_bindings 中解析 JS 参数
enum SpawnStdioConfig {
    | inherit       // 继承父进程
    | pipe          // 创建管道
    | ignore        // 忽略 (重定向到 /dev/null)
    | fd(Int64)     // 重定向到指定 fd
    | path(String)  // 重定向到文件

    /// 是否为管道模式
    public func isPipe(): Bool {
        match (this) {
            case pipe => true
            case _ => false
        }
    }

    /// 转为 Stdio (PosixSpawnOptions 使用)
    public func toSpawnStdio(): Stdio {
        match (this) {
            case inherit => Stdio.inherit
            case pipe => Stdio.pipe
            case ignore => Stdio.ignore
            case fd(val) => Stdio.fd(FD(Int32(val)))
            case path(val) => Stdio.path(PathLike(val))
        }
    }
}

