// 严格翻译自: src/md/root.zig
// Markdown 模块根入口，重新导出类型并提供公共 API
package bao_md

// 类型已通过 types.cj 和 package.cj 导出

// ============================================================================
// 公共 API
// ============================================================================

/// 渲染 Markdown 文本为 HTML 字符串
public func mdRenderToHtml(text: String): String {
    return mdRenderToHtmlWithOptions(text, Options())
}

/// 使用选项渲染 Markdown 为 HTML
public func mdRenderToHtmlWithOptions(text: String, options: Options): String {
    return ParserApi.renderToHtml(text, options.toFlags(), options.toRenderOptions())
}

/// 使用自定义渲染器解析和渲染
public func mdRenderWithRenderer(text: String, options: Options, rend: Renderer): Unit {
    ParserApi.renderWithRenderer(text, options.toFlags(), options.toRenderOptions(), rend)
}
