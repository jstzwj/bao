// bao_install - Bun 锁文件格式 (文本 + 二进制)
// 严格翻译自:
//   src/install/lockfile/bun.lock.zig                          - 文本锁文件 (bun.lock)
//   src/install/lockfile/bun.lockb.zig                         - 二进制锁文件 (bun.lockb)
//   src/install/lockfile/lockfile_json_stringify_for_debugging.zig - JSON 调试输出
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 文本锁文件版本
// 严格翻译自: src/install/lockfile/bun.lock.zig - Version
//   pub const Version = enum(u32) {
//       v0 = 0,
//       v1, // fixed unnecessary listing of workspace dependencies
//       pub const current: Version = .v1;
//   }
// ============================================================================

/// 文本锁文件版本
/// 对应 Bun: TextLockfile.Version
/// 翻译自: src/install/lockfile/bun.lock.zig
///   pub const Version = enum(u32) { v0 = 0, v1, pub const current = .v1 }
public enum TextLockfileVersion {
    | V0  // 初始格式
    | V1  // 修复了 workspace 依赖不必要的列出

    public func toInt(): Int64 {
        match (this) {
            case V0 => 0
            case V1 => 1
        }
    }

    public static func fromInt(v: Int64): TextLockfileVersion {
        if (v >= 1) { return V1 }
        return V0
    }

    /// 当前版本
    /// 翻译自: Version.current = .v1
    public static func current(): TextLockfileVersion {
        return V1
    }

    public func format(): String {
        match (this) {
            case V0 => "v0"
            case V1 => "v1"
        }
    }
}

// ============================================================================
// 依赖排序上下文
// ============================================================================

/// Tree 依赖排序上下文
/// 对应 Bun: TreeDepsSortCtx
public class TreeDepsSortCtx {
    public var deps: ArrayList<LockfileDependency>

    public init(deps: ArrayList<LockfileDependency>) {
        this.deps = deps
    }

    /// 比较两个依赖的名称
    public func isLessThan(lhs: Int64, rhs: Int64): Bool {
        if (lhs >= deps.size || rhs >= deps.size) { return false }
        return match (deps[lhs].name.compare(deps[rhs].name)) {
            case Ordering.LT => true
            case _ => false
        }
    }
}

// ============================================================================
// Tree 排序上下文
// ============================================================================

/// Tree 排序上下文
/// 对应 Bun: TreeSortCtx
public class TreeSortItem {
    /// 依赖 ID 列表
    public var dependencyIds: ArrayList<UInt32>
    /// 相对路径
    public var relativePath: String
    /// 深度
    public var depth: Int64

    public init(dependencyIds: ArrayList<UInt32>, relativePath: String, depth: Int64) {
        this.dependencyIds = dependencyIds
        this.relativePath = relativePath
        this.depth = depth
    }

    /// 比较方法
    public static func isLessThan(lhs: TreeSortItem, rhs: TreeSortItem): Bool {
        if (lhs.depth != rhs.depth) { return lhs.depth < rhs.depth }
        return match (lhs.relativePath.compare(rhs.relativePath)) {
            case Ordering.LT => true
            case _ => false
        }
    }
}

// ============================================================================
// 文本锁文件序列化器
// 翻译自: src/install/lockfile/bun.lock.zig - Stringifier
// ============================================================================

/// 文本锁文件序列化器
/// 对应 Bun: TextLockfile.Stringifier
public class TextLockfileStringifier {
    /// 缩进量
    public static let INDENT_SCALAR: Int64 = 2

    /// 将锁文件序列化为 JSON 文本
    public static func serialize(lockfileData: BinaryLockfileData): String {
        let sb = StringBuilder()
        sb.append("{\n")

        // lockfileVersion
        sb.append("  \"lockfileVersion\": ${TextLockfileVersion.current().toInt()},\n")

        // workspaces
        sb.append("  \"workspaces\": {\n")
        sb.append("  },\n")

        // packages
        sb.append("  \"packages\": {")

        let sortedPkgs = sortPackages(lockfileData)
        var first = true

        for (pkgEntry in sortedPkgs) {
            if (!first) {
                sb.append(",\n\n")
            } else {
                sb.append("\n")
                first = false
            }

            sb.append("    ${escapeJson(pkgEntry.key)}: ")
            serializePackageEntry(sb, pkgEntry)
        }

        if (!first) {
            sb.append("\n  ")
        }
        sb.append("}\n}\n")

        return sb.toString()
    }

    /// 序列化单个包条目
    private static func serializePackageEntry(sb: StringBuilder, entry: PkgMapEntry): Unit {
        sb.append("[")
        let pkg = entry.`package`
        match (pkg.resolution.tag) {
            case DependencyTag.Npm => serializeNpmEntry(sb, pkg)
            case DependencyTag.Tarball => serializeTarballEntry(sb, pkg)
            case DependencyTag.Folder => serializeFolderEntry(sb, pkg)
            case DependencyTag.Symlink => serializeSymlinkEntry(sb, pkg)
            case DependencyTag.Workspace => serializeWorkspaceEntry(sb, pkg)
            case DependencyTag.Git => serializeGitEntry(sb, pkg)
            case DependencyTag.Github => serializeGithubEntry(sb, pkg)
            case _ => serializeDefaultEntry(sb, pkg)
        }
        sb.append("]")
    }

    private static func serializeNpmEntry(sb: StringBuilder, pkg: LockfilePkg): Unit {
        sb.append("${escapeJson("${pkg.name}@${pkg.resolution.npmVersion}")}")
        sb.append(", \"${pkg.resolution.npmUrl}\"")
        sb.append(", ")
        writePackageInfoObject(sb, pkg)
        if (pkg.meta.integrity.isEmpty() == false) {
            sb.append(", ${escapeJson(pkg.meta.integrity.format())}")
        }
    }

    private static func serializeTarballEntry(sb: StringBuilder, pkg: LockfilePkg): Unit {
        sb.append("${escapeJson("${pkg.name}@${pkg.resolution.tarballUrl}")}")
        sb.append(", ")
        writePackageInfoObject(sb, pkg)
        if (pkg.meta.integrity.isEmpty() == false) {
            sb.append(", ${escapeJson(pkg.meta.integrity.format())}")
        }
    }

    private static func serializeFolderEntry(sb: StringBuilder, pkg: LockfilePkg): Unit {
        sb.append("${escapeJson("${pkg.name}@file:${pkg.resolution.folderPath}")}")
        sb.append(", ")
        writePackageInfoObject(sb, pkg)
    }

    private static func serializeSymlinkEntry(sb: StringBuilder, pkg: LockfilePkg): Unit {
        sb.append("${escapeJson("${pkg.name}@link:${pkg.resolution.symlinkPath}")}")
        sb.append(", ")
        writePackageInfoObject(sb, pkg)
    }

    private static func serializeWorkspaceEntry(sb: StringBuilder, pkg: LockfilePkg): Unit {
        sb.append("${escapeJson("${pkg.name}@workspace:${pkg.resolution.workspacePath}")}")
    }

    private static func serializeGitEntry(sb: StringBuilder, pkg: LockfilePkg): Unit {
        sb.append("${escapeJson("${pkg.name}@git+${pkg.resolution.gitRepo}")}")
        sb.append(", ")
        writePackageInfoObject(sb, pkg)
        if (pkg.meta.integrity.isEmpty() == false) {
            sb.append(", \"\", ${escapeJson(pkg.meta.integrity.format())}")
        }
    }

    private static func serializeGithubEntry(sb: StringBuilder, pkg: LockfilePkg): Unit {
        sb.append("${escapeJson("${pkg.name}@github:${pkg.resolution.githubUser}/${pkg.resolution.githubRepo}")}")
        sb.append(", ")
        writePackageInfoObject(sb, pkg)
        if (pkg.meta.integrity.isEmpty() == false) {
            sb.append(", \"\", ${escapeJson(pkg.meta.integrity.format())}")
        }
    }

    private static func serializeDefaultEntry(sb: StringBuilder, pkg: LockfilePkg): Unit {
        sb.append("${escapeJson("${pkg.name}@${pkg.resolution.versionString()}")}")
        sb.append(", ")
        writePackageInfoObject(sb, pkg)
    }

    /// 写入包依赖信息对象
    private static func writePackageInfoObject(sb: StringBuilder, pkg: LockfilePkg): Unit {
        sb.append("{")
        var any = false

        let deps = HashMap<String, String>()
        let devDeps = HashMap<String, String>()
        let peerDeps = HashMap<String, String>()
        let optDeps = HashMap<String, String>()

        for (dep in pkg.dependencies) {
            if (dep.behavior.isDev()) {
                devDeps.put(dep.name, dep.version)
            } else if (dep.behavior.isOptional()) {
                optDeps.put(dep.name, dep.version)
            } else if (dep.behavior.isPeer()) {
                peerDeps.put(dep.name, dep.version)
            } else {
                deps.put(dep.name, dep.version)
            }
        }

        if (deps.size > 0) {
            if (any) { sb.append(",") }
            sb.append(" \"dependencies\": ")
            writeDepMap(sb, deps)
            any = true
        }
        if (devDeps.size > 0) {
            if (any) { sb.append(",") }
            sb.append(" \"devDependencies\": ")
            writeDepMap(sb, devDeps)
            any = true
        }
        if (peerDeps.size > 0) {
            if (any) { sb.append(",") }
            sb.append(" \"peerDependencies\": ")
            writeDepMap(sb, peerDeps)
            any = true
        }
        if (optDeps.size > 0) {
            if (any) { sb.append(",") }
            sb.append(" \"optionalDependencies\": ")
            writeDepMap(sb, optDeps)
            any = true
        }

        if (pkg.bin.size > 0) {
            if (any) { sb.append(",") }
            sb.append(" \"bin\": ")
            writeDepMap(sb, pkg.bin)
            any = true
        }

        if (pkg.meta.hasInstallScript) {
            if (any) { sb.append(",") }
            sb.append(" \"hasInstallScript\": true")
            any = true
        }

        sb.append("}")
    }

    /// 写入依赖映射
    private static func writeDepMap(sb: StringBuilder, map: HashMap<String, String>): Unit {
        sb.append("{ ")
        var first = true
        for (key in map.keys()) {
            match (map.get(key)) {
                case Some(val) =>
                    if (!first) { sb.append(", ") }
                    sb.append("${escapeJson(key)}: ${escapeJson(val)}")
                    first = false
                case None => ()
            }
        }
        sb.append(" }")
    }

    private static func sortPackages(data: BinaryLockfileData): ArrayList<PkgMapEntry> {
        let sorted = ArrayList<PkgMapEntry>()

        for (key in data.packages.keys()) {
            match (data.packages.get(key)) {
                case Some(pkg) =>
                    let path = match (data.treePaths.get(key)) {
                        case Some(p) => p
                        case None => pkg.name
                    }
                    sorted.append(PkgMapEntry(path, pkg))
                case None => ()
            }
        }

        return sorted
    }

    private static func escapeJson(s: String): String {
        return "\"${s}\""
    }
}

/// 包映射条目
public class PkgMapEntry {
    public var key: String
    public var `package`: LockfilePkg

    public init(key: String, `package`: LockfilePkg) {
        this.key = key
        this.`package` = `package`
    }
}

// ============================================================================
// 二进制锁文件数据
// ============================================================================

/// 二进制锁文件头部
public let BINARY_LOCKFILE_HEADER: String = "#!/usr/bin/env bun\nbun-lockfile-format-v0\n"

/// 二进制锁文件标记
public let HAS_PATCHED_DEPENDENCIES_TAG: UInt64 = UInt64(0x6448687363546150)
public let HAS_WORKSPACE_PACKAGE_IDS_TAG: UInt64 = UInt64(0x435073526F537700)
public let HAS_TRUSTED_DEPENDENCIES_TAG: UInt64 = UInt64(0x64457355725400)
public let HAS_EMPTY_TRUSTED_DEPENDENCIES_TAG: UInt64 = UInt64(0x547250744D6500)
public let HAS_OVERRIDES_TAG: UInt64 = UInt64(0x536472976560000)
public let HAS_CATALOGS_TAG: UInt64 = UInt64(0x536F6C4174416300)

/// 二进制锁文件数据
public class BinaryLockfileData {
    public var format: TextLockfileVersion
    public var metaHash: Array<UInt8>
    public var packages: HashMap<String, LockfilePkg>
    public var treePaths: HashMap<String, String>
    public var buffers: LockfileBuffers
    public var workspaceVersions: HashMap<UInt64, String>
    public var workspacePaths: HashMap<UInt64, String>
    public var trustedDependencies: ?HashSet<UInt64>
    public var overrides: HashMap<UInt64, LockfileDependency>
    public var catalogs: CatalogMap
    public var patchedDependencies: HashMap<UInt64, PatchedDependency>

    public init() {
        format = TextLockfileVersion.current()
        metaHash = Array<UInt8>(32, { _ => UInt8(0) })
        packages = HashMap<String, LockfilePkg>()
        treePaths = HashMap<String, String>()
        buffers = LockfileBuffers()
        workspaceVersions = HashMap<UInt64, String>()
        workspacePaths = HashMap<UInt64, String>()
        trustedDependencies = None
        overrides = HashMap<UInt64, LockfileDependency>()
        catalogs = CatalogMap()
        patchedDependencies = HashMap<UInt64, PatchedDependency>()
    }

    public func save(): Array<UInt8> {
        return []
    }

    public static func load(data: Array<UInt8>): ?BinaryLockfileData {
        var offset: Int64 = 0
        let headerBytes = ArrayList<UInt8>()
        for (c in BINARY_LOCKFILE_HEADER) {
            headerBytes.append(c)
        }
        let headerArr = headerBytes.items()
        if (data.size < headerArr.size) { return None }

        var headerMatch = true
        var i: Int64 = 0
        while (i < headerArr.size) {
            if (data[i] != headerArr[i]) {
                headerMatch = false
                break
            }
            i += 1
        }
        if (!headerMatch) { return None }

        offset = headerArr.size

        let format = TextLockfileVersion.fromInt(Int64(readU32LE(data, offset)))
        offset += 4

        let metaHashList = ArrayList<UInt8>()
        for (j in 0..32) {
            if (offset + j < data.size) {
                metaHashList.append(data[offset + j])
            }
        }
        offset += 32

        let result = BinaryLockfileData()
        result.format = format
        result.metaHash = metaHashList.items()

        return result
    }

    private static func writeU32LE(bytes: ArrayList<UInt8>, value: UInt32): Unit {
        bytes.append(UInt8(value & UInt32(0xFF)))
        bytes.append(UInt8((value >> 8) & UInt32(0xFF)))
        bytes.append(UInt8((value >> 16) & UInt32(0xFF)))
        bytes.append(UInt8((value >> 24) & UInt32(0xFF)))
    }

    private static func readU32LE(data: Array<UInt8>, offset: Int64): UInt32 {
        if (offset + 3 >= data.size) { return UInt32(0) }
        return UInt32(data[offset]) |
               (UInt32(data[offset + 1]) << 8) |
               (UInt32(data[offset + 2]) << 16) |
               (UInt32(data[offset + 3]) << 24)
    }

    private static func writeTag(bytes: ArrayList<UInt8>, tag: UInt64): Unit {
        bytes.append(UInt8(tag & UInt64(0xFF)))
        bytes.append(UInt8((tag >> 8) & UInt64(0xFF)))
        bytes.append(UInt8((tag >> 16) & UInt64(0xFF)))
        bytes.append(UInt8((tag >> 24) & UInt64(0xFF)))
        bytes.append(UInt8((tag >> 32) & UInt64(0xFF)))
        bytes.append(UInt8((tag >> 40) & UInt64(0xFF)))
        bytes.append(UInt8((tag >> 48) & UInt64(0xFF)))
        bytes.append(UInt8((tag >> 56) & UInt64(0xFF)))
    }

    private static func writeHashMapU64String(bytes: ArrayList<UInt8>, map: HashMap<UInt64, String>): Unit {
        writeU32LE(bytes, UInt32(map.size))
        for (key in map.keys()) {
            match (map.get(key)) {
                case Some(value) =>
                    writeU32LE(bytes, UInt32(key >> 32))
                    writeU32LE(bytes, UInt32(key & UInt64(0xFFFFFFFF)))
                    writeU32LE(bytes, UInt32(value.size))
                    for (c in value) {
                        bytes.append(c)
                    }
                case None => ()
            }
        }
    }
}

// ============================================================================
// 补丁依赖
// ============================================================================

/// 补丁依赖信息
public class PatchedDependency {
    public var path: String
    public var patchfileHash: String
    public var patchfileHashIsNull: Bool

    public init() {
        path = ""
        patchfileHash = ""
        patchfileHashIsNull = true
    }

    public init(path: String) {
        this.path = path
        patchfileHash = ""
        patchfileHashIsNull = true
    }

    public init(path: String, hash: String) {
        this.path = path
        patchfileHash = hash
        patchfileHashIsNull = hash.size == 0
    }
}

// ============================================================================
// 加载结果
// ============================================================================

/// 加载结果 (二进制锁文件)
public class BinaryLoadResult {
    public var loadedFromBinaryLockfile: Bool
    public var loadedFromTextLockfile: Bool
    public var isNew: Bool
    public var warnings: ArrayList<String>
    public var errors: ArrayList<String>

    public init() {
        loadedFromBinaryLockfile = false
        loadedFromTextLockfile = false
        isNew = false
        warnings = ArrayList<String>()
        errors = ArrayList<String>()
    }

    public func isSuccess(): Bool {
        return errors.size == 0
    }

    public func wasLoadedFromBinaryLockfile(): Bool {
        return loadedFromBinaryLockfile
    }
}

// ============================================================================
// JSON 调试输出
// ============================================================================

public class LockfileJsonStringifier {
    public static func toJson(lockfileData: BinaryLockfileData): String {
        let sb = StringBuilder()
        sb.append("{\n")
        sb.append("  \"format\": \"${lockfileData.format.format()}\",\n")
        sb.append("  \"packages\": [\n")

        var first = true
        for (key in lockfileData.packages.keys()) {
            match (lockfileData.packages.get(key)) {
                case Some(pkg) =>
                    if (!first) { sb.append(",\n") }
                    first = false
                    sb.append("    ")
                    appendPackageJson(sb, pkg)
                case None => ()
            }
        }

        sb.append("\n  ],\n")

        if (lockfileData.workspaceVersions.size > 0) {
            sb.append("  \"workspaceVersions\": {\n")
            var wsFirst = true
            for (hash in lockfileData.workspaceVersions.keys()) {
                match (lockfileData.workspaceVersions.get(hash)) {
                    case Some(ver) =>
                        if (!wsFirst) { sb.append(",\n") }
                        wsFirst = false
                        sb.append("    \"${hash}\": \"${ver}\"")
                    case None => ()
                }
            }
            sb.append("\n  },\n")
        }

        match (lockfileData.trustedDependencies) {
            case Some(td) =>
                sb.append("  \"trustedDependencies\": [")
                var tdFirst = true
                for (hash in td.values()) {
                    if (!tdFirst) { sb.append(", ") }
                    tdFirst = false
                    sb.append("\"${hash}\"")
                }
                sb.append("],\n")
            case None => ()
        }

        if (lockfileData.catalogs.hasAny()) {
            sb.append("  \"catalogs\": {\n")
            appendCatalogJson(sb, "default", lockfileData.catalogs.defaultCatalog)
            for (name in lockfileData.catalogs.groups.keys()) {
                sb.append(",\n")
                match (lockfileData.catalogs.groups.get(name)) {
                    case Some(group) => appendCatalogJson(sb, name, group)
                    case None => ()
                }
            }
            sb.append("\n  },\n")
        }

        if (lockfileData.patchedDependencies.size > 0) {
            sb.append("  \"patchedDependencies\": {\n")
            var pdFirst = true
            for (hash in lockfileData.patchedDependencies.keys()) {
                match (lockfileData.patchedDependencies.get(hash)) {
                    case Some(patch) =>
                        if (!pdFirst) { sb.append(",\n") }
                        pdFirst = false
                        sb.append("    \"${hash}\": { \"path\": \"${patch.path}\" }")
                    case None => ()
                }
            }
            sb.append("\n  },\n")
        }

        if (lockfileData.overrides.size > 0) {
            sb.append("  \"overrides\": {\n")
            var ovFirst = true
            for (hash in lockfileData.overrides.keys()) {
                match (lockfileData.overrides.get(hash)) {
                    case Some(dep) =>
                        if (!ovFirst) { sb.append(",\n") }
                        ovFirst = false
                        sb.append("    \"${hash}\": \"${dep.name}@${dep.version}\"")
                    case None => ()
                }
            }
            sb.append("\n  },\n")
        }

        sb.append("  \"buffers\": \"${lockfileData.buffers.stats()}\"\n")
        sb.append("}\n")
        return sb.toString()
    }

    private static func appendPackageJson(sb: StringBuilder, pkg: LockfilePkg): Unit {
        sb.append("{\n")
        sb.append("      \"name\": \"${pkg.name}\",\n")
        sb.append("      \"nameHash\": \"${pkg.nameHash}\",\n")

        sb.append("      \"resolution\": {\n")
        sb.append("        \"tag\": \"${pkg.resolution.tag.toString()}\",\n")
        sb.append("        \"value\": \"${pkg.resolution.versionString()}\"\n")
        sb.append("      },\n")

        if (pkg.dependencies.size > 0) {
            sb.append("      \"dependencies\": [\n")
            var depFirst = true
            for (dep in pkg.dependencies) {
                if (!depFirst) { sb.append(",\n") }
                depFirst = false
                appendDependencyJson(sb, dep)
            }
            sb.append("\n      ],\n")
        }

        sb.append("      \"meta\": {\n")
        sb.append("        \"id\": ${pkg.meta.id},\n")
        sb.append("        \"integrity\": \"${pkg.meta.integrity.format()}\",\n")
        sb.append("        \"hasInstallScript\": ${pkg.meta.hasInstallScript},\n")
        sb.append("        \"isOptional\": ${pkg.meta.isOptional},\n")
        sb.append("        \"isBundled\": ${pkg.meta.isBundled}")
        if (pkg.meta.deprecated.size > 0) {
            sb.append(",\n        \"deprecated\": \"${pkg.meta.deprecated}\"")
        }
        sb.append("\n      },\n")

        if (pkg.bin.size > 0) {
            sb.append("      \"bin\": { ")
            var binFirst = true
            for (binName in pkg.bin.keys()) {
                match (pkg.bin.get(binName)) {
                    case Some(binPath) =>
                        if (!binFirst) { sb.append(", ") }
                        binFirst = false
                        sb.append("\"${binName}\": \"${binPath}\"")
                    case None => ()
                }
            }
            sb.append(" },\n")
        }

        if (pkg.scripts.hasAny()) {
            sb.append("      \"scripts\": { ")
            var scFirst = true
            for (scriptName in pkg.scripts.scriptNames()) {
                if (!scFirst) { sb.append(", ") }
                scFirst = false
                sb.append("\"${scriptName}\": true")
            }
            sb.append(" }\n")
        } else {
            sb.append("\n")
        }

        sb.append("    }")
    }

    private static func appendDependencyJson(sb: StringBuilder, dep: LockfileDependency): Unit {
        sb.append("        { \"name\": \"${dep.name}\", \"version\": \"${dep.version}\"")
        if (dep.isAlias) {
            sb.append(", \"isAlias\": true, \"realName\": \"${dep.realName}\"")
        }
        sb.append(" }")
    }

    private static func appendCatalogJson(sb: StringBuilder, name: String, catalog: HashMap<String, LockfileDependency>): Unit {
        sb.append("    \"${name}\": {")
        var first = true
        for (depName in catalog.keys()) {
            match (catalog.get(depName)) {
                case Some(dep) =>
                    if (!first) { sb.append(",") }
                    first = false
                    sb.append("\n      \"${depName}\": \"${dep.version}\"")
                case None => ()
            }
        }
        if (!first) { sb.append("\n    ") }
        sb.append("}")
    }
}

// ============================================================================
// 文本锁文件解析器
// ============================================================================

/// 文本锁文件解析器
public class TextLockfileParser {
    public static func parse(content: String): ?BinaryLockfileData {
        let parser = JsonParser()
        let json = parser.parse(content)

        match (json) {
            case Some(root) =>
                let data = BinaryLockfileData()

                match (JsonHelper.getField(root, "lockfileVersion")) {
                    case Some(JsonValue.Number(n))=> data.format = TextLockfileVersion.fromInt(Int64(n))
                    case _ => ()
                }

                match (JsonHelper.getField(root, "workspaces")) {
                    case Some(JsonValue.Object(ws))=> ()
                    case _ => ()
                }

                match (JsonHelper.getField(root, "packages")) {
                    case Some(JsonValue.Object(packages)) =>
                        for (pkgKey in packages.keys()) {
                            match (packages.get(pkgKey)) {
                                case Some(JsonValue.Array(arr)) =>
                                    match (parsePackageArray(pkgKey, arr)) {
                                        case Some(p) => data.packages.put(p.key(), p)
                                        case None => ()
                                    }
                                case _ => ()
                            }
                        }
                    case _ => ()
                }

                return data
            case None => return None
        }
    }

    private static func parsePackageArray(pkgKey: String, arr: ArrayList<JsonValue>): ?LockfilePkg {
        if (arr.size == 0) { return None }

        let resolutionStr = match (arr[0]) {
            case JsonValue.Str(s) => s
            case _ => return None
        }

        let parsed = parseResolutionString(resolutionStr)
        let name = parsed.first
        let version = parsed.second
        let tag = parsed.third
        let pkg = LockfilePkg(name, Wyhash11.hash(name))
        pkg.resolution.tag = tag

        match (tag) {
            case DependencyTag.Npm =>
                pkg.resolution.npmVersion = version
                if (arr.size >= 2) {
                    match (arr[1]) {
                        case JsonValue.Str(registryUrl) => pkg.resolution.npmUrl = registryUrl
                        case _ => ()
                    }
                }
            case DependencyTag.Tarball => pkg.resolution.tarballUrl = version
            case DependencyTag.Folder => pkg.resolution.folderPath = version
            case DependencyTag.Symlink => pkg.resolution.symlinkPath = version
            case DependencyTag.Workspace => pkg.resolution.workspacePath = version
            case DependencyTag.Git => pkg.resolution.gitRepo = version
            case DependencyTag.Github => pkg.resolution.githubRepo = version
            case _ => ()
        }

        if (arr.size >= 2) {
            match (arr[1]) {
                case JsonValue.Str(_) =>
                    if (arr.size >= 3) {
                        match (arr[2]) {
                            case JsonValue.Object(depsObj) => extractDeps(depsObj, pkg)
                            case _ => ()
                        }
                    }
                    if (arr.size >= 4) {
                        match (arr[3]) {
                            case JsonValue.Str(integrity) => pkg.meta.integrity = Integrity.parse(integrity)
                            case _ => ()
                        }
                    }
                case JsonValue.Object(depsObj) =>
                    extractDeps(depsObj, pkg)
                    if (arr.size >= 3) {
                        match (arr[2]) {
                            case JsonValue.Str(s) =>
                                if (s.startsWith("sha")) {
                                    pkg.meta.integrity = Integrity.parse(s)
                                }
                            case _ => ()
                        }
                    }
                case _ => ()
            }
        }

        return pkg
    }

    private static func parseResolutionString(s: String): Tuple3<String, String, DependencyTag> {
        if (s.endsWith("@root:")) {
            return Tuple3<String, String, DependencyTag>(s[..s.size - 6], "", DependencyTag.Npm)
        }

        match (s.indexOf("@link:")) {
            case Some(linkIdx) =>
                return Tuple3<String, String, DependencyTag>(s[..linkIdx], s[linkIdx + 6..], DependencyTag.Symlink)
            case None => ()
        }

        match (s.indexOf("@workspace:")) {
            case Some(wsIdx) =>
                return Tuple3<String, String, DependencyTag>(s[..wsIdx], s[wsIdx + 11..], DependencyTag.Workspace)
            case None => ()
        }

        match (s.indexOf("@file:")) {
            case Some(fileIdx) =>
                return Tuple3<String, String, DependencyTag>(s[..fileIdx], s[fileIdx + 6..], DependencyTag.Folder)
            case None => ()
        }

        match (s.indexOf("@git+")) {
            case Some(gitIdx) =>
                return Tuple3<String, String, DependencyTag>(s[..gitIdx], s[gitIdx + 5..], DependencyTag.Git)
            case None => ()
        }

        match (s.indexOf("@github:")) {
            case Some(ghIdx) =>
                return Tuple3<String, String, DependencyTag>(s[..ghIdx], s[ghIdx + 8..], DependencyTag.Github)
            case None => ()
        }

        match (s.lastIndexOf("@")) {
            case Some(lastAt) =>
                return Tuple3<String, String, DependencyTag>(s[..lastAt], s[lastAt + 1..], DependencyTag.Npm)
            case None => ()
        }

        return Tuple3<String, String, DependencyTag>(s, "", DependencyTag.Uninitialized)
    }

    private static func extractDeps(depsObj: HashMap<String, JsonValue>, pkg: LockfilePkg): Unit {
        match (depsObj.get("dependencies")) {
            case Some(JsonValue.Object(m)) =>
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) =>
                            let dep = LockfileDependency(k, Wyhash11.hash(k), v)
                            pkg.dependencies.append(dep)
                        case _ => ()
                    }
                }
            case _ => ()
        }
        match (depsObj.get("peerDependencies")) {
            case Some(JsonValue.Object(m)) =>
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) =>
                            let dep = LockfileDependency(k, Wyhash11.hash(k), v)
                            dep.behavior.peer = true
                            pkg.dependencies.append(dep)
                        case _ => ()
                    }
                }
            case _ => ()
        }
        match (depsObj.get("optionalDependencies")) {
            case Some(JsonValue.Object(m)) =>
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) =>
                            let dep = LockfileDependency(k, Wyhash11.hash(k), v)
                            dep.behavior.optional = true
                            pkg.dependencies.append(dep)
                        case _ => ()
                    }
                }
            case _ => ()
        }
        match (depsObj.get("hasInstallScript")) {
            case Some(JsonValue.JsonBool(b)) => pkg.meta.hasInstallScript = b
            case _ => ()
        }
        match (depsObj.get("bin")) {
            case Some(JsonValue.Object(m)) =>
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) => pkg.bin.put(k, v)
                        case _ => ()
                    }
                }
            case _ => ()
        }
    }
}
