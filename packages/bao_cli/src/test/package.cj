package bao_cli.test


import std.collection.*
import bao_core.*
import bao_options.*
import bao_runtime.*

public class TestRunnerSummary {
    public var pass: UInt32 = 0
    public var fail: UInt32 = 0
    public var skip: UInt32 = 0
    public var todo: UInt32 = 0
    public var expectations: UInt32 = 0
    public var skippedBecauseLabel: UInt32 = 0
    public var files: UInt32 = 0
}

public class JestReporterState {
    public var unhandledErrorsBetweenTests: UInt32 = 0
}

public class CommandLineReporter {
    public var jest: JestReporterState = JestReporterState()
    private var summaryValue: TestRunnerSummary = TestRunnerSummary()
    public init() {}
    public func summary(): TestRunnerSummary { return summaryValue }
}

public class TestCommand {
    public type CodeCoverageOptions = bao_options.CodeCoverageOptions
}
