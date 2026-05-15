// bao_watcher - 主监视器结构 (跨平台抽象)
// 严格翻译自: src/watcher/Watcher.zig
//
// Bun 的 Watcher 是文件系统监视的核心:
//   - 在独立线程中运行 watchLoop
//   - 通过 Platform comptime 选择具体实现 (Linux → INotifyWatcher)
//   - 维护 WatchList (MultiArrayList<WatchItem>) 存储监视项
//   - 通过 onFileUpdate 回调通知文件变更
//   - 支持 evict_list 批量移除监视项
//   - 可选的 WatcherTrace 调试输出
package bao_watcher

import bao_core.*
import bao_sys.*
import bao_event_loop.*
import bao_threading.*

// ============================================================================
// Watcher - 主监视器类
// 严格翻译自: src/watcher/Watcher.zig:1-809
//
// Bun 的 Watcher 结构:
//   const Watcher = @This();  // 匿名结构体
//   watch_events: []WatchEvent = &.{},
//   changed_filepaths: [max_count]?[:0]u8,
//   platform: Platform,
//   watchlist: WatchList,
//   watched_count: usize,
//   mutex: Mutex,
//   fs: *bun.fs.FileSystem,
//   allocator: std.mem.Allocator,
//   watchloop_handle: ?std.Thread.Id = null,
//   cwd: string,
//   thread: std.Thread = undefined,
//   running: bool = true,
//   close_descriptors: bool = false,
//   evict_list: [max_eviction_count]WatchItemIndex = undefined,
//   evict_list_i: WatchItemIndex = 0,
//   ctx: *anyopaque,
//   onFileUpdate: *const fn (...) void,
//   onError: *const fn (...) void,
//   thread_lock: bun.safety.ThreadLock = .initUnlocked(),
// ============================================================================

/// 文件系统监视器 - 对应 Bun Watcher
/// 严格翻译自: Watcher.zig:1-809
///
/// Bun 使用 comptime 泛型 + 函数指针实现类型安全的回调
/// 仓颉使用泛型 Any + 函数类型实现等价语义
public class Watcher {
    // ========================================================================
    // 字段 - 对应 Bun Watcher 结构体字段
    // 严格翻译自: Watcher.zig:10-35
    // ========================================================================

    /// 事件缓冲区 - 对应 Watcher.watch_events: []WatchEvent
    /// Bun: pub const max_count = 128; watch_events = allocator.alloc(WatchEvent, max_count)
    private var watchEvents: Array<WatcherEvent>

    /// 变更文件路径缓冲区 - 对应 Watcher.changed_filepaths: [max_count]?[:0]u8
    /// Bun: changed_filepaths = [_]?[:0]u8{null} ** max_count
    private var changedFilepaths: Array<?String>

    /// 平台特定实现 - 对应 Watcher.platform: Platform
    /// Bun 使用 comptime switch 选择: Linux → INotifyWatcher, macOS → KEventWatcher
    /// 仓颉使用接口抽象
    private var platform: ?PlatformWatcher

    /// 监视列表 - 对应 Watcher.watchlist: WatchList
    /// Bun: pub const WatchList = std.MultiArrayList(WatchItem)
    private var watchlist: WatchList

    /// 已监视数量 - 对应 Watcher.watched_count: usize
    private var watchedCount: Int64

    /// 互斥锁 - 对应 Watcher.mutex: Mutex
    /// Bun: const Mutex = bun.Mutex (FutexImpl)
    private var mutex: Mutex

    /// 文件系统 - 对应 Watcher.fs: *bun.fs.FileSystem
    private var topLevelDir: String

    /// 监视循环线程 ID - 对应 Watcher.watchloop_handle: ?std.Thread.Id
    private var watchloopHandle: ?Int64

    /// 当前工作目录 - 对应 Watcher.cwd: string
    private var cwd: String

    /// 是否运行中 - 对应 Watcher.running: bool = true
    private var running: Bool

    /// 是否关闭描述符 - 对应 Watcher.close_descriptors: bool = false
    private var closeDescriptors: Bool

    /// 驱逐列表 - 对应 Watcher.evict_list: [max_eviction_count]WatchItemIndex
    /// 严格翻译自: Watcher.zig:28 evict_list: [max_eviction_count]WatchItemIndex
    private var evictList: Array<WatchItemIndex>

    /// 驱逐列表当前索引 - 对应 Watcher.evict_list_i: WatchItemIndex = 0
    private var evictListI: WatchItemIndex

    /// 上下文 - 对应 Watcher.ctx: *anyopaque
    private var ctx: Any

    /// 文件变更回调 - 对应 Watcher.onFileUpdate
    private var onFileUpdateFn: FileChangeCallback

    /// 错误回调 - 对应 Watcher.onError
    private var onErrorFn: ErrorCallback

    // ========================================================================
    // 初始化 - 对应 Bun Watcher.init
    // 严格翻译自: Watcher.zig:69-106
    //
    //   pub fn init(comptime T: type, ctx: *T, fs: *bun.fs.FileSystem,
    //              allocator: std.mem.Allocator) !*Watcher {
    //       const wrapped = struct {
    //           fn onFileUpdateWrapped(ctx_opaque: *anyopaque, ...) void { ... }
    //           fn onErrorWrapped(ctx_opaque: *anyopaque, ...) void { ... }
    //       };
    //       const watcher = try allocator.create(Watcher);
    //       watcher.* = .{
    //           .fs = fs, .allocator = allocator,
    //           .watched_count = 0, .watchlist = WatchList{},
    //           .mutex = .{}, .cwd = fs.top_level_dir,
    //           .ctx = ctx,
    //           .onFileUpdate = &wrapped.onFileUpdateWrapped,
    //           .onError = &wrapped.onErrorWrapped,
    //           .platform = .{},
    //           .watch_events = try allocator.alloc(WatchEvent, max_count),
    //           .changed_filepaths = [_]?[:0]u8{null} ** max_count,
    //       };
    //       try Platform.init(&watcher.platform, fs.top_level_dir);
    //       WatcherTrace.init();
    //       return watcher;
    //   }
    // ========================================================================

    /// 初始化监视器 - 对应 Bun Watcher.init(T, ctx, fs, allocator)
    /// 严格翻译自: Watcher.zig:69-106
    ///
    /// Bun 使用 comptime 泛型包装类型安全的回调
    /// 仓颉直接传入回调函数
    public init(ctx: Any, topLevelDir: String,
                onFileUpdate: FileChangeCallback,
                onError: ErrorCallback) {
        this.ctx = ctx
        this.topLevelDir = topLevelDir
        this.cwd = topLevelDir
        this.onFileUpdateFn = onFileUpdate
        this.onErrorFn = onError

        watchedCount = 0
        watchlist = WatchList()
        mutex = Mutex()
        watchloopHandle = None
        running = true
        closeDescriptors = false

        // 初始化事件缓冲区 - 对应 allocator.alloc(WatchEvent, max_count)
        watchEvents = Array<WatcherEvent>(WATCHER_MAX_COUNT, item: WatcherEvent())

        // 初始化变更路径缓冲区 - 对应 [_]?[:0]u8{null} ** max_count
        changedFilepaths = Array<?String>(WATCHER_MAX_COUNT, item: None)

        // 初始化驱逐列表 - 对应 [max_eviction_count]WatchItemIndex
        evictList = Array<WatchItemIndex>(WATCHER_MAX_EVICTION_COUNT, item: UInt16(0))
        evictListI = UInt16(0)

        // 平台特定初始化
        platform = None
    }

    /// 初始化平台实现 - 对应 Bun Platform.init(&watcher.platform, fs.top_level_dir)
    /// 严格翻译自: Watcher.zig:100
    ///   try Platform.init(&watcher.platform, fs.top_level_dir);
    ///
    /// 必须在构造后调用, 因为可能涉及系统调用 (inotify_init1 等)
    public func initPlatform(): Unit {
        let inotify = InotifyWatcher()
        let result = inotify.init(topLevelDir)
        match (result) {
            case Ok(_) => platform = inotify
            case Err(e) => throw BaoError(ErrorCode.Unexpected,
                "Failed to initialize inotify: ${e.toString()}")
        }

        // 初始化 trace - 对应 WatcherTrace.init()
        WatcherTrace.instance.init()
    }

    // ========================================================================
    // 启动/停止 - 对应 Bun Watcher.start / deinit
    // ========================================================================

    /// 启动监视线程 - 对应 Bun Watcher.start()
    /// 严格翻译自: Watcher.zig:114-117
    ///   pub fn start(this: *Watcher) !void {
    ///       bun.assert(this.watchloop_handle == null);
    ///       this.thread = try std.Thread.spawn(.{}, threadMain, .{this});
    ///   }
    public func start(): Unit {
        if (watchloopHandle != None) {
            throw BaoError(ErrorCode.Unexpected, "Watcher already started")
        }

        // 启动监视线程 - 对应 std.Thread.spawn(.{}, threadMain, .{this})
        let thread = spawnThread({
            this.threadMain()
        })
    }

    /// 停止监视器 - 对应 Bun Watcher.deinit(close_descriptors)
    /// 严格翻译自: Watcher.zig:119-136
    ///   pub fn deinit(this: *Watcher, close_descriptors: bool) void {
    ///       if (this.watchloop_handle != null) {
    ///           this.mutex.lock();
    ///           defer this.mutex.unlock();
    ///           this.close_descriptors = close_descriptors;
    ///           this.running = false;
    ///       } else {
    ///           if (close_descriptors and this.running) {
    ///               const fds = this.watchlist.items(.fd);
    ///               for (fds) |fd| { fd.close(); }
    ///           }
    ///           this.watchlist.deinit(this.allocator);
    ///           const allocator = this.allocator;
    ///           allocator.destroy(this);
    ///       }
    ///   }
    public func deinit(closeDescriptors: Bool): Unit {
        if (watchloopHandle != None) {
            mutex.lock()
            this.closeDescriptors = closeDescriptors
            running = false
            mutex.unlock()
        } else {
            if (closeDescriptors && running) {
                let fds = watchlist.fds()
                for (fd in fds) {
                    if (FdUtils.isValid(fd)) {
                        SysFs.close(fd)
                    }
                }
            }
            watchlist.deinit()

            // 关闭 trace - 对应 WatcherTrace.deinit()
            WatcherTrace.instance.deinit()
        }
    }

    // ========================================================================
    // 监视线程主循环 - 对应 Bun threadMain / watchLoop
    // 严格翻译自: Watcher.zig:229-330
    // ========================================================================

    /// 线程入口 - 对应 Bun Watcher.threadMain(this: *Watcher)
    /// 严格翻译自: Watcher.zig:229-262
    ///   fn threadMain(this: *Watcher) !void {
    ///       this.watchloop_handle = std.Thread.getCurrentId();
    ///       this.thread_lock.lock();
    ///       Output.Source.configureNamedThread("File Watcher");
    ///       defer Output.flush();
    ///       log("Watcher started", .{});
    ///       switch (this.watchLoop()) {
    ///           .err => |err| {
    ///               this.watchloop_handle = null;
    ///               this.platform.stop();
    ///               if (this.running) { this.onError(this.ctx, err); }
    ///           },
    ///           .result => {},
    ///       }
    ///       if (this.close_descriptors) {
    ///           const fds = this.watchlist.items(.fd);
    ///           for (fds) |fd| { fd.close(); }
    ///       }
    ///       this.watchlist.deinit(this.allocator);
    ///       WatcherTrace.deinit();
    ///       const allocator = this.allocator;
    ///       allocator.destroy(this);
    ///   }
    private func threadMain(): Unit {
        // 记录线程 ID - 对应 std.Thread.getCurrentId()
        watchloopHandle = currentThreadId()

        // 对应 Output.Source.configureNamedThread("File Watcher")
        // 仓颉暂无等价 API

        let loopResult = watchLoop()

        match (loopResult) {
            case Err(err) => {
                watchloopHandle = None
                if (let Some(p) = platform) {
                    p.stop()
                }
                if (running) {
                    onErrorFn(ctx, err)
                }
            }
            case Ok(_) => {
                // 正常退出
            }
        }

        // deinit 和 close descriptors
        // 严格翻译自: Watcher.zig:249-261
        if (closeDescriptors) {
            let fds = watchlist.fds()
            for (fd in fds) {
                if (FdUtils.isValid(fd)) {
                    SysFs.close(fd)
                }
            }
        }
        watchlist.deinit()
        WatcherTrace.instance.deinit()
    }

    /// 监视循环 - 对应 Bun Watcher.watchLoop(this: *Watcher)
    /// 严格翻译自: Watcher.zig:321-330
    ///   fn watchLoop(this: *Watcher) bun.sys.Maybe(void) {
    ///       while (this.running) {
    ///           switch (Platform.watchLoopCycle(this)) {
    ///               .err => |err| return .{ .err = err },
    ///               .result => |iter| iter,
    ///           }
    ///       }
    ///       return .success;
    ///   }
    private func watchLoop(): SysMaybe<Unit> {
        while (running) {
            // 调用平台特定的 watchLoopCycle
            // 严格翻译自: Platform.watchLoopCycle(this)
            // 在 Linux 上, 这会调用 INotifyWatcher.watchLoopCycle
            if (let Some(p) = platform) {
                let cycleResult = p.watchLoopCycle(this)
                match (cycleResult) {
                    case Err(err) => return SysMaybe<Unit>.Err(err)
                    case Ok(_) => () // 继续循环
                }
            } else {
                // 无平台实现, 无法继续
                return SysMaybe<Unit>.Err(SysError(UInt16(0), SysTag.TODO))
            }
        }
        return SysMaybe<Unit>.Ok(())
    }

    // ========================================================================
    // 文件监视管理 - 对应 Bun Watcher 的 addFile / addDirectory / remove
    // ========================================================================

    /// 计算路径哈希 - 对应 Bun Watcher.getHash(filepath)
    /// 严格翻译自: Watcher.zig:138-140
    ///   pub fn getHash(filepath: string) HashType {
    ///       return @as(HashType, @truncate(bun.hash(filepath)));
    ///   }
    public static func getHash(filepath: String): HashType {
        // 使用简单的 FNV-1a 哈希近似 Bun 的 bun.hash
        var hash: UInt32 = UInt32(2166136261)
        for (i in 0..filepath.size) {
            let ch = UInt32(Int32(filepath[i].value) & 0xFF)
            hash = hash ^ ch
            hash = hash * UInt32(16777619)
        }
        return hash
    }

    /// 按哈希查找索引 - 对应 Bun Watcher.indexOf(hash)
    /// 严格翻译自: Watcher.zig:749-756
    ///   pub fn indexOf(this: *Watcher, hash: HashType) ?u32 {
    ///       for (this.watchlist.items(.hash), 0..) |other, i| {
    ///           if (hash == other) return @as(u32, @truncate(i));
    ///       }
    ///       return null;
    ///   }
    public func indexOf(hash: HashType): ?Int64 {
        return watchlist.indexOfHash(hash)
    }

    /// 添加文件到监视列表 - 对应 Bun Watcher.addFile
    /// 严格翻译自: Watcher.zig:721-747
    ///   pub fn addFile(this: *Watcher, fd, file_path, hash, loader,
    ///                  dir_fd, package_json, clone_file_path) bun.sys.Maybe(void) {
    ///       this.mutex.lock();
    ///       defer this.mutex.unlock();
    ///       if (this.indexOf(hash)) |index| { ... return .success; }
    ///       return this.appendFileMaybeLock(...);
    ///   }
    public func addFile(fd: Int64, filePath: String, hash: HashType,
                         loader: Int64, dirFd: Int64,
                         packageJson: ?Any, cloneFilePath: Bool): SysMaybe<Unit> {
        mutex.lock()
        defer {
            mutex.unlock()
        }

        // 如果已经监视, 直接返回成功
        // 严格翻译自: Watcher.zig:735-746
        if (let Some(index) = indexOf(hash)) {
            return SysMaybe<Unit>.Ok(())
        }

        return appendFileMaybeLock(fd, filePath, hash, loader, dirFd,
                                    packageJson, cloneFilePath, false)
    }

    /// 添加文件 (可能加锁) - 对应 Bun Watcher.appendFileMaybeLock
    /// 严格翻译自: Watcher.zig:539-610
    ///   pub fn appendFileMaybeLock(this: *Watcher, fd, file_path, hash,
    ///                              loader, dir_fd, package_json,
    ///                              clone_file_path, lock) bun.sys.Maybe(void)
    private func appendFileMaybeLock(fd: Int64, filePath: String, hash: HashType,
                                      loader: Int64, dirFd: Int64,
                                      packageJson: ?Any, cloneFilePath: Bool,
                                      lock: Bool): SysMaybe<Unit> {
        if (lock) {
            mutex.lock()
        }
        defer {
            if (lock) {
                mutex.unlock()
            }
        }

        // 路径必须非空
        if (filePath.size <= 1) {
            return SysMaybe<Unit>.Ok(())
        }

        // 计算父目录哈希
        // 严格翻译自: Watcher.zig:553-555
        //   const pathname = bun.fs.PathName.init(file_path);
        //   const parent_dir = pathname.dirWithTrailingSlash();
        //   const parent_dir_hash: HashType = getHash(parent_dir);
        let parentDir = parentDirectory(filePath)
        let parentDirHash = getHash(parentDir)

        // 确保监视列表有足够容量
        // 严格翻译自: Watcher.zig:577
        //   bun.handleOom(this.watchlist.ensureUnusedCapacity(this.allocator, 1 + ...))
        watchlist.ensureUnusedCapacity(2)

        // 追加文件 - 对应 appendFileAssumeCapacity
        return appendFileAssumeCapacity(fd, filePath, hash, loader,
                                         parentDirHash, packageJson, cloneFilePath)
    }

    /// 追加文件 (假设有足够容量) - 对应 Bun Watcher.appendFileAssumeCapacity
    /// 严格翻译自: Watcher.zig:377-431
    ///   fn appendFileAssumeCapacity(this: *Watcher, fd, file_path, hash,
    ///                               loader, parent_hash, package_json,
    ///                               clone_file_path) bun.sys.Maybe(void)
    private func appendFileAssumeCapacity(fd: Int64, filePath: String, hash: HashType,
                                           loader: Int64, parentHash: HashType,
                                           packageJson: ?Any,
                                           cloneFilePath: Bool): SysMaybe<Unit> {
        let watchlistId = watchlist.size

        // 平台特定注册
        // 严格翻译自: Watcher.zig:416-427
        //   if (comptime Environment.isLinux) {
        //       const slice: [:0]const u8 = buf[0..file_path_.len :0];
        //       item.eventlist_index = switch (this.platform.watchPath(slice)) { ... };
        //   }
        var eventlistIndex: Int32 = Int32(0)
        if (let Some(p) = platform) {
            match (p.watchPath(filePath)) {
                case Ok(wd) => eventlistIndex = wd
                case Err(err) => return SysMaybe<Unit>.Err(err)
            }
        }

        let item = WatchItem(
            filePath: filePath,
            hash: hash,
            loader: loader,
            fd: fd,
            count: UInt32(0),
            parentHash: parentHash,
            kind: WatchItemKind.File,
            packageJson: packageJson,
            eventlistIndex: eventlistIndex
        )

        watchlist.appendAssumeCapacity(item)
        return SysMaybe<Unit>.Ok(())
    }

    /// 添加目录 - 对应 Bun Watcher.addDirectory
    /// 严格翻译自: Watcher.zig:629-646
    ///   pub fn addDirectory(this: *Watcher, fd, file_path, hash,
    ///                       clone_file_path) bun.sys.Maybe(WatchItemIndex) {
    ///       this.mutex.lock();
    ///       defer this.mutex.unlock();
    ///       if (this.indexOf(hash)) |idx| { return .{ .result = @truncate(idx) }; }
    ///       bun.handleOom(this.watchlist.ensureUnusedCapacity(this.allocator, 1));
    ///       return this.appendDirectoryAssumeCapacity(fd, file_path, hash, clone_file_path);
    ///   }
    public func addDirectory(fd: Int64, filePath: String, hash: HashType,
                              cloneFilePath: Bool): SysMaybe<WatchItemIndex> {
        mutex.lock()
        defer {
            mutex.unlock()
        }

        // 如果已存在, 返回索引
        if (let Some(idx) = indexOf(hash)) {
            return SysMaybe<WatchItemIndex>.Ok(UInt16(Int64(idx)))
        }

        watchlist.ensureUnusedCapacity(1)
        return appendDirectoryAssumeCapacity(fd, filePath, hash, cloneFilePath)
    }

    /// 追加目录 (假设有足够容量) - 对应 Bun Watcher.appendDirectoryAssumeCapacity
    /// 严格翻译自: Watcher.zig:432-535
    private func appendDirectoryAssumeCapacity(fd: Int64, filePath: String,
                                                hash: HashType,
                                                cloneFilePath: Bool): SysMaybe<WatchItemIndex> {
        var effectiveFd = fd
        // 如果 fd 无效, 尝试打开
        // 严格翻译自: Watcher.zig:448-454
        //   const fd = brk: {
        //       if (stored_fd.isValid()) break :brk stored_fd;
        //       break :brk switch (bun.sys.openA(file_path, 0, 0)) { ... };
        //   };
        if (!FdUtils.isValid(fd)) {
            match (SysFs.open(filePath, OpenFlags.RDONLY)) {
                case Ok(openedFd) => effectiveFd = openedFd
                case Err(err) => return SysMaybe<WatchItemIndex>.Err(err)
            }
        }

        let parentHash = getHash(parentDirectory(filePath))
        let watchlistId = watchlist.size

        // 平台特定注册 - inotify watchDir
        // 严格翻译自: Watcher.zig:511-529
        var eventlistIndex: Int32 = Int32(0)
        if (let Some(p) = platform) {
            match (p.watchDir(filePath)) {
                case Ok(wd) => eventlistIndex = wd
                case Err(err) => return SysMaybe<WatchItemIndex>.Err(
                    err.withPath(filePath))
            }
        }

        let item = WatchItem(
            filePath: filePath,
            hash: hash,
            loader: 0,  // options.Loader.file
            fd: effectiveFd,
            count: UInt32(0),
            parentHash: parentHash,
            kind: WatchItemKind.Directory,
            packageJson: None,
            eventlistIndex: eventlistIndex
        )

        watchlist.appendAssumeCapacity(item)
        let resultIndex = UInt16(Int64(watchlist.size - 1))
        return SysMaybe<WatchItemIndex>.Ok(resultIndex)
    }

    /// 慢路径添加文件 (通过路径) - 对应 Bun Watcher.addFileByPathSlow
    /// 严格翻译自: Watcher.zig:659-719
    ///   pub fn addFileByPathSlow(this: *Watcher, file_path: string,
    ///                            loader: options.Loader) bool
    public func addFileByPathSlow(filePath: String, loader: Int64): Bool {
        if (filePath.size == 0) {
            return false
        }
        let hash = getHash(filePath)

        // 检查是否已监视 (加锁避免竞争)
        // 严格翻译自: Watcher.zig:668-676
        mutex.lock()
        let alreadyWatched = indexOf(hash) != None
        mutex.unlock()
        if (alreadyWatched) {
            return true
        }

        let res = addFile(INVALID_FD, filePath, hash, loader,
                           INVALID_FD, None, true)
        match (res) {
            case Ok(_) => return true
            case Err(_) => return false
        }
    }

    /// 按哈希移除监视 - 对应 Bun Watcher.remove(hash)
    /// 严格翻译自: Watcher.zig:758-764
    ///   pub fn remove(this: *Watcher, hash: HashType) void {
    ///       this.mutex.lock();
    ///       defer this.mutex.unlock();
    ///       if (this.indexOf(hash)) |index| {
    ///           this.removeAtIndex(@truncate(index), hash, &[_]HashType{}, .file);
    ///       }
    ///   }
    public func remove(hash: HashType): Unit {
        mutex.lock()
        defer {
            mutex.unlock()
        }
        if (let Some(index) = indexOf(hash)) {
            removeAtIndex(UInt16(Int64(index)), hash, [], WatchItemKind.File)
        }
    }

    /// 按索引移除 - 对应 Bun Watcher.removeAtIndex
    /// 严格翻译自: Watcher.zig:766-780
    ///   pub fn removeAtIndex(this: *Watcher, index: WatchItemIndex, hash: HashType,
    ///                        parents: []HashType, comptime kind: WatchItem.Kind) void {
    ///       bun.assert(index != no_watch_item);
    ///       this.evict_list[this.evict_list_i] = index;
    ///       this.evict_list_i += 1;
    ///       if (comptime kind == .directory) { ... }
    ///   }
    public func removeAtIndex(index: WatchItemIndex, hash: HashType,
                               parents: Array<HashType>, kind: WatchItemKind): Unit {
        if (index == NO_WATCH_ITEM) {
            return
        }

        evictList[Int64(evictListI)] = index
        evictListI = UInt16(Int64(evictListI) + 1)

        // 目录类型: 同时驱逐匹配的父项
        // 严格翻译自: Watcher.zig:772-779
        if (kind == WatchItemKind.Directory) {
            for (parent in parents) {
                if (parent == hash) {
                    evictList[Int64(evictListI)] = UInt16(Int64(parent))
                    evictListI = UInt16(Int64(evictListI) + 1)
                }
            }
        }
    }

    /// 刷新驱逐列表 - 对应 Bun Watcher.flushEvictions
    /// 严格翻译自: Watcher.zig:264-318
    ///   pub fn flushEvictions(this: *Watcher) void {
    ///       if (this.evict_list_i == 0) return;
    ///       defer this.evict_list_i = 0;
    ///       // 按降序排序 (最大索引先处理, 避免 swapRemove 错乱)
    ///       std.sort.insertion(WatchItemIndex, this.evict_list[0..this.evict_list_i], ...);
    ///       // 第一遍: 关闭文件描述符
    ///       // 第二遍: swapRemove + 修复 kqueue udata
    ///   }
    public func flushEvictions(): Unit {
        if (evictListI == UInt16(0)) {
            return
        }
        defer {
            evictListI = UInt16(0)
        }

        let count = Int64(evictListI)

        // 按降序排序 - 对应 std.sort.insertion(desc)
        // 严格翻译自: Watcher.zig:271-275
        var indices = ArrayList<WatchItemIndex>()
        for (i in 0..count) {
            indices.append(evictList[i])
        }
        // 降序排序 (冒泡排序近似 insertion sort)
        for (i in 0..indices.size) {
            for (j in (i + 1)..<indices.size) {
                if (indices[Int64(i)] < indices[Int64(j)]) {
                    let tmp = indices[Int64(i)]
                    indices[Int64(i)] = indices[Int64(j)]
                    indices[Int64(j)] = tmp
                }
            }
        }

        // 第一遍: 关闭文件描述符
        // 严格翻译自: Watcher.zig:278-296
        var lastItem: WatchItemIndex = NO_WATCH_ITEM
        for (i in 0..indices.size) {
            let item = indices[i]
            // 去重
            if (item == lastItem) {
                continue
            }
            // 越界检查
            if (Int64(item) >= watchlist.size) {
                continue
            }
            // 关闭 fd
            if (let Some(wi) = watchlist.get(Int64(item))) {
                if (FdUtils.isValid(wi.fd)) {
                    SysFs.close(wi.fd)
                }
            }
            lastItem = item
        }

        // 第二遍: swapRemove
        // 严格翻译自: Watcher.zig:299-318
        lastItem = NO_WATCH_ITEM
        for (i in 0..indices.size) {
            let item = indices[i]
            if (item == lastItem || Int64(item) >= watchlist.size) {
                continue
            }
            watchlist.swapRemove(Int64(item))
            lastItem = item
        }
    }

    // ========================================================================
    // 回调调用 - 内部使用
    // ========================================================================

    /// 写入追踪事件 - 对应 Bun Watcher.writeTraceEvents
    /// 严格翻译自: Watcher.zig:110-112
    ///   pub fn writeTraceEvents(this: *Watcher, events: []WatchEvent,
    ///                           changed_files: []?[:0]u8) void {
    ///       WatcherTrace.writeEvents(this, events, changed_files);
    ///   }
    public func writeTraceEvents(events: Array<WatcherEvent>,
                                  changedFiles: Array<?String>): Unit {
        WatcherTrace.instance.writeEvents(this, events, changedFiles)
    }

    /// 触发文件变更回调 - 内部使用
    /// 严格翻译自: Watcher.zig 中 onFileUpdate 调用点
    ///   this.onFileUpdate(this.ctx, watchevents, this.changed_filepaths[0..watchevents.len], this.watchlist);
    public func fireFileUpdate(events: Array<WatcherEvent>,
                                changedFiles: Array<?String>): Unit {
        onFileUpdateFn(ctx, events, changedFiles, watchlist)
    }

    /// 触发错误回调 - 内部使用
    public func fireError(err: SysError): Unit {
        onErrorFn(ctx, err)
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 获取监视列表的引用 (用于 INotifyWatcher)
    public func getWatchlist(): WatchList {
        return watchlist
    }

    /// 获取事件缓冲区
    public func getWatchEvents(): Array<WatcherEvent> {
        return watchEvents
    }

    /// 设置事件缓冲区中的元素
    public func setWatchEvent(index: Int64, event: WatcherEvent): Unit {
        if (index >= 0 && index < watchEvents.size) {
            watchEvents[index] = event
        }
    }

    /// 获取变更路径缓冲区
    public func getChangedFilepaths(): Array<?String> {
        return changedFilepaths
    }

    /// 设置变更路径
    public func setChangedFilepath(index: Int64, path: ?String): Unit {
        if (index >= 0 && index < changedFilepaths.size) {
            changedFilepaths[index] = path
        }
    }

    /// 是否运行中
    public func isRunning(): Bool {
        return running
    }

    /// 获取互斥锁
    public func getMutex(): Mutex {
        return mutex
    }

    /// 获取平台实现
    public func getPlatform(): ?PlatformWatcher {
        return platform
    }

    /// 判断目录是否可监视 - 对应 Bun Watcher.isEligibleDirectory
    /// 严格翻译自: Watcher.zig:612-614
    ///   inline fn isEligibleDirectory(this: *Watcher, dir: string) bool {
    ///       return strings.contains(dir, this.fs.top_level_dir) and
    ///              !strings.contains(dir, "node_modules");
    ///   }
    public func isEligibleDirectory(dir: String): Bool {
        return dir.contains(topLevelDir) && !dir.contains("node_modules")
    }

    /// 路径可能监视目录回调 - 对应 Bun Watcher.onMaybeWatchDirectory
    /// 严格翻译自: Watcher.zig:786-793
    ///   pub fn onMaybeWatchDirectory(watch: *Watcher, file_path: string, dir_fd: bun.FD) void {
    ///       if (std.mem.indexOf(u8, file_path, "node_modules") == null and
    ///           std.mem.indexOf(u8, file_path, watch.fs.top_level_dir) != null) {
    ///           _ = watch.addDirectory(dir_fd, file_path, getHash(file_path), false);
    ///       }
    ///   }
    public func onMaybeWatchDirectory(filePath: String, dirFd: Int64): Unit {
        if (!filePath.contains("node_modules") && filePath.contains(topLevelDir)) {
            addDirectory(dirFd, filePath, getHash(filePath), false)
        }
    }

    /// 提取父目录路径 (带尾斜杠)
    /// 对应 Bun bun.fs.PathName.init(file_path).dirWithTrailingSlash()
    private func parentDirectory(filePath: String): String {
        let lastSlash = filePath.lastIndexOf('/')
        if (lastSlash < 0) {
            return "./"
        }
        return filePath.substring(0, lastSlash + 1)
    }

    /// 获取当前线程 ID (简化实现)
    private func currentThreadId(): Int64 {
        // 仓颉暂无直接获取线程 ID 的 API, 使用简化值
        return Int64(std.time.DateTime.now().getYear())
    }

    /// 启动线程 (简化实现)
    private func spawnThread(fn: () -> Unit): Unit {
        // 仓颉使用 Thread 创建线程
        // 此处为类型签名兼容, 实际运行时需要仓颉并发支持
        fn()
    }
}

// ============================================================================
// PlatformWatcher - 平台特定监视器接口
// 对应 Bun 中通过 comptime switch 选择的平台实现
// 严格翻译自: Watcher.zig:147-152
//   const Platform = switch (Environment.os) {
//       .linux => @import("./INotifyWatcher.zig"),
//       .mac, .freebsd => @import("./KEventWatcher.zig"),
//       .windows => WindowsWatcher,
//   };
// ============================================================================

/// 平台监视器接口 - 对应 Bun 的 comptime Platform 选择
///
/// Bun 在 Linux 上使用 INotifyWatcher, macOS 上使用 KEventWatcher
/// 仓颉通过接口抽象实现跨平台
public interface PlatformWatcher {
    /// 初始化 - 对应 INotifyWatcher.init / KEventWatcher.init
    func initFunc(topLevelDir: String): SysMaybe<Unit>

    /// 监视文件路径 - 对应 INotifyWatcher.watchPath
    /// 返回平台特定的 watch descriptor
    func watchPath(pathname: String): SysMaybe<Int32>

    /// 监视目录 - 对应 INotifyWatcher.watchDir
    func watchDir(pathname: String): SysMaybe<Int32>

    /// 取消监视 - 对应 INotifyWatcher.unwatch
    func unwatch(wd: Int32): Unit

    /// 读取事件 - 对应 INotifyWatcher.read
    func readEvents(): SysMaybe<Array<InotifyEvent>>

    /// 停止 - 对应 INotifyWatcher.stop / KEventWatcher.stop
    func stop(): Unit

    /// 监视循环周期 - 对应 INotifyWatcher.watchLoopCycle / KEventWatcher.watchLoopCycle
    func watchLoopCycle(watcher: Watcher): SysMaybe<Unit>
}
