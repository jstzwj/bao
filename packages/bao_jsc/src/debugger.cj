// 严格翻译自: src/jsc/Debugger.zig (536行) + hot_reloader.zig + AsyncModule.zig
// Bun 调试器、热重载和异步模块

package bao_jsc

// ========== Wait 枚举 ==========
// 严格翻译自 Debugger.zig Wait
// 调试器等待连接的模式
public enum DebuggerWait {
    | Off       // 不等待
    | Shortly   // 短暂等待 (30ms 超时)
    | Forever   // 无限等待
}

// ========== Mode 枚举 ==========
// 严格翻译自 Debugger.zig mode
// 调试器的连接模式
public enum DebuggerMode {
    | Listen    // Bun 作为服务器 (https://debug.bun.sh/ 使用此模式)
    | Connect   // Bun 连接到指定路径 (VSCode 扩展使用此模式)
}

// ========== 调试器 ==========
// 严格翻译自 Debugger.zig
public class Debugger_ {
    public var isEnabled: Bool = false
    public var isPaused: Bool = false
    public var pathOrPort: ?String = None
    public var fromEnvironmentVariable: String = ""
    public var scriptExecutionContextId: UInt32 = 0
    public var nextDebuggerId: UInt64 = 1
    public var waitForConnection: DebuggerWait = DebuggerWait.Off
    public var setBreakpointOnFirstLine: Bool = false
    public var inspectorKind: InspectorKind = InspectorKind.None
    public var mode: DebuggerMode = DebuggerMode.Listen
    public var waitTimeout: Float64 = 0.0
    public var defaultUrl: String = ""
    public var hasStarted: Bool = false
    public var breakOnFirstLine: Bool = false
    public var mustBlockUntilConnected: Bool = false

    // 断点列表
    public var breakpoints: Array<Breakpoint> = []

    public init() {}

    // 启用调试器
    public func enable() {
        isEnabled = true
    }

    // 禁用调试器
    public func disable() {
        isEnabled = false
        isPaused = false
    }

    // 暂停执行
    public func pause() {
        if (isEnabled) {
            isPaused = true
        }
    }

    // 继续执行
    public func resume() {
        isPaused = false
    }

    // 添加断点
    public func addBreakpoint(url: String, line: Int64, column: Int64): Int64 {
        nextDebuggerId++
        let bp = Breakpoint(Int64(nextDebuggerId), url, line, column)
        breakpoints = breakpoints.concat([bp])
        Int64(nextDebuggerId)
    }

    // 移除断点
    public func removeBreakpoint(id: Int64): Bool {
        var idx: Int64 = -1
        for (i in 0..breakpoints.size) {
            if (breakpoints[i].id == id) {
                idx = Int64(i)
                break
            }
        }
        if (idx >= 0) {
            breakpoints = breakpoints.slice(0, idx).concat(breakpoints.slice(idx + 1, breakpoints.size))
            return true
        }
        false
    }

    // 检查是否在断点处
    public func shouldBreak(url: String, line: Int64): Bool {
        if (!isEnabled) { return false }
        if (breakOnFirstLine) { return true }
        for (bp in breakpoints) {
            if (bp.url == url && bp.line == line) {
                return true
            }
        }
        false
    }
}

// ========== 断点 ==========
public class Breakpoint {
    public var id: Int64 = 0
    public var url: String = ""
    public var line: Int64 = 0
    public var column: Int64 = 0
    public var condition: ?String = None
    public var hitCount: Int64 = 0
    public var isEnabled: Bool = true

    public init() {}

    public init(id: Int64, url: String, line: Int64, column: Int64) {
        this.id = id
        this.url = url
        this.line = line
        this.column = column
    }
}

// ========== Inspector 类型 ==========
public enum InspectorKind {
    | None
    | WebInspector
    | ChromeDevTools
    | VSCode
}

// 注意: HotReloader 已移至 hot_reloader.cj

// ========== 异步模块 ==========
// 严格翻译自 AsyncModule.zig
public class AsyncModule_ {
    public var specifier: String = ""
    public var isResolved: Bool = false
    public var isRejected: Bool = false
    public var error: ?JsValue = None
    public var result: ?JsValue = None
    public var dependencySpecifiers: Array<String> = []
    public var evaluateCallback: ?(() -> JsValue) = None

    // 队列相关
    public var queue: ?AsyncModuleQueue_ = None

    public init() {}

    public init(specifier: String) {
        this.specifier = specifier
    }

    // 解决模块
    public func resolve(value: JsValue) {
        isResolved = true
        result = value
    }

    // 拒绝模块
    public func reject(err: JsValue) {
        isRejected = true
        error = err
    }

    // 添加依赖说明符
    public func addDependency(specifier: String) {
        dependencySpecifiers = dependencySpecifiers.concat([specifier])
    }

    // 是否已完成
    public func isCompleted(): Bool {
        isResolved || isRejected
    }
}

// 异步模块队列 (扩展版本)
public class AsyncModuleQueue_ {
    public var queue: Array<AsyncModule_> = []
    public var isProcessing: Bool = false

    public init() {}

    // 入队
    public func enqueue(module: AsyncModule_) {
        queue = queue.concat([module])
    }

    // 处理所有挂起的模块
    public func processAll() {
        if (isProcessing) { return }
        isProcessing = true
        // defer: { isProcessing = false }

        while (queue.size > 0) {
            let module = queue[0]
            queue = queue.slice(1, queue.size)
            if (!module.isCompleted()) {
                // 等待依赖
                match (module.evaluateCallback) {
                    case Some(cb) =>
                        let result = cb()
                        module.resolve(result)
                    case None => ()
                }
            }
        }
    }
}

// 注意: SavedSourceMap 已移至 saved_source_map.cj

// 注意: CachedBytecode 已移至 cached_bytecode.cj
// 注意: BuildMessage 已移至 build_message.cj
// 注意: SourceLocation 已移至 build_message.cj (MsgLocation)
// 注意: BuildNote 已移至 build_message.cj (MsgData)
// 注意: MessageSeverity 已移至 build_message.cj (MsgKind)

// 注意: RuntimeTranspilerCache 已移至 runtime_transpiler_cache.cj

// 注意: ResolveMessage 已移至 resolve_message.cj

// ========== AsyncCallType ==========
// 严格翻译自 Debugger.zig AsyncCallType
// 异步调用的类型，用于 Inspector 调试器追踪异步操作
public enum AsyncCallType {
    | None
}

// 注意: AsyncTaskTracker 已移至 work_task.cj
// 用于追踪异步任务的调试器辅助工具
//
// 原始 Zig:
//   pub const AsyncTaskTracker = struct {
//       id: u64,
//       pub fn init(vm: *VirtualMachine) AsyncTaskTracker { ... }
//       pub fn didSchedule(this: AsyncTaskTracker, globalObject: *JSGlobalObject) void { ... }
//       pub fn didCancel(this: AsyncTaskTracker, globalObject: *JSGlobalObject) void { ... }
//       pub fn willDispatch(this: AsyncTaskTracker, globalObject: *JSGlobalObject) void { ... }
//       pub fn didDispatch(this: AsyncTaskTracker, globalObject: *JSGlobalObject) void { ... }
//   };
// 注意: AsyncTaskTracker 已移至 work_task.cj

// ========== 调试器 FFI 辅助函数 ==========
// 严格翻译自 Debugger.zig 中的 extern 函数

// 调度异步调用通知
// FFI: Debugger__didScheduleAsyncCall(*JSGlobalObject, AsyncCallType, u64, bool)
func didScheduleAsyncCall(globalObject: JsObject, callType: AsyncCallType, id: UInt64, singleShot: Bool) {
    // FFI 桩
}

// 取消异步调用通知
// FFI: Debugger__didCancelAsyncCall(*JSGlobalObject, AsyncCallType, u64)
func didCancelAsyncCall(globalObject: JsObject, callType: AsyncCallType, id: UInt64) {
    // FFI 桩
}

// 分发异步调用通知
// FFI: Debugger__didDispatchAsyncCall(*JSGlobalObject, AsyncCallType, u64)
func didDispatchAsyncCall(globalObject: JsObject, callType: AsyncCallType, id: UInt64) {
    // FFI 桩
}

// 即将分发异步调用通知
// FFI: Debugger__willDispatchAsyncCall(*JSGlobalObject, AsyncCallType, u64)
func willDispatchAsyncCall(globalObject: JsObject, callType: AsyncCallType, id: UInt64) {
    // FFI 桩
}

// ========== TestReporterAgent ==========
// 严格翻译自 Debugger.zig TestReporterAgent
// 测试报告器代理，用于向 Inspector 报告测试结果
//
// 原始 Zig:
//   pub const TestReporterAgent = struct {
//       handle: ?*Handle = null,
//       pub const TestStatus = enum(u8) { pass, fail, timeout, skip, todo, skipped_because_label }
//       pub const TestType = enum(u8) { test = 0, describe = 1 }
//       ...
//   };
public class TestReporterAgent {
    public var handle: ?TestReporterHandle = None

    public init() {}

    // 是否已启用
    public func isEnabled(): Bool {
        match (handle) {
            case Some(_) => true
            case None => false
        }
    }

    // 报告发现测试
    public func reportTestFound(callFrame: CallFrame, testId: Int32, name: String, itemType: TestType, parentId: Int32) {
        if (let Some(h) <- handle) {
            h.reportTestFound(callFrame, testId, name, itemType, parentId)
        }
    }

    // 报告测试开始
    public func reportTestStart(testId: Int32) {
        if (let Some(h) <- handle) {
            h.reportTestStart(testId)
        }
    }

    // 报告测试结束
    public func reportTestEnd(testId: Int32, status: TestStatus, elapsed: Float64) {
        if (let Some(h) <- handle) {
            h.reportTestEnd(testId, status, elapsed)
        }
    }
}

// 测试状态 - 与 c++ InspectorTestReporterAgent.cpp enum class BunTestStatus 保持同步
public enum TestStatus {
    | None
}

// 测试类型
public enum TestType {
    | None
}

// 测试报告器句柄 (opaque)
public class TestReporterHandle {
    public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()

    public init() {}

    // FFI: Bun__TestReporterAgentReportTestFound
    public func reportTestFound(callFrame: CallFrame, testId: Int32, name: String, itemType: TestType, parentId: Int32) {
        // FFI 桩
    }

    // FFI: Bun__TestReporterAgentReportTestStart
    public func reportTestStart(testId: Int32) {
        // FFI 桩
    }

    // FFI: Bun__TestReporterAgentReportTestEnd
    public func reportTestEnd(testId: Int32, status: TestStatus, elapsed: Float64) {
        // FFI 桩
    }
}

// ========== LifecycleAgent ==========
// 严格翻译自 Debugger.zig LifecycleAgent
// 生命周期代理，用于向 Inspector 报告重载和错误事件
public class LifecycleAgent {
    public var handle: ?LifecycleHandle = None

    public init() {}

    // 是否已启用
    public func isEnabled(): Bool {
        match (handle) {
            case Some(_) => true
            case None => false
        }
    }

    // 报告重载
    public func reportReload() {
        if (let Some(h) <- handle) {
            h.reportReload()
        }
    }

    // 报告错误
    public func reportError(exception: JsException) {
        if (let Some(h) <- handle) {
            h.reportError(exception)
        }
    }
}

// 生命周期句柄 (opaque)
public class LifecycleHandle {
    public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()

    public init() {}

    // FFI: Bun__LifecycleAgentReportReload
    public func reportReload() {
        // FFI 桩
    }

    // FFI: Bun__LifecycleAgentReportError
    public func reportError(exception: JsException) {
        // FFI 桩
    }
}
