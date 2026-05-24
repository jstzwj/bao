// 严格翻译自: src/http_jsc/websocket_client/CppWebSocket.zig
//! C++ WebSocket bridge state model for native client callbacks.
package bao_http_jsc.websocket_client

import bao_jsc.*
import bao_core.*

// ============================================================================
// CppWebSocket - C++ WebSocket 桥接
// ============================================================================

/// C++ WebSocket 客户端桥接。没有 native handle 时只记录失败状态，不伪造连接成功。
public class CppWebSocket {
    public var handle: UIntNative
    public var state: CppWebSocketState
    public var closeCode: ?WsErrorCode
    public var closeReason: String
    public var selectedProtocolIndex: Int32
    public var connectedSocket: ?SocketHandler
    public var bufferedAfterConnect: UIntNative
    public var negotiatedDeflateParams: ?WebSocketDeflateParams
    public var nativeClientHandle: ?UIntNative

    public init() {
        handle = 0
        state = CppWebSocketState.detached
        closeCode = None
        closeReason = ""
        selectedProtocolIndex = -1
        connectedSocket = None
        bufferedAfterConnect = 0
        negotiatedDeflateParams = None
        nativeClientHandle = None
    }

    public init(handle: UIntNative) {
        this.handle = handle
        state = if (handle == 0) { CppWebSocketState.detached } else { CppWebSocketState.connecting }
        closeCode = None
        closeReason = ""
        selectedProtocolIndex = -1
        connectedSocket = None
        bufferedAfterConnect = 0
        negotiatedDeflateParams = None
        nativeClientHandle = None
    }

    public func didAbruptClose(code: WsErrorCode): Unit {
        state = CppWebSocketState.failed
        closeCode = Some(code)
        closeReason = wsErrorCodeMessage(code)
        connectedSocket = None
        nativeClientHandle = None
    }

    public func didConnect(socket: SocketHandler, sslConfig: ?UIntNative, remainBufSize: UIntNative, deflateParams: ?WebSocketDeflateParams, wsClient: ?UIntNative): Unit {
        if (handle == 0) {
            didAbruptClose(WsErrorCode.failed_to_connect)
            return
        }
        if (socket.isClosed() || socket.isShutdown()) {
            didAbruptClose(WsErrorCode.failed_to_connect)
            return
        }

        state = CppWebSocketState.connected
        connectedSocket = Some(socket)
        bufferedAfterConnect = remainBufSize
        negotiatedDeflateParams = deflateParams
        nativeClientHandle = wsClient
        closeCode = None
        closeReason = ""
    }

    public func didClose(code: WsErrorCode, reason: String): Unit {
        state = CppWebSocketState.closed
        closeCode = Some(code)
        closeReason = reason
        connectedSocket = None
        nativeClientHandle = None
    }

    public func setProtocol(index: Int32): Unit {
        selectedProtocolIndex = index
    }

    public func rejectUnauthorized(): Bool {
        return handle != 0 && state != CppWebSocketState.failed && state != CppWebSocketState.closed
    }

    public func isConnected(): Bool {
        state == CppWebSocketState.connected
    }
}

public enum CppWebSocketState {
    | detached
    | connecting
    | connected
    | closed
    | failed
}

public func wsErrorCodeMessage(code: WsErrorCode): String {
    match (code) {
        case ended => return "WebSocket connection ended"
        case tls_handshake_failed => return "TLS handshake failed"
        case failed_to_write => return "Failed to write WebSocket request"
        case failed_to_connect => return "Failed to connect WebSocket"
        case expected_101_status_code => return "Expected HTTP 101 Switching Protocols"
        case timeout => return "WebSocket connection timed out"
        case proxy_connect_failed => return "Proxy CONNECT failed"
        case proxy_authentication_required => return "Proxy authentication required"
        case proxy_tunnel_failed => return "Proxy tunnel failed"
        case mismatch_websocket_accept_header => return "Sec-WebSocket-Accept header mismatch"
        case mismatch_client_protocol => return "WebSocket protocol mismatch"
        case missing_upgrade_header => return "Missing Upgrade header"
        case missing_connection_header => return "Missing Connection header"
        case missing_websocket_accept_header => return "Missing Sec-WebSocket-Accept header"
        case invalid_connection_header => return "Invalid Connection header"
        case invalid_upgrade_header => return "Invalid Upgrade header"
        case invalid_websocket_version => return "Invalid WebSocket version"
        case invalid_response => return "Invalid WebSocket response"
    }
}

/// WebSocket error codes
public enum WsErrorCode {
    | ended
    | tls_handshake_failed
    | failed_to_write
    | failed_to_connect
    | expected_101_status_code
    | timeout
    | proxy_connect_failed
    | proxy_authentication_required
    | proxy_tunnel_failed
    | mismatch_websocket_accept_header
    | mismatch_client_protocol
    | missing_upgrade_header
    | missing_connection_header
    | missing_websocket_accept_header
    | invalid_connection_header
    | invalid_upgrade_header
    | invalid_websocket_version
    | invalid_response
}
