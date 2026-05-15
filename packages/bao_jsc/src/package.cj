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
