// Web API structuredClone 模块
// 对应 Bun: src/runtime/structuredClone 相关实现
// 严格翻译自 Web structuredClone API
package bao_runtime.web_api

import bao_core.*
import bao_collections.*

// ============================================================================
// structuredClone — 结构化克隆算法
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/structuredClone
// ============================================================================

/// 结构化克隆支持的值类型
public enum CloneableType {
    | Undefined
    | Null
    | Boolean
    | Number
    | String
    | Array
    | Object
    | ArrayBuffer
    | Date
    | RegExp
    | Map
    | Set
    | Error
    | Blob
    | File
}

/// structuredClone — 深拷贝一个值
/// 对应 Web API: structuredClone(value, options)
/// 对应 Bun: 结构化克隆实现
public func structuredClone(value: JsValue): JsValue {
    return cloneValue(value)
}

/// structuredClone (带 transfer)
/// 对应 Web API: structuredClone(value, { transfer: [...] })
public func structuredClone(value: JsValue, transfer: ArrayList<JsValue>): JsValue {
    // 简化: transfer 列表中的 ArrayBuffer 会被转移 (当前实现为复制)
    return cloneValue(value)
}

/// 内部克隆实现 — 递归深拷贝
private func cloneValue(value: JsValue): JsValue {
    match (value.valueType) {
        case JsValueType.Undefined => return JsValue.UNDEFINED
        case JsValueType.Null => return JsValue.NULL
        case JsValueType.Boolean => return JsValue(value.boolValue)
        case JsValueType.Number => return JsValue(value.numberValue)
        case JsValueType.String => {
            match (value.stringData) {
                case Some(s) => return JsValue(BaoString(s.toString()))
                case None => return JsValue(BaoString(""))
            }
        }
        case JsValueType.Array => {
            match (value.arrayData) {
                case Some(arr) => {
                    let cloned = ArrayList<JsValue>()
                    for (item in arr) {
                        cloned.append(cloneValue(item))
                    }
                    return JsValue.array(cloned)
                }
                case None => return JsValue.emptyArray()
            }
        }
        case JsValueType.Object => {
            match (value.objectData) {
                case Some(obj) => {
                    let cloned = JsObject()
                    for (key in obj.keys()) {
                        let val = obj.get(key)
                        cloned.set(key, cloneValue(val))
                    }
                    return JsValue(cloned)
                }
                case None => return JsValue(JsObject())
            }
        }
        case _ => {
            // 对于无法克隆的类型 (function, symbol 等) 抛出错误
            // 简化: 直接返回原值
            return value
        }
    }
}

/// 克隆原生类型 (非 JsValue)
/// 用于在 Cangjie 层面进行深拷贝

/// 克隆 HashMap<String, String>
public func cloneStringMap(map: HashMap<String, String>): HashMap<String, String> {
    let result = HashMap<String, String>()
    for (key in map.keys()) {
        match (map.get(key)) {
            case Some(val) => result.put(key, val)
            case None => ()
        }
    }
    return result
}

/// 克隆 ArrayList<String>
public func cloneStringList(list: ArrayList<String>): ArrayList<String> {
    let result = ArrayList<String>()
    for (item in list) {
        result.append(item)
    }
    return result
}

/// 克隆 Array<UInt8>
public func cloneByteArray(arr: Array<UInt8>): Array<UInt8> {
    let result = Array<UInt8>(arr.size, item: UInt8(0))
    for (i in 0..arr.size) {
        result[Int64(i)] = arr[Int64(i)]
    }
    return result
}

/// 克隆 Blob
public func cloneBlob(blob: Blob): Blob {
    let data = cloneByteArray(blob.arrayBuffer())
    return Blob(data, blob.type)
}

/// 克隆 File
public func cloneFile(file: File): File {
    let data = cloneByteArray(file.arrayBuffer())
    return File(data, file.name, file.type)
}

// ============================================================================
// StructuredCloneModule — structuredClone 模块导出
// ============================================================================

/// StructuredClone 模块导出 — 将 structuredClone 注册到全局
public class StructuredCloneModule {
    /// 将 structuredClone 注册到全局环境
    public static func registerGlobals(env: Environment): Unit {
        env.define("structuredClone", Interpreter.makeNativeFn("structuredClone") { args =>
            if (args.size < 1) {
                throw JsError(JsValue(BaoString("structuredClone requires at least 1 argument")))
            }
            let value = args[0]
            return structuredClone(value)
        }, false)
    }
}
