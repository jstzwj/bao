// 翻译自 Bun: src/runtime/bake/client/websocket.ts
// HMR WebSocket 包装器，负责首连、缓冲发送、断线重连和二进制消息分发。

package bao_runtime.bake.client

let isLocal: Bool = location.host == "localhost" || location.host == "127.0.0.1"
var mainWebSocket: ?WebSocketWrapper = None

public class WebSocketWrapper {
    /// 重连时会重新赋值。
    public var wrapped: ?WebSocket = None
    private var sendQueue: Array<WebSocketData> = []
    private var sendQueueLength: Int64 = 0
    private var closed: Bool = false
    private let maxSendQueueLength: Int64 = 1024 * 256

    public func send(data: WebSocketData): Unit {
        if (let Some(ws) = wrapped) {
            if (ws.readyState == WebSocket.OPEN) { ws.send(data) }
        }
    }

    /// 连接建立后发送；连接尚未建立时缓冲。
    public func sendBuffered(data: WebSocketData): Unit {
        if (let Some(ws) = wrapped) {
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
        if (let Some(ws) = wrapped) { ws.close() }
        if (mainWebSocket == Some(this)) { mainWebSocket = None }
    }

    public func dispose(): Unit { close() }

    public func drainQueue(): Unit {
        let old = sendQueue
        sendQueue = []
        sendQueueLength = 0
        for (data in old) { send(data) }
    }

    public func clearQueue(): Unit {
        sendQueue = []
        sendQueueLength = 0
    }

    public func isClosed(): Bool { return closed }
}

public func getMainWebSocket(): ?WebSocketWrapper {
    return mainWebSocket
}

func normalizeWebSocketURL(url: String): String {
    let origin = globalThis.location.origin ?? globalThis.location.href ?? "http://localhost:3000"
    let object = URL(url, origin)
    if (object.protocol == "https:") {
        object.protocol = "wss:"
    } else if (object.protocol == "http:") {
        object.protocol = "ws:"
    }
    return object.toString()
}

public class InitWebSocketOptions {
    public var url: String = "/_bun/hmr"
    public var onStatusChange: ?(Bool) -> Unit = None
}

public func initWebSocket(handlers: Map<UInt8, (DataView, WebSocket) -> Unit>, options: InitWebSocketOptions = InitWebSocketOptions()): WebSocketWrapper {
    let url = normalizeWebSocketURL(options.url)
    let wsProxy = WebSocketWrapper()
    if (mainWebSocket.isNone()) { mainWebSocket = Some(wsProxy) }

    func onFirstOpen(): Unit {
        console.info("[Bun] Hot-module-reloading socket connected, waiting for changes...")
        if (let Some(cb) = options.onStatusChange) { cb(true) }
        wsProxy.drainQueue()
    }

    func onMessage(ev: MessageEvent): Unit {
        if (let Some(data) = ev.data.asArrayBuffer()) {
            let view = DataView(data)
            if (IS_BUN_DEVELOPMENT) {
                console.info("[WS] receive message '" + String.fromCharCode(view.getUint8(0)) + "'")
            }
            if (let Some(handler) = handlers.get(view.getUint8(0))) { handler(view, wsProxy.wrapped.get()) }
        }
    }

    func onError(ev: Event): Unit {
        if (let Some(ws) = wsProxy.wrapped) {
            if (ws.readyState == WebSocket.CLOSED || ws.readyState == WebSocket.CLOSING) { ev.preventDefault() }
        }
    }

    func onClose(): Unit {
        if (let Some(cb) = options.onStatusChange) { cb(false) }
        console.warn("[Bun] Hot-module-reloading socket disconnected, reconnecting...")
        setTimeout({ => reconnect(url, wsProxy, handlers, options, onMessage, onError) }, 1000)
    }

    let ws = WebSocket(url)
    wsProxy.wrapped = Some(ws)
    ws.binaryType = "arraybuffer"
    ws.onopen = { (_) => onFirstOpen() }
    ws.onmessage = onMessage
    ws.onclose = { (_) => onClose() }
    ws.onerror = onError
    return wsProxy
}

func reconnect(url: String, wsProxy: WebSocketWrapper, handlers: Map<UInt8, (DataView, WebSocket) -> Unit>, options: InitWebSocketOptions, onMessage: (MessageEvent) -> Unit, onError: (Event) -> Unit): Unit {
    wsProxy.clearQueue()
    if (wsProxy.isClosed()) { return }
    let ws = WebSocket(url)
    wsProxy.wrapped = Some(ws)
    ws.binaryType = "arraybuffer"
    ws.onopen = { (_) =>
        console.info("[Bun] Reconnected")
        if (let Some(cb) = options.onStatusChange) { cb(true) }
        ws.onerror = onError
    }
    ws.onmessage = onMessage
    ws.onerror = { (ev) =>
        ev.preventDefault()
        setTimeout({ => reconnect(url, wsProxy, handlers, options, onMessage, onError) }, if (isLocal) { 2500 } else { 2500 })
    }
}
