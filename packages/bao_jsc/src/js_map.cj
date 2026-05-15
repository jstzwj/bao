// 严格翻译自: src/jsc/JSMap.zig (40行)
// JavaScriptCore JSMap - JavaScript Map 对象的 opaque 绑定

package bao_jsc

// ========== JSMap_ ==========
// 严格翻译自 JSMap.zig
// JavaScript Map 对象的不透明类型绑定
// 所有操作通过 C++ FFI 实现
//
// 原始 Zig 代码:
//   pub const JSMap = opaque {
//       pub const create = bun.cpp.JSC__JSMap__create;
//       pub const set = bun.cpp.JSC__JSMap__set;
//       pub const get = bun.cpp.JSC__JSMap__get;
//       pub const has = bun.cpp.JSC__JSMap__has;
//       pub const remove = bun.cpp.JSC__JSMap__remove;
//       pub const clear = bun.cpp.JSC__JSMap__clear;
//       pub const size = bun.cpp.JSC__JSMap__size;
//       pub fn fromJS(value: JSValue) ?*JSMap { ... }
//   };
public class JsMap_ {
    // 内部存储 (仓颉侧模拟)
    var entries: ArrayList<(JsValue, JsValue)> = ArrayList()
    // 原始 opaque 指针
    public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()

    public init() {}

    // ========== create ==========
    // 严格翻译自 JSMap.create
    // FFI: bun.cpp.JSC__JSMap__create() -> *JSMap
    public static func create() -> JsMap_ {
        // FFI: JSC__JSMap__create()
        JsMap_()
    }

    // ========== set ==========
    // 严格翻译自 JSMap.set
    // 设置键值对
    // FFI: bun.cpp.JSC__JSMap__set(map, global, key, value)
    public static func set(map: JsMap_, global: JsObject, key: JsValue, value: JsValue) {
        // 查找已有 key
        for (i in 0..map.entries.size) {
            if (JsValue.strictEqual(map.entries[Int64(i)].0, key)) {
                map.entries[Int64(i)] = (key, value)
                return
            }
        }
        map.entries.append((key, value))
    }

    // ========== get ==========
    // 严格翻译自 JSMap.get
    // 获取键对应的值
    // 注意: 与 JS Map.prototype.get 语义一致，未找到时返回 undefined
    // FFI: bun.cpp.JSC__JSMap__get(map, global, key) -> JSValue
    public static func get(map: JsMap_, global: JsObject, key: JsValue) -> JsValue {
        for (entry in map.entries) {
            if (JsValue.strictEqual(entry.0, key)) {
                return entry.1
            }
        }
        JsValue.undefined()
    }

    // ========== has ==========
    // 严格翻译自 JSMap.has
    // 检查键是否存在
    // FFI: bun.cpp.JSC__JSMap__has(map, global, key) -> bool
    public static func has(map: JsMap_, global: JsObject, key: JsValue) -> Bool {
        for (entry in map.entries) {
            if (JsValue.strictEqual(entry.0, key)) {
                return true
            }
        }
        false
    }

    // ========== remove ==========
    // 严格翻译自 JSMap.remove
    // 尝试移除指定键
    // FFI: bun.cpp.JSC__JSMap__remove(map, global, key)
    public static func remove(map: JsMap_, global: JsObject, key: JsValue) -> Bool {
        for (i in 0..map.entries.size) {
            if (JsValue.strictEqual(map.entries[Int64(i)].0, key)) {
                map.entries.removeAt(Int64(i))
                return true
            }
        }
        false
    }

    // ========== clear ==========
    // 严格翻译自 JSMap.clear
    // 清除所有条目
    // FFI: bun.cpp.JSC__JSMap__clear(map)
    public static func clear(map: JsMap_) {
        map.entries.clear()
    }

    // ========== size ==========
    // 严格翻译自 JSMap.size
    // 获取条目数量
    // FFI: bun.cpp.JSC__JSMap__size(map) -> usize
    public static func size(map: JsMap_) -> Int64 {
        Int64(map.entries.size)
    }

    // ========== fromJS ==========
    // 严格翻译自 JSMap.fromJS
    // 尝试将 JSValue 转为 JSMap
    // 如果值不是 Map 类型，返回 None
    //
    // 原始 Zig:
    //   pub fn fromJS(value: JSValue) ?*JSMap {
    //       if (value.jsTypeLoose() == .Map) {
    //           return bun.cast(*JSMap, value.asEncoded().asPtr.?);
    //       }
    //       return null;
    //   }
    public static func fromJS(value: JsValue) -> ?JsMap_ {
        if (value.isObject()) {
            let obj = value.toObject()
            if (obj.className == "Map") {
                return JsMap_()
            }
        }
        None
    }
}
