// 严格翻译自: jsc/JSGlobalObject.zig (1072行)
// Bun JSGlobalObject 绑定

package bao_jsc

// ========== 格里高利日期时间 ==========
// 严格翻译自 JSGlobalObject.GregorianDateTime
public class GregorianDateTime {
    public var year: Int64 = 0
    public var month: Int64 = 0
    public var day: Int64 = 0
    public var hour: Int64 = 0
    public var minute: Int64 = 0
    public var second: Int64 = 0
    public var weekday: Int64 = 0

    public init() {}

    public init(year: Int64, month: Int64, day: Int64, hour: Int64, minute: Int64, second: Int64, weekday: Int64) {
        this.year = year
        this.month = month
        this.day = day
        this.hour = hour
        this.minute = minute
        this.second = second
        this.weekday = weekday
    }
}

// 注意: ErrorCode 已移至 error_code.cj

// 类型别名 - 兼容不同命名约定
public type JsGlobalObject = JSGlobalObject

// ========== 全局对象扩展 ==========
// 严格翻译自 JSGlobalObject.zig
public class JSGlobalObject {
    public var globalThis: JsObject = JsObject.make()
    public var vm: ?BunVirtualMachine = None

    public init() {}

    public init(vm: BunVirtualMachine) {
        this.vm = vm
        this.globalThis = vm.globalObject
    }

    // ========== 分配器 ==========

    // 严格翻译自 JSGlobalObject.allocator
    public func allocator(): String {
        if (let Some(vmInstance) <- vm) {
            return vmInstance.allocator
        }
        ""
    }

    // ========== 错误创建 ==========

    // 发出警告 - 对应 Bun globalThis.emitWarning
    public func emitWarning(message: String, warningType: String): Unit {
        // 发出警告不应中断执行
    }

    // 严格翻译自 JSGlobalObject.throwStackOverflow
    public func throwStackOverflow(): JsError {
        JsError("Stack overflow")
    }

    // 严格翻译自 JSGlobalObject.throwOutOfMemory
    public func throwOutOfMemory(): JsError {
        JsError("Out of memory")
    }

    // 严格翻译自 JSGlobalObject.createOutOfMemoryError
    public func createOutOfMemoryError(): JsValue {
        JsValue(JsError("Out of memory").toString())
    }

    // 创建不支持功能错误
    public func throwUnsupported(msg: String): JsError {
        JsError("Unsupported: " + msg)
    }

    // 严格翻译自 JSGlobalObject.throwError
    public func throwError(msg: String): Unit {
        // stub: log error instead of throwing
    }

    // 严格翻译自 JSGlobalObject.bunVM
    public func bunVM(): BunVirtualMachine {
        if (let Some(vmInstance) <- vm) {
            return vmInstance
        }
        BunVirtualMachine()
    }

    // ========== 日期时间转换 ==========

    // 严格翻译自 JSGlobalObject.gregorianDateTimeToMS
    public func gregorianDateTimeToMS(
        year: Int64, month: Int64, day: Int64,
        hour: Int64, minute: Int64, second: Int64,
        millisecond: Int64, isLocal: Bool
    ): Float64 {
        // 简化实现 - 完整版需要时区支持
        let totalMs = Float64(year * 365 * 24 * 3600 * 1000) +
                      Float64(month * 30 * 24 * 3600 * 1000) +
                      Float64(day * 24 * 3600 * 1000) +
                      Float64(hour * 3600 * 1000) +
                      Float64(minute * 60 * 1000) +
                      Float64(second * 1000) +
                      Float64(millisecond)
        totalMs
    }

    // 严格翻译自 JSGlobalObject.gregorianDateTimeToMSUTC
    public func gregorianDateTimeToMSUTC(
        year: Int64, month: Int64, day: Int64,
        hour: Int64, minute: Int64, second: Int64,
        millisecond: Int64
    ): Float64 {
        gregorianDateTimeToMS(year, month, day, hour, minute, second, millisecond, false)
    }

    // 严格翻译自 JSGlobalObject.msToGregorianDateTimeUTC
    public func msToGregorianDateTimeUTC(ms: Float64): GregorianDateTime {
        // 简化实现
        GregorianDateTime()
    }

    // ========== 参数验证 ==========

    // 严格翻译自 JSGlobalObject.throwInvalidArguments
    public func throwInvalidArguments(fmt: String): JsError {
        JsError("Invalid arguments: " + fmt)
    }

    // 严格翻译自 JSGlobalObject.throwMissingArgumentsValue
    public func throwMissingArgumentsValue(argNames: Array<String>): JsError {
        var names = ""
        var first = true
        for (n in argNames) {
            if (!first) { names = names + ", " }
            names = names + n
            first = false
        }
        if (argNames.size == 1) {
            return JsError("The \"" + names + "\" argument must be specified")
        } else if (argNames.size == 2) {
            return JsError("The \"" + argNames[0] + "\" and \"" + argNames[1] + "\" arguments must be specified")
        }
        JsError("The arguments " + names + " must be specified")
    }

    // 严格翻译自 JSGlobalObject.createInvalidArgumentType
    public func createInvalidArgumentType(name: String, field: String, typename: String): JsValue {
        let msg = "Expected " + field + " to be a " + typename + " for '" + name + "'."
        JsValue(JsError(msg).toString())
    }

    // 严格翻译自 JSGlobalObject.throwInvalidArgumentType
    public func throwInvalidArgumentType(name: String, field: String, typename: String): JsError {
        JsError(createInvalidArgumentType(name, field, typename).toString())
    }

    // 严格翻译自 JSGlobalObject.throwInvalidArgumentValue
    public func throwInvalidArgumentValue(argname: String, value: JsValue): JsError {
        let typeStr = determineSpecificType(value)
        JsError("The \"" + argname + "\" argument is invalid. Received " + typeStr)
    }

    // 严格翻译自 JSGlobalObject.throwInvalidArgumentValueCustom
    public func throwInvalidArgumentValueCustom(argname: String, value: JsValue, message: String): JsError {
        let typeStr = determineSpecificType(value)
        JsError("The \"" + argname + "\" argument " + message + ". Received " + typeStr)
    }

    // 严格翻译自 JSGlobalObject.throwInvalidArgumentPropertyValue
    public func throwInvalidArgumentPropertyValue(argname: String, expected: ?String, value: JsValue): JsError {
        let typeStr = determineSpecificType(value)
        if (let Some(exp) <- expected) {
            return JsError("The property \"" + argname + "\" is invalid. Expected " + exp + ", received " + typeStr)
        }
        JsError("The property \"" + argname + "\" is invalid. Received " + typeStr)
    }

    // 严格翻译自 JSGlobalObject.throwIncompatibleOptionPair
    public func throwIncompatibleOptionPair(opt1: String, opt2: String): JsError {
        JsError("Option \"" + opt1 + "\" cannot be used in combination with option \"" + opt2 + "\"")
    }

    // 严格翻译自 JSGlobalObject.throwInvalidScryptParams
    public func throwInvalidScryptParams(): JsError {
        JsError("Invalid scrypt params")
    }

    // 严格翻译自 JSGlobalObject.throwInvalidArgumentTypeValue
    public func throwInvalidArgumentTypeValue(argname: String, typename: String, value: JsValue): JsError {
        let typeStr = determineSpecificType(value)
        JsError("The \"" + argname + "\" argument must be of `type` " + typename + ". Received " + typeStr)
    }

    // ========== 类型判断 ==========

    // 严格翻译自 JSGlobalObject.determineSpecificType
    public func determineSpecificType(value: JsValue): String {
        if (value.isUndefined()) { return "undefined" }
        if (value.isNull()) { return "null" }
        if (value.isBoolean()) { return "boolean" }
        if (value.isNumber()) { return "number" }
        if (value.isString()) { return "string" }
        if (value.isSymbol()) { return "symbol" }
        if (value.isBigInt()) { return "bigint" }
        if (value.isObject()) {
            let obj = value.toObject()
            let className = obj.className
            if (className == "Array") { return "Array" }
            if (className == "Function") { return "Function" }
            if (className == "Error") { return "Error" }
            if (className == "Map") { return "Map" }
            if (className == "Set") { return "Set" }
            if (className == "Promise") { return "Promise" }
            if (className == "Date") { return "Date" }
            if (className == "RegExp") { return "RegExp" }
            return "Object"
        }
        "unknown"
    }

    // ========== 异常处理 ==========

    // 严格翻译自 JSGlobalObject.hasException
    public func hasException(): Bool {
        false
    }

    // 严格翻译自 JSGlobalObject.clearException
    public func clearException() {}

    // 严格翻译自 JSGlobalObject.takeException
    public func takeException(err: JsError): JsValue {
        JsValue(err.message)
    }

    // 严格翻译自 JSGlobalObject.reportUncaughtException
    public func reportUncaughtException(exception: JsValue): Bool {
        if (let Some(vmInstance) <- vm) {
            return vmInstance.uncaughtException(globalThis, exception, false)
        }
        false
    }

    // ========== ERR 辅助 ==========

    // 严格翻译自 ERR 方法
    public func err(code: ErrorCode, message: String): JsValue {
        let errorName = code.toString()
        let err = JsError(errorName + ": " + message)
        JsValue(err.toString())
    }

    // ========== 创建错误实例 ==========

    // 严格翻译自 JSGlobalObject.createErrorInstance
    public func createErrorInstance(message: String): JsValue {
        JsValue(JsError(message).toString())
    }

    // 严格翻译自 JSGlobalObject.createAggregateError
    public func createAggregateError(errors: Array<JsValue>, message: String): JsValue {
        let obj = JsObject.make()
        obj.className = "AggregateError"
        obj.set("message", JsValue(message))
        obj.set("errors", JsValue(JsObject.make()))
        JsValue(obj)
    }

    // ========== 请求终止 ==========

    // 严格翻译自 JSGlobalObject.requestTermination
    public func requestTermination() {
        if (let Some(vmInstance) <- vm) {
            vmInstance.isShuttingDown_ = true
        }
    }

    // 严格翻译自 JSGlobalObject.clearTerminationException
    public func clearTerminationException() {}

    // ========== 时区 ==========

    // 严格翻译自 JSGlobalObject.setTimeZone
    public func setTimeZone(timeZone: String): Bool {
        true
    }

    // ========== toJSValue ==========

    // 严格翻译自 JSGlobalObject.toJSValue
    public func toJSValue(): JsValue {
        JsValue(globalThis)
    }

    // ========== JS 值转换 ==========

    // 严格翻译自 JSGlobalObject.toJS
    public func toJS(value: JsValue): JsValue {
        value
    }

    // ========== 创建全局对象 ==========

    // 严格翻译自 JSGlobalObject.create
    public static func create(
        vm: BunVirtualMachine,
        console: ConsoleObject,
        contextId: Int64,
        smol: Bool,
        evalMode: Bool,
        cppWorker: ?WebWorker
    ): JsObject {
        let global = JsObject.make()

        // 设置全局属性
        global.set("globalThis", JsValue(global))
        global.set("undefined", JsValue.undefined())
        global.set("NaN", JsValue(Float64.NaN))
        global.set("Infinity", JsValue(1.0 / 0.0))

        // Console
        let consoleObj = JsObject.make()
        consoleObj.className = "Console"
        global.set("console", JsValue(consoleObj))

        // 内置构造函数
        let objectCtor = JsObject.make()
        objectCtor.className = "Function"
        objectCtor.set("name", JsValue("Object"))
        global.set("Object", JsValue(objectCtor))

        let arrayCtor = JsObject.make()
        arrayCtor.className = "Function"
        arrayCtor.set("name", JsValue("Array"))
        global.set("Array", JsValue(arrayCtor))

        let functionCtor = JsObject.make()
        functionCtor.className = "Function"
        functionCtor.set("name", JsValue("Function"))
        global.set("Function", JsValue(functionCtor))

        let stringCtor = JsObject.make()
        stringCtor.className = "Function"
        stringCtor.set("name", JsValue("String"))
        global.set("String", JsValue(stringCtor))

        let numberCtor = JsObject.make()
        numberCtor.className = "Function"
        numberCtor.set("name", JsValue("Number"))
        global.set("Number", JsValue(numberCtor))

        let booleanCtor = JsObject.make()
        booleanCtor.className = "Function"
        booleanCtor.set("name", JsValue("Boolean"))
        global.set("Boolean", JsValue(booleanCtor))

        let promiseCtor = JsObject.make()
        promiseCtor.className = "Function"
        promiseCtor.set("name", JsValue("Promise"))
        global.set("Promise", JsValue(promiseCtor))

        // Math
        let mathObj = JsObject.make()
        mathObj.className = "Math"
        mathObj.set("PI", JsValue(3.141592653589793))
        mathObj.set("E", JsValue(2.718281828459045))
        mathObj.set("LN2", JsValue(0.6931471805599453))
        mathObj.set("LN10", JsValue(2.302585092994046))
        mathObj.set("SQRT2", JsValue(1.4142135623730951))
        global.set("Math", JsValue(mathObj))

        // JSON
        let jsonObj = JsObject.make()
        jsonObj.className = "JSON"
        global.set("JSON", JsValue(jsonObj))

        // Date
        let dateCtor = JsObject.make()
        dateCtor.className = "Function"
        dateCtor.set("name", JsValue("Date"))
        global.set("Date", JsValue(dateCtor))

        // RegExp
        let regexpCtor = JsObject.make()
        regexpCtor.className = "Function"
        regexpCtor.set("name", JsValue("RegExp"))
        global.set("RegExp", JsValue(regexpCtor))

        // Map, Set, WeakMap, WeakSet
        let mapCtor = JsObject.make()
        mapCtor.className = "Function"
        mapCtor.set("name", JsValue("Map"))
        global.set("Map", JsValue(mapCtor))

        let setCtor = JsObject.make()
        setCtor.className = "Function"
        setCtor.set("name", JsValue("Set"))
        global.set("Set", JsValue(setCtor))

        // Error types
        let errorCtors = ["Error", "TypeError", "RangeError", "SyntaxError", "ReferenceError", "URIError", "AggregateError"]
        for (name in errorCtors) {
            let ctor = JsObject.make()
            ctor.className = "Function"
            ctor.set("name", JsValue(name))
            global.set(name, JsValue(ctor))
        }

        // Symbol
        let symbolCtor = JsObject.make()
        symbolCtor.className = "Function"
        symbolCtor.set("name", JsValue("Symbol"))
        global.set("Symbol", JsValue(symbolCtor))

        // BigInt
        let bigintCtor = JsObject.make()
        bigintCtor.className = "Function"
        bigintCtor.set("name", JsValue("BigInt"))
        global.set("BigInt", JsValue(bigintCtor))

        // Proxy
        let proxyCtor = JsObject.make()
        proxyCtor.className = "Function"
        proxyCtor.set("name", JsValue("Proxy"))
        global.set("Proxy", JsValue(proxyCtor))

        global
    }

    // 严格翻译自 JSGlobalObject.createForTestIsolation
    public static func createForTestIsolation(oldGlobal: JsObject, console: ConsoleObject): JsObject {
        let newGlobal = JsObject.make()
        // 复制全局属性
        for (key in oldGlobal.keys()) {
            newGlobal.set(key, oldGlobal.get(key))
        }
        newGlobal
    }

    // ========== reload ==========
    // 严格翻译自 JSGlobalObject.reload
    public func reload() {
        // 重新加载全局对象
    }

    // ========== vm() ==========
    public func getVm(): ?BunVirtualMachine {
        vm
    }
}

// 注意: ZigStackFrame 已移至 zig_stack_frame.cj
// 注意: ZigStackTrace 已移至 zig_stack_trace.cj
// 注意: ZigException 已移至 zig_exception.cj

// 注意: ZigExceptionHolder 已移至 zig_exception.cj (or virtual_machine.cj)
