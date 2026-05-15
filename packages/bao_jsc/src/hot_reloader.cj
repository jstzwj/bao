// 严格翻译自: src/jsc/hot_reloader.zig
// 热重载器 - 文件监视与模块热重载

package bao_jsc

// ============================================================================
// ImportWatcher - 导入监视器联合类型
// 严格翻译自 ImportWatcher union
// ============================================================================
public enum ImportWatcher {
    case none
    case hot(Watcher)
    case watch(Watcher)

    /// 启动监视器
    /// 对应 Bun: ImportWatcher.start
    public func start() {
        match (this) {
            case hot(let w) => w.start()
            case watch(let w) => w.start()
            case none => {}
        }
    }

    /// 获取监视列表
    /// 对应 Bun: ImportWatcher.watchlist
    public func watchlist() -> WatchList {
        match (this) {
            case hot(let w) => w.watchlist()
            case watch(let w) => w.watchlist()
            case none => WatchList()
        }
    }

    /// 获取哈希索引
    /// 对应 Bun: ImportWatcher.indexOf
    public func indexOf(hash: UInt32) -> ?UInt32 {
        match (this) {
            case hot(let w) => w.indexOf(hash)
            case watch(let w) => w.indexOf(hash)
            case none => None
        }
    }

    /// 通过路径缓慢添加文件
    /// 对应 Bun: ImportWatcher.addFileByPathSlow
    public func addFileByPathSlow(filePath: String, loader: Loader) -> Bool {
        match (this) {
            case hot(let w) => w.addFileByPathSlow(filePath, loader)
            case watch(let w) => w.addFileByPathSlow(filePath, loader)
            case none => true
        }
    }

    /// 添加文件
    /// 对应 Bun: ImportWatcher.addFile
    public func addFile(
        fd: FD,
        filePath: String,
        hash: UInt32,
        loader: Loader,
        dirFd: FD,
        packageJson: ?PackageJSON,
        copyFilePath: Bool
    ) -> MaybeVoid {
        match (this) {
            case hot(let watcher) => watcher.addFile(fd, filePath, hash, loader, dirFd, packageJson, copyFilePath)
            case watch(let watcher) => watcher.addFile(fd, filePath, hash, loader, dirFd, packageJson, copyFilePath)
            case none => MaybeVoid.success
        }
    }
}

// ============================================================================
// 全局变量
// ============================================================================

/// 当非 null 时，onFileUpdate 在触发重载之前记录每个更改文件的绝对路径。
/// 由 `bun test --changed --watch` 使用，以便重启的进程可以缩小其更改文件集合
/// 对应 Bun: watch_changed_paths
public var watchChangedPaths: ?StringSet = None

/// 临时文件的绝对路径，flushChangedPathsForReload 将更改路径列表写入其中。
/// 通过 BUN_INTERNAL_TEST_CHANGED_TRIGGER_FILE 环境变量导出
/// 对应 Bun: watch_changed_trigger_file
public var watchChangedTriggerFile: ?String = None

/// 记录更改路径
/// 对应 Bun: recordChangedPath
public func recordChangedPath(path: String) {
    let set = watchChangedPaths ?? return
    if (path.isEmpty) {
        return
    }
    set.insert(path)
}

/// 将记录的更改路径写入触发文件，以便下一个进程（exec() 之后）可以消费它们。
/// 尽力而为：如果写入失败，新进程会回退到查询 git。
/// 对应 Bun: flushChangedPathsForReload
public func flushChangedPathsForReload() {
    if (Environment.isWindows) {
        return
    }

    let set = watchChangedPaths ?? return
    let dest = watchChangedTriggerFile ?? return
    if (set.count() == 0) {
        return
    }

    var buf = ArrayListByte()
    for (p in set.keys()) {
        buf.appendSlice(p)
        buf.append(Byte('\n'.code))
    }
    let _ = File.writeFile(FD.cwd(), dest, buf.items())
}

/// 外部函数声明 - 调试器将热重载
/// 对应 Bun: extern fn BunDebugger__willHotReload
public func bunDebuggerWillHotReload() {
    // FFI: BunDebugger__willHotReload
}

// ============================================================================
// HotReloader - 热重载器
// 对应 Bun: HotReloader = NewHotReloader(VirtualMachine, jsc.EventLoop, false)
// ============================================================================
public class HotReloader {
    public var ctx: BunVirtualMachine
    public var verbose: Bool = false
    public var pendingCount: AtomicUInt32 = AtomicUInt32(0)
    public var main: MainFile = MainFile()
    public var tombstones: StringHashMapEntriesOption = StringHashMapEntriesOption()

    public init(ctx: BunVirtualMachine) {
        this.ctx = ctx
    }

    /// 初始化热重载器
    /// 对应 Bun: NewHotReloader.init
    public static func init_(ctx: BunVirtualMachine, fs: FileSystem, verbose: Bool, clearScreenFlag: Bool) -> Watcher {
        let reloader = HotReloader(ctx)
        reloader.verbose = verbose

        NewHotReloaderStatic.clearScreen = clearScreenFlag
        let watcher = Watcher.initForReloader(reloader, fs)
        watcher.start()
        return watcher
    }

    /// 调试输出
    /// 对应 Bun: NewHotReloader.debug
    public static func debug(fmt: String, args: Array<String>) {
        Output.printError("watcher: " + fmt, args)
    }

    /// 获取事件循环
    /// 对应 Bun: NewHotReloader.eventLoop
    public func eventLoop() -> EventLoop {
        ctx.eventLoop()
    }

    /// 并发入队任务
    /// 对应 Bun: NewHotReloader.enqueueTaskConcurrent
    public func enqueueTaskConcurrent(task: ConcurrentTask) {
        this.eventLoop().enqueueTaskConcurrent(task)
    }

    /// 放入墓碑（已删除条目缓存）
    /// 对应 Bun: putTombstone
    public func putTombstone(key: String, value: EntriesOption) {
        tombstones.put(key, value)
    }

    /// 获取墓碑
    /// 对应 Bun: getTombstone
    public func getTombstone(key: String) -> ?EntriesOption {
        tombstones.get(key)
    }

    /// 错误处理回调
    /// 对应 Bun: NewHotReloader.onError
    public func onError(err: SystemError) {
        Output.err(err.errno, "Watcher crashed", [])
    }

    /// 获取上下文（Watcher）
    /// 对应 Bun: NewHotReloader.getContext
    public func getContext() -> Watcher {
        ctx.getWatcher()
    }

    /// 启用热模块重载
    /// 对应 Bun: NewHotReloader.enableHotModuleReloading
    public static func enableHotModuleReloading(ctx: BunVirtualMachine, entryPath: ?String) {
        if (ctx.hasWatcher()) {
            return
        }

        let reloader = HotReloader(ctx)
        reloader.main = MainFile.init_(entryPath ?? "")

        ctx.setupWatcher(reloader)

        NewHotReloaderStatic.clearScreen = !ctx.env().hasSetNoClearTerminalOnReload(!Output.enableAnsiColorsStdout)

        let _ = reloader.getContext().start()
    }

    /// 文件更新回调
    /// 对应 Bun: NewHotReloader.onFileUpdate
    public func onFileUpdate(
        events: Array<WatchEvent>,
        changedFiles: Array<?String>,
        watchlist: WatchList
    ) {
        let slice = watchlist.slice()
        let filePaths = slice.filePaths
        let counts = slice.counts
        let kinds = slice.kinds
        let hashes = slice.hashes
        let parents = slice.parentHashes
        let fileDescriptors = slice.fileDescriptors
        let watcherCtx = getContext()
        defer watcherCtx.flushEvictions()
        defer Output.flush()

        let fs: FileSystem = FileSystem.instance
        let rfs: RealFS = fs.realFS
        var pathBuf: Array<Byte> = Array<Byte>(capacity: PathBuffer.MAX_SIZE)
        var currentTask = HotReloaderTask.initEmpty(this)
        defer currentTask.enqueue()

        for (event in events) {
            // 过时的 udata: kevent.udata 可以在 flushEvictions 的 swapRemove 之后仍然存在
            if (event.index >= filePaths.length) {
                continue
            }
            let filePath = filePaths[event.index]
            let updateCount = counts[event.index] + 1
            counts[event.index] = updateCount
            let kind = kinds[event.index]
            let currentHash = hashes[event.index]

            match (kind) {
                case .file => {
                    if (event.op.delete || (event.op.rename && Environment.isKqueue)) {
                        watcherCtx.removeAtIndex(
                            event.index,
                            0,
                            [],
                            .file
                        )
                    }

                    if (verbose) {
                        HotReloader.debug("File changed: {s}", [fs.relativeTo(filePath)])
                    }

                    if (event.op.write || event.op.delete || event.op.rename) {
                        recordChangedPath(filePath)

                        if (Environment.isKqueue) {
                            if (event.op.rename) {
                                // 特殊处理入口点：延迟重载直到获得目录写入事件确认文件存在。
                                // 这处理了 vim 的保存过程，在创建新文件之前重命名旧文件。
                                if (main.hash == currentHash) {
                                    main.isWaitingForDirChange = true
                                    continue
                                }
                            }

                            // 如果在重命名后获得写入事件，文件已恢复 - 继续重载
                            if (main.isWaitingForDirChange && main.hash == currentHash) {
                                main.isWaitingForDirChange = false
                            }
                        }

                        currentTask.append(currentHash)
                    }
                }
                case .directory => {
                    if (Environment.isWindows) {
                        // 在 Windows 上，我们接收受目录更改影响的所有文件事件
                        // 所以只需要清除目录缓存
                        let _ = ctx.bustDirCache(Strings.withoutTrailingSlashWindowsPath(filePath))
                        continue
                    }

                    var affectedBuf: Array<String> = Array<String>(capacity: 128)
                    var entriesOption: ?EntriesOption = None

                    let affected: Array<String> = if (Environment.isKqueue) {
                        if (let existing = rfs.entries.get(filePath)) {
                            putTombstone(filePath, existing)
                            entriesOption = existing
                        } else if (let existing = getTombstone(filePath)) {
                            entriesOption = existing
                        }

                        if (event.op.write) {
                            // 检查原子保存后入口点是否已存在。
                            // 如果之前入口点获得了 NOTE_RENAME（vim 重命名了文件），
                            // 此目录写入事件表示新文件已被重新创建。验证它是否存在并触发重载。
                            if (main.isWaitingForDirChange && main.dirHash == currentHash) {
                                if (SysFaccessat.fileAccessible(fileDescriptors[event.index], PathBasename.basename(main.file))) {
                                    main.isWaitingForDirChange = false
                                    recordChangedPath(main.file)
                                    currentTask.append(main.hash)
                                }
                            }
                        }

                        var affectedI: Int64 = 0

                        // 如果文件描述符过时，需要关闭它
                        if (event.op.delete && entriesOption != None) {
                            for (i in 0..parents.length) {
                                let parentHash = parents[i]
                                if (parentHash == currentHash) {
                                    let affectedPath = filePaths[i]
                                    let wasDeleted = !SysAccess.fileExists(affectedPath)
                                    if (!wasDeleted) {
                                        continue
                                    }

                                    affectedBuf[affectedI] = affectedPath[filePath.length..]
                                    affectedI += 1
                                    if (affectedI >= affectedBuf.capacity) {
                                        break
                                    }
                                }
                            }
                        }

                        affectedBuf[0..affectedI]
                    } else {
                        event.names(changedFiles)
                    }

                    if (affected.length > 0 && !Environment.isKqueue) {
                        if (let existing = rfs.entries.get(filePath)) {
                            putTombstone(filePath, existing)
                            entriesOption = existing
                        } else if (let existing = getTombstone(filePath)) {
                            entriesOption = existing
                        }
                    }

                    let _ = ctx.bustDirCache(Strings.withoutTrailingSlashWindowsPath(filePath))

                    // 入口点的重新创建检测（非 kqueue 平台）：
                    // 被监视的入口点有一个针对其 inode 的 per-file inotify 监视。
                    // 原子重命名（例如 `rename(tmp, entrypoint)`）或删除+重新创建
                    // 会删除该 inode，因此内核会丢弃 per-file 监视
                    // （IN_DELETE_SELF + IN_IGNORED）。当文件事件和此目录事件
                    // 落在不同的 processINotifyEventBatch 批次中时，
                    // flushEvictions 在两者之间运行，条目在看到重新创建的文件
                    // 之前已从 `hashes` 中消失 - 因此重新创建入口点的重载被丢弃，
                    // `--hot` 死锁。
                    //
                    // 恢复方式与 kqueue 相同：如果此目录事件命名了入口点
                    // 并且文件现在存在，则重新触发重载。
                    if (!Environment.isKqueue) {
                        if (main.hash != 0 && main.dirHash == currentHash) {
                            let mainBasename = PathBasename.basename(main.file)
                            for (changedName_ in affected) {
                                guard let changedName = changedName_ else {
                                    continue
                                }
                                if (changedName != mainBasename) {
                                    continue
                                }
                                let mainExists = SysAccess.fileExists(main.file)
                                if (mainExists) {
                                    recordChangedPath(main.file)
                                    currentTask.append(main.hash)
                                }
                                break
                            }
                        }
                    }

                    if (let dirEnt = entriesOption) {
                        var lastFileHash: UInt32 = UInt32.maxValue

                        for (changedName_ in affected) {
                            let changedName: String = if (Environment.isKqueue) {
                                changedName_
                            } else {
                                changedName_ ?? ""
                            }
                            if (changedName.isEmpty || changedName[0] == '~' || changedName[0] == '.') {
                                continue
                            }

                            let loader = ctx.getLoaders().get(FsPathName.findExtname(changedName)) ?? Loader.file
                            var prevEntryId: Int64 = Int64.maxValue
                            if (loader != .file) {
                                var pathString: PathString = PathString()
                                var fileHash: UInt32 = lastFileHash
                                let absPath: String

                                if (let fileEnt = dirEnt.entries.get(changedName)) {
                                    // 重置文件描述符
                                    fileEnt.entry.cache.fd = FD.invalid
                                    fileEnt.entry.needStat = true
                                    pathString = fileEnt.entry.absPath
                                    fileHash = WatcherGetHash.fromString(pathString.slice())
                                    for (i in 0..hashes.length) {
                                        let hash = hashes[i]
                                        if (hash == fileHash) {
                                            if (fileDescriptors[i].isValid()) {
                                                if (prevEntryId != i) {
                                                    recordChangedPath(pathString.slice())
                                                    currentTask.append(hashes[i])
                                                    if (verbose) {
                                                        HotReloader.debug("Removing file: {s}", [pathString.slice()])
                                                    }
                                                    watcherCtx.removeAtIndex(
                                                        UInt16(i),
                                                        0,
                                                        [],
                                                        .file
                                                    )
                                                }
                                            }
                                            prevEntryId = i
                                            break
                                        }
                                    }
                                    absPath = pathString.slice()
                                } else {
                                    let filePathWithoutTrailingSlash = Strings.trimRight(filePath, PathSeparator.sepStr)
                                    pathBuf = filePathWithoutTrailingSlash.toByteArray()
                                    pathBuf.append(PathSeparator.sep)
                                    pathBuf.appendAll(changedName.toByteArray())
                                    let pathSlice = pathBuf.toArray()
                                    fileHash = WatcherGetHash.fromBytes(pathSlice)
                                    absPath = String(pathSlice)
                                }

                                // 跳过连续的重复项
                                if (lastFileHash == fileHash) {
                                    continue
                                }
                                lastFileHash = fileHash

                                if (verbose) {
                                    HotReloader.debug("File change: {s}", [fs.relativeTo(absPath)])
                                }
                            }
                        }
                    }

                    if (verbose) {
                        HotReloader.debug("Dir change: {s} (affecting {d})", [fs.relativeTo(filePath), String(affected.length)])
                    }
                }
            }
        }
    }
}

// ============================================================================
// WatchReloader - 监视重载器
// 对应 Bun: WatchReloader = NewHotReloader(VirtualMachine, jsc.EventLoop, true)
// 与 HotReloader 相同，但在变更时立即重新加载进程（reload_immediately = true）
// ============================================================================
public class WatchReloader {
    public var ctx: BunVirtualMachine
    public var verbose: Bool = false
    public var pendingCount: AtomicUInt32 = AtomicUInt32(0)
    public var main: MainFile = MainFile()
    public var tombstones: StringHashMapEntriesOption = StringHashMapEntriesOption()

    public init(ctx: BunVirtualMachine) {
        this.ctx = ctx
    }

    /// 获取上下文（Watcher）
    /// 对应 Bun: NewHotReloader.getContext
    public func getContext() -> Watcher {
        ctx.getWatcher()
    }

    /// 获取事件循环
    /// 对应 Bun: NewHotReloader.eventLoop
    public func eventLoop() -> EventLoop {
        ctx.eventLoop()
    }

    /// 错误处理回调
    /// 对应 Bun: NewHotReloader.onError
    public func onError(err: SystemError) {
        Output.err(err.errno, "Watcher crashed", [])
    }

    /// 文件更新回调 - 立即重载模式（reload_immediately = true）
    /// 对应 Bun: NewHotReloader.onFileUpdate (with reload_immediately = true)
    public func onFileUpdate(
        events: Array<WatchEvent>,
        changedFiles: Array<?String>,
        watchlist: WatchList
    ) {
        let watcherCtx = getContext()
        defer watcherCtx.flushEvictions()
        defer Output.flush()

        let slice = watchlist.slice()
        let filePaths = slice.filePaths
        let counts = slice.counts
        let kinds = slice.kinds
        let hashes = slice.hashes

        var currentTask = HotReloaderTask.initEmptyForWatch(this)

        for (event in events) {
            if (event.index >= filePaths.length) {
                continue
            }
            let filePath = filePaths[event.index]
            let updateCount = counts[event.index] + 1
            counts[event.index] = updateCount
            let kind = kinds[event.index]
            let currentHash = hashes[event.index]

            match (kind) {
                case .file => {
                    if (event.op.write || event.op.delete || event.op.rename) {
                        recordChangedPath(filePath)
                        currentTask.append(currentHash)
                    }
                }
                case .directory => {
                    let _ = ctx.bustDirCache(Strings.withoutTrailingSlashWindowsPath(filePath))
                }
            }
        }

        // 立即重载：当 reload_immediately = true 时，直接重载进程
        // 对应 Bun: Task.enqueue 中 reload_immediately 分支
        if (currentTask.count > 0) {
            Output.flush()
            flushChangedPathsForReload()
            BunReload.reloadProcess(BunAlloc.defaultAllocator, NewHotReloaderStatic.clearScreen, false)
        }
    }
}

// ============================================================================
// MainFile - 主文件信息
// 严格翻译自 NewHotReloader.MainFile struct
// ============================================================================
public class MainFile {
    /// 包含尾部 "/"
    public var dir: String = ""
    public var dirHash: UInt32 = 0

    public var file: String = ""
    public var hash: UInt32 = 0

    /// 在 macOS 上，vim 的原子保存触发竞态条件：
    /// 1. 旧文件获得 NOTE_RENAME（文件重命名为临时名称：a.js -> a.js~）
    /// 2. 我们收到事件并通常会立即触发重载
    /// 3. 但新文件尚未创建 - 重载因 ENOENT 失败
    /// 4. 新文件被创建和写入（a.js）
    /// 5. 父目录获得 NOTE_WRITE
    ///
    /// 修复方法：当入口点获得 NOTE_RENAME 时，设置此标志并跳过重载。
    /// 然后当父目录获得 NOTE_WRITE 时，检查文件是否存在并触发重载。
    public var isWaitingForDirChange: Bool = false

    public init() {}

    /// 初始化主文件
    /// 对应 Bun: MainFile.init
    public static func init_(file: String) -> MainFile {
        let main = MainFile()
        main.file = file
        main.hash = if (!file.isEmpty) { WatcherGetHash.fromString(file) } else { 0 }
        main.isWaitingForDirChange = false

        if (let dir = FsPathName.dirname(file)) {
            main.dir = file[0..(dir.length + 1)]
            main.dirHash = WatcherGetHash.fromString(main.dir)
        }

        return main
    }
}

// ============================================================================
// HotReloaderTask - 热重载任务
// 严格翻译自 NewHotReloader.Task struct
// ============================================================================
public class HotReloaderTask {
    public var count: UInt8 = 0
    public var hashes: Array<UInt32> = Array<UInt32>(8, item: 0)
    public var paths: Array<String> = Array<String>(8, item: "")
    public var concurrentTask: ConcurrentTask = ConcurrentTask()
    public var reloader: HotReloader
    public var isWatchMode: Bool = false
    public var watchReloader: ?WatchReloader = None

    public init(reloader: HotReloader) {
        this.reloader = reloader
    }

    public init(watchReloader: WatchReloader) {
        this.reloader = HotReloader(watchReloader.ctx)
        this.watchReloader = watchReloader
        this.isWatchMode = true
    }

    /// 创建空任务
    /// 对应 Bun: Task.initEmpty
    public static func initEmpty(reloader: HotReloader) -> HotReloaderTask {
        let task = HotReloaderTask(reloader)
        task.count = 0
        return task
    }

    /// 创建空任务（监视模式）
    public static func initEmptyForWatch(reloader: WatchReloader) -> HotReloaderTask {
        let task = HotReloaderTask(watchReloader: reloader)
        task.count = 0
        return task
    }

    /// 追加哈希
    /// 对应 Bun: Task.append
    public func append(id: UInt32) {
        if (count == 8) {
            enqueue()
            count = 0
        }
        hashes[Int64(count)] = id
        count += 1
    }

    /// 运行任务
    /// 对应 Bun: Task.run
    /// 由于我们依赖事件循环进行热重载，在下一次重载开始之前可能会有延迟。
    /// 在上次重载和下一次重载之间的时间，我们不应安排更多的热重载。
    /// 由于我们确实重载所有内容，我们不需要担心遗漏任何更改。
    public func run() {
        while (reloader.pendingCount.swap(0) > 0) {
            reloader.ctx.reload(this)
        }
    }

    /// 入队任务
    /// 对应 Bun: Task.enqueue
    public func enqueue() {
        if (count == 0) {
            return
        }

        if (isWatchMode) {
            // reload_immediately 模式：直接重载进程
            // 对应 Bun: if (comptime reload_immediately) { ... bun.reloadProcess(...) }
            Output.flush()
            flushChangedPathsForReload()
            BunReload.reloadProcess(BunAlloc.defaultAllocator, NewHotReloaderStatic.clearScreen, false)
            return
        }

        let _ = reloader.pendingCount.fetchAdd(1)

        bunDebuggerWillHotReload()
        let that = HotReloaderTask(reloader)
        that.count = count
        that.hashes = hashes
        that.concurrentTask = ConcurrentTask()
        that.reloader.enqueueTaskConcurrent(that.concurrentTask)
        count = 0
    }

    /// 释放资源
    /// 对应 Bun: Task.deinit
    public func deinit() {}
}

// ============================================================================
// NewHotReloaderStatic - 静态变量容器
// 对应 Bun: NewHotReloader 中的 clear_screen 静态变量
// ============================================================================
public class NewHotReloaderStatic {
    public static var clearScreen: Bool = false
}

// ============================================================================
// 支撑类型
// ============================================================================

public class Watcher {
    public func start() {}
    public func watchlist() -> WatchList { WatchList() }
    public func indexOf(_ hash: UInt32) -> ?UInt32 { None }
    public func addFileByPathSlow(_ path: String, _ loader: Loader) -> Bool { true }
    public func addFile(_ fd: FD, _ filePath: String, _ hash: UInt32, _ loader: Loader, _ dirFd: FD, _ packageJson: ?PackageJSON, _ copyFilePath: Bool) -> MaybeVoid { MaybeVoid.success }
    public func flushEvictions() {}
    public func removeAtIndex(_ index: Int64, _ count: Int64, _ items: Array<Any>, _ kind: WatchKind) {}
    public static func initForReloader(_ reloader: HotReloader, _ fs: FileSystem) -> Watcher { Watcher() }
}

public class WatcherGetHash {
    public static func fromString(_ str: String) -> UInt32 { 0 }
    public static func fromBytes(_ bytes: Array<Byte>) -> UInt32 { 0 }
}

public class WatchList {
    public init() {}
    public func slice() -> WatchListSlice { WatchListSlice() }
}

public class WatchListSlice {
    public var filePaths: Array<String> = []
    public var counts: Array<UInt32> = []
    public var kinds: Array<WatchKind> = []
    public var hashes: Array<UInt32> = []
    public var parentHashes: Array<UInt32> = []
    public var fileDescriptors: Array<FD> = []
}

public enum WatchKind {
    case file
    case directory
}

public class WatchEvent {
    public var index: Int64 = 0
    public var op: WatchEventOp = WatchEventOp()
    public init() {}

    public func names(_ changedFiles: Array<?String>) -> Array<String> { [] }
}

public class WatchEventOp {
    public var write: Bool = false
    public var delete: Bool = false
    public var rename: Bool = false
    public init() {}
}

public class ConcurrentTask {
    public init() {}
}

public enum MaybeVoid {
    case success
    case err(SystemError)
}

public class StringSet {
    public func insert(_ key: String) {}
    public func count() -> Int64 { 0 }
    public func keys() -> Array<String> { [] }
}

public class StringHashMapEntriesOption {
    public func put(_ key: String, _ value: EntriesOption) {}
    public func get(_ key: String) -> ?EntriesOption { None }
}

public class EntriesOption {
    public var entries: StringHashMapFileEntry = StringHashMapFileEntry()
}

public class StringHashMapFileEntry {
    public func get(_ key: String) -> ?FileEntry { None }
}

public class FileEntry {
    public var entry: DirEntry = DirEntry()
}

public class DirEntry {
    public var cache: FileCache = FileCache()
    public var needStat: Bool = false
    public var absPath: PathString = PathString()
}

public class FileCache {
    public var fd: FD = FD.invalid
}

public class FD {
    public static let invalid: FD = FD(-1)
    public static func cwd() -> FD { FD(0) }
    public func isValid() -> Bool { true }
    public var value: Int64
    public init(_ v: Int64) { value = v }
}

public class Loader {
    public static let file: Loader = Loader()
    public static let js: Loader = Loader()
    public init() {}
}

public class PackageJSON {}

public class FileSystem {
    public static let instance: FileSystem = FileSystem()
    public var realFS: RealFS = RealFS()
    public func relativeTo(_ path: String) -> String { path }
}

public class RealFS {
    public var entries: StringHashMapEntriesOption = StringHashMapEntriesOption()
}

public class PathBuffer {
    public static let MAX_SIZE: Int64 = 4096
}

public class FsPathName {
    public static func dirname(_ path: String) -> ?String {
        if (path.isEmpty) { return None }
        let lastSep = path.lastIndexOf('/')
        if (lastSep < 0) { return None }
        return path[0..lastSep]
    }

    public static func findExtname(_ name: String) -> String {
        let dotIndex = name.lastIndexOf('.')
        if (dotIndex < 0) { return "" }
        return name[dotIndex..name.length]
    }
}

public class PathBasename {
    public static func basename(_ path: String) -> String {
        let lastSep = path.lastIndexOf('/')
        if (lastSep < 0) { return path }
        return path[(lastSep + 1)..path.length]
    }
}

public class PathString {
    public func slice() -> String { "" }
}

public class PathSeparator {
    public static let sep: Byte = Byte('/'.code)
    public static let sepStr: String = "/"
}

public class SysAccess {
    public static func fileExists(_ path: String) -> Bool { true }
}

public class SysFaccessat {
    public static func fileAccessible(_ fd: FD, _ path: String) -> Bool { true }
}

public class SystemError {
    public var errno: Int32 = 0
}

public class AtomicUInt32 {
    public var value: UInt32
    public init(_ v: UInt32) { value = v }
    public func swap(_ newVal: UInt32) -> UInt32 {
        let old = value
        value = newVal
        return old
    }
    public func fetchAdd(_ val: UInt32) -> UInt32 {
        let old = value
        value = value + val
        return old
    }
}

public class ArrayListByte {
    private var data: Array<Byte> = []
    public init() {}
    public func appendSlice(_ s: String) { data.appendAll(s.toByteArray()) }
    public func append(_ b: Byte) { data.append(b) }
    public func appendAll(_ bytes: Array<Byte>) { data.appendAll(bytes) }
    public func items() -> Array<Byte> { data }
}

public class BunVirtualMachine {
    public func eventLoop() -> EventLoop { EventLoop() }
    public func reload(_ task: HotReloaderTask) {}
    public func bustDirCache(_ path: String) -> Bool { false }
    public func getLoaders() -> StringHashMapLoader { StringHashMapLoader() }
    public func hasWatcher() -> Bool { false }
    public func getWatcher() -> Watcher { Watcher() }
    public func setupWatcher(_ reloader: HotReloader) {}
    public func env() -> BunEnvironment { BunEnvironment() }
}

public class EventLoop {
    public func tick() {}
    public func enqueueTaskConcurrent(_ task: ConcurrentTask) {}
}

public class BunEnvironment {
    public func hasSetNoClearTerminalOnReload(_ v: Bool) -> Bool { false }
}

public class Environment {
    public static let isWindows: Bool = false
    public static let isKqueue: Bool = false
    public static let isDebug: Bool = false
}

public class Output {
    public static let enableAnsiColorsStdout: Bool = true
    public static func flush() {}
    public static func err(_ errno: Int32, _ msg: String, _ args: Array<Any>) {}
    public static func printError(_ msg: String, _ args: Array<String>) {}
}

public class File {
    public static func writeFile(_ fd: FD, _ path: String, _ content: Array<Byte>) {}
}

public class Strings {
    public static func withoutTrailingSlashWindowsPath(_ path: String) -> String { path }
    public static func trimRight(_ s: String, _ chars: String) -> String { s }
}

public class BunReload {
    public static func reloadProcess(_ alloc: BunAlloc, _ clearScreen: Bool, _ force: Bool) {}
}

public class BunAlloc {
    public static let defaultAllocator: BunAlloc = BunAlloc()
}

public class StringHashMapLoader {
    public func get(_ key: String) -> ?Loader { None }
}
