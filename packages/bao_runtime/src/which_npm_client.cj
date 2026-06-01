// 严格翻译自: src/runtime/cli/which_npm_client.zig
package bao_runtime

// ============================================================================
// NPMClient — NPM 客户端信息
// 严格翻译自: src/runtime/cli/which_npm_client.zig - NPMClient struct
// ============================================================================

/// NPM 客户端标签类型
/// 对应 Bun: NPMClient.Tag
public enum NPMClientTag {
    | bun
}

/// NPM 客户端信息
/// 对应 Bun: NPMClient
public class NPMClient {
    /// 可执行文件路径
    public var bin: String

    /// 客户端标签
    public var tag: NPMClientTag

    public init(bin: String, tag: NPMClientTag) {
        this.bin = bin
        this.tag = tag
    }
}
