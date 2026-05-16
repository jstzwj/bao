// 严格翻译自: src/md/containers.zig
// 容器管理（引用块、列表）
package bao_md

import std.collection.*

// 容器管理功能由 Parser 类直接调用
// 核心逻辑已内联到 parser.cj 中的 Parser 类

/// 推送容器
public func pushContainer(parser: Parser, c: Container): Unit {
    let newC = Container()
    newC.ch = c.ch; newC.is_loose = c.is_loose; newC.is_task = c.is_task
    newC.task_mark_off = c.task_mark_off; newC.start = c.start
    newC.mark_indent = c.mark_indent; newC.contents_indent = c.contents_indent
    parser.containers.add(newC)

    // 记录 block_byte 偏移
    let block_off: UInt32 = UInt32(parser.block_bytes.size)
    parser.containers[Int64(parser.n_containers)].block_byte_off = block_off
    parser.n_containers += 1
}

/// 推送容器字节
public func pushContainerBytes(parser: Parser, block_type: BlockType, data: UInt32, flags: UInt32): Unit {
    // 对齐并添加块头 (16 bytes)
    while ((parser.block_bytes.size % 16) != 0) {
        parser.block_bytes.add(UInt8(0))
    }
    // Allocate 16 bytes
    var i: Int64 = 0
    while (i < 16) {
        parser.block_bytes.add(UInt8(0))
        i += 1
    }
    // Write header at the position
    let off = parser.block_bytes.size - 16
    parser.block_bytes[Int64(off)] = block_type.toUInt8()
    writeU32LE(parser.block_bytes, off + 4, flags)
    writeU32LE(parser.block_bytes, off + 8, data)
    writeU32LE(parser.block_bytes, off + 12, 0) // n_lines = 0
}

/// 进入子容器
public func enterChildContainers(parser: Parser, count: UInt32): Unit {
    var i: UInt32 = parser.n_containers - count
    while (i < parser.n_containers) {
        let c = parser.containers[Int64(i)]
        if (c.ch == UInt8(0x3E)) {
            pushContainerBytes(parser, BlockType.`quote`, 0, BLOCK_CONTAINER_OPENER)
        } else if (c.ch == UInt8(0x2D) || c.ch == UInt8(0x2B) || c.ch == UInt8(0x2A)) {
            pushContainerBytes(parser, BlockType.ul, 0, BLOCK_CONTAINER_OPENER)
            let li_data: UInt32 = if (c.is_task) { UInt32(UInt8(parser.text[Int64(c.task_mark_off)])) } else { 0 }
            pushContainerBytes(parser, BlockType.li, li_data, BLOCK_CONTAINER_OPENER)
        } else if (c.ch == UInt8(0x2E) || c.ch == UInt8(0x29)) {
            pushContainerBytes(parser, BlockType.ol, c.start, BLOCK_CONTAINER_OPENER)
            let li_data: UInt32 = if (c.is_task) { UInt32(UInt8(parser.text[Int64(c.task_mark_off)])) } else { 0 }
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
        let loose_flag: UInt32 = if (c.is_loose) { BLOCK_LOOSE_LIST } else { 0 }

        if (c.ch == UInt8(0x3E)) {
            pushContainerBytes(parser, BlockType.`quote`, 0, BLOCK_CONTAINER_CLOSER)
        } else if (c.ch == UInt8(0x2D) || c.ch == UInt8(0x2B) || c.ch == UInt8(0x2A)) {
            let li_data: UInt32 = if (c.is_task) { UInt32(UInt8(parser.text[Int64(c.task_mark_off)])) } else { 0 }
            pushContainerBytes(parser, BlockType.li, li_data, BLOCK_CONTAINER_CLOSER)
            pushContainerBytes(parser, BlockType.ul, 0, BLOCK_CONTAINER_CLOSER | loose_flag)
        } else if (c.ch == UInt8(0x2E) || c.ch == UInt8(0x29)) {
            let li_data: UInt32 = if (c.is_task) { UInt32(UInt8(parser.text[Int64(c.task_mark_off)])) } else { 0 }
            pushContainerBytes(parser, BlockType.li, li_data, BLOCK_CONTAINER_CLOSER)
            pushContainerBytes(parser, BlockType.ol, c.start, BLOCK_CONTAINER_CLOSER | loose_flag)
        }
    }
}

/// 检查容器兼容性
public func isContainerCompatible(parser: Parser, existing: Container, new: Container): Bool {
    if (existing.ch == UInt8(0x3E) && new.ch == UInt8(0x3E)) {
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

    var pos: Int64 = 0
    while (pos + 16 <= parser.block_bytes.size) {
        let block_type = BlockType.fromUInt8(parser.block_bytes[Int64(pos)])
        let flags = readU32LE(parser.block_bytes, pos + 4)
        let data = readU32LE(parser.block_bytes, pos + 8)
        let n_lines = readU32LE(parser.block_bytes, pos + 12)

        // 处理容器开/闭
        if ((flags & BLOCK_CONTAINER_OPENER) != 0) {
            enterBlock(parser, block_type, data, flags)
            if ((match(block_type) { case BlockType.ul => true case BlockType.ol => true case _ => false })) {
                if (Int64(parser.n_containers) < parser.containers.size) {
                    parser.containers[Int64(parser.n_containers)].is_loose = (flags & BLOCK_LOOSE_LIST) != 0
                    parser.n_containers += 1
                }
            } else if ((match(block_type) { case BlockType.`quote` => true case _ => false })) {
                if (Int64(parser.n_containers) < parser.containers.size) {
                    parser.containers[Int64(parser.n_containers)].is_loose = true
                    parser.n_containers += 1
                }
            }
            pos += 16
            continue
        }
        if ((flags & BLOCK_CONTAINER_CLOSER) != 0) {
            if ((match(block_type) { case BlockType.ul => true case BlockType.ol => true case BlockType.`quote` => true case _ => false })) {
                if (parser.n_containers > 0) {
                    parser.n_containers -= 1
                }
            }
            leaveBlock(parser, block_type, data)
            pos += 16
            continue
        }

        // 跳过完全被引用定义消耗的段落块
        if ((flags & BLOCK_REF_DEF_ONLY) != 0) {
            pos += 16
            continue
        }

        // 确定是否在紧凑列表中
        let is_in_tight_list = parser.n_containers > 0 &&
            !parser.containers[Int64(parser.n_containers - 1)].is_loose

        // 处理叶块
        if (!is_in_tight_list || !(match(block_type) { case BlockType.p => true case _ => false })) {
            enterBlock(parser, block_type, data, flags)
        }
        if (!is_in_tight_list || !(match(block_type) { case BlockType.p => true case _ => false })) {
            leaveBlock(parser, block_type, data)
        }
        pos += 16
    }
}

// enterBlock and leaveBlock are defined in render_blocks.cj
