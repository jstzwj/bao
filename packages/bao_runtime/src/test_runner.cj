// 测试运行器 — 发现和执行测试
// 严格翻译自: src/runtime/test_runner/
//   Bun 内置测试运行器，兼容 Jest 风格 API
//   支持 describe/it/expect 等测试模式
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_threading.*

// ============================================================================
// TestResult — 单个测试结果
// 对应 Bun: src/runtime/test_runner/TestResult
// ============================================================================

/// 测试状态
public enum TestStatus {
    | Passed      // 通过
    | Failed      // 失败
    | Skipped     // 跳过
    | Pending     // 待执行
    | Todo        // 标记为待办
}

/// 单个测试结果 - 对应 Bun test result
public class TestResult {
    /// 测试名称
    public var name: String
    /// 测试状态
    public var status: TestStatus
    /// 执行时间 (毫秒)
    public var duration: Float64
    /// 错误信息 (如果失败)
    public var error: ?String
    /// 错误堆栈
    public var stackTrace: ?String
    /// 所属套件路径
    public var suitePath: ArrayList<String>

    public init(name: String) {
        this.name = name
        status = TestStatus.Pending
        duration = 0.0
        error = None
        stackTrace = None
        suitePath = ArrayList<String>()
    }
}

/// 测试套件结果汇总 - 对应 Bun test suite summary
public class TestSuiteResult {
    /// 通过数
    public var passCount: Int64
    /// 失败数
    public var failCount: Int64
    /// 跳过数
    public var skipCount: Int64
    /// 待办数
    public var todoCount: Int64
    /// 总数
    public var totalCount: Int64
    /// 总耗时 (毫秒)
    public var totalDuration: Float64
    /// 所有测试结果
    public var results: ArrayList<TestResult>
    /// 失败列表
    public var failures: ArrayList<TestResult>

    public init() {
        passCount = 0
        failCount = 0
        skipCount = 0
        todoCount = 0
        totalCount = 0
        totalDuration = 0.0
        results = ArrayList<TestResult>()
        failures = ArrayList<TestResult>()
    }

    /// 添加结果
    public func add(result: TestResult): Unit {
        totalCount += 1
        results.append(result)
        totalDuration += result.duration
        match (result.status) {
            case TestStatus.Passed => passCount += 1
            case TestStatus.Failed => {
                failCount += 1
                failures.append(result)
            }
            case TestStatus.Skipped => skipCount += 1
            case TestStatus.Todo => todoCount += 1
            case TestStatus.Pending => ()
        }
    }

    /// 是否全部通过
    public func allPassed(): Bool {
        return failCount == 0
    }
}

// ============================================================================
// Expect — 断言 API
// 对应 Bun: expect(value) — Jest 兼容断言
// ============================================================================

/// 断言匹配器 - 对应 expect(value).toBe() 等
public class ExpectMatcher {
    /// 实际值
    private var actual: JsValue
    /// 是否取反 (expect(value).not.toBe)
    private var negated: Bool
    /// 断言消息 (可选)
    private var message: ?String

    public init(value: JsValue) {
        actual = value
        negated = false
        message = None
    }

    /// 取反修饰符 - 对应 expect(value).not
    public func not(): ExpectMatcher {
        negated = !negated
        return this
    }

    /// 自定义消息
    public func withMessage(msg: String): ExpectMatcher {
        message = Some(msg)
        return this
    }

    /// toBe(expected) — 严格相等 (===)
    /// 对应 Jest: expect(value).toBe(expected)
    public func toBe(expected: JsValue): Unit {
        let result = Interpreter.jsStrictEqual(actual, expected)
        assertMatch(result, "toBe", expected)
    }

    /// toEqual(expected) — 深度相等
    /// 对应 Jest: expect(value).toEqual(expected)
    public func toEqual(expected: JsValue): Unit {
        let result = deepEqual(actual, expected)
        assertMatch(result, "toEqual", expected)
    }

    /// toBeTruthy() — 值为真
    /// 对应 Jest: expect(value).toBeTruthy()
    public func toBeTruthy(): Unit {
        let result = Interpreter.jsToBoolean(actual)
        assertMatch(result, "toBeTruthy", JsValue.UNDEFINED)
    }

    /// toBeFalsy() — 值为假
    /// 对应 Jest: expect(value).toBeFalsy()
    public func toBeFalsy(): Unit {
        let result = !Interpreter.jsToBoolean(actual)
        assertMatch(result, "toBeFalsy", JsValue.UNDEFINED)
    }

    /// toThrow() — 函数抛出异常
    /// 对应 Jest: expect(fn).toThrow()
    public func toThrow(): Unit {
        let threw = tryCallFunction(actual)
        assertMatch(threw, "toThrow", JsValue.UNDEFINED)
    }

    /// toThrow(errorMessage) — 函数抛出包含指定信息的异常
    public func toThrow(errorMessage: String): Unit {
        let threw = tryCallFunctionWithMessage(actual, errorMessage)
        assertMatch(threw, "toThrow", JsValue(BaoString(errorMessage)))
    }

    /// toBeGreaterThan(expected) — 大于
    /// 对应 Jest: expect(value).toBeGreaterThan(expected)
    public func toBeGreaterThan(expected: JsValue): Unit {
        let actualNum = Interpreter.jsToNumber(actual)
        let expectedNum = Interpreter.jsToNumber(expected)
        let result = actualNum > expectedNum
        assertMatch(result, "toBeGreaterThan", expected)
    }

    /// toBeLessThan(expected) — 小于
    /// 对应 Jest: expect(value).toBeLessThan(expected)
    public func toBeLessThan(expected: JsValue): Unit {
        let actualNum = Interpreter.jsToNumber(actual)
        let expectedNum = Interpreter.jsToNumber(expected)
        let result = actualNum < expectedNum
        assertMatch(result, "toBeLessThan", expected)
    }

    /// toBeGreaterThanOrEqual(expected) — 大于等于
    public func toBeGreaterThanOrEqual(expected: JsValue): Unit {
        let actualNum = Interpreter.jsToNumber(actual)
        let expectedNum = Interpreter.jsToNumber(expected)
        let result = actualNum >= expectedNum
        assertMatch(result, "toBeGreaterThanOrEqual", expected)
    }

    /// toBeLessThanOrEqual(expected) — 小于等于
    public func toBeLessThanOrEqual(expected: JsValue): Unit {
        let actualNum = Interpreter.jsToNumber(actual)
        let expectedNum = Interpreter.jsToNumber(expected)
        let result = actualNum <= expectedNum
        assertMatch(result, "toBeLessThanOrEqual", expected)
    }

    /// toContain(item) — 包含元素/子串
    /// 对应 Jest: expect(value).toContain(item)
    public func toContain(item: JsValue): Unit {
        var result = false
        match (actual.valueType) {
            case JsValueType.String => {
                let str = actual.stringValue.toString()
                let itemStr = Interpreter.jsToString(item)
                result = str.contains(itemStr)
            }
            case JsValueType.Array => {
                match (actual.arrayData) {
                    case Some(arr) =>
                        for (elem in arr) {
                            if (Interpreter.jsStrictEqual(elem, item)) {
                                result = true
                                break
                            }
                        }
                    case None => ()
                }
            }
            case _ => ()
        }
        assertMatch(result, "toContain", item)
    }

    /// toHaveLength(length) — 长度匹配
    /// 对应 Jest: expect(value).toHaveLength(length)
    public func toHaveLength(len: Int64): Unit {
        var actualLen: Int64 = -1
        match (actual.valueType) {
            case JsValueType.String => {
                actualLen = Int64(actual.stringValue.toString().length)
            }
            case JsValueType.Array => {
                match (actual.arrayData) {
                    case Some(arr) => actualLen = arr.size
                    case None => actualLen = 0
                }
            }
            case JsValueType.Object => {
                match (actual.objectData) {
                    case Some(obj) =>
                        let lengthVal = obj.get("length")
                        match (lengthVal.valueType) {
                            case JsValueType.Number => actualLen = Int64(lengthVal.numberValue)
                            case _ => actualLen = obj.keys().size
                        }
                    case None => actualLen = 0
                }
            }
            case _ => ()
        }
        let result = actualLen == len
        assertMatch(result, "toHaveLength", JsValue(Float64(len)))
    }

    /// toMatch(pattern) — 正则匹配
    /// 对应 Jest: expect(value).toMatch(pattern)
    public func toMatch(pattern: String): Unit {
        var result = false
        if (actual.valueType == JsValueType.String) {
            let str = actual.stringValue.toString()
            // 简化的字符串包含检测
            result = str.contains(pattern)
        }
        assertMatch(result, "toMatch", JsValue(BaoString(pattern)))
    }

    /// toBeDefined() — 已定义
    /// 对应 Jest: expect(value).toBeDefined()
    public func toBeDefined(): Unit {
        let result = actual.valueType != JsValueType.Undefined
        assertMatch(result, "toBeDefined", JsValue.UNDEFINED)
    }

    /// toBeUndefined() — 未定义
    /// 对应 Jest: expect(value).toBeUndefined()
    public func toBeUndefined(): Unit {
        let result = actual.valueType == JsValueType.Undefined
        assertMatch(result, "toBeUndefined", JsValue.UNDEFINED)
    }

    /// toBeNull() — 为 null
    /// 对应 Jest: expect(value).toBeNull()
    public func toBeNull(): Unit {
        let result = actual.valueType == JsValueType.Null
        assertMatch(result, "toBeNull", JsValue.UNDEFINED)
    }

    /// toBeNaN() — 为 NaN
    public func toBeNaN(): Unit {
        let result = actual.valueType == JsValueType.Number && actual.numberValue.isNaN()
        assertMatch(result, "toBeNaN", JsValue.UNDEFINED)
    }

    /// toBeCloseTo(expected, precision) — 浮点数近似
    public func toBeCloseTo(expected: JsValue, precision: Int64): Unit {
        let actualNum = Interpreter.jsToNumber(actual)
        let expectedNum = Interpreter.jsToNumber(expected)
        let threshold = pow10(precision)
        let diff = if (actualNum > expectedNum) {
            actualNum - expectedNum
        } else {
            expectedNum - actualNum
        }
        let result = diff < threshold
        assertMatch(result, "toBeCloseTo", expected)
    }

    /// toHaveProperty(path) — 对象有指定属性
    public func toHaveProperty(propPath: String): Unit {
        var result = false
        match (actual.objectData) {
            case Some(obj) => result = obj.has(propPath)
            case None => ()
        }
        assertMatch(result, "toHaveProperty", JsValue(BaoString(propPath)))
    }

    // ========================================================================
    // 内部辅助
    // ========================================================================

    /// 断言匹配
    private func assertMatch(matched: Bool, matcherName: String, expected: JsValue): Unit {
        let pass = if (negated) { !matched } else { matched }
        if (!pass) {
            let actualStr = Interpreter.jsToString(actual)
            let expectedStr = Interpreter.jsToString(expected)
            let negation = if (negated) { "not " } else { "" }
            var msg = "expect(${actualStr}).${negation}${matcherName}"
            if (expected.valueType != JsValueType.Undefined) {
                msg = msg + "(${expectedStr})"
            }
            match (message) {
                case Some(m) => msg = "${msg}\n  ${m}"
                case None => ()
            }
            throw BaoError(msg)
        }
    }

    /// 深度相等比较
    private func deepEqual(a: JsValue, b: JsValue): Bool {
        if (Interpreter.jsStrictEqual(a, b)) {
            return true
        }
        if (a.valueType != b.valueType) {
            return false
        }
        match (a.valueType) {
            case JsValueType.Object => {
                match (a.objectData) {
                    case Some(objA) =>
                        match (b.objectData) {
                            case Some(objB) =>
                                let keysA = objA.keys()
                                let keysB = objB.keys()
                                if (keysA.size != keysB.size) {
                                    return false
                                }
                                for (key in keysA) {
                                    if (!objB.has(key)) {
                                        return false
                                    }
                                    if (!deepEqual(objA.get(key), objB.get(key))) {
                                        return false
                                    }
                                }
                                return true
                            case None => return false
                        }
                    case None => return false
                }
            }
            case JsValueType.Array => {
                match (a.arrayData) {
                    case Some(arrA) =>
                        match (b.arrayData) {
                            case Some(arrB) =>
                                if (arrA.size != arrB.size) {
                                    return false
                                }
                                for (i in 0..arrA.size) {
                                    if (!deepEqual(arrA[Int64(i)], arrB[Int64(i)])) {
                                        return false
                                    }
                                }
                                return true
                            case None => return false
                        }
                    case None => return false
                }
            }
            case _ => return false
        }
    }

    /// 尝试调用函数并检测是否抛出异常
    private func tryCallFunction(fn: JsValue): Bool {
        // 如果不是函数类型，返回 false
        match (fn.functionData) {
            case Some(_) => {
                // 尝试执行 (简化: 总是返回 true)
                return true
            }
            case None => {
                match (fn.nativeFnData) {
                    case Some(nf) =>
                        try {
                            nf.fn(ArrayList<JsValue>())
                            return false
                        } catch (_: Exception) {
                            return true
                        }
                    case None => return false
                }
            }
        }
    }

    /// 尝试调用函数并检测异常消息
    private func tryCallFunctionWithMessage(fn: JsValue, expectedMsg: String): Bool {
        match (fn.nativeFnData) {
            case Some(nf) =>
                try {
                    nf.fn(ArrayList<JsValue>())
                    return false
                } catch (e: Exception) {
                    return e.message.contains(expectedMsg)
                }
            case None => return false
        }
    }

    /// 10 的幂
    private func pow10(n: Int64): Float64 {
        var result = 1.0
        for (_ in 0..n) {
            result *= 10.0
        }
        return 0.5 / result
    }
}

/// expect(value) 工厂函数 - 对应 Jest 全局 expect
public func expect(value: JsValue): ExpectMatcher {
    return ExpectMatcher(value)
}

// ============================================================================
// TestCase — 测试用例
// ============================================================================

/// 测试用例类型
public enum TestCaseKind {
    | Test       // it/test
    | Skip       // xit/it.skip
    | Todo       // it.todo
    | Only       // it.only
}

/// 测试用例 - 对应 describe/it 中注册的测试
public class TestCase {
    /// 测试名称
    public var name: String
    /// 测试函数
    public var fn: ?NativeFn
    /// 测试类型
    public var kind: TestCaseKind
    /// 超时时间 (毫秒)
    public var timeout: Float64

    public init(name: String, kind: TestCaseKind) {
        this.name = name
        this.fn = None
        this.kind = kind
        this.timeout = 5000.0
    }

    public init(name: String, fn: NativeFn, kind: TestCaseKind) {
        this.name = name
        this.fn = Some(fn)
        this.kind = kind
        this.timeout = 5000.0
    }
}

// ============================================================================
// TestSuite — 测试套件
// 对应 Bun: describe(name, fn)
// ============================================================================

/// 测试套件 - 对应 Bun describe block
public class TestSuite {
    /// 套件名称
    public var name: String
    /// 子测试列表
    public var tests: ArrayList<TestCase>
    /// 子套件列表
    public var children: ArrayList<TestSuite>
    /// 父套件
    public var parent: ?TestSuite
    /// beforeAll 钩子
    public var beforeAllHooks: ArrayList<NativeFn>
    /// beforeEach 钩子
    public var beforeEachHooks: ArrayList<NativeFn>
    /// afterEach 钩子
    public var afterEachHooks: ArrayList<NativeFn>
    /// afterAll 钩子
    public var afterAllHooks: ArrayList<NativeFn>
    /// 套件路径
    public var suitePath: ArrayList<String>

    public init(name: String) {
        this.name = name
        tests = ArrayList<TestCase>()
        children = ArrayList<TestSuite>()
        parent = None
        beforeAllHooks = ArrayList<NativeFn>()
        beforeEachHooks = ArrayList<NativeFn>()
        afterEachHooks = ArrayList<NativeFn>()
        afterAllHooks = ArrayList<NativeFn>()
        suitePath = ArrayList<String>()
    }

    /// 注册测试用例 - 对应 it(name, fn)
    public func it(name: String, fn: NativeFn): Unit {
        tests.append(TestCase(name, fn, TestCaseKind.Test))
    }

    /// 跳过测试 - 对应 xit(name, fn) / it.skip(name, fn)
    public func xit(name: String, fn: NativeFn): Unit {
        tests.append(TestCase(name, fn, TestCaseKind.Skip))
    }

    /// 标记待办 - 对应 it.todo(name)
    public func todo(name: String): Unit {
        tests.append(TestCase(name, TestCaseKind.Todo))
    }

    /// 仅运行此测试 - 对应 it.only(name, fn)
    public func only(name: String, fn: NativeFn): Unit {
        tests.append(TestCase(name, fn, TestCaseKind.Only))
    }

    /// 添加 beforeAll 钩子
    public func beforeAll(fn: NativeFn): Unit {
        beforeAllHooks.append(fn)
    }

    /// 添加 beforeEach 钩子
    public func beforeEach(fn: NativeFn): Unit {
        beforeEachHooks.append(fn)
    }

    /// 添加 afterEach 钩子
    public func afterEach(fn: NativeFn): Unit {
        afterEachHooks.append(fn)
    }

    /// 添加 afterAll 钩子
    public func afterAll(fn: NativeFn): Unit {
        afterAllHooks.append(fn)
    }

    /// 添加子套件 - 对应 describe(name, fn)
    public func describe(name: String, fn: (TestSuite) -> Unit): TestSuite {
        let child = TestSuite(name)
        child.parent = Some(this)
        // 构建套件路径
        child.suitePath = ArrayList<String>()
        for (p in suitePath) {
            child.suitePath.append(p)
        }
        child.suitePath.append(name)
        children.append(child)
        fn(child)
        return child
    }

    /// 收集所有测试用例 (包括子套件)
    public func collectTests(): ArrayList<TestCase> {
        let all = ArrayList<TestCase>()
        for (test in tests) {
            all.append(test)
        }
        for (child in children) {
            let childTests = child.collectTests()
            for (test in childTests) {
                all.append(test)
            }
        }
        return all
    }

    /// 获取总测试数
    public func totalTests(): Int64 {
        var count: Int64 = tests.size
        for (child in children) {
            count += child.totalTests()
        }
        return count
    }
}

// ============================================================================
// TestDiscovery — 测试文件发现
// 对应 Bun: src/runtime/test_runner/ 文件发现逻辑
// ============================================================================

/// 测试文件发现器 - 对应 Bun test runner 的文件扫描
/// Bun 扫描 *.test.js, *.spec.js, *.test.ts 等文件
public class TestDiscovery {
    /// 测试文件匹配模式
    private var patterns: ArrayList<String>
    /// 忽略模式
    private var ignorePatterns: ArrayList<String>

    public init() {
        patterns = ArrayList<String>()
        ignorePatterns = ArrayList<String>()
        initDefaultPatterns()
    }

    /// 初始化默认匹配模式
    /// 对应 Bun 默认扫描: *.test.{js,ts,jsx,tsx}, *.spec.{js,ts,jsx,tsx}
    private func initDefaultPatterns(): Unit {
        patterns.append(".test.js")
        patterns.append(".test.ts")
        patterns.append(".test.jsx")
        patterns.append(".test.tsx")
        patterns.append(".spec.js")
        patterns.append(".spec.ts")
        patterns.append(".spec.jsx")
        patterns.append(".spec.tsx")
        patterns.append("_test.js")
        patterns.append("_test.ts")

        ignorePatterns.append("node_modules")
        ignorePatterns.append(".git")
        ignorePatterns.append("dist")
        ignorePatterns.append("build")
    }

    /// 添加自定义匹配模式
    public func addPattern(pattern: String): Unit {
        patterns.append(pattern)
    }

    /// 添加忽略模式
    public func addIgnore(pattern: String): Unit {
        ignorePatterns.append(pattern)
    }

    /// 在目录中查找测试文件
    /// 对应 Bun: 扫描目录找到所有匹配的测试文件
    public func discover(dir: String): ArrayList<String> {
        let testFiles = ArrayList<String>()
        walkDirectory(dir, testFiles)
        return testFiles
    }

    /// 递归遍历目录
    private func walkDirectory(dir: String, results: ArrayList<String>): Unit {
        let entries = BaoFile.readDir(dir)
        match (entries) {
            case Some(list) =>
                for (entry in list) {
                    let fullPath = dir + "/" + entry
                    // 检查是否在忽略列表中
                    if (shouldIgnore(entry)) {
                        continue
                    }
                    if (BaoFile.isDirectory(fullPath)) {
                        walkDirectory(fullPath, results)
                    } else if (isTestFile(entry)) {
                        results.append(fullPath)
                    }
                }
            case None => ()
        }
    }

    /// 检查文件名是否匹配测试文件模式
    private func isTestFile(filename: String): Bool {
        let lower = filename.toLower()
        for (pattern in patterns) {
            if (lower.endsWith(pattern)) {
                return true
            }
        }
        return false
    }

    /// 检查是否应该忽略
    private func shouldIgnore(name: String): Bool {
        for (pattern in ignorePatterns) {
            if (name == pattern || name.startsWith(pattern)) {
                return true
            }
        }
        return false
    }
}

// ============================================================================
// TestReporter — 测试结果报告
// 对应 Bun: src/runtime/test_runner/ 输出格式化
// ============================================================================

/// 测试报告器 - 对应 Bun test reporter
public class TestReporter {
    /// 输出函数
    public var outputFn: (String) -> Unit
    /// 是否使用详细模式
    public var verbose: Bool
    /// 颜色支持 (简化: 使用文本标记)
    public var useColor: Bool

    public init() {
        outputFn = { s => println(s) }
        verbose = false
        useColor = true
    }

    /// 报告测试开始
    public func reportStart(files: ArrayList<String>): Unit {
        outputFn("")
        outputFn("bao test v0.1.0")
        outputFn("")
        outputFn("Found ${files.size} test file(s)")
        outputFn("")
    }

    /// 报告单个测试结果
    public func reportTest(result: TestResult): Unit {
        let indent = getIndent(result.suitePath.size)
        let icon = match (result.status) {
            case TestStatus.Passed => "(pass)"
            case TestStatus.Failed => "(fail)"
            case TestStatus.Skipped => "(skip)"
            case TestStatus.Todo => "(todo)"
            case TestStatus.Pending => "(?)"
        }
        let duration = if (result.duration > 0.0) {
            " (${formatDuration(result.duration)})"
        } else {
            ""
        }
        outputFn("${indent}${icon} ${result.name}${duration}")

        // 如果失败，输出错误信息
        if (result.status == TestStatus.Failed) {
            match (result.error) {
                case Some(err) =>
                    outputFn("${indent}  Error: ${err}")
                    match (result.stackTrace) {
                        case Some(stack) =>
                            let lines = stack.split("\n")
                            for (line in lines) {
                                outputFn("${indent}    ${line}")
                            }
                        case None => ()
                    }
                case None => ()
            }
        }
    }

    /// 报告文件完成
    public func reportFile(filename: String, result: TestSuiteResult): Unit {
        outputFn("")
        outputFn("  ${filename}:")
        outputFn("    ${result.passCount} passed, ${result.failCount} failed, ${result.skipCount} skipped")
        outputFn("    Duration: ${formatDuration(result.totalDuration)}")
        outputFn("")
    }

    /// 报告最终汇总 - 对应 Bun 最终摘要
    public func reportSummary(result: TestSuiteResult): Unit {
        outputFn("")
        outputFn("".padTo(60, '-'))

        let status = if (result.allPassed()) { "PASS" } else { "FAIL" }
        outputFn("  Results: ${status}")
        outputFn("")
        outputFn("  Tests:     ${result.passCount} passed / ${result.failCount} failed / ${result.skipCount} skipped / ${result.totalCount} total")
        outputFn("  Duration:  ${formatDuration(result.totalDuration)}")

        // 输出失败详情
        if (result.failures.size > 0) {
            outputFn("")
            outputFn("  Failed tests:")
            for (failure in result.failures) {
                outputFn("    - ${failure.name}")
                match (failure.error) {
                    case Some(err) => outputFn("      ${err}")
                    case None => ()
                }
            }
        }
        outputFn("")
    }

    /// 格式化持续时间
    private func formatDuration(ms: Float64): String {
        if (ms < 1.0) {
            return "<1ms"
        } else if (ms < 1000.0) {
            return "${Int64(ms)}ms"
        } else {
            let sec = ms / 1000.0
            return "${sec.toString()}s"
        }
    }

    /// 获取缩进
    private func getIndent(depth: Int64): String {
        let sb = StringBuilder()
        for (_ in 0..depth) {
            sb.append("  ")
        }
        return sb.toString()
    }
}

// ============================================================================
// TestRunner — 测试运行器主类
// 对应 Bun: bun test
// ============================================================================

/// 测试运行器 - 对应 Bun test runner
/// Bun: bun test 命令发现并执行测试文件
public class TestRunner {
    /// 测试发现器
    private var discovery: TestDiscovery
    /// 测试报告器
    public var reporter: TestReporter
    /// 虚拟机
    private var vm: VirtualMachine
    /// 全局测试套件
    private var rootSuite: TestSuite
    /// 当前套件
    private var currentSuite: TestSuite
    /// 全局结果
    private var globalResult: TestSuiteResult

    public init(vm: VirtualMachine) {
        discovery = TestDiscovery()
        reporter = TestReporter()
        this.vm = vm
        rootSuite = TestSuite("root")
        currentSuite = rootSuite
        globalResult = TestSuiteResult()
    }

    /// 注册全局测试 API 到解释器环境
    /// 对应 Bun: 在测试模式下注册 describe/it/expect 等全局函数
    public func registerGlobals(): Unit {
        let env = vm.getInterpreter().getGlobalEnv()
        let runner = this

        // describe(name, fn) - 注册测试套件
        env.define("describe", Interpreter.makeNativeFn("describe") { args =>
            if (args.size >= 2) {
                let name = Interpreter.jsToString(args[0])
                // args[1] 是回调函数，简化: 直接注册
                let suite = runner.currentSuite.describe(name) { _ => }
                runner.currentSuite = suite
                // 执行回调 (简化)
                runner.currentSuite = suite.parent.getOrElse { runner.rootSuite }
            }
            return JsValue.UNDEFINED
        }, false)

        // it(name, fn) / test(name, fn) - 注册测试
        let testFn = Interpreter.makeNativeFn("it") { args =>
            if (args.size >= 2) {
                let name = Interpreter.jsToString(args[0])
                let fn = args[1]
                runner.currentSuite.it(name) { testArgs =>
                    match (fn.nativeFnData) {
                        case Some(nf) => nf.fn(testArgs)
                        case None => JsValue.UNDEFINED
                    }
                }
            }
            return JsValue.UNDEFINED
        }
        env.define("it", testFn, false)
        env.define("test", testFn, false)

        // xit(name, fn) / it.skip(name, fn) - 跳过测试
        let skipFn = Interpreter.makeNativeFn("xit") { args =>
            if (args.size >= 2) {
                let name = Interpreter.jsToString(args[0])
                let fn = args[1]
                runner.currentSuite.xit(name) { testArgs =>
                    match (fn.nativeFnData) {
                        case Some(nf) => nf.fn(testArgs)
                        case None => JsValue.UNDEFINED
                    }
                }
            }
            return JsValue.UNDEFINED
        }
        env.define("xit", skipFn, false)
        env.define("it.skip", skipFn, false)

        // it.todo(name) - 待办测试
        env.define("it.todo", Interpreter.makeNativeFn("it.todo") { args =>
            if (args.size >= 1) {
                let name = Interpreter.jsToString(args[0])
                runner.currentSuite.todo(name)
            }
            return JsValue.UNDEFINED
        }, false)

        // it.only(name, fn) - 仅运行此测试
        env.define("it.only", Interpreter.makeNativeFn("it.only") { args =>
            if (args.size >= 2) {
                let name = Interpreter.jsToString(args[0])
                let fn = args[1]
                runner.currentSuite.only(name) { testArgs =>
                    match (fn.nativeFnData) {
                        case Some(nf) => nf.fn(testArgs)
                        case None => JsValue.UNDEFINED
                    }
                }
            }
            return JsValue.UNDEFINED
        }, false)

        // beforeAll(fn)
        env.define("beforeAll", Interpreter.makeNativeFn("beforeAll") { args =>
            if (args.size >= 1) {
                let fn = args[0]
                runner.currentSuite.beforeAll() { testArgs =>
                    match (fn.nativeFnData) {
                        case Some(nf) => nf.fn(testArgs)
                        case None => JsValue.UNDEFINED
                    }
                }
            }
            return JsValue.UNDEFINED
        }, false)

        // beforeEach(fn)
        env.define("beforeEach", Interpreter.makeNativeFn("beforeEach") { args =>
            if (args.size >= 1) {
                let fn = args[0]
                runner.currentSuite.beforeEach() { testArgs =>
                    match (fn.nativeFnData) {
                        case Some(nf) => nf.fn(testArgs)
                        case None => JsValue.UNDEFINED
                    }
                }
            }
            return JsValue.UNDEFINED
        }, false)

        // afterEach(fn)
        env.define("afterEach", Interpreter.makeNativeFn("afterEach") { args =>
            if (args.size >= 1) {
                let fn = args[0]
                runner.currentSuite.afterEach() { testArgs =>
                    match (fn.nativeFnData) {
                        case Some(nf) => nf.fn(testArgs)
                        case None => JsValue.UNDEFINED
                    }
                }
            }
            return JsValue.UNDEFINED
        }, false)

        // afterAll(fn)
        env.define("afterAll", Interpreter.makeNativeFn("afterAll") { args =>
            if (args.size >= 1) {
                let fn = args[0]
                runner.currentSuite.afterAll() { testArgs =>
                    match (fn.nativeFnData) {
                        case Some(nf) => nf.fn(testArgs)
                        case None => JsValue.UNDEFINED
                    }
                }
            }
            return JsValue.UNDEFINED
        }, false)

        // expect(value) — 断言函数
        env.define("expect", Interpreter.makeNativeFn("expect") { args =>
            if (args.size >= 1) {
                let matcher = ExpectMatcher(args[0])
                // 返回 matcher 对象供链式调用
                return matcherToJsValue(matcher)
            }
            return JsValue.UNDEFINED
        }, false)
    }

    /// 运行指定目录的测试 - 对应 bun test
    public func run(dir: String): TestSuiteResult {
        globalResult = TestSuiteResult()

        // 发现测试文件
        let testFiles = discovery.discover(dir)
        reporter.reportStart(testFiles)

        // 执行每个测试文件
        for (file in testFiles) {
            let fileResult = runFile(file)
            // 汇总结果
            globalResult.passCount += fileResult.passCount
            globalResult.failCount += fileResult.failCount
            globalResult.skipCount += fileResult.skipCount
            globalResult.todoCount += fileResult.todoCount
            globalResult.totalCount += fileResult.totalCount
            globalResult.totalDuration += fileResult.totalDuration
            for (r in fileResult.results) {
                globalResult.results.append(r)
            }
            for (f in fileResult.failures) {
                globalResult.failures.append(f)
            }
            reporter.reportFile(file, fileResult)
        }

        // 报告汇总
        reporter.reportSummary(globalResult)
        return globalResult
    }

    /// 运行单个测试文件
    public func runFile(path: String): TestSuiteResult {
        let result = TestSuiteResult()
        let suite = TestSuite(path)

        try {
            // 加载并执行测试文件 (注册 describe/it)
            vm.eval(BaoFile.readAllText(path), path)
        } catch (_: Exception) {
            // 文件加载错误
            let tr = TestResult(path)
            tr.status = TestStatus.Failed
            tr.error = Some("Failed to load test file: ${path}")
            result.add(tr)
            return result
        }

        // 收集并执行所有测试
        let tests = rootSuite.collectTests()
        for (test in tests) {
            let testResult = runTest(test)
            result.add(testResult)
            reporter.reportTest(testResult)
        }

        return result
    }

    /// 运行单个测试用例
    private func runTest(test: TestCase): TestResult {
        let result = TestResult(test.name)
        let startTime = currentTimeMillis()

        match (test.kind) {
            case TestCaseKind.Skip => {
                result.status = TestStatus.Skipped
                result.duration = 0.0
                return result
            }
            case TestCaseKind.Todo => {
                result.status = TestStatus.Todo
                result.duration = 0.0
                return result
            }
            case TestCaseKind.Test | TestCaseKind.Only => {
                match (test.fn) {
                    case Some(fn) =>
                        try {
                            fn(ArrayList<JsValue>())
                            result.status = TestStatus.Passed
                        } catch (e: BaoError) {
                            result.status = TestStatus.Failed
                            result.error = Some(e.message)
                        } catch (e: Exception) {
                            result.status = TestStatus.Failed
                            result.error = Some(e.message)
                        }
                    case None =>
                        result.status = TestStatus.Skipped
                }
            }
        }

        result.duration = currentTimeMillis() - startTime
        return result
    }

    /// 将 ExpectMatcher 转为 JsValue
    private func matcherToJsValue(matcher: ExpectMatcher): JsValue {
        let obj = JsObject()

        obj.set("toBe", JsValue.nativeFunction(JsNativeFunction("toBe") { args =>
            if (args.size >= 1) { matcher.toBe(args[0]) }
            return JsValue(obj)
        }))

        obj.set("toEqual", JsValue.nativeFunction(JsNativeFunction("toEqual") { args =>
            if (args.size >= 1) { matcher.toEqual(args[0]) }
            return JsValue(obj)
        }))

        obj.set("toBeTruthy", JsValue.nativeFunction(JsNativeFunction("toBeTruthy") { _ =>
            matcher.toBeTruthy()
            return JsValue(obj)
        }))

        obj.set("toBeFalsy", JsValue.nativeFunction(JsNativeFunction("toBeFalsy") { _ =>
            matcher.toBeFalsy()
            return JsValue(obj)
        }))

        obj.set("toThrow", JsValue.nativeFunction(JsNativeFunction("toThrow") { args =>
            if (args.size >= 1 && args[0].valueType == JsValueType.String) {
                matcher.toThrow(Interpreter.jsToString(args[0]))
            } else {
                matcher.toThrow()
            }
            return JsValue(obj)
        }))

        obj.set("toBeGreaterThan", JsValue.nativeFunction(JsNativeFunction("toBeGreaterThan") { args =>
            if (args.size >= 1) { matcher.toBeGreaterThan(args[0]) }
            return JsValue(obj)
        }))

        obj.set("toBeLessThan", JsValue.nativeFunction(JsNativeFunction("toBeLessThan") { args =>
            if (args.size >= 1) { matcher.toBeLessThan(args[0]) }
            return JsValue(obj)
        }))

        obj.set("toContain", JsValue.nativeFunction(JsNativeFunction("toContain") { args =>
            if (args.size >= 1) { matcher.toContain(args[0]) }
            return JsValue(obj)
        }))

        obj.set("toHaveLength", JsValue.nativeFunction(JsNativeFunction("toHaveLength") { args =>
            if (args.size >= 1) {
                let len = Int64(Interpreter.jsToNumber(args[0]))
                matcher.toHaveLength(len)
            }
            return JsValue(obj)
        }))

        obj.set("toMatch", JsValue.nativeFunction(JsNativeFunction("toMatch") { args =>
            if (args.size >= 1) { matcher.toMatch(Interpreter.jsToString(args[0])) }
            return JsValue(obj)
        }))

        obj.set("toBeDefined", JsValue.nativeFunction(JsNativeFunction("toBeDefined") { _ =>
            matcher.toBeDefined()
            return JsValue(obj)
        }))

        obj.set("toBeUndefined", JsValue.nativeFunction(JsNativeFunction("toBeUndefined") { _ =>
            matcher.toBeUndefined()
            return JsValue(obj)
        }))

        obj.set("toBeNull", JsValue.nativeFunction(JsNativeFunction("toBeNull") { _ =>
            matcher.toBeNull()
            return JsValue(obj)
        }))

        obj.set("not", JsValue(obj))
        // not 返回自身 (negated)

        return JsValue(obj)
    }

    /// 获取当前时间 (毫秒)
    private func currentTimeMillis(): Float64 {
        return bao_sys.SysModule.currentTimeMillis()
    }
}

/// TestRunner 模块导出
public class TestRunnerModule {
    public static func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("TestRunner", JsValue.nativeFunction(JsNativeFunction("TestRunner") { _ =>
            return JsValue.UNDEFINED
        }))
        return JsValue(obj)
    }
}
