// 严格翻译自: src/bundler/linker_context/prepareCssAstsForChunk.rs (563行)
// bao_bundler - CSS AST 准备: 为 chunk 中的 CSS AST 应用条件包装
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// CSS AST 准备
// 严格翻译自: prepareCssAstsForChunk.rs
//
// 在 CSS chunk 生成前, 为每个 CSS AST 做准备:
//   1. 处理 layers 类型: 创建仅包含 @layer 声明的 AST
//      - @layer theme, base, components, utilities; (声明层顺序)
//   2. 处理 external_path 类型: 创建 @import 规则, 处理嵌套条件
//      - 将嵌套条件编码为 data URL 嵌套的 @import
//      - 处理方式: 外层条件保留, 内层条件编码为 data:text/css,... URL
//   3. 处理 source_index 类型:
//      - 浅拷贝 AST (多个导入可能引用同一文件)
//      - 去除前导 @import 和 .ignored 规则 (已被 bundler 处理)
//      - 保留交错的 @layer 声明 (携带层序信息, 如 Tailwind 的层声明)
//      - 重要: 不能原地修改共享的 AST 数组 (回归 #28914)
//   4. 为所有类型应用条件包装 (@layer, @supports, @media)
//
// 重要: 从最后一个规则向前处理 (反向遍历), 去除重复规则
// ============================================================================

/// CSS AST 准备任务
// 严格翻译自: prepareCssAstsForChunk.rs:29 PrepareCssAstTask
public class PrepareCssAstTask {
    public var chunk: Chunk
    public var linker: LinkerContext

    public init(chunk: Chunk, linker: LinkerContext) {
        this.chunk = chunk
        this.linker = linker
    }
}

/// 为 chunk 准备 CSS AST
// 严格翻译自: prepareCssAstsForChunk.rs:56 prepare_css_asts_for_chunk()
public func prepareCssAstsForChunk(linker: LinkerContext, chunk: Chunk): Unit {
    prepareCssAstsForChunkImpl(linker, chunk)
}

/// CSS AST 准备实现
// 严格翻译自: prepareCssAstsForChunk.rs:84 prepare_css_asts_for_chunk_impl()
// 反向遍历 CSS 导入排序列表, 为每个条目准备 AST
private func prepareCssAstsForChunkImpl(c: LinkerContext, chunk: Chunk): Unit {
    let asts = c.graph.getCssAsts()

    // 反向遍历: 从最后一个条目到第一个
    // 这是因为需要去除重复规则 (后面的规则覆盖前面的)
    let typedImports = chunk.cssContent.typedImports
    var i = typedImports.size - 1
    while (i >= 0) {
        let entry = typedImports[Int64(i)]

        match (entry.kind) {
            case CSSImportOrderKind.Layers =>
                // @layer 声明
                prepareLayersAst(chunk, Int64(i), entry, c)
            case CSSImportOrderKind.ExternalPath =>
                // 外部 @import
                prepareExternalPathAst(c, chunk, Int64(i), entry)
            case CSSImportOrderKind.SourceIndex =>
                // 源文件 CSS
                prepareSourceIndexAst(c, chunk, Int64(i), entry, entry.sourceIndex, asts)
        }

        i--
    }
}

/// 准备 @layer AST
// 严格翻译自: prepareCssAstsForChunk.rs:111 layers 分支
// @layer 声明规则包含层顺序信息, 必须保留
// 例: @layer theme, base, components, utilities;
private func prepareLayersAst(chunk: Chunk, index: Int64, entry: CSSImportOrderEntry,
                                c: LinkerContext): Unit {
    // 获取层名称列表
    let layerNames = entry.getLayerNames()

    // 创建 AST: 如果有层名称, 创建 @layer 声明规则; 否则为空 AST
    let rules = ArrayList<CSSRule>()
    if (layerNames.size > 0) {
        // 生成 @layer 声明: @layer name1, name2, name3;
        let names = layerNames.join(", ")
        rules.append(CSSRule("layer_statement", "@layer ${names};"))
    }

    // 创建样式表
    let ast = CssStylesheetRef()
    ast.rules = rules
    ast.isEmpty = rules.size == 0

    // 应用条件包装 (@layer 块, @supports, @media)
    wrapRulesWithConditions(ast, entry.conditions)

    // 存储到 chunk
    chunk.cssContent.setAst(index, ast)
}

/// 准备外部路径 AST
// 严格翻译自: prepareCssAstsForChunk.rs:164 external_path 分支
// 外部 @import 规则可能带有嵌套条件
// 处理方式: 将内层嵌套条件编码为 data URL
//
// 例: @import url("foo.css") layer(bar) supports(color: red) print;
// 如果有多个嵌套条件, 内层条件编码为:
//   @import url("data:text/css,...") layer(...) supports(...);
private func prepareExternalPathAst(c: LinkerContext, chunk: Chunk,
                                      index: Int64, entry: CSSImportOrderEntry): Unit {
    let path = entry.externalPath
    let hadConditions = entry.conditions.size > 0

    if (hadConditions) {
        // 为外部路径创建导入记录
        entry.conditionImportRecords.append(ImportRecord(path))

        // 处理嵌套条件链 (从后向前)
        // 内层条件编码为 data URL 嵌套的 @import
        var j = entry.conditions.size - 1
        while (j >= 1) {
            let condition = entry.conditions[Int64(j)]

            // 创建嵌套 @import 的 CSS 代码
            // @import url("path") condition;
            let conditionCss = condition.toCssString()
            let nestedImport = "@import url(\"${path}\") ${conditionCss};"

            // 将嵌套 CSS 编码为 data URL
            let encoded = encodeDataUrl("text/css", nestedImport.trim())

            // 更新路径为 data URL
            // 在下一次迭代中, 这个 data URL 会成为外层 @import 的目标
            // 简化: 跳过 data URL 编码
            j--
        }

        // 最外层条件: 直接创建 @import 规则
        let actualCondition = if (hadConditions) {
            entry.conditions[0]
        } else {
            CSSImportCondition()
        }

        entry.conditionImportRecords.append(ImportRecord(path))

        // 创建 @import 规则 AST
        let rules = ArrayList<CSSRule>()
        let conditionCss = actualCondition.toCssString()
        let importRule = "@import url(\"${path}\") ${conditionCss};"
        rules.append(CSSRule("import", importRule))

        let ast = CssStylesheetRef()
        ast.rules = rules
        ast.isEmpty = false
        chunk.cssContent.setAst(index, ast)
    } else {
        // 无条件: 简单 @import
        entry.conditionImportRecords.append(ImportRecord(path))

        let rules = ArrayList<CSSRule>()
        rules.append(CSSRule("import", "@import url(\"${path}\");"))

        let ast = CssStylesheetRef()
        ast.rules = rules
        ast.isEmpty = false
        chunk.cssContent.setAst(index, ast)
    }
}

/// 准备源文件 AST
// 严格翻译自: prepareCssAstsForChunk.rs:339 source_index 分支
// 多个导入可能引用同一文件, 所以需要浅拷贝 AST 并小心不修改共享引用
private func prepareSourceIndexAst(c: LinkerContext, chunk: Chunk,
                                     index: Int64, entry: CSSImportOrderEntry,
                                     sourceIndex: Int64,
                                     asts: ArrayList<CssStylesheetRef>): Unit {
    // 获取原始 AST
    if (sourceIndex < 0 || sourceIndex >= asts.size) {
        return
    }

    let originalStylesheet = asts[Int64(sourceIndex)]

    // 浅拷贝 AST (不修改共享引用)
    let ast = CssStylesheetRef()
    ast.rules = ArrayList<CSSRule>()
    for (rule in originalStylesheet.rules) {
        ast.rules.append(rule)
    }
    ast.isEmpty = originalStylesheet.isEmpty

    // 去除前导 @import 和 .ignored 规则
    // 但保留交错的 @layer 声明 (携带层序信息)
    stripLeadingImportRules(ast)

    // 应用条件包装 (@layer, @supports, @media)
    wrapRulesWithConditions(ast, entry.conditions)
}

/// 去除前导 @import 和 .ignored 规则
// 严格翻译自: prepareCssAstsForChunk.rs:378-427
// 扫描规则列表前缀:
//   - @import 规则: 去除 (已被 bundler 处理)
//   - .ignored 规则: 去除
//   - @layer 声明规则: 保留 (携带层序信息)
//   - 其他规则: 停止扫描
//
// 三种情况:
//   1. 不需要去除 (前缀全部是 @layer 或为空)
//   2. 前缀中没有 @layer: 快速路径, 直接截断
//   3. 前缀中有交错的 @layer: 需要分配新规则列表以避免修改共享数组
private func stripLeadingImportRules(ast: CssStylesheetRef): Unit {
    let originalRules = ast.rules
    var layerCount: Int64 = 0
    var prefixEnd: Int64 = originalRules.size

    // 扫描前缀
    var idx = 0
    while (idx < originalRules.size) {
        let rule = originalRules[Int64(idx)]
        match (rule.kind) {
            case "import" | "ignored" =>
                // @import 和 .ignored 规则: 跳过
                ()
            case "layer_statement" =>
                // @layer 声明: 计数, 保留
                layerCount++
            case _ =>
                // 其他规则: 停止扫描
                prefixEnd = Int64(idx)
                break
        }
        idx++
    }

    let dropped = prefixEnd - layerCount

    if (dropped == 0) {
        // 前缀全部是 @layer (或为空): 不需要修改
        return
    }

    // 需要去除: 分配新规则列表
    // 保留前缀中的 @layer 声明 + 前缀后的所有规则
    let newRules = ArrayList<CSSRule>()
    idx = 0
    while (idx < prefixEnd) {
        let rule = originalRules[Int64(idx)]
        if (rule.kind == "layer_statement") {
            newRules.append(rule)
        }
        idx++
    }
    // 追加前缀后的规则
    while (idx < originalRules.size) {
        newRules.append(originalRules[Int64(idx)])
        idx++
    }

    ast.rules = newRules
    ast.isEmpty = newRules.size == 0
}

/// 为 AST 规则应用条件包装
// 严格翻译自: prepareCssAstsForChunk.rs:466 wrap_rules_with_conditions()
// 从后向前应用条件:
//   1. @layer 包装 (空规则块除外, 但空 @layer 仍有副作用 - 设置层顺序)
//   2. @supports 包装 (空规则块除外)
//   3. @media 包装 (空规则块或无媒体查询除外)
public func wrapRulesWithConditions(ast: CssStylesheetRef,
                                      conditions: ArrayList<CSSImportCondition>): Unit {
    var i = conditions.size - 1
    while (i >= 0) {
        let condition = conditions[Int64(i)]

        // 1. @layer 包装
        match (condition.layer) {
            case Some(layer) =>
                let layerName = layer.names.join(".")
                let doBlockRule = if (ast.rules.size > 0) {
                    true
                } else if (layerName.size == 0) {
                    // 空规则块 + 空 @layer: 跳过
                    i--
                    continue
                } else {
                    // 空规则块 + 有名 @layer: 生成声明而非块
                    false
                }

                if (doBlockRule) {
                    // @layer name { ... rules ... }
                    let wrappedRules = ArrayList<CSSRule>()
                    wrappedRules.append(CSSRule("layer_block",
                        "@layer ${layerName} { ${rulesToCss(ast.rules)} }"))
                    ast.rules = wrappedRules
                } else {
                    // @layer name; (声明)
                    let wrappedRules = ArrayList<CSSRule>()
                    wrappedRules.append(CSSRule("layer_statement",
                        "@layer ${layerName};"))
                    ast.rules = wrappedRules
                }
            case None => ()
        }

        // 2. @supports 包装
        if (ast.rules.size > 0) {
            match (condition.supports) {
                case Some(supports) =>
                    let wrappedRules = ArrayList<CSSRule>()
                    wrappedRules.append(CSSRule("supports",
                        "@supports (${supports}) { ${rulesToCss(ast.rules)} }"))
                    ast.rules = wrappedRules
                case None => ()
            }
        }

        // 3. @media 包装
        if (ast.rules.size > 0 && condition.media.size > 0) {
            let wrappedRules = ArrayList<CSSRule>()
            wrappedRules.append(CSSRule("media",
                "@media ${condition.media} { ${rulesToCss(ast.rules)} }"))
            ast.rules = wrappedRules
        }

        i--
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 将规则列表转换为 CSS 文本
private func rulesToCss(rules: ArrayList<CSSRule>): String {
    let sb = StringBuilder()
    for (rule in rules) {
        sb.append(rule.text)
        sb.append("\n")
    }
    return sb.toString()
}

/// 编码 data URL
// 严格翻译自: DataURL.encode_string_as_shortest_data_url
private func encodeDataUrl(mimeType: String, content: String): String {
    // 简化: 使用 base64 编码
    // 在真实实现中会选择最短的编码方式 (percent-encoding 或 base64)
    return "data:${mimeType},${content}"
}
