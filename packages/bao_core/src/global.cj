// 严格翻译自: src/bun_core/Global.zig
//   const Global = @This();
//   pub const package_json_version = ...
//   pub const package_json_version_with_canary = ...
//   pub const package_json_version_with_sha = ...
//   pub fn setThreadName(name: [:0]const u8) void { ... }
//   pub fn exit(code: u32) noreturn { ... }
//   pub fn raiseIgnoringPanicHandler(sig: bun.SignalCode) noreturn { ... }
//   pub fn notimpl() noreturn { ... }
//   pub fn crash() noreturn { ... }
//   pub const BunInfo = struct { ... }
//   pub const user_agent = ...
//   pub export fn Bun__onExit() void { ... }
package bao_core

// ============================================================================
// C FFI 声明
// ============================================================================

@C
foreign func exit(code: Int32): Unit
@C
foreign func abort(): Unit
@C
foreign func raise(sig: Int32): Int32

// Linux prctl
@C
foreign func prctl(op: Int32, arg2: UIntNative): Int32
// macOS/BSD pthread_setname_np
@C
foreign func pthread_setname_np(name: CPointer<UInt8>): Int32
// FreeBSD pthread_set_name_np
@C
foreign func pthread_set_name_np(thread: UIntNative, name: CPointer<UInt8>): Unit
@C
foreign func pthread_self(): UIntNative

@C
foreign func getpid(): Int32

// ============================================================================
// ExitCallback - 退出回调函数类型
// 对应 Bun: const ExitFn = *const fn () callconv(.c) void;
// ============================================================================

/// 退出回调 - 对应 Bun ExitFn
public interface ExitCallback {
    func call(): Unit
}

// ============================================================================
// Global - 全局常量和函数
// 严格翻译自: src/bun_core/Global.zig:1-244
// ============================================================================

/// 全局常量和函数 - 对应 Bun Global
/// pub const package_json_version = if (Environment.isDebug) version_string ++ "-debug" else version_string;
/// pub const user_agent = "Bun/" ++ Global.package_json_version;
/// pub fn exit(code: u32) noreturn { ... }
/// pub fn setThreadName(name: [:0]const u8) void { ... }
public class Global {
    // ========================================================================
    // 版本字符串 - 对应 Bun Global 中的版本常量
    // ========================================================================

    /// 包 JSON 版本 - 对应 Bun package_json_version
    /// pub const package_json_version = if (Environment.isDebug) version_string ++ "-debug" else version_string;
    public static let PACKAGE_JSON_VERSION: String = Environment.VERSION_STRING +
        (if (Environment.IS_DEBUG) { "-debug" } else { "" })

    /// 包 JSON 版本 (含 canary) - 对应 Bun package_json_version_with_canary
    /// pub const package_json_version_with_canary = if (Environment.isDebug) version_string ++ "-debug"
    ///     else if (Environment.is_canary) ... else version_string;
    public static let PACKAGE_JSON_VERSION_WITH_CANARY: String = PACKAGE_JSON_VERSION

    /// 包 JSON 版本 (含 SHA) - 对应 Bun package_json_version_with_sha
    /// pub const package_json_version_with_sha = ... std.fmt.comptimePrint("{s} ({s})", ...)
    public static let PACKAGE_JSON_VERSION_WITH_SHA: String = {
        let sha = Environment.GIT_SHA
        if (sha.length > 8) {
            "${PACKAGE_JSON_VERSION} (${sha.substring(0, 8)})"
        } else if (sha.length > 0) {
            "${PACKAGE_JSON_VERSION} (${sha})"
        } else {
            PACKAGE_JSON_VERSION
        }
    }

    /// 包 JSON 版本 (含修订) - 对应 Bun package_json_version_with_revision
    /// pub const package_json_version_with_revision = ... version_string ++ "+{s}"
    public static let PACKAGE_JSON_VERSION_WITH_REVISION: String = {
        let sha = Environment.GIT_SHA_SHORT
        if (sha.length > 0) {
            "${PACKAGE_JSON_VERSION}+${sha}"
        } else {
            PACKAGE_JSON_VERSION
        }
    }

    /// OS 名称 - 对应 Bun os_name
    /// pub const os_name = if (Environment.isAndroid) "android" else Environment.os.nameString();
    public static let OS_NAME: String = Environment.OS.nameString()

    /// OS 显示名称 - 对应 Bun os_display
    /// pub const os_display = if (Environment.isAndroid) "Android" else Environment.os.displayString();
    public static let OS_DISPLAY: String = Environment.OS.displayString()

    /// 架构名称 - 对应 Bun arch_name
    /// pub const arch_name = if (Environment.isX64) "x64" else if (Environment.isX86) "x86"
    ///     else if (Environment.isAarch64) "arm64" else "unknown";
    public static let ARCH_NAME: String = Environment.ARCH.npmName()

    /// 未处理错误的版本字符串 - 对应 Bun unhandled_error_bun_version_string
    /// "Bun v1.0.0 (Linux x64 baseline)"
    public static let UNHANDLED_ERROR_VERSION_STRING: String = "Bao v${PACKAGE_JSON_VERSION} (${OS_DISPLAY} ${ARCH_NAME})"

    /// 用户代理 - 对应 Bun user_agent
    /// pub const user_agent = "Bun/" ++ Global.package_json_version;
    public static let USER_AGENT: String = "Bao/${PACKAGE_JSON_VERSION}"

    // ========================================================================
    // 退出回调管理 - 对应 Bun on_exit_callbacks / Bun__atexit / runExitCallbacks
    // ========================================================================

    /// 退出回调列表 - 对应 Bun var on_exit_callbacks = std.ArrayListUnmanaged(ExitFn){};
    private static var exitCallbacks: ArrayList<ExitCallback> = ArrayList<ExitCallback>()
    /// 是否正在退出 - 对应 Bun var is_exiting = std.atomic.Value(bool).init(false);
    private static var isExitingFlag: Bool = false

    /// 获取启动时间 - 对应 Bun getStartTime()
    /// pub inline fn getStartTime() i128 { return bun.start_time; }
    public static func getStartTime(): Int64 {
        return startTime
    }

    /// 设置启动时间
    public static func setStartTime(time: Int64): Unit {
        startTime = time
    }

    /// 注册退出回调 - 对应 Bun Bun__atexit / addExitCallback
    /// export fn Bun__atexit(function: ExitFn) void {
    ///     if (std.mem.indexOfScalar(ExitFn, on_exit_callbacks.items, function) == null) {
    ///         on_exit_callbacks.append(bun.default_allocator, function) catch {};
    ///     }
    /// }
    public static func addExitCallback(callback: ExitCallback): Unit {
        exitCallbacks.append(callback)
    }

    /// 运行退出回调 - 对应 Bun runExitCallbacks()
    /// pub fn runExitCallbacks() void {
    ///     for (on_exit_callbacks.items) |callback| { callback(); }
    ///     on_exit_callbacks.items.len = 0;
    /// }
    public static func runExitCallbacks(): Unit {
        for (callback in exitCallbacks) {
            callback.call()
        }
        exitCallbacks.clear()
    }

    /// 是否正在退出 - 对应 Bun isExiting()
    /// pub fn isExiting() bool { return is_exiting.load(.monotonic); }
    public static func isExiting(): Bool {
        return isExitingFlag
    }

    // ========================================================================
    // 线程管理 - 对应 Bun setThreadName
    // ========================================================================

    /// 设置线程名称 - 对应 Bun setThreadName()
    /// pub fn setThreadName(name: [:0]const u8) void {
    ///     if (Environment.isLinux) { _ = std.posix.prctl(.SET_NAME, .{@intFromPtr(name.ptr)}) catch 0; }
    ///     else if (Environment.isMac) { _ = std.c.pthread_setname_np(name); }
    ///     else if (Environment.isFreeBSD) { std.c.pthread_set_name_np(std.c.pthread_self(), name); }
    ///     else if (Environment.isWindows) { ... }
    /// }
    public static func setThreadName(name: String): Unit {
        unsafe {
            let cName = name.toCString()
            if (Environment.IS_LINUX) {
                // PR_SET_NAME = 15
                prctl(15, cName.toCPointer())
            } else if (Environment.IS_MAC) {
                pthread_setname_np(cName.toCPointer())
            } else if (Environment.IS_FREEBSD) {
                pthread_set_name_np(pthread_self(), cName.toCPointer())
            }
        }
    }

    // ========================================================================
    // 进程退出 - 对应 Bun exit / crash / notimpl
    // ========================================================================

    /// 退出进程 - 对应 Bun exit()
    /// pub fn exit(code: u32) noreturn {
    ///     is_exiting.store(true, .monotonic);
    ///     _ = @atomicRmw(usize, &bun.analytics.Features.exited, .Add, 1, .monotonic);
    ///     bun.crash_handler.sleepForeverIfAnotherThreadIsCrashing();
    ///     Output.flush();
    ///     switch (Environment.os) { .mac => std.c.exit(@bitCast(code)), ... }
    /// }
    public static func exit(code: Int32): Unit {
        isExitingFlag = true
        runExitCallbacks()
        exit(code)
    }

    /// 抛出信号 - 对应 Bun raiseIgnoringPanicHandler()
    /// pub fn raiseIgnoringPanicHandler(sig: bun.SignalCode) noreturn {
    ///     Output.flush();
    ///     Output.Source.Stdio.restore();
    ///     bun.crash_handler.resetSegfaultHandler();
    ///     ... clear signal handler ...
    ///     _ = std.c.raise(@intFromEnum(sig));
    ///     std.c.abort();
    /// }
    public static func raiseIgnoringPanicHandler(sig: Int32): Unit {
        unsafe {
            raise(sig)
            abort()
        }
    }

    /// 未实现 - 对应 Bun notimpl()
    /// pub fn notimpl() noreturn {
    ///     @branchHint(.cold);
    ///     Output.panic("Not implemented yet!!!!!", .{});
    /// }
    public static func notimpl(): Unit {
        throw BaoError(ErrorCode.NotImplemented, "Not implemented yet!")
    }

    /// 崩溃退出 - 对应 Bun crash()
    /// pub fn crash() noreturn { @branchHint(.cold); Global.exit(1); }
    public static func crash(): Unit {
        exit(1)
    }

    // ========================================================================
    // 分配器配置 - 对应 Bun AllocatorConfiguration / configureAllocator / mimalloc_cleanup
    // ========================================================================

    /// 分配器配置 - 对应 Bun AllocatorConfiguration
    /// pub const AllocatorConfiguration = struct { verbose: bool = false, long_running: bool = false };
    public class AllocatorConfiguration {
        public var verbose: Bool
        public var longRunning: Bool

        public init() {
            verbose = false
            longRunning = false
        }

        public init(verbose: Bool, longRunning: Bool) {
            this.verbose = verbose
            this.longRunning = longRunning
        }
    }

    /// mimalloc 清理 - 对应 Bun mimalloc_cleanup()
    /// pub inline fn mimalloc_cleanup(force: bool) void { if (comptime use_mimalloc) { Mimalloc.mi_collect(force); } }
    public static func mimallocCleanup(force: Bool): Unit {
        // 仓颉使用自己的 GC, 此处为空操作
    }

    /// 配置分配器 - 对应 Bun configureAllocator()
    /// pub inline fn configureAllocator(_: AllocatorConfiguration) void {}
    public static func configureAllocator(config: AllocatorConfiguration): Unit {
        // 仓颉使用自己的内存管理, 此处为空操作
    }

    // ========================================================================
    // BunInfo - 对应 Bun Global.BunInfo
    //   pub const BunInfo = struct {
    //       bun_version: string,
    //       platform: analytics.GenerateHeader.GeneratePlatform.Platform,
    //       pub fn generate(...) !JSAst.Expr { ... }
    //   };
    // ========================================================================

    /// Bao 信息 - 对应 Bun BunInfo
    public class BaoInfo {
        /// Bao 版本
        public let baoVersion: String
        /// 平台
        public let platform: String

        public init() {
            this.baoVersion = PACKAGE_JSON_VERSION
            this.platform = OS_DISPLAY
        }

        public init(version: String, platform: String) {
            this.baoVersion = version
            this.platform = platform
        }

        /// 生成 JSON 表示 - 对应 Bun BunInfo.generate()
        /// pub fn generate(comptime Bundler: type, _: Bundler, allocator: std.mem.Allocator) !JSAst.Expr
        public func toJson(): String {
            return "{\"bao_version\":\"${baoVersion}\",\"platform\":\"${platform}\"}"
        }
    }

    // ========================================================================
    // OnExit - 对应 Bun Bun__onExit / Bun__atexit
    // ========================================================================

    /// 退出处理 - 对应 Bun Bun__onExit()
    /// pub export fn Bun__onExit() void {
    ///     bun.jsc.Node.FSEvents.closeAndWait();
    ///     runExitCallbacks();
    ///     Output.flush();
    ///     std.mem.doNotOptimizeAway(&Bun__atexit);
    ///     Output.Source.Stdio.restore();
    /// }
    public static func onExit(): Unit {
        runExitCallbacks()
        // Output flush handled elsewhere
    }

    // ========================================================================
    // 内部状态
    // ========================================================================

    /// 进程启动时间
    private static var startTime: Int64 = 0
}
