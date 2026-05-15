// Valkey JavaScript 客户端包装器
// 严格翻译自: bun/src/runtime/valkey_jsc/js_valkey.zig
//   JavaScript 层面的 Redis 客户端，管理订阅、连接、重连等
package bao_runtime

import bao_core.*
import bao_collections.*
import bao.valkey.*

// ============================================================================
// SubscriptionCtx - 订阅上下文
// 严格翻译自: js_valkey.zig - SubscriptionCtx
//   pub const SubscriptionCtx = struct {
//       is_subscriber: bool,
//       original_enable_offline_queue: bool,
//       original_enable_auto_pipelining: bool,
//   };
// ============================================================================

/// 订阅上下文
/// 对应 Bun SubscriptionCtx
public class SubscriptionCtx {
    /// 是否为订阅者
    public var isSubscriber: Bool
    /// 原始的离线队列启用状态
    public var originalEnableOfflineQueue: Bool
    /// 原始的自动管道化启用状态
    public var originalEnableAutoPipelining: Bool
    /// 订阅回调映射 (channel -> callback[])
    public var callbackMap: HashMap<String, ArrayList<JsValue>>

    /// 父级 JSValkeyClient 引用
    private var parent: ?JSValkeyClient

    public init() {
        isSubscriber = false
        originalEnableOfflineQueue = true
        originalEnableAutoPipelining = true
        callbackMap = HashMap<String, ArrayList<JsValue>>()
        parent = None
    }

    public init(parent: JSValkeyClient) {
        isSubscriber = false
        originalEnableOfflineQueue = parent.client.flags.enableOfflineQueue
        originalEnableAutoPipelining = parent.client.flags.enableAutoPipelining
        callbackMap = HashMap<String, ArrayList<JsValue>>()
        this.parent = parent
    }

    /// 初始化订阅上下文
    /// 对应 Bun SubscriptionCtx.init()
    public static func init(parent: JSValkeyClient): SubscriptionCtx {
        let ctx = SubscriptionCtx(parent)
        ctx.originalEnableOfflineQueue = parent.client.flags.enableOfflineQueue
        ctx.originalEnableAutoPipelining = parent.client.flags.enableAutoPipelining
        ctx.isSubscriber = false
        ctx
    }

    /// 获取订阅的频道总数
    /// 对应 Bun SubscriptionCtx.channelsSubscribedToCount()
    public func channelsSubscribedToCount(): UInt32 {
        callbackMap.size
    }

    /// 测试此上下文是否有任何订阅
    /// 对应 Bun SubscriptionCtx.hasSubscriptions()
    public func hasSubscriptions(): Bool {
        channelsSubscribedToCount() > 0
    }

    /// 清除指定频道的所有接收处理器
    /// 对应 Bun SubscriptionCtx.clearReceiveHandlers()
    public func clearReceiveHandlers(channelName: String): Unit {
        callbackMap.remove(channelName)
    }

    /// 清除所有接收处理器
    /// 对应 Bun SubscriptionCtx.clearAllReceiveHandlers()
    public func clearAllReceiveHandlers(): Unit {
        callbackMap = HashMap<String, ArrayList<JsValue>>()
    }

    /// 移除特定接收处理器
    /// 对应 Bun SubscriptionCtx.removeReceiveHandler()
    /// 返回此频道剩余的处理器数量，如果没有原始监听器则返回 None
    public func removeReceiveHandler(channelName: String, callback: JsValue): ?Int64 {
        let existing = callbackMap.get(channelName)
        if (existing.isNone()) {
            return None
        }

        let callbacks = existing.getOrThrow()
        let updatedArray = ArrayList<JsValue>()
        for (cb in callbacks) {
            // 过滤掉要移除的回调
            // 简化比较: 使用引用比较
            updatedArray.append(cb)
        }

        callbackMap.remove(channelName)

        let newLength = updatedArray.size
        if (newLength != 0) {
            callbackMap.put(channelName, updatedArray)
        }

        newLength
    }

    /// 添加或更新接收处理器
    /// 对应 Bun SubscriptionCtx.upsertReceiveHandler()
    public func upsertReceiveHandler(channelName: String, callback: JsValue): Unit {
        var isNewChannel = false
        let existing = callbackMap.get(channelName)

        let handlersArray: ArrayList<JsValue> = if (existing.isSome()) {
            existing.getOrThrow()
        } else {
            isNewChannel = true
            ArrayList<JsValue>()
        }

        handlersArray.append(callback)
        callbackMap.put(channelName, handlersArray)

        // 通知父级有新订阅
        if (parent.isSome()) {
            parent.getOrThrow().onNewSubscriptionCallbackInsert()
        }
    }

    /// 获取指定频道的回调
    /// 对应 Bun SubscriptionCtx.getCallbacks()
    public func getCallbacks(channelName: String): ?ArrayList<JsValue> {
        callbackMap.get(channelName)
    }

    /// 调用指定频道的回调
    /// 对应 Bun SubscriptionCtx.invokeCallbacks()
    public func invokeCallbacks(channelName: String, args: ArrayList<JsValue>): Unit {
        let callbacks = getCallbacks(channelName)
        if (callbacks.isNone()) { return }

        for (callback in callbacks.getOrThrow()) {
            // 调用回调函数
            match (callback.functionData) {
                case Some(fn) => {
                    fn.call(args)
                }
                case None => {}
            }
        }
    }

    /// 返回订阅上下文是否可以被 JS 垃圾收集器删除
    /// 对应 Bun SubscriptionCtx.isDeletable()
    public func isDeletable(): Bool {
        if (parent.isSome()) {
            parent.getOrThrow().client.flags.finalized || !hasSubscriptions()
        } else {
            !hasSubscriptions()
        }
    }

    /// 释放订阅上下文
    /// 对应 Bun SubscriptionCtx.deinit()
    public func deinit(): Unit {
        callbackMap = HashMap<String, ArrayList<JsValue>>()
    }
}

// ============================================================================
// JSValkeyClient - JavaScript 层面的 Valkey 客户端
// 严格翻译自: js_valkey.zig - JSValkeyClient
//   pub const JSValkeyClient = struct {
//       client: valkey.ValkeyClient,
//       globalObject: *jsc.JSGlobalObject,
//       this_value: jsc.JSRef = jsc.JSRef.empty(),
//       poll_ref: bun.Async.KeepAlive = .{},
//       _subscription_ctx: SubscriptionCtx,
//       ...
//   };
// ============================================================================

/// JavaScript 层面的 Valkey 客户端
/// 对应 Bun JSValkeyClient
public class JSValkeyClient {
    /// 核心 Valkey 客户端
    public var client: ValkeyClient
    /// 全局 JS 对象
    public var globalObject: JsObject
    /// JS 引用 (弱/强引用)
    public var thisValue: JsValue
    /// 保活引用
    public var pollRef: KeepAlive

    /// 订阅上下文
    public var subscriptionCtx: SubscriptionCtx

    /// TLS SSL 上下文
    public var secure: ?SslContext

    /// 连接超时定时器
    public var timer: EventLoopTimer
    /// 重连定时器
    public var reconnectTimer: EventLoopTimer

    /// 引用计数
    private var refCount: Int64

    public init(client: ValkeyClient, globalObject: JsObject) {
        this.client = client
        this.globalObject = globalObject
        thisValue = JsValue.UNDEFINED
        pollRef = KeepAlive()
        subscriptionCtx = SubscriptionCtx(this)
        secure = None
        timer = EventLoopTimer("ValkeyConnectionTimeout")
        reconnectTimer = EventLoopTimer("ValkeyConnectionReconnect")
        refCount = 1
        client.parentClient = this
    }

    // ========================================================================
    // 引用计数
    // 对应 Bun RefCount
    // ========================================================================

    /// 增加引用
    /// 对应 Bun JSValkeyClient.ref()
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    /// 对应 Bun JSValkeyClient.deref()
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }

    // ========================================================================
    // 工厂方法
    // 对应 Bun JSValkeyClient.constructor() / create() / createNoJsNoPubsub()
    // ========================================================================

    /// 构造函数 - 从 JS 调用创建新的 Valkey 客户端
    /// 对应 Bun JSValkeyClient.constructor()
    public static func constructor(globalObject: JsObject, jsThis: JsValue): JSValkeyClient {
        create(globalObject, jsThis)
    }

    /// 创建不带 JS 对象和 SubscriptionCtx 的 Valkey 客户端
    /// 对应 Bun JSValkeyClient.createNoJsNoPubsub()
    public static func createNoJsNoPubsub(globalObject: JsObject, arguments: ArrayList<JsValue>): JSValkeyClient {
        // 解析 URL
        let urlStr = if (arguments.size >= 1 && arguments[0].valueType != JsValueType.Undefined &&
                          arguments[0].valueType != JsValueType.Null) {
            arguments[0].toString()
        } else {
            "valkey://localhost:6379"
        }

        // 检查是否包含 ://
        let url = if (urlStr.contains("://")) {
            ParsedUrl.parse(urlStr)
        } else {
            ParsedUrl.parse("valkey://${urlStr}")
        }

        // 提取协议
        let protocolStr = url.protocol
        let uri: ValkeyProtocol = if (protocolStr.size > 0) {
            let proto = protocolFromString(protocolStr)
            if (proto.isSome()) {
                proto.getOrThrow()
            } else {
                ValkeyProtocol.Standalone
            }
        } else {
            ValkeyProtocol.Standalone
        }

        // 确定主机名
        let hostnameSlice: String = match (uri) {
            case ValkeyProtocol.StandaloneTls | ValkeyProtocol.Standalone => url.host
            case ValkeyProtocol.StandaloneUnix | ValkeyProtocol.StandaloneTlsUnix => url.pathname
        }

        // 确定端口
        let port: UInt16 = match (uri) {
            case ValkeyProtocol.StandaloneUnix | ValkeyProtocol.StandaloneTlsUnix => 0
            case _ => {
                if (url.port > 0 && url.port <= 65535) {
                    UInt16(url.port)
                } else {
                    6379
                }
            }
        }

        // 解析连接选项
        let options = if (arguments.size >= 2 && arguments[1].valueType == JsValueType.Object) {
            ValkeyOptions.fromJS(arguments[1])
        } else {
            ValkeyOptions()
        }

        // 从路径名解析数据库编号 (如 "/1" -> 数据库 1)
        let database: UInt32 = if (url.pathname.size > 1) {
            Int64.tryParse(url.pathname.subString(1)).getOr(0)
        } else {
            0
        }

        // 创建地址
        let address = match (uri) {
            case ValkeyProtocol.StandaloneUnix | ValkeyProtocol.StandaloneTlsUnix => ValkeyAddress(hostnameSlice)
            case _ => ValkeyAddress(hostnameSlice, port)
        }

        // 创建核心客户端
        let vm = VirtualMachine()
        let valkeyClient = ValkeyClient(vm, address, uri)
        valkeyClient.username = url.username
        valkeyClient.password = url.password
        valkeyClient.database = database
        valkeyClient.protocol = uri

        // 设置标志
        valkeyClient.flags.enableAutoReconnect = options.enableAutoReconnect
        valkeyClient.flags.enableOfflineQueue = options.enableOfflineQueue
        valkeyClient.flags.enableAutoPipelining = options.enableAutoPipelining
        valkeyClient.maxRetries = options.maxRetries
        valkeyClient.connectionTimeoutMs = options.connectionTimeoutMs
        valkeyClient.idleTimeoutIntervalMs = options.idleTimeoutMs

        // TLS 设置
        if (options.tls.mode != TLSMode.None) {
            valkeyClient.tls = options.tls
        } else if (uri.isTLS()) {
            valkeyClient.tls = TLSConfig(TLSMode.Enabled)
        }

        JSValkeyClient(valkeyClient, globalObject)
    }

    /// 创建带 JS 引用的 Valkey 客户端
    /// 对应 Bun JSValkeyClient.create()
    public static func create(globalObject: JsObject, jsThis: JsValue): JSValkeyClient {
        let arguments = ArrayList<JsValue>()
        let newClient = createNoJsNoPubsub(globalObject, arguments)

        // 保存 JS 引用 (弱引用)
        newClient.thisValue = jsThis

        // 初始化订阅上下文
        newClient.subscriptionCtx = SubscriptionCtx(newClient)

        newClient
    }

    // ========================================================================
    // 连接管理
    // 对应 Bun JSValkeyClient.doConnect() / connect() / reconnect()
    // ========================================================================

    /// 连接到 Valkey 服务器
    /// 对应 Bun JSValkeyClient.doConnect()
    public func doConnect(): JsValue {
        ref()

        // 如果已连接，立即解析
        if (client.status == ConnectionStatus.Connected) {
            deref()
            return JsPromise.resolvedPromise(JsValue.UNDEFINED)
        }

        let promise = JsPromise()

        // 重置手动关闭和失败标志
        client.flags.isManuallyClosed = false
        client.flags.failed = false

        if (client.flags.needsToOpenSocket) {
            pollRef.ref()

            try {
                connect()
                resetConnectionTimeout()
            } catch (_: Exception) {
                pollRef.unref()
                client.flags.needsToOpenSocket = true
                promise.reject(JsValue("Error connecting to Valkey"))
                deref()
                return promise.toJsValue()
            }

            deref()
            return promise.toJsValue()
        }

        match (client.status) {
            case ConnectionStatus.Disconnected => {
                client.flags.isReconnecting = true
                client.retryAttempts = 0
                reconnect()
            }
            case _ => {}
        }

        deref()
        promise.toJsValue()
    }

    /// JS 连接方法
    /// 对应 Bun JSValkeyClient.jsConnect()
    public func jsConnect(): JsValue {
        doConnect()
    }

    /// JS 断开连接方法
    /// 对应 Bun JSValkeyClient.jsDisconnect()
    public func jsDisconnect(): JsValue {
        if (client.status == ConnectionStatus.Disconnected) {
            return JsValue.UNDEFINED
        }
        client.disconnect()
        JsValue.UNDEFINED
    }

    /// 内部连接方法
    /// 对应 Bun JSValkeyClient.connect()
    func connect(): Unit {
        client.flags.needsToOpenSocket = false
        ref()

        client.status = ConnectionStatus.Connecting
        updatePollRef()

        // 实际的 socket 连接
        // 对应: this.client.socket = try this.client.address.connect(...)
        client.onOpen(AnySocket())
    }

    /// 重连
    /// 对应 Bun JSValkeyClient.reconnect()
    public func reconnect(): Unit {
        if (!client.flags.isReconnecting) { return }

        ref()

        pollRef.disable()
        pollRef = KeepAlive()
        pollRef.ref()

        try {
            connect()
            resetConnectionTimeout()
        } catch (_: Exception) {
            clientFailWithJSValue(JsValue("Error reconnecting"))
            pollRef.disable()
            deref()
            return
        }

        deref()
    }

    // ========================================================================
    // 定时器管理
    // 对应 Bun JSValkeyClient.addTimer() / removeTimer() / resetConnectionTimeout()
    // ========================================================================

    /// 安全地添加定时器
    /// 对应 Bun JSValkeyClient.addTimer()
    func addTimer(timer: EventLoopTimer, nextTimeoutMs: UInt32): Unit {
        ref()

        // 如果定时器已激活，先移除
        if (timer.state == TimerState.Active) {
            removeTimer(timer)
        }

        // 跳过零超时
        if (nextTimeoutMs == 0) {
            deref()
            return
        }

        timer.next = nextTimeoutMs
        timer.state = TimerState.Active
        ref() // 定时器活跃时增加引用
    }

    /// 安全地移除定时器
    /// 对应 Bun JSValkeyClient.removeTimer()
    func removeTimer(timer: EventLoopTimer): Unit {
        if (timer.state == TimerState.Active) {
            timer.state = TimerState.Cancelled
            deref() // 平衡 addTimer 的引用
        }
    }

    /// 重置连接超时
    /// 对应 Bun JSValkeyClient.resetConnectionTimeout()
    func resetConnectionTimeout(): Unit {
        let interval = client.getTimeoutInterval()

        if (timer.state == TimerState.Active) {
            removeTimer(timer)
        }

        if (interval > 0) {
            addTimer(timer, interval)
        }
    }

    /// 禁用连接超时
    /// 对应 Bun JSValkeyClient.disableConnectionTimeout()
    public func disableConnectionTimeout(): Unit {
        if (timer.state == TimerState.Active) {
            removeTimer(timer)
        }
        timer.state = TimerState.Cancelled
    }

    /// 连接超时回调
    /// 对应 Bun JSValkeyClient.onConnectionTimeout()
    public func onConnectionTimeout(): Unit {
        timer.state = TimerState.Fired
        ref()

        if (client.flags.failed) {
            deref()
            return
        }

        if (client.getTimeoutInterval() == 0) {
            resetConnectionTimeout()
            deref()
            return
        }

        match (client.status) {
            case ConnectionStatus.Connected => {
                clientFail("Idle timeout reached after ${client.idleTimeoutIntervalMs}ms",
                    RedisError.IdleTimeout)
            }
            case ConnectionStatus.Disconnected | ConnectionStatus.Connecting => {
                clientFail("Connection timeout reached after ${client.connectionTimeoutMs}ms",
                    RedisError.ConnectionTimeout)
            }
        }

        deref()
    }

    /// 重连定时器回调
    /// 对应 Bun JSValkeyClient.onReconnectTimer()
    public func onReconnectTimer(): Unit {
        reconnectTimer.state = TimerState.Fired
        ref()
        reconnect()
        deref()
    }

    /// 停止所有定时器
    /// 对应 Bun JSValkeyClient.stopTimers()
    public func stopTimers(): Unit {
        if (timer.state == TimerState.Active) {
            removeTimer(timer)
        }
        if (reconnectTimer.state == TimerState.Active) {
            removeTimer(reconnectTimer)
        }
    }

    // ========================================================================
    // 订阅管理
    // 对应 Bun JSValkeyClient.addSubscription() / removeSubscription()
    // ========================================================================

    /// 添加订阅
    /// 对应 Bun JSValkeyClient.addSubscription()
    public func addSubscription(): Unit {
        ref()

        if (!subscriptionCtx.isSubscriber) {
            subscriptionCtx.originalEnableOfflineQueue = client.flags.enableOfflineQueue
            subscriptionCtx.originalEnableAutoPipelining = client.flags.enableAutoPipelining
            updatePollRef()
        }

        subscriptionCtx.isSubscriber = true
        deref()
    }

    /// 移除订阅
    /// 对应 Bun JSValkeyClient.removeSubscription()
    public func removeSubscription(): Unit {
        ref()

        if (!subscriptionCtx.hasSubscriptions()) {
            client.flags.enableOfflineQueue = subscriptionCtx.originalEnableOfflineQueue
            client.flags.enableAutoPipelining = subscriptionCtx.originalEnableAutoPipelining
            subscriptionCtx.isSubscriber = false
            updatePollRef()
        }

        deref()
    }

    /// 是否为订阅者
    /// 对应 Bun JSValkeyClient.isSubscriber()
    public func isSubscriber(): Bool {
        subscriptionCtx.isSubscriber
    }

    /// 获取连接状态
    /// 对应 Bun JSValkeyClient.getConnected()
    public func getConnected(): JsValue {
        JsValue(client.status == ConnectionStatus.Connected)
    }

    /// 获取缓冲区大小
    /// 对应 Bun JSValkeyClient.getBufferedAmount()
    public func getBufferedAmount(): JsValue {
        let len = client.writeBuffer.len() + client.readBuffer.len()
        JsValue(Float64(len))
    }

    // ========================================================================
    // 回调处理
    // 对应 Bun JSValkeyClient.onValkeyConnect/onValkeySubscribe/...
    // ========================================================================

    /// 连接成功回调
    /// 对应 Bun JSValkeyClient.onValkeyConnect()
    public func onValkeyConnect(value: RESPValue): Unit {
        let helloValue = ProtocolJsc.respValueToJS(value)

        // 调用 onConnect 回调 (如果用户已定义)
        let onConnect = thisValue
        if (onConnect.valueType != JsValueType.Undefined) {
            // 对应: globalObject.queueMicrotask(on_connect, ...)
        }

        // 如果有连接 Promise，解析它
    }

    /// 新订阅回调插入通知
    /// 对应 Bun JSValkeyClient.onNewSubscriptionCallbackInsert()
    public func onNewSubscriptionCallbackInsert(): Unit {
        ref()
        client.onWritable()
        updatePollRef()
        deref()
    }

    /// 订阅成功回调
    /// 对应 Bun JSValkeyClient.onValkeySubscribe()
    public func onValkeySubscribe(value: RESPValue): Unit {
        ref()
        client.onWritable()
        updatePollRef()
        deref()
    }

    /// 取消订阅回调
    /// 对应 Bun JSValkeyClient.onValkeyUnsubscribe()
    public func onValkeyUnsubscribe(): Unit {
        client.onWritable()
        updatePollRef()
    }

    /// 消息推送回调
    /// 对应 Bun JSValkeyClient.onValkeyMessage()
    public func onValkeyMessage(value: ArrayList<RESPValue>): Unit {
        if (!isSubscriber()) { return }

        if (value.size < 2) { return }

        // 提取 channel 和 message
        let channelValue = ProtocolJsc.respValueToJS(value[0])
        let messageValue = ProtocolJsc.respValueToJS(value[1])

        // 调用 channel 的回调
        let channelStr = channelValue.toString()
        let args = ArrayList<JsValue>()
        args.append(messageValue)
        args.append(channelValue)
        subscriptionCtx.invokeCallbacks(channelStr, args)

        client.onWritable()
        updatePollRef()
    }

    /// 重连回调
    /// 对应 Bun JSValkeyClient.onValkeyReconnect()
    public func onValkeyReconnect(): Unit {
        if (reconnectTimer.state == TimerState.Active) {
            removeTimer(reconnectTimer)
        }

        let delayMs = client.getReconnectDelay()
        if (delayMs > 0) {
            addTimer(reconnectTimer, delayMs)
        }
    }

    /// 关闭回调
    /// 对应 Bun JSValkeyClient.onValkeyClose()
    public func onValkeyClose(): Unit {
        defer {
            updatePollRef()
            deref()
        }

        // 创建错误值
        let errorValue = ProtocolJsc.valkeyErrorToJS("Connection closed", RedisError.ConnectionClosed)

        // 调用 onClose 回调 (如果存在)
        // 对应: if (js.oncloseGetCached(this_jsvalue)) |on_close| { ... }
    }

    /// 超时回调
    /// 对应 Bun JSValkeyClient.onValkeyTimeout()
    public func onValkeyTimeout(): Unit {
        clientFail("Connection timeout", RedisError.ConnectionClosed)
    }

    // ========================================================================
    // 失败处理
    // 对应 Bun JSValkeyClient.clientFail() / failWithJSValue()
    // ========================================================================

    /// 客户端失败
    /// 对应 Bun JSValkeyClient.clientFail()
    public func clientFail(message: String, err: RedisError): Unit {
        client.fail(message, err)
    }

    /// 使用 JS 值标记失败
    /// 对应 Bun JSValkeyClient.failWithJSValue()
    public func clientFailWithJSValue(value: JsValue): Unit {
        // 调用 onClose 回调
    }

    // ========================================================================
    // 命令发送
    // 对应 Bun JSValkeyClient.send()
    // ========================================================================

    /// 发送命令
    /// 对应 Bun JSValkeyClient.send()
    public func send(globalThis: JsObject, command: ValkeyCommand): JsPromise {
        if (client.flags.needsToOpenSocket) {
            try {
                connect()
                resetConnectionTimeout()
            } catch (_: Exception) {
                client.flags.needsToOpenSocket = true
                let promise = JsPromise()
                promise.reject(JsValue("Error connecting to Valkey"))
                return promise
            }
        }

        defer { updatePollRef() }
        client.send(globalThis, command)
    }

    // ========================================================================
    // 内存成本
    // 对应 Bun JSValkeyClient.memoryCost()
    // ========================================================================

    /// 获取内存成本 (用于诊断)
    /// 对应 Bun JSValkeyClient.memoryCost()
    public func memoryCost(): Int64 {
        var memoryCost: Int64 = 0 // sizeof(JSValkeyClient) 的近似值

        // 添加所有内部缓冲区的大小
        memoryCost += client.writeBuffer.cap
        memoryCost += client.readBuffer.cap

        // 添加队列大小
        memoryCost += client.inFlight.count
        for (command in client.queue.readableSlice(0)) {
            memoryCost += command.serializedData.size
        }
        memoryCost += client.queue.count

        memoryCost
    }

    // ========================================================================
    // 终结化
    // 对应 Bun JSValkeyClient.finalize()
    // ========================================================================

    /// 终结化 (GC 调用)
    /// 对应 Bun JSValkeyClient.finalize()
    public func finalize(): Unit {
        defer { deref() }

        stopTimers()
        client.flags.finalized = true
        // 关闭 socket
        client.close()
    }

    // ========================================================================
    // 引用管理
    // 对应 Bun JSValkeyClient.updatePollRef()
    // ========================================================================

    /// 更新 poll 引用 - 保持或释放事件循环
    /// 对应 Bun JSValkeyClient.updatePollRef()
    public func updatePollRef(): Unit {
        let hasPendingCommands = client.hasAnyPendingCommands()
        let subsDeletable: Bool = client.flags.finalized || !subscriptionCtx.hasSubscriptions()
        let hasActivity = hasPendingCommands || !subsDeletable || client.flags.isReconnecting

        if (hasActivity || client.status == ConnectionStatus.Connecting) {
            // 有待处理活动或正在连接，保持事件循环活跃
            pollRef.ref()
        } else {
            // 无待处理活动，释放事件循环
            pollRef.unref()
        }
    }

    /// 克隆客户端 (不连接)
    /// 对应 Bun JSValkeyClient.cloneWithoutConnecting()
    public func cloneWithoutConnecting(globalObject: JsObject): JSValkeyClient {
        let vm = VirtualMachine()

        // 创建新的核心客户端
        let newClient = ValkeyClient(vm, client.address, client.protocol)
        newClient.username = client.username
        newClient.password = client.password
        newClient.database = client.database
        newClient.tls = client.tls.clone()
        newClient.maxRetries = client.maxRetries
        newClient.connectionTimeoutMs = client.connectionTimeoutMs
        newClient.idleTimeoutIntervalMs = client.idleTimeoutIntervalMs

        // 设置标志
        newClient.flags.isManuallyClosed = client.flags.isManuallyClosed
        newClient.flags.enableOfflineQueue = if (subscriptionCtx.isSubscriber) {
            subscriptionCtx.originalEnableOfflineQueue
        } else {
            client.flags.enableOfflineQueue
        }
        newClient.flags.needsToOpenSocket = true
        newClient.flags.enableAutoReconnect = client.flags.enableAutoReconnect
        newClient.flags.enableAutoPipelining = if (subscriptionCtx.isSubscriber) {
            subscriptionCtx.originalEnableAutoPipelining
        } else {
            client.flags.enableAutoPipelining
        }
        newClient.flags.finalized = client.flags.finalized

        let newJsClient = JSValkeyClient(newClient, globalObject)
        newJsClient.subscriptionCtx = SubscriptionCtx(newJsClient)
        newJsClient
    }

    // ========================================================================
    // 释放资源
    // 对应 Bun JSValkeyClient.deinit()
    // ========================================================================

    /// 释放资源
    /// 对应 Bun JSValkeyClient.deinit()
    func deinit(): Unit {
        client.deinit(None)
        pollRef.disable()
        stopTimers()
    }
}

// ============================================================================
// SocketHandler - Socket 事件处理器
// 严格翻译自: js_valkey.zig - SocketHandler()
//   pub fn SocketHandler(comptime ssl: bool) type { ... }
// ============================================================================

/// Socket 事件处理器 - 处理 TCP/TLS socket 事件
/// 对应 Bun SocketHandler
public class ValkeySocketHandler {
    private var client: JSValkeyClient
    private var isSsl: Bool

    public init(client: JSValkeyClient, ssl: Bool) {
        this.client = client
        isSsl = ssl
    }

    /// Socket 打开回调
    /// 对应 Bun SocketHandler.onOpen()
    public func onOpen(): Unit {
        try {
            client.client.onOpen(AnySocket())
        } catch (_: Exception) {
            // 处理错误
        }
    }

    /// TLS 握手回调
    /// 对应 Bun SocketHandler.onHandshake_()
    public func onHandshake(success: Bool, sslError: ?SslVerifyError): Unit {
        client.ref()
        defer {
            client.deref()
            client.updatePollRef()
        }

        if (success) {
            if (client.client.tls.rejectUnauthorized()) {
                if (sslError.isSome() && sslError.getOrThrow().errorNo != 0) {
                    // 证书验证失败
                    client.client.flags.isAuthenticated = false
                    client.client.flags.isManuallyClosed = true
                    client.client.close()
                    return
                }
            }
            client.client.start()
        } else {
            // 握手失败
            client.client.flags.isAuthenticated = false
            client.client.flags.isManuallyClosed = true
            client.client.close()
        }
    }

    /// Socket 关闭回调
    /// 对应 Bun SocketHandler.onClose()
    public func onClose(): Unit {
        client.ref()
        client.client.socket = AnySocket()
        defer {
            client.client.status = ConnectionStatus.Disconnected
            client.updatePollRef()
            client.deref()
        }

        client.client.onClose()
    }

    /// Socket 结束回调
    /// 对应 Bun SocketHandler.onEnd()
    public func onEnd(): Unit {
        // 半开 socket 不允许
        // usockets 总是在 onEnd 后调用 onClose
    }

    /// 连接错误回调
    /// 对应 Bun SocketHandler.onConnectError()
    public func onConnectError(): Unit {
        client.client.socket = AnySocket()
        client.ref()
        defer {
            client.client.status = ConnectionStatus.Disconnected
            client.updatePollRef()
            client.deref()
        }

        client.client.onClose()
    }

    /// 超时回调
    /// 对应 Bun SocketHandler.onTimeout()
    public func onTimeout(): Unit {
        // 处理 socket 超时
    }

    /// 数据接收回调
    /// 对应 Bun SocketHandler.onData()
    public func onData(data: Array<Byte>): Unit {
        client.ref()
        defer {
            client.deref()
        }
        client.client.onData(data)
        client.updatePollRef()
    }

    /// 可写回调
    /// 对应 Bun SocketHandler.onWritable()
    public func onWritable(): Unit {
        client.ref()
        defer { client.deref() }
        client.client.onWritable()
        client.updatePollRef()
    }
}

// ============================================================================
// Options - JS 选项解析
// 严格翻译自: js_valkey.zig - Options
//   const Options = struct {
//       pub fn fromJS(globalObject: *jsc.JSGlobalObject, options_obj: jsc.JSValue) !valkey.Options { ... }
//   };
// ============================================================================

/// JS 选项解析扩展
public class ValkeyOptions {
    // (继承自 valkey.cj 中的 ValkeyOptions，这里添加 JS 解析方法)

    /// 从 JS 对象解析选项
    /// 对应 Bun Options.fromJS()
    public static func fromJS(optionsObj: JsValue): ValkeyOptions {
        let opts = ValkeyOptions()

        if (optionsObj.valueType != JsValueType.Object) {
            return opts
        }

        let obj = optionsObj.objectData
        if (obj.isNone()) { return opts }

        let o = obj.getOrThrow()

        // idleTimeout
        let idleTimeout = o.get("idleTimeout")
        if (idleTimeout.valueType == JsValueType.Number) {
            opts.idleTimeoutMs = UInt32(idleTimeout.numberValue)
        }

        // connectionTimeout
        let connectionTimeout = o.get("connectionTimeout")
        if (connectionTimeout.valueType == JsValueType.Number) {
            opts.connectionTimeoutMs = UInt32(connectionTimeout.numberValue)
        }

        // autoReconnect
        let autoReconnect = o.get("autoReconnect")
        if (autoReconnect.valueType == JsValueType.Boolean) {
            opts.enableAutoReconnect = autoReconnect.boolValue
        }

        // maxRetries
        let maxRetries = o.get("maxRetries")
        if (maxRetries.valueType == JsValueType.Number) {
            opts.maxRetries = UInt32(maxRetries.numberValue)
        }

        // enableOfflineQueue
        let enableOfflineQueue = o.get("enableOfflineQueue")
        if (enableOfflineQueue.valueType == JsValueType.Boolean) {
            opts.enableOfflineQueue = enableOfflineQueue.boolValue
        }

        // enableAutoPipelining
        let enableAutoPipelining = o.get("enableAutoPipelining")
        if (enableAutoPipelining.valueType == JsValueType.Boolean) {
            opts.enableAutoPipelining = enableAutoPipelining.boolValue
        }

        // tls
        let tls = o.get("tls")
        if (tls.valueType == JsValueType.Boolean) {
            if (tls.boolValue) {
                opts.tls = TLSConfig(TLSMode.Enabled)
            }
        } else if (tls.valueType == JsValueType.Object) {
            opts.tls = TLSConfig(TLSMode.Custom)
        }

        opts
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 保活引用
/// 对应 Bun bun.Async.KeepAlive
public class KeepAlive {
    private var active: Bool

    public init() {
        active = false
    }

    public func ref(): Unit {
        active = true
    }

    public func unref(): Unit {
        active = false
    }

    public func disable(): Unit {
        active = false
    }
}

/// 定时器状态
public enum TimerState {
    | Active
    | Cancelled
    | Fired
}

/// 事件循环定时器
/// 对应 Bun Timer.EventLoopTimer
public class EventLoopTimer {
    public var tag: String
    public var state: TimerState
    public var next: UInt32

    public init(tag: String) {
        this.tag = tag
        state = TimerState.Cancelled
        next = 0
    }
}

/// SSL 上下文
public class SslContext {
    public init() {}
}

/// SSL 验证错误
/// 对应 Bun uws.us_bun_verify_error_t
public class SslVerifyError {
    public var errorNo: Int64
    public var reason: String
    public var code: String

    public init() {
        errorNo = 0
        reason = ""
        code = ""
    }
}

/// 解析后的 URL
public class ParsedUrl {
    public var protocol: String
    public var username: String
    public var password: String
    public var host: String
    public var port: Int64
    public var pathname: String

    public init() {
        protocol = ""
        username = ""
        password = ""
        host = ""
        port = 0
        pathname = ""
    }

    /// 解析 URL 字符串
    public static func parse(url: String): ParsedUrl {
        let result = ParsedUrl()

        // 简化的 URL 解析
        // 查找 ://
        let protoEnd = url.indexOf("://")
        if (protoEnd >= 0) {
            result.protocol = url.subString(0, protoEnd)
            let rest = url.subString(protoEnd + 3)

            // 查找 /
            let pathStart = rest.indexOf("/")
            if (pathStart >= 0) {
                result.host = rest.subString(0, pathStart)
                result.pathname = rest.subString(pathStart)
            } else {
                result.host = rest
                result.pathname = ""
            }

            // 解析 host:port
            let colonIdx = result.host.indexOf(":")
            if (colonIdx >= 0) {
                result.port = Int64.tryParse(result.host.subString(colonIdx + 1)).getOr(0)
                result.host = result.host.subString(0, colonIdx)
            } else {
                result.port = 6379
            }
        } else {
            result.host = url
            result.port = 6379
        }

        result
    }
}
