// 严格翻译自: src/http_jsc/websocket_client/CppWebSocket.zig
//! C++ WebSocket bridge - stub implementation.
package bao_http_jsc.websocket_client

import bao_jsc.*
import bao_core.*

// ============================================================================
// CppWebSocket - C++ WebSocket 桥接 (stub)
// ============================================================================

/// C++ WebSocket 客户端桥接 - stub
public class CppWebSocket {
    public var handle: UIntNative

    public init() {
        handle = 0
    }

    public init(handle: UIntNative) {
        this.handle = handle
    }

    public func didAbruptClose(code: WsErrorCode): Unit {}
    public func didConnect(socket: SocketHandler, sslConfig: ?UIntNative, remainBufSize: UIntNative, deflateParams: ?WebSocketDeflateParams, wsClient: ?UIntNative): Unit {}
    public func didClose(code: WsErrorCode, reason: String): Unit {}
    public func setProtocol(index: Int32): Unit {}
    public func rejectUnauthorized(): Bool { return true }
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
