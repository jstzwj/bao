// S3File - S3 文件对象
// 对应 Bun: src/runtime/webcore/S3File.zig
// 严格翻译自: src/runtime/webcore/S3File.zig
package bao_runtime.webcore.s3

import bao_core.*

// ============================================================================
// S3File - S3 文件对象
// 对应 Bun: src/runtime/webcore/S3File.zig
// ============================================================================

/// S3File — 表示 S3 上的文件
/// 对应 Bun: src/runtime/webcore/S3File.zig
public class S3File {
    /// S3 路径 (bucket/key)
    public var path: String
    /// S3 凭证
    public var credentials: S3Credentials
    /// 文件大小
    public var size: Int64
    /// MIME 类型
    public var contentType: String
    /// ETag
    public var etag: String
    /// 最后修改时间
    public var lastModified: String

    public init(path: String, credentials: S3Credentials) {
        this.path = path
        this.credentials = credentials
        size = 0
        contentType = "application/octet-stream"
        etag = ""
        lastModified = ""
    }

    /// 获取 S3 路径中的 bucket
    public func bucket(): String {
        let slashIdx = path.indexOf("/")
        if (slashIdx > 0) {
            return path.substring(0, slashIdx)
        }
        return path
    }

    /// 获取 S3 路径中的 key
    public func key(): String {
        let slashIdx = path.indexOf("/")
        if (slashIdx > 0 && slashIdx + 1 < path.length) {
            return path.substring(slashIdx + 1)
        }
        return ""
    }

    /// 判断是否为 S3 文件
    /// 对应 Bun: Blob.isS3()
    public func isS3(): Bool {
        return path.length > 0
    }

    /// 获取预签名 URL
    /// 对应 Bun: S3 签名请求生成预签名 URL
    public func presignedUrl(expires: Int64): String {
        let signedReq = credentials.signRequest(path, "GET")
        return "${signedReq.url}?X-Amz-Expires=${expires}"
    }
}
