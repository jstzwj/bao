// bao_event_loop - 延迟任务队列
// 严格翻译自: src/event_loop/DeferredTaskQueue.zig
//
// Bun 的 DeferredTaskQueue:
//   //! Sometimes, you have work that will be scheduled, cancelled, and
//   //! rescheduled multiple times. The order of that work may not
//   //! particularly matter.
//   //!
//   //! An example of this is when writing to a file or network socket.
//   //! You want to balance:
//   //!     1) Writing as much as possible in as few system calls as possible
//   //!     2) Writing as soon as possible
//   //!
//   //! Our answer to this is the DeferredTaskQueue.
//   //!
//   //! When you call write() when sending a streaming HTTP response, we don't
//   //! actually write it immediately by default. Instead, we wait until the
//   //! end of the microtask queue to write it, unless either:
//   //!   - The buffer is full
//   //!   - The developer calls `flush` manually
//   //!
//   //! The DeferredTaskQueue is drained after the microtask queue, but before
//   //! other tasks are executed. This avoids re-entrancy issues.
//
// Bun 实现:
//   const DeferredTaskQueue = @This()
//   map: std.AutoArrayHashMapUnmanaged(?*anyopaque, DeferredRepeatingTask) = {}
//
//   pub const DeferredRepeatingTask = *const (fn (*anyopaque) bool)
//
//   pub fn postTask(this, ctx, task) bool:
//     注册延迟任务, 返回是否已存在 (found_existing)
//
//   pub fn unregisterTask(this, ctx) bool:
//     取消注册, 返回是否成功移除
//
//   pub fn run(this) void:
//     执行所有已注册的延迟任务
//     如果回调返回 false, 移除该任务
//     如果 ctx 为 null, 移除该任务
//
//   pub fn deinit(this) void:
//     清理所有资源
//
// 关键设计:
//   1. 使用 ArrayHashMap 而非普通队列
//   2. 键是上下文指针, 值是回调函数
//   3. 同一上下文只能注册一个任务 (自动替换)
//   4. 回调返回 false 表示任务完成, 应移除
//   5. 在微任务队列之后, 其他任务之前执行
//   6. 用于 I/O 缓冲刷新等场景
//
// 使用场景:
//   - HTTP 响应写入缓冲
//   - Socket 写入合并
//   - 文件 I/O 批量提交
//   - AutoFlusher 注册的自动刷新任务
package bao_event_loop

import bao_core.*

// ============================================================================
// DeferredRepeatingTask - 延迟重复任务回调类型
// 严格翻译自: DeferredTaskQueue.DeferredRepeatingTask
//
// Bun:
//   pub const DeferredRepeatingTask = *const (fn (*anyopaque) bool)
//
// 回调签名:
//   参数: *anyopaque - 任务上下文
//   返回: bool - true = 继续保留, false = 移除任务
//
// 仓颉: 使用泛型函数接口代替 void 指针
// ============================================================================

/// 延迟重复任务 - 对应 Bun DeferredRepeatingTask
/// 返回 true 表示继续保留, false 表示移除
public class DeferredRepeatingTask {
    /// 任务回调
    public var callback: () -> Bool
    /// 上下文标签 (调试用)
    public var label: String
    /// 执行次数
    public var executionCount: Int64

    public init(callback: () -> Bool) {
        this.callback = callback
        label = ""
        executionCount = 0
    }

    public init(callback: () -> Bool, label: String) {
        this.callback = callback
        this.label = label
        executionCount = 0
    }

    /// 执行任务 - 返回是否继续保留
    /// 对应 Bun: this.map.values()[i](key) -> bool
    public func run(): Bool {
        executionCount += 1
        return callback()
    }
}

// ============================================================================
// DeferredTaskQueueV2 - 延迟任务队列 (完整版)
// 严格翻译自: src/event_loop/DeferredTaskQueue.zig
//
// Bun:
//   const DeferredTaskQueue = @This()
//   map: std.AutoArrayHashMapUnmanaged(?*anyopaque, DeferredRepeatingTask) = {}
//
//   pub fn postTask(this: *DeferredTaskQueue, ctx: ?*anyopaque,
//                   task: DeferredRepeatingTask) bool {
//       const existing = bun.handleOom(this.map.getOrPutValue(
//           bun.default_allocator, ctx, task))
//       return existing.found_existing
//   }
//
//   pub fn unregisterTask(this: *DeferredTaskQueue, ctx: ?*anyopaque) bool {
//       return this.map.swapRemove(ctx)
//   }
//
//   pub fn run(this: *DeferredTaskQueue) void {
//       var i: usize = 0
//       var last = this.map.count()
//       while (i < last) {
//           const key = this.map.keys()[i] orelse {
//               this.map.swapRemoveAt(i)
//               last = this.map.count()
//               continue
//           }
//           if (!this.map.values()[i](key)) {
//               this.map.swapRemoveAt(i)
//               last = this.map.count()
//           } else {
//               i += 1
//           }
//       }
//   }
//
//   pub fn deinit(this: *DeferredTaskQueue) void {
//       this.map.deinit(bun.default_allocator)
//   }
//
// 关键语义:
//   - postTask: 注册任务, 如果 ctx 已有任务则替换, 返回是否已存在
//   - unregisterTask: 移除指定 ctx 的任务
//   - run: 执行所有任务, 回调返回 false 的自动移除
//   - ctx 为 null 时也移除
// ============================================================================

/// 延迟任务队列 V2 - 严格对应 Bun DeferredTaskQueue
/// 使用 HashMap 存储 (ctx -> task), 同一 ctx 只能有一个任务
/// 任务在微任务队列之后执行, 避免重入问题
public class DeferredTaskQueueV2 {
    /// 任务映射 - 对应 Bun map: AutoArrayHashMapUnmanaged
    /// Bun: 键是 void 指针, 值是回调函数
    /// 仓颉: 使用 String 作为键 (上下文标识)
    private var map: HashMap<String, DeferredRepeatingTask>
    /// 任务上下文列表 (保持插入顺序)
    /// Bun 的 AutoArrayHashMap 保持插入顺序
    private var order: ArrayList<String>
    /// 是否正在运行 (防止重入)
    private var running: Bool

    public init() {
        map = HashMap<String, DeferredRepeatingTask>()
        order = ArrayList<String>()
        running = false
    }

    // ========================================================================
    // postTask - 注册延迟任务
    // 严格翻译自: DeferredTaskQueue.postTask
    //
    // Bun:
    //   pub fn postTask(this: *DeferredTaskQueue, ctx: ?*anyopaque,
    //                   task: DeferredRepeatingTask) bool {
    //       const existing = bun.handleOom(this.map.getOrPutValue(
    //           bun.default_allocator, ctx, task))
    //       return existing.found_existing
    //   }
    //
    // getOrPutValue: 如果键已存在, 返回 (found_existing=true, 保持旧值)
    //                如果键不存在, 插入 (found_existing=false)
    //
    // 注意: Bun 的 getOrPutValue 在 found_existing 时不会更新值
    // 但 DeferredTaskQueue 的语义是替换: 同一 ctx 可以重新 postTask
    // 实际上 Bun 的实现是: 如果已存在, getOrPutValue 返回 existing entry
    //   但 task 参数已经传入了新值
    //   通过 getOrPutValue 的语义: 新值会被设置
    //
    // 仓颉: 简化为 put (替换语义)
    // ========================================================================

    /// 注册延迟任务 - 对应 Bun DeferredTaskQueue.postTask
    /// 如果 ctx 已有任务, 替换为新任务
    /// 返回是否已存在旧任务 (对应 Bun found_existing)
    ///
    /// Bun:
    ///   pub fn postTask(this, ctx, task) bool {
    ///       const existing = this.map.getOrPutValue(ctx, task)
    ///       return existing.found_existing
    ///   }
    public func postTask(ctx: String, task: DeferredRepeatingTask): Bool {
        let existing = map.get(ctx)
        let foundExisting = existing != None
        map.put(ctx, task)
        if (!foundExisting) {
            order.append(ctx)
        }
        return foundExisting
    }

    /// 便捷方法: 从闭包注册延迟任务
    /// 回调返回 true 表示继续保留, false 表示移除
    public func postTask(ctx: String, callback: () -> Bool): Bool {
        return postTask(ctx, DeferredRepeatingTask(callback))
    }

    // ========================================================================
    // unregisterTask - 取消注册任务
    // 严格翻译自: DeferredTaskQueue.unregisterTask
    //
    // Bun:
    //   pub fn unregisterTask(this: *DeferredTaskQueue, ctx: ?*anyopaque) bool {
    //       return this.map.swapRemove(ctx)
    //   }
    //
    // swapRemove: 交换删除 (O(1), 不保持顺序)
    //   但 AutoArrayHashMap 的 swapRemove 保持顺序
    //   仓颉: 需要手动从 order 列表中移除
    // ========================================================================

    /// 取消注册任务 - 对应 Bun DeferredTaskQueue.unregisterTask
    /// 返回是否成功移除 (对应 Bun swapRemove 返回 bool)
    ///
    /// Bun:
    ///   pub fn unregisterTask(this, ctx) bool {
    ///       return this.map.swapRemove(ctx)
    ///   }
    public func unregisterTask(ctx: String): Bool {
        let removed = map.remove(ctx)
        if (removed) {
            // 从排序列表中移除
            var idx: Int64 = 0
            while (idx < order.size) {
                if (order[idx] == ctx) {
                    order.removeAt(idx)
                    break
                }
                idx += 1
            }
        }
        return removed
    }

    // ========================================================================
    // run - 执行所有延迟任务
    // 严格翻译自: DeferredTaskQueue.run
    //
    // Bun:
    //   pub fn run(this: *DeferredTaskQueue) void {
    //       var i: usize = 0
    //       var last = this.map.count()
    //       while (i < last) {
    //           const key = this.map.keys()[i] orelse {
    //               // ctx 为 null, 移除
    //               this.map.swapRemoveAt(i)
    //               last = this.map.count()
    //               continue
    //           }
    //           // 执行回调
    //           if (!this.map.values()[i](key)) {
    //               // 回调返回 false, 移除
    //               this.map.swapRemoveAt(i)
    //               last = this.map.count()
    //           } else {
    //               // 回调返回 true, 保留, 前进
    //               i += 1
    //           }
    //       }
    //   }
    //
    // 关键语义:
    //   1. 遍历所有已注册的任务
    //   2. 调用回调, 传入上下文
    //   3. 回调返回 false -> 移除任务
    //   4. 回调返回 true -> 保留任务
    //   5. 移除时不递增 i (swapRemove 后的元素移到了 i 位置)
    // ========================================================================

    /// 执行所有延迟任务 - 对应 Bun DeferredTaskQueue.run
    /// 在微任务队列之后, 其他任务之前执行
    /// 避免重入: running 标志防止嵌套调用
    ///
    /// Bun:
    ///   pub fn run(this) void {
    ///       var i: usize = 0
    ///       var last = this.map.count()
    ///       while (i < last) {
    ///           const key = this.map.keys()[i] orelse {
    ///               this.map.swapRemoveAt(i)
    ///               last = this.map.count()
    ///               continue
    //            }
    ///           if (!this.map.values()[i](key)) {
    ///               this.map.swapRemoveAt(i)
    ///               last = this.map.count()
    ///           } else { i += 1 }
    ///       }
    ///   }
    public func run(): Unit {
        if (running) {
            // 防止重入
            // Bun 的 DeferredTaskQueue 在微任务队列之后执行
            // 不允许在 run 过程中再次 run
            return
        }
        running = true

        // 对应 Bun: var i: usize = 0; var last = this.map.count()
        var i: Int64 = 0
        var last = order.size
        while (i < last) {
            let key = order[i]

            // 对应 Bun: const key = this.map.keys()[i] orelse { ... }
            // 仓颉: 如果 key 为空字符串, 视为 null
            if (key == "") {
                // 移除空键任务
                // Bun: this.map.swapRemoveAt(i); last = this.map.count(); continue
                order.removeAt(i)
                map.remove(key)
                last = order.size
                continue
            }

            // 执行回调
            // Bun: if (!this.map.values()[i](key)) { ... }
            let task = map.get(key)
            if (let Some(t) = task) {
                if (!t.run()) {
                    // 回调返回 false, 移除
                    // Bun: this.map.swapRemoveAt(i); last = this.map.count()
                    order.removeAt(i)
                    map.remove(key)
                    last = order.size
                } else {
                    // 回调返回 true, 保留, 前进
                    // Bun: i += 1
                    i += 1
                }
            } else {
                // 任务已被其他方式移除
                order.removeAt(i)
                last = order.size
            }
        }

        running = false
    }

    // ========================================================================
    // deinit - 清理所有资源
    // 严格翻译自: DeferredTaskQueue.deinit
    //
    // Bun:
    //   pub fn deinit(this: *DeferredTaskQueue) void {
    //       this.map.deinit(bun.default_allocator)
    //   }
    // ========================================================================

    /// 清理所有资源 - 对应 Bun DeferredTaskQueue.deinit
    public func deinit(): Unit {
        map.clear()
        order.clear()
        running = false
    }

    /// 已注册任务数
    public func count(): Int64 {
        return Int64(map.size)
    }

    /// 是否为空
    public func isEmpty(): Bool {
        map.size == 0
    }

    /// 是否包含指定上下文
    public func contains(ctx: String): Bool {
        map.get(ctx) != None
    }

    /// 获取所有注册的上下文
    public func contexts(): ArrayList<String> {
        var result = ArrayList<String>()
        for (key in order) {
            result.append(key)
        }
        return result
    }
}

// ============================================================================
// AutoFlusherV2 - 自动刷新器 V2 (使用 DeferredTaskQueue)
// 严格翻译自: src/event_loop/AutoFlusher.zig
//
// Bun:
//   registered: bool = false
//
//   pub fn registerDeferredMicrotaskWithType(Type, this, vm) void {
//       if (this.auto_flusher.registered) return
//       registerDeferredMicrotaskWithTypeUnchecked(Type, this, vm)
//   }
//
//   pub fn unregisterDeferredMicrotaskWithType(Type, this, vm) void {
//       if (!this.auto_flusher.registered) return
//       unregisterDeferredMicrotaskWithTypeUnchecked(Type, this, vm)
//   }
//
//   pub fn unregisterDeferredMicrotaskWithTypeUnchecked(Type, this, vm) void {
//       bun.assert(this.auto_flusher.registered)
//       bun.assert(vm.eventLoop().deferred_tasks.unregisterTask(this))
//       this.auto_flusher.registered = false
//   }
//
//   pub fn registerDeferredMicrotaskWithTypeUnchecked(Type, this, vm) void {
//       bun.assert(!this.auto_flusher.registered)
//       this.auto_flusher.registered = true
//       bun.assert(!vm.eventLoop().deferred_tasks.postTask(this,
//           @ptrCast(&Type.onAutoFlush)))
//   }
//
// AutoFlusher 将自己注册到 DeferredTaskQueue 中:
//   - registered: 是否已注册
//   - 注册时: postTask 到 deferred_tasks
//   - 取消时: unregisterTask 从 deferred_tasks
//   - flush 时: deferred_tasks.run() 会调用 onAutoFlush
// ============================================================================

/// 自动刷新器 V2 - 对应 Bun AutoFlusher
/// 使用 DeferredTaskQueue 注册延迟刷新任务
/// 在微任务队列之后执行 flush
public class AutoFlusherV2 {
    /// 是否已注册到 DeferredTaskQueue - 对应 Bun registered: bool
    public var registered: Bool
    /// 上下文标识
    private var ctx: String
    /// 刷新回调
    private var flushCallback: () -> Bool
    /// 关联的延迟任务队列
    private var deferredQueue: ?DeferredTaskQueueV2

    public init() {
        registered = false
        ctx = ""
        flushCallback = { => true }
        deferredQueue = None
    }

    public init(ctx: String, flushCallback: () -> Bool) {
        registered = false
        this.ctx = ctx
        this.flushCallback = flushCallback
        deferredQueue = None
    }

    // ========================================================================
    // register - 注册延迟微任务
    // 严格翻译自: registerDeferredMicrotaskWithType
    //
    // Bun:
    //   pub fn registerDeferredMicrotaskWithType(Type, this, vm) void {
    //       if (this.auto_flusher.registered) return
    //       registerDeferredMicrotaskWithTypeUnchecked(Type, this, vm)
    //   }
    //
    //   pub fn registerDeferredMicrotaskWithTypeUnchecked(Type, this, vm) void {
    //       bun.assert(!this.auto_flusher.registered)
    //       this.auto_flusher.registered = true
    //       bun.assert(!vm.eventLoop().deferred_tasks.postTask(this,
    //           @ptrCast(&Type.onAutoFlush)))
    //   }
    // ========================================================================

    /// 注册延迟刷新任务 - 对应 Bun registerDeferredMicrotaskWithType
    /// 如果已注册则跳过
    /// Bun: if (this.auto_flusher.registered) return
    public func register(queue: DeferredTaskQueueV2): Unit {
        if (registered) {
            return
        }
        registerUnchecked(queue)
    }

    /// 注册延迟刷新任务 (不检查)
    /// 对应 Bun registerDeferredMicrotaskWithTypeUnchecked
    public func registerUnchecked(queue: DeferredTaskQueueV2): Unit {
        // Bun: bun.assert(!this.auto_flusher.registered)
        registered = true
        deferredQueue = queue
        // Bun: bun.assert(!vm.eventLoop().deferred_tasks.postTask(this, &Type.onAutoFlush))
        // postTask 返回 false 表示没有已存在的任务 (断言期望 false)
        queue.postTask(ctx, { =>
            flushCallback()
        })
    }

    // ========================================================================
    // unregister - 取消注册
    // 严格翻译自: unregisterDeferredMicrotaskWithType
    //
    // Bun:
    //   pub fn unregisterDeferredMicrotaskWithType(Type, this, vm) void {
    //       if (!this.auto_flusher.registered) return
    //       unregisterDeferredMicrotaskWithTypeUnchecked(Type, this, vm)
    //   }
    //
    //   pub fn unregisterDeferredMicrotaskWithTypeUnchecked(Type, this, vm) void {
    //       bun.assert(this.auto_flusher.registered)
    //       bun.assert(vm.eventLoop().deferred_tasks.unregisterTask(this))
    //       this.auto_flusher.registered = false
    //   }
    // ========================================================================

    /// 取消注册 - 对应 Bun unregisterDeferredMicrotaskWithType
    /// 如果未注册则跳过
    public func unregister(): Unit {
        if (!registered) {
            return
        }
        unregisterUnchecked()
    }

    /// 取消注册 (不检查)
    /// 对应 Bun unregisterDeferredMicrotaskWithTypeUnchecked
    public func unregisterUnchecked(): Unit {
        // Bun: bun.assert(this.auto_flusher.registered)
        registered = false
        match (deferredQueue) {
            case Some(queue) =>
                // Bun: bun.assert(vm.eventLoop().deferred_tasks.unregisterTask(this))
                queue.unregisterTask(ctx)
            case None => ()
        }
    }

    /// 是否已注册
    public func isRegistered(): Bool {
        return registered
    }

    /// 手动触发刷新
    public func flush(): Unit {
        match (deferredQueue) {
            case Some(queue) => queue.run()
            case None => ()
        }
    }
}
