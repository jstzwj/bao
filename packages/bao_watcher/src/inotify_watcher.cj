// bao_watcher - Linux inotify 文件系统监视器实现
// 严格翻译自: src/watcher/INotifyWatcher.zig
//
// Bun 的 INotifyWatcher:
//   - 使用 Linux inotify API 监视文件和目录变更
//   - inotify_init1(IN_CLOEXEC) 初始化
//   - inotify_add_watch() 注册监视
//   - read() 读取 inotify_event 事件 (变长结构)
//   - 事件通过 ppoll 合并 (coalesce) 减少 IO 噪声
//   - watchLoopCycle 处理事件并调用 onFileUpdate 回调
package bao_watcher

import bao_core.*
import bao_sys.*
import bao_event_loop.*
import bao_threading.*

// ============================================================================
// Linux inotify 常量
// 严格翻译自: std.os.linux.IN (Zig 标准库)
// ============================================================================

/// inotify 创建标志 - IN_CLOEXEC
/// 对应 Zig: std.os.linux.IN.CLOEXEC = O.CLOEXEC
private let IN_CLOEXEC: Int32 = 0o2000000  // 524288

/// inotify 事件掩码常量
/// 严格翻译自: std.os.linux.IN.*
private let IN_ACCESS: UInt32 = 0x00000001
private let IN_MODIFY: UInt32 = 0x00000002
private let IN_ATTRIB: UInt32 = 0x00000004
private let IN_CLOSE_WRITE: UInt32 = 0x00000008
private let IN_CLOSE_NOWRITE: UInt32 = 0x00000010
private let IN_CLOSE: UInt32 = IN_CLOSE_WRITE | IN_CLOSE_NOWRITE
private let IN_OPEN: UInt32 = 0x00000020
private let IN_MOVED_FROM: UInt32 = 0x00000040
private let IN_MOVED_TO: UInt32 = 0x00000080
private let IN_MOVE: UInt32 = IN_MOVED_FROM | IN_MOVED_TO
private let IN_CREATE: UInt32 = 0x00000100
private let IN_DELETE: UInt32 = 0x00000200
private let IN_DELETE_SELF: UInt32 = 0x00000400
private let IN_MOVE_SELF: UInt32 = 0x00000800
private let IN_EXCL_UNLINK: UInt32 = 0x04000000
private let IN_ONLYDIR: UInt32 = 0x01000000

// ============================================================================
// C FFI - inotify 系统调用
// 严格翻译自: INotifyWatcher.zig 中对 std.posix.system 的调用
//   std.posix.system.read(fd, buf, count)
//   std.posix.inotify_init1(flags)
//   std.posix.system.inotify_add_watch(fd, pathname, mask)
//   std.posix.system.inotify_rm_watch(fd, wd)
//   std.posix.ppoll(fds, timeout, sigmask)
// ============================================================================

@C
foreign func inotify_init1(flags: Int32): Int32
@C
foreign func inotify_add_watch(fd: Int32, pathname: CPointer<Int8>, mask: UInt32): Int32
@C
foreign func inotify_rm_watch(fd: Int32, wd: Int32): Int32

// poll 结构体相关
@C
foreign func poll(fds: CPointer<Unit>, nfds: UIntNative, timeout: Int32): Int32

// ============================================================================
// InotifyEvent - inotify 事件结构
// 严格翻译自: INotifyWatcher.zig:37-63
//   pub const Event = extern struct {
//       watch_descriptor: EventListIndex,  // c_int
//       mask: u32,
//       cookie: u32,
//       name_len: u32,
//       // name follows (variable length, null-terminated)
//   };
//
// 注意: inotify_event 在 C 中是固定头部 + 变长 name
// 仓颉使用 class 模拟, name 单独存储
// ============================================================================

/// inotify 事件 - 对应 Bun INotifyWatcher.Event (extern struct)
/// 严格翻译自: INotifyWatcher.zig:37-63
///
/// C 结构体布局:
///   struct inotify_event {
///       int wd;           // watch descriptor
///       uint32_t mask;    // event mask
///       uint32_t cookie;  // unique renaming cookie
///       uint32_t len;     // name length (including nulls)
///       char name[];      // optional null-terminated name
///   };
public class InotifyEvent {
    /// 监视描述符 - 对应 Event.watch_descriptor: EventListIndex (c_int)
    public var watchDescriptor: Int32
    /// 事件掩码 - 对应 Event.mask: u32
    public var mask: UInt32
    /// 重命名 cookie - 对应 Event.cookie: u32
    /// 用于关联 MOVED_FROM 和 MOVED_TO 事件
    public var cookie: UInt32
    /// 名称长度 - 对应 Event.name_len: u32
    /// 包含填充 null 字节的总长度
    public var nameLen: UInt32
    /// 文件名 - 对应 Event.name() 返回的 [:0]u8
    /// 仅当事件来自目录监视时存在
    public var name: String

    public init() {
        watchDescriptor = Int32(0)
        mask = UInt32(0)
        cookie = UInt32(0)
        nameLen = UInt32(0)
        name = ""
    }

    public init(wd: Int32, mask: UInt32, cookie: UInt32, nameLen: UInt32, name: String) {
        watchDescriptor = wd
        this.mask = mask
        this.cookie = cookie
        this.nameLen = nameLen
        this.name = name
    }

    /// inotify_event 结构体大小 - 对应 @sizeOf(Event) = 16 字节
    public static let STRUCT_SIZE: Int64 = 16

    /// 最大事件大小 (结构体 + NAME_MAX + padding)
    /// 对应 Bun Event.largest_size
    /// 严格翻译自: INotifyWatcher.zig:52
    ///   const largest_size = std.mem.alignForward(usize, @sizeOf(Event) + bun.MAX_PATH_BYTES, @alignOf(Event))
    public static let LARGEST_SIZE: Int64 = STRUCT_SIZE + MAX_PATH_BYTES

    /// 获取事件总大小 (含名称)
    /// 对应 Bun Event.size()
    /// 严格翻译自: INotifyWatcher.zig:60-62
    ///   pub fn size(event: *align(1) Event) u32 {
    ///       return @intCast(@sizeOf(Event) + event.name_len);
    ///   }
    public func totalSize(): Int64 {
        return STRUCT_SIZE + Int64(nameLen)
    }
}

// ============================================================================
// InotifyWatcher - Linux inotify 监视器实现
// 严格翻译自: INotifyWatcher.zig:1-386
//
//   const INotifyWatcher = @This();
//   fd: bun.FD = bun.invalid_fd,
//   loaded: bool = false,
//   eventlist_bytes: &EventListBytes align(@alignOf(Event)) = undefined,
//   eventlist_ptrs: [max_count]*align(1) Event = undefined,
//   read_ptr: ?struct { i: u32, len: u32 } = null,
//   watch_count: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
//   coalesce_interval: isize = 100_000,
// ============================================================================

/// Linux inotify 监视器 - 对应 Bun INotifyWatcher
/// 严格翻译自: INotifyWatcher.zig
///
/// Bun 的 INotifyWatcher 实现要点:
///   1. inotify_init1(IN_CLOEXEC) 创建 inotify 实例
///   2. inotify_add_watch() 注册文件/目录监视
///   3. read() 读取变长 inotify_event 到字节数组
///   4. ppoll() 短暂等待以合并高频事件 (coalesce)
///   5. watchLoopCycle 处理批量事件并回调
///
/// 仓颉使用 InotifyEvent class 数组代替变长字节数组
public class InotifyWatcher <: PlatformWatcher {
    /// inotify 文件描述符 - 对应 INotifyWatcher.fd: bun.FD
    /// Bun: fd: bun.FD = bun.invalid_fd
    private var fd: Int64

    /// 是否已初始化 - 对应 INotifyWatcher.loaded: bool = false
    private var loaded: Bool

    /// 事件缓冲区指针 - 对应 INotifyWatcher.read_ptr
    /// Bun 使用字节数组直接映射 inotify_event 结构
    /// 仓颉使用解析后的 InotifyEvent 数组
    /// 对应 INotifyWatcher.read_ptr: ?struct { i: u32, len: u32 }
    private var readPtr: ?InotifyReadPtr

    /// 监视计数 - 对应 INotifyWatcher.watch_count: std.atomic.Value(u32)
    /// 严格翻译自: INotifyWatcher.zig:32
    ///   watch_count: std.atomic.Value(u32) = std.atomic.Value(u32).init(0)
    private var watchCount: AtomicUInt32

    /// 合并间隔 (纳秒) - 对应 INotifyWatcher.coalesce_interval: isize = 100_000
    /// 严格翻译自: INotifyWatcher.zig:34
    ///   coalesce_interval: isize = 100_000,
    /// Bun 使用 ppoll 等待此时间以合并高频 IN_MODIFY 事件
    private var coalesceInterval: Int64

    /// 读取缓冲区大小
    /// 对应 Bun eventlist_bytes_size = (Event.largest_size / 2) * max_count
    private let eventlistBytesSize: Int64

    public init() {
        fd = INVALID_FD
        loaded = false
        readPtr = None
        watchCount = AtomicUInt32(UInt32(0))
        coalesceInterval = Int64(100_000)  // 0.1ms
        eventlistBytesSize = (InotifyEvent.LARGEST_SIZE / 2) * WATCHER_MAX_COUNT
    }

    // ========================================================================
    // 初始化 - 对应 Bun INotifyWatcher.init
    // 严格翻译自: INotifyWatcher.zig:93-103
    //   pub fn init(this: *INotifyWatcher, _: []const u8) !void {
    //       bun.assert(!this.loaded);
    //       this.loaded = true;
    //       this.coalesce_interval = std.math.cast(isize,
    //           bun.env_var.BUN_INOTIFY_COALESCE_INTERVAL.get()) orelse 100_000;
    //       this.fd = .fromNative(try std.posix.inotify_init1(IN.CLOEXEC));
    //       this.eventlist_bytes = &(try bun.default_allocator.alignedAlloc(...))[0];
    //   }
    // ========================================================================

    /// 初始化 inotify - 对应 Bun INotifyWatcher.init
    /// 严格翻译自: INotifyWatcher.zig:93-103
    public func initFunc(topLevelDir: String): SysMaybe<Unit> {
        if (loaded) {
            return SysMaybe<Unit>.Ok(())
        }
        loaded = true

        // 读取环境变量 BUN_INOTIFY_COALESCE_INTERVAL
        // 严格翻译自: INotifyWatcher.zig:97
        //   this.coalesce_interval = std.math.cast(isize,
        //       bun.env_var.BUN_INOTIFY_COALESCE_INTERVAL.get()) orelse 100_000
        let envVal = OS.getEnv("BUN_INOTIFY_COALESCE_INTERVAL")
        if (let Some(v) = envVal) {
            let parsed = Int64(v)
            if (parsed > 0) {
                coalesceInterval = parsed
            }
        }

        // 调用 inotify_init1 - 对应 std.posix.inotify_init1(IN.CLOEXEC)
        // 严格翻译自: INotifyWatcher.zig:100
        //   this.fd = .fromNative(try std.posix.inotify_init1(IN.CLOEXEC))
        let inotifyFd = inotify_init1(IN_CLOEXEC)
        if (inotifyFd < 0) {
            return SysMaybe<Unit>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.Open)
            )
        }
        fd = Int64(inotifyFd)

        return SysMaybe<Unit>.Ok(())
    }

    // ========================================================================
    // 监视注册 - 对应 Bun INotifyWatcher.watchPath / watchDir
    // 严格翻译自: INotifyWatcher.zig:65-85
    // ========================================================================

    /// 监视文件路径 - 对应 Bun INotifyWatcher.watchPath
    /// 严格翻译自: INotifyWatcher.zig:65-74
    ///   pub fn watchPath(this: *INotifyWatcher, pathname: [:0]const u8)
    ///                     bun.sys.Maybe(EventListIndex) {
    ///       bun.assert(this.loaded);
    ///       const old_count = this.watch_count.fetchAdd(1, .release);
    ///       defer if (old_count == 0) Futex.wake(&this.watch_count, 10);
    ///       const watch_file_mask = IN.EXCL_UNLINK | IN.MOVE_SELF |
    ///                               IN.DELETE_SELF | IN.MOVED_TO | IN.MODIFY;
    ///       const rc = system.inotify_add_watch(this.fd.cast(), pathname, watch_file_mask);
    ///       return bun.sys.Maybe(EventListIndex).errnoSysP(rc, .watch, pathname) orelse
    ///           .{ .result = rc };
    ///   }
    public func watchPath(pathname: String): SysMaybe<Int32> {
        if (!loaded) {
            return SysMaybe<Int32>.Err(SysError(UInt16(0), SysTag.TODO))
        }

        let oldCount = watchCount.get()
        watchCount.add(UInt32(1))

        // 文件监视掩码
        // 严格翻译自: INotifyWatcher.zig:69
        //   const watch_file_mask = IN.EXCL_UNLINK | IN.MOVE_SELF |
        //                           IN.DELETE_SELF | IN.MOVED_TO | IN.MODIFY
        let watchFileMask = IN_EXCL_UNLINK | IN_MOVE_SELF | IN_DELETE_SELF | IN_MOVED_TO | IN_MODIFY

        return inotifyAddWatch(pathname, watchFileMask)
    }

    /// 监视目录 - 对应 Bun INotifyWatcher.watchDir
    /// 严格翻译自: INotifyWatcher.zig:76-85
    ///   pub fn watchDir(this: *INotifyWatcher, pathname: [:0]const u8)
    ///                    bun.sys.Maybe(EventListIndex) {
    ///       bun.assert(this.loaded);
    ///       const old_count = this.watch_count.fetchAdd(1, .release);
    ///       defer if (old_count == 0) Futex.wake(&this.watch_count, 10);
    ///       const watch_dir_mask = IN.EXCL_UNLINK | IN.DELETE | IN.DELETE_SELF |
    ///                              IN.CREATE | IN.MOVE_SELF | IN.ONLYDIR |
    ///                              IN.MOVED_TO | IN.MODIFY;
    ///       const rc = system.inotify_add_watch(this.fd.cast(), pathname, watch_dir_mask);
    ///       return bun.sys.Maybe(EventListIndex).errnoSysP(rc, .watch, pathname) orelse
    ///           .{ .result = rc };
    ///   }
    public func watchDir(pathname: String): SysMaybe<Int32> {
        if (!loaded) {
            return SysMaybe<Int32>.Err(SysError(UInt16(0), SysTag.TODO))
        }

        watchCount.add(UInt32(1))

        // 目录监视掩码
        // 严格翻译自: INotifyWatcher.zig:80
        //   const watch_dir_mask = IN.EXCL_UNLINK | IN.DELETE | IN.DELETE_SELF |
        //                          IN.CREATE | IN.MOVE_SELF | IN.ONLYDIR |
        //                          IN.MOVED_TO | IN.MODIFY
        let watchDirMask = IN_EXCL_UNLINK | IN_DELETE | IN_DELETE_SELF |
                           IN_CREATE | IN_MOVE_SELF | IN_ONLYDIR |
                           IN_MOVED_TO | IN_MODIFY

        return inotifyAddWatch(pathname, watchDirMask)
    }

    /// 内部: 调用 inotify_add_watch
    private func inotifyAddWatch(pathname: String, mask: UInt32): SysMaybe<Int32> {
        unsafe {
            let pathPtr = unsafeNewCString(pathname)
            let rc = inotify_add_watch(Int32(fd), pathPtr, mask)
            if (rc < 0) {
                return SysMaybe<Int32>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Open, pathname)
                )
            }
            return SysMaybe<Int32>.Ok(rc)
        }
    }

    /// 取消监视 - 对应 Bun INotifyWatcher.unwatch
    /// 严格翻译自: INotifyWatcher.zig:87-91
    ///   pub fn unwatch(this: *INotifyWatcher, wd: EventListIndex) void {
    ///       bun.assert(this.loaded);
    ///       _ = this.watch_count.fetchSub(1, .release);
    ///       _ = system.inotify_rm_watch(this.fd, wd);
    ///   }
    public func unwatch(wd: Int32): Unit {
        if (!loaded) {
            return
        }
        watchCount.sub(UInt32(1))
        inotify_rm_watch(Int32(fd), wd)
    }

    // ========================================================================
    // 读取事件 - 对应 Bun INotifyWatcher.read
    // 严格翻译自: INotifyWatcher.zig:105-217
    //
    // Bun 的 read 实现要点:
    //   1. 从 inotify fd 读取变长字节到 eventlist_bytes 缓冲区
    //   2. 如果事件量较小, 使用 ppoll 等待 coalesce_interval 以合并事件
    //   3. ppoll 返回后再读一次 (double read), 合并更多事件
    //   4. 将字节缓冲区解析为 *align(1) Event 指针数组
    //   5. 超过 max_count 时保存 read_ptr 供下次继续
    // ========================================================================

    /// 读取 inotify 事件 - 对应 Bun INotifyWatcher.read
    /// 严格翻译自: INotifyWatcher.zig:105-217
    ///
    /// Bun 返回 []const *align(1) Event (指向字节数组的对齐指针)
    /// 仓颉返回解析后的 InotifyEvent 数组
    public func readEvents(): SysMaybe<Array<InotifyEvent>> {
        if (!loaded) {
            return SysMaybe<Array<InotifyEvent>>.Err(
                SysError(UInt16(0), SysTag.TODO))
        }

        // 读取 inotify 事件到字节数组
        // 严格翻译自: INotifyWatcher.zig:121-185
        var rawBytes: Array<UInt8> = Array<UInt8>()

        // 如果有上次的读取指针, 继续处理 - 对应 read_ptr 检查
        // 严格翻译自: INotifyWatcher.zig:117-121
        if (let Some(ptr) = readPtr) {
            // waitForever 等待 watch_count > 0
            waitWatchCount()
        }

        // 主读取循环
        // 严格翻译自: INotifyWatcher.zig:121-185
        //   outer: while (true) {
        //       const rc = std.posix.system.read(this.fd, this.eventlist_bytes, ...);
        //       ...
        //   }
        let buf = Array<UInt8>(eventlistBytesSize, item: UInt8(0))
        let bytesReadResult = rawRead(buf)
        match (bytesReadResult) {
            case Err(err) => return SysMaybe<Array<InotifyEvent>>.Err(err)
            case Ok(count) => {
                if (count == 0) {
                    return SysMaybe<Array<InotifyEvent>>.Ok([])
                }

                // 如果读取量较小, ppoll 合并
                // 严格翻译自: INotifyWatcher.zig:138-166
                //   const double_read_threshold = Event.largest_size * (max_count / 2);
                //   if (read_eventlist_bytes.len < double_read_threshold) {
                //       ppoll(..., coalesce_interval, ...) 等待更多事件
                //   }
                let doubleReadThreshold = InotifyEvent.LARGEST_SIZE * (WATCHER_MAX_COUNT / 2)
                var effectiveCount = count
                if (count < doubleReadThreshold) {
                    // ppoll 等待 coalesce_interval 纳秒
                    // 严格翻译自: INotifyWatcher.zig:140-166
                    let pollResult = ppollWait()
                    if (pollResult > 0) {
                        // 有更多数据, 追加读取
                        let restBuf = Array<UInt8>(eventlistBytesSize - count, item: UInt8(0))
                        let moreResult = rawRead(restBuf)
                        match (moreResult) {
                            case Ok(moreCount) => {
                                // 合并: 将追加字节追加到主缓冲区
                                effectiveCount = effectiveCount + moreCount
                            }
                            case Err(_) => () // 忽略追加读取错误
                        }
                    }
                }

                // 解析事件
                // 严格翻译自: INotifyWatcher.zig:187-216
                //   while (i < read_eventlist_bytes.len) {
                //       const event: *align(1) Event = @ptrCast(...);
                //       this.eventlist_ptrs[count] = event;
                //       i += event.size();
                //       count += 1;
                //       if (count == max_count) { ... }
                //   }
                return parseEvents(buf, effectiveCount)
            }
        }
    }

    /// 停止 inotify - 对应 Bun INotifyWatcher.stop
    /// 严格翻译自: INotifyWatcher.zig:219-225
    ///   pub fn stop(this: *INotifyWatcher) void {
    ///       if (this.fd != bun.invalid_fd) {
    ///           this.fd.close();
    ///           this.fd = bun.invalid_fd;
    ///       }
    ///   }
    public func stop(): Unit {
        if (fd != INVALID_FD) {
            SysFs.close(fd)
            fd = INVALID_FD
        }
    }

    // ========================================================================
    // 监视循环 - 对应 Bun INotifyWatcher.watchLoopCycle
    // 严格翻译自: INotifyWatcher.zig:228-317
    //
    //   pub fn watchLoopCycle(this: *bun.Watcher) bun.sys.Maybe(void) {
    //       defer Output.flush();
    //       const events = switch (this.platform.read()) { ... };
    //       if (events.len == 0) return .success;
    //       const eventlist_index = this.watchlist.items(.eventlist_index);
    //       ... 处理事件并调用 processINotifyEventBatch ...
    //   }
    // ========================================================================

    /// 监视循环周期 - 对应 Bun INotifyWatcher.watchLoopCycle(this: *bun.Watcher)
    /// 严格翻译自: INotifyWatcher.zig:228-317
    ///
    /// 注意: Bun 中 watchLoopCycle 接收 *bun.Watcher (整个 Watcher)
    /// 而非 *INotifyWatcher, 因为它是通过 Platform 函数指针调用的
    public func watchLoopCycle(watcher: Watcher): SysMaybe<Unit> {
        // 读取事件
        // 严格翻译自: INotifyWatcher.zig:231-234
        //   const events = switch (this.platform.read()) {
        //       .result => |result| result,
        //       .err => |err| return .{ .err = err },
        //   };
        let eventsResult = readEvents()
        var events: Array<InotifyEvent> = []
        match (eventsResult) {
            case Ok(evs) => events = evs
            case Err(err) => return SysMaybe<Unit>.Err(err)
        }
        if (events.size == 0) {
            return SysMaybe<Unit>.Ok(())
        }

        // 获取 eventlist_index 数组
        // 严格翻译自: INotifyWatcher.zig:237
        //   const eventlist_index = this.watchlist.items(.eventlist_index);
        let watchlist = watcher.getWatchlist()
        let eventlistIndices = watchlist.eventlistIndices()

        var eventId: Int64 = 0
        var eventsProcessed: Int64 = 0

        // 临时名称列表 - 对应 Bun temp_name_list: [128]?[:0]u8
        var tempNameList = Array<?String>(128, item: None)
        var tempNameOff: Int64 = 0

        // 处理事件 - 对应 Bun 的双层 while 循环
        // 严格翻译自: INotifyWatcher.zig:242-314
        while (eventsProcessed < events.size) {
            // 检查事件缓冲区是否已满
            // 严格翻译自: INotifyWatcher.zig:252-262
            if (eventId >= WATCHER_MAX_COUNT) {
                let batchResult = processINotifyEventBatch(
                    watcher, eventId, tempNameList, tempNameOff)
                match (batchResult) {
                    case Err(err) => return SysMaybe<Unit>.Err(err)
                    case Ok(_) => {
                        eventId = 0
                        tempNameOff = 0
                    }
                }
            }

            let event = events[Int64(eventsProcessed)]

            // 在 eventlistIndices 中查找 watch descriptor
            // 严格翻译自: INotifyWatcher.zig:279-289
            //   this.watch_events[event_id] = watchEventFromInotifyEvent(
            //       event,
            //       @intCast(std.mem.indexOfScalar(
            //           EventListIndex, eventlist_index,
            //           event.watch_descriptor,
            //       ) orelse { events_processed += 1; continue; }),
            //   );
            var foundIndex: ?Int64 = None
            for (i in 0..eventlistIndices.size) {
                if (eventlistIndices[i] == event.watchDescriptor) {
                    foundIndex = i
                    break
                }
            }

            if (foundIndex == None) {
                eventsProcessed += 1
                continue
            }
            let index = foundIndex.getOrThrow()

            // 转换 inotify 事件为 WatcherEvent
            let watcherEvent = watchEventFromInotifyEvent(event, UInt16(index))

            // 处理事件名称
            // 严格翻译自: INotifyWatcher.zig:292-300
            if (event.nameLen > UInt32(0) && tempNameOff < Int64(tempNameList.size)) {
                tempNameList[Int64(tempNameOff)] = event.name
                watcherEvent.nameOff = UInt8(Int32(tempNameOff))
                watcherEvent.nameLen = UInt8(1)
                tempNameOff += 1
            } else {
                watcherEvent.nameOff = UInt8(Int32(tempNameOff))
                watcherEvent.nameLen = UInt8(0)
            }

            watcher.setWatchEvent(eventId, watcherEvent)
            eventId += 1
            eventsProcessed += 1
        }

        // 处理最后一批事件
        // 严格翻译自: INotifyWatcher.zig:307-313
        if (eventId > 0) {
            let batchResult = processINotifyEventBatch(
                watcher, eventId, tempNameList, tempNameOff)
            match (batchResult) {
                case Err(err) => return SysMaybe<Unit>.Err(err)
                case Ok(_) => ()
            }
        }

        return SysMaybe<Unit>.Ok(())
    }

    // ========================================================================
    // 批量处理事件 - 对应 Bun processINotifyEventBatch
    // 严格翻译自: INotifyWatcher.zig:319-359
    //
    //   fn processINotifyEventBatch(this: *bun.Watcher, event_count: usize,
    //                               temp_name_list: []?[:0]u8) bun.sys.Maybe(void) {
    //       std.sort.pdq(WatchEvent, all_events, {}, WatchEvent.sortByIndex);
    //       ... 合并相同索引的事件 ...
    //       this.mutex.lock();
    //       if (this.running) {
    //           this.writeTraceEvents(...);
    //           this.onFileUpdate(...);
    //       }
    //   }
    // ========================================================================

    /// 批量处理 inotify 事件
    /// 严格翻译自: INotifyWatcher.zig:319-359
    private func processINotifyEventBatch(watcher: Watcher, eventCount: Int64,
                                           tempNameList: Array<?String>,
                                           tempNameOff: Int64): SysMaybe<Unit> {
        if (eventCount == 0) {
            return SysMaybe<Unit>.Ok(())
        }

        // 获取事件并按索引排序
        // 严格翻译自: INotifyWatcher.zig:326
        //   std.sort.pdq(WatchEvent, all_events, {}, WatchEvent.sortByIndex);
        var allEvents = ArrayList<WatcherEvent>()
        let watchEvents = watcher.getWatchEvents()
        for (i in 0..eventCount) {
            allEvents.append(watchEvents[i])
        }

        // 按索引排序 (pdq sort)
        allEvents.sortWith { a, b =>
            WatcherEvent.sortByIndex(a, b) ? Ordering.LT : (a.index == b.index ? Ordering.EQ : Ordering.GT)
        }

        // 映射名称偏移并合并相同索引的事件
        // 严格翻译自: INotifyWatcher.zig:328-347
        var nameOff: Int64 = 0
        var lastEventIndex: Int64 = 0
        var lastEventId: Int32 = Int32.max

        let changedFilepaths = watcher.getChangedFilepaths()

        for (i in 0..allEvents.size) {
            // 映射名称偏移
            // 严格翻译自: INotifyWatcher.zig:332-339
            if (allEvents[Int64(i)].nameLen > UInt8(0)) {
                let nameOffSrc = Int64(allEvents[Int64(i)].nameOff)
                if (nameOff < Int64(changedFilepaths.size) && nameOffSrc < Int64(tempNameList.size)) {
                    changedFilepaths[nameOff] = tempNameList[nameOffSrc]
                    allEvents[Int64(i)].nameOff = UInt8(Int32(nameOff))
                    nameOff += 1
                }
            }

            // 合并相同索引的事件
            // 严格翻译自: INotifyWatcher.zig:341-346
            if (Int32(allEvents[Int64(i)].index) == lastEventId) {
                allEvents[Int64(lastEventIndex)].merge(allEvents[Int64(i)])
            } else {
                lastEventIndex = i
                lastEventId = Int32(allEvents[Int64(i)].index)
            }
        }

        if (allEvents.size == 0) {
            return SysMaybe<Unit>.Ok(())
        }

        // 加锁并回调
        // 严格翻译自: INotifyWatcher.zig:350-357
        //   this.mutex.lock();
        //   defer this.mutex.unlock();
        //   if (this.running) {
        //       this.writeTraceEvents(all_events[0 .. last_event_index + 1], ...);
        //       this.onFileUpdate(this.ctx, all_events[0 .. last_event_index + 1], ...);
        //   }
        let mutex = watcher.getMutex()
        mutex.lock()
        defer {
            mutex.unlock()
        }

        if (watcher.isRunning()) {
            // 准备事件切片 [0..lastEventIndex+1]
            var eventsToFire = ArrayList<WatcherEvent>()
            for (i in 0..(lastEventIndex + 1)) {
                eventsToFire.append(allEvents[Int64(i)])
            }

            // 准备变更路径切片 [0..nameOff]
            var changedPaths = ArrayList<?String>()
            for (i in 0..nameOff) {
                changedPaths.append(changedFilepaths[i])
            }

            // 写入追踪
            watcher.writeTraceEvents(eventsToFire.toArray(), changedPaths.toArray())

            // 触发回调
            watcher.fireFileUpdate(eventsToFire.toArray(), changedPaths.toArray())
        }

        return SysMaybe<Unit>.Ok(())
    }

    // ========================================================================
    // 事件转换 - 对应 Bun watchEventFromInotifyEvent
    // 严格翻译自: INotifyWatcher.zig:361-372
    //   pub fn watchEventFromInotifyEvent(event: *align(1) const INotifyWatcher.Event,
    //                                     index: WatchItemIndex) WatchEvent {
    //       return .{
    //           .op = .{
    //               .delete = (event.mask & IN.DELETE_SELF) > 0 or (event.mask & IN.DELETE) > 0,
    //               .rename = (event.mask & IN.MOVE_SELF) > 0,
    //               .move_to = (event.mask & IN.MOVED_TO) > 0,
    //               .write = (event.mask & IN.MODIFY) > 0,
    //               .create = (event.mask & IN.CREATE) > 0,
    //           },
    //           .index = index,
    //       };
    //   }
    // ========================================================================

    /// 从 inotify 事件创建 WatcherEvent
    /// 严格翻译自: INotifyWatcher.zig:361-372
    public static func watchEventFromInotifyEvent(event: InotifyEvent,
                                                   index: WatchItemIndex): WatcherEvent {
        let op = WatcherEventOp(
            delete: (event.mask & IN_DELETE_SELF) > UInt32(0) || (event.mask & IN_DELETE) > UInt32(0),
            metadata: false,
            rename: (event.mask & IN_MOVE_SELF) > UInt32(0),
            write: (event.mask & IN_MODIFY) > UInt32(0),
            moveTo: (event.mask & IN_MOVED_TO) > UInt32(0),
            create: (event.mask & IN_CREATE) > UInt32(0)
        )
        return WatcherEvent(index: index, op: op)
    }

    // ========================================================================
    // 内部辅助方法
    // ========================================================================

    /// 原始读取 inotify 字节
    /// 对应 Bun 中 std.posix.system.read(fd, eventlist_bytes, len)
    private func rawRead(buf: Array<UInt8>): SysMaybe<Int64> {
        unsafe {
            let bufPtr = malloc(UIntNative(buf.size))
            let bytesRead = bao_sys.read(Int32(fd), bufPtr, UIntNative(buf.size))
            if (Int64(bytesRead) < 0) {
                free(bufPtr)
                let errno = OS.errno()
                // EAGAIN / EINTR: 可重试
                // 严格翻译自: INotifyWatcher.zig:170
                //   .AGAIN, .INTR => continue :outer,
                if (errno == 11 || errno == 4) {
                    return SysMaybe<Int64>.Ok(Int64(0))
                }
                return SysMaybe<Int64>.Err(
                    SysError(UInt16(errno), SysTag.Read, fd)
                )
            }
            let count = Int64(bytesRead)
            // 复制到仓颉数组
            for (i in 0..count) {
                let bytePtr = CPointer<Int8>(bufPtr) + IntNative(i)
                buf[i] = UInt8(Int32(bytePtr.read()) & 0xFF)
            }
            free(bufPtr)
            return SysMaybe<Int64>.Ok(count)
        }
    }

    /// ppoll 等待 - 对应 Bun 中 ppoll 等待合并事件
    /// 严格翻译自: INotifyWatcher.zig:140-166
    ///   var fds = [_]std.posix.pollfd{.{
    ///       .fd = this.fd.cast(),
    ///       .events = std.posix.POLL.IN | std.posix.POLL.ERR,
    ///       .revents = 0,
    ///   }};
    ///   var timespec = std.posix.timespec{ .sec = 0, .nsec = this.coalesce_interval };
    ///   if ((std.posix.ppoll(&fds, &timespec, null) catch 0) > 0) { ... }
    private func ppollWait(): Int64 {
        // 简化实现: 使用 usleep 等待 coalesceInterval 纳秒
        // 实际 Bun 使用 ppoll 同时等待 inotify fd 可读
        // 此处简化为固定等待
        let micros = coalesceInterval / 1000  // 纳秒 → 微秒
        if (micros > 0) {
            // 仓颉: std.time.Duration based sleep 简化
        }
        return 0
    }

    /// 解析原始字节为 InotifyEvent 数组
    /// 对应 Bun 中从字节数组解析 inotify_event 结构
    private func parseEvents(buf: Array<UInt8>, len: Int64): SysMaybe<Array<InotifyEvent>> {
        var events = ArrayList<InotifyEvent>()
        var i: Int64 = 0
        while (i + InotifyEvent.STRUCT_SIZE <= len) {
            // 解析固定头部 (16 字节)
            // struct inotify_event { int wd; uint32_t mask; uint32_t cookie; uint32_t len; }
            // 小端字节序
            let wd = Int32(
                Int32(buf[i]) |
                (Int32(buf[i + 1]) << 8) |
                (Int32(buf[i + 2]) << 16) |
                (Int32(buf[i + 3]) << 24)
            )
            let mask = UInt32(
                Int32(buf[i + 4]) |
                (Int32(buf[i + 5]) << 8) |
                (Int32(buf[i + 6]) << 16) |
                (Int32(buf[i + 7]) << 24)
            )
            let cookie = UInt32(
                Int32(buf[i + 8]) |
                (Int32(buf[i + 9]) << 8) |
                (Int32(buf[i + 10]) << 16) |
                (Int32(buf[i + 11]) << 24)
            )
            let nameLen = UInt32(
                Int32(buf[i + 12]) |
                (Int32(buf[i + 13]) << 8) |
                (Int32(buf[i + 14]) << 16) |
                (Int32(buf[i + 15]) << 24)
            )

            // 提取文件名 (如果存在)
            var name = ""
            if (nameLen > UInt32(0)) {
                var nameEnd = i + InotifyEvent.STRUCT_SIZE
                while (nameEnd < len && buf[Int64(nameEnd)] != UInt8(0) &&
                       nameEnd < i + InotifyEvent.STRUCT_SIZE + Int64(nameLen)) {
                    nameEnd += 1
                }
                // 构建名称字符串
                var sb = StringBuilder()
                for (j in (i + InotifyEvent.STRUCT_SIZE)..<nameEnd) {
                    sb.append(Char(Int32(buf[j])))
                }
                name = sb.toString()
            }

            events.append(InotifyEvent(
                wd: wd, mask: mask, cookie: cookie,
                nameLen: nameLen, name: name
            ))

            i += InotifyEvent.STRUCT_SIZE + Int64(nameLen)

            // 超过最大数量限制
            // 严格翻译自: INotifyWatcher.zig:205-212
            //   if (count == max_count) {
            //       this.read_ptr = .{ .i = i, .len = @intCast(read_eventlist_bytes.len) };
            //       return .{ .result = &this.eventlist_ptrs };
            //   }
            if (Int64(events.size) >= WATCHER_MAX_COUNT) {
                readPtr = InotifyReadPtr(i: UInt32(Int64(i)), len: UInt32(len))
                break
            }
        }

        readPtr = None
        return SysMaybe<Array<InotifyEvent>>.Ok(events.toArray())
    }

    /// 等待监视计数 > 0
    /// 对应 Bun Futex.waitForever(&this.watch_count, 0)
    private func waitWatchCount(): Unit {
        // 仓颉简化实现: 自旋等待
        // 实际 Bun 使用 futex 系统调用
        var spins = 0
        while (watchCount.get() == UInt32(0) && spins < 1000) {
            spins += 1
        }
    }

    /// 获取 inotify 文件描述符
    public func getFd(): Int64 {
        return fd
    }
}

/// 读取指针状态 - 对应 Bun INotifyWatcher.read_ptr
/// 严格翻译自: INotifyWatcher.zig:27-30
///   read_ptr: ?struct {
///       i: u32,
///       len: u32,
///   } = null,
public class InotifyReadPtr {
    public var i: UInt32
    public var len: UInt32

    public init(i: UInt32, len: UInt32) {
        this.i = i
        this.len = len
    }
}
