// ParsedSourceMap - 解析后的 SourceMap
// 严格翻译自: src/sourcemap/ParsedSourceMap.zig
//   const ParsedSourceMap = @This();
//   input_line_count: usize = 0,
//   mappings: Mapping.List = .{},
//   external_source_names: []const []const u8 = &.{},
//   is_standalone_module_graph: bool = false,
//   pub fn findMapping, writeVLQs, memoryCost
package bao_sourcemap

import bao_core.*

// ============================================================================
// ParsedSourceMap - 解析后的 SourceMap
// 严格翻译自: ParsedSourceMap.zig
//   const ParsedSourceMap = @This();
//   ref_count: RefCount,
//   input_line_count: usize = 0,
//   mappings: Mapping.List = .{},
//   internal: ?InternalSourceMap = null,
//   external_source_names: []const []const u8 = &.{},
//   underlying_provider: SourceContentPtr = .none,
//   is_standalone_module_graph: bool = false,
// ============================================================================

/// 解析后的 SourceMap - 对应 Bun ParsedSourceMap
/// ParsedSourceMap can be acquired by different threads via the thread-safe
/// source map store (SavedSourceMap), so the reference count must be thread-safe.
public class ParsedSourceMap {
    /// 输入源代码的行数
    public var inputLineCount: Int64
    /// 映射列表 - 对应 Bun mappings: Mapping.List
    public var mappings: MappingList
    /// 外部源文件名列表 - 对应 Bun external_source_names
    /// If this is empty, this implies that the source code is a single file
    /// transpiled on-demand. If there are items, then it means this is a file
    /// loaded without transpilation but with external sources.
    public var externalSourceNames: ArrayList<String>
    /// 是否为独立模块图 - 对应 Bun is_standalone_module_graph
    public var isStandaloneModuleGraph: Bool

    public init() {
        inputLineCount = 0
        mappings = MappingList()
        externalSourceNames = ArrayList<String>()
        isStandaloneModuleGraph = false
    }

    public init(inputLineCount: Int64, mappings: MappingList) {
        this.inputLineCount = inputLineCount
        this.mappings = mappings
        this.externalSourceNames = ArrayList<String>()
        this.isStandaloneModuleGraph = false
    }

    // ========================================================================
    // isExternal - 判断是否有外部源文件
    // 严格翻译自: ParsedSourceMap.zig
    //   pub fn isExternal(psm: *ParsedSourceMap) bool {
    //       return psm.external_source_names.len != 0;
    //   }
    // ========================================================================

    /// 判断是否有外部源文件 - 对应 Bun ParsedSourceMap.isExternal
    public func isExternal(): Bool {
        externalSourceNames.size > 0
    }

    // ========================================================================
    // findMapping - 查找映射
    // 严格翻译自: ParsedSourceMap.zig
    //   pub fn findMapping(this: *const ParsedSourceMap,
    //                      line: bun.Ordinal,
    //                      column: bun.Ordinal) ?Mapping {
    //       return this.mappings.find(line, column);
    //   }
    // ========================================================================

    /// 查找映射 - 给定生成的行和列，查找对应的原始映射
    /// 使用二分查找，返回 generated 位置 <= (line, column) 的最后一个映射
    /// 对应 Bun ParsedSourceMap.findMapping
    public func findMapping(line: Int64, column: Int64): ?SourceMapping {
        mappings.find(line, column)
    }

    // ========================================================================
    // memoryCost - 内存占用估算
    // 严格翻译自: ParsedSourceMap.zig
    //   pub fn memoryCost(this: *const ParsedSourceMap) usize {
    //       const mappings_cost = this.mappings.memoryCost();
    //       return @sizeOf(ParsedSourceMap) + mappings_cost +
    //              this.external_source_names.len * @sizeOf([]const u8);
    //   }
    // ========================================================================

    /// 内存占用估算 - 对应 Bun ParsedSourceMap.memoryCost
    public func memoryCost(): Int64 {
        let mappingsCost = mappings.memoryCost()
        let namesCost = externalSourceNames.size * 16
        return 64 + mappingsCost + namesCost
    }

    // ========================================================================
    // writeVLQs - 将映射编码为 VLQ 字符串
    // 严格翻译自: ParsedSourceMap.zig
    //   pub fn writeVLQs(map: *const ParsedSourceMap, writer: anytype) !void {
    //       var last_col: i32 = 0;
    //       var last_src: i32 = 0;
    //       var last_ol: i32 = 0;
    //       var last_oc: i32 = 0;
    //       var current_line: i32 = 0;
    //       for (map.mappings.generated(),
    //            map.mappings.original(),
    //            map.mappings.sourceIndex(), 0..) |
    //            gen, orig, source_index, i | {
    //           if (current_line != gen.lines.zeroBased()) {
    //               const inc = gen.lines.zeroBased() - current_line;
    //               try writer.splatByteAll(';', @intCast(inc));
    //               current_line = gen.lines.zeroBased();
    //               last_col = 0;
    //           } else if (i != 0) {
    //               try writer.writeByte(',');
    //           }
    //           try VLQ.encode(gen.columns.zeroBased() - last_col).writeTo(writer);
    //           last_col = gen.columns.zeroBased();
    //           try VLQ.encode(source_index - last_src).writeTo(writer);
    //           last_src = source_index;
    //           try VLQ.encode(orig.lines.zeroBased() - last_ol).writeTo(writer);
    //           last_ol = orig.lines.zeroBased();
    //           try VLQ.encode(orig.columns.zeroBased() - last_oc).writeTo(writer);
    //           last_oc = orig.columns.zeroBased();
    //       }
    //   }
    // ========================================================================

    /// 将映射编码为 VLQ "mappings" 字符串
    /// 对应 Bun ParsedSourceMap.writeVLQs
    /// 编码规则: 使用增量编码，行用 ';' 分隔，同一行的映射用 ',' 分隔
    public func writeVLQs(): String {
        let sb = StringBuilder()
        let genList = mappings.generated()
        let origList = mappings.original()
        let srcIdxList = mappings.sourceIndex()

        var lastCol: Int64 = 0
        var lastSrc: Int64 = 0
        var lastOL: Int64 = 0
        var lastOC: Int64 = 0
        var currentLine: Int64 = 0

        let mSize = mappings.size()
        for (i in 0..mSize) {
            let gen = genList[i]
            let orig = origList[i]
            let srcIdx = srcIdxList[i]

            // 行分隔
            if (currentLine != gen.line) {
                let inc = gen.line - currentLine
                // 写入 inc 个 ';'
                for (_ in 0..inc) {
                    sb.append(';')
                }
                currentLine = gen.line
                lastCol = 0
            } else if (i != 0) {
                sb.append(',')
            }

            // 编码增量值 - 对应 Bun VLQ.encode().writeTo(writer)
            // 生成列增量
            sb.append(VLQ.encode(gen.column - lastCol))
            lastCol = gen.column
            // 源文件索引增量
            sb.append(VLQ.encode(srcIdx - lastSrc))
            lastSrc = srcIdx
            // 原始行增量
            sb.append(VLQ.encode(orig.line - lastOL))
            lastOL = orig.line
            // 原始列增量
            sb.append(VLQ.encode(orig.column - lastOC))
            lastOC = orig.column
        }

        return sb.toString()
    }

    // ========================================================================
    // formatVLQs - 格式化 VLQ 字符串
    // 严格翻译自: ParsedSourceMap.zig
    //   pub fn formatVLQs(map: *const ParsedSourceMap)
    //       std.fmt.Alt(*const ParsedSourceMap, formatVLQsImpl) {
    //       return .{ .data = map };
    //   }
    //   fn formatVLQsImpl(map: *const ParsedSourceMap, w: *std.Io.Writer) !void {
    //       try map.writeVLQs(w);
    //   }
    // ========================================================================

    /// 格式化为 VLQ 字符串
    public func formatVLQs(): String {
        writeVLQs()
    }
}

// ============================================================================
// SourceContentHandling - 源内容处理方式
// 严格翻译自: sourcemap.zig
//   pub const SourceContentHandling = enum(u1) {
//       no_source_contents,
//       source_contents,
//   };
// ============================================================================

/// 源内容处理方式 - 对应 Bun SourceContentHandling
/// For some sourcemap loading code, this enum is used as a hint if it should
/// bother loading source code into memory.
public enum SourceContentHandling {
    | NoSourceContents
    | SourceContents
}

// ============================================================================
// SourceMapLoadHint - SourceMap 加载提示
// 严格翻译自: sourcemap.zig
//   pub const SourceMapLoadHint = enum(u2) {
//       none,
//       is_inline_map,
//       is_external_map,
//   };
// ============================================================================

/// SourceMap 加载提示 - 对应 Bun SourceMapLoadHint
/// For some sourcemap loading code, this enum is used as a hint if we already
/// know if the sourcemap is located on disk or inline in the source code.
public enum SourceMapLoadHint {
    | None
    | IsInlineMap
    | IsExternalMap
}

// ============================================================================
// ParseUrlResultHint - 解析结果提示
// 严格翻译自: sourcemap.zig
//   pub const ParseUrlResultHint = union(enum) {
//       mappings_only,
//       source_only: u32,
//       all: struct { line: i32, column: i32, include_names: bool = false },
//   };
// ============================================================================

/// 解析结果提示 - 对应 Bun ParseUrlResultHint
/// Dictates what parseUrl/parseJSON return.
public enum ParseUrlResultHint {
    | MappingsOnly
    | SourceOnly(UInt32)
    | All(Int64, Int64, Bool)  // line, column, include_names
}

// ============================================================================
// SourceMapParseResult - 解析结果
// 严格翻译自: sourcemap.zig - ParseResult
//   pub const ParseResult = union(enum) {
//       fail: struct { loc: Logger.Loc, err: anyerror, value: i32 = 0, msg: []const u8 = "" },
//       success: ParsedSourceMap,
//   };
// ============================================================================

/// 解析失败详情 - 对应 Bun ParseResult.fail
public class SourceMapParseFailure {
    public var loc: Int64
    public var err: String
    public var value: Int64
    public var msg: String

    public init(loc: Int64, err: String, value: Int64, msg: String) {
        this.loc = loc
        this.err = err
        this.value = value
        this.msg = msg
    }

    public init(msg: String) {
        this.loc = 0
        this.err = ""
        this.value = 0
        this.msg = msg
    }
}

/// SourceMap 解析结果 - 对应 Bun ParseResult
/// union(enum) { fail, success }
public class SourceMapParseResult {
    /// 是否成功
    public var isSuccess: Bool
    /// 解析失败详情
    public var failure: SourceMapParseFailure
    /// 解析成功后的 ParsedSourceMap
    public var map: ParsedSourceMap

    public init(failure: SourceMapParseFailure) {
        isSuccess = false
        this.failure = failure
        this.map = ParsedSourceMap()
    }

    public init(map: ParsedSourceMap) {
        isSuccess = true
        this.failure = SourceMapParseFailure("")
        this.map = map
    }

    /// 创建成功结果
    public static func success(map: ParsedSourceMap): SourceMapParseResult {
        SourceMapParseResult(map)
    }

    /// 创建失败结果
    public static func fail(msg: String): SourceMapParseResult {
        SourceMapParseResult(SourceMapParseFailure(msg))
    }

    public static func fail(loc: Int64, err: String, value: Int64,
                            msg: String): SourceMapParseResult {
        SourceMapParseResult(SourceMapParseFailure(loc, err, value, msg))
    }
}
