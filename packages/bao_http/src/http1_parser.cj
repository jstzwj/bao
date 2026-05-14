// bao_http http1_parser - HTTP/1.1 增量式请求/响应解析器
// 严格翻译自: src/http_types/ HTTP/1.1 parsing
// 参考: src/http/http.zig 中 picohttp 有限状态机解析器
//   Bun 使用 picohttp (picohttpparser) C 库实现零拷贝 HTTP/1.1 解析
//   picohttp 底层是基于索引的状态机，避免逐字符分支
//   仓颉实现保持等价的增量解析语义，支持流式输入
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// Http1ParseState - 解析器状态
// 严格翻译自: picohttp phr_parse_request/phr_parse_response 的内部状态机
// picohttp 使用 char* 指针追踪位置，仓颉使用索引
// ============================================================================

/// HTTP/1.1 解析器状态
/// 对应 picohttp 内部枚举: { nothing, request_line, header_field, ... }
public enum Http1ParseState {
    | Init            // 初始状态，等待请求行/状态行
    | RequestMethod   // 正在解析 HTTP 方法
    | RequestUri      // 正在解析请求 URI
    | RequestVersion  // 正在解析 HTTP 版本号
    | StatusVersion   // 正在解析响应的 HTTP 版本
    | StatusCode      // 正在解析状态码
    | StatusReason    // 正在解析状态原因短语
    | HeaderName      // 正在解析头部字段名
    | HeaderValue     // 正在解析头部字段值
    | HeaderFold      // 头部折叠续行 (obs-fold: CRLF + SP/HTAB)
    | BodyIdentity    // 等待 Content-Length 长度的 body
    | BodyChunked     // 等待 chunked 编码的 body
    | ChunkSize       // 正在解析 chunk 大小 (hex)
    | ChunkData       // 正在读取 chunk 数据
    | ChunkTrailer    // 正在读取 chunk 尾部 \r\n
    | ChunkEnd        // 等待终止 chunk (0\r\n\r\n)
    | Trailers        // 正在解析 trailer 头部
    | Complete        // 解析完成
    | Error           // 解析错误
}

// ============================================================================
// Http1ParseResult - 解析结果
// ============================================================================

/// HTTP/1.1 增量解析结果
/// 对应 picohttp 返回值: > 0 表示消耗的字节数，-1 表示需要更多数据，-2 表示错误
public class Http1ParseResult {
    /// 消耗的字节数
    public var bytesConsumed: Int64
    /// 是否解析完成
    public var complete: Bool
    /// 是否需要更多数据
    public var needsMore: Bool
    /// 错误消息
    public var errorMessage: ?String

    public init() {
        bytesConsumed = 0
        complete = false
        needsMore = false
        errorMessage = None
    }

    public static func consumed(n: Int64): Http1ParseResult {
        let r = Http1ParseResult()
        r.bytesConsumed = n
        return r
    }

    public static func more(): Http1ParseResult {
        let r = Http1ParseResult()
        r.needsMore = true
        return r
    }

    public static func done(n: Int64): Http1ParseResult {
        let r = Http1ParseResult()
        r.bytesConsumed = n
        r.complete = true
        return r
    }

    public static func err(msg: String): Http1ParseResult {
        let r = Http1ParseResult()
        r.complete = true
        r.errorMessage = Some(msg)
        return r
    }
}

// ============================================================================
// Http1RequestParser - HTTP/1.1 增量式请求解析器
// 严格翻译自: picohttp phr_parse_request
//   Bun 在 src/http/http.zig 中使用 picohttp_request_parse 解析入站请求
//   支持增量解析: 多次 feed() 调用直到请求完整
//   支持 pipeline: 一个 TCP 读取可能包含多个请求
// ============================================================================

/// HTTP/1.1 增量式请求解析器
/// 对应 picohttp phr_parse_request 的状态机实现
/// 支持 keep-alive 连接上的多个请求 (HTTP pipelining)
public class Http1RequestParser {
    /// 当前解析状态
    private var state: Http1ParseState
    /// 解析缓冲区
    private var buffer: Array<UInt8>
    /// 缓冲区中已解析的位置
    private var position: Int64
    /// 解析出的方法
    public var method: String
    /// 解析出的路径
    public var path: String
    /// 解析出的 HTTP 次版本号 (0 = HTTP/1.0, 1 = HTTP/1.1)
    public var minorVersion: Int64
    /// 解析出的头部列表
    public var headers: ArrayList<HeaderPair>
    /// 请求体
    public var body: Array<UInt8>
    /// Content-Length 值 (-1 表示未指定)
    private var contentLength: Int64
    /// 是否 Transfer-Encoding: chunked
    private var chunked: Bool
    /// 当前头部名称暂存
    private var currentHeaderName: String
    /// 当前头部值暂存
    private var currentHeaderValue: String
    /// chunk 大小暂存
    private var chunkSize: Int64
    /// 已接收 body 长度
    private var bodyReceived: Int64
    /// 最大头部大小限制 (默认 16KB，对应 Bun BUN_DEFAULT_MAX_HTTP_HEADER_SIZE)
    private var maxHeaderSize: Int64
    /// 最大 body 大小限制
    private var maxBodySize: Int64

    public init() {
        state = Http1ParseState.Init
        buffer = Array<UInt8>()
        position = 0
        method = ""
        path = ""
        minorVersion = 1
        headers = ArrayList<HeaderPair>()
        body = Array<UInt8>()
        contentLength = -1
        chunked = false
        currentHeaderName = ""
        currentHeaderValue = ""
        chunkSize = 0
        bodyReceived = 0
        maxHeaderSize = 16384  // 16KB - 对应 Bun 默认值
        maxBodySize = 104857600  // 100MB
    }

    /// 重置解析器用于复用 (keep-alive 连接上的下一个请求)
    /// 对应 Bun HTTPContext 在 keep-alive 循环中重置解析状态
    public func reset(): Unit {
        state = Http1ParseState.Init
        // 将未消费的数据移到缓冲区头部 (pipeline 支持)
        if (position < buffer.size) {
            let remaining = Array<UInt8>()
            for (i in position..buffer.size) {
                remaining.append(buffer[i])
            }
            buffer = remaining
        } else {
            buffer = Array<UInt8>()
        }
        position = 0
        method = ""
        path = ""
        minorVersion = 1
        headers = ArrayList<HeaderPair>()
        body = Array<UInt8>()
        contentLength = -1
        chunked = false
        currentHeaderName = ""
        currentHeaderValue = ""
        chunkSize = 0
        bodyReceived = 0
    }

    /// 获取未消费的数据 (用于 pipeline)
    public func remainingBytes(): Array<UInt8> {
        if (position >= buffer.size) {
            return Array<UInt8>()
        }
        let result = Array<UInt8>()
        for (i in position..buffer.size) {
            result.append(buffer[i])
        }
        return result
    }

    // ========================================================================
    // feed - 输入数据增量解析
    // 对应 picohttp 的增量解析接口
    // picohttp 通过返回值 > 0 表示消耗字节数，-1 表示需要更多数据
    // ========================================================================

    /// 输入数据进行增量解析
    /// 对应 picohttp phr_parse_request(buf, len, &method, &path, &minor_version, &headers, &num_headers, last)
    /// 返回消耗的字节数，或 -1 表示需要更多数据
    public func feed(data: Array<UInt8>): Http1ParseResult {
        // 追加到缓冲区
        for (b in data) {
            buffer.append(b)
        }

        if (state == Http1ParseState.Complete || state == Http1ParseState.Error) {
            return Http1ParseResult.consumed(data.size)
        }

        var startPos = position

        // 解析请求行 + 头部
        if (state == Http1ParseState.Init || state == Http1ParseState.RequestMethod ||
            state == Http1ParseState.RequestUri || state == Http1ParseState.RequestVersion ||
            state == Http1ParseState.HeaderName || state == Http1ParseState.HeaderValue ||
            state == Http1ParseState.HeaderFold) {

            let headerResult = parseHeaders()
            if (headerResult == -1) {
                return Http1ParseResult.more()
            }
            if (headerResult == -2) {
                state = Http1ParseState.Error
                return Http1ParseResult.err("Failed to parse HTTP/1.1 request headers")
            }

            // 头部解析完成，检查 body
            position = headerResult

            // 检查头部大小限制
            if (position > maxHeaderSize) {
                state = Http1ParseState.Error
                return Http1ParseResult.err("HTTP headers too large (max ${maxHeaderSize} bytes)")
            }

            // 确定 body 模式
            determineBodyMode()

            if (chunked) {
                state = Http1ParseState.BodyChunked
            } else if (contentLength > 0) {
                state = Http1ParseState.BodyIdentity
            } else {
                // 无 body (GET/HEAD/DELETE 等)
                state = Http1ParseState.Complete
                return Http1ParseResult.done(position)
            }
        }

        // 解析 body
        if (state == Http1ParseState.BodyIdentity) {
            let remaining = buffer.size - position
            let needed = contentLength - bodyReceived
            if (remaining >= needed) {
                for (i in 0..needed) {
                    body.append(buffer[position + i])
                }
                position += needed
                bodyReceived = contentLength
                state = Http1ParseState.Complete
                return Http1ParseResult.done(position)
            } else {
                // 需要更多数据
                for (i in 0..remaining) {
                    body.append(buffer[position + i])
                }
                bodyReceived += remaining
                position = buffer.size
                return Http1ParseResult.more()
            }
        }

        if (state == Http1ParseState.BodyChunked) {
            return parseChunkedBody()
        }

        return Http1ParseResult.more()
    }

    /// 是否解析完成
    public func isComplete(): Bool {
        return state == Http1ParseState.Complete
    }

    /// 是否出错
    public func hasError(): Bool {
        return state == Http1ParseState.Error
    }

    /// 获取解析出的方法名
    public func getMethod(): HttpMethod {
        return HttpMethod.fromString(method)
    }

    // ========================================================================
    // 内部解析方法
    // ========================================================================

    /// 解析头部 (请求行 + 头部字段)
    /// 返回消耗的字节数, -1 需要更多, -2 错误
    private func parseHeaders(): Int64 {
        // 查找 \r\n\r\n 头部结束标记
        let headerEnd = findCrlfCrlf()
        if (headerEnd < 0) {
            return -1  // 需要更多数据
        }

        var pos: Int64 = 0

        // === 解析请求行 ===
        // 对应 picohttp: method SP request-target SP HTTP-version CRLF
        let firstLineEnd = findCrlf(pos)
        if (firstLineEnd < 0) {
            return -2
        }
        let requestLine = bufferSliceToString(pos, firstLineEnd)
        pos = firstLineEnd + 2  // 跳过 \r\n

        // 解析方法
        let sp1 = requestLine.indexOf(" ")
        if (sp1 < 0) {
            return -2
        }
        method = requestLine.substring(0, sp1)

        // 解析路径
        let afterMethod = requestLine.substring(sp1 + 1)
        let sp2 = afterMethod.indexOf(" ")
        if (sp2 < 0) {
            return -2
        }
        path = afterMethod.substring(0, sp2)

        // 解析版本号: HTTP/1.x
        let versionStr = afterMethod.substring(sp2 + 1)
        if (versionStr.startsWith("HTTP/1.")) {
            let minorStr = versionStr.substring(7)
            try {
                minorVersion = Int64.parse(minorStr)
            } catch (_: Exception) {
                minorVersion = 1
            }
        }

        // === 解析头部字段 ===
        // 对应 picohttp 逐行解析 header，支持折叠续行 (obs-fold)
        while (pos < headerEnd) {
            let lineEnd = findCrlf(pos)
            if (lineEnd < 0 || lineEnd > headerEnd) {
                lineEnd = headerEnd
            }

            // 检查折叠续行: 以 SP 或 HTAB 开头的行是上一行的续行
            // RFC 7230 §3.2.4: obs-fold = CRLF 1*( SP / HTAB )
            if (buffer[pos] == UInt8(32) || buffer[pos] == UInt8(9)) {
                // 折叠续行 - 追加到当前值
                let foldValue = bufferSliceToString(pos, lineEnd).trim()
                if (currentHeaderName.size > 0) {
                    currentHeaderValue = currentHeaderValue + " " + foldValue
                }
            } else {
                // 先保存上一个头部
                if (currentHeaderName.size > 0) {
                    headers.append(HeaderPair(currentHeaderName, currentHeaderValue))
                }

                // 解析新的 Name: Value
                let line = bufferSliceToString(pos, lineEnd)
                let colonIdx = line.indexOf(":")
                if (colonIdx >= 0) {
                    currentHeaderName = line.substring(0, colonIdx).trim()
                    currentHeaderValue = line.substring(colonIdx + 1).trim()
                } else {
                    // 空行或格式错误
                    currentHeaderName = ""
                    currentHeaderValue = ""
                }
            }

            pos = lineEnd + 2  // 跳过 \r\n
        }

        // 保存最后一个头部
        if (currentHeaderName.size > 0) {
            headers.append(HeaderPair(currentHeaderName, currentHeaderValue))
            currentHeaderName = ""
            currentHeaderValue = ""
        }

        return headerEnd + 4  // 跳过 \r\n\r\n
    }

    /// 确定 body 传输模式
    private func determineBodyMode(): Unit {
        for (h in headers) {
            if (h.name.toLower() == "transfer-encoding" && h.value.toLower().contains("chunked")) {
                chunked = true
            }
            if (h.name.toLower() == "content-length") {
                try {
                    contentLength = Int64.parse(h.value.trim())
                } catch (_: Exception) {
                    contentLength = -1
                }
            }
        }
    }

    /// 解析 chunked body
    private func parseChunkedBody(): Http1ParseResult {
        while (position < buffer.size) {
            // 读取 chunk 大小行
            let lineEnd = findCrlf(position)
            if (lineEnd < 0) {
                return Http1ParseResult.more()
            }

            let sizeStr = bufferSliceToString(position, lineEnd).trim()
            // 跳过分块扩展 (;xxx)
            let semiIdx = sizeStr.indexOf(";")
            let hexStr = if (semiIdx >= 0) { sizeStr.substring(0, semiIdx).trim() } else { sizeStr }

            chunkSize = hexToInt(hexStr)
            position = lineEnd + 2  // 跳过 chunk 大小行的 \r\n

            if (chunkSize == 0) {
                // 终止 chunk - 还需要最终的 \r\n
                if (position + 2 <= buffer.size) {
                    position += 2  // 跳过终止 \r\n
                    state = Http1ParseState.Complete
                    return Http1ParseResult.done(position)
                }
                return Http1ParseResult.more()
            }

            // 读取 chunk 数据
            if (position + chunkSize + 2 > buffer.size) {
                return Http1ParseResult.more()
            }

            for (i in 0..chunkSize) {
                body.append(buffer[position + i])
            }
            position += chunkSize + 2  // 数据 + \r\n
        }

        return Http1ParseResult.more()
    }

    // ========================================================================
    // 缓冲区工具
    // ========================================================================

    /// 查找 \r\n\r\n 位置
    private func findCrlfCrlf(): Int64 {
        if (buffer.size < 4) {
            return -1
        }
        var i: Int64 = position
        while (i < buffer.size - 3) {
            if (buffer[i] == UInt8(13) && buffer[i + 1] == UInt8(10) &&
                buffer[i + 2] == UInt8(13) && buffer[i + 3] == UInt8(10)) {
                return i
            }
            i += 1
        }
        return -1
    }

    /// 查找指定位置之后的 \r\n
    private func findCrlf(from: Int64): Int64 {
        var i = from
        while (i < buffer.size - 1) {
            if (buffer[i] == UInt8(13) && buffer[i + 1] == UInt8(10)) {
                return i
            }
            i += 1
        }
        return -1
    }

    /// 缓冲区切片转字符串
    private func bufferSliceToString(start: Int64, end: Int64): String {
        let sb = StringBuilder()
        var i = start
        while (i < end && i < buffer.size) {
            sb.append(Char(Int32(buffer[i])))
            i += 1
        }
        return sb.toString()
    }

    /// 十六进制字符串转整数
    private static func hexToInt(hex: String): Int64 {
        var result: Int64 = 0
        for (c in hex) {
            result = result * 16
            if (c >= '0' && c <= '9') {
                result += Int64(c.value) - 48
            } else if (c >= 'a' && c <= 'f') {
                result += Int64(c.value) - 87
            } else if (c >= 'A' && c <= 'F') {
                result += Int64(c.value) - 55
            }
        }
        return result
    }
}

// ============================================================================
// Http1ResponseParser - HTTP/1.1 增量式响应解析器
// 严格翻译自: picohttp phr_parse_response
//   Bun 在 src/http/http.zig 中使用 picohttp_response_parse 解析服务端响应
//   与请求解析器结构类似，但解析状态行而非请求行
// ============================================================================

/// HTTP/1.1 增量式响应解析器
/// 对应 picohttp phr_parse_response 状态机
public class Http1ResponseParser {
    /// 当前解析状态
    private var state: Http1ParseState
    /// 解析缓冲区
    private var buffer: Array<UInt8>
    /// 缓冲区中已解析的位置
    private var position: Int64
    /// HTTP 版本
    public var httpVersion: String
    /// 状态码
    public var statusCode: Int64
    /// 状态原因短语
    public var statusText: String
    /// 响应头列表
    public var headers: ArrayList<HeaderPair>
    /// 响应体
    public var body: Array<UInt8>
    /// Content-Length (-1 表示未指定)
    private var contentLength: Int64
    /// 是否 chunked
    private var chunked: Bool
    /// 是否 Connection: close (读取直到 EOF)
    private var connectionClose: Bool
    /// 当前头部名称暂存
    private var currentHeaderName: String
    /// 当前头部值暂存
    private var currentHeaderValue: String
    /// chunk 大小暂存
    private var chunkSize: Int64
    /// 已接收 body 长度
    private var bodyReceived: Int64
    /// 最大头部大小
    private var maxHeaderSize: Int64

    public init() {
        state = Http1ParseState.Init
        buffer = Array<UInt8>()
        position = 0
        httpVersion = "HTTP/1.1"
        statusCode = 0
        statusText = ""
        headers = ArrayList<HeaderPair>()
        body = Array<UInt8>()
        contentLength = -1
        chunked = false
        connectionClose = false
        currentHeaderName = ""
        currentHeaderValue = ""
        chunkSize = 0
        bodyReceived = 0
        maxHeaderSize = 16384
    }

    /// 重置解析器
    public func reset(): Unit {
        state = Http1ParseState.Init
        if (position < buffer.size) {
            let remaining = Array<UInt8>()
            for (i in position..buffer.size) {
                remaining.append(buffer[i])
            }
            buffer = remaining
        } else {
            buffer = Array<UInt8>()
        }
        position = 0
        httpVersion = "HTTP/1.1"
        statusCode = 0
        statusText = ""
        headers = ArrayList<HeaderPair>()
        body = Array<UInt8>()
        contentLength = -1
        chunked = false
        connectionClose = false
        currentHeaderName = ""
        currentHeaderValue = ""
        chunkSize = 0
        bodyReceived = 0
    }

    /// 获取未消费的数据
    public func remainingBytes(): Array<UInt8> {
        if (position >= buffer.size) {
            return Array<UInt8>()
        }
        let result = Array<UInt8>()
        for (i in position..buffer.size) {
            result.append(buffer[i])
        }
        return result
    }

    /// 输入数据进行增量解析
    /// 对应 picohttp phr_parse_response
    public func feed(data: Array<UInt8>): Http1ParseResult {
        for (b in data) {
            buffer.append(b)
        }

        if (state == Http1ParseState.Complete || state == Http1ParseState.Error) {
            return Http1ParseResult.consumed(data.size)
        }

        // 解析状态行 + 头部
        if (state == Http1ParseState.Init || state == Http1ParseState.StatusVersion ||
            state == Http1ParseState.StatusCode || state == Http1ParseState.StatusReason ||
            state == Http1ParseState.HeaderName || state == Http1ParseState.HeaderValue ||
            state == Http1ParseState.HeaderFold) {

            let headerResult = parseResponseHeaders()
            if (headerResult == -1) {
                return Http1ParseResult.more()
            }
            if (headerResult == -2) {
                state = Http1ParseState.Error
                return Http1ParseResult.err("Failed to parse HTTP/1.1 response")
            }

            position = headerResult

            if (position > maxHeaderSize) {
                state = Http1ParseState.Error
                return Http1ParseResult.err("HTTP response headers too large")
            }

            // HEAD 响应和无状态码没有 body
            determineResponseBodyMode()

            if (chunked) {
                state = Http1ParseState.BodyChunked
            } else if (contentLength > 0) {
                state = Http1ParseState.BodyIdentity
            } else if (contentLength == 0) {
                state = Http1ParseState.Complete
                return Http1ParseResult.done(position)
            } else {
                // 无 Content-Length 且非 chunked: 读取直到连接关闭
                // 对应 HTTP/1.0 或 Connection: close 的情况
                if (connectionClose) {
                    // 将所有剩余数据作为 body
                    for (i in position..buffer.size) {
                        body.append(buffer[i])
                    }
                    position = buffer.size
                    return Http1ParseResult.more()  // 需要连接关闭才知道结束
                }
                state = Http1ParseState.Complete
                return Http1ParseResult.done(position)
            }
        }

        // 解析 body (与请求解析器共享逻辑)
        if (state == Http1ParseState.BodyIdentity) {
            let remaining = buffer.size - position
            let needed = contentLength - bodyReceived
            if (remaining >= needed) {
                for (i in 0..needed) {
                    body.append(buffer[position + i])
                }
                position += needed
                bodyReceived = contentLength
                state = Http1ParseState.Complete
                return Http1ParseResult.done(position)
            } else {
                for (i in 0..remaining) {
                    body.append(buffer[position + i])
                }
                bodyReceived += remaining
                position = buffer.size
                return Http1ParseResult.more()
            }
        }

        if (state == Http1ParseState.BodyChunked) {
            return parseChunkedBody()
        }

        return Http1ParseResult.more()
    }

    /// 标记连接已关闭 (用于 connectionClose 模式)
    public func markConnectionClosed(): Http1ParseResult {
        if (connectionClose && state != Http1ParseState.Complete) {
            state = Http1ParseState.Complete
            return Http1ParseResult.done(position)
        }
        return Http1ParseResult.consumed(0)
    }

    /// 是否解析完成
    public func isComplete(): Bool {
        return state == Http1ParseState.Complete
    }

    /// 是否出错
    public func hasError(): Bool {
        return state == Http1ParseState.Error
    }

    // ========================================================================
    // 内部解析方法
    // ========================================================================

    /// 解析响应头部 (状态行 + 头部字段)
    /// 返回消耗的字节数, -1 需要更多, -2 错误
    private func parseResponseHeaders(): Int64 {
        let headerEnd = findCrlfCrlf()
        if (headerEnd < 0) {
            return -1
        }

        var pos: Int64 = 0

        // === 解析状态行 ===
        // 对应 picohttp: HTTP-version SP status-code SP reason-phrase CRLF
        let firstLineEnd = findCrlf(pos)
        if (firstLineEnd < 0) {
            return -2
        }
        let statusLine = bufferSliceToString(pos, firstLineEnd)
        pos = firstLineEnd + 2

        // 解析版本: HTTP/1.x
        let sp1 = statusLine.indexOf(" ")
        if (sp1 < 0) {
            return -2
        }
        httpVersion = statusLine.substring(0, sp1)

        // 解析状态码和原因短语
        let afterVersion = statusLine.substring(sp1 + 1)
        let sp2 = afterVersion.indexOf(" ")
        if (sp2 < 0) {
            // 仅有状态码无原因短语
            try {
                statusCode = Int64.parse(afterVersion.trim())
            } catch (_: Exception) {
                return -2
            }
            statusText = ""
        } else {
            try {
                statusCode = Int64.parse(afterVersion.substring(0, sp2))
            } catch (_: Exception) {
                return -2
            }
            statusText = afterVersion.substring(sp2 + 1)
        }

        // === 解析头部字段 === (与请求解析器相同的逻辑)
        while (pos < headerEnd) {
            let lineEnd = findCrlf(pos)
            if (lineEnd < 0 || lineEnd > headerEnd) {
                lineEnd = headerEnd
            }

            // 折叠续行检测
            if (buffer[pos] == UInt8(32) || buffer[pos] == UInt8(9)) {
                let foldValue = bufferSliceToString(pos, lineEnd).trim()
                if (currentHeaderName.size > 0) {
                    currentHeaderValue = currentHeaderValue + " " + foldValue
                }
            } else {
                if (currentHeaderName.size > 0) {
                    headers.append(HeaderPair(currentHeaderName, currentHeaderValue))
                }

                let line = bufferSliceToString(pos, lineEnd)
                let colonIdx = line.indexOf(":")
                if (colonIdx >= 0) {
                    currentHeaderName = line.substring(0, colonIdx).trim()
                    currentHeaderValue = line.substring(colonIdx + 1).trim()
                } else {
                    currentHeaderName = ""
                    currentHeaderValue = ""
                }
            }

            pos = lineEnd + 2
        }

        if (currentHeaderName.size > 0) {
            headers.append(HeaderPair(currentHeaderName, currentHeaderValue))
            currentHeaderName = ""
            currentHeaderValue = ""
        }

        return headerEnd + 4
    }

    /// 确定响应 body 模式
    private func determineResponseBodyMode(): Unit {
        for (h in headers) {
            let lower = h.name.toLower()
            if (lower == "transfer-encoding" && h.value.toLower().contains("chunked")) {
                chunked = true
            }
            if (lower == "content-length") {
                try {
                    contentLength = Int64.parse(h.value.trim())
                } catch (_: Exception) {
                    contentLength = -1
                }
            }
            if (lower == "connection" && h.value.toLower() == "close") {
                connectionClose = true
            }
        }

        // 1xx, 204, 304 响应没有 body - 对应 RFC 7230 §3.3
        if (statusCode >= 100 && statusCode < 200) {
            contentLength = 0
            chunked = false
        }
        if (statusCode == 204 || statusCode == 304) {
            contentLength = 0
            chunked = false
        }
    }

    /// 解析 chunked body
    private func parseChunkedBody(): Http1ParseResult {
        while (position < buffer.size) {
            let lineEnd = findCrlf(position)
            if (lineEnd < 0) {
                return Http1ParseResult.more()
            }

            let sizeStr = bufferSliceToString(position, lineEnd).trim()
            let semiIdx = sizeStr.indexOf(";")
            let hexStr = if (semiIdx >= 0) { sizeStr.substring(0, semiIdx).trim() } else { sizeStr }

            chunkSize = hexToInt(hexStr)
            position = lineEnd + 2

            if (chunkSize == 0) {
                if (position + 2 <= buffer.size) {
                    position += 2
                    state = Http1ParseState.Complete
                    return Http1ParseResult.done(position)
                }
                return Http1ParseResult.more()
            }

            if (position + chunkSize + 2 > buffer.size) {
                return Http1ParseResult.more()
            }

            for (i in 0..chunkSize) {
                body.append(buffer[position + i])
            }
            position += chunkSize + 2
        }

        return Http1ParseResult.more()
    }

    // ========================================================================
    // 缓冲区工具 (与请求解析器共享)
    // ========================================================================

    private func findCrlfCrlf(): Int64 {
        if (buffer.size < 4) { return -1 }
        var i = position
        while (i < buffer.size - 3) {
            if (buffer[i] == UInt8(13) && buffer[i + 1] == UInt8(10) &&
                buffer[i + 2] == UInt8(13) && buffer[i + 3] == UInt8(10)) {
                return i
            }
            i += 1
        }
        return -1
    }

    private func findCrlf(from: Int64): Int64 {
        var i = from
        while (i < buffer.size - 1) {
            if (buffer[i] == UInt8(13) && buffer[i + 1] == UInt8(10)) {
                return i
            }
            i += 1
        }
        return -1
    }

    private func bufferSliceToString(start: Int64, end: Int64): String {
        let sb = StringBuilder()
        var i = start
        while (i < end && i < buffer.size) {
            sb.append(Char(Int32(buffer[i])))
            i += 1
        }
        return sb.toString()
    }

    private static func hexToInt(hex: String): Int64 {
        var result: Int64 = 0
        for (c in hex) {
            result = result * 16
            if (c >= '0' && c <= '9') {
                result += Int64(c.value) - 48
            } else if (c >= 'a' && c <= 'f') {
                result += Int64(c.value) - 87
            } else if (c >= 'A' && c <= 'F') {
                result += Int64(c.value) - 55
            }
        }
        return result
    }
}
