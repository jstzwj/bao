// 翻译自 Bun: src/runtime/bake/DevServer/HmrSocket.zig
// HMR WebSocket 连接处理器。处理客户端与服务器的热模块重载通信。
//
// 每个消息使用 .binary/ArrayBuffer 传输模式。第一个字节表示消息 ID。
// 所有整数使用小端序。
//
// 消息流:
//   客户端连接 -> 服务器发送 version payload -> 客户端订阅主题
//   -> 文件变更触发 hot_update/errors 消息
//   -> 客户端导航发送 set_url -> 服务器响应 set_url_response

package bao_runtime.bake.dev_server

import bao_bun_alloc.Allocator
import bao_collections.HashMap

// ============================================================================
// HmrSocket - WebSocket 连接处理器
// ============================================================================

/// HMR Socket - WebSocket 连接处理器
/// 对应 Bun: DevServer.HmrSocket
public class HmrSocket {
    public var dev: DevServer
    public var underlying: ?AnyWebSocket
    /// 订阅位集 - 每个位对应一个 HmrTopic
    public var subscriptions: Int64
    /// 是否来自本地主机
    public var isFromLocalhost: Bool
    /// 活跃路由索引（告知 DevServer 当前页面路由）
    public var activeRoute: ?RouteBundleIndex
    /// 此 socket 引用的源映射
    public var referencedSourceMaps: HashMap<UInt64, Unit>
    /// Inspector 连接 ID
    public var inspectorConnectionId: Int32
    /// WebSocket 主题订阅
    public var subscriptionsHotUpdate: Bool
    public var subscriptionsErrors: Bool
    public var subscriptionsBrowserError: Bool
    public var subscriptionsIncrementalVisualizer: Bool
    public var subscriptionsMemoryVisualizer: Bool

    public init() {
        dev = DevServer()
        underlying = None
        subscriptions = 0
        isFromLocalhost = false
        activeRoute = None
        referencedSourceMaps = HashMap<UInt64, Unit>()
        inspectorConnectionId = -1
        subscriptionsHotUpdate = false
        subscriptionsErrors = false
        subscriptionsBrowserError = false
        subscriptionsIncrementalVisualizer = false
        subscriptionsMemoryVisualizer = false
    }

    /// 创建新的 HMR Socket
    /// 对应 Bun: HmrSocket.new(dev, res)
    public static func create(dev: DevServer, res: Any): HmrSocket {
        let socket = HmrSocket()
        socket.dev = dev
        socket.isFromLocalhost = false
        socket.subscriptions = 0
        socket.activeRoute = None
        socket.referencedSourceMaps = HashMap<UInt64, Unit>()
        return socket
    }

    /// WebSocket 打开回调
    /// 对应 Bun: fn onOpen(this, ws)
    public func onOpen(ws: AnyWebSocket): Unit {
        // 发送 version payload
        // 格式: 'V' + 16字节配置哈希
        var versionPayload = Array<Byte>(17, { _ => 0 })
        versionPayload[0] = Byte(86) // 'V'
        // 复制配置哈希
        for (i in 0..dev.configurationHashKey.size) {
            if (i < 16) {
                versionPayload[Int64(i) + 1] = dev.configurationHashKey[Int64(i)]
            }
        }
        let sendStatus = ws.send(versionPayload, Opcode.binary, false, true)
        underlying = ws
    }

    /// WebSocket 消息回调
    /// 对应 Bun: fn onMessage(this, ws, msg, opcode)
    /// 处理来自客户端的所有传入消息
    public func onMessage(ws: AnyWebSocket, msg: Array<Byte>, opcode: Opcode): Unit {
        if (msg.size == 0) {
            return ws.close()
        }

        let msgId = msg[0]

        if (msgId == Byte(105)) {
            // 'i' = init
            onInitMessage(ws, msg)
        } else if (msgId == Byte(115)) {
            // 's' = subscribe
            onSubscribeMessage(ws, msg)
        } else if (msgId == Byte(110)) {
            // 'n' = set_url
            onSetUrlMessage(ws, msg)
        } else if (msgId == Byte(72)) {
            // 'H' = testing_batch_events
            onTestingBatchEventsMessage(ws)
        } else if (msgId == Byte(108)) {
            // 'l' = console_log
            onConsoleLogMessage(ws, msg)
        } else if (msgId == Byte(117)) {
            // 'u' = unref_source_map
            onUnrefSourceMapMessage(ws, msg)
        } else {
            ws.close()
        }
    }

    /// 处理 init 消息
    /// 格式: 'i' + 8字节hex Source Map ID
    func onInitMessage(ws: AnyWebSocket, msg: Array<Byte>): Unit {
        if (msg.size < 9) { return ws.close() }
        let hexSlice = msg[1..9]
        let sourceMapId = parseHexToUInt64(hexSlice)
        if (sourceMapId.isNone()) { return ws.close() }

        // 将弱引用升级为强引用
        if (dev.sourceMaps.removeOrUpgradeWeakRef(sourceMapId.getOrThrow(), WeakRefMode.upgrade)) {
            referencedSourceMaps.put(sourceMapId.getOrThrow(), ())
        }
    }

    /// 处理 subscribe 消息
    /// 格式: 's' + 主题字符序列
    func onSubscribeMessage(ws: AnyWebSocket, msg: Array<Byte>): Unit {
        var i: Int64 = 1
        while (i < msg.size) {
            let topicChar = msg[i]
            if (topicChar == Byte(104)) {
                // 'h' = hot_update
                subscriptionsHotUpdate = true
            } else if (topicChar == Byte(101)) {
                // 'e' = errors
                subscriptionsErrors = true
            } else if (topicChar == Byte(69)) {
                // 'E' = browser_error
                subscriptionsBrowserError = true
            } else if (topicChar == Byte(118)) {
                // 'v' = incremental_visualizer
                subscriptionsIncrementalVisualizer = true
                dev.emitIncrementalVisualizerEvents += 1
            } else if (topicChar == Byte(77)) {
                // 'M' = memory_visualizer
                subscriptionsMemoryVisualizer = true
                dev.emitMemoryVisualizerEvents += 1
            }
            i += 1
        }
    }

    /// 处理 set_url 消息
    /// 格式: 'n' + UTF-8 URL 路径
    func onSetUrlMessage(ws: AnyWebSocket, msg: Array<Byte>): Unit {
        // 解析 URL 路径
        var urlPath = ""
        for (i in 1..msg.size) {
            urlPath += String(Char.fromUInt32(UInt32(msg[i])))
        }

        // 查找匹配的路由
        let maybeRbi = dev.routeToBundleIndexSlow(urlPath)

        // 取消之前的活跃路由
        if (let Some(oldRbi) <- activeRoute) {
            let oldBundle = dev.routeBundlePtr(oldRbi)
            if (oldBundle.activeViewers > 0) {
                oldBundle.activeViewers -= 1
            }
        }

        if (let Some(rbi) <- maybeRbi) {
            activeRoute = rbi
            let newBundle = dev.routeBundlePtr(rbi)
            newBundle.activeViewers += 1

            // 发送 set_url_response: 'n' + u32 route_index
            var response = Array<Byte>(5, { _ => 0 })
            response[0] = Byte(110) // 'n'
            response[1] = UInt8(rbi.get() & UInt32(0xFF))
            response[2] = UInt8((rbi.get() >> 8) & UInt32(0xFF))
            response[3] = UInt8((rbi.get() >> 16) & UInt32(0xFF))
            response[4] = UInt8((rbi.get() >> 24) & UInt32(0xFF))
            ws.send(response, Opcode.binary, false, true)
        } else {
            activeRoute = None
            // 发送 -1 表示未找到
            var response = Array<Byte>(5, { _ => 0 })
            response[0] = Byte(110)
            response[1] = 0xFF
            response[2] = 0xFF
            response[3] = 0xFF
            response[4] = 0xFF
            ws.send(response, Opcode.binary, false, true)
        }

        // 通知 Inspector
        if (inspectorConnectionId > -1) {
            notifyInspectorClientNavigation(urlPath, activeRoute)
        }
    }

    /// 处理 testing_batch_events 消息
    func onTestingBatchEventsMessage(ws: AnyWebSocket): Unit {
        match (dev.testingBatchEvents) {
            case TestingBatchEvents.disabled =>
                if (dev.currentBundle.isSome()) {
                    dev.testingBatchEvents = TestingBatchEvents.enable_after_bundle
                }
            case TestingBatchEvents.enable_after_bundle =>
                () // 已经在等待
            case TestingBatchEvents.enabled(batch) =>
                dev.testingBatchEvents = TestingBatchEvents.disabled
        }
    }

    /// 处理 console_log 消息
    /// 格式: 'l'/'e' + UTF-8 日志内容
    func onConsoleLogMessage(ws: AnyWebSocket, msg: Array<Byte>): Unit {
        if (msg.size < 2) { return }
        let kind: ConsoleLogKind = if (msg[1] == Byte(108)) {
            ConsoleLogKind.log
        } else {
            ConsoleLogKind.err
        }

        // 提取日志数据
        var data = ""
        for (i in 2..msg.size) {
            data += String(Char.fromUInt32(UInt32(msg[i])))
        }

        if (dev.broadcastConsoleLogFromBrowserToServer) {
            match (kind) {
                case ConsoleLogKind.log =>
                    Output.pretty("[browser] ${data}\n")
                case ConsoleLogKind.err =>
                    Output.prettyError("[browser] ${data}\n")
            }
            Output.flush()
        }
    }

    /// 处理 unref_source_map 消息
    /// 格式: 'u' + 8字节hex source map key
    func onUnrefSourceMapMessage(ws: AnyWebSocket, msg: Array<Byte>): Unit {
        if (msg.size < 9) { return }
        let hexSlice = msg[1..9]
        let sourceMapKey = parseHexToUInt64(hexSlice)
        if (let Some(key) <- sourceMapKey) {
            referencedSourceMaps.remove(key)
            dev.sourceMaps.unref(key)
        }
    }

    /// 取消订阅处理
    func onUnsubscribe(): Unit {
        // 减少可视化器引用计数
        if (subscriptionsIncrementalVisualizer) {
            if (dev.emitIncrementalVisualizerEvents > 0) {
                dev.emitIncrementalVisualizerEvents -= 1
            }
        }
        if (subscriptionsMemoryVisualizer) {
            if (dev.emitMemoryVisualizerEvents > 0) {
                dev.emitMemoryVisualizerEvents -= 1
            }
        }
    }

    /// WebSocket 关闭回调
    /// 对应 Bun: fn onClose(this, ws, exit_code, message)
    public func onClose(ws: AnyWebSocket, exitCode: Int32, message: Array<Byte>): Unit {
        onUnsubscribe()

        // 通知 Inspector
        if (inspectorConnectionId > -1) {
            // agent.notifyClientDisconnected(dev.inspectorServerId, inspectorConnectionId)
        }

        // 减少活跃路由的 viewer 计数
        if (let Some(oldRbi) <- activeRoute) {
            let oldBundle = dev.routeBundlePtr(oldRbi)
            if (oldBundle.activeViewers > 0) {
                oldBundle.activeViewers -= 1
            }
        }

        // 释放引用的源映射
        var keys = referencedSourceMaps.keys()
        for (key in keys) {
            dev.sourceMaps.unref(key)
        }
        referencedSourceMaps.clear()

        // 从活跃连接中移除
        dev.activeWebsocketConnections.remove(this)
    }

    /// 通知 Inspector 客户端导航
    func notifyInspectorClientNavigation(pattern: String, rbi: ?RouteBundleIndex): Unit {
        if (inspectorConnectionId > -1) {
            // agent.notifyClientNavigated(dev.inspectorServerId, inspectorConnectionId, pattern, rbi)
        }
    }

    /// 解析十六进制字节数组为 UInt64
    static func parseHexToUInt64(hex: Array<Byte>): ?UInt64 {
        if (hex.size < 16) { return None }
        var result: UInt64 = UInt64(0)
        for (i in 0..16) {
            let ch = Int64(hex[i])
            let digit: UInt64 = if (ch >= 48 && ch <= 57) {
                UInt64(ch - 48)
            } else if (ch >= 97 && ch <= 102) {
                UInt64(ch - 97 + 10)
            } else if (ch >= 65 && ch <= 70) {
                UInt64(ch - 65 + 10)
            } else {
                return None
            }
            result = result * UInt64(16) + digit
        }
        return result
    }
}

// ============================================================================
// 辅助类型（此处定义以使子包自包含）
// 完整类型在父包 dev_server.cj 中也有定义
// ============================================================================

/// AnyWebSocket - WebSocket 连接封装
public class AnyWebSocket {
    public init() {}
    public func send(data: Array<Byte>, opcode: Opcode, compress: Bool, fin: Bool): SendStatus { SendStatus.sent }
    public func close(): Unit {}
}

/// Opcode - WebSocket 操作码
public enum Opcode {
    | text
    | binary
    | close
    | ping
    | pong
}

/// SendStatus - 发送状态
public enum SendStatus {
    | dropped
    | sent
}

/// ConsoleLogKind - 控制台日志类型
public enum ConsoleLogKind {
    | log
    | err
}

/// WeakRefMode - 弱引用模式
public enum WeakRefMode {
    | upgrade
    | downgrade
}

/// DevServer 引用（简化版，完整定义在父包 dev_server.cj）
public class DevServer {
    public var configurationHashKey: Array<Byte> = Array<Byte>(16, { _ => 0 })
    public var sourceMaps: SourceMapStore = SourceMapStore()
    public var currentBundle: ?Any = None
    public var testingBatchEvents: TestingBatchEvents = TestingBatchEvents.disabled
    public var broadcastConsoleLogFromBrowserToServer: Bool = false
    public var emitIncrementalVisualizerEvents: UInt32 = 0
    public var emitMemoryVisualizerEvents: UInt32 = 0
    public var activeWebsocketConnections: HashMap<HmrSocket, Unit> = HashMap<HmrSocket, Unit>()
    public var routeBundles: Array<RouteBundle> = []

    public init() {}
    public func allocator(): Allocator { Allocator() }
    public func routeToBundleIndexSlow(pattern: String): ?RouteBundleIndex { None }
    public func routeBundlePtr(index: RouteBundleIndex): RouteBundle {
        if (index.get() < routeBundles.size) { routeBundles[Int64(index.get())] } else { RouteBundle() }
    }
}

/// RouteBundleIndex
public class RouteBundleIndex {
    public var value: UInt32
    public init(value: UInt32) { this.value = value }
    public init() { value = 0 }
    public func get(): UInt32 { value }
}

/// RouteBundle
public class RouteBundle {
    public var serverState: RouteBundleState = RouteBundleState.unqueued
    public var clientScriptGeneration: UInt32 = 0
    public var clientBundle: ?Any = None
    public var activeViewers: UInt32 = 0
    public init() {}
}

/// RouteBundleState
public enum RouteBundleState {
    | unqueued
    | bundling
    | deferred_to_next_bundle
    | possible_bundling_failures
    | evaluation_failure
    | loaded
}

/// TestingBatchEvents
public enum TestingBatchEvents {
    | disabled
    | enable_after_bundle
    | enabled(TestingBatch)
}

/// TestingBatch
public class TestingBatch {
    public init() {}
}

/// SourceMapStore
public class SourceMapStore {
    public init() {}
    public func unref(key: UInt64): Unit {}
    public func removeOrUpgradeWeakRef(key: UInt64, mode: WeakRefMode): Bool { false }
    public func keys(): Array<UInt64> { [] }
}

/// Output
public class Output {
    public static func pretty(msg: String): Unit { print(msg) }
    public static func prettyError(msg: String): Unit { print(msg) }
    public static func flush(): Unit {}
}

/// Object helper
public class Object {
    public init() {}
}
