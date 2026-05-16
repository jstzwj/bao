// Web API WebSocket 模块
// 对应 Bun: src/runtime/api/bun/WebSocket.zig (Bun 特有的 WebSocket 客户端)
// 严格翻译自 Web WebSocket API
package bao_runtime.web_api

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*

// ============================================================================
// WebSocketReadyState — WebSocket 就绪状态
// 对应 Web API: WebSocket.readyState
// ============================================================================

/// WebSocket 就绪状态
/// 对应 Web API: WebSocket.CONNECTING / OPEN / CLOSING / CLOSED
public enum WebSocketReadyState {
    | Connecting   // 0 — 连接中
    | Open         // 1 — 已连接
    | Closing      // 2 — 关闭中
    | Closed       // 3 — 已关闭

    public func value(): Int64 {
        match (this) {
            case Connecting => 0
            case Open => 1
            case Closing => 2
            case Closed => 3
        }
    }

    public func toString(): String {
        match (this) {
            case Connecting => "CONNECTING"
            case Open => "OPEN"
            case Closing => "CLOSING"
            case Closed => "CLOSED"
        }
    }
}

// ============================================================================
// WebSocket — WebSocket 客户端
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/WebSocket
// 对应 Bun: src/runtime/api/bun/WebSocket.zig
// ============================================================================

/// WebSocket — WebSocket 客户端
/// 对应 Web API: WebSocket
/// 对应 Bun: src/runtime/api/bun/WebSocket.zig
public class WebSocket extends EventTarget {
    /// WebSocket URL
    public var url: String
    /// 协议列表
    public var protocols: ArrayList<String>
    /// 二进制类型 ("blob" | "arraybuffer")
    public var binaryType: String
    /// 缓冲数据量
    public var bufferedAmount: Int64
    /// 扩展
    public var extensions: String
    /// 协议 (服务器选择的)
    public var protocol: String
    /// 就绪状态
    public var readyState: WebSocketReadyState

    /// 内部 TCP 连接
    private var socket: ?TcpSocket
    /// 是否为 TLS
    private var isTLS: Bool

    /// onopen 回调
    public var onopen: ?(Event) -> Unit
    /// onmessage 回调
    public var onmessage: ?(MessageEvent) -> Unit
    /// onerror 回调
    public var onerror: ?(Event) -> Unit
    /// onclose 回调
    public var onclose: ?(CloseEvent) -> Unit

    public init(url: String) {
        super()
        this.url = url
        protocols = ArrayList<String>()
        binaryType = "blob"
        bufferedAmount = 0
        extensions = ""
        protocol = ""
        readyState = WebSocketReadyState.Connecting
        socket = None
        isTLS = url.startsWith("wss://")
        onopen = None
        onmessage = None
        onerror = None
        onclose = None
    }

    public init(url: String, protocols: ArrayList<String>) {
        super()
        this.url = url
        this.protocols = protocols
        binaryType = "blob"
        bufferedAmount = 0
        extensions = ""
        protocol = ""
        readyState = WebSocketReadyState.Connecting
        socket = None
        isTLS = url.startsWith("wss://")
        onopen = None
        onmessage = None
        onerror = None
        onclose = None
    }

    public init(url: String, protocol: String) {
        super()
        this.url = url
        this.protocols = ArrayList<String>()
        this.protocols.append(protocol)
        binaryType = "blob"
        bufferedAmount = 0
        extensions = ""
        this.protocol = protocol
        readyState = WebSocketReadyState.Connecting
        socket = None
        isTLS = url.startsWith("wss://")
        onopen = None
        onmessage = None
        onerror = None
        onclose = None
    }

    /// 发送文本消息
    /// 对应 Web API: websocket.send(data)
    public func send(data: String): Unit {
        if (readyState != WebSocketReadyState.Open) {
            throw JsError(JsValue(BaoString("WebSocket is not open: readyState ${readyState.value()}")))
        }
        let bytes = Utf8Codec.encode(data)
        sendBytes(bytes)
    }

    /// 发送二进制消息
    /// 对应 Web API: websocket.send(data) where data is ArrayBuffer
    public func send(data: Array<UInt8>): Unit {
        if (readyState != WebSocketReadyState.Open) {
            throw JsError(JsValue(BaoString("WebSocket is not open: readyState ${readyState.value()}")))
        }
        sendBytes(data)
    }

    /// 发送 Blob
    /// 对应 Web API: websocket.send(data) where data is Blob
    public func send(data: Blob): Unit {
        if (readyState != WebSocketReadyState.Open) {
            throw JsError(JsValue(BaoString("WebSocket is not open: readyState ${readyState.value()}")))
        }
        sendBytes(data.arrayBuffer())
    }

    /// 内部发送字节 (WebSocket 帧封装)
    private func sendBytes(data: Array<UInt8>): Unit {
        match (socket) {
            case Some(sock) => {
                // 封装 WebSocket 帧
                let frame = encodeWebSocketFrame(data, true, 0x01) // 0x01 = text frame
                sock.send(frame)
                bufferedAmount += data.size
            }
            case None => {
                throw JsError(JsValue(BaoString("WebSocket connection not established")))
            }
        }
    }

    /// 关闭连接
    /// 对应 Web API: websocket.close(code, reason)
    public func close(): Unit {
        closeInternal(1000, "")
    }

    public func close(code: Int64): Unit {
        closeInternal(code, "")
    }

    public func close(code: Int64, reason: String): Unit {
        closeInternal(code, reason)
    }

    /// 内部关闭实现
    private func closeInternal(code: Int64, reason: String): Unit {
        if (readyState == WebSocketReadyState.Closed || readyState == WebSocketReadyState.Closing) {
            return
        }
        readyState = WebSocketReadyState.Closing

        match (socket) {
            case Some(sock) => {
                // 发送关闭帧
                let reasonBytes = Utf8Codec.encode(reason)
                let closePayload = ArrayList<UInt8>()
                // 关闭代码 (2 字节大端)
                closePayload.append(UInt8((code >> 8) & 0xFF))
                closePayload.append(UInt8(code & 0xFF))
                for (b in reasonBytes) {
                    closePayload.append(b)
                }
                let frame = encodeWebSocketFrame(closePayload.toArray(), true, 0x08) // 0x08 = close frame
                sock.send(frame)
                sock.close()
            }
            case None => ()
        }

        readyState = WebSocketReadyState.Closed

        // 触发 onclose
        let closeEvent = CloseEvent("close", code, reason, code == 1000)
        match (onclose) {
            case Some(cb) => cb(closeEvent)
            case None => ()
        }
    }

    /// 连接到 WebSocket 服务器
    /// 对应 Bun: WebSocket 连接逻辑
    public func connect(): Unit {
        // 解析 URL 获取 host 和 port
        let parsedUrl = BaoUrl(url)
        let host = parsedUrl.hostname
        let defaultPort = if (isTLS) { UInt16(443) } else { UInt16(80) }
        let portStr = parsedUrl.port
        let port = if (portStr.length > 0) {
            UInt16(Int64.parse(portStr))
        } else {
            defaultPort
        }

        // 创建 TCP 连接
        let addr = SocketAddrV4(port, host)
        let socketResult = TcpSocket.create(AddressFamily.Inet)
        let sock = match (socketResult) {
            case Ok(s) => s
            case Err(_) => {
                readyState = WebSocketReadyState.Closed
                let errorEvent = Event("error")
                match (onerror) {
                    case Some(cb) => cb(errorEvent)
                    case None => ()
                }
                return
            }
        }

        let connectResult = sock.connect(SocketAddr.V4(addr))
        match (connectResult) {
            case Err(_) => {
                sock.close()
                readyState = WebSocketReadyState.Closed
                let errorEvent = Event("error")
                match (onerror) {
                    case Some(cb) => cb(errorEvent)
                    case None => ()
                }
                return
            }
            case Ok(_) => ()
        }

        socket = Some(sock)

        // 发送 HTTP 升级请求
        let key = generateWebSocketKey()
        let path = if (parsedUrl.pathname.length > 0) { parsedUrl.pathname } else { "/" }
        let fullPath = path + parsedUrl.search
        let hostHeader = if (port == defaultPort) { host } else { "${host}:${portStr}" }

        var upgradeReq = StringBuilder()
        upgradeReq.append("GET ${fullPath} HTTP/1.1\r\n")
        upgradeReq.append("Host: ${hostHeader}\r\n")
        upgradeReq.append("Upgrade: websocket\r\n")
        upgradeReq.append("Connection: Upgrade\r\n")
        upgradeReq.append("Sec-WebSocket-Key: ${key}\r\n")
        upgradeReq.append("Sec-WebSocket-Version: 13\r\n")

        // 添加协议头
        if (protocols.size > 0) {
            let protoStr = StringBuilder()
            for (i in 0..protocols.size) {
                if (i > 0) { protoStr.append(", ") }
                protoStr.append(protocols[Int64(i)])
            }
            upgradeReq.append("Sec-WebSocket-Protocol: ${protoStr.toString()}\r\n")
        }

        upgradeReq.append("\r\n")

        let reqBytes = Utf8Codec.encode(upgradeReq.toString())
        sock.send(reqBytes)

        // 接收服务器握手响应
        let recvBuf = Array<UInt8>(4096, item: UInt8(0))
        let totalData = ArrayList<UInt8>()
        var handshakeDone = false
        while (!handshakeDone) {
            let recvResult = sock.recv(recvBuf)
            match (recvResult) {
                case Ok(bytesRead) => {
                    if (bytesRead == 0) {
                        handshakeDone = true
                    } else {
                        for (i in 0..bytesRead) {
                            totalData.append(recvBuf[Int64(i)])
                        }
                        // 检查是否收到完整的 HTTP 响应
                        let response = Utf8Codec.decode(totalData.toArray())
                        if (response.contains("\r\n\r\n")) {
                            handshakeDone = true
                        }
                    }
                }
                case Err(_) => handshakeDone = true
            }
        }

        // 解析握手响应
        let responseText = Utf8Codec.decode(totalData.toArray())
        if (responseText.contains("101") && responseText.contains("Switching Protocols")) {
            readyState = WebSocketReadyState.Open

            // 触发 onopen
            let openEvent = Event("open")
            match (onopen) {
                case Some(cb) => cb(openEvent)
                case None => ()
            }
        } else {
            readyState = WebSocketReadyState.Closed
            sock.close()
            socket = None

            let errorEvent = Event("error")
            match (onerror) {
                case Some(cb) => cb(errorEvent)
                case None => ()
            }
        }
    }

    /// 生成 WebSocket Key
    private static func generateWebSocketKey(): String {
        // 16 字节随机数，Base64 编码
        let bytes = Array<UInt8>(16, item: UInt8(0))
        for (i in 0..16) {
            bytes[Int64(i)] = UInt8(bao_sys.SysModule.randomInt64(0, 255) & 0xFF)
        }
        return Base64Codec.encode(bytes)
    }

    /// 编码 WebSocket 帧
    private static func encodeWebSocketFrame(data: Array<UInt8>, isFinal: Bool, opcode: UInt8): Array<UInt8> {
        let frame = ArrayList<UInt8>()
        let finBit: UInt8 = if (isFinal) { 0x80 } else { 0x00 }
        frame.append(finBit | (opcode & 0x0F))

        let len = data.size
        if (len < 126) {
            frame.append(UInt8(len))
        } else if (len < 65536) {
            frame.append(UInt8(126))
            frame.append(UInt8((len >> 8) & 0xFF))
            frame.append(UInt8(len & 0xFF))
        } else {
            frame.append(UInt8(127))
            for (i in 0..8) {
                frame.append(UInt8((len >> (56 - i * 8)) & 0xFF))
            }
        }

        for (b in data) {
            frame.append(b)
        }

        return frame.toArray()
    }

    /// 转为 JsValue
    public func toJsValueWebSocket(): JsValue {
        let base = super.toJsValue()
        match (base.objectData) {
            case Some(obj) => {
                let self = this

                obj.set("url", JsValue(BaoString(self.url)))
                obj.set("readyState", JsValue(Float64(self.readyState.value())))
                obj.set("bufferedAmount", JsValue(Float64(self.bufferedAmount)))
                obj.set("protocol", JsValue(BaoString(self.protocol)))
                obj.set("binaryType", JsValue(BaoString(self.binaryType)))
                obj.set("extensions", JsValue(BaoString(self.extensions)))

                // 常量
                obj.set("CONNECTING", JsValue(Float64(0)))
                obj.set("OPEN", JsValue(Float64(1)))
                obj.set("CLOSING", JsValue(Float64(2)))
                obj.set("CLOSED", JsValue(Float64(3)))

                obj.set("send", JsValue.nativeFunction(JsNativeFunction("send") { args =>
                    if (args.size >= 1) {
                        let arg = args[0]
                        match (arg.valueType) {
                            case JsValueType.String => {
                                let text = Interpreter.jsToString(arg)
                                self.send(text)
                            }
                            case JsValueType.Array => {
                                match (arg.arrayData) {
                                    case Some(arr) => {
                                        let bytes = ArrayList<UInt8>()
                                        for (v in arr) {
                                            bytes.append(UInt8(Int64(Interpreter.jsToNumber(v))))
                                        }
                                        self.send(bytes.toArray())
                                    }
                                    case None => ()
                                }
                            }
                            case _ => {
                                let text = Interpreter.jsToString(arg)
                                self.send(text)
                            }
                        }
                    }
                    return JsValue.UNDEFINED
                }))

                obj.set("close", JsValue.nativeFunction(JsNativeFunction("close") { args =>
                    let code = if (args.size >= 1) { Int64(Interpreter.jsToNumber(args[0])) } else { Int64(1000) }
                    let reason = if (args.size >= 2) { Interpreter.jsToString(args[1]) } else { "" }
                    self.close(code, reason)
                    return JsValue.UNDEFINED
                }))

                obj.set("addEventListener", JsValue.nativeFunction(JsNativeFunction("addEventListener") { args =>
                    if (args.size >= 2) {
                        let type = Interpreter.jsToString(args[0])
                        let fn = args[1]
                        let callback: EventListener = { event =>
                            if (fn.nativeFnData != None) {
                                match (fn.nativeFnData) {
                                    case Some(nf) => {
                                        let eventArgs = ArrayList<JsValue>()
                                        eventArgs.append(event.toJsValue())
                                        nf.fn(eventArgs)
                                    }
                                    case None => ()
                                }
                            }
                        }

                        match (type) {
                            case "open" => self.onopen = Some(callback)
                            case "message" => self.onmessage = Some({ event =>
                                callback(event)
                            })
                            case "error" => self.onerror = Some(callback)
                            case "close" => self.onclose = Some({ event =>
                                callback(event)
                            }
                            case _ => self.addEventListener(type, callback)
                        }
                    }
                    return JsValue.UNDEFINED
                }))

                // onopen / onmessage / onerror / onclose 属性
                obj.set("onopen", JsValue.NULL)
                obj.set("onmessage", JsValue.NULL)
                obj.set("onerror", JsValue.NULL)
                obj.set("onclose", JsValue.NULL)
            }
            case None => ()
        }
        return base
    }
}

// ============================================================================
// WebSocketModule — WebSocket 模块导出
// ============================================================================

/// WebSocket 模块导出 — 将 WebSocket 注册到全局
public class WebSocketModule {
    /// 将 WebSocket 注册到全局环境
    public static func registerGlobals(env: Environment): Unit {
        // WebSocket 构造函数
        env.define("WebSocket", Interpreter.makeNativeFn("WebSocket") { args =>
            if (args.size < 1) {
                throw JsError(JsValue(BaoString("WebSocket requires a URL")))
            }
            let url = Interpreter.jsToString(args[0])

            let ws = if (args.size >= 2) {
                let protocols = ArrayList<String>()
                match (args[1].valueType) {
                    case JsValueType.String => {
                        protocols.append(Interpreter.jsToString(args[1]))
                    }
                    case JsValueType.Array => {
                        match (args[1].arrayData) {
                            case Some(arr) => {
                                for (v in arr) {
                                    protocols.append(Interpreter.jsToString(v))
                                }
                            }
                            case None => ()
                        }
                    }
                    case _ => ()
                }
                WebSocket(url, protocols)
            } else {
                WebSocket(url)
            }

            return ws.toJsValueWebSocket()
        }, false)
    }
}
