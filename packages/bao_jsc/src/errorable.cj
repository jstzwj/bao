// 严格翻译自: src/jsc/Errorable.zig
// 可错误的结果类型 - 包装成功值或错误

package bao_jsc

// ========== Errorable<T> ==========
// 严格翻译自 Errorable(Type)
// 表示一个可能成功或失败的结果
public class Errorable<T> {
    public var result: ErrorableResult<T> = ErrorableResult<T>()
    public var success: Bool = false

    public init() {}

    // 严格翻译自 Errorable.unwrap
    public func unwrap() -> ?T {
        if (success) {
            return result.value
        } else {
            return None
        }
    }

    // 严格翻译自 Errorable.value (静态构造)
    public static func value(_ val: T) -> Errorable<T> {
        let e = Errorable<T>()
        e.result = ErrorableResult<T>.fromValue(val)
        e.success = true
        e
    }

    // 严格翻译自 Errorable.ok
    public static func ok(_ val: T) -> Errorable<T> {
        let e = Errorable<T>()
        e.result = ErrorableResult<T>.fromValue(val)
        e.success = true
        e
    }

    // 严格翻译自 Errorable.err
    public static func err(code: ErrorCode_, errValue: JsValue) -> Errorable<T> {
        let e = Errorable<T>()
        e.result = ErrorableResult<T>.fromError(errValue)
        e.success = false
        e
    }
}

// ========== ErrorableResult<T> ==========
public class ErrorableResult<T> {
    public var value: ?T = None
    public var errorValue: JsValue = JsValue.zero

    public init() {}

    public static func fromValue(_ val: T) -> ErrorableResult<T> {
        let r = ErrorableResult<T>()
        r.value = val
        r
    }

    public static func fromError(_ err: JsValue) -> ErrorableResult<T> {
        let r = ErrorableResult<T>()
        r.errorValue = err
        r
    }
}

// ========== ErrorableResolvedSource ==========
// 严格翻译自 Errorable(ResolvedSource)
public typealias ErrorableResolvedSource = Errorable<ResolvedSource_>

// ========== ErrorableZigString ==========
// 严格翻译自 Errorable(ZigString)
public typealias ErrorableZigString = Errorable<ZigString>

// ========== ErrorableJSValue ==========
// 严格翻译自 Errorable(JSValue)
public typealias ErrorableJSValue = Errorable<JsValue>

// ========== ErrorableString ==========
// 严格翻译自 Errorable(bun.String)
public typealias ErrorableString = Errorable<String>
