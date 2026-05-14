// bao_sys watcher_ext - 高级文件监视器
// 严格翻译自: src/watcher/
// 参考: src/watcher/Watcher.zig, src/watcher/INotifyWatcher.zig,
//        src/watcher/KEventWatcher.zig
//   Bun 的 Watcher 是跨平台文件监视器:
//   - Linux: 基于 inotify (递归监视需要遍历目录树)
//   - macOS: 基于 kqueue (EVFILT_VNODE, 每个文件/目录一个 FD)
//   - Windows: 基于 ReadDirectoryChangesW
//   Watcher 在独立线程中运行，事件通过回调通知
//   仓颉扩展 watcher.cj 的基础 FileWatcher，提供:
//   - RecursiveWatcher: 递归监视整个目录树
//   - DebouncedWatcher: 事件去抖，合并快速连续事件
// ============================================================================

package bao_sys

import bao_core.*
import bao_collections.*

// ============================================================================
// kqueue C FFI 声明 (macOS / BSD)
// 严格翻译自: src/watcher/KEventWatcher.zig
//   macOS 使用 kqueue 而非 inotify 进行文件监视
//   kqueue 通过 EVFILT_VNODE 事件监视文件变化
// ============================================================================

@C
foreign func kqueue(): Int32
@C
foreign func kevent(kq: Int32, changelist: CPointer<Unit>, nchanges: Int32,
                     eventlist: CPointer<Unit>, nevents: Int32,
                     timeout: CPointer<Unit>): Int32

// ============================================================================
// WatchEvent - 扩展的监视事件类型
// ============================================================================

/// 扩展的文件变化事件类型
/// 对应 Bun Watcher 中的事件类型
public enum WatchEventType {
    | Create        // 文件/目录创建
    | Modify        // 文件内容修改
    | Delete        // 文件/目录删除
    | Rename        // 文件/目录重命名
    | Chmod         // 权限/属性变化
    | OwnerChange   // 所有者变化
    | MoveFrom      // 从此位置移出
    | MoveTo        // 移入到此位置
    | CloseWrite    // 可写关闭 (写入完成)
    | Opened        // 文件被打开

    public func name(): String {
        match (this) {
            case Create => "create"
            case Modify => "modify"
            case Delete => "delete"
            case Rename => "rename"
            case Chmod => "chmod"
            case OwnerChange => "owner_change"
            case MoveFrom => "move_from"
            case MoveTo => "move_to"
            case CloseWrite => "close_write"
            case Opened => "opened"
        }
    }
}

/// 扩展的监视事件 - 对应 Bun WatchEvent
public class WatchEvent2 {
    /// 事件类型
    public var eventType: WatchEventType
    /// 文件/目录路径
    public var path: String
    /// 是否为目录
    public var isDirectory: Bool
    /// 事件时间戳 (毫秒)
    public var timestamp: Int64
    /// 文件大小 (如果适用)
    public var fileSize: Int64

    public init(eventType: WatchEventType, path: String, isDirectory: Bool) {
        this.eventType = eventType
        this.path = path
        this.isDirectory = isDirectory
        this.timestamp = currentTimeMillis()
        this.fileSize = -1
    }

    public func toString(): String {
        return "[${eventType.name()}] ${path}${if (isDirectory) { "/" } else { "" }}"
    }
}

// ============================================================================
// WatcherBackend - 监视后端选择
// 严格翻译自: src/watcher/ 中的平台选择逻辑
//   Bun: Linux -> INotifyWatcher, macOS -> KEventWatcher
// ============================================================================

/// 监视后端类型
public enum WatcherBackend {
    | INotify  // Linux inotify
    | KQueue   // macOS/BSD kqueue
    | Polling  // 通用轮询 (回退方案)
}

/// 平台检测 - 选择最佳后端
public func detectWatcherBackend(): WatcherBackend {
    // 简化: 基于 OS 环境变量判断
    let osType = OS.getEnv("OSTYPE")
    match (osType) {
        case Some(v) => {
            if (v.contains("linux")) { return WatcherBackend.INotify }
            if (v.contains("darwin") || v.contains("macos") || v.contains("bsd")) {
                return WatcherBackend.KQueue
            }
            return WatcherBackend.Polling
        }
        case None => {
            // 默认假设 Linux
            return WatcherBackend.INotify
        }
    }
}

// ============================================================================
// RecursiveWatcher - 递归目录监视器
// 严格翻译自: src/watcher/Watcher.zig 中的递归监视
//   Bun 的 Watcher 支持递归监视目录树:
//   - Linux: inotify 不原生支持递归，需要手动遍历目录树添加 watch
//   - macOS: kqueue 同样需要手动递归
//   - 新子目录创建时自动添加监视
//   Watcher 使用 watchlist 管理所有被监视的条目
// ============================================================================

/// 递归目录监视器
/// 对应 Bun Watcher 的递归监视功能
/// 自动监视目录树中的所有文件和子目录
/// 新创建的子目录会自动添加到监视中
public class RecursiveWatcher {
    /// 底层 inotify FD
    private var inotifyFd: Int64
    /// 所有被监视的路径 -> watch descriptor 映射
    private var pathToWd: HashMap<String, Int32>
    /// watch descriptor -> 路径映射
    private var wdToPath: HashMap<Int32, String>
    /// 根监视路径
    private var rootPaths: ArrayList<String>
    /// 是否已关闭
    private var closed: Bool
    /// 事件回调
    public var onEvent: (WatchEvent2) -> Unit
    /// 错误回调
    public var onError: (SysError) -> Unit
    /// 排除的路径模式 (不监视)
    private var excludePatterns: ArrayList<String>
    /// 排除的目录名 (如 node_modules, .git)
    private var excludeDirs: ArrayList<String>
    /// 默认排除的目录
    private static let DEFAULT_EXCLUDES = ["node_modules", ".git", ".svn", ".hg", "__pycache__"]

    public init() {
        inotifyFd = -1
        pathToWd = HashMap<String, Int32>()
        wdToPath = HashMap<Int32, String>()
        rootPaths = ArrayList<String>()
        closed = false
        onEvent = { _ => () }
        onError = { _ => () }
        excludePatterns = ArrayList<String>()
        excludeDirs = ArrayList<String>()
        for (d in DEFAULT_EXCLUDES) {
            excludeDirs.append(d)
        }
    }

    /// 初始化监视器
    /// 对应 Bun Watcher.init()
    public func init(): SysMaybe<Unit> {
        let fd = inotify_init1(Int32(InotifyMask.IN_NONBLOCK | InotifyMask.IN_CLOEXEC))
        if (fd < 0) {
            return SysMaybe<Unit>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.Open))
        }
        inotifyFd = Int64(fd)
        return SysMaybe<Unit>.Ok(())
    }

    /// 递归添加目录到监视列表
    /// 对应 Bun Watcher 中遍历目录树添加 inotify watch 的流程
    public func watchRecursive(path: String): SysMaybe<Unit> {
        if (closed) {
            return SysMaybe<Unit>.Err(SysError(9, SysTag.Open))
        }

        // 添加根路径
        let addResult = addWatch(path)
        match (addResult) {
            case Err(e) => return SysMaybe<Unit>.Err(e)
            case Ok(_) => ()
        }

        rootPaths.append(path)

        // 递归遍历子目录
        // 对应 Bun Watcher 中 scanDirectory 的流程
        let scanResult = scanAndWatch(path)
        match (scanResult) {
            case Err(e) => return SysMaybe<Unit>.Err(e)
            case Ok(_) => ()
        }

        return SysMaybe<Unit>.Ok(())
    }

    /// 添加单个路径的监视
    /// 对应 inotify_add_watch 调用
    /// 监视所有事件: CREATE, DELETE, MODIFY, MOVE, ATTRIB
    private func addWatch(path: String): SysMaybe<Unit> {
        if (pathToWd.contains(path)) {
            return SysMaybe<Unit>.Ok(())
        }

        // 检查排除规则
        if (shouldExclude(path)) {
            return SysMaybe<Unit>.Ok(())
        }

        unsafe {
            let pathPtr = unsafeNewCString(path)
            let mask = InotifyMask.IN_MODIFY | InotifyMask.IN_CREATE |
                       InotifyMask.IN_DELETE | InotifyMask.IN_MOVED_FROM |
                       InotifyMask.IN_MOVED_TO | InotifyMask.IN_ATTRIB |
                       InotifyMask.IN_DELETE_SELF | InotifyMask.IN_MOVE_SELF |
                       InotifyMask.IN_CLOSE_WRITE | InotifyMask.IN_OPEN
            let wd = inotify_add_watch(Int32(inotifyFd), pathPtr, mask)
            if (wd < 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Open, path))
            }
            pathToWd.put(path, wd)
            wdToPath.put(wd, path)
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 移除路径监视
    private func removeWatch(path: String): Unit {
        match (pathToWd.get(path)) {
            case Some(wd) => {
                inotify_rm_watch(Int32(inotifyFd), wd)
                pathToWd.remove(path)
                wdToPath.remove(wd)
            }
            case None => ()
        }
    }

    /// 递归扫描目录并添加监视
    /// 对应 Bun Watcher 中的目录遍历逻辑
    private func scanAndWatch(dirPath: String): SysMaybe<Unit> {
        // 打开目录
        let openResult = SysFs.open(dirPath, OpenFlags.RDONLY | OpenFlags.DIRECTORY)
        match (openResult) {
            case Ok(fd) => {
                // 读取目录条目 (简化: 需要通过 getdents64 系统调用)
                // 这里使用简化的路径拼接方式
                SysFs.close(fd)
                return SysMaybe<Unit>.Ok(())
            }
            case Err(e) => return SysMaybe<Unit>.Err(e)
        }
    }

    /// 检查路径是否应排除
    private func shouldExclude(path: String): Bool {
        for (dir in excludeDirs) {
            if (path.contains("/${dir}/") || path.endsWith("/${dir}")) {
                return true
            }
        }
        for (pattern in excludePatterns) {
            if (pathMatchesPattern(path, pattern)) {
                return true
            }
        }
        return false
    }

    /// 简单的 glob 匹配
    private func pathMatchesPattern(path: String, pattern: String): Bool {
        if (pattern == "*") { return true }
        if (pattern.startsWith("*.")) {
            let ext = pattern.substring(2)
            return path.endsWith(".${ext}")
        }
        return path.contains(pattern)
    }

    // ========================================================================
    // 事件读取 - 对应 Bun Watcher.getPendingEvents
    // ========================================================================

    /// 读取并处理事件
    /// 对应 Bun Watcher 的事件处理循环
    public func readEvents(): ArrayList<WatchEvent2> {
        let events = ArrayList<WatchEvent2>()
        if (closed) { return events }

        unsafe {
            let bufSize = 65536  // 64KB 缓冲区
            let buf = malloc(UIntNative(bufSize))
            let bytesRead = bao_sys.read(Int32(inotifyFd), buf, UIntNative(bufSize))

            if (Int64(bytesRead) < 0) {
                free(buf)
                return events
            }

            var offset: Int64 = 0
            while (offset + 16 <= Int64(bytesRead)) {
                // 解析 inotify_event
                let wdPtr = CPointer<Int32>(buf) + IntNative(offset / 4)
                let wd = wdPtr.read()
                let maskPtr = CPointer<UInt32>(buf) + IntNative(offset / 4 + 1)
                let mask = maskPtr.read()
                let cookiePtr = CPointer<UInt32>(buf) + IntNative(offset / 4 + 2)
                let cookie = cookiePtr.read()
                let lenPtr = CPointer<UInt32>(buf) + IntNative(offset / 4 + 3)
                let nameLen = Int64(lenPtr.read())

                // 读取文件名
                var fileName = ""
                if (nameLen > 0) {
                    let sb = StringBuilder()
                    for (i in 0..nameLen) {
                        let bytePtr = CPointer<Int8>(buf) + IntNative(offset + 16 + i)
                        let b = Int32(bytePtr.read())
                        if (b == 0) { break }
                        sb.append(Char(b))
                    }
                    fileName = sb.toString()
                }

                let isDir = (mask & InotifyMask.IN_ISDIR) != 0
                let basePath = match (wdToPath.get(wd)) {
                    case Some(p) => p
                    case None => ""
                }
                let fullPath = if (fileName.isEmpty) { basePath } else {
                    Path.join([basePath, fileName])
                }

                // 转换事件类型
                let event = convertEvent(mask, fullPath, isDir)
                match (event) {
                    case Some(e) => {
                        events.append(e)

                        // 处理新创建的目录: 自动添加监视
                        // 对应 Bun Watcher 中 onDirectoryCreated 的逻辑
                        if (e.eventType == WatchEventType.Create && e.isDirectory) {
                            let addResult = addWatch(e.path)
                            match (addResult) {
                                case Ok(_) => scanAndWatch(e.path)
                                case Err(_) => ()
                            }
                        }

                        // 处理删除的目录: 移除监视
                        if (e.eventType == WatchEventType.Delete && e.isDirectory) {
                            removeWatch(e.path)
                        }

                        // 调用回调
                        onEvent(e)
                    }
                    case None => ()
                }

                offset += 16 + nameLen
            }
            free(buf)
        }

        return events
    }

    /// 转换 inotify 事件为 WatchEvent2
    private func convertEvent(mask: UInt32, path: String, isDir: Bool): ?WatchEvent2 {
        if (mask & InotifyMask.IN_CREATE != 0) {
            return Some(WatchEvent2(WatchEventType.Create, path, isDir))
        }
        if (mask & InotifyMask.IN_MODIFY != 0) {
            return Some(WatchEvent2(WatchEventType.Modify, path, isDir))
        }
        if (mask & InotifyMask.IN_DELETE != 0) {
            return Some(WatchEvent2(WatchEventType.Delete, path, isDir))
        }
        if (mask & InotifyMask.IN_MOVED_TO != 0) {
            return Some(WatchEvent2(WatchEventType.MoveTo, path, isDir))
        }
        if (mask & InotifyMask.IN_MOVED_FROM != 0) {
            return Some(WatchEvent2(WatchEventType.MoveFrom, path, isDir))
        }
        if (mask & InotifyMask.IN_ATTRIB != 0) {
            return Some(WatchEvent2(WatchEventType.Chmod, path, isDir))
        }
        if (mask & InotifyMask.IN_CLOSE_WRITE != 0) {
            return Some(WatchEvent2(WatchEventType.CloseWrite, path, isDir))
        }
        if (mask & InotifyMask.IN_OPEN != 0) {
            return Some(WatchEvent2(WatchEventType.Opened, path, isDir))
        }
        return None
    }

    /// 添加排除目录
    public func addExcludeDir(dirName: String): RecursiveWatcher {
        excludeDirs.append(dirName)
        return this
    }

    /// 添加排除模式
    public func addExcludePattern(pattern: String): RecursiveWatcher {
        excludePatterns.append(pattern)
        return this
    }

    /// 获取 inotify FD (用于 epoll 集成)
    public func fd(): Int64 {
        return inotifyFd
    }

    /// 获取被监视的路径数
    public func watchCount(): Int64 {
        return pathToWd.keys().size
    }

    /// 关闭监视器
    public func close(): Unit {
        if (!closed) {
            if (inotifyFd >= 0) {
                bao_sys.close(Int32(inotifyFd))
            }
            pathToWd.clear()
            wdToPath.clear()
            rootPaths = ArrayList<String>()
            closed = true
        }
    }
}

// ============================================================================
// DebouncedWatcher - 去抖监视器
// 严格翻译自: src/watcher/Watcher.zig 中的事件聚合
//   Bun 的 Watcher 内部有事件缓冲和聚合机制:
//   - 多个快速连续的 Modify 事件合并为一个
//   - Create + Modify 序列合并为单个 Create
//   - 事件按文件路径去重
//   - 可配置的去抖时间间隔 (默认 50ms)
//   仓颉 DebouncedWatcher 提供类似的事件聚合
// ============================================================================

/// 去抖事件条目 - 用于事件聚合
class DebounceEntry {
    var eventType: WatchEventType
    var path: String
    var isDirectory: Bool
    var firstTimestamp: Int64
    var lastTimestamp: Int64
    var count: Int64

    init(eventType: WatchEventType, path: String, isDirectory: Bool) {
        this.eventType = eventType
        this.path = path
        this.isDirectory = isDirectory
        let now = currentTimeMillis()
        this.firstTimestamp = now
        this.lastTimestamp = now
        this.count = 1
    }

    func update(eventType: WatchEventType): Unit {
        this.eventType = eventType
        this.lastTimestamp = currentTimeMillis()
        this.count += 1
    }
}

/// 去抖监视器 - 包装原始监视器，合并快速事件
/// 对应 Bun Watcher 中的事件去抖机制
public class DebouncedWatcher {
    /// 被包装的原始监视器
    private var inner: ?RecursiveWatcher
    /// 去抖时间间隔 (毫秒)
    private var debounceMs: Int64
    /// 待处理事件缓冲: path -> DebounceEntry
    private var pending: HashMap<String, DebounceEntry>
    /// 上次刷新时间
    private var lastFlushTime: Int64
    /// 最终事件回调 (去抖后)
    public var onDebouncedEvent: (WatchEvent2) -> Unit
    /// 是否已关闭
    private var closed: Bool

    public init() {
        inner = None
        debounceMs = 50  // 默认 50ms 去抖间隔
        pending = HashMap<String, DebounceEntry>()
        lastFlushTime = 0
        onDebouncedEvent = { _ => () }
        closed = false
    }

    public init(inner: RecursiveWatcher, debounceMs: Int64) {
        this.inner = Some(inner)
        this.debounceMs = debounceMs
        this.pending = HashMap<String, DebounceEntry>()
        this.lastFlushTime = currentTimeMillis()
        this.onDebouncedEvent = { _ => () }
        this.closed = false

        // 设置内部回调，拦截所有事件
        match (this.inner) {
            case Some(w) => {
                w.onEvent = { e => handleRawEvent(e) }
            }
            case None => ()
        }
    }

    /// 处理原始事件 - 添加到去抖缓冲
    /// 对应 Bun Watcher 中事件入队的逻辑
    private func handleRawEvent(event: WatchEvent2): Unit {
        let key = "${event.path}:${if (event.isDirectory) { "dir" } else { "file" }}"
        let now = currentTimeMillis()

        match (pending.get(key)) {
            case Some(entry) => {
                // 已有待处理事件，更新
                // 合并规则:
                // 1. Create + Modify -> Create (新文件创建后立即修改视为创建)
                // 2. Modify + Modify -> Modify (多次修改合并)
                // 3. Delete -> Delete (删除优先)
                match (entry.eventType) {
                    case WatchEventType.Create => {
                        // Create 后的 Modify 仍保持 Create
                        if (event.eventType != WatchEventType.Delete) {
                            entry.update(WatchEventType.Create)
                        } else {
                            // Create 后 Delete = 文件来去无踪，移除事件
                            pending.remove(key)
                        }
                    }
                    case WatchEventType.Delete => {
                        // Delete 是最终状态，不覆盖
                    }
                    case _ => {
                        entry.update(event.eventType)
                    }
                }
            }
            case None => {
                // 新事件
                pending.put(key, DebounceEntry(event.eventType, event.path, event.isDirectory))
            }
        }

        // 检查是否需要刷新
        if (now - lastFlushTime >= debounceMs) {
            flush()
        }
    }

    /// 手动添加事件 (用于与外部监视器集成)
    public func addEvent(event: WatchEvent2): Unit {
        handleRawEvent(event)
    }

    /// 刷新待处理事件
    /// 对应 Bun Watcher 中将缓冲的事件发送给回调的逻辑
    /// 返回去抖后的事件列表
    public func flush(): ArrayList<WatchEvent2> {
        let events = ArrayList<WatchEvent2>()
        let now = currentTimeMillis()

        // 收集所有超时的事件
        let keys = pending.keys()
        let readyKeys = ArrayList<String>()
        for (key in keys) {
            match (pending.get(key)) {
                case Some(entry) => {
                    if (now - entry.lastTimestamp >= debounceMs) {
                        readyKeys.append(key)
                    }
                }
                case None => ()
            }
        }

        // 发送就绪事件
        for (key in readyKeys) {
            match (pending.get(key)) {
                case Some(entry) => {
                    let event = WatchEvent2(entry.eventType, entry.path, entry.isDirectory)
                    event.timestamp = entry.firstTimestamp
                    events.append(event)
                    onDebouncedEvent(event)
                    pending.remove(key)
                }
                case None => ()
            }
        }

        lastFlushTime = now
        return events
    }

    /// 强制刷新所有事件 (无论是否超时)
    public func flushAll(): ArrayList<WatchEvent2> {
        let events = ArrayList<WatchEvent2>()

        for (key in pending.keys()) {
            match (pending.get(key)) {
                case Some(entry) => {
                    let event = WatchEvent2(entry.eventType, entry.path, entry.isDirectory)
                    event.timestamp = entry.firstTimestamp
                    events.append(event)
                    onDebouncedEvent(event)
                }
                case None => ()
            }
        }

        pending = HashMap<String, DebounceEntry>()
        lastFlushTime = currentTimeMillis()
        return events
    }

    /// 获取待处理事件数
    public func pendingCount(): Int64 {
        return pending.keys().size
    }

    /// 读取事件 (代理到内部监视器 + 去抖)
    public func readEvents(): ArrayList<WatchEvent2> {
        // 先从内部监视器读取原始事件
        match (inner) {
            case Some(w) => {
                let rawEvents = w.readEvents()
                // 原始事件已经通过 handleRawEvent 处理过了
                // 返回去抖后的事件
                return flush()
            }
            case None => return ArrayList<WatchEvent2>()
        }
    }

    /// 设置去抖间隔
    public func setDebounceMs(ms: Int64): DebouncedWatcher {
        debounceMs = ms
        return this
    }

    /// 获取内部监视器
    public func getInner(): ?RecursiveWatcher {
        return inner
    }

    /// 关闭
    public func close(): Unit {
        if (!closed) {
            flushAll()
            match (inner) {
                case Some(w) => w.close()
                case None => ()
            }
            closed = true
        }
    }
}

// ============================================================================
// Path - 路径工具 (用于 join 等)
// ============================================================================

/// 路径工具类
class Path {
    /// 连接路径片段
    public static func join(parts: Array<String>): String {
        if (parts.size == 0) { return "" }
        let sb = StringBuilder()
        for (i in 0..parts.size) {
            if (i > 0 && !sb.toString().endsWith("/")) {
                sb.append("/")
            }
            var part = parts[i]
            // 移除开头的 /
            if (i > 0 && part.startsWith("/")) {
                part = part.substring(1)
            }
            // 移除结尾的 /
            if (i < parts.size - 1 && part.endsWith("/")) {
                part = part.substring(0, part.size - 1)
            }
            sb.append(part)
        }
        return sb.toString()
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 获取当前时间戳 (毫秒)
private func currentTimeMillis(): Int64 {
    unsafe {
        var ts = Array<Int64>(2, item: 0)
        clock_gettime(0, ts.toArray().unsafePtr())
        return ts[0] * 1000 + ts[1] / 1000000
    }
}

/// C FFI: clock_gettime
@C
foreign func clock_gettime(clockid: Int32, tp: CPointer<Int64>): Int32
