// bao_sourcemap - Source Map 解析与生成
// 严格翻译自: src/sourcemap/
//   - sourcemap.zig: SourceMap, LineColumnOffset, SourceMapState, SourceMapPieces
//   - VLQ.zig: VLQ 编编码/解码 (Variable-Length Quantity)
//   - Mapping.zig: Mapping, Mapping.List, parse
//   - ParsedSourceMap.zig: ParsedSourceMap
//   - Chunk.zig: Chunk, VLQSourceMap, Builder
//   - LineOffsetTable.zig: LineOffsetTable
//   - InternalSourceMap.zig: InternalSourceMap (私有二进制格式)
package bao_sourcemap

// ============================================================================
// 模块重导出
// ============================================================================

// VLQ Base64 编解码 - 严格翻译自 src/sourcemap/VLQ.zig

// SourceMap 映射条目 - 严格翻译自 src/sourcemap/Mapping.zig

// SourceMap Chunk - 严格翻译自 src/sourcemap/Chunk.zig

// 行偏移表 - 严格翻译自 src/sourcemap/LineOffsetTable.zig

// 解析后的 SourceMap - 严格翻译自 src/sourcemap/ParsedSourceMap.zig

// SourceMap 构建器 - 严格翻译自 src/sourcemap/sourcemap.zig + Chunk.zig Builder
