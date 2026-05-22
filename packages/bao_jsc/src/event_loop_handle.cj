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
        None // TODO: jsLoop.global is JsObject, not JsGlobalObject
    }

    // 严格翻译自 stdout
    public func stdout(): BlobStore {
        BlobStore() // TODO: stub
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
        BlobStore() // TODO: stub
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
        FilePollStore() // TODO: stub
    }

    // 严格翻译自 putFilePoll
    public func putFilePoll(poll: FilePoll) {
        // TODO: stub
    }

    // 严格翻译自 enqueueTaskConcurrent
    public func enqueueTaskConcurrent(context: EventLoopTaskPtr) {
        // TODO: stub
    }

    // 严格翻译自 loop
    public func loop(): UwsLoop {
        UwsLoop() // TODO: stub
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
