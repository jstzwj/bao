// 严格翻译自: src/jsc/JSONLineBuffer.zig
// JSON 行缓冲区 - 用于跟踪扫描位置以避免 O(n^2) 扫描的换行分隔数据缓冲区

package bao_jsc

// ========== JSONLineBuffer ==========
// 严格翻译自 JSONLineBuffer
// 用于换行分隔数据的缓冲区，跟踪扫描位置以避免 O(n^2) 扫描
// 每个字节只扫描一次。我们跟踪:
// - newlinePos: 第一个已知换行符的位置（如果有）
// - scannedPos: 我们扫描了多远（此之前的字节已检查）
// - head: 缓冲区中未消费数据开始的偏移量（避免每次消费时复制）
public class JSONLineBuffer {
    public var data: ByteList = ByteList()
    // 未消费内容开始的偏移量
    public var head: UInt32 = 0
    // 相对于 head 的已知即将到来的换行符位置
    public var newlinePos: ?UInt32 = None
    // 相对于 head 已扫描换行符的距离
    public var scannedPos: UInt32 = 0

    // 当 head 超过此阈值时压缩缓冲区
    public static let compactionThreshold: UInt32 = 16 * 1024 * 1024  // 16 MB

    public init() {}

    // 严格翻译自 JSONLineBuffer.activeSlice
    // 获取活动（未消费的）缓冲区部分
    public func activeSlice() -> Array<Byte> {
        if (head >= data.len) {
            return []
        }
        data.slice(head)
    }

    // 严格翻译自 JSONLineBuffer.scanForNewline
    // 在缓冲区的未扫描部分中扫描换行符
    public func scanForNewline() {
        if (newlinePos != None) { return }
        let slice = activeSlice()
        let scannedPosInt = scannedPos
        if (scannedPosInt >= slice.size) { return }

        let unscanned = slice[Int(scannedPosInt):]
        if (let idx = unscanned.indexOf(Character('\n'))) {
            let pos = scannedPosInt + UInt32(idx)
            newlinePos = pos
            scannedPos = pos + 1  // 只扫描到（并包括）换行符
        } else {
            scannedPos = UInt32(slice.size)  // 没有换行符，扫描了所有内容
        }
    }

    // 严格翻译自 JSONLineBuffer.compact
    // 通过将数据移到前面来压缩缓冲区。当 head 超过阈值时调用。
    public func compact() {
        if (head == 0) { return }
        let slice = activeSlice()
        data = ByteList(slice)
        head = 0
    }

    // 严格翻译自 JSONLineBuffer.append
    // 将字节追加到缓冲区，只扫描新数据中的换行符
    public func append(bytes: Array<Byte>) {
        data.write(bytes)
        scanForNewline()
    }

    // 严格翻译自 JSONLineBuffer.next
    // 如果可用，返回下一个完整消息（直到并包括换行符）
    public func next() -> ?JSONLineBufferEntry {
        if let pos = newlinePos {
            let slice = activeSlice()
            if (Int(pos) + 1 <= slice.size) {
                return JSONLineBufferEntry(
                    data: slice[0..Int(pos) + 1],
                    newlinePos: pos
                )
            }
        }
        None
    }

    // 严格翻译自 JSONLineBuffer.consume
    // 处理消息后从缓冲区前端消费字节
    // 只是前进 head 偏移量 - 在达到压缩阈值之前不复制
    public func consume(bytes: UInt32) {
        head = head &+ bytes

        // 调整 scannedPos（减去消费的字节，但不低于零）
        scannedPos = if (bytes >= scannedPos) { 0 } else { scannedPos - bytes }

        // 调整 newlinePos
        if let pos = newlinePos {
            if (bytes > pos) {
                // 消费超过了已知换行符 - 清除并扫描下一个
                newlinePos = None
                scanForNewline()
            } else {
                newlinePos = pos - bytes
            }
        }

        // 检查是否消费了所有内容
        if (head >= data.len) {
            if (data.cap >= JSONLineBuffer.compactionThreshold) {
                data = ByteList()
            } else {
                data.len = 0
            }
            head = 0
            scannedPos = 0
            newlinePos = None
            return
        }

        // 如果 head 超过阈值则压缩
        if (head >= JSONLineBuffer.compactionThreshold) {
            compact()
        }
    }

    // 严格翻译自 JSONLineBuffer.isEmpty
    public func isEmpty() -> Bool {
        head >= data.len
    }

    // 严格翻译自 JSONLineBuffer.unusedCapacitySlice
    public func unusedCapacitySlice() -> Array<Byte> {
        data.unusedCapacitySlice()
    }

    // 严格翻译自 JSONLineBuffer.ensureUnusedCapacity
    public func ensureUnusedCapacity(additional: Int64) {
        data.ensureUnusedCapacity(additional)
    }

    // 严格翻译自 JSONLineBuffer.notifyWritten
    // 通知缓冲区数据已直接写入（例如通过预分配的切片）
    public func notifyWritten(newData: Array<Byte>) {
        data.len += UInt32(newData.size)
        scanForNewline()
    }

    // 严格翻译自 JSONLineBuffer.deinit
    public func deinit() {
        data = ByteList()
        head = 0
        scannedPos = 0
        newlinePos = None
    }
}

// ========== JSONLineBufferEntry ==========
public class JSONLineBufferEntry {
    public var data: Array<Byte> = []
    public var newlinePos: UInt32 = 0

    public init() {}
    public init(data: Array<Byte>, newlinePos: UInt32) {
        this.data = data
        this.newlinePos = newlinePos
    }
}

// ========== ByteList ==========
// 模拟 bun.ByteList
public class ByteList {
    public var len: UInt32 = 0
    public var cap: UInt32 = 0
    public var buffer: Array<Byte> = []

    public init() {}
    public init(_ bytes: Array<Byte>) {
        buffer = bytes
        len = UInt32(bytes.size)
        cap = len
    }

    public func slice(_ from: UInt32) -> Array<Byte> {
        if (Int(from) >= buffer.size) { return [] }
        buffer[Int(from):]
    }

    public func write(_ bytes: Array<Byte>) {
        for (b in bytes) {
            buffer.append(b)
        }
        len = UInt32(buffer.size)
        cap = len
    }

    public func unusedCapacitySlice() -> Array<Byte> { [] }
    public func ensureUnusedCapacity(_ additional: Int64) {}
}
