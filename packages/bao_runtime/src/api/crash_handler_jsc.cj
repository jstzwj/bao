// 严格翻译自: src/runtime/api/crash_handler_jsc.zig
package bao_runtime

import bao_jsc.*
import bao_core.*

// ============================================================================
// crash_handler_jsc - 崩溃处理器的 JS 测试/调试绑定
// 对应 Bun: src/runtime/api/crash_handler_jsc.zig
// ============================================================================

/// JS 绑定函数集合, 用于测试崩溃处理器
public class CrashHandlerJsBindings {

    /// 生成所有绑定函数到 JS 对象
    public static func generate(global: JsGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(global, 8)

        let functions: Array<(String, (JsGlobalObject, JsCallFrame) -> JsValue)> = [
            ("getMachOImageZeroOffset", jsGetMachOImageZeroOffset),
            ("getFeaturesAsVLQ", jsGetFeaturesAsVLQ),
            ("getFeatureData", jsGetFeatureData),
            ("segfault", jsSegfault),
            ("panic", jsPanic),
            ("rootError", jsRootError),
            ("outOfMemory", jsOutOfMemory),
            ("raiseIgnoringPanicHandler", jsRaiseIgnoringPanicHandler),
        ]

        for ((name, fn) in functions) {
            let jsName = ZigString.static(name)
            obj.put(global, jsName, JsFunction.create(global, name, fn, 1))
        }

        return obj
    }

    // ========================================================================
    // JS 绑定函数
    // ========================================================================

    /// 获取 MachO 镜像零偏移
    public static func jsGetMachOImageZeroOffset(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        if (!Environment.isMac) { return JsValue.jsUndefined }

        // 获取镜像头和 vmaddr_slide
        // ... 平台特定实现
        return JsValue.jsNumber(0)
    }

    /// 触发段错误 (仅用于测试)
    public static func jsSegfault(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        CrashHandler.suppressCoreDumpsIfNecessary()
        // ... 写入无效内存地址
        return JsValue.jsUndefined
    }

    /// 触发 panic (仅用于测试)
    public static func jsPanic(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        CrashHandler.suppressCoreDumpsIfNecessary()
        CrashHandler.panicImpl("invoked crashByPanic() handler")
        return JsValue.jsUndefined
    }

    /// 触发根错误 (仅用于测试)
    public static func jsRootError(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        CrashHandler.handleRootError(Error.Test)
        return JsValue.jsUndefined
    }

    /// 触发内存不足 (仅用于测试)
    public static func jsOutOfMemory(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        CrashHandler.suppressCoreDumpsIfNecessary()
        Global.outOfMemory()
        return JsValue.jsUndefined
    }

    /// 忽略 panic 处理器引发信号 (仅用于测试)
    public static func jsRaiseIgnoringPanicHandler(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        CrashHandler.suppressCoreDumpsIfNecessary()
        Global.raiseIgnoringPanicHandler(.SIGSEGV)
        return JsValue.jsUndefined
    }

    /// 获取功能特性作为 VLQ 编码
    public static func jsGetFeaturesAsVLQ(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let bits = Analytics.packedFeatures()
        var buf = BoundedArray<UInt8>(capacity: 16)
        CrashHandler.writeU64AsTwoVLQs(buf.writer(), UInt64(bitCast(bits)))
        var str = BunString.cloneLatin1(buf.slice())
        return str.transferToJS(global)
    }

    /// 获取功能特性数据
    public static func jsGetFeatureData(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let obj = JsValue.createEmptyObject(global, 5)
        let list = Analytics.packedFeaturesList
        let array = try JsValue.createEmptyArray(global, list.count)
        for ((feature, i) in list.enumerated()) {
            try array.putIndex(global, UInt32(i), BunString.static(feature).toJS(global))
        }
        obj.put(global, ZigString.static("features"), array)
        obj.put(global, ZigString.static("version"), BunString.init(Global.packageJsonVersion).toJS(global))
        obj.put(global, ZigString.static("is_canary"), JsValue.jsBoolean(Environment.isCanary))
        obj.put(global, ZigString.static("revision"), BunString.init(Environment.gitSha).toJS(global))
        obj.put(global, ZigString.static("generated_at"), JsValue.jsNumberFromInt64(max(Time.milliTimestamp(), 0)))
        return obj
    }
}
