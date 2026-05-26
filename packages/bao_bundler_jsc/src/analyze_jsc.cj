// 严格翻译自: src/bundler_jsc/analyze_jsc.zig
//! JSC bridge for analyze_transpiled_module.zig.
package bao_bundler_jsc

import bao_jsc.*
import bao_core.*
import bao_collections.*

// ============================================================================
// AnalyzeJSC - 模块分析 JSC 桥接
// ============================================================================

/// 渲染 diff
public func zigRenderDiff(expectedPtr: String, receivedPtr: String, globalThis: JSGlobalObject): Unit {
    let diff = renderDiff(expectedPtr, receivedPtr)
    if (diff.size > 0) {
        println("DIFF:\n" + diff)
    }
}

public func renderDiff(expected: String, received: String): String {
    if (expected == received) { return "" }

    let expectedLines = splitLines(expected)
    let receivedLines = splitLines(received)
    var out = ""
    let max = if (expectedLines.size > receivedLines.size) { expectedLines.size } else { receivedLines.size }

    for (i in 0..max) {
        let e = if (i < expectedLines.size) { expectedLines[i] } else { "" }
        let r = if (i < receivedLines.size) { receivedLines[i] } else { "" }
        if (e != r) {
            out += "@@ line " + Int64(i + 1).toString() + " @@\n"
            if (e.size > 0) { out += "-" + e + "\n" }
            if (r.size > 0) { out += "+" + r + "\n" }
        }
    }
    return out
}

private func splitLines(input: String): ArrayList<String> {
    let lines = ArrayList<String>()
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < input.size) {
        if (input[i] == UInt8(10)) {
            lines.append(input[start..i])
            start = i + 1
        }
        i++
    }
    if (start <= input.size) {
        lines.append(input[start..input.size])
    }
    return lines
}
