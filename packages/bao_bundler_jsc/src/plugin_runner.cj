// 严格翻译自: src/bundler_jsc/PluginRunner.zig
//! Runtime plugin host (JS-side `Bun.plugin()` resolve hooks).
package bao_bundler_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// MacroJSCtx - 宏 JS 上下文类型别名
// 严格翻译自: src/bundler_jsc/PluginRunner.zig:4-5
//   pub const MacroJSCtx = jsc.JSValue
//   pub const default_macro_js_value = jsc.JSValue.zero
// ============================================================================
public typealias MacroJSCtx = JSValue
public let defaultMacroJsValue = JSValue.zero

// ============================================================================
// PluginRunner - 插件运行器
// 严格翻译自: src/bundler_jsc/PluginRunner.zig:7-242
// ============================================================================

/// 插件运行器 - 严格对应 Bun PluginRunner
public class PluginRunner {
    public var globalObject: JSGlobalObject
    public var allocator: Allocator

    public init(globalObject: JSGlobalObject, allocator: Allocator) {
        this.globalObject = globalObject
        this.allocator = allocator
    }

    /// 提取命名空间 - 严格对应 Bun extractNamespace
    /// Zig: pub fn extractNamespace(specifier: string) string
    public static func extractNamespace(specifier: String): String {
        let colon = strings.indexOfChar(specifier, ':')
        if (colon == None) {
            return ""
        }
        if (Environment.isWindows && colon == 1 && specifier.size > 3 && path.isSepAny(specifier[2]) && ((specifier[0] > 'a' && specifier[0] < 'z') || (specifier[0] > 'A' && specifier[0] < 'Z'))) {
            return ""
        }
        return specifier[0..colon]
    }

    /// 判断是否可能是插件 - 严格对应 Bun couldBePlugin
    /// Zig: pub fn couldBePlugin(specifier: string) bool
    public static func couldBePlugin(specifier: String): Bool {
        if (let lastDot = strings.lastIndexOfChar(specifier, '.')) {
            let ext = specifier[lastDot + 1..]
            if (ext.size > 0 && ((ext[0] >= 'a' && ext[0] <= 'z') || (ext[0] >= 'A' && ext[0] <= 'Z') || ext[0] > 127)) {
                return true
            }
        }
        return (!Fs.path.isAbsolute(specifier) && strings.containsChar(specifier, ':'))
    }

    /// 解析时回调 - 严格对应 Bun onResolve
    /// Zig: pub fn onResolve(this, specifier, importer, log, loc, target) bun.JSError!?Fs.Path
    public func onResolve(
        specifier: String,
        importer: String,
        log: Logger.Log,
        loc: Loc,
        target: BunPluginTarget
    ): ?FsPath {
        let global = globalObject
        let namespaceSlice = extractNamespace(specifier)
        let namespace = if (namespaceSlice.size > 0 && !strings.eqlComptime(namespaceSlice, "file")) {
            BaoString.init(namespaceSlice)
        } else {
            BaoString.empty
        }

        let onResolvePlugin = global.runOnResolvePlugins(
            namespace,
            BaoString.init(specifier).substring(if (namespace.length() > 0) namespace.length() + 1 else 0),
            BaoString.init(importer),
            target
        )
        if (onResolvePlugin == None) {
            return None
        }

        let pathValue = onResolvePlugin.get(global, "path")
        if (pathValue == None) {
            return None
        }
        if (pathValue.isEmptyOrUndefinedOrNull) {
            return None
        }
        if (!pathValue.isString) {
            log.addError(None, loc, "Expected \"path\" to be a string")
            return None
        }

        let filePath = pathValue.toBunString(global)
        if (filePath.length() == 0) {
            log.addError(None, loc, "Expected \"path\" to be a non-empty string in onResolve plugin")
            return None
        } else if (filePath.eqlComptime(".") || filePath.eqlComptime("..") || filePath.eqlComptime("...") || filePath.eqlComptime(" ")) {
            log.addError(None, loc, "Invalid file path from onResolve plugin")
            return None
        }

        var staticNamespace = true
        let userNamespace: BaoString = if (let namespaceValue = onResolvePlugin.get(global, "namespace")) {
            if (!namespaceValue.isString) {
                log.addError(None, loc, "Expected \"namespace\" to be a string")
                return None
            }
            let namespaceStr = namespaceValue.toBunString(global)
            if (namespaceStr.length() == 0) {
                BaoString.init("file")
            } else if (namespaceStr.eqlComptime("file")) {
                BaoString.init("file")
            } else if (namespaceStr.eqlComptime("bun")) {
                BaoString.init("bun")
            } else if (namespaceStr.eqlComptime("node")) {
                BaoString.init("node")
            } else {
                staticNamespace = false
                namespaceStr
            }
        } else {
            BaoString.init("file")
        }

        if (staticNamespace) {
            return FsPath.initWithNamespace(fmtAllocPrint(allocator, "${filePath}"), userNamespace.byteSlice())
        } else {
            return FsPath.initWithNamespace(fmtAllocPrint(allocator, "${filePath}"), fmtAllocPrint(allocator, "${userNamespace}"))
        }
    }
}
