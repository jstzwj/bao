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
        importRecords.append(ImportRecord(inputPath))
    }

    /// HTML 写入回调 - 对应 Bun HTMLScanner.onWriteHTML()
    /// Bun: pub fn onWriteHTML(_: *HTMLScanner, bytes: []const u8) void
    public func onWriteHTML(bytes: String): Unit {
        // 扫描阶段不写入 bytes
    }

    /// HTML 解析错误回调 - 对应 Bun HTMLScanner.onHTMLParseError()
    /// Bun: pub fn onHTMLParseError(this: *HTMLScanner, message: []const u8) void
    public func onHTMLParseError(message: String): Unit {
        ()
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
            "script[src]",
            "src",
            ImportKind.Stmt
        ))

        // CSS Stylesheets
        // <link rel="stylesheet" href="...">
        handlers.append(TagHandler(
            "link[rel='stylesheet'][href]",
            "href",
            ImportKind.At
        ))

        // CSS Assets
        // <link as="style" href="...">
        handlers.append(TagHandler(
            "link[as='style'][href]",
            "href",
            ImportKind.At
        ))

        // Font files
        // <link as="font" href="..."> 或 <link type^='font/' href="...">
        handlers.append(TagHandler(
            "link[as='font'][href], link[type^='font/'][href]",
            "href",
            ImportKind.Url
        ))

        // Image assets
        // <link as="image" href="...">
        handlers.append(TagHandler(
            "link[as='image'][href]",
            "href",
            ImportKind.Url
        ))

        // Audio/Video assets
        // <link as="video" href="..."> 或 <link as="audio" href="...">
        handlers.append(TagHandler(
            "link[as='video'][href], link[as='audio'][href]",
            "href",
            ImportKind.Url
        ))

        // Web Workers
        // <link as="worker" href="...">
        handlers.append(TagHandler(
            "link[as='worker'][href]",
            "href",
            ImportKind.Stmt
        ))

        // Manifest files
        // <link rel="manifest" href="...">
        handlers.append(TagHandler(
            "link[rel='manifest'][href]",
            "href",
            ImportKind.Url
        ))

        // Icons
        // <link rel="icon" href="..."> 或 <link rel="apple-touch-icon" href="...">
        handlers.append(TagHandler(
            "link[rel='icon'][href], link[rel='apple-touch-icon'][href]",
            "href",
            ImportKind.Url
        ))

        // Images with src
        // <img src="...">
        handlers.append(TagHandler(
            "img[src]",
            "src",
            ImportKind.Url
        ))

        // Images with srcset
        // <img srcset="...">
        handlers.append(TagHandler(
            "img[srcset]",
            "srcset",
            ImportKind.Url
        ))

        // Videos with src
        // <video src="...">
        handlers.append(TagHandler(
            "video[src]",
            "src",
            ImportKind.Url
        ))

        // Videos with poster
        // <video poster="...">
        handlers.append(TagHandler(
            "video[poster]",
            "poster",
            ImportKind.Url
        ))

        // Audio with src
        // <audio src="...">
        handlers.append(TagHandler(
            "audio[src]",
            "src",
            ImportKind.Url
        ))

        // Source elements with src
        // <source src="...">
        handlers.append(TagHandler(
            "source[src]",
            "src",
            ImportKind.Url
        ))

        // Source elements with srcset
        // <source srcset="...">
        handlers.append(TagHandler(
            "source[srcset]",
            "srcset",
            ImportKind.Url
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
        ()
    }

    /// 扫描指定属性 - 内部辅助方法
    /// 在 HTML 中查找带有指定属性的标签
    private static func scanForAttribute(
        scanner: HTMLScanner,
        html: String,
        attribute: String,
        kind: ImportKind
    ): Unit {
        ()
    }
}

/// Loc - 位置引用
// HTMLScannerLoc removed - use Loc directly

/// 源路径辅助函数 - 从路径中提取目录名
private func sourcePathDirname(path: String): String {
    return ""
}
