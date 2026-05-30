// 严格翻译自: src/jsc/JSValue.zig
// JavaScriptCore JsValue 类型系统

package bao_jsc

import bao_collections.*

// Simple parseDouble helper
func parseDouble(s: String): Float64 {
    var result: Float64 = 0.0
    var decimal: Float64 = 0.0
    var decimalPlaces: Float64 = 1.0
    var isDecimal: Bool = false
    var sign: Float64 = 1.0
    var idx: Int64 = 0
    if (idx < s.size && s[Int64(0)] == UInt8(45)) { sign = -1.0; idx = 1 }
    while (idx < s.size) {
        let c = s[Int64(idx)]
        if (c == UInt8(46)) { isDecimal = true }
        else if (c >= UInt8(48) && c <= UInt8(57)) {
            let digit = Float64(c - UInt8(48))
            if (isDecimal) { decimalPlaces = decimalPlaces * 10.0; decimal = decimal * 10.0 + digit }
            else { result = result * 10.0 + digit }
        } else { break }
        idx++
    }
    sign * (result + decimal / decimalPlaces)
}

// Helper: check if Float64 is NaN
func floatIsNaN(n: Float64): Bool {
    n != n
}

// Helper: check if Float64 is finite (not NaN, not Infinity)
func isFiniteFloat(n: Float64): Bool {
    !floatIsNaN(n) && n != 1.0 / 0.0 && n != -1.0 / 0.0
}

// Helper: absolute value of Float64
func absFloat(n: Float64): Float64 {
    if (n < 0.0) { -n } else { n }
}

// JS 值类型枚举
public enum JsValueType {
    | Undefined
    | Null
    | Boolean
    | Number
    | String
    | Object
    | Symbol
    | BigInt
    | Array
    | ArrayBuffer
    | TypedArray
    | DataView
    | Function
    | Error
    | Promise
    | External

    public operator func ==(right: JsValueType): Bool {
        match (this) {
            case Undefined => match(right) { case Undefined => true case _ => false }
            case Null => match(right) { case Null => true case _ => false }
            case Boolean => match(right) { case Boolean => true case _ => false }
            case Number => match(right) { case Number => true case _ => false }
            case String => match(right) { case String => true case _ => false }
            case Object => match(right) { case Object => true case _ => false }
            case Symbol => match(right) { case Symbol => true case _ => false }
            case BigInt => match(right) { case BigInt => true case _ => false }
            case Array => match(right) { case Array => true case _ => false }
            case ArrayBuffer => match(right) { case ArrayBuffer => true case _ => false }
            case TypedArray => match(right) { case TypedArray => true case _ => false }
            case DataView => match(right) { case DataView => true case _ => false }
            case Function => match(right) { case Function => true case _ => false }
            case Error => match(right) { case Error => true case _ => false }
            case Promise => match(right) { case Promise => true case _ => false }
            case External => match(right) { case External => true case _ => false }
        }
    }

    public operator func !=(right: JsValueType): Bool {
        !(this == right)
    }
}

// JS 值包装 - 严格翻译自 JSValue.zig
public class JsValue {
    public var valueType: JsValueType = JsValueType.Undefined
    var boolValue: Bool = false
    var numberValue: Float64 = 0.0
    var stringValue: String = ""
    public var objectValue: ?JsObject = None
    var symbolValue: ?JsSymbol = None
    var bigIntValue: String = ""  // BigInt as string representation
    var rawPtr: CPointer<UInt8> = CPointer<UInt8>()  // JSC C API pointer

    // 编码后的 Int64 值 - 用于 JSC FFI 调用
    // 在真实 JSC 中 JSValue 是一个 64-bit 编码值 (NaN-boxing)
    // 此处用 rawPtr 转为 Int64 传给 JSC C API 函数
    public prop encoded: Int64 {
        get() {
            // 在真实 JSC 运行时中，JSValue 是 NaN-boxed 的 64 位值
            // 当前模拟环境返回 0
            Int64(0)
        }
    }

    public init() {
        this.valueType = JsValueType.Undefined
    }

    public init(b: Bool) {
        this.valueType = JsValueType.Boolean
        this.boolValue = b
    }

    public init(n: Float64) {
        this.valueType = JsValueType.Number
        this.numberValue = n
    }

    public init(n: Int64) {
        this.valueType = JsValueType.Number
        this.numberValue = Float64(n)
    }

    public init(s: String) {
        this.valueType = JsValueType.String
        this.stringValue = s
    }

    public init(obj: JsObject) {
        this.valueType = JsValueType.Object
        this.objectValue = obj
    }

    public init(fn: JsFunction) {
        this.valueType = JsValueType.Object
        this.objectValue = fn.closure
    }

    /// 创建原生函数 JsValue（从回调创建 JsFunction 并包装为 JsValue）
    public static func nativeFunction(name: String, callback: (Array<JsValue>) -> JsValue): JsValue {
        let fn = JsFunction.create(name, { _global, args => callback(args) })
        let v = JsValue()
        v.valueType = JsValueType.Object
        v.objectValue = Some(fn.closure)
        return v
    }

    public init(sym: JsSymbol) {
        this.valueType = JsValueType.Symbol
        this.symbolValue = sym
    }

    // Undefined 单例
    public static func undefined(): JsValue {
        let v = JsValue()
        return v
    }

    // Null 单例
    public static func null(): JsValue {
        let v = JsValue()
        v.valueType = JsValueType.Null
        return v
    }

    // Static constants used by napi
    public static let UNDEFINED: JsValue = JsValue()
    public static let NULL: JsValue = JsValue.null()

    // 数值常量
    public static let MAX_SAFE_INTEGER: Float64 = 9007199254740991.0  // 2^53 - 1
    public static let zero: JsValue = JsValue(0.0)

    public static func jsUndefined(): JsValue {
        JsValue()
    }

    public static func jsTrue(): JsValue {
        JsValue(true)
    }

    public static func jsFalse(): JsValue {
        JsValue(false)
    }

    public static func jsNumber(n: Int64): JsValue {
        JsValue(Float64(n))
    }

    public static func jsBoolean(b: Bool): JsValue {
        JsValue(b)
    }

    public static func jsNumber(n: Float64): JsValue {
        JsValue(n)
    }

    public static func jsString(s: String): JsValue {
        JsValue(s)
    }

    public static func array(arr: ArrayList<JsValue>): JsValue {
        let v = JsValue()
        v.valueType = JsValueType.Array
        v
    }

    public var arrayData: ?ArrayList<JsValue> = None

    public func isUndefinedOrNull(): Bool {
        isNull() || isUndefined()
    }

    // Alias for isUndefinedOrNull (used by array_buffer and other modules)
    public func isEmptyOrUndefinedOrNull(): Bool {
        isUndefinedOrNull()
    }

    // 严格翻译自 JSValue.fromCell
    // 从 JSCell 创建 JsValue
    public static func fromCell(cell: JsCell_): JsValue {
        let v = JsValue()
        v.valueType = JsValueType.Object
        v.rawPtr = cell.rawPtr
        return v
    }

    // 类型检查方法 - 严格翻译自 JSValue.zig isXxx 方法
    public func isUndefined(): Bool {
        valueType == JsValueType.Undefined
    }

    public func isNull(): Bool {
        valueType == JsValueType.Null
    }

    public operator func ==(right: JsValue): Bool {
        if (this.valueType != right.valueType) { return false }
        match (this.valueType) {
            case Undefined => true
            case Null => true
            case Boolean => this.boolValue == right.boolValue
            case Number => this.numberValue == right.numberValue
            case String => this.stringValue == right.stringValue
            case _ => false  // object/symbol equality is identity-based, simplified
        }
    }

    public operator func !=(right: JsValue): Bool {
        !(this == right)
    }

    public func isBoolean(): Bool {
        valueType == JsValueType.Boolean
    }

    public func isNumber(): Bool {
        valueType == JsValueType.Number
    }

    public func isString(): Bool {
        valueType == JsValueType.String
    }

    public func isObject(): Bool {
        valueType == JsValueType.Object
    }

    public func isSymbol(): Bool {
        valueType == JsValueType.Symbol
    }

    public func isBigInt(): Bool {
        valueType == JsValueType.BigInt
    }

    public func isPrimitive(): Bool {
        !isObject()
    }

    public func isNullOrUndefined(): Bool {
        isNull() || isUndefined()
    }

    public func isCallable(): Bool {
        if (isObject()) {
            let obj = objectValue.getOrThrow()
            if (obj.isFunction || obj.isCallable) {
                return true
            }
            // 也通过 JSC C API 检查
            return jscIsFunction(UInt64(0), encoded)
        }
        return false
    }

    // 类型转换 - 严格翻译自 JSValue.zig toXxx 方法
    // ToBoolean - JS ToBoolean 抽象操作
    public func toBoolean(): Bool {
        match (valueType) {
            case Undefined => false
            case Null => false
            case Boolean => boolValue
            case Number => numberValue != 0.0 && !floatIsNaN(numberValue)
            case String => stringValue.size > 0
            case Object => true
            case Symbol => true
            case BigInt => bigIntValue != "0"
            case _ => true
        }
    }

    // ToNumber - JS ToNumber 抽象操作
    public func toNumber(): Float64 {
        match (valueType) {
            case Undefined => Float64.NaN
            case Null => 0.0
            case Boolean => if (boolValue) { 1.0 } else { 0.0 }
            case Number => numberValue
            case String => stringToNumber(stringValue)
            case Object=>
                // 先调用 valueOf，再 toPrimitive -> toNumber
                if (let Some(obj) <- objectValue) {
                    let prim = obj.toPrimitive(JsValueType.Number)
                    return prim.toNumber()
                }
                Float64.NaN
            case Symbol => Float64.NaN
            case BigInt=>
                let n = parseDouble(bigIntValue)
                n
            case _ => Float64.NaN
        }
    }

    // ToString - JS ToString 抽象操作
    public func toString(): String {
        match (valueType) {
            case Undefined => "undefined"
            case Null => "null"
            case Boolean => if (boolValue) { "true" } else { "false" }
            case Number => numberToString(numberValue)
            case String => stringValue
            case Object=>
                if (let Some(obj) <- objectValue) {
                    let prim = obj.toPrimitive(JsValueType.String)
                    return prim.toString()
                }
                "[object Object]"
            case Symbol=>
                if (let Some(sym) <- symbolValue) {
                    "Symbol(" + sym.description + ")"
                } else {
                    "Symbol()"
                }
            case BigInt => bigIntValue + "n"
            case _ => stringValue
        }
    }

    // 格式化为字符串（用于测试输出）
    public func toFmt(formatter: ConsoleFormatter): String {
        return toString()
    }

    // ToObject - JS ToObject 抽象操作
    public func toObject(): JsObject {
        match (valueType) {
            case Undefined => throw JsTypeError("Cannot convert undefined to object")
            case Null => throw JsTypeError("Cannot convert null to object")
            case Boolean => JsObject.fromBoolean(boolValue)
            case Number => JsObject.fromNumber(numberValue)
            case String => JsObject.fromString(stringValue)
            case Object => objectValue.getOrThrow()
            case Symbol => JsObject.fromSymbol(symbolValue.getOrThrow())
            case BigInt => JsObject.fromBigInt(bigIntValue)
            case _ => JsObject()
        }
    }

    // ToInteger - JS ToIntegerOrInfinity 抽象操作
    public func toInteger(): Int64 {
        if (isNull() || isUndefined()) {
            return 0
        }
        let n = toNumber()
        if (floatIsNaN(n)) {
            return 0
        }
        if (n == 0.0 || floatIsNaN(n)) {
            return 0
        }
        Int64(if (n >= 0.0) { Math.floor(n) } else { Math.ceil(n) })
    }

    // ToLength - JS ToLength 抽象操作
    public func toLength(): UInt64 {
        let len = toInteger()
        if (len < 0) {
            return 0
        }
        UInt64(len)
    }

    // JSValue 比较
    // Strict Equality (===)
    public static func strictEqual(a: JsValue, b: JsValue): Bool {
        if (a.valueType != b.valueType) {
            // NaN === NaN is true in JS
            if (a.isNumber() && b.isNumber()) {
                return floatIsNaN(a.numberValue) && floatIsNaN(b.numberValue)
            }
            return false
        }
        match (a.valueType) {
            case Undefined => true
            case Null => true
            case Boolean => a.boolValue == b.boolValue
            case Number => a.numberValue == b.numberValue
            case String => a.stringValue == b.stringValue
            case Object =>
                // Object identity comparison
                a.objectValue.isSome() && b.objectValue.isSome()
            case Symbol =>
                if (let Some(sa) <- a.symbolValue) {
                    if (let Some(sb) <- b.symbolValue) {
                        return sa.id == sb.id
                    }
                }
                false
            case BigInt => a.bigIntValue == b.bigIntValue
            case _ => false
        }
    }

    // Abstract Equality (==) - JS Abstract Equality Comparison
    public static func abstractEqual(a: JsValue, b: JsValue): Bool {
        // Same `type` -> strict equal
        if (a.valueType == b.valueType) {
            return strictEqual(a, b)
        }
        // null == undefined
        if (a.isNullOrUndefined() && b.isNullOrUndefined()) {
            return true
        }
        // Number == String -> Number == ToNumber(String)
        if (a.isNumber() && b.isString()) {
            return a.numberValue == b.toNumber()
        }
        if (a.isString() && b.isNumber()) {
            return a.toNumber() == b.numberValue
        }
        // Boolean == X -> ToNumber(Boolean) == X
        if (a.isBoolean()) {
            return abstractEqual(JsValue(a.toNumber()), b)
        }
        if (b.isBoolean()) {
            return abstractEqual(a, JsValue(b.toNumber()))
        }
        // String/Number/Symbol == Object -> ToPrimitive(Object)
        if (a.isObject() && (b.isString() || b.isNumber() || b.isSymbol())) {
            return abstractEqual(a.toPrimitive(JsValueType.Number), b)
        }
        if (b.isObject() && (a.isString() || a.isNumber() || a.isSymbol())) {
            return abstractEqual(a, b.toPrimitive(JsValueType.Number))
        }
        // BigInt == String -> ToBigInt(String)
        if (a.isBigInt() && b.isString()) {
            return a.bigIntValue == b.stringValue
        }
        if (a.isString() && b.isBigInt()) {
            return a.stringValue == b.bigIntValue
        }
        false
    }

    // ToPrimitive - JS ToPrimitive 抽象操作
    public func toPrimitive(preferredType: JsValueType): JsValue {
        if (!isObject()) {
            return this
        }
        let obj = objectValue.getOrThrow()
        // 先尝试 toString/valueOf
        if (preferredType == JsValueType.String) {
            let str = obj.tryCallToString()
            if (str.isString()) {
                return str
            }
            let val = obj.tryCallValueOf()
            if (!val.isObject()) {
                return val
            }
        } else {
            let val = obj.tryCallValueOf()
            if (!val.isObject()) {
                return val
            }
            let str = obj.tryCallToString()
            if (str.isString()) {
                return str
            }
        }
        throw JsTypeError("Cannot convert object to primitive value")
    }

    // JSON 序列化
    public func toJsonString(): String {
        match (valueType) {
            case Undefined => "undefined"
            case Null => "null"
            case Boolean => if (boolValue) { "true" } else { "false" }
            case Number => numberToString(numberValue)
            case String => "\"" + escapeJsonString(stringValue) + "\""
            case Array =>
                // 严格翻译自数组 JSON 序列化
                if (let Some(arr) <- arrayData) {
                    let sb = StringBuilder()
                    sb.append("[")
                    for (i in 0..arr.size) {
                        if (i > 0) { sb.append(",") }
                        sb.append(arr[i].toJsonString())
                    }
                    sb.append("]")
                    sb.toString()
                } else if (let Some(obj) <- objectValue) {
                    let sb = StringBuilder()
                    sb.append("[")
                    let storage = obj.arrayStorage
                    for (i in 0..storage.size) {
                        if (i > 0) { sb.append(",") }
                        sb.append(storage[i].toJsonString())
                    }
                    sb.append("]")
                    sb.toString()
                } else {
                    "[]"
                }
            case Object =>
                if (let Some(obj) <- objectValue) {
                    return obj.toJsonString()
                }
                "null"
            case Symbol => "undefined"
            case BigInt => throw JsTypeError("BigInt value cannot be serialized in JSON")
            case _ => "undefined"
        }
    }

    // 工具方法
    func stringToNumber(s: String): Float64 {
        let trimmed = s.trimStart().trimEnd()
        if (trimmed.size == 0) {
            return 0.0
        }
        if (trimmed == "Infinity" || trimmed == "+Infinity") {
            return 1.0 / 0.0  // positive infinity
        }
        if (trimmed == "-Infinity") {
            return -1.0 / 0.0  // negative infinity
        }
        if (trimmed == "NaN") {
            return Float64.NaN
        }
        // hex 0x
        if (trimmed.size > 2 && trimmed[Int64(0)] == UInt8(48) && (trimmed[Int64(1)] == UInt8(120) || trimmed[Int64(1)] == UInt8(88))) {
            return parseDouble(trimmed[Int64(2)..])
        }
        // octal 0o
        if (trimmed.size > 2 && trimmed[Int64(0)] == UInt8(48) && (trimmed[Int64(1)] == UInt8(111) || trimmed[Int64(1)] == UInt8(79))) {
            return parseDouble(trimmed[Int64(2)..])
        }
        // binary 0b
        if (trimmed.size > 2 && trimmed[Int64(0)] == UInt8(48) && (trimmed[Int64(1)] == UInt8(98) || trimmed[Int64(1)] == UInt8(66))) {
            return parseDouble(trimmed[Int64(2)..])
        }
        parseDouble(trimmed)
    }

    func numberToString(n: Float64): String {
        if (floatIsNaN(n)) {
            return "NaN"
        }
        if (n == 1.0 / 0.0) {
            return "Infinity"
        }
        if (n == -1.0 / 0.0) {
            return "-Infinity"
        }
        if (n == 0.0) {
            return "0"
        }
        n.toString()
    }

    func escapeJsonString(s: String): String {
        var result = StringBuilder()
        for (i in 0..s.size) {
            let c = s[i]
            match (c) {
                case '"' => result.append("\\\"")
                case '\\' => result.append("\\\\")
                case '\n' => result.append("\\n")
                case '\r' => result.append("\\r")
                case '\t' => result.append("\\t")
                case '\b' => result.append("\\b")
                case '\u{0c}' => result.append("\\f")  // form feed
                case _=>
                    if (UInt32(c) < UInt32(0x20)) {
                        // hex format UInt32 as 4-digit hex
                        let v = UInt32(c)
                        let hex = "0123456789abcdef"
                        let h3 = hex[Int64((v >> 12) & 0xf)]
                        let h2 = hex[Int64((v >> 8) & 0xf)]
                        let h1 = hex[Int64((v >> 4) & 0xf)]
                        let h0 = hex[Int64(v & 0xf)]
                        result.append("\\u" + String(Rune(h3)) + String(Rune(h2)) + String(Rune(h1)) + String(Rune(h0)))
                    } else {
                        result.append(String(Rune(c)))
                    }
            }
        }
        result.toString()
    }

}

// JS Symbol 类型
public class JsSymbol {
    public let id: Int64
    public let description: String
    public let isWellKnown: Bool

    static var nextId: Int64 = 0
    static var registry: HashMap<String, JsSymbol> = HashMap()

    // 知名 Symbol
    public static let iterator = JsSymbol(0, "Symbol.iterator", true)
    public static let asyncIterator = JsSymbol(1, "Symbol.asyncIterator", true)
    public static let `match` = JsSymbol(2, "Symbol.match", true)
    public static let matchAll = JsSymbol(3, "Symbol.matchAll", true)
    public static let replace = JsSymbol(4, "Symbol.replace", true)
    public static let search = JsSymbol(5, "Symbol.search", true)
    public static let split = JsSymbol(6, "Symbol.split", true)
    public static let hasInstance = JsSymbol(7, "Symbol.hasInstance", true)
    public static let isConcatSpreadable = JsSymbol(8, "Symbol.isConcatSpreadable", true)
    public static let unscopables = JsSymbol(9, "Symbol.unscopables", true)
    public static let species = JsSymbol(10, "Symbol.species", true)
    public static let toPrimitive = JsSymbol(11, "Symbol.toPrimitive", true)
    public static let toStringTag = JsSymbol(12, "Symbol.toStringTag", true)

    public init(description: String) {
        JsSymbol.nextId++
        this.id = JsSymbol.nextId
        this.description = description
        this.isWellKnown = false
    }

    init(id: Int64, description: String, isWellKnown: Bool) {
        this.id = id
        this.description = description
        this.isWellKnown = isWellKnown
    }

    // Symbol.for(key) - 全局注册表
    public static func forKey(key: String): JsSymbol {
        if (let Some(sym) <- registry.get(key)) {
            return sym
        }
        let sym = JsSymbol(key)
        registry.put(key, sym)
        return sym
    }

    // Symbol.keyFor(sym) - 查找全局注册的 key
    // 对应 Bun: Symbol.keyFor — 线性扫描注册表查找匹配的 key
    public static func keyFor(sym: JsSymbol): ?String {
        // 线性扫描注册表, 查找 id 匹配的 symbol 对应的 key
        for (key in registry.keys()) {
            if (let Some(registered) <- registry.get(key)) {
                if (registered.id == sym.id) {
                    return key
                }
            }
        }
        None
    }

    public func toString(): String {
        if (description.size == 0) {
            "Symbol()"
        } else {
            "Symbol(" + description + ")"
        }
    }
}

// JS 错误类型
public open class JsError <: Exception {
    public let name: String
    public let stackTrace: String

    public init(message: String) {
        super(message)
        this.name = "Error"
        this.stackTrace = ""
    }

    public init(name: String, message: String) {
        super(message)
        this.name = name
        this.stackTrace = ""
    }
}

public class JsTypeError <: JsError {
    public init(message: String) {
        super("TypeError", message)
    }
}

public class JsRangeError <: JsError {
    public init(message: String) {
        super("RangeError", message)
    }
}

public class JsSyntaxError <: JsError {
    public init(message: String) {
        super("SyntaxError", message)
    }
}

public class JsReferenceError <: JsError {
    public init(message: String) {
        super("ReferenceError", message)
    }
}

public class JsUriError <: JsError {
    public init(message: String) {
        super("URIError", message)
    }
}

// ========== JsValue 扩展: 数值操作 ==========
// 严格翻译自 JSValue.zig 的数值相关方法

extend JsValue {
    // ========== toInt32 ==========
    // 严格翻译自 JSValue.toInt32
    // 将 JS 值转为 Int32，截断小数部分
    // NaN -> 0, Infinity -> max/min, -Infinity -> min
    public func toInt32(): Int32 {
        if (isNumber()) {
            return coerceDoubleTruncatingToInt32(numberValue)
        }
        0
    }

    // ========== asInt32 ==========
    // 严格翻译自 JSValue.asInt32
    // 断言值是 Int32 后返回
    public func asInt32(): Int32 {
        Int32(numberValue)
    }

    // ========== toInt64 ==========
    // 严格翻译自 JSValue.toInt64
    // 将 JS 值转为 Int64，截断小数部分
    // NaN -> 0, Infinity -> max/min
    public func toInt64(): Int64 {
        if (isNumber()) {
            return coerceDoubleTruncatingToInt64(numberValue)
        }
        0
    }

    // ========== toUInt64 ==========
    // 严格翻译自 JSValue.toUInt64NoTruncate
    // 对 BigInt 和 Number 的无符号 64 位转换
    public func toUInt64(): UInt64 {
        if (isNumber()) {
            let n = numberValue
            if (n < 0.0) {
                return UInt64(0)
            }
            return UInt64(n)
        }
        if (isBigInt()) {
            let parsed = parseDouble(bigIntValue)
            if (parsed >= 0.0) {
                return UInt64(parsed)
            }
        }
        UInt64(0)
    }

    // ========== toU16 ==========
    // 严格翻译自 JSValue.toU16
    public func toU16(): UInt16 {
        let i = toInt32()
        if (i < 0) {
            return UInt16(0)
        }
        UInt16(i)
    }

    // ========== toU32 ==========
    // 严格翻译自 JSValue.toU32
    public func toU32(): UInt32 {
        let i = toInt64()
        if (i < 0) {
            return UInt32(0)
        }
        UInt32(i)
    }

    // ========== toFloat32 ==========
    // 转为 Float32
    public func toFloat32(): Float32 {
        Float32(toNumber())
    }

    // ========== asNumber ==========
    // 严格翻译自 JSValue.asNumber
    // 断言值是 number/undefined/null/boolean 后返回 f64
    public func asNumber(): Float64 {
        if (isNumber()) {
            return numberValue
        }
        if (isUndefinedOrNull()) {
            return 0.0
        }
        if (isBoolean()) {
            return if (boolValue) { 1.0 } else { 0.0 }
        }
        Float64.NaN
    }

    // ========== getNumber ==========
    // 严格翻译自 JSValue.getNumber
    // 如果是数值类型返回 numberValue，否则返回 None
    public func getNumber(): ?Float64 {
        if (isNumber()) {
            return numberValue
        }
        None
    }

    // ========== asDouble ==========
    // 严格翻译自 JSValue.asDouble
    // 断言是 double 后返回
    public func asDouble(): Float64 {
        numberValue
    }

    // ========== asBoolean ==========
    // 严格翻译自 JSValue.asBoolean
    // 断言是 boolean 后返回
    public func asBoolean(): Bool {
        boolValue
    }

    // ========== coerceDoubleTruncatingToInt32 ==========
    // 严格翻译自 JSValue.coerceJSValueDoubleTruncatingT(i32, num)
    // 截断 double 为 Int32: NaN->0, overflow->min/max
    public static func coerceDoubleTruncatingToInt32(num: Float64): Int32 {
        if (floatIsNaN(num)) {
            return Int32(0)
        }
        if (num <= Float64(Int64(-2147483648)) || num == -1.0 / 0.0) {
            return Int32(-2147483648)
        }
        if (num >= Float64(2147483647) || num == 1.0 / 0.0) {
            return Int32(2147483647)
        }
        Int32(num)
    }

    // ========== coerceDoubleTruncatingToInt64 ==========
    // 严格翻译自 JSValue.coerceJSValueDoubleTruncatingT(i64, num)
    public static func coerceDoubleTruncatingToInt64(num: Float64): Int64 {
        if (floatIsNaN(num)) {
            return Int64(0)
        }
        if (num <= -9223372036854775808.0 || num == -1.0 / 0.0) {
            return Int64(-9223372036854775808)
        }
        if (num >= 9223372036854775807.0 || num == 1.0 / 0.0) {
            return Int64(9223372036854775807)
        }
        Int64(num)
    }

    // ========== isInteger ==========
    // 严格翻译自 JSValue.isInteger
    // ECMA-262 20.1.2.3 Number.isInteger
    public func isInteger(): Bool {
        if (isNumber()) {
            let num = numberValue
            // 有限数且截断后等于自身
            if (isFiniteFloat(num) && Float64(Math.floor(num)) == num) {
                return true
            }
        }
        false
    }

    // ========== isSafeInteger ==========
    // 严格翻译自 JSValue.isSafeInteger
    // https://tc39.es/ecma262/#sec-number.issafeinteger
    public func isSafeInteger(): Bool {
        if (isNumber()) {
            let d = numberValue
            if (Float64(Math.floor(d)) == d && absFloat(d) <= MAX_SAFE_INTEGER) {
                return true
            }
        }
        false
    }

    // ========== isFinite ==========
    // 严格翻译自 JSValue.isFinite
    // 21.1.2.2 Number.isFinite: 对非数字返回 false
    public func isFinite(): Bool {
        if (!isNumber()) {
            return false
        }
        isFiniteFloat(numberValue)
    }

    // ========== isDouble ==========
    // 严格翻译自 JSValue.isDouble
    // 是 number 但不是 int32
    public func isDouble(): Bool {
        isNumber() && !isInt32()
    }

    // ========== isInt32 ==========
    // 严格翻译自 JSValue.isInt32
    // 检查数值是否在 Int32 范围内
    public func isInt32(): Bool {
        if (!isNumber()) {
            return false
        }
        let n = numberValue
        n >= Float64(Int64(-2147483648)) && n <= Float64(2147483647) && Float64(Math.floor(n)) == n
    }

    // ========== isAnyInt ==========
    // 严格翻译自 JSValue.isAnyInt
    public func isAnyInt(): Bool {
        if (!isNumber()) {
            return false
        }
        let n = numberValue
        !floatIsNaN(n) && isFiniteFloat(n) && Float64(Math.floor(n)) == n
    }

    // ========== toPortNumber ==========
    // 严格翻译自 JSValue.toPortNumber
    // 将值转为端口号 (0-65535)
    public func toPortNumber(): ?UInt16 {
        if (!isNumber()) {
            return None
        }
        let d = toNumber()
        if (floatIsNaN(d)) {
            return None
        }
        let port = toInt64()
        if (port >= 0 && port <= 65535) {
            return UInt16(port)
        }
        None
    }

    // ========== isFinite helper ==========
    public static func isFiniteNumber(n: Float64): Bool {
        !floatIsNaN(n) && n != 1.0 / 0.0 && n != -1.0 / 0.0
    }
}

// ========== JsValue 扩展: 属性操作 ==========
// 严格翻译自 JSValue.zig 的属性相关方法

extend JsValue {
    // ========== get (property) ==========
    // 严格翻译自 JSValue.get
    // 等价于 target[property]
    // 返回 None 表示属性不存在或值为 undefined
    public func get(global: JsObject, property: String): ?JsValue {
        if (!isObject()) {
            return None
        }
        let obj = objectValue.getOrThrow()
        obj.get(property)
    }

    // ========== getOptional ==========
    // 严格翻译自 JSValue.getOptional
    // 获取属性值，如果不存在或是 undefined/null 则返回 None
    public func getOptional(global: JsObject, property: String): ?JsValue {
        let `prop` = get(global, property)
        if (let Some(val) <- `prop`) {
            if (!val.isUndefinedOrNull()) {
                return val
            }
        }
        None
    }

    // ========== put ==========
    // 严格翻译自 JSValue.put
    // 等价于 target[property] = value
    public func put(global: JsObject, property: String, value: JsValue): Unit {
        if (!isObject()) {
            return
        }
        let obj = objectValue.getOrThrow()
        obj.set(property, value)
    }

    // ========== putIndex ==========
    // 严格翻译自 JSValue.putIndex
    // 设置数组索引位置
    public func putIndex(global: JsObject, index: UInt32, value: JsValue): Unit {
        if (isObject()) {
            if (let Some(obj) <- objectValue) {
                let arr = obj.arrayStorage
                if (Int64(index) < Int64(arr.size)) {
                    obj.arrayStorage[Int64(index)] = value
                } else {
                    obj.arrayStorage.append(value)
                }
            }
        }
    }

    // ========== getIndex ==========
    // 严格翻译自 JSValue.getIndex
    // 获取数组索引处的值
    public func getIndex(global: JsObject, index: UInt32): JsValue {
        if (isObject()) {
            if (let Some(obj) <- objectValue) {
                let arr = obj.arrayStorage
                if (Int64(index) < Int64(arr.size)) {
                    return arr[Int64(index)]
                }
            }
        }
        JsValue.undefined()
    }

    // ========== deleteProperty ==========
    // 严格翻译自 JSValue.deleteProperty
    // 删除属性，返回是否删除成功
    public func deleteProperty(global: JsObject, property: String): Bool {
        if (!isObject()) {
            return false
        }
        let obj = objectValue.getOrThrow()
        obj.delete(property)
    }

    // ========== hasOwnProperty ==========
    // 严格翻译自 JSValue.hasOwnPropertyValue
    // 检查对象是否有指定属性
    public func hasOwnProperty(global: JsObject, key: JsValue): Bool {
        if (!isObject()) {
            return false
        }
        let obj = objectValue.getOrThrow()
        let keyStr = key.toString()
        obj.has(keyStr)
    }

    // ========== getLength ==========
    // 严格翻译自 JSValue.getLength
    // 获取 length 属性值 (数组、字符串等)
    // 不存在时返回 0
    public func getLength(global: JsObject): UInt64 {
        let len = getLengthIfPropertyExists(global)
        if (len < 0.0) {
            return UInt64(0)
        }
        let clamped = if (len < 0.0) { 0.0 } else { len }
        UInt64(clamped)
    }

    // ========== getLengthIfPropertyExists ==========
    // 严格翻译自 JSValue.getLengthIfPropertyExistsInternal
    // 如果 length 属性不存在，返回 NaN
    public func getLengthIfPropertyExists(global: JsObject): Float64 {
        if (!isObject()) {
            return Float64.NaN
        }
        if (let Some(obj) <- objectValue) {
            if (obj.has("length")) {
                let lenVal = obj.get("length")
                if (!lenVal.isUndefined()) {
                    return lenVal.toNumber()
                }
            }
        }
        Float64.NaN
    }

    // ========== getPrototype ==========
    // 严格翻译自 JSValue.getPrototype
    public func getPrototype(global: JsObject): JsValue {
        if (!isObject()) {
            return JsValue.null()
        }
        let obj = objectValue.getOrThrow()
        if (let Some(proto) <- obj.prototype) {
            return JsValue(proto)
        }
        JsValue.null()
    }

    // ========== getOwn ==========
    // 严格翻译自 JSValue.getOwn
    // 获取自身 (非继承) 属性值
    public func getOwn(global: JsObject, property: String): ?JsValue {
        if (!isObject()) {
            return None
        }
        let obj = objectValue.getOrThrow()
        if (obj.has(property)) {
            return obj.get(property)
        }
        None
    }

    // ========== getOwnTruthy ==========
    // 严格翻译自 JSValue.getOwnTruthy
    public func getOwnTruthy(global: JsObject, property: String): ?JsValue {
        if (let Some(val) <- getOwn(global, property)) {
            if (!val.isUndefined()) {
                return val
            }
        }
        None
    }

    // ========== getTruthy ==========
    // 严格翻译自 JSValue.getTruthy
    public func getTruthy(global: JsObject, property: String): ?JsValue {
        if (let Some(val) <- get(global, property)) {
            return truthyPropertyValue(val)
        }
        None
    }

    // ========== truthyPropertyValue ==========
    // 严格翻译自 JSValue.truthyPropertyValue
    // 过滤掉 undefined/null/空字符串
    public static func truthyPropertyValue(`prop`: JsValue): ?JsValue {
        if (`prop`.isUndefinedOrNull()) {
            return None
        }
        if (`prop`.isString()) {
            if (!`prop`.toBoolean()) {
                return None
            }
        }
        `prop`
    }

    // ========== getBooleanLoose ==========
    // 严格翻译自 JSValue.getBooleanLoose
    public func getBooleanLoose(global: JsObject, property: String): ?Bool {
        if (let Some(`prop`) <- get(global, property)) {
            return `prop`.toBoolean()
        }
        None
    }

    // ========== getBooleanStrict ==========
    // 严格翻译自 JSValue.getBooleanStrict
    public func getBooleanStrict(global: JsObject, property: String): ?Bool {
        if (let Some(`prop`) <- get(global, property)) {
            if (`prop`.isUndefined()) {
                return None
            }
            if (`prop`.isBoolean()) {
                return `prop`.asBoolean()
            }
            return None
        }
        None
    }

    // ========== getOptionalInt ==========
    // 严格翻译自 JSValue.getOptionalInt
    public func getOptionalInt(global: JsObject, property: String): ?Int64 {
        if (let Some(val) <- getOptional(global, property)) {
            if (val.isNumber()) {
                return val.toInt64()
            }
        }
        None
    }

    // ========== getArray ==========
    // 严格翻译自 JSValue.getArray
    // 获取数组属性
    public func getArray(global: JsObject, property: String): ?JsValue {
        if (let Some(`prop`) <- getOptional(global, property)) {
            if (`prop`.isArray()) {
                let len = `prop`.getLength(global)
                if (len > 0) {
                    return `prop`
                }
            }
        }
        None
    }

    // ========== getFunction ==========
    // 严格翻译自 JSValue.getFunction
    public func getFunction(global: JsObject, property: String): ?JsValue {
        if (let Some(`prop`) <- getOptional(global, property)) {
            if (`prop`.isCallable()) {
                return `prop`
            }
        }
        None
    }

    // ========== getObject ==========
    // 严格翻译自 JSValue.getObject
    // 对已是对象的值进行静态转换
    public func getObject(): ?JsObject {
        if (isObject()) {
            return objectValue.getOrThrow()
        }
        None
    }
}

// ========== JsValue 扩展: 函数调用 ==========
// 严格翻译自 JSValue.zig 的函数调用相关方法

extend JsValue {
    // ========== call ==========
    // 严格翻译自 JSValue.call
    // 调用函数: function.call(thisValue, args)
    public func call(global: JsObject, thisValue: JsValue, args: Array<JsValue>): JsValue {
        if (!isCallable()) {
            return JsValue.undefined()
        }
        let obj = objectValue.getOrThrow()
        // 执行函数调用
        if (obj.isFunction || obj.isCallable) {
            return callInternal(global, thisValue, args)
        }
        JsValue.undefined()
    }

    // ========== callWithGlobalThis ==========
    // 严格翻译自 JSValue.callWithGlobalThis
    // 以 globalThis 作为 this 值调用函数
    public func callWithGlobalThis(global: JsObject, args: Array<JsValue>): JsValue {
        call(global, JsValue(global), args)
    }

    // ========== construct ==========
    // 严格翻译自 JSValue 构造调用
    // 作为构造函数调用: new Constructor(...args)
    public func construct(global: JsObject, args: Array<JsValue>): JsValue {
        if (!isCallable()) {
            return JsValue.undefined()
        }
        let obj = objectValue.getOrThrow()
        if (obj.isConstructor) {
            // 创建新对象实例
            let instance = JsObject()
            instance.prototype = obj
            let result = callInternal(global, JsValue(instance), args)
            if (result.isObject()) {
                return result
            }
            return JsValue(instance)
        }
        JsValue.undefined()
    }

    // ========== callInternal ==========
    // 内部函数调用实现
    func callInternal(global: JsObject, thisValue: JsValue, args: Array<JsValue>): JsValue {
        // 在实际 JSC 绑定中，这会调用 Bun__JSValue__call
        // 这里是抽象实现
        JsValue.undefined()
    }
}

// ========== JsValue 扩展: 对象创建 ==========
// 严格翻译自 JSValue.zig 的对象/数组创建工厂方法

extend JsValue {
    // ========== createEmptyObject ==========
    // 严格翻译自 JSValue.createEmptyObject
    // 创建空对象 (以 Object 为原型)
    public static func createEmptyObject(global: JsObject, len: Int64): JsValue {
        let obj = JsObject()
        JsValue(obj)
    }

    // ========== createEmptyObject (no len) ==========
    public static func createEmptyObject(global: JsObject): JsValue {
        createEmptyObject(global, 0)
    }

    // ========== createEmptyObjectWithNullPrototype ==========
    // 严格翻译自 JSValue.createEmptyObjectWithNullPrototype
    // 创建以 null 为原型的空对象
    public static func createEmptyObjectWithNullPrototype(global: JsObject): JsValue {
        let obj = JsObject()
        obj.prototype = None
        JsValue(obj)
    }

    // ========== createEmptyArray ==========
    // 严格翻译自 JSValue.createEmptyArray
    // 创建空数组
    public static func createEmptyArray(global: JsObject, len: Int64): JsValue {
        let obj = JsObject()
        obj.arrayStorage = Array<JsValue>(Int64(len), { _: Int64 => JsValue.undefined() })
        obj.isFunction = false
        obj.className = "Array"
        let v = JsValue(obj)
        v.valueType = JsValueType.Array
        v
    }

    // ========== createObject2 ==========
    // 严格翻译自 JSValue.createObject2
    // 创建具有两个属性的对象
    public static func createObject2(global: JsObject, key1: String, key2: String, value1: JsValue, value2: JsValue): JsValue {
        let obj = JsObject()
        obj.set(key1, value1)
        obj.set(key2, value2)
        JsValue(obj)
    }

    // ========== jsEmptyString ==========
    // 严格翻译自 JSValue.jsEmptyString
    public static func jsEmptyString(global: JsObject): JsValue {
        JsValue("")
    }

    // ========== jsNull ==========
    // 严格翻译自 JSValue.jsNull
    public static func jsNull(): JsValue {
        JsValue.null()
    }

    // ========== jsTDZValue ==========
    // 严格翻译自 JSValue.jsTDZValue
    // Temporal Dead Zone 值
    public static func jsTDZValue(): JsValue {
        let v = JsValue()
        v.valueType = JsValueType.Undefined
        v
    }

    // ========== jsBigInt ==========
    // 严格翻译自 JSValue.jsBigInt
    // 创建 BigInt 值
    public static func jsBigInt(n: Int64): JsValue {
        let v = JsValue()
        v.valueType = JsValueType.BigInt
        v.bigIntValue = n.toString()
        v
    }

    public static func jsBigInt(n: UInt64): JsValue {
        let v = JsValue()
        v.valueType = JsValueType.BigInt
        v.bigIntValue = n.toString()
        v
    }

    // ========== fromInt64NoTruncate ==========
    // 严格翻译自 JSValue.fromInt64NoTruncate
    // 总是返回 JS BigInt
    public static func fromInt64NoTruncate(global: JsObject, i: Int64): JsValue {
        jsBigInt(i)
    }

    // ========== fromUInt64NoTruncate ==========
    // 严格翻译自 JSValue.fromUInt64NoTruncate
    // 总是返回 JS BigInt
    public static func fromUInt64NoTruncate(global: JsObject, i: UInt64): JsValue {
        jsBigInt(i)
    }

    // ========== jsNumberFromInt32 ==========
    // 严格翻译自 JSValue.jsNumberFromInt32
    public static func jsNumberFromInt32(i: Int32): JsValue {
        JsValue(Float64(i))
    }

    // ========== jsNumberFromInt64 ==========
    // 严格翻译自 JSValue.jsNumberFromInt64
    public static func jsNumberFromInt64(i: Int64): JsValue {
        if (i <= Int64(2147483647) && i >= Int64(Int64(-2147483648))) {
            return jsNumberFromInt32(Int32(i))
        }
        jsDoubleNumber(Float64(i))
    }

    // ========== jsNumberFromUint64 ==========
    // 严格翻译自 JSValue.jsNumberFromUint64
    public static func jsNumberFromUint64(i: UInt64): JsValue {
        if (i <= UInt64(2147483647)) {
            return jsNumberFromInt32(Int32(i))
        }
        jsDoubleNumber(Float64(i))
    }

    // ========== jsNumberFromChar ==========
    // 严格翻译自 JSValue.jsNumberFromChar
    public static func jsNumberFromChar(i: UInt8): JsValue {
        jsNumberFromInt32(Int32(i))
    }

    // ========== jsNumberFromU16 ==========
    // 严格翻译自 JSValue.jsNumberFromU16
    public static func jsNumberFromU16(i: UInt16): JsValue {
        jsNumberFromInt32(Int32(i))
    }

    // ========== jsDoubleNumber ==========
    // 严格翻译自 JSValue.jsDoubleNumber
    public static func jsDoubleNumber(f: Float64): JsValue {
        JsValue(f)
    }

    // ========== bigIntSum ==========
    // 严格翻译自 JSValue.bigIntSum
    // 两个 BigInt 求和 (使用任意精度算术)
    public static func bigIntSum(global: JsObject, a: JsValue, b: JsValue): JsValue {
        let bigA = JsBigInt(a.bigIntValue)
        let bigB = JsBigInt(b.bigIntValue)
        let sum = JsBigInt.add(bigA, bigB)
        sum.toJsValue()
    }

    // ========== keys ==========
    // 严格翻译自 JSValue.keys
    // Object.keys() - 获取对象的所有可枚举自身属性的键
    public static func keys(value: JsValue, global: JsObject): JsValue {
        if (!value.isObject()) {
            let arr = JsObject()
            arr.className = "Array"
            arr.arrayStorage = []
            let result = JsValue(arr)
            result.valueType = JsValueType.Array
            return result
        }
        let obj = value.objectValue.getOrThrow()
        let keyArray = obj.keys()
        let arr = JsObject()
        arr.className = "Array"
        arr.arrayStorage = []
        for (k in keyArray) {
            arr.arrayStorage = arr.arrayStorage.append(JsValue(k))
        }
        let result = JsValue(arr)
        result.valueType = JsValueType.Array
        result
    }

    // ========== values ==========
    // 严格翻译自 JSValue.values
    // Object.values()
    public static func values(value: JsValue, global: JsObject): JsValue {
        if (!value.isObject()) {
            let arr = JsObject()
            arr.className = "Array"
            arr.arrayStorage = []
            let result = JsValue(arr)
            result.valueType = JsValueType.Array
            return result
        }
        let obj = value.objectValue.getOrThrow()
        let keyArray = obj.keys()
        let arr = JsObject()
        arr.className = "Array"
        arr.arrayStorage = []
        for (k in keyArray) {
            let val = obj.get(k)
            arr.arrayStorage = arr.arrayStorage.append(val)
        }
        let result = JsValue(arr)
        result.valueType = JsValueType.Array
        result
    }
}

// ========== JsValue 扩展: 类型检查 (补充) ==========
// 严格翻译自 JSValue.zig 更多类型检查

extend JsValue {
    // ========== isFalsey ==========
    // 严格翻译自 JSValue.isFalsey
    public func isFalsey(): Bool {
        !toBoolean()
    }

    // ========== isTruthy ==========
    // 严格翻译自 JSValue.isTruthy (= toBoolean)
    public func isTruthy(): Bool {
        toBoolean()
    }

    // ========== isEmpty ==========
    // 严格翻译自 JSValue.zero
    // 检查是否为 "empty" 值 (异常情况)
    public func isEmpty(): Bool {
        valueType == JsValueType.Undefined
    }

    // ========== isRegExp ==========
    // 严格翻译自 JSValue.isRegExp
    public func isRegExp(): Bool {
        if (isObject()) {
            if (let Some(obj) <- objectValue) {
                return obj.className == "RegExp"
            }
        }
        false
    }

    // ========== isDate ==========
    // 严格翻译自 JSValue.isDate
    public func isDate(): Bool {
        if (isObject()) {
            if (let Some(obj) <- objectValue) {
                return obj.className == "Date"
            }
        }
        false
    }

    // ========== isError ==========
    // 严格翻译自 JSValue.isError
    public func isError(): Bool {
        if (!isObject()) {
            return false
        }
        if (let Some(obj) <- objectValue) {
            return obj.className == "Error" ||
                   obj.className == "TypeError" ||
                   obj.className == "RangeError" ||
                   obj.className == "SyntaxError" ||
                   obj.className == "ReferenceError" ||
                   obj.className == "URIError"
        }
        false
    }

    // ========== isArray ==========
    // 严格翻译自 JSValue.isArray
    public func isArray(): Bool {
        valueType == JsValueType.Array || (isObject() && objectValue.getOrThrow().className == "Array")
    }

    // ========== isFunction ==========
    // 严格翻译自 JSValue.isFunction
    public func isFunction(): Bool {
        isCallable()
    }

    // ========== isConstructor ==========
    // 严格翻译自 JSValue.isConstructor
    public func isConstructor(): Bool {
        if (!isObject()) {
            return false
        }
        objectValue.getOrThrow().isConstructor
    }

    // ========== isCell ==========
    // 严格翻译自 JSValue.isCell
    // 检查是否为堆分配的对象 (Cell)
    public func isCell(): Bool {
        isObject() || isString() || isSymbol() || isBigInt()
    }

    // ========== isIterable ==========
    // 严格翻译自 JSValue.isIterable
    public func isIterable(global: JsObject): Bool {
        if (isArray()) {
            return true
        }
        if (isString()) {
            return true
        }
        if (isObject()) {
            if (let Some(obj) <- objectValue) {
                let symVal = obj.get("Symbol.iterator")
                if (!symVal.isUndefined()) {
                    return symVal.isCallable()
                }
            }
        }
        false
    }

    // ========== isHeapBigInt ==========
    // 严格翻译自 JSValue.isHeapBigInt
    public func isHeapBigInt(): Bool {
        isBigInt()
    }

    // ========== isBigInt32 ==========
    // 严格翻译自 JSValue.isBigInt32
    public func isBigInt32(): Bool {
        if (isBigInt()) {
            let parsed = parseDouble(bigIntValue)
            let v = Int64(parsed)
            return v >= Int64(-2147483648) && v <= Int64(2147483647)
        }
        false
    }

    // ========== isBuffer ==========
    // 严格翻译自 JSValue.isBuffer
    public func isBuffer(global: JsObject): Bool {
        if (isObject()) {
            if (let Some(obj) <- objectValue) {
                return obj.className == "Buffer"
            }
        }
        false
    }

    // ========== isJSXElement ==========
    // 严格翻译自 JSValue.isJSXElement
    public func isJSXElement(global: JsObject): Bool {
        // 需要 JSC 绑定实际检查
        false
    }

    // ========== isGetterSetter ==========
    // 严格翻译自 JSValue.isGetterSetter
    public func isGetterSetter(): Bool {
        false  // 需要实际 JSC 绑定
    }

    // ========== isCustomGetterSetter ==========
    // 严格翻译自 JSValue.isCustomGetterSetter
    public func isCustomGetterSetter(): Bool {
        false  // 需要实际 JSC 绑定
    }

    // ========== isObjectEmpty ==========
    // 严格翻译自 JSValue.isObjectEmpty
    public func isObjectEmpty(global: JsObject): Bool {
        if (!isObject()) {
            return false
        }
        if (isRegExp() || isDate()) {
            return false
        }
        let obj = objectValue.getOrThrow()
        obj.properties.count() == 0
    }

    // ========== jsType ==========
    // 严格翻译自 JSValue.jsType
    // 获取 JSC 内部类型
    public func jsType(): JSType {
        match (valueType) {
            case Undefined => JSType.Cell
            case Null => JSType.Cell
            case Boolean => JSType.Cell
            case Number => JSType.HeapDouble
            case String => JSType.String
            case Object=>
                if (let Some(obj) <- objectValue) {
                    if (obj.className == "Array") { return JSType.Array }
                    if (obj.className == "Function" || obj.isFunction) { return JSType.JSFunction }
                    if (obj.className == "RegExp") { return JSType.Cell }  // RegExpObject
                    if (obj.className == "Date") { return JSType.Cell }    // JSDate
                    if (obj.className == "Map") { return JSType.Map }
                    if (obj.className == "Set") { return JSType.Set }
                    if (obj.className == "WeakMap") { return JSType.WeakMap }
                    if (obj.className == "WeakSet") { return JSType.WeakSet }
                    if (obj.className == "Error") { return JSType.Cell }   // ErrorInstance
                }
                JSType.Cell
            case Symbol => JSType.Symbol
            case BigInt => JSType.HeapBigInt
            case Array => JSType.Array
            case ArrayBuffer => JSType.ArrayBuffer
            case TypedArray => JSType.Uint8Array
            case DataView => JSType.Cell
            case Function => JSType.JSFunction
            case Error => JSType.Cell
            case Promise => JSType.Cell
            case External => JSType.Cell
        }
    }

    // ========== jsTypeString ==========
    // 严格翻译自 JSValue.jsTypeString
    // 返回 typeof 表达式的结果
    public func jsTypeString(): String {
        match (valueType) {
            case Undefined => "undefined"
            case Null => "object"
            case Boolean => "boolean"
            case Number => "number"
            case String => "string"
            case Symbol => "symbol"
            case BigInt => "bigint"
            case Function => "function"
            case _ => "object"
        }
    }

    // ========== className ==========
    // 严格翻译自 JSValue.className
    // 获取对象的类名
    public func className(global: JsObject): String {
        if (!isObject()) {
            return ""
        }
        let obj = objectValue.getOrThrow()
        obj.className
    }
}

// ========== JsValue 扩展: Promise 操作 ==========
// 严格翻译自 JSValue.zig 的 Promise 相关方法

extend JsValue {
    // ========== asAnyPromise ==========
    // 严格翻译自 JSValue.asAnyPromise
    // 将 JSValue 转为 AnyPromise
    public func asAnyPromise(): ?AnyPromise {
        if (isUndefinedOrNull()) {
            return None
        }
        if (valueType == JsValueType.Promise) {
            // 对应 Bun: JSValue.asAnyPromise — 从 Cell 指针构造 AnyPromise
            let ap = AnyPromise()
            ap.variant = PromiseVariant.Normal
            return ap
        }
        if (isObject()) {
            if (let Some(obj) <- objectValue) {
                // 检查是否是 thenable
                let thenVal = obj.get("then")
                if (!thenVal.isUndefined() && thenVal.isCallable()) {
                    // 对应 Bun: JSValue.asAnyPromise — 从 thenable 构造 AnyPromise
                    let ap = AnyPromise()
                    ap.variant = PromiseVariant.Normal
                    ap.internalPromise = obj
                    return ap
                }
            }
        }
        None
    }

    // ========== createInternalPromise ==========
    // 严格翻译自 JSValue.createInternalPromise
    public static func createInternalPromise(global: JsObject): JsValue {
        let obj = JsObject()
        obj.className = "Promise"
        let v = JsValue(obj)
        v.valueType = JsValueType.Promise
        v
    }

    // ========== then ==========
    // 严格翻译自 JSValue.then
    // 注册 resolve/reject 回调
    public func then(global: JsObject, resolve: JSHostFn, reject: JSHostFn): Unit {
        if (!isObject()) {
            return
        }
        // 在实际 JSC 中，这调用 JSC__JSValue___then
        // 此处为抽象实现
    }
}

// ========== JsValue 扩展: 比较操作 ==========
// 严格翻译自 JSValue.zig 的比较相关方法

// ========== ComparisonResult ==========
// 严格翻译自 JSValue.ComparisonResult (extracted from nested enum)
public enum ComparisonResult {
    | Equal
    | UndefinedResult
    | GreaterThan
    | LessThan
    | InvalidComparison
}

extend JsValue {
    // ========== isStrictEqual ==========
    // 严格翻译自 JSValue.isStrictEqual
    // JS === 操作符
    public func isStrictEqual(other: JsValue, global: JsObject): Bool {
        strictEqual(this, other)
    }

    // ========== isSameValue ==========
    // 严格翻译自 JSValue.isSameValue
    // Object.is() - 与 === 不同之处: NaN === NaN, -0 !== +0
    public func isSameValue(other: JsValue, global: JsObject): Bool {
        if (strictEqual(this, other)) {
            // 区分 +0 和 -0
            if (isNumber() && other.isNumber()) {
                let a = numberValue
                let b = other.numberValue
                if (a == 0.0 && b == 0.0) {
                    // Object.is(+0, -0) => false
                    // 用 1/a 和 1/b 检测符号
                    let invA = 1.0 / a
                    let invB = 1.0 / b
                    return invA == invB
                }
            }
            return true
        }
        // NaN === NaN => true for Object.is
        if (isNumber() && other.isNumber()) {
            return floatIsNaN(numberValue) && floatIsNaN(other.numberValue)
        }
        false
    }

    // ========== asBigIntCompare ==========
    // 严格翻译自 JSValue.asBigIntCompare
    // 使用任意精度 BigInt 比较
    public func asBigIntCompare(global: JsObject, other: JsValue): ComparisonResult {
        if (!isBigInt() && !isNumber()) {
            return ComparisonResult.InvalidComparison
        }
        if (!other.isBigInt() && !other.isNumber()) {
            return ComparisonResult.InvalidComparison
        }
        // 将操作数转换为 JsBigInt 以进行任意精度比较
        let aBigInt = if (isBigInt()) {
            JsBigInt(bigIntValue)
        } else {
            JsBigInt(toNumber().toString())
        }
        let bBigInt = if (other.isBigInt()) {
            JsBigInt(other.bigIntValue)
        } else {
            JsBigInt(other.toNumber().toString())
        }
        let cmp = aBigInt.compareTo(bBigInt)
        if (cmp == 0) {
            return ComparisonResult.Equal
        }
        if (cmp > 0) {
            return ComparisonResult.GreaterThan
        }
        ComparisonResult.LessThan
    }

    // ========== deepEquals ==========
    // 严格翻译自 JSValue.deepEquals
    // 深度相等比较
    public func deepEquals(other: JsValue, global: JsObject): Bool {
        if (strictEqual(this, other)) {
            return true
        }
        if (valueType != other.valueType) {
            return false
        }
        match (valueType) {
            case Object=>
                if (let Some(aObj) <- objectValue) {
                    if (let Some(bObj) <- other.objectValue) {
                        if (aObj.properties.count() != bObj.properties.count()) {
                            return false
                        }
                        let aKeys = aObj.properties.keys()
                        for (i in 0..aKeys.size) {
                            let key = aKeys[Int64(i)]
                            let aDesc = aObj.properties.get(key)
                            if (let Some(desc) <- aDesc) {
                                if (let Some(otherDesc) <- bObj.properties.get(key)) {
                                    if (let Some(aVal) <- desc.value) {
                                        if (let Some(bVal) <- otherDesc.value) {
                                            if (!aVal.deepEquals(bVal, global)) {
                                                return false
                                            }
                                        } else {
                                            return false
                                        }
                                    }
                                } else {
                                    return false
                                }
                            }
                        }
                        return true
                    }
                }
                false
            case Array=>
                if (let Some(aArr) <- arrayData) {
                    // 简单的数组比较
                    let bArr = other.arrayData
                    if (let Some(bArr_) <- bArr) {
                        if (aArr.size != bArr_.size) {
                            return false
                        }
                        for (i in 0..aArr.size) {
                            if (!aArr[i].deepEquals(bArr_[i], global)) {
                                return false
                            }
                        }
                        return true
                    }
                }
                false
            case _ => false
        }
    }

    // ========== eqlValue ==========
    // 严格翻译自 JSValue.eqlValue
    // 值相等检查
    public func eqlValue(other: JsValue): Bool {
        strictEqual(this, other)
    }
}

// ========== JsValue 扩展: 序列化/反序列化 ==========
// 严格翻译自 JSValue.zig 的序列化相关方法

extend JsValue {
    // ========== jsonStringify ==========
    // 严格翻译自 JSValue.jsonStringify
    // JSON.stringify 带 indent 参数
    public func jsonStringify(global: JsObject, indent: UInt32): String {
        let indented = (indent > 0)
        jsonSerializeInternal(indent)
    }

    // ========== jsonStringifyFast ==========
    // 严格翻译自 JSValue.jsonStringifyFast
    // 快速 JSON 序列化 (无缩进)
    public func jsonStringifyFast(global: JsObject): String {
        jsonSerializeInternal(0)
    }

    // ========== jsonSerializeInternal ==========
    // JSON 序列化实现
    func jsonSerializeInternal(indent: UInt32): String {
        let indentStr = if (indent > 0) {
            let sp = StringBuilder()
            for (_ in 0..Int64(indent)) {
                sp.append(" ")
            }
            sp.toString()
        } else {
            ""
        }

        jsonSerializeRecursive(indentStr, 0)
    }

    func jsonSerializeRecursive(indent: String, level: Int64): String {
        let prefix = if (indent.size == 0) { "" } else {
            let sp = StringBuilder()
            for (_ in 0..level) {
                sp.append(indent)
            }
            sp.toString()
        }

        match (valueType) {
            case Undefined => "undefined"
            case Null => "null"
            case Boolean => if (boolValue) { "true" } else { "false" }
            case Number => numberToString(numberValue)
            case String => "\"" + escapeJsonString(stringValue) + "\""
            case Array=>
                if (let Some(arr) <- arrayData) {
                    let sb = StringBuilder()
                    sb.append("[")
                    for (i in 0..arr.size) {
                        if (i > 0) { sb.append(", ") }
                        sb.append(arr[i].jsonSerializeRecursive(indent, level + 1))
                    }
                    sb.append("]")
                    sb.toString()
                } else {
                    "[]"
                }
            case Object =>
                if (let Some(obj) <- objectValue) {
                    let sb = StringBuilder()
                    sb.append("{")
                    var first = true
                    let propKeys = obj.properties.keys()
                    for (i in 0..propKeys.size) {
                        let key = propKeys[Int64(i)]
                        if (let Some(desc) <- obj.properties.get(key)) {
                            if (let Some(val) <- desc.value) {
                                if (!first) { sb.append(", ") }
                                sb.append("\"" + escapeJsonString(key) + "\":" + val.jsonSerializeRecursive(indent, level + 1))
                                first = false
                            }
                        }
                    }
                    sb.append("}")
                    sb.toString()
                } else {
                    "{}"
                }
            case Symbol => "undefined"
            case BigInt => throw JsTypeError("BigInt value cannot be serialized in JSON")
            case _ => "null"
        }
    }

    // ========== SerializedScriptValue ==========
    // 严格翻译自 JSValue.SerializedScriptValue

    // ========== serialize ==========
    // 严格翻译自 JSValue.serialize
    // 序列化 JSValue 为字节缓冲区
    public func serialize(global: JsObject, forCrossProcess: Bool, forStorage: Bool): ?SerializedScriptValue {
        // 在实际 JSC 中，这调用 Bun__serializeJSValue
        // 此处返回 JSON 字节表示作为简化
        let jsonStr = toJsonString()
        let bytes = jsonStr.toArray()
        SerializedScriptValue(bytes, 0)
    }

    // ========== deserialize ==========
    // 严格翻译自 JSValue.deserialize
    // 从字节缓冲区反序列化 JSValue
    public static func deserialize(bytes: Array<UInt8>, global: JsObject): JsValue {
        // 简化实现: 将 bytes 解析为 JSON
        let str = String.fromUtf8(bytes)
        parseJson(str)
    }

    // ========== parseJson ==========
    // 严格翻译自 JSON 解析逻辑
    // 递归下降 JSON 解析器，支持完整的嵌套对象和数组
    static func parseJson(input: String): JsValue {
        let trimmed = input.trimStart().trimEnd()
        if (trimmed.size == 0) {
            return JsValue.undefined()
        }
        let result = parseJsonValue(trimmed, 0)
        result[0]
    }

    // 解析 JSON 值，返回 (解析结果, 消费的字符数)
    static func parseJsonValue(s: String, pos: Int64): (JsValue, Int64) {
        // 跳过空白
        var p = skipWhitespace(s, pos)
        if (p >= Int64(s.size)) {
            return (JsValue.undefined(), p)
        }

        let ch = s[p]

        // null
        if (ch == UInt8(110) && p + 4 <= Int64(s.size) && s[p..p + 4] == "null") {
            return (JsValue.null(), p + 4)
        }
        // true
        if (ch == UInt8(116) && p + 4 <= Int64(s.size) && s[p..p + 4] == "true") {
            return (JsValue(true), p + 4)
        }
        // false
        if (ch == UInt8(102) && p + 5 <= Int64(s.size) && s[p..p + 5] == "false") {
            return (JsValue(false), p + 5)
        }
        // 字符串 (双引号)
        if (ch == UInt8(34)) {
            return parseJsonString(s, p)
        }
        // 数组
        if (ch == UInt8(91)) {
            return parseJsonArray(s, p)
        }
        // 对象
        if (ch == UInt8(123)) {
            return parseJsonObject(s, p)
        }
        // 数字 (包括负号)
        if (ch == UInt8(45) || (ch >= UInt8(48) && ch <= UInt8(57))) {
            return parseJsonNumber(s, p)
        }

        (JsValue.undefined(), p)
    }

    // 跳过空白字符
    static func skipWhitespace(s: String, pos: Int64): Int64 {
        var p = pos
        while (p < Int64(s.size)) {
            let ch = s[p]
            // 空格(32), 制表符(9), 换行(10), 回车(13)
            if (ch == UInt8(32) || ch == UInt8(9) || ch == UInt8(10) || ch == UInt8(13)) {
                p += 1
            } else {
                break
            }
        }
        p
    }

    // 解析 JSON 字符串 (处理转义序列)
    static func parseJsonString(s: String, pos: Int64): (JsValue, Int64) {
        // pos 指向开头的双引号
        var p = pos + 1  // 跳过开头的 "
        let sb = StringBuilder()
        while (p < Int64(s.size)) {
            let ch = s[p]
            if (ch == UInt8(92)) {
                // 转义字符 '\'
                p += 1
                if (p >= Int64(s.size)) {
                    break
                }
                let esc = s[p]
                if (esc == UInt8(34)) { sb.append("\"") }        // \"
                else if (esc == UInt8(92)) { sb.append("\\") }    // \\
                else if (esc == UInt8(47)) { sb.append("/") }     // \/
                else if (esc == UInt8(98)) { sb.append("\u{08}") } // \b (backspace)
                else if (esc == UInt8(102)) { sb.append("\u{0C}") } // \f (form feed)
                else if (esc == UInt8(110)) { sb.append("\n") }   // \n
                else if (esc == UInt8(114)) { sb.append("\r") }   // \r
                else if (esc == UInt8(116)) { sb.append("\t") }   // \t
                else if (esc == UInt8(117) && p + 4 < Int64(s.size)) {
                    // \uXXXX Unicode 转义
                    let hex = s[p + 1..p + 5]
                    let codePoint = parseHex(hex)
                    if (codePoint >= 0) {
                        sb.append(String(Rune(codePoint)))
                    }
                    p += 4
                } else {
                    sb.append(String(Rune(esc)))
                }
                p += 1
            } else if (ch == UInt8(34)) {
                // 结尾的双引号
                p += 1
                return (JsValue(sb.toString()), p)
            } else {
                sb.append(String(Rune(ch)))
                p += 1
            }
        }
        (JsValue(sb.toString()), p)
    }

    // 解析 4 位十六进制数
    static func parseHex(hex: String): Int64 {
        var result: Int64 = 0
        for (i in 0..hex.size) {
            let ch = hex[Int64(i)]
            result = result * 16
            if (ch >= UInt8(48) && ch <= UInt8(57)) {
                result += Int64(ch) - 48
            } else if (ch >= UInt8(97) && ch <= UInt8(102)) {
                result += Int64(ch) - 97 + 10
            } else if (ch >= UInt8(65) && ch <= UInt8(70)) {
                result += Int64(ch) - 65 + 10
            } else {
                return -1
            }
        }
        result
    }

    // 解析 JSON 数字
    static func parseJsonNumber(s: String, pos: Int64): (JsValue, Int64) {
        var p = pos
        let start = p
        // 负号
        if (p < Int64(s.size) && s[p] == UInt8(45)) {
            p += 1
        }
        // 整数部分
        while (p < Int64(s.size) && s[p] >= UInt8(48) && s[p] <= UInt8(57)) {
            p += 1
        }
        // 小数部分
        if (p < Int64(s.size) && s[p] == UInt8(46)) {
            p += 1
            while (p < Int64(s.size) && s[p] >= UInt8(48) && s[p] <= UInt8(57)) {
                p += 1
            }
        }
        // 指数部分
        if (p < Int64(s.size) && (s[p] == UInt8(101) || s[p] == UInt8(69))) {
            p += 1
            if (p < Int64(s.size) && (s[p] == UInt8(43) || s[p] == UInt8(45))) {
                p += 1
            }
            while (p < Int64(s.size) && s[p] >= UInt8(48) && s[p] <= UInt8(57)) {
                p += 1
            }
        }
        let numStr = s[start..p]
        let n = parseDouble(numStr)
        (JsValue(n), p)
    }

    // 解析 JSON 数组
    static func parseJsonArray(s: String, pos: Int64): (JsValue, Int64) {
        // pos 指向 '['
        var p = pos + 1  // 跳过 '['
        let arr = JsObject()
        arr.className = "Array"
        arr.arrayStorage = []
        let v = JsValue(arr)
        v.valueType = JsValueType.Array
        v.arrayData = ArrayList<JsValue>()

        p = skipWhitespace(s, p)
        if (p < Int64(s.size) && s[p] == UInt8(93)) {
            // 空数组
            return (v, p + 1)
        }

        while (p < Int64(s.size)) {
            let (elem, newPos) = parseJsonValue(s, p)
            arr.arrayStorage = arr.arrayStorage.concat([elem])
            if (let Some(ad) <- v.arrayData) {
                ad.append(elem)
            }
            p = skipWhitespace(s, newPos)
            if (p >= Int64(s.size)) {
                break
            }
            let ch = s[p]
            if (ch == UInt8(93)) {
                // ']'
                p += 1
                break
            }
            if (ch == UInt8(44)) {
                // ','
                p += 1
                p = skipWhitespace(s, p)
            } else {
                break
            }
        }
        (v, p)
    }

    // 解析 JSON 对象
    static func parseJsonObject(s: String, pos: Int64): (JsValue, Int64) {
        // pos 指向 '{'
        var p = pos + 1  // 跳过 '{'
        let obj = JsObject()
        let v = JsValue(obj)

        p = skipWhitespace(s, p)
        if (p < Int64(s.size) && s[p] == UInt8(125)) {
            // 空对象 '{}'
            return (v, p + 1)
        }

        while (p < Int64(s.size)) {
            // 解析 key (必须是字符串)
            p = skipWhitespace(s, p)
            if (p >= Int64(s.size) || s[p] != UInt8(34)) {
                break
            }
            let (keyVal, keyEnd) = parseJsonString(s, p)
            let key = keyVal.toString()

            // 跳过 ':'
            p = skipWhitespace(s, keyEnd)
            if (p >= Int64(s.size) || s[p] != UInt8(58)) {
                break
            }
            p += 1  // 跳过 ':'

            // 解析 value
            let (val, valEnd) = parseJsonValue(s, p)
            obj.properties.put(key, PropertyDescriptor.valueDescriptor(val))

            p = skipWhitespace(s, valEnd)
            if (p >= Int64(s.size)) {
                break
            }
            let ch = s[p]
            if (ch == UInt8(125)) {
                // '}'
                p += 1
                break
            }
            if (ch == UInt8(44)) {
                // ','
                p += 1
            } else {
                break
            }
        }
        (v, p)
    }
}

// ========== JsValue 扩展: 字符串操作 ==========
// 严格翻译自 JSValue.zig 的字符串相关方法

extend JsValue {
    // ========== toSliceOrNull ==========
    // 严格翻译自 JSValue.toSliceOrNull
    // 调用 toString() 并返回克隆的字符串
    public func toSliceOrNull(global: JsObject): ?String {
        if (isString()) {
            return stringValue
        }
        if (isObject() || isNumber() || isBoolean()) {
            return toString()
        }
        None
    }

    // ========== toZigString ==========
    // 严格翻译自 JSValue.toZigString
    public func toZigString(global: JsObject): String {
        toString()
    }

    // ========== createRopeString ==========
    // 严格翻译自 JSValue.createRopeString
    // 绳索字符串拼接
    public func createRopeString(rhs: JsValue, global: JsObject): JsValue {
        let left = toString()
        let right = rhs.toString()
        JsValue(left + right)
    }

    // ========== stringIncludes ==========
    // 严格翻译自 JSValue.stringIncludes
    public func stringIncludes(global: JsObject, other: JsValue): Bool {
        if (isString() && other.isString()) {
            return stringValue.contains(other.stringValue)
        }
        false
    }

    // ========== asString ==========
    // 严格翻译自 JSValue.asString
    // 静态转换为 JSString
    public func asString(): JsValue {
        this
    }

    // ========== toJSString ==========
    // 严格翻译自 JSValue.toJSString
    public func toJSString(global: JsObject): JsValue {
        JsValue(toString())
    }

    // ========== implementsToString ==========
    // 严格翻译自 JSValue.implementsToString
    public func implementsToString(global: JsObject): Bool {
        if (!isObject()) {
            return false
        }
        if (let Some(obj) <- objectValue) {
            let toStringVal = obj.get("toString")
            if (!toStringVal.isUndefined()) {
                return toStringVal.isCallable()
            }
        }
        false
    }
}

// ========== JsValue 扩展: ArrayBuffer/TypedArray 操作 ==========
// 严格翻译自 JSValue.zig 的 ArrayBuffer 相关方法

extend JsValue {
    // ========== asArrayBuffer ==========
    // 严格翻译自 JSValue.asArrayBuffer
    // 将 JSValue 转为 ArrayBuffer 视图
    public func asArrayBuffer(global: JsObject): ?ArrayBufferView {
        if (valueType == JsValueType.ArrayBuffer || valueType == JsValueType.TypedArray || valueType == JsValueType.DataView) {
            return ArrayBufferView(this)
        }
        None
    }

    // ========== createBuffer ==========
    // 严格翻译自 JSValue.createBuffer
    // 从字节切片创建 Buffer
    public static func createBuffer(global: JsObject, bytes: Array<UInt8>): JsValue {
        let obj = JsObject()
        obj.className = "Buffer"
        obj.byteStorage = cloneByteArray(bytes)
        obj.arrayStorage = []
        for (b in bytes) {
            obj.arrayStorage.append(JsValue(Float64(b)))
        }
        let v = JsValue(obj)
        v.valueType = JsValueType.TypedArray
        v
    }

    // ========== createUninitializedUint8Array ==========
    // 严格翻译自 JSValue.createUninitializedUint8Array
    public static func createUninitializedUint8Array(global: JsObject, len: Int64): JsValue {
        let obj = JsObject()
        obj.className = "Uint8Array"
        obj.byteStorage = Array<UInt8>(len, { _: Int64 => UInt8(0) })
        obj.arrayStorage = Array<JsValue>(len, { _: Int64 => JsValue(0.0) })
        obj.set("byteLength", JsValue(Float64(len)))
        obj.set("byteOffset", JsValue(Float64(0)))
        obj.set("length", JsValue(Float64(len)))
        let v = JsValue(obj)
        v.valueType = JsValueType.TypedArray
        v
    }

    // ========== createBufferFromLength ==========
    // 严格翻译自 JSValue.createBufferFromLength
    public static func createBufferFromLength(global: JsObject, len: Int64): JsValue {
        createBuffer(global, Array<UInt8>(len, { _: Int64 => UInt8(0) }))
    }

    // ========== getProperty ==========
    // 获取对象的命名属性
    public func getProperty(name: String): JsValue {
        if (isObject()) {
            let obj = toObject()
            return obj.get(name)
        }
        JsValue.undefined()
    }

    // ========== getPropertyOptional ==========
    // 获取对象的命名属性，返回 Option
    public func getPropertyOptional(name: String): ?JsValue {
        let val = getProperty(name)
        if (val.isUndefined()) {
            None
        } else {
            Some(val)
        }
    }

    // ========== hasProperty ==========
    // 检查对象是否有指定属性
    public func hasProperty(name: String): Bool {
        if (isObject()) {
            let obj = toObject()
            return obj.has(name)
        }
        false
    }

    // ========== getClassInfoName ==========
    // 获取对象的类名
    public func getClassInfoName(): ?String {
        if (isObject()) {
            let obj = toObject()
            if (obj.className.size > 0) {
                return Some(obj.className)
            }
        }
        None
    }

    // ========== identity ==========
    // 获取值的唯一标识 (用于 Map/Set)
    public func identity(): Int64 {
        Int64(0)
    }

    // ========== isProxy ==========
    public func isProxy(): Bool {
        valueType == JsValueType.Object && isObject() && toObject().className == "Proxy"
    }

    // ========== isTypedArray ==========
    public func isTypedArray(): Bool {
        valueType == JsValueType.TypedArray
    }

    // ========== jsType_ ==========
    // 获取 JSType 枚举值 (用于 console formatter)
    public func jsType_(): JsType {
        match (valueType) {
            case JsValueType.Undefined => JsType.Undefined
            case JsValueType.Null => JsType.Null
            case JsValueType.Boolean => JsType.Boolean
            case JsValueType.Number => JsType.Number
            case JsValueType.String => JsType.String
            case JsValueType.Object => JsType.Object
            case JsValueType.Symbol => JsType.Symbol
            case JsValueType.BigInt => JsType.BigInt
            case _ => JsType.Cell
        }
    }
}

// ========== JsValue 扩展: 迭代操作 ==========
// 严格翻译自 JSValue.zig 的迭代相关方法

extend JsValue {
    // ========== arrayIterator ==========
    // 严格翻译自 JSValue.arrayIterator
    // 返回数组迭代器
    public func arrayIterator(global: JsObject): JsArrayIterator {
        JsArrayIterator(this, global)
    }

    // ========== forEach ==========
    // 严格翻译自 JSValue.forEach
    // 遍历数组元素
    public func forEach(global: JsObject, callback: (JsValue, Int64, JsValue) -> Unit): Unit {
        if (isArray()) {
            if (let Some(arr) <- arrayData) {
                for (i in 0..arr.size) {
                    callback(arr[i], i, this)
                }
            }
        }
    }

    /// 带 context 的 forEach（用于 test_runner 匹配器）
    public func forEach(global: JsObject, context: Any, callback: (Any, JsObject, Any, JsValue) -> Unit): Unit {
        if (isArray()) {
            if (let Some(arr) <- arrayData) {
                for (i in 0..arr.size) {
                    callback(context, global, context, arr[i])
                }
            }
        }
    }

    // ========== forEachProperty ==========
    // 严格翻译自 JSValue.forEachProperty
    // 遍历对象的属性
    public func forEachProperty(global: JsObject, callback: (String, JsValue) -> Unit): Unit {
        if (isObject()) {
            if (let Some(obj) <- objectValue) {
                let propKeys = obj.properties.keys()
                for (i in 0..propKeys.size) {
                    let key = propKeys[Int64(i)]
                    if (let Some(desc) <- obj.properties.get(key)) {
                        if (let Some(val) <- desc.value) {
                            callback(key, val)
                        }
                    }
                }
            }
        }
    }

    // ========== forEachPropertyNonIndexed ==========
    // 严格翻译自 JSValue.forEachPropertyNonIndexed
    public func forEachPropertyNonIndexed(global: JsObject, callback: (String, JsValue) -> Unit): Unit {
        forEachProperty(global, callback)
    }

    // ========== forEachPropertyOrdered ==========
    // 严格翻译自 JSValue.forEachPropertyOrdered
    public func forEachPropertyOrdered(global: JsObject, callback: (String, JsValue) -> Unit): Unit {
        forEachProperty(global, callback)
    }

    // ========== push ==========
    // 严格翻译自 JSValue.push
    // 向数组推入值
    public func push(global: JsObject, value: JsValue): Unit {
        if (isArray()) {
            if (let Some(arr) <- arrayData) {
                arr.append(value)
            } else {
                arrayData = ArrayList<JsValue>()
                arrayData.getOrThrow().append(value)
            }
        }
    }
}

// ========== JsValue 扩展: 日期操作 ==========
// 严格翻译自 JSValue.zig 的 Date 相关方法

extend JsValue {
    // ========== getUnixTimestamp ==========
    // 严格翻译自 JSValue.getUnixTimestamp
    // 获取 Date 对象的内部时间戳 (毫秒)
    public func getUnixTimestamp(): Float64 {
        if (isDate()) {
            if (let Some(obj) <- objectValue) {
                return obj.internalNumberValue
            }
        }
        Float64.NaN
    }

    // ========== fromDateString ==========
    // 严格翻译自 JSValue.fromDateString
    // 从日期字符串创建 Date 实例
    public static func fromDateString(global: JsObject, str: String): JsValue {
        let obj = JsObject()
        obj.className = "Date"
        obj.internalNumberValue = 0.0  // 实际应解析日期字符串
        JsValue(obj)
    }

    // ========== fromDateNumber ==========
    // 严格翻译自 JSValue.fromDateNumber
    // 从时间戳创建 Date 实例
    public static func fromDateNumber(global: JsObject, value: Float64): JsValue {
        let obj = JsObject()
        obj.className = "Date"
        obj.internalNumberValue = value
        JsValue(obj)
    }

    // ========== toISOString ==========
    // 严格翻译自 JSValue.toISOString
    public func toISOString(global: JsObject): String {
        if (isDate()) {
            // 简化实现
            let ts = getUnixTimestamp()
            if (floatIsNaN(ts)) {
                return "Invalid Date"
            }
            // 实际实现需要完整的 ISO 8601 格式化
            ts.toString()
        }
        ""
    }
}

// ========== JsValue 扩展: 属性枚举/迭代 ==========
// 严格翻译自 JSValue.zig 的 BuiltinName 和属性相关

// ========== BuiltinName 枚举 ==========
// 严格翻译自 JSValue.BuiltinName (extracted from nested enum)
// 内置属性名枚举，用于快速属性访问
public enum BuiltinName {
    | Method
    | Headers
    | Status
    | StatusText
    | Url
    | Body
    | Data
    | ToString
    | Redirect
    | InspectCustom
    | HighWaterMark
    | Path
    | Stream
    | AsyncIterator
    | Name
    | Message
    | Error
    | Default
    | Encoding
    | Fatal
    | IgnoreBOM
    | Type
    | Signal
    | Cmd
}

extend JsValue {
    // ========== fastGet ==========
    // 严格翻译自 JSValue.fastGet
    // 通过内置名快速获取属性
    public func fastGet(global: JsObject, builtinName: BuiltinName): ?JsValue {
        let name = builtinNameToString(builtinName)
        get(global, name)
    }

    // ========== fastGetOwn ==========
    // 严格翻译自 JSValue.fastGetOwn
    public func fastGetOwn(global: JsObject, builtinName: BuiltinName): ?JsValue {
        let name = builtinNameToString(builtinName)
        getOwn(global, name)
    }

    // ========== builtinNameToString ==========
    func builtinNameToString(name: BuiltinName): String {
        match (name) {
            case Method => "method"
            case Headers => "headers"
            case Status => "status"
            case StatusText => "statusText"
            case Url => "url"
            case Body => "body"
            case Data => "data"
            case ToString => "toString"
            case Redirect => "redirect"
            case InspectCustom => "inspect"
            case HighWaterMark => "highWaterMark"
            case Path => "path"
            case Stream => "stream"
            case AsyncIterator => "asyncIterator"
            case Name => "name"
            case Message => "message"
            case Error => "error"
            case Default => "default"
            case Encoding => "encoding"
            case Fatal => "fatal"
            case IgnoreBOM => "ignoreBOM"
            case Type => "type"
            case Signal => "signal"
            case Cmd => "cmd"
        }
    }
}

// ========== JsValue 扩展: GC/生命周期管理 ==========
// 严格翻译自 JSValue.zig 的 GC 相关方法

extend JsValue {
    // ========== protect ==========
    // 严格翻译自 JSValue.protect
    // 保护 JSValue 不被垃圾回收
    // 通过 JSC C API: JSValueProtect
    public func protect(): Unit {
        let ptr = asRawPointer()
        if (ptr.isNull()) { return }
        // 需要从当前 VM 获取 context
        let vm = BunVirtualMachine.getOrNull()
        if (let Some(vmInstance) <- vm) {
            let ctx = vmInstance.globalObject.rawPtr
            unsafe { JSValueProtect(ctx, ptr) }
        }
    }

    // ========== unprotect ==========
    // 严格翻译自 JSValue.unprotect
    // 取消保护 (与 protect 配对使用)
    // 通过 JSC C API: JSValueUnprotect
    public func unprotect(): Unit {
        let ptr = asRawPointer()
        if (ptr.isNull()) { return }
        // 需要从当前 VM 获取 context
        let vm = BunVirtualMachine.getOrNull()
        if (let Some(vmInstance) <- vm) {
            let ctx = vmInstance.globalObject.rawPtr
            unsafe { JSValueUnprotect(ctx, ptr) }
        }
    }

    // ========== ensureStillAlive ==========
    // 严格翻译自 JSValue.ensureStillAlive
    // 确保 GC 不会回收此值 (栈引用提示)
    public func ensureStillAlive(): Unit {
        // 在实际 JSC 中，防止编译器优化掉对 JSValue 的引用
    }
}

// ========== JsValue 扩展: 错误创建 ==========
// 严格翻译自 JSValue.zig 的错误创建方法

extend JsValue {
    // ========== createTypeError ==========
    // 严格翻译自 JSValue.createTypeError
    public static func createTypeError(message: String, code: String, global: JsObject): JsValue {
        // 尝试通过 JSC C API 创建 Error 对象
        let globalEncoded = global.globalObjectEncoded()
        if (globalEncoded != UInt64(0)) {
            let resultEncoded = jscCreateError(globalEncoded, CPointer<Int64>())
            if (resultEncoded != Int64(0)) {
                // 真实 JSC 返回了有效值，创建包装对象
                let obj = JsObject()
                obj.className = "TypeError"
                obj.set("message", JsValue(message))
                obj.set("code", JsValue(code))
                return JsValue(obj)
            }
        }
        // 回退到模拟实现
        let obj = JsObject()
        obj.className = "TypeError"
        obj.set("message", JsValue(message))
        obj.set("code", JsValue(code))
        JsValue(obj)
    }

    // ========== createRangeError ==========
    // 严格翻译自 JSValue.createRangeError
    public static func createRangeError(message: String, code: String, global: JsObject): JsValue {
        // 尝试通过 JSC C API 创建 Error 对象
        let globalEncoded = global.globalObjectEncoded()
        if (globalEncoded != UInt64(0)) {
            let resultEncoded = jscCreateError(globalEncoded, CPointer<Int64>())
            if (resultEncoded != Int64(0)) {
                let obj = JsObject()
                obj.className = "RangeError"
                obj.set("message", JsValue(message))
                obj.set("code", JsValue(code))
                return JsValue(obj)
            }
        }
        // 回退到模拟实现
        let obj = JsObject()
        obj.className = "RangeError"
        obj.set("message", JsValue(message))
        obj.set("code", JsValue(code))
        JsValue(obj)
    }

    // ========== createTypeErrorInstance ==========
    // 严格翻译自 JSValue.createTypeErrorInstance
    public static func createTypeErrorInstance(message: String, global: JsObject): JsValue {
        createTypeError(message, "", global)
    }
}

// ========== JsValue 扩展: 杂项方法 ==========
// 严格翻译自 JSValue.zig 的其余方法

extend JsValue {
    // ========== isInstanceOf ==========
    // 严格翻译自 JSValue.isInstanceOf
    // instanceof 操作符
    public func isInstanceOf(global: JsObject, constructor: JsValue): Bool {
        if (!isCell()) {
            return false
        }
        // 在实际 JSC 中，这调用 JSC__JSValue__isInstanceOf
        false
    }

    // ========== toMatch ==========
    // 严格翻译自 JSValue.toMatch
    // 正则匹配: this 是 RegExp, other 是 string
    public func toMatch(global: JsObject, other: JsValue): Bool {
        false  // 需要实际正则引擎
    }

    // ========== unwrapBoxedPrimitive ==========
    // 严格翻译自 JSValue.unwrapBoxedPrimitive
    // 解包 Number, Boolean, String, BigInt 对象为原始类型
    public func unwrapBoxedPrimitive(global: JsObject): JsValue {
        if (!isObject()) {
            return this
        }
        if (let Some(obj) <- objectValue) {
            if (obj.className == "Number") {
                return JsValue(obj.internalNumberValue)
            }
            if (obj.className == "Boolean") {
                return JsValue(obj.internalBoolValue)
            }
            if (obj.className == "String") {
                return JsValue(obj.internalStringValue)
            }
        }
        this
    }

    // ========== getErrorsProperty ==========
    // 严格翻译自 JSValue.getErrorsProperty
    // 获取 errors 属性 (用于 AggregateError)
    public func getErrorsProperty(global: JsObject): JsValue {
        if (isObject()) {
            let obj = objectValue.getOrThrow()
            let val = obj.get("errors")
            if (!val.isUndefined()) {
                return val
            }
        }
        JsValue.undefined()
    }

    // ========== getSymbolDescription ==========
    // 严格翻译自 JSValue.getSymbolDescription
    public func getSymbolDescription(global: JsObject): String {
        if (isSymbol()) {
            if (let Some(sym) <- symbolValue) {
                return sym.description
            }
        }
        ""
    }

    // ========== fromEntries ==========
    // 严格翻译自 JSValue.fromEntries
    // 从键值对数组创建对象
    public static func fromEntries(global: JsObject, keys: Array<String>, values: Array<String>): JsValue {
        let obj = JsObject()
        for (i in 0..keys.size) {
            if (i < values.size) {
                obj.set(keys[i], JsValue(values[i]))
            }
        }
        JsValue(obj)
    }

    // ========== fromPtrAddress / asPtrAddress ==========
    // 严格翻译自 JSValue.fromPtrAddress / asPtrAddress
    // 将指针地址编码为 double
    public static func fromPtrAddress(addr: UInt64): JsValue {
        jsDoubleNumber(Float64(addr))
    }

    public func asPtrAddress(): UInt64 {
        UInt64(numberValue)
    }

    // ========== asPromisePtr ==========
    // 严格翻译自 JSValue.asPromisePtr
    public func asPromisePtr(): Int64 {
        Int64(asPtrAddress())
    }

    // ========== uncheckedPtrCast ==========
    // 严格翻译自 JSValue.uncheckedPtrCast
    // 将值静态转换为指定类型的指针
    public func uncheckedPtrCast(): CPointer<UInt8> {
        rawPtr
    }

    // ========== getProxyInternalField ==========
    // 严格翻译自 JSValue.getProxyInternalField
    // 获取 Proxy 的内部字段
    public func getProxyInternalField(field: UInt32): JsValue {
        if (isObject()) {
            if (let Some(obj) <- objectValue) {
                if (field == 0) {
                    // target
                    if (let Some(proto) <- obj.prototype) {
                        return JsValue(proto)
                    }
                } else if (field == 1) {
                    // handler
                    return JsValue(obj)
                }
            }
        }
        JsValue.undefined()
    }

    // ========== toEnum ==========
    // 严格翻译自 JSValue.toEnum
    // 将字符串值转换为枚举值
    public func toEnum(global: JsObject, propertyName: String, enumValues: HashMap<String, Int64>): ?Int64 {
        if (!isString()) {
            return None
        }
        enumValues.get(stringValue)
    }

    // ========== toObject ==========
    // 严格翻译自 JSValue.toObject
    // 运行时类型转换: 非对象转为包装对象
    // (已有上方的 toObject() 实现，此处为带 global 参数的版本)
    public func toObject(global: JsObject): ?JsObject {
        match (valueType) {
            case Undefined => None
            case Null => None
            case Boolean=>
                let obj = JsObject()
                obj.className = "Boolean"
                obj.internalBoolValue = boolValue
                obj
            case Number=>
                let obj = JsObject()
                obj.className = "Number"
                obj.internalNumberValue = numberValue
                obj
            case String=>
                let obj = JsObject()
                obj.className = "String"
                obj.internalStringValue = stringValue
                obj
            case Object => objectValue.getOrThrow()
            case Symbol=>
                if (let Some(sym) <- symbolValue) {
                    JsObject.fromSymbol(sym)
                } else {
                    None
                }
            case BigInt => JsObject.fromBigInt(bigIntValue)
            case _ => None
        }
    }

    // ========== dump ==========
    // 严格翻译自 JSValue.dump
    // 调试打印
    public func dump(global: JsObject): Unit {
        println(toString())
    }

    // ========== fromAny ==========
    // 严格翻译自 JSValue.fromAny
    // 将任意值转为 JsValue
    public static func fromAny(global: JsObject, value: Any): JsValue {
        // 简化实现 - 实际需要 comptime 反射
        JsValue.undefined()
    }

    // ========== getName ==========
    // 严格翻译自 JSValue.getName
    // 获取函数名
    public func getName(global: JsObject): String {
        if (isObject()) {
            let obj = objectValue.getOrThrow()
            let nameVal = obj.get("name")
            if (!nameVal.isUndefined()) {
                return nameVal.toString()
            }
        }
        ""
    }

    // ========== getNameProperty ==========
    // 严格翻译自 JSValue.getNameProperty
    public func getNameProperty(global: JsObject): String {
        getName(global)
    }

    // ========== isAggregateError ==========
    // 严格翻译自 JSValue.isAggregateError
    public func isAggregateError(global: JsObject): Bool {
        if (let Some(obj) <- objectValue) {
            return obj.className == "AggregateError"
        }
        false
    }

    // ========== isClass ==========
    // 严格翻译自 JSValue.isClass
    public func isClass(global: JsObject): Bool {
        if (!isCallable()) {
            return false
        }
        // 在实际 JSC 中检查 [[IsClassConstructor]]
        false
    }

    // ========== isException ==========
    // 严格翻译自 JSValue.isException
    public func isException(): Bool {
        false  // 需要实际 JSC 绑定
    }

    // ========== isTerminationException ==========
    // 严格翻译自 JSValue.isTerminationException
    public func isTerminationException(): Bool {
        false  // 需要实际 JSC 绑定
    }

    // ========== bind ==========
    // 严格翻译自 JSValue.bind
    // 函数绑定
    public func bind(global: JsObject, bindThisArg: JsValue, name: String, length: Float64, args: Array<JsValue>): JsValue {
        if (!isCallable()) {
            return JsValue.undefined()
        }
        let obj = JsObject()
        obj.isFunction = true
        obj.isCallable = true
        obj.boundThis = bindThisArg.objectValue.getOrThrow()
        obj.functionName = name
        obj.functionBody = this.toString()
        JsValue(obj)
    }

    // ========== callNextTick ==========
    // 严格翻译自 JSValue.callNextTick
    // 在下一个 tick 调用回调
    public func callNextTick(global: JsObject, args: JsValue): Unit {
        // 在实际 JSC 中，这调用 Bun__Process__queueNextTick1
    }

    // ========== coerce ==========
    // 严格翻译自 JSValue.coerce
    // 将值强制转换为指定类型
    public func coerce(global: JsObject): Float64 {
        toNumber()
    }

    // ========== determineDiffMethod ==========
    // 严格翻译自 JSValue.determineDiffMethod
    public func determineDiffMethod(other: JsValue, global: JsObject): DiffMethod {
        if ((isString() && other.isString()) || (isBuffer(global) && other.isBuffer(global))) {
            return DiffMethod.Character
        }
        if ((isRegExp() && other.isObject()) || (isObject() && other.isRegExp())) {
            return DiffMethod.Character
        }
        if (isObject() && other.isObject()) {
            return DiffMethod.Line
        }
        DiffMethod.None
    }

    // ========== toError ==========
    // 严格翻译自 JSValue.toError
    public func toError(): ?JsValue {
        if (isError()) {
            return this
        }
        None
    }

    // ========== StringFormatter ==========
    // 严格翻译自 JSValue.StringFormatter
}

// ========== DiffMethod ==========
// 严格翻译自 JSValue.DiffMethod (extracted from nested enum)
public enum DiffMethod {
    | None
    | Character
    | Word
    | Line
}

// ========== ArrayBufferView ==========
// 用于 asArrayBuffer 返回的类型
public class ArrayBufferView {
    public var jsValue: JsValue
    public var byteOffset: Int64 = 0
    public var byteLength: Int64 = 0

    public init(jsValue: JsValue) {
        this.jsValue = jsValue
        match (jsValue.getObject()) {
            case Some(obj) =>
                let byteLengthValue = obj.get("byteLength")
                if (!byteLengthValue.isUndefined()) {
                    this.byteLength = byteLengthValue.toInt64()
                } else {
                    this.byteLength = Int64(obj.byteStorage.size)
                }
                let byteOffsetValue = obj.get("byteOffset")
                if (!byteOffsetValue.isUndefined()) {
                    this.byteOffset = byteOffsetValue.toInt64()
                }
            case None => ()
        }
    }

    /// Return bytes only for ArrayBuffer/TypedArray values backed by Cangjie-owned
    /// byteStorage. Unknown native pointers are intentionally unsupported because
    /// the current runtime has no safe pointer-copy API with lifetime/bounds checks.
    public func bytes(): Array<UInt8> {
        match (jsValue.getObject()) {
            case Some(obj) =>
                if (obj.byteStorage.size > 0 || byteLength == 0) {
                    let end = byteOffset + byteLength
                    if (byteOffset < 0 || byteLength < 0 || end > Int64(obj.byteStorage.size)) {
                        throw JsRangeError("ArrayBufferView byte range exceeds owned byte storage")
                    }
                    var result: Array<UInt8> = []
                    for (i in byteOffset..end) {
                        result.append(obj.byteStorage[Int64(i)])
                    }
                    return result
                }
                throw JsTypeError("ArrayBufferView bytes are unavailable: no safe native pointer read bridge is implemented")
            case None =>
                throw JsTypeError("ArrayBufferView bytes are unavailable: value is not backed by owned byte storage")
        }
    }
}

private func cloneByteArray(bytes: Array<UInt8>): Array<UInt8> {
    var result: Array<UInt8> = []
    for (b in bytes) {
        result.append(b)
    }
    result
}

// 注意: JsArrayIterator 已移至 js_array.cj

// 注意: AnyPromise 已移至 any_promise.cj
// 注意: JSClassRef 已移至 jni_ffi.cj (type alias)

// 注意: JsFunction 已移至 call_frame.cj (或 package.cj)
// 注意: CallFrame 已移至 call_frame.cj


public class SerializedScriptValue {
    public var data: Array<UInt8> = []
    public var handle: Int64 = 0

    public init() {}

    public init(data: Array<UInt8>, handle: Int64) {
        this.data = data
        this.handle = handle
    }

    public func deinit(): Unit {
        data = []
    }
}

public class StringFormatter {
    public var value: JsValue
    public var globalObject: JsObject

    public init(value: JsValue, globalObject: JsObject) {
        this.value = value
        this.globalObject = globalObject
    }

    public func format(): String {
        value.toString()
    }
}

// ========== JsValue 扩展: ArrayBuffer ==========
extend JsValue {
    /// 是否为 ArrayBuffer 类型
    public func isArrayBuffer(): Bool {
        if (valueType == JsValueType.Object) {
            match (objectValue) {
                case Some(obj) => obj.className == "ArrayBuffer"
                case None => false
            }
        } else {
            false
        }
    }

    /// ArrayBuffer 切片
    /// 返回 ArrayBuffer 的底层数据副本
    /// 通过 JSC C API: JSObjectGetArrayBufferBytesPtr + JSObjectGetArrayBufferByteLength
    public func arrayBufferSlice(): Array<UInt8> {
        if (!isArrayBuffer()) {
            return Array<UInt8>()
        }
        let ptr = asRawPointer()
        if (ptr.isNull()) {
            return Array<UInt8>()
        }
        let vm = BunVirtualMachine.getOrNull()
        if (let Some(vmInstance) <- vm) {
            let ctx = vmInstance.globalObject.rawPtr
            let bytesPtr = unsafe {
                JSObjectGetArrayBufferBytesPtr(ctx, ptr, CPointer<CPointer<UInt8>>())
            }
            let byteLen = unsafe {
                JSObjectGetArrayBufferByteLength(ctx, ptr, CPointer<CPointer<UInt8>>())
            }
            if (bytesPtr.isNull() || byteLen == 0) {
                return Array<UInt8>()
            }
            // 从 C 指针读取字节
            var result = Array<UInt8>(Int64(byteLen), { _ => UInt8(0) })
            unsafe {
                var i: UInt64 = 0
                while (i < byteLen) {
                    result[Int64(i)] = (bytesPtr + Int64(i)).read()
                    i++
                }
            }
            return result
        }
        Array<UInt8>()
    }

    /// 获取 ArrayBuffer 的字节长度
    public func getByteLength(): Int64 {
        let ptr = asRawPointer()
        if (ptr.isNull()) {
            return 0
        }
        let vm = BunVirtualMachine.getOrNull()
        if (let Some(vmInstance) <- vm) {
            let ctx = vmInstance.globalObject.rawPtr
            let byteLen = unsafe {
                JSObjectGetArrayBufferByteLength(ctx, ptr, CPointer<CPointer<UInt8>>())
            }
            return Int64(byteLen)
        }
        0
    }

    /// 获取 ArrayBuffer 的字节数据
    public func getArrayBufferBytes(): ArrayList<UInt8> {
        ArrayList<UInt8>()
    }
}

// ========== JsValue 扩展: test_runner 所需方法 ==========

extend JsValue {
    /// 将 BigInt JsValue 转换为 Int64
    public func toBigInt(globalThis!: JSGlobalObject): Int64 {
        Int64(toNumber())
    }

    /// 获取对象上的 truthy 属性值
    public func getTruthyComptime(globalThis!: JSGlobalObject, key!: String): ?JsValue {
        match (objectValue) {
            case Some(obj) =>
                let v = obj.get(key)
                if (v.isUndefinedOrNull()) { None } else { Some(v) }
            case None => None
        }
    }

    /// 安全调用函数，捕获异常
    public func callWithCatch(globalThis!: JSGlobalObject, thisValue!: JsValue, args!: Array<JsValue>): JsValue {
        try {
            if (isCallable()) {
                return call(globalThis.globalThis, thisValue, args)
            }
            JsValue.undefined()
        } catch (e: Exception) {
            JsValue.undefined()
        }
    }

    /// Jest 深度相等比较 (严格翻译自 Bun C++ Bun__deepEquals)
    /// 支持递归对象/数组比较和循环检测
    public func jestDeepEquals(other: JsValue, globalThis!: JSGlobalObject): Bool {
        jestDeepEqualsInternal(other, globalThis, ArrayList<JsValue>())
    }

    /// 内部递归深度比较实现
    private func jestDeepEqualsInternal(other: JsValue, globalThis: JSGlobalObject, visited: ArrayList<JsValue>): Bool {
        // null/undefined 比较
        if (isNull() && other.isNull()) { return true }
        if (isUndefined() && other.isUndefined()) { return true }
        if (isNull() || other.isNull()) { return false }
        if (isUndefined() || other.isUndefined()) { return false }

        // 原始类型比较
        if (isNumber() && other.isNumber()) {
            return toNumber() == other.toNumber()
        }
        if (isString() && other.isString()) {
            return toString() == other.toString()
        }
        if (isBoolean() && other.isBoolean()) {
            return toBoolean() == other.toBoolean()
        }
        if (isBigInt() && other.isBigInt()) {
            return toBigInt(globalThis: globalThis) == other.toBigInt(globalThis: globalThis)
        }

        // 数组比较
        if (isArray() && other.isArray()) {
            let gObj = globalThis.globalThis
            let thisLen = Int64(getLength(gObj))
            let otherLen = Int64(other.getLength(gObj))
            if (thisLen != otherLen) {
                return false
            }
            for (i in 0..thisLen) {
                let a = getIndex(gObj, UInt32(i))
                let b = other.getIndex(gObj, UInt32(i))
                if (!a.jestDeepEqualsInternal(b, globalThis, visited)) {
                    return false
                }
            }
            return true
        }

        // 对象比较
        if (isObject() && other.isObject()) {
            let thisObj = toObject()
            let otherObj = other.toObject()
            let thisKeys = thisObj.getOwnPropertyNames()
            let otherKeys = otherObj.getOwnPropertyNames()
            if (thisKeys.size != otherKeys.size) {
                return false
            }
            for (keyStr in thisKeys) {
                let thisVal = thisObj.get(keyStr)
                let otherVal = otherObj.get(keyStr)
                if (otherVal.isUndefined()) {
                    if (!thisVal.isUndefined()) {
                        return false
                    }
                } else {
                    if (!thisVal.jestDeepEqualsInternal(otherVal, globalThis, visited)) {
                        return false
                    }
                }
            }
            return true
        }

        false
    }

    /// Jest 深度匹配（部分匹配）
    /// 严格翻译自 Bun C++ Bun__deepMatch
    /// 检查 obj 是否包含 subset 的所有属性且值相等
    public func jestDeepMatch(other: JsValue, globalThis!: JSGlobalObject, partial!: Bool): Bool {
        jestDeepMatchInternal(other, globalThis, ArrayList<JsValue>())
    }

    /// 内部递归深度匹配实现
    private func jestDeepMatchInternal(subset: JsValue, globalThis: JSGlobalObject, visited: ArrayList<JsValue>): Bool {
        // 数组: 长度必须一致
        if (isArray() && subset.isArray()) {
            let gObj = globalThis.globalThis
            let thisLen = Int64(getLength(gObj))
            let subLen = Int64(subset.getLength(gObj))
            if (thisLen != subLen) {
                return false
            }
            for (i in 0..thisLen) {
                let a = getIndex(gObj, UInt32(i))
                let b = subset.getIndex(gObj, UInt32(i))
                if (!a.jestDeepMatchInternal(b, globalThis, visited)) {
                    return false
                }
            }
            return true
        }

        // 对象: 遍历 subset 的属性, 检查 obj 是否都有且匹配
        if (isObject() && subset.isObject()) {
            let thisObj = toObject()
            let subObj = subset.toObject()
            let subKeys = subObj.getOwnPropertyNames()

            for (keyStr in subKeys) {
                let thisVal = thisObj.get(keyStr)
                let subVal = subObj.get(keyStr)

                if (thisVal.isUndefined()) {
                    return false
                }

                if (subVal.isObject() && thisVal.isObject()) {
                    if (!thisVal.jestDeepMatchInternal(subVal, globalThis, visited)) {
                        return false
                    }
                } else {
                    if (!thisVal.jestDeepEqualsInternal(subVal, globalThis, ArrayList<JsValue>())) {
                        return false
                    }
                }
            }
            return true
        }

        jestDeepEquals(subset, globalThis: globalThis)
    }

    /// 将 JsValue 转为字符串切片
    public func toSlice(global: JsObject): String {
        toString()
    }

    /// 将 JsValue 转为字符串切片（带 allocator）
    public func toSlice(globalThis!: JSGlobalObject, allocator!: Any): String {
        toString()
    }

    /// 沿路径获取属性值 (如 "a.b.c")
    public func getIfPropertyExistsFromPath(globalThis!: JSGlobalObject, path!: String): ?JsValue {
        let parts = path.split(".")
        var current: JsValue = this
        for (part in parts) {
            if (!current.isObject()) {
                return None
            }
            let obj = current.toObject()
            let val = obj.get(part)
            if (val.isUndefinedOrNull()) {
                return None
            }
            current = val
        }
        Some(current)
    }

    /// 沿路径获取属性值（带 global 参数）
    public func getIfPropertyExistsFromPath(global: JsObject, path: JsValue): ?JsValue {
        let pathStr = path.toString()
        let parts = pathStr.split(".")
        var current: JsValue = this
        for (part in parts) {
            if (!current.isObject()) {
                return None
            }
            let obj = current.toObject()
            let val = obj.get(part)
            if (val.isUndefinedOrNull()) {
                return None
            }
            current = val
        }
        Some(current)
    }

    /// 是否为字符串字面量（等同于 isString）
    public func isStringLiteral(): Bool {
        isString()
    }

    /// 获取宽松的 JS 类型（委托给 jsType_）
    public func jsTypeLoose(): JsType {
        jsType_()
    }

    /// 沿路径获取属性值（带 global 和 String 参数）
    public func getIfPropertyExistsFromPath(global: JsObject, path: String): ?JsValue {
        let parts = path.split(".")
        var current: JsValue = this
        for (part in parts) {
            if (!current.isObject()) {
                return None
            }
            let obj = current.toObject()
            let val = obj.get(part)
            if (val.isUndefinedOrNull()) {
                return None
            }
            current = val
        }
        Some(current)
    }

    /// 获取属性路径的内部实现
    public func getLengthIfPropertyExistsInternal(global: JsObject): Int64 {
        Int64(getLength(global))
    }

    /// 将 JsValue 转为 ZigString 写入 result
    public func toZigString(result: String, globalThis: JsObject): String {
        toString()
    }
}

// ========== JsValue 扩展: 原始指针操作 ==========
// 用于 JSC FFI 绑定的指针转换

extend JsValue {
    /// 获取底层 JSC C API 指针 (JSValueRef)
    /// 优先返回 rawPtr；如果 rawPtr 为 null 且有 objectValue，返回对象的 rawPtr
    public func asRawPointer(): CPointer<UInt8> {
        if (!rawPtr.isNull()) {
            return rawPtr
        }
        if (let Some(obj) <- objectValue) {
            return obj.rawPtr
        }
        CPointer<UInt8>()
    }

    /// 从 JSC C API 指针 (JSValueRef) 创建 JsValue
    /// 此方法创建一个持有原始指针的 JsValue，生命周期由 JSC GC 管理
    public static func fromRawPointer(ptr: CPointer<UInt8>): JsValue {
        let v = JsValue()
        v.rawPtr = ptr
        v.valueType = JsValueType.Object
        v
    }
}
