// 严格翻译自: src/md/parser.zig
// Markdown 解析器核心
package bao_md

import bao_core.*

// ============================================================================
// 解析器状态
// ============================================================================

/// 解析器上下文，包含解析期间的所有状态
public class Parser {
    public var text: String = ""
    public var size: OFF = 0
    public var flags: Flags = Flags()

    // 输出
    public var renderer: Renderer = Renderer()
    public var image_nesting_level: UInt32 = 0
    public var link_nesting_level: UInt32 = 0

    // 代码缩进偏移: 正常为 4，如果 no_indented_code_blocks 则为 UInt32 最大值
    public var code_indent_offset: UInt32 = 4
    public var doc_ends_with_newline: Bool = false

    // 标记字符映射
    public var mark_char_map: Array<Bool> = Array<Bool>(256, item: false)

    // 动态数组
    public var marks: Array<Mark> = []
    public var containers: Array<Container> = []
    public var block_bytes: Array<UInt8> = []
    public var buffer: StringBuilder = StringBuilder()
    public var emph_delims: Array<EmphDelim> = []

    // 活跃容器数量
    public var n_containers: UInt32 = 0

    // 当前正在构建的块
    public var current_block: ?Int64 = None
    public var current_block_lines: Array<VerbatimLine> = []

    // 操作符栈
    public var opener_stacks: Array<OpenerStack> = Array<OpenerStack>(Int64(NUM_OPENER_STACKS), item: OpenerStack())

    // 通过标记的链表
    public var unresolved_link_head: Int32 = -1
    public var unresolved_link_tail: Int32 = -1
    public var table_cell_boundaries_head: Int32 = -1
    public var table_cell_boundaries_tail: Int32 = -1

    // HTML 块跟踪
    public var html_block_type: UInt8 = 0
    // 围栏代码块缩进
    public var fence_indent: UInt32 = 0

    // 表格列对齐
    public var table_col_count: UInt32 = 0
    public var table_alignments: Array<Align> = Array<Align>(Int64(TABLE_MAXCOLCOUNT), item: Align.default)

    // 引用定义
    public var ref_defs: Array<RefDef> = []

    // 状态
    public var last_line_has_list_loosening_effect: Bool = false
    public var last_list_item_starts_with_two_blank_lines: Bool = false
    public var max_ref_def_output: UInt64 = 0

    public init() {}

    /// 初始化解析器
    public static func initFunc(text: String, flags: Flags, rend: Renderer): Parser {
        let size: OFF = OFF(text.length)
        let p = Parser()
        p.text = text
        p.size = size
        p.flags = flags
        p.renderer = rend
        p.code_indent_offset = if (flags.no_indented_code_blocks) UInt32.Max else 4
        p.doc_ends_with_newline = size > 0 && isNewline(UInt8(text[Int64(size - 1)]))
        p.max_ref_def_output = min(min(16 * UInt64(size), 1024 * 1024), UInt64(UInt32.Max))
        p.buildMarkCharMap()
        return p
    }

    /// 获取指定偏移量处的字符
    public func ch(off: OFF): UInt8 {
        if (off >= size) {
            return 0
        }
        return UInt8(text[Int64(off)])
    }

    /// 构建标记字符映射
    public func buildMarkCharMap(): Unit {
        mark_char_map = Array<Bool>(256, item: false)
        mark_char_map[Int64('\\'.toInt())] = true
        mark_char_map[Int64('*'.toInt())] = true
        mark_char_map[Int64('_'.toInt())] = true
        mark_char_map[Int64('`'.toInt())] = true
        mark_char_map[Int64('&'.toInt())] = true
        mark_char_map[Int64(';'.toInt())] = true
        mark_char_map[Int64('['.toInt())] = true
        mark_char_map[Int64('!'.toInt())] = true
        mark_char_map[Int64(']'.toInt())] = true
        mark_char_map[Int64(0)] = true
        mark_char_map[Int64('\n'.toInt())] = true // 换行符始终需要处理（硬/软换行）
        if (!flags.no_html_spans) {
            mark_char_map[Int64('<'.toInt())] = true
            mark_char_map[Int64('>'.toInt())] = true
        }
        if (flags.strikethrough) {
            mark_char_map[Int64('~'.toInt())] = true
        }
        if (flags.latex_math) {
            mark_char_map[Int64('$'.toInt())] = true
        }
        if (flags.permissive_email_autolinks || flags.permissive_url_autolinks) {
            mark_char_map[Int64(':'.toInt())] = true
        }
        if (flags.permissive_email_autolinks) {
            mark_char_map[Int64('@'.toInt())] = true
        }
        if (flags.permissive_www_autolinks) {
            mark_char_map[Int64('.'.toInt())] = true
        }
        if (flags.collapse_whitespace) {
            mark_char_map[Int64(' '.toInt())] = true
            mark_char_map[Int64('\t'.toInt())] = true
            mark_char_map[Int64('\r'.toInt())] = true
        }
    }

    /// 检查字符是否在标记字符映射中
    public func isMarkChar(c: UInt8): Bool {
        return mark_char_map[Int64(c)]
    }

    /// 查找引用定义
    public func lookupRefDef(label: String): ?RefDef {
        return lookupRefDef(this, label)
    }

    /// 获取块头
    public func getBlockHeaderAt(off: Int64): BlockHeader {
        let start = off
        let hdr = BlockHeader()
        if (start + 12 <= block_bytes.length) {
            hdr.block_type = BlockType.fromUInt8(block_bytes[Int64(start)])
            hdr.flags = readU32LE(block_bytes, start + 4)
            hdr.data = readU32LE(block_bytes, start + 8)
            let n_lines_off = start + 12 - 4
            hdr.n_lines = readU32LE(block_bytes, n_lines_off)
        }
        return hdr
    }

    /// 设置块头
    public func setBlockHeaderAt(off: Int64, hdr: BlockHeader): Unit {
        if (off + 16 <= block_bytes.length) {
            block_bytes[Int64(off)] = hdr.block_type.toUInt8()
            // pad 3 bytes
            block_bytes[Int64(off + 1)] = 0
            block_bytes[Int64(off + 2)] = 0
            block_bytes[Int64(off + 3)] = 0
            writeU32LE(block_bytes, off + 4, hdr.flags)
            writeU32LE(block_bytes, off + 8, hdr.data)
            writeU32LE(block_bytes, off + 12, hdr.n_lines)
        }
    }

    /// 获取块（同 getBlockHeaderAt）
    public func getBlockAt(off: Int64): BlockHeader {
        return getBlockHeaderAt(off)
    }

    /// 设置块
    public func setBlockAt(off: Int64, hdr: BlockHeader): Unit {
        setBlockHeaderAt(off, hdr)
    }
}

// ============================================================================
// 公共 API
// ============================================================================

/// 解析器 API（静态方法集合）
public class ParserApi {

    /// 渲染为 HTML
    public static func renderToHtml(text: String, flags: Flags, render_opts: RenderOptions): String {
        // 跳过 UTF-8 BOM
        let input = skipUtf8Bom(text)

        let html_renderer = HtmlRenderer(input, render_opts)
        let rend = html_renderer.renderer()

        let parser = Parser.init(input, flags, rend)
        processDoc(parser)

        return html_renderer.toOwnedString()
    }

    /// 使用自定义渲染器解析和渲染
    public static func renderWithRenderer(text: String, flags: Flags, render_options: RenderOptions, rend: Renderer): Unit {
        let input = skipUtf8Bom(text)

        let parser = Parser.init(input, flags, rend)
        processDoc(parser)
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 从字节数组读取小端序 UInt32
func readU32LE(bytes: Array<UInt8>, off: Int64): UInt32 {
    return UInt32(bytes[off]) |
           (UInt32(bytes[off + 1]) << 8) |
           (UInt32(bytes[off + 2]) << 16) |
           (UInt32(bytes[off + 3]) << 24)
}

/// 向字节数组写入小端序 UInt32
func writeU32LE(bytes: Array<UInt8>, off: Int64, value: UInt32): Unit {
    bytes[off] = UInt8(value & 0xFF)
    bytes[off + 1] = UInt8((value >> 8) & 0xFF)
    bytes[off + 2] = UInt8((value >> 16) & 0xFF)
    bytes[off + 3] = UInt8((value >> 24) & 0xFF)
}

/// UInt32 最大值常量（用于代码缩进）
public const CODE_INDENT_DISABLED: UInt32 = UInt32.Max
