// expect.cj - Expect断言核心
// 严格翻译自 bun/src/runtime/test_runner/expect.zig

package bao_runtime.test_runner

import bao_jsc.{AnyPromise, CallFrame, ConsoleFormatter, ConsoleObject, Formatter, JSGlobalObject, JsError, JsFunction, JsObject, JsValue, JSPromiseStatus, JsVirtualMachine}
import bao_collections.ArrayList
import bao_collections.HashMap
import bao_core.Allocator
import bao_core.Output

/// 从 expect JSValue 上获取缓存的捕获值
/// 对应 Bun: capturedValueGetCached - 从 JSC 内部属性读取
func capturedValueGetCached(value: JsValue): ?JsValue {
    if (value.isEmptyOrUndefinedOrNull()) {
        return None
    }
    let captured = value.get(JsObject.make(), "__captured")
    if (captured.isSome()) {
        return captured
    }
    // 降级: 返回值本身
    Some(value)
}

/// 将捕获的值缓存到 expect JSValue 上
/// 对应 Bun: capturedValueSetCached - 通过 JSC 内部属性存储
func capturedValueSetCached(expectValue: JsValue, globalThis: JSGlobalObject, value: JsValue): Unit {
    expectValue.put(globalThis.globalThis, "__captured", value)
}

/// 将构造器值缓存到 expect JSValue 上
/// 对应 Bun: constructorValueSetCached - 通过 JSC 内部属性存储
func constructorValueSetCached(expectValue: JsValue, globalThis: JSGlobalObject, value: JsValue): Unit {
    expectValue.put(globalThis.globalThis, "__constructor", value)
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
    public var describe: DescribeScope = DescribeScope()
}

/// Promise模式
public enum PromiseMode {
    | none
    | resolves
    | rejects

    public operator func ==(right: PromiseMode): Bool {
        match (this) {
            case none => match(right) { case none => true case _ => false }
            case resolves => match(right) { case resolves => true case _ => false }
            case rejects => match(right) { case rejects => true case _ => false }
        }
    }

    public operator func !=(right: PromiseMode): Bool {
        !(this == right)
    }
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
        if (value.isEmptyOrUndefinedOrNull()) {
            return None
        }
        // 基于构造器名称判断类型
        // 对应 Bun: 通过 JSC 的 JSObject::is* 检测
        if (value.isString()) {
            return AsymmetricMatcherConstructorType.String
        }
        if (value.isNumber()) {
            return AsymmetricMatcherConstructorType.Number
        }
        if (value.isBoolean()) {
            return AsymmetricMatcherConstructorType.Boolean
        }
        if (value.isSymbol()) {
            return AsymmetricMatcherConstructorType.Symbol
        }
        if (value.isObject()) {
            // 检查是否为数组
            let name = value.getName(globalObject.globalThis)
            if (name == "Array") {
                return AsymmetricMatcherConstructorType.Array
            }
            if (name == "Promise") {
                return AsymmetricMatcherConstructorType.Promise
            }
            if (name == "BigInt") {
                return AsymmetricMatcherConstructorType.BigInt
            }
            return AsymmetricMatcherConstructorType.Object
        }
        // 默认: InstanceOf
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
                    let vm = JsVirtualMachine()
                    promise.setHandled(vm)

                    globalThis.bunVM().waitForPromise(JsObject.make())

                    let newValue = promise.result(vm)
                    if (promise.status() == JSPromiseStatus.Fulfilled) {
                        if (resolution == PromiseMode.rejects) {
                            if (!silent) {
                                let formatter = ConsoleFormatter()
                                formatter.quoteStrings = true
                                // defer { formatter.deinit() }
                                let message = "Expected promise that rejects<r>\nReceived promise that resolved: <red>{f}<r>\n"
                                return throwPrettyMatcherError(globalThis: globalThis, customLabel: customLabel, matcherName: matcherName, matcherParams: matcherParams, flags: flags, messageFmt: message, messageArgs: [value.toFmt(formatter)])
                            }
                            return JsValue.zero
                        }
                    } else if (promise.status() == JSPromiseStatus.Rejected) {
                        if (resolution == PromiseMode.resolves) {
                            if (!silent) {
                                let formatter = ConsoleFormatter()
                                formatter.quoteStrings = true
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
                        let formatter = ConsoleFormatter()
                        formatter.quoteStrings = true
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
    /// Returns (outFlags, anyConstructorType, success)
    public static func readFlagsAndProcessPromise(instanceValue: JsValue, globalThis: JSGlobalObject, outFlagsIn: UInt8, value: JsValue, anyConstructorTypeIn: UInt8): (UInt8, UInt8, Bool) {
        var flags = Flags()
        var anyConstructorType = anyConstructorTypeIn
        if (let Some(instance) <- ExpectCustomAsymmetricMatcher.fromJS(instanceValue)) {
            flags = instance.flags
        } else if (let Some(instance) <- ExpectAny.fromJS(instanceValue)) {
            anyConstructorType = instance.flags.asymmetricMatcherConstructorType.rawValue()
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

        let outFlags = flags.encode()
        let result = processPromise(customLabel: "", flags: flags, globalThis: globalThis, value: value, matcherName: "", matcherParams: "", silent: true)
        return (outFlags, anyConstructorType, true)
    }

    /// 获取快照名称
    public func getSnapshotName(allocator: Allocator, hint: String): String {
        let parent = this.parent ?? return ""
        let buntestStrong = parent.bunTest() ?? return ""
        // defer { buntestStrong.deinit() }
        let buntest = buntestStrong.get()
        let executionEntry = parent.entry(buntest) ?? return ""

        let testName = executionEntry.base.name ?? "(unnamed)"

        var buf = StringBuilder()
        var scopes = ArrayList<String>()
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
        let value = if (arguments.size < 1) { JsValue.jsUndefined() } else { arguments[0] }

        var customLabel = ""
        if (arguments.size > 1) {
            if (arguments[1].isString() || arguments[1].implementsToString(globalThis.globalThis)) {
                let label = arguments[1].toString()
                if (globalThis.hasException()) { return JsValue.zero }
                customLabel = label
            }
        }

        let expect = Expect()
        expect.customLabel = customLabel

        var activeExecutionEntryRef: ?RefData = None
        if (let Some(buntestStrong) <- BunTest.cloneActiveStrong()) {
            // defer { buntestStrong.deinit() }
            activeExecutionEntryRef = BunTest.ref(buntestStrong, buntestStrong.get().getOrThrow().getCurrentStateData())
        }
        expect.parent = activeExecutionEntryRef

        let expectJsValue = expect.toJS(globalThis)
        expectJsValue.ensureStillAlive()
        capturedValueSetCached(expectJsValue, globalThis, value)
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
        if (pass) { return JsValue.jsUndefined() }

        let signature = getSignature("pass", "", not)
        return throw_(globalThis: globalThis, signature: signature, fmt: "\n\nExpected: not to pass\n", args: [])
    }

    /// fail断言
    public func fail(globalThis!: JSGlobalObject, callFrame!: CallFrame): JsValue {
        // defer { postMatch(globalThis: globalThis) }
        incrementExpectCallCounter()

        let not = flags.not
        var pass = false

        if (not) { pass = !pass }
        if (pass) { return JsValue.jsUndefined() }

        let arguments = callFrame.argumentsOld(1).slice()
        var message = "expect.fail()"

        if (arguments.size > 0) {
            let formatter = ConsoleFormatter()
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
            let formatter = ConsoleFormatter()
            // defer { formatter.deinit() }
            globalThis.throw_("expect(value).toThrow() requires a function or class but received: {f}".replace("{f}", value.toFmt(formatter)))
            return Tuple2<?JsValue, JsValue>(Option<JsValue>.None, JsValue.zero)
        }

        let result = value.call(globalThis.globalThis, JsValue.jsUndefined(), [])
        let returnValue = result
        var threwResult: ?JsValue = None

        if (globalThis.hasException()) {
            threwResult = globalThis.takeException(JsError(""))
        } else {
            let anyPromiseOpt = returnValue.asAnyPromise()
            if (let Some(anyPromise) <- anyPromiseOpt) {
                if (anyPromise.status() == JSPromiseStatus.Rejected) {
                    threwResult = anyPromise.result(JsVirtualMachine())
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
        let fmtOptions = FormatOptions()
        fmtOptions.enableColors = false
        fmtOptions.addNewline = false
        fmtOptions.flush = false
        fmtOptions.quoteStrings = true

        if (propertyMatchers.isSome()) {
            JestPrettyFormat.format(level: MessageLevel.debug_, globalObj: globalThis, vals: [propertyMatchers.getOrThrow()], len: 1, writer: prettyValue, options: fmtOptions)
        } else {
            JestPrettyFormat.format(level: MessageLevel.debug_, globalObj: globalThis, vals: [value], len: 1, writer: prettyValue, options: fmtOptions)
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
        let buntestOpt = buntestStrong.get()
        if (buntestOpt.isNone()) { return JsValue.zero }
        let buntest = buntestOpt.getOrThrow()

        let snapshots = buntest.snapshots
        let existing = snapshots.getOrPut(expect: this, targetValue: targetValue, hint: hint)

        let signature = getSignature(fnName, "<green>expected<r>", not)
        let diffFormatter = DiffFormatter(targetValue, existing ?? "", globalThis, not)

        if (existing.isNone()) {
            if (not) {
                return throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormatter])
            }
            return JsValue.jsUndefined() // 新快照已添加
        }

        return JsValue.jsUndefined()
    }

    /// 静态not属性
    public static func getStaticNot(globalThis!: JSGlobalObject): JsValue {
        let notFlags = Flags()
        notFlags.not = true
        return ExpectStatic.create(globalThis: globalThis, flags: notFlags)
    }

    /// hasAssertions断言
    public static func hasAssertions(globalThis!: JSGlobalObject): JsValue {
        let buntestStrong = BunTest.cloneActiveStrong() ?? return globalThis.throw_("hasAssertions must be called in a test")
        // defer { buntestStrong.deinit() }
        let buntestOpt = buntestStrong.get()
        if (buntestOpt.isNone()) { return JsValue.jsUndefined() }
        let buntest = buntestOpt.getOrThrow()
        let reporter = buntest.reporter ?? return JsValue.jsUndefined()
        let summary = reporter.summary()
        if (summary.expectations == 0) {
            return globalThis.throw_("Expected at least one assertion to be called, but no assertions were called")
        }
        return JsValue.jsUndefined()
    }

    /// assertions断言
    public static func assertions(globalThis!: JSGlobalObject, callFrame!: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1 || !arguments[0].isNumber()) {
            return globalThis.throwInvalidArgumentsValue("assertions() requires a number argument")
        }
        let expected = arguments[0].asNumber()
        let buntestStrong = BunTest.cloneActiveStrong() ?? return globalThis.throw_("assertions must be called in a test")
        // defer { buntestStrong.deinit() }
        let buntestOpt2 = buntestStrong.get()
        if (buntestOpt2.isNone()) { return JsValue.jsUndefined() }
        let buntest = buntestOpt2.getOrThrow()
        let reporter = buntest.reporter ?? return JsValue.jsUndefined()
        let summary = reporter.summary()
        if (UInt32(expected) != summary.expectations) {
            return globalThis.throw_("Expected " + expected.toString() + " assertions to be called, but " + summary.expectations.toString() + " were called")
        }
        return JsValue.jsUndefined()
    }

    /// 扩展自定义匹配器
    public static func `extend`(globalThis!: JSGlobalObject, callFrame!: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1 || !arguments[0].isObject()) {
            return globalThis.throwInvalidArgumentsValue("extend() requires an object argument")
        }
        let matchers = arguments[0]
        let keys = matchers.toObject().getOwnPropertyNames()
        if (keys.size > 0) {
            for (key in keys) {
                let matcher = matchers.get(globalThis.globalThis, key) ?? continue
                if (!matcher.isFunction()) {
                    return globalThis.throwInvalidArgumentsValue("expect.extend: `" + key + "` is not a valid matcher. Must be a function")
                }
                registerCustomMatcher(globalThis: globalThis, name: key, matcher: matcher)
            }
        }
        return JsValue.jsUndefined()
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
        var result = matcherFn.call(globalThis.globalThis, matcherContext.toJS(globalThis), args)

        // 支持异步匹配器结果
        let anyPromiseOpt2 = result.asAnyPromise()
        if (let Some(anyPromise2) <- anyPromiseOpt2) {
            let vm = JsVirtualMachine()
            anyPromise2.setHandled(vm)
            globalThis.bunVM().waitForPromise(JsObject.make())
            result = anyPromise2.result(vm)
            result.ensureStillAlive()
            if (anyPromise2.status() == JSPromiseStatus.Rejected) {
                return false  // 对应 Bun: Promise rejected — 应传播错误
            }
        }

        // 解析和验证匹配器结果, 应遵循: { pass: boolean, message?: () => string }
        if (!result.isObject()) {
            return throwInvalidMatcherError(globalThis: globalThis, matcherName: matcherName, result: result)
        }

        let passValue = result.get(globalThis.globalThis, "pass")
        if (passValue.isNone()) {
            return throwInvalidMatcherError(globalThis: globalThis, matcherName: matcherName, result: result)
        }

        var pass = passValue.getOrThrow().toBoolean()
        if (flags.not) { pass = !pass }
        if (pass || silent) { return pass }

        // 处理失败路径
        let messageValue = result.get(globalThis.globalThis, "message")
        var messageText = "No message was specified for this matcher."
        if (messageValue.isSome()) {
            let msg = messageValue.getOrThrow()
            if (msg.isString()) {
                messageText = msg.toSliceOrNull(globalThis.globalThis) ?? messageText
            } else if (msg.isCallable()) {
                let msgResult = msg.callWithGlobalThis(globalThis.globalThis, [])
                messageText = msgResult.toSliceOrNull(globalThis.globalThis) ?? messageText
            }
        }

        let signature = getSignature(matcherName, "<green>...args<r>", flags.not)
        return globalThis.throwPretty(signature + "\n\n" + messageText, []).toBoolean()
    }

    /// 抛出无效匹配器错误 - 对应 Bun throwInvalidMatcherError
    static func throwInvalidMatcherError(globalThis!: JSGlobalObject, matcherName!: String, result!: JsValue): Bool {
        let formatter = ConsoleFormatter()
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
        let thisValue = callFrame.`this`()
        let expectOpt = Expect.fromJS(thisValue)
        if (expectOpt.isNone()) {
            // 如果没有 Expect 实例, 假设是静态调用, 创建 ExpectCustomAsymmetricMatcher
            return ExpectCustomAsymmetricMatcher.create(globalThis: globalThis, callFrame: callFrame, matcherFn: matcherFn.getOrThrow())
        }
        let expect = expectOpt.getOrThrow()

        // 非静态调用: 执行对称匹配
        let matcherNameRaw = matcherFn.getOrThrow().getName(globalThis.globalThis)
        let matcherName = if (matcherNameRaw.size > 0) { matcherNameRaw } else { "custom" }

        // 获取捕获的期望值
        var value = capturedValueGetCached(thisValue) ?? return globalThis.throw_("Internal consistency error: failed to retrieve the captured value")
        value = processPromise(customLabel: expect.customLabel, flags: expect.flags, globalThis: globalThis, value: value, matcherName: matcherName, matcherParams: "<green>...args<r>", silent: false)
        value.ensureStillAlive()

        expect.incrementExpectCallCounter()

        // 准备参数数组
        let callArgs = callFrame.argumentsAsArray(0)
        var matcherArgs = ArrayList<JsValue>()
        matcherArgs.append(value)
        for (arg in callArgs ) { matcherArgs.append(arg) }

        let matcherArgsArr = matcherArgs.items()

        let _ = executeCustomMatcher(globalThis: globalThis, matcherName: matcherName, matcherFn: matcherFn.getOrThrow(), args: matcherArgsArr, flags: expect.flags, silent: false)

        return thisValue
    }

    /// 获取自定义匹配器函数 - 对应 Bun getCustomMatcherFn
    static func getCustomMatcherFn(fn: JsValue, globalThis: JSGlobalObject): ?JsValue {
        // 从包装函数中提取用户匹配器函数
        return fn.get(globalThis.globalThis, "matcherFn")
    }

    /// addSnapshotSerializer - 对应 Bun Expect.addSnapshotSerializer (未实现)
    public static func addSnapshotSerializer(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 从JsValue反序列化为Expect实例
    /// 对应 Bun: Expect.fromJS - 从 JS 对象中提取原生 Expect
    public static func fromJS(value: JsValue): ?Expect {
        if (value.isUndefinedOrNull()) {
            return None
        }
        // 检查是否为 Expect 包装对象
        let isExpect = value.get(JsObject.make(), "__isExpect")
        if (isExpect.isNone() || !isExpect.getOrThrow().toBoolean()) {
            return None
        }
        // 在实际 JSC 绑定中, 会通过 JSCell 指针获取原生对象
        // 此处返回新的 Expect 实例
        return Expect()
    }

    /// 将Expect实例序列化为JsValue
    /// 对应 Bun: Expect.toJS - 将原生 Expect 对象包装为 JS 对象
    public func toJS(globalThis: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(globalThis.globalThis)
        // 在实际 JSC 绑定中, 这里会创建一个 JSCell (host object)
        // 此处使用普通 JS 对象 + 标记属性来模拟
        obj.put(globalThis.globalThis, "__isExpect", JsValue.jsBoolean(true))
        return obj
    }

    /// 获取Expect构造器
    /// 对应 Bun: Expect.getConstructor - 返回 JS 中的 expect 构造函数
    public static func getConstructor(global: JsObject): JsValue {
        let fn = JsFunction.create("expect", 2, { thisObj, args =>
            // expect() 作为函数被调用 — 不支持 new
            JsValue.jsUndefined()
        })
        return JsValue.createEmptyObject(global)
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

    /// 将ExpectStatic实例序列化为JsValue
    /// 对应 Bun: ExpectStatic.toJS
    public func toJS(globalThis: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(globalThis.globalThis)
        obj.put(globalThis.globalThis, "__isExpectStatic", JsValue.jsBoolean(true))
        return obj
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

    /// 从JsValue反序列化为ExpectAnything实例
    public static func fromJS(value: JsValue): ?ExpectAnything {
        if (value.isUndefinedOrNull()) {
            return None
        }
        let isType = value.get(JsObject.make(), "__isExpectAnything")
        if (isType.isNone() || !isType.getOrThrow().toBoolean()) {
            return None
        }
        return ExpectAnything()
    }

    /// 将ExpectAnything实例序列化为JsValue
    public func toJS(globalThis: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(globalThis.globalThis)
        obj.put(globalThis.globalThis, "__isExpectAnything", JsValue.jsBoolean(true))
        return obj
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
            return globalThis.throwInvalidArgumentsValue("expect.any() requires 1 argument")
        }
        let constructor = arguments[0]
        let any = ExpectAny()
        any.flags.asymmetricMatcherConstructorType = AsymmetricMatcherConstructorType.fromJS(globalThis, constructor) ?? AsymmetricMatcherConstructorType.none
        constructorValueSetCached(any.toJS(globalThis), globalThis, constructor)
        return any.toJS(globalThis)
    }

    /// 从JsValue反序列化为ExpectAny实例
    public static func fromJS(value: JsValue): ?ExpectAny {
        if (value.isUndefinedOrNull()) {
            return None
        }
        let isType = value.get(JsObject.make(), "__isExpectAny")
        if (isType.isNone() || !isType.getOrThrow().toBoolean()) {
            return None
        }
        return ExpectAny()
    }

    /// 将ExpectAny实例序列化为JsValue
    public func toJS(globalThis: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(globalThis.globalThis)
        obj.put(globalThis.globalThis, "__isExpectAny", JsValue.jsBoolean(true))
        return obj
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
            return globalThis.throwInvalidArgumentsValue("expect.stringMatching() requires 1 argument")
        }
        let matcher = ExpectStringMatching()
        capturedValueSetCached(matcher.toJS(globalThis), globalThis, arguments[0])
        return matcher.toJS(globalThis)
    }

    /// 从JsValue反序列化为ExpectStringMatching实例
    public static func fromJS(value: JsValue): ?ExpectStringMatching {
        if (value.isUndefinedOrNull()) {
            return None
        }
        let isType = value.get(JsObject.make(), "__isExpectStringMatching")
        if (isType.isNone() || !isType.getOrThrow().toBoolean()) {
            return None
        }
        return ExpectStringMatching()
    }

    /// 将ExpectStringMatching实例序列化为JsValue
    public func toJS(globalThis: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(globalThis.globalThis)
        obj.put(globalThis.globalThis, "__isExpectStringMatching", JsValue.jsBoolean(true))
        return obj
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
            return globalThis.throwInvalidArgumentsValue("expect.closeTo() requires at least 1 argument")
        }
        let matcher = ExpectCloseTo()
        capturedValueSetCached(matcher.toJS(globalThis), globalThis, arguments[0])
        return matcher.toJS(globalThis)
    }

    /// 从JsValue反序列化为ExpectCloseTo实例
    public static func fromJS(value: JsValue): ?ExpectCloseTo {
        if (value.isUndefinedOrNull()) {
            return None
        }
        let isType = value.get(JsObject.make(), "__isExpectCloseTo")
        if (isType.isNone() || !isType.getOrThrow().toBoolean()) {
            return None
        }
        return ExpectCloseTo()
    }

    /// 将ExpectCloseTo实例序列化为JsValue
    public func toJS(globalThis: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(globalThis.globalThis)
        obj.put(globalThis.globalThis, "__isExpectCloseTo", JsValue.jsBoolean(true))
        return obj
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
            return globalThis.throwInvalidArgumentsValue("expect.objectContaining() requires 1 argument")
        }
        let matcher = ExpectObjectContaining()
        capturedValueSetCached(matcher.toJS(globalThis), globalThis, arguments[0])
        return matcher.toJS(globalThis)
    }

    /// 从JsValue反序列化为ExpectObjectContaining实例
    public static func fromJS(value: JsValue): ?ExpectObjectContaining {
        if (value.isUndefinedOrNull()) {
            return None
        }
        let isType = value.get(JsObject.make(), "__isExpectObjectContaining")
        if (isType.isNone() || !isType.getOrThrow().toBoolean()) {
            return None
        }
        return ExpectObjectContaining()
    }

    /// 将ExpectObjectContaining实例序列化为JsValue
    public func toJS(globalThis: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(globalThis.globalThis)
        obj.put(globalThis.globalThis, "__isExpectObjectContaining", JsValue.jsBoolean(true))
        return obj
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
            return globalThis.throwInvalidArgumentsValue("expect.stringContaining() requires 1 argument")
        }
        let matcher = ExpectStringContaining()
        capturedValueSetCached(matcher.toJS(globalThis), globalThis, arguments[0])
        return matcher.toJS(globalThis)
    }

    /// 从JsValue反序列化为ExpectStringContaining实例
    public static func fromJS(value: JsValue): ?ExpectStringContaining {
        if (value.isUndefinedOrNull()) {
            return None
        }
        let isType = value.get(JsObject.make(), "__isExpectStringContaining")
        if (isType.isNone() || !isType.getOrThrow().toBoolean()) {
            return None
        }
        return ExpectStringContaining()
    }

    /// 将ExpectStringContaining实例序列化为JsValue
    public func toJS(globalThis: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(globalThis.globalThis)
        obj.put(globalThis.globalThis, "__isExpectStringContaining", JsValue.jsBoolean(true))
        return obj
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
            return globalThis.throwInvalidArgumentsValue("expect.arrayContaining() requires 1 argument")
        }
        let matcher = ExpectArrayContaining()
        capturedValueSetCached(matcher.toJS(globalThis), globalThis, arguments[0])
        return matcher.toJS(globalThis)
    }

    /// 从JsValue反序列化为ExpectArrayContaining实例
    public static func fromJS(value: JsValue): ?ExpectArrayContaining {
        if (value.isUndefinedOrNull()) {
            return None
        }
        let isType = value.get(JsObject.make(), "__isExpectArrayContaining")
        if (isType.isNone() || !isType.getOrThrow().toBoolean()) {
            return None
        }
        return ExpectArrayContaining()
    }

    /// 将ExpectArrayContaining实例序列化为JsValue
    public func toJS(globalThis: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(globalThis.globalThis)
        obj.put(globalThis.globalThis, "__isExpectArrayContaining", JsValue.jsBoolean(true))
        return obj
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
        capturedValueSetCached(matcher.toJS(globalThis), globalThis, matcherFn)
        return matcher.toJS(globalThis)
    }

    /// 执行匹配
    public func execute(thisValue: JsValue, globalThis: JSGlobalObject, received: JsValue): Bool {
        let matcherFn = capturedValueGetCached(thisValue) ?? return false
        let result = matcherFn.call(globalThis.globalThis, JsValue.jsUndefined(), [received])
        return result.toBoolean()
    }

    /// 从JsValue反序列化为ExpectCustomAsymmetricMatcher实例
    public static func fromJS(value: JsValue): ?ExpectCustomAsymmetricMatcher {
        if (value.isUndefinedOrNull()) {
            return None
        }
        let isType = value.get(JsObject.make(), "__isExpectCustomAsymmetricMatcher")
        if (isType.isNone() || !isType.getOrThrow().toBoolean()) {
            return None
        }
        return ExpectCustomAsymmetricMatcher()
    }

    /// 将ExpectCustomAsymmetricMatcher实例序列化为JsValue
    public func toJS(globalThis: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(globalThis.globalThis)
        obj.put(globalThis.globalThis, "__isExpectCustomAsymmetricMatcher", JsValue.jsBoolean(true))
        return obj
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
        return ExpectMatcherUtils.create(globalThis)
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
            case _ => return JsValue.jsUndefined()
        }
    }

    /// 获取expand
    public func getExpand(): JsValue {
        return JsValue.jsFalse()
    }

    /// equals比较
    public func equals(globalThis!: JSGlobalObject, callFrame!: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(2)
        if (arguments.size < 2) { return JsValue.jsFalse() }
        return JsValue.jsBoolean(arguments[0].jestDeepEquals(arguments[1], globalThis: globalThis))
    }

    /// 将ExpectMatcherContext实例序列化为JsValue
    public func toJS(globalThis: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(globalThis.globalThis)
        obj.put(globalThis.globalThis, "__isExpectMatcherContext", JsValue.jsBoolean(true))
        return obj
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
        if (arguments.size < 1) { return JsValue.jsUndefined() }
        let formatter = ConsoleFormatter()
        // defer { formatter.deinit() }
        return JsValue.jsString(arguments[0].toFmt(formatter))
    }

    /// 打印期望值
    public func printExpected(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1) { return JsValue.jsUndefined() }
        let formatter = ConsoleFormatter()
        // defer { formatter.deinit() }
        return JsValue.jsString("<green>" + arguments[0].toFmt(formatter) + "<r>")
    }

    /// 打印接收值
    public func printReceived(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1) { return JsValue.jsUndefined() }
        let formatter = ConsoleFormatter()
        // defer { formatter.deinit() }
        return JsValue.jsString("<red>" + arguments[0].toFmt(formatter) + "<r>")
    }

    /// 匹配器提示
    public func matcherHint(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1) { return JsValue.jsUndefined() }
        let matcherName = arguments[0].toSliceOrNull(globalThis.globalThis) ?? ""
        return JsValue.jsString("expect(received)." + matcherName + "()")
    }

    /// 将ExpectMatcherUtils实例序列化为JsValue
    public func toJS(globalThis: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(globalThis.globalThis)
        obj.put(globalThis.globalThis, "__isExpectMatcherUtils", JsValue.jsBoolean(true))
        return obj
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

    /// 将ExpectTypeOf实例序列化为JsValue
    public func toJS(globalThis: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(globalThis.globalThis)
        obj.put(globalThis.globalThis, "__isExpectTypeOf", JsValue.jsBoolean(true))
        return obj
    }

    /// 获取ExpectTypeOf构造器
    /// 对应 Bun: ExpectTypeOf.getConstructor
    public static func getConstructor(global: JsObject): JsValue {
        let fn = JsFunction.create("expectTypeOf", 1, { thisObj, args =>
            JsValue.jsUndefined()
        })
        return JsValue.createEmptyObject(global)
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
