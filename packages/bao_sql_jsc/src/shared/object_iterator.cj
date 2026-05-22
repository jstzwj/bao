// 严格翻译自: src/sql_jsc/shared/ObjectIterator.zig
// 对象迭代器 - 遍历行数据中的属性

package bao_sql_jsc.shared

import bao_core.*
import bao_jsc.*

/// 对象迭代器
/// 对应 Bun: ObjectIterator
/// 用于遍历行对象数组中的每个属性值
public class ObjectIterator {
    var array: JscValue
    var columns: JscValue = JscValue.undefined()
    var globalObject: JscJSGlobalObject
    var cellI: Int64 = 0
    var rowI: Int64 = 0
    var currentRow: JscValue = JscValue.undefined()
    var columnsCount: Int64 = 0
    var arrayLength: Int64 = 0
    var anyFailed: Bool = false

    public init(array: JscValue, columns: JscValue, globalObject: JscJSGlobalObject,
                columnsCount: Int64, arrayLength: Int64) {
        this.array = array
        this.columns = columns
        this.globalObject = globalObject
        this.columnsCount = columnsCount
        this.arrayLength = arrayLength
    }

    /// 获取下一个属性值
    /// 对应 Bun: ObjectIterator.next
    public func next(): ?JscValue {
        if (array.isEmptyOrUndefinedOrNull() || columns.isEmptyOrUndefinedOrNull()) {
            anyFailed = true
            return None
        }
        if (rowI >= arrayLength) {
            return None
        }

        let cellI = this.cellI
        this.cellI += 1
        let rowI = this.rowI

        if (currentRow.isUndefined()) {
            currentRow = array.toObject().get(Int64(rowI).toString())
            if (currentRow.isEmptyOrUndefinedOrNull()) {
                anyFailed = true
                return None
            }
        }

        // 获取属性名
        let colObj = columns.toObject()
        let property = colObj.get(Int64(cellI).toString())
        if (property.isUndefined()) {
            anyFailed = true
            return None
        }

        // 获取值
        let rowObj = currentRow.toObject()
        let propName = property.toString()
        let value = rowObj.get(propName)
        if (value.isUndefined()) {
            anyFailed = true
            return None
        }

        // 检查是否需要移动到下一行
        if (this.cellI >= columnsCount) {
            this.cellI = 0
            currentRow = JscValue.undefined()
            this.rowI += 1
        }

        return value
    }
}
