// bao_event_loop - Poll 集成和任务队列
// 严格翻译自: src/event_loop/ (Bun 的事件循环 epoll/kqueue 集成)
//   Bun 使用 epoll (Linux) / kqueue (macOS) 进行异步 I/O
//   仓颉集成 epoll 和跨线程任务提交
package bao_event_loop

import bao_core.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// Poller - I/O 轮询器
// 严格翻译自: src/event_loop/ + src/io/epoll.zig
//   Bun 使用 epoll/kqueue 进行异步 I/O 事件通知
//   仓颉封装 epoll 实现
// ============================================================================

/// I/O 轮询器 - 对应 Bun Poller
/// 管理文件描述符的事件注册和等待
public class Poller {
    /// epoll 实例
    private var epoll: ?Epoll
    /// 注册的文件描述符
    private var registered: HashMap<Int64, PollEntry>
    /// 是否活跃
    private var active: Bool

    public init() {
        let result = Epoll.create()
        match (result) {
            case Ok(ep) =>
                epoll = Some(ep)
            case Err(_) =>
                epoll = None
        }
        registered = HashMap<Int64, PollEntry>()
        active = true
    }

    /// 注册文件描述符
    /// 对应 Bun: poll.register(fd, events)
    public func register(fd: Int64, events: UInt32, callback: (EpollEvent) -> Unit): SysMaybe<Unit> {
        match (epoll) {
            case Some(ep) =>
                let result = ep.add(fd, events, 0)
                match (result) {
                    case Err(e) => return SysMaybe<Unit>.Err(e)
                    case Ok(_) =>
                        registered.put(fd, PollEntry(fd, events, callback))
                        return SysMaybe<Unit>.Ok(())
                }
            case None => return SysMaybe<Unit>.Err(SysError(0, SysTag.TODO))
        }
    }

    /// 修改注册事件
    /// 对应 Bun: poll.modify(fd, events)
    public func modify(fd: Int64, events: UInt32): SysMaybe<Unit> {
        match (epoll) {
            case Some(ep) =>
                let result = ep.modify(fd, events, 0)
                match (result) {
                    case Err(e) => return SysMaybe<Unit>.Err(e)
                    case Ok(_) =>
                        let entry = registered.get(fd)
                        if (let Some(e) = entry) {
                            e.events = events
                        }
                        return SysMaybe<Unit>.Ok(())
                }
            case None => return SysMaybe<Unit>.Err(SysError(0, SysTag.TODO))
        }
    }

    /// 取消注册
    /// 对应 Bun: poll.unregister(fd)
    public func unregister(fd: Int64): SysMaybe<Unit> {
        match (epoll) {
            case Some(ep) =>
                let result = ep.remove(fd)
                registered.remove(fd)
                return result
            case None => return SysMaybe<Unit>.Err(SysError(0, SysTag.TODO))
        }
    }

    /// 等待事件 (阻塞)
    /// 对应 Bun: poll.poll(timeout)
    /// timeoutMs: -1 = 无限等待, 0 = 立即返回
    public func poll(timeoutMs: Int64): ArrayList<EpollEvent> {
        var events = ArrayList<EpollEvent>()
        match (epoll) {
            case Some(ep) =>
                let result = ep.wait(64, timeoutMs)
                match (result) {
                    case Ok(evs) =>
                        for (ev in evs) {
                            events.append(ev)
                            // 调用回调
                            let entry = registered.get(ev.fd)
                            if (let Some(e) = entry) {
                                e.callback(ev)
                            }
                        }
                    case Err(_) => ()
                }
            case None => ()
        }
        return events
    }

    /// 关闭轮询器
    public func close(): Unit {
        if (active) {
            match (epoll) {
                case Some(ep) => ep.close()
                case None => ()
            }
            registered.clear()
            active = false
        }
    }
}

/// 轮询条目
class PollEntry {
    var fd: Int64
    var events: UInt32
    var callback: (EpollEvent) -> Unit

    init(fd: Int64, events: UInt32, callback: (EpollEvent) -> Unit) {
        this.fd = fd
        this.events = events
        this.callback = callback
    }
}

// ============================================================================
// ConcurrentTaskQueue - 跨线程任务提交队列
// 严格翻译自: src/event_loop/ConcurrentTask.rs
//   Bun 使用 ConcurrentTaskQueue 安全地从工作线程提交任务到事件循环
// ============================================================================

/// 跨线程任务提交队列 - 对应 Bun ConcurrentTaskQueue
/// 线程安全的任务队列，工作线程提交，事件循环消费
public class ConcurrentTaskQueue {
    /// 任务队列
    private var queue: ConcurrentLinkedQueue<ConcurrentTask>
    /// 事件循环引用
    private var eventLoop: ?MiniEventLoop
    /// 事件 FD (用于唤醒事件循环)
    private var eventFd: Int64

    public init() {
        queue = ConcurrentLinkedQueue<ConcurrentTask>()
        eventLoop = None
        eventFd = -1
    }

    /// 绑定事件循环
    public func attach(loop: MiniEventLoop): Unit {
        eventLoop = loop
    }

    /// 从工作线程提交任务
    /// 对应 Bun: concurrent_tasks.push(task)
    public func push(task: ConcurrentTask): Unit {
        queue.put(task)
        // 通知事件循环有新任务
        match (eventLoop) {
            case Some(loop) => loop.enqueueConcurrent(task)
            case None => ()
        }
    }

    /// 从事件循环线程取出所有任务
    /// 对应 Bun: concurrent_tasks.drain()
    public func drain(): ArrayList<ConcurrentTask> {
        var tasks = ArrayList<ConcurrentTask>()
        while (true) {
            let task = queue.remove()
            if (task == None) { break }
            tasks.append(task.unwrap())
        }
        return tasks
    }

    /// 是否有待处理任务
    public func hasPending(): Bool {
        return !queue.isEmpty()
    }
}

// ============================================================================
// FilePollStore - 文件变化监视存储
// 严格翻译自: src/event_loop/ + src/watcher/
//   Bun 使用 FilePollStore 管理文件监视器
// ============================================================================

/// 文件变化监视存储 - 对应 Bun FilePollStore
/// 管理多个文件监视器，将事件分发到事件循环
public class FilePollStore {
    /// 文件监视器映射 (路径 -> 回调)
    private var watchers: HashMap<String, (FileWatchEvent) -> Unit>
    /// 底层 inotify 监视器
    private var fileWatcher: ?FileWatcher
    /// 关联的轮询器
    private var poller: ?Poller

    public init() {
        watchers = HashMap<String, (FileWatchEvent) -> Unit>()
        fileWatcher = None
        poller = None
    }

    /// 添加文件监视
    /// 对应 Bun: FilePollStore.watch(path, callback)
    public func watch(path: String, callback: (FileWatchEvent) -> Unit): SysMaybe<Unit> {
        watchers.put(path, callback)
        match (fileWatcher) {
            case Some(fw) =>
                return fw.watch(path)
            case None =>
                // 创建文件监视器
                let result = FileWatcher.create()
                match (result) {
                    case Ok(fw) =>
                        fileWatcher = fw
                        fw.watch(path)
                        // 注册到轮询器
                        match (poller) {
                            case Some(p) =>
                                p.register(fw.fd(), EpollEvents.EPOLLIN,
                                    { (ev: EpollEvent) => handleEvents() })
                            case None => ()
                        }
                        return SysMaybe<Unit>.Ok(())
                    case Err(e) => return SysMaybe<Unit>.Err(e)
                }
        }
    }

    /// 取消文件监视
    public func unwatch(path: String): Unit {
        watchers.remove(path)
        match (fileWatcher) {
            case Some(fw) => fw.unwatch(path)
            case None => ()
        }
    }

    /// 处理事件 (内部)
    private func handleEvents(): Unit {
        match (fileWatcher) {
            case Some(fw) =>
                let events = fw.readEvents()
                for (event in events) {
                    let callback = watchers.get(event.fileName)
                    if (let Some(cb) = callback) {
                        cb(event)
                    }
                    // 也尝试匹配目录
                    for (path in watchers.keys()) {
                        if (event.fileName.startsWith(path)) {
                            let cb = watchers.get(path)
                            if (let Some(c) = cb) {
                                c(event)
                            }
                        }
                    }
                }
            case None => ()
        }
    }

    /// 关闭所有监视
    public func close(): Unit {
        match (fileWatcher) {
            case Some(fw) => fw.close()
            case None => ()
        }
        watchers.clear()
    }
}
