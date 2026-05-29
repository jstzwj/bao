// 严格翻译自: src/runtime/api/MarkdownObject.rs (1692行)
// Bun.markdown — html/ansi/react/render host fns over bao_md.
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}
import bao_collections.{ArrayList, HashMap}
import bao_core.{Allocator, Output}
import bao_sys.*
import bao_md.*

// ============================================================================
// MarkdownObject - Bun.markdown API
// 对应 Bun: src/runtime/api/MarkdownObject.rs
// ============================================================================

/// 创建 Markdown 全局对象并注册所有方法
/// 对应 Bun: MarkdownObject.create()
public func markdownCreate(globalThis!: JsGlobalObject): JsValue {
    let obj = JsValue.createEmptyObject(globalThis, 4)
    obj.put(globalThis, ZigString.`static`("html"), JsFunction.create(globalThis, "html", markdownRenderToHtml, 1))
    obj.put(globalThis, ZigString.`static`("ansi"), JsFunction.create(globalThis, "ansi", markdownRenderToAnsi, 2))
    obj.put(globalThis, ZigString.`static`("render"), JsFunction.create(globalThis, "render", markdownRender, 3))
    obj.put(globalThis, ZigString.`static`("react"), JsFunction.create(globalThis, "react", markdownRenderReact, 3))
    return obj
}

// ============================================================================
// 内联辅助函数
// 对应 Bun: create_utf8_for_js, js_array_push, js_to_parser_err
// ============================================================================

/// 创建 UTF8 JS 字符串
/// 对应 Bun: create_utf8_for_js()
public func createUtf8ForJs(global!: JsGlobalObject, utf8!: String): JsValue {
    return BunString.createUTF8ForJS(global, utf8)
}

/// 向 JS 数组添加元素
/// 对应 Bun: js_array_push()
public func jsArrayPush(arr!: JsValue, global!: JsGlobalObject, item!: JsValue): Unit {
    arr.push(global, item)
}

// ============================================================================
// Bun.markdown.ansi(text, theme?)
// ============================================================================

/// 渲染 Markdown 到 ANSI 彩色终端字符串
/// 对应 Bun: render_to_ansi()
/// theme 是可选对象: { colors?, hyperlinks?, kittyGraphics?, light?, columns? }
/// 默认: colors=true, hyperlinks=false, columns=80
public func markdownRenderToAnsi(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    let (inputValue, themeValue) = callframe.argumentsAsArray2()

    if (inputValue.isEmptyOrUndefinedOrNull()) {
        globalThis.throwInvalidArguments("Expected a string or buffer to render")
        return JsValue.jsUndefined()
    }

    let bufferOpt = StringOrBuffer.fromJS(globalThis, inputValue)
    if (bufferOpt.isNone()) {
    globalThis.throwInvalidArguments("Expected a string or buffer to render")
    return JsValue.jsUndefined()
    }
    let buffer = bufferOpt.get()

    let input = buffer.slice()

    // 默认主题
    var theme = Theme()
    theme.colors = true
    theme.hyperlinks = false
    theme.kitty_graphics = false
    theme.light = detectLightBackground()
    theme.columns = 80

    // 解析主题选项
    if (themeValue.isObject()) {
        if (let v <- themeValue.getBooleanLoose(globalThis, "colors") ) {
            theme.colors = v
        }
        if (let v <- themeValue.getBooleanLoose(globalThis, "hyperlinks") ) {
            theme.hyperlinks = v
        }
        if (let v <- themeValue.getBooleanLoose(globalThis, "kittyGraphics") ) {
            theme.kitty_graphics = v
        }
        if (let v <- themeValue.getBooleanLoose(globalThis, "light") ) {
            theme.light = v
        }
        if (let cols <- themeValue.get(globalThis, "columns") ) {
            if (cols.isNumber()) {
                let n = cols.toInt32()
                if (n <= 0) {
                    theme.columns = 0
                } else {
                    theme.columns = UInt16(min(n, UInt16.maxValue))
                }
            }
        }
    }

    // 渲染
    let resultOpt = renderToAnsi(input, Options.terminal() , theme)
    if (resultOpt.isNone()) {
    globalThis.throwOutOfMemory()
    return JsValue.jsUndefined()
    }
    let result = resultOpt.get()

    return createUtf8ForJs(globalThis, result)
}

// ============================================================================
// Bun.markdown.html(text, opts?)
// ============================================================================

/// 渲染 Markdown 到 HTML 字符串
/// 对应 Bun: render_to_html()
public func markdownRenderToHtml(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    let (inputValue, optsValue) = callframe.argumentsAsArray2()

    if (inputValue.isEmptyOrUndefinedOrNull()) {
        globalThis.throwInvalidArguments("Expected a string or buffer to render")
        return JsValue.jsUndefined()
    }

    let bufferOpt = StringOrBuffer.fromJS(globalThis, inputValue)
    if (bufferOpt.isNone()) {
    globalThis.throwInvalidArguments("Expected a string or buffer to render")
    return JsValue.jsUndefined()
    }
    let buffer = bufferOpt.get()

    let input = buffer.slice()
    let options = markdownParseOptions(globalThis, optsValue) 

    let result = renderToHtmlWithOptions(input, options)
    return createUtf8ForJs(globalThis, result)
}

// ============================================================================
// 选项解析
// 对应 Bun: parse_options()
// ============================================================================

/// 解析 Markdown 渲染选项
public func markdownParseOptions(globalThis!: JsGlobalObject, optsValue!: JsValue): Options {
    var options = Options()
    if (optsValue.isObject()) {
        // 处理复合 autolinks: true | { url, www, email }
        if (let autolinksVal <- optsValue.get(globalThis, "autolinks") ) {
            if (autolinksVal.isBoolean()) {
                if (autolinksVal.toBoolean()) {
                    options.permissive_autolinks = true
                }
            } else if (autolinksVal.isObject()) {
                if (let v <- autolinksVal.getBooleanLoose(globalThis, "url") ) {
                    options.permissive_url_autolinks = v
                }
                if (let v <- autolinksVal.getBooleanLoose(globalThis, "www") ) {
                    options.permissive_www_autolinks = v
                }
                if (let v <- autolinksVal.getBooleanLoose(globalThis, "email") ) {
                    options.permissive_email_autolinks = v
                }
            }
        }

        // 处理复合 headings: true | { ids, autolink }
        if (let headingsVal <- optsValue.get(globalThis, "headings") ) {
            if (headingsVal.isBoolean()) {
                if (headingsVal.toBoolean()) {
                    options.heading_ids = true
                    options.autolink_headings = true
                }
            } else if (headingsVal.isObject()) {
                if (let v <- headingsVal.getBooleanLoose(globalThis, "ids") ) {
                    options.heading_ids = v
                }
                if (let v <- headingsVal.getBooleanLoose(globalThis, "autolink") ) {
                    options.autolink_headings = v
                }
            }
        }

        // 处理其余布尔选项
        // 对应 Bun: Options.BOOL_FIELD_SETTERS 反射循环
        if (let v <- optsValue.getBooleanLoose(globalThis, "allowMath") ) {
            options.latex_math = v
        }
        if (let v <- optsValue.getBooleanLoose(globalThis, "parseSpan") ) {
            options.collapse_whitespace = v
        }
        if (let v <- optsValue.getBooleanLoose(globalThis, "wikilinks") ) {
            options.wiki_links = v
        }
        if (let v <- optsValue.getBooleanLoose(globalThis, "tasklist") ) {
            options.tasklists = v
        }
        if (let v <- optsValue.getBooleanLoose(globalThis, "tasklists") ) {
            options.tasklists = v
        }
        if (let v <- optsValue.getBooleanLoose(globalThis, "strikethrough") ) {
            options.strikethrough = v
        }
        if (let v <- optsValue.getBooleanLoose(globalThis, "underline") ) {
            options.underline = v
        }
        if (let v <- optsValue.getBooleanLoose(globalThis, "tables") ) {
            options.tables = v
        }
        if (let v <- optsValue.getBooleanLoose(globalThis, "hardSoftBreaks") ) {
            options.hard_soft_breaks = v
        }
        if (let v <- optsValue.getBooleanLoose(globalThis, "noIndentedCodeBlocks") ) {
            options.no_indented_code_blocks = v
        }
        if (let v <- optsValue.getBooleanLoose(globalThis, "noHtmlBlocks") ) {
            options.no_html_blocks = v
        }
        if (let v <- optsValue.getBooleanLoose(globalThis, "noHtmlSpans") ) {
            options.no_html_spans = v
        }
        if (let v <- optsValue.getBooleanLoose(globalThis, "permissiveAtxHeaders") ) {
            options.permissive_atx_headers = v
        }
        if (let v <- optsValue.getBooleanLoose(globalThis, "tagFilter") ) {
            options.tag_filter = v
        }
    }
    return options
}

// ============================================================================
// Bun.markdown.render(text, callbacks, options?)
// ============================================================================

/// 使用自定义回调渲染 Markdown
/// 对应 Bun: render()
/// 每个回调接收累积的子元素字符串和可选元数据对象，返回字符串。
/// 最终结果是所有回调输出的拼接。
public func markdownRender(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    let (inputValue, callbacksValue, optsValue) = callframe.argumentsAsArray3()

    if (inputValue.isEmptyOrUndefinedOrNull()) {
        globalThis.throwInvalidArguments("Expected a string or buffer to render")
        return JsValue.jsUndefined()
    }

    let bufferOpt = StringOrBuffer.fromJS(globalThis, inputValue)
    if (bufferOpt.isNone()) {
    globalThis.throwInvalidArguments("Expected a string or buffer to render")
    return JsValue.jsUndefined()
    }
    let buffer = bufferOpt.get()

    let input = buffer.slice()

    // 解析选项
    let options = markdownParseOptions(globalThis, optsValue) 

    // 创建 JS 回调渲染器
    var jsRendererOpt = JsCallbackRenderer(globalThis, input, options.heading_ids)
    if (jsRendererOpt.isNone()) {
        globalThis.throwOutOfMemory()
        return JsValue.jsUndefined()
    }
    var jsRenderer = jsRendererOpt.get()

    // 提取回调
    let cbVal = if (callbacksValue.isObject()) { callbacksValue } else { JsValue.jsUndefined() }
    jsRenderer.extractCallbacks(cbVal)

    // 运行解析器
    renderWithRenderer(input, options, jsRenderer.renderer() )

    // 返回累积结果
    let result = jsRenderer.getResult()
    return createUtf8ForJs(globalThis, result)
}

// ============================================================================
// Bun.markdown.react(text, components?, options?)
// ============================================================================

/// 渲染 Markdown 为 React Fragment 元素
/// 对应 Bun: render_react() / render_react_impl()
/// 返回一个 React Fragment 元素，包含解析后的 Markdown 作为子元素。
public func markdownRenderReact(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    // 获取选项中的 reactVersion
    let args = callframe.argumentsAsArray(3)
    let optsValue = args[2]

    var reactVersion: UInt8 = 1 // 默认: react.transitional.element (React 19+)
    if (optsValue.isObject()) {
        if (let rv <- optsValue.get(globalThis, "reactVersion") ) {
            if (rv.isNumber()) {
                let num = rv.toInt32()
                if (num <= 18) {
                    reactVersion = 0 // react.element (React 18 及更早)
                }
            }
        }
    }

    let childrenOpt = renderAst(globalThis, callframe, reactVersion)
    if (childrenOpt.isNone()) {
    return JsValue.jsUndefined()
    }
    let children = childrenOpt.get()

    let fragment = JSReactElement.createFragment(globalThis, reactVersion, children)
    return fragment
}

/// 渲染 Markdown 为 AST（对象树或 React 元素）
/// 对应 Bun: render_ast()
/// 在普通模式(reactVersion.isNone())下，每个元素变为:
///   { type: "tagName", props: { ...metadata, children: [...] } }
/// 在 React 模式下，每个元素变为有效的 React 元素:
///   { $$typeof: Symbol.for('react.element'), type, key, ref, props }
public func renderAst(globalThis!: JsGlobalObject, callframe!: JsCallFrame, reactVersion!: UInt8): ?JsValue {
    let (inputValue, componentsValue, optsValue) = callframe.argumentsAsArray3()

    if (inputValue.isEmptyOrUndefinedOrNull()) {
        globalThis.throwInvalidArguments("Expected a string or buffer to render")
        return None
    }

    let bufferOpt = StringOrBuffer.fromJS(globalThis, inputValue)
    if (bufferOpt.isNone()) {
    globalThis.throwInvalidArguments("Expected a string or buffer to render")
    return None
    }
    let buffer = bufferOpt.get()

    let input = buffer.slice()

    // 解析选项
    let options = markdownParseOptions(globalThis, optsValue) 

    var rendererOpt = ParseRenderer(
        globalThis,
        input,
        options.heading_ids,
        reactVersion,
    )
    if (rendererOpt.isNone()) {
        globalThis.throwOutOfMemory()
        return None
    }
    var renderer = rendererOpt.get()

    // 提取组件覆盖
    renderer.extractComponents(if (componentsValue.isObject() ) { componentsValue } else { JsValue.jsUndefined() })

    // 运行解析器
    renderWithRenderer(input, options, renderer.renderer() )

    return renderer.getResult()
}

// ============================================================================
// TagIndex - 缓存标签字符串索引
// 对应 Bun: TagIndex enum (must match BunMarkdownTagStrings.h)
// ============================================================================

/// 缓存标签字符串索引
public enum TagIndex {
    | h1       // 0
    | h2       // 1
    | h3       // 2
    | h4       // 3
    | h5       // 4
    | h6       // 5
    | p        // 6
    | blockquote // 7
    | ul       // 8
    | ol       // 9
    | li       // 10
    | pre      // 11
    | hr       // 12
    | html     // 13
    | table    // 14
    | thead    // 15
    | tbody    // 16
    | tr       // 17
    | th       // 18
    | td       // 19
    | div      // 20
    | em       // 21
    | strong   // 22
    | a        // 23
    | img      // 24
    | code     // 25
    | del      // 26
    | math     // 27
    | u        // 28
    | br       // 29

    /// 转为 UInt8 索引
    public func toUInt8(): UInt8 {
        match (this) {
            case h1 => 0
            case h2 => 1
            case h3 => 2
            case h4 => 3
            case h5 => 4
            case h6 => 5
            case p => 6
            case blockquote => 7
            case ul => 8
            case ol => 9
            case li => 10
            case pre => 11
            case hr => 12
            case html => 13
            case table => 14
            case thead => 15
            case tbody => 16
            case tr => 17
            case th => 18
            case td => 19
            case div => 20
            case em => 21
            case strong => 22
            case a => 23
            case img => 24
            case code => 25
            case del => 26
            case math => 27
            case u => 28
            case br => 29
        }
    }
}

// ============================================================================
// 标签辅助函数
// 对应 Bun: get_cached_tag_string, get_block_type_tag, get_span_type_tag
// ============================================================================

/// 获取缓存的标签字符串
/// 对应 Bun: get_cached_tag_string()
public func getCachedTagString(jsGlobalObject!: JsGlobalObject, tag!: TagIndex): JsValue {
    return BunMarkdownTagStrings.getTagString(globalObject, tag.toUInt8())
}

/// 从 BlockType 获取标签索引
/// 对应 Bun: get_block_type_tag()
public func getBlockTypeTag(blockType!: BlockType, data!: UInt32): TagIndex {
    match (blockType) {
        case BlockType.h =>
            match (data) {
                case 1 => TagIndex.h1
                case 2 => TagIndex.h2
                case 3 => TagIndex.h3
                case 4 => TagIndex.h4
                case 5 => TagIndex.h5
                case _ => TagIndex.h6
            }
        case BlockType.p => TagIndex.p
        case BlockType.`quote` => TagIndex.blockquote
        case BlockType.ul => TagIndex.ul
        case BlockType.ol => TagIndex.ol
        case BlockType.li => TagIndex.li
        case BlockType.code => TagIndex.pre
        case BlockType.hr => TagIndex.hr
        case BlockType.html => TagIndex.html
        case BlockType.table => TagIndex.table
        case BlockType.thead => TagIndex.thead
        case BlockType.tbody => TagIndex.tbody
        case BlockType.tr => TagIndex.tr
        case BlockType.th => TagIndex.th
        case BlockType.td => TagIndex.td
        case BlockType.doc => TagIndex.div
        case _ => TagIndex.div
    }
}

/// 从 SpanType 获取标签索引
/// 对应 Bun: get_span_type_tag()
public func getSpanTypeTag(spanType!: SpanType): TagIndex {
    match (spanType) {
        case SpanType.em => TagIndex.em
        case SpanType.strong => TagIndex.strong
        case SpanType.a => TagIndex.a
        case SpanType.img => TagIndex.img
        case SpanType.code => TagIndex.code
        case SpanType.del => TagIndex.del
        case SpanType.latexmath => TagIndex.math
        case SpanType.latexmathDisplay => TagIndex.math
        case SpanType.wikilink => TagIndex.a
        case SpanType.u => TagIndex.u
        case _ => TagIndex.div
    }
}

/// 从 src_text 切割代码块语言标记
/// 对应 Bun: extract_language()
public func extractLanguage(srcText!: String, infoBeg!: UInt32): String {
    var langEnd = infoBeg
    while (Int64(langEnd) < srcText.size) {
        let c = srcText[Int64(langEnd)]
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
            break
        }
        langEnd = langEnd + 1
    }
    if (langEnd > infoBeg) {
        return srcText[Int64(infoBeg)..Int64(langEnd)]
    }
    return ""
}

// ============================================================================
// ParseRenderer - 构建 AST 对象树的渲染器
// 对应 Bun: ParseRenderer struct
// ============================================================================

/// 组件覆盖，按键名索引
/// 当设置时，该值替换 type 字段中的字符串标签名
public class Components {
    public var h1: JsValue = JsValue.jsUndefined()
    public var h2: JsValue = JsValue.jsUndefined()
    public var h3: JsValue = JsValue.jsUndefined()
    public var h4: JsValue = JsValue.jsUndefined()
    public var h5: JsValue = JsValue.jsUndefined()
    public var h6: JsValue = JsValue.jsUndefined()
    public var p: JsValue = JsValue.jsUndefined()
    public var blockquote: JsValue = JsValue.jsUndefined()
    public var ul: JsValue = JsValue.jsUndefined()
    public var ol: JsValue = JsValue.jsUndefined()
    public var li: JsValue = JsValue.jsUndefined()
    public var pre: JsValue = JsValue.jsUndefined()
    public var hr: JsValue = JsValue.jsUndefined()
    public var html: JsValue = JsValue.jsUndefined()
    public var table: JsValue = JsValue.jsUndefined()
    public var thead: JsValue = JsValue.jsUndefined()
    public var tbody: JsValue = JsValue.jsUndefined()
    public var tr: JsValue = JsValue.jsUndefined()
    public var th: JsValue = JsValue.jsUndefined()
    public var td: JsValue = JsValue.jsUndefined()
    public var em: JsValue = JsValue.jsUndefined()
    public var strong: JsValue = JsValue.jsUndefined()
    public var a: JsValue = JsValue.jsUndefined()
    public var img: JsValue = JsValue.jsUndefined()
    public var code: JsValue = JsValue.jsUndefined()
    public var del: JsValue = JsValue.jsUndefined()
    public var math: JsValue = JsValue.jsUndefined()
    public var u: JsValue = JsValue.jsUndefined()
    public var br: JsValue = JsValue.jsUndefined()

    public init() {}
}

/// 解析栈条目
/// 对应 Bun: ParseStackEntry
public class ParseStackEntry {
    public var children: JsValue = JsValue.jsUndefined()
    public var blockType: ?BlockType = None
    public var spanType: ?SpanType = None
    public var data: UInt32 = 0
    public var flags: UInt32 = 0
    public var detail: SpanDetail = SpanDetail()

    public init() {
    }

    public init(children: JsValue, blockType: ?BlockType, data: UInt32, flags: UInt32) {
        this.children = children
        this.blockType = blockType
        this.data = data
        this.flags = flags
    }
}

/// ParseRenderer - 将 Markdown 解析为 AST 对象树的渲染器
/// 对应 Bun: ParseRenderer
/// 在普通模式下，每个元素变为 { type, props }
/// 在 React 模式下，每个元素变为有效的 React 元素
public class ParseRenderer {
    public var globalObject: JsGlobalObject
    public var stack: ArrayList<ParseStackEntry>
    public var stackCheck: StackCheck
    public var srcText: String
    public var headingTracker: HeadingIdTracker
    public var components: Components
    public var reactVersion: ?UInt8 = None

    public init() {
        globalObject = JsGlobalObject.current()
        stack = ArrayList<ParseStackEntry>()
        stackCheck = StackCheck()
        srcText = ""
        headingTracker = HeadingIdTracker(false)
        components = Components()
    }

    /// 初始化渲染器
    /// 对应 Bun: ParseRenderer::init()
    public static func `init`(jsGlobalObject!: JsGlobalObject, srcText!: String, headingIds!: Bool, reactVersion!: UInt8): ?ParseRenderer {
        var self_ = ParseRenderer()
        self_.globalObject = globalObject
        self_.stack = ArrayList<ParseStackEntry>()
        self_.stackCheck = StackCheck()
        self_.srcText = srcText
        self_.headingTracker = HeadingIdTracker(headingIds)
        self_.components = Components()
        self_.reactVersion = reactVersion

        // 根条目 — 其 children 数组成为返回值
        let rootArrayOpt = JsValue.createEmptyArray(globalObject, 0)
        if (rootArrayOpt.isNone()) {
        return None
        }
        let rootArray = rootArrayOpt.get()
        var rootEntry = ParseStackEntry()
        rootEntry.children = rootArray
        rootEntry.blockType = BlockType.doc
        self_.stack.append(rootEntry)
        return self_
    }

    /// 提取组件覆盖
    /// 对应 Bun: ParseRenderer::extract_components()
    /// 任何非布尔值的 truthy 值（函数、类、字符串等）按 HTML 标签名索引存储
    public func extractComponents(opts!: JsValue): Unit {
        if (opts.isUndefinedOrNull() || !opts.isObject()) {
            return
        }

        // 提取所有组件覆盖 — 对应 Bun 的 extract! 宏
        let tagNames = ["h1", "h2", "h3", "h4", "h5", "h6", "p", "blockquote", "ul", "ol", "li",
                        "pre", "hr", "html", "table", "thead", "tbody", "tr", "th", "td", "em",
                        "strong", "a", "img", "code", "del", "math", "u", "br"]
        for (name in tagNames) {
            if (let val <- opts.getTruthy(globalObject, name) ) {
                if (!val.isBoolean()) {
                    setComponentField(name, val)
                }
            }
        }
    }

    /// 设置组件字段值
    private func setComponentField(name!: String, val!: JsValue): Unit {
        match (name) {
            case "h1" => components.h1 = val
            case "h2" => components.h2 = val
            case "h3" => components.h3 = val
            case "h4" => components.h4 = val
            case "h5" => components.h5 = val
            case "h6" => components.h6 = val
            case "p" => components.p = val
            case "blockquote" => components.blockquote = val
            case "ul" => components.ul = val
            case "ol" => components.ol = val
            case "li" => components.li = val
            case "pre" => components.pre = val
            case "hr" => components.hr = val
            case "html" => components.html = val
            case "table" => components.table = val
            case "thead" => components.thead = val
            case "tbody" => components.tbody = val
            case "tr" => components.tr = val
            case "th" => components.th = val
            case "td" => components.td = val
            case "em" => components.em = val
            case "strong" => components.strong = val
            case "a" => components.a = val
            case "img" => components.img = val
            case "code" => components.code = val
            case "del" => components.del = val
            case "math" => components.math = val
            case "u" => components.u = val
            case "br" => components.br = val
            case _ => ()
        }
    }

    /// 获取块级元素组件覆盖
    /// 对应 Bun: ParseRenderer::get_block_component()
    public func getBlockComponent(blockType!: BlockType, data!: UInt32): JsValue {
        match (blockType) {
            case BlockType.h =>
                match (data) {
                    case 1 => components.h1
                    case 2 => components.h2
                    case 3 => components.h3
                    case 4 => components.h4
                    case 5 => components.h5
                    case _ => components.h6
                }
            case BlockType.p => components.p
            case BlockType.`quote` => components.blockquote
            case BlockType.ul => components.ul
            case BlockType.ol => components.ol
            case BlockType.li => components.li
            case BlockType.code => components.pre
            case BlockType.hr => components.hr
            case BlockType.html => components.html
            case BlockType.table => components.table
            case BlockType.thead => components.thead
            case BlockType.tbody => components.tbody
            case BlockType.tr => components.tr
            case BlockType.th => components.th
            case BlockType.td => components.td
            case BlockType.doc => JsValue.jsUndefined()
            case _ => JsValue.jsUndefined()
        }
    }

    /// 获取行内元素组件覆盖
    /// 对应 Bun: ParseRenderer::get_span_component()
    public func getSpanComponent(spanType!: SpanType): JsValue {
        match (spanType) {
            case SpanType.em => components.em
            case SpanType.strong => components.strong
            case SpanType.a => components.a
            case SpanType.img => components.img
            case SpanType.code => components.code
            case SpanType.del => components.del
            case SpanType.latexmath => components.math
            case SpanType.latexmathDisplay => components.math
            case SpanType.wikilink => components.a
            case SpanType.u => components.u
            case _ => JsValue.jsUndefined()
        }
    }

    /// 获取渲染器实例
    /// 对应 Bun: ParseRenderer::renderer()
    public func renderer(): Renderer {
        let r = Renderer()
        r.ptr = UIntNative(this.hashCode())
        // 设置 vtable 回调
        r.vtable = VTable(
            enterBlock: { ptr, blockType, data, flags =>
                let self_ = ParseRenderer.fromPtr(ptr)
                self_.enterBlockImpl(blockType, data, flags)
            },
            leaveBlock: { ptr, blockType, data =>
                let self_ = ParseRenderer.fromPtr(ptr)
                self_.leaveBlockImpl(blockType, data)
            },
            enterSpan: { ptr, spanType, detail =>
                let self_ = ParseRenderer.fromPtr(ptr)
                self_.enterSpanImpl(spanType, detail)
            },
            leaveSpan: { ptr, spanType =>
                let self_ = ParseRenderer.fromPtr(ptr)
                self_.leaveSpanImpl(spanType)
            },
            text: { ptr, textType, content =>
                let self_ = ParseRenderer.fromPtr(ptr)
                self_.textImpl(textType, content)
            },
        )
        return r
    }

    /// 从指针恢复实例
    public static func fromPtr(ptr!: UIntNative): ParseRenderer {
        // 在仓颉中通过哈希码映射恢复引用
        // 实际实现通过全局注册表
        ParseRendererRegistry.get(ptr)
    }

    /// 获取最终结果
    /// 对应 Bun: ParseRenderer::get_result()
    public func getResult(): JsValue {
        if (stack.isEmpty()) {
            return JsValue.jsUndefined()
        }
        return stack[0].children
    }

    /// 创建元素节点
    /// 对应 Bun: ParseRenderer::create_element()
    /// 在 React 模式下使用 C++ 快速路径，在普通模式下创建简单的 { type, props } 对象
    public func createElement(typeVal!: JsValue, props!: JsValue): JsValue {
        if (let version <- reactVersion) {
            let obj = JSReactElement.create(globalObject, version, typeVal, props)
            return obj
        } else {
            let obj = JsValue.createEmptyObject(globalObject, 2)
            obj.put(globalObject, "type", typeVal)
            obj.put(globalObject, "props", props)
            return obj
        }
    }

    // ========================================================================
    // 块级元素回调
    // 对应 Bun: ParseRenderer::enter_block_impl / leave_block_impl
    // ========================================================================

    /// 进入块级元素
    public func enterBlockImpl(blockType!: BlockType, data!: UInt32, flags!: UInt32): Unit {
        if (!stackCheck.isSafeToRecurse()) {
            globalThis.throwStackOverflow()
            return
        }
        if (blockType == BlockType.doc) {
            return
        }

        if (blockType == BlockType.h) {
            headingTracker.enterHeading()
        }

        let arrayOpt = JsValue.createEmptyArray(globalObject, 0)
        if (arrayOpt.isNone()) {
        return
        }
        let array = arrayOpt.get()
        var entry = ParseStackEntry()
        entry.children = array
        entry.blockType = blockType
        entry.data = data
        entry.flags = flags
        stack.append(entry)
    }

    /// 离开块级元素
    public func leaveBlockImpl(blockType!: BlockType, data!: UInt32): Unit {
        if (!stackCheck.isSafeToRecurse()) {
            globalObject.throwStackOverflow()
            return
        }
        if (blockType == BlockType.doc) {
            return
        }

        if (stack.size() <= 1) {
            return
        }
        let entry = stack.removeAt(stack.size() - 1)
        let g = globalObject

        // 确定标签索引
        let tagIndex = getBlockTypeTag(blockType, entry.data)

        // 对标题，在计算 props 之前计算 slug
        var slug: ?String = None
        if (blockType == BlockType.h) {
            slug = headingTracker.leaveHeading()
        }

        // 计算 props 字段数
        var propsCount: Int64 = if (blockType == BlockType.hr) { 0 } else { 1 } // children
        match (blockType) {
            case BlockType.h =>
                if (slug.isSome()) {
                    propsCount += 1
                }
            case BlockType.ol => propsCount += 1 // start
            case BlockType.li =>
                let taskMark = taskMarkFromData(entry.data)
                if (taskMark != 0) {
                    propsCount += 1
                }
            case BlockType.code =>
                if ((entry.flags & BLOCK_FENCED_CODE) != 0) {
                    let lang = extractLanguage(srcText, entry.data)
                    if (lang.size > 0) {
                        propsCount += 1
                    }
                }
            case BlockType.th =>
                let alignment = alignmentFromData(entry.data)
                if (alignment != Align.`default`) {
                    propsCount += 1
                }
            case BlockType.td =>
                let alignment = alignmentFromData(entry.data)
                if (alignment != Align.`default`) {
                    propsCount += 1
                }
            case _ => ()
        }

        // 构建 React 元素 — 使用组件覆盖作为 type（如果已设置）
        let component = getBlockComponent(blockType, entry.data)
        let typeVal: JsValue = if (!component.isEmpty()) {
            component
        } else {
            getCachedTagString(g, tagIndex)
        }

        let props = JsValue.createEmptyObject(g, UInt64(propsCount))

        // 设置元数据 props
        match (blockType) {
            case BlockType.h =>
                if (let Some(s) <- slug) {
                    props.put(g, "id", createUtf8ForJs(g, s))
                }
            case BlockType.ol =>
                props.put(g, "start", JsValue.jsNumber(Float64(data)))
            case BlockType.li =>
                let taskMark = taskMarkFromData(entry.data)
                if (taskMark != 0) {
                    props.put(g, "checked", JsValue.from(isTaskChecked(taskMark)))
                }
            case BlockType.code =>
                if ((entry.flags & BLOCK_FENCED_CODE) != 0) {
                    let lang = extractLanguage(srcText, entry.data)
                    if (lang.size > 0) {
                        props.put(g, "language", createUtf8ForJs(g, lang))
                    }
                }
            case BlockType.th =>
                let alignment = alignmentFromData(entry.data)
                if (let Some(alignStr) <- alignmentName(alignment)) {
                    props.put(g, "align", createUtf8ForJs(g, alignStr))
                }
            case BlockType.td =>
                let alignment = alignmentFromData(entry.data)
                if (let Some(alignStr) <- alignmentName(alignment)) {
                    props.put(g, "align", createUtf8ForJs(g, alignStr))
                }
            case _ => ()
        }

        // 设置 children（void 元素跳过）
        if (blockType != BlockType.hr) {
            props.put(g, "children", entry.children)
        }

        let obj = createElement(typeVal, props)

        // 添加到父级的 children 数组
        if (stack.size() > 0) {
            let parent = stack[stack.size() - 1]
            jsArrayPush(parent.children, g, obj)
        }

        if (blockType == BlockType.h) {
            headingTracker.clearAfterHeading()
        }
    }

    // ========================================================================
    // 行内元素回调
    // 对应 Bun: ParseRenderer::enter_span_impl / leave_span_impl
    // ========================================================================

    /// 进入行内元素
    public func enterSpanImpl(spanType!: SpanType, detail!: SpanDetail): Unit {
        if (!stackCheck.isSafeToRecurse()) {
            globalObject.throwStackOverflow()
            return
        }

        let arrayOpt = JsValue.createEmptyArray(globalObject, 0)
        if (arrayOpt.isNone()) {
        return
        }
        let array = arrayOpt.get()
        var entry = ParseStackEntry()
        entry.children = array
        entry.detail = detail
        stack.append(entry)
    }

    /// 离开行内元素
    public func leaveSpanImpl(spanType!: SpanType): Unit {
        if (!stackCheck.isSafeToRecurse()) {
            globalObject.throwStackOverflow()
            return
        }

        if (stack.size() <= 1) {
            return
        }
        let entry = stack.removeAt(stack.size() - 1)
        let g = globalObject

        let tagIndex = getSpanTypeTag(spanType)

        // 计算 props 字段数
        var propsCount: Int64 = 1 // children（或 img 的 alt）
        match (spanType) {
            case SpanType.a =>
                propsCount += 1 // href
                if (entry.detail.title.size > 0) {
                    propsCount += 1
                }
            case SpanType.img =>
                propsCount += 1 // src
                if (entry.detail.title.size > 0) {
                    propsCount += 1
                }
            case SpanType.wikilink => propsCount += 1 // target
            case SpanType.latexmathDisplay => propsCount += 1 // display
            case _ => ()
        }

        // 构建 React 元素
        let component = getSpanComponent(spanType)
        let typeVal: JsValue = if (!component.isEmpty()) {
            component
        } else {
            getCachedTagString(g, tagIndex)
        }

        let props = JsValue.createEmptyObject(g, UInt64(propsCount))

        // 设置元数据 props
        match (spanType) {
            case SpanType.a =>
                props.put(g, "href", createUtf8ForJs(g, entry.detail.href))
                if (entry.detail.title.size > 0) {
                    props.put(g, "title", createUtf8ForJs(g, entry.detail.title))
                }
            case SpanType.img =>
                props.put(g, "src", createUtf8ForJs(g, entry.detail.href))
                if (entry.detail.title.size > 0) {
                    props.put(g, "title", createUtf8ForJs(g, entry.detail.title))
                }
            case SpanType.wikilink =>
                props.put(g, "target", createUtf8ForJs(g, entry.detail.href))
            case SpanType.latexmathDisplay =>
                props.put(g, "display", JsValue.from(true))
            case _ => ()
        }

        if (spanType == SpanType.img) {
            // img 是 void 元素 — 将 children 转换为 alt prop
            let len = entry.children.getLength(g)
            if (len == 1) {
                let child = entry.children.getIndex(g, 0)  ?? JsValue.jsUndefined()
                if (child.isString()) {
                    props.put(g, "alt", child)
                }
            } else if (len > 1) {
                // 多个子元素 — 拼接字符串部分
                var altBuf = StringBuilder()
                for (i in 0..len) {
                    let child = entry.children.getIndex(g, UInt32(i) ) ?? JsValue.jsUndefined()
                    if (child.isString()) {
                        let str = child.toSlice(g)
                        altBuf.append(str)
                    }
                }
                let altStr = altBuf.toString()
                if (altStr.size > 0) {
                    props.put(g, "alt", createUtf8ForJs(g, altStr))
                }
            }
        } else {
            props.put(g, "children", entry.children)
        }

        let obj = createElement(typeVal, props)

        // 添加到父级的 children 数组
        if (stack.size() > 0) {
            let parent = stack[stack.size() - 1]
            jsArrayPush(parent.children, g, obj)
        }
    }

    // ========================================================================
    // 文本回调
    // 对应 Bun: ParseRenderer::text_impl
    // ========================================================================

    /// 处理文本内容
    public func textImpl(textType!: TextType, content!: String): Unit {
        if (!stackCheck.isSafeToRecurse()) {
            globalObject.throwStackOverflow()
            return
        }

        let g = globalObject

        // 在标题内跟踪纯文本用于 slug 生成
        headingTracker.trackText(textType, content)

        if (stack.isEmpty()) {
            return
        }
        let parentChildren = stack[stack.size() - 1].children

        match (textType) {
            case TextType.br =>
                let brComponent = components.br
                let brType: JsValue = if (!brComponent.isEmpty()) {
                    brComponent
                } else {
                    getCachedTagString(g, TagIndex.br)
                }
                let emptyProps = JsValue.createEmptyObject(g, 0)
                let obj = createElement(brType, emptyProps)
                jsArrayPush(parentChildren, g, obj)
            case TextType.softbr =>
                let str = createUtf8ForJs(g, "\n")
                jsArrayPush(parentChildren, g, str)
            case TextType.nullChar =>
                let str = createUtf8ForJs(g, "\u{fffd}")
                jsArrayPush(parentChildren, g, str)
            case TextType.entity =>
                // 尝试解码 HTML 实体
                if (let decoded <- decodeEntityToUtf8(content)) {
                    let str = createUtf8ForJs(g, decoded)
                    jsArrayPush(parentChildren, g, str)
                } else {
                    let str = createUtf8ForJs(g, content)
                    jsArrayPush(parentChildren, g, str)
                }
            case _ =>
                let str = createUtf8ForJs(g, content)
                jsArrayPush(parentChildren, g, str)
        }
    }
}

// ============================================================================
// JsCallbackRenderer - 使用 JS 回调渲染 Markdown
// 对应 Bun: JsCallbackRenderer struct
// 使用内容栈模式: 每个 enter 推入新缓冲区, text 追加到顶部缓冲区,
// 每个 leave 弹出缓冲区, 用累积的子元素调用 JS 回调, 并将回调返回值追加到父缓冲区
// ============================================================================

/// 回调函数集合
/// 对应 Bun: Callbacks
public class Callbacks {
    public var heading: JsValue = JsValue.jsUndefined()
    public var paragraph: JsValue = JsValue.jsUndefined()
    public var blockquote: JsValue = JsValue.jsUndefined()
    public var code: JsValue = JsValue.jsUndefined()
    public var list: JsValue = JsValue.jsUndefined()
    public var listItem: JsValue = JsValue.jsUndefined()
    public var hr: JsValue = JsValue.jsUndefined()
    public var table: JsValue = JsValue.jsUndefined()
    public var thead: JsValue = JsValue.jsUndefined()
    public var tbody: JsValue = JsValue.jsUndefined()
    public var tr: JsValue = JsValue.jsUndefined()
    public var th: JsValue = JsValue.jsUndefined()
    public var td: JsValue = JsValue.jsUndefined()
    public var html: JsValue = JsValue.jsUndefined()
    public var strong: JsValue = JsValue.jsUndefined()
    public var emphasis: JsValue = JsValue.jsUndefined()
    public var link: JsValue = JsValue.jsUndefined()
    public var image: JsValue = JsValue.jsUndefined()
    public var codespan: JsValue = JsValue.jsUndefined()
    public var strikethrough: JsValue = JsValue.jsUndefined()
    public var text: JsValue = JsValue.jsUndefined()

    public init() {}
}

/// 回调栈条目
/// 对应 Bun: CallbackStackEntry
public class CallbackStackEntry {
    public var buffer: StringBuilder = StringBuilder()
    public var blockType: BlockType = BlockType.doc
    public var data: UInt32 = 0
    public var flags: UInt32 = 0
    /// 对于 ul/ol: 已看到的 li 子元素数量（下一个 li 的索引）
    /// 对于 li: 此项在其父列表中的从 0 开始的索引
    public var childIndex: UInt32 = 0
    public var detail: SpanDetail = SpanDetail()

    public init() {
    }

    public init(blockType: BlockType, data: UInt32, flags: UInt32, childIndex: UInt32) {
        this.blockType = blockType
        this.data = data
        this.flags = flags
        this.childIndex = childIndex
    }
}

/// JsCallbackRenderer - 使用 JS 回调渲染 Markdown
/// 对应 Bun: JsCallbackRenderer
public class JsCallbackRenderer {
    public var globalObject: JsGlobalObject
    public var srcText: String
    public var stack: ArrayList<CallbackStackEntry>
    public var callbacks: Callbacks
    public var headingTracker: HeadingIdTracker
    public var stackCheck: StackCheck

    public init() {
        globalObject = JsGlobalObject.current()
        srcText = ""
        stack = ArrayList<CallbackStackEntry>()
        callbacks = Callbacks()
        headingTracker = HeadingIdTracker(false)
        stackCheck = StackCheck()
    }

    /// 初始化
    /// 对应 Bun: JsCallbackRenderer::init()
    public static func `init`(jsGlobalObject!: JsGlobalObject, srcText!: String, headingIds!: Bool): ?JsCallbackRenderer {
        var self_ = JsCallbackRenderer()
        self_.globalObject = globalObject
        self_.srcText = srcText
        self_.stack = ArrayList<CallbackStackEntry>()
        self_.callbacks = Callbacks()
        self_.headingTracker = HeadingIdTracker(headingIds)
        self_.stackCheck = StackCheck()

        // 推入根条目
        self_.stack.append(CallbackStackEntry())
        return self_
    }

    /// 提取回调函数
    /// 对应 Bun: JsCallbackRenderer::extract_callbacks()
    public func extractCallbacks(opts!: JsValue): Unit {
        if (opts.isUndefinedOrNull() || !opts.isObject()) {
            return
        }

        // 对应 Bun 的 extract! 宏 — 检查每个回调键是否为可调用函数
        let callbackMap = [
            ("heading", "heading"),
            ("paragraph", "paragraph"),
            ("blockquote", "blockquote"),
            ("code", "code"),
            ("list", "list"),
            ("listItem", "listItem"),
            ("hr", "hr"),
            ("table", "table"),
            ("thead", "thead"),
            ("tbody", "tbody"),
            ("tr", "tr"),
            ("th", "th"),
            ("td", "td"),
            ("html", "html"),
            ("strong", "strong"),
            ("emphasis", "emphasis"),
            ("link", "link"),
            ("image", "image"),
            ("codespan", "codespan"),
            ("strikethrough", "strikethrough"),
            ("text", "text")
        ]

        for ((fieldName, jsKey) in callbackMap) {
            if (let val <- opts.getTruthy(globalObject, jsKey) ) {
                if (val.isCallable()) {
                    setCallbackField(fieldName, val)
                }
            }
        }
    }

    /// 设置回调字段
    private func setCallbackField(name!: String, val!: JsValue): Unit {
        match (name) {
            case "heading" => callbacks.heading = val
            case "paragraph" => callbacks.paragraph = val
            case "blockquote" => callbacks.blockquote = val
            case "code" => callbacks.code = val
            case "list" => callbacks.list = val
            case "listItem" => callbacks.listItem = val
            case "hr" => callbacks.hr = val
            case "table" => callbacks.table = val
            case "thead" => callbacks.thead = val
            case "tbody" => callbacks.tbody = val
            case "tr" => callbacks.tr = val
            case "th" => callbacks.th = val
            case "td" => callbacks.td = val
            case "html" => callbacks.html = val
            case "strong" => callbacks.strong = val
            case "emphasis" => callbacks.emphasis = val
            case "link" => callbacks.link = val
            case "image" => callbacks.image = val
            case "codespan" => callbacks.codespan = val
            case "strikethrough" => callbacks.strikethrough = val
            case "text" => callbacks.text = val
            case _ => ()
        }
    }

    /// 获取渲染器实例
    /// 对应 Bun: JsCallbackRenderer::renderer()
    public func renderer(): Renderer {
        let r = Renderer()
        r.ptr = UIntNative(this.hashCode())
        r.vtable = VTable(
            enterBlock: { ptr, blockType, data, flags =>
                let self_ = JsCallbackRenderer.fromPtr(ptr)
                self_.enterBlockImpl(blockType, data, flags)
            },
            leaveBlock: { ptr, blockType, data =>
                let self_ = JsCallbackRenderer.fromPtr(ptr)
                self_.leaveBlockImpl(blockType, data)
            },
            enterSpan: { ptr, spanType, detail =>
                let self_ = JsCallbackRenderer.fromPtr(ptr)
                self_.enterSpanImpl(spanType, detail)
            },
            leaveSpan: { ptr, spanType =>
                let self_ = JsCallbackRenderer.fromPtr(ptr)
                self_.leaveSpanImpl(spanType)
            },
            text: { ptr, textType, content =>
                let self_ = JsCallbackRenderer.fromPtr(ptr)
                self_.textImpl(textType, content)
            },
        )
        return r
    }

    /// 从指针恢复实例
    public static func fromPtr(ptr!: UIntNative): JsCallbackRenderer {
        JsCallbackRendererRegistry.get(ptr)
    }

    // ========================================================================
    // 内容栈操作
    // 对应 Bun: append_to_top / pop_and_callback / get_result
    // ========================================================================

    /// 追加数据到顶部缓冲区
    /// 对应 Bun: append_to_top()
    public func appendToTop(data!: String): Unit {
        if (stack.size() > 0) {
            stack[stack.size() - 1].buffer.append(data)
        }
    }

    /// 弹出栈顶并调用回调
    /// 对应 Bun: pop_and_callback()
    public func popAndCallback(callback!: JsValue, meta!: ?JsValue): Unit {
        if (stack.size() <= 1) {
            return // 不弹出根条目
        }
        let entry = stack.removeAt(stack.size() - 1)

        let children = entry.buffer.toString()

        if (callback.isEmpty()) {
            // 没有注册回调 — 将子元素直接传递给父级
            appendToTop(children)
            return
        }

        if (!stackCheck.isSafeToRecurse()) {
            globalObject.throwStackOverflow()
            return
        }

        // 将子元素转换为 JS 字符串
        let childrenJs = createUtf8ForJs(globalObject, children)

        // 调用 JS 回调
        let result = if (let Some(m) <- meta) {
            callback.call(globalObject, JsValue.jsUndefined(), [childrenJs, m])
        } else {
            callback.call(globalObject, JsValue.jsUndefined(), [childrenJs])
        }

        if (result.isUndefinedOrNull()) {
            return // 回调返回 null/undefined → 省略元素
        }
        let slice = result.toSlice(globalObject)
        appendToTop(slice)
    }

    /// 获取最终结果
    /// 对应 Bun: get_result()
    public func getResult(): String {
        if (stack.isEmpty()) {
            return ""
        }
        return stack[0].buffer.toString()
    }

    // ========================================================================
    // RendererImpl 实现
    // 对应 Bun: JsCallbackRenderer 的 enter_block/leave_block/enter_span/leave_span/text
    // ========================================================================

    /// 进入块级元素
    /// 对应 Bun: enter_block_impl()
    public func enterBlockImpl(blockType!: BlockType, data!: UInt32, flags!: UInt32): Unit {
        if (!stackCheck.isSafeToRecurse()) {
            globalObject.throwStackOverflow()
            return
        }
        if (blockType == BlockType.doc) {
            return
        }
        if (blockType == BlockType.h) {
            headingTracker.enterHeading()
        }

        // 对于 li: 记录其在父列表中的从 0 开始的索引，然后递增父级计数器
        var childIndex: UInt32 = 0
        if (blockType == BlockType.li && !stack.isEmpty()) {
            let parent = stack[stack.size() - 1]
            childIndex = parent.childIndex
            parent.childIndex = parent.childIndex + 1
        }

        var entry = CallbackStackEntry(blockType, data, flags, childIndex)
        stack.append(entry)
    }

    /// 离开块级元素
    /// 对应 Bun: leave_block_impl()
    public func leaveBlockImpl(blockType!: BlockType, data!: UInt32): Unit {
        if (!stackCheck.isSafeToRecurse()) {
            globalObject.throwStackOverflow()
            return
        }
        if (blockType == BlockType.doc) {
            return
        }

        let callback = getBlockCallback(blockType)
        // 保存栈顶信息用于创建元数据
        var savedData: UInt32 = 0
        var savedFlags: UInt32 = 0
        var savedChildIndex: UInt32 = 0
        if (stack.size() > 1) {
            let top = stack[stack.size() - 1]
            savedData = top.data
            savedFlags = top.flags
            savedChildIndex = top.childIndex
        }

        let meta = createBlockMeta(blockType, savedData, savedFlags, savedChildIndex) 
        popAndCallback(callback, meta)

        if (blockType == BlockType.h) {
            headingTracker.clearAfterHeading()
        }
    }

    /// 进入行内元素
    /// 对应 Bun: enter_span_impl()
    public func enterSpanImpl(spanType!: SpanType, detail!: SpanDetail): Unit {
        if (!stackCheck.isSafeToRecurse()) {
            globalObject.throwStackOverflow()
            return
        }
        var entry = CallbackStackEntry()
        entry.detail = detail
        stack.append(entry)
    }

    /// 离开行内元素
    /// 对应 Bun: leave_span_impl()
    public func leaveSpanImpl(spanType!: SpanType): Unit {
        if (!stackCheck.isSafeToRecurse()) {
            globalObject.throwStackOverflow()
            return
        }

        let callback = getSpanCallback(spanType)
        var detail = SpanDetail()
        if (stack.size() > 1) {
            detail = stack[stack.size() - 1].detail
        }
        let meta = createSpanMeta(spanType, detail) 
        popAndCallback(callback, meta)
    }

    /// 处理文本
    /// 对应 Bun: text_impl()
    public func textImpl(textType!: TextType, content!: String): Unit {
        if (!stackCheck.isSafeToRecurse()) {
            globalObject.throwStackOverflow()
            return
        }

        // 在标题内跟踪纯文本用于 slug 生成
        headingTracker.trackText(textType, content)

        match (textType) {
            case TextType.nullChar => appendToTop("\u{fffd}")
            case TextType.br => appendToTop("\n")
            case TextType.softbr => appendToTop("\n")
            case TextType.entity => decodeAndAppendEntity(content)
            case _ =>
                if (!callbacks.text.isEmpty()) {
                    callTextCallback(content)
                } else {
                    appendToTop(content)
                }
        }
    }

    // ========================================================================
    // 文本辅助函数
    // 对应 Bun: call_text_callback / decode_and_append_entity / append_text_or_raw
    // ========================================================================

    /// 调用文本回调
    /// 对应 Bun: call_text_callback()
    public func callTextCallback(content!: String): Unit {
        if (!stackCheck.isSafeToRecurse()) {
            globalObject.throwStackOverflow()
            return
        }
        let textJs = createUtf8ForJs(globalObject, content)
        let result = callbacks.text.call(globalObject, JsValue.jsUndefined(), [textJs])
        if (!result.isUndefinedOrNull()) {
            let slice = result.toSlice(globalObject)
            appendToTop(slice)
        }
    }

    /// 解码并追加 HTML 实体
    /// 对应 Bun: decode_and_append_entity()
    public func decodeAndAppendEntity(entityText!: String): Unit {
        if (let decoded <- decodeEntityToUtf8(entityText)) {
            appendTextOrRaw(decoded)
        } else {
            appendTextOrRaw(entityText)
        }
    }

    /// 通过文本回调追加文本（如果已设置），否则直接追加
    /// 对应 Bun: append_text_or_raw()
    public func appendTextOrRaw(content!: String): Unit {
        if (!callbacks.text.isEmpty()) {
            callTextCallback(content)
        } else {
            appendToTop(content)
        }
    }

    // ========================================================================
    // 回调查找
    // 对应 Bun: get_block_callback / get_span_callback
    // ========================================================================

    /// 获取块级元素的回调函数
    /// 对应 Bun: get_block_callback()
    public func getBlockCallback(blockType!: BlockType): JsValue {
        match (blockType) {
            case BlockType.h => callbacks.heading
            case BlockType.p => callbacks.paragraph
            case BlockType.`quote` => callbacks.blockquote
            case BlockType.code => callbacks.code
            case BlockType.ul => callbacks.list
            case BlockType.ol => callbacks.list
            case BlockType.li => callbacks.listItem
            case BlockType.hr => callbacks.hr
            case BlockType.table => callbacks.table
            case BlockType.thead => callbacks.thead
            case BlockType.tbody => callbacks.tbody
            case BlockType.tr => callbacks.tr
            case BlockType.th => callbacks.th
            case BlockType.td => callbacks.td
            case BlockType.html => callbacks.html
            case BlockType.doc => JsValue.jsUndefined()
            case _ => JsValue.jsUndefined()
        }
    }

    /// 获取行内元素的回调函数
    /// 对应 Bun: get_span_callback()
    public func getSpanCallback(spanType!: SpanType): JsValue {
        match (spanType) {
            case SpanType.em => callbacks.emphasis
            case SpanType.strong => callbacks.strong
            case SpanType.a => callbacks.link
            case SpanType.img => callbacks.image
            case SpanType.code => callbacks.codespan
            case SpanType.del => callbacks.strikethrough
            case _ => JsValue.jsUndefined()
        }
    }

    // ========================================================================
    // 元数据对象创建
    // 对应 Bun: create_block_meta / create_span_meta / count_list_depth / parent_list
    // ========================================================================

    /// 计算栈中包围的 ul/ol 块的数量
    /// 对应 Bun: count_list_depth()
    public func countListDepth(): UInt32 {
        var depth: UInt32 = 0
        let len = stack.size()
        if (len < 2) {
            return 0
        }
        // 跳过栈顶条目（自身） — 只计算包围的列表
        for (i in 0..(len - 1)) {
            let entry = stack[i]
            if (entry.blockType == BlockType.ul || entry.blockType == BlockType.ol) {
                depth += 1
            }
        }
        return depth
    }

    /// 获取当前 li 的父 ul/ol 条目
    /// 对应 Bun: parent_list()
    public func parentList(): ?CallbackStackEntry {
        let len = stack.size()
        if (len < 2) {
            return None
        }
        let parent = stack[len - 2]
        if (parent.blockType == BlockType.ul || parent.blockType == BlockType.ol) {
            return Some(parent)
        }
        return None
    }

    /// 创建块级元素的元数据对象
    /// 对应 Bun: create_block_meta()
    public func createBlockMeta(blockType!: BlockType, data!: UInt32, flags!: UInt32, childIndex!: UInt32): ?JsValue {
        let g = globalObject
        match (blockType) {
            case BlockType.h =>
                let slug = headingTracker.leaveHeading()
                let fieldCount: Int64 = if (slug.isSome()) { 2 } else { 1 }
                let obj = JsValue.createEmptyObject(g, UInt64(fieldCount))
                obj.put(g, "level", JsValue.jsNumber(Float64(data)))
                if (let Some(s) <- slug) {
                    obj.put(g, "id", createUtf8ForJs(g, s))
                }
                return obj
            case BlockType.ol =>
                return BunMarkdownMeta.createList(g, true, JsValue.jsNumber(Float64(data)), countListDepth())
            case BlockType.ul =>
                return BunMarkdownMeta.createList(g, false, JsValue.jsUndefined(), countListDepth())
            case BlockType.code =>
                if ((flags & BLOCK_FENCED_CODE) != 0) {
                    let lang = extractLanguage(srcText, data)
                    if (lang.size > 0) {
                        let obj = JsValue.createEmptyObject(g, 1)
                        obj.put(g, "language", createUtf8ForJs(g, lang))
                        return obj
                    }
                }
                return None
            case BlockType.th =>
                let alignment = alignmentFromData(data)
                let alignJs = if (let Some(alignStr) <- alignmentName(alignment)) {
                    createUtf8ForJs(g, alignStr)
                } else {
                    JsValue.jsUndefined()
                }
                return BunMarkdownMeta.createCell(g, alignJs)
            case BlockType.td =>
                let alignment = alignmentFromData(data)
                let alignJs = if (let Some(alignStr) <- alignmentName(alignment)) {
                    createUtf8ForJs(g, alignStr)
                } else {
                    JsValue.jsUndefined()
                }
                return BunMarkdownMeta.createCell(g, alignJs)
            case BlockType.li =>
                // li 条目仍在栈顶；父 ul/ol 在 len-2
                let len = stack.size()
                let itemIndex = if (len > 1) {
                    stack[len - 1].childIndex
                } else {
                    UInt32(0)
                }
                let parent = parentList()
                let isOrdered = parent.isSome() && parent.getOrThrow().blockType == BlockType.ol
                // count_list_depth() 包含直接父列表；减去它使顶级列表中的项报告 depth 0
                let enclosing = countListDepth()
                let depth: UInt32 = if (enclosing > 0) { enclosing - 1 } else { UInt32(0) }
                let taskMark = taskMarkFromData(data)

                let startJs = if (isOrdered) {
                    JsValue.jsNumber(Float64(parent.getOrThrow().data))
                } else {
                    JsValue.jsUndefined()
                }
                let checkedJs = if (taskMark != 0) {
                    JsValue.from(isTaskChecked(taskMark))
                } else {
                    JsValue.jsUndefined()
                }

                return BunMarkdownMeta.createListItem(g, itemIndex, depth, isOrdered, startJs, checkedJs)
            case _ => return None
        }
    }

    /// 创建行内元素的元数据对象
    /// 对应 Bun: create_span_meta()
    public func createSpanMeta(spanType!: SpanType, detail!: SpanDetail): ?JsValue {
        let g = globalObject
        match (spanType) {
            case SpanType.a =>
                let href = createUtf8ForJs(g, detail.href)
                let title = if (detail.title.size > 0) {
                    createUtf8ForJs(g, detail.title)
                } else {
                    JsValue.jsUndefined()
                }
                return BunMarkdownMeta.createLink(g, href, title)
            case SpanType.img =>
                // 图片元数据与链接共享形状 (src/href 都是第一个字段)
                let obj = JsValue.createEmptyObject(g, 2)
                obj.put(g, "src", createUtf8ForJs(g, detail.href))
                if (detail.title.size > 0) {
                    obj.put(g, "title", createUtf8ForJs(g, detail.title))
                }
                return obj
            case _ => return None
        }
    }
}

// ============================================================================
// 外部绑定声明
// 对应 Bun: unsafe extern "C" 声明
// ============================================================================

/// React 元素创建（FFI 绑定）
/// 对应 Bun: JSReactElement__create / JSReactElement__createFragment
public class JSReactElement {
    /// 创建 React 元素
    public static func create(global!: JsGlobalObject, reactVersion!: UInt8, elementType!: JsValue, props!: JsValue): JsValue {
        // FFI 绑定 — 在 C++ 层使用缓存的 Structure 和 putDirectOffset
        return jsReactElementCreate(global, reactVersion, elementType, props)
    }

    /// 创建 React Fragment
    public static func createFragment(global!: JsGlobalObject, reactVersion!: UInt8, children!: JsValue): JsValue {
        return jsReactElementCreateFragment(global, reactVersion, children)
    }
}

/// Markdown 标签字符串缓存（FFI 绑定）
/// 对应 Bun: BunMarkdownTagStrings__getTagString
public class BunMarkdownTagStrings {
    public static func getTagString(global!: JsGlobalObject, index!: UInt8): JsValue {
        return bunMarkdownGetTagString(global, index)
    }
}

/// Markdown 元数据快速创建（FFI 绑定）
/// 对应 Bun: BunMarkdownMeta__createListItem / createList / createCell / createLink
public class BunMarkdownMeta {
    /// 创建列表项元数据
    public static func createListItem(global!: JsGlobalObject, index!: UInt32, depth!: UInt32,
                                       ordered!: Bool, start!: JsValue, checked!: JsValue): JsValue {
        return bunMarkdownCreateListItem(global, index, depth, ordered, start, checked)
    }

    /// 创建列表元数据
    public static func createList(global!: JsGlobalObject, ordered!: Bool, start!: JsValue,
                                   depth!: UInt32): JsValue {
        return bunMarkdownCreateList(global, ordered, start, depth)
    }

    /// 创建单元格元数据
    public static func createCell(global!: JsGlobalObject, align!: JsValue): JsValue {
        return bunMarkdownCreateCell(global, align)
    }

    /// 创建链接元数据
    public static func createLink(global!: JsGlobalObject, href!: JsValue, title!: JsValue): JsValue {
        return bunMarkdownCreateLink(global, href, title)
    }
}

/// 栈安全检查
/// 对应 Bun: bun_core::StackCheck
public class StackCheck {
    private var depth: Int64 = 0
    private static let MAX_DEPTH: Int64 = 256

    public init() {}

    public static func `init`(): StackCheck {
        StackCheck()
    }

    public func isSafeToRecurse(): Bool {
        return depth < StackCheck.MAX_DEPTH
    }

    public func enter(): Unit {
        depth += 1
    }

    public func leave(): Unit {
        depth -= 1
    }
}

/// 渲染器注册表 — 将指针映射到渲染器实例
/// 用于通过 VTable 回调恢复 this 引用
public class ParseRendererRegistry {
    private static var registry: HashMap<UIntNative, ParseRenderer> = HashMap<UIntNative, ParseRenderer>()

    public static func register(ptr!: UIntNative, renderer!: ParseRenderer): Unit {
        registry.put(ptr, renderer)
    }

    public static func `get`(ptr!: UIntNative): ParseRenderer {
        registry.getOrThrow(ptr)
    }

    public static func unregister(ptr!: UIntNative): Unit {
        registry.remove(ptr)
    }
}

/// JS 回调渲染器注册表
public class JsCallbackRendererRegistry {
    private static var registry: HashMap<UIntNative, JsCallbackRenderer> = HashMap<UIntNative, JsCallbackRenderer>()

    public static func register(ptr!: UIntNative, renderer!: JsCallbackRenderer): Unit {
        registry.put(ptr, renderer)
    }

    public static func `get`(ptr!: UIntNative): JsCallbackRenderer {
        registry.getOrThrow(ptr)
    }

    public static func unregister(ptr!: UIntNative): Unit {
        registry.remove(ptr)
    }
}

// ============================================================================
// FFI 外部函数声明
// 对应 Bun: unsafe extern "C" 块
// ============================================================================

@C
foreign func jsReactElementCreate(global!: JsGlobalObject, reactVersion!: UInt8, elementType!: JsValue, props!: JsValue): JsValue

@C
foreign func jsReactElementCreateFragment(global!: JsGlobalObject, reactVersion!: UInt8, children!: JsValue): JsValue

@C
foreign func bunMarkdownGetTagString(global!: JsGlobalObject, index!: UInt8): JsValue

@C
foreign func bunMarkdownCreateListItem(global!: JsGlobalObject, index!: UInt32, depth!: UInt32,
                                          ordered!: Bool, start!: JsValue, checked!: JsValue): JsValue

@C
foreign func bunMarkdownCreateList(global!: JsGlobalObject, ordered!: Bool, start!: JsValue,
                                      depth!: UInt32): JsValue

@C
foreign func bunMarkdownCreateCell(global!: JsGlobalObject, align!: JsValue): JsValue

@C
foreign func bunMarkdownCreateLink(global!: JsGlobalObject, href!: JsValue, title!: JsValue): JsValue
