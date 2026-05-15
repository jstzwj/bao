// 严格翻译自: src/md/containers.zig
// 容器管理（引用块、列表）
package bao_md

// 容器管理功能由 Parser 类直接调用
// 核心逻辑已内联到 parser.cj 中的 Parser 类

/// 推送容器
public func pushContainer(parser: Parser, c: Container): Unit {
    parser.containers.append(Container().also {
        it.ch = c.ch; it.is_loose = c.is_loose; it.is_task = c.is_task
        it.task_mark_off = c.task_mark_off; it.start = c.start
        it.mark_indent = c.mark_indent; it.contents_indent = c.contents_indent
    })

    // 记录 block_byte 偏移
    let block_off: UInt32 = UInt32(parser.block_bytes.length)
    parser.containers[parser.n_containers].block_byte_off = block_off
    parser.n_containers += 1
}

/// 推送容器字节
public func pushContainerBytes(parser: Parser, block_type: BlockType, data: UInt32, flags: UInt32): Unit {
    // 对齐并添加块头
    let hdr = BlockHeader().also {
        it.block_type = block_type
        it.flags = flags
        it.data = data
        it.n_lines = 0
    }
    parser.block_bytes.append(hdr)
}

/// 进入子容器
public func enterChildContainers(parser: Parser, count: UInt32): Unit {
    var i: UInt32 = parser.n_containers - count
    while (i < parser.n_containers) {
        let c = parser.containers[Int64(i)]
        if (c.ch == '>'.toUInt8()) {
            pushContainerBytes(parser, BlockType.quote, 0, BLOCK_CONTAINER_OPENER)
        } else if (c.ch == '-'.toUInt8() || c.ch == '+'.toUInt8() || c.ch == '*'.toUInt8()) {
            pushContainerBytes(parser, BlockType.ul, 0, BLOCK_CONTAINER_OPENER)
            let li_data: UInt32 = if (c.is_task) UInt32(UInt8(parser.text[Int64(c.task_mark_off)])) else 0
            pushContainerBytes(parser, BlockType.li, li_data, BLOCK_CONTAINER_OPENER)
        } else if (c.ch == '.'.toUInt8() || c.ch == ')'.toUInt8()) {
            pushContainerBytes(parser, BlockType.ol, c.start, BLOCK_CONTAINER_OPENER)
            let li_data: UInt32 = if (c.is_task) UInt32(UInt8(parser.text[Int64(c.task_mark_off)])) else 0
            pushContainerBytes(parser, BlockType.li, li_data, BLOCK_CONTAINER_OPENER)
        }
        i += 1
    }
}

/// 离开子容器
public func leaveChildContainers(parser: Parser, keep: UInt32): Unit {
    while (parser.n_containers > keep) {
        parser.n_containers -= 1
        let c = parser.containers[Int64(parser.n_containers)]
        let loose_flag: UInt32 = if (c.is_loose) BLOCK_LOOSE_LIST else 0

        if (c.ch == '>'.toUInt8()) {
            pushContainerBytes(parser, BlockType.quote, 0, BLOCK_CONTAINER_CLOSER)
        } else if (c.ch == '-'.toUInt8() || c.ch == '+'.toUInt8() || c.ch == '*'.toUInt8()) {
            let li_data: UInt32 = if (c.is_task) UInt32(UInt8(parser.text[Int64(c.task_mark_off)])) else 0
            pushContainerBytes(parser, BlockType.li, li_data, BLOCK_CONTAINER_CLOSER)
            pushContainerBytes(parser, BlockType.ul, 0, BLOCK_CONTAINER_CLOSER | loose_flag)
        } else if (c.ch == '.'.toUInt8() || c.ch == ')'.toUInt8()) {
            let li_data: UInt32 = if (c.is_task) UInt32(UInt8(parser.text[Int64(c.task_mark_off)])) else 0
            pushContainerBytes(parser, BlockType.li, li_data, BLOCK_CONTAINER_CLOSER)
            pushContainerBytes(parser, BlockType.ol, c.start, BLOCK_CONTAINER_CLOSER | loose_flag)
        }
    }
}

/// 检查容器兼容性
public func isContainerCompatible(parser: Parser, existing: Container, new: Container): Bool {
    if (existing.ch == '>'.toUInt8() && new.ch == '>'.toUInt8()) {
        return true
    }
    if (existing.ch == new.ch) {
        return true
    }
    if (isListBullet(existing.ch) && isListBullet(new.ch)) {
        return false
    }
    return false
}

/// 处理所有块
public func processAllBlocks(parser: Parser): Unit {
    parser.n_containers = 0

    for (block in parser.block_bytes) {
        let block_type = block.type
        let n_lines = block.n_lines
        let data = block.data
        let flags = block.flags

        // 处理容器开/闭
        if ((flags & BLOCK_CONTAINER_OPENER) != 0) {
            enterBlock(parser, block_type, data, flags)
            if (block_type == BlockType.ul || block_type == BlockType.ol) {
                if (parser.n_containers < parser.containers.length) {
                    parser.containers[Int64(parser.n_containers)].is_loose = (flags & BLOCK_LOOSE_LIST) != 0
                    parser.n_containers += 1
                }
            } else if (block_type == BlockType.quote) {
                if (parser.n_containers < parser.containers.length) {
                    parser.containers[Int64(parser.n_containers)].is_loose = true
                    parser.n_containers += 1
                }
            }
            continue
        }
        if ((flags & BLOCK_CONTAINER_CLOSER) != 0) {
            if (block_type == BlockType.ul || block_type == BlockType.ol || block_type == BlockType.quote) {
                if (parser.n_containers > 0) {
                    parser.n_containers -= 1
                }
            }
            leaveBlock(parser, block_type, data)
            continue
        }

        // 跳过完全被引用定义消耗的段落块
        if ((flags & BLOCK_REF_DEF_ONLY) != 0) {
            continue
        }

        // 确定是否在紧凑列表中
        let is_in_tight_list = parser.n_containers > 0 &&
            !parser.containers[Int64(parser.n_containers - 1)].is_loose

        // 处理叶块
        if (!is_in_tight_list || block_type != BlockType.p) {
            enterBlock(parser, block_type, data, flags)
        }
        // 这里简化了叶块处理，实际需要按类型分发
        if (!is_in_tight_list || block_type != BlockType.p) {
            leaveBlock(parser, block_type, data)
        }
    }
}

/// 进入块（委托给渲染器）
public func enterBlock(parser: Parser, block_type: BlockType, data: UInt32, flags: UInt32): Unit {
    if (parser.image_nesting_level > 0) {
        return
    }
    parser.renderer.enterBlock(block_type, data, flags)
}

/// 离开块（委托给渲染器）
public func leaveBlock(parser: Parser, block_type: BlockType, data: UInt32): Unit {
    if (parser.image_nesting_level > 0) {
        return
    }
    parser.renderer.leaveBlock(block_type, data)
}
