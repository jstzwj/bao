// bao_runtime - JavaScript 运行时
// 对应 Bun: src/runtime/, src/jsc/
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_path.*
import bao_threading.*

// ============================================================================
// JavaScript 错误码
// 对应 Bun: src/jsc/JSErrorCode.zig
// ============================================================================

/// JS 错误类型
public enum JsErrorCode {
    | Error
    | EvalError
    | RangeError
    | ReferenceError
    | SyntaxError
    | TypeError
    | URIError
    | AggregateError
    | OutOfMemoryError
    | BundlerError
    | StackOverflow
    | UserErrorCode
}

// ============================================================================
// JS 值类型
// 对应 Bun: src/j.zig - JSValue
// ============================================================================

/// JavaScript 值类型
public enum JsValueType {
    | Undefined
    | Null
    | Boolean
    | Number
    | String
    | Symbol
    | BigInt
    | Object
    | Array
    | Function
    | Date
    | RegExp
    | Map
    | Set
    | Promise
    | ArrayBuffer
    | TypedArray
    | DataView
    | Error

    public operator func ==(right: JsValueType): Bool {
        return false
    }

    public operator func !=(right: JsValueType): Bool {
        return !(this == right)
    }
}

/// JavaScript 值表示
/// 对应 Bun: src/jsc/JSValue.zig
public class JsValue {
    public let valueType: JsValueType
    public var boolValue: Bool
    public var numberValue: Float64
    public var stringValue: BaoString
    public var objectData: ?JsObject
    public var arrayData: ?ArrayList<JsValue>
    public var functionData: ?JsFunction
    public var nativeFnData: ?JsNativeFunction

    public static let UNDEFINED = JsValue(JsValueType.Undefined)

    public static func jsUndefined(): JsValue {
        return JsValue.UNDEFINED
    }
    public static let NULL = JsValue(JsValueType.Null)
    public static let TRUE = JsValue(true)
    public static let FALSE = JsValue(false)
    public static let nan = JsValue(Float64.NaN)

    public init(valueType_: JsValueType) {
        valueType = valueType_
        boolValue = false
        numberValue = 0.0
        stringValue = BaoString("")
        objectData = None
        arrayData = None
        functionData = None
        nativeFnData = None
    }

    public init(value: Bool) {
        valueType = JsValueType.Boolean
        boolValue = value
        numberValue = 0.0
        stringValue = BaoString("")
        objectData = None
        arrayData = None
        functionData = None
        nativeFnData = None
    }

    public init(value: Float64) {
        valueType = JsValueType.Number
        numberValue = value
        boolValue = false
        stringValue = BaoString("")
        objectData = None
        arrayData = None
        functionData = None
        nativeFnData = None
    }

    public init(value: BaoString) {
        valueType = JsValueType.String
        stringValue = value
        boolValue = false
        numberValue = 0.0
        objectData = None
        arrayData = None
        functionData = None
        nativeFnData = None
    }

    public init(value: JsObject) {
        valueType = JsValueType.Object
        objectData = Some(value)
        boolValue = false
        numberValue = 0.0
        stringValue = BaoString("")
        arrayData = None
        functionData = None
        nativeFnData = None
    }

    /// 创建数组 JsValue
    public static func array(data: ArrayList<JsValue>): JsValue {
        let v = JsValue(JsValueType.Array)
        v.arrayData = Some(data)
        return v
    }

    /// 创建函数 JsValue
    public static func function(fn: JsFunction): JsValue {
        let v = JsValue(JsValueType.Function)
        v.functionData = Some(fn)
        return v
    }

    /// 创建原生函数 JsValue
    public static func nativeFunction(fn: JsNativeFunction): JsValue {
        let v = JsValue(JsValueType.Function)
        v.nativeFnData = Some(fn)
        return v
    }

    /// 转为布尔值
    public func toBoolean(): Bool {
        match (valueType) {
            case JsValueType.Undefined | JsValueType.Null => false
            case JsValueType.Boolean => boolValue
            case JsValueType.Number => numberValue != 0.0 && !numberValue.isNaN()
            case JsValueType.String => !stringValue.isEmpty()
            case _ => true
        }
    }

    /// 转为数值
    public func toNumber(): Float64 {
        match (valueType) {
            case JsValueType.Undefined => Float64.NaN
            case JsValueType.Null => 0.0
            case JsValueType.Boolean => if (boolValue) { 1.0 } else { 0.0 }
            case JsValueType.Number => numberValue
            case JsValueType.String => parseNumber(stringValue.toString())
            case _ => Float64.NaN
        }
    }

    /// 转为字符串
    public func toString(): String {
        match (valueType) {
            case JsValueType.Undefined => "undefined"
            case JsValueType.Null => "null"
            case JsValueType.Boolean => if (boolValue) { "true" } else { "false" }
            case JsValueType.Number => numberValue.toString()
            case JsValueType.String => stringValue.toString()
            case JsValueType.Object => "[object Object]"
            case JsValueType.Array => arrayToString()
            case JsValueType.Function => functionToString()
            case _ => "object"
        }
    }

    private func arrayToString(): String {
        match (arrayData) {
            case Some(arr) =>
                let sb = StringBuilder()
                for (i in 0..arr.size) {
                    if (i > 0) { sb.append(",") }
                    sb.append(arr[i].toString())
                }
                sb.toString()
            case None => ""
        }
    }

    private func functionToString(): String {
        match (functionData) {
            case Some(fn) => "function ${fn.name}() { [bao code] }"
            case None => "function() { [native code] }"
        }
    }

    /// 获取类型字符串
    public func typeOf(): String {
        match (valueType) {
            case JsValueType.Undefined => "undefined"
            case JsValueType.Null => "object"  // JS typeof null === "object"
            case JsValueType.Boolean => "boolean"
            case JsValueType.Number => "number"
            case JsValueType.String => "string"
            case JsValueType.Symbol => "symbol"
            case JsValueType.BigInt => "bigint"
            case JsValueType.Function => "function"
            case _ => "object"
        }
    }

    private func parseNumber(s: String): Float64 {
        return 0.0
    }
}

/// JavaScript 对象
public class JsObject {
    private var properties: HashMap<String, JsValue>
    private var proto: ?JsObject

    public init() {
        properties = HashMap<String, JsValue>()
        proto = None
    }

    /// 获取属性
    public func get(key: String): JsValue {
        match (properties.get(key)) {
            case Some(v) => v
            case None =>
                match (proto) {
                    case Some(p) => p.get(key)
                    case None => JsValue.UNDEFINED
                }
        }
    }

    /// 设置属性
    public func set(key: String, value: JsValue): Unit {
        properties.put(key, value)
    }

    /// 判断是否有属性
    public func has(key: String): Bool {
        return properties.contains(key)
    }

    /// 删除属性
    public func delete(key: String): Bool {
        match (properties.remove(key)) {
            case Some(_) => return true
            case None => return false
        }
    }

    /// 获取所有键
    public func keys(): ArrayList<String> {
        return properties.keys()
    }
}

// ============================================================================
// 解析与事件循环占位
// ============================================================================

public class EventLoop {
    public init() {}

    public func enter(): Unit {
        ()
    }

    public func exit(): Unit {
        ()
    }

    public func runCallback(callback: JsValue, globalThis: JsObject, thisValue: JsValue, args: ArrayList<JsValue>): Unit {
        ()
    }
}

public class ParseResultError {
    public var message: String
    public var loc: SourceLoc

    public init(message: String) {
        this.message = message
        this.loc = SourceLoc()
    }
}

public class ParseResult {
    public var program: ArrayList<Stmt>
    public var errors: ArrayList<ParseResultError>

    public init() {
        program = ArrayList<Stmt>()
        errors = ArrayList<ParseResultError>()
    }

    public func hasErrors(): Bool {
        return errors.size > 0
    }
}

public class JsParser {
    public init() {}

    public func parse(source: String, options: ParserOptions): ParseResult {
        return ParseResult()
    }
}

// ============================================================================
// 虚拟机
// 对应 Bun: src/jsc/VirtualMachine.zig
// ============================================================================

/// JavaScript 虚拟机
/// 对应 Bun: src/jsc/VirtualMachine.zig
public class VirtualMachine {
    private var eventLoop: EventLoop
    private var globalObject: JsObject
    private var interpreter: Interpreter
    private var parser: JsParser
    private var running: Bool

    public init() {
        eventLoop = EventLoop()
        globalObject = JsObject()
        interpreter = Interpreter()
        parser = JsParser()
        running = false
    }

    public static func get(): VirtualMachine {
        return VirtualMachine()
    }

    /// 执行 JavaScript 源代码
    public func eval(source: String, filename: String): JsValue {
        let options = ParserOptions()
        options.sourceFile = filename
        let result = parser.parse(source, options)

        if (result.hasErrors()) {
            var errorMsg = StringBuilder()
            for (err in result.errors) {
                errorMsg.append("${filename}:${err.loc.line}:${err.loc.column}: ${err.message}\n")
            }
            return JsValue.UNDEFINED
        }

        // 使用 Interpreter 执行 AST
        return interpreter.eval(result.program)
    }

    /// 执行文件
    public func executeFile(path: String): JsValue {
        return eval("", path)
    }

    /// 获取全局对象
    public func getGlobal(): JsObject {
        return globalObject
    }

    /// 获取事件循环
    public func getEventLoop(): EventLoop {
        return eventLoop
    }

    /// 获取解释器
    public func getInterpreter(): Interpreter {
        return interpreter
    }

    /// 获取解释器的全局环境
    public func getGlobalEnv(): Environment {
        return interpreter.getGlobalEnv()
    }
}
