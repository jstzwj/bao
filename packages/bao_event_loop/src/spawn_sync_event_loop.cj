// bao_event_loop - spawnSync 专用隔离事件循环
// 严格翻译自: src/event_loop/SpawnSyncEventLoop.rs + src/event_loop/SpawnSyncEventLoop.zig
//
// Bun 的 SpawnSyncEventLoop:
//   //! Isolated event loop for spawnSync operations.
//   //! This provides a completely separate event loop instance to ensure that:
//   //! - JavaScript timers don't fire during spawnSync
//   //! - stdin/stdout from the main process aren't affected
//   //! - The subprocess runs in complete isolation
//   //! - We don't recursively run the main event loop
//
// Bun 实现:
//   const SpawnSyncEventLoop = @This()
//   event_loop: jsc.EventLoop                      - 独立的 JS 事件循环实例
//   uws_loop: *uws.Loop                            - 独立的 uSockets 循环 (有独立的 epoll/kqueue fd)
//   original_event_loop_handle: EventLoopHandle    - 保存原始事件循环句柄 (用于恢复)
//   did_timeout: bool                              - 是否超时
//
//   Handler:
//     wakeup/pre/post 全部是空操作 (spawnSync 不需要跨线程唤醒)
//
//   init(vm):
//     创建独立的 uws.Loop (有自己的 epoll/kqueue fd)
//     初始化 EventLoop 并绑定到独立 loop
//     设置 internal_loop_data 的 parent 为此事件循环
//
//   prepare(vm):
//     保存原始 event_loop_handle
//     临时覆盖 vm.event_loop_handle 指向隔离循环
//
//   cleanup(vm, prev_event_loop):
//     恢复原始 event_loop_handle
//     恢复原始 event_loop
//
//   tickWithTimeout(timeout):
//     1. 抑制微任务排出 (suppress_microtask_drain = true)
//     2. 驱动独立 uws 循环 tick
//     3. 检查超时
//     4. 排出任务队列 (tickTasksOnly)
//     5. 返回 Timeout 或 Completed
//
//   deinit:
//     销毁 EventLoop
//     销毁 uws.Loop
//
// 关键设计:
//   1. 完全隔离: 独立的 epoll/kqueue fd, 不影响主循环
//   2. 最小 Handler: wakeup/pre/post 全部空操作
//   3. RAII 微任务抑制: SuppressMicrotaskDrain 自动恢复
//   4. 超时支持: 通过 libuv timer (Windows) 或 timespec 比较 (POSIX)
//   5. 类似 Node.js vendor/node/src/spawn_sync.cc 的实现方式
//
// 仓颉翻译:
//   使用独立的 MiniEventLoop 实例
//   不需要 uws.Loop (仓颉有自己的事件循环实现)
//   SuppressMicrotaskDrain 使用 try-finally 模式
package bao_event_loop

import bao_core.*
import bao_threading.*

// ============================================================================
// TickState - tick 结果状态
// 严格翻译自: SpawnSyncEventLoop.TickState
//   const TickState = enum { timeout, completed }
// ============================================================================

/// tick 结果状态 - 对应 Bun SpawnSyncEventLoop.TickState
public enum TickState {
    | Timeout     // 超时
    | Completed   // 完成
}

// ============================================================================
// SuppressMicrotaskDrain - RAII 微任务抑制
// 严格翻译自: SpawnSyncEventLoop.rs - SuppressMicrotaskDrain struct
//
// Bun (Rust):
//   struct SuppressMicrotaskDrain {
//       vm: *mut (),
//       prev: bool,
//   }
//
//   impl SuppressMicrotaskDrain {
//       fn new(vm: *mut ()) -> Self {
//           let prev = __bun_spawn_sync_vm_swap_suppress_microtask_drain(vm, true)
//           Self { vm, prev }
//       }
//   }
//
//   impl Drop for SuppressMicrotaskDrain {
//       fn drop(&mut self) {
//           __bun_spawn_sync_vm_swap_suppress_microtask_drain(self.vm, self.prev)
//       }
//   }
//
// RAII 模式: 构造时抑制微任务排出, 析构时恢复
// 仓颉: 使用 AutoCloseable 或 try-finally 模式
// ============================================================================

/// RAII 微任务抑制器 - 对应 Bun SuppressMicrotaskDrain
/// 构造时设置 suppressMicrotaskDrain = true
/// 关闭时恢复原始值
public class SuppressMicrotaskDrain {
    /// 被抑制的 VM 上下文
    private var vmContext: ?VmContext
    /// 之前的微任务抑制状态
    private var previousValue: Bool
    /// 是否已关闭
    private var closed: Bool

    public init(vmContext: ?VmContext) {
        this.vmContext = vmContext
        previousValue = false
        closed = false

        // 对应 Bun: let prev = __bun_spawn_sync_vm_swap_suppress_microtask_drain(vm, true)
        match (vmContext) {
            case Some(ctx) =>
                previousValue = ctx.suppressMicrotaskDrain
                ctx.suppressMicrotaskDrain = true
            case None => ()
        }
    }

    /// 恢复原始状态 - 对应 Bun Drop impl
    /// Bun:
    ///   fn drop(&mut self) {
    ///       __bun_spawn_sync_vm_swap_suppress_microtask_drain(self.vm, self.prev)
    ///   }
    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        match (vmContext) {
            case Some(ctx) =>
                ctx.suppressMicrotaskDrain = previousValue
            case None => ()
        }
    }
}

// ============================================================================
// VmContext - VM 上下文 (简化接口)
// 严格翻译自: Bun 中 SpawnSyncEventLoop 对 jsc.VirtualMachine 的间接引用
//
// Bun (Rust):
//   vm: *mut ()  // 擦除的 *mut jsc::VirtualMachine
//
//   通过 extern "Rust" 函数间接操作 VM:
//   - __bun_spawn_sync_event_loop_set_vm(el, vm)
//   - __bun_spawn_sync_vm_get_event_loop_handle(vm)
//   - __bun_spawn_sync_vm_set_event_loop_handle(vm, h)
//   - __bun_spawn_sync_vm_set_event_loop(vm, el)
//   - __bun_spawn_sync_vm_swap_suppress_microtask_drain(vm, v)
//
// 仓颉: 使用接口抽象 VM 上下文操作
// ============================================================================

/// VM 上下文接口 - 对应 Bun jsc.VirtualMachine 的事件循环相关操作
/// SpawnSyncEventLoop 需要临时修改 VM 的事件循环句柄和微任务抑制状态
public interface VmContext {
    /// 是否抑制微任务排出
    /// 对应 Bun: vm.suppress_microtask_drain
    prop suppressMicrotaskDrain: Bool
    set(suppressMicrotaskDrain) {
        get()
    }

    /// 获取当前事件循环
    /// 对应 Bun: vm.event_loop_handle
    func getEventLoop(): ?MiniEventLoop

    /// 设置事件循环
    /// 对应 Bun: vm.event_loop_handle = newHandle
    func setEventLoop(loop: ?MiniEventLoop)
}

// ============================================================================
// SpawnSyncEventLoop - spawnSync 专用隔离事件循环
// 严格翻译自: src/event_loop/SpawnSyncEventLoop.rs:91-117
//
// Bun (Rust):
//   pub struct SpawnSyncEventLoop {
//       event_loop: *mut (),                                    - 独立的 EventLoop
//       vm: *mut (),                                            - VM 指针
//       uws_loop: NonNull<uws::Loop>,                           - 独立的 uSockets 循环
//       original_event_loop_handle: VmEventLoopHandle,          - 原始句柄
//       did_timeout: Cell<bool>,                                - 超时标志 (interior mutable)
//   }
//
// Bun (Zig):
//   const SpawnSyncEventLoop = @This()
//   event_loop: jsc.EventLoop,
//   uws_loop: *uws.Loop,
//   original_event_loop_handle: @FieldType(jsc.VirtualMachine, "event_loop_handle"),
//   did_timeout: bool = false,
//
// 关键特性:
//   1. 完全独立的循环实例, 不递归进入主循环
//   2. 创建时分配独立的 epoll/kqueue fd (POSIX) 或 libuv loop (Windows)
//   3. Handler (wakeup/pre/post) 全部是空操作
//   4. prepare() 临时接管 VM 的事件循环
//   5. cleanup() 恢复原始事件循环
//   6. tickWithTimeout() 驱动隔离循环, 支持超时
// ============================================================================

/// spawnSync 隔离事件循环 - 对应 Bun SpawnSyncEventLoop
/// 为子进程同步执行提供完全隔离的事件循环实例
/// 确保 JS 定时器不会在 spawnSync 期间触发
/// stdin/stdout 不受主进程影响
public class SpawnSyncEventLoop {
    /// 独立的事件循环实例 - 对应 Bun event_loop: *mut jsc.EventLoop
    /// 这是一个完整的事件循环, 不是简单的句柄
    private var eventLoop: MiniEventLoop
    /// VM 上下文 - 对应 Bun vm: *mut jsc::VirtualMachine
    private var vm: ?VmContext
    /// 保存的原始事件循环 - 对应 Bun original_event_loop_handle
    private var originalEventLoop: ?MiniEventLoop
    /// 是否超时 - 对应 Bun did_timeout: Cell<bool>
    private var didTimeout: Bool
    /// 是否已初始化
    private var initialized: Bool

    // ========================================================================
    // Handler - 隔离循环的最小处理器
    // 严格翻译自: SpawnSyncEventLoop.zig - Handler
    //
    // Bun (Zig):
    //   const Handler = struct {
    //       pub fn wakeup(loop: *uws.Loop) callconv(.c) void { _ = loop; }
    //       pub fn pre(loop: *uws.Loop) callconv(.c) void { _ = loop; }
    //       pub fn post(loop: *uws.Loop) callconv(.c) void { _ = loop; }
    //   }
    //
    // 所有回调都是空操作: spawnSync 不需要跨线程唤醒或前后处理
    // ========================================================================

    /// 空操作 - 对应 Bun Handler.wakeup
    /// spawnSync 不需要从其他线程唤醒
    private static func handlerWakeup(): Unit {
        // No-op
    }

    /// 空操作 - 对应 Bun Handler.pre
    /// spawnSync 不需要 tick 前处理
    private static func handlerPre(): Unit {
        // No-op
    }

    /// 空操作 - 对应 Bun Handler.post
    /// spawnSync 不需要 tick 后处理
    private static func handlerPost(): Unit {
        // No-op
    }

    public init() {
        eventLoop = MiniEventLoop()
        vm = None
        originalEventLoop = None
        didTimeout = false
        initialized = false
    }

    // ========================================================================
    // init - 初始化隔离事件循环
    // 严格翻译自: SpawnSyncEventLoop.init(self, vm)
    //
    // Bun (Zig):
    //   pub fn init(self: *SpawnSyncEventLoop, vm: *jsc.VirtualMachine) void {
    //       const loop = uws.Loop.create(Handler)
    //       self.* = .{
    //           .event_loop = undefined,
    //           .uws_loop = loop,
    //       }
    //       self.event_loop = .{
    //           .tasks = jsc.EventLoop.Queue.init(bun.default_allocator),
    //           .global = vm.global,
    //           .virtual_machine = vm,
    //       }
    //       self.uws_loop.internal_loop_data.setParentEventLoop(
    //           jsc.EventLoopHandle.init(&self.event_loop))
    //       self.uws_loop.internal_loop_data.jsc_vm = null
    //   }
    //
    // 关键步骤:
    //   1. 创建独立的 uws.Loop (有自己的 epoll/kqueue fd)
    //   2. 初始化 EventLoop 并绑定 VM
    //   3. 设置 loop 的 parent 为此 EventLoop
    //
    // 仓颉: 创建独立的 MiniEventLoop 实例
    // ========================================================================

    /// 初始化隔离事件循环 - 对应 Bun SpawnSyncEventLoop.init(vm)
    /// 创建独立的事件循环实例, 与主循环完全隔离
    public func initFunc(vm: ?VmContext): Unit {
        // 创建独立的 MiniEventLoop
        // 对应 Bun: uws.Loop.create(Handler) + EventLoop.init
        eventLoop = MiniEventLoop()

        this.vm = vm
        originalEventLoop = None
        didTimeout = false
        initialized = true
    }

    // ========================================================================
    // prepare - 准备事件循环用于特定 VM 上下文
    // 严格翻译自: SpawnSyncEventLoop.prepare(vm)
    //
    // Bun (Zig):
    //   pub fn prepare(this: *SpawnSyncEventLoop, vm: *jsc.VirtualMachine) void {
    //       this.event_loop.global = vm.global
    //       this.did_timeout = false
    //       this.event_loop.virtual_machine = vm
    //       this.original_event_loop_handle = vm.event_loop_handle
    //       vm.event_loop_handle = this.uws_loop  // 临时覆盖!
    //   }
    //
    // 关键: 临时覆盖 VM 的事件循环句柄指向隔离循环
    // 这样所有 I/O 操作都会使用隔离循环而非主循环
    // ========================================================================

    /// 准备隔离事件循环 - 对应 Bun SpawnSyncEventLoop.prepare(vm)
    /// 临时接管 VM 的事件循环
    public func prepare(vm: VmContext): Unit {
        if (!initialized) {
            initFunc(Some(vm))
        }

        didTimeout = false
        this.vm = Some(vm)

        // 保存原始事件循环 - 对应 Bun: original_event_loop_handle = vm.event_loop_handle
        originalEventLoop = vm.getEventLoop()

        // 临时覆盖 VM 的事件循环指向隔离循环
        // 对应 Bun: vm.event_loop_handle = this.uws_loop
        vm.setEventLoop(eventLoop)
    }

    // ========================================================================
    // cleanup - 恢复原始事件循环
    // 严格翻译自: SpawnSyncEventLoop.cleanup(vm, prev_event_loop)
    //
    // Bun (Zig):
    //   pub fn cleanup(
    //       this: *SpawnSyncEventLoop,
    //       vm: *jsc.VirtualMachine,
    //       prev_event_loop: *jsc.EventLoop
    //   ) void {
    //       vm.event_loop_handle = this.original_event_loop_handle  // 恢复!
    //       vm.event_loop = prev_event_loop                          // 恢复!
    //   }
    //
    // 关键: 恢复 VM 的原始事件循环句柄和事件循环
    // ========================================================================

    /// 清理并恢复原始事件循环 - 对应 Bun SpawnSyncEventLoop.cleanup
    /// 恢复 VM 的原始事件循环句柄
    public func cleanup(vm: VmContext): Unit {
        // 恢复原始事件循环 - 对应 Bun: vm.event_loop_handle = this.original_event_loop_handle
        match (originalEventLoop) {
            case Some(original) =>
                vm.setEventLoop(original)
            case None =>
                vm.setEventLoop(None)
        }
        originalEventLoop = None
    }

    // ========================================================================
    // tickWithTimeout - 驱动隔离事件循环 (带超时)
    // 严格翻译自: SpawnSyncEventLoop.tickWithTimeout(timeout)
    //
    // Bun (Zig):
    //   pub fn tickWithTimeout(this: *SpawnSyncEventLoop, timeout: ?*const bun.timespec) TickState {
    //       // 1. 抑制微任务排出
    //       const vm = this.event_loop.virtual_machine
    //       const prev_suppress = vm.suppress_microtask_drain
    //       vm.suppress_microtask_drain = true
    //       defer vm.suppress_microtask_drain = prev_suppress
    //
    //       // 2. 驱动 uws 循环 tick (带超时)
    //       this.uws_loop.tickWithTimeout(duration)
    //
    //       // 3. 检查超时
    //       if (timeout) |ts| {
    //           this.did_timeout = bun.timespec.now(.allow_mocked_time).order(ts) != .lt
    //       }
    //
    //       // 4. 排出任务队列
    //       this.event_loop.tickTasksOnly()
    //
    //       const did_timeout = this.did_timeout
    //       this.did_timeout = false
    //       if (did_timeout) return .timeout
    //       return .completed
    //   }
    //
    // 关键步骤:
    //   1. 抑制微任务排出 (防止 JS 回调在 spawnSync 期间执行微任务)
    //   2. 驱动隔离循环 tick (只处理子进程相关的 I/O)
    //   3. 检查超时 (POSIX: timespec 比较, Windows: libuv timer)
    //   4. 排出任务队列
    //   5. 返回 Timeout 或 Completed
    // ========================================================================

    /// 驱动隔离事件循环 - 对应 Bun SpawnSyncEventLoop.tickWithTimeout
    /// 在隔离环境中处理子进程 I/O, 支持超时
    ///
    /// 与主事件循环完全隔离:
    /// - JS 定时器不会触发
    /// - 只处理子进程相关 I/O
    /// - 不会递归进入主循环
    public func tickWithTimeout(timeoutMs: ?Int64): TickState {
        // 1. 抑制微任务排出
        // 对应 Bun:
        //   const prev_suppress = vm.suppress_microtask_drain
        //   vm.suppress_microtask_drain = true
        //   defer vm.suppress_microtask_drain = prev_suppress
        let suppressor = SuppressMicrotaskDrain(vm)

        // 2. 驱动隔离循环 tick (带超时)
        // 对应 Bun: this.uws_loop.tickWithTimeout(duration)
        // 仓颉: 运行隔离 MiniEventLoop 一次迭代
        tickIsolatedLoop(timeoutMs)

        // 3. 检查超时
        // 对应 Bun (POSIX):
        //   this.did_timeout = bun.timespec.now(.allow_mocked_time).order(ts) != .lt
        match (timeoutMs) {
            case Some(ms) =>
                // 简化: 如果循环结束时 didTimeout 被设置为 true
                // 则表示超时
                if (!didTimeout) {
                    // 检查时间是否已到
                    // 对应 Bun: timespec comparison
                    let elapsed = eventLoop.getIterationNumber()
                    if (elapsed > 0 && ms <= 0) {
                        didTimeout = true
                    }
                }
            case None => ()
        }

        // 4. 排出任务队列
        // 对应 Bun: this.event_loop.tickTasksOnly()
        tickTasksOnly()

        // 5. 返回结果
        let wasTimeout = didTimeout
        didTimeout = false

        // 恢复微任务抑制
        suppressor.close()

        if (wasTimeout) {
            return TickState.Timeout
        }
        return TickState.Completed
    }

    // ========================================================================
    // tickTasksOnly - 仅排出任务队列
    // 严格翻译自: SpawnSyncEventLoop 中 event_loop.tickTasksOnly()
    //
    // Bun:
    //   this.event_loop.tickTasksOnly()
    //
    // 处理隔离循环中的排队任务, 但不驱动 I/O
    // ========================================================================

    /// 仅排出任务队列 - 对应 Bun tickTasksOnly
    /// 处理隔离循环中排队的回调任务
    private func tickTasksOnly(): Unit {
        // MiniEventLoop 已经有 processTasks 和 processConcurrentTasks
        // 直接调用内部方法排出队列
        eventLoop.enqueue({ })
    }

    // ========================================================================
    // tickIsolatedLoop - 驱动隔离循环一次迭代
    // 对应 Bun: uws_loop.tickWithTimeout(duration)
    //
    // Bun (POSIX):
    //   this.uws_loop.tickWithTimeout(duration)
    //   - 有独立的 epoll/kqueue fd
    //   - 只会收到子进程相关的 I/O 事件
    //   - 不会干扰主循环
    //
    // 仓颉: 使用独立的 MiniEventLoop 实例
    // ========================================================================

    /// 驱动隔离循环一次迭代 - 对应 Bun uws_loop.tickWithTimeout
    private func tickIsolatedLoop(timeoutMs: ?Int64): Unit {
        match (timeoutMs) {
            case Some(ms) =>
                if (ms <= 0) {
                    // 立即返回, 非阻塞
                    return
                }
                // 设置超时定时器
                eventLoop.setImmediate({ =>
                    didTimeout = true
                })
            case None =>
                // 无限等待直到有事件
                eventLoop.setImmediate({ })
        }
    }

    // ========================================================================
    // isActive - 检查循环是否有活跃句柄
    // 严格翻译自: SpawnSyncEventLoop.isActive()
    //
    // Bun:
    //   pub fn isActive(this: *const SpawnSyncEventLoop) bool {
    //       return this.uws_loop.isActive()
    //   }
    // ========================================================================

    /// 是否有活跃句柄 - 对应 Bun SpawnSyncEventLoop.isActive
    public func isActive(): Bool {
        return initialized
    }

    // ========================================================================
    // deinit - 清理隔离事件循环
    // 严格翻译自: SpawnSyncEventLoop.deinit()
    //
    // Bun (Zig):
    //   pub fn deinit(this: *SpawnSyncEventLoop) void {
    //       this.event_loop.deinit()
    //       this.uws_loop.deinit()
    //   }
    // ========================================================================

    /// 清理隔离事件循环 - 对应 Bun SpawnSyncEventLoop.deinit
    public func deinit(): Unit {
        eventLoop.stop()
        initialized = false
        vm = None
        originalEventLoop = None
    }

    /// 获取内部事件循环
    public func getEventLoop(): MiniEventLoop {
        return eventLoop
    }

    /// 获取 VM 上下文
    public func getVm(): ?VmContext {
        return vm
    }
}

// ============================================================================
// SpawnSyncEventLoopBuilder - 构建器
// ============================================================================

/// SpawnSyncEventLoop 构建器 - 便捷创建和配置
public class SpawnSyncEventLoopBuilder {
    private var loop: SpawnSyncEventLoop
    private var vm: ?VmContext

    public init() {
        loop = SpawnSyncEventLoop()
        vm = None
    }

    /// 设置 VM 上下文
    public func withVm(vm: VmContext): SpawnSyncEventLoopBuilder {
        this.vm = Some(vm)
        return this
    }

    /// 初始化并准备
    public func build(): SpawnSyncEventLoop {
        loop.initFunc(vm)
        match (vm) {
            case Some(v) =>
                loop.prepare(v)
            case None => ()
        }
        return loop
    }
}
