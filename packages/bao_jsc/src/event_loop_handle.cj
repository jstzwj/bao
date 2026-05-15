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
    public func globalObject() -> ?JsGlobalObject {
        match (kind) {
            case Js => jsLoop.global
            case Mini => None
        }
    }

    // 严格翻译自 stdout
    public func stdout() -> BlobStore {
        match (kind) {
            case Js => jsLoop.virtualMachine.rareData().stdout()
            case Mini => miniLoop.stdout()
        }
    }

    // 严格翻译自 bunVM
    public func bunVM() -> ?VirtualMachine {
        match (kind) {
            case Js => jsLoop.virtualMachine
            case Mini => None
        }
    }

    // 严格翻译自 stderr
    public func stderr() -> BlobStore {
        match (kind) {
            case Js => jsLoop.virtualMachine.rareData().stderr()
            case Mini => miniLoop.stderr()
        }
    }

    // 严格翻译自 enter
    public func enter() {
        match (kind) {
            case Js => jsLoop.enter()
            case Mini => {}
        }
    }

    // 严格翻译自 exit
    public func exit() {
        match (kind) {
            case Js => jsLoop.exit()
            case Mini => {}
        }
    }

    // 严格翻译自 filePolls
    public func filePolls() -> FilePollStore {
        match (kind) {
            case Js => jsLoop.virtualMachine.rareData().filePolls(jsLoop.virtualMachine)
            case Mini => miniLoop.filePolls()
        }
    }

    // 严格翻译自 putFilePoll
    public func putFilePoll(poll: FilePoll) {
        match (kind) {
            case Js => {
                jsLoop.virtualMachine.rareData().filePolls(jsLoop.virtualMachine).put(
                    poll, jsLoop.virtualMachine, poll.wasEverRegistered
                )
            }
            case Mini => {
                miniLoop.filePolls().put(poll, miniLoop, poll.wasEverRegistered)
            }
        }
    }

    // 严格翻译自 enqueueTaskConcurrent
    public func enqueueTaskConcurrent(context: EventLoopTaskPtr) {
        match (kind) {
            case Js => {
                jsLoop.enqueueTaskConcurrent(context.js)
            }
            case Mini => {
                miniLoop.enqueueTaskConcurrent(context.mini)
            }
        }
    }

    // 严格翻译自 loop
    public func loop() -> UwsLoop {
        match (kind) {
            case Js => jsLoop.usocketsLoop()
            case Mini => miniLoop.loop
        }
    }

    // 严格翻译自 platformEventLoop (别名)
    public func platformEventLoop() -> UwsLoop {
        loop()
    }

    // 严格翻译自 ref
    public func ref() {
        loop().ref()
    }

    // 严格翻译自 unref
    public func unref() {
        loop().unref()
    }

    // 严格翻译自 allocator
    public func allocator() -> Allocator {
        match (kind) {
            case Js => jsLoop.virtualMachine.allocator
            case Mini => miniLoop.allocator
        }
    }

    // 严格翻译自 topLevelDir
    public func topLevelDir() -> String {
        match (kind) {
            case Js => jsLoop.virtualMachine.transpiler.fs.topLevelDir
            case Mini => miniLoop.topLevelDir
        }
    }

    // 严格翻译自 env
    public func env() -> DotEnvLoader {
        match (kind) {
            case Js => jsLoop.virtualMachine.transpiler.env
            case Mini => miniLoop.env
        }
    }

    // 严格翻译自 pipeReadBuffer
    public func pipeReadBuffer() -> Array<UInt8> {
        match (kind) {
            case Js => jsLoop.pipeReadBuffer()
            case Mini => miniLoop.pipeReadBuffer()
        }
    }
}

// ========== EventLoopTask ==========
// 严格翻译自 EventLoopHandle.zig EventLoopTask
// 事件循环任务
public class EventLoopTask {
    public var kind: EventLoopKind = EventLoopKind.Js
    public var jsTask: ConcurrentTask = ConcurrentTask()
    public var miniTask: AnyTaskWithExtraContext = AnyTaskWithExtraContext()

    public init(kind: EventLoopKind) {
        this.kind = kind
    }

    // 严格翻译自 fromEventLoop
    public static func fromEventLoop(loop_: EventLoopHandle) -> EventLoopTask {
        match (loop_.kind) {
            case Js => EventLoopTask(EventLoopKind.Js)
            case Mini => EventLoopTask(EventLoopKind.Mini)
        }
    }
}

// ========== EventLoopTaskPtr ==========
// 严格翻译自 EventLoopHandle.zig EventLoopTaskPtr
// 事件循环任务指针
public class EventLoopTaskPtr {
    public var js: ConcurrentTask = ConcurrentTask()
    public var mini: AnyTaskWithExtraContext = AnyTaskWithExtraContext()
    public var kind: EventLoopKind = EventLoopKind.Js

    public init(js: ConcurrentTask) {
        this.kind = EventLoopKind.Js
        this.js = js
    }

    public init(mini: AnyTaskWithExtraContext) {
        this.kind = EventLoopKind.Mini
        this.mini = mini
    }
}

// ========== 辅助类型定义 ==========
// 这些类型在此文件中作为占位符声明，实际实现在其他文件中

// MiniEventLoop 占位
public class MiniEventLoop {
    public var loop: UwsLoop = UwsLoop()
    public var allocator: Allocator = Allocator()
    public var topLevelDir: String = ""
    public var env: DotEnvLoader = DotEnvLoader()

    public init() {}

    public func stdout() -> BlobStore { BlobStore() }
    public func stderr() -> BlobStore { BlobStore() }
    public func filePolls() -> FilePollStore { FilePollStore() }
    public func pipeReadBuffer() -> Array<UInt8> { Array<UInt8>() }
    public func enqueueTaskConcurrent(task: AnyTaskWithExtraContext) {}
}

// BlobStore 占位
public class BlobStore {
    public init() {}
}

// FilePollStore 占位
public class FilePollStore {
    public init() {}
    public func put(poll: FilePoll, vm: VirtualMachine, wasRegistered: Bool) {}
    public func put(poll: FilePoll, loop_: MiniEventLoop, wasRegistered: Bool) {}
}

// FilePoll 占位
public class FilePoll {
    public var wasEverRegistered: Bool = false
    public init() {}
}

// UwsLoop 占位
public class UwsLoop {
    public init() {}
    public func ref() {}
    public func unref() {}
}

// Allocator 占位
public class Allocator {
    public init() {}
}

// DotEnvLoader 占位
public class DotEnvLoader {
    public init() {}
}

// ConcurrentTask 占位
public class ConcurrentTask {
    public init() {}
}

// AnyTaskWithExtraContext 占位
public class AnyTaskWithExtraContext {
    public init() {}
}
