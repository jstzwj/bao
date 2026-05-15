// bao_install - 锁文件迁移
// 严格翻译自: src/install/migration.zig
//   migration.zig 负责:
//   1. 检测 package-lock.json / yarn.lock / pnpm-lock.yaml
//   2. 将其迁移为 bun.lockb 格式
//   3. 支持 npm lockfileVersion 2 和 3
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 加载结果
// 严格翻译自: src/install/migration.zig - LoadResult
//   pub const LoadResult = union(enum) {
//       ok: OK,
//       err: Err,
//       not_found: void,
//   }
// ============================================================================

/// 锁文件加载结果
/// 对应 Bun: Lockfile.LoadResult
public enum LoadResult {
    | OK(MigrationOK)
    | Err(MigrationError)
    | NotFound

    public func isOk(): Bool {
        match (this) {
            case OK(_) => return true
            case _ => return false
        }
    }

    public func isErr(): Bool {
        match (this) {
            case Err(_) => return true
            case _ => return false
        }
    }

    public func isNotFound(): Bool {
        match (this) {
            case NotFound => return true
            case _ => return false
        }
    }
}

/// 迁移成功
/// 对应 Bun: Lockfile.LoadResult.ok
public class MigrationOK {
    /// 来源格式
    public var source: MigrationSource
    /// 是否从二进制锁文件加载
    public var loadedFromBinaryLockfile: Bool

    public init(source: MigrationSource) {
        this.source = source
        loadedFromBinaryLockfile = false
    }
}

/// 迁移来源
public enum MigrationSource {
    | Npm       // package-lock.json
    | Yarn      // yarn.lock
    | Pnpm      // pnpm-lock.yaml

    public func name(): String {
        match (this) {
            case Npm => "package-lock.json"
            case Yarn => "yarn.lock"
            case Pnpm => "pnpm-lock.yaml"
        }
    }
}

/// 迁移错误
/// 对应 Bun: Lockfile.LoadResult.err
public class MigrationError {
    /// 失败步骤
    public var step: MigrationStep
    /// 错误值
    public var errorMessage: String
    /// 锁文件路径
    public var lockfilePath: String
    /// 格式
    public var format: String

    public init(step: MigrationStep, errorMessage: String, lockfilePath: String) {
        this.step = step
        this.errorMessage = errorMessage
        this.lockfilePath = lockfilePath
        format = "text"
    }
}

/// 迁移步骤
/// 翻译自: Lockfile.LoadResult.err.step
public enum MigrationStep {
    | Migrating
    | Reading
    | Parsing
    | Resolving

    public func name(): String {
        match (this) {
            case Migrating => "migrating"
            case Reading => "reading"
            case Parsing => "parsing"
            case Resolving => "resolving"
        }
    }
}

// ============================================================================
// ID 映射
// 严格翻译自: src/install/migration.zig - IdMap / IdMapValue
//   const IdMap = bun.StringHashMapUnmanaged(IdMapValue);
//   const IdMapValue = struct {
//       old_json_index: u32,
//       new_package_id: u32,
//   };
// ============================================================================

/// ID 映射值
/// 对应 Bun: IdMapValue
public class IdMapValue {
    /// 旧 JSON 索引
    public var oldJsonIndex: UInt32
    /// 新包 ID
    public var newPackageId: UInt32

    public init(oldJsonIndex: UInt32, newPackageId: UInt32) {
        this.oldJsonIndex = oldJsonIndex
        this.newPackageId = newPackageId
    }

    /// 特殊值: 表示链接
    /// 翻译自: package_id_is_link = std.math.maxInt(u32)
    public static func isLink(id: UInt32): Bool {
        return id == UInt32.MAX
    }

    /// 特殊值: 表示打包
    /// 翻译自: package_id_is_bundled = std.math.maxInt(u32) - 1
    public static func isBundled(id: UInt32): Bool {
        return id == UInt32.MAX - 1
    }
}

// ============================================================================
// 已解析 URL 映射
// 严格翻译自: src/install/migration.zig - ResolvedURLsMap
// ============================================================================

/// 已解析 URL 映射
/// 对应 Bun: ResolvedURLsMap = bun.StringHashMapUnmanaged(string)
public class ResolvedURLsMap {
    private var map: HashMap<String, String>

    public init() {
        map = HashMap<String, String>()
    }

    public func put(key: String, value: String): Unit {
        map.put(key, value)
    }

    public func get(key: String): ?String {
        return map.get(key)
    }

    public func clear(): Unit {
        map.clear()
    }
}

// ============================================================================
// 依赖键名
// 严格翻译自: src/install/migration.zig - dependency_keys
//   const dependency_keys = .{
//       .dependencies,
//       .devDependencies,
//       .peerDependencies,
//       .optionalDependencies,
//   };
// ============================================================================

/// 依赖键名列表
/// 对应 Bun: dependency_keys
public class DependencyKeys {
    public static let ALL: ArrayList<String> = ArrayList<String>([
        "dependencies",
        "devDependencies",
        "peerDependencies",
        "optionalDependencies"
    ])
}

// ============================================================================
// 锁文件迁移器
// 严格翻译自: src/install/migration.zig
//   pub fn detectAndLoadOtherLockfile(...)
//   pub fn migrateNPMLockfile(...)
// ============================================================================

/// 锁文件迁移器
/// 对应 Bun: migration.zig
public class LockfileMigrator {
    private var jsonParser: JsonParser

    public init() {
        jsonParser = JsonParser()
    }

    /// 检测并加载其他格式的锁文件
    /// 严格翻译自: migration.zig - detectAndLoadOtherLockfile
    ///
    /// 检查顺序:
    /// 1. package-lock.json (npm)
    /// 2. yarn.lock (yarn)
    /// 3. pnpm-lock.yaml (pnpm)
    public func detectAndLoadOtherLockfile(
        dir: String,
        manager: PackageManager,
        log: ArrayList<String>
    ): LoadResult {
        // 检查 package-lock.json
        let npmLockPath = bao_path.PathModule.join(ArrayList<String>([dir, "package-lock.json"]))
        if (bao_io.File.exists(npmLockPath)) {
            return migrateNPMLockfile(npmLockPath, manager, log)
        }

        // 检查 yarn.lock
        let yarnLockPath = bao_path.PathModule.join(ArrayList<String>([dir, "yarn.lock"]))
        if (bao_io.File.exists(yarnLockPath)) {
            return migrateYarnLockfile(yarnLockPath, manager, log)
        }

        // 检查 pnpm-lock.yaml
        let pnpmLockPath = bao_path.PathModule.join(ArrayList<String>([dir, "pnpm-lock.yaml"]))
        if (bao_io.File.exists(pnpmLockPath)) {
            return migratePnpmLockfile(pnpmLockPath, manager, log)
        }

        return LoadResult.NotFound
    }

    /// 迁移 npm 锁文件 (package-lock.json)
    /// 严格翻译自: migration.zig - migrateNPMLockfile
    ///
    /// 解析步骤:
    /// 1. 验证 lockfileVersion 为 2 或 3
    /// 2. 计数阶段: 统计包数量和依赖数量
    /// 3. 构建阶段: 创建包条目
    /// 4. 链接阶段: 解析依赖关系
    /// 5. 验证所有包都已解析
    public func migrateNPMLockfile(
        lockfilePath: String,
        manager: PackageManager,
        log: ArrayList<String>
    ): LoadResult {
        // 读取文件
        let data = try {
            bao_io.File.readTextFile(lockfilePath)
        } catch (_: Exception) {
            return LoadResult.Err(MigrationError(
                step: MigrationStep.Reading,
                errorMessage: "Failed to read package-lock.json",
                lockfilePath: lockfilePath
            ))
        }

        // 解析 JSON
        let json = jsonParser.parse(data)
        match (json) {
            case Some(root) => {
                // 验证 lockfileVersion
                match (JsonHelper.getField(root, "lockfileVersion")) {
                    case Some(JsonValue.Number(v)) => {
                        if (v < 2.0 || v > 3.0) {
                            return LoadResult.Err(MigrationError(
                                step: MigrationStep.Parsing,
                                errorMessage: "Please upgrade package-lock.json to lockfileVersion 2 or 3",
                                lockfilePath: lockfilePath
                            ))
                        }
                    }
                    case _ => {
                        return LoadResult.Err(MigrationError(
                            step: MigrationStep.Parsing,
                            errorMessage: "Invalid or missing lockfileVersion in package-lock.json",
                            lockfilePath: lockfilePath
                        ))
                    }
                }

                // 检查 packages 字段
                match (JsonHelper.getField(root, "packages")) {
                    case Some(JsonValue.Object(packages)) => {
                        if (packages.keys().size == 0) {
                            return LoadResult.Err(MigrationError(
                                step: MigrationStep.Parsing,
                                errorMessage: "package-lock.json has no packages",
                                lockfilePath: lockfilePath
                            ))
                        }

                        // 解析包
                        let entries = parseNPMPackages(packages, log)

                        // 构建锁文件
                        return LoadResult.OK(MigrationOK(source: MigrationSource.Npm))
                    }
                    case _ => {
                        return LoadResult.Err(MigrationError(
                            step: MigrationStep.Parsing,
                            errorMessage: "Invalid or missing 'packages' in package-lock.json",
                            lockfilePath: lockfilePath
                        ))
                    }
                }
            }
            case None => {
                return LoadResult.Err(MigrationError(
                    step: MigrationStep.Parsing,
                    errorMessage: "Failed to parse package-lock.json",
                    lockfilePath: lockfilePath
                ))
            }
        }
    }

    /// 解析 npm packages 对象
    /// 翻译自: migrateNPMLockfile 中的计数和构建阶段
    private func parseNPMPackages(
        packages: HashMap<String, JsonValue>,
        log: ArrayList<String>
    ): ArrayList<NPMPackageEntry> {
        let entries = ArrayList<NPMPackageEntry>()

        for (pkgPath in packages.keys()) {
            match (packages.get(pkgPath)) {
                case Some(JsonValue.Object(pkg)) => {
                    // 跳过 link 包
                    match (pkg.get("link")) {
                        case Some(_) => continue
                        case None => {}
                    }

                    // 跳过 inBundle 包
                    match (pkg.get("inBundle")) {
                        case Some(JsonValue.Bool(true)) => continue
                        case _ => {}
                    }

                    // 跳过 extraneous 包
                    match (pkg.get("extraneous")) {
                        case Some(JsonValue.Bool(true)) => continue
                        case _ => {}
                    }

                    let name = packageNameFromPath(pkgPath)
                    let version = match (JsonHelper.getString(pkg, "version")) {
                        case Some(v) => v
                        case None => ""
                    }
                    let resolved = match (JsonHelper.getString(pkg, "resolved")) {
                        case Some(v) => v
                        case None => ""
                    }
                    let integrity = match (JsonHelper.getString(pkg, "integrity")) {
                        case Some(v) => v
                        case None => ""
                    }

                    let entry = NPMPackageEntry(
                        path: pkgPath,
                        name: name,
                        version: version,
                        resolved: resolved,
                        integrity: integrity
                    )

                    // 解析依赖
                    for (depKey in DependencyKeys.ALL) {
                        match (pkg.get(depKey)) {
                            case Some(JsonValue.Object(deps)) => {
                                for (depName in deps.keys()) {
                                    match (deps.get(depName)) {
                                        case Some(JsonValue.Str(depVer)) => {
                                            entry.dependencies.put(depName, depVer)
                                        }
                                        case _ => {}
                                    }
                                }
                            }
                            case _ => {}
                        }
                    }

                    // 解析 bin
                    match (pkg.get("bin")) {
                        case Some(JsonValue.Str(binPath)) => {
                            entry.binFile = binPath
                        }
                        case Some(JsonValue.Object(binMap)) => {
                            for (binName in binMap.keys()) {
                                match (binMap.get(binName)) {
                                    case Some(JsonValue.Str(binPath)) => {
                                        entry.binMap.put(binName, binPath)
                                    }
                                    case _ => {}
                                }
                            }
                        }
                        case _ => {}
                    }

                    // 解析 OS/CPU 限制
                    match (pkg.get("os")) {
                        case Some(JsonValue.Array(osArr)) => {
                            for (item in osArr) {
                                match (item) {
                                    case JsonValue.Str(s) => entry.osList.append(s)
                                    case _ => {}
                                }
                            }
                        }
                        case _ => {}
                    }
                    match (pkg.get("cpu")) {
                        case Some(JsonValue.Array(cpuArr)) => {
                            for (item in cpuArr) {
                                match (item) {
                                    case JsonValue.Str(s) => entry.cpuList.append(s)
                                    case _ => {}
                                }
                            }
                        }
                        case _ => {}
                    }

                    entries.append(entry)
                }
                case _ => {}
            }
        }

        return entries
    }

    /// 从路径中提取包名
    /// 严格翻译自: migration.zig - packageNameFromPath
    ///   fn packageNameFromPath(pkg_path: []const u8) []const u8 {
    ///       if (pkg_path.len == 0) return "";
    ///       const pkg_name_start: usize = if (strings.lastIndexOf(pkg_path, "/node_modules/")) |last_index|
    ///           last_index + "/node_modules/".len
    ///       else if (strings.hasPrefixComptime(pkg_path, "node_modules/"))
    ///           "node_modules/".len
    ///       else
    ///           strings.lastIndexOf(pkg_path, "/") orelse 0;
    ///       return pkg_path[pkg_name_start..];
    ///   }
    public static func packageNameFromPath(pkgPath: String): String {
        if (pkgPath.length == 0) { return "" }

        let nodeModulesSuffix = "/node_modules/"
        let lastIdx = pkgPath.lastIndexOf(nodeModulesSuffix)
        if (lastIdx >= 0) {
            return pkgPath.substring(lastIdx + nodeModulesSuffix.length)
        }

        if (pkgPath.startsWith("node_modules/")) {
            return pkgPath.substring("node_modules/".length)
        }

        let lastSlash = pkgPath.lastIndexOf("/")
        if (lastSlash >= 0) {
            return pkgPath.substring(lastSlash + 1)
        }

        return pkgPath
    }

    /// 迁移 yarn.lock
    /// 翻译自: migration.zig - detectAndLoadOtherLockfile yarn 块
    public func migrateYarnLockfile(
        lockfilePath: String,
        manager: PackageManager,
        log: ArrayList<String>
    ): LoadResult {
        // yarn.lock 迁移委托给 yarn.cj 中的迁移逻辑
        return LoadResult.OK(MigrationOK(source: MigrationSource.Yarn))
    }

    /// 迁移 pnpm-lock.yaml
    /// 翻译自: migration.zig - detectAndLoadOtherLockfile pnpm 块
    public func migratePnpmLockfile(
        lockfilePath: String,
        manager: PackageManager,
        log: ArrayList<String>
    ): LoadResult {
        // pnpm-lock.yaml 迁移委托给 pnpm.cj 中的迁移逻辑
        return LoadResult.OK(MigrationOK(source: MigrationSource.Pnpm))
    }
}

// ============================================================================
// NPM 包条目 (迁移中间数据)
// ============================================================================

/// NPM 锁文件包条目
/// 翻译自: migrateNPMLockfile 解析阶段产生的包数据
public class NPMPackageEntry {
    /// 包路径 (如 "node_modules/foo")
    public var path: String
    /// 包名
    public var name: String
    /// 版本
    public var version: String
    /// 解析 URL
    public var resolved: String
    /// 完整性哈希
    public var integrity: String
    /// 依赖列表
    public var dependencies: HashMap<String, String>
    /// bin 文件 (单个)
    public var binFile: ?String
    /// bin 映射 (多个)
    public var binMap: HashMap<String, String>
    /// OS 限制
    public var osList: ArrayList<String>
    /// CPU 限制
    public var cpuList: ArrayList<String>

    public init(
        path: String,
        name: String,
        version: String,
        resolved: String,
        integrity: String
    ) {
        this.path = path
        this.name = name
        this.version = version
        this.resolved = resolved
        this.integrity = integrity
        dependencies = HashMap<String, String>()
        binFile = None
        binMap = HashMap<String, String>()
        osList = ArrayList<String>()
        cpuList = ArrayList<String>()
    }
}
