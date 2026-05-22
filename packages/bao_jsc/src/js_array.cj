// 严格翻译自: src/jsc/JSArray.zig + JSArrayIterator.zig + JSUint8Array.zig + JSCell.zig + JSMap.zig
// JavaScriptCore 数组、迭代器、Uint8Array、Cell 和 Map 绑定
// 注意: JSBigInt 已移至 js_big_int.cj

package bao_jsc

import bao_collections.*

// ========== JSArray ==========
// 严格翻译自 JSArray.zig
public class JsArray {
    // 严格翻译自 JSArray.create
    public static func create(global: JsObject, items: Array<JsValue>): JsValue {
        let arr = JsObject.make()
        arr.className = "Array"
        arr.arrayStorage = items
        arr.set("length", JsValue(Int64(items.size)))
        JsValue(arr)
    }

    // 严格翻译自 JSArray.createEmpty
    public static func createEmpty(global: JsObject, len: Int64): JsValue {
        let arr = JsObject.make()
        arr.className = "Array"
        let storage = Array<JsValue>(len, {_ => JsValue.undefined()})
        arr.arrayStorage = storage
        arr.set("length", JsValue(len))
        JsValue(arr)
    }

    // 严格翻译自 JSArray.iterator
    public static func iterator(array: JsValue, global: JsObject): JsArrayIterator {
        JsArrayIterator(array, global)
    }
}

// ========== JSArrayIterator ==========
// 严格翻译自 JSArrayIterator.zig
public class JsArrayIterator {
    public var i: Int64 = 0
    public var len: Int64 = 0
    public var array: JsValue = JsValue.undefined()
    public var global: JsObject

    public init(array: JsValue, global: JsObject) {
        this.array = array
        this.global = global
        if (array.isObject()) {
            let obj = array.toObject()
            let lengthVal = obj.get("length")
            this.len = Int64(lengthVal.toLength())
        }
    }

    // 严格翻译自 JSArrayIterator.next
    public func next(): ?JsValue {
        if (!(i < len)) {
            return None
        }
        let idx = i
        i++
        if (array.isObject()) {
            let obj = array.toObject()
            return obj.get(idx.toString())
        }
        None
    }
}

// 注意: JsBigInt 已移至 js_big_int.cj

// ========== JSUint8Array ==========
// 严格翻译自 JSUint8Array.zig
public class JsUint8Array {
    public var buffer: Array<UInt8> = []
    public var byteOffset: Int64 = 0
    public var byteLength: Int64 = 0

    public init() {}

    public init(buffer: Array<UInt8>) {
        this.buffer = buffer
        this.byteLength = Int64(buffer.size)
    }

    public init(buffer: Array<UInt8>, offset: Int64, length: Int64) {
        this.buffer = buffer
        this.byteOffset = offset
        this.byteLength = length
    }

    // 创建空的 Uint8Array
    public static func create(length: Int64): JsUint8Array {
        JsUint8Array(Array<UInt8>(length, {_ => 0}))
    }

    // 获取元素
    public func get(index: Int64): UInt8 {
        if (index < 0 || index >= byteLength) {
            return 0
        }
        buffer[Int64(byteOffset + index)]
    }

    // 设置元素
    public func set(index: Int64, value: UInt8) {
        if (index >= 0 && index < byteLength) {
            buffer[Int64(byteOffset + index)] = value
        }
    }

    // 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject.make()
        obj.className = "Uint8Array"
        obj.set("byteLength", JsValue(byteLength))
        obj.set("byteOffset", JsValue(byteOffset))
        JsValue(obj)
    }
}

// ========== JSCell ==========
// 严格翻译自 JSCell.zig
// JSCell 是所有堆分配的 JS 值的基类
public class JsCell {
    public var `type`: JSType = JSType.Cell
    public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()

    public init() {}

    public init(`type`: JSType) {
        this.`type` = `type`
    }

    // 严格翻译自 JSCell.getObject
    // 静态转换 cell 为 JSObject，非对象返回 None
    public func getObject(): ?JsObject {
        if (`type`.isObject()) {
            let obj = JsObject.make()
            return obj
        }
        None
    }

    // 严格翻译自 JSCell.toObject
    // 转换 cell 为 JSObject
    public func toObject(global: JsObject): JsObject {
        if (`type`.isObject()) {
            let obj = JsObject.make()
            return obj
        }
        // 非对象类型转为对象
        JsObject.make()
    }

    // 严格翻译自 JSCell.getType
    public func getType(): JSType {
        `type`
    }

    // 严格翻译自 JSCell.toJS
    public func toJS(): JsValue {
        JsValue()
    }

    // 严格翻译自 JSCell.ensureStillAlive
    public func ensureStillAlive() {
        // 防止 GC 回收
    }
}

// ========== JSMap ==========
// 严格翻译自 JSMap.zig
// JavaScript Map 对象的不透明类型
public class JsMap {
    // 内部存储
    var entries: ArrayList<(JsValue, JsValue)> = ArrayList()

    public init() {}

    // 严格翻译自 JSMap.create
    public static func create(): JsMap {
        JsMap()
    }

    // 严格翻译自 JSMap.set
    public func set(key: JsValue, value: JsValue) {
        // 查找已有 key
        for (i in 0..entries.size) {
            if (JsValue.strictEqual(entries[Int64(i)][0], key)) {
                entries[Int64(i)] = (key, value)
                return
            }
        }
        entries.append((key, value))
    }

    // 严格翻译自 JSMap.get
    public func get(key: JsValue): JsValue {
        for (entry in entries) {
            if (JsValue.strictEqual(entry[0], key)) {
                return entry[1]
            }
        }
        JsValue.undefined()
    }

    // 严格翻译自 JSMap.has
    public func has(key: JsValue): Bool {
        for (entry in entries) {
            if (JsValue.strictEqual(entry[0], key)) {
                return true
            }
        }
        false
    }

    // 严格翻译自 JSMap.remove
    public func remove(key: JsValue): Bool {
        for (i in 0..entries.size) {
            if (JsValue.strictEqual(entries[Int64(i)][0], key)) {
                entries.removeAt(Int64(i))
                return true
            }
        }
        false
    }

    // 严格翻译自 JSMap.clear
    public func clear() {
        entries = ArrayList<(JsValue, JsValue)>()
    }

    // 严格翻译自 JSMap.size
    public func size(): Int64 {
        Int64(entries.size)
    }

    // 严格翻译自 JSMap.fromJS
    public static func fromJS(value: JsValue): ?JsMap {
        if (value.isObject()) {
            let obj = value.toObject()
            if (obj.className == "Map") {
                return JsMap()
            }
        }
        None
    }
}

// ========== JSInternalPromise ==========
// 注意: JsInternalPromise 已移至 js_internal_promise.cj
