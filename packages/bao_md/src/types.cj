// 严格翻译自: src/md/types.zig
// Markdown 解析器类型定义
package bao_md

import bao_core.*

// ============================================================================
// 基本类型
// ============================================================================

/// 文档偏移量
public typealias OFF = UInt32

/// 大小类型
public typealias SZ = UInt32

// ============================================================================
// 枚举类型
// ============================================================================

/// 块级元素类型，通过 enterBlock / leaveBlock 回调报告
public enum BlockType <: UInt8 {
    | doc
    | quote
    | ul
    | ol
    | li
    | hr
    | h
    | code
    | html
    | p
    | table
    | thead
    | tbody
    | tr
    | th
    | td
}

/// 行内元素类型，通过 enterSpan / leaveSpan 回调报告
public enum SpanType <: UInt8 {
    | em
    | strong
    | a
    | img
    | code
    | del
    | latexmath
    | latexmath_display
    | wikilink
    | u
}

/// 文本类型，通过 text 回调报告
public enum TextType <: UInt8 {
    | normal
    | null_char
    | br
    | softbr
    | entity
    | code
    | html
    | latexmath
}

/// 表格单元格对齐方式
public enum Align <: UInt8 {
    | default
    | left
    | center
    | right
}

// ============================================================================
// 详情结构体
// ============================================================================

/// 无序列表详情
public class UlDetail {
    public var is_tight: Bool = false
    public var mark: UInt8 = 0
    public init() {}
    public init(is_tight: Bool, mark: UInt8) {
        this.is_tight = is_tight
        this.mark = mark
    }
}

/// 有序列表详情
public class OlDetail {
    public var start: UInt32 = 0
    public var is_tight: Bool = false
    public var mark_delimiter: UInt8 = 0
    public init() {}
    public init(start: UInt32, is_tight: Bool, mark_delimiter: UInt8) {
        this.start = start
        this.is_tight = is_tight
        this.mark_delimiter = mark_delimiter
    }
}

/// 列表项详情
public class LiDetail {
    public var is_task: Bool = false
    public var task_mark: UInt8 = 0
    public var task_mark_offset: OFF = 0
    public init() {}
}

/// 标题详情
public class HDetail {
    public var level: UInt8 = 0
    public init() {}
    public init(level: UInt8) {
        this.level = level
    }
}

/// 代码块详情
public class CodeDetail {
    public var info: Attribute = Attribute()
    public var lang: Attribute = Attribute()
    public var fence_char: UInt8 = 0
    public init() {}
}

/// 表格详情
public class TableDetail {
    public var col_count: UInt32 = 0
    public var head_row_count: UInt32 = 0
    public var body_row_count: UInt32 = 0
    public init() {}
}

/// 表格单元格详情
public class TdDetail {
    public var alignment: Align = Align.default
    public init() {}
    public init(alignment: Align) {
        this.alignment = alignment
    }
}

/// 链接详情
public class ADetail {
    public var href: Attribute = Attribute()
    public var title: Attribute = Attribute()
    public init() {}
}

/// 图片详情
public class ImgDetail {
    public var src: Attribute = Attribute()
    public var title: Attribute = Attribute()
    public init() {}
}

/// Wikilink 详情
public class WikilinkDetail {
    public var target: Attribute = Attribute()
    public init() {}
}

// ============================================================================
// 渲染器接口
// ============================================================================

/// 渲染器接口。解析器调用这些方法产生输出。
public class Renderer {
    public var ptr: UIntNative = 0
    public var vtable: VTable = VTable()

    public init() {}

    public func enterBlock(block_type: BlockType, data: UInt32, flags: UInt32): Unit {
        vtable.enterBlock(ptr, block_type, data, flags)
    }

    public func leaveBlock(block_type: BlockType, data: UInt32): Unit {
        vtable.leaveBlock(ptr, block_type, data)
    }

    public func enterSpan(span_type: SpanType, detail: SpanDetail): Unit {
        vtable.enterSpan(ptr, span_type, detail)
    }

    public func leaveSpan(span_type: SpanType): Unit {
        vtable.leaveSpan(ptr, span_type)
    }

    public func text(text_type: TextType, content: String): Unit {
        vtable.text(ptr, text_type, content)
    }
}

/// 渲染器虚表
public class VTable {
    public var enterBlock: (UIntNative, BlockType, UInt32, UInt32) -> Unit = { _, _, _, _ => }
    public var leaveBlock: (UIntNative, BlockType, UInt32) -> Unit = { _, _, _ => }
    public var enterSpan: (UIntNative, SpanType, SpanDetail) -> Unit = { _, _, _ => }
    public var leaveSpan: (UIntNative, SpanType) -> Unit = { _, _ => }
    public var text: (UIntNative, TextType, String) -> Unit = { _, _, _ => }

    public init() {}
}

// ============================================================================
// 行内元素详情 (SpanDetail)
// ============================================================================

/// 行内元素详情数据（链接、图片、wikilink）
public class SpanDetail {
    public var href: String = ""
    public var title: String = ""
    /// 标准自动链接（尖括号）: 使用 writeUrlEscaped（不做实体/转义处理）
    public var autolink: Bool = false
    /// 标准自动链接是电子邮件: 在 href 前添加 "mailto:"
    public var permissive_autolink: Bool = false
    /// 宽松自动链接是电子邮件: 在 href 前添加 "mailto:"
    public var autolink_email: Bool = false
    /// 宽松 www 自动链接: 在 href 前添加 "http://"
    public var autolink_www: Bool = false

    public init() {}
    public init(href: String, title: String, autolink: Bool, permissive_autolink: Bool,
                autolink_email: Bool, autolink_www: Bool) {
        this.href = href
        this.title = title
        this.autolink = autolink
        this.permissive_autolink = permissive_autolink
        this.autolink_email = autolink_email
        this.autolink_www = autolink_www
    }
}

// ============================================================================
// 属性 (Attribute)
// ============================================================================

/// 子串类型
public enum SubstrType <: UInt8 {
    | normal
    | entity
}

/// 子串偏移
public class SubstrOffset {
    public var beg: OFF = 0
    public var end: OFF = 0
    public init() {}
    public init(beg: OFF, end: OFF) {
        this.beg = beg
        this.end = end
    }
}

/// 属性是可能包含嵌入实体的字符串。
/// 文本被拆分为子串，每个子串有一个类型（普通或实体）。
public class Attribute {
    public var substr_offsets: Array<SubstrOffset> = []
    public var substr_types: Array<SubstrType> = []

    public init() {}
    public init(substr_offsets: Array<SubstrOffset>, substr_types: Array<SubstrType>) {
        this.substr_offsets = substr_offsets
        this.substr_types = substr_types
    }

    public func text(src: String): String {
        if (substr_offsets.isEmpty) {
            return ""
        }
        let first = substr_offsets[0].beg
        let last = substr_offsets[substr_offsets.size - 1].end
        if (first >= src.length || last > src.length || first >= last) {
            return ""
        }
        return src.substring(Int64(first), Int64(last))
    }
}

// ============================================================================
// 行分析类型
// ============================================================================

/// 块分析期间的行类型
public enum LineType <: UInt8 {
    | blank
    | hr
    | atxheader
    | setextunderline
    | setextheader
    | indentedcode
    | fencedcode
    | html
    | text
    | table
    | tableunderline
}

/// 行分析结果
public class Line {
    public var type: LineType = LineType.blank
    public var beg: OFF = 0
    public var end: OFF = 0
    public var indent: UInt32 = 0
    public var data: UInt32 = 0
    public var enforce_new_block: Bool = false

    public init() {}
}

/// 逐字行（存储 beg/end 偏移以及缩进代码的缩进）
public class VerbatimLine {
    public var beg: OFF = 0
    public var end: OFF = 0
    public var indent: UInt32 = 0

    public init() {}
    public init(beg: OFF, end: OFF, indent: UInt32) {
        this.beg = beg
        this.end = end
        this.indent = indent
    }
}

// ============================================================================
// 容器类型
// ============================================================================

/// 容器类型：引用块或列表项
public class Container {
    public var ch: UInt8 = 0
    public var is_loose: Bool = false
    public var is_task: Bool = false
    public var task_mark_off: OFF = 0
    public var start: UInt32 = 0
    public var mark_indent: UInt32 = 0
    public var contents_indent: UInt32 = 0
    public var block_byte_off: UInt32 = 0

    public init() {}
}

// ============================================================================
// 块标志
// ============================================================================

/// 存储在 MD_BLOCK 中的块标志
public class BlockFlags {
    public var container_closer: Bool = false
    public var container_opener: Bool = false
    public var loose_list: Bool = false
    public var setext_header: Bool = false
    public var padding: UInt32 = 0

    public init() {}
}

public const BLOCK_CONTAINER_CLOSER: UInt32 = 0x01
public const BLOCK_CONTAINER_OPENER: UInt32 = 0x02
public const BLOCK_LOOSE_LIST: UInt32 = 0x04
public const BLOCK_SETEXT_HEADER: UInt32 = 0x08
public const BLOCK_FENCED_CODE: UInt32 = 0x10
public const BLOCK_REF_DEF_ONLY: UInt32 = 0x20

// ============================================================================
// 块描述符
// ============================================================================

/// 存储在 block_bytes 缓冲区中的块描述符
public class Block {
    public var type: BlockType = BlockType.doc
    public var flags: UInt32 = 0
    public var data: UInt32 = 0
    public var n_lines: UInt32 = 0

    public init() {}
    public init(type: BlockType, flags: UInt32, data: UInt32, n_lines: UInt32) {
        this.type = type
        this.flags = flags
        this.data = data
        this.n_lines = n_lines
    }
}

/// 块头（用于存储在 block_bytes 缓冲区中）
public class BlockHeader {
    public var block_type: BlockType = BlockType.doc
    public var pad: Array<UInt8> = [0, 0, 0]
    public var flags: UInt32 = 0
    public var data: UInt32 = 0
    public var n_lines: UInt32 = 0

    public init() {}
    public init(block_type: BlockType, flags: UInt32, data: UInt32, n_lines: UInt32) {
        this.block_type = block_type
        this.flags = flags
        this.data = data
        this.n_lines = n_lines
    }
}

// ============================================================================
// 标记标志
// ============================================================================

/// 标记标志
public class MarkFlags {
    public static let POTENTIAL_OPENER: UInt16 = 0x01
    public static let POTENTIAL_CLOSER: UInt16 = 0x02
    public static let OPENER: UInt16 = 0x04
    public static let CLOSER: UInt16 = 0x08
    public static let RESOLVED: UInt16 = 0x10

    // 强调分析标志
    public static let EMPH_INTRAWORD: UInt16 = 0x20
    public static let EMPH_MOD3_0: UInt16 = 0x40
    public static let EMPH_MOD3_1: UInt16 = 0x80
    public static let EMPH_MOD3_2: UInt16 = 0x100

    public static let EMPH_OC: UInt16 = (POTENTIAL_OPENER | POTENTIAL_CLOSER).toUInt16()
}

/// 行内处理系统中的标记
public class Mark {
    public var beg: OFF = 0
    public var end: OFF = 0
    public var prev: Int32 = -1
    public var next: Int32 = -1
    public var ch: UInt8 = 0
    public var flags: UInt16 = 0

    public init() {}
}

// ============================================================================
// 解析器标志
// ============================================================================

/// 控制启用哪些扩展的解析器标志
public class Flags {
    public var collapse_whitespace: Bool = false
    public var permissive_atx_headers: Bool = false
    public var permissive_url_autolinks: Bool = false
    public var permissive_www_autolinks: Bool = false
    public var permissive_email_autolinks: Bool = false
    public var no_indented_code_blocks: Bool = false
    public var no_html_blocks: Bool = false
    public var no_html_spans: Bool = false
    public var tables: Bool = true
    public var strikethrough: Bool = true
    public var tasklists: Bool = true
    public var latex_math: Bool = false
    public var wiki_links: Bool = false
    public var underline: Bool = false
    public var hard_soft_breaks: Bool = false

    public init() {}

    public static func commonmark(): Flags {
        let f = Flags()
        f.tables = false
        f.strikethrough = false
        f.tasklists = false
        return f
    }

    public static func github(): Flags {
        let f = Flags()
        f.tables = true
        f.strikethrough = true
        f.tasklists = true
        f.permissive_url_autolinks = true
        f.permissive_www_autolinks = true
        f.permissive_email_autolinks = true
        return f
    }

    public func permissiveAutolinks(): Bool {
        return permissive_url_autolinks || permissive_www_autolinks || permissive_email_autolinks
    }
}

// ============================================================================
// 操作符栈索引
// ============================================================================

/// 行内分析期间使用的操作符栈数量
/// 6 个给 *, 6 个给 _, 2 个给 ~, 1 个给方括号, 1 个给 $
public const NUM_OPENER_STACKS: Int64 = 16

// 操作符栈索引
public const ASTERISK_OPENERS_OO_0: Int64 = 0
public const ASTERISK_OPENERS_OO_1: Int64 = 1
public const ASTERISK_OPENERS_OO_2: Int64 = 2
public const ASTERISK_OPENERS_OC_0: Int64 = 3
public const ASTERISK_OPENERS_OC_1: Int64 = 4
public const ASTERISK_OPENERS_OC_2: Int64 = 5
public const UNDERSCORE_OPENERS_OO_0: Int64 = 6
public const UNDERSCORE_OPENERS_OO_1: Int64 = 7
public const UNDERSCORE_OPENERS_OO_2: Int64 = 8
public const UNDERSCORE_OPENERS_OC_0: Int64 = 9
public const UNDERSCORE_OPENERS_OC_1: Int64 = 10
public const UNDERSCORE_OPENERS_OC_2: Int64 = 11
public const TILDE_OPENERS_1: Int64 = 12
public const TILDE_OPENERS_2: Int64 = 13
public const BRACKET_OPENERS: Int64 = 14
public const DOLLAR_OPENERS: Int64 = 15

/// 操作符栈：通过标记索引的双向链表
public class OpenerStack {
    public var top: Int32 = -1
    public init() {}
}

// ============================================================================
// 内部限制
// ============================================================================

/// 匹配 md4c 的内部限制
public const CODESPAN_MARK_MAXLEN: UInt32 = 255
public const TABLE_MAXCOLCOUNT: UInt32 = 128

// ============================================================================
// 引用定义
// ============================================================================

/// 用于链接解析的引用定义
public class RefDef {
    public var label: String = ""
    public var dest: String = ""
    public var title: String = ""

    public init() {}
    public init(label: String, dest: String, title: String) {
        this.label = label
        this.dest = dest
        this.title = title
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 从块数据中提取表格单元格对齐方式
public func alignmentFromData(data: UInt32): Align {
    return Align.fromUInt8(UInt8(data & 0x03))
}

/// 获取对齐方式的字符串名称，默认返回 null
public func alignmentName(alignment: Align): ?String {
    match (alignment) {
        case Align.left => return "left"
        case Align.center => return "center"
        case Align.right => return "right"
        case _ => return None
    }
}

/// 从块数据中提取任务列表项标记。非任务项返回 0
public func taskMarkFromData(data: UInt32): UInt8 {
    return UInt8(data & 0xFF)
}

/// 检查任务标记是否表示已勾选
public func isTaskChecked(task_mark: UInt8): Bool {
    return task_mark != 0 && task_mark != UInt8(Array<UInt8>([' '.toInt()])[0])
}

/// 强调分隔符条目，用于 CommonMark 强调算法
public const MAX_EMPH_MATCHES: Int64 = 6

/// 强调分隔符
public class EmphDelim {
    public var pos: Int64 = 0        // 内容中的起始位置
    public var count: Int64 = 0      // 原始运行长度
    public var emph_char: UInt8 = 0  // * 或 _
    public var can_open: Bool = false
    public var can_close: Bool = false
    public var remaining: Int64 = 0  // 未消耗的字符数
    public var open_count: Int64 = 0 // 作为开标记消耗的总字符数
    public var close_count: Int64 = 0 // 作为闭标记消耗的总字符数
    public var open_sizes: Array<UInt8> = Array<UInt8>(MAX_EMPH_MATCHES, item: 0)
    public var open_num: UInt8 = 0   // 开标记匹配数
    public var close_sizes: Array<UInt8> = Array<UInt8>(MAX_EMPH_MATCHES, item: 0)
    public var close_num: UInt8 = 0  // 闭标记匹配数
    public var active: Bool = true   // 匹配对之间停用时为 false

    public init() {}
}

// Align 辅助扩展
public extension Align {
    static func fromUInt8(v: UInt8): Align {
        match (v) {
            case 0 => Align.default
            case 1 => Align.left
            case 2 => Align.center
            case 3 => Align.right
            case _ => Align.default
        }
    }
}
