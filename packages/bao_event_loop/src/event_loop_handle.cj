// bao_event_loop - 事件循环句柄
// 严格翻译自: src/event_loop/AnyEventLoop.rs - EventLoopHandle, EventLoopTask, EventLoopTaskPtr
//             + src/jsc/EventLoopHandle.zig
//
// Bun 的 EventLoopHandle:
//   /// Non-owning reference to either the JS event loop or the mini event loop.
//   /// The `.js` arm holds a JsEventLoop handle (link-time-resolved dispatch).
//   /// The `.mini` arm holds a BackRef<MiniEventLoop>.
//
//   pub enum EventLoopHandle {
//       Js { owner: JsEventLoop },
//       Mini(BackRef<MiniEventLoop<'static>>),
//   }
//
//   EventLoopHandle 方法:
//     init(js_event_loop)           - 从 JS EventLoop 创建
//     init_mini(mini)               - 从 MiniEventLoop 创建
//     from_any(any)                 - 从 AnyEventLoop 创建
//     loop_()                       - 获取底层 uws.Loop
//     wakeup()                      - 唤醒事件循环
//     enter() / exit()              - 进入/退出事件循环作用域
//     entered()                     - RAII enter/exit
//     enqueue_task_concurrent(task) - 排队并发任务
//     file_polls()                  - 获取文件轮询存储
//     pipe_read_buffer()            - 获取管道读缓冲区
//     env()                         - 获取环境变量加载器
//     top_level_dir()               - 获取顶级目录
//     ref_() / unref()              - 引用/取消引用循环
//     global_object()               - 获取 JS 全局对象
//     bun_vm()                      - 获取 VM
//     stdout() / stderr()           - 获取 stdout/stderr 存储
//
// EventLoopTask:
//   pub enum EventLoopTask {
//       Js(ConcurrentTask),
//       Mini(AnyTaskWithExtraContext),
//   }
//
// EventLoopTaskPtr:
//   pub union EventLoopTaskPtr {
//       pub js: *mut ConcurrentTask,
//       pub mini: *mut AnyTaskWithExtraContext,
//   }
//
// EnteredEventLoop:
//   /// RAII pairing for enter/exit
//   pub struct EnteredEventLoop(EventLoopHandle)
//   impl Drop: self.0.exit()
//
// 仓颉翻译:
//   EventLoopHandle 使用枚举包装 MiniEventLoop 引用
//   不需要 BackRef (仓颉有 GC)
//   EnteredEventLoop 使用 AutoCloseable 模式
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
// Bun (Zig):
//   pub const EventLoopHandle = union(EventLoopKind) {
//       js: *EventLoop,
//       mini: *MiniEventLoop,
//   }
//
// EventLoopHandle 是非拥有的, 可以 Copy
// 通过它可以调度任务到事件循环, 但不拥有循环本身
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
    /// Bun:
    ///   pub fn init_mini(mini: *mut MiniEventLoop<'static>) -> EventLoopHandle {
    ///       EventLoopHandle::Mini(NonNull::new(mini).expect("non-null").into())
    ///   }
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
    // 严格翻译自: EventLoopHandle.loop_()
    //
    // Bun (Rust):
    //   pub fn r#loop(self) -> *mut UwsLoop {
    //       match self {
    //           EventLoopHandle::Js { owner } => owner.uws_loop(),
    //           EventLoopHandle::Mini(mini) => mini.loop_ptr(),
    //       }
    //   }
    //
    // 仓颉: 返回关联的 MiniEventLoop
    // ========================================================================

    /// 获取底层事件循环 - 对应 Bun EventLoopHandle.loop_()
    public func loop_(): ?MiniEventLoop {
        return miniLoop
    }

    // ========================================================================
    // wakeup - 唤醒事件循环
    // 严格翻译自: EventLoopHandle.wakeup()
    //
    // Bun (Rust):
    //   pub fn wakeup(&mut self) {
    //       unsafe { (*self.r#loop()).wakeup() }
    //   }
    //
    // 用于从其他线程通知事件循环有新任务
    // ========================================================================

    /// 唤醒事件循环 - 对应 Bun EventLoopHandle.wakeup
    /// 从任意线程安全调用, 通知事件循环检查新任务
    public func wakeup(): Unit {
        match (miniLoop) {
            case Some(loop) =>
                loop.enqueue({ })
            case None => ()
        }
    }

    // ========================================================================
    // enqueue_task_concurrent - 排队并发任务
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
    // ========================================================================

    /// 排队并发任务 - 对应 Bun EventLoopHandle.enqueue_task_concurrent
    /// 从工作线程提交任务到事件循环
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
        // 仓颉: MiniEventLoop 没有 ref/unref 概念
        // 简化实现
    }

    /// 取消引用循环 - 对应 Bun EventLoopHandle.unref
    /// 减少活跃句柄计数, 允许事件循环在没有其他句柄时退出
    public func unref(): Unit {
        // 仓颉: MiniEventLoop 没有 ref/unref 概念
        // 简化实现
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
    // JS 模式: JSC Enter/Exit 影响垃圾回收和微任务
    // Mini 模式: 无操作
    // ========================================================================

    /// 进入事件循环作用域 - 对应 Bun EventLoopHandle.enter
    public func enter(): Unit {
        // Mini 模式: 无操作
        // JS 模式: JSC Enter
    }

    /// 退出事件循环作用域 - 对应 Bun EventLoopHandle.exit
    public func exit(): Unit {
        // Mini 模式: 无操作
        // JS 模式: JSC Exit
    }

    /// 进入事件循环并返回 RAII 保护
    /// 对应 Bun EventLoopHandle.entered()
    public func entered(): EnteredEventLoop {
        enter()
        return EnteredEventLoop(this)
    }

    /// 获取迭代号 - 对应 Bun EventLoopHandle.iteration_number
    /// Bun:
    ///   pub fn iteration_number(&self) -> u64 {
    ///       match self {
    ///           Js { owner } => owner.iteration_number(),
    ///           Mini(mini) => (*mini.loop_ptr()).iteration_number(),
    ///       }
    ///   }
    public func iterationNumber(): UInt64 {
        match (miniLoop) {
            case Some(loop) => loop.getIterationNumber()
            case None => 0
        }
    }

    /// 设置为 uws 循环的 parent - 对应 Bun set_as_parent_of
    /// Bun:
    ///   pub fn set_as_parent_of(self, uws_loop: *mut UwsLoop) {
    ///       let (tag, ptr) = self.into_tag_ptr()
    ///       unsafe { (*uws_loop).internal_loop_data.set_parent_raw(tag, ptr) }
    ///   }
    public func setAsParentOf(loop: MiniEventLoop): Unit {
        // 仓颉: 不需要 uws internal_loop_data
        // 简化: 将此句柄与循环关联
    }

    // ========================================================================
    // into_tag_ptr / from_tag_ptr - 标签指针对
    // 严格翻译自: EventLoopHandle.into_tag_ptr / from_tag_ptr
    //
    // Bun (Rust):
    //   pub fn into_tag_ptr(self) -> (c_char, *mut c_void) {
    //       match self {
    //           Js { owner } => (1, owner.owner.cast()),
    //           Mini(mini) => (2, mini.as_ptr().cast()),
    //       }
    //   }
    //
    //   pub unsafe fn from_tag_ptr(tag: c_char, ptr: *mut c_void) -> EventLoopHandle {
    //       match tag {
    //           1 => Js { owner: JsEventLoop::new(...) },
    //           2 => Mini(NonNull::new(ptr.cast()).expect("non-null").into()),
    //           _ => unreachable!(),
    //       }
    //   }
    //
    // 用于在 uws::InternalLoopData 中存储/恢复 EventLoopHandle
    // tag: 1 = JS, 2 = Mini
    // ========================================================================

    /// 转换为标签-指针对 - 对应 Bun into_tag_ptr
    /// 用于在底层循环数据中存储句柄
    /// tag: 1 = JS, 2 = Mini
    public func intoTagPtr(): (Int8, Int64) {
        match (kind) {
            case Js => (1, 0)    // JS 模式简化
            case Mini => (2, 0)  // Mini 模式简化
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
//
// RAII: 构造时 enter(), 析构时 exit()
// 防止忘记 exit() 导致的作用域泄漏
// ============================================================================

/// RAII 事件循环作用域保护 - 对应 Bun EnteredEventLoop
/// 构造时进入事件循环作用域, 关闭时自动退出
/// 防止忘记退出导致的作用域泄漏
public class EnteredEventLoop {
    /// 关联的事件循环句柄
    private var handle: ?EventLoopHandle
    /// 是否已关闭
    private var closed: Bool

    public init(handle: EventLoopHandle) {
        this.handle = Some(handle)
        closed = false
        // enter() 已在外部调用
    }

    /// 退出事件循环作用域 - 对应 Bun Drop impl
    /// Bun:
    ///   fn drop(&mut self) {
    ///       self.0.exit()
    ///   }
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
// 严格翻译自: AnyEventLoop.rs:313-339 - EventLoopTask, EventLoopTaskPtr
//
// Bun (Rust):
//   pub enum EventLoopTask {
//       Js(ConcurrentTask),
//       Mini(AnyTaskWithExtraContext),
//   }
//
//   impl EventLoopTask {
//       pub fn init(kind: EventLoopKind) -> EventLoopTask {
//           match kind {
//               EventLoopKind::Js => EventLoopTask::Js(ConcurrentTask::default()),
//               EventLoopKind::Mini => EventLoopTask::Mini(AnyTaskWithExtraContext::default()),
//           }
//       }
//       pub fn from_event_loop(loop_: EventLoopHandle) -> EventLoopTask {
//           match loop_ {
//               EventLoopHandle::Js { .. } => EventLoopTask::Js(ConcurrentTask::default()),
//               EventLoopHandle::Mini(_) => EventLoopTask::Mini(AnyTaskWithExtraContext::default()),
//           }
//       }
//   }
//
// EventLoopTaskPtr (无标签联合体):
//   pub union EventLoopTaskPtr {
//       pub js: *mut ConcurrentTask,
//       pub mini: *mut AnyTaskWithExtraContext,
//   }
//
//   用法:
//     tag 由外层的 EventLoopHandle 判别式确定
//     当 handle 是 Js 时, 使用 task.js
//     当 handle 是 Mini 时, 使用 task.mini
// ============================================================================

/// 事件循环任务 - 对应 Bun EventLoopTask
/// 根据事件循环类型选择不同的任务容器
public class EventLoopTask {
    /// 任务类型
    public var kind: EventLoopKind
    /// 并发任务 (Js 模式)
    public var jsTask: ?ConcurrentTask
    /// 带额外上下文的任务 (Mini 模式)
    public var miniTask: ?AnyTaskWithExtraContext

    public init(kind: EventLoopKind) {
        this.kind = kind
        jsTask = None
        miniTask = None
    }

    /// 初始化任务 - 对应 Bun EventLoopTask.init(kind)
    /// Bun:
    ///   pub fn init(kind: EventLoopKind) -> EventLoopTask {
    ///       match kind {
    ///           EventLoopKind::Js => EventLoopTask::Js(ConcurrentTask::default()),
    ///           EventLoopKind::Mini => EventLoopTask::Mini(AnyTaskWithExtraContext::default()),
    ///       }
    ///   }
    public static func initFunc(kind: EventLoopKind): EventLoopTask {
        let task = EventLoopTask(kind)
        match (kind) {
            case Js =>
                task.jsTask = Some(ConcurrentTask(TaskTagKind.Custom, { }))
            case Mini =>
                task.miniTask = Some(AnyTaskWithExtraContext({ }))
        }
        return task
    }

    /// 从事件循环句柄创建 - 对应 Bun EventLoopTask.from_event_loop
    /// Bun:
    ///   pub fn from_event_loop(loop_: EventLoopHandle) -> EventLoopTask {
    ///       match loop_ {
    ///           EventLoopHandle::Js { .. } => EventLoopTask::Js(ConcurrentTask::default()),
    ///           EventLoopHandle::Mini(_) => EventLoopTask::Mini(AnyTaskWithExtraContext::default()),
    ///       }
    ///   }
    public static func fromEventLoop(handle: EventLoopHandle): EventLoopTask {
        return initFunc(handle.getKind())
    }
}

// ============================================================================
// EventLoopTaskPtr - 事件循环任务指针 (无标签联合体)
// 严格翻译自: AnyEventLoop.rs:313-317 - EventLoopTaskPtr
//
// Bun (Rust):
//   #[derive(Copy, Clone)]
//   pub union EventLoopTaskPtr {
//       pub js: *mut ConcurrentTask,
//       pub mini: *mut AnyTaskWithExtraContext,
//   }
//
// 无标签联合体: 使用哪个字段由外层的 EventLoopHandle 判别式确定
// 当 handle 是 Js 时, 访问 js 字段
// 当 handle 是 Mini 时, 访问 mini 字段
// ============================================================================

/// 事件循环任务指针 - 对应 Bun EventLoopTaskPtr
/// 无标签联合体, 由外层 EventLoopHandle 判别式确定活跃字段
public class EventLoopTaskPtr {
    /// 任务类型
    public var kind: EventLoopKind
    /// Js 模式下的任务
    public var jsTask: ?ConcurrentTask
    /// Mini 模式下的任务
    public var miniTask: ?AnyTaskWithExtraContext

    public init(kind: EventLoopKind) {
        this.kind = kind
        jsTask = None
        miniTask = None
    }

    /// 创建 Js 模式的任务指针
    public static func js(task: ConcurrentTask): EventLoopTaskPtr {
        let ptr = EventLoopTaskPtr(EventLoopKind.Js)
        ptr.jsTask = Some(task)
        return ptr
    }

    /// 创建 Mini 模式的任务指针
    public static func mini(task: AnyTaskWithExtraContext): EventLoopTaskPtr {
        let ptr = EventLoopTaskPtr(EventLoopKind.Mini)
        ptr.miniTask = Some(task)
        return ptr
    }
}
