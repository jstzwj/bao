// 严格翻译自: src/install_jsc/npm_jsc.zig
//! JSC host fns extracted from `src/install/npm.zig`. Stub implementation.
package bao_install_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// NpmJSC - NPM 的 JSC 桥接 (stub)
// ============================================================================

/// 操作系统匹配 - stub
public func operatingSystemIsMatch(globalObject: JSGlobalObject, callframe: CallFrame): JsValue {
    return JsValue.jsBoolean(false)
}

/// Libc 匹配 - stub
public func libcIsMatch(globalObject: JSGlobalObject, callframe: CallFrame): JsValue {
    return JsValue.jsBoolean(false)
}

/// 架构匹配 - stub
public func architectureIsMatch(globalObject: JSGlobalObject, callframe: CallFrame): JsValue {
    return JsValue.jsBoolean(false)
}

/// Manifest 绑定 - stub
public class ManifestBindings {
    /// 生成绑定对象 - stub
    public static func generate(global: JSGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(global.globalThis, 1)
        return obj
    }

    /// 解析 Manifest - stub
    public static func jsParseManifest(global: JSGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }
}
