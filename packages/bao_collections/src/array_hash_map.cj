// bao_collections - ArrayHashMap 开放寻址哈希表
// 严格翻译自: src/collections/zig_hash_map.zig (HashMap/HashMapMixin/SortedHashMap)
//   以及 src/collections/array_hash_map.rs (ArrayHashMap 完整实现)
//   Bun 使用 Robin-Hood 开放寻址哈希，条目按哈希值排序存储
//   仓颉实现保持相同的 Robin-Hood 算法和开放寻址布局
package bao_collections

import bao_core.*
import bao_hash.*

// ============================================================================
// 常量 - 对应 Bun zig_hash_map.zig
//   const empty_hash = math.maxInt(u64); // 0xFFFFFFFFFFFFFFFF
//   用于标记空条目
// ============================================================================

/// 空条目标记哈希 - 对应 Bun empty_hash = math.maxInt(u64)
/// Zig: const empty_hash = math.maxInt(u64)
/// 当 Entry.hash == EMPTY_HASH 时表示该槽位为空
private let EMPTY_HASH: UInt64 = UInt64.MAX

/// Robin-Hood 哈希默认最大负载百分比
/// Zig: max_load_percentage comptime_int (典型值 50)
private let DEFAULT_MAX_LOAD_PERCENTAGE: Int64 = 50

// ============================================================================
// Entry<K, V> - 哈希表条目
// 严格翻译自: src/collections/zig_hash_map.zig - HashMap.Entry
//   Zig:
//     pub const Entry = struct {
//         hash: u64 = empty_hash,
//         key: K = undefined,
//         value: V = undefined,
//         pub fn isEmpty(self: Entry) bool { return self.hash == empty_hash; }
//     };
// ============================================================================

/// 哈希表条目 - 对应 Bun HashMap.Entry
/// 使用 Robin-Hood 开放寻址: 条目按 hash 值排序存储
/// hash == EMPTY_HASH 表示空槽位
class ArrayHashEntry<K, V> {
    /// 哈希值 - 对应 Bun Entry.hash
    /// Zig: hash: u64 = empty_hash
    /// 空条目的 hash == EMPTY_HASH
    public var hash: UInt64

    /// 键 - 对应 Bun Entry.key
    public var key: K

    /// 值 - 对应 Bun Entry.value
    public var value: V

    public init(key: K, value: V, hash: UInt64) {
        this.key = key
        this.value = value
        this.hash = hash
    }

    /// 是否为空槽位 - 对应 Bun Entry.isEmpty
    /// Zig: pub fn isEmpty(self: Entry) bool { return self.hash == empty_hash; }
    public func isEmpty(): Bool {
        return hash == EMPTY_HASH
    }
}

// ============================================================================
// GetOrPutResult - 获取或插入结果
// 严格翻译自: src/collections/zig_hash_map.zig - HashMap.GetOrPutResult
//   Zig:
//     pub const GetOrPutResult = struct {
//         value_ptr: *V,
//         found_existing: bool,
//     };
//   仓颉: 因为没有裸指针，使用索引 + 引用语义容器模拟
// ============================================================================

/// 获取或插入的结果 - 对应 Bun HashMap.GetOrPutResult
/// Zig 返回 *V 指针; 仓颉使用 (索引, 是否已存在) 元组
public class GetOrPutResult<V> {
    /// 值引用 (通过索引访问)
    public var value: V
    /// 是否已存在
    public var foundExisting: Bool

    public init(value: V, foundExisting: Bool) {
        this.value = value
        this.foundExisting = foundExisting
    }
}

// ============================================================================
// HashContext<K> - 哈希上下文接口
// 严格翻译自: src/collections/zig_hash_map.rs - HashContext trait
//   Zig 使用 comptime duck typing: Context 类型必须有 .hash(key) 和 .eql(a, b)
//   仓颉使用接口定义
// ============================================================================

/// 哈希上下文接口 - 对应 Bun HashContext
/// 所有自定义哈希策略都需要实现此接口
public interface HashContext<K> {
    /// 计算键的哈希值
    /// Zig: pub fn hash(_: @This(), key: Key) u64
    func hash(key: K): UInt64

    /// 比较两个键是否相等
    /// Zig: pub fn eql(_: @This(), a: Key, b: Key) bool
    func eql(a: K, b: K): Bool
}

/// 自动哈希上下文 - 对应 Bun AutoContext / std.hash_map.AutoContext
/// 使用键的默认 Hash + Eq 实现
public class AutoHashContext<K> <: HashContext<K> where K <: Equatable<K> {
    public init() {}

    public func hash(key: K): UInt64 {
        return WyHash.hash(key.toString())
    }

    public func eql(a: K, b: K): Bool {
        return a == b
    }
}

// ============================================================================
// ArrayHashMap<K, V> - Robin-Hood 开放寻址哈希表
// 严格翻译自: src/collections/zig_hash_map.zig - HashMap
//   以及 HashMapMixin 中的所有方法
//
// Bun 设计:
//   1. Robin-Hood 开放寻址哈希
//      - 条目按 hash 值排序存储 (非按插入顺序)
//      - getOrPut 中: 当新 hash < 已有 hash 时，交换 (Robin-Hood 窃取)
//   2. shift 字段控制哈希到桶的映射:
//      capacity = 1 << (63 - shift + 1)
//      桶索引 = hash >> shift
//   3. 溢出区: 额外的 overflow 个槽位，处理 Robin-Hood 探测溢出
//      overflow = (capacity / 10 + (63 - shift + 1)) << 1
//   4. 动态扩容: 当元素数量超过 capacity * max_load_percentage / 100 时 grow
//   5. grow 策略: 容量翻倍，重新插入所有条目
//
// Zig: entries: [*]Entry (原始指针)
// 仓颉: entries: ArrayList<Entry<K,V>> (自动管理)
// ============================================================================

/// Robin-Hood 开放寻址哈希表 - 对应 Bun HashMap
/// 使用 Robin-Hood 探测策略减少最大探测距离
/// 条目按哈希值排序存储 (非插入顺序)
///
/// Zig HashMap 参数:
///   comptime K: type         - 键类型
///   comptime V: type         - 值类型
///   comptime Context: type   - 哈希上下文
///   comptime max_load_percentage: comptime_int - 最大负载百分比
public class ArrayHashMap<K, V> where K <: Equatable<K> {
    /// 条目数组 - 对应 Bun entries: [*]Entry
    /// 包含 capacity + overflow 个槽位
    private var entries: ArrayList<ArrayHashEntry<K, V>>
    /// 当前元素数量 - 对应 Bun len
    private var _len: Int64
    /// 移位量 - 对应 Bun shift: u6
    /// capacity = 1 << (63 - shift + 1)
    /// 桶索引 = hash >> shift
    private var shift: UInt8
    /// 最大负载百分比 - 对应 Bun max_load_percentage
    private var maxLoadPercentage: Int64
    /// 哈希上下文 - 对应 Bun context
    private var ctx: HashContext<K>

    /// 元素数量 - 对应 Bun len()
    public prop size: Int64 {
        get() { _len }
    }

    /// 默认构造 - 初始容量 16
    public init() {
        entries = ArrayList<ArrayHashEntry<K, V>>()
        _len = 0
        shift = 60  // capacity = 1 << (63 - 60 + 1) = 1 << 4 = 16
        maxLoadPercentage = DEFAULT_MAX_LOAD_PERCENTAGE
        ctx = AutoHashContext<K>()
        initEntries(computeCapacity())
    }

    /// 带上下文构造
    public init(ctx: HashContext<K>) {
        entries = ArrayList<ArrayHashEntry<K, V>>()
        _len = 0
        shift = 60
        maxLoadPercentage = DEFAULT_MAX_LOAD_PERCENTAGE
        this.ctx = ctx
        initEntries(computeCapacity())
    }

    /// 带初始容量构造 - 对应 Bun HashMap.initCapacity
    /// Zig: pub fn initCapacity(gpa: mem.Allocator, capacity: u64) !Self
    /// capacity 必须是 2 的幂
    public init(capacity: Int64) {
        entries = ArrayList<ArrayHashEntry<K, V>>()
        _len = 0
        maxLoadPercentage = DEFAULT_MAX_LOAD_PERCENTAGE
        ctx = AutoHashContext<K>()
        let cap = nextPowerOfTwo(capacity)
        shift = computeShift(cap)
        initEntries(cap)
    }

    /// 带初始容量和上下文构造
    public init(capacity: Int64, ctx: HashContext<K>) {
        entries = ArrayList<ArrayHashEntry<K, V>>()
        _len = 0
        maxLoadPercentage = DEFAULT_MAX_LOAD_PERCENTAGE
        this.ctx = ctx
        let cap = nextPowerOfTwo(capacity)
        shift = computeShift(cap)
        initEntries(cap)
    }

    // ========================================================================
    // 容量与状态查询 - 对应 Bun HashMap 公共方法
    // ========================================================================

    /// 是否为空
    public func isEmpty(): Bool {
        return _len == 0
    }

    /// 当前容量 - 对应 Bun capacity()
    /// capacity = 1 << (63 - shift + 1)
    public func capacity(): Int64 {
        return Int64(UInt64(1) << UInt64(63 - Int64(shift) + 1))
    }

    /// 获取底层条目切片 - 对应 Bun HashMap.slice()
    /// Zig: pub fn slice(self: *Self) []Self.Entry
    /// 返回所有条目 (包含容量 + 溢出区)
    public func slice(): ArrayList<ArrayHashEntry<K, V>> {
        return entries
    }

    // ========================================================================
    // 插入操作 - 对应 Bun HashMapMixin.putAssumeCapacity / put
    // ========================================================================

    /// 插入/更新键值对 (假定有足够容量) - 对应 Bun putAssumeCapacity
    /// Zig HashMapMixin:
    ///   pub fn putAssumeCapacity(self: *Self, key: K, value: V) void {
    ///       const result = self.getOrPutAssumeCapacity(key);
    ///       if (!result.found_existing) result.value_ptr.* = value;
    ///   }
    public func putAssumeCapacity(key: K, value: V): Unit {
        let gop = getOrPutAssumeCapacity(key)
        if (!gop.foundExisting) {
            gop.value = value
        }
    }

    /// 插入/更新键值对 (自动扩容) - 对应 Bun HashMap.put
    /// Zig:
    ///   pub fn put(self: *Self, gpa: mem.Allocator, key: K, value: V) !void {
    ///       try self.ensureUnusedCapacity(gpa, 1);
    ///       self.putAssumeCapacity(key, value);
    ///   }
    public func put(key: K, value: V): Unit {
        ensureUnusedCapacity(1)
        putAssumeCapacity(key, value)
    }

    // ========================================================================
    // 获取或插入 - 对应 Bun HashMapMixin.getOrPutAssumeCapacity
    //   Robin-Hood 探测的核心算法
    // ========================================================================

    /// 获取或插入 (假定有足够容量) - 对应 Bun getOrPutAssumeCapacity
    /// Zig HashMapMixin.getOrPutAssumeCapacity:
    ///   Robin-Hood 探测: 条目按 hash 排序
    ///   当新 hash < 已有条目 hash 时，交换 (窃取更近的位置)
    ///   空条目终止探测
    public func getOrPutAssumeCapacity(key: K): GetOrPutResult<V> {
        let h = ctx.hash(key)
        // Zig: assert(it.hash != Self.empty_hash)
        if (h == EMPTY_HASH) {
            // 退化情况: 不应该出现
            let entry = ArrayHashEntry<K, V>(key, defaultValue(), EMPTY_HASH)
            entries.append(entry)
            _len += 1
            return GetOrPutResult<V>(defaultValue(), false)
        }

        var it = ArrayHashEntry<K, V>(key, defaultValue(), h)
        var i = Int64(h >> UInt64(shift))
        var insertedAt: ?Int64 = None

        // Zig: while (true) : (i += 1)
        while (i < entries.size) {
            let entry = entries[i]
            // Zig: if (entry.hash >= it.hash)
            if (entry.hash >= it.hash) {
                // Zig: if (ctx.eql(entry.key, key))
                if (ctx.eql(entry.key, key)) {
                    // 找到已存在的键
                    return GetOrPutResult<V>(entry.value, true)
                }
                // Robin-Hood: 窃取位置
                entries[i] = it
                // Zig: if (entry.isEmpty())
                if (entry.isEmpty()) {
                    _len += 1
                    let idx = if (insertedAt != None) { insertedAt } else { i }
                    return GetOrPutResult<V>(entries[Int64(idx)].value, false)
                }
                // Zig: if (inserted_at == null) inserted_at = i
                if (insertedAt == None) {
                    insertedAt = i
                }
                it = entry  // 继续探测被踢出的条目
            }
            i += 1
        }
        // 溢出区不够: 扩容后重试
        grow()
        return getOrPutAssumeCapacity(key)
    }

    /// 获取或插入 (自动扩容) - 对应 Bun HashMap.getOrPut
    public func getOrPut(key: K): GetOrPutResult<V> {
        ensureUnusedCapacity(1)
        return getOrPutAssumeCapacity(key)
    }

    // ========================================================================
    // 查询操作 - 对应 Bun HashMapMixin.get / has / hasWithHash
    // ========================================================================

    /// 获取值 - 对应 Bun HashMapMixin.get
    /// Zig:
    ///   pub fn get(self: *const Self, key: K) ?V {
    ///       const hash = ctx.hash(key);
    ///       for (self.entries[hash >> self.shift ..]) |entry| {
    ///           if (entry.hash >= hash) {
    ///               if (!ctx.eql(entry.key, key)) return null;
    ///               return entry.value;
    ///           }
    ///       }
    ///   }
    public func get(key: K): ?V {
        let h = ctx.hash(key)
        if (h == EMPTY_HASH) {
            return None
        }
        let startIdx = Int64(h >> UInt64(shift))
        // Zig: for (self.entries[hash >> self.shift ..]) |entry|
        var i = startIdx
        while (i < entries.size) {
            let entry = entries[i]
            // Zig: if (entry.hash >= hash)
            if (entry.hash >= h) {
                // Zig: if (!ctx.eql(entry.key, key)) return null
                if (!ctx.eql(entry.key, key)) {
                    return None
                }
                return Some(entry.value)
            }
            i += 1
        }
        return None
    }

    /// 是否包含键 - 对应 Bun HashMapMixin.has
    /// Zig:
    ///   pub fn has(self: *const Self, key: K) bool
    public func has(key: K): Bool {
        let h = ctx.hash(key)
        if (h == EMPTY_HASH) {
            return false
        }
        let startIdx = Int64(h >> UInt64(shift))
        var i = startIdx
        while (i < entries.size) {
            let entry = entries[i]
            if (entry.hash >= h) {
                if (!ctx.eql(entry.key, key)) {
                    return false
                }
                return true
            }
            i += 1
        }
        return false
    }

    /// 按哈希值检查 - 对应 Bun HashMapMixin.hasWithHash
    /// Zig:
    ///   pub fn hasWithHash(self: *const Self, key_hash: u64) bool {
    ///       for (self.entries[key_hash >> self.shift ..]) |entry| {
    ///           if (entry.hash >= key_hash) return entry.hash == key_hash;
    ///       }
    ///       return false;
    ///   }
    public func hasWithHash(keyHash: UInt64): Bool {
        if (keyHash == EMPTY_HASH) {
            return false
        }
        let startIdx = Int64(keyHash >> UInt64(shift))
        var i = startIdx
        while (i < entries.size) {
            let entry = entries[i]
            if (entry.hash >= keyHash) {
                return entry.hash == keyHash
            }
            i += 1
        }
        return false
    }

    // ========================================================================
    // 删除操作 - 对应 Bun HashMapMixin.delete
    //   Robin-Hood 删除: 移除条目后，将后续条目前移填补空隙
    //   保持排序不变式: 所有条目按 hash 排序
    // ========================================================================

    /// 删除键值对并返回值 - 对应 Bun HashMapMixin.delete
    /// Zig:
    ///   pub fn delete(self: *Self, key: K) ?V {
    ///       // 找到条目位置
    ///       var i = hash >> self.shift;
    ///       while (true) : (i += 1) {
    ///           const entry = self.entries[i];
    ///           if (entry.hash >= hash) {
    ///               if (!ctx.eql(entry.key, key)) return null;
    ///               break;
    ///           }
    ///       }
    ///       // 前移后续条目
    ///       while (true) : (i += 1) {
    ///           const j = self.entries[i + 1].hash >> self.shift;
    ///           if (i < j || self.entries[i + 1].isEmpty()) break;
    ///           self.entries[i] = self.entries[i + 1];
    ///       }
    ///       self.entries[i] = .{};  // 清空
    ///       self.len -= 1;
    ///       return value;
    ///   }
    public func delete(key: K): ?V {
        let h = ctx.hash(key)
        if (h == EMPTY_HASH) {
            return None
        }
        // 找到条目位置
        var i = Int64(h >> UInt64(shift))
        while (i < entries.size) {
            let entry = entries[i]
            if (entry.hash >= h) {
                if (!ctx.eql(entry.key, key)) {
                    return None
                }
                // 找到了
                break
            }
            i += 1
        }
        if (i >= entries.size) {
            return None
        }
        let value = entries[i].value

        // 前移后续条目 - Robin-Hood 删除
        // Zig: while (true) : (i += 1)
        while (i + 1 < entries.size) {
            let next = entries[i + 1]
            // Zig: const j = self.entries[i + 1].hash >> self.shift;
            let j = Int64(next.hash >> UInt64(shift))
            // Zig: if (i < j || self.entries[i + 1].isEmpty()) break;
            if (i < j || next.isEmpty()) {
                break
            }
            // 前移
            entries[i] = next
            i += 1
        }
        // 清空最终位置
        entries[i] = makeEmptyEntry()
        _len -= 1

        return Some(value)
    }

    // ========================================================================
    // 清空与容量管理 - 对应 Bun HashMap.clearRetainingCapacity / ensureTotalCapacity
    // ========================================================================

    /// 清空但保留容量 - 对应 Bun HashMapMixin.clearRetainingCapacity
    /// Zig:
    ///   pub fn clearRetainingCapacity(self: *Self) void {
    ///       @memset(self.slice(), .{});
    ///       self.len = 0;
    ///   }
    public func clearRetainingCapacity(): Unit {
        for (i in 0..entries.size) {
            entries[i] = makeEmptyEntry()
        }
        _len = 0
    }

    /// 清空
    public func clear(): Unit {
        clearRetainingCapacity()
    }

    /// 确保额外容量 - 对应 Bun HashMap.ensureUnusedCapacity
    /// Zig:
    ///   pub fn ensureUnusedCapacity(self: *Self, gpa: mem.Allocator, count: usize) !void {
    ///       try self.ensureTotalCapacity(gpa, self.len + count);
    ///   }
    public func ensureUnusedCapacity(count: Int64): Unit {
        ensureTotalCapacity(_len + count)
    }

    /// 确保总容量 - 对应 Bun HashMap.ensureTotalCapacity
    /// Zig:
    ///   pub fn ensureTotalCapacity(self: *Self, gpa: mem.Allocator, count: usize) !void {
    ///       while (true) {
    ///           const capacity = 1 << (63 - self.shift + 1);
    ///           if (count <= capacity * max_load_percentage / 100) break;
    ///           try self.grow(gpa);
    ///       }
    ///   }
    public func ensureTotalCapacity(count: Int64): Unit {
        var cap = capacity()
        while (count > cap * maxLoadPercentage / 100) {
            grow()
            cap = capacity()
        }
    }

    // ========================================================================
    // 遍历与转换
    // ========================================================================

    /// 获取所有键值对
    public func entries(): ArrayList<(K, V)> {
        let result = ArrayList<(K, V)>()
        for (i in 0..entries.size) {
            let e = entries[i]
            if (!e.isEmpty()) {
                result.append((e.key, e.value))
            }
        }
        return result
    }

    /// 获取所有键
    public func keys(): ArrayList<K> {
        let result = ArrayList<K>()
        for (i in 0..entries.size) {
            let e = entries[i]
            if (!e.isEmpty()) {
                result.append(e.key)
            }
        }
        return result
    }

    /// 获取所有值
    public func values(): ArrayList<V> {
        let result = ArrayList<V>()
        for (i in 0..entries.size) {
            let e = entries[i]
            if (!e.isEmpty()) {
                result.append(e.value)
            }
        }
        return result
    }

    /// 遍历
    public func forEach(fn: (K, V) -> Unit): Unit {
        for (i in 0..entries.size) {
            let e = entries[i]
            if (!e.isEmpty()) {
                fn(e.key, e.value)
            }
        }
    }

    /// 检查条目排序是否正确 (调试用)
    /// 对应 Bun test "HashMap: put, get, delete, grow" 中的排序验证
    public func isSorted(): Bool {
        var lastHash: UInt64 = 0
        for (i in 0..entries.size) {
            let e = entries[i]
            if (!e.isEmpty()) {
                if (e.hash < lastHash) {
                    return false
                }
                lastHash = e.hash
            }
        }
        return true
    }

    // ========================================================================
    // 内部方法 - Robin-Hood 哈希核心
    // ========================================================================

    /// 扩容 - 对应 Bun HashMap.grow
    /// Zig:
    ///   fn grow(self: *Self, gpa: mem.Allocator) !void {
    ///       const capacity = 1 << (63 - self.shift + 1);
    ///       const map = try Self.initCapacity(gpa, capacity * 2);
    ///       // 重新插入所有条目到新表
    ///       var src = self.entries;
    ///       var dst = map.entries;
    ///       while (src != end) {
    ///           const entry = src[0];
    ///           const i = if (!entry.isEmpty()) entry.hash >> map.shift else 0;
    ///           const p = map.entries + i;
    ///           dst = if (@intFromPtr(p) >= @intFromPtr(dst)) p else dst;
    ///           dst[0] = entry;
    ///           src += 1; dst += 1;
    ///       }
    ///       self.entries = map.entries;
    ///       self.shift = map.shift;
    ///   }
    private func grow(): Unit {
        let oldCap = capacity()
        let newCap = oldCap * 2
        let newShift = computeShift(newCap)
        let newOverflow = computeOverflow(newCap, newShift)
        let totalSlots = newCap + newOverflow

        // 保存旧条目
        let oldEntries = entries
        let oldLen = _len

        // 创建新表
        entries = ArrayList<ArrayHashEntry<K, V>>()
        for (_ in 0..totalSlots) {
            entries.append(makeEmptyEntry())
        }
        _len = 0
        shift = newShift

        // 重新插入所有非空条目
        // Zig 的 grow 使用一种特殊的插入方式: 保持有序地复制
        // 简化实现: 逐个 putAssumeCapacity
        var dstIdx: Int64 = 0
        for (srcIdx in 0..oldEntries.size) {
            let entry = oldEntries[srcIdx]
            if (entry.isEmpty()) {
                continue
            }
            let targetIdx = Int64(entry.hash >> UInt64(newShift))
            if (targetIdx > dstIdx) {
                dstIdx = targetIdx
            }
            if (dstIdx < entries.size) {
                entries[dstIdx] = entry
                _len += 1
            }
            dstIdx += 1
        }
    }

    /// 初始化条目数组
    private func initEntries(cap: Int64): Unit {
        let overflow = computeOverflow(cap, shift)
        let totalSlots = cap + overflow
        entries = ArrayList<ArrayHashEntry<K, V>>()
        for (_ in 0..totalSlots) {
            entries.append(makeEmptyEntry())
        }
    }

    /// 创建空条目
    private func makeEmptyEntry(): ArrayHashEntry<K, V> {
        // Zig: Entry{ .hash = empty_hash, .key = undefined, .value = undefined }
        // 仓颉: 使用默认值 (因为空条目的 key/value 不会被读取)
        return ArrayHashEntry<K, V>(default<K>(), defaultValue(), EMPTY_HASH)
    }

    /// 计算当前容量
    private func computeCapacity(): Int64 {
        return Int64(UInt64(1) << UInt64(63 - Int64(shift) + 1))
    }

    // ========================================================================
    // 静态辅助函数 - 对应 Bun comptime 计算
    // ========================================================================

    /// 计算移位量 - 对应 Bun shift 计算
    /// Zig: const shift = 63 - math.log2_int(u64, capacity) + 1
    public static func computeShift(capacity: Int64): UInt8 {
        if (capacity <= 0) { return UInt8(60) }
        var c = capacity
        var log2: Int64 = 0
        while (c > 1) {
            c = c >> 1
            log2 += 1
        }
        return UInt8(63 - log2 + 1)
    }

    /// 计算溢出区大小 - 对应 Bun overflow 计算
    /// Zig: const overflow = capacity / 10 + (63 - @as(u64, shift) + 1) << 1
    /// 注意 Zig 优先级: (a + b) << 1
    public static func computeOverflow(capacity: Int64, shift: UInt8): Int64 {
        let s = Int64(shift)
        return ((capacity / 10) + (63 - s + 1)) << 1
    }

    /// 向上取最近的 2 的幂
    private static func nextPowerOfTwo(n: Int64): Int64 {
        if (n <= 0) { return 1 }
        var v = n - 1
        v = v | (v >> 1)
        v = v | (v >> 2)
        v = v | (v >> 4)
        v = v | (v >> 8)
        v = v | (v >> 16)
        v = v | (v >> 32)
        return v + 1
    }
}

// ============================================================================
// AutoHashMap - 便捷类型别名
// 严格翻译自: src/collections/zig_hash_map.zig
//   Zig: pub fn AutoHashMap(comptime K: type, comptime V: type, ...) type
//   使用 AutoContext 作为默认上下文
// 仓颉: 直接使用 ArrayHashMap<K, V> 即可 (默认就是 AutoContext)
// ============================================================================

/// 自动哈希映射 - 对应 Bun AutoHashMap
/// 使用 AutoHashContext (WyHash + == 比较)
public class AutoHashMap<K, V> where K <: Equatable<K> {
    private var inner: ArrayHashMap<K, V>

    public init() {
        inner = ArrayHashMap<K, V>()
    }

    public init(capacity: Int64) {
        inner = ArrayHashMap<K, V>(capacity)
    }

    public prop size: Int64 {
        get() { inner.size }
    }

    public func isEmpty(): Bool {
        return inner.isEmpty()
    }

    public func put(key: K, value: V): Unit {
        inner.put(key, value)
    }

    public func get(key: K): ?V {
        return inner.get(key)
    }

    public func has(key: K): Bool {
        return inner.has(key)
    }

    public func delete(key: K): ?V {
        return inner.delete(key)
    }

    public func getOrPut(key: K): GetOrPutResult<V> {
        return inner.getOrPut(key)
    }

    public func clear(): Unit {
        inner.clear()
    }

    public func keys(): ArrayList<K> {
        return inner.keys()
    }

    public func values(): ArrayList<V> {
        return inner.values()
    }

    public func forEach(fn: (K, V) -> Unit): Unit {
        inner.forEach(fn)
    }
}

// ============================================================================
// SortedHashMap - 密码学哈希键排序映射
// 严格翻译自: src/collections/zig_hash_map.zig - SortedHashMap
//   Zig:
//     pub fn SortedHashMap(comptime V: type, comptime max_load_percentage: comptime_int) type
//   键为 32 字节密码学哈希，按字典序排序
//   用于内容寻址存储 (如 bundler 模块缓存)
// ============================================================================

/// 排序哈希映射条目 - 对应 Bun SortedHashMap.Entry
/// Zig:
///   pub const Entry = struct {
///       hash: [32]u8 = empty_hash,
///       value: V = undefined,
///   }
class SortedEntry<V> {
    /// 32 字节密码学哈希键
    public var hash: Array<UInt8>
    /// 值
    public var value: V

    /// 空条目标记
    public static let SORTED_EMPTY_HASH: Array<UInt8> = {
        let arr = Array<UInt8>(32, item: UInt8(0xFF))
        return arr
    }()

    public init(hash: Array<UInt8>, value: V) {
        this.hash = hash
        this.value = value
    }

    /// 是否为空 - 对应 Bun SortedEntry.isEmpty
    /// Zig: return cmp(self.hash, empty_hash) == .eq
    public func isEmpty(): Bool {
        return compareHashes(hash, SORTED_EMPTY_HASH) == 0
    }
}

/// 排序哈希映射 - 对应 Bun SortedHashMap
/// 键为 32 字节密码学哈希值，按字典序排列
/// 使用 Robin-Hood 开放寻址，与 HashMap 类似但比较使用字典序
public class SortedHashMap<V> {
    /// 条目数组
    private var entries: ArrayList<SortedEntry<V>>
    /// 当前元素数量
    private var _len: Int64
    /// 移位量
    private var shift: UInt8
    /// 最大负载百分比
    private var maxLoadPercentage: Int64

    public prop size: Int64 {
        get() { _len }
    }

    /// 默认构造 - 初始容量 16
    /// 对应 Bun SortedHashMap.init()
    public init() {
        entries = ArrayList<SortedEntry<V>>()
        _len = 0
        shift = 60  // 1 << 4 = 16
        maxLoadPercentage = DEFAULT_MAX_LOAD_PERCENTAGE
        initEntries(16)
    }

    /// 带初始容量构造 - 对应 Bun SortedHashMap.initCapacity
    /// Zig:
    ///   pub fn initCapacity(gpa: mem.Allocator, capacity: u64) !Self {
    ///       assert(math.isPowerOfTwo(capacity));
    ///       const shift = 63 - math.log2_int(u64, capacity) + 1;
    ///       const overflow = capacity / 10 + (63 - @as(u64, shift) + 1) << 1;
    ///       ...
    ///   }
    public init(capacity: Int64) {
        entries = ArrayList<SortedEntry<V>>()
        _len = 0
        maxLoadPercentage = DEFAULT_MAX_LOAD_PERCENTAGE
        let cap = nextPowerOfTwo(capacity)
        shift = ArrayHashMap<UInt8, UInt8>.computeShift(cap)
        initEntries(cap)
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return _len == 0
    }

    /// 插入 - 对应 Bun SortedHashMap.put
    /// Zig:
    ///   pub fn put(self: *Self, gpa: mem.Allocator, key: [32]u8, value: V) !void {
    ///       try self.ensureUnusedCapacity(gpa, 1);
    ///       self.putAssumeCapacity(key, value);
    ///   }
    public func put(key: Array<UInt8>, value: V): Unit {
        ensureUnusedCapacity(1)
        putAssumeCapacity(key, value)
    }

    /// 假定有容量插入 - 对应 Bun SortedHashMap.putAssumeCapacity
    /// Zig:
    ///   pub fn putAssumeCapacity(self: *Self, key: [32]u8, value: V) void {
    ///       const result = self.getOrPutAssumeCapacity(key);
    ///       if (!result.found_existing) result.value_ptr.* = value;
    ///   }
    public func putAssumeCapacity(key: Array<UInt8>, value: V): Unit {
        let gop = getOrPutAssumeCapacity(key)
        if (!gop.foundExisting) {
            gop.value = value
        }
    }

    /// 获取或插入 - 对应 Bun SortedHashMap.getOrPutAssumeCapacity
    /// Zig: Robin-Hood 探测，使用字典序比较 (cmp)
    public func getOrPutAssumeCapacity(key: Array<UInt8>): GetOrPutResult<V> {
        var it = SortedEntry<V>(key, default<V>())
        var i = sortedIdx(key, shift)
        var insertedAt: ?Int64 = None

        while (i < entries.size) {
            let entry = entries[i]
            let cmp = compareHashes(entry.hash, it.hash)
            // Zig: if (cmp(entry.hash, it.hash).compare(.gte))
            if (cmp >= 0) {
                let keyCmp = compareHashes(entry.hash, key)
                if (keyCmp == 0) {
                    return GetOrPutResult<V>(entry.value, true)
                }
                // Robin-Hood 窃取
                entries[i] = it
                if (entry.isEmpty()) {
                    _len += 1
                    let idx = if (insertedAt != None) { insertedAt } else { i }
                    return GetOrPutResult<V>(entries[Int64(idx)].value, false)
                }
                if (insertedAt == None) {
                    insertedAt = i
                }
                it = entry
            }
            i += 1
        }
        grow()
        return getOrPutAssumeCapacity(key)
    }

    /// 获取值 - 对应 Bun SortedHashMap.get
    /// Zig:
    ///   pub fn get(self: *Self, key: [32]u8) ?V {
    ///       for (self.entries[idx(key, self.shift)..]) |entry| {
    ///           if (cmp(entry.hash, key).compare(.gte)) {
    ///               if (cmp(entry.hash, key) != .eq) return null;
    ///               return entry.value;
    ///           }
    ///       }
    ///   }
    public func get(key: Array<UInt8>): ?V {
        let startIdx = sortedIdx(key, shift)
        var i = startIdx
        while (i < entries.size) {
            let entry = entries[i]
            let cmp = compareHashes(entry.hash, key)
            if (cmp >= 0) {
                if (cmp != 0) {
                    return None
                }
                return Some(entry.value)
            }
            i += 1
        }
        return None
    }

    /// 删除 - 对应 Bun SortedHashMap.delete
    /// Zig: Robin-Hood 删除，与 HashMap 类似但使用 sortedIdx
    public func delete(key: Array<UInt8>): ?V {
        var i = sortedIdx(key, shift)
        // 找到条目
        while (i < entries.size) {
            let entry = entries[i]
            let cmp = compareHashes(entry.hash, key)
            if (cmp >= 0) {
                if (cmp != 0) {
                    return None
                }
                break
            }
            i += 1
        }
        if (i >= entries.size) {
            return None
        }
        let value = entries[i].value

        // 前移
        while (i + 1 < entries.size) {
            let next = entries[i + 1]
            let j = sortedIdx(next.hash, shift)
            if (i < j || next.isEmpty()) {
                break
            }
            entries[i] = next
            i += 1
        }
        entries[i] = makeSortedEmptyEntry()
        _len -= 1
        return Some(value)
    }

    /// 清空但保留容量 - 对应 Bun SortedHashMap.clearRetainingCapacity
    public func clearRetainingCapacity(): Unit {
        for (i in 0..entries.size) {
            entries[i] = makeSortedEmptyEntry()
        }
        _len = 0
    }

    /// 清空
    public func clear(): Unit {
        clearRetainingCapacity()
    }

    /// 确保额外容量
    public func ensureUnusedCapacity(count: Int64): Unit {
        ensureTotalCapacity(_len + count)
    }

    /// 确保总容量
    public func ensureTotalCapacity(count: Int64): Unit {
        var cap = Int64(UInt64(1) << UInt64(63 - Int64(shift) + 1))
        while (count > cap * maxLoadPercentage / 100) {
            grow()
            cap = Int64(UInt64(1) << UInt64(63 - Int64(shift) + 1))
        }
    }

    /// 获取所有条目
    public func forEach(fn: (Array<UInt8>, V) -> Unit): Unit {
        for (i in 0..entries.size) {
            let e = entries[i]
            if (!e.isEmpty()) {
                fn(e.hash, e.value)
            }
        }
    }

    // ---- 内部方法 ----

    /// 扩容
    private func grow(): Unit {
        let oldEntries = entries
        let oldCap = Int64(UInt64(1) << UInt64(63 - Int64(shift) + 1))
        let newCap = oldCap * 2
        let newShift = ArrayHashMap<UInt8, UInt8>.computeShift(newCap)

        shift = newShift
        initEntries(newCap)

        var dstIdx: Int64 = 0
        for (srcIdx in 0..oldEntries.size) {
            let entry = oldEntries[srcIdx]
            if (entry.isEmpty()) {
                continue
            }
            let targetIdx = sortedIdx(entry.hash, newShift)
            if (targetIdx > dstIdx) {
                dstIdx = targetIdx
            }
            if (dstIdx < entries.size) {
                entries[dstIdx] = entry
                _len += 1
            }
            dstIdx += 1
        }
    }

    /// 初始化条目数组
    private func initEntries(cap: Int64): Unit {
        let overflow = ArrayHashMap<UInt8, UInt8>.computeOverflow(cap, shift)
        let totalSlots = cap + overflow
        entries = ArrayList<SortedEntry<V>>()
        for (_ in 0..totalSlots) {
            entries.append(makeSortedEmptyEntry())
        }
    }

    /// 创建排序哈希空条目
    private func makeSortedEmptyEntry(): SortedEntry<V> {
        let emptyHash = Array<UInt8>(32, item: UInt8(0xFF))
        return SortedEntry<V>(emptyHash, default<V>())
    }

    /// 计算排序哈希的索引 - 对应 Bun SortedHashMap.idx
    /// Zig:
    ///   fn idx(a: [32]u8, shift: u6) usize {
    ///       return @as(usize, @intCast(mem.readIntBig(u64, a[0..8]) >> shift));
    ///   }
    /// 读取前 8 字节 (大端序 u64)，右移 shift
    public static func sortedIdx(hash: Array<UInt8>, shift: UInt8): Int64 {
        if (hash.size < 8) { return 0 }
        // 大端序读取前 8 字节
        let msb = UInt64(hash[0]) << UInt64(56) |
                  UInt64(hash[1]) << UInt64(48) |
                  UInt64(hash[2]) << UInt64(40) |
                  UInt64(hash[3]) << UInt64(32) |
                  UInt64(hash[4]) << UInt64(24) |
                  UInt64(hash[5]) << UInt64(16) |
                  UInt64(hash[6]) << UInt64(8) |
                  UInt64(hash[7])
        return Int64(msb >> UInt64(shift))
    }

    /// 比较两个 32 字节哈希 - 对应 Bun SortedHashMap.cmp
    /// Zig:
    ///   fn cmp(a: [32]u8, b: [32]u8) math.Order {
    ///       // 优化: 假设密码学哈希，如果前 64 位不同则大概率不同
    ///       const msa = @as(u64, @bitCast(a[0..8].*));
    ///       const msb = @as(u64, @bitCast(b[0..8].*));
    ///       if (msa != msb) {
    ///           return if (mem.bigToNative(u64, msa) < mem.bigToNative(u64, msb)) .lt else .gt;
    ///       } else if (@reduce(.And, a == b)) {
    ///           return .eq;
    ///       } else {
    ///           // 比较后续 8 字节块
    ///       }
    ///   }
    /// 返回: -1 (a < b), 0 (a == b), 1 (a > b)
    public static func compareHashes(a: Array<UInt8>, b: Array<UInt8>): Int64 {
        if (a.size < 32 || b.size < 32) {
            // 简短哈希: 直接字节比较
            let minLen = if (a.size < b.size) { a.size } else { b.size }
            for (i in 0..minLen) {
                if (a[i] < b[i]) { return -1 }
                if (a[i] > b[i]) { return 1 }
            }
            if (a.size < b.size) { return -1 }
            if (a.size > b.size) { return 1 }
            return 0
        }

        // 读取前 8 字节 (大端序)
        let msa = readBE64(a, 0)
        let msb = readBE64(b, 0)

        if (msa != msb) {
            return if (msa < msb) { Int64(-1) } else { Int64(1) }
        }

        // 完全比较
        var allEqual = true
        for (i in 0..32) {
            if (a[i] != b[i]) {
                allEqual = false
                break
            }
        }
        if (allEqual) { return 0 }

        // 比较后续 8 字节块 (大端序)
        let a8 = readBE64(a, 8)
        let b8 = readBE64(b, 8)
        if (a8 != b8) {
            return if (a8 < b8) { Int64(-1) } else { Int64(1) }
        }
        let a16 = readBE64(a, 16)
        let b16 = readBE64(b, 16)
        if (a16 != b16) {
            return if (a16 < b16) { Int64(-1) } else { Int64(1) }
        }
        let a24 = readBE64(a, 24)
        let b24 = readBE64(b, 24)
        if (a24 != b24) {
            return if (a24 < b24) { Int64(-1) } else { Int64(1) }
        }
        return 0
    }

    /// 大端序读取 8 字节为 UInt64
    private static func readBE64(arr: Array<UInt8>, offset: Int64): UInt64 {
        return UInt64(arr[offset]) << UInt64(56) |
               UInt64(arr[offset + 1]) << UInt64(48) |
               UInt64(arr[offset + 2]) << UInt64(40) |
               UInt64(arr[offset + 3]) << UInt64(32) |
               UInt64(arr[offset + 4]) << UInt64(24) |
               UInt64(arr[offset + 5]) << UInt64(16) |
               UInt64(arr[offset + 6]) << UInt64(8) |
               UInt64(arr[offset + 7])
    }

    /// 向上取最近的 2 的幂
    private static func nextPowerOfTwo(n: Int64): Int64 {
        if (n <= 0) { return 1 }
        var v = n - 1
        v = v | (v >> 1)
        v = v | (v >> 2)
        v = v | (v >> 4)
        v = v | (v >> 8)
        v = v | (v >> 16)
        v = v | (v >> 32)
        return v + 1
    }
}
