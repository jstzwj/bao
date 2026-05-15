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
        if (protocolWithColon.length == 0) { return None }
        var proto = protocolWithColon
        if (proto.endsWith(":")) {
            proto = proto.substring(0, proto.length - 1)
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
// 主机提供商
// 严格翻译自: src/install/hosted_git_info.zig - HostProvider
//   const HostProvider = enum {
//       bitbucket, gist, github, gitlab, sourcehut
//   }
//   每个 HostProvider 有不同的 URL 格式化规则
// ============================================================================

/// 主机提供商
/// 翻译自: src/install/hosted_git_info.zig HostProvider
public enum HostProvider {
    | Bitbucket
    | Gist
    | Github
    | Gitlab
    | Sourcehut

    /// 获取域名
    /// 翻译自: HostProvider.Config.domain
    public func domain(): String {
        match (this) {
            case Github => "github.com"
            case Gitlab => "gitlab.com"
            case Bitbucket => "bitbucket.org"
            case Gist => "gist.github.com"
            case Sourcehut => "git.sr.ht"
        }
    }

    /// 获取快捷方式前缀
    /// 翻译自: HostProvider.Config.shortcut
    public func shortcut(): String {
        match (this) {
            case Github => "github"
            case Gitlab => "gitlab"
            case Bitbucket => "bitbucket"
            case Gist => "gist"
            case Sourcehut => "sourcehut"
        }
    }

    /// 支持的协议
    /// 翻译自: HostProvider.Config.protocols
    public func protocols(): ArrayList<WellDefinedProtocol> {
        let result = ArrayList<WellDefinedProtocol>()
        match (this) {
            case Github => {
                result.append(WellDefinedProtocol.Git)
                result.append(WellDefinedProtocol.GitPlusSsh)
                result.append(WellDefinedProtocol.GitPlusHttps)
                result.append(WellDefinedProtocol.Ssh)
                result.append(WellDefinedProtocol.Https)
                result.append(WellDefinedProtocol.Github)
            }
            case Gitlab => {
                result.append(WellDefinedProtocol.Git)
                result.append(WellDefinedProtocol.GitPlusSsh)
                result.append(WellDefinedProtocol.GitPlusHttps)
                result.append(WellDefinedProtocol.Ssh)
                result.append(WellDefinedProtocol.Https)
                result.append(WellDefinedProtocol.Gitlab)
            }
            case Bitbucket => {
                result.append(WellDefinedProtocol.Git)
                result.append(WellDefinedProtocol.GitPlusSsh)
                result.append(WellDefinedProtocol.GitPlusHttps)
                result.append(WellDefinedProtocol.Ssh)
                result.append(WellDefinedProtocol.Https)
                result.append(WellDefinedProtocol.Bitbucket)
            }
            case Gist => {
                result.append(WellDefinedProtocol.Git)
                result.append(WellDefinedProtocol.GitPlusSsh)
                result.append(WellDefinedProtocol.GitPlusHttps)
                result.append(WellDefinedProtocol.Ssh)
                result.append(WellDefinedProtocol.Https)
                result.append(WellDefinedProtocol.Gist)
            }
            case Sourcehut => {
                result.append(WellDefinedProtocol.Git)
                result.append(WellDefinedProtocol.GitPlusSsh)
                result.append(WellDefinedProtocol.GitPlusHttps)
                result.append(WellDefinedProtocol.Ssh)
                result.append(WellDefinedProtocol.Https)
                result.append(WellDefinedProtocol.Sourcehut)
            }
        }
        return result
    }

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

    /// 格式化 SSH URL
    /// 翻译自: HostProvider.formatSsh
    ///   git@domain:user/project.git#committish
    public func formatSsh(user: ?String, project: String, committish: ?String): String {
        let cmsh = match (committish) {
            case Some(c) => c
            case None => ""
        }
        let cmshSep = if (cmsh.length > 0) { "#" } else { "" }

        match (this) {
            case Gist => {
                return "git@${domain()}:${project}.git${cmshSep}${cmsh}"
            }
            case _ => {
                let userName = match (user) {
                    case Some(u) => u
                    case None => "git"
                }
                return "git@${domain()}:${userName}/${project}.git${cmshSep}${cmsh}"
            }
        }
    }

    /// 格式化 SSH URL (URL 形式)
    /// 翻译自: HostProvider.formatSshUrl
    ///   git+ssh://git@domain/user/project.git#committish
    public func formatSshUrl(user: ?String, project: String, committish: ?String): String {
        let cmsh = match (committish) {
            case Some(c) => c
            case None => ""
        }
        let cmshSep = if (cmsh.length > 0) { "#" } else { "" }

        match (this) {
            case Gist => {
                return "git+ssh://git@${domain()}/${project}.git${cmshSep}${cmsh}"
            }
            case _ => {
                let userName = match (user) {
                    case Some(u) => u
                    case None => "git"
                }
                return "git+ssh://git@${domain()}/${userName}/${project}.git${cmshSep}${cmsh}"
            }
        }
    }

    /// 格式化 HTTPS URL
    /// 翻译自: HostProvider.formatHttps
    ///   git+https://domain/user/project.git#committish
    public func formatHttps(user: ?String, project: String, committish: ?String): String {
        let cmsh = match (committish) {
            case Some(c) => c
            case None => ""
        }
        let cmshSep = if (cmsh.length > 0) { "#" } else { "" }

        match (this) {
            case Gist => {
                return "git+https://${domain()}/${project}.git${cmshSep}${cmsh}"
            }
            case _ => {
                let userName = match (user) {
                    case Some(u) => u
                    case None => "git"
                }
                return "git+https://${domain()}/${userName}/${project}.git${cmshSep}${cmsh}"
            }
        }
    }

    /// 格式化快捷方式
    /// 翻译自: HostProvider.formatShortcut
    ///   shortcut:user/project#committish
    public func formatShortcut(user: ?String, project: String, committish: ?String): String {
        let cmsh = match (committish) {
            case Some(c) => "#${c}"
            case None => ""
        }

        match (user) {
            case Some(u) => return "${shortcut()}:${u}/${project}${cmsh}"
            case None => return "${shortcut()}:${project}${cmsh}"
        }
    }

    /// 从 URL 提取 user 和 project
    /// 翻译自: HostProvider.extract
    public func extract(urlStr: String): ?GitExtractResult {
        var pathname = urlStr
        // 去除协议部分
        let protoEnd = pathname.indexOf("://")
        if (protoEnd >= 0) {
            let afterProto = pathname.substring(protoEnd + 3)
            // 跳过域名
            let domainEnd = afterProto.indexOf("/")
            if (domainEnd >= 0) {
                pathname = afterProto.substring(domainEnd + 1)
            } else {
                pathname = afterProto
            }
        }

        // 去除查询参数和 fragment
        let hashIdx = pathname.indexOf("#")
        var committish: ?String = None
        if (hashIdx >= 0) {
            committish = pathname.substring(hashIdx + 1)
            pathname = pathname.substring(0, hashIdx)
        }

        let queryIdx = pathname.indexOf("?")
        if (queryIdx >= 0) {
            pathname = pathname.substring(0, queryIdx)
        }

        // 去除 .git 后缀
        if (pathname.endsWith(".git")) {
            pathname = pathname.substring(0, pathname.length - 4)
        }

        // 去除尾部斜杠
        while (pathname.endsWith("/")) {
            pathname = pathname.substring(0, pathname.length - 1)
        }

        // 分离 user 和 project
        let lastSlash = pathname.lastIndexOf("/")
        if (lastSlash >= 0) {
            let user = pathname.substring(0, lastSlash)
            let project = pathname.substring(lastSlash + 1)

            if (user.length > 0 && project.length > 0) {
                return GitExtractResult(
                    user: user,
                    project: project,
                    committish: committish
                )
            }
        }

        // 只有 project, 没有 user
        if (pathname.length > 0) {
            return GitExtractResult(
                user: None,
                project: pathname,
                committish: committish
            )
        }

        return None
    }
}

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

// ============================================================================
// HostedGitInfo
// 严格翻译自: src/install/hosted_git_info.zig - HostedGitInfo
//   pub const HostedGitInfo = struct {
//       committish: ?[]const u8,
//       project: []const u8,
//       user: ?[]const u8,
//       host_provider: HostProvider,
//       default_representation: Representation,
//       ...
//   }
// ============================================================================

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
        // 检测 GitHub 快捷方式
        if (isGitHubShorthand(gitUrl)) {
            let prefixed = "github:${gitUrl}"
            return parseUrlAndExtract(prefixed)
        }
        return parseUrlAndExtract(gitUrl)
    }

    /// 解析 URL 并提取信息
    /// 翻译自: HostedGitInfo.fromUrl 中的核心逻辑
    private static func parseUrlAndExtract(gitUrl: String): ?HostedGitInfo {
        // 标准化协议
        let (proto, urlRest) = normalizeProtocol(gitUrl)

        // 获取主机提供商
        let provider: ?HostProvider = match (proto) {
            case UrlProtocol.WellFormed(wf) => {
                match (wf.hostProvider()) {
                    case Some(p) => p
                    case None => HostProvider.fromUrlDomain(urlRest)
                }
            }
            case UrlProtocol.Unknown => HostProvider.fromUrlDomain(urlRest)
            case UrlProtocol.Custom(_) => HostProvider.fromUrlDomain(urlRest)
        }

        match (provider) {
            case Some(p) => {
                // 尝试提取
                match (p.extract(urlRest)) {
                    case Some(result) => {
                        let repr = proto.defaultRepresentation()
                        return HostedGitInfo(
                            project: result.project,
                            user: result.user,
                            committish: result.committish,
                            hostProvider: p,
                            defaultRepresentation: repr
                        )
                    }
                    case None => return None
                }
            }
            case None => return None
        }
    }

    /// 格式化为指定表示
    public func toString(representation: GitRepresentation): String {
        match (representation) {
            case GitRepresentation.SshUrl => hostProvider.formatSshUrl(user, project, committish)
            case GitRepresentation.Ssh => hostProvider.formatSsh(user, project, committish)
            case GitRepresentation.Https => hostProvider.formatHttps(user, project, committish)
            case GitRepresentation.Shortcut => hostProvider.formatShortcut(user, project, committish)
            case GitRepresentation.Git => {
                let cmsh = match (committish) {
                    case Some(c) => "#${c}"
                    case None => ""
                }
                return "git://${hostProvider.domain()}/${project}.git${cmsh}"
            }
            case GitRepresentation.Http => {
                let cmsh = match (committish) {
                    case Some(c) => "#${c}"
                    case None => ""
                }
                return "http://${hostProvider.domain()}/${project}.git${cmsh}"
            }
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

    /// 获取文件浏览 URL
    /// 翻译自: HostedGitInfo.browse
    public func browse(path: ?String): String {
        let basePath = "https://${hostProvider.domain()}"
        let userName = match (user) {
            case Some(u) => u
            case None => ""
        }
        let cmsh = match (committish) {
            case Some(c) => "/tree/${c}"
            case None => ""
        }
        let pathPart = match (path) {
            case Some(p) => "/${p}"
            case None => ""
        }

        match (hostProvider) {
            case HostProvider.Github => {
                return "${basePath}/${userName}/${project}${cmsh}${pathPart}"
            }
            case HostProvider.Gitlab => {
                return "${basePath}/${userName}/${project}${cmsh}${pathPart}"
            }
            case HostProvider.Bitbucket => {
                return "${basePath}/${userName}/${project}${cmsh}${pathPart}"
            }
            case HostProvider.Gist => {
                return "${basePath}/${project}${cmsh}${pathPart}"
            }
            case HostProvider.Sourcehut => {
                return "${basePath}/${userName}/${project}${cmsh}${pathPart}"
            }
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
public func isGitHubShorthand(npaStr: String): Bool {
    if (npaStr.length < 1) { return false }
    if (npaStr[0] == '.' || npaStr[0] == '/') { return false }

    var poundIdx: ?Int64 = None
    var seenSlash = false

    for (i in 0..npaStr.length) {
        let c = npaStr[Int64(i)]
        match (c) {
            case ':' | '@' => {
                // : 和 @ 只能在 # 之后出现
                match (poundIdx) {
                    case None => return false
                    case Some(_) => {}
                }
            }
            case '#' => {
                poundIdx = i
            }
            case '/' => {
                if (seenSlash && poundIdx == None) {
                    return false
                }
                seenSlash = true
            }
            case _ => {
                // 空格只能在 # 之后
                if (c.value <= 0x20 && poundIdx == None) {
                    return false
                }
            }
        }
    }

    // 不以 / 结尾
    let doesNotEndWithSlash = match (poundIdx) {
        case Some(pi) => pi == 0 || npaStr[Int64(pi) - 1] != '/'
        case None => npaStr.length >= 1 && npaStr[npaStr.length - 1] != '/'
    }

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
public func normalizeProtocol(npaStr: String): Tuple2<UrlProtocol, String> {
    let firstColonIdx = npaStr.indexOf(":")

    // 检查是否是已知协议
    match (firstColonIdx) {
        case Some(colIdx) => {
            let protoSlice = npaStr.substring(0, colIdx + 1)
            let wfProto = WellDefinedProtocol.fromStringWithColon(protoSlice)

            match (wfProto) {
                case Some(proto) => {
                    // 已知协议
                    var postColon = npaStr.substring(colIdx + 1)
                    if (postColon.startsWith("//")) {
                        postColon = postColon.substring(2)
                    }
                    return Tuple2(UrlProtocol.WellFormed(proto), postColon)
                }
                case None => {}
            }

            // 检查 @ 字符
            let firstAtIdx = npaStr.indexOf("@")
            match (firstAtIdx) {
                case Some(atIdx) => {
                    if (Int64(atIdx) < Int64(colIdx)) {
                        // user@host:path -> git+ssh
                        return Tuple2(UrlProtocol.WellFormed(WellDefinedProtocol.GitPlusSsh), npaStr)
                    } else {
                        // user:pass@host -> 可能是 git+ssh
                        return Tuple2(UrlProtocol.WellFormed(WellDefinedProtocol.GitPlusSsh), npaStr)
                    }
                }
                case None => {}
            }

            // 检查 //
            let dupSlashIdx = npaStr.indexOf("//")
            match (dupSlashIdx) {
                case Some(dsIdx) => {
                    if (Int64(dsIdx) == Int64(colIdx) + 1) {
                        let rest = npaStr.substring(dsIdx + 2)
                        let customProto = npaStr.substring(0, dsIdx)
                        return Tuple2(UrlProtocol.Custom(customProto), rest)
                    }
                }
                case None => {}
            }

            // 自定义协议
            let rest = npaStr.substring(colIdx + 1)
            let customProto = npaStr.substring(0, colIdx + 1)
            return Tuple2(UrlProtocol.Custom(customProto), rest)
        }
        case None => {
            // 没有 : 字符
            // 检查 @ 字符
            let atIdx = npaStr.indexOf("@")
            match (atIdx) {
                case Some(_) => {
                    // user@host -> git+ssh
                    return Tuple2(UrlProtocol.WellFormed(WellDefinedProtocol.GitPlusSsh), npaStr)
                }
                case None => {
                    return Tuple2(UrlProtocol.Unknown, npaStr)
                }
            }
        }
    }
}
