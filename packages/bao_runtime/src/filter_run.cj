// 严格翻译自: src/runtime/filter_run.zig
// --filter 运行 — 按工作区过滤并运行脚本
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*
import bao_event_loop.*


public class FilterScriptConfig {
    public var packageJsonPath: String
    public var packageName: String
    public var scriptName: String
    public var scriptContent: String
    public var combined: String
    public var deps: DependencyMap
    public var path: String
    public var elideCount: ?Int64

    public init(packageJsonPath: String, packageName: String, scriptName: String, scriptContent: String, combined: String, path: String) {
        this.packageJsonPath = packageJsonPath
        this.packageName = packageName
        this.scriptName = scriptName
        this.scriptContent = scriptContent
        this.combined = combined
        this.path = path
        this.deps = DependencyMap()
        this.elideCount = None
    }

    /// 比较（按包名排序）
    public static func compare(a: FilterScriptConfig, b: FilterScriptConfig): Int64 {
        if (a.packageName < b.packageName) { -1 } else if (a.packageName > b.packageName) { 1 } else { 0 }
    }
}

/// 过滤运行进程句柄
public class FilterProcessHandle {
    public var config: FilterScriptConfig
    public var state: FilterRunState
    public var buffer: ArrayList<UInt8>
    public var process: ?FilterSpawnedProcess
    public var options: SpawnOptions
    public var startTime: ?TimeInstant
    public var endTime: ?TimeInstant
    public var remainingDependencies: Int64
    public var dependents: ArrayList<FilterProcessHandle>
    public var visited: Bool
    public var visiting: Bool

    public init(config: FilterScriptConfig, state: FilterRunState) {
        this.config = config
        this.state = state
        this.buffer = ArrayList<UInt8>()
        this.process = None
        this.options = SpawnOptions()
        this.startTime = None
        this.endTime = None
        this.remainingDependencies = 0
        this.dependents = ArrayList<FilterProcessHandle>()
        this.visited = false
        this.visiting = false
    }

    /// 启动进程
    public func start(): Unit {
        // TODO: implement with proper BunSpawn/TimeInstant APIs
        this.state.remainingScripts += 1
    }

    /// 进程退出回调
    public func onExit(status: SpawnStatus): Unit {
        // TODO: implement with TimeInstant/Since APIs
        this.state.remainingScripts -= 1

        // 启动依赖项
        for (dep in this.dependents) {
            dep.remainingDependencies -= 1
            if (dep.remainingDependencies == 0) {
                dep.start()
            }
        }
    }
}

/// 过滤运行的已生成进程
public class FilterSpawnedProcess {
    public var status: SpawnStatus

    public init(status: SpawnStatus) {
        this.status = status
    }
}

/// 过滤运行状态
public class FilterRunState {
    public var eventLoop: MiniEventLoop
    public var env: HashMap<String, String>
    public var shellBin: String
    public var remainingScripts: Int64
    public var exitCode: Int64
    public var handles: ArrayList<FilterProcessHandle>
    public var aborted: Bool
    public var filterSet: FilterSet

    public init(eventLoop: MiniEventLoop, env: HashMap<String, String>, shellBin: String, filterSet: FilterSet) {
        this.eventLoop = eventLoop
        this.env = env
        this.shellBin = shellBin
        this.remainingScripts = 0
        this.exitCode = 0
        this.handles = ArrayList<FilterProcessHandle>()
        this.aborted = false
        this.filterSet = filterSet
    }

    /// 中止所有
    public func abort(): Unit {
        this.aborted = true
        // TODO: kill spawned processes
    }

    /// 等待所有完成
    public func wait(): Unit {
        // TODO: implement event loop tick
    }
}

/// 依赖图
public class DependencyMap {
    public var deps: HashMap<String, ArrayList<String>>

    public init() {
        this.deps = HashMap<String, ArrayList<String>>()
    }

    public func addDependency(from: String, to: String): Unit {
        let opt = this.deps.get(from)
        if (opt.isSome()) {
            opt.getOrThrow().append(to)
        } else {
            let list = ArrayList<String>()
            list.append(to)
            this.deps.put(from, list)
        }
    }
}

// ============================================================================
// FilterRun — 入口
// ============================================================================

/// 按过滤器运行工作区脚本
public class FilterRun {
    /// 执行过滤运行
    public static func run(
        eventLoop: MiniEventLoop,
        env: HashMap<String, String>,
        filters: Array<String>,
        scriptName: String,
        cwd: String,
        allocator: Allocator
    ): Int64 {
        // TODO: implement with PackageFilterIterator, getCandidatePackagePatterns, etc.
        return 0
    }

    /// 构建依赖图
    static func buildDependencyGraph(handles: ArrayList<FilterProcessHandle>): Unit {
        // TODO: implement
    }
}
