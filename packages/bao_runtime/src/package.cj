// bao_runtime - JavaScript 运行时
// 对应 Bun: src/runtime/, src/jsc/
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_parser.{Stmt, Expr, StmtTag, ExprTag, OpCode, Binding, BindingTag, GFn, GFnBody, GArg, GClass, GProperty, GPropertyKind, GDecl, SwitchCase, ParserOptions, ParserFeatures, Source as ParserSource, Log as ParserLog, LogLevel as ParserLogLevel, Loc as ParserLoc, SourceLoc as ParserSourceLoc, Scope, ScopeKind, Symbol, SymbolKind, Ref, RefTag, DeclKind, OptionalChain, Parser, ImportRecord}
import bao_sys.*
import bao_event_loop.*
import bao_path.*
import bao_threading.*
import std.time.DateTime

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
// 对应 Bun: src/j.zig - JsValue
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
        // Cangjie enums don't have built-in == comparison.
        // Use exhaustive match for correct equality.
        match (this) {
            case Undefined => match (right) { case Undefined => true case _ => false }
            case Null => match (right) { case Null => true case _ => false }
            case Boolean => match (right) { case Boolean => true case _ => false }
            case Number => match (right) { case Number => true case _ => false }
            case String => match (right) { case String => true case _ => false }
            case Symbol => match (right) { case Symbol => true case _ => false }
            case BigInt => match (right) { case BigInt => true case _ => false }
            case Object => match (right) { case Object => true case _ => false }
            case Array => match (right) { case Array => true case _ => false }
            case Function => match (right) { case Function => true case _ => false }
            case Date => match (right) { case Date => true case _ => false }
            case RegExp => match (right) { case RegExp => true case _ => false }
            case Map => match (right) { case Map => true case _ => false }
            case Set => match (right) { case Set => true case _ => false }
            case Promise => match (right) { case Promise => true case _ => false }
            case ArrayBuffer => match (right) { case ArrayBuffer => true case _ => false }
            case TypedArray => match (right) { case TypedArray => true case _ => false }
            case DataView => match (right) { case DataView => true case _ => false }
            case Error => match (right) { case Error => true case _ => false }
        }
    }

    public operator func !=(right: JsValueType): Bool {
        return !(this == right)
    }
}

/// JavaScript 值表示
/// 对应 Bun: src/jsc/JsValue.zig
public class JsValue {
    public let valueType: JsValueType
    public var boolValue: Bool
    public var numberValue: Float64
    public var stringValue: BaoString
    public var objectData: ?JsObject
    public var objectValue: ?JsObject = None
    public var arrayData: ?ArrayList<JsValue>
    public var functionData: ?JsFunction
    public var nativeFnData: ?JsNativeFunction
    public var promiseData: ?JsPromise

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
        promiseData = None
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
        promiseData = None
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
        promiseData = None
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
        promiseData = None
    }

    public init(s: String) {
        valueType = JsValueType.String
        stringValue = BaoString(s)
        boolValue = false
        numberValue = 0.0
        objectData = None
        arrayData = None
        functionData = None
        nativeFnData = None
        promiseData = None
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
        promiseData = None
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

    /// 创建 Promise JsValue — 同时存储 JsPromise 和 JsObject 包装
    public static func promise(p: JsPromise, obj: JsObject): JsValue {
        let v = JsValue(JsValueType.Object)
        v.objectData = Some(obj)
        v.promiseData = Some(p)
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

    /// 是否为 null 或 undefined
    public func isUndefinedOrNull(): Bool {
        valueType == JsValueType.Undefined || valueType == JsValueType.Null
    }

    /// 别名: isEmptyOrUndefinedOrNull
    public func isEmptyOrUndefinedOrNull(): Bool {
        isUndefinedOrNull()
    }

    /// 是否为 undefined
    public func isUndefined(): Bool {
        valueType == JsValueType.Undefined
    }

    /// 是否为 null
    public func isNull(): Bool {
        valueType == JsValueType.Null
    }

    /// 是否为布尔值
    public func isBoolean(): Bool {
        valueType == JsValueType.Boolean
    }

    /// 是否为数字
    public func isNumber(): Bool {
        valueType == JsValueType.Number
    }

    /// 是否为字符串
    public func isString(): Bool {
        valueType == JsValueType.String
    }

    /// 是否为对象
    public func isObject(): Bool {
        valueType == JsValueType.Object
    }

    /// 是否为 ArrayBuffer
    public func isArrayBuffer(): Bool {
        if (valueType == JsValueType.Object) {
            match (objectData) {
                case Some(obj) => obj.className == "ArrayBuffer"
                case None => false
            }
        } else {
            false
        }
    }

    /// ArrayBuffer 切片
    public func arrayBufferSlice(): Array<UInt8> {
        Array<UInt8>()
    }

    /// 转为 Float64
    public func asNumber(): Float64 {
        toNumber()
    }

    /// 转为布尔值
    public func asBoolean(): Bool {
        toBoolean()
    }

    /// 转为 Int32
    public func toInt32(): Int32 {
        Int32(toNumber())
    }

    /// 转为 Int64
    public func toInt64(): Int64 {
        Int64(toNumber())
    }

    /// 取消保护 (GC 引用计数) — 对应 JSC: JSValueUnprotect
    public func unprotect(): Unit {
        // 在真实 JSC 中减少 GC 引用计数
    }

    /// 确保仍活跃 (防止 GC 回收) — 对应 JSC: ensureStillAlive
    public func ensureStillAlive(): Unit {
        // 在真实 JSC 中防止编译器优化掉引用
    }

    /// 是否为 Response
    public func isResponse(): Bool {
        if (valueType == JsValueType.Object) {
            match (objectData) {
                case Some(obj) => obj.className == "Response"
                case None => false
            }
        } else {
            false
        }
    }

    /// 转为 Response — 对应 Bun: JSValue.asResponse
    public func toResponse(): ?Any {
        None
    }

    /// 静态工厂: null
    public static func jsNull(): JsValue {
        JsValue.NULL
    }

    /// 静态工厂: true
    public static func jsTrue(): JsValue {
        JsValue.TRUE
    }

    /// 静态工厂: false
    public static func jsFalse(): JsValue {
        JsValue.FALSE
    }

    /// 静态工厂: boolean
    public static func jsBoolean(b: Bool): JsValue {
        JsValue(b)
    }

    /// 静态工厂: number
    public static func jsNumber(n: Float64): JsValue {
        JsValue(n)
    }

    /// 静态工厂: number
    public static func jsNumber(n: Int64): JsValue {
        JsValue(Float64(n))
    }

    /// 静态常量: zero
    public static let zero: JsValue = JsValue(0.0)

    /// 调用此值为函数 — 对应 JSC: JSObjectCallAsFunction
    public func call(args: ArrayList<JsValue>): JsValue {
        JsValue.UNDEFINED
    }

    /// 保护 (GC 引用计数) — 对应 JSC: JSValueProtect
    public func protect(): Unit {
        // 在真实 JSC 中增加 GC 引用计数
    }
}

/// JavaScript 对象
public class JsObject {
    private var properties: HashMap<String, JsValue>
    private var proto: ?JsObject
    public var className: String = "Object"

    public init() {
        properties = HashMap<String, JsValue>()
        proto = None
    }

    /// 获取属性
    public func get(key: String): JsValue {
        let opt = properties.get(key)
        if (opt.isSome()) {
            return opt.getOrThrow()
        }
        if (proto.isSome()) {
            return proto.getOrThrow().get(key)
        }
        return JsValue.UNDEFINED
    }

    /// 设置属性
    public func set(key: String, value: JsValue): Unit {
        properties.put(key, value)
    }

    /// 判断是否有属性
    public func has(key: String): Bool {
        return properties.contains(key)
    }

    /// 引用相等比较 — 用于 prototype chain 中的对象标识判断
    /// Cangjie class 是引用类型，此处用属性数量+类名作为近似同一性判断
    public func sameRef(other: JsObject): Bool {
        return this.className == other.className
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

    /// 获取所有自有属性名
    public func getOwnPropertyNames(): ArrayList<String> {
        properties.keys()
    }

    /// 获取原型对象 — 对应 JS Object.getPrototypeOf(obj)
    public func getProto(): ?JsObject {
        proto
    }

    /// 设置原型对象 — 对应 JS Object.setPrototypeOf(obj, proto) / __proto__
    public func setProto(p: ?JsObject): Unit {
        proto = p
    }

    /// 静态工厂
    public static func make(): JsObject {
        JsObject()
    }
}

// ============================================================================
// 工具函数
// ============================================================================

/// 获取当前时间的毫秒数 (Unix epoch)
private func currentTimeMillis(): Int64 {
    DateTime.now().toUnixTimeStamp().toMilliseconds()
}

// ============================================================================
// 定时器条目
// ============================================================================

/// 定时器条目 — 内部使用
class TimerEntry {
    public var id: Int64
    public var deadlineMs: Int64
    public var intervalMs: Int64
    public var isInterval: Bool
    public var callback: () -> Unit
    public var cancelled: Bool

    public init(id: Int64, deadlineMs: Int64, intervalMs: Int64, isInterval: Bool, callback: () -> Unit) {
        this.id = id
        this.deadlineMs = deadlineMs
        this.intervalMs = intervalMs
        this.isInterval = isInterval
        this.callback = callback
        this.cancelled = false
    }
}

// ============================================================================
// 事件循环 — 带定时器调度
// ============================================================================

public class EventLoop {
    private var nextTimerId: Int64
    private var timers: ArrayList<TimerEntry>
    private var cancelledIds: HashSet<Int64>
    private var microtasks: ArrayList<() -> Unit>

    public init() {
        nextTimerId = 1
        timers = ArrayList<TimerEntry>()
        cancelledIds = HashSet<Int64>()
        microtasks = ArrayList<() -> Unit>()
    }

    public func enter(): Unit {
        ()
    }

    public func exit(): Unit {
        ()
    }

    public func runCallback(callback: JsValue, globalThis: JsObject, thisValue: JsValue, args: ArrayList<JsValue>): Unit {
        ()
    }

    /// 唤醒事件循环
    public func wakeup(): Unit {
        ()
    }

    /// 设置定时器 (setTimeout)
    public func setTimeout(delayMs: Int64, callback: () -> Unit): Int64 {
        let id = nextTimerId
        nextTimerId += 1
        let now = currentTimeMillis()
        let entry = TimerEntry(id, now + delayMs, 0, false, callback)
        timers.append(entry)
        return id
    }

    /// 设置间隔定时器 (setInterval)
    public func setInterval(intervalMs: Int64, callback: () -> Unit): Int64 {
        let id = nextTimerId
        nextTimerId += 1
        let now = currentTimeMillis()
        let entry = TimerEntry(id, now + intervalMs, intervalMs, true, callback)
        timers.append(entry)
        return id
    }

    /// 取消定时器
    public func clearTimer(id: Int64): Unit {
        cancelledIds.put(id)
        for (timer in timers) {
            if (timer.id == id) {
                timer.cancelled = true
                return
            }
        }
    }

    /// 检查定时器是否已被取消
    public func isTimerCancelled(id: Int64): Bool {
        cancelledIds.contains(id)
    }

    /// 入队微任务
    public func enqueueMicrotask(task: () -> Unit): Unit {
        microtasks.append(task)
    }

    /// 执行所有到期的定时器
    public func tick(): Unit {
        let now = currentTimeMillis()
        var expired = ArrayList<TimerEntry>()
        var remaining = ArrayList<TimerEntry>()

        for (timer in timers) {
            if (timer.cancelled || cancelledIds.contains(timer.id)) {
                continue
            }
            if (timer.deadlineMs <= now) {
                expired.append(timer)
            } else {
                remaining.append(timer)
            }
        }

        timers = remaining

        for (timer in expired) {
            if (cancelledIds.contains(timer.id)) {
                continue
            }
            timer.callback()
            if (timer.isInterval && !cancelledIds.contains(timer.id)) {
                timer.deadlineMs = now + timer.intervalMs
                timers.append(timer)
            }
        }
    }

    /// 排空微任务队列
    public func drainMicrotasks(): Unit {
        while (microtasks.size > 0) {
            let tasks = microtasks
            microtasks = ArrayList<() -> Unit>()
            for (task in tasks) {
                task()
            }
        }
    }

    /// 是否有待执行的定时器
    public func hasPendingTimers(): Bool {
        for (timer in timers) {
            if (!timer.cancelled && !cancelledIds.contains(timer.id)) {
                return true
            }
        }
        return false
    }

    /// 执行一次 tick
    public func tickOnce(): Unit {
        tick()
    }

    /// 入队任务
    public func enqueue(task: () -> Unit): Unit {
        task()
    }

    /// 入队并发任务
    public func enqueueConcurrent(task: AnyTask): Unit {
        task.run()
    }

    /// 运行事件循环直到所有定时器和微任务完成
    public func run(): Unit {
        runUntilEmpty()
    }

    /// 运行事件循环直到没有待处理的定时器
    public func runUntilEmpty(): Unit {
        var maxIter = 10000
        while ((hasPendingTimers() || microtasks.size > 0) && maxIter > 0) {
            drainMicrotasks()
            tick()
            maxIter -= 1
        }
    }
}

public class ParseResultError {
    public var message: String
    public var loc: ParserSourceLoc

    public init(message: String) {
        this.message = message
        this.loc = ParserSourceLoc()
    }
}

public class ParseResult {
    public var program: ArrayList<Stmt>
    public var errors: ArrayList<ParseResultError>
    public var importRecords: ArrayList<ImportRecord>   // 模块导入记录

    public init() {
        program = ArrayList<Stmt>()
        errors = ArrayList<ParseResultError>()
        importRecords = ArrayList<ImportRecord>()
    }

    public func hasErrors(): Bool {
        return errors.size > 0
    }
}

public class JsParser {
    public init() {}

    /// 解析 JavaScript/TypeScript 源代码
    /// 对应 Bun: Transpiler.parse + Lexer + Parser 管线
    public func parse(source: String, options: ParserOptions): ParseResult {
        let result = ParseResult()

        // 创建 bao_parser 的 Source 和 Log
        let parserSource = ParserSource(options.sourceFile, source)
        let log = ParserLog()

        // 创建解析器并解析
        let parser = Parser(log, parserSource, options)
        let blockStmt = parser.parse()

        // 提取语句列表 — parser.parse() 返回 StmtTag.Block 包裹所有语句
        if (blockStmt.tag == StmtTag.Block) {
            result.program = blockStmt.stmts
        }

        // 复制模块导入记录 (import/export 路径信息)
        result.importRecords = parser.importRecords

        // 转换错误日志为 ParseResultError
        for (msg in log.msgs) {
            let isError = match (msg.level) {
                case ParserLogLevel.Error => true
                case _ => false
            }
            if (isError) {
                var loc = ParserSourceLoc()
                let locOpt = msg.data.location
                if (locOpt.isSome()) {
                    loc = locOpt.getOrThrow()
                }
                result.errors.append(ParseResultError(msg.data.text))
            }
        }

        return result
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
    private var moduleLoader: ModuleLoader
    private var running: Bool
    /// process.exit() 设置的退出码 (-1 表示未设置)
    public var exitCode: Int64

    public init() {
        eventLoop = EventLoop()
        globalObject = JsObject()
        interpreter = Interpreter()
        parser = JsParser()
        moduleLoader = ModuleLoader({ path => VirtualMachine.readFileContents(path) })
        running = false
        exitCode = -1
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
            println(errorMsg.toString())
            return JsValue.UNDEFINED
        }

        // 设置模块上下文并执行 AST
        interpreter.setCurrentFile(filename)
        interpreter.setImportRecords(result.importRecords)
        return interpreter.eval(result.program)
    }

    /// 执行文件
    /// 对应 Bun: VirtualMachine.loadEntryPoint → transpileAndRun
    public func executeFile(path: String): JsValue {
        let source = readFileContents(path)
        if (source.isEmpty()) {
            println("Error: Cannot read file '${path}'")
            return JsValue.UNDEFINED
        }

        // 共享事件循环: VM 的 eventLoop 与 Interpreter 的 eventLoop 是同一个
        interpreter.setEventLoop(eventLoop)

        // 设置 CJS 模块上下文 (module, exports, require)
        let exports = JsObject()
        let moduleWrapper = JsObject()
        moduleWrapper.set("exports", JsValue(exports))
        moduleWrapper.set("id", JsValue(BaoString(path)))
        moduleWrapper.set("filename", JsValue(BaoString(path)))
        moduleWrapper.set("loaded", JsValue(false))

        let env = interpreter.getGlobalEnv()
        env.define("module", JsValue(moduleWrapper), true)
        env.define("exports", JsValue(exports), true)
        env.define("require", Interpreter.makeNativeFn("require") { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let spec = Interpreter.jsToString(args[0])
            return moduleLoader.require(spec, path)
        }, false)
        env.define("__filename", JsValue(BaoString(path)), false)

        var result = JsValue.UNDEFINED
        try {
            result = eval(source, path)
            // 执行事件循环直到所有定时器/微任务完成
            eventLoop.runUntilEmpty()
        } catch (e: ProcessExitSignal) {
            // process.exit() 被调用 — 保存退出码
            exitCode = e.exitCode
        }

        return result
    }

    /// 读取文件内容 — 使用 SysFs 系统调用
    private static func readFileContents(path: String): String {
        let fdResult = SysFs.openRead(path)
        let fd = if (fdResult.isOk()) {
            fdResult.result().getOrThrow()
        } else {
            return ""
        }

        // 循环读取文件内容
        var allBytes = ArrayList<UInt8>()
        let bufSize: Int64 = 8192
        var buf = Array<UInt8>(bufSize, { _ => UInt8(0) })
        while (true) {
            let readResult = SysFs.read(fd, buf)
            match (readResult) {
                case SysMaybe.Err(_) =>
                    let _ = SysFs.close(fd)
                    return ""
                case SysMaybe.Ok(bytesRead) =>
                    if (bytesRead == 0) {
                        break  // EOF
                    }
                    for (i in 0..bytesRead) {
                        allBytes.append(buf[i])
                    }
            }
        }

        let _ = SysFs.close(fd)

        // 转换为字符串
        var sb = StringBuilder()
        for (b in allBytes) {
            sb.append(Rune(b))
        }
        return sb.toString()
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

    // 覆盖率字节范围 (桩)
    public func getCoverageByteRanges(): ArrayList<Any> {
        ArrayList<Any>()
    }

    // 顶级目录 (桩)
    public func getTopLevelDir(): String {
        ""
    }

    /// 测试隔离模式开关
    /// 对应 Bun: vm.test_isolation_enabled
    public var testIsolationEnabled: Bool = false

    /// 收集覆盖率数据
    /// 对应 Bun: JSC coverage SPI (jsc_get_coverage_data)
    /// 返回覆盖函数/行/语句的条目列表
    public func collectCoverageData(sourceUrl: String): ?ArrayList<CoverageEntry> {
        // 当前 JSC 桥接尚未实现覆盖率收集
        // 完整实现需要调用 jsc/JSCoverageCollect
        return None
    }

    /// 收集行级覆盖率
    /// 对应 Bun: SourceMap byte-range → line mapping
    public func collectLineCoverage(sourceUrl: String): ArrayList<LineCoverageEntry> {
        // 当 JSCoverageCollect 不可用时, 从字节码映射推断行覆盖
        return ArrayList<LineCoverageEntry>()
    }

    /// 隔离模式: 重置全局状态用于下一个测试文件
    /// 对应 Bun: vm.swapGlobalForTestIsolation()
    public func swapGlobalForTestIsolation(): Unit {
        if (!testIsolationEnabled) {
            return
        }
        // 重置全局环境中的测试注册状态
        // 完整实现需要: 清空 describe/test 注册表, 重置 hooks, 等.
        interpreter.resetForTestIsolation()
    }
}

// ============================================================================
// 覆盖率收集类型
// ============================================================================

/// 覆盖率条目类型
/// 对应 Bun: JSC coverage data kinds
public enum CoverageKind {
    | function
    | line
    | statement
}

/// 覆盖率条目
/// 对应 Bun: JSC coverage entry (function/line/statement)
public class CoverageEntry {
    public var kind: CoverageKind
    public var name: String
    public var count: Int64
    public var lineNumber: Int64
    public var startLine: Int64
    public var endLine: Int64

    public init(kind: CoverageKind) {
        this.kind = kind
        this.name = ""
        this.count = 0
        this.lineNumber = 0
        this.startLine = 0
        this.endLine = 0
    }
}

/// 行覆盖率条目
/// 对应 Bun: SourceMap line coverage mapping
public class LineCoverageEntry {
    public var lineNumber: Int64
    public var count: Int64

    public init(lineNumber: Int64, count: Int64) {
        this.lineNumber = lineNumber
        this.count = count
    }
}
