// Blob Store - Blob 底层存储
// 对应 Bun: src/runtime/webcore/blob/Store.zig
// 严格翻译自: src/runtime/webcore/blob/Store.zig
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// BlobStoreFile - Blob 文件存储数据
// 对应 Bun: Blob.Store.File
// ============================================================================

/// Blob 文件存储数据
/// 对应 Bun: Blob.Store.File
public class BlobStoreFile {
    /// 文件路径
    public var path: String
    /// MIME 类型
    public var mimeType: MimeType
    /// 文件大小
    public var size: Int64
    /// 最后修改时间
    public var lastModified: Float64
    /// 是否为 TTY
    public var isAtty: ?Bool

    public init(path: String) {
        this.path = path
        mimeType = MimeType()
        size = 0
        lastModified = 0.0
        isAtty = None
    }
}

// ============================================================================
// BlobStoreS3 - Blob S3 存储数据
// 对应 Bun: Blob.Store.S3
// ============================================================================

/// Blob S3 存储数据
/// 对应 Bun: Blob.Store.S3
public class BlobStoreS3 {
    /// S3 路径
    public var path: String
    /// MIME 类型
    public var mimeType: MimeType
    /// 文件大小
    public var size: Int64

    public init(path: String) {
        this.path = path
        mimeType = MimeType()
        size = 0
    }
}

// ============================================================================
// MimeType - MIME 类型
// 对应 Bun: bun.http.MimeType
// ============================================================================

/// MIME 类型
/// 对应 Bun: bun.http.MimeType
public class MimeType {
    /// MIME 类型值
    public var value: String

    public init() {
        value = "application/octet-stream"
    }

    public init(value: String) {
        this.value = value
    }

    /// 常用 MIME 类型
    public static let TEXT = MimeType("text/plain")
    public static let JSON = MimeType("application/json")
    public static let HTML = MimeType("text/html")
    public static let CSS = MimeType("text/css")
    public static let JAVASCRIPT = MimeType("application/javascript")
    public static let OCTET_STREAM = MimeType("application/octet-stream")
    public static let FORM_DATA = MimeType("multipart/form-data")
    public static let URL_ENCODED = MimeType("application/x-www-form-urlencoded")
    public static let PNG = MimeType("image/png")
    public static let JPEG = MimeType("image/jpeg")
    public static let GIF = MimeType("image/gif")
    public static let SVG = MimeType("image/svg+xml")
    public static let WEBP = MimeType("image/webp")

    /// 从 Content-Type 字符串初始化
    /// 对应 Bun: MimeType.init()
    public static func fromContentType(contentType: String): MimeType {
        // 去除参数
        let semicolonIdx = contentType.indexOf(";")
        let mimeType = if (semicolonIdx >= 0) {
            contentType.substring(0, semicolonIdx).trim().toLowerCase()
        } else {
            contentType.trim().toLowerCase()
        }
        return MimeType(mimeType)
    }
}
