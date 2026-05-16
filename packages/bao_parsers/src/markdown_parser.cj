// bao_parsers - Markdown Parser (Markdown 解析器)
// 严格翻译自: src/md/
//   对应: md/parser.zig - Parser 主结构
//   对应: md/types.zig - BlockType, SpanType, TextType, Line, Mark
//   对应: md/blocks.zig - 块级元素解析 (processDoc, analyzeLine)
//   对应: md/inlines.zig - 行内元素解析 (emphasis, code span, links)
//   对应: md/html_renderer.zig - HTML 渲染器
//   对应: md/containers.zig - 容器块处理 (blockquote, list)
//   对应: md/line_analysis.zig - 行类型分析
//   对应: md/links.zig - 链接解析
//   对应: md/autolinks.rs - 自动链接
//   对应: md/entity.zig - HTML 实体
//   对应: md/ref_defs.zig - 引用定义
package bao_parsers

import bao_core.*
import bao_collections.*

extend String {
    public func trimSpace(): String {
        var start = Int64(0)
        var end = this.size
        while (start < end && (this[start] == UInt8(32) || this[start] == UInt8(9) || this[start] == UInt8(10) || this[start] == UInt8(13))) {
            start += 1
        }
        while (end > start && (this[end - 1] == UInt8(32) || this[end - 1] == UInt8(9) || this[end - 1] == UInt8(10) || this[end - 1] == UInt8(13))) {
            end -= 1
        }
        return this[start..end]
    }

    public func trimStartSpace(): String {
        var start = Int64(0)
        while (start < this.size && (this[start] == UInt8(32) || this[start] == UInt8(9) || this[start] == UInt8(10) || this[start] == UInt8(13))) {
            start += 1
        }
        return this[start..this.size]
    }

    public func sliceString(start: Int64): String {
        return this[start..this.size]
    }

    public func sliceString(start: Int64, end: Int64): String {
        return this[start..end]
    }

    public func toLowerCase(): String {
        let sb = StringBuilder()
        for (ch in this) {
            if (ch >= UInt8(65) && ch <= UInt8(90)) {
                sb.append(UInt8(ch + UInt8(32)))
            } else {
                sb.append(ch)
            }
        }
        return sb.toString()
    }
}

private func joinStrings(delimiter: String, parts: ArrayList<String>): String {
    let sb = StringBuilder()
    var first = true
    for (part in parts) {
        if (!first) { sb.append(delimiter) }
        first = false
        sb.append(part)
    }
    return sb.toString()
}

// ============================================================================
// Markdown AST 节点类型
// 严格翻译自: md/types.zig BlockType + SpanType
// ============================================================================

/// Markdown AST 节点类型
public enum MdNodeType {
    | Document          // 根节点
    | Heading           // 标题 h1-h6
    | Paragraph         // 段落
    | Text              // 纯文本
    | Bold              // **strong** 或 __strong__
    | Italic            // *emphasis* 或 _emphasis_
    | Strikethrough     // ~~strikethrough~~
    | Code              // `inline code`
    | CodeBlock         // ```code block```
    | Link              // [text](url)
    | Image             // ![alt](url)
    | List              // 列表
    | ListItem          // 列表项
    | Blockquote        // 引用块
    | HorizontalRule    // 水平线 ---
    | Table             // 表格
    | TableRow          // 表格行
    | TableCell         // 表格单元格
    | Html              // 原始 HTML
    | SoftBreak         // 软换行
    | HardBreak         // 硬换行
    | TaskListMarker    // 任务列表标记 [ ] / [x]

    public operator func ==(right: MdNodeType): Bool {
        return this.name() == right.name()
    }

    public operator func !=(right: MdNodeType): Bool {
        return !(this == right)
    }

    /// 获取节点类型名称
    public func name(): String {
        match (this) {
            case Document => "document"
            case Heading => "heading"
            case Paragraph => "paragraph"
            case Text => "text"
            case Bold => "bold"
            case Italic => "italic"
            case Strikethrough => "strikethrough"
            case Code => "code"
            case CodeBlock => "code_block"
            case Link => "link"
            case Image => "image"
            case List => "list"
            case ListItem => "list_item"
            case Blockquote => "blockquote"
            case HorizontalRule => "hr"
            case Table => "table"
            case TableRow => "table_row"
            case TableCell => "table_cell"
            case Html => "html"
            case SoftBreak => "softbreak"
            case HardBreak => "hardbreak"
            case TaskListMarker => "task_marker"
        }
    }

    /// 是否为块级节点
    public func isBlock(): Bool {
        match (this) {
            case Document | Heading | Paragraph | CodeBlock |
                 List | ListItem | Blockquote | HorizontalRule |
                 Table | TableRow | TableCell | Html => true
            case _ => false
        }
    }

    /// 是否为行内节点
    public func isInline(): Bool {
        !isBlock()
    }
}

/// 列表类型
public enum MdListType {
    | Ordered           // 有序列表 1. 2. 3.
    | Unordered         // 无序列表 - * +
}

/// 表格对齐方式
/// 严格翻译自: md/types.zig Align
public enum MdTableAlign {
    | Default           // 未指定
    | Left              // 左对齐 :---
    | Center            // 居中 :---:
    | Right             // 右对齐 ---:
}

// ============================================================================
// Markdown AST 节点
// 严格翻译自: md/types.zig 各 Detail 结构
// ============================================================================

/// Markdown AST 节点
public class MdNode {
    /// 节点类型
    public var kind: MdNodeType
    /// 子节点
    public var children: ArrayList<MdNode>
    /// 文本内容 (Text, Code, Html, SoftBreak, HardBreak)
    public var text: String
    /// 标题级别 (1-6)
    public var headingLevel: Int64
    /// 代码块语言
    public var codeLanguage: String
    /// 代码块信息字符串
    public var codeInfo: String
    /// 链接地址
    public var linkUrl: String
    /// 链接标题
    public var linkTitle: String
    /// 图片 alt 文本
    public var imageAlt: String
    /// 列表类型
    public var listType: MdListType
    /// 有序列表起始序号
    public var listStart: Int64
    /// 列表是否紧凑
    public var listTight: Bool
    /// 任务列表标记: UInt8(32) 未完成, UInt8(120) 已完成
    public var taskMark: UInt8
    /// 表格列数
    public var tableColCount: Int64
    /// 表格对齐方式列表
    public var tableAlignments: ArrayList<MdTableAlign>
    /// 表格单元格对齐
    public var cellAlignment: MdTableAlign
    /// 表格是否为表头
    public var cellIsHeader: Bool
    /// 源位置 (起始偏移)
    public var sourceStart: Int64
    /// 源位置 (结束偏移)
    public var sourceEnd: Int64

    public init(kind: MdNodeType) {
        this.kind = kind
        this.children = ArrayList<MdNode>()
        this.text = ""
        this.headingLevel = 0
        this.codeLanguage = ""
        this.codeInfo = ""
        this.linkUrl = ""
        this.linkTitle = ""
        this.imageAlt = ""
        this.listType = MdListType.Unordered
        this.listStart = 1
        this.listTight = true
        this.taskMark = 0
        this.tableColCount = 0
        this.tableAlignments = ArrayList<MdTableAlign>()
        this.cellAlignment = MdTableAlign.Default
        this.cellIsHeader = false
        this.sourceStart = 0
        this.sourceEnd = 0
    }

    /// 创建文本节点
    public static func textNode(content: String): MdNode {
        let node = MdNode(MdNodeType.Text)
        node.text = content
        return node
    }

    /// 创建标题节点
    public static func heading(level: Int64): MdNode {
        let node = MdNode(MdNodeType.Heading)
        node.headingLevel = level
        return node
    }

    /// 创建代码块节点
    public static func codeBlock(language: String, info: String): MdNode {
        let node = MdNode(MdNodeType.CodeBlock)
        node.codeLanguage = language
        node.codeInfo = info
        return node
    }

    /// 创建行内代码节点
    public static func code(content: String): MdNode {
        let node = MdNode(MdNodeType.Code)
        node.text = content
        return node
    }

    /// 创建链接节点
    public static func link(url: String, title: String): MdNode {
        let node = MdNode(MdNodeType.Link)
        node.linkUrl = url
        node.linkTitle = title
        return node
    }

    /// 创建图片节点
    public static func image(url: String, alt: String, title: String): MdNode {
        let node = MdNode(MdNodeType.Image)
        node.linkUrl = url
        node.imageAlt = alt
        node.linkTitle = title
        return node
    }

    /// 创建列表节点
    public static func list(listType: MdListType, start: Int64, tight: Bool): MdNode {
        let node = MdNode(MdNodeType.List)
        node.listType = listType
        node.listStart = start
        node.listTight = tight
        return node
    }

    /// 添加子节点
    public func addChild(child: MdNode): Unit {
        children.append(child)
    }

    /// 获取第一个子节点
    public func firstChild(): ?MdNode {
        if (children.size > 0) { Some(children[0]) } else { None }
    }

    /// 获取最后一个子节点
    public func lastChild(): ?MdNode {
        if (children.size > 0) { Some(children[children.size - 1]) } else { None }
    }

    /// 获取所有文本内容 (递归)
    public func textContent(): String {
        let sb = StringBuilder()
        collectText(sb)
        return sb.toString()
    }

    private func collectText(sb: StringBuilder): Unit {
        if (kind == MdNodeType.Text || kind == MdNodeType.Code ||
            kind == MdNodeType.SoftBreak || kind == MdNodeType.HardBreak) {
            sb.append(text)
        }
        for (child in children) {
            child.collectText(sb)
        }
    }
}

// ============================================================================
// Markdown 解析选项
// 严格翻译自: md/types.zig Flags
// ============================================================================

/// Markdown 解析选项
/// 严格翻译自 Flags struct
public class MdParseOptions {
    /// 启用 GFM 表格
    public var tables: Bool
    /// 启用 GFM 删除线
    public var strikethrough: Bool
    /// 启用 GFM 任务列表
    public var tasklists: Bool
    /// 启用自动链接
    public var autolinks: Bool
    /// 允许 URL 自动链接
    public var permissiveUrlAutolinks: Bool
    /// 允许 www 自动链接
    public var permissiveWwwAutolinks: Bool
    /// 允许 email 自动链接
    public var permissiveEmailAutolinks: Bool
    /// 禁用缩进代码块
    public var noIndentedCodeBlocks: Bool
    /// 禁用 HTML 块
    public var noHtmlBlocks: Bool
    /// 禁用 HTML 行内标签
    public var noHtmlSpans: Bool

    public init() {
        this.tables = true
        this.strikethrough = true
        this.tasklists = true
        this.autolinks = true
        this.permissiveUrlAutolinks = false
        this.permissiveWwwAutolinks = false
        this.permissiveEmailAutolinks = false
        this.noIndentedCodeBlocks = false
        this.noHtmlBlocks = false
        this.noHtmlSpans = false
    }

    /// GFM 默认配置
    public static func gfm(): MdParseOptions {
        let opts = MdParseOptions()
        opts.tables = true
        opts.strikethrough = true
        opts.tasklists = true
        opts.autolinks = true
        return opts
    }

    /// CommonMark 严格配置
    public static func commonmark(): MdParseOptions {
        let opts = MdParseOptions()
        opts.tables = false
        opts.strikethrough = false
        opts.tasklists = false
        opts.autolinks = false
        return opts
    }
}

// ============================================================================
// 行类型分析
// 严格翻译自: md/types.zig LineType + md/line_analysis.zig
// ============================================================================

/// Markdown 行类型
/// 严格翻译自 LineType enum
private enum MdLineType {
    | Blank
    | Hr
    | AtxHeader
    | SetextUnderline
    | SetextHeader
    | IndentedCode
    | FencedCode
    | HtmlBlock
    | Text
    | Table
    | TableUnderline
}

/// 行分析结果
/// 严格翻译自 Line struct
private class MdLine {
    public var kind: MdLineType
    public var indent: Int64
    public var start: Int64
    public var end: Int64
    public var data: Int64

    public init() {
        this.kind = MdLineType.Blank
        this.indent = 0
        this.start = 0
        this.end = 0
        this.data = 0
    }
}

// ============================================================================
// Markdown Parser
// 严格翻译自: md/parser.zig Parser + md/blocks.zig processDoc
// ============================================================================

/// Markdown 解析器
/// 严格翻译自 Parser struct
/// 将 Markdown 文本解析为 AST
public class MarkdownParser {
    /// 输入文本
    private var source: String
    /// 当前位置
    private var pos: Int64
    /// 当前行号
    private var line: Int64
    /// 解析选项
    private var options: MdParseOptions
    /// 错误列表
    private var errors: ArrayList<String>

    public init() {
        this.source = ""
        this.pos = 0
        this.line = 1
        this.options = MdParseOptions.gfm()
        this.errors = ArrayList<String>()
    }

    /// 解析 Markdown 文本, 返回 AST 根节点
    /// 严格翻译自 processDoc
    public func parse(input: String): MdNode {
        return parse(input, MdParseOptions.gfm())
    }

    /// 解析 Markdown 文本 (带选项)
    public func parse(input: String, options: MdParseOptions): MdNode {
        this.source = input
        this.pos = 0
        this.line = 1
        this.options = options
        this.errors = ArrayList<String>()

        let doc = MdNode(MdNodeType.Document)
        let lines = splitLines(input)

        var i: Int64 = 0
        while (i < lines.size) {
            let line = lines[i]

            // 空行
            if (line.trimSpace().size == 0) {
                i++
                continue
            }

            // ATX 标题 (# )
            let headingResult = tryParseAtxHeading(line, i)
            match (headingResult) {
                case Some(result) =>
                    doc.addChild(result.node)
                    i++
                    continue
                case None => ()
            }

            // 水平线 --- *** ___
            if (isHrLine(line)) {
                doc.addChild(MdNode(MdNodeType.HorizontalRule))
                i++
                continue
            }

            // 围栏代码块 ```
            let fenceResult = tryParseFencedCodeBlock(lines, i)
            match (fenceResult) {
                case Some(result) =>
                    doc.addChild(result.node)
                    i = result.nextLine
                    continue
                case None => ()
            }

            // 引用块 >
            if (line.trimSpace().startsWith(">")) {
                let quoteResult = parseBlockquote(lines, i)
                match (quoteResult) {
                    case Some(result) =>
                        doc.addChild(result.node)
                        i = result.nextLine
                        continue
                    case None => ()
                }
            }

            // 列表 (-, *, +, 1.)
            let listResult = tryParseList(lines, i)
            match (listResult) {
                case Some(result) =>
                    doc.addChild(result.node)
                    i = result.nextLine
                    continue
                case None => ()
            }

            // 表格 (需要至少 2 行)
            let tableResult = tryParseTable(lines, i)
            match (tableResult) {
                case Some(result) =>
                    doc.addChild(result.node)
                    i = result.nextLine
                    continue
                case None => ()
            }

            // HTML 块
            if (isHtmlBlockStart(line)) {
                let htmlResult = parseHtmlBlock(lines, i)
                match (htmlResult) {
                    case Some(result) =>
                        doc.addChild(result.node)
                        i = result.nextLine
                        continue
                    case None => ()
                }
            }

            // 段落 (包含 Setext 标题检测)
            let paraResult = parseParagraph(lines, i)
            match (paraResult) {
                case Some(result) =>
                    doc.addChild(result.node)
                    i = result.nextLine
                    continue
                case None => ()
            }

            i++
        }

        return doc
    }

    // ========================================================================
    // ATX 标题解析 (# Heading)
    // 严格翻译自: line_analysis 中的 atxheader 检测
    // ========================================================================

    private func tryParseAtxHeading(line: String, lineIdx: Int64): ?MdParseResult {
        let trimmed = line.trimStartSpace()
        var level: Int64 = 0
        var i: Int64 = 0

        // 统计 # 数量
        while (i < trimmed.size && trimmed[i] == UInt8(35) && level < 6) {
            level++
            i++
        }

        if (level == 0) { return None }

        // # 后面必须有空格或行尾
        if (i < trimmed.size && trimmed[i] != UInt8(32) && trimmed[i] != UInt8(9)) {
            return None
        }

        // 跳过 # 后的空格
        while (i < trimmed.size && (trimmed[i] == UInt8(32) || trimmed[i] == UInt8(9))) {
            i++
        }

        // 获取标题文本
        var content = trimmed.sliceString(i)
        // 移除尾部 # 序列
        var end = content.size
        while (end > 0 && content[end - 1] == UInt8(35)) { end-- }
        // 如果 # 前面有空格, 移除空格和 #
        if (end > 0 && end < content.size && content[end] == UInt8(35)) {
            // 验证 # 序列
            var hashOnly = true
            for (j in end..content.size) {
                if (content[j] != UInt8(35)) { hashOnly = false; break }
            }
            if (hashOnly && end > 0 && content[end - 1] == UInt8(32)) {
                end--
                while (end > 0 && content[end - 1] == UInt8(32)) { end-- }
            } else {
                end = content.size
            }
        }
        content = content.sliceString(0, end).trimSpace()

        let node = MdNode.heading(level)
        parseInlineContent(content, node)
        return Some(MdParseResult(node, lineIdx + 1))
    }

    // ========================================================================
    // 围栏代码块解析
    // 严格翻译自: blocks 中的 fencedcode 处理
    // ========================================================================

    private func tryParseFencedCodeBlock(lines: ArrayList<String>, startLine: Int64): ?MdParseResult {
        let line = lines[startLine]
        let trimmed = line.trimStartSpace()
        let indent = line.size - trimmed.size

        // 检查围栏字符 ``` 或 ~~~
        if (trimmed.size < 3) { return None }
        let fenceChar = trimmed[0]
        if (fenceChar != UInt8(96) && fenceChar != UInt8(126)) { return None }

        // 统计围栏字符数
        var fenceLen: Int64 = 0
        var i: Int64 = 0
        while (i < trimmed.size && trimmed[i] == fenceChar) {
            fenceLen++
            i++
        }
        if (fenceLen < 3) { return None }

        // ~~~ 不能缩进超过 3 个空格
        if (indent >= 4) { return None }

        // 提取信息字符串 (语言)
        var infoStr = trimmed.sliceString(i).trimSpace()
        // ~~~ 的信息字符串不能包含 ~~~
        if (fenceChar == UInt8(126) && infoStr.contains("~~~")) {
            return None
        }

        // 提取语言名 (第一个 word)
        let language = extractLanguage(infoStr)

        // 收集代码行
        let codeLines = ArrayList<String>()
        var j = startLine + 1
        while (j < lines.size) {
            let codeLine = lines[j]

            // 检查关闭围栏
            let codeTrimmed = codeLine.trimStartSpace()
            if (codeTrimmed.size >= fenceLen) {
                var isClose = true
                var k: Int64 = 0
                while (k < fenceLen) {
                    if (codeTrimmed[k] != fenceChar) { isClose = false; break }
                    k++
                }
                // 关闭围栏后面只能是空格
                if (isClose) {
                    var rest = codeTrimmed.sliceString(fenceLen)
                    rest = rest.trimSpace()
                    if (rest.size == 0) {
                        j++ // 跳过关闭行
                        break
                    }
                }
            }

            // 代码内容 (移除最多 indent 个前导空格)
            var contentLine = codeLine
            var removeSpaces = indent
            var ci: Int64 = 0
            while (ci < contentLine.size && removeSpaces > 0 && contentLine[ci] == UInt8(32)) {
                ci++
                removeSpaces--
            }
            if (ci > 0) {
                contentLine = contentLine.sliceString(ci)
            }
            codeLines.append(contentLine)
            j++
        }

        let node = MdNode.codeBlock(language, infoStr)
        node.text = joinStrings("\n", codeLines)
        return Some(MdParseResult(node, j))
    }

    private static func extractLanguage(info: String): String {
        let trimmed = info.trimSpace()
        let sb = StringBuilder()
        for (c in trimmed) {
            if (c == UInt8(32) || c == UInt8(9)) { break }
            sb.append(c)
        }
        return sb.toString()
    }

    // ========================================================================
    // 引用块解析
    // ========================================================================

    private func parseBlockquote(lines: ArrayList<String>, startLine: Int64): ?MdParseResult {
        // 收集连续的引用行
        let quoteLines = ArrayList<String>()
        var j = startLine

        while (j < lines.size) {
            let line = lines[j]
            if (line.trimSpace().size == 0) { break }
            let trimmed = line.trimStartSpace()
            if (trimmed.startsWith(">")) {
                // 移除 > 和可选的空格
                var content = trimmed.sliceString(1)
                if (content.size > 0 && content[0] == UInt8(32)) {
                    content = content.sliceString(1)
                }
                quoteLines.append(content)
                j++
            } else {
                break
            }
        }

        if (quoteLines.size == 0) { return None }

        // 递归解析引用内容
        let innerParser = MarkdownParser()
        innerParser.options = this.options
        let innerText = joinStrings("\n", quoteLines)
        let innerDoc = innerParser.parse(innerText)

        let node = MdNode(MdNodeType.Blockquote)
        // 将内部文档的子节点转移到引用块
        for (child in innerDoc.children) {
            node.addChild(child)
        }

        return Some(MdParseResult(node, j))
    }

    // ========================================================================
    // 列表解析
    // 严格翻译自: blocks 中的 ul/ol 处理
    // ========================================================================

    private func tryParseList(lines: ArrayList<String>, startLine: Int64): ?MdParseResult {
        let line = lines[startLine]
        let trimmed = line.trimStartSpace()

        // 检测列表标记
        var listType = MdListType.Unordered
        var startNum: Int64 = 1
        var markerLen: Int64 = 0
        var contentStart: Int64 = 0

        if (trimmed.startsWith("- ") || trimmed.startsWith("* ") || trimmed.startsWith("+ ")) {
            listType = MdListType.Unordered
            markerLen = 1
            contentStart = 2
        } else {
            // 有序列表: 1. 或 1)
            let numResult = parseOrderedMarker(trimmed)
            match (numResult) {
                case Some(r) =>
                    listType = MdListType.Ordered
                    startNum = r.number
                    markerLen = r.markerLen
                    contentStart = r.contentStart
                case None => return None
            }
        }

        // 检查缩进
        let indent = line.size - trimmed.size
        if (indent >= 4) { return None }

        // 收集列表项
        let listNode = MdNode.list(listType, startNum, true)
        var j = startLine
        var itemStart = j

        while (j < lines.size) {
            let curLine = lines[j]
            let curTrimmed = curLine.trimStartSpace()

            // 空行结束列表 (除非后面跟着缩进内容)
            if (curTrimmed.size == 0) {
                // 查看下一行是否还是列表项
                if (j + 1 < lines.size) {
                    let nextTrimmed = lines[j + 1].trimStartSpace()
                    if (isListMarker(nextTrimmed)) {
                        j++
                        continue
                    }
                }
                break
            }

            // 同级列表标记
            if (isSameLevelListMarker(curTrimmed, listType)) {
                // 如果不是第一个, 先解析前一个项
                if (j > itemStart) {
                    let itemLines = extractLines(lines, itemStart, j)
                    let itemNode = parseListItem(itemLines)
                    listNode.addChild(itemNode)
                }
                itemStart = j
                j++
                continue
            }

            // 缩进内容 (属于当前列表项)
            let curIndent = curLine.size - curTrimmed.size
            if (curIndent >= 2) {
                j++
                continue
            }

            break
        }

        // 解析最后一个列表项
        if (j > itemStart) {
            let itemLines = extractLines(lines, itemStart, j)
            let itemNode = parseListItem(itemLines)
            listNode.addChild(itemNode)
        }

        if (listNode.children.size == 0) { return None }

        return Some(MdParseResult(listNode, j))
    }

    /// 解析有序列表标记
    private static func parseOrderedMarker(s: String): ?OrderedMarker {
        if (s.size < 2) { return None }

        var num: Int64 = 0
        var i: Int64 = 0
        while (i < s.size && s[i] >= UInt8(48) && s[i] <= UInt8(57)) {
            num = num * 10 + Int64(s[i] - UInt8(48))
            i++
        }

        if (i == 0 || i > 9) { return None }

        if (i < s.size && (s[i] == UInt8(46) || s[i] == UInt8(41))) {
            if (i + 1 < s.size && s[i + 1] == UInt8(32)) {
                return Some(OrderedMarker(num, i + 1, i + 2))
            }
        }

        return None
    }

    private static func isListMarker(trimmed: String): Bool {
        if (trimmed.startsWith("- ") || trimmed.startsWith("* ") || trimmed.startsWith("+ ")) {
            return true
        }
        let numResult = parseOrderedMarker(trimmed)
        match (numResult) {
            case Some(_) => return true
            case None => return false
        }
    }

    private static func isSameLevelListMarker(trimmed: String, listType: MdListType): Bool {
        match (listType) {
            case MdListType.Unordered =>
                trimmed.startsWith("- ") || trimmed.startsWith("* ") || trimmed.startsWith("+ ")
            case MdListType.Ordered =>
                match (parseOrderedMarker(trimmed)) {
                    case Some(_) => true
                    case None => false
                }
        }
    }

    /// 解析列表项
    private func parseListItem(itemLines: ArrayList<String>): MdNode {
        let itemNode = MdNode(MdNodeType.ListItem)

        // 提取内容行 (移除标记和缩进)
        let contentLines = ArrayList<String>()
        var firstLine = true
        for (line in itemLines) {
            let trimmed = line.trimStartSpace()
            if (firstLine) {
                // 移除标记
                if (trimmed.startsWith("- ") || trimmed.startsWith("* ") || trimmed.startsWith("+ ")) {
                    contentLines.append(trimmed.sliceString(2))
                } else {
                    let numResult = parseOrderedMarker(trimmed)
                    match (numResult) {
                        case Some(r) => contentLines.append(trimmed.sliceString(r.contentStart))
                        case None => contentLines.append(line)
                    }
                }
                firstLine = false

                // 检查任务列表标记
                let content = contentLines[contentLines.size - 1].trimStartSpace()
                if (options.tasklists && content.startsWith("[") && content.size >= 3 &&
                    (content[1] == UInt8(32) || content[1] == UInt8(120) || content[1] == UInt8(88)) &&
                    content[2] == UInt8(93)) {
                    let mark = content[1]
                    contentLines[contentLines.size - 1] = content.sliceString(3).trimStartSpace()
                    if (mark != UInt8(32)) {
                        itemNode.taskMark = UInt8(120)
                    } else {
                        itemNode.taskMark = UInt8(32)
                    }
                }
            } else {
                // 移除列表项缩进 (2 空格)
                var removeCount: Int64 = 2
                var ci: Int64 = 0
                while (ci < line.size && removeCount > 0 && line[ci] == UInt8(32)) {
                    ci++
                    removeCount--
                }
                contentLines.append(line.sliceString(ci))
            }
        }

        // 递归解析内容
        let innerText = joinStrings("\n", contentLines)
        let innerParser = MarkdownParser()
        innerParser.options = this.options
        let innerDoc = innerParser.parse(innerText)
        for (child in innerDoc.children) {
            itemNode.addChild(child)
        }

        return itemNode
    }

    // ========================================================================
    // 表格解析
    // 严格翻译自: blocks 中的 table 处理
    // ========================================================================

    private func tryParseTable(lines: ArrayList<String>, startLine: Int64): ?MdParseResult {
        if (!options.tables) { return None }
        if (startLine + 1 >= lines.size) { return None }

        let headerLine = lines[startLine].trimSpace()
        let sepLine = lines[startLine + 1].trimSpace()

        // 验证分隔行 (|---|---|)
        if (!isTableSeparator(sepLine)) { return None }

        // 解析列对齐
        let alignments = parseTableAlignments(sepLine)
        let colCount = alignments.size

        // 创建表格节点
        let tableNode = MdNode(MdNodeType.Table)
        tableNode.tableColCount = colCount
        tableNode.tableAlignments = alignments

        // 解析表头行
        let headerCells = parseTableRow(headerLine, colCount)
        let headerRow = MdNode(MdNodeType.TableRow)
        for (i in 0..headerCells.size) {
            let cell = MdNode(MdNodeType.TableCell)
            cell.cellIsHeader = true
            cell.cellAlignment = if (i < alignments.size) { alignments[i] } else { MdTableAlign.Default }
            parseInlineContent(headerCells[i].trimSpace(), cell)
            headerRow.addChild(cell)
        }
        tableNode.addChild(headerRow)

        // 解析数据行
        var j = startLine + 2
        while (j < lines.size) {
            let rowLine = lines[j].trimSpace()
            if (rowLine.size == 0 || !rowLine.contains("|")) { break }

            let cells = parseTableRow(rowLine, colCount)
            let dataRow = MdNode(MdNodeType.TableRow)
            for (i in 0..cells.size) {
                let cell = MdNode(MdNodeType.TableCell)
                cell.cellIsHeader = false
                cell.cellAlignment = if (i < alignments.size) { alignments[i] } else { MdTableAlign.Default }
                parseInlineContent(cells[i].trimSpace(), cell)
                dataRow.addChild(cell)
            }
            tableNode.addChild(dataRow)
            j++
        }

        if (j == startLine + 2) { return None }

        return Some(MdParseResult(tableNode, j))
    }

    private static func isTableSeparator(line: String): Bool {
        if (line.size == 0) { return false }
        let trimmed = line.trimSpace()
        if (trimmed[0] != UInt8(124) && trimmed[trimmed.size - 1] != UInt8(124)) {
            // 无外围 | 的情况
        }
        // 简化: 检查是否只包含 |, -, :, 空格
        for (c in trimmed) {
            if (c != UInt8(124) && c != UInt8(45) && c != UInt8(58) && c != UInt8(32) && c != UInt8(9)) {
                return false
            }
        }
        return trimmed.contains("-")
    }

    private static func parseTableAlignments(sepLine: String): ArrayList<MdTableAlign> {
        let alignments = ArrayList<MdTableAlign>()
        let cells = splitTableLine(sepLine)
        for (cell in cells) {
            let trimmed = cell.trimSpace()
            if (trimmed.size == 0) { continue }
            let leftColon = trimmed.size > 0 && trimmed[0] == UInt8(58)
            let rightColon = trimmed.size > 0 && trimmed[trimmed.size - 1] == UInt8(58)
            if (leftColon && rightColon) {
                alignments.append(MdTableAlign.Center)
            } else if (rightColon) {
                alignments.append(MdTableAlign.Right)
            } else if (leftColon) {
                alignments.append(MdTableAlign.Left)
            } else {
                alignments.append(MdTableAlign.Default)
            }
        }
        return alignments
    }

    private static func parseTableRow(line: String, colCount: Int64): ArrayList<String> {
        splitTableLine(line)
    }

    private static func splitTableLine(line: String): ArrayList<String> {
        let cells = ArrayList<String>()
        var trimmed = line.trimSpace()
        // 移除前后的 |
        if (trimmed.size > 0 && trimmed[0] == UInt8(124)) {
            trimmed = trimmed.sliceString(1)
        }
        if (trimmed.size > 0 && trimmed[trimmed.size - 1] == UInt8(124)) {
            trimmed = trimmed.sliceString(0, trimmed.size - 1)
        }

        // 按分割 | (忽略转义)
        var current = ""
        for (c in trimmed) {
            if (c == UInt8(124)) {
                cells.append(current)
                current = ""
            } else {
                current += "${c}"
            }
        }
        cells.append(current)
        return cells
    }

    // ========================================================================
    // HTML 块解析
    // ========================================================================

    private func isHtmlBlockStart(line: String): Bool {
        let trimmed = line.trimStartSpace()
        if (!trimmed.startsWith("<")) { return false }
        let lower = trimmed.toLowerCase()
        // 块级 HTML 标签
        if (lower.startsWith("<script") || lower.startsWith("<pre") ||
            lower.startsWith("<style") || lower.startsWith("<textarea")) { return true }
        if (lower.startsWith("<!--")) { return true }
        if (lower.startsWith("<!doctype")) { return true }
        // 块级元素
        if (lower.startsWith("<address") || lower.startsWith("<article") ||
            lower.startsWith("<aside") || lower.startsWith("<base") ||
            lower.startsWith("<blockquote") || lower.startsWith("<body") ||
            lower.startsWith("<div") || lower.startsWith("<fieldset") ||
            lower.startsWith("<figcaption") || lower.startsWith("<figure") ||
            lower.startsWith("<footer") || lower.startsWith("<form") ||
            lower.startsWith("<h1") || lower.startsWith("<h2") ||
            lower.startsWith("<h3") || lower.startsWith("<h4") ||
            lower.startsWith("<h5") || lower.startsWith("<h6") ||
            lower.startsWith("<header") || lower.startsWith("<hr") ||
            lower.startsWith("<main") || lower.startsWith("<nav") ||
            lower.startsWith("<ol") || lower.startsWith("<p") ||
            lower.startsWith("<section") || lower.startsWith("<table") ||
            lower.startsWith("<ul")) { return true }
        return false
    }

    private func parseHtmlBlock(lines: ArrayList<String>, startLine: Int64): ?MdParseResult {
        let sb = StringBuilder()
        var j = startLine

        // 第一行确定 HTML 块类型
        let firstLine = lines[startLine].trimStartSpace().toLowerCase()
        var endOnBlank = true

        if (firstLine.startsWith("<!--") || firstLine.startsWith("<script") ||
            firstLine.startsWith("<pre") || firstLine.startsWith("<style") ||
            firstLine.startsWith("<textarea")) {
            // 类型 1: 遇到对应关闭标签结束
            endOnBlank = false
        } else {
            // 类型 6/7: 遇到空行结束
            endOnBlank = true
        }

        while (j < lines.size) {
            let line = lines[j]
            if (endOnBlank && line.trimSpace().size == 0) { break }
            if (!endOnBlank) {
                let lower = line.toLowerCase()
                // 检查关闭标签
                if (firstLine.startsWith("<!--") && lower.contains("-->")) {
                    sb.append(line)
                    j++
                    break
                }
                if (firstLine.startsWith("<script") && lower.contains("</script>")) {
                    sb.append(line)
                    j++
                    break
                }
                if (firstLine.startsWith("<style") && lower.contains("</style>")) {
                    sb.append(line)
                    j++
                    break
                }
                if (firstLine.startsWith("<pre") && lower.contains("</pre>")) {
                    sb.append(line)
                    j++
                    break
                }
            }
            if (j > startLine) { sb.append("\n") }
            sb.append(line)
            j++
        }

        let node = MdNode(MdNodeType.Html)
        node.text = sb.toString()
        return Some(MdParseResult(node, j))
    }

    // ========================================================================
    // 段落解析 (包含 Setext 标题)
    // ========================================================================

    private func parseParagraph(lines: ArrayList<String>, startLine: Int64): ?MdParseResult {
        let sb = StringBuilder()
        var j = startLine

        while (j < lines.size) {
            let line = lines[j]
            // 空行结束段落
            if (line.trimSpace().size == 0) { break }
            // 水平线结束段落
            if (isHrLine(line)) { break }
            // ATX 标题结束段落
            if (line.trimStartSpace().startsWith("#")) { break }
            // 围栏代码块结束段落
            let trimmed = line.trimStartSpace()
            if (trimmed.startsWith("```") || trimmed.startsWith("~~~")) { break }
            // 列表标记结束段落 (如果不在段落开头)
            if (j > startLine && isListMarker(trimmed)) { break }
            // 引用结束段落
            if (j > startLine && trimmed.startsWith(">")) { break }

            // 检查 Setext 标题 (下一行是 === 或 ---)
            if (j + 1 < lines.size) {
                let nextLine = lines[j + 1].trimSpace()
                if (isSetextUnderline(nextLine)) {
                    // 这是一个 Setext 标题
                    let level = if (nextLine[0] == UInt8(61)) { 1 } else { 2 }
                    let node = MdNode.heading(level)
                    parseInlineContent(line.trimSpace(), node)
                    return Some(MdParseResult(node, j + 2))
                }
            }

            if (j > startLine) { sb.append("\n") }
            sb.append(line)
            j++
        }

        if (j == startLine) { return None }

        let node = MdNode(MdNodeType.Paragraph)
        parseInlineContent(sb.toString(), node)
        return Some(MdParseResult(node, j))
    }

    private static func isSetextUnderline(line: String): Bool {
        if (line.size == 0) { return false }
        let c = line[0]
        if (c != UInt8(61) && c != UInt8(45)) { return false }
        for (ch in line) {
            if (ch != c) { return false }
        }
        return true
    }

    // ========================================================================
    // 行内解析
    // 严格翻译自: md/inlines.zig processInlineContent
    // ========================================================================

    /// 解析行内内容, 将结果添加到父节点
    /// 严格翻译自 processInlineContent
    private func parseInlineContent(input: String, parent: MdNode): Unit {
        var text = input
        var i: Int64 = 0

        while (i < text.size) {
            let c = text[i]

            // 转义字符
            if (c == UInt8(92) && i + 1 < text.size && isAsciiPunctuation(text[i + 1])) {
                parent.addChild(MdNode.textNode("${text[i + 1]}"))
                i += 2
                continue
            }

            // 行内代码 `code`
            if (c == UInt8(96)) {
                let result = parseInlineCode(text, i)
                match (result) {
                    case Some(r) =>
                        parent.addChild(r.node)
                        i = r.nextPos
                        continue
                    case None => ()
                }
            }

            // 粗体/斜体 **bold** *italic* __bold__ _italic_
            if (c == UInt8(42) || c == UInt8(95)) {
                let result = parseEmphasis(text, i)
                match (result) {
                    case Some(r) =>
                        parent.addChild(r.node)
                        i = r.nextPos
                        continue
                    case None => ()
                }
            }

            // 删除线 ~~strikethrough~~
            if (c == UInt8(126) && options.strikethrough && i + 1 < text.size && text[i + 1] == UInt8(126)) {
                let result = parseStrikethrough(text, i)
                match (result) {
                    case Some(r) =>
                        parent.addChild(r.node)
                        i = r.nextPos
                        continue
                    case None => ()
                }
            }

            // 图片 ![alt](url)
            if (c == UInt8(33) && i + 1 < text.size && text[i + 1] == UInt8(91)) {
                let result = parseImage(text, i)
                match (result) {
                    case Some(r) =>
                        parent.addChild(r.node)
                        i = r.nextPos
                        continue
                    case None => ()
                }
            }

            // 链接 [text](url)
            if (c == UInt8(91)) {
                let result = parseLink(text, i)
                match (result) {
                    case Some(r) =>
                        parent.addChild(r.node)
                        i = r.nextPos
                        continue
                    case None => ()
                }
            }

            // 自动链接 <url>
            if (c == UInt8(60) && options.autolinks) {
                let result = parseAutolink(text, i)
                match (result) {
                    case Some(r) =>
                        parent.addChild(r.node)
                        i = r.nextPos
                        continue
                    case None => ()
                }
            }

            // 硬换行 (两个以上空格 + 换行)
            if (c == UInt8(10)) {
                if (i > 0 && text[i - 1] == UInt8(32) && i > 1 && text[i - 2] == UInt8(32)) {
                    parent.addChild(MdNode(MdNodeType.HardBreak))
                } else {
                    parent.addChild(MdNode(MdNodeType.SoftBreak))
                }
                i++
                continue
            }

            // HTML 行内标签
            if (c == UInt8(60) && !options.noHtmlSpans) {
                let result = parseHtmlTag(text, i)
                match (result) {
                    case Some(r) =>
                        parent.addChild(r.node)
                        i = r.nextPos
                        continue
                    case None => ()
                }
            }

            // 普通文本
            let textStart = i
            while (i < text.size) {
                let ch = text[i]
                if (ch == UInt8(42) || ch == UInt8(95) || ch == UInt8(96) || ch == UInt8(91) || ch == UInt8(33) ||
                    ch == UInt8(92) || ch == UInt8(60) || ch == UInt8(126) || ch == UInt8(10)) {
                    break
                }
                i++
            }
            if (i > textStart) {
                parent.addChild(MdNode.textNode(text.sliceString(textStart, i)))
            } else {
                // 无进度, 推进一个字符
                parent.addChild(MdNode.textNode("${text[i]}"))
                i++
            }
        }
    }

    /// 解析行内代码
    /// 严格翻译自 findCodeSpanEnd
    private static func parseInlineCode(text: String, start: Int64): ?InlineMdParseResult {
        var i = start
        let c = text[i]
        var openLen: Int64 = 0
        while (i < text.size && text[i] == c) {
            openLen++
            i++
        }

        // 寻找关闭的 `
        var closeStart: Int64 = -1
        while (i < text.size) {
            if (text[i] == c) {
                var closeLen: Int64 = 0
                let j = i
                while (i < text.size && text[i] == c) {
                    closeLen++
                    i++
                }
                if (closeLen == openLen) {
                    let content = text.sliceString(start + openLen, j)
                    let node = MdNode.code(normalizeCodeSpan(content))
                    return Some(InlineMdParseResult(node, i))
                }
            } else {
                i++
            }
        }

        return None
    }

    private static func normalizeCodeSpan(content: String): String {
        var result = content
        // 移除首尾换行
        if (result.size > 0 && result[0] == UInt8(10)) {
            result = result.sliceString(1)
        }
        if (result.size > 0 && result[result.size - 1] == UInt8(10)) {
            result = result.sliceString(0, result.size - 1)
        }
        // 折叠空白
        result = collapseWhitespace(result)
        return result
    }

    private static func collapseWhitespace(s: String): String {
        let sb = StringBuilder()
        var prevSpace = false
        for (c in s) {
            if (c == UInt8(32) || c == UInt8(9) || c == UInt8(10)) {
                if (!prevSpace) {
                    sb.append(UInt8(32))
                    prevSpace = true
                }
            } else {
                sb.append(c)
                prevSpace = false
            }
        }
        return sb.toString()
    }

    /// 解析强调/粗体
    /// 严格翻译自 emphasis 相关处理
    private static func parseEmphasis(text: String, start: Int64): ?InlineMdParseResult {
        let c = text[start]
        var runLen: Int64 = 0
        var i = start
        while (i < text.size && text[i] == c) {
            runLen++
            i++
        }

        // 寻找关闭
        var closePos: Int64 = -1
        while (i < text.size) {
            if (text[i] == c) {
                let j = i
                var closeLen: Int64 = 0
                while (i < text.size && text[i] == c) {
                    closeLen++
                    i++
                }
                // 匹配数量
                if (closeLen >= 2 && runLen >= 2) {
                    // 粗体
                    let content = text.sliceString(start + 2, j)
                    let node = MdNode(MdNodeType.Bold)
                    // 递归解析内部内容 (不通过 MarkdownParser, 直接在这里处理简单情况)
                    let textNode = MdNode.textNode(content)
                    node.addChild(textNode)
                    return Some(InlineMdParseResult(node, start + 2 + content.size + closeLen))
                }
                if (closeLen >= 1 && runLen >= 1) {
                    let useLen = if (runLen >= 2 && closeLen >= 2) { 2 } else { 1 }
                    let kind = if (useLen == 2) { MdNodeType.Bold } else { MdNodeType.Italic }
                    let content = text.sliceString(start + useLen, j)
                    let node = MdNode(kind)
                    node.addChild(MdNode.textNode(content))
                    return Some(InlineMdParseResult(node, start + useLen + content.size + useLen))
                }
            } else {
                i++
            }
        }

        return None
    }

    /// 解析删除线
    private static func parseStrikethrough(text: String, start: Int64): ?InlineMdParseResult {
        var i = start + 2 // 跳过 ~~

        while (i + 1 < text.size) {
            if (text[i] == UInt8(126) && text[i + 1] == UInt8(126)) {
                let content = text.sliceString(start + 2, i)
                let node = MdNode(MdNodeType.Strikethrough)
                node.addChild(MdNode.textNode(content))
                return Some(InlineMdParseResult(node, i + 2))
            }
            i++
        }

        return None
    }

    /// 解析链接 [text](url "title")
    /// 严格翻译自 links 中的 processLink
    private static func parseLink(text: String, start: Int64): ?InlineMdParseResult {
        if (start >= text.size || text[start] != UInt8(91)) { return None }
        var i = start + 1

        // 找到 ]
        var closeBracket: Int64 = -1
        var depth: Int64 = 1
        while (i < text.size) {
            if (text[i] == UInt8(91)) { depth++ }
            if (text[i] == UInt8(93)) {
                depth--
                if (depth == 0) {
                    closeBracket = i
                    break
                }
            }
            if (text[i] == UInt8(92) && i + 1 < text.size) { i++ }
            i++
        }

        if (closeBracket == -1) { return None }

        let linkText = text.sliceString(start + 1, closeBracket)

        // 检查 (
        if (closeBracket + 1 >= text.size || text[closeBracket + 1] != UInt8(40)) {
            return None
        }

        // 找到 )
        i = closeBracket + 2
        var urlStart = i
        var parenDepth: Int64 = 1
        while (i < text.size) {
            if (text[i] == UInt8(40)) { parenDepth++ }
            if (text[i] == UInt8(41)) {
                parenDepth--
                if (parenDepth == 0) { break }
            }
            i++
        }

        let urlContent = text.sliceString(urlStart, i).trimSpace()

        // 解析 url 和 title
        var url = ""
        var title = ""
        if (urlContent.size > 0) {
            if (urlContent[0] == UInt8(34) || urlContent[0] == UInt8(39)) {
                // 没有 url, 只有 title
            } else {
                // 查找 title
                let spaceIdx = urlContent.indexOf(UInt8(32))
                match (spaceIdx) {
                    case Some(idx) =>
                        url = urlContent.sliceString(0, idx)
                        let titlePart = urlContent.sliceString(idx + 1).trimSpace()
                        if (titlePart.size >= 2 &&
                            ((titlePart[0] == UInt8(34) && titlePart[titlePart.size - 1] == UInt8(34)) ||
                             (titlePart[0] == UInt8(39) && titlePart[titlePart.size - 1] == UInt8(39)))) {
                            title = titlePart.sliceString(1, titlePart.size - 1)
                        }
                    case None => url = urlContent
                }
            }
        }

        let node = MdNode.link(url, title)
        node.addChild(MdNode.textNode(linkText))
        return Some(InlineMdParseResult(node, i + 1))
    }

    /// 解析图片 ![alt](url "title")
    private static func parseImage(text: String, start: Int64): ?InlineMdParseResult {
        if (start + 1 >= text.size || text[start + 1] != UInt8(91)) { return None }
        var i = start + 2

        // 找到 ]
        var closeBracket: Int64 = -1
        while (i < text.size) {
            if (text[i] == UInt8(93)) {
                closeBracket = i
                break
            }
            i++
        }

        if (closeBracket == -1) { return None }

        let altText = text.sliceString(start + 2, closeBracket)

        // 检查 (
        if (closeBracket + 1 >= text.size || text[closeBracket + 1] != UInt8(40)) {
            return None
        }

        // 找到 )
        i = closeBracket + 2
        var urlStart = i
        while (i < text.size && text[i] != UInt8(41)) {
            i++
        }

        let urlContent = text.sliceString(urlStart, i).trimSpace()
        var url = ""
        var title = ""
        let spaceIdx = urlContent.indexOf(UInt8(32))
        match (spaceIdx) {
            case Some(idx) =>
                url = urlContent.sliceString(0, idx)
                let titlePart = urlContent.sliceString(idx + 1).trimSpace()
                if (titlePart.size >= 2 &&
                    titlePart[0] == UInt8(34) && titlePart[titlePart.size - 1] == UInt8(34)) {
                    title = titlePart.sliceString(1, titlePart.size - 1)
                }
            case None => url = urlContent
        }

        let node = MdNode.image(url, altText, title)
        return Some(InlineMdParseResult(node, i + 1))
    }

    /// 解析自动链接 <url>
    /// 严格翻译自 autolinks
    private static func parseAutolink(text: String, start: Int64): ?InlineMdParseResult {
        if (start >= text.size || text[start] != UInt8(60)) { return None }
        var i = start + 1
        while (i < text.size && text[i] != UInt8(62)) {
            if (text[i] == UInt8(60) || text[i] == UInt8(10)) { return None }
            i++
        }
        if (i >= text.size) { return None }

        let content = text.sliceString(start + 1, i)

        // 判断是 URL 还是 email
        if (content.toLowerCase().startsWith("http://") ||
            content.toLowerCase().startsWith("https://")) {
            let node = MdNode.link(content, "")
            node.addChild(MdNode.textNode(content))
            return Some(InlineMdParseResult(node, i + 1))
        }
        if (content.contains("@") && content.contains(".")) {
            let node = MdNode.link("mailto:${content}", "")
            node.addChild(MdNode.textNode(content))
            return Some(InlineMdParseResult(node, i + 1))
        }

        return None
    }

    /// 解析 HTML 行内标签
    private static func parseHtmlTag(text: String, start: Int64): ?InlineMdParseResult {
        if (start >= text.size || text[start] != UInt8(60)) { return None }
        var i = start + 1

        // 关闭标签
        if (i < text.size && text[i] == UInt8(47)) { i++ }

        // 标签名
        if (i >= text.size || !((text[i] >= UInt8(97) && text[i] <= UInt8(122)) || (text[i] >= UInt8(65) && text[i] <= UInt8(90)))) {
            return None
        }

        while (i < text.size && text[i] != UInt8(62)) {
            if (text[i] == UInt8(60)) { return None }
            i++
        }
        if (i >= text.size) { return None }

        let tag = text.sliceString(start, i + 1)
        let node = MdNode(MdNodeType.Html)
        node.text = tag
        return Some(InlineMdParseResult(node, i + 1))
    }

    // ========================================================================
    // 通用辅助
    // ========================================================================

    /// 是否为水平线
    /// 严格翻译自 isHrLine
    private static func isHrLine(line: String): Bool {
        let trimmed = line.trimSpace()
        if (trimmed.size < 3) { return false }
        let c = trimmed[0]
        if (c != UInt8(45) && c != UInt8(42) && c != UInt8(95)) { return false }
        var count: Int64 = 0
        for (ch in trimmed) {
            if (ch == c) { count++ }
            else if (ch != UInt8(32) && ch != UInt8(9)) { return false }
        }
        return count >= 3
    }

    /// 是否为 ASCII 标点
    private static func isAsciiPunctuation(c: UInt8): Bool {
        (c >= UInt8(33) && c <= UInt8(47)) || (c >= UInt8(58) && c <= UInt8(64)) ||
        (c >= UInt8(91) && c <= UInt8(96)) || (c >= UInt8(123) && c <= UInt8(126))
    }

    /// 分割行
    private static func splitLines(input: String): ArrayList<String> {
        let lines = ArrayList<String>()
        var current = ""
        for (c in input) {
            if (c == UInt8(13)) { continue }
            if (c == UInt8(10)) {
                lines.append(current)
                current = ""
            } else {
                current += "${c}"
            }
        }
        if (current.size > 0) {
            lines.append(current)
        }
        return lines
    }

    /// 提取行范围
    private static func extractLines(lines: ArrayList<String>, start: Int64, end: Int64): ArrayList<String> {
        let result = ArrayList<String>()
        for (i in start..end) {
            result.append(lines[i])
        }
        return result
    }
}

// ============================================================================
// 解析结果辅助类型
// ============================================================================

/// 解析结果 (节点 + 下一个要解析的行号)
private class MdParseResult {
    public var node: MdNode
    public var nextLine: Int64

    public init(node: MdNode, nextLine: Int64) {
        this.node = node
        this.nextLine = nextLine
    }
}

/// 行内解析结果 (节点 + 下一个要解析的位置)
private class InlineMdParseResult {
    public var node: MdNode
    public var nextPos: Int64

    public init(node: MdNode, nextPos: Int64) {
        this.node = node
        this.nextPos = nextPos
    }
}

/// 有序列表标记解析结果
private class OrderedMarker {
    public var number: Int64
    public var markerLen: Int64
    public var contentStart: Int64

    public init(number: Int64, markerLen: Int64, contentStart: Int64) {
        this.number = number
        this.markerLen = markerLen
        this.contentStart = contentStart
    }
}

// ============================================================================
// Markdown 渲染器
// 严格翻译自: md/html_renderer.zig HtmlRenderer
// ============================================================================

/// 渲染模式
public enum MdRenderMode {
    | Html              // 渲染为 HTML
    | Markdown          // 渲染为 Markdown
}

/// Markdown 渲染器
/// 将 AST 渲染为 HTML 或 Markdown 文本
public class MdRenderer {
    /// 渲染 AST 为 HTML
    /// 严格翻译自 HtmlRenderer
    public static func renderHtml(node: MdNode): String {
        let sb = StringBuilder()
        renderHtmlNode(node, sb)
        return sb.toString()
    }

    private static func renderHtmlNode(node: MdNode, sb: StringBuilder): Unit {
        match (node.kind) {
            case MdNodeType.Document =>
                for (child in node.children) {
                    renderHtmlNode(child, sb)
                    sb.append("\n")
                }
            case MdNodeType.Heading =>
                let level = node.headingLevel
                sb.append("<h${level}>")
                for (child in node.children) { renderHtmlNode(child, sb) }
                sb.append("</h${level}>")
            case MdNodeType.Paragraph =>
                sb.append("<p>")
                for (child in node.children) { renderHtmlNode(child, sb) }
                sb.append("</p>")
            case MdNodeType.Text =>
                sb.append(escapeHtml(node.text))
            case MdNodeType.Bold =>
                sb.append("<strong>")
                for (child in node.children) { renderHtmlNode(child, sb) }
                sb.append("</strong>")
            case MdNodeType.Italic =>
                sb.append("<em>")
                for (child in node.children) { renderHtmlNode(child, sb) }
                sb.append("</em>")
            case MdNodeType.Strikethrough =>
                sb.append("<del>")
                for (child in node.children) { renderHtmlNode(child, sb) }
                sb.append("</del>")
            case MdNodeType.Code =>
                sb.append("<code>${escapeHtml(node.text)}</code>")
            case MdNodeType.CodeBlock =>
                sb.append("<pre><code")
                if (node.codeLanguage.size > 0) {
                    sb.append(" class=\"language-${escapeHtml(node.codeLanguage)}\"")
                }
                sb.append(">${escapeHtml(node.text)}</code></pre>")
            case MdNodeType.Link =>
                sb.append("<a href=\"${escapeHtml(node.linkUrl)}\"")
                if (node.linkTitle.size > 0) {
                    sb.append(" title=\"${escapeHtml(node.linkTitle)}\"")
                }
                sb.append(">")
                for (child in node.children) { renderHtmlNode(child, sb) }
                sb.append("</a>")
            case MdNodeType.Image =>
                sb.append("<img src=\"${escapeHtml(node.linkUrl)}\" alt=\"${escapeHtml(node.imageAlt)}\"")
                if (node.linkTitle.size > 0) {
                    sb.append(" title=\"${escapeHtml(node.linkTitle)}\"")
                }
                sb.append(" />")
            case MdNodeType.List =>
                match (node.listType) {
                    case MdListType.Ordered =>
                        sb.append("<ol")
                        if (node.listStart != 1) {
                            sb.append(" start=\"${node.listStart}\"")
                        }
                        sb.append(">\n")
                    case MdListType.Unordered =>
                        sb.append("<ul>\n")
                }
                for (child in node.children) { renderHtmlNode(child, sb) }
                match (node.listType) {
                    case MdListType.Ordered => sb.append("</ol>")
                    case MdListType.Unordered => sb.append("</ul>")
                }
            case MdNodeType.ListItem =>
                sb.append("<li>")
                // 任务列表
                if (node.taskMark != 0) {
                    if (node.taskMark == UInt8(120) || node.taskMark == UInt8(88)) {
                        sb.append("<input type=\"checkbox\" disabled checked /> ")
                    } else {
                        sb.append("<input type=\"checkbox\" disabled /> ")
                    }
                }
                for (child in node.children) { renderHtmlNode(child, sb) }
                sb.append("</li>\n")
            case MdNodeType.Blockquote =>
                sb.append("<blockquote>\n")
                for (child in node.children) { renderHtmlNode(child, sb) }
                sb.append("</blockquote>")
            case MdNodeType.HorizontalRule =>
                sb.append("<hr />")
            case MdNodeType.Table =>
                sb.append("<table>\n")
                for (child in node.children) { renderHtmlNode(child, sb) }
                sb.append("</table>")
            case MdNodeType.TableRow =>
                sb.append("<tr>")
                for (child in node.children) { renderHtmlNode(child, sb) }
                sb.append("</tr>\n")
            case MdNodeType.TableCell =>
                let tag = if (node.cellIsHeader) { "th" } else { "td" }
                sb.append("<${tag}")
                match (node.cellAlignment) {
                    case MdTableAlign.Left => sb.append(" align=\"left\"")
                    case MdTableAlign.Center => sb.append(" align=\"center\"")
                    case MdTableAlign.Right => sb.append(" align=\"right\"")
                    case MdTableAlign.Default => ()
                }
                sb.append(">")
                for (child in node.children) { renderHtmlNode(child, sb) }
                sb.append("</${tag}>")
            case MdNodeType.Html =>
                sb.append(node.text)
            case MdNodeType.HardBreak =>
                sb.append("<br />")
            case MdNodeType.SoftBreak =>
                sb.append("\n")
            case MdNodeType.TaskListMarker => ()
        }
    }

    /// 渲染 AST 回 Markdown 文本
    public static func renderMarkdown(node: MdNode): String {
        let sb = StringBuilder()
        renderMarkdownNode(node, sb, 0)
        return sb.toString()
    }

    private static func renderMarkdownNode(node: MdNode, sb: StringBuilder, indentLevel: Int64): Unit {
        match (node.kind) {
            case MdNodeType.Document =>
                var first = true
                for (child in node.children) {
                    if (!first) { sb.append("\n\n") }
                    renderMarkdownNode(child, sb, indentLevel)
                    first = false
                }
                sb.append("\n")
            case MdNodeType.Heading =>
                for (i in 0..node.headingLevel) { sb.append("#") }
                sb.append(" ")
                sb.append(node.textContent())
            case MdNodeType.Paragraph =>
                sb.append(node.textContent())
            case MdNodeType.Text =>
                sb.append(node.text)
            case MdNodeType.Bold =>
                sb.append("**")
                for (child in node.children) { renderMarkdownNode(child, sb, indentLevel) }
                sb.append("**")
            case MdNodeType.Italic =>
                sb.append("*")
                for (child in node.children) { renderMarkdownNode(child, sb, indentLevel) }
                sb.append("*")
            case MdNodeType.Strikethrough =>
                sb.append("~~")
                for (child in node.children) { renderMarkdownNode(child, sb, indentLevel) }
                sb.append("~~")
            case MdNodeType.Code =>
                sb.append("`${node.text}`")
            case MdNodeType.CodeBlock =>
                sb.append("```")
                if (node.codeLanguage.size > 0) {
                    sb.append(node.codeLanguage)
                }
                sb.append("\n")
                sb.append(node.text)
                sb.append("\n```")
            case MdNodeType.Link =>
                sb.append("[")
                for (child in node.children) { renderMarkdownNode(child, sb, indentLevel) }
                sb.append("](${node.linkUrl}")
                if (node.linkTitle.size > 0) {
                    sb.append(" \"${node.linkTitle}\"")
                }
                sb.append(")")
            case MdNodeType.Image =>
                sb.append("![${node.imageAlt}](${node.linkUrl}")
                if (node.linkTitle.size > 0) {
                    sb.append(" \"${node.linkTitle}\"")
                }
                sb.append(")")
            case MdNodeType.List =>
                var idx: Int64 = 0
                for (child in node.children) {
                    if (idx > 0) { sb.append("\n") }
                    renderMarkdownNode(child, sb, indentLevel + 1)
                    idx++
                }
            case MdNodeType.ListItem =>
                for (i in 0..indentLevel - 1) { sb.append("  ") }
                if (node.taskMark != 0) {
                    if (node.taskMark == UInt8(120) || node.taskMark == UInt8(88)) {
                        sb.append("- [x] ")
                    } else {
                        sb.append("- [ ] ")
                    }
                }
                sb.append(node.textContent())
            case MdNodeType.Blockquote =>
                let lines = node.textContent().split("\n")
                for (line in lines) {
                    sb.append("> ${line}\n")
                }
            case MdNodeType.HorizontalRule =>
                sb.append("---")
            case MdNodeType.Table =>
                // 简化: 直接输出文本内容
                sb.append(node.textContent())
            case MdNodeType.Html =>
                sb.append(node.text)
            case MdNodeType.HardBreak =>
                sb.append("  \n")
            case MdNodeType.SoftBreak =>
                sb.append("\n")
            case MdNodeType.TaskListMarker => ()
            case MdNodeType.TableRow | MdNodeType.TableCell =>
                sb.append(node.textContent())
        }
    }

    /// HTML 转义
    private static func escapeHtml(s: String): String {
        let sb = StringBuilder()
        for (c in s) {
            match (c) {
                case '&' => sb.append("&amp;")
                case 60 => sb.append("&lt;")
                case 62 => sb.append("&gt;")
                case 34 => sb.append("&quot;")
                case 39 => sb.append("&#39;")
                case _ => sb.append(c)
            }
        }
        return sb.toString()
    }
}
