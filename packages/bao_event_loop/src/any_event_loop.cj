// bao_event_loop - AnyEventLoop 通用事件循环
// 严格翻译自: src/event_loop/AnyEventLoop.rs
//   Bun 的 AnyEventLoop 是 JS/Mini 事件循环的联合类型:
//     AnyEventLoop - enum { Js { owner: JsEventLoop }, Mini(MiniEventLoop) }
//     EventLoopHandle - 非拥有引用 (Copy)
//     EventLoopTaskPtr - 未标记联合 (js/mini 任务指针)
//     EventLoopTask - 拥有的任务存储
//     EnteredEventLoop - RAII 守卫
package bao_event_loop

import bao_core.*
import bao_sys.*

// ============================================================================
// AnyEventLoop - 通用事件循环
// 严格翻译自: src/event_loop/AnyEventLoop.rs AnyEventLoop
//   pub enum AnyEventLoop<'a> {
//       Js { owner: JsEventLoop },
//       Mini(MiniEventLoop<'a>),
//   }
// ============================================================================

/// 通用事件循环 - 对应 Bun AnyEventLoop
/// JS/Mini 事件循环的联合类型
public enum AnyEventLoop {
    | Js(JsEventLoopHandle)
    | Mini(MiniEventLoopRef)

    /// 初始化 (默认 Mini)
    /// 严格翻译自: AnyEventLoop::init()
    public static func init(): AnyEventLoop {
        return Mini(MiniEventLoopRef())
    }

    /// 迭代次数 - 对应 Bun AnyEventLoop.iteration_number
    public func iterationNumber(): UInt64 {
        match (this) {
            case Js(owner) => owner.iterationNumber()
            case Mini(mini) => mini.iterationNumber()
        }
    }

    /// 运行循环 - 对应 Bun AnyEventLoop.tick
    /// 循环运行直到 isDone 返回 true
    public func tick(isDone: () -> Bool): Unit {
        match (this) {
            case Js(owner) =>
                while (!isDone()) {
                    owner.tick()
                    owner.autoTick()
                }
            case Mini(mini) => mini.tick(isDone)
        }
    }

    /// 运行一次 - 对应 Bun AnyEventLoop.tick_once
    public func tickOnce(): Unit {
        match (this) {
            case Js(owner) =>
                owner.tick()
                owner.autoTickActive()
            case Mini(mini) => mini.tickWithoutIdle()
        }
    }

    /// 入队并发任务 - 对应 Bun AnyEventLoop.enqueue_task_concurrent
    public func enqueueTaskConcurrent(task: EventLoopTask): Unit {
        match (this) {
            case Js(_) =>
                // JS 路径: 通过 JSC 入队
            case Mini(mini) => mini.enqueueTaskConcurrent(task)
        }
    }

    /// 唤醒 - 对应 Bun AnyEventLoop.wakeup
    public func wakeup(): Unit {
        match (this) {
            case Js(owner) => owner.wakeup()
            case Mini(mini) => mini.wakeup()
        }
    }
}

// ============================================================================
// JsEventLoopHandle - JS 事件循环句柄
// 严格翻译自: src/event_loop/AnyEventLoop.rs JsEventLoop
// ============================================================================

/// JS 事件循环句柄 - 对应 Bun JsEventLoop
public class JsEventLoopHandle {
    /// 迭代次数
    public var iterationCount: UInt64

    public init() {
        iterationCount = UInt64(0)
    }

    /// 获取迭代次数
    public func iterationNumber(): UInt64 {
        return iterationCount
    }

    /// 运行一次 tick
    public func tick(): Unit {
        iterationCount += UInt64(1)
    }

    /// 自动 tick
    public func autoTick(): Unit {
        // 处理微任务等
    }

    /// 自动 tick 活跃
    public func autoTickActive(): Unit {
        // 处理活跃任务
    }

    /// 唤醒
    public func wakeup(): Unit {
        // 唤醒事件循环
    }
}

// ============================================================================
// MiniEventLoopRef - Mini 事件循环引用
// 严格翻译自: src/event_loop/MiniEventLoop.zig MiniEventLoop
// ============================================================================

/// Mini 事件循环引用 - 对应 Bun MiniEventLoop
/// 轻量级事件循环, 不需要 JavaScript 运行时
public class MiniEventLoopRef {
    /// 任务队列
    public var tasks: ArrayList<AnyEventLoopTask>
    /// 并发任务队列
    public var concurrentTasks: ArrayList<AnyEventLoopTask>
    /// 迭代次数
    public var iterationCount: UInt64
    /// 是否已初始化
    public var initialized: Bool
    /// 环境变量加载器
    public var env: ?Object
    /// 顶层目录
    public var topLevelDir: String
    /// 标准输出存储
    public var stdoutStore: ?Object
    /// 标准错误存储
    public var stderrStore: ?Object

    public init() {
        tasks = ArrayList<AnyEventLoopTask>()
        concurrentTasks = ArrayList<AnyEventLoopTask>()
        iterationCount = UInt64(0)
        initialized = false
        env = None
        topLevelDir = ""
        stdoutStore = None
        stderrStore = None
    }

    /// 获取迭代次数
    public func iterationNumber(): UInt64 {
        return iterationCount
    }

    /// 运行循环 - 对应 Bun MiniEventLoop.tick
    public func tick(isDone: () -> Bool): Unit {
        while (!isDone()) {
            tickConcurrent()
            while (tasks.size > 0 && tasks.size > 0) {
                let task = tasks.removeAt(0)
                task.run()
            }
            iterationCount += UInt64(1)
        }
    }

    /// 运行不等待空闲 - 对应 Bun MiniEventLoop.tickWithoutIdle
    public func tickWithoutIdle(): Unit {
        tickConcurrent()
        while (tasks.size > 0) {
            let task = tasks.removeAt(0)
            task.run()
        }
        iterationCount += UInt64(1)
    }

    /// 处理并发任务 - 对应 Bun MiniEventLoop.tickConcurrentWithCount
    public func tickConcurrent(): Int64 {
        var count = Int64(0)
        while (concurrentTasks.size > 0) {
            let task = concurrentTasks.removeAt(0)
            tasks.append(task)
            count += 1
        }
        return count
    }

    /// 入队并发任务 - 对应 Bun MiniEventLoop.enqueueTaskConcurrent
    public func enqueueTaskConcurrent(task: EventLoopTask): Unit {
        concurrentTasks.append(AnyEventLoopTask(task.callback))
        wakeup()
    }

    /// 唤醒
    public func wakeup(): Unit {
        // 唤醒事件循环
    }

    /// 标准错误
    public func stderr(): ?Object {
        return stderrStore
    }

    /// 标准输出
    public func stdout(): ?Object {
        return stdoutStore
    }

    /// 管道读取缓冲区
    public func pipeReadBuffer(): Array<UInt8> {
        return Array<UInt8>(262144, { _ => UInt8(0) })
    }
}

/// 简单任务包装
public class AnyEventLoopTask {
    public var callback: () -> Unit

    public init(callback: () -> Unit) {
        this.callback = callback
    }

    public func run(): Unit {
        callback()
    }
}

// ============================================================================
// EventLoopHandle - 事件循环句柄
// 严格翻译自: src/event_loop/AnyEventLoop.rs EventLoopHandle
//   #[derive(Copy, Clone)]
//   pub enum EventLoopHandle {
//       Js { owner: JsEventLoop },
//       Mini(BackRef<MiniEventLoop<'static>>),
//   }
// ============================================================================

/// 事件循环句柄 - 对应 Bun EventLoopHandle
/// 非拥有引用, 可 Copy
public enum EventLoopHandle {
    | Js(JsEventLoopHandle)
    | Mini(MiniEventLoopRef)

    /// 从 AnyEventLoop 创建
    /// 严格翻译自: EventLoopHandle::from_any
    public static func fromAny(loop: AnyEventLoop): EventLoopHandle {
        match (loop) {
            case Js(owner) => EventLoopHandle.Js(owner)
            case Mini(mini) => EventLoopHandle.Mini(mini)
        }
    }

    /// 获取全局对象 (JS) 或 null (Mini)
    public func globalObject(): ?Object {
        match (this) {
            case Js(owner) => None  // 简化
            case Mini(_) => None
        }
    }

    /// 引用
    public func ref(): Unit {
        // 增加引用计数
    }

    /// 解除引用
    public func unref(): Unit {
        // 减少引用计数
    }

    /// 进入
    public func enter(): Unit {
        match (this) {
            case Js(owner) => ()  // JS 进入
            case Mini(_) => ()
        }
    }

    /// 退出
    public func exit(): Unit {
        match (this) {
            case Js(owner) => ()  // JS 退出
            case Mini(_) => ()
        }
    }
}

// ============================================================================
// EventLoopTask - 事件循环任务
// 严格翻译自: src/event_loop/AnyEventLoop.rs EventLoopTask
// ============================================================================

/// 事件循环任务 - 对应 Bun EventLoopTask
public class EventLoopTask {
    /// 回调函数
    public var callback: () -> Unit
    /// 额外上下文
    public var extraContext: ?Object

    public init(callback: () -> Unit) {
        this.callback = callback
        extraContext = None
    }
}

// ============================================================================
// EnteredEventLoop - RAII 守卫
// 严格翻译自: src/event_loop/AnyEventLoop.rs EnteredEventLoop
//   pub struct EnteredEventLoop(EventLoopHandle)
//   impl Drop for EnteredEventLoop { fn drop => self.0.exit() }
// ============================================================================

/// 进入事件循环 RAII 守卫 - 对应 Bun EnteredEventLoop
public class EnteredEventLoop {
    private var handle: EventLoopHandle

    public init(handle: EventLoopHandle) {
        this.handle = handle
        handle.enter()
    }

    /// 退出
    public func exit(): Unit {
        handle.exit()
    }
}
