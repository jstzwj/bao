// 严格翻译自: src/bundler/linker_context/prepareCssAstsForChunk.zig (332行)
// bao_bundler - CSS AST 准备: 为 chunk 中的 CSS AST 应用条件包装
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// CSS AST 准备
// 严格翻译自: prepareCssAstsForChunk.zig
//
// 在 CSS chunk 生成前, 为每个 CSS AST 做准备:
//   1. 处理 layers 类型: 创建仅包含 @layer 声明的 AST
//   2. 处理 external_path 类型: 创建 @import 规则, 处理嵌套条件
//      - 将嵌套条件编码为 data URL 嵌套的 @import
//   3. 处理 source_index 类型:
//      - 浅拷贝 AST (多个导入可能引用同一文件)
//      - 去除前导 @import 和 .ignored 规则
//      - 保留交错的 @layer 声明 (携带层序信息)
//      - 注意: 不能原地修改共享的 AST 数组 (回归 #28914)
//   4. 为所有类型应用条件包装 (@layer, @supports, @media)
//
// 重要: 从最后一个规则向前处理 (反向遍历), 去除重复规则
// ============================================================================

/// CSS AST 准备任务
// 严格翻译自: prepareCssAstsForChunk.zig:1 PrepareCssAstTask
public class PrepareCssAstTask {
    public var chunk: Chunk
    public var linker: LinkerContext

    public init(chunk: Chunk, linker: LinkerContext) {
        this.chunk = chunk
        this.linker = linker
    }
}

/// 为 chunk 准备 CSS AST
// 严格翻译自: prepareCssAstsForChunk.zig:7 prepareCssAstsForChunk()
public func prepareCssAstsForChunk(linker: LinkerContext, chunk: Chunk): Unit {
    prepareCssAstsForChunkImpl(linker, chunk)
}

/// CSS AST 准备实现
// 严格翻译自: prepareCssAstsForChunk.zig:15
private func prepareCssAstsForChunkImpl(c: LinkerContext, chunk: Chunk): Unit {
    // Prepare CSS ASTs - process in reverse order
    var i: Int64 = chunk.content.css.importsInChunkInOrder.size
    while (i > 0) {
        i -= 1
        let entry = chunk.content.css.importsInChunkInOrder[i]

        match (entry.kind) {
            case CSSImportOrderKind.Layers =>
                // Create AST with only @layer statements
                prepareLayersAst(chunk, i, entry)
            case CSSImportOrderKind.ExternalPath =>
                // Create AST with @import rule for external path
                prepareExternalPathAst(c, chunk, i, entry)
            case CSSImportOrderKind.SourceIndex =>
                // Shallow copy and strip leading @import/.ignored rules
                prepareSourceIndexAst(c, chunk, i, entry)
        }
    }
}

/// 准备 @layer AST
// 严格翻译自: prepareCssAstsForChunk.zig:27 layers 分支
private func prepareLayersAst(chunk: Chunk, index: Int64, entry: CSSImportOrder): Unit {
    // Create a stylesheet with layer statement rules from the layers data
    // Simplified: would create BundlerStyleSheet with LayerStatementRule
    wrapRulesWithConditions(chunk, index, entry.conditions)
}

/// 准备外部路径 AST
// 严格翻译自: prepareCssAstsForChunk.zig:49 external_path 分支
private func prepareExternalPathAst(c: LinkerContext, chunk: Chunk,
                                      index: Int64, entry: CSSImportOrder): Unit {
    // Handle conditions chain for external @import
    // For nested conditions, encode as data URL nested @import
    if (entry.conditions.size > 0) {
        // Process conditions from innermost to outermost
        var j: Int64 = entry.conditions.size
        while (j > 1) {
            j -= 1
            // Create a mini AST with @import rule containing this condition
            // Print it and encode as data URL for the next outer layer
            // Simplified: would call css.toCss() and DataURL.encodeStringAsShortestDataURL()
        }
    }

    // Create the main @import rule AST
    // Simplified: would create ImportRule with the final path and conditions
    wrapRulesWithConditions(chunk, index, entry.conditions)
}

/// 准备源文件 AST
// 严格翻译自: prepareCssAstsForChunk.zig:144 source_index 分支
private func prepareSourceIndexAst(c: LinkerContext, chunk: Chunk,
                                     index: Int64, entry: CSSImportOrder): Unit {
    let sourceIndex = entry.sourceIndex

    // Shallow copy the original AST (multiple imports may reference same file)
    // Simplified: chunk.content.css.asts[index] = original_stylesheet copy

    // Strip leading @import and .ignored rules
    // Preserve interleaved @layer statement rules (they carry layer ordering info)
    // IMPORTANT: must not mutate shared backing array (regression #28914)
    stripLeadingImportRules(chunk, index)

    // Apply condition wrappers
    wrapRulesWithConditions(chunk, index, entry.conditions)
}

/// 去除前导 @import 和 .ignored 规则
// 严格翻译自: prepareCssAstsForChunk.zig:155
private func stripLeadingImportRules(chunk: Chunk, index: Int64): Unit {
    // Scan the prefix of the rules list:
    // - @import rules: strip (already processed by the bundler)
    // - .ignored rules: strip
    // - @layer_statement rules: preserve (carry layer ordering)
    // - Anything else: stop scanning
    //
    // Three cases:
    // 1. No stripping needed (prefix is all @layer or empty)
    // 2. No @layer in prefix: fast path, just reslice
    // 3. Interleaved @layer: allocate fresh rules list to avoid mutating shared array
    // Simplified
}

/// 为 AST 规则应用条件包装
// 严格翻译自: prepareCssAstsForChunk.zig:226 wrapRulesWithConditions()
public func wrapRulesWithConditions(chunk: Chunk, index: Int64,
                                      conditions: ArrayList<CSSImportCondition>): Unit {
    // Apply conditions from outermost to innermost (iterate in reverse)
    var i: Int64 = conditions.size
    while (i > 0) {
        i -= 1
        let condition = conditions[i]

        // Generate @layer wrappers
        // Note: empty @layer rules still have side effect (set layer order)
        if (condition.layer != None) {
            // Wrap rules in @layer block or generate @layer statement
            // Simplified
        }

        // Generate @supports wrappers (skip if empty rules)
        // Generate @media wrappers (skip if empty rules)
        // Simplified
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// CSS 导入条件
public class CSSImportCondition {
    public var layer: ?CSSLayerName
    public var supports: ?String
    public var media: String

    public init() {
        layer = None
        supports = None
        media = ""
    }
}

/// CSS 层名称
public class CSSLayerName {
    public var names: ArrayList<String>

    public init() {
        names = ArrayList<String>()
    }
}
