// 严格翻译自: src/runtime/api/ParsedShellScript.classes.ts
package bao_runtime.api

import bao_jsc.*

// ============================================================================
// ParsedShellScript.classes.ts 类绑定定义
// Bun: ParsedShellScript 的 JSC 绑定
// construct: true, noConstructor: true, finalize: true
// configurable: false, hasPendingActivity: false
// valuesArray: true, memoryCost: true, estimatedSize: true
// ============================================================================

/// ParsedShellScript JSC 绑定
/// Bun: 预解析的 shell 脚本 (Bun.spawn 内部使用)
public class ParsedShellScriptClasses {

    /// setCwd fn
    /// 严格翻译自: proto.setCwd { fn: "setCwd", length: 1 }
    /// 参数: (cwd: string)
    public static func setCwd(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        // 设置当前工作目录
        return JsValue.jsUndefined()
    }

    /// setEnv fn
    /// 严格翻译自: proto.setEnv { fn: "setEnv", length: 1 }
    /// 参数: (env: Record<string, string>)
    public static func setEnv(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        // 设置环境变量
        return JsValue.jsUndefined()
    }

    /// setQuiet fn
    /// 严格翻译自: proto.setQuiet { fn: "setQuiet", length: 1 }
    /// 参数: (quiet: boolean)
    public static func setQuiet(JsGlobalObject, callframe: JsCallFrame, thisValue: JsValue): JsValue {
        // 设置静默模式
        return JsValue.jsUndefined()
    }
}
