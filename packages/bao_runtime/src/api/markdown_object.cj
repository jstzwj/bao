// 严格翻译自: src/runtime/api/MarkdownObject.zig
// MarkdownObject — Bun.markdown 全局对象, 提供 html/ansi/render/react 方法
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame, CallFrame, JsObject, JsFunction}
import bao_core.Allocator
import bao_collections.ArrayList

// Helper: convert ArrayList<JsValue> to JS array
func arrayListToJsArray(list: ArrayList<JsValue>): JsValue {
    let arr = JsValue.createEmptyArray(JsObject(), Int64(list.size))
    for (i in 0..list.size) {
        arr.putIndex(JsObject(), UInt32(i), list[Int64(i)])
    }
    arr
}

// ========== Markdown 块/行内类型 ==========
// 翻译自: bun.md.BlockType
public enum MDBlockType {
    | doc
    | h          // heading (data = level 1-6)
    | p          // paragraph
    | `quote`    // blockquote
    | ul         // unordered list
    | ol         // ordered list (data = start)
    | li         // list item
    | code       // code block
    | hr         // horizontal rule
    | html       // raw HTML block
    | table
    | thead
    | tbody
    | tr
    | th
    | td
}

// 翻译自: bun.md.SpanType
public enum MDSpanType {
    | em
    | strong
    | a
    | img
    | code
    | del
    | latexmath
    | latexmathDisplay
    | wikilink
    | u
}

// 翻译自: bun.md.TextType
public enum MDTextType {
    | normal
    | nullChar
    | br
    | softbr
    | entity
    | codeText
    | html
}

// 翻译自: bun.md.SpanDetail
public class MDSpanDetail {
    public var href: String = ""
    public var title: String = ""

    public init() {}
    public init(href!: String, title!: String) {
        this.href = href
        this.title = title
    }
}

// 翻译自: bun.md.Options
/// Markdown 解析器选项
public class MDOptions {
    // 自动链接相关
    public var permissiveAutolinks: Bool = false
    public var permissiveUrlAutolinks: Bool = false
    public var permissiveWwwAutolinks: Bool = false
    public var permissiveEmailAutolinks: Bool = false

    // 标题相关
    public var headingIds: Bool = false
    public var autolinkHeadings: Bool = false

    // 其他布尔选项
    public var underline: Bool = false
    public var strikethrough: Bool = false
    public var latex: Bool = false
    public var wikilinks: Bool = false
    public var tables: Bool = false
    public var tasklists: Bool = false
    public var fencedCode: Bool = true

    public init() {}
}

// 翻译自: bun.md.AnsiTheme
/// ANSI 终端渲染主题
public class MDAnsiTheme {
    public var colors: Bool = true
    public var hyperlinks: Bool = false
    public var kittyGraphics: Bool = false
    public var light: Bool = false
    public var columns: Int64 = 80

    public init() {}
}

// 翻译自: MarkdownObject.zig getCachedTagString / TagIndex
/// HTML 标签索引 (与 BunMarkdownTagStrings.h 对应)
public enum TagIndex {
    | h1 | h2 | h3 | h4 | h5 | h6
    | p | blockquote | ul | ol | li
    | pre | hr | html | table | thead | tbody | tr | th | td | div
    | em | strong | a | img | code | del | math | u | br
}

// ========== Markdown 常量 ==========
// 翻译自: md.BLOCK_FENCED_CODE
public let BLOCK_FENCED_CODE: UInt32 = 1u32

// 翻译自: md.types.taskMarkFromData / isTaskChecked / alignmentFromData / alignmentName
public class MDTypes {
    public init() {}

    public static func taskMarkFromData(data!: UInt32): UInt8 {
        UInt8(data & 0xFFu32)
    }

    public static func isTaskChecked(mark!: UInt8): Bool {
        mark != UInt8(0) && mark != UInt8(1)
    }

    public static func alignmentFromData(data!: UInt32): String {
        let val = (data >> UInt32(8)) & UInt32(3)
        if (val == UInt32(0)) {
            "default"
        } else if (val == UInt32(1)) {
            "left"
        } else if (val == UInt32(2)) {
            "center"
        } else if (val == UInt32(3)) {
            "right"
        } else {
            "default"
        }
    }

    public static func alignmentName(alignment!: String): ?String {
        if (alignment == "default") {
            return None
        }
        Some(alignment)
    }
}

// ========== Markdown 渲染器 VTable ==========
// 翻译自: md.Renderer.VTable
public interface MDRendererVTable {
    func enterBlock(blockType!: MDBlockType, data!: UInt32, flags!: UInt32): Unit
    func leaveBlock(blockType!: MDBlockType, detail!: UInt32): Unit
    func enterSpan(spanType!: MDSpanType, detail!: MDSpanDetail): Unit
    func leaveSpan(spanType!: MDSpanType): Unit
    func text(textType!: MDTextType, content!: String): Unit
}

// ========== Heading ID 追踪器 ==========
// 翻译自: md.helpers.HeadingIdTracker
public class HeadingIdTracker {
    public var enabled: Bool = false
    private var currentText: String = ""

    public init() {}
    public init(enabled!: Bool) {
        this.enabled = enabled
    }

    public func enterHeading(): Unit {
        currentText = ""
    }

    public func trackText(textType!: MDTextType, content!: String): Unit {
        if (!enabled) { return }
        // 只追踪普通文本
        match (textType) {
            case MDTextType.normal => currentText += content
            case MDTextType.codeText => currentText += content
            case _ => ()
        }
    }

    public func leaveHeading(): ?String {
        if (!enabled) { return None }
        let slug = generateSlug(text: currentText)
        return Some(slug)
    }

    public func clearAfterHeading(): Unit {
        currentText = ""
    }

    public func deinit(): Unit {
        currentText = ""
    }

    /// 生成标题 slug (小写, 连字符分隔)
    public static func generateSlug(text!: String): String {
        var slug = ""
        var lastWasSpace = false
        for (i in 0..text.size) {
            let c = text[i]
            if (c == UInt8(32)) { // space
                if (!lastWasSpace && slug.size > 0) {
                    slug += "-"
                    lastWasSpace = true
                }
            } else {
                // Convert to lowercase for ASCII letters
                if (c >= UInt8(65) && c <= UInt8(90)) {
                    slug += String(Rune(UInt32(c + UInt8(32))))
                } else {
                    slug += String(Rune(UInt32(c)))
                }
                lastWasSpace = false
            }
        }
        // 移除尾部连字符
        while (slug.size > 0 && slug[Int64(slug.size - 1)] == UInt8(45)) { // '-'
            slug = slug[Int64(0)..Int64(slug.size - 1)]
        }
        slug
    }
}

// ========== Markdown 解析器桥接 ==========
// 翻译自: bun.md.renderToHtmlWithOptions / renderToAnsi / renderWithRenderer
public class MDParse {
    public init() {}

    /// 将 Markdown 渲染为 HTML
    // 翻译自: md.renderToHtmlWithOptions(input, allocator, options)
    public static func renderToHtml(input!: String, options!: MDOptions): String {
        // 完整实现需要连接到 Markdown 解析器
        // 当前返回简化输出
        ""
    }

    /// 将 Markdown 渲染为 ANSI 终端输出
    // 翻译自: md.renderToAnsi(input, allocator, .terminal, theme)
    public static func renderToAnsi(input!: String, theme!: MDAnsiTheme): ?String {
        // 完整实现需要连接到 Markdown 解析器 + ANSI 渲染器
        Some(input)
    }

    /// 使用自定义渲染器渲染 Markdown
    // 翻译自: md.renderWithRenderer(input, allocator, options, renderer)
    public static func renderWithRenderer(input!: String, options!: MDOptions, renderer!: MDRendererVTable): Unit {
        // 完整实现需要连接到 Markdown 解析器并通过 VTable 回调
    }
}

// ========== ParseRenderer ==========
// 翻译自: MarkdownObject.zig ParseRenderer
/// 将 Markdown 解析为对象 AST (用于 React 和普通模式)
public class ParseRenderer {
    public var globalObject: JsGlobalObject = JsGlobalObject()
    public var srcText: String = ""
    public var headingTracker: HeadingIdTracker = HeadingIdTracker()
    public var components: Components = Components()
    public var reactVersion: ?UInt8 = None
    public var stack: ArrayList<StackEntry> = ArrayList<StackEntry>()
    public var markedArgs: ArrayList<JsValue> = ArrayList<JsValue>()

    public init() {}

    public init(globalObject!: JsGlobalObject, srcText!: String, headingIds!: Bool, reactVersion!: ?UInt8) {
        this.globalObject = globalObject
        this.srcText = srcText
        this.headingTracker = HeadingIdTracker(enabled: headingIds)
        this.reactVersion = reactVersion
        // 创建根数组
        let rootArray = JsValue.createEmptyArray(JsObject(), Int64(0))
        markedArgs.append(rootArray)
        stack.append(StackEntry(children: ArrayList<JsValue>(), blockType: MDBlockType.doc))
    }

    public func deinit(): Unit {
        stack.clear()
        headingTracker.deinit()
        markedArgs.clear()
    }

    /// 提取组件覆盖
    // 翻译自: ParseRenderer.extractComponents
    public func extractComponents(opts!: JsValue): Unit {
        if (opts.isUndefinedOrNull() || !opts.isObject()) { return }
        let fields = ["h1", "h2", "h3", "h4", "h5", "h6", "p", "blockquote",
            "ul", "ol", "li", "pre", "hr", "html", "table", "thead", "tbody",
            "tr", "th", "td", "em", "strong", "a", "img", "code", "del", "math", "u", "br"]
        for (field in fields) {
            let valOpt = opts.getTruthy(JsObject(), field)
            if (valOpt.isSome()) {
                let val = valOpt.getOrThrow()
                if (!val.isBoolean()) {
                    components.set(field: field, value: val)
                    markedArgs.append(val)
                }
            }
        }
    }

    /// 获取最终结果
    public func getResult(): JsValue {
        if (stack.size == 0) { return JsValue.jsUndefined() }
        // Convert ArrayList<JsValue> to JS array
        let arr = stack[0].children
        let jsArr = JsValue.createEmptyArray(JsObject(), Int64(arr.size))
        for (i in 0..arr.size) {
            jsArr.putIndex(JsObject(), UInt32(i), arr[Int64(i)])
        }
        jsArr
    }

    /// 创建元素节点
    // 翻译自: ParseRenderer.createElement
    public func createElement(typeVal!: JsValue, props!: JsValue): JsValue {
        markedArgs.append(props)
        let obj = JsValue.createEmptyObject(JsObject(), Int64(2))
        obj.toObject().set("type", typeVal)
        obj.toObject().set("props", props)
        markedArgs.append(obj)
        return obj
    }

    /// 获取块级组件覆盖
    // 翻译自: ParseRenderer.getBlockComponent
    public func getBlockComponent(blockType!: MDBlockType, data!: UInt32): JsValue {
        match (blockType) {
            case MDBlockType.h =>
                if (data == UInt32(1)) {
                    components.h1
                } else if (data == UInt32(2)) {
                    components.h2
                } else if (data == UInt32(3)) {
                    components.h3
                } else if (data == UInt32(4)) {
                    components.h4
                } else if (data == UInt32(5)) {
                    components.h5
                } else {
                    components.h6
                }
            case MDBlockType.p => components.p
            case MDBlockType.`quote` => components.blockquote
            case MDBlockType.ul => components.ul
            case MDBlockType.ol => components.ol
            case MDBlockType.li => components.li
            case MDBlockType.code => components.pre
            case MDBlockType.hr => components.hr
            case MDBlockType.html => components.html
            case MDBlockType.table => components.table
            case MDBlockType.thead => components.thead
            case MDBlockType.tbody => components.tbody
            case MDBlockType.tr => components.tr
            case MDBlockType.th => components.th
            case MDBlockType.td => components.td
            case _ => JsValue.zero
        }
    }

    /// 获取行内组件覆盖
    // 翻译自: ParseRenderer.getSpanComponent
    public func getSpanComponent(spanType!: MDSpanType): JsValue {
        match (spanType) {
            case MDSpanType.em => components.em
            case MDSpanType.strong => components.strong
            case MDSpanType.a => components.a
            case MDSpanType.img => components.img
            case MDSpanType.code => components.code
            case MDSpanType.del => components.del
            case MDSpanType.latexmath => components.math
            case MDSpanType.latexmathDisplay => components.math
            case MDSpanType.wikilink => components.a
            case MDSpanType.u => components.u
        }
    }

    /// VTable: 进入块级元素
    // 翻译自: ParseRenderer.enterBlockImpl
    public func enterBlock(blockType!: MDBlockType, data!: UInt32, flags!: UInt32): Unit {
        if (match (blockType) { case MDBlockType.doc => true case _ => false }) { return }
        if (match (blockType) { case MDBlockType.h => true case _ => false }) {
            headingTracker.enterHeading()
        }
        let array = JsValue.createEmptyArray(JsObject(), Int64(0))
        markedArgs.append(array)
        stack.append(StackEntry(
            children: ArrayList<JsValue>(),
            blockType: blockType,
            data: data,
            flags: flags
        ))
    }

    /// VTable: 离开块级元素
    // 翻译自: ParseRenderer.leaveBlockImpl
    public func leaveBlock(blockType!: MDBlockType, detail!: UInt32): Unit {
        if (match (blockType) { case MDBlockType.doc => true case _ => false }) { return }
        if (stack.size <= 1) { return }
        let entry = stack.removeAt(stack.size - 1)
        let g = globalObject

        // 获取标签索引
        let tagIndex = getBlockTypeTag(blockType: blockType, data: entry.data)
        let tagString = tagIndexToString(tag: tagIndex)

        // 计算标题 slug
        var slug: ?String = None
        if (match (blockType) { case MDBlockType.h => true case _ => false }) {
            slug = headingTracker.leaveHeading()
        }

        // 构建 props
        var propsCount: Int64 = 1 // children
        match (blockType) {
            case MDBlockType.h =>
                if (slug.isSome()) { propsCount += 1 }
            case MDBlockType.ol => propsCount += 1 // start
            case MDBlockType.li =>
                let taskMark = MDTypes.taskMarkFromData(data: entry.data)
                if (taskMark != UInt8(0)) { propsCount += 1 }
            case MDBlockType.code =>
                if ((entry.flags & BLOCK_FENCED_CODE) != UInt32(0)) {
                    let lang = extractLanguage(srcText: srcText, infoBeg: entry.data)
                    if (lang.size > 0) { propsCount += 1 }
                }
            case MDBlockType.th =>
                let alignment = MDTypes.alignmentFromData(data: entry.data)
                if (alignment != "default") { propsCount += 1 }
            case MDBlockType.td =>
                let alignment = MDTypes.alignmentFromData(data: entry.data)
                if (alignment != "default") { propsCount += 1 }
            case _ => ()
        }

        // 获取组件覆盖
        let component = getBlockComponent(blockType: blockType, data: entry.data)
        let typeVal: JsValue = if (component != JsValue.zero) { component } else { JsValue.jsString(tagString) }

        let props = JsValue.createEmptyObject(JsObject(), Int64(propsCount))
        markedArgs.append(props)

        // 设置元数据 props
        match (blockType) {
            case MDBlockType.h =>
                if (let Some(s) <- slug) {
                    props.put(g.globalThis, "id", JsValue.jsString(s))
                }
            case MDBlockType.ol =>
                props.put(g.globalThis, "start", JsValue.jsNumber(Int64(entry.data)))
            case MDBlockType.li =>
                let taskMark = MDTypes.taskMarkFromData(data: entry.data)
                if (taskMark != UInt8(0)) {
                    props.put(g.globalThis, "checked", JsValue.jsBoolean(MDTypes.isTaskChecked(mark: taskMark)))
                }
            case MDBlockType.code =>
                if ((entry.flags & BLOCK_FENCED_CODE) != UInt32(0)) {
                    let lang = extractLanguage(srcText: srcText, infoBeg: entry.data)
                    if (lang.size > 0) {
                        props.put(g.globalThis, "language", JsValue.jsString(lang))
                    }
                }
            case MDBlockType.th =>
                let alignment = MDTypes.alignmentFromData(data: entry.data)
                let alignOpt = MDTypes.alignmentName(alignment: alignment)
                if (alignOpt.isSome()) {
                    let alignStr = alignOpt.getOrThrow()
                    props.put(g.globalThis, "align", JsValue.jsString(alignStr))
                }
            case MDBlockType.td =>
                let alignment = MDTypes.alignmentFromData(data: entry.data)
                let alignOpt = MDTypes.alignmentName(alignment: alignment)
                if (alignOpt.isSome()) {
                    let alignStr = alignOpt.getOrThrow()
                    props.put(g.globalThis, "align", JsValue.jsString(alignStr))
                }
            case _ => ()
        }

        // 设置 children (void 元素跳过)
        if (!match (blockType) { case MDBlockType.hr => true case _ => false }) {
            props.put(g.globalThis, "children", arrayListToJsArray(entry.children))
        }

        let obj = createElement(typeVal: typeVal, props: props)

        // 推入父级 children 数组
        if (stack.size > 0) {
            stack[Int64(stack.size - 1)].children.append(obj)
        }

        if (match (blockType) { case MDBlockType.h => true case _ => false }) {
            headingTracker.clearAfterHeading()
        }
    }

    /// VTable: 进入行内元素
    // 翻译自: ParseRenderer.enterSpanImpl
    public func enterSpan(spanType!: MDSpanType, detail!: MDSpanDetail): Unit {
        let array = JsValue.createEmptyArray(JsObject(), Int64(0))
        markedArgs.append(array)
        stack.append(StackEntry(children: ArrayList<JsValue>(), spanType: spanType, detail: detail))
    }

    /// VTable: 离开行内元素
    // 翻译自: ParseRenderer.leaveSpanImpl
    public func leaveSpan(spanType!: MDSpanType): Unit {
        if (stack.size <= 1) { return }
        let entry = stack.removeAt(stack.size - 1)
        let g = globalObject

        let tagIndex = getSpanTypeTag(spanType: spanType)
        let tagString = tagIndexToString(tag: tagIndex)

        // 计算 props
        var propsCount: Int64 = 1 // children (或 img 的 alt)
        match (spanType) {
            case MDSpanType.a =>
                propsCount += 1 // href
                if (entry.detail.title.size > 0) { propsCount += 1 }
            case MDSpanType.img =>
                propsCount += 1 // src
                if (entry.detail.title.size > 0) { propsCount += 1 }
            case MDSpanType.latexmathDisplay => propsCount += 1 // display
            case _ => ()
        }

        // 获取组件覆盖
        let component = getSpanComponent(spanType: spanType)
        let typeVal: JsValue = if (component != JsValue.zero) { component } else { JsValue.jsString(tagString) }

        let props = JsValue.createEmptyObject(JsObject(), Int64(propsCount))
        markedArgs.append(props)

        // 设置元数据 props
        match (spanType) {
            case MDSpanType.a =>
                props.put(g.globalThis, "href", JsValue.jsString(entry.detail.href))
                if (entry.detail.title.size > 0) {
                    props.put(g.globalThis, "title", JsValue.jsString(entry.detail.title))
                }
            case MDSpanType.img =>
                props.put(g.globalThis, "src", JsValue.jsString(entry.detail.href))
                if (entry.detail.title.size > 0) {
                    props.put(g.globalThis, "title", JsValue.jsString(entry.detail.title))
                }
            case MDSpanType.latexmathDisplay =>
                props.put(g.globalThis, "display", JsValue.jsBoolean(true))
            case _ => ()
        }

        // img 是 void 元素 — 将 children 转为 alt prop
        match (spanType) {
            case MDSpanType.img =>
                props.put(g.globalThis, "children", arrayListToJsArray(entry.children))
            case _ =>
                props.put(g.globalThis, "children", arrayListToJsArray(entry.children))
        }

        let obj = createElement(typeVal: typeVal, props: props)

        // 推入父级 children 数组
        if (stack.size > 0) {
            stack[Int64(stack.size - 1)].children.append(obj)
        }
    }

    /// VTable: 文本
    // 翻译自: ParseRenderer.textImpl
    public func text(textType!: MDTextType, content!: String): Unit {
        headingTracker.trackText(textType: textType, content: content)
        if (stack.size == 0) { return }
        let parent = stack[stack.size - 1]

        match (textType) {
            case MDTextType.br =>
                let brComponent = components.br
                let brType: JsValue = if (brComponent != JsValue.zero) { brComponent } else { JsValue.jsString("br") }
                let emptyProps = JsValue.createEmptyObject(globalObject.globalThis, 0)
                markedArgs.append(emptyProps)
                let obj = createElement(typeVal: brType, props: emptyProps)
                parent.children.append(obj)
            case MDTextType.softbr =>
                let str = JsValue.jsString("\n")
                markedArgs.append(str)
                parent.children.append(str)
            case MDTextType.nullChar =>
                let str = JsValue.jsString("�")
                markedArgs.append(str)
                parent.children.append(str)
            case MDTextType.entity =>
                // 翻译自: md.helpers.decodeEntityToUtf8
                let decoded = decodeEntity(entity: content)
                let str = JsValue.jsString(decoded)
                markedArgs.append(str)
                parent.children.append(str)
            case _ =>
                let str = JsValue.jsString(content)
                markedArgs.append(str)
                parent.children.append(str)
        }
    }
}

// 翻译自: ParseRenderer.StackEntry
/// 栈条目 — 追踪解析过程中的嵌套结构
public class StackEntry {
    public var children: ArrayList<JsValue> = ArrayList<JsValue>()
    public var blockType: ?MDBlockType = None
    public var spanType: ?MDSpanType = None
    public var data: UInt32 = UInt32(0)
    public var flags: UInt32 = UInt32(0)
    public var detail: MDSpanDetail = MDSpanDetail()
    public var childIndex: UInt32 = UInt32(0)

    public init() {}
    public init(children!: ArrayList<JsValue>, blockType!: MDBlockType) {
        this.children = children
        this.blockType = blockType
    }
    public init(children!: ArrayList<JsValue>, blockType!: MDBlockType, data!: UInt32, flags!: UInt32) {
        this.children = children
        this.blockType = blockType
        this.data = data
        this.flags = flags
    }
    public init(children!: ArrayList<JsValue>, spanType!: MDSpanType, detail!: MDSpanDetail) {
        this.children = children
        this.spanType = spanType
        this.detail = detail
    }
}

// 翻译自: ParseRenderer.Components
/// 组件覆盖映射 — HTML 标签名到自定义 JS 组件
public class Components {
    public var h1: JsValue = JsValue.zero
    public var h2: JsValue = JsValue.zero
    public var h3: JsValue = JsValue.zero
    public var h4: JsValue = JsValue.zero
    public var h5: JsValue = JsValue.zero
    public var h6: JsValue = JsValue.zero
    public var p: JsValue = JsValue.zero
    public var blockquote: JsValue = JsValue.zero
    public var ul: JsValue = JsValue.zero
    public var ol: JsValue = JsValue.zero
    public var li: JsValue = JsValue.zero
    public var pre: JsValue = JsValue.zero
    public var hr: JsValue = JsValue.zero
    public var html: JsValue = JsValue.zero
    public var table: JsValue = JsValue.zero
    public var thead: JsValue = JsValue.zero
    public var tbody: JsValue = JsValue.zero
    public var tr: JsValue = JsValue.zero
    public var th: JsValue = JsValue.zero
    public var td: JsValue = JsValue.zero
    public var em: JsValue = JsValue.zero
    public var strong: JsValue = JsValue.zero
    public var a: JsValue = JsValue.zero
    public var img: JsValue = JsValue.zero
    public var code: JsValue = JsValue.zero
    public var del: JsValue = JsValue.zero
    public var math: JsValue = JsValue.zero
    public var u: JsValue = JsValue.zero
    public var br: JsValue = JsValue.zero

    public init() {}

    public func set(field!: String, value!: JsValue): Unit {
        match (field) {
            case "h1" => h1 = value
            case "h2" => h2 = value
            case "h3" => h3 = value
            case "h4" => h4 = value
            case "h5" => h5 = value
            case "h6" => h6 = value
            case "p" => p = value
            case "blockquote" => blockquote = value
            case "ul" => ul = value
            case "ol" => ol = value
            case "li" => li = value
            case "pre" => pre = value
            case "hr" => hr = value
            case "html" => html = value
            case "table" => table = value
            case "thead" => thead = value
            case "tbody" => tbody = value
            case "tr" => tr = value
            case "th" => th = value
            case "td" => td = value
            case "em" => em = value
            case "strong" => strong = value
            case "a" => a = value
            case "img" => img = value
            case "code" => code = value
            case "del" => del = value
            case "math" => math = value
            case "u" => u = value
            case "br" => br = value
            case _ => ()
        }
    }
}

// ========== JsCallbackRenderer ==========
// 翻译自: MarkdownObject.zig JsCallbackRenderer
/// 使用 JavaScript 回调渲染 Markdown
public class JsCallbackRenderer {
    public var globalObject: JsGlobalObject = JsGlobalObject()
    public var srcText: String = ""
    public var stack: ArrayList<JSCallbackStackEntry> = ArrayList<JSCallbackStackEntry>()
    public var callbacks: JSCallbacks = JSCallbacks()
    public var headingTracker: HeadingIdTracker = HeadingIdTracker()

    public init() {}

    public init(globalObject!: JsGlobalObject, srcText!: String, headingIds!: Bool) {
        this.globalObject = globalObject
        this.srcText = srcText
        this.headingTracker = HeadingIdTracker(enabled: headingIds)
        stack.append(JSCallbackStackEntry())
    }

    public func deinit(): Unit {
        for (entry in stack) {
            entry.deinit()
        }
        stack.clear()
        headingTracker.deinit()
    }

    /// 提取回调函数
    // 翻译自: JsCallbackRenderer.extractCallbacks
    public func extractCallbacks(opts!: JsValue): Unit {
        if (opts.isUndefinedOrNull() || !opts.isObject()) { return }
        let fields = ["heading", "paragraph", "blockquote", "code", "list",
            "listItem", "hr", "table", "thead", "tbody", "tr", "th", "td",
            "html", "strong", "emphasis", "link", "image", "codespan",
            "strikethrough", "text"]
        for (field in fields) {
            let truthyOpt = opts.getTruthy(globalObject.globalThis, field)
            if (truthyOpt.isSome()) {
                let val = truthyOpt.getOrThrow()
                if (val.isCallable()) {
                    callbacks.set(field: field, value: val)
                }
            }
        }
    }

    /// 获取渲染结果
    public func getResult(): String {
        if (stack.size == 0) { return "" }
        stack[0].buffer
    }

    /// 追加文本到栈顶缓冲区
    // 翻译自: JsCallbackRenderer.appendToTop
    public func appendToTop(data!: String): Unit {
        if (stack.size == 0) { return }
        let top = stack[stack.size - 1]
        top.buffer += data
    }

    /// 弹出栈顶并调用回调
    // 翻译自: JsCallbackRenderer.popAndCallback
    public func popAndCallback(callback!: JsValue, meta!: ?JsValue): Unit {
        if (stack.size <= 1) { return }
        let entry = stack.removeAt(stack.size - 1)
        let children = entry.buffer

        if (callback == JsValue.zero) {
            // 无回调 — 直接传递到父级
            appendToTop(data: children)
            return
        }

        // 将 children 转为 JS 字符串
        let childrenJs = JsValue.jsString(children)

        // 调用 JS 回调
        let result: JsValue = if (let Some(m) <- meta) {
            callback.call(globalObject.globalThis, JsValue.jsUndefined(), [childrenJs, m])
        } else {
            callback.call(globalObject.globalThis, JsValue.jsUndefined(), [childrenJs])
        }

        if (result.isUndefinedOrNull()) { return }
        let slice = result.toString()
        appendToTop(data: slice)
    }

    /// VTable 实现: 进入块级
    public func enterBlock(blockType!: MDBlockType, data!: UInt32, flags!: UInt32): Unit {
        if (match (blockType) { case MDBlockType.doc => true case _ => false }) { return }
        if (match (blockType) { case MDBlockType.h => true case _ => false }) {
            headingTracker.enterHeading()
        }

        var childIndex: UInt32 = UInt32(0)
        let isListItem = match (blockType) { case MDBlockType.li => true case _ => false }
        if (isListItem && stack.size > 0) {
            let parent = stack[stack.size - 1]
            childIndex = parent.childIndex
            parent.childIndex = parent.childIndex + UInt32(1)
        }

        stack.append(JSCallbackStackEntry(
            blockType: blockType,
            data: data,
            flags: flags,
            childIndex: childIndex
        ))
    }

    /// VTable 实现: 离开块级
    public func leaveBlock(blockType!: MDBlockType, detail!: UInt32): Unit {
        if (match (blockType) { case MDBlockType.doc => true case _ => false }) { return }
        let callback = getBlockCallback(blockType: blockType)

        var savedData: UInt32 = UInt32(0)
        var savedFlags: UInt32 = UInt32(0)
        var savedChildIndex: UInt32 = UInt32(0)
        if (stack.size > 1) {
            let top = stack[stack.size - 1]
            savedData = top.data
            savedFlags = top.flags
            savedChildIndex = top.childIndex
        }

        let meta = createBlockMeta(blockType: blockType, data: savedData, flags: savedFlags)
        popAndCallback(callback: callback, meta: meta)

        if (match (blockType) { case MDBlockType.h => true case _ => false }) {
            headingTracker.clearAfterHeading()
        }
    }

    /// VTable 实现: 进入行内
    public func enterSpan(spanType!: MDSpanType, detail!: MDSpanDetail): Unit {
        stack.append(JSCallbackStackEntry(detail: detail))
    }

    /// VTable 实现: 离开行内
    public func leaveSpan(spanType!: MDSpanType): Unit {
        let callback = getSpanCallback(spanType: spanType)
        var detail = MDSpanDetail()
        if (stack.size > 1) {
            detail = stack[stack.size - 1].detail
        }
        let meta = createSpanMeta(spanType: spanType, detail: detail)
        popAndCallback(callback: callback, meta: meta)
    }

    /// VTable 实现: 文本
    public func text(textType!: MDTextType, content!: String): Unit {
        headingTracker.trackText(textType: textType, content: content)
        match (textType) {
            case MDTextType.nullChar => appendToTop(data: "\u{FFFD}")
            case MDTextType.br => appendToTop(data: "\n")
            case MDTextType.softbr => appendToTop(data: "\n")
            case MDTextType.entity =>
                let decoded = decodeEntity(entity: content)
                appendToTop(data: decoded)
            case _ =>
                if (callbacks.text != JsValue.zero) {
                    callTextCallback(content: content)
                } else {
                    appendToTop(data: content)
                }
        }
    }

    /// 调用文本回调
    // 翻译自: JsCallbackRenderer.callTextCallback
    public func callTextCallback(content!: String): Unit {
        let textJs = JsValue.jsString(content)
        let result = callbacks.text.call(globalObject.globalThis, JsValue.jsUndefined(), [textJs])
        if (!result.isUndefinedOrNull()) {
            let slice = result.toString()
            appendToTop(data: slice)
        }
    }

    /// 获取块级回调
    // 翻译自: JsCallbackRenderer.getBlockCallback
    public func getBlockCallback(blockType!: MDBlockType): JsValue {
        match (blockType) {
            case MDBlockType.h => callbacks.heading
            case MDBlockType.p => callbacks.paragraph
            case MDBlockType.`quote` => callbacks.blockquote
            case MDBlockType.code => callbacks.code
            case MDBlockType.ul => callbacks.list
            case MDBlockType.ol => callbacks.list
            case MDBlockType.li => callbacks.listItem
            case MDBlockType.hr => callbacks.hr
            case MDBlockType.table => callbacks.table
            case MDBlockType.thead => callbacks.thead
            case MDBlockType.tbody => callbacks.tbody
            case MDBlockType.tr => callbacks.tr
            case MDBlockType.th => callbacks.th
            case MDBlockType.td => callbacks.td
            case MDBlockType.html => callbacks.html
            case _ => JsValue.zero
        }
    }

    /// 获取行内回调
    // 翻译自: JsCallbackRenderer.getSpanCallback
    public func getSpanCallback(spanType!: MDSpanType): JsValue {
        match (spanType) {
            case MDSpanType.em => callbacks.emphasis
            case MDSpanType.strong => callbacks.strong
            case MDSpanType.a => callbacks.link
            case MDSpanType.img => callbacks.image
            case MDSpanType.code => callbacks.codespan
            case MDSpanType.del => callbacks.strikethrough
            case _ => JsValue.zero
        }
    }

    /// 创建块级元数据对象
    // 翻译自: JsCallbackRenderer.createBlockMeta
    public func createBlockMeta(blockType!: MDBlockType, data!: UInt32, flags!: UInt32): ?JsValue {
        let g = globalObject.globalThis
        match (blockType) {
            case MDBlockType.h =>
                let slug = headingTracker.leaveHeading()
                let fieldCount: Int64 = if (slug.isSome()) { 2 } else { 1 }
                let obj = JsValue.createEmptyObject(g, fieldCount)
                obj.put(g, "level", JsValue.jsNumber(Int64(data)))
                if (let Some(s) <- slug) {
                    obj.put(g, "id", JsValue.jsString(s))
                }
                return Some(obj)
            case MDBlockType.ol =>
                let obj = JsValue.createEmptyObject(g, 3)
                obj.put(g, "ordered", JsValue.jsBoolean(true))
                obj.put(g, "start", JsValue.jsNumber(Int64(data)))
                return Some(obj)
            case MDBlockType.ul =>
                let obj = JsValue.createEmptyObject(g, 2)
                obj.put(g, "ordered", JsValue.jsBoolean(false))
                return Some(obj)
            case MDBlockType.code =>
                if ((flags & BLOCK_FENCED_CODE) != UInt32(0)) {
                    let lang = extractLanguage(srcText: srcText, infoBeg: data)
                    if (lang.size > 0) {
                        let obj = JsValue.createEmptyObject(g, 1)
                        obj.put(g, "language", JsValue.jsString(lang))
                        return Some(obj)
                    }
                }
                return None
            case MDBlockType.li =>
                let len = stack.size
                let itemIndex: UInt32 = if (len > 1) { stack[len - 1].childIndex } else { UInt32(0) }
                let taskMark = MDTypes.taskMarkFromData(data: data)
                let checkedJs: JsValue = if (taskMark != UInt8(0)) {
                    JsValue.jsBoolean(MDTypes.isTaskChecked(mark: taskMark))
                } else {
                    JsValue.jsUndefined()
                }
                let obj = JsValue.createEmptyObject(g, 4)
                obj.put(g, "index", JsValue.jsNumber(Int64(itemIndex)))
                obj.put(g, "checked", checkedJs)
                return Some(obj)
            case _ => None
        }
    }

    /// 创建行内元数据对象
    // 翻译自: JsCallbackRenderer.createSpanMeta
    public func createSpanMeta(spanType!: MDSpanType, detail!: MDSpanDetail): ?JsValue {
        let g = globalObject.globalThis
        match (spanType) {
            case MDSpanType.a =>
                let obj = JsValue.createEmptyObject(g, 2)
                obj.put(g, "href", JsValue.jsString(detail.href))
                if (detail.title.size > 0) {
                    obj.put(g, "title", JsValue.jsString(detail.title))
                }
                return Some(obj)
            case MDSpanType.img =>
                let obj = JsValue.createEmptyObject(g, 2)
                obj.put(g, "src", JsValue.jsString(detail.href))
                if (detail.title.size > 0) {
                    obj.put(g, "title", JsValue.jsString(detail.title))
                }
                return Some(obj)
            case _ => None
        }
    }
}

// 翻译自: JsCallbackRenderer.StackEntry
/// 回调渲染器栈条目
public class JSCallbackStackEntry {
    public var buffer: String = ""
    public var blockType: MDBlockType = MDBlockType.doc
    public var data: UInt32 = UInt32(0)
    public var flags: UInt32 = UInt32(0)
    public var childIndex: UInt32 = UInt32(0)
    public var detail: MDSpanDetail = MDSpanDetail()

    public init() {}
    public init(blockType!: MDBlockType, data!: UInt32, flags!: UInt32, childIndex!: UInt32) {
        this.blockType = blockType
        this.data = data
        this.flags = flags
        this.childIndex = childIndex
    }
    public init(detail!: MDSpanDetail) {
        this.detail = detail
    }

    public func deinit(): Unit {
        buffer = ""
    }
}

// 翻译自: JsCallbackRenderer.Callbacks
/// JS 回调函数映射
public class JSCallbacks {
    public var heading: JsValue = JsValue.zero
    public var paragraph: JsValue = JsValue.zero
    public var blockquote: JsValue = JsValue.zero
    public var code: JsValue = JsValue.zero
    public var list: JsValue = JsValue.zero
    public var listItem: JsValue = JsValue.zero
    public var hr: JsValue = JsValue.zero
    public var table: JsValue = JsValue.zero
    public var thead: JsValue = JsValue.zero
    public var tbody: JsValue = JsValue.zero
    public var tr: JsValue = JsValue.zero
    public var th: JsValue = JsValue.zero
    public var td: JsValue = JsValue.zero
    public var html: JsValue = JsValue.zero
    public var strong: JsValue = JsValue.zero
    public var emphasis: JsValue = JsValue.zero
    public var link: JsValue = JsValue.zero
    public var image: JsValue = JsValue.zero
    public var codespan: JsValue = JsValue.zero
    public var strikethrough: JsValue = JsValue.zero
    public var text: JsValue = JsValue.zero

    public init() {}

    public func set(field!: String, value!: JsValue): Unit {
        match (field) {
            case "heading" => heading = value
            case "paragraph" => paragraph = value
            case "blockquote" => blockquote = value
            case "code" => code = value
            case "list" => list = value
            case "listItem" => listItem = value
            case "hr" => hr = value
            case "table" => table = value
            case "thead" => thead = value
            case "tbody" => tbody = value
            case "tr" => tr = value
            case "th" => th = value
            case "td" => td = value
            case "html" => html = value
            case "strong" => strong = value
            case "emphasis" => emphasis = value
            case "link" => link = value
            case "image" => image = value
            case "codespan" => codespan = value
            case "strikethrough" => strikethrough = value
            case "text" => text = value
            case _ => ()
        }
    }
}

// ========== MarkdownObject 主类 ==========
// 翻译自: MarkdownObject.zig 的顶层 create/renderToHTML/renderToAnsi/render/renderReact

/// MarkdownObject — Bun.markdown 全局对象
public class MarkdownObject {
    public init() {}

    // 翻译自: MarkdownObject.create
    public static func create(globalThis!: JsGlobalObject): JsValue {
        let object = JsValue.createEmptyObject(globalThis.globalThis, 4)
        let gt = globalThis  // capture for closures
        object.put(globalThis.globalThis, "html", JsValue.nativeFunction("html", { args => renderToHTML_(globalThis: gt, callFrame: CallFrame(args, JsValue.jsUndefined(), JsValue.jsUndefined())) }))
        object.put(globalThis.globalThis, "ansi", JsValue.nativeFunction("ansi", { args => renderToAnsi_(globalThis: gt, callFrame: CallFrame(args, JsValue.jsUndefined(), JsValue.jsUndefined())) }))
        object.put(globalThis.globalThis, "render", JsValue.nativeFunction("render", { args => render_(globalThis: gt, callFrame: CallFrame(args, JsValue.jsUndefined(), JsValue.jsUndefined())) }))
        object.put(globalThis.globalThis, "react", JsValue.nativeFunction("react", { args => renderReact_(globalThis: gt, callFrame: CallFrame(args, JsValue.jsUndefined(), JsValue.jsUndefined())) }))
        return object
    }

    // 翻译自: MarkdownObject.renderToHTML
    /// Bun.markdown.html(text, options?) — 将 Markdown 渲染为 HTML
    public static func renderToHTML(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsAsArray(2)
        let inputValue = args[0]
        let optsValue = args[1]

        if (inputValue.isEmptyOrUndefinedOrNull()) {
            globalThis.throwInvalidArguments("Expected a string or buffer to render")
            return JsValue.jsUndefined()
        }

        let input = inputValue.toString()

        // 解析选项
        let options = parseOptions(globalThis: globalThis, optsValue: optsValue)

        // 渲染为 HTML
        let result = MDParse.renderToHtml(input: input, options: options)
        return JsValue.jsString(result)
    }

    // 翻译自: MarkdownObject.renderToAnsi
    /// Bun.markdown.ansi(text, theme?) — 将 Markdown 渲染为 ANSI 终端字符串
    public static func renderToAnsi(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsAsArray(2)
        let inputValue = args[0]
        let themeValue = args[1]

        if (inputValue.isEmptyOrUndefinedOrNull()) {
            globalThis.throwInvalidArguments("Expected a string or buffer to render")
            return JsValue.jsUndefined()
        }

        let input = inputValue.toString()

        // 构建 ANSI 主题
        var theme = MDAnsiTheme()
        if (themeValue.isObject()) {
            let colorsOpt = themeValue.getBooleanLoose(globalThis.globalThis, "colors")
            if (colorsOpt.isSome()) { theme.colors = colorsOpt.getOrThrow() }
            let hyperlinksOpt = themeValue.getBooleanLoose(globalThis.globalThis, "hyperlinks")
            if (hyperlinksOpt.isSome()) { theme.hyperlinks = hyperlinksOpt.getOrThrow() }
            let kittyOpt = themeValue.getBooleanLoose(globalThis.globalThis, "kittyGraphics")
            if (kittyOpt.isSome()) { theme.kittyGraphics = kittyOpt.getOrThrow() }
            let lightOpt = themeValue.getBooleanLoose(globalThis.globalThis, "light")
            if (lightOpt.isSome()) { theme.light = lightOpt.getOrThrow() }
            let colsOpt = themeValue.get(globalThis.globalThis, "columns")
            if (colsOpt.isSome()) {
                let cols = colsOpt.getOrThrow()
                if (cols.isNumber()) {
                    let n = cols.toInt32()
                    theme.columns = if (n <= 0) { Int64(0) } else { Int64(n) }
                }
            }
        }

        // 渲染为 ANSI
        let result = MDParse.renderToAnsi(input: input, theme: theme)
        if (result.isSome()) {
            return JsValue.jsString(result.getOrThrow())
        }
        return JsValue.jsUndefined()
    }

    // 翻译自: MarkdownObject.render
    /// Bun.markdown.render(text, callbacks, options?) — 使用自定义回调渲染 Markdown
    public static func render(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsAsArray(3)
        let inputValue = args[0]
        let callbacksValue = args[1]
        let optsValue = args[2]

        if (inputValue.isEmptyOrUndefinedOrNull()) {
            globalThis.throwInvalidArguments("Expected a string or buffer to render")
            return JsValue.jsUndefined()
        }

        let input = inputValue.toString()

        // 解析选项
        let options = parseOptions(globalThis: globalThis, optsValue: optsValue)

        // 创建 JS 回调渲染器
        var jsRenderer = JsCallbackRenderer(
            globalObject: globalThis,
            srcText: input,
            headingIds: options.headingIds
        )

        // 提取回调
        jsRenderer.extractCallbacks(
            opts: if (callbacksValue.isObject()) { callbacksValue } else { JsValue.jsUndefined() }
        )

        // 运行解析器 (在完整实现中, 这将遍历 Markdown AST 并调用 VTable)
        // 简化: 直接返回输入
        let result = jsRenderer.getResult()
        jsRenderer.deinit()
        return JsValue.jsString(result)
    }

    // 翻译自: MarkdownObject.renderReact
    /// Bun.markdown.react(text, components?, options?) — 返回 React Fragment 元素
    public static func renderReact(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsAsArray(3)
        let optsValue = args[2]

        // 确定 React 版本
        var reactVersion: UInt8 = UInt8(1) // 默认: react.transitional.element (React 19+)
        if (optsValue.isObject()) {
            let rvOpt = optsValue.get(globalThis.globalThis, "reactVersion")
            if (rvOpt.isSome()) {
                let rv = rvOpt.getOrThrow()
                if (rv.isNumber()) {
                    let num = rv.toInt32()
                    if (num <= 18) { reactVersion = UInt8(0) } // react.element (React 18)
                }
            }
        }

        // 渲染 AST
        let children = renderAST(globalThis: globalThis, callFrame: callFrame, reactVersion: reactVersion)

        // 创建 Fragment
        // 翻译自: JSReactElement__createFragment(globalThis, react_version, children)
        let fragment = JsValue.createEmptyObject(globalThis.globalThis, 1)
        fragment.put(globalThis.globalThis, "children", children)
        return fragment
    }

    /// 渲染 Markdown AST 为 JS 值
    // 翻译自: MarkdownObject.renderAST
    public static func renderAST(globalThis!: JsGlobalObject, callFrame!: JsCallFrame, reactVersion!: UInt8): JsValue {
        let args = callFrame.argumentsAsArray(3)
        let inputValue = args[0]
        let componentsValue = args[1]
        let optsValue = args[2]

        if (inputValue.isEmptyOrUndefinedOrNull()) {
            globalThis.throwInvalidArguments("Expected a string or buffer to render")
            return JsValue.jsUndefined()
        }

        let input = inputValue.toString()

        // 解析选项
        let options = parseOptions(globalThis: globalThis, optsValue: optsValue)

        // 创建 ParseRenderer
        var renderer = ParseRenderer(
            globalObject: globalThis,
            srcText: input,
            headingIds: options.headingIds,
            reactVersion: reactVersion
        )

        // 提取组件覆盖
        renderer.extractComponents(
            opts: if (componentsValue.isObject()) { componentsValue } else { JsValue.jsUndefined() }
        )

        // 在完整实现中, 这将运行 Markdown 解析器并调用 VTable 回调
        let result = renderer.getResult()
        renderer.deinit()
        return result
    }

    // 内部包装函数, 用作 JS 函数回调
    public static func renderToHTML_(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        renderToHTML(globalThis: globalThis, callFrame: callFrame)
    }
    public static func renderToAnsi_(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        renderToAnsi(globalThis: globalThis, callFrame: callFrame)
    }
    public static func render_(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        render(globalThis: globalThis, callFrame: callFrame)
    }
    public static func renderReact_(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        renderReact(globalThis: globalThis, callFrame: callFrame)
    }
}

// ========== 辅助函数 ==========

/// 解析 Markdown 选项
// 翻译自: MarkdownObject.parseOptions
public func parseOptions(globalThis!: JsGlobalObject, optsValue!: JsValue): MDOptions {
    var options = MDOptions()
    if (!optsValue.isObject()) { return options }

    // 处理复合 autolinks 选项: true | { url, www, email }
    let autolinksOpt = optsValue.get(globalThis.globalThis, "autolinks")
    if (autolinksOpt.isSome()) {
        let autolinksVal = autolinksOpt.getOrThrow()
        if (autolinksVal.isBoolean()) {
            if (autolinksVal.toBoolean()) {
                options.permissiveAutolinks = true
            }
        } else if (autolinksVal.isObject()) {
            let urlOpt = autolinksVal.getBooleanLoose(globalThis.globalThis, "url")
            if (urlOpt.isSome()) { options.permissiveUrlAutolinks = urlOpt.getOrThrow() }
            let wwwOpt = autolinksVal.getBooleanLoose(globalThis.globalThis, "www")
            if (wwwOpt.isSome()) { options.permissiveWwwAutolinks = wwwOpt.getOrThrow() }
            let emailOpt = autolinksVal.getBooleanLoose(globalThis.globalThis, "email")
            if (emailOpt.isSome()) { options.permissiveEmailAutolinks = emailOpt.getOrThrow() }
        }
    }

    // 处理复合 headings 选项: true | { ids, autolink }
    let headingsOpt = optsValue.get(globalThis.globalThis, "headings")
    if (headingsOpt.isSome()) {
        let headingsVal = headingsOpt.getOrThrow()
        if (headingsVal.isBoolean()) {
            if (headingsVal.toBoolean()) {
                options.headingIds = true
                options.autolinkHeadings = true
            }
        } else if (headingsVal.isObject()) {
            let idsOpt = headingsVal.getBooleanLoose(globalThis.globalThis, "ids")
            if (idsOpt.isSome()) { options.headingIds = idsOpt.getOrThrow() }
            let autolinkOpt = headingsVal.getBooleanLoose(globalThis.globalThis, "autolink")
            if (autolinkOpt.isSome()) { options.autolinkHeadings = autolinkOpt.getOrThrow() }
        }
    }

    // 处理剩余布尔选项
    let boolOptions = [
        ("underline", "underline"),
        ("strikethrough", "strikethrough"),
        ("latex", "latex"),
        ("wikilinks", "wikilinks"),
        ("tables", "tables"),
        ("tasklists", "tasklists")
    ]
    for ((jsName, fieldName) in boolOptions) {
        let boolOpt = optsValue.getBooleanLoose(globalThis.globalThis, jsName)
        if (boolOpt.isSome()) {
            let val = boolOpt.getOrThrow()
            match (fieldName) {
                case "underline" => options.underline = val
                case "strikethrough" => options.strikethrough = val
                case "latex" => options.latex = val
                case "wikilinks" => options.wikilinks = val
                case "tables" => options.tables = val
                case "tasklists" => options.tasklists = val
                case _ => ()
            }
        }
    }

    options
}

// 翻译自: MarkdownObject.extractLanguage
/// 从源文本中提取代码块语言标识
public func extractLanguage(srcText!: String, infoBeg!: UInt32): String {
    var langEnd: Int64 = Int64(infoBeg)
    while (langEnd < srcText.size) {
        let c = srcText[langEnd]
        if (c == UInt8(32) || c == UInt8(9) || c == UInt8(10) || c == UInt8(13)) { break }  // space, tab, newline, carriage return
        langEnd += 1
    }
    if (langEnd > Int64(infoBeg)) {
        return srcText[Int64(infoBeg)..langEnd]
    }
    ""
}

// 翻译自: MarkdownObject.getBlockTypeTag
/// 获取块级类型对应的 HTML 标签索引
public func getBlockTypeTag(blockType!: MDBlockType, data!: UInt32): TagIndex {
    match (blockType) {
        case MDBlockType.h =>
            if (data == UInt32(1)) {
                TagIndex.h1
            } else if (data == UInt32(2)) {
                TagIndex.h2
            } else if (data == UInt32(3)) {
                TagIndex.h3
            } else if (data == UInt32(4)) {
                TagIndex.h4
            } else if (data == UInt32(5)) {
                TagIndex.h5
            } else {
                TagIndex.h6
            }
        case MDBlockType.p => TagIndex.p
        case MDBlockType.`quote` => TagIndex.blockquote
        case MDBlockType.ul => TagIndex.ul
        case MDBlockType.ol => TagIndex.ol
        case MDBlockType.li => TagIndex.li
        case MDBlockType.code => TagIndex.pre
        case MDBlockType.hr => TagIndex.hr
        case MDBlockType.html => TagIndex.html
        case MDBlockType.table => TagIndex.table
        case MDBlockType.thead => TagIndex.thead
        case MDBlockType.tbody => TagIndex.tbody
        case MDBlockType.tr => TagIndex.tr
        case MDBlockType.th => TagIndex.th
        case MDBlockType.td => TagIndex.td
        case _ => TagIndex.div
    }
}

// 翻译自: MarkdownObject.getSpanTypeTag
/// 获取行内类型对应的 HTML 标签索引
public func getSpanTypeTag(spanType!: MDSpanType): TagIndex {
    match (spanType) {
        case MDSpanType.em => TagIndex.em
        case MDSpanType.strong => TagIndex.strong
        case MDSpanType.a => TagIndex.a
        case MDSpanType.img => TagIndex.img
        case MDSpanType.code => TagIndex.code
        case MDSpanType.del => TagIndex.del
        case MDSpanType.latexmath => TagIndex.math
        case MDSpanType.latexmathDisplay => TagIndex.math
        case MDSpanType.wikilink => TagIndex.a
        case MDSpanType.u => TagIndex.u
    }
}

// 翻译自: getCachedTagString
/// 将标签索引转为 HTML 标签字符串
public func tagIndexToString(tag!: TagIndex): String {
    match (tag) {
        case TagIndex.h1 => "h1"
        case TagIndex.h2 => "h2"
        case TagIndex.h3 => "h3"
        case TagIndex.h4 => "h4"
        case TagIndex.h5 => "h5"
        case TagIndex.h6 => "h6"
        case TagIndex.p => "p"
        case TagIndex.blockquote => "blockquote"
        case TagIndex.ul => "ul"
        case TagIndex.ol => "ol"
        case TagIndex.li => "li"
        case TagIndex.pre => "pre"
        case TagIndex.hr => "hr"
        case TagIndex.html => "html"
        case TagIndex.table => "table"
        case TagIndex.thead => "thead"
        case TagIndex.tbody => "tbody"
        case TagIndex.tr => "tr"
        case TagIndex.th => "th"
        case TagIndex.td => "td"
        case TagIndex.div => "div"
        case TagIndex.em => "em"
        case TagIndex.strong => "strong"
        case TagIndex.a => "a"
        case TagIndex.img => "img"
        case TagIndex.code => "code"
        case TagIndex.del => "del"
        case TagIndex.math => "math"
        case TagIndex.u => "u"
        case TagIndex.br => "br"
    }
}

// 翻译自: md.helpers.decodeEntityToUtf8 (简化版)
/// 解码 HTML 实体为 UTF-8 字符串
public func decodeEntity(entity!: String): String {
    // 常见 HTML 实体映射
    let entityMap = [
        ("&amp;", "&"),
        ("&lt;", "<"),
        ("&gt;", ">"),
        ("&quot;", "\""),
        ("&apos;", "'"),
        ("&nbsp;", " "),
        ("&mdash;", "—"),
        ("&ndash;", "–"),
        ("&hellip;", "…"),
        ("&copy;", "©"),
        ("&reg;", "®"),
        ("&trade;", "™"),
        ("&#39;", "'")
    ]
    for ((name, value) in entityMap) {
        if (entity == name) { return value }
    }
    // 数字实体 &#NNN; 或 &#xHHH;
    if (entity.size > 3 && entity[0] == UInt8(38) && entity[1] == UInt8(35)) {  // '&' == 38, '#' == 35
        if (entity[2] == UInt8(120) || entity[2] == UInt8(88)) {  // 'x' == 120, 'X' == 88
            // 十六进制
            let hexStr = entity[Int64(3)..Int64(entity.size - 1)]
            var code: Int64 = Int64(0)
            for (ch in hexStr) {
                let digit = if (ch >= UInt8(48) && ch <= UInt8(57)) {
                    Int64(ch - UInt8(48))
                } else if (ch >= UInt8(65) && ch <= UInt8(70)) {
                    Int64(ch - UInt8(55))
                } else {
                    Int64(ch - UInt8(87))
                }
                code = code * Int64(16) + digit
            }
            return String(Rune(code))
        } else {
            // 十进制
            let decStr = entity[Int64(2)..Int64(entity.size - 1)]
            var code: Int64 = Int64(0)
            for (ch in decStr) {
                if (ch >= UInt8(48) && ch <= UInt8(57)) {
                    code = code * Int64(10) + Int64(ch - UInt8(48))
                }
            }
            return String(Rune(code))
        }
    }
    entity
}
