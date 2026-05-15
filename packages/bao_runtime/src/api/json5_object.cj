// 严格翻译自: src/runtime/api/JSON5Object.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_collections.*

// ============================================================================
// JSON5Object - Bun.JSON5 API (parse/stringify)
// 对应 Bun: src/runtime/api/JSON5Object.zig
// ============================================================================

/// JSON5Object 提供 JSON5 解析和序列化功能
public class JSON5Object {

    /// 创建 JSON5 对象, 挂载 parse 和 stringify 方法
    public static func create(globalThis: JsGlobalObject): JsValue {
        let object = JsValue.createEmptyObject(globalThis, 2)
        object.put(globalThis, ZigString.static("parse"), JsFunction.create(globalThis, "parse", parse, 1))
        object.put(globalThis, ZigString.static("stringify"), JsFunction.create(globalThis, "stringify", stringify, 3))
        return object
    }

    // ========================================================================
    // stringify - JSON5.stringify(value, replacer?, space?)
    // ========================================================================

    /// JSON5 序列化
    public static func stringify(global: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let (value, replacer, spaceValue) = callFrame.argumentsAsArray3()

        value.ensureStillAlive()

        if (value.isUndefined() || value.isSymbol() || value.isFunction()) {
            return JsValue.jsUndefined
        }

        if (!replacer.isUndefinedOrNull()) {
            return global.throw("JSON5.stringify does not support the replacer argument")
        }

        var stringifier = try Stringifier.init(global, spaceValue)
        defer stringifier.deinit()

        try stringifier.stringifyValue(global, value)

        return stringifier.builder.toString(global)
    }

    // ========================================================================
    // parse - JSON5.parse(text)
    // ========================================================================

    /// JSON5 解析
    public static func parse(global: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let inputValue = callFrame.argument(0)

        if (inputValue.isEmptyOrUndefinedOrNull()) {
            global.throwInvalidArguments("Expected a string to parse")
            return JsValue.zero
        }

        // 获取输入字符串
        let input = try inputValue.toSlice(global, default_allocator)
        defer input.deinit()

        // 解析 JSON5
        let root = try JSON5Parser.parse(input.slice()) ?? {
            global.throwValue(global.createSyntaxErrorInstance("JSON5 Parse error: Unable to parse JSON5 string"))
            return JsValue.zero
        }

        return exprToJS(root, global)
    }

    // ========================================================================
    // exprToJS - 将 AST 表达式转为 JS 值
    // ========================================================================

    /// 将 JSON5 AST 表达式转换为 JS 值
    public static func exprToJS(expr: Expr, global: JsGlobalObject): JsValue {
        match (expr.data) {
            case .e_null => return JsValue.null
            case .e_boolean(let b) => return JsValue.jsBoolean(b.value)
            case .e_number(let n) => return JsValue.jsNumber(n.value)
            case .e_string(let s) => return s.toJS(default_allocator, global)
            case .e_array(let arr) =>
                var jsArr = try JsValue.createEmptyArray(global, arr.items.count)
                for ((item, i) in arr.slice().enumerated()) {
                    let value = try exprToJS(item, global)
                    try jsArr.putIndex(global, UInt32(i), value)
                }
                return jsArr
            case .e_object(let obj) =>
                var jsObj = JsValue.createEmptyObject(global, obj.properties.count)
                for (prop in obj.properties.slice()) {
                    let keyExpr = prop.key!
                    let value = try exprToJS(prop.value!, global)
                    let keyJs = try exprToJS(keyExpr, global)
                    let keyStr = try keyJs.toBunString(global)
                    defer keyStr.deref()
                    try jsObj.putMayBeIndex(global, keyStr, value)
                }
                return jsObj
            default => return JsValue.jsUndefined
        }
    }
}

/// Stringifier - JSON5 序列化器
public class Stringifier {
    public var stackCheck: StackCheck
    public var builder: StringBuilder
    public var indent: Int
    public var space: Space
    public var visiting: HashMap<JsValue, Unit>

    /// Space - 缩进方式
    public enum Space {
        case minified
        case number(UInt32)
        case str(BunString)
    }

    public static func init(global: JsGlobalObject, spaceValue: JsValue): Stringifier {
        return Stringifier(
            stackCheck: StackCheck.init(),
            builder: StringBuilder.init(),
            indent: 0,
            space: try Space.init(global, spaceValue),
            visiting: HashMap<JsValue, Unit>(),
        )
    }

    public func deinit(): Unit {
        builder.deinit()
        space.deinit()
    }

    /// 序列化值
    public func stringifyValue(global: JsGlobalObject, value: JsValue): Unit {
        if (!stackCheck.isSafeToRecurse()) {
            throw StackOverflow()
        }

        let unwrapped = try value.unwrapBoxedPrimitive(global)

        if (unwrapped.isNull()) {
            builder.append("null")
            return
        }

        if (unwrapped.isNumber()) {
            if (unwrapped.isInt32()) {
                builder.append(unwrapped.asInt32().toString())
                return
            }
            let num = unwrapped.asNumber()
            if (num.isNegativeInf()) {
                builder.append("-Infinity")
            } else if (num.isInf()) {
                builder.append("Infinity")
            } else if (num.isNaN()) {
                builder.append("NaN")
            } else {
                builder.append(num.toString())
            }
            return
        }

        if (unwrapped.isBigInt()) {
            global.throw("JSON5.stringify cannot serialize BigInt")
            return
        }

        if (unwrapped.isBoolean()) {
            builder.append(unwrapped.asBoolean() ? "true" : "false")
            return
        }

        if (unwrapped.isString()) {
            let str = try unwrapped.toBunString(global)
            defer str.deref()
            appendQuotedString(str)
            return
        }

        // 检查循环引用
        if (visiting.containsKey(unwrapped)) {
            global.throw("Converting circular structure to JSON5")
            return
        }
        visiting[unwrapped] = ()

        if (unwrapped.isArray()) {
            stringifyArray(global, unwrapped)
        } else {
            stringifyObject(global, unwrapped)
        }

        visiting.remove(unwrapped)
    }

    /// 序列化数组
    public func stringifyArray(global: JsGlobalObject, value: JsValue): Unit {
        // ... 数组序列化实现
    }

    /// 序列化对象
    public func stringifyObject(global: JsGlobalObject, value: JsValue): Unit {
        // ... 对象序列化实现
    }

    /// 追加引号包裹的字符串
    public func appendQuotedString(str: BunString): Unit {
        builder.append("'")
        for (i in 0..<str.length()) {
            let c = str.charAt(i)
            match (c) {
                case 0x00 => builder.append("\\0")
                case 0x08 => builder.append("\\b")
                case 0x09 => builder.append("\\t")
                case 0x0a => builder.append("\\n")
                case 0x0b => builder.append("\\v")
                case 0x0c => builder.append("\\f")
                case 0x0d => builder.append("\\r")
                case 0x27 => builder.append("\\'")
                case 0x5c => builder.append("\\\\")
                case 0x2028 => builder.append("\\u2028")
                case 0x2029 => builder.append("\\u2029")
                default =>
                    if (c >= 0x01 && c <= 0x07) || (c >= 0x0e && c <= 0x1f) || c == 0x7f {
                        builder.append("\\x")
                        builder.append(hexDigit(c >> 4))
                        builder.append(hexDigit(c & 0x0f))
                    } else {
                        builder.appendChar(c)
                    }
            }
        }
        builder.append("'")
    }

    /// 十六进制数字
    public static func hexDigit(v: UInt16): UInt8 {
        let nibble: UInt8 = UInt8(v & 0x0f)
        return nibble < 10 ? UInt8('0') + nibble : UInt8('a') + nibble - 10
    }

    /// 换行和缩进
    public func newline(): Unit {
        match (space) {
            case .minified => {}
            case .number(let spaceNum) =>
                builder.appendChar('\n')
                for (_ in 0..(indent * Int(spaceNum))) {
                    builder.appendChar(' ')
                }
            case .str(let spaceStr) =>
                builder.appendChar('\n')
                for (_ in 0..indent) {
                    builder.append(spaceStr.toString())
                }
        }
    }
}
