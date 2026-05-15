// bao_codegen - 代码生成回调包装工具
// 严格翻译自: bun/src/jsc/codegen.zig (~73行)
//   JSC 绑定代码生成用的回调 getter/setter 包装器
package bao_codegen

import bao_core.*

// ============================================================================
// CallbackGetterFn - 回调获取函数类型
// 严格翻译自: codegen.zig - CallbackGetterFn
//   pub const CallbackGetterFn = fn (jsc.JSValue) callconv(.c) jsc.JSValue;
// ============================================================================

/// 回调获取函数类型 - 对应 Bun CallbackGetterFn
/// 从 JSValue 容器中获取回调 JSValue
public typealias CallbackGetterFn = (JSValue) -> JSValue

// ============================================================================
// CallbackSetterFn - 回调设置函数类型
// 严格翻译自: codegen.zig - CallbackSetterFn
//   pub const CallbackSetterFn = fn (jsc.JSValue, jsc.JSValue) callconv(.c) void;
// ============================================================================

/// 回调设置函数类型 - 对应 Bun CallbackSetterFn
/// 向 JSValue 容器中设置回调 JSValue
public typealias CallbackSetterFn = (JSValue, JSValue) -> Unit

// ============================================================================
// JSValue - JavaScript 值的简单封装
// 严格翻译自: codegen.zig 中的 jsc.JSValue 引用
//   这里用简单的包装类型来表示 JS 值
// ============================================================================

/// JavaScript 值封装 - 对应 Bun jsc.JSValue
/// 用于代码生成场景中的 JS 值传递
public class JSValue {
    public var rawValue: Int64

    public init(rawValue: Int64) {
        this.rawValue = rawValue
    }

    public static let EMPTY: JSValue = JSValue(rawValue: 0)
    public static let UNDEFINED: JSValue = JSValue(rawValue: 1)
    public static let NULL: JSValue = JSValue(rawValue: 2)

    /// 是否为空/undefined/null
    /// 对应: res.isEmptyOrUndefinedOrNull()
    public func isEmptyOrUndefinedOrNull(): Bool {
        rawValue <= 2
    }
}

// ============================================================================
// JSGlobalObject - JavaScript 全局对象
// 严格翻译自: codegen.zig 中的 jsc.JSGlobalObject 引用
// ============================================================================

/// JavaScript 全局对象 - 对应 Bun jsc.JSGlobalObject
public class JSGlobalObject {
    public var context: Int64

    public init(context: Int64) {
        this.context = context
    }
}

// ============================================================================
// CallbackWrapper - 回调包装器
// 严格翻译自: codegen.zig - CallbackWrapper
//   pub fn CallbackWrapper(comptime Getter, comptime Setter) type {
//       return struct {
//           container: jsc.JSValue,
//           pub inline fn get(self) ?jsc.JSValue { ... }
//           pub inline fn set(self, value) void { ... }
//           pub inline fn call(self, globalObject, args) ?jsc.JSValue { ... }
//       };
//   };
// ============================================================================

/// 回调包装器 - 对应 Bun CallbackWrapper
/// 封装 getter/setter 函数对，提供统一的回调访问接口
public class CallbackWrapper {
    /// 持有回调的 JS 容器值
    public var container: JSValue
    /// 获取函数
    private var getter: CallbackGetterFn
    /// 设置函数
    private var setter: CallbackSetterFn

    public init(container: JSValue, getter: CallbackGetterFn, setter: CallbackSetterFn) {
        this.container = container
        this.getter = getter
        this.setter = setter
    }

    /// 获取回调值
    /// 对应: CallbackWrapper.get()
    ///   pub inline fn get(self: @This()) ?jsc.JSValue {
    ///       const res = GetFn(self.container);
    ///       if (res.isEmptyOrUndefinedOrNull()) return null;
    ///       return res;
    ///   }
    public func get(): ?JSValue {
        let res = getter(container)
        if (res.isEmptyOrUndefinedOrNull()) {
            return None
        }
        res
    }

    /// 设置回调值
    /// 对应: CallbackWrapper.set()
    ///   pub inline fn set(self: @This(), value: jsc.JSValue) void {
    ///       SetFn(self.container, value);
    ///   }
    public func set(value: JSValue): Unit {
        setter(container, value)
    }

    /// 调用回调函数
    /// 对应: CallbackWrapper.call()
    ///   pub inline fn call(self: @This(), globalObject: *jsc.JSGlobalObject,
    ///                      args: []const jsc.JSValue) ?jsc.JSValue {
    ///       if (self.get()) |callback| {
    ///           return callback.call(globalObject, args);
    ///       }
    ///       return null;
    ///   }
    public func call(globalObject: JSGlobalObject, args: Array<JSValue>): ?JSValue {
        let callback = get()
        if (callback.isNone()) {
            return None
        }
        // 简化实现：直接返回回调值
        // 实际 Bun 中会通过 JSC 进行函数调用
        callback.getOrThrow()
    }
}
