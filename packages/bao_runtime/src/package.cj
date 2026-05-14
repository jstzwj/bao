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
    public static let NULL = JsValue(JsValueType.Null)
    public static let TRUE = JsValue(true)
    public static let FALSE = JsValue(false)
    public static let nan = JsValue(Float64.nan)

    public init(type: JsValueType) {
        valueType = type
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
            case JsValueType.Undefined => Float64.nan
            case JsValueType.Null => 0.0
            case JsValueType.Boolean => if (boolValue) { 1.0 } else { 0.0 }
            case JsValueType.Number => numberValue
            case JsValueType.String => parseNumber(stringValue.toString())
            case _ => Float64.nan
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
            case JsValueType.Array => {
                match (arrayData) {
                    case Some(arr) => {
                        let sb = StringBuilder()
                        for (i in 0..arr.size) {
                            if (i > 0) { sb.append(",") }
                            sb.append(arr[i].toString())
                        }
                        sb.toString()
                    }
                    case None => ""
                }
            }
            case JsValueType.Function => {
                match (functionData) {
                    case Some(fn) => "function ${fn.name}() { [bao code] }"
                    case None => "function() { [native code] }"
                }
            }
            case _ => valueType.toString()
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
        try {
            return Float64.parse(s)
        } catch (_: Exception) {
            return Float64.nan
        }
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
            case None => {
                match (proto) {
                    case Some(p) => p.get(key)
                    case None => JsValue.UNDEFINED
                }
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
        return properties.remove(key) != None
    }

    /// 获取所有键
    public func keys(): ArrayList<String> {
        return ArrayList<String>(properties.keys())
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
            throw BaoError(errorMsg.toString())
        }

        // 使用 Interpreter 执行 AST
        return interpreter.eval(result.program)
    }

    /// 执行文件
    public func executeFile(path: String): JsValue {
        let source = BaoFile.readAllText(path)
        return eval(source, path)
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
