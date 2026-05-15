// 严格翻译自: src/md/render_blocks.zig
// 块渲染方法
package bao_md

// ============================================================================
// 块级渲染
// ============================================================================

/// 进入块
public func enterBlock(parser: Parser, block_type: BlockType, data: UInt32, flags: UInt32): Unit {
    if (parser.image_nesting_level > 0) {
        return
    }
    parser.renderer.enterBlock(block_type, data, flags)
}

/// 离开块
public func leaveBlock(parser: Parser, block_type: BlockType, data: UInt32): Unit {
    if (parser.image_nesting_level > 0) {
        return
    }
    parser.renderer.leaveBlock(block_type, data)
}

/// 处理代码块
public func processCodeBlock(parser: Parser, block_lines: Array<VerbatimLine>, data: UInt32, flags: UInt32): Unit {
    var count = block_lines.length

    // 裁剪缩进代码块的尾部空行（非围栏）
    if ((flags & BLOCK_FENCED_CODE) == 0) {
        while (count > 0 && block_lines[Int64(count - 1)].beg >= block_lines[Int64(count - 1)].end) {
            count -= 1
        }
    }

    for (i in 0..count) {
        let vline = block_lines[Int64(i)]
        // 输出缩进内容
        for (j in 0..vline.indent) {
            emitText(parser, TextType.normal, " ")
        }
        let content = parser.text.substring(Int64(vline.beg), Int64(vline.end))
        emitText(parser, TextType.normal, content)
        emitText(parser, TextType.normal, "\n")
    }
}

/// 处理 HTML 块
public func processHtmlBlock(parser: Parser, block_lines: Array<VerbatimLine>): Unit {
    for (i in 0..block_lines.length) {
        let vline = block_lines[Int64(i)]
        if (i > 0) {
            emitText(parser, TextType.html, "\n")
        }
        for (j in 0..vline.indent) {
            emitText(parser, TextType.html, " ")
        }
        let content = parser.text.substring(Int64(vline.beg), Int64(vline.end))
        emitText(parser, TextType.html, content)
    }
    emitText(parser, TextType.html, "\n")
}

/// 处理表格块
public func processTableBlock(parser: Parser, block_lines: Array<VerbatimLine>, col_count: UInt32): Unit {
    if (block_lines.length < 2) {
        return
    }

    // 第一行是标题，第二行是下划线，其余是主体
    enterBlock(parser, BlockType.thead, 0, 0)
    enterBlock(parser, BlockType.tr, 0, 0)
    processTableRow(parser, block_lines[0], true, col_count)
    leaveBlock(parser, BlockType.tr, 0)
    leaveBlock(parser, BlockType.thead, 0)

    if (block_lines.length > 2) {
        enterBlock(parser, BlockType.tbody, 0, 0)
        for (i in 2..block_lines.length) {
            enterBlock(parser, BlockType.tr, 0, 0)
            processTableRow(parser, block_lines[Int64(i)], false, col_count)
            leaveBlock(parser, BlockType.tr, 0)
        }
        leaveBlock(parser, BlockType.tbody, 0)
    }
}

/// 处理表格行
public func processTableRow(parser: Parser, vline: VerbatimLine, is_header: Bool, col_count: UInt32): Unit {
    let row_text = parser.text.substring(Int64(vline.beg), Int64(vline.end))
    var start: Int64 = 0
    var cell_index: UInt32 = 0

    // 跳过前导管道符
    if (start < row_text.length && row_text[Int64(start)] == '|') {
        start += 1
    }

    while (start < row_text.length && cell_index < col_count) {
        // 查找单元格结束，跳过转义字符和代码跨度
        var end = start
        while (end < row_text.length && row_text[Int64(end)] != '|') {
            if (row_text[Int64(end)] == '\\' && end + 1 < row_text.length) {
                end += 2
            } else {
                end += 1
            }
        }

        // 跳过尾部管道符的空单元格
        if (end == row_text.length && start == end) {
            break
        }

        // 修剪单元格内容
        var cell_beg = start
        var cell_end = end
        while (cell_beg < cell_end && isBlank(UInt8(row_text[Int64(cell_beg)]))) {
            cell_beg += 1
        }
        while (cell_end > cell_beg && isBlank(UInt8(row_text[Int64(cell_end - 1)]))) {
            cell_end -= 1
        }

        let cell_type: BlockType = if (is_header) BlockType.th else BlockType.td
        let align_data: UInt32 = if (cell_index < TABLE_MAXCOLCOUNT) {
            parser.table_alignments[Int64(cell_index)].toUInt8().toUInt32()
        } else {
            0
        }
        enterBlock(parser, cell_type, align_data, 0)
        if (cell_beg < cell_end) {
            var cell_content = row_text.substring(cell_beg, cell_end)
            // GFM: \| 在表格单元格中应在表格级别处理，
            // 将 \| 替换为 | 后再进行行内处理
            let backslash_pipe = "\\|"
            if (cell_content.indexOf(backslash_pipe) >= 0) {
                var buf = StringBuilder()
                var ci: Int64 = 0
                while (ci < cell_content.length) {
                    if (cell_content[Int64(ci)] == '\\' && ci + 1 < cell_content.length && cell_content[Int64(ci + 1)] == '|') {
                        buf.append('|')
                        ci += 2
                    } else {
                        buf.append(cell_content[Int64(ci)])
                        ci += 1
                    }
                }
                cell_content = buf.toString()
            }
            processInlineContent(parser, cell_content, vline.beg + OFF(cell_beg))
        }
        leaveBlock(parser, cell_type, 0)
        cell_index += 1

        if (end < row_text.length) {
            start = end + 1 // 跳过 |
        } else {
            break
        }
    }

    // 填充短行空单元格
    let pad_type: BlockType = if (is_header) BlockType.th else BlockType.td
    while (cell_index < col_count) {
        let align_data: UInt32 = if (cell_index < TABLE_MAXCOLCOUNT) {
            parser.table_alignments[Int64(cell_index)].toUInt8().toUInt32()
        } else {
            0
        }
        enterBlock(parser, pad_type, align_data, 0)
        leaveBlock(parser, pad_type, 0)
        cell_index += 1
    }
}
