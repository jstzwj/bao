// S3Stat - S3 对象元数据
// 对应 Bun: src/runtime/webcore/S3Stat.zig
// 严格翻译自: src/runtime/webcore/S3Stat.zig
package bao_runtime

import bao_core.*

// ============================================================================
// S3Stat - S3 对象元数据
// 对应 Bun: src/runtime/webcore/S3Stat.zig
// ============================================================================

/// S3Stat — S3 对象元数据
/// 对应 Bun: src/runtime/webcore/S3Stat.zig
public class S3Stat {
    /// 对象大小 (字节)
    public var size: Int64
    /// 最后修改时间 (ISO 8601)
    public var lastModified: String
    /// ETag
    public var etag: String
    /// Content-Type
    public var contentType: String
    /// 存储类型
    public var storageClass: String
    /// 是否存在
    public var exists: Bool

    public init() {
        size = 0
        lastModified = ""
        etag = ""
        contentType = ""
        storageClass = "STANDARD"
        exists = false
    }
}
