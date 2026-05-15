// bao_install - Yarn 锁文件迁移
// 严格翻译自: src/install/yarn.zig
//   YarnLock 解析器 + migrateYarnLockfile 迁移函数
//   将 yarn.lock (v1) 格式转换为 Bun/Bao 内部锁文件格式
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// Yarn 依赖类型
// 翻译自: src/install/yarn.zig - DependencyType
//   const DependencyType = enum { production, development, optional, peer }
// ============================================================================

/// Yarn 依赖类型
/// 翻译自: src/install/yarn.zig DependencyType
public enum YarnDependencyType {
    | Production
    | Development
    | Optional
    | Peer
}

// ============================================================================
// Yarn 锁文件条目
// 严格翻译自: src/install/yarn.zig - YarnLock.Entry
//   const Entry = struct {
//       specs: []const []const u8,
//       version: string,
//       resolved: ?string = null,
//       integrity: ?string = null,
//       dependencies: ?bun.StringHashMap(string) = null,
//       optionalDependencies: ?bun.StringHashMap(string) = null,
//       peerDependencies: ?bun.StringHashMap(string) = null,
//       devDependencies: ?bun.StringHashMap(string) = null,
//       commit: ?string = null,
//       workspace: bool = false,
//       file: ?string = null,
//       os: ?[]const []const u8 = null,
//       cpu: ?[]const []const u8 = null,
//       git_repo_name: ?string = null,
//   }
// ============================================================================

/// Yarn 锁文件条目
/// 对应 Bun: YarnLock.Entry
/// 翻译自: src/install/yarn.zig YarnLock.Entry
public class YarnLockEntry {
    /// 规格列表 (name@version-range)
    /// 对应 Bun: specs: []const []const u8
    public var specs: ArrayList<String>
    /// 版本
    /// 对应 Bun: version: string
    public var version: String
    /// 解析后的 URL
    /// 对应 Bun: resolved: ?string = null
    public var resolved: ?String
    /// 完整性哈希
    /// 对应 Bun: integrity: ?string = null
    public var integrity: ?String
    /// 生产依赖
    /// 对应 Bun: dependencies: ?bun.StringHashMap(string) = null
    public var dependencies: ?HashMap<String, String>
    /// 可选依赖
    /// 对应 Bun: optionalDependencies: ?bun.StringHashMap(string) = null
    public var optionalDependencies: ?HashMap<String, String>
    /// peer 依赖
    /// 对应 Bun: peerDependencies: ?bun.StringHashMap(string) = null
    public var peerDependencies: ?HashMap<String, String>
    /// 开发依赖
    /// 对应 Bun: devDependencies: ?bun.StringHashMap(string) = null
    public var devDependencies: ?HashMap<String, String>
    /// git commit hash
    /// 对应 Bun: commit: ?string = null
    public var commit: ?String
    /// 是否是 workspace 依赖
    /// 对应 Bun: workspace: bool = false
    public var isWorkspace: Bool
    /// 文件路径
    /// 对应 Bun: file: ?string = null
    public var file: ?String
    /// OS 限制
    /// 对应 Bun: os: ?[]const []const u8 = null
    public var os: ?ArrayList<String>
    /// CPU 限制
    /// 对应 Bun: cpu: ?[]const []const u8 = null
    public var cpu: ?ArrayList<String>
    /// git 仓库名
    /// 对应 Bun: git_repo_name: ?string = null
    public var gitRepoName: ?String

    public init() {
        specs = ArrayList<String>()
        version = ""
        resolved = None
        integrity = None
        dependencies = None
        optionalDependencies = None
        peerDependencies = None
        devDependencies = None
        commit = None
        isWorkspace = false
        file = None
        os = None
        cpu = None
        gitRepoName = None
    }

    /// 从 spec 字符串提取包名
    /// 翻译自: Entry.getNameFromSpec
    ///   pub fn getNameFromSpec(spec: []const u8) []const u8 {
    ///       const unquoted = if (spec[0] == '"' and spec[spec.len - 1] == '"')
    ///           spec[1 .. spec.len - 1] else spec;
    ///       if (unquoted[0] == '@') {
    ///           if (strings.indexOf(unquoted[1..], "@")) |second_at| {
    ///               return unquoted[0..second_at + 1];
    ///           }
    ///           return unquoted;
    ///       }
    ///       // 按优先级检查各种前缀
    ///       ...
    ///   }
    public static func getNameFromSpec(spec: String): String {
        var s = spec
        // 去除引号
        if (s.length > 1 && s[0] == '"' && s[s.length - 1] == '"') {
            s = s.substring(1, s.length - 1)
        }

        // scoped package: @foo/bar@version
        if (s.length > 0 && s[0] == '@') {
            let secondAt = s.indexOf("@", Int64(1))
            match (secondAt) {
                case Some(idx) => return s.substring(0, idx)
                case None => return s
            }
        }

        // 按优先级检查前缀
        // 翻译自: Entry.getNameFromSpec 中的各种 indexOf 检查
        let prefixes = ArrayList<String>()
        prefixes.append("@npm:")
        prefixes.append("@https://")
        prefixes.append("@git+")
        prefixes.append("@github:")
        prefixes.append("@file:")
        for (prefix in prefixes) {
            let idx = s.indexOf(prefix)
            if (idx >= 0) {
                return s.substring(0, idx)
            }
        }

        // 普通 @ 分隔
        let atIdx = s.indexOf("@")
        if (atIdx >= 0) {
            return s.substring(0, atIdx)
        }
        return s
    }

    /// 从 spec 字符串提取版本
    /// 翻译自: Entry.getVersionFromSpec
    public static func getVersionFromSpec(spec: String): ?String {
        var s = spec
        if (s.length > 1 && s[0] == '"' && s[s.length - 1] == '"') {
            s = s.substring(1, s.length - 1)
        }

        // scoped package
        if (s.length > 0 && s[0] == '@') {
            let secondAt = s.indexOf("@", Int64(1))
            match (secondAt) {
                case Some(idx) => {
                    let versionStart = idx + 2 // skip second @
                    if (versionStart >= s.length) { return None }
                    let versionPart = s.substring(versionStart)
                    if (versionPart.startsWith("npm:") && versionPart.length > 4) {
                        return versionPart.substring(4)
                    }
                    return versionPart
                }
                case None => return None
            }
        }

        // @npm: alias
        let npmIdx = s.indexOf("@npm:")
        if (npmIdx >= 0) {
            let after = npmIdx + 5
            if (after < s.length) { return s.substring(after) }
            return None
        }

        // @https://
        let httpsIdx = s.indexOf("@https://")
        if (httpsIdx >= 0) {
            let after = httpsIdx + 1
            if (after < s.length) { return s.substring(after) }
            return None
        }

        // @git+
        let gitIdx = s.indexOf("@git+")
        if (gitIdx >= 0) {
            let after = gitIdx + 1
            if (after < s.length) { return s.substring(after) }
            return None
        }

        // @github:
        let ghIdx = s.indexOf("@github:")
        if (ghIdx >= 0) {
            let after = ghIdx + 1
            if (after < s.length) { return s.substring(after) }
            return None
        }

        // @file:
        let fileIdx = s.indexOf("@file:")
        if (fileIdx >= 0) {
            let after = fileIdx + 1
            if (after < s.length) { return s.substring(after) }
            return None
        }

        // 普通 @
        let atIdx = s.indexOf("@")
        if (atIdx >= 0) {
            let after = atIdx + 1
            if (after < s.length) { return s.substring(after) }
            return None
        }

        return None
    }

    /// 是否是 git 依赖
    /// 翻译自: Entry.isGitDependency
    public static func isGitDependency(version: String): Bool {
        return version.startsWith("git+") ||
               version.startsWith("git://") ||
               version.startsWith("github:") ||
               version.startsWith("https://github.com/")
    }

    /// 是否是 npm alias
    /// 翻译自: Entry.isNpmAlias
    public static func isNpmAlias(version: String): Bool {
        return version.startsWith("npm:")
    }

    /// 是否是远程 tarball
    /// 翻译自: Entry.isRemoteTarball
    public static func isRemoteTarball(version: String): Bool {
        return version.startsWith("https://") && version.endsWith(".tgz")
    }

    /// 是否是 workspace 依赖
    /// 翻译自: Entry.isWorkspaceDependency
    public static func isWorkspaceDependency(version: String): Bool {
        return version.startsWith("workspace:") || version == "*"
    }

    /// 是否是文件依赖
    /// 翻译自: Entry.isFileDependency
    public static func isFileDependency(version: String): Bool {
        return version.startsWith("file:") ||
               version.startsWith("./") ||
               version.startsWith("../")
    }

    /// 解析 git URL
    /// 翻译自: Entry.parseGitUrl
    public static func parseGitUrl(version: String): GitUrlInfo {
        var url = version
        var commit: ?String = None
        var owner: ?String = None
        var repo: ?String = None

        // 去除 git+ 前缀
        if (url.startsWith("git+")) {
            url = url.substring(4)
        }

        // 分离 commit hash
        let hashIdx = url.indexOf("#")
        match (hashIdx) {
            case Some(idx) => {
                commit = url.substring(idx + 1)
                url = url.substring(0, idx)
            }
            case None => {}
        }

        // github: 前缀
        if (version.startsWith("github:")) {
            let githubPath = version.substring(7)
            let pathWithoutCommit = match (githubPath.indexOf("#")) {
                case Some(idx) => githubPath.substring(0, idx)
                case None => githubPath
            }
            let slashIdx = pathWithoutCommit.indexOf("/")
            match (slashIdx) {
                case Some(sIdx) => {
                    owner = pathWithoutCommit.substring(0, sIdx)
                    repo = pathWithoutCommit.substring(sIdx + 1)
                }
                case None => {
                    repo = pathWithoutCommit
                }
            }
            url = "https://github.com/${pathWithoutCommit}"
        } else if (url.contains("github.com")) {
            let githubIdx = url.indexOf("github.com/")
            if (githubIdx >= 0) {
                let remaining = url.substring(githubIdx + 11)
                let slashIdx = remaining.indexOf("/")
                match (slashIdx) {
                    case Some(sIdx) => {
                        owner = remaining.substring(0, sIdx)
                        let afterOwner = remaining.substring(sIdx + 1)
                        if (afterOwner.endsWith(".git")) {
                            repo = afterOwner.substring(0, afterOwner.length - 4)
                        } else {
                            repo = afterOwner
                        }
                    }
                    case None => {}
                }
            }
        }

        return GitUrlInfo(url: url, commit: commit, owner: owner, repo: repo)
    }

    /// 解析 npm alias
    /// 翻译自: Entry.parseNpmAlias
    public static func parseNpmAlias(version: String): NpmAliasInfo {
        if (version.length <= 4) {
            return NpmAliasInfo(packageName: "", version: "*")
        }
        let npmPart = version.substring(4)
        let atIdx = npmPart.indexOf("@")
        match (atIdx) {
            case Some(idx) => {
                let pkg = npmPart.substring(0, idx)
                let ver = if (idx + 1 < npmPart.length) { npmPart.substring(idx + 1) } else { "*" }
                return NpmAliasInfo(packageName: pkg, version: ver)
            }
            case None => {
                return NpmAliasInfo(packageName: npmPart, version: "*")
            }
        }
    }

    /// 从 resolved URL 提取包名
    /// 翻译自: Entry.getPackageNameFromResolvedUrl
    public static func getPackageNameFromResolvedUrl(url: String): ?String {
        let dashIdx = url.indexOf("/-/")
        match (dashIdx) {
            case Some(dIdx) => {
                var slashCount: Int64 = 0
                var lastSlash: Int64 = -1
                var secondLastSlash: Int64 = -1
                var i: Int64 = dIdx
                while (i > 0) {
                    i -= 1
                    if (url[Int64(i)] == '/') {
                        slashCount += 1
                        if (slashCount == 1) {
                            lastSlash = i
                        } else if (slashCount == 2) {
                            secondLastSlash = i
                            break
                        }
                    }
                }
                if (lastSlash >= 0 && lastSlash < dIdx && Int64(url[Int64(lastSlash) + 1]) == Int64('@')) {
                    if (secondLastSlash >= 0) {
                        return url.substring(Int64(secondLastSlash) + 1, Int64(dIdx))
                    }
                } else if (lastSlash >= 0) {
                    return url.substring(Int64(lastSlash) + 1, Int64(dIdx))
                }
            }
            case None => {}
        }
        return None
    }
}

/// Git URL 解析结果
/// 翻译自: Entry.parseGitUrl 的返回值
public class GitUrlInfo {
    public var url: String
    public var commit: ?String
    public var owner: ?String
    public var repo: ?String

    public init(url: String, commit: ?String, owner: ?String, repo: ?String) {
        this.url = url
        this.commit = commit
        this.owner = owner
        this.repo = repo
    }
}

/// NPM alias 解析结果
/// 翻译自: Entry.parseNpmAlias 的返回值
public class NpmAliasInfo {
    public var packageName: String
    public var version: String

    public init(packageName: String, version: String) {
        this.packageName = packageName
        this.version = version
    }
}

// ============================================================================
// Yarn 锁文件解析器
// 严格翻译自: src/install/yarn.zig - YarnLock
//   pub const YarnLock = struct {
//       entries: std.array_list.Managed(Entry),
//       allocator: Allocator,
//       pub fn init(allocator) YarnLock { ... }
//       pub fn parse(self, content) !void { ... }
//   }
// ============================================================================

/// Yarn 锁文件解析器
/// 对应 Bun: YarnLock
/// 翻译自: src/install/yarn.zig YarnLock
public class YarnLock {
    /// 解析后的条目列表
    /// 对应 Bun: entries: std.array_list.Managed(Entry)
    public var entries: ArrayList<YarnLockEntry>

    public init() {
        entries = ArrayList<YarnLockEntry>()
    }

    /// 解析 yarn.lock 文本内容
    /// 翻译自: YarnLock.parse
    ///   逐行解析 yarn.lock v1 格式:
    ///   - 顶行 (indent=0) 以 ":" 结尾的是 specs 行
    ///   - 缩进行是 key-value 属性
    ///   - "dependencies:", "optionalDependencies:" 等开启依赖块
    public func parse(content: String): Unit {
        let lines = content.split("\n")
        var currentEntry: ?YarnLockEntry = None
        var currentSpecs = ArrayList<String>()
        var currentDeps: ?HashMap<String, String> = None
        var currentOptionalDeps: ?HashMap<String, String> = None
        var currentPeerDeps: ?HashMap<String, String> = None
        var currentDevDeps: ?HashMap<String, String> = None
        var currentDepType: ?YarnDependencyType = None

        for (line_ in lines) {
            let line = line_.trimRight(" \r\t")
            if (line.length == 0 || line[0] == '#') { continue }

            // 计算缩进
            var indent: Int64 = 0
            while (indent < line.length && line[Int64(indent)] == ' ') {
                indent += 1
            }

            let trimmed = line.substring(indent).trim(" \r\t")
            if (trimmed.length == 0) { continue }

            // 顶行 (indent=0) 且以 ":" 结尾 -> 新的 specs
            if (indent == 0 && trimmed.endsWith(":")) {
                // 保存前一个条目
                match (currentEntry) {
                    case Some(entry) => {
                        entry.dependencies = currentDeps
                        entry.optionalDependencies = currentOptionalDeps
                        entry.peerDependencies = currentPeerDeps
                        entry.devDependencies = currentDevDeps
                        consolidateAndAppend(entry)
                    }
                    case None => {}
                }

                // 解析 specs (逗号分隔)
                currentSpecs = ArrayList<String>()
                let specsStr = trimmed.substring(0, trimmed.length - 1)
                let specParts = specsStr.split(",")
                for (spec in specParts) {
                    let specTrimmed = spec.trim(" \"")
                    if (specTrimmed.length > 0) {
                        currentSpecs.append(specTrimmed)
                    }
                }

                let newEntry = YarnLockEntry()
                newEntry.specs = currentSpecs
                newEntry.version = ""

                // 检查 file: 依赖
                for (spec in currentSpecs) {
                    let fileIdx = spec.indexOf("@file:")
                    if (fileIdx >= 0) {
                        let filePath = spec.substring(fileIdx + 6)
                        newEntry.file = filePath
                        break
                    }
                }

                currentEntry = newEntry
                currentDeps = None
                currentOptionalDeps = None
                currentPeerDeps = None
                currentDevDeps = None
                currentDepType = None
                continue
            }

            // 没有当前条目则跳过
            match (currentEntry) {
                case None => continue
                case Some(_) => {}
            }

            // 缩进行
            if (indent > 0) {
                // 依赖块标题
                if (trimmed == "dependencies:") {
                    currentDepType = YarnDependencyType.Production
                    currentDeps = HashMap<String, String>()
                    continue
                }
                if (trimmed == "optionalDependencies:") {
                    currentDepType = YarnDependencyType.Optional
                    currentOptionalDeps = HashMap<String, String>()
                    continue
                }
                if (trimmed == "peerDependencies:") {
                    currentDepType = YarnDependencyType.Peer
                    currentPeerDeps = HashMap<String, String>()
                    continue
                }
                if (trimmed == "devDependencies:") {
                    currentDepType = YarnDependencyType.Development
                    currentDevDeps = HashMap<String, String>()
                    continue
                }

                // 依赖块中的 key-value
                match (currentDepType) {
                    case Some(depType) => {
                        let spaceIdx = trimmed.indexOf(" ")
                        if (spaceIdx >= 0) {
                            let key = trimmed.substring(0, spaceIdx).trim(" \"")
                            let value = trimmed.substring(spaceIdx + 1).trim(" \"")
                            match (depType) {
                                case YarnDependencyType.Production => {
                                    match (currentDeps) {
                                        case Some(m) => m.put(key, value)
                                        case None => {}
                                    }
                                }
                                case YarnDependencyType.Optional => {
                                    match (currentOptionalDeps) {
                                        case Some(m) => m.put(key, value)
                                        case None => {}
                                    }
                                }
                                case YarnDependencyType.Peer => {
                                    match (currentPeerDeps) {
                                        case Some(m) => m.put(key, value)
                                        case None => {}
                                    }
                                }
                                case YarnDependencyType.Development => {
                                    match (currentDevDeps) {
                                        case Some(m) => m.put(key, value)
                                        case None => {}
                                    }
                                }
                            }
                        }
                        continue
                    }
                    case None => {}
                }

                // 属性行
                let spaceIdx = trimmed.indexOf(" ")
                if (spaceIdx >= 0) {
                    let key = trimmed.substring(0, spaceIdx).trim(" ")
                    let value = trimmed.substring(spaceIdx + 1).trim(" \"")

                    match (currentEntry) {
                        case Some(entry) => {
                            if (key == "version") {
                                entry.version = value

                                if (YarnLockEntry.isWorkspaceDependency(value)) {
                                    entry.isWorkspace = true
                                } else if (YarnLockEntry.isFileDependency(value)) {
                                    if (value.startsWith("file:") && value.length > 5) {
                                        entry.file = value.substring(5)
                                    } else {
                                        entry.file = value
                                    }
                                } else if (YarnLockEntry.isGitDependency(value)) {
                                    let gitInfo = YarnLockEntry.parseGitUrl(value)
                                    entry.resolved = gitInfo.url
                                    entry.commit = gitInfo.commit
                                    match (gitInfo.repo) {
                                        case Some(repoName) => entry.gitRepoName = repoName
                                        case None => {}
                                    }
                                } else if (YarnLockEntry.isNpmAlias(value)) {
                                    let aliasInfo = YarnLockEntry.parseNpmAlias(value)
                                    entry.version = aliasInfo.version
                                } else if (YarnLockEntry.isRemoteTarball(value)) {
                                    entry.resolved = value
                                }
                            } else if (key == "resolved") {
                                entry.resolved = value
                                if (YarnLockEntry.isGitDependency(value)) {
                                    let gitInfo = YarnLockEntry.parseGitUrl(value)
                                    entry.resolved = gitInfo.url
                                    entry.commit = gitInfo.commit
                                    match (gitInfo.repo) {
                                        case Some(repoName) => entry.gitRepoName = repoName
                                        case None => {}
                                    }
                                }
                            } else if (key == "integrity") {
                                entry.integrity = value
                            } else if (key == "os") {
                                if (value.length >= 2) {
                                    let inner = value.substring(1, value.length - 1)
                                    let osList = ArrayList<String>()
                                    for (part in inner.split(",")) {
                                        let trimmedPart = part.trim(" \"")
                                        if (trimmedPart.length > 0) {
                                            osList.append(trimmedPart)
                                        }
                                    }
                                    entry.os = osList
                                }
                            } else if (key == "cpu") {
                                if (value.length >= 2) {
                                    let inner = value.substring(1, value.length - 1)
                                    let cpuList = ArrayList<String>()
                                    for (part in inner.split(",")) {
                                        let trimmedPart = part.trim(" \"")
                                        if (trimmedPart.length > 0) {
                                            cpuList.append(trimmedPart)
                                        }
                                    }
                                    entry.cpu = cpuList
                                }
                            }
                        }
                        case None => {}
                    }
                }
            }
        }

        // 保存最后一个条目
        match (currentEntry) {
            case Some(entry) => {
                entry.dependencies = currentDeps
                entry.optionalDependencies = currentOptionalDeps
                entry.peerDependencies = currentPeerDeps
                entry.devDependencies = currentDevDeps
                consolidateAndAppend(entry)
            }
            case None => {}
        }
    }

    /// 通过 spec 查找条目
    /// 翻译自: YarnLock.findEntryBySpec
    public func findEntryBySpec(spec: String): ?YarnLockEntry {
        for (entry in entries) {
            for (entrySpec in entry.specs) {
                if (entrySpec == spec) {
                    return entry
                }
            }
        }
        return None
    }

    /// 合并并追加条目
    /// 翻译自: YarnLock.consolidateAndAppendEntry
    ///   如果同名同版本的条目已存在, 合并 specs
    private func consolidateAndAppend(newEntry: YarnLockEntry): Unit {
        if (newEntry.specs.size == 0) { return }
        let packageName = YarnLockEntry.getNameFromSpec(newEntry.specs[0])

        for (entry in entries) {
            if (entry.specs.size == 0) { continue }
            let existingName = YarnLockEntry.getNameFromSpec(entry.specs[0])

            if (packageName == existingName && newEntry.version == entry.version) {
                // 合并 specs
                for (spec in newEntry.specs) {
                    entry.specs.append(spec)
                }
                return
            }
        }

        entries.append(newEntry)
    }
}

// ============================================================================
// Yarn 锁文件迁移
// 严格翻译自: src/install/yarn.zig - migrateYarnLockfile
//   将 yarn.lock (v1) 迁移为 Bun/Bao 锁文件格式
//   pub fn migrateYarnLockfile(this, manager, allocator, log, data, dir) !LoadResult { ... }
// ============================================================================

/// Yarn 锁文件迁移器
/// 对应 Bun: migrateYarnLockfile
/// 翻译自: src/install/yarn.zig migrateYarnLockfile
public class YarnMigrator {
    /// 迁移 yarn.lock 为 Bao 锁文件
    /// 翻译自: migrateYarnLockfile
    public static func migrate(content: String): ?MigrationResult {
        // 检查版本
        // 翻译自: if (!strings.containsComptime(data, "# yarn lockfile v1"))
        if (!content.contains("# yarn lockfile v1")) {
            return None
        }

        let yarnLock = YarnLock()
        yarnLock.parse(content)

        let result = MigrationResult()
        result.format = TextLockfileVersion.current()

        // 版本信息
        let versionMap = HashMap<String, YarnVersionInfo>()
        let scopedVersions = HashMap<String, ArrayList<YarnVersionInfo>>()

        var nextPackageId: UInt32 = UInt32(1)

        // 第一遍: 为每个条目分配 package ID
        // 翻译自: migrateYarnLockfile 中的 package 版本映射
        for (i in 0..yarnLock.entries.size) {
            let entry = yarnLock.entries[Int64(i)]
            let name = YarnLockEntry.getNameFromSpec(entry.specs[0])

            match (versionMap.get(name)) {
                case Some(existing) => {
                    if (existing.version != entry.version) {
                        // 同名不同版本 -> scoped
                        var list = match (scopedVersions.get(name)) {
                            case Some(l) => l
                            case None => ArrayList<YarnVersionInfo>()
                        }

                        var foundNew = false
                        for (item in list) {
                            if (item.version == entry.version) {
                                foundNew = true
                                break
                            }
                        }

                        if (!foundNew) {
                            let pkgId = nextPackageId
                            nextPackageId = nextPackageId + UInt32(1)
                            list.append(YarnVersionInfo(version: entry.version, packageId: pkgId, yarnIdx: Int64(i)))
                        }

                        scopedVersions.put(name, list)
                    }
                }
                case None => {
                    let pkgId = nextPackageId
                    nextPackageId = nextPackageId + UInt32(1)
                    versionMap.put(name, YarnVersionInfo(
                        version: entry.version,
                        packageId: pkgId,
                        yarnIdx: Int64(i)
                    ))
                }
            }
        }

        // 第二遍: 创建包条目
        // 翻译自: migrateYarnLockfile 中创建 Lockfile.Package 的循环
        for (entry in yarnLock.entries) {
            let name = YarnLockEntry.getNameFromSpec(entry.specs[0])
            let pkg = LockfilePkg(name, Wyhash11.hash(name))

            // 设置 resolution
            // 翻译自: migrateYarnLockfile 中的 resolution 设置逻辑
            if (entry.isWorkspace) {
                pkg.resolution.tag = DependencyTag.Workspace
                pkg.resolution.workspacePath = name
            } else if (entry.file != None) {
                let filePath = entry.file.getOrThrow()
                if (filePath.endsWith(".tgz") || filePath.endsWith(".tar.gz")) {
                    pkg.resolution.tag = DependencyTag.Tarball
                    pkg.resolution.tarballUrl = filePath
                } else {
                    pkg.resolution.tag = DependencyTag.Folder
                    pkg.resolution.folderPath = filePath
                }
            } else if (entry.commit != None) {
                match (entry.resolved) {
                    case Some(resolved) => {
                        if (resolved.contains("github.com/")) {
                            pkg.resolution.tag = DependencyTag.Github
                            let ghIdx = resolved.indexOf("github.com/")
                            if (ghIdx >= 0) {
                                let after = resolved.substring(ghIdx + 11)
                                let slashIdx = after.indexOf("/")
                                match (slashIdx) {
                                    case Some(sIdx) => {
                                        pkg.resolution.githubUser = after.substring(0, sIdx)
                                        pkg.resolution.githubRepo = after.substring(sIdx + 1)
                                    }
                                    case None => {
                                        pkg.resolution.githubRepo = after
                                    }
                                }
                            }
                            pkg.resolution.githubCommittish = entry.commit.getOrThrow()
                        } else {
                            pkg.resolution.tag = DependencyTag.Git
                            pkg.resolution.gitRepo = resolved
                            pkg.resolution.gitRef = entry.commit.getOrThrow()
                        }
                    }
                    case None => {
                        pkg.resolution.tag = DependencyTag.Npm
                    }
                }
            } else if (entry.resolved != None) {
                let resolved = entry.resolved.getOrThrow()
                if (YarnLockEntry.isRemoteTarball(resolved)) {
                    pkg.resolution.tag = DependencyTag.Tarball
                    pkg.resolution.tarballUrl = resolved
                } else {
                    pkg.resolution.tag = DependencyTag.Npm
                    pkg.resolution.npmVersion = entry.version
                    pkg.resolution.npmUrl = resolved
                }
            } else {
                pkg.resolution.tag = DependencyTag.Npm
                pkg.resolution.npmVersion = entry.version
            }

            // 设置 integrity
            match (entry.integrity) {
                case Some(s) => pkg.meta.integrity = Integrity.parse(s)
                case None => {}
            }

            // 设置依赖
            match (entry.dependencies) {
                case Some(deps) => {
                    for (depName in deps.keys()) {
                        match (deps.get(depName)) {
                            case Some(depVer) => {
                                let dep = LockfileDependency(depName, Wyhash11.hash(depName), depVer)
                                pkg.dependencies.append(dep)
                            }
                            case None => {}
                        }
                    }
                }
                case None => {}
            }
            match (entry.optionalDependencies) {
                case Some(deps) => {
                    for (depName in deps.keys()) {
                        match (deps.get(depName)) {
                            case Some(depVer) => {
                                let dep = LockfileDependency(depName, Wyhash11.hash(depName), depVer)
                                dep.behavior.isOptional = true
                                pkg.dependencies.append(dep)
                            }
                            case None => {}
                        }
                    }
                }
                case None => {}
            }
            match (entry.peerDependencies) {
                case Some(deps) => {
                    for (depName in deps.keys()) {
                        match (deps.get(depName)) {
                            case Some(depVer) => {
                                let dep = LockfileDependency(depName, Wyhash11.hash(depName), depVer)
                                dep.behavior.isPeer = true
                                pkg.dependencies.append(dep)
                            }
                            case None => {}
                        }
                    }
                }
                case None => {}
            }

            result.packages.append(pkg)
        }

        return result
    }
}

/// Yarn 版本信息
/// 翻译自: migrateYarnLockfile 中的 VersionInfo struct
public class YarnVersionInfo {
    public var version: String
    public var packageId: UInt32
    public var yarnIdx: Int64

    public init(version: String, packageId: UInt32, yarnIdx: Int64) {
        this.version = version
        this.packageId = packageId
        this.yarnIdx = yarnIdx
    }
}

/// 迁移结果
public class MigrationResult {
    public var format: TextLockfileVersion
    public var packages: ArrayList<LockfilePkg>
    public var warnings: ArrayList<String>

    public init() {
        format = TextLockfileVersion.current()
        packages = ArrayList<LockfilePkg>()
        warnings = ArrayList<String>()
    }
}
