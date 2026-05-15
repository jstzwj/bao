// bao_http InternalState - HTTP 客户端内部状态
// 严格翻译自: bun/src/http/InternalState.zig
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// InternalState - HTTP 请求/响应内部状态机
// 严格翻译自: bun/src/http/InternalState.zig
//
// Bun 使用此结构管理 HTTP 请求的完整生命周期:
//   - 请求阶段: pending -> opened -> headers -> body -> done
//   - 响应阶段: pending -> headers -> body/body_chunk -> done
//   - 内容解码: gzip/deflate/brotli/zstd/chunked
//   - 重定向处理: is_redirect_pending
// ============================================================================

/// HTTP 阶段枚举
/// 严格翻译自: InternalState.HTTPStage
public enum HTTPStage {
    | pending     // 初始状态
    | opened      // onOpen 回调已调用 (仅请求)
    | headers     // 正在接收头部
    | body        // 正在接收 body (Content-Length)
    | bodyChunk   // 正在接收 chunked body
    | fail        // 请求失败
    | done        // 请求完成
    | proxyHandshake  // 代理握手阶段
    | proxyHeaders    // 代理头部阶段
    | proxyBody       // 代理 body 阶段
}

/// 连接阶段
/// 严格翻译自: InternalState.Stage (u8)
public enum Stage {
    | pending
    | connect
    | done
    | fail
}

/// 内容编码
/// 严格翻译自: bun/src/http_types/Encoding.zig
public enum Encoding {
    | identity   // 无编码
    | gzip       // gzip 压缩
    | deflate    // deflate 压缩
    | brotli     // brotli 压缩
    | zstd       // zstd 压缩
    | chunked    // chunked 传输编码

    /// 是否为压缩编码
    public func isCompressed(): Bool {
        match (this) {
            case gzip => true
            case deflate => true
            case brotli => true
            case zstd => true
            case identity => false
            case chunked => false
        }
    }

    /// 是否可以使用 libdeflate 加速
    public func canUseLibDeflate(): Bool {
        match (this) {
            case gzip => true
            case deflate => true
            case _ => false
        }
    }
}

/// 内部状态标志位
/// 严格翻译自: InternalState.InternalStateFlags (packed struct u8)
public class InternalStateFlags {
    /// 是否允许 keep-alive - 对应 allow_keepalive
    public var allowKeepalive: Bool
    /// 是否收到最后一个 chunk - 对应 received_last_chunk
    public var receivedLastChunk: Bool
    /// 是否已设置 content-encoding 处理 - 对应 did_set_content_encoding
    public var didSetContentEncoding: Bool
    /// 是否有重定向挂起 - 对应 is_redirect_pending
    public var isRedirectPending: Bool
    /// 是否禁用 libdeflate 快速路径 - 对应 is_libdeflate_fast_path_disabled
    public var isLibdeflateFastPathDisabled: Bool
    /// 重定向时是否重发请求体 - 对应 resend_request_body_on_redirect
    public var resendRequestBodyOnRedirect: Bool

    public init() {
        allowKeepalive = true
        receivedLastChunk = false
        didSetContentEncoding = false
        isRedirectPending = false
        isLibdeflateFastPathDisabled = false
        resendRequestBodyOnRedirect = false
    }
}

/// HTTP 请求体类型
/// 严格翻译自: bun/src/http/HTTPRequestBody.zig
public enum HTTPRequestBody {
    | bytes(String)           // 普通字节 body
    | stream(StreamBody)      // 流式 body
    | sendfile(SendFileBody)  // 零拷贝文件发送

    /// 获取 body 长度
    public func len(): Int64 {
        match (this) {
            case bytes(s) => s.size
            case stream(_) => -1  // 流式长度未知
            case sendfile(_) => -1
        }
    }

    /// 获取字节数据 (仅 bytes 模式)
    public func bytes(): String {
        match (this) {
            case bytes(s) => s
            case _ => ""
        }
    }

    public func deinit(): Unit {
        match (this) {
            case bytes(_) => () // 字符串由 GC 管理
            case stream(s) => s.detach()
            case sendfile(_) => ()
        }
    }
}

/// 流式请求体
/// 严格翻译自: bun/src/http/ThreadSafeStreamBuffer.zig (简化)
public class StreamBody {
    public var buffer: ?Array<UInt8>
    public var ended: Bool

    public init() {
        buffer = None
        ended = false
    }

    public func detach(): Unit {
        buffer = None
        ended = true
    }
}

/// 零拷贝文件发送
/// 严格翻译自: bun/src/http/SendFile.zig (简化)
public class SendFileBody {
    public var fd: Int64
    public var offset: Int64
    public var length: Int64

    public init(fd: Int64, offset: Int64, length: Int64) {
        this.fd = fd
        this.offset = offset
        this.length = length
    }
}

/// HTTP 响应元数据
/// 严格翻译自: HTTPClient.HTTPResponseMetadata
public class HTTPResponseMetadata {
    /// 响应 URL
    public var url: String
    /// 拥有的缓冲区
    public var ownedBuf: String
    /// 原始响应 (状态码 + 头部)
    public var response: ?RawResponse

    public init() {
        url = ""
        ownedBuf = ""
        response = None
    }

    public func deinit(): Unit {
        url = ""
        ownedBuf = ""
        response = None
    }
}

/// 原始 HTTP 响应 (对应 picohttp.Response)
public class RawResponse {
    public var statusCode: Int64
    public var statusText: String
    public var headers: ArrayList<HeaderPair>
    public var bytesRead: Int64

    public init() {
        statusCode = 0
        statusText = ""
        headers = ArrayList<HeaderPair>()
        bytesRead = 0
    }
}

/// 证书信息
/// 严格翻译自: bun/src/http/CertificateInfo.zig (简化)
public class CertificateInfo {
    public var cert: Array<UInt8>
    public var hostname: String
    public var certError: HTTPCertError

    public init(cert: Array<UInt8>, hostname: String, certError: HTTPCertError) {
        this.cert = cert
        this.hostname = hostname
        this.certError = certError
    }

    public func deinit(): Unit {
        cert = Array<UInt8>()
        hostname = ""
    }
}

/// HTTP 证书错误
public class HTTPCertError {
    public var errorNo: Int64
    public var code: String
    public var reason: String

    public init() {
        errorNo = 0
        code = ""
        reason = ""
    }

    public init(errorNo: Int64, code: String, reason: String) {
        this.errorNo = errorNo
        this.code = code
        this.reason = reason
    }
}

/// 可变字符串缓冲区
/// 对应 Bun: MutableString — 动态增长的字节数组
public class MutableString {
    public var data: ArrayList<UInt8>

    public init() {
        data = ArrayList<UInt8>()
    }

    /// 追加字节数据
    public func append(slice: Array<UInt8>): Unit {
        for (b in slice) {
            data.append(b)
        }
    }

    /// 追加字符串
    public func append(s: String): Unit {
        for (c in s) {
            data.append(UInt8(c.value & 0xFF))
        }
    }

    /// 获取长度
    public func len(): Int64 {
        return data.size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return data.size == 0
    }

    /// 重置
    public func reset(): Unit {
        data = ArrayList<UInt8>()
    }

    /// 确保容量
    public func ensureCapacity(capacity: Int64): Unit {
        while (data.size < capacity) {
            data.append(UInt8(0))
        }
    }

    /// 转字符串
    public func toString(): String {
        let sb = StringBuilder()
        for (b in data) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }
}

/// Decompressor 占位 — 对应 Bun: Decompressor union
/// Bun 支持 gzip/deflate/brotli/zstd 解压
public class Decompressor {
    public enum DecompressorType {
        | none
        | gzip
        | deflate
        | brotli
        | zstd
    }

    public var type_: DecompressorType

    public init() {
        type_ = DecompressorType.none
    }

    public func deinit(): Unit {
        type_ = DecompressorType.none
    }
}

/// HTTP 内部状态
/// 严格翻译自: bun/src/http/InternalState.zig InternalState struct
public class InternalState {
    // ========================================================================
    // 响应缓冲区
    // 严格翻译自: InternalState 中的缓冲区字段
    // ========================================================================

    /// 响应消息缓冲区 - 存放接收到的原始数据
    /// 对应 response_message_buffer: MutableString
    public var responseMessageBuffer: MutableString
    /// 挂起的响应 - 解析中的头部
    /// 对应 pending_response: ?picohttp.Response
    public var pendingResponse: ?RawResponse
    /// 已克隆的元数据 - 解析完成的头部
    /// 对应 cloned_metadata: ?HTTPResponseMetadata
    public var clonedMetadata: ?HTTPResponseMetadata

    // ========================================================================
    // 标志和编码
    // ========================================================================

    /// 内部状态标志
    public var flags: InternalStateFlags
    /// 传输编码 (chunked 等)
    /// 对应 transfer_encoding: Encoding
    public var transferEncoding: Encoding
    /// 内容编码 (gzip/deflate/brotli/zstd)
    /// 对应 encoding: Encoding
    public var encoding: Encoding
    /// Content-Encoding 头的索引
    /// 对应 content_encoding_i: u8
    public var contentEncodingI: UInt8

    // ========================================================================
    // 状态机
    // ========================================================================

    /// 连接阶段
    /// 对应 stage: Stage
    public var stage: Stage
    /// 请求阶段
    /// 对应 request_stage: HTTPStage
    public var requestStage: HTTPStage
    /// 响应阶段
    /// 对应 response_stage: HTTPStage
    public var responseStage: HTTPStage

    // ========================================================================
    // Body 相关
    // ========================================================================

    /// 用户拥有的 body 输出缓冲区
    /// 对应 body_out_str: ?*MutableString
    public var bodyOutStr: ?MutableString
    /// 压缩后的 body
    /// 对应 compressed_body: MutableString
    public var compressedBody: MutableString
    /// Content-Length
    /// 对应 content_length: ?usize
    public var contentLength: ?Int64
    /// 已接收的 body 总字节数
    /// 对应 total_body_received: usize
    public var totalBodyReceived: Int64
    /// 请求体数据
    /// 对应 request_body: []const u8
    public var requestBody: String
    /// 原始请求体
    /// 对应 original_request_body: HTTPRequestBody
    public var originalRequestBody: HTTPRequestBody
    /// 已发送的请求字节数
    /// 对应 request_sent_len: usize
    public var requestSentLen: Int64
    /// 失败错误
    /// 对应 fail: ?anyerror
    public var fail: ?String
    /// 解压器
    /// 对应 decompressor: Decompressor
    public var decompressor: Decompressor
    /// chunked 解码器状态
    /// 对应 chunked_decoder: picohttp.phr_chunked_decoder
    public var chunkedDecoderState: Int64  // 简化为状态整数
    /// 证书信息
    /// 对应 certificate_info: ?CertificateInfo
    public var certificateInfo: ?CertificateInfo

    public init() {
        responseMessageBuffer = MutableString()
        pendingResponse = None
        clonedMetadata = None
        flags = InternalStateFlags()
        transferEncoding = Encoding.identity
        encoding = Encoding.identity
        contentEncodingI = UInt8(255)
        stage = Stage.pending
        requestStage = HTTPStage.pending
        responseStage = HTTPStage.pending
        bodyOutStr = None
        compressedBody = MutableString()
        contentLength = None
        totalBodyReceived = 0
        requestBody = ""
        originalRequestBody = HTTPRequestBody.bytes("")
        requestSentLen = 0
        fail = None
        decompressor = Decompressor()
        chunkedDecoderState = 0
        certificateInfo = None
    }

    /// 初始化内部状态
    /// 严格翻译自: InternalState.init
    public static func initFunc(body: HTTPRequestBody, bodyOutStr: MutableString): InternalState {
        let state = InternalState()
        state.originalRequestBody = body
        state.requestBody = match (body) {
            case bytes(s) => s
            case _ => ""
        }
        state.bodyOutStr = Some(bodyOutStr)
        state.stage = Stage.pending
        state.pendingResponse = None
        return state
    }

    /// 是否为 chunked 编码
    /// 严格翻译自: InternalState.isChunkedEncoding
    public func isChunkedEncoding(): Bool {
        return transferEncoding == Encoding.chunked
    }

    /// 是否完成
    /// 严格翻译自: InternalState.isDone
    public func isDone(): Bool {
        if (isChunkedEncoding()) {
            return flags.receivedLastChunk
        }
        match (contentLength) {
            case Some(cl) => return totalBodyReceived >= cl
            case None => return flags.receivedLastChunk
        }
    }

    /// 获取 body 缓冲区
    /// 严格翻译自: InternalState.getBodyBuffer
    public func getBodyBuffer(): MutableString {
        if (encoding.isCompressed()) {
            return compressedBody
        }
        match (bodyOutStr) {
            case Some(buf) => return buf
            case None => return compressedBody  // fallback
        }
    }

    /// 重置状态
    /// 严格翻译自: InternalState.reset
    public func reset(): Unit {
        compressedBody.reset()
        responseMessageBuffer.reset()

        match (bodyOutStr) {
            case Some(buf) => buf.reset()
            case None => ()
        }

        decompressor.deinit()

        // 清理克隆的元数据
        match (clonedMetadata) {
            case Some(_) => {
                clonedMetadata = None
            }
            case None => ()
        }

        // 清理证书信息
        match (certificateInfo) {
            case Some(_) => certificateInfo = None
            case None => ()
        }

        originalRequestBody.deinit()

        // 重置所有字段
        responseMessageBuffer = MutableString()
        compressedBody = MutableString()
        pendingResponse = None
        clonedMetadata = None
        flags = InternalStateFlags()
        transferEncoding = Encoding.identity
        encoding = Encoding.identity
        contentEncodingI = UInt8(255)
        stage = Stage.pending
        requestStage = HTTPStage.pending
        responseStage = HTTPStage.pending
        contentLength = None
        totalBodyReceived = 0
        requestBody = ""
        originalRequestBody = HTTPRequestBody.bytes("")
        requestSentLen = 0
        fail = None
        certificateInfo = None
        chunkedDecoderState = 0
    }

    /// 处理 body 缓冲区
    /// 严格翻译自: InternalState.processBodyBuffer
    public func processBodyBuffer(buffer: MutableString, isFinalChunk: Bool): Bool {
        if (flags.isRedirectPending) {
            return false
        }

        let bodyOut = match (bodyOutStr) {
            case Some(buf) => buf
            case None => return false
        }

        match (encoding) {
            case brotli => {
                // 解压逻辑
                // 简化: 直接追加
                bodyOut.append(buffer.data.toArray())
            }
            case gzip => {
                bodyOut.append(buffer.data.toArray())
            }
            case deflate => {
                bodyOut.append(buffer.data.toArray())
            }
            case zstd => {
                bodyOut.append(buffer.data.toArray())
            }
            case _ => {
                bodyOut.append(buffer.data.toArray())
            }
        }

        return bodyOut.len() > 0
    }
}
