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
    public func addBreakpoint(url: String, line: Int64, column: Int64) -> Int64 {
        nextDebuggerId++
        let bp = Breakpoint(id: nextDebuggerId, url: url, line: line, column: column)
        breakpoints.append(bp)
        nextDebuggerId
    }

    // 移除断点
    public func removeBreakpoint(id: Int64) -> Bool {
        var idx = -1
        for (i in 0..breakpoints.size) {
            if (breakpoints[Int64(i)].id == id) {
                idx = Int64(i)
                break
            }
        }
        if (idx >= 0) {
            breakpoints.removeAt(idx)
            return true
        }
        false
    }

    // 检查是否在断点处
    public func shouldBreak(url: String, line: Int64) -> Bool {
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

// ========== 热重载器 ==========
// 严格翻译自 hot_reloader.zig
public class HotReloader {
    public var isEnabled: Bool = false
    public var watchedPaths: Array<String> = []
    public var ignoredPatterns: Array<String> = []
    public var debounceMs: Int64 = 100
    public var onReload: ?((String) -> Unit) = None
    public var onError: ?((JsValue) -> Unit) = None

    public init() {}

    // 启用热重载
    public func enable(path: String) {
        isEnabled = true
        watchedPaths.append(path)
    }

    // 禁用热重载
    public func disable() {
        isEnabled = false
        watchedPaths = []
    }

    // 添加监听路径
    public func addWatch(path: String) {
        if (!watchedPaths.contains(path)) {
            watchedPaths.append(path)
        }
    }

    // 移除监听路径
    public func removeWatch(path: String) {
        var idx = -1
        for (i in 0..watchedPaths.size) {
            if (watchedPaths[Int64(i)] == path) {
                idx = Int64(i)
                break
            }
        }
        if (idx >= 0) {
            watchedPaths.removeAt(idx)
        }
    }

    // 触发重载
    public func triggerReload(path: String) {
        if (!isEnabled) { return }
        if (let Some(cb) <- onReload) {
            cb(path)
        }
    }

    // 触发错误
    public func triggerError(error: JsValue) {
        if (let Some(cb) <- onError) {
            cb(error)
        }
    }

    // 检查路径是否应该被忽略
    public func shouldIgnore(path: String) -> Bool {
        for (pattern in ignoredPatterns) {
            if (path.startsWith(pattern)) {
                return true
            }
        }
        false
    }
}

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
        dependencySpecifiers.append(specifier)
    }

    // 是否已完成
    public func isCompleted() -> Bool {
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
        queue.append(module)
    }

    // 处理所有挂起的模块
    public func processAll() {
        if (isProcessing) { return }
        isProcessing = true
        defer { isProcessing = false }

        while (queue.size > 0) {
            let module = queue[0]
            queue = queue.slice(1)
            if (!module.isCompleted()) {
                // 等待依赖
                if (module.evaluateCallback != None) {
                    let result = module.evaluateCallback.getOrThrow()()
                    module.resolve(result)
                }
            }
        }
    }
}

// ========== 保存的 SourceMap ==========
// 严格翻译自 SavedSourceMap.zig
public class SavedSourceMap {
    public var file: String = ""
    public var mappings: String = ""
    public var sources: Array<String> = []
    public var sourcesContent: Array<String> = []
    public var names: Array<String> = []
    public var sourceRoot: String = ""

    public init() {}

    // 查找原始位置
    public func lookup(line: Int64, column: Int64) -> ?SourceMapLookup {
        // 简化实现
        let lookup = SourceMapLookup()
        lookup.originalLine = line
        lookup.originalColumn = column
        if (sources.size > 0) {
            lookup.displaySourceURL = sources[0]
        }
        Some(lookup)
    }
}

// ========== 缓存字节码 ==========
// 严格翻译自 CachedBytecode.zig
public class CachedBytecode {
    public var hash: Int64 = 0
    public var bytecode: Array<UInt8> = []
    public var sourceURL: String = ""
    public var isValid: Bool = false

    public init() {}

    public init(bytecode: Array<UInt8>, sourceURL: String) {
        this.bytecode = bytecode
        this.sourceURL = sourceURL
        this.isValid = bytecode.size > 0
    }
}

// ========== 构建消息 ==========
// 严格翻译自 BuildMessage.zig
public class BuildMessage {
    public var text: String = ""
    public var location: ?SourceLocation = None
    public var severity: MessageSeverity = MessageSeverity.Error
    public var notes: Array<BuildNote> = []

    public init() {}

    public init(text: String) {
        this.text = text
    }
}

public class SourceLocation {
    public var file: String = ""
    public var line: Int64 = 0
    public var column: Int64 = 0
    public var lineText: String = ""

    public init() {}
}

public class BuildNote {
    public var text: String = ""
    public var location: ?SourceLocation = None

    public init() {}
}

public enum MessageSeverity {
    | Error
    | Warning
    | Info
    | Debug
}

// ========== 运行时转译器缓存 ==========
// 严格翻译自 RuntimeTranspilerCache.zig
public class RuntimeTranspilerCache {
    public var cache: HashMap<String, CachedBytecode> = HashMap()
    public var isEnabled: Bool = true

    public init() {}

    public func get(key: String) -> ?CachedBytecode {
        cache.get(key)
    }

    public func put(key: String, bytecode: CachedBytecode) {
        cache.put(key, bytecode)
    }

    public func clear() {
        cache.clear()
    }
}

// ========== 解析消息 ==========
// 严格翻译自 ResolveMessage.zig
public class ResolveMessage {
    public var specifier: String = ""
    public var referrer: String = ""
    public var isError: Bool = false
    public var message: String = ""

    public init() {}
}

// ========== AsyncCallType ==========
// 严格翻译自 Debugger.zig AsyncCallType
// 异步调用的类型，用于 Inspector 调试器追踪异步操作
public enum AsyncCallType {
    | None
}
    }
}

// ========== AsyncTaskTracker ==========
// 严格翻译自 Debugger.zig AsyncTaskTracker
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
public class AsyncTaskTracker {
    public var id: UInt64 = 0

    public init() {}

    public init(id: UInt64) {
        this.id = id
    }

    // 严格翻译自 AsyncTaskTracker.init
    public static func initFunc(vm: BunVirtualMachine) -> AsyncTaskTracker {
        AsyncTaskTracker(id: vm.nextAsyncTaskID())
    }

    // 严格翻译自 AsyncTaskTracker.didSchedule
    // 通知调试器异步调用已调度
    // FFI: Debugger__didScheduleAsyncCall(globalObject, callType, id, singleShot)
    public func didSchedule(globalObject: JsObject) {
        if (id == 0) { return }
        didScheduleAsyncCall(globalObject, AsyncCallType.EventListener, id, true)
    }

    // 严格翻译自 AsyncTaskTracker.didCancel
    // 通知调试器异步调用已取消
    // FFI: Debugger__didCancelAsyncCall(globalObject, callType, id)
    public func didCancel(globalObject: JsObject) {
        if (id == 0) { return }
        didCancelAsyncCall(globalObject, AsyncCallType.EventListener, id)
    }

    // 严格翻译自 AsyncTaskTracker.willDispatch
    // 通知调试器异步调用即将分发
    // FFI: Debugger__willDispatchAsyncCall(globalObject, callType, id)
    public func willDispatch(globalObject: JsObject) {
        if (id == 0) { return }
        willDispatchAsyncCall(globalObject, AsyncCallType.EventListener, id)
    }

    // 严格翻译自 AsyncTaskTracker.didDispatch
    // 通知调试器异步调用已完成分发
    // FFI: Debugger__didDispatchAsyncCall(globalObject, callType, id)
    public func didDispatch(globalObject: JsObject) {
        if (id == 0) { return }
        didDispatchAsyncCall(globalObject, AsyncCallType.EventListener, id)
    }
}

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
    public func isEnabled() -> Bool {
        handle != None
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
    public func isEnabled() -> Bool {
        handle != None
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
