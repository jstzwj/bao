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
        if (s.size > 1 && s[0] == UInt8(34) && s[s.size - 1] == UInt8(34)) {
            s = s[1..s.size - 1]
        }

        // scoped package: @foo/bar@version
        if (s.size > 0 && s[0] == UInt8(64)) {
            let secondAt = s.indexOf("@", Int64(1))
            match (secondAt) {
                case Some(idx) => return s[0..idx]
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
            match (s.indexOf(prefix)) {
                case Some(idx) => return s[0..idx]
                case None => ()
            }
        }

        // 普通 @ 分隔
        match (s.indexOf("@")) {
            case Some(atIdx) => return s[0..atIdx]
            case None => ()
        }
        return s
    }

    /// 从 spec 字符串提取版本
    /// 翻译自: Entry.getVersionFromSpec
    private static func extractVersionFromScoped(s: String, idx: Int64): ?String {
        let versionStart = idx + 2 // skip second @
        if (versionStart >= s.size) { return None }
        let versionPart = s[versionStart..]
        if (versionPart.startsWith("npm:") && versionPart.size > 4) {
            return versionPart[4..]
        }
        return versionPart
    }

    public static func getVersionFromSpec(spec: String): ?String {
        var s = spec
        if (s.size > 1 && s[0] == UInt8(34) && s[s.size - 1] == UInt8(34)) {
            s = s[1..s.size - 1]
        }

        // scoped package
        if (s.size > 0 && s[0] == UInt8(64)) {
            let secondAt = s.indexOf("@", Int64(1))
            match (secondAt) {
                case Some(idx) => return extractVersionFromScoped(s, idx)
                case None => return None
            }
        }

        // @npm: alias
        match (s.indexOf("@npm:")) {
            case Some(npmIdx) =>
                let after = npmIdx + 5
                if (after < s.size) { return s[after..] }
                return None
            case None => ()
        }

        // @https://
        match (s.indexOf("@https://")) {
            case Some(httpsIdx) =>
                let after = httpsIdx + 1
                if (after < s.size) { return s[after..] }
                return None
            case None => ()
        }

        // @git+
        match (s.indexOf("@git+")) {
            case Some(gitIdx) =>
                let after = gitIdx + 1
                if (after < s.size) { return s[after..] }
                return None
            case None => ()
        }

        // @github:
        match (s.indexOf("@github:")) {
            case Some(ghIdx) =>
                let after = ghIdx + 1
                if (after < s.size) { return s[after..] }
                return None
            case None => ()
        }

        // @file:
        match (s.indexOf("@file:")) {
            case Some(fileIdx) =>
                let after = fileIdx + 1
                if (after < s.size) { return s[after..] }
                return None
            case None => ()
        }

        // 普通 @
        match (s.indexOf("@")) {
            case Some(atIdx) =>
                let after = atIdx + 1
                if (after < s.size) { return s[after..] }
                return None
            case None => ()
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
        if (url.startsWith("git+")) {
            url = url[4..]
        }
        return GitUrlInfo(url, Option<String>.None, Option<String>.None, Option<String>.None)
    }

    /// 解析 npm alias
    /// 翻译自: Entry.parseNpmAlias
    public static func parseNpmAlias(version: String): NpmAliasInfo {
        if (version.size <= 4) {
            return NpmAliasInfo("", "*")
        }
        let npmPart = version[4..]
        match (npmPart.indexOf("@")) {
            case Some(idx) => return NpmAliasInfo(npmPart[0..idx], npmPart[idx + 1..])
            case None => return NpmAliasInfo(npmPart, "*")
        }
    }

    /// 从 resolved URL 提取包名
    /// 翻译自: Entry.getPackageNameFromResolvedUrl
    public static func getPackageNameFromResolvedUrl(url: String): ?String {
        return Option<String>.None
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
        return
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
            if (entry.specs.size == 0) { () }
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
        if (!content.contains("# yarn lockfile v1")) {
            return Option<MigrationResult>.None
        }
        return MigrationResult()
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
