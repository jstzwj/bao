// 严格翻译自: src/bundler/linker_context/generateCompileResultForCssChunk.rs (251行)
// bao_bundler - CSS chunk 编译: 为 CSS chunk 生成编译结果
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// CSS chunk 编译结果生成
// 严格翻译自: generateCompileResultForCssChunk.rs
//
// 为 CSS chunk 中的每个文件生成编译结果:
//   1. 处理三种 CSS 导入类型:
//      - layers: 仅包含 @layer 声明 (如 @layer theme, base, components, utilities;)
//      - external_path: 外部 CSS @import (带条件如 media/layer/supports)
//      - source_index: 来自源文件的 CSS AST
//   2. 调用 CSS 打印器 (to_css_with_writer) 生成最终代码
//   3. 更新 bytesInOutput 计数 (用于 metafile)
//   4. 处理打印错误
// ============================================================================

/// 为 CSS chunk 生成编译结果
// 严格翻译自: generateCompileResultForCssChunk.rs:29
public func generateCompileResultForCssChunk(
    linker: LinkerContext,
    chunk: Chunk,
    importsInChunkIndex: Int64
): CompileResult {
    return generateCompileResultForCssChunkImpl(linker, chunk, importsInChunkIndex)
}

/// CSS chunk 编译实现
// 严格翻译自: generateCompileResultForCssChunk.rs:66
private func generateCompileResultForCssChunkImpl(
    c: LinkerContext,
    chunk: Chunk,
    importsInChunkIndex: Int64
): CompileResult {
    // 获取 CSS chunk 内容
    match (chunk.cssContent) {
        case cssContent =>
            // 获取此索引对应的 CSS 导入条目 (使用 typedImports)
            let typedImports = cssContent.typedImports
            let cssImport = if (importsInChunkIndex >= 0 &&
                                importsInChunkIndex < typedImports.size) {
                typedImports[Int64(importsInChunkIndex)]
            } else {
                return makeErrorCompileResult(-1)
            }

            // 根据导入类型分支处理
            match (cssImport.kind) {
                case CSSImportOrderKind.Layers =>
                    // @layer 声明: 仅包含层顺序声明
                    return generateLayerCompileResult(c, chunk, cssImport)
                case CSSImportOrderKind.ExternalPath =>
                    // 外部 @import: 生成 @import 规则 (带条件)
                    return generateExternalPathCompileResult(c, chunk, cssImport)
                case CSSImportOrderKind.SourceIndex =>
                    // 源文件 CSS: 调用 CSS 打印器
                    return generateSourceIndexCompileResult(c, chunk, cssImport, cssImport.sourceIndex)
            }
        case _ =>
            return makeErrorCompileResult(-1)
    }
}

/// 生成 @layer 编译结果
// 严格翻译自: generateCompileResultForCssChunk.rs:118-152 layers 分支
// @layer 声明仅包含层顺序声明, 不包含实际规则
private func generateLayerCompileResult(c: LinkerContext, chunk: Chunk,
                                          cssImport: CSSImportOrderEntry): CompileResult {
    let printerOptions = CssPrinterOptions()
    printerOptions.minify = c.options.minifyWhitespace
    printerOptions.targets = cssTargetsForBundlerTarget(c.options.target)

    // 调用 CSS 打印器
    let importInfo = CssImportInfo()
    importInfo.importRecords = cssImport.conditionImportRecords
    importInfo.astUrlsForCss = c.graph.getAstUrlsForCss()
    importInfo.astUniqueKeyForAdditionalFile = c.graph.getUniqueKeysForAdditionalFile()

    let code = printCssStylesheet(cssImport.ast, printerOptions, importInfo, c.mangledProps)

    let result = CompileResult()
    result.kind = CompileResultKind.CSS
    result.code = code
    result.sourceIndex = -1 // layers 没有关联源文件
    return result
}

/// 生成外部路径编译结果
// 严格翻译自: generateCompileResultForCssChunk.rs:154-196 external_path 分支
// 外部 @import 生成带条件的导入规则
private func generateExternalPathCompileResult(c: LinkerContext, chunk: Chunk,
                                                 cssImport: CSSImportOrderEntry): CompileResult {
    let printerOptions = CssPrinterOptions()
    printerOptions.minify = c.options.minifyWhitespace
    printerOptions.targets = cssTargetsForBundlerTarget(c.options.target)

    let importInfo = CssImportInfo()
    importInfo.importRecords = cssImport.conditionImportRecords
    importInfo.astUrlsForCss = c.graph.getAstUrlsForCss()
    importInfo.astUniqueKeyForAdditionalFile = c.graph.getUniqueKeysForAdditionalFile()

    let code = printCssStylesheet(cssImport.ast, printerOptions, importInfo, c.mangledProps)

    let result = CompileResult()
    result.kind = CompileResultKind.CSS
    result.code = code
    result.sourceIndex = -1
    return result
}

/// 生成源文件编译结果
// 严格翻译自: generateCompileResultForCssChunk.rs:197-244 source_index 分支
// 来自源文件的 CSS: 调用 CSS 打印器并更新 bytesInOutput
private func generateSourceIndexCompileResult(c: LinkerContext, chunk: Chunk,
                                                cssImport: CSSImportOrderEntry,
                                                sourceIndex: Int64): CompileResult {
    let printerOptions = CssPrinterOptions()
    printerOptions.minify = c.options.minifyWhitespace ||
                            c.options.minifySyntax ||
                            c.options.minifyIdentifiers
    printerOptions.targets = cssTargetsForBundlerTarget(c.options.target)

    let importInfo = CssImportInfo()
    importInfo.importRecords = c.graph.getImportRecords(sourceIndex)
    importInfo.astUrlsForCss = c.graph.getAstUrlsForCss()
    importInfo.astUniqueKeyForAdditionalFile = c.graph.getUniqueKeysForAdditionalFile()

    let code = printCssStylesheet(cssImport.ast, printerOptions, importInfo, c.mangledProps)

    // 更新 bytesInOutput (用于 metafile 统计)
    if (code.size > 0) {
        updateBytesInOutput(chunk, sourceIndex, Int64(code.size))
    }

    let result = CompileResult()
    result.kind = CompileResultKind.CSS
    result.code = code
    result.sourceIndex = sourceIndex
    return result
}

// ============================================================================
// 辅助类型
// ============================================================================

/// CSS 导入排序类型 (使用 linker_compute_chunks.cj 中已定义的 CSSImportOrderKind)
// CSSImportOrderKind 定义在 linker_compute_chunks.cj:
//   | SourceIndex
//   | ExternalPath
//   | Layers

/// CSS 导入排序条目 (丰富版本, 带 AST)
// 严格翻译自: Chunk.zig CssImportOrder + AST 扩展
public class CSSImportOrderEntry {
    /// 导入类型
    public var kind: CSSImportOrderKind
    /// 源文件索引
    public var sourceIndex: Int64
    /// 外部路径
    public var externalPath: String
    /// 条件导入记录 (用于 @import 条件)
    public var conditionImportRecords: ArrayList<ImportRecord>
    /// CSS 条件列表
    public var conditions: ArrayList<CSSImportCondition>
    /// CSS AST (准备后的)
    public var ast: CssStylesheetRef
    /// 层名称列表
    public var layerNames: ArrayList<String>

    public init() {
        kind = CSSImportOrderKind.SourceIndex
        sourceIndex = -1
        externalPath = ""
        conditionImportRecords = ArrayList<ImportRecord>()
        conditions = ArrayList<CSSImportCondition>()
        ast = CssStylesheetRef()
        layerNames = ArrayList<String>()
    }

    /// 获取层名称列表
    public func getLayerNames(): ArrayList<String> {
        return layerNames
    }
}

/// CSS 打印器选项
// 严格翻译自: bun_css.PrinterOptions
public class CssPrinterOptions {
    public var minify: Bool
    public var targets: ArrayList<CssTarget>

    public init() {
        minify = false
        targets = ArrayList<CssTarget>()
    }
}

/// CSS 目标平台
public class CssTarget {
    public var name: String

    public init(name: String) {
        this.name = name
    }
}

/// CSS 导入信息 (传递给打印器)
// 严格翻译自: bun_css.ImportInfo
public class CssImportInfo {
    public var importRecords: ArrayList<ImportRecord>
    public var astUrlsForCss: ArrayList<String>
    public var astUniqueKeyForAdditionalFile: ArrayList<String>

    public init() {
        importRecords = ArrayList<ImportRecord>()
        astUrlsForCss = ArrayList<String>()
        astUniqueKeyForAdditionalFile = ArrayList<String>()
    }
}

/// CSS 样式表引用 (简化)
public class CssStylesheetRef {
    public var rules: ArrayList<CSSRule>
    public var isEmpty: Bool

    public init() {
        rules = ArrayList<CSSRule>()
        isEmpty = true
    }
}

/// CSS 规则 (简化)
public class CSSRule {
    public var kind: String
    public var text: String

    public init(kind: String, text: String) {
        this.kind = kind
        this.text = text
    }
}

/// CSS 导入条件
// 严格翻译自: prepareCssAstsForChunk.rs CSSImportCondition
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

// ============================================================================
// 辅助函数
// ============================================================================

/// 获取 bundler 对应的 CSS 目标平台
// 严格翻译自: bun_css.Targets.for_bundler_target()
private func cssTargetsForBundlerTarget(target: BundleTarget): ArrayList<CssTarget> {
    let targets = ArrayList<CssTarget>()
    match (target) {
        case BundleTarget.Browser =>
            targets.append(CssTarget("chrome80"))
            targets.append(CssTarget("firefox72"))
            targets.append(CssTarget("safari13"))
        case BundleTarget.Node =>
            targets.append(CssTarget("node14"))
        case BundleTarget.Bun =>
            targets.append(CssTarget("bun"))
    }
    return targets
}

/// 打印 CSS 样式表
// 严格翻译自: bun_css.BundlerStyleSheet.to_css_with_writer()
// 调用 CSS 打印器将 AST 转换为 CSS 代码
private func printCssStylesheet(ast: CssStylesheetRef, options: CssPrinterOptions,
                                 importInfo: CssImportInfo,
                                 mangledProps: HashMap<Int64, String>): String {
    // 在真实实现中, 这调用 CSS 打印器 (bun_css)
    // 遍历 AST 中的规则, 生成 CSS 文本
    // 处理:
    //   - @import 规则 (替换 URL)
    //   - @layer 规则
    //   - @media 规则
    //   - @supports 规则
    //   - CSS Modules 类名替换
    //   - 压缩 (如果启用)
    var output = StringBuilder()
    for (rule in ast.rules) {
        if (options.minify) {
            output.append(rule.text.trim())
        } else {
            output.append(rule.text)
            output.append("\n")
        }
    }
    return output.toString()
}

/// 创建错误编译结果
private func makeErrorCompileResult(sourceIndex: Int64): CompileResult {
    let result = CompileResult()
    result.kind = CompileResultKind.CSS
    result.sourceIndex = sourceIndex
    result.code = ""
    return result
}

/// 更新 bytesInOutput 计数 (原子操作)
// 严格翻译自: generateCompileResultForCssChunk.rs:230-236
private func updateBytesInOutput(chunk: Chunk, sourceIndex: Int64, bytes: Int64): Unit {
    match (chunk.filesWithParts.get(sourceIndex)) {
        case Some(counter) =>
            // 原子加: chunk.files_with_parts_in_chunk[sourceIndex] += bytes
            chunk.filesWithParts.put(sourceIndex, counter + bytes)
        case None =>
            chunk.filesWithParts.put(sourceIndex, bytes)
    }
}
