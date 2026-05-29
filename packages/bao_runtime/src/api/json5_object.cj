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
    public static func create(globalThis!: JsGlobalObject): JsValue {
        let object = JsValue.createEmptyObject(globalThis, 2)
        object.put(globalThis, ZigString.`static`("parse"), JsFunction.create(globalThis, "parse", parse, 1))
        object.put(globalThis, ZigString.`static`("stringify"), JsFunction.create(globalThis, "stringify", stringify, 3))
        return object
    }

    // ========================================================================
    // stringify - JSON5.stringify(value, replacer?, space?)
    // ========================================================================

    /// JSON5 序列化
    public static func stringify(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let (value, replacer, spaceValue) = callFrame.argumentsAsArray3()

        value.ensureStillAlive()

        if (value.isUndefined() || value.isSymbol() || value.isFunction()) {
            return JsValue.jsUndefined()
        }

        if (!replacer.isUndefinedOrNull()) {
            return global.`throw`("JSON5.stringify does not support the replacer argument")
        }

        var stringifier = Stringifier(global, spaceValue) 
        stringifier.stringifyValue(global, value) 

        let result = stringifier.builder.toString(global)
        stringifier.deinit()
        return result
    }

    // ========================================================================
    // parse - JSON5.parse(text)
    // ========================================================================

    /// JSON5 解析
    public static func parse(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let inputValue = callFrame.argument(0)

        if (inputValue.isEmptyOrUndefinedOrNull()) {
            global.throwInvalidArguments("Expected a string to parse")
            return JsValue.jsUndefined()
        }

        // 获取输入字符串
        let input = inputValue.toSlice(global, default_allocator)
        // 解析 JSON5
                let rootOpt = JSON5Parser.parse(input.slice() )
        if (rootOpt.isNone()) {
            global.throwValue(global.createSyntaxErrorInstance("JSON5 Parse error: Unable to parse JSON5 string"))
            return JsValue.jsUndefined()
        }
        let root = rootOpt.get()

        let jsResult = exprToJS(root, global)
        input.deinit()
        return jsResult
    }

    // ========================================================================
    // exprToJS - 将 AST 表达式转为 JS 值
    // ========================================================================

    /// 将 JSON5 AST 表达式转换为 JS 值
    public static func exprToJS(expr!: Expr, global!: JsGlobalObject): JsValue {
        match (expr.data) {
            case e_null => return JsValue.jsNull()
            case e_boolean(b) => return JsValue.jsBoolean(b.value)
            case e_number(n) => return JsValue.jsNumber(n.value)
            case e_string(s) => return s.toJS(default_allocator, global)
            case e_array(arr) =>
                var jsArr = JsValue.createEmptyArray(global, arr.items.count) 
                for ((item, i) in arr.slice().enumerated()) {
                    let value = exprToJS(item, global) 
                    jsArr.putIndex(global, UInt32(i) , value)
                }
                return jsArr
            case e_object(obj) =>
                var jsObj = JsValue.createEmptyObject(global, obj.properties.count)
                for (p in obj.properties.slice()) {
                    let keyExpr = p.key.getOrThrow()
                    let value = exprToJS(p.value.getOrThrow(), global)
                    let keyJs = exprToJS(keyExpr, global)
                    let keyStr = keyJs.toBunString(global)
                    jsObj.putMayBeIndex(global, keyStr, value)
                    keyStr.deref()
                }
                return jsObj
            case _ => return JsValue.jsUndefined()
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
//    public enum Space {
//        | minified
//        | number(UInt32)
//        | str(BunString)
//    }

    public static func initFunc(global!: JsGlobalObject, spaceValue!: JsValue): Stringifier {
        return Stringifier(
            stackCheck: StackCheck(),
            builder: StringBuilder(),
            indent: 0,
            space: Space(global, spaceValue) ,
            visiting: HashMap<JsValue, Unit>(),
        )
    }

    public func deinit(): Unit {
        builder.deinit()
        space.deinit()
    }

    /// 序列化值
    public func stringifyValue(global!: JsGlobalObject, value!: JsValue): Unit {
        if (!stackCheck.isSafeToRecurse()) {
            throw StackOverflow()
        }

        let unwrapped = value.unwrapBoxedPrimitive(global) 

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
            global.`throw`("JSON5.stringify cannot serialize BigInt")
            return
        }

        if (unwrapped.isBoolean()) {
            if (unwrapped.asBoolean()) { builder.append("true") } else { builder.append("false") }
            return
        }

        if (unwrapped.isString()) {
            let str = unwrapped.toBunString(global)
            appendQuotedString(str)
            str.deref()
            return
        }

        // 检查循环引用
        if (visiting.containsKey(unwrapped)) {
            global.`throw`("Converting circular structure to JSON5")
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
    /// 对应 Bun: Stringifier.stringifyArray
    public func stringifyArray(global!: JsGlobalObject, value!: JsValue): Unit {
        var iter = value.arrayIterator(global) 

        if (iter.len == 0) {
            builder.append("[]")
            return
        }

        builder.append("[")

        match (space) {
            case Space.minified =>
                var first: Bool = true
                while (let item <- iter.next() ) {
                    if (!first) {
                        builder.append(",")
                    }
                    first = false
                    if (item.isUndefined() || item.isSymbol() || item.isFunction()) {
                        builder.append("null")
                    } else {
                        stringifyValue(global, item) 
                    }
                }
            case Space.number(_) | Space.str(_) =>
                indent += 1
                var first: Bool = true
                while (let item <- iter.next() ) {
                    if (!first) {
                        builder.append(",")
                    }
                    first = false
                    newline()
                    if (item.isUndefined() || item.isSymbol() || item.isFunction()) {
                        builder.append("null")
                    } else {
                        stringifyValue(global, item) 
                    }
                }
                // Trailing comma
                builder.append(",")
                indent -= 1
                newline()
        }

        builder.append("]")
    }

    /// 序列化对象
    /// 对应 Bun: Stringifier.stringifyObject
    public func stringifyObject(global!: JsGlobalObject, value!: JsValue): Unit {
        var iter = JsPropertyIterator (
            skipEmptyName: false,
            includeValue: true,
        ).`init`(global, value.toObject(global) )
        if (iter.len == 0) {
            builder.append("{")
            return
        }

        builder.append("{")

        match (space) {
            case Space.minified =>
                var first: Bool = true
                while (let propName <- iter.next() ) {
                    if (iter.value.isUndefined() || iter.value.isSymbol() || iter.value.isFunction()) {
                        continue
                    }
                    if (!first) {
                        builder.append(",")
                    }
                    first = false
                    appendKey(propName)
                    builder.append(":")
                    stringifyValue(global, iter.value) 
                }
            case Space.number(_) | Space.str(_) =>
                indent += 1
                var first: Bool = true
                while (let propName <- iter.next() ) {
                    if (iter.value.isUndefined() || iter.value.isSymbol() || iter.value.isFunction()) {
                        continue
                    }
                    if (!first) {
                        builder.append(",")
                    }
                    first = false
                    newline()
                    appendKey(propName)
                    builder.append(": ")
                    stringifyValue(global, iter.value) 
                }
                indent -= 1
                if (!first) {
                    // Trailing comma
                    builder.append(",")
                    newline()
                }
        }

        builder.append("}")
        iter.deinit()
    }

    /// 追加键名 — 如果是标识符则直接输出，否则加引号
    /// 对应 Bun: Stringifier.appendKey
    public func appendKey(name!: BunString): Unit {
        var isIdentifier: Bool = true
        if (name.size() == 0) {
            isIdentifier = false
        } else {
            if (!JsLexer.isIdentifierStart(name.charAt(0))) {
                isIdentifier = false
            } else {
                for (i in 1..name.size()) {
                    if (!JsLexer.isIdentifierContinue(name.charAt(i))) {
                        isIdentifier = false
                        break
                    }
                }
            }
        }

        if (isIdentifier) {
            builder.append(name.toString())
        } else {
            appendQuotedString(name)
        }
    }

    /// 追加引号包裹的字符串
    public func appendQuotedString(str!: BunString): Unit {
        builder.append("'")
        for (i in 0..str.size()) {
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
                case _ =>
                    if ((c >= 0x01 && c <= 0x07) || (c >= 0x0e && c <= 0x1f) || c == 0x7f) {
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
    public static func hexDigit(v!: UInt16): UInt8 {
        let nibble: UInt8 = UInt8(v & 0x0f)
        return if (nibble < 10) { UInt8('0') + nibble } else { UInt8('a') + nibble - 10 }
    }

    /// 换行和缩进
    public func newline(): Unit {
        match (space) {
            case minified => ()
            case number(spaceNum) =>
                builder.appendChar('\n')
                for (_ in 0..(indent * Int(spaceNum))) {
                    builder.appendChar(' ')
                }
            case str(spaceStr) =>
                builder.appendChar('\n')
                for (_ in 0..indent) {
                    builder.append(spaceStr.toString())
                }
        }
    }
}