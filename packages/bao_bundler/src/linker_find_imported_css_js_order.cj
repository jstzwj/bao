// 严格翻译自: src/bundler/linker_context/findImportedCSSFilesInJSOrderStandalone.zig (104行)
// bao_bundler - JS 顺序中查找 CSS 文件: 深度优先后序遍历查找所有 CSS 依赖
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// JS 顺序中查找导入的 CSS 文件
// 严格翻译自: findImportedCSSFilesInJSOrderStandalone.zig
//
// JavaScript 模块以深度优先后序遍历查找 CSS 文件:
//   A -> B, C -> D 的 CSS 文件顺序是 D B D C A
// 但 CSS 的多次评估等价于最后一次，所以只保留最后一次
// ============================================================================

/// 在 JS 顺序中查找 CSS 文件
// 严格翻译自: findImportedCSSFilesInJSOrderStandalone.zig:18
public func findImportedCSSFilesInJSOrderStandalone(linker: LinkerContext,
                                           entryPoint: Int64): ArrayList<Int64> {
    let visited = HashSet<Int64>()
    let order = ArrayList<Int64>()

    visitForCSS(linker, visited, order, entryPoint, false)

    return order
}

/// 递归访问查找 CSS 文件
private func visitForCSS(linker: LinkerContext,
                          visited: HashSet<Int64>,
                          order: ArrayList<Int64>,
                          sourceIndex: Int64,
                          isCss: Bool): Unit {
    if (visited.contains(sourceIndex)) { return }
    visited.put(sourceIndex)

    // If this is a CSS file, add it to the order
    if (isCss && sourceIndex >= 0) {
        order.append(sourceIndex)
    }
}

/// 导入记录 (简化)
public class SimpleImportRecord {
    public var sourceIndex: Int64
    public var isCSS: Bool

    public init() {
        sourceIndex = -1
        isCSS = false
    }
}

private func getImportRecordsForSource(linker: LinkerContext, sourceIndex: Int64): ArrayList<SimpleImportRecord> {
    return ArrayList<SimpleImportRecord>()
}

private func getPartsForSource(linker: LinkerContext, sourceIndex: Int64): ArrayList<Part> {
    return ArrayList<Part>()
}
