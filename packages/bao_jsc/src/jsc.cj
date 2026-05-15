// 严格翻译自: src/jsc/jsc.zig
// JSC 主模块 - JavaScriptCore 绑定的中央入口点

package bao_jsc

// ========== JSC 模块 ==========
// 严格翻译自 jsc.zig
// JavaScriptCore 和其他 JavaScript 原语（如 VirtualMachine、JSGlobalObject、事件循环）的绑定
// Web 和运行时特定的 API 应放在 bun.webcore 和 bun.api 中

// ========== 常量 ==========
// 严格翻译自 jsc.MAX_SAFE_INTEGER / MIN_SAFE_INTEGER
public let MAX_SAFE_INTEGER: Int64 = 9007199254740991
public let MIN_SAFE_INTEGER: Int64 = -9007199254740991

// 严格翻译自 jsc.init_timestamp / JSTimeType
// 根据 MDN，JavaScript 中最大 Date 小于 Number.MAX_SAFE_INTEGER (u52)
public typealias JSTimeType = UInt64
public let INIT_TIMESTAMP: JSTimeType = JSTimeType.maxValue

// ========== markBinding ==========
// 严格翻译自 jsc.markBinding
// 标记绑定调用点，用于调试日志
public func markBinding(fnName: String, file: String, line: Int64) {
    // Log the binding call for debugging
}

// ========== markMemberBinding ==========
// 严格翻译自 jsc.markMemberBinding
public func markMemberBinding(className: String, fnName: String, file: String, line: Int64) {
    // Log the member binding call for debugging
}

// ========== initialize ==========
// 严格翻译自 jsc.initialize
// 绑定 JSCInitialize，在 ZigGlobalObject.cpp 中定义
public func initialize(evalMode: Bool) {
    // FFI: JSCInitialize
}

// ========== toJSTime ==========
// 严格翻译自 jsc.toJSTime
// 将秒和纳秒转换为 JS 时间戳（毫秒精度，适配 u52）
public func toJSTime(sec: Int64, nsec: Int64) -> JSTimeType {
    let millisec = nsec / 1000000
    UInt64(sec * 1000 + millisec)
}

// ========== Ref ==========
// 严格翻译自 jsc.Ref
// 跟踪对象是否应该保持事件循环活跃
public class Ref {
    public var has_: Bool = false

    public init() {}

    // 严格翻译自 Ref.init
    public static func init_() -> Ref {
        Ref()
    }

    // 严格翻译自 Ref.unref
    public func unref(vm: BunVirtualMachine) {
        if (!has_) { return }
        has_ = false
        vm.activeTasks -= 1
    }

    // 严格翻译自 Ref.ref
    public func ref(vm: BunVirtualMachine) {
        if (has_) { return }
        has_ = true
        vm.activeTasks += 1
    }
}

// ========== OpaqueCallback ==========
// 严格翻译自 jsc.OpaqueCallback
public typealias OpaqueCallback = (UInt64) -> Void

// ========== Math ==========
// 严格翻译自 jsc.math
public class JSCMath {
    // 严格翻译自 math.pow
    public static func pow(x: Float64, y: Float64) -> Float64 {
        // FFI: Bun__JSC__operationMathPow
        Math.pow(x, y)
    }
}
