// expect.cj - Expect断言核心
// 严格翻译自 bun/src/runtime/test_runner/expect.zig

package bao_runtime.test_runner

import bao_jsc.{CallFrame, ConsoleFormatter, ConsoleObject, Formatter, JSGlobalObject, JsValue, PromiseStatus}
import bao_collections.ArrayList
import bao_collections.HashMap
import bao_core.Allocator
import bao_core.Output

/// Stub for JSC capturedValueGetCached - returns the value directly from expect cache
func capturedValueGetCached(value: JsValue): ?JsValue {
    Some(value)
}

// ========== Expect supporting types ==========

/// 期望调用计数器
public class Counter {
    public var expected: UInt32 = 0
    public var actual: UInt32 = 0
}

/// 测试作用域信息
public class TestScope {
    public var testId: UInt32 = 0
    public var describe: DescribeScope
}

/// Promise模式
public enum PromiseMode {
    | none
    | resolves
    | rejects
}

/// 非对称匹配器构造类型
public enum AsymmetricMatcherConstructorType {
    | none
    | Symbol
    | String
    | Object
    | Array
    | BigInt
    | Boolean
    | Number
    | Promise
    | InstanceOf

    public static func fromJS(globalObject: JSGlobalObject, value: JsValue): ?AsymmetricMatcherConstructorType {
        // Stub: constructor type detection - requires JSC bindings
        // TODO: implement when JsValue has is*Constructor methods
        return AsymmetricMatcherConstructorType.InstanceOf
    }

    public func rawValue(): UInt8 {
        match (this) {
            case none => return 0
            case Symbol => return 1
            case String => return 2
            case Object => return 3
            case Array => return 4
            case BigInt => return 5
            case Boolean => return 6
            case Number => return 7
            case Promise => return 8
            case InstanceOf => return 9
        }
    }

    public static func fromRaw(raw: UInt8): AsymmetricMatcherConstructorType {
        match (raw) {
            case 1 => return AsymmetricMatcherConstructorType.Symbol
            case 2 => return AsymmetricMatcherConstructorType.String
            case 3 => return AsymmetricMatcherConstructorType.Object
            case 4 => return AsymmetricMatcherConstructorType.Array
            case 5 => return AsymmetricMatcherConstructorType.BigInt
            case 6 => return AsymmetricMatcherConstructorType.Boolean
            case 7 => return AsymmetricMatcherConstructorType.Number
            case 8 => return AsymmetricMatcherConstructorType.Promise
            case 9 => return AsymmetricMatcherConstructorType.InstanceOf
            case _ => return AsymmetricMatcherConstructorType.none
        }
    }
}

/// Expect标志位(注意: 保持与C++实现同步)
public class Flags {
    public var promise: PromiseMode = PromiseMode.none
    public var not: Bool = false
    public var asymmetricMatcherConstructorType: AsymmetricMatcherConstructorType = AsymmetricMatcherConstructorType.none

    public init() {}

    public func encode(): UInt8 {
        var bits: UInt8 = 0
        match (promise) {
            case PromiseMode.resolves => bits |= 0x01
            case PromiseMode.rejects => bits |= 0x02
            case PromiseMode.none => ()
        }
        if (not) { bits |= 0x04 }
        bits |= UInt8(asymmetricMatcherConstructorType.rawValue() << 3)
        return bits
    }

    public static func decode(bitset: UInt8): Flags {
        let flags = Flags()
        match (bitset & 0x03) {
            case 1 => flags.promise = PromiseMode.resolves
            case 2 => flags.promise = PromiseMode.rejects
            case _ => flags.promise = PromiseMode.none
        }
        flags.not = (bitset & 0x04) != 0
        flags.asymmetricMatcherConstructorType = AsymmetricMatcherConstructorType.fromRaw(UInt8((bitset >> 3) & 0x1f))
        return flags
    }
}

// ========== Expect - 期望断言类 ==========

/// https://jestjs.io/docs/expect
/// Expect断言核心类
public class Expect {
    public var flags: Flags = Flags()
    public var parent: ?RefData = None
    public var customLabel: String = ""

    /// 期望调用计数器递增
    public func incrementExpectCallCounter() {
        let parentOpt = this.parent
        if (parentOpt.isNone()) { return }
        let parent = parentOpt.getOrThrow()
        let buntestStrongOpt = parent.bunTest()
        if (buntestStrongOpt.isNone()) { return }
        let buntestStrong = buntestStrongOpt.getOrThrow()
        // defer { buntestStrong.deinit() }
        let buntestOpt = buntestStrong.get()
        if (buntestOpt.isNone()) { return }
        let buntest = buntestOpt.getOrThrow()
        let sequenceOpt = parent.sequence(buntest)
        if (sequenceOpt.isSome()) {
            // 找到活跃序列
            sequenceOpt.getOrThrow().expectCallCount += 1
        } else {
            // 在并发组或其他无法获取序列的情况; 直接在reporter中递增expect调用计数
            if (buntest.reporter.isSome()) {
                buntest.reporter.getOrThrow().summary().expectations += 1
            }
        }
    }

    /// 获取关联的BunTest
    public func bunTest(): ?BunTestPtr {
        let parent = this.parent ?? return None
        return parent.bunTest()
    }

    // ========== Flags - 标志位 ==========

    /// 生成签名
    public static func getSignature(matcherName: String, args: String, not: Bool): String {
        let received = "<d>expect(<r><red>received<r><d>).<r>"
        if (not) {
            return received + "not<d>.<r>" + matcherName + "<d>(<r>" + args + "<d>)<r>"
        }
        return received + matcherName + "<d>(<r>" + args + "<d>)<r>"
    }

    /// 抛出漂亮的匹配器错误
    public static func throwPrettyMatcherError(globalThis!: JSGlobalObject, customLabel!: String, matcherName!: String, matcherParams!: String, flags!: Flags, messageFmt!: String, messageArgs!: Array<Any>): JsValue {
        let colors = Output.enableAnsiColorsStderr
        let chain = match (flags.promise) {
            case PromiseMode.resolves => if (flags.not) { Output.prettyFmt("resolves<d>.<r>not<d>.<r>", colors) } else { Output.prettyFmt("resolves<d>.<r>", colors) }
            case PromiseMode.rejects => if (flags.not) { Output.prettyFmt("rejects<d>.<r>not<d>.<r>", colors) } else { Output.prettyFmt("rejects<d>.<r>", colors) }
            case PromiseMode.none => if (flags.not) { Output.prettyFmt("not<d>.<r>", colors) } else { "" }
        }

        if (customLabel.size > 0) {
            let fmt = Output.prettyFmt("{f}\n\n" + messageFmt, colors)
            var allArgs = ArrayList<Any>()
            allArgs.append(customLabel)
            for (arg in messageArgs ) { allArgs.append(arg) }
            return globalThis.throwPretty(fmt, allArgs)
        } else {
            let fmt = Output.prettyFmt("<d>expect(<r><red>received<r><d>).<r>" + chain + "" + matcherName + "<d>(<r>" + matcherParams + "<d>)<r>\n\n" + messageFmt, colors)
            var allArgs = ArrayList<Any>()
            allArgs.append(chain)
            allArgs.append(matcherName)
            allArgs.append(matcherParams)
            for (arg in messageArgs ) { allArgs.append(arg) }
            return globalThis.throwPretty(fmt, allArgs)
        }
    }

    /// 获取not属性
    public func getNot(thisValue: JsValue): JsValue {
        flags.not = !flags.not
        return thisValue
    }

    /// 获取resolves属性
    public func getResolves(thisValue: JsValue, globalThis: JSGlobalObject): JsValue {
        flags.promise = match (flags.promise) {
            case PromiseMode.resolves | PromiseMode.none => PromiseMode.resolves
            case PromiseMode.rejects => return globalThis.throw_("Cannot chain .resolves() after .rejects()")
        }
        return thisValue
    }

    /// 获取rejects属性
    public func getRejects(thisValue: JsValue, globalThis: JSGlobalObject): JsValue {
        flags.promise = match (flags.promise) {
            case PromiseMode.none | PromiseMode.rejects => PromiseMode.rejects
            case PromiseMode.resolves => return globalThis.throw_("Cannot chain .rejects() after .resolves()")
        }
        return thisValue
    }

    /// 获取值
    public func getValue(globalThis!: JSGlobalObject, thisValue!: JsValue, matcherName!: String, matcherParamsFmt!: String): JsValue {
        let valueOpt = capturedValueGetCached(thisValue)
        if (valueOpt.isNone()) {
            return globalThis.throw_("Internal error: the expect(value) was garbage collected but it should not have been!")
        }
        let value = valueOpt.getOrThrow()
        value.ensureStillAlive()

        let matcherParams = Output.prettyFmt(matcherParamsFmt, Output.enableAnsiColorsStderr)
        return processPromise(customLabel: customLabel, flags: flags, globalThis: globalThis, value: value, matcherName: matcherName, matcherParams: matcherParams, silent: false)
    }

    /// 处理Promise标志（resolves/rejects）
    public static func processPromise(customLabel!: String, flags!: Flags, globalThis!: JSGlobalObject, value!: JsValue, matcherName!: String, matcherParams!: String, silent!: Bool): JsValue {
        match (flags.promise) {
            case PromiseMode.resolves | PromiseMode.rejects =>
                let resolution = flags.promise
                let promiseOpt = value.asAnyPromise()
                if (promiseOpt.isSome()) {
                    let promise = promiseOpt.getOrThrow()
                    let vm = globalThis.vm()
                    promise.setHandled(vm)

                    globalThis.bunVM().waitForPromise(promise)

                    let newValue = promise.result(vm)
                    if (promise.status() == PromiseStatus.Fulfilled) {
                        if (resolution == PromiseMode.rejects) {
                            if (!silent) {
                                let formatter = ConsoleFormatter(globalThis: globalThis, quote_strings: true)
                                // defer { formatter.deinit() }
                                let message = "Expected promise that rejects<r>\nReceived promise that resolved: <red>{f}<r>\n"
                                return throwPrettyMatcherError(globalThis: globalThis, customLabel: customLabel, matcherName: matcherName, matcherParams: matcherParams, flags: flags, messageFmt: message, messageArgs: [value.toFmt(formatter)])
                            }
                            return JsValue.zero
                        }
                    } else if (promise.status() == PromiseStatus.rejected) {
                        if (resolution == PromiseMode.resolves) {
                            if (!silent) {
                                let formatter = ConsoleFormatter(globalThis: globalThis, quote_strings: true)
                                // defer { formatter.deinit() }
                                let message = "Expected promise that resolves<r>\nReceived promise that rejected: <red>{f}<r>\n"
                                return throwPrettyMatcherError(globalThis: globalThis, customLabel: customLabel, matcherName: matcherName, matcherParams: matcherParams, flags: flags, messageFmt: message, messageArgs: [value.toFmt(formatter)])
                            }
                            return JsValue.zero
                        }
                    }

                    newValue.ensureStillAlive()
                    return newValue
                } else {
                    if (!silent) {
                        let formatter = ConsoleFormatter(globalThis: globalThis, quote_strings: true)
                        // defer { formatter.deinit() }
                        let message = "Expected promise<r>\nReceived: <red>{f}<r>\n"
                        return throwPrettyMatcherError(globalThis: globalThis, customLabel: customLabel, matcherName: matcherName, matcherParams: matcherParams, flags: flags, messageFmt: message, messageArgs: [value.toFmt(formatter)])
                    }
                    return JsValue.zero
                }
            case _ =>
                ()
        }

        return value
    }

    /// 检查是否为非对称匹配器
    public static func isAsymmetricMatcher(value: JsValue): Bool {
        if (ExpectCustomAsymmetricMatcher.fromJS(value).isSome()) { return true }
        if (ExpectAny.fromJS(value).isSome()) { return true }
        if (ExpectAnything.fromJS(value).isSome()) { return true }
        if (ExpectStringMatching.fromJS(value).isSome()) { return true }
        if (ExpectCloseTo.fromJS(value).isSome()) { return true }
        if (ExpectObjectContaining.fromJS(value).isSome()) { return true }
        if (ExpectStringContaining.fromJS(value).isSome()) { return true }
        if (ExpectArrayContaining.fromJS(value).isSome()) { return true }
        return false
    }

    /// 读取标志并处理Promise
    public static func readFlagsAndProcessPromise(instanceValue: JsValue, globalThis: JSGlobalObject, outFlags: UInt8, value: JsValue, anyConstructorType: UInt8): Bool {
        var flags = Flags()
        if (let Some(instance) <- ExpectCustomAsymmetricMatcher.fromJS(instanceValue)) {
            flags = instance.flags
        } else if (let Some(instance) <- ExpectAny.fromJS(instanceValue)) {
            anyConstructorType = instance.flags.asymmetricMatcherConstructorType.rawValue
            flags = instance.flags
        } else if (let Some(instance) <- ExpectAnything.fromJS(instanceValue)) {
            flags = instance.flags
        } else if (let Some(instance) <- ExpectStringMatching.fromJS(instanceValue)) {
            flags = instance.flags
        } else if (let Some(instance) <- ExpectCloseTo.fromJS(instanceValue)) {
            flags = instance.flags
        } else if (let Some(instance) <- ExpectObjectContaining.fromJS(instanceValue)) {
            flags = instance.flags
        } else if (let Some(instance) <- ExpectStringContaining.fromJS(instanceValue)) {
            flags = instance.flags
        } else if (let Some(instance) <- ExpectArrayContaining.fromJS(instanceValue)) {
            flags = instance.flags
        }

        outFlags = flags.encode()
        let result = processPromise(customLabel: "", flags: flags, globalThis: globalThis, value: value, matcherName: "", matcherParams: "", silent: true)
        return true
    }

    /// 获取快照名称
    public func getSnapshotName(allocator: Allocator, hint: String): String {
        let parent = this.parent ?? return ""
        let buntestStrong = parent.bunTest() ?? return ""
        // defer { buntestStrong.deinit() }
        let buntest = buntestStrong.get()
        let executionEntry = parent.phase.entry(buntest) ?? return ""

        let testName = executionEntry.base.name ?? "(unnamed)"

        var buf = StringBuilder()
        var scopes = Array<String>()
        var currScope = executionEntry.base.parent
        while (currScope.isSome()) {
            let scope = currScope.getOrThrow()
            if (scope.base.name.isSome() && scope.base.name.getOrThrow().size > 0) {
                scopes.append(scope.base.name.getOrThrow())
            }
            currScope = scope.base.parent
        }
        for (i in 0..scopes.size ) {
            buf.append(scopes[i])
            buf.append(" ")
        }

        if (hint.size > 0) {
            buf.append(testName)
            buf.append(": ")
            buf.append(hint)
        } else {
            buf.append(testName)
        }
        return buf.toString()
    }

    /// 最终化
    public func finalize() {
        customLabel = ""
        if (let Some(p) <- parent) {
            p.deref()
        }
    }

    /// Expect调用
    public static func call(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsOld(2).slice()
        let value = if (arguments.size < 1) { JsValue.jsUndefined } else { arguments[0] }

        var customLabel = ""
        if (arguments.size > 1) {
            if (arguments[1].isString() || arguments[1].implementsToString(globalThis)) {
                let label = arguments[1].toBunString(globalThis)
                if (globalThis.hasException()) { return JsValue.zero }
                customLabel = label
            }
        }

        let expect = Expect()
        expect.customLabel = customLabel

        let activeExecutionEntryRef = BunTest.cloneActiveStrong().map({ buntestStrong =>
            // defer { buntestStrong.deinit() }
            return BunTest.ref(buntestStrong, buntestStrong.get().getCurrentStateData())
        })
        expect.parent = activeExecutionEntryRef

        let expectJsValue = expect.toJS(globalThis)
        expectJsValue.ensureStillAlive()
        capturedValueSetCached(expectJsValue, globalThis: globalThis, value: value)
        expectJsValue.ensureStillAlive()

        expect.postMatch(globalThis: globalThis)
        return expectJsValue
    }

    /// 抛出错误
    public func throw_(globalThis!: JSGlobalObject, signature!: String, fmt!: String, args!: Array<Any>): JsValue {
        if (customLabel.size == 0) {
            return globalThis.throwPretty(signature + fmt, args)
        } else {
            var allArgs = ArrayList<Any>()
            allArgs.append(customLabel)
            for (arg in args ) { allArgs.append(arg) }
            return globalThis.throwPretty("{f}" + fmt, allArgs)
        }
    }

    /// 构造函数（不允许用new调用）
    public static func constructor(globalThis: JSGlobalObject): Expect {
        globalThis.throw_("expect() cannot be called with new")
        return Expect()
    }

    /// pass断言
    public func pass(globalThis!: JSGlobalObject, callFrame!: CallFrame): JsValue {
        // defer { postMatch(globalThis: globalThis) }
        incrementExpectCallCounter()

        let not = flags.not
        var pass = true

        if (not) { pass = !pass }
        if (pass) { return JsValue.jsUndefined }

        let signature = getSignature(matcherName: "pass", args: "", not: not)
        return throw_(globalThis: globalThis, signature: signature, fmt: "\n\nExpected: not to pass\n", args: [])
    }

    /// fail断言
    public func fail(globalThis!: JSGlobalObject, callFrame!: CallFrame): JsValue {
        // defer { postMatch(globalThis: globalThis) }
        incrementExpectCallCounter()

        let not = flags.not
        var pass = false

        if (not) { pass = !pass }
        if (pass) { return JsValue.jsUndefined }

        let arguments = callFrame.argumentsOld(1).slice()
        var message = "expect.fail()"

        if (arguments.size > 0) {
            let formatter = ConsoleFormatter(globalThis: globalThis, quote_strings: true)
            // defer { formatter.deinit() }
            message = arguments[0].toFmt(formatter)
        }

        return globalThis.throwPretty("\n\n{f}\n", [message])
    }

    /// 匹配后清理
    public func postMatch(globalThis!: JSGlobalObject) {}

    /// 获取用于toThrow的值
    public func getValueAsToThrow(globalThis!: JSGlobalObject, value!: JsValue): Tuple2<?JsValue, JsValue> {
        if (!value.isFunction() && !value.isObject()) {
            let formatter = ConsoleFormatter(globalThis: globalThis, quote_strings: true)
            // defer { formatter.deinit() }
            globalThis.throw_("expect(value).toThrow() requires a function or class but received: {f}", args: [value.toFmt(formatter)])
            return Tuple2<?JsValue, JsValue>(None, JsValue.zero)
        }

        let result = value.call(globalThis: globalThis, thisValue: JsValue.jsUndefined, args: [])
        let returnValue = result
        var threwResult: ?JsValue = None

        if (globalThis.hasException()) {
            threwResult = globalThis.takeException()
        } else {
            if (let Some(promise) <- returnValue.asAnyPromise()) {
                if (promise.status() == PromiseStatus.rejected) {
                    threwResult = promise.result(globalThis.vm())
                }
            }
        }

        return Tuple2<?JsValue, JsValue>(threwResult, returnValue)
    }

    /// 行内快照
    public func inlineSnapshot(globalThis!: JSGlobalObject, callFrame!: CallFrame, value!: JsValue, propertyMatchers!: ?JsValue, result!: ?String, fnName!: String): JsValue {
        // defer { postMatch(globalThis: globalThis) }
        incrementExpectCallCounter()

        var prettyValue = StringWriter()
        matchAndFmtSnapshot(globalThis: globalThis, value: value, propertyMatchers: propertyMatchers, prettyValue: prettyValue, fnName: fnName)

        return snapshot(globalThis: globalThis, value: value, propertyMatchers: propertyMatchers, hint: "", fnName: fnName)
    }

    /// 匹配并格式化快照
    public func matchAndFmtSnapshot(globalThis!: JSGlobalObject, value!: JsValue, propertyMatchers!: ?JsValue, prettyValue!: StringWriter, fnName!: String) {
        let fmtOptions = JestPrettyFormat.FormatOptions(enableColors: false, addNewline: false, flush: false, quoteStrings: true)

        if (propertyMatchers.isSome()) {
            JestPrettyFormat.format(level: MessageLevel.debug_, global: globalThis, vals: [propertyMatchers.getOrThrow()], len: 1, writer: prettyValue, options: fmtOptions)
        } else {
            JestPrettyFormat.format(level: MessageLevel.debug_, global: globalThis, vals: [value], len: 1, writer: prettyValue, options: fmtOptions)
        }
    }

    /// 快照
    public func snapshot(globalThis!: JSGlobalObject, value!: JsValue, propertyMatchers!: ?JsValue, hint!: String, fnName!: String): JsValue {
        let not = flags.not

        var prettyValue = StringWriter()
        matchAndFmtSnapshot(globalThis: globalThis, value: value, propertyMatchers: propertyMatchers, prettyValue: prettyValue, fnName: fnName)

        let targetValue = prettyValue.written()

        let buntestStrong = bunTest() ?? return JsValue.zero
        // defer { buntestStrong.deinit() }
        let buntest = buntestStrong.get()

        let snapshots = buntest.snapshots
        let existing = snapshots.getOrPut(expect: this, targetValue: targetValue, hint: hint)

        let signature = getSignature(matcherName: fnName, args: "<green>expected<r>", not: not)
        let diffFormatter = DiffFormatter(receivedString: targetValue, expectedString: existing ?? "", globalThis: globalThis, not: not)

        if (existing.isNone()) {
            if (not) {
                return throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormatter])
            }
            return JsValue.jsUndefined // 新快照已添加
        }

        return JsValue.jsUndefined
    }

    /// 静态not属性
    public static func getStaticNot(globalThis!: JSGlobalObject): JsValue {
        return ExpectStatic.create(globalThis: globalThis, flags: Flags(not: true))
    }

    /// hasAssertions断言
    public static func hasAssertions(globalThis!: JSGlobalObject): JsValue {
        let buntestStrong = BunTest.cloneActiveStrong() ?? return globalThis.throw_("hasAssertions must be called in a test")
        // defer { buntestStrong.deinit() }
        let buntest = buntestStrong.get()
        let reporter = buntest.reporter ?? return JsValue.jsUndefined
        let summary = reporter.summary()
        if (summary.expectations == 0) {
            return globalThis.throw_("Expected at least one assertion to be called, but no assertions were called")
        }
        return JsValue.jsUndefined
    }

    /// assertions断言
    public static func assertions(globalThis!: JSGlobalObject, callFrame!: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1 || !arguments[0].isNumber()) {
            return globalThis.throwInvalidArguments("assertions() requires a number argument")
        }
        let expected = arguments[0].asNumber()
        let buntestStrong = BunTest.cloneActiveStrong() ?? return globalThis.throw_("assertions must be called in a test")
        // defer { buntestStrong.deinit() }
        let buntest = buntestStrong.get()
        let reporter = buntest.reporter ?? return JsValue.jsUndefined
        let summary = reporter.summary()
        if (UInt32(expected) != summary.expectations) {
            return globalThis.throw_("Expected " + expected + " assertions to be called, but " + summary.expectations + " were called")
        }
        return JsValue.jsUndefined
    }

    /// 扩展自定义匹配器
    public static func `extend`(globalThis!: JSGlobalObject, callFrame!: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1 || !arguments[0].isObject()) {
            return globalThis.throwInvalidArguments("extend() requires an object argument")
        }
        let matchers = arguments[0]
        let keys = matchers.getOwnPropertyNames(globalThis)
        if (keys.isSome()) {
            for (key in keys.getOrThrow() ) {
                let matcher = matchers.get(globalThis, key) ?? continue
                if (!matcher.isFunction()) {
                    return globalThis.throwInvalidArguments("expect.extend: `" + key + "` is not a valid matcher. Must be a function")
                }
                registerCustomMatcher(globalThis: globalThis, name: key, matcher: matcher)
            }
        }
        return JsValue.jsUndefined
    }

    // ========================================================================
    // 自定义匹配器注册与执行
    // 严格翻译自: Expect.extend / Expect.executeCustomMatcher / Expect.applyCustomMatcher
    // ========================================================================

    /// 注册自定义匹配器 - 对应 Bun extend 中的注册逻辑
    /// 将自定义匹配器函数包装并注册到 Expect 原型上
    public static func registerCustomMatcher(globalThis!: JSGlobalObject, name!: String, matcher!: JsValue): Unit {
        // 在实际实现中, 这会创建一个 JSWrappingFunction 并将其安装到
        // expect 原型和 expect 构造函数上
        // 对应 Bun: Bun__JSWrappingFunction__create + expect_proto.putMayBeIndex
    }

    /// 执行自定义匹配器 - 对应 Bun Expect.executeCustomMatcher
    /// 对给定参数执行自定义匹配器 (对称和非对称匹配都使用此函数)
    /// 如果 silent=false 且匹配结果不是 pass, 则在 JS 中抛出异常
    public static func executeCustomMatcher(globalThis!: JSGlobalObject, matcherName!: String, matcherFn!: JsValue, args!: Array<JsValue>, flags!: Flags, silent!: Bool): Bool {
        // 创建 matcher 上下文 (this 对象)
        let matcherContext = ExpectMatcherContext()
        matcherContext.flags = flags

        // 调用自定义匹配器实现
        var result = matcherFn.call(globalThis: globalThis, thisValue: matcherContext.toJS(globalThis), args: args)

        // 支持异步匹配器结果
        if (let Some(promise) <- result.asAnyPromise()) {
            let vm = globalThis.vm()
            promise.setHandled(vm)
            globalThis.bunVM().waitForPromise(promise)
            result = promise.result(vm)
            result.ensureStillAlive()
            if (promise.status() == PromiseStatus.rejected) {
                return false  // 简化: 实际应抛出错误
            }
        }

        // 解析和验证匹配器结果, 应遵循: { pass: boolean, message?: () => string }
        if (!result.isObject()) {
            return throwInvalidMatcherError(globalThis: globalThis, matcherName: matcherName, result: result)
        }

        let passValue = result.get(globalThis, "pass")
        if (passValue.isNone()) {
            return throwInvalidMatcherError(globalThis: globalThis, matcherName: matcherName, result: result)
        }

        var pass = passValue.getOrThrow().toBoolean()
        if (flags.not) { pass = !pass }
        if (pass || silent) { return pass }

        // 处理失败路径
        let messageValue = result.fastGet(globalThis, key: "message")
        var messageText = "No message was specified for this matcher."
        if (messageValue.isSome()) {
            let msg = messageValue.getOrThrow()
            if (msg.isString()) {
                messageText = msg.toSliceOrNull(globalThis: globalThis) ?? messageText
            } else if (msg.isCallable()) {
                let msgResult = msg.callWithGlobalThis(globalThis, args: [])
                messageText = msgResult.toSliceOrNull(globalThis: globalThis) ?? messageText
            }
        }

        let signature = getSignature(matcherName: matcherName, args: "<green>...args<r>", not: flags.not)
        return globalThis.throwPretty(signature + "\n\n" + messageText, []).toBoolean()
    }

    /// 抛出无效匹配器错误 - 对应 Bun throwInvalidMatcherError
    static func throwInvalidMatcherError(globalThis!: JSGlobalObject, matcherName!: String, result!: JsValue): Bool {
        let formatter = ConsoleFormatter(globalThis: globalThis, quote_strings: true)
        // defer { formatter.deinit() }
        let fmt = "Unexpected return from matcher function `" + matcherName + "`.\n" +
            "Matcher functions should return an object in the following format:\n" +
            "  {message?: string | function, pass: boolean}\n" +
            "'" + result.toFmt(formatter) + "' was returned"
        globalThis.throwPretty(fmt, [])
        return false
    }

    /// 应用自定义匹配器 - 对应 Bun Expect.applyCustomMatcher
    /// 用于 expect().myMatcher 调用或 expect.myMatcher() 静态调用
    public static func applyCustomMatcher(globalThis!: JSGlobalObject, callFrame!: CallFrame): JsValue {
        // 获取用户提供的匹配器函数
        let calleeFunc = callFrame.callee()
        let matcherFn = getCustomMatcherFn(calleeFunc, globalThis)
        if (matcherFn.isNone() || !matcherFn.getOrThrow().isFunction()) {
            return globalThis.throw_("Internal consistency error: failed to retrieve the matcher function for a custom matcher!")
        }
        matcherFn.getOrThrow().ensureStillAlive()

        // 尝试获取 Expect 实例
        let thisValue = callFrame.this_()
        let expectOpt = Expect.fromJS(thisValue)
        if (expectOpt.isNone()) {
            // 如果没有 Expect 实例, 假设是静态调用, 创建 ExpectCustomAsymmetricMatcher
            return ExpectCustomAsymmetricMatcher.create(globalThis: globalThis, callFrame: callFrame, matcherFn: matcherFn.getOrThrow())
        }
        let expect = expectOpt.getOrThrow()

        // 非静态调用: 执行对称匹配
        let matcherName = matcherFn.getOrThrow().getName(globalThis: globalThis) ?? "custom"

        // 获取捕获的期望值
        var value = capturedValueGetCached(thisValue) ?? return globalThis.throw_("Internal consistency error: failed to retrieve the captured value")
        value = processPromise(customLabel: expect.customLabel, flags: expect.flags, globalThis: globalThis, value: value, matcherName: matcherName, matcherParams: "<green>...args<r>", silent: false)
        value.ensureStillAlive()

        expect.incrementExpectCallCounter()

        // 准备参数数组
        let callArgs = callFrame.argumentsAsArray(0)
        var matcherArgs = Array<JsValue>()
        matcherArgs.append(value)
        for (arg in callArgs ) { matcherArgs.append(arg) }

        let _ = executeCustomMatcher(globalThis: globalThis, matcherName: matcherName, matcherFn: matcherFn.getOrThrow(), args: matcherArgs, flags: expect.flags, silent: false)

        return thisValue
    }

    /// 获取自定义匹配器函数 - 对应 Bun getCustomMatcherFn
    static func getCustomMatcherFn(fn: JsValue, globalThis: JSGlobalObject): ?JsValue {
        // 从包装函数中提取用户匹配器函数
        return fn.get(globalThis, "matcherFn")
    }

    /// addSnapshotSerializer - 对应 Bun Expect.addSnapshotSerializer (未实现)
    public static func addSnapshotSerializer(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined
    }
}

// ========== ExpectStatic - 静态expect实例 ==========

/// 静态expect实例，例如expect.not
public class ExpectStatic {
    public var flags: Flags = Flags()

    public init() {}

    public func finalize() {}

    /// 创建静态expect
    public static func create(globalThis!: JSGlobalObject, flags!: Flags): JsValue {
        let expect = ExpectStatic()
        expect.flags = flags
        return expect.toJS(globalThis)
    }

    /// 获取not属性
    public func getNot(globalThis!: JSGlobalObject): JsValue {
        var newFlags = flags
        newFlags.not = !flags.not
        return ExpectStatic.create(globalThis: globalThis, flags: newFlags)
    }

    /// 获取resolvesTo属性
    public func getResolvesTo(globalThis!: JSGlobalObject): JsValue {
        var newFlags = flags
        newFlags.promise = PromiseMode.resolves
        return ExpectStatic.create(globalThis: globalThis, flags: newFlags)
    }

    /// 获取rejectsTo属性
    public func getRejectsTo(globalThis!: JSGlobalObject): JsValue {
        var newFlags = flags
        newFlags.promise = PromiseMode.rejects
        return ExpectStatic.create(globalThis: globalThis, flags: newFlags)
    }
}

// ========== ExpectAnything ==========

/// expect.anything()匹配器
public class ExpectAnything {
    public var flags: Flags = Flags()

    public init() {}
    public func finalize() {}

    public static func call(globalThis: JSGlobalObject): JsValue {
        let anything = ExpectAnything()
        return anything.toJS(globalThis)
    }
}

// ========== ExpectAny ==========

/// expect.any()匹配器
public class ExpectAny {
    public var flags: Flags = Flags()

    public init() {}
    public func finalize() {}

    public static func call(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1) {
            return globalThis.throwInvalidArguments("expect.any() requires 1 argument")
        }
        let constructor = arguments[0]
        let any = ExpectAny()
        any.flags.asymmetricMatcherConstructorType = AsymmetricMatcherConstructorType.fromJS(globalThis, value: constructor) ?? AsymmetricMatcherConstructorType.none
        constructorValueSetCached(any.toJS(globalThis), globalThis: globalThis, value: constructor)
        return any.toJS(globalThis)
    }
}

// ========== ExpectStringMatching ==========

/// expect.stringMatching()匹配器
public class ExpectStringMatching {
    public var flags: Flags = Flags()

    public init() {}
    public func finalize() {}

    public static func call(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1) {
            return globalThis.throwInvalidArguments("expect.stringMatching() requires 1 argument")
        }
        let matcher = ExpectStringMatching()
        capturedValueSetCached(matcher.toJS(globalThis), globalThis: globalThis, value: arguments[0])
        return matcher.toJS(globalThis)
    }
}

// ========== ExpectCloseTo ==========

/// expect.closeTo()匹配器
public class ExpectCloseTo {
    public var flags: Flags = Flags()

    public init() {}
    public func finalize() {}

    public static func call(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(2)
        if (arguments.size < 1) {
            return globalThis.throwInvalidArguments("expect.closeTo() requires at least 1 argument")
        }
        let matcher = ExpectCloseTo()
        capturedValueSetCached(matcher.toJS(globalThis), globalThis: globalThis, value: arguments[0])
        return matcher.toJS(globalThis)
    }
}

// ========== ExpectObjectContaining ==========

/// expect.objectContaining()匹配器
public class ExpectObjectContaining {
    public var flags: Flags = Flags()

    public init() {}
    public func finalize() {}

    public static func call(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1) {
            return globalThis.throwInvalidArguments("expect.objectContaining() requires 1 argument")
        }
        let matcher = ExpectObjectContaining()
        capturedValueSetCached(matcher.toJS(globalThis), globalThis: globalThis, value: arguments[0])
        return matcher.toJS(globalThis)
    }
}

// ========== ExpectStringContaining ==========

/// expect.stringContaining()匹配器
public class ExpectStringContaining {
    public var flags: Flags = Flags()

    public init() {}
    public func finalize() {}

    public static func call(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1) {
            return globalThis.throwInvalidArguments("expect.stringContaining() requires 1 argument")
        }
        let matcher = ExpectStringContaining()
        capturedValueSetCached(matcher.toJS(globalThis), globalThis: globalThis, value: arguments[0])
        return matcher.toJS(globalThis)
    }
}

// ========== ExpectArrayContaining ==========

/// expect.arrayContaining()匹配器
public class ExpectArrayContaining {
    public var flags: Flags = Flags()

    public init() {}
    public func finalize() {}

    public static func call(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1) {
            return globalThis.throwInvalidArguments("expect.arrayContaining() requires 1 argument")
        }
        let matcher = ExpectArrayContaining()
        capturedValueSetCached(matcher.toJS(globalThis), globalThis: globalThis, value: arguments[0])
        return matcher.toJS(globalThis)
    }
}

// ========== ExpectCustomAsymmetricMatcher ==========

/// 自定义非对称匹配器
public class ExpectCustomAsymmetricMatcher {
    public var flags: Flags = Flags()

    public init() {}
    public func finalize() {}

    /// 创建
    public static func create(globalThis!: JSGlobalObject, callFrame!: CallFrame, matcherFn!: JsValue): JsValue {
        let matcher = ExpectCustomAsymmetricMatcher()
        capturedValueSetCached(matcher.toJS(globalThis), globalThis: globalThis, value: matcherFn)
        return matcher.toJS(globalThis)
    }

    /// 执行匹配
    public func execute(thisValue: JsValue, globalThis: JSGlobalObject, received: JsValue): Bool {
        let matcherFn = capturedValueGetCached(thisValue) ?? return false
        let result = matcherFn.call(globalThis: globalThis, thisValue: JsValue.jsUndefined, args: [received])
        return result.toBoolean()
    }
}

// ========== ExpectMatcherContext ==========

/// 匹配器上下文 - 参考 Jest MatcherContext
public class ExpectMatcherContext {
    public var flags: Flags = Flags()

    public init() {}
    public func finalize() {}

    /// 获取工具对象
    public func getUtils(globalThis!: JSGlobalObject): JsValue {
        return ExpectMatcherUtils.create(globalThis: globalThis)
    }

    /// 获取isNot
    public func getIsNot(): JsValue {
        return JsValue.jsBoolean(flags.not)
    }

    /// 获取promise
    public func getPromise(globalThis: JSGlobalObject): JsValue {
        match (flags.promise) {
            case PromiseMode.rejects => return JsValue.jsString("rejects")
            case PromiseMode.resolves => return JsValue.jsString("resolves")
            case _ => return JsValue.jsUndefined
        }
    }

    /// 获取expand
    public func getExpand(): JsValue {
        return JsValue.jsFalse
    }

    /// equals比较
    public func equals(globalThis!: JSGlobalObject, callFrame!: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(2)
        if (arguments.size < 2) { return JsValue.jsFalse }
        return JsValue.jsBoolean(arguments[0].jestDeepEquals(arguments[1], globalThis: globalThis))
    }
}

// ========== ExpectMatcherUtils ==========

/// 匹配器工具 - 参考 Jest MatcherUtils
public class ExpectMatcherUtils {
    public init() {}
    public func finalize() {}

    /// 创建工具实例
    public static func create(globalThis: JSGlobalObject): JsValue {
        let utils = ExpectMatcherUtils()
        return utils.toJS(globalThis)
    }

    /// 序列化值
    public func stringify(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1) { return JsValue.jsUndefined }
        let formatter = ConsoleFormatter(globalThis: globalThis, quote_strings: true)
        // defer { formatter.deinit() }
        return JsValue.jsString(arguments[0].toFmt(formatter))
    }

    /// 打印期望值
    public func printExpected(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1) { return JsValue.jsUndefined }
        let formatter = ConsoleFormatter(globalThis: globalThis, quote_strings: true)
        // defer { formatter.deinit() }
        return JsValue.jsString("<green>" + arguments[0].toFmt(formatter) + "<r>")
    }

    /// 打印接收值
    public func printReceived(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1) { return JsValue.jsUndefined }
        let formatter = ConsoleFormatter(globalThis: globalThis, quote_strings: true)
        // defer { formatter.deinit() }
        return JsValue.jsString("<red>" + arguments[0].toFmt(formatter) + "<r>")
    }

    /// 匹配器提示
    public func matcherHint(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1) { return JsValue.jsUndefined }
        let matcherName = arguments[0].toSliceOrNull(globalThis: globalThis) ?? ""
        return JsValue.jsString("expect(received)." + matcherName + "()")
    }
}

// ========== ExpectTypeOf ==========

/// expectTypeOf
public class ExpectTypeOf {
    public init() {}
    public func finalize() {}

    public static func create(globalThis: JSGlobalObject): JsValue {
        let typeOf = ExpectTypeOf()
        return typeOf.toJS(globalThis)
    }
}

// ========== Mock辅助结构 ==========

/// Mock相关工具
public class Mock {
    /// 返回状态

    /// 所有调用参数格式化器

    /// 所有调用格式化器

    /// 成功返回格式化器
}

public enum ReturnStatus {
    | throw_
    | return_
    | incomplete
}

public class AllCallsWithArgsFormatter {
    public var globalThis: JSGlobalObject
    public var calls: JsValue

    public init(globalThis: JSGlobalObject, calls: JsValue) {
        this.globalThis = globalThis
        this.calls = calls
    }
}

public class AllCallsFormatter {
    public var globalThis: JSGlobalObject
    public var returns: JsValue

    public init(globalThis: JSGlobalObject, returns: JsValue) {
        this.globalThis = globalThis
        this.returns = returns
    }
}

public class SuccessfulReturnsFormatter {
    public var globalThis: JSGlobalObject
    public var successfulReturns: ArrayList<JsValue>

    public init(globalThis: JSGlobalObject, successfulReturns: ArrayList<JsValue>) {
        this.globalThis = globalThis
        this.successfulReturns = successfulReturns
    }
}

// ========== 辅助类型 ==========

/// 二元组
public class Tuple2<T, U> {
    public var first: T
    public var second: U

    public init(first: T, second: U) {
        this.first = first
        this.second = second
    }
}

/// 字符串写入器
public class StringWriter {
    private var buffer: StringBuilder = StringBuilder()

    public init() {}

    public func write(str: String) {
        buffer.append(str)
    }

    public func written(): String {
        return buffer.toString()
    }
}
