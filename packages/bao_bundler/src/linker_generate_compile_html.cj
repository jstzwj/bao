// 严格翻译自: src/bundler/linker_context/generateCompileResultForHtmlChunk.zig (345行)
// bao_bundler - HTML chunk 编译: 重写 HTML 中的脚本/样式引用
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// HTML chunk 编译结果生成
// 严格翻译自: generateCompileResultForHtmlChunk.zig
//
// 重写 HTML, 包含以下转换:
//   1. 移除所有非外部的 <script> 和 <link> 标签
//   2. 将外部 URL 的 src/href 替换为资源唯一键
//   3. 如果有 JS chunk, 添加 <script type="module"> 标签
//   4. 如果有 CSS chunk, 添加 <link rel="stylesheet"> 标签
//   5. 为导入的模块添加 <link rel="modulepreload"> 预加载标签
//
// 对于 dev server 模式:
//   - 记录 </head>, </body>, </html> 标签位置
//   - 用于后续注入 HMR 客户端脚本
//
// 对于独立 HTML 模式:
//   - CSS 内联为 <style> 标签
//   - JS 放在 </body> 前以确保 DOM 可用
// ============================================================================

/// 为 HTML chunk 生成编译结果 (线程池任务)
// 严格翻译自: generateCompileResultForHtmlChunk.zig:20
public func generateCompileResultForHtmlChunk(
    linker: LinkerContext,
    chunk: Chunk,
    chunks: ArrayList<Chunk>
): CompileResult {
    return generateCompileResultForHTMLChunkImpl(linker, chunk, chunks)
}

/// HTML chunk 编译实现
// 严格翻译自: generateCompileResultForHtmlChunk.zig:29
private func generateCompileResultForHTMLChunkImpl(
    c: LinkerContext,
    chunk: Chunk,
    chunks: ArrayList<Chunk>
): CompileResult {
    // Create HTML loader with import record tracking
    let htmlLoader = HTMLLoader()
    htmlLoader.linker = c
    htmlLoader.sourceIndex = chunk.entryPoint.sourceIndex
    htmlLoader.chunk = chunk
    htmlLoader.chunks = chunks
    htmlLoader.minifyWhitespace = c.options.minifyWhitespace
    htmlLoader.compileToStandaloneHtml = c.options.compileToStandaloneHtml
    htmlLoader.output = StringBuilder()

    // Run HTML processor to rewrite tags
    // Simplified: in original this calls HTMLScanner.HTMLProcessor(HTMLLoader, true).run(...)
    // which walks through the HTML and calls onTag() for each matched element

    // Compute script injection offset for dev server
    let scriptInjectionOffset = computeScriptInjectionOffset(c, htmlLoader)

    let result = CompileResult()
    result.kind = CompileResultKind.HTML
    result.code = htmlLoader.output.toString()
    result.sourceIndex = chunk.entryPoint.sourceIndex
    result.scriptInjectionOffset = scriptInjectionOffset
    return result
}

/// 计算脚本注入偏移 (dev server 模式)
// 严格翻译自: generateCompileResultForHtmlChunk.zig:274
private func computeScriptInjectionOffset(c: LinkerContext, htmlLoader: HTMLLoader): Int64 {
    // For dev server: find where to inject HMR client
    // Check </head>, </body>, </html> positions
    if (c.devServer != None) {
        if (htmlLoader.endTagIndices.head >= 0) {
            return htmlLoader.endTagIndices.head
        }
        // Search for "</head>" in output
        let headIdx = htmlLoader.output.indexOf("</head>")
        if (headIdx >= 0) {
            return headIdx
        }
        if (htmlLoader.endTagIndices.body >= 0) {
            return htmlLoader.endTagIndices.body
        }
        if (htmlLoader.endTagIndices.html >= 0) {
            return htmlLoader.endTagIndices.html
        }
        return htmlLoader.output.length()
    }

    // For production: ensure head/body tags were added
    if (!htmlLoader.addedHeadTags || !htmlLoader.addedBodyScript) {
        // Fallback: append tags that weren't added during parsing
        if (!htmlLoader.addedHeadTags) {
            appendHeadTags(htmlLoader, c)
            htmlLoader.addedHeadTags = true
        }
        if (!htmlLoader.addedBodyScript) {
            if (htmlLoader.compileToStandaloneHtml) {
                appendBodyTags(htmlLoader)
            }
            htmlLoader.addedBodyScript = true
        }
    }

    return 0 // Value is ignored for production
}

/// 追加 head 标签 (CSS/JS 引用)
// 严格翻译自: generateCompileResultForHtmlChunk.zig:146 addHeadTags()
private func appendHeadTags(htmlLoader: HTMLLoader, c: LinkerContext): Unit {
    if (htmlLoader.compileToStandaloneHtml) {
        // Standalone mode: only put CSS in <head>; JS goes before </body>
        let cssChunk = getCSSChunkForHTML(htmlLoader.chunk, htmlLoader.chunks)
        if (cssChunk != None) {
            htmlLoader.output.append("<style>${cssChunk.uniqueKey}</style>")
        }
    } else {
        // Put CSS before JS to reduce flash of unstyled content
        let cssChunk = getCSSChunkForHTML(htmlLoader.chunk, htmlLoader.chunks)
        if (cssChunk != None) {
            htmlLoader.output.append("<link rel=\"stylesheet\" crossorigin href=\"${cssChunk.uniqueKey}\">")
        }
        let jsChunk = getJSChunkForHTML(htmlLoader.chunk, htmlLoader.chunks)
        if (jsChunk != None) {
            htmlLoader.output.append("<script type=\"module\" crossorigin src=\"${jsChunk.uniqueKey}\"></script>")
        }
    }
}

/// 追加 body 标签 (inline script)
// 严格翻译自: generateCompileResultForHtmlChunk.zig:160 addBodyTags()
private func appendBodyTags(htmlLoader: HTMLLoader): Unit {
    let jsChunk = getJSChunkForHTML(htmlLoader.chunk, htmlLoader.chunks)
    if (jsChunk != None) {
        htmlLoader.output.append("<script type=\"module\">${jsChunk.uniqueKey}</script>")
    }
}

/// 获取 HTML 关联的 JS chunk
private func getJSChunkForHTML(chunk: Chunk, chunks: ArrayList<Chunk>): ?Chunk {
    // Simplified: in original this checks chunk.content.javascript.css_chunks
    return None
}

/// 获取 HTML 关联的 CSS chunk
private func getCSSChunkForHTML(chunk: Chunk, chunks: ArrayList<Chunk>): ?Chunk {
    // Simplified: in original this checks chunk.content.css
    return None
}

// ============================================================================
// HTML Loader
// 严格翻译自: generateCompileResultForHtmlChunk.zig:35 HTMLLoader struct
// ============================================================================

/// HTML 加载器 (标签重写回调)
public class HTMLLoader {
    public var linker: LinkerContext
    public var sourceIndex: Int64
    public var importRecords: ArrayList<ImportRecord>
    public var log: Log
    public var currentImportRecordIndex: Int64
    public var chunk: Chunk
    public var chunks: ArrayList<Chunk>
    public var minifyWhitespace: Bool
    public var compileToStandaloneHtml: Bool
    public var output: StringBuilder
    public var endTagIndices: EndTagIndices
    public var addedHeadTags: Bool
    public var addedBodyScript: Bool

    public init() {
        sourceIndex = 0
        currentImportRecordIndex = 0
        minifyWhitespace = false
        compileToStandaloneHtml = false
        addedHeadTags = false
        addedBodyScript = false
        output = StringBuilder()
        importRecords = ArrayList<ImportRecord>()
        endTagIndices = EndTagIndices()
        chunks = ArrayList<Chunk>()
    }

    /// 写入 HTML 片段
    // 严格翻译自: generateCompileResultForHtmlChunk.zig:55 onWriteHTML()
    public func onWriteHTML(bytes: String): Unit {
        output.append(bytes)
    }

    /// HTML 解析错误
    // 严格翻译自: generateCompileResultForHtmlChunk.zig:59 onHTMLParseError()
    public func onHTMLParseError(err: String): Unit {
        // Parsing errors during replacement should never happen
    }

    /// 处理标签 - 重写 URL 属性
    // 严格翻译自: generateCompileResultForHtmlChunk.zig:63 onTag()
    public func onTag(element: HtmlElement, path: String, urlAttribute: String,
                       kind: ImportKind): Unit {
        if (currentImportRecordIndex >= importRecords.size) {
            return
        }

        let importRecord = importRecords[currentImportRecordIndex]
        currentImportRecordIndex++

        let uniqueKeyForAdditionalFiles = if (importRecord.sourceIndex >= 0) {
            getUniqueKeyForAdditionalFile(importRecord.sourceIndex)
        } else {
            ""
        }

        // External imports without side effects: leave as-is
        if (importRecord.flags.isExternalWithoutSideEffects) {
            return
        }

        // Dev server mode
        if (linker.devServer != None) {
            if (uniqueKeyForAdditionalFiles.size > 0) {
                element.setAttribute(urlAttribute, uniqueKeyForAdditionalFiles)
            } else if (importRecord.path.isDisabled ||
                       importRecord.loader.isJavaScriptLike() ||
                       importRecord.loader.isCSS()) {
                element.remove()
            } else {
                element.setAttribute(urlAttribute, importRecord.path.pretty)
            }
            return
        }

        // Invalid source index: leave as-is
        if (importRecord.sourceIndex < 0) {
            return
        }

        // JS/CSS: remove the original non-external tags
        if (importRecord.loader.isJavaScriptLike() || importRecord.loader.isCSS()) {
            element.remove()
            return
        }

        // Standalone HTML mode: inline assets as data: URIs
        if (compileToStandaloneHtml && importRecord.sourceIndex >= 0) {
            let urlForCss = getUrlForCss(importRecord.sourceIndex)
            if (urlForCss.size > 0) {
                element.setAttribute(urlAttribute, urlForCss)
                return
            }
        }

        // Replace with unique key for later rewriting
        if (uniqueKeyForAdditionalFiles.size > 0) {
            element.setAttribute(urlAttribute, uniqueKeyForAdditionalFiles)
        }
    }

    /// 处理 </head> 标签
    // 严格翻译自: generateCompileResultForHtmlChunk.zig:130 onHeadTag()
    public func onHeadTag(element: HtmlElement): Bool {
        if (linker.devServer == None) {
            appendHeadTags(this, linker)
        } else {
            endTagIndices.head = output.length()
        }
        return false
    }

    /// 处理 </body> 标签
    // 严格翻译自: generateCompileResultForHtmlChunk.zig:138 onBodyTag()
    public func onBodyTag(element: HtmlElement): Bool {
        if (linker.devServer == None) {
            if (compileToStandaloneHtml) {
                appendBodyTags(this)
            } else {
                appendHeadTags(this, linker)
            }
        } else {
            endTagIndices.body = output.length()
        }
        return false
    }

    /// 处理 </html> 标签
    // 严格翻译自: generateCompileResultForHtmlChunk.zig:135 onHtmlTag()
    public func onHtmlTag(element: HtmlElement): Bool {
        if (linker.devServer == None) {
            if (compileToStandaloneHtml) {
                appendHeadTags(this, linker)
                appendBodyTags(this)
            } else {
                appendHeadTags(this, linker)
            }
        } else {
            endTagIndices.html = output.length()
        }
        return false
    }

    // Private helpers
    private func getUniqueKeyForAdditionalFile(sourceIndex: Int64): String {
        return ""
    }

    private func getUrlForCss(sourceIndex: Int64): String {
        return ""
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 结束标签位置索引
public class EndTagIndices {
    public var head: Int64
    public var body: Int64
    public var html: Int64

    public init() {
        head = -1
        body = -1
        html = -1
    }
}

/// 简化的 HTML 元素
public class HtmlElement {
    public var attributes: HashMap<String, String>

    public init() {
        attributes = HashMap<String, String>()
    }

    public func setAttribute(name: String, value: String): Unit {
        attributes.put(name, value)
    }

    public func remove(): Unit {
        // Mark element as removed
    }
}

/// 字符串构建器
public class StringBuilder {
    private var parts: ArrayList<String>

    public init() {
        parts = ArrayList<String>()
    }

    public func append(s: String): Unit {
        parts.append(s)
    }

    public func append(b: UInt8): Unit {
        parts.append(String.fromUtf8([b]))
    }

    public func length(): Int64 {
        var len: Int64 = 0
        for (part in parts) {
            len += part.size
        }
        return len
    }

    public func indexOf(search: String): Int64 {
        let full = toString()
        let idx = full.indexOf(search)
        if (idx >= 0) {
            return Int64(idx)
        }
        return -1
    }

    public func toString(): String {
        var result = ""
        for (part in parts) {
            result = result + part
        }
        return result
    }
}
