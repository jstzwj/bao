// 严格翻译自: src/cli/filter_run.zig
package bao_cli

import bao_core.*

// ============================================================================
// FilterRun — 使用 --filter/--workspaces 运行脚本
// 严格翻译自: src/cli/filter_run.zig
// ============================================================================

/// 脚本配置
/// 对应 Bun: filter_run ScriptConfig
public class FilterScriptConfig {
    public var packageJsonPath: String
    public var packageName: String
    public var scriptName: String
    public var scriptContent: String
    public var combined: String
    public var deps: DependencyMap
    public var PATH: String
    public var elideCount: ?Int64

    public init() {
        packageJsonPath = ""
        packageName = ""
        scriptName = ""
        scriptContent = ""
        combined = ""
        deps = DependencyMap()
        PATH = ""
        elideCount = None
    }
}

/// 使用 --filter/--workspaces 运行脚本
/// 对应 Bun: runScriptsWithFilter()
public func runScriptsWithFilter(ctx: CommandContext): Unit {
    val scriptName = if (ctx.positionals.size > 1) {
        ctx.positionals[1]
    } else if (ctx.positionals.size > 0) {
        ctx.positionals[0]
    } else {
        Output.prettyErrorLn("error: No script name provided")
        Global.exit(1)
        return
    }

    val preScriptName = "pre${scriptName}"
    val postScriptName = "post${scriptName}"

    val fsInstance = FileSystem.init()

    // 确定 filter
    var filtersToUse = ctx.filters
    if (ctx.workspaces) {
        filtersToUse = ArrayList<String>()
        filtersToUse.append("*")
    }

    val filterInstance = FilterSet(ctx.allocator, filtersToUse, fsInstance.topLevelDir)
    val patterns = ArrayList<String>()

    val rootBuf = StringBuilder()
    val resolveRoot = getCandidatePackagePatterns(ctx.allocator, ctx.log, patterns, fsInstance.topLevelDir, rootBuf)

    // 配置环境
    val thisTranspiler = Transpiler()
    RunCommand.configureEnvForRun(ctx, thisTranspiler, None, true, false)

    val packageJsonIter = PackageFilterIterator(ctx.allocator, patterns, resolveRoot)

    // 收集脚本配置
    val scripts = ArrayList<FilterScriptConfig>()

    while (true) {
        val packageJsonPath = packageJsonIter.next()
        if (packageJsonPath == None) {
            break
        }

        val dirpath = Path.dirname(packageJsonPath!!)
        val path = Strings.withoutTrailingSlash(dirpath)

        // 使用 --workspaces 时跳过根包
        if (ctx.workspaces && path == resolveRoot) {
            continue
        }

        val pkgjson = PackageJSON.parse(thisTranspiler.resolver, dirpath)
        if (pkgjson == None) {
            continue
        }

        val pkgscripts = pkgjson!!.scripts ?: continue

        if (!filterInstance.matches(path, pkgjson!!.name)) {
            continue
        }

        val pkgPATH = RunCommand.configurePathForRunWithPackageJsonDir(ctx, dirpath, thisTranspiler, None, dirpath, ctx.debug.runInBun)

        // pre/main/post 脚本
        val scriptNames = [preScriptName, scriptName, postScriptName]
        for ((i, name) in scriptNames.iterator().indexed()) {
            val originalContent = pkgscripts.get(name)
            if (originalContent == None) {
                if (i == 1 && ctx.workspaces && !ctx.ifPresent) {
                    Output.errGeneric("Missing '${scriptName}' script at '${path}'")
                    Global.exit(1)
                }
                continue
            }

            var copyScript = StringBuilder()
            copyScript.append(RunCommand.replacePackageManagerRun(originalContent!!))
            val lenCommandOnly = copyScript.length

            for (part in ctx.passthrough) {
                copyScript.append(' ')
                copyScript.append(Shell.escape(part))
            }

            val config = FilterScriptConfig()
            config.packageJsonPath = packageJsonPath!!
            config.packageName = pkgjson!!.name
            config.scriptName = name
            config.scriptContent = copyScript.toString().substring(0, lenCommandOnly)
            config.combined = copyScript.toString()
            config.deps = pkgjson!!.dependencies
            config.PATH = pkgPATH
            config.elideCount = ctx.bundlerOptions.elideLines

            scripts.append(config)
        }
    }

    if (scripts.size == 0) {
        if (ctx.ifPresent) {
            Global.exit(0)
        }
        if (ctx.workspaces) {
            Output.errGeneric("No workspace packages have script \"${scriptName}\"")
        } else {
            Output.errGeneric("No packages matched the filter")
        }
        Global.exit(1)
    }

    val eventLoop = MiniEventLoop.initGlobal(thisTranspiler.env, None)
    val shellBin = RunCommand.findShell(thisTranspiler.env.get("PATH") ?: "", fsInstance.topLevelDir)
        ?: { Output.prettyErrorLn("error: Missing shell"); Global.exit(1) }()

    val state = FilterRunState()
    state.handles = ArrayList<FilterProcessHandle>()
    state.eventLoop = eventLoop
    state.prettyOutput = Output.enableAnsiColorsStdout
    state.shellBin = shellBin
    state.env = thisTranspiler.env

    // 初始化 handles
    val map = HashMap<String, ArrayList<FilterProcessHandle>>()
    for (script in scripts) {
        val handle = FilterProcessHandle()
        handle.state = state
        handle.config = script
        handle.options = SpawnOptions()
        handle.options.stdin = StdioKind.ignore
        handle.options.stdout = StdioKind.buffer
        handle.options.stderr = StdioKind.buffer
        handle.options.cwd = Path.dirname(script.packageJsonPath)
        handle.options.stream = true
        state.handles.append(handle)

        val res = map.getOrPut(script.packageName, { ArrayList<FilterProcessHandle>() })
        res.append(handle)
    }

    // 计算依赖
    for (handle in state.handles) {
        val deps = handle.config.deps
        for ((name, _) in deps) {
            if (map.contains(name)) {
                val pkgs = map.get(name)!!
                for (dep in pkgs) {
                    dep.dependents.append(handle)
                    handle.remainingDependencies += 1
                }
            }
        }
    }

    // 检查循环依赖
    var hasCycle = false
    for (handle in state.handles) {
        if (FilterRunState.hasCycle(handle)) {
            hasCycle = true
            break
        }
    }
    if (hasCycle) {
        for (handle in state.handles) {
            handle.dependents.clear()
            handle.remainingDependencies = 0
        }
    }

    // 设置 pre/post 脚本依赖
    for (i in 0..state.handles.size - 1) {
        if (state.handles[i].config.packageName == state.handles[i + 1].config.packageName) {
            state.handles[i].dependents.append(state.handles[i + 1])
            state.handles[i + 1].remainingDependencies += 1
        }
    }

    // 启动无依赖的脚本
    for (handle in state.handles) {
        if (handle.remainingDependencies == 0) {
            handle.start()
        }
    }

    FilterRunAbortHandler.install()

    while (!state.isDone()) {
        if (FilterRunAbortHandler.shouldAbort && !state.aborted) {
            FilterRunAbortHandler.uninstall()
            state.abort()
        }
        eventLoop.tickOnce(state)
    }

    val status = state.finalize()
    Global.exit(status)
}

/// FilterRun 状态
/// 对应 Bun: filter_run State
public class FilterRunState {
    public var handles: ArrayList<FilterProcessHandle>
    public var eventLoop: MiniEventLoop
    public var remainingScripts: Int64
    public var drawBuf: StringBuilder
    public var lastLinesWritten: Int64
    public var prettyOutput: Bool
    public var shellBin: String
    public var aborted: Bool
    public var env: DotEnvLoader

    public init() {
        handles = ArrayList<FilterProcessHandle>()
        eventLoop = MiniEventLoop()
        remainingScripts = 0
        drawBuf = StringBuilder()
        lastLinesWritten = 0
        prettyOutput = false
        shellBin = ""
        aborted = false
        env = DotEnvLoader()
    }

    /// 是否所有工作完成
    public func isDone(): Bool {
        return remainingScripts == 0
    }

    /// 读取数据块
    public func readChunk(handle: FilterProcessHandle, chunk: String): Unit {
        if (prettyOutput) {
            handle.buffer.append(chunk)
            redraw(false)
        } else {
            val content = chunk
            drawBuf.clear()
            if (handle.buffer.length > 0) {
                val newlineIdx = content.indexOf('\n')
                if (newlineIdx >= 0) {
                    handle.buffer.append(content.substring(0, newlineIdx + 1))
                    val rest = content.substring(newlineIdx + 1)
                    drawBuf.append("${handle.config.packageName} ${handle.config.scriptName}: ${handle.buffer.toString()}")
                    handle.buffer.clear()
                    // 处理剩余行
                    var remaining = rest
                    while (true) {
                        val idx = remaining.indexOf('\n')
                        if (idx < 0) {
                            handle.buffer.append(remaining)
                            break
                        }
                        val line = remaining.substring(0, idx + 1)
                        drawBuf.append("${handle.config.packageName} ${handle.config.scriptName}: ${line}")
                        remaining = remaining.substring(idx + 1)
                    }
                } else {
                    handle.buffer.append(content)
                    return
                }
            }
            flushDrawBuf()
        }
    }

    /// 进程退出回调
    public func processExit(handle: FilterProcessHandle): Unit {
        remainingScripts -= 1
        if (!aborted) {
            for (dependent in handle.dependents) {
                dependent.remainingDependencies -= 1
                if (dependent.remainingDependencies == 0) {
                    dependent.start()
                }
            }
        }

        if (prettyOutput) {
            redraw(false)
        } else {
            drawBuf.clear()
            if (handle.buffer.length > 0) {
                drawBuf.append("${handle.config.packageName}: ${handle.buffer.toString()}\n")
                handle.buffer.clear()
            }
            // 打印退出状态
            when (handle.status) {
                case ProcessStatus.exited(code) =>
                    drawBuf.append("${handle.config.packageName} ${handle.config.scriptName}: Exited with code ${code}\n")
                case ProcessStatus.signaled(sig) =>
                    drawBuf.append("${handle.config.packageName} ${handle.config.scriptName}: Signaled with code ${sig}\n")
                else => {}
            }
            flushDrawBuf()
        }
    }

    /// 重绘 (pretty 模式)
    public func redraw(isAbort: Bool): Unit {
        if (!prettyOutput) {
            return
        }
        drawBuf.clear()
        for (handle in handles) {
            val elideLines = if (isAbort) None else handle.config.elideCount ?: 10
            drawBuf.append("${handle.config.packageName} ${handle.config.scriptName} $ ${handle.config.scriptContent}\n")
            // 简化: 显示缓冲区内容
            if (handle.buffer.length > 0) {
                drawBuf.append("| ${handle.buffer.toString()}\n")
            }
            drawBuf.append("+- ")
            if (handle.process != None) {
                when (handle.status) {
                    case ProcessStatus.running => drawBuf.append("Running...\n")
                    case ProcessStatus.exited(code) => {
                        if (code == 0) {
                            drawBuf.append("Done\n")
                        } else {
                            drawBuf.append("Exited with code ${code}\n")
                        }
                    }
                    case ProcessStatus.signaled(sig) => drawBuf.append("Signaled: ${sig}\n")
                    case ProcessStatus.err(e) => drawBuf.append("Error\n")
                }
            } else {
                drawBuf.append("Waiting for ${handle.remainingDependencies} other script(s)\n")
            }
        }
        flushDrawBuf()
    }

    /// 刷新绘制缓冲区
    public func flushDrawBuf(): Unit {
        Output.write(drawBuf.toString())
    }

    /// 中止所有进程
    public func abort(): Unit {
        aborted = true
        for (handle in handles) {
            if (handle.process != None) {
                handle.process!!.kill()
            }
        }
    }

    /// 确定最终退出码
    public func finalize(): Int64 {
        if (aborted) {
            redraw(true)
        }
        for (handle in handles) {
            when (handle.status) {
                case ProcessStatus.exited(code) => if (code != 0) return code
                case ProcessStatus.signaled(_) => return 1
                else => return 1
            }
        }
        return 0
    }

    /// 检查循环依赖
    public static func hasCycle(current: FilterProcessHandle): Bool {
        return hasCycleInternal(current, ArrayList<FilterProcessHandle>())
    }

    private static func hasCycleInternal(current: FilterProcessHandle, visited: ArrayList<FilterProcessHandle>): Bool {
        if (visited.contains(current)) {
            return true
        }
        visited.append(current)
        for (dep in current.dependents) {
            if (hasCycleInternal(dep, visited)) {
                return true
            }
        }
        visited.removeAt(visited.size - 1)
        return false
    }
}

/// 进程 Handle
/// 对应 Bun: filter_run ProcessHandle
public class FilterProcessHandle {
    public var config: FilterScriptConfig
    public var state: FilterRunState
    public var buffer: StringBuilder
    public var process: ?Process
    public var options: SpawnOptions
    public var status: ProcessStatus
    public var remainingDependencies: Int64
    public var dependents: ArrayList<FilterProcessHandle>

    public init() {
        config = FilterScriptConfig()
        state = FilterRunState()
        buffer = StringBuilder()
        process = None
        options = SpawnOptions()
        status = ProcessStatus.running
        remainingDependencies = 0
        dependents = ArrayList<FilterProcessHandle>()
    }

    /// 启动进程
    public func start(): Unit {
        state.remainingScripts += 1

        val argv = [state.shellBin, "-c", config.combined]
        process = Sys.spawnProcess(options, argv)
        status = ProcessStatus.running
    }
}

/// 中止信号处理器
public class FilterRunAbortHandler {
    public static var shouldAbort: Bool = false

    public static func install(): Unit {
        shouldAbort = false
        SignalHandler.install(SIGINT, { shouldAbort = true })
    }

    public static func uninstall(): Unit {
        SignalHandler.uninstall()
    }
}
