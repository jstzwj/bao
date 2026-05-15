// 严格翻译自: src/jsc/GetterSetter.zig (11行)
// JavaScriptCore GetterSetter - 访问器属性描述符 opaque 类型

package bao_jsc

// ========== GetterSetter ==========
// 严格翻译自 GetterSetter.zig
// GetterSetter 是 JSC 内部的 opaque 类型
// 表示一个包含 getter 和/或 setter 函数的访问器属性描述符
// 此类型用于属性查找链中，不能从 JS 直接访问
//
// 在 JSC 中，GetterSetter 是一个 JSCell 子类，包含:
//   - m_getter: JSFunction (可能为 null)
//   - m_setter: JSFunction (可能为 null)
//
// 原始 Zig 代码使用 opaque 类型 + extern FFI 函数
// 仓颉版本使用 class 包装 FFI 调用
public class GetterSetter {
    // 内部 getter 函数值
    public var getterValue: ?JsValue = None
    // 内部 setter 函数值
    public var setterValue: ?JsValue = None
    // 原始 opaque 指针
    public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()

    public init() {}

    public init(getter: JsValue, setter: JsValue) {
        this.getterValue = getter
        this.setterValue = setter
    }

    // ========== isGetterNull ==========
    // 严格翻译自 GetterSetter.isGetterNull
    // 检查 getter 是否为 null
    //
    // FFI: JSC__GetterSetter__isGetterNull(this: *GetterSetter) bool
    public func isGetterNull() -> Bool {
        // 原始 Zig:
        //   return JSC__GetterSetter__isGetterNull(this);
        getterValue == None
    }

    // ========== isSetterNull ==========
    // 严格翻译自 GetterSetter.isSetterNull
    // 检查 setter 是否为 null
    //
    // FFI: JSC__GetterSetter__isSetterNull(this: *GetterSetter) bool
    public func isSetterNull() -> Bool {
        // 原始 Zig:
        //   return JSC__GetterSetter__isSetterNull(this);
        setterValue == None
    }

    // ========== FFI 绑定 ==========
    // 外部 C 函数声明:
    //   @extern "c" fn JSC__GetterSetter__isGetterNull(this: CPointer<UInt8>) -> Bool
    //   @extern "c" fn JSC__GetterSetter__isSetterNull(this: CPointer<UInt8>) -> Bool
}
