// bao_collections - 集合类型
// 对应 Bun: src/collections/
// Bun 在 Zig 中实现了自定义的 HashMap/HashSet 以优化性能
// 仓颉标准库已有集合类型，此处提供与 Bun 兼容的包装
package bao_collections

import bao_core.*

// ============================================================================
// StringMap - 字符串键映射
// 对应 Bun: src/collections/StringMap.zig
// Bun 使用自定义的 string hash map 优化字符串查找
// ============================================================================

/// 字符串键值映射
public class StringMap<V> {
    private var map: HashMap<BaoString, V>
    private var hashMap: HashMap<UInt64, V>  // 哈希快速查找

    public init() {
        map = HashMap<BaoString, V>()
        hashMap = HashMap<UInt64, V>()
    }

    public init(capacity: Int64) {
        map = HashMap<BaoString, V>()
        hashMap = HashMap<UInt64, V>()
    }

    /// 插入键值对
    public func put(key: BaoString, value: V): Unit {
        let hashed = HashedString(key)
        map.put(key, value)
        hashMap.put(hashed.hash, value)
    }

    /// 通过原生字符串插入
    public func put(key: String, value: V): Unit {
        put(BaoString(key), value)
    }

    /// 获取值
    public func get(key: BaoString): ?V {
        let hashed = HashedString(key)
        return hashMap.get(hashed.hash)
    }

    /// 通过原生字符串获取
    public func get(key: String): ?V {
        return get(BaoString(key))
    }

    /// 是否包含键
    public func contains(key: BaoString): Bool {
        return get(key) != None
    }

    /// 是否包含键
    public func contains(key: String): Bool {
        return contains(BaoString(key))
    }

    /// 删除键
    public func remove(key: BaoString): ?V {
        let hashed = HashedString(key)
        let val = hashMap.remove(hashed.hash)
        map.remove(key)
        return val
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
        hashMap.clear()
    }

    /// 获取所有键
    public func keys(): ArrayList<BaoString> {
        return ArrayList<BaoString>(map.keys())
    }

    /// 获取所有值
    public func values(): ArrayList<V> {
        return ArrayList<V>(map.values())
    }
}

// ============================================================================
// StringSet - 字符串集合
// 对应 Bun: src/collections/StringSet.zig
// ============================================================================

/// 字符串集合
public class StringSet {
    private var set: HashSet<BaoString>
    private var hashSet: HashSet<UInt64>

    public init() {
        set = HashSet<BaoString>()
        hashSet = HashSet<UInt64>()
    }

    /// 插入字符串
    public func insert(value: BaoString): Bool {
        let hashed = HashedString(value)
        if (hashSet.contains(hashed.hash)) {
            return false
        }
        set.put(value)
        hashSet.put(hashed.hash)
        return true
    }

    /// 插入原生字符串
    public func insert(value: String): Bool {
        return insert(BaoString(value))
    }

    /// 是否包含
    public func contains(value: BaoString): Bool {
        let hashed = HashedString(value)
        return hashSet.contains(hashed.hash)
    }

    /// 是否包含
    public func contains(value: String): Bool {
        return contains(BaoString(value))
    }

    /// 删除
    public func remove(value: BaoString): Bool {
        let hashed = HashedString(value)
        if (!hashSet.contains(hashed.hash)) {
            return false
        }
        set.remove(value)
        hashSet.remove(hashed.hash)
        return true
    }

    /// 获取大小
    public func size(): Int64 {
        return set.size
    }

    /// 清空
    public func clear(): Unit {
        set.clear()
        hashSet.clear()
    }
}

// ============================================================================
// ArrayBuffer - 自动扩容字节数组
// 对应 Bun 中大量使用的 std.ArrayList(u8)
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

    /// 写入字节
    public func append(b: UInt8): Unit {
        ensureCapacity(length + 1)
        data[length] = b
        length += 1
    }

    /// 写入字节数组
    public func appendBytes(bytes: Array<UInt8>): Unit {
        ensureCapacity(length + bytes.size)
        for (b in bytes) {
            data[length] = b
            length += 1
        }
    }

    /// 写入字符串
    public func appendString(s: String): Unit {
        for (c in s) {
            append(UInt8(c.value))
        }
    }

    /// 获取有效数据
    public func slice(): Array<UInt8> {
        var result = Array<UInt8>()
        for (i in 0..length) {
            result.append(data[i])
        }
        return result
    }

    /// 获取长度
    public func len(): Int64 {
        return length
    }

    /// 获取容量
    public func capacity(): Int64 {
        return data.size
    }

    /// 清空
    public func clear(): Unit {
        length = 0
    }

    /// 确保容量足够
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
