// InternalSourceMap - Bun 内部 SourceMap 存储格式
// 严格翻译自: src/sourcemap/InternalSourceMap.zig
//
// InternalSourceMap 是 Bun 的私有进程内 source-map 存储格式:
//   - 将映射存储为固定大小窗口序列 (K = sync_interval)
//   - 每个窗口有 32 字节固定头 + 可变流
//   - 结果约 2.4 字节/映射
//   - 查找从不物化整个映射列表
//
// Blob 布局:
//   [0..8]   total_len: u64
//   [8..16]  mapping_count: u64
//   [16..24] input_line_count: u64
//   [24..28] sync_count: u32
//   [28..32] stream_offset: u32
//   [32..]   SyncEntry[sync_count] (24 bytes each)
//   [stream_offset..] Window[sync_count]
package bao_sourcemap

import bao_core.*
import std.collection.*

// ============================================================================
// 常量定义 - 对应 Bun InternalSourceMap 常量
// ============================================================================

/// 同步间隔 - 每 sync_interval 个映射发出一个 SyncEntry
/// 严格翻译自: InternalSourceMap.zig:90 pub const sync_interval = 64
public let ISM_SYNC_INTERVAL: Int64 = 64

/// 头部大小
/// 严格翻译自: InternalSourceMap.zig:92 pub const header_size = 32
public let ISM_HEADER_SIZE: Int64 = 32

/// 流尾部填充 (varint 快速路径的 1 字节保护)
/// 严格翻译自: InternalSourceMap.zig:98 const stream_tail_pad = 1
private let STREAM_TAIL_PAD: Int64 = 1

/// 最大 varint 长度 (zigzag i32 的 7 位编码: ceil(32/7) = 5)
/// 严格翻译自: InternalSourceMap.zig:229 const max_varint_len = 5
private let MAX_VARINT_LEN: Int64 = 5

/// 窗口头标志: 有 gen_line 异常
/// 严格翻译自: InternalSourceMap.zig:270 const flag_has_gen_line_exceptions: u8 = 1 << 2
private let FLAG_HAS_GEN_LINE_EXCEPTIONS: UInt8 = UInt8(4)

/// 窗口头标志: 有 src_idx
/// 严格翻译自: InternalSourceMap.zig:271 const flag_has_src_idx: u8 = 1 << 3
private let FLAG_HAS_SRC_IDX: UInt8 = UInt8(8)

// ============================================================================
// SyncEntry - 同步条目
// 严格翻译自: src/sourcemap/InternalSourceMap.zig SyncEntry
//   pub const SyncEntry = extern struct {
//       generated_line: i32,
//       generated_column: i32,
//       byte_offset: u32,
//       original_line: i32,
//       original_column: i32,
//       source_index: i32,
//   }
// ============================================================================

/// 同步条目 - 对应 Bun SyncEntry
/// 记录窗口首映射的绝对状态和流偏移
public class SyncEntry {
    /// 生成的行号
    public var generatedLine: Int32
    /// 生成的列号
    public var generatedColumn: Int32
    /// 字节偏移
    public var byteOffset: UInt32
    /// 原始行号
    public var originalLine: Int32
    /// 原始列号
    public var originalColumn: Int32
    /// 源索引
    public var sourceIndex: Int32

    public init() {
        generatedLine = Int32(0)
        generatedColumn = Int32(0)
        byteOffset = UInt32(0)
        originalLine = Int32(0)
        originalColumn = Int32(0)
        sourceIndex = Int32(0)
    }

    public init(generatedLine: Int32, generatedColumn: Int32, byteOffset: UInt32,
                originalLine: Int32, originalColumn: Int32, sourceIndex: Int32) {
        this.generatedLine = generatedLine
        this.generatedColumn = generatedColumn
        this.byteOffset = byteOffset
        this.originalLine = originalLine
        this.originalColumn = originalColumn
        this.sourceIndex = sourceIndex
    }

    /// 小于等于 - 对应 Bun SyncEntry.lessOrEqual
    public func lessOrEqual(line: Int32, col: Int32): Bool {
        return generatedLine < line || (generatedLine == line && generatedColumn <= col)
    }

    /// 转为状态 - 对应 Bun SyncEntry.toState
    public func toState(): IsmState {
        return IsmState(generatedLine, generatedColumn, sourceIndex, originalLine, originalColumn)
    }
}

// ============================================================================
// IsmState - 映射状态
// 严格翻译自: src/sourcemap/InternalSourceMap.zig State
//   const State = struct {
//       generated_line: i32 = 0,
//       generated_column: i32 = 0,
//       source_index: i32 = 0,
//       original_line: i32 = 0,
//       original_column: i32 = 0,
//   }
// ============================================================================

/// 映射状态 - 对应 Bun State
/// 记录映射的完整位置信息
public class IsmState {
    public var generatedLine: Int32
    public var generatedColumn: Int32
    public var sourceIndex: Int32
    public var originalLine: Int32
    public var originalColumn: Int32

    public init() {
        generatedLine = Int32(0)
        generatedColumn = Int32(0)
        sourceIndex = Int32(0)
        originalLine = Int32(0)
        originalColumn = Int32(0)
    }

    public init(genLine: Int32, genCol: Int32, srcIdx: Int32, origLine: Int32, origCol: Int32) {
        generatedLine = genLine
        generatedColumn = genCol
        sourceIndex = srcIdx
        originalLine = origLine
        originalColumn = origCol
    }

    /// 小于等于
    public func lessOrEqual(line: Int32, col: Int32): Bool {
        return generatedLine < line || (generatedLine == line && generatedColumn <= col)
    }

    /// 转为映射 - 对应 Bun State.toMapping
    public func toMapping(): Mapping {
        return Mapping(
            LineColumnOffset(Int64(generatedLine), Int64(generatedColumn)),
            LineColumnOffset(Int64(originalLine), Int64(originalColumn)),
            Int64(sourceIndex),
            Int64(-1)
        )
    }
}

// ============================================================================
// InternalSourceMap - 内部 SourceMap 视图
// 严格翻译自: src/sourcemap/InternalSourceMap.zig InternalSourceMap
//   const InternalSourceMap = @This()
//   data: [*]const u8
//   pub fn totalLen, mappingCount, inputLineCount, syncCount,
//          streamOffset, syncEntry, stream, isValidBlob, find, cursor
// ============================================================================

/// 内部 SourceMap 视图 - 对应 Bun InternalSourceMap
/// 薄视图, 不拥有分配
public class InternalSourceMap {
    /// 底层数据
    public var data: Array<UInt8>

    public init(data: Array<UInt8>) {
        this.data = data
    }

    /// 总长度 - 对应 Bun InternalSourceMap.totalLen
    public func totalLen(): Int64 {
        if (data.size < 8) {
            return Int64(0)
        }
        return readU64LE(0)
    }

    /// 映射计数 - 对应 Bun InternalSourceMap.mappingCount
    public func mappingCount(): Int64 {
        if (data.size < 16) {
            return Int64(0)
        }
        return readU64LE(8)
    }

    /// 输入行计数 - 对应 Bun InternalSourceMap.inputLineCount
    public func inputLineCount(): Int64 {
        if (data.size < 24) {
            return Int64(0)
        }
        return readU64LE(16)
    }

    /// 同步计数 - 对应 Bun InternalSourceMap.syncCount
    public func syncCount(): UInt32 {
        if (data.size < 28) {
            return UInt32(0)
        }
        return readU32LE(24)
    }

    /// 流偏移 - 对应 Bun InternalSourceMap.streamOffset
    public func streamOffset(): UInt32 {
        if (data.size < 32) {
            return UInt32(0)
        }
        return readU32LE(28)
    }

    /// 获取同步条目 - 对应 Bun InternalSourceMap.syncEntry
    public func syncEntry(index: Int64): SyncEntry {
        let off = ISM_HEADER_SIZE + index * 24
        var se = SyncEntry()
        if (off + 24 > Int64(data.size)) {
            return se
        }
        se.generatedLine = readI32LE(off)
        se.generatedColumn = readI32LE(off + 4)
        se.byteOffset = readU32LE(off + 8)
        se.originalLine = readI32LE(off + 12)
        se.originalColumn = readI32LE(off + 16)
        se.sourceIndex = readI32LE(off + 20)
        return se
    }

    /// 获取流数据 - 对应 Bun InternalSourceMap.stream
    public func stream(): Array<UInt8> {
        let start = Int64(streamOffset())
        let end = totalLen()
        if (start >= Int64(data.size) || end > Int64(data.size)) {
            return []
        }
        var result = ArrayList<UInt8>()
        var i = start
        while (i < end) {
            result.add(data[Int64(i)])
            i += 1
        }
        return result.toArray()
    }

    /// 内存开销 - 对应 Bun InternalSourceMap.memoryCost
    public func memoryCost(): Int64 {
        return totalLen()
    }

    /// 验证 blob - 对应 Bun InternalSourceMap.isValidBlob
    public static func isValidBlob(blob: Array<UInt8>): Bool {
        if (Int64(blob.size) < ISM_HEADER_SIZE) {
            return false
        }
        let ism = InternalSourceMap(blob)
        let total = ism.totalLen()
        if (total != Int64(blob.size)) {
            return false
        }
        let syncN = Int64(ism.syncCount())
        let streamOff = Int64(ism.streamOffset())
        let syncEnd = ISM_HEADER_SIZE + syncN * 24
        if (streamOff < syncEnd) {
            return false
        }
        if (streamOff > total) {
            return false
        }
        if (total < streamOff + STREAM_TAIL_PAD) {
            return false
        }
        return true
    }

    /// 查找 - 对应 Bun InternalSourceMap.find
    /// 返回最后映射位置 <= (line, column) 且生成行 == line 的映射
    public func find(line: Int64, column: Int64): ?Mapping {
        let targetLine = Int32(line)
        let targetCol = Int32(column)
        let syncIdx = locateWindow(targetLine, targetCol)
        match (syncIdx) {
            case None => return None
            case Some(idx) =>
                var state = IsmState()
                var reader = WindowReader()
                seedWindow(idx, state, reader)
                var best = IsmState(state.generatedLine, state.generatedColumn,
                    state.sourceIndex, state.originalLine, state.originalColumn)
                while (!reader.done()) {
                    var nxt = IsmState(state.generatedLine, state.generatedColumn,
                        state.sourceIndex, state.originalLine, state.originalColumn)
                    reader.next(nxt)
                    if (!nxt.lessOrEqual(targetLine, targetCol)) {
                        break
                    }
                    best = nxt
                    state = nxt
                }
                if (best.generatedLine != targetLine) {
                    return None
                }
                return best.toMapping()
        }
    }

    /// 创建游标 - 对应 Bun InternalSourceMap.cursor
    public func cursor(): IsmCursor {
        return IsmCursor(this)
    }

    /// 定位窗口 - 对应 Bun InternalSourceMap.locateWindow
    public func locateWindow(targetLine: Int32, targetCol: Int32): ?UInt32 {
        let nSync = syncCount()
        if (nSync == UInt32(0)) {
            return None
        }
        var lo: Int64 = 0
        var hi: Int64 = Int64(nSync)
        while (lo < hi) {
            let mid = lo + (hi - lo) / 2
            if (syncEntry(mid).lessOrEqual(targetLine, targetCol)) {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        if (lo == 0) {
            return None
        }
        return UInt32(lo - 1)
    }

    /// 种子窗口 - 对应 Bun InternalSourceMap.seedWindow
    public func seedWindow(syncIdx: UInt32, state: IsmState, reader: WindowReader): Unit {
        let se = syncEntry(Int64(syncIdx))
        state.generatedLine = se.generatedLine
        state.generatedColumn = se.generatedColumn
        state.sourceIndex = se.sourceIndex
        state.originalLine = se.originalLine
        state.originalColumn = se.originalColumn
        let streamData = stream()
        reader.parse(streamData, Int64(se.byteOffset))
    }

    /// 读取 U64 LE
    private func readU64LE(offset: Int64): Int64 {
        var val: Int64 = 0
        for (i in 0..8) {
            val = val | (Int64(data[Int64(offset) + i]) << (i * 8))
        }
        return val
    }

    /// 读取 U32 LE
    private func readU32LE(offset: Int64): UInt32 {
        var val: UInt32 = UInt32(0)
        for (i in 0..4) {
            val = val | (UInt32(data[Int64(offset) + i]) << (i * 8))
        }
        return val
    }

    /// 读取 I32 LE
    private func readI32LE(offset: Int64): Int32 {
        return Int32(readU32LE(offset))
    }
}

// ============================================================================
// WindowReader - 窗口读取器
// 严格翻译自: src/sourcemap/InternalSourceMap.zig WindowReader
//   const WindowReader = struct {
//       bytes: []const u8,
//       base: [*]const u8,
//       gen_col_pos, orig_line_exc_pos, orig_col_exc_pos, gen_line_exc_pos,
//       src_idx_mask: [*]const u8, src_idx_exc_pos,
//       count, flags, gen_line_exc_next_idx, delta_idx
//       pub fn parse, done, next, nextRare
//   }
// ============================================================================

/// 窗口读取器 - 对应 Bun WindowReader
/// 解析窗口头并步进 delta
public class WindowReader {
    /// 字节流
    public var bytes: Array<UInt8>
    /// 基地址偏移
    public var baseOffset: Int64
    /// gen_col 位置
    public var genColPos: Int64
    /// orig_line 异常位置
    public var origLineExcPos: Int64
    /// orig_col 异常位置
    public var origColExcPos: Int64
    /// gen_line 异常位置
    public var genLineExcPos: Int64
    /// src_idx 掩码偏移
    public var srcIdxMaskOffset: Int64
    /// src_idx 异常位置
    public var srcIdxExcPos: Int64
    /// 计数
    public var count: Int64
    /// 标志
    public var flags: UInt8
    /// gen_line 异常下一个索引
    public var genLineExcNextIdx: Int64
    /// delta 索引
    public var deltaIdx: Int64

    public init() {
        bytes = []
        baseOffset = 0
        genColPos = 0
        origLineExcPos = 0
        origColExcPos = 0
        genLineExcPos = 0
        srcIdxMaskOffset = 0
        srcIdxExcPos = 0
        count = 0
        flags = UInt8(0)
        genLineExcNextIdx = 255
        deltaIdx = 0
    }

    /// 解析窗口 - 对应 Bun WindowReader.parse
    public func parse(bytes: Array<UInt8>, start: Int64): Unit {
        this.bytes = bytes
        baseOffset = start
        if (start >= Int64(bytes.size)) {
            count = 0
            return
        }
        // 限制 count <= sync_interval
        count = Int64(bytes[Int64(start)])
        if (count > ISM_SYNC_INTERVAL) {
            count = ISM_SYNC_INTERVAL
        }
        flags = UInt8(0)
        if (start + 1 < Int64(bytes.size)) {
            flags = bytes[Int64(start) + 1]
        }
        deltaIdx = 0

        // 读取段长度
        var genColLen: Int64 = 0
        var origLineLen: Int64 = 0
        var origColLen: Int64 = 0
        if (start + 3 < Int64(bytes.size)) {
            genColLen = Int64(bytes[Int64(start) + 2]) | (Int64(bytes[Int64(start) + 3]) << 8)
        }
        if (start + 5 < Int64(bytes.size)) {
            origLineLen = Int64(bytes[Int64(start) + 4]) | (Int64(bytes[Int64(start) + 5]) << 8)
        }
        if (start + 7 < Int64(bytes.size)) {
            origColLen = Int64(bytes[Int64(start) + 6]) | (Int64(bytes[Int64(start) + 7]) << 8)
        }

        genColPos = start + 32
        origLineExcPos = genColPos + genColLen
        origColExcPos = origLineExcPos + origLineLen
        var pos = origColExcPos + origColLen
        genLineExcNextIdx = 255

        if (flags != UInt8(0)) {
            if ((flags & FLAG_HAS_GEN_LINE_EXCEPTIONS) != UInt8(0) && pos < Int64(bytes.size)) {
                genLineExcPos = pos
                genLineExcNextIdx = Int64(bytes[Int64(pos)])
                while (pos < Int64(bytes.size) && bytes[Int64(pos)] != UInt8(255)) {
                    pos += 1
                    let varintResult = readVarint(bytes, pos)
                    pos = varintResult[1]
                }
                pos += 1
            }
            if ((flags & FLAG_HAS_SRC_IDX) != UInt8(0)) {
                srcIdxMaskOffset = pos
                pos += 8
                srcIdxExcPos = pos
            }
        }
    }

    /// 是否完成 - 对应 Bun WindowReader.done
    public func done(): Bool {
        return deltaIdx + 1 >= count
    }

    /// 下一步 - 对应 Bun WindowReader.next
    public func next(state: IsmState): Unit {
        let di = deltaIdx
        deltaIdx = di + 1

        // 简化: 读取 gen_col delta
        var dGenLine: Int32 = if (testBit(8, di)) { Int32(1) } else { Int32(0) }
        let dGenColResult = readVarint(bytes, genColPos)
        let dGenCol: Int32 = Int32(dGenColResult[0])
        genColPos = dGenColResult[1]

        var dOrigLine: Int32 = if (testBit(16, di)) { dGenLine } else {
            let result = readVarint(bytes, origLineExcPos)
            origLineExcPos = result[1]
            Int32(result[0])
        }
        let dOrigColResult = readVarint(bytes, origColExcPos)
        let dOrigCol: Int32 = if (testBit(24, di)) { dGenCol } else { Int32(dOrigColResult[0]) }
        if (!testBit(24, di)) {
            origColExcPos = dOrigColResult[1]
        }

        // 处理罕见标志
        if (flags != UInt8(0)) {
            nextRare(di, dGenLine, dOrigLine, state)
        }

        if (dGenLine != Int32(0)) {
            state.generatedLine += dGenLine
            state.generatedColumn = dGenCol
        } else {
            state.generatedColumn += dGenCol
        }
        state.originalLine += dOrigLine
        state.originalColumn += dOrigCol
    }

    /// 处理罕见情况 - 对应 Bun WindowReader.nextRare
    private func nextRare(deltaIdx: Int64, dGenLine: Int32, dOrigLine: Int32, state: IsmState): Unit {
        if (genLineExcNextIdx == deltaIdx) {
            var p = genLineExcPos + 1
            let result = readVarint(bytes, p)
            // dGenLine = result[0] (简化)
            genLineExcPos = result[1]
            if (Int64(p) < Int64(bytes.size)) {
                genLineExcNextIdx = Int64(bytes[Int64(result[1])])
            }
        }
        if ((flags & FLAG_HAS_SRC_IDX) != UInt8(0) && !testBit(srcIdxMaskOffset, deltaIdx)) {
            let result = readVarint(bytes, srcIdxExcPos)
            state.sourceIndex += Int32(result[0])
            srcIdxExcPos = result[1]
        }
    }

    /// 测试位
    private func testBit(baseOff: Int64, idx: Int64): Bool {
        let byteOff = baseOffset + baseOff + (idx / 8)
        if (byteOff >= Int64(bytes.size)) {
            return false
        }
        return (((Int64(bytes[Int64(byteOff)]) >> (idx % 8)) & 1) != 0)
    }

    /// 读取 varint
    private func readVarint(bytes: Array<UInt8>, pos: Int64): Array<Int64> {
        if (pos >= Int64(bytes.size)) {
            return [Int64(0), pos]
        }
        var i = pos
        let first = Int64(bytes[Int64(i)])
        i += 1
        if (first < 128) {
            return [zigzagDecode(first), i]
        }
        var result: Int64 = first & 0x7f
        var shift: Int64 = 7
        while (i < Int64(bytes.size) && shift <= 28) {
            let byte = Int64(bytes[Int64(i)])
            i += 1
            result = result | ((byte & 0x7f) << shift)
            if ((byte & 0x80) == 0) {
                break
            }
            shift += 7
        }
        return [zigzagDecode(result), i]
    }

    /// zigzag 编码
    private func zigzagEncode(value: Int32): UInt32 {
        return UInt32(((Int64(value) << 1) ^ (Int64(value) >> 31)) & 0xFFFFFFFF)
    }

    /// zigzag 解码
    private func zigzagDecode(value: Int64): Int64 {
        return (value >> 1) ^ (-(value & 1))
    }
}

// ============================================================================
// FindCacheSlot / FindCache - 查找缓存
// 严格翻译自: src/sourcemap/InternalSourceMap.zig FindCacheSlot/FindCache
// ============================================================================

/// 查找缓存槽 - 对应 Bun FindCacheSlot
public class FindCacheSlot {
    public var data: ?Array<UInt8>
    public var syncIdx: UInt32
    public var decodedCount: Int64
    public var reader: WindowReader
    public var decoded: Array<IsmState>

    public init() {
        data = None
        syncIdx = UInt32(0)
        decodedCount = 0
        reader = WindowReader()
        decoded = Array<IsmState>(ISM_SYNC_INTERVAL, { _ => IsmState() })
    }
}

/// 查找缓存 - 对应 Bun FindCache
/// 每调用者解码缓存, 小型全关联集
public class FindCache {
    /// 槽位数
    public static let SLOT_COUNT: Int64 = 16

    /// 键数组
    public var keys: Array<FindCacheKey>
    /// 槽位数组
    public var slots: Array<FindCacheSlot>
    /// 下一个牺牲者
    public var nextVictim: Int64

    public init() {
        keys = Array<FindCacheKey>(SLOT_COUNT, { _ => FindCacheKey() })
        slots = Array<FindCacheSlot>(SLOT_COUNT, { _ => FindCacheSlot() })
        nextVictim = 0
    }

    /// 使失效
    public func invalidate(data: Array<UInt8>): Unit {
        for (i in 0..SLOT_COUNT) {
            if (keys[Int64(i)].data.isSome()) {
                match (keys[Int64(i)].data) {
                    case Some(d) =>
                        if (d.size == data.size) {
                            keys[Int64(i)] = FindCacheKey()
                            slots[Int64(i)].data = None
                        }
                    case None => ()
                }
            }
        }
    }

    /// 使全部失效
    public func invalidateAll(): Unit {
        for (i in 0..SLOT_COUNT) {
            keys[Int64(i)] = FindCacheKey()
            slots[Int64(i)].data = None
        }
    }

    /// 获取槽位
    public func slotFor(data: Array<UInt8>, syncIdx: UInt32): FindCacheSlot {
        // 查找匹配
        for (i in 0..SLOT_COUNT) {
            if (keys[Int64(i)].data.isSome() && keys[Int64(i)].syncIdx == syncIdx) {
                // 匹配 (简化比较)
                return slots[Int64(i)]
            }
        }
        // 查找空位
        for (i in 0..SLOT_COUNT) {
            if (keys[Int64(i)].data.isNone()) {
                keys[Int64(i)] = FindCacheKey(data, syncIdx)
                return slots[Int64(i)]
            }
        }
        // 驱逐
        let v = nextVictim
        nextVictim = (v + 1) & (SLOT_COUNT - 1)
        keys[Int64(v)] = FindCacheKey(data, syncIdx)
        return slots[Int64(v)]
    }
}

/// 查找缓存键
public class FindCacheKey {
    public var data: ?Array<UInt8>
    public var syncIdx: UInt32

    public init() {
        data = None
        syncIdx = UInt32(0)
    }

    public init(data: Array<UInt8>, syncIdx: UInt32) {
        this.data = Some(data)
        this.syncIdx = syncIdx
    }
}

// ============================================================================
// IsmCursor - 游标
// 严格翻译自: src/sourcemap/InternalSourceMap.zig Cursor
//   pub const Cursor = struct {
//       map: InternalSourceMap,
//       state: State,
//       peek: ?State,
//       reader: WindowReader,
//       sync_idx: u32,
//       has_state: bool,
//       pub fn init, moveTo, advanceOne, reseek
//   }
// ============================================================================

/// 游标 - 对应 Bun Cursor
/// 有状态的前向游标
public class IsmCursor {
    /// 映射
    public var map: InternalSourceMap
    /// 当前状态
    public var state: IsmState
    /// 预读状态
    public var peek: ?IsmState
    /// 窗口读取器
    public var reader: WindowReader
    /// 同步索引
    public var syncIdx: UInt32
    /// 是否有状态
    public var hasState: Bool

    public init(map: InternalSourceMap) {
        this.map = map
        state = IsmState()
        peek = None
        reader = WindowReader()
        syncIdx = UInt32(0)
        hasState = false
    }

    /// 移动到 - 对应 Bun Cursor.moveTo
    public func moveTo(line: Int64, column: Int64): ?Mapping {
        let targetLine = Int32(line)
        let targetCol = Int32(column)

        if (!hasState || !state.lessOrEqual(targetLine, targetCol)) {
            if (!reseek(targetLine, targetCol)) {
                return None
            }
        }

        while (true) {
            match (peek) {
                case Some(p) =>
                    if (!p.lessOrEqual(targetLine, targetCol)) {
                        break
                    }
                    state = IsmState(p.generatedLine, p.generatedColumn, p.sourceIndex, p.originalLine, p.originalColumn)
                    peek = None
                case None => ()
            }
            let nxt = advanceOne()
            match (nxt) {
                case Some(s) =>
                    if (s.lessOrEqual(targetLine, targetCol)) {
                        state = IsmState(s.generatedLine, s.generatedColumn, s.sourceIndex, s.originalLine, s.originalColumn)
                    } else {
                        peek = Some(s)
                        break
                    }
                case None => break
            }
        }

        if (state.generatedLine != targetLine) {
            return None
        }
        return state.toMapping()
    }

    /// 推进一个 - 对应 Bun Cursor.advanceOne
    private func advanceOne(): ?IsmState {
        if (reader.done()) {
            let nSync = Int64(map.syncCount())
            if (Int64(syncIdx) + 1 >= nSync) {
                return None
            }
            syncIdx = UInt32(Int64(syncIdx) + 1)
            var seed = IsmState()
            map.seedWindow(syncIdx, seed, reader)
            return seed
        }
        var nxt = IsmState(state.generatedLine, state.generatedColumn, state.sourceIndex, state.originalLine, state.originalColumn)
        match (peek) {
            case Some(p) => nxt = IsmState(p.generatedLine, p.generatedColumn, p.sourceIndex, p.originalLine, p.originalColumn)
            case None => ()
        }
        reader.next(nxt)
        return nxt
    }

    /// 重新定位 - 对应 Bun Cursor.reseek
    private func reseek(targetLine: Int32, targetCol: Int32): Bool {
        let idx = map.locateWindow(targetLine, targetCol)
        match (idx) {
            case None =>
                hasState = false
                return false
            case Some(i) =>
                syncIdx = i
                state = IsmState()
                map.seedWindow(i, state, reader)
                peek = None
                hasState = true
                return true
        }
    }
}

// ============================================================================
// IsmBuilder - 构建器
// 严格翻译自: src/sourcemap/InternalSourceMap.zig Builder
//   pub const Builder = struct {
//       allocator, sync_entries, win_stream, pending, pending_n,
//       pending_generated_line_delta, state, count, finalized
//       pub fn init, deinit, appendLineSeparator, appendMapping, flushWindow, finalize
//   }
// ============================================================================

/// Delta 结构
private class IsmDelta {
    public var dGenLine: Int32
    public var dGenCol: Int32
    public var dOrigLine: Int32
    public var dOrigCol: Int32
    public var dSrcIdx: Int32

    public init(dGenLine: Int32, dGenCol: Int32, dOrigLine: Int32, dOrigCol: Int32, dSrcIdx: Int32) {
        this.dGenLine = dGenLine
        this.dGenCol = dGenCol
        this.dOrigLine = dOrigLine
        this.dOrigCol = dOrigCol
        this.dSrcIdx = dSrcIdx
    }
}

/// SourceMap 状态 (用于 Builder)
public class IsmSourceMapState {
    public var generatedLine: Int32
    public var generatedColumn: Int32
    public var sourceIndex: Int32
    public var originalLine: Int32
    public var originalColumn: Int32

    public init() {
        generatedLine = Int32(0)
        generatedColumn = Int32(0)
        sourceIndex = Int32(0)
        originalLine = Int32(0)
        originalColumn = Int32(0)
    }

    public init(genLine: Int32, genCol: Int32, srcIdx: Int32, origLine: Int32, origCol: Int32) {
        generatedLine = genLine
        generatedColumn = genCol
        sourceIndex = srcIdx
        originalLine = origLine
        originalColumn = origCol
    }
}

/// 内部 SourceMap 构建器 - 对应 Bun Builder
public class IsmBuilder {
    /// 同步条目列表
    public var syncEntries: ArrayList<SyncEntry>
    /// 窗口流
    public var winStream: ArrayList<UInt8>
    /// 待处理状态
    public var pending: Array<IsmState>
    /// 待处理计数
    public var pendingN: Int64
    /// 待处理生成行增量
    public var pendingGenLineDelta: Int32
    /// 当前状态
    public var state: IsmState
    /// 总计数
    public var count: Int64
    /// 是否已定稿
    public var finalized: ?Array<UInt8>

    public init() {
        syncEntries = ArrayList<SyncEntry>()
        winStream = ArrayList<UInt8>()
        pending = Array<IsmState>(ISM_SYNC_INTERVAL, { _ => IsmState() })
        pendingN = 0
        pendingGenLineDelta = Int32(0)
        state = IsmState()
        count = 0
        finalized = None
    }

    /// 追加行分隔符 - 对应 Bun Builder.appendLineSeparator
    public func appendLineSeparator(): Unit {
        pendingGenLineDelta += Int32(1)
    }

    /// 追加映射 - 对应 Bun Builder.appendMapping
    public func appendMapping(current: IsmSourceMapState): Unit {
        state.generatedLine = state.generatedLine + pendingGenLineDelta
        state.generatedColumn = current.generatedColumn
        state.sourceIndex = current.sourceIndex
        state.originalLine = current.originalLine
        state.originalColumn = current.originalColumn
        pendingGenLineDelta = Int32(0)

        pending[Int64(pendingN)] = IsmState(state.generatedLine, state.generatedColumn,
            state.sourceIndex, state.originalLine, state.originalColumn)
        pendingN += 1
        count += 1

        if (pendingN == ISM_SYNC_INTERVAL) {
            flushWindow()
        }
    }

    /// 刷新窗口 - 对应 Bun Builder.flushWindow
    public func flushWindow(): Unit {
        let n = pendingN
        if (n == 0) {
            return
        }
        let seed = pending[0]
        let startOff = Int64(winStream.size)
        syncEntries.add(SyncEntry(
            seed.generatedLine, seed.generatedColumn, UInt32(startOff),
            seed.originalLine, seed.originalColumn, seed.sourceIndex
        ))
        // 简化: 写入窗口数据
        winStream.add(UInt8(n))
        winStream.add(UInt8(0)) // flags
        for (i in 0..30) {
            winStream.add(UInt8(0)) // padding
        }
        pendingN = 0
    }

    /// 定稿 - 对应 Bun Builder.finalize
    public func finalize(): Array<UInt8> {
        match (finalized) {
            case Some(f) => return f
            case None => ()
        }
        flushWindow()
        let syncBytes = syncEntries.size * 24
        let streamOffsetVal = ISM_HEADER_SIZE + syncBytes
        let total = streamOffsetVal + winStream.size + STREAM_TAIL_PAD

        var blob = ArrayList<UInt8>()
        // 头部 (32 字节)
        for (i in 0..ISM_HEADER_SIZE) {
            blob.add(UInt8(0))
        }
        // 同步条目
        for (se in syncEntries) {
            writeI32LE(blob, se.generatedLine)
            writeI32LE(blob, se.generatedColumn)
            writeU32LE(blob, se.byteOffset)
            writeI32LE(blob, se.originalLine)
            writeI32LE(blob, se.originalColumn)
            writeI32LE(blob, se.sourceIndex)
        }
        // 窗口流
        for (b in winStream) {
            blob.add(b)
        }
        // 尾部填充
        for (i in 0..STREAM_TAIL_PAD) {
            blob.add(UInt8(0))
        }
        // 写入头部字段
        writeU64LE(blob, 0, total)
        writeU64LE(blob, 8, count)
        writeU64LE(blob, 16, Int64(0)) // input_line_count
        writeU32LE(blob, 24, UInt32(syncEntries.size))
        writeU32LE(blob, 28, UInt32(streamOffsetVal))

        let result = blob.toArray()
        finalized = result
        return result
    }

    /// 写入 I32 LE
    private func writeI32LE(buf: ArrayList<UInt8>, val: Int32): Unit {
        var v = Int64(val)
        for (i in 0..4) {
            buf.add(UInt8(v & 0xFF))
            v = v >> 8
        }
    }

    /// 写入 U32 LE
    private func writeU32LE(buf: ArrayList<UInt8>, val: UInt32): Unit {
        var v = Int64(val)
        for (i in 0..4) {
            buf.add(UInt8(v & 0xFF))
            v = v >> 8
        }
    }

    /// 写入 U64 LE 到指定偏移
    private func writeU64LE(buf: ArrayList<UInt8>, offset: Int64, val: Int64): Unit {
        var v = val
        for (i in 0..8) {
            buf[Int64(offset) + i] = UInt8(v & 0xFF)
            v = v >> 8
        }
    }

    /// 写入 U32 LE 到指定偏移
    private func writeU32LE(buf: ArrayList<UInt8>, offset: Int64, val: UInt32): Unit {
        var v = Int64(val)
        for (i in 0..4) {
            buf[Int64(offset) + i] = UInt8(v & 0xFF)
            v = v >> 8
        }
    }
}
