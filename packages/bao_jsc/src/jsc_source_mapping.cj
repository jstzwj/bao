// Bun JSC 源文件到 Bao Cangjie 翻译文件的映射。

package bao_jsc

public class BunJscSourceMapping {
    public let bunPath: String
    public let baoPath: String

    public init(_ bunPath: String, _ baoPath: String) {
        this.bunPath = bunPath
        this.baoPath = baoPath
    }
}
