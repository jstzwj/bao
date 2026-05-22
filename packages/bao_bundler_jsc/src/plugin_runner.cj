// 严格翻译自: src/bundler_jsc/PluginRunner.zig
//! Runtime plugin host (JS-side `Bun.plugin()` resolve hooks). Stub implementation.
package bao_bundler_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// MacroJSCtx - 宏 JS 上下文类型别名
// ============================================================================

public type MacroJSCtx = JsValue
public let defaultMacroJsValue = JsValue.jsUndefined()

// ============================================================================
// PluginRunner - 插件运行器 (stub)
// ============================================================================

/// 插件运行器 - stub
public class PluginRunner {
    public var globalObject: JSGlobalObject
    public var allocator: Allocator

    public init(globalObject: JSGlobalObject, allocator: Allocator) {
        this.globalObject = globalObject
        this.allocator = allocator
    }

    /// 提取命名空间 - stub
    public static func extractNamespace(specifier: String): String {
        return ""
    }

    /// 判断是否可能是插件 - stub
    public static func couldBePlugin(specifier: String): Bool {
        return specifier.contains(':')
    }

    /// 解析时回调 - stub
    public func onResolve(
        specifier: String,
        importer: String
    ): ?String {
        return None
    }
}
