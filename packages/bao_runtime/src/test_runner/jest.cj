// jest.cj - Jest兼容层
// 严格翻译自 bun/src/runtime/test_runner/jest.zig

package bao_runtime.test_runner

import bao_jsc.*
import std.collection.*

// ========== TestRunner 嵌套类型提取到顶层 ==========

/// 测试摘要
public class Summary {
    public var pass: UInt32 = 0
    public var expectations: UInt32 = 0
    public var skip: UInt32 = 0
    public var todo: UInt32 = 0
    public var fail: UInt32 = 0
    public var files: UInt32 = 0
    public var skippedBecauseLabel: UInt32 = 0

    public init() {}

    /// 是否因标签过滤而跳过了所有测试
    public func didLabelFilterOutAllTests(): Bool {
        return skippedBecauseLabel > 0 && (pass + skip + todo + fail + expectations) == 0
    }
}

/// 文件ID结果
public class FileIdResult {
    public var fileId: UInt32
    public init(fileId: UInt32) {
        this.fileId = fileId
    }
}

/// 文件信息
public class File {
    public var source: Source = Source()
    public var log: Log = Log()

    public init() {}
}

/// 文件列表类型
public type FileList = ArrayList<File>

/// 文件ID类型  
public type FileID = UInt32

/// 文件映射类型
public type FileMap = HashMap<UInt32, UInt32>

// ========== TestRunner - 测试运行器 ==========

/// 测试运行器，管理所有测试文件和运行状态
public class TestRunner {
    public var currentFile: CurrentFile = CurrentFile()
    public var files: FileList = FileList()
    public var index: FileMap = FileMap()
    public var only: Bool = false
    public var runTodo: Bool = false
    public var concurrent: Bool = false
    public var randomize: Bool = false
    public var randomizeSeed: ?UInt32 = None
    public var concurrentTestGlob: ?Array<String> = None
    public var lastFile: UInt64 = 0
    public var bail: UInt32 = 0
    public var maxConcurrency: UInt32 = 20
    public var allocator: Allocator
    public var hasPendingTests: Bool = false
    public var snapshots: Snapshots
    public var defaultTimeoutMs: UInt32 = 0
    public var defaultTimeoutOverride: UInt32 = UInt32.max
    public var testOptions: TestOptions = TestOptions()
    public var filterRegex: ?RegularExpression = None
    public var unhandledErrorsBetweenTests: UInt32 = 0
    public var summary: Summary = Summary()
    public var bunTestRoot: BunTestRoot

    public init() {
        this.allocator = Allocator.default
        this.snapshots = Snapshots()
        this.bunTestRoot = BunTestRoot(gpa: allocator)
    }

    /// 获取活跃超时
    ///
    /// 从当前活跃的BunTest文件中获取其事件循环定时器的下一个超时时间。
    /// 如果定时器未激活或时间为epoch（无超时），返回epoch。
    public func getActiveTimeout(): Timespec {
        let activeFile = bunTestRoot.activeFile
        if (activeFile == None) {
            return Timespec.epoch
        }
        let activeFileVal = activeFile.getOrThrow()
        let fileOpt = activeFileVal.get()
        if (fileOpt == None) { return Timespec.epoch }
        let file = fileOpt.getOrThrow()

        if (file.timer.state != TimerState.active || file.timer.next == Timespec.epoch) {
            return Timespec.epoch
        }
        return file.timer.next
    }

    /// 移除活跃超时
    ///
    /// 从事件循环中移除当前BunTest文件的定时器。
    public func removeActiveTimeout(vm: VirtualMachine) {
        let activeFile = bunTestRoot.activeFile
        if (activeFile == None) {
            return
        }
        let file = activeFile.getOrThrow().get()
        if (file == None) {
            return
        }
        let fileVal = file.getOrThrow()

        if (fileVal.timer.state != TimerState.active || fileVal.timer.next == Timespec.epoch) {
            return
        }
        // 从事件循环定时器堆中移除
        vm.timer.remove(ref: fileVal.timer)
    }



    /// 是否有测试过滤器
    public func hasTestFilter(): Bool {
        return filterRegex != None
    }

    /// 文件是否应该并发运行
    ///
    /// 检查全局并发标志和glob模式匹配
    public func shouldFileRunConcurrently(fileId: UInt32): Bool {
        // 全局并发标志
        if (concurrent) { return true }

        // 检查glob模式
        if (concurrentTestGlob == None) { return false }
        let globPatterns = concurrentTestGlob.getOrThrow()
        if (fileId >= files.size) { return false }

        let filePath = files[fileId].path.text

        // 检查文件路径是否匹配任何glob模式
        for (pattern in globPatterns ) {
            if (GlobMatcher.`match`(pattern: pattern, path: filePath) == GlobMatcher.MatchResult.`match`) {
                return true
            }
        }
        return false
    }

    /// 获取或创建文件
    ///
    /// 根据文件路径的hash查找已有的文件ID，如果不存在则创建新的文件条目
    public func getOrPutFile(filePath: String): FileIdResult {
        let hash = WyHash.hash(data: filePath)
        let existing = index.get(key: hash)
        if (existing != None) {
            return FileIdResult(fileId: existing.getOrThrow())
        }

        let fileId: UInt32 = UInt32(files.size)
        files.append(File(source: Source.initEmptyFile(path: filePath)))
        index.put(key: hash, value: fileId)
        return FileIdResult(fileId: fileId)
    }






}

// ========== Jest - Jest模块 ==========

/// Jest模块，提供test/describe/expect等全局函数
///
/// Jest是Bun测试框架的兼容层，提供与Jest/Vitest兼容的API。
/// 主要入口是createTestModule，它返回一个包含所有测试函数的JS模块对象。
public class Jest {
    /// 全局测试运行器实例
    public static var runner: ?TestRunner = None

    /// 创建测试模块对象
    public static func createTestModuleObject(globalObject: JSGlobalObject): JSValue {
        return createTestModule(globalObject: globalObject) ?? JSValue.zero
    }

    /// 创建测试模块
    ///
    /// 创建一个JS对象，包含:
    /// - test/it: 测试函数
    /// - xtest/xit: 跳过的测试函数
    /// - describe/xdescribe: 描述块
    /// - beforeEach/afterEach/beforeAll/afterAll: 生命周期钩子
    /// - onTestFinished: 测试完成回调
    /// - setDefaultTimeout: 设置默认超时
    /// - expect/expectTypeOf: 断言函数
    /// - jest/vi: Mock工具
    /// - spyOn: 间谍函数
    public static func createTestModule(globalObject: JSGlobalObject): ?JSValue {
        let module = JSValue.createEmptyObject(global: globalObject, propertyCount: 23)

        // test/it - 测试函数
        let testScopeFunctions = ScopeFunctions.createBound(
            globalThis: globalObject,
            mode: ScopeFunctions.Mode.test_,
            each: JSValue.zero,
            cfg: BaseScopeCfg(),
            name: "test"
        )
        module.put(global: globalObject, name: "test", value: testScopeFunctions)
        module.put(global: globalObject, name: "it", value: testScopeFunctions)

        // xtest/xit - 跳过的测试函数
        let xtestScopeFunctions = ScopeFunctions.createBound(
            globalThis: globalObject,
            mode: ScopeFunctions.Mode.test_,
            each: JSValue.zero,
            cfg: BaseScopeCfg(selfMode: ScopeMode.skip),
            name: "xtest"
        )
        module.put(global: globalObject, name: "xtest", value: xtestScopeFunctions)
        module.put(global: globalObject, name: "xit", value: xtestScopeFunctions)

        // describe - 描述块
        let describeScopeFunctions = ScopeFunctions.createBound(
            globalThis: globalObject,
            mode: ScopeFunctions.Mode.describe,
            each: JSValue.zero,
            cfg: BaseScopeCfg(),
            name: "describe"
        )
        module.put(global: globalObject, name: "describe", value: describeScopeFunctions)

        // xdescribe - 跳过的描述块
        let xdescribeScopeFunctions = ScopeFunctions.createBound(
            globalThis: globalObject,
            mode: ScopeFunctions.Mode.describe,
            each: JSValue.zero,
            cfg: BaseScopeCfg(selfMode: ScopeMode.skip),
            name: "xdescribe"
        )
        module.put(global: globalObject, name: "xdescribe", value: xdescribeScopeFunctions)

        // 生命周期钩子
        module.put(global: globalObject, name: "beforeEach",
            value: JSFunction.create(global: globalObject, name: "beforeEach",
                hostFn: GenericHookTag.beforeEach.hostFn, argCount: 1))
        module.put(global: globalObject, name: "beforeAll",
            value: JSFunction.create(global: globalObject, name: "beforeAll",
                hostFn: GenericHookTag.beforeAll.hostFn, argCount: 1))
        module.put(global: globalObject, name: "afterAll",
            value: JSFunction.create(global: globalObject, name: "afterAll",
                hostFn: GenericHookTag.afterAll.hostFn, argCount: 1))
        module.put(global: globalObject, name: "afterEach",
            value: JSFunction.create(global: globalObject, name: "afterEach",
                hostFn: GenericHookTag.afterEach.hostFn, argCount: 1))
        module.put(global: globalObject, name: "onTestFinished",
            value: JSFunction.create(global: globalObject, name: "onTestFinished",
                hostFn: GenericHookTag.onTestFinished.hostFn, argCount: 1))
        module.put(global: globalObject, name: "setDefaultTimeout",
            value: JSFunction.create(global: globalObject, name: "setDefaultTimeout",
                hostFn: Jest.jsSetDefaultTimeout, argCount: 1))

        // expect/expectTypeOf - 断言
        module.put(global: globalObject, name: "expect",
            value: Expect.getConstructor(global: globalObject))
        module.put(global: globalObject, name: "expectTypeOf",
            value: ExpectTypeOf.getConstructor(global: globalObject))

        // 创建mock对象
        createMockObjects(globalObject: globalObject, module: module)

        return module
    }

    /// 创建Mock对象
    ///
    /// 创建jest/vi兼容的mock工具函数:
    /// - fn: 创建mock函数
    /// - spyOn: 创建间谍函数
    /// - restoreAllMocks/clearAllMocks: 恢复/清除所有mock
    /// - mock.module: 模块mock
    /// - setSystemTime/now: 假定时器相关
    /// - setTimeout: 设置默认超时
    public static func createMockObjects(globalObject: JSGlobalObject, module: JSValue) {
        let setSystemTime = JSFunction.create(global: globalObject, name: "setSystemTime",
            hostFn: JSMock.jsSetSystemTime, argCount: 0)
        let mockFn = JSFunction.create(global: globalObject, name: "fn",
            hostFn: JSMock.jsMockFn, argCount: 1)
        let spyOn = JSFunction.create(global: globalObject, name: "spyOn",
            hostFn: JSMock.jsSpyOn, argCount: 2)
        let restoreAllMocks = JSFunction.create(global: globalObject, name: "restoreAllMocks",
            hostFn: JSMock.jsRestoreAllMocks, argCount: 2)
        let clearAllMocks = JSFunction.create(global: globalObject, name: "clearAllMocks",
            hostFn: JSMock.jsClearAllMocks, argCount: 2)
        let mockModuleFn = JSFunction.create(global: globalObject, name: "module",
            hostFn: JSMock.jsModuleMock, argCount: 2)

        module.put(global: globalObject, name: "mock", value: mockFn)
        mockFn.put(global: globalObject, name: "module", value: mockModuleFn)
        mockFn.put(global: globalObject, name: "restore", value: restoreAllMocks)
        mockFn.put(global: globalObject, name: "clearAllMocks", value: clearAllMocks)

        // jest对象
        let jest = JSValue.createEmptyObject(global: globalObject, propertyCount: 9 + FakeTimers.timerFnsCount)
        jest.put(global: globalObject, name: "fn", value: mockFn)
        jest.put(global: globalObject, name: "mock", value: mockModuleFn)
        jest.put(global: globalObject, name: "spyOn", value: spyOn)
        jest.put(global: globalObject, name: "restoreAllMocks", value: restoreAllMocks)
        jest.put(global: globalObject, name: "clearAllMocks", value: clearAllMocks)
        jest.put(global: globalObject, name: "resetAllMocks", value: clearAllMocks)
        jest.put(global: globalObject, name: "setSystemTime", value: setSystemTime)
        jest.put(global: globalObject, name: "now",
            value: JSFunction.create(global: globalObject, name: "now",
                hostFn: JSMock.jsNow, argCount: 0))
        jest.put(global: globalObject, name: "setTimeout",
            value: JSFunction.create(global: globalObject, name: "setTimeout",
                hostFn: Jest.jsSetDefaultTimeout, argCount: 1))

        module.put(global: globalObject, name: "jest", value: jest)
        module.put(global: globalObject, name: "spyOn", value: spyOn)
        module.put(global: globalObject, name: "expect",
            value: Expect.getConstructor(global: globalObject))

        // vi对象 (Vitest兼容)
        let vi = JSValue.createEmptyObject(global: globalObject, propertyCount: 6 + FakeTimers.timerFnsCount)
        vi.put(global: globalObject, name: "fn", value: mockFn)
        vi.put(global: globalObject, name: "mock", value: mockModuleFn)
        vi.put(global: globalObject, name: "spyOn", value: spyOn)
        vi.put(global: globalObject, name: "restoreAllMocks", value: restoreAllMocks)
        vi.put(global: globalObject, name: "resetAllMocks", value: clearAllMocks)
        vi.put(global: globalObject, name: "clearAllMocks", value: clearAllMocks)
        module.put(global: globalObject, name: "vi", value: vi)

        // 添加假定时器函数到jest和vi对象
        FakeTimers.putTimersFns(globalObject: globalObject, jest: jest, vi: vi)
    }

    /// Jest调用入口
    ///
    /// 处理Bun.jest()调用。在preload阶段不需要参数，
    /// 在执行阶段需要绝对文件路径作为第一个参数。
    public static func call(globalObject: JSGlobalObject, callFrame: CallFrame): ?JSValue {
        let vm = globalObject.bunVM()

        if (vm.isInPreload || runner == None) {
            // 在preload阶段，不需要参数
        } else {
            let arguments = callFrame.arguments(max: 2)

            if (arguments.size < 1 || !arguments[0].isString()) {
                globalObject.`throw`(message: "Bun.jest() expects a string filename")
                return None
            }

            let str = arguments[0].toSlice(global: globalObject)
            if (!Path.isAbsolute(path: str)) {
                globalObject.`throw`(message: "Bun.jest() expects an absolute file path, got '" + (str) + "'")
                return None
            }
        }

        return createTestModuleObject(globalObject: globalObject)
    }

    /// 设置默认超时
    ///
    /// 处理setDefaultTimeout()/jest.setTimeout()调用。
    /// 参数为一个表示毫秒数的数字。
    public static func jsSetDefaultTimeout(globalObject: JSGlobalObject, callFrame: CallFrame): ?JSValue {
        let arguments = callFrame.arguments(max: 1)
        if (arguments.size < 1 || !arguments[0].isNumber()) {
            globalObject.`throw`(message: "setTimeout() expects a number (milliseconds)")
            return None
        }

        let timeoutMs: UInt32 = UInt32(arguments[0].coerceInt32(global: globalObject).max(0))

        if (let Some(testRunner) <- runner) {
            testRunner.defaultTimeoutOverride = timeoutMs
        }

        return JSValue.jsUndefined
    }
}

/// 重复信息
public class RepeatInfo {
    public var count: UInt32 = 0
    public var index: UInt32 = 0
    public init() {}
}

// ========== CurrentFile - 当前文件信息 ==========

/// 当前正在运行的测试文件信息
///
/// 用于在终端中显示当前正在运行的测试文件名。
/// dots和onlyFailures模式下会延迟显示直到需要时才打印。
public class CurrentFile {
    public var title: String = ""
    public var prefix: String = ""
    public var repeatInfo: RepeatInfo = RepeatInfo()
    public var hasPrintedFilename: Bool = false

    public init() {}



    /// 设置当前文件
    ///
    /// 根据reporter的模式决定是否立即打印文件名:
    /// - dots/onlyFailures模式: 延迟打印
    /// - 其他模式: 立即打印
    public func set(title: String, prefix: String, repeatCount: UInt32, repeatIndex: UInt32, reporter: CommandLineReporter) {
        if (reporter.workerIpcFileIdx != None) {
            // 协调器拥有终端，worker不应输出
            hasPrintedFilename = true
            return
        }

        if (reporter.reporters.dots || reporter.reporters.onlyFailures) {
            this.title = title
            this.prefix = prefix
            repeatInfo.count = repeatCount
            repeatInfo.index = repeatIndex
            hasPrintedFilename = false
            return
        }

        hasPrintedFilename = true
        print(title: title, prefix: prefix, repeatCount: repeatCount, repeatIndex: repeatIndex)
    }

    /// 打印当前文件信息
    ///
    /// 在终端中显示当前测试文件名和前缀。
    /// 如果有重复执行，显示重复序号。
    public func print(title: String, prefix: String, repeatCount: UInt32, repeatIndex: UInt32) {
        Output.prettyError("<r>\n")

        if (repeatCount > 0) {
            if (repeatCount > 1) {
                Output.prettyErrorln((prefix) + (title) + ": <d>(run #" + (repeatIndex + 1) + ")<r>\n")
            } else {
                Output.prettyErrorln((prefix) + (title) + ":\n")
            }
        } else {
            Output.prettyErrorln((prefix) + (title) + ":\n")
        }

        Output.flush()
    }

    /// 如果需要则打印
    ///
    /// 延迟打印模式下，首次调用时才实际打印文件名
    public func printIfNeeded() {
        if (hasPrintedFilename) { return }
        hasPrintedFilename = true
        print(title: title, prefix: prefix, repeatCount: repeatInfo.count, repeatIndex: repeatInfo.index)
    }
}

// ========== 未处理的拒绝处理 ==========

/// 处理未捕获的Promise拒绝
///
/// 如果有活跃的BunTest，将拒绝标记为当前测试的错误并继续运行。
/// 否则，直接运行错误处理器。
public func onUnhandledRejection(jscVm: VirtualMachine, globalObject: JSGlobalObject, rejection: JSValue) {
    if (let Some(buntestStrong) <- cloneActiveStrong()) {
        let buntestOpt = buntestStrong.get()
        if (buntestOpt == None) { return }
        let buntest = buntestOpt.getOrThrow()

        // 标记未处理错误属于当前活跃测试
        var currentStateData = buntest.getCurrentStateData()

        // 如果错误发生在钩子中，标记为"测试间未处理错误"
        if (let Some(entry) <- currentStateData.entry(buntest: buntest)) {
            if (let Some(sequence) <- currentStateData.sequence(buntest: buntest)) {
                if (sequence.testEntry != entry) {
                    currentStateData = RefDataValue.start
                }
            }
        }

        buntest.onUncaughtException(
            globalThis: globalObject,
            exception: rejection,
            isRejection: true,
            userData: currentStateData
        )
        buntest.addResult(result: currentStateData)
        let _ = BunTest.run(strong: buntestStrong, globalThis: globalObject)
        return
    }

    // 没有活跃的BunTest，直接运行错误处理器
    jscVm.runErrorHandler(exception: rejection, exceptionList: jscVm.onUnhandledRejectionExceptionList)
}

// ========== 格式化标签 ==========

/// 通过位置注入参数来生成测试标签
///
/// 支持printf风格的格式化:
/// - %s: 字符串
/// - %i: 整数
/// - %d: 数字
/// - %f: 浮点数
/// - %j/%o: JSON字符串化
/// - %p: pretty-format
/// - %#: 测试索引
/// - %%: 百分号字面量
///
/// 还支持$variablePath语法来从第一个参数（对象）中读取属性:
/// - $name: 读取args[0].name
/// - $user.email: 读取args[0].user.email
public func formatLabel(globalThis: JSGlobalObject, label: String, functionArgs: Array<JSValue>, testIdx: UInt64, allocator: Allocator): String {
    var idx: UInt64 = 0
    var argsIdx: UInt64 = 0
    var result = StringBuilder()

    while (idx < label.length) {
        let char = label[idx]

        // $variablePath语法
        if (char == '$' && idx + 1 < label.length && functionArgs.size > 0 && functionArgs[0].isObject()) {
            let varStart = idx + 1
            var varEnd = varStart

            // 检查是否以标识符起始字符开头
            if (JSLexer.isIdentifierStart(char: label[varEnd])) {
                varEnd += 1

                // 读取标识符和点号路径
                while (varEnd < label.length) {
                    let c = label[varEnd]
                    if (c == '.') {
                        if (varEnd + 1 < label.length && JSLexer.isIdentifierContinue(char: label[varEnd + 1])) {
                            varEnd += 1
                        } else {
                            break
                        }
                    } else if (JSLexer.isIdentifierContinue(char: c)) {
                        varEnd += 1
                    } else {
                        break
                    }
                }

                let varPath = label[varStart..varEnd]
                let value = functionArgs[0].getIfPropertyExistsFromPath(
                    global: globalThis,
                    path: BunString.`init`(data: varPath).toJS(global: globalThis)
                )

                if (value != None && !value.getOrThrow().isEmptyOrUndefinedOrNull()) {
                    // 原始字符串直接输出，避免引号
                    if (value.getOrThrow().isString()) {
                        let slice = value.getOrThrow().toSlice(global: globalThis)
                        result.append(slice)
                    } else {
                        let formatter = makeFormatter(global: globalThis)
                        result.append(formatter.format(value: value.getOrThrow()))
                    }
                    idx = varEnd
                    idx += 1
                    continue
                }
            } else {
                // 不是有效的标识符起始，跳过
                while (varEnd < label.length && JSLexer.isIdentifierContinue(char: label[varEnd]) && label[varEnd] != '$') {
                    varEnd += 1
                }
            }

            result.append('$')
            result.append(label[varStart..varEnd])
            idx = varEnd
        } else if (char == '%' && (idx + 1 < label.length) && !(argsIdx >= functionArgs.size)) {
            let currentArg = functionArgs[argsIdx]

            match (label[idx + 1]) {
                case 's' =>
                    if (!currentArg.isEmpty() && currentArg.isString()) {
                        result.append(currentArg.toSlice(global: globalThis))
                    } else {
                        result.append("%s")
                    }
                    idx += 1
                    argsIdx += 1
                case 'i' =>
                    if (currentArg.isAnyInt()) {
                        result.append(currentArg.toSlice(global: globalThis))
                    } else {
                        result.append("%i")
                    }
                    idx += 1
                    argsIdx += 1
                case 'd' =>
                    if (currentArg.isNumber()) {
                        result.append(currentArg.toSlice(global: globalThis))
                    } else {
                        result.append("%d")
                    }
                    idx += 1
                    argsIdx += 1
                case 'f' =>
                    if (currentArg.isNumber()) {
                        result.append(currentArg.toSlice(global: globalThis))
                    } else {
                        result.append("%f")
                    }
                    idx += 1
                    argsIdx += 1
                case 'j' | 'o' =>
                    // JSON字符串化
                    let jsonStr = currentArg.jsonStringifyFast(global: globalThis)
                    result.append(jsonStr)
                    idx += 1
                    argsIdx += 1
                case 'p' =>
                    let formatter = makeFormatter(global: globalThis)
                    result.append(formatter.format(value: currentArg))
                    idx += 1
                    argsIdx += 1
                case '#' =>
                    result.append(testIdx.toString())
                    idx += 1
                case '%' =>
                    result.append('%')
                    idx += 1
                case _ =>
                    // 忽略未识别的格式
                    break
            }
        } else {
            result.append(char)
        }
        idx += 1
    }

    return result.toString()
}

/// 捕获测试行号
///
/// 当使用JUnit reporter时，通过CallFrame获取当前调用的行号。
/// 否则返回0。
public func captureTestLineNumber(callFrame: CallFrame, globalThis: JSGlobalObject): UInt32 {
    if (let Some(runner) <- Jest.runner) {
        if (runner.testOptions.reporters.junit) {
            return CallFrame.getLineNumber(callFrame: callFrame, global: globalThis)
        }
    }
    return 0
}

/// CI环境中的错误
///
/// 如果在CI环境中运行，抛出错误提示用户设置CI=false来覆盖。
public func errorInCI(globalObject: JSGlobalObject, message: String): ?JSValue {
    if (CIInfo.isCI()) {
        globalObject.`throw`(message: (message) + "\nTo override, set the environment variable CI=false.")
        return None
    }
    return JSValue.jsUndefined
}
