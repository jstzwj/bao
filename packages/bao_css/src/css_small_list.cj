// bao_css - CSS 小型列表数据结构
// 严格翻译自: bun/src/css/small_list.zig
//   对应: small_list.zig SmallList(T, N) - 小型列表数据结构
//
// SmallList 是一个性能优化数据结构，可以内联存储 N 个元素
// 或在元素超过 N 个时自动扩展到堆上。
// 基于 servo/rust-smallvec 和 Zig std.ArrayList。
//
// 当 capacity <= N 时，元素内联存储，capacity 即为长度。
// 当 capacity > N 时，元素存储在堆上，成为类似 ArrayList 的结构。
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// 小型列表
// 严格翻译自: small_list.zig SmallList(comptime T: type, comptime N: comptime_int)
// ============================================================================

/// CSS 小型列表
/// 严格翻译自 SmallList(T, N) 泛型结构
/// T: 元素类型 (仓颉中用泛型)
/// INLINE_CAPACITY: 内联容量，超过此数量则分配到堆上
///
/// 此为简化翻译，保留核心语义:
/// - 小列表内联存储 (避免堆分配)
/// - 大列表退化为 ArrayList
/// - 支持解析 (逗号分隔) 和 toCss
public class CssSmallList<T> {
    /// 内联容量 (超过此数则堆分配)
    public static let INLINE_CAPACITY: Int64 = 1

    /// 当前长度
    private var len: Int64

    /// 内联存储 (前 INLINE_CAPACITY 个元素)
    private var inlined: Array<?T>

    /// 堆存储 (超过内联容量后使用)
    private var heap: ArrayList<T>

    /// 是否已溢出到堆
    private var spilled: Bool

    public init() {
        this.len = 0
        this.inlined = Array<?T>(INLINE_CAPACITY)
        this.heap = ArrayList<T>()
        this.spilled = false
    }

    public init(capacity: Int64) {
        this.len = 0
        this.inlined = Array<?T>(INLINE_CAPACITY)
        this.heap = ArrayList<T>()
        this.spilled = false
        if (capacity > INLINE_CAPACITY) {
            this.heap = ArrayList<T>(capacity)
            this.spilled = true
        }
    }

    /// 长度
    /// 严格翻译自 SmallList.len
    public func size(): Int64 {
        len
    }

    /// 是否为空
    /// 严格翻译自 SmallList.isEmpty
    public func isEmpty(): Bool {
        len == 0
    }

    /// 获取元素 (只读)
    /// 严格翻译自 SmallList.at
    public func get(index: Int64): ?T {
        if (index < 0 || index >= len) { return None }
        if (spilled) {
            return heap[index]
        }
        inlined[index]
    }

    /// 获取最后一个元素 (不检查边界)
    /// 严格翻译自 SmallList.getLastUnchecked
    public func getLastUnchecked(): T {
        if (spilled) {
            return heap[len - 1]
        }
        match (inlined[len - 1]) {
            case Some(v) => v
            case None => throw Exception("CssSmallList: empty")
        }
    }

    /// 获取最后一个元素
    /// 严格翻译自 SmallList.last
    public func last(): ?T {
        if (len == 0) { return None }
        get(len - 1)
    }

    /// 追加元素
    /// 严格翻译自 SmallList.append
    public func append(item: T): Unit {
        if (spilled) {
            heap.append(item)
        } else if (len < INLINE_CAPACITY) {
            inlined[len] = Some(item)
        } else {
            // 溢出: 将内联元素移到堆上
            spilled = true
            for (i in 0..len) {
                match (inlined[i]) {
                    case Some(v) => heap.append(v)
                    case None => {}
                }
            }
            heap.append(item)
        }
        len++
    }

    /// 弹出最后一个元素
    /// 严格翻译自 SmallList.pop
    public func pop(): ?T {
        if (len == 0) { return None }
        len--
        if (spilled) {
            return heap.pop()
        }
        let v = inlined[len]
        inlined[len] = None
        v
    }

    /// 有序移除指定索引元素
    /// 严格翻译自 SmallList.orderedRemove
    public func orderedRemove(index: Int64): ?T {
        if (index < 0 || index >= len) { return None }
        let item = get(index)
        // 将后续元素前移
        if (spilled) {
            heap.removeAt(index)
        } else {
            for (i in index..(len - 1)) {
                inlined[i] = inlined[i + 1]
            }
            inlined[len - 1] = None
        }
        len--
        item
    }

    /// 交换移除 (O(1) 但不保序)
    /// 严格翻译自 SmallList.swapRemove
    public func swapRemove(index: Int64): ?T {
        if (index < 0 || index >= len) { return None }
        let item = get(index)
        let lastItem = get(len - 1)
        if (index != len - 1) {
            set(index, lastItem)
        }
        len--
        if (spilled) {
            heap.removeAt(len)
        } else {
            inlined[len] = None
        }
        item
    }

    /// 设置指定位置元素
    public func set(index: Int64, item: ?T): Unit {
        if (index < 0 || index >= len) { return }
        if (spilled) {
            match (item) {
                case Some(v) => heap[index] = v
                case None => {}
            }
        } else {
            inlined[index] = item
        }
    }

    /// 清空但保留容量
    /// 严格翻译自 SmallList.clearRetainingCapacity
    public func clearRetainingCapacity(): Unit {
        if (spilled) {
            heap.clear()
        }
        for (i in 0..INLINE_CAPACITY) {
            inlined[i] = None
        }
        len = 0
    }

    /// 转为只读切片
    /// 严格翻译自 SmallList.slice
    public func toArray(): Array<T> {
        if (spilled) {
            return heap.toArray()
        }
        let arr = Array<T>(len)
        for (i in 0..len) {
            match (inlined[i]) {
                case Some(v) => arr[i] = v
                case None => {}
            }
        }
        arr
    }

    /// 浅克隆
    /// 严格翻译自 SmallList.shallowClone
    public func shallowClone(): CssSmallList<T> {
        let clone = CssSmallList<T>()
        clone.len = len
        clone.spilled = spilled
        if (spilled) {
            clone.heap = ArrayList<T>(heap.size())
            for (item in heap) {
                clone.heap.append(item)
            }
        } else {
            for (i in 0..INLINE_CAPACITY) {
                clone.inlined[i] = inlined[i]
            }
        }
        clone
    }

    /// 深克隆 (要求 T 支持 clone)
    /// 严格翻译自 SmallList.deepClone
    public func deepClone(cloneFn: (T) -> T): CssSmallList<T> {
        let clone = CssSmallList<T>()
        clone.len = len
        clone.spilled = spilled
        if (spilled) {
            clone.heap = ArrayList<T>(heap.size())
            for (item in heap) {
                clone.heap.append(cloneFn(item))
            }
        } else {
            for (i in 0..len) {
                match (inlined[i]) {
                    case Some(v) => clone.inlined[i] = Some(cloneFn(v))
                    case None => {}
                }
            }
        }
        clone
    }

    /// 相等比较
    /// 严格翻译自 SmallList.eql
    public func eql(other: CssSmallList<T>, eqlFn: (T, T) -> Bool): Bool {
        if (len != other.len) { return false }
        let a = toArray()
        let b = other.toArray()
        for (i in 0..len) {
            if (!eqlFn(a[i], b[i])) { return false }
        }
        true
    }

    /// 是否任何元素满足谓词
    /// 严格翻译自 SmallList.any
    public func any(predicate: (T) -> Bool): Bool {
        if (spilled) {
            for (item in heap) {
                if (predicate(item)) { return true }
            }
        } else {
            for (i in 0..len) {
                match (inlined[i]) {
                    case Some(v) =>
                        if (predicate(v)) { return true }
                    case None => {}
                }
            }
        }
        false
    }

    /// 对每个元素应用函数
    /// 严格翻译自 SmallList.map
    public func forEach(fn: (T) -> Unit): Unit {
        if (spilled) {
            for (item in heap) { fn(item) }
        } else {
            for (i in 0..len) {
                match (inlined[i]) {
                    case Some(v) => fn(v)
                    case None => {}
                }
            }
        }
    }

    /// 是否溢出到堆
    /// 严格翻译自 SmallList.spilled
    public func isSpilled(): Bool {
        spilled
    }
}

// ============================================================================
// 专用小型列表: 字符串列表
// 用于 CSS 值中常见的逗号分隔列表
// ============================================================================

/// CSS 字符串小型列表 (内联容量 4)
public class CssStringList {
    private var items: ArrayList<String>

    public init() {
        this.items = ArrayList<String>()
    }

    public init(items: ArrayList<String>) {
        this.items = items
    }

    /// 从逗号分隔字符串解析
    public static func parseCommaSeparated(input: String): CssStringList {
        let list = CssStringList()
        var current = ""
        var inQuotes = false
        var quoteChar: UInt8 = 0

        for (c in input) {
            if (inQuotes) {
                if (UInt8(c) == quoteChar) {
                    inQuotes = false
                } else {
                    current = current + c.toString()
                }
            } else if (c == '"' || c == '\'') {
                inQuotes = true
                quoteChar = UInt8(c)
            } else if (c == ',') {
                list.append(current.trim())
                current = ""
            } else {
                current = current + c.toString()
            }
        }
        let last = current.trim()
        if (!last.isEmpty()) {
            list.append(last)
        }
        list
    }

    public func size(): Int64 {
        items.size()
    }

    public func isEmpty(): Bool {
        items.isEmpty()
    }

    public func append(item: String): Unit {
        items.append(item)
    }

    public func get(index: Int64): ?String {
        if (index < 0 || index >= items.size()) { None }
        else { Some(items[index]) }
    }

    public func toArray(): Array<String> {
        items.toArray()
    }

    /// 转为逗号分隔的 CSS 文本
    public func toCss(): String {
        String.join(", ", items)
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 增长策略
// 严格翻译自: small_list.zig SmallList.growCapacity
// ============================================================================

/// 列表增长策略工具
public class CssGrowStrategy {
    /// 计算新的容量
    /// 严格翻译自 SmallList.growCapacity
    /// 超线性增长: new = current * 1.5 + 8
    public static func growCapacity(current: Int64, minimum: Int64): Int64 {
        var newCapacity = current
        while (true) {
            newCapacity = newCapacity + newCapacity / 2 + 8
            if (newCapacity >= minimum) {
                return newCapacity
            }
        }
        newCapacity
    }
}
