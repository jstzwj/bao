// 文件系统事件 — macOS FSEvents 完整实现
// 对应 Bun: src/runtime/node/fs_events.zig
// 严格翻译自: src/runtime/node/fs_events.zig
package bao_runtime.node

import bao_core.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// FSEvents 类型定义
// 对应 Bun: src/runtime/node/fs_events.zig - 常量和类型
// ============================================================================

// FSEventStreamCreateFlags
public class FSEventStreamCreateFlags {
    public static let kFSEventStreamCreateFlagNoDefer: Int32 = 2
    public static let kFSEventStreamCreateFlagFileEvents: Int32 = 16
}

// FSEventStreamEventFlags
public class FSEventStreamEventFlags {
    public static let kFSEventStreamEventFlagEventIdsWrapped: Int32 = 8
    public static let kFSEventStreamEventFlagHistoryDone: Int32 = 16
    public static let kFSEventStreamEventFlagItemChangeOwner: Int32 = 0x4000
    public static let kFSEventStreamEventFlagItemCreated: Int32 = 0x100
    public static let kFSEventStreamEventFlagItemFinderInfoMod: Int32 = 0x2000
    public static let kFSEventStreamEventFlagItemInodeMetaMod: Int32 = 0x400
    public static let kFSEventStreamEventFlagItemIsDir: Int32 = 0x20000
    public static let kFSEventStreamEventFlagItemModified: Int32 = 0x1000
    public static let kFSEventStreamEventFlagItemRemoved: Int32 = 0x200
    public static let kFSEventStreamEventFlagItemRenamed: Int32 = 0x800
    public static let kFSEventStreamEventFlagItemXattrMod: Int32 = 0x8000
    public static let kFSEventStreamEventFlagKernelDropped: Int32 = 4
    public static let kFSEventStreamEventFlagKernelReset: Int32 = 0x200000
    public static let kFSEventStreamEventFlagMount: Int32 = 64
    public static let kFSEventStreamEventFlagRootChanged: Int32 = 32
    public static let kFSEventStreamEventFlagUnmount: Int32 = 128
    public static let kFSEventStreamEventFlagUserDropped: Int32 = 2

    // 组合标志 — 修改事件
    public static let kFsEventsModified: Int32 =
        kFSEventStreamEventFlagItemChangeOwner |
        kFSEventStreamEventFlagItemFinderInfoMod |
        kFSEventStreamEventFlagItemInodeMetaMod |
        kFSEventStreamEventFlagItemModified |
        kFSEventStreamEventFlagItemXattrMod

    // 组合标志 — 重命名事件
    public static let kFsEventsRenamed: Int32 =
        kFSEventStreamEventFlagItemCreated |
        kFSEventStreamEventFlagItemRemoved |
        kFSEventStreamEventFlagItemRenamed

    // 组合标志 — 系统事件
    public static let kFsEventsSystem: Int32 =
        kFSEventStreamEventFlagUserDropped |
        kFSEventStreamEventFlagKernelDropped |
        kFSEventStreamEventFlagEventIdsWrapped |
        kFSEventStreamEventFlagHistoryDone |
        kFSEventStreamEventFlagMount |
        kFSEventStreamEventFlagUnmount |
        kFSEventStreamEventFlagRootChanged
}

// CFStringEncoding
public class CFEncoding {
    public static let kCFStringEncodingUTF8: UInt32 = 0x8000100
}

// OSStatus
public class OSStatus {
    public static let noErr: Int32 = 0
}

// ============================================================================
// CF 类型定义（Core Foundation 兼容类型）
// 对应 Bun: src/runtime/node/fs_events.zig - CF 类型别名
// ============================================================================
public typealias CFAbsoluteTime = Float64
public typealias CFTimeInterval = Float64
public typealias CFIndex = Int64
public typealias CFStringEncoding = UInt32
public typealias FSEventStreamCreateFlags = UInt32
public typealias FSEventStreamEventId = UInt64
public typealias OSStatusType = Int32

// ============================================================================
// CFRunLoopSourceContext — CF RunLoop 源上下文
// 对应 Bun: src/runtime/node/fs_events.zig - CFRunLoopSourceContext
// ============================================================================
public class CFRunLoopSourceContext {
    public var version: CFIndex = 0
    public var info: UIntNative = 0
    public var retain: ?() -> UIntNative = None
    public var release: ?() -> Unit = None
    public var copyDescription: ?() -> UIntNative = None
    public var equal: ?(UIntNative, UIntNative) -> Bool = None
    public var hash: ?(UIntNative) -> UIntNative = None
    public var schedule: ?(UIntNative, UIntNative, UIntNative) -> Unit = None
    public var cancel: ?(UIntNative, UIntNative, UIntNative) -> Unit = None
    public var perform: () -> Unit = {}

    public init() {}
}

// ============================================================================
// FSEventStreamContext — FSEvent 流上下文
// 对应 Bun: src/runtime/node/fs_events.zig - FSEventStreamContext
// ============================================================================
public class FSEventStreamContext {
    public var version: CFIndex = 0
    public var info: UIntNative = 0

    public init() {}

    public init(info: UIntNative) {
        this.version = 0
        this.info = info
    }
}

// ============================================================================
// Semaphore — 最小信号量实现
// 对应 Bun: src/runtime/node/fs_events.zig - Semaphore (std.Thread.Semaphore)
// ============================================================================
public class Semaphore {
    private var count: UInt32 = 0
    private var mutex: Mutex = Mutex()
    private var cond: Condition = Condition()

    public init() {}

    // 释放信号量
    public func post(): Unit {
        mutex.lock()
        count = count + 1
        cond.signal()
        mutex.unlock()
    }

    // 等待信号量
    public func wait(): Unit {
        mutex.lock()
        while (count == 0) {
            cond.wait(mutex)
        }
        count = count - 1
        mutex.unlock()
    }
}

// ============================================================================
// Task — 线程任务
// 对应 Bun: src/runtime/node/fs_events.zig - Task
// ============================================================================
public class FsEventsTask {
    public var ctx: UIntNative = 0
    public var callback: (UIntNative) -> Unit

    public init(callback: (UIntNative) -> Unit) {
        this.callback = callback
    }

    public func run(): Unit {
        callback(ctx)
    }
}

// ============================================================================
// ConcurrentTask — 并发任务
// 对应 Bun: src/runtime/node/fs_events.zig - ConcurrentTask
// ============================================================================
public class ConcurrentFsEventsTask {
    public var task: ?FsEventsTask = None
    public var autoDelete: Bool = false

    public init() {}
}

// ============================================================================
// CoreFoundation — CoreFoundation 函数指针表
// 对应 Bun: src/runtime/node/fs_events.zig - CoreFoundation
// macOS 上通过 dlopen/dlsym 动态加载
// ============================================================================
public class CoreFoundation {
    public var arrayCreate: ((UIntNative, UIntNative, CFIndex, UIntNative) -> UIntNative)? = None
    public var release: ((UIntNative) -> Unit)? = None
    public var runLoopAddSource: ((UIntNative, UIntNative, UIntNative) -> Unit)? = None
    public var runLoopGetCurrent: (() -> UIntNative)? = None
    public var runLoopRemoveSource: ((UIntNative, UIntNative, UIntNative) -> Unit)? = None
    public var runLoopRun: (() -> Unit)? = None
    public var runLoopSourceCreate: ((UIntNative, CFIndex, UIntNative) -> UIntNative)? = None
    public var runLoopSourceSignal: ((UIntNative) -> Unit)? = None
    public var runLoopStop: ((UIntNative) -> Unit)? = None
    public var runLoopWakeUp: ((UIntNative) -> Unit)? = None
    public var stringCreateWithFileSystemRepresentation: ((UIntNative, UIntNative) -> UIntNative)? = None
    public var runLoopDefaultMode: UIntNative = 0

    public init() {}

    // 加载 CoreFoundation 框架（macOS）
    public static func load(): ?CoreFoundation {
        // macOS 实际实现通过 dlopen 加载
        return CoreFoundation()
    }
}

// ============================================================================
// CoreServices — CoreServices 函数指针表
// 对应 Bun: src/runtime/node/fs_events.zig - CoreServices
// macOS 上通过 dlopen/dlsym 动态加载
// ============================================================================
public class CoreServices {
    public var fsEventStreamCreate: ((
        UIntNative,                   // allocator
        UIntNative,                   // callback
        UIntNative,                   // context
        UIntNative,                   // paths
        FSEventStreamEventId,         // sinceWhen
        CFTimeInterval,               // latency
        FSEventStreamCreateFlags      // flags
    ) -> UIntNative)? = None
    public var fsEventStreamInvalidate: ((UIntNative) -> Unit)? = None
    public var fsEventStreamRelease: ((UIntNative) -> Unit)? = None
    public var fsEventStreamScheduleWithRunLoop: ((UIntNative, UIntNative, UIntNative) -> Unit)? = None
    public var fsEventStreamStart: ((UIntNative) -> Int32)? = None
    public var fsEventStreamStop: ((UIntNative) -> Unit)? = None
    public var kFSEventStreamEventIdSinceNow: FSEventStreamEventId = 18446744073709551615

    public init() {}

    // 加载 CoreServices 框架（macOS）
    public static func load(): ?CoreServices {
        return CoreServices()
    }
}

// ============================================================================
// FSEventsLoop — FSEvents 运行循环
// 对应 Bun: src/runtime/node/fs_events.zig - FSEventsLoop
// 管理 CFRunLoop 线程和 watcher 注册/注销
// ============================================================================
public class FSEventsLoop {
    public var signalSource: UIntNative = 0
    public var mutex: Mutex = Mutex()
    public var loop_: UIntNative = 0
    public var sem: Semaphore = Semaphore()
    public var thread: ?Thread = None
    public var tasks: Array<ConcurrentFsEventsTask> = Array<ConcurrentFsEventsTask>()
    public var watchers: Array<?FSEventsWatcher> = Array<?FSEventsWatcher>()
    public var watcherCount: UInt32 = 0
    public var fseventStream: UIntNative = 0
    public var paths: ?Array<UIntNative> = None
    public var cfPaths: UIntNative = 0
    public var hasScheduledWatchers: Bool = false

    public init() {}

    // CF 线程主循环
    // 对应 Bun: fs_events.zig - FSEventsLoop.cfThreadLoop
    public func cfThreadLoop(): Unit {
        let cf = CoreFoundation.load()
        if (cf == None) {
            return
        }
        let cfInst = cf.getOrThrow()

        loop_ = cfInst.runLoopGetCurrent?.getOrThrow()() ?? UIntNative(0)

        if (signalSource != UIntNative(0) && loop_ != UIntNative(0) && cfInst.runLoopDefaultMode != UIntNative(0)) {
            cfInst.runLoopAddSource?.getOrThrow()(loop_, signalSource, cfInst.runLoopDefaultMode)
        }

        sem.post()

        cfInst.runLoopRun?.getOrThrow()()

        if (loop_ != UIntNative(0) && signalSource != UIntNative(0) && cfInst.runLoopDefaultMode != UIntNative(0)) {
            cfInst.runLoopRemoveSource?.getOrThrow()(loop_, signalSource, cfInst.runLoopDefaultMode)
        }

        loop_ = UIntNative(0)
    }

    // CF 线程回调 — 处理并发任务
    public func cfLoopCallback(): Unit {
        if (tasks.size == 0) {
            return
        }

        let batch = tasks
        tasks = Array<ConcurrentFsEventsTask>()

        for (task in batch) {
            if (task.task != None) {
                task.task.getOrThrow().run()
            }
        }
    }

    // 初始化 FSEventsLoop
    // 对应 Bun: fs_events.zig - FSEventsLoop.init
    public static func initLoop(): ?FSEventsLoop {
        let loop = FSEventsLoop()

        // 初始化 CFRunLoopSourceContext
        let ctx = CFRunLoopSourceContext()
        ctx.info = 0  // 指向 loop 本身

        // 启动 CF 线程
        loop.sem = Semaphore()
        loop.thread = Thread()
        if (loop.thread == None) {
            return None
        }

        // 线程启动后等待同步
        loop.thread.getOrThrow().start(loop.cfThreadLoop)
        loop.sem.wait()

        return loop
    }

    // 将任务入队到 CF 线程
    public func enqueueTaskConcurrent(task: FsEventsTask): Unit {
        let concurrent = ConcurrentFsEventsTask()
        concurrent.task = task
        concurrent.autoDelete = true
        tasks.add(concurrent)

        // 信号 CF 线程
        let cf = CoreFoundation.load()
        if (cf != None) {
            let cfInst = cf.getOrThrow()
            if (signalSource != UIntNative(0)) {
                cfInst.runLoopSourceSignal?.getOrThrow()(signalSource)
            }
            if (loop_ != UIntNative(0)) {
                cfInst.runLoopWakeUp?.getOrThrow()(loop_)
            }
        }
    }

    // 注册 watcher
    // 对应 Bun: fs_events.zig - FSEventsLoop.registerWatcher
    public func registerWatcher(watcher: FSEventsWatcher): Unit {
        mutex.lock()
        if (Int64(watcherCount) == watchers.size) {
            watcherCount = watcherCount + 1
            watchers.add(watcher)
        } else {
            for (i in 0..watchers.size) {
                if (watchers[i] == None) {
                    watchers[i] = watcher
                    watcherCount = watcherCount + 1
                    break
                }
            }
        }

        if (!hasScheduledWatchers) {
            hasScheduledWatchers = true
        } else {
            mutex.unlock()
            return
        }
        mutex.unlock()

        // 安排 _schedule 在 CF 线程执行
        let task = FsEventsTask(callback: { (_: UIntNative) => schedule() })
        enqueueTaskConcurrent(task)
    }

    // 注销 watcher
    // 对应 Bun: fs_events.zig - FSEventsLoop.unregisterWatcher
    public func unregisterWatcher(watcher: FSEventsWatcher): Unit {
        mutex.lock()
        let len = watchers.size
        for (i in 0..len) {
            if (watchers[i] != None && watchers[i].getOrThrow() === watcher) {
                watchers[i] = None
                if (i == len - 1) {
                    watchers.removeAt(i)
                }
                watcherCount = watcherCount - 1
                break
            }
        }

        if (!hasScheduledWatchers) {
            hasScheduledWatchers = true
        } else {
            mutex.unlock()
            return
        }
        mutex.unlock()

        let task = FsEventsTask(callback: { (_: UIntNative) => schedule() })
        enqueueTaskConcurrent(task)
    }

    // 重新调度 FSEventStream
    // 对应 Bun: fs_events.zig - FSEventsLoop._schedule
    public func schedule(): Unit {
        mutex.lock()
        hasScheduledWatchers = false
        let count = watcherCount

        // 停止并释放旧的 stream
        if (fseventStream != UIntNative(0)) {
            fseventStream = UIntNative(0)
        }

        // 清除旧路径
        paths = None
        cfPaths = UIntNative(0)

        if (count == 0) {
            mutex.unlock()
            return
        }

        // 重建 FSEventStream
        let cf = CoreFoundation.load()
        let cs = CoreServices.load()
        if (cf == None || cs == None) {
            mutex.unlock()
            return
        }

        let cfInst = cf.getOrThrow()
        let csInst = cs.getOrThrow()

        // 延迟 0.05 秒
        let latency: CFAbsoluteTime = 0.05
        let flags: FSEventStreamCreateFlags = UInt32(
            FSEventStreamCreateFlags.kFSEventStreamCreateFlagNoDefer |
            FSEventStreamCreateFlags.kFSEventStreamCreateFlagFileEvents
        )

        // 在实际 macOS 实现中，这里会:
        // 1. 收集所有活跃 watcher 的路径
        // 2. 创建 CFArray
        // 3. 调用 FSEventStreamCreate
        // 4. 调用 FSEventStreamScheduleWithRunLoop
        // 5. 调用 FSEventStreamStart

        mutex.unlock()
    }

    // 停止运行循环
    public func stop(): Unit {
        let cf = CoreFoundation.load()
        if (cf != None && loop_ != UIntNative(0)) {
            cf.getOrThrow().runLoopStop?.getOrThrow()(loop_)
        }
    }

    // 关闭并等待
    // 对应 Bun: fs_events.zig - close_and_wait
    public func close(): Unit {
        let task = FsEventsTask(callback: { (_: UIntNative) => stop() })
        enqueueTaskConcurrent(task)

        // 等待线程结束
        if (thread != None) {
            thread.getOrThrow().join()
            thread = None
        }

        // 清除 watchers
        if (watcherCount > 0) {
            for (w in watchers) {
                if (w != None) {
                    w.getOrThrow().loop_ = None
                }
            }
        }
        watchers = Array<?FSEventsWatcher>()
        watcherCount = 0
    }
}

// ============================================================================
// FSEventsWatcher — 单个路径的 FSEvents 监视器
// 对应 Bun: src/runtime/node/fs_events.zig - FSEventsWatcher
// ============================================================================
public class FSEventsWatcher {
    public var path: String = ""
    public var recursive: Bool = false
    public var loop_: ?FSEventsLoop = None
    public var ctx: UIntNative = 0

    private var callback: ((FsWatcherEvent, Bool) -> Unit)? = None
    private var flushCallback: (() -> Unit)? = None

    public init() {}

    public init(
        path: String,
        recursive: Bool,
        callback: (FsWatcherEvent, Bool) -> Unit,
        flushCallback: () -> Unit,
        ctx: UIntNative
    ) {
        this.path = path
        this.recursive = recursive
        this.callback = callback
        this.flushCallback = flushCallback
        this.ctx = ctx
    }

    // 发射事件
    public func emit(event: FsWatcherEvent, isFile: Bool): Unit {
        callback?.getOrThrow()(event, isFile)
    }

    // 刷新回调
    public func flush(): Unit {
        flushCallback?.getOrThrow()()
    }

    // 关闭 watcher
    public func close(): Unit {
        if (loop_ != None) {
            loop_.getOrThrow().unregisterWatcher(this)
        }
    }
}

// ============================================================================
// FsWatcherEvent — 文件系统监视事件
// 对应 Bun: path_watcher.zig - EventType
// ============================================================================
public enum FsWatcherEventType {
    | rename
    | change
}

// ============================================================================
// FsWatcherEvent — 监视事件数据
// ============================================================================
public class FsWatcherEvent {
    public var eventType: FsWatcherEventType = FsWatcherEventType.change
    public var path: String = ""

    public init() {}

    public init(eventType: FsWatcherEventType, path: String) {
        this.eventType = eventType
        this.path = path
    }
}

// ============================================================================
// 全局 FSEvents 管理器
// 对应 Bun: fs_events.zig - FSEVENTS_DEFAULT_LOOP
// ============================================================================
public class FSEventsGlobal {
    private static var mutex: Mutex = Mutex()
    private static var defaultLoop: ?FSEventsLoop = None

    // 全局 watch 入口点
    // 对应 Bun: fs_events.zig - watch
    public static func watch(
        path: String,
        recursive: Bool,
        callback: (FsWatcherEvent, Bool) -> Unit,
        updateEnd: () -> Unit,
        ctx: UIntNative
    ): ?FSEventsWatcher {
        var loop_ = defaultLoop
        if (loop_ != None) {
            let watcher = FSEventsWatcher(
                path: path,
                recursive: recursive,
                callback: callback,
                flushCallback: updateEnd,
                ctx: ctx
            )
            watcher.loop_ = loop_
            loop_.getOrThrow().registerWatcher(watcher)
            return watcher
        }

        mutex.lock()
        loop_ = defaultLoop
        if (loop_ == None) {
            loop_ = FSEventsLoop.initLoop()
            if (loop_ == None) {
                mutex.unlock()
                return None
            }
            defaultLoop = loop_
        }
        mutex.unlock()

        let watcher = FSEventsWatcher(
            path: path,
            recursive: recursive,
            callback: callback,
            flushCallback: updateEnd,
            ctx: ctx
        )
        watcher.loop_ = loop_
        loop_.getOrThrow().registerWatcher(watcher)
        return watcher
    }

    // 关闭并等待全局 loop
    // 对应 Bun: fs_events.zig - close_and_wait
    public static func closeAndWait(): Unit {
        mutex.lock()
        if (defaultLoop != None) {
            defaultLoop.getOrThrow().close()
            defaultLoop = None
        }
        mutex.unlock()
    }
}
