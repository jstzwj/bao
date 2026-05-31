// 严格翻译自: src/runtime/api/cron.zig
//   Bun.cron — 进程内和操作系统级 cron 调度
//
//   Bun.cron(schedule, handler)       — 在调度上运行回调 (返回 CronJob)
//   Bun.cron(path, schedule, title)   — 注册 OS 级任务 (返回 Promise)
//   Bun.cron.remove(title)            — 移除 OS 级任务 (返回 Promise)
//   Bun.cron.parse(expr, from?)       — 下次匹配计算器 (返回 Date | null)
//
//   OS 级使用 crontab (Linux), launchctl + launchd plist (macOS), 或
//   schtasks (Windows)。异步，事件循环集成通过 bun.spawn。
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame}
import bao_core.*

// ============================================================================
// CronJobBase — CronRegisterJob 和 CronRemoveJob 的共享基类
// 翻译自: cron.zig fn CronJobBase(comptime Self: type) type
// ============================================================================

/// CronJobBase — cron 任务的公共方法
/// 翻译自: cron.zig CronJobBase — 提供 loop/eventLoop/onReaderDone/onReaderError/onProcessExit
public class CronJobBase {
    public init() {}
}

// ============================================================================
// CronRegisterJob — cron 注册任务
// 翻译自: cron.zig pub const CronRegisterJob = struct { ... }
// ============================================================================

/// CronRegisterJob — 注册一个 OS 级 cron 任务
/// 通过 crontab (Linux), launchd plist (macOS), 或 schtasks (Windows)
public class CronRegisterJob {
    /// JS Promise (用于异步返回)
    public var promise: JsValue = JsValue.jsUndefined()
    /// JSGlobalObject
    public var global: JsGlobalObject = JsGlobalObject()
    /// 调度表达式 (标准化数字形式)
    public var schedule: String = ""
    /// 任务标题
    public var title: String = ""
    /// 绝对路径
    public var absPath: String = ""
    /// Bun 可执行文件路径
    public var bunExe: String = ""
    /// 解析后的 cron 表达式
    public var parsedCron: CronExpression = CronExpression()
    /// 当前状态
    public var state: CronRegisterState = CronRegisterState.readingCrontab
    /// 错误消息
    public var errMsg: ?String = None
    /// 临时文件路径
    public var tmpPath: ?String = None
    /// 进程退出状态
    public var exitStatus: ?SpawnStatus = None
    /// 是否已调用 process exit
    public var hasCalledProcessExit: Bool = false
    /// 剩余 fd 数量
    public var remainingFds: Int64 = 0

    public init() {}

    // ========================================================================
    // JS 入口点
    // 翻译自: CronRegisterJob.cronRegister
    // ========================================================================

    /// cronRegister — Bun.cron(path, schedule, title) 的 JS 入口
    /// 翻译自: pub fn cronRegister(globalObject, callframe) bun.JSError!jsc.JSValue
    public static func cronRegister(globalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(3)

        // 进程内回调 cron: Bun.cron(schedule, handler)
        if (args.size > 1 && args[1].isCallable()) {
            return CronJob.register(globalObject: globalObject, scheduleArg: args[0], callbackArg: args[1])
        }

        if (args.size < 3) {
            return globalObject.throwInvalidArgumentsValue("Bun.cron() expects 3 arguments for OS-level registration")
        }

        if (!args[0].isString()) {
            return globalObject.throwInvalidArgumentsValue("Bun.cron() expects a string path as the first argument")
        }
        if (!args[1].isString()) {
            return globalObject.throwInvalidArgumentsValue("Bun.cron() expects a string schedule as the second argument")
        }
        if (!args[2].isString()) {
            return globalObject.throwInvalidArgumentsValue("Bun.cron() expects a string title as the third argument")
        }

        let pathStr = args[0].toString()
        let scheduleStr = args[1].toString()
        let titleStr = args[2].toString()

        // 验证标题: 仅 [a-zA-Z0-9_-]
        if (!validateTitle(title: titleStr)) {
            return globalObject.throwInvalidArgumentsValue("Cron title must contain only alphanumeric characters, hyphens, and underscores")
        }

        // 解析并标准化 cron 调度为数字形式
        let parsed = CronExpression.parse(input: scheduleStr)
        if (parsed.isNone()) {
            return globalObject.throwInvalidArgumentsValue("Invalid cron expression")
        }
        let parsedExpr = parsed.getOrThrow()
        let normalizedSchedule = parsedExpr.formatNumeric()

        // 验证路径不包含单引号或百分号
        for (c in absPathFromArgs(pathStr: pathStr)) {
            if (c == UInt8(39)) {
                return globalObject.throwInvalidArgumentsValue("Path must not contain single quotes")
            }
            if (c == UInt8(37)) {
                return globalObject.throwInvalidArgumentsValue("Path must not contain percent signs (cron interprets % as newline)")
            }
        }

        let job = CronRegisterJob()
        job.global = globalObject
        job.schedule = normalizedSchedule
        job.title = titleStr
        job.absPath = absPathFromArgs(pathStr: pathStr)
        job.bunExe = selfExePath()
        job.parsedCron = parsedExpr

        // 启动平台相关注册流程
        // Linux: startLinux(), macOS: startMac(), Windows: startWindows()
        job.startLinux()

        return job.promise
    }

    // ========================================================================
    // Linux — crontab 注册
    // 翻译自: CronRegisterJob.startLinux / processCrontabAndInstall
    // ========================================================================

    /// 启动 Linux crontab 注册流程
    func startLinux(): Unit {
        state = CronRegisterState.readingCrontab
        // TODO(bao-runtime-api): 实现完整的 crontab 读取 + 安装流程
        //   1. 查找 crontab 二进制
        //   2. 运行 crontab -l 读取当前 crontab
        //   3. 过滤同名任务，添加新条目
        //   4. 写入临时文件，运行 crontab tmpfile 安装
        finish()
    }

    /// 处理 crontab 内容并安装新条目
    /// 翻译自: CronRegisterJob.processCrontabAndInstall
    func processCrontabAndInstall(existingContent!: String): Unit {
        // 构建新的 crontab 内容
        var result = filterCrontab(content: existingContent, title: title)
        let newEntry = "# bun-cron: ${title}\n${schedule} '${bunExe}' run --cron-title=${title} --cron-period='${schedule}' '${absPath}'\n"
        result = result + newEntry

        // TODO(bao-runtime-api): 写入临时文件并安装
        state = CronRegisterState.installingCrontab
        finish()
    }

    // ========================================================================
    // macOS — launchd plist 注册
    // 翻译自: CronRegisterJob.startMac
    // ========================================================================

    /// 启动 macOS launchd plist 注册流程
    func startMac(): Unit {
        state = CronRegisterState.writingPlist
        // TODO(bao-runtime-api): 实现完整的 launchd plist 注册流程
        //   1. 将 cron 表达式转换为 CalendarInterval XML
        //   2. 写入 ~/Library/LaunchAgents/bun.cron.{title}.plist
        //   3. launchctl bootout + bootstrap
        finish()
    }

    // ========================================================================
    // Windows — schtasks 注册
    // 翻译自: CronRegisterJob.startWindows
    // ========================================================================

    /// 启动 Windows schtasks 注册流程
    func startWindows(): Unit {
        state = CronRegisterState.installingCrontab
        // TODO(bao-runtime-api): 实现完整的 schtasks 注册流程
        //   1. 构建 Task Scheduler XML
        //   2. 写入临时 XML 文件
        //   3. 运行 schtasks /create /xml <file> /tn <name>
        finish()
    }

    // ========================================================================
    // 完成和清理
    // ========================================================================

    /// 完成注册流程 — resolve/reject Promise
    /// 翻译自: CronRegisterJob.finish
    func finish(): Unit {
        if (errMsg.isSome()) {
            state = CronRegisterState.failed
        } else {
            state = CronRegisterState.done
        }
        // TODO(bao-runtime-api): resolve/reject promise
    }

    /// 设置错误消息
    /// 翻译自: CronRegisterJob.setErr
    func setErr(msg!: String): Unit {
        if (errMsg.isNone()) {
            errMsg = msg
        }
    }
}

// ============================================================================
// CronRemoveJob — cron 移除任务
// 翻译自: cron.zig pub const CronRemoveJob = struct { ... }
// ============================================================================

/// CronRemoveJob — 移除一个 OS 级 cron 任务
public class CronRemoveJob {
    /// JS Promise
    public var promise: JsValue = JsValue.jsUndefined()
    /// JSGlobalObject
    public var global: JsGlobalObject = JsGlobalObject()
    /// 任务标题
    public var title: String = ""
    /// 当前状态
    public var state: CronRemoveState = CronRemoveState.readingCrontab
    /// 错误消息
    public var errMsg: ?String = None
    /// 临时文件路径
    public var tmpPath: ?String = None
    /// 进程退出状态
    public var exitStatus: ?SpawnStatus = None
    /// 是否已调用 process exit
    public var hasCalledProcessExit: Bool = false
    /// 剩余 fd 数量
    public var remainingFds: Int64 = 0

    public init() {}

    /// cronRemove — Bun.cron.remove(title) 的 JS 入口
    /// 翻译自: pub fn cronRemove(globalObject, callframe) bun.JSError!jsc.JSValue
    public static func cronRemove(globalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)
        if (args.size < 1 || !args[0].isString()) {
            return globalObject.throwInvalidArgumentsValue("Bun.cron.remove() expects a string title")
        }

        let titleStr = args[0].toString()

        if (!validateTitle(title: titleStr)) {
            return globalObject.throwInvalidArgumentsValue("Cron title must contain only alphanumeric characters, hyphens, and underscores")
        }

        let job = CronRemoveJob()
        job.global = globalObject
        job.title = titleStr

        // 启动平台相关移除流程
        job.startLinux()

        return job.promise
    }

    /// 启动 Linux crontab 移除流程
    func startLinux(): Unit {
        state = CronRemoveState.readingCrontab
        // TODO(bao-runtime-api): 实现完整的 crontab 读取 + 移除流程
        finish()
    }

    /// 启动 macOS launchd 移除流程
    func startMac(): Unit {
        state = CronRemoveState.bootingOut
        // TODO(bao-runtime-api): 实现 launchctl bootout + 删除 plist
        finish()
    }

    /// 启动 Windows schtasks 移除流程
    func startWindows(): Unit {
        state = CronRemoveState.installingCrontab
        // TODO(bao-runtime-api): 实现 schtasks /delete
        finish()
    }

    /// 完成移除流程
    func finish(): Unit {
        if (errMsg.isSome()) {
            state = CronRemoveState.failed
        } else {
            state = CronRemoveState.done
        }
    }

    /// 设置错误消息
    func setErr(msg!: String): Unit {
        if (errMsg.isNone()) {
            errMsg = msg
        }
    }
}

// ============================================================================
// CronJob — 进程内回调式 cron (Bun.cron(expr, cb))
// 翻译自: cron.zig pub const CronJob = struct { ... }
// ============================================================================

/// CronJob — 进程内定时 cron 任务
/// 通过事件循环定时器触发 JS 回调
public class CronJob {
    /// JSGlobalObject
    public var global: JsGlobalObject = JsGlobalObject()
    /// 解析后的 cron 表达式
    public var parsed: CronExpression = CronExpression()
    /// 是否已停止
    public var stopped: Bool = false
    /// 最后计算的下次触发时间 (ms epoch)
    public var lastNextMs: Float64 = 0.0
    /// JS this 值
    public var thisValue: JsValue = JsValue.jsUndefined()
    /// JS 回调函数
    public var callback: JsValue = JsValue.jsUndefined()
    /// 是否有待处理的引用
    public var pendingRef: Bool = false
    /// 是否正在执行回调
    public var inFire: Bool = false
    /// 引用计数
    public var refCount: Int64 = 1

    public init() {}

    // ========================================================================
    // JS 绑定方法
    // 翻译自: CronJob 的 JS 绑定方法
    // ========================================================================

    /// register — 注册进程内 cron 任务
    /// 翻译自: CronJob.register(globalObject, schedule_arg, callback_arg)
    public static func register(globalObject!: JsGlobalObject, scheduleArg!: JsValue, callbackArg!: JsValue): JsValue {
        if (!scheduleArg.isString()) {
            return globalObject.throwInvalidArgumentsValue("Bun.cron() expects a string cron expression")
        }

        let scheduleStr = scheduleArg.toString()
        let parsed = CronExpression.parse(input: scheduleStr)
        if (parsed.isNone()) {
            return globalObject.throwInvalidArgumentsValue("Invalid cron expression")
        }

        let job = CronJob()
        job.global = globalObject
        job.parsed = parsed.getOrThrow()
        job.callback = callbackArg

        // 计算首次触发时间
        let nowMs = currentMillis()
        let nextMs = job.parsed.next(globalObject: globalObject, fromMs: nowMs)
        if (nextMs.isNone()) {
            return globalObject.throwInvalidArgumentsValue("Cron expression has no future occurrences")
        }
        job.lastNextMs = nextMs.getOrThrow()

        // 将 job 注册到 VM 的 cron_jobs 列表
        // TODO(bao-runtime-api): 实现事件循环定时器注册

        // 返回 JS 包装的 CronJob 对象
        return JsValue.jsUndefined() // createCronJobWrapper not yet available
    }

    /// stop — 停止 cron 任务
    /// 翻译自: CronJob.stop
    public func stop(globalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        selfStop()
        return callframe.thisValue
    }

    /// doRef — 引用 cron 任务 (保持事件循环活跃)
    /// 翻译自: CronJob.doRef
    public func doRef(globalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        if (!stopped) {
            // TODO(bao-runtime-api): poll_ref.ref(vm)
        }
        return callframe.thisValue
    }

    /// doUnref — 取消引用 cron 任务
    /// 翻译自: CronJob.doUnref
    public func doUnref(globalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // TODO(bao-runtime-api): poll_ref.unref(vm)
        return callframe.thisValue
    }

    /// finalize — GC 回收
    /// 翻译自: CronJob.finalize
    public func finalize(): Unit {
        // 释放 JS 引用
    }

    // ========================================================================
    // 内部方法
    // ========================================================================

    /// selfStop — 内部停止
    /// 翻译自: CronJob.selfStop
    func selfStop(): Unit {
        stopped = true
        // TODO(bao-runtime-api): 从 VM cron_jobs 列表移除
    }

    /// computeNextTimespec — 计算下一次触发时间
    /// 翻译自: CronJob.computeNextTimespec
    func computeNextTimespec(): ?Float64 {
        let nowMs = currentMillis()
        let fromMs = if (nowMs > lastNextMs) { nowMs } else { lastNextMs }
        let nextMs = parsed.next(globalObject: global, fromMs: fromMs)
        if (nextMs.isSome()) {
            lastNextMs = nextMs.getOrThrow()
        }
        nextMs
    }

    /// scheduleNext — 调度下一次触发
    /// 翻译自: CronJob.scheduleNext
    func scheduleNext(): Unit {
        if (stopped) { return }
        let nextTime = computeNextTimespec()
        if (nextTime.isNone()) {
            selfStop()
            return
        }
        // TODO(bao-runtime-api): 更新事件循环定时器
    }

    /// onTimerFire — 定时器触发回调
    /// 翻译自: CronJob.onTimerFire
    func onTimerFire(): Unit {
        if (stopped) { return }

        // 调用 JS 回调
        if (callback.isUndefined() || !callback.isCallable()) {
            selfStop()
            return
        }

        inFire = true
        // TODO(bao-runtime-api): 调用 callback.call() 并处理 Promise 结果
        inFire = false

        scheduleNext()
    }
}

// ============================================================================
// getCronObject — 构建 Bun.cron 函数对象
// 翻译自: cron.zig pub fn getCronObject
// ============================================================================

/// getCronObject — 创建 Bun.cron 函数及其子方法
/// 翻译自: pub fn getCronObject(globalThis, _) jsc.JSValue
public func getCronObject(globalThis!: JsGlobalObject, obj!: JsValue): JsValue {
    // 创建 cron 函数对象
    // Bun.cron(path, schedule, title) 或 Bun.cron(schedule, handler)
    // Bun.cron.remove(title)
    // Bun.cron.parse(expr, from?)
    // TODO(bao-runtime-api): 创建 JS 函数对象并挂载 remove/parse 子方法
    JsValue.jsUndefined()
}

/// cronParse — Bun.cron.parse(expr, from?) 的实现
/// 翻译自: cron.zig pub fn cronParse(globalObject, callframe)
public func cronParse(globalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    let args = callframe.argumentsAsArray(2)

    if (args.size < 1 || !args[0].isString()) {
        return globalObject.throwInvalidArgumentsValue("Bun.cron.parse() expects a string cron expression as the first argument")
    }

    let exprStr = args[0].toString()
    let parsed = CronExpression.parse(input: exprStr)
    if (parsed.isNone()) {
        return globalObject.throwInvalidArgumentsValue("Invalid cron expression")
    }

    let parsedExpr = parsed.getOrThrow()

    let fromMs: Float64 = if (args.size > 1 && !args[1].isUndefined() && !args[1].isNull()) {
        if (args[1].isNumber()) {
            args[1].toNumber()
        } else {
            currentMillis()
        }
    } else {
        currentMillis()
    }

    let nextMs = parsedExpr.next(globalObject: globalObject, fromMs: fromMs)
    if (nextMs.isNone()) {
        return JsValue.null()
    }

    // 返回 Date 对象
    return JsValue.jsNumber(nextMs.getOrThrow())
}

// ============================================================================
// 共享辅助函数
// 翻译自: cron.zig 共享辅助函数
// ============================================================================

/// 验证标题: 仅 [a-zA-Z0-9_-]，非空
/// 翻译自: fn validateTitle(title) bool
public func validateTitle(title!: String): Bool {
    if (title.size == 0) { return false }
    for (c in title) {
        if (!((c >= UInt8(97) && c <= UInt8(122)) || (c >= UInt8(65) && c <= UInt8(90)) ||
              (c >= UInt8(48) && c <= UInt8(57)) || c == UInt8(45) || c == UInt8(95))) {
            return false
        }
    }
    true
}

/// 过滤 crontab 内容，移除匹配标题标记的条目
/// 翻译自: fn filterCrontab(content, title, result)
public func filterCrontab(content!: String, title!: String): String {
    let marker = "# bun-cron: ${title}"
    let lines = content.split("\n")
    var result = ""
    var skipNext = false
    for (line in lines) {
        if (skipNext) {
            skipNext = false
            continue
        }
        if (line.trimAscii() == marker) {
            skipNext = true
            continue
        }
        if (line.size > 0) {
            result = result + line + "\n"
        }
    }
    result
}

/// 获取 Bun 可执行文件路径
/// 翻译自: bun.selfExePath()
func selfExePath(): String {
    // TODO(bao-runtime-api): 获取当前可执行文件路径
    "bao"
}

/// 从 JS 参数解析绝对路径
func absPathFromArgs(pathStr!: String): String {
    // TODO(bao-runtime-api): 解析相对路径为绝对路径
    pathStr
}

/// 获取当前毫秒时间戳
func currentMillis(): Float64 {
    // TODO(bao-runtime-api): 获取当前时间戳
    Float64(0)
}

/// 解析路径为绝对路径
/// 翻译自: cron.zig fn resolvePath
func resolveCronPath(globalObject!: JsGlobalObject, path!: String): ?String {
    // TODO(bao-runtime-api): 实现路径解析
    Some(path)
}

/// XML 转义字符串
/// 翻译自: cron.zig fn xmlEscape
func xmlEscape(input!: String): String {
    var needsEscape = false
    for (c in input) {
        if (c == UInt8(38) || c == UInt8(60) || c == UInt8(62) || c == UInt8(34) || c == UInt8(39)) {
            needsEscape = true
            break
        }
    }
    if (!needsEscape) { return input }

    var result = ""
    for (c in input) {
        if (c == UInt8(38)) { result = result + "&amp;" }
        else if (c == UInt8(60)) { result = result + "&lt;" }
        else if (c == UInt8(62)) { result = result + "&gt;" }
        else if (c == UInt8(34)) { result = result + "&quot;" }
        else if (c == UInt8(39)) { result = result + "&apos;" }
        else { result = result + String(Rune(UInt32(c))) }
    }
    result
}

/// 将 cron 调度转换为 macOS CalendarInterval XML
/// 翻译自: cron.zig fn cronToCalendarInterval
func cronToCalendarInterval(schedule!: String): ?String {
    // TODO(bao-runtime-api): 实现完整的 CalendarInterval XML 生成
    //   解析 5 字段 cron 表达式，生成 launchd StartCalendarInterval 字典
    Some("<dict></dict>")
}

/// 将 cron 调度转换为 Windows Task Scheduler XML
/// 翻译自: cron.zig fn cronToTaskXml
func cronToTaskXml(cron!: CronExpression, bunExe!: String, title!: String, schedule!: String, absPath!: String): ?String {
    // TODO(bao-runtime-api): 实现完整的 Task Scheduler XML 生成
    Some("<?xml version=\"1.0\"?><Task></Task>")
}

/// 查找 crontab 二进制
/// 翻译自: cron.zig fn findCrontab
func findCrontab(): ?String {
    // TODO(bao-runtime-api): 在 PATH 中查找 crontab
    Some("/usr/bin/crontab")
}

/// 创建临时文件路径
/// 翻译自: cron.zig fn makeTempPath
func makeTempPath(prefix!: String): ?String {
    // TODO(bao-runtime-api): 创建安全的临时文件路径
    Some("/tmp/${prefix}tmpXXX")
}

// ============================================================================
// SpawnStatus — 进程退出状态 (cron 模块使用)
// ============================================================================

/// SpawnStatus — cron 模块中的进程退出状态
public class SpawnStatus {
    public var exitCode: Int32 = 0
    public var signal: Int32 = 0
    public init() {}
    public init(exitCode!: Int32, signal!: Int32) {
        this.exitCode = exitCode
        this.signal = signal
    }
}

// ============================================================================
// OutputReader — 输出读取器桩
// ============================================================================

/// OutputReader — 进程输出读取器
public class OutputReader {
    public init() {}
}

// ============================================================================
// 状态枚举
// ============================================================================

/// CronRegisterJob 状态
/// 翻译自: CronRegisterJob.State
public enum CronRegisterState {
    | readingCrontab
    | installingCrontab
    | writingPlist
    | bootingOut
    | bootstrapping
    | done
    | failed
}

/// CronRemoveJob 状态
/// 翻译自: CronRemoveJob.State
public enum CronRemoveState {
    | readingCrontab
    | installingCrontab
    | bootingOut
    | done
    | failed
}
