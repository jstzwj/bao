// 严格翻译自: src/md/root.zig
// Markdown 解析器包入口
package bao_md

// ============================================================================
// 渲染选项
// ============================================================================

/// 渲染选项
public class RenderOptions {
    public var tag_filter: Bool = false
    public var heading_ids: Bool = false
    public var autolink_headings: Bool = false

    public init() {}
    public init(tag_filter: Bool, heading_ids: Bool, autolink_headings: Bool) {
        this.tag_filter = tag_filter
        this.heading_ids = heading_ids
        this.autolink_headings = autolink_headings
    }
}

/// 解析选项（包含解析标志和渲染选项）
public class Options {
    public var tables: Bool = true
    public var strikethrough: Bool = true
    public var tasklists: Bool = true
    public var permissive_autolinks: Bool = false
    public var permissive_url_autolinks: Bool = false
    public var permissive_www_autolinks: Bool = false
    public var permissive_email_autolinks: Bool = false
    public var hard_soft_breaks: Bool = false
    public var wiki_links: Bool = false
    public var underline: Bool = false
    public var latex_math: Bool = false
    public var collapse_whitespace: Bool = false
    public var permissive_atx_headers: Bool = false
    public var no_indented_code_blocks: Bool = false
    public var no_html_blocks: Bool = false
    public var no_html_spans: Bool = false
    /// GFM 标签过滤: 将禁用 HTML 标签的 `<` 替换为 `&lt;`
    /// (title, textarea, style, xmp, iframe, noembed, noframes, script, plaintext)
    public var tag_filter: Bool = false
    public var heading_ids: Bool = false
    public var autolink_headings: Bool = false

    public init() {}

    /// CommonMark 默认选项
    public static func commonmark(): Options {
        let o = Options()
        o.tables = false
        o.strikethrough = false
        o.tasklists = false
        return o
    }

    /// GitHub 风格 Markdown 选项
    public static func github(): Options {
        let o = Options()
        o.tables = true
        o.strikethrough = true
        o.tasklists = true
        o.permissive_autolinks = true
        o.permissive_www_autolinks = true
        o.permissive_email_autolinks = true
        o.tag_filter = true
        return o
    }

    /// 终端输出选项
    public static func terminal(): Options {
        let o = Options()
        o.tables = true
        o.strikethrough = true
        o.tasklists = true
        o.permissive_url_autolinks = true
        o.permissive_www_autolinks = true
        o.permissive_email_autolinks = true
        o.wiki_links = true
        o.underline = true
        o.latex_math = true
        return o
    }

    /// 转换为解析器标志
    public func toFlags(): Flags {
        let f = Flags()
        f.tables = tables
        f.strikethrough = strikethrough
        f.tasklists = tasklists
        f.permissive_url_autolinks = permissive_url_autolinks || permissive_autolinks
        f.permissive_www_autolinks = permissive_www_autolinks || permissive_autolinks
        f.permissive_email_autolinks = permissive_email_autolinks || permissive_autolinks
        f.hard_soft_breaks = hard_soft_breaks
        f.wiki_links = wiki_links
        f.underline = underline
        f.latex_math = latex_math
        f.collapse_whitespace = collapse_whitespace
        f.permissive_atx_headers = permissive_atx_headers
        f.no_indented_code_blocks = no_indented_code_blocks
        f.no_html_blocks = no_html_blocks
        f.no_html_spans = no_html_spans
        return f
    }

    /// 转换为渲染选项
    public func toRenderOptions(): RenderOptions {
        let ro = RenderOptions()
        ro.tag_filter = tag_filter
        ro.heading_ids = heading_ids
        ro.autolink_headings = autolink_headings
        return ro
    }
}

// ============================================================================
// 公共 API
// ============================================================================

/// 渲染 Markdown 为 HTML
public func renderToHtml(text: String): String {
    return renderToHtmlWithOptions(text, Options())
}

/// 使用选项渲染 Markdown 为 HTML
public func renderToHtmlWithOptions(text: String, options: Options): String {
    return ParserApi.renderToHtml(text, options.toFlags(), options.toRenderOptions())
}

/// 使用自定义渲染器解析和渲染
public func renderWithRenderer(text: String, options: Options, rend: Renderer): Unit {
    ParserApi.renderWithRenderer(text, options.toFlags(), options.toRenderOptions(), rend)
}
