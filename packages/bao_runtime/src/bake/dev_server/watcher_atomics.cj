// 翻译自 Bun: src/runtime/bake/DevServer/WatcherAtomics.zig
// 所有使用原子操作在 watcher <-> DevServer 之间通信的代码都在这里。
// 它尝试尽可能回收内存，因为文件非常频繁地更新（HMR 的全部意义）。

package bao_runtime.bake.dev_server

/// WatcherAtomics - 监控器原子操作
/// 管理 watcher 线程和 DevServer 线程之间的通信。
/// 使用原子操作来安全地传递热重载事件。
public class WatcherAtomics {
    /// 一次只能运行一个事件。我们需要三个事件因为：
    ///
    /// * 一个事件可能在 DevServer 线程上活跃运行。
    /// * 一个事件可能是"待定"的，即它由 watcher 线程添加但没有立即启动，
    ///   因为事件已经在运行。
    /// * 一个事件必须可用于 watcher 线程初始化和提交。如果事件已经待定，
    ///   新事件将替换待定的，待定的将变为可用。
    public var events: Array<HotReloadEvent>  // 长度 3

    /// 下一个要运行的事件。如果事件已在运行，新事件存储在此字段中，
    /// 而不是直接调度，将在当前事件完成后运行。
    public var next_event: Atomic<UInt8> = Atomic<UInt8>(NextEvent.done)

    /// 只有 watcher 线程使用这两个字段。它们都是 events 数组的索引，
    /// 指示哪些元素正在使用，不可修改。最多只能有两个这样的事件在用，
    /// 所以我们总是能在长度为 3 的数组中找到空闲事件。
    public var current_event: ?UInt8 = None
    public var pending_event: ?UInt8 = None

    /// NextEvent 枚举值
    public struct NextEvent <: UInt8 {
        /// 事件正在运行，没有下一个事件待定
        public static let waiting: UInt8 = UInt8.max - 1
        /// 没有事件正在运行
        public static let done: UInt8 = UInt8.max
        /// 任何其他值表示 events 数组的索引
    }

    /// 初始化
    public static func init(dev: DevServer): WatcherAtomics {
        var self = WatcherAtomics(events: Array<HotReloadEvent>(3))
        for (event in self.events) {
            event = HotReloadEvent.initEmpty(dev)
        }
        return self
    }

    /// 原子地获取一个不被 DevServer 线程使用的 HotReloadEvent。
    /// 当填满文件后调用 watcherRelease。
    ///
    /// 从 watcher 线程调用。
    public func watcherAcquireEvent(): HotReloadEvent {
        var available: Array<Bool> = [true, true, true]
        if (let Some(i) = current_event) { available[i] = false }
        if (let Some(i) = pending_event) { available[i] = false }

        let index = available.first(true)
        let ev = events[index]

        // 如果事件为空则初始化定时器
        if (ev.isEmpty()) {
            ev.timer = Timer.start()
        }

        return ev
    }

    /// 释放 watcherAcquireEvent 返回的指针，如果包含新文件则提交事件。
    ///
    /// 从 watcher 线程调用。
    public func watcherReleaseAndSubmitEvent(ev: HotReloadEvent): Unit {
        if (ev.isEmpty()) { return }

        let ev_index: UInt8 = UInt8(ev - events[0])
        let old_next = next_event.swap(ev_index, .acq_rel)
        match (old_next) {
            case NextEvent.done =>
                // DevServer 完成运行事件。我们需要直接调度事件。
                current_event = ev_index
                pending_event = None
                next_event.store(NextEvent.waiting, .monotonic)
                ev.concurrent_task = ConcurrentTask(task: Task.init(ev))
                ev.owner.vm.event_loop.enqueueTaskConcurrent(ev.concurrent_task)

            case NextEvent.waiting =>
                if (pending_event != None) {
                    current_event = pending_event
                }
                pending_event = ev_index

            case _ =>
                // 旧待定事件尚未运行，用 ev 替换
                let old_index: UInt8 = old_next
                pending_event = ev_index
        }
    }

    /// DevServer 接收任务回调后调用此函数。如果返回另一个事件，
    /// 该事件应再次传递给此函数，依此类推，直到返回 null。
    ///
    /// 在 DevServer 线程上运行。
    public func recycleEventFromDevServer(old_event: HotReloadEvent): ?HotReloadEvent {
        old_event.reset()

        while (true) {
            let next = next_event.swap(NextEvent.waiting, .acq_rel)
            match (next) {
                case NextEvent.waiting =>
                    if (next_event.cmpxchgWeak(NextEvent.waiting, NextEvent.done, .release, .monotonic) != None) {
                        continue  // 可能添加了另一个事件
                    }
                    return None  // 完成运行事件
                case NextEvent.done => unreachable
                case _ => return events[next]
            }
        }
        return None
    }
}

// 类型别名
public type Atomic<T> = std.atomic.Value<T>
public type ConcurrentTask = jsc.ConcurrentTask
public type Task = jsc.Task
public type Timer = std.time.Timer
