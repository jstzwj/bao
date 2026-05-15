// 严格翻译自: src/cli/which_npm_client.zig
package bao_cli

// ============================================================================
// NPMClient — NPM 客户端信息
// 严格翻译自: src/cli/which_npm_client.zig - NPMClient struct
// ============================================================================

/// NPM 客户端信息
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

/// NPM 客户端标签类型
public enum NPMClientTag {
    | bun
}
