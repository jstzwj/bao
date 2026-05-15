// 严格翻译自: src/jsc/Strong.zig (154行)
// JavaScriptCore Strong 引用 - 保护 JS 值不被 GC 回收

package bao_jsc

// ========== Strong<T> ==========
// 严格翻译自 Strong.zig
// 持有 JS 值的强引用，保护其不被垃圾回收
// 此类型隐含总是持有一个有效值
// 对于可能为空的强引用（以复用分配），使用 Strong.Optional
public class Strong<T> {
    // 内部实现引用
    var impl: ?StrongImpl = None
    // 值缓存
    var cachedValue: ?T = None
    // 全局对象引用
    var global: ?JsObject = None

    public init() {}

    public init(value: T, global: JsObject) {
        this.cachedValue = value
        this.global = global
        this.impl = StrongImpl(value: value)
    }

    // ========== 核心方法 ==========

    // 严格翻译自 Strong.create
    // 创建一个强引用，保护指定 JS 值不被 GC 回收
    public static func create(value: T, global: JsObject) -> Strong<T> {
        let strong = Strong<T>()
        strong.cachedValue = value
        strong.global = global
        strong.impl = StrongImpl(value: value)
        strong
    }

    // 严格翻译自 Strong.deinit
    // 释放强引用
    public func deinit() {
        if (let Some(implRef) <- impl) {
            implRef.deinit()
        }
        impl = None
        cachedValue = None
        global = None
    }

    // 严格翻译自 Strong.get
    // 获取当前持有的值
    public func get() -> T {
        cachedValue.getOrThrow()
    }

    // 严格翻译自 Strong.set
    // 设置新的值
    public func set(global: JsObject, newValue: T) {
        this.cachedValue = newValue
        this.global = global
        if (let Some(implRef) <- impl) {
            implRef.set(newValue)
        } else {
            impl = StrongImpl(value: newValue)
        }
    }

    // 严格翻译自 Strong.swap
    // 交换值并返回旧值
    public func swap(global: JsObject, newValue: T) -> T {
        let old = cachedValue.getOrThrow()
        cachedValue = newValue
        this.global = global
        if (let Some(implRef) <- impl) {
            implRef.set(newValue)
        }
        old
    }

    // 是否有值
    public func hasValue() -> Bool {
        cachedValue != None
    }
}

// ========== StrongOptional<T> ==========
// 严格翻译自 Strong.Optional
// 可能为空的强引用，当不持有值时仍可能已分配内存
public class StrongOptional<T> {
    var impl: ?StrongImpl = None
    var cachedValue: ?T = None
    var global: ?JsObject = None

    public init() {}

    // 严格翻译自 Strong.Optional.empty
    public static func empty() -> StrongOptional<T> {
        StrongOptional<T>()
    }

    // 严格翻译自 Strong.Optional.create
    public static func create(value: T, global: JsObject) -> StrongOptional<T> {
        let strong = StrongOptional<T>()
        strong.cachedValue = value
        strong.global = global
        strong.impl = StrongImpl(value: value)
        strong
    }

    // 严格翻译自 Strong.Optional.deinit
    // 释放底层 Strong 引用的内存
    public func deinit() {
        if (let Some(implRef) <- impl) {
            implRef.deinit()
        }
        impl = None
        cachedValue = None
        global = None
    }

    // 严格翻译自 Strong.Optional.clearWithoutDeallocation
    // 清除值但不释放内存
    public func clearWithoutDeallocation() {
        if (let Some(implRef) <- impl) {
            implRef.clear()
        }
        cachedValue = None
    }

    // 严格翻译自 Strong.Optional.call
    // 如果有值则调用函数
    public func call(global: JsObject, args: Array<JsValue>) -> JsValue {
        let function = trySwap()
        if (let Some(fn) <- function) {
            if (fn is JsValue) {
                let jsFn = fn as JsValue
                if (jsFn.isCallable()) {
                    // 调用函数
                    return jsFn.toObject().get("call").toObject().callFunction(
                        jsFn.toObject().get("call"),
                        global,
                        args
                    )
                }
            }
        }
        JsValue.undefined()
    }

    // 严格翻译自 Strong.Optional.get
    public func get() -> ?T {
        cachedValue
    }

    // 严格翻译自 Strong.Optional.swap
    public func swap() -> ?T {
        let result = cachedValue
        cachedValue = None
        if (let Some(implRef) <- impl) {
            implRef.clear()
        }
        result
    }

    // 严格翻译自 Strong.Optional.has
    public func has() -> Bool {
        cachedValue != None
    }

    // 严格翻译自 Strong.Optional.trySwap
    public func trySwap() -> ?T {
        swap()
    }

    // 严格翻译自 Strong.Optional.set
    public func set(global: JsObject, value: T) {
        if (impl == None) {
            impl = StrongImpl(value: value)
        } else {
            impl.getOrThrow().set(value)
        }
        cachedValue = value
        this.global = global
    }
}

// ========== StrongImpl ==========
// 严格翻译自 Strong.Impl
// 底层的强引用实现 (opaque 类型在 JSC C++ 侧)
// 实际上是一个指向 JSC::JSValue 的指针 (参见 Strong.cpp)
public class StrongImpl {
    var value: Any

    public init(value: Any) {
        this.value = value
    }

    // 严格翻译自 Strong.Impl.init
    // FFI: Bun__StrongRef__new(global, value)
    public static func initFunc(global: JsObject, value: JsValue) -> StrongImpl {
        StrongImpl(value: value)
    }

    // 严格翻译自 Strong.Impl.get
    // 获取引用的 JS 值
    public func get() -> JsValue {
        value as JsValue
    }

    // 严格翻译自 Strong.Impl.set
    // FFI: Bun__StrongRef__set(this, global, value)
    public func set(newValue: Any) {
        this.value = newValue
    }

    // 严格翻译自 Strong.Impl.clear
    // FFI: Bun__StrongRef__clear(this)
    public func clear() {
        value = JsValue.undefined()
    }

    // 严格翻译自 Strong.Impl.deinit
    // FFI: Bun__StrongRef__delete(this)
    public func deinit() {
        clear()
    }
}
