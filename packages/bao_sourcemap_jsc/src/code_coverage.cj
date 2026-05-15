// 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig
//! Code coverage tracking for source maps.
//! Tracks which lines, statements, and functions have been executed.
package bao_sourcemap_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// LinesHits - 行命中计数列表
// 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig:1
//   const LinesHits = bun.collections.BabyList(u32);
// ============================================================================

/// 行命中计数列表 - 严格对应 Bun LinesHits (BabyList(u32))
public class LinesHits {
    public var items: Array<UInt32>

    public init() {
        items = []
    }

    public init(items: Array<UInt32>) {
        this.items = items
    }

    /// 获取切片 - 严格对应 bun.collections.BabyList(u32).slice()
    public func slice(): Array<UInt32> {
        return items
    }

    /// 初始化容量 - 严格对应 BabyList.initCapacity
    public static func initCapacity(alloc: Allocator, capacity: UInt32): LinesHits {
        return LinesHits(items: Array<UInt32>(capacity, item: 0))
    }

    /// 释放资源 - 严格对应 BabyList.deinit
    public func deinit(alloc: Allocator): Unit {
        items = []
    }
}

// ============================================================================
// Bitset - 动态位集合
// 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig:737
//   const Bitset = bun.bit_set.DynamicBitSetUnmanaged;
// ============================================================================

/// 动态位集合 - 严格对应 Bun DynamicBitSetUnmanaged
public class Bitset {
    public var bits: Array<UInt64>
    public var length: UInt32

    public init() {
        bits = []
        length = 0
    }

    public init(bits: Array<UInt64>, length: UInt32) {
        this.bits = bits
        this.length = length
    }

    /// 初始化空位集 - 严格对应 Bitset.initEmpty
    public static func initEmpty(alloc: Allocator, count: UInt32): Bitset {
        let wordCount = (UInt64(count) + 63) / 64
        return Bitset(
            bits: Array<UInt64>(Int64(wordCount), item: 0),
            length: count
        )
    }

    /// 设置位 - 严格对应 Bitset.set
    public func set(index: UInt32): Unit {
        let wordIdx = Int64(index) / 64
        let bitIdx = index % 64
        if (wordIdx < bits.size) {
            bits[wordIdx] = bits[wordIdx] | (UInt64(1) << Int64(bitIdx))
        }
    }

    /// 取消设置位 - 严格对应 Bitset.unset
    public func unset(index: UInt32): Unit {
        let wordIdx = Int64(index) / 64
        let bitIdx = index % 64
        if (wordIdx < bits.size) {
            bits[wordIdx] = bits[wordIdx] & ~(UInt64(1) << Int64(bitIdx))
        }
    }

    /// 切换所有位 - 严格对应 Bitset.toggleAll
    public func toggleAll(): Unit {
        for (i in 0..bits.size) {
            bits[i] = ~bits[i]
        }
    }

    /// 交集 - 严格对应 Bitset.setIntersection
    public func setIntersection(other: Bitset): Unit {
        let minLen = min(bits.size, other.bits.size)
        for (i in 0..<minLen) {
            bits[i] = bits[i] & other.bits[i]
        }
    }

    /// 计数 - 严格对应 Bitset.count
    public func count(): UInt32 {
        var total: UInt32 = 0
        for (word in bits) {
            total += UInt32(popcount(word))
        }
        return total
    }

    /// 克隆 - 严格对应 Bitset.clone
    public func clone(alloc: Allocator): Bitset {
        let clonedBits = Array<UInt64>(bits.size, item: 0)
        for (i in 0..bits.size) {
            clonedBits[i] = bits[i]
        }
        return Bitset(bits: clonedBits, length: length)
    }

    /// 释放 - 严格对应 Bitset.deinit
    public func deinit(alloc: Allocator): Unit {
        bits = []
        length = 0
    }

    /// 迭代器 - 严格对应 Bitset.iterator
    public func iterator(): BitsetIterator {
        return BitsetIterator(bitset: this)
    }

    /// popcount 辅助函数
    private static func popcount(v: UInt64): Int64 {
        var x = v
        x = x - ((x >> 1) & 0x5555555555555555)
        x = (x & 0x3333333333333333) + ((x >> 2) & 0x3333333333333333)
        x = (x + (x >> 4)) & 0x0F0F0F0F0F0F0F0F
        x = x + (x >> 8)
        x = x + (x >> 16)
        x = x + (x >> 32)
        return Int64(x & 0x7F)
    }

    private static func min(a: Int64, b: Int64): Int64 {
        if (a < b) { return a }
        return b
    }
}

/// 位集合迭代器 - 严格对应 Bitset iterator
public class BitsetIterator {
    public var bitset: Bitset
    public var currentWord: UInt64
    public var wordIndex: Int64

    public init(bitset: Bitset) {
        this.bitset = bitset
        this.currentWord = 0
        this.wordIndex = 0
    }

    /// 下一个设置的位 - 严格对应 iterator.next()
    public func next(): ?UInt32 {
        while (true) {
            if (currentWord != 0) {
                let bit = UInt32(Bitset.popcount(currentWord & (~currentWord + 1)) - 1)
                currentWord = currentWord & (currentWord - 1)
                return UInt32(wordIndex * 64) + bit
            }
            if (wordIndex >= bitset.bits.size) {
                return None
            }
            currentWord = bitset.bits[wordIndex]
            wordIndex += 1
        }
    }
}

// ============================================================================
// Block - 覆盖范围块
// 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig:729-732
//   pub const Block = struct {
//       start_line: u32 = 0,
//       end_line: u32 = 0,
//   };
// ============================================================================

/// 覆盖范围块 - 严格对应 Bun Block
public class Block {
    public var startLine: UInt32
    public var endLine: UInt32

    public init() {
        startLine = 0
        endLine = 0
    }

    public init(startLine: UInt32, endLine: UInt32) {
        this.startLine = startLine
        this.endLine = endLine
    }
}

// ============================================================================
// Fraction - 覆盖率阈值
// 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig:719-727
//   pub const Fraction = struct {
//       functions: f64 = 0.9,
//       lines: f64 = 0.9,
//       stmts: f64 = 0.75,
//       failing: bool = false,
//   };
// ============================================================================

/// 覆盖率阈值 - 严格对应 Bun Fraction
public class Fraction {
    public var functions: Float64
    public var lines: Float64
    public var stmts: Float64
    public var failing: Bool

    public init() {
        functions = 0.9
        lines = 0.9
        stmts = 0.75
        failing = false
    }

    public init(functions: Float64, lines: Float64, stmts: Float64, failing: Bool) {
        this.functions = functions
        this.lines = lines
        this.stmts = stmts
        this.failing = failing
    }
}

// ============================================================================
// BasicBlockRange - 基本块范围
// 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig:351-356
//   const BasicBlockRange = extern struct {
//       startOffset: c_int = 0,
//       endOffset: c_int = 0,
//       hasExecuted: bool = false,
//       executionCount: usize = 0,
//   };
// ============================================================================

/// 基本块范围 - 严格对应 Bun BasicBlockRange (extern struct)
@C
public struct BasicBlockRange {
    public var startOffset: Int32
    public var endOffset: Int32
    public var hasExecuted: Bool
    public var executionCount: UIntNative

    public init() {
        startOffset = 0
        endOffset = 0
        hasExecuted = false
        executionCount = 0
    }

    public init(startOffset: Int32, endOffset: Int32, hasExecuted: Bool, executionCount: UIntNative) {
        this.startOffset = startOffset
        this.endOffset = endOffset
        this.hasExecuted = hasExecuted
        this.executionCount = executionCount
    }
}

// ============================================================================
// Report - 代码覆盖率报告
// 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig:17-348
//   pub const Report = struct { ... };
// ============================================================================

/// 代码覆盖率报告 - 严格对应 Bun Report
public class Report {
    public var sourceUrl: ZigStringSlice
    public var executableLines: Bitset
    public var linesWhichHaveExecuted: Bitset
    public var lineHits: LinesHits
    public var functions: Array<Block>
    public var functionsWhichHaveExecuted: Bitset
    public var stmtsWhichHaveExecuted: Bitset
    public var stmts: Array<Block>
    public var totalLines: UInt32

    public init() {
        sourceUrl = ZigStringSlice()
        executableLines = Bitset()
        linesWhichHaveExecuted = Bitset()
        lineHits = LinesHits()
        functions = []
        functionsWhichHaveExecuted = Bitset()
        stmtsWhichHaveExecuted = Bitset()
        stmts = []
        totalLines = 0
    }

    /// 计算行覆盖率比例 - 严格对应 Bun linesCoverageFraction
    /// Zig:
    ///   pub fn linesCoverageFraction(this: *const Report) f64 {
    ///       var intersected = bun.handleOom(this.executable_lines.clone(bun.default_allocator));
    ///       defer intersected.deinit(bun.default_allocator);
    ///       intersected.setIntersection(this.lines_which_have_executed);
    ///       const total_count: f64 = @floatFromInt(this.executable_lines.count());
    ///       if (total_count == 0) return 1.0;
    ///       const intersected_count: f64 = @floatFromInt(intersected.count());
    ///       return (intersected_count / total_count);
    ///   }
    public func linesCoverageFraction(): Float64 {
        var intersected = executableLines.clone(Allocator.default)
        intersected.setIntersection(linesWhichHaveExecuted)

        let totalCount = Float64(executableLines.count())
        if (totalCount == 0.0) {
            return 1.0
        }

        let intersectedCount = Float64(intersected.count())
        return intersectedCount / totalCount
    }

    /// 计算语句覆盖率比例 - 严格对应 Bun stmtsCoverageFraction
    /// Zig:
    ///   pub fn stmtsCoverageFraction(this: *const Report) f64 {
    ///       const total_count: f64 = @floatFromInt(this.stmts.items.len);
    ///       if (total_count == 0) return 1.0;
    ///       return ((@as(f64, @floatFromInt(this.stmts_which_have_executed.count()))) / (total_count));
    ///   }
    public func stmtsCoverageFraction(): Float64 {
        let totalCount = Float64(stmts.size)
        if (totalCount == 0.0) {
            return 1.0
        }
        return Float64(stmtsWhichHaveExecuted.count()) / totalCount
    }

    /// 计算函数覆盖率比例 - 严格对应 Bun functionCoverageFraction
    /// Zig:
    ///   pub fn functionCoverageFraction(this: *const Report) f64 {
    ///       const total_count: f64 = @floatFromInt(this.functions.items.len);
    ///       if (total_count == 0) return 1.0;
    ///       return (@as(f64, @floatFromInt(this.functions_which_have_executed.count())) / total_count);
    ///   }
    public func functionCoverageFraction(): Float64 {
        let totalCount = Float64(functions.size)
        if (totalCount == 0.0) {
            return 1.0
        }
        return Float64(functionsWhichHaveExecuted.count()) / totalCount
    }

    /// 释放资源 - 严格对应 Bun Report.deinit
    /// Zig:
    ///   pub fn deinit(this: *Report, allocator: std.mem.Allocator) void {
    ///       this.executable_lines.deinit(allocator);
    ///       this.lines_which_have_executed.deinit(allocator);
    ///       this.line_hits.deinit(allocator);
    ///       this.functions.deinit(allocator);
    ///       this.stmts.deinit(allocator);
    ///       this.functions_which_have_executed.deinit(allocator);
    ///       this.stmts_which_have_executed.deinit(allocator);
    ///   }
    public func deinit(alloc: Allocator): Unit {
        executableLines.deinit(alloc)
        linesWhichHaveExecuted.deinit(alloc)
        lineHits.deinit(alloc)
        functions = []
        stmts = []
        functionsWhichHaveExecuted.deinit(alloc)
        stmtsWhichHaveExecuted.deinit(alloc)
    }

    // ==========================================================================
    // Report.Text - 文本格式输出
    // 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig:61-208
    // ==========================================================================

    /// 文本格式输出 - 严格对应 Bun Report.Text
    public class Text {
        /// 带值的格式化写入 - 严格对应 Bun writeFormatWithValues
        /// Zig:
        ///   pub fn writeFormatWithValues(
        ///       filename: []const u8,
        ///       max_filename_length: usize,
        ///       vals: Fraction,
        ///       failing: Fraction,
        ///       failed: bool,
        ///       writer: *std.Io.Writer,
        ///       indent_name: bool,
        ///       comptime enable_colors: bool,
        ///   ) !void
        public static func writeFormatWithValues(
            filename: String,
            maxFilenameLength: UIntNative,
            vals: Fraction,
            failing: Fraction,
            failed: Bool,
            writer: IOWriter,
            indentName: Bool,
            enableColors: Bool
        ): Unit {
            if (enableColors) {
                if (failed) {
                    writer.writeAll("\u{1b}[0m\u{1b}[1m\u{1b}[31m")
                } else {
                    writer.writeAll("\u{1b}[0m\u{1b}[1m\u{1b}[32m")
                }
            }

            if (indentName) {
                writer.writeAll(" ")
            }

            writer.writeAll(filename)
            let padding = maxFilenameLength - filename.length + (indentName ? 0 : 1)
            writer.splatByteAll(' ', padding)
            if (enableColors) {
                writer.writeAll("\u{1b}[0m\u{1b}[2m | \u{1b}[0m")
            } else {
                writer.writeAll(" | ")
            }

            if (enableColors) {
                if (vals.functions < failing.functions) {
                    writer.writeAll("\u{1b}[1m\u{1b}[31m")
                } else {
                    writer.writeAll("\u{1b}[1m\u{1b}[32m")
                }
            }

            writer.printFormat("${functions_pct >7.2}", vals.functions * 100.0)
            if (enableColors) {
                writer.writeAll("\u{1b}[0m\u{1b}[2m | \u{1b}[0m")
            } else {
                writer.writeAll(" | ")
            }

            if (enableColors) {
                if (vals.lines < failing.lines) {
                    writer.writeAll("\u{1b}[1m\u{1b}[31m")
                } else {
                    writer.writeAll("\u{1b}[1m\u{1b}[32m")
                }
            }

            writer.printFormat("${lines_pct >7.2}", vals.lines * 100.0)
        }

        /// 格式化报告 - 严格对应 Bun writeFormat
        /// Zig:
        ///   pub fn writeFormat(
        ///       report: *const Report,
        ///       max_filename_length: usize,
        ///       fraction: *Fraction,
        ///       base_path: []const u8,
        ///       writer: *std.Io.Writer,
        ///       comptime enable_colors: bool,
        ///   ) !void
        public static func writeFormat(
            report: Report,
            maxFilenameLength: UIntNative,
            fraction: Fraction,
            basePath: String,
            writer: IOWriter,
            enableColors: Bool
        ): Unit {
            let savedFunctions = fraction.functions
            let savedLines = fraction.lines
            let savedStmts = fraction.stmts

            let fns = report.functionCoverageFraction()
            let lines = report.linesCoverageFraction()
            let stmts = report.stmtsCoverageFraction()
            fraction.functions = fns
            fraction.lines = lines
            fraction.stmts = stmts

            let failed = fns < savedFunctions || lines < savedLines
            fraction.failing = failed

            var filename = report.sourceUrl.slice()
            if (basePath.length > 0) {
                filename = Path.relative(basePath, filename)
            }

            writeFormatWithValues(
                filename,
                maxFilenameLength,
                fraction,
                Fraction(functions: savedFunctions, lines: savedLines, stmts: savedStmts, failing: false),
                failed,
                writer,
                true,
                enableColors
            )

            if (enableColors) {
                writer.writeAll("\u{1b}[0m\u{1b}[2m | \u{1b}[0m")
            } else {
                writer.writeAll(" | ")
            }

            // 找出未被执行的可执行行
            var executableLinesNotExecuted = report.linesWhichHaveExecuted.clone(Allocator.default)
            executableLinesNotExecuted.toggleAll()
            executableLinesNotExecuted.setIntersection(report.executableLines)

            var iter = executableLinesNotExecuted.iterator()
            var startOfLineRange: UIntNative = 0
            var prevLine: UIntNative = 0
            var isFirst = true

            var nextLineOpt = iter.next()
            while (let nextLine = nextLineOpt) {
                if (nextLine == (prevLine + 1)) {
                    prevLine = nextLine
                    nextLineOpt = iter.next()
                    continue
                } else if (isFirst && startOfLineRange == 0 && prevLine == 0) {
                    startOfLineRange = nextLine
                    prevLine = nextLine
                    nextLineOpt = iter.next()
                    continue
                }

                if (isFirst) {
                    isFirst = false
                } else {
                    if (enableColors) {
                        writer.writeAll("\u{1b}[0m\u{1b}[2m,\u{1b}[0m")
                    } else {
                        writer.writeAll(",")
                    }
                }

                if (startOfLineRange == prevLine) {
                    if (enableColors) {
                        writer.printFormat("\u{1b}[31m${d}", startOfLineRange + 1)
                    } else {
                        writer.printFormat("${d}", startOfLineRange + 1)
                    }
                } else {
                    if (enableColors) {
                        writer.printFormat("\u{1b}[31m${d}-${d}", startOfLineRange + 1, prevLine + 1)
                    } else {
                        writer.printFormat("${d}-${d}", startOfLineRange + 1, prevLine + 1)
                    }
                }

                prevLine = nextLine
                startOfLineRange = nextLine
                nextLineOpt = iter.next()
            }

            // 处理最后一个范围
            if (prevLine != startOfLineRange) {
                if (isFirst) {
                    isFirst = false
                } else {
                    if (enableColors) {
                        writer.writeAll("\u{1b}[0m\u{1b}[2m,\u{1b}[0m")
                    } else {
                        writer.writeAll(",")
                    }
                }

                if (startOfLineRange == prevLine) {
                    if (enableColors) {
                        writer.printFormat("\u{1b}[31m${d}", startOfLineRange + 1)
                    } else {
                        writer.printFormat("${d}", startOfLineRange + 1)
                    }
                } else {
                    if (enableColors) {
                        writer.printFormat("\u{1b}[31m${d}-${d}", startOfLineRange + 1, prevLine + 1)
                    } else {
                        writer.printFormat("${d}-${d}", startOfLineRange + 1, prevLine + 1)
                    }
                }
            }
        }
    }

    // ==========================================================================
    // Report.Lcov - Lcov 格式输出
    // 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig:210-262
    // ==========================================================================

    /// Lcov 格式输出 - 严格对应 Bun Report.Lcov
    public class Lcov {
        /// 格式化 Lcov 报告 - 严格对应 Bun Lcov.writeFormat
        /// Zig:
        ///   pub fn writeFormat(
        ///       report: *const Report,
        ///       base_path: []const u8,
        ///       writer: *std.Io.Writer,
        ///   ) !void
        public static func writeFormat(
            report: Report,
            basePath: String,
            writer: IOWriter
        ): Unit {
            var filename = report.sourceUrl.slice()
            if (basePath.length > 0) {
                filename = Path.relative(basePath, filename)
            }

            // TN: test name
            writer.writeAll("TN:\n")

            // SF: Source File path
            writer.printFormat("SF:${s}\n", filename)

            // FNF: functions found
            writer.printFormat("FNF:${d}\n", report.functions.size)

            // FNH: functions hit
            writer.printFormat("FNH:${d}\n", report.functionsWhichHaveExecuted.count())

            // Track all executable lines
            var executableLines = report.executableLines.clone(Allocator.default)
            var iter = executableLines.iterator()
            let lineHitsSlice = report.lineHits.slice()

            var lineOpt = iter.next()
            while (let line = lineOpt) {
                // DA: line number, hit count
                let hitCount: UInt32 = if (Int64(line) < lineHitsSlice.size) { lineHitsSlice[Int64(line)] } else { 0 }
                writer.printFormat("DA:${d},${d}\n", line + 1, hitCount)
                lineOpt = iter.next()
            }

            // LF: lines found
            writer.printFormat("LF:${d}\n", report.executableLines.count())

            // LH: lines hit
            writer.printFormat("LH:${d}\n", report.linesWhichHaveExecuted.count())

            writer.writeAll("end_of_record\n")
        }
    }
}

// ============================================================================
// Generator - 报告生成器
// 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig:288-318
//   const Generator = struct { ... };
// ============================================================================

/// 报告生成器回调结构 - 严格对应 Bun Generator
public class Generator {
    public var allocator: Allocator
    public var byteRangeMapping: ByteRangeMapping
    public var result: ?Report

    public init() {
        allocator = Allocator.default
        byteRangeMapping = ByteRangeMapping()
        result = None
    }

    public init(allocator: Allocator, byteRangeMapping: ByteRangeMapping) {
        this.allocator = allocator
        this.byteRangeMapping = byteRangeMapping
        this.result = None
    }

    /// 生成回调 - 严格对应 Bun Generator.do
    /// Zig:
    ///   pub fn do(
    ///       this: *@This(),
    ///       blocks_ptr: [*]const BasicBlockRange,
    ///       blocks_len: usize,
    ///       function_start_offset: usize,
    ///       ignore_sourcemap: bool,
    ///   ) callconv(.c) void
    public func doGenerate(
        blocksPtr: Array<BasicBlockRange>,
        blocksLen: UIntNative,
        functionStartOffset: UIntNative,
        ignoreSourcemap: Bool
    ): Unit {
        let blocks = blocksPtr[0..Int64(functionStartOffset)]
        var functionBlocks = blocksPtr[Int64(functionStartOffset)..Int64(blocksLen)]
        if (functionBlocks.size > 1) {
            functionBlocks = functionBlocks[1..]
        }

        if (blocks.size == 0) {
            return
        }

        result = byteRangeMapping.generateReportFromBlocks(
            allocator,
            byteRangeMapping.sourceUrl,
            blocks,
            functionBlocks,
            ignoreSourcemap
        )
    }
}

// ============================================================================
// ByteRangeMapping - 字节范围到行号映射
// 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig:358-717
//   pub const ByteRangeMapping = struct { ... };
// ============================================================================

/// 字节范围到行号映射 - 严格对应 Bun ByteRangeMapping
public class ByteRangeMapping {
    public var lineOffsetTable: LineOffsetTableList
    public var sourceId: Int32
    public var sourceUrl: ZigStringSlice

    public init() {
        lineOffsetTable = LineOffsetTableList()
        sourceId = 0
        sourceUrl = ZigStringSlice()
    }

    public init(lineOffsetTable: LineOffsetTableList, sourceId: Int32, sourceUrl: ZigStringSlice) {
        this.lineOffsetTable = lineOffsetTable
        this.sourceId = sourceId
        this.sourceUrl = sourceUrl
    }

    /// 释放资源 - 严格对应 Bun ByteRangeMapping.deinit
    /// Zig:
    ///   pub fn deinit(this: *ByteRangeMapping) void {
    ///       this.line_offset_table.deinit(bun.default_allocator);
    ///   }
    public func deinit(): Unit {
        lineOffsetTable = LineOffsetTableList()
    }

    /// 获取 source ID - 严格对应 Bun ByteRangeMapping.getSourceID
    /// Zig: pub fn getSourceID(this: *ByteRangeMapping) callconv(.c) i32
    public func getSourceID(): Int32 {
        return sourceId
    }

    /// 比较 - 严格对应 Bun ByteRangeMapping.isLessThan
    /// Zig:
    ///   pub fn isLessThan(_: void, a: ByteRangeMapping, b: ByteRangeMapping) bool {
    ///       return bun.strings.order(a.source_url.slice(), b.source_url.slice()) == .lt;
    ///   }
    public static func isLessThan(a: ByteRangeMapping, b: ByteRangeMapping): Bool {
        return a.sourceUrl.slice() < b.sourceUrl.slice()
    }

    /// 生成字节范围映射 - 严格对应 Bun ByteRangeMapping.generate
    /// Zig:
    ///   pub fn generate(str: bun.String, source_contents_str: bun.String, source_id: i32) callconv(.c) void
    public static func generate(str: BaoString, sourceContentsStr: BaoString, sourceId: Int32): Unit {
        let map = ByteRangeMappingGlobalMap.getOrCreate()

        var slice = str.toUTF8(Allocator.default)
        let hash = BaoHash.hash(slice.slice())
        var entry = map.getOrPut(hash)

        if (entry.foundExisting) {
            entry.value.deinit()
        }

        var sourceContents = sourceContentsStr.toUTF8(Allocator.default)

        entry.value = compute(sourceContents.slice(), sourceId, slice)
    }

    /// 查找字节范围映射 - 严格对应 Bun ByteRangeMapping.find
    /// Zig: pub fn find(path: bun.String) callconv(.c) ?*ByteRangeMapping
    public static func find(path: BaoString): ?ByteRangeMapping {
        var slice = path.toUTF8(Allocator.default)
        let map = ByteRangeMappingGlobalMap.instance
        if (map == None) {
            return None
        }
        let hash = BaoHash.hash(slice.slice())
        return map.get(hash)
    }

    /// 从源文件内容计算字节范围映射 - 严格对应 Bun ByteRangeMapping.compute
    /// Zig:
    ///   pub fn compute(source_contents: []const u8, source_id: i32, source_url: bun.jsc.ZigString.Slice) ByteRangeMapping
    public static func compute(sourceContents: String, sourceId: Int32, sourceUrl: ZigStringSlice): ByteRangeMapping {
        return ByteRangeMapping(
            lineOffsetTable: LineOffsetTable.generate(Allocator.default, sourceContents, 0),
            sourceId: sourceId,
            sourceUrl: sourceUrl
        )
    }

    /// 从基本块生成覆盖率报告 - 严格对应 Bun ByteRangeMapping.generateReportFromBlocks
    /// Zig:
    ///   pub fn generateReportFromBlocks(
    ///       this: *ByteRangeMapping,
    ///       allocator: std.mem.Allocator,
    ///       source_url: bun.jsc.ZigString.Slice,
    ///       blocks: []const BasicBlockRange,
    ///       function_blocks: []const BasicBlockRange,
    ///       ignore_sourcemap: bool,
    ///   ) !Report
    public func generateReportFromBlocks(
        alloc: Allocator,
        sourceUrl: ZigStringSlice,
        blocks: Array<BasicBlockRange>,
        functionBlocks: Array<BasicBlockRange>,
        ignoreSourcemap: Bool
    ): ?Report {
        let lineStarts = lineOffsetTable.byteOffsetToStartOfLine()

        var executableLines = Bitset()
        var linesWhichHaveExecuted = Bitset()
        var lineHits = LinesHits()
        var functions = Array<Block>()
        var functionsWhichHaveExecuted = Bitset()
        var stmtsWhichHaveExecuted = Bitset()
        var stmts = Array<Block>()
        var lineCount: UInt32 = 0

        if (ignoreSourcemap) {
            lineCount = UInt32(lineStarts.size)
            executableLines = Bitset.initEmpty(alloc, lineCount)
            linesWhichHaveExecuted = Bitset.initEmpty(alloc, lineCount)
            lineHits = LinesHits.initCapacity(alloc, lineCount)

            let lineHitsSlice = lineHits.slice()

            for (i in 0..blocks.size) {
                let block = blocks[i]
                if (block.endOffset < 0 || block.startOffset < 0) {
                    continue
                }

                let minOffset = UIntNative(minOf(block.startOffset, block.endOffset))
                let maxOffset = UIntNative(maxOf(block.startOffset, block.endOffset))
                var minLine: UInt32 = MAX_U32
                var maxLine: UInt32 = 0

                let hasExecuted = block.hasExecuted || block.executionCount > 0

                for (byteOffset in minOffset..maxOffset) {
                    let newLineIndex = LineOffsetTable.findIndex(lineStarts, Int32(byteOffset))
                    if (newLineIndex == None) {
                        continue
                    }
                    let idx = newLineIndex.getOrThrow()
                    let lineStartByteOffset = lineStarts[Int64(idx)]
                    if (lineStartByteOffset >= Int32(byteOffset)) {
                        continue
                    }

                    let line: UInt32 = UInt32(idx)
                    minLine = minOfUInt32(minLine, line)
                    maxLine = maxOfUInt32(maxLine, line)

                    executableLines.set(line)
                    if (hasExecuted) {
                        linesWhichHaveExecuted.set(line)
                        lineHitsSlice[Int64(line)] = lineHitsSlice[Int64(line)] + 1
                    }
                }

                if (minLine != MAX_U32) {
                    if (hasExecuted) {
                        stmtsWhichHaveExecuted.set(UInt32(i))
                    }
                    stmts.append(Block(startLine: minLine, endLine: maxLine))
                }
            }

            // 处理函数块
            functionsWhichHaveExecuted = Bitset.initEmpty(alloc, UInt32(functionBlocks.size))
            for (i in 0..functionBlocks.size) {
                let function = functionBlocks[i]
                if (function.endOffset < 0 || function.startOffset < 0) {
                    continue
                }

                let minOffset = UIntNative(minOf(function.startOffset, function.endOffset))
                let maxOffset = UIntNative(maxOf(function.startOffset, function.endOffset))
                var minLine: UInt32 = MAX_U32
                var maxLine: UInt32 = 0

                for (byteOffset in minOffset..maxOffset) {
                    let newLineIndex = LineOffsetTable.findIndex(lineStarts, Int32(byteOffset))
                    if (newLineIndex == None) {
                        continue
                    }
                    let idx = newLineIndex.getOrThrow()
                    let lineStartByteOffset = lineStarts[Int64(idx)]
                    if (lineStartByteOffset >= Int32(byteOffset)) {
                        continue
                    }

                    let line: UInt32 = UInt32(idx)
                    minLine = minOfUInt32(minLine, line)
                    maxLine = maxOfUInt32(maxLine, line)
                }

                let didFnExecute = function.executionCount > 0 || function.hasExecuted

                if (!didFnExecute) {
                    let end = minOfUInt32(maxLine, lineCount)
                    for (line in minLine..end) {
                        executableLines.set(line)
                        linesWhichHaveExecuted.unset(line)
                    }
                }

                functions.append(Block(startLine: minLine, endLine: maxLine))

                if (didFnExecute) {
                    functionsWhichHaveExecuted.set(UInt32(i))
                }
            }
        }

        return Report(
            sourceUrl: sourceUrl,
            functions: functions,
            executableLines: executableLines,
            linesWhichHaveExecuted: linesWhichHaveExecuted,
            lineHits: lineHits,
            totalLines: lineCount,
            stmts: stmts,
            functionsWhichHaveExecuted: functionsWhichHaveExecuted,
            stmtsWhichHaveExecuted: stmtsWhichHaveExecuted
        )
    }

    /// 查找已执行行 - 严格对应 Bun ByteRangeMapping.findExecutedLines
    /// Zig:
    ///   pub fn findExecutedLines(
    ///       globalThis: *bun.jsc.JSGlobalObject,
    ///       source_url: bun.String,
    ///       blocks_ptr: [*]const BasicBlockRange,
    ///       blocks_len: usize,
    ///       function_start_offset: usize,
    ///       ignore_sourcemap: bool,
    ///   ) callconv(.c) bun.jsc.JSValue
    public static func findExecutedLines(
        globalThis: JSGlobalObject,
        sourceUrl: BaoString,
        blocksPtr: Array<BasicBlockRange>,
        blocksLen: UIntNative,
        functionStartOffset: UIntNative,
        ignoreSourcemap: Bool
    ): JSValue {
        let this = ByteRangeMapping.find(sourceUrl)
        if (this == None) {
            return JSValue.null
        }

        let mapping = this.getOrThrow()
        let blocks = blocksPtr[0..Int64(functionStartOffset)]
        var functionBlocks = blocksPtr[Int64(functionStartOffset)..Int64(blocksLen)]
        if (functionBlocks.size > 1) {
            functionBlocks = functionBlocks[1..]
        }
        var urlSlice = sourceUrl.toUTF8(Allocator.default)
        let report = mapping.generateReportFromBlocks(Allocator.default, urlSlice, blocks, functionBlocks, ignoreSourcemap)
        if (report == None) {
            return globalThis.throwOutOfMemoryValue()
        }
        var report_ = report.getOrThrow()
        report_.deinit(Allocator.default)

        var coverageFraction = Fraction()

        var allocatingWriter = AllocatingWriter.init(Allocator.default)
        let bufferedWriter = allocatingWriter.writer

        Report.Text.writeFormat(report_, UIntNative(sourceUrl.utf8ByteLength()), coverageFraction, "", bufferedWriter, false)

        allocatingWriter.flush()
        return BaoString.createUTF8ForJS(globalThis, allocatingWriter.written())
    }

    // 辅助方法
    private static func minOf(a: Int32, b: Int32): Int32 {
        if (a < b) { return a }
        return b
    }
    private static func maxOf(a: Int32, b: Int32): Int32 {
        if (a > b) { return a }
        return b
    }
    private static func minOfUInt32(a: UInt32, b: UInt32): UInt32 {
        if (a < b) { return a }
        return b
    }
    private static func maxOfUInt32(a: UInt32, b: UInt32): UInt32 {
        if (a > b) { return a }
        return b
    }
    private let MAX_U32: UInt32 = 4294967295
}

// ============================================================================
// LineOffsetTable - 行偏移表
// 严格翻译自: bun.SourceMap.LineOffsetTable
// ============================================================================

/// 行偏移表列表 - 用于字节偏移到行号的映射
public class LineOffsetTableList {
    public var items: Array<Int32>

    public init() {
        items = []
    }

    /// 获取字节偏移到行起始的数组
    public func byteOffsetToStartOfLine(): Array<Int32> {
        return items
    }

    public func deinit(alloc: Allocator): Unit {
        items = []
    }
}

/// 行偏移表 - 严格对应 Bun LineOffsetTable
public class LineOffsetTable {
    /// 生成行偏移表 - 严格对应 Bun LineOffsetTable.generate
    public static func generate(alloc: Allocator, sourceContents: String, startOffset: Int32): LineOffsetTableList {
        var offsets = Array<Int32>()
        offsets.append(startOffset)

        for (i in 0..sourceContents.length) {
            if (sourceContents[i] == '\n') {
                offsets.append(Int32(i) + 1 + startOffset)
            }
        }

        return LineOffsetTableList(items: offsets)
    }

    /// 查找索引 - 严格对应 Bun LineOffsetTable.findIndex
    public static func findIndex(lineStarts: Array<Int32>, byteOffset: Int32): ?UInt32 {
        if (lineStarts.size == 0) {
            return None
        }

        // 二分查找
        var lo: Int64 = 0
        var hi: Int64 = lineStarts.size - 1
        while (lo < hi) {
            let mid = lo + (hi - lo + 1) / 2
            if (lineStarts[mid] <= byteOffset) {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        return UInt32(lo)
    }
}

// ============================================================================
// ByteRangeMappingGlobalMap - 全局映射表
// 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig:367-373
//   pub const HashMap = std.HashMap(u64, ByteRangeMapping, ...);
//   pub threadlocal var map: ?*HashMap = null;
// ============================================================================

/// 全局字节范围映射哈希表 - 严格对应 Bun ByteRangeMapping.HashMap
public class ByteRangeMappingGlobalMap {
    public static var instance: ?HashMap<UInt64, ByteRangeMapping>

    public static func getOrCreate(): HashMap<UInt64, ByteRangeMapping> {
        if (instance == None) {
            instance = HashMap<UInt64, ByteRangeMapping>()
        }
        return instance.getOrThrow()
    }
}

// ============================================================================
// 辅助类型声明 (来自 bao_jsc/bao_core)
// ============================================================================

/// ZigString.Slice 对应
public class ZigStringSlice {
    public var data: String

    public init() {
        data = ""
    }

    public func slice(): String {
        return data
    }
}

/// 分配写入器
public class AllocatingWriter {
    public var writer: IOWriter
    public var buffer: MutableString

    public init() {
        writer = IOWriter()
        buffer = MutableString.initEmpty(Allocator.default)
    }

    public static func initFunc(alloc: Allocator): AllocatingWriter {
        let aw = AllocatingWriter()
        aw.buffer = MutableString.initEmpty(alloc)
        return aw
    }

    public func flush(): Unit {
        // flush buffer
    }

    public func written(): String {
        return buffer.list.items
    }

    public func deinit(): Unit {
        buffer = MutableString.initEmpty(Allocator.default)
    }
}
