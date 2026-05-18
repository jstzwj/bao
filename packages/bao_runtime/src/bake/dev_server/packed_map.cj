// 翻译自 Bun: src/runtime/bake/DevServer/PackedMap.zig
// 单个文件的打包源映射数据。
// 由一个 IncrementalGraph 文件和/或多个 SourceMapStore 条目拥有。

package bao_runtime.bake.dev_server

/// EndState - 结束状态
/// 对应 Bun PackedMap.end_state: struct { original_line, original_column }
public class EndState {
    public var original_line: Int32
    public var original_column: Int32

    public init() {
        original_line = 0
        original_column = 0
    }

    public init(original_line: Int32, original_column: Int32) {
        this.original_line = original_line
        this.original_column = original_column
    }
}

/// LineCount - HTML/CSS/Assets 的行数计数
/// 对应 Bun PackedMap.LineCount = bun.GenericIndex(u32, u8)
public struct LineCount {
    public var value: UInt32

    public init(value: UInt32) {
        this.value = value
    }
}

/// PackedMap - 单个文件的打包源映射数据
/// 对应 Bun PackedMap: vlq_, escaped_source, end_state
public class PackedMap {
    public var vlqData: String
    public var escapedSource: String
    public var endState: EndState

    public init() {
        vlqData = ""
        escapedSource = ""
        endState = EndState()
    }

    public init(vlqData: String, escapedSource: String, endState: EndState) {
        this.vlqData = vlqData
        this.escapedSource = escapedSource
        this.endState = endState
    }

    /// 对应 Bun PackedMap.newNonEmpty
    public static func newNonEmpty(chunk: SourceMapChunk, escapedSource: String): PackedMap {
        return PackedMap(
            vlqData: chunk.buffer,
            escapedSource: escapedSource,
            endState: EndState(
                original_line: chunk.endState.original_line,
                original_column: chunk.endState.original_column,
            ),
        )
    }

    /// 对应 Bun PackedMap.deinit
    public func deinit(): Unit {
        vlqData = ""
        escapedSource = ""
    }

    /// 对应 Bun PackedMap.memoryCost
    public func memoryCost(): Int64 {
        return Int64(vlqData.length) + Int64(escapedSource.length)
    }

    /// 对应 Bun PackedMap.vlq()
    public func vlq(): String {
        return vlqData
    }

    /// 对应 Bun PackedMap.quotedContents() (Bun 原始 TODO: rename to escapedSource)
    public func quotedContents(): String {
        return escapedSource
    }
}

/// PackedMapShared - PackedMap 的共享引用包装
/// 对应 Bun PackedMap.Shared: union(enum) { some, none, line_count }
public enum PackedMapShared {
    | Some(PackedMap)
    | None
    | LineCount(LineCount)

    /// 对应 Bun Shared.get()
    public func get(): ?PackedMap {
        match (this) {
            case Some(map) => map
            case _ => None
        }
    }

    /// 对应 Bun Shared.take()
    public mutating func take(): ?PackedMap {
        match (this) {
            case Some(map) =>
                this = PackedMapShared.None
                return map
            case _ => None
        }
    }

    /// 对应 Bun Shared.clone()
    public func clone(): PackedMapShared {
        match (this) {
            case Some(map) => PackedMapShared.Some(map)
            case _ => this
        }
    }

    /// 对应 Bun Shared.deinit()
    public mutating func deinit(): Unit {
        match (this) {
            case Some(map) =>
                map.deinit()
                this = PackedMapShared.None
            case _ => ()
        }
    }

    /// 对应 Bun Shared.memoryCost()
    public func memoryCost(): Int64 {
        match (this) {
            case Some(map) => map.memoryCost()
            case _ => Int64(0)
        }
    }
}

/// SourceMapChunk - 源映射数据块（简化表示）
public class SourceMapChunk {
    public var buffer: String
    public var endState: EndState

    public init() {
        buffer = ""
        endState = EndState()
    }
}
