// JsValue 扩展 — 运行时增强
// 对应 Bun: src/jsc/JSValue.zig 中的运行时扩展方法
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// JsValue 运行时扩展
// 对应 Bun: JSValue 上的各种工具方法
// ============================================================================

/// JsValue 工厂方法扩展
public class JsValueHelper {
    /// 从 Bool 创建
    public static func fromBool(b: Bool): JsValue {
        return JsValue(b)
    }

    /// 从 Int64 创建
    public static func fromInt64(i: Int64): JsValue {
        return JsValue(Float64(i))
    }

    /// 从 Float64 创建
    public static func fromFloat64(f: Float64): JsValue {
        return JsValue(f)
    }

    /// 从 String 创建
    public static func fromString(s: String): JsValue {
        return JsValue(BaoString(s))
    }

    /// 创建空对象
    public static func emptyObject(): JsValue {
        return JsValue(JsObject())
    }

    /// 创建空数组
    public static func emptyArray(): JsValue {
        return JsValue.array(ArrayList<JsValue>())
    }

    /// 创建 Error 对象
    public static func error(message: String): JsValue {
        let obj = JsObject()
        obj.set("message", JsValue(BaoString(message)))
        obj.set("stack", JsValue(BaoString("")))
        return JsValue(obj)
    }

    /// 创建 Promise (占位)
    public static func promise(): JsValue {
        let obj = JsObject()
        obj.set("then", JsValue.nativeFunction(JsNativeFunction("then") { _ => JsValue.UNDEFINED }))
        obj.set("catch", JsValue.nativeFunction(JsNativeFunction("catch") { _ => JsValue.UNDEFINED }))
        obj.set("finally", JsValue.nativeFunction(JsNativeFunction("finally") { _ => JsValue.UNDEFINED }))
        let v = JsValue(obj)
        return v
    }
}

/// JsObject 工具方法扩展
public class JsObjectHelper {
    /// 合并两个对象 (类似 Object.assign)
    public static func assign(target: JsObject, source: JsObject): JsObject {
        for (key in source.keys()) {
            target.set(key, source.get(key))
        }
        return target
    }

    /// 冻结对象 (占位 — 仓颉没有 freeze 语义)
    public static func freeze(obj: JsObject): JsObject {
        // 仓颉无法真正冻结对象，返回原对象
        return obj
    }

    /// 获取对象的所有自有属性
    public static func ownKeys(obj: JsObject): ArrayList<String> {
        return obj.keys()
    }

    /// 判断对象是否有某个自有属性
    public static func hasOwnProperty(obj: JsObject, key: String): Bool {
        return obj.has(key)
    }

    /// 转为 JSON 字符串 (简化版)
    public static func toJsonString(obj: JsObject): String {
        let sb = StringBuilder()
        sb.append("{")
        let keys = obj.keys()
        for (i in 0..keys.size) {
            if (i > 0) { sb.append(", ") }
            let key = keys[i]
            let val = obj.get(key)
            sb.append("\"${key}\": ${jsValueToJson(val)}")
        }
        sb.append("}")
        return sb.toString()
    }

    /// JsValue 转 JSON 字符串
    private static func jsValueToJson(v: JsValue): String {
        match (v.valueType) {
            case JsValueType.Undefined => "null"
            case JsValueType.Null => "null"
            case JsValueType.Boolean => if (v.boolValue) { "true" } else { "false" }
            case JsValueType.Number => v.numberValue.toString()
            case JsValueType.String => "\"${v.stringValue.toString()}\""
            case JsValueType.Object => {
                match (v.objectData) {
                    case Some(obj) => toJsonString(obj)
                    case None => "{}"
                }
            }
            case JsValueType.Array => {
                match (v.arrayData) {
                    case Some(arr) => {
                        let sb = StringBuilder()
                        sb.append("[")
                        for (i in 0..arr.size) {
                            if (i > 0) { sb.append(", ") }
                            sb.append(jsValueToJson(arr[i]))
                        }
                        sb.append("]")
                        sb.toString()
                    }
                    case None => "[]"
                }
            }
            case _ => "null"
        }
    }
}
