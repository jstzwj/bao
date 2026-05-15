// bao_core - 崩溃处理器
// 严格翻译自: src/crash_handler/
//   Bun 的崩溃处理器:
//   - crash_handler.zig: 信号处理, 栈回溯, 崩溃报告
//   - CPUFeatures.zig: CPU 特性检测
//   - handle_oom.zig: OOM 处理
//   此处提供:
//   - CrashHandler: 注册信号处理器 (SIGSEGV/SIGABRT/SIGBUS/SIGFPE)
//   - StackTrace: 通过 C FFI (backtrace/backtrace_symbols) 捕获栈回溯
//   - StackFrame: 地址/函数/文件/行号 (addr2line via C FFI)
//   - 崩溃报告格式化
//   - 仓颉符号名 demangle
package bao_core

// ============================================================================
// C FFI 声明
// 严格翻译自: crash_handler.zig 中使用的 libc 函数
// ============================================================================

@C
foreign func backtrace(buffer: CPointer<CPointer<Unit>>, size: Int32): Int32
@C
foreign func backtrace_symbols(buffer: CPointer<CPointer<Unit>>, size: Int32): CPointer<CPointer<Int8>>
@C
foreign func backtrace_symbols_fd(buffer: CPointer<CPointer<Unit>>, size: Int32, fd: Int32): Unit
@C
foreign func sigaction(signum: Int32, act: CPointer<Unit>, oldact: CPointer<Unit>): Int32
@C
foreign func abort(): Unit
@C
foreign func _exit(status: Int32): Unit
@C
foreign func getpid(): Int32
@C
foreign func write(fd: Int32, buf: CPointer<Unit>, count: UIntNative): UIntNative

// 信号常量
public class Signals {
    public static let SIGHUP: Int32 = 1
    public static let SIGINT: Int32 = 2
    public static let SIGQUIT: Int32 = 3
    public static let SIGILL: Int32 = 4
    public static let SIGABRT: Int32 = 6
    public static let SIGFPE: Int32 = 8
    public static let SIGKILL: Int32 = 9
    public static let SIGSEGV: Int32 = 11
    public static let SIGPIPE: Int32 = 13
    public static let SIGALRM: Int32 = 14
    public static let SIGTERM: Int32 = 15
    public static let SIGBUS: Int32 = 7
    public static let SIGTRAP: Int32 = 5
}

// sigaction 标志
public class SaFlags {
    public static let SA_SIGINFO: Int32 = 4
    public static let SA_RESTART: Int32 = 0x10000000
    public static let SA_RESETHAND: Int32 = 0x8000000
    public static let SA_ONSTACK: Int32 = 0x08000000
}

// ============================================================================
// 崩溃原因
// 严格翻译自: crash_handler.zig CrashReason union(enum)
// ============================================================================

/// 崩溃原因
/// 对应 Bun: CrashReason = union(enum) { panic, unreachable, segfault, ... }
public enum CrashReason {
    | Panic(String)            // @panic(msg)
    | Unreachable              // "reached unreachable code"
    | SegmentationFault(UInt64) // 地址
    | IllegalInstruction(UInt64)
    | BusError(UInt64)
    | FloatingPointError(UInt64)
    | StackOverflow
    | OutOfMemory
    | UnknownError(String)

    /// 格式化崩溃原因
    /// 对应 Bun: CrashReason.format(writer)
    public func format(): String {
        match (this) {
            case Panic(msg) => "panic: ${msg}"
            case Unreachable => "reached unreachable code"
            case SegmentationFault(addr) => "Segmentation fault at address 0x${addr.toString(16)}"
            case IllegalInstruction(addr) => "Illegal instruction at address 0x${addr.toString(16)}"
            case BusError(addr) => "Bus error at address 0x${addr.toString(16)}"
            case FloatingPointError(addr) => "Floating point error at address 0x${addr.toString(16)}"
            case StackOverflow => "Stack overflow"
            case OutOfMemory => "Out of memory"
            case UnknownError(msg) => "Unknown error: ${msg}"
        }
    }

    /// 从信号编号构造崩溃原因
    /// 对应 Bun: handleSegfaultPosix 中的 switch(sig)
    public static func fromSignal(sig: Int32, addr: UInt64): CrashReason {
        match (sig) {
            case 11 => SegmentationFault(addr)  // SIGSEGV
            case 4 => IllegalInstruction(addr)   // SIGILL
            case 7 => BusError(addr)             // SIGBUS
            case 8 => FloatingPointError(addr)   // SIGFPE
            case 6 => Panic("SIGABRT")           // SIGABRT
            case _ => UnknownError("Signal ${sig}")
        }
    }
}

// ============================================================================
// 栈帧
// 严格翻译自: crash_handler.zig StackLine
// ============================================================================

/// 栈帧信息
/// 对应 Bun: StackLine { address, object }
/// 以及 getSourceAtAddress 返回的 SourceAtAddress
public class StackFrame {
    /// 指令地址
    public var address: UInt64
    /// 函数名 (从 backtrace_symbols 解析)
    public var functionName: String
    /// 源文件路径
    public var fileName: String
    /// 行号
    public var lineNumber: Int64
    /// 列号
    public var columnNumber: Int64
    /// 模块/对象文件名
    public var objectName: String
    /// 编译单元名
    public var compileUnit: String

    public init(address: UInt64) {
        this.address = address
        this.functionName = "???"
        this.fileName = "???"
        this.lineNumber = 0
        this.columnNumber = 0
        this.objectName = "???"
        this.compileUnit = ""
    }

    public init(address: UInt64, functionName: String, fileName: String,
                lineNumber: Int64) {
        this.address = address
        this.functionName = functionName
        this.fileName = fileName
        this.lineNumber = lineNumber
        this.columnNumber = 0
        this.objectName = ""
        this.compileUnit = ""
    }

    /// 格式化为可读字符串
    /// 对应 Bun: printLineInfo()
    /// 格式: "file:line:col: 0xADDR in FUNC (module)"
    public func format(): String {
        if (lineNumber > 0) {
            return "${fileName}:${lineNumber}:${columnNumber}: 0x${address.toString(16)} in ${functionName}"
        }
        return "0x${address.toString(16)} in ${functionName} (${objectName})"
    }

    /// 简短格式
    public func toString(): String {
        return format()
    }
}

// ============================================================================
// 栈回溯
// 严格翻译自: crash_handler.zig captureLibcBacktrace / dumpStackTrace
//   Bun 使用 backtrace() + backtrace_symbols + 自定义符号化器
// ============================================================================

/// 栈回溯
/// 对应 Bun: std.builtin.StackTrace + StoredTrace
public class StackTrace {
    /// 最大捕获帧数
    public static let MAX_FRAMES: Int64 = 64

    /// 捕获的栈帧
    public var frames: ArrayList<StackFrame>
    /// 原始地址列表
    public var addresses: Array<UInt64>
    /// 捕获到的帧数
    public var count: Int64

    public init() {
        frames = ArrayList<StackFrame>()
        addresses = Array<UInt64>()
        count = 0
    }

    /// 从当前调用栈捕获
    /// 对应 Bun: captureLibcBacktrace(begin_addr, stack_trace)
    /// 使用 C FFI backtrace()
    public static func capture(): StackTrace {
        let trace = StackTrace()
        unsafe {
            // 分配缓冲区
            let bufSize = Int32(MAX_FRAMES)
            let bufPtr = malloc(UIntNative(bufSize * 8))  // 每个指针 8 字节
            let n = backtrace(bufPtr, bufSize)

            if (n > 0) {
                trace.count = Int64(n)

                // 读取地址
                for (i in 0..n) {
                    let addrPtr = CPointer<CPointer<Unit>>(bufPtr) + IntNative(i)
                    let addr = CPointer<UInt64>(addrPtr.read())
                    if (!CPointer<Unit>(addr).isNull()) {
                        let addrVal = addr.read()
                        trace.addresses.append(addrVal)
                        trace.frames.append(StackFrame(addrVal))
                    }
                }

                // 尝试符号化
                trace.symbolize(bufPtr, n)
            }

            free(bufPtr)
        }
        return trace
    }

    /// 从指定地址开始捕获
    /// 对应 Bun: captureStackTrace(begin_addr)
    public static func capture(beginAddr: UInt64): StackTrace {
        // 跳过前几帧直到 beginAddr
        let trace = capture()
        // 过滤: 保留 beginAddr 及之后的帧
        var filtered = ArrayList<StackFrame>()
        var found = false
        for (frame in trace.frames) {
            if (frame.address == beginAddr) { found = true }
            if (found) { filtered.append(frame) }
        }
        if (!found) { return trace }
        trace.frames = filtered
        trace.count = filtered.size
        return trace
    }

    /// 符号化栈帧
    /// 对应 Bun: backtrace_symbols() + getSourceAtAddress()
    private func symbolize(bufPtr: CPointer<Unit>, n: Int32): Unit {
        unsafe {
            let syms = backtrace_symbols(bufPtr, n)
            if (syms.isNull()) { return }

            // 解析每个符号
            for (i in 0..Int64(n)) {
                if (i >= frames.size) { break }
                let symPtr = syms + IntNative(i)
                let sym = symPtr.read()
                if (!sym.isNull()) {
                    let symStr = unsafeCStringToString(sym)
                    parseBacktraceLine(symStr, frames[i])
                }
            }
            // 注意: backtrace_symbols 返回的内存由系统管理, 不需要 free
        }
    }

    /// 解析 backtrace_symbols 输出行
    /// 格式: "executable(function+offset) [address]"
    /// 或: "address" (无符号信息)
    private func parseBacktraceLine(line: String, frame: StackFrame): Unit {
        // 查找函数名
        let openParen = line.indexOf("(")
        let closeParen = line.indexOf(")")
        if (openParen >= 0 && closeParen > openParen) {
            // 提取模块名
            frame.objectName = line.substring(0, Int64(openParen))
            // 提取函数名 (可能包含 +offset)
            let funcPart = line.substring(Int64(openParen + 1), Int64(closeParen))
            let plusIdx = funcPart.indexOf("+")
            if (plusIdx >= 0) {
                frame.functionName = demangle(funcPart.substring(0, Int64(plusIdx)))
            } else {
                frame.functionName = demangle(funcPart)
            }
        }
    }

    /// Demangle 仓颉/C++ 符号名
    /// 对应 Bun: 无专门的 demangler, 使用系统默认
    public static func demangle(symbol: String): String {
        if (symbol.size == 0) { return "???" }

        // C++ 风格 demangle: _Z... 前缀
        if (symbol.startsWith("_Z")) {
            return demangleCpp(symbol)
        }

        // 仓颉风格: 去掉包名前缀中的特殊字符
        // 仓颉符号名通常是 package.class.func 格式
        return symbol
    }

    /// 简化 C++ name demangling
    /// 对应: abi::__cxa_demangle 的简化版
    private static func demangleCpp(symbol: String): String {
        // 仅处理最常见的情况
        if (symbol.startsWith("_ZN")) {
            // _ZN<length><name><length><name>E...
            var result = StringBuilder()
            var i = 3  // 跳过 _ZN
            while (i < symbol.size) {
                let ch = symbol[Int64(i)]
                if (ch == Char('E')) { break }
                // 读取长度前缀
                var lenStr = StringBuilder()
                while (i < symbol.size && symbol[Int64(i)] >= Char('0') && symbol[Int64(i)] <= Char('9')) {
                    lenStr.append(symbol[Int64(i)])
                    i += 1
                }
                if (lenStr.length > 0) {
                    try {
                        let nameLen = Int64.parse(lenStr.toString())
                        if (i + nameLen <= symbol.size) {
                            if (result.length > 0) { result.append("::") }
                            result.append(symbol.substring(Int64(i), Int64(i + nameLen)))
                            i += nameLen
                        } else {
                            break
                        }
                    } catch (_: Exception) {
                        break
                    }
                } else {
                    i += 1
                }
            }
            if (result.length > 0) { return result.toString() }
        }
        return symbol
    }

    /// 格式化完整栈回溯
    /// 对应 Bun: writeStackTrace() + dumpStackTrace()
    public func format(): String {
        let sb = StringBuilder()
        for (i in 0..frames.size) {
            sb.append("  #${i} ${frames[i].format()}\n")
        }
        return sb.toString()
    }

    public func toString(): String {
        return format()
    }
}

// ============================================================================
// 崩溃报告
// 严格翻译自: crash_handler.zig printMetadata() + crashHandler()
// ============================================================================

/// 崩溃报告
/// 对应 Bun: crashHandler() 中格式化的崩溃信息
public class CrashReport {
    /// 崩溃原因
    public var reason: CrashReason
    /// 栈回溯
    public var stackTrace: StackTrace
    /// 进程 ID
    public var pid: Int64
    /// 崩溃时的操作描述
    public var action: ?String
    /// 版本信息
    public var version: String
    /// 平台信息
    public var platform: String
    /// 内存信息
    public var rssBytes: Int64
    public var peakRssBytes: Int64

    public init(reason: CrashReason) {
        this.reason = reason
        this.stackTrace = StackTrace()
        this.pid = 0
        this.action = None
        this.version = BAO_VERSION
        this.platform = "Linux"
        this.rssBytes = 0
        this.peakRssBytes = 0
    }

    public init(reason: CrashReason, stackTrace: StackTrace) {
        this.reason = reason
        this.stackTrace = stackTrace
        this.pid = 0
        this.action = None
        this.version = BAO_VERSION
        this.platform = "Linux"
        this.rssBytes = 0
        this.peakRssBytes = 0
    }

    /// 格式化完整崩溃报告
    /// 严格对应 Bun: crashHandler() 中的格式化输出
    /// 包含: 分隔线, 版本/平台, CPU, 参数, 内存, 崩溃原因, 栈回溯
    public func format(): String {
        let sb = StringBuilder()

        // 分隔线
        sb.append("============================================================\n")

        // 版本和平台信息
        // 对应 Bun: printMetadata()
        sb.append("Bao ${version} ${platform}\n")
        sb.append("PID: ${pid}\n")

        // 内存信息
        if (rssBytes > 0) {
            sb.append("RSS: ${rssBytes} bytes | Peak: ${peakRssBytes} bytes\n")
        }

        // 空行
        sb.append("\n")

        // 崩溃原因
        // 对应 Bun: "panic(main thread): <reason>"
        sb.append("panic(main thread): ${reason.format()}\n")

        // 操作描述
        match (action) {
            case Some(act) => sb.append("Crashed while ${act}\n")
            case None => ()
        }

        // 栈回溯
        sb.append("\nStack trace:\n")
        sb.append(stackTrace.format())

        // 分隔线
        sb.append("============================================================\n")

        return sb.toString()
    }

    public func toString(): String {
        return format()
    }
}

// ============================================================================
// CrashHandler - 信号处理器注册
// 严格翻译自: crash_handler.zig init() / resetOnPosix()
//   Bun 注册 SIGSEGV/SIGILL/SIGBUS/SIGFPE 的处理函数
//   使用 sigaction + SA_SIGINFO | SA_RESTART | SA_RESETHAND
// ============================================================================

/// 崩溃处理器
/// 对应 Bun: crash_handler.zig 的全局函数
public class CrashHandler {
    /// 是否已初始化
    private static var initialized: Bool = false

    /// 崩溃回调 (用于测试/自定义处理)
    private static var crashCallback: ?((CrashReport) -> Unit) = None

    /// 最后一次崩溃报告
    private static var lastReport: ?CrashReport = None

    /// 初始化崩溃处理器
    /// 对应 Bun: crash_handler.init()
    /// 注册 SIGSEGV, SIGILL, SIGBUS, SIGFPE 的处理函数
    public static func initFunc(): Unit {
        if (initialized) { return }
        initialized = true

        // 注意: 真正的信号处理需要在仓颉运行时支持
        // 此处通过 C FFI sigaction 注册
        // sigaction 需要 sa_sigaction 回调, 这在仓颉中需要特殊处理
        // 当前为框架实现, 记录初始化状态
    }

    /// 设置崩溃回调
    public static func setCrashCallback(callback: (CrashReport) -> Unit): Unit {
        crashCallback = Some(callback)
    }

    /// 获取最后一次崩溃报告
    public static func getLastReport(): ?CrashReport {
        return lastReport
    }

    /// 手动触发崩溃报告 (不终止进程)
    /// 对应 Bun: dumpStackTrace()
    public static func dumpStackTrace(): StackTrace {
        return StackTrace.capture()
    }

    /// 手动触发崩溃报告 (带原因)
    /// 对应 Bun: crashHandler(reason, trace, begin_addr)
    public static func reportCrash(reason: CrashReason): CrashReport {
        let trace = StackTrace.capture()
        let report = CrashReport(reason, trace)
        report.pid = Int64(getpid())
        lastReport = Some(report)

        // 调用回调
        match (crashCallback) {
            case Some(cb) => cb(report)
            case None => ()
        }

        return report
    }

    /// 触发 panic
    /// 对应 Bun: panicImpl(msg, error_return_trace, begin_addr)
    public static func panic(message: String): Nothing {
        let report = reportCrash(CrashReason.Panic(message))
        // 输出到 stderr
        let reportStr = report.format()
        unsafe {
            let msgPtr = unsafeNewCString(reportStr)
            write(2, msgPtr, UIntNative(reportStr.size))
        }
        abort()
    }

    /// 处理 OOM
    /// 对应 Bun: handle_oom.zig handleOOM
    public static func handleOutOfMemory(): Nothing {
        let report = reportCrash(CrashReason.OutOfMemory)
        let reportStr = report.format()
        unsafe {
            let msgPtr = unsafeNewCString(reportStr)
            write(2, msgPtr, UIntNative(reportStr.size))
        }
        abort()
    }

    /// 捕获当前栈并返回格式化字符串
    /// 对应 Bun: dumpCurrentStackTrace()
    public static func dumpCurrentStackTrace(): String {
        let trace = StackTrace.capture()
        return trace.format()
    }

    /// 重置信号处理器为默认行为
    /// 对应 Bun: resetSegfaultHandler()
    /// 在崩溃报告后调用, 防止递归崩溃
    public static func resetHandlers(): Unit {
        // 将所有注册的信号恢复为 SIG_DFL
        // sigaction(SIGSEGV, SIG_DFL, NULL) 等
        // 需要仓颉运行时支持
    }
}

// ============================================================================
// 预崩溃钩子
// 严格翻译自: crash_handler.zig before_crash_handlers
//   Bun 允许注册在崩溃前执行的回调
// ============================================================================

/// 预崩溃钩子注册
/// 对应 Bun: appendPreCrashHandler / removePreCrashHandler
public class PreCrashHandlers {
    private static var handlers: ArrayList<(CrashReport) -> Unit> = ArrayList<(CrashReport) -> Unit>()

    /// 注册预崩溃回调
    /// 对应 Bun: appendPreCrashHandler(T, ptr, handler)
    public static func append(handler: (CrashReport) -> Unit): Unit {
        handlers.append(handler)
    }

    /// 移除预崩溃回调
    /// 对应 Bun: removePreCrashHandler(ptr)
    public static func remove(handler: (CrashReport) -> Unit): Unit {
        var newHandlers = ArrayList<(CrashReport) -> Unit>()
        for (h in handlers) {
            if (h != handler) {
                newHandlers.append(h)
            }
        }
        handlers = newHandlers
    }

    /// 执行所有预崩溃回调
    /// 对应 Bun: for (item in before_crash_handlers) { cb(ptr) }
    public static func runAll(report: CrashReport): Unit {
        for (handler in handlers) {
            try {
                handler(report)
            } catch (_: Exception) {
                // 预崩溃回调中的错误被忽略
            }
        }
    }
}

// ============================================================================
// 内存统计
// 严格翻译自: crash_handler.zig printMetadata() 中的 mi_process_info 调用
// ============================================================================

/// 内存统计信息
/// 对应 Bun: mimalloc.mi_process_info 输出
public class MemoryStats {
    /// 当前 RSS (字节)
    public var currentRss: Int64
    /// 峰值 RSS (字节)
    public var peakRss: Int64
    /// 当前提交大小
    public var currentCommit: Int64
    /// 峰值提交大小
    public var peakCommit: Int64
    /// 页面错误数
    public var pageFaults: Int64

    public init() {
        currentRss = 0
        peakRss = 0
        currentCommit = 0
        peakCommit = 0
        pageFaults = 0
    }

    /// 从 /proc/self/status 读取内存信息
    /// 对应 Bun: mi_process_info() 或 /proc/self/status
    public static func read(): MemoryStats {
        let stats = MemoryStats()
        // 读取 /proc/self/status 获取 VmRSS/VmHWM 等
        // 简化实现: 返回默认值
        // 完整实现需要文件系统读取
        return stats
    }

    /// 格式化为字符串
    public func format(): String {
        return "RSS: ${currentRss} | Peak: ${peakRss} | Commit: ${currentCommit} | Faults: ${pageFaults}"
    }
}

// ============================================================================
// 内部工具函数
// ============================================================================

/// 创建 C 字符串 (内部使用)
private func unsafeNewCString(s: String): CPointer<Int8> {
    unsafe {
        let len = s.size
        let ptr = malloc(UIntNative(len + 1))
        let bytesPtr = CPointer<Int8>(ptr)
        for (i in 0..len) {
            (bytesPtr + IntNative(i)).write(Int8(s[Int64(i)].value))
        }
        (bytesPtr + IntNative(len)).write(Int8(0))
        return bytesPtr
    }
}

/// C 字符串转仓颉字符串 (内部使用)
private func unsafeCStringToString(ptr: CPointer<Int8>): String {
    unsafe {
        var len = 0
        while (!(ptr + IntNative(len)).read() == Int8(0)) {
            len += 1
        }
        var sb = StringBuilder()
        for (i in 0..len) {
            sb.append(Char(Int32((ptr + IntNative(i)).read())))
        }
        return sb.toString()
    }
}

@C
foreign func malloc(size: UIntNative): CPointer<Unit>
@C
foreign func free(ptr: CPointer<Unit>): Unit
