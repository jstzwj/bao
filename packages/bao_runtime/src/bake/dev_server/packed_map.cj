// 翻译自 Bun: src/runtime/bake/DevServer/PackedMap.zig
// 单个文件的打包源映射数据。
// 由一个 IncrementalGraph 文件和/或多个 SourceMapStore 条目拥有。
// TODO: 完整实现需要 Cangjie 泛型枚举和指针类型支持

package bao_runtime.bake.dev_server

/// EndState - 结束状态
public class EndState {
    public var original_line: Int32
    public var original_column: Int32

    public init() {
        original_line = 0
        original_column = 0
    }
}

/// PackedMap - 单个文件的打包源映射数据
/// TODO: 完整实现需要 OwnedIn/Shared 等泛型类型
public class PackedMap {
    public var vlqData: String
    public var escapedSource: String
    public var endState: EndState

    public init() {
        vlqData = ""
        escapedSource = ""
        endState = EndState()
    }

    /// 获取 VLQ 数据
    public func vlq(): String {
        return vlqData
    }

    /// 获取引用内容（转义源）
    public func quotedContents(): String {
        return escapedSource
    }
}
