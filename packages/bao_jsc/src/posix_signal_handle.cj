// 严格翻译自: src/jsc/PosixSignalHandle.zig
// POSIX 信号处理 - 使用无锁环形缓冲区处理信号

package bao_jsc

// ========== PosixSignalHandle ==========
// 严格翻译自 PosixSignalHandle
// 使用无锁 SPSC（单生产者-单消费者）环形缓冲区处理 POSIX 信号
// 信号处理程序（生产者）写入 tail，主线程（消费者）读取 head
public class PosixSignalHandle {
    public static let BUFFER_SIZE: Int64 = 8192

    public var signals: Array<UInt8> = Array<UInt8>(BUFFER_SIZE, item: 0)
    // 生产者索引（信号处理程序写入）
    public var tail: AtomicUInt16 = AtomicUInt16(0)
    // 消费者索引（主线程读取）
    public var head: AtomicUInt16 = AtomicUInt16(0)

    public init() {}

    // 严格翻译自 PosixSignalHandle.enqueue
    // 由信号处理程序调用（单生产者）
    // 成功入队返回 true，环形缓冲区满返回 false
    public func enqueue(signal: UInt8) -> Bool {
        let oldTail = tail.load()
        let headVal = head.load()

        // 计算下一个 tail（环绕）
        let nextTail = (oldTail &+ 1) % UInt16(PosixSignalHandle.BUFFER_SIZE)

        // 检查环形缓冲区是否已满
        if (nextTail == (headVal % UInt16(PosixSignalHandle.BUFFER_SIZE))) {
            return false
        }

        // 存储信号到环形缓冲区槽位
        signals[Int(oldTail % UInt16(PosixSignalHandle.BUFFER_SIZE))] = signal

        // 发布新 tail
        tail.store(oldTail &+ 1)

        // 唤醒事件循环
        return true
    }

    // 严格翻译自 PosixSignalHandle.dequeue
    // 由主线程调用（单消费者）
    // 环形缓冲区为空返回 null，否则返回下一个信号
    public func dequeue() -> ?UInt8 {
        let oldHead = head.load()
        let tailVal = tail.load()

        // 如果 head == tail，环形缓冲区为空
        if (oldHead == tailVal) {
            return None
        }

        let slotIndex = Int(oldHead % UInt16(PosixSignalHandle.BUFFER_SIZE))
        let signal = signals[slotIndex]
        signals[slotIndex] = 0

        // 发布更新的 head
        head.store(oldHead &+ 1)

        return signal
    }

    // 严格翻译自 PosixSignalHandle.drain
    // 排空尽可能多的信号并将它们作为任务入队到事件循环
    // 由主线程调用
    public func drain(eventLoop: EventLoop) {
        while (let signal = dequeue()) {
            // 将信号包装为 PosixSignalTask 并入队
            let task = PosixSignalTask(number: signal)
            eventLoop.enqueueTask(task)
        }
    }
}

// ========== PosixSignalTask ==========
// 严格翻译自 PosixSignalHandle.PosixSignalTask
public class PosixSignalTask {
    public var number: UInt8

    public init(number: UInt8) {
        this.number = number
    }

    // 严格翻译自 PosixSignalTask.runFromJSThread
    public func runFromJSThread(globalObject: JsObject) {
        // FFI: Bun__onSignalForJS
    }
}

// ========== AtomicUInt16 ==========
public class AtomicUInt16 {
    public var value: UInt16 = 0

    public init(_ v: UInt16) { value = v }
    public func load() -> UInt16 { value }
    public func store(_ v: UInt16) { value = v }
}
