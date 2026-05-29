// 翻译自 Bun: src/runtime/bake/client/websocket.ts
// HMR WebSocket 包装器，负责首连、缓冲发送、断线重连和二进制消息分发。

package bao_runtime.bake.client

import bao_collections.*

// 浏览器 DOM 类型存根
public class WebSocketData {
    public var byteLength: Int64 = 0
    public init() {}
}

public class WebSocket {
    public static let OPEN: Int64 = 1
    public static let CLOSED: Int64 = 3
    public static let CLOSING: Int64 = 2
    public static let CONNECTING: Int64 = 0
    public var readyState: Int64 = 0
    public var binaryType: String = ""
    public init(url: String) {}
    public func send(data: WebSocketData): Unit {}
    public func close(): Unit {}
}

public class MessageEvent {
    public var data: Any = Object()
    public init() {}
}

public class Event {
    public init() {}
    public func preventDefault(): Unit {}
}

public class WebSocketWrapper {
    /// 重连时会重新赋值。
    public var wrapped: ?WebSocket = None
    private var sendQueue: ArrayList<WebSocketData> = ArrayList<WebSocketData>()
    private var sendQueueLength: Int64 = 0
    private var closed: Bool = false
    private let maxSendQueueLength: Int64 = 1024 * 256

    public func send(data: WebSocketData): Unit {
        if (let Some(ws) <- wrapped) {
            if (ws.readyState == WebSocket.OPEN) { ws.send(data) }
        }
    }

    /// 连接建立后发送；连接尚未建立时缓冲。
    public func sendBuffered(data: WebSocketData): Unit {
        if (let Some(ws) <- wrapped) {
            if (ws.readyState == WebSocket.OPEN) {
                ws.send(data)
            } else if (ws.readyState == WebSocket.CONNECTING && sendQueueLength < maxSendQueueLength) {
                sendQueue.append(data)
                sendQueueLength += data.byteLength
            }
        }
    }

    public func close(): Unit {
        closed = true
        if (let Some(ws) <- wrapped) { ws.close() }
    }

    public func dispose(): Unit { close() }

    public func drainQueue(): Unit {
        let old = sendQueue
        sendQueue = ArrayList<WebSocketData>()
        sendQueueLength = 0
        for (data in old) { send(data) }
    }

    public func clearQueue(): Unit {
        sendQueue = ArrayList<WebSocketData>()
        sendQueueLength = 0
    }

    public func isClosed(): Bool { return closed }
}

var mainWebSocket: ?WebSocketWrapper = None

public func getMainWebSocket(): ?WebSocketWrapper {
    return mainWebSocket
}

public class InitWebSocketOptions {
    public var url: String = "/_bun/hmr"
    public init() {}
}

public func initWebSocket(handlers: HashMap<UInt8, (DataView, WebSocket) -> Unit>, options: InitWebSocketOptions): WebSocketWrapper {
    let wsProxy = WebSocketWrapper()
    if (mainWebSocket.isNone()) { mainWebSocket = Some(wsProxy) }
    // Browser-specific initialization stub
    return wsProxy
}
