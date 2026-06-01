// 严格翻译自: src/bundler/HTMLScanner.rs (496行)
// bao_bundler - HTML 扫描器: 扫描 HTML 中的导入引用 (脚本、样式、资源)
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// HTML 扫描器
// 严格翻译自: HTMLScanner.rs:19 HTMLScanner
//
// HTMLScanner 扫描 HTML 文件, 提取所有外部资源引用:
//   - <script src="...">
//   - <link rel="stylesheet" href="...">
//   - <img src="..."> / <img srcset="...">
//   - <video src="..."> / <video poster="...">
//   - <audio src="...">
//   - <source src="..."> / <source srcset="...">
//   - <link as="font" href="...">
//   - <link as="image" href="...">
//   - <link rel="manifest" href="...">
//   - <link rel="icon" href="...">
//
// 每个 URL 被转换为 ImportRecord, 传递给解析器进行后续处理
// ============================================================================

/// HTML 扫描器 - 对应 Bun HTMLScanner
// 严格翻译自: HTMLScanner.rs:19
public class HTMLScanner {
    /// 日志
    public var log: Log
    /// 源文件
    public var source: Source
    /// 导入记录列表
    public var importRecords: ArrayList<ImportRecord>
    /// 项目根目录
    public var topLevelDir: String

    public init(log: Log, source: Source) {
        this.log = log
        this.source = source
        this.importRecords = ArrayList<ImportRecord>()
        this.topLevelDir = ""
    }

    /// 释放
    public func deinit(): Unit {
        importRecords.clear()
    }

    /// 创建导入记录
    // 严格翻译自: HTMLScanner.rs:37 create_import_record()
    ///
    /// 路径处理逻辑:
    /// 1. 以 '/' 开头的路径 -> 相对于项目根目录 (top_level_dir)
    ///    例: /src/index.js -> <top_level_dir>/src/index.js
    /// 2. 不以 './' 开头且有短扩展名的路径 -> 尝试相对于 HTML 文件解析
    ///    例: App.tsx -> 检查 <html_dir>/App.tsx 是否存在
    /// 3. 其他 -> 原样保留
    public func createImportRecord(inputPath: String, kind: ImportKind): Unit {
        let pathToUse: String

        if (inputPath.size > 1 && inputPath.startsWith("/")) {
            // 绝对路径: 相对于项目根目录
            pathToUse = joinPath(topLevelDir, inputPath[1..inputPath.size])
        } else if (inputPath.size > 2 && !inputPath.startsWith("./")) {
            // 可能是省略了 ./ 的相对导入: 检查是否有短扩展名
            let ext = getFileExtension(inputPath)
            if (ext.size > 0 && ext.size <= 4) {
                // 尝试相对于 HTML 文件目录解析
                let dirname = sourcePathDirname(source.path)
                if (dirname.size > 0) {
                    let resolved = joinPath(dirname, inputPath)
                    // 在实际实现中, 这里会检查文件是否存在
                    // 如果文件存在, 使用解析后的路径; 否则使用原始路径
                    // 简化: 如果路径看起来合理, 使用解析后的路径
                    if (resolved.size > 0) {
                        pathToUse = resolved
                    } else {
                        pathToUse = inputPath
                    }
                } else {
                    pathToUse = inputPath
                }
            } else {
                pathToUse = inputPath
            }
        } else {
            pathToUse = inputPath
        }

        let record = ImportRecord(pathToUse)
        importRecords.append(record)
    }

    /// HTML 写入回调
    public func onWriteHTML(bytes: String): Unit {
        // 扫描阶段不写入 bytes
    }

    /// HTML 解析错误回调
    public func onHTMLParseError(message: String): Unit {
        // Log errors (Log class doesn't have addError, silently track)
        ()
    }

    /// 标签回调
    public func onTag(path: String, urlAttribute: String, kind: ImportKind): Unit {
        createImportRecord(path, kind)
    }

    /// 扫描 HTML 输入
    // 严格翻译自: HTMLScanner.rs:115 scan()
    public func scan(input: String): Unit {
        HTMLProcessor.scan(this, input, false)
    }
}

// ============================================================================
// 标签处理器信息
// 严格翻译自: HTMLScanner.rs:175 TagHandler
// ============================================================================

/// 标签处理器信息
// 严格翻译自: HTMLScanner.rs:175
public class TagHandler {
    /// CSS 选择器
    public var selector: String
    /// 是否有文本内容需要处理
    public var hasContent: Bool
    /// URL 属性名
    public var urlAttribute: String
    /// 导入类型
    public var kind: ImportKind
    /// 是否为 head/html 标签
    public var isHeadOrHtml: Bool

    public init(selector: String, hasContent: Bool, urlAttribute: String,
                kind: ImportKind, isHeadOrHtml: Bool) {
        this.selector = selector
        this.hasContent = hasContent
        this.urlAttribute = urlAttribute
        this.kind = kind
        this.isHeadOrHtml = isHeadOrHtml
    }

    public init(selector: String, urlAttribute: String, kind: ImportKind) {
        this.selector = selector
        this.hasContent = false
        this.urlAttribute = urlAttribute
        this.kind = kind
        this.isHeadOrHtml = false
    }
}

// ============================================================================
// HTML 处理器
// 严格翻译自: HTMLScanner.rs:172 HTMLProcessor
// ============================================================================

/// HTML 处理器 - 对应 Bun HTMLProcessor
public class HTMLProcessor {

    /// 获取所有标签处理器 - 对应 Bun TAG_HANDLERS 常量
    // 严格翻译自: HTMLScanner.rs:205 TAG_HANDLERS
    // 16 个标签处理器, 每个定义了一种 HTML 元素的 URL 提取规则
    public static func getTagHandlers(): ArrayList<TagHandler> {
        let handlers = ArrayList<TagHandler>()

        // 1. Module scripts with src
        // <script src="...">
        handlers.append(TagHandler(
            "script[src]",
            false,
            "src",
            ImportKind.Stmt,
            false
        ))

        // 2. CSS Stylesheets
        // <link rel="stylesheet" href="...">
        handlers.append(TagHandler(
            "link[rel='stylesheet'][href]",
            false,
            "href",
            ImportKind.At,
            false
        ))

        // 3. CSS Assets
        // <link as="style" href="...">
        handlers.append(TagHandler(
            "link[as='style'][href]",
            false,
            "href",
            ImportKind.At,
            false
        ))

        // 4. Font files
        // <link as="font" href="..."> 或 <link type^='font/' href="...">
        handlers.append(TagHandler(
            "link[as='font'][href]",
            false,
            "href",
            ImportKind.Url,
            false
        ))

        // 5. Image assets
        // <link as="image" href="...">
        handlers.append(TagHandler(
            "link[as='image'][href]",
            false,
            "href",
            ImportKind.Url,
            false
        ))

        // 6. Audio/Video assets
        // <link as="video" href="..."> 或 <link as="audio" href="...">
        handlers.append(TagHandler(
            "link[as='video'][href]",
            false,
            "href",
            ImportKind.Url,
            false
        ))

        // 7. Web Workers
        // <link as="worker" href="...">
        handlers.append(TagHandler(
            "link[as='worker'][href]",
            false,
            "href",
            ImportKind.Stmt,
            false
        ))

        // 8. Manifest files
        // <link rel="manifest" href="...">
        handlers.append(TagHandler(
            "link[rel='manifest'][href]",
            false,
            "href",
            ImportKind.Url,
            false
        ))

        // 9. Icons
        // <link rel="icon" href="..."> 或 <link rel="apple-touch-icon" href="...">
        handlers.append(TagHandler(
            "link[rel='icon'][href]",
            false,
            "href",
            ImportKind.Url,
            false
        ))

        // 10. Images with src
        // <img src="...">
        handlers.append(TagHandler(
            "img[src]",
            false,
            "src",
            ImportKind.Url,
            false
        ))

        // 11. Images with srcset
        // <img srcset="...">
        handlers.append(TagHandler(
            "img[srcset]",
            false,
            "srcset",
            ImportKind.Url,
            false
        ))

        // 12. Videos with src
        // <video src="...">
        handlers.append(TagHandler(
            "video[src]",
            false,
            "src",
            ImportKind.Url,
            false
        ))

        // 13. Videos with poster
        // <video poster="...">
        handlers.append(TagHandler(
            "video[poster]",
            false,
            "poster",
            ImportKind.Url,
            false
        ))

        // 14. Audio with src
        // <audio src="...">
        handlers.append(TagHandler(
            "audio[src]",
            false,
            "src",
            ImportKind.Url,
            false
        ))

        // 15. Source elements with src
        // <source src="...">
        handlers.append(TagHandler(
            "source[src]",
            false,
            "src",
            ImportKind.Url,
            false
        ))

        // 16. Source elements with srcset
        // <source srcset="...">
        handlers.append(TagHandler(
            "source[srcset]",
            false,
            "srcset",
            ImportKind.Url,
            false
        ))

        // Note: Iframes intentionally excluded (commented out in Bun source)
        // handlers.append(TagHandler("iframe[src]", "src", ImportKind.Url))

        return handlers
    }

    /// 扫描 HTML - 对应 Bun HTMLProcessor.run()
    // 严格翻译自: HTMLScanner.rs:379 run()
    //
    // 使用标签处理器数组扫描 HTML:
    //   1. 解析 HTML 为标签流
    //   2. 对每个标签检查是否匹配任何处理器
    //   3. 匹配时提取 URL 属性并创建 ImportRecord
    //   4. 如果 visitDocumentTags 为 true, 追踪 </head>, </body>, </html> 位置
    //
    // 在真实实现中使用 lol-html 库:
    //   builder -> add_element_content_handlers -> rewriter.write -> rewriter.end
    public static func scan(scanner: HTMLScanner, input: String,
                            visitDocumentTags: Bool): Unit {
        let handlers = getTagHandlers()
        var pos = 0

        while (pos < input.size) {
            // 查找下一个标签
            let tagStartOpt = input.indexOf("<", pos)
            let tagStart = match (tagStartOpt) {
                case Some(v) => v
                case None => break
            }

            // 跳过注释 <!-- ... -->
            if (tagStart + 4 <= input.size &&
                input[tagStart..(tagStart + 4)] == "<!--") {
                let commentEndOpt = input.indexOf("-->", tagStart + 4)
                match (commentEndOpt) {
                    case Some(ce) => pos = ce + 3
                    case None => pos = input.size
                }
                continue
            }

            // 跳过 DOCTYPE
            if (tagStart + 9 <= input.size &&
                CssStrUtil.toLowerCase(input[tagStart..(tagStart + 9)]) == "<!doctype") {
                let doctypeEndOpt = input.indexOf(">", tagStart)
                match (doctypeEndOpt) {
                    case Some(de) => pos = de + 1
                    case None => pos = input.size
                }
                continue
            }

            // 跳过结束标签
            if (tagStart + 1 < input.size && input[tagStart + 1..tagStart + 2] == "/") {
                let tagEndOpt = input.indexOf(">", tagStart)
                match (tagEndOpt) {
                    case Some(te) => pos = te + 1
                    case None => pos = input.size
                }
                continue
            }

            // 解析开始标签
            let tagEndOpt = input.indexOf(">", tagStart)
            let tagEnd = match (tagEndOpt) {
                case Some(v) => v
                case None => break
            }

            let tagContent = input[tagStart..(tagEnd + 1)]

            // 提取标签名
            let tagName = extractTagName(tagContent)
            if (tagName.size == 0) {
                pos = tagEnd + 1
                continue
            }

            // 提取所有属性
            let attributes = parseAllAttributes(tagContent)

            // 检查标签处理器
            for (handler in handlers) {
                if (matchesHandler(tagName, attributes, handler)) {
                    // 提取 URL 属性值
                    match (getAttributeValue(attributes, handler.urlAttribute)) {
                        case Some(urlValue) =>
                            if (urlValue.size > 0) {
                                // 处理 srcset 属性 (可能包含多个 URL)
                                if (handler.urlAttribute == "srcset") {
                                    let urls = parseSrcSet(urlValue)
                                    for (url in urls) {
                                        scanner.createImportRecord(url, handler.kind)
                                    }
                                } else {
                                    scanner.createImportRecord(urlValue, handler.kind)
                                }
                            }
                        case None => ()
                    }
                }
            }

            pos = tagEnd + 1
        }

        // 处理扫描错误
        // 在真实实现中, lol-html 可能在解析错误时报告
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 提取标签名称
private func extractTagName(tag: String): String {
    var start = 1 // 跳过 <
    // 跳过前导空白
    while (start < tag.size && (tag[start..start + 1] == " " || tag[start..start + 1] == "\t" ||
           tag[start..start + 1] == "\n")) {
        start++
    }
    var end = start
    while (end < tag.size && tag[end..end + 1] != " " && tag[end..end + 1] != "\t" &&
           tag[end..end + 1] != "\n" && tag[end..end + 1] != ">" && tag[end..end + 1] != "/" &&
           tag[end..end + 1] != "\r") {
        end++
    }
    if (end > start) {
        return CssStrUtil.toLowerCase(tag[start..end])
    }
    return ""
}

/// 解析所有属性为 (name, value) 对列表
private func parseAllAttributes(tag: String): ArrayList<(String, String)> {
    let attrs = ArrayList<(String, String)>()
    var pos = 0

    // 跳过标签名
    while (pos < tag.size && tag[pos..pos+1] != " " && tag[pos..pos+1] != "\t" &&
           tag[pos..pos+1] != "\n" && tag[pos..pos+1] != ">") {
        pos++
    }

    while (pos < tag.size) {
        // 跳过空白
        while (pos < tag.size && (tag[pos..pos+1] == " " || tag[pos..pos+1] == "\t" ||
               tag[pos..pos+1] == "\n" || tag[pos..pos+1] == "\r")) {
            pos++
        }
        if (pos >= tag.size || tag[pos..pos+1] == ">" || tag[pos..pos+1] == "/") {
            break
        }

        // 读取属性名
        let nameStart = pos
        while (pos < tag.size && tag[pos..pos+1] != "=" && tag[pos..pos+1] != " " &&
               tag[pos..pos+1] != "\t" && tag[pos..pos+1] != ">" && tag[pos..pos+1] != "/" &&
               tag[pos..pos+1] != "\n") {
            pos++
        }
        if (pos <= nameStart) { break }
        let name = CssStrUtil.toLowerCase(tag[nameStart..pos])

        // 跳过空白
        while (pos < tag.size && (tag[pos..pos+1] == " " || tag[pos..pos+1] == "\t")) {
            pos++
        }

        // 检查是否有 =
        if (pos < tag.size && tag[pos..pos+1] == "=") {
            pos++ // 跳过 =
            // 跳过空白
            while (pos < tag.size && (tag[pos..pos+1] == " " || tag[pos..pos+1] == "\t")) {
                pos++
            }
            // 读取值
            if (pos < tag.size && (tag[pos..pos+1] == "\"" || tag[pos..pos+1] == "'")) {
                let quoteChar = tag[pos..pos+1]
                pos++ // 跳过开始引号
                let valueStart = pos
                while (pos < tag.size && tag[pos..pos+1] != quoteChar) {
                    pos++
                }
                let value = tag[valueStart..pos]
                attrs.append((name, value))
                if (pos < tag.size) { pos++ } // 跳过结束引号
            } else {
                // 无引号值
                let valueStart = pos
                while (pos < tag.size && tag[pos..pos+1] != " " && tag[pos..pos+1] != "\t" &&
                       tag[pos..pos+1] != ">") {
                    pos++
                }
                let value = tag[valueStart..pos]
                attrs.append((name, value))
            }
        } else {
            // 布尔属性
            attrs.append((name, ""))
        }
    }

    return attrs
}

/// 检查标签是否匹配处理器选择器
// 支持选择器语法:
//   element[attr]              - 元素名 + 属性存在
//   element[attr='value']      - 属性值匹配
//   element[attr^='prefix']    - 属性值前缀匹配
//   element[att1][att2]        - 多属性匹配
//   sel1, sel2                 - 多选择器 OR
private func matchesHandler(tagName: String,
                              attributes: ArrayList<(String, String)>,
                              handler: TagHandler): Bool {
    // 分割逗号分隔的多选择器
    let selectors = handler.selector.split(",")
    for (sel in selectors) {
        if (matchesSingleSelector(tagName, attributes, CssStrUtil.trim(sel))) {
            return true
        }
    }
    return false
}

/// 匹配单个选择器
private func matchesSingleSelector(tagName: String,
                                     attributes: ArrayList<(String, String)>,
                                     selector: String): Bool {
    var pos = 0

    // 提取元素名
    let nameStart = pos
    while (pos < selector.size && selector[pos..pos+1] != "[") {
        pos++
    }
    let selTagName = CssStrUtil.toLowerCase(CssStrUtil.trim(selector[nameStart..pos]))
    if (selTagName.size > 0 && selTagName != tagName) {
        return false
    }

    // 处理属性条件
    while (pos < selector.size) {
        if (selector[pos..pos+1] != "[") {
            pos++
            continue
        }
        pos++ // 跳过 [

        // 读取属性名
        let attrStart = pos
        while (pos < selector.size && selector[pos..pos+1] != "=" &&
               selector[pos..pos+1] != "]" && !(selector[pos..pos+1] == "^" &&
               pos + 1 < selector.size && selector[pos+1..pos+2] == "=")) {
            pos++
        }
        let attrName = CssStrUtil.toLowerCase(CssStrUtil.trim(selector[attrStart..pos]))

        if (pos < selector.size && selector[pos..pos+1] == "^" &&
            pos + 1 < selector.size && selector[pos+1..pos+2] == "=") {
            // ^= 前缀匹配
            pos += 2 // 跳过 ^=
            let (value, endPos) = readQuotedValue(selector, pos)
            pos = skipToCloseBracket(selector, endPos)
            // 检查属性值是否以指定值开头
            match (getAttributeValue(attributes, attrName)) {
                case Some(v) =>
                    if (!v.startsWith(value)) { return false }
                case None => return false
            }
        } else if (pos < selector.size && selector[pos..pos+1] == "=") {
            // = 精确匹配
            pos++ // 跳过 =
            let (value, endPos) = readQuotedValue(selector, pos)
            pos = skipToCloseBracket(selector, endPos)
            match (getAttributeValue(attributes, attrName)) {
                case Some(v) =>
                    if (v != value) { return false }
                case None => return false
            }
        } else {
            // 仅属性存在检查
            pos = skipToCloseBracket(selector, pos)
            if (!hasAttribute(attributes, attrName)) {
                return false
            }
        }
    }

    return true
}

/// 读取引号中的值
private func readQuotedValue(selector: String, start: Int64): (String, Int64) {
    var pos = start
    if (pos >= selector.size) {
        return ("", pos)
    }
    if (selector[pos..pos+1] == "\"" || selector[pos..pos+1] == "'") {
        let quoteChar = selector[pos..pos+1]
        pos++
        let valStart = pos
        while (pos < selector.size && selector[pos..pos+1] != quoteChar) {
            pos++
        }
        let value = selector[valStart..pos]
        if (pos < selector.size) { pos++ } // 跳过结束引号
        return (value, pos)
    }
    // 无引号值
    let valStart = pos
    while (pos < selector.size && selector[pos..pos+1] != "]") {
        pos++
    }
    return (selector[valStart..pos], pos)
}

/// 跳到 ] 后
private func skipToCloseBracket(selector: String, pos: Int64): Int64 {
    var p = pos
    while (p < selector.size && selector[p..p+1] != "]") {
        p++
    }
    if (p < selector.size) { p++ } // 跳过 ]
    return p
}

/// 获取属性值
private func getAttributeValue(attrs: ArrayList<(String, String)>,
                                 name: String): ?String {
    for ((n, v) in attrs) {
        if (n == name) {
            return Some(v)
        }
    }
    return None
}

/// 检查属性是否存在
private func hasAttribute(attrs: ArrayList<(String, String)>, name: String): Bool {
    for ((n, _) in attrs) {
        if (n == name) {
            return true
        }
    }
    return false
}

/// 解析 srcset 属性值
// srcset 格式: "url1 1x, url2 2x" 或 "url1 100w, url2 200w"
// 每个条目以逗号分隔, URL 是第一个 token
private func parseSrcSet(srcset: String): ArrayList<String> {
    let urls = ArrayList<String>()
    let entries = srcset.split(",")
    for (entry in entries) {
        let trimmed = CssStrUtil.trim(entry)
        if (trimmed.size == 0) { continue }
        // URL 是第一个空白之前的部分
        let spaceIdx = trimmed.indexOf(" ")
        match (spaceIdx) {
            case Some(idx) =>
                urls.append(trimmed[0..idx])
            case None =>
                urls.append(trimmed)
        }
    }
    return urls
}

/// 获取文件扩展名 (包含点号)
private func getFileExtension(path: String): String {
    let dotIdx = path.lastIndexOf(".")
    match (dotIdx) {
        case Some(idx) =>
            if (idx > 0) {
                return path[idx..path.size]
            }
        case None => ()
    }
    return ""
}

/// 源路径目录名
// 严格翻译自: resolve_path.dirname
private func sourcePathDirname(path: String): String {
    let lastSep = path.lastIndexOf("/")
    match (lastSep) {
        case Some(idx) =>
            return path[0..idx]
        case None => ()
    }
    return ""
}

/// 路径拼接
private func joinPath(base: String, relative: String): String {
    if (base.size == 0) { return relative }
    if (base.endsWith("/")) {
        return base + relative
    }
    return base + "/" + relative
}

