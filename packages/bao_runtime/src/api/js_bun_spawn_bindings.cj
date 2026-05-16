// 严格翻译自: src/runtime/api/bun/js_bun_spawn_bindings.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_sys.*

// ============================================================================
// js_bun_spawn_bindings - Bun.spawn() 和 Bun.spawnSync() 的 JS 绑定
// 对应 Bun: src/runtime/api/bun/js_bun_spawn_bindings.zig
// ============================================================================

/// Bun.spawn() 的 JS 绑定
public class JsBunSpawnBindings {

    // ========================================================================
    // spawn - Bun.spawn()
    // ========================================================================

    /// Bun.spawn() 入口
    public static func spawn(globalThis: JsGlobalObject, args: JsValue, secondaryArgsValue: ?JsValue): JsValue {
        return spawnMaybeSync(globalThis, args, secondaryArgsValue, false)
    }

    // ========================================================================
    // spawnSync - Bun.spawnSync()
    // ========================================================================

    /// Bun.spawnSync() 入口
    public static func spawnSync(globalThis: JsGlobalObject, args: JsValue, secondaryArgsValue: ?JsValue): JsValue {
        return spawnMaybeSync(globalThis, args, secondaryArgsValue, true)
    }

    // ========================================================================
    // spawnMaybeSync - 共享实现
    // ========================================================================

    /// spawnMaybeSync - spawn 和 spawnSync 的共享实现
    /// 对应 Bun: js_bun_spawn_bindings.zig spawnMaybeSync
    public static func spawnMaybeSync(globalThis: JsGlobalObject, args_: JsValue, secondaryArgsValue: ?JsValue, isSync: Bool): JsValue {
        if (isSync) {
            // 检查栈溢出
            if (!StackCheck.init().isSafeToRecurse()) {
                return globalThis.throwStackOverflow()
            }
        }

        var arena = ArenaAllocator.init(default_allocator)
        defer arena.deinit()
        let allocator = arena.allocator()

        var overrideEnv: Bool = false
        var envArray: ArrayList<?String> = ArrayList<?String>()
        var jscVm = globalThis.bunVm()

        var cwd: String = jscVm.transpiler.fs.topLevelDir

        var stdio = [3]Stdio{
            Stdio.ignore(),
            Stdio.pipe(),
            Stdio.inherit(),
        }

        if (isSync) {
            stdio[1] = Stdio.pipe()
            stdio[2] = Stdio.pipe()
        }

        var lazy: Bool = false
        var onExitCallback: JsValue = JsValue.zero
        var onDisconnectCallback: JsValue = JsValue.zero
        var path: String = jscVm.transpiler.env.get("PATH") ?? ""
        var argv = ArrayList<?String>(allocator)
        var cmdValue: JsValue = JsValue.zero
        var detached: Bool = false
        var args = args_
        var maybeIpcMode: ?IpcMode = if (!isSync) None else ()
        var ipcCallback: JsValue = JsValue.zero
        var extraFds = ArrayList<SpawnStdio>(default_allocator)
        defer extraFds.deinit()
        var argv0: ?String = None
        var ipcChannel: Int32 = -1
        var timeout: ?Int32 = None
        var killSignal: SignalCode = SignalCode.default
        var maxBuffer: ?Int64 = None
        var abortSignal: ?AbortSignal = None
        var terminalInfo: ?TerminalCreateResult = None
        var existingTerminal: ?Terminal = None
        var terminalJsValue: JsValue = JsValue.zero

        // 清理 abort_signal 和 terminal
        defer {
            if (let Some(signal) = abortSignal) {
                signal.unref()
            }
            if (let Some(info) = terminalInfo) {
                info.terminal.thisValue.downgrade()
                info.terminal.flags.finalized = true
                info.terminal.closeInternal()
            }
        }

        // 解析参数
        if (args.isEmptyOrUndefinedOrNull()) {
            return globalThis.throwInvalidArguments("cmd must be an array")
        }

        let argsType = args.jsType()
        if (argsType.isArray()) {
            cmdValue = args
            args = secondaryArgsValue ?? JsValue.zero
        } else if (!args.isObject()) {
            return globalThis.throwInvalidArguments("cmd must be an array")
        } else if (let cmdValue_ = try args.getTruthy(globalThis, "cmd")) {
            cmdValue = cmdValue_
        } else {
            return globalThis.throwInvalidArguments("cmd must be an array")
        }

        if (args.isObject()) {
            // argv0
            if (let argv0_ = try args.getTruthy(globalThis, "argv0")) {
                let argv0Str = try argv0_.getZigString(globalThis)
                if (argv0Str.len > 0) {
                    argv0 = try argv0Str.toOwnedSliceZ(allocator)
                }
            }

            // cwd (必须在搜索可执行文件之前更新)
            if (let cwd_ = try args.getTruthy(globalThis, "cwd")) {
                let cwdStr = try cwd_.getZigString(globalThis)
                if (cwdStr.len > 0) {
                    cwd = try cwdStr.toOwnedSliceZ(allocator)
                }
            }
        }

        if (args != JsValue.zero && args.isObject()) {
            // terminal 仅支持异步 spawn
            if (isSync) {
                if (try args.getTruthy(globalThis, "terminal") != None) {
                    return globalThis.throwInvalidArguments("terminal option is only supported for Bun.spawn, not Bun.spawnSync")
                }
            }

            // IPC (仅异步)
            if (!isSync) {
                if (let val = try args.getTruthy(globalThis, "ipc")) {
                    if (val.isCell() && val.isCallable()) {
                        // 解析 IPC 模式
                        maybeIpcMode = IpcMode.advanced
                        if (let modeVal = try args.getTruthy(globalThis, "serialization")) {
                            if (modeVal.isString()) {
                                maybeIpcMode = try IpcMode.fromJs(globalThis, modeVal) ?? {
                                    return globalThis.throwInvalidArguments("serialization must be \"json\" or \"advanced\"")
                                }
                            } else {
                                if (!globalThis.hasException()) {
                                    return globalThis.throwInvalidArgumentType("spawn", "serialization", "string")
                                }
                                return JsValue.zero
                            }
                        }
                        ipcCallback = val.withAsyncContextIfNeeded(globalThis)
                    }
                }
            }

            // abort signal
            if (let signalVal = try args.getTruthy(globalThis, "signal")) {
                if (let signal = signalVal.as(AbortSignal)) {
                    abortSignal = signal.ref()
                } else {
                    return globalThis.throwInvalidArgumentTypeValue("signal", "AbortSignal", signalVal)
                }
            }

            // onDisconnect
            if (let onDisconnect_ = try args.getTruthy(globalThis, "onDisconnect")) {
                if (!onDisconnect_.isCell() || !onDisconnect_.isCallable()) {
                    return globalThis.throwInvalidArguments("onDisconnect must be a function or undefined")
                }
                onDisconnectCallback = if (isSync) {
                    onDisconnect_
                } else {
                    onDisconnect_.withAsyncContextIfNeeded(globalThis)
                }
            }

            // onExit
            if (let onExit_ = try args.getTruthy(globalThis, "onExit")) {
                if (!onExit_.isCell() || !onExit_.isCallable()) {
                    return globalThis.throwInvalidArguments("onExit must be a function or undefined")
                }
                onExitCallback = if (isSync) {
                    onExit_
                } else {
                    onExit_.withAsyncContextIfNeeded(globalThis)
                }
            }

            // env
            if (let envArg = try args.getTruthy(globalThis, "env")) {
                envArg.ensureStillAlive()
                let object = envArg.getObject() ?? {
                    return globalThis.throwInvalidArguments("env must be an object")
                }
                overrideEnv = true
                var newPath: String = ""
                var envpManaged = envArray.toManaged(allocator)
                try appendEnvpFromJs(globalThis, object, envpManaged, newPath)
                envArray = envpManaged.moveToUnmanaged()
                path = newPath
            }

            // argv
            try getArgv(globalThis, cmdValue, path, cwd, argv0, allocator, argv)

            // stdio
            if (let stdioVal = try args.get(globalThis, "stdio")) {
                if (!stdioVal.isEmptyOrUndefinedOrNull()) {
                    if (stdioVal.jsType().isArray()) {
                        var stdioIter = try stdioVal.arrayIterator(globalThis)
                        var i: Int32 = 0
                        while (let value = try stdioIter.next()) {
                            try stdio[i].extract(globalThis, i, value, isSync)
                            if (i == 2) {
                                break
                            }
                            i += 1
                        }
                        i += 1

                        while (let value = try stdioIter.next()) {
                            var newItem = Stdio.ignore()
                            try newItem.extract(globalThis, i, value, isSync)

                            let opt = match (newItem.asSpawnOption(i)) {
                                case SpawnOption.result(let o) => o
                                case SpawnOption.err(let e) => return e.throwJs(globalThis)
                            }
                            if (opt == SpawnOption.ipc()) {
                                ipcChannel = Int32(extraFds.items.length)
                            }
                            try extraFds.append(opt)
                            i += 1
                        }
                    } else {
                        return globalThis.throwInvalidArguments("stdio must be an array")
                    }
                }
            } else {
                if (let value = try args.get(globalThis, "stdin")) {
                    try stdio[0].extract(globalThis, 0, value, isSync)
                }
                if (let value = try args.get(globalThis, "stderr")) {
                    try stdio[2].extract(globalThis, 2, value, isSync)
                }
                if (let value = try args.get(globalThis, "stdout")) {
                    try stdio[1].extract(globalThis, 1, value, isSync)
                }
            }

            // lazy (仅异步)
            if (!isSync) {
                if (let lazyVal = try args.get(globalThis, "lazy")) {
                    if (lazyVal.isBoolean()) {
                        lazy = lazyVal.toBoolean()
                    }
                }
            }

            // detached
            if (let detachedVal = try args.get(globalThis, "detached")) {
                if (detachedVal.isBoolean()) {
                    detached = detachedVal.toBoolean()
                }
            }

            // timeout
            if (let timeoutValue = try args.get(globalThis, "timeout")) {
                if (timeoutValue != JsValue.null) {
                    if (timeoutValue.isNumber() && timeoutValue.asNumber().isPositiveInf()) {
                        // Infinity: 无超时
                    } else {
                        let timeoutInt = try globalThis.validateIntegerRange(timeoutValue, UInt64, 0, ValidationArgs(min: 0, fieldName: "timeout"))
                        if (timeoutInt > 0) {
                            timeout = Int32(timeoutInt)
                        }
                    }
                }
            }

            // killSignal
            if (let val = try args.get(globalThis, "killSignal")) {
                killSignal = try SignalCode.fromJs(val, globalThis)
            }

            // maxBuffer
            if (let val = try args.get(globalThis, "maxBuffer")) {
                if (val.isNumber() && val.isFinite()) {
                    let value = try val.coerce(Int64, globalThis)
                    if (value > 0 && (stdio[0].isPiped() || stdio[1].isPiped() || stdio[2].isPiped())) {
                        maxBuffer = value
                    }
                }
            }

            // terminal (仅异步)
            if (!isSync) {
                if (let terminalVal = try args.getTruthy(globalThis, "terminal")) {
                    if (Terminal.fromJs(terminalVal)) {
                        let terminal = Terminal.fromJs(terminalVal).getOrThrow()
                        if (terminal.flags.closed) {
                            return globalThis.throwInvalidArguments("terminal is closed")
                        }
                        if (terminal.flags.inlineSpawned) {
                            return globalThis.throwInvalidArguments("terminal was created inline by a previous spawn and cannot be reused")
                        }
                        existingTerminal = terminal
                        terminalJsValue = terminalVal
                    } else if (terminalVal.isObject()) {
                        let termOptions = try Terminal.Options.parseFromJs(globalThis, terminalVal)
                        terminalInfo = Terminal.createFromSpawn(globalThis, termOptions) catch {
                            err => match (err) {
                                case Error.OpenPtyFailed => return globalThis.throw("Failed to open PTY")
                                case Error.DupFailed => return globalThis.throw("Failed to duplicate PTY file descriptor")
                                case Error.NotSupported => return globalThis.throw("PTY not supported on this platform")
                                case Error.WriterStartFailed => return globalThis.throw("Failed to start terminal writer")
                                case Error.ReaderStartFailed => return globalThis.throw("Failed to start terminal reader")
                            }
                        }
                    } else {
                        return globalThis.throwInvalidArguments("terminal must be a Terminal object or options object")
                    }

                    // 设置 stdio 为 terminal fd
                    let terminal = existingTerminal ?? terminalInfo.?.terminal
                    let slaveFd = terminal.getSlaveFd()
                    stdio[0] = Stdio.fd(slaveFd)
                    stdio[1] = Stdio.fd(slaveFd)
                    stdio[2] = Stdio.fd(slaveFd)
                }
            }
        } else {
            try getArgv(globalThis, cmdValue, path, cwd, argv0, allocator, argv)
        }

        // 构建 envp
        if (!overrideEnv && envArray.items.length == 0) {
            envArray.items = jscVm.transpiler.env.map.createNullDelimitedEnvMap(allocator) catch {
                err => return globalThis.throwError(err, "in Bun.spawn")
            }
            envArray.capacity = envArray.items.length
        }

        // memfd 优化 (Linux)
        for (fdIndex in 0..stdio.length) {
            if (stdio[fdIndex].canUseMemfd(isSync, fdIndex > 0 && maxBuffer != None)) {
                if (stdio[fdIndex].useMemfd(fdIndex)) {
                    jscVm.counters.mark(Counter.spawnMemfd)
                }
            }
        }
        var shouldCloseMemfd: Bool = Environment.isLinux

        defer {
            if (shouldCloseMemfd) {
                for (fdIndex in 0..stdio.length) {
                    match (stdio[fdIndex]) {
                        case Stdio.memfd(let m) =>
                            m.close()
                            stdio[fdIndex] = Stdio.ignore()
                        default => ()
                    }
                }
            }
        }

        // IPC 环境变量设置
        var ipcEnvBuf: Array<Byte> = Array<Byte>(32)
        if (!isSync) {
            if (let ipcMode = maybeIpcMode) {
                envArray.ensureUnusedCapacity(allocator, 3) catch {
                    err => return globalThis.throwError(err, "in Bun.spawn")
                }
                let ipcFd: Int32 = {
                    if (ipcChannel == -1) {
                        ipcChannel = Int32(extraFds.items.length)
                        let fd: Int32 = ipcChannel + 3
                        let opt = match (Stdio.ipc().asSpawnOption(fd)) {
                            case SpawnOption.result(let o) => o
                            case SpawnOption.err(let e) => return e.throwJs(globalThis)
                        }
                        try extraFds.append(opt)
                        break fd
                    } else {
                        break Int32(ipcChannel + 3)
                    }
                }

                let pipeEnv = "NODE_CHANNEL_FD=" + ipcFd.toString()
                envArray.append(pipeEnv)
                envArray.append("NODE_CHANNEL_SERIALIZATION_MODE=" + ipcMode.tagName())
            }
        }

        try envArray.append(allocator, None)
        try argv.append(None)

        // spawnSync 的 stdio 转 sync 模式
        if (isSync) {
            for ((io, i) in stdio) {
                io.toSync(i)
            }
        }

        // 快速路径检查
        let canBlockEntireThread = isSync &&
            abortSignal == None &&
            timeout == None &&
            maxBuffer == None &&
            !stdio[0].isPiped() &&
            !stdio[1].isPiped() &&
            !stdio[2].isPiped() &&
            extraFds.items.length == 0 &&
            !jscVm.autoKiller.enabled &&
            !jscVm.jscVm.hasExecutionTimeLimit() &&
            !jscVm.isInspectorEnabled() &&
            !FeatureFlag.disableSpawnSyncFastPath.get()

        // 获取事件循环
        let eventLoop: EventLoop = if (isSync) {
            jscVm.rareData().spawnSyncEventLoop(jscVm).eventLoop
        } else {
            jscVm.eventLoop()
        }

        if (isSync) {
            jscVm.rareData().spawnSyncEventLoop(jscVm).prepare(jscVm)
        }

        defer {
            if (isSync) {
                jscVm.rareData().spawnSyncEventLoop(jscVm).cleanup(jscVm, jscVm.eventLoop())
            }
        }

        let loopHandle = EventLoopHandle.init(eventLoop)

        // 构建 spawn 选项
        let spawnOptions = SpawnOptions(
            cwd: cwd,
            detached: detached,
            stdin: match (stdio[0].asSpawnOption(0)) {
                case SpawnOption.result(let o) => o
                case SpawnOption.err(let e) => return e.throwJs(globalThis)
            },
            stdout: match (stdio[1].asSpawnOption(1)) {
                case SpawnOption.result(let o) => o
                case SpawnOption.err(let e) => return e.throwJs(globalThis)
            },
            stderr: match (stdio[2].asSpawnOption(2)) {
                case SpawnOption.result(let o) => o
                case SpawnOption.err(let e) => return e.throwJs(globalThis)
            },
            extraFds: extraFds.items,
            argv0: argv0,
            canBlockEntireThread: canBlockEntireThread,
            ptySlaveFd: if (terminalInfo != None) {
                terminalInfo.?.terminal.getSlaveFd().native()
            } else {
                -1
            },
        )

        // 执行 spawn
        var spawned = spawnProcess(
            spawnOptions,
            argv.items.ptr,
            envArray.items.ptr,
        ) catch {
            err => match (err) {
                case Error.EMFILE | Error.ENFILE =>
                    spawnOptions.deinit()
                    let displayPath: String = if (argv.items.length > 0 && argv.items[0] != None) {
                        sliceTo(argv.items[0]!, 0)
                    } else {
                        ""
                    }
                    var systemError = SystemError.fromCode(
                        if (err == Error.EMFILE) Errno.MFILE else Errno.NFILE,
                        Syscall.posixSpawn,
                    ).withPath(displayPath).toSystemError()
                    systemError.errno = if (err == Error.EMFILE) -UV_E.MFILE else -UV_E.NFILE
                    return globalThis.throwValue(systemError.toErrorInstance(globalThis))
                default =>
                    spawnOptions.deinit()
                    return globalThis.throwError(err, ": failed to spawn process")
            }
        }

        match (spawned) {
            case SpawnResult.err(let err) =>
                spawnOptions.deinit()
                match (err.getErrno()) {
                    case Errno.ACCES | Errno.NOENT | Errno.PERM | Errno.ISDIR | Errno.NOTDIR =>
                        let displayPath: String = if (argv.items.length > 0 && argv.items[0] != None) {
                            sliceTo(argv.items[0]!, 0)
                        } else {
                            ""
                        }
                        if (!displayPath.isEmpty()) {
                            var systemError = err.withPath(displayPath).toSystemError()
                            if (err.getErrno() == Errno.NOENT) {
                                systemError.errno = -UV_E.NOENT
                            }
                            return globalThis.throwValue(systemError.toErrorInstance(globalThis))
                        }
                    default => ()
                }
                return globalThis.throwValue(try err.toJs(globalThis))
            case SpawnResult.result(let result) => spawned = result
        }

        let process = spawned.toProcess(loopHandle, isSync)

        var subprocess = Subprocess(
            refCount: RefCount.initExactRefs(2),
            globalThis: globalThis,
            process: process,
            pidRusage: None,
            stdin: Stdio.ignore(),
            stdout: Stdio.ignore(),
            stderr: Stdio.ignore(),
            stdioPipes: extraFds.moveToUnmanaged(),
            ipcData: None,
            flags: SubprocessFlags(isSync: isSync),
            killSignal: killSignal,
        )

        MaxBuf.createForSubprocess(subprocess, subprocess.stderrMaxbuf, maxBuffer)
        MaxBuf.createForSubprocess(subprocess, subprocess.stdoutMaxbuf, maxBuffer)

        var promiseForStream: JsValue = JsValue.zero

        subprocess = Subprocess(
            globalThis: globalThis,
            process: process,
            pidRusage: None,
            stdin: Stdio.ignore(),
            stdout: Stdio.ignore(),
            stderr: Stdio.ignore(),
            refCount: RefCount.initExactRefs(2),
            stdioPipes: spawned.extraPipes.moveToUnmanaged(),
            ipcData: None,
            flags: SubprocessFlags(isSync: isSync),
            killSignal: killSignal,
            stderrMaxbuf: subprocess.stderrMaxbuf,
            stdoutMaxbuf: subprocess.stdoutMaxbuf,
            terminal: existingTerminal ?? (if (terminalInfo != None) terminalInfo.?.terminal else None),
        )

        // 初始化 stdin
        subprocess.stdin = try Writable.init(stdio[0], eventLoop, subprocess, spawned.stdin, promiseForStream) catch {
            err =>
                if (spawned.stdout != None) {
                    spawned.stdout.close()
                }
                if (spawned.stderr != None) {
                    spawned.stderr.close()
                }
                subprocess.finalizeStreams()
                subprocess.process.detach()
                subprocess.process.deref()
                MaxBuf.removeFromSubprocess(subprocess.stdoutMaxbuf)
                MaxBuf.removeFromSubprocess(subprocess.stderrMaxbuf)
                subprocess.deref()
                subprocess.deref()
                if (err == Error.JsError) {
                    return Error.JsError
                }
                return globalThis.throwOutOfMemory()
        }

        subprocess.stdout = Readable.init(stdio[1], eventLoop, subprocess, spawned.stdout, jscVm.allocator, subprocess.stdoutMaxbuf, isSync)
        subprocess.stderr = Readable.init(stdio[2], eventLoop, subprocess, spawned.stderr, jscVm.allocator, subprocess.stderrMaxbuf, isSync)

        // 终端: 关闭父进程的 slave_fd
        if (let info = terminalInfo) {
            terminalJsValue = info.jsValue
            info.terminal.closeSlaveFd()
            subprocess.flags.ownsTerminal = true
            terminalInfo = None
        }

        subprocess.process.setExitHandler(subprocess)

        promiseForStream.ensureStillAlive()
        subprocess.flags.isStdinAReadableStream = (promiseForStream != JsValue.zero)

        if (promiseForStream != JsValue.zero && !globalThis.hasException()) {
            if (let err = promiseForStream.toError()) {
                let _ = globalThis.throwValue(err)
            }
        }

        if (globalThis.hasException()) {
            let err = globalThis.takeException(Error.JsError)
            // 终止进程
            let _ = subprocess.tryKill(subprocess.killSignal)

            if (globalThis.hasException()) {
                return Error.JsError
            }

            return globalThis.throwValue(err)
        }

        // 设置 IPC
        if (!isSync && maybeIpcMode != None) {
            if (let socket = jscVm.rareData().spawnIpcGroup(jscVm).fromFd(
                .spawnIpc,
                None,
                sizeOf<IpcSendQueue>(),
                spawned.extraPipes.items[Int64(ipcChannel)].fd().cast(),
                true,
            )) {
                subprocess.ipcData = IpcData.init(maybeIpcMode.getOrThrow(), IpcDataContext.subprocess(subprocess), IpcState.uninitialized)
            }
        }

        if (let ipcData = subprocess.ipcData) {
            // 写入版本包
            ipcData.writeVersionPacket(globalThis)
            subprocess.stdioPipes.items[Int64(ipcChannel)] = SpawnPipe.unavailable
        }

        // stdin pipe 信号
        if (subprocess.stdin == SubprocessStdio.pipe && promiseForStream == JsValue.zero) {
            subprocess.stdin.pipe.signal = Signal.init(subprocess.stdin)
        }

        // 创建 JS 值
        let out = if (!isSync) {
            subprocess.toJs(globalThis)
        } else {
            JsValue.zero
        }
        if (out != JsValue.zero) {
            subprocess.thisValue.setWeak(out)
            subprocess.updateHasPendingActivity()
        }

        var sendExitNotification: Bool = false

        if (!isSync) {
            // 超时计时器
            if (let timeoutVal = timeout) {
                subprocess.eventLoopTimer.next = Timespec.msFromNow(timeoutVal)
                globalThis.bunVm().timer.insert(subprocess.eventLoopTimer)
                subprocess.setEventLoopTimerRefd(true)
            }

            // 缓存回调
            if (onExitCallback.isCell()) {
                JSSubprocess.onExitCallbackSetCached(out, globalThis, onExitCallback)
            }
            if (onDisconnectCallback.isCell()) {
                JSSubprocess.onDisconnectCallbackSetCached(out, globalThis, onDisconnectCallback)
            }
            if (ipcCallback.isCell()) {
                JSSubprocess.ipcCallbackSetCached(out, globalThis, ipcCallback)
            }

            if (stdio[0] == Stdio.readableStream) {
                JSSubprocess.stdinSetCached(out, globalThis, stdio[0].readableStream.value)
            }

            if (terminalJsValue != JsValue.zero) {
                JSSubprocess.terminalSetCached(out, globalThis, terminalJsValue)
            }

            match (subprocess.process.watch()) {
                case WatchResult.result => ()
                case WatchResult.err =>
                    sendExitNotification = true
                    lazy = false
            }
        }

        defer {
            if (sendExitNotification) {
                if (subprocess.process.hasExited()) {
                    subprocess.process.onExit(subprocess.process.status, Rusage.zeroes())
                } else {
                    subprocess.process.wait(isSync)
                }
            }
        }

        // stdin buffer 错误检查
        if (subprocess.stdin == SubprocessStdio.buffer) {
            if (let err = subprocess.stdin.buffer.start().asErr()) {
                let _ = subprocess.tryKill(subprocess.killSignal)
                let _ = globalThis.throwValue(err.toJs(globalThis))
                return Error.JsError
            }
        }

        // 启动 stdout pipe
        if (subprocess.stdout == SubprocessStdio.pipe) {
            if (let err = subprocess.stdout.pipe.start(subprocess, eventLoop).asErr()) {
                let _ = subprocess.tryKill(subprocess.killSignal)
                let _ = globalThis.throwValue(err.toJs(globalThis))
                return Error.JsError
            }
            if ((isSync || !lazy) && subprocess.stdout == SubprocessStdio.pipe) {
                subprocess.stdout.pipe.readAll()
            }
        }

        // 启动 stderr pipe
        if (subprocess.stderr == SubprocessStdio.pipe) {
            if (let err = subprocess.stderr.pipe.start(subprocess, eventLoop).asErr()) {
                let _ = subprocess.tryKill(subprocess.killSignal)
                let _ = globalThis.throwValue(err.toJs(globalThis))
                return Error.JsError
            }
            if ((isSync || !lazy) && subprocess.stderr == SubprocessStdio.pipe) {
                subprocess.stderr.pipe.readAll()
            }
        }

        shouldCloseMemfd = false

        // 最后添加 abort 监听器
        if (let signal = abortSignal) {
            signal.pendingActivityRef()
            subprocess.abortSignal = signal.addListener(subprocess, Subprocess.onAbortSignal)
            abortSignal = None
        }

        // ========== 异步路径 ==========
        if (!isSync) {
            if (!subprocess.process.hasExited()) {
                jscVm.onSubprocessSpawn(subprocess.process)
            }
            return out
        }

        // ========== 同步路径 ==========
        if (canBlockEntireThread) {
            jscVm.counters.mark(Counter.spawnSyncBlocking)
            subprocess.process.wait(true)
        }

        match (subprocess.process.watchOrReap()) {
            case WatchResult.result =>
                // 重新添加 abort 监听器
                if (let signal = abortSignal) {
                    signal.pendingActivityRef()
                    subprocess.abortSignal = signal.addListener(subprocess, Subprocess.onAbortSignal)
                    abortSignal = None
                }
            case WatchResult.err =>
                subprocess.process.wait(true)
        }

        if (!subprocess.process.hasExited()) {
            jscVm.onSubprocessSpawn(subprocess.process)
        }

        var didTimeout: Bool = false

        // 同步事件循环
        {
            var absoluteTimespec = Timespec.epoch
            var now = Timespec.now()
            var userTimespec: Timespec = if (let timeoutMs = timeout) {
                now.addMs(timeoutMs)
            } else {
                absoluteTimespec
            }

            let hasUserTimespec = !userTimespec.eql(Timespec.epoch)
            let syncLoop = jscVm.rareData().spawnSyncEventLoop(jscVm)

            while (subprocess.computeHasPendingActivity()) {
                if (hasUserTimespec) {
                    absoluteTimespec = userTimespec
                } else {
                    absoluteTimespec = Timespec.epoch
                }
                let hasTimespec = !absoluteTimespec.eql(Timespec.epoch)

                if (subprocess.stdin == SubprocessStdio.buffer) {
                    subprocess.stdin.buffer.watch()
                }
                if (subprocess.stderr == SubprocessStdio.pipe) {
                    subprocess.stderr.pipe.watch()
                }
                if (subprocess.stdout == SubprocessStdio.pipe) {
                    subprocess.stdout.pipe.watch()
                }

                match (syncLoop.tickWithTimeout(if (hasTimespec && !didTimeout) absoluteTimespec else None)) {
                    case TickResult.completed =>
                        now = Timespec.now()
                    case TickResult.timeout =>
                        now = Timespec.now()
                        let didUserTimeout = hasUserTimespec && (absoluteTimespec.eql(userTimespec) || userTimespec.order(now) == .lt)

                        if (didUserTimeout) {
                            didTimeout = true
                            let _ = subprocess.tryKill(subprocess.killSignal)
                        }
                }
            }
        }

        if (globalThis.hasException()) {
            return JsValue.zero
        }

        subprocess.updateHasPendingActivity()

        let signalCode = subprocess.getSignalCode(globalThis)
        let exitCode = subprocess.getExitCode(globalThis)
        let stdout = try subprocess.stdout.toBufferedValue(globalThis)
        let stderr = try subprocess.stderr.toBufferedValue(globalThis)
        let resourceUsage: JsValue = if (!globalThis.hasException()) {
            try subprocess.createResourceUsageObject(globalThis)
        } else {
            JsValue.zero
        }
        let exitedDueToTimeout = didTimeout
        let exitedDueToMaxBuffer = subprocess.exitedDueToMaxbuf
        let resultPid = JsValue.jsNumberFromInt32(subprocess.pid())
        subprocess.finalize()

        let syncValue = JsValue.createEmptyObject(globalThis, 0)
        syncValue.put(globalThis, ZigString.static("exitCode"), exitCode)
        if (!signalCode.isEmptyOrUndefinedOrNull()) {
            syncValue.put(globalThis, ZigString.static("signalCode"), signalCode)
        }
        syncValue.put(globalThis, ZigString.static("stdout"), stdout)
        syncValue.put(globalThis, ZigString.static("stderr"), stderr)
        syncValue.put(globalThis, ZigString.static("success"), JsValue.jsBoolean(exitCode.isInt32() && exitCode.asInt32() == 0))
        syncValue.put(globalThis, ZigString.static("resourceUsage"), resourceUsage)
        if (timeout != None) {
            syncValue.put(globalThis, ZigString.static("exitedDueToTimeout"), if (exitedDueToTimeout) JsValue.true else JsValue.false)
        }
        if (maxBuffer != None) {
            syncValue.put(globalThis, ZigString.static("exitedDueToMaxBuffer"), if (exitedDueToMaxBuffer != None) JsValue.true else JsValue.false)
        }
        syncValue.put(globalThis, ZigString.static("pid"), resultPid)

        return syncValue
    }

    // ========================================================================
    // getArgv - 构建 argv 数组
    // ========================================================================

    /// getArgv - 构建 Bun.spawn 的 argv
    public static func getArgv(globalThis: JsGlobalObject, args: JsValue, path: String, cwd: String, argv0: String?, allocator: Allocator): ArrayList<String> {
        if (args.isEmptyOrUndefinedOrNull()) {
            globalThis.throwInvalidArguments("cmd must be an array of strings")
            return []
        }

        var cmdsArray = try args.arrayIterator(globalThis)
        if (cmdsArray.len == 0) {
            globalThis.throwInvalidArguments("cmd must not be empty")
            return []
        }

        var argv = ArrayList<String>(capacity: cmdsArray.len + 2)

        // 获取 argv0
        let argv0Result = try getArgv0(globalThis, path, cwd, argv0, cmdsArray.next()!, allocator)
        argv.append(argv0Result.arg0)

        // 添加其余参数
        var argIndex: Int = 1
        while (let value = try cmdsArray.next()) {
            let arg = try value.toBunString(globalThis)
            defer arg.deref()

            // 检查 null 字节 (安全: 防止 null 字节注入)
            if (arg.indexOfAsciiChar(0) != null) {
                globalObject.throwInvalidArguments("Argument must be a string without null bytes")
                return []
            }

            argv.append(arg.toOwnedSliceZ(allocator))
            argIndex += 1
        }

        return argv
    }

    // ========================================================================
    // getArgv0 - 解析 argv[0]
    // ========================================================================

    /// getArgv0 - 解析第一个命令参数
    public static func getArgv0(globalThis: JsGlobalObject, path: String, cwd: String, pretendArgv0: ?String, firstCmd: JsValue, allocator: Allocator): Argv0Result {
        var arg0 = try firstCmd.toSliceOrNullWithAllocator(globalThis, allocator)
        defer arg0.deinit()

        // 检查 null 字节
        if (arg0.slice().indexOfChar(0) != null) {
            globalThis.throwInvalidArguments("The argument 'args[0]' must be a string without null bytes")
            return Argv0Result(argv0: "", arg0: "")
        }

        var actualArgv0: String = ""
        let argv0ToUse: String = arg0.slice()

        // 如果命令包含 /, 不从 $PATH 搜索
        let pathToUse: String = if (argv0ToUse.contains('/')) {
            ""
        } else if (path.count > 0) {
            path
        } else {
            BUN_DEFAULT_PATH_FOR_SPAWN
        }

        if (pathToUse.count == 0) {
            actualArgv0 = allocator.dupeZ(argv0ToUse)
        } else {
            let resolved = Which.which(pathToUse, cwd, argv0ToUse) ?? {
                throwCommandNotFound(globalThis, argv0ToUse)
                return Argv0Result(argv0: "", arg0: "")
            }
            actualArgv0 = allocator.dupeZ(resolved)
        }

        return Argv0Result(
            argv0: actualArgv0,
            arg0: pretendArgv0 != null ? allocator.dupeZ(pretendArgv0.getOrThrow()) : allocator.dupeZ(arg0.slice()),
        )
    }

    /// Argv0 结果
    public struct Argv0Result {
        public var argv0: String
        public var arg0: String
    }

    // ========================================================================
    // throwCommandNotFound - 命令未找到错误
    // ========================================================================

    /// 抛出命令未找到错误
    public static func throwCommandNotFound(globalThis: JsGlobalObject, command: String): JsError {
        let err = SystemError(
            message: BunString.createFormat("Executable not found in $PATH: \"{}\"", [command]),
            code: BunString.static("ENOENT"),
            errno: -UV_E.NOENT,
            path: BunString.cloneUTF8(command),
        )
        return globalThis.throwValue(err.toErrorInstance(globalThis))
    }

    // ========================================================================
    // appendEnvpFromJS - 从 JS 对象构建环境变量数组
    // ========================================================================

    /// 从 JS 对象构建环境变量数组
    /// 对应 Bun: js_bun_spawn_bindings.zig appendEnvpFromJS
    public static func appendEnvpFromJs(
        globalThis: JsGlobalObject,
        object: JsObject,
        envp: ArrayListManaged<?String>,
        path: String,
    ): Unit {
        var objectIter = try JsPropertyIterator(
            skipEmptyName: false,
            includeValue: true,
        ).init(globalThis, object)
        defer objectIter.deinit()

        try envp.ensureTotalCapacityPrecise(objectIter.len + 2)

        while (let key = try objectIter.next()) {
            var value = objectIter.value
            if (value.isUndefined()) {
                continue
            }

            let valueBunStr = try value.toBunString(globalThis)
            defer valueBunStr.deref()

            // 检查 null 字节 (安全: 防止 null 字节注入)
            if (key.indexOfAsciiChar(0) != None) {
                return globalThis.ERR(
                    .INVALID_ARG_VALUE,
                    "The property 'options.env[{}']' must be a string without null bytes. Received \"{}\"",
                    [key.toZigString(), key.toZigString()],
                ).throw()
            }
            if (valueBunStr.indexOfAsciiChar(0) != None) {
                return globalThis.ERR(
                    .INVALID_ARG_VALUE,
                    "The property 'options.env[{}']' must be a string without null bytes. Received \"{}\"",
                    [key.toZigString(), valueBunStr.toZigString()],
                ).throw()
            }

            let line = try formatAllocSentinel(envp.allocator, "{}={}", [key, valueBunStr.toZigString()], 0)

            if (key.eqlComptime("PATH")) {
                path = asByteSlice(line.substring("PATH=".length))
            }

            try envp.append(line)
        }
    }
}
