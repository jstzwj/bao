// scope_functions.cj - 作用域函数
// 严格翻译自 bun/src/runtime/test_runner/ScopeFunctions.zig

package bao_runtime.test_runner

import bao_jsc.*
import std.collection.*

// ========== ScopeFunctions Mode ==========

/// 模式
public enum ScopeFunctionsMode {
    | describe
    | test_
}

// ========== ScopeFunctions - 作用域函数 ==========

/// 作用域函数，管理test()/describe()的链式调用（.skip/.todo/.only/.concurrent等）
///
/// ScopeFunctions是一个JS可调用对象，支持链式调用API:
/// test("name", cb)           - 普通测试
/// test.skip("name", cb)      - 跳过测试
/// test.todo("name", cb)      - 标记为TODO
/// test.only("name", cb)      - 只运行此测试
/// test.concurrent("name", cb) - 并发运行测试
/// test.each([1,2,3])("name %s", cb) - 参数化测试
/// test.if(condition)("name", cb) - 条件测试
public class ScopeFunctions {
    public var mode: ScopeFunctionsMode = ScopeFunctionsMode.test_
    public var cfg: BaseScopeCfg = BaseScopeCfg()
    public var each: JSValue = JSValue.zero

    /// 字符串常量
    public static let strings = ScopeFunctionStrings()

    /// 获取.skip属性
    public func getSkip(globalThis: JSGlobalObject): JSValue {
        return genericExtend(cfg: BaseScopeCfg(selfMode: ScopeMode.skip), name: "get .skip", fnName: "skip")
    }

    /// 获取.todo属性
    public func getTodo(globalThis: JSGlobalObject): JSValue {
        return genericExtend(cfg: BaseScopeCfg(selfMode: ScopeMode.todo), name: "get .todo", fnName: "todo")
    }

    /// 获取.failing属性
    public func getFailing(globalThis: JSGlobalObject): JSValue {
        return genericExtend(cfg: BaseScopeCfg(selfMode: ScopeMode.failing), name: "get .failing", fnName: "failing")
    }

    /// 获取.concurrent属性
    public func getConcurrent(globalThis: JSGlobalObject): JSValue {
        return genericExtend(cfg: BaseScopeCfg(selfConcurrent: ConcurrentMode.yes), name: "get .concurrent", fnName: "concurrent")
    }

    /// 获取.serial属性
    public func getSerial(globalThis: JSGlobalObject): JSValue {
        return genericExtend(cfg: BaseScopeCfg(selfConcurrent: ConcurrentMode.no), name: "get .serial", fnName: "serial")
    }

    /// 获取.only属性
    public func getOnly(globalThis: JSGlobalObject): JSValue {
        return genericExtend(cfg: BaseScopeCfg(selfOnly: true), name: "get .only", fnName: "only")
    }

    /// .if()调用
    ///
    /// 当条件为true时跳过（因为.if()的含义是"如果满足条件则运行"，
    /// 这里invert=true表示条件不满足时保留原始配置）
    public func fnIf(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        return genericIf(callFrame: callFrame, conditionalCfg: BaseScopeCfg(selfMode: ScopeMode.skip), name: "call .if()", invert: true, fnName: "if")
    }

    /// .skipIf()调用
    ///
    /// 当条件为true时跳过
    public func fnSkipIf(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        return genericIf(callFrame: callFrame, conditionalCfg: BaseScopeCfg(selfMode: ScopeMode.skip), name: "call .skipIf()", invert: false, fnName: "skipIf")
    }

    /// .todoIf()调用
    ///
    /// 当条件为true时标记为TODO
    public func fnTodoIf(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        return genericIf(callFrame: callFrame, conditionalCfg: BaseScopeCfg(selfMode: ScopeMode.todo), name: "call .todoIf()", invert: false, fnName: "todoIf")
    }

    /// .failingIf()调用
    ///
    /// 当条件为true时标记为failing
    public func fnFailingIf(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        return genericIf(callFrame: callFrame, conditionalCfg: BaseScopeCfg(selfMode: ScopeMode.failing), name: "call .failingIf()", invert: false, fnName: "failingIf")
    }

    /// .concurrentIf()调用
    ///
    /// 当条件为true时设为并发模式
    public func fnConcurrentIf(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        return genericIf(callFrame: callFrame, conditionalCfg: BaseScopeCfg(selfConcurrent: ConcurrentMode.yes), name: "call .concurrentIf()", invert: false, fnName: "concurrentIf")
    }

    /// .serialIf()调用
    ///
    /// 当条件为true时设为串行模式
    public func fnSerialIf(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        return genericIf(callFrame: callFrame, conditionalCfg: BaseScopeCfg(selfConcurrent: ConcurrentMode.no), name: "call .serialIf()", invert: false, fnName: "serialIf")
    }

    /// .each()调用
    ///
    /// 接收一个数组参数，用于参数化测试。
    /// 例如: test.each([1,2,3])("test %s", (n) => { ... })
    public func fnEach(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.arguments(max: 1)
        let array = arguments[0]

        if (array.isUndefinedOrNull() || !array.isArray()) {
            let formatter = ConsoleObject.Formatter(global: globalThis)
            globalThis.`throw`(message: "Expected array, got " + formatter.format(value: array))
            return JSValue.jsUndefined
        }

        if (!each.isEmpty()) {
            globalThis.`throw`(message: "Cannot each on " + format())
            return JSValue.jsUndefined
        }

        return ScopeFunctions.createBound(
            globalThis: globalThis,
            mode: mode,
            each: array,
            cfg: cfg,
            name: "each"
        )
    }

    /// 作为函数调用
    ///
    /// 当test/it/describe被直接调用时触发。
    /// 解析参数（描述、回调、选项），然后入队describe或test回调。
    public func callAsFunction(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let lineNo = captureTestLineNumber(callFrame: callFrame, globalThis: globalThis)

        let buntestStrong = cloneActiveStrong(
            globalThis: globalThis,
            cfg: GetActiveCfg(
                signature: Signature.scopeFunctions(this),
                allowInPreload: false
            )
        ) ?? return JSValue.jsUndefined
        let bunTest = buntestStrong.get() ?? return JSValue.jsUndefined

        // 根据模式决定回调是否必须
        let callbackMode: CallbackMode = match (cfg.selfMode) {
            case ScopeMode.skip | ScopeMode.todo => CallbackMode.allow
            case _ => CallbackMode.require
        }

        let args = ScopeFunctions.parseArguments(
            globalThis: globalThis,
            callFrame: callFrame,
            signature: Signature.scopeFunctions(this),
            cfg: ParseArgumentsCfg(callback: callbackMode, kind: FunctionKind.testOrDescribe)
        )

        let callbackLength: UInt64 = if (let Some(callback) <- args.callback) {
            callback.getLength(global: globalThis)
        } else {
            0
        }

        if (!each.isEmpty()) {
            // 参数化测试 (.each模式)
            if (each.isUndefinedOrNull() || !each.isArray()) {
                let formatter = ConsoleObject.Formatter(global: globalThis)
                globalThis.`throw`(message: "Expected array, got " + formatter.format(value: each))
                return JSValue.jsUndefined
            }

            var testIdx: UInt64 = 0
            var iter = each.arrayIterator(global: globalThis)
            while (let Some(item) <- iter.next() ){
                if (item.isEmpty()) { break }

                // 收集参数列表
                var argsList: Array<JSValue> = Array<JSValue>()
                if (item.isArray()) {
                    // 展开数组作为参数列表
                    var itemIter = item.arrayIterator(global: globalThis)
                    while (let Some(arrayItem) <- itemIter.next() ){
                        argsList.append(arrayItem)
                    }
                } else {
                    argsList.append(item)
                }

                // 格式化标签
                let formattedLabel: ?String = if (let Some(desc) <- args.description) {
                    formatLabel(
                        globalThis: globalThis,
                        label: desc,
                        functionArgs: argsList,
                        testIdx: testIdx
                    )
                } else {
                    None
                }

                // 绑定回调
                let bound = if (let Some(cb) <- args.callback) {
                    JSValueTestExt.bind(
                        value: cb, global: globalThis,
                        thisValue: item, name: BunString.staticStr("cb"),
                        length: 0.0, args: argsList
                    )
                } else {
                    None
                }

                enqueueDescribeOrTestCallback(
                    bunTest: bunTest, globalThis: globalThis, callFrame: callFrame,
                    callback: bound, description: formattedLabel,
                    options: args.options,
                    callbackLength: callbackLength - argsList.size,
                    lineNo: lineNo
                )

                testIdx += 1
            }
        } else {
            // 普通测试
            enqueueDescribeOrTestCallback(
                bunTest: bunTest, globalThis: globalThis, callFrame: callFrame,
                callback: args.callback, description: args.description,
                options: args.options,
                callbackLength: callbackLength,
                lineNo: lineNo
            )
        }

        return JSValue.jsUndefined
    }

    /// 入队describe或test回调
    private func enqueueDescribeOrTestCallback(
        bunTest: BunTest, globalThis: JSGlobalObject, callFrame: CallFrame,
        callback: ?JSValue, description: ?String,
        options: ParseArgumentsOptions, callbackLength: UInt64, lineNo: UInt32
    ) {
        // 只允许在收集阶段
        match (bunTest.phase) {
            case TestPhase.collection => () // OK
            case TestPhase.execution =>
                globalThis.`throw`(message: "Cannot call " + format() + "() inside a test. Call it inside describe() instead.")
                return
            case TestPhase.done =>
                globalThis.`throw`(message: "Cannot call " + format() + "() after the test run has completed")
                return
        }

        // 处理debugger的test reporter
        var testIdForDebugger: Int32 = 0
        let vm = globalThis.bunVM()
        if (let Some(debugger) <- vm.debugger) {
            if (debugger.testReporterAgent.isEnabled()) {
                let id = ScopeFunctions.maxTestIdForDebugger + 1
                ScopeFunctions.maxTestIdForDebugger = id

                let name = description ?? "(unnamed)"
                let parent = bunTest.collection.activeScope
                let parentId = if (parent.base.testIdForDebugger != 0) {
                    parent.base.testIdForDebugger
                } else {
                    -1
                }

                debugger.testReporterAgent.reportTestFound(
                    callFrame: callFrame,
                    id: id,
                    name: name,
                    kind: match (mode) {
                        case ScopeFunctionsMode.describe => TestReporterKind.describe
                        case ScopeFunctionsMode.test_ => TestReporterKind.test_
                    },
                    parentId: parentId
                )
                testIdForDebugger = id
            }
        }

        let hasDoneParameter = if (callback != None) { callbackLength >= 1 } else { false }

        var base = cfg
        base.lineNo = lineNo
        base.testIdForDebugger = testIdForDebugger

        // 设置并发模式
        if (bunTest.defaultConcurrent || (Jest.runner?.concurrent ?? false)) {
            if (base.selfConcurrent == ConcurrentMode.inherit) {
                base.selfConcurrent = ConcurrentMode.yes
            }
        }

        match (mode) {
            case ScopeFunctionsMode.describe =>
                let newScope = bunTest.collection.activeScope.appendDescribe(
                    name: description, base: base
                )
                bunTest.collection.enqueueDescribeCallback(
                    newScope: newScope, callback: callback
                )
            case ScopeFunctionsMode.test_ =>
                // 检查过滤器匹配
                var matchesFilter = true
                if (let Some(reporter) <- bunTest.reporter) {
                    if (let Some(filterRegex) <- reporter.jest.filterRegex) {
                        let activeScope = bunTest.collection.activeScope

                        // 构建完整测试名用于过滤匹配
                        let filterName = filterNames(description: description, parent: activeScope)

                        matchesFilter = filterRegex.matches(str: filterName)
                        bunTest.collection.filterBuffer.clear()
                    }
                }

                if (!matchesFilter) {
                    base.selfMode = ScopeMode.filteredOut
                }

                bunTest.collection.activeScope.appendTest(
                    name: description,
                    callback: if (matchesFilter) { callback } else { None },
                    cfg: ExecutionEntryCfg(
                        hasDoneParameter: hasDoneParameter,
                        timeout: options.timeout,
                        retryCount: options.retry ?? 0,
                        repeatCount: options.repeats
                    ),
                    base: base,
                    phase: AddedInPhase.collection
                )
        }
    }

    /// 通用If处理
    ///
    /// 根据条件和invert参数决定使用conditionalCfg还是保持当前配置
    /// - invert=true: 条件!=invert时使用conditionalCfg（即条件为false时使用）
    /// - invert=false: 条件==invert(false)时保持当前配置（即条件为true时使用conditionalCfg）
    private func genericIf(callFrame: CallFrame, conditionalCfg: BaseScopeCfg, name: String, invert: Bool, fnName: String): JSValue {
        let arguments = callFrame.arguments(max: 1)
        if (arguments.size == 0) {
            globalThis.`throw`(message: "Expected condition to be a boolean")
            return JSValue.jsUndefined
        }

        let condition = arguments[0].toBoolean()
        if (condition != invert) {
            return genericExtend(cfg: conditionalCfg, name: name, fnName: fnName)
        } else {
            return ScopeFunctions.createBound(
                globalThis: globalThis,
                mode: mode, each: each, cfg: cfg, name: fnName
            )
        }
    }

    /// 通用扩展
    ///
    /// 将当前配置与新配置合并，创建新的ScopeFunctions绑定
    private func genericExtend(cfg: BaseScopeCfg, name: String, fnName: String): JSValue {
        // failing不能用于describe
        if (cfg.selfMode == ScopeMode.failing && mode == ScopeFunctionsMode.describe) {
            globalThis.`throw`(message: "Cannot " + (name) + " on " + (format()))
            return JSValue.jsUndefined
        }

        // .only在CI环境中发出警告
        if (cfg.selfOnly) {
            errorInCI(globalObject: globalThis, message: ".only")
        }

        // 合并配置
        if (let Some(extended) <- this.cfg.`extend`(other: cfg)) {
            return ScopeFunctions.createBound(
                globalThis: globalThis,
                mode: mode, each: each, cfg: extended, name: fnName
            )
        } else {
            globalThis.`throw`(message: "Cannot " + (name) + " on " + (format()))
            return JSValue.jsUndefined
        }
    }

    /// 创建未绑定的ScopeFunctions
    public static func createUnbound(globalThis: JSGlobalObject, mode: Mode, each: JSValue, cfg: BaseScopeCfg): JSValue {
        let value = ScopeFunctions(mode: mode, cfg: cfg, each: each).toJS(global: globalThis)
        value.ensureStillAlive()

        // 如果有each参数，设置到C++侧的WriteBarrier以确保GC访问
        if (!each.isEmpty()) {
            eachSetCached(value: value, global: globalThis, each: each)
        }
        return value
    }

    /// 绑定
    ///
    /// 创建一个绑定了当前ScopeFunctions作为this的JS函数
    public func bind(value: JSValue, globalThis: JSGlobalObject, name: String): JSValue {
        let callFn = JSFunction.create(global: globalThis, name: name, hostFn: callAsFunction, argCount: 1)
        let bound = JSValueTestExt.bind(
            value: callFn, global: globalThis,
            thisValue: value, name: BunString.staticStr(name),
            length: 1.0, args: []
        )
        bound.setPrototypeDirect(prototype: value.getPrototype(global: globalThis), global: globalThis)
        return bound
    }

    /// 创建已绑定的ScopeFunctions
    public static func createBound(globalThis: JSGlobalObject, mode: Mode, each: JSValue, cfg: BaseScopeCfg, name: String): JSValue {
        let value = createUnbound(globalThis: globalThis, mode: mode, each: each, cfg: cfg)
        let scopeFunctions = ScopeFunctions(mode: mode, cfg: cfg, each: each)
        return scopeFunctions.bind(value: value, globalThis: globalThis, name: name)
    }

    /// 解析参数
    ///
    /// 解析test/it/describe调用的参数，支持以下形式:
    /// - ("description", callback, options)
    /// - ("description", options, callback)
    /// - ("description", callback)
    /// - (callback, options)
    /// - (callback)
    /// - ("description")
    ///
    /// options可以是数字(超时)或对象{timeout, retry, repeats}
    public static func parseArguments(globalThis: JSGlobalObject, callFrame: CallFrame, signature: Signature, cfg: ParseArgumentsCfg): ParseArgumentsResult {
        let arguments = callFrame.arguments(max: 3)
        let a1 = arguments[0]
        let a2 = arguments[1]
        let a3 = arguments[2]

        // 确定参数数量
        var len: Int = 3
        if (a3.isUndefinedOrNull()) { len = 2 }
        if (a2.isUndefinedOrNull()) { len = 1 }
        if (a1.isUndefinedOrNull()) { len = 0 }

        // 解析参数位置
        var description: JSValue = JSValue.undefined
        var callback: JSValue = JSValue.undefined
        var options: JSValue = JSValue.undefined

        match (len) {
            case 3 =>
                if (a2.isFunction()) {
                    description = a1; callback = a2; options = a3
                } else {
                    description = a1; callback = a3; options = a2
                }
            case 2 =>
                if (a1.isFunction() && !a2.isFunction()) {
                    callback = a1; options = a2
                } else {
                    description = a1; callback = a2
                }
            case 1 =>
                if (a1.isFunction()) {
                    callback = a1
                } else {
                    description = a1
                }
            case _ => ()
        }

        // 验证回调
        var resultCallback: ?JSValue = None
        if (cfg.callback != CallbackMode.require && callback.isUndefinedOrNull()) {
            resultCallback = None
        } else if (callback.isFunction()) {
            resultCallback = callback.withAsyncContextIfNeeded(global: globalThis)
        } else {
            let ordinal = if (cfg.kind == FunctionKind.hook) { "first" } else { "second" }
            globalThis.`throw`(message: (signature) + " expects a function as the " + (ordinal) + " argument")
            return ParseArgumentsResult()
        }

        var result = ParseArgumentsResult()
        result.callback = resultCallback

        // 解析选项
        var timeoutOption: ?Float64 = None

        if (options.isNumber()) {
            timeoutOption = options.asNumber()
        } else if (options.isFunction()) {
            globalThis.`throw`(message: (signature) + "() expects options to be a number or object, not a function")
            return ParseArgumentsResult()
        } else if (options.isObject()) {
            // 解析timeout
            if (let Some(timeout) <- options.get(global: globalThis, name: "timeout")) {
                if (!timeout.isNumber()) {
                    globalThis.`throw`(message: (signature) + "() expects timeout to be a number")
                    return ParseArgumentsResult()
                }
                timeoutOption = timeout.asNumber()
            }

            // 解析retry
            if (let Some(retries) <- options.get(global: globalThis, name: "retry")) {
                if (!retries.isNumber()) {
                    globalThis.`throw`(message: (signature) + "() expects retry to be a number")
                    return ParseArgumentsResult()
                }
                result.options.retry = UInt32(retries.asNumber())
            }

            // 解析repeats
            if (let Some(repeats) <- options.get(global: globalThis, name: "repeats")) {
                if (!repeats.isNumber()) {
                    globalThis.`throw`(message: (signature) + "() expects repeats to be a number")
                    return ParseArgumentsResult()
                }
                if (result.options.retry != None && result.options.retry.getOrThrow() != 0) {
                    globalThis.`throw`(message: (signature) + "(): Cannot set both retry and repeats")
                    return ParseArgumentsResult()
                }
                result.options.repeats = UInt32(repeats.asNumber())
            }
        }

        // 解析描述
        if (description.isUndefinedOrNull()) {
            result.description = None
        } else {
            result.description = getDescription(globalThis: globalThis, description: description, signature: signature)
        }

        // 设置默认retry
        if (result.options.retry == None) {
            if (let Some(runner) <- Jest.runner) {
                result.options.retry = runner.testOptions.retry
            }
        }
        if (result.options.retry ?? 0 != 0 && result.options.repeats != 0) {
            globalThis.`throw`(message: (signature) + "(): Cannot set both retry and repeats")
            return ParseArgumentsResult()
        }

        // 计算最终超时
        var defaultTimeoutMs: ?UInt32 = None
        var overrideTimeoutMs: ?UInt32 = None
        if (let Some(runner) <- Jest.runner) {
            if (runner.defaultTimeoutMs != 0) {
                defaultTimeoutMs = runner.defaultTimeoutMs
            }
            if (runner.defaultTimeoutOverride != UInt32.max) {
                overrideTimeoutMs = runner.defaultTimeoutOverride
            }
        }
        let timeoutOptionMs: ?UInt32 = if (let Some(t) <- timeoutOption) { UInt32(t) } else { None }
        result.options.timeout = timeoutOptionMs ?? overrideTimeoutMs ?? defaultTimeoutMs ?? 0

        return result
    }

    /// 获取描述名称
    ///
    /// 从JS值中提取测试描述:
    /// - 类: 使用类名
    /// - 函数: 使用函数名
    /// - 数字/字符串: 直接转换
    private static func getDescription(globalThis: JSGlobalObject, description: JSValue, signature: Signature): ?String {
        if (description.isEmpty()) { return None }

        if (description.isClass(global: globalThis)) {
            let className = description.getClassName(global: globalThis)
            if (className.length > 0) {
                return className
            }
            let funcName = description.getName(global: globalThis)
            return funcName
        }

        if (description.isFunction()) {
            let funcName = description.getName(global: globalThis)
            if (funcName.length > 0) {
                return funcName
            }
        }

        if (description.isNumber() || description.isString()) {
            return description.toSlice(global: globalThis)
        }

        globalThis.`throw`(message: (signature) + "() expects first argument to be a named class, named function, number, or string")
        return None
    }

    /// 构建过滤名称
    ///
    /// 将测试描述和所有父级describe名称拼接，用空格分隔
    private static func filterNames(description: ?String, parent: ?DescribeScope): String {
        var result = StringBuilder()
        result.append(description ?? "")

        var currentParent = parent
        while (let Some(scope) <- currentParent ){
            if (scope.base.name == None) {
                currentParent = scope.base.parent
                continue
            }
            result.append(" ")
            result.append(scope.base.name ?? "")
            currentParent = scope.base.parent
        }
        return result.toString()
    }

    /// 格式化输出
    public func format(): String {
        var result = ""
        match (mode) {
        case ScopeFunctionsMode.describe => result += "describe"
        case ScopeFunctionsMode.test_ => result += "test"
        }
        if (cfg.selfConcurrent == ConcurrentMode.yes) { result += ".concurrent" }
        else if (cfg.selfConcurrent == ConcurrentMode.no) { result += ".serial" }
        if (cfg.selfMode != ScopeMode.normal) { result += "." + (cfg.selfMode.toString()) }
        if (cfg.selfOnly) { result += ".only" }
        if (!each.isEmpty()) { result += ".each()" }
        return result
    }

    /// 最终化
    public func finalize() {
        // 释放资源
    }

    /// 用于debugger的全局测试ID计数器
    public static var maxTestIdForDebugger: Int32 = 0
}

// ========== 辅助类型 ==========

/// 解析参数配置
public class ParseArgumentsCfg {
    public var callback: CallbackMode = CallbackMode.require
    public var kind: FunctionKind = FunctionKind.testOrDescribe

    public init() {}
    public init(callback: CallbackMode, kind: FunctionKind) {
        this.callback = callback
        this.kind = kind
    }
}

/// 回调模式
public enum CallbackMode {
    | require
    | allow
}

/// 函数类型
public enum FunctionKind {
    | testOrDescribe
    | hook
}

/// 解析参数结果
public class ParseArgumentsResult {
    public var description: ?String = None
    public var callback: ?JSValue = None
    public var options: ParseArgumentsOptions = ParseArgumentsOptions()

    public init() {}

    public func deinit(gpa: Allocator) {
        description = None
    }
}

/// 解析参数选项
public class ParseArgumentsOptions {
    public var timeout: UInt32 = 0
    public var retry: ?UInt32 = None
    public var repeats: UInt32 = 0

    public init() {}
}

/// 作用域函数字符串
public class ScopeFunctionStrings {
    public let describe: String = "describe"
    public let xdescribe: String = "xdescribe"
    public let test_: String = "test"
    public let xtest: String = "xtest"
    public let skip: String = "skip"
    public let todo: String = "todo"
    public let failing: String = "failing"
    public let concurrent: String = "concurrent"
    public let serial: String = "serial"
    public let only: String = "only"
    public let if_: String = "if"
    public let skipIf: String = "skipIf"
    public let todoIf: String = "todoIf"
    public let failingIf: String = "failingIf"
    public let concurrentIf: String = "concurrentIf"
    public let serialIf: String = "serialIf"
    public let each: String = "each"
}
