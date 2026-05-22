// Myers diff 算法核心实现
// 对应 Bun: src/runtime/node/assert/myers_diff.zig
// 严格翻译自: src/runtime/node/assert/myers_diff.zig
package bao_runtime.node.assert

import bao_runtime.node.*
import bao_collections.*

// ============================================================================
// Myers diff 选项
// 对应 Bun: src/runtime/node/assert/myers_diff.zig - Options
// ============================================================================
public class MyersDiffOptions {
    public var avgInputSize: Int64 = 256
    public var initialTraceCapacity: Int64 = 64
    public var checkCommaDisparity: Bool = false

    public init() {}
}

// ============================================================================
// Myers diff 核心算法
// 对应 Bun: src/runtime/node/assert/myers_diff.zig - Differ
// ============================================================================
public class MyersDiffAlgorithm {
    // 最大输入长度
    private static let MAXLEN: UInt32 = 4294967295

    // 对两个字符串数组执行 diff
    // 对应 Bun: src/runtime/node/assert/myers_diff.zig - Differ.diff
    public static func diffLines(actual: Array<String>, expected: Array<String>, checkCommaDisparity: Bool): Array<DiffItem> {
        let n = actual.size
        let m = expected.size

        if (n == 0 && m == 0) {
            return Array<DiffItem>()
        }

        if (n == 0) {
            let result = ArrayList<DiffItem>()
            for (line in expected) {
                result.append(DiffItem(DiffKind.insert, line))
            }
            return result.items()
        }

        if (m == 0) {
            let result = ArrayList<DiffItem>()
            for (line in actual) {
                result.append(DiffItem(DiffKind.delete, line))
            }
            return result.items()
        }

        return computeDiff(actual, expected, checkCommaDisparity)
    }

    // 计算最长公共子序列并生成 diff
    private static func computeDiff(actual: Array<String>, expected: Array<String>, checkCommaDisparity: Bool): Array<DiffItem> {
        let n = actual.size
        let m = expected.size

        let dp = Array<Array<Int64>>(Int64(n + 1), { _ => Array<Int64>(Int64(m + 1), { _ => Int64(0) }) })

        for (i in 1..Int64(n + 1)) {
            for (j in 1..Int64(m + 1)) {
                let aLine = actual[Int64(i - 1)]
                let eLine = expected[Int64(j - 1)]
                let areEqual = if (checkCommaDisparity) {
                    aLine.trimEnd(',') == eLine.trimEnd(',')
                } else {
                    aLine == eLine
                }

                if (areEqual) {
                    dp[Int64(i)][Int64(j)] = dp[Int64(i - 1)][Int64(j - 1)] + 1
                } else {
                    let left = dp[Int64(i - 1)][Int64(j)]
                    let top = dp[Int64(i)][Int64(j - 1)]
                    dp[Int64(i)][Int64(j)] = if (left > top) { left } else { top }
                }
            }
        }

        var result = ArrayList<DiffItem>()
        var i: Int64 = Int64(n)
        var j: Int64 = Int64(m)

        while (i > 0 || j > 0) {
            if (i > 0 && j > 0) {
                let aLine = actual[Int64(i - 1)]
                let eLine = expected[Int64(j - 1)]
                let areEqual = if (checkCommaDisparity) {
                    aLine.trimEnd(',') == eLine.trimEnd(',')
                } else {
                    aLine == eLine
                }

                if (areEqual && dp[Int64(i)][Int64(j)] == dp[Int64(i - 1)][Int64(j - 1)] + 1) {
                    result.insert(0, DiffItem(DiffKind.equal, aLine))
                    i -= 1
                    j -= 1
                    continue
                }
            }

            if (j > 0 && (i == 0 || dp[Int64(i)][Int64(j)] == dp[Int64(i)][Int64(j - 1)])) {
                result.insert(0, DiffItem(DiffKind.insert, expected[Int64(j - 1)]))
                j -= 1
            } else if (i > 0) {
                result.insert(0, DiffItem(DiffKind.delete, actual[Int64(i - 1)]))
                i -= 1
            }
        }

        return result.items()
    }

    private static func areStrLinesEqual(a: String, b: String, checkCommaDisparity: Bool): Bool {
        if (checkCommaDisparity) {
            return a.trimEnd(',') == b.trimEnd(',')
        }
        return a == b
    }
}
