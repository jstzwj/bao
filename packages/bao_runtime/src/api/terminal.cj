// 翻译自: src/runtime/api/bun/Terminal.zig
//   Terminal — 伪终端 (PTY) 管理
//   创建 PTY master/slave 对，允许 JS 代码与终端程序交互
//
// 生命周期:
//   - 以弱 JSRef 启动 (允许 GC 回收)
//   - 读写时升级为强引用
//   - master_fd 收到 EOF 时降级为弱引用
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame}

// ============================================================================
// Terminal — 伪终端 (PTY)
// 翻译自: src/runtime/api/bun/Terminal.zig:1-1220
//   const Terminal = @This();
// ============================================================================

public class Terminal {
    /// PTY master fd (原始 fd，用于 ioctl 操作)
    /// Windows 上始终为 invalid_fd；ConPTY 使用 hpcon
    private var masterFd: FD = FD.invalid

    /// 复制的 master fd 用于读取 (POSIX) / 重叠读取管道端 (Windows)
    private var readFd: FD = FD.invalid

    /// 复制的 master fd 用于写入 (POSIX) / 重叠写入管道端 (Windows)
    private var writeFd: FD = FD.invalid

    /// PTY slave fd (子进程使用)。Windows 上未使用。
    private var slaveFd: FD = FD.invalid

    /// 当前终端大小
    private var cols: UInt16 = 80
    private var rows: UInt16 = 24

    /// 终端名称 (例如 "xterm-256color")
    private var termName: String = "xterm-256color"

    /// 全局对象引用
    private var globalThis: JsGlobalObject = JsGlobalObject()

    /// this 值引用 (用于 GC 跟踪)
    private var thisValue: JsValue = JsValue.jsUndefined()

    /// 状态标志
    private var closed: Bool = false
    private var finalized: Bool = false
    private var rawMode: Bool = false
    private var readerStarted: Bool = false
    private var connected: Bool = false
    private var readerDone: Bool = false
    private var writerDone: Bool = false
    private var inlineSpawned: Bool = false

    public init() {}

    // ========================================================================
    // 构造函数
    // 翻译自: Terminal.zig:292-318
    //   pub fn constructor(globalObject, callframe, this_value) -> bun.JSError!*Terminal
    // ========================================================================

    /// 构造函数 — 从 JavaScript 调用
    /// 翻译自: Terminal.zig:292-318
    public static func constructor(globalThis!: JsGlobalObject, callframe!: JsCallFrame, thisValue!: JsValue): JsValue {
        // 解析选项
        // TODO(bao-runtime-api): 从 callframe 解析 options 对象
        //   1. 解析 cols, rows, name
        //   2. 解析 data/exit/drain 回调
        //   3. 创建 PTY (openpty)
        //   4. 启动 reader/writer
        //   5. 设置 this_value 引用

        // 当前返回占位值
        JsValue.jsUndefined()
    }

    // ========================================================================
    // PTY 创建
    // 翻译自: Terminal.zig:401-621
    //   fn createPty(cols, rows) -> CreatePtyError!PtyResult
    // ========================================================================

    /// 创建 PTY (POSIX)
    /// 翻译自: Terminal.zig:485-621
    ///   fn createPtyPosix(cols, rows) -> CreatePtyError!PtyResult
    private static func createPtyPosix(cols: UInt16, rows: UInt16): ?Terminal {
        // TODO(bao-runtime-api): 实现 openpty
        //   1. 调用 openpty(&master_fd, &slave_fd, null, null, &winsize)
        //   2. 配置 termios (cooked mode defaults)
        //   3. 复制 master_fd 用于读写 (dup)
        //   4. 设置非阻塞 (O_NONBLOCK)
        //   5. 设置 close-on-exec
        None
    }

    // ========================================================================
    // 读写操作
    // 翻译自: Terminal.zig:808-846
    //   pub fn write(this, globalObject, callframe) -> bun.JSError!JSValue
    // ========================================================================

    /// 写入数据到终端
    /// 翻译自: Terminal.zig:808-846
    ///   pub fn write(this, globalObject, callframe) -> bun.JSError!JSValue
    public func write(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        if (closed) {
            return JsValue.jsUndefined()
        }
        // TODO(bao-runtime-api): 获取数据参数并写入 writer
        //   1. 从 callframe 获取 data 参数
        //   2. 转为字节数组
        //   3. 调用 writer.write(bytes)
        JsValue.jsUndefined()
    }

    /// 调整终端大小
    /// 翻译自: Terminal.zig:849-917
    ///   pub fn resize(this, globalObject, callframe) -> bun.JSError!JSValue
    public func resize(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        if (closed) {
            return JsValue.jsUndefined()
        }
        // TODO(bao-runtime-api): 解析 cols/rows 参数
        //   1. 从 callframe 获取 cols, rows
        //   2. 调用 ioctl(master_fd, TIOCSWINSZ, &winsize)
        //   3. 更新 this.cols, this.rows
        JsValue.jsUndefined()
    }

    /// 设置原始模式
    /// 翻译自: Terminal.zig:920-942
    ///   pub fn setRawMode(this, globalObject, callframe) -> bun.JSError!JSValue
    public func setRawMode(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        if (closed) {
            return JsValue.jsUndefined()
        }
        // TODO(bao-runtime-api): 设置终端模式
        //   1. 从 callframe 获取 enabled 参数
        //   2. 调用 tty.setMode(master_fd, raw/normal)
        //   3. 更新 this.raw_mode
        JsValue.jsUndefined()
    }

    // ========================================================================
    // 终端标志操作 (termios)
    // 翻译自: Terminal.zig:760-805
    //   pub fn getInputFlags/setInputFlags/getOutputFlags/...
    // ========================================================================

    /// 获取输入标志 (iflag)
    /// 翻译自: Terminal.zig:782-784
    public func getInputFlags(globalThis!: JsGlobalObject): JsValue {
        // TODO(bao-runtime-api): tcgetattr + 返回 iflag
        JsValue.jsNumber(Int64(0))
    }

    /// 设置输入标志 (iflag)
    /// 翻译自: Terminal.zig:785-787
    public func setInputFlags(globalThis!: JsGlobalObject, value!: JsValue): Unit {
        // TODO(bao-runtime-api): tcgetattr + 修改 iflag + tcsetattr
    }

    /// 获取输出标志 (oflag)
    /// 翻译自: Terminal.zig:788-790
    public func getOutputFlags(globalThis!: JsGlobalObject): JsValue {
        JsValue.jsNumber(Int64(0))
    }

    /// 设置输出标志 (oflag)
    /// 翻译自: Terminal.zig:791-793
    public func setOutputFlags(globalThis!: JsGlobalObject, value!: JsValue): Unit {}

    /// 获取本地标志 (lflag)
    /// 翻译自: Terminal.zig:794-796
    public func getLocalFlags(globalThis!: JsGlobalObject): JsValue {
        JsValue.jsNumber(Int64(0))
    }

    /// 设置本地标志 (lflag)
    /// 翻译自: Terminal.zig:797-799
    public func setLocalFlags(globalThis!: JsGlobalObject, value!: JsValue): Unit {}

    /// 获取控制标志 (cflag)
    /// 翻译自: Terminal.zig:800-802
    public func getControlFlags(globalThis!: JsGlobalObject): JsValue {
        JsValue.jsNumber(Int64(0))
    }

    /// 设置控制标志 (cflag)
    /// 翻译自: Terminal.zig:803-805
    public func setControlFlags(globalThis!: JsGlobalObject, value!: JsValue): Unit {}

    // ========================================================================
    // 关闭 / 释放
    // 翻译自: Terminal.zig:977-1041, 1188-1211
    // ========================================================================

    /// 关闭终端
    /// 翻译自: Terminal.zig:977-984
    ///   pub fn close(this, globalObject, callframe) -> bun.JSError!JSValue
    public func close(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        closeInternal()
        JsValue.jsUndefined()
    }

    /// 内部关闭实现
    /// 翻译自: Terminal.zig:1002-1041
    ///   pub fn closeInternal(this: *Terminal) -> void
    private func closeInternal(): Unit {
        if (closed) { return }
        closed = true

        // 关闭写入端
        writeFd = FD.invalid

        // 关闭读取端
        if (readerStarted) {
            // TODO(bao-runtime-api): reader.close()
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

    /// Finalize — GC 回收时调用
    /// 翻译自: Terminal.zig:1204-1211
    ///   pub fn finalize(this: *Terminal) callconv(.c) -> void
    public func finalize(): Unit {
        finalized = true
        closeInternal()
    }

    // ========================================================================
    // IO 回调
    // 翻译自: Terminal.zig:1044-1174
    // ========================================================================

    /// 写入关闭回调
    /// 翻译自: Terminal.zig:1044-1051
    ///   fn onWriterClose(this: *Terminal) -> void
    private func onWriterClose(): Unit {
        if (!writerDone) {
            writerDone = true
            // 释放 writer 的引用
        }
    }

    /// 写入就绪回调 (drain)
    /// 翻译自: Terminal.zig:1053-1066
    ///   fn onWriterReady(this: *Terminal) -> void
    private func onWriterReady(): Unit {
        // TODO(bao-runtime-api): 调用 drain 回调
    }

    /// 写入错误回调
    /// 翻译自: Terminal.zig:1068-1075
    ///   fn onWriterError(this: *Terminal, err: bun.sys.Error) -> void
    private func onWriterError(err!: Any): Unit {
        if (!closed) {
            closeInternal()
        }
    }

    /// 读取完成回调 (EOF)
    /// 翻译自: Terminal.zig:1083-1098
    ///   pub fn onReaderDone(this: *Terminal) -> void
    public func onReaderDone(): Unit {
        if (!finalized) {
            connected = false
            // TODO(bao-runtime-api): 降级 JSRef
            // TODO(bao-runtime-api): 调用 exit 回调 (exit_code=0)
        }
        if (!readerDone) {
            readerDone = true
        }
    }

    /// 读取错误回调
    /// 翻译自: Terminal.zig:1100-1115
    ///   pub fn onReaderError(this: *Terminal, err: bun.sys.Error) -> void
    public func onReaderError(err!: Any): Unit {
        if (!finalized) {
            connected = false
            // TODO(bao-runtime-api): 降级 JSRef
            // TODO(bao-runtime-api): 调用 exit 回调 (exit_code=1)
        }
        if (!readerDone) {
            readerDone = true
        }
    }

    /// 读取数据回调
    /// 翻译自: Terminal.zig:1140-1174
    ///   pub fn onReadChunk(this: *Terminal, chunk: []const u8, has_more) -> bool
    public func onReadChunk(chunk!: Array<UInt8>, hasMore!: Bool): Bool {
        if (finalized) { return true }

        // 首次收到数据 — 升级为强引用 (已连接)
        if (!connected) {
            connected = true
            // TODO(bao-runtime-api): 升级 JSRef
        }

        // TODO(bao-runtime-api): 调用 data 回调
        //   1. 复制 chunk 数据
        //   2. 创建 ArrayBuffer
        //   3. 调用 data_callback(this_value, data)

        return true  // 继续读取
    }

    // ========================================================================
    // PTY 辅助操作
    // 翻译自: Terminal.zig:331-389
    // ========================================================================

    /// 获取 slave fd (子进程使用)
    /// 翻译自: Terminal.zig:331-333
    ///   pub fn getSlaveFd(this: *Terminal) -> bun.FD
    public func getSlaveFd(): FD { slaveFd }

    /// 关闭 slave fd (fork 后父进程关闭)
    /// 翻译自: Terminal.zig:345-351
    ///   pub fn closeSlaveFd(this: *Terminal) -> void
    public func closeSlaveFd(): Unit {
        inlineSpawned = true
        if (slaveFd != FD.invalid) {
            slaveFd.close()
            slaveFd = FD.invalid
        }
    }

    // ========================================================================
    // 引用管理
    // 翻译自: Terminal.zig:960-974
    // ========================================================================

    /// 引用
    /// 翻译自: Terminal.zig:960-963
    ///   pub fn doRef(this, _, _) -> bun.JSError!JSValue
    public func doRef(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        updateRef(add: true)
        JsValue.jsUndefined()
    }

    /// 取消引用
    /// 翻译自: Terminal.zig:966-969
    ///   pub fn doUnref(this, _, _) -> bun.JSError!JSValue
    public func doUnref(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        updateRef(add: false)
        JsValue.jsUndefined()
    }

    /// 更新引用
    /// 翻译自: Terminal.zig:971-974
    ///   fn updateRef(this: *Terminal, add: bool) -> void
    private func updateRef(add!: Bool): Unit {
        // TODO(bao-runtime-api): 更新 reader/writer 引用
    }

    /// 转为 JS 值
    /// 翻译自: Terminal.toJS (由 codegen 生成)
    public func toJS(globalThis!: JsGlobalObject): JsValue {
        // TODO(bao-runtime-api): 创建 JSTerminal 包装对象
        JsValue.jsUndefined()
    }
}

// ============================================================================
// Terminal Options — 创建选项
// 翻译自: Terminal.zig:105-163
//   pub const Options = struct { ... }
// ============================================================================

public class TerminalOptions {
    public var cols: UInt16 = 80
    public var rows: UInt16 = 24
    public var termName: String = "xterm-256color"
    public var dataCallback: ?JsValue = None
    public var exitCallback: ?JsValue = None
    public var drainCallback: ?JsValue = None

    public init() {}
}
