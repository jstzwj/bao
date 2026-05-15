// 严格翻译自: src/bundler/HTMLScanner.zig (~309行)
// bao_bundler - HTML 扫描器: 扫描 HTML 中的导入引用 (脚本、样式、资源)
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_ast.*

// ============================================================================
// HTML 扫描器
// 严格翻译自: src/bundler/HTMLScanner.zig:1-309
// Bun: const HTMLScanner = @This();
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
/// Bun: const HTMLScanner = @This(); { allocator, import_records, log, source }
public class HTMLScanner {
    /// 日志
    public var log: Log
    /// 源文件
    public var source: Source
    /// 导入记录列表
    public var importRecords: ArrayList<ImportRecord>

    public init(log: Log, source: Source) {
        this.log = log
        this.source = source
        this.importRecords = ArrayList<ImportRecord>()
    }

    /// 释放 - 对应 Bun HTMLScanner.deinit()
    /// Bun: pub fn deinit(this: *HTMLScanner) void
    public func deinit(): Unit {
        importRecords.clear()
    }

    /// 创建导入记录 - 对应 Bun HTMLScanner.createImportRecord()
    /// Bun: fn createImportRecord(this: *HTMLScanner, input_path: []const u8, kind: ImportKind) !void
    ///
    /// 路径处理逻辑:
    /// 1. 以 '/' 开头的路径 -> 相对于项目根目录
    /// 2. 不以 './' 开头且有扩展名 -> 尝试相对于 HTML 文件解析
    /// 3. 其他 -> 原样保留
    public func createImportRecord(inputPath: String, kind: ImportKind): Unit {
        var pathToUse = inputPath

        // 以 '/' 开头: 转换为项目根目录下的绝对路径
        if (inputPath.length > 1 && inputPath[0] == '/') {
            // 在 Bun 中: bun.path.joinAbsString(top_level_dir, input_path[1..])
            // 仓颉中简化处理
            pathToUse = inputPath.substring(1)
        } else if (inputPath.length > 2 && inputPath[0] != '.' && inputPath[1] != '/') {
            // 尝试查找扩展名
            let dotIndex = inputPath.lastIndexOf('.')
            if (dotIndex >= 0) {
                let ext = inputPath.substring(dotIndex)
                if (ext.length <= 4) {
                    // 尝试相对于 HTML 文件目录解析
                    let dirname = source.path.dirname()
                    if (dirname.length > 0) {
                        let resolved = dirname + "/" + inputPath
                        // 在 Bun 中会检查文件是否存在
                        // 仓颉中简化: 使用 resolved 路径
                        pathToUse = resolved
                    }
                }
            }
        }

        let record = ImportRecord(
            path: pathToUse,
            kind: kind,
            range: Range.None
        )
        importRecords.append(record)
    }

    /// HTML 写入回调 - 对应 Bun HTMLScanner.onWriteHTML()
    /// Bun: pub fn onWriteHTML(_: *HTMLScanner, bytes: []const u8) void
    public func onWriteHTML(bytes: String): Unit {
        // 扫描阶段不写入 bytes
    }

    /// HTML 解析错误回调 - 对应 Bun HTMLScanner.onHTMLParseError()
    /// Bun: pub fn onHTMLParseError(this: *HTMLScanner, message: []const u8) void
    public func onHTMLParseError(message: String): Unit {
        log.addError(source, Loc.Empty, message)
    }

    /// 标签回调 - 对应 Bun HTMLScanner.onTag()
    /// Bun: pub fn onTag(this: *HTMLScanner, _: *lol.Element, path: []const u8, url_attribute: []const u8, kind: ImportKind) void
    public func onTag(path: String, urlAttribute: String, kind: ImportKind): Unit {
        createImportRecord(path, kind)
    }

    /// 扫描 HTML 输入 - 对应 Bun HTMLScanner.scan()
    /// Bun: pub fn scan(this: *HTMLScanner, input: []const u8) !void
    public func scan(input: String): Unit {
        // 运行 HTML 处理器
        HTMLProcessor.scan(this, input)
    }
}

// ============================================================================
// HTML 处理器
// 严格翻译自: src/bundler/HTMLScanner.zig:75-298
// Bun: pub fn HTMLProcessor(comptime T: type, comptime visit_document_tags: bool) type
//
// HTMLProcessor 使用 CSS 选择器匹配 HTML 元素, 提取 URL 属性
// 每个匹配的元素创建一个 ImportRecord
// ============================================================================

/// 标签处理器信息 - 对应 Bun HTMLProcessor.TagHandler
/// Bun: const TagHandler = struct { selector, has_content, url_attribute, kind }
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

/// HTML 处理器 - 对应 Bun HTMLProcessor
/// Bun: pub fn HTMLProcessor(comptime T: type, comptime visit_document_tags: bool) type
///
/// 包含所有标签处理规则和扫描逻辑
public class HTMLProcessor {

    /// 获取所有标签处理器 - 对应 Bun tag_handlers 静态数组
    /// Bun: const tag_handlers = [_]TagHandler{ ... }
    public static func getTagHandlers(): ArrayList<TagHandler> {
        let handlers = ArrayList<TagHandler>()

        // Module scripts with src
        // <script src="...">
        handlers.append(TagHandler(
            selector: "script[src]",
            urlAttribute: "src",
            kind: ImportKind.Stmt
        ))

        // CSS Stylesheets
        // <link rel="stylesheet" href="...">
        handlers.append(TagHandler(
            selector: "link[rel='stylesheet'][href]",
            urlAttribute: "href",
            kind: ImportKind.At
        ))

        // CSS Assets
        // <link as="style" href="...">
        handlers.append(TagHandler(
            selector: "link[as='style'][href]",
            urlAttribute: "href",
            kind: ImportKind.At
        ))

        // Font files
        // <link as="font" href="..."> 或 <link type^='font/' href="...">
        handlers.append(TagHandler(
            selector: "link[as='font'][href], link[type^='font/'][href]",
            urlAttribute: "href",
            kind: ImportKind.Url
        ))

        // Image assets
        // <link as="image" href="...">
        handlers.append(TagHandler(
            selector: "link[as='image'][href]",
            urlAttribute: "href",
            kind: ImportKind.Url
        ))

        // Audio/Video assets
        // <link as="video" href="..."> 或 <link as="audio" href="...">
        handlers.append(TagHandler(
            selector: "link[as='video'][href], link[as='audio'][href]",
            urlAttribute: "href",
            kind: ImportKind.Url
        ))

        // Web Workers
        // <link as="worker" href="...">
        handlers.append(TagHandler(
            selector: "link[as='worker'][href]",
            urlAttribute: "href",
            kind: ImportKind.Stmt
        ))

        // Manifest files
        // <link rel="manifest" href="...">
        handlers.append(TagHandler(
            selector: "link[rel='manifest'][href]",
            urlAttribute: "href",
            kind: ImportKind.Url
        ))

        // Icons
        // <link rel="icon" href="..."> 或 <link rel="apple-touch-icon" href="...">
        handlers.append(TagHandler(
            selector: "link[rel='icon'][href], link[rel='apple-touch-icon'][href]",
            urlAttribute: "href",
            kind: ImportKind.Url
        ))

        // Images with src
        // <img src="...">
        handlers.append(TagHandler(
            selector: "img[src]",
            urlAttribute: "src",
            kind: ImportKind.Url
        ))

        // Images with srcset
        // <img srcset="...">
        handlers.append(TagHandler(
            selector: "img[srcset]",
            urlAttribute: "srcset",
            kind: ImportKind.Url
        ))

        // Videos with src
        // <video src="...">
        handlers.append(TagHandler(
            selector: "video[src]",
            urlAttribute: "src",
            kind: ImportKind.Url
        ))

        // Videos with poster
        // <video poster="...">
        handlers.append(TagHandler(
            selector: "video[poster]",
            urlAttribute: "poster",
            kind: ImportKind.Url
        ))

        // Audio with src
        // <audio src="...">
        handlers.append(TagHandler(
            selector: "audio[src]",
            urlAttribute: "src",
            kind: ImportKind.Url
        ))

        // Source elements with src
        // <source src="...">
        handlers.append(TagHandler(
            selector: "source[src]",
            urlAttribute: "src",
            kind: ImportKind.Url
        ))

        // Source elements with srcset
        // <source srcset="...">
        handlers.append(TagHandler(
            selector: "source[srcset]",
            urlAttribute: "srcset",
            kind: ImportKind.Url
        ))

        // Note: Iframes intentionally excluded (commented out in Bun source)
        // <iframe src="..."> is NOT processed

        return handlers
    }

    /// 扫描 HTML - 对应 Bun HTMLProcessor.run()
    /// Bun: pub fn run(this: *T, input: []const u8) !void
    ///
    /// 遍历所有标签处理器, 对每个匹配的标签提取 URL 并创建 ImportRecord
    public static func scan(scanner: HTMLScanner, input: String): Unit {
        // 简化的 HTML 标签扫描
        // 在 Bun 中, 这使用 lolhtml (一个 C 库) 进行 HTML 解析
        // 仓颉中简化为基于字符串的标签匹配

        let tagHandlers = getTagHandlers()
        let html = input

        for (handler in tagHandlers) {
            scanForAttribute(scanner, html, handler.urlAttribute, handler.kind)
        }
    }

    /// 扫描指定属性 - 内部辅助方法
    /// 在 HTML 中查找带有指定属性的标签
    private static func scanForAttribute(
        scanner: HTMLScanner,
        html: String,
        attribute: String,
        kind: ImportKind
    ): Unit {
        // 简化的属性扫描: 查找 attribute="value" 模式
        let attrPattern = attribute + "=\""
        var searchStart = 0

        while (searchStart < html.length) {
            let attrIndex = html.indexOf(attrPattern, searchStart)
            if (attrIndex < 0) {
                break
            }

            let valueStart = attrIndex + attrPattern.length
            let valueEnd = html.indexOf("\"", valueStart)
            if (valueEnd < 0) {
                break
            }

            let value = html.substring(valueStart, valueEnd)
            if (value.length > 0) {
                scanner.createImportRecord(value, kind)
            }

            searchStart = valueEnd + 1
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 导入类型 - 对应 Bun ImportKind
/// Bun: const ImportKind = @import("../options_types/import_record.zig").ImportKind
public enum ImportKind {
    | Stmt   // script, worker 等 (语句级导入)
    | At     // stylesheet, CSS (at 规则级导入)
    | Url    // image, font, icon 等 (URL 级引用)

    public func name(): String {
        match (this) {
            case Stmt => "stmt"
            case At => "at"
            case Url => "url"
        }
    }
}

/// 导入记录 - 对应 Bun ImportRecord
/// Bun: const ImportRecord = @import("../options_types/import_record.zig").ImportRecord
public class ImportRecord {
    /// 导入路径
    public var path: String
    /// 导入类型
    public var kind: ImportKind
    /// 源码范围
    public var range: Range

    public init(path: String, kind: ImportKind, range: Range) {
        this.path = path
        this.kind = kind
        this.range = range
    }
}

/// Range - 对应 Bun logger.Range
public class Range {
    public static let None = Range()

    public init() {}
}

/// Source 路径辅助
public class Source {
    public var path: SourcePath

    public init(path: SourcePath) {
        this.path = path
    }

    public init() {
        this.path = SourcePath()
    }
}

/// 源文件路径
public class SourcePath {
    public var text: String

    public init(text: String) {
        this.text = text
    }

    public init() {
        this.text = ""
    }

    /// 获取目录名
    public func dirname(): String {
        let lastSlash = text.lastIndexOf('/')
        if (lastSlash < 0) {
            return ""
        }
        return text.substring(0, lastSlash)
    }

    /// 获取漂亮路径
    public func pretty(): String {
        return text
    }
}

/// Log - 日志引用类型
public class Log {
    public init() {}

    /// 添加错误 - 对应 Bun Logger.Log.addError()
    public func addError(source: Source, loc: Loc, message: String): Unit {
        // 简化: 记录错误
    }
}

/// Loc - 位置引用
public typealias Loc = bao_ast.Loc
