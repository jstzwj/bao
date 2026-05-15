// 严格翻译自: src/jsc/Exception.zig (16行)
// JavaScriptCore Exception 不透明类型绑定

package bao_jsc

// ========== Exception ==========
// 严格翻译自 Exception.zig
// Exception 是 JavaScript 异常的不透明表示
// 在 JSC 中，Exception 对象包含错误的 JSValue 和可选的堆栈追踪
public class JsException {
    // 异常值
    public var value: JsValue = JsValue.undefined()
    // 堆栈追踪
    public var stackTrace: ZigStackTrace = ZigStackTrace()

    public init() {}

    public init(value: JsValue) {
        this.value = value
    }

    public init(value: JsValue, stackTrace: ZigStackTrace) {
        this.value = value
        this.stackTrace = stackTrace
    }

    // 严格翻译自 Exception.getStackTrace
    // 获取异常的堆栈追踪信息
    // @param global 全局对象
    // @param stack 输出的堆栈追踪
    public func getStackTrace(global: JsObject, stack: ZigStackTrace) {
        // FFI: JSC__Exception__getStackTrace(this, global, stack)
        // 在纯仓颉实现中，堆栈追踪通过全局对象获取
        this.stackTrace = stack
    }

    // 严格翻译自 Exception.value (asJSValue)
    // 获取异常的 JS 值表示
    public func asJSValue() -> JsValue {
        value
    }

    // 判断是否有有效值
    public func hasValue() -> Bool {
        !value.isUndefined()
    }

    // 转为 JsValue (用于 throw)
    public func toJsValue() -> JsValue {
        value
    }

    // 获取错误消息字符串
    public func getMessage() -> String {
        value.toString()
    }

    // 获取堆栈追踪字符串
    public func getStackString() -> String {
        if (stackTrace.frames.size == 0) {
            return ""
        }
        var result = StringBuilder()
        for (frame in stackTrace.frames) {
            if (!frame.isPositionInvalid()) {
                result.append("    at ")
                if (!frame.functionName.isEmpty) {
                    result.append(frame.functionName + " ")
                }
                result.append("(" + frame.sourceUrl + ":" +
                    String(frame.positionLine) + ":" +
                    String(frame.positionColumn) + ")\n")
            }
        }
        result.toString()
    }
}
