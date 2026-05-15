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
            do {
                currentRow = JscObject.getIndex(array, globalObject, rowI)
            } catch (_: Exception) {
                anyFailed = true
                return None
            }
            if (currentRow.isEmptyOrUndefinedOrNull()) {
                globalObject.throwError("Expected a row to be returned at index ${rowI}")
                return None
            }
        }

        defer {
            if (this.cellI >= columnsCount) {
                this.cellI = 0
                currentRow = JscValue.undefined()
                this.rowI += 1
            }
        }

        var property: JscValue
        do {
            property = JscObject.getIndex(columns, globalObject, cellI)
        } catch (_: Exception) {
            anyFailed = true
            return None
        }
        if (property.isUndefined()) {
            globalObject.throwError("Expected a column at index ${cellI} in row ${rowI}")
            return None
        }

        let value = currentRow.getOwnByValue(globalObject, property)
        if (value.isUndefined() || value.isZero()) {
            if (!globalObject.hasException()) {
                globalObject.throwError("Expected a value at index ${cellI} in row ${rowI}")
            }
            anyFailed = true
            return None
        }
        return value
    }
}
