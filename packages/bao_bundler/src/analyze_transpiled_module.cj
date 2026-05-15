// 严格翻译自: src/bundler/analyze_transpiled_module.zig
// 全局无副作用属性访问列表 & 纯全局标识符映射
package bao_bundler

import bao_core.*
import bao_collections.*

// ============================================================================
// 全局无副作用属性访问列表
// 严格翻译自: src/bundler/analyze_transpiled_module.zig:1-190
// Bun: pub const global_no_side_effect_property_accesses
//
// 如果某个属性访问路径在此列表中, 则假定该表达式没有副作用, 可以被移除。
// 这也意味着代码可以被重新排序。
// ============================================================================

/// 全局无副作用属性访问路径
/// Bun: pub const global_no_side_effect_property_accesses = &[_][]const string{ ... }
/// 每个条目是一个属性访问链: ["Object", "keys"] 表示 Object.keys
public let GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES: ArrayList<ArrayList<String>> = ArrayList<ArrayList<String>>()

/// 全局无副作用函数调用 (toString 安全)
/// Bun: pub const global_no_side_effect_function_calls_safe_for_to_string
public let GLOBAL_NO_SIDE_EFFECT_FUNCTION_CALLS_SAFE_FOR_TOSTRING: ArrayList<ArrayList<String>> = ArrayList<ArrayList<String>>()

/// 初始化无副作用列表
public func initGlobalNoSideEffectLists(): Unit {
    // Array: Static methods
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Array", "from"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Array", "isArray"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Array", "of"))

    // JSON: Static methods
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("JSON", "parse"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("JSON", "stringify"))

    // Math: Static properties
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "E"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "LN10"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "LN2"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "PI"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "SQRT2"))

    // Math: Static methods
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "abs"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "ceil"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "floor"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "max"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "min"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "pow"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "random"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "round"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "sqrt"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Math", "trunc"))

    // Number: Static methods
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Number", "isFinite"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Number", "isInteger"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Number", "isNaN"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Number", "isSafeInteger"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Number", "parseFloat"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Number", "parseInt"))

    // Object: Static methods
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Object", "assign"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Object", "create"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Object", "defineProperty"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Object", "entries"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Object", "freeze"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Object", "fromEntries"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Object", "getPrototypeOf"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Object", "hasOwn"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Object", "is"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Object", "keys"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Object", "values"))

    // Reflect: Static methods
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Reflect", "apply"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Reflect", "construct"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Reflect", "get"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Reflect", "has"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Reflect", "ownKeys"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Reflect", "set"))

    // Symbol: Static properties
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Symbol", "asyncIterator"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Symbol", "hasInstance"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Symbol", "iterator"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Symbol", "toStringTag"))

    // Console methods
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("console", "log"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("console", "error"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("console", "warn"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("console", "info"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("console", "debug"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("console", "table"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("console", "trace"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("console", "assert"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("console", "clear"))

    // Promise
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Promise", "resolve"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Promise", "reject"))
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("Promise", "all"))

    // Crypto
    GLOBAL_NO_SIDE_EFFECT_PROPERTY_ACCESSES.append(arrayListOf("crypto", "randomUUID"))

    // toString-safe function calls
    GLOBAL_NO_SIDE_EFFECT_FUNCTION_CALLS_SAFE_FOR_TOSTRING.append(arrayListOf("Symbol", "for"))
}

/// 辅助函数: 创建 ArrayList<String>
private func arrayListOf(vararg elements: String): ArrayList<String> {
    let list = ArrayList<String>()
    for (e in elements) {
        list.append(e)
    }
    return list
}

// ============================================================================
// 纯全局标识符映射
// 严格翻译自: src/bundler/analyze_transpiled_module.zig:230-923
// Bun: pub const pure_global_identifier_map
// ============================================================================

/// 纯全局标识符值类型 - 对应 Bun PureGlobalIdentifierValue
public enum PureGlobalIdentifierValue {
    | NaN
    | Infinity
    | StrictUndefined
    | Other

    public func name(): String {
        match (this) {
            case NaN => "NaN"
            case Infinity => "Infinity"
            case StrictUndefined => "strict undefined"
            case Other => "other"
        }
    }
}

/// 纯全局标识符映射 - 对应 Bun pure_global_identifier_map
/// Bun: pub const pure_global_identifier_map = ComptimeStringMap(PureGlobalIdentifierValue, .{ ... })
/// 这些全局标识符在所有 JavaScript 环境中存在, 访问它们没有副作用
public func isPureGlobalIdentifier(name: String): Bool {
    match (name) {
        // Special values
        case "NaN" | "Infinity" | "undefined" => true

        // Built-in constructors and objects
        case "Array" | "Boolean" | "Function" | "Math" | "Number" |
             "Object" | "RegExp" | "String" | "BigInt" | "Symbol" |
             "Date" | "Map" | "Set" | "WeakMap" | "WeakSet" |
             "Promise" | "Proxy" | "JSON" | "Reflect" |
             "Intl" | "WebAssembly" => true

        // Error types
        case "Error" | "TypeError" | "SyntaxError" | "RangeError" |
             "ReferenceError" | "EvalError" | "URIError" | "AggregateError" => true

        // Typed arrays
        case "ArrayBuffer" | "DataView" | "Float32Array" | "Float64Array" |
             "Int8Array" | "Int16Array" | "Int32Array" |
             "Uint8Array" | "Uint16Array" | "Uint32Array" | "Uint8ClampedArray" => true

        // Global functions
        case "parseInt" | "parseFloat" | "isNaN" | "isFinite" |
             "decodeURI" | "decodeURIComponent" | "encodeURI" | "encodeURIComponent" |
             "escape" | "unescape" | "queueMicrotask" |
             "setTimeout" | "setInterval" | "clearTimeout" | "clearInterval" => true

        // Browser globals
        case "console" | "document" | "window" | "globalThis" |
             "fetch" | "Request" | "Response" | "Headers" |
             "URL" | "URLSearchParams" | "TextEncoder" | "TextDecoder" |
             "FormData" | "Blob" | "File" | "FileReader" |
             "Event" | "EventTarget" | "MessageChannel" | "MessagePort" |
             "AbortController" | "AbortSignal" | "Crypto" => true

        case _ => false
    }
}

/// 获取纯全局标识符值类型
public func getPureGlobalIdentifierValue(name: String): ?PureGlobalIdentifierValue {
    match (name) {
        case "NaN" => PureGlobalIdentifierValue.NaN
        case "Infinity" => PureGlobalIdentifierValue.Infinity
        case "undefined" => PureGlobalIdentifierValue.StrictUndefined
        case "Array" | "Boolean" | "Function" | "Math" | "Number" |
             "Object" | "RegExp" | "String" | "console" | "JSON" |
             "Date" | "Map" | "Set" | "Promise" | "Symbol" |
             "Reflect" | "Error" | "fetch" | "URL" | "Headers" => PureGlobalIdentifierValue.Other
        case _ => None
    }
}

// ============================================================================
// 初始化
// ============================================================================
initGlobalNoSideEffectLists()
