// Chunk - SourceMap Chunk
// 严格翻译自: src/sourcemap/Chunk.zig
//   const Chunk = @This();
//   buffer: MutableString,
//   mappings_count: usize = 0,
//   end_state: SourceMapState = .{},
//   final_generated_column: i32 = 0,
//   should_ignore: bool = true,
//   pub fn initEmpty, deinit, printSourceMapContents
//   pub fn SourceMapFormat(comptime Type: type) type
//   pub const VLQSourceMap = struct { ... }
//   pub fn NewBuilder(comptime SourceMapFormatType: type) type
//   pub const Builder = NewBuilder(VLQSourceMap);
package bao_sourcemap.chunk

import bao_core.*
import bao_sourcemap.vlq.*
import bao_sourcemap.mapping.*

// ============================================================================
// Chunk - SourceMap 块
// 严格翻译自: Chunk.zig - Chunk
//   const Chunk = @This();
//   buffer: MutableString,
//   mappings_count: usize = 0,
//   end_state: SourceMapState = .{},
//   final_generated_column: i32 = 0,
//   should_ignore: bool = true,
// ============================================================================

/// SourceMap 块 - 对应 Bun Chunk
/// Source map chunks are computed in parallel for speed. Each chunk is relative
/// to the zero state instead of being relative to the end state of the previous
/// chunk, since it's impossible to know the end state of the previous chunk in
/// a parallel computation.
///
/// After all chunks are computed, they are joined together in a second pass.
/// This rewrites the first mapping in each chunk to be relative to the end
/// state of the previous chunk.
public class Chunk {
    /// 映射数据缓冲区 (VLQ 编码的 mappings 字符串)
    public var buffer: String
    /// 映射数量
    public var mappingsCount: Int64
    /// 结束状态 - 用于重写下一个 chunk 的起始映射
    /// This end state will be used to rewrite the start of the following source
    /// map chunk so that the delta-encoded VLQ numbers are preserved.
    public var endState: SourceMapState
    /// 最后生成的列号
    /// There probably isn't a source mapping at the end of the file (nor should
    /// there be) but if we're appending another source map chunk after this one,
    /// we'll need to know how many characters were in the last line we generated.
    public var finalGeneratedColumn: Int64
    /// 是否应该忽略空 chunk
    /// ignore empty chunks
    public var shouldIgnore: Bool

    public init() {
        buffer = ""
        mappingsCount = 0
        endState = SourceMapState()
        finalGeneratedColumn = 0
        shouldIgnore = true
    }

    /// 初始化空 chunk - 对应 Bun Chunk.initEmpty
    public static func initEmpty(): Chunk {
        Chunk()
    }

    /// 判断是否有内容
    public func hasContent(): Bool {
        buffer.size > 0 && mappingsCount > 0
    }

    /// 获取缓冲区
    public func getBuffer(): String {
        buffer
    }
}

// ============================================================================
// VLQSourceMap - VLQ 格式 SourceMap 写入器
// 严格翻译自: Chunk.zig - VLQSourceMap
//   pub const VLQSourceMap = struct {
//       data: MutableString,
//       internal: ?InternalSourceMap.Builder = null,
//       count: usize = 0,
//       offset: usize = 0,
//       approximate_input_line_count: usize = 0,
//       pub fn init, appendLineSeparator, append, shouldIgnore, getBuffer, takeBuffer, getCount
//   };
// ============================================================================

/// VLQ 格式 SourceMap 写入器 - 对应 Bun VLQSourceMap
public class VLQSourceMap {
    /// VLQ 编码数据
    private var data: StringBuilder
    /// 映射数量
    private var count: Int64
    /// 写入偏移
    private var offset: Int64

    public init() {
        data = StringBuilder()
        count = 0
        offset = 0
    }

    /// 添加行分隔符 - 对应 Bun VLQSourceMap.appendLineSeparator
    public func appendLineSeparator(): Unit {
        data.append(';')
    }

    /// 添加映射 - 对应 Bun VLQSourceMap.append
    //   pub fn append(this: *VLQSourceMap, current_state: SourceMapState,
    //                 prev_state: SourceMapState) anyerror!void {
    //       const last_byte: u8 = if (this.data.list.items.len > this.offset)
    //           this.data.list.items[this.data.list.items.len - 1] else 0;
    //       appendMappingToBuffer(&this.data, last_byte, prev_state, current_state);
    //       this.count += 1;
    //   }
    public func append(currentState: SourceMapState,
                       prevState: SourceMapState): Unit {
        // 获取最后一个字节 - 用于判断是否需要逗号
        let lastByte = if (data.size() > 0) {
            Int64(data.toString().toArray()[data.size() - 1])
        } else {
            0
        }

        // 写入映射
        appendMappingToBuffer(lastByte, prevState, currentState)
        count += 1
    }

    /// 判断是否应该忽略
    public func shouldIgnore(): Bool {
        count == 0
    }

    /// 获取映射数量
    public func getCount(): Int64 {
        count
    }

    /// 获取缓冲区字符串
    public func getBuffer(): String {
        data.toString()
    }

    /// 取出缓冲区并重置
    public func takeBuffer(): String {
        let result = data.toString()
        data = StringBuilder()
        count = 0
        offset = 0
        return result
    }

    // ========================================================================
    // appendMappingToBuffer - 将映射写入缓冲区
    // 严格翻译自: sourcemap.zig - appendMappingToBuffer
    //   pub fn appendMappingToBuffer(buffer: *MutableString, last_byte: u8,
    //       prev_state: SourceMapState, current_state: SourceMapState) void {
    //       const needs_comma = last_byte != 0 and last_byte != ';' and last_byte != '"';
    //       const vlqs = [_]VLQ{
    //           .encode(current_state.generated_column -| prev_state.generated_column),
    //           .encode(current_state.source_index -| prev_state.source_index),
    //           .encode(current_state.original_line -| prev_state.original_line),
    //           .encode(current_state.original_column -| prev_state.original_column),
    //       };
    //       // 写入逗号和 VLQ 编码
    //   }
    // ========================================================================

    /// 将映射编码到缓冲区
    /// This function is extremely hot.
    private func appendMappingToBuffer(lastByte: Int64,
                                       prevState: SourceMapState,
                                       currentState: SourceMapState): Unit {
        // 判断是否需要逗号 - 对应 Bun needs_comma
        let needsComma = lastByte != 0 && lastByte != Int64(';') &&
                         lastByte != Int64('"')

        // 编码 4 个增量值 - 对应 Bun vlqs
        // 使用饱和减法 -| 对应 Zig 的 saturating subtraction
        let genColDelta = VLQ.saturatingSub(
            currentState.generatedColumn, prevState.generatedColumn)
        let srcIdxDelta = VLQ.saturatingSub(
            currentState.sourceIndex, prevState.sourceIndex)
        let origLineDelta = VLQ.saturatingSub(
            currentState.originalLine, prevState.originalLine)
        let origColDelta = VLQ.saturatingSub(
            currentState.originalColumn, prevState.originalColumn)

        // 写入逗号
        if (needsComma) {
            data.append(',')
        }

        // 写入 VLQ 编码 - 对应 Bun inline for (&vlqs) |item|
        data.append(VLQ.encode(genColDelta))
        data.append(VLQ.encode(srcIdxDelta))
        data.append(VLQ.encode(origLineDelta))
        data.append(VLQ.encode(origColDelta))
    }
}

// ============================================================================
// ChunkBuilder - Chunk 构建器
// 严格翻译自: Chunk.zig - NewBuilder(VLQSourceMap)
//   pub const Builder = NewBuilder(VLQSourceMap);
//   pub fn NewBuilder(comptime SourceMapFormatType: type) type {
//       return struct {
//           source_map: SourceMapper,
//           line_offset_tables: LineOffsetTable.List = .{},
//           prev_state: SourceMapState = SourceMapState{},
//           last_generated_update: u32 = 0,
//           generated_column: i32 = 0,
//           prev_loc: Logger.Loc = Logger.Loc.Empty,
//           has_prev_state: bool = false,
//           line_starts_with_mapping: bool = false,
//           cover_lines_without_mappings: bool = false,
//           approximate_input_line_count: usize = 0,
//           prepend_count: bool = false,
//       };
//   }
// ============================================================================

/// Chunk 构建器 - 对应 Bun Chunk.Builder (NewBuilder(VLQSourceMap))
public class ChunkBuilder {
    /// VLQ 写入器
    private var sourceMap: VLQSourceMap
    /// 前一个状态
    private var prevState: SourceMapState
    /// 最后生成的更新位置
    private var lastGeneratedUpdate: Int64
    /// 当前生成的列号
    private var generatedColumn: Int64
    /// 是否有前一个状态
    private var hasPrevState: Bool
    /// 当前行是否以映射开始
    private var lineStartsWithMapping: Bool
    /// 是否覆盖没有映射的行
    private var coverLinesWithoutMappings: Bool
    /// 估计的输入行数
    private var approximateInputLineCount: Int64

    public init() {
        sourceMap = VLQSourceMap()
        prevState = SourceMapState()
        lastGeneratedUpdate = 0
        generatedColumn = 0
        hasPrevState = false
        lineStartsWithMapping = false
        coverLinesWithoutMappings = false
        approximateInputLineCount = 0
    }

    // ========================================================================
    // generateChunk - 生成 SourceMap 块
    // 严格翻译自: Chunk.zig - Builder.generateChunk
    //   pub noinline fn generateChunk(b: *ThisBuilder, output: []const u8) Chunk {
    //       b.updateGeneratedLineAndColumn(output);
    //       var buffer = b.source_map.getBuffer();
    //       return Chunk{
    //           .buffer = b.source_map.takeBuffer(),
    //           .mappings_count = b.source_map.getCount(),
    //           .end_state = b.prev_state,
    //           .final_generated_column = b.generated_column,
    //           .should_ignore = b.source_map.shouldIgnore(),
    //       };
    //   }
    // ========================================================================

    /// 生成 SourceMap 块
    public func generateChunk(output: String): Chunk {
        updateGeneratedLineAndColumn(output)

        let chunk = Chunk()
        chunk.buffer = sourceMap.getBuffer()
        chunk.mappingsCount = sourceMap.getCount()
        chunk.endState = prevState.copy()
        chunk.finalGeneratedColumn = generatedColumn
        chunk.shouldIgnore = sourceMap.shouldIgnore()
        return chunk
    }

    // ========================================================================
    // updateGeneratedLineAndColumn - 更新生成的行和列号
    // 严格翻译自: Chunk.zig - Builder.updateGeneratedLineAndColumn
    //   pub fn updateGeneratedLineAndColumn(b: *ThisBuilder, output: []const u8) void {
    //       const slice = output[b.last_generated_update..];
    //       var needs_mapping = b.cover_lines_without_mappings and
    //                           !b.line_starts_with_mapping and b.has_prev_state;
    //       // 扫描输出文本，更新行列号
    //   }
    // ========================================================================

    /// 扫描输出文本，更新生成的行和列号
    public func updateGeneratedLineAndColumn(output: String): Unit {
        if (lastGeneratedUpdate >= output.size) {
            return
        }

        var needsMapping = coverLinesWithoutMappings &&
                           !lineStartsWithMapping && hasPrevState

        var i = lastGeneratedUpdate
        while (i < output.size) {
            let ch = output[i]
            let code = Int64(ch.value)

            if (code >= 14 && code <= 127) {
                // ASCII 快速路径
                var j = i + 1
                while (j < output.size) {
                    let c = Int64(output[j].value)
                    if (c == Int64('\r') || c == Int64('\n') || c > 127) {
                        break
                    }
                    j += 1
                }
                generatedColumn += (j - i)
                i = j
                continue
            }

            if (code == Int64('\r') || code == Int64('\n') ||
                code == 0x2028 || code == 0x2029) {
                // Windows 换行 \r\n
                if (code == Int64('\r') && i + 1 < output.size &&
                    Int64(output[i + 1].value) == Int64('\n')) {
                    i += 1
                    continue
                }

                // 对应 Bun: cover_lines_without_mappings 逻辑
                if (needsMapping) {
                    appendMappingWithoutRemapping(SourceMapState(
                        prevState.generatedLine, 0,
                        prevState.sourceIndex,
                        prevState.originalLine,
                        prevState.originalColumn
                    ))
                }

                prevState.generatedLine += 1
                prevState.generatedColumn = 0
                generatedColumn = 0
                sourceMap.appendLineSeparator()

                lineStartsWithMapping = false
                needsMapping = coverLinesWithoutMappings &&
                               !lineStartsWithMapping && hasPrevState

                i += 1
                continue
            }

            // Mozilla 的 "source-map" 库使用 UTF-16 代码单元计数列
            if (code > 0xFFFF) {
                generatedColumn += 2
            } else {
                generatedColumn += 1
            }
            i += 1
        }

        lastGeneratedUpdate = output.size
    }

    // ========================================================================
    // appendMapping / appendMappingWithoutRemapping
    // 严格翻译自: Chunk.zig - Builder.appendMapping / appendMappingWithoutRemapping
    //   pub fn appendMapping(b: *ThisBuilder, current_state: SourceMapState) void {
    //       b.appendMappingWithoutRemapping(current_state);
    //   }
    //   pub fn appendMappingWithoutRemapping(b: *ThisBuilder,
    //       current_state: SourceMapState) void {
    //       b.source_map.append(current_state, b.prev_state) catch unreachable;
    //       b.prev_state = current_state;
    //       b.has_prev_state = true;
    //   }
    // ========================================================================

    /// 添加映射
    public func appendMapping(currentState: SourceMapState): Unit {
        appendMappingWithoutRemapping(currentState)
    }

    /// 添加映射 (不重映射) - 对应 Bun appendMappingWithoutRemapping
    public func appendMappingWithoutRemapping(currentState: SourceMapState): Unit {
        sourceMap.append(currentState, prevState)
        prevState = currentState.copy()
        hasPrevState = true
    }
}

// ============================================================================
// appendSourceMapChunk - 合并 SourceMap 块
// 严格翻译自: sourcemap.zig - appendSourceMapChunk
//   pub fn appendSourceMapChunk(
//       j: *StringJoiner, allocator: std.mem.Allocator,
//       prev_end_state_: SourceMapState, start_state_: SourceMapState,
//       source_map_: []const u8) !void {
//       // Handle line breaks in between this mapping and the previous one
//       // Skip past any leading semicolons
//       // Strip off the first mapping from the buffer
//       // Rewrite the first mapping to be relative to the end state of the previous chunk
//   }
// ============================================================================

/// SourceMap 块合并器
/// Source map chunks are computed in parallel for speed. Each chunk is relative
/// to the zero state instead of being relative to the end state of the previous
/// chunk. This function joins them together.
public class SourceMapChunkJoiner {
    private var parts: ArrayList<String>
    private var prevState: SourceMapState

    public init() {
        parts = ArrayList<String>()
        prevState = SourceMapState()
    }

    /// 重置
    public func reset(): Unit {
        parts = ArrayList<String>()
        prevState = SourceMapState()
    }

    /// 合并 SourceMap 块 - 对应 Bun appendSourceMapChunk
    //   pub fn appendSourceMapChunk(
    //       j: *StringJoiner, allocator: std.mem.Allocator,
    //       prev_end_state_: SourceMapState, start_state_: SourceMapState,
    //       source_map_: []const u8) !void {
    //       var prev_end_state = prev_end_state_;
    //       var start_state = start_state_;
    //       // Handle line breaks in between this mapping and the previous one
    //       if (start_state.generated_line != 0) {
    //           j.push(repeatingAlloc(allocator, start_state.generated_line, ';'), allocator);
    //           prev_end_state.generated_column = 0;
    //       }
    //       // Skip past any leading semicolons
    //       // Strip off the first mapping
    //       // Rewrite the first mapping to be relative to the end state
    //   }
    public func appendSourceMapChunk(prevEndState: SourceMapState,
                                     startState: SourceMapState,
                                     sourceMap: String): Unit {
        var prevEndState = prevEndState.copy()
        var startState = startState.copy()

        // 处理行分隔
        if (startState.generatedLine != 0) {
            var semicolons = StringBuilder()
            for (_ in 0..startState.generatedLine) {
                semicolons.append(';')
            }
            parts.append(semicolons.toString())
            prevEndState.generatedColumn = 0
        }

        // 跳过前导分号
        var sourceMapStr = sourceMap
        var semicolonCount = 0
        while (semicolonCount < sourceMapStr.size &&
               sourceMapStr[semicolonCount] == ';') {
            semicolonCount += 1
        }
        if (semicolonCount > 0) {
            parts.append(sourceMapStr.subString(0, semicolonCount))
            sourceMapStr = sourceMapStr.subString(semicolonCount)
            prevEndState.generatedColumn = 0
            startState.generatedColumn = 0
        }

        // 剥离第一个映射
        // Bun: decodeVLQAssumeValid 四次
        var i = 0
        let genCol = VLQ.decodeAssumeValid(sourceMapStr, i)
        i = genCol.start
        let srcIdx = VLQ.decodeAssumeValid(sourceMapStr, i)
        i = srcIdx.start
        let origLine = VLQ.decodeAssumeValid(sourceMapStr, i)
        i = origLine.start
        let origCol = VLQ.decodeAssumeValid(sourceMapStr, i)
        i = origCol.start

        let remaining = if (i < sourceMapStr.size) {
            sourceMapStr.subString(i)
        } else {
            ""
        }

        // 重写第一个映射，使其相对于前一个 chunk 的结束状态
        startState.sourceIndex += srcIdx.value
        startState.generatedColumn += genCol.value
        startState.originalLine += origLine.value
        startState.originalColumn += origCol.value

        // 编码重写后的映射
        let sb = StringBuilder()
        let lastByte = if (parts.size > 0 && parts[parts.size - 1].size > 0) {
            Int64(parts[parts.size - 1].toArray()[parts[parts.size - 1].size - 1])
        } else {
            0
        }

        let needsComma = lastByte != 0 && lastByte != Int64(';') &&
                         lastByte != Int64('"')
        if (needsComma) {
            sb.append(',')
        }

        // 编码 4 个增量值
        sb.append(VLQ.encode(VLQ.saturatingSub(startState.generatedColumn,
            prevEndState.generatedColumn)))
        sb.append(VLQ.encode(VLQ.saturatingSub(startState.sourceIndex,
            prevEndState.sourceIndex)))
        sb.append(VLQ.encode(VLQ.saturatingSub(startState.originalLine,
            prevEndState.originalLine)))
        sb.append(VLQ.encode(VLQ.saturatingSub(startState.originalColumn,
            prevEndState.originalColumn)))

        parts.append(sb.toString())

        // 追加剩余部分
        if (remaining.size > 0) {
            parts.append(remaining)
        }

        // 更新 prev state
        prevState = startState.copy()
    }

    /// 获取合并后的结果
    public func finalize(): String {
        var sb = StringBuilder()
        for (i in 0..parts.size) {
            sb.append(parts[i])
        }
        return sb.toString()
    }
}
