// NodeHTTPResponse - Node.js 兼容的 HTTP 响应
// 严格翻译自: Bun src/runtime/server/NodeHTTPResponse.rs
// 对应: node:http 模块的 ServerResponse 实现
// 这是 Bun/Bao HTTP 服务器中最核心的 Node.js 兼容响应类型，
// 管理响应头写入、数据发送、WebSocket 升级、请求体读取等完整生命周期。

package bao_runtime.server

import bao_core.*
import bao_collections.*

// ============================================================================
// NodeHTTPResponseFlags - 响应标志位
// 严格翻译自: NodeHTTPResponse.rs bitflags Flags
// 对应 Bun: bitflags! { pub struct Flags: u8 { ... } }
// ============================================================================

/// NodeHTTPResponse 标志位
/// 对应 Bun: bitflags Flags (packed u8)
public class NodeHTTPResponseFlags {
    /// Socket 已关闭 - 对应 Bun: SOCKET_CLOSED = 1 << 0
    public var socketClosed: Bool
    /// 请求已完成 - 对应 Bun: REQUEST_HAS_COMPLETED = 1 << 1
    public var requestHasCompleted: Bool
    /// 已结束 - 对应 Bun: ENDED = 1 << 2
    public var ended: Bool
    /// 已升级 - 对应 Bun: UPGRADED = 1 << 3
    public var upgraded: Bool
    /// 有自定义 onData - 对应 Bun: HAS_CUSTOM_ON_DATA = 1 << 4
    public var hasCustomOnData: Bool
    /// 请求是否待处理 - 对应 Bun: IS_REQUEST_PENDING = 1 << 5
    public var isRequestPending: Bool
    /// 暂停期间是否缓冲了数据 - 对应 Bun: IS_DATA_BUFFERED_DURING_PAUSE = 1 << 6
    public var isDataBufferedDuringPause: Bool
    /// 暂停期间是否收到最后一块数据 - 对应 Bun: IS_DATA_BUFFERED_DURING_PAUSE_LAST = 1 << 7
    public var isDataBufferedDuringPauseLast: Bool

    public init() {
        socketClosed = false
        requestHasCompleted = false
        ended = false
        upgraded = false
        hasCustomOnData = false
        isRequestPending = true
        isDataBufferedDuringPause = false
        isDataBufferedDuringPauseLast = false
    }

    /// 请求是否已完成或结束
    /// 对应 Bun: pub fn is_requested_completed_or_ended(&self) -> bool
    public func isRequestedCompletedOrEnded(): Bool {
        requestHasCompleted || ended
    }

    /// 是否完成
    /// 对应 Bun: pub fn is_done(&self) -> bool
    public func isDone(): Bool {
        isRequestedCompletedOrEnded() || socketClosed
    }
}

// ============================================================================
// BodyReadState - 请求体读取状态
// 严格翻译自: NodeHTTPResponse.rs BodyReadState
// 对应 Bun: #[repr(u8)] pub enum BodyReadState
// ============================================================================

/// Body 读取状态
public enum BodyReadState {
    | None      // 未开始
    | Pending   // 正在读取
    | Done      // 已完成

    /// 默认值
    public static func `default`(): BodyReadState {
        BodyReadState.None
    }
}

// ============================================================================
// AbortEvent - 中止事件类型
// 严格翻译自: NodeHTTPResponse.rs AbortEvent
// 对应 Bun: #[repr(u8)] pub enum AbortEvent
// ============================================================================

/// 中止事件类型
public enum AbortEvent {
    | None      // 无事件
    | Abort     // 连接中止
    | Timeout   // 超时
}

// ============================================================================
// NodeUpgradeContext - WebSocket 升级上下文
// 严格翻译自: NodeHTTPResponse.rs UpgradeCTX
// 对应 Bun: pub struct UpgradeCTX
// ============================================================================

/// 升级上下文
/// 在异步升级期间保持 WebSocket 头部信息
public class NodeUpgradeContext {
    /// WebSocket 升级上下文
    public var context: ?WebSocketUpgradeContext
    /// 原始请求引用 (异步升级时会被分离)
    public var request: ?RawRequestRef
    /// WebSocket 头部 (异步升级时保存)
    public var secWebSocketKey: String
    public var secWebSocketProtocol: String
    public var secWebSocketExtensions: String

    public init() {
        context = None
        request = None
        secWebSocketKey = ""
        secWebSocketProtocol = ""
        secWebSocketExtensions = ""
    }

    /// 重置 (可多次调用)
    /// 对应 Bun: pub fn reset(&mut self)
    public func reset(): Unit {
        context = None
        request = None
        secWebSocketKey = ""
        secWebSocketProtocol = ""
        secWebSocketExtensions = ""
    }

    /// 保留 WebSocket 头部 (用于异步升级)
    /// 对应 Bun: pub fn preserve_web_socket_headers_if_needed(&mut self)
    public func preserveWebSocketHeadersIfNeeded(): Unit {
        match (request) {
            case Some(req) =>
                request = None
                secWebSocketKey = req.header("sec-websocket-key") ?? ""
                secWebSocketProtocol = req.header("sec-websocket-protocol") ?? ""
                secWebSocketExtensions = req.header("sec-websocket-extensions") ?? ""
            case None => ()
        }
    }
}

// ============================================================================
// NodeHTTPResponse - Node.js 兼容 HTTP 响应
// 严格翻译自: src/runtime/server/NodeHTTPResponse.rs
// 对应 Bun: pub struct NodeHTTPResponse
// R-2: 每个 JS 暴露的方法接受 &self; 每字段的内部可变性
// 通过 Cell(Copy) / JsCell(非Copy) 实现
// ============================================================================

/// Node.js HTTP 响应
/// 严格翻译自: src/runtime/server/NodeHTTPResponse.rs
/// 对应 Bun: pub struct NodeHTTPResponse
/// 提供 Node.js 的 http.ServerResponse 兼容接口
/// 包含响应头写入、数据发送、WebSocket 升级、请求体读取等完整功能
public class NodeHTTPResponse {
    // ========================================================================
    // 字段
    // ========================================================================

    /// 引用计数 - 对应 Bun: ref_count: Cell<u32>
    public var refCount: Int64

    /// 原始响应 - 对应 Bun: raw_response: Cell<Option<uws::AnyResponse>>
    public var rawResponse: ?ResponseRef

    /// 标志 - 对应 Bun: flags: Cell<Flags>
    public var flags: NodeHTTPResponseFlags

    /// 轮询引用 - 对应 Bun: poll_ref: JsCell<jsc::Ref>
    public var pollRef: PollRef

    /// Body 读取状态 - 对应 Bun: body_read_state: Cell<BodyReadState>
    public var bodyReadState: BodyReadState

    /// Body 读取引用 - 对应 Bun: body_read_ref: JsCell<jsc::Ref>
    public var bodyReadRef: PollRef

    /// Promise - 对应 Bun: promise: JsCell<StrongOptional>
    public var promise: ?PromiseRef

    /// 服务器引用 - 对应 Bun: server: AnyServer
    public var server: ?ServerRef

    /// 暂停期间缓冲的请求体数据
    /// 对应 Bun: buffered_request_body_data_during_pause: JsCell<Vec<u8>>
    public var bufferedRequestBodyDataDuringPause: Array<UInt8>

    /// 已写入字节数 - 对应 Bun: bytes_written: Cell<usize>
    public var bytesWritten: Int64

    /// 升级上下文 - 对应 Bun: upgrade_context: JsCell<UpgradeCTX>
    public var upgradeContext: NodeUpgradeContext

    /// 自动刷写器 - 对应 Bun: auto_flusher: JsCell<AutoFlusher>
    public var autoFlusher: AutoFlusher

    public init() {
        refCount = 1
        rawResponse = None
        flags = NodeHTTPResponseFlags()
        pollRef = PollRef()
        bodyReadState = BodyReadState.None
        bodyReadRef = PollRef()
        promise = None
        server = None
        bufferedRequestBodyDataDuringPause = Array<UInt8>()
        bytesWritten = 0
        upgradeContext = NodeUpgradeContext()
        autoFlusher = AutoFlusher()
    }

    // ========================================================================
    // 引用计数
    // ========================================================================

    /// 增加引用
    /// 对应 Bun: pub fn ref_(&self)
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    /// 对应 Bun: pub fn deref(&self)
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// 析构
    /// 对应 Bun: fn deinit
    public func deinit(): Unit {
        rawResponse = None
        promise = None
        bufferedRequestBodyDataDuringPause = Array<UInt8>()
        upgradeContext.reset()
    }

    // ========================================================================
    // 状态检查
    // ========================================================================

    /// 是否完成
    /// 对应 Bun: fn is_done(&self) -> bool
    public func isDone(): Bool {
        flags.isDone()
    }

    /// 请求是否已完成或结束
    /// 对应 Bun: fn is_requested_completed_or_ended(&self) -> bool
    public func isRequestedCompletedOrEnded(): Bool {
        flags.isRequestedCompletedOrEnded()
    }

    /// 请求是否应该保持 pending
    /// 对应 Bun: pub fn should_request_be_pending(&self) -> bool
    public func shouldRequestBePending(): Bool {
        if (flags.socketClosed) {
            return false
        }
        if (flags.ended) {
            return bodyReadState == BodyReadState.Pending
        }
        return true
    }

    // ========================================================================
    // JS 值获取
    // ========================================================================

    /// 获取 this 值
    /// 对应 Bun: pub fn get_this_value(&self) -> JSValue
    public func getThisValue(): JSValue {
        if (flags.socketClosed || flags.upgraded) {
            return JSValue.zero
        }
        match (rawResponse) {
            case Some(r) =>
                return r.getNodeHTTPResponseThisValue()
            case None =>
                return JSValue.zero
        }
    }

    /// 获取服务器 socket 值
    /// 对应 Bun: pub fn get_server_socket_value(&self) -> JSValue
    public func getServerSocketValue(): JSValue {
        if (flags.socketClosed || flags.upgraded) {
            return JSValue.zero
        }
        match (rawResponse) {
            case Some(r) =>
                return r.getNodeHTTPServerSocketThisValue()
            case None =>
                return JSValue.zero
        }
    }

    // ========================================================================
    // Socket 暂停/恢复
    // ========================================================================

    /// 暂停 socket
    /// 对应 Bun: pub fn pause_socket(&self)
    public func pauseSocket(): Unit {
        if (flags.socketClosed || flags.upgraded) {
            return
        }
        match (rawResponse) {
            case Some(r) =>
                if (!r.isConnectRequest()) {
                    r.pause()
                }
            case None => ()
        }
    }

    /// 恢复 socket
    /// 对应 Bun: pub fn resume_socket(&self)
    public func resumeSocket(): Unit {
        if (flags.socketClosed || flags.upgraded) {
            return
        }
        match (rawResponse) {
            case Some(r) =>
                if (!r.isConnectRequest()) {
                    r.resume()
                }
            case None => ()
        }
    }

    // ========================================================================
    // WebSocket 升级
    // ========================================================================

    /// 升级到 WebSocket
    /// 对应 Bun: pub fn upgrade(&self, data_value, sec_websocket_protocol, sec_websocket_extensions) -> bool
    public func upgrade(dataValue: JSValue, secWebsocketProtocol: String,
                         secWebsocketExtensions: String): Bool {
        match (upgradeContext.context) {
            case None => return false
            case Some(_) => {}
        }

        match (server) {
            case Some(srv) =>
                match (srv.getWebSocketHandler()) {
                    case None => return false
                    case Some(handler) => {}
                }
            case None => return false
        }

        let socketValue = getServerSocketValue()
        if (socketValue.isEmpty()) {
            return false
        }

        resumeSocket()

        // 创建 ServerWebSocket
        let ws = ServerWebSocket.init(handler!, dataValue, None)

        // 获取 WebSocket 头部
        var secWebsocketProtocolValue: String = secWebsocketProtocol
        var secWebsocketExtensionsValue: String = secWebsocketExtensions

        if (secWebsocketProtocolValue.size == 0) {
            match (upgradeContext.request) {
                case Some(req) =>
                    secWebsocketProtocolValue = req.header("sec-websocket-protocol") ?? ""
                case None =>
                    secWebsocketProtocolValue = upgradeContext.secWebSocketProtocol
            }
        }

        if (secWebsocketExtensionsValue.size == 0) {
            match (upgradeContext.request) {
                case Some(req) =>
                    secWebsocketExtensionsValue = req.header("sec-websocket-extensions") ?? ""
                case None =>
                    secWebsocketExtensionsValue = upgradeContext.secWebSocketExtensions
            }
        }

        var websocketKey: String = ""
        match (upgradeContext.request) {
            case Some(req) =>
                websocketKey = req.header("sec-websocket-key") ?? ""
            case None =>
                websocketKey = upgradeContext.secWebSocketKey
        }

        // 执行升级
        match (rawResponse) {
            case Some(r) =>
                flags.upgraded = true
                pollRef.unref()
                r.upgrade(ws, websocketKey, secWebsocketProtocolValue,
                           secWebsocketExtensionsValue, upgradeContext.context)
            case None => {}
        }

        // 清理升级上下文
        setOnAbortedHandler()
        upgradeContext.reset()

        return true
    }

    // ========================================================================
    // 请求体管理
    // ========================================================================

    /// 可能停止读取请求体
    /// 对应 Bun: pub fn maybe_stop_reading_body(&self, vm, this_value)
    public func maybeStopReadingBody(vm: VirtualMachine, thisValue: JSValue): Unit {
        upgradeContext.reset()

        if ((flags.upgraded || flags.socketClosed || flags.ended)
            && (bodyReadRef.has || bodyReadState == BodyReadState.Pending)
            && (!flags.hasCustomOnData)) {

            let hadRef = bodyReadRef.has
            if (!flags.upgraded && !flags.socketClosed) {
                match (rawResponse) {
                    case Some(r) => r.clearOnData()
                    case None => {}
                }
            }

            bodyReadRef.unref(vm)
            bodyReadState = BodyReadState.Done

            if (hadRef) {
                markRequestAsDoneIfNecessary()
            }
        }
    }

    /// 转储请求体
    /// 对应 Bun: pub fn dump_request_body(&self, global_object, callframe, this_value) -> JsResult<JSValue>
    public func dumpRequestBody(globalObject: JSGlobalObject, thisValue: JSValue): JSValue {
        if (bufferedRequestBodyDataDuringPause.size > 0) {
            bufferedRequestBodyDataDuringPause = Array<UInt8>()
        }
        if (!flags.requestHasCompleted) {
            clearOnDataCallback(thisValue, globalObject)
        }
        return JSValue.undefined
    }

    // ========================================================================
    // 标记完成
    // ========================================================================

    /// 标记请求完成
    /// 对应 Bun: fn mark_request_as_done(&self)
    public func markRequestAsDone(): Unit {
        flags.isRequestPending = false

        let vm = VirtualMachine.get()
        clearOnDataCallback(getThisValue(), vm.global)
        upgradeContext.reset()

        bufferedRequestBodyDataDuringPause = Array<UInt8>()
        pollRef.unref()
        unregisterAutoFlush()

        match (server) {
            case Some(srv) => srv.onRequestComplete()
            case None => {}
        }

        deref()
    }

    /// 如果需要则标记请求完成
    /// 对应 Bun: fn mark_request_as_done_if_necessary(&self)
    public func markRequestAsDoneIfNecessary(): Unit {
        if (flags.isRequestPending && !shouldRequestBePending()) {
            markRequestAsDone()
        }
    }

    // ========================================================================
    // 中止/超时处理
    // ========================================================================

    /// 设置中止处理器
    /// 对应 Bun: pub fn set_on_aborted_handler(&self)
    public func setOnAbortedHandler(): Unit {
        if (flags.socketClosed) {
            return
        }
        if (!flags.upgraded) {
            match (rawResponse) {
                case Some(r) =>
                    r.onTimeout(this, NodeHTTPResponse.onTimeoutCallback)
                case None => {}
            }
        }
        upgradeContext.preserveWebSocketHeadersIfNeeded()
    }

    /// 处理中止或超时
    /// 对应 Bun: fn handle_abort_or_timeout<const EVENT: u8>(&self, js_value: JSValue)
    public func handleAbortOrTimeout(event: AbortEvent, jsValue: JSValue): Unit {
        if (flags.requestHasCompleted) {
            if (event == AbortEvent.Abort) {
                rawResponse = None
            }
            return
        }

        if (event == AbortEvent.Abort) {
            flags.socketClosed = true
        }

        ref()

        let jsThis: JSValue = if (jsValue.isEmpty()) {
            getThisValue()
        } else {
            jsValue
        }

        // 调用中止回调
        // 对应 Bun: js::on_aborted_get_cached(js_this)
        let onAborted = jsThis.getCachedOnAborted()
        if (onAborted != None) {
            let vm = VirtualMachine.get()
            vm.eventLoop.runCallback(
                onAborted.get(),
                vm.global,
                jsThis,
                Array<JSValue>(JSValue.jsNumber(Int64(event.ordinal())))
            )
            if (event == AbortEvent.Abort) {
                jsThis.setCachedOnAborted(JSValue.zero)
            }
        }

        if (event == AbortEvent.Abort) {
            onDataOrAborted(Array<Byte>(), true, AbortEvent.Abort, jsThis)
        }

        if (event == AbortEvent.Abort) {
            markRequestAsDoneIfNecessary()
            rawResponse = None
        }
        deref()
    }

    /// 中止回调
    /// 对应 Bun: #[uws::uws_callback] pub fn on_abort(&self, js_value: JSValue)
    public func onAbort(jsValue: JSValue): Unit {
        handleAbortOrTimeout(AbortEvent.Abort, jsValue)
    }

    /// 超时回调
    /// 对应 Bun: pub fn on_timeout(&self, _resp: uws::AnyResponse)
    public func onTimeout(resp: ResponseRef): Unit {
        handleAbortOrTimeout(AbortEvent.Timeout, JSValue.zero)
    }

    /// 设置已关闭
    /// 对应 Bun: pub fn set_closed(&self)
    public func setClosed(): Unit {
        flags.socketClosed = true
    }

    // ========================================================================
    // 暂停/恢复请求体
    // ========================================================================

    /// 暂停请求体读取
    /// 对应 Bun: pub fn do_pause(&self, global, frame, this_value) -> JsResult<JSValue>
    public func doPause(globalObject: JSGlobalObject, thisValue: JSValue): JSValue {
        match (rawResponse) {
            case Some(raw) =>
                if (flags.requestHasCompleted || flags.socketClosed
                    || flags.ended || flags.upgraded) {
                    return JSValue.jsBoolean(false)
                }
                flags.isDataBufferedDuringPause = true
                raw.onData(this, NodeHTTPResponse.onBufferPausedCallback)
                pauseSocket()
                return JSValue.jsBoolean(true)
            case None =>
                return JSValue.jsBoolean(false)
        }
    }

    /// 排空暂停期间的缓冲数据
    /// 对应 Bun: pub fn drain_request_body(&self, global_object, frame) -> JsResult<JSValue>
    public func drainRequestBody(globalObject: JSGlobalObject): JSValue {
        match (drainBufferedRequestBodyFromPause(globalObject)) {
            case Some(v) => v
            case None => JSValue.undefined
        }
    }

    /// 从暂停缓冲区排空
    /// 对应 Bun: fn drain_buffered_request_body_from_pause(&self, global_object) -> Option<JSValue>
    public func drainBufferedRequestBodyFromPause(globalObject: JSGlobalObject): ?JSValue {
        if (bufferedRequestBodyDataDuringPause.size > 0) {
            let bytes = bufferedRequestBodyDataDuringPause
            bufferedRequestBodyDataDuringPause = Array<UInt8>()
            return Some(JSValue.createBuffer(globalObject, bytes))
        }
        return None
    }

    /// 恢复请求体读取
    /// 对应 Bun: pub fn do_resume(&self, global_object, frame) -> JSValue
    public func doResume(globalObject: JSGlobalObject): JSValue {
        match (rawResponse) {
            case Some(raw) =>
                if (flags.requestHasCompleted || flags.socketClosed
                    || flags.ended || flags.upgraded) {
                    return JSValue.jsBoolean(false)
                }
                setOnAbortedHandler()
                raw.onData(this, NodeHTTPResponse.onDataCallback)
                flags.isDataBufferedDuringPause = false
                var result: JSValue = JSValue.jsBoolean(true)

                match (drainBufferedRequestBodyFromPause(globalObject)) {
                    case Some(bufferedData) =>
                        result = bufferedData
                    case None => {}
                }

                resumeSocket()
                return result
            case None =>
                return JSValue.jsBoolean(false)
        }
    }

    // ========================================================================
    // 请求完成
    // ========================================================================

    /// 请求完成回调
    /// 对应 Bun: pub fn on_request_complete(&self)
    public func onRequestComplete(): Unit {
        if (flags.requestHasCompleted) {
            return
        }
        flags.requestHasCompleted = true
        pollRef.unref()
        markRequestAsDoneIfNecessary()
    }

    // ========================================================================
    // 写入/结束响应
    // ========================================================================

    /// 写入响应头
    /// 对应 Bun: pub fn write_head(&self, global_object, callframe) -> JsResult<JSValue>
    public func writeHead(globalObject: JSGlobalObject, arguments: Array<JSValue>): ?JSValue {
        if (isRequestedCompletedOrEnded()) {
            globalObject.throwError("ERR_STREAM_ALREADY_FINISHED", "Stream is already ended")
            return None
        }

        match (rawResponse) {
            case Some(raw) =>
                if (flags.socketClosed || flags.upgraded) {
                    return JSValue.undefined
                }
            case None =>
                return JSValue.undefined
        }

        let raw = rawResponse.get()
        let state = raw.state()

        if (!state.isResponsePending()) {
            globalObject.throwError("ERR_HTTP_HEADERS_SENT", "Stream already started")
            return None
        }

        let statusCodeValue: JSValue = if (arguments.size > 0) { arguments[0] } else { JSValue.undefined }
        let statusMessageValue: JSValue = if (arguments.size > 1 && !arguments[1].isNull()) {
            arguments[1]
        } else { JSValue.undefined }
        let headersObjectValue: JSValue = if (arguments.size > 2 && !arguments[2].isNull()) {
            arguments[2]
        } else { JSValue.undefined }

        // 解析状态码
        var statusCode: Int32 = 200
        if (!statusCodeValue.isUndefined()) {
            statusCode = statusCodeValue.toInt32()
            if (statusCode < 100 || statusCode > 999) {
                globalObject.throwError("ERR_HTTP_INVALID_STATUS_CODE", "Invalid status code")
                return None
            }
        }

        // 获取状态消息
        let statusMessage: String = if (!statusMessageValue.isUndefined()) {
            statusMessageValue.toString(globalObject)
        } else {
            ""
        }

        if (globalObject.hasException()) {
            return None
        }

        if (state.isHttpStatusCalled()) {
            globalObject.throwError("ERR_HTTP_HEADERS_SENT", "Stream already started")
            return None
        }

        // 验证状态消息不包含无效字符
        for (c in statusMessage) {
            if (c != '\t' && (c < ' ' || c == '\u{7F}')) {
                globalObject.throwError("ERR_INVALID_CHAR", "Invalid character in statusMessage")
                return None
            }
        }

        // 构建最终状态行
        var finalMessage: String
        if (statusMessage.size == 0) {
            match (HTTPStatusText.get(UInt16(statusCode))) {
                case Some(t) => finalMessage = t
                case None => finalMessage = "\(statusCode) HM"
            }
        } else {
            finalMessage = "\(statusCode) \(statusMessage)"
        }

        // 写入头
        raw.writeHead(finalMessage, headersObjectValue)
        return JSValue.undefined
    }

    /// 写入 Continue (100)
    /// 对应 Bun: pub fn write_continue(&self, global_object, frame) -> JsResult<JSValue>
    public func writeContinue(globalObject: JSGlobalObject): JSValue {
        if (isDone()) {
            return JSValue.undefined
        }
        match (rawResponse) {
            case Some(raw) =>
                raw.writeContinue()
            case None => {}
        }
        return JSValue.undefined
    }

    /// 写入或结束响应体
    /// 对应 Bun: fn write_or_end<const IS_END: bool>(&self, global_object, arguments, this_value) -> JsResult<JSValue>
    public func writeOrEnd(isEnd: Bool, globalObject: JSGlobalObject,
                            arguments: Array<JSValue>, thisValue: JSValue): ?JSValue {
        if (isRequestedCompletedOrEnded()) {
            globalObject.throwError("ERR_STREAM_WRITE_AFTER_END", "Stream already ended")
            return None
        }

        if (flags.socketClosed || rawResponse == None) {
            return if (isEnd) { JSValue.undefined } else { JSValue.jsNumber(0) }
        }

        let raw = rawResponse.get()
        let state = raw.state()
        if (!state.isResponsePending()) {
            globalObject.throwError("ERR_STREAM_WRITE_AFTER_END", "Stream already ended")
            return None
        }

        let inputValue: JSValue = if (arguments.size > 0) { arguments[0] } else { JSValue.undefined }
        var encodingValue: JSValue = if (arguments.size > 1) { arguments[1] } else { JSValue.undefined }
        let callbackValue: JSValue = if (arguments.size > 2 && !arguments[2].isUndefined()) {
            arguments[2]
        } else { JSValue.undefined }

        // 编码处理
        let encoding: Encoding = if (!encodingValue.isUndefinedOrNull()) {
            Encoding.fromJS(encodingValue, globalObject) ?? Encoding.UTF8
        } else { Encoding.UTF8 }

        // 获取字节数据
        let bytes: Array<Byte> = if (!inputValue.isUndefinedOrNull()) {
            StringOrBuffer.toBytes(inputValue, globalObject, encoding)
        } else {
            Array<Byte>()
        }

        if (globalObject.hasException()) {
            return None
        }

        // 更新写入字节数
        bytesWritten += bytes.size

        if (isEnd) {
            // 结束响应
            if (bodyReadRef.has && bodyReadState == BodyReadState.Pending
                && !flags.hasCustomOnData) {
                bodyReadRef.unref()
                bodyReadState = BodyReadState.None
            }

            if (!thisValue.isEmpty()) {
                thisValue.setCachedOnAborted(JSValue.zero)
            }

            raw.clearAborted()
            raw.clearOnWritable()
            raw.clearTimeout()
            flags.ended = true

            if (!state.isHttpWriteCalled() || bytes.size > 0) {
                raw.end(bytes, state.isHttpConnectionClose())
            } else {
                raw.endStream(state.isHttpConnectionClose())
            }
            onRequestComplete()

            return JSValue.jsNumber(Int64(bytes.size))
        } else {
            // 写入数据
            let jsThis = if (!thisValue.isEmpty()) { thisValue } else { getThisValue() }
            match (raw.write(bytes)) {
                case .wantMore(let written) =>
                    raw.clearOnWritable()
                    jsThis.setCachedOnWritable(JSValue.undefined)
                    return JSValue.jsNumber(Int64(written))
                case .backpressure(let written) =>
                    if (!callbackValue.isUndefined()) {
                        jsThis.setCachedOnWritable(callbackValue)
                        raw.onWritable(this, NodeHTTPResponse.onDrainCallback)
                    }
                    return JSValue.jsNumber(-Int64(written))
            }
        }
    }

    /// 结束响应
    /// 对应 Bun: write_or_end<true>
    public func `end`(globalObject: JSGlobalObject, arguments: Array<JSValue>,
                       thisValue: JSValue): ?JSValue {
        writeOrEnd(true, globalObject, arguments, thisValue)
    }

    /// 写入数据
    /// 对应 Bun: write_or_end<false>
    public func write(globalObject: JSGlobalObject, arguments: Array<JSValue>,
                       thisValue: JSValue): ?JSValue {
        writeOrEnd(false, globalObject, arguments, thisValue)
    }

    /// 中止响应
    /// 对应 Bun: pub fn abort(&self, global, frame) -> JsResult<JSValue>
    public func abort(globalObject: JSGlobalObject): JSValue {
        if (isDone()) {
            return JSValue.undefined
        }

        flags.socketClosed = true
        match (rawResponse) {
            case Some(raw) =>
                let state = raw.state()
                if (state.isHttpEndCalled()) {
                    return JSValue.undefined
                }
            case None => {}
        }

        resumeSocket()
        match (rawResponse) {
            case Some(raw) =>
                raw.clearOnData()
                raw.clearOnWritable()
                raw.clearTimeout()
                raw.endWithoutBody(true)
            case None => {}
        }
        onRequestComplete()
        return JSValue.undefined
    }

    // ========================================================================
    // 数据回调
    // ========================================================================

    /// 暂停期间缓冲数据
    /// 对应 Bun: fn on_buffer_request_body_while_paused(&self, chunk, last)
    public func onBufferRequestBodyWhilePaused(chunk: Array<Byte>, last: Bool): Unit {
        bufferedRequestBodyDataDuringPause.appendAll(chunk)
        if (last) {
            flags.isDataBufferedDuringPauseLast = true
            if (bodyReadRef.has) {
                bodyReadRef.unref()
                markRequestAsDoneIfNecessary()
            }
        }
    }

    /// 获取字节值
    /// 对应 Bun: fn get_bytes(&self, global_this, chunk) -> JSValue
    public func getBytes(globalThis: JSGlobalObject, chunk: Array<Byte>): JSValue {
        if (chunk.size > 0 && bufferedRequestBodyDataDuringPause.size > 0) {
            let paused = bufferedRequestBodyDataDuringPause
            bufferedRequestBodyDataDuringPause = Array<Byte>()
            var combined = Array<Byte>(paused.size + chunk.size)
            combined.appendAll(paused)
            combined.appendAll(chunk)
            return JSValue.createBuffer(globalThis, combined)
        }

        match (drainBufferedRequestBodyFromPause(globalThis)) {
            case Some(v) => return v
            case None => {}
        }

        if (chunk.size > 0) {
            return JSValue.createBuffer(globalThis, chunk)
        }
        return JSValue.undefined
    }

    /// 数据或中止回调
    /// 对应 Bun: fn on_data_or_aborted(&self, chunk, last, event, this_value)
    public func onDataOrAborted(chunk: Array<Byte>, last: Bool, event: AbortEvent,
                                 thisValue: JSValue): Unit {
        if (last) {
            ref()
            bodyReadState = BodyReadState.Done
        }

        let onCallback = thisValue.getCachedOnData()
        if (onCallback != None && !onCallback.get().isUndefined()) {
            let vm = VirtualMachine.get()
            let globalThis = vm.global
            let bytes = getBytes(globalThis, chunk)
            vm.eventLoop.runCallback(
                onCallback.get(),
                globalThis,
                JSValue.undefined,
                Array<JSValue>(bytes, JSValue.jsBoolean(last),
                               JSValue.jsNumber(Int64(event.ordinal())))
            )
        }

        if (last) {
            if (bodyReadRef.has) {
                bodyReadRef.unref()
                markRequestAsDoneIfNecessary()
            }
            deref()
        }
    }

    /// 数据回调
    /// 对应 Bun: pub fn on_data(&self, chunk, last)
    public func onData(chunk: Array<Byte>, last: Bool): Unit {
        onDataOrAborted(chunk, last, AbortEvent.None, getThisValue())
    }

    /// 可排写回调 (corked)
    /// 对应 Bun: fn on_drain_corked(&self, offset)
    public func onDrainCorked(offset: Int64): Unit {
        ref()
        let thisValue = getThisValue()
        let onWritable = thisValue.getCachedOnWritable()
        if (onWritable == None) {
            deref()
            return
        }

        let vm = VirtualMachine.get()
        let globalThis = vm.global
        thisValue.setCachedOnWritable(JSValue.undefined)

        vm.eventLoop.runCallback(
            onWritable.get(),
            globalThis,
            JSValue.undefined,
            Array<JSValue>(JSValue.jsNumber(offset))
        )

        deref()
    }

    /// 可排写回调
    /// 对应 Bun: fn on_drain(&self, offset, response) -> bool
    public func onDrain(offset: Int64, response: ResponseRef): Bool {
        if (flags.socketClosed || flags.requestHasCompleted || flags.upgraded) {
            return false
        }

        response.corked(() => onDrainCorked(offset))
        return true
    }

    // ========================================================================
    // 属性访问器
    // ========================================================================

    /// 获取 ended 属性
    /// 对应 Bun: pub fn get_ended(&self, _global) -> JSValue
    public func getEnded(): JSValue {
        JSValue.jsBoolean(flags.ended)
    }

    /// 获取 finished 属性
    /// 对应 Bun: pub fn get_finished(&self, _global) -> JSValue
    public func getFinished(): JSValue {
        JSValue.jsBoolean(flags.requestHasCompleted)
    }

    /// 获取 flags 属性
    /// 对应 Bun: pub fn get_flags(&self, _global) -> JSValue
    public func getFlags(): JSValue {
        JSValue.jsNumber(Int64(flags.toBits()))
    }

    /// 获取 aborted 属性
    /// 对应 Bun: pub fn get_aborted(&self, _global) -> JSValue
    public func getAborted(): JSValue {
        JSValue.jsBoolean(flags.socketClosed)
    }

    /// 获取 hasBody 属性
    /// 对应 Bun: pub fn get_has_body(&self, _global) -> JSValue
    public func getHasBody(): JSValue {
        var result: Int32 = 0
        match (bodyReadState) {
            case BodyReadState.None => {}
            case BodyReadState.Pending => result |= 1 << 1
            case BodyReadState.Done => result |= 1 << 2
        }
        if (bufferedRequestBodyDataDuringPause.size > 0) {
            result |= 1 << 3
        }
        if (flags.isDataBufferedDuringPauseLast) {
            result |= 1 << 2
        }
        JSValue.jsNumber(result)
    }

    /// 获取缓冲量
    /// 对应 Bun: pub fn get_buffered_amount(&self, _global) -> JSValue
    public func getBufferedAmount(): JSValue {
        if (flags.requestHasCompleted || flags.socketClosed) {
            return JSValue.jsNumber(0)
        }
        match (rawResponse) {
            case Some(raw) =>
                return JSValue.jsNumber(Int64(raw.getBufferedAmount()))
            case None =>
                return JSValue.jsNumber(0)
        }
    }

    /// JS ref
    /// 对应 Bun: pub fn js_ref(&self, global_object, frame) -> JSValue
    public func jsRef(globalObject: JSGlobalObject): JSValue {
        if (!isDone()) {
            pollRef.ref()
        }
        return JSValue.undefined
    }

    /// JS unref
    /// 对应 Bun: pub fn js_unref(&self, global_object, frame) -> JSValue
    public func jsUnref(globalObject: JSGlobalObject): JSValue {
        if (!isDone()) {
            pollRef.unref()
        }
        return JSValue.undefined
    }

    // ========================================================================
    // JS 回调设置/获取
    // ========================================================================

    /// 设置可写回调
    /// 对应 Bun: pub fn set_on_writable(&self, this_value, global_object, value)
    public func setOnWritable(thisValue: JSValue, globalObject: JSGlobalObject, value: JSValue): Unit {
        if (isDone() || value.isUndefined()) {
            thisValue.setCachedOnWritable(JSValue.undefined)
        } else {
            thisValue.setCachedOnWritable(value)
        }
    }

    /// 获取可写回调
    /// 对应 Bun: pub fn get_on_writable(&self, this_value, _global) -> JSValue
    public func getOnWritable(thisValue: JSValue): JSValue {
        thisValue.getCachedOnWritable() ?? JSValue.undefined
    }

    /// 获取中止回调
    /// 对应 Bun: pub fn get_on_abort(&self, this_value, _global) -> JSValue
    public func getOnAbort(thisValue: JSValue): JSValue {
        if (flags.socketClosed || flags.upgraded) {
            return JSValue.undefined
        }
        thisValue.getCachedOnAborted() ?? JSValue.undefined
    }

    /// 设置中止回调
    /// 对应 Bun: pub fn set_on_abort(&self, this_value, global_object, value)
    public func setOnAbort(thisValue: JSValue, globalObject: JSGlobalObject, value: JSValue): Unit {
        if (flags.socketClosed || flags.upgraded) {
            return
        }
        if (isRequestedCompletedOrEnded() || value.isUndefined()) {
            thisValue.setCachedOnAborted(JSValue.zero)
        } else {
            thisValue.setCachedOnAborted(value)
        }
    }

    /// 获取数据回调
    /// 对应 Bun: pub fn get_on_data(&self, this_value, _global) -> JSValue
    public func getOnData(thisValue: JSValue): JSValue {
        thisValue.getCachedOnData() ?? JSValue.undefined
    }

    /// 获取是否有自定义 onData
    /// 对应 Bun: pub fn get_has_custom_on_data(&self, _global) -> JSValue
    public func getHasCustomOnData(): JSValue {
        JSValue.jsBoolean(flags.hasCustomOnData)
    }

    /// 获取是否已升级
    /// 对应 Bun: pub fn get_upgraded(&self, _global) -> JSValue
    public func getUpgraded(): JSValue {
        JSValue.jsBoolean(flags.upgraded)
    }

    /// 设置是否有自定义 onData
    /// 对应 Bun: pub fn set_has_custom_on_data(&self, _global, value)
    public func setHasCustomOnData(value: JSValue): Unit {
        flags.hasCustomOnData = value.toBoolean()
    }

    /// 设置数据回调
    /// 对应 Bun: pub fn set_on_data(&self, this_value, global_object, value)
    public func setOnData(thisValue: JSValue, globalObject: JSGlobalObject, value: JSValue): Unit {
        if (value.isUndefined() || flags.ended || flags.socketClosed
            || bodyReadState != BodyReadState.Pending
            || flags.isDataBufferedDuringPauseLast || flags.upgraded) {
            thisValue.setCachedOnData(JSValue.undefined)
            match (bodyReadState) {
                case BodyReadState.Pending | BodyReadState.Done =>
                    if (!flags.requestHasCompleted && !flags.socketClosed && !flags.upgraded) {
                        match (rawResponse) {
                            case Some(raw) => raw.clearOnData()
                            case None => {}
                        }
                    }
                    bodyReadState = BodyReadState.Done
                case BodyReadState.None => {}
            }
            if (bodyReadRef.has) {
                bodyReadRef.unref()
            }
            return
        }

        thisValue.setCachedOnData(value)
        flags.hasCustomOnData = true
        match (rawResponse) {
            case Some(raw) =>
                raw.onData(this, NodeHTTPResponse.onDataCallback)
            case None => {}
        }
        flags.isDataBufferedDuringPause = false
    }

    /// 清除数据回调
    /// 对应 Bun: fn clear_on_data_callback(&self, this_value, global_object)
    public func clearOnDataCallback(thisValue: JSValue, globalObject: JSGlobalObject): Unit {
        if (bodyReadState != BodyReadState.None) {
            if (!thisValue.isEmpty()) {
                thisValue.setCachedOnData(JSValue.undefined)
            }
            if (!flags.socketClosed && !flags.upgraded) {
                match (rawResponse) {
                    case Some(raw) => raw.clearOnData()
                    case None => {}
                }
            }
            if (bodyReadState != BodyReadState.Done) {
                bodyReadState = BodyReadState.Done
            }
        }
    }

    // ========================================================================
    // 自动刷写
    // ========================================================================

    /// 注册自动刷写
    /// 对应 Bun: fn register_auto_flush(&self)
    public func registerAutoFlush(): Unit {
        autoFlusher.register(this)
    }

    /// 注销自动刷写
    /// 对应 Bun: fn unregister_auto_flush(&self)
    public func unregisterAutoFlush(): Unit {
        autoFlusher.unregister()
    }

    /// 自动刷写回调
    /// 对应 Bun: fn on_auto_flush(&self) -> bool
    public func onAutoFlush(): Bool {
        // 调用 corked 刷写
        match (rawResponse) {
            case Some(raw) =>
                raw.flush()
            case None => {}
        }
        return false // 不重复
    }

    // ========================================================================
    // 静态回调适配器
    // ========================================================================

    /// 超时回调适配器
    public static func onTimeoutCallback(response: NodeHTTPResponse, resp: ResponseRef): Unit {
        response.onTimeout(resp)
    }

    /// 数据回调适配器
    public static func onDataCallback(response: NodeHTTPResponse, chunk: Array<Byte>, last: Bool): Unit {
        response.onData(chunk, last)
    }

    /// 暂停缓冲回调适配器
    public static func onBufferPausedCallback(response: NodeHTTPResponse, chunk: Array<Byte>, last: Bool): Unit {
        response.onBufferRequestBodyWhilePaused(chunk, last)
    }

    /// 排写回调适配器
    public static func onDrainCallback(response: NodeHTTPResponse, offset: Int64, resp: ResponseRef): Bool {
        response.onDrain(offset, resp)
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// PollRef - 引用/取消引用轮询
public class PollRef {
    public var has: Bool

    public init() {
        has = false
    }

    public func ref(): Unit {
        has = true
    }

    public func unref(): Unit {
        has = false
    }

    public func unref(vm: VirtualMachine): Unit {
        has = false
    }
}

/// Promise 引用
public class PromiseRef {
    public var resolved: Bool
    public var rejected: Bool

    public init() {
        resolved = false
        rejected = false
    }

    public func deinit(): Unit {
        resolved = false
        rejected = false
    }
}

/// 自动刷写器
/// 对应 Bun: JsCell<AutoFlusher>
public class AutoFlusher {
    public var registered: Bool
    public var response: ?NodeHTTPResponse

    public init() {
        registered = false
        response = None
    }

    public func register(response: NodeHTTPResponse): Unit {
        this.response = response
        registered = true
    }

    public func unregister(): Unit {
        registered = false
        response = None
    }
}

/// 编码类型
public enum Encoding {
    | UTF8
    | ASCII
    | Latin1
    | Hex
    | Base64
    | UCS2

    public static func fromJS(value: JSValue, global: JSGlobalObject): ?Encoding {
        let str = value.toString(global)
        if (str == "utf-8" || str == "utf8") return Some(Encoding.UTF8)
        if (str == "ascii") return Some(Encoding.ASCII)
        if (str == "latin1" || str == "binary") return Some(Encoding.Latin1)
        if (str == "hex") return Some(Encoding.Hex)
        if (str == "base64") return Some(Encoding.Base64)
        if (str == "ucs2" || str == "ucs-2") return Some(Encoding.UCS2)
        return None
    }
}

/// 字符串或缓冲区工具
public class StringOrBuffer {
    public static func toBytes(value: JSValue, global: JSGlobalObject, encoding: Encoding): Array<Byte> {
        if (value.isString()) {
            return value.toString(global).toBytes()
        }
        if (let buf = value.asArrayBuffer(global)) {
            return buf
        }
        return Array<Byte>()
    }
}

/// 虚拟机
public class VirtualMachine {
    public var global: JSGlobalObject
    public var eventLoop: EventLoop

    public static func get(): VirtualMachine {
        VirtualMachine()
    }

    public init() {
        global = JSGlobalObject()
        eventLoop = EventLoop()
    }
}

/// 事件循环
public class EventLoop {
    public func runCallback(callback: JSValue, global: JSGlobalObject,
                             thisValue: JSValue, args: Array<JSValue>): Unit {}
}

/// JSValue 简化
public class JSValue {
    public static let zero = JSValue()
    public static let undefined = JSValue()
    public static let `true` = JSValue()
    public static let `false` = JSValue()

    public init() {}

    public func isUndefined(): Bool { true }
    public func isEmpty(): Bool { true }
    public func isNull(): Bool { false }
    public func isUndefinedOrNull(): Bool { false }
    public func isString(): Bool { false }
    public func isCallable(): Bool { false }
    public func isNumber(): Bool { false }
    public func isBoolean(): Bool { false }
    public func toBoolean(): Bool { false }
    public func toInt32(): Int32 { 0 }
    public func toString(global: JSGlobalObject): String { "" }
    public func asArrayBuffer(global: JSGlobalObject): ?Array<Byte> { None }

    public static func jsBoolean(b: Bool): JSValue { JSValue() }
    public static func jsNumber(n: Int64): JSValue { JSValue() }
    public static func createBuffer(global: JSGlobalObject, bytes: Array<Byte>): JSValue { JSValue() }

    // 缓存属性访问
    public func getCachedOnData(): ?JSValue { None }
    public func getCachedOnAborted(): ?JSValue { None }
    public func getCachedOnWritable(): ?JSValue { None }
    public func setCachedOnData(v: JSValue): Unit {}
    public func setCachedOnAborted(v: JSValue): Unit {}
    public func setCachedOnWritable(v: JSValue): Unit {}
}

/// 全局对象
public class JSGlobalObject {
    public init() {}

    public func hasException(): Bool { false }
    public func throwError(code: String, msg: String): Unit {}
    public func throwInvalidArguments(msg: String): Unit {}
}

/// HTTP 状态文本前向声明
public class HTTPStatusText {
    public static func get(status: UInt16): ?String { None }
}

/// 响应引用
public class ResponseRef {
    public init() {}

    public func state(): ResponseState { ResponseState() }
    public func pause(): Unit {}
    public func resume(): Unit {}
    public func flush(): Unit {}
    public func corked(f: () -> Unit): Unit { f() }
    public func end(bytes: Array<Byte>, close: Bool): Unit {}
    public func endStream(close: Bool): Unit {}
    public func endWithoutBody(close: Bool): Unit {}
    public func write(bytes: Array<Byte>): WriteResult { WriteResult.wantMore(bytes.size) }
    public func writeHead(msg: String, headers: JSValue): Unit {}
    public func writeContinue(): Unit {}
    public func clearOnData(): Unit {}
    public func clearOnWritable(): Unit {}
    public func clearAborted(): Unit {}
    public func clearTimeout(): Unit {}
    public func onTimeout(ctx: NodeHTTPResponse, cb: (NodeHTTPResponse, ResponseRef) -> Unit): Unit {}
    public func onData(ctx: NodeHTTPResponse, cb: (NodeHTTPResponse, Array<Byte>, Bool) -> Unit): Unit {}
    public func onWritable(ctx: NodeHTTPResponse, cb: (NodeHTTPResponse, Int64, ResponseRef) -> Bool): Unit {}
    public func getBufferedAmount(): Int64 { 0 }
    public func isConnectRequest(): Bool { false }
    public func upgrade(ws: ServerWebSocket, key: String, proto: String, ext: String,
                         ctx: ?WebSocketUpgradeContext): Unit {}
    public func getNodeHTTPResponseThisValue(): JSValue { JSValue() }
    public func getNodeHTTPServerSocketThisValue(): JSValue { JSValue() }
}

/// 响应状态
public class ResponseState {
    public func isResponsePending(): Bool { true }
    public func isHttpStatusCalled(): Bool { false }
    public func isHttpWriteCalled(): Bool { false }
    public func isHttpEndCalled(): Bool { false }
    public func isHttpConnectionClose(): Bool { false }
}

/// 写入结果
public enum WriteResult {
    | WantMore(Int64)     // 写入的字节数
    | Backpressure(Int64) // 已写入但背压
}

/// 服务器引用 (扩展)
public class ServerRef {
    public var id: String

    public init(id: String) {
        this.id = id
    }

    public func onRequestComplete(): Unit {}
    public func getWebSocketHandler(): ?WebSocketServerHandler { None }
}

/// WebSocket 服务器处理器
public class WebSocketServerHandler {}

/// WebSocket 升级上下文
public class WebSocketUpgradeContext {}

/// 原始请求引用
public class RawRequestRef {
    public func header(name: String): ?String { None }
}

/// ServerWebSocket 前向声明
public class ServerWebSocket {
    public static func init(handler: WebSocketServerHandler, dataValue: JSValue,
                             signal: ?AnyRef): ServerWebSocket {
        ServerWebSocket()
    }
}

/// AnyRef
public class AnyRef {}
