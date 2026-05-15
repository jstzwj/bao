// CodeCoverageOptions - 代码覆盖率选项
// 严格翻译自: bun/src/options_types/CodeCoverageOptions.zig
//   pub const CodeCoverageOptions = struct { ... };
package bao_options

import bao_core.*

// ============================================================================
// CoverageReporter - 覆盖率报告格式
// 严格翻译自: CodeCoverageOptions.zig - Reporter
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
// CodeCoverageOptions - 代码覆盖率选项
// 严格翻译自: CodeCoverageOptions.zig - CodeCoverageOptions
//   pub const CodeCoverageOptions = struct {
//       skip_test_files: bool = !bun.Environment.allow_assert,
//       reporters: Reporters = .{ .text = true, .lcov = false },
//       reports_directory: []const u8 = "coverage",
//       ...
//   };
// ============================================================================

/// 代码覆盖率选项 - 对应 Bun CodeCoverageOptions
public class CodeCoverageOptions {
    /// 是否跳过测试文件的覆盖率收集
    public var skipTestFiles: Bool
    /// 报告格式
    public var reporters: CoverageReporters
    /// 报告输出目录
    public var reportsDirectory: String
    /// 是否忽略 source map
    public var ignoreSourcemap: Bool
    /// 是否启用覆盖率
    public var enabled: Bool
    /// 低覆盖率是否失败
    public var failOnLowCoverage: Bool
    /// 忽略模式
    public var ignorePatterns: ArrayList<String>

    public init() {
        skipTestFiles = true
        reporters = CoverageReporters()
        reportsDirectory = "coverage"
        ignoreSourcemap = false
        enabled = false
        failOnLowCoverage = false
        ignorePatterns = ArrayList<String>()
    }
}
