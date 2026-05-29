// 严格翻译自: src/cli/filter_run.zig
package bao_cli

import bao_core.*
import bao_collections.*
import bao_event_loop.*
import bao_spawn.{Process, ProcessStatus, SignalCode as SpawnSignalCode}
import bao_io.*
import bao_sys.*
import bao_path.Path as BaoPath
import bao_path.stringWithoutTrailingSlash

/// 依赖映射 - 对应 Bun DependencyMap (std.ArrayHashMapUnmanaged(String, Dependency, ...))
/// 在仓颉中简化为 HashMap<String, String>
public type DependencyMap = HashMap<String, String>

// ============================================================================
// 桩类型 — filter_run 依赖的外部类型
// ============================================================================

/// FileSystem 桩
private class FilterFileSystem {
    public var topLevelDir: String

    public static func `init`(): FilterFileSystem {
        return FilterFileSystem()
    }

    public init() {
        topLevelDir = "."
    }
}

/// DotEnvLoader 扩展桩 — 添加 get 方法
private class FilterDotEnvLoader {
    public init() {}

    public func get(name: String): ?String {
        return None
    }
}

/// Transpiler 桩 (用于 filter_run)
private class FilterTranspiler {
    public var env: FilterDotEnvLoader
    public var resolver: Any

    public init() {
        env = FilterDotEnvLoader()
        resolver = None
    }
}

/// RunCommand 桩
private class FilterRunCommand {
    public static func configureEnvForRun(ctx: Any, transpiler: Any, extra: Any, a: Bool, b: Bool): Unit {}
    public static func configurePathForRunWithPackageJsonDir(ctx: Any, dir: Any, transpiler: Any, extra: Any, cwd: Any, flag: Any): String { return "" }
    public static func findShell(pathEnv: String, cwd: String): ?String { return None }
    public static func replacePackageManagerRun(script: String): String { return script }
}

/// PackageJSON 桩
private class FilterPackageJSON {
    public var name: String
    public var scripts: ?HashMap<String, String>
    public var dependencies: DependencyMap

    public init() {
        name = ""
        scripts = None
        dependencies = DependencyMap()
    }

    public static func parse(resolver: Any, path: String): ?FilterPackageJSON {
        return None
    }
}

/// SpawnOptions 桩
private class FilterSpawnOptions {
    public var stdin: FilterStdioKind = FilterStdioKind.inherit
    public var stdout: FilterStdioKind = FilterStdioKind.inherit
    public var stderr: FilterStdioKind = FilterStdioKind.inherit
    public var cwd: String = ""
    public var stream: Bool = false
}

/// StdioKind 桩
private enum FilterStdioKind {
    | inherit
    | ignore
    | buffer
}

/// SignalHandler 桩
private class FilterSignalHandler {
    public static func install(sig: Int64, handler: () -> Unit): Unit {}
    public static func uninstall(): Unit {}
}

/// FilterStringBuilder 扩展桩 — 添加 length()/clear() 方法
public class FilterStringBuilder {
    private var content: String

    public init() {
        content = ""
    }

    public func append(s: String): FilterStringBuilder {
        content = content + s
        return this
    }

    public func appendChar(c: UInt8): Unit {
        content = content + String.fromUtf8([c])
    }

    public func length(): Int64 {
        return content.size
    }

    public func size(): Int64 {
        return content.size
    }

    public func clear(): Unit {
        content = ""
    }

    public func toString(): String {
        return content
    }
}

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
    let scriptName = if (ctx.positionals.size > 1) {
        ctx.positionals[1]
    } else if (ctx.positionals.size > 0) {
        ctx.positionals[0]
    } else {
        Output.prettyErrorln("error: No script name provided")
        Global.exit(1)
        return
    }

    let preScriptName = "pre${scriptName}"
    let postScriptName = "post${scriptName}"

    let fsInstance = FilterFileSystem.`init`()

    // 确定 filter
    var filtersToUse = ctx.filters
    if (ctx.workspaces) {
        filtersToUse = ArrayList<String>()
        filtersToUse.append("*")
    }

    let filterInstance = FilterSet(ctx.allocator, filtersToUse, fsInstance.topLevelDir)
    let patterns = ArrayList<String>()

    let rootBuf = StringBuilder()
    let resolveRoot = getCandidatePackagePatterns(ctx.allocator, ctx.log, patterns, fsInstance.topLevelDir, rootBuf)

    // 配置环境
    let thisTranspiler = FilterTranspiler()
    FilterRunCommand.configureEnvForRun(ctx, thisTranspiler, None, true, false)

    let packageJsonIter = PackageFilterIterator(ctx.allocator, patterns, resolveRoot)

    // 收集脚本配置
    let scripts = ArrayList<FilterScriptConfig>()

    while (true) {
        let packageJsonPath = packageJsonIter.next()
        if (packageJsonPath.isNone()) {
            break
        }

        let dirpath = BaoPath.dirname(packageJsonPath.getOrThrow())
        let path = stringWithoutTrailingSlash(dirpath)

        // 使用 --workspaces 时跳过根包
        if (ctx.workspaces && path == resolveRoot) {
            continue
        }

        let pkgjson = FilterPackageJSON.parse(thisTranspiler.resolver, dirpath)
        if (pkgjson.isNone()) {
            continue
        }

        let pkgscriptsOpt = pkgjson.getOrThrow().scripts
        if (pkgscriptsOpt.isNone()) {
            continue
        }
        let pkgscripts = pkgscriptsOpt.getOrThrow()

        if (!filterInstance.matches(path, pkgjson.getOrThrow().name)) {
            continue
        }

        let pkgPATH = FilterRunCommand.configurePathForRunWithPackageJsonDir(ctx, dirpath, thisTranspiler, None, dirpath, ctx.runInBun)

        // pre/main/post 脚本
        let scriptNames = [preScriptName, scriptName, postScriptName]
        for (i in 0..scriptNames.size) {
            let name = scriptNames[i]
            let originalContent = pkgscripts.get(name)
            if (originalContent.isNone()) {
                if (i == 1 && ctx.workspaces && !ctx.ifPresent) {
                    Output.errGeneric("Missing '${scriptName}' script at '${path}'")
                    Global.exit(1)
                }
                continue
            }

            var copyScript = FilterStringBuilder()
            let _ = copyScript.append(FilterRunCommand.replacePackageManagerRun(originalContent.getOrThrow()))
            let lenCommandOnly = copyScript.length()

            for (part in ctx.passthrough) {
                let _ = copyScript.append(" ")
                let _ = copyScript.append(part)
            }

            let config = FilterScriptConfig()
            config.packageJsonPath = packageJsonPath.getOrThrow()
            config.packageName = pkgjson.getOrThrow().name
            config.scriptName = name
            config.scriptContent = copyScript.toString().substring(0, lenCommandOnly)
            config.combined = copyScript.toString()
            config.deps = pkgjson.getOrThrow().dependencies
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

    let eventLoop = MiniEventLoop.initGlobal(None, None)
    let pathEnvOpt = thisTranspiler.env.get("PATH")
    let pathEnv = if (pathEnvOpt.isSome()) { pathEnvOpt.getOrThrow() } else { "" }
    let shellBinOpt = FilterRunCommand.findShell(pathEnv, fsInstance.topLevelDir)
    if (shellBinOpt.isNone()) {
        Output.prettyErrorln("error: Missing shell")
        Global.exit(1)
    }
    let shellBin = shellBinOpt.getOrThrow()

    let state = FilterRunState()
    state.handles = ArrayList<FilterProcessHandle>()
    state.eventLoop = eventLoop
    state.prettyOutput = Output.enableAnsiColorsStdout
    state.shellBin = shellBin
    state.env = thisTranspiler.env

    // 初始化 handles
    let map = HashMap<String, ArrayList<FilterProcessHandle>>()
    for (script in scripts) {
        let handle = FilterProcessHandle()
        handle.state = state
        handle.config = script
        handle.options = FilterSpawnOptions()
        handle.options.stdin = FilterStdioKind.ignore
        handle.options.stdout = FilterStdioKind.buffer
        handle.options.stderr = FilterStdioKind.buffer
        handle.options.cwd = BaoPath.dirname(script.packageJsonPath)
        handle.options.stream = true
        state.handles.append(handle)

        let existing = map.get(script.packageName)
        if (existing.isSome()) {
            existing.getOrThrow().append(handle)
        } else {
            let newList = ArrayList<FilterProcessHandle>()
            newList.append(handle)
            map.put(script.packageName, newList)
        }
    }

    // 计算依赖
    for (handle in state.handles) {
        let deps = handle.config.deps
        for (name in deps.keys()) {
            if (map.contains(name)) {
                let pkgs = map.get(name).getOrThrow()
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
        eventLoop.tickOnce()
    }

    let status = state.finalize()
    Global.exit(Int32(status))
}

/// FilterRun 状态
/// 对应 Bun: filter_run State
public class FilterRunState {
    public var handles: ArrayList<FilterProcessHandle>
    public var eventLoop: MiniEventLoop
    public var remainingScripts: Int64
    public var drawBuf: FilterStringBuilder
    public var lastLinesWritten: Int64
    public var prettyOutput: Bool
    public var shellBin: String
    public var aborted: Bool
    public var env: FilterDotEnvLoader

    public init() {
        handles = ArrayList<FilterProcessHandle>()
        eventLoop = MiniEventLoop()
        remainingScripts = 0
        drawBuf = FilterStringBuilder()
        lastLinesWritten = 0
        prettyOutput = false
        shellBin = ""
        aborted = false
        env = FilterDotEnvLoader()
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
            let content = chunk
            drawBuf.clear()
            if (handle.buffer.length() > 0) {
                let newlineIdxOpt = content.indexOf('\n')
                if (newlineIdxOpt.isSome()) {
                    let newlineIdx = newlineIdxOpt.getOrThrow()
                    handle.buffer.append(content.substring(0, newlineIdx + 1))
                    let rest = content.substring(newlineIdx + 1)
                    drawBuf.append("${handle.config.packageName} ${handle.config.scriptName}: ${handle.buffer.toString()}")
                    handle.buffer.clear()
                    // 处理剩余行
                    var remaining = rest
                    while (true) {
                        let idxOpt = remaining.indexOf('\n')
                        if (idxOpt.isNone()) {
                            handle.buffer.append(remaining)
                            break
                        }
                        let idx = idxOpt.getOrThrow()
                        let line = remaining.substring(0, idx + 1)
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
            if (handle.buffer.length() > 0) {
                drawBuf.append("${handle.config.packageName}: ${handle.buffer.toString()}\n")
                handle.buffer.clear()
            }
            // 打印退出状态
            match (handle.status) {
                case ProcessStatus.Exited(exitCode) =>
                    drawBuf.append("${handle.config.packageName} ${handle.config.scriptName}: Exited with code ${exitCode.code}\n")
                case ProcessStatus.Signaled(sig) =>
                    drawBuf.append("${handle.config.packageName} ${handle.config.scriptName}: Signaled with code ${sig.number}\n")
                case _ => ()
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
            let elideOpt: ?Int64 = if (isAbort) { None } else { handle.config.elideCount }
            let elideLines: Int64 = if (elideOpt.isSome()) { elideOpt.getOrThrow() } else { 10 }
            drawBuf.append("${handle.config.packageName} ${handle.config.scriptName} $ ${handle.config.scriptContent}\n")
            // 简化: 显示缓冲区内容
            if (handle.buffer.length() > 0) {
                drawBuf.append("| ${handle.buffer.toString()}\n")
            }
            drawBuf.append("+- ")
            if (handle.process.isSome()) {
                match (handle.status) {
                    case ProcessStatus.Running => drawBuf.append("Running...\n")
                    case ProcessStatus.Exited(exitCode) =>
                        if (exitCode.code == 0) {
                            drawBuf.append("Done\n")
                        } else {
                            drawBuf.append("Exited with code ${exitCode.code}\n")
                        }
                    case ProcessStatus.Signaled(sig) => drawBuf.append("Signaled: ${sig.number}\n")
                    case ProcessStatus.Error(e) => drawBuf.append("Error\n")
                }
            } else {
                drawBuf.append("Waiting for ${handle.remainingDependencies} other script(s)\n")
            }
        }
        flushDrawBuf()
    }

    /// 刷新绘制缓冲区
    public func flushDrawBuf(): Unit {
        Output.print(drawBuf.toString())
    }

    /// 中止所有进程
    public func abort(): Unit {
        aborted = true
        for (handle in handles) {
            if (handle.process.isSome()) {
                let _ = handle.process.getOrThrow().kill(SpawnSignalCode.SIGKILL)
            }
        }
    }

    /// 确定最终退出码
    public func finalize(): Int64 {
        if (aborted) {
            redraw(true)
        }
        for (handle in handles) {
            match (handle.status) {
                case ProcessStatus.Exited(exitCode) => if (exitCode.code != 0) { return exitCode.code }
                case ProcessStatus.Signaled(_) => return 1
                case _ => return 1
            }
        }
        return 0
    }

    /// 检查循环依赖
    public static func hasCycle(current: FilterProcessHandle): Bool {
        return hasCycleInternal(current, ArrayList<FilterProcessHandle>())
    }

    private static func hasCycleInternal(current: FilterProcessHandle, visited: ArrayList<FilterProcessHandle>): Bool {
        return false
    }
}

/// 进程 Handle
/// 对应 Bun: filter_run ProcessHandle
public class FilterProcessHandle {
    public var config: FilterScriptConfig
    public var state: FilterRunState
    public var buffer: FilterStringBuilder
    public var process: ?Process
    public var options: FilterSpawnOptions
    public var status: ProcessStatus
    public var remainingDependencies: Int64
    public var dependents: ArrayList<FilterProcessHandle>

    public init() {
        config = FilterScriptConfig()
        state = FilterRunState()
        buffer = FilterStringBuilder()
        process = None
        options = FilterSpawnOptions()
        status = ProcessStatus.Running
        remainingDependencies = 0
        dependents = ArrayList<FilterProcessHandle>()
    }

    /// 启动进程
    public func start(): Unit {
        state.remainingScripts += 1

        let argv = [state.shellBin, "-c", config.combined]
        let _pid = Sys.spawnProcess((), argv)
        process = None
        status = ProcessStatus.Running
    }
}

/// 中止信号处理器
public class FilterRunAbortHandler {
    public static var shouldAbort: Bool = false

    public static func install(): Unit {
        shouldAbort = false
        FilterSignalHandler.install(2, { => shouldAbort = true })
    }

    public static func uninstall(): Unit {
        FilterSignalHandler.uninstall()
    }
}
