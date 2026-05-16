// bao_collections - StringMap 字符串键值映射
// 严格翻译自: src/collections/string_map.rs
//   pub struct StringMap {
//       pub map: StringArrayHashMap<Box<[u8]>>,
//       pub dupe_keys: bool,
//   }
// Bun 设计:
//   StringArrayHashMap<Box<[u8]>> 的包装
//   dupe_keys 控制插入时是否克隆键字节
//   值总是被克隆
//   put = insert 别名 (Zig: pub const put = insert)
package bao_collections

import bao_core.*
import bao_hash.*

// ============================================================================
// StringMapEntry - 字符串映射条目
// 严格翻译自: StringArrayHashMap 中的键值对
// ============================================================================

/// 字符串映射条目 - 存储键值对
/// Bun: Box<[u8]> 存储字节数组
/// 仓颉: 使用 BaoString 作为键
public class StringMapEntry<V> {
    /// 键
    public var key: BaoString
    /// 值
    public var value: V

    public init(key: BaoString, value: V) {
        this.key = key
        this.value = value
    }
}

// ============================================================================
// StringMap<V> - 字符串键值映射
// 严格翻译自: src/collections/string_map.rs
//   pub struct StringMap {
//       pub map: StringArrayHashMap<Box<[u8]>>,
//       pub dupe_keys: bool,
//   }
//
// Bun 设计:
//   - A StringArrayHashMap<Box<[u8]>> plus a dupe_keys flag
//   - dupe_keys 控制 insert 是否克隆键字节
//   - 值总是被克隆 (Box::from(value))
//   - Zig init(allocator, dupe_keys) — allocator dropped (global mimalloc)
//   - 仓颉: 使用 ArrayList<StringMapEntry<V>> 作为底层存储
//     低于阈值线性扫描，高于阈值构建哈希索引
// ============================================================================

/// 字符串键值映射 - 严格对应 Bun StringMap
/// 使用字符串作为键的哈希映射，支持可选的键克隆
/// 和大小写不敏感匹配
///
/// Bun: StringArrayHashMap<Box<[u8]>> + dupe_keys
/// 仓颉: ArrayList<StringMapEntry<V>> + 哈希索引
public class StringMap<V> {
    /// 条目数组 - 对应 Bun map.entries
    private var entries: ArrayList<StringMapEntry<V>>
    /// 是否复制键字节 - 对应 Bun dupe_keys: bool
    /// Zig: dupe_keys 控制 insert 是否调用 allocator.dupe(u8, key)
    /// 仓颉: BaoString 本身是值类型，此标志影响 clone 行为
    public var dupeKeys: Bool
    /// 是否大小写不敏感 - 对应 Bun CaseInsensitiveAsciiStringArrayHashMap
    // 严格翻译自: array_hash_map.rs 中 CaseInsensitiveAsciiStringContext
    public var caseInsensitive: Bool
    /// 当前元素数量
    private var _size: Int64
    /// 哈希索引桶 - 当元素超过阈值时构建
    private var buckets: Array<Int64>
    /// 索引容量
    private var _capacity: Int64
    /// 是否已构建索引
    private var indexed: Bool
    /// 索引阈值 - 低于此值使用线性扫描
    // 严格翻译自: Bun StringArrayHashMap 使用 hashbrown，小规模时线性扫描更优
    private static let THRESHOLD: Int64 = 8

    /// 元素数量 - 对应 Bun StringMap::count
    public prop size: Int64 {
        get() { _size }
    }

    /// 默认构造 - 对应 Bun StringMap::default()
    /// Zig: init(allocator, dupe_keys=false)
    public init() {
        entries = ArrayList<StringMapEntry<V>>()
        dupeKeys = false
        caseInsensitive = false
        _size = 0
        _capacity = 16
        buckets = Array<Int64>(_capacity, item: -1)
        indexed = false
    }

    /// 带配置初始化 - 对应 Bun StringMap::init(dupe_keys)
    /// Zig: pub fn init(dupe_keys: bool) Self
    public init(dupeKeys: Bool) {
        entries = ArrayList<StringMapEntry<V>>()
        this.dupeKeys = dupeKeys
        this.caseInsensitive = false
        _size = 0
        _capacity = 16
        buckets = Array<Int64>(_capacity, item: -1)
        indexed = false
    }

    /// 带大小写不敏感选项初始化
    // 严格翻译自: CaseInsensitiveAsciiStringArrayHashMap
    public init(caseInsensitive: Bool) {
        entries = ArrayList<StringMapEntry<V>>()
        this.dupeKeys = false
        this.caseInsensitive = caseInsensitive
        _size = 0
        _capacity = 16
        buckets = Array<Int64>(_capacity, item: -1)
        indexed = false
    }

    /// 完整配置初始化
    public init(dupeKeys: Bool, caseInsensitive: Bool) {
        entries = ArrayList<StringMapEntry<V>>()
        this.dupeKeys = dupeKeys
        this.caseInsensitive = caseInsensitive
        _size = 0
        _capacity = 16
        buckets = Array<Int64>(_capacity, item: -1)
        indexed = false
    }

    // ========================================================================
    // 核心操作 - 对应 Bun StringMap 公共方法
    // ========================================================================

    /// 插入键值对 - 对应 Bun StringMap::insert
    /// Bun: dupe value; dupe key only when dupe_keys and the key is new
    /// Zig:
    ///   pub fn insert(&mut self, key: &[u8], value: &[u8]) -> Result<(), AllocError> {
    ///       let entry = self.map.get_or_put(key)?;
    ///       *entry.value_ptr = Box::from(value);
    ///       Ok(())
    ///   }
    public func insert(key: BaoString, value: V): Unit {
        let k = if (dupeKeys) { normalizeKey(key).clone() } else { normalizeKey(key) }
        // 先检查是否已存在
        let idx = findEntry(k)
        if (idx >= 0) {
            // 更新已存在的条目
            entries[Int64(idx)].value = value
            return
        }
        // 添加新条目
        let entry = StringMapEntry<V>(k, value)
        entries.append(entry)
        _size += 1
        if (_size >= THRESHOLD) {
            rebuildIndex()
        } else {
            indexed = false
        }
    }

    /// put = insert 别名 - 对应 Bun: pub const put = insert
    /// Zig: pub const put = insert;
    /// Bun: pub fn put(&mut self, key: &[u8], value: &[u8]) -> Result<(), AllocError>
    ///     { self.insert(key, value) }
    public func put(key: BaoString, value: V): Unit {
        insert(key, value)
    }

    /// 通过原生字符串插入
    public func put(key: String, value: V): Unit {
        put(BaoString(key), value)
    }

    /// 获取值 - 对应 Bun StringMap::get
    /// Zig:
    ///   pub fn get(&self, key: &[u8]) -> Option<&[u8]> {
    ///       self.map.get(key).map(|v| &**v)
    ///   }
    public func get(key: BaoString): ?V {
        if (_size == 0) { return None }
        let k = normalizeKey(key)
        let idx = findEntry(k)
        if (idx >= 0) {
            return Some(entries[Int64(idx)].value)
        }
        return None
    }

    /// 通过原生字符串获取
    public func get(key: String): ?V {
        return get(BaoString(key))
    }

    /// 获取或插入 - 对应 Bun StringArrayHashMap.get_or_put
    /// 返回 (值引用, 是否为新插入)
    public func getOrPut(key: BaoString, defaultValue: V): (V, Bool) {
        let k = normalizeKey(key)
        let idx = findEntry(k)
        if (idx >= 0) {
            return (entries[Int64(idx)].value, false)
        }
        insert(key, defaultValue)
        return (defaultValue, true)
    }

    /// 是否包含键 - 对应 Bun StringMap contains
    public func contains(key: BaoString): Bool {
        if (_size == 0) { return false }
        return findEntry(normalizeKey(key)) >= 0
    }

    /// 删除键值对
    public func remove(key: BaoString): ?V {
        if (_size == 0) { return None }
        let k = normalizeKey(key)
        let idx = findEntry(k)
        if (idx < 0) { return None }
        let removed = entries[Int64(idx)].value
        // swap-remove: 与最后一个交换并移除
        let lastIdx = entries.size - 1
        if (Int64(idx) != lastIdx) {
            entries[Int64(idx)] = entries[lastIdx]
        }
        entries.removeAt(lastIdx)
        _size -= 1
        if (_size >= THRESHOLD) {
            rebuildIndex()
        } else {
            indexed = false
        }
        return Some(removed)
    }

    // ========================================================================
    // 查询与遍历 - 对应 Bun StringMap::keys / values / count
    // ========================================================================

    /// 获取所有键 - 对应 Bun StringMap::keys -> &[Box<[u8]>]
    /// Zig: pub fn keys(&self) -> &[Box<[u8]>] { self.map.keys() }
    public func keys(): ArrayList<BaoString> {
        let result = ArrayList<BaoString>()
        for (i in 0..entries.size) {
            result.append(entries[i].key)
        }
        return result
    }

    /// 获取所有值 - 对应 Bun StringMap::values -> &[Box<[u8]>]
    /// Zig: pub fn values(&self) -> &[Box<[u8]>] { self.map.values() }
    public func values(): ArrayList<V> {
        let result = ArrayList<V>()
        for (i in 0..entries.size) {
            result.append(entries[i].value)
        }
        return result
    }

    /// 获取条目数 - 对应 Bun StringMap::count
    /// Zig: pub fn count(&self) -> usize { self.map.count() }
    public func count(): Int64 {
        return _size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return _size == 0
    }

    /// 清空
    public func clear(): Unit {
        entries.clear()
        _size = 0
        for (i in 0..buckets.size) {
            buckets[i] = -1
        }
        indexed = false
    }

    /// 遍历
    public func forEach(fn: (BaoString, V) -> Unit): Unit {
        for (i in 0..entries.size) {
            fn(entries[i].key, entries[i].value)
        }
    }

    /// 克隆 - 对应 Bun StringMap::clone
    /// Zig:
    ///   pub fn clone(&self) -> Result<Self, AllocError> {
    ///       Ok(Self { map: self.map.clone()?, dupe_keys: self.dupe_keys })
    ///   }
    public func clone(): StringMap<V> {
        let result = StringMap<V>(dupeKeys, caseInsensitive)
        for (i in 0..entries.size) {
            let e = entries[i]
            result.entries.append(StringMapEntry<V>(e.key.clone(), e.value))
        }
        result._size = _size
        return result
    }

    /// 排序键 - 对应 Bun StringMap 排序
    /// Zig: sort 方法接受 anytype ctx
    // TODO(port): StringMap::sort — wire once ArrayHashMap::sort lands
    public func sortKeys(): Unit {
        // 简单冒泡排序 (可优化为归并排序)
        for (i in 0..entries.size) {
            for (j in i + 1..entries.size) {
                if (entries[Int64(i)].key.toString() > entries[Int64(j)].key.toString()) {
                    let tmp = entries[Int64(i)]
                    entries[Int64(i)] = entries[Int64(j)]
                    entries[Int64(j)] = tmp
                }
            }
        }
        // 排序后重建索引
        if (_size >= THRESHOLD) {
            rebuildIndex()
        }
    }

    // ========================================================================
    // 内部方法
    // ========================================================================

    /// 规范化键 (大小写不敏感时转小写)
    // 严格翻译自: CaseInsensitiveAsciiStringContext.hash/toLower
    private func normalizeKey(key: BaoString): BaoString {
        if (caseInsensitive) {
            return BaoString(key.toString().toLower())
        }
        return key
    }

    /// 查找条目索引
    private func findEntry(key: BaoString): Int64 {
        if (!indexed || _size < THRESHOLD) {
            // 线性扫描
            for (i in 0..entries.size) {
                if (entries[i].key == key) {
                    return i
                }
            }
            return -1
        }
        // 哈希查找
        let h = hashKey(key)
        let bucketIdx = Int64(h % UInt64(buckets.size))
        var idx = buckets[bucketIdx]
        while (idx >= 0 && idx < entries.size) {
            if (entries[idx].key == key) {
                return idx
            }
            idx += 1
            if (idx >= entries.size) { break }
        }
        // 回退线性扫描
        for (i in 0..entries.size) {
            if (entries[i].key == key) {
                return i
            }
        }
        return -1
    }

    /// 哈希键值
    private func hashKey(key: BaoString): UInt64 {
        return WyHash.hash(key.toString())
    }

    /// 重建哈希索引
    private func rebuildIndex(): Unit {
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
        for (i in 0..entries.size) {
            let h = hashKey(entries[i].key)
            let bucketIdx = Int64(h % UInt64(buckets.size))
            buckets[bucketIdx] = i
        }
        indexed = true
    }
}
