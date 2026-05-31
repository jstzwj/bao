// JSValueRef 扩展方法
// 对应 Bun: jsc.JSValue 的类型判断和转换方法
//
// 这些方法在真实 JSC 环境中通过 FFI 调用 JSC C API。
// 当前为占位实现，未来切换到 JSC 时对接 FFI。
package bao_runtime.sql.mysql

import bao_core.*

/// JSValueRef 扩展: 类型判断
public extension JSValueRef {
    /// 是否为 Date 对象
    public func isDate(): Bool {
        return false
    }

    /// 是否为 ArrayBuffer
    public func isArrayBuffer(): Bool {
        return false
    }

    /// 是否为 BigInt
    public func isBigInt(): Bool {
        return false
    }

    /// 是否为任意整数
    public func isAnyInt(): Bool {
        return false
    }

    /// 是否为数字
    public func isNumber(): Bool {
        return false
    }

    /// 是否为布尔值
    public func isBoolean(): Bool {
        return false
    }

    /// 是否为对象
    public func isObject(): Bool {
        return false
    }

    /// 是否为 undefined
    public func isUndefined(): Bool {
        return handle == 0
    }

    /// 转为布尔值
    public func toBoolean(): Bool {
        return handle != 0
    }

    /// 转为 Int16
    public func toInt16(): Int16 {
        return Int16(handle)
    }

    /// 转为 UInt16
    public func toUInt16(): UInt16 {
        return UInt16(handle)
    }

    /// 转为 Int32
    public func toInt32(): Int32 {
        return Int32(handle)
    }

    /// 转为 UInt32
    public func toUInt32(): UInt32 {
        return UInt32(handle)
    }

    /// 转为 Int64
    public func toInt64(): Int64 {
        return handle
    }

    /// 转为 UInt64
    public func toUInt64(): UInt64 {
        return UInt64(handle)
    }

    /// 转为 Float32
    public func toFloat32(): Float32 {
        return 0.0f
    }

    /// 转为 Float64
    public func toFloat64(): Float64 {
        return 0.0
    }

    /// 转为字节数组
    public func toBytes(): Array<UInt8> {
        return Array<UInt8>()
    }

    /// 转为 JSON 字符串
    public func toJSONString(): String {
        return "{}"
    }

    /// 获取 Unix 时间戳 (ms)
    public func getUnixTimestamp(): Float64 {
        return 0.0
    }

    /// 获取数字值
    public func asNumber(): Float64 {
        return 0.0
    }

    /// 创建 JS Date
    public static func fromDateNumber(ms: Float64): JSValueRef {
        return JSValueRef()
    }

    /// 创建 JS double number
    public static func jsDoubleNumber(value: Float64): JSValueRef {
        let v = JSValueRef()
        v.handle = Int64(value)
        return v
    }

    /// 是否为 JS null
    public func isJsNull(): Bool {
        return false
    }

    /// 检查是否为空/undefined/null
    public func isEmptyOrUndefinedOrNull(): Bool {
        return handle == 0
    }
}

/// HashSet 简单实现 (用于重复列检测)
public class HashSet<T> {
    private var items: ArrayList<T>

    public init() {
        items = ArrayList<T>()
    }

    public func contains(item: T): Bool {
        for (i in items) {
            if (i == item) {
                return true
            }
        }
        return false
    }

    public func put(item: T): Unit {
        if (!contains(item)) {
            items.append(item)
        }
    }

    public func size(): Int64 {
        return items.size
    }
}

/// ArrayList contains 扩展
public extension ArrayList<T> {
    public func contains(item: T): Bool {
        for (i in this) {
            if (i == item) {
                return true
            }
        }
        return false
    }

    public func removeAt(index: Int64): Unit {
        if (index < 0 || index >= size) {
            return
        }
        // 简化: 用 slice 重建
        var newList = ArrayList<T>()
        for (i in 0..size) {
            if (i != index) {
                newList.append(this[i])
            }
        }
        // 无法直接赋值 this，在真实环境中使用 mutable ArrayList
    }
}
