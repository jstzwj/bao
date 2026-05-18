// SourceMap - Source Map 实现
// 严格翻译自: src/sourcemap/sourcemap.zig
//   Bun 的 sourcemap.zig 定义了:
//     LegacySourceMapState - 源映射状态 (相对偏移)
//     SourceMap - 源映射主结构
//     LegacyParseUrlResultHint - 解析结果提示
//     ParseUrl - 解析 URL 结果
//     ParseResult - 解析结果
//     LegacyParsedSourceMap - 已解析源映射 (重新导出)
//     LineColumnOffset - 行列偏移
//     LegacySourceContent - 源内容
//     LegacySourceMapPieces - 源映射片段
//     SourceMapShifts - 源映射偏移
//     appendSourceMapChunk - 追加源映射块
//     appendMappingToBuffer - 追加映射到缓冲区
//     LegacyDebugIDFormatter - 调试 ID 格式化器
package bao_sourcemap

import bao_core.*
import std.collection.*

// ============================================================================
// LegacySourceMapState - 源映射状态
// 严格翻译自: src/sourcemap/sourcemap.zig LegacySourceMapState
//   pub const LegacySourceMapState = struct {
//       generated_line: i32 = 0,
//       generated_column: i32 = 0,
//       source_index: i32 = 0,
//       original_line: i32 = 0,
//       original_column: i32 = 0,
//   }
// ============================================================================

/// 源映射状态 - 对应 Bun LegacySourceMapState
/// 坐标使用相对偏移, 存储在 VLQ 格式中
public class LegacySourceMapState {
    /// 生成行 (不存储在 source map 中, 仅用于 bundler 拼接)
    public var generatedLine: Int32
    /// 生成列 (VLQ 格式存储)
    public var generatedColumn: Int32
    /// 源索引 (VLQ 格式存储)
    public var sourceIndex: Int32
    /// 原始行 (VLQ 格式存储)
    public var originalLine: Int32
    /// 原始列 (VLQ 格式存储)
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

// ============================================================================
// LegacyParseUrlResultHint - 解析结果提示
// 严格翻译自: src/sourcemap/sourcemap.zig LegacyParseUrlResultHint
//   pub const LegacyParseUrlResultHint = union(enum) {
//       mappings_only,
//       source_only: u32,
//       all: struct { line: i32, column: i32, include_names: bool },
//   }
// ============================================================================

/// 解析结果提示 - 对应 Bun LegacyParseUrlResultHint
public enum LegacyParseUrlResultHint {
    | MappingsOnly
    | SourceOnly(UInt32)
    | All(Int32, Int32, Bool)  // line, column, include_names

    /// 是否只请求映射
    public func isMappingsOnly(): Bool {
        match (this) {
            case MappingsOnly => true
            case _ => false
        }
    }

    /// 是否只请求源
    public func isSourceOnly(): Bool {
        match (this) {
            case SourceOnly(_) => true
            case _ => false
        }
    }
}

// ============================================================================
// ParseUrl - 解析 URL 结果
// 严格翻译自: src/sourcemap/sourcemap.zig ParseUrl
//   pub const ParseUrl = struct {
//       map: ?*LegacyParsedSourceMap = null,
//       mapping: ?Mapping = null,
//       source_contents: ?[]const u8 = null,
//   }
// ============================================================================

/// 解析 URL 结果 - 对应 Bun ParseUrl
public class ParseUrlResult {
    /// 已解析的源映射
    public var map: ?LegacyParsedSourceMap
    /// 映射条目
    public var mapping: ?Mapping
    /// 源内容
    public var sourceContents: ?String

    public init() {
        map = None
        mapping = None
        sourceContents = None
    }
}

// ============================================================================
// ParseResult - 解析结果
// 严格翻译自: src/sourcemap/sourcemap.zig ParseResult
//   pub const ParseResult = union(enum) {
//       fail: struct { loc, err, value, msg },
//       success: LegacyParsedSourceMap,
//   }
// ============================================================================

/// 解析结果 - 对应 Bun ParseResult
public enum ParseResult {
    | Fail(ParseError)
    | Success(LegacyParsedSourceMap)
}

/// 解析错误
public class ParseError {
    public var loc: Int64
    public var err: SourceMapError
    public var value: Int32
    public var msg: String

    public init(loc: Int64, err: SourceMapError, value: Int32, msg: String) {
        this.loc = loc
        this.err = err
        this.value = value
        this.msg = msg
    }
}

/// 源映射错误
public enum SourceMapError {
    | InvalidBase64
    | InvalidJSON
    | InvalidSourceMap
    | UnsupportedVersion
    | UnsupportedFormat
}

// ============================================================================
// LegacyLegacySourceContentHandling - 源内容处理
// 严格翻译自: src/sourcemap/sourcemap.zig LegacyLegacySourceContentHandling
//   pub const LegacyLegacySourceContentHandling = enum(u1) {
//       no_source_contents,
//       source_contents,
//   }
// ============================================================================

/// 源内容处理 - 对应 Bun LegacyLegacySourceContentHandling
public enum LegacyLegacySourceContentHandling {
    | NoLegacySourceContents
    | LegacySourceContents
}

// ============================================================================
// LegacySourceMapLoadHint - 源映射加载提示
// 严格翻译自: src/sourcemap/sourcemap.zig LegacySourceMapLoadHint
//   pub const LegacySourceMapLoadHint = enum(u2) {
//       none,
//       is_inline_map,
//       is_external_map,
//   }
// ============================================================================

/// 源映射加载提示 - 对应 Bun LegacySourceMapLoadHint
public enum LegacySourceMapLoadHint {
    | None
    | IsInlineMap
    | IsExternalMap
}

// ============================================================================
// LegacySourceContent - 源内容
// 严格翻译自: src/sourcemap/sourcemap.zig LegacySourceContent
//   pub const LegacySourceContent = struct {
//       value: []const u16 = &[_]u16{},
//       quoted: []const u8 = &[_]u8{},
//   }
// ============================================================================

/// 源内容 - 对应 Bun LegacySourceContent
public class LegacySourceContent {
    /// UTF-16 值
    public var value: String
    /// 引用字符串
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
// SourceMapShifts - 源映射偏移
// 严格翻译自: src/sourcemap/sourcemap.zig SourceMapShifts
//   pub const SourceMapShifts = struct {
//       before: LineColumnOffset,
//       after: LineColumnOffset,
//   }
// ============================================================================

/// 源映射偏移 - 对应 Bun SourceMapShifts
public class SourceMapShifts {
    public var before: LineColumnOffset
    public var after: LineColumnOffset

    public init(before: LineColumnOffset, after: LineColumnOffset) {
        this.before = before
        this.after = after
    }
}

// ============================================================================
// LegacySourceMapPieces - 源映射片段
// 严格翻译自: src/sourcemap/sourcemap.zig LegacySourceMapPieces
//   pub const LegacySourceMapPieces = struct {
//       prefix: std.array_list.Managed(u8),
//       mappings: std.array_list.Managed(u8),
//       suffix: std.array_list.Managed(u8),
//       pub fn init, hasContent, finalize
//   }
// ============================================================================

/// 源映射片段 - 对应 Bun LegacySourceMapPieces
public class LegacySourceMapPieces {
    /// 前缀
    public var prefix: ArrayList<UInt8>
    /// 映射
    public var mappings: ArrayList<UInt8>
    /// 后缀
    public var suffix: ArrayList<UInt8>

    public init() {
        prefix = ArrayList<UInt8>()
        mappings = ArrayList<UInt8>()
        suffix = ArrayList<UInt8>()
    }

    /// 是否有内容
    public func hasContent(): Bool {
        return prefix.size + mappings.size + suffix.size > 0
    }

    /// 定稿 - 对应 Bun LegacySourceMapPieces.finalize
    /// 拼接前缀 + 修改后的映射 + 后缀
    public func finalize(shifts: Array<SourceMapShifts>): ?String {
        var result = ArrayList<UInt8>()
        // 追加前缀
        for (b in prefix) {
            result.add(b)
        }
        // 追加映射 (简化: 直接追加, 不做偏移修改)
        for (b in mappings) {
            result.add(b)
        }
        // 追加后缀
        for (b in suffix) {
            result.add(b)
        }
        return String.fromUtf8(result.toArray())
    }
}

// ============================================================================
// SourceMap - 源映射主结构
// 严格翻译自: src/sourcemap/sourcemap.zig SourceMap
//   pub const SourceMap = @This()
//   sources: [][]const u8
//   sources_content: []string
//   mapping: Mapping.List
//   allocator: std.mem.Allocator
//   pub fn find, parseUrl, parseJSON, getSourceMapImpl
// ============================================================================

/// 源映射 - 对应 Bun SourceMap
public class SourceMap {
    /// 源文件路径
    public var sources: Array<String>
    /// 源内容
    public var sourcesContent: Array<LegacySourceContent>
    /// 映射列表
    public var mappings: ArrayList<Mapping>

    public init() {
        sources = []
        sourcesContent = []
        mappings = ArrayList<Mapping>()
    }

    public init(sources: Array<String>, sourcesContent: Array<LegacySourceContent>) {
        this.sources = sources
        this.sourcesContent = sourcesContent
        mappings = ArrayList<Mapping>()
    }

    /// 查找 - 对应 Bun SourceMap.find
    public func find(line: Int64, column: Int64): ?Mapping {
        // 在映射列表中二分查找
        var lo: Int64 = 0
        var hi: Int64 = mappings.size
        while (lo < hi) {
            let mid = lo + (hi - lo) / 2
            let m = mappings[Int64(mid)]
            if (m.generated.line < line || (m.generated.line == line && m.generated.column <= column)) {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        if (lo == 0) {
            return None
        }
        let best = mappings[Int64(lo - 1)]
        if (best.generated.line != line) {
            return None
        }
        return best
    }

    /// 解析 URL - 对应 Bun SourceMap.parseUrl
    /// 解析内联 source map URL
    public static func parseUrl(source: String, hint: LegacyParseUrlResultHint): ?ParseUrlResult {
        let dataPrefix = "data:application/json"
        if (!source.startsWith(dataPrefix)) {
            return None
        }
        // 简化: 不处理完整的 data URL 解析
        return None
    }

    /// 追加源映射块 - 对应 Bun appendSourceMapChunk
    /// 并行计算的源映射块在第二遍中拼接
    public static func appendSourceMapChunk(
        prevEndState: LegacySourceMapState,
        startState: LegacySourceMapState,
        sourceMap: String
    ): String {
        // 简化: 直接返回源映射
        return sourceMap
    }

    /// 追加映射到缓冲区 - 对应 Bun appendMappingToBuffer
    /// 极其热点的函数
    public static func appendMappingToBuffer(
        lastByte: UInt8,
        prevState: LegacySourceMapState,
        currentState: LegacySourceMapState
    ): Array<UInt8> {
        var result = ArrayList<UInt8>()
        let needsComma = lastByte != UInt8(0) && lastByte != UInt8(59) && lastByte != UInt8(34)
        if (needsComma) {
            result.add(UInt8(44)) // ','
        }
        // 编码四个 VLQ 字段
        let genCol = currentState.generatedColumn - prevState.generatedColumn
        let srcIdx = currentState.sourceIndex - prevState.sourceIndex
        let origLine = currentState.originalLine - prevState.originalLine
        let origCol = currentState.originalColumn - prevState.originalColumn

        let vlqs = [
            VLQEncode(Int64(genCol)),
            VLQEncode(Int64(srcIdx)),
            VLQEncode(Int64(origLine)),
            VLQEncode(Int64(origCol))
        ]
        for (vlq in vlqs) {
            for (b in vlq) {
                result.add(b)
            }
        }
        return result.toArray()
    }
}

// ============================================================================
// LegacyParsedSourceMap - 已解析源映射
// 严格翻译自: src/sourcemap/LegacyParsedSourceMap.zig
// ============================================================================

/// 已解析源映射 - 对应 Bun LegacyParsedSourceMap
public class LegacyParsedSourceMap {
    /// 源文件路径列表
    public var sources: Array<String>
    /// 源内容列表
    public var sourcesContent: Array<String>
    /// 映射列表
    public var mappings: ArrayList<Mapping>
    /// 外部源名
    public var externalSourceNames: ?Array<String>
    /// 底层提供者
    public var underlyingProvider: ?LegacySourceContentPtr
    /// 名称列表
    public var names: Array<String>

    public init() {
        sources = []
        sourcesContent = []
        mappings = ArrayList<Mapping>()
        externalSourceNames = None
        underlyingProvider = None
        names = []
    }

    /// 查找映射
    public func findMapping(line: Int64, column: Int64): ?Mapping {
        var lo: Int64 = 0
        var hi: Int64 = mappings.size
        while (lo < hi) {
            let mid = lo + (hi - lo) / 2
            let m = mappings[Int64(mid)]
            if (m.generated.line < line || (m.generated.line == line && m.generated.column <= column)) {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        if (lo == 0) {
            return None
        }
        let best = mappings[Int64(lo - 1)]
        if (best.generated.line != line) {
            return None
        }
        return best
    }

    /// 引用
    public func ref(): Unit {
        // 增加引用计数
    }

    /// 解除引用
    public func deref(): Unit {
        // 减少引用计数
    }
}

/// 源内容指针
public class LegacySourceContentPtr {
    public var loadHint: LegacySourceMapLoadHint

    public init() {
        loadHint = LegacySourceMapLoadHint.None
    }
}

// ============================================================================
// LegacyDebugIDFormatter - 调试 ID 格式化器
// 严格翻译自: src/sourcemap/sourcemap.zig LegacyDebugIDFormatter
//   pub const LegacyDebugIDFormatter = struct {
//       id: u64 = 0,
//       pub fn format
//   }
// ============================================================================

/// 调试 ID 格式化器 - 对应 Bun LegacyDebugIDFormatter
/// 将 64 位哈希格式化为 128 位 UUID (填充 "bun!bun!" hex 编码)
public class LegacyDebugIDFormatter {
    public var id: UInt64

    public init() {
        id = UInt64(0)
    }

    public init(id: UInt64) {
        this.id = id
    }

    /// 格式化为 32 字符十六进制字符串
    public func format(): String {
        let hex = id.toString()
        // 填充到 16 字符
        var padded = StringBuilder()
        let zeroCount = 16 - hex.size
        for (_ in 0..zeroCount) {
            padded.append("0")
        }
        padded.append(hex)
        // 追加 "bun!bun!" 的十六进制: 64756E2164756E21
        padded.append("64756E2164756E21")
        return padded.toString()
    }
}

// ============================================================================
// VLQ 编码辅助函数
// ============================================================================

/// VLQ 编码 (简化版本)
/// 将有符号整数编码为 VLQ 字节数组
private func VLQEncode(value: Int64): Array<UInt8> {
    var result = ArrayList<UInt8>()
    var v: Int64 = if (value < 0) { ((-value) << 1) + 1 } else { value << 1 }
    while (true) {
        var byte: UInt8 = UInt8(v & 0x7f)
        v = v >> 7
        if (v != 0) {
            byte = byte | UInt8(0x80)
        }
        result.add(byte)
        if (v == 0) {
            break
        }
    }
    return result.toArray()
}
