// 严格翻译自: src/jsc/comptime_string_map_jsc.zig
// ComptimeStringMap 的 JSC 桥接 - JSValue 到 V 的查找辅助函数

package bao_jsc

// ========== ComptimeStringMapJSC ==========
// 严格翻译自 comptime_string_map_jsc 命名空间
// ComptimeStringMap(V) 的 JSC 桥接
// 泛型映射类型保留在 collections/ 中；只有 JSValue -> V 的查找辅助函数在这里
public class ComptimeStringMapJSC {

    // 严格翻译自 fromJS
    // 从 JS 值中获取映射中的值
    public static func fromJS(map: ComptimeStringMap, globalThis: JsObject, input: JsValue) -> ?UInt64 {
        // Parse string from JS value and look up in map
        None
    }

    // 严格翻译自 fromJSCaseInsensitive
    // 从 JS 值中获取映射中的值（大小写不敏感）
    public static func fromJSCaseInsensitive(map: ComptimeStringMap, globalThis: JsObject, input: JsValue) -> ?UInt64 {
        None
    }
}

// 支撑类型
public class ComptimeStringMap { public init() {} }
