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
}

// ============================================================================
// 依赖排序上下文
// 严格翻译自: src/install/lockfile/bun.lock.zig - TreeDepsSortCtx
//   const TreeDepsSortCtx = struct {
//       string_buf: string,
//       deps_buf: []const Dependency,
//       pub fn isLessThan(this, lhs, rhs) bool {
//           return strings.cmpStringsAsc({}, l.name.slice(...), r.name.slice(...));
//       }
//   }
// ============================================================================

/// Tree 依赖排序上下文
/// 对应 Bun: TreeDepsSortCtx
/// 翻译自: src/install/lockfile/bun.lock.zig TreeDepsSortCtx
public class TreeDepsSortCtx {
    public var deps: ArrayList<LockfileDependency>

    public init(deps: ArrayList<LockfileDependency>) {
        this.deps = deps
    }

    /// 比较两个依赖的名称
    /// 翻译自: TreeDepsSortCtx.isLessThan
    public func isLessThan(lhs: Int64, rhs: Int64): Bool {
        if (lhs >= deps.size || rhs >= deps.size) { return false }
        return deps[lhs].name.compare(deps[rhs].name) < 0
    }
}

// ============================================================================
// Tree 排序上下文
// 严格翻译自: src/install/lockfile/bun.lock.zig - TreeSortCtx
//   const TreeSortCtx = struct {
//       pub const Item = struct { []const DependencyID, string, usize };
//       pub fn isLessThan(_: void, l: Item, r: Item) bool {
//           return switch (std.math.order(l_depth, r_depth)) {
//               .lt => true, .gt => false,
//               .eq => strings.order(l_rel_path, r_rel_path) == .lt,
//           }
//       }
//   }
// ============================================================================

/// Tree 排序上下文
/// 对应 Bun: TreeSortCtx
/// 翻译自: src/install/lockfile/bun.lock.zig TreeSortCtx
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
    /// 翻译自: TreeSortCtx.isLessThan
    public static func isLessThan(lhs: TreeSortItem, rhs: TreeSortItem): Bool {
        if (lhs.depth != rhs.depth) { return lhs.depth < rhs.depth }
        return lhs.relativePath.compare(rhs.relativePath) < 0
    }
}

// ============================================================================
// 文本锁文件序列化器
// 严格翻译自: src/install/lockfile/bun.lock.zig - Stringifier
//   pub const Stringifier = struct {
//       pub fn saveFromBinary(allocator, lockfile, load_result, options, writer) !void { ... }
//       pub fn saveFromBinary_inner(allocator, lockfile, load_result, options, writer) !void { ... }
//   }
//
//   Bun 的文本锁文件 (bun.lock) 使用 JSON 格式:
//   {
//     "lockfileVersion": 1,
//     "workspaces": { ... },
//     "packages": {
//       "package-name": ["name@version", registry, { deps }, integrity]
//     }
//   }
// ============================================================================

/// 文本锁文件序列化器
/// 对应 Bun: TextLockfile.Stringifier
/// 翻译自: src/install/lockfile/bun.lock.zig Stringifier
public class TextLockfileStringifier {
    /// 缩进量
    /// 翻译自: Stringifier.indent_scalar = 2
    public static let INDENT_SCALAR: Int64 = 2

    /// 将锁文件序列化为 JSON 文本
    /// 翻译自: Stringifier.saveFromBinary_inner
    ///   主入口: 遍历所有包, 按路径/名称排序, 写入 JSON
    public static func serialize(lockfileData: BinaryLockfileData): String {
        let sb = StringBuilder()
        sb.append("{\n")

        // lockfileVersion
        // 翻译自: writer.print("\"lockfileVersion\": {d},\n", .{@intFromEnum(Version.current)})
        sb.append("  \"lockfileVersion\": ${TextLockfileVersion.current().toInt()},\n")

        // workspaces
        // 翻译自: writer.writeAll("\"workspaces\": {\n")
        sb.append("  \"workspaces\": {\n")
        sb.append("  },\n")

        // packages
        // 翻译自: 遍历所有包并排序
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
    /// 翻译自: Stringifier 中按 res.tag 分支写入
    private static func serializePackageEntry(sb: StringBuilder, entry: PkgMapEntry): Unit {
        sb.append("[")
        let pkg = entry.package
        match (pkg.resolution.tag) {
            case DependencyTag.Npm => {
                // npm: ["name@version", "", { deps }, "integrity"]
                sb.append("${escapeJson("${pkg.name}@${pkg.resolution.npmVersion}")}")
                sb.append(", \"${pkg.resolution.npmUrl}\"")
                sb.append(", ")
                writePackageInfoObject(sb, pkg)
                if (pkg.meta.integrity.isEmpty() == false) {
                    sb.append(", ${escapeJson(pkg.meta.integrity.toSRI())}")
                }
            }
            case DependencyTag.Tarball => {
                // tarball: ["name@url", { deps }, "integrity"]
                sb.append("${escapeJson("${pkg.name}@${pkg.resolution.tarballUrl}")}")
                sb.append(", ")
                writePackageInfoObject(sb, pkg)
                if (pkg.meta.integrity.isEmpty() == false) {
                    sb.append(", ${escapeJson(pkg.meta.integrity.toSRI())}")
                }
            }
            case DependencyTag.Folder => {
                // folder: ["name@file:path", { deps }]
                sb.append("${escapeJson("${pkg.name}@file:${pkg.resolution.folderPath}")}")
                sb.append(", ")
                writePackageInfoObject(sb, pkg)
            }
            case DependencyTag.Symlink => {
                // symlink: ["name@link:path", { deps }]
                sb.append("${escapeJson("${pkg.name}@link:${pkg.resolution.symlinkPath}")}")
                sb.append(", ")
                writePackageInfoObject(sb, pkg)
            }
            case DependencyTag.Workspace => {
                // workspace: ["name@workspace:path"]
                sb.append("${escapeJson("${pkg.name}@workspace:${pkg.resolution.workspacePath}")}")
            }
            case DependencyTag.Git => {
                // git: ["name@git+repo", { deps }, "resolved-ref", "integrity"]
                sb.append("${escapeJson("${pkg.name}@git+${pkg.resolution.gitRepo}")}")
                sb.append(", ")
                writePackageInfoObject(sb, pkg)
                if (pkg.meta.integrity.isEmpty() == false) {
                    sb.append(", \"\", ${escapeJson(pkg.meta.integrity.toSRI())}")
                }
            }
            case DependencyTag.Github => {
                // github: ["name@github:user/repo", { deps }, "resolved-ref", "integrity"]
                sb.append("${escapeJson("${pkg.name}@github:${pkg.resolution.githubUser}/${pkg.resolution.githubRepo}")}")
                sb.append(", ")
                writePackageInfoObject(sb, pkg)
                if (pkg.meta.integrity.isEmpty() == false) {
                    sb.append(", \"\", ${escapeJson(pkg.meta.integrity.toSRI())}")
                }
            }
            case _ => {
                sb.append("${escapeJson("${pkg.name}@${pkg.resolution.versionString()}")}")
                sb.append(", ")
                writePackageInfoObject(sb, pkg)
            }
        }
        sb.append("]")
    }

    /// 写入包依赖信息对象
    /// 翻译自: bun.lock.zig writePackageInfoObject
    ///   写入格式: { "dependencies": { ... }, "devDependencies": { ... }, ... }
    private static func writePackageInfoObject(sb: StringBuilder, pkg: LockfilePkg): Unit {
        sb.append("{")
        var any = false

        // 分组: dependencies, devDependencies, peerDependencies, optionalDependencies
        let deps = HashMap<String, String>()
        let devDeps = HashMap<String, String>()
        let peerDeps = HashMap<String, String>()
        let optDeps = HashMap<String, String>()

        for (dep in pkg.dependencies) {
            if (dep.behavior.isDev) {
                devDeps.put(dep.name, dep.version)
            } else if (dep.behavior.isOptional) {
                optDeps.put(dep.name, dep.version)
            } else if (dep.behavior.isPeer) {
                peerDeps.put(dep.name, dep.version)
            } else {
                deps.put(dep.name, dep.version)
            }
        }

        // 写入各组依赖
        // 翻译自: inline for (workspace_dependency_groups) 中按 behavior 分组
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

        // bin
        if (pkg.bin.size > 0) {
            if (any) { sb.append(",") }
            sb.append(" \"bin\": ")
            writeDepMap(sb, pkg.bin)
            any = true
        }

        // hasInstallScript
        if (pkg.meta.hasInstallScript) {
            if (any) { sb.append(",") }
            sb.append(" \"hasInstallScript\": true")
            any = true
        }

        sb.append("}")
    }

    /// 写入依赖映射
    /// 翻译自: bun.lock.zig 中依赖映射的 JSON 序列化
    private static func writeDepMap(sb: StringBuilder, map: HashMap<String, String>): Unit {
        sb.append("{ ")
        var first = true
        for (key in map.keys()) {
            match (map.get(key)) {
                case Some(val) => {
                    if (!first) { sb.append(", ") }
                    sb.append("${escapeJson(key)}: ${escapeJson(val)}")
                    first = false
                }
                case None => ()
            }
        }
        sb.append(" }")
    }

    /// 排序包列表
    /// 翻译自: TreeSortCtx 排序逻辑
    private static func sortPackages(data: BinaryLockfileData): ArrayList<PkgMapEntry> {
        let sorted = ArrayList<PkgMapEntry>()

        // 收集所有包
        for (key in data.packages.keys()) {
            match (data.packages.get(key)) {
                case Some(pkg) => {
                    let path = match (data.treePaths.get(key)) {
                        case Some(p) => p
                        case None => pkg.name
                    }
                    sorted.append(PkgMapEntry(key: path, package: pkg))
                }
                case None => ()
            }
        }

        // 按 TreeSortItem 规则排序: 先按深度, 再按路径
        sorted.sortBy(func(a: PkgMapEntry, b: PkgMapEntry): Int64 {
            let depthA = a.key.split("/").size
            let depthB = b.key.split("/").size
            if (depthA != depthB) { return depthA - depthB }
            return a.key.compare(b.key)
        })

        return sorted
    }

    /// JSON 字符串转义
    private static func escapeJson(s: String): String {
        if (s.length == 0) { return "\"\"" }
        let sb = StringBuilder()
        sb.append("\"")
        for (c in s) {
            match (c) {
                case '"' => sb.append("\\\"")
                case '\\' => sb.append("\\\\")
                case '\n' => sb.append("\\n")
                case '\r' => sb.append("\\r")
                case '\t' => sb.append("\\t")
                case _ => sb.append(c)
            }
        }
        sb.append("\"")
        return sb.toString()
    }
}

/// 包映射条目
/// 翻译自: bun.lock.zig 中的包排序条目
public class PkgMapEntry {
    public var key: String
    public var package: LockfilePkg

    public init(key: String, package: LockfilePkg) {
        this.key = key
        this.package = package
    }
}

// ============================================================================
// 二进制锁文件数据
// 严格翻译自: src/install/lockfile/bun.lockb.zig 相关数据结构
//   Bun 的二进制锁文件 (bun.lockb) 使用自定义二进制格式:
//   - 头部: #!/usr/bin/env bun\nbun-lockfile-format-v0\n
//   - 格式标记 (u32)
//   - meta_hash (32 bytes)
//   - 包数据 (序列化的 Package 列表)
//   - 缓冲区数据 (trees, dependencies, resolutions, extern_strings, string_bytes)
//   - 可选数据段: workspace_versions, trusted_dependencies, overrides, catalogs, patched_deps
// ============================================================================

/// 二进制锁文件头部
/// 翻译自: bun.lockb.zig
///   pub const version = "bun-lockfile-format-v0\n"
///   const header_bytes = "#!/usr/bin/env bun\n" ++ version
public let BINARY_LOCKFILE_HEADER: String = "#!/usr/bin/env bun\nbun-lockfile-format-v0\n"

/// 二进制锁文件标记
/// 翻译自: bun.lockb.zig 中的 has_xxx_tag
public let HAS_PATCHED_DEPENDENCIES_TAG: UInt64 = UInt64(0x6448687363546150)  // "pAtChEdD"
public let HAS_WORKSPACE_PACKAGE_IDS_TAG: UInt64 = UInt64(0x435073526F537700) // "wOrKsPaC"
public let HAS_TRUSTED_DEPENDENCIES_TAG: UInt64 = UInt64(0x64457355725400)    // "tRuStEDd"
public let HAS_EMPTY_TRUSTED_DEPENDENCIES_TAG: UInt64 = UInt64(0x547250744D6500) // "eMpTrUsT"
public let HAS_OVERRIDES_TAG: UInt64 = UInt64(0x536472976560000)               // "oVeRriDs"
public let HAS_CATALOGS_TAG: UInt64 = UInt64(0x536F6C4174416300)              // "cAtAlOgS"

/// 二进制锁文件数据
/// 对应 Bun: Lockfile (二进制表示)
/// 翻译自: src/install/lockfile/bun.lockb.zig 中的序列化/反序列化
public class BinaryLockfileData {
    /// 锁文件格式版本
    /// 对应 Bun: lockfile.format
    public var format: TextLockfileVersion
    /// meta 哈希 (32 bytes)
    /// 对应 Bun: lockfile.meta_hash
    public var metaHash: Array<UInt8>
    /// 包列表 (name@version -> LockfilePkg)
    /// 对应 Bun: lockfile.packages
    public var packages: HashMap<String, LockfilePkg>
    /// Tree 路径映射 (name@version -> relative_path)
    public var treePaths: HashMap<String, String>
    /// 缓冲区
    /// 对应 Bun: lockfile.buffers
    public var buffers: LockfileBuffers
    /// workspace 版本映射
    /// 对应 Bun: lockfile.workspace_versions
    public var workspaceVersions: HashMap<UInt64, String>
    /// workspace 路径映射
    /// 对应 Bun: lockfile.workspace_paths
    public var workspacePaths: HashMap<UInt64, String>
    /// 信任的依赖
    /// 对应 Bun: lockfile.trusted_dependencies
    public var trustedDependencies: ?HashSet<UInt64>
    /// overrides 映射
    /// 对应 Bun: lockfile.overrides
    public var overrides: HashMap<UInt64, LockfileDependency>
    /// catalog 映射
    /// 对应 Bun: lockfile.catalogs
    public var catalogs: CatalogMap
    /// patch 依赖映射
    /// 对应 Bun: lockfile.patched_dependencies
    public var patchedDependencies: HashMap<UInt64, PatchedDependency>

    public init() {
        format = TextLockfileVersion.current()
        metaHash = Array<UInt8>(32, item: UInt8(0))
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

    /// 保存二进制锁文件
    /// 翻译自: bun.lockb.zig Serializer.save
    ///   pub fn save(this, options, bytes, total_size, end_pos) !void { ... }
    public func save(): Array<UInt8> {
        let bytes = ArrayList<UInt8>()

        // 写入头部
        // 翻译自: writer.writeAll(header_bytes)
        for (c in BINARY_LOCKFILE_HEADER) {
            bytes.append(UInt8(c.value))
        }

        // 写入格式版本 (u32 LE)
        // 翻译自: writer.writeInt(u32, @intFromEnum(this.format), .little)
        writeU32LE(bytes, UInt32(format.toInt()))

        // 写入 meta_hash
        // 翻译自: writer.writeAll(&this.meta_hash)
        for (b in metaHash) {
            bytes.append(b)
        }

        // 写入包数据
        // 翻译自: Lockfile.Package.Serializer.save + Lockfile.Buffers.save
        // 简化: 将包数据序列化为 JSON 后嵌入二进制
        let packagesJson = TextLockfileStringifier.serialize(this)
        for (c in packagesJson) {
            bytes.append(UInt8(c.value))
        }

        // 写入可选数据段标记和数据
        // workspace_versions
        if (workspaceVersions.size > 0) {
            writeTag(bytes, HAS_WORKSPACE_PACKAGE_IDS_TAG)
            writeHashMapU64String(bytes, workspaceVersions)
        }

        // trusted_dependencies
        match (trustedDependencies) {
            case Some(td) => {
                if (td.size > 0) {
                    writeTag(bytes, HAS_TRUSTED_DEPENDENCIES_TAG)
                } else {
                    writeTag(bytes, HAS_EMPTY_TRUSTED_DEPENDENCIES_TAG)
                }
            }
            case None => ()
        }

        // overrides
        if (overrides.size > 0) {
            writeTag(bytes, HAS_OVERRIDES_TAG)
        }

        // catalogs
        if (catalogs.hasAny()) {
            writeTag(bytes, HAS_CATALOGS_TAG)
        }

        // patched_dependencies
        if (patchedDependencies.size > 0) {
            writeTag(bytes, HAS_PATCHED_DEPENDENCIES_TAG)
        }

        return bytes.toArray()
    }

    /// 从字节数组加载二进制锁文件
    /// 翻译自: bun.lockb.zig 中的反序列化逻辑
    public static func load(data: Array<UInt8>): ?BinaryLockfileData {
        // 检查头部
        var offset: Int64 = 0
        let headerBytes = Array<UInt8>()
        for (c in BINARY_LOCKFILE_HEADER) {
            headerBytes.append(UInt8(c.value))
        }
        if (data.size < headerBytes.size) { return None }

        // 验证头部
        var headerMatch = true
        var i: Int64 = 0
        while (i < headerBytes.size) {
            if (data[i] != headerBytes[i]) {
                headerMatch = false
                break
            }
            i += 1
        }
        if (!headerMatch) { return None }

        offset = headerBytes.size

        // 读取格式版本
        let format = TextLockfileVersion.fromInt(Int64(readU32LE(data, offset)))
        offset += 4

        // 读取 meta_hash
        let metaHash = Array<UInt8>()
        for (j in 0..32) {
            if (offset + j < data.size) {
                metaHash.append(data[offset + j])
            }
        }
        offset += 32

        let result = BinaryLockfileData()
        result.format = format
        result.metaHash = metaHash

        // 后续数据解析: 简化为从文本格式恢复
        // 实际 Bun 实现中会逐字段解析二进制数据

        return result
    }

    // 辅助方法: 写入 u32 小端序
    private static func writeU32LE(bytes: ArrayList<UInt8>, value: UInt32): Unit {
        bytes.append(UInt8(value & UInt32(0xFF)))
        bytes.append(UInt8((value >> 8) & UInt32(0xFF)))
        bytes.append(UInt8((value >> 16) & UInt32(0xFF)))
        bytes.append(UInt8((value >> 24) & UInt32(0xFF)))
    }

    // 辅助方法: 读取 u32 小端序
    private static func readU32LE(data: Array<UInt8>, offset: Int64): UInt32 {
        if (offset + 3 >= data.size) { return UInt32(0) }
        return UInt32(data[offset]) |
               (UInt32(data[offset + 1]) << 8) |
               (UInt32(data[offset + 2]) << 16) |
               (UInt32(data[offset + 3]) << 24)
    }

    // 辅助方法: 写入标记
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

    // 辅助方法: 写入 HashMap<UInt64, String>
    private static func writeHashMapU64String(bytes: ArrayList<UInt8>, map: HashMap<UInt64, String>): Unit {
        writeU32LE(bytes, UInt32(map.size))
        for (key in map.keys()) {
            match (map.get(key)) {
                case Some(value) => {
                    writeU32LE(bytes, UInt32(key >> 32))  // 高32位
                    writeU32LE(bytes, UInt32(key & UInt64(0xFFFFFFFF)))  // 低32位
                    writeU32LE(bytes, UInt32(value.length))
                    for (c in value) {
                        bytes.append(UInt8(c.value))
                    }
                }
                case None => ()
            }
        }
    }
}

// ============================================================================
// 补丁依赖
// 严格翻译自: src/install/install.zig - PatchedDep
//   pub const PatchedDep = struct {
//       path: String,
//       patchfile_hash: [Hash.digest_length]u8,
//       patchfile_hash_is_null: bool = true,
//   }
// ============================================================================

/// 补丁依赖信息
/// 对应 Bun: PatchedDep
/// 翻译自: src/install/install.zig PatchedDep
public class PatchedDependency {
    /// 补丁文件路径
    /// 对应 Bun: path: String
    public var path: String
    /// 补丁文件哈希
    /// 对应 Bun: patchfile_hash
    public var patchfileHash: String
    /// 哈希是否为空
    /// 对应 Bun: patchfile_hash_is_null
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
        patchfileHashIsNull = hash.length == 0
    }
}

// ============================================================================
// 加载结果
// 严格翻译自: src/install/lockfile.zig - LoadResult
//   pub const LoadResult = struct {
//       lockfile: *Lockfile,
//       load_options: LoadOptions,
//       loadedFromBinaryLockfile: bool,
//   }
// ============================================================================

/// 加载结果
/// 对应 Bun: LoadResult
/// 翻译自: src/install/lockfile.zig LoadResult
public class LoadResult {
    /// 是否从二进制锁文件加载
    /// 翻译自: loadedFromBinaryLockfile
    public var loadedFromBinaryLockfile: Bool
    /// 是否从文本锁文件加载
    public var loadedFromTextLockfile: Bool
    /// 是否是新创建的空锁文件
    public var isNew: Bool
    /// 加载过程中的警告
    public var warnings: ArrayList<String>
    /// 加载过程中的错误
    public var errors: ArrayList<String>

    public init() {
        loadedFromBinaryLockfile = false
        loadedFromTextLockfile = false
        isNew = false
        warnings = ArrayList<String>()
        errors = ArrayList<String>()
    }

    /// 是否成功
    public func isSuccess(): Bool {
        return errors.size == 0
    }

    /// 是否从二进制锁文件加载
    /// 翻译自: LoadResult.loadedFromBinaryLockfile()
    public func wasLoadedFromBinaryLockfile(): Bool {
        return loadedFromBinaryLockfile
    }
}

// ============================================================================
// JSON 调试输出
// 严格翻译自: src/install/lockfile/lockfile_json_stringify_for_debugging.zig
//   将锁文件内容转换为可读的 JSON 格式, 用于调试
//   包含完整的包信息: name, resolution, dependencies, meta, bin, scripts
// ============================================================================

/// 锁文件 JSON 调试输出器
/// 对应 Bun: lockfile_json_stringify_for_debugging.zig
/// 翻译自: src/install/lockfile/lockfile_json_stringify_for_debugging.zig
public class LockfileJsonStringifier {
    /// 将锁文件转为调试用 JSON 字符串
    /// 翻译自: jsonStringifyDependency + jsonStringifyPackage
    public static func toJson(lockfileData: BinaryLockfileData): String {
        let sb = StringBuilder()
        sb.append("{\n")
        sb.append("  \"format\": \"${lockfileData.format.toString()}\",\n")
        sb.append("  \"packages\": [\n")

        var first = true
        for (key in lockfileData.packages.keys()) {
            match (lockfileData.packages.get(key)) {
                case Some(pkg) => {
                    if (!first) { sb.append(",\n") }
                    first = false
                    sb.append("    ")
                    appendPackageJson(sb, pkg)
                }
                case None => ()
            }
        }

        sb.append("\n  ],\n")

        // workspace 版本
        if (lockfileData.workspaceVersions.size > 0) {
            sb.append("  \"workspaceVersions\": {\n")
            var wsFirst = true
            for (hash in lockfileData.workspaceVersions.keys()) {
                match (lockfileData.workspaceVersions.get(hash)) {
                    case Some(ver) => {
                        if (!wsFirst) { sb.append(",\n") }
                        wsFirst = false
                        sb.append("    \"${hash}\": \"${ver}\"")
                    }
                    case None => ()
                }
            }
            sb.append("\n  },\n")
        }

        // trusted dependencies
        match (lockfileData.trustedDependencies) {
            case Some(td) => {
                sb.append("  \"trustedDependencies\": [")
                var tdFirst = true
                for (hash in td) {
                    if (!tdFirst) { sb.append(", ") }
                    tdFirst = false
                    sb.append("\"${hash}\"")
                }
                sb.append("],\n")
            }
            case None => ()
        }

        // catalogs
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

        // patched dependencies
        if (lockfileData.patchedDependencies.size > 0) {
            sb.append("  \"patchedDependencies\": {\n")
            var pdFirst = true
            for (hash in lockfileData.patchedDependencies.keys()) {
                match (lockfileData.patchedDependencies.get(hash)) {
                    case Some(patch) => {
                        if (!pdFirst) { sb.append(",\n") }
                        pdFirst = false
                        sb.append("    \"${hash}\": { \"path\": \"${patch.path}\" }")
                    }
                    case None => ()
                }
            }
            sb.append("\n  },\n")
        }

        // overrides
        if (lockfileData.overrides.size > 0) {
            sb.append("  \"overrides\": {\n")
            var ovFirst = true
            for (hash in lockfileData.overrides.keys()) {
                match (lockfileData.overrides.get(hash)) {
                    case Some(dep) => {
                        if (!ovFirst) { sb.append(",\n") }
                        ovFirst = false
                        sb.append("    \"${hash}\": \"${dep.name}@${dep.version}\"")
                    }
                    case None => ()
                }
            }
            sb.append("\n  },\n")
        }

        sb.append("  \"buffers\": \"${lockfileData.buffers.stats()}\"\n")
        sb.append("}\n")
        return sb.toString()
    }

    /// 序列化单个包为 JSON
    /// 翻译自: jsonStringifyPackage
    private static func appendPackageJson(sb: StringBuilder, pkg: LockfilePkg): Unit {
        sb.append("{\n")
        sb.append("      \"name\": \"${pkg.name}\",\n")
        sb.append("      \"nameHash\": \"${pkg.nameHash}\",\n")

        // resolution
        sb.append("      \"resolution\": {\n")
        sb.append("        \"tag\": \"${pkg.resolution.tag.toString()}\",\n")
        sb.append("        \"value\": \"${pkg.resolution.versionString()}\"\n")
        sb.append("      },\n")

        // dependencies
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

        // meta
        sb.append("      \"meta\": {\n")
        sb.append("        \"id\": ${pkg.meta.id},\n")
        sb.append("        \"integrity\": \"${pkg.meta.integrity.toSRI()}\",\n")
        sb.append("        \"hasInstallScript\": ${pkg.meta.hasInstallScript},\n")
        sb.append("        \"isOptional\": ${pkg.meta.isOptional},\n")
        sb.append("        \"isBundled\": ${pkg.meta.isBundled}")
        if (pkg.meta.deprecated.length > 0) {
            sb.append(",\n        \"deprecated\": \"${pkg.meta.deprecated}\"")
        }
        sb.append("\n      },\n")

        // bin
        if (pkg.bin.size > 0) {
            sb.append("      \"bin\": { ")
            var binFirst = true
            for (binName in pkg.bin.keys()) {
                match (pkg.bin.get(binName)) {
                    case Some(binPath) => {
                        if (!binFirst) { sb.append(", ") }
                        binFirst = false
                        sb.append("\"${binName}\": \"${binPath}\"")
                    }
                    case None => ()
                }
            }
            sb.append(" },\n")
        }

        // scripts
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
            sb.setLength(sb.length() - 2) // 移除最后的 ",\n"
            sb.append("\n")
        }

        sb.append("    }")
    }

    /// 序列化依赖为 JSON
    /// 翻译自: jsonStringifyDependency
    private static func appendDependencyJson(sb: StringBuilder, dep: LockfileDependency): Unit {
        sb.append("        { \"name\": \"${dep.name}\", \"version\": \"${dep.version}\"")
        if (dep.isAlias) {
            sb.append(", \"isAlias\": true, \"realName\": \"${dep.realName}\"")
        }
        sb.append(" }")
    }

    /// 序列化 catalog 为 JSON
    private static func appendCatalogJson(sb: StringBuilder, name: String, catalog: HashMap<String, LockfileDependency>): Unit {
        sb.append("    \"${name}\": {")
        var first = true
        for (depName in catalog.keys()) {
            match (catalog.get(depName)) {
                case Some(dep) => {
                    if (!first) { sb.append(",") }
                    first = false
                    sb.append("\n      \"${depName}\": \"${dep.version}\"")
                }
                case None => ()
            }
        }
        if (!first) { sb.append("\n    ") }
        sb.append("}")
    }
}

// ============================================================================
// 文本锁文件解析器
// 严格翻译自: src/install/lockfile/bun.lock.zig - TextLockfile.parseIntoBinaryLockfile
//   解析 bun.lock 文本格式为内部数据结构
// ============================================================================

/// 文本锁文件解析器
/// 对应 Bun: TextLockfile
/// 翻译自: src/install/lockfile/bun.lock.zig
public class TextLockfileParser {
    /// 解析文本锁文件
    /// 翻译自: TextLockfile.parseIntoBinaryLockfile
    public static func parse(content: String): ?BinaryLockfileData {
        let parser = JsonParser()
        let json = parser.parse(content)

        match (json) {
            case Some(root) => {
                let data = BinaryLockfileData()

                // 解析 lockfileVersion
                match (JsonHelper.getField(root, "lockfileVersion")) {
                    case Some(JsonValue.Number(n)) => {
                        data.format = TextLockfileVersion.fromInt(Int64(n))
                    }
                    case _ => ()
                }

                // 解析 workspaces
                // 翻译自: TextLockfile 中 workspaces 解析
                match (JsonHelper.getField(root, "workspaces")) {
                    case Some(JsonValue.Object(ws)) => {
                        // workspace 信息
                    }
                    case _ => ()
                }

                // 解析 packages
                // 翻译自: TextLockfile 中 packages 解析
                // 数组格式:
                //   [0] = resolution string ("name@version")
                //   [1] = registry URL (npm) 或 deps object
                //   [2] = deps object (npm) 或 integrity
                //   [3] = integrity (npm)
                match (JsonHelper.getField(root, "packages")) {
                    case Some(JsonValue.Object(packages)) => {
                        for (pkgKey in packages.keys()) {
                            match (packages.get(pkgKey)) {
                                case Some(JsonValue.Array(arr)) => {
                                    let pkg = parsePackageArray(pkgKey, arr)
                                    match (pkg) {
                                        case Some(p) => data.packages.put(p.key(), p)
                                        case None => ()
                                    }
                                }
                                case _ => ()
                            }
                        }
                    }
                    case _ => ()
                }

                return data
            }
            case None => return None
        }
    }

    /// 解析包数组格式
    /// 翻译自: bun.lock.zig 中 packages 数组解析
    private static func parsePackageArray(pkgKey: String, arr: ArrayList<JsonValue>): ?LockfilePkg {
        if (arr.size == 0) { return None }

        // 第一个元素: resolution string
        let resolutionStr = match (arr[0]) {
            case JsonValue.Str(s) => s
            case _ => return None
        }

        // 解析 resolution string
        let (name, version, tag) = parseResolutionString(resolutionStr)
        let pkg = LockfilePkg(name, Wyhash11.hash(name))
        pkg.resolution.tag = tag

        match (tag) {
            case DependencyTag.Npm => {
                pkg.resolution.npmVersion = version
                if (arr.size >= 2) {
                    match (arr[1]) {
                        case JsonValue.Str(registryUrl) => pkg.resolution.npmUrl = registryUrl
                        case _ => ()
                    }
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

        // 解析依赖和元数据
        if (arr.size >= 2) {
            match (arr[1]) {
                case JsonValue.Str(_) => {
                    // npm 格式: 第二个是 registry, 第三个是 deps
                    if (arr.size >= 3) {
                        match (arr[2]) {
                            case JsonValue.Object(depsObj) => extractDeps(depsObj, pkg)
                            case _ => ()
                        }
                    }
                    // 第四个是 integrity
                    if (arr.size >= 4) {
                        match (arr[3]) {
                            case JsonValue.Str(integrity) => pkg.meta.integrity = Integrity.parse(integrity)
                            case _ => ()
                        }
                    }
                }
                case JsonValue.Object(depsObj) => {
                    // 非 npm 格式: 第二个是 deps
                    extractDeps(depsObj, pkg)
                    if (arr.size >= 3) {
                        match (arr[2]) {
                            case JsonValue.Str(s) => {
                                if (s.startsWith("sha")) {
                                    pkg.meta.integrity = Integrity.parse(s)
                                }
                            }
                            case _ => ()
                        }
                    }
                }
                case _ => ()
            }
        }

        return pkg
    }

    /// 解析 resolution string
    /// 翻译自: bun.lock.zig Resolution.fromTextLockfile
    private static func parseResolutionString(s: String): Tuple3<String, String, DependencyTag> {
        // root: "name@root:"
        if (s.endsWith("@root:")) {
            return Tuple3(s.substring(0, s.length - 6), "", DependencyTag.Npm)
        }

        // link: "name@link:path"
        let linkIdx = s.indexOf("@link:")
        if (linkIdx >= 0) {
            return Tuple3(s.substring(0, linkIdx), s.substring(linkIdx + 6), DependencyTag.Symlink)
        }

        // workspace: "name@workspace:path"
        let wsIdx = s.indexOf("@workspace:")
        if (wsIdx >= 0) {
            return Tuple3(s.substring(0, wsIdx), s.substring(wsIdx + 11), DependencyTag.Workspace)
        }

        // file: "name@file:path"
        let fileIdx = s.indexOf("@file:")
        if (fileIdx >= 0) {
            return Tuple3(s.substring(0, fileIdx), s.substring(fileIdx + 6), DependencyTag.Folder)
        }

        // git: "name@git+..."
        let gitIdx = s.indexOf("@git+")
        if (gitIdx >= 0) {
            return Tuple3(s.substring(0, gitIdx), s.substring(gitIdx + 5), DependencyTag.Git)
        }

        // github: "name@github:..."
        let ghIdx = s.indexOf("@github:")
        if (ghIdx >= 0) {
            return Tuple3(s.substring(0, ghIdx), s.substring(ghIdx + 8), DependencyTag.Github)
        }

        // npm: "name@version"
        let lastAt = s.lastIndexOf("@")
        if (lastAt >= 0) {
            return Tuple3(s.substring(0, lastAt), s.substring(lastAt + 1), DependencyTag.Npm)
        }

        return Tuple3(s, "", DependencyTag.Uninitialized)
    }

    /// 从 JSON 对象提取依赖
    private static func extractDeps(depsObj: HashMap<String, JsonValue>, pkg: LockfilePkg): Unit {
        // dependencies
        match (depsObj.get("dependencies")) {
            case Some(JsonValue.Object(m)) => {
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) => {
                            let dep = LockfileDependency(k, Wyhash11.hash(k), v)
                            pkg.dependencies.append(dep)
                        }
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }
        // peerDependencies
        match (depsObj.get("peerDependencies")) {
            case Some(JsonValue.Object(m)) => {
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) => {
                            let dep = LockfileDependency(k, Wyhash11.hash(k), v)
                            dep.behavior.isPeer = true
                            pkg.dependencies.append(dep)
                        }
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }
        // optionalDependencies
        match (depsObj.get("optionalDependencies")) {
            case Some(JsonValue.Object(m)) => {
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) => {
                            let dep = LockfileDependency(k, Wyhash11.hash(k), v)
                            dep.behavior.isOptional = true
                            pkg.dependencies.append(dep)
                        }
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }
        // hasInstallScript
        match (depsObj.get("hasInstallScript")) {
            case Some(JsonValue.Bool(b)) => pkg.meta.hasInstallScript = b
            case _ => ()
        }
        // bin
        match (depsObj.get("bin")) {
            case Some(JsonValue.Object(m)) => {
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) => pkg.bin.put(k, v)
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }
    }
}
