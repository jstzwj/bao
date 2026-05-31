// MySQL JS 查询绑定迭代器
// 严格翻译自: src/sql_jsc/shared/QueryBindingIterator.zig + ObjectIterator.zig
//
// 遍历 JS 参数数组，支持两种模式:
// - array: 普通数组迭代
// - objects: 按列名从对象数组中提取值
package bao_runtime.sql.mysql

import bao_core.*

/// 查询绑定迭代器
/// 对应 Bun: QueryBindingIterator
/// 遍历 JS 参数值，用于预编译语句参数绑定
public class QueryBindingIterator {
    /// 迭代器类型
    public var mode: BindingIteratorMode
    /// 数组迭代器
    public var arrayIter: JSArrayIterator
    /// 对象迭代器
    public var objectIter: JSObjectIterator
    /// 是否有失败
    public var anyFailed: Bool

    public init() {
        mode = BindingIteratorMode.array
        arrayIter = JSArrayIterator()
        objectIter = JSObjectIterator()
        anyFailed = false
    }

    /// 初始化
    /// 对应 Bun: QueryBindingIterator.init
    public static func init(
        array: JSValueRef,
        columns: JSValueRef,
        globalObject: JSValueRef
    ): QueryBindingIterator {
        let iter = QueryBindingIterator()

        if (columns.isEmptyOrUndefinedOrNull()) {
            iter.mode = BindingIteratorMode.array
            iter.arrayIter = JSArrayIterator(array: array, globalObject: globalObject)
        } else {
            iter.mode = BindingIteratorMode.objects
            iter.objectIter = JSObjectIterator(
                array: array,
                columns: columns,
                globalObject: globalObject
            )
        }

        return iter
    }

    /// 获取下一个值
    /// 对应 Bun: QueryBindingIterator.next
    public func next(): ?JSValueRef {
        match (mode) {
            case BindingIteratorMode.array =>
                return arrayIter.next()
            case BindingIteratorMode.objects =>
                return objectIter.next()
        }
    }

    /// 是否有任何失败
    /// 对应 Bun: QueryBindingIterator.anyFailed
    public func anyFailed(): Bool {
        return match (mode) {
            case BindingIteratorMode.array => false
            case BindingIteratorMode.objects => objectIter.anyFailed
        }
    }

    /// 跳转到指定位置
    /// 对应 Bun: QueryBindingIterator.to
    public func to(index: UInt32): Unit {
        match (mode) {
            case BindingIteratorMode.array =>
                arrayIter.index = index
            case BindingIteratorMode.objects =>
                objectIter.cellI = index % objectIter.columnsCount
                objectIter.rowI = index / objectIter.columnsCount
                objectIter.currentRow = JSValueRef()
        }
    }

    /// 重置
    /// 对应 Bun: QueryBindingIterator.reset
    public func reset(): Unit {
        match (mode) {
            case BindingIteratorMode.array =>
                arrayIter.index = 0
            case BindingIteratorMode.objects =>
                objectIter.cellI = 0
                objectIter.rowI = 0
                objectIter.currentRow = JSValueRef()
        }
    }
}

/// 绑定迭代器模式
/// 对应 Bun: QueryBindingIterator (union enum)
public enum BindingIteratorMode {
    | array
    | objects
}

/// JS 数组迭代器
/// 对应 Bun: jsc.JSArrayIterator
public class JSArrayIterator {
    public var array: JSValueRef
    public var globalObject: JSValueRef
    public var index: UInt32
    public var length: UInt32

    public init() {
        array = JSValueRef()
        globalObject = JSValueRef()
        index = 0
        length = 0
    }

    public init(array: JSValueRef, globalObject: JSValueRef) {
        this.array = array
        this.globalObject = globalObject
        index = 0
        length = 0 // 在真实环境中从 JS 获取 length
    }

    /// 获取下一个元素
    public func next(): ?JSValueRef {
        if (index >= length) {
            return None
        }
        // 在真实环境中: JSObject.getIndex(array, globalObject, index)
        index += 1
        return None
    }
}

/// JS 对象迭代器
/// 对应 Bun: ObjectIterator
/// 按列名从对象数组中提取值
public class JSObjectIterator {
    /// 对象数组
    public var array: JSValueRef
    /// 列名数组
    public var columns: JSValueRef
    /// 全局对象
    public var globalObject: JSValueRef
    /// 当前单元格索引
    public var cellI: UInt32
    /// 当前行索引
    public var rowI: UInt32
    /// 当前行 JS 值
    public var currentRow: JSValueRef
    /// 列数
    public var columnsCount: UInt32
    /// 数组长度
    public var arrayLength: UInt32
    /// 是否有失败
    public var anyFailed: Bool

    public init() {
        array = JSValueRef()
        columns = JSValueRef()
        globalObject = JSValueRef()
        cellI = 0
        rowI = 0
        currentRow = JSValueRef()
        columnsCount = 0
        arrayLength = 0
        anyFailed = false
    }

    public init(
        array: JSValueRef,
        columns: JSValueRef,
        globalObject: JSValueRef
    ) {
        this.array = array
        this.columns = columns
        this.globalObject = globalObject
        cellI = 0
        rowI = 0
        currentRow = JSValueRef()
        columnsCount = 0 // 在真实环境中从 JS 获取 length
        arrayLength = 0  // 在真实环境中从 JS 获取 length
        anyFailed = false
    }

    /// 获取下一个值
    /// 对应 Bun: ObjectIterator.next
    public func next(): ?JSValueRef {
        if (array.isEmptyOrUndefinedOrNull() || columns.isEmptyOrUndefinedOrNull()) {
            anyFailed = true
            return None
        }
        if (rowI >= arrayLength) {
            return None
        }

        let cellI_ = cellI
        cellI += 1
        let rowI_ = rowI

        // 如果没有当前行，获取它
        if (currentRow.isEmpty()) {
            // 在真实环境中: currentRow = JSObject.getIndex(array, globalObject, rowI)
            if (currentRow.isEmptyOrUndefinedOrNull()) {
                anyFailed = true
                return None
            }
        }

        // 获取列名
        // 在真实环境中: property = JSObject.getIndex(columns, globalObject, cellI)
        let property = JSValueRef()
        if (property.isUndefined()) {
            anyFailed = true
            return None
        }

        // 用列名从当前行获取值
        // 在真实环境中: value = currentRow.getOwnByValue(globalObject, property)
        let value = JSValueRef()

        // 当前行完成时切换到下一行
        if (cellI >= columnsCount) {
            cellI = 0
            currentRow = JSValueRef()
            rowI += 1
        }

        return if (value.isZero()) None else value
    }
}
