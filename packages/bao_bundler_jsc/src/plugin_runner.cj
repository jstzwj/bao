// 严格翻译自: src/bundler_jsc/PluginRunner.zig
//! Runtime plugin host (JS-side `Bun.plugin()` resolve hooks).
package bao_bundler_jsc

import bao_jsc.*
import bao_core.*
import bao_bundler.{PluginResolveResult, PluginLoadResult}

// ============================================================================
// MacroJSCtx - 宏 JS 上下文类型别名
// ============================================================================

public type MacroJSCtx = JsValue
public let defaultMacroJsValue = JsValue.jsUndefined()

// ============================================================================
// PluginRunner - 插件运行器
// ============================================================================

/// 插件解析结果 - 对应 Bun PluginRunner.onResolve 返回的 Fs.Path 子集
public class PluginRunnerResolveResult {
    public var path: String
    public var namespace: String
    public var external: Bool

    public init(path: String) {
        this.path = path
        this.namespace = "file"
        this.external = false
    }

    public init(path: String, namespace: String, external: Bool) {
        this.path = path
        this.namespace = namespace
        this.external = external
    }

    public func toBundlerResult(): PluginResolveResult {
        let result = PluginResolveResult(path)
        result.namespace = namespace
        result.external = external
        return result
    }
}

/// 插件运行器
public class PluginRunner {
    public var globalObject: JSGlobalObject
    public var allocator: Allocator

    public init(globalObject: JSGlobalObject, allocator: Allocator) {
        this.globalObject = globalObject
        this.allocator = allocator
    }

    /// 提取命名空间
    /// 严格翻译自 Bun: PluginRunner.extractNamespace(specifier)
    public static func extractNamespace(specifier: String): String {
        let colonOpt = specifier.indexOf(':')
        if (colonOpt.isNone()) { return "" }
        let colon = colonOpt.getOrThrow()

        if (isWindowsDriveSpecifier(specifier, colon)) {
            return ""
        }

        return specifier[0..colon]
    }

    /// 判断是否可能是插件
    /// 严格翻译自 Bun: PluginRunner.couldBePlugin(specifier)
    public static func couldBePlugin(specifier: String): Bool {
        let lastDotOpt = specifier.lastIndexOf('.')
        if (let Some(lastDot) <- lastDotOpt) {
            if (lastDot + 1 < specifier.size) {
                let firstExt = specifier[lastDot + 1]
                if (isAsciiLetter(firstExt) || firstExt > UInt8(127)) {
                    return true
                }
            }
        }

        return !isAbsolutePath(specifier) && specifier.indexOf(':').isSome()
    }

    /// 解析时回调
    /// 对应 Bun: runOnResolvePlugins + path/namespace 校验。
    /// Bao 当前 JSGlobalObject 尚未暴露 runOnResolvePlugins，因此该重载接收插件返回对象。
    public func onResolve(
        specifier: String,
        importer: String,
        pluginResult: JsValue
    ): ?PluginRunnerResolveResult {
        if (pluginResult.isEmptyOrUndefinedOrNull()) { return None }
        if (!pluginResult.isObject()) { return None }

        let global = globalObject.globalThis
        let pathValue = match (pluginResult.get(global, "path")) {
            case Some(value) => value
            case None => return None
        }
        if (pathValue.isEmptyOrUndefinedOrNull()) { return None }
        if (!pathValue.isString()) { return None }

        let filePath = pathValue.toString()
        if (!isValidResolvedPath(filePath)) { return None }

        var namespace = "file"
        if (let Some(namespaceValue) <- pluginResult.get(global, "namespace")) {
            if (!namespaceValue.isEmptyOrUndefinedOrNull()) {
                if (!namespaceValue.isString()) { return None }
                let namespaceString = namespaceValue.toString()
                namespace = normalizeNamespace(namespaceString)
            }
        }

        var external = false
        if (let Some(externalValue) <- pluginResult.get(global, "external")) {
            if (externalValue.isBoolean()) {
                external = externalValue.toBoolean()
            }
        }

        return Some(PluginRunnerResolveResult(filePath, namespace, external))
    }

    /// 兼容 PluginResolver 形状；没有 JSGlobalObject.runOnResolvePlugins 时不能伪造成功解析。
    public func onResolve(path: String, importer: String): ?PluginResolveResult {
        return None
    }

    public func onLoad(path: String, namespace: String): ?PluginLoadResult {
        return None
    }

    private static func normalizeNamespace(namespace: String): String {
        if (namespace.size == 0 || namespace == "file") { return "file" }
        if (namespace == "bun") { return "bun" }
        if (namespace == "node") { return "node" }
        return namespace
    }

    private static func isValidResolvedPath(path: String): Bool {
        if (path.size == 0) { return false }
        return !(path == "." || path == ".." || path == "..." || path == " ")
    }

    private static func isWindowsDriveSpecifier(specifier: String, colon: Int64): Bool {
        if (colon != 1 || specifier.size <= 3) { return false }
        let drive = specifier[0]
        return isAsciiLetter(drive) && isPathSeparator(specifier[2])
    }

    private static func isAbsolutePath(path: String): Bool {
        if (path.size == 0) { return false }
        if (isPathSeparator(path[0])) { return true }
        return path.size > 2 && isAsciiLetter(path[0]) && path[1] == UInt8(58) && isPathSeparator(path[2])
    }

    private static func isPathSeparator(ch: UInt8): Bool {
        ch == UInt8(47) || ch == UInt8(92)
    }

    private static func isAsciiLetter(ch: UInt8): Bool {
        (ch >= UInt8(65) && ch <= UInt8(90)) || (ch >= UInt8(97) && ch <= UInt8(122))
    }
}
