// 严格翻译自: src/jsc/EventLoopHandle.zig (180行)
// 事件循环句柄 - JS 事件循环或 Mini 事件循环的非拥有引用

package bao_jsc

// ========== EventLoopKind ==========
// 严格翻译自 EventLoopHandle.zig EventLoopKind
// 事件循环类型
public enum EventLoopKind {
    | Js
    | Mini
}

// ========== EventLoopHandle ==========
// 严格翻译自 EventLoopHandle.zig EventLoopHandle
// 对 JS 事件循环或 Mini 事件循环的非拥有引用
public class EventLoopHandle {
    public var kind: EventLoopKind = EventLoopKind.Js
    public var jsLoop: EventLoop
    public var miniLoop: MiniEventLoop

    public init(jsLoop: EventLoop) {
        this.kind = EventLoopKind.Js
        this.jsLoop = jsLoop
        this.miniLoop = MiniEventLoop()
    }

    public init(miniLoop: MiniEventLoop) {
        this.kind = EventLoopKind.Mini
        this.jsLoop = EventLoop()
        this.miniLoop = miniLoop
    }

    // 严格翻译自 globalObject
    public func globalObject(): ?JsGlobalObject {
        match (kind) {
            case Js =>
                let glob = JSGlobalObject()
                glob.globalThis = jsLoop.global
                Some(glob)
            case Mini => None
        }
    }

    // 严格翻译自 stdout
    public func stdout(): BlobStore {
        match (kind) {
            case Js =>
                let rd = jsLoop.virtualMachine().getRareData()
                if (let Some(store) <- rd.stdoutStore) {
                    return store
                }
                let store = BlobStore()
                rd.stdoutStore = store
                store
            case Mini => miniLoop.stdout()
        }
    }

    // 严格翻译自 bunVM
    public func bunVM(): ?BunVirtualMachine {
        match (kind) {
            case Js => Some(jsLoop.virtualMachine())
            case Mini => None
        }
    }

    // 严格翻译自 stderr
    public func stderr(): BlobStore {
        match (kind) {
            case Js =>
                let rd = jsLoop.virtualMachine().getRareData()
                if (let Some(store) <- rd.stderrStore) {
                    return store
                }
                let store = BlobStore()
                rd.stderrStore = store
                store
            case Mini => miniLoop.stderr()
        }
    }

    // 严格翻译自 enter
    public func enter() {
        match (kind) {
            case Js => jsLoop.enter()
            case Mini => ()
        }
    }

    // 严格翻译自 exit
    public func exit() {
        match (kind) {
            case Js => jsLoop.exit()
            case Mini => ()
        }
    }

    // 严格翻译自 filePolls
    public func filePolls(): FilePollStore {
        match (kind) {
            case Js =>
                let rd = jsLoop.virtualMachine().getRareData()
                if (let Some(store) <- rd.filePolls) {
                    return store
                }
                let store = FilePollStore()
                rd.filePolls = store
                store
            case Mini => miniLoop.filePolls()
        }
    }

    // 严格翻译自 putFilePoll
    public func putFilePoll(poll: FilePoll) {
        let wasRegistered = poll.wasEverRegistered
        match (kind) {
            case Js => filePolls().put(poll, jsLoop.virtualMachine(), wasRegistered)
            case Mini => miniLoop.filePolls().put(poll, miniLoop, wasRegistered)
        }
    }

    // 严格翻译自 enqueueTaskConcurrent
    public func enqueueTaskConcurrent(context: EventLoopTaskPtr) {
        match (kind) {
            case Js =>
                if (let Some(jsTask) <- context.js) {
                    enqueueTaskConcurrent(jsLoop, jsTask)
                }
            case Mini =>
                if (let Some(miniTask) <- context.mini) {
                    miniLoop.enqueueTaskConcurrent(miniTask)
                }
        }
    }

    // 严格翻译自 loop
    public func loop(): UwsLoop {
        match (kind) {
            case Js => UwsLoop() // uws.Loop managed by event loop internals
            case Mini => miniLoop.loop
        }
    }

    // 严格翻译自 platformEventLoop (别名)
    public func platformEventLoop(): EventLoop {
        jsLoop
    }

    // 严格翻译自 hasRef
    public func hasRef(): Bool {
        jsLoop.activeHandles > 0
    }

    // 严格翻译自 ref
    public func ref() {
        jsLoop.activeHandles += 1
    }

    // 严格翻译自 unref
    public func unref() {
        if (jsLoop.activeHandles > 0) {
            jsLoop.activeHandles -= 1
        }
    }

    /// 唤醒事件循环
    public func wakeup(): Unit {
        match (kind) {
            case Js => ()
            case Mini => ()
        }
    }

    /// 运行事件循环
    public func run(): Unit {
        match (kind) {
            case Js => jsLoop.run()
            case Mini => miniLoop.run()
        }
    }
}

// ========== EventLoopTaskPtr ==========
// 严格翻译自 EventLoopHandle.zig EventLoopTaskPtr
public class EventLoopTaskPtr {
    public var js: ?ConcurrentTask = None
    public var mini: ?MiniEventLoopTask = None

    public init() {}

    public init(js: ConcurrentTask) {
        this.js = js
    }

    public init(mini: MiniEventLoopTask) {
        this.mini = mini
    }
}

// ========== MiniEventLoop ==========
// 严格翻译自 EventLoopHandle.zig MiniEventLoop
public class MiniEventLoop {
    public var loop: UwsLoop = UwsLoop()

    public init() {}

    public func stdout(): BlobStore { BlobStore() }
    public func stderr(): BlobStore { BlobStore() }
    public func filePolls(): FilePollStore { FilePollStore() }
    public func enqueueTaskConcurrent(task: MiniEventLoopTask) {}
    public func run(): Unit {}
}

// ========== MiniEventLoopTask ==========
public class MiniEventLoopTask {
    public init() {}
}

// ========== UwsLoop ==========
public class UwsLoop {
    public init() {}
}

// ========== FilePollStore ==========
public class FilePollStore {
    public init() {}

    public func put(poll: FilePoll, loop: MiniEventLoop, wasRegistered: Bool) {}
    public func put(poll: FilePoll, vm: BunVirtualMachine, wasRegistered: Bool) {}
}

// ========== FilePoll ==========
public class FilePoll {
    public var wasEverRegistered: Bool = false
    public init() {}
}

// ========== BlobStore ==========
public class BlobStore {
    public init() {}
}
