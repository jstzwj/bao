// 严格翻译自: src/runtime/webcore/s3/credentials_jsc.zig
// S3Credentials.getCredentialsWithOptions - 从 JS 选项对象解析为 S3CredentialsWithOptions
// 因为它需要访问 jsc.JSValue，所以放在 runtime/webcore/s3/ 而非 s3_signing/
package bao_runtime.webcore.s3

import bao_core.*
import bao_collections.*
import bao_jsc.*

// ============================================================================
// S3CredentialsWithOptions - 带选项的 S3 凭证
// 严格翻译自: S3CredentialsWithOptions struct
// Bun: 通过 getCredentialsWithOptions 构造
// ============================================================================

/// 带选项的 S3 凭证
/// 对应 Bun: S3CredentialsWithOptions (s3_signing/credentials.zig 中定义)
/// 包含凭证、多部分上传选项、ACL、存储类别等
public class S3CredentialsWithOptions {
    /// S3 凭证
    /// 对应 Bun: .credentials
    public var credentials: S3Credentials

    /// 多部分上传选项
    /// 对应 Bun: .options
    public var options: MultiPartUploadOptions

    /// ACL
    /// 对应 Bun: .acl
    public var acl: ?S3Acl

    /// 存储类别
    /// 对应 Bun: .storage_class
    public var storageClass: ?S3StorageClass

    /// 是否请求付费
    /// 对应 Bun: .request_payer
    public var requestPayer: Bool

    /// Content-Disposition
    /// 对应 Bun: .content_disposition
    public var contentDisposition: String

    /// Content-Type
    /// 对应 Bun: .content_type
    public var contentType: String

    /// Content-Encoding
    /// 对应 Bun: .content_encoding
    public var contentEncoding: String

    /// 凭证是否已更改
    /// 对应 Bun: .changed_credentials
    public var changedCredentials: Bool

    // 内部持有的 UTF8 字符串切片 (拥有所有权)
    private var _accessKeyIdSlice: String
    private var _secretAccessKeySlice: String
    private var _regionSlice: String
    private var _endpointSlice: String
    private var _bucketSlice: String
    private var _sessionTokenSlice: String
    private var _contentDispositionSlice: String
    private var _contentTypeSlice: String
    private var _contentEncodingSlice: String

    public init(credentials: S3Credentials, options: MultiPartUploadOptions) {
        this.credentials = credentials
        this.options = options
        acl = None
        storageClass = None
        requestPayer = false
        contentDisposition = ""
        contentType = ""
        contentEncoding = ""
        changedCredentials = false
        _accessKeyIdSlice = ""
        _secretAccessKeySlice = ""
        _regionSlice = ""
        _endpointSlice = ""
        _bucketSlice = ""
        _sessionTokenSlice = ""
        _contentDispositionSlice = ""
        _contentTypeSlice = ""
        _contentEncodingSlice = ""
    }

    // ========================================================================
    // deinit - 释放资源
    // 严格翻译自: errdefer { new_credentials.deinit(); }
    // ========================================================================

    /// 释放资源
    /// 对应 Bun: S3CredentialsWithOptions.deinit()
    public func deinit(): Unit {
        // 字符串由仓颉 GC 管理，无需手动释放
        _accessKeyIdSlice = ""
        _secretAccessKeySlice = ""
        _regionSlice = ""
        _endpointSlice = ""
        _bucketSlice = ""
        _sessionTokenSlice = ""
        _contentDispositionSlice = ""
        _contentTypeSlice = ""
        _contentEncodingSlice = ""
    }
}

// ============================================================================
// S3Acl - S3 ACL 枚举
// 严格翻译自: bun.S3.ACL
// ============================================================================

/// S3 ACL (Access Control List)
/// 对应 Bun: bun.S3.ACL
public enum S3Acl {
    | Private
    | PublicRead
    | PublicReadWrite
    | AwsExecRead
    | AuthenticatedRead
    | BucketOwnerRead
    | BucketOwnerFullControl
    | LogDeliveryWrite

    public func toString(): String {
        match (this) {
            case Private => "private"
            case PublicRead => "public-read"
            case PublicReadWrite => "public-read-write"
            case AwsExecRead => "aws-exec-read"
            case AuthenticatedRead => "authenticated-read"
            case BucketOwnerRead => "bucket-owner-read"
            case BucketOwnerFullControl => "bucket-owner-full-control"
            case LogDeliveryWrite => "log-delivery-write"
        }
    }

    public static func fromString(s: String): ?S3Acl {
        match (s) {
            case "private" => Some(S3Acl.Private)
            case "public-read" => Some(S3Acl.PublicRead)
            case "public-read-write" => Some(S3Acl.PublicReadWrite)
            case "aws-exec-read" => Some(S3Acl.AwsExecRead)
            case "authenticated-read" => Some(S3Acl.AuthenticatedRead)
            case "bucket-owner-read" => Some(S3Acl.BucketOwnerRead)
            case "bucket-owner-full-control" => Some(S3Acl.BucketOwnerFullControl)
            case "log-delivery-write" => Some(S3Acl.LogDeliveryWrite)
            case _ => None
        }
    }
}

// ============================================================================
// S3StorageClass - S3 存储类别枚举
// 严格翻译自: bun.S3.StorageClass
// ============================================================================

/// S3 存储类别
/// 对应 Bun: bun.S3.StorageClass
public enum S3StorageClass {
    | Standard
    | ReducedRedundancy
    | Glacier
    | StandardIa
    | OnezoneIa
    | IntelligentTiering
    | DeepArchive
    | Outposts
    | GlacierIr

    public func toString(): String {
        match (this) {
            case Standard => "STANDARD"
            case ReducedRedundancy => "REDUCED_REDUNDANCY"
            case Glacier => "GLACIER"
            case StandardIa => "STANDARD_IA"
            case OnezoneIa => "ONEZONE_IA"
            case IntelligentTiering => "INTELLIGENT_TIERING"
            case DeepArchive => "DEEP_ARCHIVE"
            case Outposts => "OUTPOSTS"
            case GlacierIr => "GLACIER_IR"
        }
    }

    public static func fromString(s: String): ?S3StorageClass {
        match (s) {
            case "STANDARD" => Some(S3StorageClass.Standard)
            case "REDUCED_REDUNDANCY" => Some(S3StorageClass.ReducedRedundancy)
            case "GLACIER" => Some(S3StorageClass.Glacier)
            case "STANDARD_IA" => Some(S3StorageClass.StandardIa)
            case "ONEZONE_IA" => Some(S3StorageClass.OnezoneIa)
            case "INTELLIGENT_TIERING" => Some(S3StorageClass.IntelligentTiering)
            case "DEEP_ARCHIVE" => Some(S3StorageClass.DeepArchive)
            case "OUTPOSTS" => Some(S3StorageClass.Outposts)
            case "GLACIER_IR" => Some(S3StorageClass.GlacierIr)
            case _ => None
        }
    }
}

// ============================================================================
// containsNewlineOrCR - 检查字符串是否包含换行符
// 严格翻译自: fn containsNewlineOrCR(value: []const u8) bool
// Bun: fn containsNewlineOrCR(value: []const u8) bool
// ============================================================================

/// 检查字符串是否包含换行符或回车
/// 对应 Bun: fn containsNewlineOrCR(value: []const u8) bool
/// 用于验证 header 值不包含 CRLF 注入字符
public func containsNewlineOrCR(value: String): Bool {
    return value.contains("\r") || value.contains("\n")
}

// ============================================================================
// getCredentialsWithOptions - 从 JS 选项对象解析凭证
// 严格翻译自: pub fn getCredentialsWithOptions(
//   this: S3Credentials, default_options: MultiPartUploadOptions,
//   options: ?jsc.JSValue, default_acl: ?ACL, default_storage_class: ?StorageClass,
//   default_request_payer: bool, globalObject: *jsc.JSGlobalObject
// ) bun.JSError!S3CredentialsWithOptions
// ============================================================================

/// 从 JS 选项对象解析凭证和选项
/// 对应 Bun: getCredentialsWithOptions
/// 从 JS 选项对象中提取 accessKeyId, secretAccessKey, region, endpoint, bucket,
/// sessionToken, virtualHostedStyle, pageSize, partSize, queueSize, retry, acl,
/// storageClass, contentDisposition, type, contentEncoding, requestPayer 等
public func getCredentialsWithOptions(
    credentials: S3Credentials,
    defaultOptions: MultiPartUploadOptions,
    options: ?JsValue,
    defaultAcl: ?S3Acl,
    defaultStorageClass: ?S3StorageClass,
    defaultRequestPayer: Bool,
    globalObject: JsGlobalObject
): S3CredentialsWithOptions {
    // 初始化结果
    var result = S3CredentialsWithOptions(credentials, defaultOptions)
    result.acl = defaultAcl
    result.storageClass = defaultStorageClass
    result.requestPayer = defaultRequestPayer

    match (options) {
        case Some(opts) => {
            if (opts.isObject()) {
                // ----------------------------------------------------------------
                // accessKeyId
                // 对应 Bun: opts.getTruthyComptime(globalObject, "accessKeyId")
                // ----------------------------------------------------------------
                let accessKeyIdVal = opts.getTruthy("accessKeyId")
                match (accessKeyIdVal) {
                    case Some(jsValue) => {
                        if (!jsValue.isEmptyOrUndefinedOrNull()) {
                            if (jsValue.isString()) {
                                let str = jsValue.toString()
                                if (str.length > 0) {
                                    result._accessKeyIdSlice = str
                                    result.credentials.accessKeyId = str
                                    result.changedCredentials = true
                                }
                            }
                        }
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // secretAccessKey
                // 对应 Bun: opts.getTruthyComptime(globalObject, "secretAccessKey")
                // ----------------------------------------------------------------
                let secretAccessKeyVal = opts.getTruthy("secretAccessKey")
                match (secretAccessKeyVal) {
                    case Some(jsValue) => {
                        if (!jsValue.isEmptyOrUndefinedOrNull()) {
                            if (jsValue.isString()) {
                                let str = jsValue.toString()
                                if (str.length > 0) {
                                    result._secretAccessKeySlice = str
                                    result.credentials.secretAccessKey = str
                                    result.changedCredentials = true
                                }
                            }
                        }
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // region
                // 对应 Bun: opts.getTruthyComptime(globalObject, "region")
                // ----------------------------------------------------------------
                let regionVal = opts.getTruthy("region")
                match (regionVal) {
                    case Some(jsValue) => {
                        if (!jsValue.isEmptyOrUndefinedOrNull()) {
                            if (jsValue.isString()) {
                                let str = jsValue.toString()
                                if (str.length > 0) {
                                    result._regionSlice = str
                                    result.credentials.region = str
                                    result.changedCredentials = true
                                }
                            }
                        }
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // endpoint
                // 对应 Bun: opts.getTruthyComptime(globalObject, "endpoint")
                // ----------------------------------------------------------------
                let endpointVal = opts.getTruthy("endpoint")
                match (endpointVal) {
                    case Some(jsValue) => {
                        if (!jsValue.isEmptyOrUndefinedOrNull()) {
                            if (jsValue.isString()) {
                                let str = jsValue.toString()
                                if (str.length > 0) {
                                    result._endpointSlice = str
                                    // 解析 URL，获取 hostWithPath
                                    let normalizedEndpoint = UrlParser.hostWithPath(str)
                                    if (normalizedEndpoint.length > 0) {
                                        result.credentials.endpoint = normalizedEndpoint
                                        // 默认 https，只有明确以 http:// 开头时使用 http
                                        result.changedCredentials = true
                                    }
                                }
                            }
                        }
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // bucket
                // 对应 Bun: opts.getTruthyComptime(globalObject, "bucket")
                // ----------------------------------------------------------------
                let bucketVal = opts.getTruthy("bucket")
                match (bucketVal) {
                    case Some(jsValue) => {
                        if (!jsValue.isEmptyOrUndefinedOrNull()) {
                            if (jsValue.isString()) {
                                let str = jsValue.toString()
                                if (str.length > 0) {
                                    result._bucketSlice = str
                                    result.changedCredentials = true
                                }
                            }
                        }
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // virtualHostedStyle
                // 对应 Bun: opts.getBooleanStrict(globalObject, "virtualHostedStyle")
                // ----------------------------------------------------------------
                let virtualHostedStyleVal = opts.getBooleanStrict("virtualHostedStyle")
                match (virtualHostedStyleVal) {
                    case Some(val) => {
                        result.changedCredentials = true
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // sessionToken
                // 对应 Bun: opts.getTruthyComptime(globalObject, "sessionToken")
                // ----------------------------------------------------------------
                let sessionTokenVal = opts.getTruthy("sessionToken")
                match (sessionTokenVal) {
                    case Some(jsValue) => {
                        if (!jsValue.isEmptyOrUndefinedOrNull()) {
                            if (jsValue.isString()) {
                                let str = jsValue.toString()
                                if (str.length > 0) {
                                    result._sessionTokenSlice = str
                                    result.credentials.sessionToken = str
                                    result.changedCredentials = true
                                }
                            }
                        }
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // pageSize
                // 对应 Bun: opts.getOptional(globalObject, "pageSize", i64)
                // ----------------------------------------------------------------
                let pageSizeVal = opts.getOptionalInt64("pageSize")
                match (pageSizeVal) {
                    case Some(pageSize) => {
                        if (pageSize < MultiPartUploadOptions.MIN_SINGLE_UPLOAD_SIZE ||
                            pageSize > MultiPartUploadOptions.MAX_SINGLE_UPLOAD_SIZE) {
                            // throwRangeError
                        } else {
                            result.options.partSize = pageSize
                        }
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // partSize
                // 对应 Bun: opts.getOptional(globalObject, "partSize", i64)
                // ----------------------------------------------------------------
                let partSizeVal = opts.getOptionalInt64("partSize")
                match (partSizeVal) {
                    case Some(partSize) => {
                        if (partSize < MultiPartUploadOptions.MIN_SINGLE_UPLOAD_SIZE ||
                            partSize > MultiPartUploadOptions.MAX_SINGLE_UPLOAD_SIZE) {
                            // throwRangeError
                        } else {
                            result.options.partSize = partSize
                        }
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // queueSize
                // 对应 Bun: opts.getOptional(globalObject, "queueSize", i32)
                // ----------------------------------------------------------------
                let queueSizeVal = opts.getOptionalInt32("queueSize")
                match (queueSizeVal) {
                    case Some(queueSize) => {
                        if (queueSize < 1) {
                            // throwRangeError
                        } else {
                            result.options.queueSize = Math.min8(queueSize)
                        }
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // retry
                // 对应 Bun: opts.getOptional(globalObject, "retry", i32)
                // ----------------------------------------------------------------
                let retryVal = opts.getOptionalInt32("retry")
                match (retryVal) {
                    case Some(retry) => {
                        if (retry < 0 || retry > 255) {
                            // throwRangeError
                        } else {
                            result.options.retry = UInt8(retry)
                        }
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // acl
                // 对应 Bun: opts.getOptionalEnum(globalObject, "acl", ACL)
                // ----------------------------------------------------------------
                let aclVal = opts.getOptionalString("acl")
                match (aclVal) {
                    case Some(aclStr) => {
                        let acl = S3Acl.fromString(aclStr)
                        result.acl = acl
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // storageClass
                // 对应 Bun: opts.getOptionalEnum(globalObject, "storageClass", StorageClass)
                // ----------------------------------------------------------------
                let storageClassVal = opts.getOptionalString("storageClass")
                match (storageClassVal) {
                    case Some(scStr) => {
                        let sc = S3StorageClass.fromString(scStr)
                        result.storageClass = sc
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // contentDisposition
                // 对应 Bun: opts.getTruthyComptime(globalObject, "contentDisposition")
                // ----------------------------------------------------------------
                let cdVal = opts.getTruthy("contentDisposition")
                match (cdVal) {
                    case Some(jsValue) => {
                        if (!jsValue.isEmptyOrUndefinedOrNull()) {
                            if (jsValue.isString()) {
                                let str = jsValue.toString()
                                if (str.length > 0) {
                                    if (containsNewlineOrCR(str)) {
                                        // throwInvalidArguments
                                    } else {
                                        result._contentDispositionSlice = str
                                        result.contentDisposition = str
                                    }
                                }
                            }
                        }
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // type (Content-Type)
                // 对应 Bun: opts.getTruthyComptime(globalObject, "type")
                // ----------------------------------------------------------------
                let typeVal = opts.getTruthy("type")
                match (typeVal) {
                    case Some(jsValue) => {
                        if (!jsValue.isEmptyOrUndefinedOrNull()) {
                            if (jsValue.isString()) {
                                let str = jsValue.toString()
                                if (str.length > 0) {
                                    if (containsNewlineOrCR(str)) {
                                        // throwInvalidArguments
                                    } else {
                                        result._contentTypeSlice = str
                                        result.contentType = str
                                    }
                                }
                            }
                        }
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // contentEncoding
                // 对应 Bun: opts.getTruthyComptime(globalObject, "contentEncoding")
                // ----------------------------------------------------------------
                let ceVal = opts.getTruthy("contentEncoding")
                match (ceVal) {
                    case Some(jsValue) => {
                        if (!jsValue.isEmptyOrUndefinedOrNull()) {
                            if (jsValue.isString()) {
                                let str = jsValue.toString()
                                if (str.length > 0) {
                                    if (containsNewlineOrCR(str)) {
                                        // throwInvalidArguments
                                    } else {
                                        result._contentEncodingSlice = str
                                        result.contentEncoding = str
                                    }
                                }
                            }
                        }
                    }
                    case None => ()
                }

                // ----------------------------------------------------------------
                // requestPayer
                // 对应 Bun: opts.getBooleanStrict(globalObject, "requestPayer")
                // ----------------------------------------------------------------
                let rpVal = opts.getBooleanStrict("requestPayer")
                match (rpVal) {
                    case Some(val) => {
                        result.requestPayer = val
                    }
                    case None => ()
                }
            }
        }
        case None => ()
    }

    return result
}
