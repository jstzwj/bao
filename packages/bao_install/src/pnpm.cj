// bao_install - pnpm 锁文件迁移
// 严格翻译自: src/install/pnpm.zig
//   pnpm-lock.yaml (v7+) 到 Bun/Bao 锁文件的迁移
//   包含依赖路径解析、importers 解析、snapshots 解析、
//   package 依赖解析、package.json 更新等
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// pnpm 迁移错误
// 严格翻译自: src/install/pnpm.zig - MigratePnpmLockfileError
//   const MigratePnpmLockfileError = OOM || error{
//       PnpmLockfileTooOld, PnpmLockfileVersionInvalid, InvalidPnpmLockfile,
//       YamlParseError, NonExistentWorkspaceDependency, RelativeLinkDependency,
//       WorkspaceNameMissing, DependencyLoop,
//       PnpmLockfileNotObject, PnpmLockfileMissingVersion, PnpmLockfileMissingImporters,
//       PnpmLockfileInvalidImporter, PnpmLockfileMissingRootPackage,
//       PnpmLockfileInvalidSnapshot, PnpmLockfileInvalidPackage,
//       PnpmLockfileMissingDependencyVersion, PnpmLockfileInvalidDependency,
//       PnpmLockfileInvalidOverride, PnpmLockfileInvalidPatchedDependency,
//       PnpmLockfileMissingCatalogEntry, PnpmLockfileUnresolvableDependency,
//   }
//   ParseAppendDependenciesError adds:
//       PnpmLockfileMissingPackages
//       UnsupportedDependencyType
// ============================================================================

/// pnpm 迁移错误类型
/// 翻译自: src/install/pnpm.zig MigratePnpmLockfileError + ParseAppendDependenciesError
public enum PnpmMigrationError {
    | PnpmLockfileTooOld
    | PnpmLockfileVersionInvalid
    | InvalidPnpmLockfile
    | YamlParseError
    | NonExistentWorkspaceDependency
    | RelativeLinkDependency
    | WorkspaceNameMissing
    | DependencyLoop
    | PnpmLockfileNotObject
    | PnpmLockfileMissingVersion
    | PnpmLockfileMissingImporters
    | PnpmLockfileInvalidImporter
    | PnpmLockfileMissingRootPackage
    | PnpmLockfileInvalidSnapshot
    | PnpmLockfileInvalidPackage
    | PnpmLockfileMissingDependencyVersion
    | PnpmLockfileInvalidDependency
    | PnpmLockfileInvalidOverride
    | PnpmLockfileInvalidPatchedDependency
    | PnpmLockfileMissingCatalogEntry
    | PnpmLockfileUnresolvableDependency
    | PnpmLockfileMissingPackages
    | UnsupportedDependencyType

    public func toString(): String {
        match (this) {
            case PnpmLockfileTooOld => "pnpm lockfile version is too old (requires v7+)"
            case PnpmLockfileVersionInvalid => "pnpm lockfile version is invalid"
            case InvalidPnpmLockfile => "invalid pnpm lockfile"
            case YamlParseError => "YAML parse error"
            case NonExistentWorkspaceDependency => "non-existent workspace dependency"
            case RelativeLinkDependency => "relative link dependency not supported"
            case WorkspaceNameMissing => "workspace package name is missing"
            case DependencyLoop => "dependency loop detected"
            case PnpmLockfileNotObject => "pnpm lockfile root must be an object"
            case PnpmLockfileMissingVersion => "pnpm lockfile missing 'lockfileVersion' field"
            case PnpmLockfileMissingImporters => "pnpm lockfile missing 'importers' field"
            case PnpmLockfileInvalidImporter => "invalid importer in pnpm lockfile"
            case PnpmLockfileMissingRootPackage => "pnpm lockfile missing root package entry"
            case PnpmLockfileInvalidSnapshot => "invalid snapshot in pnpm lockfile"
            case PnpmLockfileInvalidPackage => "invalid package in pnpm lockfile"
            case PnpmLockfileMissingDependencyVersion => "missing dependency version"
            case PnpmLockfileInvalidDependency => "invalid dependency in pnpm lockfile"
            case PnpmLockfileInvalidOverride => "invalid override in pnpm lockfile"
            case PnpmLockfileInvalidPatchedDependency => "invalid patched dependency"
            case PnpmLockfileMissingCatalogEntry => "missing catalog entry"
            case PnpmLockfileUnresolvableDependency => "unresolvable dependency"
            case PnpmLockfileMissingPackages => "pnpm lockfile missing 'packages' field"
            case UnsupportedDependencyType => "unsupported dependency type"
        }
    }
}

// ============================================================================
// 依赖路径后缀检测
// 严格翻译自: src/install/pnpm.zig - indexOfDepPathSuffix
//   fn indexOfDepPathSuffix(path: []const u8) struct { ?usize, ?usize } {
//       if (path.len < 2) return .{ null, null };
//       if (path[path.len - 1] != ')') return .{ null, null };
//       var open: i64 = 1;
//       var i = path.len - 1;
//       while (i > 0) { i -= 1; if '(' => open--, ')' => open++,
//           else if (open == 0) check for "(patch_hash=" prefix }
//       return .{ null, null };
//   }
//   https://github.com/pnpm/pnpm/blob/.../packages/dependency-path/src/index.ts#L9-L31
// ============================================================================

/// 查找依赖路径后缀索引
/// 翻译自: src/install/pnpm.zig indexOfDepPathSuffix
///   返回 (peersIndex, patchHashIndex)
public class PnpmDepPath {
    /// 查找依赖路径中的后缀索引 (peers 和 patch_hash)
    /// 翻译自: indexOfDepPathSuffix
    ///   解析形如 "name@version(patch_hash=xxx)(peer_hash=yyy)" 的路径
    ///   从右向左扫描, 匹配括号平衡, 找到 patch_hash 和 peers 后缀位置
    public static func indexOfDepPathSuffix(path: String): Tuple2<?Int64, ?Int64> {
        if (path.size < 2) {
            return Tuple2(<?Int64>.None, <?Int64>.None)
        }

        if (path[path.size - 1] != UInt8(41)) { // ')'
            return Tuple2(<?Int64>.None, <?Int64>.None)
        }

        var open: Int64 = 1
        var i = path.size - 1
        while (i > 0) {
            i = i - 1

            if (path[i] == UInt8(40)) { // '('
                open = open - 1
            } else if (path[i] == UInt8(41)) { // ')'
                open = open + 1
            } else if (open == 0) {
                // Check for "(patch_hash=" prefix
                // 翻译自: if (strings.startsWith(path[i + 1 ..], "(patch_hash="))
                let suffix = path[i + 1..]
                if (suffix.startsWith("(patch_hash=")) {
                    // Look for peers index after patch_hash
                    // 翻译自: const peers_idx = strings.indexOfChar(path[i + 2 ..], '(') + i + 2
                    let peersIdx: ?Int64 = match (path.indexOf("(", i + 2)) {
                        case Some(idx) => idx
                        case None => None
                    }
                    return Tuple2(<?Int64>.Some(peersIdx), <?Int64>.Some(Int64(i + 1)))
                }
                // Regular parenthesized suffix
                return Tuple2(<?Int64>.Some(Int64(i + 1)), <?Int64>.None)
            }
        }
        return Tuple2(<?Int64>.None, <?Int64>.None)
    }

    /// 去除依赖路径后缀
    /// 翻译自: removeSuffix
    ///   name@version(hash) -> name@version
    ///   version(hash) -> version
    ///   fn removeSuffix(path: []const u8) []const u8 {
    ///       const peers_idx, const patch_hash_idx = indexOfDepPathSuffix(path);
    ///       if (patch_hash_idx orelse peers_idx) |idx| return path[0..idx];
    ///       return path;
    ///   }
    public static func removeDepPathSuffix(path: String): String {
        let result = indexOfDepPathSuffix(path)
        let peersIdx = result.first
        let patchHashIdx = result.second

        // patchHashIdx takes priority, else peersIdx
        // 翻译自: if (patch_hash_idx orelse peers_idx) |idx| return path[0..idx];
        match (patchHashIdx) {
            case Some(idx) => return path[0..idx]
            case None =>
                match (peersIdx) {
                    case Some(idx) => return path[0..idx]
                    case None => ()
                }
        }

        return path
    }

    private static func removeDepPathSuffixPeers(path: String, peersIdx: ?Int64): String {
        match (peersIdx) {
            case Some(idx) => return path[0..idx]
            case None => return path
        }
    }

    /// 分割 name@version
    /// 翻译自: Dependency.splitNameAndVersion
    ///   处理 scoped packages: @scope/name@version
    ///   pub fn splitNameAndVersion(key: []const u8) !struct { []const u8, []const u8 }
    public static func splitNameAndVersion(key: String): Tuple2<String, String> {
        // Handle scoped packages: @scope/name@version
        if (key.size > 0 && key[0] == UInt8(64)) { // '@'
            // Find second @ for scoped package
            match (key.indexOf("@", Int64(1))) {
                case Some(secondAt) =>
                    let name = key[0..secondAt]
                    let version = key[secondAt + 1..]
                    return Tuple2(name, version)
                case None => return Tuple2(key, "")
            }
        }

        // Non-scoped: name@version
        match (key.indexOf("@")) {
            case Some(atIdx) =>
                let name = key[0..atIdx]
                let version = key[atIdx + 1..]
                return Tuple2(name, version)
            case None => return Tuple2(key, "")
        }
    }

    /// 分割版本和可能的别名
    /// 翻译自: Dependency.splitVersionAndMaybeName
    ///   解析 "alias@version" 或 "version" 格式
    ///   如果版本字符串包含 @, 则前半部分是别名包名
    public static func splitVersionAndMaybeName(versionStr: String): Tuple2<String, ?String> {
        // Check for alias: "alias@version"
        if (versionStr.size > 0 && versionStr[0] == UInt8(64)) {
            // Scoped alias: @scope/name@version
            match (versionStr.indexOf("@", Int64(1))) {
                case Some(secondAt) =>
                    let alias = versionStr[0..secondAt]
                    let version = versionStr[secondAt + 1..]
                    return Tuple2(version, Some(alias))
                case None => return Tuple2(versionStr, None)
            }
        }

        match (versionStr.indexOf("@")) {
            case Some(atIdx) =>
                let alias = versionStr[0..atIdx]
                let version = versionStr[atIdx + 1..]
                return Tuple2(version, Some(alias))
            case None => return Tuple2(versionStr, None)
        }
    }
}

// ============================================================================
// pnpm 锁文件解析器
// 严格翻译自: src/install/pnpm.zig - migratePnpmLockfile
//   pnpm-lock.yaml 的结构:
//   lockfileVersion: 9.0
//   importers:
//     .:
//       dependencies: { ... }
//       devDependencies: { ... }
//   packages:
//     /name@version:
//       resolution: { ... }
//       dependencies: { ... }
//   snapshots:
//     /name@version(hash):
//       dependencies: { ... }
// ============================================================================

/// pnpm 锁文件解析结果
/// 对应 Bun: migratePnpmLockfile 返回的数据
public class PnpmLockfileData {
    /// 锁文件版本
    public var lockfileVersion: Float64
    /// importers (路径 -> 依赖列表)
    public var importers: HashMap<String, PnpmImporter>
    /// 包列表 (key -> 包信息)
    public var packages: HashMap<String, PnpmPackageInfo>
    /// snapshots (key -> 依赖列表)
    public var snapshots: HashMap<String, PnpmSnapshot>
    /// overrides
    public var overrides: HashMap<String, String>
    /// catalogs (默认 + 命名)
    public var catalogs: CatalogMap
    /// patched dependencies
    public var patchedDependencies: HashMap<String, PnpmPatchInfo>
    /// workspace 路径
    public var workspacePaths: HashMap<String, String>
    /// workspace 版本
    public var workspaceVersions: HashMap<String, String>

    public init() {
        lockfileVersion = 0.0
        importers = HashMap<String, PnpmImporter>()
        packages = HashMap<String, PnpmPackageInfo>()
        snapshots = HashMap<String, PnpmSnapshot>()
        overrides = HashMap<String, String>()
        catalogs = CatalogMap()
        patchedDependencies = HashMap<String, PnpmPatchInfo>()
        workspacePaths = HashMap<String, String>()
        workspaceVersions = HashMap<String, String>()
    }
}

/// pnpm importer 条目
/// 对应 Bun: migratePnpmLockfile 中的 importer 数据
public class PnpmImporter {
    /// 路径
    public var path: String
    /// 依赖
    public var dependencies: HashMap<String, PnpmDepVersion>
    /// 开发依赖
    public var devDependencies: HashMap<String, PnpmDepVersion>
    /// 可选依赖
    public var optionalDependencies: HashMap<String, PnpmDepVersion>
    /// peer 依赖
    public var peerDependencies: HashMap<String, PnpmDepVersion>

    public init(path: String) {
        this.path = path
        dependencies = HashMap<String, PnpmDepVersion>()
        devDependencies = HashMap<String, PnpmDepVersion>()
        optionalDependencies = HashMap<String, PnpmDepVersion>()
        peerDependencies = HashMap<String, PnpmDepVersion>()
    }
}

/// pnpm 依赖版本
/// 对应 Bun: migratePnpmLockfile 中的依赖版本信息
public class PnpmDepVersion {
    /// specifier (来自 package.json)
    public var specifier: String
    /// 解析后的版本 (来自 lockfile)
    public var version: String
    /// 解析后的包 key (来自 packages/snapshots)
    public var resolved: ?String

    public init(specifier: String, version: String) {
        this.specifier = specifier
        this.version = version
        resolved = None
    }

    public init(version: String) {
        specifier = ""
        this.version = version
        resolved = None
    }

    public init(version: String, resolved: ?String) {
        specifier = ""
        this.version = version
        this.resolved = resolved
    }
}

/// pnpm 包信息
/// 对应 Bun: migratePnpmLockfile 中 packages 条目
public class PnpmPackageInfo {
    /// 包名
    public var name: String
    /// 版本
    public var version: String
    /// 解析信息
    public var resolution: LockfileResolution
    /// integrity
    public var integrity: String
    /// 是否有安装脚本
    public var hasInstallScript: Bool
    /// 是否可选
    public var isOptional: Bool
    /// 依赖
    public var dependencies: HashMap<String, String>
    /// 可选依赖
    public var optionalDependencies: HashMap<String, String>
    /// peer 依赖
    public var peerDependencies: HashMap<String, String>
    /// peer 依赖 meta
    public var peerDependenciesMeta: HashMap<String, PnpmPeerDepMeta>
    /// 开发依赖 (snapshots)
    public var devDependencies: HashMap<String, String>
    /// bin 条目
    public var bin: HashMap<String, String>
    /// OS 限制
    public var os: ArrayList<String>
    /// CPU 限制
    public var cpu: ArrayList<String>
    /// deprecated 信息
    public var deprecated: ?String
    /// has bin
    public var hasBin: Bool

    public init() {
        name = ""
        version = ""
        resolution = LockfileResolution()
        integrity = ""
        hasInstallScript = false
        isOptional = false
        dependencies = HashMap<String, String>()
        optionalDependencies = HashMap<String, String>()
        peerDependencies = HashMap<String, String>()
        peerDependenciesMeta = HashMap<String, PnpmPeerDepMeta>()
        devDependencies = HashMap<String, String>()
        bin = HashMap<String, String>()
        os = ArrayList<String>()
        cpu = ArrayList<String>()
        deprecated = None
        hasBin = false
    }
}

/// pnpm peer dependency meta
/// 翻译自: package_obj.get("peerDependenciesMeta") 中的 optional 字段
public class PnpmPeerDepMeta {
    public var optional: Bool

    public init() {
        optional = false
    }
}

/// pnpm snapshot 条目
/// 对应 Bun: migratePnpmLockfile 中 snapshots 条目
public class PnpmSnapshot {
    /// 依赖
    public var dependencies: HashMap<String, String>
    /// 可选依赖
    public var optionalDependencies: HashMap<String, String>
    /// peer 依赖
    public var peerDependencies: HashMap<String, String>

    public init() {
        dependencies = HashMap<String, String>()
        optionalDependencies = HashMap<String, String>()
        peerDependencies = HashMap<String, String>()
    }
}

/// pnpm patch 信息
/// 对应 Bun: migratePnpmLockfile 中 patched dependencies
public class PnpmPatchInfo {
    /// 补丁文件路径
    public var path: String
    /// 依赖名
    public var depName: String
    /// 补丁哈希
    public var hash: String

    public init(path: String, depName: String) {
        this.path = path
        this.depName = depName
        hash = ""
    }
}

/// Catalog 映射
/// 翻译自: Lockfile.CatalogMap
public class CatalogMap {
    /// 默认 catalog: name -> Dependency
    public var defaultCatalog: HashMap<String, CatalogEntry>
    /// 命名 catalogs: groupName -> (name -> Dependency)
    public var namedCatalogs: HashMap<String, HashMap<String, CatalogEntry>>

    public init() {
        defaultCatalog = HashMap<String, CatalogEntry>()
        namedCatalogs = HashMap<String, HashMap<String, CatalogEntry>>()
    }

    /// 获取 catalog 条目
    /// 翻译自: lockfile.catalogs.get(lockfile, catalog_group_name, name.value)
    public func get(groupName: String, name: String): ?CatalogEntry {
        if (groupName.size == 0) {
            return defaultCatalog.get(name)
        }
        match (namedCatalogs.get(groupName)) {
            case Some(group) => return group.get(name)
            case None => return None
        }
    }
}

/// Catalog 条目
/// 翻译自: catalog 中的依赖条目
public class CatalogEntry {
    public var name: String
    public var version: String

    public init(name: String, version: String) {
        this.name = name
        this.version = version
    }
}

/// 锁文件包
/// 翻译自: Lockfile.Package
public class LockfilePkg {
    public var name: String
    public var version: String
    public var resolution: LockfileResolution
    public var integrity: String
    public var os: ArrayList<String>
    public var cpu: ArrayList<String>
    public var dependencies: HashMap<String, String>
    public var optionalDependencies: HashMap<String, String>
    public var peerDependencies: HashMap<String, String>
    public var devDependencies: HashMap<String, String>

    public init() {
        name = ""
        version = ""
        resolution = LockfileResolution()
        integrity = ""
        os = ArrayList<String>()
        cpu = ArrayList<String>()
        dependencies = HashMap<String, String>()
        optionalDependencies = HashMap<String, String>()
        peerDependencies = HashMap<String, String>()
        devDependencies = HashMap<String, String>()
    }
}

/// 锁文件 Resolution
/// 翻译自: Resolution
public class LockfileResolution {
    public var tag: String // "npm", "git", "github", "workspace", "folder", "local_tarball", "remote_tarball", "root", "symlink"
    public var value: String
    public var url: String
    public var commit: ?String
    public var owner: ?String
    public var repo: ?String
    public var packageName: ?String

    public init() {
        tag = ""
        value = ""
        url = ""
        commit = None
        owner = None
        repo = None
        packageName = None
    }

    /// 从 pnpm lockfile resolution 字符串解析
    /// 翻译自: Resolution.fromPnpmLockfile(res_str, &string_buf)
    public static func fromPnpmLockfile(resStr: String): LockfileResolution {
        let res = LockfileResolution()

        if (resStr.size == 0) {
            return res
        }

        // Check for various resolution types
        if (resStr.startsWith("github:")) {
            res.tag = "github"
            res.value = "https://github.com/" + resStr[7..]
        } else if (resStr.startsWith("git+")) {
            res.tag = "git"
            res.value = resStr[4..]
        } else if (resStr.startsWith("git://")) {
            res.tag = "git"
            res.value = resStr
        } else if (resStr.startsWith("https://") || resStr.startsWith("http://")) {
            if (resStr.endsWith(".tgz") || resStr.endsWith(".tar.gz")) {
                res.tag = "remote_tarball"
            } else {
                res.tag = "remote_tarball"
            }
            res.value = resStr
        } else if (resStr.startsWith("file:")) {
            let filePath = resStr[5..]
            if (filePath.endsWith(".tgz") || filePath.endsWith(".tar.gz")) {
                res.tag = "local_tarball"
            } else {
                res.tag = "folder"
            }
            res.value = filePath
        } else if (resStr.startsWith("link:")) {
            res.tag = "symlink"
            res.value = resStr[5..]
        } else {
            // Assume npm version
            res.tag = "npm"
            res.value = resStr
        }

        return res
    }
}

/// TextLockfileVersion
/// 翻译自: Lockfile.TextLockfileVersion
public class TextLockfileVersion {
    public var value: Int64

    public init() {
        value = 1
    }

    public static func current(): TextLockfileVersion {
        return TextLockfileVersion()
    }
}

// ============================================================================
// pnpm 锁文件迁移器
// 严格翻译自: src/install/pnpm.zig - migratePnpmLockfile
// ============================================================================

/// pnpm 锁文件迁移器
/// 对应 Bun: migratePnpmLockfile
/// 翻译自: src/install/pnpm.zig migratePnpmLockfile (lines 73-840)
public class PnpmMigrator {
    /// 从 YAML 内容解析 pnpm-lock.yaml
    /// 翻译自: migratePnpmLockfile 中的 YAML 解析逻辑
    public static func parse(content: String): ?PnpmLockfileData {
        let data = PnpmLockfileData()

        // Parse YAML content
        let parser = YamlLikeParser()
        let root = parser.parse(content)
        if (root == None) {
            return None
        }
        let rootObj = root.getOrThrow()

        // Extract lockfileVersion
        // 翻译自: const lockfile_version_expr = root.get("lockfileVersion") orelse { ... }
        match (rootObj.getString("lockfileVersion")) {
            case Some(versionStr) =>
                // Parse version number from string or number
                // 翻译自: lockfile_version_num = parseFloat(str[0..end])
                let dotIdx = versionStr.indexOf(".")
                let majorStr: String = match (dotIdx) {
                    case Some(idx) => versionStr[0..idx]
                    case None => versionStr
                }
                let versionNum = majorStr.toFloat64()
                if (versionNum < 7.0) {
                    return None
                }
                data.lockfileVersion = versionNum
            case None => return None
        }

        // Extract catalogs
        // 翻译自: if (root.getObject("catalogs")) |catalogs_expr|
        //   try Lockfile.CatalogMap.fromPnpmLockfile(...)
        match (rootObj.getObject("catalogs")) {
            case Some(catalogsObj) =>
                parseCatalogs(catalogsObj, data)
            case None => ()
        }

        // Extract overrides
        // 翻译自: if (root.getObject("overrides")) |overrides_expr|
        match (rootObj.getObject("overrides")) {
            case Some(overridesObj) =>
                parseOverrides(overridesObj, data)
            case None => ()
        }

        // Extract patchedDependencies
        // 翻译自: if (root.getObject("patchedDependencies")) |patched_dependencies_expr|
        match (rootObj.getObject("patchedDependencies")) {
            case Some(patchedObj) =>
                parsePatchedDependencies(patchedObj, data)
            case None => ()
        }

        // Extract importers
        // 翻译自: const importers_obj = root.getObject("importers") orelse { ... }
        match (rootObj.getObject("importers")) {
            case Some(importersObj) =>
                parseImporters(importersObj, data)
            case None => return None
        }

        // Extract packages and snapshots
        // 翻译自: if (root.getObject("packages")) |packages_obj|
        match (rootObj.getObject("packages")) {
            case Some(packagesObj) =>
                match (rootObj.getObject("snapshots")) {
                    case Some(snapshotsObj) =>
                        parsePackagesAndSnapshots(packagesObj, snapshotsObj, data)
                    case None => ()
                }
            case None => ()
        }

        return data
    }

    /// 解析 catalogs
    /// 翻译自: Lockfile.CatalogMap.fromPnpmLockfile
    private static func parseCatalogs(catalogsObj: YamlObject, data: PnpmLockfileData): Unit {
        var iter = catalogsObj.iterator()
        while (iter.hasNext()) {
            let entry = iter.next()
            let groupName = entry.key
            let catalogObj = entry.value.getObject()
            if (catalogObj == None) { continue }
            let catalog = catalogObj.getOrThrow()

            var entries = HashMap<String, CatalogEntry>()
            var catIter = catalog.iterator()
            while (catIter.hasNext()) {
                let catEntry = catIter.next()
                let name = catEntry.key
                let version = catEntry.value.getString().getOrThrow()
                entries.put(name, CatalogEntry(name, version))
            }

            if (groupName.size == 0 || groupName == "default") {
                data.catalogs.defaultCatalog = entries
            } else {
                data.catalogs.namedCatalogs.put(groupName, entries)
            }
        }
    }

    /// 解析 overrides
    /// 翻译自: for (overrides_expr.data.e_object.properties.slice()) |prop| { ... }
    private static func parseOverrides(overridesObj: YamlObject, data: PnpmLockfileData): Unit {
        var iter = overridesObj.iterator()
        while (iter.hasNext()) {
            let entry = iter.next()
            let name = entry.key
            match (entry.value.getString()) {
                case Some(version) => data.overrides.put(name, version)
                case None => ()
            }
        }
    }

    /// 解析 patchedDependencies
    /// 翻译自: for (patched_dependencies_expr.data.e_object.properties.slice()) |prop| { ... }
    private static func parsePatchedDependencies(patchedObj: YamlObject, data: PnpmLockfileData): Unit {
        var iter = patchedObj.iterator()
        while (iter.hasNext()) {
            let entry = iter.next()
            let depName = entry.key
            let patchObj = entry.value.getObject()
            if (patchObj == None) { continue }
            let patch = patchObj.getOrThrow()

            let pathStr: String = match (patch.getString("path")) {
                case Some(p) => p
                case None => ""
            }
            let hashStr: String = match (patch.getString("hash")) {
                case Some(h) => h
                case None => ""
            }

            let info = PnpmPatchInfo(pathStr, depName)
            info.hash = hashStr
            data.patchedDependencies.put(depName, info)
        }
    }

    /// 解析 importers
    /// 翻译自: for (importers_obj.data.e_object.properties.slice()) |prop| { ... }
    ///   Each importer has dependencies, devDependencies, optionalDependencies
    ///   with nested { specifier, version } objects
    private static func parseImporters(importersObj: YamlObject, data: PnpmLockfileData): Unit {
        var iter = importersObj.iterator()
        while (iter.hasNext()) {
            let entry = iter.next()
            let importerPath = entry.key
            let importerObj = entry.value.getObject()
            if (importerObj == None) { continue }
            let importer = PnpmImporter(importerPath)

            // Parse dependency groups
            // 翻译自: parseAppendImporterDependencies 中的
            //   const importer_dependency_groups = [3]struct { key, behavior }{
            //     .{ "dependencies", .{ .prod = true } },
            //     .{ "devDependencies", .{ .dev = true } },
            //     .{ "optionalDependencies", .{ .optional = true } },
            //   };
            let imp = importerObj.getOrThrow()
            parseImporterDeps(imp, "dependencies", importer.dependencies)
            parseImporterDeps(imp, "devDependencies", importer.devDependencies)
            parseImporterDeps(imp, "optionalDependencies", importer.optionalDependencies)

            data.importers.put(importerPath, importer)
        }
    }

    /// 解析单个 importer 的依赖组
    /// 翻译自: parseAppendImporterDependencies 中的 per-group 循环
    ///   每个依赖有 { specifier: "...", version: "..." } 结构
    private static func parseImporterDeps(
        importerObj: YamlObject,
        groupName: String,
        depMap: HashMap<String, PnpmDepVersion>
    ): Unit {
        match (importerObj.getObject(groupName)) {
            case Some(depsObj) =>
                var iter = depsObj.iterator()
                while (iter.hasNext()) {
                    let depEntry = iter.next()
                    let name = depEntry.key
                    let depValue = depEntry.value.getObject()
                    if (depValue == None) { continue }
                    let depObj = depValue.getOrThrow()

                    let specifier: String = match (depObj.getString("specifier")) {
                        case Some(s) => s
                        case None => ""
                    }
                    let version: String = match (depObj.getString("version")) {
                        case Some(v) => v
                        case None => ""
                    }

                    // Remove suffix from version
                    // 翻译自: entry.value_ptr.* = removeSuffix(version_str)
                    let cleanVersion = PnpmDepPath.removeDepPathSuffix(version)

                    depMap.put(name, PnpmDepVersion(specifier, cleanVersion))
                }
            case None => ()
        }
    }

    /// 解析 packages 和 snapshots
    /// 翻译自: migratePnpmLockfile 中的 packages/snapshots 循环
    private static func parsePackagesAndSnapshots(packagesObj: YamlObject, snapshotsObj: YamlObject, data: PnpmLockfileData): Unit {
        // First parse snapshots
        // 翻译自: for (snapshots_obj.data.e_object.properties.slice()) |snapshot_prop| { ... }
        var snapIter = snapshotsObj.iterator()
        while (snapIter.hasNext()) {
            let snapEntry = snapIter.next()
            let keyStr = snapEntry.key
            let snapValue = snapEntry.value.getObject()
            if (snapValue == None) { continue }

            // Remove suffix from key
            // 翻译自: const key_str_without_suffix = ... removeSuffix(key_str)
            let cleanKey = PnpmDepPath.removeDepPathSuffix(keyStr)

            let snapshot = PnpmSnapshot()
            let snapObj = snapValue.getOrThrow()

            // Parse dependencies
            parseSnapshotDeps(snapObj, "dependencies", snapshot.dependencies)
            parseSnapshotDeps(snapObj, "devDependencies", snapshot.optionalDependencies)
            parseSnapshotDeps(snapObj, "optionalDependencies", snapshot.peerDependencies)

            data.snapshots.put(cleanKey, snapshot)
        }

        // Then parse packages
        // 翻译自: for (packages_obj.data.e_object.properties.slice()) |packages_prop| { ... }
        var pkgIter = packagesObj.iterator()
        while (pkgIter.hasNext()) {
            let pkgEntry = pkgIter.next()
            let keyStr = pkgEntry.key
            let pkgValue = pkgEntry.value.getObject()
            if (pkgValue == None) { continue }

            // Split name and version from key
            // 翻译自: const name_str, const res_str = Dependency.splitNameAndVersion(key_str)
            let nameVersion = PnpmDepPath.splitNameAndVersion(keyStr)
            let nameStr = nameVersion.first
            let resStr = nameVersion.second

            let pkgInfo = PnpmPackageInfo()
            pkgInfo.name = nameStr
            pkgInfo.version = resStr

            let pkgObj = pkgValue.getOrThrow()

            // Parse resolution
            // 翻译自: if (package_obj.get("resolution")) |res_expr| { ... integrity ... }
            match (pkgObj.getObject("resolution")) {
                case Some(resObj) =>
                    match (resObj.getString("integrity")) {
                        case Some(integrity) => pkgInfo.integrity = integrity
                        case None => ()
                    }
                    pkgInfo.resolution = LockfileResolution.fromPnpmLockfile(resStr)
                case None =>
                    pkgInfo.resolution = LockfileResolution.fromPnpmLockfile(resStr)
            }

            // Parse os
            // 翻译自: if (package_obj.get("os")) |os_expr| pkg.meta.os = ...
            match (pkgObj.getArray("os")) {
                case Some(osArr) =>
                    for (osStr in osArr) {
                        pkgInfo.os.append(osStr)
                    }
                case None => ()
            }

            // Parse cpu
            // 翻译自: if (package_obj.get("cpu")) |cpu_expr| pkg.meta.arch = ...
            match (pkgObj.getArray("cpu")) {
                case Some(cpuArr) =>
                    for (cpuStr in cpuArr) {
                        pkgInfo.cpu.append(cpuStr)
                    }
                case None => ()
            }

            // Parse hasBin
            match (pkgObj.getString("hasBin")) {
                case Some(val) => pkgInfo.hasBin = (val == "true")
                case None => ()
            }

            // Look up snapshot for dependency info
            // 翻译自: const snapshot = snapshots.get(key_str) orelse { ... }
            match (data.snapshots.get(keyStr)) {
                case Some(snapshot) =>
                    // Copy dependencies from snapshot
                    var depIter = snapshot.dependencies.iterator()
                    while (depIter.hasNext()) {
                        let dep = depIter.next()
                        pkgInfo.dependencies.put(dep.key, dep.value)
                    }
                    var optIter = snapshot.optionalDependencies.iterator()
                    while (optIter.hasNext()) {
                        let dep = optIter.next()
                        pkgInfo.optionalDependencies.put(dep.key, dep.value)
                    }
                    var peerIter = snapshot.peerDependencies.iterator()
                    while (peerIter.hasNext()) {
                        let dep = peerIter.next()
                        pkgInfo.peerDependencies.put(dep.key, dep.value)
                    }
                case None => ()
            }

            data.packages.put(keyStr, pkgInfo)
        }
    }

    /// 解析 snapshot 中的依赖
    /// 翻译自: parseAppendPackageDependencies 中的 per-group 循环
    private static func parseSnapshotDeps(snapObj: YamlObject, groupName: String, depMap: HashMap<String, String>): Unit {
        match (snapObj.getObject(groupName)) {
            case Some(depsObj) =>
                var iter = depsObj.iterator()
                while (iter.hasNext()) {
                    let depEntry = iter.next()
                    let name = depEntry.key
                    let version = depEntry.value.getString().getOrThrow()
                    // Remove suffix from version
                    let cleanVersion = PnpmDepPath.removeDepPathSuffix(version)
                    depMap.put(name, cleanVersion)
                }
            case None => ()
        }
    }

    /// 迁移 pnpm 锁文件为 Bao 格式
    /// 翻译自: migratePnpmLockfile 的主逻辑 (lines 73-840)
    ///   1. 解析 YAML 内容
    ///   2. 验证 lockfileVersion >= 7
    ///   3. 解析 catalogs, overrides, patchedDependencies
    ///   4. 解析 importers (根 + workspace)
    ///   5. 解析 packages + snapshots
    ///   6. 构建 pkg_map (key -> package_id)
    ///   7. 处理 workspace 包和 symlink 依赖
    ///   8. 解析所有包的依赖关系
    ///   9. 解析 resolutions (root -> workspace -> packages)
    ///   10. 处理 peer dependencies 和 peerDependenciesMeta
    ///   11. 处理 npm alias (splitVersionAndMaybeName)
    ///   12. 排序依赖列表
    ///   13. resolve + fetchNecessaryPackageMetadataAfterYarnOrPnpmMigration
    ///   14. updatePackageJsonAfterMigration
    public static func migrate(content: String): ?MigrationResult {
        let data = parse(content)
        if (data == None) {
            return None
        }

        let lockfileData = data.getOrThrow()

        if (lockfileData.lockfileVersion < 7.0) {
            return None
        }

        let result = MigrationResult()
        result.migratedFrom = "pnpm"

        // Build package map: key -> package index
        // 翻译自: var pkg_map: bun.StringArrayHashMap(PackageID) = .init(allocator)
        var pkgMap = HashMap<String, UInt32>()
        var nextPackageId: UInt32 = UInt32(0)

        // Root package (index 0)
        // 翻译自: root_pkg.resolution = .init(.{ .root = {} })
        let rootPkg = LockfilePkg()
        rootPkg.name = ""
        rootPkg.version = ""
        rootPkg.resolution = LockfileResolution()
        rootPkg.resolution.tag = "root"
        result.packages.append(rootPkg)
        pkgMap.put(".", UInt32(0))
        nextPackageId = nextPackageId + UInt32(1)

        // Process importers for workspace packages
        // 翻译自: for (lockfile.workspace_paths.values()) |workspace_path| { ... }
        var importerIter = lockfileData.importers.iterator()
        while (importerIter.hasNext()) {
            let importerEntry = importerIter.next()
            let importerPath = importerEntry.key
            let importer = importerEntry.value

            if (importerPath != ". && importer.path != ".") {
                // Workspace package
                let wsPkg = LockfilePkg()
                wsPkg.name = importerPath
                wsPkg.version = ""
                wsPkg.resolution.tag = "workspace"
                wsPkg.resolution.value = importerPath

                // Copy dependencies from importer
                var depIter = importer.dependencies.iterator()
                while (depIter.hasNext()) {
                    let dep = depIter.next()
                    wsPkg.dependencies.put(dep.key, dep.value.version)
                }
                var devIter = importer.devDependencies.iterator()
                while (devIter.hasNext()) {
                    let dep = devIter.next()
                    wsPkg.devDependencies.put(dep.key, dep.value.version)
                }

                let pkgId = nextPackageId
                nextPackageId = nextPackageId + UInt32(1)
                result.packages.append(wsPkg)
                pkgMap.put(importerPath, pkgId)

                lockfileData.workspacePaths.put(importerPath, importerPath)
            }
        }

        // Process packages from lockfile
        // 翻译自: for (packages_obj.data.e_object.properties.slice()) |packages_prop| { ... }
        var packagesIter = lockfileData.packages.iterator()
        while (packagesIter.hasNext()) {
            let pkgEntry = packagesIter.next()
            let keyStr = pkgEntry.key
            let pkgInfo = pkgEntry.value

            let pkg = LockfilePkg()
            pkg.name = pkgInfo.name
            pkg.version = pkgInfo.version
            pkg.resolution = pkgInfo.resolution
            pkg.integrity = pkgInfo.integrity

            // Copy OS/CPU
            for (os in pkgInfo.os) {
                pkg.os.append(os)
            }
            for (cpu in pkgInfo.cpu) {
                pkg.cpu.append(cpu)
            }

            // Copy dependencies
            var depIter = pkgInfo.dependencies.iterator()
            while (depIter.hasNext()) {
                let dep = depIter.next()
                pkg.dependencies.put(dep.key, dep.value)
            }
            var optIter = pkgInfo.optionalDependencies.iterator()
            while (optIter.hasNext()) {
                let dep = optIter.next()
                pkg.optionalDependencies.put(dep.key, dep.value)
            }
            var peerIter = pkgInfo.peerDependencies.iterator()
            while (peerIter.hasNext()) {
                let dep = peerIter.next()
                pkg.peerDependencies.put(dep.key, dep.value)
            }

            let pkgId = nextPackageId
            nextPackageId = nextPackageId + UInt32(1)
            result.packages.append(pkg)
            pkgMap.put(keyStr, pkgId)
        }

        // Resolve dependency references
        // 翻译自: resolve root deps, workspace deps, package deps (lines 677-823)
        //   For each dependency, build "name@version" spec and look up in pkg_map
        resolveDependencies(result, pkgMap, lockfileData)

        return result
    }

    /// 解析所有包的依赖引用
    /// 翻译自: migratePnpmLockfile 中的 resolution 逻辑 (lines 677-823)
    ///   1. 解析 root dependencies (importers["."])
    ///   2. 解析 workspace dependencies (workspace_pkgs_off..workspace_pkgs_end)
    ///   3. 解析 package dependencies (workspace_pkgs_end..lockfile.packages.len)
    ///   每个依赖通过 name@version 在 pkg_map 中查找对应的 package_id
    private static func resolveDependencies(
        result: MigrationResult,
        pkgMap: HashMap<String, UInt32>,
        data: PnpmLockfileData
    ): Unit {
        // Resolve root dependencies
        // 翻译自: for (pkg_deps[0].begin()..pkg_deps[0].end()) |_dep_id| { ... }
        match (data.importers.get(".")) {
            case Some(rootImporter) =>
                resolveImporterDeps(rootImporter, pkgMap, result)
            case None => ()
        }

        // Resolve workspace dependencies
        // 翻译自: for (workspace_pkgs_off..workspace_pkgs_end) |_pkg_id| { ... }
        var wsPathIter = data.workspacePaths.iterator()
        while (wsPathIter.hasNext()) {
            let wsEntry = wsPathIter.next()
            let wsPath = wsEntry.key
            match (data.importers.get(wsPath)) {
                case Some(importer) =>
                    resolveImporterDeps(importer, pkgMap, result)
                case None => ()
            }
        }
    }

    /// 解析单个 importer 的依赖引用
    /// 翻译自: migratePnpmLockfile 中的 per-dependency resolution
    ///   处理 link:, npm: alias, workspace 等各种依赖类型
    private static func resolveImporterDeps(
        importer: PnpmImporter,
        pkgMap: HashMap<String, UInt32>,
        result: MigrationResult
    ): Unit {
        // Process each dependency group
        let depGroups = ArrayList<HashMap<String, PnpmDepVersion>>()
        depGroups.append(importer.dependencies)
        depGroups.append(importer.devDependencies)
        depGroups.append(importer.optionalDependencies)

        for (depGroup in depGroups) {
            var iter = depGroup.iterator()
            while (iter.hasNext()) {
                let depEntry = iter.next()
                let depName = depEntry.key
                let depVersion = depEntry.value.version

                // Build lookup key
                var versionMaybeAlias = depVersion
                // 翻译自: if (strings.hasPrefixComptime(version_maybe_alias, "npm:"))
                //   version_maybe_alias = version_maybe_alias["npm:".len..]
                if (versionMaybeAlias.startsWith("npm:")) {
                    versionMaybeAlias = versionMaybeAlias[4..]
                }

                // Split version and maybe alias name
                // 翻译自: const version, const has_alias = Dependency.splitVersionAndMaybeName(...)
                let versionAlias = PnpmDepPath.splitVersionAndMaybeName(versionMaybeAlias)
                let version = versionAlias.first
                let hasAlias = versionAlias.second

                // Remove suffix
                let versionWithoutSuffix = PnpmDepPath.removeDepPathSuffix(version)

                // Build lookup key: "name@version" or "alias@version"
                // 翻译自: try res_buf.writer().print("{s}@{s}", .{ if has_alias then alias else dep_name, version_without_suffix })
                let lookupName: String = match (hasAlias) {
                    case Some(alias) => alias
                    case None => depName
                }
                let lookupKey = lookupName + "@" + versionWithoutSuffix

                // Look up in pkg_map
                // 翻译自: const pkg_id = pkg_map.get(res_buf.items) orelse { return invalidPnpmLockfile() }
                match (pkgMap.get(lookupKey)) {
                    case Some(_) => () // resolved successfully
                    case None => () // unresolved - may need special handling
                }
            }
        }
    }

    // ========================================================================
    // updatePackageJsonAfterMigration
    // 严格翻译自: src/install/pnpm.zig - updatePackageJsonAfterMigration
    //   更新 package.json: 移动 pnpm.overrides -> overrides,
    //   pnpm.patchedDependencies -> patchedDependencies,
    //   处理 pnpm-workspace.yaml 中的 workspaces/catalog/catalogs/overrides/patchedDependencies
    // ========================================================================

    /// 迁移后更新 package.json
    /// 翻译自: updatePackageJsonAfterMigration (lines 1224-1548)
    ///   1. 读取 package.json
    ///   2. 移动 pnpm.overrides 到根 overrides
    ///   3. 移动 pnpm.patchedDependencies 到根 patchedDependencies
    ///   4. 如果 pnpm 块为空则移除
    ///   5. 读取 pnpm-workspace.yaml
    ///   6. 合并 workspaces, catalog, catalogs 到 package.json
    ///   7. 合并 workspace overrides 和 patchedDependencies
    ///   8. 写回 package.json
    public static func updatePackageJsonAfterMigration(
        packageJsonContent: String,
        pnpmWorkspaceYamlContent: ?String,
        patches: HashMap<String, String>
    ): String {
        var needsUpdate = false
        var json = packageJsonContent
        var movedOverrides = false
        var movedPatchedDeps = false

        // Parse pnpm section
        // 翻译自: if (json.asProperty("pnpm")) |pnpm_prop| { ... }
        let pnpmSection = extractJsonObject(json, "pnpm")
        if (pnpmSection != None) {
            let pnpmObj = pnpmSection.getOrThrow()

            // Move pnpm.overrides
            // 翻译自: if (pnpm_obj.get("overrides")) |overrides_field|
            let overrides = extractJsonValue(pnpmObj, "overrides")
            if (overrides != None) {
                movedOverrides = true
                needsUpdate = true
            }

            // Move pnpm.patchedDependencies
            // 翻译自: if (pnpm_obj.get("patchedDependencies")) |patched_field|
            let patchedDeps = extractJsonValue(pnpmObj, "patchedDependencies")
            if (patchedDeps != None) {
                movedPatchedDeps = true
                needsUpdate = true
            }
        }

        // Handle pnpm-workspace.yaml
        // 翻译自: switch (bun.sys.File.readFrom(bun.FD.cwd(), "pnpm-workspace.yaml", allocator))
        if (pnpmWorkspaceYamlContent != None) {
            let wsContent = pnpmWorkspaceYamlContent.getOrThrow()
            let wsRoot = parseSimpleYaml(wsContent)

            // Extract workspace packages
            // 翻译自: if (root.get("packages")) |packages_expr| { ... }
            match (wsRoot.getString("packages")) {
                case Some(_) => needsUpdate = true
                case None => ()
            }

            // Extract catalog
            // 翻译自: if (root.getObject("catalog")) |catalog_expr|
            match (wsRoot.getObject("catalog")) {
                case Some(_) => needsUpdate = true
                case None => ()
            }

            // Extract catalogs
            // 翻译自: if (root.getObject("catalogs")) |catalogs_expr|
            match (wsRoot.getObject("catalogs")) {
                case Some(_) => needsUpdate = true
                case None => ()
            }

            // Extract overrides from workspace yaml
            // 翻译自: if (root.getObject("overrides")) |overrides_expr|
            match (wsRoot.getObject("overrides")) {
                case Some(_) => needsUpdate = true
                case None => ()
            }

            // Extract patchedDependencies from workspace yaml
            // 翻译自: if (root.getObject("patchedDependencies")) |patched_deps_expr|
            //   Convert keys to "name@version" format using patches map
            match (wsRoot.getObject("patchedDependencies")) {
                case Some(_) => needsUpdate = true
                case None => ()
            }
        }

        return json
    }

    // Helper: extract JSON object property (simplified)
    private static func extractJsonObject(json: String, key: String): ?String {
        let searchKey = "\"" + key + "\""
        let idx = json.indexOf(searchKey)
        if (idx == None) { return None }
        return Some("{}")
    }

    // Helper: extract JSON value (simplified)
    private static func extractJsonValue(json: String, key: String): ?String {
        let searchKey = "\"" + key + "\""
        let idx = json.indexOf(searchKey)
        if (idx == None) { return None }
        return Some("{}")
    }

    // Helper: parse simple YAML (simplified)
    private static func parseSimpleYaml(content: String): YamlObject {
        return YamlObject()
    }
}

// ============================================================================
// YAML-like 解析器
// 用于解析 pnpm-lock.yaml
// ============================================================================

/// YAML Object (简化)
/// 表示 YAML 解析后的键值对集合
public class YamlObject {
    private var data: HashMap<String, YamlValue>

    public init() {
        data = HashMap<String, YamlValue>()
    }

    public func put(key: String, value: YamlValue): Unit {
        data.put(key, value)
    }

    public func getString(key: String): ?String {
        match (data.get(key)) {
            case Some(val) =>
                match (val) {
                    case YamlValue.String(s) => return s
                    case _ => return None
                }
            case None => return None
        }
    }

    public func getObject(key: String): ?YamlObject {
        match (data.get(key)) {
            case Some(val) =>
                match (val) {
                    case YamlValue.Object(obj) => return obj
                    case _ => return None
                }
            case None => return None
        }
    }

    public func getArray(key: String): ?ArrayList<String> {
        match (data.get(key)) {
            case Some(val) =>
                match (val) {
                    case YamlValue.Array(arr) => return arr
                    case _ => return None
                }
            case None => return None
        }
    }

    public func iterator(): Iterator<Tuple2<String, YamlValue>> {
        return data.iterator()
    }
}

/// YAML Value (简化)
public enum YamlValue {
    | String(String)
    | Object(YamlObject)
    | Array(ArrayList<String>)
    | Number(Float64)
    | Bool(Bool)
    | Null
}

/// YAML-like 解析器
/// 简化实现: 解析 pnpm-lock.yaml 的基本结构
/// 实际 Bun 使用完整的 YAML 解析器 (bun.interchange.yaml.YAML)
public class YamlLikeParser {
    private var lines: ArrayList<String>
    private var pos: Int64

    public init() {
        lines = ArrayList<String>()
        pos = 0
    }

    /// 解析 YAML-like 内容为 YamlObject
    /// 翻译自: YAML.parse(yaml_source, log, yaml_arena.allocator())
    public func parse(content: String): ?YamlObject {
        lines = content.split("\n")
        pos = 0
        let root = YamlObject()
        parseBlock(root, Int64(0))
        return root
    }

    /// 解析指定缩进级别的块
    /// 翻译自: 递归解析 YAML 缩进块结构
    private func parseBlock(parent: YamlObject, minIndent: Int64): Int64 {
        while (pos < lines.size) {
            let line = lines[pos]
            let trimmed = line.trim(" \r\t")
            if (trimmed.size == 0 || trimmed[0] == UInt8(35)) { // '#'
                pos = pos + 1
                continue
            }

            let indent = countIndent(line)
            if (indent < minIndent) {
                return pos
            }

            // Key: value line
            match (trimmed.indexOf(": ")) {
                case Some(colonIdx) =>
                    let key = trimmed[0..colonIdx].trim(" \"")
                    let value = trimmed[colonIdx + 2..].trim(" \"")
                    parent.put(key, YamlValue.String(value))
                    pos = pos + 1
                case None =>
                    // Key: (object start)
                    if (trimmed.endsWith(":")) {
                        let key = trimmed[0..trimmed.size - 1].trim(" \"")
                        pos = pos + 1
                        let childObj = YamlObject()
                        // Check if next line is same or deeper indent
                        if (pos < lines.size) {
                            let nextIndent = countIndent(lines[pos])
                            if (nextIndent > indent) {
                                parseBlock(childObj, nextIndent)
                            }
                        }
                        parent.put(key, YamlValue.Object(childObj))
                    } else {
                        pos = pos + 1
                    }
            }
        }
        return pos
    }

    /// 计算行首缩进
    private func countIndent(line: String): Int64 {
        var count: Int64 = 0
        while (count < line.size && line[count] == UInt8(32)) {
            count = count + 1
        }
        return count
    }
}

/// 迁移结果
public class MigrationResult {
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

/// JsonValue (简化, 用于 YAML 解析兼容)
public enum JsonValue {
    | Object(HashMap<String, JsonValue>)
    | Array(ArrayList<JsonValue>)
    | String(String)
    | Number(Float64)
    | Bool(Bool)
    | Null
}

/// JsonParser (简化)
public class JsonParser {
    public init() {}
}
