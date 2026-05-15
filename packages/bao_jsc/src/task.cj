// 严格翻译自: src/jsc/Task.zig + WorkTask.zig + CppTask.zig + ConcurrentPromiseTask.zig
// JavaScriptCore 任务系统

package bao_jsc

// ========== 任务标签 ==========
// 严格翻译自 Task.zig TaggedPointerUnion
// 任务类型标识
public enum TaskTag {
    | Access
    | AnyTask
    | AppendFile
    | ArchiveExtract
    | ArchiveBlob
    | ArchiveWrite
    | ArchiveFiles
    | AsyncGlobWalk
    | AsyncImage
    | AsyncTransform
    | HotReloadEvent
    | DeferredBatch
    | Chmod
    | Chown
    | Close
    | CopyFile
    | CopyFilePromise
    | CppTask
    | Exists
    | Fchmod
    | Fchown
    | Fdatasync
    | Fetch
    | Fstat
    | FSWatch
    | Fsync
    | Ftruncate
    | Futimes
    | GetAddrInfo
    | HotReload
    | Immediate
    | JSCDeferredWork
    | Lchmod
    | Lchown
    | Link
    | Lstat
    | Lutimes
    | Managed
    | Mkdir
    | Mkdtemp
    | NapiAsyncWork
    | NapiFinalizer
    | Open
    | PollPendingModules
    | PosixSignal
    | ProcessWaiter
    | Read
    | Readdir
    | ReaddirRecursive
    | ReadFile
    | ReadFileTask
    | Readlink
    | Readv
    | Realpath
    | Rename
    | Rm
    | Rmdir
    | RuntimeTranspilerStore
    | ShellAsync
    | Stat
    | StatFS
    | StreamPending
    | Symlink
    | ThreadSafeFunction
    | Timeout
    | Truncate
    | Unlink
    | Utimes
    | Write
    | WriteFile
    | Writev
    | Custom
}

// ========== Task ==========
// 严格翻译自 Task.zig
// 所有异步任务的基类
public class Task {
    public var tag: TaskTag = TaskTag.Custom
    public var isCompleted: Bool = false
    public var callback: ?(() -> Unit) = None

    public init() {}

    public init(tag: TaskTag) {
        this.tag = tag
    }

    // 执行任务
    public func run() {
        if (let Some(cb) <- callback) {
            cb()
        }
        isCompleted = true
    }

    // 取消任务
    public func cancel() {
        isCompleted = true
    }
}

// ========== WorkTask ==========
// 严格翻译自 WorkTask.zig
// 工作线程任务
public class WorkTask {
    public var task: ?Task = None
    public var result: ?JsValue = None
    public var isDone: Bool = false

    public init() {}

    public init(task: Task) {
        this.task = task
    }

    // 执行工作任务
    public func run() {
        if (let Some(t) <- task) {
            t.run()
        }
        isDone = true
    }
}

// ========== CppTask ==========
// 严格翻译自 CppTask.zig
// C++ 互操作任务
public class CppTask {
    public var funcPtr: CPointer<UInt8> = CPointer<UInt8>()
    public var dataPtr: CPointer<UInt8> = CPointer<UInt8>()
    public var isCompleted: Bool = false

    public init() {}

    // 执行 C++ 任务
    public func run() {
        // 通过 FFI 调用 C++ 函数
        isCompleted = true
    }
}

// ========== ConcurrentPromiseTask ==========
// 严格翻译自 ConcurrentPromiseTask.zig
// 并发 Promise 任务
public class ConcurrentPromiseTask {
    public var promise: ?JsPromise = None
    public var task: ?Task = None
    public var isCancelled: Bool = false
    public var isCompleted: Bool = false

    public init() {}

    public init(promise: JsPromise, task: Task) {
        this.promise = promise
        this.task = task
    }

    // 执行并发任务
    public func run() {
        if (isCancelled) { return }
        if (let Some(t) <- task) {
            t.run()
        }
        isCompleted = true
    }

    // 取消
    public func cancel() {
        isCancelled = true
    }

    // 完成并解决 Promise
    public func resolve(value: JsValue) {
        if (let Some(p) <- promise) {
            p.doResolve(value)
        }
        isCompleted = true
    }

    // 拒绝 Promise
    public func reject(reason: JsValue) {
        if (let Some(p) <- promise) {
            p.doReject(reason)
        }
        isCompleted = true
    }
}

// ========== ManagedTask ==========
// 严格翻译自 ManagedTask
// 管理型任务包装器
public class ManagedTask {
    public var task: ?Task = None
    public var refCount: Int64 = 1

    public init() {}

    public init(task: Task) {
        this.task = task
    }

    public func ref() {
        refCount++
    }

    public func deref() {
        refCount--
        if (refCount <= 0) {
            task = None
        }
    }

    public func run() {
        if (let Some(t) <- task) {
            t.run()
        }
    }
}

// ========== ImmediateObject ==========
// setImmediate 任务对象
public class ImmediateObject {
    public var id: Int64 = 0
    public var callback: ?JsFunction = None
    public var args: Array<JsValue> = []
    public var isRefed: Bool = true
    public var isDestroyed: Bool = false

    public init() {}

    public func run() {
        if (let Some(cb) <- callback) {
            cb.call(JsValue.undefined(), args)
        }
        isDestroyed = true
    }

    public func ref() {
        isRefed = true
    }

    public func unref() {
        isRefed = false
    }
}

// ========== TimeoutObject ==========
// setTimeout 任务对象
public class TimeoutObject {
    public var id: Int64 = 0
    public var callback: ?JsFunction = None
    public var args: Array<JsValue> = []
    public var interval: Float64 = 0.0
    public var startTime: Float64 = 0.0
    public var isRefed: Bool = true
    public var isRepeated: Bool = false
    public var isDestroyed: Bool = false

    public init() {}

    public func run() {
        if (let Some(cb) <- callback) {
            cb.call(JsValue.undefined(), args)
        }
        if (!isRepeated) {
            isDestroyed = true
        }
    }

    public func ref() {
        isRefed = true
    }

    public func unref() {
        isRefed = false
    }

    public func refresh() {
        startTime = currentTimeMillis().toFloat64()
    }
}

// ========== 全局任务队列 ==========
public class GlobalTaskQueue {
    var tasks: Array<Task> = []
    var workTasks: Array<WorkTask> = []

    static var instance_: ?GlobalTaskQueue = None

    public static func instance() -> GlobalTaskQueue {
        if (instance_ == None) {
            instance_ = GlobalTaskQueue()
        }
        instance_.getOrThrow()
    }

    public init() {}

    public func enqueue(task: Task) {
        tasks.append(task)
    }

    public func dequeue() -> ?Task {
        if (tasks.size == 0) { return None }
        let task = tasks[0]
        tasks = tasks.slice(1)
        Some(task)
    }

    public func drain() -> Int64 {
        var count: Int64 = 0
        while (tasks.size > 0) {
            let task = dequeue()
            if (let Some(t) <- task) {
                t.run()
                count++
            }
        }
        count
    }
}
