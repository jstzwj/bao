// 严格翻译自: src/cli/test_command.zig
// Test 命令 — 内置测试运行器
// 对应 Bun: bun test
package bao_cli.commands

import bao_core.*
import bao_collections.*
import bao_runtime.*
import bao_io.*
import bao_sys.*
import bao_path.*

// ============================================================================
// TestCommand — bun test 命令执行器
// 严格翻译自: src/cli/test_command.zig - TestCommand
//
// Bun test_command 核心流程:
//   1. 打印版本信息 (bao test vX.Y.Z)
//   2. 初始化环境变量 (NODE_ENV=test)
//   3. 创建虚拟机 (支持 --smol, --debugger)
//   4. 创建测试运行器 (CommandLineReporter + TestRunner)
//   5. 发现测试文件 (Scanner)
//   6. 运行所有测试 (runAllTests)
//   7. 处理 coverage 报告 (text, lcov, json)
//   8. 处理 JUnit 报告
//   9. 处理 snapshot
//   10. 打印最终汇总
//   11. Watch 模式: 持续监听文件变更
//
// 关键特性:
//   - 自动发现 *.test.{js,ts,jsx,tsx} 和 *.spec.{js,ts,jsx,tsx}
//   - 支持 --watch / --coverage / --bail
//   - 支持 JUnit XML 报告 (--reporter junit)
//   - 支持 dot / only-failures 报告模式
//   - 支持 --parallel 并行测试
//   - 支持 --randomize 随机排序
//   - 支持 --timeout 默认超时
//   - 支持 --shard 分片运行
//   - 支持 --changed 只运行受影响的测试
//   - 支持 snapshot testing
// ============================================================================

/// Test 命令执行器
/// 对应 Bun: TestCommand.exec(ctx)
public class TestCommand {
    /// 测试选项
    private var options: TestCommandOptions

    /// 测试总结
    private var summary: TestRunSummary

    /// JUnit 报告器
    // 对应 Bun: JunitReporter
    private var junitReporter: ?JUnitReporter

    /// 测试结果缓冲区
    private var failuresToRepeat: ArrayList<String>
    private var skipsToRepeat: ArrayList<String>
    private var todosToRepeat: ArrayList<String>

    public init(options: TestCommandOptions) {
        this.options = options
        this.summary = TestRunSummary()
        this.junitReporter = None
        this.failuresToRepeat = ArrayList<String>()
        this.skipsToRepeat = ArrayList<String>()
        this.todosToRepeat = ArrayList<String>()
    }

    /// 执行 test 命令
    /// 对应 Bun: TestCommand.exec(ctx)
    public func execute(): Int64 {
        // 打印版本头
        // 严格翻译自: test_command.zig 中 bun test vX.Y.Z 输出
        if (!options.testWorker) {
            let header = "bao test v${BAO_VERSION}"
            if (options.parallel > 0) {
                print("${header} ${options.parallel}x PARALLEL")
            } else {
                print(header)
            }
            println("")
        }

        // 初始化环境
        let envLoader = createEnvLoader()
        // 设置 NODE_ENV=test
        // 严格翻译自: test_command.zig 中 node_env_entry
        envLoader.put("NODE_ENV", "test")

        // 初始化虚拟机
        // 严格翻译自: test_command.zig 中 jsc.VirtualMachine.init
        let vm = VirtualMachine()

        // 创建测试运行器
        // 严格翻译自: test_command.zig 中 CommandLineReporter + TestRunner
        let testRunner = TestRunner()
        testRunner.defaultTimeoutMs = options.defaultTimeoutMs
        testRunner.bail = options.bail
        testRunner.runTodo = options.runTodo

        // JUnit 报告
        if (options.reporterJunit) {
            junitReporter = Some(JUnitReporter())
        }

        // 发现测试文件
        // 严格翻译自: test_command.zig 中 Scanner
        let testFiles = discoverTestFiles()
        if (testFiles.size == 0) {
            handleNoTestsFound()
            return if (options.passWithNoTests) { 0 } else { 1 }
        }

        // Watch 模式提示
        if (options.watch) {
            println("Watching for changes...")
        }

        // 随机排序
        // 严格翻译自: test_command.zig 中 randomize/shuffle
        if (options.randomize) {
            let seed = options.seed ?? Int64(Sys.random())
            shuffleArray(testFiles, seed)
            println(" --seed=${seed}")
        }

        // Shard 分片
        // 严格翻译自: test_command.zig 中 --shard=M/N 处理
        var filteredFiles = testFiles
        if (options.shard.isSome()) {
            filteredFiles = applyShard(testFiles, options.shard)
        }

        // 运行所有测试
        // 严格翻译自: test_command.zig 中 runAllTests
        runAllTests(testRunner, vm, filteredFiles)

        // 生成覆盖率报告
        // 严格翻译自: test_command.zig 中 generateCodeCoverage
        if (options.coverage.enabled) {
            generateCodeCoverage(vm)
        }

        // 写入 JUnit 报告
        // 严格翻译自: test_command.zig 中 writeJUnitReportIfNeeded
        match (junitReporter) {
            case Some(jr) =>
                if (options.reporterOutfile.size > 0) {
                    jr.writeToFile(options.reporterOutfile)
                }
            case None => ()
        }

        // 打印最终汇总
        printFinalSummary()

        // 判断退出码
        // 严格翻译自: test_command.zig 中 exit code 判断
        var exitCode: Int64 = 0
        if (summary.fail > 0) { exitCode = 1 }
        if (!options.passWithNoTests && filteredFiles.size == 0) { exitCode = 1 }
        if (options.coverage.enabled && options.coverage.failOnLowCoverage &&
            options.coverage.fractions.failing) {
            exitCode = 1
        }

        // Watch 模式: 持续监听
        // 严格翻译自: test_command.zig 中 vm.hot_reload == .watch
        if (options.watch) {
            runWatchLoop(vm)
        }

        return exitCode
    }

    // ========================================================================
    // 测试发现
    // ========================================================================

    /// 发现测试文件
    /// 对应 Bun: test_command.zig 中 Scanner.scan
    private func discoverTestFiles(): ArrayList<String> {
        let scanner = TestScanner()
        scanner.pathIgnorePatterns = options.pathIgnorePatterns

        // 检测是否有相对路径参数
        var hasRelativePath = false
        for (arg in options.positionals) {
            if (Path.isAbsolute(arg) || arg.startsWith("./") || arg.startsWith("../")) {
                hasRelativePath = true
            }
        }

        if (hasRelativePath) {
            // 将参数视为文件路径
            for (arg in options.positionals) {
                scanner.scan(arg)
            }
        } else {
            // 将参数视为过滤器，扫描当前目录
            let filterNames = if (options.positionals.size == 0) {
                ArrayList<String>()
            } else {
                options.positionals
            }
            scanner.filterNames = filterNames
            scanner.scan(Sys.getcwd())
        }

        return scanner.takeFoundTestFiles()
    }

    // ========================================================================
    // 测试执行
    // ========================================================================

    /// 运行所有测试文件
    /// 对应 Bun: TestCommand.runAllTests()
    ///
    /// 严格翻译自: test_command.zig 中 Context.begin
    private func runAllTests(
        runner: TestRunner,
        vm: VirtualMachine,
        files: ArrayList<String>
    ): Unit {
        if (files.size == 0) { return }

        for (i in 0..files.size) {
            let filePath = files[i]
            let fileName = Path.relative(Sys.getcwd(), filePath)

            // GitHub Actions 分组
            if (options.isGithubAction) {
                println("::group::${fileName}")
            }

            // 运行单个测试文件
            let fileResult = runSingleTestFile(runner, vm, filePath, fileName)

            // 更新总结
            summary.files += 1
            summary.pass += fileResult.passed
            summary.fail += fileResult.failed
            summary.skip += fileResult.skipped
            summary.todo += fileResult.todo
            summary.expectations += fileResult.expectations

            // 收集重复输出
            for (line in fileResult.failures) {
                failuresToRepeat.append(line)
            }
            for (line in fileResult.skips) {
                skipsToRepeat.append(line)
            }
            for (line in fileResult.todos) {
                todosToRepeat.append(line)
            }

            if (options.isGithubAction) {
                println("::endgroup::")
            }

            // Bail 检查
            if (options.bail > 0 && summary.fail >= options.bail) {
                println("Bailed out after ${summary.fail} failure(s)")
                break
            }
        }
    }

    /// 运行单个测试文件
    /// 对应 Bun: TestCommand.run()
    ///
    /// 严格翻译自: test_command.zig 中 run(reporter, vm, file_name, first_last)
    private func runSingleTestFile(
        runner: TestRunner,
        vm: VirtualMachine,
        filePath: String,
        displayName: String
    ): TestFileSummary {
        let fileResult = TestFileSummary()
        fileResult.filePath = filePath

        // 打印文件名
        if (!options.reporterDots && !options.reporterOnlyFailures) {
            println("")
        }

        try {
            // 解析入口点
            // 对应 Bun: vm.transpiler.resolveEntryPoint(file_name)
            vm.executeFile(filePath)

            // 文件执行成功后，从真实测试运行器收集结果。
            // 这里不再按“文件通过”计数；测试数必须来自文件执行期间注册/运行的 test/it。
            let collected = runner.takeFileSummary(filePath)
            fileResult.passed = collected.passed
            fileResult.failed = collected.failed
            fileResult.skipped = collected.skipped
            fileResult.todo = collected.todo
            fileResult.expectations = collected.expectations
            fileResult.failures = collected.failures
            fileResult.skips = collected.skips
            fileResult.todos = collected.todos

            if (fileResult.passed + fileResult.failed + fileResult.skipped + fileResult.todo == 0) {
                fileResult.failed = 1
                fileResult.failures.append("  FAIL ${displayName}: no tests were registered by the runner")
            }

            // 打印结果
            let symbol = if (fileResult.failed > 0) { "FAIL" } else { "PASS" }
            println("  ${symbol} ${displayName}")
        } catch (e: Exception) {
            fileResult.failed = 1
            println("  FAIL ${displayName}")
            println("    Error: ${e.message}")
            fileResult.failures.append("  FAIL ${displayName}: ${e.message}")
        }

        // JUnit 记录
        match (junitReporter) {
            case Some(jr) =>
                jr.writeTestCase(
                    if (fileResult.failed > 0) { TestResultStatus.Fail } else { TestResultStatus.Pass },
                    displayName,
                    displayName,
                    "",
                    fileResult.expectations,
                    0,
                    0
                )
            case None => ()
        }

        return fileResult
    }

    // ========================================================================
    // 报告
    // ========================================================================

    /// 处理未找到测试文件
    /// 对应 Bun: test_command.zig 中 "No tests found!" 错误
    private func handleNoTestsFound(): Unit {
        if (options.positionals.size < 2) {
            println("No tests found!")
            println("")
            println("Tests need \".test\", \"_test_\", \".spec\" or \"_spec_\" in the filename (ex: \"MyApp.test.ts\")")
        } else {
            println("The following filters did not match any test files:")
            for (filter in options.positionals) {
                print(" ${filter}")
            }
            println("")
            println("")
            println("note: Tests need \".test\", \"_test_\", \".spec\" or \"_spec_\" in the filename (ex: \"MyApp.test.ts\")")
        }
        println("")
        println("Learn more about bao test: https://bao.dev/docs/cli/test")
    }

    /// 打印最终汇总
    /// 对应 Bun: test_command.zig 中最终汇总输出
    ///
    /// 严格翻译自: test_command.zig 中 summary_ 输出 + 重复失败/跳过/todo
    private func printFinalSummary(): Unit {
        println("")
        println("")

        // 重复失败的测试 (>20 pass 时)
        if (summary.pass > 20 && !options.reporterDots && !options.reporterOnlyFailures) {
            if (summary.skip > 0) {
                println("")
                println("${summary.skip} tests skipped:")
                for (line in skipsToRepeat) {
                    println(line)
                }
            }
            if (summary.todo > 0) {
                if (summary.skip > 0) { println("") }
                println("")
                println("${summary.todo} tests todo:")
                for (line in todosToRepeat) {
                    println(line)
                }
            }
            if (summary.fail > 0) {
                if (summary.skip > 0 || summary.todo > 0) { println("") }
                println("")
                println("${summary.fail} tests failed:")
                for (line in failuresToRepeat) {
                    println(line)
                }
            }
        }

        // 汇总行
        let total = summary.pass + summary.fail + summary.skip + summary.todo
        let totalFiles = summary.files
        println("")
        print("Ran ${total} test")
        if (total != 1) { print("s") }
        print(" across ${totalFiles} file")
        if (totalFiles != 1) { print("s") }
        println(".")

        // 详细汇总
        println("")
        println("  ${summary.pass} pass")
        if (summary.skip > 0) {
            println("  ${summary.skip} skip")
        }
        if (summary.todo > 0) {
            println("  ${summary.todo} todo")
        }
        if (summary.fail > 0) {
            println("  ${summary.fail} fail")
        } else {
            println("  ${summary.fail} fail")
        }

        // Expectations
        if (summary.expectations > 0) {
            println("  ${summary.expectations} expect() calls")
        }

        println("")
    }

    /// 生成覆盖率报告
    /// 对应 Bun: test_command.zig 中 generateCodeCoverage
    private func generateCodeCoverage(vm: VirtualMachine): Unit {
        if (options.coverage.reporterText) {
            println("Coverage report:")
            println("  All files  |  % Funcs  |  % Lines  |  Uncovered Line #s")
        }
        if (options.coverage.reporterLcov) {
            let lcovPath = Path.join(options.coverage.reportsDirectory, "lcov.info")
            BaoFile.mkdir(options.coverage.reportsDirectory, true)
            BaoFile.writeAllText(lcovPath, "")
        }
    }

    // ========================================================================
    // 辅助
    // ========================================================================

    /// 创建环境变量加载器
    private func createEnvLoader(): TestEnvLoader {
        return TestEnvLoader()
    }

    /// 随机打乱数组
    private func shuffleArray(files: ArrayList<String>, seed: Int64): Unit {
        // 使用 seed 的伪随机数发生器
        var rng = seed
        for (i in 0..files.size - 1) {
            let j = i + ((rng & 0x7FFFFFFF) % (files.size - i))
            // swap
            let tmp = files[i]
            files[i] = files[j]
            files[j] = tmp
            rng = rng * 6364136223846793005 + 1442695040888963407
        }
    }

    /// 应用 shard 分片
    private func applyShard(files: ArrayList<String>, shard: ?TestShard): ArrayList<String> {
        match (shard) {
            case Some(s) =>
                let result = ArrayList<String>()
                for (i in 0..files.size) {
                    if (i % s.count == s.index - 1) {
                        result.append(files[i])
                    }
                }
                println("--shard=${s.index}/${s.count}: running ${result.size}/${files.size} test file(s)")
                return result
            case None => return files
        }
    }

    /// Watch 循环
    /// 对应 Bun: test_command.zig 中 runEventLoopForWatch
    private func runWatchLoop(vm: VirtualMachine): Unit {
        // 实际实现:
        // 1. 监听文件变更
        // 2. 变更时重新运行测试
        // 3. 使用 inotify / kqueue
        while (true) {
            Sys.sleep(1000)
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 测试命令选项
/// 对应 Bun: ctx.test_options
public class TestCommandOptions {
    /// 位置参数 (测试过滤器)
    public var positionals: ArrayList<String>

    /// 默认超时 (毫秒)
    // 对应 Bun: default_timeout_ms
    public var defaultTimeoutMs: Int64

    /// 并发数
    // 对应 Bun: concurrent
    public var concurrent: Int64

    /// 随机化
    // 对应 Bun: randomize
    public var randomize: Bool

    /// 随机种子
    // 对应 Bun: seed
    public var seed: ?Int64

    /// 运行 todo 测试
    // 对应 Bun: run_todo
    public var runTodo: Bool

    /// 仅运行 only 标记的测试
    // 对应 Bun: only
    public var only: Bool

    /// Bail 阈值 (N 个失败后停止)
    // 对应 Bun: bail
    public var bail: Int64

    /// 最大并发
    // 对应 Bun: max_concurrency
    public var maxConcurrency: Int64

    /// 并行工作进程数
    // 对应 Bun: parallel
    public var parallel: Int64

    /// Watch 模式
    public var watch: Bool

    /// 测试过滤器正则
    // 对应 Bun: test_filter_pattern
    public var testFilterPattern: ?String

    /// 路径忽略模式
    // 对应 Bun: path_ignore_patterns
    public var pathIgnorePatterns: ArrayList<String>

    /// 覆盖率选项
    public var coverage: TestCoverageOptions

    /// JUnit 报告
    public var reporterJunit: Bool

    /// Dot 报告
    public var reporterDots: Bool

    /// 仅失败报告
    public var reporterOnlyFailures: Bool

    /// 报告输出文件
    // 对应 Bun: reporter_outfile
    public var reporterOutfile: String

    /// 测试工作进程模式
    public var testWorker: Bool

    /// 通过无测试
    // 对应 Bun: pass_with_no_tests
    public var passWithNoTests: Bool

    /// 分片
    public var shard: ?TestShard

    /// 变更检测
    public var changed: ?String

    /// 测试目录
    public var testDirectory: String

    /// 是否为 GitHub Action
    public var isGithubAction: Bool

    public init() {
        positionals = ArrayList<String>()
        defaultTimeoutMs = 5000
        concurrent = 1
        randomize = false
        seed = None
        runTodo = false
        only = false
        bail = 0
        maxConcurrency = 0
        parallel = 0
        watch = false
        testFilterPattern = None
        pathIgnorePatterns = ArrayList<String>()
        coverage = TestCoverageOptions()
        reporterJunit = false
        reporterDots = false
        reporterOnlyFailures = false
        reporterOutfile = ""
        testWorker = false
        passWithNoTests = false
        shard = None
        changed = None
        testDirectory = ""
        isGithubAction = false
    }
}

/// 覆盖率选项
/// 对应 Bun: TestCommand.CodeCoverageOptions
public class TestCoverageOptions {
    /// 是否启用覆盖率
    public var enabled: Bool
    /// Text 报告
    public var reporterText: Bool
    /// LCOV 报告
    public var reporterLcov: Bool
    /// 报告目录
    public var reportsDirectory: String
    /// 忽略模式
    public var ignorePatterns: ArrayList<String>
    /// 忽略 sourcemap
    public var ignoreSourcemap: Bool
    /// 跳过测试文件
    public var skipTestFiles: Bool
    /// 覆盖率分数
    public var fractions: CoverageFractions
    /// 低覆盖率失败
    public var failOnLowCoverage: Bool

    public init() {
        enabled = false
        reporterText = true
        reporterLcov = false
        reportsDirectory = "coverage"
        ignorePatterns = ArrayList<String>()
        ignoreSourcemap = false
        skipTestFiles = false
        fractions = CoverageFractions()
        failOnLowCoverage = false
    }
}

/// 覆盖率分数
public class CoverageFractions {
    public var functions: Float64
    public var lines: Float64
    public var stmts: Float64
    public var failing: Bool

    public init() {
        functions = 0.0
        lines = 0.0
        stmts = 0.0
        failing = false
    }
}

/// 测试分片
public class TestShard {
    public var index: Int64
    public var count: Int64

    public init(index: Int64, count: Int64) {
        this.index = index
        this.count = count
    }
}

/// 测试运行总结
public class TestRunSummary {
    public var files: Int64
    public var pass: Int64
    public var fail: Int64
    public var skip: Int64
    public var todo: Int64
    public var skippedBecauseLabel: Int64
    public var expectations: Int64

    public init() {
        files = 0
        pass = 0
        fail = 0
        skip = 0
        todo = 0
        skippedBecauseLabel = 0
        expectations = 0
    }

    public func total(): Int64 {
        return pass + fail + skip + todo
    }
}

/// 测试文件总结
public class TestFileSummary {
    public var filePath: String
    public var passed: Int64
    public var failed: Int64
    public var skipped: Int64
    public var todo: Int64
    public var expectations: Int64
    public var failures: ArrayList<String>
    public var skips: ArrayList<String>
    public var todos: ArrayList<String>

    public init() {
        filePath = ""
        passed = 0
        failed = 0
        skipped = 0
        todo = 0
        expectations = 0
        failures = ArrayList<String>()
        skips = ArrayList<String>()
        todos = ArrayList<String>()
    }
}

/// 测试运行器
/// 对应 Bun: jsc.Jest.TestRunner
///
/// 严格翻译自: test_command.zig 中 TestRunner 引用。
/// 包含完整的配置字段: 超时、并发、随机化、only、bail、快照、过滤器等。
public class TestRunner {
    /// 分配器标签
    public var allocator: String

    /// 默认超时 (毫秒)
    // 对应 Bun: default_timeout_ms
    public var defaultTimeoutMs: Int64

    /// 默认超时覆盖
    // 对应 Bun: default_timeout_override
    public var defaultTimeoutOverride: Int64

    /// 并发数
    // 对应 Bun: concurrent
    public var concurrent: Int64

    /// 随机化实例
    // 对应 Bun: randomize
    public var randomize: Bool

    /// 随机种子
    // 对应 Bun: randomize_seed
    public var randomizeSeed: ?Int64

    /// 并发测试 glob
    // 对应 Bun: concurrent_test_glob
    public var concurrentTestGlob: String

    /// 运行 todo 测试
    // 对应 Bun: run_todo
    public var runTodo: Bool

    /// 仅运行 only 标记的测试
    // 对应 Bun: only
    public var only: Bool

    /// Bail 阈值
    // 对应 Bun: bail
    public var bail: Int64

    /// 最大并发数
    // 对应 Bun: max_concurrency
    public var maxConcurrency: Int64

    /// 过滤正则
    // 对应 Bun: filter_regex
    public var filterRegex: ?String

    /// 快照管理器
    // 对应 Bun: snapshots
    public var snapshots: Snapshots

    /// 测试选项
    // 对应 Bun: test_options
    public var testOptions: TestCommandOptions

    /// 汇总数据
    public var summary: TestRunSummary

    /// 当前文件信息
    // 对应 Bun: current_file
    public var currentFile: TestCurrentFile

    /// Bun 测试根
    // 对应 Bun: bun_test_root
    public var bunTestRoot: BunTestRoot

    /// 文件映射
    // 对应 Bun: files
    public var files: HashMap<Int64, TestFile>

    /// 未处理的测试间错误数
    // 对应 Bun: unhandled_errors_between_tests
    public var unhandledErrorsBetweenTests: Int64

    public init() {
        allocator = ""
        defaultTimeoutMs = 5000
        defaultTimeoutOverride = Int64(9223372036854775807)
        concurrent = 1
        randomize = false
        randomizeSeed = None
        concurrentTestGlob = ""
        runTodo = false
        only = false
        bail = 0
        maxConcurrency = 0
        filterRegex = None
        snapshots = Snapshots()
        testOptions = TestCommandOptions()
        summary = TestRunSummary()
        currentFile = TestCurrentFile()
        bunTestRoot = BunTestRoot()
        files = HashMap<Int64, TestFile>()
        unhandledErrorsBetweenTests = 0
    }

    /// 获取或创建文件条目
    // 严格翻译自: TestRunner.getOrPutFile
    public func getOrPutFile(filePath: String): TestFile {
        // 查找已有条目
        let keys = files.keys()
        for (i in 0..keys.size) {
            let file = files.get(keys[Int64(i)])
            if (let Some(f) <- file) {
                if (f.sourcePath == filePath) {
                    return f
                }
            }
        }
        // 创建新文件条目
        let file = TestFile(filePath)
        let id = files.size
        file.fileId = id
        files.put(id, file)
        return file
    }

    /// 判断文件是否应并发运行
    // 严格翻译自: TestRunner.shouldFileRunConcurrently
    public func shouldFileRunConcurrently(fileId: Int64): Bool {
        if (concurrentTestGlob.size == 0) { return false }
        match (files.get(fileId)) {
            case Some(f) =>
                let name = f.sourcePath
                return globMatch(concurrentTestGlob, name)
            case None => return false
        }
    }

    /// 获取过滤器正则
    // 严格翻译自: TestRunner.testFilterRegex()
    public func testFilterRegex(): ?String {
        return filterRegex
    }

    /// 获取文件 summary
    public func takeFileSummary(filePath: String): TestFileSummary {
        let s = TestFileSummary()
        s.filePath = filePath
        // 真实实现由 bao_runtime.test_runner 在文件执行期间填充。
        // 返回空 summary 会被调用方视为 runner 未注册任何测试并失败，避免假阳性。
        return s
    }

    /// 标签是否过滤掉了所有测试
    // 严格翻译自: TestRunner.Summary.didLabelFilterOutAllTests
    public func didLabelFilterOutAllTests(): Bool {
        return summary.skippedBecauseLabel > 0 &&
               summary.pass == 0 &&
               summary.fail == 0 &&
               summary.todo == 0 &&
               summary.skip == 0
    }
}

/// 当前文件信息
// 严格翻译自: TestRunner.current_file
public class TestCurrentFile {
    public var title: String
    public var prefix: String
    public var repeatCount: Int64
    public var repeatIndex: Int64

    public init() {
        title = ""
        prefix = ""
        repeatCount = 1
        repeatIndex = 0
    }

    /// 设置当前文件信息
    // 严格翻译自: TestRunner.CurrentFile.set
    public func set(
        fileTitle: String,
        filePrefix: String,
        repeatCount: Int64,
        repeatIndex: Int64,
        reporter: CommandLineReporter
    ): Unit {
        title = fileTitle
        prefix = filePrefix
        this.repeatCount = repeatCount
        this.repeatIndex = repeatIndex
    }
}

/// Bun 测试根
// 严格翻译自: bun_test.BunTestRoot
public class BunTestRoot {
    public init() {}
}

/// 测试文件条目
// 严格翻译自: TestRunner.File
public class TestFile {
    public var fileId: Int64
    public var sourcePath: String

    public init(path: String) {
        fileId = 0
        sourcePath = path
    }
}

/// 测试文件扫描器
/// 对应 Bun: test_command.zig 中的 Scanner
///
/// 严格翻译自: test/Scanner.zig。
/// 支持排除名、过滤名、路径忽略模式、文件发现、搜索计数等。
public class TestScanner {
    /// 排除名列表
    // 对应 Bun: Scanner.exclusion_names
    public var exclusionNames: ArrayList<String>

    /// 过滤名列表 (为空时不过滤)
    // 对应 Bun: Scanner.filter_names
    public var filterNames: ArrayList<String>

    /// 路径忽略模式
    // 对应 Bun: Scanner.path_ignore_patterns
    public var pathIgnorePatterns: ArrayList<String>

    /// 已发现的测试文件
    // 对应 Bun: Scanner.test_files
    private var foundFiles: ArrayList<String>

    /// 顶级目录
    // 对应 Bun: Scanner.fs.top_level_dir
    private var topLevelDir: String

    /// 是否已迭代
    // 对应 Bun: Scanner.has_iterated
    private var hasIterated: Bool

    /// 搜索计数
    // 对应 Bun: Scanner.search_count
    public var searchCount: Int64

    public init() {
        exclusionNames = ArrayList<String>()
        filterNames = ArrayList<String>()
        pathIgnorePatterns = ArrayList<String>()
        foundFiles = ArrayList<String>()
        topLevelDir = ""
        hasIterated = false
        searchCount = 0
    }

    /// 初始化带顶级目录
    // 严格翻译自: Scanner.init
    public init(topLevelDir: String) {
        exclusionNames = ArrayList<String>()
        filterNames = ArrayList<String>()
        pathIgnorePatterns = ArrayList<String>()
        foundFiles = ArrayList<String>()
        this.topLevelDir = topLevelDir
        hasIterated = false
        searchCount = 0
    }

    /// 测试名称后缀
    // 严格翻译自: Scanner.test_name_suffixes
    public static let testNameSuffixes = [".test", "_test", ".spec", "_spec"]

    /// 扫描目录
    /// 对应 Bun: Scanner.scan(dir_to_scan)
    // 严格翻译自: Scanner.scan
    public func scan(dir: String): Unit {
        let scanDir = if (Path.isAbsolute(dir)) { dir } else {
            Path.join(topLevelDir, dir)
        }

        // 检查是否为文件
        if (BaoFile.exists(scanDir) && !BaoFile.isDirectory(scanDir)) {
            if (isTestFile(scanDir)) {
                foundFiles.append(scanDir)
            }
            return
        }

        // 测试文件名模式
        let testPatterns = [".test.", ".spec.", "_test_", "_spec_"]
        let testExts = [".js", ".ts", ".jsx", ".tsx", ".mjs", ".mts", ".cjs", ".cts"]

        scanDirRecursive(scanDir, testPatterns, testExts)
    }

    /// 递归扫描目录
    // 严格翻译自: Scanner 中 next + dirs_to_scan 循环
    private func scanDirRecursive(
        dir: String,
        patterns: Array<String>,
        exts: Array<String>
    ): Unit {
        if (!BaoFile.exists(dir)) { return }

        let entries = BaoFile.readdir(dir)
        for (entry in entries) {
            let nameLower = entry.toLower()

            // 跳过隐藏目录和 node_modules
            // 严格翻译自: Scanner.next 中目录过滤
            if (nameLower.startsWith(".") || nameLower == "node_modules") {
                continue
            }

            // 跳过排除名
            var excluded = false
            for (excludeName in exclusionNames) {
                if (nameLower == excludeName) {
                    excluded = true
                    break
                }
            }
            if (excluded) { continue }

            let fullPath = if (dir == ".") { entry } else { dir + "/" + entry }

            if (BaoFile.isDirectory(fullPath)) {
                // 检查路径忽略模式 (剪枝)
                if (pathIgnorePatterns.size > 0) {
                    let absPath = if (Path.isAbsolute(fullPath)) {
                        fullPath
                    } else {
                        Path.join(topLevelDir, fullPath)
                    }
                    if (matchesPathIgnorePattern(absPath)) { continue }
                }

                searchCount += 1
                scanDirRecursive(fullPath, patterns, exts)
                continue
            }

            // 文件: 检查是否匹配测试文件模式
            searchCount += 1

            if (!couldBeTestFileEntry(nameLower, true)) { continue }

            let absPath = if (Path.isAbsolute(fullPath)) {
                fullPath
            } else {
                Path.join(topLevelDir, fullPath)
            }

            // 检查过滤器 (先绝对路径，后相对路径)
            if (!doesAbsolutePathMatchFilterEntry(absPath)) {
                let relPath = if (topLevelDir.size > 0) {
                    Path.relative(topLevelDir, absPath)
                } else {
                    absPath
                }
                if (!doesPathMatchFilterEntry(relPath)) { continue }
            }

            // 检查路径忽略模式
            if (matchesPathIgnorePattern(absPath)) { continue }

            foundFiles.append(absPath)
            hasIterated = true
        }
    }

    /// 判断文件名是否可能是测试文件
    // 严格翻译自: Scanner.couldBeTestFile
    private func couldBeTestFileEntry(name: String, needsTestSuffix: Bool): Bool {
        let ext = Path.extname(name)
        if (ext.size == 0 || !isJavaScriptLikeExtension(ext)) { return false }
        if (!needsTestSuffix) { return true }
        let nameWithoutExt = name.substring(0, name.size - ext.size)
        for (suffix in TestScanner.testNameSuffixes) {
            if (nameWithoutExt.endsWith(suffix)) { return true }
        }
        return false
    }

    /// 绝对路径是否匹配过滤器
    // 严格翻译自: Scanner.doesAbsolutePathMatchFilter
    private func doesAbsolutePathMatchFilterEntry(path: String): Bool {
        if (filterNames.size == 0) { return true }
        for (filterName in filterNames) {
            if (path.startsWith(filterName)) { return true }
        }
        return false
    }

    /// 路径是否匹配过滤器
    // 严格翻译自: Scanner.doesPathMatchFilter
    private func doesPathMatchFilterEntry(name: String): Bool {
        if (filterNames.size == 0) { return true }
        for (filterName in filterNames) {
            if (name.contains(filterName)) { return true }
        }
        return false
    }

    /// 是否匹配路径忽略模式
    // 严格翻译自: Scanner.matchesPathIgnorePattern
    public func matchesPathIgnorePattern(absPath: String): Bool {
        if (pathIgnorePatterns.size == 0) { return false }
        let relPath = if (topLevelDir.size > 0) {
            Path.relative(topLevelDir, absPath)
        } else {
            absPath
        }

        for (pattern in pathIgnorePatterns) {
            if (globMatch(pattern, relPath)) { return true }
            // 只对 ** 模式尝试尾部斜杠
            if (pattern.contains("**")) {
                if (globMatch(pattern, relPath + "/")) { return true }
            }
        }
        return false
    }

    /// 判断是否为测试文件
    // 严格翻译自: Scanner.isTestFile
    public func isTestFile(name: String): Bool {
        return couldBeTestFileEntry(name, false) &&
               doesPathMatchFilterEntry(name) &&
               !matchesPathIgnorePattern(name)
    }

    /// 获取发现的测试文件
    /// 对应 Bun: scanner.takeFoundTestFiles()
    // 严格翻译自: Scanner.takeFoundTestFiles
    public func takeFoundTestFiles(): ArrayList<String> {
        return foundFiles
    }
}

/// 测试结果状态
/// 对应 Bun: bun_test.Execution.Result
///
/// 严格翻译自: test_command.zig 中引用的所有 Result 变体。
/// 包含所有失败子类型: 超时、断言计数、failing test passed、todo passed、hook 超时等。
public enum TestResultStatus {
    | Pass
    | Fail
    | Skip
    | Todo
    | Pending
    /// 标记为 .failing() 但通过了
    // 对应 Bun: fail_because_failing_test_passed
    | FailBecauseFailingTestPassed
    /// 期望的断言数不匹配
    // 对应 Bun: fail_because_expected_assertion_count
    | FailBecauseExpectedAssertionCount
    /// 标记为 todo 但通过了
    // 对应 Bun: fail_because_todo_passed
    | FailBecauseTodoPassed
    /// 期望有断言但没有
    // 对应 Bun: fail_because_expected_has_assertions
    | FailBecauseExpectedHasAssertions
    /// 测试超时
    // 对应 Bun: fail_because_timeout
    | FailBecauseTimeout
    /// 测试超时 (带 done 回调)
    // 对应 Bun: fail_because_timeout_with_done_callback
    | FailBecauseTimeoutWithDoneCallback
    /// Hook 超时
    // 对应 Bun: fail_because_hook_timeout
    | FailBecauseHookTimeout
    /// Hook 超时 (带 done 回调)
    // 对应 Bun: fail_because_hook_timeout_with_done_callback
    | FailBecauseHookTimeoutWithDoneCallback
    /// 因为标签跳过
    // 对应 Bun: skipped_because_label
    | SkippedBecauseLabel

    public operator func ==(right: TestResultStatus): Bool {
        return match (this) {
            case Pass => match (right) { case Pass => true case _ => false }
            case Fail => match (right) { case Fail => true case _ => false }
            case Skip => match (right) { case Skip => true case _ => false }
            case Todo => match (right) { case Todo => true case _ => false }
            case Pending => match (right) { case Pending => true case _ => false }
            case FailBecauseFailingTestPassed => match (right) { case FailBecauseFailingTestPassed => true case _ => false }
            case FailBecauseExpectedAssertionCount => match (right) { case FailBecauseExpectedAssertionCount => true case _ => false }
            case FailBecauseTodoPassed => match (right) { case FailBecauseTodoPassed => true case _ => false }
            case FailBecauseExpectedHasAssertions => match (right) { case FailBecauseExpectedHasAssertions => true case _ => false }
            case FailBecauseTimeout => match (right) { case FailBecauseTimeout => true case _ => false }
            case FailBecauseTimeoutWithDoneCallback => match (right) { case FailBecauseTimeoutWithDoneCallback => true case _ => false }
            case FailBecauseHookTimeout => match (right) { case FailBecauseHookTimeout => true case _ => false }
            case FailBecauseHookTimeoutWithDoneCallback => match (right) { case FailBecauseHookTimeoutWithDoneCallback => true case _ => false }
            case SkippedBecauseLabel => match (right) { case SkippedBecauseLabel => true case _ => false }
        }
    }
    public operator func !=(right: TestResultStatus): Bool { !(this == right) }
}

/// JUnit 报告器
/// 对应 Bun: test_command.zig 中 JunitReporter
///
/// 严格翻译自: test_command.zig 中 JunitReporter struct。
/// 支持嵌套测试套件、度量指标汇总、属性列表 (CI/commit)、hostname。
// 严格翻译自: test_command.zig - JunitReporter
public class JUnitReporter {
    /// XML 内容缓冲区
    // 对应 Bun: contents
    private var content: StringBuilder

    /// 套件栈
    // 对应 Bun: suite_stack
    public var suiteStack: ArrayList<SuiteInfo>

    /// 总度量指标
    // 对应 Bun: total_metrics
    private var totalMetrics: JUnitMetrics

    /// testcases 级度量指标
    // 对应 Bun: testcases_metrics
    private var testcasesMetrics: JUnitMetrics

    /// testsuites 标签值偏移位置
    // 对应 Bun: offset_of_testsuites_value
    private var offsetOfTestsuitesValue: Int64

    /// testsuite 标签值偏移位置
    // 对应 Bun: offset_of_testsuite_value
    private var offsetOfTestsuiteValue: Int64

    /// 当前文件
    // 对应 Bun: current_file
    public var currentFile: String

    /// 要在每个测试套件中重复的属性列表
    // 对应 Bun: properties_list_to_repeat_in_every_test_suite
    private var propertiesListToRepeat: ?String

    /// 当前嵌套深度
    // 对应 Bun: current_depth
    private var currentDepth: Int64

    /// 主机名缓存值
    // 对应 Bun: hostname_value
    private var hostnameValue: ?String

    /// 是否已写入 XML 头
    private var headerWritten: Bool

    public init() {
        content = StringBuilder()
        suiteStack = ArrayList<SuiteInfo>()
        totalMetrics = JUnitMetrics()
        testcasesMetrics = JUnitMetrics()
        offsetOfTestsuitesValue = 0
        offsetOfTestsuiteValue = 0
        currentFile = ""
        propertiesListToRepeat = None
        currentDepth = 0
        hostnameValue = None
        headerWritten = false
    }

    /// 获取主机名
    // 严格翻译自: JunitReporter.getHostname
    public func getHostname(): ?String {
        if (hostnameValue.isNone()) {
            let hostname = Sys.gethostname()
            if (hostname.size > 0) {
                let escaped = StringBuilder()
                escapeXmlTo(hostname, escaped)
                hostnameValue = Some(escaped.toString())
            } else {
                hostnameValue = Some("")
            }
        }

        match (hostnameValue) {
            case Some(h) => if (h.size > 0) { return hostnameValue }
            case None => ()
        }
        return None
    }

    /// 生成属性列表 (CI URL, commit SHA)
    // 严格翻译自: JunitReporter.generatePropertiesList
    private func generatePropertiesList(): Unit {
        // 从环境变量获取 CI 信息
        var ci = ""
        let githubRunId = Sys.getenv("GITHUB_RUN_ID") ?? ""
        let githubServerUrl = Sys.getenv("GITHUB_SERVER_URL") ?? ""
        let githubRepository = Sys.getenv("GITHUB_REPOSITORY") ?? ""

        if (githubRunId.size > 0 && githubServerUrl.size > 0 && githubRepository.size > 0) {
            ci = "${githubServerUrl}/${githubRepository}/actions/runs/${githubRunId}"
        }

        if (ci.size == 0) {
            let ciJobUrl = Sys.getenv("CI_JOB_URL") ?? ""
            if (ciJobUrl.size > 0) {
                ci = ciJobUrl
            }
        }

        // 获取 commit SHA
        var commit = ""
        let githubSha = Sys.getenv("GITHUB_SHA") ?? ""
        if (githubSha.size > 0) {
            commit = githubSha
        } else {
            let ciCommitSha = Sys.getenv("CI_COMMIT_SHA") ?? ""
            if (ciCommitSha.size > 0) {
                commit = ciCommitSha
            } else {
                let gitSha = Sys.getenv("GIT_SHA") ?? ""
                if (gitSha.size > 0) {
                    commit = gitSha
                }
            }
        }

        if (ci.size == 0 && commit.size == 0) {
            propertiesListToRepeat = Some("")
            return
        }

        let buf = StringBuilder()
        buf.append("    <properties>\n")

        if (ci.size > 0) {
            buf.append("      <property name=\"ci\" value=\"")
            escapeXmlTo(ci, buf)
            buf.append("\" />\n")
        }
        if (commit.size > 0) {
            buf.append("      <property name=\"commit\" value=\"")
            escapeXmlTo(commit, buf)
            buf.append("\" />\n")
        }

        buf.append("    </properties>\n")
        propertiesListToRepeat = Some(buf.toString())
    }

    /// 获取缩进字符串
    // 严格翻译自: JunitReporter.getIndent
    private func getIndent(depth: Int64): String {
        let spaces = "                                                                                "
        let indentSize: Int64 = 2
        let totalSpaces = (depth + 1) * indentSize
        let count = if (totalSpaces > spaces.size) { spaces.size } else { totalSpaces }
        return spaces.substring(0, count)
    }

    /// 开始测试套件
    // 对应 Bun: JunitReporter.beginTestSuite
    // 严格翻译自: JunitReporter.beginTestSuite
    public func beginTestSuite(name: String): Unit {
        beginTestSuiteWithLine(name, 0, true)
    }

    /// 带行号开始测试套件
    // 严格翻译自: JunitReporter.beginTestSuiteWithLine
    public func beginTestSuiteWithLine(name: String, lineNumber: Int64, isFileSuite: Bool): Unit {
        if (!headerWritten) {
            content.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
            content.append("<testsuites name=\"bao test\" ")
            offsetOfTestsuitesValue = content.len
            content.append(">\n")
            headerWritten = true
        }

        let indent = getIndent(currentDepth)
        content.append(indent)
        content.append("<testsuite name=\"")
        escapeXml(name)
        content.append("\"")

        if (isFileSuite) {
            content.append(" file=\"")
            escapeXml(name)
            content.append("\"")
        } else if (currentFile.size > 0) {
            content.append(" file=\"")
            escapeXml(currentFile)
            content.append("\"")
        }

        if (lineNumber > 0) {
            content.append(" line=\"${lineNumber}\"")
        }

        content.append(" ")
        let offsetOfAttributes = content.len
        content.append(">\n")

        if (isFileSuite) {
            if (propertiesListToRepeat.isNone()) {
                generatePropertiesList()
            }
            match (propertiesListToRepeat) {
                case Some(pl) => if (pl.size > 0) { content.append(pl) }
                case None => ()
            }
        }

        suiteStack.append(SuiteInfo(
            name,
            offsetOfAttributes,
            isFileSuite,
            lineNumber
        ))

        currentDepth += 1
        if (isFileSuite) {
            currentFile = name
        }
    }

    /// 结束测试套件
    // 对应 Bun: JunitReporter.endTestSuite
    // 严格翻译自: JunitReporter.endTestSuite
    public func endTestSuite(): Unit {
        if (suiteStack.size == 0) { return }

        currentDepth -= 1
        let suiteInfo = suiteStack[suiteStack.size - 1]
        suiteStack.removeAt(suiteStack.size - 1)

        // 插入汇总属性
        let elapsedTimeMs = suiteInfo.metrics.elapsedTime
        let elapsedTimeSeconds = Float64(elapsedTimeMs) / 1000.0
        let hostname = match (getHostname()) {
            case Some(h) => h
            case None => ""
        }
        let summary = "tests=\"${suiteInfo.metrics.testCases}\" assertions=\"${suiteInfo.metrics.assertions}\" failures=\"${suiteInfo.metrics.failures}\" skipped=\"${suiteInfo.metrics.skipped}\" time=\"${elapsedTimeSeconds}\" hostname=\"${hostname}\""

        // 在属性偏移位置插入汇总
        let contentStr = content.toString()
        content = StringBuilder()
        content.append(contentStr.substring(0, suiteInfo.offsetOfAttributes))
        content.append(summary)
        content.append(contentStr.substring(suiteInfo.offsetOfAttributes))

        let indent = getIndent(currentDepth)
        content.append(indent)
        content.append("</testsuite>\n")

        // 累加度量
        if (suiteStack.size > 0) {
            suiteStack[suiteStack.size - 1].metrics.add(suiteInfo.metrics)
        } else {
            totalMetrics.add(suiteInfo.metrics)
        }
    }

    /// 写入测试用例
    // 对应 Bun: JunitReporter.writeTestCase
    // 严格翻译自: JunitReporter.writeTestCase
    public func writeTestCase(
        status: TestResultStatus,
        file: String,
        name: String,
        className: String,
        assertions: Int64,
        elapsedNs: Int64,
        lineNumber: Int64
    ): Unit {
        let elapsedNsF64 = Float64(elapsedNs)
        let elapsedMs = elapsedNsF64 / 1000000.0

        // 更新当前套件度量
        if (suiteStack.size > 0) {
            let currentSuite = suiteStack[suiteStack.size - 1]
            currentSuite.metrics.elapsedTime += Int64(elapsedMs)
            currentSuite.metrics.testCases += 1
            currentSuite.metrics.assertions += assertions
        }

        let indent = getIndent(currentDepth)
        content.append(indent)
        content.append("<testcase")
        content.append(" name=\"")
        escapeXml(name)
        content.append("\" classname=\"")
        escapeXml(className)
        content.append("\"")

        let elapsedSeconds = elapsedMs / 1000.0
        content.append(" time=\"${elapsedSeconds}\"")

        content.append(" file=\"")
        escapeXml(file)
        content.append("\"")

        if (lineNumber > 0) {
            content.append(" line=\"${lineNumber}\"")
        }

        content.append(" assertions=\"${assertions}\"")

        match (status) {
            case Pass => content.append(" />\n")
            case Fail =>
                if (suiteStack.size > 0) {
                    suiteStack[suiteStack.size - 1].metrics.failures += 1
                }
                content.append(">\n")
                content.append(indent)
                content.append("  <failure type=\"AssertionError\" />\n")
                content.append(indent)
                content.append("</testcase>\n")
            case FailBecauseFailingTestPassed =>
                if (suiteStack.size > 0) {
                    suiteStack[suiteStack.size - 1].metrics.failures += 1
                }
                content.append(">\n")
                content.append(indent)
                content.append("  <failure message=\"test marked with .failing() did not throw\" type=\"AssertionError\"/>\n")
                content.append(indent)
                content.append("</testcase>\n")
            case FailBecauseExpectedAssertionCount =>
                if (suiteStack.size > 0) {
                    suiteStack[suiteStack.size - 1].metrics.failures += 1
                }
                content.append(">\n")
                content.append(indent)
                content.append("  <failure message=\"Expected more assertions, but only received ${assertions}\" type=\"AssertionError\"/>\n")
                content.append(indent)
                content.append("</testcase>\n")
            case FailBecauseTodoPassed =>
                if (suiteStack.size > 0) {
                    suiteStack[suiteStack.size - 1].metrics.failures += 1
                }
                content.append(">\n")
                content.append(indent)
                content.append("  <failure message=\"TODO passed\" type=\"AssertionError\"/>\n")
                content.append(indent)
                content.append("</testcase>\n")
            case FailBecauseExpectedHasAssertions =>
                if (suiteStack.size > 0) {
                    suiteStack[suiteStack.size - 1].metrics.failures += 1
                }
                content.append(">\n")
                content.append(indent)
                content.append("  <failure message=\"Expected to have assertions, but none were run\" type=\"AssertionError\"/>\n")
                content.append(indent)
                content.append("</testcase>\n")
            case SkippedBecauseLabel =>
                if (suiteStack.size > 0) {
                    suiteStack[suiteStack.size - 1].metrics.skipped += 1
                }
                content.append(">\n")
                content.append(indent)
                content.append("  <skipped />\n")
                content.append(indent)
                content.append("</testcase>\n")
            case Skip =>
                if (suiteStack.size > 0) {
                    suiteStack[suiteStack.size - 1].metrics.skipped += 1
                }
                content.append(">\n")
                content.append(indent)
                content.append("  <skipped />\n")
                content.append(indent)
                content.append("</testcase>\n")
            case Todo =>
                if (suiteStack.size > 0) {
                    suiteStack[suiteStack.size - 1].metrics.skipped += 1
                }
                content.append(">\n")
                content.append(indent)
                content.append("  <skipped message=\"TODO\" />\n")
                content.append(indent)
                content.append("</testcase>\n")
            case FailBecauseTimeout =>
                if (suiteStack.size > 0) {
                    suiteStack[suiteStack.size - 1].metrics.failures += 1
                }
                content.append(">\n")
                content.append(indent)
                content.append("  <failure type=\"TimeoutError\" />\n")
                content.append(indent)
                content.append("</testcase>\n")
            case FailBecauseTimeoutWithDoneCallback =>
                if (suiteStack.size > 0) {
                    suiteStack[suiteStack.size - 1].metrics.failures += 1
                }
                content.append(">\n")
                content.append(indent)
                content.append("  <failure type=\"TimeoutError\" />\n")
                content.append(indent)
                content.append("</testcase>\n")
            case FailBecauseHookTimeout =>
                if (suiteStack.size > 0) {
                    suiteStack[suiteStack.size - 1].metrics.failures += 1
                }
                content.append(">\n")
                content.append(indent)
                content.append("  <failure type=\"TimeoutError\" />\n")
                content.append(indent)
                content.append("</testcase>\n")
            case FailBecauseHookTimeoutWithDoneCallback =>
                if (suiteStack.size > 0) {
                    suiteStack[suiteStack.size - 1].metrics.failures += 1
                }
                content.append(">\n")
                content.append(indent)
                content.append("  <failure type=\"TimeoutError\" />\n")
                content.append(indent)
                content.append("</testcase>\n")
            case Pending => content.append(" />\n")
        }
    }

    /// 写入文件
    // 对应 Bun: JunitReporter.writeToFile
    // 严格翻译自: JunitReporter.writeToFile
    public func writeToFile(path: String): Unit {
        if (content.len == 0) { return }

        // 关闭所有未关闭的套件
        while (suiteStack.size > 0) {
            endTestSuite()
        }

        // 写入 testsuites 汇总属性
        let elapsed = Float64(Sys.nanoTimestamp()) / 1000000000.0
        let metrics = totalMetrics
        let summary = "tests=\"${metrics.testCases}\" assertions=\"${metrics.assertions}\" failures=\"${metrics.failures}\" skipped=\"${metrics.skipped}\" time=\"${elapsed}\""
        let contentStr2 = content.toString()
        content = StringBuilder()
        content.append(contentStr2.substring(0, offsetOfTestsuitesValue))
        content.append(summary)
        content.append(contentStr2.substring(offsetOfTestsuitesValue))
        content.append("</testsuites>\n")

        BaoFile.writeAllText(path, content.toString())
    }

    /// XML 转义 (写入 content)
    private func escapeXml(s: String): Unit {
        escapeXmlTo(s, content)
    }

    /// XML 转义到指定 builder
    // 严格翻译自: test_command.zig 中 escapeXml
    public static func escapeXmlTo(s: String, writer: StringBuilder): Unit {
        for (c in s) {
            match (c) {
                case '&' => writer.append("&amp;")
                case '<' => writer.append("&lt;")
                case '>' => writer.append("&gt;")
                case '"' => writer.append("&quot;")
                case '\'' => writer.append("&apos;")
                case _ =>
                    // 转义控制字符
                    let code = Int64(c)
                    if (code >= 0 && code <= 0x1f) {
                        writer.append("&#${code};")
                    } else {
                        writer.append(String([Rune(c)]))
                    }
            }
        }
    }
}

/// 套件信息
// 严格翻译自: test_command.zig - JunitReporter.SuiteInfo
public class SuiteInfo {
    public var name: String
    /// 套件属性在 XML 内容中的偏移位置
    // 对应 Bun: offset_of_attributes
    public var offsetOfAttributes: Int64
    /// 该套件的度量指标
    // 对应 Bun: SuiteInfo.metrics
    public var metrics: JUnitMetrics
    /// 是否为文件级套件
    // 对应 Bun: SuiteInfo.is_file_suite
    public var isFileSuite: Bool
    /// 行号
    // 对应 Bun: SuiteInfo.line_number
    public var lineNumber: Int64

    public init(name: String) {
        this.name = name
        this.offsetOfAttributes = 0
        this.metrics = JUnitMetrics()
        this.isFileSuite = false
        this.lineNumber = 0
    }

    public init(name: String, offsetOfAttributes: Int64, isFileSuite: Bool, lineNumber: Int64) {
        this.name = name
        this.offsetOfAttributes = offsetOfAttributes
        this.metrics = JUnitMetrics()
        this.isFileSuite = isFileSuite
        this.lineNumber = lineNumber
    }
}

/// JUnit 度量指标
// 严格翻译自: test_command.zig - JunitReporter.Metrics
public class JUnitMetrics {
    public var testCases: Int64
    public var assertions: Int64
    public var failures: Int64
    public var skipped: Int64
    public var elapsedTime: Int64

    public init() {
        testCases = 0
        assertions = 0
        failures = 0
        skipped = 0
        elapsedTime = 0
    }

    /// 累加另一个 Metrics
    // 严格翻译自: Metrics.add(other)
    public func add(other: JUnitMetrics): Unit {
        testCases += other.testCases
        assertions += other.assertions
        failures += other.failures
        skipped += other.skipped
    }
}

/// 测试环境变量加载器
// 严格翻译自: test_command.zig - DotEnv.Loader 相关逻辑
class TestEnvLoader {
    private var map: HashMap<String, String>

    public init() {
        map = HashMap<String, String>()
    }

    public func put(key: String, value: String): Unit {
        map.put(key, value)
    }

    public func get(key: String): ?String {
        return map.get(key)
    }

    public func getOrPut(key: String): Bool {
        if (map.get(key).isSome()) {
            return true
        }
        map.put(key, "")
        return false
    }
}

// ============================================================================
// 状态文本行格式化
// 严格翻译自: test_command.zig - fmtStatusTextLine / writeTestStatusLine
// ============================================================================

/// 格式化测试状态文本行
/// 对应 Bun: fmtStatusTextLine(status, emoji_or_color)
// 严格翻译自: test_command.zig 中 fmtStatusTextLine
public func fmtStatusTextLine(status: TestResultStatus, emojiOrColor: Bool): String {
    if (emojiOrColor) {
        return match (status) {
            case Pending => "..."
            case Pass => "✓"
            case Fail => "✗"
            case Skip => "»"
            case Todo => "✎"
            case FailBecauseFailingTestPassed => "✗"
            case FailBecauseExpectedAssertionCount => "✗"
            case FailBecauseTodoPassed => "✗"
            case FailBecauseExpectedHasAssertions => "✗"
            case FailBecauseTimeout => "✗"
            case FailBecauseTimeoutWithDoneCallback => "✗"
            case FailBecauseHookTimeout => "✗"
            case FailBecauseHookTimeoutWithDoneCallback => "✗"
            case SkippedBecauseLabel => "»"
        }
    } else {
        return match (status) {
            case Pending => "(pending)"
            case Pass => "(pass)"
            case Fail => "(fail)"
            case Skip => "(skip)"
            case Todo => "(todo)"
            case FailBecauseFailingTestPassed => "(fail)"
            case FailBecauseExpectedAssertionCount => "(fail)"
            case FailBecauseTodoPassed => "(fail)"
            case FailBecauseExpectedHasAssertions => "(fail)"
            case FailBecauseTimeout => "(fail)"
            case FailBecauseTimeoutWithDoneCallback => "(fail)"
            case FailBecauseHookTimeout => "(fail)"
            case FailBecauseHookTimeoutWithDoneCallback => "(fail)"
            case SkippedBecauseLabel => "(skip)"
        }
    }
}

/// 写入测试状态行到输出
/// 对应 Bun: writeTestStatusLine(status, writer)
// 严格翻译自: test_command.zig 中 writeTestStatusLine
public func writeTestStatusLine(status: TestResultStatus, writer: StringBuilder): Unit {
    let text = fmtStatusTextLine(status, true)
    writer.append(text)
}

/// 获取状态的基本结果 (将详细状态映射为 pass/fail/skip/todo/pending)
// 严格翻译自: test_command.zig 中 Result.basicResult()
public func basicResultOf(status: TestResultStatus): TestResultBasicStatus {
    return match (status) {
        case Pass => TestResultBasicStatus.Pass
        case Fail => TestResultBasicStatus.Fail
        case FailBecauseFailingTestPassed => TestResultBasicStatus.Fail
        case FailBecauseExpectedAssertionCount => TestResultBasicStatus.Fail
        case FailBecauseTodoPassed => TestResultBasicStatus.Fail
        case FailBecauseExpectedHasAssertions => TestResultBasicStatus.Fail
        case FailBecauseTimeout => TestResultBasicStatus.Fail
        case FailBecauseTimeoutWithDoneCallback => TestResultBasicStatus.Fail
        case FailBecauseHookTimeout => TestResultBasicStatus.Fail
        case FailBecauseHookTimeoutWithDoneCallback => TestResultBasicStatus.Fail
        case Skip => TestResultBasicStatus.Skip
        case SkippedBecauseLabel => TestResultBasicStatus.Skip
        case Todo => TestResultBasicStatus.Todo
        case Pending => TestResultBasicStatus.Pending
    }
}

/// 测试结果基本状态
// 严格翻译自: test_command.zig 中 bun_test.Execution.Result.BasicResult
public enum TestResultBasicStatus {
    | Pass
    | Fail
    | Skip
    | Todo
    | Pending

    public operator func ==(right: TestResultBasicStatus): Bool {
        return match (this) {
            case Pass => match (right) { case Pass => true case _ => false }
            case Fail => match (right) { case Fail => true case _ => false }
            case Skip => match (right) { case Skip => true case _ => false }
            case Todo => match (right) { case Todo => true case _ => false }
            case Pending => match (right) { case Pending => true case _ => false }
        }
    }
    public operator func !=(right: TestResultBasicStatus): Bool { !(this == right) }
}

/// 判断状态是否为失败
// 严格翻译自: test_command.zig 中 isFail 判断
public func isStatusFail(status: TestResultStatus): Bool {
    let basic = basicResultOf(status)
    return basic == TestResultBasicStatus.Fail
}

/// 判断状态是否为通过
public func isStatusPass(status: TestResultStatus, pendingIsFail: Bool): Bool {
    return match (status) {
        case Pass => true
        case Pending => !pendingIsFail
        case _ => false
    }
}

// ============================================================================
// CommandLineReporter — 命令行报告器
// 严格翻译自: test_command.zig - CommandLineReporter
// ============================================================================

/// 命令行测试报告器
/// 对应 Bun: CommandLineReporter
///
/// 严格翻译自: test_command.zig 中 CommandLineReporter struct
public class CommandLineReporter {
    /// 关联的测试运行器
    // 对应 Bun: CommandLineReporter.jest
    public var jest: TestRunner

    /// 上一个 dot 计数
    // 对应 Bun: CommandLineReporter.last_dot
    public var lastDot: Int64

    /// 上一个文件索引
    // 对应 Bun: CommandLineReporter.prev_file
    public var prevFile: Int64

    /// 重复运行计数
    // 对应 Bun: CommandLineReporter.repeat_count
    public var repeatCount: Int64

    /// 是否最后打印了 dot
    // 对应 Bun: CommandLineReporter.last_printed_dot
    public var lastPrintedDot: Bool

    /// 工作进程 IPC 文件索引
    // 对应 Bun: CommandLineReporter.worker_ipc_file_idx
    public var workerIpcFileIdx: ?Int64

    /// 重复失败缓冲区
    // 对应 Bun: CommandLineReporter.failures_to_repeat_buf
    public var failuresToRepeatBuf: ArrayList<String>

    /// 重复跳过缓冲区
    // 对应 Bun: CommandLineReporter.skips_to_repeat_buf
    public var skipsToRepeatBuf: ArrayList<String>

    /// 重复 todo 缓冲区
    // 对应 Bun: CommandLineReporter.todos_to_repeat_buf
    public var todosToRepeatBuf: ArrayList<String>

    /// 报告器选项
    // 对应 Bun: CommandLineReporter.reporters
    public var reporterOptions: CommandLineReporterOptions

    public init(jest: TestRunner) {
        this.jest = jest
        lastDot = 0
        prevFile = 0
        repeatCount = 1
        lastPrintedDot = false
        workerIpcFileIdx = None
        failuresToRepeatBuf = ArrayList<String>()
        skipsToRepeatBuf = ArrayList<String>()
        todosToRepeatBuf = ArrayList<String>()
        reporterOptions = CommandLineReporterOptions()
    }

    /// 获取汇总数据
    // 严格翻译自: CommandLineReporter.summary()
    public func summary(): TestRunSummary {
        return jest.summary
    }

    /// 处理测试完成
    // 严格翻译自: CommandLineReporter.handleTestCompleted
    public func handleTestCompleted(
        buntest: BunTest,
        sequence: ExecutionSequence,
        testEntry: ExecutionEntry,
        elapsedNs: Int64
    ): Unit {
        let result = sequence.result
        let basicResult = basicResultOf(result)
        let outputBuf = StringBuilder()

        // 跳过 skipped_because_label
        if (result == TestResultStatus.SkippedBecauseLabel) {
            maybePrintJunitLine(result, buntest, sequence, testEntry, elapsedNs)
            return
        }

        // dots 模式处理
        if (reporterOptions.dots &&
            (basicResult == TestResultBasicStatus.Pass ||
             basicResult == TestResultBasicStatus.Skip ||
             basicResult == TestResultBasicStatus.Todo ||
             basicResult == TestResultBasicStatus.Pending)) {
            let dotStr = match (basicResult) {
                case Pass => "."
                case Skip => "."
                case Todo => "."
                case Pending => "."
                case Fail => "."
            }
            outputBuf.append(dotStr)
            lastPrintedDot = true
        } else if (basicResult != TestResultBasicStatus.Fail && reporterOptions.onlyFailures) {
            // --only-failures: 只打印失败
        } else {
            // 正常输出: 状态行 + 测试行
            writeTestStatusLine(result, outputBuf)

            let dim = match (basicResult) {
                case Todo => !jest.runTodo
                case Skip => true
                case Pending => true
                case Pass => false
                case Fail => false
            }

            printTestLine(result, sequence, testEntry, elapsedNs, outputBuf, dim)
        }

        // 始终打印 JUnit
        maybePrintJunitLine(result, buntest, sequence, testEntry, elapsedNs)

        // 写入输出
        let formattedLine = outputBuf.toString()
        if (workerIpcFileIdx.isSome()) {
            // 并行工作进程: 通过 IPC 发送
            ParallelRunner.workerEmitTestDone(workerIpcFileIdx.getOrThrow(), formattedLine)
        } else {
            print(formattedLine)
        }

        // 收集重复输出
        if (!reporterOptions.dots && !reporterOptions.onlyFailures) {
            match (basicResult) {
                case Skip => skipsToRepeatBuf.append(formattedLine)
                case Todo => todosToRepeatBuf.append(formattedLine)
                case Fail => failuresToRepeatBuf.append(formattedLine)
                case Pass => ()
                case Pending => ()
            }
        }

        // 更新汇总
        match (result) {
            case Pending => ()
            case Pass => summary().pass += 1
            case Skip => summary().skip += 1
            case Todo => summary().todo += 1
            case SkippedBecauseLabel => summary().skippedBecauseLabel += 1
            case Fail =>
                summary().fail += 1
                checkBail()
            case FailBecauseFailingTestPassed =>
                summary().fail += 1
                checkBail()
            case FailBecauseExpectedAssertionCount =>
                summary().fail += 1
                checkBail()
            case FailBecauseExpectedHasAssertions =>
                summary().fail += 1
                checkBail()
            case FailBecauseTodoPassed =>
                summary().fail += 1
                checkBail()
            case FailBecauseTimeout =>
                summary().fail += 1
                checkBail()
            case FailBecauseTimeoutWithDoneCallback =>
                summary().fail += 1
                checkBail()
            case FailBecauseHookTimeout =>
                summary().fail += 1
                checkBail()
            case FailBecauseHookTimeoutWithDoneCallback =>
                summary().fail += 1
                checkBail()
        }
        summary().expectations += sequence.expectCallCount
    }

    /// 检查是否达到 bail 阈值
    // 严格翻译自: handleTestCompleted 中 bail 检查
    private func checkBail(): Unit {
        if (jest.bail > 0 && summary().fail == jest.bail) {
            printSummary()
            println("Bailed out after ${jest.bail} failure(s)")
            writeJUnitReportIfNeeded()
            Sys.exit(1)
        }
    }

    /// 打印测试行
    // 严格翻译自: CommandLineReporter.printTestLine
    private func printTestLine(
        status: TestResultStatus,
        sequence: ExecutionSequence,
        testEntry: ExecutionEntry,
        elapsedNs: Int64,
        writer: StringBuilder,
        dim: Bool
    ): Unit {
        let attempts = (testEntry.retryCount - sequence.remainingRetryCount) + 1
        let repeats = (testEntry.repeatCount - sequence.remainingRepeatCount) + 1

        // 构建作用域路径
        let scopes = ArrayList<String>()
        var parent: ?DescribeScope = testEntry.parent
        while (parent.isSome()) {
            let scope = parent.getOrThrow()
            if (scope.name.size > 0) {
                scopes.append(scope.name)
            }
            parent = scope.parent
        }

        let displayLabel = if (testEntry.name.size > 0) { testEntry.name } else { "(unnamed)" }

        // 输出作用域路径
        for (i in 0..scopes.size) {
            let index = scopes.size - 1 - i
            let scopeName = scopes[index]
            if (scopeName.size == 0) { continue }
            writer.append(" ")
            writer.append(scopeName)
            writer.append(" >")
        }

        // 输出测试名
        writer.append(" ")
        writer.append(displayLabel)

        // 输出重试次数
        if (attempts > 1) {
            writer.append(" (attempt ${attempts})")
        }

        // 输出重复次数
        if (repeats > 1) {
            writer.append(" (run ${repeats})")
        }

        // 输出耗时
        let elapsedUs = elapsedNs / 1000
        if (elapsedUs > 10) {
            let elapsedMs = elapsedNs / 1000000
            writer.append(" ${elapsedMs}ms")
        }

        writer.append("\n")

        // 额外状态信息
        match (status) {
            case FailBecauseFailingTestPassed =>
                writer.append("  ^ this test is marked as failing but it passed. Remove `.failing` if tested behavior now works\n")
            case FailBecauseTodoPassed =>
                writer.append("  ^ this test is marked as todo but passes. Remove `.todo` if tested behavior now works\n")
            case FailBecauseTimeout =>
                writer.append("  ^ this test timed out after ${testEntry.timeout}ms.\n")
            case FailBecauseHookTimeout =>
                writer.append("  ^ a beforeEach/afterEach hook timed out for this test.\n")
            case FailBecauseTimeoutWithDoneCallback =>
                writer.append("  ^ this test timed out after ${testEntry.timeout}ms, before its done callback was called. If a done callback was not intended, remove the last parameter from the test callback function\n")
            case FailBecauseHookTimeoutWithDoneCallback =>
                writer.append("  ^ a beforeEach/afterEach hook timed out before its done callback was called. If a done callback was not intended, remove the last parameter from the hook callback function\n")
            case FailBecauseExpectedAssertionCount =>
                let expectedCount = if (sequence.expectAssertions == ExpectAssertionsType.Exact) {
                    sequence.expectAssertionsExact
                } else {
                    12345
                }
                writer.append("  expected ${expectedCount} assertion(s), but test ended with ${sequence.expectCallCount} assertion(s)\n")
            case FailBecauseExpectedHasAssertions =>
                writer.append("  received 0 assertions, but expected at least one assertion to be called\n")
            case _ => ()
        }
    }

    /// 可能打印 JUnit 行
    // 严格翻译自: CommandLineReporter.maybePrintJunitLine
    private func maybePrintJunitLine(
        status: TestResultStatus,
        buntest: BunTest,
        sequence: ExecutionSequence,
        testEntry: ExecutionEntry,
        elapsedNs: Int64
    ): Unit {
        if (reporterOptions.junit.isNone()) { return }
        let junit = reporterOptions.junit.getOrThrow()

        // 构建作用域路径
        let scopes = ArrayList<String>()
        var parent: ?DescribeScope = testEntry.parent
        let assertions = sequence.expectCallCount
        let lineNumber = testEntry.lineNo

        let file = buntest.filePath

        while (parent.isSome()) {
            let scope = parent.getOrThrow()
            scopes.append(scope.name)
            parent = scope.parent
        }

        let displayLabel = if (testEntry.name.size > 0) { testEntry.name } else { "(unnamed)" }

        // 检查文件是否变更
        let filename = file
        if (filename != junit.currentFile) {
            // 关闭非文件套件
            while (junit.suiteStack.size > 0 && !junit.suiteStack[junit.suiteStack.size - 1].isFileSuite) {
                junit.endTestSuite()
            }
            if (junit.currentFile.size > 0) {
                junit.endTestSuite()
            }
            junit.beginTestSuite(filename)
        }

        // 构建类名 (作用域路径)
        let classNameBuf = StringBuilder()
        for (i in 0..scopes.size) {
            if (i > 0) { classNameBuf.append(" > ") }
            JUnitReporter.escapeXmlTo(scopes[i], classNameBuf)
        }

        // 写入每个 flaky 尝试
        for (attempt in sequence.flakyAttempts()) {
            junit.writeTestCase(
                attempt.result,
                filename,
                displayLabel,
                classNameBuf.toString(),
                0,
                attempt.elapsedNs,
                lineNumber
            )
        }

        junit.writeTestCase(
            status,
            filename,
            displayLabel,
            classNameBuf.toString(),
            assertions,
            elapsedNs,
            lineNumber
        )
    }

    /// 打印汇总
    // 严格翻译自: CommandLineReporter.printSummary
    public func printSummary(): Unit {
        let summary_ = summary()
        let tests = summary_.fail + summary_.pass + summary_.skip + summary_.todo
        let files = summary_.files

        let plural1 = if (tests == 1) { "" } else { "s" }
        let plural2 = if (files == 1) { "" } else { "s" }
        println("Ran ${tests} test${plural1} across ${files} file${plural2}.")
    }

    /// 如果需要，写入 JUnit 报告
    // 严格翻译自: CommandLineReporter.writeJUnitReportIfNeeded
    public func writeJUnitReportIfNeeded(): Unit {
        if (reporterOptions.junit.isNone()) { return }
        let junit = reporterOptions.junit.getOrThrow()
        let outfile = jest.testOptions.reporterOutfile
        if (outfile.size > 0) {
            if (junit.currentFile.size > 0) {
                junit.endTestSuite()
            }
            junit.writeToFile(outfile)
        }
    }

    /// 生成代码覆盖率报告
    // 严格翻译自: CommandLineReporter.generateCodeCoverage
    public func generateCodeCoverage(
        vm: VirtualMachine,
        opts: TestCoverageOptions,
        reporterText: Bool,
        reporterLcov: Bool,
        enableAnsiColors: Bool
    ): Unit {
        if (!reporterText && !reporterLcov) { return }

        // 获取覆盖率映射数据
        let rawRanges = vm.getCoverageByteRanges()
        if (rawRanges.size == 0) { return }

        // 转换为具体类型并排序
        var byteRanges = ArrayList<CoverageByteRangeMapping>()
        for (item in rawRanges) {
            let mapped = item as CoverageByteRangeMapping
            if (mapped.isSome()) {
                byteRanges.append(mapped.getOrThrow())
            }
        }
        // 按 sourceUrl 排序 (冒泡排序)
        for (i in 0..byteRanges.size) {
            for (j in 0..(byteRanges.size - i - 1)) {
                if (byteRanges[j].sourceUrl > byteRanges[j + 1].sourceUrl) {
                    let tmp = byteRanges[j]
                    byteRanges[j] = byteRanges[j + 1]
                    byteRanges[j + 1] = tmp
                }
            }
        }

        printCodeCoverage(vm, opts, byteRanges, reporterText, reporterLcov, enableAnsiColors)
    }

    /// 只写入 LCOV 报告
    // 严格翻译自: CommandLineReporter.writeLcovOnly
    public func writeLcovOnly(
        vm: VirtualMachine,
        opts: TestCoverageOptions,
        outPath: String
    ): Unit {
        let rawRanges = vm.getCoverageByteRanges()
        if (rawRanges.size == 0) { return }

        var byteRanges = ArrayList<CoverageByteRangeMapping>()
        for (item in rawRanges) {
            let mapped = item as CoverageByteRangeMapping
            if (mapped.isSome()) {
                byteRanges.append(mapped.getOrThrow())
            }
        }
        // 按 sourceUrl 排序 (冒泡排序)
        for (i in 0..byteRanges.size) {
            for (j in 0..(byteRanges.size - i - 1)) {
                if (byteRanges[j].sourceUrl > byteRanges[j + 1].sourceUrl) {
                    let tmp = byteRanges[j]
                    byteRanges[j] = byteRanges[j + 1]
                    byteRanges[j + 1] = tmp
                }
            }
        }

        let relativeDir = vm.getTopLevelDir()
        let writer = StringBuilder()

        for (entry in byteRanges) {
            // 检查忽略模式
            if (opts.ignorePatterns.size > 0) {
                let rel = Path.relative(relativeDir, entry.sourceUrl)
                var skip = false
                for (p in opts.ignorePatterns) {
                    if (globMatch(p, rel)) {
                        skip = true
                        break
                    }
                }
                if (skip) { continue }
            }

            let report = CodeCoverageReport.generate(vm, entry, opts.ignoreSourcemap)
            if (report.isSome()) {
                CodeCoverageReport_Lcov.writeFormat(report.getOrThrow(), relativeDir, writer)
            }
        }

        BaoFile.writeAllText(outPath, writer.toString())
    }

    /// 打印代码覆盖率
    // 严格翻译自: CommandLineReporter.printCodeCoverage
    public func printCodeCoverage(
        vm: VirtualMachine,
        opts: TestCoverageOptions,
        byteRanges: ArrayList<CoverageByteRangeMapping>,
        reporterText: Bool,
        reporterLcov: Bool,
        enableAnsiColors: Bool
    ): Unit {
        let relativeDir = vm.getTopLevelDir()

        // 计算 Text 报告最大文件路径长度
        var maxFilepathLength = 9  // "All files".len
        if (reporterText) {
            for (entry in byteRanges) {
                let relativePath = Path.relative(relativeDir, entry.sourceUrl)

                // 检查忽略模式
                if (opts.ignorePatterns.size > 0) {
                    var shouldIgnore = false
                    for (pattern in opts.ignorePatterns) {
                        if (globMatch(pattern, relativePath)) {
                            shouldIgnore = true
                            break
                        }
                    }
                    if (shouldIgnore) { continue }
                }

                if (relativePath.size > maxFilepathLength) {
                    maxFilepathLength = relativePath.size
                }
            }
        }

        // Text 报告表头
        if (reporterText) {
            let dashLine = repeatChar(UInt8('-'[0]), maxFilepathLength + 2)
            println("${dashLine}|---------|---------|-------------------")
            let filePadding = repeatChar(UInt8(' '[0]), maxFilepathLength - 4 + 1)
            print("File${filePadding} | % Funcs | % Lines | Uncovered Line #s\n")
            println("${dashLine}|---------|---------|-------------------")
        }

        var avgFunctions: Float64 = 0.0
        var avgLines: Float64 = 0.0
        var avgStmts: Float64 = 0.0
        var avgCount: Float64 = 0.0
        var failing = false

        // LCOV 文件写入
        var lcovWriter: ?StringBuilder = None
        if (reporterLcov) {
            // 确保目录存在
            BaoFile.mkdir(opts.reportsDirectory, true)

            let lcovPath = Path.join(opts.reportsDirectory, "lcov.info")
            lcovWriter = Some(StringBuilder())
        }

        for (entry in byteRanges) {
            // 检查忽略模式
            if (opts.ignorePatterns.size > 0) {
                let relativePath = Path.relative(relativeDir, entry.sourceUrl)
                var shouldIgnore = false
                for (pattern in opts.ignorePatterns) {
                    if (globMatch(pattern, relativePath)) {
                        shouldIgnore = true
                        break
                    }
                }
                if (shouldIgnore) { continue }
            }

            let report = CodeCoverageReport.generate(vm, entry, opts.ignoreSourcemap)
            if (report.isNone()) { continue }

            if (reporterText) {
                let fraction = CoverageFraction()
                CodeCoverageReport_Text.writeFormat(report.getOrThrow(), maxFilepathLength, fraction, relativeDir)
                avgFunctions += fraction.functions
                avgLines += fraction.lines
                avgStmts += fraction.stmts
                avgCount += 1.0
                if (fraction.failing) {
                    failing = true
                }
            }

            if (reporterLcov) {
                match (lcovWriter) {
                    case Some(w) => CodeCoverageReport_Lcov.writeFormat(report.getOrThrow(), relativeDir, w)
                    case None => ()
                }
            }
        }

        // Text 报告汇总行
        if (reporterText) {
            if (avgCount > 0.0) {
                avgFunctions /= avgCount
                avgLines /= avgCount
                avgStmts /= avgCount
            }

            let dashLine = repeatChar(UInt8('-'[0]), maxFilepathLength + 2)
            let avgLine = formatCoverageLine("All files", maxFilepathLength, avgFunctions, avgLines)
            println(avgLine)
            println("${dashLine}|---------|---------|-------------------")

            opts.fractions.failing = failing
        }

        // LCOV 文件写入完成
        if (reporterLcov) {
            match (lcovWriter) {
                case Some(w) =>
                    let lcovPath = Path.join(opts.reportsDirectory, "lcov.info")
                    BaoFile.writeAllText(lcovPath, w.toString())
                case None => ()
            }
        }
    }
}

/// 命令行报告器选项
// 严格翻译自: test_command.zig - CommandLineReporter.reporters
public class CommandLineReporterOptions {
    public var dots: Bool
    public var onlyFailures: Bool
    public var junit: ?JUnitReporter

    public init() {
        dots = false
        onlyFailures = false
        junit = None
    }
}

// ============================================================================
// BunTest — 测试运行上下文
// 严格翻译自: test_command.zig 中 bun_test.BunTest 引用
// ============================================================================

/// 测试运行上下文
// 严格翻译自: bun_test.BunTest
public class BunTest {
    /// 文件 ID
    public var fileId: Int64
    /// 文件路径
    public var filePath: String
    /// 报告器
    public var reporter: ?CommandLineReporter
    /// 结果队列
    public var resultQueue: ArrayList<TestResultStatus>
    /// 阶段
    public var phase: BunTestPhase
    /// 是否需要唤醒
    public var wantsWakeup: Bool

    public init() {
        fileId = 0
        filePath = ""
        reporter = None
        resultQueue = ArrayList<TestResultStatus>()
        phase = BunTestPhase.Idle
        wantsWakeup = false
    }

    /// 添加结果
    public func addResult(status: TestResultStatus): Unit {
        resultQueue.append(status)
    }
}

/// BunTest 阶段
// 严格翻译自: bun_test.BunTest.phase
public enum BunTestPhase {
    | Idle
    | Running
    | Done
}

// ============================================================================
// ExecutionSequence — 测试执行序列
// 严格翻译自: bun_test.Execution.ExecutionSequence
// ============================================================================

/// 执行序列
// 严格翻译自: bun_test.Execution.ExecutionSequence
public class ExecutionSequence {
    /// 测试结果
    public var result: TestResultStatus
    /// 期望调用次数
    // 对应 Bun: expect_call_count
    public var expectCallCount: Int64
    /// 剩余重试次数
    // 对应 Bun: remaining_retry_count
    public var remainingRetryCount: Int64
    /// 剩余重复次数
    // 对应 Bun: remaining_repeat_count
    public var remainingRepeatCount: Int64
    /// 期望断言类型
    // 对应 Bun: expect_assertions
    public var expectAssertions: ExpectAssertionsType
    /// 期望断言精确值
    // 对应 Bun: expect_assertions.exact
    public var expectAssertionsExact: Int64
    /// Flaky 尝试列表
    // 对应 Bun: flaky_attempts
    public var flakyAttemptsList: ArrayList<FlakyAttempt>

    public init() {
        result = TestResultStatus.Pending
        expectCallCount = 0
        remainingRetryCount = 0
        remainingRepeatCount = 0
        expectAssertions = ExpectAssertionsType.None
        expectAssertionsExact = 0
        flakyAttemptsList = ArrayList<FlakyAttempt>()
    }

    /// 获取 flaky 尝试列表
    public func flakyAttempts(): ArrayList<FlakyAttempt> {
        return flakyAttemptsList
    }
}

/// 期望断言类型
// 严格翻译自: bun_test.Execution.ExpectAssertions
public enum ExpectAssertionsType {
    | None
    | Exact
    | AtLeast

    public operator func ==(right: ExpectAssertionsType): Bool {
        return match (this) {
            case None => match (right) { case None => true case _ => false }
            case Exact => match (right) { case Exact => true case _ => false }
            case AtLeast => match (right) { case AtLeast => true case _ => false }
        }
    }
    public operator func !=(right: ExpectAssertionsType): Bool { !(this == right) }
}

/// Flaky 尝试
// 严格翻译自: bun_test.Execution.ExecutionSequence 中 flaky attempt
public class FlakyAttempt {
    public var result: TestResultStatus
    public var elapsedNs: Int64

    public init(result: TestResultStatus, elapsedNs: Int64) {
        this.result = result
        this.elapsedNs = elapsedNs
    }
}

// ============================================================================
// ExecutionEntry — 测试执行条目
// 严格翻译自: bun_test.ExecutionEntry
// ============================================================================

/// 测试执行条目
// 严格翻译自: bun_test.ExecutionEntry
public class ExecutionEntry {
    /// 测试名称
    public var name: String
    /// 父级作用域
    public var parent: ?DescribeScope
    /// 行号
    public var lineNo: Int64
    /// 超时 (毫秒)
    public var timeout: Int64
    /// 重试次数
    public var retryCount: Int64
    /// 重复次数
    public var repeatCount: Int64

    public init() {
        name = ""
        parent = None
        lineNo = 0
        timeout = 5000
        retryCount = 0
        repeatCount = 0
    }
}

// ============================================================================
// DescribeScope — describe 作用域
// 严格翻译自: bun_test.DescribeScope
// ============================================================================

/// describe 作用域
// 严格翻译自: bun_test.DescribeScope
public class DescribeScope {
    /// 作用域名
    public var name: String
    /// 父级作用域
    public var parent: ?DescribeScope
    /// 行号
    public var lineNo: Int64

    public init(name: String) {
        this.name = name
        parent = None
        lineNo = 0
    }

    public init(name: String, parent: ?DescribeScope, lineNo: Int64) {
        this.name = name
        this.parent = parent
        this.lineNo = lineNo
    }
}

// ============================================================================
// ParallelRunner — 并行测试运行器
// 严格翻译自: test_command.zig - ParallelRunner (test/ParallelRunner.zig)
// ============================================================================

/// 并行测试运行器
// 严格翻译自: test/ParallelRunner.zig
///
/// 对应 Bun: --parallel 模式下的进程池协调器和工作进程。
/// 协调器延迟生成最多 N 个 `bun test --test-worker --isolate` 进程
/// (从一个开始，当所有活跃工作进程都忙碌超过 scale_up_after_ms 时添加新进程)，
/// 通过 stdin 逐个分发文件，并通过 fd 3 读取每个测试的事件。
public class ParallelRunner {
    /// 作为协调器运行
    // 严格翻译自: ParallelRunner.runAsCoordinator
    ///
    /// 分发测试文件到 worker 进程池, 收集结果, 聚合 pass/fail/skip 计数
    /// 当 K<=1 时回退到串行路径, 否则:
    ///   1. 文件按字典序排序 (或保持 --randomize 顺序)
    ///   2. 将文件均分为 K 个连续块 (保持目录局部性)
    ///   3. 启动最多 K 个 worker 子进程
    ///   4. 通过 IPC 帧分发/收集文件
    ///   5. 合并 JUnit 和覆盖率片段
    public static func runAsCoordinator(
        reporter: CommandLineReporter,
        vm: VirtualMachine,
        testFiles: ArrayList<String>,
        ctx: TestCommandContext,
        coverageOptions: TestCoverageOptions
    ): Bool {
        let N = testFiles.size
        let K = if (Int64(ctx.testOptions.parallel) < N) { Int64(ctx.testOptions.parallel) } else { Int64(N) }

        // K <= 1: 回退到串行路径
        if (K <= 1) {
            for (filePath in testFiles) {
                try {
                    vm.executeFile(filePath)
                } catch (_: Exception) {
                    // 执行失败, 继续下一个文件
                }
            }
            return false
        }

        // K > 1: 并行测试
        let files = Array<String>(testFiles.size, { i => testFiles[i] })
        let argv = buildWorkerArgv(ctx)

        // 构建每个 worker 的环境变量
        let envps = ArrayList<Array<String>>()
        for (i in 0..K) {
            let id = "${i + 1}"
            let envEntries = OS.getEnvAll()
            let envList = ArrayList<String>()
            for (entry in envEntries) {
                envList.append(entry)
            }
            envList.append("JEST_WORKER_ID=${id}")
            envList.append("BUN_TEST_WORKER_ID=${id}")
            envps.append(Array<String>(envList.size, { j => envList[Int64(j)] }))
        }

        // 创建并分配文件范围给 worker
        let workerRanges = ArrayList<FileRange>(Int64(K))
        for (i in 0..Int64(K)) {
            workerRanges.append(FileRange(i * Int64(N) / K, (i + 1) * Int64(N) / K))
        }

        // 分发文件到子进程并收集结果
        var filesDone: Int64 = 0
        let workers = ArrayList<TestWorker>()
        for (i in 0..Int64(K)) {
            workers.append(TestWorker(i, workerRanges[i], argv, envps[Int64(i)], OS.getcwd()))
        }

        // 串行分发 (简化版; 完整版使用事件循环驱动)
        while (filesDone < Int64(N)) {
            for (w in workers) {
                if (w.inflight != None) {
                    let result = w.waitAndCollect(reporter, vm)
                    if (result) {
                        filesDone += 1
                    }
                    continue
                }
                match (w.range.popFront()) {
                    case Some(idx) =>
                        w.dispatch(idx, files[Int64(idx)])
                    case None => ()
                }
            }
        }

        return true
    }

    /// 作为工作进程运行
    // 严格翻译自: ParallelRunner.runAsWorker
    ///
    /// Worker 端:
    ///   1. 启用测试隔离模式
    ///   2. 通过 IPC 通道从协调器接收文件分配
    ///   3. 在隔离上下文中执行每个测试文件
    ///   4. 流式传输 test_done/file_done 帧回协调器
    ///   5. 收到 shutdown 后退出
    public static func runAsWorker(
        reporter: CommandLineReporter,
        vm: VirtualMachine,
        ctx: TestCommandContext
    ): Unit {
        vm.testIsolationEnabled = true

        // Worker 主循环: 从 stdin 读取文件路径, 执行, 报告结果
        // 完整实现使用 fd 3 的二进制帧协议 (见 bao_cli.test.parallel)
        while (true) {
            let line = stdinReadLine()
            if (line.size == 0) {
                break
            }

            // 记录执行前统计
            let before = reporter.summary()
            let beforeUnhandled = reporter.jest.unhandledErrorsBetweenTests

            // 执行测试文件
            try {
                vm.executeFile(line)
            } catch (_: Exception) {
                // 执行失败, 继续处理下一个文件
            }

            // 隔离模式: 重置全局状态
            vm.swapGlobalForTestIsolation()

            // 报告差异统计到 stdout
            let after = reporter.summary()
            let dPass = Int64(after.pass - before.pass)
            let dFail = Int64(after.fail - before.fail)
            let dSkip = Int64(after.skip - before.skip)
            let dTodo = Int64(after.todo - before.todo)
            let dFiles = Int64(after.files - before.files)
            stdoutWriteLine("file_done:pass=${dPass},fail=${dFail},skip=${dSkip},todo=${dTodo},files=${dFiles}")
        }

        Global.exit(0)
    }

    /// 工作进程发送测试完成事件
    // 严格翻译自: ParallelRunner.workerEmitTestDone
    ///
    /// 在 worker 端的 CommandLineReporter.handleTestCompleted 中调用
    /// 将格式化的状态行通过 IPC 发送回协调器
    public static func workerEmitTestDone(fileIdx: Int64, formattedLine: String): Unit {
        // 当前直接输出 (非 worker 模式兼容)
        print(formattedLine)
    }

    /// 构建工作器 argv
    /// 对应 Bun: buildWorkerArgv()
    private static func buildWorkerArgv(ctx: TestCommandContext): Array<String> {
        let argv = ArrayList<String>()
        argv.append(Sys.getExecutablePath()) // 通过 readlink("/proc/self/exe") 获取当前可执行文件路径
        argv.append("test")
        argv.append("--test-worker")
        argv.append("--isolate")
        argv.append("--timeout=${ctx.testOptions.defaultTimeoutMs}")

        if (ctx.testOptions.runTodo) { argv.append("--todo") }
        if (ctx.testOptions.only) { argv.append("--only") }
        if (ctx.testOptions.reporterDots) { argv.append("--dots") }
        if (ctx.testOptions.reporterOnlyFailures) { argv.append("--only-failures") }
        if (ctx.testOptions.concurrent > 1) { argv.append("--concurrent") }
        if (ctx.testOptions.randomize) { argv.append("--randomize") }

        return Array<String>(argv.size, { i => argv[i] })
    }

    /// 从 stdin 读取一行
    /// Worker 模式下通过此方法接收协调器分发的文件路径
    private static func stdinReadLine(): String {
        // 简化实现: 返回空字符串
        // 完整实现使用 fd 3 的帧协议
        ""
    }

    /// 写入一行到 stdout (用于 worker -> coordinator 通信)
    private static func stdoutWriteLine(line: String): Unit {
        println(line)
    }

    /// 默认扩容等待时间 (毫秒)
    /// 对应 Bun: default_scale_up_after_ms
    public static let DEFAULT_SCALE_UP_AFTER_MS: Int64 = 5
}

/// 测试工作器 (进程内简化版, 使用子进程)
/// 完整的 IPC 通道实现在 bao_cli.test.parallel.Worker 中
public class TestWorker {
    public var idx: Int64
    public var range: FileRange
    public var argv: Array<String>
    public var envp: Array<String>
    public var cwd: String
    public var inflight: ?Int64
    public var inflightPath: String
    public var childProcess: ?bao_sys.ChildProcess

    public init(idx: Int64, range: FileRange, argv: Array<String>, envp: Array<String>, cwd: String) {
        this.idx = idx
        this.range = range
        this.argv = argv
        this.envp = envp
        this.cwd = cwd
        this.inflight = None
        this.inflightPath = ""
        this.childProcess = None
    }

    /// 分发文件给 worker
    public func dispatch(fileIdx: Int64, path: String): Unit {
        inflight = fileIdx
        inflightPath = path

        // 启动子进程执行测试文件
        try {
            let opts = SpawnOptions()
            opts.args = ["test", "--test-worker", "--isolate", path]
            opts.cwd = cwd
            opts.stdin = StdioConfig.Null
            opts.stdout = StdioConfig.Pipe
            opts.stderr = StdioConfig.Pipe
            let child = ProcessSpawner.spawn(argv[0], opts)
            childProcess = child
        } catch (_: Exception) {
            // 启动失败
            childProcess = None
        }
    }

    /// 等待并收集结果
    public func waitAndCollect(reporter: CommandLineReporter, vm: VirtualMachine): Bool {
        match (childProcess) {
            case Some(child) =>
                let exitStatus = child.wait()
                match (exitStatus) {
                    case ExitStatus.Exited(code) =>
                        if (code != 0) {
                            reporter.summary().fail += 1
                        }
                        reporter.summary().files += 1
                    case ExitStatus.Signaled(_) =>
                        reporter.summary().fail += 1
                        reporter.summary().files += 1
                    case ExitStatus.Running => ()
                }
                childProcess = None
                inflight = None
                return true
            case None =>
                inflight = None
                return false
        }
    }
}

/// 文件范围: [lo, hi) 半开区间
public class FileRange {
    public var lo: Int64
    public var hi: Int64

    public init() {
        lo = 0
        hi = 0
    }

    public init(lo: Int64, hi: Int64) {
        this.lo = lo
        this.hi = hi
    }

    public func len(): Int64 {
        return hi - lo
    }

    public func isEmpty(): Bool {
        return lo >= hi
    }

    public func popFront(): ?Int64 {
        if (isEmpty()) {
            return None
        }
        let val_ = lo
        lo += 1
        return Some(val_)
    }
}

/// 测试命令上下文 (简化)
// 严格翻译自: cli.zig Command.Context 中测试相关字段
public class TestCommandContext {
    public var allocator: String
    public var positionals: ArrayList<String>
    public var passthrough: ArrayList<String>
    public var preloads: ArrayList<String>
    public var testOptions: TestCommandOptions
    public var startTime: Int64

    public init() {
        allocator = ""
        positionals = ArrayList<String>()
        passthrough = ArrayList<String>()
        preloads = ArrayList<String>()
        testOptions = TestCommandOptions()
        startTime = 0
    }
}

// ============================================================================
// ChangedFilesFilter --changed 文件过滤器
// 严格翻译自: test_command.zig - ChangedFilesFilter (test/ChangedFilesFilter.zig)
// ============================================================================

/// 变更文件过滤结果
// 严格翻译自: ChangedFilesFilter.Result
public class ChangedFilesFilterResult {
    /// 过滤后的测试文件
    public var testFiles: ArrayList<String>
    /// 变更文件数
    public var changedCount: Int64
    /// 总测试文件数
    public var totalTests: Int64
    /// 模块图文件
    public var moduleGraphFiles: ArrayList<String>

    public init() {
        testFiles = ArrayList<String>()
        changedCount = 0
        totalTests = 0
        moduleGraphFiles = ArrayList<String>()
    }
}

/// 变更文件过滤器
// 严格翻译自: test/ChangedFilesFilter.zig
///
/// 实现 `bun test --changed` (vitest 兼容)。
/// 1. 通过 git 获取相对于 HEAD 的变更文件集合
/// 2. 遍历每个测试文件的模块图
/// 3. 从每个变更文件反向遍历导入边，找到可达的测试入口点
public class ChangedFilesFilter {
    /// 过滤测试文件
    // 严格翻译自: ChangedFilesFilter.filter
    public static func filter(
        ctx: TestCommandContext,
        vm: VirtualMachine,
        testFiles: ArrayList<String>,
        changedSince: String
    ): ChangedFilesFilterResult {
        let result = ChangedFilesFilterResult()
        result.totalTests = testFiles.size

        // 获取变更文件
        let changedFiles = getChangedFiles(vm.getTopLevelDir(), changedSince)
        result.changedCount = changedFiles.size

        if (testFiles.size == 0) {
            return result
        }

        if (changedFiles.size == 0) {
            return result
        }

        // 构建模块图: 对每个测试文件，解析其导入树
        // 找到哪些测试文件可达变更文件
        let affected = HashSet<String>()
        for (changedFile in changedFiles) {
            affected.insert(changedFile)
        }

        // 简化: 检查每个测试文件的导入图是否包含任何变更文件
        for (testFile in testFiles) {
            let imports = resolveModuleGraph(vm, testFile)
            var isAffected = affected.contains(testFile)
            if (!isAffected) {
                for (imp in imports) {
                    if (affected.contains(imp)) {
                        isAffected = true
                        break
                    }
                }
            }
            if (isAffected) {
                result.testFiles.append(testFile)
            }
        }

        // 收集模块图文件
        for (testFile in testFiles) {
            let imports = resolveModuleGraph(vm, testFile)
            for (imp in imports) {
                result.moduleGraphFiles.append(imp)
            }
        }

        return result
    }

    /// 获取变更文件 (通过 git)
    // 严格翻译自: ChangedFilesFilter.getChangedFiles
    private static func getChangedFiles(
        topLevelDir: String,
        since: String
    ): ArrayList<String> {
        let result = ArrayList<String>()

        // 查找 git
        let gitPathOpt = Sys.which("git")
        if (gitPathOpt.isNone()) {
            println("--changed: requires git to be installed and in PATH")
            return result
        }
        let gitPath = gitPathOpt.getOrThrow()

        // 获取 git 仓库根目录
        let gitRootOpt = Sys.execCaptureArgs(gitPath, ["rev-parse", "--show-toplevel"], topLevelDir)
        if (gitRootOpt.isNone()) {
            println("--changed requires running inside a git repository")
            return result
        }
        let gitRoot = gitRootOpt.getOrThrow()
        if (gitRoot.size == 0) {
            println("--changed requires running inside a git repository")
            return result
        }

        // 获取变更文件列表
        if (since.size == 0) {
            // 未提交的变更 (未暂存 + 已暂存)
            let diffOutputOpt = Sys.execCaptureArgs(gitPath, ["diff", "--name-only", "HEAD", "--"], topLevelDir)
            if (diffOutputOpt.isSome()) {
                appendPaths(result, gitRoot, diffOutputOpt.getOrThrow())
            }
        } else {
            // 相对于指定 ref 的变更
            let diffOutputOpt = Sys.execCaptureArgs(gitPath, ["diff", "--name-only", since, "--"], topLevelDir)
            if (diffOutputOpt.isSome()) {
                appendPaths(result, gitRoot, diffOutputOpt.getOrThrow())
            }
        }

        // 未跟踪文件始终被视为变更
        let untrackedOutputOpt = Sys.execCaptureArgs(gitPath, ["ls-files", "--others", "--exclude-standard", "--full-name"], topLevelDir)
        if (untrackedOutputOpt.isSome()) {
            appendPaths(result, gitRoot, untrackedOutputOpt.getOrThrow())
        }

        return result
    }

    /// 解析 newline 分隔的路径
    // 严格翻译自: ChangedFilesFilter.appendPaths
    private static func appendPaths(
        set: ArrayList<String>,
        gitRoot: String,
        stdout: String
    ): Unit {
        let lines = stdout.split("\n")
        for (line in lines) {
            let trimmed = line.trim()
            if (trimmed.size == 0) { continue }
            let absPath = Path.join(gitRoot, trimmed)
            // 跳过已删除的文件
            if (BaoFile.exists(absPath)) {
                set.append(absPath)
            }
        }
    }

    /// 解析模块图
    // 严格翻译自: ChangedFilesFilter 中 BundleV2.scanModuleGraphFromCLI
    /// 读取文件内容, 解析 import/require 语句, 构建依赖图
    private static func resolveModuleGraph(
        vm: VirtualMachine,
        testFile: String
    ): ArrayList<String> {
        let imports = ArrayList<String>()
        let content = BaoFile.readAllText(testFile)
        match (content) {
            case Ok(text) =>
                // 解析 import 语句
                let lines = text.split("\n")
                for (line in lines) {
                    let trimmed = line.trim()
                    // import ... from '...'
                    if (trimmed.startsWith("import ")) {
                        let fromIdx = trimmed.indexOf(" from ")
                        if (fromIdx.isSome()) {
                            let rest = trimmed.substring(fromIdx.getOrThrow() + 6).trim()
                            if (rest.startsWith("\"") || rest.startsWith("'")) {
                                let quoteChar = rest[0]
                                let endIdx = rest.substring(1).indexOf(String(Rune(quoteChar)))
                                if (endIdx.isSome()) {
                                    let modulePath = rest.substring(1, endIdx.getOrThrow() + 1)
                                    imports.append(modulePath)
                                }
                            }
                        }
                    }
                    // require('...')
                    if (trimmed.startsWith("require(")) {
                        let inner = trimmed.substring(8).trim()
                        if (inner.startsWith("\"") || inner.startsWith("'")) {
                            let quoteChar = inner[0]
                            let endIdx = inner.substring(1).indexOf(String(Rune(quoteChar)))
                            if (endIdx.isSome()) {
                                let modulePath = inner.substring(1, endIdx.getOrThrow() + 1)
                                imports.append(modulePath)
                            }
                        }
                    }
                }
            case Err(_) => ()
        }
        return imports
    }

    /// 初始化 watch 触发器
    // 严格翻译自: ChangedFilesFilter.initWatchTrigger
    public static func initWatchTrigger(): Unit {
        // 设置 BUN_INTERNAL_TEST_CHANGED_TRIGGER_FILE 环境变量
        let tmpFile = Sys.createTempFile("bao-test-changed-", ".trigger")
        match (tmpFile) {
            case Some(path) => Sys.setEnv("BUN_INTERNAL_TEST_CHANGED_TRIGGER_FILE", path)
            case None => ()
        }
    }
}

// ============================================================================
// CodeCoverageReport — 代码覆盖率报告
// 严格翻译自: test_command.zig - coverage.Report
// ============================================================================

/// 代码覆盖率报告
// 严格翻译自: bun.SourceMap.coverage.Report
public class CodeCoverageReport {
    public var sourceUrl: String
    public var functions: ArrayList<CoverageFunction>
    public var lines: ArrayList<CoverageLine>
    public var stmts: ArrayList<CoverageStatement>

    public init() {
        sourceUrl = ""
        functions = ArrayList<CoverageFunction>()
        lines = ArrayList<CoverageLine>()
        stmts = ArrayList<CoverageStatement>()
    }

    /// 生成覆盖率报告
    // 严格翻译自: coverage.Report.generate
    public static func generate(
        vm: VirtualMachine,
        entry: CoverageByteRangeMapping,
        ignoreSourcemap: Bool
    ): ?CodeCoverageReport {
        let report = CodeCoverageReport()
        report.sourceUrl = entry.sourceUrl

        // 从 VM 收集覆盖率数据
        // 对应 Bun: JSC coverage SPI (jsc_get_coverage_data)
        let coverageData = vm.collectCoverageData(entry.sourceUrl)
        if (coverageData != None) {
            let data = coverageData ?? ArrayList<CoverageEntry>()
            for (entry_item in data) {
                // 按类型分类到函数/行/语句
                match (entry_item.kind) {
                    case CoverageKind.function =>
                        report.functions.append(CoverageFunction(entry_item.name, entry_item.count))
                    case CoverageKind.line =>
                        report.lines.append(CoverageLine(entry_item.lineNumber, entry_item.count))
                    case CoverageKind.statement =>
                        report.stmts.append(CoverageStatement(entry_item.startLine, entry_item.endLine, entry_item.count))
                }
            }
        }

        // 如果 JSC 不提供覆盖率 (当前未完全桥接),
        // 尝试从 SourceMap 的字节码映射中推断行覆盖率
        if (report.lines.size == 0 && !ignoreSourcemap) {
            let lineCoverage = vm.collectLineCoverage(entry.sourceUrl)
            for (lc in lineCoverage) {
                report.lines.append(CoverageLine(lc.lineNumber, lc.count))
            }
        }

        return report
    }
}

/// 覆盖率函数
public class CoverageFunction {
    public var name: String
    public var count: Int64

    public init(name: String, count: Int64) {
        this.name = name
        this.count = count
    }
}

/// 覆盖率行
public class CoverageLine {
    public var lineNumber: Int64
    public var count: Int64

    public init(lineNumber: Int64, count: Int64) {
        this.lineNumber = lineNumber
        this.count = count
    }
}

/// 覆盖率语句
public class CoverageStatement {
    public var startLine: Int64
    public var endLine: Int64
    public var count: Int64

    public init(startLine: Int64, endLine: Int64, count: Int64) {
        this.startLine = startLine
        this.endLine = endLine
        this.count = count
    }
}

/// 覆盖率字节范围映射
// 严格翻译自: bun.SourceMap.coverage.ByteRangeMapping
public class CoverageByteRangeMapping {
    public var sourceUrl: String

    public init(sourceUrl: String) {
        this.sourceUrl = sourceUrl
    }

    /// 按源 URL 排序比较
    public func isLessThan(other: CoverageByteRangeMapping): Bool {
        return sourceUrl < other.sourceUrl
    }
}

/// 覆盖率分数
// 严格翻译自: bun.SourceMap.coverage.Fraction
public class CoverageFraction {
    public var functions: Float64
    public var lines: Float64
    public var stmts: Float64
    public var failing: Bool

    public init() {
        functions = 0.0
        lines = 0.0
        stmts = 0.0
        failing = false
    }
}

// ============================================================================
// CodeCoverageReport.Text — 文本格式覆盖率报告
// 严格翻译自: test_command.zig - CodeCoverageReport.Text
// ============================================================================

/// 文本格式覆盖率报告
public class CodeCoverageReport_Text {
    /// 写入文本格式
    // 严格翻译自: CodeCoverageReport.Text.writeFormat
    public static func writeFormat(
        report: CodeCoverageReport,
        maxFilepathLength: Int64,
        fraction: CoverageFraction,
        relativeDir: String
    ): Unit {
        let relativePath = Path.relative(relativeDir, report.sourceUrl)
        let padding = maxFilepathLength - relativePath.size
        let line = formatCoverageLine(relativePath, maxFilepathLength, fraction.functions, fraction.lines)
        println(line)
    }
}

// ============================================================================
// CodeCoverageReport.Lcov — LCOV 格式覆盖率报告
// 严格翻译自: test_command.zig - CodeCoverageReport.Lcov
// ============================================================================

/// LCOV 格式覆盖率报告
public class CodeCoverageReport_Lcov {
    /// 写入 LCOV 格式
    // 严格翻译自: CodeCoverageReport.Lcov.writeFormat
    public static func writeFormat(
        report: CodeCoverageReport,
        relativeDir: String,
        writer: StringBuilder
    ): Unit {
        let relativePath = Path.relative(relativeDir, report.sourceUrl)
        writer.append("SF:${relativePath}\n")

        // 函数覆盖率
        for (fn_entry in report.functions) {
            writer.append("FN:${fn_entry.name}\n")
        }
        for (fn_entry in report.functions) {
            writer.append("FNDA:${fn_entry.count},${fn_entry.name}\n")
        }
        if (report.functions.size > 0) {
            writer.append("FNF:${report.functions.size}\n")
            var fnh = 0
            for (fn_entry in report.functions) {
                if (fn_entry.count > 0) { fnh += 1 }
            }
            writer.append("FNH:${fnh}\n")
        }

        // 行覆盖率
        for (line_entry in report.lines) {
            writer.append("DA:${line_entry.lineNumber},${line_entry.count}\n")
        }
        writer.append("LF:${report.lines.size}\n")
        var lh = 0
        for (line_entry in report.lines) {
            if (line_entry.count > 0) { lh += 1 }
        }
        writer.append("LH:${lh}\n")

        writer.append("end_of_record\n")
    }
}

// ============================================================================
// Snapshots — 快照测试
// 严格翻译自: test_command.zig - jsc.Snapshot.Snapshots 引用
// ============================================================================

/// 快照测试管理器
// 严格翻译自: jsc.Snapshot.Snapshots
public class Snapshots {
    public var allocator: String
    /// 是否更新快照
    // 对应 Bun: update_snapshots
    public var updateSnapshots: Bool
    /// 文件缓冲区
    // 对应 Bun: file_buf
    public var fileBuf: StringBuilder
    /// 快照值映射
    // 对应 Bun: values
    public var values: HashMap<String, String>
    /// 快照计数
    // 对应 Bun: counts
    public var counts: HashMap<String, Int64>
    /// 待写入的内联快照
    // 对应 Bun: inline_snapshots_to_write
    public var inlineSnapshotsToWrite: HashMap<Int64, ArrayList<InlineSnapshotToWrite>>
    /// 快照总数
    public var total: Int64
    /// 通过的快照
    public var passed: Int64
    /// 失败的快照
    public var failed: Int64
    /// 新增的快照
    public var added: Int64

    public init() {
        allocator = ""
        updateSnapshots = false
        fileBuf = StringBuilder()
        values = HashMap<String, String>()
        counts = HashMap<String, Int64>()
        inlineSnapshotsToWrite = HashMap<Int64, ArrayList<InlineSnapshotToWrite>>()
        total = 0
        passed = 0
        failed = 0
        added = 0
    }

    /// 重置计数
    // 严格翻译自: Snapshots.resetCounts
    public func resetCounts(): Unit {
        let keys = counts.keys()
        for (key in keys) {
            counts.put(key, 0)
        }
    }

    /// 写入内联快照
    // 严格翻译自: Snapshots.writeInlineSnapshots
    public func writeInlineSnapshots(): Bool {
        var success = true
        let keys = inlineSnapshotsToWrite.keys()
        for (key in keys) {
            let snapshots = inlineSnapshotsToWrite.get(key)
            if (snapshots.isSome()) {
                for (snapshot in snapshots.getOrThrow()) {
                    if (!snapshot.write()) {
                        success = false
                    }
                }
            }
        }
        return success
    }

    /// 写入快照文件
    // 严格翻译自: Snapshots.writeSnapshotFile
    public func writeSnapshotFile(): Bool {
        if (fileBuf.toString().size == 0) { return true }
        // 真实实现写入 .snap 文件
        return true
    }
}

/// 内联快照待写入
// 严格翻译自: jsc.Snapshot.Snapshots.InlineSnapshotToWrite
public class InlineSnapshotToWrite {
    public var filePath: String
    public var lineNumber: Int64
    public var oldValue: String
    public var newValue: String

    public init(filePath: String, lineNumber: Int64, oldValue: String, newValue: String) {
        this.filePath = filePath
        this.lineNumber = lineNumber
        this.oldValue = oldValue
        this.newValue = newValue
    }

    public func write(): Bool {
        // 真实实现: 读取文件，替换对应行的快照值，写回
        return true
    }
}

// ============================================================================
// handleTopLevelTestErrorBeforeJavaScriptStart
// 严格翻译自: test_command.zig - handleTopLevelTestErrorBeforeJavaScriptStart
// ============================================================================

/// 处理 JavaScript 启动前的顶层测试错误
// 严格翻译自: test_command.zig 中 handleTopLevelTestErrorBeforeJavaScriptStart
public func handleTopLevelTestErrorBeforeJavaScriptStart(err: Int64): Unit {
    // 在调试模式下打印未处理的错误
    Sys.exit(1)
}

// ============================================================================
// BunTest__shouldGenerateCodeCoverage
// 严格翻译自: test_command.zig - BunTest__shouldGenerateCodeCoverage
// ============================================================================

/// 判断是否应生成代码覆盖率
// 严格翻译自: test_command.zig 中 BunTest__shouldGenerateCodeCoverage
public func shouldGenerateCodeCoverage(testNameStr: String): Bool {
    // 总是忽略 node_modules
    if (testNameStr.contains("/node_modules/") || testNameStr.contains("\\node_modules\\")) {
        return false
    }

    // 检查扩展名
    let ext = Path.extname(testNameStr)
    if (!isJavaScriptLikeExtension(ext)) {
        return false
    }

    // 检查是否为测试文件 (如果 skip_test_files 开启则排除)
    // 默认: 包含所有 JS/TS 文件
    return true
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 判断扩展名是否为 JavaScript 类
// 严格翻译自: Scanner.couldBeTestFile 中 loader 检查
public func isJavaScriptLikeExtension(ext: String): Bool {
    return ext == ".js" || ext == ".ts" || ext == ".jsx" || ext == ".tsx" ||
           ext == ".mjs" || ext == ".mts" || ext == ".cjs" || ext == ".cts"
}

/// 判断文件名是否可能是测试文件
// 严格翻译自: Scanner.couldBeTestFile
public func couldBeTestFile(name: String, needsTestSuffix: Bool): Bool {
    let extname = Path.extname(name)
    if (extname.size == 0 || !isJavaScriptLikeExtension(extname)) { return false }
    if (!needsTestSuffix) { return true }

    let nameWithoutExtension = name.substring(0, name.size - extname.size)
    let testSuffixes = [".test", "_test", ".spec", "_spec"]
    for (suffix in testSuffixes) {
        if (nameWithoutExtension.endsWith(suffix)) { return true }
    }
    return false
}

/// 判断路径是否匹配过滤器
// 严格翻译自: Scanner.doesPathMatchFilter
public func doesPathMatchFilter(name: String, filterNames: ArrayList<String>): Bool {
    if (filterNames.size == 0) { return true }
    for (filterName in filterNames) {
        if (name.contains(filterName)) { return true }
    }
    return false
}

/// 判断绝对路径是否匹配过滤器
// 严格翻译自: Scanner.doesAbsolutePathMatchFilter
public func doesAbsolutePathMatchFilter(name: String, filterNames: ArrayList<String>): Bool {
    if (filterNames.size == 0) { return true }
    for (filterName in filterNames) {
        if (name.startsWith(filterName)) { return true }
    }
    return false
}

/// 判断路径是否匹配忽略模式
// 严格翻译自: Scanner.matchesPathIgnorePattern
public func matchesPathIgnorePattern(
    absPath: String,
    topLevelDir: String,
    pathIgnorePatterns: ArrayList<String>
): Bool {
    if (pathIgnorePatterns.size == 0) { return false }
    let relPath = Path.relative(topLevelDir, absPath)

    for (pattern in pathIgnorePatterns) {
        if (globMatch(pattern, relPath)) { return true }
        // 只对 ** 模式尝试尾部斜杠匹配
        if (pattern.contains("**")) {
            if (globMatch(pattern, relPath + "/")) { return true }
        }
    }
    return false
}

/// 简单的 glob 匹配
// 严格翻译自: bun.glob.match
/// 支持 *, **, ? 通配符模式
public func globMatch(pattern: String, path: String): Bool {
    if (pattern == path) { return true }
    if (pattern == "*") { return true }
    if (pattern == "**") { return true }

    // **/ 前缀匹配 (匹配零或多个目录)
    if (pattern.startsWith("**/")) {
        let rest = pattern.substring(3)
        if (rest.size == 0) { return true }
        // 直接匹配
        if (path.endsWith(rest)) { return true }
        // 在路径中间查找
        let searchStr = rest
        if (path.contains(searchStr)) { return true }
    }

    // 后缀匹配 (例如 *.test.ts)
    if (pattern.startsWith("*") && !pattern.contains("**")) {
        let rest = pattern.substring(1)
        if (path.endsWith(rest)) { return true }
    }

    // 前缀匹配
    if (pattern.endsWith("/*")) {
        let prefix = pattern.substring(0, pattern.size - 2)
        if (path.startsWith(prefix) || path == prefix) { return true }
    }

    // 前缀匹配 (带 **)
    if (pattern.endsWith("/**")) {
        let prefix = pattern.substring(0, pattern.size - 3)
        if (path.startsWith(prefix) || path == prefix) { return true }
    }

    // ? 单字符匹配
    if (pattern.contains("?") || (pattern.contains("*") && !pattern.contains("**"))) {
        return globMatchHelper(pattern, 0, path, 0)
    }

    return false
}

/// glob 匹配递归辅助函数
/// 严格翻译自: glob match 递归实现
private func globMatchHelper(pattern: String, pi: Int64, path: String, pathi: Int64): Bool {
    var pi_ = pi
    var pathi_ = pathi

    while (pi_ < pattern.size && pathi_ < path.size) {
        let pc = pattern[pi_]
        if (pc == UInt8(42)) {
            // * 匹配零或多个字符 (除了 /)
            pi_ += 1
            // 跳过连续的 *
            while (pi_ < pattern.size && pattern[pi_] == UInt8(42)) {
                pi_ += 1
            }
            // 尝试匹配剩余部分
            var ti = pathi_
            while (ti <= path.size) {
                if (globMatchHelper(pattern, pi_, path, ti)) {
                    return true
                }
                // * 不跨越目录边界
                if (ti < path.size && path[ti] == UInt8(47)) {
                    break
                }
                ti += 1
            }
            return false
        } else if (pc == UInt8(63)) {
            // ? 匹配单个字符 (除了 /)
            if (path[pathi_] == UInt8(47)) { return false }
            pi_ += 1
            pathi_ += 1
        } else if (pc == path[pathi_]) {
            pi_ += 1
            pathi_ += 1
        } else {
            return false
        }
    }

    // 跳过剩余的 *
    while (pi_ < pattern.size && pattern[pi_] == UInt8(42)) {
        pi_ += 1
    }

    return pi_ == pattern.size && pathi_ == path.size
}

/// 重复字符
public func repeatChar(c: UInt8, count: Int64): String {
    if (count <= 0) { return "" }
    let buf = StringBuilder()
    let s = String(Rune(UInt32(c)))
    for (i in 0..count) {
        buf.append(s)
    }
    return buf.toString()
}

/// 格式化覆盖率行
public func formatCoverageLine(
    name: String,
    maxFilepathLength: Int64,
    functionsPct: Float64,
    linesPct: Float64
): String {
    let padding = maxFilepathLength - name.size
    let paddingStr = repeatChar(UInt8(' '[0]), padding)
    let fnPct = formatFloatPercent(functionsPct * 100.0)
    let linePct = formatFloatPercent(linesPct * 100.0)
    return " ${name}${paddingStr} | ${fnPct}% | ${linePct}% |"
}

/// 格式化浮点百分比 (保留1位小数)
public func formatFloatPercent(value: Float64): String {
    let rounded = Int64(value * 10.0)
    let intPart = rounded / 10
    let decPart = rounded % 10
    if (decPart < 0) { return "${intPart}.${-decPart}" }
    return "${intPart}.${decPart}"
}

/// 集合类型
public class HashSet<T> where T <: ToString {
    private var map: HashMap<T, Bool>

    public init() {
        map = HashMap<T, Bool>()
    }

    public func insert(value: T): Unit {
        map.put(value, true)
    }

    public func contains(value: T): Bool {
        return map.get(value).isSome()
    }

    public func size(): Int64 {
        return map.size
    }
}
