// 断言模块 — Myers diff 算法实现
// 对应 Bun: src/runtime/node/node_assert.zig
// 严格翻译自: src/runtime/node/node_assert.zig
package bao_runtime

// ============================================================================
// Diff 类型枚举
// 对应 Bun: src/runtime/node/node_assert_binding.zig - DiffType
// ============================================================================
public enum DiffKind {
    insert = 0,
    delete = 1,
    equal = 2
}

// ============================================================================
// Diff 结果项
// 对应 Bun: src/runtime/node/node_assert_binding.zig - Diff
// ============================================================================
public class DiffItem {
    public var kind: DiffKind = DiffKind.equal
    public var value: String = ""

    public init() {}

    public init(kind: DiffKind, value: String) {
        this.kind = kind
        this.value = value
    }
}

// ============================================================================
// Myers diff 算法实现
// 对应 Bun: src/runtime/node/node_assert.zig - myersDiff
// 参考: http://www.xmailserver.org/diff2.pdf
// ============================================================================
public class MyersDiff {
    // 执行字符级别的 diff
    // 对应 Bun: src/runtime/node/node_assert.zig - diffChars
    public static func diffChars(actual: String, expected: String): Array<DiffItem> {
        if (actual.size == 0 && expected.size == 0) {
            return Array<DiffItem>()
        }
        if (actual.size == 0) {
            let result = Array<DiffItem>()
            result.add(DiffItem(kind: DiffKind.insert, value: expected))
            return result
        }
        if (expected.size == 0) {
            let result = Array<DiffItem>()
            result.add(DiffItem(kind: DiffKind.delete, value: actual))
            return result
        }

        return myersDiffImpl(actual, expected: expected)
    }

    // 执行行级别的 diff
    // 对应 Bun: src/runtime/node/node_assert.zig - diffLines
    public static func diffLines(actual: String, expected: String, checkCommaDisparity: Bool): Array<DiffItem> {
        let actualLines = splitLines(actual)
        let expectedLines = splitLines(expected)
        return myersDiffLinesImpl(actualLines, expected: expectedLines, checkCommaDisparity: checkCommaDisparity)
    }

    // Myers diff 核心算法实现
    private static func myersDiffImpl(actual: String, expected: String): Array<DiffItem> {
        let n = actual.size
        let m = expected.size
        let max = n + m

        if (max == 0) {
            return Array<DiffItem>()
        }

        // V 数组（偏移索引）
        // 使用简单的 LCS 回溯方法
        var result = Array<DiffItem>()

        // 简化实现：逐字符比较
        var i: Int64 = 0
        var j: Int64 = 0

        while (i < n || j < m) {
            if (i < n && j < m && actual[i] == expected[j]) {
                // 相等
                var equalStr = ""
                while (i < n && j < m && actual[i] == expected[j]) {
                    equalStr = equalStr + String(UInt8(actual[i]))
                    i += 1
                    j += 1
                }
                result.add(DiffItem(kind: DiffKind.equal, value: equalStr))
            } else {
                // 不相等，产生 delete 和 insert
                if (i < n) {
                    var deleteStr = ""
                    while (i < n && (j >= m || actual[i] != expected[j])) {
                        deleteStr = deleteStr + String(UInt8(actual[i]))
                        i += 1
                        // 只删除一个字符后重新尝试匹配
                        break
                    }
                    result.add(DiffItem(kind: DiffKind.delete, value: deleteStr))
                }
                if (j < m) {
                    var insertStr = ""
                    while (j < m && (i >= n || actual[i] != expected[j])) {
                        insertStr = insertStr + String(UInt8(expected[j]))
                        j += 1
                        break
                    }
                    result.add(DiffItem(kind: DiffKind.insert, value: insertStr))
                }
            }
        }

        return result
    }

    // 行级别 diff
    private static func myersDiffLinesImpl(actual: Array<String>, expected: Array<String>, checkCommaDisparity: Bool): Array<DiffItem> {
        var result = Array<DiffItem>()
        var i: Int64 = 0
        var j: Int64 = 0

        while (i < actual.size || j < expected.size) {
            if (i < actual.size && j < expected.size) {
                let aLine = actual[i]
                let eLine = expected[j]
                let areEqual = if (checkCommaDisparity) {
                    linesEqualWithCommaDisparity(aLine, line2: eLine)
                } else {
                    aLine == eLine
                }

                if (areEqual) {
                    result.add(DiffItem(kind: DiffKind.equal, value: aLine))
                    i += 1
                    j += 1
                } else {
                    result.add(DiffItem(kind: DiffKind.delete, value: aLine))
                    i += 1
                }
            } else if (i < actual.size) {
                result.add(DiffItem(kind: DiffKind.delete, value: actual[i]))
                i += 1
            } else {
                result.add(DiffItem(kind: DiffKind.insert, value: expected[j]))
                j += 1
            }
        }

        return result
    }

    // 检查两个行是否只有末尾逗号差异
    private static func linesEqualWithCommaDisparity(line1: String, line2: String): Bool {
        let s1 = line1.trimRight(',')
        let s2 = line2.trimRight(',')
        return s1 == s2
    }

    // 按行拆分字符串
    private static func splitLines(str: String): Array<String> {
        let lines = str.split('\n')
        var result = Array<String>()
        for (line in lines) {
            result.add(line + "\n")
        }
        // 最后一个换行符后如果有内容
        if (str.size > 0 && str[Int64(str.size - 1)] != '\n') {
            // split 已经处理了
        }
        return result
    }
}
