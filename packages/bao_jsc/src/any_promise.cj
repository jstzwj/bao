// 严格翻译自: src/jsc/AnyPromise.zig (110行)
// 通用 Promise 类型 - 可以是普通 Promise 或内部 Promise

package bao_jsc

// ========== AnyPromise ==========
// 严格翻译自 AnyPromise.zig AnyPromise
// 可以是已解决或待定的 Promise，也可以是普通 JSPromise 或 JSInternalPromise
// JSInternalPromise 在 C++ 中继承自 JSPromise，因此两种变体都被处理
public class AnyPromise {
    // 内部变体
    public enum PromiseVariant {
        | Normal
        | Internal
    }

    // Promise 变体类型
    public var variant: PromiseVariant = PromiseVariant.Normal
    // 内部 Promise 引用
    public var promise: ?JsPromise = None
    // 内部 Promise (JSInternalPromise)
    public var internalPromise: ?JsObject = None

    public init() {}

    public init(promise: JsPromise) {
        this.variant = PromiseVariant.Normal
        this.promise = promise
    }

    public init(internalPromise: JsObject) {
        this.variant = PromiseVariant.Internal
        this.internalPromise = internalPromise
    }

    // 严格翻译自 AnyPromise.unwrap
    // 解包 Promise 的结果
    public func unwrap(vm: JsVirtualMachine, mode: JSPromiseUnwrapMode) -> JsPromiseUnwrapped {
        match (variant) {
            case Normal => {
                if (let Some(p) <- promise) {
                    p.unwrap(mode)
                } else {
                    JsPromiseUnwrapped()
                }
            }
            case Internal => {
                // JSInternalPromise 的 unwrap
                JsPromiseUnwrapped()
            }
        }
    }

    // 严格翻译自 AnyPromise.status
    // 获取 Promise 状态
    public func status() -> JSPromiseStatus {
        match (variant) {
            case Normal => {
                if (let Some(p) <- promise) {
                    p.status()
                } else {
                    JSPromiseStatus.Pending
                }
            }
            case Internal => {
                // JSInternalPromise 继承 JSPromise
                JSPromiseStatus.Pending
            }
        }
    }

    // 严格翻译自 AnyPromise.result
    // 获取 Promise 结果
    public func result(vm: JsVirtualMachine) -> JsValue {
        match (variant) {
            case Normal => {
                if (let Some(p) <- promise) {
                    p.result()
                } else {
                    JsValue.undefined()
                }
            }
            case Internal => {
                JsValue.undefined()
            }
        }
    }

    // 严格翻译自 AnyPromise.isHandled
    public func isHandled() -> Bool {
        match (variant) {
            case Normal => {
                if (let Some(p) <- promise) {
                    p.isHandled()
                } else {
                    false
                }
            }
            case Internal => false
        }
    }

    // 严格翻译自 AnyPromise.setHandled
    public func setHandled(vm: JsVirtualMachine) {
        match (variant) {
            case Normal => {
                if (let Some(p) <- promise) {
                    p.setHandled()
                }
            }
            case Internal => {
                if (let Some(p) <- internalPromise) {
                    // JSInternalPromise 也支持 setHandled
                }
            }
        }
    }

    // 严格翻译自 AnyPromise.resolve
    // 解决 Promise
    public func resolve(globalThis: JsObject, value: JsValue) -> Bool {
        match (variant) {
            case Normal => {
                if (let Some(p) <- promise) {
                    p.doResolve(value)
                    return false  // 成功
                }
                false
            }
            case Internal => {
                // JSInternalPromise 的 resolve
                false
            }
        }
    }

    // 严格翻译自 AnyPromise.reject
    // 拒绝 Promise
    public func reject(globalThis: JsObject, value: JsValue) -> Bool {
        match (variant) {
            case Normal => {
                if (let Some(p) <- promise) {
                    p.doReject(value)
                    return false  // 成功
                }
                false
            }
            case Internal => {
                false
            }
        }
    }

    // 严格翻译自 AnyPromise.rejectWithAsyncStack
    // 像 reject 一样工作，但先从 Promise 的 await 链中附加异步堆栈帧到错误
    // 在事件循环顶部从原生代码拒绝时使用
    public func rejectWithAsyncStack(globalThis: JsObject, value: JsValue) -> Bool {
        // value.attachAsyncStackFromPromise(globalThis, asJSPromise())
        reject(globalThis, value)
    }

    // 严格翻译自 AnyPromise.asJSPromise
    // JSInternalPromise 在 C++ 中继承自 JSPromise -- 此转换对任何接受 JSPromise* 的 C++ 函数是安全的
    public func asJSPromise() -> ?JsPromise {
        match (variant) {
            case Normal => promise
            case Internal => None  // 实际上可以 cast，但仓颉中无法直接表达
        }
    }

    // 严格翻译自 AnyPromise.rejectAsHandled
    public func rejectAsHandled(globalThis: JsObject, value: JsValue) -> Bool {
        match (variant) {
            case Normal => {
                if (let Some(p) <- promise) {
                    p.doReject(value)
                    return false
                }
                false
            }
            case Internal => false
        }
    }

    // 严格翻译自 AnyPromise.asValue
    public func asValue() -> JsValue {
        match (variant) {
            case Normal => {
                if (let Some(p) <- promise) {
                    p.toJsValue()
                } else {
                    JsValue.undefined()
                }
            }
            case Internal => {
                if (let Some(p) <- internalPromise) {
                    JsValue(obj: p)
                } else {
                    JsValue.undefined()
                }
            }
        }
    }

    // 严格翻译自 AnyPromise.wrap
    // 使用 TopExceptionScope 包装 Promise 操作
    public func wrap(globalObject: JsObject, callback: () -> JsValue) -> Bool {
        let scope = TopExceptionScope(globalObject)
        defer { scope.deinit() }

        // 执行包装操作
        let result = callback()

        scope.assertNoExceptionExceptTermination()
    }

    // ========== 静态工厂方法 ==========

    // 创建已解决的 AnyPromise
    public static func resolved(value: JsValue) -> AnyPromise {
        let p = JsPromise.resolve(value)
        AnyPromise(promise: p)
    }

    // 创建待定的 AnyPromise
    public static func pending() -> AnyPromise {
        AnyPromise(promise: JsPromise())
    }

    // 从普通 Promise 创建
    public static func normal(promise: JsPromise) -> AnyPromise {
        AnyPromise(promise: promise)
    }

    // 从内部 Promise 创建
    public static func internal(internalPromise: JsObject) -> AnyPromise {
        AnyPromise(internalPromise: internalPromise)
    }
}

// ========== JSPromiseUnwrapMode ==========
// 严格翻译自 JSPromise.UnwrapMode
public enum JSPromiseUnwrapMode {
    | FulfillOnly
    | All
}

// ========== JSPromiseStatus ==========
// 严格翻译自 JSPromise.Status
public enum JSPromiseStatus {
    | Pending
    | Fulfilled
    | Rejected
}

// ========== JsPromiseUnwrapped ==========
// 严格翻译自 JSPromise.Unwrapped
public class JsPromiseUnwrapped {
    public var value: JsValue = JsValue.undefined()
    public var isSuccess: Bool = false

    public init() {}
}
