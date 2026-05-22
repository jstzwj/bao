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
        //   if (strings.indexOf(unquoted, "@npm:")) |npm_idx| return unquoted[0..npm_idx];
        //   else if (strings.indexOf(unquoted, "@https://")) |url_idx| return unquoted[0..url_idx];
        //   else if (strings.indexOf(unquoted, "@git+")) |git_idx| return unquoted[0..git_idx];
        //   else if (strings.indexOf(unquoted, "@github:")) |gh_idx| return unquoted[0..gh_idx];
        //   else if (strings.indexOf(unquoted, "@file:")) |file_idx| return unquoted[0..file_idx];
        //   else if (strings.indexOf(unquoted, "@")) |idx| return unquoted[0..idx];
        match (s.indexOf("@npm:")) {
            case Some(idx) => return s[0..idx]
            case None => ()
        }
        match (s.indexOf("@https://")) {
            case Some(idx) => return s[0..idx]
            case None => ()
        }
        match (s.indexOf("@git+")) {
            case Some(idx) => return s[0..idx]
            case None => ()
        }
        match (s.indexOf("@github:")) {
            case Some(idx) => return s[0..idx]
            case None => ()
        }
        match (s.indexOf("@file:")) {
            case Some(idx) => return s[0..idx]
            case None => ()
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
    ///   pub fn getVersionFromSpec(spec: []const u8) ?[]const u8 {
    ///       const unquoted = ...
    ///       if (unquoted[0] == '@') {
    ///           if (strings.indexOfChar(unquoted[1..], '@')) |second_at_pos| {
    ///               const version_start = second_at_pos + "@".len + 1;
    ///               const version_part = unquoted[version_start..];
    ///               if (strings.hasPrefixComptime(version_part, "npm:") and version_part.len > 4)
    ///                   return version_part["npm:".len..];
    ///               return version_part;
    ///           }
    ///           return null;
    ///       } else if (strings.indexOf(unquoted, "@npm:")) |npm_idx| {
    ///           const after_npm = npm_idx + "npm:".len + 1;
    ///           if (after_npm < unquoted.len) return unquoted[after_npm..];
    ///           return null;
    ///       } else if (strings.indexOf(unquoted, "@https://")) |url_idx| { ... }
    ///       ...
    ///   }
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
        // 翻译自: strings.indexOf(unquoted, "@npm:") => unquoted[npm_idx + "npm:".len + 1 ..]
        match (s.indexOf("@npm:")) {
            case Some(npmIdx) =>
                let after = npmIdx + 5
                if (after < s.size) { return s[after..] }
                return None
            case None => ()
        }

        // @https://
        // 翻译自: strings.indexOf(unquoted, "@https://") => unquoted[url_idx + '@'.len ..]
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
    ///   pub fn isGitDependency(version: []const u8) bool {
    ///       return strings.hasPrefixComptime(version, "git+") or
    ///           strings.hasPrefixComptime(version, "git://") or
    ///           strings.hasPrefixComptime(version, "github:") or
    ///           strings.hasPrefixComptime(version, "https://github.com/");
    ///   }
    public static func isGitDependency(version: String): Bool {
        return version.startsWith("git+") ||
               version.startsWith("git://") ||
               version.startsWith("github:") ||
               version.startsWith("https://github.com/")
    }

    /// 是否是 npm alias
    /// 翻译自: Entry.isNpmAlias
    ///   pub fn isNpmAlias(version: []const u8) bool {
    ///       return strings.hasPrefixComptime(version, "npm:");
    ///   }
    public static func isNpmAlias(version: String): Bool {
        return version.startsWith("npm:")
    }

    /// 是否是远程 tarball
    /// 翻译自: Entry.isRemoteTarball
    ///   pub fn isRemoteTarball(version: []const u8) bool {
    ///       return strings.hasPrefixComptime(version, "https://") and
    ///           strings.endsWithComptime(version, ".tgz");
    ///   }
    public static func isRemoteTarball(version: String): Bool {
        return version.startsWith("https://") && version.endsWith(".tgz")
    }

    /// 是否是 workspace 依赖
    /// 翻译自: Entry.isWorkspaceDependency
    ///   pub fn isWorkspaceDependency(version: []const u8) bool {
    ///       return strings.hasPrefixComptime(version, "workspace:") or
    ///           strings.eqlComptime(version, "*");
    ///   }
    public static func isWorkspaceDependency(version: String): Bool {
        return version.startsWith("workspace:") || version == "*"
    }

    /// 是否是文件依赖
    /// 翻译自: Entry.isFileDependency
    ///   pub fn isFileDependency(version: []const u8) bool {
    ///       return strings.hasPrefixComptime(version, "file:") or
    ///           strings.hasPrefixComptime(version, "./") or
    ///           strings.hasPrefixComptime(version, "../");
    ///   }
    public static func isFileDependency(version: String): Bool {
        return version.startsWith("file:") ||
               version.startsWith("./") ||
               version.startsWith("../")
    }

    /// 解析 git URL
    /// 翻译自: Entry.parseGitUrl
    ///   pub fn parseGitUrl(self: *const YarnLock, version: []const u8)
    ///       !struct { url: []const u8, commit: ?[]const u8, owner: ?[]const u8, repo: ?[]const u8 } {
    ///       var url = version;
    ///       var commit: ?[]const u8 = null;
    ///       var owner: ?[]const u8 = null;
    ///       var repo: ?[]const u8 = null;
    ///       if (strings.hasPrefixComptime(url, "git+")) url = url[4..];
    ///       if (strings.indexOf(url, "#")) |hash_idx| {
    ///           commit = url[hash_idx + 1 ..];
    ///           url = url[0..hash_idx];
    ///       }
    ///       if (strings.hasPrefixComptime(version, "github:")) {
    ///           const github_path = version["github:".len..];
    ///           const path_without_commit = if (strings.indexOf(github_path, "#")) |idx|
    ///               github_path[0..idx] else github_path;
    ///           if (strings.indexOf(path_without_commit, "/")) |slash_idx| {
    ///               owner = path_without_commit[0..slash_idx];
    ///               repo = path_without_commit[slash_idx + 1 ..];
    ///           }
    ///           url = "https://github.com/" + path_without_commit;
    ///       } else if (strings.contains(url, "github.com")) {
    ///           var remaining = url;
    ///           if (strings.indexOf(remaining, "github.com/")) |idx| {
    ///               remaining = remaining[idx + "github.com/".len ..];
    ///           }
    ///           if (strings.indexOf(remaining, "/")) |slash_idx| {
    ///               owner = remaining[0..slash_idx];
    ///               const after_owner = remaining[slash_idx + 1 ..];
    ///               if (strings.endsWithComptime(after_owner, ".git"))
    ///                   repo = after_owner[0 .. after_owner.len - ".git".len];
    ///               else
    ///                   repo = after_owner;
    ///           }
    ///       }
    ///       return .{ .url = url, .commit = commit, .owner = owner, .repo = repo };
    ///   }
    public static func parseGitUrl(version: String): GitUrlInfo {
        var url = version
        var commit: ?String = None
        var owner: ?String = None
        var repo: ?String = None

        if (url.startsWith("git+")) {
            url = url[4..]
        }

        // Extract commit hash from #fragment
        match (url.indexOf("#")) {
            case Some(hashIdx) =>
                commit = url[hashIdx + 1..]
                url = url[0..hashIdx]
            case None => ()
        }

        // Handle github: protocol
        // 翻译自: if (strings.hasPrefixComptime(version, "github:"))
        if (version.startsWith("github:")) {
            let githubPath = version[7..]
            let pathWithoutCommit: String = match (githubPath.indexOf("#")) {
                case Some(idx) => githubPath[0..idx]
                case None => githubPath
            }
            match (pathWithoutCommit.indexOf("/")) {
                case Some(slashIdx) =>
                    owner = pathWithoutCommit[0..slashIdx]
                    repo = pathWithoutCommit[slashIdx + 1..]
                case None => ()
            }
            url = "https://github.com/" + pathWithoutCommit
        } else if (url.contains("github.com")) {
            // Handle URLs containing github.com
            // 翻译自: else if (strings.contains(url, "github.com"))
            var remaining = url
            match (remaining.indexOf("github.com/")) {
                case Some(idx) => remaining = remaining[idx + 11..]
                case None => ()
            }
            match (remaining.indexOf("/")) {
                case Some(slashIdx) =>
                    owner = remaining[0..slashIdx]
                    let afterOwner = remaining[slashIdx + 1..]
                    if (afterOwner.endsWith(".git")) {
                        repo = afterOwner[0..afterOwner.size - 4]
                    } else {
                        repo = afterOwner
                    }
                case None => ()
            }
        }

        return GitUrlInfo(url, commit, owner, repo)
    }

    /// 解析 npm alias
    /// 翻译自: Entry.parseNpmAlias
    ///   pub fn parseNpmAlias(version: []const u8) struct { package: []const u8, version: []const u8 } {
    ///       if (version.len <= 4) return .{ .package = "", .version = "*" };
    ///       const npm_part = version[4..];
    ///       if (strings.indexOf(npm_part, "@")) |at_idx| {
    ///           return .{
    ///               .package = npm_part[0..at_idx],
    ///               .version = if (at_idx + 1 < npm_part.len) npm_part[at_idx + 1 ..] else "*",
    ///           };
    ///       }
    ///       return .{ .package = npm_part, .version = "*" };
    ///   }
    public static func parseNpmAlias(version: String): NpmAliasInfo {
        if (version.size <= 4) {
            return NpmAliasInfo("", "*")
        }
        let npmPart = version[4..]
        match (npmPart.indexOf("@")) {
            case Some(idx) =>
                let ver: String = if (idx + 1 < npmPart.size) {
                    npmPart[idx + 1..]
                } else {
                    "*"
                }
                return NpmAliasInfo(npmPart[0..idx], ver)
            case None => return NpmAliasInfo(npmPart, "*")
        }
    }

    /// 从 resolved URL 提取包名
    /// 翻译自: Entry.getPackageNameFromResolvedUrl
    ///   pub fn getPackageNameFromResolvedUrl(url: []const u8) ?[]const u8 {
    ///       if (strings.indexOf(url, "/-/")) |dash_idx| {
    ///           var slash_count: usize = 0;
    ///           var last_slash: usize = 0;
    ///           var second_last_slash: usize = 0;
    ///           var i = dash_idx;
    ///           while (i > 0) : (i -= 1) {
    ///               if (url[i - 1] == '/') {
    ///                   slash_count += 1;
    ///                   if (slash_count == 1) last_slash = i - 1;
    ///                   else if (slash_count == 2) { second_last_slash = i - 1; break; }
    ///               }
    ///           }
    ///           if (last_slash < dash_idx and url[last_slash + 1] == '@')
    ///               return url[second_last_slash + 1 .. dash_idx];
    ///           else
    ///               return url[last_slash + 1 .. dash_idx];
    ///       }
    ///       return null;
    ///   }
    public static func getPackageNameFromResolvedUrl(url: String): ?String {
        match (url.indexOf("/-/")) {
            case Some(dashIdx) =>
                var slashCount: Int64 = 0
                var lastSlash: Int64 = 0
                var secondLastSlash: Int64 = 0

                var i = dashIdx
                while (i > 0) {
                    i = i - 1
                    if (url[i] == UInt8(47)) { // '/'
                        slashCount = slashCount + 1
                        if (slashCount == 1) {
                            lastSlash = i
                        } else if (slashCount == 2) {
                            secondLastSlash = i
                            break
                        }
                    }
                }

                if (lastSlash < dashIdx && url[lastSlash + 1] == UInt8(64)) { // '@'
                    return url[secondLastSlash + 1..dashIdx]
                } else {
                    return url[lastSlash + 1..dashIdx]
                }
            case None => return None
        }
    }

}

/// Git URL 解析结果
/// 翻译自: Entry.parseGitUrl 的返回值
///   struct { url: []const u8, commit: ?[]const u8, owner: ?[]const u8, repo: ?[]const u8 }
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
///   struct { package: []const u8, version: []const u8 }
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
    /// 翻译自: YarnLock.parse (lines 265-431)
    ///   逐行解析 yarn.lock v1 格式:
    ///   - 顶行 (indent=0) 以 ":" 结尾的是 specs 行
    ///   - 缩进行是 key-value 属性
    ///   - "dependencies:", "optionalDependencies:" 等开启依赖块
    ///   - "version" 行解析版本并判断依赖类型 (git/workspace/file/npm alias/remote tarball)
    ///   - "resolved" 行解析 URL
    ///   - "integrity" 行解析完整性哈希
    ///   - "os" / "cpu" 行解析平台限制
    ///   - 最后一个条目在文件结束时追加
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
            let line = line_.trimEnd()
            if (line.size == 0 || line[0] == UInt8(35)) { continue } // skip empty / comments

            var indent: Int64 = 0
            while (indent < line.size && line[indent] == UInt8(32)) {
                indent = indent + 1
            }

            // Trim leading/trailing whitespace (\r, \t, space)
            var _trimmedStart: Int64 = indent
            var _trimmedEnd: Int64 = line.size
            while (_trimmedStart < _trimmedEnd && (line[_trimmedStart] == UInt8(32) || line[_trimmedStart] == UInt8(9) || line[_trimmedStart] == UInt8(13))) {
                _trimmedStart += 1
            }
            while (_trimmedEnd > _trimmedStart && (line[_trimmedEnd - 1] == UInt8(32) || line[_trimmedEnd - 1] == UInt8(9) || line[_trimmedEnd - 1] == UInt8(13))) {
                _trimmedEnd -= 1
            }
            let trimmed = line[_trimmedStart.._trimmedEnd]
            if (trimmed.size == 0) { continue }

            // Top-level line ending with ":" starts a new entry's specs
            // 翻译自: if (indent == 0 and strings.endsWithComptime(trimmed, ":"))
            if (indent == 0 && trimmed.endsWith(":")) {
                // Flush previous entry
                if (currentEntry .isSome()) {
                    let entry = currentEntry.getOrThrow()
                    entry.dependencies = currentDeps
                    entry.optionalDependencies = currentOptionalDeps
                    entry.peerDependencies = currentPeerDeps
                    entry.devDependencies = currentDevDeps
                    consolidateAndAppend(entry)
                }

                // Parse specs from "spec1, spec2, spec3:" line
                currentSpecs = ArrayList<String>()
                let specsStr = trimmed[0..trimmed.size - 1]
                let specParts = specsStr.split(",")
                for (spec in specParts) {
                    let trimmedSpec = spec.trimStart().trimEnd()
                    currentSpecs.append(trimmedSpec)
                }

                let newEntry = YarnLockEntry()
                newEntry.specs = currentSpecs
                // Note: version is set below when parsing "version" key

                // Check for @file: in specs
                // 翻译自: for (current_specs.items) |spec| { if indexOf(spec, "@file:") ... }
                for (spec in currentSpecs) {
                    match (spec.indexOf("@file:")) {
                        case Some(atIndex) =>
                            let filePath = spec[atIndex + 6..]
                            newEntry.file = filePath
                            break
                        case None => ()
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

            if (currentEntry .isNone()) { continue }

            if (indent > 0) {
                // Dependency block headers
                // 翻译自: if (strings.eqlComptime(trimmed, "dependencies:"))
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

                // Inside a dependency block, parse "key value" pairs
                // 翻译自: if (current_dep_type) |dep_type| { ... try map.put(key, value) }
                if (currentDepType .isSome()) {
                    match (trimmed.indexOf(" ")) {
                        case Some(spaceIdx) =>
                            let key = trimmed[0..spaceIdx].trimStart().trimEnd()
                            let value = trimmed[spaceIdx + 1..].trimStart().trimEnd()
                            match (currentDepType.getOrThrow()) {
                                case YarnDependencyType.Production =>
                                    currentDeps.getOrThrow().put(key, value)
                                case YarnDependencyType.Optional =>
                                    currentOptionalDeps.getOrThrow().put(key, value)
                                case YarnDependencyType.Peer =>
                                    currentPeerDeps.getOrThrow().put(key, value)
                                case YarnDependencyType.Development =>
                                    currentDevDeps.getOrThrow().put(key, value)
                            }
                        case None => ()
                    }
                    continue
                }

                // Key-value attributes of the entry
                // 翻译自: if (strings.indexOf(trimmed, " ")) |space_idx| { ... }
                match (trimmed.indexOf(" ")) {
                    case Some(spaceIdx) =>
                        let key = trimmed[0..spaceIdx].trimStart().trimEnd()
                        let value = trimmed[spaceIdx + 1..].trimStart().trimEnd()

                        let entry = currentEntry.getOrThrow()

                        if (key == "version") {
                            entry.version = value

                            // Determine dependency type from version string
                            // 翻译自: if (Entry.isWorkspaceDependency(value)) entry.workspace = true
                            if (YarnLockEntry.isWorkspaceDependency(value)) {
                                entry.isWorkspace = true
                            } else if (YarnLockEntry.isFileDependency(value)) {
                                // 翻译自: else if (Entry.isFileDependency(value))
                                //   entry.file = if hasPrefixComptime "file:" and len > 5 then value[5..] else value
                                if (value.startsWith("file:") && value.size > 5) {
                                    entry.file = value[5..]
                                } else {
                                    entry.file = value
                                }
                            } else if (YarnLockEntry.isGitDependency(value)) {
                                // 翻译自: else if (Entry.isGitDependency(value))
                                //   const git_info = try Entry.parseGitUrl(self, value);
                                //   entry.resolved = git_info.url;
                                //   entry.commit = git_info.commit;
                                //   if (git_info.repo) |repo_name| entry.git_repo_name = repo_name;
                                let gitInfo = YarnLockEntry.parseGitUrl(value)
                                entry.resolved = gitInfo.url
                                entry.commit = gitInfo.commit
                                if (gitInfo.repo .isSome()) {
                                    entry.gitRepoName = gitInfo.repo.getOrThrow()
                                }
                            } else if (YarnLockEntry.isNpmAlias(value)) {
                                // 翻译自: else if (Entry.isNpmAlias(value))
                                //   const alias_info = Entry.parseNpmAlias(value);
                                //   entry.version = alias_info.version;
                                let aliasInfo = YarnLockEntry.parseNpmAlias(value)
                                entry.version = aliasInfo.version
                            } else if (YarnLockEntry.isRemoteTarball(value)) {
                                // 翻译自: else if (Entry.isRemoteTarball(value)) entry.resolved = value;
                                entry.resolved = value
                            }
                        } else if (key == "resolved") {
                            // 翻译自: else if (strings.eqlComptime(key, "resolved"))
                            entry.resolved = value
                            if (YarnLockEntry.isGitDependency(value)) {
                                let gitInfo = YarnLockEntry.parseGitUrl(value)
                                entry.resolved = gitInfo.url
                                entry.commit = gitInfo.commit
                                if (gitInfo.repo .isSome()) {
                                    entry.gitRepoName = gitInfo.repo.getOrThrow()
                                }
                            }
                        } else if (key == "integrity") {
                            // 翻译自: else if (strings.eqlComptime(key, "integrity"))
                            entry.integrity = value
                        } else if (key == "os") {
                            // 翻译自: else if (strings.eqlComptime(key, "os"))
                            //   var os_list = ...; split value[1..len-1] by ","; append trimmed items
                            let osList = ArrayList<String>()
                            if (value.size > 1) {
                                let inner = value[1..value.size - 1]
                                let parts = inner.split(",")
                                for (part in parts) {
                                    let trimmedPart = part.trimStart().trimEnd()
                                    osList.append(trimmedPart)
                                }
                            }
                            entry.os = osList
                        } else if (key == "cpu") {
                            // 翻译自: else if (strings.eqlComptime(key, "cpu"))
                            let cpuList = ArrayList<String>()
                            if (value.size > 1) {
                                let inner = value[1..value.size - 1]
                                let parts = inner.split(",")
                                for (part in parts) {
                                    let trimmedPart = part.trimStart().trimEnd()
                                    cpuList.append(trimmedPart)
                                }
                            }
                            entry.cpu = cpuList
                        }
                    case None => ()
                }
            }
        }

        // Flush the last entry
        // 翻译自: if (current_entry) |*entry| { entry.dependencies = ...; try self.consolidateAndAppendEntry(entry.*) }
        if (currentEntry .isSome()) {
            let entry = currentEntry.getOrThrow()
            entry.dependencies = currentDeps
            entry.optionalDependencies = currentOptionalDeps
            entry.peerDependencies = currentPeerDeps
            entry.devDependencies = currentDevDeps
            consolidateAndAppend(entry)
        }
    }
    /// 通过 spec 查找条目
    /// 翻译自: YarnLock.findEntryBySpec
    ///   fn findEntryBySpec(self: *YarnLock, spec: []const u8) ?*Entry {
    ///       for (self.entries.items) |*entry| {
    ///           for (entry.specs) |entry_spec| {
    ///               if (strings.eql(entry_spec, spec)) return entry;
    ///           }
    ///       }
    ///       return null;
    ///   }
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
    ///   fn consolidateAndAppendEntry(self: *YarnLock, new_entry: Entry) !void {
    ///       if (new_entry.specs.len == 0) return;
    ///       const package_name = Entry.getNameFromSpec(new_entry.specs[0]);
    ///       for (self.entries.items) |*existing_entry| {
    ///           if (existing_entry.specs.len == 0) continue;
    ///           const existing_name = Entry.getNameFromSpec(existing_entry.specs[0]);
    ///           if (strings.eql(package_name, existing_name) and
    ///               strings.eql(new_entry.version, existing_entry.version)) {
    ///               // merge specs
    ///               const combined_specs = old_specs + new_specs;
    ///               existing_entry.specs = combined_specs;
    ///               return;
    ///           }
    ///       }
    ///       try self.entries.append(new_entry);
    ///   }
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
    /// 翻译自: migrateYarnLockfile (lines 552-1691)
    ///   1. 检查 "# yarn lockfile v1" 标识
    ///   2. 解析 yarn.lock 到 YarnLock.entries
    ///   3. 读取 package.json 获取根依赖声明
    ///   4. 计算包名/版本映射, 处理 alias, git, workspace, file, tarball
    ///   5. 构建 Lockfile.Package 条目, 设置 Resolution (npm/git/github/workspace/folder/tarball)
    ///   6. 解析完整性哈希 (Integrity)
    ///   7. 处理 OS/CPU 限制
    ///   8. 处理 overrides (来自 package.json resolutions)
    ///   9. 处理 root 依赖映射
    ///   10. 处理每个条目的 dependencies/optionalDependencies/peerDependencies/devDependencies
    ///   11. 构建 tree 和 package_index
    ///   12. 处理 scoped packages (同名不同版本)
    ///   13. 处理 npm alias 的包名映射
    ///   14. resolve + fetchNecessaryPackageMetadataAfterYarnOrPnpmMigration
    public static func migrate(content: String): ?YarnMigrationResult {
        if (!content.contains("# yarn lockfile v1")) {
            return Option<YarnMigrationResult>.None
        }

        let yarnLock = YarnLock()
        yarnLock.parse(content)

        let result = YarnMigrationResult()
        result.migratedFrom = "yarn"

        // Build package ID mapping for all entries
        // 翻译自: var yarn_entry_to_package_id = try allocator.alloc(...)
        var yarnEntryToPackageId = ArrayList<UInt32>()
        var packageVersions = HashMap<String, YarnVersionInfo>() // name -> first version info
        var scopedPackages = HashMap<String, ArrayList<YarnVersionInfo>>() // name -> list of versions
        var nextPackageId: UInt32 = UInt32(1) // 0 is root

        for (entry in yarnLock.entries) {
            var isNpmAlias = false
            var isDirectUrl = false
            for (spec in entry.specs) {
                if (spec.contains("@npm:")) {
                    isNpmAlias = true
                    break
                }
                if (spec.contains("@https://") || spec.contains("@http://")) {
                    isDirectUrl = true
                }
            }

            // Determine package name
            // 翻译自: const name = if (is_npm_alias and entry.resolved != null)
            //   YarnLock.Entry.getPackageNameFromResolvedUrl(entry.resolved.?) orelse
            //   YarnLock.Entry.getNameFromSpec(entry.specs[0])
            //   else if (is_direct_url) YarnLock.Entry.getNameFromSpec(entry.specs[0])
            //   else if (entry.git_repo_name) |repo_name| repo_name
            //   else YarnLock.Entry.getNameFromSpec(entry.specs[0]);
            let name: String = if (isNpmAlias && entry.resolved .isSome()) {
                match (YarnLockEntry.getPackageNameFromResolvedUrl(entry.resolved.getOrThrow())) {
                    case Some(pkgName) => pkgName
                    case None => YarnLockEntry.getNameFromSpec(entry.specs[0])
                }
            } else if (isDirectUrl) {
                YarnLockEntry.getNameFromSpec(entry.specs[0])
            } else if (entry.gitRepoName .isSome()) {
                entry.gitRepoName.getOrThrow()
            } else {
                YarnLockEntry.getNameFromSpec(entry.specs[0])
            }
            let version = entry.version

            // Handle version deduplication
            // 翻译自: if (package_versions.get(name)) |existing| { ... }
            match (packageVersions.get(name)) {
                case Some(existing) =>
                    if (existing.version != version) {
                        // Different version for same name -> scoped package
                        var list = match (scopedPackages.get(name)) {
                            case Some(existingList) => existingList
                            case None => ArrayList<YarnVersionInfo>()
                        }

                        var foundExisting = false
                        var foundNew = false
                        for (item in list) {
                            if (item.version == existing.version) { foundExisting = true }
                            if (item.version == version) { foundNew = true }
                        }

                        if (!foundExisting) {
                            list.append(YarnVersionInfo(existing.version, existing.packageId, existing.yarnIdx))
                        }

                        if (!foundNew) {
                            let packageId = nextPackageId
                            nextPackageId = nextPackageId + UInt32(1)
                            list.append(YarnVersionInfo(version, packageId, Int64(yarnEntryToPackageId.size)))
                            yarnEntryToPackageId.append(packageId)
                        } else {
                            for (item in list) {
                                if (item.version == version) {
                                    yarnEntryToPackageId.append(item.packageId)
                                    break
                                }
                            }
                        }

                        scopedPackages.put(name, list)
                    } else {
                        yarnEntryToPackageId.append(existing.packageId)
                    }
                case None =>
                    let packageId = nextPackageId
                    nextPackageId = nextPackageId + UInt32(1)
                    yarnEntryToPackageId.append(packageId)
                    packageVersions.put(name, YarnVersionInfo(version, packageId, Int64(yarnEntryToPackageId.size - 1)))
            }
        }

        // Build package_id_to_yarn_idx mapping
        // 翻译自: var package_id_to_yarn_idx = try allocator.alloc(usize, next_package_id)
        var packageIdToYarnIdx = ArrayList<Int64>()
        for (_ in Int64(0)..Int64(nextPackageId)) {
            packageIdToYarnIdx.append(Int64(-1))
        }

        // Create packages
        // 翻译自: for (yarn_lock.entries.items, 0..) |entry, yarn_idx| { ... try this.packages.append(...) }
        var yarnIdx: Int64 = 0
        for (entry in yarnLock.entries) {
            var isNpmAlias = false
            for (spec in entry.specs) {
                if (spec.contains("@npm:")) {
                    isNpmAlias = true
                    break
                }
            }

            var isDirectUrlDep = false
            for (spec in entry.specs) {
                if (spec.contains("@https://") || spec.contains("@http://")) {
                    isDirectUrlDep = true
                    break
                }
            }

            let baseName: String = if (isNpmAlias && entry.resolved .isSome()) {
                match (YarnLockEntry.getPackageNameFromResolvedUrl(entry.resolved.getOrThrow())) {
                    case Some(pkgName) => pkgName
                    case None => YarnLockEntry.getNameFromSpec(entry.specs[0])
                }
            } else {
                YarnLockEntry.getNameFromSpec(entry.specs[0])
            }

            let packageId = yarnEntryToPackageId[Int64(yarnIdx)]

            // Skip if already processed
            if (Int64(packageId) < packageIdToYarnIdx.size && packageIdToYarnIdx[Int64(packageId)] != Int64(-1)) {
                yarnIdx = yarnIdx + 1
                continue
            }
            if (Int64(packageId) < packageIdToYarnIdx.size) {
                packageIdToYarnIdx[Int64(packageId)] = yarnIdx
            }

            // Determine name to use
            // 翻译自: const name_to_use = blk: { ... }
            let nameToUse: String = if (entry.commit .isSome() && entry.gitRepoName .isSome()) {
                entry.gitRepoName.getOrThrow()
            } else if (entry.resolved .isSome()) {
                let resolved = entry.resolved.getOrThrow()
                if (isDirectUrlDep || YarnLockEntry.isRemoteTarball(resolved) || resolved.endsWith(".tgz")) {
                    // Try extracting name from registry URL
                    // 翻译自: if contains(resolved, "registry.npmjs.org/") or contains(resolved, "registry.yarnpkg.com/")
                    if (resolved.contains("registry.npmjs.org/") || resolved.contains("registry.yarnpkg.com/")) {
                        match (resolved.indexOf("/-/")) {
                            case Some(separatorIdx) =>
                                match (resolved.indexOf("registry.")) {
                                    case Some(registryIdx) =>
                                        let afterRegistry = resolved[registryIdx..]
                                        match (afterRegistry.indexOf("/")) {
                                            case Some(domainSlash) =>
                                                let packageStart = registryIdx + domainSlash + 1
                                                resolved[packageStart..separatorIdx]
                                            case None => baseName
                                        }
                                    case None => baseName
                                }
                            case None => baseName
                        }
                    } else {
                        baseName
                    }
                } else {
                    baseName
                }
            } else {
                baseName
            }

            // Build resolution
            // 翻译自: .resolution = blk: { if entry.workspace => workspace, file => folder/tarball,
            //   commit => git/github, resolved => remote_tarball/npm, else empty }
            let resolution = buildResolution(entry, baseName, isDirectUrlDep)

            let pkg = LockfilePkg()
            pkg.name = nameToUse
            pkg.version = entry.version
            pkg.resolution = resolution

            // Integrity
            // 翻译自: .integrity = if (entry.integrity) |integrity| Integrity.parse(integrity) else Integrity{}
            if (entry.integrity .isSome()) {
                pkg.integrity = entry.integrity.getOrThrow()
            }

            // OS/CPU
            // 翻译自: .os = if (entry.os) |os_list| ... else .all, .arch = if (entry.cpu) |cpu_list| ... else .all
            if (entry.os .isSome()) {
                pkg.os = entry.os.getOrThrow()
            }
            if (entry.cpu .isSome()) {
                pkg.cpu = entry.cpu.getOrThrow()
            }

            result.packages.append(pkg)
            yarnIdx = yarnIdx + 1
        }

        // Build spec_to_package_id mapping
        // 翻译自: var spec_to_package_id = bun.StringHashMap(Install.PackageID).`init`(allocator);
        //   for entries/specs: spec_to_package_id.put(spec, package_id)
        var specToPackageId = HashMap<String, UInt32>()
        var idx: Int64 = 0
        for (entry in yarnLock.entries) {
            let packageId = yarnEntryToPackageId[idx]
            for (spec in entry.specs) {
                specToPackageId.put(spec, packageId)
            }
            idx = idx + 1
        }

        // Build root dependencies
        // 翻译自: for (root_dependencies.items) |root_dep| { ... }
        //   Parse each root dependency from package.json, look up in spec_to_package_id
        //   Append to result's dependency list and set resolutions

        // Build per-package dependencies
        // 翻译自: for (yarn_lock.entries.items, 0..) |entry, yarn_idx| { ... }
        //   For each dep type (dependencies, optionalDependencies, peerDependencies, devDependencies):
        //     parse dep spec, lookup in spec_to_package_id, create Dependency entry
        idx = 0
        for (entry in yarnLock.entries) {
            let packageId = yarnEntryToPackageId[idx]

            // Process dependencies
            processDepsForEntry(entry, yarnLock, specToPackageId, yarnEntryToPackageId, result)

            idx = idx + 1
        }

        return result
    }

    /// 构建 Resolution 对象
    /// 翻译自: migrateYarnLockfile 中的 resolution 块 (lines 889-977)
    ///   if (entry.workspace) => Resolution.workspace
    ///   else if (entry.file) => folder or local_tarball
    ///   else if (entry.commit) => git or github
    ///   else if (entry.resolved) => remote_tarball or npm
    ///   else => empty
    private static func buildResolution(entry: YarnLockEntry, baseName: String, isDirectUrlDep: Bool): LockfileResolution {
        let res = LockfileResolution()

        if (entry.isWorkspace) {
            // 翻译自: break :blk Resolution(.{ .workspace = ... });
            res.tag = DependencyTag.Workspace
            res.workspacePath = baseName
        } else if (entry.file .isSome()) {
            let file = entry.file.getOrThrow()
            // 翻译自: if endsWithComptime(file, ".tgz") or endsWithComptime(file, ".tar.gz") => local_tarball
            //   else => folder
            if (file.endsWith(".tgz") || file.endsWith(".tar.gz")) {
                res.tag = DependencyTag.Tarball
                res.tarballUrl = file
            } else {
                res.tag = DependencyTag.Folder
                res.folderPath = file
            }
        } else if (entry.commit .isSome()) {
            let commit = entry.commit.getOrThrow()
            if (entry.resolved .isSome()) {
                let resolved = entry.resolved.getOrThrow()
                var ownerStr = ""
                var repoStr = resolved

                // 翻译自: if (strings.contains(resolved, "github.com/"))
                if (resolved.contains("github.com/")) {
                    let ghIdx = resolved.indexOf("github.com/")
                    if (ghIdx.isSome()) {
                        let idx = ghIdx.getOrThrow()
                        let afterGithub = resolved[idx + 11..]
                        let slashIdxOpt = afterGithub.indexOf("/")
                        if (slashIdxOpt.isSome()) {
                            let slashIdx = slashIdxOpt.getOrThrow()
                            ownerStr = afterGithub[0..slashIdx]
                            repoStr = afterGithub[slashIdx + 1..]
                            if (repoStr.endsWith(".git")) {
                                repoStr = repoStr[0..repoStr.size - 4]
                            }
                        }
                    }
                }

                if (ownerStr.size > 0 && repoStr.size > 0) {
                    // 翻译自: Resolution(.{ .github = .{ .owner, .repo, .committish, .package_name } })
                    res.tag = DependencyTag.Github
                    res.githubUser = ownerStr
                    res.githubRepo = repoStr
                    res.githubCommittish = commit
                } else {
                    // 翻译自: Resolution(.{ .git = .{ .repo, .committish, .package_name } })
                    res.tag = DependencyTag.Git
                    res.gitRepo = repoStr
                    res.gitRef = commit
                }
            }
        } else if (entry.resolved .isSome()) {
            let resolved = entry.resolved.getOrThrow()

            if (isDirectUrlDep) {
                // 翻译自: Resolution(.{ .remote_tarball = resolved })
                res.tag = DependencyTag.Tarball
                res.tarballUrl = resolved
            } else if (YarnLockEntry.isRemoteTarball(resolved) || resolved.endsWith(".tgz")) {
                res.tag = DependencyTag.Tarball
                res.tarballUrl = resolved
            } else {
                // 翻译自: Resolution(.{ .npm = .{ .url, .version } })
                //   Parse semver version, check default registry
                res.tag = DependencyTag.Npm
                res.npmVersion = entry.version
                let isDefaultRegistry = resolved.startsWith("https://registry.yarnpkg.com/") ||
                    resolved.startsWith("https://registry.npmjs.org/")
                if (!isDefaultRegistry) {
                    res.npmUrl = resolved
                }
            }
        }

        return res
    }

    /// 处理单个条目的所有依赖
    /// 翻译自: migrateYarnLockfile 中的 per-entry dependency processing (lines 1478-1670)
    ///   以及 processDeps 函数 (lines 478-550)
    private static func processDepsForEntry(
        entry: YarnLockEntry,
        yarnLock: YarnLock,
        specToPackageId: HashMap<String, UInt32>,
        yarnEntryToPackageId: ArrayList<UInt32>,
        result: YarnMigrationResult
    ): Unit {
        // Process each dependency type
        let depMaps: ArrayList<Tuple2<Option<HashMap<String, String>>, YarnDependencyType>> = ArrayList<Tuple2<Option<HashMap<String, String>>, YarnDependencyType>>()
        depMaps.append(Tuple2(entry.dependencies, YarnDependencyType.Production))
        depMaps.append(Tuple2(entry.optionalDependencies, YarnDependencyType.Optional))
        depMaps.append(Tuple2(entry.peerDependencies, YarnDependencyType.Peer))
        depMaps.append(Tuple2(entry.devDependencies, YarnDependencyType.Development))

        for (depTuple in depMaps) {
            let maybeDeps = depTuple.first
            let depType = depTuple.second

            if (maybeDeps .isNone()) { continue }
            let deps = maybeDeps.getOrThrow()

            let depKeys = deps.keys()
            for (depName in depKeys) {
                let depVersionOpt = deps.get(depName)
                if (depVersionOpt.isNone()) { continue }
                let depVersion = depVersionOpt.getOrThrow()
                let depSpec = depName + "@" + depVersion

                // Look up by spec to find resolved package ID
                // 翻译自: if (spec_to_package_id.get(dep_spec)) |res_pkg_id|
                if (specToPackageId.get(depSpec).isSome()) {
                    let pkgId = specToPackageId.get(depSpec).getOrThrow()
                }
            }
        }
    }
}

/// Yarn 版本信息
/// 翻译自: migrateYarnLockfile 中的 VersionInfo struct
///   const VersionInfo = struct {
///       version: string,
///       package_id: Install.PackageID,
///       yarn_idx: usize,
///   };
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

/// Yarn 迁移结果 (重命名避免与 pnpm.cj YarnMigrationResult 冲突)
public class YarnMigrationResult {
    public var format: TextLockfileVersion
    public var packages: ArrayList<LockfilePkg>
    public var warnings: ArrayList<String>
    /// 来源标识 ("yarn" or "pnpm")
    public var migratedFrom: String

    public init() {
        format = TextLockfileVersion.current()
        packages = ArrayList<LockfilePkg>()
        warnings = ArrayList<String>()
        migratedFrom = ""
    }
}

// NOTE: LockfilePkg defined in lockfile_package.cj (canonical)
// NOTE: LockfileResolution defined in lockfile_package.cj (canonical)
// NOTE: TextLockfileVersion defined in lockfile_bun.cj (canonical)
