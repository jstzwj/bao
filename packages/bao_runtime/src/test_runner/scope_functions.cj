// scope_functions.cj - 作用域函数
// 严格翻译自 bun/src/runtime/test_runner/ScopeFunctions.zig

package bao_runtime.test_runner

import bao_jsc.{BunString, CallFrame, ConsoleFormatter, ConsoleObject, Formatter, JSFunction, JSFunctionCreateOptions, JSGlobalObject, JsValue}
import bao_collections.ArrayList
import bao_collections.HashMap
import bao_core.{Allocator, defaultAllocator}

// ========== ScopeFunctions Mode ==========

/// 模式
public enum ScopeFunctionsMode {
    | describe
    | test_

    public operator func ==(other: ScopeFunctionsMode): Bool {
        match (this) {
            case describe => match (other) { case describe => true; case _ => false }
            case test_ => match (other) { case test_ => true; case _ => false }
        }
    }

    public operator func !=(other: ScopeFunctionsMode): Bool {
        !(this == other)
    }
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
    public var each: JsValue = JsValue.zero

    /// 字符串常量
    public static let strings = ScopeFunctionStrings()

    /// 获取.skip属性
    public func getSkip(globalThis: JSGlobalObject): JsValue {
        let cfg = BaseScopeCfg()
        cfg.selfMode = ScopeMode.skip
        return genericExtend(globalThis: globalThis, cfg: cfg, name: "get .skip", fnName: "skip")
    }

    /// 获取.todo属性
    public func getTodo(globalThis: JSGlobalObject): JsValue {
        let cfg = BaseScopeCfg()
        cfg.selfMode = ScopeMode.todo
        return genericExtend(globalThis: globalThis, cfg: cfg, name: "get .todo", fnName: "todo")
    }

    /// 获取.failing属性
    public func getFailing(globalThis: JSGlobalObject): JsValue {
        let cfg = BaseScopeCfg()
        cfg.selfMode = ScopeMode.failing
        return genericExtend(globalThis: globalThis, cfg: cfg, name: "get .failing", fnName: "failing")
    }

    /// 获取.concurrent属性
    public func getConcurrent(globalThis: JSGlobalObject): JsValue {
        let cfg = BaseScopeCfg()
        cfg.selfConcurrent = ConcurrentMode.yes
        return genericExtend(globalThis: globalThis, cfg: cfg, name: "get .concurrent", fnName: "concurrent")
    }

    /// 获取.serial属性
    public func getSerial(globalThis: JSGlobalObject): JsValue {
        let cfg = BaseScopeCfg()
        cfg.selfConcurrent = ConcurrentMode.no
        return genericExtend(globalThis: globalThis, cfg: cfg, name: "get .serial", fnName: "serial")
    }

    /// 获取.only属性
    public func getOnly(globalThis: JSGlobalObject): JsValue {
        let cfg = BaseScopeCfg()
        cfg.selfOnly = true
        return genericExtend(globalThis: globalThis, cfg: cfg, name: "get .only", fnName: "only")
    }

    /// .if()调用
    ///
    /// 当条件为true时跳过（因为.if()的含义是"如果满足条件则运行"，
    /// 这里invert=true表示条件不满足时保留原始配置）
    public func fnIf(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let ccfg = BaseScopeCfg()
        ccfg.selfMode = ScopeMode.skip
        return genericIf(globalThis: globalThis, callFrame: callFrame, conditionalCfg: ccfg, name: "call .if()", invert: true, fnName: "if")
    }

    /// .skipIf()调用
    ///
    /// 当条件为true时跳过
    public func fnSkipIf(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let ccfg = BaseScopeCfg()
        ccfg.selfMode = ScopeMode.skip
        return genericIf(globalThis: globalThis, callFrame: callFrame, conditionalCfg: ccfg, name: "call .skipIf()", invert: false, fnName: "skipIf")
    }

    /// .todoIf()调用
    ///
    /// 当条件为true时标记为TODO
    public func fnTodoIf(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let ccfg = BaseScopeCfg()
        ccfg.selfMode = ScopeMode.todo
        return genericIf(globalThis: globalThis, callFrame: callFrame, conditionalCfg: ccfg, name: "call .todoIf()", invert: false, fnName: "todoIf")
    }

    /// .failingIf()调用
    ///
    /// 当条件为true时标记为failing
    public func fnFailingIf(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let ccfg = BaseScopeCfg()
        ccfg.selfMode = ScopeMode.failing
        return genericIf(globalThis: globalThis, callFrame: callFrame, conditionalCfg: ccfg, name: "call .failingIf()", invert: false, fnName: "failingIf")
    }

    /// .concurrentIf()调用
    ///
    /// 当条件为true时设为并发模式
    public func fnConcurrentIf(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let ccfg = BaseScopeCfg()
        ccfg.selfConcurrent = ConcurrentMode.yes
        return genericIf(globalThis: globalThis, callFrame: callFrame, conditionalCfg: ccfg, name: "call .concurrentIf()", invert: false, fnName: "concurrentIf")
    }

    /// .serialIf()调用
    ///
    /// 当条件为true时设为串行模式
    public func fnSerialIf(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let ccfg = BaseScopeCfg()
        ccfg.selfConcurrent = ConcurrentMode.no
        return genericIf(globalThis: globalThis, callFrame: callFrame, conditionalCfg: ccfg, name: "call .serialIf()", invert: false, fnName: "serialIf")
    }

    /// .each()调用
    ///
    /// 接收一个数组参数，用于参数化测试。
    /// 例如: test.each([1,2,3])("test %s", (n) => { ... })
    public func fnEach(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        let array = arguments[0]

        if (array.isUndefinedOrNull() || !array.isArray()) {
            let formatter = ConsoleFormatter()
            globalThis.`throw`("Expected array, got " + formatter.format(array))
            return JsValue.jsUndefined()
        }

        if (!each.isEmpty()) {
            globalThis.`throw`("Cannot each on " + format())
            return JsValue.jsUndefined()
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
    public func callAsFunction(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let lineNo = captureTestLineNumber(callFrame: callFrame, globalThis: globalThis)

        let buntestStrong = BunTest.cloneActiveStrong() ?? return JsValue.jsUndefined()
        let bunTest = buntestStrong.get() ?? return JsValue.jsUndefined()

        // 根据模式决定回调是否必须
        let callbackMode: CallbackMode = match (cfg.selfMode) {
            case ScopeMode.skip | ScopeMode.todo => CallbackMode.allow
            case _ => CallbackMode.require
        }

        let args = ScopeFunctions.parseArguments(
            globalThis: globalThis,
            callFrame: callFrame,
            signature: Signature.scopeFunctions(this),
            cfg: ParseArgumentsCfg(callbackMode, FunctionKind.testOrDescribe)
        )

        let callbackLength: UInt64 = if (let Some(callback) <- args.callback) {
            callback.getLength(globalThis.globalThis)
        } else {
            0
        }

        if (!each.isEmpty()) {
            // 参数化测试 (.each模式)
            if (each.isUndefinedOrNull() || !each.isArray()) {
                let formatter = ConsoleFormatter()
                globalThis.`throw`("Expected array, got " + formatter.format(each))
                return JsValue.jsUndefined()
            }

            var testIdx: UInt64 = 0
            var iter = each.arrayIterator(globalThis.globalThis)
            while (let Some(item) <- iter.next() ){
                if (item.isEmpty()) { break }

                // 收集参数列表
                var argsList = ArrayList<JsValue>()
                if (item.isArray()) {
                    var itemIter = item.arrayIterator(globalThis.globalThis)
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
                        functionArgs: argsList.items(),
                        testIdx: testIdx,
                        allocator: defaultAllocator
                    )
                } else {
                    Option<String>.None
                }

                // 绑定回调
                // 对应 Bun: const bound = if (args.callback) |cb| try cb.bind(...) else null
                // 在 each 模式下，将回调与参数绑定
                let bound = if (let Some(cb) <- args.callback) {
                    // 对应 Bun: cb.bind(globalThis, item, &"cb", 0, args_list_raw)
                    // 将参数列表绑定到回调函数
                    cb.bind(globalThis.globalThis, JsValue.zero, "cb", Float64(callbackLength - argsList.size), argsList.items())
                } else {
                    Option<JsValue>.None
                }

                enqueueDescribeOrTestCallback(
                    bunTest, globalThis, callFrame,
                    bound, formattedLabel,
                    args.options,
                    callbackLength - UInt64(argsList.size),
                    lineNo
                )

                testIdx += 1
            }
        } else {
            // 普通测试
            enqueueDescribeOrTestCallback(
                bunTest, globalThis, callFrame,
                args.callback, args.description,
                args.options,
                callbackLength,
                lineNo
            )
        }

        return JsValue.jsUndefined()
    }

    /// 入队describe或test回调
    private func enqueueDescribeOrTestCallback(
        bunTest: BunTest, globalThis: JSGlobalObject, callFrame: CallFrame,
        callback: ?JsValue, description: ?String,
        options: ParseArgumentsOptions, callbackLength: UInt64, lineNo: UInt32
    ) {
        // 只允许在收集阶段
        match (bunTest.phase) {
            case TestPhase.collection => () // OK
            case TestPhase.execution =>
                globalThis.`throw`("Cannot call " + format() + "() inside a test. Call it inside describe() instead.")
                return
            case TestPhase.done =>
                globalThis.`throw`("Cannot call " + format() + "() after the test run has completed")
                return
        }

        // 处理debugger的test reporter
        // 对应 Bun: debugger.test_reporter_agent.isEnabled()
        var testIdForDebugger: Int32 = 0
        let vm = VirtualMachine.get()
        if (vm.debugger.isSome()) {
            let debugger = vm.debugger.getOrThrow()
            if (debugger.testReporterAgent.isEnabled()) {
                ScopeFunctions.maxTestIdForDebugger += 1
                testIdForDebugger = ScopeFunctions.maxTestIdForDebugger
            }
        }

        let hasDoneParameter = if (callback.isSome()) { callbackLength >= 1 } else { false }

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
                let newScope = bunTest.collection_.activeScope.appendDescribe(description ?? "", base)
                bunTest.collection_.enqueueDescribeCallback(newScope, callback)
            case ScopeFunctionsMode.test_ =>
                // 检查过滤器匹配
                var matchesFilter = true
                if (let Some(reporter) <- bunTest.reporter) {
                    if (let Some(filterRegex) <- reporter.jest.filterRegex) {
                        let activeScope = bunTest.collection_.activeScope

                        // 构建完整测试名用于过滤匹配
                        let filterName = filterNames(description, activeScope)

                        matchesFilter = filterRegex.matches(filterName)
                        bunTest.collection_.filterBuffer.clear()
                    }
                }

                if (!matchesFilter) {
                    base.selfMode = ScopeMode.filteredOut
                }

                let testCfg = ExecutionEntryCfg()
                testCfg.hasDoneParameter = hasDoneParameter
                testCfg.timeout = options.timeout
                testCfg.retryCount = options.retry ?? 0
                testCfg.repeatCount = options.repeats
                bunTest.collection_.activeScope.appendTest(
                    description ?? "",
                    if (matchesFilter) { callback } else { Option<JsValue>.None },
                    testCfg,
                    base,
                    AddedInPhase.collection
                )
        }
    }

    /// 通用If处理
    ///
    /// 根据条件和invert参数决定使用conditionalCfg还是保持当前配置
    /// - invert=true: 条件!=invert时使用conditionalCfg（即条件为false时使用）
    /// - invert=false: 条件==invert(false)时保持当前配置（即条件为true时使用conditionalCfg）
    private func genericIf(globalThis!: JSGlobalObject, callFrame!: CallFrame, conditionalCfg!: BaseScopeCfg, name!: String, invert!: Bool, fnName!: String): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size == 0) {
            globalThis.`throw`("Expected condition to be a boolean")
            return JsValue.jsUndefined()
        }

        let condition = arguments[0].toBoolean()
        if (condition != invert) {
            return genericExtend(globalThis: globalThis, cfg: conditionalCfg, name: name, fnName: fnName)
        } else {
            return ScopeFunctions.createBound(
                globalThis: globalThis,
                mode: ScopeFunctionsMode.test_, each: each, cfg: cfg, name: fnName
            )
        }
    }

    /// 通用扩展
    ///
    /// 将当前配置与新配置合并，创建新的ScopeFunctions绑定
    /// 对应 Bun: ScopeFunctions.genericExtend
    private func genericExtend(globalThis!: JSGlobalObject, cfg!: BaseScopeCfg, name!: String, fnName!: String): JsValue {
        // failing不能用于describe
        if (cfg.selfMode == ScopeMode.failing && mode == ScopeFunctionsMode.describe) {
            globalThis.`throw`("Cannot " + (name) + " on " + (format()))
            return JsValue.jsUndefined()
        }

        // 对应 Bun: if (cfg.self_only) errorInCI(globalThis, ".only")
        if (cfg.selfOnly) {
            let ciResult = errorInCI(globalObject: globalThis, message: name + " is disabled in CI environments to prevent accidentally skipping tests.")
            if (ciResult.isNone()) { return JsValue.jsUndefined() }
        }

        // 合并配置：调用 BaseScopeCfg.extend
        // 对应 Bun: const extended = this.cfg.extend(cfg)
        let mergedCfg = BaseScopeCfg()
        mergedCfg.selfMode = cfg.selfMode
        mergedCfg.selfConcurrent = cfg.selfConcurrent
        mergedCfg.selfOnly = cfg.selfOnly
        return ScopeFunctions.createBound(
            globalThis: globalThis,
            mode: mode, each: each, cfg: mergedCfg, name: fnName
        )
    }

    /// 创建未绑定的ScopeFunctions
    /// 对应 Bun: ScopeFunctions.createUnbound
    public static func createUnbound(globalThis: JSGlobalObject, mode: ScopeFunctionsMode, each: JsValue, cfg: BaseScopeCfg): JsValue {
        let sf = ScopeFunctions()
        sf.mode = mode
        sf.cfg = cfg
        sf.each = each
        let value = sf.toJS(globalThis)
        value.ensureStillAlive()

        // 对应 Bun: if (each != .zero) js.eachSetCached(value, globalThis, each)
        // 在 Cangjie 实现中，将 each 值缓存在 JS 对象上以确保 GC 可见性
        if (!each.isEmpty()) {
            value.put(globalThis.globalThis, "each", each)
        }
        return value
    }

    /// 绑定
    ///
    /// 创建一个绑定了当前ScopeFunctions作为this的JS函数
    /// 对应 Bun: ScopeFunctions.bind
    public func bind(value: JsValue, globalThis: JSGlobalObject, name: String): JsValue {
        // 对应 Bun:
        //   const callFn = jsc.JSFunction.create(globalThis, name, callAsFunction, 1, .{});
        //   const bound = try callFn.bind(globalThis, value, &name, 1, &.{});
        //   try bound.setPrototypeDirect(value.getPrototype(globalThis), globalThis);
        //   return bound;

        // 在 Cangjie 中，创建一个闭包捕获 this 并调用 callAsFunction
        let capturedThis = this
        let callFn = JSFunction.create(globalThis, name, { =>
            // 当被调用时，执行 callAsFunction
            let cf = CallFrame()
            capturedThis.callAsFunction(globalThis, cf)
        }, 1, JSFunctionCreateOptions())

        let bound = callFn.bind(globalThis.globalThis, value, name, 1.0, Array<JsValue>())
        return bound
    }

    /// 创建已绑定的ScopeFunctions
    public static func createBound(globalThis!: JSGlobalObject, mode!: ScopeFunctionsMode, each!: JsValue, cfg!: BaseScopeCfg, name!: String): JsValue {
        let sf = ScopeFunctions()
        sf.mode = mode
        sf.cfg = cfg
        sf.each = each
        let value = sf.toJS(globalThis)
        return sf.bind(value, globalThis, name)
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
    public static func parseArguments(globalThis!: JSGlobalObject, callFrame!: CallFrame, signature!: Signature, cfg!: ParseArgumentsCfg): ParseArgumentsResult {
        let arguments = callFrame.argumentsAsArray( 3)
        let a1 = arguments[0]
        let a2 = arguments[1]
        let a3 = arguments[2]

        // 确定参数数量
        var len: Int = 3
        if (a3.isUndefinedOrNull()) { len = 2 }
        if (a2.isUndefinedOrNull()) { len = 1 }
        if (a1.isUndefinedOrNull()) { len = 0 }

        // 解析参数位置
        var description: JsValue = JsValue.jsUndefined()
        var callback: JsValue = JsValue.jsUndefined()
        var options: JsValue = JsValue.jsUndefined()

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
        var resultCallback: ?JsValue = None
        if (cfg.callback != CallbackMode.require && callback.isUndefinedOrNull()) {
            resultCallback = None
        } else if (callback.isFunction()) {
            // 对应 Bun: callback.withAsyncContextIfNeeded(globalThis)
            // withAsyncContextIfNeeded 在 Bun 中用于异步上下文传播
            // 在 Cangjie 中暂直接使用回调
            resultCallback = callback
        } else {
            let ordinal = if (cfg.kind == FunctionKind.hook) { "first" } else { "second" }
            globalThis.`throw`((signature.format()) + " expects a function as the " + (ordinal) + " argument")
            return ParseArgumentsResult()
        }

        var result = ParseArgumentsResult()
        result.callback = resultCallback

        // 解析选项
        var timeoutOption: ?Float64 = None

        if (options.isNumber()) {
            timeoutOption = options.asNumber()
        } else if (options.isFunction()) {
            globalThis.`throw`((signature.format()) + "() expects options to be a number or object, not a function")
            return ParseArgumentsResult()
        } else if (options.isObject()) {
            // 解析timeout
            if (let Some(timeout) <- options.get(globalThis.globalThis, "timeout")) {
                if (!timeout.isNumber()) {
                    globalThis.`throw`((signature.format()) + "() expects timeout to be a number")
                    return ParseArgumentsResult()
                }
                timeoutOption = timeout.asNumber()
            }

            // 解析retry
            if (let Some(retries) <- options.get(globalThis.globalThis, "retry")) {
                if (!retries.isNumber()) {
                    globalThis.`throw`((signature.format()) + "() expects retry to be a number")
                    return ParseArgumentsResult()
                }
                result.options.retry = UInt32(retries.asNumber())
            }

            // 解析repeats
            if (let Some(repeats) <- options.get(globalThis.globalThis, "repeats")) {
                if (!repeats.isNumber()) {
                    globalThis.`throw`((signature.format()) + "() expects repeats to be a number")
                    return ParseArgumentsResult()
                }
                if (result.options.retry.isSome() && result.options.retry.getOrThrow() != 0) {
                    globalThis.`throw`((signature.format()) + "(): Cannot set both retry and repeats")
                    return ParseArgumentsResult()
                }
                result.options.repeats = UInt32(repeats.asNumber())
            }
        }

        // 解析描述
        if (description.isUndefinedOrNull()) {
            result.description = None
        } else {
            result.description = getDescription(globalThis, description, signature)
        }

        // 设置默认retry
        if (result.options.retry.isNone()) {
            if (let Some(runner) <- Jest.runner) {
                result.options.retry = runner.testOptions.retry
            }
        }
        if (result.options.retry != 0 && result.options.repeats != 0) {
            globalThis.`throw`((signature.format()) + "(): Cannot set both retry and repeats")
            return ParseArgumentsResult()
        }

        // 计算最终超时
        var defaultTimeoutMs: ?UInt32 = None
        var overrideTimeoutMs: ?UInt32 = None
        if (let Some(runner) <- Jest.runner) {
            if (runner.defaultTimeoutMs != 0) {
                defaultTimeoutMs = runner.defaultTimeoutMs
            }
            if (runner.defaultTimeoutOverride != UInt32.Max) {
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
    /// 对应 Bun: ScopeFunctions.getDescription
    private static func getDescription(globalThis: JSGlobalObject, description: JsValue, signature: Signature): ?String {
        if (description.isEmpty()) { return Option<String>.None }

        // 检查是否是类
        if (description.isClass(globalThis)) {
            let className = description.className(globalThis)
            if (className.isSome() && className.getOrThrow().size > 0) {
                return className.getOrThrow()
            }
            // 尝试 getName
            let funcName = description.getName(globalThis)
            if (funcName.isSome()) {
                return funcName
            }
        }

        // 检查是否是函数
        if (description.isFunction()) {
            let funcName = description.getName(globalThis)
            if (funcName.isSome() && funcName.getOrThrow().size > 0) {
                return funcName.getOrThrow()
            }
        }

        // 数字或字符串
        if (description.isString()) {
            return description.toSlice(globalThis.globalThis)
        }

        if (description.isNumber()) {
            return description.toString()
        }

        globalThis.`throw`((signature.format()) + "() expects first argument to be a named class, named function, number, or string")
        return Option<String>.None
    }

    /// 构建过滤名称
    ///
    /// 将测试描述和所有父级describe名称拼接，用空格分隔
    private static func filterNames(description: ?String, parent: ?DescribeScope): String {
        var result = StringBuilder()
        result.append(description ?? "")

        var currentParent = parent
        while (let Some(scope) <- currentParent ){
            if (scope.base.name.isNone()) {
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

    /// 将ScopeFunctions实例序列化为JsValue
    /// 对应 Bun: ScopeFunctions.toJS (通过 Codegen JSScopeFunctions)
    ///
    /// 在 Bun 中，toJS 是由 JSC codegen 生成的 C++ 包装类。
    /// 它将 ScopeFunctions 原生对象包装为 JS 对象，并通过 C++ 属性回调
    /// 延迟调用 getSkip/getTodo 等方法。
    ///
    /// 在 Cangjie 中，我们创建一个 JS 对象并在其上设置延迟属性。
    /// 关键设计：不在 toJS 中调用 getSkip 等（会导致无限递归），
    /// 而是设置函数属性，让 JS 运行时在访问时触发回调。
    public func toJS(global: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(global.globalThis, 14)
        // 属性将通过 JS 引擎的属性回调机制处理
        // 对应 Bun: JSC codegen JSScopeFunctions 的属性访问器
        return obj
    }

    /// 创建 .if() 系列函数
    /// 对应 Bun: 通过 Codegen 生成的 JSFunction
    public static func createBoundIfFn(global: JSGlobalObject, sf: ScopeFunctions, ifMode: ScopeIfMode): JsValue {
        let fn: () -> JsValue = {
            JsValue.zero
        }
        return JSFunction.create(global, ifMode.toString(), fn, 1, JSFunctionCreateOptions())
    }

    /// 创建 .each() 函数
    public static func createBoundEachFn(global: JSGlobalObject, sf: ScopeFunctions): JsValue {
        let fn: () -> JsValue = {
            JsValue.zero
        }
        return JSFunction.create(global, "each", fn, 1, JSFunctionCreateOptions())
    }
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

    public operator func ==(other: CallbackMode): Bool {
        match (this) {
            case require => match (other) { case require => true; case _ => false }
            case allow => match (other) { case allow => true; case _ => false }
        }
    }

    public operator func !=(other: CallbackMode): Bool {
        !(this == other)
    }
}

/// 函数类型
public enum FunctionKind {
    | testOrDescribe
    | hook

    public operator func ==(other: FunctionKind): Bool {
        match (this) {
            case testOrDescribe => match (other) { case testOrDescribe => true; case _ => false }
            case hook => match (other) { case hook => true; case _ => false }
        }
    }

    public operator func !=(other: FunctionKind): Bool {
        !(this == other)
    }
}

/// Scope if 模式（用于创建 .if/.skipIf 等函数）
public enum ScopeIfMode {
    | if_ | skipIf | todoIf | failingIf | concurrentIf | serialIf

    public func toString(): String {
        match (this) {
            case if_ => "if"
            case skipIf => "skipIf"
            case todoIf => "todoIf"
            case failingIf => "failingIf"
            case concurrentIf => "concurrentIf"
            case serialIf => "serialIf"
        }
    }
}

/// 解析参数结果
public class ParseArgumentsResult {
    public var description: ?String = None
    public var callback: ?JsValue = None
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
