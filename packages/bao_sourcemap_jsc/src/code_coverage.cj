// 严格翻译自: src/sourcemap_jsc/CodeCoverage.zig
//! Code coverage tracking - stub implementation.
package bao_sourcemap_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// Stubs for code coverage types
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
    public init() { length = 0 }
    public func set(index: UInt32): Unit {}
    public func unset(index: UInt32): Unit {}
    public func toggleAll(): Unit {}
    public func setIntersection(other: Bitset): Unit {}
    public func count(): UInt32 { return 0 }
    public func clone(alloc: Allocator): Bitset { return Bitset() }
    public func deinit(alloc: Allocator): Unit {}
    public func iterator(): BitsetIterator { return BitsetIterator() }
}

public class BitsetIterator {
    public init() {}
    public func next(): ?UInt32 { return None }
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
    public init() { totalLines = 0 }
    public func linesCoverageFraction(): Float64 { return 1.0 }
    public func stmtsCoverageFraction(): Float64 { return 1.0 }
    public func functionCoverageFraction(): Float64 { return 1.0 }
    public func deinit(alloc: Allocator): Unit {}
}

public class Generator {
    public var result: ?Report
    public init() { result = None }
    public func doGenerate(blocksPtr: Array<BasicBlockRange>, blocksLen: UIntNative, functionStartOffset: UIntNative, ignoreSourcemap: Bool): Unit {}
}

public class ByteRangeMapping {
    public init() {}
    public func deinit(): Unit {}
    public func getSourceID(): Int32 { return 0 }
    public static func find(path: BaoString): ?ByteRangeMapping { return None }
    public static func findExecutedLines(globalThis: JSGlobalObject, sourceUrl: BaoString, blocksPtr: Array<BasicBlockRange>, blocksLen: UIntNative, functionStartOffset: UIntNative, ignoreSourcemap: Bool): JsValue { return JsValue.jsUndefined() }
}

public class LineOffsetTableList {
    public init() {}
}

public class LineOffsetTable {
    public static func generate(alloc: Allocator, sourceContents: String, startOffset: Int32): LineOffsetTableList { return LineOffsetTableList() }
    public static func findIndex(lineStarts: Array<Int32>, byteOffset: Int32): ?UInt32 { return None }
}

public class ZigStringSlice {
    public var data: String
    public init() { data = "" }
    public func slice(): String { return data }
}
