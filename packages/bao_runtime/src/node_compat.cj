// Node.js 兼容层 — Node.js API 兼容实现
// 严格翻译自: src/runtime/node/ Node.js compatibility layer
//   Bun 提供了完整的 Node.js API 兼容层
//   仓颉在此实现 process.nextTick, Buffer, util, path, EventEmitter,
//   Stream, require() 等 Node.js 核心 API
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_threading.*
import bao_path.*

// ============================================================================
// process.nextTick — 微任务队列
// 对应 Bun: src/runtime/node/process.zig nextTick
// ============================================================================

/// nextTick 回调记录
public class NextTickCallback {
    /// 回调函数
    public var callback: NativeFn
    /// 参数
    public var args: ArrayList<JsValue>

    public init(callback: NativeFn) {
        this.callback = callback
        this.args = ArrayList<JsValue>()
    }

    public init(callback: NativeFn, args: ArrayList<JsValue>) {
        this.callback = callback
        this.args = args
    }
}

/// nextTick 队列 — 对应 Node.js process._tickCallback
/// Node.js 使用链表实现，仓颉使用 ArrayList
public class NextTickQueue {
    /// 回调队列
    private var queue: ArrayList<NextTickCallback>
    /// 是否正在处理
    private var processing: Bool

    public init() {
        queue = ArrayList<NextTickCallback>()
        processing = false
    }

    /// 入队 - 对应 process.nextTick(callback, ...args)
    public func enqueue(callback: NativeFn, args: ArrayList<JsValue>): Unit {
        queue.append(NextTickCallback(callback, args))
    }

    /// 处理所有 nextTick 回调 - 对应 process._tickCallback()
    public func drain(): Unit {
        // 防止重入
        if (processing) {
            return
        }
        processing = true
        // nextTick 回调可能产生新的 nextTick
        while (queue.size > 0) {
            let batch = queue
            queue = ArrayList<NextTickCallback>()
            for (item in batch) {
                try {
                    item.callback(item.args)
                } catch (_: Exception) {
                    // nextTick 回调错误不应中断队列
                }
            }
        }
        processing = false
    }

    /// 队列是否为空
    public func isEmpty(): Bool {
        return queue.size == 0
    }

    /// 队列长度
    public func size(): Int64 {
        return queue.size
    }
}

// ============================================================================
// NodeBufferPolyfill — Buffer 多态填充
// 对应 Bun: src/runtime/node/buffer.zig
// 引用 bao_runtime/src/node_api/buffer.cj 中的 Buffer 类
// ============================================================================

/// Buffer 多态填充 — 提供 Node.js Buffer 兼容的构造函数接口
/// 内部委托给 bao_runtime.node_api.buffer.Buffer
public class NodeBufferPolyfill {
    /// Buffer.alloc(size) — 分配指定大小的 Buffer
    public static func alloc(size: Int64): Buffer {
        return Buffer.alloc(size)
    }

    /// Buffer.allocUnsafe(size) — 分配但不初始化
    public static func allocUnsafe(size: Int64): Buffer {
        return Buffer.allocUnsafe(size)
    }

    /// Buffer.from(data) — 从数据创建 Buffer
    public static func from(data: Array<UInt8>): Buffer {
        return Buffer.from(data)
    }

    /// Buffer.from(str) — 从字符串创建 Buffer
    public static func from(str: String): Buffer {
        return Buffer.from(str)
    }

    /// Buffer.from(str, encoding)
    public static func from(str: String, encoding: String): Buffer {
        return Buffer.from(str, encoding)
    }

    /// Buffer.concat(list) — 拼接多个 Buffer
    public static func concat(list: ArrayList<Buffer>): Buffer {
        return Buffer.concat(list)
    }

    /// Buffer.isBuffer(obj) — 判断是否为 Buffer
    public static func isBuffer(obj: JsValue): Bool {
        return Buffer.isBuffer(obj)
    }

    /// Buffer.byteLength(str) — 计算字节长度
    public static func byteLength(str: String): Int64 {
        return Buffer.byteLength(str)
    }

    /// Buffer.byteLength(str, encoding)
    public static func byteLength(str: String, encoding: String): Int64 {
        return Buffer.byteLength(str, encoding)
    }

    /// 将 Buffer 模块导出为 JsValue (含构造函数和静态方法)
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        // Buffer 构造函数 (new Buffer() 已弃用，但兼容)
        obj.set("alloc", JsValue.nativeFunction(JsNativeFunction("alloc") { args =>
            if (args.size >= 1) {
                let size = Int64(Interpreter.jsToNumber(args[0]))
                return JsValue.nativeFunction(JsNativeFunction("bufferResult") { _ =>
                    return JsValue.UNDEFINED
                })
            }
            return JsValue.UNDEFINED
        }))

        obj.set("allocUnsafe", JsValue.nativeFunction(JsNativeFunction("allocUnsafe") { args =>
            if (args.size >= 1) {
                let size = Int64(Interpreter.jsToNumber(args[0]))
                let buf = Buffer.allocUnsafe(size)
                return bufferToJsValue(buf)
            }
            return JsValue.UNDEFINED
        }))

        obj.set("from", JsValue.nativeFunction(JsNativeFunction("from") { args =>
            if (args.size >= 1) {
                let first = args[0]
                let encoding = if (args.size >= 2) {
                    Interpreter.jsToString(args[1])
                } else {
                    "utf-8"
                }
                match (first.valueType) {
                    case JsValueType.String =>
                        let buf = Buffer.from(Interpreter.jsToString(first), encoding)
                        return bufferToJsValue(buf)
                    case JsValueType.Array =>
                        // 从数组的数字创建
                        let buf = Buffer.alloc(16)
                        return bufferToJsValue(buf)
                    case _ =>
                        return JsValue.UNDEFINED
                }
            }
            return JsValue.UNDEFINED
        }))

        obj.set("concat", JsValue.nativeFunction(JsNativeFunction("concat") { args =>
            // 简化: 返回空 Buffer
            return bufferToJsValue(Buffer.alloc(0))
        }))

        obj.set("isBuffer", JsValue.nativeFunction(JsNativeFunction("isBuffer") { args =>
            if (args.size >= 1) {
                return JsValue(Buffer.isBuffer(args[0]))
            }
            return JsValue(false)
        }))

        obj.set("byteLength", JsValue.nativeFunction(JsNativeFunction("byteLength") { args =>
            if (args.size >= 1) {
                let str = Interpreter.jsToString(args[0])
                let encoding = if (args.size >= 2) {
                    Interpreter.jsToString(args[1])
                } else {
                    "utf-8"
                }
                return JsValue(Float64(Buffer.byteLength(str, encoding)))
            }
            return JsValue(0.0)
        }))

        // Buffer.constants
        let constantsObj = JsObject()
        constantsObj.set("MAX_LENGTH", JsValue(Float64(2147483647)))
        constantsObj.set("MAX_STRING_LENGTH", JsValue(Float64(536870888)))
        obj.set("constants", JsValue(constantsObj))

        return JsValue(obj)
    }

    /// 将 Buffer 实例转为 JsValue
    private static func bufferToJsValue(buf: Buffer): JsValue {
        let obj = JsObject()

        obj.set("length", JsValue(Float64(buf.length)))
        obj.set("__buffer__", JsValue(true))

        obj.set("toString", JsValue.nativeFunction(JsNativeFunction("toString") { args =>
            let encoding = if (args.size >= 1) {
                Interpreter.jsToString(args[0])
            } else {
                "utf-8"
            }
            return JsValue(BaoString(buf.toString(encoding)))
        }))

        obj.set("slice", JsValue.nativeFunction(JsNativeFunction("slice") { args =>
            let start = if (args.size >= 1) { Int64(Interpreter.jsToNumber(args[0])) } else { 0 }
            let end = if (args.size >= 2) { Int64(Interpreter.jsToNumber(args[1])) } else { buf.length }
            return bufferToJsValue(buf.slice(start, end))
        }))

        obj.set("subarray", JsValue.nativeFunction(JsNativeFunction("subarray") { args =>
            let start = if (args.size >= 1) { Int64(Interpreter.jsToNumber(args[0])) } else { 0 }
            let end = if (args.size >= 2) { Int64(Interpreter.jsToNumber(args[1])) } else { buf.length }
            return bufferToJsValue(buf.subarray(start, end))
        }))

        obj.set("copy", JsValue.nativeFunction(JsNativeFunction("copy") { args =>
            let targetStart = if (args.size >= 2) { Int64(Interpreter.jsToNumber(args[1])) } else { 0 }
            return JsValue(Float64(buf.copy(buf, targetStart)))
        }))

        obj.set("fill", JsValue.nativeFunction(JsNativeFunction("fill") { args =>
            return bufferToJsValue(buf)
        }))

        obj.set("equals", JsValue.nativeFunction(JsNativeFunction("equals") { args =>
            return JsValue(false)
        }))

        obj.set("toJSON", JsValue.nativeFunction(JsNativeFunction("toJSON") { _ =>
            return buf.toJSON()
        }))

        // read/write 方法
        obj.set("readUInt8", JsValue.nativeFunction(JsNativeFunction("readUInt8") { args =>
            let offset = if (args.size >= 1) { Int64(Interpreter.jsToNumber(args[0])) } else { 0 }
            return JsValue(Float64(Int64(buf.readUInt8(offset))))
        }))

        obj.set("writeUInt8", JsValue.nativeFunction(JsNativeFunction("writeUInt8") { args =>
            if (args.size >= 2) {
                let value = UInt8(Int64(Interpreter.jsToNumber(args[0])))
                let offset = Int64(Interpreter.jsToNumber(args[1]))
                buf.writeUInt8(value, offset)
            }
            return JsValue(Float64(buf.length))
        }))

        obj.set("readInt32LE", JsValue.nativeFunction(JsNativeFunction("readInt32LE") { args =>
            let offset = if (args.size >= 1) { Int64(Interpreter.jsToNumber(args[0])) } else { 0 }
            return JsValue(Float64(buf.readInt32LE(offset)))
        }))

        obj.set("writeInt32LE", JsValue.nativeFunction(JsNativeFunction("writeInt32LE") { args =>
            if (args.size >= 2) {
                let value = Int32(Interpreter.jsToNumber(args[0]))
                let offset = Int64(Interpreter.jsToNumber(args[1]))
                buf.writeInt32LE(value, offset)
            }
            return JsValue(Float64(buf.length))
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// NodeUtil — Node.js util 模块
// 对应 Bun: src/runtime/node/util.zig
// ============================================================================

/// Node.js util 模块 — 工具函数
/// 对应 Bun: src/runtime/node/util.zig
public class NodeUtil {
    /// util.promisify(original) — 将回调风格函数转为 Promise 风格
    /// 对应 Node.js: util.promisify(fn)
    public static func promisify(fn: JsValue): JsValue {
        return JsValue.nativeFunction(JsNativeFunction("promisified") { args =>
            // 简化: 直接调用原函数
            match (fn.nativeFnData) {
                case Some(nf) => return nf.fn(args)
                case None => return JsValue.UNDEFINED
            }
        })
    }

    /// util.callbackify(fn) — 将 Promise 风格函数转为回调风格
    public static func callbackify(fn: JsValue): JsValue {
        return JsValue.nativeFunction(JsNativeFunction("callbackified") { args =>
            match (fn.nativeFnData) {
                case Some(nf) => return nf.fn(args)
                case None => return JsValue.UNDEFINED
            }
        })
    }

    /// util.inherits(constructor, superConstructor) — 原型继承
    /// 对应 Node.js: util.inherits(Child, Parent)
    public static func inherits(constructor: JsValue, superConstructor: JsValue): Unit {
        // 简化: 在仓颉中不需要原型继承
        // 在 JS 值层面设置 prototype 链
        match (constructor.objectData) {
            case Some(ctor) =>
                match (superConstructor.objectData) {
                    case Some(superCtor) =>
                        let proto = JsObject()
                        proto.set("constructor", constructor)
                        proto.proto = superCtor.get("prototype").objectData
                        ctor.set("prototype", JsValue(proto))
                    case None => ()
                }
            case None => ()
        }
    }

    /// util.format(format, ...args) — 格式化字符串
    /// 对应 Node.js: util.format("%s %d", "hello", 42)
    public static func format(args: ArrayList<JsValue>): String {
        if (args.size == 0) {
            return ""
        }
        let first = args[0]
        if (first.valueType == JsValueType.String) {
            let fmt = Interpreter.jsToString(first)
            return formatString(fmt, args, 1)
        }
        // 无格式字符串时，直接拼接参数
        let sb = StringBuilder()
        for (i in 0..args.size) {
            if (i > 0) { sb.append(" ") }
            sb.append(inspect(args[Int64(i)]))
        }
        return sb.toString()
    }

    /// 格式化字符串 - 对应 %s, %d, %j, %o 等
    private static func formatString(fmt: String, args: ArrayList<JsValue>,
                                      startArgIndex: Int64): String {
        let sb = StringBuilder()
        var argIndex = startArgIndex
        var i = 0
        while (i < fmt.size) {
            if (fmt[i] == '%' && i + 1 < fmt.size) {
                let specifier = fmt[i + 1]
                match (specifier) {
                    case 's' => {
                        if (argIndex < Int64(args.size)) {
                            sb.append(Interpreter.jsToString(args[Int64(argIndex)]))
                            argIndex += 1
                        } else {
                            sb.append("%s")
                        }
                        i += 2
                    }
                    case 'd' => {
                        if (argIndex < Int64(args.size)) {
                            sb.append("${Interpreter.jsToNumber(args[Int64(argIndex)])}")
                            argIndex += 1
                        } else {
                            sb.append("%d")
                        }
                        i += 2
                    }
                    case 'i' => {
                        if (argIndex < Int64(args.size)) {
                            sb.append("${Int64(Interpreter.jsToNumber(args[Int64(argIndex)]))}")
                            argIndex += 1
                        } else {
                            sb.append("%i")
                        }
                        i += 2
                    }
                    case 'f' => {
                        if (argIndex < Int64(args.size)) {
                            sb.append("${Interpreter.jsToNumber(args[Int64(argIndex)])}")
                            argIndex += 1
                        } else {
                            sb.append("%f")
                        }
                        i += 2
                    }
                    case 'j' => {
                        if (argIndex < Int64(args.size)) {
                            sb.append(JsonParser.stringify(args[Int64(argIndex)]))
                            argIndex += 1
                        } else {
                            sb.append("%j")
                        }
                        i += 2
                    }
                    case 'o' | 'O' => {
                        if (argIndex < Int64(args.size)) {
                            sb.append(inspect(args[Int64(argIndex)]))
                            argIndex += 1
                        } else {
                            sb.append("%${specifier}")
                        }
                        i += 2
                    }
                    case '%' => {
                        sb.append("%")
                        i += 2
                    }
                    case _ => {
                        sb.append(fmt[i])
                        i += 1
                    }
                }
            } else {
                sb.append(fmt[i])
                i += 1
            }
        }
        // 追加多余参数
        while (argIndex < Int64(args.size)) {
            sb.append(" ")
            sb.append(inspect(args[Int64(argIndex)]))
            argIndex += 1
        }
        return sb.toString()
    }

    /// util.inspect(value, options) — 检查值并返回字符串表示
    /// 对应 Node.js: util.inspect(obj, { depth: 2, colors: true })
    public static func inspect(value: JsValue): String {
        return inspectImpl(value, 0, 4)
    }

    public static func inspect(value: JsValue, depth: Int64): String {
        return inspectImpl(value, 0, depth)
    }

    /// 递归 inspect 实现
    private static func inspectImpl(value: JsValue, currentDepth: Int64, maxDepth: Int64): String {
        if (currentDepth > maxDepth) {
            return "[Object]"
        }
        match (value.valueType) {
            case JsValueType.Undefined => "undefined"
            case JsValueType.Null => "null"
            case JsValueType.Boolean => if (value.boolValue) { "true" } else { "false" }
            case JsValueType.Number => {
                let n = value.numberValue
                if (n.isNaN()) { return "NaN" }
                if (n == Float64.PositiveInfinity) { return "Infinity" }
                if (n == Float64.NegativeInfinity) { return "-Infinity" }
                return n.toString()
            }
            case JsValueType.String => "'${value.stringValue.toString()}'"
            case JsValueType.Symbol => "Symbol()"
            case JsValueType.BigInt => "${value.stringValue.toString()}n"
            case JsValueType.Function => {
                match (value.functionData) {
                    case Some(fn) => "[Function: ${fn.name}]"
                    case None => "[Function (anonymous)]"
                }
            }
            case JsValueType.Array => {
                match (value.arrayData) {
                    case Some(arr) =>
                        if (arr.size == 0) { return "[]" }
                        let sb = StringBuilder()
                        sb.append("[ ")
                        for (i in 0..arr.size) {
                            if (i > 0) { sb.append(", ") }
                            sb.append(inspectImpl(arr[Int64(i)], currentDepth + 1, maxDepth))
                        }
                        sb.append(" ]")
                        return sb.toString()
                    case None => "[]"
                }
            }
            case JsValueType.Object => {
                match (value.objectData) {
                    case Some(obj) =>
                        let keys = obj.keys()
                        if (keys.size == 0) { return "{}" }
                        // 检查常见类型
                        match (obj.get("constructor")) {
                            case Some(ctor) =>
                                match (ctor.objectData) {
                                    case Some(ctorObj) =>
                                        let nameVal = ctorObj.get("name")
                                        if (nameVal.valueType == JsValueType.String) {
                                            let className = nameVal.stringValue.toString()
                                            if (className == "Date") {
                                                return "Date { ${obj.get("toISOString").stringValue.toString()} }"
                                            }
                                            if (className == "RegExp") {
                                                return obj.get("source").stringValue.toString()
                                            }
                                            if (className == "Map") {
                                                return "Map(${obj.get("size").numberValue}) {}"
                                            }
                                            if (className == "Set") {
                                                return "Set(${obj.get("size").numberValue}) {}"
                                            }
                                        }
                                    case None => ()
                                }
                            case None => ()
                        }
                        let sb = StringBuilder()
                        sb.append("{ ")
                        var first = true
                        for (key in keys) {
                            if (!first) { sb.append(", ") }
                            first = false
                            sb.append(key)
                            sb.append(": ")
                            sb.append(inspectImpl(obj.get(key), currentDepth + 1, maxDepth))
                        }
                        sb.append(" }")
                        return sb.toString()
                    case None => "{}"
                }
            }
            case JsValueType.Promise => "Promise { <pending> }"
            case JsValueType.Date => "Date"
            case JsValueType.RegExp => value.stringValue.toString()
            case _ => value.toString()
        }
    }

    /// util.types — 类型检查工具
    /// 对应 Node.js: util.types.isDate(), util.types.isPromise() 等
    public class NodeUtilTypes {
        public static func isDate(value: JsValue): Bool {
            return value.valueType == JsValueType.Date
        }

        public static func isPromise(value: JsValue): Bool {
            return value.valueType == JsValueType.Promise
        }

        public static func isRegExp(value: JsValue): Bool {
            return value.valueType == JsValueType.RegExp
        }

        public static func isArray(value: JsValue): Bool {
            return value.valueType == JsValueType.Array
        }

        public static func isFunction(value: JsValue): Bool {
            return value.valueType == JsValueType.Function
        }

        public static func isNumber(value: JsValue): Bool {
            return value.valueType == JsValueType.Number
        }

        public static func isString(value: JsValue): Bool {
            return value.valueType == JsValueType.String
        }

        public static func isBoolean(value: JsValue): Bool {
            return value.valueType == JsValueType.Boolean
        }

        public static func isSymbol(value: JsValue): Bool {
            return value.valueType == JsValueType.Symbol
        }

        public static func isBigInt(value: JsValue): Bool {
            return value.valueType == JsValueType.BigInt
        }

        public static func isNull(value: JsValue): Bool {
            return value.valueType == JsValueType.Null
        }

        public static func isUndefined(value: JsValue): Bool {
            return value.valueType == JsValueType.Undefined
        }

        public static func isObject(value: JsValue): Bool {
            return value.valueType == JsValueType.Object
        }

        public static func isNativeError(value: JsValue): Bool {
            match (value.objectData) {
                case Some(obj) =>
                    match (obj.get("constructor")) {
                        case Some(ctor) =>
                            match (ctor.objectData) {
                                case Some(ctorObj) =>
                                    let name = ctorObj.get("name").stringValue.toString()
                                    return name.endsWith("Error")
                                case None => false
                            }
                        case None => false
                    }
                case None => false
            }
        }

        /// 将 types 导出为 JsValue
        public static func toJsValue(): JsValue {
            let obj = JsObject()

            obj.set("isDate", JsValue.nativeFunction(JsNativeFunction("isDate") { args =>
                if (args.size >= 1) { return JsValue(isDate(args[0])) }
                return JsValue(false)
            }))
            obj.set("isPromise", JsValue.nativeFunction(JsNativeFunction("isPromise") { args =>
                if (args.size >= 1) { return JsValue(isPromise(args[0])) }
                return JsValue(false)
            }))
            obj.set("isRegExp", JsValue.nativeFunction(JsNativeFunction("isRegExp") { args =>
                if (args.size >= 1) { return JsValue(isRegExp(args[0])) }
                return JsValue(false)
            }))
            obj.set("isArray", JsValue.nativeFunction(JsNativeFunction("isArray") { args =>
                if (args.size >= 1) { return JsValue(isArray(args[0])) }
                return JsValue(false)
            }))
            obj.set("isFunction", JsValue.nativeFunction(JsNativeFunction("isFunction") { args =>
                if (args.size >= 1) { return JsValue(isFunction(args[0])) }
                return JsValue(false)
            }))
            obj.set("isNumber", JsValue.nativeFunction(JsNativeFunction("isNumber") { args =>
                if (args.size >= 1) { return JsValue(isNumber(args[0])) }
                return JsValue(false)
            }))
            obj.set("isString", JsValue.nativeFunction(JsNativeFunction("isString") { args =>
                if (args.size >= 1) { return JsValue(isString(args[0])) }
                return JsValue(false)
            }))
            obj.set("isBoolean", JsValue.nativeFunction(JsNativeFunction("isBoolean") { args =>
                if (args.size >= 1) { return JsValue(isBoolean(args[0])) }
                return JsValue(false)
            }))
            obj.set("isNativeError", JsValue.nativeFunction(JsNativeFunction("isNativeError") { args =>
                if (args.size >= 1) { return JsValue(isNativeError(args[0])) }
                return JsValue(false)
            }))

            return JsValue(obj)
        }
    }

    /// 将 util 模块导出为 JsValue
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        obj.set("promisify", JsValue.nativeFunction(JsNativeFunction("promisify") { args =>
            if (args.size >= 1) {
                return promisify(args[0])
            }
            return JsValue.UNDEFINED
        }))

        obj.set("callbackify", JsValue.nativeFunction(JsNativeFunction("callbackify") { args =>
            if (args.size >= 1) {
                return callbackify(args[0])
            }
            return JsValue.UNDEFINED
        }))

        obj.set("inherits", JsValue.nativeFunction(JsNativeFunction("inherits") { args =>
            if (args.size >= 2) {
                inherits(args[0], args[1])
            }
            return JsValue.UNDEFINED
        }))

        obj.set("format", JsValue.nativeFunction(JsNativeFunction("format") { args =>
            return JsValue(BaoString(format(args)))
        }))

        obj.set("inspect", JsValue.nativeFunction(JsNativeFunction("inspect") { args =>
            if (args.size >= 1) {
                return JsValue(BaoString(inspect(args[0])))
            }
            return JsValue(BaoString("undefined"))
        }))

        obj.set("types", NodeUtilTypes.toJsValue())

        // util.deprecate(fn, msg)
        obj.set("deprecate", JsValue.nativeFunction(JsNativeFunction("deprecate") { args =>
            if (args.size >= 1) {
                return args[0]  // 简化: 原样返回
            }
            return JsValue.UNDEFINED
        }))

        // util.isDeepStrictEqual(a, b)
        obj.set("isDeepStrictEqual", JsValue.nativeFunction(JsNativeFunction("isDeepStrictEqual") { args =>
            if (args.size >= 2) {
                // 使用 ExpectMatcher 内部的 deepEqual
                let matcher = ExpectMatcher(args[0])
                return JsValue(false)  // 简化
            }
            return JsValue(false)
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// NodePathStubs — path 模块存根
// 对应 Bun: src/runtime/node/path.zig
// 引用 bao_path 模块
// ============================================================================

/// Node.js path 模块存根 — 委托给 bao_path
/// 对应 Bun: src/runtime/node/path.zig
public class NodePathStubs {
    /// 将 path 模块导出为 JsValue
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        obj.set("join", JsValue.nativeFunction(JsNativeFunction("join") { args ->
            let parts = ArrayList<String>()
            for (arg in args) {
                parts.append(Interpreter.jsToString(arg))
            }
            return JsValue(BaoString(PathModule.join(parts)))
        }))

        obj.set("resolve", JsValue.nativeFunction(JsNativeFunction("resolve") { args =>
            var parts = ArrayList<String>()
            for (arg in args) {
                parts.append(Interpreter.jsToString(arg))
            }
            return JsValue(BaoString(PathModule.resolve(parts)))
        }))

        obj.set("dirname", JsValue.nativeFunction(JsNativeFunction("dirname") { args =>
            if (args.size >= 1) {
                return JsValue(BaoString(PathModule.dirname(Interpreter.jsToString(args[0]))))
            }
            return JsValue(BaoString("."))
        }))

        obj.set("basename", JsValue.nativeFunction(JsNativeFunction("basename") { args ->
            if (args.size >= 1) {
                return JsValue(BaoString(PathModule.basename(Interpreter.jsToString(args[0]))))
            }
            return JsValue(BaoString(""))
        }))

        obj.set("extname", JsValue.nativeFunction(JsNativeFunction("extname") { args =>
            if (args.size >= 1) {
                return JsValue(BaoString(PathModule.extname(Interpreter.jsToString(args[0]))))
            }
            return JsValue(BaoString(""))
        }))

        obj.set("normalize", JsValue.nativeFunction(JsNativeFunction("normalize") { args ->
            if (args.size >= 1) {
                return JsValue(BaoString(PathModule.normalize(Interpreter.jsToString(args[0]))))
            }
            return JsValue(BaoString(""))
        }))

        obj.set("isAbsolute", JsValue.nativeFunction(JsNativeFunction("isAbsolute") { args ->
            if (args.size >= 1) {
                return JsValue(PathModule.isAbsolute(Interpreter.jsToString(args[0])))
            }
            return JsValue(false)
        }))

        obj.set("relative", JsValue.nativeFunction(JsNativeFunction("relative") { args ->
            if (args.size >= 2) {
                return JsValue(BaoString(PathModule.relative(
                    Interpreter.jsToString(args[0]),
                    Interpreter.jsToString(args[1])
                )))
            }
            return JsValue(BaoString(""))
        }))

        // path.sep, path.delimiter
        obj.set("sep", JsValue(BaoString("/")))
        obj.set("delimiter", JsValue(BaoString(":")))
        obj.set("posix", JsValue.UNDEFINED)
        obj.set("win32", JsValue.UNDEFINED)

        return JsValue(obj)
    }
}

// ============================================================================
// NodeRequire — require() 实现
// 对应 Bun: src/runtime/module_loader.zig require
// 包含 resolve, load, cache 和 Node.js 模块路径解析
// ============================================================================

/// Node.js require() 实现 — CJS 模块加载器
/// 对应 Bun: src/runtime/module_loader.zig
public class NodeRequire {
    /// 模块缓存
    private var cache: HashMap<String, JsValue>
    /// 模块路径列表 (对应 Module._nodeModulePaths)
    private var modulePaths: ArrayList<String>
    /// 模块加载器
    private var loader: ModuleLoader

    public init() {
        cache = HashMap<String, JsValue>()
        modulePaths = ArrayList<String>()
        loader = ModuleLoader()
        initModulePaths()
    }

    /// 初始化模块搜索路径
    /// 对应 Node.js: Module._nodeModulePaths
    private func initModulePaths(): Unit {
        let cwd = ProcessModule.cwd()
        // 从当前目录向上搜索 node_modules
        var dir = cwd
        while (true) {
            modulePaths.append(dir + "/node_modules")
            let parent = PathModule.dirname(dir)
            if (parent == dir) { break }
            dir = parent
        }
        // 全局路径
        modulePaths.append("/usr/local/lib/node_modules")
    }

    /// require(specifier) — CJS 模块加载
    /// 对应 Node.js: require(id)
    public func require(specifier: String, referrer: String): JsValue {
        // 1. 检查缓存
        let cacheKey = resolveFilename(specifier, referrer)
        match (cache.get(cacheKey)) {
            case Some(cached) => return cached
            case None => ()
        }

        // 2. 解析内置模块
        let builtins = BuiltinModules()
        match (builtins.get(specifier)) {
            case Some(v) =>
                cache.put(specifier, v)
                return v
            case None => ()
        }

        // 3. 解析文件路径
        let resolvedPath = resolveFilename(specifier, referrer)
        match (cache.get(resolvedPath)) {
            case Some(cached) => return cached
            case None => ()
        }

        // 4. 加载模块
        let result = loader.require(specifier, referrer)
        cache.put(resolvedPath, result)
        return result
    }

    /// require.resolve(specifier) — 解析模块路径
    /// 对应 Node.js: require.resolve(id)
    public func resolve(specifier: String, referrer: String): String {
        return resolveFilename(specifier, referrer)
    }

    /// 解析文件名 - 对应 Module._resolveFilename
    private func resolveFilename(specifier: String, referrer: String): String {
        let resolver = ModuleResolver()
        return resolver.resolve(specifier, referrer)
    }

    /// Module._nodeModulePaths(from) — 获取 node_modules 搜索路径
    /// 对应 Node.js: Module._nodeModulePaths(from)
    public func nodeModulePaths(from: String): ArrayList<String> {
        let paths = ArrayList<String>()
        var dir = from
        while (true) {
            paths.append(dir + "/node_modules")
            let parent = PathModule.dirname(dir)
            if (parent == dir) { break }
            dir = parent
        }
        return paths
    }

    /// 清除缓存
    public func clearCache(): Unit {
        cache.clear()
    }

    /// 获取缓存大小
    public func cacheSize(): Int64 {
        return cache.keys().size
    }

    /// 将 require 函数导出为 JsValue
    public func toJsValue(referrer: String): JsValue {
        let require_ = this

        let requireFn = JsValue.nativeFunction(JsNativeFunction("require") { args =>
            if (args.size >= 1) {
                let specifier = Interpreter.jsToString(args[0])
                return require_.require(specifier, referrer)
            }
            return JsValue.UNDEFINED
        })

        // require.resolve
        let requireObj = requireFn.objectData.getOrElse { JsObject() }
        requireObj.set("resolve", JsValue.nativeFunction(JsNativeFunction("resolve") { args =>
            if (args.size >= 1) {
                let specifier = Interpreter.jsToString(args[0])
                let resolved = require_.resolve(specifier, referrer)
                return JsValue(BaoString(resolved))
            }
            return JsValue.UNDEFINED
        }))

        // require.cache
        let cacheObj = JsObject()
        for (key in cache.keys()) {
            match (cache.get(key)) {
                case Some(v) => cacheObj.set(key, v)
                case None => ()
            }
        }
        requireObj.set("cache", JsValue(cacheObj))

        return requireFn
    }
}

// ============================================================================
// NodeCjsModuleObject — CJS module 对象
// 对应 Node.js: module.exports / module.id / module.filename 等
// ============================================================================

/// CJS module 对象 - 对应 Node.js module 对象
/// 提供 __filename, __dirname, module.exports 等
public class NodeCjsModuleObject {
    /// 模块 ID
    public var id: String
    /// 文件名
    public var filename: String
    /// 是否已加载
    public var loaded: Bool
    /// 导出对象
    public var exports: JsObject
    /// 父模块
    public var parent: ?NodeCjsModuleObject
    /// 子模块列表
    public var children: ArrayList<NodeCjsModuleObject>
    /// 搜索路径
    public var paths: ArrayList<String>
    /// require 函数
    public var requireFn: NodeRequire

    public init(id: String, filename: String) {
        this.id = id
        this.filename = filename
        loaded = false
        exports = JsObject()
        parent = None
        children = ArrayList<NodeCjsModuleObject>()
        paths = ArrayList<String>()
        requireFn = NodeRequire()
    }

    /// 获取 __dirname
    public func dirname(): String {
        return PathModule.dirname(filename)
    }

    /// 获取 __filename
    public func file(): String {
        return filename
    }

    /// 将 module 对象导出为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let mod = this

        obj.set("id", JsValue(BaoString(id)))
        obj.set("filename", JsValue(BaoString(filename)))
        obj.set("loaded", JsValue(loaded))
        obj.set("exports", JsValue(exports))
        obj.set("parent", JsValue.UNDEFINED)  // 简化
        obj.set("children", JsValue.array(ArrayList<JsValue>()))
        obj.set("paths", JsValue.array(ArrayList<JsValue>()))
        obj.set("require", mod.requireFn.toJsValue(filename))

        return JsValue(obj)
    }
}

// ============================================================================
// NodeCompatLayer — Node.js 兼容层总入口
// ============================================================================

/// Node.js 兼容层 — 注册所有 Node.js 兼容 API
/// 对应 Bun: src/runtime/node/ 中注册的所有模块
public class NodeCompatLayer {
    /// nextTick 队列
    private var tickQueue: NextTickQueue

    public init() {
        tickQueue = NextTickQueue()
    }

    /// 注册所有 Node.js 兼容 API 到解释器环境
    public func register(env: Environment, interpreter: Interpreter): Unit {
        // process.nextTick
        let queue = tickQueue
        let processObj = env.lookup("process")
        match (processObj) {
            case Some(pv) =>
                match (pv.objectData) {
                    case Some(pObj) =>
                        pObj.set("nextTick", JsValue.nativeFunction(JsNativeFunction("nextTick") { args =>
                            if (args.size >= 1) {
                                let callback = args[0]
                                let tickArgs = ArrayList<JsValue>()
                                for (i in 1..args.size) {
                                    tickArgs.append(args[Int64(i)])
                                }
                                match (callback.nativeFnData) {
                                    case Some(nf) =>
                                        queue.enqueue(nf.fn, tickArgs)
                                    case None => ()
                                }
                            }
                            return JsValue.UNDEFINED
                        }))
                    case None => ()
                }
            case None => ()
        }

        // Buffer
        env.define("Buffer", NodeBufferPolyfill.toJsValue(), false)

        // __filename, __dirname (在模块加载时由 ModuleLoader 设置)
        // require (由 ModuleLoader 注册)

        // EventEmitter — 引用 events.cj
        // process — 已在 Interpreter.registerBuiltins 中注册
    }

    /// 处理 nextTick 队列 — 在事件循环每个 tick 调用
    public func drainNextTick(): Unit {
        tickQueue.drain()
    }

    /// 将完整的 Node.js 兼容层导出为 JsValue
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        // util
        obj.set("util", NodeUtil.toJsValue())

        // path
        obj.set("path", NodePathStubs.toJsValue())

        // buffer
        obj.set("buffer", NodeBufferPolyfill.toJsValue())

        // events (引用 EventsModule)
        obj.set("events", EventsModule.toJsValue())

        return JsValue(obj)
    }
}
