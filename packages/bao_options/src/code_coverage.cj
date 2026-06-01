// 严格翻译自: src/options_types/CodeCoverageOptions.zig
//   以及 src/options_types/code_coverage_options.rs
//   pub const CodeCoverageOptions = struct { ... };
//   pub const Reporter = enum { text, lcov };
//   pub const Reporters = struct { text: bool, lcov: bool };
//   pub struct Fraction { functions: f64, lines: f64, stmts: f64, failing: bool };
package bao_options

import bao_core.*
import bao_collections.*

// ============================================================================
// CoverageReporter - 覆盖率报告格式
// 严格翻译自: CodeCoverageOptions.zig - Reporter
//   pub const Reporter = enum { text, lcov };
// ============================================================================

/// 覆盖率报告格式 - 对应 Bun Reporter
public enum CoverageReporter {
    | Text
    | Lcov
}

// ============================================================================
// CoverageReporters - 覆盖率报告格式集合
// 严格翻译自: CodeCoverageOptions.zig - Reporters
//   pub const Reporters = struct { text: bool, lcov: bool };
// ============================================================================

/// 覆盖率报告格式集合 - 对应 Bun Reporters
public class CoverageReporters {
    public var text: Bool
    public var lcov: Bool

    public init() {
        text = true
        lcov = false
    }

    public init(text: Bool, lcov: Bool) {
        this.text = text
        this.lcov = lcov
    }
}

// ============================================================================
// CoverageFraction - 覆盖率阈值
// 严格翻译自: code_coverage_options.rs - Fraction
//   #[derive(Copy, Clone, Debug, PartialEq)]
//   pub struct Fraction {
//       pub functions: f64,   // 默认 0.9
//       pub lines: f64,       // 默认 0.9
//       pub stmts: f64,       // 默认 0.75
//       pub failing: bool,    // 默认 false
//   }
//
// Zig 源: fractions: bun.SourceMap.coverage.Fraction = .{}
//   (move-in from sourcemap_jsc/CodeCoverage.zig Fraction)
// ============================================================================

/// 覆盖率阈值 - 对应 Bun Fraction
/// 控制各维度的最低覆盖率要求，低于阈值时根据 failOnLowCoverage 决定是否失败
public class CoverageFraction {
    /// 函数覆盖率阈值 (默认 0.9 = 90%)
    public var functions: Float64
    /// 行覆盖率阈值 (默认 0.9 = 90%)
    public var lines: Float64
    /// 语句覆盖率阈值 (默认 0.75 = 75%)
    public var stmts: Float64
    /// 是否正在失败状态
    public var failing: Bool

    public init() {
        functions = 0.9
        lines = 0.9
        stmts = 0.75
        failing = false
    }

    public init(functions: Float64, lines: Float64, stmts: Float64, failing: Bool) {
        this.functions = functions
        this.lines = lines
        this.stmts = stmts
        this.failing = failing
    }

    /// 检查给定的覆盖率是否满足所有阈值要求
    public func isSatisfied(funcCov: Float64, lineCov: Float64, stmtCov: Float64): Bool {
        return funcCov >= functions && lineCov >= lines && stmtCov >= stmts
    }
}

// ============================================================================
// CodeCoverageOptions - 代码覆盖率选项
// 严格翻译自: CodeCoverageOptions.zig - CodeCoverageOptions
//   pub const CodeCoverageOptions = struct {
//       skip_test_files: bool = !bun.Environment.allow_assert,
//       reporters: Reporters = .{ .text = true, .lcov = false },
//       reports_directory: []const u8 = "coverage",
//       fractions: bun.SourceMap.coverage.Fraction = .{},
//       ignore_sourcemap: bool = false,
//       enabled: bool = false,
//       fail_on_low_coverage: bool = false,
//       ignore_patterns: []const []const u8 = &.{},
//   };
// ============================================================================

/// 代码覆盖率选项 - 对应 Bun CodeCoverageOptions
public class CodeCoverageOptions {
    /// 是否跳过测试文件的覆盖率收集
    /// Zig 默认: !bun.Environment.allow_assert (release 模式跳过)
    public var skipTestFiles: Bool
    /// 报告格式
    public var reporters: CoverageReporters
    /// 报告输出目录 (Zig: "coverage")
    public var reportsDirectory: String
    /// 覆盖率阈值 (Zig: bun.SourceMap.coverage.Fraction = .{})
    public var fractions: CoverageFraction
    /// 是否忽略 source map
    public var ignoreSourcemap: Bool
    /// 是否启用覆盖率
    public var enabled: Bool
    /// 低覆盖率是否失败
    public var failOnLowCoverage: Bool
    /// 忽略模式 (Zig: []const []const u8 = &.{})
    public var ignorePatterns: ArrayList<String>

    public init() {
        skipTestFiles = true
        reporters = CoverageReporters()
        reportsDirectory = "coverage"
        fractions = CoverageFraction()
        ignoreSourcemap = false
        enabled = false
        failOnLowCoverage = false
        ignorePatterns = ArrayList<String>()
    }
}
