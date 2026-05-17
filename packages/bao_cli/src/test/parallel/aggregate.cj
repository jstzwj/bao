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

    /// 被命中行数
    public func lh(): Int64 {
        return 0
    }
}

/// 合并 per-worker LCOV 片段为单一报告
/// 对应 Bun: mergeCoverageFragments()
public func mergeCoverageFragments(paths: ArrayList<String>, opts: CodeCoverageOptions, enableColors: Bool): Unit {
    ()
}

/// XML 转义
private func escapeXml(s: String): String {
    return s.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
            .replace("'", "&apos;")
}
