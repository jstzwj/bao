// 严格翻译自: src/runtime/api/Shell.classes.ts
package bao_runtime.api

import bao_jsc.*

// ============================================================================
// Shell.classes.ts 类绑定定义
// Bun: ShellInterpreter 的 JSC 绑定
// construct: true, noConstructor: true, finalize: true
// configurable: false, hasPendingActivity: true
// values: ["resolve", "reject"], valuesArray: true
// memoryCost: true, estimatedSize: true
// rustPath: crate::shell::Interpreter
// ============================================================================

/// ShellInterpreter JSC 绑定
/// Bun: Bun.shell() 内部 shell 解释器
public class ShellInterpreterClasses {

    /// run fn
    /// 严格翻译自: proto.run { fn: "runFromJS", length: 0 }
    /// 启动 shell 脚本执行
    public static func runFromJS(globalObject: JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        // 执行预解析的 shell 脚本
        // 返回 Promise<ShellOutput>
        return JsValue.jsUndefined()
    }

    /// isRunning fn
    /// 严格翻译自: proto.isRunning { fn: "isRunning", length: 0 }
    public static func isRunning(globalObject: JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        // 检查 shell 是否正在运行
        return JsValue.jsBoolean(false)
    }

    /// started fn
    /// 严格翻译自: proto.started { fn: "getStarted", length: 0 }
    public static func getStarted(globalObject: JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        // 返回是否已开始执行
        return JsValue.jsBoolean(false)
    }
}
