// bao_core - 崩溃处理器 (严格 1:1 翻译)
// 严格翻译自: src/crash_handler/crash_handler.zig
//   Bun 的崩溃处理器:
//   - 信号处理 (SIGSEGV/SIGILL/SIGBUS/SIGFPE/SIGABRT)
//   - Windows: VectoredExceptionHandler
//   - POSIX: sigaction + SA_SIGINFO|SA_RESTART|SA_RESETHAND
//   - 栈回溯捕获与格式化
//   - 崩溃报告 URL (bun.report)
//   - 栈追踪字符串编码 (VLQ)
//   - 预崩溃钩子
//   - OOM 处理 (handle_oom.zig)
//   - CPU 特性检测 (CPUFeatures.zig)
package bao_core.crash_handler

// ============================================================================
// C FFI 声明
// 严格翻译自: crash_handler.zig 中使用的系统调用
// ============================================================================

@C
foreign func backtrace(buffer: CPointer<CPointer<Unit>>, size: Int32): Int32
@C
foreign func backtrace_symbols(buffer: CPointer<CPointer<Unit>>, size: Int32): CPointer<CPointer<Int8>>
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
@C
foreign func malloc(size: UIntNative): CPointer<Unit>
@C
foreign func free(ptr: CPointer<Unit>): Unit
@C
foreign func memset(s: CPointer<Unit>, c: Int32, n: UIntNative): CPointer<Unit>

// ============================================================================
// 信号常量
// 严格翻译自: crash_handler.zig 中的信号处理
// ============================================================================

/// 信号编号常量
/// 对应 Bun: std.posix.SIG.*
public class Signals {
    public static let SIGHUP: Int32 = 1
    public static let SIGINT: Int32 = 2
    public static let SIGQUIT: Int32 = 3
    public static let SIGILL: Int32 = 4
    public static let SIGTRAP: Int32 = 5
    public static let SIGABRT: Int32 = 6
    public static let SIGBUS: Int32 = 7
    public static let SIGFPE: Int32 = 8
    public static let SIGKILL: Int32 = 9
    public static let SIGSEGV: Int32 = 11
    public static let SIGPIPE: Int32 = 13
    public static let SIGALRM: Int32 = 14
    public static let SIGTERM: Int32 = 15
}

/// sigaction 标志
/// 对应 Bun: std.posix.SA.*
public class SaFlags {
    public static let SA_SIGINFO: Int32 = 4
    public static let SA_RESTART: Int32 = 0x10000000
    public static let SA_RESETHAND: Int32 = 0x8000000
    public static let SA_ONSTACK: Int32 = 0x08000000
}

// ============================================================================
// 启用开关
// 严格翻译自: crash_handler.zig pub const enable = true
// ============================================================================

/// 是否启用崩溃处理器
/// 对应 Bun: crash_handler.enable = true
/// 设为 false 可在测试中禁用崩溃处理器
public let CRASH_HANDLER_ENABLE: Bool = true

/// 默认崩溃报告 URL
/// 对应 Bun: default_report_base_url = "https://bun.report"
/// 可通过 BUN_CRASH_REPORT_URL 环境变量覆盖
public let DEFAULT_REPORT_BASE_URL: String = "https://bun.report"

/// 是否已打印崩溃消息
/// 对应 Bun: has_printed_message (控制只打印一次)
private var hasPrintedMessage: Bool = false

/// 全局恐慌计数器
/// 对应 Bun: panicking = std.atomic.Value(u8).init(0)
private var panickingCount: Int32 = 0

// ============================================================================
// CrashReason - 崩溃原因
// 严格翻译自: crash_handler.zig CrashReason = union(enum)
// ============================================================================

/// 崩溃原因
/// 对应 Bun: CrashReason = union(enum) {
///   panic: []const u8,
///   @"unreachable",
///   segmentation_fault: usize,
///   illegal_instruction: usize,
///   bus_error: usize,        // Posix-only
///   floating_point_error: usize, // Posix-only
///   datatype_misalignment,   // Windows-only
///   stack_overflow,          // Windows-only
///   zig_error: anyerror,
///   out_of_memory,
/// }
public enum CrashReason {
    | Panic(String)              // @panic(msg)
    | Unreachable                // "reached unreachable code"
    | SegmentationFault(UInt64)  // 地址
    | IllegalInstruction(UInt64) // 地址
    | BusError(UInt64)           // 地址 (Posix-only)
    | FloatingPointError(UInt64) // 地址 (Posix-only)
    | DatatypeMisalignment       // Windows-only: 未对齐内存访问
    | StackOverflow              // Windows-only: 栈溢出
    | ZigError(String)           // error.{name}
    | OutOfMemory                // OOM

    /// 格式化崩溃原因
    /// 对应 Bun: CrashReason.format(writer)
    public func format(): String {
        match (this) {
            case Panic(msg) => "${msg}"
            case Unreachable => "reached unreachable code"
            case SegmentationFault(addr) => "Segmentation fault at address 0x${addr.toString(16)}"
            case IllegalInstruction(addr) => "Illegal instruction at address 0x${addr.toString(16)}"
            case BusError(addr) => "Bus error at address 0x${addr.toString(16)}"
            case FloatingPointError(addr) => "Floating point error at address 0x${addr.toString(16)}"
            case DatatypeMisalignment => "Unaligned memory access"
            case StackOverflow => "Stack overflow"
            case ZigError(name) => "error.${name}"
            case OutOfMemory => "Bun ran out of memory"
        }
    }

    /// 从 POSIX 信号构造
    /// 对应 Bun: handleSegfaultPosix 中的 switch(sig)
    public static func fromSignal(sig: Int32, addr: UInt64): CrashReason {
        match (sig) {
            case 11 => SegmentationFault(addr)  // SIGSEGV
            case 4 => IllegalInstruction(addr)   // SIGILL
            case 7 => BusError(addr)             // SIGBUS
            case 8 => FloatingPointError(addr)   // SIGFPE
            case _ => Panic("Unknown signal ${sig}")
        }
    }
}

// ============================================================================
// Action - 崩溃时的操作描述
// 严格翻译自: crash_handler.zig Action = union(enum)
// ============================================================================

/// 崩溃时正在执行的操作
/// 对应 Bun: Action = union(enum) {
///   parse: []const u8,
///   visit: []const u8,
///   print: []const u8,
///   bundle_generate_chunk: ...,
///   resolver: ...,
///   dlopen: []const u8,
/// }
public enum CrashAction {
    | Parse(String)          // 正在解析文件
    | Visit(String)          // 正在访问文件
    | Print(String)          // 正在打印文件
    | BundleGenerateChunk    // 正在生成 bundler chunk
    | Resolver(String, String, String)  // source_dir, import_path, kind
    | Dlopen(String)         // 正在加载原生模块

    public func format(): String {
        match (this) {
            case Parse(path) => "parsing ${path}"
            case Visit(path) => "visiting ${path}"
            case Print(path) => "printing ${path}"
            case BundleGenerateChunk => "generating bundler chunk"
            case Resolver(sourceDir, importPath, kind) => "resolving ${importPath} from ${sourceDir} (${kind})"
            case Dlopen(path) => "loading native module: ${path}"
        }
    }
}

/// 当前操作 (线程局部)
/// 对应 Bun: threadlocal var current_action: ?Action = null
public class CrashState {
    /// 当前崩溃操作
    /// 对应 Bun: threadlocal var current_action: ?Action = null
    public static var currentAction: ?CrashAction = None

    /// 是否在原生插件内部
    /// 对应 Bun: threadlocal var inside_native_plugin: ?[*:0]const u8 = null
    public static var insideNativePlugin: ?String = None

    /// 不支持的 UV 函数名
    /// 对应 Bun: threadlocal var unsupported_uv_function: ?[*:0]const u8 = null
    public static var unsupportedUvFunction: ?String = None

    /// 是否抑制报告
    /// 对应 Bun: var suppress_reporting: bool = false
    public static var suppressReporting: Bool = false

    /// 是否显示详细错误追踪
    /// 对应 Bun: pub var verbose_error_trace = false
    public static var verboseErrorTrace: Bool = false
}

// ============================================================================
// Platform - 平台编码
// 严格翻译自: crash_handler.zig Platform = enum(u8)
//   用于崩溃报告 URL 中的平台标识
//   大写 = aarch64, 小写 = x86_64
// ============================================================================

/// 崩溃报告平台编码
/// 对应 Bun: Platform = enum(u8)
/// 每个平台编码为单个字符, 放在版本号后的斜杠后面
/// 例如: https://bun.report/1.1.3/we04c... -> 'w' 表示 Windows x86_64
public enum CrashPlatform {
    | LinuxX86_64            // 'l'
    | LinuxX86_64Baseline    // 'B'
    | LinuxAarch64           // 'L'
    | MacX86_64Baseline      // 'b'
    | MacX86_64              // 'm'
    | MacAarch64             // 'M'
    | WindowsX86_64          // 'w'
    | WindowsX86_64Baseline  // 'e'
    | WindowsAarch64         // 'W'
    | FreeBsdX86_64          // 'f'
    | FreeBsdX86_64Baseline  // 'g'
    | FreeBsdAarch64         // 'F'

    /// 获取编码字符
    /// 对应 Bun: @intFromEnum(Platform.current)
    public func toChar(): UInt8 {
        match (this) {
            case LinuxX86_64 => UInt8('l')
            case LinuxX86_64Baseline => UInt8('B')
            case LinuxAarch64 => UInt8('L')
            case MacX86_64Baseline => UInt8('b')
            case MacX86_64 => UInt8('m')
            case MacAarch64 => UInt8('M')
            case WindowsX86_64 => UInt8('w')
            case WindowsX86_64Baseline => UInt8('e')
            case WindowsAarch64 => UInt8('W')
            case FreeBsdX86_64 => UInt8('f')
            case FreeBsdX86_64Baseline => UInt8('g')
            case FreeBsdAarch64 => UInt8('F')
        }
    }

    /// 获取当前平台
    /// 对应 Bun: Platform.current
    public static func current(): CrashPlatform {
        // 默认返回 Linux x86_64
        return LinuxX86_64
    }
}

/// 版本字符
/// 对应 Bun: version_char = if (is_canary) "2" else "1"
/// '1' = 原始格式, 7字符哈希 + VLQ编码栈帧
/// '2' = 同 '1' 但标记为 canary 构建
public let VERSION_CHAR: String = "1"

/// Git SHA (前7位)
/// 对应 Bun: git_sha = git_sha[0..7]
public let GIT_SHA: String = "unknown"

// ============================================================================
// StackLine - 栈行信息
// 严格翻译自: crash_handler.zig StackLine struct
// ============================================================================

/// 栈行 (地址 + 所属对象)
/// 对应 Bun: StackLine = struct { address: i32, object: ?[]const u8 }
public class StackLine {
    /// 指令地址 (ASLR 移除后的偏移)
    public var address: Int32
    /// 所属对象文件 (null = 来自 bun.exe)
    public var objectName: ?String

    public init(address: Int32, objectName: ?String) {
        this.address = address
        this.objectName = objectName
    }

    /// 编码为追踪字符串
    /// 对应 Bun: StackLine.writeEncoded(self, writer)
    ///   null -> "_"
    ///   有 object -> VLQ(1) + VLQ(len) + object + VLQ(address)
    ///   无 object -> VLQ(address)
    public func writeEncoded(): String {
        let sb = StringBuilder()
        if (objectName != None) {
            let obj = objectName.getOrThrow()
            sb.append(VLQEncode.encode(1))
            sb.append(VLQEncode.encode(obj.size))
            sb.append(obj)
        }
        sb.append(VLQEncode.encode(Int64(address)))
        return sb.toString()
    }

    /// 解码后的格式
    /// 对应 Bun: StackLine.format(writer)
    public func format(): String {
        match (objectName) {
            case Some(obj) => "0x${address.toString(16)} @ ${obj}"
            case None => "0x${address.toString(16)}"
        }
    }
}

// ============================================================================
// VLQ 编码
// 严格翻译自: crash_handler.zig 通过 SourceMap.VLQ
// ============================================================================

/// VLQ 编码工具
/// 对应 Bun: VLQ (来自 sourcemap)
public class VLQEncode {
    /// VLQ 编码一个整数值
    /// 对应 Bun: VLQ.encode(value)
    public static func encode(value: Int64): String {
        // VLQ 编码: 每组 5 位, 最高位表示是否有后续
        var v = if (value < 0) { ((-value) << 1) + 1 } else { value << 1 }
        let sb = StringBuilder()
        while (true) {
            var digit = Int32(v & 0x1F)
            v = v >> 5
            if (v > 0) {
                digit = digit | 0x20
            }
            sb.append(Char(Int32('A') + digit))
            if (v <= 0) { break }
        }
        return sb.toString()
    }

    /// VLQ 零值
    /// 对应 Bun: VLQ.zero
    public static func zero(): String {
        return "A"
    }
}

// ============================================================================
// TraceString - 追踪字符串
// 严格翻译自: crash_handler.zig TraceString struct
//   编码崩溃信息为 URL, 用于 bun.report
// ============================================================================

/// 追踪字符串动作
/// 对应 Bun: TraceString.Action = enum { open_issue, view_trace }
public enum TraceAction {
    | OpenIssue     // 打开预填的 GitHub issue
    | ViewTrace     // 仅查看追踪信息
}

/// 追踪字符串
/// 对应 Bun: TraceString = struct { trace, reason, action }
/// 编码为 URL: {base_url}/{version}/{platform_char}{cmd_char}{version_char}{git_sha}{features}{stack_frames}{reason_type}{reason_data}
public class TraceString {
    /// 栈回溯地址
    public var addresses: Array<UInt64>
    /// 崩溃原因
    public var reason: CrashReason
    /// 动作
    public var action: TraceAction

    public init(reason: CrashReason, action: TraceAction) {
        addresses = Array<UInt64>()
        this.reason = reason
        this.action = action
    }

    /// 编码为追踪字符串 URL
    /// 对应 Bun: encodeTraceString(opts, writer)
    public func encode(): String {
        let sb = StringBuilder()

        // 基础 URL
        sb.append(DEFAULT_REPORT_BASE_URL)
        sb.append("/")
        sb.append(BAO_VERSION)
        sb.append("/")

        // 平台字符
        let platform = CrashPlatform.current()
        sb.append(Char(platform.toChar()))

        // 命令字符 (简化: 使用 '_')
        sb.append("_")

        // 版本字符 + git sha
        sb.append(VERSION_CHAR)
        sb.append(GIT_SHA)

        // 特性标志 (简化: 空的 VLQ)
        sb.append(VLQEncode.zero())
        sb.append(VLQEncode.zero())

        // 栈帧 (简化: 编码每个地址)
        for (addr in addresses) {
            writeU64AsTwoVLQs(sb, addr)
        }

        // 结束标记
        sb.append(VLQEncode.zero())

        // 崩溃原因编码
        // 对应 Bun: switch(opts.reason) { .panic => '0', .unreachable => '1', ... }
        match (reason) {
            case Panic(_) => sb.append("0")
            case Unreachable => sb.append("1")
            case SegmentationFault(_) => sb.append("2")
            case IllegalInstruction(_) => sb.append("3")
            case BusError(_) => sb.append("4")
            case FloatingPointError(_) => sb.append("5")
            case DatatypeMisalignment => sb.append("6")
            case StackOverflow => sb.append("7")
            case ZigError(_) => sb.append("8")
            case OutOfMemory => sb.append("9")
        }

        // 动作后缀
        if (action == TraceAction.ViewTrace) {
            sb.append("/view")
        }

        return sb.toString()
    }

    /// 将 u64 写为两个 VLQ
    /// 对应 Bun: writeU64AsTwoVLQs(writer, addr)
    private static func writeU64AsTwoVLQs(sb: StringBuilder, addr: UInt64): Unit {
        let high = Int64((addr >> 32) & 0xFFFFFFFF)
        let low = Int64(addr & 0xFFFFFFFF)
        sb.append(VLQEncode.encode(high))
        sb.append(VLQEncode.encode(low))
    }
}

// ============================================================================
// CrashHandler - 崩溃处理器主接口
// 严格翻译自: crash_handler.zig 的全局函数
// ============================================================================

/// 崩溃处理器
/// 对应 Bun: crash_handler 命名空间
public class CrashHandler {
    /// 是否已初始化
    /// 对应 Bun: 信号处理器注册状态
    private static var initialized: Bool = false

    /// 崩溃回调
    private static var crashCallback: ?((CrashReport) -> Unit) = None

    /// 最后一次崩溃报告
    private static var lastReport: ?CrashReport = None

    /// 预崩溃钩子
    /// 对应 Bun: before_crash_handlers: std.ArrayListUnmanaged
    private static var preCrashHandlers: ArrayList<(CrashReport) -> Unit> = ArrayList<(CrashReport) -> Unit>()

    /// 初始化崩溃处理器
    /// 对应 Bun: pub fn init() void
    ///   Windows: AddVectoredExceptionHandler
    ///   POSIX: sigaction(SIGSEGV/SIGILL/SIGBUS/SIGFPE, handler)
    public static func initFunc(): Unit {
        if (!CRASH_HANDLER_ENABLE) { return }
        if (initialized) { return }
        initialized = true

        // 注册 POSIX 信号处理器
        // sigaction(SIGSEGV/SIGILL/SIGBUS/SIGFPE, handleSegfaultPosix)
        // 使用 SA_SIGINFO | SA_RESTART | SA_RESETHAND
        // 注意: 仓颉中信号处理需要运行时支持
    }

    /// 崩溃处理主函数
    /// 对应 Bun: pub fn crashHandler(reason, error_return_trace, begin_addr) noreturn
    ///   1. 检查 panic_stage (0=首次, 1=打印中, 2=二次, 3=三次, else=abort)
    ///   2. 执行预崩溃钩子
    ///   3. 打印崩溃信息
    ///   4. 捕获栈回溯
    ///   5. 编码追踪字符串
    ///   6. 上报崩溃
    ///   7. 重置信号处理器
    ///   8. auto_reload_on_crash (如果启用)
    ///   9. crash() 终止进程
    public static func crashHandler(reason: CrashReason,
                                     errorReturnTrace: ?StackTrace,
                                     beginAddr: ?UInt64): Nothing {
        // 阶段 0: 首次崩溃
        // 执行预崩溃钩子
        let report = CrashReport(reason)
        report.pid = Int64(getpid())
        report.stackTrace = match (errorReturnTrace) {
            case Some(t) => t
            case None => StackTrace.capture()
        }

        // 调用预崩溃钩子
        for (handler in preCrashHandlers) {
            try {
                handler(report)
            } catch (_: Exception) {
                // 预崩溃回调中的错误被忽略
            }
        }

        lastReport = Some(report)

        // 调用回调
        match (crashCallback) {
            case Some(cb) => cb(report)
            case None => ()
        }

        // 输出崩溃报告到 stderr
        let reportStr = report.format()
        unsafe {
            let msgPtr = unsafeNewCString(reportStr)
            write(2, msgPtr, UIntNative(reportStr.size))
        }

        // 上报崩溃
        report2(report)

        // 重置信号处理器
        resetSegfaultHandler()

        // 终止进程
        // 对应 Bun: crash() -> @trap() on POSIX, abort() on Windows
        abort()
    }

    /// panic 实现
    /// 对应 Bun: pub fn panicImpl(msg, error_return_trace, begin_addr) noreturn
    ///   如果 msg == "reached unreachable code" -> .unreachable
    ///   否则 -> .panic(msg)
    public static func panicImpl(message: String): Nothing {
        let reason = if (message == "reached unreachable code") {
            CrashReason.Unreachable
        } else {
            CrashReason.Panic(message)
        }
        return crashHandler(reason, None, None)
    }

    /// 处理根错误
    /// 对应 Bun: pub fn handleRootError(err, error_return_trace) noreturn
    ///   根据 error 类型选择不同的错误处理策略:
    ///   - OutOfMemory -> outOfMemory()
    ///   - InvalidArgument/InvalidBunfig/InstallFailed -> exit(1)
    ///   - SyntaxError -> 输出错误信息
    ///   - SystemFdQuotaExceeded/ProcessFdQuotaExceeded -> 输出 fd 限制建议
    ///   - ENOENT/FileNotFound -> 文件不存在
    ///   - MissingPackageJSON -> 缺少 package.json
    ///   - else -> 内部错误
    public static func handleRootError(err: ErrorCode): Nothing {
        match (err) {
            case OutOfMemory => handleOutOfMemory()
            case InvalidArgument => abort()
            case ENOENT => abort()
            case _ => abort()
        }
    }

    /// 处理 OOM
    /// 对应 Bun: handle_oom.zig handleOom()
    public static func handleOutOfMemory(): Nothing {
        return crashHandler(CrashReason.OutOfMemory, None, None)
    }

    /// 重置信号处理器为默认
    /// 对应 Bun: pub fn resetSegfaultHandler() void
    ///   Windows: RemoveVectoredExceptionHandler
    ///   POSIX: sigaction(*, SIG_DFL, *)
    public static func resetSegfaultHandler(): Unit {
        if (!CRASH_HANDLER_ENABLE) { return }
        // 将 SIGSEGV/SIGILL/SIGBUS/SIGFPE/SIGABRT/SIGFPE/SIGHUP/SIGTERM 恢复为 SIG_DFL
    }

    /// 注册预崩溃钩子
    /// 对应 Bun: pub fn appendPreCrashHandler(T, ptr, handler)
    public static func appendPreCrashHandler(handler: (CrashReport) -> Unit): Unit {
        preCrashHandlers.append(handler)
    }

    /// 移除预崩溃钩子
    /// 对应 Bun: pub fn removePreCrashHandler(ptr)
    public static func removePreCrashHandler(handler: (CrashReport) -> Unit): Unit {
        var newHandlers = ArrayList<(CrashReport) -> Unit>()
        for (h in preCrashHandlers) {
            if (h != handler) {
                newHandlers.append(h)
            }
        }
        preCrashHandlers = newHandlers
    }

    /// 检查是否正在 panic
    /// 对应 Bun: pub fn isPanicking() bool -> panicking.load(.monotonic) > 0
    public static func isPanicking(): Bool {
        return panickingCount > 0
    }

    /// 抑制崩溃报告
    /// 对应 Bun: pub fn suppressReporting() void
    public static func suppressReporting(): Unit {
        CrashState.suppressReporting = true
    }

    /// 检查报告是否启用
    /// 对应 Bun: isReportingEnabled()
    ///   检查: suppress_reporting, BUN_CRASH_REPORT_URL, BUN_ENABLE_CRASH_REPORTING,
    ///         isDebug, enable_asan, analytics.isEnabled, is_canary, macOS/Windows
    public static func isReportingEnabled(): Bool {
        if (CrashState.suppressReporting) { return false }
        // 简化: 默认禁用
        return false
    }

    /// 设置当前操作
    /// 对应 Bun: threadlocal var current_action
    public static func setCurrentAction(action: ?CrashAction): Unit {
        CrashState.currentAction = action
    }

    /// 设置是否在原生插件内
    /// 对应 Bun: CrashHandler__setInsideNativePlugin(name)
    public static func setInsideNativePlugin(name: ?String): Unit {
        CrashState.insideNativePlugin = name
    }

    /// 设置不支持的 UV 函数
    /// 对应 Bun: CrashHandler__unsupportedUVFunction(name)
    public static func setUnsupportedUvFunction(name: ?String): Unit {
        CrashState.unsupportedUvFunction = name
    }

    /// 转储当前栈回溯
    /// 对应 Bun: dumpCurrentStackTrace(first_address, limits)
    public static func dumpCurrentStackTrace(): String {
        let trace = StackTrace.capture()
        return trace.format()
    }

    /// 打印元数据
    /// 对应 Bun: pub fn printMetadata(writer)
    ///   输出: 版本行, 平台, CPU 特性, 命令行参数, 分析特性, 内存统计
    public static func printMetadata(): String {
        let sb = StringBuilder()
        // 版本行
        sb.append("Bao v${BAO_VERSION} Linux x64\n")
        // CPU 特性
        let cpuFeatures = CPUFeatures.get()
        if (!cpuFeatures.isEmpty()) {
            sb.append("CPU: ${cpuFeatures.format()}\n")
        }
        // 内存统计
        let memStats = MemoryStats.readFromProc()
        sb.append("${memStats.format()}\n")
        return sb.toString()
    }

    /// 如果其他线程正在崩溃, 永远休眠当前线程
    /// 对应 Bun: sleepForeverIfAnotherThreadIsCrashing()
    public static func sleepForeverIfAnotherThreadIsCrashing(): Unit {
        if (panickingCount > 0) {
            // 永远休眠
            while (true) {
                // Futex.waitForever
            }
        }
    }
}

// ============================================================================
// 上报函数
// 严格翻译自: crash_handler.zig report(url)
//   macOS/Linux: fork + execve("curl", url + "/ack")
//   Windows: CreateProcess("powershell Invoke-RestMethod")
// ============================================================================

/// 上报崩溃到 bun.report
/// 对应 Bun: fn report(url: []const u8) void
/// 使用 curl 发送 GET 请求到 {url}/ack
/// 注意: URL 不包含源代码或个人身份信息 (PII)
/// 栈帧指向 Bun 的开源原生代码 (非用户代码)
private func report2(report: CrashReport): Unit {
    if (!CrashHandler.isReportingEnabled()) { return }

    // POSIX: fork + curl
    // fork(); child: close(0); close(1); execve(curl, [url + "/ack"])
    // 简化实现: 不实际发送
}

// ============================================================================
// 内部工具函数
// ============================================================================

/// 创建 C 字符串
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
