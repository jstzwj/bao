// 严格翻译自: src/css/sourcemap.zig
package bao_css

import bao_core.*
import bao_collections.*

// ============================================================================
// SourceMap - CSS 源码映射
// 严格翻译自: sourcemap.zig SourceMap
// ============================================================================

/// CSS 源码映射
/// 严格翻译自 SourceMap struct
public class CssSourceMap {
    /// 项目根目录
    public var project_root: String

    /// 内部源码映射数据
    public var inner: SourceMapInner

    public init() {
        this.project_root = ""
        this.inner = SourceMapInner()
    }

    public init(project_root: String, inner: SourceMapInner) {
        this.project_root = project_root
        this.inner = inner
    }
}

/// 源码映射内部数据
/// 严格翻译自 SourceMapInner struct
public class SourceMapInner {
    /// 源文件路径列表
    public var sources: ArrayList<String>

    /// 源文件内容列表
    public var sources_content: ArrayList<String>

    /// 名称列表
    public var names: ArrayList<String>

    /// 映射行列表
    public var mapping_lines: ArrayList<MappingLine>

    public init() {
        this.sources = ArrayList<String>()
        this.sources_content = ArrayList<String>()
        this.names = ArrayList<String>()
        this.mapping_lines = ArrayList<MappingLine>()
    }
}

/// 映射行
/// 严格翻译自 MappingLine struct
public class MappingLine {
    /// 行内映射列表
    public var mappings: ArrayList<LineMapping>

    /// 最后一列
    public var last_column: UInt32

    /// 是否已排序
    public var is_sorted: Bool

    public init() {
        this.mappings = ArrayList<LineMapping>()
        this.last_column = 0
        this.is_sorted = false
    }
}

/// 行内映射
/// 严格翻译自 LineMapping struct
public class LineMapping {
    /// 生成列号
    public var generated_column: UInt32

    /// 原始位置 (可选)
    public var original: ?OriginalLocation

    public init() {
        this.generated_column = 0
        this.original = None
    }

    public init(generated_column: UInt32, original: ?OriginalLocation) {
        this.generated_column = generated_column
        this.original = original
    }
}

/// 原始位置
/// 严格翻译自 OriginalLocation struct
public class OriginalLocation {
    /// 原始行号
    public var original_line: UInt32

    /// 原始列号
    public var original_column: UInt32

    /// 源文件索引
    public var source: UInt32

    /// 名称索引 (可选)
    public var name: ?UInt32

    public init() {
        this.original_line = 0
        this.original_column = 0
        this.source = 0
        this.name = None
    }

    public init(original_line: UInt32, original_column: UInt32, source: UInt32, name: ?UInt32) {
        this.original_line = original_line
        this.original_column = original_column
        this.source = source
        this.name = name
    }
}
