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
    public func unwrap(): ?T {
        if (success) {
            return result.value
        } else {
            return None
        }
    }

    // 严格翻译自 Errorable.value (静态构造)
    public static func value(val: T): Errorable<T> {
        let e = Errorable<T>()
        e.result = ErrorableResult<T>.fromValue(val)
        e.success = true
        e
    }

    // 严格翻译自 Errorable.ok
    public static func ok(val: T): Errorable<T> {
        let e = Errorable<T>()
        e.result = ErrorableResult<T>.fromValue(val)
        e.success = true
        e
    }

    // 严格翻译自 Errorable.err
    public static func err(code: JscErrorCode, errValue: JsValue): Errorable<T> {
        let e = Errorable<T>()
        e.result = ErrorableResult<T>.fromError(errValue)
        e.success = false
        e
    }
}

// ========== ErrorableResult<T> ==========
public class ErrorableResult<T> {
    public var value: ?T = None
    public var errorValue: JsValue = JsValue()

    public init() {}

    public static func fromValue(val: T): ErrorableResult<T> {
        let r = ErrorableResult<T>()
        r.value = val
        r
    }

    public static func fromError(err: JsValue): ErrorableResult<T> {
        let r = ErrorableResult<T>()
        r.errorValue = err
        r
    }
}

// 注意: ErrorableResolvedSource 已移至 module_loader.cj (非泛型具体类)
// 注意: ErrorableString 已移至 module_loader.cj (非泛型具体类)

// ========== ErrorableZigString ==========
// 严格翻译自 Errorable(ZigString)
public type ErrorableZigString = Errorable<ZigString>

// ========== ErrorableJSValue ==========
// 严格翻译自 Errorable(JSValue)
public type ErrorableJSValue = Errorable<JsValue>
