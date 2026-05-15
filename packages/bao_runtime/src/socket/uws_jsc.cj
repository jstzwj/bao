// 严格翻译自: src/runtime/socket/uws_jsc.zig
// JSC 桥接 — uws 类型的 JS 绑定
package bao_runtime.socket

import bao_core.*
import bao_collections.*

// ============================================================================
// JSC 桥接
// 对应 Bun: uws_jsc.zig
// 导出 JSC 桥接用于 src/uws/ 类型，保持 uws/ 不包含 JSC 类型
// ============================================================================

/// 将 create_bun_socket_error_t 转为 JS 值
/// 对应 Zig: pub fn createBunSocketErrorToJS
public func createBunSocketErrorToJS(error: CreateBunSocketError, globalObject: JsGlobalObject): JsValue {
    match (error) {
        // us_ssl_ctx_from_options 只为 CA/密码情况设置 *err
        // 错误的 cert/key/DH 返回 NULL 且 .none，详情在 BoringSSL 错误队列上
        case NONE =>
            return BoringSSL.errToJS(globalObject, BoringSSL.errGetError())
        case LOAD_CA_FILE =>
            return globalObject.ERR("BORINGSSL", "Failed to load CA file").toJS()
        case INVALID_CA_FILE =>
            return globalObject.ERR("BORINGSSL", "Invalid CA file").toJS()
        case INVALID_CA =>
            return globalObject.ERR("BORINGSSL", "Invalid CA").toJS()
        case INVALID_CIPHERS =>
            return globalObject.ERR("BORINGSSL", "Invalid ciphers").toJS()
    }
}

/// 将 us_bun_verify_error_t 转为 JS 错误值
/// 对应 Zig: pub fn verifyErrorToJS
public func verifyErrorToJS(error: UsBunVerifyError, globalObject: JsGlobalObject): JsValue {
    let code = if (error.code == None || error.code.size == 0) { "" } else { error.code }
    let reason = if (error.reason == None || error.reason.size == 0) { "" } else { error.reason }

    let fallback = SystemError(
        code: BunString.cloneUTF8(code),
        message: BunString.cloneUTF8(reason)
    )

    return fallback.toErrorInstance(globalObject)
}

/// AnyWebSocket.getTopicsAsJSArray
/// 对应 Zig: pub fn anyWebSocketGetTopicsAsJSArray
/// 获取 WebSocket 订阅的主题列表
extern func uwsWsGetTopicsAsJsArray(ssl: Int32, ws: RawWebSocket, globalObject: JsGlobalObject): JsValue

public func anyWebSocketGetTopicsAsJSArray(ws: AnyWebSocket, globalObject: JsGlobalObject): JsValue {
    match (ws) {
        case SSL =>
            return uwsWsGetTopicsAsJsArray(1, ws.raw(), globalObject)
        case TCP =>
            return uwsWsGetTopicsAsJsArray(0, ws.raw(), globalObject)
    }
}

/// Socket 带缓冲区的 JS 写入
/// 对应 Zig: export fn us_socket_buffered_js_write
/// 从 JSNodeHTTPServerSocket.cpp 调用的 C 导出函数
public func usSocketBufferedJsWrite(
    socket: UsSocket,
    ended: Bool,
    buffer: UsSocketStreamBuffer,
    globalObject: JsGlobalObject,
    data: JsValue,
    encoding: JsValue
): JsValue {
    var streamBuffer = buffer.toStreamBuffer()
    var totalWritten: Int64 = 0
    defer {
        buffer.update(streamBuffer)
        buffer.wrote(totalWritten)
    }

    let nodeBuffer = if (data.isUndefined()) {
        NodeBlobOrStringOrBuffer.stringOrBuffer(NodeStringOrBuffer.EMPTY)
    } else {
        NodeBlobOrStringOrBuffer.fromJSWithEncodingValueAllowRequestResponse(
            globalObject, data, encoding, true
        )
    }

    if (nodeBuffer == None) {
        if (!globalObject.hasException()) {
            return globalObject.throwInvalidArgumentTypeValue("data", "string, buffer, or blob", data)
        }
        return JsValue.zero
    }

    defer nodeBuffer.deinit()
    if (nodeBuffer.isBlob() && nodeBuffer.blob.needsToReadFile()) {
        return globalObject.throw("File blob not supported yet in this function.")
    }

    let dataSlice = nodeBuffer.slice()
    if (streamBuffer.isNotEmpty()) {
        let toFlush = streamBuffer.slice()
        let written = max(0, socket.write(toFlush))
        streamBuffer.wrote(written)
        totalWritten += written
        if (written < toFlush.size) {
            if (dataSlice.size > 0) {
                streamBuffer.write(dataSlice)
            }
            return JsValue.jsFalse()
        }
    }

    if (dataSlice.size > 0) {
        let written = max(0, socket.write(dataSlice))
        totalWritten += written
        if (written < dataSlice.size) {
            streamBuffer.write(dataSlice[written:])
            return JsValue.jsFalse()
        }
    }
    if (ended) {
        socket.shutdown()
    }
    return JsValue.jsTrue()
}

// ============================================================================
// 不透明类型
// ============================================================================

/// AnyWebSocket 联合类型
public enum AnyWebSocket {
    | SSL
    | TCP

    public func raw(): RawWebSocket { ... }
}

/// RawWebSocket 不透明类型
public class RawWebSocket {}

/// UsSocketStreamBuffer 不透明类型
public class UsSocketStreamBuffer {
    public func toStreamBuffer(): StreamBuffer { ... }
    public func update(sb: StreamBuffer): Unit { ... }
    public func wrote(count: Int64): Unit { ... }
}

/// StreamBuffer 不透明类型
public class StreamBuffer {
    public func isNotEmpty(): Bool { ... }
    public func slice(): Array<Byte> { ... }
    public func wrote(count: Int64): Unit { ... }
    public func write(data: Array<Byte>): Unit { ... }
}

/// SystemError 不透明类型
public class SystemError {
    public var code: BunString
    public var message: BunString

    public init(code: BunString, message: BunString) {
        this.code = code
        this.message = message
    }

    public func toErrorInstance(globalObject: JsGlobalObject): JsValue { ... }
}

/// NodeStringOrBuffer 不透明类型
public class NodeStringOrBuffer {
    public static let EMPTY = NodeStringOrBuffer()
}

/// NodeBlobOrStringOrBuffer 不透明类型
public class NodeBlobOrStringOrBuffer {
    public var blob: NodeBlob
    public static func stringOrBuffer(sb: NodeStringOrBuffer): NodeBlobOrStringOrBuffer { ... }
    public static func fromJSWithEncodingValueAllowRequestResponse(
        globalObject: JsGlobalObject, data: JsValue, encoding: JsValue, allowRequestResponse: Bool
    ): ?NodeBlobOrStringOrBuffer { ... }
    public func slice(): Array<Byte> { ... }
    public func deinit(): Unit { ... }
    public func isBlob(): Bool { ... }
}

/// NodeBlob 不透明类型
public class NodeBlob {
    public func needsToReadFile(): Bool { ... }
}

/// BunString 不透明类型
public class BunString {
    public static func static(s: String): BunString { ... }
    public static func cloneUTF8(s: String): BunString { ... }
    public func toJS(globalObject: JsGlobalObject): JsValue { ... }
}
