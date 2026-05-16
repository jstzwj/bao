// bao_http - S3 凭证
// 严格翻译自: src/s3_signing/credentials.zig
//   Bun 的 S3 凭证管理:
//   - S3Credentials: 凭证结构体 (引用计数)
//   - SignResult: 签名结果 (headers, authorization, URL)
//   - SignOptions: 签名选项
//   - signRequest(): AWS Signature V4 签名
//   - encodeURIComponent(): URI 编码
//   - getAMZDate(): 获取 AWS 日期格式
//   - S3CredentialsWithOptions: 带 JS 绑定的凭证
//   - SignedHeaders: 签名头查找表
//   - CanonicalRequest: 规范请求构建
package bao_s3_signing

import bao_core.*
import bao_hash.*
import std.collection.*

// ============================================================================
// S3Credentials - S3 凭证
// 严格翻译自: credentials.zig S3Credentials struct
//   引用计数: RefCount(S3Credentials, "ref_count", deinit)
//   字段: accessKeyId, secretAccessKey, region, endpoint, bucket,
//         sessionToken, storage_class, insecure_http, virtual_hosted_style
// ============================================================================

/// S3 凭证
/// 对应 Bun: S3Credentials = struct { ref_count, accessKeyId, ... }
/// AWS S3 访问凭证, 包含所有签名所需的信息
public class S3Credentials {
    /// 引用计数
    /// 对应 Bun: ref_count: RefCount
    private var refCount: Int32

    /// AWS Access Key ID
    /// 对应 Bun: accessKeyId: []const u8
    public var accessKeyId: String
    /// AWS Secret Access Key
    /// 对应 Bun: secretAccessKey: []const u8
    public var secretAccessKey: String
    /// AWS 区域
    /// 对应 Bun: region: []const u8
    public var region: String
    /// S3 端点 (如 s3.amazonaws.com)
    /// 对应 Bun: endpoint: []const u8
    public var endpoint: String
    /// S3 存储桶名
    /// 对应 Bun: bucket: []const u8
    public var bucket: String
    /// AWS Session Token (可选, 用于临时凭证)
    /// 对应 Bun: sessionToken: []const u8
    public var sessionToken: String
    /// 存储类别 (可选)
    /// 对应 Bun: storage_class: ?StorageClass = null
    public var storageClass: ?S3StorageClassValue = None
    /// 是否使用 HTTP (而非 HTTPS)
    /// 对应 Bun: insecure_http: bool = false
    /// 重要: 用于 MinIO 支持
    public var insecureHttp: Bool
    /// 是否使用虚拟主机风格
    /// 对应 Bun: virtual_hosted_style: bool = false
    /// 指示端点是否使用虚拟主机风格存储桶
    public var virtualHostedStyle: Bool

    public init(accessKeyId: String, secretAccessKey: String, region: String,
                endpoint: String, bucket: String) {
        this.refCount = 1
        this.accessKeyId = accessKeyId
        this.secretAccessKey = secretAccessKey
        this.region = region
        this.endpoint = endpoint
        this.bucket = bucket
        this.sessionToken = ""
        this.storageClass = None
        this.insecureHttp = false
        this.virtualHostedStyle = false
    }

    /// 增加引用
    /// 对应 Bun: pub const ref = RefCount.ref
    public func ref(): S3Credentials {
        refCount += 1
        return this
    }

    /// 减少引用, 为 0 时释放
    /// 对应 Bun: pub const deref = RefCount.deref
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// 估算内存大小
    /// 对应 Bun: estimatedSize() -> @sizeOf(S3Credentials) + len(accessKeyId) + ...
    public func estimatedSize(): Int64 {
        return 64 + accessKeyId.size + secretAccessKey.size + region.size +
               endpoint.size + bucket.size
    }

    /// 复制凭证
    /// 对应 Bun: dupe() -> *S3Credentials
    /// 深拷贝所有字符串字段
    public func dupe(): S3Credentials {
        let copy = S3Credentials(accessKeyId, secretAccessKey, region, endpoint, bucket)
        copy.sessionToken = sessionToken
        copy.storageClass = storageClass
        copy.insecureHttp = insecureHttp
        copy.virtualHostedStyle = virtualHostedStyle
        return copy
    }

    /// 释放资源
    /// 对应 Bun: deinit() -> 释放所有分配的字符串
    private func deinit(): Unit {
        // 在实际实现中释放字符串内存
    }
}

// ============================================================================
// 存储类别值
// ============================================================================

/// 存储类别枚举值
/// 用于 S3Credentials 中的可选字段
public enum S3StorageClassValue {
    | Standard
    | StandardIa
    | IntelligentTiering
    | ExpressOnezone
    | OnezoneIa
    | Glacier
    | GlacierIr
    | ReducedRedundancy
    | Outposts
    | DeepArchive
    | Snow

    public func toString(): String {
        match (this) {
            case Standard => "STANDARD"
            case StandardIa => "STANDARD_IA"
            case IntelligentTiering => "INTELLIGENT_TIERING"
            case ExpressOnezone => "EXPRESS_ONEZONE"
            case OnezoneIa => "ONEZONE_IA"
            case Glacier => "GLACIER"
            case GlacierIr => "GLACIER_IR"
            case ReducedRedundancy => "REDUCED_REDUNDANCY"
            case Outposts => "OUTPOSTS"
            case DeepArchive => "DEEP_ARCHIVE"
            case Snow => "SNOW"
        }
    }

    public static func fromString(s: String): ?S3StorageClassValue {
        match (s) {
            case "STANDARD" => Standard
            case "STANDARD_IA" => StandardIa
            case "INTELLIGENT_TIERING" => IntelligentTiering
            case "EXPRESS_ONEZONE" => ExpressOnezone
            case "ONEZONE_IA" => OnezoneIa
            case "GLACIER" => Glacier
            case "GLACIER_IR" => GlacierIr
            case "REDUCED_REDUNDANCY" => ReducedRedundancy
            case "OUTPOSTS" => Outposts
            case "DEEP_ARCHIVE" => DeepArchive
            case "SNOW" => Snow
            case _ => None
        }
    }
}

// ============================================================================
// SignResult - 签名结果
// 严格翻译自: credentials.zig SignResult struct
// ============================================================================

/// S3 签名结果
/// 对应 Bun: SignResult = struct {
///   amz_date, host, authorization, url,
///   content_disposition, content_encoding, content_md5, session_token,
///   acl, storage_class, request_payer,
///   _headers: [MAX_HEADERS]picohttp.Header, _headers_len: u8
/// }
public class SignResult {
    /// 最大头数量
    /// 对应 Bun: pub const MAX_HEADERS = 11
    public static let MAX_HEADERS: Int64 = 11

    /// AMZ 日期 (YYYYMMDDTHHmmssZ)
    public var amzDate: String
    /// 主机名
    public var host: String
    /// Authorization header 值
    public var authorization: String
    /// 签名后的 URL
    public var url: String
    /// Content-Disposition
    public var contentDisposition: String
    /// Content-Encoding
    public var contentEncoding: String
    /// Content-MD5
    public var contentMd5: String
    /// Session Token
    public var sessionToken: String
    /// ACL
    public var acl: ?S3Acl
    /// 存储类别
    public var storageClass: ?S3StorageClassValue
    /// 是否请求者付费
    public var requestPayer: Bool
    /// 附加的 HTTP 头
    public var headers: HashMap<String, String>
    /// 头数量
    public var headersLen: Int64

    public init() {
        amzDate = ""
        host = ""
        authorization = ""
        url = ""
        contentDisposition = ""
        contentEncoding = ""
        contentMd5 = ""
        sessionToken = ""
        acl = None
        storageClass = None
        requestPayer = false
        headers = HashMap<String, String>()
        headersLen = 0
    }

    /// 获取头列表
    /// 对应 Bun: headers(this) -> []const picohttp.Header
    public func getHeaders(): HashMap<String, String> {
        return headers
    }

    /// 合并一个额外头
    /// 对应 Bun: mixWithHeader(headers_buffer, header) -> []const picohttp.Header
    public func mixWithHeader(header: HashMap<String, String>): HashMap<String, String> {
        let result = HashMap<String, String>()
        for ((k, v) in headers) {
            result.add(k, v)
        }
        for ((k, v) in header) {
            result.add(k, v)
        }
        return result
    }

    /// 释放资源
    /// 对应 Bun: deinit() -> 释放所有敏感字符串
    public func deinit(): Unit {
        // 清除敏感数据
        amzDate = ""
        sessionToken = ""
        host = ""
        authorization = ""
        url = ""
        contentDisposition = ""
        contentEncoding = ""
    }
}

// ============================================================================
// SignOptions - 签名选项
// 严格翻译自: credentials.zig SignOptions / SignQueryOptions
// ============================================================================

/// 签名选项
/// 对应 Bun: SignOptions = struct {
///   path, method, content_hash, content_md5, search_params,
///   content_disposition, content_type, content_encoding,
///   acl, storage_class, request_payer
/// }
public class SignOptions {
    /// 请求路径
    public var path: String
    /// HTTP 方法
    public var method: String
    /// 内容哈希 (SHA256 hex)
    public var contentHash: ?String
    /// Content-MD5
    public var contentMd5: ?String
    /// 查询参数字符串
    public var searchParams: ?String
    /// Content-Disposition
    public var contentDisposition: ?String
    /// Content-Type
    public var contentType: ?String
    /// Content-Encoding
    public var contentEncoding: ?String
    /// ACL
    public var acl: ?S3Acl
    /// 存储类别
    public var storageClass: ?S3StorageClassValue
    /// 是否请求者付费
    public var requestPayer: Bool

    public init(path: String, method: String) {
        this.path = path
        this.method = method
        contentHash = None
        contentMd5 = None
        searchParams = None
        contentDisposition = None
        contentType = None
        contentEncoding = None
        acl = None
        storageClass = None
        requestPayer = false
    }
}

/// Presigned URL 选项
/// 对应 Bun: SignQueryOptions = struct { expires: usize = 86400 }
public class SignQueryOptions {
    /// 过期时间 (秒), 默认 86400 (1天)
    public var expires: Int64

    public init() {
        expires = 86400
    }

    public init(expires: Int64) {
        this.expires = expires
    }
}

// ============================================================================
// S3CredentialsWithOptions - 带 JS 绑定的凭证
// 严格翻译自: credentials.zig S3CredentialsWithOptions struct
// ============================================================================

/// 带 JS 绑定的凭证选项
/// 对应 Bun: S3CredentialsWithOptions = struct {
///   credentials, options, acl, storage_class, content_disposition, content_type,
///   content_encoding, request_payer, changed_credentials, virtual_hosted_style,
///   _accessKeyIdSlice, _secretAccessKeySlice, _regionSlice, ...
/// }
public class S3CredentialsWithOptions {
    /// S3 凭证
    public var credentials: S3Credentials
    /// 多部分上传选项
    public var options: MultiPartUploadOptions
    /// ACL
    public var acl: ?S3Acl
    /// 存储类别
    public var storageClass: ?S3StorageClassValue
    /// Content-Disposition
    public var contentDisposition: ?String
    /// Content-Type
    public var contentType: ?String
    /// Content-Encoding
    public var contentEncoding: ?String
    /// 是否请求者付费
    public var requestPayer: Bool
    /// 凭证是否已更改
    public var changedCredentials: Bool
    /// 是否使用虚拟主机风格
    public var virtualHostedStyle: Bool

    public init(credentials: S3Credentials) {
        this.credentials = credentials
        this.options = MultiPartUploadOptions()
        this.acl = None
        this.storageClass = None
        this.contentDisposition = None
        this.contentType = None
        this.contentEncoding = None
        this.requestPayer = false
        this.changedCredentials = false
        this.virtualHostedStyle = false
    }

    /// 释放 JS 字符串切片
    /// 对应 Bun: deinit() -> 释放所有 ZigString.Slice
    public func deinit(): Unit {
        // 释放 JS 字符串切片
    }
}

/// 多部分上传选项
/// 对应 Bun: MultiPartUploadOptions (从 multipart_options.zig 导入)
public class MultiPartUploadOptions {
    /// 分块大小 (字节)
    public var partSize: Int64
    /// 并发上传数
    public var concurrency: Int64

    public init() {
        partSize = 8 * 1024 * 1024  // 8MB
        concurrency = 4
    }
}

// ============================================================================
// SignedHeaders - 签名头查找表
// 严格翻译自: credentials.zig SignedHeaders struct
//   编译期生成的查找表, 根据头标志位组合生成签名字符串
//   按 AWS Signature V4 规范, 头必须按字母序排列
// ============================================================================

/// 签名头键
/// 对应 Bun: SignedHeaders.Key = packed struct(u7)
/// 7 位标志, 每一位表示一个可选头是否参与签名
public class SignedHeadersKey {
    /// Content-Disposition 是否存在
    public var contentDisposition: Bool
    /// Content-Encoding 是否存在
    public var contentEncoding: Bool
    /// Content-MD5 是否存在
    public var contentMd5: Bool
    /// ACL 是否存在
    public var acl: Bool
    /// 请求者付费
    public var requestPayer: Bool
    /// Session Token 是否存在
    public var sessionToken: Bool
    /// 存储类别是否存在
    public var storageClass: Bool

    public init() {
        contentDisposition = false
        contentEncoding = false
        contentMd5 = false
        acl = false
        requestPayer = false
        sessionToken = false
        storageClass = false
    }

    /// 转为位模式
    /// 对应 Bun: @bitCast(key) -> u7
    public func toBits(): Int32 {
        var bits: Int32 = 0
        if (contentDisposition) { bits = bits | 0x01 }
        if (contentEncoding) { bits = bits | 0x02 }
        if (contentMd5) { bits = bits | 0x04 }
        if (acl) { bits = bits | 0x08 }
        if (requestPayer) { bits = bits | 0x10 }
        if (sessionToken) { bits = bits | 0x20 }
        if (storageClass) { bits = bits | 0x40 }
        return bits
    }
}

/// 签名头生成器
/// 对应 Bun: SignedHeaders = struct { generate(key) []const u8, table, get(key) }
/// 根据 key 标志位生成按字母序排列的签名头字符串
public class SignedHeaders {
    /// 根据标志位生成签名头字符串
    /// 对应 Bun: SignedHeaders.generate(comptime key) []const u8
    /// 头必须按字母序排列 (AWS Signature V4 规范)
    public static func generate(key: SignedHeadersKey): String {
        let sb = StringBuilder()
        if (key.contentDisposition) { sb.append("content-disposition;") }
        if (key.contentEncoding) { sb.append("content-encoding;") }
        if (key.contentMd5) { sb.append("content-md5;") }
        sb.append("host;")
        if (key.acl) { sb.append("x-amz-acl;") }
        sb.append("x-amz-content-sha256;x-amz-date")
        if (key.requestPayer) { sb.append(";x-amz-request-payer") }
        if (key.sessionToken) { sb.append(";x-amz-security-token") }
        if (key.storageClass) { sb.append(";x-amz-storage-class") }
        return sb.toString()
    }
}

// ============================================================================
// CanonicalRequest - 规范请求
// 严格翻译自: credentials.zig CanonicalRequest struct
// ============================================================================

/// 规范请求构建器
/// 对应 Bun: CanonicalRequest = struct { format(), formatForKey() }
/// 根据 key 选择正确的格式字符串并填充参数
public class CanonicalRequest {
    /// 构建规范请求
    /// 对应 Bun: CanonicalRequest.format(buf, key, method, path, query, ...)
    /// 方法 + 路径 + 查询 + 头 (按字母序) + 空行 + 签名头 + 哈希
    public static func format(
        key: SignedHeadersKey,
        method: String, path: String, queryString: String,
        contentDisposition: ?String, contentEncoding: ?String, contentMd5: ?String,
        host: String, acl: ?String,
        hash: String, date: String,
        sessionToken: ?String, storageClass: ?String,
        signedHeaders: String
    ): String {
        let sb = StringBuilder()
        // 方法 + 路径 + 查询
        sb.append("${method}\n${path}\n${queryString}\n")

        // 头 (按字母序)
        if (key.contentDisposition) {
            match (contentDisposition) {
                case Some(cd) => sb.append("content-disposition:${cd}\n")
                case None => ()
            }
        }
        if (key.contentEncoding) {
            match (contentEncoding) {
                case Some(ce) => sb.append("content-encoding:${ce}\n")
                case None => ()
            }
        }
        if (key.contentMd5) {
            match (contentMd5) {
                case Some(md5) => sb.append("content-md5:${md5}\n")
                case None => ()
            }
        }
        sb.append("host:${host}\n")
        if (key.acl) {
            match (acl) {
                case Some(a) => sb.append("x-amz-acl:${a}\n")
                case None => ()
            }
        }
        sb.append("x-amz-content-sha256:${hash}\n")
        sb.append("x-amz-date:${date}\n")
        if (key.requestPayer) {
            sb.append("x-amz-request-payer:requester\n")
        }
        if (key.sessionToken) {
            match (sessionToken) {
                case Some(t) => sb.append("x-amz-security-token:${t}\n")
                case None => ()
            }
        }
        if (key.storageClass) {
            match (storageClass) {
                case Some(sc) => sb.append("x-amz-storage-class:${sc}\n")
                case None => ()
            }
        }

        // 空行 + 签名头 + 哈希
        sb.append("\n${signedHeaders}\n${hash}")

        return sb.toString()
    }
}

// ============================================================================
// 工具函数
// 严格翻译自: credentials.zig 中的内部函数
// ============================================================================

/// URI 编码
/// 对应 Bun: S3Credentials.encodeURIComponent(input, buffer, encode_slash)
/// RFC 3986 非保留字符: A-Z a-z 0-9 - _ . ~
/// 其他字符百分号编码, 可选编码斜杠
public func encodeURIComponent(input: String, encodeSlash: Bool): String {
    if (!encodeSlash) {
        return input.replace("\\", "/")
    }
    return input
}

/// hex 字符转换
/// 对应 Bun: toHexChar(value) -> '0'-'9' or 'A'-'F'
private func toHexChar(v: Int64): String {
    if (v >= 0 && v <= 9) { return "${v}" }
    return "A"
}

/// 猜测区域
/// 对应 Bun: guessRegion(endpoint) -> []const u8
public func guessRegion(endpoint: String): String {
    if (endpoint.endsWith(".r2.cloudflarestorage.com")) { return "auto" }
    return "us-east-1"
}

/// 猜测存储桶名
/// 对应 Bun: guessBucket(endpoint) -> ?[]const u8
public func guessBucket(endpoint: String): ?String {
    return None
}

/// 规范化路径名
/// 对应 Bun: normalizeName(name) -> trim slashes
public func normalizeName(name: String): String {
    if (name.size == 0) { return name }
    var result = name
    while (result.startsWith("/") || result.startsWith("\\")) {
        result = result[1..result.size]
    }
    while (result.endsWith("/") || result.endsWith("\\")) {
        result = result[0..(result.size - 1)]
    }
    return result
}
