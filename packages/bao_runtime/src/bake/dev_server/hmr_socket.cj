// 翻译自 Bun: src/runtime/bake/DevServer/HmrSocket.zig
// HMR WebSocket 连接处理器。处理客户端与服务器的热模块重载通信。

package bao_runtime.bake.dev_server

/// HMR Socket - WebSocket 连接处理器
public class HmrSocket {
    public var dev: DevServer
    public var underlying: ?AnyWebSocket = None
    public var subscriptions: HmrTopic.Bits
    /// 允许检查或修改敏感 DevServer 状态的操作
    public var is_from_localhost: Bool
    /// 告知 DevServer 活跃路由，从而接收路由更新的详细 hot_update 事件
    public var active_route: RouteBundle.Index.Optional
    /// 引用的源映射
    public var referenced_source_maps: AutoHashMapUnmanaged<SourceMapStore.Key, Unit>
    /// Inspector 连接 ID
    public var inspector_connection_id: Int32 = -1

    /// 创建新的 HMR Socket
    public static func new(dev: DevServer, res: Any): HmrSocket {
        let is_localhost = if (let Some(addr) = res.getRemoteSocketInfo()) {
            if (addr.is_ipv6) {
                bun.strings.eqlComptime(addr.ip, "::1")
            } else {
                bun.strings.eqlComptime(addr.ip, "127.0.0.1")
            }
        } else {
            false
        }
        return HmrSocket(
            dev: dev,
            is_from_localhost: is_localhost,
            subscriptions: HmrTopic.Bits(),
            active_route: RouteBundle.Index.Optional.none,
            referenced_source_maps: AutoHashMapUnmanaged<SourceMapStore.Key, Unit>.empty,
        )
    }

    /// WebSocket 打开回调
    public func onOpen(ws: AnyWebSocket): Unit {
        let send_status = ws.send([MessageId.version.char()] ++ dev.configuration_hash_key, .binary, false, true)
        underlying = ws

        if (send_status != .dropped) {
            // 通知 inspector 客户端连接
            if (let Some(agent) = dev.inspector()) {
                inspector_connection_id = agent.nextConnectionID()
                agent.notifyClientConnected(dev.inspector_server_id, inspector_connection_id)
            }
        }
    }

    /// WebSocket 消息回调
    public func onMessage(ws: AnyWebSocket, msg: Array<Byte>, opcode: Opcode): Unit {
        if (msg.length == 0) {
            return ws.close()
        }

        match (IncomingMessageId(msg[0])) {
            case init =>
                if (msg.length != 9) { return ws.close() }
                var generation: UInt32
                // 解析十六进制生成 ID
                let source_map_id = SourceMapStore.Key.init(UInt64(generation) << 32)
                if (dev.source_maps.removeOrUpgradeWeakRef(source_map_id, .upgrade)) {
                    referenced_source_maps.put(dev.allocator(), source_map_id, Unit())
                }

            case subscribe =>
                var new_bits: HmrTopic.Bits = HmrTopic.Bits()
                let topics = msg.slice(1)
                if (topics.length > HmrTopic.max_count) { return }
                for (char in topics) {
                    // 匹配主题字符
                }
                // 更新订阅
                onUnsubscribe(bun.bits.and(HmrTopic.Bits, bun.bits.invert(HmrTopic.Bits, new_bits), subscriptions))
                subscriptions = new_bits

            case set_url =>
                let pattern = msg.slice(1)
                let maybe_rbi = dev.routeToBundleIndexSlow(pattern)
                if (let Some(agent) = dev.inspector()) {
                    if (inspector_connection_id > -1) {
                        agent.notifyClientNavigated(dev.inspector_server_id, inspector_connection_id, pattern, maybe_rbi)
                    }
                }
                let rbi = maybe_rbi ?? return
                if (let Some(old) = active_route.unwrap()) {
                    if (old == rbi) { return }
                    dev.routeBundlePtr(old).active_viewers -= 1
                }
                dev.routeBundlePtr(rbi).active_viewers += 1
                active_route = rbi.toOptional()
                var response: Array<Byte> = [MessageId.set_url_response.char()] ++ toBytes(rbi.get())
                ws.send(response, .binary, false, true)

            case testing_batch_events =>
                match (dev.testing_batch_events) {
                    case disabled =>
                        if (dev.current_bundle != None) {
                            dev.testing_batch_events = .enable_after_bundle
                        } else {
                            dev.testing_batch_events = .enabled(TestingBatch.empty)
                            dev.publish(.testing_watch_synchronization, [MessageId.testing_watch_synchronization.char(), 0], .binary)
                        }
                    case enable_after_bundle =>
                        ws.close()
                    case enabled(let event_const) =>
                        var event = event_const
                        dev.testing_batch_events = .disabled
                        if (event.entry_points.set.count() == 0) {
                            dev.publish(.testing_watch_synchronization, [MessageId.testing_watch_synchronization.char(), 2], .binary)
                            return
                        }
                        dev.startAsyncBundle(event.entry_points, true, Timer.start())
                        event.entry_points.deinit(dev.allocator())
                }

            case console_log =>
                if (msg.length < 2) {
                    ws.close()
                    return
                }
                let kind: ConsoleLogKind = match (msg[1]) {
                    case 'l' => .log
                    case 'e' => .err
                    case _ => { ws.close(); return }
                }
                let data = msg.slice(2)
                if (dev.broadcast_console_log_from_browser_to_server) {
                    match (kind) {
                        case log => Output.pretty("[browser] ${data}\n")
                        case err => Output.prettyError("[browser] ${data}\n")
                    }
                    Output.flush()
                }

            case unref_source_map =>
                let source_map_id = SourceMapStore.Key.init(/* 从消息解析 u64 */)
                let kv = referenced_source_maps.fetchRemove(source_map_id) ?? return
                dev.source_maps.unref(kv.key)

            case _ => ws.close()
        }
    }

    /// 取消订阅处理
    func onUnsubscribe(field: HmrTopic.Bits): Unit {
        // 处理主题取消订阅
    }

    /// WebSocket 关闭回调
    public func onClose(ws: AnyWebSocket, exit_code: Int32, message: Array<Byte>): Unit {
        onUnsubscribe(subscriptions)

        if (inspector_connection_id > -1) {
            if (let Some(agent) = dev.inspector()) {
                agent.notifyClientDisconnected(dev.inspector_server_id, inspector_connection_id)
            }
        }

        if (let Some(old) = active_route.unwrap()) {
            dev.routeBundlePtr(old).active_viewers -= 1
        }

        for (key in referenced_source_maps.keyIterator()) {
            dev.source_maps.unref(key)
        }
        referenced_source_maps.deinit(dev.allocator())
        assert(dev.active_websocket_connections.remove(this))
        dev.allocator().destroy(this)
    }

    /// 通知 Inspector 客户端导航
    func notifyInspectorClientNavigation(pattern: String, rbi: RouteBundle.Index.Optional): Unit {
        if (inspector_connection_id > -1) {
            if (let Some(agent) = dev.inspector()) {
                agent.notifyClientNavigated(dev.inspector_server_id, inspector_connection_id, pattern, rbi.unwrap())
            }
        }
    }
}

// 类型别名
public type AnyWebSocket = bun.uws.AnyWebSocket
public type Opcode = bun.uws.Opcode
public type AutoHashMapUnmanaged<K, V> = std.AutoHashMapUnmanaged<K, V>
public type RouteBundle = dev_server.RouteBundle
public type SourceMapStore = dev_server.SourceMapStore
public type TestingBatch = dev_server.TestingBatch
