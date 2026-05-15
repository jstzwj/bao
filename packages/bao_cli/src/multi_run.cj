// 严格翻译自: src/cli/multi_run.zig
package bao_cli

import bao_core.*

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
private let COLORS: Array<String> = [
    "\u001b[36m", // cyan
    "\u001b[33m", // yellow
    "\u001b[35m", // magenta
    "\u001b[32m", // green
    "\u001b[34m", // blue
    "\u001b[31m", // red
]
private let RESET = "\u001b[0m"

/// 管道读取器
/// 对应 Bun: multi_run PipeReader
public class MultiRunPipeReader {
    public var reader: BufferedReader
    public var handle: ?MultiRunProcessHandle
    public var isStderr: Bool
    public var lineBuffer: StringBuilder

    public init(isStderr: Bool) {
        reader = BufferedReader()
        handle = None
        this.isStderr = isStderr
        lineBuffer = StringBuilder()
    }

    /// 读取回调
    public func onReadChunk(chunk: String): Bool {
        handle!!.state.readChunk(this, chunk)
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

    public var process: ?Process
    public var status: ProcessStatus
    public var options: SpawnOptions

    public var startTime: ?TimeInstant
    public var endTime: ?TimeInstant

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
        status = ProcessStatus.running
        options = SpawnOptions()
        startTime = None
        endTime = None
        remainingDependencies = 0
        groupDependents = ArrayList<MultiRunProcessHandle>()
        nextDependents = ArrayList<MultiRunProcessHandle>()
    }

    /// 启动进程
    public func start(): Unit {
        state.remainingScripts += 1

        val argv = [state.shellBin, "-c", config.command]
        startTime = TimeInstant.now()

        val originalPath = state.env.map.get("PATH") ?: ""
        state.env.map.put("PATH", config.PATH)
        val envp = state.env.map.toNullDelimitedEnvMap()
        state.env.map.put("PATH", originalPath)

        process = Sys.spawnProcess(options, argv, envp)
        stdoutReader.handle = this
        stderrReader.handle = this
    }

    /// 进程退出回调
    public func onProcessExit(proc: Process, status: ProcessStatus): Unit {
        this.status = status
        endTime = TimeInstant.now()
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
        val writer = if (pipe.isStderr) Output.errorWriter() else Output.writer()

        // 处理完整行
        var buf = pipe.lineBuffer.toString()
        while (true) {
            val newlinePos = buf.indexOf('\n')
            if (newlinePos < 0) {
                break
            }
            val line = buf.substring(0, newlinePos + 1)
            writeLineWithPrefix(pipe.handle!!, line, writer)
            buf = buf.substring(newlinePos + 1)
        }
        pipe.lineBuffer.clear()
        pipe.lineBuffer.append(buf)
    }

    /// 写入带前缀的行
    public func writeLineWithPrefix(handle: MultiRunProcessHandle, line: String, writer: OutputWriter): Unit {
        writePrefix(handle, writer)
        writer.writeAll(line)
    }

    /// 写入前缀 (标签 + 颜色)
    public func writePrefix(handle: MultiRunProcessHandle, writer: OutputWriter): Unit {
        if (useColors) {
            writer.writeAll(COLORS[(handle.colorIdx % COLORS.length).toInt()])
        }

        writer.writeAll(handle.config.label)
        val padding = maxLabelLen - handle.config.label.length
        for (_ in 0..padding) {
            writer.writeByte(' ')
        }

        if (useColors) {
            writer.writeAll(RESET)
        }

        writer.writeAll(" | ")
    }

    /// 刷新管道缓冲区
    public func flushPipeBuffer(handle: MultiRunProcessHandle, pipe: MultiRunPipeReader): Unit {
        if (pipe.lineBuffer.length > 0) {
            val line = pipe.lineBuffer.toString()
            val needsNewline = line.length > 0 && line[line.length - 1] != '\n'
            val writer = if (pipe.isStderr) Output.errorWriter() else Output.writer()
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
        val writer = Output.errorWriter()
        writePrefix(handle, writer)

        when (handle.status) {
            case ProcessStatus.exited(code) => {
                if (code != 0) {
                    writer.println("Exited with code ${code}")
                } else {
                    if (handle.startTime != None && handle.endTime != None) {
                        val duration = handle.endTime!!.since(handle.startTime!!)
                        val ms = duration.toDouble() / 1_000_000.0
                        if (ms > 1000.0) {
                            writer.println("Done in ${ms / 1000.0} s")
                        } else {
                            writer.println("Done in ${ms} ms")
                        }
                    } else {
                        writer.println("Done")
                    }
                }
            }
            case ProcessStatus.signaled(sig) => {
                writer.println("Signaled: ${sig}")
            }
            else => {
                writer.println("Error")
            }
        }

        // 检查是否应中止
        val failed = when (handle.status) {
            case ProcessStatus.exited(code) => code != 0
            case ProcessStatus.signaled(_) => true
            else => true
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
            if (handle.process != None && handle.status == ProcessStatus.running) {
                handle.process!!.kill()
            }
        }
    }

    /// 确定最终退出码
    public func finalize(): Int64 {
        for (handle in handles) {
            if (handle.process != None) {
                when (handle.status) {
                    case ProcessStatus.exited(code) => {
                        if (code != 0) return code
                    }
                    case ProcessStatus.signaled(_) => return 1
                    else => return 1
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

    while (ni < name.length || pi < pattern.length) {
        if (pi < pattern.length && pattern[pi] == '*') {
            haveStar = true
            starPi = pi
            starNi = ni
            pi += 1
        } else if (pi < pattern.length && ni < name.length && pattern[pi] == name[ni]) {
            pi += 1
            ni += 1
        } else if (haveStar) {
            pi = starPi + 1
            starNi += 1
            ni = starNi
            if (ni > name.length) {
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
    allocator: Allocator,
    cwd: String,
    path: String,
    labelPrefix: ?String
): Unit {
    val groupStart = configs.size

    val label = if (labelPrefix != None) {
        "${labelPrefix!!}:${rawName}"
    } else {
        rawName
    }

    val scriptContent = if (scriptsMap != None) scriptsMap!!.get(rawName) else None

    if (scriptContent != None) {
        // package.json 脚本 - 检查 pre/post
        val preName = "pre${rawName}"
        val postName = "post${rawName}"

        val preContent = if (scriptsMap != None) scriptsMap!!.get(preName) else None
        val postContent = if (scriptsMap != None) scriptsMap!!.get(postName) else None

        if (preContent != None) {
            val config = MultiScriptConfig()
            config.label = label
            config.command = preContent!!
            config.cwd = cwd
            config.PATH = path
            configs.append(config)
        }

        // 主脚本
        val mainConfig = MultiScriptConfig()
        mainConfig.label = label
        mainConfig.command = scriptContent!!
        mainConfig.cwd = cwd
        mainConfig.PATH = path
        configs.append(mainConfig)

        if (postContent != None) {
            val config = MultiScriptConfig()
            config.label = label
            config.command = postContent!!
            config.cwd = cwd
            config.PATH = path
            configs.append(config)
        }
    } else {
        // 非 package.json 脚本 - 作为原始命令运行
        val command = rawName
        val config = MultiScriptConfig()
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
        Output.prettyErrorLn("error: --parallel and --sequential cannot be used together")
        Global.exit(1)
    }

    // 收集脚本名称
    val scriptNames = ArrayList<String>()
    var positionals = ctx.positionals
    if (positionals.size > 0 && (positionals[0] == "run" || positionals[0] == "r")) {
        positionals = positionals.subList(1, positionals.size)
    }
    for (pos in positionals) {
        if (pos.length > 0) {
            scriptNames.append(pos)
        }
    }
    for (pt in ctx.passthrough) {
        if (pt.length > 0) {
            scriptNames.append(pt)
        }
    }

    if (scriptNames.size == 0) {
        Output.prettyErrorLn("error: --parallel/--sequential requires at least one script name")
        Global.exit(1)
    }

    // 配置环境
    val fsInstance = FileSystem.init()
    val thisTranspiler = Transpiler()
    RunCommand.configureEnvForRun(ctx, thisTranspiler, None, true, false)
    val cwd = fsInstance.topLevelDir

    val eventLoop = MiniEventLoop.initGlobal(thisTranspiler.env, None)
    val shellBin = RunCommand.findShell(thisTranspiler.env.get("PATH") ?: "", cwd)
        ?: { Output.prettyErrorLn("error: Missing shell"); Global.exit(1) }()

    // 构建配置
    val configs = ArrayList<MultiScriptConfig>()
    val groupInfos = ArrayList<GroupInfo>()

    // 单包模式
    val rootPath = RunCommand.configurePathForRunWithPackageJsonDir(ctx, "", thisTranspiler, None, cwd, ctx.debug.runInBun)
    val scriptsMap = PackageJSON.readScripts(cwd)

    for (rawName in scriptNames) {
        // 检查是否为 glob 模式
        if (rawName.contains('*')) {
            if (scriptsMap != None) {
                val matches = ArrayList<String>()
                for (key in scriptsMap!!.keys()) {
                    if (matchesGlob(rawName, key)) {
                        matches.append(key)
                    }
                }
                matches.sort()
                if (matches.size == 0) {
                    Output.prettyErrorLn("error: No scripts match pattern \"${rawName}\"")
                    Global.exit(1)
                }
                for (matchedName in matches) {
                    addScriptConfigs(configs, groupInfos, matchedName, scriptsMap, ctx.allocator, cwd, rootPath, None)
                }
            } else {
                Output.prettyErrorLn("error: Cannot use glob pattern \"${rawName}\" without package.json scripts")
                Global.exit(1)
            }
        } else {
            addScriptConfigs(configs, groupInfos, rawName, scriptsMap, ctx.allocator, cwd, rootPath, None)
        }
    }

    if (configs.size == 0) {
        Output.prettyErrorLn("error: No scripts to run")
        Global.exit(1)
    }

    // 计算最大标签宽度
    var maxLabelLen: Int64 = 0
    for (config in configs) {
        if (config.label.length > maxLabelLen) {
            maxLabelLen = config.label.length
        }
    }

    val useColors = Output.enableAnsiColorsStderr

    val state = MultiRunState()
    state.handles = ArrayList<MultiRunProcessHandle>(configs.size)
    state.eventLoop = eventLoop
    state.maxLabelLen = maxLabelLen
    state.shellBin = shellBin
    state.noExitOnError = ctx.noExitOnError
    state.env = thisTranspiler.env
    state.useColors = useColors

    // 初始化 handles
    for ((i, config) in configs.iterator().indexed()) {
        // 确定颜色索引
        var colorIdx: Int64 = 0
        for ((gi, group) in groupInfos.iterator().indexed()) {
            if (i >= group.start && i < group.start + group.count) {
                colorIdx = gi
                break
            }
        }

        val handle = MultiRunProcessHandle()
        handle.state = state
        handle.config = config
        handle.colorIdx = colorIdx
        handle.options = SpawnOptions()
        handle.options.stdin = StdioKind.ignore
        handle.options.stdout = StdioKind.buffer
        handle.options.stderr = StdioKind.buffer
        handle.options.cwd = config.cwd
        handle.options.stream = true
        state.handles.append(handle)
    }

    // 设置 pre->main->post 链
    for (group in groupInfos) {
        if (group.count > 1) {
            var j = group.start
            while (j < group.start + group.count - 1) {
                state.handles[j.toInt()].groupDependents.append(state.handles[(j + 1).toInt()])
                state.handles[(j + 1).toInt()].remainingDependencies += 1
                j += 1
            }
        }
    }

    // 顺序模式: 链接组间依赖
    if (ctx.sequential) {
        var gi = 0
        while (gi < groupInfos.size - 1) {
            val currentGroup = groupInfos[gi]
            val nextGroup = groupInfos[gi + 1]
            val lastInCurrent = currentGroup.start + currentGroup.count - 1
            val firstInNext = nextGroup.start
            state.handles[lastInCurrent.toInt()].nextDependents.append(state.handles[firstInNext.toInt()])
            state.handles[firstInNext.toInt()].remainingDependencies += 1
            gi += 1
        }
    }

    // 启动无依赖的 handles
    for (handle in state.handles) {
        if (handle.remainingDependencies == 0) {
            handle.start()
        }
    }

    val multiAbortHandler = MultiRunAbortHandler()
    multiAbortHandler.install()

    while (!state.isDone()) {
        if (multiAbortHandler.shouldAbort && !state.aborted) {
            multiAbortHandler.uninstall()
            state.abort()
        }
        eventLoop.tickOnce(state)
    }

    val status = state.finalize()
    Global.exit(status)
}

/// 中止处理器
/// 对应 Bun: multi_run AbortHandler
public class MultiRunAbortHandler {
    public var shouldAbort: Bool = false

    public func install(): Unit {
        shouldAbort = false
        SignalHandler.install(SIGINT, { shouldAbort = true })
    }

    public func uninstall(): Unit {
        SignalHandler.uninstall()
    }
}
