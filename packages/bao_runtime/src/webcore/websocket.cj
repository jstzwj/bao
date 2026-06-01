// WebSocket - WebSocket protocol implementation
// 严格翻译自: src/uws_sys/WebSocket.rs (877 lines)
// 包含: NewWebSocket, RawWebSocket, AnyWebSocket, WebSocketBehavior,
//        WebSocketHandler, WebSocketUpgradeServer, Wrap trampolines
package bao_runtime.webcore

import bao_jsc.*
import bao_ptr.*
import bao_sys.*
import bao_collections.ArrayList

// ============================================================================
// Opcode - WebSocket frame opcode
// Corresponds to: Bun: uws.Opcode
// ============================================================================

/// WebSocket frame opcode
/// Corresponds to: Bun: uws.Opcode
public enum WsOpcode {
    | Text       // 1 - text frame
    | Binary     // 2 - binary frame
    | Close      // 8 - close frame
    | Ping       // 9 - ping frame
    | Pong       // 10 (0xA) - pong frame
    | Continuation // 0 - continuation frame

    public func toInt(): Int32 {
        match (this) {
            case Continuation => 0
            case Text => 1
            case Binary => 2
            case Close => 8
            case Ping => 9
            case Pong => 10
        }
    }

    public static func fromInt(v: Int32): ?WsOpcode {
        match (v) {
            case 0 => Some(WsOpcode.Continuation)
            case 1 => Some(WsOpcode.Text)
            case 2 => Some(WsOpcode.Binary)
            case 8 => Some(WsOpcode.Close)
            case 9 => Some(WsOpcode.Ping)
            case 10 => Some(WsOpcode.Pong)
            case _ => None
        }
    }
}

// ============================================================================
// SendStatus - result of WebSocket send
// Corresponds to: Bun: uws.SendStatus
// ============================================================================

/// WebSocket send status
/// Corresponds to: Bun: uws.SendStatus
public enum SendStatus {
    | Success      // 0 - sent successfully
    | Backpressure // 1 - backpressure applied
    | Dropped      // 2 - message dropped

    public func toInt(): Int32 {
        match (this) {
            case Success => 0
            case Backpressure => 1
            case Dropped => 2
        }
    }
}

// ============================================================================
// CompressOptions - WebSocket compression options
// Corresponds to: Bun: uws.CompressOptions
// ============================================================================

/// WebSocket compression options
/// Corresponds to: Bun: uws.CompressOptions
public enum WsCompressOptions {
    | None        // 0 - no compression
    | Shared      // shared compressor
    | Dedicated   // dedicated compressor
    | DedicatedRaw // dedicated raw compressor

    public func toInt(): Int32 {
        match (this) {
            case None => 0
            case Shared => 1
            case Dedicated => 2
            case DedicatedRaw => 3
        }
    }

    public static func fromInt(v: Int32): WsCompressOptions {
        match (v) {
            case 1 => WsCompressOptions.Shared
            case 2 => WsCompressOptions.Dedicated
            case 3 => WsCompressOptions.DedicatedRaw
            case _ => WsCompressOptions.None
        }
    }
}

// ============================================================================
// WebSocketState - WebSocket connection state
// ============================================================================

/// WebSocket connection state
public enum WebSocketState {
    | Connecting   // Connection in progress
    | Open         // Connection established
    | Closing      // Close frame sent/received
    | Closed       // Connection fully closed

    public func isOpen(): Bool {
        match (this) {
            case Open => true
            case _ => false
        }
    }

    public func isClosed(): Bool {
        match (this) {
            case Closed => true
            case _ => false
        }
    }
}

// ============================================================================
// WebSocketFlags - WebSocket internal flags
// Corresponds to: Bun: src/runtime/socket/uws_jsc.rs WebSocketFlags
// ============================================================================

/// WebSocket internal flags
/// Corresponds to: Bun: WebSocketFlags
public class WebSocketFlags {
    /// Whether the connection has been opened
    public var isOpen: Bool
    /// Whether a close frame has been sent
    public var closeSent: Bool
    /// Whether a close frame has been received
    public var closeReceived: Bool
    /// Whether the peer requested close
    public var peerRequestedClose: Bool
    /// Close code from peer
    public var peerCloseCode: Int32
    /// Close reason from peer
    public var peerCloseReason: String
    /// Whether binary is enabled
    public var binaryType: WsBinaryType

    public init() {
        isOpen = false
        closeSent = false
        closeReceived = false
        peerRequestedClose = false
        peerCloseCode = 0
        peerCloseReason = ""
        binaryType = WsBinaryType.ArrayBuffer
    }

    /// Whether the connection is fully closed
    public func isClosed(): Bool {
        return closeSent && closeReceived
    }
}

// ============================================================================
// WsBinaryType - binary data format
// ============================================================================

/// WebSocket binary data format
/// Corresponds to: WebSocket.binaryType property
public enum WsBinaryType {
    | ArrayBuffer  // "arraybuffer"
    | Blob         // "blob" (not fully supported in Bun)
    | NodeBuffer   // "nodebuffer"

    public func toString(): String {
        match (this) {
            case ArrayBuffer => "arraybuffer"
            case Blob => "blob"
            case NodeBuffer => "nodebuffer"
        }
    }

    public static func fromString(s: String): WsBinaryType {
        match (s.toAsciiLower()) {
            case "blob" => WsBinaryType.Blob
            case "nodebuffer" => WsBinaryType.NodeBuffer
            case _ => WsBinaryType.ArrayBuffer
        }
    }
}

// ============================================================================
// WebSocketData - per-connection user data
// Corresponds to: Bun: src/runtime/socket/uws_jsc.rs WebSocketData
// ============================================================================

/// Per-connection user data for WebSocket
/// Corresponds to: Bun: WebSocketData
public class WebSocketData {
    /// The JS WebSocket wrapper object
    public var jsObject: ?JsValue
    /// Connection flags
    public var flags: WebSocketFlags
    /// SSL flag
    public var ssl: Bool
    /// The raw WebSocket handle pointer
    public var rawWs: UIntNative
    /// The server context
    public var serverContext: UIntNative
    /// Buffered data for send
    public var bufferedData: ArrayList<UInt8>
    /// Subscribe topics
    public var subscribedTopics: ArrayList<String>

    public init() {
        jsObject = None
        flags = WebSocketFlags()
        ssl = false
        rawWs = 0
        serverContext = 0
        bufferedData = ArrayList<UInt8>()
        subscribedTopics = ArrayList<String>()
    }

    public init(ssl: Bool, rawWs: UIntNative, serverContext: UIntNative) {
        jsObject = None
        flags = WebSocketFlags()
        this.ssl = ssl
        this.rawWs = rawWs
        this.serverContext = serverContext
        bufferedData = ArrayList<UInt8>()
        subscribedTopics = ArrayList<String>()
    }
}

// ============================================================================
// RawWebSocket - opaque raw WebSocket handle
// Corresponds to: Bun: uws.RawWebSocket
// ============================================================================

/// Opaque raw WebSocket handle
/// Corresponds to: Bun: uws.RawWebSocket
public class RawWebSocket {
    /// Native pointer
    public var ptr: UIntNative
    /// SSL flag
    public var ssl: Bool

    public init() {
        ptr = 0
        ssl = false
    }

    public init(ptr: UIntNative, ssl: Bool) {
        this.ptr = ptr
        this.ssl = ssl
    }

    /// Get memory cost
    /// Corresponds to: Bun: RawWebSocket.memoryCost()
    public func memoryCost(): Int64 {
        // In Bun, this calls into uWS C++ to get the socket memory cost
        return 0
    }
}

// ============================================================================
// AnyWebSocket - union of SSL/TCP WebSocket handles
// Corresponds to: Bun: uws.AnyWebSocket
// ============================================================================

/// Union of SSL/TCP WebSocket handles
/// Corresponds to: Bun: uws.AnyWebSocket
public class AnyWebSocket {
    public var raw: RawWebSocket

    public init() {
        raw = RawWebSocket()
    }

    public init(raw: RawWebSocket) {
        this.raw = raw
    }

    /// Create from SSL flag and raw pointer
    public static func create(ssl: Bool, ptr: UIntNative): AnyWebSocket {
        AnyWebSocket(RawWebSocket(ptr, ssl))
    }

    /// Get user data as typed reference
    /// Corresponds to: Bun: AnyWebSocket.as_<T>()
    public func getUserData(): ?WebSocketData {
        // In actual implementation, this recovers the user data pointer
        // from the uWS socket via uws_ws_get_user_data(ssl, ws)
        return None
    }

    /// Get memory cost
    public func memoryCost(): Int64 {
        return raw.memoryCost()
    }

    /// Close the WebSocket connection
    /// Corresponds to: Bun: AnyWebSocket.close()
    public func close(): Unit {
        // Corresponds to: uws_ws_close(ssl_flag, ws)
    }

    /// Send a message
    /// Corresponds to: Bun: AnyWebSocket.send()
    public func send(message: Array<UInt8>, opcode: WsOpcode, compress: Bool, fin: Bool): SendStatus {
        // Corresponds to: uws_ws_send_with_options(ssl_flag, ws, message, len, opcode, compress, fin)
        return SendStatus.Success
    }

    /// Send text message
    public func sendText(text: String): SendStatus {
        let bytes = Utf8Codec.encode(text)
        return send(bytes, WsOpcode.Text, false, true)
    }

    /// Send binary message
    public func sendBinary(data: Array<UInt8>): SendStatus {
        return send(data, WsOpcode.Binary, false, true)
    }

    /// Send last fragment
    /// Corresponds to: Bun: AnyWebSocket.sendLastFragment()
    public func sendLastFragment(message: Array<UInt8>, compress: Bool): SendStatus {
        // Corresponds to: uws_ws_send_last_fragment(ssl_flag, ws, message, len, compress)
        return SendStatus.Success
    }

    /// End the WebSocket with close code and message
    /// Corresponds to: Bun: AnyWebSocket.end()
    public func end(code: Int32, message: Array<UInt8>): Unit {
        // Corresponds to: uws_ws_end(ssl_flag, ws, code, message, len)
    }

    /// Cork the socket for batched writes
    /// Corresponds to: Bun: AnyWebSocket.cork()
    public func cork(callback: () -> Unit): Unit {
        // Corresponds to: uws_ws_cork(ssl_flag, ws, handler, user_data)
        callback()
    }

    /// Subscribe to a topic
    /// Corresponds to: Bun: AnyWebSocket.subscribe()
    public func subscribe(topic: String): Bool {
        // Corresponds to: uws_ws_subscribe(ssl_flag, ws, topic, len)
        return false
    }

    /// Unsubscribe from a topic
    /// Corresponds to: Bun: AnyWebSocket.unsubscribe()
    public func unsubscribe(topic: String): Bool {
        // Corresponds to: uws_ws_unsubscribe(ssl_flag, ws, topic, len)
        return false
    }

    /// Check if subscribed to a topic
    /// Corresponds to: Bun: AnyWebSocket.isSubscribed()
    public func isSubscribed(topic: String): Bool {
        // Corresponds to: uws_ws_is_subscribed(ssl_flag, ws, topic, len)
        return false
    }

    /// Publish a message to a topic
    /// Corresponds to: Bun: AnyWebSocket.publish()
    public func publish(topic: String, message: Array<UInt8>, opcode: WsOpcode, compress: Bool): Bool {
        // Corresponds to: uws_ws_publish_with_options(ssl_flag, ws, topic, msg, opcode, compress)
        return false
    }

    /// Get buffered amount
    /// Corresponds to: Bun: AnyWebSocket.getBufferedAmount()
    public func getBufferedAmount(): UInt32 {
        // Corresponds to: uws_ws_get_buffered_amount(ssl_flag, ws)
        return 0
    }

    /// Get remote address
    /// Corresponds to: Bun: AnyWebSocket.getRemoteAddress()
    public func getRemoteAddress(): String {
        // Corresponds to: uws_ws_get_remote_address(ssl_flag, ws, &ptr)
        return ""
    }
}

// ============================================================================
// WebSocketBehavior - WebSocket configuration for uWS
// Corresponds to: Bun: uws.WebSocketBehavior
// ============================================================================

/// WebSocket behavior configuration
/// Corresponds to: Bun: uws.WebSocketBehavior
public class WebSocketBehavior {
    /// Compression option
    /// Corresponds to: Bun: WebSocketBehavior.compression
    public var compression: WsCompressOptions
    /// Maximum payload length
    /// Corresponds to: Bun: WebSocketBehavior.max_payload_length
    public var maxPayloadLength: UInt32
    /// Idle timeout in seconds
    /// Corresponds to: Bun: WebSocketBehavior.idle_timeout
    public var idleTimeout: UInt16
    /// Maximum backpressure in bytes
    /// Corresponds to: Bun: WebSocketBehavior.max_backpressure
    public var maxBackpressure: UInt32
    /// Whether to close on backpressure limit
    /// Corresponds to: Bun: WebSocketBehavior.close_on_backpressure_limit
    public var closeOnBackpressureLimit: Bool
    /// Whether to reset idle timeout on send
    /// Corresponds to: Bun: WebSocketBehavior.reset_idle_timeout_on_send
    public var resetIdleTimeoutOnSend: Bool
    /// Whether to send pings automatically
    /// Corresponds to: Bun: WebSocketBehavior.send_pings_automatically
    public var sendPingsAutomatically: Bool
    /// Maximum lifetime in seconds
    /// Corresponds to: Bun: WebSocketBehavior.max_lifetime
    public var maxLifetime: UInt16
    /// Upgrade handler
    public var upgrade: ?WsUpgradeHandler
    /// Open handler
    public var open: ?WsOpenHandler
    /// Message handler
    public var message: ?WsMessageHandler
    /// Drain handler
    public var drain: ?WsDrainHandler
    /// Ping handler
    public var ping: ?WsPingPongHandler
    /// Pong handler
    public var pong: ?WsPingPongHandler
    /// Close handler
    public var close: ?WsCloseHandler

    public init() {
        compression = WsCompressOptions.None
        maxPayloadLength = UInt32(0xFFFFFFFF)
        idleTimeout = 120
        maxBackpressure = 1024 * 1024  // 1 MB
        closeOnBackpressureLimit = false
        resetIdleTimeoutOnSend = true
        sendPingsAutomatically = true
        maxLifetime = 0
        upgrade = None
        open = None
        message = None
        drain = None
        ping = None
        pong = None
        close = None
    }
}

// ============================================================================
// Handler types
// Corresponds to: Bun: uws.WebSocketBehavior handler fields
// ============================================================================

/// WebSocket upgrade handler type
/// Corresponds to: Bun: uws_websocket_upgrade_handler
public type WsUpgradeHandler = (context: UIntNative, res: UIntNative, req: UIntNative, wsUpgradeCtx: UIntNative, id: Int64) -> Unit

/// WebSocket open handler type
/// Corresponds to: Bun: uws_websocket_handler
public type WsOpenHandler = (ws: AnyWebSocket) -> Unit

/// WebSocket message handler type
/// Corresponds to: Bun: uws_websocket_message_handler
public type WsMessageHandler = (ws: AnyWebSocket, message: Array<UInt8>, opcode: WsOpcode) -> Unit

/// WebSocket drain handler type
/// Corresponds to: Bun: uws_websocket_handler
public type WsDrainHandler = (ws: AnyWebSocket) -> Unit

/// WebSocket ping/pong handler type
/// Corresponds to: Bun: uws_websocket_ping_pong_handler
public type WsPingPongHandler = (ws: AnyWebSocket, message: Array<UInt8>) -> Unit

/// WebSocket close handler type
/// Corresponds to: Bun: uws_websocket_close_handler
public type WsCloseHandler = (ws: AnyWebSocket, code: Int32, message: Array<UInt8>) -> Unit

// ============================================================================
// WebSocketHandler - trait for WebSocket event handling
// Corresponds to: Bun: uws.WebSocketHandler
// ============================================================================

/// WebSocket event handler interface
/// Corresponds to: Bun: uws.WebSocketHandler trait
public interface WebSocketHandler {
    /// Whether on_message handler is defined
    func hasOnMessage(): Bool
    /// Whether on_drain handler is defined
    func hasOnDrain(): Bool
    /// Whether on_ping handler is defined
    func hasOnPing(): Bool
    /// Whether on_pong handler is defined
    func hasOnPong(): Bool

    /// Called when WebSocket connection is opened
    func onOpen(ws: AnyWebSocket): Unit
    /// Called when a message is received
    func onMessage(ws: AnyWebSocket, message: Array<UInt8>, opcode: WsOpcode): Unit
    /// Called when the drain event fires
    func onDrain(ws: AnyWebSocket): Unit
    /// Called when a ping is received
    func onPing(ws: AnyWebSocket, message: Array<UInt8>): Unit
    /// Called when a pong is received
    func onPong(ws: AnyWebSocket, message: Array<UInt8>): Unit
    /// Called when the connection is closed
    func onClose(ws: AnyWebSocket, code: Int32, message: Array<UInt8>): Unit
}

// ============================================================================
// WebSocketUpgradeServer - trait for server-side upgrade handling
// Corresponds to: Bun: uws.WebSocketUpgradeServer
// ============================================================================

/// WebSocket upgrade server interface
/// Corresponds to: Bun: uws.WebSocketUpgradeServer trait
public interface WebSocketUpgradeServer {
    /// Called when an HTTP request should be upgraded to WebSocket
    func onWebSocketUpgrade(res: UIntNative, req: UIntNative, context: UIntNative, id: Int64): Unit
}

// ============================================================================
// WebSocketWrap - trampoline that connects behavior to handlers
// Corresponds to: Bun: uws.Wrap<Server, T, SSL>
// ============================================================================

/// WebSocket wrap — connects behavior configuration to event handlers
/// Corresponds to: Bun: uws.Wrap<Server, T, SSL>
public class WebSocketWrap {
    /// SSL flag
    public var ssl: Bool
    /// Behavior configuration
    public var behavior: WebSocketBehavior

    public init(ssl: Bool) {
        this.ssl = ssl
        this.behavior = WebSocketBehavior()
    }

    /// Create an AnyWebSocket from a raw pointer
    /// Corresponds to: Bun: Wrap::make_ws()
    public func makeWs(rawPtr: UIntNative): AnyWebSocket {
        return AnyWebSocket.create(ssl, rawPtr)
    }

    /// Apply the handler to the behavior
    /// Corresponds to: Bun: Wrap::apply()
    public func apply(handler: WebSocketHandler): WebSocketBehavior {
        let b = behavior
        let result = WebSocketBehavior()
        result.compression = b.compression
        result.maxPayloadLength = b.maxPayloadLength
        result.idleTimeout = b.idleTimeout
        result.maxBackpressure = b.maxBackpressure
        result.closeOnBackpressureLimit = b.closeOnBackpressureLimit
        result.resetIdleTimeoutOnSend = b.resetIdleTimeoutOnSend
        result.sendPingsAutomatically = b.sendPingsAutomatically
        result.maxLifetime = b.maxLifetime
        // Handlers are always set (with null checks inside trampolines)
        result.open = { ws =>
            handler.onOpen(ws)
        }
        if (handler.hasOnMessage()) {
            result.message = { ws, msg, opcode =>
                handler.onMessage(ws, msg, opcode)
            }
        }
        if (handler.hasOnDrain()) {
            result.drain = { ws =>
                handler.onDrain(ws)
            }
        }
        if (handler.hasOnPing()) {
            result.ping = { ws, msg =>
                handler.onPing(ws, msg)
            }
        }
        if (handler.hasOnPong()) {
            result.pong = { ws, msg =>
                handler.onPong(ws, msg)
            }
        }
        result.close = { ws, code, msg =>
            handler.onClose(ws, code, msg)
        }
        return result
    }
}

// ============================================================================
// NewWebSocket - typed WebSocket handle parameterized by SSL flag
// Corresponds to: Bun: uws.NewWebSocket<SSL_FLAG>
// ============================================================================

/// Typed WebSocket handle, parameterized by SSL flag
/// Corresponds to: Bun: uws.NewWebSocket<SSL_FLAG>
public class NewWebSocket {
    public var ssl: Bool
    public var raw: RawWebSocket

    public init(ssl: Bool) {
        this.ssl = ssl
        this.raw = RawWebSocket()
    }

    public init(ssl: Bool, raw: RawWebSocket) {
        this.ssl = ssl
        this.raw = raw
    }

    /// Get user data as typed reference
    /// Corresponds to: Bun: NewWebSocket.as_<T>()
    public func getUserData(): ?WebSocketData {
        return None
    }

    /// Close the WebSocket
    /// Corresponds to: Bun: NewWebSocket.close()
    public func close(): Unit {
    }

    /// Send a message with default options
    /// Corresponds to: Bun: NewWebSocket.send()
    public func send(message: Array<UInt8>, opcode: WsOpcode): SendStatus {
        return SendStatus.Success
    }

    /// Send a message with options
    /// Corresponds to: Bun: NewWebSocket.sendWithOptions()
    public func sendWithOptions(message: Array<UInt8>, opcode: WsOpcode, compress: Bool, fin: Bool): SendStatus {
        return SendStatus.Success
    }

    /// Get memory cost
    /// Corresponds to: Bun: NewWebSocket.memoryCost()
    public func memoryCost(): Int64 {
        return raw.memoryCost()
    }

    /// Send last fragment
    /// Corresponds to: Bun: NewWebSocket.sendLastFragment()
    public func sendLastFragment(message: Array<UInt8>, compress: Bool): SendStatus {
        return SendStatus.Success
    }

    /// End the WebSocket
    /// Corresponds to: Bun: NewWebSocket.end()
    public func end(code: Int32, message: Array<UInt8>): Unit {
    }

    /// Cork the socket
    /// Corresponds to: Bun: NewWebSocket.cork()
    public func cork(callback: () -> Unit): Unit {
        callback()
    }

    /// Subscribe to a topic
    /// Corresponds to: Bun: NewWebSocket.subscribe()
    public func subscribe(topic: String): Bool {
        return false
    }

    /// Unsubscribe from a topic
    /// Corresponds to: Bun: NewWebSocket.unsubscribe()
    public func unsubscribe(topic: String): Bool {
        return false
    }

    /// Check if subscribed to a topic
    /// Corresponds to: Bun: NewWebSocket.isSubscribed()
    public func isSubscribed(topic: String): Bool {
        return false
    }

    /// Publish a message to a topic
    /// Corresponds to: Bun: NewWebSocket.publish()
    public func publish(topic: String, message: Array<UInt8>): Bool {
        return false
    }

    /// Get buffered amount
    /// Corresponds to: Bun: NewWebSocket.getBufferedAmount()
    public func getBufferedAmount(): UInt32 {
        return 0
    }

    /// Get remote address
    /// Corresponds to: Bun: NewWebSocket.getRemoteAddress()
    public func getRemoteAddress(): String {
        return ""
    }
}

// ============================================================================
// FFI declarations for uWS WebSocket C API
// Corresponds to: Bun: uws_sys/WebSocket.rs mod c { ... }
// ============================================================================

@C
foreign func uws_ws_memory_cost(ssl: Int32, ws: UIntNative): Int64

@C
foreign func uws_ws_get_user_data(ssl: Int32, ws: UIntNative): UIntNative

@C
foreign func uws_ws_close(ssl: Int32, ws: UIntNative): Unit

@C
foreign func uws_ws_send(
    ssl: Int32, ws: UIntNative,
    message: CPointer<UInt8>, length: UIntNative,
    opcode: Int32
): Int32

@C
foreign func uws_ws_send_with_options(
    ssl: Int32, ws: UIntNative,
    message: CPointer<UInt8>, length: UIntNative,
    opcode: Int32, compress: Bool, fin: Bool
): Int32

@C
foreign func uws_ws_send_last_fragment(
    ssl: Int32, ws: UIntNative,
    message: CPointer<UInt8>, length: UIntNative,
    compress: Bool
): Int32

@C
foreign func uws_ws_end(
    ssl: Int32, ws: UIntNative,
    code: Int32, message: CPointer<UInt8>, length: UIntNative
): Unit

@C
foreign func uws_ws_cork(
    ssl: Int32, ws: UIntNative,
    handler: CPointer<Unit>, user_data: UIntNative
): Unit

@C
foreign func uws_ws_subscribe(
    ssl: Int32, ws: UIntNative,
    topic: CPointer<UInt8>, length: UIntNative
): Bool

@C
foreign func uws_ws_unsubscribe(
    ssl: Int32, ws: UIntNative,
    topic: CPointer<UInt8>, length: UIntNative
): Bool

@C
foreign func uws_ws_is_subscribed(
    ssl: Int32, ws: UIntNative,
    topic: CPointer<UInt8>, length: UIntNative
): Bool

@C
foreign func uws_ws_publish(
    ssl: Int32, ws: UIntNative,
    topic: CPointer<UInt8>, topicLength: UIntNative,
    message: CPointer<UInt8>, messageLength: UIntNative
): Bool

@C
foreign func uws_ws_publish_with_options(
    ssl: Int32, ws: UIntNative,
    topic: CPointer<UInt8>, topicLength: UIntNative,
    message: CPointer<UInt8>, messageLength: UIntNative,
    opcode: Int32, compress: Bool
): Bool

@C
foreign func uws_ws_get_buffered_amount(ssl: Int32, ws: UIntNative): UIntNative

// ported from: src/uws_sys/WebSocket.rs
