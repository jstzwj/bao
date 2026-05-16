// bao_collections - ComptimeStringMap 编译期字符串映射
// 严格翻译自: src/js_parser/ComptimeStringMap.zig
//   Zig 在编译期构建完美哈希映射
//   仓颉使用排序数组 + 二分查找实现等价的只读字符串映射
package bao_collections

import bao_core.*

// ============================================================================
// ComptimeStringMap - 只读字符串映射
// 严格翻译自: src/js_parser/ComptimeStringMap.zig
//   pub fn ComptimeStringMap(comptime V: type, comptime kvs_list: ...)
//   Zig 使用编译期构建的完美哈希表
//   仓颉使用排序数组 + 二分查找实现 O(log n) 查找
//   用于解析器的关键字映射 (关键字 → Token类型)
// ============================================================================

/// 只读字符串映射条目
public class StringMapEntry {
    public let key: String
    public let value: Int64  // 对应 Bun 中的枚举值

    public init(key: String, value: Int64) {
        this.key = key
        this.value = value
    }
}

/// 只读字符串映射 - 对应 Bun ComptimeStringMap
/// 构建后不可修改，使用二分查找进行高效查询
/// 典型用途: JavaScript关键字 → Token类型映射
public class ComptimeStringMap {
    /// 排序后的条目数组
    private var entries: ArrayList<StringMapEntry>
    /// 是否已排序
    private var sorted: Bool

    /// 空映射
    public init() {
        entries = ArrayList<StringMapEntry>()
        sorted = true
    }

    /// 从键值对数组构建 - 对应 Bun ComptimeStringMap 构造
    public init(pairs: Array<(String, Int64)>) {
        entries = ArrayList<StringMapEntry>()
        for (pair in pairs) {
            entries.append(StringMapEntry(pair[0], pair[1]))
        }
        sorted = true
        sortEntries()
    }

    /// 从条目数组构建
    public init(entries: ArrayList<StringMapEntry>) {
        this.entries = ArrayList<StringMapEntry>()
        for (entry in entries) {
            this.entries.append(entry)
        }
        sorted = true
        sortEntries()
    }

    /// 查找 - 对应 Bun ComptimeStringMap.get
    /// 二分查找, O(log n)
    public func get(key: String): ?Int64 {
        if (entries.size == 0) {
            return Option<Int64>.None
        }
        ensureSorted()
        var lo: Int64 = 0
        var hi: Int64 = entries.size - 1
        while (lo <= hi) {
            let mid = lo + (hi - lo) / 2
            let midKey = entries[mid].key
            if (midKey == key) {
                return Some(entries[mid].value)
            } else if (midKey < key) {
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        return Option<Int64>.None
    }

    /// 是否包含键 - 对应 Bun ComptimeStringMap.has
    public func has(key: String): Bool {
        return get(key) != Option<Int64>.None
    }

    /// 条目数量
    public func count(): Int64 {
        return entries.size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return entries.size == 0
    }

    /// 获取所有键
    public func keys(): ArrayList<String> {
        let result = ArrayList<String>()
        for (entry in entries) {
            result.append(entry.key)
        }
        return result
    }

    /// 遍历
    public func forEach(fn: (String, Int64) -> Unit): Unit {
        for (entry in entries) {
            fn(entry.key, entry.value)
        }
    }

    // ---- 内部方法 ----

    /// 确保已排序
    private func ensureSorted(): Unit {
        if (!sorted) {
            sortEntries()
            sorted = true
        }
    }

    /// 对条目按键排序 (插入排序，适合小规模数据)
    private func sortEntries(): Unit {
        if (entries.size <= 1) {
            return
        }
        // 使用简单的冒泡排序 (条目通常不多)
        for (i in 0..entries.size - 1) {
            for (j in 0..entries.size - 1 - i) {
                if (entries[Int64(j)].key > entries[Int64(j + 1)].key) {
                    let tmp = entries[Int64(j)]
                    entries[Int64(j)] = entries[Int64(j + 1)]
                    entries[Int64(j + 1)] = tmp
                }
            }
        }
    }
}

// ============================================================================
// JavaScript 关键字映射
// 严格翻译自: src/js_parser/p.zig 中的关键字表
//   使用 ComptimeStringMap 将关键字字符串映射到 Token 枚举值
// ============================================================================

/// JavaScript 关键字 → Token 值映射
/// 对应 Bun 中使用 ComptimeStringMap 声明的关键字表
public class JsKeywordMap {
    private static let INSTANCE: ComptimeStringMap = buildMap()

    /// 查找关键字对应的 Token 值
    public static func get(keyword: String): ?Int64 {
        return INSTANCE.get(keyword)
    }

    /// 是否是关键字
    public static func isKeyword(word: String): Bool {
        return INSTANCE.has(word)
    }

    private static func buildMap(): ComptimeStringMap {
        // Token 值对应 bun_parser 的 token 枚举
        // 这里使用简化的编号系统
        let pairs = [
            // 关键字
            ("break", 1), ("case", 2), ("catch", 3), ("continue", 4),
            ("debugger", 5), ("default", 6), ("delete", 7), ("do", 8),
            ("else", 9), ("finally", 10), ("for", 11), ("function", 12),
            ("if", 13), ("in", 14), ("instanceof", 15), ("new", 16),
            ("return", 17), ("switch", 18), ("this", 19), ("throw", 20),
            ("try", 21), ("typeof", 22), ("var", 23), ("void", 24),
            ("while", 25), ("with", 26), ("class", 27), ("const", 28),
            ("enum", 29), ("export", 30), ("extends", 31), ("import", 32),
            ("super", 33), ("implements", 34), ("interface", 35),
            ("let", 36), ("package", 37), ("private", 38), ("protected", 39),
            ("public", 40), ("static", 41), ("yield", 42), ("abstract", 43),
            ("as", 44), ("asserts", 45), ("assert", 46), ("any", 47),
            ("async", 48), ("await", 49), ("boolean", 50), ("constructor", 51),
            ("declare", 52), ("get", 53), ("infer", 54), ("is", 55),
            ("keyof", 56), ("module", 57), ("namespace", 58), ("never", 59),
            ("readonly", 60), ("require", 61), ("number", 62),
            ("object", 63), ("set", 64), ("string", 65), ("symbol", 66),
            ("type", 67), ("from", 68), ("of", 69), ("out", 70),
            ("global", 71), ("bigint", 72), ("override", 73),
            ("satisfies", 74), ("using", 75), ("unique", 76),
            // 字面量
            ("true", 100), ("false", 101), ("null", 102), ("undefined", 103)
        ]
        return ComptimeStringMap(pairs)
    }
}
