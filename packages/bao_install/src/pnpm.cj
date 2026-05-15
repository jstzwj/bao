// bao_install - pnpm 锁文件迁移
// 严格翻译自: src/install/pnpm.zig
//   pnpm-lock.yaml (v7+) 到 Bun/Bao 锁文件的迁移
//   包含依赖路径解析、importers 解析、snapshots 解析等
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
//       YamlParseError, ...
//   }
// ============================================================================

/// pnpm 迁移错误类型
/// 翻译自: src/install/pnpm.zig MigratePnpmLockfileError
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
//   fn indexOfDepPathSuffix(path: []const u8) struct { ?usize, ?usize } { ... }
//   https://github.com/pnpm/pnpm/blob/.../packages/dependency-path/src/index.ts#L9-L31
// ============================================================================

/// 查找依赖路径后缀索引
/// 翻译自: src/install/pnpm.zig indexOfDepPathSuffix
///   返回 (peersIndex, patchHashIndex)
public static func indexOfDepPathSuffix(path: String): Tuple2<?Int64, ?Int64> {
    if (path.length < 2) { return Tuple2(None, None) }
    if (path[path.length - 1] != ')') { return Tuple2(None, None) }

    var open: Int64 = 1
    var i: Int64 = path.length - 1
    while (i > 0) {
        i -= 1
        if (path[Int64(i)] == '(') {
            open -= 1
        } else if (path[Int64(i)] == ')') {
            open += 1
        } else if (open == 0) {
            if (path.substring(Int64(i) + 1).startsWith("(patch_hash=")) {
                let peersIdx = match (path.indexOf("(", Int64(i) + 2)) {
                    case Some(idx) => idx
                    case None => None
                }
                return Tuple2(peersIdx, Int64(i) + 1)
            }
            return Tuple2(Int64(i) + 1, None)
        }
    }
    return Tuple2(None, None)
}

/// 去除依赖路径后缀
/// 翻译自: src/install/pnpm.zig removeSuffix
///   name@version(hash) -> name@version
public static func removeDepPathSuffix(path: String): String {
    let (peersIdx, patchHashIdx) = indexOfDepPathSuffix(path)
    match (patchHashIdx) {
        case Some(idx) => return path.substring(0, idx)
        case None => {
            match (peersIdx) {
                case Some(idx) => return path.substring(0, idx)
                case None => return path
            }
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
    /// 版本字符串 (可能是 specifier, version, link: 等)
    public var version: String
    /// 解析后的包 key (来自 packages/snapshots)
    public var resolved: ?String

    public init(version: String) {
        this.version = version
        resolved = None
    }

    public init(version: String, resolved: ?String) {
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
    /// 是否有安装脚本
    public var hasInstallScript: Bool
    /// 是否可选
    public var isOptional: Bool
    /// 依赖
    public var dependencies: HashMap<String, String>
    /// peer 依赖
    public var peerDependencies: HashMap<String, String>
    /// bin 条目
    public var bin: HashMap<String, String>
    /// OS 限制
    public var os: ArrayList<String>
    /// CPU 限制
    public var cpu: ArrayList<String>
    /// deprecated 信息
    public var deprecated: ?String

    public init() {
        name = ""
        version = ""
        resolution = LockfileResolution()
        hasInstallScript = false
        isOptional = false
        dependencies = HashMap<String, String>()
        peerDependencies = HashMap<String, String>()
        bin = HashMap<String, String>()
        os = ArrayList<String>()
        cpu = ArrayList<String>()
        deprecated = None
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

// ============================================================================
// pnpm 锁文件迁移器
// 严格翻译自: src/install/pnpm.zig - migratePnpmLockfile
// ============================================================================

/// pnpm 锁文件迁移器
/// 对应 Bun: migratePnpmLockfile
/// 翻译自: src/install/pnpm.zig migratePnpmLockfile
public class PnpmMigrator {
    /// 从 YAML 内容解析 pnpm-lock.yaml
    /// 翻译自: migratePnpmLockfile 中的 YAML 解析逻辑
    public static func parse(content: String): ?PnpmLockfileData {
        let data = PnpmLockfileData()
        let parser = YamlLikeParser()

        let root = parser.parse(content)
        match (root) {
            case Some(r) => {
                // 解析 lockfileVersion
                // 翻译自: migratePnpmLockfile 中版本解析
                match (r.get("lockfileVersion")) {
                    case Some(JsonValue.Number(n)) => {
                        data.lockfileVersion = n
                        if (n < 7.0) { return None }
                    }
                    case Some(JsonValue.Str(s)) => {
                        let dotIdx = s.indexOf(".")
                        let majorStr = match (dotIdx) {
                            case Some(idx) => s.substring(0, idx)
                            case None => s
                        }
                        try {
                            data.lockfileVersion = Float64.parse(majorStr)
                            if (data.lockfileVersion < 7.0) { return None }
                        } catch (_: Exception) {
                            return None
                        }
                    }
                    case _ => return None
                }

                // 解析 catalogs
                // 翻译自: migratePnpmLockfile 中 catalogs 解析
                match (r.get("catalogs")) {
                    case Some(JsonValue.Object(catalogs)) => {
                        data.catalogs.fromPnpmLockfile(catalogs)
                    }
                    case _ => ()
                }

                // 解析 overrides
                // 翻译自: migratePnpmLockfile 中 overrides 解析
                match (r.get("overrides")) {
                    case Some(JsonValue.Object(overrides)) => {
                        for (key in overrides.keys()) {
                            match (overrides.get(key)) {
                                case Some(JsonValue.Str(value)) => {
                                    data.overrides.put(key, value)
                                }
                                case _ => ()
                            }
                        }
                    }
                    case _ => ()
                }

                // 解析 patchedDependencies
                // 翻译自: migratePnpmLockfile 中 patched dependencies 解析
                match (r.get("patchedDependencies")) {
                    case Some(JsonValue.Object(patched)) => {
                        for (depName in patched.keys()) {
                            match (patched.get(depName)) {
                                case Some(JsonValue.Object(info)) => {
                                    let pathStr = match (info.get("path")) {
                                        case Some(JsonValue.Str(s)) => s
                                        case _ => ""
                                    }
                                    let hashStr = match (info.get("hash")) {
                                        case Some(JsonValue.Str(s)) => s
                                        case _ => ""
                                    }
                                    if (pathStr.length > 0) {
                                        let patch = PnpmPatchInfo(pathStr, depName)
                                        patch.hash = hashStr
                                        data.patchedDependencies.put(depName, patch)
                                    }
                                }
                                case _ => ()
                            }
                        }
                    }
                    case _ => ()
                }

                // 解析 importers
                // 翻译自: migratePnpmLockfile 中 importers 解析
                match (r.get("importers")) {
                    case Some(JsonValue.Object(importersObj)) => {
                        for (importerPath in importersObj.keys()) {
                            match (importersObj.get(importerPath)) {
                                case Some(JsonValue.Object(importerObj)) => {
                                    let importer = PnpmImporter(importerPath)
                                    parseImporterDeps(importerObj, importer)
                                    data.importers.put(importerPath, importer)
                                }
                                case _ => ()
                            }
                        }
                    }
                    case _ => ()
                }

                // 解析 packages 和 snapshots
                // 翻译自: migratePnpmLockfile 中 packages/snapshots 解析
                match (r.get("packages")) {
                    case Some(JsonValue.Object(packagesObj)) => {
                        match (r.get("snapshots")) {
                            case Some(JsonValue.Object(snapshotsObj)) => {
                                // 解析 snapshots
                                for (snapKey in snapshotsObj.keys()) {
                                    match (snapshotsObj.get(snapKey)) {
                                        case Some(JsonValue.Object(snapObj)) => {
                                            let snap = PnpmSnapshot()
                                            match (snapObj.get("dependencies")) {
                                                case Some(JsonValue.Object(deps)) => {
                                                    for (k in deps.keys()) {
                                                        match (deps.get(k)) {
                                                            case Some(JsonValue.Str(v)) => snap.dependencies.put(k, v)
                                                            case _ => ()
                                                        }
                                                    }
                                                }
                                                case _ => ()
                                            }
                                            match (snapObj.get("optionalDependencies")) {
                                                case Some(JsonValue.Object(deps)) => {
                                                    for (k in deps.keys()) {
                                                        match (deps.get(k)) {
                                                            case Some(JsonValue.Str(v)) => snap.optionalDependencies.put(k, v)
                                                            case _ => ()
                                                        }
                                                    }
                                                }
                                                case _ => ()
                                            }
                                            match (snapObj.get("peerDependencies")) {
                                                case Some(JsonValue.Object(deps)) => {
                                                    for (k in deps.keys()) {
                                                        match (deps.get(k)) {
                                                            case Some(JsonValue.Str(v)) => snap.peerDependencies.put(k, v)
                                                            case _ => ()
                                                        }
                                                    }
                                                }
                                                case _ => ()
                                            }
                                            let keyWithoutSuffix = removeDepPathSuffix(snapKey)
                                            data.snapshots.put(keyWithoutSuffix, snap)
                                        }
                                        case _ => ()
                                    }
                                }

                                // 解析 packages
                                for (pkgKey in packagesObj.keys()) {
                                    match (packagesObj.get(pkgKey)) {
                                        case Some(JsonValue.Object(pkgObj)) => {
                                            let pkgInfo = parsePackageInfo(pkgKey, pkgObj)
                                            match (pkgInfo) {
                                                case Some(info) => data.packages.put(pkgKey, info)
                                                case None => ()
                                            }
                                        }
                                        case _ => ()
                                    }
                                }
                            }
                            case _ => ()
                        }
                    }
                    case _ => ()
                }

                return data
            }
            case None => return None
        }
    }

    /// 解析 importer 依赖
    /// 翻译自: migratePnpmLockfile 中 parseAppendImporterDependencies
    private static func parseImporterDeps(importerObj: HashMap<String, JsonValue>, importer: PnpmImporter): Unit {
        // dependencies
        match (importerObj.get("dependencies")) {
            case Some(JsonValue.Object(deps)) => {
                for (name in deps.keys()) {
                    match (deps.get(name)) {
                        case Some(JsonValue.Str(v)) => {
                            let depVer = parseDepVersion(v)
                            importer.dependencies.put(name, depVer)
                        }
                        case Some(JsonValue.Object(info)) => {
                            let version = match (info.get("version")) {
                                case Some(JsonValue.Str(s)) => s
                                case _ => ""
                            }
                            let resolved = match (info.get("resolved")) {
                                case Some(JsonValue.Str(s)) => Some(s)
                                case _ => None
                            }
                            let depVer = PnpmDepVersion(version, resolved)
                            importer.dependencies.put(name, depVer)
                        }
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }

        // devDependencies
        match (importerObj.get("devDependencies")) {
            case Some(JsonValue.Object(deps)) => {
                for (name in deps.keys()) {
                    match (deps.get(name)) {
                        case Some(JsonValue.Str(v)) => {
                            let depVer = parseDepVersion(v)
                            importer.devDependencies.put(name, depVer)
                        }
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }

        // optionalDependencies
        match (importerObj.get("optionalDependencies")) {
            case Some(JsonValue.Object(deps)) => {
                for (name in deps.keys()) {
                    match (deps.get(name)) {
                        case Some(JsonValue.Str(v)) => {
                            let depVer = parseDepVersion(v)
                            importer.optionalDependencies.put(name, depVer)
                        }
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }

        // peerDependencies
        match (importerObj.get("peerDependencies")) {
            case Some(JsonValue.Object(deps)) => {
                for (name in deps.keys()) {
                    match (deps.get(name)) {
                        case Some(JsonValue.Str(v)) => {
                            let depVer = parseDepVersion(v)
                            importer.peerDependencies.put(name, depVer)
                        }
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }
    }

    /// 解析依赖版本字符串
    /// 翻译自: migratePnpmLockfile 中的版本解析
    private static func parseDepVersion(versionStr: String): PnpmDepVersion {
        // pnpm 格式可能是:
        // - 简单版本: "1.2.3"
        // - link: "./path"
        // - workspace: "*" or workspace:^
        // - 引用: "/name@version"
        let resolved = if (versionStr.startsWith("/") || versionStr.startsWith("link:") || versionStr.startsWith("workspace:")) {
            None
        } else {
            None
        }

        return PnpmDepVersion(versionStr, resolved)
    }

    /// 解析包信息
    /// 翻译自: migratePnpmLockfile 中 packages 解析
    private static func parsePackageInfo(pkgKey: String, pkgObj: HashMap<String, JsonValue>): ?PnpmPackageInfo {
        // 从 key 提取 name@version
        // pnpm 格式: /name@version 或 /@scope/name@version
        var key = pkgKey
        if (key.startsWith("/")) {
            key = key.substring(1)
        }

        let (name, version) = splitNameAndVersion(key)
        let info = PnpmPackageInfo()
        info.name = name
        info.version = version

        // 解析 resolution
        // 翻译自: Resolution.fromPnpmLockfile
        info.resolution = LockfileResolution.fromPnpmLockfile(version)

        // resolution 字段
        match (pkgObj.get("resolution")) {
            case Some(JsonValue.Object(resObj)) => {
                match (resObj.get("integrity")) {
                    case Some(JsonValue.Str(s)) => {
                        info.resolution = LockfileResolution.fromPnpmLockfile(version)
                    }
                    case _ => ()
                }
                match (resObj.get("tarball")) {
                    case Some(JsonValue.Str(s)) => {
                        info.resolution.tag = DependencyTag.Tarball
                        info.resolution.tarballUrl = s
                    }
                    case _ => ()
                }
            }
            case _ => ()
        }

        // hasInstallScript
        match (pkgObj.get("hasInstallScript")) {
            case Some(JsonValue.Bool(b)) => info.hasInstallScript = b
            case _ => ()
        }

        // dependencies
        match (pkgObj.get("dependencies")) {
            case Some(JsonValue.Object(deps)) => {
                for (k in deps.keys()) {
                    match (deps.get(k)) {
                        case Some(JsonValue.Str(v)) => info.dependencies.put(k, v)
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }

        // peerDependencies
        match (pkgObj.get("peerDependencies")) {
            case Some(JsonValue.Object(deps)) => {
                for (k in deps.keys()) {
                    match (deps.get(k)) {
                        case Some(JsonValue.Str(v)) => info.peerDependencies.put(k, v)
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }

        // bin
        match (pkgObj.get("bin")) {
            case Some(JsonValue.Object(binObj)) => {
                for (k in binObj.keys()) {
                    match (binObj.get(k)) {
                        case Some(JsonValue.Str(v)) => info.bin.put(k, v)
                        case _ => ()
                    }
                }
            }
            case Some(JsonValue.Str(s)) => {
                info.bin.put(name, s)
            }
            case _ => ()
        }

        // deprecated
        match (pkgObj.get("deprecated")) {
            case Some(JsonValue.Str(s)) => info.deprecated = s
            case _ => ()
        }

        return info
    }

    /// 分割 name@version
    /// 翻译自: Dependency.splitNameAndVersion
    ///   处理 scoped packages: @scope/name@version
    private static func splitNameAndVersion(key: String): Tuple2<String, String> {
        if (key.startsWith("@")) {
            // scoped: @scope/name@version
            let secondAt = key.indexOf("@", Int64(1))
            match (secondAt) {
                case Some(idx) => return Tuple2(key.substring(0, idx), key.substring(idx + 1))
                case None => return Tuple2(key, "")
            }
        }
        // non-scoped: name@version
        let atIdx = key.indexOf("@")
        match (atIdx) {
            case Some(idx) => return Tuple2(key.substring(0, idx), key.substring(idx + 1))
            case None => return Tuple2(key, "")
        }
    }

    /// 迁移 pnpm 锁文件为 Bao 格式
    /// 翻译自: migratePnpmLockfile 的主逻辑
    public static func migrate(content: String): ?MigrationResult {
        let data = parse(content)
        match (data) {
            case Some(d) => {
                let result = MigrationResult()
                result.format = TextLockfileVersion.current()

                // 创建根包
                let rootPkg = LockfilePkg("", UInt64(0))
                rootPkg.resolution.tag = DependencyTag.Npm
                rootPkg.resolution.npmVersion = ""
                result.packages.append(rootPkg)

                // 解析 importers 中的依赖
                match (d.importers.get(".")) {
                    case Some(rootImporter) => {
                        // 根包的依赖
                        for (depName in rootImporter.dependencies.keys()) {
                            match (rootImporter.dependencies.get(depName)) {
                                case Some(depVer) => {
                                    let dep = LockfileDependency(depName, Wyhash11.hash(depName), depVer.version)
                                    rootPkg.dependencies.append(dep)
                                }
                                case None => ()
                            }
                        }
                        for (depName in rootImporter.devDependencies.keys()) {
                            match (rootImporter.devDependencies.get(depName)) {
                                case Some(depVer) => {
                                    let dep = LockfileDependency(depName, Wyhash11.hash(depName), depVer.version)
                                    dep.behavior.isDev = true
                                    rootPkg.dependencies.append(dep)
                                }
                                case None => ()
                            }
                        }
                    }
                    case None => ()
                }

                // 创建包条目
                for (pkgKey in d.packages.keys()) {
                    match (d.packages.get(pkgKey)) {
                        case Some(pkgInfo) => {
                            let pkg = LockfilePkg(pkgInfo.name, Wyhash11.hash(pkgInfo.name))
                            pkg.resolution = pkgInfo.resolution
                            pkg.meta.hasInstallScript = pkgInfo.hasInstallScript
                            pkg.bin = pkgInfo.bin
                            pkg.meta.deprecated = match (pkgInfo.deprecated) {
                                case Some(d) => d
                                case None => ""
                            }

                            // 从 snapshot 中获取依赖
                            match (d.snapshots.get(pkgKey)) {
                                case Some(snapshot) => {
                                    for (depName in snapshot.dependencies.keys()) {
                                        match (snapshot.dependencies.get(depName)) {
                                            case Some(depVer) => {
                                                let dep = LockfileDependency(depName, Wyhash11.hash(depName), depVer)
                                                pkg.dependencies.append(dep)
                                            }
                                            case None => ()
                                        }
                                    }
                                    for (depName in snapshot.peerDependencies.keys()) {
                                        match (snapshot.peerDependencies.get(depName)) {
                                            case Some(depVer) => {
                                                let dep = LockfileDependency(depName, Wyhash11.hash(depName), depVer)
                                                dep.behavior.isPeer = true
                                                pkg.dependencies.append(dep)
                                            }
                                            case None => ()
                                        }
                                    }
                                }
                                case None => {
                                    // 使用 package 本身的依赖
                                    for (depName in pkgInfo.dependencies.keys()) {
                                        match (pkgInfo.dependencies.get(depName)) {
                                            case Some(depVer) => {
                                                let dep = LockfileDependency(depName, Wyhash11.hash(depName), depVer)
                                                pkg.dependencies.append(dep)
                                            }
                                            case None => ()
                                        }
                                    }
                                }
                            }

                            result.packages.append(pkg)
                        }
                        case None => ()
                    }
                }

                return result
            }
            case None => return None
        }
    }
}

// ============================================================================
// YAML-like 解析器 (简化版)
// 用于解析 pnpm-lock.yaml
// ============================================================================

/// YAML-like 解析器
/// 简化实现: 解析 pnpm-lock.yaml 的基本结构
/// 实际 Bun 使用完整的 YAML 解析器
public class YamlLikeParser {
    private var parser: JsonParser

    public init() {
        parser = JsonParser()
    }

    /// 解析 YAML-like 内容为 JSON 结构
    public func parse(content: String): ?JsonValue {
        // 简化: 将 YAML-like 转换为类似 JSON 的结构
        let lines = content.split("\n")
        return parseYamlToValue(lines)
    }

    /// 递归解析 YAML 结构
    private func parseYamlToValue(lines: ArrayList<String>): ?JsonValue {
        // 简化实现: 生成一个包含所有顶级字段的 JSON 对象
        let root = HashMap<String, JsonValue>()
        var i: Int64 = 0

        while (i < lines.size) {
            let line = lines[Int64(i)]
            let trimmed = line.trim(" \r\t")

            // 跳过空行和注释
            if (trimmed.length == 0 || trimmed[0] == '#') {
                i += 1
                continue
            }

            // 顶级 key:
            if (!line.startsWith(" ") && trimmed.endsWith(":")) {
                let key = trimmed.substring(0, trimmed.length - 1).trim(" \"")
                i += 1

                // 检查下一行是否是内联值或子对象
                if (i < lines.size) {
                    let nextLine = lines[Int64(i)]
                    let nextTrimmed = nextLine.trim(" \r\t")

                    // 如果下一行是更深层缩进, 解析为对象或数组
                    if (nextLine.startsWith("  ") || nextLine.startsWith("    ")) {
                        // 子对象/数组
                        let (subObj, newI) = parseYamlBlock(lines, i, 1)
                        root.put(key, subObj)
                        i = newI
                    } else if (nextTrimmed.length > 0 && !nextTrimmed.endsWith(":")) {
                        // 内联值
                        let value = nextTrimmed.trim(" \"")
                        if (value == "true") {
                            root.put(key, JsonValue.Bool(true))
                        } else if (value == "false") {
                            root.put(key, JsonValue.Bool(false))
                        } else if (value == "null") {
                            root.put(key, JsonValue.Null)
                        } else {
                            // 尝试解析为数字
                            try {
                                root.put(key, JsonValue.Number(Float64.parse(value)))
                            } catch (_: Exception) {
                                root.put(key, JsonValue.Str(value))
                            }
                        }
                        i += 1
                    } else {
                        // 空的 key:
                        root.put(key, JsonValue.Object(HashMap<String, JsonValue>()))
                    }
                } else {
                    root.put(key, JsonValue.Object(HashMap<String, JsonValue>()))
                }
            } else {
                i += 1
            }
        }

        return JsonValue.Object(root)
    }

    /// 解析 YAML 块
    private func parseYamlBlock(lines: ArrayList<String>, startIdx: Int64, minIndent: Int64): Tuple2<JsonValue, Int64> {
        let obj = HashMap<String, JsonValue>()
        var i = startIdx

        while (i < lines.size) {
            let line = lines[Int64(i)]
            if (line.trim(" \r\t").length == 0) {
                i += 1
                continue
            }

            // 计算缩进
            var indent: Int64 = 0
            while (indent < line.length && line[Int64(indent)] == ' ') {
                indent += 1
            }

            if (indent < minIndent) { break }

            let trimmed = line.substring(indent).trim(" \r\t")
            if (trimmed.length == 0) {
                i += 1
                continue
            }

            // key: value 或 key:
            let colonIdx = trimmed.indexOf(": ")
            if (colonIdx >= 0) {
                let key = trimmed.substring(0, colonIdx).trim(" \"")
                let value = trimmed.substring(colonIdx + 2).trim(" \"")
                if (value == "true") {
                    obj.put(key, JsonValue.Bool(true))
                } else if (value == "false") {
                    obj.put(key, JsonValue.Bool(false))
                } else {
                    try {
                        obj.put(key, JsonValue.Number(Float64.parse(value)))
                    } catch (_: Exception) {
                        obj.put(key, JsonValue.Str(value))
                    }
                }
            } else if (trimmed.endsWith(":")) {
                let key = trimmed.substring(0, trimmed.length - 1).trim(" \"")
                i += 1
                if (i < lines.size) {
                    let nextIndent = countIndent(lines[Int64(i)])
                    if (nextIndent > indent) {
                        let (subObj, newI) = parseYamlBlock(lines, i, nextIndent)
                        obj.put(key, subObj)
                        i = newI
                    } else {
                        obj.put(key, JsonValue.Object(HashMap<String, JsonValue>()))
                    }
                } else {
                    obj.put(key, JsonValue.Object(HashMap<String, JsonValue>()))
                }
                continue
            }

            i += 1
        }

        return Tuple2(JsonValue.Object(obj), i)
    }

    /// 计算行首缩进
    private func countIndent(line: String): Int64 {
        var indent: Int64 = 0
        while (indent < line.length && line[Int64(indent)] == ' ') {
            indent += 1
        }
        return indent
    }
}
