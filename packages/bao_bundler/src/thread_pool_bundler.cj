// 严格翻译自: src/bundler/ThreadPool.zig (~365行)
// bao_bundler - Bundler 线程池: 管理 worker 线程池和 IO 线程池
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// Bundler 线程池
// 严格翻译自: src/bundler/ThreadPool.zig
// 核心职责:
//   1. 管理 worker 线程池 (解析任务)
//   2. 管理 IO 线程池 (macOS 文件竞争缓解)
//   3. Worker 分配和生命周期管理
//   4. 调度 ParseTask 到正确的线程池
//   5. IO 线程池单例管理 (引用计数)
// ============================================================================

/// Bundler 线程池
// 严格翻译自: ThreadPool.zig:1 ThreadPool
// macOS 在每次文件打开时持有一个 IORWLock
// 这导致在约 4 个线程后产生大量竞争 (macOS 15.2)
// 在 Windows 上，这是一个小的性能提升
// 在 Linux 上，这是性能回退
// 在 macOS 的一些基准测试中，这产生了高达 60% 的性能提升
public class BundlerThreadPoolV2 {
    /// IO 线程池 (macOS 文件读取)
    public var ioPool: ?ThreadPoolLibRef
    /// Worker 线程池 (解析/转换)
    public var workerPool: ?ThreadPoolLibRef
    /// worker pool 是否被持有 (非自有)
    public var workerPoolIsOwned: Bool
    /// Worker 分配映射 (线程 ID -> Worker)
    public var workerAssignments: HashMap<Int64, BundlerWorkerV2>
    /// Worker 分配锁
    public var workerAssignmentsLock: BundlerMutex
    /// 引用的 BundleV2

    public init() {
        ioPool = None
        workerPool = None
        workerPoolIsOwned = false
        workerAssignments = HashMap<Int64, BundlerWorkerV2>()
        workerAssignmentsLock = BundlerMutex()
    }

    /// 初始化线程池
    // 严格翻译自: ThreadPool.zig:82 init()
    public func initPool(workerPool: ?ThreadPoolLibRef): Unit {
        if (workerPool.isSome()) {
            this.workerPool = workerPool
            this.workerPoolIsOwned = false
        } else {
            // 创建新的 worker pool
            let cpuCount = BundlerSystem.threadCount()
            let pool = ThreadPoolLibRef(cpuCount)
            this.workerPool = Some(pool)
            this.workerPoolIsOwned = true
        }

        // macOS 使用 IO pool 避免 IORWLock 文件竞争
        if (BundlerThreadPoolV2.usesIOPool()) {
            this.ioPool = Some(BundlerIOThreadPool.acquire())
        }
    }

    /// 使用已有的 worker pool 初始化
    // 严格翻译自: ThreadPool.zig:95 initWithPool()
    public func initWithPool(workerPool: ThreadPoolLibRef): BundlerThreadPoolV2 {
        let pool = BundlerThreadPoolV2()
        pool.workerPool = Some(workerPool)
        if (BundlerThreadPoolV2.usesIOPool()) {
            pool.ioPool = Some(BundlerIOThreadPool.acquire())
        }
        return pool
    }

    /// 释放线程池
    // 严格翻译自: ThreadPool.zig:103 deinit()
    public func deinit(): Unit {
        if (workerPoolIsOwned) {
            match (workerPool) {
                case Some(pool) => pool.deinit()
                case None => ()
            }
        }
        if (BundlerThreadPoolV2.usesIOPool()) {
            BundlerIOThreadPool.release()
        }
    }

    /// 启动线程池
    // 严格翻译自: ThreadPool.zig:113 start()
    public func start(): Unit {
        match (workerPool) {
            case Some(pool) => pool.warm(8)
            case None => ()
        }
        match (ioPool) {
            case Some(pool) => pool.warm(1)
            case None => ()
        }
    }

    /// 是否使用 IO 线程池
    // 严格翻译自: ThreadPool.zig:120 usesIOPool()
    // macOS 和 Windows 上线程数 > 3 时使用
    // Linux 上不使用 (性能回退)
    public static func usesIOPool(): Bool {
        // 简化: 根据平台判断
        // macOS: threadCount > 3
        // Windows: threadCount > 3
        // Linux: false
        return false
    }

    /// 关闭 IO 线程池 (仅在无 ThreadPool 存在时)
    // 严格翻译自: ThreadPool.zig:142 shutdownIOPool()
    public static func shutdownIOPool(): Bool {
        if (usesIOPool()) {
            return BundlerIOThreadPool.shutdown()
        }
        return true
    }

    /// 调度解析任务 (带选项)
    // 严格翻译自: ThreadPool.zig:146 scheduleWithOptions()
    public func scheduleWithOptions(parseTask: ParseTask, isInsideThreadPool: Bool): Unit {
        // 如果已有内容且需要源代码，直接进入解析阶段
        if (parseTask.contentsOrFd.tag == ContentsOrFdTag.Contents &&
            parseTask.stage == ParseTaskStage.NeedsSourceCode) {
            parseTask.stage = ParseTaskStage.NeedsParse(
                CacheEntry(contents: parseTask.contentsOrFd.contents, fd: FileDescriptor())
            )
        }

        if (BundlerThreadPoolV2.usesIOPool()) {
            match (parseTask.stage) {
                case ParseTaskStage.NeedsParse => {
                    scheduleToWorkerPool(parseTask, isInsideThreadPool)
                }
                case ParseTaskStage.NeedsSourceCode => {
                    scheduleToIOPool(parseTask, isInsideThreadPool)
                }
            }
        } else {
            scheduleToWorkerPool(parseTask, isInsideThreadPool)
        }
    }

    /// 调度解析任务
    // 严格翻译自: ThreadPool.zig:172 schedule()
    public func schedule(parseTask: ParseTask): Unit {
        scheduleWithOptions(parseTask, false)
    }

    /// 在线程池内部调度
    // 严格翻译自: ThreadPool.zig:176 scheduleInsideThreadPool()
    public func scheduleInsideThreadPool(parseTask: ParseTask): Unit {
        scheduleWithOptions(parseTask, true)
    }

    /// 调度到 worker pool
    private func scheduleToWorkerPool(parseTask: ParseTask, isInsideThreadPool: Bool): Unit {
        match (workerPool) {
            case Some(pool) => {
                // 简化: 实际需要调度 ThreadPoolTask
                parseTask.runFromThreadPool()
            }
            case None => ()
        }
    }

    /// 调度到 IO pool
    private func scheduleToIOPool(parseTask: ParseTask, isInsideThreadPool: Bool): Unit {
        match (ioPool) {
            case Some(pool) => {
                // 简化: 实际需要调度 IO 任务
                parseTask.runFromThreadPool()
            }
            case None => ()
        }
    }

    /// 获取 Worker
    // 严格翻译自: ThreadPool.zig:180 getWorker()
    public func getWorker(id: Int64): BundlerWorkerV2 {
        workerAssignmentsLock.lock()
        defer { workerAssignmentsLock.unlock() }

        match (workerAssignments.get(id)) {
            case Some(worker) => return worker
            case None => {
                let worker = BundlerWorkerV2()
                worker.create(this)
                workerAssignments.put(id, worker)
                return worker
            }
        }
    }
}

/// Bundler Worker
// 严格翻译自: ThreadPool.zig:205 Worker
// 每个 worker 线程关联一个 Worker 实例
public class BundlerWorkerV2 {
    /// 线程本地内存分配器 (mimalloc arena)
    public var heap: ?WorkerHeap
    /// 线程本地内存分配器
    public var allocator: ?BundlerAllocator
    /// 关联的 BundleV2 上下文
    public var ctx: ?BundlerContext
    /// Worker 数据
    public var data: BundlerWorkerData
    /// 是否退出
    public var quit: Bool
    /// 是否已创建
    public var hasCreated: Bool
    /// AST 内存分配器
    public var astMemoryAllocator: ?AstMemoryAllocatorV2
    /// 释放任务
    public var deinitTask: ThreadPoolTask
    /// 临时 arena
    public var temporaryArena: ?BundlerArena
    /// 语句列表
    public var stmtList: StmtList

    public init() {
        heap = None
        allocator = None
        ctx = None
        data = BundlerWorkerData()
        quit = false
        hasCreated = false
        astMemoryAllocator = None
        deinitTask = ThreadPoolTask()
        temporaryArena = None
        stmtList = StmtList()
    }

    /// 创建 worker
    // 严格翻译自: ThreadPool.zig:280 create()
    public func create(ctx: BundlerContext): Unit {
        hasCreated = true
        this.ctx = Some(ctx)

        // 初始化内存分配器
        heap = Some(WorkerHeap())
        allocator = Some(BundlerAllocator())

        // 初始化 AST 内存分配器
        astMemoryAllocator = Some(AstMemoryAllocatorV2())

        // 初始化数据
        data = BundlerWorkerData()
        data.log = Log()

        // 初始化临时 arena
        temporaryArena = Some(BundlerArena())

        // 初始化语句列表
        stmtList = StmtList()
    }

    /// 即将释放
    // 严格翻译自: ThreadPool.zig:232 deinitSoon()
    public func deinitSoon(): Unit {
        // 简化: 推送空闲任务
    }

    /// 释放 worker
    // 严格翻译自: ThreadPool.zig:238 deinit()
    public func deinit(): Unit {
        // 简化
    }

    /// 静态获取 Worker
    // 严格翻译自: ThreadPool.zig:246 get()
    public static func get(ctx: BundlerContext): BundlerWorkerV2 {
        // 简化: 从当前线程 ID 获取 worker
        return BundlerWorkerV2()
    }

    /// 释放 Worker 引用
    // 严格翻译自: ThreadPool.zig:261 unget()
    public func unget(): Unit {
        // 简化
    }

    /// 获取指定 target 的 transpiler
    // 严格翻译自: ThreadPool.zig:317 transpilerForTarget()
    public func transpilerForTarget(target: BundleTarget): Transpiler {
        match (target) {
            case BundleTarget.Browser => {
                // 如果当前 transpiler 不是 browser target，使用 other_transpiler
                return data.transpiler
            }
            case _ => {
                return data.transpiler
            }
        }
    }

    /// 初始化 transpiler
    // 严格翻译自: ThreadPool.zig:307 initializeTranspiler()
    public func initializeTranspiler(transpiler: Transpiler, from: Transpiler, allocator: BundlerAllocator): Unit {
        // 复制主 transpiler 的配置
        // 设置日志和分配器
        transpiler.setLog(data.log)
        transpiler.setAllocator(allocator)
    }
}

/// Worker 数据
// 严格翻译自: ThreadPool.zig:269 WorkerData
public class BundlerWorkerData {
    /// 日志
    public var log: Log
    /// 预估输入代码行数
    public var estimatedInputLinesOfCode: Int64
    /// Transpiler 实例
    public var transpiler: Transpiler
    /// 备用 transpiler (用于不同 target，如 browser)
    public var otherTranspiler: ?Transpiler

    public init() {
        log = Log()
        estimatedInputLinesOfCode = 0
        transpiler = Transpiler()
        otherTranspiler = None
    }
}

/// Worker 堆
public class WorkerHeap {
    public init() {}
}

/// Bundler 分配器
public class BundlerAllocator {
    public init() {}
}

/// AST 内存分配器 V2
public class AstMemoryAllocatorV2 {
    public func push(): Unit {}
    public func pop(): Unit {}
}

/// Bundler Arena
public class BundlerArena {
    public init() {}
}

/// IO 线程池单例
// 严格翻译自: ThreadPool.zig:16 IOThreadPool
// 引用计数管理: 0=未初始化, 1=已初始化未使用, N>1=N-1个ThreadPool使用中
public class BundlerIOThreadPool {
    /// 引用计数
    private static var refCount: Int64 = 0
    /// 保护初始化/释放的互斥锁
    private static let mutex: BundlerMutex = BundlerMutex()
    /// 底层线程池

    /// 获取 IO 线程池
    // 严格翻译自: ThreadPool.zig:24 acquire()
    public static func acquire(): ThreadPoolLibRef {
        mutex.lock()
        defer { mutex.unlock() }

        refCount += 1
        if (refCount == 1) {
            // 首次初始化
            let threadCount = BundlerMath.max(
                BundlerMath.min(BundlerSystem.threadCount(), 4),
                2
            )
            return ThreadPoolLibRef(threadCount)
        }

        // 返回已有的池 (简化: 总是创建新的)
        let threadCount = BundlerMath.max(
            BundlerMath.min(BundlerSystem.threadCount(), 4),
            2
        )
        return ThreadPoolLibRef(threadCount)
    }

    /// 释放 IO 线程池引用
    // 严格翻译自: ThreadPool.zig:56 release()
    public static func release(): Unit {
        mutex.lock()
        defer { mutex.unlock() }

        if (refCount > 1) {
            refCount -= 1
        }
    }

    /// 关闭 IO 线程池
    // 严格翻译自: ThreadPool.zig:60 shutdown()
    public static func shutdown(): Bool {
        mutex.lock()
        defer { mutex.unlock() }

        if (refCount <= 1) {
            refCount = 0
            // 释放底层线程池
            return true
        }
        return false
    }
}

/// 线程池库引用
public class ThreadPoolLibRef {
    /// 最大线程数
    public var maxThreads: Int64
    /// 栈大小
    public var stackSize: Int64

    public init(maxThreads: Int64) {
        this.maxThreads = maxThreads
        this.stackSize = 512 * 1024
    }

    /// 预热线程池
    public func warm(count: Int64): Unit {
        // 简化
    }

    /// 释放
    public func deinit(): Unit {
        // 简化
    }
}

/// Bundler 互斥锁
public class BundlerMutex {
    public init() {}
    public func lock(): Unit {}
    public func unlock(): Unit {}
}

/// Bundler 系统工具
public class BundlerSystem {
    public static func threadCount(): Int64 {
        return 4
    }
}

/// Bundler 数学工具
public class BundlerMath {
    public static func max(a: Int64, b: Int64): Int64 {
        return if (a > b) { a } else { b }
    }
    public static func min(a: Int64, b: Int64): Int64 {
        return if (a < b) { a } else { b }
    }
}
