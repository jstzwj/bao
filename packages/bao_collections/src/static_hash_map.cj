// bao_collections - StaticHashMap 编译期/静态哈希表
// 严格翻译自: src/collections/StaticHashMap.zig (StaticHashMap + HashMap + SortedHashMap)
//   Bun 使用 Robin-Hood 开放寻址哈希，条目按哈希值排序存储
//   StaticHashMap: 固定容量的栈上哈希表
//   HashMap: 堆上动态扩容的哈希表
//   两者共享 HashMapMixin 中的所有方法
//   仓颉实现保持相同的 Robin-Hood 算法和 API
package bao_collections

import bao_core.*
import bao_hash.*

// ============================================================================
// 常量 - 对应 Bun StaticHashMap.zig / zig_hash_map.zig
//   const empty_hash = math.maxInt(u64); // 0xFFFFFFFFFFFFFFFF
//   用于标记空条目
// ============================================================================

/// 空条目标记哈希 - 对应 Bun empty_hash = math.maxInt(u64)
/// Zig: const empty_hash = math.maxInt(u64)
/// 当 Entry.hash == STATIC_EMPTY_HASH 时表示该槽位为空
private let STATIC_EMPTY_HASH: UInt64 = UInt64.MAX

/// Robin-Hood 哈希默认最大负载百分比
/// Zig: max_load_percentage comptime_int (典型值 50)
private let STATIC_DEFAULT_MAX_LOAD_PERCENTAGE: Int64 = 50

// ============================================================================
// StaticHashEntry<K, V> - 静态哈希表条目
// 严格翻译自: src/collections/StaticHashMap.zig - HashMap.Entry
//   Zig:
//     pub const Entry = struct {
//         hash: u64 = empty_hash,
//         key: K = std.mem.zeroes(K),
//         value: V = std.mem.zeroes(V),
//         pub fn isEmpty(self: Entry) bool { return self.hash == empty_hash; }
//     };
// ============================================================================

/// 静态哈希表条目 - 对应 Bun StaticHashMap.Entry
/// hash == STATIC_EMPTY_HASH 表示空槽位
public class StaticHashEntry<K, V> {
    /// 哈希值 - 对应 Bun Entry.hash
    /// Zig: hash: u64 = empty_hash
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

    /// 创建空条目 - 对应 Zig Entry{} 默认值
    /// Zig: hash: u64 = empty_hash, key = zeroes(K), value = zeroes(V)
    public static func empty<K2, V2>(): StaticHashEntry<K2, V2> {
        return StaticHashEntry<K2, V2>(default<K2>(), default<V2>(), STATIC_EMPTY_HASH)
    }

    /// 是否为空槽位 - 对应 Bun Entry.isEmpty
    /// Zig: pub fn isEmpty(self: Entry) bool { return self.hash == empty_hash; }
    public func isEmpty(): Bool {
        return hash == STATIC_EMPTY_HASH
    }
}

// ============================================================================
// StaticGetOrPutResult<V> - 获取或插入结果
// 严格翻译自: src/collections/StaticHashMap.zig - HashMap.GetOrPutResult
//   Zig:
//     pub const GetOrPutResult = struct {
//         value_ptr: *V,
//         found_existing: bool,
//     };
//   仓颉: 因为没有裸指针，使用值 + 布尔标记
// ============================================================================

/// 获取或插入的结果 - 对应 Bun HashMap.GetOrPutResult
public class StaticGetOrPutResult<V> {
    /// 值引用
    public var value: V
    /// 是否已存在
    public var foundExisting: Bool

    public init(value: V, foundExisting: Bool) {
        this.value = value
        this.foundExisting = foundExisting
    }
}

// ============================================================================
// StaticHashMap<K, V> - 静态容量 Robin-Hood 哈希表
// 严格翻译自: src/collections/StaticHashMap.zig - StaticHashMap
//   pub fn StaticHashMap(comptime K: type, comptime V: type, comptime Context: type, comptime capacity: usize) type
//
// Bun 设计:
//   1. 固定容量 (编译期确定，Zig 使用 comptime capacity)
//      仓颉: 运行时确定，构造后不可扩容
//   2. Robin-Hood 开放寻址哈希
//   3. entries 数组大小 = capacity + overflow
//      overflow = (capacity / 10 + (63 - shift + 1)) << 1
//   4. shift 控制哈希到桶的映射:
//      capacity = 1 << (63 - shift + 1)
//      桶索引 = hash >> shift
//   5. 与 HashMap 共享 HashMapMixin 中的所有方法
//
// Zig: entries: [capacity + overflow]Entry = [_]Entry{.{}} ** (capacity + overflow)
// 仓颉: entries: ArrayList<StaticHashEntry<K, V>> (运行时分配)
// ============================================================================

/// 静态容量 Robin-Hood 哈希表 - 对应 Bun StaticHashMap
/// 固定容量，构造后不可扩容
/// 使用 Robin-Hood 探测策略，条目按哈希值排序
///
/// Zig StaticHashMap 参数:
///   comptime K: type         - 键类型
///   comptime V: type         - 值类型
///   comptime Context: type   - 哈希上下文
///   comptime capacity: usize - 固定容量 (必须是 2 的幂)
public class StaticHashMap<K, V> where K <: Equatable<K> {
    /// 条目数组 - 对应 Bun entries: [capacity + overflow]Entry
    private var entries: ArrayList<StaticHashEntry<K, V>>
    /// 当前元素数量 - 对应 Bun len
    private var _len: Int64
    /// 移位量 - 对应 Bun shift: u6
    private var shift: UInt8
    /// 哈希上下文 - 对应 Bun context
    private var ctx: HashContext<K>

    /// 元素数量
    public prop size: Int64 {
        get() { _len }
    }

    /// 构造指定容量的静态哈希表 - 对应 Bun StaticHashMap 初始化
    /// Zig: entries: [capacity + overflow]Entry = [_]Entry{.{}} ** ...
    /// capacity 必须是 2 的幂
    public init(capacity: Int64) {
        entries = ArrayList<StaticHashEntry<K, V>>()
        _len = 0
        ctx = AutoHashContext<K>()
        let cap = staticNextPowerOfTwo(capacity)
        shift = staticComputeShift(cap)
        let overflow = staticComputeOverflow(cap, shift)
        let totalSlots = cap + overflow
        for (_ in 0..totalSlots) {
            entries.append(StaticHashEntry<K, V>(default<K>(), default<V>(), STATIC_EMPTY_HASH))
        }
    }

    /// 带哈希上下文构造
    public init(capacity: Int64, ctx: HashContext<K>) {
        entries = ArrayList<StaticHashEntry<K, V>>()
        _len = 0
        this.ctx = ctx
        let cap = staticNextPowerOfTwo(capacity)
        shift = staticComputeShift(cap)
        let overflow = staticComputeOverflow(cap, shift)
        let totalSlots = cap + overflow
        for (_ in 0..totalSlots) {
            entries.append(StaticHashEntry<K, V>(default<K>(), default<V>(), STATIC_EMPTY_HASH))
        }
    }

    // ========================================================================
    // 容量与状态查询
    // ========================================================================

    /// 是否为空
    public func isEmpty(): Bool {
        return _len == 0
    }

    /// 当前容量 - 对应 Bun capacity
    /// capacity = 1 << (63 - shift + 1)
    public func capacity(): Int64 {
        return Int64(UInt64(1) << UInt64(63 - Int64(shift) + 1))
    }

    /// 获取底层条目切片 - 对应 Bun HashMap.slice()
    public func slice(): ArrayList<StaticHashEntry<K, V>> {
        return entries
    }

    // ========================================================================
    // 插入操作 - 对应 Bun HashMapMixin.putAssumeCapacity
    //   StaticHashMap 没有 grow，只有 putAssumeCapacity
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

    // ========================================================================
    // 获取或插入 - 对应 Bun HashMapMixin.getOrPutAssumeCapacity
    //   Robin-Hood 探测的核心算法
    // ========================================================================

    /// 获取或插入 - 对应 Bun getOrPutAssumeCapacity
    /// Robin-Hood 探测: 条目按 hash 排序
    /// 当新 hash < 已有条目 hash 时，交换 (窃取更近的位置)
    public func getOrPutAssumeCapacity(key: K): StaticGetOrPutResult<V> {
        let h = ctx.hash(key)
        if (h == STATIC_EMPTY_HASH) {
            let entry = StaticHashEntry<K, V>(key, default<V>(), STATIC_EMPTY_HASH)
            entries.append(entry)
            _len += 1
            return StaticGetOrPutResult<V>(default<V>(), false)
        }

        var it = StaticHashEntry<K, V>(key, default<V>(), h)
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
                    return StaticGetOrPutResult<V>(entry.value, true)
                }
                // Robin-Hood: 窃取位置
                entries[i] = it
                // Zig: if (entry.isEmpty())
                if (entry.isEmpty()) {
                    _len += 1
                    let idx = if (insertedAt != None) { insertedAt } else { i }
                    return StaticGetOrPutResult<V>(entries[Int64(idx)].value, false)
                }
                // Zig: if (inserted_at == null) inserted_at = i
                if (insertedAt == None) {
                    insertedAt = i
                }
                it = entry  // 继续探测被踢出的条目
            }
            i += 1
        }
        // 溢出: 不应到达这里 (StaticHashMap 容量不足)
        // 简化处理: 追加到末尾
        entries.append(it)
        _len += 1
        return StaticGetOrPutResult<V>(default<V>(), false)
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
        if (h == STATIC_EMPTY_HASH) {
            return None
        }
        let startIdx = Int64(h >> UInt64(shift))
        var i = startIdx
        while (i < entries.size) {
            let entry = entries[i]
            if (entry.hash >= h) {
                if (!ctx.eql(entry.key, key)) {
                    return None
                }
                return Some(entry.value)
            }
            i += 1
        }
        return None
    }

    /// 按上下文获取 - 对应 Bun HashMapMixin.getContext
    public func getContext(key: K, ctx: HashContext<K>): ?V {
        let h = ctx.hash(key)
        if (h == STATIC_EMPTY_HASH) {
            return None
        }
        let startIdx = Int64(h >> UInt64(shift))
        var i = startIdx
        while (i < entries.size) {
            let entry = entries[i]
            if (entry.hash >= h) {
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
    public func has(key: K): Bool {
        let h = ctx.hash(key)
        if (h == STATIC_EMPTY_HASH) {
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
        if (keyHash == STATIC_EMPTY_HASH) {
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

    /// 按上下文检查 - 对应 Bun HashMapMixin.hasContext
    public func hasContext(key: K, ctx: HashContext<K>): Bool {
        let h = ctx.hash(key)
        if (h == STATIC_EMPTY_HASH) {
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

    // ========================================================================
    // 删除操作 - 对应 Bun HashMapMixin.delete
    //   Robin-Hood 删除: 移除条目后，将后续条目前移填补空隙
    // ========================================================================

    /// 删除键值对并返回值 - 对应 Bun HashMapMixin.delete
    /// Zig:
    ///   pub fn delete(self: *Self, key: K) ?V {
    ///       const hash = ctx.hash(key);
    ///       var i = hash >> self.shift;
    ///       while (true) : (i += 1) {
    ///           const entry = self.entries[i];
    ///           if (entry.hash >= hash) {
    ///               if (!ctx.eql(entry.key, key)) return null;
    ///               break;
    ///           }
    ///       }
    ///       const value = self.entries[i].value;
    ///       while (true) : (i += 1) {
    ///           const j = self.entries[i + 1].hash >> self.shift;
    ///           if (i < j || self.entries[i + 1].isEmpty()) break;
    ///           self.entries[i] = self.entries[i + 1];
    ///       }
    ///       self.entries[i] = .{};
    ///       self.len -= 1;
    ///       return value;
    ///   }
    public func delete(key: K): ?V {
        let h = ctx.hash(key)
        if (h == STATIC_EMPTY_HASH) {
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
                break
            }
            i += 1
        }
        if (i >= entries.size) {
            return None
        }
        let value = entries[i].value

        // 前移后续条目 - Robin-Hood 删除
        while (i + 1 < entries.size) {
            let next = entries[i + 1]
            let j = Int64(next.hash >> UInt64(shift))
            if (i < j || next.isEmpty()) {
                break
            }
            entries[i] = next
            i += 1
        }
        // 清空最终位置
        entries[i] = StaticHashEntry<K, V>(default<K>(), default<V>(), STATIC_EMPTY_HASH)
        _len -= 1

        return Some(value)
    }

    /// 按上下文删除 - 对应 Bun HashMapMixin.deleteContext
    public func deleteContext(key: K, ctx: HashContext<K>): ?V {
        let h = ctx.hash(key)
        if (h == STATIC_EMPTY_HASH) {
            return None
        }
        var i = Int64(h >> UInt64(shift))
        while (i < entries.size) {
            let entry = entries[i]
            if (entry.hash >= h) {
                if (!ctx.eql(entry.key, key)) {
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

        while (i + 1 < entries.size) {
            let next = entries[i + 1]
            let j = Int64(next.hash >> UInt64(shift))
            if (i < j || next.isEmpty()) {
                break
            }
            entries[i] = next
            i += 1
        }
        entries[i] = StaticHashEntry<K, V>(default<K>(), default<V>(), STATIC_EMPTY_HASH)
        _len -= 1
        return Some(value)
    }

    // ========================================================================
    // 清空 - 对应 Bun HashMapMixin.clearRetainingCapacity
    // ========================================================================

    /// 清空但保留容量 - 对应 Bun HashMapMixin.clearRetainingCapacity
    /// Zig:
    ///   pub fn clearRetainingCapacity(self: *Self) void {
    ///       @memset(self.slice(), .{});
    ///       self.len = 0;
    ///   }
    public func clearRetainingCapacity(): Unit {
        for (i in 0..entries.size) {
            entries[i] = StaticHashEntry<K, V>(default<K>(), default<V>(), STATIC_EMPTY_HASH)
        }
        _len = 0
    }

    /// 清空
    public func clear(): Unit {
        clearRetainingCapacity()
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
    // 静态辅助函数 - 对应 Bun comptime 计算
    // ========================================================================

    /// 计算移位量 - 对应 Bun shift 计算
    /// Zig: const shift = 63 - math.log2_int(u64, capacity) + 1
    public static func staticComputeShift(capacity: Int64): UInt8 {
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
    public static func staticComputeOverflow(capacity: Int64, shift: UInt8): Int64 {
        let s = Int64(shift)
        return ((capacity / 10) + (63 - s + 1)) << 1
    }

    /// 向上取最近的 2 的幂
    private static func staticNextPowerOfTwo(n: Int64): Int64 {
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
// AutoStaticHashMap - 便捷类型别名
// 严格翻译自: src/collections/StaticHashMap.zig
//   Zig: pub fn AutoStaticHashMap(comptime K: type, comptime V: type, comptime capacity: usize) type
//   使用 AutoContext 作为默认上下文
// 仓颉: 直接使用 StaticHashMap<K, V> 即可 (默认就是 AutoContext)
// ============================================================================

/// 自动静态哈希映射 - 对应 Bun AutoStaticHashMap
/// 使用 AutoHashContext (WyHash + == 比较)
public class AutoStaticHashMap<K, V> where K <: Equatable<K> {
    private var inner: StaticHashMap<K, V>

    public init(capacity: Int64) {
        inner = StaticHashMap<K, V>(capacity)
    }

    public prop size: Int64 {
        get() { inner.size }
    }

    public func isEmpty(): Bool {
        return inner.isEmpty()
    }

    public func putAssumeCapacity(key: K, value: V): Unit {
        inner.putAssumeCapacity(key, value)
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

    public func getOrPutAssumeCapacity(key: K): StaticGetOrPutResult<V> {
        return inner.getOrPutAssumeCapacity(key)
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
// StaticHashMap 的静态辅助函数 - 计算 total slots
// 严格翻译自: src/collections/StaticHashMap.rs - static_slots()
//   pub const fn static_slots(capacity: usize) -> usize {
//       let shift = compute_shift(capacity as u64);
//       let overflow = compute_overflow(capacity as u64, shift);
//       capacity + overflow as usize
//   }
// ============================================================================

/// 计算静态哈希表的总槽位数 - 对应 Bun static_slots()
/// 用于在编译期/运行时确定 entries 数组的大小
/// capacity 必须是 2 的幂
public func staticHashSlots(capacity: Int64): Int64 {
    let shift = StaticHashMap<Int64, Int64>.staticComputeShift(capacity)
    let overflow = StaticHashMap<Int64, Int64>.staticComputeOverflow(capacity, shift)
    return capacity + overflow
}
