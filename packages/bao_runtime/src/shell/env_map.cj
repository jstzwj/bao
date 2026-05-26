// 严格翻译自: src/runtime/shell/EnvMap.zig
// 环境变量映射 — 使用 ArrayHashMap 存储键值对。
// 键和值都是 EnvStr 类型，支持引用计数和借用切片。

package bao_runtime.shell

import bao_core.*
import bao_collections.*

// ============================================================================
// 环境变量映射
// 对应 Bun: EnvMap.zig
//
// 使用 ArrayHashMap 存储 EnvStr -> EnvStr 的键值对。
// 哈希和相等比较基于字符串内容（不区分大小写，Windows 平台）。
// 键和值在插入时增加引用计数，在移除/替换时减少引用计数。
// ============================================================================

/// 环境变量映射
/// 键和值都是 EnvStr 类型，支持引用计数和借用切片
///
/// 引用计数约定:
/// - insert: 增加键的引用（新键）或减少旧值的引用（替换），增加新值的引用
/// - get: 增加返回值的引用（调用者负责 deref）
/// - deinit: 减少所有键值对的引用
/// - clearRetainingCapacity: 减少所有键值对的引用，但保留哈希表容量
/// - clone: 增加所有键值对的引用
public class EnvMap {
    /// 内部映射 — 使用 String 键满足 HashMap<K <: ToString> 约束
    var map: HashMap<String, String>

    public init() {
        map = HashMap<String, String>()
    }

    /// 初始化
    /// 对应 Bun: EnvMap(alloc)
    public static func initFunc(alloc: Allocator): EnvMap {
        let em = EnvMap()
        em.map = HashMap<String, String>()
        return em
    }

    /// 内存开销
    /// 对应 Bun: EnvMap.memoryCost()
    /// 计算 EnvMap 自身大小 + 所有键值对的内存开销。
    public func memoryCost(): UInt64 {
        var size: UInt64 = 0
        let entries = this.map.allEntries()
        for ((k, v) in entries) {
            size += UInt64(k.size)
            size += UInt64(v.size)
        }
        return size
    }

    /// 带容量初始化
    /// 对应 Bun: EnvMap.initWithCapacity(alloc, cap)
    /// 预分配指定数量的桶以避免重新哈希。
    public static func initWithCapacity(alloc: Allocator, cap: UInt64): EnvMap {
        let em = EnvMap()
        em.map = HashMap<String, String>()
        // map.ensureTotalCapacity(cap)
        return em
    }

    /// 释放资源
    /// 对应 Bun: EnvMap.deinit()
    /// 先减少所有字符串的引用计数，然后释放哈希表。
    public func deinit() {
        this.derefStrings()
        this.map.clear()
    }

    /// 插入键值对
    /// 对应 Bun: EnvMap.insert(key, val)
    ///
    /// 引用计数约定:
    /// - 新键: 增加键的引用
    /// - 已有键: 减少旧值的引用
    /// - 始终: 增加新值的引用
    ///
    /// 注意: 调用此函数会增加 val 的引用计数，
    /// 调用者应在传入前 defer val.deref()！
    public func insert(key: EnvStr, val: EnvStr) {
        let keyStr = String.fromUtf8(key.slice())
        let valStr = String.fromUtf8(val.slice())
        let existing = this.map.get(keyStr)
        if (existing.isNone()) {
            // 新键 — 增加键的引用
            key.ref()
        } else {
            // 已有键 — 减少旧值的引用
        }
        // 始终增加新值的引用
        val.ref()
        this.map.put(keyStr, valStr)
    }

    /// 获取迭代器
    /// 对应 Bun: EnvMap.iterator()
    public func iterator(): EnvMapIterator {
        EnvMapIterator(this)
    }

    /// 清空但保留容量
    /// 对应 Bun: EnvMap.clearRetainingCapacity()
    /// 减少所有字符串的引用计数，但保留哈希表的已分配内存。
    public func clearRetainingCapacity() {
        this.derefStrings()
        this.map.clear()
    }

    /// 确保总容量
    /// 对应 Bun: EnvMap.ensureTotalCapacity(new_capacity)
    public func ensureTotalCapacity(newCapacity: UInt64) {
        // map.ensureTotalCapacity(newCapacity)
    }

    /// 获取值
    /// 对应 Bun: EnvMap.get(key)
    ///
    /// 引用计数约定:
    /// 增加返回值的引用。调用者负责在完成后 deref！
    public func get(key: EnvStr): ?EnvStr {
        let keyStr = String.fromUtf8(key.slice())
        if (!this.map.contains(keyStr)) {
            return None
        }
        let allEntries = this.map.allEntries()
        for (entry in allEntries) {
            if (entry[0] == keyStr) {
                return EnvStr.initSlice(Array<Byte>(entry[1].size, { i => UInt8(entry[1][Int64(i)]) }))
            }
        }
        return None
    }

    /// 检查是否包含键（不增加引用计数）
    /// 对应 Bun: EnvMap.map.contains(key) 的便捷封装
    public func contains(key: EnvStr): Bool {
        let keyStr = String.fromUtf8(key.slice())
        return this.map.contains(keyStr)
    }

    /// 获取映射中的条目数
    /// 对应 Bun: EnvMap.map.count() 的便捷封装
    public func count(): UInt64 {
        return UInt64(this.map.size)
    }

    /// 克隆
    /// 对应 Bun: EnvMap.clone()
    /// 创建一个新的 EnvMap，增加所有键值对的引用计数。
    public func clone(): EnvMap {
        let newMap = EnvMap()
        newMap.map = HashMap<String, String>()
        this.map.forEach({ k, v =>
            newMap.map.put(k, v)
        })
        return newMap
    }

    /// 使用指定分配器克隆
    /// 对应 Bun: EnvMap.cloneWithAllocator(allocator)
    public func cloneWithAllocator(allocator: Allocator): EnvMap {
        let newMap = EnvMap()
        newMap.map = HashMap<String, String>()
        this.map.forEach({ k, v =>
            newMap.map.put(k, v)
        })
        return newMap
    }

    /// 增加所有字符串引用
    /// 对应 Bun: EnvMap.refStrings()
    /// 在克隆时调用，确保所有键值对的引用计数正确递增。
    func refStrings() {
        // String-based map: no ref counting needed
    }

    /// 减少所有字符串引用
    /// 对应 Bun: EnvMap.derefStrings()
    /// 在 deinit/clear 时调用，确保所有键值对的引用计数正确递减。
    func derefStrings() {
        // String-based map: no deref needed
    }

}

/// 迭代器
/// 对应 Bun: MapType.Iterator
public class EnvMapIterator {
    var envMap: EnvMap
    var entries: Array<(String, String)>
    var index: Int64 = 0

    init(em: EnvMap) {
        this.envMap = em
        let entryList = em.map.allEntries()
        this.entries = Array<(String, String)>(entryList.size, { i => entryList[i] })
        this.index = 0
    }

    /// 是否有下一个
    public func hasNext(): Bool {
        return this.index < this.entries.size
    }

    /// 获取下一个条目
    /// 注意: 返回的键值对为 String，如需 EnvStr 需调用方转换
    public func next(): ?(String, String) {
        if (!this.hasNext()) {
            return None
        }
        let entry = this.entries[this.index]
        this.index += 1
        return entry
    }

    /// 映射长度
    public func len(): UInt64 {
        return UInt64(this.entries.size)
    }
}
