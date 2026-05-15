// 严格翻译自: src/install_jsc/hosted_git_info_jsc.zig
//! JSC bridges for `src/install/hosted_git_info.zig`.
package bao_install_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// HostedGitInfoJSC - HostedGitInfo 的 JSC 桥接
// 严格翻译自: src/install_jsc/hosted_git_info_jsc.zig:4-110
// ============================================================================

/// 将 HostedGitInfo 转换为 JS - 严格对应 Bun hostedGitInfoToJS
public func hostedGitInfoToJS(self: HostedGitInfo, go: JSGlobalObject): JSValue {
    let obj = JSValue.createEmptyObject(go, 6)
    obj.put(go, ZigString.static("type"), BaoString.fromBytes(self.hostProvider.typeStr()).toJS(go))
    obj.put(go, ZigString.static("domain"), BaoString.fromBytes(self.hostProvider.domain()).toJS(go))
    obj.put(go, ZigString.static("project"), BaoString.fromBytes(self.project).toJS(go))
    obj.put(go, ZigString.static("user"), if (let user = self.user) BaoString.fromBytes(user).toJS(go) else JSValue.null)
    obj.put(go, ZigString.static("committish"), if (let committish = self.committish) BaoString.fromBytes(committish).toJS(go) else JSValue.null)
    obj.put(go, ZigString.static("default"), BaoString.fromBytes(self.defaultRepresentation.toString()).toJS(go))
    return obj
}

/// JS parseUrl 函数 - 严格对应 Bun jsParseUrl
public func jsParseUrl(go: JSGlobalObject, callframe: CallFrame): JSValue {
    let allocator = Allocator.default

    if (callframe.argumentsCount() != 1) {
        go.throw("hostedGitInfo.prototype.parseUrl takes exactly 1 argument")
        return JSValue.zero
    }

    let arg0 = callframe.argument(0)
    if (!arg0.isString) {
        go.throw("hostedGitInfo.prototype.parseUrl takes a string as its first argument")
        return JSValue.zero
    }

    let npaStr = arg0.toBunString(go)
    var asUtf8 = npaStr.toUTF8(allocator)
    let parsed = HostedGitInfo.parseUrl(allocator, asUtf8.mut())
    if (parsed.isErr) {
        go.throw("Invalid Git URL: ${parsed.errValue}")
        return JSValue.zero
    }

    return parsed.resultValue.url.href().toJS(go)
}

/// JS fromUrl 函数 - 严格对应 Bun jsFromUrl
public func jsFromUrl(go: JSGlobalObject, callframe: CallFrame): JSValue {
    let allocator = Allocator.default

    if (callframe.argumentsCount() != 1) {
        go.throw("hostedGitInfo.prototype.fromUrl takes exactly 1 argument")
        return JSValue.zero
    }

    let arg0 = callframe.argument(0)
    if (!arg0.isString) {
        go.throw("hostedGitInfo.prototype.fromUrl takes a string as its first argument")
        return JSValue.zero
    }

    let npaStr = arg0.toBunString(go)
    var asUtf8 = npaStr.toUTF8(allocator)
    let parsed = HostedGitInfo.fromUrl(allocator, asUtf8.mut())
    if (parsed.isErr) {
        go.throw("Invalid Git URL: ${parsed.errValue}")
        return JSValue.zero
    }
    if (parsed.resultValue == None) {
        return JSValue.null
    }

    return hostedGitInfoToJS(parsed.resultValue, go)
}
