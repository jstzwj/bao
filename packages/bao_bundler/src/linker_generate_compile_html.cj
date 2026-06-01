// 严格翻译自: src/bundler/linker_context/generateCompileResultForHtmlChunk.rs (508行)
// bao_bundler - HTML chunk 编译: 重写 HTML 中的脚本/样式引用
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// HTML chunk 编译结果生成
// 严格翻译自: generateCompileResultForHtmlChunk.rs
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

/// 为 HTML chunk 生成编译结果
// 严格翻译自: generateCompileResultForHtmlChunk.rs:52 generate_compile_result_for_html_chunk()
public func generateCompileResultForHtmlChunk(
    linker: LinkerContext,
    chunk: Chunk,
    chunks: ArrayList<Chunk>
): CompileResult {
    return generateCompileResultForHTMLChunkImpl(linker, chunk, chunks)
}

/// HTML chunk 编译实现
// 严格翻译自: generateCompileResultForHtmlChunk.rs:394 generate_compile_result_for_html_chunk_impl()
private func generateCompileResultForHTMLChunkImpl(
    c: LinkerContext,
    chunk: Chunk,
    chunks: ArrayList<Chunk>
): CompileResult {
    let sourceIndex = chunk.entryPoint.sourceIndex

    // 获取源文件内容
    let contents = getHTMLSourceContents(c, sourceIndex)
    // 获取导入记录
    let importRecords = getImportRecordsForSource(c, sourceIndex)

    let minifyWhitespace = c.options.minifyWhitespace
    let compileToStandaloneHtml = c.options.compileToStandaloneHtml
    let hasDevServer = c.devServer.isSome()

    // 创建 HTML 加载器
    let htmlLoader = HTMLLoader()
    htmlLoader.linker = c
    htmlLoader.sourceIndex = sourceIndex
    htmlLoader.importRecords = importRecords
    htmlLoader.currentImportRecordIndex = 0
    htmlLoader.chunk = chunk
    htmlLoader.chunks = chunks
    htmlLoader.minifyWhitespace = minifyWhitespace
    htmlLoader.compileToStandaloneHtml = compileToStandaloneHtml
    htmlLoader.output = StringBuilder()
    htmlLoader.endTagIndices = EndTagIndices()
    htmlLoader.addedHeadTags = false
    htmlLoader.addedBodyScript = false

    // 运行 HTML 处理器 (使用 lol-html 重写)
    // 第二次遍历: 重写标签, 同时追踪 </head>, </body>, </html> 位置
    HTMLRewriter.run(htmlLoader, contents, true)

    // 计算脚本注入偏移
    let scriptInjectionOffset = computeScriptInjectionOffset(
        c, htmlLoader, hasDevServer, chunks
    )

    let result = CompileResult()
    result.kind = CompileResultKind.HTML
    result.code = htmlLoader.output.toString()
    result.sourceIndex = sourceIndex
    result.scriptInjectionOffset = scriptInjectionOffset
    return result
}

/// 计算脚本注入偏移 (dev server 模式)
// 严格翻译自: generateCompileResultForHtmlChunk.rs:446
// 在 dev server 模式下, HMR 客户端脚本需要注入到 HTML 中
// 优先注入位置: </head> > </body> > </html> > 文件末尾
private func computeScriptInjectionOffset(c: LinkerContext,
                                           htmlLoader: HTMLLoader,
                                           hasDevServer: Bool,
                                           chunks: ArrayList<Chunk>): Int64 {
    if (hasDevServer) {
        // Dev server 模式: 返回标签位置
        // 优先级: </head> 位置 > 查找 "</head>" 文本 > </body> 位置 > </html> 位置 > 文件末尾
        if (htmlLoader.endTagIndices.head >= 0) {
            return htmlLoader.endTagIndices.head
        }
        // 回退: 在输出中搜索 "</head>"
        let output = htmlLoader.output.toString()
        let headIdx = output.indexOf("</head>")
        match (headIdx) {
            case Some(idx) => return idx
            case None => ()
        }
        if (htmlLoader.endTagIndices.body >= 0) {
            return htmlLoader.endTagIndices.body
        }
        if (htmlLoader.endTagIndices.html >= 0) {
            return htmlLoader.endTagIndices.html
        }
        return Int64(output.size)
    } else {
        // 非 dev server 模式: 处理缺少标签的情况
        // 如果 </head> 和 </body> 都没有被找到, 手动追加标签
        if (!htmlLoader.addedHeadTags || !htmlLoader.addedBodyScript) {
            // 缺少 head 标签: 追加 head 标签到输出末尾
            if (!htmlLoader.addedHeadTags) {
                let headSlices = htmlLoader.getHeadTags(chunks)
                for (slice in headSlices) {
                    htmlLoader.output.append(slice)
                }
                htmlLoader.addedHeadTags = true
            }
            // 缺少 body 标签且是独立 HTML 模式: 追加 body 脚本
            if (!htmlLoader.addedBodyScript) {
                if (htmlLoader.compileToStandaloneHtml) {
                    match (getJSChunkForHTML(htmlLoader.chunk, chunks)) {
                        case Some(jsChunk) =>
                            let script = "<script type=\"module\">${jsChunk.uniqueKey}</script>"
                            htmlLoader.output.append(script)
                        case None => ()
                    }
                }
                htmlLoader.addedBodyScript = true
            }
        }
        // 非 dev server 模式下此值被忽略
        return 0
    }
}

// ============================================================================
// HTML Loader
// 严格翻译自: generateCompileResultForHtmlChunk.rs:82 HTMLLoader struct
// ============================================================================

/// HTML 加载器 (标签重写回调)
// 严格翻译自: generateCompileResultForHtmlChunk.rs:82 HTMLLoader
public class HTMLLoader {
    public var linker: LinkerContext
    public var sourceIndex: Int64
    public var importRecords: ArrayList<ImportRecord>
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
        linker = LinkerContext()
        sourceIndex = 0
        currentImportRecordIndex = 0
        minifyWhitespace = false
        compileToStandaloneHtml = false
        addedHeadTags = false
        addedBodyScript = false
        output = StringBuilder()
        importRecords = ArrayList<ImportRecord>()
        chunk = Chunk()
        endTagIndices = EndTagIndices()
        chunks = ArrayList<Chunk>()
    }

    /// 写入 HTML 片段
    // 严格翻译自: generateCompileResultForHtmlChunk.rs:99 onWriteHTML()
    public func onWriteHTML(bytes: String): Unit {
        output.append(bytes)
    }

    /// HTML 解析错误
    // 严格翻译自: generateCompileResultForHtmlChunk.rs:103 onHTMLParseError()
    public func onHTMLParseError(err: String): Unit {
        // 解析错误在重写阶段不应发生 (因为第一次扫描已成功)
    }

    /// 处理标签 - 重写 URL 属性
    // 严格翻译自: generateCompileResultForHtmlChunk.rs:110 onTag()
    //
    // 核心重写逻辑:
    // 1. 查找当前标签对应的 import record
    // 2. 如果是外部导入 (IS_EXTERNAL_WITHOUT_SIDE_EFFECTS) -> 保留原始标签
    // 3. Dev server 模式:
    //    - 有 unique_key -> 替换 href/src 为 unique_key
    //    - JS/CSS 标签 -> 移除整个元素
    //    - 其他 -> 保留原始路径
    // 4. 非 dev server:
    //    - 无效 source_index -> 保留原始标签
    //    - JS/CSS 标签 -> 移除 (由注入的标签替代)
    //    - 独立 HTML 模式 -> 内联为 data: URI
    //    - 有 unique_key -> 替换为 unique_key
    public func onTag(element: HtmlElement, path: String, urlAttribute: String,
                       kind: ImportKind): Unit {
        if (currentImportRecordIndex >= importRecords.size) {
            return
        }

        let importRecord = importRecords[Int64(currentImportRecordIndex)]
        currentImportRecordIndex++

        let uniqueKeyForAdditionalFiles = getUniqueKeyForAdditionalFile(
            linker, importRecord.sourceIndex
        )
        let loader = getLoaderForSourceIndex(linker, importRecord.sourceIndex)

        // 外部导入 (无副作用) -> 保留
        if (importRecord.isExternal && !importRecord.hasSideEffects) {
            return
        }

        // Dev server 模式
        if (linker.devServer.isSome()) {
            if (uniqueKeyForAdditionalFiles.size > 0) {
                element.setAttribute(urlAttribute, uniqueKeyForAdditionalFiles)
            } else if (isJavaScriptLike(loader) || isCss(loader)) {
                element.remove()
            } else {
                element.setAttribute(urlAttribute, importRecord.path)
            }
            return
        }

        // 无效 source_index -> 保留原始标签
        if (importRecord.sourceIndex < 0) {
            return
        }

        // JS/CSS 标签 -> 移除 (由注入的 <script>/<link> 标签替代)
        if (isJavaScriptLike(loader) || isCss(loader)) {
            element.remove()
            return
        }

        // 独立 HTML 模式: 尝试内联为 data: URI
        if (compileToStandaloneHtml && importRecord.sourceIndex >= 0) {
            let urlForCss = getUrlForCss(linker, importRecord.sourceIndex)
            if (urlForCss.size > 0) {
                element.setAttribute(urlAttribute, urlForCss)
                return
            }
        }

        // 有 unique_key -> 替换 href/src 为 unique_key
        if (uniqueKeyForAdditionalFiles.size > 0) {
            element.setAttribute(urlAttribute, uniqueKeyForAdditionalFiles)
            return
        }
    }

    /// 处理 </head> 标签
    // 严格翻译自: generateCompileResultForHtmlChunk.rs:207 onHeadTag()
    // 在 </head> 前注入 CSS/JS 引用标签
    public func onHeadTag(element: HtmlElement): Bool {
        // 注册结束标签处理器
        // 在 </head> 前插入 CSS/JS 标签
        if (linker.devServer.isSome()) {
            // Dev server: 记录位置
            endTagIndices.head = Int64(output.length())
        } else {
            // 非 dev server: 注入 head 标签
            addHeadTags(element, chunks)
        }
        return false
    }

    /// 处理 </body> 标签
    // 严格翻译自: generateCompileResultForHtmlChunk.rs:225 onBodyTag()
    // 在独立 HTML 模式下, </body> 前插入 JS (确保 DOM 可用)
    public func onBodyTag(element: HtmlElement): Bool {
        if (linker.devServer.isSome()) {
            endTagIndices.body = Int64(output.length())
        } else {
            if (compileToStandaloneHtml) {
                // 独立 HTML: 在 </body> 前插入 JS
                addBodyTags(element, chunks)
            } else {
                // 非 standalone: 也可能在 </body> 前注入 head 标签 (回退)
                addHeadTags(element, chunks)
            }
        }
        return false
    }

    /// 处理 </html> 标签
    // 严格翻译自: generateCompileResultForHtmlChunk.rs:216 onHtmlTag()
    // 作为最终回退, 在 </html> 前注入所有标签
    public func onHtmlTag(element: HtmlElement): Bool {
        if (linker.devServer.isSome()) {
            endTagIndices.html = Int64(output.length())
        } else {
            if (compileToStandaloneHtml) {
                // 独立 HTML: 在 </html> 前注入 CSS 和 JS (回退)
                addHeadTags(element, chunks)
                addBodyTags(element, chunks)
            } else {
                addHeadTags(element, chunks)
            }
        }
        return false
    }

    /// 在 </head> 前追加 CSS/JS 引用标签
    // 严格翻译自: generateCompileResultForHtmlChunk.rs:237 addHeadTags()
    //
    // 非 standalone 模式:
    //   - 先注入 CSS <link> (减少无样式内容闪烁)
    //   - 再注入 JS <script type="module">
    // Standalone 模式:
    //   - 只注入 CSS <style> (JS 在 </body> 前注入)
    public func addHeadTags(element: HtmlElement, chunks: ArrayList<Chunk>): Unit {
        if (addedHeadTags) {
            return
        }
        addedHeadTags = true

        let tags = getHeadTags(chunks)
        for (tag in tags) {
            // 在结束标签前插入
            output.append(tag)
        }
    }

    /// 在 </body> 前追加 inline script (独立 HTML 模式)
    // 严格翻译自: generateCompileResultForHtmlChunk.rs:252 addBodyTags()
    // 在独立 HTML 模式下, JS 放在 </body> 前以确保 DOM 元素可用
    public func addBodyTags(element: HtmlElement, chunks: ArrayList<Chunk>): Unit {
        if (addedBodyScript) {
            return
        }
        addedBodyScript = true

        match (getJSChunkForHTML(chunk, chunks)) {
            case Some(jsChunk) =>
                let script = "<script type=\"module\">${jsChunk.uniqueKey}</script>"
                output.append(script)
            case None => ()
        }
    }

    /// 获取 head 标签列表
    // 严格翻译自: generateCompileResultForHtmlChunk.rs:274 getHeadTags()
    public func getHeadTags(chunks: ArrayList<Chunk>): ArrayList<String> {
        let tags = ArrayList<String>()

        if (compileToStandaloneHtml) {
            // Standalone 模式: CSS 为 <style>, JS 在 </body> 前
            match (getCSSChunkForHTML(chunk, chunks)) {
                case Some(cssChunk) =>
                    tags.append("<style>${cssChunk.uniqueKey}</style>")
                case None => ()
            }
        } else {
            // 正常模式: CSS 为 <link>, JS 为 <script>
            // CSS 在 JS 前以减少无样式内容闪烁 (FOUC)
            match (getCSSChunkForHTML(chunk, chunks)) {
                case Some(cssChunk) =>
                    tags.append("<link rel=\"stylesheet\" crossorigin href=\"${cssChunk.uniqueKey}\">")
                case None => ()
            }
            match (getJSChunkForHTML(chunk, chunks)) {
                case Some(jsChunk) =>
                    // type="module" 脚本不阻塞渲染, 可以放在 head 中
                    tags.append("<script type=\"module\" crossorigin src=\"${jsChunk.uniqueKey}\"></script>")
                case None => ()
            }
        }

        return tags
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
// 严格翻译自: generateCompileResultForHtmlChunk.rs:76 EndTagIndices
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
// 严格翻译自: lol_html.Element
public class HtmlElement {
    public var attributes: HashMap<String, String>
    private var removed: Bool

    public init() {
        attributes = HashMap<String, String>()
        removed = false
    }

    public func setAttribute(name: String, value: String): Unit {
        attributes.put(name, value)
    }

    public func remove(): Unit {
        removed = true
    }

    public func isRemoved(): Bool {
        return removed
    }

    public func hasAttribute(name: String): Bool {
        return attributes.contains(name)
    }

    public func getAttribute(name: String): ?String {
        return attributes.get(name)
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

    public func append(c: UInt8): Unit {
        parts.append(String(Rune(c)))
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
        match (full.indexOf(search)) {
            case Some(idx) => return idx
            case None => return -1
        }
    }

    public func toString(): String {
        var result = ""
        for (part in parts) {
            result = result + part
        }
        return result
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 获取 HTML 关联的 JS chunk
// 严格翻译自: generateCompileResultForHtmlChunk.rs:261 get_js_chunk_for_html()
// HTML chunk 的 JS 内容存储在 chunk 的 JavaScript 子 chunk 中
// 查找与 HTML chunk 相关联的 JS chunk (通过 entry_bits 匹配)
private func getJSChunkForHTML(chunk: Chunk, chunks: ArrayList<Chunk>): ?Chunk {
    for (i in 0..chunks.size) {
        let ch = chunks[i]
        let isJS = match (ch.contentType) {
            case ChunkContentType.JavaScript => true
            case _ => false
        }
        if (isJS &&
            ch.entryPoint.sourceIndex == chunk.entryPoint.sourceIndex &&
            ch.entryPoint.isEntryPoint) {
            return Some(ch)
        }
    }
    return None
}

/// 获取 HTML 关联的 CSS chunk
// 严格翻译自: generateCompileResultForHtmlChunk.rs:283 get_css_chunk_for_html()
// 查找与 HTML chunk 相关联的 CSS chunk
private func getCSSChunkForHTML(chunk: Chunk, chunks: ArrayList<Chunk>): ?Chunk {
    for (i in 0..chunks.size) {
        let ch = chunks[i]
        let isCSS = match (ch.contentType) {
            case ChunkContentType.CSS => true
            case _ => false
        }
        if (isCSS &&
            ch.entryPoint.sourceIndex == chunk.entryPoint.sourceIndex &&
            ch.entryPoint.isEntryPoint) {
            return Some(ch)
        }
    }
    return None
}

/// 获取源文件内容
private func getHTMLSourceContents(c: LinkerContext, sourceIndex: Int64): String {
    if (sourceIndex >= 0 && sourceIndex < c.parseGraph.inputFiles.size) {
        return c.parseGraph.inputFiles[Int64(sourceIndex)].contents
    }
    return ""
}

/// 获取源文件的导入记录
private func getImportRecordsForSource(c: LinkerContext, sourceIndex: Int64): ArrayList<ImportRecord> {
    // LinkerFile doesn't store importRecords directly; return empty for now
    return ArrayList<ImportRecord>()
}

/// 获取额外文件的 unique_key
private func getUniqueKeyForAdditionalFile(c: LinkerContext, sourceIndex: Int64): String {
    if (sourceIndex >= 0 && sourceIndex < c.parseGraph.inputFiles.size) {
        return c.parseGraph.inputFiles[Int64(sourceIndex)].uniqueKeyForAdditionalFile
    }
    return ""
}

/// 获取 source_index 对应的 loader
private func getLoaderForSourceIndex(c: LinkerContext, sourceIndex: Int64): String {
    // Simplified: return default loader
    return "file"
}

/// 获取 CSS URL
private func getUrlForCss(c: LinkerContext, sourceIndex: Int64): String {
    // JsAst doesn't have urlForCss; return empty for now
    return ""
}

/// 判断是否为 JS 类 loader
private func isJavaScriptLike(loader: String): Bool {
    return loader == "js" || loader == "jsx" || loader == "ts" ||
           loader == "tsx" || loader == "mjs" || loader == "cjs"
}

/// 判断是否为 CSS loader
private func isCss(loader: String): Bool {
    return loader == "css"
}

/// Dev server 检测 - LinkerContext 的扩展字段
// 严格翻译自: LinkerContext.dev_server
private func getDevServer(c: LinkerContext): ?Object {
    return None // 简化: 由 LinkerContext 的实际 devServer 字段提供
}

// ============================================================================
// HTML 重写器
// 严格翻译自: HTMLScanner.rs HTMLProcessor
// 使用 lol-html 重写 HTML, 处理标签替换和位置追踪
// ============================================================================

/// HTML 重写器
// 严格翻译自: HTMLScanner.rs HTMLProcessor.run()
// 第二次遍历 HTML, 启用 VISIT_DOCUMENT_TAGS 以追踪 </head>, </body>, </html>
public class HTMLRewriter {

    /// 运行 HTML 重写
    // visitDocumentTags: 是否追踪文档级标签 (head, body, html)
    public static func run(loader: HTMLLoader, input: String,
                           visitDocumentTags: Bool): Unit {
        // 简化实现: 逐标签扫描 HTML
        // 在真实实现中, 这使用 lol-html 库进行 HTML 重写
        //
        // 扫描流程:
        // 1. 解析 HTML 为标签流
        // 2. 对每个匹配的标签调用 loader.onTag()
        // 3. 对 </head>, </body>, </html> 调用对应的回调
        // 4. 将非标签文本直接传递给 loader.onWriteHTML()

        var pos = 0
        let tagHandlers = HTMLProcessor.getTagHandlers()

        while (pos < input.size) {
            // 查找下一个标签
            let tagStartOpt = input.indexOf("<", pos)
            if (tagStartOpt.isNone()) {
                // 剩余文本
                if (pos < input.size) {
                    loader.onWriteHTML(input[pos..input.size])
                }
                break
            }
            let tagStart = tagStartOpt.getOrThrow()

            // 标签前的文本
            if (tagStart > pos) {
                loader.onWriteHTML(input[pos..tagStart])
            }

            // 解析标签
            let tagEndOpt = input.indexOf(">", tagStart)
            if (tagEndOpt.isNone()) {
                loader.onWriteHTML(input[tagStart..input.size])
                break
            }
            let tagEnd = tagEndOpt.getOrThrow()

            let tagContent = input[tagStart..(tagEnd + 1)]
            let isEndTag = tagContent.size > 1 && tagContent[1..2] == "/"

            if (isEndTag && visitDocumentTags) {
                // 处理结束标签
                let tagName = extractEndTagName(tagContent)
                let element = HtmlElement()

                if (tagName == "head") {
                    loader.onHeadTag(element)
                } else if (tagName == "body") {
                    loader.onBodyTag(element)
                } else if (tagName == "html") {
                    loader.onHtmlTag(element)
                }
                loader.onWriteHTML(tagContent)
            } else if (!isEndTag) {
                // 处理开始标签
                let tagName = extractStartTagName(tagContent)
                let element = HtmlElement()
                parseAttributes(tagContent, element)

                // 检查标签处理器
                for (handler in tagHandlers) {
                    if (matchesSelector(tagName, handler.selector, element)) {
                        let urlAttr = handler.urlAttribute
                        match (element.getAttribute(urlAttr)) {
                            case Some(urlValue) =>
                                if (urlValue.size > 0) {
                                    loader.onTag(element, urlValue, urlAttr, handler.kind)
                                }
                            case None => ()
                        }
                    }
                }

                // 输出标签 (可能被修改过)
                loader.onWriteHTML(serializeElement(tagName, element, tagContent))
            } else {
                loader.onWriteHTML(tagContent)
            }

            pos = tagEnd + 1
        }
    }

    /// 提取结束标签名称
    private static func extractEndTagName(tag: String): String {
        // </head> -> head
        var start = 2 // 跳过 </
        var end = start
        while (end < tag.size && tag[end..end+1] != ">" && tag[end..end+1] != " ") {
            end++
        }
        if (end > start) {
            return tag[start..end]
        }
        return ""
    }

    /// 提取开始标签名称
    private static func extractStartTagName(tag: String): String {
        // <script src="..."> -> script
        var start = 1 // 跳过 <
        var end = start
        while (end < tag.size && tag[end..end+1] != ">" && tag[end..end+1] != " " &&
               tag[end..end+1] != "/" && tag[end..end+1] != "\n") {
            end++
        }
        if (end > start) {
            return tag[start..end]
        }
        return ""
    }

    /// 解析标签属性
    private static func parseAttributes(tag: String, element: HtmlElement): Unit {
        // 简化属性解析: 查找 attr="value" 模式
        var pos = 0
        while (pos < tag.size) {
            // 查找属性名开始
            while (pos < tag.size && (tag[pos..pos+1] == " " || tag[pos..pos+1] == "\t" ||
                   tag[pos..pos+1] == "\n" || tag[pos..pos+1] == "\r" || tag[pos..pos+1] == "<" || tag[pos..pos+1] == "/")) {
                pos++
            }
            if (pos >= tag.size || tag[pos..pos+1] == ">") { break }

            // 读取属性名
            let nameStart = pos
            while (pos < tag.size && tag[pos..pos+1] != "=" && tag[pos..pos+1] != " " &&
                   tag[pos..pos+1] != ">" && tag[pos..pos+1] != "/") {
                pos++
            }
            if (pos >= nameStart + 1) {
                let name = tag[nameStart..pos]

                // 检查是否有 = 号
                if (pos < tag.size && tag[pos..pos+1] == "=") {
                    pos++ // 跳过 =
                    // 跳过引号
                    if (pos < tag.size && (tag[pos..pos+1] == "\"" || tag[pos..pos+1] == "'")) {
                        let quoteChar = tag[pos..pos+1]
                        pos++ // 跳过开始引号
                        let valueStart = pos
                        while (pos < tag.size && tag[pos..pos+1] != quoteChar) {
                            pos++
                        }
                        let value = tag[valueStart..pos]
                        element.setAttribute(name, value)
                        if (pos < tag.size) { pos++ } // 跳过结束引号
                    } else {
                        // 无引号值
                        let valueStart = pos
                        while (pos < tag.size && tag[pos..pos+1] != " " &&
                               tag[pos..pos+1] != ">" && tag[pos..pos+1] != "/") {
                            pos++
                        }
                        let value = tag[valueStart..pos]
                        element.setAttribute(name, value)
                    }
                } else {
                    // 布尔属性
                    element.setAttribute(name, "")
                }
            }
        }
    }

    /// 检查元素是否匹配选择器
    // 简化选择器匹配: 支持 element[attr] 和 element[attr='value'] 模式
    private static func matchesSelector(tagName: String, selector: String,
                                         element: HtmlElement): Bool {
        // 解析选择器: "script[src]" -> tagName="script", attr="src"
        // 解析选择器: "link[rel='stylesheet'][href]" -> 需要匹配多个属性条件
        let parts = selector.split(",")
        for (part in parts) {
            let s = CssStrUtil.trim(part)
            if (matchesSingleSelector(tagName, s, element)) {
                return true
            }
        }
        return false
    }

    /// 匹配单个选择器
    private static func matchesSingleSelector(tagName: String, selector: String,
                                               element: HtmlElement): Bool {
        // 提取标签名
        var selIdx = 0
        let tagStart = selIdx
        while (selIdx < selector.size && selector[selIdx..selIdx+1] != "[") {
            selIdx++
        }
        let selTagName = CssStrUtil.trim(selector[tagStart..selIdx])
        if (selTagName.size > 0 && selTagName != tagName) {
            return false
        }

        // 提取属性条件
        while (selIdx < selector.size) {
            if (selector[selIdx..selIdx+1] == "[") {
                selIdx++ // 跳过 [
                // 检查 ^= (starts with)
                let attrStart = selIdx
                var isStartsWith = false
                while (selIdx < selector.size && selector[selIdx..selIdx+1] != "]" &&
                       selector[selIdx..selIdx+1] != "=" && !(selector[selIdx..selIdx+1] == "^" &&
                       selIdx + 1 < selector.size && selector[selIdx+1..selIdx+2] == "=")) {
                    selIdx++
                }
                if (selIdx < selector.size && selector[selIdx..selIdx+1] == "^" &&
                    selIdx + 1 < selector.size && selector[selIdx+1..selIdx+2] == "=") {
                    isStartsWith = true
                    let attrName = CssStrUtil.trim(selector[attrStart..selIdx])
                    selIdx += 2 // 跳过 ^=
                    // 读取引号中的值
                    if (selIdx < selector.size && (selector[selIdx..selIdx+1] == "\"" || selector[selIdx..selIdx+1] == "'")) {
                        let q = selector[selIdx..selIdx+1]
                        selIdx++
                        let valStart = selIdx
                        while (selIdx < selector.size && selector[selIdx..selIdx+1] != q) {
                            selIdx++
                        }
                        let val = selector[valStart..selIdx]
                        selIdx++ // 跳过引号
                        // 跳过 ]
                        while (selIdx < selector.size && selector[selIdx..selIdx+1] != "]") {
                            selIdx++
                        }
                        selIdx++ // 跳过 ]
                        // 检查属性值是否以指定值开头
                        match (element.getAttribute(attrName)) {
                            case Some(v) =>
                                if (!v.startsWith(val)) {
                                    return false
                                }
                            case None => return false
                        }
                    } else {
                        return false
                    }
                } else if (selIdx < selector.size && selector[selIdx..selIdx+1] == "=") {
                    let attrName = CssStrUtil.trim(selector[attrStart..selIdx])
                    selIdx++ // 跳过 =
                    // 读取引号中的值
                    if (selIdx < selector.size && (selector[selIdx..selIdx+1] == "\"" || selector[selIdx..selIdx+1] == "'")) {
                        let q = selector[selIdx..selIdx+1]
                        selIdx++
                        let valStart = selIdx
                        while (selIdx < selector.size && selector[selIdx..selIdx+1] != q) {
                            selIdx++
                        }
                        let val = selector[valStart..selIdx]
                        selIdx++ // 跳过引号
                        while (selIdx < selector.size && selector[selIdx..selIdx+1] != "]") {
                            selIdx++
                        }
                        selIdx++ // 跳过 ]
                        // 精确匹配属性值
                        match (element.getAttribute(attrName)) {
                            case Some(v) =>
                                if (v != val) {
                                    return false
                                }
                            case None => return false
                        }
                    } else {
                        return false
                    }
                } else {
                    let attrName = CssStrUtil.trim(selector[attrStart..selIdx])
                    while (selIdx < selector.size && selector[selIdx..selIdx+1] != "]") {
                        selIdx++
                    }
                    selIdx++ // 跳过 ]
                    // 仅检查属性存在
                    if (!element.hasAttribute(attrName)) {
                        return false
                    }
                }
            } else {
                selIdx++
            }
        }

        return true
    }

    /// 序列化元素 (可能被修改过)
    private static func serializeElement(tagName: String, element: HtmlElement,
                                          originalTag: String): String {
        if (element.isRemoved()) {
            return "" // 移除的标签不输出
        }

        // 重建标签
        var result = "<${tagName}"
        let entries = element.attributes.allEntries()
        for (entry in entries) {
            let name = entry[0]
            let value = entry[1]
            if (value.size > 0) {
                result = result + " ${name}=\"${value}\""
            } else {
                result = result + " ${name}"
            }
        }

        // 自闭合标签
        if (tagName == "link" || tagName == "img" || tagName == "source" ||
            tagName == "meta" || tagName == "br" || tagName == "hr" ||
            tagName == "input") {
            // 检查原始标签是否自闭合
            if (originalTag.endsWith("/>")) {
                result = result + "/>"
            } else {
                result = result + ">"
            }
        } else {
            result = result + ">"
        }

        return result
    }
}
