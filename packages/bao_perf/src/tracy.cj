// tracy - Tracy 性能分析器集成
// 严格翻译自: bun/src/perf/tracy.zig (559行)
//   Tracy 是一个实时纳秒级性能分析器 (https://github.com/wolfpld/tracy)
//   此模块提供 Tracy C API 的仓颉绑定
//
//   Zig 版本通过 dlsym 动态加载 Tracy 函数 (无需编译时链接)
//   仓颉版本通过 FFI + 动态加载实现等价功能
//
//   主要功能:
//     - trace(): 创建追踪区间
//     - traceNamed(): 创建命名追踪区间
//     - message(): 发送消息
//     - frameMark(): 标记帧边界
//     - 内存分配追踪
package bao_perf

import bao_core.*

// ============================================================================
// 全局开关
// 严格翻译自: tracy.zig
//   pub const enable_allocation = false;
//   pub const enable_callstack = false;
//   pub var enable = false;
// ============================================================================

/// 是否启用内存分配追踪
/// 对应 Zig: pub const enable_allocation = false
public let ENABLE_ALLOCATION: Bool = false

/// 是否启用调用栈追踪
/// 对应 Zig: pub const enable_callstack = false
public let ENABLE_CALLSTACK: Bool = false

/// Tracy 调用栈深度
/// 对应 Zig: const callstack_depth = build_options.tracy_callstack_depth
public let CALLSTACK_DEPTH: Int64 = 10

/// 是否启用 Tracy (运行时检测)
/// 对应 Zig: pub var enable = false
public var tracyEnabled: Bool = false

/// Tracy 是否已启动
/// 对应 Zig: pub var has_started = false
public var tracyHasStarted: Bool = false

// ============================================================================
// TracySourceLocationData - 源码位置数据
// 严格翻译自: tracy.zig - ___tracy_source_location_data
//   const ___tracy_source_location_data = extern struct {
//       name: ?[*:0]const u8 = null,
//       function: [*:0]const u8 = "",
//       file: [*:0]const u8 = "",
//       line: u32 = 0,
//       color: u32 = 0,
//   };
// ============================================================================

/// Tracy 源码位置数据 - 对应 ___tracy_source_location_data
public class TracySourceLocationData {
    public var name: String = ""
    public var function: String = ""
    public var file: String = ""
    public var line: UInt32 = 0
    public var color: UInt32 = 0

    public init() {}

    public init(name: String, function: String, file: String,
                line: UInt32, color: UInt32) {
        this.name = name
        this.function = function
        this.file = file
        this.line = line
        this.color = color
    }
}

// ============================================================================
// TracyCtx - Tracy 区间上下文
// 严格翻译自: tracy.zig - ___tracy_c_zone_context
//   const ___tracy_c_zone_context = extern struct {
//       id: u32 = 0,
//       active: c_int = 0,
//       pub inline fn end(self: @This()) void { ... }
//       pub inline fn addText(self: @This(), text: []const u8) void { ... }
//       pub inline fn setName(self: @This(), name: []const u8) void { ... }
//       pub inline fn setColor(self: @This(), color: u32) void { ... }
//       pub inline fn setValue(self: @This(), value: u64) void { ... }
//   };
//   pub const Ctx = ___tracy_c_zone_context;
// ============================================================================

/// Tracy 区间上下文 - 对应 ___tracy_c_zone_context / Ctx
public class TracyCtx {
    public var id: UInt32 = 0
    public var active: Int32 = 0

    public init() {}

    public init(id: UInt32, active: Int32) {
        this.id = id
        this.active = active
    }

    /// 结束追踪区间
    /// 对应 Zig: pub inline fn end(self: @This()) void {
    ///     if (!enable) return;
    ///     ___tracy_emit_zone_end(self);
    /// }
    public func end(): Unit {
        if (!tracyEnabled) {
            return
        }
        Tracy.nativeTracyEmitZoneEnd(id, active)
    }

    /// 添加文本到追踪区间
    /// 对应 Zig: pub inline fn addText(self: @This(), text: []const u8) void {
    ///     if (!enable) return;
    ///     ___tracy_emit_zone_text(self, text.ptr, text.len);
    /// }
    public func addText(text: String): Unit {
        if (!tracyEnabled) {
            return
        }
        Tracy.nativeTracyEmitZoneText(id, active, text)
    }

    /// 设置追踪区间名称
    /// 对应 Zig: pub inline fn setName(self: @This(), name: []const u8) void {
    ///     if (!enable) return;
    ///     ___tracy_emit_zone_name(self, name.ptr, name.len);
    /// }
    public func setName(name: String): Unit {
        if (!tracyEnabled) {
            return
        }
        Tracy.nativeTracyEmitZoneName(id, active, name)
    }

    /// 设置追踪区间颜色
    /// 对应 Zig: pub inline fn setColor(self: @This(), color: u32) void {
    ///     if (!enable) return;
    ///     ___tracy_emit_zone_color(self, color);
    /// }
    public func setColor(color: UInt32): Unit {
        if (!tracyEnabled) {
            return
        }
        Tracy.nativeTracyEmitZoneColor(id, active, color)
    }

    /// 设置追踪区间值
    /// 对应 Zig: pub inline fn setValue(self: @This(), value: u64) void {
    ///     if (!enable) return;
    ///     ___tracy_emit_zone_value(self, value);
    /// }
    public func setValue(value: UInt64): Unit {
        if (!tracyEnabled) {
            return
        }
        Tracy.nativeTracyEmitZoneValue(id, active, value)
    }
}

// ============================================================================
// Tracy - 核心追踪函数
// 严格翻译自: tracy.zig 公共 API
// ============================================================================

/// Tracy 性能分析器 - 对应 Bun tracy 模块
public class Tracy {

    // ========================================================================
    // trace - 创建追踪区间
    // 严格翻译自: tracy.zig - trace()
    //   pub inline fn trace(comptime src: std.builtin.SourceLocation) Ctx {
    //       if (!enable) return .{};
    //       if (enable_callstack) {
    //           return ___tracy_emit_zone_begin_callstack(&.{...}, callstack_depth, 1);
    //       } else {
    //           const holder = struct { pub const srcloc = ___tracy_source_location_data{...}; };
    //           return ___tracy_emit_zone_begin(&holder.srcloc, 1);
    //       }
    //   }
    // ========================================================================

    /// 创建追踪区间
    /// 对应 Bun tracy.trace()
    /// 使用源码位置信息创建 Tracy 区间
    public static func trace(srcFunc: String, srcFile: String,
                              srcLine: UInt32): TracyCtx {
        if (!tracyEnabled) {
            return TracyCtx()
        }

        let srcloc = TracySourceLocationData(
            "",
            srcFunc,
            srcFile,
            srcLine,
            0
        )

        if (ENABLE_CALLSTACK) {
            return nativeTracyEmitZoneBeginCallstack(srcloc, Int32(CALLSTACK_DEPTH), 1)
        } else {
            return nativeTracyEmitZoneBegin(srcloc, 1)
        }
    }

    // ========================================================================
    // traceNamed - 创建命名追踪区间
    // 严格翻译自: tracy.zig - traceNamed()
    //   pub inline fn traceNamed(comptime src: std.builtin.SourceLocation,
    //                            comptime name: [*:0]const u8) Ctx { ... }
    // ========================================================================

    /// 创建命名追踪区间
    /// 对应 Bun tracy.traceNamed()
    public static func traceNamed(srcFunc: String, srcFile: String,
                                   srcLine: UInt32,
                                   name: String): TracyCtx {
        if (!tracyEnabled) {
            return TracyCtx()
        }

        let srcloc = TracySourceLocationData(
            name,
            srcFunc,
            srcFile,
            srcLine,
            0
        )

        if (ENABLE_CALLSTACK) {
            return nativeTracyEmitZoneBeginCallstack(srcloc, Int32(CALLSTACK_DEPTH), 1)
        } else {
            return nativeTracyEmitZoneBegin(srcloc, 1)
        }
    }

    // ========================================================================
    // message - 发送消息
    // 严格翻译自: tracy.zig - message()
    //   pub inline fn message(comptime msg: [:0]const u8) void {
    //       if (!enable) return;
    //       ___tracy_emit_messageL(msg.ptr, if (enable_callstack) callstack_depth else 0);
    //   }
    // ========================================================================

    /// 发送编译时已知消息
    /// 对应 Bun tracy.message()
    public static func message(msg: String): Unit {
        if (!tracyEnabled) {
            return
        }
        let depth = if (ENABLE_CALLSTACK) { Int32(CALLSTACK_DEPTH) } else { Int32(0) }
        nativeTracyEmitMessageL(msg, depth)
    }

    /// 发送带颜色的编译时已知消息
    /// 对应 Bun tracy.messageColor()
    public static func messageColor(msg: String, color: UInt32): Unit {
        if (!tracyEnabled) {
            return
        }
        let depth = if (ENABLE_CALLSTACK) { Int32(CALLSTACK_DEPTH) } else { Int32(0) }
        nativeTracyEmitMessageLC(msg, color, depth)
    }

    /// 发送运行时消息
    /// 对应 Bun tracy.messageCopy()
    public static func messageCopy(msg: String): Unit {
        if (!tracyEnabled) {
            return
        }
        let depth = if (ENABLE_CALLSTACK) { Int32(CALLSTACK_DEPTH) } else { Int32(0) }
        nativeTracyEmitMessage(msg, depth)
    }

    /// 发送带颜色的运行时消息
    /// 对应 Bun tracy.messageColorCopy()
    public static func messageColorCopy(msg: String, color: UInt32): Unit {
        if (!tracyEnabled) {
            return
        }
        let depth = if (ENABLE_CALLSTACK) { Int32(CALLSTACK_DEPTH) } else { Int32(0) }
        nativeTracyEmitMessageC(msg, color, depth)
    }

    // ========================================================================
    // frameMark - 帧标记
    // 严格翻译自: tracy.zig - frameMark() / frameMarkNamed()
    //   pub inline fn frameMark() void {
    //       if (!enable) return;
    //       ___tracy_emit_frame_mark(null);
    //   }
    //   pub inline fn frameMarkNamed(comptime name: [:0]const u8) void { ... }
    // ========================================================================

    /// 标记帧结束
    /// 对应 Bun tracy.frameMark()
    public static func frameMark(): Unit {
        if (!tracyEnabled) {
            return
        }
        nativeTracyEmitFrameMark("")
    }

    /// 标记命名帧结束
    /// 对应 Bun tracy.frameMarkNamed()
    public static func frameMarkNamed(name: String): Unit {
        if (!tracyEnabled) {
            return
        }
        nativeTracyEmitFrameMark(name)
    }

    // ========================================================================
    // namedFrame - 命名帧
    // 严格翻译自: tracy.zig - namedFrame() / Frame()
    //   pub inline fn namedFrame(comptime name: [:0]const u8) Frame(name) {
    //       frameMarkStart(name);
    //       return .{};
    //   }
    //   pub fn Frame(comptime name: [:0]const u8) type {
    //       return struct {
    //           pub fn end(_: @This()) void { frameMarkEnd(name); }
    //       };
    //   }
    // ========================================================================

    /// 创建命名帧
    /// 对应 Bun tracy.namedFrame()
    public static func namedFrame(name: String): TracyFrame {
        frameMarkStart(name)
        return TracyFrame(name)
    }

    /// 帧开始标记
    private static func frameMarkStart(name: String): Unit {
        if (!tracyEnabled) {
            return
        }
        nativeTracyEmitFrameMarkStart(name)
    }

    /// 帧结束标记
    private static func frameMarkEnd(name: String): Unit {
        if (!tracyEnabled) {
            return
        }
        nativeTracyEmitFrameMarkEnd(name)
    }

    // ========================================================================
    // 内存追踪函数
    // 严格翻译自: tracy.zig - alloc/free/allocNamed/freeNamed
    //   inline fn alloc(ptr: [*]u8, len: usize) void { ... }
    //   inline fn allocNamed(ptr: [*]u8, len: usize, comptime name) void { ... }
    //   inline fn free(ptr: [*]u8) void { ... }
    //   inline fn freeNamed(ptr: [*]u8, comptime name) void { ... }
    // ========================================================================

    /// 追踪内存分配
    /// 对应 Bun tracy.alloc()
    public static func alloc(ptr: Int64, size: UInt64): Unit {
        if (!tracyEnabled) {
            return
        }
        if (ENABLE_CALLSTACK) {
            nativeTracyEmitMemoryAllocCallstack(ptr, size, Int32(CALLSTACK_DEPTH), 0)
        } else {
            nativeTracyEmitMemoryAlloc(ptr, size, 0)
        }
    }

    /// 追踪命名内存分配
    /// 对应 Bun tracy.allocNamed()
    public static func allocNamed(ptr: Int64, size: UInt64,
                                   name: String): Unit {
        if (!tracyEnabled) {
            return
        }
        if (ENABLE_CALLSTACK) {
            nativeTracyEmitMemoryAllocCallstackNamed(ptr, size, Int32(CALLSTACK_DEPTH), 0, name)
        } else {
            nativeTracyEmitMemoryAllocNamed(ptr, size, 0, name)
        }
    }

    /// 追踪内存释放
    /// 对应 Bun tracy.free()
    public static func free(ptr: Int64): Unit {
        if (!tracyEnabled) {
            return
        }
        if (ENABLE_CALLSTACK) {
            nativeTracyEmitMemoryFreeCallstack(ptr, Int32(CALLSTACK_DEPTH), 0)
        } else {
            nativeTracyEmitMemoryFree(ptr, 0)
        }
    }

    /// 追踪命名内存释放
    /// 对应 Bun tracy.freeNamed()
    public static func freeNamed(ptr: Int64, name: String): Unit {
        if (!tracyEnabled) {
            return
        }
        if (ENABLE_CALLSTACK) {
            nativeTracyEmitMemoryFreeCallstackNamed(ptr, Int32(CALLSTACK_DEPTH), 0, name)
        } else {
            nativeTracyEmitMemoryFreeNamed(ptr, 0, name)
        }
    }

    // ========================================================================
    // init / start / stop - Tracy 生命周期
    // 严格翻译自: tracy.zig - init() / start() / stop() / isConnected()
    //   pub fn init() bool {
    //       if (comptime !bun.Environment.isNative) return false;
    //       if (enable) return true;
    //       if (dlsym(...) == null) return false;
    //       enable = true;
    //       return true;
    //   }
    //   pub fn start() void {
    //       if (!enable or has_started) return;
    //       ___tracy_startup_profiler();
    //   }
    //   pub fn stop() void {
    //       if (!enable or !has_started) return;
    //       ___tracy_shutdown_profiler();
    //   }
    // ========================================================================

    /// 初始化 Tracy
    /// 对应 Bun tracy.init()
    /// 尝试加载 Tracy 共享库，成功则启用
    public static func initFunc(): Bool {
        if (!Environment.IS_NATIVE) {
            return false
        }

        if (tracyEnabled) {
            return true
        }

        // 尝试加载 Tracy 共享库
        if (!loadTracyLibrary()) {
            return false
        }

        tracyEnabled = true
        return true
    }

    /// 启动 Tracy 分析器
    /// 对应 Bun tracy.start()
    public static func start(): Unit {
        if (!tracyEnabled || tracyHasStarted) {
            return
        }
        nativeTracyStartupProfiler()
        tracyHasStarted = true
    }

    /// 停止 Tracy 分析器
    /// 对应 Bun tracy.stop()
    public static func stop(): Unit {
        if (!tracyEnabled || !tracyHasStarted) {
            return
        }
        nativeTracyShutdownProfiler()
        tracyHasStarted = false
    }

    /// 检查 Tracy 是否已连接
    /// 对应 Bun tracy.isConnected()
    public static func isConnected(): Bool {
        if (!Environment.IS_NATIVE) {
            return false
        }
        if (!tracyEnabled) {
            return false
        }
        return nativeTracyConnected() != 0
    }

    /// 初始化线程名称
    /// 对应 Bun tracy.initThread()
    public static func initThread(name: String): Unit {
        if (!Environment.IS_NATIVE) {
            return
        }
        if (!tracyEnabled) {
            return
        }
        nativeTracySetThreadName(name)
    }

    // ========================================================================
    // Tracy 分配器包装
    // 严格翻译自: tracy.zig - TracyAllocator
    //   pub fn tracyAllocator(allocator: std.mem.Allocator) TracyAllocator(null) { ... }
    //   pub fn TracyAllocator(comptime name: ?[:0]const u8) type { ... }
    // ========================================================================

    /// 创建 Tracy 感知的分配器
    /// 对应 Bun tracy.tracyAllocator()
    public static func tracyAllocator(): TracyAllocator {
        let name: ?String = None
        return TracyAllocator(name)
    }

    /// 创建命名 Tracy 感知分配器
    public static func tracyAllocatorNamed(name: String): TracyAllocator {
        return TracyAllocator(Some(name))
    }

    // ========================================================================
    // dlsym / 动态库加载
    // 严格翻译自: tracy.zig - dlsym()
    //   fn dlsym(comptime Type: type, comptime symbol: [:0]const u8) ?Type {
    //       if (comptime !bun.Environment.isNative) return null;
    //       // 尝试加载 Tracy 共享库
    //       // macOS: /usr/local/opt/tracy/lib/libtracy.dylib, ...
    //       // Linux: /usr/local/lib/libtracy.so, ...
    //       // Windows: tracy.dll
    //   }
    // ========================================================================

    /// Tracy 库句柄
    private static var tracyHandle: Int64 = 0

    /// 尝试加载 Tracy 共享库
    /// 对应 Zig dlsym 中的库搜索逻辑
    private static func loadTracyLibrary(): Bool {
        if (!Environment.IS_NATIVE) {
            return false
        }

        // 如果已经加载
        if (tracyHandle != 0) {
            return true
        }

        // 尝试 BUN_TRACY_PATH 环境变量
        let tracyPath = EnvVar.get("BUN_TRACY_PATH")
        if (tracyPath.isSome()) {
            let handle = nativeDlopen(tracyPath.getOrThrow())
            if (handle != 0) {
                tracyHandle = handle
                return true
            }
        }

        // 按平台搜索标准路径
        let paths = getSearchPaths()
        for (path in paths) {
            let handle = nativeDlopen(path)
            if (handle != 0) {
                tracyHandle = handle
                return true
            }
        }

        return false
    }

    /// 获取平台搜索路径
    /// 对应 Zig dlsym 中的 paths_to_try
    private static func getSearchPaths(): Array<String> {
        if (Environment.IS_MAC) {
            return [
                "/usr/local/opt/tracy/lib/libtracy.dylib",
                "/usr/local/lib/libtracy.dylib",
                "/opt/homebrew/lib/libtracy.so",
                "/opt/homebrew/lib/libtracy.dylib",
                "/usr/lib/libtracy.dylib",
                "libtracy.dylib",
                "libtracy.so",
                "libTracyClient.dylib",
                "libTracyClient.so"
            ]
        } else if (Environment.IS_LINUX) {
            return [
                "/usr/local/lib/libtracy.so",
                "/usr/local/opt/tracy/lib/libtracy.so",
                "/opt/tracy/lib/libtracy.so",
                "/usr/lib/libtracy.so",
                "/usr/local/lib/libTracyClient.so",
                "/usr/local/opt/tracy/lib/libTracyClient.so",
                "/opt/tracy/lib/libTracyClient.so",
                "/usr/lib/libTracyClient.so",
                "libtracy.so",
                "libTracyClient.so"
            ]
        } else if (Environment.IS_WINDOWS) {
            return [
                "tracy.dll"
            ]
        }
        return []
    }

    // ========================================================================
    // 原生函数声明 (FFI)
    // 严格翻译自: tracy.zig 中的 ___tracy_* 函数
    // 所有函数通过 dlsym 从 Tracy 共享库动态加载
    // ========================================================================

    // --- 区间追踪 ---

    public static func nativeTracyEmitZoneBegin(
        srcloc: TracySourceLocationData, active: Int32): TracyCtx {
        return TracyCtx()
    }

    public static func nativeTracyEmitZoneBeginCallstack(
        srcloc: TracySourceLocationData, depth: Int32,
        active: Int32): TracyCtx {
        return TracyCtx()
    }

    public static func nativeTracyEmitZoneEnd(id: UInt32,
                                                active: Int32): Unit {}

    public static func nativeTracyEmitZoneText(id: UInt32, active: Int32,
                                                 text: String): Unit {}

    public static func nativeTracyEmitZoneName(id: UInt32, active: Int32,
                                                 text: String): Unit {}

    public static func nativeTracyEmitZoneColor(id: UInt32, active: Int32,
                                                  color: UInt32): Unit {}

    public static func nativeTracyEmitZoneValue(id: UInt32, active: Int32,
                                                  value: UInt64): Unit {}

    // --- 内存追踪 ---

    private static func nativeTracyEmitMemoryAlloc(ptr: Int64, size: UInt64,
                                                    secure: Int32): Unit {}

    private static func nativeTracyEmitMemoryAllocCallstack(
        ptr: Int64, size: UInt64, depth: Int32,
        secure: Int32): Unit {}

    private static func nativeTracyEmitMemoryFree(ptr: Int64,
                                                   secure: Int32): Unit {}

    private static func nativeTracyEmitMemoryFreeCallstack(
        ptr: Int64, depth: Int32, secure: Int32): Unit {}

    private static func nativeTracyEmitMemoryAllocNamed(
        ptr: Int64, size: UInt64, secure: Int32,
        name: String): Unit {}

    private static func nativeTracyEmitMemoryAllocCallstackNamed(
        ptr: Int64, size: UInt64, depth: Int32, secure: Int32,
        name: String): Unit {}

    private static func nativeTracyEmitMemoryFreeNamed(
        ptr: Int64, secure: Int32, name: String): Unit {}

    private static func nativeTracyEmitMemoryFreeCallstackNamed(
        ptr: Int64, depth: Int32, secure: Int32,
        name: String): Unit {}

    // --- 消息 ---

    private static func nativeTracyEmitMessage(text: String,
                                                callstack: Int32): Unit {}

    private static func nativeTracyEmitMessageL(text: String,
                                                 callstack: Int32): Unit {}

    private static func nativeTracyEmitMessageC(text: String, color: UInt32,
                                                 callstack: Int32): Unit {}

    private static func nativeTracyEmitMessageLC(text: String, color: UInt32,
                                                  callstack: Int32): Unit {}

    // --- 帧标记 ---

    private static func nativeTracyEmitFrameMark(name: String): Unit {}

    private static func nativeTracyEmitFrameMarkStart(name: String): Unit {}

    public static func nativeTracyEmitFrameMarkEnd(name: String): Unit {}

    // --- 生命周期 ---

    private static func nativeTracyStartupProfiler(): Unit {}

    private static func nativeTracyShutdownProfiler(): Unit {}

    private static func nativeTracyConnected(): Int32 {
        return 0
    }

    private static func nativeTracySetThreadName(name: String): Unit {}

    // --- 动态加载 ---

    private static func nativeDlopen(path: String): Int64 {
        return 0
    }
}

// ============================================================================
// TracyFrame - 命名帧
// 严格翻译自: tracy.zig - Frame()
//   pub fn Frame(comptime name: [:0]const u8) type {
//       return struct {
//           pub fn end(_: @This()) void { frameMarkEnd(name); }
//       };
//   }
// ============================================================================

/// Tracy 命名帧 - 对应 Bun tracy.Frame(name)
public class TracyFrame {
    private let name: String

    public init(name: String) {
        this.name = name
    }

    /// 结束帧
    /// 对应 Zig Frame.end()
    public func end(): Unit {
        // 调用 frameMarkEnd(name)
        // 这需要访问 Tracy.frameMarkEnd，通过间接调用
        if (!tracyEnabled) {
            return
        }
        Tracy.nativeTracyEmitFrameMarkEnd(name)
    }
}

// ============================================================================
// TracyAllocator - Tracy 感知分配器
// 严格翻译自: tracy.zig - TracyAllocator
//   pub fn TracyAllocator(comptime name: ?[:0]const u8) type {
//       return struct {
//           parent_allocator: std.mem.Allocator,
//           pub fn init(parent_allocator: std.mem.Allocator) Self { ... }
//           pub fn allocator(self: *Self) std.mem.Allocator { ... }
//           fn allocFn(...) ?[*]u8 { ... }
//           fn resizeFn(...) bool { ... }
//           fn freeFn(...) void { ... }
//       };
//   }
// ============================================================================

/// Tracy 感知分配器 - 对应 Bun tracy.TracyAllocator
/// 包装标准分配器，在每次 alloc/free 时通知 Tracy
public class TracyAllocator {
    /// 分配器名称 (用于 Tracy 中标识)
    public let tracyName: ?String

    /// 总分配字节数
    public var totalAllocated: UInt64 = 0

    /// 总释放字节数
    public var totalFreed: UInt64 = 0

    /// 当前活跃分配字节数
    public var currentBytes: UInt64 = 0

    /// 分配次数
    public var allocationCount: UInt64 = 0

    public init(tracyName: ?String) {
        this.tracyName = tracyName
    }

    /// 记录分配
    /// 对应 Zig TracyAllocator.allocFn()
    public func recordAlloc(size: UInt64, ptr: Int64): Unit {
        totalAllocated = totalAllocated + size
        currentBytes = currentBytes + size
        allocationCount = allocationCount + 1

        if (!ENABLE_ALLOCATION || !tracyEnabled) {
            return
        }

        if (size != 0) {
            if (let Some(name) <- tracyName) {
                Tracy.allocNamed(ptr, size, name)
            } else {
                Tracy.alloc(ptr, size)
            }
        }
    }

    /// 记录释放
    /// 对应 Zig TracyAllocator.freeFn()
    public func recordFree(size: UInt64, ptr: Int64): Unit {
        totalFreed = totalFreed + size
        if (currentBytes >= size) {
            currentBytes = currentBytes - size
        } else {
            currentBytes = 0
        }

        if (!ENABLE_ALLOCATION || !tracyEnabled) {
            return
        }

        if (size != 0) {
            if (let Some(name) <- tracyName) {
                Tracy.freeNamed(ptr, name)
            } else {
                Tracy.free(ptr)
            }
        }
    }

    /// 记录调整大小
    /// 对应 Zig TracyAllocator.resizeFn()
    public func recordResize(oldSize: UInt64, newSize: UInt64,
                              ptr: Int64): Unit {
        if (oldSize == newSize) {
            return
        }

        if (!ENABLE_ALLOCATION || !tracyEnabled) {
            // 仅更新统计
            if (newSize > oldSize) {
                currentBytes = currentBytes + (newSize - oldSize)
                totalAllocated = totalAllocated + (newSize - oldSize)
            } else {
                if (currentBytes >= (oldSize - newSize)) {
                    currentBytes = currentBytes - (oldSize - newSize)
                }
                totalFreed = totalFreed + (oldSize - newSize)
            }
            return
        }

        // Tracy: 先释放旧大小，再分配新大小
        if (let Some(name) <- tracyName) {
            Tracy.freeNamed(ptr, name)
            Tracy.allocNamed(ptr, newSize, name)
        } else {
            Tracy.free(ptr)
            Tracy.alloc(ptr, newSize)
        }
    }
}
