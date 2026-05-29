// 严格翻译自: src/cli/multi_run.zig
package bao_cli

import bao_core.{Output, Global}
import bao_collections.*
import bao_event_loop.*
import bao_sys.*
import bao_io.*

/// 查找 shell 可执行文件
/// 严格翻译自: multi_run.zig 中 findShell
/// 在 PATH 中搜索 sh/bash/zsh, 回退到硬编码路径
func findShell(pathEnv: String, cwd: String): ?String {
    // 在 PATH 中查找
    let pathDirs = pathEnv.split(":")
    let shellNames = ["sh", "bash", "zsh"]
    for (dir in pathDirs) {
        for (name in shellNames) {
            let candidate = "${dir}/${name}"
            if (BaoFile.exists(candidate)) {
                return Some(candidate)
            }
        }
    }
    // 尝试常见 shell 路径
    let shells = ["/bin/bash", "/bin/sh", "/usr/bin/bash", "/usr/bin/sh"]
    for (shell in shells) {
        if (BaoFile.exists(shell)) {
            return Some(shell)
        }
    }
    return None
}

// ============================================================================
// MultiRun — 并行/顺序脚本执行
// 严格翻译自: src/cli/multi_run.zig
//
// 支持 --parallel 和 --sequential 模式运行多个脚本
// 包含: ScriptConfig, PipeReader, ProcessHandle, State, AbortHandler
// ============================================================================

/// 多脚本配置
/// 对应 Bun: multi_run ScriptConfig
public class MultiScriptConfig {
    public var label: String
    public var command: String
    public var cwd: String
    public var PATH: String

    public init() {
        label = ""
        command = ""
        cwd = ""
        PATH = ""
    }
}

/// ANSI 颜色序列
private let ESC = "\u{001b}"
private let COLORS: Array<String> = [
    ESC + "[36m", // cyan
    ESC + "[33m", // yellow
    ESC + "[35m", // magenta
    ESC + "[32m", // green
    ESC + "[34m", // blue
    ESC + "[31m"  // red
]
private let RESET = ESC + "[0m"

/// 管道读取器
/// 对应 Bun: multi_run PipeReader
public class MultiRunPipeReader {
    public var reader: BufferedReader
    public var handle: ?MultiRunProcessHandle
    public var isStderr: Bool
    public var lineBuffer: MrStringBuilder

    public init(isStderr: Bool) {
        reader = BufferedReader()
        handle = None
        this.isStderr = isStderr
        lineBuffer = MrStringBuilder()
    }

    /// 读取回调
    public func onReadChunk(chunk: String): Bool {
        handle.getOrThrow().state.readChunk(this, chunk)
        return true
    }

    /// 完成回调
    public func onReaderDone(): Unit {}

    /// 错误回调
    public func onReaderError(err: String): Unit {}
}

/// 进程 Handle
/// 对应 Bun: multi_run ProcessHandle
public class MultiRunProcessHandle {
    public var config: MultiScriptConfig
    public var state: MultiRunState
    public var colorIdx: Int64

    public var stdoutReader: MultiRunPipeReader
    public var stderrReader: MultiRunPipeReader

    public var process: ?MrProcess
    public var status: MrProcessStatus
    public var options: MrSpawnOptions

    public var startTime: ?MrTimeInstant
    public var endTime: ?MrTimeInstant

    public var remainingDependencies: Int64
    /// 同一脚本组内的依赖 (pre->main->post 链)
    public var groupDependents: ArrayList<MultiRunProcessHandle>
    /// 跨顺序组的依赖 (组 N -> 组 N+1)
    public var nextDependents: ArrayList<MultiRunProcessHandle>

    public init() {
        config = MultiScriptConfig()
        state = MultiRunState()
        colorIdx = 0
        stdoutReader = MultiRunPipeReader(false)
        stderrReader = MultiRunPipeReader(true)
        process = None
        status = MrProcessStatus.Running
        options = MrSpawnOptions()
        startTime = None
        endTime = None
        remainingDependencies = 0
        groupDependents = ArrayList<MultiRunProcessHandle>()
        nextDependents = ArrayList<MultiRunProcessHandle>()
    }

    /// 启动进程
    /// 严格翻译自: multi_run.zig ProcessHandle.start()
    public func start(): Unit {
        state.remainingScripts += 1

        let argv = [state.shellBin, "-c", config.command]
        startTime = MrTimeInstant.now()

        let originalPath = match (state.env.get("PATH")) {
            case Some(v) => v
            case None => ""
        }
        state.env.put("PATH", config.PATH)
        let envp = state.env.toEnvArray()
        state.env.put("PATH", originalPath)

        // spawn 子进程
        let spawnResult = MrProcess.spawn(state.shellBin, argv, envp, config.cwd)
        match (spawnResult) {
            case Some(proc) =>
                process = Some(proc)
                status = MrProcessStatus.Running
            case None =>
                process = None
                status = MrProcessStatus.Exited(127)
                // 启动失败, 立即触发退出回调
                endTime = MrTimeInstant.now()
                state.processExit(this)
                return
        }
        stdoutReader.handle = this
        stderrReader.handle = this
    }

    /// 进程退出回调
    public func onProcessExit(proc: MrProcess, status: MrProcessStatus): Unit {
        this.status = status
        endTime = MrTimeInstant.now()
        state.processExit(this)
    }
}

/// 多运行状态
/// 对应 Bun: multi_run State
public class MultiRunState {
    public var handles: ArrayList<MultiRunProcessHandle>
    public var eventLoop: MiniEventLoop
    public var remainingScripts: Int64
    public var maxLabelLen: Int64
    public var shellBin: String
    public var aborted: Bool
    public var noExitOnError: Bool
    public var env: DotEnvLoader
    public var useColors: Bool

    public init() {
        handles = ArrayList<MultiRunProcessHandle>()
        eventLoop = MiniEventLoop()
        remainingScripts = 0
        maxLabelLen = 0
        shellBin = ""
        aborted = false
        noExitOnError = false
        env = DotEnvLoader()
        useColors = false
    }

    /// 是否所有工作完成
    public func isDone(): Bool {
        return remainingScripts == 0
    }

    /// 读取数据块
    public func readChunk(pipe: MultiRunPipeReader, chunk: String): Unit {
        pipe.lineBuffer.append(chunk)

        // 路由到正确的父流
        let writer = if (pipe.isStderr) { MrOutputWriter() } else { MrOutputWriter() }
        var buf = pipe.lineBuffer.toString()
        while (true) {
            let newlinePosOpt = buf.indexOf('\n')
            if (newlinePosOpt.isNone()) {
                break
            }
            let newlinePos = newlinePosOpt.getOrThrow()
            let line = buf.substring(0, newlinePos + 1)
            writeLineWithPrefix(pipe.handle.getOrThrow(), line, writer)
            buf = buf.substring(newlinePos + 1)
        }
        pipe.lineBuffer.clear()
        pipe.lineBuffer.append(buf)
    }

    /// 写入带前缀的行
    public func writeLineWithPrefix(handle: MultiRunProcessHandle, line: String, writer: MrOutputWriter): Unit {
        writePrefix(handle, writer)
        writer.writeAll(line)
    }

    /// 写入前缀 (标签 + 颜色)
    public func writePrefix(handle: MultiRunProcessHandle, writer: MrOutputWriter): Unit {
        if (useColors) {
            writer.writeAll(COLORS[handle.colorIdx % COLORS.size])
        }

        writer.writeAll(handle.config.label)
        let padding = maxLabelLen - Int64(handle.config.label.size)
        var _padI: Int64 = 0
        while (_padI < padding) {
            writer.writeByte(UInt8(0x20))
            _padI += 1
        }

        if (useColors) {
            writer.writeAll(RESET)
        }

        writer.writeAll(" | ")
    }

    /// 刷新管道缓冲区
    public func flushPipeBuffer(handle: MultiRunProcessHandle, pipe: MultiRunPipeReader): Unit {
        if (pipe.lineBuffer.length > 0) {
            let line = pipe.lineBuffer.toString()
            let needsNewline = line.size > 0 && line[line.size - 1] != UInt8(0x0a)
            let writer = if (pipe.isStderr) { MrOutputWriter() } else { MrOutputWriter() }
            writeLineWithPrefix(handle, line, writer)
            if (needsNewline) {
                writer.writeAll("\n")
            }
            pipe.lineBuffer.clear()
        }
    }

    /// 进程退出处理
    public func processExit(handle: MultiRunProcessHandle): Unit {
        remainingScripts -= 1

        // 刷新剩余缓冲区
        flushPipeBuffer(handle, handle.stdoutReader)
        flushPipeBuffer(handle, handle.stderrReader)

        // 打印退出状态到 stderr
        let writer = MrOutputWriter()
        writePrefix(handle, writer)

        match (handle.status) {
            case MrProcessStatus.Exited(code) =>
                if (code != 0) {
                    writer.println("Exited with code ${code}")
                } else {
                    if (handle.startTime.isSome() && handle.endTime.isSome()) {
                        let duration = handle.endTime.getOrThrow().since(handle.startTime.getOrThrow())
                        let ms = Float64(duration) / 1_000_000.0
                        if (ms > 1000.0) {
                            writer.println("Done in ${ms / 1000.0} s")
                        } else {
                            writer.println("Done in ${ms} ms")
                        }
                    } else {
                        writer.println("Done")
                    }
                }
            case MrProcessStatus.Signaled(sig) =>
                writer.println("Signaled: ${sig}")
            case _ =>
                writer.println("Error")
        }

        // 检查是否应中止
        let failed = match (handle.status) {
            case MrProcessStatus.Exited(code) => code != 0
            case MrProcessStatus.Signaled(_) => true
            case _ => true
        }

        if (failed && !noExitOnError) {
            abort()
            return
        }

        if (failed) {
            // pre->main->post 链断裂: 跳过组依赖
            skipDependents(handle.groupDependents)
            // 但级联到下一组
            if (!aborted) {
                startDependents(handle.nextDependents)
            }
            return
        }

        // 成功: 级联到所有依赖
        if (!aborted) {
            startDependents(handle.groupDependents)
            startDependents(handle.nextDependents)
        }
    }

    /// 启动依赖
    public func startDependents(dependents: ArrayList<MultiRunProcessHandle>): Unit {
        for (dependent in dependents) {
            dependent.remainingDependencies -= 1
            if (dependent.remainingDependencies == 0) {
                dependent.start()
            }
        }
    }

    /// 跳过组依赖
    public func skipDependents(dependents: ArrayList<MultiRunProcessHandle>): Unit {
        for (dependent in dependents) {
            dependent.remainingDependencies -= 1
            if (dependent.remainingDependencies == 0) {
                skipDependents(dependent.groupDependents)
                if (!aborted) {
                    startDependents(dependent.nextDependents)
                }
            }
        }
    }

    /// 中止所有进程
    public func abort(): Unit {
        aborted = true
        for (handle in handles) {
            if (handle.process.isSome() && mrProcessStatusEquals(handle.status, MrProcessStatus.Running)) {
                handle.process.getOrThrow().kill()
            }
        }
    }

    /// 确定最终退出码
    public func finalize(): Int64 {
        for (handle in handles) {
            if (handle.process.isSome()) {
                match (handle.status) {
                    case MrProcessStatus.Exited(code) =>
                        if (code != 0) { return code }
                    case MrProcessStatus.Signaled(_) => return 1
                    case _ => return 1
                }
            }
        }
        return 0
    }
}

/// 分组信息
public class GroupInfo {
    public var start: Int64
    public var count: Int64

    public init(start: Int64, count: Int64) {
        this.start = start
        this.count = count
    }
}

/// 简单通配符匹配
/// 对应 Bun: matchesGlob()
private func matchesGlob(pattern: String, name: String): Bool {
    var pi = 0
    var ni = 0
    var starPi = 0
    var starNi = 0
    var haveStar = false

    while (ni < name.size || pi < pattern.size) {
        if (pi < pattern.size && pattern[pi] == UInt8(0x2a)) {
            haveStar = true
            starPi = pi
            starNi = ni
            pi += 1
        } else if (pi < pattern.size && ni < name.size && pattern[pi] == name[ni]) {
            pi += 1
            ni += 1
        } else if (haveStar) {
            pi = starPi + 1
            starNi += 1
            ni = starNi
            if (ni > name.size) {
                return false
            }
        } else {
            return false
        }
    }
    return true
}

/// 添加脚本配置 (含 pre/post 处理)
/// 对应 Bun: addScriptConfigs()
private func addScriptConfigs(
    configs: ArrayList<MultiScriptConfig>,
    groupInfos: ArrayList<GroupInfo>,
    rawName: String,
    scriptsMap: ?HashMap<String, String>,
    allocator: Unit,
    cwd: String,
    path: String,
    labelPrefix: ?String
): Unit {
    let groupStart = configs.size

    let label = if (labelPrefix.isSome()) {
        "${labelPrefix.getOrThrow()}:${rawName}"
    } else {
        rawName
    }

    let scriptContent: ?String = if (scriptsMap.isSome()) { scriptsMap.getOrThrow().get(rawName) } else { None }

    if (scriptContent.isSome()) {
        // package.json 脚本 - 检查 pre/post
        let preName = "pre${rawName}"
        let postName = "post${rawName}"

        let preContent: ?String = if (scriptsMap.isSome()) { scriptsMap.getOrThrow().get(preName) } else { None }
        let postContent: ?String = if (scriptsMap.isSome()) { scriptsMap.getOrThrow().get(postName) } else { None }

        if (preContent.isSome()) {
            let config = MultiScriptConfig()
            config.label = label
            config.command = preContent.getOrThrow()
            config.cwd = cwd
            config.PATH = path
            configs.append(config)
        }

        // 主脚本
        let mainConfig = MultiScriptConfig()
        mainConfig.label = label
        mainConfig.command = scriptContent.getOrThrow()
        mainConfig.cwd = cwd
        mainConfig.PATH = path
        configs.append(mainConfig)

        if (postContent.isSome()) {
            let config = MultiScriptConfig()
            config.label = label
            config.command = postContent.getOrThrow()
            config.cwd = cwd
            config.PATH = path
            configs.append(config)
        }
    } else {
        // 非 package.json 脚本 - 作为原始命令运行
        let command = rawName
        let config = MultiScriptConfig()
        config.label = label
        config.command = command
        config.cwd = cwd
        config.PATH = path
        configs.append(config)
    }

    groupInfos.append(GroupInfo(groupStart, configs.size - groupStart))
}

/// 多运行入口
/// 对应 Bun: multi_run.run()
public func multiRun(ctx: CommandContext): Unit {
    // 验证标志
    if (ctx.parallel && ctx.sequential) {
        Output.prettyErrorln("error: --parallel and --sequential cannot be used together")
        Global.exit(1)
    }

    // 收集脚本名称
    let scriptNames = ArrayList<String>()
    var positionals = ArrayList<String>()
    let rawPositionals = ctx.positionals
    var startIdx = 0
    if (rawPositionals.size > 0 && (rawPositionals[0] == "run" || rawPositionals[0] == "r")) {
        startIdx = 1
    }
    for (i in startIdx..rawPositionals.size) {
        positionals.append(rawPositionals[i])
    }
    for (pos in positionals) {
        if (pos.size > 0) {
            scriptNames.append(pos)
        }
    }
    for (pt in ctx.passthrough) {
        if (pt.size > 0) {
            scriptNames.append(pt)
        }
    }

    if (scriptNames.size == 0) {
        Output.prettyErrorln("error: --parallel/--sequential requires at least one script name")
        Global.exit(1)
    }

    // 配置环境
    let cwd = Sys.getcwd()
    let eventLoop = MiniEventLoop.initGlobal(None, Some(cwd))
    let pathEnv = Sys.getEnv("PATH") ?? ""
    let shellBinOpt = findShell(pathEnv, cwd)
    if (shellBinOpt.isNone()) {
        Output.prettyErrorln("error: Missing shell")
        Global.exit(1)
    }
    let shellBin = shellBinOpt.getOrThrow()

    // 构建配置
    let configs = ArrayList<MultiScriptConfig>()
    let groupInfos = ArrayList<GroupInfo>()

    // 加载 package.json scripts 映射
    let rootPath = cwd
    let scriptsMap: ?HashMap<String, String> = loadPackageScripts(rootPath)

    for (rawName in scriptNames) {
        // 检查是否为 glob 模式
        if (rawName.contains('*')) {
            if (scriptsMap.isSome()) {
                let matches = ArrayList<String>()
                for (key in scriptsMap.getOrThrow().keys()) {
                    if (matchesGlob(rawName, key)) {
                        matches.append(key)
                    }
                }
                // Simple bubble sort for ArrayList<String>
                var sorted = true
                for (si in 0..matches.size) {
                    for (sj in si+1..matches.size) {
                        if (matches[si] > matches[sj]) {
                            let tmp = matches[si]
                            matches[si] = matches[sj]
                            matches[sj] = tmp
                            sorted = false
                        }
                    }
                }
                if (matches.size == 0) {
                    Output.prettyErrorln("error: No scripts match pattern \"${rawName}\"")
                    Global.exit(1)
                }
                for (matchedName in matches) {
                    addScriptConfigs(configs, groupInfos, matchedName, scriptsMap, ctx.allocator, cwd, rootPath, None)
                }
            } else {
                Output.prettyErrorln("error: Cannot use glob pattern \"${rawName}\" without package.json scripts")
                Global.exit(1)
            }
        } else {
            addScriptConfigs(configs, groupInfos, rawName, scriptsMap, ctx.allocator, cwd, rootPath, None)
        }
    }

    if (configs.size == 0) {
        Output.prettyErrorln("error: No scripts to run")
        Global.exit(1)
    }

    // 计算最大标签宽度
    var maxLabelLen: Int64 = 0
    for (config in configs) {
        if (config.label.size > maxLabelLen) {
            maxLabelLen = config.label.size
        }
    }

    let useColors = Output.enableAnsiColorsStderr

    let state = MultiRunState()
    state.handles = ArrayList<MultiRunProcessHandle>()
    state.eventLoop = eventLoop
    state.maxLabelLen = maxLabelLen
    state.shellBin = shellBin
    state.noExitOnError = ctx.noExitOnError
    state.env = DotEnvLoader()
    state.useColors = useColors

    // 初始化 handles
    var i: Int64 = 0
    for (config in configs) {
        // 确定颜色索引
        var colorIdx: Int64 = 0
        var gi: Int64 = 0
        for (group in groupInfos) {
            if (i >= group.start && i < group.start + group.count) {
                colorIdx = gi
                break
            }
            gi += 1
        }

        let handle = MultiRunProcessHandle()
        handle.state = state
        handle.config = config
        handle.colorIdx = colorIdx
        handle.options = MrSpawnOptions()
        handle.options.stdin = MrStdioKind.Ignore
        handle.options.stdout = MrStdioKind.Buffer
        handle.options.stderr = MrStdioKind.Buffer
        handle.options.cwd = config.cwd
        handle.options.stream = true
        state.handles.append(handle)
        i += 1
    }

    // 设置 pre->main->post 链
    for (group in groupInfos) {
        if (group.count > 1) {
            var j = group.start
            while (j < group.start + group.count - 1) {
                state.handles[Int64(j)].groupDependents.append(state.handles[Int64(j + 1)])
                state.handles[Int64(j + 1)].remainingDependencies += 1
                j += 1
            }
        }
    }

    // 顺序模式: 链接组间依赖
    if (ctx.sequential) {
        var gi = 0
        while (gi < groupInfos.size - 1) {
            let currentGroup = groupInfos[gi]
            let nextGroup = groupInfos[gi + 1]
            let lastInCurrent = currentGroup.start + currentGroup.count - 1
            let firstInNext = nextGroup.start
            state.handles[Int64(lastInCurrent)].nextDependents.append(state.handles[Int64(firstInNext)])
            state.handles[Int64(firstInNext)].remainingDependencies += 1
            gi += 1
        }
    }

    // 启动无依赖的 handles
    for (handle in state.handles) {
        if (handle.remainingDependencies == 0) {
            handle.start()
        }
    }

    let multiAbortHandler = MultiRunAbortHandler()
    multiAbortHandler.install()

    while (!state.isDone()) {
        if (multiAbortHandler.shouldAbort && !state.aborted) {
            multiAbortHandler.uninstall()
            state.abort()
        }
        eventLoop.tickOnce(state)
    }

    let status = state.finalize()
    Global.exit(status)
}

/// 中止处理器
/// 对应 Bun: multi_run AbortHandler
public class MultiRunAbortHandler {
    public var shouldAbort: Bool = false

    public func install(): Unit {
        shouldAbort = false
        SignalHandler.install(SIGINT, { => shouldAbort = true })
    }

    public func uninstall(): Unit {
        SignalHandler.uninstall()
    }
}

/// 从 package.json 加载 scripts 映射
/// 严格翻译自: multi_run.zig 中读取 package.json scripts
private func loadPackageScripts(cwd: String): ?HashMap<String, String> {
    let pkgJsonPath = Path.join([cwd, "package.json"])
    let content = BaoFile.readAllText(pkgJsonPath)
    match (content) {
        case Ok(text) =>
            let parser = JsonParser()
            let json = parser.parse(text)
            match (json) {
                case Some(root) =>
                    let scriptsObj = JsonHelper.getField(root, "scripts")
                    match (scriptsObj) {
                        case Some(obj) =>
                            let map = HashMap<String, String>()
                            for (key in obj.keys()) {
                                match (obj.getString(key)) {
                                    case Some(v) => map.put(key, v)
                                    case None => ()
                                }
                            }
                            if (map.size > 0) {
                                return Some(map)
                            }
                        case None => ()
                    }
                case None => ()
            }
        case Err(_) => ()
    }
    return None
}

// ============================================================================
// 本地类型定义 — multi_run 所需的类型
// ============================================================================

/// 进程状态 (multi_run 本地使用)
public enum MrProcessStatus {
    | Running
    | Exited(Int64)
    | Signaled(Int64)
    | Error
}

/// MrProcessStatus 相等性比较
public func mrProcessStatusEquals(a: MrProcessStatus, b: MrProcessStatus): Bool {
    match (a) {
        case MrProcessStatus.Running => match (b) { case MrProcessStatus.Running => true case _ => false }
        case MrProcessStatus.Exited(codeA) => match (b) { case MrProcessStatus.Exited(codeB) => codeA == codeB case _ => false }
        case MrProcessStatus.Signaled(sigA) => match (b) { case MrProcessStatus.Signaled(sigB) => sigA == sigB case _ => false }
        case MrProcessStatus.Error => match (b) { case MrProcessStatus.Error => true case _ => false }
    }
}

/// Stdio 配置类型
public enum MrStdioKind {
    | Ignore
    | Buffer
    | Pipe
    | Inherit
}

/// 进程创建选项 (multi_run 本地使用)
public class MrSpawnOptions {
    public var stdin: MrStdioKind
    public var stdout: MrStdioKind
    public var stderr: MrStdioKind
    public var cwd: String
    public var stream: Bool

    public init() {
        stdin = MrStdioKind.Pipe
        stdout = MrStdioKind.Pipe
        stderr = MrStdioKind.Pipe
        cwd = ""
        stream = false
    }
}

/// 子进程 (multi_run 本地使用)
/// 严格翻译自: multi_run.zig 中 bun.spawn.Process 封装
public class MrProcess {
    public var pid: Int64
    public var status: MrProcessStatus

    public init(pid: Int64) {
        this.pid = pid
        this.status = MrProcessStatus.Running
    }

    /// 生成子进程
    /// 严格翻译自: multi_run.zig 中 spawnProcess
    public static func spawn(exe: String, args: Array<String>, env: Array<String>, cwd: String): ?MrProcess {
        let pid = Sys.spawnProcess(exe, args, env, cwd)
        if (pid > 0) {
            return Some(MrProcess(pid))
        }
        return None
    }

    /// 终止进程
    /// 严格翻译自: multi_run.zig 中 process.kill()
    public func kill(): Unit {
        if (pid > 0) {
            Sys.killProcess(pid, 15) // SIGTERM
        }
    }

    /// 检查进程是否仍在运行
    public func isAlive(): Bool {
        if (pid <= 0) { return false }
        let exitCode = Sys.waitpid(pid)
        if (exitCode.isSome()) {
            status = MrProcessStatus.Exited(exitCode.getOrThrow())
            return false
        }
        return true
    }
}

/// 时间戳 (multi_run 本地使用)
public class MrTimeInstant {
    private var nanos: Int64

    private init(nanos: Int64) {
        this.nanos = nanos
    }

    public static func now(): MrTimeInstant {
        // 使用系统单调时钟获取当前时间戳
        return MrTimeInstant(nanos: Sys.nanoTimestamp())
    }

    /// 返回与另一个时间点的纳秒差
    public func since(other: MrTimeInstant): Int64 {
        return nanos - other.nanos
    }
}

/// 字符串构建器 (multi_run 本地使用)
public class MrStringBuilder {
    private var parts: ArrayList<String>

    public init() {
        parts = ArrayList<String>()
    }

    public prop length: Int64 {
        get() {
            var total: Int64 = 0
            for (p in parts) {
                total += p.size
            }
            return total
        }
    }

    public func append(s: String): Unit {
        parts.append(s)
    }

    public func clear(): Unit {
        parts = ArrayList<String>()
    }

    public func toString(): String {
        var result = ""
        for (p in parts) {
            result = result + p
        }
        return result
    }
}

/// 输出写入器 (multi_run 本地使用)
/// 严格翻译自: multi_run.zig 中输出路由 - 写到 stderr
public class MrOutputWriter {
    public func writeAll(s: String): Unit {
        print(s)
    }

    public func writeByte(c: UInt8): Unit {
        print(String(Rune(UInt32(c))))
    }

    public func println(s: String): Unit {
        println(s)
    }
}
