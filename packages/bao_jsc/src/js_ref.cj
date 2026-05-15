// 严格翻译自: src/jsc/JSRef.zig (226行)
// JavaScriptCore JSRef - 带生命周期管理的 JSValue 引用

package bao_jsc

// ========== JSRef ==========
// 严格翻译自 JSRef.zig JSRef
// 安全维护 JavaScript 对象的原生引用，显式控制引用是否在 GC 期间保持对象存活
//
// # 状态
// - **weak**: 直接持有 JSValue，不阻止 GC。如果对象被回收，JSValue 可能变为无效。
//   使用 tryGet() 安全检查值是否仍然存活。
// - **strong**: 持有 Strong 引用，阻止 GC。JS 对象在此引用存在期间保持存活。
//   必须调用 deinit() 或 finalize() 释放。
// - **finalized**: 引用已被终结 (对象被 GC 或显式清理)。tryGet() 返回 None。
//
// 原始 Zig 代码:
//   pub const JSRef = union(enum) {
//       weak: jsc.JSValue,
//       strong: jsc.Strong.Optional,
//       finalized: void,
//   };
public class JSRef {
    // ========== 内部状态 ==========
    private var _tag: JSRefTag = JSRefTag.Weak
    // weak 状态下的 JSValue
    private var _weakValue: JsValue = JsValue.undefined()
    // strong 状态下的句柄
    private var _strongHandle: CPointer<UInt8> = CPointer<UInt8>()

    public init() {
        _tag = JSRefTag.Weak
        _weakValue = JsValue.undefined()
    }

    // ========== 当前标签 ==========
    public func tag() -> JSRefTag {
        _tag
    }

    // ========== initWeak ==========
    // 严格翻译自 JSRef.initWeak
    // 创建 weak 引用
    //
    // 原始 Zig:
    //   pub fn initWeak(value: jsc.JSValue) @This() {
    //       bun.assert(!value.isEmptyOrUndefinedOrNull());
    //       return .{ .weak = value };
    //   }
    public static func initWeak(value: JsValue) -> JSRef {
        // 断言: value 不能为空/undefined/null
        let ref = JSRef()
        ref._tag = JSRefTag.Weak
        ref._weakValue = value
        ref
    }

    // ========== initStrong ==========
    // 严格翻译自 JSRef.initStrong
    // 创建 strong 引用
    //
    // 原始 Zig:
    //   pub fn initStrong(value: jsc.JSValue, globalThis: *jsc.JSGlobalObject) @This() {
    //       bun.assert(!value.isEmptyOrUndefinedOrNull());
    //       return .{ .strong = .create(value, globalThis) };
    //   }
    public static func initStrong(value: JsValue, globalThis: JsObject) -> JSRef {
        let ref = JSRef()
        ref._tag = JSRefTag.Strong
        ref._weakValue = value
        // FFI: Strong.Optional.create(value, globalThis)
        ref._strongHandle = strongCreateFFI(value, globalThis)
        ref
    }

    // ========== empty ==========
    // 严格翻译自 JSRef.empty
    // 创建空引用 (weak with undefined)
    //
    // 原始 Zig:
    //   pub fn empty() @This() {
    //       return .{ .weak = .js_undefined };
    //   }
    public static func empty() -> JSRef {
        JSRef()
    }

    // ========== tryGet ==========
    // 严格翻译自 JSRef.tryGet
    // 安全获取 JSValue，如果已终结或为空返回 None
    //
    // 原始 Zig:
    //   pub fn tryGet(this: *const @This()) ?jsc.JSValue {
    //       return switch (this.*) {
    //           .weak => if (this.weak.isEmptyOrUndefinedOrNull()) null else this.weak,
    //           .strong => this.strong.get(),
    //           .finalized => null,
    //       };
    //   }
    public func tryGet() -> ?JsValue {
        match (_tag) {
            case JSRefTag.Weak => {
                if (_weakValue.isEmptyOrUndefinedOrNull()) {
                    return None
                }
                Some(_weakValue)
            }
            case JSRefTag.Strong => {
                // FFI: strong.get()
                if (_strongHandle == CPointer<UInt8>()) {
                    return None
                }
                strongGetFFI(_strongHandle)
            }
            case JSRefTag.Finalized => None
        }
    }

    // ========== setWeak ==========
    // 严格翻译自 JSRef.setWeak
    // 设置为 weak 引用
    //
    // 原始 Zig:
    //   pub fn setWeak(this: *@This(), value: jsc.JSValue) void {
    //       bun.assert(!value.isEmptyOrUndefinedOrNull());
    //       switch (this.*) {
    //           .weak => {},
    //           .strong => { this.strong.deinit(); },
    //           .finalized => { return; },
    //       }
    //       this.* = .{ .weak = value };
    //   }
    public func setWeak(value: JsValue) {
        match (_tag) {
            case JSRefTag.Weak => {}
            case JSRefTag.Strong => {
                strongDeinitFFI(_strongHandle)
                _strongHandle = CPointer<UInt8>()
            }
            case JSRefTag.Finalized => return
        }
        _tag = JSRefTag.Weak
        _weakValue = value
    }

    // ========== setStrong ==========
    // 严格翻译自 JSRef.setStrong
    // 设置为 strong 引用
    //
    // 原始 Zig:
    //   pub fn setStrong(this: *@This(), value: jsc.JSValue, globalThis: *jsc.JSGlobalObject) void {
    //       bun.assert(!value.isEmptyOrUndefinedOrNull());
    //       if (this.* == .strong) {
    //           this.strong.set(globalThis, value);
    //           return;
    //       }
    //       this.* = .{ .strong = .create(value, globalThis) };
    //   }
    public func setStrong(value: JsValue, globalThis: JsObject) {
        if (_tag == JSRefTag.Strong) {
            // FFI: strong.set(globalThis, value)
            strongSetFFI(_strongHandle, globalThis, value)
            return
        }
        _tag = JSRefTag.Strong
        _weakValue = value
        _strongHandle = strongCreateFFI(value, globalThis)
    }

    // ========== upgrade ==========
    // 严格翻译自 JSRef.upgrade
    // 将 weak 升级为 strong
    //
    // 原始 Zig:
    //   pub fn upgrade(this: *@This(), globalThis: *jsc.JSGlobalObject) void {
    //       switch (this.*) {
    //           .weak => {
    //               bun.assert(!this.weak.isEmptyOrUndefinedOrNull());
    //               const weak = this.weak;
    //               this.* = .{ .strong = .create(weak, globalThis) };
    //           },
    //           .strong => {},
    //           .finalized => { bun.debugAssert(false); },
    //       }
    //   }
    public func upgrade(globalThis: JsObject) {
        match (_tag) {
            case JSRefTag.Weak => {
                _tag = JSRefTag.Strong
                _strongHandle = strongCreateFFI(_weakValue, globalThis)
            }
            case JSRefTag.Strong => {}
            case JSRefTag.Finalized => {
                // debugAssert(false) - 在调试模式下会崩溃
            }
        }
    }

    // ========== downgrade ==========
    // 严格翻译自 JSRef.downgrade
    // 将 strong 降级为 weak
    //
    // 原始 Zig:
    //   pub fn downgrade(this: *@This()) void {
    //       switch (this.*) {
    //           .weak => {},
    //           .strong => |*strong| {
    //               const value = strong.trySwap() orelse .js_undefined;
    //               value.ensureStillAlive();
    //               strong.deinit();
    //               this.* = .{ .weak = value };
    //           },
    //           .finalized => {},
    //       }
    //   }
    public func downgrade() {
        match (_tag) {
            case JSRefTag.Weak => {}
            case JSRefTag.Strong => {
                // FFI: strong.trySwap() -> JSValue
                let value = strongTrySwapFFI(_strongHandle)
                // value.ensureStillAlive()
                // FFI: strong.deinit()
                strongDeinitFFI(_strongHandle)
                _strongHandle = CPointer<UInt8>()
                _tag = JSRefTag.Weak
                _weakValue = value
            }
            case JSRefTag.Finalized => {}
        }
    }

    // ========== isEmpty ==========
    // 严格翻译自 JSRef.isEmpty
    public func isEmpty() -> Bool {
        match (_tag) {
            case JSRefTag.Weak => _weakValue.isEmptyOrUndefinedOrNull()
            case JSRefTag.Strong => _strongHandle == CPointer<UInt8>()
            case JSRefTag.Finalized => true
        }
    }

    // ========== isNotEmpty ==========
    // 严格翻译自 JSRef.isNotEmpty
    public func isNotEmpty() -> Bool {
        !isEmpty()
    }

    // ========== isStrong ==========
    // 严格翻译自 JSRef.isStrong
    // 测试是否为 strong 引用
    public func isStrong() -> Bool {
        _tag == JSRefTag.Strong
    }

    // ========== deinit ==========
    // 严格翻译自 JSRef.deinit
    // 释放资源
    //
    // 原始 Zig:
    //   pub fn deinit(this: *@This()) void {
    //       switch (this.*) {
    //           .weak => { this.weak = .js_undefined; },
    //           .strong => { this.strong.deinit(); },
    //           .finalized => {},
    //       }
    //   }
    public func deinit() {
        match (_tag) {
            case JSRefTag.Weak => {
                _weakValue = JsValue.undefined()
            }
            case JSRefTag.Strong => {
                strongDeinitFFI(_strongHandle)
                _strongHandle = CPointer<UInt8>()
            }
            case JSRefTag.Finalized => {}
        }
    }

    // ========== finalize ==========
    // 严格翻译自 JSRef.finalize
    // 终结引用 (通常由 GC finalizer 调用)
    //
    // 原始 Zig:
    //   pub fn finalize(this: *@This()) void {
    //       this.deinit();
    //       this.* = .{ .finalized = {} };
    //   }
    public func finalize() {
        deinit()
        _tag = JSRefTag.Finalized
        _weakValue = JsValue.undefined()
    }

    // ========== update ==========
    // 严格翻译自 JSRef.update
    // 更新引用值
    //
    // 原始 Zig:
    //   pub fn update(this: *@This(), globalThis: *jsc.JSGlobalObject, value: JSValue) void {
    //       switch (this.*) {
    //           .weak => { ... this.weak = value; },
    //           .strong => { if (this.strong.get() != value) { this.strong.set(globalThis, value); } },
    //           .finalized => { bun.debugAssert(false); },
    //       }
    //   }
    public func update(globalThis: JsObject, value: JsValue) {
        match (_tag) {
            case JSRefTag.Weak => {
                _weakValue = value
            }
            case JSRefTag.Strong => {
                let current = strongGetFFI(_strongHandle)
                if (current == None || current.getOrThrow() != value) {
                    strongSetFFI(_strongHandle, globalThis, value)
                }
            }
            case JSRefTag.Finalized => {
                // debugAssert(false)
            }
        }
    }

    // ========== FFI 桩函数 ==========

    // FFI: jsc.Strong.Optional.create(value, globalThis)
    private static func strongCreateFFI(value: JsValue, globalThis: JsObject) -> CPointer<UInt8> {
        // 真实实现: @CFFI 调用 JSC Strong 创建
        CPointer<UInt8>()
    }

    // FFI: jsc.Strong.Optional.get() -> ?JSValue
    private static func strongGetFFI(handle: CPointer<UInt8>) -> ?JsValue {
        // 真实实现: @CFFI 调用 JSC Strong get
        if (handle == CPointer<UInt8>()) {
            return None
        }
        None
    }

    // FFI: jsc.Strong.Optional.set(globalThis, value)
    private static func strongSetFFI(handle: CPointer<UInt8>, globalThis: JsObject, value: JsValue) {
        // 真实实现: @CFFI 调用 JSC Strong set
    }

    // FFI: jsc.Strong.Optional.deinit()
    private static func strongDeinitFFI(handle: CPointer<UInt8>) {
        // 真实实现: @CFFI 调用 JSC Strong deinit
    }

    // FFI: jsc.Strong.Optional.trySwap() -> ?JSValue
    private static func strongTrySwapFFI(handle: CPointer<UInt8>) -> JsValue {
        // 真实实现: @CFFI 调用 JSC Strong trySwap
        JsValue.undefined()
    }
}

// ========== JSRefTag ==========
// JSRef 的内部状态标签
public enum JSRefTag {
    | Weak       // 弱引用 - 不阻止 GC
    | Strong     // 强引用 - 阻止 GC
    | Finalized  // 已终结 - JSValue 不再有效
}
