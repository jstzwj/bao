// expect.cj - Expect断言核心
// 严格翻译自 bun/src/runtime/test_runner/expect.zig

package bao_runtime.test_runner

// ========== Expect - 期望断言类 ==========

/// https://jestjs.io/docs/expect
/// Expect断言核心类
public class Expect {
    public var flags: Flags = Flags()
    public var parent: ?RefData = None
    public var customLabel: String = ""

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

    /// 期望调用计数器递增
    public func incrementExpectCallCounter() {
        let parent = this.parent ?? return // 不在bun:test中
        let buntestStrong = parent.bunTest() ?? return // 该expect()调用的测试文件不再活跃
        defer { buntestStrong.deinit() }
        let buntest = buntestStrong.get()
        if let sequence = parent.phase.sequence(buntest) {
            // 找到活跃序列
            sequence.expectCallCount += 1
        } else {
            // 在并发组或其他无法获取序列的情况; 直接在reporter中递增expect调用计数
            if let reporter = buntest.reporter {
                reporter.summary().expectations += 1
            }
        }
    }

    /// 获取关联的BunTest
    public func bunTest(): ?BunTestPtr {
        let parent = this.parent ?? return None
        return parent.bunTest()
    }

    // ========== Flags - 标志位 ==========

    /// Expect标志位(注意: 保持与C++实现同步)
    public class Flags {
        public var promise: PromiseMode = PromiseMode.none
        public var not: Bool = false
        public var asymmetricMatcherConstructorType: AsymmetricMatcherConstructorType = AsymmetricMatcherConstructorType.none

        public init() {}

        public func encode(): UInt8 {
            var bits: UInt8 = promise.rawValue
            if not { bits |= 0x04 }
            bits |= (asymmetricMatcherConstructorType.rawValue << 3)
            return bits
        }

        public static func decode(bitset: UInt8): Flags {
            let flags = Flags()
            flags.promise = PromiseMode(rawValue: bitset & 0x03) ?? PromiseMode.none
            flags.not = (bitset & 0x04) != 0
            flags.asymmetricMatcherConstructorType = AsymmetricMatcherConstructorType(rawValue: (bitset >> 3) & 0x1F) ?? AsymmetricMatcherConstructorType.none
            return flags
        }
    }

    /// Promise模式
    public enum PromiseMode {
    }

    /// 非对称匹配器构造类型
    public enum AsymmetricMatcherConstructorType {
    }
    }

    /// 生成签名
    public static func getSignature(matcherName: String, args: String, not: Bool): String {
        let received = "<d>expect(<r><red>received<r><d>).<r>"
        if not {
            return received + "not<d>.<r>" + matcherName + "<d>(<r>" + args + "<d>)<r>"
        }
        return received + matcherName + "<d>(<r>" + args + "<d>)<r>"
    }

    /// 抛出漂亮的匹配器错误
    public static func throwPrettyMatcherError(globalThis: JSGlobalObject, customLabel: String, matcherName: String, matcherParams: String, flags: Flags, messageFmt: String, messageArgs: Array<Any>): JSValue {
        let colors = Output.enableAnsiColorsStderr()
        let chain = match (flags.promise) {
            | PromiseMode.resolves => flags.not ? Output.prettyFmt("resolves<d>.<r>not<d>.<r>", colors) : Output.prettyFmt("resolves<d>.<r>", colors)
            | PromiseMode.rejects => flags.not ? Output.prettyFmt("rejects<d>.<r>not<d>.<r>", colors) : Output.prettyFmt("rejects<d>.<r>", colors)
            | PromiseMode.none => flags.not ? Output.prettyFmt("not<d>.<r>", colors) : ""
        }

        if customLabel.length > 0 {
            let fmt = Output.prettyFmt("{f}\n\n" + messageFmt, colors)
            var allArgs = Array<Any>()
            allArgs.append(customLabel)
            for arg in messageArgs { allArgs.append(arg) }
            return globalThis.throwPretty(fmt, args: allArgs)
        } else {
            let fmt = Output.prettyFmt("<d>expect(<r><red>received<r><d>).<r>${chain}${matcherName}<d>(<r>${matcherParams}<d>)<r>\n\n${messageFmt}", colors)
            var allArgs = Array<Any>()
            allArgs.append(chain)
            allArgs.append(matcherName)
            allArgs.append(matcherParams)
            for arg in messageArgs { allArgs.append(arg) }
            return globalThis.throwPretty(fmt, args: allArgs)
        }
    }

    /// 获取not属性
    public func getNot(thisValue: JSValue): JSValue {
        flags.not = !flags.not
        return thisValue
    }

    /// 获取resolves属性
    public func getResolves(thisValue: JSValue, globalThis: JSGlobalObject): JSValue {
        flags.promise = match (flags.promise) {
            | PromiseMode.resolves, PromiseMode.none => PromiseMode.resolves
            | PromiseMode.rejects => return globalThis.throw_("Cannot chain .resolves() after .rejects()")
        }
        return thisValue
    }

    /// 获取rejects属性
    public func getRejects(thisValue: JSValue, globalThis: JSGlobalObject): JSValue {
        flags.promise = match (flags.promise) {
            | PromiseMode.none, PromiseMode.rejects => PromiseMode.rejects
            | PromiseMode.resolves => return globalThis.throw_("Cannot chain .rejects() after .resolves()")
        }
        return thisValue
    }

    /// 获取值
    public func getValue(globalThis: JSGlobalObject, thisValue: JSValue, matcherName: String, matcherParamsFmt: String): JSValue {
        let value = capturedValueGetCached(thisValue) ?? {
            return globalThis.throw_("Internal error: the expect(value) was garbage collected but it should not have been!")
        }()
        value.ensureStillAlive()

        let matcherParams = Output.prettyFmt(matcherParamsFmt, Output.enableAnsiColorsStderr())
        return processPromise(customLabel: customLabel, flags: flags, globalThis: globalThis, value: value, matcherName: matcherName, matcherParams: matcherParams, silent: false)
    }

    /// 处理Promise标志（resolves/rejects）
    public static func processPromise(customLabel: String, flags: Flags, globalThis: JSGlobalObject, value: JSValue, matcherName: String, matcherParams: String, silent: Bool): JSValue {
        match (flags.promise) {
            | PromiseMode.resolves, PromiseMode.rejects => {
                let resolution = flags.promise
                if (let Some(promise) <- value.asAnyPromise()) {
                    let vm = globalThis.vm()
                    promise.setHandled(vm)

                    globalThis.bunVM().waitForPromise(promise)

                    let newValue = promise.result(vm)
                    match (promise.status()) {
                        | PromiseStatus.fulfilled => {
                            match (resolution) {
                                | PromiseMode.resolves => {}
                                | PromiseMode.rejects => {
                                    if !silent {
                                        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
                                        defer { formatter.deinit() }
                                        let message = "Expected promise that rejects<r>\nReceived promise that resolved: <red>{f}<r>\n"
                                        return throwPrettyMatcherError(globalThis: globalThis, customLabel: customLabel, matcherName: matcherName, matcherParams: matcherParams, flags: flags, messageFmt: message, messageArgs: [value.toFmt(formatter)])
                                    }
                                    return JSValue.zero
                                }
                                | _ => {}
                            }
                        }
                        | PromiseStatus.rejected => {
                            match (resolution) {
                                | PromiseMode.rejects => {}
                                | PromiseMode.resolves => {
                                    if !silent {
                                        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
                                        defer { formatter.deinit() }
                                        let message = "Expected promise that resolves<r>\nReceived promise that rejected: <red>{f}<r>\n"
                                        return throwPrettyMatcherError(globalThis: globalThis, customLabel: customLabel, matcherName: matcherName, matcherParams: matcherParams, flags: flags, messageFmt: message, messageArgs: [value.toFmt(formatter)])
                                    }
                                    return JSValue.zero
                                }
                                | _ => {}
                            }
                        }
                        | _ => {}
                    }

                    newValue.ensureStillAlive()
                    return newValue
                } else {
                    if !silent {
                        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
                        defer { formatter.deinit() }
                        let message = "Expected promise<r>\nReceived: <red>{f}<r>\n"
                        return throwPrettyMatcherError(globalThis: globalThis, customLabel: customLabel, matcherName: matcherName, matcherParams: matcherParams, flags: flags, messageFmt: message, messageArgs: [value.toFmt(formatter)])
                    }
                    return JSValue.zero
                }
            }
            | _ => {}
        }

        return value
    }

    /// 检查是否为非对称匹配器
    public static func isAsymmetricMatcher(value: JSValue): Bool {
        if ExpectCustomAsymmetricMatcher.fromJS(value) != None { return true }
        if ExpectAny.fromJS(value) != None { return true }
        if ExpectAnything.fromJS(value) != None { return true }
        if ExpectStringMatching.fromJS(value) != None { return true }
        if ExpectCloseTo.fromJS(value) != None { return true }
        if ExpectObjectContaining.fromJS(value) != None { return true }
        if ExpectStringContaining.fromJS(value) != None { return true }
        if ExpectArrayContaining.fromJS(value) != None { return true }
        return false
    }

    /// 读取标志并处理Promise
    public static func readFlagsAndProcessPromise(instanceValue: JSValue, globalThis: JSGlobalObject, outFlags: UInt8, value: JSValue, anyConstructorType: UInt8): Bool {
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
        defer { buntestStrong.deinit() }
        let buntest = buntestStrong.get()
        let executionEntry = parent.phase.entry(buntest) ?? return ""

        let testName = executionEntry.base.name ?? "(unnamed)"

        var buf = StringBuilder()
        var scopes = Array<String>()
        var currScope = executionEntry.base.parent
        while currScope != None {
            let scope = currScope!
            if scope.base.name != None && scope.base.name.getOrThrow().length > 0 {
                scopes.append(scope.base.name!)
            }
            currScope = scope.base.parent
        }
        for i in 0..scopes.length {
            buf.append(scopes[i])
            buf.append(" ")
        }

        if hint.length > 0 {
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
        if let p = parent {
            p.deref()
        }
    }

    /// Expect调用
    public static func call(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.argumentsOld(2).slice()
        let value = arguments.length < 1 ? JSValue.jsUndefined : arguments[0]

        var customLabel = ""
        if arguments.length > 1 {
            if arguments[1].isString() || arguments[1].implementsToString(globalThis) {
                let label = arguments[1].toBunString(globalThis)
                if globalThis.hasException() { return JSValue.zero }
                customLabel = label
            }
        }

        let expect = Expect()
        expect.customLabel = customLabel

        let activeExecutionEntryRef = BunTest.cloneActiveStrong().map({ buntestStrong =>
            defer { buntestStrong.deinit() }
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
    public func throw_(globalThis: JSGlobalObject, signature: String, fmt: String, args: Array<Any>): JSValue {
        if customLabel.length == 0 {
            return globalThis.throwPretty(signature + fmt, args: args)
        } else {
            var allArgs = Array<Any>()
            allArgs.append(customLabel)
            for arg in args { allArgs.append(arg) }
            return globalThis.throwPretty("{f}" + fmt, args: allArgs)
        }
    }

    /// 构造函数（不允许用new调用）
    public static func constructor(globalThis: JSGlobalObject): Expect {
        globalThis.throw_("expect() cannot be called with new")
        return Expect()
    }

    /// pass断言
    public func pass(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        defer { postMatch(globalThis: globalThis) }
        incrementExpectCallCounter()

        let not = flags.not
        var pass = true

        if not { pass = !pass }
        if pass { return JSValue.jsUndefined }

        let signature = getSignature(matcherName: "pass", args: "", not: not)
        return throw_(globalThis: globalThis, signature: signature, fmt: "\n\nExpected: not to pass\n", args: [])
    }

    /// fail断言
    public func fail(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        defer { postMatch(globalThis: globalThis) }
        incrementExpectCallCounter()

        let not = flags.not
        var pass = false

        if not { pass = !pass }
        if pass { return JSValue.jsUndefined }

        let arguments = callFrame.argumentsOld(1).slice()
        var message = "expect.fail()"

        if arguments.length > 0 {
            let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
            defer { formatter.deinit() }
            message = arguments[0].toFmt(formatter)
        }

        return globalThis.throwPretty("\n\n{f}\n", args: [message])
    }

    /// 匹配后清理
    public func postMatch(globalThis: JSGlobalObject) {}

    /// 获取用于toThrow的值
    public func getValueAsToThrow(globalThis: JSGlobalObject, value: JSValue): Tuple2<?JSValue, JSValue> {
        if !value.isFunction() && !value.isObject() {
            let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
            defer { formatter.deinit() }
            globalThis.throw_("expect(value).toThrow() requires a function or class but received: {f}", args: [value.toFmt(formatter)])
            return Tuple2<?JSValue, JSValue>(None, JSValue.zero)
        }

        let result = value.call(globalThis: globalThis, thisValue: JSValue.jsUndefined, args: [])
        let returnValue = result
        var threwResult: ?JSValue = None

        if globalThis.hasException() {
            threwResult = globalThis.takeException()
        } else {
            if (let Some(promise) <- returnValue.asAnyPromise()) {
                if promise.status() == PromiseStatus.rejected {
                    threwResult = promise.result(globalThis.vm())
                }
            }
        }

        return Tuple2<?JSValue, JSValue>(threwResult, returnValue)
    }

    /// 行内快照
    public func inlineSnapshot(globalThis: JSGlobalObject, callFrame: CallFrame, value: JSValue, propertyMatchers: ?JSValue, result: ?String, fnName: String): JSValue {
        defer { postMatch(globalThis: globalThis) }
        incrementExpectCallCounter()

        var prettyValue = StringWriter()
        matchAndFmtSnapshot(globalThis: globalThis, value: value, propertyMatchers: propertyMatchers, prettyValue: prettyValue, fnName: fnName)

        return snapshot(globalThis: globalThis, value: value, propertyMatchers: propertyMatchers, hint: "", fnName: fnName)
    }

    /// 匹配并格式化快照
    public func matchAndFmtSnapshot(globalThis: JSGlobalObject, value: JSValue, propertyMatchers: ?JSValue, prettyValue: StringWriter, fnName: String) {
        let fmtOptions = JestPrettyFormat.FormatOptions(enableColors: false, addNewline: false, flush: false, quoteStrings: true)

        if propertyMatchers != None {
            JestPrettyFormat.format(level: FormatLevel.Debug, globalThis: globalThis, values: [propertyMatchers!], writer: prettyValue, options: fmtOptions)
        } else {
            JestPrettyFormat.format(level: FormatLevel.Debug, globalThis: globalThis, values: [value], writer: prettyValue, options: fmtOptions)
        }
    }

    /// 快照
    public func snapshot(globalThis: JSGlobalObject, value: JSValue, propertyMatchers: ?JSValue, hint: String, fnName: String): JSValue {
        let not = flags.not

        var prettyValue = StringWriter()
        matchAndFmtSnapshot(globalThis: globalThis, value: value, propertyMatchers: propertyMatchers, prettyValue: prettyValue, fnName: fnName)

        let targetValue = prettyValue.written()

        let buntestStrong = bunTest() ?? return JSValue.zero
        defer { buntestStrong.deinit() }
        let buntest = buntestStrong.get()

        let snapshots = buntest.snapshots
        let existing = snapshots.getOrPut(expect: this, targetValue: targetValue, hint: hint)

        let signature = getSignature(matcherName: fnName, args: "<green>expected<r>", not: not)
        let diffFormatter = DiffFormatter(receivedString: targetValue, expectedString: existing ?? "", globalThis: globalThis, not: not)

        if existing == None {
            if not {
                return throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormatter])
            }
            return JSValue.jsUndefined // 新快照已添加
        }

        return JSValue.jsUndefined
    }

    /// 静态not属性
    public static func getStaticNot(globalThis: JSGlobalObject): JSValue {
        return ExpectStatic.create(globalThis: globalThis, flags: Flags(not: true))
    }

    /// hasAssertions断言
    public static func hasAssertions(globalThis: JSGlobalObject): JSValue {
        let buntestStrong = BunTest.cloneActiveStrong() ?? return globalThis.throw_("hasAssertions must be called in a test")
        defer { buntestStrong.deinit() }
        let buntest = buntestStrong.get()
        let reporter = buntest.reporter ?? return JSValue.jsUndefined
        let summary = reporter.summary()
        if summary.expectations == 0 {
            return globalThis.throw_("Expected at least one assertion to be called, but no assertions were called")
        }
        return JSValue.jsUndefined
    }

    /// assertions断言
    public static func assertions(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.argumentsAsArray(1)
        if arguments.length < 1 || !arguments[0].isNumber() {
            return globalThis.throwInvalidArguments("assertions() requires a number argument")
        }
        let expected = arguments[0].asNumber()
        let buntestStrong = BunTest.cloneActiveStrong() ?? return globalThis.throw_("assertions must be called in a test")
        defer { buntestStrong.deinit() }
        let buntest = buntestStrong.get()
        let reporter = buntest.reporter ?? return JSValue.jsUndefined
        let summary = reporter.summary()
        if UInt32(expected) != summary.expectations {
            return globalThis.throw_("Expected ${expected} assertions to be called, but ${summary.expectations} were called")
        }
        return JSValue.jsUndefined
    }

    /// 扩展自定义匹配器
    public static func extend(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.argumentsAsArray(1)
        if arguments.length < 1 || !arguments[0].isObject() {
            return globalThis.throwInvalidArguments("extend() requires an object argument")
        }
        let matchers = arguments[0]
        let keys = matchers.getOwnPropertyNames(globalThis)
        if keys != None {
            for key in keys! {
                let matcher = matchers.get(globalThis, key: key) ?? continue
                registerCustomMatcher(globalThis: globalThis, name: key, matcher: matcher)
            }
        }
        return JSValue.jsUndefined
    }
}

// ========== ExpectStatic - 静态expect实例 ==========

/// 静态expect实例，例如expect.not
public class ExpectStatic {
    public var flags: Expect.Flags = Expect.Flags()

    public init() {}

    public func finalize() {}

    /// 创建静态expect
    public static func create(globalThis: JSGlobalObject, flags: Expect.Flags): JSValue {
        let expect = ExpectStatic()
        expect.flags = flags
        return expect.toJS(globalThis)
    }

    /// 获取not属性
    public func getNot(globalThis: JSGlobalObject): JSValue {
        var newFlags = flags
        newFlags.not = !flags.not
        return ExpectStatic.create(globalThis: globalThis, flags: newFlags)
    }

    /// 获取resolvesTo属性
    public func getResolvesTo(globalThis: JSGlobalObject): JSValue {
        var newFlags = flags
        newFlags.promise = Expect.PromiseMode.resolves
        return ExpectStatic.create(globalThis: globalThis, flags: newFlags)
    }

    /// 获取rejectsTo属性
    public func getRejectsTo(globalThis: JSGlobalObject): JSValue {
        var newFlags = flags
        newFlags.promise = Expect.PromiseMode.rejects
        return ExpectStatic.create(globalThis: globalThis, flags: newFlags)
    }
}

// ========== ExpectAnything ==========

/// expect.anything()匹配器
public class ExpectAnything {
    public var flags: Expect.Flags = Expect.Flags()

    public init() {}
    public func finalize() {}

    public static func call(globalThis: JSGlobalObject): JSValue {
        let anything = ExpectAnything()
        return anything.toJS(globalThis)
    }
}

// ========== ExpectAny ==========

/// expect.any()匹配器
public class ExpectAny {
    public var flags: Expect.Flags = Expect.Flags()

    public init() {}
    public func finalize() {}

    public static func call(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.argumentsAsArray(1)
        if arguments.length < 1 {
            return globalThis.throwInvalidArguments("expect.any() requires 1 argument")
        }
        let constructor = arguments[0]
        let any = ExpectAny()
        any.flags.asymmetricMatcherConstructorType = Expect.AsymmetricMatcherConstructorType.fromJS(globalObject: globalThis, value: constructor) ?? Expect.AsymmetricMatcherConstructorType.none
        constructorValueSetCached(any.toJS(globalThis), globalThis: globalThis, value: constructor)
        return any.toJS(globalThis)
    }
}

// ========== ExpectStringMatching ==========

/// expect.stringMatching()匹配器
public class ExpectStringMatching {
    public var flags: Expect.Flags = Expect.Flags()

    public init() {}
    public func finalize() {}

    public static func call(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.argumentsAsArray(1)
        if arguments.length < 1 {
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
    public var flags: Expect.Flags = Expect.Flags()

    public init() {}
    public func finalize() {}

    public static func call(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.argumentsAsArray(2)
        if arguments.length < 1 {
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
    public var flags: Expect.Flags = Expect.Flags()

    public init() {}
    public func finalize() {}

    public static func call(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.argumentsAsArray(1)
        if arguments.length < 1 {
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
    public var flags: Expect.Flags = Expect.Flags()

    public init() {}
    public func finalize() {}

    public static func call(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.argumentsAsArray(1)
        if arguments.length < 1 {
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
    public var flags: Expect.Flags = Expect.Flags()

    public init() {}
    public func finalize() {}

    public static func call(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.argumentsAsArray(1)
        if arguments.length < 1 {
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
    public var flags: Expect.Flags = Expect.Flags()

    public init() {}
    public func finalize() {}

    /// 创建
    public static func create(globalThis: JSGlobalObject, callFrame: CallFrame, matcherFn: JSValue): JSValue {
        let matcher = ExpectCustomAsymmetricMatcher()
        capturedValueSetCached(matcher.toJS(globalThis), globalThis: globalThis, value: matcherFn)
        return matcher.toJS(globalThis)
    }

    /// 执行匹配
    public func execute(thisValue: JSValue, globalThis: JSGlobalObject, received: JSValue): Bool {
        let matcherFn = capturedValueGetCached(thisValue) ?? return false
        let result = matcherFn.call(globalThis: globalThis, thisValue: JSValue.jsUndefined, args: [received])
        return result.toBoolean()
    }
}

// ========== ExpectMatcherContext ==========

/// 匹配器上下文 - 参考 Jest MatcherContext
public class ExpectMatcherContext {
    public var flags: Expect.Flags = Expect.Flags()

    public init() {}
    public func finalize() {}

    /// 获取工具对象
    public func getUtils(globalThis: JSGlobalObject): JSValue {
        return ExpectMatcherUtils.create(globalThis: globalThis)
    }

    /// 获取isNot
    public func getIsNot(): JSValue {
        return JSValue.jsBoolean(flags.not)
    }

    /// 获取promise
    public func getPromise(globalThis: JSGlobalObject): JSValue {
        match (flags.promise) {
            | Expect.PromiseMode.rejects => return JSValue.jsString("rejects")
            | Expect.PromiseMode.resolves => return JSValue.jsString("resolves")
            default => return JSValue.jsUndefined
        }
    }

    /// 获取expand
    public func getExpand(): JSValue {
        return JSValue.jsFalse
    }

    /// equals比较
    public func equals(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.argumentsAsArray(2)
        if arguments.length < 2 { return JSValue.jsFalse }
        return JSValue.jsBoolean(arguments[0].jestDeepEquals(arguments[1], globalThis: globalThis))
    }
}

// ========== ExpectMatcherUtils ==========

/// 匹配器工具 - 参考 Jest MatcherUtils
public class ExpectMatcherUtils {
    public init() {}
    public func finalize() {}

    /// 创建工具实例
    public static func create(globalThis: JSGlobalObject): JSValue {
        let utils = ExpectMatcherUtils()
        return utils.toJS(globalThis)
    }

    /// 序列化值
    public func stringify(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.argumentsAsArray(1)
        if arguments.length < 1 { return JSValue.jsUndefined }
        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        defer { formatter.deinit() }
        return JSValue.jsString(arguments[0].toFmt(formatter))
    }

    /// 打印期望值
    public func printExpected(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.argumentsAsArray(1)
        if arguments.length < 1 { return JSValue.jsUndefined }
        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        defer { formatter.deinit() }
        return JSValue.jsString("<green>${arguments[0].toFmt(formatter)}<r>")
    }

    /// 打印接收值
    public func printReceived(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.argumentsAsArray(1)
        if arguments.length < 1 { return JSValue.jsUndefined }
        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        defer { formatter.deinit() }
        return JSValue.jsString("<red>${arguments[0].toFmt(formatter)}<r>")
    }

    /// 匹配器提示
    public func matcherHint(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        let arguments = callFrame.argumentsAsArray(1)
        if arguments.length < 1 { return JSValue.jsUndefined }
        let matcherName = arguments[0].toSliceOrNull(globalThis: globalThis) ?? ""
        return JSValue.jsString("expect(received).${matcherName}()")
    }
}

// ========== ExpectTypeOf ==========

/// expectTypeOf
public class ExpectTypeOf {
    public init() {}
    public func finalize() {}

    public static func create(globalThis: JSGlobalObject): JSValue {
        let typeOf = ExpectTypeOf()
        return typeOf.toJS(globalThis)
    }
}

// ========== Mock辅助结构 ==========

/// Mock相关工具
public class Mock {
    /// 返回状态
    public enum ReturnStatus {
        | throw_
        | return_
        | incomplete
    }

    /// 所有调用参数格式化器
    public class AllCallsWithArgsFormatter {
        public var globalThis: JSGlobalObject
        public var calls: JSValue

        public init(globalThis: JSGlobalObject, calls: JSValue) {
            this.globalThis = globalThis
            this.calls = calls
        }
    }

    /// 所有调用格式化器
    public class AllCallsFormatter {
        public var globalThis: JSGlobalObject
        public var returns: JSValue

        public init(globalThis: JSGlobalObject, returns: JSValue) {
            this.globalThis = globalThis
            this.returns = returns
        }
    }

    /// 成功返回格式化器
    public class SuccessfulReturnsFormatter {
        public var globalThis: JSGlobalObject
        public var successfulReturns: ArrayList<JSValue>

        public init(globalThis: JSGlobalObject, successfulReturns: ArrayList<JSValue>) {
            this.globalThis = globalThis
            this.successfulReturns = successfulReturns
        }
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
