// 严格翻译自: src/jsc/static_export.zig (34行)
// 回调函数包装器

package bao_jsc

// ========== CallbackGetterFn / CallbackSetterFn ==========
// 严格翻译自 static_export.zig
// Getter 回调函数类型: 接收一个 JsValue 容器，返回一个 JsValue
public type CallbackGetterFn = (JsValue) -> JsValue

// Setter 回调函数类型: 接收容器 JsValue 和值 JsValue，无返回
public type CallbackSetterFn = (JsValue, JsValue) -> Unit

// ========== CallbackWrapper ==========
// 严格翻译自 static_export.zig CallbackWrapper
// 用于包装 getter/setter 回调函数的泛型结构体
public class CallbackWrapper {
    public var container: JsValue
    private var getter: CallbackGetterFn
    private var setter: CallbackSetterFn

    public init(container: JsValue, getter: CallbackGetterFn, setter: CallbackSetterFn) {
        this.container = container
        this.getter = getter
        this.setter = setter
    }

    // 严格翻译自 get
    // 调用 getter 回调函数获取值
    // 如果结果为空/undefined/null，返回 None
    public func get(): ?JsValue {
        let res = getter(container)
        if (res.isEmptyOrUndefinedOrNull()) {
            return None
        }
        res
    }

    // 严格翻译自 set
    // 调用 setter 回调函数设置值
    public func set(value: JsValue) {
        setter(container, value)
    }

    // 严格翻译自 call
    // 获取回调函数并在全局对象上调用它
    public func call(globalObject: JsGlobalObject, args: Array<JsValue>): ?JsValue {
        if (let Some(callback) <- get()) {
            return callWithThis(globalObject, callback, args)
        }
        None
    }

    // 严格翻译自 callWithThis
    // 通过 JSC C API 调用函数，绑定 this 为 container
    public func callWithThis(globalObject: JsGlobalObject, fn: JsValue, args: Array<JsValue>): ?JsValue {
        let ctx = globalObject.globalThis.rawPtr
        let fnObj = fn.asRawPointer()
        let thisObj = container.asRawPointer()

        // 准备参数
        let argCount = UInt64(args.size)
        var argPtrs = Array<CPointer<UInt8>>()
        for (arg in args) {
            argPtrs.append(arg.asRawPointer())
        }

        var exception: CPointer<UInt8> = CPointer<UInt8>()
        let resultPtr = unsafe {
            JSObjectCallAsFunction(
                ctx,
                fnObj,
                thisObj,
                argCount,
                CPointer<CPointer<UInt8>>(),
                CPointer<CPointer<UInt8>>()
            )
        }

        if (!exception.isNull()) {
            return None
        }
        if (resultPtr.isNull()) {
            return None
        }
        Some(JsValue.fromRawPointer(resultPtr))
    }
}
