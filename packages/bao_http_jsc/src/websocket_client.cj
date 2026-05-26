// 严格翻译自: src/http_jsc/websocket_client.zig
//! JSC bridge for WebSocket client. Keeps http/ free of JSC types.
package bao_http_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// WebSocketClientJSC - WebSocket 客户端 JSC 桥接
// ============================================================================

public enum WebSocketOpcode {
    | Continue
    | Text
    | Binary
    | Close
    | Ping
    | Pong
    | Reserved

    public operator func ==(right: WebSocketOpcode): Bool {
        match (this) {
            case Continue => match (right) { case Continue => true case _ => false }
            case Text => match (right) { case Text => true case _ => false }
            case Binary => match (right) { case Binary => true case _ => false }
            case Close => match (right) { case Close => true case _ => false }
            case Ping => match (right) { case Ping => true case _ => false }
            case Pong => match (right) { case Pong => true case _ => false }
            case Reserved => match (right) { case Reserved => true case _ => false }
        }
    }

    public operator func !=(right: WebSocketOpcode): Bool {
        return !(this == right)
    }
}

public enum WebSocketReceiveState {
    | needHeader
    | needMask
    | needBody
    | extendedPayloadLength16
    | extendedPayloadLength64
    | ping
    | pong
    | close
    | fail

    public operator func ==(right: WebSocketReceiveState): Bool {
        match (this) {
            case needHeader => match (right) { case needHeader => true case _ => false }
            case needMask => match (right) { case needMask => true case _ => false }
            case needBody => match (right) { case needBody => true case _ => false }
            case extendedPayloadLength16 => match (right) { case extendedPayloadLength16 => true case _ => false }
            case extendedPayloadLength64 => match (right) { case extendedPayloadLength64 => true case _ => false }
            case ping => match (right) { case ping => true case _ => false }
            case pong => match (right) { case pong => true case _ => false }
            case close => match (right) { case close => true case _ => false }
            case fail => match (right) { case fail => true case _ => false }
        }
    }

    public operator func !=(right: WebSocketReceiveState): Bool {
        return !(this == right)
    }

    public func needControlFrame(): Bool {
        return this != WebSocketReceiveState.needBody
    }
}

public class ParsedWebSocketHeader {
    public var state: WebSocketReceiveState
    public var opcode: WebSocketOpcode
    public var payloadLength: UInt64
    public var isFragmented: Bool
    public var isFinal: Bool
    public var needCompression: Bool

    public init(state: WebSocketReceiveState, opcode: WebSocketOpcode, payloadLength: UInt64, isFragmented: Bool, isFinal: Bool, needCompression: Bool) {
        this.state = state
        this.opcode = opcode
        this.payloadLength = payloadLength
        this.isFragmented = isFragmented
        this.isFinal = isFinal
        this.needCompression = needCompression
    }
}

public class WebSocketClientState {
    public static let MIN_COMPRESS_SIZE: UInt64 = UInt64(860)
    public static let COMPRESSION_OVERHEAD: UInt64 = UInt64(4)

    public var receiveState: WebSocketReceiveState = WebSocketReceiveState.needHeader
    public var receivingType: WebSocketOpcode = WebSocketOpcode.Reserved
    public var receivingIsFinal: Bool = true
    public var pingReceived: Bool = false
    public var pongReceived: Bool = false
    public var closeReceived: Bool = false
    public var closeFrameBuffering: Bool = false
    public var receiveFrame: UInt64 = UInt64(0)
    public var receiveBodyRemain: UInt64 = UInt64(0)
    public var receivePendingChunkLen: UInt64 = UInt64(0)
    public var headerFragment: ?UInt8 = None
    public var receivingCompressed: Bool = false
    public var messageIsCompressed: Bool = false
    public var hasDeflate: Bool = false

    public init() {}

    public func shouldCompress(dataLen: UInt64, opcode: WebSocketOpcode): Bool {
        if (!hasDeflate) { return false }
        if (opcode != WebSocketOpcode.Text && opcode != WebSocketOpcode.Binary) { return false }
        if (dataLen < WebSocketClientState.MIN_COMPRESS_SIZE) { return false }
        return true
    }

    public func clearData(): Unit {
        pingReceived = false
        pongReceived = false
        closeFrameBuffering = false
        receivePendingChunkLen = UInt64(0)
        receivingCompressed = false
        messageIsCompressed = false
        hasDeflate = false
        headerFragment = None
    }
}

/// WebSocket 客户端 JSC 绑定
public class WebSocketClientJSC {
    /// 创建 WebSocket 客户端。网络连接仍由 upgrade client/原生层负责；这里不伪造成功连接。
    public static func createWebSocket(globalObject: JSGlobalObject, url: String, protocols: Array<String>): JsValue {
        let obj = JsValue.createEmptyObject(globalObject.globalThis, 3)
        obj.put(globalObject.globalThis, "url", JsValue(url))
        obj.put(globalObject.globalThis, "protocolCount", JsValue.jsNumber(Int64(protocols.size)))
        obj.put(globalObject.globalThis, "readyState", JsValue.jsNumber(Int64(0)))
        return obj
    }
}

public func parseWebSocketHeader(bytes: Array<UInt8>): ParsedWebSocketHeader {
    if (bytes.size < 2) {
        return ParsedWebSocketHeader(WebSocketReceiveState.fail, WebSocketOpcode.Reserved, UInt64(0), false, false, false)
    }

    let first = bytes[0]
    let second = bytes[1]
    let finalFrame = (first & UInt8(0x80)) != UInt8(0)
    let compressed = (first & UInt8(0x40)) != UInt8(0)
    let rsv = first & UInt8(0x30)
    let opcode = opcodeFromByte(first & UInt8(0x0f))
    let masked = (second & UInt8(0x80)) != UInt8(0)
    let payload = UInt64(second & UInt8(0x7f))
    let fragmented = opcode == WebSocketOpcode.Continue || !finalFrame

    var needCompression = false
    if (opcode == WebSocketOpcode.Text || opcode == WebSocketOpcode.Binary) {
        needCompression = compressed
    } else if (opcode == WebSocketOpcode.Continue) {
        needCompression = false
    } else if (compressed) {
        return ParsedWebSocketHeader(WebSocketReceiveState.fail, opcode, payload, fragmented, finalFrame, false)
    }

    if (masked && (opcode == WebSocketOpcode.Text || opcode == WebSocketOpcode.Binary)) {
        return ParsedWebSocketHeader(WebSocketReceiveState.needMask, opcode, payload, fragmented, finalFrame, needCompression)
    }

    if (rsv != UInt8(0)) {
        return ParsedWebSocketHeader(WebSocketReceiveState.fail, opcode, payload, fragmented, finalFrame, needCompression)
    }

    let state = match (opcode) {
        case Text => payloadState(payload)
        case Continue => payloadState(payload)
        case Binary => payloadState(payload)
        case Close => WebSocketReceiveState.close
        case Ping => WebSocketReceiveState.ping
        case Pong => WebSocketReceiveState.pong
        case Reserved => WebSocketReceiveState.fail
    }
    return ParsedWebSocketHeader(state, opcode, payload, fragmented, finalFrame, needCompression)
}

private func opcodeFromByte(op: UInt8): WebSocketOpcode {
    match (op) {
        case 0 => return WebSocketOpcode.Continue
        case 1 => return WebSocketOpcode.Text
        case 2 => return WebSocketOpcode.Binary
        case 8 => return WebSocketOpcode.Close
        case 9 => return WebSocketOpcode.Ping
        case 10 => return WebSocketOpcode.Pong
        case _ => return WebSocketOpcode.Reserved
    }
}

private func payloadState(payload: UInt64): WebSocketReceiveState {
    if (payload <= UInt64(125)) { return WebSocketReceiveState.needBody }
    if (payload == UInt64(126)) { return WebSocketReceiveState.extendedPayloadLength16 }
    if (payload == UInt64(127)) { return WebSocketReceiveState.extendedPayloadLength64 }
    return WebSocketReceiveState.fail
}
