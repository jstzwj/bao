// 严格翻译自: src/sql_jsc/shared/QueryBindingIterator.zig
// 查询绑定迭代器 - 支持数组和对象两种模式

package bao_sql_jsc.shared

import bao_core.*
import bao_jsc.*

/// 查询绑定迭代器模式
public enum IteratorMode {
    | Array
    | Objects
}

/// 查询绑定迭代器
/// 对应 Bun: QueryBindingIterator
/// 根据是否有 columns 参数决定使用数组迭代还是对象迭代
public class QueryBindingIterator {
    var mode: IteratorMode
    var arrayIter: ?JsArrayIterator = None
    var objectIter: ?ObjectIterator = None

    /// 初始化迭代器
    /// 对应 Bun: QueryBindingIterator.init
    public static func initFunc(array: JscValue, columns: JscValue,
                            globalObject: JscJSGlobalObject): ?QueryBindingIterator {
        if (columns.isEmptyOrUndefinedOrNull()) {
            let arrayIter = JsArrayIterator(array, globalObject.globalThis)
            return QueryBindingIterator(IteratorMode.Array, arrayIter, None)
        }

        let columnsCount = Int64(columns.getLength(globalObject.globalThis))
        let arrayLength = Int64(array.getLength(globalObject.globalThis))

        let objIter = ObjectIterator(
            array,
            columns,
            globalObject,
            columnsCount,
            arrayLength
        )
        return QueryBindingIterator(IteratorMode.Objects, None, objIter)
    }

    private init(mode: IteratorMode, arrayIter: ?JsArrayIterator,
                 objectIter: ?ObjectIterator) {
        this.mode = mode
        this.arrayIter = arrayIter
        this.objectIter = objectIter
    }

    /// 获取下一个值
    /// 对应 Bun: QueryBindingIterator.next
    public func next(): ?JscValue {
        match (mode) {
            case IteratorMode.Array =>
                if (arrayIter.isSome()) {
                    return arrayIter.getOrThrow().next()
                }
                return None
            case IteratorMode.Objects =>
                if (objectIter.isSome()) {
                    return objectIter.getOrThrow().next()
                }
                return None
        }
    }

    /// 检查是否有失败
    /// 对应 Bun: QueryBindingIterator.anyFailed
    public func anyFailed(): Bool {
        match (mode) {
            case IteratorMode.Array => false
            case IteratorMode.Objects =>
                if (objectIter.isSome()) {
                    return objectIter.getOrThrow().anyFailed
                }
                return false
        }
    }

    /// 跳转到指定索引
    /// 对应 Bun: QueryBindingIterator.to
    public func to(index: UInt32): Unit {
        match (mode) {
            case IteratorMode.Array =>
                if (arrayIter.isSome()) {
                    arrayIter.getOrThrow().i = Int64(index)
                }
            case IteratorMode.Objects =>
                if (objectIter.isSome()) {
                    objectIter.getOrThrow().cellI = Int64(index) % objectIter.getOrThrow().columnsCount
                    objectIter.getOrThrow().rowI = Int64(index) / objectIter.getOrThrow().columnsCount
                    objectIter.getOrThrow().currentRow = JscValue.undefined()
                }
        }
    }

    /// 重置迭代器
    /// 对应 Bun: QueryBindingIterator.reset
    public func reset(): Unit {
        match (mode) {
            case IteratorMode.Array =>
                if (arrayIter.isSome()) {
                    arrayIter.getOrThrow().i = 0
                }
            case IteratorMode.Objects =>
                if (objectIter.isSome()) {
                    objectIter.getOrThrow().cellI = 0
                    objectIter.getOrThrow().rowI = 0
                    objectIter.getOrThrow().currentRow = JscValue.undefined()
                }
        }
    }
}
