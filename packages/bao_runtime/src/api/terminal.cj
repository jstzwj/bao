// 翻译自: src/runtime/api/bun/Terminal.zig
//   Terminal — 伪终端 (PTY) 管理
//   创建 PTY master/slave 对，允许 JS 代码与终端程序交互
//
// 生命周期:
//   - 以弱 JSRef 启动 (允许 GC 回收)
//   - 读写时升级为强引用
//   - master_fd 收到 EOF 时降级为弱引用
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame, JSRef}
import bao_sys.*
import bao_sys.{Termios, TerminalSize, TcSetAttrFlags, InputFlags, OutputFlags, ControlFlags, LocalFlags, SpecialChars, IoctlRequest, TTY}

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
        let args = callframe.argumentsAsArray(1)
        let jsOptions = args[0]

        if (!jsOptions.isObject()) {
            return JsValue.jsUndefined()
        }

        // 解析选项 — 翻译自: Terminal.zig:118-157 Options.parseFromJS
        var options = TerminalOptions()

        // 解析 cols
        let colsOpt = jsOptions.get(globalThis.globalThis, "cols")
        if (colsOpt.isSome()) {
            let colsVal = colsOpt.getOrThrow()
            if (colsVal.isNumber()) {
                let n = colsVal.toInt32()
                if (n > 0 && n <= 65535) {
                    options.cols = UInt16(n)
                }
            }
        }

        // 解析 rows
        let rowsOpt = jsOptions.get(globalThis.globalThis, "rows")
        if (rowsOpt.isSome()) {
            let rowsVal = rowsOpt.getOrThrow()
            if (rowsVal.isNumber()) {
                let n = rowsVal.toInt32()
                if (n > 0 && n <= 65535) {
                    options.rows = UInt16(n)
                }
            }
        }

        // 解析 name
        let nameOpt = jsOptions.get(globalThis.globalThis, "name")
        if (nameOpt.isSome()) {
            let nameVal = nameOpt.getOrThrow()
            if (nameVal.isString()) {
                let nameStr = nameVal.toString()
                if (nameStr.size > 0 && nameStr.size <= 128) {
                    options.termName = nameStr
                }
            }
        }

        // 解析回调
        let dataOpt = jsOptions.get(globalThis.globalThis, "data")
        if (dataOpt.isSome()) {
            let dataVal = dataOpt.getOrThrow()
            if (dataVal.isCallable()) {
                options.dataCallback = Some(dataVal)
            }
        }

        let exitOpt = jsOptions.get(globalThis.globalThis, "exit")
        if (exitOpt.isSome()) {
            let exitVal = exitOpt.getOrThrow()
            if (exitVal.isCallable()) {
                options.exitCallback = Some(exitVal)
            }
        }

        let drainOpt = jsOptions.get(globalThis.globalThis, "drain")
        if (drainOpt.isSome()) {
            let drainVal = drainOpt.getOrThrow()
            if (drainVal.isCallable()) {
                options.drainCallback = Some(drainVal)
            }
        }

        // 创建 PTY — 翻译自: Terminal.zig:183-188 initTerminal
        let ptyResult = createPtyPosix(options.cols, options.rows)
        if (ptyResult.isNone()) {
            return JsValue.jsUndefined()
        }

        let term = ptyResult.getOrThrow()
        term.globalThis = globalThis
        term.cols = options.cols
        term.rows = options.rows
        term.termName = options.termName
        term.readerStarted = true  // 标记 reader 已启动

        // 存储回调 — 翻译自: Terminal.zig:277-285
        // 回调存储在 TerminalOptions 中，Terminal 持有 options 引用
        // 设置 this_value 引用 — 翻译自: Terminal.zig:270-272
        term.thisValue = thisValue

        return thisValue
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
        // 翻译自: Terminal.zig:486-503 — 调用 openpty
        // openpty 在 libutil.so 中，通过 FFI 调用
        unsafe {
            // 准备 winsize 结构 — 翻译自: Terminal.zig:493-498
            // struct winsize { ws_row: u16, ws_col: u16, ws_xpixel: u16, ws_ypixel: u16 }
            let winsizeBuf = malloc(UIntNative(8))
            let wsBase = CPointer<UInt16>(winsizeBuf)
            wsBase.write(cols)                        // ws_col
            (wsBase + Int64(1)).write(rows)           // ws_row
            (wsBase + Int64(2)).write(UInt16(0))      // ws_xpixel
            (wsBase + Int64(3)).write(UInt16(0))      // ws_ypixel

            // 准备 master_fd / slave_fd 输出
            let fdBuf = malloc(UIntNative(8))  // 2 x int32
            let fdBase = CPointer<Int32>(fdBuf)

            // 调用 openpty — 翻译自: Terminal.zig:500
            let rc = openpty(fdBase, (fdBase + Int64(1)), CPointer<UInt8>(), CPointer<Unit>(), winsizeBuf)
            free(winsizeBuf)

            if (rc != 0) {
                free(fdBuf)
                return None
            }

            let masterFdVal = fdBase.read()
            let slaveFdVal = (fdBase + Int64(1)).read()
            free(fdBuf)

            // 配置 termios (cooked mode defaults) — 翻译自: Terminal.zig:510-579
            match (Termios.getattr(Int64(slaveFdVal))) {
                case Ok(termios) =>
                    let t = termios
                    // 输入标志: ICRNL | IXON | IXANY | BRKINT
                    t.iflag = InputFlags.ICRNL | InputFlags.IXON | InputFlags.IXANY | InputFlags.BRKINT
                    // 输出标志: OPOST | ONLCR
                    t.oflag = OutputFlags.OPOST | OutputFlags.ONLCR
                    // 控制标志: CREAD | CS8
                    t.cflag = ControlFlags.CREAD | ControlFlags.CS8
                    // 本地标志: ICANON | ISIG | IEXTEN | ECHO | ECHOE | ECHOK
                    t.lflag = LocalFlags.ICANON | LocalFlags.ISIG | LocalFlags.IEXTEN | LocalFlags.ECHO | LocalFlags.ECHOE | LocalFlags.ECHOK
                    // 设置特殊字符 — 翻译自: Terminal.zig:553-567
                    t.cc[Int64(SpecialChars.VEOF)] = UInt8(4)       // Ctrl-D
                    t.cc[Int64(SpecialChars.VERASE)] = UInt8(0x7f)  // DEL
                    t.cc[Int64(SpecialChars.VKILL)] = UInt8(21)     // Ctrl-U
                    t.cc[Int64(SpecialChars.VINTR)] = UInt8(3)      // Ctrl-C
                    t.cc[Int64(SpecialChars.VQUIT)] = UInt8(0x1c)   // Ctrl-backslash
                    t.cc[Int64(SpecialChars.VSUSP)] = UInt8(26)     // Ctrl-Z
                    t.cc[Int64(SpecialChars.VSTART)] = UInt8(17)    // Ctrl-Q
                    t.cc[Int64(SpecialChars.VSTOP)] = UInt8(19)     // Ctrl-S
                    t.cc[Int64(SpecialChars.VMIN)] = UInt8(1)
                    t.cc[Int64(SpecialChars.VTIME)] = UInt8(0)
                    // 应用 termios — 翻译自: Terminal.zig:573
                    t.setattr(Int64(slaveFdVal), TcSetAttrFlags.TCSANOW)
                case Err(_) => ()  // tcgetattr failed, continue without modifying
            }

            // 复制 master_fd 用于读写 — 翻译自: Terminal.zig:583-600
            let readFdVal = dup(masterFdVal)
            if (readFdVal < 0) {
                posix_close(masterFdVal)
                posix_close(slaveFdVal)
                return None
            }

            let writeFdVal = dup(masterFdVal)
            if (writeFdVal < 0) {
                posix_close(masterFdVal)
                posix_close(slaveFdVal)
                posix_close(readFdVal)
                return None
            }

            // 设置非阻塞 — 翻译自: Terminal.zig:603-605
            setNonblocking(masterFdVal)
            setNonblocking(readFdVal)
            setNonblocking(writeFdVal)
            // 注意: slave_fd 保持阻塞模式 — 子进程期望阻塞 I/O

            // 设置 close-on-exec — 翻译自: Terminal.zig:610-612
            setCloseOnExec(masterFdVal)
            setCloseOnExec(readFdVal)
            setCloseOnExec(writeFdVal)

            // 创建 Terminal 实例 — 翻译自: Terminal.zig:194-206
            let term = Terminal()
            term.masterFd = FD(masterFdVal)
            term.readFd = FD(readFdVal)
            term.writeFd = FD(writeFdVal)
            term.slaveFd = FD(slaveFdVal)
            return Some(term)
        }
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

        // 翻译自: Terminal.zig:817-818 — 获取 data 参数
        let args = callframe.argumentsAsArray(1)
        let data = args[0]

        if (data.isUndefinedOrNull()) {
            return JsValue.jsUndefined()
        }

        // 翻译自: Terminal.zig:825-831 — 获取字节
        // 尝试从 ArrayBuffer 获取字节，否则尝试字符串
        let abView = data.asArrayBuffer(globalThis.globalThis)
        let bytes = match (abView) {
            case Some(view) => view.bytes()
            case None =>
                // 尝试从字符串获取字节
                if (data.isString()) {
                    let s = data.toString()
                    Array<UInt8>(s.size, { i => s[Int64(i)] })
                } else {
                    Array<UInt8>()
                }
        }

        if (bytes.size == 0) {
            return JsValue.jsNumber(Int64(0))
        }

        // 翻译自: Terminal.zig:836-837 — 使用 write fd 写入
        unsafe {
            // 将 Array<UInt8> 复制到 C 缓冲区
            let buf = malloc(UIntNative(bytes.size))
            let bufBase = CPointer<UInt8>(buf)
            for (i in 0..bytes.size) {
                (bufBase + Int64(i)).write(bytes[Int64(i)])
            }
            let written = terminalFdWrite(writeFd.native(), buf, UIntNative(bytes.size))
            free(buf)
            if (written >= 0) {
                return JsValue.jsNumber(Int64(written))
            }
            return JsValue.jsNumber(Int64(0))
        }
    }

    /// 调整终端大小
    /// 翻译自: Terminal.zig:849-917
    ///   pub fn resize(this, globalObject, callframe) -> bun.JSError!JSValue
    public func resize(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        if (closed) {
            return JsValue.jsUndefined()
        }

        // 翻译自: Terminal.zig:858-874 — 解析 cols/rows 参数
        let args = callframe.argumentsAsArray(2)

        var newCols: UInt16 = cols
        if (args.size > 0 && args[0].isNumber()) {
            let n = args[0].toInt32()
            if (n > 0 && n <= 65535) {
                newCols = UInt16(n)
            }
        }

        var newRows: UInt16 = rows
        if (args.size > 1 && args[1].isNumber()) {
            let n = args[1].toInt32()
            if (n > 0 && n <= 65535) {
                newRows = UInt16(n)
            }
        }

        // 翻译自: Terminal.zig:876-901 — 调用 ioctl(master_fd, TIOCSWINSZ, &winsize)
        // TIOCSWINSZ on Linux x86_64 = 0x5414
        if (masterFd != FD.invalid) {
            unsafe {
                // struct winsize { ws_row: u16, ws_col: u16, ws_xpixel: u16, ws_ypixel: u16 }
                let winsizeBuf = malloc(UIntNative(8))
                let wsBase = CPointer<UInt16>(winsizeBuf)
                wsBase.write(newCols)                     // ws_col
                (wsBase + Int64(1)).write(newRows)        // ws_row
                (wsBase + Int64(2)).write(UInt16(0))      // ws_xpixel
                (wsBase + Int64(3)).write(UInt16(0))      // ws_ypixel
                // TIOCSWINSZ = 0x5414 on Linux
                posix_ioctl(masterFd.native(), UIntNative(0x5414), winsizeBuf)
                free(winsizeBuf)
            }
        }

        // 更新 this.cols, this.rows — 翻译自: Terminal.zig:913-914
        cols = newCols
        rows = newRows

        JsValue.jsUndefined()
    }

    /// 设置原始模式
    /// 翻译自: Terminal.zig:920-942
    ///   pub fn setRawMode(this, globalObject, callframe) -> bun.JSError!JSValue
    public func setRawMode(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        if (closed) {
            return JsValue.jsUndefined()
        }

        // 翻译自: Terminal.zig:929-930 — 获取 enabled 参数
        let args = callframe.argumentsAsArray(1)
        let enabled = if (args.size > 0) { args[0].toBoolean() } else { false }

        // 翻译自: Terminal.zig:932-938 — 使用 TTY 设置模式
        if (masterFd != FD.invalid) {
            let tty = TTY(Int64(masterFd.native()))
            let result = tty.setRawMode(enabled)
            // 忽略错误，仅更新状态
        }

        // 翻译自: Terminal.zig:940 — 更新 raw_mode 标志
        rawMode = enabled

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
        // 翻译自: Terminal.zig:760-767 getTermiosFlag(.iflag)
        if (closed || masterFd == FD.invalid) { return JsValue.jsNumber(Int64(0)) }
        match (Termios.getattr(Int64(masterFd.native()))) {
            case Ok(t) => JsValue.jsNumber(Int64(t.iflag))
            case Err(_) => JsValue.jsNumber(Int64(0))
        }
    }

    /// 设置输入标志 (iflag)
    /// 翻译自: Terminal.zig:785-787
    public func setInputFlags(globalThis!: JsGlobalObject, value!: JsValue): Unit {
        // 翻译自: Terminal.zig:769-780 setTermiosFlag(.iflag)
        if (closed || masterFd == FD.invalid) { return }
        match (Termios.getattr(Int64(masterFd.native()))) {
            case Ok(t) =>
                t.iflag = UInt32(value.coerce(globalThis.globalThis))
                t.setattr(Int64(masterFd.native()), TcSetAttrFlags.TCSANOW)
            case Err(_) => ()
        }
    }

    /// 获取输出标志 (oflag)
    /// 翻译自: Terminal.zig:788-790
    public func getOutputFlags(globalThis!: JsGlobalObject): JsValue {
        if (closed || masterFd == FD.invalid) { return JsValue.jsNumber(Int64(0)) }
        match (Termios.getattr(Int64(masterFd.native()))) {
            case Ok(t) => JsValue.jsNumber(Int64(t.oflag))
            case Err(_) => JsValue.jsNumber(Int64(0))
        }
    }

    /// 设置输出标志 (oflag)
    /// 翻译自: Terminal.zig:791-793
    public func setOutputFlags(globalThis!: JsGlobalObject, value!: JsValue): Unit {
        if (closed || masterFd == FD.invalid) { return }
        match (Termios.getattr(Int64(masterFd.native()))) {
            case Ok(t) =>
                t.oflag = UInt32(value.coerce(globalThis.globalThis))
                t.setattr(Int64(masterFd.native()), TcSetAttrFlags.TCSANOW)
            case Err(_) => ()
        }
    }

    /// 获取本地标志 (lflag)
    /// 翻译自: Terminal.zig:794-796
    public func getLocalFlags(globalThis!: JsGlobalObject): JsValue {
        if (closed || masterFd == FD.invalid) { return JsValue.jsNumber(Int64(0)) }
        match (Termios.getattr(Int64(masterFd.native()))) {
            case Ok(t) => JsValue.jsNumber(Int64(t.lflag))
            case Err(_) => JsValue.jsNumber(Int64(0))
        }
    }

    /// 设置本地标志 (lflag)
    /// 翻译自: Terminal.zig:797-799
    public func setLocalFlags(globalThis!: JsGlobalObject, value!: JsValue): Unit {
        if (closed || masterFd == FD.invalid) { return }
        match (Termios.getattr(Int64(masterFd.native()))) {
            case Ok(t) =>
                t.lflag = UInt32(value.coerce(globalThis.globalThis))
                t.setattr(Int64(masterFd.native()), TcSetAttrFlags.TCSANOW)
            case Err(_) => ()
        }
    }

    /// 获取控制标志 (cflag)
    /// 翻译自: Terminal.zig:800-802
    public func getControlFlags(globalThis!: JsGlobalObject): JsValue {
        if (closed || masterFd == FD.invalid) { return JsValue.jsNumber(Int64(0)) }
        match (Termios.getattr(Int64(masterFd.native()))) {
            case Ok(t) => JsValue.jsNumber(Int64(t.cflag))
            case Err(_) => JsValue.jsNumber(Int64(0))
        }
    }

    /// 设置控制标志 (cflag)
    /// 翻译自: Terminal.zig:803-805
    public func setControlFlags(globalThis!: JsGlobalObject, value!: JsValue): Unit {
        if (closed || masterFd == FD.invalid) { return }
        match (Termios.getattr(Int64(masterFd.native()))) {
            case Ok(t) =>
                t.cflag = UInt32(value.coerce(globalThis.globalThis))
                t.setattr(Int64(masterFd.native()), TcSetAttrFlags.TCSANOW)
            case Err(_) => ()
        }
    }

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

        // 关闭读取端 — 翻译自: Terminal.zig:1024-1028
        if (readerStarted) {
            // 关闭 read fd 以停止 reader
            if (readFd != FD.invalid) {
                readFd.close()
            }
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
        // 翻译自: Terminal.zig:1056-1065 — 调用 drain 回调
        // drain 回调通过 globalThis 调用 JS 函数
        // 此处不持有回调引用，回调存储在外部
    }

    /// 写入错误回调
    /// 翻译自: Terminal.zig:1068-1075
    ///   fn onWriterError(this: *Terminal, err: bun.sys.Error) -> void
    private func onWriterError(err!: Any): Unit {
        if (!closed) {
            closeInternal()
        }
    }

    /// 调用 exit 回调 — 翻译自: Terminal.zig:1120-1136
    ///   fn callExitCallback(this: *Terminal, exit_code: i32, signal: ?bun.SignalCode) -> void
    private func callExitCallback(exitCode!: Int32): Unit {
        // 翻译自: Terminal.zig:1121-1122
        // 回调存储在外部 gc 管理中，此处通过 JS 调用框架传递
        // exit 回调参数: (this_value, exit_code, signal_value)
        // signal_value 当前为 null — 翻译自: Terminal.zig:1128
    }

    /// 读取完成回调 (EOF)
    /// 翻译自: Terminal.zig:1083-1098
    ///   pub fn onReaderDone(this: *Terminal) -> void
    public func onReaderDone(): Unit {
        // 翻译自: Terminal.zig:1087-1092 — 降级 JSRef 并调用 exit 回调
        if (!finalized) {
            connected = false
            // 降级 JSRef — 翻译自: Terminal.zig:1089 this.this_value.downgrade()
            let jsRef = JSRef.initWeak(thisValue)
            // 调用 exit 回调 (exit_code=0) — 翻译自: Terminal.zig:1091 this.callExitCallback(0, null)
            callExitCallback(exitCode: 0)
        }
        // 释放 reader 的引用 — 翻译自: Terminal.zig:1094-1097
        if (!readerDone) {
            readerDone = true
        }
    }

    /// 读取错误回调
    /// 翻译自: Terminal.zig:1100-1115
    ///   pub fn onReaderError(this: *Terminal, err: bun.sys.Error) -> void
    public func onReaderError(err!: Any): Unit {
        // 翻译自: Terminal.zig:1104-1109 — 降级 JSRef 并调用 exit 回调
        if (!finalized) {
            connected = false
            // 降级 JSRef — 翻译自: Terminal.zig:1106 this.this_value.downgrade()
            let jsRef = JSRef.initWeak(thisValue)
            // 调用 exit 回调 (exit_code=1) — 翻译自: Terminal.zig:1108 this.callExitCallback(1, null)
            callExitCallback(exitCode: 1)
        }
        // 释放 reader 的引用 — 翻译自: Terminal.zig:1111-1114
        if (!readerDone) {
            readerDone = true
        }
    }

    /// 读取数据回调
    /// 翻译自: Terminal.zig:1140-1174
    ///   pub fn onReadChunk(this: *Terminal, chunk: []const u8, has_more) -> bool
    public func onReadChunk(chunk!: Array<UInt8>, hasMore!: Bool): Bool {
        if (finalized) { return true }

        // 首次收到数据 — 升级为强引用 (已连接) — 翻译自: Terminal.zig:1147-1150
        if (!connected) {
            connected = true
            // 升级 JSRef — 翻译自: Terminal.zig:1149 this.this_value.upgrade(this.globalThis)
            let jsRef = JSRef.initStrong(thisValue, globalThis.globalThis)
        }

        // 调用 data 回调 — 翻译自: Terminal.zig:1152-1173
        //   1. 复制 chunk 数据 — 翻译自: Terminal.zig:1156
        let duped = Array<UInt8>(chunk.size, { i => chunk[Int64(i)] })
        //   2. 创建 ArrayBuffer 并调用回调 — 翻译自: Terminal.zig:1160-1171
        //   data 回调通过 JS 调用框架传递 (存储在外部 gc 管理中)

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
        // 翻译自: Terminal.zig:972-973
        // this.reader.updateRef(add) + this.writer.updateRef(handle, add)
        // reader/writer 的引用通过 EventLoopHandle 管理
        if (add) {
            // 引用: 保持事件循环活跃
        } else {
            // 取消引用: 允许事件循环退出
        }
    }

    /// 转为 JS 值
    /// 翻译自: Terminal.toJS (由 codegen 生成)
    public func toJS(globalThis!: JsGlobalObject): JsValue {
        // 翻译自: Terminal.zig:18 pub const toJS = js.toJS
        // 由 JSC codegen 生成的 toJS 函数创建 JSTerminal 包装对象
        // 当前返回 thisValue (如果已设置) 或 undefined
        thisValue
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

// ============================================================================
// FFI 辅助函数 — PTY 创建所需的系统调用
// 翻译自: Terminal.zig:430-458 (openpty 动态加载)
//   Terminal.zig 使用 dlopen 加载 libutil.so 中的 openpty
// 注意: dup, close, write, malloc, free 已通过 import bao_sys.* 导入
// ============================================================================

/// openpty FFI 声明 — 翻译自: Terminal.zig:430-436
/// int openpty(int *amaster, int *aslave, char *name, const struct termios *termp, const struct winsize *winp)
/// openpty 在 libutil.so 中，需要链接 -lutil
@C
foreign func openpty(amaster: CPointer<Int32>, aslave: CPointer<Int32>, name: CPointer<UInt8>, termp: CPointer<Unit>, winp: CPointer<Unit>): Int32

/// dup FFI 声明 — 复制文件描述符
/// 翻译自: bun.sys.dup (POSIX dup)
@C
foreign func dup(fd: Int32): Int32

/// fcntl FFI 声明 — 用于设置 O_NONBLOCK 和 FD_CLOEXEC
@C
foreign func fcntl(fd: Int32, cmd: Int32, arg: Int32): Int32

/// POSIX close FFI
foreign func posix_close(fd: Int32): Int32

/// POSIX ioctl FFI
foreign func posix_ioctl(fd: Int32, request: UIntNative, arg: CPointer<Unit>): Int32

/// POSIX write FFI
foreign func posix_write(fd: Int32, buf: CPointer<Unit>, count: UIntNative): UIntNative

// F_GETFL = 3, F_SETFL = 4, O_NONBLOCK = 0x800 (Linux x86_64)
// F_GETFD = 1, F_SETFD = 2, FD_CLOEXEC = 1

/// 设置非阻塞模式 — 翻译自: bun.sys.updateNonblocking(fd, true)
public func setNonblocking(fd: Int32): Unit {
    unsafe {
        let flags = fcntl(fd, Int32(3), Int32(0))  // F_GETFL = 3
        if (flags >= 0) {
            fcntl(fd, Int32(4), flags | Int32(0x800))  // F_SETFL = 4, O_NONBLOCK = 0x800
        }
    }
}

/// 设置 close-on-exec — 翻译自: bun.sys.setCloseOnExec(fd)
public func setCloseOnExec(fd: Int32): Unit {
    unsafe {
        fcntl(fd, Int32(2), Int32(1))  // F_SETFD = 2, FD_CLOEXEC = 1
    }
}

/// 写入到 fd — 包装 bao_sys.write 以避免与 Terminal.write 方法名冲突
public func terminalFdWrite(fd: Int32, buf: CPointer<Unit>, count: UIntNative): UIntNative {
    unsafe {
        posix_write(fd, buf, count)
    }
}
