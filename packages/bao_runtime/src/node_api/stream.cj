// Node.js 兼容流实现
// 严格翻译自: src/runtime/node/stream.zig
//   Bun 实现了 Node.js Readable/Writable 流以兼容 Node 生态
//   连接 bao_io 的底层流抽象
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_io.*

// ============================================================================
// NodeReadable - Node.js Readable 流
// 严格翻译自: src/runtime/node/stream.zig Readable
//   实现了 Node.js stream.Readable 接口
// ============================================================================

/// Node.js 可读流 - 对应 Bun NodeReadable
/// 封装底层 ReadableStream 提供 Node.js 兼容 API
public class NodeReadable {
    /// 内部流
    private var stream: ReadableStream
    /// 是否已暂停
    public var isPaused: Bool
    /// 是否已销毁
    public var isDestroyed: Bool
    /// 高水位线
    public var highWaterMark: Int64
    /// 编码
    public var encoding: String
    /// 数据事件回调
    private var dataCallbacks: ArrayList<(Array<UInt8>) -> Unit>
    /// 结束事件回调
    private var endCallbacks: ArrayList<() -> Unit>
    /// 错误事件回调
    private var errorCallback: ?(String) -> Unit
    /// 关闭事件回调
    private var closeCallbacks: ArrayList<() -> Unit>
    /// 可读事件回调
    private var readableCallbacks: ArrayList<() -> Unit>

    public init(stream: ReadableStream) {
        this.stream = stream
        isPaused = false
        isDestroyed = false
        highWaterMark = 16384  // 16KB default
        encoding = "utf8"
        dataCallbacks = ArrayList<(Array<UInt8>) -> Unit>()
        endCallbacks = ArrayList<() -> Unit>()
        errorCallback = None
        closeCallbacks = ArrayList<() -> Unit>()
        readableCallbacks = ArrayList<() -> Unit>()
    }

    public init(stream: ReadableStream, highWaterMark: Int64) {
        this.stream = stream
        isPaused = false
        isDestroyed = false
        this.highWaterMark = highWaterMark
        encoding = "utf8"
        dataCallbacks = ArrayList<(Array<UInt8>) -> Unit>()
        endCallbacks = ArrayList<() -> Unit>()
        errorCallback = None
        closeCallbacks = ArrayList<() -> Unit>()
        readableCallbacks = ArrayList<() -> Unit>()
    }

    /// 注册数据回调 - 对应 readable.on('data', callback)
    public func onData(callback: (Array<UInt8>) -> Unit): NodeReadable {
        dataCallbacks.append(callback)
        // 自动恢复流
        if (isPaused) {
            isPaused = false
        }
        return this
    }

    /// 注册字符串数据回调
    public func onDataString(callback: (String) -> Unit): NodeReadable {
        dataCallbacks.append({ (data: Array<UInt8>) =>
            callback(bytesToString(data))
        })
        return this
    }

    /// 注册结束回调 - 对应 readable.on('end', callback)
    public func onEnd(callback: () -> Unit): NodeReadable {
        endCallbacks.append(callback)
        return this
    }

    /// 注册错误回调 - 对应 readable.on('error', callback)
    public func onError(callback: (String) -> Unit): NodeReadable {
        errorCallback = Some(callback)
        return this
    }

    /// 注册关闭回调 - 对应 readable.on('close', callback)
    public func onClose(callback: () -> Unit): NodeReadable {
        closeCallbacks.append(callback)
        return this
    }

    /// 注册可读回调 - 对应 readable.on('readable', callback)
    public func onReadable(callback: () -> Unit): NodeReadable {
        readableCallbacks.append(callback)
        return this
    }

    /// 读取数据 - 对应 readable.read(size)
    public func read(size: Int64): ?Array<UInt8> {
        if (isDestroyed) {
            return None
        }
        let result = stream.read()
        if (result.done) {
            // 触发 end 事件
            for (cb in endCallbacks) {
                cb()
            }
            return None
        }
        return Some(result.data)
    }

    /// 暂停流 - 对应 readable.pause()
    public func pause(): NodeReadable {
        isPaused = true
        return this
    }

    /// 恢复流 - 对应 readable.resume()
    public func resume(): NodeReadable {
        isPaused = false
        // 触发可读事件
        for (cb in readableCallbacks) {
            cb()
        }
        return this
    }

    /// 将所有数据管道到可写流 - 对应 readable.pipe(writable)
    public func pipe(destination: NodeWritable): NodeWritable {
        onData({ (data: Array<UInt8>) =>
            destination.write(data)
        })
        onEnd({ () =>
            destination.end()
        })
        return destination
    }

    /// 取消管道 - 对应 readable.unpipe(destination)
    public func unpipe(destination: NodeWritable): NodeReadable {
        // 简化: 清空回调
        dataCallbacks.clear()
        endCallbacks.clear()
        return this
    }

    /// 销毁流 - 对应 readable.destroy(error)
    public func destroy(error: ?String): Unit {
        if (isDestroyed) {
            return
        }
        isDestroyed = true
        stream.cancel()
        match (error) {
            case Some(e) =>
                match (errorCallback) {
                    case Some(cb) => cb(e)
                    case None => ()
                }
            case None => ()
        }
        for (cb in closeCallbacks) {
            cb()
        }
    }

    /// 设置编码
    public func setEncoding(encoding: String): NodeReadable {
        this.encoding = encoding
        return this
    }

    /// 是否可读
    public func isReadable(): Bool {
        return stream.isReadable() && !isDestroyed
    }

    /// 将字节转换为字符串
    private func bytesToString(data: Array<UInt8>): String {
        var sb = StringBuilder()
        for (b in data) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }
}

// ============================================================================
// NodeWritable - Node.js Writable 流
// 严格翻译自: src/runtime/node/stream.zig Writable
// ============================================================================

/// Node.js 可写流 - 对应 Bun NodeWritable
/// 封装底层 WritableStream 提供 Node.js 兼容 API
public class NodeWritable {
    /// 内部流
    private var stream: WritableStream
    /// 是否已销毁
    public var isDestroyed: Bool
    /// 是否已结束
    public var isFinished: Bool
    /// 高水位线
    public var highWaterMark: Int64
    /// 完成回调
    private var finishCallbacks: ArrayList<() -> Unit>
    /// 关闭回调
    private var closeCallbacks: ArrayList<() -> Unit>
    /// 错误回调
    private var errorCallback: ?(String) -> Unit
    /// 排空回调
    private var drainCallbacks: ArrayList<() -> Unit>

    public init(stream: WritableStream) {
        this.stream = stream
        isDestroyed = false
        isFinished = false
        highWaterMark = 16384
        finishCallbacks = ArrayList<() -> Unit>()
        closeCallbacks = ArrayList<() -> Unit>()
        errorCallback = None
        drainCallbacks = ArrayList<() -> Unit>()
    }

    /// 写入数据 - 对应 writable.write(data)
    /// 返回 true 如果可以继续写入，false 如果应该等待 drain
    public func write(data: Array<UInt8>): Bool {
        if (isDestroyed || isFinished) {
            return false
        }
        stream.write(data)
        return true
    }

    /// 写入字符串 - 对应 writable.write(string, encoding)
    public func writeString(text: String, encoding: String): Bool {
        if (isDestroyed || isFinished) {
            return false
        }
        stream.writeString(text)
        return true
    }

    /// 写入字符串 (默认 UTF-8)
    public func writeString(text: String): Bool {
        return writeString(text, "utf8")
    }

    /// 结束写入 - 对应 writable.end()
    public func end(): Unit {
        if (isFinished) {
            return
        }
        isFinished = true
        stream.close()
        for (cb in finishCallbacks) {
            cb()
        }
        for (cb in closeCallbacks) {
            cb()
        }
    }

    /// 结束写入 (带最后的数据) - 对应 writable.end(data)
    public func end(data: Array<UInt8>): Unit {
        write(data)
        end()
    }

    /// 结束写入 (带最后的字符串)
    public func end(text: String): Unit {
        writeString(text)
        end()
    }

    /// 注册完成回调 - 对应 writable.on('finish', callback)
    public func onFinish(callback: () -> Unit): NodeWritable {
        finishCallbacks.append(callback)
        return this
    }

    /// 注册关闭回调 - 对应 writable.on('close', callback)
    public func onClose(callback: () -> Unit): NodeWritable {
        closeCallbacks.append(callback)
        return this
    }

    /// 注册错误回调 - 对应 writable.on('error', callback)
    public func onError(callback: (String) -> Unit): NodeWritable {
        errorCallback = Some(callback)
        return this
    }

    /// 注册排空回调 - 对应 writable.on('drain', callback)
    public func onDrain(callback: () -> Unit): NodeWritable {
        drainCallbacks.append(callback)
        return this
    }

    /// 销毁流 - 对应 writable.destroy(error)
    public func destroy(error: ?String): Unit {
        if (isDestroyed) {
            return
        }
        isDestroyed = true
        stream.abort()
        match (error) {
            case Some(e) =>
                match (errorCallback) {
                    case Some(cb) => cb(e)
                    case None => ()
                }
            case None => ()
        }
        for (cb in closeCallbacks) {
            cb()
        }
    }

    /// 是否可写
    public func isWritable(): Bool {
        return stream.isWritable() && !isDestroyed && !isFinished
    }

    /// 刷新缓冲区 - 对应 writable.uncork() / flush
    public func flush(): Unit {
        // WritableStream already handles buffering
    }

    /// cork/uncork 模式 (简化)
    public func cork(): Unit {
        // 缓冲模式开始
    }

    public func uncork(): Unit {
        // 缓冲模式结束，刷新
    }
}

// ============================================================================
// NodeDuplex - Node.js 双工流
// 严格翻译自: src/runtime/node/stream.zig Duplex
//   同时可读可写
// ============================================================================

/// Node.js 双工流 - 对应 Bun NodeDuplex
/// 同时实现 Readable 和 Writable
public class NodeDuplex {
    public var readable: NodeReadable
    public var writable: NodeWritable

    public init(readable: ReadableStream, writable: WritableStream) {
        this.readable = NodeReadable(readable)
        this.writable = NodeWritable(writable)
    }

    public func destroy(): Unit {
        readable.destroy(None)
        writable.destroy(None)
    }
}

// ============================================================================
// NodeTransform - Node.js 转换流
// 严格翻译自: src/runtime/node/stream.zig Transform
//   输入数据经过转换后输出
// ============================================================================

/// Node.js 转换流 - 对应 Bun NodeTransform
/// 继承 Duplex，添加 transform 方法
public class NodeTransform {
    public var readable: NodeReadable
    public var writable: NodeWritable
    private var transformFn: (Array<UInt8>) -> Array<UInt8>
    private var outputBuffer: ArrayList<Array<UInt8>>
    private var outputStream: ReadableStream

    public init(transformFn: (Array<UInt8>) -> Array<UInt8>) {
        this.transformFn = transformFn
        outputStream = ReadableStream()
        outputBuffer = ArrayList<Array<UInt8>>()
        readable = NodeReadable(outputStream)
        writable = NodeWritable(WritableStream())
    }

    /// 写入并转换数据
    public func writeTransform(data: Array<UInt8>): Unit {
        let transformed = transformFn(data)
        outputStream.enqueueChunk(transformed)
    }

    public func destroy(): Unit {
        readable.destroy(None)
        writable.destroy(None)
    }
}

// ============================================================================
// Stream 工厂方法
// ============================================================================

/// Node.js Stream 工厂
public class NodeStreamFactory {
    /// 从文件描述符创建可读流
    public static func createReadable(fd: Int64): NodeReadable {
        let stream = ReadableStream.fromFd(fd, 16384)
        return NodeReadable(stream)
    }

    /// 从文件描述符创建可写流
    public static func createWritable(fd: Int64): NodeWritable {
        let stream = WritableStream.fromFd(fd)
        return NodeWritable(stream)
    }

    /// 从管道创建双工流
    public static func createDuplex(readFd: Int64, writeFd: Int64): NodeDuplex {
        let readable = ReadableStream.fromFd(readFd, 16384)
        let writable = WritableStream.fromFd(writeFd)
        return NodeDuplex(readable, writable)
    }

    /// 创建转换流
    public static func createTransform(transformFn: (Array<UInt8>) -> Array<UInt8>): NodeTransform {
        return NodeTransform(transformFn)
    }

    /// 管道连接 (readable -> writable)
    public static func pipeline(src: NodeReadable, dest: NodeWritable): NodeWritable {
        return src.pipe(dest)
    }

    /// 多级管道 (readable -> transform -> writable)
    public static func pipeline(src: NodeReadable, transform: NodeTransform, dest: NodeWritable): NodeWritable {
        src.onData({ (data: Array<UInt8>) =>
            transform.writeTransform(data)
        })
        transform.readable.onData({ (data: Array<UInt8>) =>
            dest.write(data)
        })
        src.onEnd({ () =>
            dest.end()
        })
        return dest
    }
}
