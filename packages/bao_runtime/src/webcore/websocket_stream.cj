// WebSocketStream - streaming interface for WebSocket messages
// 严格翻译自: Bun WebSocket streaming (combines server + client WebSocket streams)
// 参考: src/http_jsc/websocket_client/*.rs, src/runtime/server/ServerWebSocket.rs
// 以及 Bun: ReadableStream/WritableStream integration for WebSocket
package bao_runtime.webcore

import bao_jsc.*
import bao_collections.ArrayList
import bao_ptr.*

// ============================================================================
// WebSocketStreamDirection - stream direction
// ============================================================================

/// WebSocket stream direction
public enum WebSocketStreamDirection {
    | Incoming   // Messages from peer
    | Outgoing   // Messages to peer
}

// ============================================================================
// WebSocketMessageType - type of received WebSocket message
// ============================================================================

/// WebSocket message type
public enum WebSocketMessageType {
    | Text(String)          // UTF-8 text message
    | Binary(Array<UInt8>)  // Binary message
    | Close(Int32, String)  // Close frame with code and reason
    | Ping(Array<UInt8>)    // Ping frame
    | Pong(Array<UInt8>)    // Pong frame

    /// Whether this is a text message
    public func isText(): Bool {
        match (this) {
            case Text(_) => true
            case _ => false
        }
    }

    /// Whether this is a binary message
    public func isBinary(): Bool {
        match (this) {
            case Binary(_) => true
            case _ => false
        }
    }

    /// Get as text if text message
    public func asText(): ?String {
        match (this) {
            case Text(s) => Some(s)
            case _ => None
        }
    }

    /// Get as bytes if binary message
    public func asBinary(): ?Array<UInt8> {
        match (this) {
            case Binary(b) => Some(b)
            case _ => None
        }
    }
}

// ============================================================================
// WebSocketReadableStream - readable stream of WebSocket messages
// Corresponds to: Bun WebSocket message reading as ReadableStream
// ============================================================================

/// Readable stream of incoming WebSocket messages
/// Corresponds to: Bun: WebSocket message consumption via ReadableStream
public class WebSocketReadableStream {
    /// Underlying WebSocket
    public var ws: ?AnyWebSocket
    /// Whether the stream has been disturbed (read from)
    public var isDisturbed: Bool
    /// Whether the stream is locked (has an active reader)
    public var locked: Bool
    /// Buffered incoming messages
    public var buffer: ArrayList<WebSocketMessageType>
    /// Maximum buffer size before backpressure
    public var maxBufferSize: Int64
    /// Whether the stream is done (closed)
    public var done: Bool
    /// Error if stream errored
    public var error: ?String

    public init() {
        ws = None
        isDisturbed = false
        locked = false
        buffer = ArrayList<WebSocketMessageType>()
        maxBufferSize = 1024 * 1024 * 16  // 16 MB
        done = false
        error = None
    }

    public init(ws: AnyWebSocket) {
        this.ws = Some(ws)
        isDisturbed = false
        locked = false
        buffer = ArrayList<WebSocketMessageType>()
        maxBufferSize = 1024 * 1024 * 16
        done = false
        error = None
    }

    /// Push a message into the stream buffer
    /// Corresponds to: Bun: WebSocket on_message → stream push
    public func pushMessage(msg: WebSocketMessageType): Unit {
        if (done) {
            return
        }
        buffer.append(msg)
        isDisturbed = true
    }

    /// Read the next message from the stream
    /// Corresponds to: Bun: ReadableStream reader.read()
    public func read(): ?WebSocketMessageType {
        if (done) {
            return None
        }
        if (buffer.size > 0) {
            let msg = buffer[0]
            buffer.removeAt(0)
            return Some(msg)
        }
        return None
    }

    /// Cancel the stream
    /// Corresponds to: Bun: ReadableStream.cancel()
    public func cancel(): Unit {
        done = true
        isDisturbed = true
        buffer.clear()
    }

    /// Close the stream
    public func close(): Unit {
        done = true
    }

    /// Get the stream as a JS ReadableStream value
    /// Corresponds to: Bun: WebSocketReadableStream.toJsValue()
    public func toJsValue(global: JsGlobalObject): JsValue {
        let obj = JsObject()
        obj.set("getReader", JsValue("getReader"))
        obj.set("locked", JsValue(locked))
        obj.set("cancel", JsValue("cancel"))
        return JsValue(obj)
    }
}

// ============================================================================
// WebSocketWritableStream - writable stream for sending WebSocket messages
// Corresponds to: Bun WebSocket message writing as WritableStream
// ============================================================================

/// Writable stream for sending WebSocket messages
/// Corresponds to: Bun: WebSocket message sending via WritableStream
public class WebSocketWritableStream {
    /// Underlying WebSocket
    public var ws: ?AnyWebSocket
    /// Whether the stream is closed
    public var closed: Bool
    /// Whether the stream has an active writer
    public var locked: Bool
    /// Total bytes written
    public var totalBytesWritten: Int64

    public init() {
        ws = None
        closed = false
        locked = false
        totalBytesWritten = 0
    }

    public init(ws: AnyWebSocket) {
        this.ws = Some(ws)
        closed = false
        locked = false
        totalBytesWritten = 0
    }

    /// Write a text message
    /// Corresponds to: Bun: WebSocket.send(text)
    public func writeText(text: String): SendStatus {
        match (ws) {
            case Some(w) =>
                let bytes = Utf8Codec.encode(text)
                let status = w.sendText(text)
                if (let SendStatus.Success <- status) {
                    totalBytesWritten += Int64(bytes.size)
                }
                return status
            case None => return SendStatus.Dropped
        }
    }

    /// Write a binary message
    /// Corresponds to: Bun: WebSocket.send(binary)
    public func writeBinary(data: Array<UInt8>): SendStatus {
        match (ws) {
            case Some(w) =>
                let status = w.sendBinary(data)
                if (let SendStatus.Success <- status) {
                    totalBytesWritten += Int64(data.size)
                }
                return status
            case None => return SendStatus.Dropped
        }
    }

    /// Close the writable stream (sends close frame)
    /// Corresponds to: Bun: WritableStream.close() → WebSocket.close()
    public func close(code: Int32, reason: String): Unit {
        match (ws) {
            case Some(w) =>
                let reasonBytes = Utf8Codec.encode(reason)
                w.end(code, reasonBytes)
            case None => ()
        }
        closed = true
    }

    /// Abort the writable stream
    /// Corresponds to: Bun: WritableStream.abort()
    public func abort(): Unit {
        match (ws) {
            case Some(w) => w.close()
            case None => ()
        }
        closed = true
    }

    /// Get the stream as a JS WritableStream value
    /// Corresponds to: Bun: WebSocketWritableStream.toJsValue()
    public func toJsValue(global: JsGlobalObject): JsValue {
        let obj = JsObject()
        obj.set("getWriter", JsValue("getWriter"))
        obj.set("locked", JsValue(locked))
        obj.set("close", JsValue("close"))
        obj.set("abort", JsValue("abort"))
        return JsValue(obj)
    }
}

// ============================================================================
// WebSocketStreamPair - bidirectional stream pair for WebSocket
// Corresponds to: Bun: WebSocket.stream() / WebSocketStream API
// ============================================================================

/// Bidirectional stream pair for WebSocket
/// Corresponds to: Bun experimental WebSocketStream API
public class WebSocketStreamPair {
    /// Readable stream for incoming messages
    public var readable: WebSocketReadableStream
    /// Writable stream for outgoing messages
    public var writable: WebSocketWritableStream

    public init(ws: AnyWebSocket) {
        readable = WebSocketReadableStream(ws)
        writable = WebSocketWritableStream(ws)
    }

    /// Convert to JS value (WebSocketStream-like object)
    /// Corresponds to: Bun: WebSocketStream { readable, writable }
    public func toJsValue(global: JsGlobalObject): JsValue {
        let obj = JsObject()
        obj.set("readable", readable.toJsValue(global))
        obj.set("writable", writable.toJsValue(global))
        return JsValue(obj)
    }
}

// ============================================================================
// WebSocketEvent - event object for WebSocket events
// Corresponds to: Web API MessageEvent / CloseEvent / ErrorEvent
// ============================================================================

/// WebSocket message event
/// Corresponds to: Web API MessageEvent
public class WebSocketMessageEvent {
    /// Event data
    public var data: JsValue
    /// Event origin
    public var origin: String
    /// Event type
    public var `type`: String

    public init(data: JsValue, origin: String, `type`: String) {
        this.data = data
        this.origin = origin
        this.`type` = `type`
    }
}

/// WebSocket close event
/// Corresponds to: Web API CloseEvent
public class WebSocketCloseEvent {
    /// Close code
    public var code: Int32
    /// Close reason
    public var reason: String
    /// Whether the close was clean
    public var wasClean: Bool
    /// Event type
    public var `type`: String

    public init(code: Int32, reason: String, wasClean: Bool) {
        this.code = code
        this.reason = reason
        this.wasClean = wasClean
        this.`type` = "close"
    }

    /// Convert to JS value
    public func toJsValue(global: JsGlobalObject): JsValue {
        let obj = JsObject()
        obj.set("code", JsValue(Float64(code)))
        obj.set("reason", JsValue(reason))
        obj.set("wasClean", JsValue(wasClean))
        return JsValue(obj)
    }
}

/// WebSocket error event
/// Corresponds to: Web API ErrorEvent
public class WebSocketErrorEvent {
    /// Error message
    public var message: String
    /// Event type
    public var `type`: String

    public init(message: String) {
        this.message = message
        this.`type` = "error"
    }

    /// Convert to JS value
    public func toJsValue(global: JsGlobalObject): JsValue {
        let obj = JsObject()
        obj.set("message", JsValue(message))
        return JsValue(obj)
    }
}

// ============================================================================
// WebSocketReadyState - WebSocket ready state enum
// Corresponds to: Web API WebSocket.readyState
// ============================================================================

/// WebSocket ready state
/// Corresponds to: Web API WebSocket.readyState
public enum WebSocketReadyState {
    | Connecting  // 0
    | Open        // 1
    | Closing     // 2
    | Closed      // 3

    public func toInt(): Int32 {
        match (this) {
            case Connecting => 0
            case Open => 1
            case Closing => 2
            case Closed => 3
        }
    }

    public static func fromInt(v: Int32): WebSocketReadyState {
        match (v) {
            case 0 => Connecting
            case 1 => Open
            case 2 => Closing
            case 3 => Closed
            case _ => Closed
        }
    }
}

// ============================================================================
// Close codes - standard WebSocket close codes
// ============================================================================

/// Standard WebSocket close codes
/// Corresponds to: RFC 6455 Section 7.4
public class WsCloseCode {
    public static let NORMAL: Int32 = 1000
    public static let GOING_AWAY: Int32 = 1001
    public static let PROTOCOL_ERROR: Int32 = 1002
    public static let UNSUPPORTED_DATA: Int32 = 1003
    public static let NO_STATUS_RECEIVED: Int32 = 1005
    public static let ABNORMAL_CLOSURE: Int32 = 1006
    public static let INVALID_FRAME_PAYLOAD: Int32 = 1007
    public static let POLICY_VIOLATION: Int32 = 1008
    public static let MESSAGE_TOO_BIG: Int32 = 1009
    public static let MANDATORY_EXTENSION: Int32 = 1010
    public static let INTERNAL_ERROR: Int32 = 1011
    public static let SERVICE_RESTART: Int32 = 1012
    public static let TRY_AGAIN_LATER: Int32 = 1013
    public static let TLS_HANDSHAKE: Int32 = 1015
}

// ported from: src/uws_sys/WebSocket.rs + src/runtime/server/ServerWebSocket.rs
