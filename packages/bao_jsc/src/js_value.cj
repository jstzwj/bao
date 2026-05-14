// 严格翻译自: src/jsc/JSValue.zig
// JavaScriptCore JsValue 类型系统

package bao_jsc

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
}

// JS 值包装 - 严格翻译自 JSValue.zig
public class JsValue {
    var valueType: JsValueType = JsValueType.Undefined
    var boolValue: Bool = false
    var numberValue: Float64 = 0.0
    var stringValue: String = ""
    var objectValue: ?JsObject = None
    var symbolValue: ?JsSymbol = None
    var bigIntValue: String = ""  // BigInt as string representation
    var rawPtr: CPointer<UInt8> = CPointer<UInt8>()  // JSC C API pointer

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

    public init(sym: JsSymbol) {
        this.valueType = JsValueType.Symbol
        this.symbolValue = sym
    }

    // Undefined 单例
    public static func undefined() -> JsValue {
        let v = JsValue()
        return v
    }

    // Null 单例
    public static func null() -> JsValue {
        let v = JsValue()
        v.valueType = JsValueType.Null
        return v
    }

    // 类型检查方法 - 严格翻译自 JSValue.zig isXxx 方法
    public func isUndefined() -> Bool {
        valueType == JsValueType.Undefined
    }

    public func isNull() -> Bool {
        valueType == JsValueType.Null
    }

    public func isBoolean() -> Bool {
        valueType == JsValueType.Boolean
    }

    public func isNumber() -> Bool {
        valueType == JsValueType.Number
    }

    public func isString() -> Bool {
        valueType == JsValueType.String
    }

    public func isObject() -> Bool {
        valueType == JsValueType.Object
    }

    public func isSymbol() -> Bool {
        valueType == JsValueType.Symbol
    }

    public func isBigInt() -> Bool {
        valueType == JsValueType.BigInt
    }

    public func isPrimitive() -> Bool {
        !isObject()
    }

    public func isNullOrUndefined() -> Bool {
        isNull() || isUndefined()
    }

    public func isCallable() -> Bool {
        if (isbject()) {
            let obj = objectValue.getOrThrow()
            return obj.isFunction
        }
        return false
    }

    // 类型转换 - 严格翻译自 JSValue.zig toXxx 方法
    // ToBoolean - JS ToBoolean 抽象操作
    public func toBoolean() -> Bool {
        match (valueType) {
            case Undefined => false
            case Null => false
            case Boolean => boolValue
            case Number => numberValue != 0.0 && !isNaN(numberValue)
            case String => stringValue.size > 0
            case Object => true
            case Symbol => true
            case BigInt => bigIntValue != "0"
        }
    }

    // ToNumber - JS ToNumber 抽象操作
    public func toNumber() -> Float64 {
        match (valueType) {
            case Undefined => Float64.NaN
            case Null => 0.0
            case Boolean => boolValue ? 1.0 : 0.0
            case Number => numberValue
            case String => stringToNumber(stringValue)
            case Object => {
                // 先调用 valueOf，再 toPrimitive -> toNumber
                if (let Some(obj) <- objectValue) {
                    let prim = obj.toPrimitive(JsValueType.Number)
                    return prim.toNumber()
                }
                Float64.NaN
            }
            case Symbol => Float64.NaN
            case BigInt => {
                let n = Float64.parseDouble(bigIntValue)
                match (n) {
                    case Some(v) => v
                    case None => Float64.NaN
                }
            }
        }
    }

    // ToString - JS ToString 抽象操作
    public func toString() -> String {
        match (valueType) {
            case Undefined => "undefined"
            case Null => "null"
            case Boolean => boolValue ? "true" : "false"
            case Number => numberToString(numberValue)
            case String => stringValue
            case Object => {
                if (let Some(obj) <- objectValue) {
                    let prim = obj.toPrimitive(JsValueType.String)
                    return prim.toString()
                }
                "[object Object]"
            }
            case Symbol => {
                if (let Some(sym) <- symbolValue) {
                    "Symbol(" + sym.description + ")"
                } else {
                    "Symbol()"
                }
            }
            case BigInt => bigIntValue + "n"
        }
    }

    // ToObject - JS ToObject 抽象操作
    public func toObject() -> JsObject {
        match (valueType) {
            case Undefined => throw JsTypeError("Cannot convert undefined to object")
            case Null => throw JsTypeError("Cannot convert null to object")
            case Boolean => JsObject.fromBoolean(boolValue)
            case Number => JsObject.fromNumber(numberValue)
            case String => JsObject.fromString(stringValue)
            case Object => objectValue.getOrThrow()
            case Symbol => JsObject.fromSymbol(symbolValue.getOrThrow())
            case BigInt => JsObject.fromBigInt(bigIntValue)
        }
    }

    // ToInteger - JS ToIntegerOrInfinity 抽象操作
    public func toInteger() -> Int64 {
        if (isNull() || isUndefined()) {
            return 0
        }
        let n = toNumber()
        if (isNaN(n)) {
            return 0
        }
        if (n == 0.0 || isNaN(n)) {
            return 0
        }
        Int64(n >= 0 ? Math.floor(n) : Math.ceil(n))
    }

    // ToLength - JS ToLength 抽象操作
    public func toLength() -> UInt64 {
        let len = toInteger()
        if (len < 0) {
            return 0
        }
        UInt64(len)
    }

    // JSValue 比较
    // Strict Equality (===)
    public static func strictEqual(a: JsValue, b: JsValue) -> Bool {
        if (a.valueType != b.valueType) {
            // NaN === NaN is true in JS
            if (a.isNumber() && b.isNumber()) {
                return isNaN(a.numberValue) && isNaN(b.numberValue)
            }
            return false
        }
        match (a.valueType) {
            case Undefined => true
            case Null => true
            case Boolean => a.boolValue == b.boolValue
            case Number => a.numberValue == b.numberValue
            case String => a.stringValue == b.stringValue
            case Object => {
                // Object identity comparison
                a.objectValue === b.objectValue
            }
            case Symbol => {
                if (let Some(sa) <- a.symbolValue) {
                    if (let Some(sb) <- b.symbolValue) {
                        return sa.id == sb.id
                    }
                }
                false
            }
            case BigInt => a.bigIntValue == b.bigIntValue
        }
    }

    // Abstract Equality (==) - JS Abstract Equality Comparison
    public static func abstractEqual(a: JsValue, b: JsValue) -> Bool {
        // Same type -> strict equal
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
            return abstractEqual(JsValue(n: a.toNumber()), b)
        }
        if (b.isBoolean()) {
            return abstractEqual(a, JsValue(n: b.toNumber()))
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
    public func toPrimitive(preferredType: JsValueType) -> JsValue {
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
    public func toJsonString() -> String {
        match (valueType) {
            case Undefined => "undefined"
            case Null => "null"
            case Boolean => boolValue ? "true" : "false"
            case Number => numberToString(numberValue)
            case String => "\"" + escapeJsonString(stringValue) + "\""
            case Object => {
                if (let Some(obj) <- objectValue) {
                    return obj.toJsonString()
                }
                "null"
            }
            case Symbol => "undefined"
            case BigInt => throw JsTypeError("BigInt value cannot be serialized in JSON")
        }
    }

    // 工具方法
    func stringToNumber(s: String) -> Float64 {
        let trimmed = s.trim()
        if (trimmed.isEmpty) {
            return 0.0
        }
        if (trimmed == "Infinity" || trimmed == "+Infinity") {
            return Float64.PositiveInfinity
        }
        if (trimmed == "-Infinity") {
            return Float64.NegativeInfinity
        }
        if (trimmed == "NaN") {
            return Float64.NaN
        }
        // hex 0x
        if (trimmed.size > 2 && trimmed[0] == '0' && (trimmed[1] == 'x' || trimmed[1] == 'X')) {
            return Float64(Int64.parseInt(trimmed, 16).getOrThrow())
        }
        // octal 0o
        if (trimmed.size > 2 && trimmed[0] == '0' && (trimmed[1] == 'o' || trimmed[1] == 'O')) {
            return Float64(Int64.parseInt(trimmed, 8).getOrThrow())
        }
        // binary 0b
        if (trimmed.size > 2 && trimmed[0] == '0' && (trimmed[1] == 'b' || trimmed[1] == 'B')) {
            return Float64(Int64.parseInt(trimmed, 2).getOrThrow())
        }
        Float64.parseDouble(trimmed).getOr(0.0)
    }

    func numberToString(n: Float64) -> String {
        if (isNaN(n)) {
            return "NaN"
        }
        if (n == Float64.PositiveInfinity) {
            return "Infinity"
        }
        if (n == Float64.NegativeInfinity) {
            return "-Infinity"
        }
        if (n == 0.0) {
            return "0"
        }
        String(n)
    }

    func escapeJsonString(s: String) -> String {
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
                case _ => {
                    if (c.code < 0x20) {
                        result.append("\\u" + String.format("%04x", c.code))
                    } else {
                        result.append(c)
                    }
                }
            }
        }
        result.toString()
    }

    func isNaN(n: Float64) -> Bool {
        n != n
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
    public static let iterator = JsSymbol(id: 0, description: "Symbol.iterator", isWellKnown: true)
    public static let asyncIterator = JsSymbol(id: 1, description: "Symbol.asyncIterator", isWellKnown: true)
    public static let match = JsSymbol(id: 2, description: "Symbol.match", isWellKnown: true)
    public static let matchAll = JsSymbol(id: 3, description: "Symbol.matchAll", isWellKnown: true)
    public static let replace = JsSymbol(id: 4, description: "Symbol.replace", isWellKnown: true)
    public static let search = JsSymbol(id: 5, description: "Symbol.search", isWellKnown: true)
    public static let split = JsSymbol(id: 6, description: "Symbol.split", isWellKnown: true)
    public static let hasInstance = JsSymbol(id: 7, description: "Symbol.hasInstance", isWellKnown: true)
    public static let isConcatSpreadable = JsSymbol(id: 8, description: "Symbol.isConcatSpreadable", isWellKnown: true)
    public static let unscopables = JsSymbol(id: 9, description: "Symbol.unscopables", isWellKnown: true)
    public static let species = JsSymbol(id: 10, description: "Symbol.species", isWellKnown: true)
    public static let toPrimitive = JsSymbol(id: 11, description: "Symbol.toPrimitive", isWellKnown: true)
    public static let toStringTag = JsSymbol(id: 12, description: "Symbol.toStringTag", isWellKnown: true)

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
    public static func forKey(key: String) -> JsSymbol {
        if (let Some(sym) <- registry.get(key)) {
            return sym
        }
        let sym = JsSymbol(description: key)
        registry.put(key, sym)
        return sym
    }

    // Symbol.keyFor(sym) - 查找全局注册的 key
    public static func keyFor(sym: JsSymbol) -> ?String {
        for ((k, v) in registry) {
            if (v.id == sym.id) {
                return k
            }
        }
        return None
    }

    public func toString() -> String {
        if (description.isEmpty) {
            "Symbol()"
        } else {
            "Symbol(" + description + ")"
        }
    }
}

// JS 错误类型
public class JsError <: Exception {
    public let name: String
    public let message: String
    public let stackTrace: String

    public init(message: String) {
        this.name = "Error"
        this.message = message
        this.stackTrace = ""
    }

    public init(name: String, message: String) {
        this.name = name
        this.message = message
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
