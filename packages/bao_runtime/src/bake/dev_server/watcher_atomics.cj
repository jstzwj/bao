// 翻译自 Bun: src/runtime/bake/DevServer/WatcherAtomics.zig
// 所有使用原子操作在 watcher <-> DevServer 之间通信的代码都在这里。

package bao_runtime.bake.dev_server

/// WatcherAtomics - 监控器原子操作
public class WatcherAtomics {
    public var events: Array<HotReloadEvent>
    public var next_event: Atomic<UInt8>
    public var current_event: ?UInt8
    public var pending_event: ?UInt8

    public static let nextEventWaiting: UInt8 = 254
    public static let nextEventDone: UInt8 = 255

    public init() {
        events = []
        next_event = Atomic<UInt8>(WatcherAtomics.nextEventDone)
        current_event = None
        pending_event = None
    }

    public static func initFunc(dev: DevServer): WatcherAtomics {
        var self = WatcherAtomics()
        for (i in 0..self.events.size) {
            self.events[i] = HotReloadEvent.initEmpty(dev)
        }
        return self
    }

    public func watcherAcquireEvent(): HotReloadEvent {
        var available: Array<Bool> = [true, true, true]
        if (let Some(i) <- current_event) { available[Int64(i)] = false }
        if (let Some(i) <- pending_event) { available[Int64(i)] = false }

        var index: Int64 = 0
        for (i in 0..available.size) {
            if (available[i]) { index = Int64(i); break }
        }
        let ev = events[Int64(index)]

        if (ev.isEmpty()) {
            // ev.timer = Timer.start()
        }

        return ev
    }

    public func watcherReleaseAndSubmitEvent(ev: HotReloadEvent): Unit {
        if (ev.isEmpty()) { return }

        // stub: simplified event submission
        var ev_index: UInt8 = 0

        current_event = ev_index
        pending_event = None
        next_event.store(WatcherAtomics.nextEventWaiting, AtomicOrdering.monotonic)
        let concurrent_task = ConcurrentTask(Task(ev))
        ev.owner.vm.event_loop.enqueueTaskConcurrent(concurrent_task)
    }

    public func recycleEventFromDevServer(old_event: HotReloadEvent): ?HotReloadEvent {
        old_event.reset()

        while (true) {
            let next = next_event.swap(WatcherAtomics.nextEventWaiting, AtomicOrdering.acqRel)
            if (next == WatcherAtomics.nextEventWaiting) {
                if (next_event.cmpxchgWeak(WatcherAtomics.nextEventWaiting, WatcherAtomics.nextEventDone, AtomicOrdering.release, AtomicOrdering.monotonic).isSome()) {
                    continue
                }
                return None
            } else if (next == WatcherAtomics.nextEventDone) {
                throw Exception("unreachable: nextEventDone in recycleEventFromDevServer")
            } else {
                return events[Int64(next)]
            }
        }
        return None
    }
}
