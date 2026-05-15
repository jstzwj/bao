// 严格翻译自: src/http_jsc/websocket_client/CppWebSocket.zig
//! Wrapper between Cangjie and C++ for WebSocket client functionality.
//! Corresponds to the `WebCore::WebSocket` class (WebSocket.cpp).
package bao_http_jsc.websocket_client

import bao_jsc.*
import bao_core.*

// ============================================================================
// CppWebSocket - C++ WebSocket 桥接
// 严格翻译自: src/http_jsc/websocket_client/CppWebSocket.zig:10-89
//   pub const CppWebSocket = opaque { ... };
// ============================================================================

/// C++ WebSocket 客户端桥接 - 严格对应 Bun CppWebSocket
/// 每个方法确保在 C++ 函数调用前后正确进出事件循环，维护正确的执行上下文。
/// 注意：这专门用于 WebSocket 客户端实现，而不是服务端 WebSocket。
public class CppWebSocket {
    public var handle: UIntNative

    public init() {
        handle = 0
    }

    public init(handle: UIntNative) {
        this.handle = handle
    }

    // ========================================================================
    // 外部 C 函数声明 - 严格对应 Bun extern fn 声明
    // ========================================================================

    @Foreign("c")
    private static func WebSocket__didConnect(
        websocketContext: UIntNative,
        socket: UIntNative,
        bufferedData: ?UIntNative,
        bufferedLen: UIntNative,
        deflateParams: ?UIntNative,
        secure: ?UIntNative
    ): Unit

    @Foreign("c")
    private static func WebSocket__didConnectWithTunnel(
        websocketContext: UIntNative,
        tunnel: UIntNative,
        bufferedData: ?UIntNative,
        bufferedLen: UIntNative,
        deflateParams: ?UIntNative
    ): Unit

    @Foreign("c")
    private static func WebSocket__didAbruptClose(websocketContext: UIntNative, reason: ErrorCode): Unit

    @Foreign("c")
    private static func WebSocket__didClose(websocketContext: UIntNative, code: UInt16, reason: UIntNative): Unit

    @Foreign("c")
    private static func WebSocket__didReceiveText(websocketContext: UIntNative, clone: Bool, text: UIntNative): Unit

    @Foreign("c")
    private static func WebSocket__didReceiveBytes(websocketContext: UIntNative, bytes: UIntNative, byteLen: UIntNative, opcode: UInt8): Unit

    @Foreign("c")
    private static func WebSocket__rejectUnauthorized(websocketContext: UIntNative): Bool

    @Foreign("c")
    private static func WebSocket__incrementPendingActivity(websocketContext: UIntNative): Unit

    @Foreign("c")
    private static func WebSocket__decrementPendingActivity(websocketContext: UIntNative): Unit

    @Foreign("c")
    private static func WebSocket__setProtocol(websocketContext: UIntNative, protocol: UIntNative): Unit

    // ========================================================================
    // 公开方法 - 严格对应每个 CppWebSocket pub fn
    // ========================================================================

    /// 连接已建立 (非隧道) - 严格对应 Bun didConnect
    /// Zig:
    ///   pub fn didConnect(this: *CppWebSocket, socket: *uws.Socket, buffered_data: ?[*]u8,
    ///       buffered_len: usize, deflate_params: ?*const WebSocketDeflate.Params, secure: ?*uws.SslCtx) void {
    ///       const loop = jsc.VirtualMachine.get().eventLoop();
    ///       loop.enter();
    ///       defer loop.exit();
    ///       WebSocket__didConnect(this, socket, buffered_data, buffered_len, deflate_params, secure);
    ///   }
    public func didConnect(
        socket: UIntNative,
        bufferedData: ?UIntNative,
        bufferedLen: UIntNative,
        deflateParams: ?UIntNative,
        secure: ?UIntNative
    ): Unit {
        let loop = VirtualMachine.get().eventLoop()
        loop.enter()
        WebSocket__didConnect(handle, socket, bufferedData, bufferedLen, deflateParams, secure)
        loop.exit()
    }

    /// 连接已建立 (隧道模式) - 严格对应 Bun didConnectWithTunnel
    /// Zig:
    ///   pub fn didConnectWithTunnel(this: *CppWebSocket, tunnel: *anyopaque,
    ///       buffered_data: ?[*]u8, buffered_len: usize, deflate_params: ?*const WebSocketDeflate.Params) void {
    ///       const loop = jsc.VirtualMachine.get().eventLoop();
    ///       loop.enter();
    ///       defer loop.exit();
    ///       WebSocket__didConnectWithTunnel(this, tunnel, buffered_data, buffered_len, deflate_params);
    ///   }
    public func didConnectWithTunnel(
        tunnel: UIntNative,
        bufferedData: ?UIntNative,
        bufferedLen: UIntNative,
        deflateParams: ?UIntNative
    ): Unit {
        let loop = VirtualMachine.get().eventLoop()
        loop.enter()
        WebSocket__didConnectWithTunnel(handle, tunnel, bufferedData, bufferedLen, deflateParams)
        loop.exit()
    }

    /// 异常关闭 - 严格对应 Bun didAbruptClose
    /// Zig:
    ///   pub fn didAbruptClose(this: *CppWebSocket, reason: ErrorCode) void {
    ///       const loop = jsc.VirtualMachine.get().eventLoop();
    ///       loop.enter();
    ///       defer loop.exit();
    ///       WebSocket__didAbruptClose(this, reason);
    ///   }
    public func didAbruptClose(reason: ErrorCode): Unit {
        let loop = VirtualMachine.get().eventLoop()
        loop.enter()
        WebSocket__didAbruptClose(handle, reason)
        loop.exit()
    }

    /// 正常关闭 - 严格对应 Bun didClose
    /// Zig:
    ///   pub fn didClose(this: *CppWebSocket, code: u16, reason: *const bun.String) void {
    ///       const loop = jsc.VirtualMachine.get().eventLoop();
    ///       loop.enter();
    ///       defer loop.exit();
    ///       WebSocket__didClose(this, code, reason);
    ///   }
    public func didClose(code: UInt16, reason: UIntNative): Unit {
        let loop = VirtualMachine.get().eventLoop()
        loop.enter()
        WebSocket__didClose(handle, code, reason)
        loop.exit()
    }

    /// 接收文本消息 - 严格对应 Bun didReceiveText
    /// Zig:
    ///   pub fn didReceiveText(this: *CppWebSocket, clone: bool, text: *const jsc.ZigString) void {
    ///       const loop = jsc.VirtualMachine.get().eventLoop();
    ///       loop.enter();
    ///       defer loop.exit();
    ///       WebSocket__didReceiveText(this, clone, text);
    ///   }
    public func didReceiveText(clone: Bool, text: UIntNative): Unit {
        let loop = VirtualMachine.get().eventLoop()
        loop.enter()
        WebSocket__didReceiveText(handle, clone, text)
        loop.exit()
    }

    /// 接收二进制消息 - 严格对应 Bun didReceiveBytes
    /// Zig:
    ///   pub fn didReceiveBytes(this: *CppWebSocket, bytes: [*]const u8, byte_len: usize, opcode: u8) void {
    ///       const loop = jsc.VirtualMachine.get().eventLoop();
    ///       loop.enter();
    ///       defer loop.exit();
    ///       WebSocket__didReceiveBytes(this, bytes, byte_len, opcode);
    ///   }
    public func didReceiveBytes(bytes: UIntNative, byteLen: UIntNative, opcode: UInt8): Unit {
        let loop = VirtualMachine.get().eventLoop()
        loop.enter()
        WebSocket__didReceiveBytes(handle, bytes, byteLen, opcode)
        loop.exit()
    }

    /// 检查是否拒绝未授权 - 严格对应 Bun rejectUnauthorized
    /// Zig:
    ///   pub fn rejectUnauthorized(this: *CppWebSocket) bool {
    ///       const loop = jsc.VirtualMachine.get().eventLoop();
    ///       loop.enter();
    ///       defer loop.exit();
    ///       return WebSocket__rejectUnauthorized(this);
    ///   }
    public func rejectUnauthorized(): Bool {
        let loop = VirtualMachine.get().eventLoop()
        loop.enter()
        let result = WebSocket__rejectUnauthorized(handle)
        loop.exit()
        return result
    }

    /// 增加挂起活动引用 - 严格对应 Bun ref
    /// Zig:
    ///   pub fn ref(this: *CppWebSocket) void {
    ///       jsc.markBinding(@src());
    ///       WebSocket__incrementPendingActivity(this);
    ///   }
    public func ref(): Unit {
        JSCHelper.markBinding()
        WebSocket__incrementPendingActivity(handle)
    }

    /// 减少挂起活动引用 - 严格对应 Bun unref
    /// Zig:
    ///   pub fn unref(this: *CppWebSocket) void {
    ///       jsc.markBinding(@src());
    ///       WebSocket__decrementPendingActivity(this);
    ///   }
    public func unref(): Unit {
        JSCHelper.markBinding()
        WebSocket__decrementPendingActivity(handle)
    }

    /// 设置协议 - 严格对应 Bun setProtocol
    /// Zig:
    ///   pub fn setProtocol(this: *CppWebSocket, protocol: *bun.String) void {
    ///       jsc.markBinding(@src());
    ///       WebSocket__setProtocol(this, protocol);
    ///   }
    public func setProtocol(protocol: UIntNative): Unit {
        JSCHelper.markBinding()
        WebSocket__setProtocol(handle, protocol)
    }
}

// ============================================================================
// ErrorCode - WebSocket 错误码
// 严格翻译自: src/http_jsc/websocket_client.zig ErrorCode
// ============================================================================

/// WebSocket 错误码 - 严格对应 Bun ErrorCode
public enum ErrorCode {
    ended
    tls_handshake_failed
    failed_to_write
    failed_to_connect
    timeout
    cancel
    expected_101_status_code
    invalid_response
    invalid_websocket_version
    mismatch_client_protocol
    mismatch_websocket_accept_header
    missing_upgrade_header
    missing_connection_header
    missing_websocket_accept_header
    invalid_connection_header
    invalid_upgrade_header
    proxy_connect_failed
    proxy_authentication_required
    proxy_tunnel_failed
}
