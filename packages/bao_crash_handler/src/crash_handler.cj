// bao_crash_handler - 崩溃处理器
// 严格翻译自: bun/src/crash_handler/crash_handler.zig
//   崩溃捕获、栈追踪、崩溃报告上传、段错误处理
package bao_crash_handler

import bao_core.*
import std.collection.*

// Helper: convert Int64 to hex string
func int64ToHex(n: Int64): String {
    if (n == 0) { return "0" }
    let hexChars = "0123456789abcdef"
    var result = ""
    var num = n
    while (num > 0) {
        let digit = num % 16
        result = hexChars[digit..digit+1].toString() + result
        num = num / 16
    }
    return result
}

// Helper: convert Int32 to hex string
func int32ToHex(n: Int32): String {
    return int64ToHex(Int64(n))
}

// ============================================================================
// 常量和全局状态
// 严格翻译自: bun/src/crash_handler/crash_handler.zig - 全局变量
// ============================================================================

/// 是否启用崩溃处理器
/// 对应: pub const enable = true;
public let CRASH_HANDLER_ENABLE: Bool = true

/// 默认崩溃报告 URL
/// 对应: const default_report_base_url = "https://bun.report";
public let DEFAULT_REPORT_BASE_URL: String = "https://bun.report"

/// 是否已打印崩溃消息 (只打印一次)
/// 对应: var has_printed_message = false;
public var hasPrintedMessage: Bool = false

/// 正在 panic 的线程计数 (原子操作)
/// 对应: var panicking = std.atomic.Value(u8).init(0);
public var panickingCount: Int64 = 0

/// 是否禁止崩溃报告
/// 对应: var suppress_reporting: bool = false;
public var suppressReportingFlag: Bool = false

/// 详细错误追踪标志
/// 对应: pub var verbose_error_trace = false;
public var verboseErrorTrace: Bool = false

/// 报告的内存大小
/// 对应: export var Bun__reported_memory_size: usize = 0;
public var reportedMemorySize: Int64 = 0

// ============================================================================
// CrashReason - 崩溃原因
// 严格翻译自: bun/src/crash_handler/crash_handler.zig - CrashReason
//   pub const CrashReason = union(enum) {
//       panic: []const u8,
//       @"unreachable",
//       segmentation_fault: usize,
//       illegal_instruction: usize,
//       bus_error: usize,
//       floating_point_error: usize,
//       datatype_misalignment,
//       stack_overflow,
//       zig_error: anyerror,
//       out_of_memory,
//   };
// ============================================================================

/// 崩溃原因 - 对应 Bun CrashReason (union(enum))
/// 包含崩溃类型和关联数据
public enum CrashReason {
    | Panic(String)                    // panic: []const u8
    | Unreachable                      // @"unreachable"
    | SegmentationFault(Int64)         // segmentation_fault: usize
    | IllegalInstruction(Int64)        // illegal_instruction: usize
    | BusError(Int64)                  // bus_error: usize
    | FloatingPointError(Int64)        // floating_point_error: usize
    | DatatypeMisalignment             // datatype_misalignment
    | StackOverflow                    // stack_overflow
    | ZigError(String)                 // zig_error: anyerror
    | OutOfMemory                      // out_of_memory

    /// 格式化崩溃原因
    /// 对应: pub fn format(reason: CrashReason, writer: *std.Io.Writer) !void
    public func format(): String {
        match (this) {
            case Panic(message) =>
                message
            case Unreachable =>
                "reached unreachable code"
            case SegmentationFault(addr) =>
                "Segmentation fault at address 0x${int64ToHex(addr)}"
            case IllegalInstruction(addr) =>
                "Illegal instruction at address 0x${int64ToHex(addr)}"
            case BusError(addr) =>
                "Bus error at address 0x${int64ToHex(addr)}"
            case FloatingPointError(addr) =>
                "Floating point error at address 0x${int64ToHex(addr)}"
            case DatatypeMisalignment =>
                "Unaligned memory access"
            case StackOverflow =>
                "Stack overflow"
            case ZigError(errName) =>
                "error.${errName}"
            case OutOfMemory =>
                "Bao ran out of memory"
        }
    }
}

// ============================================================================
// Action - 崩溃时正在执行的动作
// 严格翻译自: bun/src/crash_handler/crash_handler.zig - Action
//   pub const Action = union(enum) {
//       parse: []const u8,
//       visit: []const u8,
//       print: []const u8,
//       bundle_generate_chunk: ...,
//       resolver: ...,
//       dlopen: []const u8,
//   };
// ============================================================================

/// 崩溃动作 - 对应 Bun Action (union(enum))
/// 记录崩溃发生时正在执行的操作
public enum Action {
    | Parse(String)              // parse: []const u8
    | Visit(String)              // visit: []const u8
    | Print(String)              // print: []const u8
    | BundleGenerateChunk        // bundle_generate_chunk (简化)
    | Resolver(String, String)   // resolver: source_dir, import_path
    | Dlopen(String)             // dlopen: []const u8

    /// 格式化动作描述
    /// 对应: pub fn format(act: Action, writer: *std.Io.Writer) !void
    public func format(): String {
        match (this) {
            case Parse(path) =>
                "parsing ${path}"
            case Visit(path) =>
                "visiting ${path}"
            case Print(path) =>
                "printing ${path}"
            case BundleGenerateChunk =>
                "generating bundler chunk"
            case Resolver(importPath, sourceDir) =>
                "resolving ${importPath} from ${sourceDir}"
            case Dlopen(path) =>
                "loading native module: ${path}"
        }
    }
}

// ============================================================================
// StackTrace - 栈追踪
// 严格翻译自: bun/src/crash_handler/crash_handler.zig - StackTrace 相关
//   std.builtin.StackTrace = { index, instruction_addresses }
// ============================================================================

/// 栈追踪 - 对应 std.builtin.StackTrace
/// 存储捕获的指令地址列表
public struct StackTrace {
    /// 指令地址数组
    public var instructionAddresses: Array<Int64>
    /// 有效的地址数量
    public var index: Int64

    public init() {
        instructionAddresses = Array<Int64>()
        index = 0
    }

    public init(capacity: Int64) {
        instructionAddresses = Array<Int64>(capacity, repeat: Int64(0))
        index = 0
    }
}

// ============================================================================
// StackLine - 栈行信息
// 严格翻译自: bun/src/crash_handler/crash_handler.zig - StackLine
//   const StackLine = struct {
//       address: i32,
//       object: ?[]const u8,
//       pub fn fromAddress, writeEncoded, format, writeDecoded
//   };
// ============================================================================

/// 栈行信息 - 对应 Bun StackLine
/// 表示栈追踪中的一个帧
public struct StackLine {
    /// 相对地址
    /// 对应: address: i32
    public var address: Int32

    /// 所属对象名 (null 表示来自主程序)
    /// 对应: object: ?[]const u8
    public var objectName: ?String

    public init(address: Int32, objectName: ?String) {
        this.address = address
        this.objectName = objectName
    }

    /// 从地址获取栈行信息
    /// 对应: pub fn fromAddress(addr: usize, name_bytes: []u8) ?StackLine
    ///   平台相关: Windows (模块查找), macOS (dyld), Linux (dl_iterate_phdr)
    public static func fromAddress(addr: Int64): ?StackLine {
        // 仓颉中通过 FFI 实现平台相关的地址解析
        // 简化实现: 返回空值
        // 完整实现需要:
        //   - Linux: dl_iterate_phdr 回调遍历共享对象
        //   - macOS: _dyld_image_count + _dyld_get_image_header 遍历镜像
        //   - Windows: GetModuleHandleFromAddress
        None
    }

    /// 编码栈行
    /// 对应: pub fn writeEncoded(self: ?StackLine, writer: anytype) !void
    ///   使用 VLQ 编码地址信息
    public func writeEncoded(): String {
        if (objectName.isSome()) {
            let obj = objectName.getOrThrow()
            "1:${obj.size}:${obj}${address}"
        } else {
            "_"
        }
    }

    /// 格式化为可读字符串
    /// 对应: pub fn format(line: StackLine, writer: *std.Io.Writer) !void
    public func format(): String {
        if (objectName.isSome()) {
            "0x${int32ToHex(address)} @ ${objectName.getOrThrow()}"
        } else {
            "0x${int32ToHex(address)}"
        }
    }
}

// ============================================================================
// StoredTrace - 存储的栈追踪
// 严格翻译自: bun/src/crash_handler/crash_handler.zig - StoredTrace
//   pub const StoredTrace = struct {
//       data: [31]usize,
//       index: usize,
//       pub const empty, trace, capture, from
//   };
// ============================================================================

/// 存储的栈追踪 - 对应 Bun StoredTrace
/// 可以在之后打印的栈追踪副本
public struct StoredTrace {
    /// 数据数组 (最多 31 帧)
    /// 对应: data: [31]usize
    public var data: Array<Int64>

    /// 有效帧数
    /// 对应: index: usize
    public var index: Int64

    public init() {
        data = Array<Int64>(31, repeat: Int64(0))
        index = 0
    }

    /// 空追踪
    /// 对应: pub const empty: StoredTrace = .{ .data = .{0} ** 31, .index = 0 };
    public static func createEmpty(): StoredTrace {
        var trace = StoredTrace()
        trace.index = 0
        return trace
    }

    public static let EMPTY: StoredTrace = createEmpty()

    /// 获取 StackTrace 视图
    /// 对应: pub fn trace(stored: *StoredTrace) std.builtin.StackTrace
    public func trace(): StackTrace {
        var st = StackTrace()
        st.instructionAddresses = data
        st.index = index
        st
    }

    /// 捕获当前栈追踪
    /// 对应: pub fn capture(begin: ?usize) StoredTrace
    public static func capture(begin: ?Int64): StoredTrace {
        let stored = StoredTrace()
        // 仓颉中通过 FFI 调用捕获栈追踪
        // 对应: std.debug.captureStackTrace(begin orelse @returnAddress(), &frame)
        stored
    }

    /// 从 StackTrace 创建
    /// 对应: pub fn from(stack_trace: ?*std.builtin.StackTrace) StoredTrace
    public static func from(stackTrace: ?StackTrace): StoredTrace {
        if (stackTrace.isSome()) {
            let st = stackTrace.getOrThrow()
            var result = StoredTrace()
            let count = if (st.index < 31) { st.index } else { 31 }
            for (i in 0..count) {
                result.data[i] = st.instructionAddresses[i]
            }
            result.index = count
            result
        } else {
            EMPTY
        }
    }
}

// ============================================================================
// TraceString - 追踪字符串
// 严格翻译自: bun/src/crash_handler/crash_handler.zig - TraceString
//   const TraceString = struct {
//       trace: *const std.builtin.StackTrace,
//       reason: CrashReason,
//       action: TraceString.Action,
//   };
// ============================================================================

/// 追踪字符串动作
/// 对应: TraceString.Action
public enum TraceStringAction {
    | OpenIssue    // open_issue - 打开预填的 GitHub issue
    | ViewTrace    // view_trace - 仅查看追踪
}

/// 追踪字符串 - 对应 Bun TraceString
/// 编码崩溃信息为可分享的 URL
public struct TraceString {
    /// 栈追踪
    /// 对应: trace: *const std.builtin.StackTrace
    public var trace: StackTrace

    /// 崩溃原因
    /// 对应: reason: CrashReason
    public var reason: CrashReason

    /// 动作
    /// 对应: action: TraceString.Action
    public var action: TraceStringAction

    public init(trace: StackTrace, reason: CrashReason, action: TraceStringAction) {
        this.trace = trace
        this.reason = reason
        this.action = action
    }

    /// 编码追踪字符串
    /// 对应: fn encodeTraceString(opts: TraceString, writer: anytype) !void
    ///   格式: {base_url}/{version}/{platform_char}{cmd_char}{version_char}{git_sha}{vlq_features}{stack_lines}{reason_code}{reason_data}
    public func encode(): String {
        var sb = StringBuilder()

        // 基础 URL
        // 对应: try writer.writeAll(reportBaseUrl());
        sb.append(CrashHandler.reportBaseUrl())

        // 版本和平台
        // 对应: "/" ++ bun.Environment.version_string ++ "/" ++ @intFromEnum(Platform.current)
        sb.append("/")
        sb.append(Environment.VERSION_STRING)
        sb.append("/")
        sb.append(CrashPlatform.current().toChar())

        // 命令字符
        // 对应: try writer.writeByte(if (bun.cli.Cli.cmd) |cmd| cmd.char() else '_')
        sb.append("_")

        // 版本字符和 git sha
        // 对应: version_char ++ git_sha
        sb.append(CrashHandler.VERSION_CHAR)
        sb.append(CrashHandler.GIT_SHA)

        // 特性标志
        // 对应: const packed_features = bun.analytics.packedFeatures()
        //   try writeU64AsTwoVLQs(writer, @bitCast(packed_features))
        sb.append("AA") // 占位: 两个 VLQ 编码的零

        // 栈帧
        // 对应: for (opts.trace.instruction_addresses[0..opts.trace.index]) |addr| { ... }
        for (i in 0..trace.index) {
            let addr = trace.instructionAddresses[i]
            let line = StackLine.fromAddress(addr)
            if (line.isSome()) {
                sb.append(line.getOrThrow().writeEncoded())
            } else {
                sb.append("_")
            }
        }

        // 零终止栈帧
        // 对应: try writer.writeAll(VLQ.zero.slice())
        sb.append("A")

        // 崩溃原因编码
        // 对应: switch (opts.reason) { ... }
        match (reason) {
            case Panic(message) =>
                sb.append("0")
                sb.append(encodeBase64(message))
            case Unreachable =>
                sb.append("1")
            case SegmentationFault(addr) =>
                sb.append("2")
                sb.append(writeU64AsTwoVLQs(addr))
            case IllegalInstruction(addr) =>
                sb.append("3")
                sb.append(writeU64AsTwoVLQs(addr))
            case BusError(addr) =>
                sb.append("4")
                sb.append(writeU64AsTwoVLQs(addr))
            case FloatingPointError(addr) =>
                sb.append("5")
                sb.append(writeU64AsTwoVLQs(addr))
            case DatatypeMisalignment =>
                sb.append("6")
            case StackOverflow =>
                sb.append("7")
            case ZigError(errName) =>
                sb.append("8")
                sb.append(errName)
            case OutOfMemory =>
                sb.append("9")
        }

        // 动作后缀
        // 对应: if (opts.action == .view_trace) { try writer.writeAll("/view") }
        match (action) {
            case ViewTrace => sb.append("/view")
            case _ => ()
        }

        sb.toString()
    }

    /// 将 u64 编码为两个 VLQ
    /// 对应: pub fn writeU64AsTwoVLQs(writer: anytype, addr: usize) !void
    private static func writeU64AsTwoVLQs(addr: Int64): String {
        // 简化实现: 十六进制表示
        int64ToHex(addr)
    }

    /// Base64 编码辅助
    private static func encodeBase64(data: String): String {
        // 简化: 实际实现需要 zlib 压缩 + base64
        data
    }
}

// ============================================================================
// CrashPlatform - 崩溃追踪平台编码
// 严格翻译自: bun/src/crash_handler/crash_handler.zig - Platform
//   const Platform = enum(u8) {
//       linux_x86_64 = 'l',
//       linux_x86_64_baseline = 'B',
//       linux_aarch64 = 'L',
//       mac_x86_64_baseline = 'b',
//       mac_x86_64 = 'm',
//       mac_aarch64 = 'M',
//       windows_x86_64 = 'w',
//       windows_x86_64_baseline = 'e',
//       windows_aarch64 = 'W',
//       freebsd_x86_64 = 'f',
//       freebsd_x86_64_baseline = 'g',
//       freebsd_aarch64 = 'F',
//       const current = ...
//   };
// ============================================================================

/// 崩溃追踪平台编码 - 对应 Bun crash_handler.Platform
/// 大写字母表示 aarch64，小写字母表示 x86_64
public enum CrashPlatform {
    | LinuxX86_64           // 'l'
    | LinuxX86_64Baseline   // 'B'
    | LinuxAarch64          // 'L'
    | MacX86_64Baseline     // 'b'
    | MacX86_64             // 'm'
    | MacAarch64            // 'M'
    | WindowsX86_64         // 'w'
    | WindowsX86_64Baseline // 'e'
    | WindowsAarch64        // 'W'
    | FreeBSDX86_64         // 'f'
    | FreeBSDX86_64Baseline // 'g'
    | FreeBSDDAarch64       // 'F'

    /// 当前平台
    /// 对应: const current = @field(Platform, @tagName(bun.Environment.os) ++ "_" ++ @tagName(builtin.target.cpu.arch) ++ ...)
    public static func current(): CrashPlatform {
        if (Environment.IS_LINUX) {
            if (Environment.IS_X64) { LinuxX86_64 }
            else if (Environment.IS_AARCH64) { LinuxAarch64 }
            else { LinuxX86_64 }
        } else if (Environment.IS_MAC) {
            if (Environment.IS_X64) { MacX86_64 }
            else if (Environment.IS_AARCH64) { MacAarch64 }
            else { MacX86_64 }
        } else if (Environment.IS_WINDOWS) {
            if (Environment.IS_X64) { WindowsX86_64 }
            else if (Environment.IS_AARCH64) { WindowsAarch64 }
            else { WindowsX86_64 }
        } else if (Environment.IS_FREEBSD) {
            if (Environment.IS_X64) { FreeBSDX86_64 }
            else { FreeBSDX86_64 }
        } else {
            LinuxX86_64
        }
    }

    /// 转为单字符编码
    /// 对应: @intFromEnum(Platform.current)
    public func toChar(): String {
        match (this) {
            case LinuxX86_64 => "l"
            case LinuxX86_64Baseline => "B"
            case LinuxAarch64 => "L"
            case MacX86_64Baseline => "b"
            case MacX86_64 => "m"
            case MacAarch64 => "M"
            case WindowsX86_64 => "w"
            case WindowsX86_64Baseline => "e"
            case WindowsAarch64 => "W"
            case FreeBSDX86_64 => "f"
            case FreeBSDX86_64Baseline => "g"
            case FreeBSDDAarch64 => "F"
        }
    }
}

// ============================================================================
// WriteStackTraceLimits - 栈追踪输出限制
// 严格翻译自: bun/src/crash_handler/crash_handler.zig - WriteStackTraceLimits
//   pub const WriteStackTraceLimits = struct {
//       frame_count: usize = std.math.maxInt(usize),
//       stop_at_jsc_llint: bool = false,
//       skip_stdlib: bool = false,
//       skip_file_patterns: []const []const u8 = &.{},
//       skip_function_patterns: []const []const u8 = &.{},
//   };
// ============================================================================

/// 栈追踪输出限制 - 对应 Bun WriteStackTraceLimits
public struct WriteStackTraceLimits {
    /// 最大帧数
    /// 对应: frame_count: usize = std.math.maxInt(usize)
    public var frameCount: Int64

    /// 是否在 JSC LLInt 帧停止
    /// 对应: stop_at_jsc_llint: bool = false
    public var stopAtJscLlint: Bool

    /// 是否跳过标准库帧
    /// 对应: skip_stdlib: bool = false
    public var skipStdlib: Bool

    /// 要跳过的文件模式
    /// 对应: skip_file_patterns: []const []const u8 = &.{}
    public var skipFilePatterns: Array<String>

    /// 要跳过的函数模式
    /// 对应: skip_function_patterns: []const []const u8 = &.{}
    public var skipFunctionPatterns: Array<String>

    public init() {
        frameCount = Int64.Max
        stopAtJscLlint = false
        skipStdlib = false
        skipFilePatterns = Array<String>()
        skipFunctionPatterns = Array<String>()
    }

    public static func defaultLimits(): WriteStackTraceLimits {
        WriteStackTraceLimits()
    }
}

// ============================================================================
// SourceAtAddress - 地址源码信息
// 严格翻译自: bun/src/crash_handler/crash_handler.zig - SourceAtAddress
//   pub const SourceAtAddress = struct {
//       source_location: ?SourceLocation,
//       symbol_name: []const u8,
//       compile_unit_name: []const u8,
//   };
// ============================================================================

/// 地址源码信息 - 对应 Bun SourceAtAddress
public struct SourceAtAddress {
    /// 源码位置
    /// 对应: source_location: ?SourceLocation
    public var sourceLocation: ?SourceLocationInfo

    /// 符号名
    /// 对应: symbol_name: []const u8
    public var symbolName: String

    /// 编译单元名
    /// 对应: compile_unit_name: []const u8
    public var compileUnitName: String

    public init() {
        sourceLocation = None
        symbolName = ""
        compileUnitName = ""
    }
}

/// 源码位置信息 (替代 std.debug.SourceLocation)
public struct SourceLocationInfo {
    public var fileName: String
    public var line: Int64
    public var column: Int64

    public init(fileName: String, line: Int64, column: Int64) {
        this.fileName = fileName
        this.line = line
        this.column = column
    }
}

// ============================================================================
// OnBeforeCrash - 崩溃前回调
// 严格翻译自: bun/src/crash_handler/crash_handler.zig - OnBeforeCrash
//   const OnBeforeCrash = fn (opaque_ptr: *anyopaque) void;
// ============================================================================

/// 崩溃前回调函数类型
/// 对应: const OnBeforeCrash = fn (opaque_ptr: *anyopaque) void
public type OnBeforeCrashCallback = () -> Unit

// ============================================================================
// BeforeCrashHandler - 崩溃前处理器
// 严格翻译自: var before_crash_handlers: std.ArrayListUnmanaged(...)
// ============================================================================

/// 崩溃前处理器条目
public struct BeforeCrashHandlerEntry {
    public var id: Int64
    public var callback: OnBeforeCrashCallback

    public init(id: Int64, callback: OnBeforeCrashCallback) {
        this.id = id
        this.callback = callback
    }
}

// ============================================================================
// CrashHandler - 崩溃处理器
// 严格翻译自: bun/src/crash_handler/crash_handler.zig - 主要导出函数
//   pub fn crashHandler, handleRootError, panicImpl, init, resetSegfaultHandler,
//         resetOnPosix, reportBaseUrl, report, dumpStackTrace, dumpCurrentStackTrace,
//         handleErrorReturnTrace, printMetadata, appendPreCrashHandler,
//         removePreCrashHandler, isPanicking, suppressReporting,
//         suppressCoreDumpsIfNecessary, sleepForeverIfAnotherThreadIsCrashing
// ============================================================================

/// 崩溃处理器 - 对应 Bun crash_handler 模块的主要导出
/// 在 debug 构建中可以打印映射到源代码的栈追踪
/// 在 release 构建中使用 "trace string" (URL 编码的压缩栈追踪)
public class CrashHandler {
    /// 版本字符
    /// 对应: const version_char = if (bun.Environment.is_canary) "2" else "1"
    public static let VERSION_CHAR: String = "1"

    /// Git SHA (前 7 字符)
    /// 对应: const git_sha = if (bun.Environment.git_sha.len > 0) bun.Environment.git_sha[0..7] else "unknown"
    public static let GIT_SHA: String = "unknown"

    /// 崩溃前处理器列表
    /// 对应: var before_crash_handlers: std.ArrayListUnmanaged(...)
    private static var beforeCrashHandlers: ArrayList<BeforeCrashHandlerEntry> = ArrayList<BeforeCrashHandlerEntry>()

    /// 当前正在执行的动作
    /// 对应: pub threadlocal var current_action: ?Action = null
    public static var currentAction: ?Action = None

    /// 原生插件名
    /// 对应: threadlocal var inside_native_plugin: ?[*:0]const u8 = null
    public static var insideNativePlugin: ?String = None

    /// 不支持的 UV 函数名
    /// 对应: threadlocal var unsupported_uv_function: ?[*:0]const u8 = null
    public static var unsupportedUvFunction: ?String = None

    // ========================================================================
    // 初始化和重置
    // 严格翻译自: pub fn init() void, pub fn resetSegfaultHandler() void
    // ========================================================================

    /// 初始化崩溃处理器
    /// 对应: pub fn init() void
    ///   注册段错误、非法指令、总线错误、浮点异常的信号处理器
    public static func initFunc(): Unit {
        if (!CRASH_HANDLER_ENABLE) { return }
        if (Environment.ENABLE_ASAN) { return }

        if (Environment.IS_POSIX) {
            resetOnPosix()
        } else if (Environment.IS_WINDOWS) {
            // 注册 Windows 向量化异常处理器
            // 对应: windows_segfault_handle = windows.kernel32.AddVectoredExceptionHandler(0, handleSegfaultWindows)
        }
    }

    /// 重置 POSIX 信号处理器
    /// 对应: pub fn resetOnPosix() void
    public static func resetOnPosix(): Unit {
        if (Environment.ENABLE_ASAN) { return }

        // 对应: 设置 SIGSEGV, SIGILL, SIGBUS, SIGFPE 的处理器
        // 仓颉中通过 FFI 调用 sigaction
        // bun.sys.sigaction(std.posix.SIG.SEGV, act, null)
        // bun.sys.sigaction(std.posix.SIG.ILL, act, null)
        // bun.sys.sigaction(std.posix.SIG.BUS, act, null)
        // bun.sys.sigaction(std.posix.SIG.FPE, act, null)
    }

    /// 重置段错误处理器 (恢复默认)
    /// 对应: pub fn resetSegfaultHandler() void
    public static func resetSegfaultHandler(): Unit {
        if (!CRASH_HANDLER_ENABLE) { return }
        if (Environment.ENABLE_ASAN) { return }

        if (Environment.IS_WINDOWS) {
            // 对应: windows.kernel32.RemoveVectoredExceptionHandler(handle)
        } else {
            // 恢复默认信号处理
            // 对应: bun.sys.sigaction(sig, &act, null) 恢复 SIG_DFL
        }
    }

    // ========================================================================
    // 崩溃报告 URL
    // 严格翻译自: pub fn reportBaseUrl() []const u8
    // ========================================================================

    /// 获取崩溃报告基础 URL
    /// 对应: pub fn reportBaseUrl() []const u8
    ///   可通过 BUN_CRASH_REPORT_URL 环境变量覆盖
    private static var cachedBaseUrl: ?String = None

    public static func reportBaseUrl(): String {
        if (cachedBaseUrl.isSome()) {
            return cachedBaseUrl.getOrThrow()
        }

        // 检查环境变量覆盖
        // 对应: if (bun.env_var.BUN_CRASH_REPORT_URL.get()) |url| { ... }
        // 简化: 使用默认值
        cachedBaseUrl = DEFAULT_REPORT_BASE_URL
        cachedBaseUrl.getOrThrow()
    }

    // ========================================================================
    // 崩溃处理核心
    // 严格翻译自: pub fn crashHandler(reason, error_return_trace, begin_addr) noreturn
    // ========================================================================

    /// 崩溃处理核心函数
    /// 对应: pub fn crashHandler(
    ///   reason: CrashReason,
    ///   error_return_trace: ?*std.builtin.StackTrace,
    ///   begin_addr: ?usize,
    /// ) noreturn
    public static func crashHandler(reason: CrashReason, errorReturnTrace: ?StackTrace, beginAddr: ?Int64): Nothing {
        // 阶段 0: 首次崩溃
        // 对应: switch (panic_stage) { 0 => { ... } }
        if (!hasPrintedMessage) {
            hasPrintedMessage = true

            // 调用崩溃前处理器
            // 对应: for (before_crash_handlers.items) |item| { const ptr, const cb = item; cb(ptr) }
            for (entry in beforeCrashHandlers) {
                try {
                    entry.callback()
                } catch (_: Exception) {
                    // 忽略崩溃前处理器中的错误
                }
            }

            // 打印崩溃信息
            // 对应: writer.writeAll("=" ** 60 ++ "\n")
            printSeparator()
            printMetadata()

            // 打印崩溃原因
            // 对应: writer.print("{f}\n", .{reason})
            let threadInfo = if (true) { "(main thread)" } else { "" }
            printStderr("panic${threadInfo}: ${reason.format()}\n")

            // 打印当前动作
            // 对应: if (current_action) |action| { writer.print("Crashed while {f}\n", .{action}) }
            if (currentAction.isSome()) {
                printStderr("Crashed while ${currentAction.getOrThrow().format()}\n")
            }
        } else {
            printStderr("oh no: multiple threads are crashing\n")
        }

        // 生成追踪字符串
        var traceStrBuf = StringBuilder()
        let trace = captureStackTrace(beginAddr)
        let traceString = TraceString(trace, reason, TraceStringAction.ViewTrace)

        let debugTrace = Environment.IS_DEBUG

        if (debugTrace) {
            dumpStackTrace(trace, WriteStackTraceLimits.defaultLimits())
        } else {
            if (!hasPrintedMessage) {
                printStderr("Bao has crashed. This indicates a bug in Bao, not your code.\n")
                hasPrintedMessage = true
            }
            printStderr(" ${traceString.encode()}\n")
        }

        printStderr("\n")

        // 等待其他线程完成 panic
        // 对应: waitForOtherThreadToFinishPanicking()
        // report(traceStrBuf.toString())

        // 重置信号处理器以便真正崩溃
        // 对应: resetSegfaultHandler()
        resetSegfaultHandler()

        // 最终崩溃
        // 对应: crash()
        crash()
    }

    // ========================================================================
    // handleRootError - 根错误处理
    // 严格翻译自: pub fn handleRootError(err: anyerror, error_return_trace) noreturn
    // ========================================================================

    /// 处理根错误 (main 返回的错误)
    /// 对应: pub fn handleRootError(err: anyerror, error_return_trace: ?*std.builtin.StackTrace) noreturn
    public static func handleRootError(err: ErrorCode, errorReturnTrace: ?StackTrace): Nothing {
        var showTrace = Environment.IS_DEBUG

        match (err) {
            case OutOfMemory =>
                // 对应: error.OutOfMemory => bun.outOfMemory()
                printStderr("Bao ran out of memory\n")
            case InvalidArgument =>
                // 对应: error.InvalidArgument, ... => if (!show_trace) Global.exit(1)
                if (!showTrace) { exit(1) }
            case SyntaxError =>
                // 对应: error.SyntaxError => { Output.err("SyntaxError", ...) }
                printStderr("error: SyntaxError: An error occurred while parsing code\n")
            case ENOENT =>
                // 对应: error.ENOENT, error.FileNotFound => { ... }
                printStderr("error: ENOENT: Bao could not find a file\n")
            case Unexpected =>
                // 对应: error.NotOpenForReading, error.Unexpected => { ... }
                showTrace = true
            case _ =>
                // 对应: else => { ... }
                printStderr("An internal error occurred (${err.name()}\n")
                showTrace = true
        }

        if (showTrace) {
            verboseErrorTrace = true
            if (errorReturnTrace.isSome()) {
                dumpStackTrace(errorReturnTrace.getOrThrow(), WriteStackTraceLimits.defaultLimits())
            }
        }

        exit(1)
    }

    // ========================================================================
    // panicImpl - panic 实现
    // 严格翻译自: pub fn panicImpl(msg, error_return_trace, begin_addr) noreturn
    // ========================================================================

    /// panic 实现
    /// 对应: pub fn panicImpl(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, begin_addr: ?usize) noreturn
    public static func panicImpl(msg: String, errorReturnTrace: ?StackTrace, beginAddr: ?Int64): Nothing {
        let reason = if (msg == "reached unreachable code") {
            CrashReason.Unreachable
        } else {
            CrashReason.Panic(msg)
        }
        crashHandler(reason, errorReturnTrace, beginAddr)
    }

    // ========================================================================
    // dumpStackTrace / dumpCurrentStackTrace - 转储栈追踪
    // 严格翻译自: pub fn dumpStackTrace(trace, limits) void
    //   pub fn dumpCurrentStackTrace(first_address, limits) void
    // ========================================================================

    /// 转储栈追踪
    /// 对应: pub fn dumpStackTrace(trace: std.builtin.StackTrace, limits: WriteStackTraceLimits) void
    public static func dumpStackTrace(trace: StackTrace, limits: WriteStackTraceLimits): Unit {
        // 在 debug 构建中: 使用 debug info 解析栈帧
        // 在 release 构建中: 生成追踪字符串
        let ts = TraceString(trace, CrashReason.ZigError("DumpStackTrace"), TraceStringAction.ViewTrace)
        printStderr("View Debug Trace: ${ts.encode()}\n")
    }

    /// 转储当前栈追踪
    /// 对应: pub fn dumpCurrentStackTrace(first_address: ?usize, limits: WriteStackTraceLimits) void
    public static func dumpCurrentStackTrace(firstAddress: ?Int64, limits: WriteStackTraceLimits): Unit {
        let trace = captureStackTrace(firstAddress)
        dumpStackTrace(trace, limits)
    }

    // ========================================================================
    // printMetadata - 打印元数据
    // 严格翻译自: pub fn printMetadata(writer: anytype) !void
    // ========================================================================

    /// 打印崩溃时的程序元数据
    /// 对应: pub fn printMetadata(writer: anytype) !void
    ///   包含版本、平台、CPU 特性、内存使用等
    public static func printMetadata(): Unit {
        // 版本行
        // 对应: metadata_version_line = "Bun {s}v{s} {s} {s}{s}\n"
        let versionLine = "Bao v${Environment.VERSION_STRING} ${Environment.OS.displayString()} ${archDisplayString()}\n"
        printStderr(versionLine)

        // CPU 特性
        // 对应: const cpu_features = CPUFeatures.get();
        //   if (!cpu_features.isEmpty()) { try writer.print("CPU: {f}\n", .{cpu_features}) }
        let cpuFeatures = CPUFeatures.get()
        if (!cpuFeatures.isEmpty()) {
            printStderr("CPU: ${cpuFeatures.format()}\n")
        }

        // 参数列表
        // 对应: try writer.print("Args: ", .{}); for (bun.argv, 0..) |arg, i| { ... }
        printStderr("Args: ...\n")

        // 内存信息 (如果使用 mimalloc)
        // 对应: if (bun.use_mimalloc) { mimalloc.mi_process_info(...) ... }
        if (reportedMemorySize > 0) {
            printStderr("Machine: ${reportedMemorySize} bytes\n")
        }
    }

    // ========================================================================
    // 报告相关
    // 严格翻译自: fn isReportingEnabled() bool, fn report(url) void
    // ========================================================================

    /// 是否启用崩溃报告
    /// 对应: fn isReportingEnabled() bool
    public static func isReportingEnabled(): Bool {
        if (suppressReportingFlag) { return false }
        if (Environment.IS_DEBUG) { return false }
        if (Environment.ENABLE_ASAN) { return false }

        // 检查环境变量
        // 对应: if (bun.env_var.BUN_CRASH_REPORT_URL.get()) |value| { return value.len > 0 }
        // 对应: if (bun.env_var.BUN_ENABLE_CRASH_REPORTING.get()) |enable| { return enable }

        // macOS 和 Windows 默认启用
        if (Environment.IS_MAC || Environment.IS_WINDOWS) {
            return true
        }

        false
    }

    /// 上传崩溃报告
    /// 对应: fn report(url: []const u8) void
    ///   macOS/Linux: fork + execve("curl", ...)
    ///   Windows: CreateProcessW("powershell ...")
    public static func report(url: String): Unit {
        if (!isReportingEnabled()) { return }

        if (Environment.IS_POSIX) {
            // 对应: fork + execve curl
            // 简化: 使用系统调用
            printStderr("Report URL: ${url}/ack\n")
        } else if (Environment.IS_WINDOWS) {
            // 对应: CreateProcessW powershell
            printStderr("Report URL: ${url}/ack\n")
        }
    }

    // ========================================================================
    // 抑制报告
    // 严格翻译自: pub fn suppressReporting() void
    //   pub fn suppressCoreDumpsIfNecessary() void
    // ========================================================================

    /// 抑制崩溃报告上传
    /// 对应: pub fn suppressReporting() void
    ///   覆盖所有报告设置，用于测试中故意崩溃的场景
    public static func suppressReporting(): Unit {
        suppressCoreDumpsIfNecessary()
        suppressReportingFlag = true
    }

    /// 在 POSIX 上抑制核心转储
    /// 对应: pub fn suppressCoreDumpsIfNecessary() void
    ///   如果 RLIMIT_CORE 的软限制非零，设为零
    public static func suppressCoreDumpsIfNecessary(): Unit {
        if (Environment.IS_POSIX) {
            // 对应: std.posix.getrlimit(.CORE) catch return
            //   if (existing_limit.cur > 0) { existing_limit.cur = 0; std.posix.setrlimit(...) }
            // 仓颉中通过 FFI 调用 getrlimit/setrlimit
        }
    }

    // ========================================================================
    // 崩溃前处理器
    // 严格翻译自: pub fn appendPreCrashHandler, removePreCrashHandler
    // ========================================================================

    /// 添加崩溃前处理器
    /// 对应: pub fn appendPreCrashHandler(comptime T: type, ptr: *T, comptime handler) !void
    public static func appendPreCrashHandler(id: Int64, callback: OnBeforeCrashCallback): Unit {
        beforeCrashHandlers.add(BeforeCrashHandlerEntry(id, callback))
    }

    /// 移除崩溃前处理器
    /// 对应: pub fn removePreCrashHandler(ptr: *anyopaque) void
    public static func removePreCrashHandler(id: Int64): Unit {
        var found: Int64 = -1
        for (i in 0..beforeCrashHandlers.size) {
            if (beforeCrashHandlers[i].id == id) {
                found = i
                break
            }
        }
        let index = found
        if (index >= 0) {
            beforeCrashHandlers.remove(at: index)
        }
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 等待其他线程完成 panic
    /// 对应: fn waitForOtherThreadToFinishPanicking() void
    public static func waitForOtherThreadToFinishPanicking(): Unit {
        // 对应: if (panicking.fetchSub(1, .seq_cst) != 1) { ... sleep forever ... }
        // 简化: 无操作
    }

    /// 如果其他线程正在崩溃，则永久休眠
    /// 对应: pub fn sleepForeverIfAnotherThreadIsCrashing() void
    public static func sleepForeverIfAnotherThreadIsCrashing(): Unit {
        if (panickingCount > 0) {
            // 对应: while (true) bun.Futex.waitForever(&futex, 0)
            // 永久阻塞当前线程
        }
    }

    /// 是否正在 panic
    /// 对应: pub fn isPanicking() bool
    public static func isPanicking(): Bool {
        panickingCount > 0
    }

    /// 处理错误返回追踪
    /// 对应: pub inline fn handleErrorReturnTrace(err: anyerror, maybe_trace) void
    public static func handleErrorReturnTrace(err: String, maybeTrace: ?StackTrace): Unit {
        handleErrorReturnTraceExtra(err, maybeTrace, false)
    }

    /// 处理错误返回追踪 (带 is_root 参数)
    /// 对应: inline fn handleErrorReturnTraceExtra(err, maybe_trace, comptime is_root) void
    public static func handleErrorReturnTraceExtra(err: String, maybeTrace: ?StackTrace, isRoot: Bool): Unit {
        if (!verboseErrorTrace && !isRoot) { return }

        if (maybeTrace.isSome()) {
            coldHandleErrorReturnTrace(err, maybeTrace.getOrThrow(), isRoot)
        }
    }

    /// 冷路径错误追踪处理
    /// 对应: noinline fn coldHandleErrorReturnTrace(...) void
    private static func coldHandleErrorReturnTrace(err: String, trace: StackTrace, isRoot: Bool): Unit {
        if (Environment.IS_DEBUG) {
            if (isRoot) {
                if (verboseErrorTrace) {
                    printStderr("Note: Release build will not have this trace by default:\n")
                }
            } else {
                printStderr("Note: caught error.${err}:\n")
            }
            dumpStackTrace(trace, WriteStackTraceLimits.defaultLimits())
        } else {
            let ts = TraceString(trace, CrashReason.ZigError(err), TraceStringAction.ViewTrace)
            if (isRoot) {
                printStderr("\nTo send a redacted crash report, please file a GitHub issue:\n ${ts.encode()}\n\n")
            } else {
                printStderr("trace: error.${err}: ${ts.encode()}\n")
            }
        }
    }

    /// 设置原生插件名
    /// 对应: export fn CrashHandler__setInsideNativePlugin(name: ?[*:0]const u8) void
    public static func setInsideNativePlugin(name: ?String): Unit {
        insideNativePlugin = name
    }

    /// 设置不支持的 UV 函数
    /// 对应: export fn CrashHandler__unsupportedUVFunction(name: ?[*:0]const u8) void
    public static func setUnsupportedUvFunction(name: ?String): Unit {
        unsupportedUvFunction = name
    }

    /// 设置 dlopen 动作
    /// 对应: export fn CrashHandler__setDlOpenAction(action: ?[*:0]const u8) void
    public static func setDlOpenAction(action: ?String): Unit {
        if (action.isSome()) {
            currentAction = Action.Dlopen(action.getOrThrow())
        } else {
            currentAction = None
        }
    }

    /// 最终崩溃
    /// 对应: fn crash() noreturn
    ///   在 POSIX 上通过 @trap() 触发段错误获取 core dump
    ///   在 Windows 上调用 abort()
    private static func crash(): Nothing {
        if (Environment.IS_POSIX) {
            // 恢复默认信号处理器
            // 对应: inline for (.{ SIGSEGV, SIGILL, SIGBUS, SIGABRT, SIGFPE, SIGHUP, SIGTERM }) |sig| { ... }
            resetSegfaultHandler()
        }
        // 终止进程
        exit(134) // 128 + SIGABRT
    }

    // ========================================================================
    // 私有辅助
    // ========================================================================

    /// 捕获栈追踪
    private static func captureStackTrace(beginAddr: ?Int64): StackTrace {
        let trace = StackTrace(20)
        // 仓颉中通过 FFI 调用 std.debug.captureStackTrace
        // 简化: 返回空追踪
        trace
    }

    /// 获取架构显示字符串
    private static func archDisplayString(): String {
        if (Environment.IS_AARCH64) {
            if (Environment.IS_MAC) { "Silicon" } else { "arm64" }
        } else {
            "x64"
        }
    }

    /// 打印分隔线
    private static func printSeparator(): Unit {
        printStderr("============================================================\n")
    }

    /// 打印到 stderr
    private static func printStderr(message: String): Unit {
        println(message)
    }
}
