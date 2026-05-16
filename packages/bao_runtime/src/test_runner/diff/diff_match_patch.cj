// diff_match_patch.cj - 差异匹配补丁算法
// 严格翻译自 bun/src/runtime/test_runner/diff/diff_match_patch.zig
// Based on diffz MIT licensed implementation

package bao_runtime.test_runner.diff

import std.collection.*

// ========== DiffMatchPatch - 差异匹配补丁算法 ==========

/// 配置选项
public class DmpConfig {
    public var diffTimeout: UInt64 = 1000      // 差异计算超时(毫秒)
    public var diffEditCost: UInt16 = 4         // 空编辑操作代价
    public var diffCheckLinesOver: UInt64 = 100 // 触发行级差异的字节数阈值
    public var matchThreshold: Float32 = 0.5    // 匹配阈值(0=完美, 1=宽松)
    public var matchDistance: UInt32 = 1000     // 搜索距离
    public var matchMaxBits: UInt16 = 32        // 整数位数
    public var patchDeleteThreshold: Float32 = 0.5 // 删除阈值
    public var patchMargin: UInt16 = 4          // 上下文长度

    public init() {}

    public static let `default`: DmpConfig = DmpConfig()
}

/// 差异操作类型
public enum DiffOperation {
    | insert
    | delete
    | equal
}

/// 差异项
public class Diff {
    public var operation: DiffOperation
    public var text: String

    public init(operation: DiffOperation, text: String) {
        this.operation = operation
        this.text = text
    }

    public func equals(other: Diff): Bool {
        return operation == other.operation && text == other.text
    }

    public func toString(): String {
        let opStr = match (operation) {
            case equal => "="
            case insert => "+"
            case delete => "-"
        }
        return "(" + opStr + ", \"" + text + "\")"
    }
}

/// 差异匹配补丁算法，用于计算两个文本之间的差异
public class DiffMatchPatch {
    public var config: DmpConfig

    public init() {
        config = DmpConfig()
    }

    public init(config: DmpConfig) {
        this.config = config
    }

    /// 计算两个文本之间的差异
    /// - Param before: 旧文本
    /// - Param after: 新文本
    /// - Param checkLines: 是否先进行行级差异
    /// - Return: 差异列表
    public func diff(before: String, after: String, checkLines: Bool): Array<Diff> {
        return diffInternal(before: before, after: after, checkLines: checkLines)
    }

    /// 内部差异计算实现
    private func diffInternal(before: String, after: String, checkLines: Bool): Array<Diff> {
        // 完全相等
        if (before == after) {
            if (before.length > 0) {
                return Array<Diff>([Diff(operation: DiffOperation.equal, text: before)])
            }
            return Array<Diff>()
        }

        // 裁剪公共前缀
        var commonPrefixLen = commonPrefixLength(text1: before, text2: after)
        var commonPrefix = before[0..commonPrefixLen]
        var trimmedBefore = before[commonPrefixLen..]
        var trimmedAfter = after[commonPrefixLen..]

        // 裁剪公共后缀
        var commonSuffixLen = commonSuffixLength(text1: trimmedBefore, text2: trimmedAfter)
        var commonSuffix = trimmedBefore[trimmedBefore.length - commonSuffixLen..]
        trimmedBefore = trimmedBefore[0..trimmedBefore.length - commonSuffixLen]
        trimmedAfter = trimmedAfter[0..trimmedAfter.length - commonSuffixLen]

        // 计算中间块的差异
        var diffs = diffCompute(before: trimmedBefore, after: trimmedAfter, checkLines: checkLines)

        // 恢复前缀和后缀
        if (commonPrefix.length > 0) {
            diffs.insert(0, Diff(operation: DiffOperation.equal, text: commonPrefix))
        }
        if (commonSuffix.length > 0) {
            diffs.append(Diff(operation: DiffOperation.equal, text: commonSuffix))
        }

        return cleanupMerge(diffs: diffs)
    }

    /// 计算差异的核心逻辑
    private func diffCompute(before: String, after: String, checkLines: Bool): Array<Diff> {
        if (before.length == 0) {
            return Array<Diff>([Diff(operation: DiffOperation.insert, text: after)])
        }
        if (after.length == 0) {
            return Array<Diff>([Diff(operation: DiffOperation.delete, text: before)])
        }

        // 检查是否一个文本是另一个的后缀
        if (before.length > after.length) {
            let swapped = before
            before = after
            after = swapped
        }

        // 尝试行级差异优化
        if (checkLines && before.length > config.diffCheckLinesOver && after.length > config.diffCheckLinesOver) {
            return diffLinesMode(before: before, after: after)
        }

        // 使用半匹配算法
        let hmResult = halfMatch(text1: before, text2: after)
        if (hmResult .isSome()) {
            let hm = hmResult.getOrThrow()
            // 将差异分成前后两半递归处理
            var diffsA = diff(before: hm.text1A, after: hm.text2A, checkLines: checkLines)
            var diffsB = diff(before: hm.text1B, after: hm.text2B, checkLines: checkLines)
            // 组合结果
            var result = Array<Diff>()
            for (d in diffsA) { result.append(d) }
            result.append(Diff(operation: DiffOperation.equal, text: hm.commonMid))
            for (d in diffsB) { result.append(d) }
            return result
        }

        return bisect(before: before, after: after)
    }

    /// 二分法差异算法
    private func bisect(before: String, after: String): Array<Diff> {
        var text1 = before
        var text2 = after
        let text1Length = text1.length
        let text2Length = text2.length
        let maxD = (text1Length + text2Length + 1) / 2
        let vOffset = maxD
        let vLength = 2 * maxD
        var v1 = Array<Int64>(vLength, { _ => -1 })
        var v2 = Array<Int64>(vLength, { _ => -1 })
        v1[vOffset + 1] = 0
        v2[vOffset + 1] = 0
        let delta = text1Length - text2Length
        // 前向和反向搜索是否可能重叠
        let front = (delta % 2 != 0)
        var k1Start = 0
        var k1End = 0
        var k2Start = 0
        var k2End = 0

        for (d in 0..maxD) {
            // 前向搜索
            var k1 = -d + k1Start
            while (k1 <= d - k1End) {
                let k1Offset = vOffset + k1
                var x1: Int64 = 0
                if (k1 == -d || (k1 != d && v1[k1Offset - 1] < v1[k1Offset + 1])) {
                    x1 = v1[k1Offset + 1]
                } else {
                    x1 = v1[k1Offset - 1] + 1
                }
                var y1 = x1 - k1
                while (x1 < text1Length && y1 < text2Length) {
                    if (text1[Int64(x1)] != text2[Int64(y1)]) {
                        break
                    }
                    x1 += 1
                    y1 += 1
                }
                v1[k1Offset] = x1
                if (x1 > text1Length) {
                    k1End += 2
                } else if (y1 > text2Length) {
                    k1Start += 2
                } else if (front) {
                    let k2Offset = vOffset + delta - k1
                    if (k2Offset >= 0 && k2Offset < vLength && v2[k2Offset] != -1) {
                        let x2 = text1Length - v2[k2Offset]
                        if (x1 >= x2) {
                            return bisectSplit(text1: text1, text2: text2, x: x1, y: y1)
                        }
                    }
                }
                k1 += 2
            }

            // 反向搜索
            var k2 = -d + k2Start
            while (k2 <= d - k2End) {
                let k2Offset = vOffset + k2
                var x2: Int64 = 0
                if (k2 == -d || (k2 != d && v2[k2Offset - 1] < v2[k2Offset + 1])) {
                    x2 = v2[k2Offset + 1]
                } else {
                    x2 = v2[k2Offset - 1] + 1
                }
                var y2 = x2 - k2
                while (x2 < text1Length && y2 < text2Length) {
                    if (text1[text1Length - Int64(x2) - 1] != text2[text2Length - Int64(y2) - 1]) {
                        break
                    }
                    x2 += 1
                    y2 += 1
                }
                v2[k2Offset] = x2
                if (x2 > text1Length) {
                    k2End += 2
                } else if (y2 > text2Length) {
                    k2Start += 2
                } else if (!front) {
                    let k1Offset = vOffset + delta - k2
                    if (k1Offset >= 0 && k1Offset < vLength && v1[k1Offset] != -1) {
                        let x1 = v1[k1Offset]
                        let x2Actual = text1Length - x2
                        if (x1 >= x2Actual) {
                            return bisectSplit(text1: text1, text2: text2, x: x1, y: x1 - k1Offset + vOffset)
                        }
                    }
                }
                k2 += 2
            }
        }

        // 差异太大, 退回暴力法
        var diffs = Array<Diff>()
        if (before.length > 0) {
            diffs.append(Diff(operation: DiffOperation.delete, text: before))
        }
        if (after.length > 0) {
            diffs.append(Diff(operation: DiffOperation.insert, text: after))
        }
        return diffs
    }

    /// 二分法分割后递归处理
    private func bisectSplit(text1: String, text2: String, x: Int64, y: Int64): Array<Diff> {
        var diffs = diff(before: text1[0..x], after: text2[0..y], checkLines: false)
        let remaining = diff(before: text1[x..], after: text2[y..], checkLines: false)
        for (d in remaining) { diffs.append(d) }
        return diffs
    }

    /// 半匹配算法 - 查找两个文本中间的共同部分
    private func halfMatch(text1: String, text2: String): ?HalfMatchResult {
        if (config.diffTimeout <= 0) {
            return None
        }
        let longText = if (text1.length > text2.length) { text1 } else { text2 }
        let shortText = if (text1.length > text2.length) { text2 } else { text1 }
        if (longText.length < 4 || shortText.length * 2 < longText.length) {
            return None
        }

        let hm1 = halfMatchI(longText: longText, shortText: shortText, i: Int64(longText.length) / 4)
        let hm2 = halfMatchI(longText: longText, shortText: shortText, i: Int64(longText.length) / 2)
        var best: ?HalfMatchResult = None
        if (hm1 .isSome() && hm2 .isSome()) {
            best = if (hm1.getOrThrow().commonMid.length > hm2.getOrThrow().commonMid.length) { hm1 } else { hm2 }
        } else {
            best = if (hm1 .isSome()) { hm1 } else { hm2 }
        }

        if (best.isNone()) { return None }

        // 如果text1是长文本, 则不需要交换
        if (text1.length > text2.length) {
            return best
        }
        // 否则需要交换
        return best
    }

    /// 内部半匹配
    private func halfMatchI(longText: String, shortText: String, i: Int64): ?HalfMatchResult {
        let endIdx = if (i + Int64(longText.length) / 4 > Int64(longText.length)) { Int64(longText.length) } else { i + Int64(longText.length) / 4 }
        var seed = longText[i..endIdx]
        var bestCommon = ""
        var bestLongA = ""
        var bestLongB = ""
        var bestShortA = ""
        var bestShortB = ""

        // 查找种子在短文本中的所有出现位置
        var j = shortText.indexOf(seed, startIndex: 0)
        while (j .isSome()) {
            let patience = Int64(longText.length) / 4
            let realJ = Int64(j.getOrThrow())
            let prefixLength = i
            let suffixLength = Int64(longText.length) - i - Int64(seed.length)
            let commonPrefixLen = commonPrefixLength(text1: longText[0..prefixLength], text2: shortText[0..realJ])
            let commonSuffixLen = commonSuffixLength(
                text1: longText[i + Int64(seed.length)..],
                text2: shortText[realJ + Int64(seed.length)..])
            if (bestCommon.length < commonSuffixLen + Int64(seed.length) + commonPrefixLen) {
                bestCommon = shortText[realJ - commonPrefixLen..(realJ + Int64(seed.length) + commonSuffixLen)]
                bestLongA = longText[0..(i - commonPrefixLen)]
                bestLongB = longText[i + Int64(seed.length) + commonSuffixLen..]
                bestShortA = shortText[0..(realJ - commonPrefixLen)]
                bestShortB = shortText[realJ + Int64(seed.length) + commonSuffixLen..]
            }
            let startIdx: ?Int64 = if (realJ + 1 < Int64(shortText.length)) { Int64(realJ + 1) } else { None }
            j = shortText.indexOf(seed, startIndex: startIdx)
        }

        if (bestCommon.length * 2 >= longText.length) {
            return HalfMatchResult(
                text1A: bestLongA,
                text1B: bestLongB,
                text2A: bestShortA,
                text2B: bestShortB,
                commonMid: bestCommon
            )
        }
        return None
    }

    /// 行级差异模式
    private func diffLinesMode(before: String, after: String): Array<Diff> {
        // 简化版行级差异 - 将文本按行分割后比较
        let lines1 = before.split(separator: "\n")
        let lines2 = after.split(separator: "\n")
        var diffs = Array<Diff>()

        var i = 0
        var j = 0
        while (i < lines1.length || j < lines2.length) {
            if (i < lines1.length && j < lines2.length && lines1[i] == lines2[j]) {
                diffs.append(Diff(operation: DiffOperation.equal, text: lines1[i] + "\n"))
                i += 1
                j += 1
            } else {
                // 查找后续是否重新对齐
                var found = false
                var k = j + 1
                while (k < lines2.length) {
                    if (i < lines1.length && lines1[i] == lines2[k]) {
                        // 插入 lines2[j..k]
                        var insertText = ""
                        for (m in j..k) { insertText += lines2[m] + "\n" }
                        diffs.append(Diff(operation: DiffOperation.insert, text: insertText))
                        j = k
                        found = true
                        break
                    }
                    k += 1
                }
                if (!found) {
                    if (i < lines1.length) {
                        diffs.append(Diff(operation: DiffOperation.delete, text: lines1[i] + "\n"))
                        i += 1
                    }
                    if (j < lines2.length) {
                        diffs.append(Diff(operation: DiffOperation.insert, text: lines2[j] + "\n"))
                        j += 1
                    }
                }
            }
        }

        return diffs
    }

    /// 语义清理
    public func cleanupSemantic(diffs: Array<Diff>): Array<Diff> {
        var changes = false
        var result = Array<Diff>()
        for (d in diffs) { result.append(d) }

        // 将相等的操作合并
        // 将小的相等操作重写为插入/删除
        var i = 2
        while (i < result.length) {
            if (result[i - 2].operation == DiffOperation.delete &&
               result[i - 1].operation == DiffOperation.insert &&
               result[i].operation == DiffOperation.equal) {
                // 检查是否值得交换
                let delText = result[i - 2].text
                let insText = result[i - 1].text
                let eqText = result[i].text
                if (delText.length < eqText.length && insText.length < eqText.length) {
                    // 交换可能是语义上更好的
                    let commonSuffix = commonSuffixLength(text1: delText, text2: insText)
                    if (commonSuffix > 0) {
                        // 调整
                        changes = true
                    }
                }
            }
            i += 1
        }

        if (changes) {
            result = cleanupMerge(diffs: result)
        }
        return result
    }

    /// 合并清理 - 合并相邻的相同操作
    public func cleanupMerge(diffs: Array<Diff>): Array<Diff> {
        var result = Array<Diff>()
        if (diffs.length == 0) { return result }

        // 添加哨兵
        result.append(Diff(operation: DiffOperation.equal, text: ""))
        for (d in diffs) {
            let last = result[result.length - 1]
            if (last.operation == d.operation) {
                // 合并
                result[result.length - 1] = Diff(operation: d.operation, text: last.text + d.text)
            } else {
                result.append(d)
            }
        }

        // 移除空差异和哨兵
        var cleaned = Array<Diff>()
        for (d in result) {
            if (d.text.length > 0 || d.operation != DiffOperation.equal) {
                cleaned.append(d)
            }
        }

        // 如果第一个不是equal, 添加空equal
        if (cleaned.length > 0 && cleaned[0].operation != DiffOperation.equal) {
            cleaned.insert(0, Diff(operation: DiffOperation.equal, text: ""))
        }
        // 如果最后一个不是equal, 添加空equal
        if (cleaned.length > 0 && cleaned[cleaned.length - 1].operation != DiffOperation.equal) {
            cleaned.append(Diff(operation: DiffOperation.equal, text: ""))
        }

        // 合并分割的equal
        var finalResult = Array<Diff>()
        if (cleaned.length > 0) {
            finalResult.append(cleaned[0])
            var i = 1
            while (i < cleaned.length) {
                if (cleaned[i].operation == DiffOperation.equal && finalResult[finalResult.length - 1].operation == DiffOperation.equal) {
                    finalResult[finalResult.length - 1] = Diff(operation: DiffOperation.equal, text: finalResult[finalResult.length - 1].text + cleaned[i].text)
                } else {
                    finalResult.append(cleaned[i])
                }
                i += 1
            }
        }

        // 移除首尾空equal
        while (finalResult.length > 0 && finalResult[0].text.length == 0) {
            finalResult.removeAt(0)
        }
        while (finalResult.length > 0 && finalResult[finalResult.length - 1].text.length == 0) {
            finalResult.removeAt(finalResult.length - 1)
        }

        return finalResult
    }

    /// 计算公共前缀长度
    public static func commonPrefixLength(text1: String, text2: String): Int64 {
        if (text1 == text2) { return Int64(text1.length) }
        let minLen = Int64(min(text1.length, text2.length))
        var n: Int64 = 0
        while (n < minLen) {
            if (text1[n] != text2[n]) { break }
            n += 1
        }
        return n
    }

    /// 计算公共后缀长度
    public static func commonSuffixLength(text1: String, text2: String): Int64 {
        if (text1 == text2) { return Int64(text1.length) }
        let minLen = Int64(min(text1.length, text2.length))
        var n: Int64 = 0
        while (n < minLen) {
            if (text1[Int64(text1.length) - 1 - n] != text2[Int64(text2.length) - 1 - n]) { break }
            n += 1
        }
        return n
    }

    /// 将文本转换为行字符编码(用于行级差异)
    public func diffLinesToChars(text1: String, text2: String): LinesToCharsResult {
        var lineArray = Array<String>()
        var lineHash = HashMap<String, UInt64>()
        lineHash[""] = 0

        var chars1 = encodeLines(text: text1, lineArray: lineArray, lineHash: lineHash)
        var chars2 = encodeLines(text: text2, lineArray: lineArray, lineHash: lineHash)
        return LinesToCharsResult(chars1: chars1, chars2: chars2, lineArray: lineArray)
    }

    private func encodeLines(text: String, lineArray: Array<String>, lineHash: HashMap<String, UInt64>): String {
        var result = ""
        var lines = text.split(separator: "\n", keepDelimiters: true)
        for (line in lines) {
            if (lineHash.contains(line)) {
                let code = lineHash[line].getOrThrow()
                result += String.fromCodePoint(code)
            } else {
                let code = UInt64(lineArray.length + 1)
                lineArray.append(line)
                lineHash[line] = code
                result += String.fromCodePoint(code)
            }
        }
        return result
    }

    /// 将字符差异转换回行差异
    public func diffCharsToLines(diffs: Array<Diff>, lineArray: Array<String>): Array<Diff> {
        var result = Array<Diff>()
        for (d in diffs) {
            var text = ""
            for (ch in d.text.runes()) {
                let idx = Int64(ch) - 1
                if (idx >= 0 && idx < lineArray.length) {
                    text += lineArray[idx]
                }
            }
            result.append(Diff(operation: d.operation, text: text))
        }
        return result
    }
}

/// 半匹配结果
public class HalfMatchResult {
    public var text1A: String   // 长文本前半部分
    public var text1B: String   // 长文本后半部分
    public var text2A: String   // 短文本前半部分
    public var text2B: String   // 短文本后半部分
    public var commonMid: String // 公共中间部分

    public init(text1A: String, text1B: String, text2A: String, text2B: String, commonMid: String) {
        this.text1A = text1A
        this.text1B = text1B
        this.text2A = text2A
        this.text2B = text2B
        this.commonMid = commonMid
    }
}

/// 行到字符编码的结果
public class LinesToCharsResult {
    public var chars1: String
    public var chars2: String
    public var lineArray: Array<String>

    public init(chars1: String, chars2: String, lineArray: Array<String>) {
        this.chars1 = chars1
        this.chars2 = chars2
        this.lineArray = lineArray
    }
}
