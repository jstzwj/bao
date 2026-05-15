// 严格翻译自: src/sql_jsc/shared/QueryBindingIterator.zig
// 查询绑定迭代器 - 支持数组和对象两种模式

package bao_sql_jsc.shared

import bao_core.*
import bao_jsc.*

/// 查询绑定迭代器
/// 对应 Bun: QueryBindingIterator
/// 根据是否有 columns 参数决定使用数组迭代还是对象迭代
public class QueryBindingIterator {
    var mode: IteratorMode
    var arrayIter: ?JsArrayIterator = None
    var objectIter: ?ObjectIterator = None

    enum IteratorMode {
        | Array
        | Objects
    }

    /// 初始化迭代器
    /// 对应 Bun: QueryBindingIterator.init
    public static func init(array: JscValue, columns: JscValue,
                            globalObject: JscJSGlobalObject): ?QueryBindingIterator {
        if (columns.isEmptyOrUndefinedOrNull()) {
            let arrayIter = JsArrayIterator.init(array, globalObject)
            if (arrayIter == None) {
                return None
            }
            return QueryBindingIterator(Array, arrayIter, None)
        }

        let columnsCount = columns.getLength(globalObject)
        let arrayLength = array.getLength(globalObject)
        if (columnsCount == None || arrayLength == None) {
            return None
        }

        let objIter = ObjectIterator(
            array: array,
            columns: columns,
            globalObject: globalObject,
            columnsCount: columnsCount.getOrThrow(),
            arrayLength: arrayLength.getOrThrow()
        )
        return QueryBindingIterator(Objects, None, objIter)
    }

    private init(_ mode: IteratorMode, _ arrayIter: ?JsArrayIterator,
                 _ objectIter: ?ObjectIterator) {
        this.mode = mode
        this.arrayIter = arrayIter
        this.objectIter = objectIter
    }

    /// 获取下一个值
    /// 对应 Bun: QueryBindingIterator.next
    public func next(): ?JscValue {
        match (mode) {
            case Array =>
                if (arrayIter != None) {
                    return arrayIter.next()
                }
                return None
            case Objects =>
                if (objectIter != None) {
                    return objectIter.next()
                }
                return None
        }
    }

    /// 检查是否有失败
    /// 对应 Bun: QueryBindingIterator.anyFailed
    public func anyFailed(): Bool {
        match (mode) {
            case Array => false
            case Objects =>
                if (objectIter != None) {
                    return objectIter.anyFailed
                }
                return false
        }
    }

    /// 跳转到指定索引
    /// 对应 Bun: QueryBindingIterator.to
    public func to(index: UInt32): Unit {
        match (mode) {
            case Array =>
                if (arrayIter != None) {
                    arrayIter.setIndex(index)
                }
            case Objects =>
                if (objectIter != None) {
                    objectIter.cellI = Int64(index) % objectIter.columnsCount
                    objectIter.rowI = Int64(index) / objectIter.columnsCount
                    objectIter.currentRow = JscValue.undefined()
                }
        }
    }

    /// 重置迭代器
    /// 对应 Bun: QueryBindingIterator.reset
    public func reset(): Unit {
        match (mode) {
            case Array =>
                if (arrayIter != None) {
                    arrayIter.reset()
                }
            case Objects =>
                if (objectIter != None) {
                    objectIter.cellI = 0
                    objectIter.rowI = 0
                    objectIter.currentRow = JscValue.undefined()
                }
        }
    }
}
