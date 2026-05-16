// 严格翻译自: src/jsc/
// bao_jsc 包入口 - 重新导出所有公共类型

package bao_jsc

// JsValue 类型系统
public type JsBool = Bool
public type JsNumber = Float64
public type JsString_ = JsString

// 重新导出所有类型
public type JscValue = JsValue
public type JscObject = JsObject
public type JscFunction = JsFunction
public type JscPromise = JsPromise
public type JscString = JsString
public type JscSymbol = JsSymbol
public type JscContext = JsContext
public type JscVM = JsVirtualMachine
public type JscModule = JsModule

// 新翻译的类型重新导出
public type JscVirtualMachine = BunVirtualMachine
public type JscConsoleObject = ConsoleObject
public type JscJSGlobalObject = JSGlobalObject
public type JscWebWorker = WebWorker
public type JscRareData = RareData
public type JscModuleLoader = ModuleLoader

// Phase 5 - JSC 绑定和基础设施类型重新导出
public type JscJSModuleLoader = JSModuleLoader_
public type JscJsInternalPromise = JsInternalPromise
public type JscSourceProvider = SourceProvider_
public type JscResolvedSourceTag = ResolvedSourceTag
public type JscResolvedSource = ResolvedSource_
public type JscScriptExecutionStatus = ScriptExecutionStatus
public type JscCounters = Counters
public type JscCounterField = CounterField
public type JscJsArrayIterator_ = JsArrayIterator_
public type JscJsMap_ = JsMap_
public type JscJsUint8Array_ = JsUint8Array_
public type JscJsCell_ = JsCell_
public type JscRegister = Register
public type JscCallFrameArguments = CallFrameArguments
public type JscAsyncCallType = AsyncCallType
public type JscAsyncTaskTracker = AsyncTaskTracker
public type JscTestReporterAgent = TestReporterAgent
public type JscTestStatus = TestStatus
public type JscTestType = TestType
public type JscLifecycleAgent = LifecycleAgent
public type JscDebuggerWait = DebuggerWait
public type JscDebuggerMode = DebuggerMode

// FFI 类型
public type JscContextRef = JSContextRef
public type JscValueRef = JSValueRef
public type JscObjectRef = JSObjectRef
public type JscStringRef = JSStringRef

// 错误类型
public type JscError = JsError
public type JscTypeError = JsTypeError
public type JscRangeError = JsRangeError
public type JscSyntaxError = JsSyntaxError
public type JscReferenceError = JsReferenceError

// ========== 新增类型导出 ==========

// 调用帧
public type JscCallFrame = CallFrame
public type JscArgumentsSlice = ArgumentsSlice

// JS 类型系统
public type JscType = JSType
public type JscRuntimeType = JSRuntimeType
public type JscErrorCode_ = JSErrorCode
public type JscPromiseRejectionOp = JSPromiseRejectionOperation

// 数组/集合
public type JscArray = JsArray
public type JscArrayIterator = JsArrayIterator
public type JscMap = JsMap
public type JscBigInt = JsBigInt
public type JscUint8Array = JsUint8Array
public type JscCell = JsCell
public type JscArrayBuffer = JsArrayBuffer
public type JscTypedArray = JsTypedArray

// 参数缓冲区
public type JscMarkedArgumentBuffer = MarkedArgumentBuffer

// 字符串
public type JscZigString = ZigString

// 错误/异常
public type JscException = JsException
public type JscErrorable = Errorable
public type JscDeferredError = DeferredError
public type JscGetterSetter = GetterSetter
public type JscCustomGetterSetter = CustomGetterSetter

// 错误码/类型
public type JscZigException = ZigException
public type JscZigErrorType = ZigErrorType
public type JscZigStackFrame = ZigStackFrame
public type JscZigStackTrace = ZigStackTrace
public type JscErrorCode_ = ErrorCode
public type JscJSErrorCode = JSErrorCode
public type JscDOMExceptionCode = DOMExceptionCode
public type JscTopExceptionScope = TopExceptionScope
public type JscExceptionValidationScope = ExceptionValidationScope

// 消息
public type JscBuildMessage = BuildMessage
public type JscResolveMessage = ResolveMessage
public type JscLoggerMsg = LoggerMsg

// Promise
public type JscAnyPromise = AnyPromise
public type JscConcurrentPromiseTask = ConcurrentPromiseTaskGeneric

// 引用
public type JscStrong<T> = Strong<T>
public type JscWeak<T> = Weak<T>

// 任务
public type JscTask = Task
public type JscWorkTask = WorkTask
public type JscCppTask = CppTask
public type JscConcurrentPromiseTask = ConcurrentPromiseTask

// 事件循环
public type JscEventLoop = EventLoop
public type JscMicrotaskQueue = MicrotaskQueue

// URL
public type JscURL = URL
public type JscURLSearchParams = URLSearchParams
public type JscDOMURL = DOMURL
public type JscDOMFormData = DOMFormData

// 系统
public type JscSystemError = SystemError
public type JscPosixSignalHandle = PosixSignalHandle
public type JscRegularExpression = RegularExpression
public type JscTextCodec = TextCodec
public type JscAbortSignal = AbortSignal
public type JscAbortController = AbortController

// IPC
public type JscHostFunction = HostFunction
public type JscFFIFunction = FFIFunction

// 调试
public type JscDebugger = Debugger_
public type JscHotReloader = HotReloader
public type JscSavedSourceMap = SavedSourceMap

// HTTP
public type JscFetchHeaders = FetchHeaders
public type JscHTTPServerAgent = HTTPServerAgent

// UUID
public type JscUUID = UUID

// Phase 6 - 新翻译类型重新导出

// 异步模块
public type JscAsyncModule = AsyncModule
public type JscAsyncModuleQueue = AsyncModuleQueue

// CPU/Heap 分析器
public type JscBunCPUProfiler = BunCPUProfiler
public type JscBunHeapProfiler = BunHeapProfiler

// 字符串
public type JscBunString = BunString
public type JscRefString = RefString
public type JscStringBuilder = StringBuilder

// 字节码/缓存
public type JscCachedBytecode = CachedBytecode
public type JscRuntimeTranspilerCache = RuntimeTranspilerCache
public type JscRuntimeTranspilerStore = RuntimeTranspilerStore

// 字符串映射
public type JscComptimeStringMap = ComptimeStringMap

// DOM 效果
public type JscDOMEffect = DOMEffect
public type JscHostFn = HostFn

// 垃圾回收控制器
public type JscGarbageCollectionController = GarbageCollectionController

// JSON 行缓冲区
public type JscJSONLineBuffer = JSONLineBuffer

// Node 模块
public type JscNodeModuleModule = NodeModuleModule

// 进程自动终止器
public type JscProcessAutoKiller = ProcessAutoKiller

// 虚拟机导出
public type JscVirtualMachineExports = VirtualMachineExports

// 堆栈帧
public type JscZigStackFrameCode = ZigStackFrameCode
public type JscZigStackFramePosition = ZigStackFramePosition

// 插件运行器
public type JscPluginRunner = PluginRunner
public type JscHostFnEntry = HostFnEntry

// 路径类型
public type JscPathLike = PathLike
public type JscPathOrFileDescriptor = PathOrFileDescriptor
public type JscPathOrFileDescriptorSerializeTag = PathOrFileDescriptorSerializeTag
public type JscThreadSafe = ThreadSafePathLike

// Webcore 数据类型
public type JscBlob = Blob
public type JscStore = Store
public type JscStoreRef = StoreRef
public type JscStoreData = Data
public type JscBytes = Bytes
public type JscStoreFile = File
public type JscS3 = S3
public type JscClosingState = ClosingState
public type JscDataTag = DataTag
public type JscSerializeTag = SerializeTag

// AnyTaskJob
public type JscAnyTaskJob<C> = AnyTaskJob<C>

// Bun JSC native 源码清单
public type JscNativeSourcesManifest = JscNativeSources

// 包版本信息
public let BAO_JSC_VERSION = "0.1.0"

// 工具函数

// 快速创建 undefined
public func undefined() -> JsValue {
    JsValue.undefined()
}

// 快速创建 null
public func null() -> JsValue {
    JsValue.null()
}

// 从 Bool 创建 JsValue
public func value(b: Bool) -> JsValue {
    JsValue(b: b)
}

// 从 Number 创建 JsValue
public func value(n: Float64) -> JsValue {
    JsValue(n: n)
}

// 从 String 创建 JsValue
public func value(s: String) -> JsValue {
    JsValue(s: s)
}

// 从 Object 创建 JsValue
public func value(obj: JsObject) -> JsValue {
    JsValue(obj: obj)
}

// 创建新 VM
public func createVM() -> JsVirtualMachine {
    JsVirtualMachine()
}

// 创建新上下文
public func createContext() -> JsContext {
    let vm = JsVirtualMachine()
    vm.createContext()
}

// 执行脚本
public func evaluate(code: String, sourceUrl: String) -> JsValue {
    let vm = JsVirtualMachine()
    let ctx = vm.createContext()
    ctx.evaluateScript(code, sourceUrl)
}
