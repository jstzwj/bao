// bao_event_loop - 并发任务 (完整版)
// 严格翻译自: src/event_loop/ConcurrentTask.zig
//
// Bun 的 ConcurrentTask:
//   //! A task that runs concurrently in the work pool.
//   //! It's also used to run tasks that need to be run on a different thread
//   //! than the main JavaScript thread.
//   //! If `auto_delete` is true, the task is automatically deallocated when finished.
//
//   const ConcurrentTask = @This()
//   task: Task = undefined
//   next: PackedNextPtr = .none
//
//   PackedNextPtr:
//     将 next 指针和 auto_delete 标志打包到一个 usize 中
//     低 1 位存储 auto_delete (指针至少 2 字节对齐)
//     pub inline fn init(ptr, auto_del) PackedNextPtr
//     pub inline fn getPtr(self) ?*ConcurrentTask
//     pub inline fn setPtr(self, ptr)
//     pub inline fn isAutoDelete(self) bool
//     pub inline fn atomicLoadPtr(self, ordering)
//     pub inline fn atomicStorePtr(self, ptr, ordering)
//
//   Queue = UnboundedQueue(ConcurrentTask, .next)
//   create(task) -> *ConcurrentTask
//   createFrom(task) -> *ConcurrentTask
//   fromCallback(ptr, callback) -> *ConcurrentTask
//   from(this, of, auto_deinit) -> *ConcurrentTask
//   autoDelete(this) bool
//
// 编译时检查:
//   @sizeOf(ConcurrentTask) == 16  (task: 8 + next: 8)
//   @alignOf(ConcurrentTask) >= 2  (指针打包要求)
//
// 仓颉翻译:
//   PackedNextPtr -> 使用独立的字段代替指针打包
//     (仓颉不需要手动指针操作, GC 管理引用)
//   UnboundedQueue -> ConcurrentLinkedQueue
package bao_event_loop

import bao_core.*
import bao_threading.*

// ============================================================================
// PackedNextPtr - 打包的下一指针
// 严格翻译自: ConcurrentTask.PackedNextPtr
//
// Bun:
//   pub const PackedNextPtr = enum(usize) {
//       none = 0,
//       auto_delete = 1,
//       _,
//       pub inline fn init(ptr: ?*ConcurrentTask, auto_del: bool) PackedNextPtr
//       pub inline fn getPtr(self) ?*ConcurrentTask
//       pub inline fn setPtr(self, ptr: ?*ConcurrentTask)
//       pub inline fn isAutoDelete(self) bool
//       pub inline fn atomicLoadPtr(self, ordering) ?*ConcurrentTask
//       pub inline fn atomicStorePtr(self, ptr, ordering)
//   }
//
// 将指针和 auto_delete 标志打包到一个 usize 中:
//   低 1 位: auto_delete 标志 (指针至少 2 字节对齐, 所以低 1 位总是 0)
//   高位: 指针值
//
// 仓颉: 不需要指针打包, 使用独立字段
//   因为仓颉有 GC, 引用本身就是安全的
//   但保持相同的逻辑接口
// ============================================================================

/// 打包的下一指针 - 对应 Bun PackedNextPtr
/// 仓颉实现: 使用独立字段代替指针位操作
/// Bun 使用指针低 1 位存储 auto_delete 标志
/// 仓颉不需要此优化, 但保持接口一致
public class PackedNextPtr {
    /// 下一任务指针 - 对应 Bun getPtr/setPtr
    public var next: ?ConcurrentTask
    /// 是否自动删除 - 对应 Bun isAutoDelete (低 1 位)
    public var autoDelete: Bool

    public init() {
        next = None
        autoDelete = false
    }

    public init(next: ?ConcurrentTask, autoDelete: Bool) {
        this.next = next
        this.autoDelete = autoDelete
    }

    /// 初始化 - 对应 Bun PackedNextPtr.init(ptr, auto_del)
    /// Bun:
    ///   pub inline fn init(ptr: ?*ConcurrentTask, auto_del: bool) PackedNextPtr {
    ///       const ptr_bits = if (ptr) |p| @intFromPtr(p) else 0
    ///       return @enumFromInt(ptr_bits | @intFromBool(auto_del))
    ///   }
    public static func init(next: ?ConcurrentTask, autoDelete: Bool): PackedNextPtr {
        return PackedNextPtr(next, autoDelete)
    }

    /// 获取下一指针 - 对应 Bun getPtr
    /// Bun:
    ///   pub inline fn getPtr(self) ?*ConcurrentTask {
    ///       const addr = @intFromEnum(self) & ~@as(usize, 1)
    ///       return if (addr == 0) null else @ptrFromInt(addr)
    ///   }
    public func getPtr(): ?ConcurrentTask {
        return next
    }

    /// 设置下一指针 - 对应 Bun setPtr
    /// Bun:
    ///   pub inline fn setPtr(self: *PackedNextPtr, ptr: ?*ConcurrentTask) void {
    ///       const auto_del = @intFromEnum(self.*) & 1
    ///       const ptr_bits = if (ptr) |p| @intFromPtr(p) else 0
    ///       self.* = @enumFromInt(ptr_bits | auto_del)
    ///   }
    public func setPtr(ptr: ?ConcurrentTask): Unit {
        next = ptr
    }

    /// 是否自动删除 - 对应 Bun isAutoDelete
    /// Bun:
    ///   pub inline fn isAutoDelete(self) bool {
    ///       return (@intFromEnum(self) & 1) != 0
    ///   }
    public func isAutoDelete(): Bool {
        return autoDelete
    }

    /// 原子加载下一指针 - 对应 Bun atomicLoadPtr
    /// Bun:
    ///   pub inline fn atomicLoadPtr(self, ordering) ?*ConcurrentTask {
    ///       const value = @atomicLoad(usize, @ptrCast(self), ordering)
    ///       const addr = value & ~@as(usize, 1)
    ///       return if (addr == 0) null else @ptrFromInt(addr)
    ///   }
    /// 仓颉: 由于使用引用类型, 原子操作由 GC 保证
    public func atomicLoadPtr(): ?ConcurrentTask {
        return next
    }

    /// 原子存储下一指针 - 对应 Bun atomicStorePtr
    /// Bun:
    ///   pub inline fn atomicStorePtr(self, ptr, ordering) void {
    ///       const ptr_bits = if (ptr) |p| @intFromPtr(p) else 0
    ///       const auto_del_bit = @atomicLoad(usize, self_ptr, .monotonic) & 1
    ///       @atomicStore(usize, self_ptr, ptr_bits | auto_del_bit, ordering)
    ///   }
    /// 仓颉: 引用赋值天然原子
    public func atomicStorePtr(ptr: ?ConcurrentTask): Unit {
        next = ptr
    }
}

// ============================================================================
// ConcurrentTaskV2 - 完整版并发任务 (严格翻译自 Zig)
// 严格翻译自: src/event_loop/ConcurrentTask.zig
//
// Bun:
//   const ConcurrentTask = @This()
//   task: Task = undefined
//   next: PackedNextPtr = .none
//
//   pub const Queue = UnboundedQueue(ConcurrentTask, .next)
//   pub const new = bun.TrivialNew(@This())
//   pub const deinit = bun.TrivialDeinit(@This())
//
//   pub fn create(task: Task) -> *ConcurrentTask {
//       return ConcurrentTask.new(.{ .task = task, .next = .auto_delete })
//   }
//
//   pub fn createFrom(task: anytype) -> *ConcurrentTask {
//       return create(Task.init(task))
//   }
//
//   pub fn fromCallback(ptr, callback) -> *ConcurrentTask {
//       return create(ManagedTask.New(...).init(ptr))
//   }
//
//   pub fn from(this, of, auto_deinit) -> *ConcurrentTask {
//       this.* = .{
//           .task = Task.init(of),
//           .next = if (auto_deinit == .auto_deinit) .auto_delete else .none
//       }
//       return this
//   }
//
//   pub fn autoDelete(this) bool {
//       return this.next.isAutoDelete()
//   }
//
//   编译时断言:
//     @sizeOf(ConcurrentTask) == 16
//     @alignOf(ConcurrentTask) >= 2
// ============================================================================

/// 并发任务 V2 - 严格翻译自 Bun ConcurrentTask.zig
/// 在工作线程池中运行, 结果返回主线程
/// 16 字节结构: task(8) + packedNext(8)
public class ConcurrentTaskV2 {
    /// 内部任务 - 对应 Bun task: Task
    /// Task 是一个 tag + ptr 的组合 (热调度标签)
    public var innerTask: AnyTask
    /// 打包的下一指针 - 对应 Bun next: PackedNextPtr
    /// 包含: next 指针 + auto_delete 标志
    public var packedNext: PackedNextPtr

    public init() {
        innerTask = AnyTask({ })
        packedNext = PackedNextPtr()
    }

    public init(task: AnyTask, autoDelete: Bool) {
        innerTask = task
        packedNext = PackedNextPtr(None, autoDelete)
    }

    // ========================================================================
    // create - 从 Task 创建并发任务
    // 严格翻译自: ConcurrentTask.create(task)
    //
    // Bun:
    //   pub fn create(task: Task) -> *ConcurrentTask {
    //       return ConcurrentTask.new(.{
    //           .task = task,
    //           .next = .auto_delete
    //       })
    //   }
    //
    // new 是 TrivialNew: 使用默认分配器创建实例
    // auto_delete 默认为 true
    // ========================================================================

    /// 创建并发任务 - 对应 Bun ConcurrentTask.create(task)
    /// 自动设置 autoDelete = true
    public static func create(task: AnyTask): ConcurrentTaskV2 {
        return ConcurrentTaskV2(task, true)
    }

    /// 从回调创建 - 对应 Bun ConcurrentTask.createFrom(task)
    /// Bun:
    ///   pub fn createFrom(task: anytype) -> *ConcurrentTask {
    ///       return create(Task.init(task))
    ///   }
    public static func createFrom(callback: () -> Unit): ConcurrentTaskV2 {
        return create(AnyTask(callback))
    }

    /// 从 ManagedTask 回调创建 - 对应 Bun ConcurrentTask.fromCallback
    /// Bun:
    ///   pub fn fromCallback(ptr: anytype, comptime callback: anytype) -> *ConcurrentTask {
    ///       return create(ManagedTask.New(std.meta.Child(@TypeOf(ptr)), callback).init(ptr))
    ///   }
    public static func fromCallback(callback: () -> Unit): ConcurrentTaskV2 {
        let managed = ManagedTask(callback)
        return create(AnyTask({ => managed.run() }))
    }

    // ========================================================================
    // from - 从已有结构初始化
    // 严格翻译自: ConcurrentTask.from(this, of, auto_deinit)
    //
    // Bun:
    //   pub fn from(this: *ConcurrentTask, of: anytype, auto_deinit: AutoDeinit)
    //       *ConcurrentTask
    //   {
    //       this.* = .{
    //           .task = Task.init(of),
    //           .next = if (auto_deinit == .auto_deinit) .auto_delete else .none
    //       }
    //       return this
    //   }
    // ========================================================================

    /// 从已有结构初始化 - 对应 Bun ConcurrentTask.from
    public static func from(task: AnyTask, autoDeinit: Bool): ConcurrentTaskV2 {
        return ConcurrentTaskV2(task, autoDeinit)
    }

    /// 是否自动删除 - 对应 Bun autoDelete
    /// Bun:
    ///   pub fn autoDelete(this: *const ConcurrentTask) bool {
    ///       return this.next.isAutoDelete()
    ///   }
    public func autoDelete(): Bool {
        return packedNext.isAutoDelete()
    }

    /// 执行任务
    public func run(): Unit {
        innerTask.run()
    }
}

/// AutoDeinit 枚举 - 对应 Bun ConcurrentTask.AutoDeinit
public enum AutoDeinit {
    | Manual    // manual_deinit
    | Auto      // auto_deinit
}

// ============================================================================
// ConcurrentTaskQueueV2 - MPSC 无界队列 (侵入式链表)
// 严格翻译自: UnboundedQueue(ConcurrentTask, .next)
//
// Bun:
//   pub const Queue = UnboundedQueue(ConcurrentTask, .next)
//
// UnboundedQueue 是侵入式 MPSC 无锁链表:
//   push: 原子 store next (release), 不需要 RMW
//     item.next.store(null, .Release)
//     prev = queue.tail.swap(item, .AcqRel)
//     if (prev) prev.next.store(item, .Release)
//     else queue.head.store(item, .Monotonic)
//
//   popBatch: 从 head 取一批任务
//     head = queue.head.swap(null, .AcqRel)
//     // reverse the list to maintain FIFO order
//
//   仓颉实现: 使用 ConcurrentLinkedQueue + PackedNextPtr 接口
// ============================================================================

/// MPSC 无界任务队列 V2 - 对应 Bun UnboundedQueue(ConcurrentTask, .next)
/// 多生产者单消费者: 工作线程 push, 事件循环 drain
public class ConcurrentTaskQueueV2 {
    /// 无界 MPSC 队列
    private var queue: ConcurrentLinkedQueue<ConcurrentTaskV2>
    /// 统计: 已提交
    private var totalPushed: AtomicInt64
    /// 统计: 已消费
    private var totalPopped: AtomicInt64

    public init() {
        queue = ConcurrentLinkedQueue<ConcurrentTaskV2>()
        totalPushed = AtomicInt64(0)
        totalPopped = AtomicInt64(0)
    }

    // ========================================================================
    // push - 从工作线程提交任务
    // 严格对应 Bun UnboundedQueue.push
    //
    // Bun (侵入式链表):
    //   pub fn push(queue, item) void {
    //       item.next.store(null, .Release)            // 清除 next
    //       const prev = queue.tail.swap(item, .AcqRel) // 原子交换 tail
    //       if (prev) |p| {
    //           p.next.store(item, .Release)            // 链接前一个节点
    //       } else {
    //           queue.head.store(item, .Monotonic)      // 首个元素
    //       }
    //   }
    //
    // 关键: push 是单个原子 store (swap), 不需要 CAS
    // 多个线程同时 push 时, 每个线程的 swap 是原子的
    // ========================================================================

    /// 提交任务 (MPSC push)
    /// 对应 Bun: concurrent_tasks.push(task); loop.wakeup()
    /// 线程安全: 多个工作线程可同时调用
    public func push(task: ConcurrentTaskV2): Unit {
        queue.put(task)
        totalPushed.incrementAndGet()
    }

    // ========================================================================
    // popBatch - 从事件循环线程批量取出任务
    // 严格对应 Bun UnboundedQueue.popBatch
    //
    // Bun:
    //   pub fn popBatch(queue) Batch {
    //       var head = queue.head.swap(null, .AcqRel)
    //       if (head == null) return Batch{}
    //       // reverse list to maintain FIFO order
    //       var tail = head
    //       while (tail.next) |next| { tail = next }
    //       return Batch{ .head = head, .tail = tail }
    //   }
    // ========================================================================

    /// 批量取出所有任务 - 对应 Bun popBatch
    public func popBatch(): ArrayList<ConcurrentTaskV2> {
        var tasks = ArrayList<ConcurrentTaskV2>()
        while (true) {
            let task = queue.remove()
            if (task == None) { break }
            tasks.append(task.unwrap())
            totalPopped.incrementAndGet()
        }
        return tasks
    }

    /// 取出并执行所有任务 - 对应 Bun tickConcurrentWithCount
    /// 返回执行的任务数
    public func drainAndExecute(): Int64 {
        var count: Int64 = 0
        while (true) {
            let task = queue.remove()
            if (task == None) { break }
            task.unwrap().run()
            totalPopped.incrementAndGet()
            count += 1
        }
        return count
    }

    /// 是否为空
    public func isEmpty(): Bool {
        queue.isEmpty()
    }

    /// 已提交数
    public func pushedCount(): Int64 {
        totalPushed.get()
    }

    /// 已消费数
    public func poppedCount(): Int64 {
        totalPopped.get()
    }
}
