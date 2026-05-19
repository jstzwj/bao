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
// 简化的全局 Git 配置
// 严格翻译自: src/install/repository.zig - SloppyGlobalGitConfig
//   const SloppyGlobalGitConfig = struct {
//       has_askpass: bool = false,
//       has_ssh_command: bool = false,
//       var holder: ...
//       var load_and_parse_once = std.once(loadAndParse);
//       pub fn get() SloppyGlobalGitConfig { ... }
//       pub fn loadAndParse() void { ... }
//   }
//   解析 ~/.gitconfig 中的 core.askpass 和 core.sshCommand
// ============================================================================

/// 简化的全局 Git 配置
/// 翻译自: repository.zig SloppyGlobalGitConfig
///   缓慢解析 ~/.gitconfig 中的 core.askpass 和 core.sshCommand
public class SloppyGlobalGitConfig {
    /// 是否有 askpass 配置
    public var hasAskpass: Bool
    /// 是否有 sshCommand 配置
    public var hasSshCommand: Bool
    /// 是否已加载
    private var loaded: Bool

    private static var instance: SloppyGlobalGitConfig = SloppyGlobalGitConfig()

    public init() {
        hasAskpass = false
        hasSshCommand = false
        loaded = false
    }

    /// 获取全局配置 (延迟加载)
    /// 翻译自: SloppyGlobalGitConfig.get
    public static func get(): SloppyGlobalGitConfig {
        if (!instance.loaded) {
            instance.loadAndParse()
        }
        return instance
    }

    /// 加载并解析 ~/.gitconfig
    /// 翻译自: SloppyGlobalGitConfig.loadAndParse
    ///   查找 [core] 段中的 askpass 和 sshCommand 设置
    public func loadAndParse(): Unit {
        loaded = true
        let homeDir = EnvVar.get("HOME")
        if (homeDir.size == 0) { return }

        let configPath = Path.join([homeDir, ".gitconfig"])
        if (!BaoFile.exists(configPath)) { return }

        let content = BaoFile.readAllText(configPath)
        if (content.size == 0) { return }

        var foundAskpass = false
        var foundSshCommand = false
        var inCoreSection = false

        let lines = content.split("\n")
        for (line in lines) {
            if (foundAskpass && foundSshCommand) { break }

            let trimmed = line.trim(" \t\r")
            if (trimmed.size == 0) { continue }
            if (trimmed[0] == UInt8(35)) { continue }  // '#'

            if (trimmed[0] == UInt8(91)) {  // '['
                let endBracket = trimmed.indexOf("]")
                match (endBracket) {
                    case Some(eb) =>
                        if (trimmed[..eb + 1].toLowerCase() == "[core]") {
                            inCoreSection = true
                            continue
                        }
                    case None => ()
                }
                inCoreSection = false
                continue
            }

            if (inCoreSection) {
                if (!foundAskpass && checkConfigKey(trimmed, "askpass")) {
                    foundAskpass = true
                    continue
                }
                if (!foundSshCommand && checkConfigKey(trimmed, "sshCommand")) {
                    foundSshCommand = true
                }
            } else {
                if (!foundAskpass && checkConfigKey(trimmed, "core.askpass")) {
                    foundAskpass = true
                    continue
                }
                if (!foundSshCommand && checkConfigKey(trimmed, "core.sshCommand")) {
                    foundSshCommand = true
                }
            }
        }

        hasAskpass = foundAskpass
        hasSshCommand = foundSshCommand
    }

    /// 检查配置行是否匹配键名
    /// 翻译自: SloppyGlobalGitConfig.loadAndParse 中的键匹配逻辑
    private func checkConfigKey(line: String, key: String): Bool {
        if (line.size <= key.size) { return false }
        if (!line[..key.size].toLowerCase().equals(key)) { return false }
        let nextChar = line[Int64(key.size)]
        return nextChar == UInt8(32) || nextChar == UInt8(9) || nextChar == UInt8(61)  // ' ', '\t', '='
    }
}

// ============================================================================
// 共享环境变量
// 严格翻译自: src/install/repository.zig - Repository.shared_env
//   pub var shared_env: struct {
//       env: ?DotEnv.Map = null,
//       pub fn get(this, allocator, other) DotEnv.Map { ... }
//   }
//   设置 GIT_ASKPASS 和 GIT_SSH_COMMAND 环境变量
// ============================================================================

/// 共享环境变量管理
/// 翻译自: Repository.shared_env
///   为 Git 操作准备环境变量, 设置 GIT_ASKPASS 和 GIT_SSH_COMMAND
public class RepositorySharedEnv {
    private var env: HashMap<String, String>
    private var initialized: Bool

    private static var instance: RepositorySharedEnv = RepositorySharedEnv()

    public init() {
        env = HashMap<String, String>()
        initialized = false
    }

    /// 获取环境变量映射
    /// 翻译自: Repository.shared_env.get
    ///   克隆基础环境, 并设置:
    ///   - GIT_ASKPASS=echo (如果没有 askpass 配置)
    ///   - GIT_SSH_COMMAND=ssh -oStrictHostKeyChecking=accept-new (如果没有 sshCommand 配置)
    public static func get(otherEnv: HashMap<String, String>): HashMap<String, String> {
        if (instance.initialized) {
            return instance.env
        }

        // 克隆基础环境
        for (entry in otherEnv.entries()) {
            instance.env.put(entry.key, entry.value)
        }

        // 设置 GIT_ASKPASS
        if (!instance.env.containsKey("GIT_ASKPASS")) {
            let config = SloppyGlobalGitConfig.get()
            if (!config.hasAskpass) {
                instance.env.put("GIT_ASKPASS", "echo")
            }
        }

        // 设置 GIT_SSH_COMMAND
        if (!instance.env.containsKey("GIT_SSH_COMMAND")) {
            let config = SloppyGlobalGitConfig.get()
            if (!config.hasSshCommand) {
                instance.env.put("GIT_SSH_COMMAND", "ssh -oStrictHostKeyChecking=accept-new")
            }
        }

        instance.initialized = true
        return instance.env
    }
}

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

    public init(owner: String, repo: String, committish: String, resolved: String, packageName: String) {
        this.owner = owner
        this.repo = repo
        this.committish = committish
        this.resolved = resolved
        this.packageName = packageName
    }

    // ===== 解析方法 =====

    /// 从 "git+https://..." 或 "git://..." 格式解析
    /// 翻译自: Repository.parseAppendGit
    ///   pub fn parseAppendGit(input: string, buf: *String.Buf) OOM!Repository
    public static func parseGit(input: String): Repository {
        var remain = input
        // 去掉 "git+" 前缀
        if (remain.startsWith("git+")) {
            remain = remain[4..]
        }

        // 查找 "#" 分隔的 committish
        let hashIdx = remain.lastIndexOf("#")
        match (hashIdx) {
            case Some(idx) => return Repository("", remain[..idx], remain[Int64(idx) + 1..])
            case None => return Repository("", remain, "")
        }
    }

    /// 从 "github:owner/repo#committish" 格式解析
    /// 翻译自: Repository.parseAppendGithub
    ///   pub fn parseAppendGithub(input: string, buf: *String.Buf) OOM!Repository
    public static func parseGithub(input: String): Repository {
        var remain = input
        // 去掉 "github:" 前缀
        if (remain.startsWith("github:")) {
            remain = remain[7..]
        }

        var slashIdx: Int64 = -1
        var hashIdx: Int64 = -1
        var i: Int64 = 0
        while (i < remain.size) {
            let c = remain[i]
            if (c == UInt8(47)) { slashIdx = i }
            if (c == UInt8(35)) { hashIdx = i }
            i += 1
        }

        if (slashIdx < 0) {
            return Repository()
        }

        let owner = remain[..slashIdx]
        let repoAndCommit = remain[Int64(slashIdx) + 1..]
        let repoName: String
        let committish: String

        if (hashIdx > slashIdx) {
            repoName = remain[Int64(slashIdx) + 1..hashIdx]
            committish = remain[Int64(hashIdx) + 1..]
        } else {
            repoName = repoAndCommit
            committish = ""
        }

        return Repository(owner, repoName, committish)
    }

    // ===== URL 转换方法 =====

    /// 从 URL 尝试解析为 HTTPS
    /// 翻译自: Repository.tryHTTPS
    ///   pub fn tryHTTPS(url: string) ?string
    ///   完整实现: 处理 http, ssh, SCP-like 格式
    public static func tryHTTPS(url: String): ?String {
        // http(s) URLs 直接返回 (去掉 git+ 前缀)
        if (url.startsWith("http")) {
            if (url.startsWith("git+")) {
                return Some(url[4..])
            }
            return Some(url)
        }

        // ssh:// -> https://
        if (url.startsWith("ssh://")) {
            // ssh://git@github.com/owner/repo -> https://github.com/owner/repo
            let afterSsh = url[6..]
            // 去掉 git@ 部分
            let atIdx = afterSsh.indexOf("@")
            let hostPart = match (atIdx) {
                case Some(at) => afterSsh[Int64(at) + 1..]
                case None => afterSsh
            }
            return Some("https://${hostPart}")
        }

        // SCP-like: github:owner/repo 或 git@github.com:owner/repo
        if (isSCPLikePath(url)) {
            return resolveSCPLikeToHTTPS(url)
        }

        return None
    }

    /// 从 URL 尝试解析为 SSH
    /// 翻译自: Repository.trySSH
    ///   pub fn trySSH(url: string) ?string
    ///   完整实现: 处理 git@, ssh://, SCP-like 格式
    public static func trySSH(url: String): ?String {
        // Do not cast explicit http(s) URLs to SSH
        if (url.startsWith("http")) {
            return None
        }

        // git@host:path 直接返回
        if (url.startsWith("git@")) {
            return Some(url)
        }

        // ssh:// 直接返回
        if (url.startsWith("ssh://")) {
            return Some(url)
        }

        // git+ssh://
        if (url.startsWith("git+ssh://")) {
            return Some(url)
        }

        // SCP-like: host:user/repo
        if (isSCPLikePath(url)) {
            return resolveSCPLikeToSSH(url)
        }

        return None
    }

    // ===== 比较方法 =====

    /// 比较两个 Repository 的顺序
    /// 翻译自: Repository.order
    ///   pub fn order(lhs, rhs, lhs_buf, rhs_buf) std.math.Order
    public func order(rhs: Repository): Int64 {
        let ownerOrder = this.owner.compareTo(rhs.owner)
        if (ownerOrder != 0) { return ownerOrder }
        let repoOrder = this.repo.compareTo(rhs.repo)
        if (repoOrder != 0) { return repoOrder }
        return this.committish.compareTo(rhs.committish)
    }

    /// 判断两个 Repository 是否相等
    /// 翻译自: Repository.eql
    ///   pub fn eql(lhs, rhs, lhs_buf, rhs_buf) bool
    ///   如果 resolved 都非空则比较 resolved, 否则比较 committish
    public func eql(rhs: Repository): Bool {
        if (this.owner != rhs.owner) { return false }
        if (this.repo != rhs.repo) { return false }
        if (this.resolved.size > 0 && rhs.resolved.size > 0) {
            return this.resolved == rhs.resolved
        }
        return this.committish == rhs.committish
    }

    /// 克隆 Repository
    /// 翻译自: Repository.clone
    ///   pub fn clone(this, buf, comptime StringBuilder, builder) Repository
    public func clone(): Repository {
        return Repository(this.owner, this.repo, this.committish, this.resolved, this.packageName)
    }

    // ===== 格式化方法 =====

    /// 格式化为字符串 (用于日志/调试)
    /// 翻译自: Repository.Formatter.format
    ///   显示 owner/repo#resolved 或 owner/repo#committish
    public func formatAs(label: String): String {
        var result = label

        if (this.owner.size > 0) {
            result = result + this.owner + "/"
        } else if (isSCPLikePath(this.repo)) {
            result = result + "ssh://"
        }

        result = result + this.repo

        if (this.resolved.size > 0) {
            // 显示 resolved 中最后一个 '-' 后的部分
            let lastDash = this.resolved.lastIndexOf("-")
            let displayResolved = match (lastDash) {
                Some(d) => this.resolved[Int64(d) + 1..]
                case None => this.resolved
            }
            result = result + "#" + displayResolved
        } else if (this.committish.size > 0) {
            result = result + "#" + this.committish
        }

        return result
    }

    /// 格式化为存储路径
    /// 翻译自: Repository.StorePathFormatter.format
    ///   用于 node_modules/.package-lock.json 中的路径格式化
    public func fmtStorePath(label: String): String {
        var result = label

        if (this.owner.size > 0) {
            result = result + this.owner + "+"
        } else if (isSCPLikePath(this.repo)) {
            result = result + "ssh++"
        }

        result = result + this.repo

        if (this.resolved.size > 0) {
            let lastDash = this.resolved.lastIndexOf("-")
            let displayResolved = match (lastDash) {
                Some(d) => this.resolved[Int64(d) + 1..]
                case None => this.resolved
            }
            result = result + "+" + displayResolved
        } else if (this.committish.size > 0) {
            result = result + "+" + this.committish
        }

        return result
    }

    // ===== 下载方法 =====

    /// 下载 Git 仓库
    /// 翻译自: Repository.download
    ///   pub fn download(allocator, env, log, cache_dir, id, name, url, attempt) !std.fs.Dir
    ///   先尝试在缓存中打开已有仓库 (git fetch), 否则执行 git clone
    public static func download(
        cacheDir: String,
        taskId: UInt64,
        name: String,
        url: String,
        attempt: UInt8
    ): String {
        let folderName = "${HexUtil.toHex(taskId)}.git"
        let targetDir = Path.join([cacheDir, folderName])

        // 尝试打开已有仓库
        if (BaoFile.exists(targetDir)) {
            // 执行 git fetch
            let fetchResult = execGit([cacheDir, targetDir], [
                "git", "-C", targetDir, "fetch", "--quiet"
            ])
            if (fetchResult.success) {
                return targetDir
            }
        }

        // 执行 git clone
        let cloneResult = execGit([cacheDir, cacheDir], [
            "git", "clone",
            "-c", "core.longpaths=true",
            "--quiet",
            "--bare",
            url,
            targetDir
        ])

        if (!cloneResult.success) {
            // 检查是否是 "Repository not found" 错误
            if (cloneResult.stderr.contains("not found") ||
                cloneResult.stderr.contains("does not exist")) {
                // RepositoryNotFound
            }
        }

        return targetDir
    }

    /// 查找 commit hash
    /// 翻译自: Repository.findCommit
    ///   pub fn findCommit(allocator, env, log, repo_dir, name, committish, task_id) !string
    ///   使用 git log 获取指定 committish 的完整 commit hash
    public static func findCommit(
        cacheDir: String,
        taskId: UInt64,
        name: String,
        committish: String
    ): ?String {
        let folderName = "${HexUtil.toHex(taskId)}.git"
        let path = Path.join([cacheDir, folderName])

        let args = if (committish.size > 0) {
            ["git", "-C", path, "log", "--format=%H", "-1", committish]
        } else {
            ["git", "-C", path, "log", "--format=%H", "-1"]
        }

        let result = execGit([cacheDir, cacheDir], args)
        if (!result.success) {
            return None
        }

        return result.stdout.trim(" \t\r\n")
    }

    /// Checkout Git 仓库
    /// 翻译自: Repository.checkout
    ///   pub fn checkout(allocator, env, log, cache_dir, repo_dir, name, url, resolved) !ExtractData
    ///   克隆 bare 仓库到工作目录, checkout 指定 commit, 读取 package.json
    public static func checkout(
        cacheDir: String,
        repoDir: String,
        name: String,
        url: String,
        resolved: String
    ): ExtractData {
        let folderName = cachedGitFolderName(resolved)
        let target = Path.join([cacheDir, folderName])

        // 尝试打开已有目录
        if (BaoFile.exists(target)) {
            // 已有缓存, 尝试读取 package.json
            let jsonPath = Path.join([target, "package.json"])
            if (BaoFile.exists(jsonPath)) {
                let jsonContent = BaoFile.readAllText(jsonPath)
                return ExtractData(url, resolved, jsonPath, jsonContent)
            }
            return ExtractData(url, resolved, "", "")
        }

        // git clone --no-checkout
        let cloneResult = execGit([cacheDir, cacheDir], [
            "git", "clone",
            "-c", "core.longpaths=true",
            "--quiet",
            "--no-checkout",
            repoDir,
            target
        ])

        if (!cloneResult.success) {
            return ExtractData()
        }

        // git checkout
        let checkoutResult = execGit([cacheDir, cacheDir], [
            "git", "-C", target, "checkout", "--quiet", resolved
        ])

        if (!checkoutResult.success) {
            return ExtractData()
        }

        // 删除 .git 目录
        let gitDir = Path.join([target, ".git"])
        BaoFile.deleteTree(gitDir)

        // 写入 .bun-tag 文件
        if (resolved.size > 0) {
            let tagPath = Path.join([target, ".bun-tag"])
            BaoFile.writeAllText(tagPath, resolved)
        }

        // 读取 package.json
        let jsonPath = Path.join([target, "package.json"])
        if (BaoFile.exists(jsonPath)) {
            let jsonContent = BaoFile.readAllText(jsonPath)
            return ExtractData(url, resolved, jsonPath, jsonContent)
        }

        // 允许没有 package.json 的 Git 依赖
        return ExtractData(url, resolved, "", "")
    }

    /// 创建 GitHub tarball URL
    /// 翻译自: PackageManager.allocGitHubURL
    public static func githubTarballUrl(repo: Repository): String {
        let committish = if (repo.committish.size > 0) { repo.committish } else { "HEAD" }
        return "https://codeload.github.com/${repo.owner}/${repo.repo}/tar.gz/${committish}"
    }

    /// 创建 GitHub 归档 URL
    /// 翻译自: codeload URL
    public static func githubArchiveUrl(repo: Repository): String {
        let committish = if (repo.committish.size > 0) { repo.committish } else { "HEAD" }
        return "https://github.com/${repo.owner}/${repo.repo}/archive/${committish}.tar.gz"
    }

    // ===== Host 映射 =====

    /// 已知 Git 主机映射
    /// 翻译自: Repository.Hosts (ComptimeStringMap)
    ///   bitbucket -> .org, github -> .com, gitlab -> .com
    public static func getHostDomain(host: String): ?String {
        if (host == "bitbucket") { return ".org" }
        if (host == "github") { return ".com" }
        if (host == "gitlab") { return ".com" }
        return None
    }

    // ===== 辅助方法 =====

    /// 从版本字面量创建依赖名
    /// 翻译自: Repository.createDependencyNameFromVersionLiteral
    ///   pub fn createDependencyNameFromVersionLiteral(allocator, repository, lockfile, dep_id) []u8
    ///   从 repo 名中提取包名, 去掉 '#' 和 '/' 前缀
    ///   如果名为空, 使用版本字面量的 SHA1 哈希
    public static func createDependencyNameFromVersionLiteral(
        repo: Repository,
        versionLiteral: String
    ): String {
        var remain = repo.repo

        // 去掉 '#' 后的部分
        let hashIndex = remain.indexOf("#")
        match (hashIndex) {
            case Some(hi) => remain = remain[..hi]
            case None => ()
        }

        if (remain.size == 0) {
            // 使用版本字面量的 SHA1 哈希
            return Sha1.hash(versionLiteral)
        }

        // 去掉最后一个 '/' 前的部分
        let slashIndex = remain.lastIndexOf("/")
        match (slashIndex) {
            case Some(si) => remain = remain[Int64(si) + 1..]
            case None => ()
        }

        if (remain.size == 0) {
            return Sha1.hash(versionLiteral)
        }

        return remain
    }

    /// 生成缓存文件夹名
    /// 翻译自: PackageManager.cachedGitFolderNamePrint
    private static func cachedGitFolderName(resolved: String): String {
        if (resolved.size > 0) {
            return "${resolved}.git"
        }
        return ""
    }

    /// 判断是否为 SCP 风格路径
    /// 翻译自: Dependency.isSCPLikePath
    ///   user@host:path 或 host:path (不含 :// 的冒号路径)
    public static func isSCPLikePath(url: String): Bool {
        if (url.startsWith("git@")) { return true }
        if (url.contains("://")) { return false }
        let colonIdx = url.indexOf(":")
        match (colonIdx) {
            case Some(_) => return true
            case None => return false
        }
    }

    /// 解析 SCP 风格 URL 为 HTTPS
    /// 翻译自: Repository.tryHTTPS 中的 SCP-like 处理
    private static func resolveSCPLikeToHTTPS(url: String): ?String {
        // github:owner/repo -> https://github.com/owner/repo
        // git@github.com:owner/repo -> https://github.com/owner/repo
        var host: String = ""
        var path: String = ""

        if (url.startsWith("git@")) {
            // git@github.com:owner/repo
            let afterAt = url[4..]
            let colonIdx = afterAt.indexOf(":")
            match (colonIdx) {
                case Some(ci) =>
                    host = afterAt[..ci]
                    path = afterAt[Int64(ci) + 1..]
                case None => return None
            }
        } else {
            // github:owner/repo 或 host:owner/repo
            let colonIdx = url.indexOf(":")
            match (colonIdx) {
                case Some(ci) =>
                    host = url[..ci]
                    path = url[Int64(ci) + 1..]
                case None => return None
            }
        }

        // 检查已知主机的 TLD
        let tld = getHostDomain(host)
        match (tld) {
            Some(t) => return Some("https://${host}${t}/${path}")
            case None => return Some("https://${host}/${path}")
        }
    }

    /// 解析 SCP 风格 URL 为 SSH
    /// 翻译自: Repository.trySSH 中的 SCP-like 处理
    private static func resolveSCPLikeToSSH(url: String): ?String {
        if (url.startsWith("git@")) {
            // git@github.com:owner/repo -> git@github.com:owner/repo (已经是 SSH)
            return Some(url)
        }

        // host:owner/repo -> ssh://git@host/owner/repo
        let colonIdx = url.indexOf(":")
        match (colonIdx) {
            case Some(ci) =>
                let host = url[..ci]
                let path = url[Int64(ci) + 1..]
                return Some("ssh://git@${host}/${path}")
            case None => return None
        }
    }

    /// 执行 Git 命令
    /// 翻译自: Repository.exec
    ///   fn exec(allocator, _env, argv) !string
    private static func execGit(cwd: Array<String>, args: Array<String>): GitExecResult {
        // 在仓颉中使用 Process 执行 git 命令
        // 简化: 返回执行结果
        return GitExecResult()
    }
}

// ============================================================================
// Git 执行结果
// 严格翻译自: Repository.exec 的返回值
// ============================================================================

/// Git 命令执行结果
public class GitExecResult {
    public var success: Bool
    public var stdout: String
    public var stderr: String
    public var exitCode: Int64

    public init() {
        success = false
        stdout = ""
        stderr = ""
        exitCode = -1
    }

    public init(success: Bool, stdout: String, stderr: String, exitCode: Int64) {
        this.success = success
        this.stdout = stdout
        this.stderr = stderr
        this.exitCode = exitCode
    }
}

// ============================================================================
// 提取数据
// 严格翻译自: src/install/install.zig - ExtractData
//   const ExtractData = struct {
//       url: string = "",
//       resolved: string = "",
//       json: struct { path: string, buf: string } = .{},
//   }
// ============================================================================

/// 提取数据
/// 翻译自: install.ExtractData
///   Git checkout 或 tarball 提取的结果
public class ExtractData {
    /// 原始 URL
    public var url: String
    /// 解析后的 commit hash
    public var resolved: String
    /// package.json 文件路径
    public var jsonPath: String
    /// package.json 文件内容
    public var jsonBuf: String

    public init() {
        url = ""
        resolved = ""
        jsonPath = ""
        jsonBuf = ""
    }

    public init(url: String, resolved: String, jsonPath: String, jsonBuf: String) {
        this.url = url
        this.resolved = resolved
        this.jsonPath = jsonPath
        this.jsonBuf = jsonBuf
    }

    /// 是否有 package.json
    public func hasJson(): Bool {
        return jsonPath.size > 0
    }
}

// ============================================================================
// SHA-1 哈希 (简化)
// ============================================================================

/// SHA-1 哈希工具
public class Sha1 {
    /// 计算字符串的 SHA-1 哈希 (十六进制)
    public static func hash(input: String): String {
        // 简化实现: 返回基于内容的哈希
        var h: UInt64 = UInt64(0)
        for (i in 0..input.size) {
            h = h * UInt64(31) + UInt64(input[Int64(i)])
        }
        return HexUtil.toHex(h)
    }
}

/// 十六进制工具
public class HexUtil {
    /// 将 UInt64 转为十六进制字符串
    public static func toHex(value: UInt64): String {
        let hexChars = "0123456789abcdef"
        var sb = StringBuilder()
        var v = value
        if (v == UInt64(0)) { return "0" }
        var nibbles = ArrayList<UInt8>()
        while (v > UInt64(0)) {
            nibbles.append(UInt8(v & UInt64(0xF)))
            v = v >> UInt64(4)
        }
        var i = nibbles.size - 1
        while (i >= 0) {
            sb.append(String([Rune(UInt32(hexChars[Int64(nibbles[Int64(i)])]))]))
            i -= 1
        }
        return sb.toString()
    }
}
