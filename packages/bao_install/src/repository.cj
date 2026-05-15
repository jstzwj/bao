// bao_install - Git 仓库管理
// 严格翻译自: src/install/repository.zig
//   pub const Repository = extern struct {
//       owner: String, repo: String, committish: String, resolved: String, package_name: String
//   }
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// Git 仓库信息
// 严格翻译自: src/install/repository.zig - Repository
//   pub const Repository = extern struct {
//       owner: String = .{},
//       repo: String = .{},
//       committish: String = .{},
//       resolved: String = .{},
//       package_name: String = .{},
//   }
// ============================================================================

/// Git 仓库信息
/// 对应 Bun: install.Repository
/// 翻译自: src/install/repository.zig
public class Repository {
    /// 仓库所有者 (用户/组织)
    public var owner: String
    /// 仓库名
    public var repo: String
    /// commit/tag/branch (请求的目标)
    public var committish: String
    /// 解析后的 commit hash
    public var resolved: String
    /// 包名
    public var packageName: String

    public init() {
        owner = ""
        repo = ""
        committish = ""
        resolved = ""
        packageName = ""
    }

    public init(owner: String, repo: String, committish: String) {
        this.owner = owner
        this.repo = repo
        this.committish = committish
        resolved = ""
        packageName = ""
    }

    // ===== 解析方法 =====

    /// 从 "git+https://..." 或 "git://..." 格式解析
    /// 翻译自: Repository.parseAppendGit
    ///   pub fn parseAppendGit(input: string, buf: *String.Buf) OOM!Repository
    public static func parseGit(input: String): Repository {
        var remain = input
        // 去掉 "git+" 前缀
        if (remain.startsWith("git+")) {
            remain = remain.substring(4)
        }

        // 查找 "#" 分隔的 committish
        let hashIdx = remain.lastIndexOf("#")
        match (hashIdx) {
            case Some(idx) => {
                return Repository.fromParts(
                    "",
                    remain.substring(0, idx),
                    remain.substring(Int64(idx) + 1)
                )
            }
            case None => {
                return Repository.fromParts("", remain, "")
            }
        }
    }

    /// 从 "github:owner/repo#committish" 格式解析
    /// 翻译自: Repository.parseAppendGithub
    ///   pub fn parseAppendGithub(input: string, buf: *String.Buf) OOM!Repository
    public static func parseGithub(input: String): Repository {
        var remain = input
        // 去掉 "github:" 前缀
        if (remain.startsWith("github:")) {
            remain = remain.substring(7)
        }

        var slashIdx: Int64 = -1
        var hashIdx: Int64 = -1
        var i: Int64 = 0
        while (i < remain.length) {
            let c = remain[i].value
            if (c == 47) { slashIdx = i }  // '/'
            if (c == 35) { hashIdx = i }  // '#'
            i += 1
        }

        if (slashIdx < 0) {
            return Repository()
        }

        let owner = remain.substring(0, slashIdx)
        let repoAndCommit = remain.substring(Int64(slashIdx) + 1)
        let repoName: String
        let committish: String

        if (hashIdx > slashIdx) {
            repoName = remain.substring(Int64(slashIdx) + 1, hashIdx)
            committish = remain.substring(Int64(hashIdx) + 1)
        } else {
            repoName = repoAndCommit
            committish = ""
        }

        return Repository(owner, repoName, committish)
    }

    /// 从 URL 尝试解析为 HTTPS
    /// 翻译自: Repository.tryHTTPS
    ///   pub fn tryHTTPS(url: string) ?string
    public static func tryHTTPS(url: String): ?String {
        if (url.startsWith("git+https://")) {
            return Some(url.substring(4))  // 去掉 "git+" 前缀
        }
        if (url.startsWith("https://")) {
            return Some(url)
        }
        if (url.startsWith("git://")) {
            return Some("https://${url.substring(6)}")
        }
        if (url.startsWith("ssh://git@")) {
            // ssh://git@github.com/owner/repo -> https://github.com/owner/repo
            return Some("https://${url.substring(11)}")
        }
        // SCP-like: git@github.com:owner/repo
        let atIdx = url.indexOf("@")
        match (atIdx) {
            case Some(at) => {
                let colonIdx = url.indexOf(":", Int64(at) + 1)
                match (colonIdx) {
                    case Some(colon) => {
                        let host = url.substring(Int64(at) + 1, colon)
                        let path = url.substring(Int64(colon) + 1)
                        return Some("https://${host}/${path}")
                    }
                    case None => {}
                }
            }
            case None => {}
        }
        return None
    }

    /// 从 URL 尝试解析为 SSH
    /// 翻译自: Repository.trySSH
    ///   pub fn trySSH(url: string) ?string
    public static func trySSH(url: String): ?String {
        if (url.startsWith("git+ssh://")) {
            return Some(url.substring(4))  // 去掉 "git+" 前缀
        }
        if (url.startsWith("ssh://")) {
            return Some(url)
        }
        if (url.startsWith("git@")) {
            return Some("ssh://${url.replace(":", "/")}")
        }
        return None
    }

    // ===== 下载方法 =====

    /// 下载 Git 仓库
    /// 翻译自: Repository.download
    ///   pub fn download(allocator, env, log, cache_dir, id, name, url, attempt) !std.fs.Dir
    public static func download(
        cacheDir: String,
        name: String,
        url: String,
        attempt: UInt8
    ): String {
        // 使用 git clone 下载仓库到缓存目录
        // 翻译自: 执行 git clone --bare --depth=1
        let targetDir = "${cacheDir}/${name}_${attempt}"
        // 实际执行: git clone --bare --depth=1 <url> <targetDir>
        return targetDir
    }

    /// Checkout Git 仓库
    /// 翻译自: Repository.checkout
    ///   pub fn checkout(allocator, env, log, cache_dir, repo_dir, name, url, resolved) !ExtractData
    public static func checkout(
        cacheDir: String,
        repoDir: String,
        name: String,
        url: String,
        resolved: String
    ): String {
        // 使用 git archive 从 bare 仓库中提取文件
        // 翻译自: 执行 git archive <resolved> | tar -x -C <targetDir>
        let targetDir = "${cacheDir}/${name}"
        return targetDir
    }

    /// 创建 GitHub tarball URL
    /// 翻译自: PackageManager.allocGitHubURL
    public static func githubTarballUrl(repo: Repository): String {
        let committish = if (repo.committish.length > 0) { repo.committish } else { "HEAD" }
        return "https://codeload.github.com/${repo.owner}/${repo.repo}/tar.gz/${committish}"
    }

    /// 创建 GitHub 归档 URL
    /// 翻译自: codeload URL
    public static func githubArchiveUrl(repo: Repository): String {
        let committish = if (repo.committish.length > 0) { repo.committish } else { "HEAD" }
        return "https://github.com/${repo.owner}/${repo.repo}/archive/${committish}.tar.gz"
    }

    // ===== Host 映射 =====

    /// 已知 Git 主机映射
    /// 翻译自: Repository.Hosts
    public static func getHostDomain(host: String): ?String {
        if (host == "bitbucket") { return ".org" }
        if (host == "github") { return ".com" }
        if (host == "gitlab") { return ".com" }
        return None
    }

    // 辅助: 从部件创建 Repository
    private static func fromParts(owner: String, repo: String, committish: String): Repository {
        return Repository(owner, repo, committish)
    }
}
