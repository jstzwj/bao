package bao_cli.test


import bao_core.*
import bao_collections.*
import bao_options.*
import bao_runtime.*

public enum HotReloadKind {
    | none
    | watch
}

public type PathString = String

/// 代码覆盖率选项
/// 对应 Bun: TestCommand.CodeCoverageOptions
public class CodeCoverageOptions {
    public var enabled: Bool = false
    public var lcovReporter: Bool = false
    public var textReporter: Bool = true
    public var reportsDirectory: String = "coverage"
    public var fractions: CoverageFraction = CoverageFraction()

    public init() {}
}

/// 覆盖率分数阈值
public class CoverageFraction {
    public var functions: Float64 = 0.0
    public var lines: Float64 = 0.0
    public var stmts: Float64 = 0.0
    public var failing: Bool = false

    public init() {}
}

public class TestRunnerSummary {
    public var pass: UInt32 = 0
    public var fail: UInt32 = 0
    public var skip: UInt32 = 0
    public var todo: UInt32 = 0
    public var expectations: UInt32 = 0
    public var skippedBecauseLabel: UInt32 = 0
    public var files: UInt32 = 0

    public init() {}

    /// 创建副本用于 worker 前后差异计算
    public func copy(): TestRunnerSummary {
        let c = TestRunnerSummary()
        c.pass = pass
        c.fail = fail
        c.skip = skip
        c.todo = todo
        c.expectations = expectations
        c.skippedBecauseLabel = skippedBecauseLabel
        c.files = files
        return c
    }
}

public class JestReporterState {
    public var unhandledErrorsBetweenTests: UInt32 = 0

    public init() {}
}

public class CommandLineReporter {
    public var jest: JestReporterState = JestReporterState()
    private var summaryValue: TestRunnerSummary = TestRunnerSummary()
    public init() {}
    public func summary(): TestRunnerSummary { return summaryValue }
}

public class TestOptions {
    public var parallel: Int64 = 1
    public var reporters: ReportersOptions = ReportersOptions()
    public var coverage: CodeCoverageOptions = CodeCoverageOptions()
    public var junit: Bool = false
    public var reporterOutfile: ?String = None

    public init() {}
}

public class ReportersOptions {
    public var junit: Bool = false

    public init() {}
}

public class DebugOptions {
    public var hotReload: HotReloadKind = HotReloadKind.none
}

public class CommandContext {
    public var testOptions: TestOptions = TestOptions()
    public var allocator: Allocator = CAllocator()
    public var log: Log = Log()
    public var args: ArrayList<String> = ArrayList<String>()
    public var debug: DebugOptions = DebugOptions()
    public var preloads: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class TestCommand {
    public static func runAllTests(reporter: CommandLineReporter, vm: VirtualMachine, files: Array<PathString>, allocator: Allocator): Unit {}
}

/// 日志 (桩)
public class Log {
    public init() {}
}
