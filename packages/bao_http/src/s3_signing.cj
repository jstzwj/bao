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
                                    options: S3SignOptions): Result<SignResult> {
        if (!credentials.isValid()) {
            return Result<SignResult>.Err(BaoError(ErrorCode.InvalidArgument, "Missing AWS credentials"))
        }

        let region = if (credentials.region.size > 0) {
            credentials.region
        } else {
            guessRegion(credentials.endpoint)
        }

        // 解析路径
        var path = options.path
        if (path.startsWith("/")) { path = path.substring(1) }
        if (path.startsWith("\\")) { path = path.substring(1) }

        var bucket = credentials.bucket
        if (!credentials.virtualHostedStyle && bucket.size == 0) {
            // 从路径中提取 bucket
            let slashIdx = path.indexOf("/")
            if (slashIdx >= 0) {
                bucket = path.substring(0, Int64(slashIdx))
                path = path.substring(Int64(slashIdx + 1))
            }
        }

        // 规范化路径
        path = normalizePath(path)
        bucket = normalizePath(bucket)

        if (path.size == 0) {
            path = ""
        }

        // URI 编码
        val encodedBucket = encodeURIComponent(bucket, false)
        val encodedPath = encodeURIComponent(path, false)

        // 构建主机
        var host = credentials.endpoint
        var extraPath = ""
        if (host.size > 0) {
            let slashPos = host.indexOf("/")
            if (slashPos >= 0) {
                extraPath = host.substring(Int64(slashPos))
                host = host.substring(0, Int64(slashPos))
            }
        } else {
            if (credentials.virtualHostedStyle) {
                host = "${encodedBucket}.s3.${region}.amazonaws.com"
            } else {
                host = "s3.${region}.amazonaws.com"
            }
        }

        // 规范化路径
        val normalizedPath = if (credentials.virtualHostedStyle) {
            "${extraPath}/${encodedPath}"
        } else {
            "${extraPath}/${encodedBucket}/${encodedPath}"
        }

        // 获取 AMZ 日期
        val amzDate = getAmzDate()
        val amzDay = amzDate.substring(0, 8)

        // 内容哈希
        val awsContentHash = match (options.contentHash) {
            case Some(h) => h
            case None => "UNSIGNED-PAYLOAD"
        }

        // 构建 signed headers 列表
        // 对应 Bun: SignedHeaders.get(key)
        val hasContentDisposition = options.contentDisposition != None &&
                                     match (options.contentDisposition) {
                                         case Some(s) => s.size > 0
                                         case None => false
                                     }
        val hasContentEncoding = options.contentEncoding != None &&
                                  match (options.contentEncoding) {
                                      case Some(s) => s.size > 0
                                      case None => false
                                  }
        val hasContentMd5 = options.contentMd5 != None
        val hasAcl = options.acl != None
        val hasSessionToken = credentials.sessionToken.size > 0
        val hasStorageClass = options.storageClass != None

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
        val queryString = match (options.searchParams) {
            case Some(p) => if (p.startsWith("?")) { p.substring(1) } else { p }
            case None => ""
        }

        val canonicalRequest = buildCanonicalRequest(
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
        val canonicalHash = Sha256.hashHex(stringToBytes(canonicalRequest))

        // 构建 String-to-Sign
        // 对应 Bun: "AWS4-HMAC-SHA256\n{date}\n{day}/{region}/s3/aws4_request\n{hash}"
        val stringToSign = "AWS4-HMAC-SHA256\n${amzDate}\n${amzDay}/${region}/${SERVICE_NAME}/aws4_request\n${canonicalHash}"

        // 派生签名密钥
        // 对应 Bun: sigDate -> sigDateRegion -> sigDateRegionService -> sigDateRegionServiceReq
        val signingKey = deriveSigningKey(credentials.secretAccessKey, amzDay, region)

        // 计算签名
        val signature = HmacSha256.hmacHex(signingKey, stringToSign)

        // 构建 Authorization header
        // 对应 Bun: "AWS4-HMAC-SHA256 Credential={key}/{day}/{region}/s3/aws4_request, SignedHeaders={headers}, Signature={sig}"
        val authorization = "AWS4-HMAC-SHA256 Credential=${credentials.accessKeyId}/${amzDay}/${region}/${SERVICE_NAME}/aws4_request, SignedHeaders=${signedHeadersStr}, Signature=${signature}"

        // 构建结果
        val protocol = if (credentials.insecureHttp) { "http" } else { "https" }
        val result = SignResult()
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

        return Result<SignResult>.Ok(result)
    }

    /// 生成 Presigned URL
    /// 严格翻译自 Bun: signRequest(options, true, SignQueryOptions)
    public static func presignedUrl(credentials: AwsCredentials,
                                     options: S3SignOptions,
                                     presignedOptions: PresignedUrlOptions): Result<String> {
        if (!credentials.isValid()) {
            return Result<String>.Err(BaoError(ErrorCode.InvalidArgument, "Missing AWS credentials"))
        }

        let region = if (credentials.region.size > 0) {
            credentials.region
        } else {
            guessRegion(credentials.endpoint)
        }

        var path = options.path
        if (path.startsWith("/")) { path = path.substring(1) }
        path = normalizePath(path)

        val encodedPath = encodeURIComponent(path, false)

        var host = if (credentials.endpoint.size > 0) {
            credentials.endpoint
        } else {
            "s3.${region}.amazonaws.com"
        }

        val normalizedPath = "/${encodedPath}"
        val amzDate = getAmzDate()
        val amzDay = amzDate.substring(0, 8)
        val awsContentHash = "UNSIGNED-PAYLOAD"
        val protocol = if (credentials.insecureHttp) { "http" } else { "https" }

        // 派生签名密钥
        val signingKey = deriveSigningKey(credentials.secretAccessKey, amzDay, region)

        // 构建 presigned URL 的 canonical request
        // 查询参数按字母序排列
        val credential = "${credentials.accessKeyId}/${amzDay}/${region}/${SERVICE_NAME}/aws4_request"

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
        val queryString = queryParts.toArray().toString("&")

        // Canonical request for presigned URL
        val canonicalRequest = "${options.method}\n${normalizedPath}\n${queryString}\nhost:${host}\n\nhost\n${awsContentHash}"

        val canonicalHash = Sha256.hashHex(stringToBytes(canonicalRequest))
        val stringToSign = "AWS4-HMAC-SHA256\n${amzDate}\n${amzDay}/${region}/${SERVICE_NAME}/aws4_request\n${canonicalHash}"
        val signature = HmacSha256.hmacHex(signingKey, stringToSign)

        // 构建最终 URL
        val url = "${protocol}://${host}${normalizedPath}?${queryString}&X-Amz-Signature=${signature}"

        return Result<String>.Ok(url)
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
        val kDate = HmacSha256.hmac("AWS4${secretKey}", date)
        val kRegion = HmacSha256.hmac(kDate, region)
        val kService = HmacSha256.hmac(kRegion, SERVICE_NAME)
        val kSigning = HmacSha256.hmac(kService, "aws4_request")
        return kSigning
    }

    /// URI 编码
    /// 严格对应 Bun: encodeURIComponent(input, buffer, encode_slash)
    /// RFC 3986 unreserved: A-Z a-z 0-9 - _ . ~
    public static func encodeURIComponent(input: String, encodeSlash: Bool): String {
        let sb = StringBuilder()
        for (i in 0..input.size) {
            let c = input[Int64(i)]
            let v = Int64(c.value)
            if ((v >= Int64('A') && v <= Int64('Z')) ||
                (v >= Int64('a') && v <= Int64('z')) ||
                (v >= Int64('0') && v <= Int64('9')) ||
                v == Int64('-') || v == Int64('_') || v == Int64('.') || v == Int64('~')) {
                sb.append(c)
            } else if (!encodeSlash && (c == Char('/') || c == Char('\\'))) {
                sb.append(if (c == Char('\\')) { "/" } else { c })
            } else {
                let high = (v >> 4) & 0x0F
                let low = v & 0x0F
                sb.append("%")
                sb.append(toHexChar(high))
                sb.append(toHexChar(low))
            }
        }
        return sb.toString()
    }

    /// 数字转 hex 字符
    private static func toHexChar(v: Int64): Char {
        if (v >= 0 && v <= 9) { return Char(Int64('0') + v) }
        return Char(Int64('A') + v - 10)
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
        // 对应 Bun: getAMZDate 使用 std.time.milliTimestamp
        // 此处使用 C FFI time() + gmtime_r
        // 简化实现
        let now = System.currentTimeMillis()
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
        val (year, month, day) = daysToDate(days)

        return "${pad4(year)}${pad2(month)}${pad2(day)}T${pad2(hours)}${pad2(minutes)}${pad2(seconds)}Z"
    }

    /// 从 1970-01-01 起的天数转年月日
    private static func daysToDate(days: Int64): (Int64, Int64, Int64) {
        // Zeller 算法简化版
        var y = Int64(1970)
        var d = days
        val daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

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
        while (result.startsWith("/") || result.startsWith("\\")) {
            result = result.substring(1)
        }
        while (result.endsWith("/") || result.endsWith("\\")) {
            result = result.substring(0, result.size - 1)
        }
        return result
    }

    /// 猜测区域
    /// 对应 Bun: guessRegion(endpoint)
    public static func guessRegion(endpoint: String): String {
        if (endpoint.size > 0) {
            if (endpoint.endsWith(".r2.cloudflarestorage.com")) { return "auto" }
            let s3Idx = endpoint.indexOf(".s3.")
            let awsIdx = endpoint.indexOf(".amazonaws.com")
            if (s3Idx >= 0 && awsIdx >= 0) {
                return endpoint.substring(Int64(s3Idx + 4), Int64(awsIdx))
            }
            return "auto"
        }
        return "us-east-1"
    }

    /// 猜测 bucket 名
    /// 对应 Bun: guessBucket(endpoint)
    public static func guessBucket(endpoint: String): ?String {
        let awsIdx = endpoint.indexOf(".amazonaws.com")
        if (awsIdx >= 0) {
            let s3Idx = endpoint.indexOf(".s3.")
            if (s3Idx >= 0) {
                let start = endpoint.indexOf("/")
                if (start >= 0) {
                    return endpoint.substring(Int64(start + 1), Int64(s3Idx))
                }
                return endpoint.substring(0, Int64(s3Idx))
            }
        }
        let r2Idx = endpoint.indexOf(".r2.cloudflarestorage.com")
        if (r2Idx >= 0) {
            let dotIdx = endpoint.indexOf(".")
            if (dotIdx >= 0 && r2Idx == dotIdx) { return None }
            let start = endpoint.indexOf("/")
            if (start >= 0) {
                return endpoint.substring(Int64(start + 1), Int64(dotIdx))
            }
            return endpoint.substring(0, Int64(dotIdx))
        }
        return None
    }
}

// ============================================================================
// 工具函数
// ============================================================================

/// 字符串转字节数组
private func stringToBytes(s: String): Array<UInt8> {
    var bytes = Array<UInt8>()
    for (c in s) { bytes.append(UInt8(c.value)) }
    return bytes
}
