// NodeHTTPResponse - Node.js 兼容的 HTTP 响应
// 严格翻译自: Bun src/runtime/server/NodeHTTPResponse.zig
// 对应: node:http 模块的 ServerResponse 实现
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// NodeHTTPResponse - Node.js 兼容 HTTP 响应
// 严格翻译自: src/runtime/server/NodeHTTPResponse.zig
// Bun: const NodeHTTPResponse = @This()
// 提供 Node.js 的 http.ServerResponse 兼容接口
// ============================================================================

/// NodeHTTPResponse 标志
/// 对应 Bun: pub const Flags = packed struct(u8) { ... }
public class NodeHTTPResponseFlags {
    /// Socket 已关闭 - 对应 Bun: socket_closed: bool = false
    public var socketClosed: Bool
    /// 请求已完成 - 对应 Bun: request_has_completed: bool = false
    public var requestHasCompleted: Bool
    /// 已结束 - 对应 Bun: ended: bool = false
    public var ended: Bool
    /// 已升级 - 对应 Bun: upgraded: bool = false
    public var upgraded: Bool
    /// 有自定义 onData - 对应 Bun: hasCustomOnData: bool = false
    public var hasCustomOnData: Bool
    /// 请求是否待处理 - 对应 Bun: is_request_pending: bool = true
    public var isRequestPending: Bool
    /// 暂停期间是否缓冲了数据 - 对应 Bun: is_data_buffered_during_pause: bool = false
    public var isDataBufferedDuringPause: Bool
    /// 暂停期间是否收到最后一块数据 - 对应 Bun: is_data_buffered_during_pause_last: bool = false
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
    /// 对应 Bun: pub fn isRequestedCompletedOrEnded(this) bool
    public func isRequestedCompletedOrEnded(): Bool {
        return requestHasCompleted || ended
    }

    /// 是否完成
    /// 对应 Bun: pub fn isDone(this) bool
    public func isDone(): Bool {
        return isRequestedCompletedOrEnded() || socketClosed
    }
}

/// 升级上下文
/// 对应 Bun: pub const UpgradeCTX = struct { ... }
public class NodeUpgradeContext {
    /// WebSocket 升级上下文
    public var context: ?WebSocketUpgradeContext

    /// 原始请求引用
    public var request: ?RawRequestRef

    /// WebSocket 头部
    /// 对应 Bun: sec_websocket_key, sec_websocket_protocol, sec_websocket_extensions
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

    /// 清理
    /// 对应 Bun: pub fn deinit(this) void
    public func deinit(): Unit {
        context = None
        request = None
        secWebSocketKey = ""
        secWebSocketProtocol = ""
        secWebSocketExtensions = ""
    }

    /// 保留 WebSocket 头部 (用于异步升级)
    /// 对应 Bun: pub fn preserveWebSocketHeadersIfNeeded(this) void
    public func preserveWebSocketHeadersIfNeeded(): Unit {
        match (request) {
            case Some(req) => {
                request = None

                match (req.headers.get("sec-websocket-key")) {
                    case Some(v) => secWebSocketKey = v
                    case None => ()
                }
                match (req.headers.get("sec-websocket-protocol")) {
                    case Some(v) => secWebSocketProtocol = v
                    case None => ()
                }
                match (req.headers.get("sec-websocket-extensions")) {
                    case Some(v) => secWebSocketExtensions = v
                    case None => ()
                }
            }
            case None => ()
        }
    }
}

/// Body 读取状态
/// 对应 Bun: BodyReadState
public enum BodyReadState {
    | None
    | Reading
    | Done
}

/// Node.js HTTP 响应
/// 严格翻译自: src/runtime/server/NodeHTTPResponse.zig
/// 对应 Bun: const NodeHTTPResponse = @This()
/// 提供 Node.js 的 http.ServerResponse 兼容接口
public class NodeHTTPResponse {
    // ========================================================================
    // 字段
    // ========================================================================

    /// 引用计数
    public var refCount: Int64

    /// 原始响应 - 对应 Bun: raw_response: ?uws.AnyResponse
    public var rawResponse: ?ResponseRef

    /// 标志 - 对应 Bun: flags: Flags = .{}
    public var flags: NodeHTTPResponseFlags

    /// 轮询引用 - 对应 Bun: poll_ref: jsc.Ref
    public var pollRef: PollRef

    /// Body 读取状态 - 对应 Bun: body_read_state: BodyReadState = .none
    public var bodyReadState: BodyReadState

    /// Body 读取引用 - 对应 Bun: body_read_ref: jsc.Ref
    public var bodyReadRef: PollRef

    /// Promise - 对应 Bun: promise: jsc.Strong.Optional = .empty
    public var promise: ?PromiseRef

    /// 服务器引用 - 对应 Bun: server: AnyServer
    public var server: ?ServerRef

    /// 暂停期间缓冲的请求体数据
    /// 对应 Bun: buffered_request_body_data_during_pause: bun.ByteList
    public var bufferedRequestBodyDataDuringPause: Array<UInt8>

    /// 已写入字节数 - 对应 Bun: bytes_written: usize = 0
    public var bytesWritten: Int64

    /// 升级上下文 - 对应 Bun: upgrade_context: UpgradeCTX
    public var upgradeContext: NodeUpgradeContext

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
    }

    // ========================================================================
    // 生命周期
    // ========================================================================

    /// 增加引用
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// 析构
    public func deinit(): Unit {
        rawResponse = None
        promise = None
        bufferedRequestBodyDataDuringPause = Array<UInt8>()
        upgradeContext.deinit()
    }
}

/// PollRef 简化
public class PollRef {
    public var refCount: Int64

    public init() {
        refCount = 0
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
}
