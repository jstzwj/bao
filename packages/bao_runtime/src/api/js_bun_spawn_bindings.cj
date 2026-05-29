// 严格翻译自: src/runtime/api/bun/js_bun_spawn_bindings.zig
package bao_runtime.api

import bao_jsc.*
import bao_collections.ArrayList
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
    public static func `spawn`(globalThis!: JsGlobalObject, args!: JsValue, secondaryArgsValue!: ?JsValue): JsValue {
        return spawnMaybeSync(globalThis, args, secondaryArgsValue, false)
    }

    // ========================================================================
    // spawnSync - Bun.spawnSync()
    // ========================================================================

    /// Bun.spawnSync() 入口
    public static func spawnSync(globalThis!: JsGlobalObject, args!: JsValue, secondaryArgsValue!: ?JsValue): JsValue {
        return spawnMaybeSync(globalThis, args, secondaryArgsValue, true)
    }

    // ========================================================================
    // spawnMaybeSync - 共享实现
    // ========================================================================

    /// spawnMaybeSync - spawn 和 spawnSync 的共享实现
    /// 对应 Bun: js_bun_spawn_bindings.zig spawnMaybeSync
    public static func spawnMaybeSync(globalThis!: JsGlobalObject, args_!: JsValue, secondaryArgsValue!: ?JsValue, isSync!: Bool): JsValue {
        if (isSync) {
            // 检查栈溢出
            if (!StackCheck().isSafeToRecurse()) {
                return globalThis.throwStackOverflow()
            }
        }

        var arena = ArenaAllocator(default_allocator)
        let allocator = arena.allocator()

        var overrideEnv: Bool = false
        var envArray: ArrayList<?String> = ArrayList<?String>()
        var jscVm = globalThis.bunVm()

        var cwd: String = jscVm.transpiler.fs.topLevelDir

        var stdio = Array<Stdio>(3, { i =>
            match (i) {
                case 0 => Stdio.ignore()
                case 1 => Stdio.pipe()
                case _ => Stdio.inherit()
            }
        })

        if (isSync) {
            stdio[1] = Stdio.pipe()
            stdio[2] = Stdio.pipe()
        }

        var lazy: Bool = false
        var onExitCallback: JsValue = JsValue.jsUndefined()
        var onDisconnectCallback: JsValue = JsValue.jsUndefined()
        var path: String = jscVm.transpiler.env.get("PATH") ?? ""
        var argv = ArrayList<?String>(allocator)
        var cmdValue: JsValue = JsValue.jsUndefined()
        var detached: Bool = false
        var args = args_
        var maybeIpcMode: ?IpcMode = if (!isSync) { None } else { None }
        var ipcCallback: JsValue = JsValue.jsUndefined()
        var extraFds = ArrayList<SpawnStdio>(default_allocator)
        var argv0: ?String = None
        var ipcChannel: Int32 = -1
        var timeout: ?Int32 = None
        var killSignal: SignalCode = SignalCode.default
        var maxBuffer: ?Int64 = None
        var abortSignal: ?AbortSignal = None
        var terminalInfo: ?TerminalCreateResult = None
        var existingTerminal: ?Terminal = None
        var terminalJsValue: JsValue = JsValue.jsUndefined()

        // 清理 abort_signal 和 terminal

        // 解析参数
        if (args.isEmptyOrUndefinedOrNull()) {
            return globalThis.throwInvalidArguments("cmd must be an array")
        }

        let argsType = args.jsType()
        if (argsType.isArray()) {
            cmdValue = args
            args = secondaryArgsValue ?? JsValue.jsUndefined()
        } else if (!args.isObject()) {
            return globalThis.throwInvalidArguments("cmd must be an array")
        } else if (let cmdValue_ <- args.getTruthy(globalThis, "cmd") ) {
            cmdValue = cmdValue_
        } else {
            return globalThis.throwInvalidArguments("cmd must be an array")
        }

        if (args.isObject()) {
            // argv0
            if (let argv0_ <- args.getTruthy(globalThis, "argv0") ) {
                let argv0Str = argv0_.getZigString(globalThis) 
                if (argv0Str.len > 0) {
                    argv0 = argv0Str.toOwnedSliceZ(allocator) 
                }
            }

            // cwd (必须在搜索可执行文件之前更新)
            if (let cwd_ <- args.getTruthy(globalThis, "cwd") ) {
                let cwdStr = cwd_.getZigString(globalThis) 
                if (cwdStr.len > 0) {
                    cwd = cwdStr.toOwnedSliceZ(allocator) 
                }
            }
        }

        if (args != JsValue.jsUndefined() && args.isObject()) {
            // terminal 仅支持异步 spawn
            if (isSync) {
                if (args.getTruthy(globalThis, "terminal") .isSome()) {
                    return globalThis.throwInvalidArguments("terminal option is only supported for Bun.spawn, not Bun.spawnSync")
                }
            }

            // IPC (仅异步)
            if (!isSync) {
                if (let val <- args.getTruthy(globalThis, "ipc") ) {
                    if (val.isCell() && val.isCallable()) {
                        // 解析 IPC 模式
                        maybeIpcMode = IpcMode.advanced
                        if (let modeVal <- args.getTruthy(globalThis, "serialization") ) {
                            if (modeVal.isString()) {
                                let ipcModeResult = IpcMode.fromJs(globalThis, modeVal)
                                if (ipcModeResult == none) {
                                    return globalThis.throwInvalidArguments("serialization must be \"json\" or \"advanced\"")
                                }
                                maybeIpcMode = ipcModeResult
                            } else {
                                if (!globalThis.hasException()) {
                                    return globalThis.throwInvalidArgumentType("spawn", "serialization", "string")
                                }
                                return JsValue.jsUndefined()
                            }
                        }
                        ipcCallback = val.withAsyncContextIfNeeded(globalThis)
                    }
                }
            }

            // abort signal
            if (let signalVal <- args.getTruthy(globalThis, "signal") ) {
                if (let signal <- signalVal.`as`(AbortSignal)) {
                    abortSignal = signal.ref()
                } else {
                    return globalThis.throwInvalidArgumentTypeValue("signal", "AbortSignal", signalVal)
                }
            }

            // onDisconnect
            if (let onDisconnect_ <- args.getTruthy(globalThis, "onDisconnect") ) {
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
            if (let onExit_ <- args.getTruthy(globalThis, "onExit") ) {
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
            if (let envArg <- args.getTruthy(globalThis, "env") ) {
                envArg.ensureStillAlive()
                                let objectOpt = envArg.getObject()
                if (objectOpt.isNone()) {
                    return globalThis.throwInvalidArguments("env must be an object")
                }
                let object = objectOpt.get()
                overrideEnv = true
                var newPath: String = ""
                var envpManaged = envArray.toManaged(allocator)
                appendEnvpFromJs(globalThis, object, envpManaged, newPath) 
                envArray = envpManaged.moveToUnmanaged()
                path = newPath
            }

            // argv
            getArgv(globalThis, cmdValue, path, cwd, argv0, allocator, argv) 

            // stdio
            if (let stdioVal <- args.get(globalThis, "stdio") ) {
                if (!stdioVal.isEmptyOrUndefinedOrNull()) {
                    if (stdioVal.jsType().isArray()) {
                        var stdioIter = stdioVal.arrayIterator(globalThis) 
                        var i: Int32 = 0
                        while (let value <- stdioIter.next() ) {
                            stdio [i].extract(globalThis, i, value, isSync)
                            if (i == 2) {
                                break
                            }
                            i += 1
                        }
                        i += 1

                        while (let value <- stdioIter.next() ) {
                            var newItem = Stdio.ignore()
                            newItem.extract(globalThis, i, value, isSync) 

                            let opt = match (newItem.asSpawnOption(i)) {
                                case SpawnOption.result(o) => o
                                case SpawnOption.err(e) => return e.throwJs(globalThis)
                            }
                            if (opt == SpawnOption.ipc()) {
                                ipcChannel = Int32(extraFds.items.size)
                            }
                            extraFds.append(opt) 
                            i += 1
                        }
                    } else {
                        return globalThis.throwInvalidArguments("stdio must be an array")
                    }
                }
            } else {
                if (let value <- args.get(globalThis, "stdin") ) {
                    stdio [0].extract(globalThis, 0, value, isSync)
                }
                if (let value <- args.get(globalThis, "stderr") ) {
                    stdio [2].extract(globalThis, 2, value, isSync)
                }
                if (let value <- args.get(globalThis, "stdout") ) {
                    stdio [1].extract(globalThis, 1, value, isSync)
                }
            }

            // lazy (仅异步)
            if (!isSync) {
                if (let lazyVal <- args.get(globalThis, "lazy") ) {
                    if (lazyVal.isBoolean()) {
                        lazy = lazyVal.toBoolean()
                    }
                }
            }

            // detached
            if (let detachedVal <- args.get(globalThis, "detached") ) {
                if (detachedVal.isBoolean()) {
                    detached = detachedVal.toBoolean()
                }
            }

            // timeout
            if (let timeoutValue <- args.get(globalThis, "timeout") ) {
                if (timeoutValue != JsValue.jsNull()) {
                    if (timeoutValue.isNumber() && timeoutValue.asNumber().isPositiveInf()) {
                        // Infinity: 无超时
                    } else {
                        let timeoutInt = globalThis.validateIntegerRange(timeoutValue, 0, ValidationArgs(min: 0, fieldName: "timeout"))
                        if (timeoutInt > 0) {
                            timeout = Int32(timeoutInt)
                        }
                    }
                }
            }

            // killSignal
            if (let val <- args.get(globalThis, "killSignal") ) {
                killSignal = SignalCode.fromJs(val, globalThis) 
            }

            // maxBuffer
            if (let val <- args.get(globalThis, "maxBuffer") ) {
                if (val.isNumber() && val.isFinite()) {
                    let value = val.coerce(globalThis)
                    if (value > 0 && (stdio[0].isPiped() || stdio[1].isPiped() || stdio[2].isPiped())) {
                        maxBuffer = value
                    }
                }
            }

            // terminal (仅异步)
            if (!isSync) {
                if (let terminalVal <- args.getTruthy(globalThis, "terminal") ) {
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
                        let termOptions = Terminal.Options.parseFromJs(globalThis, terminalVal) 
                        terminalInfo = try { Terminal.createFromSpawn(globalThis, termOptions) } catch (err: Exception) {
                            match (err) {
                                case Error.OpenPtyFailed => return globalThis.`throw`("Failed to open PTY")
                                case Error.DupFailed => return globalThis.`throw`("Failed to duplicate PTY file descriptor")
                                case Error.NotSupported => return globalThis.`throw`("PTY not supported on this platform")
                                case Error.WriterStartFailed => return globalThis.`throw`("Failed to start terminal writer")
                                case Error.ReaderStartFailed => return globalThis.`throw`("Failed to start terminal reader")
                            }
                        }
                    } else {
                        return globalThis.throwInvalidArguments("terminal must be a Terminal object or options object")
                    }

                    // 设置 stdio 为 terminal fd
                    let terminal = existingTerminal ?? terminalInfo.getOrThrow().terminal
                    let slaveFd = terminal.getSlaveFd()
                    stdio[0] = Stdio.fd(slaveFd)
                    stdio[1] = Stdio.fd(slaveFd)
                    stdio[2] = Stdio.fd(slaveFd)
                }
            }
        } else {
            getArgv(globalThis, cmdValue, path, cwd, argv0, allocator, argv) 
        }

        // 构建 envp
        if (!overrideEnv && envArray.items.size == 0) {
            envArray.items = try { jscVm.transpiler.env.map.createNullDelimitedEnvMap(allocator) } catch(err: Exception) {
                return globalThis.throwError(err, "in Bun.spawn")
            }
            envArray.capacity = envArray.items.size
        }

        // memfd 优化 (Linux)
        for (fdIndex in 0..stdio.size) {
            if (stdio[fdIndex].canUseMemfd(isSync, fdIndex > 0 && maxBuffer.isSome())) {
                if (stdio[fdIndex].useMemfd(fdIndex)) {
                    jscVm.counters.mark(Counter.spawnMemfd)
                }
            }
        }
        var shouldCloseMemfd: Bool = Environment.isLinux

        // IPC 环境变量设置
        var ipcEnvBuf: Array<Byte> = Array<Byte>(32)
        if (!isSync) {
            if (let ipcMode <- maybeIpcMode) {
                try { envArray.ensureUnusedCapacity(allocator, 3) } catch(err: Exception) {
                    return globalThis.throwError(err, "in Bun.spawn")
                }

                var ipcFd: Int32 = 0
                    if (ipcChannel == -1) {
                        ipcChannel = Int32(extraFds.items.size)
                        let fd: Int32 = ipcChannel + 3
                        let opt = match (Stdio.ipc().asSpawnOption(fd)) {
                            case SpawnOption.result(o) => o
                            case SpawnOption.err(e) => return e.throwJs(globalThis)
                        }
                        extraFds.append(opt)
                        ipcFd = fd
                    } else {
                        ipcFd = Int32(ipcChannel + 3)
                    }

                let pipeEnv = "NODE_CHANNEL_FD=" + ipcFd.toString()
                envArray.append(pipeEnv)
                envArray.append("NODE_CHANNEL_SERIALIZATION_MODE=" + ipcMode.tagName())
            }
        }

        envArray.append(allocator, None) 
        argv.append(None) 

        // spawnSync 的 stdio 转 sync 模式
        if (isSync) {
            for ((io, i) in stdio) {
                io.toSync(i)
            }
        }

        // 快速路径检查
        let canBlockEntireThread = isSync &&
            abortSignal.isNone() &&
            timeout.isNone() &&
            maxBuffer.isNone() &&
            !stdio[0].isPiped() &&
            !stdio[1].isPiped() &&
            !stdio[2].isPiped() &&
            extraFds.items.size == 0 &&
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

        let loopHandle = EventLoopHandle(eventLoop)

        // 构建 spawn 选项
        let stdinOpt = stdio[0].asSpawnOption(0)
        let stdoutOpt = stdio[1].asSpawnOption(1)
        let stderrOpt = stdio[2].asSpawnOption(2)
        let spawnOptions = SpawnOptions(
            cwd: cwd,
            detached: detached,
            stdin: stdinOpt,
            stdout: stdoutOpt,
            stderr: stderrOpt,
            extraFds: extraFds.items,
            argv0: argv0,
            canBlockEntireThread: canBlockEntireThread,
            ptySlaveFd: if (terminalInfo.isSome()) {
                terminalInfo.getOrThrow().terminal.getSlaveFd().native()
            } else {
                -1
            },
        )

        // 执行 spawn
        var spawned = try { spawnProcess(
            spawnOptions,
            argv.items.ptr,
            envArray.items.ptr
        ) } catch(err: Exception) {
            match (err) {
                case Error.EMFILE | Error.ENFILE =>
                    spawnOptions.deinit()
                    let firstArg = if (argv.items.size > 0) { argv.items[0] } else { none }
                    let displayPath: String = if (firstArg.isSome()) {
                        sliceTo(firstArg.getOrThrow(), 0)
                    } else {
                        ""
                    }
                    var systemError = SystemError.fromCode(
                        if (err == Error.EMFILE) { Errno.MFILE } else { Errno.NFILE },
                        Syscall.posixSpawn,
                    ).withPath(displayPath).toSystemError()
                    systemError.errno = if (err == Error.EMFILE) { -UV_E.MFILE } else { -UV_E.NFILE }
                    return globalThis.throwValue(systemError.toErrorInstance(globalThis))
                case _ =>
                    spawnOptions.deinit()
                    return globalThis.throwError(err, ": failed to spawn process")
            }
        }

        match (spawned) {
            case SpawnResult.err(err) =>
                spawnOptions.deinit()
                match (err.getErrno()) {
                    case Errno.ACCES | Errno.NOENT | Errno.PERM | Errno.ISDIR | Errno.NOTDIR =>
                        let firstArg2 = if (argv.items.size > 0) { argv.items[0] } else { none }
                        let displayPath: String = if (firstArg2.isSome()) {
                            sliceTo(firstArg2.getOrThrow(), 0)
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
                    case _ => ()
                }
                return globalThis.throwValue(err.toJs(globalThis) )
            case SpawnResult.result(result) => spawned = result
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

        var promiseForStream: JsValue = JsValue.jsUndefined()

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
            terminal: existingTerminal ?? (if (terminalInfo.isSome()) { terminalInfo.getOrThrow().terminal } else { None }),
        )

        // 初始化 stdin
        subprocess.stdin = try { Writable(stdio[0], eventLoop, subprocess, spawned.stdin, promiseForStream) } catch(err: Exception) {
            if (spawned.stdout.isSome()) {
                    spawned.stdout.close()
                }
                if (spawned.stderr.isSome()) {
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

        subprocess.stdout = Readable(stdio[1], eventLoop, subprocess, spawned.stdout, jscVm.allocator, subprocess.stdoutMaxbuf, isSync)
        subprocess.stderr = Readable(stdio[2], eventLoop, subprocess, spawned.stderr, jscVm.allocator, subprocess.stderrMaxbuf, isSync)

        // 终端: 关闭父进程的 slave_fd
        if (let info <- terminalInfo) {
            terminalJsValue = info.jsValue
            info.terminal.closeSlaveFd()
            subprocess.flags.ownsTerminal = true
            terminalInfo = None
        }

        subprocess.process.setExitHandler(subprocess)

        promiseForStream.ensureStillAlive()
        subprocess.flags.isStdinAReadableStream = (promiseForStream != JsValue.jsUndefined())

        if (promiseForStream != JsValue.jsUndefined() && !globalThis.hasException()) {
            if (let err <- promiseForStream.toError()) {
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
        if (!isSync && maybeIpcMode.isSome()) {
            if (let socket <- jscVm.rareData().spawnIpcGroup(jscVm).fromFd(
                SocketKind.spawn_ipc,
                None,
                sizeOf<IpcSendQueue>(),
                spawned.extraPipes.items[Int64(ipcChannel)].fd().cast(),
                true,
            )) {
                subprocess.ipcData = IpcData(maybeIpcMode.getOrThrow(), IpcDataContext.subprocess(subprocess), IpcState.uninitialized)
            }
        }

        if (let ipcData <- subprocess.ipcData) {
            // 写入版本包
            ipcData.writeVersionPacket(globalThis)
            subprocess.stdioPipes.items[Int64(ipcChannel)] = SpawnPipe.unavailable
        }

        // stdin pipe 信号
        if (subprocess.stdin == SubprocessStdio.pipe && promiseForStream == JsValue.jsUndefined()) {
            subprocess.stdin.pipe.signal = Signal(subprocess.stdin)
        }

        // 创建 JS 值
        let out = if (!isSync) {
            subprocess.toJs(globalThis)
        } else {
            JsValue.jsUndefined()
        }
        if (out != JsValue.jsUndefined()) {
            subprocess.thisValue.setWeak(out)
            subprocess.updateHasPendingActivity()
        }

        var sendExitNotification: Bool = false

        if (!isSync) {
            // 超时计时器
            if (let timeoutVal <- timeout) {
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

            if (terminalJsValue != JsValue.jsUndefined()) {
                JSSubprocess.terminalSetCached(out, globalThis, terminalJsValue)
            }

            match (subprocess.process.watch()) {
                case WatchResult.result => ()
                case WatchResult.err =>
                    sendExitNotification = true
                    lazy = false
            }
        }

        // stdin buffer 错误检查
        if (subprocess.stdin == SubprocessStdio.buffer) {
            if (let err <- subprocess.stdin.buffer.start().asErr()) {
                let _ = subprocess.tryKill(subprocess.killSignal)
                let _ = globalThis.throwValue(err.toJs(globalThis))
                return Error.JsError
            
        }

        // 启动 stdout pipe
        if (subprocess.stdout == SubprocessStdio.pipe) {
            if (let err <- subprocess.stdout.pipe.start(subprocess, eventLoop).asErr()) {
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
            if (let err <- subprocess.stderr.pipe.start(subprocess, eventLoop).asErr()) {
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
        if (let signal <- abortSignal) {
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
                if (let signal <- abortSignal) {
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
        var absoluteTimespec = Timespec.epoch
        var now = Timespec.now()
        var userTimespec: Timespec = if (let timeoutMs <- timeout) {
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

            match (syncLoop.tickWithTimeout(if (hasTimespec && !didTimeout) { absoluteTimespec } else { None })) {
                    case TickResult.completed =>
                        now = Timespec.now()
                    case TickResult.timeout =>
                        now = Timespec.now()
                        let didUserTimeout = hasUserTimespec && (absoluteTimespec.eql(userTimespec) || userTimespec.order(now) == lt)

                        if (didUserTimeout) {
                            didTimeout = true
                            let _ = subprocess.tryKill(subprocess.killSignal)
                        }
                }
            }
        }

        if (globalThis.hasException()) {
            return JsValue.jsUndefined()
        }

        subprocess.updateHasPendingActivity()

        let signalCode = subprocess.getSignalCode(globalThis)
        let exitCode = subprocess.getExitCode(globalThis)
        let stdout = subprocess.stdout.toBufferedValue(globalThis) 
        let stderr = subprocess.stderr.toBufferedValue(globalThis) 
        let resourceUsage: JsValue = if (!globalThis.hasException()) {
            subprocess.createResourceUsageObject(globalThis) 
        } else {
            JsValue.jsUndefined()
        }
        let exitedDueToTimeout = didTimeout
        let exitedDueToMaxBuffer = subprocess.exitedDueToMaxbuf
        let resultPid = JsValue.jsNumberFromInt32(subprocess.pid())
        subprocess.finalize()

        let syncValue = JsValue.createEmptyObject(globalThis, 0)
        syncValue.put(globalThis, ZigString.`static`("exitCode"), exitCode)
        if (!signalCode.isEmptyOrUndefinedOrNull()) {
            syncValue.put(globalThis, ZigString.`static`("signalCode"), signalCode)
        }
        syncValue.put(globalThis, ZigString.`static`("stdout"), stdout)
        syncValue.put(globalThis, ZigString.`static`("stderr"), stderr)
        syncValue.put(globalThis, ZigString.`static`("success"), JsValue.jsBoolean(exitCode.isInt32() && exitCode.asInt32() == 0))
        syncValue.put(globalThis, ZigString.`static`("resourceUsage"), resourceUsage)
        if (timeout.isSome()) {
            syncValue.put(globalThis, ZigString.`static`("exitedDueToTimeout"), if (exitedDueToTimeout) { JsValue.`true` } else { JsValue.`false` })
        }
        if (maxBuffer.isSome()) {
            syncValue.put(globalThis, ZigString.`static`("exitedDueToMaxBuffer"), if (exitedDueToMaxBuffer.isSome()) { JsValue.`true` } else { JsValue.`false` })
        }
        syncValue.put(globalThis, ZigString.`static`("pid"), resultPid)

        try {
            if (sendExitNotification) {
                if (subprocess.process.hasExited()) {
                    subprocess.process.onExit(subprocess.process.status, Rusage.zeroes())
                } else {
                    subprocess.process.wait(isSync)
                }
            }
            if (isSync) {
                jscVm.rareData().spawnSyncEventLoop(jscVm).cleanup(jscVm, jscVm.eventLoop())
            }
            if (shouldCloseMemfd) {
                for (fdIndex in 0..stdio.size) {
                    match (stdio[fdIndex]) {
                        case Stdio.memfd(m) =>
                            m.close()
                            stdio[fdIndex] = Stdio.ignore()
                        case _ => ()
                    }
                }
            }
            if (let Some(signal) <- abortSignal) {
                signal.unref()
            }
            if (let Some(info) <- terminalInfo) {
                info.terminal.thisValue.downgrade()
                info.terminal.flags.finalized = true
                info.terminal.closeInternal()
            }
            extraFds.deinit()
            arena.deinit()
            return syncValue
        } catch(err: Exception) {
        if (let Some(signal) <- abortSignal) {
            signal.unref()
        }
        if (let Some(info) <- terminalInfo) {
            info.terminal.thisValue.downgrade()
            info.terminal.flags.finalized = true
            info.terminal.closeInternal()
        }
        extraFds.deinit()
        arena.deinit()
        return globalThis.throwError(err, "spawn failed")
    }
}

    // ========================================================================
    // getArgv - 构建 argv 数组
    // ========================================================================

    /// getArgv - 构建 Bun.spawn 的 argv
    public static func getArgv(globalThis!: JsGlobalObject, args!: JsValue, path!: String, cwd!: String, argv0!: ?String, allocator!: Allocator): ArrayList<String> {
        if (args.isEmptyOrUndefinedOrNull()) {
            globalThis.throwInvalidArguments("cmd must be an array of strings")
            return []
        }

        var cmdsArray = args.arrayIterator(globalThis) 
        if (cmdsArray.len == 0) {
            globalThis.throwInvalidArguments("cmd must not be empty")
            return []
        }

        var argv = ArrayList<String>(capacity: cmdsArray.len + 2)

        // 获取 argv0
        let argv0Result = getArgv0(globalThis, path, cwd, argv0, cmdsArray.next().getOrThrow(), allocator)
        argv.append(argv0Result.arg0)

        // 添加其余参数
        var argIndex: Int = 1
        while (let value <- cmdsArray.next() ) {
            let arg = value.toBunString(globalThis) 
            // 检查 null 字节 (安全: 防止 null 字节注入)
            if (arg.indexOfAsciiChar(0) != none) {
                globalObject.throwInvalidArguments("Argument must be a string without null bytes")
                return []
            }

            argv.append(arg.toOwnedSliceZ(allocator))
            argIndex += 1
            arg.deref()
        }

        return argv
    }

    // ========================================================================
    // Argv0 结果
    // ========================================================================

    // Note: Argv0Result moved to top level (struct cannot be declared inside class body)

    // ========================================================================
    // getArgv0 - 解析 argv[0]
    // ========================================================================

    /// getArgv0 - 解析第一个命令参数
    public static func getArgv0(globalThis!: JsGlobalObject, path!: String, cwd!: String, pretendArgv0!: ?String, firstCmd!: JsValue, allocator!: Allocator): Argv0Result {
        var arg0 = firstCmd.toSliceOrNullWithAllocator(globalThis, allocator) 
        // 检查 null 字节
        if (arg0.slice().indexOfChar(0) != none) {
            globalThis.throwInvalidArguments("The argument 'args[0]' must be a string without null bytes")
            return Argv0Result("", "")
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
            let resolvedOpt = Which.which(pathToUse, cwd, argv0ToUse)
            if (resolvedOpt.isNone()) {
                throwCommandNotFound(globalThis, argv0ToUse)
                return Argv0Result("", "")
            }
            let resolved = resolvedOpt.get()
            actualArgv0 = allocator.dupeZ(resolved)
        }

        let resultArg0 = if (pretendArgv0 != none) { allocator.dupeZ(pretendArgv0.getOrThrow()) } else { allocator.dupeZ(arg0.slice()) }
        arg0.deinit()
        return Argv0Result(actualArgv0, resultArg0)
    }

    // ========================================================================
    // throwCommandNotFound - 命令未找到错误
    // ========================================================================

    /// 抛出命令未找到错误
    public static func throwCommandNotFound(globalThis!: JsGlobalObject, command!: String): JsError {
        let err = SystemError(
            message: BunString.createFormat("Executable not found in $PATH: \"{}\"", [command]),
            code: BunString.`static`("ENOENT"),
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
        globalThis!: JsGlobalObject,
        object!: JsObject,
        envp!: ArrayListManaged<?String>,
        path!: String
    ): Unit {
        var objectIter = JsPropertyIterator (
            skipEmptyName: false,
            includeValue: true,
        ).`init`(globalThis, object)
        envp.ensureTotalCapacityPrecise(objectIter.len + 2) 

        while (true) {
            let key = try {
                objectIter.next()
            } catch (e: Exception) {
                break
            }
            var value = objectIter.value
            if (value.isUndefined()) {
                continue
            }

            let valueBunStr = value.toBunString(globalThis) 
            // 检查 null 字节 (安全: 防止 null 字节注入)
            if (key.indexOfAsciiChar(0).isSome()) {
                return globalThis.ERR(
                    NodeJsErrorCode.ERR_INVALID_ARG_VALUE,
                    "The property 'options.env[{']' must be a string without null bytes. Received \"{}\"",
                    [key.toZigString(), key.toZigString()],
                ).`throw`()
            }
            if (valueBunStr.indexOfAsciiChar(0).isSome()) {
                return globalThis.ERR(
                    NodeJsErrorCode.ERR_INVALID_ARG_VALUE,
                    "The property 'options.env[{}']' must be a string without null bytes. Received \"{}\"",
                    [key.toZigString(), valueBunStr.toZigString()],
                ).`throw`()
            }

            let line = formatAllocSentinel(envp.allocator, "{}={}", [key, valueBunStr.toZigString() ], 0)

            if (key.eqlComptime("PATH")) {
                path = asByteSlice(line.substring("PATH=".size))
            }

            envp.append(line) 
            valueBunStr.deref()
        }
        objectIter.deinit()
    }
}

/// Argv0 结果
public struct Argv0Result {
    public var argv0: String
    public var arg0: String
}
