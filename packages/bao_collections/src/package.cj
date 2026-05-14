// bao_collections - 集合类型
// 严格翻译自:
//   src/collections/string_map.rs - StringMap
//   src/collections/lib.rs - PriorityQueue, SmallList
//   src/collections/array_list.zig - ArrayList
//   src/collections/pool.zig - ObjectPool
package bao_collections

import bao_core.*

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
public class StringMap<V> {
    /// 底层映射表 - 对应 Bun map: StringArrayHashMap<Box<[u8]>>
    public var map: HashMap<BaoString, V>
    /// 是否复制键字节 - 对应 Bun dupe_keys: bool
    public var dupeKeys: Bool

    public init() {
        map = HashMap<BaoString, V>()
        dupeKeys = false
    }

    /// 带配置初始化 - 对应 Bun StringMap::init(dupe_keys)
    public init(dupeKeys: Bool) {
        map = HashMap<BaoString, V>()
        this.dupeKeys = dupeKeys
    }

    /// 克隆 - 对应 Bun StringMap::clone
    public func clone(): StringMap<V> {
        let result = StringMap<V>(dupeKeys)
        for ((k, v) in map) {
            result.map.put(k.clone(), v)
        }
        return result
    }

    /// 获取所有键 - 对应 Bun StringMap::keys → &[Box<[u8]>]
    public func keys(): ArrayList<BaoString> {
        return ArrayList<BaoString>(map.keys())
    }

    /// 获取所有值 - 对应 Bun StringMap::values → &[Box<[u8]>]
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
        let k = if (dupeKeys) { key.clone() } else { key }
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

    /// 获取值 - 对应 Bun StringMap::get → Option<&[u8]>
    public func get(key: BaoString): ?V {
        return map.get(key)
    }

    /// 通过原生字符串获取
    public func get(key: String): ?V {
        return get(BaoString(key))
    }

    /// 是否包含键
    public func contains(key: BaoString): Bool {
        return map.contains(key)
    }

    /// 删除键值对
    public func remove(key: BaoString): ?V {
        return map.remove(key)
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

    public init() {
        items = ArrayList<T>()
    }

    public init(capacity: Int64) {
        items = ArrayList<T>()
    }

    /// 元素数量 - 对应 Bun count() / len()
    public func count(): Int64 {
        return items.size
    }

    /// 添加元素并上滤 - 对应 Bun PriorityQueue::add
    /// Zig: add(elem) !void — push and sift-up
    public func add(elem: T, compare: (T, T) -> Int64): Unit {
        items.append(elem)
        var child = items.size - 1
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

    /// 弹出最小元素并下滤 - 对应 Bun PriorityQueue::remove_or_null
    /// Zig: removeOrNull() — pop min, sift-down; None when empty
    public func removeOrNull(compare: (T, T) -> Int64): ?T {
        if (items.size == 0) {
            return None
        }
        let lastIdx = items.size - 1
        swap(0, lastIdx)
        let out = items.removeAt(lastIdx)
        // sift-down
        let len = items.size
        var idx: Int64 = 0
        while (true) {
            let l = 2 * idx + 1
            let r = 2 * idx + 2
            var smallest = idx
            if (l < len && compare(items[l], items[smallest]) < 0) {
                smallest = l
            }
            if (r < len && compare(items[r], items[smallest]) < 0) {
                smallest = r
            }
            if (smallest == idx) {
                break
            }
            swap(idx, smallest)
            idx = smallest
        }
        return Some(out)
    }

    private func swap(a: Int64, b: Int64): Unit {
        if (a == b) { return }
        let tmp = items[a]
        items[a] = items[b]
        items[b] = tmp
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
public class SmallList<T> {
    private var data: ArrayList<T>

    public init() {
        data = ArrayList<T>()
    }

    public init(capacity: Int64) {
        data = ArrayList<T>()
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
public interface ObjectPoolType<T> {
    func create(): T
    func reset(obj: T): Unit
}

/// 对象池 - 对应 Bun Pool
public class ObjectPool<T> {
    private var pool: ArrayList<T>
    private var factory: ObjectPoolType<T>

    public init(factory: ObjectPoolType<T>) {
        pool = ArrayList<T>()
        this.factory = factory
    }

    /// 获取对象 - 对应 Bun Pool.get
    public func get(): T {
        if (pool.size > 0) {
            return pool.removeAt(pool.size - 1)
        }
        return factory.create()
    }

    /// 归还对象 - 对应 Bun Pool.put
    public func put(obj: T): Unit {
        factory.reset(obj)
        pool.append(obj)
    }

    /// 池中可用数量
    public func available(): Int64 {
        return pool.size
    }
}
