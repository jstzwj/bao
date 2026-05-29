// 翻译自 Bun: src/runtime/bake/DevServer/HmrSocket.zig
// HMR WebSocket 连接处理器。处理客户端与服务器的热模块重载通信。

package bao_runtime.bake.dev_server

/// HMR Socket - WebSocket 连接处理器
public class HmrSocket {
    public var dev: DevServer
    public var underlying: ?AnyWebSocket
    public var subscriptions: Int64
    /// 允许检查或修改敏感 DevServer 状态的操作
    public var is_from_localhost: Bool
    /// 告知 DevServer 活跃路由，从而接收路由更新的详细 hot_update 事件
    public var active_route: IndexOptional
    /// 引用的源映射
    public var referenced_source_maps: HashMap<UInt64, Unit>
    /// Inspector 连接 ID
    public var inspector_connection_id: Int32

    public init() {
        dev = DevServer()
        underlying = None
        subscriptions = 0
        is_from_localhost = false
        active_route = IndexOptional.none
        referenced_source_maps = HashMap<UInt64, Unit>()
        inspector_connection_id = -1
    }

    /// 创建新的 HMR Socket
    public static func new(dev: DevServer, res: Any): HmrSocket {
        let is_localhost = false
        let socket = HmrSocket()
        socket.dev = dev
        socket.is_from_localhost = is_localhost
        socket.subscriptions = 0
        socket.active_route = IndexOptional.none
        socket.referenced_source_maps = HashMap<UInt64, Unit>()
        return socket
    }

    /// WebSocket 打开回调
    public func onOpen(ws: AnyWebSocket): Unit {
        // [KEPT: no-pkg - simplified (Array is fixed-size in Cangjie)]
        let versionPayload = [MessageId.version.char()]
        let sendStatus = ws.send(versionPayload, Opcode.binary, false, true)
        underlying = ws
    }

    /// WebSocket 消息回调
    public func onMessage(ws: AnyWebSocket, msg: Array<Byte>, opcode: Opcode): Unit {
        if (msg.size == 0) {
            return ws.close()
        }

        let msgId = msg[0]
        if (msgId == 105) { // 'i' = init
            if (msg.size != 9) { return ws.close() }
            let source_map_id = UInt64(0) << 32
                if (dev.source_maps.removeOrUpgradeWeakRef(source_map_id, WeakRefMode.upgrade)) {
                    referenced_source_maps.put(source_map_id, ())
                }
        } else if (msgId == 115) { // 's'
                subscriptions = 0

            } else if (msgId == 117) { // 'u'
                let pattern = if (msg.size > 1) { "" } else { "" }
                let maybe_rbi = dev.routeToBundleIndexSlow(pattern)

                if (let Some(rbi) <- maybe_rbi) {
                if (let Some(old) <- active_route.unwrap()) {
                    if (old == rbi) { return }
                    // dev.routeBundlePtr(old).active_viewers -= 1
                }
                // dev.routeBundlePtr(rbi).active_viewers += 1
                active_route = IndexOptional()

            } else if (msgId == 116) { // 't'
                match (dev.testing_batch_events) {
                    case TestingBatchEvents.disabled =>
                        if (dev.current_bundle.isSome()) {
                            dev.testing_batch_events = TestingBatchEvents.enable_after_bundle
                        }
                    case TestingBatchEvents.enable_after_bundle =>
                        ws.close()
                    case TestingBatchEvents.enabled(event_const) =>
                        dev.testing_batch_events = TestingBatchEvents.disabled
                }

            } else if (msgId == 99) { // 'c'
                if (msg.size < 2) {
                    ws.close()
                    return
                }
                let kind: ConsoleLogKind = if (msg[1] == 108) { ConsoleLogKind.log } else { ConsoleLogKind.err }
                let data = if (msg.size > 2) { "" } else { "" }
                if (dev.broadcast_console_log_from_browser_to_server) {
                    match (kind) {
                        case ConsoleLogKind.log => Output.pretty("[browser] ${data}\n")
                        case ConsoleLogKind.err => Output.prettyError("[browser] ${data}\n")
                    }
                    Output.flush()
                }

            } else if (msgId == 114) { // 'r'
                let source_map_id = UInt64(0)

            } else { ws.close() }
        }
    }

    /// 取消订阅处理
    func onUnsubscribe(field: Int64): Unit {
        // 处理主题取消订阅
    }

    /// WebSocket 关闭回调
    public func onClose(ws: AnyWebSocket, exit_code: Int32, message: Array<Byte>): Unit {
        onUnsubscribe(subscriptions)

        if (inspector_connection_id > -1) {
            // 通知 inspector
        }

        if (let Some(old) <- active_route.unwrap()) {
            // dev.routeBundlePtr(old).active_viewers -= 1
        }

        referenced_source_maps.clear()
    }

    /// 通知 Inspector 客户端导航
    func notifyInspectorClientNavigation(pattern: String, rbi: IndexOptional): Unit {
        if (inspector_connection_id > -1) {
            // agent.notifyClientNavigated(...)
        }
    }
}

/// Unit type [KEPT: no-pkg - placeholder for void unit type]
public class UnitValue {
    public init() {}
}
