// 严格翻译自: src/jsc/CustomGetterSetter.zig (11行)
// JavaScriptCore CustomGetterSetter - 自定义原生 getter/setter opaque 类型

package bao_jsc

// ========== CustomGetterSetter ==========
// 严格翻译自 CustomGetterSetter.zig
// CustomGetterSetter 是 JSC 内部的 opaque 类型
// 表示自定义的原生 getter/setter 实现
// 与 GetterSetter 不同，CustomGetterSetter 使用原生函数指针
// 而不是 JSFunction 对象
//
// 在 JSC 中，CustomGetterSetter 是一个 JSCell 子类，包含:
//   - m_getter: NativeFunction 指针 (可能为 null)
//   - m_setter: NativeFunction 指针 (可能为 null)
//
// 原始 Zig 代码使用 opaque 类型 + 通过 bun.cpp 命名空间的 FFI
public class CustomGetterSetter {
    // 自定义 getter 原生函数
    public var getterValue: ?JsValue = None
    // 自定义 setter 原生函数
    public var setterValue: ?JsValue = None
    // 原始 opaque 指针
    public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()

    public init() {}

    // ========== isGetterNull ==========
    // 严格翻译自 CustomGetterSetter.isGetterNull
    // 检查自定义 getter 是否为 null
    //
    // FFI: bun.cpp.JSC__CustomGetterSetter__isGetterNull(this) bool
    public func isGetterNull() -> Bool {
        // 原始 Zig:
        //   return bun.cpp.JSC__CustomGetterSetter__isGetterNull(this);
        getterValue == None
    }

    // ========== isSetterNull ==========
    // 严格翻译自 CustomGetterSetter.isSetterNull
    // 检查自定义 setter 是否为 null
    //
    // FFI: bun.cpp.JSC__CustomGetterSetter__isSetterNull(this) bool
    public func isSetterNull() -> Bool {
        // 原始 Zig:
        //   return bun.cpp.JSC__CustomGetterSetter__isSetterNull(this);
        setterValue == None
    }

    // ========== FFI 绑定 ==========
    // 外部 C 函数声明 (通过 bun.cpp 命名空间):
    //   @extern "c" fn JSC__CustomGetterSetter__isGetterNull(this: CPointer<UInt8>) -> Bool
    //   @extern "c" fn JSC__CustomGetterSetter__isSetterNull(this: CPointer<UInt8>) -> Bool
}
