// bao_http - S3 请求签名
// 严格翻译自: src/s3_signing/
//   Bun 的 S3 签名实现:
//   - credentials.zig: S3Credentials, signRequest, SignResult
//   - acl.zig: ACL 权限控制
//   - storage_class.zig: 存储类别
//   - error.zig: S3 错误类型
//   此处提供:
//   - AwsCredentials: accessKeyId/secretAccessKey/sessionToken
//   - S3Signer: signRequest (Authorization header)
//   - Canonical request 构建
//   - String-to-sign 构造 (AWS4-HMAC-SHA256)
//   - Signing key 派生 (date/region/service)
//   - Presigned URL 生成
package bao_http

import bao_core.*
import bao_hash.*
import bao_collections.*
import bao_sys.*
import std.time.*

// ============================================================================
// AWS 凭证
// 严格翻译自: src/s3_signing/credentials.zig S3Credentials
// ============================================================================

/// AWS 凭证
/// 对应 Bun: S3Credentials struct
public class AwsCredentials {
    /// AWS Access Key ID
    public var accessKeyId: String
    /// AWS Secret Access Key
    public var secretAccessKey: String
    /// AWS Session Token (可选, 用于临时凭证)
    public var sessionToken: String
    /// AWS 区域
    public var region: String
    /// S3 端点 (可选, 默认 s3.amazonaws.com)
    public var endpoint: String
    /// S3 存储桶名
    public var bucket: String
    /// 是否使用 HTTP (而非 HTTPS)
    public var insecureHttp: Bool
    /// 是否使用虚拟主机风格
    public var virtualHostedStyle: Bool

    public init(accessKeyId: String, secretAccessKey: String, region: String) {
        this.accessKeyId = accessKeyId
        this.secretAccessKey = secretAccessKey
        this.sessionToken = ""
        this.region = region
        this.endpoint = ""
        this.bucket = ""
        this.insecureHttp = false
        this.virtualHostedStyle = false
    }

    public init(accessKeyId: String, secretAccessKey: String, sessionToken: String,
                region: String) {
        this.accessKeyId = accessKeyId
        this.secretAccessKey = secretAccessKey
        this.sessionToken = sessionToken
        this.region = region
        this.endpoint = ""
        this.bucket = ""
        this.insecureHttp = false
        this.virtualHostedStyle = false
    }

    public init(accessKeyId: String, secretAccessKey: String, sessionToken: String,
                region: String, endpoint: String, bucket: String) {
        this.accessKeyId = accessKeyId
        this.secretAccessKey = secretAccessKey
        this.sessionToken = sessionToken
        this.region = region
        this.endpoint = endpoint
        this.bucket = bucket
        this.insecureHttp = false
        this.virtualHostedStyle = false
    }

    /// 是否有有效凭证
    public func isValid(): Bool {
        return accessKeyId.size > 0 && secretAccessKey.size > 0
    }

    /// 估算内存大小
    /// 对应 Bun: S3Credentials.estimatedSize()
    public func estimatedSize(): Int64 {
        return accessKeyId.size + secretAccessKey.size + region.size +
               endpoint.size + bucket.size + sessionToken.size + 64
    }
}

// ============================================================================
// S3 存储类别
// 严格翻译自: src/s3_signing/storage_class.zig
// ============================================================================

/// S3 存储类别
/// 对应 Bun: StorageClass enum
public enum S3StorageClass {
    | Standard          // STANDARD
    | ReducedRedundancy // REDUCED_REDUNDANCY
    | StandardIa        // STANDARD_IA
    | OnezoneIa         // ONEZONE_IA
    | IntelligentTiering // INTELLIGENT_TIERING
    | Glacier           // GLACIER
    | DeepArchive       // DEEP_ARCHIVE
    | Outposts          // OUTPOSTS

    public func toString(): String {
        match (this) {
            case Standard => "STANDARD"
            case ReducedRedundancy => "REDUCED_REDUNDANCY"
            case StandardIa => "STANDARD_IA"
            case OnezoneIa => "ONEZONE_IA"
            case IntelligentTiering => "INTELLIGENT_TIERING"
            case Glacier => "GLACIER"
            case DeepArchive => "DEEP_ARCHIVE"
            case Outposts => "OUTPOSTS"
        }
    }
}

// ============================================================================
// S3 ACL
// 严格翻译自: src/s3_signing/acl.zig
// ============================================================================

/// S3 ACL 权限
/// 对应 Bun: ACL enum
public enum S3Acl {
    | Private           // private
    | PublicRead        // public-read
    | PublicReadWrite   // public-read-write
    | AuthenticatedRead // authenticated-read
    | AwsExecRead       // aws-exec-read
    | BucketOwnerRead   // bucket-owner-read
    | BucketOwnerFullControl // bucket-owner-full-control

    public func toString(): String {
        match (this) {
            case Private => "private"
            case PublicRead => "public-read"
            case PublicReadWrite => "public-read-write"
            case AuthenticatedRead => "authenticated-read"
            case AwsExecRead => "aws-exec-read"
            case BucketOwnerRead => "bucket-owner-read"
            case BucketOwnerFullControl => "bucket-owner-full-control"
        }
    }
}

// ============================================================================
// 签名结果
// 严格翻译自: credentials.zig SignResult
// ============================================================================

/// S3 签名结果
/// 对应 Bun: S3Credentials.SignResult
public class SignResult {
    /// AMZ 日期
    public var amzDate: String
    /// 主机名
    public var host: String
    /// Authorization header 值
    public var authorization: String
    /// 签名后的 URL (用于 presigned URL)
    public var url: String
    /// 附加的 HTTP 头
    public var headers: HashMap<String, String>
    /// Content-Disposition
    public var contentDisposition: String
    /// Content-Encoding
    public var contentEncoding: String
    /// Content-MD5
    public var contentMd5: String
    /// Session Token
    public var sessionToken: String
    /// 存储类别
    public var storageClass: ?S3StorageClass
    /// ACL
    public var acl: ?S3Acl

    public init() {
        amzDate = ""
        host = ""
        authorization = ""
        url = ""
        headers = HashMap<String, String>()
        contentDisposition = ""
        contentEncoding = ""
        contentMd5 = ""
        sessionToken = ""
        storageClass = None
        acl = None
    }
}

// ============================================================================
// 签名选项
// 严格翻译自: credentials.zig SignOptions
// ============================================================================

/// S3 签名选项
/// 对应 Bun: S3Credentials.SignOptions
public class S3SignOptions {
    /// 请求路径
    public var path: String
    /// HTTP 方法
    public var method: String
    /// 内容哈希 (SHA256 hex), 默认 "UNSIGNED-PAYLOAD"
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
    public var storageClass: ?S3StorageClass
    /// 是否请求者付费
    public var requestPayer: Bool

    public init(path: String, method: String) {
        this.path = path
        this.method = method
        this.contentHash = None
        this.contentMd5 = None
        this.searchParams = None
        this.contentDisposition = None
        this.contentType = None
        this.contentEncoding = None
        this.acl = None
        this.storageClass = None
        this.requestPayer = false
    }
}

/// Presigned URL 选项
/// 对应 Bun: S3Credentials.SignQueryOptions
public class PresignedUrlOptions {
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
// S3Signer - S3 签名器
// 严格翻译自: credentials.zig S3Credentials.signRequest()
//   AWS Signature Version 4 签名流程:
//   1. 构造 Canonical Request
//   2. 创建 String-to-Sign
//   3. 计算签名密钥 (日期/区域/服务派生)
//   4. 计算签名
//   5. 添加到请求头
// ============================================================================

/// S3 请求签名器
/// 对应 Bun: S3Credentials.signRequest()
public class S3Signer {
    /// 服务名称 (固定为 "s3")
    private static let SERVICE_NAME: String = "s3"
    /// HMAC 摘要长度
    private static let HMAC_DIGEST_LEN: Int64 = 32

    /// 签名 S3 请求 (生成 Authorization header)
    /// 严格翻译自 Bun: S3Credentials.signRequest(options, false, null)
    public static func signRequest(credentials: AwsCredentials,
                                    options: S3SignOptions): Result<SignResult, BaoError> {
        if (!credentials.isValid()) {
            return Result<SignResult, BaoError>.Err(BaoError(ErrorCode.InvalidArgument, "Missing AWS credentials"))
        }

        let region = if (credentials.region.size > 0) {
            credentials.region
        } else {
            guessRegion(credentials.endpoint)
        }

        // 解析路径
        var path = options.path
        if (s3StartsWith(path, "/")) { path = path[1..] }
        if (s3StartsWith(path, "\\")) { path = path[1..] }

        var bucket = credentials.bucket
        if (!credentials.virtualHostedStyle && bucket.size == 0) {
            // 从路径中提取 bucket
            let slashIdxOpt = path.indexOf("/")
            if (slashIdxOpt.isSome()) {
                let slashIdx = slashIdxOpt.getOrThrow()
                bucket = path[0..slashIdx]
                path = path[(slashIdx + 1)..]
            }
        }

        // 规范化路径
        path = normalizePath(path)
        bucket = normalizePath(bucket)

        if (path.size == 0) {
            path = ""
        }

        // URI 编码
        let encodedBucket = encodeURIComponent(bucket, false)
        let encodedPath = encodeURIComponent(path, false)

        // 构建主机
        var host = credentials.endpoint
        var extraPath = ""
        if (host.size > 0) {
            let slashPosOpt = host.indexOf("/")
            if (slashPosOpt.isSome()) {
                let slashPos = slashPosOpt.getOrThrow()
                extraPath = host[slashPos..]
                host = host[0..slashPos]
            }
        } else {
            if (credentials.virtualHostedStyle) {
                host = "${encodedBucket}.s3.${region}.amazonaws.com"
            } else {
                host = "s3.${region}.amazonaws.com"
            }
        }

        // 规范化路径
        let normalizedPath = if (credentials.virtualHostedStyle) {
            "${extraPath}/${encodedPath}"
        } else {
            "${extraPath}/${encodedBucket}/${encodedPath}"
        }

        // 获取 AMZ 日期
        let amzDate = getAmzDate()
        let amzDay = amzDate[0..8]

        // 内容哈希
        let awsContentHash = match (options.contentHash) {
            case Some(h) => h
            case None => "UNSIGNED-PAYLOAD"
        }

        // 构建 signed headers 列表
        // 对应 Bun: SignedHeaders.get(key)
        let hasContentDisposition = options.contentDisposition.isSome() &&
                                     match (options.contentDisposition) {
                                         case Some(s) => s.size > 0
                                         case None => false
                                     }
        let hasContentEncoding = options.contentEncoding.isSome() &&
                                  match (options.contentEncoding) {
                                      case Some(s) => s.size > 0
                                      case None => false
                                  }
        let hasContentMd5 = options.contentMd5.isSome()
        let hasAcl = options.acl.isSome()
        let hasSessionToken = credentials.sessionToken.size > 0
        let hasStorageClass = options.storageClass.isSome()

        var signedHeaders = StringBuilder()
        if (hasContentDisposition) { signedHeaders.append("content-disposition;") }
        if (hasContentEncoding) { signedHeaders.append("content-encoding;") }
        if (hasContentMd5) { signedHeaders.append("content-md5;") }
        signedHeaders.append("host;")
        if (hasAcl) { signedHeaders.append("x-amz-acl;") }
        signedHeaders.append("x-amz-content-sha256;x-amz-date")
        if (options.requestPayer) { signedHeaders.append(";x-amz-request-payer") }
        if (hasSessionToken) { signedHeaders.append(";x-amz-security-token") }
        if (hasStorageClass) { signedHeaders.append(";x-amz-storage-class") }
        let signedHeadersStr = signedHeaders.toString()

        // 构建 Canonical Request
        // 对应 Bun: CanonicalRequest.format()
        let queryString = match (options.searchParams) {
            case Some(p) => if (s3StartsWith(p, "?")) { p[1..] } else { p }
            case None => ""
        }

        let canonicalRequest = buildCanonicalRequest(
            options.method, normalizedPath, queryString,
            hasContentDisposition, hasContentEncoding, hasContentMd5,
            options.contentDisposition, options.contentEncoding, options.contentMd5,
            host, options.acl,
            awsContentHash, amzDate,
            hasSessionToken, credentials.sessionToken,
            hasStorageClass, options.storageClass,
            options.requestPayer,
            signedHeadersStr
        )

        // 计算 canonical request 的 SHA256 哈希
        let canonicalHash = Sha256.hashHex(s3StringToBytes(canonicalRequest))

        // 构建 String-to-Sign
        // 对应 Bun: "AWS4-HMAC-SHA256\n{date}\n{day}/{region}/s3/aws4_request\n{hash}"
        let stringToSign = "AWS4-HMAC-SHA256\n${amzDate}\n${amzDay}/${region}/${SERVICE_NAME}/aws4_request\n${canonicalHash}"

        // 派生签名密钥
        // 对应 Bun: sigDate -> sigDateRegion -> sigDateRegionService -> sigDateRegionServiceReq
        let signingKey = deriveSigningKey(credentials.secretAccessKey, amzDay, region)

        // 计算签名
        let signature = HmacSha256.hmacHex(signingKey, s3StringToBytes(stringToSign))

        // 构建 Authorization header
        // 对应 Bun: "AWS4-HMAC-SHA256 Credential={key}/{day}/{region}/s3/aws4_request, SignedHeaders={headers}, Signature={sig}"
        let authorization = "AWS4-HMAC-SHA256 Credential=${credentials.accessKeyId}/${amzDay}/${region}/${SERVICE_NAME}/aws4_request, SignedHeaders=${signedHeadersStr}, Signature=${signature}"

        // 构建结果
        let protocol = if (credentials.insecureHttp) { "http" } else { "https" }
        let result = SignResult()
        result.amzDate = amzDate
        result.host = host
        result.authorization = authorization
        result.url = "${protocol}://${host}${normalizedPath}"
        result.storageClass = options.storageClass
        result.acl = options.acl

        // 构建请求头
        result.headers.put("x-amz-content-sha256", awsContentHash)
        result.headers.put("x-amz-date", amzDate)
        result.headers.put("Host", host)
        result.headers.put("Authorization", authorization)

        if (hasAcl) {
            match (options.acl) {
                case Some(acl) => result.headers.put("x-amz-acl", acl.toString())
                case None => ()
            }
        }
        if (hasSessionToken) {
            result.sessionToken = credentials.sessionToken
            result.headers.put("x-amz-security-token", credentials.sessionToken)
        }
        if (hasStorageClass) {
            match (options.storageClass) {
                case Some(sc) => result.headers.put("x-amz-storage-class", sc.toString())
                case None => ()
            }
        }
        if (hasContentDisposition) {
            match (options.contentDisposition) {
                case Some(cd) =>
                    result.contentDisposition = cd
                    result.headers.put("content-disposition", cd)
                case None => ()
            }
        }
        if (hasContentEncoding) {
            match (options.contentEncoding) {
                case Some(ce) =>
                    result.contentEncoding = ce
                    result.headers.put("content-encoding", ce)
                case None => ()
            }
        }
        if (hasContentMd5) {
            match (options.contentMd5) {
                case Some(md5) =>
                    result.contentMd5 = md5
                    result.headers.put("content-md5", md5)
                case None => ()
            }
        }
        if (options.requestPayer) {
            result.headers.put("x-amz-request-payer", "requester")
        }

        return Result<SignResult, BaoError>.Ok(result)
    }

    /// 生成 Presigned URL
    /// 严格翻译自 Bun: signRequest(options, true, SignQueryOptions)
    public static func presignedUrl(credentials: AwsCredentials,
                                     options: S3SignOptions,
                                     presignedOptions: PresignedUrlOptions): Result<String, BaoError> {
        if (!credentials.isValid()) {
            return Result<String, BaoError>.Err(BaoError(ErrorCode.InvalidArgument, "Missing AWS credentials"))
        }

        let region = if (credentials.region.size > 0) {
            credentials.region
        } else {
            guessRegion(credentials.endpoint)
        }

        var path = options.path
        if (s3StartsWith(path, "/")) { path = path[1..] }
        path = normalizePath(path)

        let encodedPath = encodeURIComponent(path, false)

        var host = if (credentials.endpoint.size > 0) {
            credentials.endpoint
        } else {
            "s3.${region}.amazonaws.com"
        }

        let normalizedPath = "/${encodedPath}"
        let amzDate = getAmzDate()
        let amzDay = amzDate[0..8]
        let awsContentHash = "UNSIGNED-PAYLOAD"
        let protocol = if (credentials.insecureHttp) { "http" } else { "https" }

        // 派生签名密钥
        let signingKey = deriveSigningKey(credentials.secretAccessKey, amzDay, region)

        // 构建 presigned URL 的 canonical request
        // 查询参数按字母序排列
        let credential = "${credentials.accessKeyId}/${amzDay}/${region}/${SERVICE_NAME}/aws4_request"

        var queryParts = ArrayList<String>()
        queryParts.append("X-Amz-Algorithm=AWS4-HMAC-SHA256")
        queryParts.append("X-Amz-Credential=${encodeURIComponent(credential, true)}")
        queryParts.append("X-Amz-Date=${amzDate}")
        queryParts.append("X-Amz-Expires=${presignedOptions.expires}")
        if (credentials.sessionToken.size > 0) {
            queryParts.append("X-Amz-Security-Token=${encodeURIComponent(credentials.sessionToken, true)}")
        }
        queryParts.append("X-Amz-SignedHeaders=host")

        // 构建查询字符串
        let queryString = s3Join(queryParts, "&")

        // Canonical request for presigned URL
        let canonicalRequest = "${options.method}\n${normalizedPath}\n${queryString}\nhost:${host}\n\nhost\n${awsContentHash}"

        let canonicalHash = Sha256.hashHex(s3StringToBytes(canonicalRequest))
        let stringToSign = "AWS4-HMAC-SHA256\n${amzDate}\n${amzDay}/${region}/${SERVICE_NAME}/aws4_request\n${canonicalHash}"
        let signature = HmacSha256.hmacHex(signingKey, s3StringToBytes(stringToSign))

        // 构建最终 URL
        let url = "${protocol}://${host}${normalizedPath}?${queryString}&X-Amz-Signature=${signature}"

        return Result<String, BaoError>.Ok(url)
    }

    // ========================================================================
    // 内部方法
    // ========================================================================

    /// 构建 Canonical Request
    /// 严格对应 Bun: CanonicalRequest.format()
    private static func buildCanonicalRequest(
        method: String, path: String, queryString: String,
        hasContentDisposition: Bool, hasContentEncoding: Bool, hasContentMd5: Bool,
        contentDisposition: ?String, contentEncoding: ?String, contentMd5: ?String,
        host: String, acl: ?S3Acl,
        contentHash: String, amzDate: String,
        hasSessionToken: Bool, sessionToken: String,
        hasStorageClass: Bool, storageClass: ?S3StorageClass,
        requestPayer: Bool,
        signedHeaders: String
    ): String {
        let sb = StringBuilder()
        // 方法 + 路径 + 查询
        sb.append("${method}\n${path}\n${queryString}\n")

        // 请求头 (按字母序)
        if (hasContentDisposition) {
            match (contentDisposition) {
                case Some(cd) => sb.append("content-disposition:${cd}\n")
                case None => ()
            }
        }
        if (hasContentEncoding) {
            match (contentEncoding) {
                case Some(ce) => sb.append("content-encoding:${ce}\n")
                case None => ()
            }
        }
        if (hasContentMd5) {
            match (contentMd5) {
                case Some(md5) => sb.append("content-md5:${md5}\n")
                case None => ()
            }
        }
        sb.append("host:${host}\n")
        if (hasContentDisposition || hasContentEncoding || hasContentMd5) {
            match (acl) {
                case Some(a) => sb.append("x-amz-acl:${a.toString()}\n")
                case None => ()
            }
        } else {
            match (acl) {
                case Some(a) => sb.append("x-amz-acl:${a.toString()}\n")
                case None => ()
            }
        }
        sb.append("x-amz-content-sha256:${contentHash}\n")
        sb.append("x-amz-date:${amzDate}\n")
        if (requestPayer) {
            sb.append("x-amz-request-payer:requester\n")
        }
        if (hasSessionToken) {
            sb.append("x-amz-security-token:${sessionToken}\n")
        }
        if (hasStorageClass) {
            match (storageClass) {
                case Some(sc) => sb.append("x-amz-storage-class:${sc.toString()}\n")
                case None => ()
            }
        }

        // 空行 + signed headers + hash
        sb.append("\n${signedHeaders}\n${contentHash}")

        return sb.toString()
    }

    /// 派生签名密钥
    /// 严格对应 Bun: sigDate -> sigDateRegion -> sigDateRegionService -> result
    /// HMAC key derivation: date/region/service/aws4_request
    private static func deriveSigningKey(secretKey: String, date: String,
                                          region: String): Array<UInt8> {
        let kDate = HmacSha256.hmac("AWS4${secretKey}", date)
        let kRegion = HmacSha256.hmac(kDate, s3StringToBytes(region))
        let kService = HmacSha256.hmac(kRegion, s3StringToBytes(SERVICE_NAME))
        let kSigning = HmacSha256.hmac(kService, s3StringToBytes("aws4_request"))
        return kSigning
    }

    /// URI 编码
    /// 严格对应 Bun: encodeURIComponent(input, buffer, encode_slash)
    /// RFC 3986 unreserved: A-Z a-z 0-9 - _ . ~
    public static func encodeURIComponent(input: String, encodeSlash: Bool): String {
        let sb = StringBuilder()
        for (i in 0..input.size) {
            let c = input[Int64(i)]
            let v = Int64(c)
            if ((c >= UInt8(65) && c <= UInt8(90)) ||
                (c >= UInt8(97) && c <= UInt8(122)) ||
                (c >= UInt8(48) && c <= UInt8(57)) ||
                c == UInt8(45) || c == UInt8(95) || c == UInt8(46) || c == UInt8(126)) {
                sb.append(Rune(UInt32(c)))
            } else if (!encodeSlash && (c == UInt8(47) || c == UInt8(92))) {
                sb.append(Rune(UInt32(UInt8(47))))
            } else {
                let high = (v >> 4) & 0x0F
                let low = v & 0x0F
                sb.append(Rune(UInt32(UInt8(37))))
                sb.append(toHexRune(high))
                sb.append(toHexRune(low))
            }
        }
        return sb.toString()
    }

    /// 数字转 hex 字符
    private static func toHexRune(v: Int64): Rune {
        if (v >= 0 && v <= 9) { return Rune(UInt32(UInt8(v + 48))) }
        return Rune(UInt32(UInt8(v + 55)))
    }

    /// 获取 AMZ 日期
    /// 严格对应 Bun: getAMZDate()
    /// 格式: YYYYMMDDTHHmmssZ
    public static func getAmzDate(): String {
        // 使用 clock_gettime 获取当前 UTC 时间
        // 简化: 使用系统时间格式化
        // 完整实现需要 gmtime_r
        // 此处返回占位符, 实际应使用实时时钟
        return formatCurrentTime()
    }

    /// 格式化当前时间为 AMZ 格式
    private static func formatCurrentTime(): String {
        let now = DateTime.now().toUnixTimeStamp().toMilliseconds()
        return formatTimestampAmz(now)
    }

    /// 时间戳毫秒转 AMZ 日期格式
    /// 格式: YYYYMMDDTHHmmssZ
    public static func formatTimestampAmz(millis: Int64): String {
        // 简化的 Unix 时间戳转 UTC 日期
        // 完整实现需要 gmtime_r
        let totalSeconds = millis / 1000
        let days = totalSeconds / 86400
        let timeOfDay = totalSeconds % 86400
        let hours = timeOfDay / 3600
        let minutes = (timeOfDay % 3600) / 60
        let seconds = timeOfDay % 60

        // 从 1970-01-01 计算年月日
        let date = daysToDate(days)
        let year = date[0]
        let month = date[1]
        let day = date[2]

        return "${pad4(year)}${pad2(month)}${pad2(day)}T${pad2(hours)}${pad2(minutes)}${pad2(seconds)}Z"
    }

    /// 从 1970-01-01 起的天数转年月日
    private static func daysToDate(days: Int64): (Int64, Int64, Int64) {
        // Zeller 算法简化版
        var y = Int64(1970)
        var d = days
        let daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

        // 年
        var yearDays = if (isLeapYear(y)) { 366 } else { 365 }
        while (d >= yearDays) {
            d -= yearDays
            y += 1
            yearDays = if (isLeapYear(y)) { 366 } else { 365 }
        }

        // 月
        var m = 0
        while (m < 12) {
            let dim = if (m == 1 && isLeapYear(y)) { 29 } else { daysInMonth[m] }
            if (d < dim) { break }
            d -= dim
            m += 1
        }

        return (y, Int64(m + 1), d + 1)
    }

    private static func isLeapYear(y: Int64): Bool {
        return (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0)
    }

    private static func pad4(n: Int64): String {
        if (n < 10) { return "000${n}" }
        if (n < 100) { return "00${n}" }
        if (n < 1000) { return "0${n}" }
        return "${n}"
    }

    private static func pad2(n: Int64): String {
        if (n < 10) { return "0${n}" }
        return "${n}"
    }

    /// 规范化路径名
    /// 对应 Bun: normalizeName(name)
    private static func normalizePath(name: String): String {
        if (name.size == 0) { return name }
        var result = name
        while (s3StartsWith(result, "/") || s3StartsWith(result, "\\")) {
            result = result[1..]
        }
        while (s3EndsWith(result, "/") || s3EndsWith(result, "\\")) {
            result = result[0..(result.size - 1)]
        }
        return result
    }

    /// 猜测区域
    /// 对应 Bun: guessRegion(endpoint)
    public static func guessRegion(endpoint: String): String {
        if (endpoint.size > 0) {
            if (s3EndsWith(endpoint, ".r2.cloudflarestorage.com")) { return "auto" }
            let s3IdxOpt = endpoint.indexOf(".s3.")
            let awsIdxOpt = endpoint.indexOf(".amazonaws.com")
            if (s3IdxOpt.isSome() && awsIdxOpt.isSome()) {
                return endpoint[(s3IdxOpt.getOrThrow() + 4)..awsIdxOpt.getOrThrow()]
            }
            return "auto"
        }
        return "us-east-1"
    }

    /// 猜测 bucket 名
    /// 对应 Bun: guessBucket(endpoint)
    public static func guessBucket(endpoint: String): ?String {
        let awsIdxOpt = endpoint.indexOf(".amazonaws.com")
        if (awsIdxOpt.isSome()) {
            let s3IdxOpt = endpoint.indexOf(".s3.")
            if (s3IdxOpt.isSome()) {
                let s3Idx = s3IdxOpt.getOrThrow()
                let startOpt = endpoint.indexOf("/")
                if (startOpt.isSome()) {
                    return Some(endpoint[(startOpt.getOrThrow() + 1)..s3Idx])
                }
                return Some(endpoint[0..s3Idx])
            }
        }
        let r2IdxOpt = endpoint.indexOf(".r2.cloudflarestorage.com")
        if (r2IdxOpt.isSome()) {
            let r2Idx = r2IdxOpt.getOrThrow()
            let dotIdxOpt = endpoint.indexOf(".")
            if (dotIdxOpt.isSome() && r2Idx == dotIdxOpt.getOrThrow()) { return None }
            if (!dotIdxOpt.isSome()) { return None }
            let dotIdx = dotIdxOpt.getOrThrow()
            let startOpt = endpoint.indexOf("/")
            if (startOpt.isSome()) {
                return Some(endpoint[(startOpt.getOrThrow() + 1)..dotIdx])
            }
            return Some(endpoint[0..dotIdx])
        }
        return None
    }
}

// ============================================================================
// 工具函数
// ============================================================================

/// 字符串转字节数组
private func s3StringToBytes(s: String): Array<UInt8> {
    let bytes = ArrayList<UInt8>()
    for (c in s) { bytes.append(c) }
    return bytes.toOwnedSlice()
}

private func s3StartsWith(s: String, prefix: String): Bool {
    if (s.size < prefix.size) { return false }
    return s[0..prefix.size] == prefix
}

private func s3EndsWith(s: String, suffix: String): Bool {
    if (s.size < suffix.size) { return false }
    return s[(s.size - suffix.size)..] == suffix
}

private func s3Join(parts: ArrayList<String>, sep: String): String {
    let sb = StringBuilder()
    for (i in 0..parts.size) {
        if (i > 0) { sb.append(sep) }
        sb.append(parts[Int64(i)])
    }
    return sb.toString()
}
