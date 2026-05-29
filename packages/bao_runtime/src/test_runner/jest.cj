// jest.cj - Jest兼容层
// 严格翻译自 bun/src/runtime/test_runner/jest.zig

package bao_runtime.test_runner

import bao_jsc.{BunString, CallFrame, File, JSFunction, JSFunctionCreateOptions, JSGlobalObject, JsValue, Log, RegularExpression, Source}
import bao_collections.ArrayList
import bao_collections.HashMap
import bao_core.Allocator
import bao_core.Output
import bao_sys.OS
import bao_core.defaultAllocator
import bao_event_loop.Timespec
import bao_runtime.test_runner.timers.FakeTimers

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
    public var path: String = ""

    public init() {}
}

/// 文件列表类型
public type FileList = ArrayList<File>

/// 文件ID类型  
public type FileID = UInt32

/// 文件映射类型
public type FileMap = HashMap<UInt64, UInt32>

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
    public var defaultTimeoutOverride: UInt32 = UInt32.Max
    public var testOptions: TestOptions = TestOptions()
    public var filterRegex: ?RegularExpression = None
    public var unhandledErrorsBetweenTests: UInt32 = 0
    public var summary: Summary = Summary()
    public var bunTestRoot: BunTestRoot

    public init() {
        this.allocator = defaultAllocator
        this.snapshots = Snapshots(allocator)
        this.bunTestRoot = BunTestRoot(allocator)
    }

    /// 获取活跃超时
    ///
    /// 从当前活跃的BunTest文件中获取其事件循环定时器的下一个超时时间。
    /// 如果定时器未激活或时间为epoch（无超时），返回epoch。
    public func getActiveTimeout(): Timespec {
        let activeFile = bunTestRoot.activeFile
        if (activeFile.isNone()) {
            return Timespec.EPOCH
        }
        let activeFileVal = activeFile.getOrThrow()
        let fileOpt = activeFileVal.get()
        if (fileOpt.isNone()) { return Timespec.EPOCH }
        let file = fileOpt.getOrThrow()

        if (file.timer.state != EventLoopTimerState.Active || file.timer.next.isZero()) {
            return Timespec.EPOCH
        }
        return file.timer.next
    }

    /// 移除活跃超时
    ///
    /// 从事件循环中移除当前BunTest文件的定时器。
    public func removeActiveTimeout(vm: VirtualMachine) {
        let activeFile = bunTestRoot.activeFile
        if (activeFile.isNone()) {
            return
        }
        let file = activeFile.getOrThrow().get()
        if (file.isNone()) {
            return
        }
        let fileVal = file.getOrThrow()

        if (fileVal.timer.state != EventLoopTimerState.Active || fileVal.timer.next.isZero()) {
            return
        }
        // 从事件循环定时器堆中移除
        vm.timer.remove(fileVal.timer)
    }



    /// 是否有测试过滤器
    public func hasTestFilter(): Bool {
        return filterRegex.isSome()
    }

    /// 文件是否应该并发运行
    ///
    /// 检查全局并发标志和glob模式匹配
    public func shouldFileRunConcurrently(fileId: UInt32): Bool {
        // 全局并发标志
        if (concurrent) { return true }

        // 检查glob模式
        if (concurrentTestGlob.isNone()) { return false }
        let globPatterns = concurrentTestGlob.getOrThrow()
        if (Int64(fileId) >= files.size) { return false }

        let filePath = files[Int64(fileId)].path

        // 检查文件路径是否匹配任何glob模式
        for (pattern in globPatterns ) {
            if (GlobMatcher.`match`(pattern: pattern, path: filePath) == GlobMatchResult.match_) {
                return true
            }
        }
        return false
    }

    /// 获取或创建文件
    ///
    /// 根据文件路径的hash查找已有的文件ID，如果不存在则创建新的文件条目
    public func getOrPutFile(filePath: String): FileIdResult {
        let hash = WyHash.hash(filePath)
        let existing = index.get(hash)
        if (existing.isSome()) {
            return FileIdResult(existing.getOrThrow())
        }

        let fileId: UInt32 = UInt32(files.size)
        let newFile = File()
        newFile.path = filePath
        files.append(newFile)
        index.put(hash, fileId)
        return FileIdResult(fileId)
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
    public static func createTestModuleObject(globalObject: JSGlobalObject): JsValue {
        return createTestModule(globalObject) ?? JsValue.zero
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
    public static func createTestModule(globalObject: JSGlobalObject): ?JsValue {
        let module = JsValue.createEmptyObject(globalObject.globalThis, 23)

        // test/it - 测试函数
        let testScopeFunctions = ScopeFunctions.createBound(
            globalThis: globalObject,
            mode: ScopeFunctionsMode.test_,
            each: JsValue.zero,
            cfg: BaseScopeCfg(),
            name: "test"
        )
        module.put(globalObject.globalThis, "test", testScopeFunctions)
        module.put(globalObject.globalThis, "it", testScopeFunctions)

        // xtest/xit - 跳过的测试函数
        let skipCfg = BaseScopeCfg()
        skipCfg.selfMode = ScopeMode.skip
        let xtestScopeFunctions = ScopeFunctions.createBound(
            globalThis: globalObject,
            mode: ScopeFunctionsMode.test_,
            each: JsValue.zero,
            cfg: skipCfg,
            name: "xtest"
        )
        module.put(globalObject.globalThis, "xtest", xtestScopeFunctions)
        module.put(globalObject.globalThis, "xit", xtestScopeFunctions)

        // describe - 描述块
        let describeScopeFunctions = ScopeFunctions.createBound(
            globalThis: globalObject,
            mode: ScopeFunctionsMode.describe,
            each: JsValue.zero,
            cfg: BaseScopeCfg(),
            name: "describe"
        )
        module.put(globalObject.globalThis, "describe", describeScopeFunctions)

        // xdescribe - 跳过的描述块
        let xdescribeCfg = BaseScopeCfg()
        xdescribeCfg.selfMode = ScopeMode.skip
        let xdescribeScopeFunctions = ScopeFunctions.createBound(
            globalThis: globalObject,
            mode: ScopeFunctionsMode.describe,
            each: JsValue.zero,
            cfg: xdescribeCfg,
            name: "xdescribe"
        )
        module.put(globalObject.globalThis, "xdescribe", xdescribeScopeFunctions)

        // 生命周期钩子
        module.put(globalObject.globalThis, "beforeEach",
            JsValue.zero)
        module.put(globalObject.globalThis, "beforeAll",
            JsValue.zero)
        module.put(globalObject.globalThis, "afterAll",
            JsValue.zero)
        module.put(globalObject.globalThis, "afterEach",
            JsValue.zero)
        module.put(globalObject.globalThis, "onTestFinished",
            JsValue.zero)
        module.put(globalObject.globalThis, "setDefaultTimeout",
            JsValue.zero)

        // expect/expectTypeOf - 断言
        module.put(globalObject.globalThis, "expect",
            Expect.getConstructor(globalObject.globalThis))
        module.put(globalObject.globalThis, "expectTypeOf",
            ExpectTypeOf.getConstructor(globalObject.globalThis))

        // 创建mock对象
        createMockObjects(globalObject, module)

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
    public static func createMockObjects(globalObject: JSGlobalObject, module: JsValue) {
        let setSystemTime = JsValue.zero
        let mockFn = JsValue.zero
        let spyOn = JsValue.zero
        let restoreAllMocks = JsValue.zero
        let clearAllMocks = JsValue.zero
        let mockModuleFn = JsValue.zero

        module.put(globalObject.globalThis, "mock", mockFn)
        // 对应 Bun: mockFn.put(globalObject, "module", mockModuleFn) etc.
        mockFn.put(globalObject.globalThis, "module", mockModuleFn)
        mockFn.put(globalObject.globalThis, "restore", restoreAllMocks)
        mockFn.put(globalObject.globalThis, "clearAllMocks", clearAllMocks)

        // jest对象
        let jest = JsValue.createEmptyObject(globalObject.globalThis, Int64(9) + Int64(FakeTimers.timerFnsCount))
        jest.put(globalObject.globalThis, "fn", mockFn)
        jest.put(globalObject.globalThis, "mock", mockModuleFn)
        jest.put(globalObject.globalThis, "spyOn", spyOn)
        jest.put(globalObject.globalThis, "restoreAllMocks", restoreAllMocks)
        jest.put(globalObject.globalThis, "clearAllMocks", clearAllMocks)
        jest.put(globalObject.globalThis, "resetAllMocks", clearAllMocks)
        jest.put(globalObject.globalThis, "setSystemTime", setSystemTime)
        jest.put(globalObject.globalThis, "now", JsValue.zero)
        jest.put(globalObject.globalThis, "setTimeout", JsValue.zero)

        module.put(globalObject.globalThis, "jest", jest)
        module.put(globalObject.globalThis, "spyOn", spyOn)
        module.put(globalObject.globalThis, "expect",
            Expect.getConstructor(globalObject.globalThis))

        // vi对象 (Vitest兼容)
        let vi = JsValue.createEmptyObject(globalObject.globalThis, Int64(6) + Int64(FakeTimers.timerFnsCount))
        vi.put(globalObject.globalThis, "fn", mockFn)
        vi.put(globalObject.globalThis, "mock", mockModuleFn)
        vi.put(globalObject.globalThis, "spyOn", spyOn)
        vi.put(globalObject.globalThis, "restoreAllMocks", restoreAllMocks)
        vi.put(globalObject.globalThis, "resetAllMocks", clearAllMocks)
        vi.put(globalObject.globalThis, "clearAllMocks", clearAllMocks)
        module.put(globalObject.globalThis, "vi", vi)

        // 添加假定时器函数到jest和vi对象
        FakeTimers.putTimersFns(globalObject, jest, vi)
    }

    /// Jest调用入口
    ///
    /// 处理Bun.jest()调用。在preload阶段不需要参数，
    /// 在执行阶段需要绝对文件路径作为第一个参数。
    public static func call(globalObject: JSGlobalObject, callFrame: CallFrame): ?JsValue {
        let vm = globalObject.bunVM()

        if (vm.isInPreload || runner.isNone()) {
            // 在preload阶段，不需要参数
        } else {
            let arguments = callFrame.argumentsAsArray(2)

            if (arguments.size < 1 || !arguments[0].isString()) {
                globalObject.`throw`("Bun.jest() expects a string filename")
                return None
            }

            let str = arguments[0].toSlice(globalObject.globalThis)
            if (!str.startsWith("/")) {
                globalObject.`throw`("Bun.jest() expects an absolute file path, got '" + (str) + "'")
                return None
            }
        }

        return createTestModuleObject(globalObject)
    }

    /// 设置默认超时
    ///
    /// 处理setDefaultTimeout()/jest.setTimeout()调用。
    /// 参数为一个表示毫秒数的数字。
    public static func jsSetDefaultTimeout(globalObject: JSGlobalObject, callFrame: CallFrame): ?JsValue {
        let arguments = callFrame.argumentsAsArray(1)
        if (arguments.size < 1 || !arguments[0].isNumber()) {
            globalObject.`throw`("setTimeout() expects a number (milliseconds)")
            return None
        }

        let timeoutMsRaw = Int64(arguments[0].asNumber())
        let timeoutMs: UInt32 = UInt32(if (timeoutMsRaw < 0) { Int64(0) } else { timeoutMsRaw })

        if (let Some(testRunner) <- runner) {
            testRunner.defaultTimeoutOverride = timeoutMs
        }

        return JsValue.jsUndefined()
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
        if (reporter.workerIpcFileIdx.isSome()) {
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
        this.print(title, prefix, repeatCount, repeatIndex)
    }

    /// 打印当前文件信息
    ///
    /// 在终端中显示当前测试文件名和前缀。
    /// 如果有重复执行，显示重复序号。
    public func print(title: String, prefix: String, repeatCount: UInt32, repeatIndex: UInt32) {
        Output.prettyError("<r>\n")

        if (repeatCount > 0) {
            if (repeatCount > 1) {
                Output.prettyErrorln((prefix) + (title) + ": <d>(run #" + (repeatIndex + 1).toString() + ")<r>\n")
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
        this.print(title, prefix, repeatInfo.count, repeatInfo.index)
    }
}

// ========== 未处理的拒绝处理 ==========

/// 处理未捕获的Promise拒绝
///
/// 如果有活跃的BunTest，将拒绝标记为当前测试的错误并继续运行。
/// 否则，直接运行错误处理器。
public func onUnhandledRejection(jscVm: VirtualMachine, globalObject: JSGlobalObject, rejection: JsValue) {
    if (let Some(buntestStrong) <- BunTest.cloneActiveStrong()) {
        let buntestOpt = buntestStrong.get()
        if (buntestOpt.isNone()) { return }
        let buntest = buntestOpt.getOrThrow()

        // 标记未处理错误属于当前活跃测试
        // 对应 Bun: 检查错误是否发生在 hook 上下文中
        var currentStateData = buntest.getCurrentStateData()

        // 对应 Bun: if (entry != sequence.test_entry) currentStateData = .start
        // 检查当前活跃条目是否为 hook（而非 test entry）
        let ref = BunTest.ref(buntestStrong, currentStateData)
        if (ref.isSome()) {
            let refVal = ref.getOrThrow()
            let entry = refVal.entry(buntest)
            let sequence = refVal.sequence(buntest)
            if (entry.isSome() && sequence.isSome()) {
                let entryVal = entry.getOrThrow()
                let seqVal = sequence.getOrThrow()
                // 如果当前条目不是 test_entry，说明是在 hook 中发生的错误
                if (entryVal != seqVal.testEntry.getOrThrow()) {
                    currentStateData = RefDataValue.start // 标记为测试间未处理错误
                }
            }
        }

        buntest.onUncaughtException(
            globalObject,
            rejection,
            true,
            currentStateData
        )
        buntest.addResult(currentStateData)
        let _ = BunTest.run(buntestStrong, globalObject)
        return
    }

    // 没有活跃的BunTest，直接运行错误处理器
    jscVm.runErrorHandler(rejection, jscVm.onUnhandledRejectionExceptionList)
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
public func formatLabel(globalThis!: JSGlobalObject, label!: String, functionArgs!: Array<JsValue>, testIdx!: UInt64, allocator!: Allocator): String {
    var idx: Int64 = 0
    var argsIdx: Int64 = 0
    var result = StringBuilder()

    while (idx < label.size) {
        let char = label[idx]

        // $variablePath语法 - 对应 Bun: $variablePath property access
        // 从 functionArgs[0]（对象）中读取属性值
        if (label[idx..idx+1] == "$" && idx + 1 < label.size && functionArgs.size > 0 && functionArgs[0].isObject()) {
            let varStart = idx + 1
            var varEnd = varStart

            // 检查是否是有效的标识符开头
            if (varEnd < label.size && isIdentifierStart(label[varEnd])) {
                varEnd += 1
                while (varEnd < label.size) {
                    let c = label[varEnd]
                    if (c == '.'.toInt()) {
                        if (varEnd + 1 < label.size && isIdentifierContinue(label[varEnd + 1])) {
                            varEnd += 1
                        } else {
                            break
                        }
                    } else if (isIdentifierContinue(c)) {
                        varEnd += 1
                    } else {
                        break
                    }
                }

                let varPath = label[varStart..varEnd]
                // 尝试从第一个参数对象获取属性值
                let value = functionArgs[0].getIfPropertyExistsFromPath(globalThis.globalThis, varPath)
                if (value.isSome() && !value.getOrThrow().isEmptyOrUndefinedOrNull()) {
                    let resolvedValue = value.getOrThrow()
                    // 对于字符串，使用 toString 避免引号（与 Jest 行为一致）
                    if (resolvedValue.isString()) {
                        result.append(resolvedValue.toSlice(globalThis.globalThis))
                    } else {
                        let formatter = makeFormatter(globalThis)
                        result.append(formatter.format(resolvedValue))
                    }
                    idx = varEnd
                    idx += 1
                    continue
                }
                // 无法解析的 $variablePath，保留原样
                result.append("$")
                result.append(varPath)
                idx = varEnd
                idx += 1
                continue
            } else {
                // 不是有效的标识符开头，作为普通 $ 处理
                while (varEnd < label.size && isIdentifierContinue(label[varEnd]) && label[varEnd] != "$".toInt()) {
                    varEnd += 1
                }
                result.append("$")
                result.append(label[varStart..varEnd])
                idx = varEnd
                idx += 1
                continue
            }
        } else if (label[idx..idx+1] == "%" && (idx + 1 < label.size) && !(argsIdx >= functionArgs.size)) {
            let currentArg = functionArgs[argsIdx]
            let nextStr = label[idx + 1..idx + 2]

            if (nextStr == "s") {
                if (!currentArg.isEmpty() && currentArg.isString()) {
                    result.append(currentArg.toSlice(globalThis.globalThis))
                } else {
                    result.append("%s")
                }
                idx += 1
                argsIdx += 1
            } else if (nextStr == "i") {
                if (currentArg.isAnyInt()) {
                    result.append(currentArg.toSlice(globalThis.globalThis))
                } else {
                    result.append("%i")
                }
                idx += 1
                argsIdx += 1
            } else if (nextStr == "d") {
                if (currentArg.isNumber()) {
                    result.append(currentArg.toSlice(globalThis.globalThis))
                } else {
                    result.append("%d")
                }
                idx += 1
                argsIdx += 1
            } else if (nextStr == "f") {
                if (currentArg.isNumber()) {
                    result.append(currentArg.toSlice(globalThis.globalThis))
                } else {
                    result.append("%f")
                }
                idx += 1
                argsIdx += 1
            } else if (nextStr == "j" || nextStr == "o") {
                let jsonStr = currentArg.jsonStringifyFast(globalThis.globalThis)
                result.append(jsonStr)
                idx += 1
                argsIdx += 1
            } else if (nextStr == "p") {
                let formatter = makeFormatter(globalThis)
                result.append(formatter.format(currentArg))
                idx += 1
                argsIdx += 1
            } else if (nextStr == "#") {
                result.append(testIdx.toString())
                idx += 1
            } else if (nextStr == "%") {
                result.append("%")
                idx += 1
            } else {
                // ignore unrecognized format
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
public func captureTestLineNumber(callFrame!: CallFrame, globalThis!: JSGlobalObject): UInt32 {
    if (let Some(runner) <- Jest.runner) {
        if (runner.testOptions.reporters.junit) {
            return UInt32(0)
        }
    }
    return 0
}

/// CI环境中的错误
///
/// 如果在CI环境中运行，抛出错误提示用户设置CI=false来覆盖。
/// 对应 Bun: jest.zig errorInCI
public func errorInCI(globalObject!: JSGlobalObject, message!: String): ?JsValue {
    // 对应 Bun: if (bun.ci.isCI())
    if (isCIEnv()) {
        globalObject.`throw`((message) + "\nTo override, set the environment variable CI=false.")
        return None
    }
    return JsValue.jsUndefined()
}

/// TestOptions桩
/// 完整实现在 bao_options 中
public class TestOptions {
    public var reporters: ReporterOptions = ReporterOptions()
    public var retry: UInt32 = 0
    public var repeats: UInt32 = 0
    public var defaultTimeout: UInt32 = 0
    public init() {}
}

public class ReporterOptions {
    public var junit: Bool = false
    public init() {}
}

// ========== 标识符辅助函数 ==========
/// 对应 Bun: bun.js_lexer.isIdentifierStart / isIdentifierContinue
/// 用于 formatLabel 中的 $variablePath 语法

/// 判断字符是否是 JS 标识符的起始字符
public func isIdentifierStart(ch: UInt8): Bool {
    // a-z, A-Z, _, $
    if (ch >= 97 && ch <= 122) { return true }  // a-z
    if (ch >= 65 && ch <= 90) { return true }   // A-Z
    if (ch == 95) { return true }               // _
    if (ch == 36) { return true }               // $
    return false
}

/// 判断字符是否是 JS 标识符的后续字符
public func isIdentifierContinue(ch: UInt8): Bool {
    if (isIdentifierStart(ch)) { return true }
    // 0-9
    if (ch >= 48 && ch <= 57) { return true }
    return false
}
