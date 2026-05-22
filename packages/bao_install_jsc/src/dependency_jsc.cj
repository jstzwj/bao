// 严格翻译自: src/install_jsc/dependency_jsc.zig
//! JSC bridges for `bun.install.Dependency`. Stub implementation.
package bao_install_jsc

import bao_jsc.*
import bao_core.*
import bao_install.*

// ============================================================================
// DependencyJSC - Dependency 的 JSC 桥接 (stub)
// ============================================================================

/// 将 Dependency.Version 转换为 JS 值 - stub
public func dependencyVersionToJS(dep: DependencyVersion, buf: Array<Byte>, globalThis: JSGlobalObject): JsValue {
    let object = JsValue.createEmptyObject(globalThis.globalThis, 0)
    return object
}

/// 从 JS 推断 tag 类型 - stub
public func tagInferFromJS(globalObject: JSGlobalObject, callframe: CallFrame): JsValue {
    return JsValue.jsUndefined()
}

/// 从 JS 创建 Dependency - stub
public func dependencyFromJS(globalThis: JSGlobalObject, callframe: CallFrame): JsValue {
    return JsValue.jsUndefined()
}
