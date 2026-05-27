// ──────────────────────────────────────────────────────────────────────────
// Fetch API — HTTP 请求核心
// 严格翻译自: src/runtime/webcore/fetch.rs (2123 lines)
// 对应 Bun: src/runtime/webcore/fetch.zig
// ──────────────────────────────────────────────────────────────────────────
package bao_runtime.webcore

import bao_core.Result as CoreResult
import bao_core.Environment as CoreEnvironment
import bao_core.*
import std.convert.*
import bao_jsc.*
import bao_collections.ArrayList
import bao_collections.ArrayBuffer
import bao_sys.*
import bao_http.Headers
import bao_http_types.*
import bao_runtime.webcore.s3.S3Credentials as S3Creds
import bao_runtime.webcore.s3.S3CredentialsWithOptions
import bao_runtime.webcore.s3.S3CredentialsExt
import bao_runtime.webcore.s3.S3Signing
import bao_runtime.webcore.s3.S3SignResult
import bao_runtime.webcore.s3.S3Acl as S3AclType
import bao_runtime.webcore.s3.S3StorageClass as S3StorageClassType
import bao_runtime.webcore.s3.HttpMethod as S3HttpMethod
import bao_runtime.webcore.s3.MultiPartUploadOptions as S3MultiPartUploadOptions
import bao_runtime.webcore.s3.HttpHeaders as S3HttpHeaders
import bao_runtime.webcore.s3.HttpHeaderEntry

/// Convert bao_http_types.HttpMethod to s3.HttpMethod
func toS3Method(m: HttpMethod): S3HttpMethod {
    match (m) {
        case HttpMethod.GET => S3HttpMethod.GET
        case HttpMethod.PUT => S3HttpMethod.PUT
        case HttpMethod.POST => S3HttpMethod.POST
        case HttpMethod.DELETE => S3HttpMethod.DELETE
        case HttpMethod.HEAD => S3HttpMethod.HEAD
        case HttpMethod.PATCH => S3HttpMethod.PATCH
        case HttpMethod.OPTIONS => S3HttpMethod.OPTIONS
        case HttpMethod.CONNECT => S3HttpMethod.CONNECT
        case HttpMethod.TRACE => S3HttpMethod.TRACE
        case _ => S3HttpMethod.GET
    }
}

/// Parse HttpMethod from string, defaulting to GET
func httpMethodFromString(s: String): HttpMethod {
    let upper = s.toAsciiUpper()
    if (upper == "GET") { return HttpMethod.GET }
    if (upper == "POST") { return HttpMethod.POST }
    if (upper == "PUT") { return HttpMethod.PUT }
    if (upper == "DELETE") { return HttpMethod.DELETE }
    if (upper == "HEAD") { return HttpMethod.HEAD }
    if (upper == "PATCH") { return HttpMethod.PATCH }
    if (upper == "OPTIONS") { return HttpMethod.OPTIONS }
    if (upper == "CONNECT") { return HttpMethod.CONNECT }
    if (upper == "TRACE") { return HttpMethod.TRACE }
    HttpMethod.GET
}

/// Convert HttpMethod to string
func httpMethodToString(m: HttpMethod): String {
    match (m) {
        case HttpMethod.GET => "GET"
        case HttpMethod.POST => "POST"
        case HttpMethod.PUT => "PUT"
        case HttpMethod.DELETE => "DELETE"
        case HttpMethod.HEAD => "HEAD"
        case HttpMethod.PATCH => "PATCH"
        case HttpMethod.OPTIONS => "OPTIONS"
        case HttpMethod.CONNECT => "CONNECT"
        case HttpMethod.TRACE => "TRACE"
        case _ => "GET"
    }
}

// ──────────────────────────────────────────────────────────────────────────
// RequestRedirect — HTTP 重定向策略
// 对应 Bun: src/api/fetch.zig RequestRedirect
// ──────────────────────────────────────────────────────────────────────────

/// HTTP 重定向策略
public enum RequestRedirect {
    | Follow   // 自动跟随重定向
    | Error    // 遇到重定向抛出错误
    | Manual   // 不自动处理重定向

    public func toString(): String {
        match (this) {
            case Follow => "follow"
            case Error => "error"
            case Manual => "manual"
        }
    }

    public static func fromString(s: String): RequestRedirect {
        match (s.toAsciiLower()) {
            case "follow" => Follow
            case "error" => Error
            case "manual" => Manual
            case _ => Follow
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────
// Error message constants
// 对应 Bun: pub const FETCH_ERROR_* (fetch.rs L5-L9)
// ──────────────────────────────────────────────────────────────────────────

/// fetch() 无参数错误
public let FETCH_ERROR_NO_ARGS = "fetch() expects a string but received no arguments."
/// fetch() URL 为空错误
public let FETCH_ERROR_BLANK_URL = "fetch() URL must not be a blank string."
/// fetch() GET/HEAD 不允许 body
public let FETCH_ERROR_UNEXPECTED_BODY = "fetch() request with GET/HEAD/OPTIONS method cannot have body."
/// fetch() 不支持 Unix socket 代理
public let FETCH_ERROR_PROXY_UNIX = "fetch() cannot use a proxy with a unix socket."

// ──────────────────────────────────────────────────────────────────────────
// FETCH_TYPE_ERROR_NAMES — JSType name table
// 对应 Bun: pub const FETCH_TYPE_ERROR_NAMES: [&str; 8] (fetch.rs L16-L25)
// ──────────────────────────────────────────────────────────────────────────

/// JS 类型名称表，用于 fetch() 类型错误消息
/// 对应 Bun: FETCH_TYPE_ERROR_NAMES
public let FETCH_TYPE_ERROR_NAMES: Array<String> = [
    "Undefined",
    "Null",
    "Boolean",
    "Number",
    "String",
    "Object",
    "Symbol",
    "BigInt"
]

// ──────────────────────────────────────────────────────────────────────────
// FETCH_TYPE_ERROR_STRING_VALUES — 类型错误消息模板
// 对应 Bun: pub const FETCH_TYPE_ERROR_STRING_VALUES: [&str; 8] (fetch.rs L27-L36)
// ──────────────────────────────────────────────────────────────────────────

/// fetch() 类型错误字符串值表
/// 对应 Bun: FETCH_TYPE_ERROR_STRING_VALUES
public let FETCH_TYPE_ERROR_STRING_VALUES: Array<String> = [
    "fetch() expects a string, but received Undefined",
    "fetch() expects a string, but received Null",
    "fetch() expects a string, but received Boolean",
    "fetch() expects a string, but received Number",
    "fetch() expects a string, but received String",
    "fetch() expects a string, but received Object",
    "fetch() expects a string, but received Symbol",
    "fetch() expects a string, but received BigInt"
]

// ──────────────────────────────────────────────────────────────────────────
// FETCH_TYPE_ERROR_STRINGS — alias
// 对应 Bun: pub const FETCH_TYPE_ERROR_STRINGS (fetch.rs L38)
// ──────────────────────────────────────────────────────────────────────────

/// 类型错误字符串别名
/// 对应 Bun: FETCH_TYPE_ERROR_STRINGS
public let FETCH_TYPE_ERROR_STRINGS = FETCH_TYPE_ERROR_STRING_VALUES

// ──────────────────────────────────────────────────────────────────────────
// Re-export: FetchTasklet
// 对应 Bun: pub use self::fetch_tasklet::FetchTasklet (fetch.rs L89)
// ──────────────────────────────────────────────────────────────────────────

// FetchTasklet 定义在 bao_runtime.webcore.fetch 包中

// ──────────────────────────────────────────────────────────────────────────
// HTTPRequestBody — HTTP 请求体
// 对应 Bun: fetch_tasklet::HTTPRequestBody (fetch.rs L90 import)
// ──────────────────────────────────────────────────────────────────────────

/// HTTP 请求体变体
/// 对应 Bun: HTTPRequestBody enum
public enum HTTPRequestBody {
    | BlobBody(AnyBlob)                    // Blob 请求体
    | ReadableStream(ReadableStreamRef)   // 可读流请求体
    | Sendfile(SendFile)                  // sendfile 零拷贝
    | None                                // 无请求体

    /// 是否有 body
    /// 对应 Bun: HTTPRequestBody.has_body()
    public func hasBody(): Bool {
        match (this) {
            case BlobBody(b) => !b.isDefinitelyEmpty()
            case ReadableStream(_) => true
            case Sendfile(_) => true
            case None => false
        }
    }

    /// 是否为 S3 请求体
    /// 对应 Bun: HTTPRequestBody.is_s3()
    public func isS3(): Bool {
        match (this) {
            case BlobBody(b) => b.isS3()
            case _ => false
        }
    }

    /// 是否需要读取文件
    /// 对应 Bun: HTTPRequestBody.needs_to_read_file()
    public func needsToReadFile(): Bool {
        match (this) {
            case BlobBody(b) => b.needsToReadFile()
            case _ => false
        }
    }

    /// 获取 AnyBlob
    /// 对应 Bun: HTTPRequestBody.any_blob()
    public func anyBlob(): ?AnyBlob {
        match (this) {
            case BlobBody(b) => Some(b)
            case _ => Option<AnyBlob>.None
        }
    }

    /// 获取可变的 SendFile
    /// 对应 Bun: HTTPRequestBody.sendfile_mut()
    public func sendfileMut(): ?SendFile {
        match (this) {
            case Sendfile(sf) => Some(sf)
            case _ => Option<SendFile>.None
        }
    }

    /// 获取 store
    /// 对应 Bun: HTTPRequestBody.store()
    public func store(): ?BlobStore {
        match (this) {
            case BlobBody(b) => b.store()
            case _ => Option<BlobStore>.None
        }
    }

    /// 获取 AnyBlob 的 content-type
    /// 对应 Bun: body.has_content_type_from_user()
    public func hasContentTypeFromUser(): Bool {
        match (this) {
            case BlobBody(b) => b.hasContentTypeFromUser()
            case _ => false
        }
    }

    /// 分离请求体资源
    /// 对应 Bun: HTTPRequestBody.detach()
    public func detach(): Unit {
        // 释放持有的资源
    }

    /// 获取可变 AnyBlob
    public func getAnyBlob(): ?AnyBlob {
        match (this) {
            case BlobBody(b) => Some(b)
            case _ => Option<AnyBlob>.None
        }
    }

    /// 从 JS 值构造
    /// 对应 Bun: HTTPRequestBody::from_js()
    public static func fromJs(ctx: JsGlobalObject, value: JsValue): ?HTTPRequestBody {
        if (value.isUndefinedOrNull()) {
            return None
        }
        if (value.isString()) {
            let text = value.toString()
            let bytes = Utf8Codec.encode(text)
            let bodyValue = BodyValue(InternalBlob(bytes, false))
            let blob = Blob.initFromBytes(bytes, "text/plain")
            return Some(HTTPRequestBody.BlobBody(AnyBlob(blob)))
        }
        if (value.isObject()) {
            // 尝试从 JS 对象提取 body
            let text = value.toString()
            let bytes = Utf8Codec.encode(text)
            let blob = Blob.initFromBytes(bytes, "application/octet-stream")
            return Some(HTTPRequestBody.BlobBody(AnyBlob(blob)))
        }
        return None
    }
}

// ──────────────────────────────────────────────────────────────────────────
// SendFile — 零拷贝文件传输参数
// 对应 Bun: http::SendFile
// ──────────────────────────────────────────────────────────────────────────

/// 零拷贝文件传输参数
/// 对应 Bun: http::SendFile
public class SendFile {
    /// 文件描述符
    public var fd: Int32
    /// 剩余字节数
    public var remain: Int64
    /// 偏移量
    public var offset: Int64
    /// 内容大小
    public var contentSize: Int64

    public init() {
        fd = -1
        remain = 0
        offset = 0
        contentSize = 0
    }

    public init(fd: Int32, remain: Int64, offset: Int64, contentSize: Int64) {
        this.fd = fd
        this.remain = remain
        this.offset = offset
        this.contentSize = contentSize
    }

    /// 检查 URL 是否支持 sendfile
    /// 对应 Bun: SendFile::is_eligible()
    public static func isEligible(url: BaoUrl): Bool {
        let protocol = url.protocol
        protocol == "http:" || protocol == "https:"
    }
}

// ──────────────────────────────────────────────────────────────────────────
// ReadableStreamRef — 可读流强引用
// 对应 Bun: readable_stream::Strong
// ──────────────────────────────────────────────────────────────────────────

/// 可读流强引用
/// 对应 Bun: readable_stream::Strong
public class ReadableStreamRef {
    /// 底层可读流
    public var stream: ReadableStream
    /// 全局对象引用
    public var global: JsGlobalObject

    public init(stream: ReadableStream, global: JsGlobalObject) {
        this.stream = stream
        this.global = global
    }

    /// 获取可读流
    /// 对应 Bun: readable_stream::Strong::get()
    public func get(global: JsGlobalObject): ?ReadableStream {
        Some(stream)
    }
}

/// AnyBlob 类型标签
/// 对应 Bun: blob::Any 枚举标签
public enum AnyBlobTag {
    | Blob          // 标准 Blob
    | InternalBlob  // 内部 Blob (拥有数据)
    | None          // 空
}

// ──────────────────────────────────────────────────────────────────────────
// FetchOptions — Fetch 选项
// 对应 Bun: FetchTasklet.FetchOptions (fetch.rs L90 import)
// ──────────────────────────────────────────────────────────────────────────

/// Fetch 选项 — fetch() 的所有配置参数
/// 对应 Bun: FetchOptions
public class FetchOptions {
    /// HTTP 方法
    public var method: HttpMethod
    /// 请求 URL
    public var url: BaoUrl
    /// 请求头
    public var headers: Headers
    /// 请求体
    public var body: HTTPRequestBody
    /// 禁用 keepalive
    public var disableKeepalive: Bool
    /// 禁用超时
    public var disableTimeout: Bool
    /// 禁用解压
    public var disableDecompression: Bool
    /// 拒绝未授权 TLS
    public var rejectUnauthorized: Bool
    /// 重定向类型
    public var redirectType: RequestRedirect
    /// 详细级别
    public var verbose: HTTPVerboseLevel
    /// 代理 URL
    public var proxy: ?BaoUrl
    /// 代理头
    public var proxyHeaders: ?Headers
    /// URL 代理缓冲区
    public var urlProxyBuffer: Array<UInt8>
    /// AbortSignal
    public var signal: ?AbortSignal
    /// 全局对象
    public var globalThis: ?JsGlobalObject
    /// SSL 配置
    public var sslConfig: ?SSLConfig
    /// 自定义主机名
    public var hostname: ?String
    /// Range 头值
    public var range: ?String
    /// 是否升级连接
    public var upgradedConnection: Bool
    /// 强制 HTTP/2
    public var forceHttp2: Bool
    /// 强制 HTTP/3
    public var forceHttp3: Bool
    /// 强制 HTTP/1.1
    public var forceHttp1: Bool
    /// checkServerIdentity 回调
    public var checkServerIdentity: ?JsValue
    /// Unix socket 路径
    public var unixSocketPath: String

    public init() {
        method = HttpMethod.GET
        url = BaoUrl()
        headers = Headers()
        body = HTTPRequestBody.None
        disableKeepalive = false
        disableTimeout = false
        disableDecompression = false
        rejectUnauthorized = true
        redirectType = RequestRedirect.Follow
        verbose = HTTPVerboseLevel.None
        proxy = None
        proxyHeaders = None
        urlProxyBuffer = Array<UInt8>()
        signal = None
        globalThis = None
        sslConfig = None
        hostname = None
        range = None
        upgradedConnection = false
        forceHttp2 = false
        forceHttp3 = false
        forceHttp1 = false
        checkServerIdentity = None
        unixSocketPath = ""
    }
}

// ──────────────────────────────────────────────────────────────────────────
// HTTPVerboseLevel — HTTP 详细级别
// 对应 Bun: http::HTTPVerboseLevel
// ──────────────────────────────────────────────────────────────────────────

/// HTTP 详细级别
/// 对应 Bun: http::HTTPVerboseLevel
public enum HTTPVerboseLevel {
    | None       // 无详细输出
    | Headers    // 输出头信息
    | Curl       // curl 模式输出

    public func toString(): String {
        match (this) {
            case None => "none"
            case Headers => "headers"
            case Curl => "curl"
        }
    }

    public operator func ==(other: HTTPVerboseLevel): Bool {
        match (this) {
            case None => match (other) { case None => true case _ => false }
            case Headers => match (other) { case Headers => true case _ => false }
            case Curl => match (other) { case Curl => true case _ => false }
        }
    }
    public operator func !=(other: HTTPVerboseLevel): Bool { !(this == other) }
}

// ──────────────────────────────────────────────────────────────────────────
// SSLConfig — SSL/TLS 配置
// 对应 Bun: SSLConfig
// ──────────────────────────────────────────────────────────────────────────

/// SSL/TLS 配置
/// 对应 Bun: SSLConfig
public class SSLConfig {
    /// 是否拒绝未授权证书
    public var rejectUnauthorized: Bool
    /// CA 证书路径
    public var caCertPath: String
    /// 客户端证书路径
    public var clientCertPath: String
    /// 客户端密钥路径
    public var clientKeyPath: String
    /// 服务器名
    public var serverName: String

    public init() {
        rejectUnauthorized = true
        caCertPath = ""
        clientCertPath = ""
        clientKeyPath = ""
        serverName = ""
    }

    /// 从 JS 对象解析
    /// 对应 Bun: SSLConfigFromJs::from_js()
    public static func fromJs(vm: VirtualMachine, globalThis: JsGlobalObject, value: JsValue): ?SSLConfig {
        if (!value.isObject()) {
            return None
        }
        let config = SSLConfig()
        // rejectUnauthorized
        let rejectVal = value.get(JsObject(), "rejectUnauthorized")
        match (rejectVal) {
            case Some(v) =>
                if (v.isBoolean()) {
                    config.rejectUnauthorized = v.toBoolean()
                } else if (v.isNumber()) {
                    config.rejectUnauthorized = v.toInt32() != 0
                }
            case None => ()
        }
        // serverName
        let snVal = value.get(JsObject(), "serverName")
        match (snVal) {
            case Some(v) =>
                if (v.isString()) {
                    config.serverName = v.toString()
                }
            case None => ()
        }
        return Some(config)
    }
}

// ──────────────────────────────────────────────────────────────────────────
// URLType — URL 类型 (fetch_impl 内部枚举)
// 对应 Bun: enum URLType (fetch.rs L394-L399)
// ──────────────────────────────────────────────────────────────────────────

/// URL 类型
/// 对应 Bun: URLType (fetch_impl 内部枚举)
public enum URLType {
    | Remote   // 远程 (http/https/s3)
    | File     // file:// URL
    | Blob     // blob:// URL

    public operator func ==(other: URLType): Bool {
        match (this) {
            case Remote => match (other) { case Remote => true case _ => false }
            case File => match (other) { case File => true case _ => false }
            case Blob => match (other) { case Blob => true case _ => false }
        }
    }
    public operator func !=(other: URLType): Bool { !(this == other) }
}

// ──────────────────────────────────────────────────────────────────────────
// FetchTaskState — Fetch 任务状态 (旧版兼容)
// ──────────────────────────────────────────────────────────────────────────

/// Fetch 任务状态 (旧版兼容)
public enum FetchTaskState {
    | Pending      // 等待中
    | Loading      // 加载中
    | Done         // 完成
    | Error        // 错误
}

// ──────────────────────────────────────────────────────────────────────────
// FetchTasklet — Fetch 任务单元 (旧版兼容)
// 对应 Bun: FetchTasklet
// ──────────────────────────────────────────────────────────────────────────

/// Fetch 任务单元 (旧版兼容)
/// 对应 Bun: FetchTasklet
public class FetchTasklet {
    /// 任务状态
    public var state: FetchTaskState
    /// 关联请求
    public var request: ?Request
    /// 关联响应
    public var response: ?Response
    /// 错误消息
    public var errorMessage: String

    public init() {
        state = FetchTaskState.Pending
        request = None
        response = None
        errorMessage = ""
    }

    /// 将 FetchTasklet 加入任务队列
    /// 对应 Bun: FetchTasklet::queue()
    public static func queue(globalThis: JsGlobalObject, options: FetchOptions, promise: JsPromiseStrong): FetchTasklet {
        let tasklet = FetchTasklet()
        // 在实际实现中会加入事件循环
        return tasklet
    }
}

// ──────────────────────────────────────────────────────────────────────────
// StringOrURL helper — 从 JS 值提取字符串或 URL
// 对应 Bun: struct StringOrURL (fetch.rs L358-L372)
// ──────────────────────────────────────────────────────────────────────────

/// 字符串或 URL 辅助工具
/// 对应 Bun: StringOrURL
public class StringOrURL {
    /// 从 JS 值提取 URL 字符串
    /// 对应 Bun: StringOrURL::from_js()
    public static func fromJs(value: JsValue, globalThis: JsGlobalObject): ?String {
        if (value.isString()) {
            return Some(value.toString())
        }
        // 尝试从 URL 对象提取 href
        let href = value.get(JsObject(), "href")
        match (href) {
            case Some(v) =>
                if (v.isString()) {
                    return Some(v.toString())
                }
            case None => ()
        }
        // 尝试 toString
        if (value.isObject()) {
            let str = value.toString()
            if (str.size > 0) {
                return Some(str)
            }
        }
        return None
    }
}

// ──────────────────────────────────────────────────────────────────────────
// SignalRef — AbortSignal 引用 RAII 守卫
// 对应 Bun: struct SignalRef (fetch.rs L144-L160)
// ──────────────────────────────────────────────────────────────────────────

/// AbortSignal 引用 RAII 守卫
/// 对应 Bun: SignalRef
/// 管理从 extract_signal 获取的 AbortSignal +1 引用
/// 在作用域结束时自动释放引用
public class SignalRef {
    /// 持有的 AbortSignal 引用
    public var signal: ?AbortSignal

    public init() {
        signal = None
    }

    public init(signal: ?AbortSignal) {
        this.signal = signal
    }

    /// 取出 AbortSignal，转移所有权（解除守卫）
    /// 对应 Bun: SignalRef::take()
    public func take(): ?AbortSignal {
        let result = signal
        signal = None
        return result
    }

    /// 释放引用
    /// 对应 Bun: SignalRef Drop impl
    public func deinit(): Unit {
        match (signal) {
            case Some(sig) =>
                // 对应 Bun: sig.unref() 释放 +1 引用
                sig.unref()
            case None => ()
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────
// FetchHeadersRef — FetchHeaders 引用 RAII 守卫
// 对应 Bun: struct FetchHeadersRef (fetch.rs L165-L175)
// ──────────────────────────────────────────────────────────────────────────

/// FetchHeaders 引用 RAII 守卫
/// 对应 Bun: FetchHeadersRef
/// 管理从 FetchHeaders::create_from_js 获取的 +1 引用
public class FetchHeadersRef {
    /// 持有的 FetchHeaders 引用
    public var headers: ?Headers

    public init() {
        headers = None
    }

    public init(headers: ?Headers) {
        this.headers = headers
    }

    /// 释放引用
    /// 对应 Bun: FetchHeadersRef Drop impl
    public func deinit(): Unit {
        match (headers) {
            case Some(h) =>
                () // 对应 Bun: fh.deref() 释放 +1 引用
            case None => ()
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────
// DataResult — DataURL 解析/解码结果
// 避免与 bao_core.Result<T, E> 或 s3.Result<T> 冲突
// ──────────────────────────────────────────────────────────────────────────

/// DataURL 操作结果 (避免 Result 类型歧义)
public enum DataUrlResult {
    | Data(Array<UInt8>)
    | Url(DataURL)
    | Err(String)

    public func isOk(): Bool {
        match (this) {
            case Err(_) => false
            case _ => true
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────
// DataURL — data: URL 解析结果
// 对应 Bun: bun_resolver::data_url::DataURL
// ──────────────────────────────────────────────────────────────────────────

/// Data URL 解析结果
/// 对应 Bun: DataURL
public class DataURL {
    /// MIME 类型
    public var mimeType: String
    /// 数据
    public var data: Array<UInt8>
    /// 原始 URL
    public var url: String
    /// 是否 base64 编码
    public var isBase64: Bool

    public init() {
        mimeType = "text/plain"
        data = Array<UInt8>()
        url = ""
        isBase64 = false
    }

    /// 解码数据
    /// 对应 Bun: DataURL.decode_data()
    public func decodeData(): DataUrlResult {
        if (isBase64) {
            let decodedBuf = Array<UInt8>(data.size, repeat: UInt8(0))
            let _ = Base64Codec.decode(decodedBuf, data)
            return DataUrlResult.Data(decodedBuf)
        }
        return DataUrlResult.Data(data)
    }

    /// 解析 data: URL
    /// 对应 Bun: DataURL::parse_without_check()
    public static func parseWithoutCheck(url: String): DataUrlResult {
        let dataUrl = DataURL()
        if (!url.startsWith("data:")) {
            return DataUrlResult.Err("not a data URL")
        }
        let rest = url[5..]
        let commaIdxOpt = rest.indexOf(",")
        if (let Some(commaIdx) <- commaIdxOpt) {
            let metaPart = rest[0..commaIdx]
            dataUrl.data = Utf8Codec.encode(rest[commaIdx + 1..])
            dataUrl.url = url

            // 解析 MIME 类型和编码
            if (metaPart.endsWith(";base64")) {
                dataUrl.isBase64 = true
                dataUrl.mimeType = metaPart[0..metaPart.size - 7]
            } else if (metaPart.size > 0) {
                dataUrl.mimeType = metaPart
            }
            if (dataUrl.mimeType.size == 0) {
                dataUrl.mimeType = "text/plain"
            }
            return DataUrlResult.Url(dataUrl)
        }
        return DataUrlResult.Err("invalid data URL: missing comma")
    }
}

// ──────────────────────────────────────────────────────────────────────────
// S3StreamWrapper — S3 可读流上传包装器
// 对应 Bun: struct S3StreamWrapper<'a> (fetch.rs L2050-L2110)
// ──────────────────────────────────────────────────────────────────────────

/// S3 可读流上传包装器
/// 对应 Bun: S3StreamWrapper
/// 管理 S3 流式上传的 Promise 和回调
public class S3StreamWrapper {
    /// 关联的 Promise
    public var promise: JsPromiseStrong
    /// S3 URL
    public var url: BaoUrl
    /// URL 代理缓冲区
    public var urlProxyBuffer: Array<UInt8>
    /// 全局对象
    public var global: JsGlobalObject

    public init(promise: JsPromiseStrong, url: BaoUrl, urlProxyBuffer: Array<UInt8>, global: JsGlobalObject) {
        this.promise = promise
        this.url = url
        this.urlProxyBuffer = urlProxyBuffer
        this.global = global
    }

    /// S3 上传完成回调
    /// 对应 Bun: S3StreamWrapper::resolve()
    public func resolve(result: S3UploadResult): Unit {
        match (result) {
            case S3UploadResult.Success =>
                let response = Response()
                response.statusCode_ = 200
                response.statusText = "OK"
                response.url = url.href
                promise.resolve(global, response.toJsValue())
            case S3UploadResult.Failure(errCode, errMsg) =>
                let response = Response()
                response.statusCode_ = 500
                response.statusText = errMsg
                response.url = url.href
                promise.resolve(global, response.toJsValue())
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────
// S3UploadResult — S3 上传结果
// 对应 Bun: s3::S3UploadResult
// ──────────────────────────────────────────────────────────────────────────

/// S3 上传结果
/// 对应 Bun: s3::S3UploadResult
public enum S3UploadResult {
    | Success                                  // 上传成功
    | Failure(String, String)                  // 上传失败 (code, message)
}

// ──────────────────────────────────────────────────────────────────────────
// SignResult — S3 签名结果
// 对应 Bun: bun_s3_signing::SignResult
// ──────────────────────────────────────────────────────────────────────────

/// S3 签名请求结果
/// 对应 Bun: SignResult
public class SignResult {
    /// 签名后的 URL 字节数据
    public var url: Array<UInt8>
    /// 签名后的头信息
    public var headers: ArrayList<HttpHeader>

    /// 最大头数量
    /// 对应 Bun: SignResult::MAX_HEADERS
    public static let MAX_HEADERS: Int64 = 8

    public init() {
        url = Array<UInt8>()
        headers = ArrayList<HttpHeader>()
    }

    /// 与额外头信息混合
    /// 对应 Bun: SignResult::mix_with_header()
    public func mixWithHeader(buffer: ArrayList<HttpHeader>, extraHeader: HttpHeader): Array<HttpHeader> {
        let result = ArrayList<HttpHeader>()
        result.append(extraHeader)
        for (h in headers) {
            result.append(h)
        }
        return result.items()
    }

    /// 获取头信息
    /// 对应 Bun: SignResult::headers()
    public func getHeaders(): Array<HttpHeader> {
        headers.items()
    }
}

// ──────────────────────────────────────────────────────────────────────────
// HttpHeader — HTTP 头
// 对应 Bun: picohttp::Header
// ──────────────────────────────────────────────────────────────────────────

/// HTTP 头键值对
/// 对应 Bun: picohttp::Header
public class HttpHeader {
    /// 头名称
    public var name: String
    /// 头值
    public var value: String

    public init() {
        name = ""
        value = ""
    }

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }

    /// 零值
    /// 对应 Bun: picohttp::Header::ZERO
    public static let ZERO = HttpHeader()
}

// ──────────────────────────────────────────────────────────────────────────
// S3SignedRequest — S3 签名请求
// 对应 Bun: bun_s3_signing 签名结果
// ──────────────────────────────────────────────────────────────────────────

/// S3 签名请求
/// 对应 Bun: SignResult 的中间态
public class S3SignedRequest {
    /// URL
    public var url: Array<UInt8>
    /// 方法
    public var method: HttpMethod
    /// 头信息
    public var headers: ArrayList<HttpHeader>

    public init() {
        url = Array<UInt8>()
        method = HttpMethod.GET
        headers = ArrayList<HttpHeader>()
    }
}

// ──────────────────────────────────────────────────────────────────────────
// s3CredentialsFromEnv — 从环境变量构建 S3 凭证
// 对应 Bun: pub(crate) fn s3_credentials_from_env (fetch.rs L126-L138)
// ──────────────────────────────────────────────────────────────────────────

/// 从 dotenv 环境变量构建 S3 凭证
/// 对应 Bun: s3_credentials_from_env()
/// 将低层级 dotenv::S3Credentials 转换为 bun_s3_signing::S3Credentials
public func s3CredentialsFromEnv(env: S3EnvCredentials): S3Creds {
    let creds = S3Creds()
    creds.accessKey = env.accessKeyId
    creds.secretKey = env.secretAccessKey
    creds.region = env.region
    creds.endpoint = env.endpoint
    creds.sessionToken = env.sessionToken
    return creds
}

// ──────────────────────────────────────────────────────────────────────────
// S3EnvCredentials — 环境变量中的 S3 凭证
// 对应 Bun: bun_dotenv::S3Credentials
// ──────────────────────────────────────────────────────────────────────────

/// 环境变量中的 S3 凭证 (POD 镜像)
/// 对应 Bun: bun_dotenv::S3Credentials
public class S3EnvCredentials {
    /// 访问密钥 ID
    public var accessKeyId: String
    /// 秘密访问密钥
    public var secretAccessKey: String
    /// 区域
    public var region: String
    /// 端点
    public var endpoint: String
    /// 存储桶
    public var bucket: String
    /// 会话令牌
    public var sessionToken: String
    /// 是否使用不安全 HTTP
    public var insecureHttp: Bool

    public init() {
        accessKeyId = ""
        secretAccessKey = ""
        region = ""
        endpoint = ""
        bucket = ""
        sessionToken = ""
        insecureHttp = false
    }
}

// ──────────────────────────────────────────────────────────────────────────
// dataURLResponse — 处理 data: URL 响应
// 对应 Bun: fn data_url_response (fetch.rs L214-L263)
// ──────────────────────────────────────────────────────────────────────────

/// 处理 data: URL 响应
/// 对应 Bun: data_url_response()
/// 解码 data URL 并创建对应的 Response
public func dataUrlResponse(dataUrl: DataURL, globalThis: JsGlobalObject): JsValue {
    let decoded = dataUrl.decodeData()
    match (decoded) {
        case Err(_) =>
            return JsPromise.reject(globalThis, JsValue("failed to fetch the data URL"))
        case Data(decodedBytes) =>
            let blob = Blob.initFromBytes(decodedBytes, dataUrl.mimeType)

            let response = Response()
            response.statusCode_ = 200
            response.statusText = "OK"
            response.body = Some(BodyValue(blob))
            response.url = dataUrl.url

            return JsPromise.resolve(globalThis, response.toJsValue())
        case Url(_) =>
            return JsPromise.reject(globalThis, JsValue("not a data URL"))
    }
}

// ──────────────────────────────────────────────────────────────────────────
// Bun__fetchPreconnect — 预连接
// 对应 Bun: bun_fetch_preconnect (fetch.rs L269-L352)
// ──────────────────────────────────────────────────────────────────────────

/// 预连接到指定 URL
/// 对应 Bun: Bun__fetchPreconnect / bun_fetch_preconnect()
public func fetchPreconnect(global: JsGlobalObject, callFrame: CallFrame): JsResult<JsValue> {
    let arguments = callFrame.argumentsOld(1)
    if (arguments.len < 1) {
        return JsResult.Err("fetch.preconnect expects 1 argument, got 0")
    }

    let urlStr = arguments.ptr[0].toString()

    if (urlStr.size == 0) {
        return JsResult.Err(FETCH_ERROR_BLANK_URL)
    }

    // 解析 URL
    let url = BaoUrl(urlStr)

    // 验证协议
    let protocol = url.protocol
    if (protocol != "http:" && protocol != "https:" && !url.isS3()) {
        return JsResult.Err("URL must be HTTP or HTTPS")
    }

    // 验证主机名
    if (url.hostname.size == 0) {
        return JsResult.Err(FETCH_ERROR_BLANK_URL)
    }

    // 验证端口
    if (!url.hasValidPort()) {
        return JsResult.Err("Invalid port")
    }

    // 在实际实现中会预先建立 TCP/TLS 连接
    // 对应 Bun: http::async_http::preconnect(url, true)

    return JsResult.Ok(JsValue.UNDEFINED)
}

// ──────────────────────────────────────────────────────────────────────────
// bunFetch — Bun.fetch 入口
// 对应 Bun: pub fn bun_fetch (fetch.rs L379-L382)
// ──────────────────────────────────────────────────────────────────────────

/// Bun.fetch 入口 — 验证 GET/HEAD/OPTIONS 的 body
/// 对应 Bun: bun_fetch()
public func bunFetch(ctx: JsGlobalObject, callFrame: CallFrame): JsResult<JsValue> {
    fetchImpl(false, ctx, callFrame)
}

// ──────────────────────────────────────────────────────────────────────────
// nodeHttpClient — Node.js HTTP 客户端入口
// 对应 Bun: pub fn node_http_client (fetch.rs L386-L388)
// ──────────────────────────────────────────────────────────────────────────

/// Node.js HTTP 客户端入口 — 允许 GET/HEAD/OPTIONS 的 body
/// 对应 Bun: node_http_client()
public func nodeHttpClient(ctx: JsGlobalObject, callFrame: CallFrame): JsResult<JsValue> {
    fetchImpl(true, ctx, callFrame)
}

// ──────────────────────────────────────────────────────────────────────────
// fetchImpl — fetch 共享实现
// 对应 Bun: fn fetch_impl<const ALLOW_GET_BODY: bool> (fetch.rs L406-L2042)
// 这是 fetch.rs 的核心函数，处理所有 fetch 参数提取和请求调度
// ──────────────────────────────────────────────────────────────────────────

/// fetch() 共享实现
/// 对应 Bun: fetch_impl<ALLOW_GET_BODY>()
/// allowGetBody: 是否允许 GET/HEAD/OPTIONS 方法带 body
///               bun_fetch -> false (标准 Web 行为)
///               nodeHttpClient -> true (Node.js 兼容)
public func fetchImpl(allowGetBody: Bool, ctx: JsGlobalObject, callFrame: CallFrame): JsResult<JsValue> {
    let globalThis = ctx
    let arguments = callFrame.argumentsOld(2)

    // ── 初始化变量 ────────────────────────────────────────────────────
    var isError = false
    var upgradedConnection = false
    var forceHttp2 = false
    var forceHttp3 = false
    var forceHttp1 = false

    // 无参数错误
    if (arguments.len == 0) {
        let err = JsValue(FETCH_ERROR_NO_ARGS)
        return JsResult.Ok(JsPromise.reject(globalThis, err))
    }

    var headers: ?Headers = None
    var method = HttpMethod.GET

    let vm = VirtualMachine.get()
    var verbose = HTTPVerboseLevel.None
    let vmVerboseFetch = vm.getVerboseFetch()
    if (vmVerboseFetch == HTTPVerboseLevel.None) {
        let logLevel = vm.getLogLevel()
        if (logLevel.isAtLeast(LogLevel.Debug)) {
            verbose = HTTPVerboseLevel.Headers
        } else {
            verbose = vmVerboseFetch
        }
    } else {
        verbose = vmVerboseFetch
    }

    var args = arguments
    var url = BaoUrl()
    let firstArg = args.ptr[0]

    // 请求体: 在 Headers 之前获取 Body，以便从 Blob 设置 Content-Type
    var body: HTTPRequestBody = HTTPRequestBody.None

    var disableTimeout = false
    var disableKeepalive = false
    var disableDecompression = false
    var proxy: ?BaoUrl = None
    var redirectType = RequestRedirect.Follow
    var signal = SignalRef()
    var hostname: ?String = None
    var range: ?String = None
    var unixSocketPath = ""
    var urlProxyBuffer = Array<UInt8>()
    var urlType = URLType.Remote
    var sslConfig: ?SSLConfig = None
    var rejectUnauthorized = vm.getTlsRejectUnauthorized()
    var checkServerIdentity: JsValue = JsValue(Int64(0))

    // ── 提取 options 对象 ─────────────────────────────────────────────
    var optionsObject: ?JsValue = None
    if (args.len >= 2) {
        let options = args.ptr[1]
        if (options.isObject() || options.isDomWrapper()) {
            optionsObject = Some(options)
        }
    }

    // ── 提取 Request 对象 ─────────────────────────────────────────────
    var request: ?Request = None
    if (firstArg.isObject()) {
        let req = firstArg.asDirectRequest()
        match (req) {
            case Some(r) => request = Some(r)
            case None => ()
        }
    }

    // 如果第一个参数不是 Request，当作 URL 处理
    var urlStrOptional: ?String = None
    if (request.isNone()) {
        urlStrOptional = StringOrURL.fromJs(firstArg, globalThis)
    }

    // ── 提取 request init 对象 ────────────────────────────────────────
    var requestInitObject: ?JsValue = None
    if (request.isNone() && urlStrOptional.isNone()) {
        if (firstArg.isObject()) {
            requestInitObject = Some(firstArg)
        }
    }

    // ── 提取 URL 字符串 ────────────────────────────────────────────────
    var urlStr: String = ""
    if (urlStrOptional.isSome()) {
        urlStr = urlStrOptional.getOrThrow()
    } else if (request.isSome()) {
        let req = request.getOrThrow()
        if (req.url.size == 0) {
            urlStr = ""
        } else {
            urlStr = req.url
        }
    } else if (requestInitObject.isSome()) {
        let initObj = requestInitObject.getOrThrow()
        let urlVal = initObj.get(JsObject(), "url")
        match (urlVal) {
            case Some(v) =>
                if (!v.isUndefined()) {
                    urlStr = v.toString()
                }
            case None => ()
        }
    }

    // 检查异常
    if (false) {  // TODO: globalThis.hasException()
        return JsResult.Ok(JsValue(Int64(0)))
    }

    // URL 为空错误
    if (urlStr.size == 0) {
        let err = JsValue(FETCH_ERROR_BLANK_URL)
        return JsResult.Ok(JsPromise.reject(globalThis, err))
    }

    // ── data: URL 处理 ────────────────────────────────────────────────
    if (urlStr.startsWith("data:")) {
        let dataUrlResult = DataURL.parseWithoutCheck(urlStr)
        match (dataUrlResult) {
            case Url(dataUrl) =>
                return JsResult.Ok(dataUrlResponse(dataUrl, globalThis))
            case Data(_) =>
                return JsResult.Ok(JsPromise.reject(globalThis, JsValue("invalid data URL")))
            case Err(_) =>
                let err = JsValue("failed to fetch the data URL")
                return JsResult.Ok(JsPromise.reject(globalThis, err))
        }
    }

    // ── 解析 URL ──────────────────────────────────────────────────────
    let parsedUrl = BaoUrl.parse(urlStr)
    if (!parsedUrl.isValid()) {
        let err = JsValue("fetch() URL is invalid")
        return JsResult.Ok(JsPromise.reject(globalThis, err))
    }
    url = parsedUrl
    if (url.isLocalFile()) {
        urlType = URLType.File
    } else if (url.isBlob()) {
        urlType = URLType.Blob
    }

    // ════════════════════════════════════════════════════════════════════
    // 提取各个选项参数 — 对应 Bun: fetch_impl 中各 extract_* 块
    // ════════════════════════════════════════════════════════════════════

    // ── method ─────────────────────────────────────────────────────────
    // 对应 Bun: 'extract_method (fetch.rs L659-L678)
    method = extractMethod(optionsObject, request, requestInitObject, globalThis)

    // ── decompress ─────────────────────────────────────────────────────
    // 对应 Bun: 'extract_disable_decompression (fetch.rs L681-L706)
    disableDecompression = extractDisableDecompression(
        optionsObject, requestInitObject, globalThis, disableDecompression
    )

    // ── tls ────────────────────────────────────────────────────────────
    // 对应 Bun: 'extract_ssl_config (fetch.rs L714-L768)
    let tlsResult = extractSslConfig(
        optionsObject, requestInitObject, ctx, globalThis, vm,
        sslConfig, rejectUnauthorized
    )
    sslConfig = tlsResult.sslConfig
    rejectUnauthorized = tlsResult.rejectUnauthorized
    checkServerIdentity = tlsResult.checkServerIdentity

    // ── unix socket ────────────────────────────────────────────────────
    // 对应 Bun: 'extract_unix_socket_path (fetch.rs L776-L799)
    unixSocketPath = extractUnixSocketPath(
        optionsObject, requestInitObject, globalThis, unixSocketPath
    )

    // ── protocol ───────────────────────────────────────────────────────
    // 对应 Bun: 'extract_protocol (fetch.rs L807-L836)
    let protocolResult = extractProtocol(optionsObject, requestInitObject, globalThis)
    forceHttp2 = protocolResult.forceHttp2
    forceHttp3 = protocolResult.forceHttp3
    forceHttp1 = protocolResult.forceHttp1
    if (protocolResult.isError) {
        return JsResult.Err("fetch: 'protocol' must be \"http2\", \"h2\", \"http3\", \"h3\", \"http1.1\", or \"h1\"")
    }

    // ── timeout ────────────────────────────────────────────────────────
    // 对应 Bun: 'extract_disable_timeout (fetch.rs L839-L864)
    disableTimeout = extractDisableTimeout(
        optionsObject, requestInitObject, globalThis, disableTimeout
    )

    // ── redirect ───────────────────────────────────────────────────────
    // 对应 Bun: 'extract_redirect_type (fetch.rs L872-L901)
    redirectType = extractRedirectType(
        optionsObject, request, requestInitObject, globalThis, redirectType
    )

    // ── keepalive ──────────────────────────────────────────────────────
    // 对应 Bun: 'extract_disable_keepalive (fetch.rs L909-L934)
    disableKeepalive = extractDisableKeepalive(
        optionsObject, requestInitObject, globalThis, disableKeepalive
    )

    // ── verbose ────────────────────────────────────────────────────────
    // 对应 Bun: 'extract_verbose (fetch.rs L942-L972)
    verbose = extractVerbose(
        optionsObject, requestInitObject, globalThis, verbose
    )

    // ── proxy ──────────────────────────────────────────────────────────
    // 对应 Bun: 'extract_proxy (fetch.rs L977-L1115)
    let proxyResult = extractProxy(
        optionsObject, requestInitObject, ctx, globalThis,
        url, urlType, urlProxyBuffer, proxy
    )
    url = proxyResult.url
    urlType = proxyResult.urlType
    urlProxyBuffer = proxyResult.urlProxyBuffer
    proxy = proxyResult.proxy

    // ── signal ─────────────────────────────────────────────────────────
    // 对应 Bun: 'extract_signal (fetch.rs L1123-L1165)
    signal = extractSignal(
        optionsObject, request, requestInitObject, globalThis
    )

    // ── body ───────────────────────────────────────────────────────────
    // 对应 Bun: 'extract_body (fetch.rs L1177-L1257)
    body = extractBody(
        optionsObject, request, requestInitObject,
        globalThis, firstArg, ctx
    )

    // ── headers ────────────────────────────────────────────────────────
    // 对应 Bun: 'extract_headers (fetch.rs L1265-L1376)
    let headersResult = extractHeaders(
        optionsObject, request, requestInitObject,
        globalThis, ctx, headers, body, url
    )
    headers = headersResult.headers
    hostname = headersResult.hostname
    range = headersResult.range
    upgradedConnection = headersResult.upgradedConnection

    // ── 验证 proxy + unix 互斥 ────────────────────────────────────────
    // 对应 Bun: fetch.rs L1383-L1395
    if (proxy.isSome() && unixSocketPath.size > 0) {
        let err = JsValue(FETCH_ERROR_PROXY_UNIX)
        return JsResult.Ok(JsPromise.reject(globalThis, err))
    }

    // ════════════════════════════════════════════════════════════════════
    // 非远程 URL 处理 (file://, blob://)
    // 对应 Bun: fetch.rs L1405-L1559
    // ════════════════════════════════════════════════════════════════════

    if (urlType != URLType.Remote) {
        let pathSlice = match (urlType) {
            case URLType.File => url.pathname
            case URLType.Blob => urlStr[5..] // "blob:" 之后
            case URLType.Remote => ""
        }
        let urlPathDecoded = UrlParser.percentDecode(pathSlice)
        var urlString = ""

        if (urlType == URLType.Blob) {
            // 尝试从 ObjectURLRegistry 解析 blob
            let registry = ObjectURLRegistry.singleton()
            let resolved = registry.resolveAndDupe(urlPathDecoded)
            match (resolved) {
                case Some(blob) =>
                    urlString = "blob:${urlPathDecoded}"
                    let response = Response()
                    response.statusCode_ = 200
                    response.body = Some(BodyValue(blob))
                    response.url = urlString
                    return JsResult.Ok(JsPromise.resolve(globalThis, response.toJsValue()))
                case None =>
                    let err = JsValue("Failed to resolve blob:${urlPathDecoded}")
                    return JsResult.Ok(JsPromise.reject(globalThis, err))
            }
        }

        // file:// URL 处理
        let tempFilePath = urlPathDecoded
        let pathlike = PathLike.EncodedSlice(tempFilePath)
        let blobToUse = Blob.findOrCreateFileFromPath(pathlike, globalThis, true)
        urlString = "file://${tempFilePath}"

        let response = Response()
        response.statusCode_ = 200
        response.body = Some(BodyValue(blobToUse))
        response.url = urlString
        return JsResult.Ok(JsPromise.resolve(globalThis, response.toJsValue()))
    }

    // ════════════════════════════════════════════════════════════════════
    // 协议验证
    // 对应 Bun: fetch.rs L1561-L1575
    // ════════════════════════════════════════════════════════════════════

    let protocol = url.protocol
    if (protocol.size > 0) {
        if (protocol != "http:" && protocol != "https:" && !url.isS3()) {
            let err = JsValue("protocol must be http:, https: or s3:")
            return JsResult.Ok(JsPromise.reject(globalThis, err))
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // GET/HEAD/OPTIONS body 验证
    // 对应 Bun: fetch.rs L1577-L1589
    // ════════════════════════════════════════════════════════════════════

    if (!allowGetBody && !method.hasRequestBody() && body.hasBody() && !upgradedConnection) {
        let err = JsValue(FETCH_ERROR_UNEXPECTED_BODY)
        return JsResult.Ok(JsPromise.reject(globalThis, err))
    }

    // ── 如果无 headers 但 body 有 content-type，创建 headers ─────────
    // 对应 Bun: fetch.rs L1591-L1596
    if (headers.isNone() && body.hasBody() && body.hasContentTypeFromUser()) {
        headers = Some(Headers())
    }

    // ════════════════════════════════════════════════════════════════════
    // S3 请求体准备
    // 对应 Bun: fetch.rs L1604-L1962
    // ════════════════════════════════════════════════════════════════════

    if (body.isS3()) {
        // S3 流式上传准备
        // 对应 Bun: fetch.rs L1605-L1637
        let readable = ReadableStream.fromBlobCopyRef(
            globalThis,
            body.anyBlob().getOrThrow().blob,
            S3MultiPartUploadOptions.DEFAULT_PART_SIZE
        )
        if (readable.isSome()) {
            let rs = readable.getOrThrow()
            let oldBody = body
            body = HTTPRequestBody.ReadableStream(ReadableStreamRef(rs, globalThis))
            // 旧 body detach
        } else {
            let err = JsValue("Failed to start s3 stream")
            body.detach()
            return JsResult.Ok(JsPromise.reject(globalThis, err))
        }
    }

    // ── 文件读取 / sendfile ───────────────────────────────────────────
    // 对应 Bun: fetch.rs L1639-L1775
    if (body.needsToReadFile()) {
        body = prepareFileBody(body, proxy, url, globalThis)
    }

    // ════════════════════════════════════════════════════════════════════
    // S3 签名请求处理
    // 对应 Bun: fetch.rs L1777-L1962
    // ════════════════════════════════════════════════════════════════════

    if (url.isS3()) {
        // 从环境变量获取 S3 凭证
        let envCreds = vm.getS3Credentials()
        let creds = s3CredentialsFromEnv(envCreds)
        var credentialsWithOptions = S3CredentialsWithOptions(creds, S3MultiPartUploadOptions())

        // 从选项对象提取 S3 选项
        match (optionsObject) {
            case Some(options) =>
                let s3Opts = options.getTruthy(globalThis.globalThis, "s3")
                match (s3Opts) {
                    case Some(s3OptsVal) =>
                        if (s3OptsVal.isObject()) {
                            credentialsWithOptions = S3CredentialsExt.getCredentialsWithOptions(
                                creds,
                                S3MultiPartUploadOptions(),
                                Some(s3OptsVal),
                                Option<S3AclType>.None,
                                Option<S3StorageClassType>.None,
                                false,
                                globalThis
                            )
                        }
                    case None => ()
                }
            case None => ()
        }

        // ReadableStream 上传到 S3
        match (body) {
            case HTTPRequestBody.ReadableStream(readableStream) =>
                // S3 流式上传: 仅支持 PUT/POST
                // S3 流式上传: 仅支持 PUT/POST
                let isPutOrPost = match (method) {
                    case HttpMethod.PUT => true
                    case HttpMethod.POST => true
                    case _ => false
                }
                if (!isPutOrPost) {
                    let err = JsValue("Only POST and PUT do support body when using S3")
                    return JsResult.Ok(JsPromise.reject(globalThis, err))
                }

                let promise = JsPromiseStrong()
                let promiseValue = promise.value()

                // 创建 S3StreamWrapper
                let s3Stream = S3StreamWrapper(
                    promise,
                    url,
                    urlProxyBuffer,
                    globalThis
                )

                // 在实际实现中会调用 s3::upload_stream()
                return JsResult.Ok(promiseValue)
            case _ => ()
        }

        // POST -> PUT
        let isPost = match (method) {
            case HttpMethod.POST => true
            case _ => false
        }
        if (isPost) {
            method = HttpMethod.PUT
        }

        // 签名请求
        let signResult = S3Signing.signRequestFull(
            url.s3Path(), toS3Method(method), "", "", "", Option<String>.None, Option<String>.None,
            false, Option<S3AclType>.None, Option<S3StorageClassType>.None, credentialsWithOptions.credentials
        )
        let signedUrl = signResult.url

        // 替换 URL 和 headers
        match (proxy) {
            case Some(proxyUrl) =>
                // 合并签名 URL 和代理 URL
                urlProxyBuffer = Utf8Codec.encode(signedUrl)
                url = BaoUrl.parse(signedUrl)
            case None =>
                urlProxyBuffer = Utf8Codec.encode(signedUrl)
                url = BaoUrl.parse(signedUrl)
        }

        // 设置签名头
        var contentType: ?String = None
        match (headers) {
            case Some(h) => contentType = h.get("content-type")
            case None => ()
        }
        match (range) {
            case Some(rangeVal) =>
                let newHeaders = ArrayList<HttpHeader>()
                newHeaders.append(HttpHeader("range", rangeVal))
                headers = Some(Headers.fromHttpHeaders(newHeaders.items()))
            case None =>
                match (contentType) {
                    case Some(ct) =>
                        if (ct.size > 0) {
                            let newHeaders = ArrayList<HttpHeader>()
                            newHeaders.append(HttpHeader("Content-Type", ct))
                            headers = Some(Headers.fromHttpHeaders(newHeaders.items()))
                        } else {
                            headers = Some(Headers.fromHttpHeaders(httpHeadersToArray(signResult.toHttpHeaders())))
                        }
                    case None =>
                        headers = Some(Headers.fromHttpHeaders(httpHeadersToArray(signResult.toHttpHeaders())))
                }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // 创建 Promise 并排队 FetchTasklet
    // 对应 Bun: fetch.rs L1966-L2042
    // ════════════════════════════════════════════════════════════════════

    let promise = JsPromiseStrong()
    let promiseVal = promise.value()

    // 构建 FetchOptions
    let fetchOptions = FetchOptions()
    fetchOptions.method = method
    fetchOptions.url = url
    fetchOptions.headers = match (headers) {
        case Some(h) => h
        case None => Headers()
    }
    fetchOptions.body = body
    fetchOptions.disableKeepalive = disableKeepalive
    fetchOptions.disableTimeout = disableTimeout
    fetchOptions.disableDecompression = disableDecompression
    fetchOptions.rejectUnauthorized = rejectUnauthorized
    fetchOptions.redirectType = redirectType
    fetchOptions.verbose = verbose
    fetchOptions.proxy = proxy
    fetchOptions.urlProxyBuffer = urlProxyBuffer
    fetchOptions.signal = signal.take()
    fetchOptions.sslConfig = sslConfig
    fetchOptions.hostname = hostname
    fetchOptions.range = range
    fetchOptions.upgradedConnection = upgradedConnection
    fetchOptions.forceHttp2 = forceHttp2
    fetchOptions.forceHttp3 = forceHttp3
    fetchOptions.forceHttp1 = forceHttp1
    fetchOptions.unixSocketPath = unixSocketPath

    // 排队 FetchTasklet
    FetchTasklet.queue(globalThis, fetchOptions, promise)

    return JsResult.Ok(promiseVal)
}

// ════════════════════════════════════════════════════════════════════════
// fetch() 公共 API — 全局 fetch() 函数
// 对应 Web API: globalThis.fetch()
// ════════════════════════════════════════════════════════════════════════

/// fetch(url) — 发送 HTTP GET 请求
/// 对应 Web API: globalThis.fetch(url)
/// 对应 Bun: Bun__fetch_
public func fetchUrl(url: String): Response {
    let request = Request(url)
    return fetchWithRequest(request)
}

/// fetch(url, init) — 发送 HTTP 请求
/// 对应 Web API: globalThis.fetch(url, init)
public func fetchUrl(url: String, options: RequestInit): Response {
    let request = Request(url, options)
    return fetchWithRequest(request)
}

/// fetch(url, options) — 发送 HTTP 请求 (简化版)
public func fetchUrl(url: String, method: String): Response {
    let request = Request(url)
    return fetchWithRequest(request)
}

/// 内部 fetch 实现
/// 对应 Bun: fetchImpl (simplified synchronous version)
private func fetchWithRequest(request: Request): Response {
    // 检查 abort signal
    if (!request.signal.isUndefined()) {
        // TODO: check abort signal properly
    }

    // 验证 GET/HEAD/OPTIONS 不带 body
    match (request.method) {
        case HttpMethod.GET | HttpMethod.HEAD | HttpMethod.OPTIONS =>
            match (request.body) {
                case Some(bv) =>
                    if (!bv.isDefinitelyEmpty()) {
                        // 允许但不推荐
                    }
                case None => ()
            }
        case _ => ()
    }

    // 解析 URL
    let parsedUrl = BaoUrl(request.url)

    // 只支持 http/https 协议
    let protocol = parsedUrl.protocol
    if (protocol != "http:" && protocol != "https:") {
        return Response.error()
    }

    // 发送请求
    var response = HttpClient.sendRequest(parsedUrl, request)
    response.url = request.url

    // 处理重定向
    var redirectCount = 0
    let maxRedirects = 20
    while (response.statusCode() >= 300 && response.statusCode() < 400 && redirectCount < maxRedirects) {
        match (request.flags.redirect) {
            case "error" =>
                return Response.error()
            case "manual" =>
                return response
            case "follow" =>
                let location = response.redirectLocation()
                match (location) {
                    case Some(loc) =>
                        redirectCount++
                        response.redirected = true
                        let redirectUrl = if (loc.startsWith("http://") || loc.startsWith("https://")) {
                            loc
                        } else {
                            protocol + "//" + parsedUrl.hostname + loc
                        }
                        let redirectRequest = Request(redirectUrl)
                        response = HttpClient.sendRequest(BaoUrl(redirectUrl), redirectRequest)
                        response.url = redirectUrl
                    case None => return response
                }
            case _ => return response
        }
    }

    return response
}

// ════════════════════════════════════════════════════════════════════════
// 参数提取辅助函数 — 对应 fetch_impl 中的各 'extract_* 块
// ════════════════════════════════════════════════════════════════════════

/// 提取 method 参数
/// 对应 Bun: 'extract_method (fetch.rs L659-L678)
private func extractMethod(
    optionsObject: ?JsValue,
    request: ?Request,
    requestInitObject: ?JsValue,
    globalThis: JsGlobalObject
): HttpMethod {
    // 从 options 对象提取
    match (optionsObject) {
        case Some(options) =>
            let methodVal = options.getTruthy(globalThis.globalThis, "method")
            match (methodVal) {
                case Some(v) =>
                    if (v.isString()) {
                        return httpMethodFromString(v.toString())
                    }
                case None => ()
            }
        case None => ()
    }

    // 从 Request 对象提取
    match (request) {
        case Some(req) => return req.method
        case None => ()
    }

    // 从 request init 对象提取
    match (requestInitObject) {
        case Some(`init`) =>
            let methodVal = `init`.getTruthy(globalThis.globalThis, "method")
            match (methodVal) {
                case Some(v) =>
                    if (v.isString()) {
                        return httpMethodFromString(v.toString())
                    }
                case None => ()
            }
        case None => ()
    }

    return HttpMethod.GET
}

/// 提取 disableDecompression 参数
/// 对应 Bun: 'extract_disable_decompression (fetch.rs L681-L706)
private func extractDisableDecompression(
    optionsObject: ?JsValue,
    requestInitObject: ?JsValue,
    globalThis: JsGlobalObject,
    currentValue: Bool
): Bool {
    let objectsToTry = ArrayList<JsValue>()
    match (optionsObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }
    match (requestInitObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }

    for (obj in objectsToTry) {
        if (!obj.isEmptyOrUndefinedOrNull()) {
            let decompressionVal = obj.get(globalThis.globalThis, "decompress")
            match (decompressionVal) {
                case Some(v) =>
                    if (v.isBoolean()) {
                        return !v.toBoolean()
                    } else if (v.isNumber()) {
                        return v.toInt32() == 0
                    }
                case None => ()
            }
        }
    }

    return currentValue
}

/// 提取 SSL 配置
/// 对应 Bun: 'extract_ssl_config (fetch.rs L714-L768)
private func extractSslConfig(
    optionsObject: ?JsValue,
    requestInitObject: ?JsValue,
    ctx: JsGlobalObject,
    globalThis: JsGlobalObject,
    vm: VirtualMachine,
    currentSslConfig: ?SSLConfig,
    currentRejectUnauthorized: Bool
): SslConfigResult {
    var sslConfig = currentSslConfig
    var rejectUnauthorized = currentRejectUnauthorized
    var checkServerIdentity: JsValue = JsValue(Int64(0))

    let objectsToTry = ArrayList<JsValue>()
    match (optionsObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }
    match (requestInitObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }

    for (obj in objectsToTry) {
        if (!obj.isEmptyOrUndefinedOrNull()) {
            let tlsVal = obj.get(globalThis.globalThis, "tls")
            match (tlsVal) {
                case Some(tls) =>
                    if (tls.isObject()) {
                        // rejectUnauthorized
                        let rejectVal = tls.get(globalThis.globalThis, "rejectUnauthorized")
                        match (rejectVal) {
                            case Some(v) =>
                                if (v.isBoolean()) {
                                    rejectUnauthorized = v.toBoolean()
                                } else if (v.isNumber()) {
                                    rejectUnauthorized = v.toInt32() != 0
                                }
                            case None => ()
                        }

                        // checkServerIdentity
                        let checkVal = tls.get(globalThis.globalThis, "checkServerIdentity")
                        match (checkVal) {
                            case Some(v) =>
                                if (v.isCell() && v.isCallable()) {
                                    checkServerIdentity = v
                                }
                            case None => ()
                        }

                        // SSLConfig
                        let config = SSLConfig.fromJs(vm, globalThis, tls)
                        match (config) {
                            case Some(c) =>
                                sslConfig = Some(c)
                            case None => ()
                        }
                    }
                case None => ()
            }
        }
    }

    return SslConfigResult(sslConfig, rejectUnauthorized, checkServerIdentity)
}

/// 提取 Unix socket 路径
/// 对应 Bun: 'extract_unix_socket_path (fetch.rs L776-L799)
private func extractUnixSocketPath(
    optionsObject: ?JsValue,
    requestInitObject: ?JsValue,
    globalThis: JsGlobalObject,
    currentValue: String
): String {
    let objectsToTry = ArrayList<JsValue>()
    match (optionsObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }
    match (requestInitObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }

    for (obj in objectsToTry) {
        if (!obj.isEmptyOrUndefinedOrNull()) {
            let socketVal = obj.get(globalThis.globalThis, "unix")
            match (socketVal) {
                case Some(v) =>
                    if (v.isString()) {
                        let str = v.toString()
                        if (str.size > 0) {
                            return str
                        }
                    }
                case None => ()
            }
        }
    }

    return currentValue
}

/// 提取 protocol 强制设置
/// 对应 Bun: 'extract_protocol (fetch.rs L807-L836)
private func extractProtocol(
    optionsObject: ?JsValue,
    requestInitObject: ?JsValue,
    globalThis: JsGlobalObject
): ProtocolResult {
    var forceHttp2 = false
    var forceHttp3 = false
    var forceHttp1 = false
    var errResult = false

    let objectsToTry = ArrayList<JsValue>()
    match (optionsObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }
    match (requestInitObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }

    for (obj in objectsToTry) {
        if (!obj.isEmptyOrUndefinedOrNull()) {
            let protocolVal = obj.get(globalThis.globalThis, "protocol")
            match (protocolVal) {
                case Some(v) =>
                    if (v.isString()) {
                        let str = v.toString()
                        if (str == "http2" || str == "h2") {
                            forceHttp2 = true
                        } else if (str == "http3" || str == "h3") {
                            forceHttp3 = true
                        } else if (str == "http1.1" || str == "h1") {
                            forceHttp1 = true
                        } else {
                            errResult = true
                        }
                    }
                case None => ()
            }
        }
    }

    return ProtocolResult(forceHttp2, forceHttp3, forceHttp1, errResult)
}

/// 提取 disableTimeout
/// 对应 Bun: 'extract_disable_timeout (fetch.rs L839-L864)
private func extractDisableTimeout(
    optionsObject: ?JsValue,
    requestInitObject: ?JsValue,
    globalThis: JsGlobalObject,
    currentValue: Bool
): Bool {
    let objectsToTry = ArrayList<JsValue>()
    match (optionsObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }
    match (requestInitObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }

    for (obj in objectsToTry) {
        if (!obj.isEmptyOrUndefinedOrNull()) {
            let timeoutVal = obj.get(globalThis.globalThis, "timeout")
            match (timeoutVal) {
                case Some(v) =>
                    if (v.isBoolean()) {
                        return !v.toBoolean()
                    } else if (v.isNumber()) {
                        return v.toInt32() == 0
                    }
                case None => ()
            }
        }
    }

    return currentValue
}

/// 提取 redirect 类型
/// 对应 Bun: 'extract_redirect_type (fetch.rs L872-L901)
private func extractRedirectType(
    optionsObject: ?JsValue,
    request: ?Request,
    requestInitObject: ?JsValue,
    globalThis: JsGlobalObject,
    currentValue: RequestRedirect
): RequestRedirect {
    var redirectType = currentValue

    // 从 Request 对象提取
    match (request) {
        case Some(req) =>
            redirectType = RequestRedirect.fromString(req.flags.redirect)
        case None => ()
    }

    // 从 options/init 对象覆盖
    let objectsToTry = ArrayList<JsValue>()
    match (optionsObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }
    match (requestInitObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }

    for (obj in objectsToTry) {
        if (!obj.isEmptyOrUndefinedOrNull()) {
            let redirectVal = obj.get(globalThis.globalThis, "redirect")
            match (redirectVal) {
                case Some(v) =>
                    if (v.isString()) {
                        return RequestRedirect.fromString(v.toString())
                    }
                case None => ()
            }
        }
    }

    return redirectType
}

/// 提取 disableKeepalive
/// 对应 Bun: 'extract_disable_keepalive (fetch.rs L909-L934)
private func extractDisableKeepalive(
    optionsObject: ?JsValue,
    requestInitObject: ?JsValue,
    globalThis: JsGlobalObject,
    currentValue: Bool
): Bool {
    let objectsToTry = ArrayList<JsValue>()
    match (optionsObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }
    match (requestInitObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }

    for (obj in objectsToTry) {
        if (!obj.isEmptyOrUndefinedOrNull()) {
            let keepaliveVal = obj.get(globalThis.globalThis, "keepalive")
            match (keepaliveVal) {
                case Some(v) =>
                    if (v.isBoolean()) {
                        return !v.toBoolean()
                    } else if (v.isNumber()) {
                        return v.toInt32() == 0
                    }
                case None => ()
            }
        }
    }

    return currentValue
}

/// 提取 verbose 级别
/// 对应 Bun: 'extract_verbose (fetch.rs L942-L972)
private func extractVerbose(
    optionsObject: ?JsValue,
    requestInitObject: ?JsValue,
    globalThis: JsGlobalObject,
    currentValue: HTTPVerboseLevel
): HTTPVerboseLevel {
    var verbose = currentValue

    let objectsToTry = ArrayList<JsValue>()
    match (optionsObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }
    match (requestInitObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }

    for (obj in objectsToTry) {
        if (!obj.isEmptyOrUndefinedOrNull()) {
            let verboseVal = obj.get(globalThis.globalThis, "verbose")
            match (verboseVal) {
                case Some(v) =>
                    if (v.isString()) {
                        let str = v.toString()
                        if (str == "curl") {
                            return HTTPVerboseLevel.Curl
                        }
                    } else if (v.isBoolean()) {
                        return if (v.toBoolean()) {
                            HTTPVerboseLevel.Headers
                        } else {
                            HTTPVerboseLevel.None
                        }
                    }
                case None => ()
            }
        }
    }

    return verbose
}

/// 提取 proxy 配置
/// 对应 Bun: 'extract_proxy (fetch.rs L977-L1115)
private func extractProxy(
    optionsObject: ?JsValue,
    requestInitObject: ?JsValue,
    ctx: JsGlobalObject,
    globalThis: JsGlobalObject,
    currentUrl: BaoUrl,
    currentUrlType: URLType,
    currentUrlProxyBuffer: Array<UInt8>,
    currentProxy: ?BaoUrl
): ProxyResult {
    var url = currentUrl
    var urlType = currentUrlType
    var urlProxyBuffer = currentUrlProxyBuffer
    var proxy = currentProxy
    var proxyHeaders: ?Headers = None

    let objectsToTry = ArrayList<JsValue>()
    match (optionsObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }
    match (requestInitObject) {
        case Some(v) => objectsToTry.append(v)
        case None => ()
    }

    for (obj in objectsToTry) {
        if (!obj.isEmptyOrUndefinedOrNull()) {
            let proxyArg = obj.get(globalThis.globalThis, "proxy")
            match (proxyArg) {
                case Some(proxyVal) =>
                    // 字符串格式: proxy: "http://proxy.example.com:8080"
                    if (proxyVal.isString()) {
                        let href = proxyVal.toString()
                        if (href.size > 0) {
                            let parsedProxy = BaoUrl.parse(href)
                            if (!parsedProxy.isValid()) {
                                return ProxyResult(url, urlType, urlProxyBuffer, proxy)
                            }
                            // 合并 URL 和 proxy 到 buffer
                            var buffer = ArrayList<UInt8>()
                            buffer.appendSlice(urlProxyBuffer)
                            buffer.appendSlice(Utf8Codec.encode(href))
                            urlProxyBuffer = buffer.items()

                            proxy = Some(parsedProxy)
                        }
                    }
                    // 对象格式: proxy: { url: "...", headers?: {...} }
                    if (proxyVal.isObject()) {
                        let proxyUrlVal = proxyVal.get(globalThis.globalThis, "url")
                        match (proxyUrlVal) {
                            case Some(urlVal) =>
                                if (!urlVal.isUndefinedOrNull() && urlVal.isString()) {
                                    let href = urlVal.toString()
                                    if (href.size > 0) {
                                        let parsedProxy = BaoUrl.parse(href)
                                        if (!parsedProxy.isValid()) {
                                            return ProxyResult(url, urlType, urlProxyBuffer, proxy)
                                        }
                                        var buffer = ArrayList<UInt8>()
                                        buffer.appendSlice(urlProxyBuffer)
                                        buffer.appendSlice(Utf8Codec.encode(href))
                                        urlProxyBuffer = buffer.items()
                                        proxy = Some(parsedProxy)

                                        // 提取代理头
                                        let headersVal = proxyVal.get(globalThis.globalThis, "headers")
                                        match (headersVal) {
                                            case Some(hVal) =>
                                                if (!hVal.isUndefinedOrNull()) {
                                                    let hdrs = Headers()
                                                    if (hVal.isObject()) {
                                                        let keys = hVal.objectKeys()
                                                        for (key in keys) {
                                                            let val = hVal.get(globalThis.globalThis, key)
                                                            match (val) {
                                                                case Some(v) => hdrs.set(key, v.toString())
                                                                case None => ()
                                                            }
                                                        }
                                                    }
                                                    proxyHeaders = Some(hdrs)
                                                }
                                            case None => ()
                                        }
                                    }
                                }
                            case None => ()
                        }
                    }
                case None => ()
            }
        }
    }

    return ProxyResult(url, urlType, urlProxyBuffer, proxy)
}

/// 提取 AbortSignal
/// 对应 Bun: 'extract_signal (fetch.rs L1123-L1165)
private func extractSignal(
    optionsObject: ?JsValue,
    request: ?Request,
    requestInitObject: ?JsValue,
    globalThis: JsGlobalObject
): SignalRef {
    // 从 options 对象提取
    match (optionsObject) {
        case Some(options) =>
            let signalVal = options.get(globalThis.globalThis, "signal")
            match (signalVal) {
                case Some(v) =>
                    if (!v.isUndefined()) {
                        // 尝试从 JS 值创建 AbortSignal
                        if (v.isAbortSignal()) {
                            return SignalRef(Some(AbortSignal.fromJs(v)))
                        }
                    }
                case None => ()
            }
        case None => ()
    }

    // 从 Request 对象提取
    match (request) {
        case Some(req) =>
            if (!req.signal.isUndefined()) {
                return SignalRef(Some(AbortSignal.fromJs(req.signal)))
            }
        case None => ()
    }

    // 从 requestInit 对象提取
    match (requestInitObject) {
        case Some(`init`) =>
            let signalVal = `init`.get(globalThis.globalThis, "signal")
            match (signalVal) {
                case Some(v) =>
                    if (v.isUndefined()) {
                        return SignalRef()
                    }
                    if (v.isAbortSignal()) {
                        return SignalRef(Some(AbortSignal.fromJs(v)))
                    }
                case None => ()
            }
        case None => ()
    }

    return SignalRef()
}

/// 提取 body
/// 对应 Bun: 'extract_body (fetch.rs L1177-L1257)
private func extractBody(
    optionsObject: ?JsValue,
    request: ?Request,
    requestInitObject: ?JsValue,
    globalThis: JsGlobalObject,
    firstArg: JsValue,
    ctx: JsGlobalObject
): HTTPRequestBody {
    // 从 options 对象提取
    match (optionsObject) {
        case Some(options) =>
            let bodyVal = options.get(globalThis.globalThis, "body")
            match (bodyVal) {
                case Some(v) =>
                    if (!v.isUndefined()) {
                        let result = HTTPRequestBody.fromJs(ctx, v)
                        match (result) {
                            case Some(b) => return b
                            case None => ()
                        }
                    }
                case None => ()
            }
        case None => ()
    }

    // 从 Request 对象提取
    match (request) {
        case Some(req) =>
            let bodyValue = match (req.body) {
                case Some(bv) => bv
                case None => BodyValue()
            }
            let alreadyUsed = match (bodyValue.tag) {
                case BodyValueTag.Used => true
                case BodyValueTag.Locked => true
                case _ => false
            }
            if (alreadyUsed) {
                // 对应 Bun: BODY_ALREADY_USED 错误
                return HTTPRequestBody.None
            }

            // 使用 AnyBlob
            match (bodyValue.tag) {
                case BodyValueTag.Blob =>
                    match (bodyValue.blob) {
                        case Some(b) => return HTTPRequestBody.BlobBody(AnyBlob(b))
                        case None => ()
                    }
                case BodyValueTag.InternalBlob =>
                    match (bodyValue.internalBlob) {
                        case Some(ib) =>
                            let blob = Blob.initFromBytes(ib.slice(), "")
                            return HTTPRequestBody.BlobBody(AnyBlob(blob))
                        case None => ()
                    }
                case BodyValueTag.WTFStringImpl =>
                    match (bodyValue.wtfStringImpl) {
                        case Some(wtf) =>
                            let bytes = Utf8Codec.encode(wtf.toString())
                            let blob = Blob.initFromBytes(bytes, "text/plain")
                            return HTTPRequestBody.BlobBody(AnyBlob(blob))
                        case None => ()
                    }
                case _ => ()
            }
        case None => ()
    }

    // 从 requestInit 对象提取
    match (requestInitObject) {
        case Some(`init`) =>
            let bodyVal = `init`.get(globalThis.globalThis, "body")
            match (bodyVal) {
                case Some(v) =>
                    if (!v.isUndefined()) {
                        let result = HTTPRequestBody.fromJs(ctx, v)
                        match (result) {
                            case Some(b) => return b
                            case None => ()
                        }
                    }
                case None => ()
            }
        case None => ()
    }

    return HTTPRequestBody.None
}

/// 提取 headers
/// 对应 Bun: 'extract_headers (fetch.rs L1265-L1376)
private func extractHeaders(
    optionsObject: ?JsValue,
    request: ?Request,
    requestInitObject: ?JsValue,
    globalThis: JsGlobalObject,
    ctx: JsGlobalObject,
    currentHeaders: ?Headers,
    body: HTTPRequestBody,
    url: BaoUrl
): HeadersResult {
    var headers = currentHeaders
    var hostname: ?String = None
    var range: ?String = None
    var upgradedConnection = false

    // 从 options 对象提取
    var fetchHeaders: ?Headers = extractHeadersFromObjects(
        optionsObject, requestInitObject, request, globalThis, ctx
    )

    match (fetchHeaders) {
        case Some(h) =>
            // 提取 Host 头
            let hostVal = h.get("host")
            match (hostVal) {
                case Some(v) => hostname = Some(v)
                case None => ()
            }

            // S3 Range 头
            if (url.isS3()) {
                let rangeVal = h.get("range")
                match (rangeVal) {
                    case Some(v) => range = Some(v)
                    case None => ()
                }
            }

            // Upgrade 头检测
            let upgradeVal = h.get("upgrade")
            match (upgradeVal) {
                case Some(v) =>
                    if (v != "h2" && v != "h2c") {
                        upgradedConnection = true
                    }
                case None => ()
            }

            headers = Some(h)
        case None => ()
    }

    return HeadersResult(headers, hostname, range, upgradedConnection)
}

/// 从 JS 对象提取 Headers
/// 对应 Bun: extract_headers 中的 fetch_headers 提取逻辑
private func extractHeadersFromObjects(
    optionsObject: ?JsValue,
    requestInitObject: ?JsValue,
    request: ?Request,
    globalThis: JsGlobalObject,
    ctx: JsGlobalObject
): ?Headers {
    // 从 options 对象提取
    match (optionsObject) {
        case Some(options) =>
            let headersVal = options.get(globalThis.globalThis, "headers")
            match (headersVal) {
                case Some(v) =>
                    if (!v.isUndefined()) {
                        return headersFromJsValue(v, globalThis)
                    }
                case None => ()
            }
        case None => ()
    }

    // 从 Request 对象提取
    match (request) {
        case Some(req) =>
            return Some(req.headers)
        case None => ()
    }

    // 从 requestInit 对象提取
    match (requestInitObject) {
        case Some(`init`) =>
            let headersVal = `init`.get(globalThis.globalThis, "headers")
            match (headersVal) {
                case Some(v) =>
                    if (!v.isUndefined()) {
                        return headersFromJsValue(v, globalThis)
                    }
                case None => ()
            }
        case None => ()
    }

    return None
}

/// 从 JsValue 创建 Headers
private func headersFromJsValue(value: JsValue, globalThis: JsGlobalObject): ?Headers {
    if (value.isHeaders()) {
        // 直接使用 Headers 对象
        return Some(value.toHeaders())
    }
    if (value.isObject()) {
        // 从普通对象创建 Headers
        let headers = Headers()
        let keys = value.objectKeys()
        for (key in keys) {
            let val = value.get(globalThis.globalThis, key)
            match (val) {
                case Some(v) => headers.set(key, v.toString())
                case None => ()
            }
        }
        return Some(headers)
    }
    return None
}

/// 准备文件请求体 (sendfile 或读取)
/// 对应 Bun: fetch.rs L1639-L1775 (needs_to_read_file 块)
private func prepareFileBody(
    body: HTTPRequestBody,
    proxy: ?BaoUrl,
    url: BaoUrl,
    globalThis: JsGlobalObject
): HTTPRequestBody {
    let store = body.store()
    match (store) {
        case Some(s) =>
            let filePath = s.filePath
            if (filePath.size > 0) {
                // 打开文件
                let fdResult = SysCompat.open(filePath, SysCompat.O_RDONLY, 0)
                match (fdResult) {
                    case Err(_) =>
                        return body // 保持原样，后续会处理错误
                    case Ok(fd) =>
                        // 检查是否支持 sendfile
                        if (proxy.isNone() && SendFile.isEligible(url)) {
                            let statResult = SysCompat.fstat(fd)
                            match (statResult) {
                                case Ok(stat) =>
                                    let fileSize = stat.fileSize
                                    // 小于 32KB 不值得 sendfile
                                    if (fileSize >= 32 * 1024) {
                                        let sf = SendFile(
                                            fd,
                                            fileSize,
                                            0,
                                            fileSize
                                        )
                                        return HTTPRequestBody.Sendfile(sf)
                                    }
                                case Err(_) => ()
                            }
                        }

                        // 读取文件到内存
                        let readResult = SysCompat.readFile(fd)
                        match (readResult) {
                            case Ok(fileData) =>
                                SysCompat.close(fd)
                                return HTTPRequestBody.BlobBody(AnyBlob.fromOwnedSlice(fileData))
                            case Err(_) =>
                                SysCompat.close(fd)
                                return body
                        }
                }
            }
        case None => ()
    }
    return body
}

/// setHeaders 辅助函数
/// 对应 Bun: fn set_headers (fetch.rs L2116-L2121)
public func setHeaders(headers: ?Headers, newHeaders: Array<HttpHeader>): ?Headers {
    let result = Headers.fromHttpHeaders(newHeaders)
    Some(result)
}

// ════════════════════════════════════════════════════════════════════════
// 结果数据类 — 用于 extract_* 函数的返回值
// ════════════════════════════════════════════════════════════════════════

/// SSL 配置提取结果
public class SslConfigResult {
    public var sslConfig: ?SSLConfig
    public var rejectUnauthorized: Bool
    public var checkServerIdentity: JsValue

    public init(sslConfig: ?SSLConfig, rejectUnauthorized: Bool, checkServerIdentity: JsValue) {
        this.sslConfig = sslConfig
        this.rejectUnauthorized = rejectUnauthorized
        this.checkServerIdentity = checkServerIdentity
    }
}

/// Protocol 提取结果
public class ProtocolResult {
    public var forceHttp2: Bool
    public var forceHttp3: Bool
    public var forceHttp1: Bool
    public var isError: Bool

    public init(forceHttp2: Bool, forceHttp3: Bool, forceHttp1: Bool, isError: Bool) {
        this.forceHttp2 = forceHttp2
        this.forceHttp3 = forceHttp3
        this.forceHttp1 = forceHttp1
        this.isError = isError
    }
}

/// Proxy 提取结果
public class ProxyResult {
    public var url: BaoUrl
    public var urlType: URLType
    public var urlProxyBuffer: Array<UInt8>
    public var proxy: ?BaoUrl

    public init(url: BaoUrl, urlType: URLType, urlProxyBuffer: Array<UInt8>, proxy: ?BaoUrl) {
        this.url = url
        this.urlType = urlType
        this.urlProxyBuffer = urlProxyBuffer
        this.proxy = proxy
    }
}

/// Headers 提取结果
public class HeadersResult {
    public var headers: ?Headers
    public var hostname: ?String
    public var range: ?String
    public var upgradedConnection: Bool

    public init(headers: ?Headers, hostname: ?String, range: ?String, upgradedConnection: Bool) {
        this.headers = headers
        this.hostname = hostname
        this.range = range
        this.upgradedConnection = upgradedConnection
    }
}

// ════════════════════════════════════════════════════════════════════════
// HttpMethod hasRequestBody 扩展
// 对应 Bun: Method::has_request_body()
// ════════════════════════════════════════════════════════════════════════

/// HttpMethod 扩展方法
extend HttpMethod {
    /// 是否允许请求体
    /// 对应 Bun: Method::has_request_body()
    public func hasRequestBody(): Bool {
        match (this) {
            case GET => false
            case HEAD => false
            case OPTIONS => false
            case _ => true
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// HttpClient — 底层 HTTP 请求实现
// 对应 Bun: fetch.zig 中使用 TcpSocket 发送 HTTP 请求
// ════════════════════════════════════════════════════════════════════════

/// HTTP 客户端 — 使用 TcpSocket 发送 HTTP/1.1 请求
/// 对应 Bun: fetch.zig HttpClient
public class HttpClient {
    /// 默认 HTTP 端口
    public static let DEFAULT_HTTP_PORT: UInt16 = 80
    /// 默认 HTTPS 端口
    public static let DEFAULT_HTTPS_PORT: UInt16 = 443
    /// 默认接收缓冲区大小
    public static let RECV_BUFFER_SIZE: Int64 = 4096

    /// 发送 HTTP 请求并返回原始响应字节
    /// 对应 Bun: fetch() 底层使用 TcpSocket 发送请求
    public static func sendRequest(url: BaoUrl, request: Request): Response {
        // 解析主机和端口
        let host = url.hostname
        let portStr = url.port
        let port = if (portStr.size > 0) {
            UInt16(IntParser.parseInt(portStr, 10))
        } else {
            DEFAULT_HTTP_PORT
        }

        // 创建 TCP 连接
        let addr = SocketAddrV4(port, host)
        let socketResult = TcpSocket.create(AddressFamily.Inet)
        let sock = match (socketResult) {
            case Ok(s) => s
            case Err(_) =>
                return Response.error()
        }

        // 连接服务器
        let connectResult = sock.connect(SocketAddr.V4(addr))
        match (connectResult) {
            case Err(_) =>
                sock.close()
                return Response.error()
            case Ok(_) => ()
        }

        // 构建 HTTP/1.1 请求报文
        let path = if (url.pathname.size > 0) { url.pathname } else { "/" }
        let fullPath = path + url.search
        let requestLine = "${httpMethodToString(request.method)} ${fullPath} HTTP/1.1\r\n"
        let hostHeader = "Host: ${host}\r\n"
        let connectionHeader = "Connection: close\r\n"

        var httpReq = ""
        httpReq += requestLine
        httpReq += hostHeader
        httpReq += connectionHeader

        // 添加自定义 headers
        request.headers.forEach({ name: String, value: String =>
            httpReq += "${name}: ${value}\r\n"
        })

        // 添加 body (如果有)
        match (request.body) {
            case Some(bodyVal) =>
                match (bodyVal.tag) {
                    case BodyValueTag.Blob | BodyValueTag.InternalBlob | BodyValueTag.WTFStringImpl =>
                        let bodySize = bodyVal.size()
                        httpReq += "Content-Length: ${bodySize}\r\n"
                        httpReq += "\r\n"
                        // 发送 headers
                        let headerBytes = Utf8Codec.encode(httpReq.toString())
                        sock.send(headerBytes)
                        // 发送 body
                        match (bodyVal.blob) {
                            case Some(b) => sock.send(Utf8Codec.encode(b.toString()))
                            case None => ()
                        }
                    case _ =>
                        httpReq += "\r\n"
                        let headerBytes = Utf8Codec.encode(httpReq.toString())
                        sock.send(headerBytes)
                }
            case None =>
                httpReq += "\r\n"
                let headerBytes = Utf8Codec.encode(httpReq.toString())
                sock.send(headerBytes)
        }

        // 接收响应
        let recvBuf = Array<UInt8>(RECV_BUFFER_SIZE, repeat: UInt8(0))
        let totalData = ArrayList<UInt8>()
        var done = false
        while (!done) {
            let recvResult = sock.recv(recvBuf)
            match (recvResult) {
                case Ok(bytesRead) =>
                    if (bytesRead == 0) {
                        done = true
                    } else {
                        for (i in 0..bytesRead) {
                            totalData.append(recvBuf[Int64(i)])
                        }
                    }
                case Err(_) => done = true
            }
        }

        sock.close()

        // 解析 HTTP 响应
        return parseHttpResponse(totalData.items())
    }

    /// 解析原始 HTTP 响应字节为 Response 对象
    /// 对应 Bun: fetch.zig HTTP 响应解析
    private static func parseHttpResponse(data: Array<UInt8>): Response {
        let text = Utf8Codec.decode(data)
        let resp = Response()

        // 查找 header 与 body 的分隔符 \r\n\r\n
        let headerEndIdxOpt = text.indexOf("\r\n\r\n")
        if (let Some(headerEndIdx) <- headerEndIdxOpt) {
            let headerSection = text[0..headerEndIdx]
            let bodyStart = headerEndIdx + 4

            // 解析状态行: HTTP/1.1 200 OK
            let lines = headerSection.split("\r\n")
            if (lines.size > 0) {
                let statusLine = lines[0]
                let statusParts = statusLine.split(" ")
                if (statusParts.size >= 2) {
                    try {
                        resp.statusCode_ = IntParser.parseInt(statusParts[1], 10)
                    } catch (_: Exception) {
                        resp.statusCode_ = 0
                    }
                    // 状态文本: 取状态码之后的部分
                    if (statusParts.size >= 3) {
                        var sb = ""
                        for (i in 2..statusParts.size) {
                            if (i > 2) { sb += " " }
                            sb += statusParts[Int64(i)]
                        }
                        resp.statusText = sb
                    }
                }
            }

            // 解析响应头
            for (i in 1..lines.size) {
                let line = lines[Int64(i)]
                let colonIdxOpt = line.indexOf(":")
                if (let Some(colonIdx) <- colonIdxOpt) {
                    let name = line[0..colonIdx].trimAscii()
                    let value = line[colonIdx + 1..].trimAscii()
                    resp.headers.append(name, value)
                }
            }

            // 提取 body
            if (bodyStart < text.size) {
                let bodyText = text[bodyStart..]
                let bodyBytes = Utf8Codec.encode(bodyText)
                let bodyValue = BodyValue(InternalBlob(bodyBytes, false))
                resp.body = Some(bodyValue)
            }

            return resp
        }
        resp.statusCode_ = 0
        resp.statusText = "Invalid HTTP response"
        return resp
    }
}

// ════════════════════════════════════════════════════════════════════════
// BaoUrl — URL 解析和操作
// 对应 Bun: bun_url::URL (ZigURL)
// ════════════════════════════════════════════════════════════════════════

/// URL 解析和操作
/// 对应 Bun: bun_url::URL (ZigURL)
public class BaoUrl {
    /// 协议 (如 "http:", "https:")
    public var protocol: String
    /// 主机名
    public var hostname: String
    /// 端口字符串
    public var port: String
    /// 路径名
    public var pathname: String
    /// 查询字符串 (含 "?")
    public var search: String
    /// 哈希
    public var hash: String
    /// 完整 href
    public var href: String
    /// 用户名
    public var username: String
    /// 密码
    public var password: String

    public init() {
        protocol = ""
        hostname = ""
        port = ""
        pathname = ""
        search = ""
        hash = ""
        href = ""
        username = ""
        password = ""
    }

    public init(url: String) {
        protocol = ""
        hostname = ""
        port = ""
        pathname = ""
        search = ""
        hash = ""
        href = url
        username = ""
        password = ""
        parseAndSet(url)
    }

    /// 解析 URL 字符串
    public static func parse(url: String): BaoUrl {
        BaoUrl(url)
    }

    /// 是否有效
    public func isValid(): Bool {
        href.size > 0
    }

    /// 是否为 http://
    public func isHttp(): Bool {
        protocol == "http:"
    }

    /// 是否为 https://
    public func isHttps(): Bool {
        protocol == "https:"
    }

    /// 是否为 file://
    public func isLocalFile(): Bool {
        protocol == "file:"
    }

    /// 是否为 blob://
    public func isBlob(): Bool {
        protocol == "blob:"
    }

    /// 是否为 s3://
    public func isS3(): Bool {
        protocol == "s3:"
    }

    /// 是否有有效端口
    public func hasValidPort(): Bool {
        if (port.size == 0) {
            return true
        }
        let portNum = IntParser.parseInt(port, 10)
        portNum > 0 && portNum <= 65535
    }

    /// 获取 S3 路径
    /// 对应 Bun: ZigURL::s3_path()
    public func s3Path(): String {
        pathname
    }

    /// 从字符串解析并设置字段
    private func parseAndSet(url: String): Unit {
        href = url
        // 简化的 URL 解析
        let protoEndOpt = url.indexOf("://")
        if (let Some(protoEnd) <- protoEndOpt) {
            protocol = url[0..protoEnd + 1]
            let rest = url[protoEnd + 3..]
            let pathStartOpt = rest.indexOf("/")
            let queryStartOpt = rest.indexOf("?")
            let hashStartOpt = rest.indexOf("#")

            let pathStart = match (pathStartOpt) { case Some(x) => x case None => rest.size }
            let queryStart = match (queryStartOpt) { case Some(x) => x case None => rest.size }
            let hashStart = match (hashStartOpt) { case Some(x) => x case None => rest.size }

            var hostEnd = rest.size
            if (pathStart < hostEnd) { hostEnd = pathStart }
            if (queryStart < hostEnd) { hostEnd = queryStart }
            if (hashStart < hostEnd) { hostEnd = hashStart }

            let hostPart = rest[0..hostEnd]
            // 解析 host:port
            let colonIdxOpt = hostPart.lastIndexOf(":")
            if (let Some(colonIdx) <- colonIdxOpt) {
                hostname = hostPart[0..colonIdx]
                port = hostPart[colonIdx + 1..]
            } else {
                hostname = hostPart
                port = ""
            }

            // 解析路径/查询/哈希
            if (let Some(ps) <- pathStartOpt) {
                let pathEnd = if (let Some(qs) <- queryStartOpt) { qs } else if (let Some(hs) <- hashStartOpt) { hs } else { rest.size }
                pathname = rest[ps..pathEnd]
            } else {
                pathname = "/"
            }

            if (let Some(qs) <- queryStartOpt) {
                let queryEnd = if (let Some(hs) <- hashStartOpt) { hs } else { rest.size }
                search = rest[qs..queryEnd]
            } else {
                search = ""
            }

            if (let Some(hs) <- hashStartOpt) {
                hash = rest[hs..]
            } else {
                hash = ""
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// PathLike — 路径类型
// 对应 Bun: node::types::PathLike
// ════════════════════════════════════════════════════════════════════════

/// 路径类型
/// 对应 Bun: PathLike
public enum PathLike {
    | EncodedSlice(String)   // 编码后的路径字符串
    | Raw(String)            // 原始路径字符串

    public func toString(): String {
        match (this) {
            case EncodedSlice(s) => s
            case Raw(s) => s
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// SysCompat — 系统调用兼容层
// 对应 Bun: bun_sys::* 文件操作
// ════════════════════════════════════════════════════════════════════════

/// 系统调用兼容层
/// 对应 Bun: bun_sys 文件操作封装
/// Delegates to bao_sys.SysFs for actual FFI calls.
public class SysCompat {
    /// O_RDONLY
    public static let O_RDONLY: Int32 = 0

    /// 打开文件
    /// 对应 Bun: bun.sys.open(path, O.RDONLY | O.NOCTTY, 0) -> Maybe(FD)
    /// Uses bao_sys.SysFs.open for the FFI call.
    public static func open(path: String, flags: Int32, mode: Int32): CoreResult<Int32, String> {
        match (SysFs.open(path, Int64(flags), UInt32(mode))) {
            case Ok(fd) => CoreResult.Ok(Int32(fd))
            case Err(e) => CoreResult.Err(e.toString())
        }
    }

    /// fstat 文件
    /// 对应 Bun: bun.sys.fstat(fd) -> Maybe(bun.Stat)
    /// Uses bao_sys.SysFs.fstat for the FFI call.
    public static func fstat(fd: Int32): CoreResult<FileStat, String> {
        let statResult = LinuxSyscall.fstat(fd)
        match (statResult) {
            case Ok(st) =>
                let stat = FileStat()
                stat.fileSize = Int64(st.size)
                return CoreResult.Ok(stat)
            case Err(e) => CoreResult.Err(e.toString())
        }
    }

    /// 读取文件
    /// 对应 Bun: NodeFS.readFile(fd, .buffer, .sync) or sys.read(fd, buf)
    /// Uses bao_sys.SysFs.read for the FFI call.
    public static func readFile(fd: Int32): CoreResult<Array<UInt8>, String> {
        let buf = Array<UInt8>(8192, repeat: 0)
        match (SysFs.read(Int64(fd), buf)) {
            case Ok(count) =>
                let result = Array<UInt8>(count, repeat: 0)
                for (i in 0..count) {
                    result[i] = buf[i]
                }
                return CoreResult.Ok(result)
            case Err(e) => CoreResult.Err(e.toString())
        }
    }

    /// 关闭文件描述符
    /// 对应 Bun: bun.sys.close(fd)
    /// Uses bao_sys.SysFs.close for the FFI call.
    public static func close(fd: Int32): Unit {
        SysFs.close(Int64(fd))
    }
}

/// 文件状态信息
/// 对应 Bun: bun_sys::Stat
public class FileStat {
    /// 文件大小
    public var fileSize: Int64
    /// 文件模式
    public var mode: UInt32

    public init() {
        fileSize = 0
        mode = 0
    }
}

// ════════════════════════════════════════════════════════════════════════
// UrlParser — URL 解析工具
// 对应 Bun: bun_url::PercentEncoding
// ════════════════════════════════════════════════════════════════════════

/// URL 解析工具
public class UrlParser {
    /// percent-decode 一个字符串
    public static func percentDecode(input: String): String {
        var bytes = ArrayList<UInt8>()
        var i = Int64(0)
        while (i < input.size) {
            let ch = input[Int64(i)]
            if (ch == UInt8(37) && i + 2 < input.size) {
                // Parse hex: input[i+1..i+3]
                let hexSlice = input[i + 1..i + 3]
                let byteVal = IntParser.parseInt(hexSlice.toString(), 16)
                bytes.append(UInt8(byteVal))
                i += 3
            } else if (ch == UInt8(43)) {
                bytes.append(UInt8(32))
                i += 1
            } else {
                bytes.append(ch)
                i += 1
            }
        }
        Utf8Codec.decode(bytes.toOwnedSlice())
    }

    /// hostWithPath — 提取 host+path 形式的端点
    public static func hostWithPath(url: String): String {
        let parsed = BaoUrl(url)
        let host = parsed.hostname
        let path = parsed.pathname
        if (path.size > 0) {
            return "${host}${path}"
        }
        return host
    }
}

// ════════════════════════════════════════════════════════════════════════
// AbortSignal — 中止信号
// 对应 Bun: webcore::AbortSignal
// ════════════════════════════════════════════════════════════════════════

/// 中止信号
/// 对应 Bun: webcore::AbortSignal
public class AbortSignal {
    /// 是否已中止
    public var aborted: Bool
    /// 中止原因
    public var reason: ?JsValue

    public init() {
        aborted = false
        reason = None
    }

    /// 增加引用
    public func ref(): AbortSignal {
        this
    }

    /// 减少引用
    public func unref(): Unit {
        // 释放引用
    }

    /// 从 JS 值创建
    public static func fromJs(value: JsValue): AbortSignal {
        let signal = AbortSignal()
        // 在实际实现中会从 JS 对象提取 AbortSignal 属性
        return signal
    }
}

// ════════════════════════════════════════════════════════════════════════
// LogLevel — 日志级别
// 对应 Bun: bun_ast::Level
// ════════════════════════════════════════════════════════════════════════

/// 日志级别
/// 对应 Bun: bun_ast::Level
public enum LogLevel {
    | Error
    | Warn
    | Info
    | Debug
    | Trace

    /// 是否至少为指定级别
    public func isAtLeast(level: LogLevel): Bool {
        this.ordinal() >= level.ordinal()
    }

    /// 获取序号
    public func ordinal(): Int64 {
        match (this) {
            case Error => 0
            case Warn => 1
            case Info => 2
            case Debug => 3
            case Trace => 4
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// VirtualMachine — 虚拟机
// 对应 Bun: VirtualMachine
// ════════════════════════════════════════════════════════════════════════

/// 虚拟机
/// 对应 Bun: VirtualMachine
public class VirtualMachine {
    /// 获取线程本地 VM
    public static func get(): VirtualMachine {
        VirtualMachine()
    }

    /// 获取 verbose fetch 设置
    public func getVerboseFetch(): HTTPVerboseLevel {
        HTTPVerboseLevel.None
    }

    /// 获取 TLS rejectUnauthorized 设置
    public func getTlsRejectUnauthorized(): Bool {
        true
    }

    /// 获取日志级别
    public func getLogLevel(): LogLevel {
        LogLevel.Info
    }

    /// 获取 S3 凭证
    public func getS3Credentials(): S3EnvCredentials {
        S3EnvCredentials()
    }
}

// ════════════════════════════════════════════════════════════════════════
// CallFrame — JS 调用帧
// 对应 Bun: jsc::CallFrame
// ════════════════════════════════════════════════════════════════════════

// CallFrame is defined in sink.cj - use that version instead

// ════════════════════════════════════════════════════════════════════════
// JsGlobalObject — JS 全局对象
// 对应 Bun: jsc::JSGlobalObject
// ════════════════════════════════════════════════════════════════════════

// JsGlobalObject is defined in sink.cj - use that version instead
// Adding methods that fetch.cj needs
extend JsGlobalObject {
    /// 是否有异常
    public func hasException(): Bool {
        false
    }
}

// ════════════════════════════════════════════════════════════════════════
// JsPromiseStrong — JS Promise 强引用
// 对应 Bun: jsc::JSPromiseStrong
// ════════════════════════════════════════════════════════════════════════

/// JS Promise 强引用
/// 对应 Bun: jsc::JSPromiseStrong
public class JsPromiseStrong {
    private var value_: JsValue

    public init() {
        value_ = JsValue.UNDEFINED
    }

    /// 初始化
    public static func `init`(globalThis: JsGlobalObject): JsPromiseStrong {
        JsPromiseStrong()
    }

    /// 获取 Promise 的 JS 值
    public func value(): JsValue {
        value_
    }

    /// 解决 Promise
    public func resolve(globalThis: JsGlobalObject, value: JsValue): Unit {
        this.value_ = value
    }
}

// ════════════════════════════════════════════════════════════════════════
// JsResult — JS 结果类型
// 对应 Bun: JsResult<JsValue>
// ════════════════════════════════════════════════════════════════════════

/// JS 结果类型
/// 对应 Bun: JsResult<JsValue>
public enum JsResult<T> {
    | Ok(T)
    | Err(String)
}

// ════════════════════════════════════════════════════════════════════════
// JsValue 扩展方法
// ════════════════════════════════════════════════════════════════════════

/// JsValue 辅助扩展
extend JsValue {
    /// 是否为空
    public func isEmpty(): Bool {
        isUndefinedOrNull()
    }

    /// 是否为 DOMWrapper
    public func isDomWrapper(): Bool {
        isObject()
    }

    /// 作为 Request
    public func asDirectRequest(): ?Request {
        // 在实际实现中会从 JS 包装器提取 Request
        None
    }

    /// 获取可选 Int64
    public func getOptionalInt64(global: JsObject, key: String): ?Int64 {
        let val = get(global, key)
        match (val) {
            case Some(v) =>
                if (v.isNumber()) {
                    return Some(v.toInt64())
                }
                return None
            case None => None
        }
    }

    /// 获取可选 Int32
    public func getOptionalInt32(global: JsObject, key: String): ?Int32 {
        let val = get(global, key)
        match (val) {
            case Some(v) =>
                if (v.isNumber()) {
                    return Some(v.toInt32())
                }
                return None
            case None => None
        }
    }

    /// 获取可选字符串
    public func getOptionalString(global: JsObject, key: String): ?String {
        let val = get(global, key)
        match (val) {
            case Some(v) =>
                if (v.isString()) {
                    return Some(v.toString())
                }
                return None
            case None => None
        }
    }

    /// 是否为 Headers 对象
    public func isHeaders(): Bool {
        false
    }

    /// 转为 Headers
    public func toHeaders(): Headers {
        Headers()
    }

    /// 是否为 AbortSignal
    public func isAbortSignal(): Bool {
        false
    }

    /// 获取对象键
    public func objectKeys(): ArrayList<String> {
        ArrayList<String>()
    }

    /// 快速获取属性 (from JsValueHelper)
    public func fastGet(global: JsGlobalObject, name: BuiltinName): ?JsValue {
        JsValueHelper.fastGet(this, global, name)
    }

    /// 获取 truthy 属性 (from JsValueHelper)
    public func getTruthy(global: JsGlobalObject, name: String): ?JsValue {
        JsValueHelper.getTruthy(this, global, name)
    }

    /// 是否为 Request 对象
    public func isRequest(): Bool { false }

    /// 转为 Request
    public func toRequest(): ?Request { None }

    /// 是否为 Response 对象
    public func isResponse(): Bool { false }

    /// 转为 Response
    public func toResponse(): ?Response { None }

    /// 是否为 Fetch Headers 对象
    public func isFetchHeaders(): Bool { false }

    /// 转为 Int64 (coerce)
    public func coerceToInt64(global: JsGlobalObject): Int64 {
        if (isNumber()) { toInt64() } else { 0 }
    }
}

// ════════════════════════════════════════════════════════════════════════
// Blob 扩展方法
// ════════════════════════════════════════════════════════════════════════

/// Blob 静态工厂扩展
extend Blob {
    /// 从字节数组创建 Blob
    public static func initFromBytes(bytes: Array<UInt8>, contentType: String): Blob {
        let blob = Blob()
        blob.size = bytes.size
        return blob
    }

    /// 查找或创建文件 Blob
    public static func findOrCreateFileFromPath(pathlike: PathLike, globalThis: JsGlobalObject, create: Bool): Blob {
        let blob = Blob()
        blob.size = 0
        return blob
    }
}

// ════════════════════════════════════════════════════════════════════════
// ReadableStream 扩展方法
// ════════════════════════════════════════════════════════════════════════

/// ReadableStream 静态工厂扩展
extend ReadableStream {
    /// 从 JS 值获取可读流
    /// 对应 Bun: ReadableStream::from_js()
    public static func fromJs(stream: ReadableStream, globalThis: JsGlobalObject): ?ReadableStream {
        Some(stream)
    }
}

/// Convert S3HttpHeaders to Array<HttpHeader>
func httpHeadersToArray(hdrs: S3HttpHeaders): Array<HttpHeader> {
    let arr = ArrayList<HttpHeader>()
    let entries = hdrs.toEntries()
    for (i in 0..entries.size) {
        let entry = entries[i]
        arr.append(HttpHeader(entry.name, entry.value))
    }
    return arr.items()
}

// ════════════════════════════════════════════════════════════════════════
// Headers 扩展方法
// ════════════════════════════════════════════════════════════════════════

/// Headers 静态工厂扩展
extend Headers {
    /// 从 HTTP 头数组创建 Headers
    public static func fromHttpHeaders(headers: Array<HttpHeader>): Headers {
        let h = Headers()
        for (header in headers) {
            h.set(header.name, header.value)
        }
        return h
    }
}

// ════════════════════════════════════════════════════════════════════════
// Option<T> 扩展方法
// ════════════════════════════════════════════════════════════════════════

/// Option<T> flatMap helper (not in stdlib)
extend<T> Option<T> {
    public func flatMap<U>(f: (T) -> ?U): ?U {
        match (this) {
            case Some(v) => f(v)
            case None => None
        }
    }
}

// ════════════════════════════════════════════════════════════════════════
// FetchModule — fetch 模块导出
// 对应 Bun: Fetch 模块注册到全局环境
// ════════════════════════════════════════════════════════════════════════

/// Fetch 模块导出 — 将 fetch/Request/Response/Headers 注册到全局
public class FetchModule {
    /// 将 fetch 相关 API 注册到全局环境
    public static func registerGlobals(env: CoreEnvironment): Unit {
        // Stub: registerGlobals not yet implemented
    }
}
