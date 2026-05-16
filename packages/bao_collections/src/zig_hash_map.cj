// bao_collections - ZigHashMap 开放寻址哈希表 (线性探测 + 墓碑删除)
// 严格翻译自: src/collections/zig_hash_map.rs
//   pub struct HashMap<K, V, C = AutoHashContext> {
//       metadata: Vec<u8>,
//       slots: Vec<Option<(K, V)>>,
//       size: u32,
//       available: u32,
//       _ctx: PhantomData<C>,
//   }
//
// Bun 设计 (移植自 Zig std.HashMapUnmanaged):
//   1. 开放寻址线性探测
//   2. 墓碑标记删除 (SLOT_FREE=0x00, SLOT_TOMBSTONE=0x01)
//   3. 2 的幂容量
//   4. 80% 最大负载因子
//   5. 元数据字节: bit7=used, bits0..6=fingerprint
//   6. fingerprint = hash >> 57 (top 7 bits)
//   7. 迭代顺序与 Zig 规范一致 (因为某些调用者快照迭代序列)
//
//   存储: metadata: Vec<u8> + slots: Vec<Option<(K, V)>>
//   与 Zig 的单分配 [Header][meta][keys][values] 不同
//   但 slot 索引和元数据状态机位一致，因此迭代顺序匹配
//
// Spec: vendor/zig/lib/std/hash_map.zig
package bao_collections

import bao_core.*
import bao_hash.*

// ============================================================================
// 元数据字节常量 - 对应 Bun zig_hash_map.rs
//   Zig: packed struct { fingerprint: u7, used: u1 }
//   LSB-first packing: bit 7 = used, bits 0..6 = fingerprint
// ============================================================================

/// 空槽位 - 对应 Bun SLOT_FREE
/// Zig: used=0, fp=0
private let SLOT_FREE: UInt8 = UInt8(0x00)

/// 墓碑标记 - 对应 Bun SLOT_TOMBSTONE
/// Zig: used=0, fp=1
private let SLOT_TOMBSTONE: UInt8 = UInt8(0x01)

/// 最小容量 - 对应 Bun MINIMAL_CAPACITY = 8
/// Zig: const min = @max(8, ...)
private let MINIMAL_CAPACITY: UInt32 = UInt32(8)

/// 最大负载百分比 - 对应 Bun MAX_LOAD_PERCENTAGE = 80
/// Zig: default_max_load_percentage = 80
private let MAX_LOAD_PERCENTAGE: UInt64 = UInt64(80)

// ============================================================================
// 元数据辅助函数 - 对应 Bun zig_hash_map.rs 内联函数
// ============================================================================

/// 检查槽位是否被占用 - 对应 Bun meta_is_used
/// Zig: bit 7 = used
private func metaIsUsed(m: UInt8): Bool {
    return (m & UInt8(0x80)) != UInt8(0)
}

/// 检查槽位是否为空 - 对应 Bun meta_is_free
private func metaIsFree(m: UInt8): Bool {
    return m == SLOT_FREE
}

/// 检查槽位是否为墓碑 - 对应 Bun meta_is_tombstone
private func metaIsTombstone(m: UInt8): Bool {
    return m == SLOT_TOMBSTONE
}

/// 获取指纹 - 对应 Bun meta_fingerprint
/// Zig: bits 0..6 = fingerprint
private func metaFingerprint(m: UInt8): UInt8 {
    return m & UInt8(0x7F)
}

/// 取哈希值的指纹 - 对应 Bun take_fingerprint
/// Zig: top 7 bits of the 64-bit hash
/// Metadata.takeFingerprint: hash >> (64 - 7)
private func takeFingerprint(hash: UInt64): UInt8 {
    return UInt8(hash >> UInt64(57))
}

/// 构建占用元数据 - 对应 Bun meta_fill
/// Zig: 0x80 | (fp & 0x7F) - 设置 used 位和指纹
private func metaFill(fp: UInt8): UInt8 {
    return UInt8(0x80) | (fp & UInt8(0x7F))
}

/// 计算所需容量 - 对应 Bun capacity_for_size
/// Zig: ((size * 100) / max_load + 1).ceilPowerOfTwo()
private func capacityForSize(size: UInt32): UInt32 {
    let newCap = UInt32((UInt64(size) * UInt64(100)) / MAX_LOAD_PERCENTAGE + UInt64(1))
    return nextPowerOfTwo(newCap)
}

/// 向上取最近的 2 的幂
private func nextPowerOfTwo(n: UInt32): UInt32 {
    if (n <= 1) { return 1 }
    var v = n - 1
    v = v | (v >> 1)
    v = v | (v >> 2)
    v = v | (v >> 4)
    v = v | (v >> 8)
    v = v | (v >> 16)
    return v + 1
}

// ============================================================================
// ZigHashEntry<K, V> - 哈希表条目
// 对应 Bun zig_hash_map.rs 中的 Option<(K, V)>
// ============================================================================

/// 哈希表槽位 - 模拟 Rust Option<(K, V)>
class ZigHashEntry<K, V> {
    /// 键
    public var key: ?K
    /// 值
    public var value: ?V
    /// 是否占用
    public var occupied: Bool

    public init() {
        key = Option<K>.None
        value = Option<V>.None
        occupied = false
    }

    public init(key: K, value: V) {
        this.key = Some(key)
        this.value = Some(value)
        this.occupied = true
    }
}

// ============================================================================
// ZigGetOrPutResult<V> - 获取或插入结果
// 严格翻译自: zig_hash_map.rs - GetOrPutResult
//   pub struct GetOrPutResult<'a, V> {
//       pub found_existing: bool,
//       pub value_ptr: &'a mut V,
//   }
// ============================================================================

/// 获取或插入的结果 - 对应 Bun GetOrPutResult
/// Zig 返回 *V 指针; 仓颉使用索引 + 引用语义容器模拟
public class ZigGetOrPutResult<V> {
    /// 值
    public var value: ?V
    /// 是否已存在
    public var foundExisting: Bool
    /// 槽位索引 (内部使用)
    public var slotIndex: Int64

    public init(value: ?V, foundExisting: Bool, slotIndex: Int64) {
        this.value = value
        this.foundExisting = foundExisting
        this.slotIndex = slotIndex
    }
}

// ============================================================================
// ZigKV<K, V> - 键值对
// 严格翻译自: zig_hash_map.rs - KV<K, V>
//   pub struct KV<K, V> { pub key: K, pub value: V }
// ============================================================================

/// 键值对 - 对应 Bun KV<K, V>
/// Zig: fetchRemove 返回的 {key, value} 对
public class ZigKV<K, V> {
    public var key: K
    public var value: V

    public init(key: K, value: V) {
        this.key = key
        this.value = value
    }
}

// ============================================================================
// ZigHashMap<K, V> - 开放寻址线性探测哈希表
// 严格翻译自: src/collections/zig_hash_map.rs - HashMap<K, V, C>
//
// Bun/Zig 设计:
//   1. 开放寻址 + 线性探测
//      - 从 hash % capacity 开始，逐个探测
//      - 遇到 free 停止 (跳过 tombstone)
//   2. 墓碑删除
//      - 删除时标记为 SLOT_TOMBSTONE
//      - 墓碑不停止探测，但可被新条目复用
//   3. 2 的幂容量
//      - 使用 hash & (cap - 1) 替代取模
//      - 扩容时容量翻倍
//   4. 80% 最大负载因子
//      - 当 size + 新条目 > cap * 80% 时扩容
//   5. 元数据字节
//      - 每个槽位 1 字节元数据
//      - bit7 = used, bits0..6 = fingerprint
//      - fingerprint = hash >> 57 (高 7 位)
//      - 用于快速过滤不匹配的键
//
//   存储: metadata: Array<UInt8> + slots: ArrayList<ZigHashEntry<K, V>>
//   与 Zig 的 [Header][meta][keys][values] 布局不同
//   但索引和元数据状态机位一致
//
// Spec: vendor/zig/lib/std/hash_map.zig
// ============================================================================

/// 开放寻址线性探测哈希表 - 对应 Bun HashMap<K, V, C>
/// 使用线性探测 + 墓碑删除 + 2的幂容量 + 80%最大负载
///
/// Zig HashMap 参数:
///   K: type         - 键类型
///   V: type         - 值类型
///   C: type         - 哈希上下文 (仓颉中内置)
///   max_load_percentage: 80
public class ZigHashMap<K, V> where K <: Hashable & Equatable<K> & ToString {
    /// 元数据数组 - 对应 Bun metadata: Vec<u8>
    /// 每个槽位一个字节: bit7=used, bits0..6=fingerprint
    private var metadata: Array<UInt8>
    /// 槽位数组 - 对应 Bun slots: Vec<Option<(K, V)>>
    private var slots: ArrayList<ZigHashEntry<K, V>>
    /// 当前元素数量 - 对应 Bun size: u32
    private var _size: UInt32
    /// 可用槽位 (含空闲和墓碑消耗) - 对应 Bun available: u32
    private var available: UInt32

    /// 元素数量 - 对应 Bun HashMap.len / count
    public prop size: Int64 {
        get() { Int64(_size) }
    }

    /// 默认构造 - 空表
    /// 对应 Bun HashMap::default()
    public init() {
        metadata = []
        slots = ArrayList<ZigHashEntry<K, V>>()
        _size = 0
        available = 0
    }

    /// 带初始容量构造 - 对应 Bun HashMap::with_capacity
    /// Zig: pub fn initCapacity(capacity: usize) !Self
    public init(capacity: Int64) {
        metadata = []
        slots = ArrayList<ZigHashEntry<K, V>>()
        _size = 0
        available = 0
        if (capacity > 0) {
            ensureTotalCapacity(capacity)
        }
    }

    // ========================================================================
    // 基本查询 - 对应 Bun HashMap 公共查询方法
    // ========================================================================

    /// 元素数量 - 对应 Bun HashMap.len
    /// Zig: pub fn len() -> usize / pub fn count() -> u32
    public func len(): Int64 {
        return Int64(_size)
    }

    /// 元素数量 (UInt32) - 对应 Bun HashMap.count
    public func count(): UInt32 {
        return _size
    }

    /// 是否为空 - 对应 Bun HashMap.is_empty
    public func isEmpty(): Bool {
        return _size == 0
    }

    /// 当前容量 - 对应 Bun HashMap.capacity
    /// Zig: metadata.len() (元数据数组长度 == 槽位数量)
    public func capacity(): Int64 {
        return metadata.size
    }

    // ========================================================================
    // 生命周期操作
    // ========================================================================

    /// 释放存储 - 对应 Bun HashMap.deinit
    /// Zig: pub fn deinit(self: *Self) void
    public func deinit(): Unit {
        metadata = []
        slots = ArrayList<ZigHashEntry<K, V>>()
        _size = 0
        available = 0
    }

    /// 清空但保留容量 - 对应 Bun HashMap.clear
    /// Zig: pub fn clearRetainingCapacity(self: *Self) void
    public func clearRetainingCapacity(): Unit {
        if (metadata.size == 0) {
            return
        }
        for (i in 0..metadata.size) {
            metadata[i] = SLOT_FREE
        }
        for (i in 0..slots.size) {
            slots[Int64(i)].occupied = false
        }
        _size = 0
        available = UInt32((UInt64(metadata.size) * MAX_LOAD_PERCENTAGE) / UInt64(100))
    }

    /// 清空
    public func clear(): Unit {
        clearRetainingCapacity()
    }

    /// 锁定指针 - 对应 Bun HashMap.lock_pointers
    /// Zig: debug-mode pointer-stability assertion. No-op stub
    public func lockPointers(): Unit {}

    /// 解锁指针 - 对应 Bun HashMap.unlock_pointers
    public func unlockPointers(): Unit {}

    // ========================================================================
    // 容量管理 - 对应 Bun HashMap.ensureTotalCapacity / ensureUnusedCapacity
    // ========================================================================

    /// 带初始容量创建 - 对应 Bun HashMap::with_capacity
    /// Zig: pub fn ensureTotalCapacity(self, new_size) !void
    public static func withCapacity(capacity: Int64): ZigHashMap<K, V> {
        let m = ZigHashMap<K, V>()
        if (capacity > 0) {
            m.ensureTotalCapacity(capacity)
        }
        return m
    }

    /// 确保总容量 - 对应 Bun HashMap.ensure_total_capacity
    /// Zig: pub fn ensureTotalCapacity(self, new_size) !void
    ///   grow so new_size elements fit without further allocation
    public func ensureTotalCapacity(newSize: Int64): Unit {
        let ns = UInt32(newSize)
        if (ns > _size) {
            growIfNeeded(ns - _size)
        }
    }

    /// 确保额外容量 - 对应 Bun HashMap.ensure_unused_capacity
    /// Zig: pub fn ensureUnusedCapacity(self, additional) !void
    public func ensureUnusedCapacity(additional: Int64): Unit {
        ensureTotalCapacity(Int64(_size) + additional)
    }

    /// 预留空间 - 对应 Bun HashMap.reserve
    /// std HashMap alias of ensure_unused_capacity
    public func reserve(additional: Int64): Unit {
        ensureUnusedCapacity(additional)
    }

    // ========================================================================
    // 查询操作 - 对应 Bun HashMap.get / get_mut / contains_key
    // ========================================================================

    /// 获取值 - 对应 Bun HashMap.get
    /// Zig:
    ///   pub fn get(self, key) ?V {
    ///       probe for key, stop on free, skip tombstones
    ///   }
    public func get(key: K): ?V {
        let idx = getIndex(key)
        if (idx >= 0) {
            let slot = slots[idx]
            if (slot.occupied) {
                return Some(slot.value.getOrThrow())
            }
        }
        return None
    }

    /// 是否包含键 - 对应 Bun HashMap.contains_key
    /// Zig: pub fn contains(self, key) bool
    public func containsKey(key: K): Bool {
        return getIndex(key) >= 0
    }

    /// 别名 - 对应 Bun HashMap.contains
    public func contains(key: K): Bool {
        return getIndex(key) >= 0
    }

    /// 获取键值对 - 对应 Bun HashMap.get_key_value
    /// Zig: returns Option<(&K, &V)>
    public func getKeyValue(key: K): ?(K, V) {
        let idx = getIndex(key)
        if (idx >= 0) {
            let slot = slots[idx]
            if (slot.occupied) {
                return Some((slot.key.getOrThrow(), slot.value.getOrThrow()))
            }
        }
        return None
    }

    // ========================================================================
    // 插入操作 - 对应 Bun HashMap.insert / put / get_or_put
    // ========================================================================

    /// 插入/更新键值对 - 对应 Bun HashMap.insert
    /// Zig: fetchPut — returns the previous value if any
    /// Rust:
    ///   pub fn insert(&mut self, key: K, value: V) -> Option<V>
    public func insert(key: K, value: V): ?V {
        let (idx, foundExisting) = getOrPutSlot(key)
        if (foundExisting) {
            let slot = slots[idx]
            let oldValue = slot.value.getOrThrow()
            slot.value = Some(value)
            return Some(oldValue)
        } else {
            let slot = slots[idx]
            slot.key = Some(key)
            slot.value = Some(value)
            slot.occupied = true
            return None
        }
    }

    /// 插入别名 - 对应 Bun HashMap.put
    /// Zig: pub fn put(self, key, value) !void { self.insert(key, value); }
    public func put(key: K, value: V): Unit {
        insert(key, value)
    }

    /// 插入不覆盖 - 对应 Bun HashMap.put_no_clobber
    /// Zig: pub fn putNoClobber(self, key, value) !void
    ///   asserts key is new
    public func putNoClobber(key: K, value: V): Unit {
        let prev = insert(key, value)
        // debug_assert!(prev.is_none(), "putNoClobber: key already present")
    }

    /// 获取或插入 - 对应 Bun HashMap.get_or_put
    /// Zig: getOrPut — single-probe insert-or-lookup
    /// Rust:
    ///   pub fn get_or_put(&mut self, key: K) -> Result<GetOrPutResult<'_, V>, AllocError>
    public func getOrPut(key: K): ZigGetOrPutResult<V> {
        let (idx, foundExisting) = getOrPutSlot(key)
        if (!foundExisting) {
            let slot = slots[idx]
            slot.key = Some(key)
            slot.value = Option<V>.None
            slot.occupied = true
        }
        let slot = slots[idx]
        return ZigGetOrPutResult<V>(slot.value, foundExisting, idx)
    }

    /// 获取或插入 (带上下文) - 对应 Bun HashMap.get_or_put_context
    /// 仓颉: 上下文已绑定在类型中，忽略 ctx 参数
    public func getOrPutContext(key: K): ZigGetOrPutResult<V> {
        return getOrPut(key)
    }

    // ========================================================================
    // 删除操作 - 对应 Bun HashMap.remove / remove_entry / fetch_remove
    // ========================================================================

    /// 删除并返回值 - 对应 Bun HashMap.remove
    /// Zig: fetchRemove value half
    /// Rust:
    ///   pub fn remove<Q>(&mut self, key: &Q) -> Option<V>
    public func remove(key: K): ?V {
        let idx = getIndex(key)
        if (idx >= 0) {
            let result = removeByIndex(idx)
            return Some(result[1])
        }
        return None
    }

    /// 删除并返回键值对 - 对应 Bun HashMap.remove_entry
    /// Rust:
    ///   pub fn remove_entry<Q>(&mut self, key: &Q) -> Option<(K, V)>
    public func removeEntry(key: K): ?(K, V) {
        let idx = getIndex(key)
        if (idx >= 0) {
            let result = removeByIndex(idx)
            return Some((result[0], result[1]))
        }
        return None
    }

    /// 删除并返回键值对对象 - 对应 Bun HashMap.fetch_remove
    /// Zig: fetchRemove — remove and return {key, value} pair
    /// Rust:
    ///   pub fn fetch_remove(&mut self, key: K) -> Option<KV<K, V>>
    public func fetchRemove(key: K): ?ZigKV<K, V> {
        let idx = getIndex(key)
        if (idx >= 0) {
            let result = removeByIndex(idx)
            return Some(ZigKV<K, V>(result[0], result[1]))
        }
        return None
    }

    // ========================================================================
    // Entry API - 对应 Bun HashMap.entry
    // Zig: std HashMap entry API
    // ========================================================================

    /// Entry 操作 - 获取或创建条目
    /// 对应 Bun HashMap::entry / std HashMap::entry
    /// 返回 (entry_index, is_occupied)
    public func entry(key: K): (Int64, Bool) {
        let idx = getIndex(key)
        if (idx >= 0) {
            return (idx, true) // Occupied
        }
        return (Int64(-1), false) // Vacant
    }

    /// 获取或插入默认值 - 对应 Bun Entry::or_insert
    public func entryOrInsert(key: K, defaultValue: V): V {
        let (idx, foundExisting) = getOrPutSlot(key)
        if (!foundExisting) {
            let slot = slots[idx]
            slot.key = Some(key)
            slot.value = Some(defaultValue)
            slot.occupied = true
            return defaultValue
        }
        return slots[idx].value.getOrThrow()
    }

    /// 获取或插入工厂值 - 对应 Bun Entry::or_insert_with
    public func entryOrInsertWith(key: K, factory: () -> V): V {
        let (idx, foundExisting) = getOrPutSlot(key)
        if (!foundExisting) {
            let slot = slots[idx]
            let value = factory()
            slot.key = Some(key)
            slot.value = Some(value)
            slot.occupied = true
            return value
        }
        return slots[idx].value.getOrThrow()
    }

    // ========================================================================
    // 遍历 - 对应 Bun HashMap.iter / keys / values
    // ========================================================================

    /// 获取所有键 - 对应 Bun HashMap.keys
    /// Zig: 遍历 metadata 找到所有 used 槽位
    public func keys(): ArrayList<K> {
        let result = ArrayList<K>()
        if (_size == 0) { return result }
        var remaining = _size
        var i: Int64 = 0
        while (i < metadata.size && remaining > 0) {
            if (metaIsUsed(metadata[Int64(i)])) {
                result.append(slots[i].key.getOrThrow())
                remaining -= 1
            }
            i += 1
        }
        return result
    }

    /// 获取所有值 - 对应 Bun HashMap.values
    public func values(): ArrayList<V> {
        let result = ArrayList<V>()
        if (_size == 0) { return result }
        var remaining = _size
        var i: Int64 = 0
        while (i < metadata.size && remaining > 0) {
            if (metaIsUsed(metadata[Int64(i)])) {
                result.append(slots[i].value.getOrThrow())
                remaining -= 1
            }
            i += 1
        }
        return result
    }

    /// 获取所有键值对 - 对应 Bun HashMap.entries
    public func entries(): ArrayList<(K, V)> {
        let result = ArrayList<(K, V)>()
        if (_size == 0) { return result }
        var remaining = _size
        var i: Int64 = 0
        while (i < metadata.size && remaining > 0) {
            if (metaIsUsed(metadata[Int64(i)])) {
                result.append((slots[i].key.getOrThrow(), slots[i].value.getOrThrow()))
                remaining -= 1
            }
            i += 1
        }
        return result
    }

    /// 遍历 - 对应 Bun HashMap.iter
    /// Zig: Iter<'a, K, V> — 按 metadata 顺序遍历 used 槽位
    public func forEach(fn: (K, V) -> Unit): Unit {
        if (_size == 0) { return }
        var remaining = _size
        var i: Int64 = 0
        while (i < metadata.size && remaining > 0) {
            if (metaIsUsed(metadata[Int64(i)])) {
                fn(slots[i].key.getOrThrow(), slots[i].value.getOrThrow())
                remaining -= 1
            }
            i += 1
        }
    }

    // ========================================================================
    // 内部方法 - 核心算法
    // ========================================================================

    /// 哈希键值
    private func hashKey(key: K): UInt64 {
        return WyHash.hash(key.toString())
    }

    /// 当前负载 - 对应 Bun HashMap.load
    /// Zig: max_load - available
    private func load(): UInt32 {
        let maxLoad = UInt32((UInt64(metadata.size) * MAX_LOAD_PERCENTAGE) / UInt64(100))
        return maxLoad - available
    }

    /// 按需扩容 - 对应 Bun HashMap.grow_if_needed
    private func growIfNeeded(newCount: UInt32): Unit {
        if (newCount > available) {
            grow(capacityForSize(load() + newCount))
        }
    }

    /// 扩容 - 对应 Bun HashMap.grow
    /// Zig:
    ///   fn grow(self, new_capacity) void {
    ///       create new table with new_capacity
    ///       re-insert all entries
    ///   }
    private func grow(newCapacity: UInt32): Unit {
        let newCap = if (newCapacity > MINIMAL_CAPACITY) { newCapacity } else { MINIMAL_CAPACITY }
        // debug_assert!(newCap > metadata.size)

        // 创建新表
        var newMetadata = Array<UInt8>(Int64(newCap), repeat: SLOT_FREE)
        var newSlots = ArrayList<ZigHashEntry<K, V>>()
        for (_ in 0..Int64(newCap)) {
            newSlots.append(ZigHashEntry<K, V>())
        }
        let newAvailable = UInt32((UInt64(newCap) * MAX_LOAD_PERCENTAGE) / UInt64(100))

        // 重新插入所有条目
        if (_size > 0) {
            for (i in 0..metadata.size) {
                if (!metaIsUsed(metadata[Int64(i)])) {
                    continue
                }
                let slot = slots[Int64(i)]
                if (slot.occupied) {
                    putAssumeCapacityNoClobber(
                        newMetadata, newSlots, newCap,
                        slot.key.getOrThrow(), slot.value.getOrThrow()
                    )
                }
            }
        }

        metadata = newMetadata
        slots = newSlots
        available = newAvailable
    }

    /// 假定有容量插入 (不覆盖) - 对应 Bun HashMap.put_assume_capacity_no_clobber
    /// Zig:
    ///   fn putAssumeCapacityNoClobber(self, key, value) void {
    ///       let cap = metadata.len;
    ///       let hash = hash(key);
    ///       let mask = cap - 1;
    ///       let mut idx = hash & mask;
    ///       while (meta_is_used(metadata[idx])) { idx = (idx + 1) & mask; }
    ///       available -= 1;
    ///       metadata[idx] = fill(take_fingerprint(hash));
    ///       slots[idx] = (key, value);
    ///       size += 1;
    ///   }
    private func putAssumeCapacityNoClobber(
        meta: Array<UInt8>, slotArr: ArrayList<ZigHashEntry<K, V>>, cap: UInt32,
        key: K, value: V
    ): Unit {
        let hash = hashKey(key)
        let mask = Int64(cap - 1)
        var idx = Int64(hash) & mask

        while (metaIsUsed(meta[idx])) {
            idx = (idx + 1) & mask
        }

        // debug_assert!(available > 0)
        let fp = takeFingerprint(hash)
        meta[idx] = metaFill(fp)
        let slot = slotArr[idx]
        slot.key = Some(key)
        slot.value = Some(value)
        slot.occupied = true
        _size += 1
    }

    /// 查找索引 - 对应 Bun HashMap.get_index
    /// Zig:
    ///   fn getIndex(self, key) ?usize {
    ///       if size == 0: return null
    ///       probe for key, stop on free, skip tombstones
    ///   }
    private func getIndex(key: K): Int64 {
        if (_size == 0) {
            return -1
        }
        let cap = metadata.size
        let hash = hashKey(key)
        let mask = Int64(cap - 1)
        let fp = takeFingerprint(hash)
        var limit = cap
        var idx = Int64(hash) & mask

        while (!metaIsFree(metadata[Int64(idx)]) && limit > 0) {
            if (metaIsUsed(metadata[Int64(idx)]) && metaFingerprint(metadata[Int64(idx)]) == fp) {
                let slot = slots[Int64(idx)]
                if (slot.occupied && key == slot.key.getOrThrow()) {
                    return Int64(idx)
                }
            }
            limit -= 1
            idx = (idx + 1) & mask
        }
        return -1
    }

    /// 获取或插入槽位 - 对应 Bun HashMap.get_or_put_slot
    /// Zig: getOrPutAdapted lifted to grow-on-demand
    ///   Returns (slot_index, found_existing)
    ///   On miss: slot is empty, metadata is filled
    private func getOrPutSlot(key: K): (Int64, Bool) {
        growIfNeeded(1)

        let cap = metadata.size
        let hash = hashKey(key)
        let mask = Int64(cap - 1)
        let fp = takeFingerprint(hash)
        var limit = cap
        var idx = Int64(hash) & mask
        var firstTombstoneIdx = Int64(cap) // invalid sentinel

        while (!metaIsFree(metadata[Int64(idx)]) && limit > 0) {
            if (metaIsUsed(metadata[Int64(idx)]) && metaFingerprint(metadata[Int64(idx)]) == fp) {
                let slot = slots[Int64(idx)]
                if (slot.occupied && key == slot.key.getOrThrow()) {
                    return (Int64(idx), true)
                }
            } else if (firstTombstoneIdx == cap && metaIsTombstone(metadata[Int64(idx)])) {
                firstTombstoneIdx = Int64(idx)
            }
            limit -= 1
            idx = (idx + 1) & mask
        }

        // 复用墓碑或使用新位置
        if (firstTombstoneIdx < cap) {
            idx = firstTombstoneIdx
        }
        available -= 1
        metadata[Int64(idx)] = metaFill(fp)
        _size += 1
        return (idx, false)
    }

    /// 按索引删除 - 对应 Bun HashMap.remove_by_index
    /// Zig:
    ///   metadata[idx] = SLOT_TOMBSTONE;
    ///   slots[idx] = None;
    ///   size -= 1;
    ///   available += 1;
    private func removeByIndex(idx: Int64): (K, V) {
        metadata[Int64(idx)] = SLOT_TOMBSTONE
        let slot = slots[Int64(idx)]
        let k = slot.key.getOrThrow()
        let v = slot.value.getOrThrow()
        slot.occupied = false
        _size -= 1
        available += 1
        return (k, v)
    }
}
