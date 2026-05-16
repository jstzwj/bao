// 内容编码枚举
// 严格翻译自: src/http_types/Encoding.zig
//   Bun 的内容编码: identity/gzip/deflate/brotli/zstd/chunked
package bao_http_types

import bao_core.*
import std.collection.*

// ============================================================================
// ContentEncoding - 内容编码枚举
// 严格翻译自: Encoding.zig Encoding enum
// ============================================================================

/// 内容编码枚举 - 对应 Bun Encoding
/// 用于 HTTP Content-Encoding / Transfer-Encoding 头
public enum ContentEncoding {
    | Identity   // 无压缩
    | Gzip       // gzip 压缩
    | Deflate    // deflate 压缩
    | Brotli     // brotli 压缩
    | Zstd       // zstd 压缩
    | Chunked    // 分块传输编码
}

// ============================================================================
// ContentEncodingUtil - ContentEncoding 工具函数
// ============================================================================

/// 内容编码工具类
public class ContentEncodingUtil {
    /// 是否可使用 libdeflate 压缩/解压 - 对应 Bun Encoding.canUseLibDeflate()
    /// Bun: gzip 和 deflate 可以使用 libdeflate
    public static func canUseLibDeflate(enc: ContentEncoding): Bool {
        match (enc) {
            case ContentEncoding.Gzip => true
            case ContentEncoding.Deflate => true
            case _ => false
        }
    }

    /// 是否为压缩编码 - 对应 Bun Encoding.isCompressed()
    /// Bun: brotli, gzip, deflate, zstd 为压缩编码
    public static func isCompressed(enc: ContentEncoding): Bool {
        match (enc) {
            case ContentEncoding.Brotli => true
            case ContentEncoding.Gzip => true
            case ContentEncoding.Deflate => true
            case ContentEncoding.Zstd => true
            case _ => false
        }
    }

    /// 从字符串解析编码 - 对应 Accept-Encoding 头解析
    public static func fromString(str: String): ?ContentEncoding {
        let lower = str
        if (lower == "identity") {
            return ContentEncoding.Identity
        }
        if (lower == "gzip" || lower == "x-gzip") {
            return ContentEncoding.Gzip
        }
        if (lower == "deflate") {
            return ContentEncoding.Deflate
        }
        if (lower == "br" || lower == "brotli") {
            return ContentEncoding.Brotli
        }
        if (lower == "zstd") {
            return ContentEncoding.Zstd
        }
        if (lower == "chunked") {
            return ContentEncoding.Chunked
        }
        return None<ContentEncoding>
    }

    /// 编码枚举转字符串 - 用于 Content-Encoding 头
    public static func toString(enc: ContentEncoding): String {
        match (enc) {
            case ContentEncoding.Identity => "identity"
            case ContentEncoding.Gzip => "gzip"
            case ContentEncoding.Deflate => "deflate"
            case ContentEncoding.Brotli => "br"
            case ContentEncoding.Zstd => "zstd"
            case ContentEncoding.Chunked => "chunked"
        }
    }

    /// 解析 Accept-Encoding 头，返回客户端偏好列表
    public static func parseAcceptEncoding(header: String): Array<ContentEncoding> {
        let enc = fromString(header)
        if (enc.isSome()) { return [enc.getOrThrow()] }
        return []
    }
}
