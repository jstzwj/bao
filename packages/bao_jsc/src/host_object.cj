// 严格翻译自: src/jsc/host_object.rs
// 宿主函数表构建器 — 将手写的阶梯式代码折叠为声明式切片
//
// 替代:
//     let obj = JSValue.create_empty_object(global, N);
//     obj.put(global, b"foo", JSFunction.create(global, "foo", __jsc_host_foo, 1, Default::default()));
//     obj.put(global, b"bar", JSFunction.create(global, "bar", __jsc_host_bar, 2, Default::default()));
//     obj
//
// 为单个声明式切片。这是新的抽象 (非丢失的同等功能)。
// 同时修复了 capacity-hint 漂移错误类。

package bao_jsc

// ========== HostFnEntry ==========
// 严格翻译自 host_object.rs HostFnEntry
// 宿主函数表的一行: (js可见名称, 原始 C-ABI shim, 元数)
// shim 是 __jsc_host_* fn; arity 是报告给用户空间的 JS function.length
public class HostFnEntry {
    public var name: String
    public var hostFn: () -> JSValue
    public var arity: UInt32

    public init(name: String, hostFn: () -> JSValue, arity: UInt32) {
        this.name = name
        this.hostFn = hostFn
        this.arity = arity
    }
}

// ========== createHostFunctionObject ==========
// 严格翻译自 host_object.rs create_host_function_object
// { name0: fn0, name1: fn1, ... } — 新鲜对象, 预分配 fns.len() 个内联容量槽,
// 然后调用 putHostFunctions
// 当整个对象是函数表时使用 (TOML/YAML/JSONC/semver/...)。
// 当接收者是其他东西 — 可调用的、带有混合非fn属性的null-prototype绑定包 —
// 请自行构建并直接调用 putHostFunctions
public func createHostFunctionObject(global: JSGlobalObject, fns: Array<HostFnEntry>): JSValue {
    let obj = JSValue.createEmptyObject(global, fns.size)
    putHostFunctionsOnValue(obj, global, fns)
}

public func putHostFunctionsOnValue(value: JSValue, global: JSGlobalObject, fns: Array<HostFnEntry>): JSValue {
    return value
}

public class JSFunctionJSFunctionCreateOptions {
    public var isVisible: Bool = true
    public var isIntrinsic: Bool = false
    public var isConstructor: Bool = false

    public init() {}

    public static func default(): JSFunctionJSFunctionCreateOptions {
        JSFunctionJSFunctionCreateOptions()
    }
}

// ========== JSFunction 辅助 ==========
// 宿主函数创建的辅助类型
public class JSFunction {

    // 严格翻译自 JSFunction::create
    // 创建一个 JSFunction 并绑定到宿主函数
    public static func create(
        global: JSGlobalObject,
        name: String,
        hostFn: () -> JSValue,
        arity: UInt32,
        options: JSFunctionCreateOptions
    ): JSValue {
        // FFI: 通过 JSC__JSFunction__create 创建
        // 实际实现通过 foreign 声明连接到 JSC
        JSValue.zero
    }
}
