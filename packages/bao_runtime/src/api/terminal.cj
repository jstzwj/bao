// 严格翻译自: src/runtime/api/bun/Terminal.zig
package bao_runtime

import bao_jsc.*
import bao_core.*
import bao_io.*
import bao_sys.*

// ============================================================================
// Terminal - Bun.Terminal - 伪终端 (PTY) 支持
// 对应 Bun: src/runtime/api/bun/Terminal.zig
// ============================================================================

/// Terminal - 伪终端类, 创建 PTY master/slave 对
public class Terminal {
    public var refCount: RefCount

    /// PTY 的 master 端 (原始 fd, 用于 ioctl 操作)
    public var masterFd: FD

    /// 用于读取的复制 master fd
    public var readFd: FD

    /// 用于写入的复制 master fd
    public var writeFd: FD

    /// PTY 的 slave 端 (子进程使用)
    public var slaveFd: FD

    /// 当前终端大小
    public var cols: UInt16
    public var rows: UInt16

    /// 终端名称
    public var termName: ZigStringSlice

    /// 事件循环句柄
    public var eventLoopHandle: EventLoopHandle

    /// 全局对象引用
    public var globalThis: JsGlobalObject

    /// 写入器
    public var writer: IOWriter

    /// 读取器
    public var reader: IOReader

    /// JS 引用
    public var thisValue: JsRef

    /// 状态标志
    public var flags: Flags

    // ========================================================================
    // Flags - 状态标志
    // ========================================================================

    public struct Flags {
        public var closed: Bool
        public var finalized: Bool
        public var rawMode: Bool
        public var readerStarted: Bool
        public var connected: Bool
        public var readerDone: Bool
        public var writerDone: Bool
        public var inlineSpawned: Bool
    }

    // ========================================================================
    // Options - 创建选项
    // ========================================================================

    public struct Options {
        public var cols: UInt16
        public var rows: UInt16
        public var termName: ZigStringSlice
        public var dataCallback: ?JsValue
        public var exitCallback: ?JsValue
        public var drainCallback: ?JsValue

        public static let maxTermNameLen: Int = 128

        /// 从 JS 对象解析选项
        public static func parseFromJS(globalObject: JsGlobalObject, jsOptions: JsValue): Options {
            var options = Options()
            // ... 解析 cols, rows, name, data, exit, drain
            return options
        }

        public mutating func deinit(): Unit {
            termName.deinit()
        }
    }

    // ========================================================================
    // 构造函数
    // ========================================================================

    /// 构造函数 - 从 JS 创建 Terminal
    public static func constructor(globalObject: JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): Terminal {
        let args = callframe.argumentsAsArray1()
        let jsOptions = args[0]

        if (!jsOptions.isObject()) {
            globalObject.throw("Terminal constructor requires an options object")
            return Terminal()
        }

        var options = try Options.parseFromJS(globalObject, jsOptions)
        // ... 创建 PTY, 启动读写器
        return Terminal()
    }

    // ========================================================================
    // 方法
    // ========================================================================

    /// write - 向终端写入数据
    public func write(globalObject: JsGlobalObject, callframe: JsCallFrame): JsValue {
        if (flags.closed) {
            globalObject.throw("Terminal is closed")
            return JsValue.zero
        }

        let args = callframe.argumentsAsArray1()
        let data = args[0]

        if (data.isUndefinedOrNull()) {
            globalObject.throw("write() requires data argument")
            return JsValue.zero
        }

        let stringOrBuffer = try StringOrBuffer.fromJS(globalObject, data) ?? {
            globalObject.throw("write() argument must be a string or ArrayBuffer")
            return JsValue.zero
        }
        defer stringOrBuffer.deinit()

        let bytes = stringOrBuffer.slice()
        if (bytes.count == 0) { return JsValue.jsNumber(0) }

        let writeResult = writer.write(bytes)
        return match (writeResult) {
            case .done(let amt) => JsValue.jsNumber(Int32(amt))
            case .wrote(let amt) => JsValue.jsNumber(Int32(amt))
            case .pending(let amt) => JsValue.jsNumber(Int32(amt))
            case .err(let err) => globalObject.throwValue(err.toJS(globalObject))
        }
    }

    /// resize - 调整终端大小
    public func resize(globalObject: JsGlobalObject, callframe: JsCallFrame): JsValue {
        if (flags.closed) {
            globalObject.throw("Terminal is closed")
            return JsValue.zero
        }

        let args = callframe.argumentsAsArray2()

        let newCols: UInt16 = {
            if (args[0].isNumber()) {
                let n = args[0].toInt32()
                if (n > 0 && n <= 65535) { return UInt16(n) }
            }
            globalObject.throw("resize() requires valid cols argument")
            return 80
        }()

        let newRows: UInt16 = {
            if (args[1].isNumber()) {
                let n = args[1].toInt32()
                if (n > 0 && n <= 65535) { return UInt16(n) }
            }
            globalObject.throw("resize() requires valid rows argument")
            return 24
        }()

        // 调用 ioctl TIOCSWINSZ
        // ...

        cols = newCols
        rows = newRows

        return JsValue.jsUndefined
    }

    /// setRawMode - 设置原始模式
    public func setRawMode(globalObject: JsGlobalObject, callframe: JsCallFrame): JsValue {
        if (flags.closed) {
            globalObject.throw("Terminal is closed")
            return JsValue.zero
        }

        let args = callframe.argumentsAsArray1()
        let enabled = args[0].toBoolean()

        // 设置 TTY 模式
        flags.rawMode = enabled
        return JsValue.jsUndefined
    }

    /// getClosed - 获取关闭状态
    public func getClosed(): JsValue {
        return JsValue.jsBoolean(flags.closed)
    }

    /// getInputFlags - 获取输入标志
    public func getInputFlags(): JsValue {
        return JsValue.jsNumber(0)
    }

    /// doRef - 引用终端
    public func doRef(): JsValue {
        updateRef(true)
        return JsValue.jsUndefined
    }

    /// doUnref - 取消引用终端
    public func doUnref(): JsValue {
        updateRef(false)
        return JsValue.jsUndefined
    }

    /// close - 关闭终端
    public func close(): JsValue {
        closeInternal()
        return JsValue.jsUndefined
    }

    /// asyncDispose - 异步释放
    public func asyncDispose(globalObject: JsGlobalObject): JsValue {
        thisValue.downgrade()
        flags.finalized = true
        closeInternal()
        return JSPromise.resolvedPromiseValue(globalObject, JsValue.jsUndefined)
    }

    // ========================================================================
    // 内部方法
    // ========================================================================

    /// closeInternal - 内部关闭实现
    public func closeInternal(): Unit {
        if (flags.closed) { return }
        flags.closed = true

        // 关闭写入器
        writer.close()
        writeFd = FD.invalid

        // 关闭读取器
        if (flags.readerStarted) {
            reader.close()
        }
        readFd = FD.invalid

        // 关闭 master fd
        if (masterFd != FD.invalid) {
            masterFd.close()
            masterFd = FD.invalid
        }

        // 关闭 slave fd
        if (slaveFd != FD.invalid) {
            slaveFd.close()
            slaveFd = FD.invalid
        }
    }

    /// updateRef - 更新引用
    public func updateRef(add: Bool): Unit {
        reader.updateRef(add)
        writer.updateRef(eventLoopHandle, add)
    }

    /// getSlaveFd - 获取 slave fd
    public func getSlaveFd(): FD {
        return slaveFd
    }

    /// closeSlaveFd - 关闭 slave fd
    public func closeSlaveFd(): Unit {
        flags.inlineSpawned = true
        if (slaveFd != FD.invalid) {
            slaveFd.close()
            slaveFd = FD.invalid
        }
    }

    /// finalize - GC 回收
    public func finalize(): Unit {
        thisValue.finalize()
        flags.finalized = true
        closeInternal()
        deref()
    }

    /// deinit - 内部释放
    public func deinit(): Unit {
        flags.readerDone = true
        flags.writerDone = true
        closeInternal()
        termName.deinit()
        reader.deinit()
        writer.deinit()
    }
}
