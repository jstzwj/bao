// LineOffsetTable - 行偏移表
// 严格翻译自: src/sourcemap/LineOffsetTable.zig
//   const LineOffsetTable = @This();
//   columns_for_non_ascii: BabyList(i32) = .{},
//   byte_offset_to_first_non_ascii: u32 = 0,
//   byte_offset_to_start_of_line: u32 = 0,
//   pub fn findLine, findIndex, generate
package bao_sourcemap

import bao_core.*
import std.collection.*

// ============================================================================
// LineOffsetTable - 行偏移表
// 严格翻译自: LineOffsetTable.zig
//   const LineOffsetTable = @This();
//   columns_for_non_ascii: BabyList(i32) = .{},
//   byte_offset_to_first_non_ascii: u32 = 0,
//   byte_offset_to_start_of_line: u32 = 0,
//
// The source map specification is very loose and does not specify what
// column numbers actually mean. The popular "source-map" library from Mozilla
// appears to interpret them as counts of UTF-16 code units, so we generate
// those too for compatibility.
//
// We keep mapping tables around to accelerate conversion from byte offsets
// to UTF-16 code unit counts. However, this mapping takes up a lot of memory.
// Since most JavaScript is ASCII and the mapping for ASCII is 1:1, we avoid
// creating a table for ASCII-only lines as an optimization.
// ============================================================================

/// 行偏移表 - 对应 Bun LineOffsetTable
/// 用于加速从字节偏移到 UTF-16 代码单元计数的转换
public class LineOffsetTable {
    /// 非 ASCII 字符的列偏移映射
    /// 当一行只包含 ASCII 字符时，此数组为空 (1:1 映射)
    public var columnsForNonAscii: ArrayList<Int64>
    /// 第一个非 ASCII 字符的字节偏移
    public var byteOffsetToFirstNonAscii: Int64
    /// 行首的字节偏移
    public var byteOffsetToStartOfLine: Int64

    public init() {
        columnsForNonAscii = ArrayList<Int64>()
        byteOffsetToFirstNonAscii = 0
        byteOffsetToStartOfLine = 0
    }

    public init(columnsForNonAscii: ArrayList<Int64>,
                byteOffsetToFirstNonAscii: Int64,
                byteOffsetToStartOfLine: Int64) {
        this.columnsForNonAscii = columnsForNonAscii
        this.byteOffsetToFirstNonAscii = byteOffsetToFirstNonAscii
        this.byteOffsetToStartOfLine = byteOffsetToStartOfLine
    }
}

// ============================================================================
// LineOffsetTableList - 行偏移表列表
// 严格翻译自: LineOffsetTable.zig 的 generate 函数返回的 List
//   pub const List = bun.MultiArrayList(LineOffsetTable);
// ============================================================================

/// 行偏移表列表
public class LineOffsetTableList {
    private var tables: ArrayList<LineOffsetTable>
    /// 每行的起始字节偏移 - 对应 Bun line_offset_table_byte_offset_list
    private var byteOffsetList: ArrayList<Int64>

    public init() {
        tables = ArrayList<LineOffsetTable>()
        byteOffsetList = ArrayList<Int64>()
    }

    /// 获取表数量
    public func size(): Int64 {
        tables.size
    }

    /// 获取指定索引的表
    public func get(index: Int64): LineOffsetTable {
        tables[index]
    }

    /// 获取字节偏移列表
    public func getByteOffsetList(): Array<Int64> {
        byteOffsetList.toArray()
    }

    /// 获取所有表
    public func getTables(): ArrayList<LineOffsetTable> {
        tables
    }

    // ========================================================================
    // findLine - 通过字节偏移查找行号
    // 严格翻译自: LineOffsetTable.zig - findLine
    //   pub fn findLine(byte_offsets_to_start_of_line: []const u32,
    //                   loc: Logger.Loc) i32 {
    //       assert(loc.start > -1);
    //       var original_line: usize = 0;
    //       const loc_start = @as(usize, @intCast(loc.start));
    //       {
    //           var count = @as(usize, @truncate(byte_offsets_to_start_of_line.len));
    //           var i: usize = 0;
    //           while (count > 0) {
    //               const step = count / 2;
    //               i = original_line + step;
    //               if (byte_offsets_to_start_of_line[i] <= loc_start) {
    //                   original_line = i + 1;
    //                   count = count - step - 1;
    //               } else { count = step; }
    //           }
    //       }
    //       return @as(i32, @intCast(original_line)) - 1;
    //   }
    // ========================================================================

    /// 通过字节偏移查找行号 - 二分查找
    /// 对应 Bun LineOffsetTable.findLine
    public static func findLine(byteOffsetsToStartOfLine: Array<Int64>,
                                loc: Int64): Int64 {
        if (loc < 0) {
            return 0
        }

        var originalLine = 0
        var count = byteOffsetsToStartOfLine.size
        var index = 0

        while (count > 0) {
            let step = count / 2
            let i = index + step
            if (byteOffsetsToStartOfLine[i] <= loc) {
                index = i + 1
                count = count - step - 1
            } else {
                count = step
            }
        }

        return index - 1
    }

    // ========================================================================
    // findIndex - 通过字节偏移查找精确索引
    // 严格翻译自: LineOffsetTable.zig - findIndex
    //   pub fn findIndex(byte_offsets_to_start_of_line: []const u32,
    //                    loc: Logger.Loc) ?usize {
    //       var count = ...; var i: usize = 0;
    //       while (count > 0) {
    //           const step = count / 2;
    //           i = original_line + step;
    //           if (byte_offset == loc_start) return i;
    //           if (i + 1 < len and byte_offset < loc_start < next)
    //               return i;
    //           // binary search...
    //       }
    //       return null;
    //   }
    // ========================================================================

    /// 通过字节偏移查找精确索引 - 二分查找
    /// 对应 Bun LineOffsetTable.findIndex
    public static func findIndex(byteOffsetsToStartOfLine: Array<Int64>,
                                 loc: Int64): ?Int64 {
        if (loc < 0) {
            return None
        }

        var count = byteOffsetsToStartOfLine.size
        var index = 0

        while (count > 0) {
            let step = count / 2
            let i = index + step
            let byteOffset = byteOffsetsToStartOfLine[i]

            if (byteOffset == loc) {
                return i
            }

            // 检查是否在当前行范围内
            if (i + 1 < byteOffsetsToStartOfLine.size) {
                let nextByteOffset = byteOffsetsToStartOfLine[i + 1]
                if (byteOffset < loc && loc < nextByteOffset) {
                    return i
                }
            }

            if (byteOffset < loc) {
                index = i + 1
                count = count - step - 1
            } else {
                count = step
            }
        }

        return None
    }

    // ========================================================================
    // generate - 生成行偏移表
    // 严格翻译自: LineOffsetTable.zig - generate
    //   pub fn generate(allocator, contents: []const u8,
    //                   approximate_line_count: i32) List {
    //       var list = List{};
    //       var column: i32 = 0;
    //       var byte_offset_to_first_non_ascii: u32 = 0;
    //       var column_byte_offset: u32 = 0;
    //       var line_byte_offset: u32 = 0;
    //       // 遍历内容，构建行偏移表
    //   }
    //
    // 核心逻辑:
    //   - 对于纯 ASCII 行: columnsForNonAscii 为空 (1:1 映射)
    //   - 对于含非 ASCII 字符的行: 构建字节偏移 -> 列号的映射
    //   - Mozilla 的 "source-map" 库使用 UTF-16 代码单元计数列
    //   - 处理 \r\n Windows 换行
    //   - 处理 Unicode 行分隔符 (0x2028, 0x2029)
    // ========================================================================

    /// 为给定内容生成行偏移表
    /// 对应 Bun LineOffsetTable.generate
    public static func generate(contents: String,
                                approximateLineCount: Int64): LineOffsetTableList {
        let list = LineOffsetTableList()
        var column = 0
        var byteOffsetToFirstNonAscii = 0
        var columnByteOffset = 0
        var lineByteOffset = 0

        // 非 ASCII 列映射
        var columnsForNonAscii = ArrayList<Int64>()

        var offset = 0
        while (offset < contents.size) {
            let ch = contents[offset]
            let code = Int64(ch)

            // 记录行首字节偏移
            if (column == 0) {
                lineByteOffset = offset
            }

            // 检测非 ASCII 字符
            if (code > 0x7F && columnsForNonAscii.size == 0) {
                // 遇到第一个非 ASCII 字符
                columnsForNonAscii.add(column)
                columnByteOffset = offset - lineByteOffset
                byteOffsetToFirstNonAscii = columnByteOffset
            }

            // 更新非 ASCII 列映射
            if (columnsForNonAscii.size > 0) {
                let lineBytesSoFar = offset - lineByteOffset
                while (columnByteOffset <= lineBytesSoFar) {
                    columnsForNonAscii.add(column)
                    columnByteOffset += 1
                }
            } else if (code > 0x7F) {
                // 跳过 - 只有在遇到非 ASCII 时才记录
            } else if (code >= 14 && code <= 127) {
                // ASCII 快速路径 - 跳到下一个换行符或非 ASCII
                var j = offset + 1
                while (j < contents.size) {
                    let c = Int64(contents[j])
                    if (c == Int64(0x0D) || c == Int64(0x0A) || c > 127) {
                        break
                    }
                    j += 1
                }
                column += (j - offset)
                offset = j
                continue
            }

            // 处理换行
            if (code == Int64(0x0D) || code == Int64(0x0A) ||
                code == 0x2028 || code == 0x2029) {
                // Windows 换行 \r\n
                if (code == Int64(0x0D) && offset + 1 < contents.size &&
                    Int64(contents[offset + 1]) == Int64(0x0A)) {
                    column += 1
                    offset += 1
                    offset += 1
                    continue
                }

                // 添加行偏移表条目
                let table = LineOffsetTable(
                    columnsForNonAscii,
                    byteOffsetToFirstNonAscii,
                    lineByteOffset
                )
                list.tables.add(table)
                list.byteOffsetList.add(lineByteOffset)

                // 重置状态
                column = 0
                byteOffsetToFirstNonAscii = 0
                columnByteOffset = 0
                lineByteOffset = 0
                columnsForNonAscii = ArrayList<Int64>()

                offset += 1
                continue
            }

            // Mozilla 的 "source-map" 库使用 UTF-16 代码单元计数列
            // 对应 Bun: column += @as(i32, @intFromBool(c > 0xFFFF)) + 1
            if (code > 0xFFFF) {
                column += 2
            } else {
                column += 1
            }

            offset += 1
        }

        // 最后一行
        if (column == 0) {
            lineByteOffset = contents.size
        }

        if (columnsForNonAscii.size > 0) {
            let lineBytesSoFar = contents.size - lineByteOffset
            while (columnByteOffset <= lineBytesSoFar) {
                columnsForNonAscii.add(column)
                columnByteOffset += 1
            }
        }

        let lastTable = LineOffsetTable(
            columnsForNonAscii,
            byteOffsetToFirstNonAscii,
            lineByteOffset
        )
        list.tables.add(lastTable)
        list.byteOffsetList.add(lineByteOffset)

        return list
    }
}
