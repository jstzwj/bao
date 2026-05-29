// 严格翻译自: src/runtime/api/cron.rs
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_event_loop.{EventLoopTimer, TimerTag, TimerState}

/// SpawnStatus — 进程退出状态桩类型
public class SpawnStatus {
    public var exitCode: Int32 = 0
    public var signal: Int32 = 0
    public init() {}
}

/// OutputReader — 输出读取器桩类型
public class OutputReader {
    public init() {}
}

/// JSPromiseStrong — JS Promise 强引用桩类型
public class JSPromiseStrong {
    public init() {}
}

/// AsyncKeepAlive — 异步 KeepAlive 桩类型
public class AsyncKeepAlive {
    public init() {}
}

/// SpawnStdio — 进程标准 IO 桩类型
public class SpawnStdio {
    public static let ignore = SpawnStdio()
    public static let buffer = SpawnStdio()
    public init() {}
}

/// ClearMode — 清理模式枚举
public enum ClearMode {
    | reload
    | teardown
}

// ============================================================================
// Bun.cron - 进程内和 OS 级 cron 调度
// 对应 Bun: src/runtime/api/cron.rs
//
// Bun.cron(schedule, handler)       - 按计划运行回调 (返回 CronJob)
// Bun.cron(path, schedule, title)   - 注册 OS 级任务 (返回 Promise)
// Bun.cron.remove(title)            - 移除 OS 级任务 (返回 Promise)
// Bun.cron.parse(expr, from?)       - 下次触发时间计算器 (返回 Date | null)
//
// OS 级别使用 crontab (Linux), launchctl + launchd plist (macOS), 或
// schtasks (Windows). 异步, 通过 bun.spawn 集成到事件循环.
// ============================================================================

// ============================================================================
// CronJobBase - CronRegisterJob 和 CronRemoveJob 的共享基类 trait
// ============================================================================

/// CronJobBase - CronRegisterJob 和 CronRemoveJob 的共享接口
/// 对应 Rust 中的 trait CronJobBase
public interface CronJobBaseIsh<T> {
    func remainingFdsMut(): Int8
    func errMsgMut(): ?Array<UInt8>
    func setErrMsg(msg!: ?Array<UInt8>): Unit
    func hasCalledProcessExitMut(): Bool
    func setHasCalledProcessExit(v!: Bool): Unit
    func exitStatusMut(): ?SpawnStatus
    func setExitStatus(s!: ?SpawnStatus): Unit
    func getEventLoopHandle(): EventLoopHandle
    func getStdoutReader(): OutputReader
    func getStderrReader(): OutputReader
    func getProcess(): ?Process
    func setProcess(p!: ?Process): Unit
    func getErrMsg(): ?Array<UInt8>
    func getStateStr(): String
}

// ============================================================================
// RegisterState - CronRegisterJob 状态枚举
// ============================================================================

/// CronRegisterJob 的状态
public enum RegisterState {
    | readingCrontab
    | installingCrontab
    | writingPlist
    | bootingOut
    | bootstrapping
    | done
    | failed
}

// ============================================================================
// RemoveState - CronRemoveJob 状态枚举
// ============================================================================

/// CronRemoveJob 的状态
public enum RemoveState {
    | readingCrontab
    | installingCrontab
    | bootingOut
    | done
    | failed
}

// ============================================================================
// CronRegisterJob - 注册 OS 级 cron 任务
// ============================================================================

/// CronRegisterJob - 注册 OS 级 cron 任务
public class CronRegisterJob {
    public var promise: JSPromiseStrong
    public var global: JsGlobalObject
    public var poll: AsyncKeepAlive
    public var bunExe: String
    public var absPath: String
    public var schedule: String  // 规范化数字形式
    public var title: String
    public var parsedCron: CronExpression
    public var state: RegisterState
    public var process: ?Process
    public var stdoutReader: OutputReader
    public var stderrReader: OutputReader
    public var remainingFds: Int8
    public var hasCalledProcessExit: Bool
    public var exitStatus: ?SpawnStatus
    public var errMsg: ?Array<UInt8>
    public var tmpPath: ?String
    public var eventLoopHandle: EventLoopHandle

    public init() {
        promise = JSPromiseStrong()
        global = JsGlobalObject.zero
        poll = AsyncKeepAlive()
        bunExe = ""
        absPath = ""
        schedule = ""
        title = ""
        parsedCron = CronExpression()
        state = RegisterState.readingCrontab
        process = none
        stdoutReader = OutputReader()
        stderrReader = OutputReader()
        remainingFds = 0
        hasCalledProcessExit = false
        exitStatus = none
        errMsg = none
        tmpPath = none
        eventLoopHandle = EventLoopHandle()
    }

    // ========================================================================
    // CronJobBase 实现
    // ========================================================================

    public func remainingFdsMut(): Int8 {
        return remainingFds
    }

    public func errMsgMut(): ?Array<UInt8> {
        return errMsg
    }

    public func setErrMsg(msg!: ?Array<UInt8>): Unit {
        errMsg = msg
    }

    public func hasCalledProcessExitMut(): Bool {
        return hasCalledProcessExit
    }

    public func setHasCalledProcessExit(v!: Bool): Unit {
        hasCalledProcessExit = v
    }

    public func exitStatusMut(): ?SpawnStatus {
        return exitStatus
    }

    public func setExitStatus(s!: ?SpawnStatus): Unit {
        exitStatus = s
    }

    public func getEventLoopHandle(): EventLoopHandle {
        return eventLoopHandle
    }

    public func getStdoutReader(): OutputReader {
        return stdoutReader
    }

    public func getStderrReader(): OutputReader {
        return stderrReader
    }

    public func getProcess(): ?Process {
        return process
    }

    public func setProcess(p!: ?Process): Unit {
        process = p
    }

    public func getErrMsg(): ?Array<UInt8> {
        return errMsg
    }

    public func getStateStr(): String {
        return "CronRegisterJob"
    }

    // ========================================================================
    // 错误处理
    // ========================================================================

    /// 设置错误消息 (仅当尚未设置时)
    public func setErr(fmt!: String): Unit {
        if (errMsg == none) {
            errMsg = fmt.toUtf8().toArray()
        }
    }

    // ========================================================================
    // Reader 回调
    // ========================================================================

    /// 当 reader 完成时调用
    public func onReaderDone(): Unit {
        if (remainingFds > 0) {
            remainingFds -= 1
        }
        maybeFinished()
    }

    /// 当 reader 出错时调用
    public func onReaderError(err!: SysError): Unit {
        if (remainingFds > 0) {
            remainingFds -= 1
        }
        if (errMsg == none) {
            errMsg = "Failed to read process output: ".append(err.strerror()).toUtf8().toArray()
        }
        maybeFinished()
    }

    /// 当进程退出时调用
    public func onProcessExit(status!: SpawnStatus): Unit {
        hasCalledProcessExit = true
        exitStatus = status
        maybeFinished()
    }

    // ========================================================================
    // 状态管理
    // ========================================================================

    /// 检查是否所有操作都已完成, 如果是则推进状态
    public func maybeFinished(): Unit {
        if (!hasCalledProcessExit || remainingFds != 0) {
            return
        }

        // 释放进程引用
        if (let proc <- process) {
            proc.detach()
            process = none
        }

        if (errMsg != none) {
            finish()
            return
        }

        if (exitStatus.isNone()) { return }
        let status = exitStatus.getOrThrow()

        match (status) {
            case exited(code) =>
                if (code != 0 && !(state == RegisterState.readingCrontab && code == 1) && state != RegisterState.bootingOut) {
                    // 在 Windows 上, 检测 SID 解析错误
                    setErr("Process exited with code ".append(code.toString()))
                    finish()
                    return
                }
            case signaled(sig) =>
                if (state != RegisterState.bootingOut) {
                    setErr("Process killed by signal ".append(sig.toString()))
                    finish()
                    return
                }
            case err(err) =>
                setErr("Process error: ".append(err.strerror()))
                finish()
                return
            case running =>
                return
        }

        advanceState()
    }

    /// 推进状态机
    public func advanceState(): Unit {
        // macOS 和 Linux/Windows 有不同的状态流
        match (state) {
            case writingPlist =>
                spawnBootout()
            case bootingOut =>
                spawnBootstrap()
            case bootstrapping =>
                finish()
            case readingCrontab =>
                processCrontabAndInstall()
            case installingCrontab =>
                finish()
            case _ =>
                setErr("Unexpected state")
                finish()
        }
    }

    /// 完成操作, 解决 Promise
    public func finish(): Unit {
        state = if (errMsg == none) { RegisterState.done } else { RegisterState.failed }
        poll.unref(VirtualMachine.get())
        let ev = VirtualMachine.get().eventLoop()
        ev.enter()
        if (let msg <- errMsg) {
            promise.rejectWithAsyncStack(global, global.createErrorInstance(String.fromUtf8(msg)))
        } else {
            promise.resolve(global, JsValue.jsUndefined() )
        }
        deinit()
        ev.exit()
    }

    // ========================================================================
    // Linux 实现
    // ========================================================================

    /// 启动 Linux 注册流程: 读取现有 crontab
    public func startLinux(): Unit {
        state = RegisterState.readingCrontab
        stdoutReader = OutputReader.initForCronRegister()
        let crontabPath = findCrontab()
        if (crontabPath == none) {
            setErr("crontab not found in PATH")
            finish()
            return
        }
        // 启动 "crontab -l" 进程读取现有 crontab
        let argv: Array<String> = [crontabPath.get(), "-l"]
        spawnCmd(argv, SpawnStdio.ignore, SpawnStdio.buffer)
    }

    /// 处理现有 crontab 并安装新条目
    public func processCrontabAndInstall(): Unit {
        let existingContent = stdoutReader.finalBuffer()
        var result: Array<UInt8> = Array<UInt8>()

        filterCrontab(existingContent, title, result)

        // 构建新条目, 使用单引号包裹路径防止 shell 注入
        let newEntry = "# bun-cron: ".append(title)
            .append("\n")
            .append(schedule)
            .append(" '")
            .append(bunExe)
            .append("' run --cron-title=")
            .append(title)
            .append(" --cron-period='")
            .append(schedule)
            .append("' '")
            .append(absPath)
            .append("'\n")

        result.appendRange(newEntry.toUtf8().toArray())

        let tmpPathVal = makeTempPath("bun-cron-")
        if (tmpPathVal == none) {
            setErr("Out of memory")
            finish()
            return
        }
        tmpPath = tmpPathVal

        // 将结果写入临时文件
        if (!writeFile(tmpPath.get(), result)) {
            setErr("Failed to write temp file")
            finish()
            return
        }

        state = RegisterState.installingCrontab
        stdoutReader = OutputReader.initForCronRegister()

        let crontabPath = findCrontab()
        if (crontabPath == none) {
            setErr("crontab not found in PATH")
            finish()
            return
        }

        let argv: Array<String> = [crontabPath.get(), tmpPath.get()]
        spawnCmd(argv, SpawnStdio.ignore, SpawnStdio.ignore)
    }

    // ========================================================================
    // macOS 实现
    // ========================================================================

    /// 启动 macOS 注册流程: 编写 plist
    public func startMac(): Unit {
        state = RegisterState.writingPlist

        let calendarXml = cronToCalendarInterval(schedule)
        if (calendarXml == none) {
            setErr("Invalid cron expression")
            finish()
            return
        }

        let home = EnvVar.HOME.get()
        if (home == none) {
            setErr("HOME environment variable not set")
            finish()
            return
        }

        // 创建 ~/Library/LaunchAgents 目录
        let launchAgentsDir = home.get().append("/Library/LaunchAgents")
        // mkdir -p 目录
        if (!makeDirAll(launchAgentsDir)) {
            setErr("Failed to create ~/Library/LaunchAgents directory")
            finish()
            return
        }

        let plistPath = home.get()
            .append("/Library/LaunchAgents/bun.cron.")
            .append(title)
            .append(".plist")
        tmpPath = plistPath

        // XML 转义所有动态值
        let xmlTitle = xmlEscape(title)
        let xmlBun = xmlEscape(bunExe)
        let xmlPath = xmlEscape(absPath)
        let xmlSched = xmlEscape(schedule)

        // 构建 plist XML 内容
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
            .append("<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n")
            .append("<plist version=\"1.0\">\n")
            .append("<dict>\n")
            .append("    <key>Label</key>\n")
            .append("    <string>bun.cron.").append(xmlTitle).append("</string>\n")
            .append("    <key>ProgramArguments</key>\n")
            .append("    <array>\n")
            .append("        <string>").append(xmlBun).append("</string>\n")
            .append("        <string>run</string>\n")
            .append("        <string>--cron-title=").append(xmlTitle).append("</string>\n")
            .append("        <string>--cron-period=").append(xmlSched).append("</string>\n")
            .append("        <string>").append(xmlPath).append("</string>\n")
            .append("    </array>\n")
            .append("    <key>StartCalendarInterval</key>\n")
            .append(calendarXml.get())
            .append("\n")
            .append("    <key>StandardOutPath</key>\n")
            .append("    <string>/tmp/bun.cron.").append(xmlTitle).append(".stdout.log</string>\n")
            .append("    <key>StandardErrorPath</key>\n")
            .append("    <string>/tmp/bun.cron.").append(xmlTitle).append(".stderr.log</string>\n")
            .append("</dict>\n")
            .append("</plist>\n")

        // 写入 plist 文件
        if (!writeFile(plistPath, plist.toUtf8().toArray())) {
            setErr("Failed to write plist")
            finish()
            return
        }

        spawnBootout()
    }

    /// 执行 launchctl bootout (卸载旧版本)
    public func spawnBootout(): Unit {
        state = RegisterState.bootingOut
        let uidStr = "gui/".append(getUid().toString()).append("/bun.cron.").append(title)

        let argv: Array<String> = ["/bin/launchctl", "bootout", uidStr]
        spawnCmd(argv, SpawnStdio.ignore, SpawnStdio.ignore)
    }

    /// 执行 launchctl bootstrap (加载新版本)
    public func spawnBootstrap(): Unit {
        state = RegisterState.bootstrapping
                let plistPathValOpt = tmpPath
        if (plistPathValOpt.isNone()) {
            setErr("No plist path")
            finish()
            return
        }
        let plistPathVal = plistPathValOpt.get()
        let uidStr = "gui/".append(getUid().toString())

        let argv: Array<String> = ["/bin/launchctl", "bootstrap", uidStr, plistPathVal]
        // tmp_path 已通过 take() 清除 - 不要删除已安装的 plist
        tmpPath = none
        spawnCmd(argv, SpawnStdio.ignore, SpawnStdio.ignore)
    }

    // ========================================================================
    // Windows 实现
    // ========================================================================

    /// 启动 Windows 注册流程
    public func startWindows(): Unit {
        state = RegisterState.installingCrontab

        let taskName = "bun-cron-".append(title)

        let xml = cronToTaskXml(
            parsedCron,
            bunExe.toUtf8().toArray(),
            title.toUtf8().toArray(),
            schedule.toUtf8().toArray(),
            absPath.toUtf8().toArray(),
        )
        if (xml == none) {
            setErr("Failed to build task XML")
            finish()
            return
        }

        let xmlPathVal = makeTempPath("bun-cron-xml-")
        if (xmlPathVal == none) {
            setErr("Out of memory")
            finish()
            return
        }
        tmpPath = xmlPathVal

        if (!writeFile(xmlPathVal.get(), xml.get())) {
            setErr("Failed to write temp XML file")
            finish()
            return
        }

        let argv: Array<String> = [
            "schtasks",
            "/create",
            "/xml",
            xmlPathVal.get(),
            "/tn",
            taskName,
            "/np",
            "/f"
        ]
        spawnCmd(argv, SpawnStdio.ignore, SpawnStdio.ignore)
    }

    // ========================================================================
    // spawn 命令
    // ========================================================================

    /// 通用的 spawn 命令, 可能会释放 this
    public func spawnCmd(argv!: Array<String>, stdinOpt!: SpawnStdio, stdoutOpt!: SpawnStdio): Unit {
        hasCalledProcessExit = false
        exitStatus = none
        remainingFds = 0

        let spawnOpts = SpawnOptions()
        spawnOpts.stdin = stdinOpt
        spawnOpts.stdout = stdoutOpt
        spawnOpts.stderr = SpawnStdio.ignore

        let result = SpawnProcess.`spawn`(argv, spawnOpts)
        match (result) {
            case ok(proc) =>
                process = proc
                proc.setExitHandler(this)
                // 设置 stdout reader
                if (stdoutOpt == SpawnStdio.buffer) {
                    stdoutReader = OutputReader.initForCronRegister()
                    remainingFds += 1
                    stdoutReader.start(proc)
                }
                proc.watchOrReap()
            case err(err) =>
                setErr("Failed to spawn process: ".append(err.toString()))
                finish()
        }
    }

    // ========================================================================
    // 清理
    // ========================================================================

    public func deinit(): Unit {
        stdoutReader.deinit()
        stderrReader.deinit()
        if (let p <- tmpPath) {
            Syscall.unlink(p)
            tmpPath = none
        }
        if (let proc <- process) {
            proc.detach()
            process = none
        }
    }
}

// ============================================================================
// CronRemoveJob - 移除 OS 级 cron 任务
// ============================================================================

/// CronRemoveJob - 移除 OS 级 cron 任务
public class CronRemoveJob {
    public var promise: JSPromiseStrong
    public var global: JsGlobalObject
    public var poll: AsyncKeepAlive
    public var title: String
    public var state: RemoveState
    public var process: ?Process
    public var stdoutReader: OutputReader
    public var stderrReader: OutputReader
    public var remainingFds: Int8
    public var hasCalledProcessExit: Bool
    public var exitStatus: ?SpawnStatus
    public var errMsg: ?Array<UInt8>
    public var tmpPath: ?String
    public var eventLoopHandle: EventLoopHandle

    public init() {
        promise = JSPromiseStrong()
        global = JsGlobalObject.zero
        poll = AsyncKeepAlive()
        title = ""
        state = RemoveState.readingCrontab
        process = none
        stdoutReader = OutputReader()
        stderrReader = OutputReader()
        remainingFds = 0
        hasCalledProcessExit = false
        exitStatus = none
        errMsg = none
        tmpPath = none
        eventLoopHandle = EventLoopHandle()
    }

    // ========================================================================
    // 错误处理
    // ========================================================================

    public func setErr(fmt!: String): Unit {
        if (errMsg == none) { errMsg = fmt.toUtf8().toArray() }
    }

    // ========================================================================
    // Reader 回调
    // ========================================================================

    public func onReaderDone(): Unit {
        if (remainingFds > 0) {
            remainingFds -= 1
        }
        maybeFinished()
    }

    public func onReaderError(err!: SysError): Unit {
        if (remainingFds > 0) {
            remainingFds -= 1
        }
        if (errMsg == none) {
            errMsg = "Failed to read process output: ".append(err.strerror()).toUtf8().toArray()
        }
        maybeFinished()
    }

    public func onProcessExit(status!: SpawnStatus): Unit {
        hasCalledProcessExit = true
        exitStatus = status
        maybeFinished()
    }

    // ========================================================================
    // 状态管理
    // ========================================================================

    public func maybeFinished(): Unit {
        if (!hasCalledProcessExit || remainingFds != 0) { return }

        if (let proc <- process) {
            proc.detach()
            process = none
        }

        if (errMsg != none) {
            finish()
            return
        }

        let status = exitStatus ?? return

        match (status) {
            case exited(code) =>
                let isAcceptableNonzero = (state == RemoveState.readingCrontab && code == 1)
                    || state == RemoveState.bootingOut
                if (code != 0 && !isAcceptableNonzero) {
                    setErr("Process exited with code ".append(code.toString()))
                    finish()
                    return
                }
            case signaled(sig) =>
                if (state != RemoveState.bootingOut) {
                    setErr("Process killed by signal ".append(sig.toString()))
                    finish()
                    return
                }
            case err(err) =>
                setErr("Process error: ".append(err.strerror()))
                finish()
                return
            case running =>
                return
        }

        advanceState()
    }

    /// 推进状态机
    public func advanceState(): Unit {
        match (state) {
            case bootingOut =>
                // macOS: bootout 后删除 plist
                let home = EnvVar.HOME.get()
                if (home != none) {
                    let plistPath = home.get()
                        .append("/Library/LaunchAgents/bun.cron.")
                        .append(title)
                        .append(".plist")
                    Syscall.unlink(plistPath)
                }
                finish()
            case readingCrontab =>
                removeCrontabEntry()
            case installingCrontab =>
                finish()
            case _ =>
                setErr("Unexpected state")
                finish()
        }
    }

    /// 完成操作, 解决 Promise
    public func finish(): Unit {
        state = if (errMsg != none) { RemoveState.failed } else { RemoveState.done }
        poll.unref(VirtualMachine.get())
        let ev = VirtualMachine.get().eventLoop()
        ev.enter()
        if (let msg <- errMsg) {
            promise.rejectWithAsyncStack(global, global.createErrorInstance(String.fromUtf8(msg)))
        } else {
            promise.resolve(global, JsValue.jsUndefined() )
        }
        deinit()
        ev.exit()
    }

    // ========================================================================
    // Linux 实现
    // ========================================================================

    /// 启动 Linux 移除流程
    public func startLinux(): Unit {
        state = RemoveState.readingCrontab
        stdoutReader = OutputReader.initForCronRemove()
        let crontabPath = findCrontab()
        if (crontabPath == none) {
            setErr("crontab not found in PATH")
            finish()
            return
        }
        let argv: Array<String> = [crontabPath.get(), "-l"]
        spawnCmd(argv, SpawnStdio.ignore, SpawnStdio.buffer)
    }

    /// 移除 crontab 条目
    public func removeCrontabEntry(): Unit {
        let existingContent = stdoutReader.finalBuffer()
        var result: Array<UInt8> = Array<UInt8>()

        filterCrontab(existingContent, title, result)

        let tmpPathVal = makeTempPath("bun-cron-rm-")
        if (tmpPathVal == none) {
            setErr("Out of memory")
            finish()
            return
        }
        tmpPath = tmpPathVal

        if (!writeFile(tmpPathVal.get(), result)) {
            setErr("Failed to write temp file")
            finish()
            return
        }

        state = RemoveState.installingCrontab
        stdoutReader = OutputReader.initForCronRemove()

        let crontabPath = findCrontab()
        if (crontabPath == none) {
            setErr("crontab not found in PATH")
            finish()
            return
        }

        let argv: Array<String> = [crontabPath.get(), tmpPathVal.get()]
        spawnCmd(argv, SpawnStdio.ignore, SpawnStdio.ignore)
    }

    // ========================================================================
    // macOS 实现
    // ========================================================================

    /// 启动 macOS 移除流程
    public func startMac(): Unit {
        state = RemoveState.bootingOut
        let uidStr = "gui/".append(getUid().toString()).append("/bun.cron.").append(title)

        let argv: Array<String> = ["/bin/launchctl", "bootout", uidStr]
        spawnCmd(argv, SpawnStdio.ignore, SpawnStdio.ignore)
    }

    // ========================================================================
    // Windows 实现
    // ========================================================================

    /// 启动 Windows 移除流程
    public func startWindows(): Unit {
        state = RemoveState.installingCrontab
        let taskName = "bun-cron-".append(title)

        let argv: Array<String> = ["schtasks", "/delete", "/tn", taskName, "/f"]
        spawnCmd(argv, SpawnStdio.ignore, SpawnStdio.ignore)
    }

    // ========================================================================
    // spawn 命令
    // ========================================================================

    public func spawnCmd(argv!: Array<String>, stdinOpt!: SpawnStdio, stdoutOpt!: SpawnStdio): Unit {
        hasCalledProcessExit = false
        exitStatus = none
        remainingFds = 0

        let spawnOpts = SpawnOptions()
        spawnOpts.stdin = stdinOpt
        spawnOpts.stdout = stdoutOpt
        spawnOpts.stderr = SpawnStdio.ignore

        let result = SpawnProcess.`spawn`(argv, spawnOpts)
        match (result) {
            case ok(proc) =>
                process = proc
                proc.setExitHandler(this)
                if (stdoutOpt == SpawnStdio.buffer) {
                    stdoutReader = OutputReader.initForCronRemove()
                    remainingFds += 1
                    stdoutReader.start(proc)
                }
                proc.watchOrReap()
            case err(err) =>
                setErr("Failed to spawn process: ".append(err.toString()))
                finish()
        }
    }

    // ========================================================================
    // 清理
    // ========================================================================

    public func deinit(): Unit {
        stdoutReader.deinit()
        stderrReader.deinit()
        if (let p <- tmpPath) {
            Syscall.unlink(p)
            tmpPath = none
        }
        if (let proc <- process) {
            proc.detach()
            process = none
        }
    }
}

// ============================================================================
// CronJob - 进程内回调式 cron (Bun.cron(expr, cb))
// ============================================================================

/// CronJob - 进程内回调式 cron
/// 使用引用计数管理, 通过事件循环计时器触发
public class CronJob {
    public var refCount: UInt32
    public var eventLoopTimer: EventLoopTimer
    public var global: JsGlobalObject
    public var parsed: CronExpression
    public var pollRef: AsyncKeepAlive
    public var thisValue: JsRef
    public var stopped: Bool
    public var lastNextMs: Float64
    public var pendingRef: Bool
    public var inFire: Bool

    public init() {
        refCount = 0
        eventLoopTimer = EventLoopTimer()
        global = JsGlobalObject.zero
        parsed = CronExpression()
        pollRef = AsyncKeepAlive()
        thisValue = JsRef.empty
        stopped = false
        lastNextMs = 0.0
        pendingRef = false
        inFire = false
    }

    // ========================================================================
    // 引用计数管理
    // ========================================================================

    /// 增加引用计数
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用计数, 到零时销毁
    public func deref(): Unit {
        if (refCount > 0) {
            refCount -= 1
        }
        if (refCount == 0) {
            destroyImpl()
        }
    }

    /// 销毁实现
    public func destroyImpl(): Unit {
        thisValue = JsRef.empty
    }

    // ========================================================================
    // JS 入口点
    // ========================================================================

    /// JS 入口: CronJob 构造函数 (不可直接构造)
    public static func constructor(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        globalObject.throwInvalidArguments("CronJob cannot be constructed directly; use Bun.cron(schedule, handler)")
        return JsValue.jsUndefined()
    }

    /// 注册进程内 cron 任务
    public static func register(jsGlobalObject!: JsGlobalObject, scheduleArg!: JsValue, callbackArg!: JsValue): JsValue {
        if (!scheduleArg.isString()) {
            globalObject.throwInvalidArguments("Bun.cron() expects a string cron expression")
            return JsValue.jsUndefined()
        }

        let scheduleStr = scheduleArg.toString(globalObject)
        if (scheduleStr == none) {
            return JsValue.jsUndefined()
        }

        let parsed: CronExpression = try {
            CronExpression.parse(scheduleStr.get())
        } catch (e: CronExpressionError) {
            globalObject.throwInvalidArguments(e.errorMessage())
            return JsValue.jsUndefined()
        }

        let vm = globalObject.bunVM()

        let job = CronJob()
        job.refCount = 1
        job.eventLoopTimer = EventLoopTimer.initPaused(EventLoopTimerTag.cronJob)
        job.global = globalObject
        job.parsed = parsed
        job.pollRef = AsyncKeepAlive()
        job.thisValue = JsRef.empty
        job.stopped = false
        job.lastNextMs = 0.0
        job.pendingRef = false
        job.inFire = false

        let nextTime = job.computeNextTimespec()
        if (nextTime == none) {
            // 无法计算下次触发时间 - 表达式没有未来的匹配项
            job.deref()
            globalObject.throwInvalidArguments("Cron expression '".append(scheduleStr.get()).append("' has no future occurrences"))
            return JsValue.jsUndefined()
        }

        // 如果是 hot reload 或 worker, 加入 cron_jobs 列表
        if (vm.hotReload || vm.worker != none) {
            job.ref()
            vm.rareData.cronJobs.append(job)
        }

        // 创建 JS 包装器
        let jsValue = CronJob.toJsPtr(job, globalObject)
        job.thisValue = JsRef.setStrong(jsValue, globalObject)
        // 设置缓存的 cron 和 callback
        JSCronJob.cronSetCached(jsValue, globalObject, scheduleArg)
        JSCronJob.callbackSetCached(jsValue, globalObject, callbackArg.withAsyncContextIfNeeded(globalObject))

        job.pollRef.ref(vm)
        vm.timer.update(job.eventLoopTimer, nextTime.get())

        return jsValue
    }

    // ========================================================================
    // 计时器回调
    // ========================================================================

    /// 计算下次触发时间
    public func computeNextTimespec(): ?Timespec {
        // Cron 触发是基于日历的 (实际 epoch); 计时器堆是单调的
        // 使用实际时间锚定, 以避免伪计时器半应用
        let nowMs: Float64 = Float64(Time.milliTimestamp())
        // 单调计时器可能在 wall-clock 目标之前略微触发
        // 在先前目标处 floor next(), 这样它不会重新计算同一分钟并重复触发
        let fromMs = max(nowMs, lastNextMs)
        let nextMs = parsed.next(global, fromMs)  ?? return none
        lastNextMs = nextMs
        let delta: Int64 = Int64(max(1.0, nextMs - nowMs))
        return Timespec.msFromNow(TimespecMockMode.forceRealTime, delta)
    }

    /// 调度下次触发
    public static func scheduleNext(job!: CronJob, vm!: VirtualMachine): Unit {
        // 每个到达这里的路径都刚刚从用户 JS 返回
        // 如果该 JS 调用了 process.exit() / worker.terminate(), 不要重新武装计时器
        if (job.stopped || vm.scriptExecutionStatus != ScriptExecutionStatus.running) {
            job.stopped = true
            finishDeferredStop(job, vm)
            return
        }
        let nextTime = job.computeNextTimespec()
        if (nextTime == none) {
            finishDeferredStop(job, vm)
            return
        }
        vm.timer.update(job.eventLoopTimer, nextTime.get())
    }

    /// 计时器触发回调
    public static func onTimerFire(job!: CronJob, vm!: VirtualMachine): Unit {
        // 先增加引用计数, 防止在回调中被释放
        job.ref()

        job.eventLoopTimer.state = EventLoopTimerState.fired

        if (job.stopped) {
            job.deref()
            return
        }
        if (vm.scriptExecutionStatus != ScriptExecutionStatus.running) {
            selfStop(job, vm)
            job.deref()
            return
        }

        let jsThis = job.thisValue.tryGet()
        if (jsThis == none) {
            selfStop(job, vm)
            job.deref()
            return
        }

        let cb = JSCronJob.callbackGetCached(jsThis.get())
        if (cb == none || cb.get().isUndefined()) {
            selfStop(job, vm)
            job.deref()
            return
        }

        job.inFire = true
        let result = cb.get().call(job.global, jsThis.get(), [])
        job.inFire = false

        if (result == none) {
            // 调用抛出异常
            if (let err <- job.global.tryTakeException()) {
                if (err.isTerminationException()) {
                    selfStop(job, vm)
                    job.deref()
                    return
                }
                let globalRef = vm.global()
                vm.uncaughtException(globalRef, err, false)
            }
            scheduleNext(job, vm)
            job.deref()
            return
        }

        // terminate() 可能在回调运行期间到达
        if (vm.scriptExecutionStatus != ScriptExecutionStatus.running) {
            selfStop(job, vm)
            job.deref()
            return
        }

        if (let promise <- result.get().asAnyPromise()) {
            match (promise.status()) {
                case pending =>
                    job.ref()
                    job.pendingRef = true
                    JSCronJob.pendingPromiseSetCached(jsThis.get(), job.global, result.get())
                    promise.then(job.global, job,
                        CronJob.onPromiseResolve,
                        CronJob.onPromiseReject)
                    // 检查 VM 状态 - then() 可能在终止时失败
                    if (vm.scriptExecutionStatus != ScriptExecutionStatus.running) {
                        JSCronJob.pendingPromiseSetCached(jsThis.get(), job.global, JsValue.jsUndefined())
                        releasePendingRef(job)
                        scheduleNext(job, vm)
                    }
                    job.deref()
                    return
                case fulfilled =>
                    () // 继续调度下次
                case rejected =>
                    promise.setHandled(job.global.vm())
                    let reason = promise.result(job.global.vm())
                    let globalRef = vm.global()
                    vm.unhandledRejection(globalRef, reason, result.get())
            }
        }

        scheduleNext(job, vm)
        job.deref()
    }

    /// Promise resolve 回调
    public static func onPromiseResolve(global!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.arguments()
        let job: CronJob = args[args.size - 1].asPromisePtr<CronJob>()

        releasePendingRef(job)

        let jsThis = job.thisValue.tryGet()
        if (jsThis != none) {
            JSCronJob.pendingPromiseSetCached(jsThis.get(), job.global, JsValue.jsUndefined())
        }

        let vm = job.global.bunVM()
        scheduleNext(job, vm)

        return JsValue.jsUndefined()
    }

    /// Promise reject 回调
    public static func onPromiseReject(global!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.arguments()
        let job: CronJob = args[args.size - 1].asPromisePtr<CronJob>()

        releasePendingRef(job)

        let vm = job.global.bunVM()
        let err = args[0]
        var promiseValue = JsValue.jsUndefined()

        let jsThis = job.thisValue.tryGet()
        if (jsThis != none) {
            promiseValue = JSCronJob.pendingPromiseGetCached(jsThis.get()) ?? JsValue.jsUndefined()
            JSCronJob.pendingPromiseSetCached(jsThis.get(), job.global, JsValue.jsUndefined())
        }

        let globalRef = vm.global()
        vm.unhandledRejection(globalRef, err, promiseValue)

        scheduleNext(job, vm)

        return JsValue.jsUndefined()
    }

    // ========================================================================
    // 停止和引用管理
    // ========================================================================

    /// 停止 cron 任务 (JS 入口: job.stop())
    public func stop(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        CronJob.selfStop(this, globalThis.bunVM())
        return callframe.`this`()
    }

    /// 引用 cron 任务 (JS 入口: job.ref())
    public func doRef(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        if (!stopped) { pollRef.ref(globalThis.bunVM()) }
        return callframe.`this`()
    }

    /// 取消引用 cron 任务 (JS 入口: job.unref())
    public func doUnref(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        pollRef.unref(globalThis.bunVM())
        return callframe.`this`()
    }

    /// 获取 cron 表达式 (JS getter: job.cron)
    public func getCron(): JsValue {
        return JsValue.jsUndefined() // 不可达 - register() 已通过 cronSetCached 预填充缓存
    }

    /// 内部停止
    public static func selfStop(job!: CronJob, vm!: VirtualMachine): Unit {
        // 当回调在堆栈上或其 promise 待定时, 延迟列表移除 + 降级
        if (job.inFire || job.pendingRef) {
            job.stopped = true
            job.pollRef.unref(vm)
            return
        }
        stopInternal(job, vm)
        removeFromList(job, vm)
    }

    /// 内部停止实现
    public static func stopInternal(job!: CronJob, vm!: VirtualMachine): Unit {
        job.stopped = true
        if (job.eventLoopTimer.state == EventLoopTimerState.active) {
            vm.timer.remove(job.eventLoopTimer)
        }
        job.pollRef.unref(vm)
        maybeDowngrade(job)
    }

    /// 延迟停止的完成
    public static func finishDeferredStop(job!: CronJob, vm!: VirtualMachine): Unit {
        stopInternal(job, vm)
        removeFromList(job, vm)
    }

    /// 从 VM 列表中移除
    public static func removeFromList(job!: CronJob, vm!: VirtualMachine): Unit {
        if (let rare <- vm.rareData) {
            let idx = rare.cronJobs.indexOf(job)
            if (idx != none) {
                rare.cronJobs.swapRemove(idx.get())
                job.deref()
            }
        }
    }

    /// 降级 JS 包装器
    public static func maybeDowngrade(job!: CronJob): Unit {
        if (job.stopped && !job.pendingRef && !job.thisValue.isFinalized()) {
            job.thisValue.downgrade()
        }
    }

    /// 释放待定引用
    public static func releasePendingRef(job!: CronJob): Unit {
        if (job.pendingRef) {
            job.pendingRef = false
            maybeDowngrade(job)
            job.deref()
        }
    }

    /// 清除 VM 上所有 cron 任务
    public static func clearAllForVM(vm!: VirtualMachine, mode!: ClearMode): Unit {
        let rare = vm.rareData ?? return
        // 先排空列表, 以便 stop_internal (重新进入 VM) 不会别名 rare 借用
        let jobs = rare.cronJobs.toArray()
        rare.cronJobs.clear()
        for (job in jobs) {
            stopInternal(job, vm)
            if (mode == ClearMode.teardown) {
                releasePendingRef(job)
            }
            job.deref()
        }
    }

    /// 定稿
    public func finalize(): Unit {
        thisValue.finalize()
    }

    // ========================================================================
    // ClearMode (moved to top-level)
    // ========================================================================

    // ========================================================================
    // JS 包装
    // ========================================================================

    /// 将 CronJob 指针转换为 JS 值
    public static func toJsPtr(job!: CronJob, global!: JsGlobalObject): JsValue {
        return JsFunction.wrapObject(global, job, "CronJob")
    }
}

// ============================================================================
// JSCronJob - JS 端缓存访问器辅助
// ============================================================================

/// JSCronJob - JS 端缓存访问器
/// 对应 Rust 中的 js:: 模块和 bun_jsc::codegen_cached_accessors!
public class JSCronJob {
    /// 设置缓存的 callback
    public static func callbackSetCached(jsThis!: JsValue, global!: JsGlobalObject, value!: JsValue): Unit {
        jsThis.putCached(global, "callback", value)
    }

    /// 获取缓存的 callback
    public static func callbackGetCached(jsThis!: JsValue): ?JsValue {
        return jsThis.getCached("callback")
    }

    /// 设置缓存的 cron 表达式
    public static func cronSetCached(jsThis!: JsValue, global!: JsGlobalObject, value!: JsValue): Unit {
        jsThis.putCached(global, "cron", value)
    }

    /// 获取缓存的 cron 表达式
    public static func cronGetCached(jsThis!: JsValue): ?JsValue {
        return jsThis.getCached("cron")
    }

    /// 设置缓存的 pending promise
    public static func pendingPromiseSetCached(jsThis!: JsValue, global!: JsGlobalObject, value!: JsValue): Unit {
        jsThis.putCached(global, "pendingPromise", value)
    }

    /// 获取缓存的 pending promise
    public static func pendingPromiseGetCached(jsThis!: JsValue): ?JsValue {
        return jsThis.getCached("pendingPromise")
    }
}

// ============================================================================
// getCronObject - 创建 Bun.cron 函数对象
// ============================================================================

/// 获取 Bun.cron 函数对象
/// 对应 Rust 中的 get_cron_object 函数
public func getCronObject(globalThis!: JsGlobalObject, arg!: JsObject): JsValue {
    let cronFn = JsFunction.create(globalThis, "cron", CronRegisterJob.cronRegister, 3)
    let removeFn = JsFunction.create(globalThis, "remove", CronRemoveJob.cronRemove, 1)
    let parseFn = JsFunction.create(globalThis, "parse", cronParse, 1)
    cronFn.put(globalThis, BunString.`static`("remove"), removeFn)
    cronFn.put(globalThis, BunString.`static`("parse"), parseFn)
    return cronFn
}

// ============================================================================
// cronRegister - JS 入口: Bun.cron(path, schedule, title) 或 Bun.cron(schedule, handler)
// ============================================================================

/// cronRegister - JS 入口
/// Bun.cron(schedule, handler)       - 进程内回调 cron (返回 CronJob)
/// Bun.cron(path, schedule, title)   - 注册 OS 级任务 (返回 Promise)
public func cronRegister(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    let args = callframe.argumentsAsArray3()

    // 进程内回调 cron: Bun.cron(schedule, handler)
    if (args[1].isCallable()) {
        return CronJob.register(globalObject, args[0], args[1])
    }

    if (args[0].isString() && args[2].isUndefined()) {
        globalObject.throwInvalidArguments("Bun.cron(schedule, handler) expects a function handler as the second argument")
        return JsValue.jsUndefined()
    }

    if (!args[0].isString()) {
        globalObject.throwInvalidArguments("Bun.cron() expects a string path as the first argument")
        return JsValue.jsUndefined()
    }
    if (!args[1].isString()) {
        globalObject.throwInvalidArguments("Bun.cron() expects a string schedule as the second argument")
        return JsValue.jsUndefined()
    }
    if (!args[2].isString()) {
        globalObject.throwInvalidArguments("Bun.cron() expects a string title as the third argument")
        return JsValue.jsUndefined()
    }

    let pathStr = args[0].toString(globalObject) ?? ""
    let scheduleStr = args[1].toString(globalObject) ?? ""
    let titleStr = args[2].toString(globalObject) ?? ""

    // 验证标题: 只允许 [a-zA-Z0-9_-]
    if (!validateTitle(titleStr)) {
        globalObject.throwInvalidArguments("Cron title must contain only alphanumeric characters, hyphens, and underscores")
        return JsValue.jsUndefined()
    }

    // 解析并规范化 cron 调度为数字形式
    let parsed: CronExpression = try {
        CronExpression.parse(scheduleStr)
    } catch (e: CronExpressionError) {
        globalObject.throwInvalidArguments(e.errorMessage())
        return JsValue.jsUndefined()
    }
    let normalizedSchedule = parsed.formatNumericString()

    let absPathVal = resolvePath(globalObject, callframe, pathStr)
    if (absPathVal == none) {
        globalObject.throwInvalidArguments("Failed to resolve path")
        return JsValue.jsUndefined()
    }

    // 验证路径不包含单引号或百分号
    for (c in absPathVal.get()) {
        if (c == '\'') {
            globalObject.throwInvalidArguments("Path must not contain single quotes")
            return JsValue.jsUndefined()
        }
        if (c == '%') {
            globalObject.throwInvalidArguments("Path must not contain percent signs (cron interprets % as newline)")
            return JsValue.jsUndefined()
        }
        if (c == '\n' || c == '\r') {
            globalObject.throwInvalidArguments("Path must not contain line breaks")
            return JsValue.jsUndefined()
        }
    }

    let bunExe = getSelfExePath()
    if (bunExe == none) {
        globalObject.throwInvalidArguments("Failed to get bun executable path")
        return JsValue.jsUndefined()
    }

    // 检查 bun 可执行路径中的特殊字符
    for (c in bunExe.get()) {
        if (c == '\'' || c == '%') {
            globalObject.throwInvalidArguments("Bun executable path '".append(bunExe.get()).append("' contains characters (' or %) that cannot be safely embedded in a crontab entry"))
            return JsValue.jsUndefined()
        }
    }

    let job = CronRegisterJob()
    job.promise = JSPromiseStrong(globalObject)
    job.global = globalObject
    job.poll = AsyncKeepAlive()
    job.bunExe = bunExe.get()
    job.absPath = absPathVal.get()
    job.schedule = normalizedSchedule
    job.title = titleStr
    job.parsedCron = parsed
    job.state = RegisterState.readingCrontab
    job.process = none
    job.stdoutReader = OutputReader.initForCronRegister()
    job.stderrReader = OutputReader.initForCronRegister()
    job.remainingFds = 0
    job.hasCalledProcessExit = false
    job.exitStatus = none
    job.errMsg = none
    job.tmpPath = none
    job.eventLoopHandle = EventLoopHandle(VirtualMachine.get().eventLoop())

    job.poll.ref(VirtualMachine.get())
    let promiseValue = job.promise.getValue()

    // 根据平台启动注册流程
    if (Syscall.isMacOS()) {
        job.startMac()
    } else if (Syscall.isWindows()) {
        job.startWindows()
    } else {
        job.startLinux()
    }

    return promiseValue
}

// ============================================================================
// cronRemove - JS 入口: Bun.cron.remove(title)
// ============================================================================

/// cronRemove - JS 入口: 移除 OS 级 cron 任务
public func cronRemove(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    let args = callframe.argumentsAsArray1()
    if (!args[0].isString()) {
        globalObject.throwInvalidArguments("Bun.cron.remove() expects a string title")
        return JsValue.jsUndefined()
    }

    let titleStr = args[0].toString(globalObject) ?? ""

    if (!validateTitle(titleStr)) {
        globalObject.throwInvalidArguments("Cron title must contain only alphanumeric characters, hyphens, and underscores")
        return JsValue.jsUndefined()
    }

    let job = CronRemoveJob()
    job.promise = JSPromiseStrong(globalObject)
    job.global = globalObject
    job.poll = AsyncKeepAlive()
    job.title = titleStr
    job.state = RemoveState.readingCrontab
    job.process = none
    job.stdoutReader = OutputReader.initForCronRemove()
    job.stderrReader = OutputReader.initForCronRemove()
    job.remainingFds = 0
    job.hasCalledProcessExit = false
    job.exitStatus = none
    job.errMsg = none
    job.tmpPath = none
    job.eventLoopHandle = EventLoopHandle(VirtualMachine.get().eventLoop())

    job.poll.ref(VirtualMachine.get())
    let promiseValue = job.promise.getValue()

    // 根据平台启动移除流程
    if (Syscall.isMacOS()) {
        job.startMac()
    } else if (Syscall.isWindows()) {
        job.startWindows()
    } else {
        job.startLinux()
    }

    return promiseValue
}

// ============================================================================
// cronParse - JS 入口: Bun.cron.parse(expr, from?)
// ============================================================================

/// cronParse - JS 入口: 下次触发时间计算器
/// Bun.cron.parse(expr, from?) 返回 Date | null
public func cronParse(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    let args = callframe.argumentsAsArray2()

    if (!args[0].isString()) {
        globalObject.throwInvalidArguments("Bun.cron.parse() expects a string cron expression as the first argument")
        return JsValue.jsUndefined()
    }

    let exprStr = args[0].toString(globalObject) ?? ""

    let parsed: CronExpression = try {
        CronExpression.parse(exprStr)
    } catch (e: CronExpressionError) {
        globalObject.throwInvalidArguments(e.errorMessage())
        return JsValue.jsUndefined()
    }

    var fromMs: Float64 = Float64(Time.milliTimestamp())
    if (!args[1].isEmpty() && !args[1].isUndefined() && !args[1].isNull()) {
        if (args[1].isNumber()) {
            fromMs = args[1].toNumber(globalObject) ?? fromMs
        } else if (args[1].jsType() == JSType.jsDate) {
            fromMs = args[1].toNumber(globalObject) ?? fromMs
        } else {
            globalObject.throwInvalidArguments("Bun.cron.parse() expects the second argument to be a Date or number (ms since epoch)")
            return JsValue.jsUndefined()
        }
    }

    if (fromMs.isNaN() || fromMs.isInfinite()) {
        globalObject.throwInvalidArguments("Invalid date value")
        return JsValue.jsUndefined()
    }

    let nextMs = parsed.next(globalObject, fromMs) 
    if (nextMs == none) {
        return JsValue.jsNull()
    }
    return JsValue.fromDateNumber(globalObject, nextMs.get())
}

// ============================================================================
// 共享辅助函数
// ============================================================================

/// 验证标题: 只允许 [a-zA-Z0-9_-], 非空
public func validateTitle(title!: String): Bool {
    if (title.isEmpty()) { return false }
    for (c in title) {
        if (!c.isAlphanumeric() && c != '-' && c != '_') { return false }
    }
    return true
}

/// 验证标题 (字节版本)
public func validateTitle(title!: Array<UInt8>): Bool {
    if (title.isEmpty) { return false }
    for (c in title) {
        let ch = Int32(c)
        let isAlpha = (ch >= Int32('a') && ch <= Int32('z')) || (ch >= Int32('A') && ch <= Int32('Z'))
        let isDigit = ch >= Int32('0') && ch <= Int32('9')
        if (!isAlpha && !isDigit && c != UInt8('-') && c != UInt8('_')) { return false }
    }
    return true
}

/// 过滤 crontab 内容, 移除匹配标题标记的条目
public func filterCrontab(content!: Array<UInt8>, title!: String, result!: Array<UInt8>): Unit {
    let marker = "# bun-cron: ".append(title)
    var skipNext = false

    // 按行分割
    var lineStart: Int = 0
    for (i in 0..content.size + 1) {
        if (i == content.size || content[i] == UInt8('\n')) {
            if (skipNext) {
                skipNext = false
                lineStart = i + 1
                continue
            }

            // 跳过行首空白
            var start = lineStart
            while (start < i && (content[start] == UInt8(' ') || content[start] == UInt8('\t'))) {
                start++
            }
            var end = i
            while (end > start && (content[end - 1] == UInt8(' ') || content[end - 1] == UInt8('\t'))) {
                end--
            }

            // 检查是否是标记行
            let markerBytes = marker.toUtf8().toArray()
            if (end - start == markerBytes.size) {
                var isMarker = true
                for (j in 0..markerBytes.size) {
                    if (content[start + j] != markerBytes[j]) {
                        isMarker = false
                        break
                    }
                }
                if (isMarker) {
                    skipNext = true
                    lineStart = i + 1
                    continue
                }
            }

            // 追加非空行
            if (i > lineStart) {
                for (j in lineStart..i) {
                    result.append(content[j])
                }
                result.append(UInt8('\n'))
            }
            lineStart = i + 1
        }
    }
}

/// XML 转义字符串
public func xmlEscape(input!: String): String {
    var needsEscape = false
    for (c in input) {
        if (c == '&' || c == '<' || c == '>' || c == '"' || c == '\'') {
            needsEscape = true
            break
        }
    }
    if (!needsEscape) { return input }

    var result = StringBuilder()
    for (c in input) {
        match (c) {
            case '&' => result.append("&amp;")
            case '<' => result.append("&lt;")
            case '>' => result.append("&gt;")
            case '"' => result.append("&quot;")
            case '\'' => result.append("&apos;")
            case _ => result.append(c)
        }
    }
    return result.toString()
}

/// XML 转义 (字节版本)
public func xmlEscapeBytes(input!: Array<UInt8>): ?Array<UInt8> {
    var needsEscape = false
    for (c in input) {
        if (c == UInt8('&') || c == UInt8('<') || c == UInt8('>') || c == UInt8('"') || c == UInt8('\'')) {
            needsEscape = true
            break
        }
    }
    if (!needsEscape) { return input }

    var result = Array<UInt8>()
    for (c in input) {
        if (c == UInt8('&')) {
            result.appendAll("&amp;".toUtf8().toArray())
        } else if (c == UInt8('<')) {
            result.appendAll("&lt;".toUtf8().toArray())
        } else if (c == UInt8('>')) {
            result.appendAll("&gt;".toUtf8().toArray())
        } else if (c == UInt8('"')) {
            result.appendAll("&quot;".toUtf8().toArray())
        } else if (c == UInt8('\'')) {
            result.appendAll("&apos;".toUtf8().toArray())
        } else {
            result.append(c)
        }
    }
    return result
}

/// 查找 crontab 二进制
public func findCrontab(): ?String {
    if (Syscall.isWindows()) { return none }
    let pathEnv = EnvVar.PATH.get() ?? "/usr/bin:/bin"
    return Which.which("crontab", pathEnv, "")
}

/// 获取当前用户 ID
public func getUid(): UInt32 {
    return Syscall.getuid()
}

/// 获取 bun 可执行路径
public func getSelfExePath(): ?String {
    return Syscall.selfExePath()
}

/// 解析模块路径
public func resolvePath(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame, pathStr!: String): ?String {
    let vm = globalObject.bunVM()
    let srcloc = callframe.getCallerSrcLoc(globalObject)
    let callerDir = PathUtils.dirname(srcloc.str)
    let sourceDir: String = if (callerDir.isEmpty()) { "." } else { callerDir }

    let resolved = vm.transpiler.resolver.resolve(sourceDir, pathStr, ImportKind.entryPointRun)
    if (resolved == none) { return none }
    return resolved.get().path()?.text
}

/// 创建临时文件路径
public func makeTempPath(prefix!: String): ?String {
    let fullPrefix = prefix.append("tmp")
    let name = FileSystem.tmpname(fullPrefix, CoreUtils.fastRandom())
    if (name == none) { return none }
    return PathUtils.joinAbsString(FileSystem.platformTempDir(), [name.get()])
}

/// 写入文件
public func writeFile(path!: String, content!: Array<UInt8>): Bool {
    return Syscall.writeFile(path, content)
}

/// 递归创建目录
public func makeDirAll(path!: String): Bool {
    return Syscall.mkdirp(path)
}

// ============================================================================
// macOS launchd 相关: cron 表达式转换为 StartCalendarInterval
// ============================================================================

/// CalendarError
public enum CalendarError {
    | invalidCron
    | outOfMemory
}

/// 将 cron 表达式转换为 launchd StartCalendarInterval XML
public func cronToCalendarInterval(schedule!: String): ?String {
    // 按 ' ' 分割, 跳过空白
    var fields: Array<Array<UInt8>> = Array<Array<UInt8>>()
    let bytes = schedule.toUtf8().toArray()

    var fieldStart: Int = 0
    for (i in 0..bytes.size + 1) {
        if (i == bytes.size || bytes[i] == UInt8(' ')) {
            if (i > fieldStart) {
                var field = Array<UInt8>()
                for (j in fieldStart..i) {
                    field.append(bytes[j])
                }
                if (fields.size >= 5) {
                    return none // TooManyFields
                }
                fields.append(field)
            }
            fieldStart = i + 1
        }
    }

    if (fields.size != 5) { return none }

    // 解析每个字段为整数值列表 (或 none 表示 "*")
    var fieldValues: Array<?Array<Int32>> = [none, none, none, none, none]

    for (idx in 0..5) {
        if (fields[idx].size == 1 && fields[idx][0] == UInt8('*')) {
            continue // 通配符
        }
        var vals = Array<Int32>()
        // 按 ',' 分割
        var partStart: Int = 0
        for (j in 0..fields[idx].size + 1) {
            if (j == fields[idx].size || fields[idx][j] == UInt8(',')) {
                if (j == partStart) { return none }
                var part = Array<UInt8>()
                for (k in partStart..j) {
                    part.append(fields[idx][k])
                }
                let val = parseUnsigned32(part)
                if (val == none) { return none }
                vals.append(val.get())
                partStart = j + 1
            }
        }
        fieldValues[idx] = vals
    }

    // 生成 StartCalendarInterval 字典
    let hasDom = fieldValues[2] != none
    let hasDow = fieldValues[4] != none
    let needsOrSplit = hasDom && hasDow

    // 确定是否需要 <array> 包装器
    let needsProduct = fieldValues.any({ fv =>
        if (let v <- fv) { v.size > 1 } else { false }
    })
    let needsArray = needsProduct || needsOrSplit

    // 转为切片引用
    var fvSlices: Array<?Array<Int32>> = fieldValues

    if (!needsArray) {
        // 单个字典, 不需要乘积
        let plistKeys: Array<String> = ["Minute", "Hour", "Day", "Month", "Weekday"]
        var result = "    <dict>\n"
        for (i in 0..5) {
            if (let vals <- fvSlices[i]) {
                if (vals.size == 1) {
                    result = result.append("        <key>").append(plistKeys[i]).append("</key>\n")
                    result = result.append("        <integer>").append(vals[0].toString()).append("</integer>\n")
                }
            }
        }
        result = result.append("    </dict>")
        return result
    }

    var result = "    <array>\n"

    if (needsOrSplit) {
        // OR 分割: 先发出 day-of-month 字典 (无 Weekday), 然后发出 day-of-week 字典 (无 Day)
        result = result.append(emitCalendarDicts(fvSlices, EmitMode.excludeWeekday))
        result = result.append(emitCalendarDicts(fvSlices, EmitMode.excludeDay))
    } else {
        // 普通笛卡尔积: 所有字段一起
        result = result.append(emitCalendarDicts(fvSlices, EmitMode.includeAll))
    }

    result = result.append("    </array>")
    return result
}

/// 解析无符号 32 位整数
public func parseUnsigned32(s!: Array<UInt8>): ?Int32 {
    if (s.isEmpty) { return none }
    var result: Int32 = 0
    for (i in 0..s.size) {
        let c = s[i]
        if (c < UInt8('0') || c > UInt8('9')) { return none }
        let digit = Int32(c) - Int32(UInt8('0'))
        if (result > (Int32.max - digit) / 10) { return none }
        result = result * 10 + digit
    }
    return result
}

/// EmitMode - 日历字典的发射模式
public enum EmitMode {
    | includeAll
    | excludeWeekday
    | excludeDay
}

/// 发射笛卡尔积 <dict> 条目
public func emitCalendarDicts(fieldValues!: Array<?Array<Int32>>, mode!: EmitMode): String {
    let plistKeys: Array<String> = ["Minute", "Hour", "Day", "Month", "Weekday"]

    // 根据模式构建有效字段值
    var effective: Array<?Array<Int32>> = fieldValues.toArray()
    match (mode) {
        case excludeWeekday => effective[4] = none
        case excludeDay => effective[2] = none
        case includeAll => ()
    }

    let zeroArr: Array<Int32> = [0]
    let iterMins: Array<Int32> = effective[0] ?? zeroArr
    let iterHrs: Array<Int32> = effective[1] ?? zeroArr
    let iterDays: Array<Int32> = effective[2] ?? zeroArr
    let iterMons: Array<Int32> = effective[3] ?? zeroArr
    let iterWdays: Array<Int32> = effective[4] ?? zeroArr

    var result = ""

    for (m in iterMins) {
        for (h in iterHrs) {
            for (d in iterDays) {
                for (mo in iterMons) {
                    for (w in iterWdays) {
                        result = result.append("    <dict>\n")
                        if (effective[0] != none) {
                            result = result.append("        <key>").append(plistKeys[0]).append("</key>\n")
                            result = result.append("        <integer>").append(m.toString()).append("</integer>\n")
                        }
                        if (effective[1] != none) {
                            result = result.append("        <key>").append(plistKeys[1]).append("</key>\n")
                            result = result.append("        <integer>").append(h.toString()).append("</integer>\n")
                        }
                        if (effective[2] != none) {
                            result = result.append("        <key>").append(plistKeys[2]).append("</key>\n")
                            result = result.append("        <integer>").append(d.toString()).append("</integer>\n")
                        }
                        if (effective[3] != none) {
                            result = result.append("        <key>").append(plistKeys[3]).append("</key>\n")
                            result = result.append("        <integer>").append(mo.toString()).append("</integer>\n")
                        }
                        if (effective[4] != none) {
                            result = result.append("        <key>").append(plistKeys[4]).append("</key>\n")
                            result = result.append("        <integer>").append(w.toString()).append("</integer>\n")
                        }
                        result = result.append("    </dict>\n")
                    }
                }
            }
        }
    }

    return result
}

// ============================================================================
// Windows schtasks 相关: cron 表达式转换为 Task Scheduler XML
// ============================================================================

/// TaskXmlError
public enum TaskXmlError {
    | invalidCron
    | tooManyTriggers
    | outOfMemory
}

/// 构建从已解析 cron 表达式的 Windows Task Scheduler XML 定义
/// 对简单间隔使用 TimeTrigger+Repetition, 对复杂计划使用 CalendarTrigger
public func cronToTaskXml(
    cron: CronExpression,
    bunExe: Array<UInt8>,
    title: Array<UInt8>,
    schedule: Array<UInt8>,
    absPath: Array<UInt8>
): Option<Array<UInt8>> {
    var xml = Array<UInt8>()
    xml.appendAll("<?xml version=\"1.0\"?>\n<Task version=\"1.2\" xmlns=\"http://schemas.microsoft.com/windows/2004/02/mit/task\">\n  <Triggers>\n".toUtf8().toArray())

    // 使用语义检查 (位字段值) 而不是语法标志来检测通配符
    let daysIsWild = cron.days == CronExpression.allDays
    let weekdaysIsWild = cron.weekdays == CronExpression.allWeekdays
    let monthsIsWild = cron.months == CronExpression.allMonths

    // 尝试使用带 Repetition 的单个触发器来处理简单的重复模式
    // 这避免了高频表达式的 48 触发器限制
    let minuteInterval = computeStepInterval64(cron.minutes, 0, 59)
    let hourInterval = computeStepInterval32(cron.hours, 0, 23)
    let minutesCount: UInt32 = UInt32(CronExpression.popCount64(cron.minutes))
    let hoursCount: UInt32 = UInt32(CronExpression.popCount32(cron.hours))

    // 情况 1: 所有小数都激活, 均匀间隔的分钟数能整除 60
    // 情况 2: 单个分钟, 均匀间隔的小时数能整除 24
    var canUseRepetition = false
    if (daysIsWild && weekdaysIsWild && monthsIsWild) {
        if (hoursCount == 24
            && minuteInterval != none
            && minuteInterval.get() <= 60
            && 60 % minuteInterval.get() == 0
            && minutesCount == 60 / minuteInterval.get()) {
            canUseRepetition = true // 情况 1
        } else if (minutesCount == 1
            && hourInterval != none
            && hourInterval.get() <= 24
            && 24 % hourInterval.get() == 0
            && hoursCount == 24 / hourInterval.get()) {
            canUseRepetition = true // 情况 2
        }
    }

    if (canUseRepetition) {
        let firstMin: Int = CronExpression.trailingZeros64(cron.minutes)
        let firstHour: Int = CronExpression.trailingZeros32(cron.hours)

        let sb = "2000-01-01T".append(String.format("%02d", firstHour)).append(":").append(String.format("%02d", firstMin)).append(":00")

        xml.appendAll("    <CalendarTrigger>\n".toUtf8().toArray())
        xml.appendAll("      <StartBoundary>".toUtf8().toArray())
        xml.appendAll(sb.toUtf8().toArray())
        xml.appendAll("</StartBoundary>\n".toUtf8().toArray())

        if (hoursCount == 24) {
            // 情况 1: 基于分钟的重复
            let m = minuteInterval.get()
            if (m == 1) {
                xml.appendAll("      <Repetition><Interval>PT1M</Interval></Repetition>\n".toUtf8().toArray())
            } else {
                xml.appendAll("      <Repetition><Interval>PT".toUtf8().toArray())
                xml.appendAll(m.toString().toUtf8().toArray())
                xml.appendAll("M</Interval></Repetition>\n".toUtf8().toArray())
            }
        } else {
            // 情况 2: 基于小时的重复
            let h = hourInterval.get()
            if (h > 1) {
                xml.appendAll("      <Repetition><Interval>PT".toUtf8().toArray())
                xml.appendAll(h.toString().toUtf8().toArray())
                xml.appendAll("H</Interval></Repetition>\n".toUtf8().toArray())
            }
        }

        xml.appendAll("      <ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay>\n".toUtf8().toArray())
        xml.appendAll("    </CalendarTrigger>\n".toUtf8().toArray())
    } else {
        // 复杂模式: 为每个 hour x minute 对发出 CalendarTriggers
        // 限制在 48 个触发器 (Task Scheduler 限制)
        let needsOrSplit = !daysIsWild && !weekdaysIsWild
        let triggersPerTime: UInt32 = if (needsOrSplit) { 2 } else { 1 }
        let totalTriggers = minutesCount * hoursCount * triggersPerTime
        if (totalTriggers > 48) {
            return none // TooManyTriggers
        }

        var hoursBits = cron.hours
        while (hoursBits != 0) {
            let h: Int = trailingZeros32(hoursBits)
            hoursBits &= hoursBits - 1
            var minsBits = cron.minutes
            while (minsBits != 0) {
                let m: Int = trailingZeros64(minsBits)
                minsBits &= minsBits - 1

                let sb = "2000-01-01T".append(String.format("%02d", h)).append(":").append(String.format("%02d", m)).append(":00")

                // 如果需要, 发出 day-of-month 触发器
                if (!daysIsWild) {
                    appendCalendarTriggerWithSchedule(xml, sb,
                        ScheduleType.byMonth(cron, monthsIsWild))
                }

                // 如果需要, 发出 day-of-week 触发器
                if (!weekdaysIsWild) {
                    if (monthsIsWild) {
                        appendCalendarTriggerWithSchedule(xml, sb,
                            ScheduleType.byWeek(cron.weekdays))
                    } else {
                        // 使用 ScheduleByMonthDayOfWeek 包含月份限制
                        appendCalendarTriggerWithSchedule(xml, sb,
                            ScheduleType.byMonthDow(cron, monthsIsWild))
                    }
                }

                // 两者都为通配符: 每天 (有可选的月份限制)
                if (daysIsWild && weekdaysIsWild) {
                    if (monthsIsWild) {
                        appendCalendarTriggerWithSchedule(xml, sb, ScheduleType.byDay)
                    } else {
                        // 每日但限制月份 -> 使用 ScheduleByMonth 且所有天
                        appendCalendarTriggerWithSchedule(xml, sb,
                            ScheduleType.byMonthAllDays(cron.months))
                    }
                }
            }
        }
    }

    // 关闭触发器, 添加操作
    let xmlBun = xmlEscapeBytes(bunExe) ?? bunExe
    let xmlTitle = xmlEscapeBytes(title) ?? title
    let xmlSched = xmlEscapeBytes(schedule) ?? schedule
    let xmlPath = xmlEscapeBytes(absPath) ?? absPath

    xml.appendAll("  </Triggers>\n  <Principals>\n    <Principal>\n      <LogonType>S4U</LogonType>\n      <RunLevel>LeastPrivilege</RunLevel>\n    </Principal>\n  </Principals>\n  <Settings>\n    <Enabled>true</Enabled>\n    <AllowStartOnDemand>true</AllowStartOnDemand>\n    <AllowHardTerminate>true</AllowHardTerminate>\n    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>\n    <StartWhenAvailable>true</StartWhenAvailable>\n  </Settings>\n  <Actions>\n    <Exec>\n      <Command>".toUtf8().toArray())
    xml.appendAll(xmlBun)
    xml.appendAll("</Command>\n      <Arguments>run --cron-title=".toUtf8().toArray())
    xml.appendAll(xmlTitle)
    xml.appendAll(" --cron-period=\"".toUtf8().toArray())
    xml.appendAll(xmlSched)
    xml.appendAll("\" \"".toUtf8().toArray())
    xml.appendAll(xmlPath)
    xml.appendAll("\"</Arguments>\n    </Exec>\n  </Actions>\n</Task>\n".toUtf8().toArray())

    return xml
}

/// ScheduleType - 计划类型
public enum ScheduleType {
    | byDay
    | byWeek(UInt8)           // weekdays 位掩码
    | byMonth(CronExpression, Bool)  // cron, months_is_wild
    | byMonthDow(CronExpression, Bool) // cron, months_is_wild
    | byMonthAllDays(UInt16)  // months 位掩码
}

/// 追加带计划的日历触发器
public func appendCalendarTriggerWithSchedule(xml!: Array<UInt8>, startBoundary!: String, sched!: ScheduleType): Unit {
    xml.appendAll("    <CalendarTrigger>\n".toUtf8().toArray())
    xml.appendAll("      <StartBoundary>".toUtf8().toArray())
    xml.appendAll(startBoundary.toUtf8().toArray())
    xml.appendAll("</StartBoundary>\n".toUtf8().toArray())

    match (sched) {
        case byDay =>
            xml.appendAll("      <ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay>\n".toUtf8().toArray())
        case byWeek(weekdays) =>
            xml.appendAll("      <ScheduleByWeek>\n".toUtf8().toArray())
            xml.appendAll("        <WeeksInterval>1</WeeksInterval>\n".toUtf8().toArray())
            appendDaysOfWeekXml(xml, weekdays)
            xml.appendAll("      </ScheduleByWeek>\n".toUtf8().toArray())
        case byMonth(cron, _) =>
            xml.appendAll("      <ScheduleByMonth>\n".toUtf8().toArray())
            appendDaysOfMonthXml(xml, cron.days)
            appendMonthsXml(xml, cron.months)
            xml.appendAll("      </ScheduleByMonth>\n".toUtf8().toArray())
        case byMonthDow(cron, _) =>
            xml.appendAll("      <ScheduleByMonthDayOfWeek>\n".toUtf8().toArray())
            xml.appendAll("        <Weeks><Week>1</Week><Week>2</Week><Week>3</Week><Week>4</Week><Week>Last</Week></Weeks>\n".toUtf8().toArray())
            appendDaysOfWeekXml(xml, cron.weekdays)
            appendMonthsXml(xml, cron.months)
            xml.appendAll("      </ScheduleByMonthDayOfWeek>\n".toUtf8().toArray())
        case byMonthAllDays(months) =>
            xml.appendAll("      <ScheduleByMonth>\n".toUtf8().toArray())
            appendDaysOfMonthXml(xml, 0xFFFFFFFE)
            appendMonthsXml(xml, months)
            xml.appendAll("      </ScheduleByMonth>\n".toUtf8().toArray())
    }

    xml.appendAll("    </CalendarTrigger>\n".toUtf8().toArray())
}

/// 追加 days-of-month XML
public func appendDaysOfMonthXml(xml!: Array<UInt8>, days!: UInt32): Unit {
    xml.appendAll("        <DaysOfMonth>\n".toUtf8().toArray())
    for (day in 1..33) {
        if (days & (UInt32(1) << UInt32(day)) != 0) {
            xml.appendAll("          <Day>".toUtf8().toArray())
            xml.appendAll(day.toString().toUtf8().toArray())
            xml.appendAll("</Day>\n".toUtf8().toArray())
        }
    }
    xml.appendAll("        </DaysOfMonth>\n".toUtf8().toArray())
}

/// 月份名称
public let monthNames: Array<String> = [
    "", "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
]

/// 追加 months XML
public func appendMonthsXml(xml!: Array<UInt8>, months!: UInt16): Unit {
    xml.appendAll("        <Months>\n".toUtf8().toArray())
    for (mo in 1..14) {
        if (months & (UInt16(1) << UInt16(mo)) != 0) {
            xml.appendAll("          <".toUtf8().toArray())
            xml.appendAll(monthNames[mo].toUtf8().toArray())
            xml.appendAll("/>\n".toUtf8().toArray())
        }
    }
    xml.appendAll("        </Months>\n".toUtf8().toArray())
}

/// 星期名称
public let dayNames: Array<String> = [
    "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
]

/// 追加 days-of-week XML
public func appendDaysOfWeekXml(xml!: Array<UInt8>, weekdays!: UInt8): Unit {
    xml.appendAll("        <DaysOfWeek>\n".toUtf8().toArray())
    for (d in 0..8) {
        if (weekdays & (UInt8(1) << UInt8(d)) != 0) {
            xml.appendAll("          <".toUtf8().toArray())
            xml.appendAll(dayNames[d].toUtf8().toArray())
            xml.appendAll("/>\n".toUtf8().toArray())
        }
    }
    xml.appendAll("        </DaysOfWeek>\n".toUtf8().toArray())
}

/// 计算 32 位 trailing zeros
public func trailingZeros32(v!: UInt32): Int {
    if (v == 0) { return 32 }
    var count: Int = 0
    var temp = v
    while ((temp & 1) == 0) {
        count++
        temp >>= 1
    }
    return count
}

/// 计算 64 位 trailing zeros
public func trailingZeros64(v!: UInt64): Int {
    if (v == 0) { return 64 }
    var count: Int = 0
    var temp = v
    while ((temp & 1) == 0) {
        count++
        temp >>= 1
    }
    return count
}

/// 如果所有设置位均匀间隔, 则返回步长大小, 否则返回 none (64位)
public func computeStepInterval64(bits!: UInt64, min!: UInt8, max!: UInt8): ?UInt32 {
    if (bits == 0) { return none }
    let count = CronExpression.popCount64(bits)
    if (count == 1) { return UInt32(max) + 1 }

    // 找到前两个设置位以确定步长
    var remaining = bits
    let first: Int = CronExpression.trailingZeros64(remaining)
    remaining = remaining & (remaining - 1)
    let second: Int = CronExpression.trailingZeros64(remaining)
    let step = UInt32(second - first)

    // 验证所有位是否均匀间隔
    remaining = remaining & (remaining - 1)
    var prev = second
    while (remaining != 0) {
        let next: Int = CronExpression.trailingZeros64(remaining)
        if (UInt32(next - prev) != step) { return none }
        prev = next
        remaining = remaining & (remaining - 1)
    }
    return step
}

/// 如果所有设置位均匀间隔, 则返回步长大小, 否则返回 none (32位)
public func computeStepInterval32(bits!: UInt32, min!: UInt8, max!: UInt8): ?UInt32 {
    if (bits == 0) { return none }
    let count = CronExpression.popCount32(bits)
    if (count == 1) { return UInt32(max) + 1 }

    // 找到前两个设置位以确定步长
    var remaining = bits
    let first: Int = trailingZeros32(remaining)
    remaining = remaining & (remaining - 1)
    let second: Int = trailingZeros32(remaining)
    let step = UInt32(second - first)

    // 验证所有位是否均匀间隔
    remaining = remaining & (remaining - 1)
    var prev = second
    while (remaining != 0) {
        let next: Int = trailingZeros32(remaining)
        if (UInt32(next - prev) != step) { return none }
        prev = next
        remaining = remaining & (remaining - 1)
    }
    return step
}
