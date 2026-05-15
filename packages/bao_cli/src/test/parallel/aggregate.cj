// 严格翻译自: src/cli/test/parallel/aggregate.zig
package bao_cli

import bao_core.*

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
    val body = StringBuilder()

    var totalTests: Int64 = 0
    var totalFailures: Int64 = 0
    var totalSkipped: Int64 = 0

    for (path in coord.junitFragments) {
        val file = BaoFile.readAllText(path)
        if (file == None) {
            continue
        }
        val content = file!!

        // 每个 fragment 是完整的 <testsuites> 文档
        val openStart = content.indexOf("<testsuites")
        if (openStart < 0) {
            continue
        }
        val headEnd = content.indexOf('>', openStart)
        if (headEnd < 0) {
            continue
        }
        val head = content.substring(openStart, headEnd)

        // 提取头部属性
        totalTests += attrValue(head, "tests")
        totalFailures += attrValue(head, "failures")
        totalSkipped += attrValue(head, "skipped")

        // 提取主体内容
        val bodyStart = headEnd + 1
        val bodyEnd = content.lastIndexOf("</testsuites>")
        if (bodyEnd < 0 || bodyStart >= bodyEnd) {
            continue
        }
        val inner = content.substring(bodyStart, bodyEnd).trim()
        if (inner.length > 0) {
            body.append(inner)
            body.append('\n')
        }
    }

    // 处理崩溃的文件
    for (idx in coord.crashedFiles) {
        val rel = coord.relPath(idx)
        body.append("  <testsuite name=\"${escapeXml(rel)}\" tests=\"1\" assertions=\"0\" failures=\"1\" skipped=\"0\" time=\"0\">\n")
        body.append("    <testcase name=\"(worker crashed)\" classname=\"${escapeXml(rel)}\">\n")
        body.append("      <failure message=\"worker process crashed before reporting results\"></failure>\n")
        body.append("    </testcase>\n")
        body.append("  </testsuite>\n")
        totalTests += 1
        totalFailures += 1
    }

    // 写入合并后的文件
    val contents = StringBuilder()
    contents.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
    contents.append("<testsuites name=\"bao test\" tests=\"${totalTests}\" assertions=\"${summary.expectations}\" failures=\"${totalFailures}\" skipped=\"${totalSkipped}\" time=\"0\">\n")
    contents.append(body.toString())
    contents.append("</testsuites>\n")

    BaoFile.writeAllText(outfile, contents.toString())
}

/// 从属性头中提取数值属性
/// 对应 Bun: attrValue()
private func attrValue(head: String, name: String): Int64 {
    val needle = " ${name}=\""
    val start = head.indexOf(needle)
    if (start < 0) {
        return 0
    }
    val valStart = start + needle.length
    val end = head.indexOf('"', valStart)
    if (end < 0) {
        return 0
    }
    return Int64.parse(head.substring(valStart, end)) ?: 0
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

    /// 被命中行数
    public func lh(): Int64 {
        var n: Int64 = 0
        for ((_, count) in da) {
            if (count > 0) {
                n += 1
            }
        }
        return n
    }
}

/// 合并 per-worker LCOV 片段为单一报告
/// 对应 Bun: mergeCoverageFragments()
public func mergeCoverageFragments(paths: ArrayList<String>, opts: TestCommand.CodeCoverageOptions, enableColors: Bool): Unit {
    val byFile = HashMap<String, FileCoverage>()

    for (path in paths) {
        val data = BaoFile.readAllText(path)
        if (data == None) {
            continue
        }

        var cur: ?FileCoverage = None
        val lines = data!!.split('\n')
        for (line in lines) {
            val trimmed = line.trimEnd('\r')
            if (trimmed.startsWith("SF:")) {
                val name = trimmed.substring(3)
                if (!byFile.contains(name)) {
                    byFile.put(name, FileCoverage(name))
                }
                cur = byFile.get(name)
            } else if (trimmed == "end_of_record") {
                cur = None
            } else if (cur != None) {
                val fc = cur!!
                if (trimmed.startsWith("DA:")) {
                    val parts = trimmed.substring(3).split(',')
                    if (parts.length >= 2) {
                        val ln = Int64.parse(parts[0]) ?: continue
                        val cnt = Int64.parse(parts[1]) ?: continue
                        val existing = fc.da.get(ln) ?: 0
                        fc.da.put(ln, existing + cnt)
                    }
                } else if (trimmed.startsWith("FNF:")) {
                    val val_ = Int64.parse(trimmed.substring(4)) ?: 0
                    fc.fnf = Math.max(fc.fnf, val_)
                } else if (trimmed.startsWith("FNH:")) {
                    val val_ = Int64.parse(trimmed.substring(4)) ?: 0
                    fc.fnh = Math.max(fc.fnh, val_)
                }
            }
        }
    }

    if (byFile.size == 0) {
        return
    }

    // 写入 lcov.info
    if (opts.reporters.lcov) {
        val outPath = Path.join(opts.reportsDirectory, "lcov.info")
        val writer = StringBuilder()
        for ((_, fc) in byFile) {
            writer.append("TN:\nSF:${fc.path}\nFNF:${fc.fnf}\nFNH:${fc.fnh}\n")
            for ((ln, cnt) in fc.da) {
                writer.append("DA:${ln},${cnt}\n")
            }
            writer.append("LF:${fc.da.size}\nLH:${fc.lh()}\nend_of_record\n")
        }
        BaoFile.writeAllText(outPath, writer.toString())
    }

    // 文本报告
    if (opts.reporters.text) {
        var failing = false

        for ((_, fc) in byFile) {
            val lf = fc.da.size.toDouble()
            val lh_ = fc.lh().toDouble()

            val linesFraction = if (lf > 0) lh_ / lf else 1.0
            val funcsFraction = if (fc.fnf > 0) fc.fnh.toDouble() / fc.fnf.toDouble() else 1.0

            if (funcsFraction < opts.fractions.functions || linesFraction < opts.fractions.lines) {
                failing = true
            }
        }

        opts.fractions.failing = failing
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
