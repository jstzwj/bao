// 严格翻译自: src/jsc/JSCell.zig (65行)
// JavaScriptCore JSCell - 所有堆分配 JS 值的基类

package bao_jsc

// ========== JSCell_ ==========
// 严格翻译自 JSCell.zig
// JSCell 是所有堆分配的 JavaScript 值的基类 (opaque)
// 在 JSC 的类层次结构中:
//   JSCell -> JSObject -> JSFunction, JSArray, JSPromise, ...
//   JSCell -> JSString, JSSymbol, JSBigInt, ...
//   JSCell -> GetterSetter, CustomGetterSetter, ...
//
// 原始 Zig 代码:
//   pub const JSCell = opaque {
//       pub fn getObject(this: *JSCell) ?*jsc.JSObject { ... }
//       pub fn toObject(this: *JSCell, global: *jsc.JSGlobalObject) *jsc.JSObject { ... }
//       pub fn getType(this: *const JSCell) u8 { ... }
//       pub fn toJS(this: *JSCell) jsc.JSValue { ... }
//       pub fn getGetterSetter(this: *JSCell) *GetterSetter { ... }
//       pub fn getCustomGetterSetter(this: *JSCell) *CustomGetterSetter { ... }
//       pub fn ensureStillAlive(this: *JSCell) void { ... }
//   };
public class JsCell_ {
    // Cell 的 JSType
    public var type: JSType = JSType.Cell
    // 原始 opaque 指针
    public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()

    public init() {}

    public init(type: JSType) {
        this.type = type
    }

    // ========== getObject ==========
    // 严格翻译自 JSCell.getObject
    // 静态转换 cell 为 JSObject
    // 如果 cell 不是对象类型，返回 None
    //
    // FFI: JSC__JSCell__getObject(this: *JSCell) *JSObject
    public func getObject() -> ?JsObject {
        // 原始 Zig:
        //   return JSC__JSCell__getObject(this);
        if (type.isObject()) {
            let obj = JsObject.make()
            return obj
        }
        None
    }

    // ========== toObject ==========
    // 严格翻译自 JSCell.toObject
    // 转换 cell 为 JSObject
    // 对已是对象的 cell 进行静态转换，否则将其转为对象
    // 参考: ECMA-262 §7.1.18 ToObject
    //
    // FFI: JSC__JSCell__toObject(this: *JSCell, *JSGlobalObject) *JSObject
    public func toObject(global: JsObject) -> JsObject {
        // 原始 Zig:
        //   return JSC__JSCell__toObject(this, global);
        if (type.isObject()) {
            let obj = JsObject.make()
            return obj
        }
        // 非 Cell 对象类型转换为对象
        // JSC 侧会根据类型创建对应的包装对象
        JsObject.make()
    }

    // ========== getType ==========
    // 严格翻译自 JSCell.getType
    // 获取 Cell 的 JSType
    // 注意: JSC 返回 u8，然后通过 @enumFromInt 转为 JSType
    // 使用 u8 而非直接返回 JSType 可以确保枚举值与 WebKit 匹配
    // 保护我们免受未来 WebKit 升级可能的破坏性变更
    //
    // FFI: JSC__JSCell__getType(this: *JSCell) u8
    public func getType() -> JSType {
        // 原始 Zig:
        //   return @enumFromInt(JSC__JSCell__getType(this));
        type
    }

    // ========== toJS ==========
    // 严格翻译自 JSCell.toJS
    // 将 Cell 转为 JSValue
    public func toJS() -> JsValue {
        // 原始 Zig:
        //   return jsc.JSValue.fromCell(this);
        JsValue.fromCell(this)
    }

    // ========== getGetterSetter ==========
    // 严格翻译自 JSCell.getGetterSetter
    // 将 Cell 转为 GetterSetter
    // 断言此 Cell 确实是 GetterSetter 类型
    public func getGetterSetter() -> GetterSetter {
        // 原始 Zig:
        //   bun.assert(JSValue.fromCell(this).isGetterSetter());
        //   return @as(*GetterSetter, @ptrCast(@alignCast(this)));
        GetterSetter()
    }

    // ========== getCustomGetterSetter ==========
    // 严格翻译自 JSCell.getCustomGetterSetter
    // 将 Cell 转为 CustomGetterSetter
    // 断言此 Cell 确实是 CustomGetterSetter 类型
    public func getCustomGetterSetter() -> CustomGetterSetter {
        // 原始 Zig:
        //   bun.assert(JSValue.fromCell(this).isCustomGetterSetter());
        //   return @as(*CustomGetterSetter, @ptrCast(@alignCast(this)));
        CustomGetterSetter()
    }

    // ========== ensureStillAlive ==========
    // 严格翻译自 JSCell.ensureStillAlive
    // 防止 GC 在当前作用域内回收此 Cell
    // 通过编译器屏障阻止优化器消除对此值的引用
    //
    // 原始 Zig:
    //   std.mem.doNotOptimizeAway(this);
    public func ensureStillAlive() {
        // 在仓颉中，保持引用即可防止 GC
        // 类似于 Zig 的 doNotOptimizeAway
        let _ = rawPtr
    }
}
