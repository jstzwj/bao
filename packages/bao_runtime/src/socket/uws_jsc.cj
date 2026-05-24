// 严格翻译自: src/runtime/socket/uws_jsc.zig
// JSC 桥接 — uws 类型的 JS 绑定
package bao_runtime.socket

import bao_core.*
import bao_collections.*
import bao_jsc.*

// ============================================================================
// JSC 桥接
// 对应 Bun: uws_jsc.zig
// 导出 JSC 桥接用于 src/uws/ 类型，保持 uws/ 不包含 JSC 类型
// ============================================================================

/// 将 create_bun_socket_error_t 转为 JS 值
/// 对应 Zig: pub fn createBunSocketErrorToJS
public func createBunSocketErrorToJS(error: CreateBunSocketError, globalObject: JsGlobalObject): JsValue {
    // Stub: BoringSSL.errToJS / globalObject.ERR 尚未实现
    // 返回通用错误字符串
    match (error) {
        case NONE =>
            return JsValue("SSL error")
        case LOAD_CA_FILE =>
            return JsValue("BORINGSSL: Failed to load CA file")
        case INVALID_CA_FILE =>
            return JsValue("BORINGSSL: Invalid CA file")
        case INVALID_CA =>
            return JsValue("BORINGSSL: Invalid CA")
        case INVALID_CIPHERS =>
            return JsValue("BORINGSSL: Invalid ciphers")
    }
}

/// 将 us_bun_verify_error_t 转为 JS 错误值
/// 对应 Zig: pub fn verifyErrorToJS
public func verifyErrorToJS(error: UsBunVerifyError, globalObject: JsGlobalObject): JsValue {
    let code = if (error.code.size == 0) { "" } else { error.code }
    let reason = if (error.reason.size == 0) { "" } else { error.reason }

    let fallback = SystemError(code, reason)
    return fallback.toJS(JsObject())
}

/// AnyWebSocket.getTopicsAsJSArray
/// 对应 Zig: pub fn anyWebSocketGetTopicsAsJSArray
/// 获取 WebSocket 订阅的主题列表
public func uwsWsGetTopicsAsJsArray(ssl: Int32, ws: RawWebSocket, globalObject: JsGlobalObject): JsValue {
    return JsValue.jsUndefined()
}

public func anyWebSocketGetTopicsAsJSArray(ws: AnyWebSocket, globalObject: JsGlobalObject): JsValue {
    return JsValue.jsUndefined()
}

/// Socket 带缓冲区的 JS 写入
/// 对应 Zig: export fn us_socket_buffered_js_write
/// Stub: 需要 UsSocket.write/shutdown 等方法的实际 FFI 实现
public func usSocketBufferedJsWrite(
    socket: UsSocket,
    ended: Bool,
    buffer: UsSocketStreamBuffer,
    globalObject: JsGlobalObject,
    data: JsValue,
    encoding: JsValue
): JsValue {
    // Native write/shutdown FFI is not wired yet. Report failure instead of dropping data.
    return JsValue.jsFalse()
}

// ============================================================================
// 不透明类型
// ============================================================================

/// AnyWebSocket 联合类型
public enum AnyWebSocket {
    | SSL
    | TCP
}

/// RawWebSocket 不透明类型
public class RawWebSocket {}

/// UsSocketStreamBuffer 不透明类型
public class UsSocketStreamBuffer {
    public func toStreamBuffer(): StreamBuffer { return StreamBuffer() }
    public func update(sb: StreamBuffer): Unit {}
    public func wrote(count: Int64): Unit {}
}

/// StreamBuffer 不透明类型
public class StreamBuffer {
    public func isNotEmpty(): Bool { return false }
    public func slice(): Array<Byte> { return [] }
    public func wrote(count: Int64): Unit {}
    public func write(data: Array<Byte>): Unit {}
}

/// NodeStringOrBuffer 不透明类型
public class NodeStringOrBuffer {
    public static let EMPTY = NodeStringOrBuffer()
}

/// NodeBlobOrStringOrBuffer 不透明类型
public class NodeBlobOrStringOrBuffer {
    public var blob: NodeBlob

    public init() {
        blob = NodeBlob()
    }

    public static func stringOrBuffer(sb: NodeStringOrBuffer): NodeBlobOrStringOrBuffer {
        NodeBlobOrStringOrBuffer()
    }
    public static func fromJSWithEncodingValueAllowRequestResponse(
        globalObject: JsGlobalObject, data: JsValue, encoding: JsValue, allowRequestResponse: Bool
    ): ?NodeBlobOrStringOrBuffer { None }
    public func slice(): Array<Byte> { [] }
    public func deinit(): Unit {}
    public func isBlob(): Bool { false }
}

/// NodeBlob 不透明类型
public class NodeBlob {
    public func needsToReadFile(): Bool { false }
}
