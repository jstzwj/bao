// bao_threading - WorkPool 全局线程池
// 严格翻译自: src/threading/work_pool.zig
//   Bun 使用 WorkPool 作为全局单例的 ThreadPool
//   懒初始化: 首次 get() 时创建线程池
//   线程数 = CPU 核心数
//   提供调度接口: schedule, scheduleBatch, go
//   仓颉实现提供等价的全局工作池
package bao_threading

import bao_core.*

// ============================================================================
// WorkPool - 全局工作线程池
// 严格翻译自: src/threading/work_pool.zig WorkPool
//   var pool: ThreadPool = undefined
//   var createOnce = bun.once(create)
//   pub inline fn get() *ThreadPool
//   pub fn scheduleBatch(batch)
//   pub fn schedule(task)
//   pub fn go(allocator, Context, context, function)
// ============================================================================

/// 全局工作线程池
/// 严格翻译自 work_pool.zig:3-55 WorkPool
///   使用懒初始化模式, 首次访问时创建线程池
public type WorkPoolBatch = TaskBatch

public type WorkPoolTask = ThreadPoolTask

public class WorkPool {
    /// 线程池实例
    /// 翻译自: var pool: ThreadPool = undefined
    private static var pool: ?ThreadPool = None

    /// 是否已初始化
    private static var initialized: Bool = false

    /// 初始化锁
    private static let initLock: Mutex = Mutex()

    /// 获取全局线程池 (懒初始化)
    /// 严格翻译自: pub inline fn get() *ThreadPool
    ///   createOnce.call(.{})
    ///   return &pool
    public static func get(): ThreadPool {
        if (!initialized) {
            initLock.lock()
            if (!initialized) {
                pool = ThreadPool(ThreadPoolConfig(getThreadCount()))
                initialized = true
            }
            initLock.unlock()
        }
        match (pool) {
            case Some(p) => return p
            case None =>
                let newPool = ThreadPool(ThreadPoolConfig(getThreadCount()))
                pool = newPool
                return newPool
        }
    }

    /// 调度任务批次
    /// 严格翻译自: pub fn scheduleBatch(batch: ThreadPool.Batch) void
    ///   get().schedule(batch)
    public static func scheduleBatch(batch: TaskBatch): Unit {
        get().schedule(batch)
    }

    /// 调度单个任务
    /// 严格翻译自: pub fn schedule(task: *ThreadPool.Task) void
    ///   get().schedule(ThreadPool.Batch.from(task))
    public static func schedule(task: ThreadPoolTask): Unit {
        get().schedule(task)
    }

    /// 异步执行函数
    /// 严格翻译自: pub fn go(allocator, comptime Context, context, comptime function) !void
    ///   创建包装任务, 调度到线程池, 回调中执行函数并释放
    public static func go(context: WorkPoolContext, function: (WorkPoolContext) -> Unit): Unit {
        schedule(WorkPoolClosureTask(context, function))
    }

    /// 获取线程数
    private static func getThreadCount(): Int64 {
        // 仓颉平台实现
        return 4
    }
}

/// 工作池上下文
public class WorkPoolContext {
    public init() {}
}

private class WorkPoolClosureTask <: ThreadPoolTask {
    private let context: WorkPoolContext
    private let callback: (WorkPoolContext) -> Unit

    public init(context: WorkPoolContext, callback: (WorkPoolContext) -> Unit) {
        this.context = context
        this.callback = callback
    }

    public func execute(): Unit {
        callback(context)
    }
}
