// 严格翻译自: src/install_jsc/hosted_git_info_jsc.zig
//! JSC bridges for `src/install/hosted_git_info.zig`.
package bao_install_jsc

import bao_jsc.*
import bao_core.*
import bao_install.*

// ============================================================================
// HostedGitInfoJSC - HostedGitInfo 的 JSC 桥接
// ============================================================================

/// 将 HostedGitInfo 转换为 JS
public func hostedGitInfoToJS(self: HostedGitInfo, go: JSGlobalObject): JsValue {
    let obj = JsObject.make()
    obj.set("type", JsValue(hostProviderToString(self.hostProvider)))
    obj.set("domain", JsValue(self.hostProvider.domain()))
    obj.set("user", optionalStringToJS(self.user))
    obj.set("project", JsValue(self.project))
    obj.set("committish", optionalStringToJS(self.committish))
    obj.set("default", JsValue(self.toString()))
    obj.set("https", JsValue(self.https()))
    obj.set("ssh", JsValue(self.ssh()))
    obj.set("sshurl", JsValue(self.sshUrl()))
    obj.set("shortcut", JsValue(self.shortcut()))
    obj.set("browse", JsValue(self.browse()))
    return JsValue(obj)
}

/// JS parseUrl 函数
public func jsParseUrl(go: JSGlobalObject, callframe: CallFrame): JsValue {
    let value = callframe.argument(0)
    if (!value.isString()) {
        go.throwInvalidArguments("parseUrl expects a git URL string")
        return JsValue.jsUndefined()
    }

    match (parseUrl(value.toString())) {
        case Some(pair) =>
            let obj = JsObject.make()
            obj.set("url", JsValue(pair.urlSlice()))
            obj.set("protocol", JsValue(urlProtocolToString(pair.protocol)))
            obj.set("corrected", JsValue(pair.wasCorrected))
            return JsValue(obj)
        case None => return JsValue.jsUndefined()
    }
}

/// JS fromUrl 函数
public func jsFromUrl(go: JSGlobalObject, callframe: CallFrame): JsValue {
    let value = callframe.argument(0)
    if (!value.isString()) {
        go.throwInvalidArguments("fromUrl expects a git URL string")
        return JsValue.jsUndefined()
    }

    match (HostedGitInfo.fromUrl(value.toString())) {
        case Some(info) => hostedGitInfoToJS(info, go)
        case None => JsValue.jsUndefined()
    }
}

private func optionalStringToJS(value: ?String): JsValue {
    match (value) {
        case Some(v) => JsValue(v)
        case None => JsValue.jsUndefined()
    }
}

private func hostProviderToString(provider: HostProvider): String {
    match (provider) {
        case HostProvider.Bitbucket => "bitbucket"
        case HostProvider.Gist => "gist"
        case HostProvider.Github => "github"
        case HostProvider.Gitlab => "gitlab"
        case HostProvider.Sourcehut => "sourcehut"
    }
}

private func urlProtocolToString(protocol: UrlProtocol): String {
    match (protocol) {
        case UrlProtocol.WellFormed(wellFormed) => wellDefinedProtocolToString(wellFormed)
        case UrlProtocol.Custom(value) => value
        case UrlProtocol.Unknown => "unknown"
    }
}

private func wellDefinedProtocolToString(protocol: WellDefinedProtocol): String {
    match (protocol) {
        case WellDefinedProtocol.Git => "git"
        case WellDefinedProtocol.GitPlusFile => "git+file"
        case WellDefinedProtocol.GitPlusFtp => "git+ftp"
        case WellDefinedProtocol.GitPlusHttp => "git+http"
        case WellDefinedProtocol.GitPlusHttps => "git+https"
        case WellDefinedProtocol.GitPlusRsync => "git+rsync"
        case WellDefinedProtocol.GitPlusSsh => "git+ssh"
        case WellDefinedProtocol.Http => "http"
        case WellDefinedProtocol.Https => "https"
        case WellDefinedProtocol.Ssh => "ssh"
        case WellDefinedProtocol.Github => "github"
        case WellDefinedProtocol.Bitbucket => "bitbucket"
        case WellDefinedProtocol.Gitlab => "gitlab"
        case WellDefinedProtocol.Gist => "gist"
        case WellDefinedProtocol.Sourcehut => "sourcehut"
    }
}
