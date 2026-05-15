// 严格翻译自: src/jsc/ZigErrorType.zig (7行)
// Zig 错误类型包装

package bao_jsc

// ========== ZigErrorType ==========
// 严格翻译自 ZigErrorType.zig
// ZigErrorType 是一个包含错误码和 JSValue 的结构体
// 在 Bun 中用于表示 Zig 错误到 JS 错误的映射
public class ZigErrorType {
    // 错误码
    public var code: ErrorCode = ErrorCode(0)
    // 对应的 JS 值
    public var value: JsValue = JsValue.undefined()

    public init() {}

    public init(code: ErrorCode, value: JsValue) {
        this.code = code
        this.value = value
    }

    // 从错误码创建
    public static func fromCode(code: ErrorCode) -> ZigErrorType {
        ZigErrorType(code: code, value: JsValue.undefined())
    }

    // 从错误码和值创建
    public static func fromCodeAndValue(code: ErrorCode, value: JsValue) -> ZigErrorType {
        ZigErrorType(code: code, value: value)
    }

    // 转为错误
    public func toError() -> Exception {
        Exception(code.toString())
    }
}
