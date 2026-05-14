// bao_sourcemap - Source Map 解析与生成
// 严格翻译自: src/sourcemap/
//   - sourcemap.zig: SourceMap, LineColumnOffset, SourceMapState, SourceMapPieces
//   - VLQ.zig: VLQ 编码/解码 (Variable-Length Quantity)
//   - Mapping.zig: Mapping, Mapping.List, parse
//   - ParsedSourceMap.zig: ParsedSourceMap
//   - Chunk.zig: Chunk
//   - LineOffsetTable.zig: LineOffsetTable
package bao_sourcemap

import bao_core.*
import bao_collections.*

// ============================================================================
// VLQ - Variable-Length Quantity 编解码
// 严格翻译自: src/sourcemap/VLQ.zig
//   const VLQ = @This();
//   bytes: [vlq_max_in_bytes]u8,
//   len: u8 = 0,
//   pub fn encode(value: i32) VLQ { ... }
//   pub fn decode(encoded: []const u8, start: usize) VLQResult { ... }
//
// VLQ 编码原理 (用于 Source Map 的 "mappings" 字段):
//   - 将整数编码为可变长度的 Base64 字符序列
//   - 每个 Base64 字符包含 6 位数据
//     - bit 5 (0x20): 继续位 (1 = 还有更多字符)
//     - bit 0: 符号位 (1 = 负数)
//     - bit 1-4: 数值
//   - 编码范围: i32, 最多 7 个字节
//
//   示例:
//     0 -> "A"    (6位: 符号0, 值0000, 继续0 = 000000 = 'A')
//     1 -> "C"    (6位: 符号0, 值0001, 继续0 = 000001 = 'C')
//     -1 -> "D"   (6位: 符号1, 值0000, 继续0 = 000001 = 'D')
//     16 -> "gB"  (第一字节: 符号0, 值0000, 继续1 = 100000 = 'g')
//                    (第二字节: 符号0, 值0001, 继续0 = 000001 = 'B')
// ============================================================================

/// Base64 字母表 - 对应 Bun VLQ.base64
private let VLQ_BASE64: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

/// Base64 查找表 - 对应 Bun VLQ.base64_lut
private let VLQ_BASE64_LUT: Array<UInt8> = {
    var lut = Array<UInt8>(128, item: 0xFF.toUInt8())
    for (i in 0..64) {
        lut[VLQ_BASE64[i].toUInt8()] = UInt8(i)
    }
    lut
}()

/// VLQ 最大编码字节数 - 对应 Bun VLQ.vlq_max_in_bytes = 7
private let VLQ_MAX_BYTES: Int64 = 7

/// VLQ 编码结果 - 对应 Bun VLQ struct
public class VLQEncoded {
    public var bytes: Array<UInt8>
    public var len: Int64

    public init() {
        bytes = Array<UInt8>(VLQ_MAX_BYTES, item: 0)
        len = 0
    }

    public func slice(): Array<UInt8> {
        bytes.subArray(0, len)
    }
}

/// VLQ 解码结果 - 对应 Bun VLQ.VLQResult
//   pub const VLQResult = struct {
//       value: i32 = 0,
//       start: usize = 0,
//   }
public class VLQResult {
    /// 解码后的值
    public var value: Int64
    /// 解码后的新位置
    public var start: Int64

    public init(value: Int64, start: Int64) {
        this.value = value
        this.start = start
    }
}

/// VLQ 编解码工具类
public class VLQ {
    // ========================================================================
    // encode - VLQ 编码
    // 严格翻译自: VLQ.encodeSlowPath
    //   fn encodeSlowPath(value: i32) VLQ {
    //       var vlq: u32 = if (value >= 0)
    //           @as(u32, @bitCast(value << 1))
    //       else
    //           @as(u32, @bitCast((-value << 1) | 1));
    //       inline for (0..vlq_max_in_bytes) |_| {
    //           var digit = vlq & 31;
    //           vlq >>= 5;
    //           if (vlq != 0) { digit |= 32; }
    //           bytes[len] = base64[digit];
    //           len += 1;
    //           if (vlq == 0) return;
    //       }
    //   }
    //
    // 编码步骤:
    //   1. 将带符号整数转为无符号 VLQ 值:
    //      - 正数: value << 1
    //      - 负数: (-value << 1) | 1
    //   2. 每 5 位一组编码为一个 Base64 字符:
    //      - 低 5 位为数据 (bit 0-4)
    //      - bit 5 为继续位
    //   3. 直到所有位编码完毕
    // ========================================================================

    /// 编码整数为 VLQ Base64 字符串
    public static func encode(value: Int64): String {
        // 特殊情况: 0 直接查表
        // Bun: if (value >= 0 and value <= 255) vlq_lookup_table[value]
        if (value >= 0 && value <= 255) {
            return vlqEncodeSmall(value)
        }

        // 将带符号值转为无符号 VLQ 值
        var vlq = if (value >= 0) {
            value << 1
        } else {
            ((-value) << 1) | 1
        }

        var result = StringBuilder()

        // 每 5 位编码一个字符
        var count = 0
        while (count < VLQ_MAX_BYTES) {
            var digit = vlq & 31  // 取低 5 位
            vlq = vlq >> 5

            // 如果还有更多位，设置继续位 (bit 5)
            if (vlq != 0) {
                digit = digit | 32
            }

            result.append(VLQ_BASE64[digit])
            count += 1

            if (vlq == 0) {
                break
            }
        }

        return result.toString()
    }

    /// 编码小数值 (0-255) 使用查表优化
    /// 对应 Bun vlq_lookup_table
    private static func vlqEncodeSmall(value: Int64): String {
        // 直接计算，等价于查表
        var vlq = value << 1
        var digit = vlq & 31
        vlq = vlq >> 5
        if (vlq != 0) {
            digit = digit | 32
        }
        var result = StringBuilder()
        result.append(VLQ_BASE64[digit])

        while (vlq != 0) {
            digit = vlq & 31
            vlq = vlq >> 5
            if (vlq != 0) {
                digit = digit | 32
            }
            result.append(VLQ_BASE64[digit])
        }

        return result.toString()
    }

    // ========================================================================
    // decode - VLQ 解码
    // 严格翻译自: VLQ.decode
    //   pub fn decode(encoded: []const u8, start: usize) VLQResult {
    //       var shift: u8 = 0;
    //       var vlq: u32 = 0;
    //       inline for (0..vlq_max_in_bytes + 1) |i| {
    //           const index = @as(u32, base64_lut[encoded_[i]]);
    //           vlq |= (index & 31) << @as(u5, @truncate(shift));
    //           shift += 5;
    //           if ((index & 32) == 0) {
    //               // 无继续位 -> 解码完成
    //               return VLQResult{
    //                   .start = start + i + 1,
    //                   .value = if ((vlq & 1) == 0) vlq >> 1
    //                            else -@as(i32, @intCast(vlq >> 1)),
    //               };
    //           }
    //       }
    //   }
    //
    // 解码步骤:
    //   1. 逐个读取 Base64 字符
    //   2. 查找字符索引 (6 位值)
    //   3. 低 5 位为数据，按位移累加到 vlq
    //   4. bit 5 为继续位: 1 = 继续读取, 0 = 结束
    //   5. 从 vlq 恢复带符号值:
    //      - 最低位为 0: vlq >> 1 (正数)
    //      - 最低位为 1: -(vlq >> 1) (负数)
    // ========================================================================

    /// 解码 VLQ Base64 字符串
    /// 从指定位置开始解码一个 VLQ 值，返回值和新位置
    public static func decode(encoded: String, start: Int64): VLQResult {
        var shift = 0
        var vlq = 0
        var i = start
        let len = encoded.size

        while (i < len && (i - start) < VLQ_MAX_BYTES + 1) {
            let ch = encoded[i]
            // 查找字符索引
            if (ch.toUInt8() >= 128) {
                return VLQResult(0, i)
            }
            let idx = VLQ_BASE64_LUT[ch.toUInt8()]
            if (idx == 0xFF.toUInt8()) {
                return VLQResult(0, i)
            }

            // 累加数据位
            vlq = vlq | ((Int64(idx) & 31) << shift)
            shift += 5
            i += 1

            // 检查继续位 (bit 5)
            if ((Int64(idx) & 32) == 0) {
                // 无继续位 -> 解码完成
                // 恢复带符号值
                let value = if ((vlq & 1) == 0) {
                    vlq >> 1
                } else {
                    -(vlq >> 1)
                }
                return VLQResult(value, i)
            }
        }

        return VLQResult(0, i)
    }

    /// 编码多个值为 VLQ 字符串 (用于 source map mappings)
    /// 多个值按顺序编码，无分隔符
    public static func vlqEncode(values: Array<Int64>): String {
        var sb = StringBuilder()
        for (i in 0..values.size) {
            sb.append(encode(values[i]))
        }
        return sb.toString()
    }

    /// 从 VLQ 字符串解码多个值
    /// 返回所有解码值和最终位置
    public static func vlqDecode(str: String): Array<Int64> {
        let result = ArrayList<Int64>()
        var pos = 0
        while (pos < str.size) {
            let r = decode(str, pos)
            if (r.start == pos) {
                break  // 无法继续解码
            }
            result.append(r.value)
            pos = r.start
        }
        return result.toArray()
    }
}

// ============================================================================
// LineColumnOffset - 行列偏移
// 严格翻译自: src/sourcemap/sourcemap.zig - LineColumnOffset
//   pub const LineColumnOffset = struct {
//       lines: bun.Ordinal = bun.Ordinal.start,
//       columns: bun.Ordinal = bun.Ordinal.start,
//       pub fn add, advance, comesBefore, cmp
//   }
// ============================================================================

/// 行列偏移 - 对应 Bun SourceMap.LineColumnOffset
/// 坐标从零开始计数
public class LineColumnOffset {
    /// 零起始行号
    public var line: Int64
    /// 零起始列号
    public var column: Int64

    public init() {
        line = 0
        column = 0
    }

    public init(line: Int64, column: Int64) {
        this.line = line
        this.column = column
    }

    /// 相加 - 对应 Bun LineColumnOffset.add
    public func add(other: LineColumnOffset): Unit {
        if (other.line == 0) {
            column += other.column
        } else {
            line += other.line
            column = other.column
        }
    }

    /// 比较先后 - 对应 Bun LineColumnOffset.comesBefore
    public func comesBefore(other: LineColumnOffset): Bool {
        line < other.line || (line == other.line && column < other.column)
    }

    /// 比较 - 对应 Bun LineColumnOffset.cmp
    public func compare(other: LineColumnOffset): Int64 {
        if (line != other.line) {
            return line - other.line
        }
        return column - other.column
    }
}

// ============================================================================
// SourceMapping - 映射条目
// 严格翻译自: src/sourcemap/Mapping.zig - Mapping
//   const Mapping = @This();
//   generated: LineColumnOffset,
//   original: LineColumnOffset,
//   source_index: i32,
//   name_index: i32 = -1,
//   pub fn generatedLine, generatedColumn, sourceIndex,
//          originalLine, originalColumn, nameIndex, parse
// ============================================================================

/// 源映射条目 - 对应 Bun Mapping
/// 表示 generated 位置到 original 位置的映射关系
public class SourceMapping {
    /// 生成代码中的位置
    public var generated: LineColumnOffset
    /// 原始代码中的位置
    public var original: LineColumnOffset
    /// 源文件索引
    public var sourceIndex: Int64
    /// 名称索引 (-1 表示无名称)
    public var nameIndex: Int64

    public init() {
        generated = LineColumnOffset()
        original = LineColumnOffset()
        sourceIndex = 0
        nameIndex = -1
    }

    public init(genLine: Int64, genCol: Int64, srcIdx: Int64,
                origLine: Int64, origCol: Int64, nameIdx: Int64) {
        generated = LineColumnOffset(genLine, genCol)
        original = LineColumnOffset(origLine, origCol)
        sourceIndex = srcIdx
        nameIndex = nameIdx
    }

    /// 生成代码行号 - 对应 Bun Mapping.generatedLine
    public func generatedLine(): Int64 { generated.line }

    /// 生成代码列号 - 对应 Bun Mapping.generatedColumn
    public func generatedColumn(): Int64 { generated.column }

    /// 原始代码行号 - 对应 Bun Mapping.originalLine
    public func originalLine(): Int64 { original.line }

    /// 原始代码列号 - 对应 Bun Mapping.originalColumn
    public func originalColumn(): Int64 { original.column }
}

// ============================================================================
// SourceMapSection - 索引 Source Map 节
// 用于索引 Source Map (indexed source maps)
// ============================================================================

/// Source Map 节 - 用于索引 Source Map
public class SourceMapSection {
    /// 节的偏移行
    public var offsetLine: Int64
    /// 节的偏移列
    public var offsetColumn: Int64
    /// 节的 URL 或数据
    public var url: String
    /// 节的 Source Map 数据
    public var map: ?SourceMapConsumer

    public init(offsetLine: Int64, offsetColumn: Int64, url: String) {
        this.offsetLine = offsetLine
        this.offsetColumn = offsetColumn
        this.url = url
        this.map = None
    }
}

// ============================================================================
// SourceMapConsumer - Source Map 消费者
// 对应 Bun ParsedSourceMap + Mapping.List 的查找功能
// 严格翻译自: Mapping.List.find / findIndex
//   pub fn find(this: *const List, line: bun.Ordinal, column: bun.Ordinal) ?Mapping {
//       // 二分查找: 找到 generated 位置 <= (line, column) 的最后一个映射
//       var count = line_column_offsets.len;
//       var index: usize = 0;
//       while (count > 0) {
//           const step = count / 2;
//           const i = index + step;
//           if (mapping.lines < line || (mapping.lines == line && mapping.columns <= column)) {
//               index = i + 1;
//               count -= step + 1;
//           } else { count = step; }
//       }
//       if (index > 0 && offsets[index-1].lines == line) return index - 1;
//   }
// ============================================================================

/// Source Map 消费者 - 用于查找原始位置
/// 对应 Bun ParsedSourceMap 的查找功能
public class SourceMapConsumer {
    /// 映射列表 (已排序)
    private var mappings: ArrayList<SourceMapping>
    /// 源文件路径列表
    private var sources: ArrayList<String>
    /// 源文件内容列表
    private var sourcesContent: ArrayList<String>
    /// 名称列表
    private var names: ArrayList<String>

    public init() {
        mappings = ArrayList<SourceMapping>()
        sources = ArrayList<String>()
        sourcesContent = ArrayList<String>()
        names = ArrayList<String>()
    }

    public init(mappings: ArrayList<SourceMapping>, sources: ArrayList<String>,
                sourcesContent: ArrayList<String>, names: ArrayList<String>) {
        this.mappings = mappings
        this.sources = sources
        this.sourcesContent = sourcesContent
        this.names = names
    }

    /// 查找原始位置 - 对应 Bun Mapping.List.find
    /// 给定生成代码的行列位置，返回对应的原始位置映射
    /// 使用二分查找定位最近的映射
    public func originalPositionFor(line: Int64, col: Int64): ?SourceMapping {
        if (mappings.size == 0) {
            return None
        }

        // 二分查找 - 对应 Bun findIndexFromGenerated
        var lo = 0
        var hi = mappings.size

        while (lo < hi) {
            let mid = lo + (hi - lo) / 2
            let mapping = mappings[mid]

            if (mapping.generated.line < line ||
                (mapping.generated.line == line && mapping.generated.column <= col)) {
                lo = mid + 1
            } else {
                hi = mid
            }
        }

        // 检查找到的映射是否在同一行
        if (lo > 0) {
            let found = mappings[lo - 1]
            if (found.generated.line == line) {
                return found
            }
        }

        return None
    }

    /// 获取源文件路径
    public func getSource(sourceIndex: Int64): ?String {
        if (sourceIndex < 0 || sourceIndex >= sources.size) {
            return None
        }
        return Some(sources[sourceIndex])
    }

    /// 获取源文件内容
    public func getSourceContent(sourceIndex: Int64): ?String {
        if (sourceIndex < 0 || sourceIndex >= sourcesContent.size) {
            return None
        }
        return Some(sourcesContent[sourceIndex])
    }

    /// 获取名称
    public func getName(nameIndex: Int64): ?String {
        if (nameIndex < 0 || nameIndex >= names.size) {
            return None
        }
        return Some(names[nameIndex])
    }

    /// 获取所有映射
    public func getMappings(): ArrayList<SourceMapping> {
        mappings
    }

    /// 获取源文件列表
    public func getSources(): ArrayList<String> {
        sources
    }
}

// ============================================================================
// SourceMapGenerator - Source Map 生成器
// 对应 Bun 的 Source Map 生成逻辑 (appendMappingToBuffer, SourceMapPieces)
// 严格翻译自:
//   sourcemap.zig - appendMappingToBuffer
//   pub fn appendMappingToBuffer(buffer, last_byte, prev_state, current_state) void {
//       const vlqs = [_]VLQ{
//           .encode(current_state.generated_column -| prev_state.generated_column),
//           .encode(current_state.source_index -| prev_state.source_index),
//           .encode(current_state.original_line -| prev_state.original_line),
//           .encode(current_state.original_column -| prev_state.original_column),
//       };
//   }
// ============================================================================

/// Source Map 生成器 - 对应 Bun SourceMapPieces + appendMappingToBuffer
public class SourceMapGenerator {
    /// 映射列表
    private var mappings: ArrayList<SourceMapping>
    /// 源文件路径列表
    private var sources: ArrayList<String>
    /// 源文件内容列表
    private var sourcesContent: ArrayList<?String>
    /// 名称列表
    private var names: ArrayList<String>
    /// 文件路径
    public var file: String

    public init() {
        mappings = ArrayList<SourceMapping>()
        sources = ArrayList<String>()
        sourcesContent = ArrayList<?String>()
        names = ArrayList<String>()
        file = ""
    }

    public init(file: String) {
        mappings = ArrayList<SourceMapping>()
        sources = ArrayList<String>()
        sourcesContent = ArrayList<?String>()
        names = ArrayList<String>()
        this.file = file
    }

    /// 添加映射 - 对应 Bun appendMappingToBuffer
    public func addMapping(genLine: Int64, genCol: Int64, srcIdx: Int64,
                           origLine: Int64, origCol: Int64, nameIdx: Int64): Unit {
        mappings.append(SourceMapping(genLine, genCol, srcIdx, origLine, origCol, nameIdx))
    }

    /// 添加源文件
    public func addSource(source: String): Int64 {
        sources.append(source)
        sourcesContent.append(None)
        return sources.size - 1
    }

    /// 设置源文件内容 - 对应 Bun sourcesContent 字段
    public func setSourceContent(index: Int64, content: String): Unit {
        if (index >= 0 && index < sourcesContent.size) {
            sourcesContent[index] = Some(content)
        }
    }

    /// 添加名称
    public func addName(name: String): Int64 {
        names.append(name)
        return names.size - 1
    }

    // ========================================================================
    // generateMappings - 生成 VLQ 编码的 mappings 字符串
    // 严格翻译自: appendMappingToBuffer
    //   const vlqs = [_]VLQ{
    //       .encode(current_state.generated_column -| prev_state.generated_column),
    //       .encode(current_state.source_index -| prev_state.source_index),
    //       .encode(current_state.original_line -| prev_state.original_line),
    //       .encode(current_state.original_column -| prev_state.original_column),
    //   };
    //
    // mappings 编码格式:
    //   - 每个映射编码为 4 或 5 个 VLQ 值:
    //     1. 生成列 (相对于前一映射的增量)
    //     2. 源文件索引 (增量)
    //     3. 原始行 (增量)
    //     4. 原始列 (增量)
    //     5. 名称索引 (增量, 可选)
    //   - 映射之间用 ',' 分隔
    //   - 换行用 ';' 分隔
    // ========================================================================

    /// 生成 VLQ 编码的 mappings 字符串
    public func generateMappings(): String {
        if (mappings.size == 0) {
            return ""
        }

        var sb = StringBuilder()
        var prevGenCol = 0
        var prevSrcIdx = 0
        var prevOrigLine = 0
        var prevOrigCol = 0
        var prevNameIdx = 0
        var prevGenLine = 0

        for (i in 0..mappings.size) {
            let m = mappings[i]

            // 新行 -> 用 ';' 分隔
            if (m.generated.line != prevGenLine) {
                var lineDiff = m.generated.line - prevGenLine
                while (lineDiff > 0) {
                    sb.append(';')
                    lineDiff -= 1
                }
                prevGenCol = 0  // 新行重置列
                prevGenLine = m.generated.line
            } else if (i > 0) {
                sb.append(',')
            }

            // 编码 4 个增量值 - 对应 Bun appendMappingToBuffer
            // VLQ 编码使用增量 (相对于前一映射)
            let genColDelta = m.generated.column - prevGenCol
            let srcIdxDelta = m.sourceIndex - prevSrcIdx
            let origLineDelta = m.original.line - prevOrigLine
            let origColDelta = m.original.column - prevOrigCol

            sb.append(VLQ.encode(genColDelta))
            sb.append(VLQ.encode(srcIdxDelta))
            sb.append(VLQ.encode(origLineDelta))
            sb.append(VLQ.encode(origColDelta))

            // 可选的第 5 个值: 名称索引
            if (m.nameIndex >= 0) {
                let nameIdxDelta = m.nameIndex - prevNameIdx
                sb.append(VLQ.encode(nameIdxDelta))
                prevNameIdx = m.nameIndex
            }

            prevGenCol = m.generated.column
            prevSrcIdx = m.sourceIndex
            prevOrigLine = m.original.line
            prevOrigCol = m.original.column
        }

        return sb.toString()
    }

    // ========================================================================
    // toJSON - 生成 Source Map JSON
    // 对应 Bun Source Map 的 JSON 输出格式:
    // {
    //   "version": 3,
    //   "file": "...",
    //   "sources": [...],
    //   "sourcesContent": [...],
    //   "names": [...],
    //   "mappings": "..."
    // }
    // ========================================================================

    /// 生成 Source Map JSON 字符串
    public func toJSON(): String {
        var sb = StringBuilder()
        sb.append("{\n")
        sb.append("  \"version\": 3")

        if (file.size > 0) {
            sb.append(",\n  \"file\": \"${escapeJson(file)}\"")
        }

        // sources 数组
        sb.append(",\n  \"sources\": [")
        for (i in 0..sources.size) {
            if (i > 0) { sb.append(", ") }
            sb.append("\"${escapeJson(sources[i])}\"")
        }
        sb.append("]")

        // sourcesContent 数组
        sb.append(",\n  \"sourcesContent\": [")
        for (i in 0..sourcesContent.size) {
            if (i > 0) { sb.append(", ") }
            match (sourcesContent[i]) {
                case Some(content) => sb.append("\"${escapeJson(content)}\"")
                case None => sb.append("null")
            }
        }
        sb.append("]")

        // names 数组
        sb.append(",\n  \"names\": [")
        for (i in 0..names.size) {
            if (i > 0) { sb.append(", ") }
            sb.append("\"${escapeJson(names[i])}\"")
        }
        sb.append("]")

        // mappings 字符串
        sb.append(",\n  \"mappings\": \"${generateMappings()}\"")

        sb.append("\n}")
        return sb.toString()
    }

    /// JSON 字符串转义
    private static func escapeJson(s: String): String {
        var sb = StringBuilder()
        for (i in 0..s.size) {
            let ch = s[i]
            if (ch == '"') {
                sb.append("\\\"")
            } else if (ch == '\\') {
                sb.append("\\\\")
            } else if (ch == '\n') {
                sb.append("\\n")
            } else if (ch == '\r') {
                sb.append("\\r")
            } else if (ch == '\t') {
                sb.append("\\t")
            } else {
                sb.append(ch)
            }
        }
        return sb.toString()
    }
}

// ============================================================================
// SourceMap - 顶层 Source Map 解析入口
// 严格翻译自: src/sourcemap/sourcemap.zig - parseJSON / parseMappings
// 以及 Mapping.zig - Mapping.parse
//
// Mapping.parse 核心逻辑:
//   var generated = LineColumnOffset{};
//   var original = LineColumnOffset{};
//   var name_index: i32 = 0;
//   var source_index: i32 = 0;
//   while (remain.len > 0) {
//       if (remain[0] == ';') { generated.lines++; generated.columns = 0; continue; }
//       generated.columns += decodeVLQ(remain);  // 增量
//       source_index += decodeVLQ(remain);
//       original.lines += decodeVLQ(remain);
//       original.columns += decodeVLQ(remain);
//       name_index += decodeVLQ(remain);  // 可选
//   }
// ============================================================================

/// Source Map 解析与生成 - 顶层类
public class SourceMap {
    /// 解析 Source Map JSON 并返回消费者
    /// 对应 Bun parseJSON -> Mapping.parse
    public static func parse(json: String): ?SourceMapConsumer {
        // 简化的 JSON 解析: 提取 mappings, sources, sourcesContent, names
        let mappingsStr = extractJsonString(json, "mappings")
        if (mappingsStr == None) {
            return None
        }

        let sources = extractJsonArray(json, "sources")
        let sourcesContent = extractJsonStringArray(json, "sourcesContent")
        let names = extractJsonArray(json, "names")

        // 解析 mappings 字符串
        let parsedMappings = parseMappings(mappingsStr.getOrThrow(),
            if (sources != None) { sources.getOrThrow().size } else { 0 })

        let consumer = SourceMapConsumer()
        consumer.mappings = parsedMappings
        if (sources != None) {
            for (i in 0..sources.getOrThrow().size) {
                consumer.sources.append(sources.getOrThrow()[i])
            }
        }
        if (sourcesContent != None) {
            for (i in 0..sourcesContent.getOrThrow().size) {
                consumer.sourcesContent.append(sourcesContent.getOrThrow()[i])
            }
        }
        if (names != None) {
            for (i in 0..names.getOrThrow().size) {
                consumer.names.append(names.getOrThrow()[i])
            }
        }

        return consumer
    }

    /// 解析 mappings 字符串
    /// 严格翻译自: Mapping.parse
    ///
    /// mappings 编码格式:
    ///   - ';' 分隔行 (每行对应生成代码的一行)
    ///   - ',' 分隔同一行的映射
    ///   - 每个映射包含 1/4/5 个 VLQ 值:
    ///     1. 生成列 (增量)
    ///     2. 源文件索引 (增量)
    ///     3. 原始行 (增量)
    ///     4. 原始列 (增量)
    ///     5. 名称索引 (增量, 可选)
    public static func parseMappings(mappings: String, sourceCount: Int64): ArrayList<SourceMapping> {
        let result = ArrayList<SourceMapping>()
        if (mappings.size == 0) {
            return result
        }

        // 运行状态 - 对应 Bun Mapping.parse 中的局部变量
        var genLine = 0
        var genCol = 0
        var srcIdx = 0
        var origLine = 0
        var origCol = 0
        var nameIdx = 0

        var pos = 0

        while (pos < mappings.size) {
            let ch = mappings[pos]

            // ';' -> 新行
            // Bun: if (remain[0] == ';') { generated.columns = 0; generated.lines++; }
            if (ch == ';') {
                genLine += 1
                genCol = 0
                pos += 1
                continue
            }

            // ',' -> 同行新映射
            if (ch == ',') {
                pos += 1
                continue
            }

            // 解码生成列增量
            let colResult = VLQ.decode(mappings, pos)
            if (colResult.start == pos) {
                // 解码失败，跳过
                pos += 1
                continue
            }
            genCol += colResult.value
            pos = colResult.start

            // 检查是否有更多字段
            if (pos >= mappings.size || mappings[pos] == ',' || mappings[pos] == ';') {
                // 仅有 1 个字段 -> 无原始位置信息，跳过
                // Bun: "Having one field means there's no original location information"
                continue
            }

            // 解码源文件索引增量
            let srcResult = VLQ.decode(mappings, pos)
            if (srcResult.start == pos) { break }
            srcIdx += srcResult.value
            pos = srcResult.start

            // 解码原始行增量
            let lineResult = VLQ.decode(mappings, pos)
            if (lineResult.start == pos) { break }
            origLine += lineResult.value
            pos = lineResult.start

            // 解码原始列增量
            let colOrigResult = VLQ.decode(mappings, pos)
            if (colOrigResult.start == pos) { break }
            origCol += colOrigResult.value
            pos = colOrigResult.start

            // 可选: 解码名称索引增量 (第 5 个字段)
            var mapNameIdx = -1
            if (pos < mappings.size && mappings[pos] != ',' && mappings[pos] != ';') {
                let nameResult = VLQ.decode(mappings, pos)
                if (nameResult.start > pos) {
                    nameIdx += nameResult.value
                    mapNameIdx = nameIdx
                    pos = nameResult.start
                }
            }

            // 创建映射条目
            result.append(SourceMapping(
                genLine, genCol, srcIdx,
                origLine, origCol, mapNameIdx
            ))
        }

        return result
    }

    /// 从 JSON 字符串提取字段值 (简化解析)
    private static func extractJsonString(json: String, field: String): ?String {
        let needle = "\"${field}\""
        let idx = json.indexOf(needle)
        if (idx < 0) { return None }

        // 查找冒号后的字符串值
        var pos = idx + needle.size
        while (pos < json.size && json[pos] != ':') { pos += 1 }
        pos += 1  // 跳过冒号

        // 跳过空白
        while (pos < json.size && json[pos] == ' ') { pos += 1 }

        if (pos >= json.size || json[pos] != '"') { return None }
        pos += 1  // 跳过开始引号

        var sb = StringBuilder()
        while (pos < json.size) {
            let ch = json[pos]
            if (ch == '\\') {
                pos += 1
                if (pos < json.size) {
                    sb.append(json[pos])
                    pos += 1
                }
            } else if (ch == '"') {
                break
            } else {
                sb.append(ch)
                pos += 1
            }
        }

        return Some(sb.toString())
    }

    /// 从 JSON 字符串提取字符串数组字段
    private static func extractJsonArray(json: String, field: String): ?ArrayList<String> {
        let needle = "\"${field}\""
        let idx = json.indexOf(needle)
        if (idx < 0) { return None }

        var pos = idx + needle.size
        while (pos < json.size && json[pos] != ':') { pos += 1 }
        pos += 1
        while (pos < json.size && json[pos] == ' ') { pos += 1 }

        if (pos >= json.size || json[pos] != '[') { return None }
        pos += 1

        let result = ArrayList<String>()
        while (pos < json.size && json[pos] != ']') {
            if (json[pos] == ' ' || json[pos] == ',' || json[pos] == '\n') {
                pos += 1
                continue
            }
            if (json[pos] != '"') {
                pos += 1
                continue
            }
            pos += 1  // 跳过引号
            var sb = StringBuilder()
            while (pos < json.size && json[pos] != '"') {
                if (json[pos] == '\\') {
                    pos += 1
                    if (pos < json.size) {
                        sb.append(json[pos])
                    }
                } else {
                    sb.append(json[pos])
                }
                pos += 1
            }
            if (pos < json.size) { pos += 1 }  // 跳过关闭引号
            result.append(sb.toString())
        }

        return Some(result)
    }

    /// 从 JSON 字符串提取字符串数组字段 (sourcesContent)
    private static func extractJsonStringArray(json: String, field: String): ?ArrayList<String> {
        extractJsonArray(json, field)
    }
}
