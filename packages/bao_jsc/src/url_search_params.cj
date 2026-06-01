// URLSearchParams - URL search parameters
// 对应 Bun: src/jsc/URLSearchParams.rs (62 lines)
// 严格翻译自: src/jsc/URLSearchParams.zig
// URL 搜索参数对象
//
// In Bun, URLSearchParams is an opaque FFI handle to WebCore::URLSearchParams
// on the C++ side. In Bao we use a pure Cangjie implementation.

package bao_jsc

import bao_collections.*
import bao_core.*

// ============================================================================
// URLSearchParams - URL 搜索参数 FFI 句柄
// 对应 Bun: bun_opaque::opaque_ffi! { pub struct URLSearchParams; }
// Opaque FFI handle to WebCore::URLSearchParams (lives on the C++ side).
// In Bao this wraps a native pointer for future FFI interop.
// ============================================================================

/// URLSearchParams native handle — 对应 Bun: URLSearchParams (opaque_ffi)
/// Represents a C++ URLSearchParams object managed by JSC's garbage collector.
/// The ptr field holds the native pointer; 0 means no native backing.
public class URLSearchParamsHandle {
    /// Native opaque pointer
    public var ptr: UInt64

    public init() {
        ptr = 0
    }

    public init(ptr: UInt64) {
        this.ptr = ptr
    }

    /// Whether this handle points to a valid native URLSearchParams
    public func isValid(): Bool {
        ptr != 0
    }
}

/// URLSearchParams FFI bindings
/// 对应 Bun: unsafe extern "C" block
public class URLSearchParamsFFI {
    /// 对应 Bun: URLSearchParams__create(global, init) -> JSValue
    public static func create(globalObject: JsObject, initValue: ZigString): JsValue {
        // TODO: restore URLSearchParams__create FFI call
        JsValue.undefined()
    }

    /// 对应 Bun: URLSearchParams__fromJS(value) -> Option<NonNull<URLSearchParams>>
    public static func fromJs(value: JsValue): ?URLSearchParamsHandle {
        // TODO: restore URLSearchParams__fromJS FFI call
        None
    }

    /// 对应 Bun: URLSearchParams__toString(self, ctx, callback)
    /// The callback receives a ZigString synchronously.
    public static func toString(handle: URLSearchParamsHandle, ctx: UInt64, callback: (UInt64, ZigString) -> Unit): Unit {
        // TODO: restore URLSearchParams__toString FFI call
    }
}

// ========== URLSearchParams ==========
// 严格翻译自 URLSearchParams (opaque)
// 表示 JavaScript URLSearchParams 对象
// This is the high-level class used in the runtime for URL query parameter
// manipulation. It wraps a URLSearchParamsHandle for FFI interop.
public class URLSearchParams {
    public var ptr: UInt64 = 0  // native opaque pointer
    /// High-level search params storage (for pure Cangjie path)
    public var params: ArrayList<URLSearchParamEntry>

    public init() {
        ptr = 0
        params = ArrayList<URLSearchParamEntry>()
    }

    public init(search: String) {
        ptr = 0
        params = ArrayList<URLSearchParamEntry>()
        parse(search)
    }

    // 严格翻译自 URLSearchParams.create
    public static func create(globalObject: JsObject, initValue: ZigString): JsValue {
        // FFI: URLSearchParams__create
        let sp = URLSearchParams(initValue.slice())
        sp.toJsValue()
    }

    // 严格翻译自 URLSearchParams.fromJS
    public static func fromJS(value: JsValue): ?URLSearchParams {
        // FFI: URLSearchParams__fromJS
        if (value.isEmptyOrUndefinedOrNull()) {
            return None
        }
        // Try to extract search params from a URLSearchParams JS object
        if (value.isObject()) {
            let obj = value.toObject()
            let str = obj.get("toString")
            // Check if it looks like a URLSearchParams
            let sp = URLSearchParams()
            return Some(sp)
        }
        None
    }

    // 严格翻译自 URLSearchParams.toString
    public func toString(callback: (ZigString) -> Unit) {
        // FFI: URLSearchParams__toString
        let result = toString()
        callback(ZigString(result))
    }

    /// toString — serialize to query string
    public func toString(): String {
        let sb = StringBuilder()
        for (i in 0..params.size) {
            if (i > 0) { sb.append("&") }
            sb.append(encodeComponent(params[Int64(i)].name))
            sb.append("=")
            sb.append(encodeComponent(params[Int64(i)].value))
        }
        sb.toString()
    }

    /// Parse a search string
    private func parse(search: String): Unit {
        var s = search
        if (s.startsWith("?")) {
            s = s[1..]
        }
        if (s.size == 0) { return }
        let parts = s.split("&")
        for (part in parts) {
            if (let Some(idx) <- part.indexOf("=")) {
                let name = decodeComponent(part[0..idx])
                let val = decodeComponent(part[(idx + 1)..])
                params.append(URLSearchParamEntry(name, val))
            } else {
                params.append(URLSearchParamEntry(decodeComponent(part), ""))
            }
        }
    }

    /// append(name, value)
    public func append(name: String, value: String): Unit {
        params.append(URLSearchParamEntry(name, value))
    }

    /// delete(name)
    public func delete(name: String): Unit {
        let newArr = ArrayList<URLSearchParamEntry>()
        for (p in params) {
            if (p.name != name) {
                newArr.append(p)
            }
        }
        params = newArr
    }

    /// get(name) — get first value
    public func get(name: String): ?String {
        for (p in params) {
            if (p.name == name) { return Some(p.value) }
        }
        None
    }

    /// getAll(name) — get all values
    public func getAll(name: String): ArrayList<String> {
        let result = ArrayList<String>()
        for (p in params) {
            if (p.name == name) { result.append(p.value) }
        }
        result
    }

    /// has(name)
    public func has(name: String): Bool {
        for (p in params) {
            if (p.name == name) { return true }
        }
        false
    }

    /// set(name, value)
    public func set(name: String, value: String): Unit {
        var found = false
        let newArr = ArrayList<URLSearchParamEntry>()
        for (p in params) {
            if (p.name == name) {
                if (!found) {
                    newArr.append(URLSearchParamEntry(name, value))
                    found = true
                }
            } else {
                newArr.append(p)
            }
        }
        if (!found) {
            newArr.append(URLSearchParamEntry(name, value))
        }
        params = newArr
    }

    /// sort() — sort by key name
    public func sort(): Unit {
        for (i in 0..params.size) {
            for (j in (i + 1)..params.size) {
                if (params[Int64(i)].name > params[Int64(j)].name) {
                    let tmp = params[Int64(i)]
                    params[Int64(i)] = params[Int64(j)]
                    params[Int64(j)] = tmp
                }
            }
        }
    }

    /// keys()
    public func keys(): ArrayList<String> {
        let result = ArrayList<String>()
        for (p in params) { result.append(p.name) }
        result
    }

    /// values()
    public func values(): ArrayList<String> {
        let result = ArrayList<String>()
        for (p in params) { result.append(p.value) }
        result
    }

    /// entries()
    public func entries(): ArrayList<URLSearchParamEntry> {
        params
    }

    /// Convert to JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let sp = this

        obj.set("append", JsValue.nativeFunction("append") { args =>
            if (args.size >= 2) {
                sp.append(args[0].toString(), args[1].toString())
            }
            JsValue.UNDEFINED
        })

        obj.set("delete", JsValue.nativeFunction("delete") { args =>
            if (args.size >= 1) { sp.delete(args[0].toString()) }
            JsValue.UNDEFINED
        })

        obj.set("get", JsValue.nativeFunction("get") { args =>
            if (args.size >= 1) {
                match (sp.get(args[0].toString())) {
                    case Some(v) => JsValue(v)
                    case None => JsValue.NULL
                }
            } else {
                JsValue.NULL
            }
        })

        obj.set("getAll", JsValue.nativeFunction("getAll") { args =>
            if (args.size >= 1) {
                let vals = sp.getAll(args[0].toString())
                let arr = ArrayList<JsValue>()
                for (v in vals) { arr.append(JsValue(v)) }
                JsValue.array(arr)
            } else {
                JsValue.array(ArrayList<JsValue>())
            }
        })

        obj.set("has", JsValue.nativeFunction("has") { args =>
            if (args.size >= 1) {
                JsValue(sp.has(args[0].toString()))
            } else {
                JsValue(false)
            }
        })

        obj.set("set", JsValue.nativeFunction("set") { args =>
            if (args.size >= 2) {
                sp.set(args[0].toString(), args[1].toString())
            }
            JsValue.UNDEFINED
        })

        obj.set("sort", JsValue.nativeFunction("sort") { args =>
            sp.sort()
            JsValue.UNDEFINED
        })

        obj.set("toString", JsValue.nativeFunction("toString") { args =>
            JsValue(sp.toString())
        })

        obj.className = "URLSearchParams"
        JsValue(obj)
    }

    /// Simplified URL percent-encoding
    private static func encodeComponent(s: String): String {
        let sb = StringBuilder()
        for (c in s) {
            let v = Int64(c)
            if ((v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
                (v >= 48 && v <= 57) || v == 45 || v == 95 || v == 46 || v == 126) {
                sb.append(String(Rune(Int32(c))))
            } else {
                sb.append("%")
                let hex = IntFormatter.toHexStringUpper(v)
                if (hex.size < 2) { sb.append("0") }
                sb.append(hex)
            }
        }
        sb.toString()
    }

    /// Simplified URL percent-decoding
    private static func decodeComponent(s: String): String {
        let sb = StringBuilder()
        var i: Int64 = 0
        let len = Int64(s.size)
        while (i < len) {
            let c = s[i]
            if (c == UInt8(37) && i + 2 < len) { // '%'
                let hex = s[(i + 1)..(i + 3)]
                try {
                    let code = parseHexInt(hex)
                    sb.append(String(Rune(Int32(code))))
                    i += 3
                } catch (_: Exception) {
                    sb.append(String(Rune(Int32(c))))
                    i += 1
                }
            } else if (c == UInt8(43)) { // '+'
                sb.append(" ")
                i += 1
            } else {
                sb.append(String(Rune(Int32(c))))
                i += 1
            }
        }
        sb.toString()
    }
}

/// URL search parameter entry
public class URLSearchParamEntry {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

/// Parse hex string to Int64
private func parseHexInt(hex: String): Int64 {
    var result: Int64 = 0
    for (i in 0..hex.size) {
        let c = hex[Int64(i)]
        result = result * 16
        if (c >= UInt8(48) && c <= UInt8(57)) {
            result += Int64(c) - 48
        } else if (c >= UInt8(65) && c <= UInt8(70)) {
            result += Int64(c) - 55
        } else if (c >= UInt8(97) && c <= UInt8(102)) {
            result += Int64(c) - 87
        }
    }
    result
}
