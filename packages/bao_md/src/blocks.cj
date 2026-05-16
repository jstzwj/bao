// 严格翻译自: src/md/blocks.zig
// 块级元素处理（文档处理、行分析、行处理）
package bao_md

import std.collection.*

/// Helper: LineType not-equal
func lineTypeNe(a: LineType, b: LineType): Bool {
    return match (a) {
        case LineType.line_none => match(b) { case LineType.line_none => false case _ => true }
        case LineType.blank => match(b) { case LineType.blank => false case _ => true }
        case LineType.hr => match(b) { case LineType.hr => false case _ => true }
        case LineType.atx => match(b) { case LineType.atx => false case _ => true }
        case LineType.setext => match(b) { case LineType.setext => false case _ => true }
        case LineType.code => match(b) { case LineType.code => false case _ => true }
        case LineType.html => match(b) { case LineType.html => false case _ => true }
        case LineType.text => match(b) { case LineType.text => false case _ => true }
        case LineType.table => match(b) { case LineType.table => false case _ => true }
        case LineType.tableunderline => match(b) { case LineType.tableunderline => false case _ => true }
        case LineType.fence => match(b) { case LineType.fence => false case _ => true }
    }
}

// ============================================================================
// 文档处理
// ============================================================================

/// 处理整个文档
public func processDoc(parser: Parser): Unit {
    let dummyBlank = Line()
    dummyBlank.`type` = LineType.blank

    var pivotLine = dummyBlank
    var lineBuf: Array<Line> = [Line(), Line()]
    var lineIdx: UInt8 = 0
    var off: OFF = 0

    parser.renderer.enterBlock(BlockType.doc, 0, 0)

    while (off < parser.size) {
        let lineResult = analyzeLine(parser, off, pivotLine)
        off = lineResult.off
        pivotLine = lineResult.pivot
        let line = lineResult.line

        processLine(parser, pivotLine, line)
    }

    endCurrentBlock(parser)

    // 构建引用定义哈希表
    buildRefDefHashtable(parser)

    // 处理所有块
    leaveChildContainers(parser, 0)
    processAllBlocks(parser)

    parser.renderer.leaveBlock(BlockType.doc, 0)
}

/// 行分析结果
public class AnalyzeLineResult {
    public var off: OFF = 0
    public var pivot: Line = Line()
    public var line: Line = Line()
    public init() {}
    public init(off: OFF, pivot: Line, line: Line) {
        this.off = off
        this.pivot = pivot
        this.line = line
    }
}

/// 分析一行
public func analyzeLine(parser: Parser, offStart: OFF, pivotLine: Line): AnalyzeLineResult {
    var off = offStart
    var totalIndent: UInt32 = 0
    var nParents: UInt32 = 0
    var nBrothers: UInt32 = 0
    var nChildren: UInt32 = 0
    var container = Container()
    let prevLineHasListLooseningEffect = parser.last_line_has_list_loosening_effect

    let line = Line()
    line.enforce_new_block = false

    // 消费缩进并匹配容器
    let indentResult = lineIndentation(parser.text, totalIndent, off)
    line.indent = indentResult.indent
    totalIndent += line.indent
    off = indentResult.off
    line.beg = off

    // 匹配现有容器
    var remainingIndent = totalIndent
    while (nParents < parser.n_containers) {
        let c = parser.containers[Int64(nParents)]
        if (c.ch == UInt8(0x3E)) {
            // 引用块延续
            if (off < parser.size && UInt8(parser.text[Int64(off)]) == UInt8(0x3E) && line.indent < parser.code_indent_offset) {
                off += 1
                totalIndent += 1
                let r = lineIndentation(parser.text, totalIndent, off)
                line.indent = r.indent
                totalIndent += line.indent
                off = r.off
                // '>' 后可选的第一个空格属于引用块标记
                if (line.indent > 0) {
                    line.indent -= 1
                }
                // 使用局部缩进进行后续列表容器匹配
                remainingIndent = line.indent
                line.beg = off
                nParents += 1
                continue
            } else {
                break
            }
        } else {
            // 列表延续 — 检查缩进是否匹配
            if (remainingIndent >= c.contents_indent) {
                remainingIndent -= c.contents_indent
                line.indent = remainingIndent
                nParents += 1
                continue
            } else {
                break
            }
        }
    }

    parser.last_line_has_list_loosening_effect = false

    // 空行惰性匹配列表容器
    if (off >= parser.size || isNewline(UInt8(parser.text[Int64(off)]))) {
        if (nBrothers + nChildren == 0) {
            while (nParents < parser.n_containers && parser.containers[Int64(nParents)].ch != UInt8(0x3E)) {
                nParents += 1
            }
        }
    }

    // 跟踪有效枢轴类型
    var effectivePivotType = pivotLine.`type`

    // 确定行类型
    var done = false
    while (!done) {
        // 检查围栏代码延续/关闭
        if ((match(effectivePivotType) { case LineType.fence => true case _ => false })) {
            line.beg = off

            // 检查关闭围栏
            if (line.indent < parser.code_indent_offset) {
                if (isClosingCodeFence(parser, off, pivotLine.data)) {
                    line.`type` = LineType.blank
                    parser.last_line_has_list_loosening_effect = false
                    break
                }
            }

            // 围栏代码延续（所有容器都必须匹配）
            if (nParents == parser.n_containers) {
                if (line.indent > parser.fence_indent) {
                    line.indent -= parser.fence_indent
                } else {
                    line.indent = 0
                }
                line.`type` = LineType.fence
                break
            }
        }

        // 检查 HTML 块延续
        if ((match(effectivePivotType) { case LineType.html => true case _ => false }) && parser.html_block_type > 0) {
            if (nParents < parser.n_containers) {
                parser.html_block_type = 0
            } else {
                if (isHtmlBlockEndCondition(parser, off, parser.html_block_type)) {
                    let endedType = parser.html_block_type
                    parser.html_block_type = 0

                    if (endedType == 6 || endedType == 7) {
                        line.`type` = LineType.blank
                        line.indent = 0
                        break
                    }
                }
                line.`type` = LineType.html
                nParents = parser.n_containers
                break
            }
        }

        // 检查空行
        if (off >= parser.size || isNewline(UInt8(parser.text[Int64(off)]))) {
            // 缩进代码通过空行延续
            if ((match(effectivePivotType) { case LineType.code => true case _ => false }) && nParents == parser.n_containers) {
                line.`type` = LineType.code
                if (line.indent > parser.code_indent_offset) {
                    line.indent -= parser.code_indent_offset
                } else {
                    line.indent = 0
                }
                parser.last_line_has_list_loosening_effect = false
            } else {
                line.`type` = LineType.blank
                parser.last_line_has_list_loosening_effect = (nParents > 0 &&
                    nBrothers + nChildren == 0 &&
                    parser.containers[Int64(nParents - 1)].ch != UInt8(0x3E))

                // HTML 块类型 6 和 7 在空行处结束
                if (parser.html_block_type >= 6) {
                    parser.html_block_type = 0
                }

                // 追踪以 2+ 空行开头的空列表项
                if (nParents > 0 && parser.containers[Int64(nParents - 1)].ch != UInt8(0x3E) &&
                    nBrothers + nChildren == 0 && (match(parser.current_block) { case None => true case _ => false }) &&
                    parser.block_bytes.size > 16) {
                    let topOff = parser.block_bytes.size - 16
                    if (topOff >= 0 && topOff + 16 <= parser.block_bytes.size) {
                        let topHdr = parser.getBlockHeaderAt(topOff)
                        if ((match(topHdr.block_type) { case BlockType.li => true case _ => false })) {
                            parser.last_list_item_starts_with_two_blank_lines = true
                        }
                    }
                }
            }
            break
        } else {
            // 非空行: 检查是否需要强制关闭空列表项
            if (parser.last_list_item_starts_with_two_blank_lines) {
                if (nParents > 0 && nParents == parser.n_containers &&
                    parser.containers[Int64(nParents - 1)].ch != UInt8(0x3E) &&
                    nBrothers + nChildren == 0 && (match(parser.current_block) { case None => true case _ => false }) &&
                    parser.block_bytes.size > 16) {
                    let topHdr = parser.getBlockHeaderAt(parser.block_bytes.size - 16)
                    if ((match(topHdr.block_type) { case BlockType.li => true case _ => false })) {
                        nParents -= 1
                        line.indent = totalIndent
                        if (nParents > 0) {
                            let parentContents = parser.containers[Int64(nParents - 1)].contents_indent
                            if (line.indent > parentContents) {
                                line.indent -= parentContents
                            } else {
                                line.indent = 0
                            }
                        }
                    }
                }
                parser.last_list_item_starts_with_two_blank_lines = false
            }
            parser.last_line_has_list_loosening_effect = false
        }

        // 缩进代码延续
        if ((match(effectivePivotType) { case LineType.code => true case _ => false })) {
            if (line.indent >= parser.code_indent_offset) {
                line.`type` = LineType.code
                line.indent -= parser.code_indent_offset
                line.data = 0
                break
            }
        }

        // 检查 Setext 下划线
        if (line.indent < parser.code_indent_offset && (match(effectivePivotType) { case LineType.text => true case _ => false }) &&
            off < parser.size && (UInt8(parser.text[Int64(off)]) == UInt8(0x3D) || UInt8(parser.text[Int64(off)]) == UInt8(0x2D)) &&
            nParents == parser.n_containers) {
            let setextResult = isSetextUnderline(parser, off)
            if (setextResult.is_setext) {
                line.`type` = LineType.setext
                line.data = setextResult.level
                break
            }
        }

        // 检查主题分割线
        if (line.indent < parser.code_indent_offset && off < parser.size &&
            (UInt8(parser.text[Int64(off)]) == UInt8(0x2D) || UInt8(parser.text[Int64(off)]) == UInt8(0x5F) || UInt8(parser.text[Int64(off)]) == UInt8(0x2A))) {
            if (isHrLine(parser, off)) {
                line.`type` = LineType.hr
                break
            }
        }

        // 检查兄弟容器（同列表中的另一个列表项）
        if (nParents < parser.n_containers && nBrothers + nChildren == 0) {
            let contResult = isContainerMark(parser, line.indent, off)
            if (contResult.is_container) {
                if (isContainerCompatible(parser, parser.containers[Int64(nParents)], contResult.container)) {
                    effectivePivotType = LineType.blank

                    container = contResult.container
                    off = contResult.off

                    totalIndent += container.contents_indent - container.mark_indent
                    let r = lineIndentation(parser.text, totalIndent, off)
                    line.indent = r.indent
                    totalIndent += line.indent
                    off = r.off
                    line.beg = off

                    // 调整属于标记的空白
                    if (off >= parser.size || isNewline(UInt8(parser.text[Int64(off)]))) {
                        container.contents_indent += 1
                    } else if (line.indent <= parser.code_indent_offset) {
                        container.contents_indent += line.indent
                        line.indent = 0
                    } else {
                        container.contents_indent += 1
                        line.indent -= 1
                    }

                    parser.containers[Int64(nParents)].mark_indent = container.mark_indent
                    parser.containers[Int64(nParents)].contents_indent = container.contents_indent

                    // 新的兄弟容器开始时 HTML 块结束
                    parser.html_block_type = 0

                    nBrothers += 1
                    continue
                }
            }
        }

        // 检查缩进代码
        if (line.indent >= parser.code_indent_offset && !(match(effectivePivotType) { case LineType.text => true case _ => false })) {
            line.`type` = LineType.code
            line.indent -= parser.code_indent_offset
            line.data = 0
            break
        }

        // 检查新容器块
        if (line.indent < parser.code_indent_offset) {
            let contResult = isContainerMark(parser, line.indent, off)
            if (contResult.is_container) {
                container = contResult.container

                // 列表标记不能中断段落，除非是 > 或有序列表以 1 开始
                if ((match(effectivePivotType) { case LineType.text => true case _ => false }) && nParents == parser.n_containers) {
                    if ((contResult.off >= parser.size || isNewline(UInt8(parser.ch(contResult.off)))) && container.ch != UInt8(0x3E)) {
                        // 列表标记后为空不能中断段落
                    } else if ((container.ch == UInt8(0x2E) || container.ch == UInt8(0x29)) && container.start != 1) {
                        // 有序列表起始 != 1 不能中断段落
                    } else {
                        off = contResult.off
                        totalIndent += container.contents_indent - container.mark_indent
                        let r = lineIndentation(parser.text, totalIndent, off)
                        line.indent = r.indent
                        totalIndent += line.indent
                        off = r.off
                        line.beg = off
                        line.data = UInt32(container.ch)

                        if (off >= parser.size || isNewline(UInt8(parser.text[Int64(off)]))) {
                            container.contents_indent += 1
                        } else if (line.indent <= parser.code_indent_offset) {
                            container.contents_indent += line.indent
                            line.indent = 0
                        } else {
                            container.contents_indent += 1
                            line.indent -= 1
                        }

                        if (nBrothers + nChildren == 0) {
                            effectivePivotType = LineType.blank
                        }

                        if (nChildren == 0) {
                            endCurrentBlock(parser)
                            leaveChildContainers(parser, nParents + nBrothers)
                        }

                        nChildren += 1
                        pushContainer(parser, container)
                        continue
                    }
                } else {
                    off = contResult.off
                    totalIndent += container.contents_indent - container.mark_indent
                    let r = lineIndentation(parser.text, totalIndent, off)
                    line.indent = r.indent
                    totalIndent += line.indent
                    off = r.off
                    line.beg = off
                    line.data = UInt32(container.ch)

                    if (off >= parser.size || isNewline(UInt8(parser.text[Int64(off)]))) {
                        container.contents_indent += 1
                    } else if (line.indent <= parser.code_indent_offset) {
                        container.contents_indent += line.indent
                        line.indent = 0
                    } else {
                        container.contents_indent += 1
                        line.indent -= 1
                    }

                    if (nBrothers + nChildren == 0) {
                        effectivePivotType = LineType.blank
                    }

                    if (nChildren == 0) {
                        endCurrentBlock(parser)
                        leaveChildContainers(parser, nParents + nBrothers)
                    }

                    nChildren += 1
                    pushContainer(parser, container)
                    continue
                }
            }
        }

        // 检查表格延续
        if ((match(effectivePivotType) { case LineType.table => true case _ => false }) && nParents == parser.n_containers) {
            line.`type` = LineType.table
            break
        }

        // 检查 ATX 标题
        if (line.indent < parser.code_indent_offset && off < parser.size && UInt8(parser.text[Int64(off)]) == UInt8(0x23)) {
            let atxResult = isAtxHeaderLine(parser, off)
            if (atxResult.is_atx) {
                line.`type` = LineType.atx
                line.data = atxResult.level
                line.beg = atxResult.content_beg

                // 修剪尾部空白
                while (line.end > line.beg && (isBlank(UInt8(parser.text[Int64(line.end - 1)])) || UInt8(parser.text[Int64(line.end - 1)]) == UInt8(0x09))) {
                    line.end -= 1
                }
                // 修剪可选的关闭 # 序列
                if (line.end > line.beg && UInt8(parser.text[Int64(line.end - 1)]) == UInt8(0x23)) {
                    var tmp = line.end
                    while (tmp > line.beg && UInt8(parser.text[Int64(tmp - 1)]) == UInt8(0x23)) {
                        tmp -= 1
                    }
                    if (tmp == line.beg || isBlank(UInt8(parser.text[Int64(tmp - 1)]))) {
                        line.end = tmp
                        // 再次修剪尾部空白
                        while (line.end > line.beg && isBlank(UInt8(parser.text[Int64(line.end - 1)]))) {
                            line.end -= 1
                        }
                    }
                }

                break
            }
        }

        // 检查打开的代码围栏
        if (line.indent < parser.code_indent_offset && off < parser.size &&
            (UInt8(parser.text[Int64(off)]) == UInt8(0x60) || UInt8(parser.text[Int64(off)]) == UInt8(0x7E))) {
            let fenceResult = isOpeningCodeFence(parser, off)
            if (fenceResult.is_fence) {
                line.`type` = LineType.fence
                line.data = fenceResult.fence_data
                line.enforce_new_block = true
                break
            }
        }

        // 检查 HTML 块开始
        if (off < parser.size && UInt8(parser.text[Int64(off)]) == UInt8(0x3C) && !parser.flags.no_html_blocks) {
            parser.html_block_type = isHtmlBlockStartCondition(parser, off)

            // 类型 7 不能中断段落
            if (parser.html_block_type == 7 && (match(effectivePivotType) { case LineType.text => true case _ => false })) {
                parser.html_block_type = 0
            }

            if (parser.html_block_type > 0) {
                if (isHtmlBlockEndCondition(parser, off, parser.html_block_type)) {
                    parser.html_block_type = 0
                }
                line.enforce_new_block = true
                line.`type` = LineType.html
                break
            }
        }

        // 检查表格下划线
        if (parser.flags.tables && (match(effectivePivotType) { case LineType.text => true case _ => false }) &&
            off < parser.size && (UInt8(parser.text[Int64(off)]) == UInt8(0x7C) || UInt8(parser.text[Int64(off)]) == UInt8(0x2D) || UInt8(parser.text[Int64(off)]) == UInt8(0x3A)) &&
            nParents == parser.n_containers) {
            let tblResult = isTableUnderline(parser, off)
            if (tblResult.is_underline && true /* current_block check */ && parser.current_block_lines.size >= 1) {
                // 验证标题行列数与分隔符行列数匹配
                let headerLine = parser.current_block_lines[Int64(parser.current_block_lines.size - 1)]
                let headerCols = countTableRowColumns(parser, headerLine.beg, headerLine.end)
                if (headerCols == tblResult.col_count) {
                    line.data = tblResult.col_count
                    line.`type` = LineType.tableunderline
                    break
                }
            }
        }

        // 默认: 普通文本行
        line.`type` = LineType.text
        if ((match(effectivePivotType) { case LineType.text => true case _ => false }) && nBrothers + nChildren == 0) {
            // 惰性延续
            nParents = parser.n_containers
        }

        // 检查任务标记
        if (parser.flags.tasklists && nBrothers + nChildren > 0 &&
            parser.n_containers > 0 &&
            isListItemMark(parser.containers[Int64(parser.n_containers - 1)].ch)) {
            var tmp = off
            while (tmp < parser.size && tmp < off + 3 && isBlank(UInt8(parser.text[Int64(tmp)]))) {
                tmp += 1
            }
            if (tmp + 2 < parser.size && UInt8(parser.text[Int64(tmp)]) == UInt8(0x5B) &&
                (UInt8(parser.text[Int64(tmp + 1)]) == UInt8(0x78) || UInt8(parser.text[Int64(tmp + 1)]) == UInt8(0x58) || UInt8(parser.text[Int64(tmp + 1)]) == UInt8(0x20)) &&
                UInt8(parser.text[Int64(tmp + 2)]) == UInt8(0x5D) &&
                (tmp + 3 == parser.size || isBlank(UInt8(parser.text[Int64(tmp + 3)])) || isNewline(UInt8(parser.text[Int64(tmp + 3)])))) {
                if (nChildren > 0) {
                    parser.containers[Int64(parser.n_containers - 1)].is_task = true
                    parser.containers[Int64(parser.n_containers - 1)].task_mark_off = UInt32(tmp + 1)
                } else {
                    container.is_task = true
                    container.task_mark_off = UInt32(tmp + 1)
                }
                off = UInt32(tmp + 3)
                while (off < parser.size && isWhitespace(UInt8(parser.text[Int64(off)]))) {
                    off += 1
                }
                line.beg = off
            }
        }

        done = true
    }

    // 扫描行尾
    while (off < parser.size && !isNewline(UInt8(parser.text[Int64(off)]))) {
        off += 1
    }

    line.end = off

    // 修剪 ATX 标题的尾部关闭标记
    if ((match(line.`type`) { case LineType.atx => true case _ => false })) {
        var tmp = line.end
        while (tmp > line.beg && isBlank(UInt8(parser.text[Int64(tmp - 1)]))) {
            tmp -= 1
        }
        while (tmp > line.beg && UInt8(parser.text[Int64(tmp - 1)]) == UInt8(0x23)) {
            tmp -= 1
        }
        if (tmp == line.beg || isBlank(UInt8(parser.text[Int64(tmp - 1)])) || parser.flags.permissive_atx_headers) {
            line.end = tmp
        }
    }

    // 修剪尾部空格（代码/HTML/文本除外）
    if (!(match(line.`type`) { case LineType.code => true case _ => false }) && !(match(line.`type`) { case LineType.fence => true case _ => false }) && !(match(line.`type`) { case LineType.html => true case _ => false }) && !(match(line.`type`) { case LineType.text => true case _ => false })) {
        while (line.end > line.beg && isBlank(UInt8(parser.text[Int64(line.end - 1)]))) {
            line.end -= 1
        }
    }

    // 消费换行符
    if (off < parser.size && UInt8(parser.text[Int64(off)]) == UInt8(0x0D)) {
        off += 1
    }
    if (off < parser.size && UInt8(parser.text[Int64(off)]) == UInt8(0x0A)) {
        off += 1
    }

    // 松散列表检测
    if (prevLineHasListLooseningEffect && !(match(line.`type`) { case LineType.blank => true case _ => false }) && nParents + nBrothers > 0) {
        let ci = nParents + nBrothers - 1
        if (Int64(ci) < parser.containers.size && parser.containers[Int64(ci)].ch != UInt8(0x3E)) {
            parser.containers[Int64(ci)].is_loose = true
        }
    }

    // 在容器转换前刷新当前叶块
    if ((nChildren == 0 && nParents + nBrothers < parser.n_containers) || nBrothers > 0 || nChildren > 0) {
        endCurrentBlock(parser)
    }

    // 离开不再参与的容器
    if (nChildren == 0 && nParents + nBrothers < parser.n_containers) {
        leaveChildContainers(parser, nParents + nBrothers)
    }

    // 进入兄弟容器
    if (nBrothers > 0) {
        // 关闭旧 LI，打开新 LI
        let liDataOld: UInt32 = if (parser.containers[Int64(nParents)].is_task) { UInt32(UInt8(parser.text[Int64(parser.containers[Int64(nParents)].task_mark_off)])) } else { 0 }
        pushContainerBytes(parser, BlockType.li, liDataOld, BLOCK_CONTAINER_CLOSER)
        let liDataNew: UInt32 = if (container.is_task) { UInt32(UInt8(parser.text[Int64(container.task_mark_off)])) } else { 0 }
        pushContainerBytes(parser, BlockType.li, liDataNew, BLOCK_CONTAINER_OPENER)
        parser.containers[Int64(nParents)].is_task = container.is_task
        parser.containers[Int64(nParents)].task_mark_off = container.task_mark_off
    }

    if (nChildren > 0) {
        enterChildContainers(parser, nChildren)
    }

    return AnalyzeLineResult(off, pivotLine, line)
}

/// 处理一行
public func processLine(parser: Parser, pivotLine: Line, line: Line): Unit {
    // 空行结束当前叶块
    if ((match(line.`type`) { case LineType.blank => true case _ => false })) {
        endCurrentBlock(parser)
        return
    }

    // 打开的代码围栏: 开始块但不包含围栏行作为内容
    if ((match(line.`type`) { case LineType.fence => true case _ => false }) && line.enforce_new_block) {
        endCurrentBlock(parser)
        startNewBlock(parser, line)
        parser.fence_indent = line.indent

        // 提取信息字符串位置并存储到块数据
        if (let Some(cbOff) <- parser.current_block) {
            let hdr = parser.getBlockHeaderAt(cbOff)
            let fenceCount = line.data >> 8
            var infoBeg: OFF = UInt32(line.beg) + fenceCount
            // 跳过信息字符串前的空白
            while (infoBeg < line.end && isBlank(UInt8(parser.text[Int64(infoBeg)]))) {
                infoBeg += 1
            }
            hdr.data = infoBeg
            hdr.flags |= BLOCK_FENCED_CODE
            parser.setBlockHeaderAt(cbOff, hdr)
        }
        return
    }

    if (line.enforce_new_block) {
        endCurrentBlock(parser)
    }

    // 单行块
    if ((match(line.`type`) { case LineType.hr => true case _ => false }) || (match(line.`type`) { case LineType.atx => true case _ => false })) {
        endCurrentBlock(parser)
        startNewBlock(parser, line)
        addLineToCurrentBlock(parser, line)
        endCurrentBlock(parser)
        return
    }

    // Setext 下划线将当前块改为标题
    if ((match(line.`type`) { case LineType.setext => true case _ => false })) {
        if (let Some(cbOff) <- parser.current_block) {
            var hdr = parser.getBlockHeaderAt(cbOff)
            hdr.block_type = BlockType.h
            hdr.data = line.data
            hdr.flags |= BLOCK_SETEXT_HEADER
            parser.setBlockHeaderAt(cbOff, hdr)
        }
        addLineToCurrentBlock(parser, line)
        endCurrentBlock(parser)
        if ((match(parser.current_block) { case None => true case _ => false })) {
            // 块正常关闭
        } else {
            // 块保持打开: 所有正文被引用定义消耗，
            // 下划线降级为新段落的开始
        }
        return
    }

    // 表格下划线
    if ((match(line.`type`) { case LineType.tableunderline => true case _ => false })) {
        if (let Some(cbOff) <- parser.current_block) {
            if (parser.current_block_lines.size > 1) {
                // 表格中断段落。拆分: 行 0..N-2 保持为段落，
                // 最后一行成为表格标题。
                let lastLine = parser.current_block_lines[Int64(parser.current_block_lines.size - 1)]
                // 移除当前段落块中的最后一行
                parser.current_block_lines = ArrayList<VerbatimLine>()
                var hdr = parser.getBlockHeaderAt(cbOff)
                hdr.n_lines -= 1
                parser.setBlockHeaderAt(cbOff, hdr)
                // 结束段落
                endCurrentBlock(parser)
                // 用保存的标题行开始新的表格块
                let headerAsLine = Line()
                headerAsLine.`type` = LineType.table
                headerAsLine.beg = lastLine.beg
                headerAsLine.end = lastLine.end
                headerAsLine.indent = lastLine.indent
                headerAsLine.data = line.data
                startNewBlock(parser, headerAsLine)
                addLineToCurrentBlock(parser, headerAsLine)
            } else {
                // 单行段落: 直接转换为表格
                var hdr = parser.getBlockHeaderAt(cbOff)
                hdr.block_type = BlockType.table
                hdr.data = line.data
                parser.setBlockHeaderAt(cbOff, hdr)
            }
        }
        // 更改枢轴为表格
        addLineToCurrentBlock(parser, line)
        return
    }

    // 不同行类型结束当前块
    if (lineTypeNe(line.`type`, pivotLine.`type`)) {
        endCurrentBlock(parser)
    }

    // 需要时开始新块
    if ((match(parser.current_block) { case None => true case _ => false })) {
        startNewBlock(parser, line)
    }

    // 添加行到当前块
    addLineToCurrentBlock(parser, line)
}

/// 开始新块
public func startNewBlock(parser: Parser, line: Line): Unit {
    let blockType: BlockType = match (line.`type`) {
        case LineType.hr => BlockType.hr
        case LineType.atx => BlockType.h
        case LineType.fence => BlockType.code
        case LineType.code => BlockType.code
        case LineType.html => BlockType.html
        case LineType.table => BlockType.table
        case LineType.tableunderline => BlockType.table
        case _ => BlockType.p
    }

    // 对齐 block_bytes
    let alignMask: Int64 = 15
    let curLen = parser.block_bytes.size
    let aligned = (curLen + alignMask) & (alignMask ^ (-1))
    let needed = aligned + 16

    // 填充零对齐
    while (parser.block_bytes.size < aligned) {
        parser.block_bytes.add(UInt8(0))
    }
    while (parser.block_bytes.size < needed) {
        parser.block_bytes.add(UInt8(0))
    }

    let hdr = BlockHeader()
    hdr.block_type = blockType
    hdr.flags = 0
    hdr.data = line.data
    hdr.n_lines = 0
    parser.setBlockHeaderAt(aligned, hdr)

    parser.current_block = aligned
    parser.current_block_lines = ArrayList<VerbatimLine>()
}

/// 添加行到当前块
public func addLineToCurrentBlock(parser: Parser, line: Line): Unit {
    if (let Some(cbOff) <- parser.current_block) {
        var hdr = parser.getBlockHeaderAt(cbOff)
        hdr.n_lines += 1
        parser.setBlockHeaderAt(cbOff, hdr)

        let vl = VerbatimLine()
        vl.beg = line.beg
        vl.end = line.end
        vl.indent = line.indent
        parser.current_block_lines.add(vl)
    }
}

/// 结束当前块
public func endCurrentBlock(parser: Parser): Unit {
    if (let Some(cbOff) <- parser.current_block) {
        var hdr = parser.getBlockHeaderAt(cbOff)

        // 从 setext 标题消费链接引用定义
        let isSetext = (match(hdr.block_type) { case BlockType.h => true case _ => false }) && (hdr.flags & BLOCK_SETEXT_HEADER) != 0
        if (isSetext && hdr.n_lines > 0 &&
            parser.current_block_lines.size > 0 &&
            parser.current_block_lines[0].beg < parser.size &&
            UInt8(parser.text[Int64(parser.current_block_lines[0].beg)]) == UInt8(0x5B)) {
            consumeRefDefsFromCurrentBlock(parser)
            hdr = parser.getBlockHeaderAt(cbOff)
        }

        // 处理引用定义消费后的 setext 标题
        if ((match(hdr.block_type) { case BlockType.h => true case _ => false }) && (hdr.flags & BLOCK_SETEXT_HEADER) != 0) {
            if (hdr.n_lines > 1) {
                // 移除下划线（最后一行）
                hdr.n_lines -= 1
                parser.current_block_lines = ArrayList<VerbatimLine>()
                parser.setBlockHeaderAt(cbOff, hdr)
            } else if (hdr.n_lines == 1) {
                // 引用定义消费后只剩下划线 → 转换为段落，
                // 保持块打开以便后续行加入此段落
                hdr.block_type = BlockType.p
                hdr.flags &= (BLOCK_SETEXT_HEADER ^ UInt32.Max)
                parser.setBlockHeaderAt(cbOff, hdr)
                return // 不关闭块
            } else {
                // 所有行被消费
                hdr.flags |= BLOCK_REF_DEF_ONLY
                parser.setBlockHeaderAt(cbOff, hdr)
            }
        }

        // 写入累积的行到 block_bytes
        for (i in 0..parser.current_block_lines.size) {
            let vl = parser.current_block_lines[i]
            // 将 VerbatimLine 的字段写入 block_bytes
            let base = parser.block_bytes.size
            // 确保足够空间
            while (parser.block_bytes.size < base + 12) {
                parser.block_bytes.add(UInt8(0))
            }
            writeU32LE(parser.block_bytes, base, UInt32(vl.beg))
            writeU32LE(parser.block_bytes, base + 4, UInt32(vl.end))
            writeU32LE(parser.block_bytes, base + 8, vl.indent)
        }

        parser.current_block = None
    }
}

/// 从当前块消费引用定义
public func consumeRefDefsFromCurrentBlock(parser: Parser): Unit {
    let items = parser.current_block_lines
    if (items.size == 0) {
        return
    }

    // 合并行到缓冲区用于引用定义解析
    parser.buffer = StringBuilder()
    for (i in 0..items.size) {
        let vline = items[i]
        if (vline.beg > vline.end || vline.end > parser.size) {
            continue
        }
        if (parser.buffer.size > 0) {
            parser.buffer.append('\n')
        }
        parser.buffer.append(parser.text[Int64(vline.beg)..Int64(vline.end)])
    }

    let merged = parser.buffer.toString()
    var pos: Int64 = 0
    var linesConsumed: UInt32 = 0

    while (pos < merged.size) {
        let resultOpt = parseRefDef(parser, merged, pos)
        if (let Some(result) <- resultOpt) {
            let normLabel = normalizeLabel(parser, result.label)
            if (normLabel.isEmpty()) {
                break
            }

            // 第一个定义优先
            var alreadyExists = false
            for (i in 0..parser.ref_defs.size) {
                if (parser.ref_defs[i].label == normLabel) {
                    alreadyExists = true
                    break
                }
            }
            if (!alreadyExists) {
                let rd = RefDef()
                rd.label = normLabel
                rd.dest = result.dest
                rd.title = result.title
                parser.ref_defs.add(rd)
            }

            var newlines: UInt32 = 0
            for (i in pos..result.end_pos) {
                if (UInt8(merged[Int64(i)]) == UInt8(0x0A)) {
                    newlines += 1
                }
            }
            if (result.end_pos >= merged.size && (result.end_pos == pos || UInt8(merged[Int64(result.end_pos - 1)]) != UInt8(0x0A))) {
                newlines += 1
            }
            linesConsumed += newlines
            pos = result.end_pos
        } else {
            break
        }
    }

    if (linesConsumed > 0) {
        if (let Some(cbOff) <- parser.current_block) {
            var hdr = parser.getBlockHeaderAt(cbOff)
            if (linesConsumed >= hdr.n_lines) {
                // 所有行被消费
                parser.current_block_lines = ArrayList<VerbatimLine>()
                hdr.n_lines = 0
            } else {
                // 移除前 linesConsumed 行
                let remaining = items.size - Int64(linesConsumed)
                var newLines: ArrayList<VerbatimLine> = ArrayList<VerbatimLine>()
                for (i in Int64(linesConsumed)..items.size) {
                    newLines.add(items[i])
                }
                parser.current_block_lines = newLines
                hdr.n_lines -= linesConsumed
            }
            parser.setBlockHeaderAt(cbOff, hdr)
        }
    }
}

/// 构建引用定义哈希表
public func buildRefDefHashtable(parser: Parser): Unit {
    // 引用定义已存储在 parser.ref_defs 数组中
    // 通过 lookupRefDef 进行线性查找
    // 这与 md4c 实现一致
}
