// 严格翻译自: src/jsc/ErrorCode.zig (24行)
// Zig 错误码类型

package bao_jsc

// ========== ErrorCode ==========
// 严格翻译自 ErrorCode.zig ErrorCode
// 错误码类型，使用 UInt16 表示
// 支持从 anyerror 转换和到 anyerror 的转换
public class ErrorCode {
    // 内部错误码值
    public var value: UInt16

    public init(_ value: UInt16) {
        this.value = value
    }

    public init() {
        this.value = 0
    }

    // 严格翻译自 ErrorCode.from
    // 从错误码整数创建
    public static func from(code: Int64) -> ErrorCode {
        ErrorCode(UInt16(code % 65536))
    }

    // 严格翻译自 ErrorCode.toError
    // 转为错误类型
    public func toError() -> Exception {
        Exception(this.toString())
    }

    // 获取整数值
    public func toInt() -> Int64 {
        Int64(value)
    }

    // 严格翻译自 ErrorCode.ParserError
    // 解析器错误常量
    public static func parserError() -> ErrorCode {
        ErrorCode(UInt16(1))
    }

    // 严格翻译自 ErrorCode.JSErrorObject
    // JS 错误对象常量
    public static func jsErrorObject() -> ErrorCode {
        ErrorCode(UInt16(2))
    }

    // 错误码类型别名
    // 严格翻译自 ErrorCode.Type
    public typealias CodeInt = UInt16

    // 判断是否相等
    public func equals(other: ErrorCode) -> Bool {
        value == other.value
    }

    // 转为字符串表示
    public func toString() -> String {
        match (value) {
            case 0 => "NoError"
            case 1 => "ParserError"
            case 2 => "JSErrorObject"
            case _ => "ErrorCode(" + String(Int64(value)) + ")"
        }
    }
}
