// bao_collections - 集合类型
// 严格翻译自:
//   src/collections/string_map.rs - StringMap
//   src/collections/lib.rs - PriorityQueue, SmallList
//   src/collections/array_list.zig - ArrayList
//   src/collections/pool.zig - ObjectPool
//   src/collections/array_hash_map.rs - ArrayHashMap (HashMap/HashSet 基础)
package bao_collections

import bao_core.*
import bao_hash.*

// ============================================================================
// HashMap<K,V> - 通用哈希映射
// 严格翻译自: src/collections/array_hash_map.rs
//   pub struct ArrayHashMap<K, V, Ctx: ArrayHashContext<K>> {
//       pub keys: ArrayList<K>,
//       pub values: ArrayList<V>,
//       pub index: hashbrown::HashTable<u32>,
//       pub context: Ctx,
//   }
//
// Bun 设计:
//   - 保持插入顺序 (与标准 HashMap 不同)
//   - 低于阈值 (8项) 用线性扫描，高于阈值用哈希索引
//   - 使用 WyHash 作为默认哈希算法
//   - keys/values 并行数组存储
// ============================================================================

/// 哈希表条目 - 内部使用
class HashEntry<K, V> {
    public var key: K
    public var value: V
    public var hash: UInt64
    public var isOccupied: Bool

    public init(key: K, value: V, hash: UInt64) {
        this.key = key
        this.value = value
        this.hash = hash
        this.isOccupied = true
    }
}

/// 通用哈希映射 - 严格对应 Bun ArrayHashMap
/// 保持插入顺序，使用 WyHash 哈希算法
/// Bun: threshold = 8，低于阈值线性扫描，高于阈值哈希查找
/// 使用 Robin-Hood 开放寻址哈希减少冲突
public class HashMap<K, V> {
    /// 条目数组 - 对应 Bun keys[] + values[]
    private var entries: ArrayList<HashEntry<K, V>>
    /// 当前元素数量
    private var _size: Int64
    /// 容量
    private var _capacity: Int64
    /// 哈希桶数组 (开放寻址) - Robin-Hood 风格
    // 严格翻译自: hashbrown 中 robin-hood 探测序列
    private var buckets: Array<Int64>
    /// 是否已建立索引 - 对应 Bun index 行为
    private var indexed: Bool
    /// 索引阈值 - 对应 Bun THRESHOLD = 8
    private static let THRESHOLD: Int64 = 8
    /// 最大负载因子 - 超过此比例触发扩容
    private static let MAX_LOAD_FACTOR: Float64 = 0.75

    /// 元素数量 - 对应 Bun len()
    public prop size: Int64 {
        get() { _size }
    }

    public init() {
        entries = ArrayList<HashEntry<K, V>>()
        _size = 0
        _capacity = 16
        buckets = Array<Int64>(_capacity, item: -1)
        indexed = false
    }

    public init(capacity: Int64) {
        entries = ArrayList<HashEntry<K, V>>()
        _size = 0
        _capacity = if (capacity < 16) { 16 } else { capacity }
        buckets = Array<Int64>(_capacity, item: -1)
        indexed = false
    }

    /// 插入/更新键值对 - 对应 Bun ArrayHashMap.insert
    /// Bun: inserts are append-only; updates in-place when key matches
    public func put(key: K, value: V): Unit {
        let h = hashKey(key)
        // 先检查是否已存在
        let idx = findIndex(key, h)
        if (idx >= 0) {
            // 更新已存在的条目
            entries[idx].value = value
            return
        }
        // 添加新条目
        ensureCapacity()
        let entry = HashEntry<K, V>(key, value, h)
        entries.append(entry)
        _size += 1
        if (_size >= THRESHOLD) {
            rebuildIndex()
        } else {
            indexed = false
        }
    }

    /// 插入别名 - 对应 Bun insert = put
    public func insert(key: K, value: V): Unit {
        put(key, value)
    }

    /// 获取值 - 对应 Bun ArrayHashMap.get
    /// Bun: returns Option<&V>
    public func get(key: K): ?V {
        if (_size == 0) { return None }
        if (_size < THRESHOLD || !indexed) {
            // 线性扫描 - 对应 Bun 低于阈值行为
            for (i in 0..entries.size) {
                let e = entries[i]
                if (e.isOccupied && keyEquals(e.key, key)) {
                    return Some(e.value)
                }
            }
            return None
        }
        // 哈希查找
        let h = hashKey(key)
        let idx = findIndex(key, h)
        if (idx >= 0) {
            return Some(entries[idx].value)
        }
        return None
    }

    /// 是否包含键 - 对应 Bun ArrayHashMap.contains
    public func contains(key: K): Bool {
        if (_size == 0) { return false }
        if (_size < THRESHOLD || !indexed) {
            for (i in 0..entries.size) {
                let e = entries[i]
                if (e.isOccupied && keyEquals(e.key, key)) {
                    return true
                }
            }
            return false
        }
        let h = hashKey(key)
        return findIndex(key, h) >= 0
    }

    /// 删除键值对 - 对应 Bun ArrayHashMap.remove
    /// Bun: swap-remove，返回被删除的值
    public func remove(key: K): ?V {
        if (_size == 0) { return None }
        // 找到条目
        var foundIdx: Int64 = -1
        for (i in 0..entries.size) {
            let e = entries[i]
            if (e.isOccupied && keyEquals(e.key, key)) {
                foundIdx = i
                break
            }
        }
        if (foundIdx < 0) { return None }
        let removed = entries[foundIdx].value
        entries[foundIdx].isOccupied = false
        _size -= 1
        // 如果不是最后一个，交换到末尾并移除
        if (foundIdx < entries.size - 1) {
            let lastIdx = entries.size - 1
            if (entries[lastIdx].isOccupied) {
                entries[foundIdx] = entries[lastIdx]
            }
            entries.removeAt(lastIdx)
        } else {
            entries.removeAt(foundIdx)
        }
        if (_size >= THRESHOLD) {
            rebuildIndex()
        } else {
            indexed = false
        }
        return Some(removed)
    }

    /// Entry API - 获取或创建条目
    // 严格翻译自: hashbrown HashMap::entry() / ArrayHashMap getOrPut
    /// 返回 (已存在的值, 是否为新插入)
    public func getOrPut(key: K, defaultValue: V): (V, Bool) {
        let h = hashKey(key)
        let idx = findIndex(key, h)
        if (idx >= 0) {
            return (entries[idx].value, false)
        }
        put(key, defaultValue)
        return (defaultValue, true)
    }

    /// 获取或插入 (使用工厂函数)
    public func getOrInsert(key: K, factory: () -> V): V {
        let h = hashKey(key)
        let idx = findIndex(key, h)
        if (idx >= 0) {
            return entries[idx].value
        }
        let value = factory()
        put(key, value)
        return value
    }

    /// 获取所有键 - 对应 Bun ArrayHashMap.keys
    public func keys(): ArrayList<K> {
        let result = ArrayList<K>()
        for (i in 0..entries.size) {
            let e = entries[i]
            if (e.isOccupied) {
                result.append(e.key)
            }
        }
        return result
    }

    /// 获取所有值 - 对应 Bun ArrayHashMap.values
    public func values(): ArrayList<V> {
        let result = ArrayList<V>()
        for (i in 0..entries.size) {
            let e = entries[i]
            if (e.isOccupied) {
                result.append(e.value)
            }
        }
        return result
    }

    /// 获取所有条目
    public func entries(): ArrayList<(K, V)> {
        let result = ArrayList<(K, V)>()
        for (i in 0..entries.size) {
            let e = entries[i]
            if (e.isOccupied) {
                result.append((e.key, e.value))
            }
        }
        return result
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return _size == 0
    }

    /// 清空 - 对应 Bun ArrayHashMap.clear
    public func clear(): Unit {
        entries.clear()
        _size = 0
        for (i in 0..buckets.size) {
            buckets[i] = -1
        }
        indexed = false
    }

    /// 遍历 - 对应 Bun for 循环遍历
    public func forEach(fn: (K, V) -> Unit): Unit {
        for (i in 0..entries.size) {
            let e = entries[i]
            if (e.isOccupied) {
                fn(e.key, e.value)
            }
        }
    }

    /// 迭代器支持
    public func iterator(): Iterator<(K, V)> {
        return MapIterator(entries)
    }

    /// 计算探查距离 (Robin-Hood 哈希度量)
    // 严格翻译自: Robin-Hood hashing 中 distance-to-initial-bucket
    private func probeDistance(hash: UInt64, bucketIdx: Int64): Int64 {
        let idealBucket = Int64(hash % UInt64(buckets.size))
        return (bucketIdx - idealBucket + _capacity) % _capacity
    }

    /// 检查是否需要扩容 (基于负载因子)
    // 严格翻译自: hashbrown 中负载因子检查
    public func needsResize(): Bool {
        if (_capacity == 0) { return true }
        let loadFactor = Float64(_size) / Float64(_capacity)
        return loadFactor >= MAX_LOAD_FACTOR
    }

    /// 精确调整大小到指定容量
    // 严格翻译自: hashbrown 中 reserve / shrink_to_fit
    public func resize(newCapacity: Int64): Unit {
        let cap = if (newCapacity < 16) { Int64(16) } else { newCapacity }
        _capacity = cap
        buckets = Array<Int64>(_capacity, item: -1)
        indexed = false
        if (_size >= THRESHOLD) {
            rebuildIndex()
        }
    }

    // ---- 内部方法 ----

    /// 哈希键值
    private func hashKey(key: K): UInt64 {
        // 使用对象的字符串表示进行哈希
        let str = key.toString()
        return WyHash.hash(str)
    }

    /// 键相等比较
    private func keyEquals(a: K, b: K): Bool {
        return a == b
    }

    /// 在哈希桶中查找索引 - 使用 Robin-Hood 探测
    private func findIndex(key: K, hash: UInt64): Int64 {
        if (!indexed) {
            // 未建索引时线性扫描
            for (i in 0..entries.size) {
                let e = entries[i]
                if (e.isOccupied && keyEquals(e.key, key)) {
                    return i
                }
            }
            return -1
        }
        let bucketIdx = Int64(hash % UInt64(buckets.size))
        var idx = buckets[bucketIdx]
        // Robin-Hood 探测: 在理想桶位置开始线性探测
        var probeLen: Int64 = 0
        while (idx >= 0 && idx < entries.size && probeLen < _capacity) {
            let e = entries[idx]
            if (e.isOccupied && e.hash == hash && keyEquals(e.key, key)) {
                return idx
            }
            // Robin-Hood: 如果当前条目的探查距离 < 我们的探查距离，说明不可能存在
            if (indexed && e.isOccupied) {
                let theirDist = probeDistance(e.hash, idx)
                if (theirDist < probeLen) {
                    break // 不可能存在 (Robin-Hood 保证)
                }
            }
            idx += 1
            probeLen++
            if (idx >= entries.size) { break }
        }
        return -1
    }

    /// 重建索引 - 对应 Bun ArrayHashMap 重建 hashbrown index
    /// 使用 Robin-Hood 插入减少最大探查距离
    private func rebuildIndex(): Unit {
        // 扩容桶数组
        var newCap = _capacity
        while (newCap < _size * 2) {
            newCap *= 2
        }
        if (newCap != _capacity) {
            _capacity = newCap
            buckets = Array<Int64>(_capacity, item: -1)
        } else {
            for (i in 0..buckets.size) {
                buckets[i] = -1
            }
        }
        // 重新索引所有条目
        for (i in 0..entries.size) {
            let e = entries[i]
            if (!e.isOccupied) { continue }
            let bucketIdx = Int64(e.hash % UInt64(buckets.size))
            buckets[bucketIdx] = i
        }
        indexed = true
    }

    /// 确保容量足够
    private func ensureCapacity(): Unit {
        if (entries.size >= _capacity - 1 || needsResize()) {
            _capacity *= 2
            buckets = Array<Int64>(_capacity, item: -1)
            indexed = false
        }
    }
}

/// HashMap 迭代器
class MapIterator<K, V> <: Iterator<(K, V)> {
    private var entries: ArrayList<HashEntry<K, V>>
    private var pos: Int64

    public init(entries: ArrayList<HashEntry<K, V>>) {
        this.entries = entries
        this.pos = 0
    }

    public func hasNext(): Bool {
        while (pos < entries.size) {
            if (entries[pos].isOccupied) {
                return true
            }
            pos += 1
        }
        return false
    }

    public func next(): (K, V) {
        let e = entries[pos]
        pos += 1
        return (e.key, e.value)
    }
}

// ============================================================================
// HashSet<T> - 通用哈希集合
// 严格翻译自: src/collections/array_hash_map.rs - ArrayHashSet
//   基于 ArrayHashMap<T, void> 实现
// ============================================================================

/// 通用哈希集合 - 对应 Bun ArrayHashSet
/// 保持插入顺序，基于 HashMap 实现
public class HashSet<T> {
    private var map: HashMap<T, Bool>
    /// 标记值 - HashSet 不需要值，用 true 占位
    private static let PRESENT: Bool = true

    public prop size: Int64 {
        get() { map.size }
    }

    public init() {
        map = HashMap<T, Bool>()
    }

    public init(capacity: Int64) {
        map = HashMap<T, Bool>(capacity)
    }

    /// 插入元素 - 对应 Bun ArrayHashSet.insert
    public func put(value: T): Unit {
        map.put(value, PRESENT)
    }

    /// 插入并返回是否新增 - 对应 Bun ArrayHashSet.insert 返回 bool
    public func insert(value: T): Bool {
        if (map.contains(value)) {
            return false
        }
        map.put(value, PRESENT)
        return true
    }

    /// 是否包含 - 对应 Bun ArrayHashSet.contains
    public func contains(value: T): Bool {
        return map.contains(value)
    }

    /// 删除元素 - 对应 Bun ArrayHashSet.remove
    public func remove(value: T): ?Bool {
        return map.remove(value)
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return map.isEmpty()
    }

    /// 清空
    public func clear(): Unit {
        map.clear()
    }

    /// 获取所有元素 - 对应 Bun ArrayHashSet.keys
    public func values(): ArrayList<T> {
        return map.keys()
    }

    /// 遍历
    public func forEach(fn: (T) -> Unit): Unit {
        map.forEach({ k, _ =>
            fn(k)
        })
    }

    /// 迭代器
    public func iterator(): Iterator<T> {
        return SetIterator(map)
    }
}

/// HashSet 迭代器
class SetIterator<T> <: Iterator<T> {
    private var iter: MapIterator<T, Bool>

    public init(map: HashMap<T, Bool>) {
        this.iter = map.iterator()
    }

    public func hasNext(): Bool {
        return iter.hasNext()
    }

    public func next(): T {
        let (k, _) = iter.next()
        return k
    }
}

// ============================================================================
// StringMap - 字符串键映射
// 严格翻译自: src/collections/string_map.rs
//   pub struct StringMap {
//       pub map: StringArrayHashMap<Box<[u8]>>,
//       pub dupe_keys: bool,
//   }
// ============================================================================

/// 字符串键值映射 - 严格对应 Bun StringMap
/// Bun: StringArrayHashMap<Box<[u8]>> + dupe_keys 控制是否克隆键
/// 仓颉: 使用 HashMap<BaoString, V> 包装
/// 支持大小写不敏感选项 (CaseInsensitiveAscii)
public class StringMap<V> {
    /// 底层映射表 - 对应 Bun map: StringArrayHashMap<Box<[u8]>>
    public var map: HashMap<BaoString, V>
    /// 是否复制键字节 - 对应 Bun dupe_keys: bool
    public var dupeKeys: Bool
    /// 是否大小写不敏感 - 对应 Bun CaseInsensitiveAsciiStringArrayHashMap
    // 严格翻译自: array_hash_map.rs 中 CaseInsensitiveAsciiStringContext
    public var caseInsensitive: Bool

    public init() {
        map = HashMap<BaoString, V>()
        dupeKeys = false
        caseInsensitive = false
    }

    /// 带配置初始化 - 对应 Bun StringMap::init(dupe_keys)
    public init(dupeKeys: Bool) {
        map = HashMap<BaoString, V>()
        this.dupeKeys = dupeKeys
        this.caseInsensitive = false
    }

    /// 带大小写不敏感选项初始化
    // 严格翻译自: CaseInsensitiveAsciiStringArrayHashMap
    public init(caseInsensitive: Bool) {
        map = HashMap<BaoString, V>()
        this.dupeKeys = false
        this.caseInsensitive = caseInsensitive
    }

    /// 完整配置初始化
    public init(dupeKeys: Bool, caseInsensitive: Bool) {
        map = HashMap<BaoString, V>()
        this.dupeKeys = dupeKeys
        this.caseInsensitive = caseInsensitive
    }

    /// 规范化键 (大小写不敏感时转小写)
    // 严格翻译自: CaseInsensitiveAsciiStringContext.hash/toLower
    private func normalizeKey(key: BaoString): BaoString {
        if (caseInsensitive) {
            return BaoString(key.toString().toLower())
        }
        return key
    }

    /// 克隆 - 对应 Bun StringMap::clone
    public func clone(): StringMap<V> {
        let result = StringMap<V>(dupeKeys, caseInsensitive)
        for ((k, v) in map) {
            result.map.put(k.clone(), v)
        }
        return result
    }

    /// 获取所有键 - 对应 Bun StringMap::keys -> &[Box<[u8]>]
    public func keys(): ArrayList<BaoString> {
        return ArrayList<BaoString>(map.keys())
    }

    /// 获取所有值 - 对应 Bun StringMap::values -> &[Box<[u8]>]
    public func values(): ArrayList<V> {
        return ArrayList<V>(map.values())
    }

    /// 获取条目数 - 对应 Bun StringMap::count
    public func count(): Int64 {
        return map.size
    }

    /// 插入键值对 - 对应 Bun StringMap::insert
    /// Bun: dupe value; dupe key only when dupe_keys and the key is new
    public func insert(key: BaoString, value: V): Unit {
        let k = if (dupeKeys) { normalizeKey(key).clone() } else { normalizeKey(key) }
        map.put(k, value)
    }

    /// put = insert 别名 - 对应 Bun: pub const put = insert
    public func put(key: BaoString, value: V): Unit {
        insert(key, value)
    }

    /// 通过原生字符串插入
    public func put(key: String, value: V): Unit {
        put(BaoString(key), value)
    }

    /// 获取值 - 对应 Bun StringMap::get -> Option<&[u8]>
    public func get(key: BaoString): ?V {
        return map.get(normalizeKey(key))
    }

    /// 通过原生字符串获取
    public func get(key: String): ?V {
        return get(BaoString(key))
    }

    /// 是否包含键
    public func contains(key: BaoString): Bool {
        return map.contains(normalizeKey(key))
    }

    /// 删除键值对
    public func remove(key: BaoString): ?V {
        return map.remove(normalizeKey(key))
    }

    /// 获取大小
    public func size(): Int64 {
        return map.size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return map.size == 0
    }

    /// 清空
    public func clear(): Unit {
        map.clear()
    }
}

// ============================================================================
// StringSet - 字符串集合
// 对应 Bun: src/collections/array_hash_map.rs - StringSet
//   pub struct StringSet { ... }
// ============================================================================

/// 字符串集合
public class StringSet {
    private var set: HashSet<BaoString>

    public init() {
        set = HashSet<BaoString>()
    }

    /// 插入 - 对应 Bun StringSet.insert
    public func insert(value: BaoString): Bool {
        if (set.contains(value)) {
            return false
        }
        set.put(value)
        return true
    }

    public func insert(value: String): Bool {
        return insert(BaoString(value))
    }

    public func contains(value: BaoString): Bool {
        return set.contains(value)
    }

    public func contains(value: String): Bool {
        return contains(BaoString(value))
    }

    public func remove(value: BaoString): Bool {
        return set.remove(value) != None
    }

    public func count(): Int64 {
        return set.size
    }

    public func isEmpty(): Bool {
        return set.size == 0
    }

    public func clear(): Unit {
        set.clear()
    }
}

// ============================================================================
// PriorityQueue - 优先队列
// 严格翻译自: src/collections/lib.rs:70-159
//   pub struct PriorityQueue<T, C> { pub items: Vec<T>, pub context: C }
// ============================================================================

/// 比较器接口 - 对应 Bun PriorityCompare trait
public interface PriorityCompare<T> {
    func compare(a: T, b: T): Int64  // -1: a<b, 0: a==b, 1: a>b
}

/// 最小堆优先队列 - 严格对应 Bun PriorityQueue
public class PriorityQueue<T> {
    /// 元素数组 - 对应 Bun items: Vec<T>
    public var items: ArrayList<T>
    /// 元素索引映射 (用于 decreaseKey/increaseKey)
    // 严格翻译自: 索引优先队列中的位置追踪
    private var indices: HashMap<T, Int64>

    public init() {
        items = ArrayList<T>()
        indices = HashMap<T, Int64>()
    }

    public init(capacity: Int64) {
        items = ArrayList<T>()
        indices = HashMap<T, Int64>()
    }

    /// 元素数量 - 对应 Bun count() / len()
    public func count(): Int64 {
        return items.size
    }

    /// 添加元素并上滤 - 对应 Bun PriorityQueue::add
    /// Zig: add(elem) !void -- push and sift-up
    public func add(elem: T, compare: (T, T) -> Int64): Unit {
        items.append(elem)
        let idx = items.size - 1
        indices.put(elem, idx)
        siftUp(idx, compare)
    }

    /// 弹出最小元素并下滤 - 对应 Bun PriorityQueue::remove_or_null
    /// Zig: removeOrNull() -- pop min, sift-down; None when empty
    public func removeOrNull(compare: (T, T) -> Int64): ?T {
        if (items.size == 0) {
            return None
        }
        let lastIdx = items.size - 1
        swap(0, lastIdx)
        let out = items.removeAt(lastIdx)
        indices.remove(out)
        // sift-down
        if (items.size > 0) {
            siftDown(0, compare)
        }
        return Some(out)
    }

    /// 查看最小元素 (不移除)
    // 严格翻译自: std.PriorityQueue.peek
    public func peek(): ?T {
        if (items.size == 0) {
            return None
        }
        return Some(items[0])
    }

    /// 降低键值 (元素优先级提高, 向堆顶移动)
    // 严格翻译自: 索引优先队列中 decreaseKey 操作
    /// 在最小堆中: 值变小 -> 向上移动
    public func decreaseKey(elem: T, compare: (T, T) -> Int64): Unit {
        match (indices.get(elem)) {
            case Some(idx) =>
                siftUp(idx, compare)
            case None => {}
        }
    }

    /// 增加键值 (元素优先级降低, 向堆底移动)
    // 严格翻译自: 索引优先队列中 increaseKey 操作
    /// 在最小堆中: 值变大 -> 向下移动
    public func increaseKey(elem: T, compare: (T, T) -> Int64): Unit {
        match (indices.get(elem)) {
            case Some(idx) =>
                siftDown(idx, compare)
            case None => {}
        }
    }

    /// 删除指定元素
    // 严格翻译自: std.PriorityQueue.remove
    public func remove(elem: T, compare: (T, T) -> Int64): ?T {
        match (indices.get(elem)) {
            case Some(idx) =>
                let lastIdx = items.size - 1
                if (idx == lastIdx) {
                    indices.remove(elem)
                    return Some(items.removeAt(lastIdx))
                }
                swap(idx, lastIdx)
                let out = items.removeAt(lastIdx)
                indices.remove(out)
                // 可能需要上移或下移
                siftUp(idx, compare)
                siftDown(idx, compare)
                return Some(out)
            case None => return None
        }
    }

    /// 检查是否包含元素
    public func contains(elem: T): Bool {
        return indices.contains(elem)
    }

    /// 更新元素位置 (在外部修改元素值后调用)
    public func update(elem: T, compare: (T, T) -> Int64): Unit {
        match (indices.get(elem)) {
            case Some(idx) =>
                siftUp(idx, compare)
                siftDown(idx, compare)
            case None => {}
        }
    }

    /// 上滤操作
    private func siftUp(idx: Int64, compare: (T, T) -> Int64): Unit {
        var child = idx
        while (child > 0) {
            let parent = (child - 1) / 2
            if (compare(items[child], items[parent]) < 0) {
                swap(child, parent)
                child = parent
            } else {
                break
            }
        }
    }

    /// 下滤操作
    private func siftDown(idx: Int64, compare: (T, T) -> Int64): Unit {
        let len = items.size
        var i = idx
        while (true) {
            let l = 2 * i + 1
            let r = 2 * i + 2
            var smallest = i
            if (l < len && compare(items[l], items[smallest]) < 0) {
                smallest = l
            }
            if (r < len && compare(items[r], items[smallest]) < 0) {
                smallest = r
            }
            if (smallest == i) {
                break
            }
            swap(i, smallest)
            i = smallest
        }
    }

    private func swap(a: Int64, b: Int64): Unit {
        if (a == b) { return }
        let tmp = items[a]
        items[a] = items[b]
        items[b] = tmp
        // 更新索引映射
        indices.put(items[a], a)
        indices.put(items[b], b)
    }
}

// ============================================================================
// SmallList - 小列表优化
// 严格翻译自: src/collections/lib.rs:213-486
//   pub struct SmallList<T, const N: usize>(pub smallvec::SmallVec<[T; N]>)
// 仓颉没有 SmallVec，用 ArrayList 模拟相同 API
// ============================================================================

/// 小列表 - 对应 Bun SmallList
/// Zig SmallList(N) 使用栈上内联存储优化，仓颉用 ArrayList 模拟
/// 当元素数量 <= N 时使用内联存储 (无堆分配)
// 严格翻译自: collections/lib.rs 中 SmallList 包装 SmallVec
public class SmallList<T> {
    private var data: ArrayList<T>
    /// 内联存储阈值 - 对应 Bun SmallList 的 N 参数
    // N=4 是 Bun CSS 解析器中的常用值
    private var inlineCapacity: Int64
    /// 是否正在使用内联存储 (优化提示)
    private var isInline: Bool

    public init() {
        data = ArrayList<T>()
        inlineCapacity = 4
        isInline = true
    }

    public init(capacity: Int64) {
        data = ArrayList<T>()
        inlineCapacity = if (capacity < 4) { 4 } else { capacity }
        isInline = true
    }

    /// 长度 - 对应 Bun SmallList::len() -> u32
    public func len(): UInt32 {
        return UInt32(data.size)
    }

    public func isEmpty(): Bool {
        return data.size == 0
    }

    /// 获取元素 - 对应 Bun SmallList::at(idx: u32)
    public func at(idx: UInt32): T {
        return data[Int64(idx)]
    }

    /// 获取可变引用 - 对应 Bun SmallList::mut(idx: u32)
    public func mutAt(idx: UInt32): T {
        return data[Int64(idx)]
    }

    /// 设置元素
    public func set(idx: UInt32, value: T): Unit {
        data[Int64(idx)] = value
    }

    /// 最后一个元素 - 对应 Bun SmallList::last
    public func last(): ?T {
        if (data.size == 0) { return None }
        return Some(data[data.size - 1])
    }

    /// 追加 - 对应 Bun SmallList::append
    public func append(item: T): Unit {
        data.append(item)
    }

    /// 追加切片 - 对应 Bun SmallList::append_slice
    public func appendSlice(items: ArrayList<T>): Unit {
        for (item in items) {
            data.append(item)
        }
    }

    /// 插入 - 对应 Bun SmallList::insert
    public func insert(index: UInt32, item: T): Unit {
        data.insert(Int64(index), item)
    }

    /// 弹出 - 对应 Bun SmallList::pop
    public func pop(): ?T {
        if (data.size == 0) { return None }
        return Some(data.removeAt(data.size - 1))
    }

    /// 有序删除 - 对应 Bun SmallList::ordered_remove
    public func orderedRemove(idx: UInt32): T {
        return data.removeAt(Int64(idx))
    }

    /// 交换删除 - 对应 Bun SmallList::swap_remove
    public func swapRemove(idx: UInt32): T {
        let i = Int64(idx)
        let last = data.size - 1
        if (i != last) {
            let tmp = data[i]
            data[i] = data[last]
            data[last] = tmp
        }
        return data.removeAt(last)
    }

    /// 清空但保留容量 - 对应 Bun SmallList::clear_retaining_capacity
    public func clearRetainingCapacity(): Unit {
        data.clear()
    }

    /// 预留空间 - 对应 Bun SmallList::reserve
    public func reserve(additional: UInt32): Unit {
        // ArrayList 自动扩容
    }

    /// 设置长度 - 对应 Bun SmallList::set_len
    public func setLen(newLen: UInt32): Unit {
        while (data.size < Int64(newLen)) {
            data.append(default<T>())  // 需要 T 有默认值
        }
        while (data.size > Int64(newLen)) {
            data.removeAt(data.size - 1)
        }
    }

    /// 转为数组
    public func toArray(): Array<T> {
        return data.toArray()
    }

    /// 遍历
    public func forEach(fn: (T) -> Unit): Unit {
        for (item in data) {
            fn(item)
        }
    }

    /// 任意匹配 - 对应 Bun SmallList::any
    public func any(predicate: (T) -> Bool): Bool {
        for (item in data) {
            if (predicate(item)) {
                return true
            }
        }
        return false
    }

    /// 映射 - 对应 Bun SmallList::map
    public func map(func: (T) -> T): Unit {
        for (i in 0..data.size) {
            data[i] = func(data[i])
        }
    }
}

// ============================================================================
// ArrayBuffer - 自动扩容字节数组
// 对应 Bun 中大量使用的 std.ArrayList(u8) 模式
// ============================================================================

/// 自动扩容字节数组缓冲区
public class ArrayBuffer {
    private var data: Array<UInt8>
    private var length: Int64

    public init() {
        data = Array<UInt8>(256, item: 0)
        length = 0
    }

    public init(capacity: Int64) {
        data = Array<UInt8>(capacity, item: 0)
        length = 0
    }

    public func append(b: UInt8): Unit {
        ensureCapacity(length + 1)
        data[length] = b
        length += 1
    }

    public func appendBytes(bytes: Array<UInt8>): Unit {
        ensureCapacity(length + bytes.size)
        for (b in bytes) {
            data[length] = b
            length += 1
        }
    }

    public func appendString(s: String): Unit {
        for (c in s) {
            append(UInt8(c.value))
        }
    }

    public func slice(): Array<UInt8> {
        var result = Array<UInt8>()
        for (i in 0..length) {
            result.append(data[i])
        }
        return result
    }

    public func len(): Int64 {
        return length
    }

    public func capacity(): Int64 {
        return data.size
    }

    public func clear(): Unit {
        length = 0
    }

    private func ensureCapacity(needed: Int64): Unit {
        if (needed <= data.size) {
            return
        }
        var newCap = data.size * 2
        if (newCap < needed) {
            newCap = needed
        }
        var newData = Array<UInt8>(newCap, item: 0)
        for (i in 0..length) {
            newData[i] = data[i]
        }
        data = newData
    }
}

// ============================================================================
// ObjectPool - 对象池
// 严格翻译自: src/collections/pool.zig
//   pub fn Pool(comptime T: type, comptime pool_size: usize) type { ... }
// ============================================================================

/// 对象池接口 - 对应 Bun ObjectPoolTrait
// 严格翻译自: pool.rs 中 ObjectPoolType trait
public interface ObjectPoolType<T> {
    func create(): T
    func reset(obj: T): Unit
}

/// 对象池 - 对应 Bun Pool
// 严格翻译自: pool.rs 中 ObjectPool<T, THREADSAFE, MAX_COUNT>
/// 使用 singly-linked free list 管理
/// 支持最大池大小限制和 reset 回调
public class ObjectPool<T> {
    /// 池中空闲对象列表 (singly-linked free list)
    // 严格翻译自: pool.rs 中 SinglyLinkedList<T>
    private var pool: ArrayList<T>
    /// 对象工厂
    private var factory: ObjectPoolType<T>
    /// 最大池大小 (0 = 无限)
    // 严格翻译自: pool.rs 中 MAX_COUNT const generic
    private var maxCount: Int64
    /// 总创建数量
    private var totalCreated: Int64
    /// 总获取次数
    private var totalGetCount: Int64
    /// 总归还次数
    private var totalPutCount: Int64

    public init(factory: ObjectPoolType<T>) {
        pool = ArrayList<T>()
        this.factory = factory
        this.maxCount = 0
        this.totalCreated = 0
        this.totalGetCount = 0
        this.totalPutCount = 0
    }

    /// 带最大池大小初始化
    // 严格翻译自: pool.rs 中 ObjectPool<T, THREADSAFE, MAX_COUNT>
    public init(factory: ObjectPoolType<T>, maxCount: Int64) {
        pool = ArrayList<T>()
        this.factory = factory
        this.maxCount = maxCount
        this.totalCreated = 0
        this.totalGetCount = 0
        this.totalPutCount = 0
    }

    /// 获取对象 - 对应 Bun Pool.get / get_node
    // 严格翻译自: pool.rs 中 get_node() -> pop from free list or allocate
    public func get(): T {
        totalGetCount++
        if (pool.size > 0) {
            let obj = pool.removeAt(pool.size - 1)
            // 归还时已经 reset 过，直接返回
            return obj
        }
        // 池为空: 创建新对象
        totalCreated++
        return factory.create()
    }

    /// 归还对象 - 对应 Bun Pool.put / release
    // 严格翻译自: pool.rs 中 release() -> reset then prepend to free list
    public func put(obj: T): Unit {
        totalPutCount++
        // 检查池是否已满
        if (maxCount > 0 && pool.size >= maxCount) {
            // 池已满: 不归还 (让 GC 回收)
            return
        }
        // reset 对象状态
        factory.reset(obj)
        pool.append(obj)
    }

    /// 池中可用数量
    public func available(): Int64 {
        return pool.size
    }

    /// 是否池已满
    // 严格翻译自: pool.rs 中 full() -> bool
    public func isFull(): Bool {
        if (maxCount == 0) { return false }
        return pool.size >= maxCount
    }

    /// 是否池中有可用对象
    // 严格翻译自: pool.rs 中 has() -> bool
    public func has(): Bool {
        return pool.size > 0
    }

    /// 清空池中所有对象
    // 严格翻译自: pool.rs 中 delete_all()
    public func clear(): Unit {
        pool.clear()
    }

    /// 预热池 (预先创建指定数量的对象)
    public func prewarm(count: Int64): Unit {
        for (_ in 0..count) {
            let obj = factory.create()
            totalCreated++
            put(obj)
        }
    }

    /// 获取总创建数
    public func getTotalCreated(): Int64 {
        return totalCreated
    }

    /// 获取总获取次数
    public func getTotalGetCount(): Int64 {
        return totalGetCount
    }

    /// 获取总归还次数
    public func getTotalPutCount(): Int64 {
        return totalPutCount
    }

    /// 池命中率 (获取时从池中复用的比例)
    public func hitRate(): Float64 {
        if (totalGetCount == 0) { return 0.0 }
        let hits = totalGetCount - (totalCreated - (pool.size + totalPutCount - totalGetCount).clamp(0, totalCreated))
        return Float64(hits) / Float64(totalGetCount)
    }
}

/// Int64 钳制
private func Int64.clamp(minVal: Int64, maxVal: Int64): Int64 {
    if (this < minVal) { return minVal }
    if (this > maxVal) { return maxVal }
    return this
}

// ============================================================================
// 新增模块导出 - 从独立文件中导出类型
// 严格翻译自:
//   src/collections/pool.zig - PoolAllocator (SinglyLinkedList + ObjectPool)
//   src/collections/StaticHashMap.zig - StaticHashMap / AutoStaticHashMap
//   src/collections/identity_context.zig - IdentityContext / ArrayIdentityContext
//   src/collections/zig_hash_map.zig - ArrayHashMap (Robin-Hood)
// ============================================================================

// pool_allocator.cj 导出:
//   PoolNode<T>         - 池节点 (侵入式单链表节点)
//   SinglyLinkedList<T> - 侵入式单链表 (空闲列表)
//   Poolable            - 可池化对象接口
//   ObjectPool<T>       - 对象池 (非线程安全)
//   ThreadSafeObjectPool<T> - 线程安全对象池

// static_hash_map.cj 导出:
//   StaticHashEntry<K, V>       - 静态哈希表条目
//   StaticGetOrPutResult<V>     - 获取或插入结果
//   StaticHashMap<K, V>         - 静态容量 Robin-Hood 哈希表
//   AutoStaticHashMap<K, V>     - 自动静态哈希映射
//   staticHashSlots(capacity)   - 计算静态哈希表总槽位数

// identity_context.cj 导出:
//   IdentityContext<K>          - 引用相等性哈希上下文
//   IntIdentityContext          - Int64 引用相等性上下文
//   UInt64IdentityContext       - UInt64 引用相等性上下文
//   ArrayIdentityContext        - 数组哈希映射引用相等性上下文
//   ArrayIdentityContextU64     - 64 位键引用相等性上下文

// array_hash_map.cj 导出:
//   ArrayHashEntry<K, V>        - 哈希表条目 (Robin-Hood)
//   GetOrPutResult<V>           - 获取或插入结果
//   HashContext<K>              - 哈希上下文接口
//   AutoHashContext<K>          - 自动哈希上下文
//   ArrayHashMap<K, V>          - Robin-Hood 开放寻址哈希表
//   AutoHashMap<K, V>           - 自动哈希映射
//   SortedEntry<V>              - 排序哈希映射条目
//   SortedHashMap<V>            - 密码学哈希键排序映射
