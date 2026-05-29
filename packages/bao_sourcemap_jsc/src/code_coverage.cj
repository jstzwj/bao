// 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig
//! Code coverage tracking.
package bao_sourcemap_jsc

import bao_jsc.*
import bao_core.*
import std.collection.ArrayList

// ============================================================================
// 代码覆盖率追踪类型
// 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig
// ============================================================================

public class LinesHits {
    public var items: Array<UInt32>
    public init() { items = [] }
    public init(items: Array<UInt32>) { this.items = items }
    public func slice(): Array<UInt32> { return items }
    public func deinit(alloc: Allocator): Unit { items = [] }
}

public class Bitset {
    public var length: UInt32
    private var bits: Array<Bool>

    public init() {
        length = 0
        bits = []
    }

    public init(length: UInt32) {
        this.length = length
        bits = Array<Bool>(Int64(length), { _ => false })
    }

    private func ensure(index: UInt32): Unit {
        if (index < length) { return }
        let newLength = index + 1
        var next = Array<Bool>(Int64(newLength), { i => if (i < bits.size) { bits[i] } else { false } })
        bits = next
        length = newLength
    }

    public func set(index: UInt32): Unit {
        ensure(index)
        bits[Int64(index)] = true
    }

    public func unset(index: UInt32): Unit {
        if (index < length) {
            bits[Int64(index)] = false
        }
    }

    public func toggleAll(): Unit {
        for (i in 0..bits.size) {
            bits[i] = !bits[i]
        }
    }

    public func setIntersection(other: Bitset): Unit {
        for (i in 0..bits.size) {
            bits[i] = bits[i] && i < other.bits.size && other.bits[i]
        }
    }

    public func count(): UInt32 {
        var total: UInt32 = 0
        for (bit in bits) {
            if (bit) { total += 1 }
        }
        return total
    }

    public func clone(alloc: Allocator): Bitset {
        let copy = Bitset(length)
        for (i in 0..bits.size) {
            copy.bits[i] = bits[i]
        }
        return copy
    }

    public func deinit(alloc: Allocator): Unit { bits = []; length = 0 }
    public func iterator(): BitsetIterator { return BitsetIterator(bits) }
}

public class BitsetIterator {
    private var bits: Array<Bool>
    private var index: Int64
    public init() { bits = []; index = 0 }
    public init(bits: Array<Bool>) { this.bits = bits; index = 0 }
    public func next(): ?UInt32 {
        while (index < bits.size) {
            let current = index
            index += 1
            if (bits[current]) {
                return Some(UInt32(current))
            }
        }
        return None
    }
}

public class Block {
    public var startLine: UInt32
    public var endLine: UInt32
    public init() { startLine = 0; endLine = 0 }
    public init(startLine: UInt32, endLine: UInt32) { this.startLine = startLine; this.endLine = endLine }
}

public class Fraction {
    public var functions: Float64
    public var lines: Float64
    public var stmts: Float64
    public var failing: Bool
    public init() { functions = 0.9; lines = 0.9; stmts = 0.75; failing = false }
}

@C
public struct BasicBlockRange {
    public var startOffset: Int32
    public var endOffset: Int32
    public var hasExecuted: Bool
    public var executionCount: UIntNative
    public init() { startOffset = 0; endOffset = 0; hasExecuted = false; executionCount = 0 }
}

public class Report {
    public var totalLines: UInt32
    public var executableLines: Bitset
    public var linesWhichHaveExecuted: Bitset
    public var lineHits: LinesHits
    public var functions: Array<Block>
    public var functionsWhichHaveExecuted: Bitset
    public var stmts: Array<Block>
    public var stmtsWhichHaveExecuted: Bitset

    public init() {
        totalLines = 0
        executableLines = Bitset()
        linesWhichHaveExecuted = Bitset()
        lineHits = LinesHits()
        functions = []
        functionsWhichHaveExecuted = Bitset()
        stmts = []
        stmtsWhichHaveExecuted = Bitset()
    }

    public func linesCoverageFraction(): Float64 {
        let intersected = executableLines.clone(defaultAllocator)
        intersected.setIntersection(linesWhichHaveExecuted)
        let total = executableLines.count()
        if (total == 0) { return 1.0 }
        return Float64(intersected.count()) / Float64(total)
    }

    public func stmtsCoverageFraction(): Float64 {
        if (stmts.size == 0) { return 1.0 }
        return Float64(stmtsWhichHaveExecuted.count()) / Float64(stmts.size)
    }

    public func functionCoverageFraction(): Float64 {
        if (functions.size == 0) { return 1.0 }
        return Float64(functionsWhichHaveExecuted.count()) / Float64(functions.size)
    }

    public func deinit(alloc: Allocator): Unit {
        executableLines.deinit(alloc)
        linesWhichHaveExecuted.deinit(alloc)
        functionsWhichHaveExecuted.deinit(alloc)
        stmtsWhichHaveExecuted.deinit(alloc)
        lineHits.deinit(alloc)
        functions = []
        stmts = []
        totalLines = 0
    }
}

public class Generator {
    public var result: ?Report
    public init() { result = None }
    public func doGenerate(blocksPtr: Array<BasicBlockRange>, blocksLen: UIntNative, functionStartOffset: UIntNative, ignoreSourcemap: Bool): Unit {}
}

public class ByteRangeMapping {
    private static var entries: ArrayList<ByteRangeMapping> = ArrayList<ByteRangeMapping>()
    public var lineStarts: Array<Int32>
    public var sourceID: Int32
    public var sourceURL: BaoString

    public init() {
        lineStarts = [0]
        sourceID = 0
        sourceURL = BaoString()
    }

    public init(sourceContents: String, sourceID: Int32, sourceURL: BaoString) {
        this.lineStarts = computeLineStarts(sourceContents)
        this.sourceID = sourceID
        this.sourceURL = sourceURL
    }

    public func deinit(): Unit { lineStarts = [] }
    public func getSourceID(): Int32 { return sourceID }

    public static func compute(sourceContents: String, sourceID: Int32, sourceURL: BaoString): ByteRangeMapping {
        ByteRangeMapping(sourceContents, sourceID, sourceURL)
    }

    public static func register(sourceContents: String, sourceID: Int32, sourceURL: BaoString): ByteRangeMapping {
        let mapping = compute(sourceContents, sourceID, sourceURL)
        var next = ArrayList<ByteRangeMapping>()
        for (item in entries) {
            if (item.sourceURL.toString() != sourceURL.toString()) {
                next.add(item)
            }
        }
        next.add(mapping)
        entries = next
        return mapping
    }

    public static func find(path: BaoString): ?ByteRangeMapping {
        let needle = path.toString()
        for (entry in entries) {
            if (entry.sourceURL.toString() == needle) {
                return Some(entry)
            }
        }
        return None
    }

    private static func computeLineStarts(sourceContents: String): Array<Int32> {
        var starts = ArrayList<Int32>()
        starts.add(0)
        var offset = 0
        while (offset < sourceContents.size) {
            let ch = sourceContents[offset]
            if (ch == UInt8(0x0D) || ch == UInt8(0x0A)) {
                if (ch == UInt8(0x0D) && offset + 1 < sourceContents.size && sourceContents[offset + 1] == UInt8(0x0A)) {
                    offset += 1
                }
                starts.add(Int32(offset + 1))
            }
            offset += 1
        }
        return starts.toArray()
    }

    private func generateReportFromBlocks(blocks: Array<BasicBlockRange>, functionStartOffset: UIntNative): Report {
        let report = Report()
        report.totalLines = UInt32(lineStarts.size)
        report.executableLines = Bitset(report.totalLines)
        report.linesWhichHaveExecuted = Bitset(report.totalLines)
        report.lineHits = LinesHits(Array<UInt32>(Int64(report.totalLines), { _ => UInt32(0) }))

        let functionStart = Int64(functionStartOffset)
        let split = if (functionStart < blocks.size) { functionStart } else { blocks.size }
        report.stmtsWhichHaveExecuted = Bitset(UInt32(split))

        var stmtsOut = ArrayList<Block>()
        for (i in 0..split) {
            let block = blocks[i]
            if (block.endOffset < 0 || block.startOffset < 0) { continue }
            let minOffset = if (block.startOffset < block.endOffset) { block.startOffset } else { block.endOffset }
            let maxOffset = if (block.startOffset > block.endOffset) { block.startOffset } else { block.endOffset }
            let minLine = CoverageLineOffsetTable.findIndex(lineStarts, minOffset)
            let maxLine = CoverageLineOffsetTable.findIndex(lineStarts, maxOffset)
            if (minLine.isNone() || maxLine.isNone()) { continue }
            let startLine = minLine.getOrThrow()
            let endLine = maxLine.getOrThrow()
            let executed = block.hasExecuted || block.executionCount > 0
            for (line in startLine..(endLine + 1)) {
                report.executableLines.set(line)
                if (executed) {
                    report.linesWhichHaveExecuted.set(line)
                    report.lineHits.items[Int64(line)] += 1
                }
            }
            if (executed) { report.stmtsWhichHaveExecuted.set(UInt32(i)) }
            stmtsOut.add(Block(startLine, endLine))
        }
        report.stmts = stmtsOut.toArray()

        let fnCount = if (blocks.size > split) { blocks.size - split } else { 0 }
        report.functionsWhichHaveExecuted = Bitset(UInt32(fnCount))
        var functionsOut = ArrayList<Block>()
        for (i in split..blocks.size) {
            let block = blocks[i]
            if (block.endOffset < 0 || block.startOffset < 0) { continue }
            let minOffset = if (block.startOffset < block.endOffset) { block.startOffset } else { block.endOffset }
            let maxOffset = if (block.startOffset > block.endOffset) { block.startOffset } else { block.endOffset }
            let minLine = CoverageLineOffsetTable.findIndex(lineStarts, minOffset)
            let maxLine = CoverageLineOffsetTable.findIndex(lineStarts, maxOffset)
            if (minLine.isNone() || maxLine.isNone()) { continue }
            let fnIndex = i - split
            let executed = block.hasExecuted || block.executionCount > 0
            if (executed) { report.functionsWhichHaveExecuted.set(UInt32(fnIndex)) }
            functionsOut.add(Block(minLine.getOrThrow(), maxLine.getOrThrow()))
        }
        report.functions = functionsOut.toArray()
        return report
    }

    public static func findExecutedLines(globalThis: JSGlobalObject, sourceUrl: BaoString, blocksPtr: Array<BasicBlockRange>, blocksLen: UIntNative, functionStartOffset: UIntNative, ignoreSourcemap: Bool): JsValue {
        let mapping = find(sourceUrl)
        if (mapping.isNone()) { return JsValue.jsNull() }
        let requestedLen = Int64(blocksLen)
        let len = if (requestedLen < blocksPtr.size) { requestedLen } else { blocksPtr.size }
        var blocks = Array<BasicBlockRange>(len, { i => blocksPtr[i] })
        let report = mapping.getOrThrow().generateReportFromBlocks(blocks, functionStartOffset)
        let obj = JsValue.createEmptyObject(globalThis.globalThis, 4)
        obj.put(globalThis.globalThis, "lines", JsValue.jsNumber(report.linesCoverageFraction()))
        obj.put(globalThis.globalThis, "functions", JsValue.jsNumber(report.functionCoverageFraction()))
        obj.put(globalThis.globalThis, "statements", JsValue.jsNumber(report.stmtsCoverageFraction()))
        obj.put(globalThis.globalThis, "totalLines", JsValue.jsNumber(Int64(report.totalLines)))
        return obj
    }
}

public class CoverageLineOffsetTableList {
    public init() {}
}

public class CoverageLineOffsetTable {
    public static func generate(alloc: Allocator, sourceContents: String, startOffset: Int32): CoverageLineOffsetTableList { return CoverageLineOffsetTableList() }
    public static func findIndex(lineStarts: Array<Int32>, byteOffset: Int32): ?UInt32 {
        if (lineStarts.size == 0 || byteOffset < 0) { return None }
        var count = lineStarts.size
        var index = 0
        while (count > 0) {
            let step = count / 2
            let i = index + step
            let current = lineStarts[i]
            if (current == byteOffset) { return Some(UInt32(i)) }
            if (i + 1 < lineStarts.size && current < byteOffset && byteOffset < lineStarts[i + 1]) {
                return Some(UInt32(i))
            }
            if (current < byteOffset) {
                index = i + 1
                count = count - step - 1
            } else {
                count = step
            }
        }
        if (index > 0) { return Some(UInt32(index - 1)) }
        return None
    }
}

public class ZigStringSlice {
    public var data: String
    public init() { data = "" }
    public func slice(): String { return data }
}
