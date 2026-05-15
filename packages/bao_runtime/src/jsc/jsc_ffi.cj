// JavaScriptCore C API FFI 声明
// 对应 Bun: src/jsc/ 绑定的 JSC C API
// 仓颉没有 JSC 绑定，这些声明供未来切换到真正 JSC 时使用
// 当前使用 AST 解释器代替 JSC 执行
package bao_runtime.jsc

// ============================================================================
// JSC FFI — JavaScriptCore C API 声明
// 对应 Bun: src/jsc/ 中通过 Zig/Rust 调用的 JSC C 函数
//
// 这些是 JSC 的核心 C API，定义在 JavaScriptCore/JavaScript.h 中
// Bun 通过这些 C 函数创建 JS 上下文、执行代码、操作 JS 值
//
// 当前 Bao 使用 AST 解释器，不需要真正调用 JSC
// 但保留这些声明以保持与 Bun 的架构一致性
// 未来可以切换到仓颉 FFI 对接 JSC
// ============================================================================

/// JSC 全局上下文 — 对应 JSGlobalContextRef
public class JscContext {
    /// 上下文指针 (未来对接 JSC 时使用 CPointer<Unit>)
    private var handle: Int64

    public init() {
        handle = 0
    }

    /// 执行脚本 (占位 — 当前由 Interpreter 处理)
    public func evaluateScript(source: String, filename: String): JsValue {
        return JsValue.UNDEFINED
    }
}

/// JSC 值操作 — 对应 JSValueRef 操作
/// 当前为占位声明，未来通过 C FFI 调用 JSC
public class JscValue {
    /// 值指针
    private var handle: Int64

    public init() {
        handle = 0
    }

    /// 获取类型
    public func getType(): JsValueType {
        return JsValueType.Undefined
    }

    /// 转为布尔值
    public func toBoolean(): Bool {
        return false
    }

    /// 转为数值
    public func toNumber(): Float64 {
        return 0.0
    }

    /// 转为字符串
    public func toString(): String {
        return ""
    }
}

/// JSC 类定义 — 对应 JSClassRef
/// 用于创建自定义 JS 类
public class JscClass {
    public var name: String
    public var parentClass: ?JscClass

    public init(name: String) {
        this.name = name
        this.parentClass = None
    }
}

/// JSC 对象 — 对应 JSObjectRef
public class JscObject {
    private var handle: Int64

    public init() {
        handle = 0
    }

    /// 获取属性
    public func getProperty(name: String): JsValue {
        return JsValue.UNDEFINED
    }

    /// 设置属性
    public func setProperty(name: String, value: JsValue): Unit {
        // 占位
    }
}

/// JSC 字符串 — 对应 JSStringRef
public class JscString {
    private var handle: Int64

    public init() {
        handle = 0
    }

    public init(s: String) {
        handle = 0
    }

    public func toString(): String {
        return ""
    }
}

// ============================================================================
// JSC C API FFI 声明 (占位)
// 未来通过 @C foreign func 对接真正的 JavaScriptCore C 库
// ============================================================================

// 以下为 JSC C API 的声明模板，实际使用时需要链接 JSC 动态库:
//
// @C foreign func JSGlobalContextCreate(jsClass: CPointer<Unit>): CPointer<Unit>
// @C foreign func JSGlobalContextRelease(ctx: CPointer<Unit>): Unit
// @C foreign func JSEvaluateScript(ctx: CPointer<Unit>, script: CPointer<Unit>,
//                                   sourceURL: CPointer<Unit>, startingLineNumber: Int32,
//                                   exception: CPointer<CPointer<Unit>>): CPointer<Unit>
// @C foreign func JSValueMakeUndefined(ctx: CPointer<Unit>): CPointer<Unit>
// @C foreign func JSValueMakeNull(ctx: CPointer<Unit>): CPointer<Unit>
// @C foreign func JSValueMakeBoolean(ctx: CPointer<Unit>, value: Bool): CPointer<Unit>
// @C foreign func JSValueMakeNumber(ctx: CPointer<Unit>, value: Float64): CPointer<Unit>
// @C foreign func JSStringCreateWithUTF8CString(str: CPointer<UInt8>): CPointer<Unit>
// @C foreign func JSStringRelease(str: CPointer<Unit>): Unit
// @C foreign func JSValueToStringCopy(ctx: CPointer<Unit>, value: CPointer<Unit>,
//                                      exception: CPointer<CPointer<Unit>>): CPointer<Unit>
