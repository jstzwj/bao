// Mapping - SourceMap 映射条目
// 严格翻译自: src/sourcemap/Mapping.zig
//   const Mapping = @This();
//   generated: LineColumnOffset,
//   original: LineColumnOffset,
//   source_index: i32,
//   name_index: i32 = -1,
//   pub fn generatedLine, generatedColumn, sourceIndex,
//          originalLine, originalColumn, nameIndex, parse
package bao_sourcemap

import bao_core.*

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
    //   pub fn add(this: *LineColumnOffset, b: LineColumnOffset) void {
    //       if (b.lines.zeroBased() == 0) {
    //           this.columns = this.columns.add(b.columns);
    //       } else {
    //           this.lines = this.lines.add(b.lines);
    //           this.columns = b.columns;
    //       }
    //   }
    public func add(other: LineColumnOffset): Unit {
        if (other.line == 0) {
            column += other.column
        } else {
            line += other.line
            column = other.column
        }
    }

    /// 增量更新 - 对应 Bun LineColumnOffset.addScalar
    public func addScalar(delta: Int64): Unit {
        // 这里只对 column 操作，因为 lines 的 addScalar 在 Bun 中是通过 Ordinal 实现的
        column += delta
    }

    /// 推进 - 对应 Bun LineColumnOffset.advance
    // 扫描文本内容，更新行号和列号
    // 处理换行符 (\r, \n, \u2028, \u2029) 和 UTF-16 代理对
    public func advance(input: String): Unit {
        var offset = 0
        while (offset < input.size) {
            let ch = input[offset]
            let code = Int64(ch.value)

            if (code >= 14 && code <= 127) {
                // ASCII 快速路径 - 查找下一个换行符或非 ASCII 字符
                var j = offset + 1
                while (j < input.size) {
                    let c = Int64(input[j].value)
                    if (c == '\r'.toUInt8() || c == '\n'.toUInt8() ||
                        c > 127) {
                        break
                    }
                    j += 1
                }
                column += (j - offset)
                offset = j
                continue
            }

            // 处理换行
            if (code == Int64('\r') || code == Int64('\n') ||
                code == 0x2028 || code == 0x2029) {
                // Windows 换行 \r\n
                if (code == Int64('\r') && offset + 1 < input.size &&
                    Int64(input[offset + 1].value) == Int64('\n')) {
                    column += 1
                    offset += 1
                    continue
                }

                line += 1
                column = 0
                offset += 1
                continue
            }

            // Mozilla 的 "source-map" 库使用 UTF-16 代码单元计数列
            if (code > 0xFFFF) {
                column += 2
            } else {
                column += 1
            }
            offset += 1
        }
    }

    /// 重置
    public func reset(): Unit {
        line = 0
        column = 0
    }

    /// 比较先后 - 对应 Bun LineColumnOffset.comesBefore
    //   pub fn comesBefore(a: LineColumnOffset, b: LineColumnOffset) bool {
    //       return a.lines.zeroBased() < b.lines.zeroBased() or
    //              (a.lines.zeroBased() == b.lines.zeroBased() and
    //               a.columns.zeroBased() < b.columns.zeroBased());
    //   }
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

    public init(generated: LineColumnOffset, original: LineColumnOffset,
                sourceIndex: Int64, nameIndex: Int64) {
        this.generated = generated
        this.original = original
        this.sourceIndex = sourceIndex
        this.nameIndex = nameIndex
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
// MappingWithoutName - 无名称的映射条目
// 严格翻译自: Mapping.zig - MappingWithoutName
//   pub const MappingWithoutName = struct {
//       generated: LineColumnOffset,
//       original: LineColumnOffset,
//       source_index: i32,
//       pub fn toNamed(this: *const MappingWithoutName) Mapping
//   };
// ============================================================================

/// 无名称的映射条目 - 对应 Bun Mapping.MappingWithoutName
/// 优化: 不需要 "names" 列时可以节省内存
public class MappingWithoutName {
    public var generated: LineColumnOffset
    public var original: LineColumnOffset
    public var sourceIndex: Int64

    public init() {
        generated = LineColumnOffset()
        original = LineColumnOffset()
        sourceIndex = 0
    }

    public init(generated: LineColumnOffset, original: LineColumnOffset,
                sourceIndex: Int64) {
        this.generated = generated
        this.original = original
        this.sourceIndex = sourceIndex
    }

    /// 转换为带名称的映射 - 对应 Bun MappingWithoutName.toNamed
    public func toNamed(): SourceMapping {
        SourceMapping(generated, original, sourceIndex, -1)
    }
}

// ============================================================================
// ParseResult - 解析结果
// 严格翻译自: sourcemap.zig - ParseResult
//   pub const ParseResult = union(enum) {
//       fail: struct { loc, err, value, msg },
//       success: ParsedSourceMap,
//   };
// ============================================================================

/// 映射解析错误类型
public enum ParseErrorKind {
    /// 内存不足
    OutOfMemory
    /// 缺少生成列值
    MissingGeneratedColumnValue
    /// 无效的生成列值
    InvalidGeneratedColumnValue
    /// 无效的源文件索引增量
    InvalidSourceIndexDelta
    /// 无效的源文件索引值
    InvalidSourceIndexValue
    /// 缺少原始行
    MissingOriginalLine
    /// 无效的原始行值
    InvalidOriginalLineValue
    /// 缺少原始列值
    MissingOriginalColumnValue
    /// 无效的原始列值
    InvalidOriginalColumnValue
    /// 无效的名称索引增量
    InvalidNameIndexDelta
}

/// 映射解析失败详情
public class ParseFailure {
    public var errorKind: ParseErrorKind
    public var msg: String
    public var value: Int64
    /// 在 mappings 字符串中的偏移位置
    public var loc: Int64

    public init(errorKind: ParseErrorKind, msg: String, value: Int64,
                loc: Int64) {
        this.errorKind = errorKind
        this.msg = msg
        this.value = value
        this.loc = loc
    }

    public init(errorKind: ParseErrorKind, msg: String) {
        this.errorKind = errorKind
        this.msg = msg
        this.value = 0
        this.loc = 0
    }
}

// ============================================================================
// SourceMapState - SourceMap 状态
// 严格翻译自: sourcemap.zig - SourceMapState
//   pub const SourceMapState = struct {
//       generated_line: i32 = 0,
//       generated_column: i32 = 0,
//       source_index: i32 = 0,
//       original_line: i32 = 0,
//       original_column: i32 = 0,
//   };
// ============================================================================

/// SourceMap 状态 - 用于增量编码
/// Coordinates in source maps are stored using relative offsets for size
/// reasons. When joining together chunks of a source map that were emitted
/// in parallel for different parts of a file, we need to fix up the first
/// segment of each chunk to be relative to the end of the previous chunk.
public class SourceMapState {
    /// 生成的行号 (不存储在 source map 中，仅用于 bundler 合并)
    public var generatedLine: Int64
    /// 生成的列号 (存储在 source map 的 VLQ 格式中)
    public var generatedColumn: Int64
    /// 源文件索引
    public var sourceIndex: Int64
    /// 原始行号
    public var originalLine: Int64
    /// 原始列号
    public var originalColumn: Int64

    public init() {
        generatedLine = 0
        generatedColumn = 0
        sourceIndex = 0
        originalLine = 0
        originalColumn = 0
    }

    public init(generatedLine: Int64, generatedColumn: Int64,
                sourceIndex: Int64, originalLine: Int64,
                originalColumn: Int64) {
        this.generatedLine = generatedLine
        this.generatedColumn = generatedColumn
        this.sourceIndex = sourceIndex
        this.originalLine = originalLine
        this.originalColumn = originalColumn
    }

    /// 复制状态
    public func copy(): SourceMapState {
        SourceMapState(generatedLine, generatedColumn, sourceIndex,
            originalLine, originalColumn)
    }
}

// ============================================================================
// MappingList - 映射列表
// 严格翻译自: Mapping.zig - Mapping.List
//   pub const List = struct {
//       impl: Value = .{ .without_names = .{} },
//       names: []const bun.Semver.String = &[_]bun.Semver.String{},
//       names_buffer: bun.ByteList = .{},
//       pub fn find, findIndex, append, sort, generated, original, sourceIndex
//   };
// ============================================================================

/// 映射列表 - 对应 Bun Mapping.List
/// 简化为单一数组存储 (仓颉中不需要 MultiArrayList 优化)
public class MappingList {
    /// 映射数组
    private var mappings: ArrayList<SourceMapping>
    /// 名称列表 - 对应 Bun Mapping.List.names
    private var names: ArrayList<String>

    public init() {
        mappings = ArrayList<SourceMapping>()
        names = ArrayList<String>()
    }

    /// 映射数量
    public func size(): Int64 {
        mappings.size
    }

    /// 添加映射 - 对应 Bun Mapping.List.append
    public func append(mapping: SourceMapping): Unit {
        mappings.append(mapping)
    }

    /// 添加名称 - 对应 Bun Mapping.List.names
    public func appendName(name: String): Unit {
        names.append(name)
    }

    /// 获取名称 - 对应 Bun Mapping.List.getName
    public func getName(index: Int64): ?String {
        if (index < 0 || index >= names.size) {
            return None
        }
        return Some(names[index])
    }

    /// 获取所有映射
    public func getMappings(): ArrayList<SourceMapping> {
        mappings
    }

    /// 获取所有名称
    public func getNames(): ArrayList<String> {
        names
    }

    /// 获取 generated 位置列表
    public func generated(): Array<LineColumnOffset> {
        var result = Array<LineColumnOffset>()
        for (i in 0..mappings.size) {
            result.append(mappings[i].generated)
        }
        return result
    }

    /// 获取 original 位置列表
    public func original(): Array<LineColumnOffset> {
        var result = Array<LineColumnOffset>()
        for (i in 0..mappings.size) {
            result.append(mappings[i].original)
        }
        return result
    }

    /// 获取源文件索引列表
    public func sourceIndex(): Array<Int64> {
        var result = Array<Int64>()
        for (i in 0..mappings.size) {
            result.append(mappings[i].sourceIndex)
        }
        return result
    }

    // ========================================================================
    // findIndexFromGenerated - 从 generated 位置查找索引
    // 严格翻译自: Mapping.zig - List.findIndexFromGenerated
    //   fn findIndexFromGenerated(line_column_offsets: []const LineColumnOffset,
    //       line: bun.Ordinal, column: bun.Ordinal) ?usize {
    //       var count = line_column_offsets.len;
    //       var index: usize = 0;
    //       while (count > 0) {
    //           const step = count / 2;
    //           const i: usize = index + step;
    //           if (mapping.lines < line || (mapping.lines == line && mapping.columns <= column)) {
    //               index = i + 1;
    //               count -= step + 1;
    //           } else { count = step; }
    //       }
    //       if (index > 0 && offsets[index-1].lines == line) return index - 1;
    //   }
    // ========================================================================

    /// 从 generated 位置查找索引 - 二分查找
    /// 找到 generated 位置 <= (line, column) 的最后一个映射
    public func findIndexFromGenerated(line: Int64, column: Int64): ?Int64 {
        var count = mappings.size
        var index = 0

        while (count > 0) {
            let step = count / 2
            let i = index + step
            let mapping = mappings[i]

            if (mapping.generated.line < line ||
                (mapping.generated.line == line &&
                 mapping.generated.column <= column)) {
                index = i + 1
                count = count - step - 1
            } else {
                count = step
            }
        }

        if (index > 0) {
            let found = mappings[index - 1]
            if (found.generated.line == line) {
                return index - 1
            }
        }

        return None
    }

    /// 查找索引 - 对应 Bun Mapping.List.findIndex
    public func findIndex(line: Int64, column: Int64): ?Int64 {
        findIndexFromGenerated(line, column)
    }

    // ========================================================================
    // find - 查找映射
    // 严格翻译自: Mapping.zig - List.find
    //   pub fn find(this: *const List, line: bun.Ordinal, column: bun.Ordinal) ?Mapping {
    //       switch (this.impl) {
    //           inline else => |*list, tag| {
    //               if (findIndexFromGenerated(list.items(.generated), line, column)) |i| {
    //                   return list.get(i); // or .toNamed()
    //               }
    //           },
    //       }
    //       return null;
    //   }
    // ========================================================================

    /// 查找映射 - 给定 generated 位置，返回对应的映射
    /// 使用二分查找定位 <= (line, column) 的最后一个映射
    public func find(line: Int64, column: Int64): ?SourceMapping {
        let idx = findIndexFromGenerated(line, column)
        if (idx != None) {
            return Some(mappings[idx.getOrThrow()])
        }
        return None
    }

    // ========================================================================
    // sort - 排序映射
    // 严格翻译自: Mapping.zig - List.sort
    //   pub fn sort(this: *List) void {
    //       const SortContext = struct {
    //           generated: []const LineColumnOffset,
    //           pub fn lessThan(ctx, a_index, b_index) bool { ... }
    //       };
    //   }
    // ========================================================================

    /// 按 generated 位置排序
    public func sort(): Unit {
        // 简单插入排序 (对应 Bun 的 sort with SortContext)
        if (mappings.size <= 1) {
            return
        }

        let arr = mappings.toArray()
        for (i in 1..arr.size) {
            let key = arr[i]
            var j = i - 1

            // 找到 key 应该插入的位置
            while (j >= 0) {
                let a = arr[j]
                // 比较逻辑 - 对应 Bun SortContext.lessThan
                var shouldSwap = false
                if (a.generated.line != key.generated.line) {
                    shouldSwap = a.generated.line > key.generated.line
                } else if (a.generated.column != key.generated.column) {
                    shouldSwap = a.generated.column > key.generated.column
                } else {
                    shouldSwap = false
                }

                if (shouldSwap) {
                    arr[j + 1] = arr[j]
                    j -= 1
                } else {
                    break
                }
            }
            arr[j + 1] = key
        }

        // 重建 mappings
        mappings = ArrayList<SourceMapping>()
        for (i in 0..arr.size) {
            mappings.append(arr[i])
        }
    }

    /// 内存占用估算 - 对应 Bun Mapping.List.memoryCost
    public func memoryCost(): Int64 {
        mappings.size * 48 + names.size * 16  // 估算值
    }
}

// ============================================================================
// Mapping 解析函数
// 严格翻译自: Mapping.zig - Mapping.parse
//   pub fn parse(allocator, bytes, estimated_mapping_count, sources_count,
//                input_line_count, options) ParseResult { ... }
// ============================================================================

/// 解析选项 - 对应 Bun Mapping.parse 的 options 参数
public class ParseOptions {
    public var allowNames: Bool
    public var sort: Bool

    public init() {
        allowNames = false
        sort = false
    }

    public init(allowNames: Bool, sort: Bool) {
        this.allowNames = allowNames
        this.sort = sort
    }
}

/// 解析结果 - 对应 Bun ParseResult
public class MappingParseResult {
    public var mappings: MappingList
    public var inputLineCount: Int64

    public init(mappings: MappingList, inputLineCount: Int64) {
        this.mappings = mappings
        this.inputLineCount = inputLineCount
    }
}

/// Mapping 解析工具
public class MappingParser {
    // ========================================================================
    // parse - 解析 mappings 字符串
    // 严格翻译自: Mapping.zig - Mapping.parse
    //
    // mappings 编码格式:
    //   - ';' 分隔行 (每行对应生成代码的一行)
    //   - ',' 分隔同一行的映射
    //   - 每个映射包含 1/4/5 个 VLQ 值:
    //     1. 生成列 (增量)
    //     2. 源文件索引 (增量)
    //     3. 原始行 (增量)
    //     4. 原始列 (增量)
    //     5. 名称索引 (增量, 可选)
    // ========================================================================

    /// 解析 mappings 字符串
    /// 严格翻译自 Bun Mapping.parse
    public static func parse(bytes: String, sourceCount: Int64,
                             inputLineCount: Int64,
                             options: ParseOptions): MappingParseResult {
        let mapping = MappingList()

        // 运行状态 - 对应 Bun Mapping.parse 中的局部变量
        var generated = LineColumnOffset()
        var original = LineColumnOffset()
        var nameIndex = 0
        var sourceIndex = 0
        var needsSort = false

        var remain = bytes
        var byteOffset = 0  // 用于错误定位

        while (remain.size > 0) {
            let ch = remain[0]

            // ';' -> 新行
            // Bun: if (remain[0] == ';') {
            //          generated.columns = bun.Ordinal.start;
            //          while (remain.len > 0 and remain[0] == ';') {
            //              generated.lines = generated.lines.addScalar(1);
            //              remain = remain[1..];
            //          }
            if (ch == ';') {
                generated.column = 0

                // 批量处理连续的分号 - 对应 Bun 的 hasPrefixComptime 优化
                while (remain.size > 0 && remain[0] == ';') {
                    generated.line += 1
                    remain = remain.subString(1)
                    byteOffset += 1
                }

                if (remain.size == 0) {
                    break
                }
                continue
            }

            // 读取生成列增量
            // Bun: const generated_column_delta = decodeVLQ(remain, 0);
            let colResult = VLQ.decode(remain, 0)
            if (colResult.start == 0) {
                // 解码失败
                // Bun: return fail{ .msg = "Missing generated column value", ... }
                return MappingParseResult(mapping, inputLineCount)
            }

            needsSort = needsSort || (colResult.value < 0)
            generated.column += colResult.value

            if (generated.column < 0) {
                // Bun: return fail{ .msg = "Invalid generated column value", ... }
                return MappingParseResult(mapping, inputLineCount)
            }

            remain = remain.subString(colResult.start)
            byteOffset += colResult.start

            // 根据 Bun: if (remain.len == 0) break;
            // 只有 1 个字段 -> 无原始位置信息，跳过
            if (remain.size == 0) {
                break
            }

            // 检查下一个字符
            let nextCh = remain[0]
            if (nextCh == ',') {
                remain = remain.subString(1)
                byteOffset += 1
                continue
            }
            if (nextCh == ';') {
                continue
            }

            // 读取源文件索引增量
            let srcResult = VLQ.decode(remain, 0)
            if (srcResult.start == 0) {
                return MappingParseResult(mapping, inputLineCount)
            }
            sourceIndex += srcResult.value

            // Bun: if (source_index < 0 or source_index >= sources_count) { ... }
            if (sourceIndex < 0 || (sourceCount < Int64.MAX_VALUE &&
                                     sourceIndex >= sourceCount)) {
                return MappingParseResult(mapping, inputLineCount)
            }
            remain = remain.subString(srcResult.start)
            byteOffset += srcResult.start

            // 读取原始行增量
            let lineResult = VLQ.decode(remain, 0)
            if (lineResult.start == 0) {
                return MappingParseResult(mapping, inputLineCount)
            }
            original.line += lineResult.value

            if (original.line < 0) {
                return MappingParseResult(mapping, inputLineCount)
            }
            remain = remain.subString(lineResult.start)
            byteOffset += lineResult.start

            // 读取原始列增量
            let colOrigResult = VLQ.decode(remain, 0)
            if (colOrigResult.start == 0) {
                return MappingParseResult(mapping, inputLineCount)
            }
            original.column += colOrigResult.value

            if (original.column < 0) {
                return MappingParseResult(mapping, inputLineCount)
            }
            remain = remain.subString(colOrigResult.start)
            byteOffset += colOrigResult.start

            // 可选: 读取名称索引增量 (第 5 个字段)
            var mapNameIdx = -1
            if (remain.size > 0) {
                let afterCh = remain[0]
                if (afterCh != ',' && afterCh != ';') {
                    // 第 5 个字段: 名称索引
                    let nameResult = VLQ.decode(remain, 0)
                    if (nameResult.start == 0) {
                        return MappingParseResult(mapping, inputLineCount)
                    }
                    remain = remain.subString(nameResult.start)
                    byteOffset += nameResult.start

                    if (options.allowNames) {
                        nameIndex += nameResult.value
                        mapNameIdx = nameIndex
                    }

                    // 处理后续的分隔符
                    if (remain.size > 0 && remain[0] == ',') {
                        remain = remain.subString(1)
                        byteOffset += 1
                    }
                } else if (afterCh == ',') {
                    remain = remain.subString(1)
                    byteOffset += 1
                }
            }

            // 创建映射条目
            mapping.append(SourceMapping(
                generated.line, generated.column, sourceIndex,
                original.line, original.column, mapNameIdx
            ))
        }

        // 对应 Bun: if (needs_sort and options.sort) { mapping.sort(); }
        if (needsSort && options.sort) {
            mapping.sort()
        }

        return MappingParseResult(mapping, inputLineCount)
    }

    /// 简化的 mappings 解析 (不要求排序和名称)
    public static func parseMappings(mappings: String,
                                     sourceCount: Int64): ArrayList<SourceMapping> {
        let opts = ParseOptions(allowNames: true, sort: false)
        let result = parse(mappings, sourceCount, 0, opts)
        return result.mappings.getMappings()
    }
}
