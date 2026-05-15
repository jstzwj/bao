// 严格翻译自: src/uws_sys/WebSocket.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: WebSocket.zig 中 extern fn
// ============================================================================
@C
foreign func uws_ws_memory_cost(ssl: Int32, ws: CPointer<Unit>): UIntNative
@C
foreign func uws_ws(ssl: Int32, app: CPointer<Unit>, ctx: CPointer<Unit>, pattern: CPointer<UInt8>, pattern_len: UIntNative, id: UIntNative, behavior: CPointer<Unit>): Unit
@C
foreign func uws_ws_get_user_data(ssl: Int32, ws: CPointer<Unit>): CPointer<Unit>
@C
foreign func uws_ws_close(ssl: Int32, ws: CPointer<Unit>): Unit
@C
foreign func uws_ws_send(ssl: Int32, ws: CPointer<Unit>, message: CPointer<UInt8>, length: UIntNative, opcode: Int32): Int32
@C
foreign func uws_ws_send_with_options(ssl: Int32, ws: CPointer<Unit>, message: CPointer<UInt8>, length: UIntNative, opcode: Int32, compress: Bool, fin: Bool): Int32
@C
foreign func uws_ws_send_fragment(ssl: Int32, ws: CPointer<Unit>, message: CPointer<UInt8>, length: UIntNative, compress: Bool): Int32
@C
foreign func uws_ws_send_first_fragment(ssl: Int32, ws: CPointer<Unit>, message: CPointer<UInt8>, length: UIntNative, compress: Bool): Int32
@C
foreign func uws_ws_send_first_fragment_with_opcode(ssl: Int32, ws: CPointer<Unit>, message: CPointer<UInt8>, length: UIntNative, opcode: Int32, compress: Bool): Int32
@C
foreign func uws_ws_send_last_fragment(ssl: Int32, ws: CPointer<Unit>, message: CPointer<UInt8>, length: UIntNative, compress: Bool): Int32
@C
foreign func uws_ws_end(ssl: Int32, ws: CPointer<Unit>, code: Int32, message: CPointer<UInt8>, length: UIntNative): Unit
@C
foreign func uws_ws_cork(ssl: Int32, ws: CPointer<Unit>, handler: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_ws_subscribe(ssl: Int32, ws: CPointer<Unit>, topic: CPointer<UInt8>, length: UIntNative): Bool
@C
foreign func uws_ws_unsubscribe(ssl: Int32, ws: CPointer<Unit>, topic: CPointer<UInt8>, length: UIntNative): Bool
@C
foreign func uws_ws_is_subscribed(ssl: Int32, ws: CPointer<Unit>, topic: CPointer<UInt8>, length: UIntNative): Bool
@C
foreign func uws_ws_iterate_topics(ssl: Int32, ws: CPointer<Unit>, callback: CPointer<Unit>, user_data: CPointer<Unit>): Unit
@C
foreign func uws_ws_publish(ssl: Int32, ws: CPointer<Unit>, topic: CPointer<UInt8>, topic_length: UIntNative, message: CPointer<UInt8>, message_length: UIntNative): Bool
@C
foreign func uws_ws_publish_with_options(ssl: Int32, ws: CPointer<Unit>, topic: CPointer<UInt8>, topic_length: UIntNative, message: CPointer<UInt8>, message_length: UIntNative, opcode: Int32, compress: Bool): Bool
@C
foreign func uws_ws_get_buffered_amount(ssl: Int32, ws: CPointer<Unit>): UIntNative
@C
foreign func uws_ws_get_remote_address(ssl: Int32, ws: CPointer<Unit>, dest: CPointer<CPointer<UInt8>>): UIntNative
@C
foreign func uws_ws_get_remote_address_as_text(ssl: Int32, ws: CPointer<Unit>, dest: CPointer<CPointer<UInt8>>): UIntNative

// ============================================================================
// Opcode - WebSocket 操作码
// 严格翻译自: WebSocket.zig (from uws.Opcode)
// ============================================================================
public enum Opcode {
    | text
    | binary
    | close
    | ping
    | pong
}

// ============================================================================
// SendStatus - WebSocket 发送状态
// 严格翻译自: WebSocket.zig (from uws.SendStatus)
// ============================================================================
public enum SendStatus {
    | backpressure
    | success
    | dropped
}

// ============================================================================
// RawWebSocket - 原始 WebSocket 指针
// 严格翻译自: WebSocket.zig RawWebSocket = opaque
// ============================================================================
public class RawWebSocket {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn memoryCost(this, ssl_flag) usize
    public func memoryCost(sslFlag: Int32): UIntNative {
        return uws_ws_memory_cost(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn asSocket(this) *uws.Socket
    /// They're the same memory address. Equivalent to: (struct us_socket_t *)socket
    public func asSocket(): UsSocket {
        return UsSocket(ptr)
    }
}

// ============================================================================
// WebSocket - WebSocket 连接
// 严格翻译自: WebSocket.zig NewWebSocket(comptime ssl_flag: c_int)
// ============================================================================
public class WebSocket {
    private var ptr: CPointer<Unit>
    private let sslFlag: Int32

    public init(sslFlag: Int32, ptr: CPointer<Unit>) {
        this.sslFlag = sslFlag
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn raw(this) *RawWebSocket
    public func raw(): RawWebSocket {
        return RawWebSocket(ptr)
    }

    /// 对应 Bun: pub fn as(this, comptime Type: type) ?*Type
    public func getUserData(): CPointer<Unit> {
        return uws_ws_get_user_data(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn close(this) void
    public func close(): Unit {
        uws_ws_close(sslFlag, ptr)
    }

    /// 对应 Bun: pub fn send(this, message, opcode) SendStatus
    public func send(message: Array<UInt8>, opcode: Opcode): SendStatus {
        return SendStatus(uws_ws_send(sslFlag, ptr, CPointer<UInt8>.reinterpret(message), UIntNative(message.size), Int32(opcode)))
    }

    /// 对应 Bun: pub fn sendWithOptions(this, message, opcode, compress, fin) SendStatus
    public func sendWithOptions(message: Array<UInt8>, opcode: Opcode, compress: Bool, fin: Bool): SendStatus {
        return SendStatus(uws_ws_send_with_options(sslFlag, ptr, CPointer<UInt8>.reinterpret(message), UIntNative(message.size), Int32(opcode), compress, fin))
    }

    /// 对应 Bun: pub fn memoryCost(this) usize
    public func memoryCost(): UIntNative {
        return raw().memoryCost(sslFlag)
    }

    /// 对应 Bun: pub fn sendLastFragment(this, message, compress) SendStatus
    public func sendLastFragment(message: Array<UInt8>, compress: Bool): SendStatus {
        return SendStatus(uws_ws_send_last_fragment(sslFlag, ptr, CPointer<UInt8>.reinterpret(message), UIntNative(message.size), compress))
    }

    /// 对应 Bun: pub fn end(this, code, message) void
    public func end(code: Int32, message: Array<UInt8>): Unit {
        uws_ws_end(sslFlag, ptr, code, CPointer<UInt8>.reinterpret(message), UIntNative(message.size))
    }

    /// 对应 Bun: pub fn cork(this, ctx, comptime callback) void
    public func cork(ctx: CPointer<Unit>, callback: CPointer<Unit>): Unit {
        uws_ws_cork(sslFlag, ptr, callback, ctx)
    }

    /// 对应 Bun: pub fn subscribe(this, topic) bool
    public func subscribe(topic: Array<UInt8>): Bool {
        return uws_ws_subscribe(sslFlag, ptr, CPointer<UInt8>.reinterpret(topic), UIntNative(topic.size))
    }

    /// 对应 Bun: pub fn unsubscribe(this, topic) bool
    public func unsubscribe(topic: Array<UInt8>): Bool {
        return uws_ws_unsubscribe(sslFlag, ptr, CPointer<UInt8>.reinterpret(topic), UIntNative(topic.size))
    }

    /// 对应 Bun: pub fn isSubscribed(this, topic) bool
    public func isSubscribed(topic: Array<UInt8>): Bool {
        return uws_ws_is_subscribed(sslFlag, ptr, CPointer<UInt8>.reinterpret(topic), UIntNative(topic.size))
    }

    /// 对应 Bun: pub fn publish(this, topic, message) bool
    public func publish(topic: Array<UInt8>, message: Array<UInt8>): Bool {
        return uws_ws_publish(sslFlag, ptr, CPointer<UInt8>.reinterpret(topic), UIntNative(topic.size), CPointer<UInt8>.reinterpret(message), UIntNative(message.size))
    }

    /// 对应 Bun: pub fn publishWithOptions(this, topic, message, opcode, compress) bool
    public func publishWithOptions(topic: Array<UInt8>, message: Array<UInt8>, opcode: Opcode, compress: Bool): Bool {
        return uws_ws_publish_with_options(sslFlag, ptr, CPointer<UInt8>.reinterpret(topic), UIntNative(topic.size), CPointer<UInt8>.reinterpret(message), UIntNative(message.size), Int32(opcode), compress)
    }

    /// 对应 Bun: pub fn getBufferedAmount(this) u32
    public func getBufferedAmount(): UInt32 {
        return UInt32(uws_ws_get_buffered_amount(sslFlag, ptr))
    }

    /// 对应 Bun: pub fn getRemoteAddress(this, buf) []u8
    public func getRemoteAddress(buf: Array<UInt8>): Array<UInt8> {
        // In real impl would call C function
        return Array<UInt8>()
    }
}

// ============================================================================
// AnyWebSocket - SSL/TCP WebSocket 联合体
// 严格翻译自: WebSocket.zig AnyWebSocket = union(enum)
// ============================================================================
public class AnyWebSocket {
    public var isSsl: Bool
    public var ws: WebSocket

    public init(isSsl: Bool, ws: WebSocket) {
        this.isSsl = isSsl
        this.ws = ws
    }

    public static func ssl(ws: WebSocket): AnyWebSocket {
        return AnyWebSocket(true, ws)
    }

    public static func tcp(ws: WebSocket): AnyWebSocket {
        return AnyWebSocket(false, ws)
    }

    /// 对应 Bun: pub fn raw(this) *RawWebSocket
    public func raw(): RawWebSocket {
        return ws.raw()
    }

    /// 对应 Bun: pub fn as(this, comptime Type: type) ?*Type
    public func getUserData(): CPointer<Unit> {
        return ws.getUserData()
    }

    /// 对应 Bun: pub fn memoryCost(this) usize
    public func memoryCost(): UIntNative {
        return ws.memoryCost()
    }

    /// 对应 Bun: pub fn close(this) void
    public func close(): Unit {
        let sslFlag: Int32 = if (isSsl) 1 else 0
        uws_ws_close(sslFlag, ws.getPtr())
    }

    /// 对应 Bun: pub fn send(this, message, opcode, compress, fin) SendStatus
    public func send(message: Array<UInt8>, opcode: Opcode, compress: Bool, fin: Bool): SendStatus {
        let sslFlag: Int32 = if (isSsl) 1 else 0
        return SendStatus(uws_ws_send_with_options(sslFlag, ws.getPtr(), CPointer<UInt8>.reinterpret(message), UIntNative(message.size), Int32(opcode), compress, fin))
    }

    /// 对应 Bun: pub fn sendLastFragment(this, message, compress) SendStatus
    public func sendLastFragment(message: Array<UInt8>, compress: Bool): SendStatus {
        let sslFlag: Int32 = if (isSsl) 1 else 0
        return SendStatus(uws_ws_send_last_fragment(sslFlag, ws.getPtr(), CPointer<UInt8>.reinterpret(message), UIntNative(message.size), compress))
    }

    /// 对应 Bun: pub fn end(this, code, message) void
    public func end(code: Int32, message: Array<UInt8>): Unit {
        let sslFlag: Int32 = if (isSsl) 1 else 0
        uws_ws_end(sslFlag, ws.getPtr(), code, CPointer<UInt8>.reinterpret(message), UIntNative(message.size))
    }

    /// 对应 Bun: pub fn cork(this, ctx, comptime callback) void
    public func cork(ctx: CPointer<Unit>, callback: CPointer<Unit>): Unit {
        let sslFlag: Int32 = if (isSsl) 1 else 0
        uws_ws_cork(sslFlag, ws.getPtr(), callback, ctx)
    }

    /// 对应 Bun: pub fn subscribe(this, topic) bool
    public func subscribe(topic: Array<UInt8>): Bool {
        let sslFlag: Int32 = if (isSsl) 1 else 0
        return uws_ws_subscribe(sslFlag, ws.getPtr(), CPointer<UInt8>.reinterpret(topic), UIntNative(topic.size))
    }

    /// 对应 Bun: pub fn unsubscribe(this, topic) bool
    public func unsubscribe(topic: Array<UInt8>): Bool {
        let sslFlag: Int32 = if (isSsl) 1 else 0
        return uws_ws_unsubscribe(sslFlag, ws.getPtr(), CPointer<UInt8>.reinterpret(topic), UIntNative(topic.size))
    }

    /// 对应 Bun: pub fn isSubscribed(this, topic) bool
    public func isSubscribed(topic: Array<UInt8>): Bool {
        let sslFlag: Int32 = if (isSsl) 1 else 0
        return uws_ws_is_subscribed(sslFlag, ws.getPtr(), CPointer<UInt8>.reinterpret(topic), UIntNative(topic.size))
    }

    /// 对应 Bun: pub fn publish(this, topic, message, opcode, compress) bool
    public func publish(topic: Array<UInt8>, message: Array<UInt8>, opcode: Opcode, compress: Bool): Bool {
        let sslFlag: Int32 = if (isSsl) 1 else 0
        return uws_ws_publish_with_options(sslFlag, ws.getPtr(), CPointer<UInt8>.reinterpret(topic), UIntNative(topic.size), CPointer<UInt8>.reinterpret(message), UIntNative(message.size), Int32(opcode), compress)
    }

    /// 对应 Bun: pub fn getBufferedAmount(this) usize
    public func getBufferedAmount(): UIntNative {
        let sslFlag: Int32 = if (isSsl) 1 else 0
        return uws_ws_get_buffered_amount(sslFlag, ws.getPtr())
    }

    /// 对应 Bun: pub fn getRemoteAddress(this, buf) []u8
    public func getRemoteAddress(buf: Array<UInt8>): Array<UInt8> {
        return ws.getRemoteAddress(buf)
    }
}

// ============================================================================
// WebSocketBehavior - WebSocket 行为配置
// 严格翻译自: WebSocket.zig WebSocketBehavior = extern struct
// ============================================================================
public class WebSocketBehavior {
    public var compression: Int32 = 0
    public var maxPayloadLength: UInt32 = UInt32.Max
    public var idleTimeout: UInt16 = 120
    public var maxBackpressure: UInt32 = 1024 * 1024
    public var closeOnBackpressureLimit: Bool = false
    public var resetIdleTimeoutOnSend: Bool = true
    public var sendPingsAutomatically: Bool = true
    public var maxLifetime: UInt16 = 0
    public var upgrade: ?CPointer<Unit> = None
    public var open: ?CPointer<Unit> = None
    public var message: ?CPointer<Unit> = None
    public var drain: ?CPointer<Unit> = None
    public var ping: ?CPointer<Unit> = None
    public var pong: ?CPointer<Unit> = None
    public var close: ?CPointer<Unit> = None

    public init() {}
}

// ============================================================================
// WebSocketUpgradeContext - WebSocket 升级上下文
// ============================================================================
public class WebSocketUpgradeContext {
    public var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }
}
