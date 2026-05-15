// 严格翻译自: src/cli/test/parallel/Worker.zig
package bao_cli.test.parallel

import bao_core.*

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
    public var process: ?Process

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
        process = None
        ipc = Channel()
        stdoutReader = WorkerPipe(this, false)
        stderrReader = WorkerPipe(this, true)
        inflight = None
        range = FileRange()
        dispatchedAt = 0
        captured = ArrayList<Byte>()
        alive = false
        exitStatus = None
    }

    /// 启动 worker 进程
    /// 对应 Bun: Worker.start()
    public func start(): Unit {
        let coord_ = coord

        let options = SpawnOptions()
        options.stdin = StdioKind.ignore
        options.stdout = StdioKind.buffer
        options.stderr = StdioKind.buffer
        options.extraFds = [StdioKind.buffer]
        options.cwd = coord_.cwd
        options.stream = true
        options.newProcessGroup = true

        let spawned = Sys.spawnProcess(options, coord_.argv, coord_.envps[idx.toInt()])
        process = spawned.toProcess(coord_.vm.eventLoop(), false)

        if (spawned.stdout != None) {
            stdoutReader.start(spawned.stdout!!)
        }
        if (spawned.stderr != None) {
            stderrReader.start(spawned.stderr!!)
        }

        if (spawned.extraPipes.length > 0) {
            if (!ipc.adopt(coord_.vm, spawned.extraPipes[0].fd())) {
                ipc.done = true
            }
        } else {
            ipc.done = true
        }

        alive = true
        coord_.liveWorkers += 1
        process!!.setExitHandler(this)
        process!!.watchOrReap()
    }

    /// 进程退出回调
    /// 对应 Bun: Worker.onProcessExit()
    public func onProcessExit(proc: Process, status: ProcessStatus): Unit {
        alive = false
        coord.onWorkerExit(this, status)
    }

    /// 获取事件循环
    public func eventLoop(): EventLoop {
        return coord.vm.eventLoop()
    }

    /// 分发文件给 worker
    /// 对应 Bun: Worker.dispatch()
    public func dispatch(fileIdx: Int64, file: String): Unit {
        let f = coord.frame
        f.begin(FrameKind.run)
        f.u32_(fileIdx)
        f.str(file)
        ipc.send(f.finish())
        inflight = fileIdx
        dispatchedAt = Sys.milliTimestamp()
    }

    /// 关闭 worker
    /// 对应 Bun: Worker.shutdown()
    public func shutdown(): Unit {
        let f = coord.frame
        f.begin(FrameKind.shutdown)
        ipc.send(f.finish())
    }

    /// IPC 帧回调: 解码的帧到达
    /// 对应 Bun: Worker.onChannelFrame()
    public func onChannelFrame(kind: FrameKind, rd: FrameReader): Unit {
        coord.onFrame(this, kind, rd)
    }

    /// IPC 完成回调: peer 关闭或发送了损坏帧
    /// 对应 Bun: Worker.onChannelDone()
    public func onChannelDone(): Unit {
        if (ipc.backend.socket != None) {
            // 损坏帧路径: 杀死 worker
            if (process != None) {
                process!!.kill(9)
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
public class WorkerPipe {
    /// 所属 worker
    public var worker: Worker

    /// 是否为 stderr
    public var isStderr: Bool

    /// 缓冲读取器
    public var reader: BufferedReader

    /// 是否完成
    public var done: Bool

    public init(worker: Worker, isStderr: Bool) {
        this.worker = worker
        this.isStderr = isStderr
        this.reader = BufferedReader()
        this.done = false
    }

    /// 启动读取
    public func start(fd: FileDescriptor): Unit {
        reader.start(fd)
    }

    /// 读取块回调
    /// 对应 Bun: WorkerPipe.onReadChunk()
    public func onReadChunk(chunk: Array<Byte>): Bool {
        for (b in chunk) {
            worker.captured.append(b)
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

    /// 获取事件循环
    public func eventLoop(): EventLoop {
        return worker.coord.vm.eventLoop()
    }

    /// 释放资源
    public func deinit(): Unit {
        reader.deinit()
    }
}
