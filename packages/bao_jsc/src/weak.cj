// 严格翻译自: src/jsc/Weak.zig (116行)
// JavaScriptCore Weak 引用绑定

package bao_jsc

// ========== WeakRefType ==========
// 严格翻译自 Weak.zig WeakRefType
// 弱引用的类型标记，用于区分不同来源的弱引用
public enum WeakRefType {
    | None
}

// ========== WeakImpl ==========
// 严格翻译自 Weak.zig WeakImpl (内部 opaque)
// 底层弱引用实现
class WeakImpl {
    var value: ?JsValue = None
    var refType: WeakRefType = WeakRefType.None
    var ctx: ?Any = None

    init(value: JsValue, refType: WeakRefType, ctx: ?Any) {
        this.value = value
        this.refType = refType
        this.ctx = ctx
    }

    // 严格翻译自 WeakImpl.init
    // FFI: Bun__WeakRef__new(globalThis, value, refType, ctx)
    static func initFunc(globalThis: JsObject, value: JsValue, refType: WeakRefType, ctx: ?Any): WeakImpl {
        let impl = WeakImpl(value, refType, ctx)
        impl
    }

    // 严格翻译自 WeakImpl.get
    // FFI: Bun__WeakRef__get(this)
    func get(): JsValue {
        if (value.isSome()) {
            value.getOrThrow()
        } else {
            JsValue.undefined()
        }
    }

    // 严格翻译自 WeakImpl.clear
    // FFI: Bun__WeakRef__clear(this)
    func clear() {
        value = None
    }

    // 严格翻译自 WeakImpl.deinit
    // FFI: Bun__WeakRef__delete(this)
    func deinit() {
        value = None
        ctx = None
    }
}

// ========== Weak<T> ==========
// 严格翻译自 Weak.zig Weak(comptime T: type) type
// JS 值的弱引用
// 当 GC 回收目标值后，get() 将返回 None
public class Weak<T> {
    // 内部弱引用实现
    var ref: ?WeakImpl = None
    // 关联的全局对象
    var globalThis: ?JsObject = None

    public init() {}

    // 严格翻译自 Weak.init
    public static func initFunc(): Weak<T> {
        Weak<T>()
    }

    // 严格翻译自 Weak.create
    // 创建弱引用
    public static func create(
        value: JsValue,
        globalThis: JsObject,
        refType: WeakRefType,
        ctx: T
    ): Weak<T> {
        let weak = Weak<T>()
        if (value != JsValue.undefined()) {
            weak.ref = WeakImpl(value, refType, ctx)
            weak.globalThis = globalThis
        }
        weak
    }

    // ========== 值访问 ==========

    // 严格翻译自 Weak.call
    // 如果有值，调用关联的函数
    public func call(args: Array<JsValue>): JsValue {
        let function = trySwap()
        if (function.isSome()) {
            return function.getOrThrow()
        }
        JsValue.undefined()
    }

    // 严格翻译自 Weak.get
    // 获取引用的值，如果已被 GC 回收则返回 None
    public func get(): ?JsValue {
        let refImpl = ref
        if (refImpl.isNone()) {
            return None
        }
        let result = refImpl.getOrThrow().get()
        if (result == JsValue.undefined()) {
            return None
        }
        result
    }

    // 严格翻译自 Weak.swap
    // 获取并清除引用
    public func swap(): JsValue {
        let refImpl = ref
        if (refImpl.isNone()) {
            return JsValue.undefined()
        }
        let result = refImpl.getOrThrow().get()
        refImpl.getOrThrow().clear()
        result
    }

    // 严格翻译自 Weak.has
    // 检查引用是否仍然有效
    public func has(): Bool {
        let refImpl = ref
        if (refImpl.isNone()) {
            return false
        }
        refImpl.getOrThrow().get() != JsValue.undefined()
    }

    // 严格翻译自 Weak.trySwap
    // 尝试获取并清除引用
    public func trySwap(): ?JsValue {
        let result = swap()
        if (result == JsValue.undefined()) {
            return None
        }
        result
    }

    // 严格翻译自 Weak.clear
    // 清除引用但不释放
    public func clear() {
        let refImpl = ref
        if (refImpl.isNone()) {
            return
        }
        refImpl.getOrThrow().clear()
    }

    // 严格翻译自 Weak.deinit
    // 释放弱引用
    public func deinit() {
        let refImpl = ref
        if (refImpl.isNone()) {
            return
        }
        ref = None
        refImpl.getOrThrow().deinit()
    }
}
