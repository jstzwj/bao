// bao_install - 托管 Git 信息解析
// 严格翻译自: src/install/hosted_git_info.zig
//   解析 Git URL 和 "shortcut" 为结构化表示
//   模拟 npm 包 hosted-git-info 的行为
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// URL 表示类型
// 严格翻译自: src/install/hosted_git_info.zig - Representation
//   const Representation = enum {
//       shortcut, sshurl, ssh, https, git, http
//   }
// ============================================================================

/// URL 表示类型
/// 翻译自: src/install/hosted_git_info.zig Representation
public enum GitRepresentation {
    | Shortcut  // foo/bar
    | SshUrl    // git+ssh://git@domain/user/project.git#committish
    | Ssh       // ssh://domain/user/project.git#committish
    | Https     // https://domain/user/project.git#committish
    | Git       // git://domain/user/project.git#committish
    | Http      // http://domain/user/project.git#committish

    public func toString(): String {
        match (this) {
            case Shortcut => "shortcut"
            case SshUrl => "sshurl"
            case Ssh => "ssh"
            case Https => "https"
            case Git => "git"
            case Http => "http"
        }
    }
}

// ============================================================================
// 已知协议
// 严格翻译自: src/install/hosted_git_info.zig - WellDefinedProtocol
//   pub const WellDefinedProtocol = enum {
//       git, git_plus_file, git_plus_ftp, git_plus_http, git_plus_https,
//       git_plus_rsync, git_plus_ssh, http, https, ssh,
//       github, bitbucket, gitlab, gist, sourcehut
//   }
// ============================================================================

/// 已知协议
/// 翻译自: src/install/hosted_git_info.zig WellDefinedProtocol
public enum WellDefinedProtocol {
    | Git
    | GitPlusFile
    | GitPlusFtp
    | GitPlusHttp
    | GitPlusHttps
    | GitPlusRsync
    | GitPlusSsh
    | Http
    | Https
    | Ssh
    // 快捷方式协议
    | Github
    | Bitbucket
    | Gitlab
    | Gist
    | Sourcehut

    /// 从协议字符串 (不含冒号) 解析
    /// 翻译自: WellDefinedProtocol.strings (ComptimeStringMap)
    public static func fromString(protocol: String): ?WellDefinedProtocol {
        if (protocol == "git") { return Git }
        if (protocol == "git+file") { return GitPlusFile }
        if (protocol == "git+ftp") { return GitPlusFtp }
        if (protocol == "git+http") { return GitPlusHttp }
        if (protocol == "git+https") { return GitPlusHttps }
        if (protocol == "git+rsync") { return GitPlusRsync }
        if (protocol == "git+ssh") { return GitPlusSsh }
        if (protocol == "http") { return Http }
        if (protocol == "https") { return Https }
        if (protocol == "ssh") { return Ssh }
        if (protocol == "github") { return Github }
        if (protocol == "bitbucket") { return Bitbucket }
        if (protocol == "gitlab") { return Gitlab }
        if (protocol == "gist") { return Gist }
        if (protocol == "sourcehut") { return Sourcehut }
        return None
    }

    /// 从带冒号的协议字符串解析 (如 "https:")
    /// 翻译自: WellDefinedProtocol.fromStringWithColon
    public static func fromStringWithColon(protocolWithColon: String): ?WellDefinedProtocol {
        if (protocolWithColon.size == 0) { return None }
        var proto = protocolWithColon
        if (proto.endsWith(":")) {
            proto = proto[..proto.size - 1]
        }
        return fromString(proto)
    }

    /// 转为协议字符串
    public func toString(): String {
        match (this) {
            case Git => "git"
            case GitPlusFile => "git+file"
            case GitPlusFtp => "git+ftp"
            case GitPlusHttp => "git+http"
            case GitPlusHttps => "git+https"
            case GitPlusRsync => "git+rsync"
            case GitPlusSsh => "git+ssh"
            case Http => "http"
            case Https => "https"
            case Ssh => "ssh"
            case Github => "github"
            case Bitbucket => "bitbucket"
            case Gitlab => "gitlab"
            case Gist => "gist"
            case Sourcehut => "sourcehut"
        }
    }

    /// 获取带冒号的协议字符串
    /// 翻译自: WellDefinedProtocol.toStringWithColon
    public func toStringWithColon(): String {
        return "${toString()}:"
    }

    /// 协议资源标识符连接标记 (:// 或 "")
    /// 翻译自: WellDefinedProtocol.protocolResourceIdentifierConcatenationToken
    public func concatenationToken(): String {
        match (this) {
            case Git | GitPlusFile | GitPlusFtp | GitPlusHttp | GitPlusHttps |
                 GitPlusRsync | GitPlusSsh | Http | Https | Ssh => "//"
            case Github | Bitbucket | Gitlab | Gist | Sourcehut => ""
        }
    }

    /// 默认表示方式
    /// 翻译自: WellDefinedProtocol.defaultRepresentation
    public func defaultRepresentation(): GitRepresentation {
        match (this) {
            case GitPlusSsh | Ssh | GitPlusHttp => GitRepresentation.SshUrl
            case GitPlusHttps => GitRepresentation.Https
            case GitPlusFile | GitPlusFtp | GitPlusRsync | Git => GitRepresentation.Git
            case Http => GitRepresentation.Http
            case Https => GitRepresentation.Https
            case Github | Bitbucket | Gitlab | Gist | Sourcehut => GitRepresentation.Shortcut
        }
    }

    /// 获取关联的主机提供商
    /// 翻译自: WellDefinedProtocol.hostProvider
    public func hostProvider(): ?HostProvider {
        match (this) {
            case Github => HostProvider.Github
            case Bitbucket => HostProvider.Bitbucket
            case Gitlab => HostProvider.Gitlab
            case Gist => HostProvider.Gist
            case Sourcehut => HostProvider.Sourcehut
            case _ => None
        }
    }

    /// 是否是快捷方式
    /// 翻译自: WellDefinedProtocol.isShortcut
    public func isShortcut(): Bool {
        match (this) {
            case Github | Bitbucket | Gitlab | Gist | Sourcehut => true
            case _ => false
        }
    }
}

// ============================================================================
// URL 协议
// 严格翻译自: src/install/hosted_git_info.zig - UrlProtocol
//   pub const UrlProtocol = union(enum) {
//       well_formed: WellDefinedProtocol,
//       custom: []const u8,
//       unknown
//   }
// ============================================================================

/// URL 协议
/// 翻译自: src/install/hosted_git_info.zig UrlProtocol
public enum UrlProtocol {
    | WellFormed(WellDefinedProtocol)
    | Custom(String)
    | Unknown

    /// 获取默认表示
    /// 翻译自: UrlProtocol.defaultRepresentation
    public func defaultRepresentation(): GitRepresentation {
        match (this) {
            case WellFormed(wf) => wf.defaultRepresentation()
            case Custom(_) | Unknown => GitRepresentation.SshUrl
        }
    }
}

// ============================================================================
// URL 协议对
// 严格翻译自: src/install/hosted_git_info.zig - UrlProtocolPair
//   pub const UrlProtocolPair = struct {
//       url: union(enum) { managed: ..., unmanaged: []const u8 },
//       protocol: UrlProtocol,
//       pub fn urlSlice(...)
//       pub fn deinit(...)
//       fn toUrl(...)
//       fn concatPartsToUrl(...)
//   }
// ============================================================================

/// URL 协议对
/// 翻译自: src/install/hosted_git_info.zig UrlProtocolPair
///   包含 URL 字符串和已解析的协议
public class UrlProtocolPair {
    /// URL 字符串
    public var url: String
    /// 是否为托管 (owned) 内存
    public var urlOwned: Bool
    /// 协议
    public var protocol: UrlProtocol

    public init(url: String, protocol: UrlProtocol) {
        this.url = url
        this.urlOwned = false
        this.protocol = protocol
    }

    public init(url: String, protocol: UrlProtocol, urlOwned: Bool) {
        this.url = url
        this.urlOwned = urlOwned
        this.protocol = protocol
    }

    /// 获取 URL 切片
    /// 翻译自: UrlProtocolPair.urlSlice
    public func urlSlice(): String {
        return url
    }

    /// 释放资源
    /// 翻译自: UrlProtocolPair.deinit
    public func deinit(): Unit {
        // 在仓颉中由 GC 管理
    }

    /// 将协议对转换为 URL
    /// 翻译自: UrlProtocolPair.toUrl
    ///   根据协议类型拼接 URL 字符串并解析
    public func toUrl(): ?ParsedUrl {
        let protoToken: String = match (protocol) {
            case UrlProtocol.Unknown => "git+ssh://"
            case UrlProtocol.Custom(protoStr) => "${protoStr}//"
            case UrlProtocol.WellFormed(wf) =>
                "${wf.toStringWithColon()}${wf.concatenationToken()}"
        }

        let fullUrl = "${protoToken}${url}"
        return ParsedUrl.parse(fullUrl)
    }
}

/// 简化的 URL 解析结果
/// 翻译自: UrlProtocolPair.toUrl 返回的 jsc.URL 简化
public class ParsedUrl {
    /// 完整 URL
    public var href: String
    /// 协议 (含冒号)
    public var protocol: String
    /// 主机名
    public var hostname: String
    /// 路径名
    public var pathname: String
    /// Fragment 标识符 (#后面的内容)
    public var fragment: String

    public init() {
        href = ""
        protocol = ""
        hostname = ""
        pathname = ""
        fragment = ""
    }

    public init(href: String, protocol: String, hostname: String, pathname: String, fragment: String) {
        this.href = href
        this.protocol = protocol
        this.hostname = hostname
        this.pathname = pathname
        this.fragment = fragment
    }

    /// 简化的 URL 解析
    /// 翻译自: jsc.URL.fromString
    public static func parse(urlStr: String): ?ParsedUrl {
        let result = ParsedUrl()
        result.href = urlStr

        // 提取协议
        let colonIdx = urlStr.indexOf("://")
        let protoEnd: Int64 = match (colonIdx) {
            case Some(i) => i + Int64(3)
            case None =>
                let simpleColon = urlStr.indexOf(":")
                match (simpleColon) {
                    case Some(j) => j + Int64(1)
                    case None => Int64(0)
                }
        }

        if (protoEnd > 0 && protoEnd <= urlStr.size) {
            result.protocol = urlStr[..protoEnd]
        }

        var afterProto = if (protoEnd > 0 && protoEnd < urlStr.size) {
            urlStr[Int64(protoEnd)..]
        } else {
            urlStr
        }

        // 提取主机名
        let hostEnd = afterProto.indexOf("/")
        match (hostEnd) {
            case Some(he) =>
                result.hostname = afterProto[..he]
                var pathPart = if (he + 1 < afterProto.size) { afterProto[Int64(he) + 1..] } else { "" }
                // 分离 fragment
                let fragIdx = pathPart.indexOf("#")
                match (fragIdx) {
                    case Some(fi) =>
                        result.pathname = pathPart[..fi]
                        result.fragment = if (fi + 1 < pathPart.size) { pathPart[Int64(fi) + 1..] } else { "" }
                    case None =>
                        result.pathname = pathPart
                        result.fragment = ""
                }
            case None =>
                result.hostname = afterProto
                result.pathname = ""
                result.fragment = ""
        }

        return result
    }

    /// 获取路径名 (去掉前导 /)
    /// 翻译自: url.pathname() + trimPrefixComptime
    public func pathnameTrimmed(): String {
        if (pathname.startsWith("/")) {
            return if (pathname.size > 1) { pathname[1..] } else { "" }
        }
        return pathname
    }

    /// 获取主机名 (去掉 www. 前缀)
    /// 翻译自: url.hostname() + withoutPrefixComptime("www.")
    public func hostnameWithoutWww(): String {
        if (hostname.startsWith("www.")) {
            return hostname[4..]
        }
        return hostname
    }

    /// 获取协议 (不含冒号)
    public func protocolWithoutColon(): String {
        if (protocol.endsWith(":")) {
            return protocol[..protocol.size - 1]
        }
        if (protocol.endsWith("://")) {
            return protocol[..protocol.size - 3]
        }
        return protocol
    }
}

// ============================================================================
// 主机提供商
// 严格翻译自: src/install/hosted_git_info.zig - HostProvider
//   const HostProvider = enum {
//       bitbucket, gist, github, gitlab, sourcehut
//   }
//   每个 HostProvider 有不同的 URL 格式化规则
// ============================================================================

/// 主机提供商配置
/// 翻译自: HostProvider.Config struct
///   每个提供商的配置 (协议列表、域名、快捷方式、路径等)
public class HostProviderConfig {
    /// 支持的协议
    public var protocols: ArrayList<WellDefinedProtocol>
    /// 域名
    public var domain: String
    /// 快捷方式前缀 (含冒号)
    public var shortcut: String
    /// tree 路径 (如 "tree")
    public var treePath: ?String
    /// blob 路径 (如 "blob")
    public var blobPath: ?String
    /// edit 路径
    public var editPath: ?String

    public init() {
        protocols = ArrayList<WellDefinedProtocol>()
        domain = ""
        shortcut = ""
        treePath = None
        blobPath = None
        editPath = None
    }

    public init(protocols: ArrayList<WellDefinedProtocol>, domain: String, shortcut: String,
                treePath: ?String, blobPath: ?String, editPath: ?String) {
        this.protocols = protocols
        this.domain = domain
        this.shortcut = shortcut
        this.treePath = treePath
        this.blobPath = blobPath
        this.editPath = editPath
    }
}

/// 主机提供商
/// 翻译自: src/install/hosted_git_info.zig HostProvider
public enum HostProvider {
    | Bitbucket
    | Gist
    | Github
    | Gitlab
    | Sourcehut

    // ===== 配置 =====

    /// 获取提供商配置
    /// 翻译自: HostProvider.configs (EnumArray)
    public func config(): HostProviderConfig {
        match (this) {
            case Bitbucket =>
                let protos = ArrayList<WellDefinedProtocol>()
                protos.append(WellDefinedProtocol.GitPlusHttp)
                protos.append(WellDefinedProtocol.GitPlusHttps)
                protos.append(WellDefinedProtocol.Ssh)
                protos.append(WellDefinedProtocol.Https)
                return HostProviderConfig(protos, "bitbucket.org", "bitbucket:",
                    Some("src"), Some("src"), Some("?mode=edit"))
            case Gist =>
                let protos = ArrayList<WellDefinedProtocol>()
                protos.append(WellDefinedProtocol.Git)
                protos.append(WellDefinedProtocol.GitPlusSsh)
                protos.append(WellDefinedProtocol.GitPlusHttps)
                protos.append(WellDefinedProtocol.Ssh)
                protos.append(WellDefinedProtocol.Https)
                return HostProviderConfig(protos, "gist.github.com", "gist:",
                    Option<String>.None, Option<String>.None, Some("edit"))
            case Github =>
                let protos = ArrayList<WellDefinedProtocol>()
                protos.append(WellDefinedProtocol.Git)
                protos.append(WellDefinedProtocol.Http)
                protos.append(WellDefinedProtocol.GitPlusSsh)
                protos.append(WellDefinedProtocol.GitPlusHttps)
                protos.append(WellDefinedProtocol.Ssh)
                protos.append(WellDefinedProtocol.Https)
                return HostProviderConfig(protos, "github.com", "github:",
                    Some("tree"), Some("blob"), Some("edit"))
            case Gitlab =>
                let protos = ArrayList<WellDefinedProtocol>()
                protos.append(WellDefinedProtocol.GitPlusSsh)
                protos.append(WellDefinedProtocol.GitPlusHttps)
                protos.append(WellDefinedProtocol.Ssh)
                protos.append(WellDefinedProtocol.Https)
                return HostProviderConfig(protos, "gitlab.com", "gitlab:",
                    Some("tree"), Some("tree"), Some("-/edit"))
            case Sourcehut =>
                let protos = ArrayList<WellDefinedProtocol>()
                protos.append(WellDefinedProtocol.GitPlusSsh)
                protos.append(WellDefinedProtocol.Https)
                return HostProviderConfig(protos, "git.sr.ht", "sourcehut:",
                    Some("tree"), Some("tree"), Option<String>.None)
        }
    }

    /// 获取域名
    /// 翻译自: HostProvider.Config.domain
    public func domain(): String {
        return config().domain
    }

    /// 获取快捷方式前缀 (含冒号)
    /// 翻译自: HostProvider.Config.shortcut
    public func shortcut(): String {
        return config().shortcut
    }

    /// 获取快捷方式前缀 (不含冒号)
    /// 翻译自: HostProvider.Config.shortcutWithoutColon
    public func shortcutWithoutColon(): String {
        let shct = shortcut()
        return shct[..shct.size - 1]
    }

    /// 获取 tree 路径
    /// 翻译自: HostProvider.Config.tree_path
    public func treePath(): ?String {
        return config().treePath
    }

    /// 获取 blob 路径
    /// 翻译自: HostProvider.Config.blob_path
    public func blobPath(): ?String {
        return config().blobPath
    }

    /// 获取 edit 路径
    /// 翻译自: HostProvider.Config.edit_path
    public func editPath(): ?String {
        return config().editPath
    }

    /// 获取类型名称字符串
    /// 翻译自: HostProvider.typeStr
    public func typeStr(): String {
        match (this) {
            case Bitbucket => "bitbucket"
            case Gist => "gist"
            case Github => "github"
            case Gitlab => "gitlab"
            case Sourcehut => "sourcehut"
        }
    }

    /// 支持的协议
    /// 翻译自: HostProvider.Config.protocols
    public func protocols(): ArrayList<WellDefinedProtocol> {
        return config().protocols
    }

    // ===== 查找方法 =====

    /// 从 URL 域名推断主机提供商
    /// 翻译自: HostProvider.fromUrlDomain
    public static func fromUrlDomain(url: String): ?HostProvider {
        if (url.contains("github.com") || url.contains("github:")) { return Github }
        if (url.contains("gitlab.com") || url.contains("gitlab:")) { return Gitlab }
        if (url.contains("bitbucket.org") || url.contains("bitbucket:")) { return Bitbucket }
        if (url.contains("gist.github.com") || url.contains("gist:")) { return Gist }
        if (url.contains("git.sr.ht") || url.contains("sourcehut:")) { return Sourcehut }
        return None
    }

    /// 从域名精确匹配
    /// 翻译自: HostProvider.fromDomain
    public static func fromDomain(domainStr: String): ?HostProvider {
        if (domainStr == "github.com") { return Github }
        if (domainStr == "gitlab.com") { return Gitlab }
        if (domainStr == "bitbucket.org") { return Bitbucket }
        if (domainStr == "gist.github.com") { return Gist }
        if (domainStr == "git.sr.ht") { return Sourcehut }
        return None
    }

    /// 从快捷方式查找提供商
    /// 翻译自: HostProvider.fromShortcut
    ///   withColon: 是否包含冒号
    public static func fromShortcut(shortcutStr: String, withColon: Bool): ?HostProvider {
        if (withColon) {
            if (shortcutStr == "github:") { return Github }
            if (shortcutStr == "gitlab:") { return Gitlab }
            if (shortcutStr == "bitbucket:") { return Bitbucket }
            if (shortcutStr == "gist:") { return Gist }
            if (shortcutStr == "sourcehut:") { return Sourcehut }
        } else {
            if (shortcutStr == "github") { return Github }
            if (shortcutStr == "gitlab") { return Gitlab }
            if (shortcutStr == "bitbucket") { return Bitbucket }
            if (shortcutStr == "gist") { return Gist }
            if (shortcutStr == "sourcehut") { return Sourcehut }
        }
        return None
    }

    /// 从 URL 对象解析主机提供商
    /// 翻译自: HostProvider.fromUrl
    public static func fromUrl(url: ParsedUrl): ?HostProvider {
        // 尝试快捷方式
        let proto = url.protocolWithoutColon()
        let fromShortcut = fromShortcut(proto, false)
        match (fromShortcut) {
            case Some(p) => return p
            case None => ()
        }
        return fromUrlDomain(url.hostnameWithoutWww())
    }

    // ===== 格式化方法 =====

    /// 格式化 SSH URL (SCP 样式)
    /// 翻译自: HostProvider.Config.formatters.ssh
    ///   git@domain:user/project.git#committish
    public func formatSsh(user: ?String, project: String, committish: ?String): String {
        let cmsh = match (committish) {
            case Some(c) => c
            case None => ""
        }
        let cmshSep = if (cmsh.size > 0) { "#" } else { "" }

        match (this) {
            case Gist=> return "git@${domain()}:${project}.git${cmshSep}${cmsh}"
            case _ =>
                let userName = match (user) {
                    case Some(u) => u
                    case None => "git"
                }
                return "git@${domain()}:${userName}/${project}.git${cmshSep}${cmsh}"
        }
    }

    /// 格式化 SSH URL (URL 形式)
    /// 翻译自: HostProvider.Config.formatters.ssh_url
    ///   git+ssh://git@domain/user/project.git#committish
    public func formatSshUrl(user: ?String, project: String, committish: ?String): String {
        let cmsh = match (committish) {
            case Some(c) => c
            case None => ""
        }
        let cmshSep = if (cmsh.size > 0) { "#" } else { "" }

        match (this) {
            case Gist=> return "git+ssh://git@${domain()}/${project}.git${cmshSep}${cmsh}"
            case _ =>
                let userName = match (user) {
                    case Some(u) => u
                    case None => "git"
                }
                return "git+ssh://git@${domain()}/${userName}/${project}.git${cmshSep}${cmsh}"
        }
    }

    /// 格式化 HTTPS URL
    /// 翻译自: HostProvider.Config.formatters.https
    ///   git+https://domain/user/project.git#committish
    public func formatHttps(auth: ?String, user: ?String, project: String, committish: ?String): String {
        let cmsh = match (committish) {
            case Some(c) => c
            case None => ""
        }
        let cmshSep = if (cmsh.size > 0) { "#" } else { "" }
        let authStr = match (auth) {
            case Some(a) => a
            case None => ""
        }
        let authSep = if (authStr.size > 0) { "@" } else { "" }

        match (this) {
            case Gist=> return "git+https://${domain()}/${project}.git${cmshSep}${cmsh}"
            case Sourcehut =>
                let userName = match (user) {
                    case Some(u) => u
                    case None => "git"
                }
                return "https://${domain()}/${userName}/${project}.git${cmshSep}${cmsh}"
            case _ =>
                let userName = match (user) {
                    case Some(u) => u
                    case None => "git"
                }
                return "git+https://${authStr}${authSep}${domain()}/${userName}/${project}.git${cmshSep}${cmsh}"
        }
    }

    /// 格式化快捷方式
    /// 翻译自: HostProvider.Config.formatters.shortcut
    ///   shortcut:user/project#committish
    public func formatShortcut(user: ?String, project: String, committish: ?String): String {
        let cmsh = match (committish) {
            case Some(c) => c
            case None => ""
        }
        let cmshSep = if (cmsh.size > 0) { "#" } else { "" }

        match (this) {
            case Gist =>
                return "${shortcutWithoutColon()}:${project}${cmshSep}${cmsh}"
            case _ =>
                match (user) {
                    case Some(u) => return "${shortcutWithoutColon()}:${u}/${project}${cmshSep}${cmsh}"
                    case None => return "${shortcutWithoutColon()}:${project}${cmshSep}${cmsh}"
                }
        }
    }

    /// 格式化 Git URL
    /// 翻译自: HostProvider.Config.formatters.git
    ///   git://domain/user/project.git#committish
    public func formatGit(auth: ?String, user: ?String, project: String, committish: ?String): String {
        let cmsh = match (committish) {
            case Some(c) => c
            case None => ""
        }
        let cmshSep = if (cmsh.size > 0) { "#" } else { "" }
        let authStr = match (auth) {
            case Some(a) => a
            case None => ""
        }
        let authSep = if (authStr.size > 0) { "@" } else { "" }

        match (this) {
            case Gist => return "git://${domain()}/${project}.git${cmshSep}${cmsh}"
            case _ =>
                let userName = match (user) {
                    case Some(u) => u
                    case None => "git"
                }
                return "git://${authStr}${authSep}${domain()}/${userName}/${project}.git${cmshSep}${cmsh}"
        }
    }

    // ===== 提取方法 =====

    /// 从 URL 提取 user 和 project (通用入口)
    /// 翻译自: HostProvider.extract
    ///   分发到各提供商特定的提取函数
    public func extract(urlStr: String): ?GitExtractResult {
        match (this) {
            case Github => extractGithub(urlStr)
            case Bitbucket => extractBitbucket(urlStr)
            case Gitlab => extractGitlab(urlStr)
            case Gist => extractGist(urlStr)
            case Sourcehut => extractSourcehut(urlStr)
        }
    }

    /// GitHub 风格提取
    /// 翻译自: HostProvider.Config.formatters.extract.github
    ///   解析 pathname 为 user/project[/tree/committish]
    public func extractGithub(urlStr: String): ?GitExtractResult {
        let url = ParsedUrl.parse(urlStr)
        match (url) {
            case Some(u) =>
                var pathname = u.pathnameTrimmed()
                if (pathname.size == 0) { return None }

                var iter = StringSplitter.split(pathname, "/")
                let userPart = iter.next()
                let projectPart = iter.next()
                let typePart = iter.next()
                let committishPart = iter.next()

                match (userPart) {
                    case None => return None
                    case Some(_) => ()
                }
                match (projectPart) {
                    case None => return None
                    case Some(pp) =>
                        let project = trimGitSuffix(pp)
                        if (userPart.getOrThrow().size == 0 || project.size == 0) { return None }

                        // type_part 为 "tree" 时 committish 在 URL 中
                        var committish: ?String = None
                        match (typePart) {
                            case Some(tp) =>
                                if (tp == "tree") {
                                    committish = committishPart
                                }
                            case None =>
                                // committish 来自 fragment
                                if (u.fragment.size > 0) {
                                    committish = Some(u.fragment)
                                }
                        }

                        return GitExtractResult(
                            Some(decodePercent(userPart.getOrThrow())),
                            decodePercent(project),
                            match (committish) {
                                case Some(c) => Some(decodePercent(c))
                                case None => None
                            }
                        )
                }
            case None => return None
        }
    }

    /// Bitbucket 风格提取
    /// 翻译自: HostProvider.Config.formatters.extract.bitbucket
    ///   如果有 aux="get" 则返回 null
    public func extractBitbucket(urlStr: String): ?GitExtractResult {
        let url = ParsedUrl.parse(urlStr)
        match (url) {
            case Some(u) =>
                var pathname = u.pathnameTrimmed()
                if (pathname.size == 0) { return None }

                var iter = StringSplitter.split(pathname, "/")
                let userPart = iter.next()
                let projectPart = iter.next()
                let aux = iter.next()

                // 如果 aux == "get" 则不是标准 URL
                match (aux) {
                    case Some(a) =>
                        if (a == "get") { return None }
                    case None => ()
                }

                match (userPart) {
                    case None => return None
                    case Some(_) => ()
                }
                match (projectPart) {
                    case None => return None
                    case Some(pp) =>
                        let project = trimGitSuffix(pp)
                        if (userPart.getOrThrow().size == 0 || project.size == 0) { return None }

                        var committish: ?String = None
                        if (u.fragment.size > 0) {
                            committish = Some(u.fragment)
                        }

                        return GitExtractResult(
                            Some(decodePercent(userPart.getOrThrow())),
                            decodePercent(project),
                            committish
                        )
                }
            case None => return None
        }
    }

    /// GitLab 风格提取
    /// 翻译自: HostProvider.Config.formatters.extract.gitlab
    ///   拒绝包含 "/-/" 或 "/archive.tar.gz" 的路径
    ///   使用最后一个 "/" 分隔 user 和 project
    public func extractGitlab(urlStr: String): ?GitExtractResult {
        let url = ParsedUrl.parse(urlStr)
        match (url) {
            case Some(u) =>
                var pathname = u.pathnameTrimmed()
                if (pathname.size == 0) { return None }

                // 拒绝特殊路径
                if (pathname.contains("/-/")) { return None }
                if (pathname.contains("/archive.tar.gz")) { return None }

                let lastSlash = pathname.lastIndexOf("/")
                match (lastSlash) {
                    case Some(endSlash) =>
                        let userPart = pathname[..endSlash]
                        let projectPart = pathname[Int64(endSlash) + 1..]
                        let project = trimGitSuffix(projectPart)

                        if (userPart.size == 0 || project.size == 0) { return None }

                        var committish: ?String = None
                        if (u.fragment.size > 0) {
                            committish = Some(u.fragment)
                        }

                        return GitExtractResult(
                            Some(decodePercent(userPart)),
                            decodePercent(project),
                            committish
                        )
                    case None => return None
                }
            case None => return None
        }
    }

    /// Gist 风格提取
    /// 翻译自: HostProvider.Config.formatters.extract.gist
    ///   只有 project 时 user 为 null
    ///   如果有 aux="raw" 则返回 null
    public func extractGist(urlStr: String): ?GitExtractResult {
        let url = ParsedUrl.parse(urlStr)
        match (url) {
            case Some(u) =>
                var pathname = u.pathnameTrimmed()
                if (pathname.size == 0) { return None }

                var iter = StringSplitter.split(pathname, "/")
                var userPart = iter.next()
                var projectPart = iter.next()
                let aux = iter.next()

                // 如果有 aux="raw" 则返回 null
                match (aux) {
                    case Some(a) =>
                        if (a == "raw") { return None }
                    case None => ()
                }

                match (projectPart) {
                    case Some(pp) =>
                        if (pp.size == 0) {
                            // 只有 project, 没有 user
                            projectPart = userPart
                            userPart = None
                        }
                    case None =>
                        // 只有 project, 没有 user
                        projectPart = userPart
                        userPart = None
                }

                let project = trimGitSuffix(projectPart.getOrThrow())
                let user = match (userPart) {
                    case Some(up) => if (up.size > 0) { Some(decodePercent(up)) } else { Option<String>.None }
                    case None => Option<String>.None
                }

                if (project.size == 0) { return None }

                var committish: ?String = None
                if (u.fragment.size > 0) {
                    committish = Some(u.fragment)
                }

                return GitExtractResult(user, decodePercent(project), committish)
            case None => return None
        }
    }

    /// Sourcehut 风格提取
    /// 翻译自: HostProvider.Config.formatters.extract.sourcehut
    ///   如果有 aux="archive" 则返回 null
    public func extractSourcehut(urlStr: String): ?GitExtractResult {
        let url = ParsedUrl.parse(urlStr)
        match (url) {
            case Some(u) =>
                var pathname = u.pathnameTrimmed()
                if (pathname.size == 0) { return None }

                var iter = StringSplitter.split(pathname, "/")
                let userPart = iter.next()
                let projectPart = iter.next()
                let aux = iter.next()

                match (aux) {
                    case Some(a) =>
                        if (a == "archive") { return None }
                    case None => ()
                }

                match (userPart) {
                    case None => return None
                    case Some(_) => ()
                }
                match (projectPart) {
                    case None => return None
                    case Some(pp) =>
                        let project = trimGitSuffix(pp)
                        if (userPart.getOrThrow().size == 0 || project.size == 0) { return None }

                        var committish: ?String = None
                        if (u.fragment.size > 0) {
                            committish = Some(u.fragment)
                        }

                        return GitExtractResult(
                            Some(decodePercent(userPart.getOrThrow())),
                            decodePercent(project),
                            committish
                        )
                }
            case None => return None
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// Git 提取结果
/// 翻译自: HostProvider.Config.formatters.extract.Result
public class GitExtractResult {
    public var user: ?String
    public var project: String
    public var committish: ?String

    public init(user: ?String, project: String, committish: ?String) {
        this.user = user
        this.project = project
        this.committish = committish
    }
}

/// 字符串分割迭代器
/// 翻译自: std.mem.splitScalar
public class StringSplitter {
    private var str: String
    private var delimiter: String
    private var pos: Int64

    private init(str: String, delimiter: String) {
        this.str = str
        this.delimiter = delimiter
        pos = 0
    }

    public static func split(str: String, delimiter: String): StringSplitter {
        return StringSplitter(str, delimiter)
    }

    public func next(): ?String {
        if (pos >= str.size) { return None }
        let idx = str.indexOf(delimiter, pos)
        match (idx) {
            case Some(i) =>
                let result = str[pos..i]
                pos = i + Int64(delimiter.size)
                return result
            case None =>
                let result = str[pos..]
                pos = str.size
                return result
        }
    }

    /// 获取剩余未分割的部分
    public func rest(): String {
        if (pos >= str.size) { return "" }
        return str[pos..]
    }
}

// ============================================================================
// HostedGitInfo
// 严格翻译自: src/install/hosted_git_info.zig - HostedGitInfo
//   pub const HostedGitInfo = struct {
//       committish: ?[]const u8,
//       project: []const u8,
//       user: ?[]const u8,
//       host_provider: HostProvider,
//       default_representation: Representation,
//       _memory_buffer: []const u8,
//       _allocator: std.mem.Allocator,
//       ...
//   }
// ============================================================================

/// 字符串对
/// 翻译自: HostedGitInfo.StringPair
public class HostedGitInfoStringPair {
    public var saveSpec: String
    public var fetchSpec: ?String

    public init(saveSpec: String, fetchSpec: ?String) {
        this.saveSpec = saveSpec
        this.fetchSpec = fetchSpec
    }
}

/// 托管 Git 信息
/// 对应 Bun: HostedGitInfo
/// 翻译自: src/install/hosted_git_info.zig HostedGitInfo
public class HostedGitInfo {
    /// commit hash / tag / branch
    /// 对应 Bun: committish: ?[]const u8
    public var committish: ?String
    /// 项目名
    /// 对应 Bun: project: []const u8
    public var project: String
    /// 用户名
    /// 对应 Bun: user: ?[]const u8
    public var user: ?String
    /// 主机提供商
    /// 对应 Bun: host_provider: HostProvider
    public var hostProvider: HostProvider
    /// 默认表示方式
    /// 对应 Bun: default_representation: Representation
    public var defaultRepresentation: GitRepresentation

    public init() {
        committish = None
        project = ""
        user = None
        hostProvider = HostProvider.Github
        defaultRepresentation = GitRepresentation.Shortcut
    }

    public init(project: String, user: ?String, committish: ?String, hostProvider: HostProvider, defaultRepresentation: GitRepresentation) {
        this.project = project
        this.user = user
        this.committish = committish
        this.hostProvider = hostProvider
        this.defaultRepresentation = defaultRepresentation
    }

    /// 从 URL 字符串解析 HostedGitInfo
    /// 翻译自: HostedGitInfo.fromUrl
    ///   pub fn fromUrl(allocator, git_url) error{ OutOfMemory, InvalidURL }!?Self { ... }
    public static func fromUrl(gitUrl: String): ?HostedGitInfo {
        var urlMut = gitUrl

        // 检测 GitHub 快捷方式
        if (isGitHubShorthand(gitUrl)) {
            urlMut = "github:${gitUrl}"
        }

        // 解析 URL
        let parsed = parseUrl(urlMut)
        match (parsed) {
            case None => return None
            case Some(pair) =>
                // 获取主机提供商
                let provider: ?HostProvider = match (pair.protocol) {
                    case UrlProtocol.WellFormed(wf) =>
                        let hp = wf.hostProvider()
                        match (hp) {
                            case Some(p) => Some(p)
                            case None => HostProvider.fromUrlDomain(pair.urlSlice())
                        }
                    case UrlProtocol.Unknown => HostProvider.fromUrlDomain(pair.urlSlice())
                    case UrlProtocol.Custom(_) => HostProvider.fromUrlDomain(pair.urlSlice())
                }

                match (provider) {
                    case None => return None
                    case Some(p) =>
                        let isShortcut = match (pair.protocol) {
                            case UrlProtocol.WellFormed(wf) => wf.isShortcut()
                            case _ => false
                        }

                        if (!isShortcut) {
                            // 非 shortcut 路径: 使用 extract
                            let extracted = p.extract(pair.urlSlice())
                            match (extracted) {
                                case None => return None
                                case Some(result) =>
                                    return HostedGitInfo(
                                        result.project,
                                        result.user,
                                        result.committish,
                                        p,
                                        pair.protocol.defaultRepresentation()
                                    )
                            }
                        }

                        // Shortcut 路径: github:user/repo, gitlab:user/repo 等
                        // 翻译自: from-url.js line 68-96
                        let url = pair.toUrl()
                        match (url) {
                            case None => return None
                            case Some(u) =>
                                var pathname = u.pathnameTrimmed()

                                // Strip auth (from-url.js line 70-74)
                                let firstAt = pathname.indexOf("@")
                                match (firstAt) {
                                    case Some(atIdx) => pathname = pathname[Int64(atIdx) + 1..]
                                    case None => ()
                                }

                                // extract user and project from pathname
                                var userPart: ?String = None
                                let projectPart: String = match (pathname.lastIndexOf("/")) {
                                    case Some(lastSlash) =>
                                        let userStr = pathname[..lastSlash]
                                        if (userStr.size > 0) {
                                            userPart = Some(userStr)
                                        }
                                        pathname[Int64(lastSlash) + 1..]
                                    case None => pathname
                                }

                                // Strip .git suffix
                                let projectTrimmed = trimGitSuffix(projectPart)

                                // Get committish from fragment
                                var committish: ?String = None
                                if (u.fragment.size > 0) {
                                    committish = Some(u.fragment)
                                }

                                return HostedGitInfo(
                                    decodePercent(projectTrimmed),
                                    match (userPart) {
                                        case Some(up) => Some(decodePercent(up))
                                        case None => None
                                    },
                                    match (committish) {
                                        case Some(c) => Some(decodePercent(c))
                                        case None => None
                                    },
                                    p,
                                    GitRepresentation.Shortcut
                                )
                        }
                }
        }
    }

    /// 格式化为指定表示
    public func toString(representation: GitRepresentation): String {
        match (representation) {
            case GitRepresentation.SshUrl => hostProvider.formatSshUrl(user, project, committish)
            case GitRepresentation.Ssh => hostProvider.formatSsh(user, project, committish)
            case GitRepresentation.Https => hostProvider.formatHttps(Option<String>.None, user, project, committish)
            case GitRepresentation.Shortcut => hostProvider.formatShortcut(user, project, committish)
            case GitRepresentation.Git =>
                hostProvider.formatGit(Option<String>.None, user, project, committish)
            case GitRepresentation.Http =>
                let cmsh = match (committish) {
                    case Some(c) => "#${c}"
                    case None => ""
                }
                let userName = match (user) {
                    case Some(u) => u
                    case None => "git"
                }
                return "http://${hostProvider.domain()}/${userName}/${project}.git${cmsh}"
        }
    }

    /// 默认字符串表示
    public func toString(): String {
        return toString(defaultRepresentation)
    }

    /// 获取 HTTPS URL
    public func https(): String {
        return toString(GitRepresentation.Https)
    }

    /// 获取 HTTPS URL (带 auth)
    /// 翻译自: HostedGitInfo.https (带 auth 参数)
    public func httpsWithAuth(auth: ?String): String {
        match (GitRepresentation.Https) {
            case GitRepresentation.Https =>
                hostProvider.formatHttps(auth, user, project, committish)
            case _ => ""
        }
    }

    /// 获取 SSH URL
    public func ssh(): String {
        return toString(GitRepresentation.Ssh)
    }

    /// 获取 SSH URL (URL 形式)
    public func sshUrl(): String {
        return toString(GitRepresentation.SshUrl)
    }

    /// 获取快捷方式
    public func shortcut(): String {
        return toString(GitRepresentation.Shortcut)
    }

    /// 获取 Git URL
    /// 翻译自: HostedGitInfo.git
    public func git(): String {
        return toString(GitRepresentation.Git)
    }

    /// 获取文件浏览 URL
    /// 翻译自: HostedGitInfo.browse
    public func browse(path: ?String, committishOverride: ?String): String {
        let basePath = "https://${hostProvider.domain()}"
        let userName = match (user) {
            case Some(u) => u
            case None => ""
        }
        let cmsh = match (if (committishOverride .isSome()) { committishOverride } else { committish }) {
            case Some(c) => "/tree/${c}"
            case None => ""
        }
        let pathPart = match (path) {
            case Some(p) => "/${p}"
            case None => ""
        }
        let treePath = match (hostProvider.treePath()) {
            case Some(tp) => "/${tp}"
            case None => ""
        }

        match (hostProvider) {
            case HostProvider.Github =>
                return "${basePath}/${userName}/${project}${treePath}${cmsh}${pathPart}"
            case HostProvider.Gitlab =>
                return "${basePath}/${userName}/${project}${treePath}${cmsh}${pathPart}"
            case HostProvider.Bitbucket =>
                return "${basePath}/${userName}/${project}${treePath}${cmsh}${pathPart}"
            case HostProvider.Gist =>
                return "${basePath}/${project}${cmsh}${pathPart}"
            case HostProvider.Sourcehut =>
                return "${basePath}/${userName}/${project}${treePath}${cmsh}${pathPart}"
        }
    }

    /// 获取文件浏览 URL (简化版)
    public func browse(path: ?String): String {
        return browse(path, Option<String>.None)
    }

    /// 获取文件浏览 URL (无参数)
    public func browse(): String {
        return browse(Option<String>.None, Option<String>.None)
    }

    /// 获取 blob/文件 URL
    /// 翻译自: HostedGitInfo.browse + blobPath
    public func file(path: String, committishOverride: ?String): String {
        let basePath = "https://${hostProvider.domain()}"
        let userName = match (user) {
            case Some(u) => u
            case None => ""
        }
        let cmsh = match (if (committishOverride .isSome()) { committishOverride } else { committish }) {
            case Some(c) => c
            case None => ""
        }
        let blobPath = match (hostProvider.blobPath()) {
            case Some(bp) => "/${bp}"
            case None => ""
        }
        let cmshPart = if (cmsh.size > 0) { "/${cmsh}" } else { "" }

        return "${basePath}/${userName}/${project}${blobPath}${cmshPart}/${path}"
    }

    /// 获取 edit URL
    /// 翻译自: HostedGitInfo.browse + editPath
    public func edit(path: ?String, committishOverride: ?String): String {
        let browseUrl = browse(path, committishOverride)
        let editPath = hostProvider.editPath()
        match (editPath) {
            case Some(ep) => return "${browseUrl}/${ep}"
            case None => return browseUrl
        }
    }
}

// ============================================================================
// GitHub 快捷方式检测
// 严格翻译自: src/install/hosted_git_info.zig - isGitHubShorthand
//   pub fn isGitHubShorthand(npa_str: []const u8) bool { ... }
//   检测字符串是否是 GitHub 快捷方式 (user/repo 格式)
// ============================================================================

/// 检测是否是 GitHub 快捷方式
/// 翻译自: src/install/hosted_git_info.zig isGitHubShorthand
///   实现: 单次遍历检测, 匹配 hosted-git-info 的行为
///   翻译自: hosted-git-info/index.js 中的多规则检测
///   - doesNotStartWithDot: 不以 . 开头
///   - doesNotStartWithSlash: 不以 / 开头
///   - atOnlyAfterHash: @ 只能在 # 后出现
///   - colonOnlyAfterHash: : 只能在 # 后出现
///   - spaceOnlyAfterHash: 空格只能在 # 后出现
///   - secondSlashOnlyAfterHash: 第二个 / 只能在 # 后出现
///   - hasSlash: 必须包含 /
///   - doesNotEndWithSlash: 不以 / 结尾
public func isGitHubShorthand(npaStr: String): Bool {
    if (npaStr.size < 1) { return false }
    if (npaStr[0] == UInt8(46) || npaStr[0] == UInt8(47)) { return false }

    var poundIdx: ?Int64 = None
    var seenSlash = false

    for (i in 0..npaStr.size) {
        let c = npaStr[Int64(i)]
        if (c == UInt8(58) || c == UInt8(64)) {
            // : 和 @ 只能在 # 之后出现 (colonOnlyAfterHash, atOnlyAfterHash)
            match (poundIdx) {
                case Some(_) => ()
                case None => return false
            }
        } else if (c == UInt8(35)) {
            poundIdx = Some<Int64>(Int64(i))
        } else if (c == UInt8(47)) {
            // 第二个 / 只能在 # 之后出现 (secondSlashOnlyAfterHash)
            if (seenSlash) {
                match (poundIdx) {
                    case None => return false
                    case Some(_) => ()
                }
            }
            seenSlash = true
        } else {
            // 空格只能在 # 之后出现 (spaceOnlyAfterHash)
            if ((c >= UInt8(9) && c <= UInt8(13)) || c == UInt8(32)) {
                match (poundIdx) {
                    case None => return false
                    case Some(_) => ()
                }
            }
        }
    }

    // 不以 / 结尾 (doesNotEndWithSlash)
    let doesNotEndWithSlash = match (poundIdx) {
        case Some(pi) => pi == 0 || npaStr[Int64(pi) - 1] != UInt8(47)
        case None => npaStr.size >= 1 && npaStr[npaStr.size - 1] != UInt8(47)
    }

    // 必须包含 / (hasSlash)
    return seenSlash && doesNotEndWithSlash
}

// ============================================================================
// 协议标准化
// 严格翻译自: src/install/hosted_git_info.zig - normalizeProtocol
//   fn normalizeProtocol(npa_str: []const u8) UrlProtocolPair { ... }
// ============================================================================

/// 标准化协议
/// 翻译自: src/install/hosted_git_info.zig normalizeProtocol
///   从 URL 字符串中提取协议和剩余部分
///   镜像 hosted-git-info/parse-url.js 中的 correctProtocol 函数
public func normalizeProtocol(npaStr: String): UrlProtocolPair {
    let firstColonIdx = npaStr.indexOf(":")

    // 检查是否是已知协议
    match (firstColonIdx) {
        case Some(colIdx) =>
            let protocolWithColon = npaStr[0..(colIdx + 1)]
            let proto = WellDefinedProtocol.fromStringWithColon(protocolWithColon)
            match (proto) {
                case Some(wfProto) =>
                    // 已知协议
                    var postColon = npaStr[(colIdx + 1)..]
                    if (postColon.startsWith("//")) {
                        postColon = postColon[2..]
                    }
                    return UrlProtocolPair(postColon, UrlProtocol.WellFormed(wfProto))
                case None =>
                    // 不是已知协议, 检查 @ 字符判断是否为 git+ssh
                    let firstAtIdx = npaStr.indexOf("@")
                    match (firstAtIdx) {
                        case Some(atIdx) =>
                            if (colIdx != -1) {
                                if (atIdx > colIdx) {
                                    // user:pass@host -> git+ssh
                                    return UrlProtocolPair(npaStr, UrlProtocol.WellFormed(WellDefinedProtocol.GitPlusSsh))
                                } else {
                                    // user@host:path -> unknown
                                    return UrlProtocolPair(npaStr, UrlProtocol.Unknown)
                                }
                            } else {
                                // user@host (无冒号) -> git+ssh
                                return UrlProtocolPair(npaStr, UrlProtocol.WellFormed(WellDefinedProtocol.GitPlusSsh))
                            }
                        case None => ()
                    }

                    // 检查双斜线 (自定义协议)
                    let dupSlashIdx = npaStr.indexOf("//")
                    match (dupSlashIdx) {
                        case Some(dsIdx) =>
                            if (dsIdx == colIdx + 1) {
                                return UrlProtocolPair(
                                    npaStr[Int64(dsIdx) + 2..],
                                    UrlProtocol.Custom(npaStr[..Int64(dsIdx)])
                                )
                            }
                        case None => ()
                    }

                    // 冒号后内容作为自定义协议
                    let rest = npaStr[Int64(colIdx) + 1..]
                    let customProto = npaStr[..Int64(colIdx) + 1]
                    return UrlProtocolPair(rest, UrlProtocol.Custom(customProto))
            }
        case None =>
            // 没有 : 字符, 检查 @ 判断 git+ssh
            let atIdx = npaStr.indexOf("@")
            match (atIdx) {
                case Some(_) =>
                    return UrlProtocolPair(npaStr, UrlProtocol.WellFormed(WellDefinedProtocol.GitPlusSsh))
                case None =>
                    return UrlProtocolPair(npaStr, UrlProtocol.Unknown)
            }
    }
}

// ============================================================================
// URL 解析
// 严格翻译自: src/install/hosted_git_info.zig - parseUrl
//   pub fn parseUrl(allocator, npa_str) error{ InvalidGitUrl, OutOfMemory }!struct { ... }
// ============================================================================

/// 解析 URL
/// 翻译自: src/install/hosted_git_info.zig parseUrl
///   标准化协议后尝试解析 URL, 失败时尝试修正 SCP 风格 URL
public func parseUrl(npaStr: String): ?UrlProtocolPair {
    let protoPair = normalizeProtocol(npaStr)

    // 尝试直接解析
    let url = protoPair.toUrl()
    match (url) {
        case Some(_) => return protoPair
        case None => ()
    }

    // 解析失败, 尝试修正 SCP 风格 URL
    let corrected = correctUrl(protoPair)
    match (corrected) {
        case Some(pair) =>
            let correctedUrl = pair.toUrl()
            match (correctedUrl) {
                case Some(_) => return pair
                case None => return None
            }
        case None => return None
    }
}

// ============================================================================
// URL 修正
// 严格翻译自: src/install/hosted_git_info.zig - correctUrl
//   pub fn correctUrl(url_proto_pair, allocator) error{OutOfMemory}!UrlProtocolPair
//   将 SCP 风格 URL (user@host:path) 修正为可解析的形式
// ============================================================================

/// 修正 SCP 风格 URL
/// 翻译自: src/install/hosted_git_info.zig correctUrl
///   查找 @ 之前的最后一个 : 并替换为 /
///   这样 user@host:path 变为 user@host/path, 可被标准 URL 解析器处理
public func correctUrl(protoPair: UrlProtocolPair): ?UrlProtocolPair {
    let urlSlice = protoPair.urlSlice()

    // 查找 # 之前的最后一个 @
    let atIdx = lastIndexBeforeChar(urlSlice, UInt8(64), UInt8(35))  // '@', '#'

    // 查找 # 之前的最后一个 :
    let colIdx = lastIndexBeforeChar(urlSlice, UInt8(58), UInt8(35))  // ':', '#'

    if (colIdx .isSome() && atIdx .isSome() && colIdx.getOrThrow() > atIdx.getOrThrow()) {
        // user@host:path -> user@host/path
        let col = colIdx.getOrThrow()
        var corrected = urlSlice
        // 将 : 替换为 /
        corrected = urlSlice[..col] + "/" + urlSlice[Int64(col) + 1..]
        return UrlProtocolPair(corrected, UrlProtocol.WellFormed(WellDefinedProtocol.GitPlusSsh), true)
    }

    if (colIdx.isNone() && match (protoPair.protocol) {
        case UrlProtocol.Unknown => true
        case _ => false
    }) {
        return UrlProtocolPair(urlSlice, UrlProtocol.WellFormed(WellDefinedProtocol.GitPlusSsh))
    }

    return Some(protoPair)
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 在 stopChar 之前查找最后一个 targetChar
/// 翻译自: bun.strings.lastIndexBeforeChar
func lastIndexBeforeChar(str: String, targetChar: UInt8, stopChar: UInt8): ?Int64 {
    var result: ?Int64 = None
    var i: Int64 = 0
    while (i < str.size) {
        if (str[i] == stopChar) { break }
        if (str[i] == targetChar) {
            result = Some(i)
        }
        i += 1
    }
    return result
}

/// 去除 .git 后缀
/// 翻译自: bun.strings.trimSuffixComptime(project_part, ".git")
func trimGitSuffix(s: String): String {
    if (s.size > 4 && s.endsWith(".git")) {
        return s[..s.size - 4]
    }
    return s
}

/// 百分号解码 (简化实现)
/// 翻译自: HostedGitInfo.decodeAndAppend
///   将 %20 等编码序列解码为原始字符
func decodePercent(input: String): String {
    if (!input.contains("%")) { return input }
    var result = StringBuilder()
    var i: Int64 = 0
    while (i < input.size) {
        if (input[i] == UInt8(37) && i + 2 < input.size) {  // '%'
            let high = hexCharValue(input[Int64(i) + 1])
            let low = hexCharValue(input[Int64(i) + 2])
            if (high >= 0 && low >= 0) {
                result.append(String([Rune(UInt32(high << 4 | low))]))
                i += 3
                continue
            }
        }
        result.append(String([Rune(UInt32(input[i]))]))
        i += 1
    }
    return result.toString()
}

/// 十六进制字符转数值
func hexCharValue(c: UInt8): Int64 {
    let v = Int64(c)
    if (v >= 0x30 && v <= 0x39) { return v - 0x30 }      // '0'-'9'
    if (v >= 0x61 && v <= 0x66) { return v - 0x61 + 10 }  // 'a'-'f'
    if (v >= 0x41 && v <= 0x46) { return v - 0x41 + 10 }  // 'A'-'F'
    return -1
}
