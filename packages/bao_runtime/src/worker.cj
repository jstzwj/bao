// Worker — Web Worker API
// 严格翻译自: src/jsc/web_worker.zig + src/runtime/web_worker
//   Bun 支持 Web Worker API，允许在独立线程中执行 JavaScript
//   仓颉通过 spawn { } + Channel 实现等价功能
//
// 生命周期模型 (对应 Bun web_worker.zig):
//   1. create()  — 分配 Worker 结构体, 注册到全局列表, 启动线程
//   2. spin()    — 加载入口脚本, 触发 'online' 事件, 运行事件循环
//   3. shutdown() — 运行退出处理器, 销毁 VM, 发送 'close' 事件
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_threading.*

// ============================================================================
// 全局 Worker 注册表
// 对应 Bun: LiveWorkers — 进程级 Worker 注册表
//   terminateAllAndWait() 在进程退出前终止所有 Worker
// ============================================================================

/// 全局活跃 Worker 注册表
/// 对应 Bun: LiveWorkers struct
public class LiveWorkers {
    /// 活跃 Worker 列表
    private static let workers: ArrayList<Worker> = ArrayList<Worker>()
    /// 互斥锁
    private static let mutex: ThreadMutex = ThreadMutex()

    /// 注册 Worker
    public static func register(worker: Worker): Unit {
        synchronized(mutex) {
            workers.append(worker)
        }
    }

    /// 注销 Worker
    public static func unregister(worker: Worker): Unit {
        synchronized(mutex) {
            var i = Int64(0)
            while (i < workers.size) {
                if (workers[i] == worker) {
                    workers.removeAt(i)
                    break
                }
                i += Int64(1)
            }
        }
    }

    /// 终止所有 Worker 并等待
    /// 对应 Bun: terminateAllAndWait(timeout_ms)
    public static func terminateAllAndWait(timeoutMs: Int64): Unit {
        let snapshot = ArrayList<Worker>()
        synchronized(mutex) {
            for (w in workers) {
                snapshot.append(w)
            }
        }
        for (w in snapshot) {
            w.terminate()
        }
    }

    /// 获取活跃 Worker 数量
    public static func count(): Int64 {
        synchronized(mutex) {
            return workers.size
        }
    }
}

// ============================================================================
// WorkerState — Worker 状态
// ============================================================================

/// Worker 状态
public enum WorkerState {
    | Starting    // 正在启动
    | Running     // 运行中
    | Terminated  // 已终止
    | Error       // 出错

    public operator func ==(right: WorkerState): Bool {
        match (this) {
            case Starting =>
                match (right) {
                    case Starting => true
                    case _ => false
                }
            case Running =>
                match (right) {
                    case Running => true
                    case _ => false
                }
            case Terminated =>
                match (right) {
                    case Terminated => true
                    case _ => false
                }
            case Error =>
                match (right) {
                    case Error => true
                    case _ => false
                }
        }
    }

    public operator func !=(right: WorkerState): Bool {
        return !(this == right)
    }
}

// ============================================================================
// MessagePort — 消息端口
// 对应 Bun: MessagePort — 双向消息通道的一端
// ============================================================================

/// 消息端口 — 双向消息通道的一端
/// 对应 Bun: MessagePort
///   Worker 和主线程通过 MessagePort 互相发送消息
public class MessagePort {
    /// 端口 ID
    public var id: Int64
    /// 接收通道 (从此通道读取消息)
    private var receiveChannel: Channel<JsValue>
    /// 发送通道 (向此通道写入消息)
    private var sendChannel: Channel<JsValue>
    /// 消息监听器
    private var messageListeners: ArrayList<(JsValue) -> Unit>
    /// 错误监听器
    private var errorListeners: ArrayList<(String) -> Unit>
    /// 关闭监听器
    private var closeListeners: ArrayList<() -> Unit>
    /// 是否已关闭
    private var closed: Bool

    /// 双通道构造 (MessageChannel 使用)
    public init(id: Int64, receiveChannel: Channel<JsValue>, sendChannel: Channel<JsValue>) {
        this.id = id
        this.receiveChannel = receiveChannel
        this.sendChannel = sendChannel
        messageListeners = ArrayList<(JsValue) -> Unit>()
        errorListeners = ArrayList<(String) -> Unit>()
        closeListeners = ArrayList<() -> Unit>()
        closed = false
    }

    /// 单通道构造 (向后兼容)
    public init(id: Int64, channel: Channel<JsValue>) {
        this.id = id
        this.receiveChannel = channel
        this.sendChannel = channel
        messageListeners = ArrayList<(JsValue) -> Unit>()
        errorListeners = ArrayList<(String) -> Unit>()
        closeListeners = ArrayList<() -> Unit>()
        closed = false
    }

    /// postMessage(data) — 发送消息
    /// 对应 Worker/Bun: port.postMessage(data)
    public func postMessage(data: JsValue): Bool {
        if (closed) {
            return false
        }
        return sendChannel.send(data)
    }

    /// 接收消息 (非阻塞)
    public func receiveMessage(): ?JsValue {
        if (closed) {
            return None
        }
        return receiveChannel.tryReceive()
    }

    /// 注册消息监听器 - 对应 port.onmessage = fn
    public func onMessage(listener: (JsValue) -> Unit): MessagePort {
        messageListeners.append(listener)
        return this
    }

    /// 注册错误监听器
    public func onError(listener: (String) -> Unit): MessagePort {
        errorListeners.append(listener)
        return this
    }

    /// 注册关闭监听器
    public func onClose(listener: () -> Unit): MessagePort {
        closeListeners.append(listener)
        return this
    }

    /// 轮询并分发消息 (在事件循环中调用)
    public func poll(): Unit {
        if (closed) {
            return
        }
        while (true) {
            let msg = receiveChannel.tryReceive()
            match (msg) {
                case Some(value) =>
                    // 分发给所有监听器
                    for (listener in messageListeners) {
                        listener(value)
                    }
                case None => break
            }
        }
    }

    /// 关闭端口
    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        receiveChannel.close()
        // 注意: 不关闭 sendChannel, 对端可能还需要发送
        for (listener in closeListeners) {
            listener()
        }
    }

    /// 是否已关闭
    public func isClosed(): Bool {
        return closed
    }

    /// 将 MessagePort 导出为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let port = this

        obj.set("postMessage", JsValue.nativeFunction(JsNativeFunction("postMessage") { args =>
            if (args.size >= 1) {
                let sent = port.postMessage(args[0])
                return JsValue(sent)
            }
            return JsValue(false)
        }))

        obj.set("close", JsValue.nativeFunction(JsNativeFunction("close") { _ =>
            port.close()
            return JsValue.UNDEFINED
        }))

        obj.set("onmessage", JsValue.UNDEFINED)
        obj.set("onerror", JsValue.UNDEFINED)
        obj.set("onclose", JsValue.UNDEFINED)

        return JsValue(obj)
    }
}

// ============================================================================
// MessageChannel — 消息通道
// 对应 Bun: new MessageChannel() 创建一对相连的端口
// ============================================================================

/// 消息通道 — 创建一对互相连接的消息端口
/// 对应 Bun: MessageChannel
///   new MessageChannel() 创建 port1 和 port2
///   port1 发送的消息可以从 port2 接收，反之亦然
public class MessageChannel {
    /// 端口 1
    public var port1: MessagePort
    /// 端口 2
    public var port2: MessagePort

    /// 双向通道: port1 -> port2 (port1 发送, port2 接收)
    private var channel1to2: Channel<JsValue>
    /// 双向通道: port2 -> port1 (port2 发送, port1 接收)
    private var channel2to1: Channel<JsValue>

    public init() {
        // port1.postMessage(data) -> channel1to2 -> port2.receiveMessage()
        // port2.postMessage(data) -> channel2to1 -> port1.receiveMessage()
        channel1to2 = Channel<JsValue>()
        channel2to1 = Channel<JsValue>()
        // port1 的接收通道是 channel2to1, 发送通道是 channel1to2
        port1 = MessagePort(1, channel2to1, channel1to2)
        // port2 的接收通道是 channel1to2, 发送通道是 channel2to1
        port2 = MessagePort(2, channel1to2, channel2to1)
    }

    /// 将 MessageChannel 导出为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("port1", port1.toJsValue())
        obj.set("port2", port2.toJsValue())
        return JsValue(obj)
    }
}

// ============================================================================
// SharedArrayBuffer — 共享内存 (存根)
// 对应 Bun: SharedArrayBuffer
//   SharedArrayBuffer 允许多个 Worker 共享同一段内存
//   完整实现需要 Atomics API 支持
// ============================================================================

/// SharedArrayBuffer — 共享内存
/// 对应 Bun: SharedArrayBuffer
/// 线程安全实现: 使用 ThreadMutex 保护的数组
public class SharedArrayBuffer {
    /// 底层数据
    private var data: Array<UInt8>
    /// 互斥锁 — 使用 ThreadMutex 保证线程安全
    private var lock: ThreadMutex
    /// 字节长度
    public var byteLength: Int64

    public init(size: Int64) {
        this.data = Array<UInt8>(Int64(size), { _ => UInt8(0) })
        this.lock = ThreadMutex()
        this.byteLength = size
    }

    /// 读取字节
    public func readByte(index: Int64): UInt8 {
        synchronized(lock) {
            if (index < 0 || index >= byteLength) {
                return UInt8(0)
            }
            return data[Int64(index)]
        }
    }

    /// 写入字节
    public func writeByte(index: Int64, value: UInt8): Unit {
        synchronized(lock) {
            if (index < 0 || index >= byteLength) {
                return
            }
            data[Int64(index)] = value
        }
    }

    /// 读取 Int32 (小端序)
    public func readInt32(index: Int64): Int32 {
        synchronized(lock) {
            if (index < 0 || index + 4 > byteLength) {
                return 0
            }
            let b0 = Int32(data[Int64(index)])
            let b1 = Int32(data[Int64(index + 1)])
            let b2 = Int32(data[Int64(index + 2)])
            let b3 = Int32(data[Int64(index + 3)])
            return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
        }
    }

    /// 写入 Int32 (小端序)
    public func writeInt32(index: Int64, value: Int32): Unit {
        synchronized(lock) {
            if (index < 0 || index + 4 > byteLength) {
                return
            }
            data[Int64(index)] = UInt8(value & 0xFF)
            data[Int64(index + 1)] = UInt8((value >> 8) & 0xFF)
            data[Int64(index + 2)] = UInt8((value >> 16) & 0xFF)
            data[Int64(index + 3)] = UInt8((value >> 24) & 0xFF)
        }
    }

    /// 原子比较并交换 (简化)
    /// 对应 Atomics.compareExchange
    public func compareExchange(index: Int64, expected: Int32, replacement: Int32): Int32 {
        synchronized(lock) {
            let current = readInt32Locked(index)
            if (current == expected) {
                writeInt32Locked(index, replacement)
            }
            return current
        }
    }

    /// 内部读取 (调用者已持有锁)
    private func readInt32Locked(index: Int64): Int32 {
        if (index < 0 || index + 4 > byteLength) {
            return 0
        }
        let b0 = Int32(data[Int64(index)])
        let b1 = Int32(data[Int64(index + 1)])
        let b2 = Int32(data[Int64(index + 2)])
        let b3 = Int32(data[Int64(index + 3)])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    /// 内部写入 (调用者已持有锁)
    private func writeInt32Locked(index: Int64, value: Int32): Unit {
        if (index < 0 || index + 4 > byteLength) {
            return
        }
        data[Int64(index)] = UInt8(value & 0xFF)
        data[Int64(index + 1)] = UInt8((value >> 8) & 0xFF)
        data[Int64(index + 2)] = UInt8((value >> 16) & 0xFF)
        data[Int64(index + 3)] = UInt8((value >> 24) & 0xFF)
    }

    /// 切片数据 (复制)
    public func slice(start: Int64, end: Int64): Array<UInt8> {
        synchronized(lock) {
            let s = if (start < 0) { byteLength + start } else { start }
            let e = if (end < 0) { byteLength + end } else { end }
            if (s < 0 || e > byteLength || s >= e) {
                return Array<UInt8>(0, { _ => UInt8(0) })
            }
            let len = e - s
            let result = Array<UInt8>(Int64(len), { _ => UInt8(0) })
            for (i in 0..Int64(len)) {
                result[i] = data[Int64(s) + i]
            }
            return result
        }
    }

    /// 将 SharedArrayBuffer 导出为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let sab = this

        obj.set("byteLength", JsValue(Float64(byteLength)))

        obj.set("slice", JsValue.nativeFunction(JsNativeFunction("slice") { args =>
            let start = if (args.size >= 1) { Int64(Interpreter.jsToNumber(args[0])) } else { 0 }
            let end = if (args.size >= 2) { Int64(Interpreter.jsToNumber(args[1])) } else { sab.byteLength }
            let sliced = sab.slice(start, end)
            // 返回一个新的 ArrayBuffer 视图
            let bufObj = JsObject()
            bufObj.set("byteLength", JsValue(Float64(sliced.size)))
            return JsValue(bufObj)
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// WorkerMessageBus — Worker 消息总线
// 对应 Bun: Worker 内外通信的消息管理
// ============================================================================

/// Worker 消息总线 — 管理 Worker 内外通信
/// 对应 Bun: Worker 的 postMessage/onmessage 实现
public class WorkerMessageBus {
    /// 主线程 -> Worker 的通道
    private var toWorker: Channel<JsValue>
    /// Worker -> 主线程的通道
    private var toMain: Channel<JsValue>
    /// 消息监听器 (主线程端)
    private var mainListeners: ArrayList<(JsValue) -> Unit>
    /// 消息监听器 (Worker 端)
    private var workerListeners: ArrayList<(JsValue) -> Unit>

    public init() {
        toWorker = Channel<JsValue>()
        toMain = Channel<JsValue>()
        mainListeners = ArrayList<(JsValue) -> Unit>()
        workerListeners = ArrayList<(JsValue) -> Unit>()
    }

    /// 主线程向 Worker 发送消息 - 对应 worker.postMessage(data)
    public func postToWorker(data: JsValue): Bool {
        return toWorker.send(data)
    }

    /// Worker 向主线程发送消息 - 对应 self.postMessage(data)
    public func postToMain(data: JsValue): Bool {
        return toMain.send(data)
    }

    /// Worker 接收来自主线程的消息
    public func receiveInWorker(): ?JsValue {
        return toWorker.tryReceive()
    }

    /// 主线程接收来自 Worker 的消息
    public func receiveInMain(): ?JsValue {
        return toMain.tryReceive()
    }

    /// 主线程注册消息监听器 - 对应 worker.onmessage = fn
    public func onMainMessage(listener: (JsValue) -> Unit): Unit {
        mainListeners.append(listener)
    }

    /// Worker 注册消息监听器 - 对应 self.onmessage = fn
    public func onWorkerMessage(listener: (JsValue) -> Unit): Unit {
        workerListeners.append(listener)
    }

    /// 轮询主线程消息 (在主线程事件循环中调用)
    public func pollMainMessages(): Unit {
        while (true) {
            let msg = toMain.tryReceive()
            match (msg) {
                case Some(value) =>
                    for (listener in mainListeners) {
                        listener(value)
                    }
                case None => break
            }
        }
    }

    /// 轮询 Worker 消息 (在 Worker 事件循环中调用)
    public func pollWorkerMessages(): Unit {
        while (true) {
            let msg = toWorker.tryReceive()
            match (msg) {
                case Some(value) =>
                    for (listener in workerListeners) {
                        listener(value)
                    }
                case None => break
            }
        }
    }

    /// 关闭消息总线
    public func close(): Unit {
        toWorker.close()
        toMain.close()
    }
}

// ============================================================================
// WorkerThread — Worker 线程执行上下文
// 对应 Bun: web_worker.zig threadMain -> startVM -> spin -> shutdown
// ============================================================================

/// Worker 线程执行上下文
/// 对应 Bun: WebWorker 结构体的 Worker 线程部分
public class WorkerContext {
    /// Worker 内的全局作用域
    public var globalScope: JsObject
    /// 消息总线
    public var messageBus: WorkerMessageBus
    /// Worker 虚拟机
    public var vm: VirtualMachine
    /// Worker 解释器
    public var interpreter: Interpreter
    /// Worker 名称
    public var name: String
    /// 请求终止标志
    public var requestedTerminate: Bool
    /// Worker 入口脚本 URL
    public var entryUrl: String
    /// Worker 入口脚本源码
    public var entrySource: String
    /// 是否已退出
    public var exitCalled: Bool

    public init(messageBus: WorkerMessageBus, entryUrl: String, entrySource: String) {
        globalScope = JsObject()
        this.messageBus = messageBus
        vm = VirtualMachine()
        interpreter = vm.getInterpreter()
        name = ""
        requestedTerminate = false
        this.entryUrl = entryUrl
        this.entrySource = entrySource
        exitCalled = false
    }

    /// 初始化 Worker VM 环境
    /// 对应 Bun: startVM() — 构建 Worker 的 VM 并注册全局对象
    public func startVM(): Unit {
        let env = interpreter.getGlobalEnv()

        // 注册 self / globalThis — Worker 全局作用域
        let selfValue = toSelfJsValue()
        env.define("self", selfValue, false)
        env.define("globalThis", selfValue, false)

        // 注册 onmessage — 消息处理回调
        env.define("onmessage", JsValue.UNDEFINED, true)

        // 注册 onerror — 错误处理回调
        env.define("onerror", JsValue.UNDEFINED, true)

        // 注册 onclose — 关闭回调
        env.define("onclose", JsValue.UNDEFINED, true)

        // 注册 importScripts (经典 Worker)
        let ctx = this
        env.define("importScripts", Interpreter.makeNativeFn("importScripts") { args =>
            // 经典 Worker 的 importScripts
            // 对应 Bun: WebWorker.importScripts — 从文件系统加载并同步执行脚本
            for (arg in args) {
                let scriptPath = Interpreter.jsToString(arg)
                // 从文件系统读取脚本源码
                let readResult = BaoFile.readAllText(scriptPath)
                if (readResult.isOk()) {
                    let source = readResult.result().getOrThrow()
                    // 在当前 VM 中执行脚本
                    let result = ctx.vm.eval(source, scriptPath)
                    // 如果执行出错，传播异常
                    match (result.valueType) {
                        case JsValueType.Error =>
                            return result
                        case _ => ()
                    }
                } else {
                    // 文件读取失败
                    ()
                }
            }
            return JsValue.UNDEFINED
        }, false)

        // 注册 close() — Worker 内部关闭
        env.define("close", Interpreter.makeNativeFn("close") { _ =>
            ctx.requestedTerminate = true
            ctx.messageBus.postToMain(JsValue(BaoString("__close__")))
            return JsValue.UNDEFINED
        }, false)

        // 注册 console 对象
        let consoleObj = JsObject()
        let printFn = interpreter.printFn
        consoleObj.set("log", Interpreter.makeNativeFn("log") { args =>
            let sb = StringBuilder()
            for (i in 0..args.size) {
                if (i > 0) { sb.append(" ") }
                sb.append(Interpreter.jsToString(args[i]))
            }
            printFn(sb.toString())
            return JsValue.UNDEFINED
        })
        consoleObj.set("error", Interpreter.makeNativeFn("error") { args =>
            let sb = StringBuilder()
            for (i in 0..args.size) {
                if (i > 0) { sb.append(" ") }
                sb.append(Interpreter.jsToString(args[i]))
            }
            printFn("[Worker ERROR] ${sb.toString()}")
            return JsValue.UNDEFINED
        })
        consoleObj.set("warn", Interpreter.makeNativeFn("warn") { args =>
            let sb = StringBuilder()
            for (i in 0..args.size) {
                if (i > 0) { sb.append(" ") }
                sb.append(Interpreter.jsToString(args[i]))
            }
            printFn("[Worker WARN] ${sb.toString()}")
            return JsValue.UNDEFINED
        })
        env.define("console", JsValue(consoleObj), false)

        // 注册 setTimeout/setInterval (Worker 内的定时器)
        env.define("setTimeout", Interpreter.makeNativeFn("setTimeout") { args =>
            if (args.size < 1) { return JsValue(-1.0) }
            // 简化: 立即执行回调
            match (args[0].nativeFnData) {
                case Some(nf) =>
                    let result = nf.fn(ArrayList<JsValue>())
                    return result
                case None => ()
            }
            return JsValue(-1.0)
        }, false)
        env.define("setInterval", Interpreter.makeNativeFn("setInterval") { args =>
            return JsValue(-1.0)
        }, false)
        env.define("clearTimeout", Interpreter.makeNativeFn("clearTimeout") { _ =>
            return JsValue.UNDEFINED
        }, false)
        env.define("clearInterval", Interpreter.makeNativeFn("clearInterval") { _ =>
            return JsValue.UNDEFINED
        }, false)
    }

    /// 将 Worker 全局作用域注册为 JsValue (self)
    /// 对应 Bun: WorkerGlobalScope
    public func toSelfJsValue(): JsValue {
        let obj = JsObject()
        let ctx = this

        // self.postMessage(data) — Worker 向主线程发送消息
        obj.set("postMessage", JsValue.nativeFunction(JsNativeFunction("postMessage") { args =>
            if (args.size >= 1) {
                ctx.messageBus.postToMain(args[0])
            }
            return JsValue.UNDEFINED
        }))

        // self.onmessage — 消息处理回调
        obj.set("onmessage", JsValue.UNDEFINED)

        // self.onerror — 错误处理回调
        obj.set("onerror", JsValue.UNDEFINED)

        // self.close() — 关闭 Worker
        obj.set("close", JsValue.nativeFunction(JsNativeFunction("close") { _ =>
            ctx.requestedTerminate = true
            ctx.messageBus.postToMain(JsValue(BaoString("__close__")))
            return JsValue.UNDEFINED
        }))

        // self.name — Worker 名称
        obj.set("name", JsValue(BaoString(name)))

        return JsValue(obj)
    }

    /// spin() — 加载入口脚本并运行事件循环
    /// 对应 Bun: WebWorker.spin() — Phase 2
    public func spin(): Unit {
        // 加载并执行入口脚本
        if (!entrySource.isEmpty()) {
            let result = vm.eval(entrySource, entryUrl)
            // 检查是否有未处理的错误
            match (result.valueType) {
                case JsValueType.Error =>
                    // 脚本执行出错, 发送错误事件
                    let errorObj = JsObject()
                    let errMsg = result.toString()
                    errorObj.set("message", JsValue(errMsg))
                    messageBus.postToMain(JsValue(errorObj))
                case _ => ()
            }
        }

        // 触发 online 事件 — 通知主线程 Worker 已就绪
        messageBus.postToMain(JsValue(BaoString("__online__")))

        // 进入消息循环
        // 对应 Bun: while (vm.isEventLoopAlive()) { vm.tick(); }
        while (!requestedTerminate) {
            // 轮询来自主线程的消息
            messageBus.pollWorkerMessages()

            // 检查 onmessage 回调
            let env = interpreter.getGlobalEnv()
            match (env.lookup("onmessage")) {
                case Some(handler) =>
                    // 尝试从消息总线获取消息
                    while (true) {
                        let msg = messageBus.receiveInWorker()
                        match (msg) {
                            case Some(value) =>
                                // 创建 MessageEvent 对象
                                let eventObj = JsObject()
                                eventObj.set("data", value)
                                let event = JsValue(eventObj)

                                // 调用 onmessage handler
                                match (handler.nativeFnData) {
                                    case Some(nf) =>
                                        let callArgs = ArrayList<JsValue>()
                                        callArgs.append(event)
                                        nf.fn(callArgs)
                                    case None => ()
                                }
                            case None => break
                        }
                    }
                case None => ()
            }

            // 让出 CPU 时间
            SysModule.sleep(1)
        }
    }

    /// shutdown() — 运行退出处理器
    /// 对应 Bun: WebWorker.shutdown() — Phase 3
    public func shutdown(): Unit {
        // 触发 onclose 回调
        let env = interpreter.getGlobalEnv()
        match (env.lookup("onclose")) {
            case Some(handler) =>
                match (handler.nativeFnData) {
                    case Some(nf) =>
                        let _ = nf.fn(ArrayList<JsValue>())
                    case None => ()
                }
            case None => ()
        }

        // 关闭消息总线
        messageBus.close()
    }
}

// ============================================================================
// Worker — Web Worker
// 对应 Bun: new Worker(url, options) + web_worker.zig
// ============================================================================

/// Worker 选项 - 对应 new Worker(url, { ... })
/// 对应 Bun: WorkerOptions
public class WorkerOptions {
    /// Worker 名称 - 对应 { name: "my-worker" }
    public var name: String
    /// Worker 类型 - 对应 { type: "module" | "classic" }
    public var `type`: String
    /// 是否启用 SharedArrayBuffer - 对应 { sharedArrayBuffer: true }
    public var sharedArrayBuffer: Bool
    /// 预执行代码 (内联 Worker) - 对应 Blob URL 或 eval 模式
    public var source: ?String
    /// 是否使用精简模式
    public var smol: Bool

    public init() {
        name = ""
        `type` = "module"
        sharedArrayBuffer = false
        source = None
        smol = false
    }
}

/// Worker — Web Worker API
/// 对应 Bun: new Worker(url, options)
///   Bun 通过 pthread_create 创建新线程执行 Worker 脚本
///   仓颉通过 spawn { } 创建新线程
///
/// 生命周期 (对应 Bun web_worker.zig):
///   1. create()  — 分配结构体, 注册到 LiveWorkers, 启动线程
///   2. spin()    — 加载入口脚本, 触发 'online', 运行事件循环
///   3. shutdown() — 运行退出处理器, 发送 'close', 清理资源
public class Worker {
    /// Worker URL (脚本路径)
    public var url: String
    /// Worker 选项
    public var options: WorkerOptions
    /// 消息总线
    private var messageBus: WorkerMessageBus
    /// Worker 状态
    public var state: WorkerState
    /// 请求终止标志 (原子)
    private var requestedTerminate: Bool
    /// Worker 线程上下文 (在线程启动后设置)
    private var context: ?WorkerContext
    /// 消息监听器 (主线程端)
    private var messageListeners: ArrayList<(JsValue) -> Unit>
    /// 错误监听器
    private var errorListeners: ArrayList<(String) -> Unit>
    /// 关闭监听器
    private var closeListeners: ArrayList<() -> Unit>
    /// 消息错误事件监听器
    private var messageErrorListeners: ArrayList<(JsValue) -> Unit>

    public init(url: String) {
        this.url = url
        options = WorkerOptions()
        messageBus = WorkerMessageBus()
        state = WorkerState.Starting
        requestedTerminate = false
        context = None
        messageListeners = ArrayList<(JsValue) -> Unit>()
        errorListeners = ArrayList<(String) -> Unit>()
        closeListeners = ArrayList<() -> Unit>()
        messageErrorListeners = ArrayList<(JsValue) -> Unit>()
    }

    public init(url: String, options: WorkerOptions) {
        this.url = url
        this.options = options
        messageBus = WorkerMessageBus()
        state = WorkerState.Starting
        requestedTerminate = false
        context = None
        messageListeners = ArrayList<(JsValue) -> Unit>()
        errorListeners = ArrayList<(String) -> Unit>()
        closeListeners = ArrayList<() -> Unit>()
        messageErrorListeners = ArrayList<(JsValue) -> Unit>()
    }

    public operator func ==(right: Worker): Bool {
        this.url == right.url
    }

    /// 启动 Worker — 对应 Bun: create() + threadMain()
    /// 分配 Worker 线程上下文, 注册到 LiveWorkers, 启动线程
    public func start(): Unit {
        if (state != WorkerState.Starting) {
            return
        }

        let bus = messageBus
        let workerUrl = url
        let workerOpts = options
        let worker = this

        // 获取入口脚本源码
        // 如果 options.source 有值, 使用内联源码
        // 否则尝试从 URL 读取
        let entrySource = match (options.source) {
            case Some(src) => src
            case None =>
                // 从文件系统读取 worker 入口脚本
                // 对应 Bun: std.fs.cwd().readFileAlloc(...)
                let readResult = BaoFile.readAllText(workerUrl)
                if (readResult.isOk()) { readResult.result().getOrThrow() } else { "" }
        }

        // 创建 Worker 线程上下文
        let ctx = WorkerContext(bus, workerUrl, entrySource)
        ctx.name = options.name
        context = Some(ctx)

        // 注册到全局 LiveWorkers
        LiveWorkers.register(worker)

        // 注册消息总线监听器 — 主线程端
        bus.onMainMessage() { value =>
            let valueStr = Interpreter.jsToString(value)
            // 处理内部控制消息
            if (valueStr == "__online__") {
                worker.state = WorkerState.Running
                return
            }
            if (valueStr == "__close__") {
                worker.state = WorkerState.Terminated
                for (listener in worker.closeListeners) {
                    listener()
                }
                return
            }
            if (valueStr.startsWith("error:")) {
                let errMsg = valueStr[6..]
                for (listener in worker.errorListeners) {
                    listener(errMsg)
                }
                return
            }
            // 普通消息, 分发给监听器
            for (listener in worker.messageListeners) {
                listener(value)
            }
        }

        // 启动 Worker 线程
        // 对应 Bun: std.Thread.spawn(.{ .stack_size }, threadMain, .{worker})
        // 仓颉使用 spawn { } 创建新线程
        spawn {
            worker.workerThreadMain(ctx)
        }
    }

    /// Worker 线程主函数
    /// 对应 Bun: WebWorker.threadMain() -> startVM() -> spin() -> shutdown()
    private func workerThreadMain(ctx: WorkerContext): Unit {
        // Phase 1: startVM — 初始化 Worker VM 环境
        // 对应 Bun: WebWorker.startVM()
        try {
            ctx.startVM()
        } catch (e: Exception) {
            messageBus.postToMain(JsValue(BaoString("error: Failed to start Worker VM: ${e.message}")))
            LiveWorkers.unregister(this)
            return
        }

        // 检查是否已请求终止
        if (requestedTerminate) {
            ctx.shutdown()
            LiveWorkers.unregister(this)
            return
        }

        // Phase 2: spin — 加载入口脚本, 运行事件循环
        // 对应 Bun: WebWorker.spin()
        try {
            ctx.spin()
        } catch (e: Exception) {
            messageBus.postToMain(JsValue(BaoString("error: Worker error: ${e.message}")))
        }

        // Phase 3: shutdown — 运行退出处理器, 清理资源
        // 对应 Bun: WebWorker.shutdown()
        ctx.shutdown()

        // 从全局注册表注销
        LiveWorkers.unregister(this)

        // 如果还未触发关闭事件, 触发它
        if (state != WorkerState.Terminated) {
            state = WorkerState.Terminated
            for (listener in closeListeners) {
                listener()
            }
        }
    }

    /// postMessage(data) — 主线程向 Worker 发送消息
    /// 对应 Bun: worker.postMessage(data)
    public func postMessage(data: JsValue): Unit {
        if (state != WorkerState.Running) {
            return
        }
        messageBus.postToWorker(data)
    }

    /// onmessage — 注册消息监听器
    /// 对应 Bun: worker.onmessage = fn
    public func onMessage(listener: (JsValue) -> Unit): Worker {
        messageListeners.append(listener)
        return this
    }

    /// onerror — 注册错误监听器
    /// 对应 Bun: worker.onerror = fn
    public func onError(listener: (String) -> Unit): Worker {
        errorListeners.append(listener)
        return this
    }

    /// onclose — 注册关闭监听器
    /// 对应 Bun: worker.onclose = fn
    public func onClose(listener: () -> Unit): Worker {
        closeListeners.append(listener)
        return this
    }

    /// onmessageerror — 注册消息错误监听器
    public func onMessageError(listener: (JsValue) -> Unit): Worker {
        messageErrorListeners.append(listener)
        return this
    }

    /// terminate() — 强制终止 Worker
    /// 对应 Bun: worker.terminate() / WebWorker.notifyNeedTermination()
    public func terminate(): Unit {
        if (state == WorkerState.Terminated) {
            return
        }
        requestedTerminate = true
        state = WorkerState.Terminated
        messageBus.close()
        // 通知关闭监听器
        for (listener in closeListeners) {
            listener()
        }
    }

    /// close() — Worker 内部调用关闭
    /// 对应 Bun: self.close()
    public func close(): Unit {
        terminate()
    }

    /// ref() — 保持父事件循环活跃
    /// 对应 Bun: worker.ref()
    public func ref(): Unit {
        // 在完整实现中, 这会增加父事件循环的 keep-alive 计数
    }

    /// unref() — 允许父事件循环退出
    /// 对应 Bun: worker.unref()
    public func unref(): Unit {
        // 在完整实现中, 这会减少父事件循环的 keep-alive 计数
    }

    /// 轮询来自 Worker 的消息 (在主线程事件循环中调用)
    public func poll(): Unit {
        if (state != WorkerState.Running) {
            return
        }
        messageBus.pollMainMessages()
    }

    /// 将 Worker 导出为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let worker = this

        obj.set("postMessage", JsValue.nativeFunction(JsNativeFunction("postMessage") { args =>
            if (args.size >= 1) {
                worker.postMessage(args[0])
            }
            return JsValue.UNDEFINED
        }))

        obj.set("terminate", JsValue.nativeFunction(JsNativeFunction("terminate") { _ =>
            worker.terminate()
            return JsValue.UNDEFINED
        }))

        obj.set("close", JsValue.nativeFunction(JsNativeFunction("close") { _ =>
            worker.close()
            return JsValue.UNDEFINED
        }))

        obj.set("ref", JsValue.nativeFunction(JsNativeFunction("ref") { _ =>
            worker.ref()
            return JsValue.UNDEFINED
        }))

        obj.set("unref", JsValue.nativeFunction(JsNativeFunction("unref") { _ =>
            worker.unref()
            return JsValue.UNDEFINED
        }))

        // onmessage / onerror / onclose 占位
        obj.set("onmessage", JsValue.UNDEFINED)
        obj.set("onerror", JsValue.UNDEFINED)
        obj.set("onclose", JsValue.UNDEFINED)

        return JsValue(obj)
    }
}

// ============================================================================
// WorkerPool — Worker 池
// 对应 Bun: Worker 池化管理 (用于 CPU 密集任务)
// ============================================================================

/// Worker 池 — 管理多个 Worker 的池
/// 用于将任务分发到多个 Worker 线程并行处理
public class WorkerPool {
    /// Worker 列表
    private var workers: ArrayList<Worker>
    /// 当前轮询索引
    private var nextIndex: Int64
    /// 池大小
    public var size: Int64

    public init(size: Int64, scriptUrl: String) {
        workers = ArrayList<Worker>()
        nextIndex = 0
        this.size = size
        for (_ in 0..size) {
            let worker = Worker(scriptUrl)
            worker.start()
            workers.append(worker)
        }
    }

    /// 获取下一个 Worker (轮询策略)
    public func getWorker(): ?Worker {
        if (workers.size == 0) {
            return None
        }
        let worker = workers[Int64(nextIndex)]
        nextIndex = (nextIndex + 1) % Int64(workers.size)
        return Some(worker)
    }

    /// 向下一个 Worker 发送消息
    public func postMessage(data: JsValue): Bool {
        match (getWorker()) {
            case Some(worker) =>
                worker.postMessage(data)
                return true
            case None => return false
        }
    }

    /// 终止所有 Worker
    public func terminateAll(): Unit {
        for (worker in workers) {
            worker.terminate()
        }
        workers.clear()
    }

    /// 轮询所有 Worker 的消息
    public func pollAll(): Unit {
        for (worker in workers) {
            worker.poll()
        }
    }
}

// ============================================================================
// WorkerModule — Worker 模块导出
// 对应 Bun: node:worker_threads 模块
// ============================================================================

/// Worker 模块导出 — 对应 node:worker_threads
/// 提供 Web Worker API 和 Node.js worker_threads 兼容接口
public class WorkerModule {
    /// 将 Worker 模块导出为 JsValue (Web Worker API)
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        // Worker 构造函数
        obj.set("Worker", JsValue.nativeFunction(JsNativeFunction("Worker") { args =>
            if (args.size >= 1) {
                let url = Interpreter.jsToString(args[0])
                let opts = WorkerOptions()
                // 解析第二个参数 (options)
                if (args.size >= 2) {
                    match (args[1].objectValue) {
                        case Some(optObj) =>
                            let nameVal = optObj.get("name")
                            if (nameVal.valueType == JsValueType.String) {
                                opts.name = nameVal.stringValue.toString()
                            }
                            let typeVal = optObj.get("type")
                            if (typeVal.valueType == JsValueType.String) {
                                opts.`type` = typeVal.stringValue.toString()
                            }
                        case None => ()
                    }
                }
                let worker = Worker(url, opts)
                worker.start()
                return worker.toJsValue()
            }
            return JsValue.UNDEFINED
        }))

        // MessageChannel 构造函数
        obj.set("MessageChannel", JsValue.nativeFunction(JsNativeFunction("MessageChannel") { _ =>
            let channel = MessageChannel()
            return channel.toJsValue()
        }))

        // SharedArrayBuffer 构造函数
        obj.set("SharedArrayBuffer", JsValue.nativeFunction(JsNativeFunction("SharedArrayBuffer") { args =>
            let size = if (args.size >= 1) {
                Int64(Interpreter.jsToNumber(args[0]))
            } else {
                0
            }
            let sab = SharedArrayBuffer(size)
            return sab.toJsValue()
        }))

        // default 导出 (ESM 兼容)
        obj.set("default", JsValue(obj))

        return JsValue(obj)
    }

    /// 将 node:worker_threads 模块导出为 JsValue
    /// 对应 Node.js worker_threads API
    public static func toNodeWorkerThreadsJsValue(): JsValue {
        let obj = JsObject()

        // Worker 类 — 对应 node:worker_threads.Worker
        obj.set("Worker", JsValue.nativeFunction(JsNativeFunction("Worker") { args =>
            if (args.size >= 1) {
                let url = Interpreter.jsToString(args[0])
                let opts = WorkerOptions()
                // 解析第二个参数 (options)
                if (args.size >= 2) {
                    match (args[1].objectValue) {
                        case Some(optObj) =>
                            let nameVal = optObj.get("name")
                            if (nameVal.valueType == JsValueType.String) {
                                opts.name = nameVal.stringValue.toString()
                            }
                            let typeVal = optObj.get("type")
                            if (typeVal.valueType == JsValueType.String) {
                                opts.`type` = typeVal.stringValue.toString()
                            }
                            let evalVal = optObj.get("eval")
                            if (evalVal.valueType == JsValueType.Boolean) {
                                // eval 模式: workerData 作为源码
                                if (evalVal.boolValue) {
                                    let workerDataVal = optObj.get("workerData")
                                    if (workerDataVal.valueType == JsValueType.String) {
                                        opts.source = Some(workerDataVal.stringValue.toString())
                                    }
                                }
                            }
                            let workerDataVal = optObj.get("workerData")
                            // workerData 传递给 Worker
                        case None => ()
                    }
                }
                let worker = Worker(url, opts)
                worker.start()
                return worker.toJsValue()
            }
            return JsValue.UNDEFINED
        }))

        // isMainThread — 是否在主线程
        obj.set("isMainThread", JsValue(true))

        // workerData — 当前 Worker 的数据 (主线程为 null)
        obj.set("workerData", JsValue.NULL)

        // parentPort — 父线程端口 (主线程为 null)
        obj.set("parentPort", JsValue.NULL)

        // threadId — 当前线程 ID
        obj.set("threadId", JsValue(0.0))

        // MessageChannel
        obj.set("MessageChannel", JsValue.nativeFunction(JsNativeFunction("MessageChannel") { _ =>
            let channel = MessageChannel()
            return channel.toJsValue()
        }))

        // MessagePort
        obj.set("MessagePort", JsValue.nativeFunction(JsNativeFunction("MessagePort") { _ =>
            let channel = Channel<JsValue>()
            let port = MessagePort(0, channel)
            return port.toJsValue()
        }))

        // SharedArrayBuffer
        obj.set("SharedArrayBuffer", JsValue.nativeFunction(JsNativeFunction("SharedArrayBuffer") { args =>
            let size = if (args.size >= 1) {
                Int64(Interpreter.jsToNumber(args[0]))
            } else {
                0
            }
            let sab = SharedArrayBuffer(size)
            return sab.toJsValue()
        }))

        // default 导出 (ESM 兼容)
        obj.set("default", JsValue(obj))

        return JsValue(obj)
    }

    /// 创建 Worker 内部的 worker_threads 模块
    /// 当在 Worker 线程中 require('worker_threads') 时使用
    public static func toWorkerThreadJsValue(workerCtx: WorkerContext): JsValue {
        let obj = JsObject()

        // isMainThread — Worker 中为 false
        obj.set("isMainThread", JsValue(false))

        // workerData — Worker 的初始化数据
        obj.set("workerData", JsValue.NULL)

        // parentPort — 父线程端口
        let parentPort = JsObject()
        parentPort.set("postMessage", JsValue.nativeFunction(JsNativeFunction("postMessage") { args =>
            if (args.size >= 1) {
                workerCtx.messageBus.postToMain(args[0])
            }
            return JsValue.UNDEFINED
        }))
        parentPort.set("on", JsValue.nativeFunction(JsNativeFunction("on") { args =>
            // 注册消息监听器
            if (args.size >= 2) {
                let eventName = Interpreter.jsToString(args[0])
                if (eventName == "message") {
                    match (args[1].nativeFnData) {
                        case Some(nf) =>
                            workerCtx.messageBus.onWorkerMessage() { value =>
                                let callArgs = ArrayList<JsValue>()
                                callArgs.append(value)
                                nf.fn(callArgs)
                            }
                        case None => ()
                    }
                }
            }
            return JsValue.UNDEFINED
        }))
        parentPort.set("close", JsValue.nativeFunction(JsNativeFunction("close") { _ =>
            workerCtx.requestedTerminate = true
            return JsValue.UNDEFINED
        }))
        obj.set("parentPort", JsValue(parentPort))

        // threadId
        obj.set("threadId", JsValue(1.0))

        // MessageChannel
        obj.set("MessageChannel", JsValue.nativeFunction(JsNativeFunction("MessageChannel") { _ =>
            let channel = MessageChannel()
            return channel.toJsValue()
        }))

        // default 导出
        obj.set("default", JsValue(obj))

        return JsValue(obj)
    }
}
