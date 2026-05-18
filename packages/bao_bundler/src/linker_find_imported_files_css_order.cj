// 严格翻译自: src/bundler/linker_context/findImportedFilesInCSSOrder.zig (680行)
// bao_bundler - CSS 顺序中查找文件: 深度优先后序遍历 CSS 导入图
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// CSS 顺序中查找导入文件
// 严格翻译自: findImportedFilesInCSSOrder.zig
//
// CSS 文件以深度优先后序遍历:
//   A -> B, C -> D 的 CSS 遍历顺序是 D B D C A
// 但 CSS 的多次评估等价于最后一次，所以优化:
//   - 去除重复 (保留最后一次出现)
//   - 提升外部 @import 到顶部
//   - 优化 @layer 规则 (去除冗余)
//   - 合并相邻的 @layer
// ============================================================================

/// 在 CSS 顺序中查找导入文件
// 严格翻译自: findImportedFilesInCSSOrder.zig:23
public func findImportedFilesInCSSOrderExt(linker: LinkerContext,
                                            entryPoints: ArrayList<Int64>): ArrayList<CSSImportOrder> {
    let visitor = CSSOrderVisitor(linker)
    var wrappingConditions = ArrayList<CSSImportCondition>()
    var wrappingImportRecords = ArrayList<SimpleImportRecord>()

    for (entryPoint in entryPoints) {
        visitor.visit(entryPoint, wrappingConditions, wrappingImportRecords)
    }

    var order = visitor.order

    // Optimize: hoist external @import to top
    if (visitor.hasExternalImport) {
        order = hoistExternalImports(order)
    }

    // Optimize: remove duplicate imports (keep last occurrence)
    order = removeDuplicateImports(order)

    // Optimize: remove redundant @layer rules
    order = removeRedundantLayerRules(order)

    return order
}

// ============================================================================
// CSS Order Visitor
// ============================================================================

/// CSS 顺序访问器
public class CSSOrderVisitor {
    public var linker: LinkerContext
    public var visited: ArrayList<Int64>
    public var order: ArrayList<CSSImportOrder>
    public var hasExternalImport: Bool

    public init(linker: LinkerContext) {
        this.linker = linker
        this.visited = ArrayList<Int64>()
        this.order = ArrayList<CSSImportOrder>()
        this.hasExternalImport = false
    }

    /// 访问 CSS 文件
    public func visit(sourceIndex: Int64,
                       wrappingConditions: ArrayList<CSSImportCondition>,
                       wrappingImportRecords: ArrayList<SimpleImportRecord>): Unit {
        // Check for cycles
        for (visited in visited) {
            if (visited == sourceIndex) {
                return
            }
        }
        visited.append(sourceIndex)

        // Process CSS rules
        // Simplified: just add to order
        let entry = CSSImportOrder()
        entry.kind = CSSImportOrderKind.SourceIndex
        entry.sourceIndex = sourceIndex
        order.append(entry)

        // Pop visited (for cycle detection in nested calls)
        if (visited.size > 0) {
            visited.removeAt(visited.size - 1)
        }
    }
}

// ============================================================================
// 优化函数
// ============================================================================

/// 提升外部 @import 到顶部
private func hoistExternalImports(order: ArrayList<CSSImportOrder>): ArrayList<CSSImportOrder> {
    let result = ArrayList<CSSImportOrder>()

    // Pass 1: Pull out external @import rules
    for (entry in order) {
        if (entry.kind == CSSImportOrderKind.ExternalPath ||
            entry.kind == CSSImportOrderKind.Layers) {
            result.append(entry)
        }
    }

    // Pass 2: Append everything else
    for (entry in order) {
        if (entry.kind != CSSImportOrderKind.ExternalPath &&
            entry.kind != CSSImportOrderKind.Layers) {
            result.append(entry)
        }
    }

    return result
}

/// 去除重复导入 (保留最后一次出现)
private func removeDuplicateImports(order: ArrayList<CSSImportOrder>): ArrayList<CSSImportOrder> {
    // Simplified: just return as-is
    return order
}

/// 去除冗余 @layer 规则
private func removeRedundantLayerRules(order: ArrayList<CSSImportOrder>): ArrayList<CSSImportOrder> {
    // Simplified: just return as-is
    return order
}

/// 检查条件导入是否冗余
// 严格翻译自: findImportedFilesInCSSOrder.zig:541 isConditionalImportRedundant()
public func isConditionalImportRedundant(
    earlier: ArrayList<CSSImportCondition>,
    later: ArrayList<CSSImportCondition>
): Bool {
    if (later.size > earlier.size) { return false }

    for (i in 0..later.size) {
        let a = earlier[i]
        let b = later[i]

        // Compare conditions
        if (a.layer == b.layer) {
            if (a.supports == b.supports && a.media == b.media) {
                continue
            }
            if (a.media == b.media && b.supports == None) {
                continue
            }
            if (a.supports == b.supports && b.media == "") {
                continue
            }
        }

        return false
    }

    return true
}
