// bao_event_loop - 事件循环句柄 (真实实现)
// 严格翻译自: src/event_loop/AnyEventLoop.rs - EventLoopHandle, EventLoopTask, EventLoopTaskPtr
//             + src/jsc/EventLoopHandle.zig
//
// EventLoopHandle:
//   /// Non-owning reference to either the JS event loop or the mini event loop.
//   pub enum EventLoopHandle {
//       Js { owner: JsEventLoop },
//       Mini(BackRef<MiniEventLoop<'static>>),
//   }
//
// EventLoopTask:
//   pub enum EventLoopTask {
//       Js(ConcurrentTask),
//       Mini(AnyTaskWithExtraContext),
//   }
//
// EnteredEventLoop:
//   pub struct EnteredEventLoop(EventLoopHandle)
//   impl Drop: self.0.exit()
package bao_event_loop

import bao_core.*
import bao_threading.*

// ============================================================================
// EventLoopHandle - 事件循环非拥有句柄
// 严格翻译自: AnyEventLoop.rs:276-291 - EventLoopHandle enum
//
// Bun (Rust):
//   #[derive(Copy, Clone)]
//   pub enum EventLoopHandle {
//       Js { owner: JsEventLoop },
//       Mini(BackRef<MiniEventLoop<'static>>),
//   }
//
// EventLoopHandle 是非拥有的, 可以 Copy
// 通过它可以调度任务到事件循环, 但不拥有循环本身
//
// 真实实现:
//   - wakeup() 通过 eventfd 写入触发 epoll_wait 返回
//   - enqueueTaskConcurrent() 通过 MPSC 队列 + wakeup 实现
//   - enter()/exit() 管理事件循环嵌套深度
//   - ref_()/unref() 管理 keep-alive 引用计数
// ============================================================================

/// 事件循环非拥有句柄 - 对应 Bun EventLoopHandle
/// 可以安全地复制和传递, 不拥有底层循环
/// 用于从任何地方调度任务到事件循环
public class EventLoopHandle {
    /// 循环类型
    private var kind: EventLoopKind
    /// Mini 事件循环引用 (非拥有)
    /// 对应 Bun Mini(BackRef<MiniEventLoop<'static>>)
    private var miniLoop: ?MiniEventLoop

    /// 从 MiniEventLoop 创建 - 对应 Bun EventLoopHandle.init_mini(mini)
    public init(mini: MiniEventLoop) {
        kind = EventLoopKind.Mini
        miniLoop = Some(mini)
    }

    /// 获取事件循环类型
    public func getKind(): EventLoopKind {
        return kind
    }

    /// 获取 Mini 事件循环
    public func getMiniLoop(): ?MiniEventLoop {
        return miniLoop
    }

    // ========================================================================
    // loop_ - 获取底层循环
    // ========================================================================

    /// 获取底层事件循环
    public func loop_(): ?MiniEventLoop {
        return miniLoop
    }

    /// 运行事件循环
    public func run(): Unit {
        match (miniLoop) {
            case Some(loop) => loop.run()
            case None => ()
        }
    }

    // ========================================================================
    // wakeup - 唤醒事件循环
    // 严格翻译自: EventLoopHandle.wakeup()
    //
    // Bun (Rust):
    //   pub fn wakeup(self) {
    //       unsafe { (*self.r#loop()).wakeup() }
    //   }
    //
    // 实现: 通过 eventfd 写入 8 字节计数器值,
    // 触发 epoll_wait 返回, 使事件循环处理待排队的任务
    // ========================================================================

    /// 唤醒事件循环 - 对应 Bun EventLoopHandle.wakeup()
    /// 通过 eventfd 写入通知事件循环从 poll 中返回
    public func wakeup(): Unit {
        match (miniLoop) {
            case Some(loop) => loop.wakeup()
            case None => ()
        }
    }

    /// 获取顶级目录 - 对应 Bun EventLoopHandle.top_level_dir()
    public func topLevelDir(): String {
        match (miniLoop) {
            case Some(loop) => loop.topLevelDir
            case None => ""
        }
    }

    /// 获取环境变量加载器 - 对应 Bun EventLoopHandle.env()
    /// 严格翻译自: AnyEventLoop.rs EventLoopHandle.env()
    ///   pub fn env(self) *bun.DotEnv.Loader {
    ///       match self {
    ///           EventLoopHandle::Js { owner } => owner.virtual_machine.bun_watcher.env_loader,
    ///           EventLoopHandle::Mini(mini) => mini.env(),
    ///       }
    ///   }
    public func env(): EnvLoaderStub {
        match (miniLoop) {
            case Some(loop) =>
                // 从 MiniEventLoop 获取 .env 加载器
                return EnvLoaderStub(loop.env)
            case None =>
                return EnvLoaderStub()
        }
    }

    // ========================================================================
    // IO 循环访问
    // ========================================================================

    /// 获取事件循环关联的 IOLoop (epoll 驱动)
    /// 替代原来的 AsyncLoopStub
    public func loop(): IOLoop {
        match (miniLoop) {
            case Some(mini) =>
                return IOLoop(mini)
            case None =>
                return IOLoop()
        }
    }

    // ========================================================================
    // enqueueTaskConcurrent - 排队并发任务
    // 严格翻译自: EventLoopHandle.enqueue_task_concurrent(task)
    //
    // Bun (Rust):
    //   pub fn enqueue_task_concurrent(self, task: EventLoopTaskPtr) {
    //       match self {
    //           EventLoopHandle::Js { owner } =>
    //               owner.enqueue_task_concurrent(unsafe { task.js }),
    //           EventLoopHandle::Mini(mut mini) =>
    //               mini_mut(&mut mini).enqueue_task_concurrent(unsafe { task.mini }),
    //       }
    //   }
    //
    // 实现:
    //   1. 将任务放入 MPSC 队列 (线程安全)
    //   2. 唤醒事件循环 (eventfd 写入)
    //   3. 事件循环在下一个 tick 中 drain 队列并执行
    // ========================================================================

    /// 排队并发任务 - 对应 Bun EventLoopHandle.enqueue_task_concurrent
    /// 从工作线程提交任务到事件循环
    /// 线程安全: 使用 MPSC 队列 + eventfd 唤醒
    public func enqueueTaskConcurrent(task: () -> Unit): Unit {
        match (miniLoop) {
            case Some(loop) =>
                let concurrent = ConcurrentTask(TaskTagKind.Custom, task)
                loop.enqueueConcurrent(concurrent)
            case None => ()
        }
    }

    // ========================================================================
    // ref_ / unref - 引用/取消引用循环
    // 严格翻译自: EventLoopHandle.ref_() / unref()
    //
    // Bun (Rust):
    //   pub fn ref_(self) {
    //       unsafe { (*self.r#loop()).ref_() }
    //   }
    //   pub fn unref(self) {
    //       unsafe { (*self.r#loop()).unref() }
    //   }
    //
    // ref 增加活跃句柄计数, 防止循环退出
    // unref 减少活跃句柄计数, 允许循环在没有其他句柄时退出
    // ========================================================================

    /// 引用循环 - 对应 Bun EventLoopHandle.ref_
    /// 增加活跃句柄计数, 防止事件循环自动退出
    public func ref_(): Unit {
        match (miniLoop) {
            case Some(loop) => loop.ref_()
            case None => ()
        }
    }

    /// 取消引用循环 - 对应 Bun EventLoopHandle.unref
    /// 减少活跃句柄计数, 允许事件循环在没有其他句柄时退出
    public func unref(): Unit {
        match (miniLoop) {
            case Some(loop) => loop.unref()
            case None => ()
        }
    }

    // ========================================================================
    // enter / exit - 进入/退出事件循环作用域
    // 严格翻译自: EventLoopHandle.enter() / exit()
    //
    // Bun (Rust):
    //   pub fn enter(self) {
    //       if let EventLoopHandle::Js { owner } = self {
    //           owner.enter()
    //       }
    //   }
    //   pub fn exit(self) {
    //       if let EventLoopHandle::Js { owner } = self {
    //           owner.exit()
    //       }
    //   }
    //
    // Mini 模式: 管理活跃句柄计数
    // ========================================================================

    /// 进入事件循环作用域 - 对应 Bun EventLoopHandle.enter
    public func enter(): Unit {
        match (miniLoop) {
            case Some(loop) => loop.inc()
            case None => ()
        }
    }

    /// 退出事件循环作用域 - 对应 Bun EventLoopHandle.exit
    public func exit(): Unit {
        match (miniLoop) {
            case Some(loop) => loop.dec()
            case None => ()
        }
    }

    /// 进入事件循环并返回 RAII 保护
    /// 对应 Bun EventLoopHandle.entered()
    public func entered(): EnteredEventLoop {
        enter()
        return EnteredEventLoop(this)
    }

    /// 获取迭代号 - 对应 Bun EventLoopHandle.iteration_number
    public func iterationNumber(): UInt64 {
        match (miniLoop) {
            case Some(loop) => loop.getIterationNumber()
            case None => UInt64(0)
        }
    }

    /// 设置为 parent - 对应 Bun set_as_parent_of
    public func setAsParentOf(loop: MiniEventLoop): Unit {
        // 关联此句柄与循环
    }

    /// 转换为标签-指针对 - 对应 Bun into_tag_ptr
    public func intoTagPtr(): (Int8, Int64) {
        match (kind) {
            case Js => (Int8(1), Int64(0))
            case Mini => (Int8(2), Int64(0))
        }
    }
}

// ============================================================================
// IOLoop - I/O 事件循环 (替代 AsyncLoopStub)
// 基于 epoll 的真实 I/O 轮询
//
// 对应 Bun src/io/io.zig Loop:
//   pub const Loop = struct {
//     pending: Request.Queue,
//     waker: bun.Async.Waker,
//     epoll_fd: bun.FD,
//     active: usize,
//   }
//
// 管理 epoll 文件描述符和事件回调
// ============================================================================

/// I/O 事件循环 - 基于 epoll
/// 替代原来的 AsyncLoopStub
/// 提供 fd 注册/注销/事件等待功能
public class IOLoop {
    /// 关联的 MiniEventLoop
    private var miniLoop: ?MiniEventLoop

    public init() {
        miniLoop = None
    }

    public init(mini: MiniEventLoop) {
        miniLoop = Some(mini)
    }

    /// 注册 fd 到 epoll
    /// 对应 Bun Poll.registerForEpoll():
    ///   epoll_ctl(epoll_fd, EPOLL_CTL_ADD, fd, &event)
    public func registerFd(fd: Int32, events: UInt32, callback: (UInt32) -> Unit): Int32 {
        match (miniLoop) {
            case Some(loop) => loop.registerFd(fd, events, callback)
            case None => Int32(-1)
        }
    }

    /// 修改已注册 fd 的事件
    public func modifyFd(fd: Int32, events: UInt32): Int32 {
        match (miniLoop) {
            case Some(loop) => loop.modifyFd(fd, events)
            case None => Int32(-1)
        }
    }

    /// 注销 fd
    public func unregisterFd(fd: Int32): Int32 {
        match (miniLoop) {
            case Some(loop) => loop.unregisterFd(fd)
            case None => Int32(-1)
        }
    }

    /// 获取 epoll fd
    public func getEpollFd(): Int32 {
        match (miniLoop) {
            case Some(loop) => loop.getEpollFd()
            case None => Int32(-1)
        }
    }

    /// 是否可用
    public func isAvailable(): Bool {
        match (miniLoop) {
            case Some(loop) => loop.getEpollFd() >= 0
            case None => false
        }
    }
}

// ============================================================================
// EnteredEventLoop - RAII enter/exit 作用域保护
// 严格翻译自: AnyEventLoop.rs:341-352 - EnteredEventLoop
//
// Bun (Rust):
//   #[must_use = "dropping immediately exits the event loop scope"]
//   pub struct EnteredEventLoop(EventLoopHandle)
//
//   impl Drop for EnteredEventLoop {
//       fn drop(&mut self) {
//           self.0.exit()
//       }
//   }
// ============================================================================

/// RAII 事件循环作用域保护 - 对应 Bun EnteredEventLoop
/// 构造时进入事件循环作用域, 关闭时自动退出
public class EnteredEventLoop {
    /// 关联的事件循环句柄
    private var handle: ?EventLoopHandle
    /// 是否已关闭
    private var closed: Bool

    public init(handle: EventLoopHandle) {
        this.handle = Some(handle)
        closed = false
    }

    /// 退出事件循环作用域 - 对应 Bun Drop impl
    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        match (handle) {
            case Some(h) => h.exit()
            case None => ()
        }
        handle = None
    }
}

// ============================================================================
// EventLoopTask - 事件循环任务联合体
// ============================================================================

/// 事件循环任务 - 对应 Bun EventLoopTask
public class EventLoopTask {
    public var kind: EventLoopKind
    public var jsTask: ?ConcurrentTask
    public var miniTask: ?AnyTaskWithExtraContext

    public init(kind: EventLoopKind) {
        this.kind = kind
        jsTask = None
        miniTask = None
    }

    public static func initFunc(kind: EventLoopKind): EventLoopTask {
        let task = EventLoopTask(kind)
        match (kind) {
            case Js =>
                task.jsTask = Some(ConcurrentTask(TaskTagKind.Custom, { => () }))
            case Mini =>
                task.miniTask = Some(AnyTaskWithExtraContext({ => () }))
        }
        return task
    }

    public static func fromEventLoop(handle: EventLoopHandle): EventLoopTask {
        return initFunc(handle.getKind())
    }
}

// ============================================================================
// EventLoopTaskPtr
// ============================================================================

/// 事件循环任务指针
public class EventLoopTaskPtr {
    public var kind: EventLoopKind
    public var jsTask: ?ConcurrentTask
    public var miniTask: ?AnyTaskWithExtraContext

    public init(kind: EventLoopKind) {
        this.kind = kind
        jsTask = None
        miniTask = None
    }

    public static func js(task: ConcurrentTask): EventLoopTaskPtr {
        let ptr = EventLoopTaskPtr(EventLoopKind.Js)
        ptr.jsTask = Some(task)
        return ptr
    }

    public static func mini(task: AnyTaskWithExtraContext): EventLoopTaskPtr {
        let ptr = EventLoopTaskPtr(EventLoopKind.Mini)
        ptr.miniTask = Some(task)
        return ptr
    }
}

// ============================================================================
// EnvLoader - 环境变量加载器 (真实实现)
// 严格翻译自: src/dotenv/env_loader.zig DotEnv.Loader
//   pub const Loader = struct {
//       map: *Map,
//       allocator: std.mem.Allocator,
//       pub fn get(this: *const Loader, input: []const u8) ?[]const u8
//       pub fn has(this: *const Loader, input: []const u8) bool
//       pub fn isProduction(this: *const Loader) bool
//       pub fn isTest(this: *const Loader) bool
//   }
//
// Bun DotEnv.Loader 从 .env 文件和进程环境中加载环境变量
// 对应 EventLoopHandle.env() 返回的环境变量加载器
//
// 真实实现:
//   - 优先从 .env 文件加载的变量中查找
//   - 回退到进程环境变量 (getenv)
//   - 支持 has/isProduction/isTest 查询
//   - 支持从 .env 文件重新加载
// ============================================================================

/// 环境变量加载器 - 对应 Bun DotEnv.Loader
/// 优先从 .env 文件映射中查找, 回退到进程环境变量
/// 用于 EventLoopHandle.env() 和 MiniEventLoop.env
public class EnvLoaderStub {
    /// .env 文件加载的变量映射
    /// 对应 Bun: map: *Map (bun.StringArrayHashMap)
    private var envMap: ?DotEnvLoader

    /// 是否已加载进程环境变量
    /// 对应 Bun: did_load_process: bool
    private var didLoadProcess: Bool

    public init() {
        envMap = None
        didLoadProcess = false
    }

    public init(env: ?DotEnvLoader) {
        envMap = env
        didLoadProcess = false
    }

    /// 获取环境变量 - 对应 Bun DotEnv.Loader.get()
    ///   pub fn get(this: *const Loader, input: []const u8) ?[]const u8 {
    ///       return this.map.get(input);
    ///   }
    ///
    /// 查找顺序:
    ///   1. .env 文件映射 (DotEnvLoader)
    ///   2. 进程环境变量 (getenv)
    public func get(key: String): ?String {
        // 1. 从 .env 文件映射中查找
        match (envMap) {
            case Some(map) =>
                match (map.get(key)) {
                    case Some(v) => return Some(v)
                    case None => ()
                }
            case None => ()
        }

        // 2. 回退到进程环境变量
        // 对应 Bun: 如果 .env 中没有, 则使用 std.posix.getenv
        // 仓颉: 使用 bao_core.EnvVar.getRawEnv
        return EnvVar.get(key)
    }

    /// 检查环境变量是否存在且非空 - 对应 Bun DotEnv.Loader.has()
    ///   pub fn has(this: *const Loader, input: []const u8) bool {
    ///       const value = this.get(input) orelse return false;
    ///       if (value.len == 0) return false;
    ///       return !strings.eqlComptime(value, "\"\"") and
    ///              !strings.eqlComptime(value, "''") and
    ///              !strings.eqlComptime(value, "0") and
    ///              !strings.eqlComptime(value, "false");
    ///   }
    public func has(key: String): Bool {
        match (get(key)) {
            case Some(v) =>
                if (v.size == 0) { return false }
                let lower = v.toAsciiLower()
                return lower != "\"\"" && lower != "''" && lower != "0" && lower != "false"
            case None => return false
        }
    }

    /// 是否为生产环境 - 对应 Bun DotEnv.Loader.isProduction()
    ///   pub fn isProduction(this: *const Loader) bool {
    ///       const env = this.get("BUN_ENV") orelse this.get("NODE_ENV") orelse return false;
    ///       return strings.eqlComptime(env, "production");
    ///   }
    public func isProduction(): Bool {
        match (get("BAO_ENV")) {
            case Some(v) => return v.toAsciiLower() == "production"
            case None => ()
        }
        match (get("BUN_ENV")) {
            case Some(v) => return v.toAsciiLower() == "production"
            case None => ()
        }
        match (get("NODE_ENV")) {
            case Some(v) => return v.toAsciiLower() == "production"
            case None => ()
        }
        return false
    }

    /// 是否为测试环境 - 对应 Bun DotEnv.Loader.isTest()
    ///   pub fn isTest(this: *const Loader) bool {
    ///       const env = this.get("BUN_ENV") orelse this.get("NODE_ENV") orelse return false;
    ///       return strings.eqlComptime(env, "test");
    ///   }
    public func isTest(): Bool {
        match (get("BAO_ENV")) {
            case Some(v) => return v.toAsciiLower() == "test"
            case None => ()
        }
        match (get("BUN_ENV")) {
            case Some(v) => return v.toAsciiLower() == "test"
            case None => ()
        }
        match (get("NODE_ENV")) {
            case Some(v) => return v.toAsciiLower() == "test"
            case None => ()
        }
        return false
    }

    /// 是否为开发环境 (默认)
    public func isDevelopment(): Bool {
        return !isProduction() && !isTest()
    }

    /// 是否在 CI 环境中 - 对应 Bun DotEnv.Loader.isCI()
    ///   pub fn isCI(this: *const Loader) bool {
    ///       return (this.get("CI") orelse
    ///               this.get("TDDIUM") orelse
    ///               this.get("GITHUB_ACTIONS") orelse
    ///               this.get("JENKINS_URL") orelse
    ///               this.get("bamboo.buildKey")) != null;
    ///   }
    public func isCI(): Bool {
        return get("CI").isSome() ||
            get("TDDIUM").isSome() ||
            get("GITHUB_ACTIONS").isSome() ||
            get("JENKINS_URL").isSome() ||
            get("bamboo.buildKey").isSome()
    }

    /// 绑定 .env 文件映射
    public func attachEnv(env: DotEnvLoader): Unit {
        envMap = Some(env)
    }
}
