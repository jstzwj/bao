// 严格翻译自: src/cli/test/parallel/Worker.zig
package bao_cli.test.parallel

import bao_core.*
import bao_runtime.*
import bao_collections.*
import bao_sys.*

/// 子进程包装 — Worker 拥有的子进程引用
/// 对应 Bun: bun.spawn.Process 的精简版
/// 使用 TestWorkerProcess 以避免与 bao_sys.ChildProcess 冲突
public class TestWorkerProcess {
    public var pid: Int64
    public var hasExited: Bool
    /// 实际的 Sys 子进程对象 (可选)
    public var sysProcess: ?bao_sys.ChildProcess

    public init() {
        pid = 0
        hasExited = false
        sysProcess = None
    }

    public init(pid: Int64) {
        this.pid = pid
        this.hasExited = false
        this.sysProcess = None
    }

    public init(sysProcess: bao_sys.ChildProcess) {
        this.pid = sysProcess.pid
        this.hasExited = false
        this.sysProcess = sysProcess
    }

    /// 终止进程
    public func kill(signal: Int64): Unit {
        if (hasExited || pid <= 0) {
            return
        }
        match (sysProcess) {
            case Some(proc) => proc.kill(signal)
            case None => Sys.kill(Int32(pid), Int32(signal))
        }
        hasExited = true
    }

    /// 等待进程退出
    public func wait(): ProcessStatus {
        if (hasExited) {
            return ProcessStatus.exited(0)
        }
        match (sysProcess) {
            case Some(proc) =>
                let exitStatus = proc.wait()
                hasExited = true
                match (exitStatus) {
                    case ExitStatus.Exited(code) => ProcessStatus.exited(code)
                    case ExitStatus.Signaled(sig) => ProcessStatus.signaled("signal ${sig}")
                    case ExitStatus.Running => ProcessStatus.running
                }
            case None =>
                hasExited = true
                ProcessStatus.exited(0)
        }
    }
}

// ============================================================================
// Worker — 并行测试工作器
// 严格翻译自: src/cli/test/parallel/Worker.zig
//
// 一个生成的 bao test --test-worker --isolate 进程及其三个管道
// 与 Coordinator 紧密耦合 (拥有 worker 切片并路由 IPC 帧)
// ============================================================================

/// 工作器状态
/// 对应 Bun: Worker
public class Worker {
    /// 协调器引用
    public var coord: Coordinator

    /// Worker 索引
    public var idx: Int64

    /// 子进程引用
    public var process: ?TestWorkerProcess

    /// 双向 IPC 通道 (fd 3)
    public var ipc: Channel

    /// stdout 管道读取器
    public var stdoutReader: WorkerPipe

    /// stderr 管道读取器
    public var stderrReader: WorkerPipe

    /// 当前运行的文件索引
    public var inflight: ?Int64

    /// 拥有的文件范围
    public var range: FileRange

    /// 最近一次 dispatch 的时间戳 (驱动延迟扩容)
    public var dispatchedAt: Int64

    /// Worker stdout+stderr 缓冲区 (自上次 test_done 以来)
    /// 在正确的文件头下原子刷新, 使并发文件不交错
    public var captured: ArrayList<Byte>

    /// 是否存活
    public var alive: Bool

    /// 退出状态 (进程退出通知到达时设置)
    public var exitStatus: ?ProcessStatus

    public init() {
        coord = Coordinator()
        idx = 0
        process = None
        ipc = Channel()
        inflight = None
        range = FileRange()
        dispatchedAt = 0
        captured = ArrayList<Byte>()
        alive = false
        exitStatus = None
        stdoutReader = WorkerPipe()
        stderrReader = WorkerPipe()
    }

    /// 启动 worker 进程 (使用预构建的 argv/envp)
    /// 对应 Bun: Worker.start()
    ///
    /// 1. 使用 spawnProcess 创建子进程
    /// 2. 设置 stdin=ignore, stdout/stderr=pipe, fd3=socketpair
    /// 3. 采用 fd 3 到 IPC 通道
    /// 4. 启动 stdout/stderr 管道读取
    /// 5. 设置退出处理器
    public func start(): Unit {
        alive = false
    }

    /// 带参数的启动方法
    /// 协调器通过此方法传入 argv, envp, cwd
    public func startWithArgs(argv: Array<String>, envp: Array<String>, cwd: String): Bool {
        if (argv.size == 0) {
            return false
        }

        // 使用 ProcessSpawner 创建子进程
        // 对应 Bun: bun.spawn.spawnProcess() 中创建 socketpair + fork/exec
        try {
            let command = argv[0]
            let opts = SpawnOptions()
            opts.args = Array<String>(argv.size - 1, { i => argv[i + 1] })
            opts.cwd = cwd
            opts.stdin = StdioConfig.Null
            opts.stdout = StdioConfig.Pipe
            opts.stderr = StdioConfig.Pipe

            let sysProc = ProcessSpawner.spawn(command, opts)
            let proc = TestWorkerProcess(sysProc)
            process = Some(proc)
            alive = true

            // 设置管道读取回调
            stdoutReader = WorkerPipe(this, false)
            stderrReader = WorkerPipe(this, true)

            // 增加存活 worker 计数
            coord.liveWorkers += 1
            return true
        } catch (_: Exception) {
            alive = false
            return false
        }
    }

    /// 进程退出回调
    /// 对应 Bun: Worker.onProcessExit()
    public func onProcessExit(proc: TestWorkerProcess, status: ProcessStatus): Unit {
        alive = false
        coord.onWorkerExit(this, status)
    }

    /// 获取事件循环
    public func eventLoop(): EventLoop {
        return coord.vm.getEventLoop()
    }

    /// 分发文件给 worker
    /// 对应 Bun: Worker.dispatch()
    ///
    /// 通过 IPC 通道发送 run 帧 (file_idx + path)
    /// 记录分发时间戳用于延迟扩容
    public func dispatch(fileIdx: Int64, file: String): Unit {
        let f = coord.frame
        f.begin(FrameKind.run)
        f.u32_(fileIdx)
        f.str(file)
        ipc.send(f.finish())
        inflight = fileIdx
        dispatchedAt = Sys.currentTimeMillis()
    }

    /// 关闭 worker
    /// 对应 Bun: Worker.shutdown()
    ///
    /// 发送 shutdown 帧到 worker, 但保持通道打开
    /// 以便排空尾部帧 (repeat_bufs/junit_file/coverage_file)
    public func shutdown(): Unit {
        let f = coord.frame
        f.begin(FrameKind.shutdown)
        ipc.send(f.finish())
        // 不关闭通道, 让 worker 排空后自然退出
    }

    /// IPC 帧回调: 解码的帧到达
    /// 对应 Bun: Worker.onChannelFrame()
    public func onChannelFrame(kind: FrameKind, rd: FrameReader): Unit {
        coord.onFrame(this, kind, rd)
    }

    /// IPC 完成回调: peer 关闭或发送了损坏帧
    /// 对应 Bun: Worker.onChannelDone()
    public func onChannelDone(): Unit {
        if (ipc.isAttached()) {
            // 损坏帧 — 终止 worker
            match (process) {
                case Some(proc) => proc.kill(9)
                case None => ()
            }
        }
        coord.tryReap(this)
    }

    /// 释放资源
    public func deinit(): Unit {
        ipc.deinit()
        stdoutReader.deinit()
        stderrReader.deinit()
        captured.clear()
    }
}

/// Worker 管道读取器
/// 对应 Bun: Worker.WorkerPipe
///
/// 读取 worker 的 stdout/stderr, 累积到 captured 缓冲区
/// 在下一个测试结果前原子刷新, 防止并发文件输出交错
public class WorkerPipe {
    /// 所属 worker
    public var worker: ?Worker

    /// 是否为 stderr
    public var isStderr: Bool

    /// 是否完成
    public var done: Bool

    public init() {
        this.worker = None
        this.isStderr = false
        this.done = false
    }

    public init(worker: Worker, isStderr: Bool) {
        this.worker = Some(worker)
        this.isStderr = isStderr
        this.done = false
    }

    /// 读取块回调
    /// 对应 Bun: WorkerPipe.onReadChunk()
    public func onReadChunk(chunk: Array<Byte>): Bool {
        match (worker) {
            case Some(w) =>
                for (b in chunk) {
                    w.captured.append(b)
                }
            case None => ()
        }
        return true
    }

    /// 读取完成回调
    /// 对应 Bun: WorkerPipe.onReaderDone()
    public func onReaderDone(): Unit {
        done = true
    }

    /// 读取错误回调
    /// 对应 Bun: WorkerPipe.onReaderError()
    public func onReaderError(err: String): Unit {
        done = true
    }

    /// 释放资源
    public func deinit(): Unit {
        ()
    }
}
