// SourceMap Builder - SourceMap 构建器与核心逻辑
// 严格翻译自: src/sourcemap/sourcemap.zig
//   pub const SourceMap = @This();
//   SourceMapState, LineColumnOffset, SourceMapPieces
//   appendSourceMapChunk, appendMappingToBuffer, parseUrl, parseJSON
//   findSourceMappingURL
package bao_sourcemap

import bao_core.*

// ============================================================================
// SourceMapPieces - SourceMap 片段
// 严格翻译自: sourcemap.zig - SourceMapPieces
//   pub const SourceMapPieces = struct {
//       prefix: std.array_list.Managed(u8),
//       mappings: std.array_list.Managed(u8),
//       suffix: std.array_list.Managed(u8),
//       pub fn init, hasContent, finalize
//   };
// ============================================================================

/// SourceMap 片段 - 对应 Bun SourceMapPieces
/// 用于拼接和修改 source map JSON 的不同部分
public class SourceMapPieces {
    /// JSON 前缀 (从 "{" 到 "mappings" 键之前)
    public var prefix: StringBuilder
    /// mappings 值
    public var mappings: StringBuilder
    /// JSON 后缀 (从 mappings 值之后到 "}")
    public var suffix: StringBuilder

    public init() {
        prefix = StringBuilder()
        mappings = StringBuilder()
        suffix = StringBuilder()
    }

    /// 判断是否有内容 - 对应 Bun SourceMapPieces.hasContent
    //   pub fn hasContent(this: *SourceMapPieces) bool {
    //       return (this.prefix.items.len + this.mappings.items.len +
    //               this.suffix.items.len) > 0;
    //   }
    public func hasContent(): Bool {
        prefix.size() + mappings.size() + suffix.size() > 0
    }

    // ========================================================================
    // finalize - 应用偏移并合并
    // 严格翻译自: sourcemap.zig - SourceMapPieces.finalize
    //   pub fn finalize(this: *SourceMapPieces, allocator,
    //                   _shifts: []SourceMapShifts) ![]const u8 {
    //       var shifts = _shifts;
    //       var start_of_run: usize = 0;
    //       var current: usize = 0;
    //       var generated = LineColumnOffset{};
    //       var prev_shift_column_delta: i32 = 0;
    //       var j = StringJoiner{ .allocator = sfb.get() };
    //       j.pushStatic(this.prefix.items);
    //       const mappings = this.mappings.items;
    //       while (current < mappings.len) {
    //           // 扫描 mappings，应用 shift
    //           // 行分隔 -> generated.lines += 1
    //           // 解码 VLQ -> generated.columns += delta
    //           // 跳过 source_index, original_line, original_column
    //           // 如果有第 5 字段 (name_index)，也跳过
    //           // 检查 shift 边界，应用列偏移
    //       }
    //       j.pushStatic(mappings[start_of_run..]);
    //       return j.doneWithEnd(allocator, this.suffix.items);
    //   }
    // ========================================================================

    /// 应用行偏移并生成最终的 source map JSON
    /// 对应 Bun SourceMapPieces.finalize
    public func finalize(shifts: ArrayList<SourceMapShift>): String {
        var sb = StringBuilder()
        sb.append(prefix.toString())

        var startOfRun = 0
        var current = 0
        var generatedLine = 0
        var generatedColumn = 0
        var prevShiftColumnDelta: Int64 = 0
        let mappingsStr = mappings.toString()
        let mappingsBytes = mappingsStr.toArray()
        var shiftIdx = 0

        while (current < mappingsBytes.size) {
            let b = mappingsBytes[current]
            if (b == UInt8(';')) {
                generatedLine += 1
                generatedColumn = 0
                prevShiftColumnDelta = 0
                current += 1
                continue
            }

            let potentialEndOfRun = current

            // 解码生成列增量
            let decodeResult = VLQ.decode(mappingsStr, current)
            generatedColumn += decodeResult.value
            current = decodeResult.start

            let potentialStartOfRun = current

            // 跳过 source_index, original_line, original_column
            let si = VLQ.decodeAssumeValid(mappingsStr, current)
            current = si.start
            let ol = VLQ.decodeAssumeValid(mappingsStr, current)
            current = ol.start
            let oc = VLQ.decodeAssumeValid(mappingsStr, current)
            current = oc.start

            // 可选的第 5 字段
            if (current < mappingsBytes.size) {
                let c = mappingsBytes[current]
                if (c != UInt8(',') && c != UInt8(';')) {
                    let ni = VLQ.decodeAssumeValid(mappingsStr, current)
                    current = ni.start
                }
            }

            if (current < mappingsBytes.size && mappingsBytes[current] == UInt8(',')) {
                current += 1
            }

            // 检查 shift 边界
            var didCrossBoundary = false
            if (shiftIdx + 1 < shifts.size) {
                let nextShift = shifts[shiftIdx + 1]
                if (nextShift.before.comesBefore(
                        LineColumnOffset(generatedLine, generatedColumn))) {
                    shiftIdx += 1
                    didCrossBoundary = true
                }
            }

            if (!didCrossBoundary) {
                continue
            }

            let shift = shifts[shiftIdx]
            // 只在同行时应用偏移
            if (shift.after.line != generatedLine) {
                continue
            }

            // 写入到 potentialEndOfRun 的部分
            sb.append(mappingsStr.subString(startOfRun, potentialEndOfRun))

            // 计算偏移后的列增量
            let shiftColumnDelta = shift.after.column - shift.before.column
            let vlqValue = decodeResult.value + shiftColumnDelta - prevShiftColumnDelta
            sb.append(VLQ.encode(vlqValue))
            prevShiftColumnDelta = shiftColumnDelta

            startOfRun = potentialStartOfRun
        }

        // 写入剩余部分
        sb.append(mappingsStr.subString(startOfRun))
        // 写入后缀
        sb.append(suffix.toString())

        return sb.toString()
    }
}

// ============================================================================
// SourceMapShift - SourceMap 偏移
// 严格翻译自: sourcemap.zig - SourceMapShifts
//   pub const SourceMapShifts = struct {
//       before: LineColumnOffset,
//       after: LineColumnOffset,
//   };
// ============================================================================

/// SourceMap 偏移 - 对应 Bun SourceMapShifts
public class SourceMapShift {
    public var before: LineColumnOffset
    public var after: LineColumnOffset

    public init(before: LineColumnOffset, after: LineColumnOffset) {
        this.before = before
        this.after = after
    }

    public init() {
        before = LineColumnOffset()
        after = LineColumnOffset()
    }
}

// ============================================================================
// SourceContent - 源内容
// 严格翻译自: sourcemap.zig - SourceContent
//   pub const SourceContent = struct {
//       value: []const u16 = &[_]u16{},
//       quoted: []const u8 = &[_]u8{},
//   };
// ============================================================================

/// 源内容 - 对应 Bun SourceContent
public class SourceContent {
    /// 源代码内容 (UTF-16 编码)
    public var value: String
    /// JSON 引用字符串
    public var quoted: String

    public init() {
        value = ""
        quoted = ""
    }

    public init(value: String, quoted: String) {
        this.value = value
        this.quoted = quoted
    }
}

// ============================================================================
// DebugIDFormatter - 调试 ID 格式化
// 严格翻译自: sourcemap.zig - DebugIDFormatter
//   pub const DebugIDFormatter = struct {
//       id: u64 = 0,
//       pub fn format(self: DebugIDFormatter, writer) !void {
//           var buf: [32]u8 = undefined;
//           const formatter = bun.fmt.hexIntUpper(self.id);
//           _ = std.fmt.bufPrint(&buf, "{f}64756E2164756E21", .{formatter});
//           try writer.writeAll(&buf);
//       }
//   };
// ============================================================================

/// 调试 ID 格式化 - 对应 Bun DebugIDFormatter
/// https://sentry.engineering/blog/the-case-for-debug-ids
/// The RFC asks for a UUID, which is 128 bits (32 hex chars). Bun hashes are
/// only 64 bits. The end is filled with "bun!bun!" hex encoded.
public class DebugIDFormatter {
    public var id: UInt64

    public init(id: UInt64) {
        this.id = id
    }

    public init() {
        id = 0
    }

    /// 格式化为 32 字符的调试 ID
    public func format(): String {
        // 将 u64 格式化为 16 个 hex 字符 (大写)
        var hex = StringBuilder()
        var remaining = id
        var hexChars = Array<UInt8>()
        // 转为 hex (从高位到低位)
        if (remaining == 0) {
            hexChars.append(UInt8('0'))
        } else {
            while (remaining > 0) {
                let digit = remaining % 16
                remaining = remaining / 16
                if (digit < 10) {
                    hexChars.append(UInt8('0') + UInt8(digit))
                } else {
                    hexChars.append(UInt8('A') + UInt8(digit - 10))
                }
            }
        }
        // 补齐到 16 个字符
        while (hexChars.size < 16) {
            hexChars.append(UInt8('0'))
        }
        // 反转 (因为是从低位到高位)
        for (i in 0..hexChars.size / 2) {
            let tmp = hexChars[i]
            hexChars[i] = hexChars[hexChars.size - 1 - i]
            hexChars[hexChars.size - 1 - i] = tmp
        }
        for (i in 0..hexChars.size) {
            hex.append(Char(Int32(hexChars[i])))
        }
        // 追加 "64756E2164756E21" ("bun!bun!" hex 编码)
        hex.append("64756E2164756E21")
        return hex.toString()
    }
}

// ============================================================================
// SourceMapBuilder - SourceMap 构建器
// 严格翻译自: sourcemap.zig 中的核心函数
//   - appendMappingToBuffer: 映射编码到缓冲区
//   - appendSourceMapChunk: 合并 SourceMap 块
//   - parseUrl: 解析 inline source map URL
//   - parseJSON: 解析 JSON source map
//   - findSourceMappingURL: 查找 sourceMappingURL 注释
// ============================================================================

/// SourceMap 构建器 - 对应 Bun sourcemap.zig 中的核心函数
public class SourceMapBuilder {
    // ========================================================================
    // appendMappingToBuffer - 将映射编码到缓冲区
    // 严格翻译自: sourcemap.zig
    //   pub fn appendMappingToBuffer(buffer: *MutableString, last_byte: u8,
    //       prev_state: SourceMapState, current_state: SourceMapState) void {
    //       const needs_comma = last_byte != 0 and last_byte != ';' and last_byte != '"';
    //       const vlqs = [_]VLQ{
    //           .encode(current_state.generated_column -| prev_state.generated_column),
    //           .encode(current_state.source_index -| prev_state.source_index),
    //           .encode(current_state.original_line -| prev_state.original_line),
    //           .encode(current_state.original_column -| prev_state.original_column),
    //       };
    //       // Count exactly how many bytes we need to write
    //       // Instead of updating .len 5 times, we only need to update it once.
    //   }
    //
    // This function is extremely hot.
    // ========================================================================

    /// 将映射编码为 VLQ 字符串
    /// 对应 Bun appendMappingToBuffer
    /// 使用增量编码，4 个 VLQ 值表示: 生成列, 源索引, 原始行, 原始列
    public static func appendMappingToString(lastByte: Int64,
                                             prevState: SourceMapState,
                                             currentState: SourceMapState): String {
        let needsComma = lastByte != 0 && lastByte != Int64(';') &&
                         lastByte != Int64('"')

        let sb = StringBuilder()

        if (needsComma) {
            sb.append(',')
        }

        // 编码 4 个增量值 - 使用饱和减法 -|
        sb.append(VLQ.encode(VLQ.saturatingSub(
            currentState.generatedColumn, prevState.generatedColumn)))
        sb.append(VLQ.encode(VLQ.saturatingSub(
            currentState.sourceIndex, prevState.sourceIndex)))
        sb.append(VLQ.encode(VLQ.saturatingSub(
            currentState.originalLine, prevState.originalLine)))
        sb.append(VLQ.encode(VLQ.saturatingSub(
            currentState.originalColumn, prevState.originalColumn)))

        return sb.toString()
    }

    // ========================================================================
    // appendSourceMapChunk - 合并 SourceMap 块
    // 严格翻译自: sourcemap.zig
    //   pub fn appendSourceMapChunk(
    //       j: *StringJoiner, allocator: std.mem.Allocator,
    //       prev_end_state_: SourceMapState, start_state_: SourceMapState,
    //       source_map_: []const u8) !void {
    //       var prev_end_state = prev_end_state_;
    //       var start_state = start_state_;
    //       // Handle line breaks in between this mapping and the previous one
    //       if (start_state.generated_line != 0) {
    //           j.push(repeatingAlloc(allocator, @intCast(start_state.generated_line), ';'), allocator);
    //           prev_end_state.generated_column = 0;
    //       }
    //       // Skip past any leading semicolons
    //       var source_map = source_map_;
    //       if (strings.indexOfNotChar(source_map, ';')) |semicolons| { ... }
    //       // Strip off the first mapping
    //       // Rewrite the first mapping
    //   }
    // ========================================================================

    /// 合并 SourceMap 块 - 对应 Bun appendSourceMapChunk
    /// Source map chunks are computed in parallel for speed. Each chunk is relative
    /// to the zero state. After all chunks are computed, they are joined together.
    /// This rewrites the first mapping in each chunk to be relative to the end
    /// state of the previous chunk.
    public static func appendSourceMapChunk(sb: StringBuilder,
                                            prevEndState: SourceMapState,
                                            startState: SourceMapState,
                                            sourceMap: String): Unit {
        var prevEndState = prevEndState.copy()
        var startState = startState.copy()

        // 处理行分隔 - 对应 Bun
        // if (start_state.generated_line != 0) {
        //     j.push(repeatingAlloc(allocator, start_state.generated_line, ';'));
        //     prev_end_state.generated_column = 0;
        // }
        if (startState.generatedLine != 0) {
            for (_ in 0..startState.generatedLine) {
                sb.append(';')
            }
            prevEndState.generatedColumn = 0
        }

        // 跳过前导分号 - 对应 Bun
        // if (strings.indexOfNotChar(source_map, ';')) |semicolons| {
        //     if (semicolons > 0) {
        //         j.pushStatic(source_map[0..semicolons]);
        //         source_map = source_map[semicolons..];
        //         prev_end_state.generated_column = 0;
        //         start_state.generated_column = 0;
        //     }
        // }
        var sourceMapStr = sourceMap
        var semicolonCount = 0
        while (semicolonCount < sourceMapStr.size &&
               sourceMapStr[semicolonCount] == ';') {
            semicolonCount += 1
        }
        if (semicolonCount > 0) {
            sb.append(sourceMapStr.subString(0, semicolonCount))
            sourceMapStr = sourceMapStr.subString(semicolonCount)
            prevEndState.generatedColumn = 0
            startState.generatedColumn = 0
        }

        // 剥离第一个映射 - 对应 Bun
        // const generated_column = decodeVLQAssumeValid(source_map, i);
        // const source_index = decodeVLQAssumeValid(source_map, i);
        // const original_line = decodeVLQAssumeValid(source_map, i);
        // const original_column = decodeVLQAssumeValid(source_map, i);
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
        // 对应 Bun:
        //   start_state.source_index += source_index.value;
        //   start_state.generated_column += generated_column.value;
        //   start_state.original_line += original_line.value;
        //   start_state.original_column += original_column.value;
        startState.sourceIndex += srcIdx.value
        startState.generatedColumn += genCol.value
        startState.originalLine += origLine.value
        startState.originalColumn += origCol.value

        // 编码重写后的映射
        sb.append(appendMappingToString(
            if (sb.size() > 0) {
                Int64(sb.toString().toArray()[sb.size() - 1])
            } else {
                0
            },
            prevEndState,
            startState
        ))

        // 追加剩余部分
        if (remaining.size > 0) {
            sb.append(remaining)
        }
    }

    // ========================================================================
    // findSourceMappingURL - 查找 sourceMappingURL 注释
    // 严格翻译自: sourcemap.zig
    //   fn findSourceMappingURL(comptime T: type, source: []const T,
    //                           alloc: std.mem.Allocator) ?bun.jsc.ZigString.Slice {
    //       const needle = comptime bun.strings.literal(T, "\n//# sourceMappingURL=");
    //       const found = std.mem.lastIndexOf(T, source, needle) orelse return null;
    //       const end = std.mem.indexOfScalarPos(T, source, found + needle.len, '\n')
    //                   orelse source.len;
    //       const url = std.mem.trimRight(T, source[found + needle.len .. end],
    //                                     &.{ ' ', '\r' });
    //   }
    // ========================================================================

    /// 查找 sourceMappingURL 注释 - 对应 Bun findSourceMappingURL
    /// 查找 `//# sourceMappingURL=` 注释并返回 URL
    public static func findSourceMappingURL(source: String): ?String {
        let needle = "\n//# sourceMappingURL="
        let found = source.lastIndexOf(needle)
        if (found < 0) {
            return None
        }

        let urlStart = found + needle.size
        var urlEnd = source.size

        // 查找行尾
        for (i in urlStart..source.size) {
            if (source[i] == '\n') {
                urlEnd = i
                break
            }
        }

        // 去除尾部空格和 \r
        var url = source.subString(urlStart, urlEnd)
        while (url.size > 0) {
            let last = url[url.size - 1]
            if (last == ' ' || last == '\r') {
                url = url.subString(0, url.size - 1)
            } else {
                break
            }
        }

        return Some(url)
    }

    // ========================================================================
    // parseUrl - 解析 inline source map URL
    // 严格翻译自: sourcemap.zig
    //   pub fn parseUrl(alloc, arena, source: []const u8, hint) !ParseUrl {
    //       const json_bytes = json_bytes: {
    //           const data_prefix = "data:application/json";
    //           if (bun.strings.hasPrefixComptime(source, data_prefix)
    //               and source.len > (data_prefix.len + 1)) try_data_url: {
    //               switch (source[data_prefix.len]) {
    //                   ';' => {
    //                       // base64 编码
    //                       const encoding = bun.sliceTo(source[data_prefix.len + 1 ..], ',');
    //                       if (!bun.strings.eqlComptime(encoding, "base64"))
    //                           break :try_data_url;
    //                       const base64_data = source[data_prefix.len + ";base64,".len ..];
    //                       // decode base64
    //                   },
    //                   ',' => break :json_bytes source[data_prefix.len + 1 ..],
    //                   else => break :try_data_url,
    //               }
    //           }
    //           return error.UnsupportedFormat;
    //       };
    //       return parseJSON(alloc, arena, json_bytes, hint);
    //   }
    // ========================================================================

    /// 解析 inline source map URL - 对应 Bun parseUrl
    /// Parses an inline source map url like `data:application/json,....`
    public static func parseUrl(source: String): ?SourceMapParseResult {
        let dataPrefix = "data:application/json"

        if (!source.startsWith(dataPrefix) ||
            source.size <= dataPrefix.size + 1) {
            return SourceMapParseResult.fail("UnsupportedFormat")
        }

        var jsonBytes: ?String = None

        let afterPrefix = source[dataPrefix.size]
        if (afterPrefix == ';') {
            // 可能是 base64 编码: data:application/json;base64,...
            let rest = source.subString(dataPrefix.size + 1)
            let commaIdx = rest.indexOf(',')
            if (commaIdx < 0) {
                return SourceMapParseResult.fail("UnsupportedFormat")
            }
            let encoding = rest.subString(0, commaIdx)
            if (encoding == "base64") {
                // 解码 base64 - 这里简单处理，实际需要 base64 解码器
                // 在仓颉中暂时直接传递编码字符串
                let base64Data = rest.subString(commaIdx + 1)
                jsonBytes = Some(base64Decode(base64Data))
            }
        } else if (afterPrefix == ',') {
            // 直接 JSON: data:application/json,...
            jsonBytes = Some(source.subString(dataPrefix.size + 1))
        }

        if (jsonBytes == None) {
            return SourceMapParseResult.fail("UnsupportedFormat")
        }

        return parseJSON(jsonBytes.getOrThrow())
    }

    // ========================================================================
    // parseJSON - 解析 JSON source map
    // 严格翻译自: sourcemap.zig
    //   pub fn parseJSON(alloc, arena, source: []const u8, hint) !ParseUrl {
    //       var json = bun.json.parse(&json_src, &log, arena, false) catch {
    //           return error.InvalidJSON;
    //       };
    //       // 检查 version == 3
    //       // 提取 mappings, sourcesContent, sources
    //       // 解析 mappings
    //       // 构建 ParsedSourceMap
    //   }
    //
    // 注意: Bun 使用专门的 JSON 解析器来处理 source map JSON。
    // 仓颉中我们使用简化的 JSON 解析来提取关键字段。
    // ========================================================================

    /// 解析 JSON source map - 对应 Bun parseJSON
    public static func parseJSON(jsonStr: String): ?SourceMapParseResult {
        // 简化的 JSON source map 解析
        // 提取关键字段: version, mappings, sources, sourcesContent

        // 检查版本
        let versionKey = "\"version\""
        let versionIdx = jsonStr.indexOf(versionKey)
        if (versionIdx < 0) {
            // version 字段可选
        }

        // 提取 mappings
        let mappingsKey = "\"mappings\""
        let mappingsIdx = jsonStr.indexOf(mappingsKey)
        if (mappingsIdx < 0) {
            return SourceMapParseResult.fail("InvalidSourceMap: missing mappings")
        }

        // 查找 mappings 值 (双引号字符串)
        let mappingsValueStart = findStringValueStart(jsonStr, mappingsIdx + mappingsKey.size)
        if (mappingsValueStart < 0) {
            return SourceMapParseResult.fail("InvalidSourceMap: invalid mappings value")
        }
        let mappingsValueEnd = jsonStr.indexOf('"', mappingsValueStart + 1)
        if (mappingsValueEnd < 0) {
            return SourceMapParseResult.fail("InvalidSourceMap: unterminated mappings")
        }
        let mappingsValue = jsonStr.subString(mappingsValueStart + 1, mappingsValueEnd)

        // 提取 sources
        let sourcesKey = "\"sources\""
        let sourcesIdx = jsonStr.indexOf(sourcesKey)
        let sourceNames = ArrayList<String>()
        if (sourcesIdx >= 0) {
            extractStringArray(jsonStr, sourcesIdx + sourcesKey.size, sourceNames)
        }

        // 解析 mappings
        let parseOpts = ParseOptions(allowNames: true, sort: true)
        let mappingResult = MappingParser.parse(
            mappingsValue,
            Int64.MAX_VALUE,  // sourceCount
            0,                // inputLineCount
            parseOpts
        )

        // 构建 ParsedSourceMap
        let parsedMap = ParsedSourceMap(
            mappingResult.inputLineCount,
            mappingResult.mappings
        )
        for (i in 0..sourceNames.size) {
            parsedMap.externalSourceNames.append(sourceNames[i])
        }

        return SourceMapParseResult.success(parsedMap)
    }

    // ========================================================================
    // printSourceMapContentsJSON - 生成 SourceMap JSON
    // 严格翻译自: Chunk.zig - printSourceMapContentsJSON
    //   fn printSourceMapContentsJSON(source, mutable, include_sources_contents,
    //                                 mappings, comptime ascii_only) !void {
    //       mutable.append("{\n  \"version\":3,\n  \"sources\": [");
    //       JSPrinter.quoteForJSON(filename, mutable, ascii_only);
    //       mutable.append("],\n  \"mappings\": ");
    //       JSPrinter.quoteForJSON(mappings, mutable, ascii_only);
    //       mutable.append(", \"names\": []\n}");
    //   }
    // ========================================================================

    /// 生成 SourceMap JSON - 对应 Bun printSourceMapContentsJSON
    public static func printSourceMapContentsJSON(
        filename: String,
        mappings: String,
        includeSourceContents: Bool,
        sourceContents: String
    ): String {
        let sb = StringBuilder()
        sb.append("{\n  \"version\":3,\n  \"sources\": [")
        sb.append(quoteForJSON(filename))
        if (includeSourceContents) {
            sb.append("],\n  \"sourcesContent\": [")
            sb.append(quoteForJSON(sourceContents))
        }
        sb.append("],\n  \"mappings\": ")
        sb.append(quoteForJSON(mappings))
        sb.append(", \"names\": []\n}")
        return sb.toString()
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// Base64 解码 - 简化实现
    private static func base64Decode(encoded: String): String {
        let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        let sb = StringBuilder()
        var i = 0
        while (i + 3 < encoded.size) {
            var b0 = base64CharValue(table, encoded[i])
            var b1 = base64CharValue(table, encoded[i + 1])
            var b2 = base64CharValue(table, encoded[i + 2])
            var b3 = base64CharValue(table, encoded[i + 3])

            let v0 = (b0 << 18) | (b1 << 12) | (b2 << 6) | b3
            sb.append(Char(Int32((v0 >> 16) & 0xFF)))
            sb.append(Char(Int32((v0 >> 8) & 0xFF)))
            sb.append(Char(Int32(v0 & 0xFF)))
            i += 4
        }
        // 处理剩余字符
        if (i < encoded.size && encoded[encoded.size - 1] != '=') {
            // 不完整组，忽略
        } else if (i < encoded.size) {
            // 有 padding
            if (i + 2 <= encoded.size) {
                let b0 = base64CharValue(table, encoded[i])
                let b1 = base64CharValue(table, encoded[i + 1])
                let v = (b0 << 18) | (b1 << 12)
                sb.append(Char(Int32((v >> 16) & 0xFF)))
            }
            if (i + 3 <= encoded.size && encoded[i + 2] != '=') {
                let b0 = base64CharValue(table, encoded[i])
                let b1 = base64CharValue(table, encoded[i + 1])
                let b2 = base64CharValue(table, encoded[i + 2])
                let v = (b0 << 18) | (b1 << 12) | (b2 << 6)
                sb.append(Char(Int32((v >> 16) & 0xFF)))
                sb.append(Char(Int32((v >> 8) & 0xFF)))
            }
        }
        return sb.toString()
    }

    private static func base64CharValue(table: String, ch: Char): Int64 {
        for (i in 0..table.size) {
            if (table[i] == ch) {
                return Int64(i)
            }
        }
        return 0
    }

    /// JSON 字符串转义 - 对应 Bun JSPrinter.quoteForJSON
    private static func quoteForJSON(str: String): String {
        let sb = StringBuilder()
        sb.append('"')
        for (i in 0..str.size) {
            let ch = str[i]
            let code = Int64(ch.value)
            if (code == Int64('"')) {
                sb.append("\\\"")
            } else if (code == Int64('\\')) {
                sb.append("\\\\")
            } else if (code == Int64('\n')) {
                sb.append("\\n")
            } else if (code == Int64('\r')) {
                sb.append("\\r")
            } else if (code == Int64('\t')) {
                sb.append("\\t")
            } else if (code < 32) {
                // 控制字符 -> \uXXXX
                sb.append("\\u00")
                sb.append(hexDigit(Int32((code >> 4) & 0xF)))
                sb.append(hexDigit(Int32(code & 0xF)))
            } else {
                sb.append(ch)
            }
        }
        sb.append('"')
        return sb.toString()
    }

    private static func hexDigit(n: Int32): String {
        if (n < 10) {
            return "${Int64(n)}"
        }
        let chars = "ABCDEF"
        "${chars[Int64(n - 10)]}"
    }

    /// 查找 JSON 字符串值的起始位置 (跳过冒号和空格)
    private static func findStringValueStart(json: String, from: Int64): Int64 {
        var i = from
        // 跳过冒号和空格
        while (i < json.size) {
            let ch = json[i]
            if (ch == ':' || ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
                i += 1
            } else if (ch == '"') {
                return i
            } else {
                return -1
            }
        }
        return -1
    }

    /// 从 JSON 中提取字符串数组
    private static func extractStringArray(json: String, from: Int64,
                                           result: ArrayList<String>): Unit {
        var i = from
        // 跳过冒号和空格
        while (i < json.size && (json[i] == ':' || json[i] == ' ' ||
               json[i] == '\t' || json[i] == '\n' || json[i] == '\r')) {
            i += 1
        }
        // 检查 '['
        if (i >= json.size || json[i] != '[') {
            return
        }
        i += 1

        // 解析数组元素
        while (i < json.size) {
            // 跳过空格和逗号
            while (i < json.size && (json[i] == ' ' || json[i] == ',' ||
                   json[i] == '\t' || json[i] == '\n' || json[i] == '\r')) {
                i += 1
            }
            if (i >= json.size || json[i] == ']') {
                break
            }
            if (json[i] == '"') {
                // 读取字符串值
                i += 1
                let start = i
                while (i < json.size && json[i] != '"') {
                    if (json[i] == '\\') {
                        i += 1  // 跳过转义字符
                    }
                    i += 1
                }
                result.append(unescapeJSON(json.subString(start, i)))
                i += 1  // 跳过结束引号
            } else {
                break
            }
        }
    }

    /// JSON 字符串反转义
    private static func unescapeJSON(str: String): String {
        let sb = StringBuilder()
        var i = 0
        while (i < str.size) {
            if (str[i] == '\\' && i + 1 < str.size) {
                let next = str[i + 1]
                if (next == '"') { sb.append('"'); i += 2 }
                else if (next == '\\') { sb.append('\\'); i += 2 }
                else if (next == 'n') { sb.append('\n'); i += 2 }
                else if (next == 'r') { sb.append('\r'); i += 2 }
                else if (next == 't') { sb.append('\t'); i += 2 }
                else if (next == '/') { sb.append('/'); i += 2 }
                else if (next == 'u') {
                    // Unicode escape: \uXXXX
                    if (i + 5 < str.size) {
                        let hex = str.subString(i + 2, i + 6)
                        let codePoint = hexToInt(hex)
                        sb.append(Char(Int32(codePoint)))
                        i += 6
                    } else {
                        sb.append(str[i])
                        i += 1
                    }
                } else {
                    sb.append(str[i])
                    i += 1
                }
            } else {
                sb.append(str[i])
                i += 1
            }
        }
        return sb.toString()
    }

    /// Hex 字符串转整数
    private static func hexToInt(hex: String): Int64 {
        var result = 0
        for (i in 0..hex.size) {
            let ch = hex[i]
            let code = Int64(ch.value)
            if (code >= Int64('0') && code <= Int64('9')) {
                result = result * 16 + (code - Int64('0'))
            } else if (code >= Int64('a') && code <= Int64('f')) {
                result = result * 16 + (code - Int64('a') + 10)
            } else if (code >= Int64('A') && code <= Int64('F')) {
                result = result * 16 + (code - Int64('A') + 10)
            }
        }
        return result
    }
}
