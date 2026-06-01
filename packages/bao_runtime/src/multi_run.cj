// 严格翻译自: src/runtime/cli/multi_run.zig
// 多脚本并行运行器 — 用于 bun run 的多脚本并行执行
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*
import bao_event_loop.*

// ============================================================================
// multi_run — 多脚本并行运行器
// 对应 Bun: src/runtime/cli/multi_run.zig
// ============================================================================

/// 脚本配置
public class ScriptConfig {
    public var label: String
    public var command: String
    public var cwd: String
    public var path: String

    public init(label: String, command: String, cwd: String, path: String) {
        this.label = label
        this.command = command
        this.cwd = cwd
        this.path = path
    }
}

/// 管道读取器 — 跟踪 stdout/stderr
public class RunPipeReader {
    public var handle: ?ProcessHandle
    public var isStderr: Bool
    public var lineBuffer: ArrayList<UInt8>

    public init(handle: ?ProcessHandle, isStderr: Bool) {
        this.handle = handle
        this.isStderr = isStderr
        this.lineBuffer = ArrayList<UInt8>()
    }

    /// 读取数据块回调
    public func onReadChunk(chunk: Array<UInt8>, hasMore: ReadState): Bool {
        if (this.handle.isSome()) {
            this.handle.getOrThrow().state.readChunk(this, chunk)
        }
        return true
    }

    /// 读取完成回调
    public func onReaderDone(): Unit {
        // 无操作
    }

    /// 读取错误回调
    public func onReaderError(err: SysError): Unit {
        // 无操作
    }

    /// 获取事件循环
    public func eventLoop(): MiniEventLoop {
        if (this.handle.isSome()) {
            return this.handle.getOrThrow().state.eventLoop
        }
        return MiniEventLoop()  // fallback
    }
}

/// 进程句柄 — 管理单个脚本进程
public class ProcessHandle {
    public var config: ScriptConfig
    public var state: State
    public var colorIdx: Int64
    public var stdoutReader: RunPipeReader
    public var stderrReader: RunPipeReader
    public var process: ?SpawnedProcess
    public var options: SpawnOptions
    public var startTime: ?TimeInstant
    public var endTime: ?TimeInstant
    public var remainingDependencies: Int64
    public var groupDependents: ArrayList<ProcessHandle>
    public var nextDependents: ArrayList<ProcessHandle>

    public init(config: ScriptConfig, state: State, colorIdx: Int64) {
        this.config = config
        this.state = state
        this.colorIdx = colorIdx
        this.stdoutReader = RunPipeReader(Option<ProcessHandle>.None, false)
        this.stderrReader = RunPipeReader(Option<ProcessHandle>.None, true)
        this.process = None
        this.options = SpawnOptions()
        this.startTime = None
        this.endTime = None
        this.remainingDependencies = 0
        this.groupDependents = ArrayList<ProcessHandle>()
        this.nextDependents = ArrayList<ProcessHandle>()
        // Set back-reference after all fields initialized
        this.stdoutReader.handle = this
        this.stderrReader.handle = this
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

        // 启动组内依赖
        for (dep in this.groupDependents) {
            dep.start()
        }
        // 启动下一组依赖
        for (dep in this.nextDependents) {
            dep.start()
        }
    }

    /// 关闭句柄
    public func close(): Unit {
        this.stdoutReader.lineBuffer.clear()
        this.stderrReader.lineBuffer.clear()
        this.groupDependents.clear()
        this.nextDependents.clear()
    }
}

/// 已启动的进程
public class SpawnedProcess {
    public var ptr: SpawnProcess
    public var status: SpawnStatus

    public init(ptr: SpawnProcess, status: SpawnStatus) {
        this.ptr = ptr
        this.status = status
    }
}

/// 多运行状态
public class State {
    public var eventLoop: MiniEventLoop
    public var env: DotEnvLoader
    public var shellBin: String
    public var remainingScripts: Int64
    public var exitCode: Int64
    public var noExitOnError: Bool
    public var prefixOutput: Bool
    public var handles: ArrayList<ProcessHandle>
    public var aborted: Bool

    public init(eventLoop: MiniEventLoop, env: DotEnvLoader, shellBin: String) {
        this.eventLoop = eventLoop
        this.env = env
        this.shellBin = shellBin
        this.remainingScripts = 0
        this.exitCode = 0
        this.noExitOnError = false
        this.prefixOutput = true
        this.handles = ArrayList<ProcessHandle>()
        this.aborted = false
    }

    /// 读取数据块
    public func readChunk(reader: RunPipeReader, chunk: Array<UInt8>): Unit {
        // TODO: implement with Output.errorWriter/stdoutWriter
    }

    /// 中止所有
    public func abort(): Unit {
        this.aborted = true
        // TODO: kill spawned processes
    }

    /// 等待所有完成
    public func wait(): Unit {
        // TODO: implement with eventLoop.tick()
    }
}

// ============================================================================
// MultiRun — 多脚本并行执行入口
// ============================================================================

/// 多脚本并行执行
public class MultiRun {
    /// 执行多个脚本
    public static func run(
        eventLoop: MiniEventLoop,
        env: DotEnvLoader,
        configs: Array<ScriptConfig>,
        noExitOnError: Bool,
        prefixOutput: Bool
    ): Int64 {
        let state = State(eventLoop, env, "/bin/sh")  // TODO: DetectShell.detect()
        state.noExitOnError = noExitOnError
        state.prefixOutput = prefixOutput

        // 为每个配置创建句柄
        for (i in 0..configs.size) {
            let handle = ProcessHandle(configs[i], state, Int64(i) % 6)
            state.handles.append(handle)
        }

        // 启动没有依赖的脚本
        for (handle in state.handles) {
            if (handle.remainingDependencies == 0) {
                handle.start()
            }
        }

        // 等待所有完成
        state.wait()

        // 关闭句柄
        for (handle in state.handles) {
            handle.close()
        }

        return state.exitCode
    }
}

/// 颜色列表
let COLORS: Array<String> = ["", "", "", "", "", ""]
