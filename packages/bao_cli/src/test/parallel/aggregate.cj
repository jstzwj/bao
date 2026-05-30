// 严格翻译自: src/cli/test/parallel/aggregate.zig
package bao_cli.test.parallel

import bao_core.*
import bao_runtime.*
import bao_cli.test.*
import bao_io.*
import bao_collections.*

// ============================================================================
// Aggregate — Per-worker JUnit XML 和 LCOV 覆盖率片段合并
// 严格翻译自: src/cli/test/parallel/aggregate.zig
//
// Worker 将各自的片段写入共享临时目录
// 协调器在 drive() 完成后拼接为单一文档/报告
// ============================================================================

/// 合并 JUnit XML 片段
/// 对应 Bun: mergeJUnitFragments()
public func mergeJUnitFragments(coord: Coordinator, outfile: String, summary: TestRunnerSummary): Unit {
    let body = StringBuilder()

    var totalTests: Int64 = 0
    var totalFailures: Int64 = 0
    var totalSkipped: Int64 = 0

    for (path in coord.junitFragments) {
        let content = match (BaoFile.readAllText(path)) {
            case Ok(text) => text
            case Err(_) => continue
        }

        // 每个 fragment 是完整的 <testsuites> 文档
        let openStart = match (content.indexOf("<testsuites")) {
            case Some(v) => v
            case None => continue
        }
        let headEnd = match (content.indexOf('>', openStart)) {
            case Some(v) => v
            case None => continue
        }
        let head = content[openStart..headEnd]

        // 提取头部属性
        totalTests += attrValue(head, "tests")
        totalFailures += attrValue(head, "failures")
        totalSkipped += attrValue(head, "skipped")

        // 提取主体内容
        let bodyStart = headEnd + 1
        let bodyEnd = match (content.lastIndexOf("</testsuites>")) {
            case Some(v) => v
            case None => continue
        }
        if (bodyStart >= bodyEnd) {
            continue
        }
        let inner = content[bodyStart..bodyEnd]
        if (inner.size > 0) {
            body.append(inner)
            body.append('\n')
        }
    }

    // 处理崩溃的文件
    for (idx in coord.crashedFiles) {
        let rel = coord.relPath(idx)
        body.append("  <testsuite name=\"${escapeXml(rel)}\" tests=\"1\" assertions=\"0\" failures=\"1\" skipped=\"0\" time=\"0\">\n")
        body.append("    <testcase name=\"(worker crashed)\" classname=\"${escapeXml(rel)}\">\n")
        body.append("      <failure message=\"worker process crashed before reporting results\"></failure>\n")
        body.append("    </testcase>\n")
        body.append("  </testsuite>\n")
        totalTests += 1
        totalFailures += 1
    }

    // 写入合并后的文件
    let contents = StringBuilder()
    contents.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
    contents.append("<testsuites name=\"bao test\" tests=\"${totalTests}\" assertions=\"${summary.expectations}\" failures=\"${totalFailures}\" skipped=\"${totalSkipped}\" time=\"0\">\n")
    contents.append(body.toString())
    contents.append("</testsuites>\n")

    BaoFile.writeAllText(outfile, contents.toString())
}

/// 从属性头中提取数值属性
/// 对应 Bun: attrValue()
private func attrValue(head: String, name: String): Int64 {
    let needle = " ${name}=\""
    let start = match (head.indexOf(needle)) {
        case Some(v) => v
        case None => return 0
    }
    let valStart = start + needle.size
    let end = match (head.indexOf('"', valStart)) {
        case Some(v) => v
        case None => return 0
    }
    return match (IntParser.parseDecimal(head[valStart..end])) { case Some(v) => v case None => 0 }
}

/// 文件覆盖率信息
/// 对应 Bun: FileCoverage
public class FileCoverage {
    public var path: String
    public var fnf: Int64
    public var fnh: Int64
    /// 1-based 行号 -> 命中次数总和
    public var da: HashMap<Int64, Int64>

    public init(path: String) {
        this.path = path
        this.fnf = 0
        this.fnh = 0
        this.da = HashMap<Int64, Int64>()
    }

    /// 被命中行数 (da 中 count > 0 的行数)
    public func lh(): Int64 {
        var count: Int64 = 0
        let entries = da.entries()
        for (entry in entries) {
            if (entry.value > 0) {
                count += 1
            }
        }
        return count
    }
}

/// 合并 per-worker LCOV 片段为单一报告
/// 对应 Bun: mergeCoverageFragments()
///
/// 1. 读取所有 worker 的 LCOV 片段文件
/// 2. 按源文件分组, 合并 DA (行命中) 计数 (求和)
/// 3. FNF/FNH 取每 worker 的最大值
/// 4. 输出合并后的 LCOV 报告 + 文本覆盖率表
public func mergeCoverageFragments(paths: ArrayList<String>, opts: CodeCoverageOptions, enableColors: Bool): Unit {
    let byFile = HashMap<String, FileCoverage>()

    for (path in paths) {
        let content = match (BaoFile.readAllText(path)) {
            case Ok(text) => text
            case Err(_) => continue
        }

        var cur: ?FileCoverage = None
        let lines = content.split('\n')
        for (raw in lines) {
            let line = raw.trimEnd('\r')
            if (line.startsWith("SF:")) {
                let name = line[3..]
                match (byFile.get(name)) {
                    case Some(existing) => cur = existing
                    case None =>
                        let fc = FileCoverage(name)
                        byFile.put(name, fc)
                        cur = fc
                }
            } else if (line == "end_of_record") {
                cur = None
            } else if (let Some(fc) <- cur) {
                if (line.startsWith("DA:")) {
                    // DA:line_number,hit_count
                    let daContent = line[3..]
                    let commaIdx = match (daContent.indexOf(',')) {
                        case Some(v) => v
                        case None => continue
                    }
                    let lnStr = daContent[0..commaIdx]
                    let cntStr = daContent[commaIdx + 1..]
                    let ln = match (IntParser.parseDecimal(lnStr)) { case Some(v) => v case None => continue }
                    let cnt = match (IntParser.parseDecimal(cntStr)) { case Some(v) => v case None => continue }
                    match (fc.da.get(ln)) {
                        case Some(existing) => fc.da.put(ln, existing + cnt)
                        case None => fc.da.put(ln, cnt)
                    }
                } else if (line.startsWith("FNF:")) {
                    let val = match (IntParser.parseDecimal(line[4..])) { case Some(v) => v case None => 0 }
                    if (val > fc.fnf) { fc.fnf = val }
                } else if (line.startsWith("FNH:")) {
                    let val = match (IntParser.parseDecimal(line[4..])) { case Some(v) => v case None => 0 }
                    if (val > fc.fnh) { fc.fnh = val }
                }
            }
        }
    }

    if (byFile.size == 0) {
        return
    }

    // 收集并排序文件名
    let sortedPaths = ArrayList<String>()
    let keys = byFile.keys()
    for (k in keys) {
        sortedPaths.append(k)
    }
    sortedPaths.sort()

    // 输出合并后的 LCOV 报告
    if (opts.lcovReporter) {
        let outPath = "${opts.reportsDirectory}/lcov.info"
        let writer = StringBuilder()
        for (path in sortedPaths) {
            match (byFile.get(path)) {
                case Some(fc) =>
                    writer.append("TN:\n")
                    writer.append("SF:${fc.path}\n")
                    writer.append("FNF:${fc.fnf}\n")
                    writer.append("FNH:${fc.fnh}\n")

                    // 按行号排序输出 DA 记录
                    let sortedLineNums = ArrayList<Int64>()
                    let daEntries = fc.da.entries()
                    for (entry in daEntries) {
                        sortedLineNums.append(entry.key)
                    }
                    sortedLineNums.sort()
                    for (ln in sortedLineNums) {
                        let cnt = fc.da.get(ln) ?? 0
                        writer.append("DA:${ln},${cnt}\n")
                    }
                    writer.append("LF:${fc.da.size}\n")
                    writer.append("LH:${fc.lh()}\n")
                    writer.append("end_of_record\n")
                case None => ()
            }
        }
        BaoFile.writeAllText(outPath, writer.toString())
    }

    // 输出文本覆盖率表
    if (opts.textReporter) {
        // 表头
        let maxLen = sortedPaths.fold(8, { max_val, path =>
            if (path.size > max_val) { path.size } else { max_val }
        })
        printCoverageTableHeader(maxLen)

        var totalFunctions: Float64 = 0.0
        var totalLines: Float64 = 0.0
        var fileCount: Float64 = 0.0
        var anyFailing = false

        for (path in sortedPaths) {
            match (byFile.get(path)) {
                case Some(fc) =>
                    let lf: Float64 = Float64(fc.da.size)
                    let lh: Float64 = Float64(fc.lh())
                    let lineCov = if (lf > 0.0) { lh / lf } else { 1.0 }
                    let funcCov = if (fc.fnf > 0) { Float64(fc.fnh) / Float64(fc.fnf) } else { 1.0 }
                    let failing = funcCov < opts.fractions.functions || lineCov < opts.fractions.lines
                    if (failing) { anyFailing = true }

                    totalFunctions += funcCov
                    totalLines += lineCov
                    fileCount += 1.0

                    printCoverageRow(path, maxLen, funcCov, lineCov, failing)

                    // 输出未覆盖行号范围
                    let uncovered = ArrayList<Int64>()
                    let daEntries = fc.da.entries()
                    for (entry in daEntries) {
                        if (entry.value == 0) {
                            uncovered.append(entry.key)
                        }
                    }
                    uncovered.sort()
                    if (uncovered.size > 0) {
                        printUncoveredLineRanges(uncovered)
                    }
                    println("")
                case None => ()
            }
        }

        // 汇总行
        let avgFunctions = if (fileCount > 0.0) { totalFunctions / fileCount } else { 0.0 }
        let avgLines = if (fileCount > 0.0) { totalLines / fileCount } else { 0.0 }
        printCoverageRow("All files", maxLen, avgFunctions, avgLines, anyFailing)
        printCoverageTableFooter(maxLen)
    }
}

/// 打印覆盖率表头
private func printCoverageTableHeader(maxLen: Int64): Unit {
    let sep = "-".repeat(maxLen + 2) + "|---------|---------|-------------------"
    println(sep)
    let pad = " ".repeat(maxLen - 4 + 1)
    print("File${pad} | % Funcs | % Lines | Uncovered Line #s\n")
    println(sep)
}

/// 打印覆盖率表尾
private func printCoverageTableFooter(maxLen: Int64): Unit {
    let sep = "-".repeat(maxLen + 2) + "|---------|---------|-------------------"
    println(sep)
}

/// 打印覆盖率行
private func printCoverageRow(path: String, maxLen: Int64, funcCov: Float64, lineCov: Float64, failing: Bool): Unit {
    let padding = " ".repeat(maxLen - path.size + 1)
    let pctFuncs = (funcCov * 100.0).format("0.0")
    let pctLines = (lineCov * 100.0).format("0.0")
    let marker = if (failing) { "!" } else { " " }
    print("${path}${padding} | ${marker}${pctFuncs}% | ${marker}${pctLines}% |")
}

/// 打印未覆盖行号范围
private func printUncoveredLineRanges(lineNums: ArrayList<Int64>): Unit {
    if (lineNums.size == 0) {
        return
    }
    var first = true
    var rangeStart = lineNums[0]
    var rangeEnd = lineNums[0]

    for (i in 1..lineNums.size) {
        let ln = lineNums[i]
        if (ln == rangeEnd + 1) {
            rangeEnd = ln
        } else {
            if (!first) { print(",") }
            writeRange(rangeStart, rangeEnd)
            rangeStart = ln
            rangeEnd = ln
            first = false
        }
    }
    if (!first) { print(",") }
    writeRange(rangeStart, rangeEnd)
}

/// 写入行号范围
private func writeRange(a: Int64, b: Int64): Unit {
    if (a == b) {
        print("${a}")
    } else {
        print("${a}-${b}")
    }
}

/// XML 转义
private func escapeXml(s: String): String {
    return s.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
            .replace("'", "&apos;")
}
