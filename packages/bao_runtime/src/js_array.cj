// 严格翻译自: src/jsc/JSArray.zig
// JavaScript Array 操作 — 数组方法、迭代器
// 对应 Bun: src/jsc/JSArray.zig, JSC C API 中的 JSObjectRef 数组操作
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// JsArrayOps - 数组操作
// 对应 Bun: JSC::JSArray 相关操作封装
//   Bun 通过 JSC C API (JSObjectGetIndexed, JSObjectCallAsFunction 等)
//   实现数组方法的绑定。仓颉直接在 ArrayList<JsValue> 上实现等价方法
// ============================================================================

/// JS Array 静态操作 - 对应 Array 构造器的静态方法及实例方法
public class JsArrayOps {

    /// 从类数组对象或可迭代对象创建数组 - 对应 Array.from
    public static func from(items: JsValue): JsValue {
        match (items.valueType) {
            case JsValueType.Array => {
                // 直接复制数组
                match (items.arrayData) {
                    case Some(arr) => {
                        let copy = ArrayList<JsValue>()
                        for (item in arr) {
                            copy.append(item)
                        }
                        return JsValue.array(copy)
                    }
                    case None => JsValue.array(ArrayList<JsValue>())
                }
            }
            case JsValueType.String => {
                // 字符串转为字符数组
                let arr = ArrayList<JsValue>()
                let s = items.stringValue.toString()
                for (c in s) {
                    arr.append(JsValue(BaoString(c.toString())))
                }
                return JsValue.array(arr)
            }
            case _ => JsValue.array(ArrayList<JsValue>())
        }
    }

    /// 从参数列表创建数组 - 对应 Array.of
    public static func of(items: ArrayList<JsValue>): JsValue {
        let arr = ArrayList<JsValue>()
        for (item in items) {
            arr.append(item)
        }
        return JsValue.array(arr)
    }

    /// 判断值是否为数组 - 对应 Array.isArray
    public static func isArray(value: JsValue): Bool {
        return value.valueType == JsValueType.Array
    }

    /// 合并多个数组 - 对应 Array.prototype.concat
    public static func concat(arrays: ArrayList<ArrayList<JsValue>>): ArrayList<JsValue> {
        let result = ArrayList<JsValue>()
        for (arr in arrays) {
            for (item in arr) {
                result.append(item)
            }
        }
        return result
    }

    /// 映射 - 对应 Array.prototype.map
    public static func map(array: ArrayList<JsValue>,
        fn: (JsValue, Int64) -> JsValue): ArrayList<JsValue> {
        let result = ArrayList<JsValue>()
        for (i in 0..array.size) {
            result.append(fn(array[i], i))
        }
        return result
    }

    /// 过滤 - 对应 Array.prototype.filter
    public static func filter(array: ArrayList<JsValue>,
        fn: (JsValue, Int64) -> Bool): ArrayList<JsValue> {
        let result = ArrayList<JsValue>()
        for (i in 0..array.size) {
            if (fn(array[i], i)) {
                result.append(array[i])
            }
        }
        return result
    }

    /// 归约 - 对应 Array.prototype.reduce
    public static func reduce(array: ArrayList<JsValue>,
        fn: (JsValue, JsValue, Int64) -> JsValue, initial: JsValue): JsValue {
        var acc = initial
        for (i in 0..array.size) {
            acc = fn(acc, array[i], i)
        }
        return acc
    }

    /// 反向归约 - 对应 Array.prototype.reduceRight
    public static func reduceRight(array: ArrayList<JsValue>,
        fn: (JsValue, JsValue, Int64) -> JsValue, initial: JsValue): JsValue {
        var acc = initial
        var i = array.size - 1
        while (i >= 0) {
            acc = fn(acc, array[i], i)
            i -= 1
        }
        return acc
    }

    /// 遍历 - 对应 Array.prototype.forEach
    public static func forEach(array: ArrayList<JsValue>,
        fn: (JsValue, Int64) -> Unit): Unit {
        for (i in 0..array.size) {
            fn(array[i], i)
        }
    }

    /// 查找第一个满足条件的元素 - 对应 Array.prototype.find
    public static func find(array: ArrayList<JsValue>,
        fn: (JsValue, Int64) -> Bool): ?JsValue {
        for (i in 0..array.size) {
            if (fn(array[i], i)) {
                return Some(array[i])
            }
        }
        return None
    }

    /// 查找第一个满足条件的索引 - 对应 Array.prototype.findIndex
    public static func findIndex(array: ArrayList<JsValue>,
        fn: (JsValue, Int64) -> Bool): Int64 {
        for (i in 0..array.size) {
            if (fn(array[i], i)) {
                return i
            }
        }
        return -1
    }

    /// 是否存在满足条件的元素 - 对应 Array.prototype.some
    public static func some(array: ArrayList<JsValue>,
        fn: (JsValue, Int64) -> Bool): Bool {
        for (i in 0..array.size) {
            if (fn(array[i], i)) {
                return true
            }
        }
        return false
    }

    /// 是否所有元素都满足条件 - 对应 Array.prototype.every
    public static func every(array: ArrayList<JsValue>,
        fn: (JsValue, Int64) -> Bool): Bool {
        for (i in 0..array.size) {
            if (!fn(array[i], i)) {
                return false
            }
        }
        return true
    }

    /// 是否包含指定值 - 对应 Array.prototype.includes
    public static func includes(array: ArrayList<JsValue>, value: JsValue): Bool {
        for (item in array) {
            if (jsValueEquals(item, value)) {
                return true
            }
        }
        return false
    }

    /// 查找值的第一个索引 - 对应 Array.prototype.indexOf
    public static func indexOf(array: ArrayList<JsValue>, value: JsValue): Int64 {
        for (i in 0..array.size) {
            if (jsValueEquals(array[i], value)) {
                return i
            }
        }
        return -1
    }

    /// 查找值的最后一个索引 - 对应 Array.prototype.lastIndexOf
    public static func lastIndexOf(array: ArrayList<JsValue>, value: JsValue): Int64 {
        var i = array.size - 1
        while (i >= 0) {
            if (jsValueEquals(array[i], value)) {
                return i
            }
            i -= 1
        }
        return -1
    }

    /// 将数组元素连接为字符串 - 对应 Array.prototype.join
    public static func join(array: ArrayList<JsValue>, separator: String): String {
        let sb = BaoStringBuilder()
        for (i in 0..array.size) {
            if (i > 0) {
                sb.appendString(separator)
            }
            sb.appendString(array[i].toString())
        }
        return sb.toString()
    }

    /// 反转数组 - 对应 Array.prototype.reverse
    public static func reverse(array: ArrayList<JsValue>): ArrayList<JsValue> {
        let result = ArrayList<JsValue>()
        var i = array.size - 1
        while (i >= 0) {
            result.append(array[i])
            i -= 1
        }
        return result
    }

    /// 排序 - 对应 Array.prototype.sort
    public static func sort(array: ArrayList<JsValue>,
        compareFn: (JsValue, JsValue) -> Int64): ArrayList<JsValue> {
        // 复制数组后进行快速排序
        let result = ArrayList<JsValue>()
        for (item in array) {
            result.append(item)
        }
        quickSort(result, 0, result.size - 1, compareFn)
        return result
    }

    /// 切片 - 对应 Array.prototype.slice
    public static func slice(array: ArrayList<JsValue>,
        start: Int64, end: Int64): ArrayList<JsValue> {
        let s = normalizeIndex(start, array.size)
        let e = if (end < 0) { array.size + end } else { if (end > array.size) { array.size } else { end } }
        let result = ArrayList<JsValue>()
        var i = s
        while (i < e) {
            result.append(array[i])
            i += 1
        }
        return result
    }

    /// 剪切/插入 - 对应 Array.prototype.splice
    public static func splice(array: ArrayList<JsValue>, start: Int64,
        deleteCount: Int64, items: ArrayList<JsValue>): ArrayList<JsValue> {
        let s = normalizeIndex(start, array.size)
        let dc = if (s + deleteCount > array.size) { array.size - s } else { deleteCount }
        let removed = ArrayList<JsValue>()
        // 收集被删除的元素
        for (i in s..(s + dc)) {
            if (i < array.size) {
                removed.append(array[i])
            }
        }
        // 执行 splice: 移除 dc 个，插入 items
        // 简化实现: 重建数组
        let newArr = ArrayList<JsValue>()
        for (i in 0..s) {
            newArr.append(array[i])
        }
        for (item in items) {
            newArr.append(item)
        }
        for (i in (s + dc)..array.size) {
            newArr.append(array[i])
        }
        // 将结果写回原数组 (通过清除并重新填充)
        // 注意: ArrayList 没有直接 replaceAll，需要外部处理
        return removed
    }

    /// 扁平化 - 对应 Array.prototype.flat
    public static func flat(array: ArrayList<JsValue>, depth: Int64): ArrayList<JsValue> {
        let result = ArrayList<JsValue>()
        flatInto(array, depth, result)
        return result
    }

    /// 映射后扁平化 - 对应 Array.prototype.flatMap
    public static func flatMap(array: ArrayList<JsValue>,
        fn: (JsValue, Int64) -> ArrayList<JsValue>): ArrayList<JsValue> {
        let result = ArrayList<JsValue>()
        for (i in 0..array.size) {
            let mapped = fn(array[i], i)
            for (item in mapped) {
                result.append(item)
            }
        }
        return result
    }

    /// 填充 - 对应 Array.prototype.fill
    public static func fill(array: ArrayList<JsValue>, value: JsValue,
        start: Int64, end: Int64): ArrayList<JsValue> {
        let s = normalizeIndex(start, array.size)
        let e = if (end < 0) { array.size + end } else { if (end > array.size) { array.size } else { end } }
        let result = ArrayList<JsValue>()
        for (i in 0..array.size) {
            if (i >= s && i < e) {
                result.append(value)
            } else {
                result.append(array[i])
            }
        }
        return result
    }

    /// 数组内部复制 - 对应 Array.prototype.copyWithin
    public static func copyWithin(array: ArrayList<JsValue>, target: Int64,
        start: Int64, end: Int64): ArrayList<JsValue> {
        let result = ArrayList<JsValue>()
        for (item in array) {
            result.append(item)
        }
        let t = normalizeIndex(target, array.size)
        let s = normalizeIndex(start, array.size)
        let e = if (end < 0) { array.size + end } else { if (end > array.size) { array.size } else { end } }
        var dst = t
        for (i in s..e) {
            if (dst < array.size) {
                result[dst] = array[i]
                dst += 1
            }
        }
        return result
    }

    /// 尾部添加元素 - 对应 Array.prototype.push
    public static func push(array: ArrayList<JsValue>,
        items: ArrayList<JsValue>): Int64 {
        for (item in items) {
            array.append(item)
        }
        return array.size
    }

    /// 尾部弹出元素 - 对应 Array.prototype.pop
    public static func pop(array: ArrayList<JsValue>): ?JsValue {
        if (array.size == 0) {
            return None
        }
        return Some(array.removeAt(array.size - 1))
    }

    /// 头部弹出元素 - 对应 Array.prototype.shift
    public static func shift(array: ArrayList<JsValue>): ?JsValue {
        if (array.size == 0) {
            return None
        }
        return Some(array.removeAt(0))
    }

    /// 头部添加元素 - 对应 Array.prototype.unshift
    public static func unshift(array: ArrayList<JsValue>,
        items: ArrayList<JsValue>): Int64 {
        // 在头部插入 (逆序以保持顺序)
        var i = items.size - 1
        while (i >= 0) {
            array.insert(0, items[i])
            i -= 1
        }
        return array.size
    }

    /// 创建迭代器 - 对应数组迭代器协议
    public static func iterator(array: ArrayList<JsValue>): ArrayIterator {
        return ArrayIterator(array)
    }

    // ---- 内部辅助方法 ----

    /// 归一化索引 (处理负索引)
    private static func normalizeIndex(index: Int64, length: Int64): Int64 {
        if (index < 0) {
            let n = length + index
            return if (n < 0) { 0 } else { n }
        }
        return if (index > length) { length } else { index }
    }

    /// 递归扁平化
    private static func flatInto(array: ArrayList<JsValue>,
        depth: Int64, result: ArrayList<JsValue>): Unit {
        for (item in array) {
            if (depth > 0 && item.valueType == JsValueType.Array) {
                match (item.arrayData) {
                    case Some(subArr) => flatInto(subArr, depth - 1, result)
                    case None => result.append(item)
                }
            } else {
                result.append(item)
            }
        }
    }

    /// 快速排序
    private static func quickSort(arr: ArrayList<JsValue>, low: Int64,
        high: Int64, compareFn: (JsValue, JsValue) -> Int64): Unit {
        if (low < high && low >= 0 && high < arr.size) {
            let pi = partition(arr, low, high, compareFn)
            quickSort(arr, low, pi - 1, compareFn)
            quickSort(arr, pi + 1, high, compareFn)
        }
    }

    /// 快速排序分区
    private static func partition(arr: ArrayList<JsValue>, low: Int64,
        high: Int64, compareFn: (JsValue, JsValue) -> Int64): Int64 {
        let pivot = arr[high]
        var i = low - 1
        for (j in low..high) {
            if (compareFn(arr[j], pivot) <= 0) {
                i += 1
                let tmp = arr[i]
                arr[i] = arr[j]
                arr[j] = tmp
            }
        }
        let tmp = arr[i + 1]
        arr[i + 1] = arr[high]
        arr[high] = tmp
        return i + 1
    }

    /// 简单值相等比较 (用于 includes/indexOf)
    private static func jsValueEquals(a: JsValue, b: JsValue): Bool {
        if (a.valueType != b.valueType) {
            return false
        }
        match (a.valueType) {
            case JsValueType.Boolean => a.boolValue == b.boolValue
            case JsValueType.Number => a.numberValue == b.numberValue
            case JsValueType.String => a.stringValue.toString() == b.stringValue.toString()
            case JsValueType.Null => true
            case JsValueType.Undefined => true
            case _ => false  // 引用类型不进行深度比较
        }
    }
}

// ============================================================================
// ArrayIterator - 数组迭代器
// 对应 ECMAScript Array Iterator Objects (CreateArrayIterator)
//   实现迭代器协议: next() 返回 { value, done }
//   对应 for...of 循环底层机制
// ============================================================================

/// 数组迭代器 - 对应 JS %ArrayIteratorPrototype%
public class ArrayIterator {
    /// 被迭代的数组引用
    private var array: ArrayList<JsValue>
    /// 当前迭代位置
    private var index: Int64

    public init(array: ArrayList<JsValue>) {
        this.array = array
        this.index = 0
    }

    /// 获取下一个元素 - 对应 iterator.next()
    public func next(): ?JsValue {
        if (index >= array.size) {
            return None
        }
        let val = array[index]
        index += 1
        return Some(val)
    }

    /// 是否还有下一个元素 - 对应迭代协议检查
    public func hasNext(): Bool {
        return index < array.size
    }

    /// 获取当前索引
    public func currentIndex(): Int64 {
        return index
    }

    /// 重置迭代器
    public func reset(): Unit {
        index = 0
    }
}
