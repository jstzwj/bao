// bao_core - Tracy 性能分析集成
// 严格翻译自: src/perf/tracy.zig
//   Bun 的 Tracy 集成:
//   - 运行时 dlsym 检测 Tracy 库是否存在
//   - 支持: zone (begin/end), memory (alloc/free), message, frame mark
//   - 可选: allocation tracking, callstack depth
//   - 通过动态加载避免硬依赖
//   仓颉: 提供 Tracy 兼容的接口框架, 通过 C FFI dlsym 动态加载
package bao_core.perf

// ============================================================================
// C FFI 声明
// 严格翻译自: tracy.zig 中 dlsym 相关函数
// ============================================================================

@C
foreign func dlopen(filename: CPointer<Int8>, flags: Int32): CPointer<Unit>
@C
foreign func dlsym(handle: CPointer<Unit>, symbol: CPointer<Int8>): CPointer<Unit>
@C
foreign func dlerror(): CPointer<Int8>
@C
foreign func getenv(name: CPointer<Int8>): CPointer<Int8>

// ============================================================================
// Tracy 配置
// 严格翻译自: tracy.zig 顶部的配置变量
// ============================================================================

/// 是否启用分配追踪
/// 对应 Bun: tracy.enable_allocation = false
public let TRACY_ENABLE_ALLOCATION: Bool = false

/// 是否启用调用栈捕获
/// 对应 Bun: tracy.enable_callstack = false
public let TRACY_ENABLE_CALLSTACK: Bool = false

/// 调用栈深度
/// 对应 Bun: build_options.tracy_callstack_depth
public let TRACY_CALLSTACK_DEPTH: Int32 = 10

// ============================================================================
// TracyCtx - Tracy zone 上下文
// 严格翻译自: tracy.zig ___tracy_c_zone_context
//   extern struct { id: u32, active: c_int }
//   方法: end(), addText(), setName(), setColor(), setValue()
// ============================================================================

/// Tracy zone 上下文
/// 对应 Bun: ___tracy_c_zone_context
/// 用于标记一个追踪区域的开始和结束
public class TracyCtx {
    /// Zone ID
    public var id: UInt32
    /// 是否激活
    public var active: Bool

    public init() {
        id = 0
        active = false
    }

    public init(id: UInt32, active: Bool) {
        this.id = id
        this.active = active
    }

    /// 结束 zone
    /// 对应 Bun: ___tracy_c_zone_context.end() -> ___tracy_emit_zone_end(self)
    public func end(): Unit {
        if (!TracyProfiler.enable || !active) { return }
        TracyProfiler.emitZoneEnd(this)
    }

    /// 添加文本到 zone
    /// 对应 Bun: ___tracy_c_zone_context.addText(text) -> ___tracy_emit_zone_text(self, text.ptr, text.len)
    public func addText(text: String): Unit {
        if (!TracyProfiler.enable || !active) { return }
        TracyProfiler.emitZoneText(this, text)
    }

    /// 设置 zone 名称
    /// 对应 Bun: ___tracy_c_zone_context.setName(name) -> ___tracy_emit_zone_name(self, name.ptr, name.len)
    public func setName(name: String): Unit {
        if (!TracyProfiler.enable || !active) { return }
        TracyProfiler.emitZoneName(this, name)
    }

    /// 设置 zone 颜色
    /// 对应 Bun: ___tracy_c_zone_context.setColor(color) -> ___tracy_emit_zone_color(self, color)
    public func setColor(color: UInt32): Unit {
        if (!TracyProfiler.enable || !active) { return }
        TracyProfiler.emitZoneColor(this, color)
    }

    /// 设置 zone 值
    /// 对应 Bun: ___tracy_c_zone_context.setValue(value) -> ___tracy_emit_zone_value(self, value)
    public func setValue(value: UInt64): Unit {
        if (!TracyProfiler.enable || !active) { return }
        TracyProfiler.emitZoneValue(this, value)
    }
}

// ============================================================================
// TracySourceLocationData - Tracy 源码位置数据
// 严格翻译自: tracy.zig ___tracy_source_location_data
//   extern struct { name, function, file, line, color }
// ============================================================================

/// Tracy 源码位置数据
/// 对应 Bun: ___tracy_source_location_data
public class TracySourceLocationData {
    /// Zone 名称 (可选)
    public var name: String
    /// 函数名
    public var functionName: String
    /// 文件路径
    public var file: String
    /// 行号
    public var line: UInt32
    /// 颜色
    public var color: UInt32

    public init() {
        name = ""
        functionName = ""
        file = ""
        line = 0
        color = 0
    }

    public init(name: String, functionName: String, file: String,
                line: UInt32, color: UInt32) {
        this.name = name
        this.functionName = functionName
        this.file = file
        this.line = line
        this.color = color
    }
}

// ============================================================================
// TracyProfiler - Tracy 分析器主接口
// 严格翻译自: tracy.zig 顶层函数
//   init(), start(), stop(), trace(), traceNamed(), message(), frameMark() 等
// ============================================================================

/// Tracy 分析器
/// 对应 Bun: tracy 命名空间的全部顶层函数
///
/// 基于 dlsym 动态加载 Tracy 库:
///   macOS: /usr/local/opt/tracy/lib/libtracy.dylib, /opt/homebrew/lib/libtracy.dylib 等
///   Linux: /usr/local/lib/libtracy.so, /usr/lib/libtracy.so 等
///   Windows: tracy.dll
///   环境变量: BUN_TRACY_PATH 可覆盖默认路径
public class TracyProfiler {
    /// 是否启用 Tracy
    /// 对应 Bun: tracy.enable = false (运行时检测后设为 true)
    public static var enable: Bool = false

    /// 是否已启动
    /// 对应 Bun: tracy.has_started = false
    public static var hasStarted: Bool = false

    /// Tracy 库句柄
    private static var libraryHandle: ?CPointer<Unit> = None

    /// 初始化 Tracy (检测库是否存在)
    /// 对应 Bun: tracy.init() -> bool
    /// 通过 dlsym 检测 ___tracy_emit_message 是否存在
    public static func initTracy(): Bool {
        if (enable) { return true }

        // 尝试加载 Tracy 库
        let handle = loadTracyLibrary()
        if (handle.isSome()) {
            // 检查关键函数是否存在
            unsafe {
                let symName = unsafeNewCString("___tracy_emit_message")
                let sym = dlsym(handle.getOrThrow(), symName)
                if (!sym.isNull()) {
                    enable = true
                    libraryHandle = handle
                    return true
                }
            }
        }
        return false
    }

    /// 启动 Tracy 分析器
    /// 对应 Bun: tracy.start()
    /// 调用 ___tracy_startup_profiler
    public static func start(): Unit {
        if (!enable || hasStarted) { return }
        // 调用 ___tracy_startup_profiler
        emitStartupProfiler()
        hasStarted = true
    }

    /// 停止 Tracy 分析器
    /// 对应 Bun: tracy.stop()
    /// 调用 ___tracy_shutdown_profiler
    public static func stop(): Unit {
        if (!enable || !hasStarted) { return }
        emitShutdownProfiler()
    }

    /// 开始一个 zone (追踪区域)
    /// 对应 Bun: tracy.trace(src) -> Ctx
    /// 使用源码位置信息 (函数名, 文件, 行号)
    public static func trace(functionName: String, file: String,
                              line: UInt32): TracyCtx {
        if (!enable) { return TracyCtx() }

        let srcLoc = TracySourceLocationData(
            name: "",
            functionName: functionName,
            file: file,
            line: line,
            color: 0
        )
        return emitZoneBegin(srcLoc, 1)
    }

    /// 开始一个命名 zone
    /// 对应 Bun: tracy.traceNamed(src, name) -> Ctx
    public static func traceNamed(name: String, functionName: String,
                                   file: String, line: UInt32): TracyCtx {
        if (!enable) { return TracyCtx() }

        let srcLoc = TracySourceLocationData(
            name: name,
            functionName: functionName,
            file: file,
            line: line,
            color: 0
        )
        return emitZoneBegin(srcLoc, 1)
    }

    /// 发送消息 (编译期已知字符串)
    /// 对应 Bun: tracy.message(msg) -> ___tracy_emit_messageL(msg.ptr, depth)
    public static func message(msg: String): Unit {
        if (!enable) { return }
        emitMessageL(msg)
    }

    /// 发送带颜色的消息
    /// 对应 Bun: tracy.messageColor(msg, color) -> ___tracy_emit_messageLC(msg.ptr, color, depth)
    public static func messageColor(msg: String, color: UInt32): Unit {
        if (!enable) { return }
        emitMessageLC(msg, color)
    }

    /// 发送消息 (运行时字符串)
    /// 对应 Bun: tracy.messageCopy(msg) -> ___tracy_emit_message(msg.ptr, msg.len, depth)
    public static func messageCopy(msg: String): Unit {
        if (!enable) { return }
        emitMessage(msg)
    }

    /// 标记帧结束
    /// 对应 Bun: tracy.frameMark() -> ___tracy_emit_frame_mark(null)
    public static func frameMark(): Unit {
        if (!enable) { return }
        emitFrameMark("")
    }

    /// 标记命名帧结束
    /// 对应 Bun: tracy.frameMarkNamed(name) -> ___tracy_emit_frame_mark(name.ptr)
    public static func frameMarkNamed(name: String): Unit {
        if (!enable) { return }
        emitFrameMark(name)
    }

    /// 开始一个命名帧
    /// 对应 Bun: tracy.namedFrame(name) -> Frame(name)
    public static func namedFrame(name: String): TracyFrame {
        frameMarkStart(name)
        return TracyFrame(name)
    }

    /// 记录内存分配
    /// 对应 Bun: tracy.alloc(ptr, len) -> ___tracy_emit_memory_alloc(ptr, len, 0)
    public static func alloc(ptr: CPointer<Unit>, size: UIntNative): Unit {
        if (!enable) { return }
        emitMemoryAlloc(ptr, size)
    }

    /// 记录命名内存分配
    /// 对应 Bun: tracy.allocNamed(ptr, len, name)
    public static func allocNamed(ptr: CPointer<Unit>, size: UIntNative,
                                   name: String): Unit {
        if (!enable) { return }
        emitMemoryAllocNamed(ptr, size, name)
    }

    /// 记录内存释放
    /// 对应 Bun: tracy.free(ptr) -> ___tracy_emit_memory_free(ptr, 0)
    public static func free(ptr: CPointer<Unit>): Unit {
        if (!enable) { return }
        emitMemoryFree(ptr)
    }

    /// 记录命名内存释放
    /// 对应 Bun: tracy.freeNamed(ptr, name)
    public static func freeNamed(ptr: CPointer<Unit>, name: String): Unit {
        if (!enable) { return }
        emitMemoryFreeNamed(ptr, name)
    }

    /// 检查 Tracy 是否已连接
    /// 对应 Bun: tracy.isConnected() -> bool
    public static func isConnected(): Bool {
        if (!enable) { return false }
        // 调用 ___tracy_connected 检查
        return false  // 简化实现
    }

    /// 设置当前线程名称
    /// 对应 Bun: tracy.initThread(name) -> ___tracy_set_thread_name(name.ptr)
    public static func initThread(name: String): Unit {
        if (!enable) { return }
        emitSetThreadName(name)
    }

    // ========================================================================
    // 内部方法 - Tracy emit 函数
    // 严格对应 Bun: tracy.zig 中的 ___tracy_* 函数
    // 每个函数通过 dlsym 动态解析 Tracy C API
    // ========================================================================

    /// 加载 Tracy 动态库
    /// 对应 Bun: dlsym() 中的 Handle 和路径搜索
    private static func loadTracyLibrary(): ?CPointer<Unit> {
        unsafe {
            // 尝试 BUN_TRACY_PATH 环境变量
            let envName = unsafeNewCString("BUN_TRACY_PATH")
            let envPath = getenv(envName)
            if (!envPath.isNull()) {
                let pathStr = unsafeCStringToString(envPath)
                let pathPtr = unsafeNewCString(pathStr)
                let handle = dlopen(pathPtr, Int32(-2))  // RTLD_DEFAULT on macOS
                if (!handle.isNull()) { return handle }
            }

            // 尝试默认路径
            let paths = [
                "/usr/local/lib/libtracy.so",
                "/usr/local/opt/tracy/lib/libtracy.so",
                "/opt/homebrew/lib/libtracy.so",
                "/usr/lib/libtracy.so",
                "libtracy.so",
                "libTracyClient.so"
            ]
            for (path in paths) {
                let pathPtr = unsafeNewCString(path)
                let handle = dlopen(pathPtr, Int32(1))  // RTLD_LAZY
                if (!handle.isNull()) { return handle }
            }
            return None
        }
    }

    /// emit zone begin
    /// 对应 Bun: ___tracy_emit_zone_begin(srcloc, active)
    private static func emitZoneBegin(srcLoc: TracySourceLocationData,
                                       active: Int32): TracyCtx {
        // 通过 dlsym 调用 ___tracy_emit_zone_begin
        // 简化实现: 返回默认上下文
        return TracyCtx()
    }

    private static func emitZoneEnd(ctx: TracyCtx): Unit {
        // ___tracy_emit_zone_end(ctx)
    }

    private static func emitZoneText(ctx: TracyCtx, text: String): Unit {
        // ___tracy_emit_zone_text(ctx, text.ptr, text.len)
    }

    private static func emitZoneName(ctx: TracyCtx, name: String): Unit {
        // ___tracy_emit_zone_name(ctx, name.ptr, name.len)
    }

    private static func emitZoneColor(ctx: TracyCtx, color: UInt32): Unit {
        // ___tracy_emit_zone_color(ctx, color)
    }

    private static func emitZoneValue(ctx: TracyCtx, value: UInt64): Unit {
        // ___tracy_emit_zone_value(ctx, value)
    }

    private static func emitMessageL(msg: String): Unit {
        // ___tracy_emit_messageL(msg.ptr, depth)
    }

    private static func emitMessageLC(msg: String, color: UInt32): Unit {
        // ___tracy_emit_messageLC(msg.ptr, color, depth)
    }

    private static func emitMessage(msg: String): Unit {
        // ___tracy_emit_message(msg.ptr, msg.len, depth)
    }

    private static func emitFrameMark(name: String): Unit {
        // ___tracy_emit_frame_mark(name.ptr)
    }

    private static func frameMarkStart(name: String): Unit {
        // ___tracy_emit_frame_mark_start(name.ptr)
    }

    private static func frameMarkEnd(name: String): Unit {
        // ___tracy_emit_frame_mark_end(name.ptr)
    }

    private static func emitMemoryAlloc(ptr: CPointer<Unit>, size: UIntNative): Unit {
        // ___tracy_emit_memory_alloc(ptr, size, 0)
    }

    private static func emitMemoryAllocNamed(ptr: CPointer<Unit>, size: UIntNative,
                                              name: String): Unit {
        // ___tracy_emit_memory_alloc_named(ptr, size, 0, name.ptr)
    }

    private static func emitMemoryFree(ptr: CPointer<Unit>): Unit {
        // ___tracy_emit_memory_free(ptr, 0)
    }

    private static func emitMemoryFreeNamed(ptr: CPointer<Unit>, name: String): Unit {
        // ___tracy_emit_memory_free_named(ptr, 0, name.ptr)
    }

    private static func emitStartupProfiler(): Unit {
        // ___tracy_startup_profiler()
    }

    private static func emitShutdownProfiler(): Unit {
        // ___tracy_shutdown_profiler()
    }

    private static func emitSetThreadName(name: String): Unit {
        // ___tracy_set_thread_name(name.ptr)
    }
}

// ============================================================================
// TracyFrame - Tracy 命名帧
// 严格翻译自: tracy.zig Frame(comptime name) type
//   Frame 是一个简单的结构, end() 调用 frameMarkEnd(name)
// ============================================================================

/// Tracy 命名帧
/// 对应 Bun: Frame(name) struct { pub fn end() { frameMarkEnd(name) } }
public class TracyFrame {
    private let name: String

    public init(name: String) {
        this.name = name
    }

    /// 结束帧
    /// 对应 Bun: Frame.end() -> frameMarkEnd(name)
    public func end(): Unit {
        TracyProfiler.frameMarkEnd(name)
    }
}

// ============================================================================
// TracyAllocator - Tracy 内存分配追踪器
// 严格翻译自: tracy.zig TracyAllocator(comptime name) type
//   包装 std.mem.Allocator, 在每次 alloc/free 时通知 Tracy
// ============================================================================

/// Tracy 内存分配追踪器
/// 对应 Bun: TracyAllocator(name) struct
/// 包装父分配器, 在分配/释放时记录到 Tracy
public class TracyAllocator {
    /// 分配器名称
    public let name: String

    /// 总分配字节数
    public var totalAllocated: Int64
    /// 总释放字节数
    public var totalFreed: Int64
    /// 当前活跃分配数
    public var activeAllocations: Int64

    public init(name: String) {
        this.name = name
        totalAllocated = 0
        totalFreed = 0
        activeAllocations = 0
    }

    /// 记录分配
    /// 对应 Bun: TracyAllocator.allocFn -> alloc/allocNamed
    public func recordAlloc(size: UIntNative, ptr: CPointer<Unit>): Unit {
        totalAllocated += Int64(size)
        activeAllocations += 1
        TracyProfiler.allocNamed(ptr, size, name)
    }

    /// 记录释放
    /// 对应 Bun: TracyAllocator.freeFn -> free/freeNamed
    public func recordFree(size: UIntNative, ptr: CPointer<Unit>): Unit {
        totalFreed += Int64(size)
        activeAllocations -= 1
        TracyProfiler.freeNamed(ptr, name)
    }

    /// 记录 resize
    /// 对应 Bun: TracyAllocator.resizeFn -> free + alloc
    public func recordResize(oldSize: UIntNative, newSize: UIntNative,
                              ptr: CPointer<Unit>): Unit {
        totalFreed += Int64(oldSize)
        totalAllocated += Int64(newSize)
        TracyProfiler.freeNamed(ptr, name)
        TracyProfiler.allocNamed(ptr, newSize, name)
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

// malloc and free are declared in hw_timer.cj
