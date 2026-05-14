// Worker — Web Worker API
// 严格翻译自: src/runtime/ Web Worker API
//   Bun 支持 Web Worker API，允许在独立线程中执行 JavaScript
//   仓颉通过 bao_threading.Thread + Channel 实现等价功能
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_threading.*

// ============================================================================
// WorkerState — Worker 状态
// ============================================================================

/// Worker 状态
public enum WorkerState {
    | Starting    // 正在启动
    | Running     // 运行中
    | Terminated  // 已终止
    | Error       // 出错
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
    /// 消息通道
    private var channel: Channel<JsValue>
    /// 消息监听器
    private var messageListeners: ArrayList<(JsValue) -> Unit>
    /// 错误监听器
    private var errorListeners: ArrayList<(String) -> Unit>
    /// 关闭监听器
    private var closeListeners: ArrayList<() -> Unit>
    /// 是否已关闭
    private var closed: Bool

    public init(id: Int64, channel: Channel<JsValue>) {
        this.id = id
        this.channel = channel
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
        return channel.send(data)
    }

    /// 接收消息 (非阻塞)
    public func receiveMessage(): ?JsValue {
        if (closed) {
            return None
        }
        return channel.tryReceive()
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
            let msg = channel.tryReceive()
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
        channel.close()
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

    /// 双向通道: port1 -> port2
    private var channel1to2: Channel<JsValue>
    /// 双向通道: port2 -> port1
    private var channel2to1: Channel<JsValue>

    public init() {
        channel1to2 = Channel<JsValue>()
        channel2to1 = Channel<JsValue>()
        port1 = MessagePort(1, channel2to1)
        port2 = MessagePort(2, channel1to2)
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

/// SharedArrayBuffer 存根 — 共享内存
/// 对应 Bun: SharedArrayBuffer
/// 简化实现: 使用 Mutex 保护的数组模拟
public class SharedArrayBuffer {
    /// 底层数据
    private var data: Array<UInt8>
    /// 互斥锁
    private var lock: ReentrantMutex
    /// 字节长度
    public var byteLength: Int64

    public init(size: Int64) {
        this.data = Array<UInt8>(Int64(size), item: UInt8(0))
        this.lock = ReentrantMutex()
        this.byteLength = size
    }

    /// 读取字节
    public func readByte(index: Int64): UInt8 {
        if (index < 0 || index >= byteLength) {
            return UInt8(0)
        }
        synchronized(lock) {
            return data[Int64(index)]
        }
    }

    /// 写入字节
    public func writeByte(index: Int64, value: UInt8): Unit {
        if (index < 0 || index >= byteLength) {
            return
        }
        synchronized(lock) {
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
            let current = readInt32(index)
            if (current == expected) {
                writeInt32(index, replacement)
            }
            return current
        }
    }

    /// 切片数据 (复制)
    public func slice(start: Int64, end: Int64): Array<UInt8> {
        synchronized(lock) {
            let s = if (start < 0) { byteLength + start } else { start }
            let e = if (end < 0) { byteLength + end } else { end }
            if (s < 0 || e > byteLength || s >= e) {
                return Array<UInt8>(0, item: UInt8(0))
            }
            let len = e - s
            let result = Array<UInt8>(Int64(len), item: UInt8(0))
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
            let data = sab.slice(start, end)
            return JsValue.nativeFunction(JsNativeFunction("getBuffer") { _ =>
                // 返回一个新的 Buffer 视图
                return JsValue.UNDEFINED
            })
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
// WorkerThread — Worker 线程
// 对应 Bun: Worker 底层线程执行
// ============================================================================

/// Worker 线程执行上下文
public class WorkerContext {
    /// Worker 内的全局作用域
    public var globalScope: JsObject
    /// 消息总线
    public var messageBus: WorkerMessageBus
    /// Worker 虚拟机
    public var vm: VirtualMachine
    /// Worker 名称
    public var name: String

    public init(messageBus: WorkerMessageBus) {
        globalScope = JsObject()
        this.messageBus = messageBus
        vm = VirtualMachine()
        name = ""
    }

    /// 将 Worker 全局作用域注册为 JsValue (self)
    public func toSelfJsValue(): JsValue {
        let obj = JsObject()
        let ctx = this

        // self.postMessage(data)
        obj.set("postMessage", JsValue.nativeFunction(JsNativeFunction("postMessage") { args =>
            if (args.size >= 1) {
                ctx.messageBus.postToMain(args[0])
            }
            return JsValue.UNDEFINED
        }))

        // self.onmessage
        obj.set("onmessage", JsValue.UNDEFINED)

        // self.close()
        obj.set("close", JsValue.nativeFunction(JsNativeFunction("close") { _ =>
            ctx.messageBus.postToMain(JsValue(BaoString("close")))
            return JsValue.UNDEFINED
        }))

        // self.name
        obj.set("name", JsValue(BaoString(name)))

        return JsValue(obj)
    }
}

// ============================================================================
// Worker — Web Worker
// 对应 Bun: new Worker(url, options)
// ============================================================================

/// Worker 选项 - 对应 new Worker(url, { ... })
public class WorkerOptions {
    /// Worker 名称 - 对应 { name: "my-worker" }
    public var name: String
    /// Worker 类型 - 对应 { type: "module" | "classic" }
    public var type: String
    /// 是否启用 SharedArrayBuffer - 对应 { sharedArrayBuffer: true }
    public var sharedArrayBuffer: Bool
    /// 预执行代码 (内联 Worker) - 对应 Blob URL
    public var source: ?String
    /// 是否平滑启动
    public var smol: Bool

    public init() {
        name = ""
        type = "module"
        sharedArrayBuffer = false
        source = None
        smol = false
    }
}

/// Worker — Web Worker API
/// 对应 Bun: new Worker(url, options)
///   Bun 通过 pthread_create 创建新线程执行 Worker 脚本
///   仓颉通过 bao_threading.spawn 创建新线程
public class Worker {
    /// Worker URL (脚本路径)
    public var url: String
    /// Worker 选项
    public var options: WorkerOptions
    /// 消息总线
    private var messageBus: WorkerMessageBus
    /// Worker 状态
    public var state: WorkerState
    /// Worker 线程
    private var workerThread: ?Thread
    /// 消息监听器 (主线程端)
    private var messageListeners: ArrayList<(JsValue) -> Unit>
    /// 错误监听器
    private var errorListeners: ArrayList<(String) -> Unit>
    /// 关闭监听器
    private var closeListeners: ArrayList<() -> Unit>
    /// 错误事件监听器
    private var messageErrorListeners: ArrayList<(JsValue) -> Unit>

    public init(url: String) {
        this.url = url
        options = WorkerOptions()
        messageBus = WorkerMessageBus()
        state = WorkerState.Starting
        workerThread = None
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
        workerThread = None
        messageListeners = ArrayList<(JsValue) -> Unit>()
        errorListeners = ArrayList<(String) -> Unit>()
        closeListeners = ArrayList<() -> Unit>()
        messageErrorListeners = ArrayList<(JsValue) -> Unit>()
    }

    /// 启动 Worker - 对应 new Worker(url) 后自动启动
    public func start(): Unit {
        if (state != WorkerState.Starting) {
            return
        }

        let bus = messageBus
        let workerUrl = url
        let workerOpts = options
        let worker = this

        // 生成 Worker 线程
        workerThread = Some(spawn {
            workerRunLoop(bus, workerUrl, workerOpts)
        })

        state = WorkerState.Running

        // 注册消息总线监听器
        messageBus.onMainMessage() { value =>
            // 通知 Worker 消息给主线程的监听器
            for (listener in worker.messageListeners) {
                listener(value)
            }
        }
    }

    /// Worker 线程运行循环
    private func workerRunLoop(bus: WorkerMessageBus, scriptUrl: String, opts: WorkerOptions): Unit {
        let ctx = WorkerContext(bus)
        ctx.name = opts.name

        // 创建 Worker 内的虚拟机
        let interpreter = ctx.vm.getInterpreter()
        let env = interpreter.getGlobalEnv()

        // 注册 self / globalThis
        let selfValue = ctx.toSelfJsValue()
        env.define("self", selfValue, false)
        env.define("globalThis", selfValue, false)

        // 注册 onmessage
        env.define("onmessage", JsValue.UNDEFINED, true)

        // 注册 importScripts (经典 Worker)
        env.define("importScripts", Interpreter.makeNativeFn("importScripts") { args =>
            // 简化: 加载并执行脚本
            for (arg in args) {
                let scriptPath = Interpreter.jsToString(arg)
                try {
                    ctx.vm.executeFile(scriptPath)
                } catch (_: Exception) {
                    // 忽略加载错误
                }
            }
            return JsValue.UNDEFINED
        }, false)

        // 执行 Worker 脚本
        try {
            let source = match (opts.source) {
                case Some(src) => src
                case None => BaoFile.readAllText(scriptUrl)
            }
            ctx.vm.eval(source, scriptUrl)

            // 进入消息循环
            while (true) {
                // 检查来自主线程的消息
                bus.pollWorkerMessages()

                // 检查是否有 onmessage
                match (env.lookup("onmessage")) {
                    case Some(handler) =>
                        // 尝试从消息总线获取消息
                        while (true) {
                            let msg = bus.receiveInWorker()
                            match (msg) {
                                case Some(value) =>
                                    // 调用 onmessage handler
                                    match (handler.nativeFnData) {
                                        case Some(nf) =>
                                            let args = ArrayList<JsValue>()
                                            let dataObj = JsObject()
                                            dataObj.set("data", value)
                                            args.append(JsValue(dataObj))
                                            nf.fn(args)
                                        case None => ()
                                    }
                                    match (handler.functionData) {
                                        case Some(fn) =>
                                            // JS 函数调用需要 Interpreter
                                            ()
                                        case None => ()
                                    }
                                case None => break
                            }
                        }
                    case None => ()
                }

                bao_sys.SysModule.sleep(1)
            }
        } catch (e: Exception) {
            // Worker 错误
            bus.postToMain(JsValue(BaoString("error: ${e.message}")))
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
    /// 对应 Bun: worker.terminate()
    public func terminate(): Unit {
        if (state == WorkerState.Terminated) {
            return
        }
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

        // onmessage 占位
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

/// Worker 模块导出
public class WorkerModule {
    /// 将 Worker 类导出为 JsValue
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        // Worker 构造函数
        obj.set("Worker", JsValue.nativeFunction(JsNativeFunction("Worker") { args =>
            if (args.size >= 1) {
                let url = Interpreter.jsToString(args[0])
                let worker = Worker(url)
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

        return JsValue(obj)
    }
}
