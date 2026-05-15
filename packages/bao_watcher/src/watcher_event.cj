// bao_watcher - 监视器事件类型定义
// 严格翻译自: src/watcher/Watcher.zig 中的 WatchEvent, WatchItem, WatchList 等类型
//
// Bun 的 WatchEvent 定义:
//   pub const WatchEvent = struct {
//       index: WatchItemIndex,  // u16 - 监视列表中的索引
//       op: Op,                 // packed struct(u8) - 操作位域
//       name_off: u8 = 0,       // 名称偏移 (目录监视中子文件名)
//       name_len: u8 = 0,       // 名称长度
//   };
//
//   pub const Op = packed struct(u8) {
//       delete: bool, metadata: bool, rename: bool, write: bool,
//       move_to: bool, create: bool, _padding: u2,
//   };
//
//   pub const WatchItem = struct {
//       file_path: string,      // []const u8
//       hash: u32,              // 路径哈希
//       loader: options.Loader, // 文件加载器类型
//       fd: bun.FD,             // 文件描述符
//       count: u32,             // 引用计数
//       parent_hash: u32,       // 父目录哈希
//       kind: Kind,             // file | directory
//       package_json: ?*PackageJSON,
//       eventlist_index: EventListIndex,  // 平台特定 (Linux: c_int, macOS: u0)
//   };
package bao_watcher

import bao_core.*
import bao_sys.*

// ============================================================================
// 常量 - 对应 Bun Watcher.zig 中的常量
// 严格翻译自:
//   pub const max_count = 128;
//   pub const WatchItemIndex = u16;
//   pub const max_eviction_count = 8096;
//   pub const HashType = u32;
// ============================================================================

/// 最大事件数量 - 对应 Bun Watcher.max_count
/// Bun: pub const max_count = 128
public let WATCHER_MAX_COUNT: Int64 = 128

/// 最大驱逐数量 - 对应 Bun Watcher.max_eviction_count
/// Bun: pub const max_eviction_count = 8096
public let WATCHER_MAX_EVICTION_COUNT: Int64 = 8096

/// 监视项索引类型 - 对应 Bun Watcher.WatchItemIndex = u16
public type WatchItemIndex = UInt16

/// 哈希类型 - 对应 Bun Watcher.HashType = u32
public type HashType = UInt32

/// 无效监视项索引 - 对应 Bun no_watch_item = maxInt(WatchItemIndex)
public let NO_WATCH_ITEM: WatchItemIndex = UInt16.max

// ============================================================================
// WatcherEventOp - 事件操作位域
// 严格翻译自: src/watcher/Watcher.zig:176-211
//   pub const Op = packed struct(u8) {
//       delete: bool = false,
//       metadata: bool = false,
//       rename: bool = false,
//       write: bool = false,
//       move_to: bool = false,
//       create: bool = false,
//       _padding: u2 = 0,
//   };
//
// Bun 使用 packed struct(u8) 高效存储 6 个布尔标志
// 仓颉使用 class + 布尔字段实现等价语义
// ============================================================================

/// 监视事件操作 - 对应 Bun WatchEvent.Op
/// 严格翻译自: Watcher.zig:176-211
/// Bun 使用 packed struct(u8) 位域, 仓颉使用普通布尔字段
public class WatcherEventOp {
    /// 文件被删除 - 对应 Op.delete
    public var delete: Bool
    /// 元数据变更 - 对应 Op.metadata (chmod, chown 等)
    public var metadata: Bool
    /// 文件被重命名 - 对应 Op.rename
    public var rename: Bool
    /// 文件被写入 - 对应 Op.write
    public var write: Bool
    /// 文件被移入 - 对应 Op.move_to
    public var moveTo: Bool
    /// 文件被创建 - 对应 Op.create
    public var create: Bool

    public init() {
        delete = false
        metadata = false
        rename = false
        write = false
        moveTo = false
        create = false
    }

    public init(delete: Bool, metadata: Bool, rename: Bool, write: Bool, moveTo: Bool, create: Bool) {
        this.delete = delete
        this.metadata = metadata
        this.rename = rename
        this.write = write
        this.moveTo = moveTo
        this.create = create
    }

    /// 合并两个操作 - 对应 Bun Op.merge(before, after)
    /// 严格翻译自: Watcher.zig:186-194
    ///   pub fn merge(before: Op, after: Op) Op {
    ///       return .{
    ///           .delete = before.delete or after.delete,
    ///           .write = before.write or after.write,
    ///           .metadata = before.metadata or after.metadata,
    ///           .rename = before.rename or after.rename,
    ///           .move_to = before.move_to or after.move_to,
    ///           .create = before.create or after.create,
    ///       };
    ///   }
    public static func merge(before: WatcherEventOp, after: WatcherEventOp): WatcherEventOp {
        return WatcherEventOp(
            delete: before.delete || after.delete,
            metadata: before.metadata || after.metadata,
            rename: before.rename || after.rename,
            write: before.write || after.write,
            moveTo: before.moveTo || after.moveTo,
            create: before.create || after.create
        )
    }

    /// 格式化为字符串 - 对应 Bun Op.format
    /// 严格翻译自: Watcher.zig:196-210
    ///   pub fn format(op: Op, w: *std.Io.Writer) !void {
    ///       try w.writeAll("{");
    ///       var first = true;
    ///       inline for (comptime std.meta.fieldNames(Op)) |name| {
    ///           if (comptime std.mem.eql(u8, name, "_padding")) continue;
    ///           if (@field(op, name)) {
    ///               if (!first) try w.writeAll(",");
    ///               first = false;
    ///               try w.writeAll(name);
    ///           }
    ///       }
    ///       try w.writeAll("}");
    ///   }
    public func format(): String {
        var parts = ArrayList<String>()
        if (delete) { parts.append("delete") }
        if (metadata) { parts.append("metadata") }
        if (rename) { parts.append("rename") }
        if (write) { parts.append("write") }
        if (moveTo) { parts.append("move_to") }
        if (create) { parts.append("create") }
        return "{" + ",".join(parts) + "}"
    }
}

// ============================================================================
// WatcherEvent - 监视事件
// 严格翻译自: src/watcher/Watcher.zig:154-212
//   pub const WatchEvent = struct {
//       index: WatchItemIndex,
//       op: Op,
//       name_off: u8 = 0,
//       name_len: u8 = 0,
//   };
// ============================================================================

/// 监视事件 - 对应 Bun Watcher.WatchEvent
/// 严格翻译自: Watcher.zig:154-212
public class WatcherEvent {
    /// 监视列表中的索引 - 对应 WatchEvent.index: WatchItemIndex
    public var index: WatchItemIndex
    /// 操作标志 - 对应 WatchEvent.op: Op
    public var op: WatcherEventOp
    /// 名称偏移 - 对应 WatchEvent.name_off: u8
    /// 用于目录监视时记录子文件名在 changed_filepaths 中的偏移
    public var nameOff: UInt8
    /// 名称长度 - 对应 WatchEvent.name_len: u8
    public var nameLen: UInt8

    public init() {
        index = UInt16(0)
        op = WatcherEventOp()
        nameOff = UInt8(0)
        nameLen = UInt8(0)
    }

    public init(index: WatchItemIndex, op: WatcherEventOp) {
        this.index = index
        this.op = op
        nameOff = UInt8(0)
        nameLen = UInt8(0)
    }

    /// 获取事件关联的文件名列表 - 对应 Bun WatchEvent.names(buf)
    /// 严格翻译自: Watcher.zig:160-163
    ///   pub fn names(this: WatchEvent, buf: []?[:0]u8) []?[:0]u8 {
    ///       if (this.name_len == 0) return &[_]?[:0]u8{};
    ///       return buf[this.name_off..][0..this.name_len];
    ///   }
    public func names(buf: Array<?String>): Array<?String> {
        if (nameLen == UInt8(0)) {
            return []
        }
        var result = ArrayList<?String>()
        let end = Int64(nameOff) + Int64(nameLen)
        for (i in Int64(nameOff)..<end) {
            if (i < buf.size) {
                result.append(buf[i])
            }
        }
        return result.toArray()
    }

    /// 合并事件 - 对应 Bun WatchEvent.merge(other)
    /// 严格翻译自: Watcher.zig:172-174
    ///   pub fn merge(this: *WatchEvent, other: WatchEvent) void {
    ///       this.name_len += other.name_len;
    ///       this.op = Op.merge(this.op, other.op);
    ///   }
    public func merge(other: WatcherEvent): Unit {
        nameLen = UInt8(Int32(nameLen) + Int32(other.nameLen))
        op = WatcherEventOp.merge(op, other.op)
    }

    /// 按索引排序的比较器 - 对应 Bun WatchEvent.sortByIndex
    /// 严格翻译自: Watcher.zig:167-169
    ///   pub fn sortByIndex(_: Sorter, event: WatchEvent, rhs: WatchEvent) bool {
    ///       return event.index < rhs.index;
    ///   }
    public static func sortByIndex(a: WatcherEvent, b: WatcherEvent): Bool {
        return a.index < b.index
    }
}

// ============================================================================
// WatchItemKind - 监视项类型
// 严格翻译自: src/watcher/Watcher.zig:226
//   pub const Kind = enum { file, directory };
// ============================================================================

/// 监视项类型 - 对应 Bun WatchItem.Kind
/// 严格翻译自: Watcher.zig:227
/// Bun: pub const Kind = enum { file, directory }
public enum WatchItemKind {
    | File
    | Directory
}

// ============================================================================
// WatchItem - 监视列表项
// 严格翻译自: src/watcher/Watcher.zig:214-227
//   pub const WatchItem = struct {
//       file_path: string,
//       hash: u32,
//       loader: options.Loader,
//       fd: bun.FD,
//       count: u32,
//       parent_hash: u32,
//       kind: Kind,
//       package_json: ?*PackageJSON,
//       eventlist_index: EventListIndex,
//   };
// ============================================================================

/// 监视列表项 - 对应 Bun Watcher.WatchItem
/// 严格翻译自: Watcher.zig:214-227
public class WatchItem {
    /// 文件路径 - 对应 WatchItem.file_path: string
    public var filePath: String
    /// 路径哈希 - 对应 WatchItem.hash: u32
    public var hash: HashType
    /// 加载器类型 - 对应 WatchItem.loader: options.Loader
    /// Bun 使用 options.Loader 枚举标识文件类型 (js, ts, css, file 等)
    public var loader: Int64
    /// 文件描述符 - 对应 WatchItem.fd: bun.FD
    public var fd: Int64
    /// 引用计数 - 对应 WatchItem.count: u32
    public var count: UInt32
    /// 父目录哈希 - 对应 WatchItem.parent_hash: u32
    public var parentHash: HashType
    /// 监视项类型 - 对应 WatchItem.kind: Kind
    public var kind: WatchItemKind
    /// 包 JSON 指针 - 对应 WatchItem.package_json: ?*PackageJSON
    public var packageJson: ?Any
    /// 平台特定的事件列表索引 - 对应 WatchItem.eventlist_index
    /// Linux: c_int (inotify watch descriptor)
    /// macOS: u0 (未使用)
    public var eventlistIndex: Int32

    public init() {
        filePath = ""
        hash = UInt32(0)
        loader = 0
        fd = INVALID_FD
        count = UInt32(0)
        parentHash = UInt32(0)
        kind = WatchItemKind.File
        packageJson = None
        eventlistIndex = Int32(0)
    }

    public init(filePath: String, hash: HashType, loader: Int64, fd: Int64,
                count: UInt32, parentHash: HashType, kind: WatchItemKind,
                packageJson: ?Any, eventlistIndex: Int32) {
        this.filePath = filePath
        this.hash = hash
        this.loader = loader
        this.fd = fd
        this.count = count
        this.parentHash = parentHash
        this.kind = kind
        this.packageJson = packageJson
        this.eventlistIndex = eventlistIndex
    }

    /// 便利构造: 文件类型监视项
    public static func forFile(filePath: String, hash: HashType, fd: Int64,
                               loader: Int64, parentHash: HashType): WatchItem {
        return WatchItem(
            filePath: filePath,
            hash: hash,
            loader: loader,
            fd: fd,
            count: UInt32(0),
            parentHash: parentHash,
            kind: WatchItemKind.File,
            packageJson: None,
            eventlistIndex: Int32(0)
        )
    }

    /// 便利构造: 目录类型监视项
    public static func forDirectory(filePath: String, hash: HashType, fd: Int64): WatchItem {
        return WatchItem(
            filePath: filePath,
            hash: hash,
            loader: 0,  // options.Loader.file
            fd: fd,
            count: UInt32(0),
            parentHash: UInt32(0),
            kind: WatchItemKind.Directory,
            packageJson: None,
            eventlistIndex: Int32(0)
        )
    }
}

// ============================================================================
// WatchList - 监视列表
// 严格翻译自: src/watcher/Watcher.zig:50
//   pub const WatchList = std.MultiArrayList(WatchItem);
//
// Bun 使用 MultiArrayList 实现结构体数组 (SoA 布局)
// 仓颉使用 ArrayList<WatchItem> 实现等价语义
// ============================================================================

/// 监视列表 - 对应 Bun Watcher.WatchList = std.MultiArrayList(WatchItem)
/// 严格翻译自: Watcher.zig:50
///
/// Bun 的 MultiArrayList 是结构体数组 (Structure of Arrays) 布局:
///   每个字段存储在独立的连续数组中, 提高缓存局部性
///   items(.field_name) 返回该字段数组的切片
///
/// 仓颉使用 ArrayList<WatchItem> 简化实现
public class WatchList {
    /// 内部存储 - 对应 MultiArrayList 的各字段数组
    private var items: ArrayList<WatchItem>

    public init() {
        items = ArrayList<WatchItem>()
    }

    /// 当前列表长度 - 对应 MultiArrayList.len
    public prop size: Int64 {
        get() {
            return items.size
        }
    }

    /// 追加元素 (假设已有足够容量) - 对应 MultiArrayList.appendAssumeCapacity
    /// 严格翻译自: Watcher.zig 中多处调用 watchlist.appendAssumeCapacity(item)
    public func appendAssumeCapacity(item: WatchItem): Unit {
        items.append(item)
    }

    /// 确保额外容量 - 对应 MultiArrayList.ensureUnusedCapacity
    /// 严格翻译自: Watcher.zig:577
    ///   bun.handleOom(this.watchlist.ensureUnusedCapacity(this.allocator, 1 + ...))
    public func ensureUnusedCapacity(additional: Int64): Unit {
        // ArrayList 自动扩容, 无需手动调用
    }

    /// 交换移除 - 对应 MultiArrayList.swapRemove
    /// 严格翻译自: Watcher.zig:302 this.watchlist.swapRemove(item)
    /// swapRemove 将末尾元素移到被删除位置, O(1) 但不保序
    public func swapRemove(index: Int64): ?WatchItem {
        if (index < 0 || index >= items.size) {
            return None
        }
        let removed = items[index]
        if (index < items.size - 1) {
            items[index] = items[items.size - 1]
        }
        items.removeAt(items.size - 1)
        return removed
    }

    /// 获取指定索引的元素
    public func get(index: Int64): ?WatchItem {
        if (index < 0 || index >= items.size) {
            return None
        }
        return items[index]
    }

    /// 设置指定索引的元素
    public func set(index: Int64, item: WatchItem): Unit {
        if (index >= 0 && index < items.size) {
            items[index] = item
        }
    }

    /// 按哈希值查找索引 - 对应 Watcher.indexOf(hash)
    /// 严格翻译自: Watcher.zig:749-756
    ///   pub fn indexOf(this: *Watcher, hash: HashType) ?u32 {
    ///       for (this.watchlist.items(.hash), 0..) |other, i| {
    ///           if (hash == other) return @as(u32, @truncate(i));
    ///       }
    ///       return null;
    ///   }
    public func indexOfHash(hash: HashType): ?Int64 {
        for (i in 0..items.size) {
            if (items[i].hash == hash) {
                return i
            }
        }
        return None
    }

    /// 获取所有文件描述符 - 对应 watchlist.items(.fd)
    /// 严格翻译自: Watcher.zig 中 watchlist.slice().items(.fd) 和 watchlist.items(.fd)
    public func fds(): Array<Int64> {
        var result = ArrayList<Int64>()
        for (item in items) {
            result.append(item.fd)
        }
        return result.toArray()
    }

    /// 获取所有哈希 - 对应 watchlist.items(.hash)
    public func hashes(): Array<HashType> {
        var result = ArrayList<HashType>()
        for (item in items) {
            result.append(item.hash)
        }
        return result.toArray()
    }

    /// 获取所有路径 - 对应 watchlist.items(.file_path)
    public func filePaths(): Array<String> {
        var result = ArrayList<String>()
        for (item in items) {
            result.append(item.filePath)
        }
        return result.toArray()
    }

    /// 获取所有 eventlist_index - 对应 watchlist.items(.eventlist_index)
    /// 严格翻译自: INotifyWatcher.zig:237
    ///   const eventlist_index = this.watchlist.items(.eventlist_index);
    public func eventlistIndices(): Array<Int32> {
        var result = ArrayList<Int32>()
        for (item in items) {
            result.append(item.eventlistIndex)
        }
        return result.toArray()
    }

    /// 释放资源 - 对应 MultiArrayList.deinit(allocator)
    /// 严格翻译自: Watcher.zig:256 this.watchlist.deinit(this.allocator)
    public func deinit(): Unit {
        items.clear()
    }

    /// 迭代器
    public func iterator(): Iterator<WatchItem> {
        return items.iterator()
    }
}

// ============================================================================
// 回调类型定义
// 严格翻译自: src/watcher/Watcher.zig:31-33
//   onFileUpdate: *const fn (this: *anyopaque, events: []WatchEvent,
//                            changed_files: []?[:0]u8, watchlist: WatchList) void,
//   onError: *const fn (this: *anyopaque, err: bun.sys.Error) void,
// ============================================================================

/// 文件变更回调 - 对应 Bun Watcher.onFileUpdate
/// 严格翻译自: Watcher.zig:32
///   *const fn (this: *anyopaque, events: []WatchEvent,
///              changed_files: []?[:0]u8, watchlist: WatchList) void
///
/// ctx: 上下文指针 (对应 Bun *anyopaque)
/// events: 监视事件数组
/// changedFiles: 变更文件名数组 (目录监视中子文件名)
/// watchlist: 当前监视列表
public type FileChangeCallback = (ctx: Any, events: Array<WatcherEvent>,
                                   changedFiles: Array<?String>, watchlist: WatchList) -> Unit

/// 错误回调 - 对应 Bun Watcher.onError
/// 严格翻译自: Watcher.zig:33
///   *const fn (this: *anyopaque, err: bun.sys.Error) void
public type ErrorCallback = (ctx: Any, err: SysError) -> Unit
