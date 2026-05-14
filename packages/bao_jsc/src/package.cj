// 严格翻译自: src/jsc/
// bao_jsc 包入口 - 重新导出所有公共类型

package bao_jsc

// JsValue 类型系统
public type JsBool = Bool
public type JsNumber = Float64
public type JsString = String

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
