// mock.cj - Mock/Spy 函数系统
// 严格翻译自 bun/src/jsc/bindings/JSMockFunction.cpp + JSMockFunction.h
//
// 本文件实现了 Jest 兼容的 mock 函数系统:
// - JSMockFunction: mock 函数类，记录调用、返回值等
// - JSMockModule: mock 模块，管理全局 mock 状态
// - JSMock: 对外暴露的 JS 宿主函数（fn, spyOn, restoreAllMocks 等）
//
// 底层依赖 C++ 的 JSC 内部实现，通过 FFI 绑定暴露给仓颉。

package bao_runtime.test_runner

import bao_jsc.*

// ========== JSMockFunction - Mock 函数 ==========

/// Mock 函数类
///
/// 对应 Bun C++: `class JSMockFunction : public JSC::InternalFunction`
///
/// Mock 函数用于:
/// 1. 记录所有调用参数 (calls)
/// 2. 记录调用上下文 (contexts)
/// 3. 记录返回值 (results/returnValues)
/// 4. 记录调用顺序 (invocationCallOrder)
/// 5. 支持自定义实现 (mockImplementation/mockImplementationOnce)
/// 6. 支持固定返回值 (mockReturnValue/mockReturnValueOnce)
/// 7. 支持 spyOn（间谍函数）
///
/// 大部分操作通过 FFI 调用 C++ 实现，因为 JSMockFunction 继承自
/// JSC::InternalFunction，需要与 JSC 的 GC 系统交互。
public class JSMockFunction {

    // ========== FFI 桥接方法 ==========

    /// 获取 mock 函数的调用记录数组
    ///
    /// 对应 C++: `JSMockFunction__getCalls`
    /// 返回一个 JSArray，每个元素是一个调用参数数组。
    ///
    /// @param globalThis - 全局对象
    /// @param value - mock 函数的 JSValue
    /// @return 调用记录数组
    public static func getCalls(globalThis: JSGlobalObject, value: JSValue): JSValue {
        return JSMockFunctionFFI.getCalls(globalThis: globalThis, value: value)
    }

    /// 获取 mock 函数的上下文记录数组
    ///
    /// 返回一个 JSArray，记录每次调用的 this 值。
    public static func getContexts(globalThis: JSGlobalObject, value: JSValue): JSValue {
        return JSMockFunctionFFI.getContexts(globalThis: globalThis, value: value)
    }

    /// 获取 mock 函数的返回值记录数组
    ///
    /// 对应 C++: `JSMockFunction__getReturns`
    /// 返回一个 JSArray，每个元素是 { type: "return"|"throw"|"incomplete", value: ... }
    public static func getReturnValues(globalThis: JSGlobalObject, value: JSValue): JSValue {
        return JSMockFunctionFFI.getReturnValues(globalThis: globalThis, value: value)
    }

    /// 获取 mock 函数的实例记录数组
    public static func getInstances(globalThis: JSGlobalObject, value: JSValue): JSValue {
        return JSMockFunctionFFI.getInstances(globalThis: globalThis, value: value)
    }

    /// 获取 mock 函数的调用顺序数组
    public static func getInvocationCallOrder(globalThis: JSGlobalObject, value: JSValue): JSValue {
        return JSMockFunctionFFI.getInvocationCallOrder(globalThis: globalThis, value: value)
    }
}

// ========== JSMockFunctionFFI - FFI 桥接层 ==========

/// FFI 桥接层
///
/// 这些函数通过外部函数接口调用 C++ 的 JSMockFunction 实现。
/// 对应 Bun C++ 代码中通过 `[[ZIG_EXPORT]]` 导出的函数。
public class JSMockFunctionFFI {

    /// 获取调用记录 - FFI 桥接
    /// 对应: `JSMockFunction__getCalls(JSGlobalObject*, EncodedJSValue)`
    public static func getCalls(globalThis: JSGlobalObject, value: JSValue): JSValue {
        // FFI 调用 C++ 实现
        return JSMockFunction__getCalls(globalThis, value)
    }

    /// 获取上下文记录 - FFI 桥接
    public static func getContexts(globalThis: JSGlobalObject, value: JSValue): JSValue {
        return JSMockFunction__getContexts(globalThis, value)
    }

    /// 获取返回值记录 - FFI 桥接
    /// 对应: `JSMockFunction__getReturns(JSGlobalObject*, EncodedJSValue)`
    public static func getReturnValues(globalThis: JSGlobalObject, value: JSValue): JSValue {
        return JSMockFunction__getReturns(globalThis, value)
    }

    /// 获取实例记录 - FFI 桥接
    public static func getInstances(globalThis: JSGlobalObject, value: JSValue): JSValue {
        return JSMockFunction__getInstances(globalThis, value)
    }

    /// 获取调用顺序 - FFI 桥接
    public static func getInvocationCallOrder(globalThis: JSGlobalObject, value: JSValue): JSValue {
        return JSMockFunction__getInvocationCallOrder(globalThis, value)
    }
}

// ========== FFI 外部函数声明 ==========

/// C++ JSMockFunction 实现的外部函数声明
///
/// 这些函数在 C++ 端通过 Bun 的代码生成系统导出，
/// 在仓颉端通过 @ForeignFunction 声明并调用。
@ForeignFunction(link("bao_jsc", "JSMockFunction__getCalls"))
external func JSMockFunction__getCalls(globalThis: JSGlobalObject, value: JSValue): JSValue

@ForeignFunction(link("bao_jsc", "JSMockFunction__getContexts"))
external func JSMockFunction__getContexts(globalThis: JSGlobalObject, value: JSValue): JSValue

@ForeignFunction(link("bao_jsc", "JSMockFunction__getReturns"))
external func JSMockFunction__getReturnValues(globalThis: JSGlobalObject, value: JSValue): JSValue

@ForeignFunction(link("bao_jsc", "JSMockFunction__getInstances"))
external func JSMockFunction__getInstances(globalThis: JSGlobalObject, value: JSValue): JSValue

@ForeignFunction(link("bao_jsc", "JSMockFunction__getInvocationCallOrder"))
external func JSMockFunction__getInvocationCallOrder(globalThis: JSGlobalObject, value: JSValue): JSValue

// ========== JSMock - JS 宿主函数 ==========

/// JSMock JS 宿主函数
///
/// 对应 Bun C++ 中的以下导出函数:
/// - JSMock__jsMockFn: 创建 mock 函数
/// - JSMock__jsSpyOn: 创建间谍函数
/// - JSMock__jsRestoreAllMocks: 恢复所有 mock
/// - JSMock__jsClearAllMocks: 清除所有 mock
/// - JSMock__jsNow: 获取当前时间
/// - JSMock__jsSetSystemTime: 设置系统时间
/// - JSMock__setOverridenDateNow: 设置 Date.now 覆盖
/// - JSMock__getCurrentUnixTimeMs: 获取当前 Unix 时间戳
public class JSMock {

    /// 创建 mock 函数
    ///
    /// 对应 C++: `JSMock__jsMockFn`
    /// 用法: jest.fn(implementation?) 或 vi.fn(implementation?)
    ///
    /// 创建一个新的 mock 函数:
    /// - 如果提供了实现函数，使用它作为 mock 的实现
    /// - 如果提供了非函数值，将其作为固定返回值
    /// - 如果没有参数，创建一个返回 undefined 的 mock
    ///
    /// @param globalObject - 全局对象
    /// @param callFrame - 调用帧
    /// @return 新创建的 mock 函数 JSValue
    public static func jsMockFn(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        return JSMock__jsMockFn(globalObject, callFrame)
    }

    /// 创建间谍函数
    ///
    /// 对应 C++: `JSMock__jsSpyOn`
    /// 用法: jest.spyOn(object, methodName) 或 vi.spyOn(object, methodName)
    ///
    /// 在给定对象上创建一个间谍函数:
    /// 1. 保存原始方法的引用
    /// 2. 替换为 mock 函数
    /// 3. 记录所有调用
    /// 4. 可通过 mockRestore() 恢复原始方法
    ///
    /// @param globalObject - 全局对象
    /// @param callFrame - 调用帧（参数: target, propertyKey）
    /// @return 间谍 mock 函数 JSValue
    public static func jsSpyOn(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        return JSMock__jsSpyOn(globalObject, callFrame)
    }

    /// 恢复所有 mock（重置所有间谍）
    ///
    /// 对应 C++: `JSMock__jsRestoreAllMocks`
    /// 用法: jest.restoreAllMocks() 或 vi.restoreAllMocks()
    ///
    /// 遍历所有活跃的间谍函数，将它们恢复为原始实现。
    public static func jsRestoreAllMocks(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        return JSMock__jsRestoreAllMocks(globalObject, callFrame)
    }

    /// 清除所有 mock（清除调用记录，但不恢复实现）
    ///
    /// 对应 C++: `JSMock__jsClearAllMocks`
    /// 用法: jest.clearAllMocks() 或 vi.clearAllMocks()
    ///
    /// 遍历所有活跃的 mock 函数，清除调用记录、返回值记录等，
    /// 但不恢复原始实现（区别于 restoreAllMocks）。
    public static func jsClearAllMocks(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        return JSMock__jsClearAllMocks(globalObject, callFrame)
    }

    /// 获取当前时间
    ///
    /// 对应 C++: `JSMock__jsNow`
    /// 用法: jest.now() 或 vi.now()
    ///
    /// 返回 Date.now() 的值，如果使用了假定时器则返回模拟的时间。
    public static func jsNow(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        return JSMock__jsNow(globalObject, callFrame)
    }

    /// 设置系统时间
    ///
    /// 对应 C++: `JSMock__jsSetSystemTime`
    /// 用法: jest.setSystemTime(dateOrNumber) 或 vi.setSystemTime(dateOrNumber)
    ///
    /// 设置假定时器的系统时间:
    /// - 如果传入 Date 对象，使用其时间戳
    /// - 如果传入数字 >= 0，直接使用
    /// - 否则重置为 -1（真实时间）
    public static func jsSetSystemTime(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        return JSMock__jsSetSystemTime(globalObject, callFrame)
    }

    /// 设置 Date.now 覆盖值
    ///
    /// 对应 C++: `JSMock__setOverridenDateNow`
    /// 这是在 FakeTimers 中使用的底层函数。
    ///
    /// @param globalObject - 全局对象
    /// @param timeMs - 时间戳（毫秒），-1 表示不覆盖
    public static func setOverridenDateNow(globalObject: JSGlobalObject, timeMs: Float64) {
        JSMock__setOverridenDateNow(globalObject, timeMs)
    }

    /// 获取当前 Unix 时间戳（毫秒）
    ///
    /// 对应 C++: `JSMock__getCurrentUnixTimeMs`
    /// @return 当前时间的毫秒时间戳
    public static func getCurrentUnixTimeMs(): Float64 {
        return JSMock__getCurrentUnixTimeMs()
    }
}

// ========== JSMock FFI 外部函数声明 ==========

@ForeignFunction(link("bao_jsc", "JSMock__jsMockFn"))
external func JSMock__jsMockFn(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue

@ForeignFunction(link("bao_jsc", "JSMock__jsSpyOn"))
external func JSMock__jsSpyOn(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue

@ForeignFunction(link("bao_jsc", "JSMock__jsRestoreAllMocks"))
external func JSMock__jsRestoreAllMocks(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue

@ForeignFunction(link("bao_jsc", "JSMock__jsClearAllMocks"))
external func JSMock__jsClearAllMocks(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue

@ForeignFunction(link("bao_jsc", "JSMock__jsNow"))
external func JSMock__jsNow(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue

@ForeignFunction(link("bao_jsc", "JSMock__jsSetSystemTime"))
external func JSMock__jsSetSystemTime(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue

@ForeignFunction(link("bao_jsc", "JSMock__setOverridenDateNow"))
external func JSMock__setOverridenDateNow(globalObject: JSGlobalObject, timeMs: Float64): Unit

@ForeignFunction(link("bao_jsc", "JSMock__getCurrentUnixTimeMs"))
external func JSMock__getCurrentUnixTimeMs(): Float64
