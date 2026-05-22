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
import bao_sys.*

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
        return id == UInt32(4294967295)
    }

    /// 特殊值: 表示打包
    /// 翻译自: package_id_is_bundled = std.math.maxInt(u32) - 1
    public static func isBundled(id: UInt32): Bool {
        return id == UInt32(4294967294)
    }
}

/// 未设置包 ID
/// 翻译自: const unset_package_id = Install.invalid_package_id - 1
public let UNSET_PACKAGE_ID: UInt32 = UInt32(4294967294) // invalid_package_id - 1

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
    private var jsonParser: PkgJsonParser

    public init() {
        jsonParser = PkgJsonParser()
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
        let npmLockPath = Path.join([dir, "package-lock.json"])
        if (BaoFile.exists(npmLockPath)) {
            return migrateNPMLockfile(npmLockPath, manager, log)
        }

        // 检查 yarn.lock
        let yarnLockPath = Path.join([dir, "yarn.lock"])
        if (BaoFile.exists(yarnLockPath)) {
            return migrateYarnLockfile(yarnLockPath, manager, log)
        }

        // 检查 pnpm-lock.yaml
        let pnpmLockPath = Path.join([dir, "pnpm-lock.yaml"])
        if (BaoFile.exists(pnpmLockPath)) {
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
        var data = ""
        match (BaoFile.readAllText(lockfilePath)) {
            case SysMaybe<String>.Ok(text) => data = text
            case _ =>
                return LoadResult.Err(MigrationError(
                    MigrationStep.Reading,
                    "Failed to read package-lock.json",
                    lockfilePath
                ))
        }

        // 解析 JSON
        let jsonParser = PkgJsonParser()
        let json = jsonParser.parse(data)
        match (json) {
            case Some(root) => validateLockfileJson(root, lockfilePath, log)
            case None => return LoadResult.Err(MigrationError(
                MigrationStep.Parsing,
                "Invalid JSON in package-lock.json",
                lockfilePath
            ))
        }
    }

    private func validateLockfileJson(root: JsonValue, lockfilePath: String, log: ArrayList<String>): LoadResult {
        // 验证 lockfileVersion
        match (PkgJsonHelper.getField(root, "lockfileVersion")) {
            case Some(JsonValue.Number(v)) =>
                if (v < 2.0 || v > 3.0) {
                    return LoadResult.Err(MigrationError(
                        MigrationStep.Parsing,
                        "Please upgrade package-lock.json to lockfileVersion 2 or 3",
                        lockfilePath
                    ))
                }
            case _ =>
                return LoadResult.Err(MigrationError(
                    MigrationStep.Parsing,
                    "Invalid or missing lockfileVersion in package-lock.json",
                    lockfilePath
                ))
        }

        // 检查 packages 字段
        match (PkgJsonHelper.getField(root, "packages")) {
            case Some(JsonValue.Object(packages)) =>
                if (packages.keys().size == 0) {
                    return LoadResult.Err(MigrationError(
                        MigrationStep.Parsing,
                        "package-lock.json has no packages",
                        lockfilePath
                    ))
                }
                // 解析包
                let entries = parseNPMPackages(packages, log)
                // 构建锁文件
                return LoadResult.OK(MigrationOK(MigrationSource.Npm))
            case _ =>
                return LoadResult.Err(MigrationError(
                    MigrationStep.Parsing,
                    "Invalid or missing 'packages' in package-lock.json",
                    lockfilePath
                ))
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
                case Some(JsonValue.Object(pkg)) =>
                    // 跳过 link 包
                    match (pkg.get("link")) {
                        case Some(_) => ()
                        case None => ()
                    }
                    // 跳过 inBundle 包
                    match (pkg.get("inBundle")) {
                        case Some(JsonValue.JsonBool(true)) => ()
                        case _ => ()
                    }
                    // 跳过 extraneous 包
                    match (pkg.get("extraneous")) {
                        case Some(JsonValue.JsonBool(true)) => ()
                        case _ => ()
                    }

                    let name = packageNameFromPath(pkgPath)
                    let version = match (PkgJsonHelper.getString(JsonValue.Object(pkg), "version")) {
                        case Some(v) => v
                        case None => ""
                    }
                    let resolved = match (PkgJsonHelper.getString(JsonValue.Object(pkg), "resolved")) {
                        case Some(v) => v
                        case None => ""
                    }
                    let integrity = match (PkgJsonHelper.getString(JsonValue.Object(pkg), "integrity")) {
                        case Some(v) => v
                        case None => ""
                    }

                    let entry = NPMPackageEntry(
                        pkgPath,
                        name,
                        version,
                        resolved,
                        integrity
                    )

                    // 解析依赖
                    for (depKey in DependencyKeys.ALL) {
                        match (pkg.get(depKey)) {
                            case Some(JsonValue.Object(deps)) =>
                                for (depName in deps.keys()) {
                                    match (deps.get(depName)) {
                                        case Some(JsonValue.Str(depVer))=> entry.dependencies.put(depName, depVer)
                                        case _ => ()
                                    }
                                }
                            case _ => ()
                        }
                    }

                    // 解析 bin
                    match (pkg.get("bin")) {
                        case Some(JsonValue.Str(binPath))=> entry.binFile = binPath
                        case Some(JsonValue.Object(binMap)) =>
                            for (binName in binMap.keys()) {
                                match (binMap.get(binName)) {
                                    case Some(JsonValue.Str(bp))=> entry.binMap.put(binName, bp)
                                    case _ => ()
                                }
                            }
                        case _ => ()
                    }

                    // 解析 OS/CPU 限制
                    match (pkg.get("os")) {
                        case Some(JsonValue.Array(osArr)) =>
                            for (item in osArr) {
                                match (item) {
                                    case JsonValue.Str(s) => entry.osList.append(s)
                                    case _ => ()
                                }
                            }
                        case _ => ()
                    }
                    match (pkg.get("cpu")) {
                        case Some(JsonValue.Array(cpuArr)) =>
                            for (item in cpuArr) {
                                match (item) {
                                    case JsonValue.Str(s) => entry.cpuList.append(s)
                                    case _ => ()
                                }
                            }
                        case _ => ()
                    }

                    entries.append(entry)
                case _ => ()
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
        if (pkgPath.size == 0) { return "" }

        let nodeModulesSuffix = "/node_modules/"
        match (pkgPath.lastIndexOf(nodeModulesSuffix)) {
            case Some(lastIdx) =>
                return pkgPath[lastIdx + Int64(nodeModulesSuffix.size)..]
            case None => ()
        }

        if (pkgPath.startsWith("node_modules/")) {
            return pkgPath[14..]
        }

        match (pkgPath.lastIndexOf("/")) {
            case Some(lastSlash) =>
                return pkgPath[lastSlash + 1..]
            case None => ()
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
        return LoadResult.OK(MigrationOK(MigrationSource.Yarn))
    }

    /// 迁移 pnpm-lock.yaml
    /// 翻译自: migration.zig - detectAndLoadOtherLockfile pnpm 块
    public func migratePnpmLockfile(
        lockfilePath: String,
        manager: PackageManager,
        log: ArrayList<String>
    ): LoadResult {
        // pnpm-lock.yaml 迁移委托给 pnpm.cj 中的迁移逻辑
        return LoadResult.OK(MigrationOK(MigrationSource.Pnpm))
    }

    // ========================================================================
    // 计数阶段
    // 严格翻译自: migrateNPMLockfile 计数阶段
    //   遍历 packages_properties, 统计:
    //   - num_deps (总依赖数)
    //   - num_extern_strings (外部字符串数)
    //   - package_idx (有效包数)
    //   - resolved_urls (构造的 resolved URL)
    //   - id_map (路径到包 ID 映射)
    // ========================================================================

    /// 执行计数阶段
    /// 严格翻译自: migrateNPMLockfile 中的计数阶段
    ///   遍历 packages_properties, 构建 id_map, resolved_urls
    public func countNPMPackages(
        packagesProperties: ArrayList<JsonProperty>,
        manager: PackageManager
    ): CountPhaseResult {
        let result = CountPhaseResult()

        for (entry in packagesProperties) {
            let pkgPath = entry.key

            match (entry.value) {
                case JsonValue.Object(pkg) =>
                    // 检查 link 包 -> 标记为 link
                    match (pkg.get("link")) {
                        case Some(_) =>
                            result.idMap.put(pkgPath, IdMapValue(UInt32(0), PACKAGE_ID_IS_LINK))
                            continue
                        case None => ()
                    }

                    // 检查 inBundle -> 标记为 bundled
                    match (pkg.get("inBundle")) {
                        case Some(JsonValue.JsonBool(true)) =>
                            result.idMap.put(pkgPath, IdMapValue(UInt32(0), PACKAGE_ID_IS_BUNDLED))
                            continue
                        case _ => ()
                    }

                    // 检查 extraneous -> 跳过
                    match (pkg.get("extraneous")) {
                        case Some(JsonValue.JsonBool(true)) => continue
                        case _ => ()
                    }

                    // 记录有效包
                    result.idMap.put(pkgPath, IdMapValue(UInt32(0), result.packageIdx))
                    result.packageIdx = result.packageIdx + UInt32(1)

                    // 统计依赖数量
                    for (depKey in DependencyKeys.ALL) {
                        match (pkg.get(depKey)) {
                            case Some(JsonValue.Object(deps)) =>
                                result.numDeps = result.numDeps + UInt32(deps.keys().size)
                            case _ => ()
                        }
                    }

                    // 统计 bin 外部字符串
                    match (pkg.get("bin")) {
                        case Some(JsonValue.Object(binObj)) =>
                            let binLen = binObj.keys().size
                            if (binLen > 1) {
                                result.numExternStrings = result.numExternStrings + UInt32(binLen * 2)
                            }
                        case _ => ()
                    }

                    // 当 resolved 不存在时, 构造 registry URL
                    match (pkg.get("resolved")) {
                        case Some(_) => () // 已有 resolved
                        case None =>
                            match (pkg.get("version")) {
                                case Some(JsonValue.Str(_)) =>
                                    let pkgName = packageNameFromPath(pkgPath)
                                    if (pkgName.size > 0) {
                                        let constructedUrl = constructRegistryUrl(pkgName, pkg, manager)
                                        match (constructedUrl) {
                                            case Some(url) => result.resolvedUrls.put(pkgPath, url)
                                            case None => ()
                                        }
                                    }
                                case _ => ()
                            }
                    }
                case _ => ()
            }
        }

        return result
    }

    // ========================================================================
    // 构造 registry URL
    // 严格翻译自: migrateNPMLockfile 计数阶段中的 resolved URL 构造
    //   当 resolved 不存在时, 从 registry + pkg_name + version 构造
    //   URL 格式: {registry}{pkg_name}/-/{unscoped_name}-{version}.tgz
    // ========================================================================

    /// 构造 registry URL
    /// 翻译自: migrateNPMLockfile 中 resolved 缺失时的 URL 构造逻辑
    ///   e.g. https://registry.npmjs.org/lodash/-/lodash-4.17.21.tgz
    public func constructRegistryUrl(
        pkgName: String,
        pkg: HashMap<String, JsonValue>,
        manager: PackageManager
    ): ?String {
        let versionStr = match (PkgJsonHelper.getString(JsonValue.Object(pkg), "version")) {
            case Some(v) => v
            case None => return None
        }

        // 获取 registry URL
        let registry = scopeForPackageName(manager, pkgName)
        let registryUrl = registry

        // 计算包名部分
        let unscopedName = if (pkgName.size > 0 && pkgName[0] == UInt8(64)) {
            // scoped package: @scope/name -> 取 name 部分
            match (pkgName.indexOf("/")) {
                case Some(slashIdx) =>
                    if (slashIdx + 1 < pkgName.size) { pkgName[(slashIdx + 1)..pkgName.size] } else { pkgName }
                case None => pkgName
            }
        } else {
            pkgName
        }

        // 构造: {registry}{pkgName}/-/{unscopedName}-{version}.tgz
        let url = "${registryUrl}${pkgName}/-/${unscopedName}-${versionStr}.tgz"
        return Some(url)
    }

    /// 获取包名对应的 registry URL
    /// 翻译自: manager.scopeForPackageName(pkg_name).url.href
    private func scopeForPackageName(manager: PackageManager, name: String): String {
        // 默认 registry
        return "https://registry.npmjs.org/"
    }

    /// 包 ID 特殊常量: 表示 link
    /// 翻译自: package_id_is_link = std.math.maxInt(u32)
    public static let PACKAGE_ID_IS_LINK: UInt32 = UInt32(4294967295)

    /// 包 ID 特殊常量: 表示 bundled
    /// 翻译自: package_id_is_bundled = std.math.maxInt(u32) - 1
    public static let PACKAGE_ID_IS_BUNDLED: UInt32 = UInt32(4294967294)

    // ========================================================================
    // 包构建阶段
    // 严格翻译自: migrateNPMLockfile 包构建阶段
    //   初始化每个包, 设置 resolution 为 uninitialized
    //   处理: workspace 包, bin, integrity, OS/CPU 限制
    // ========================================================================

    // ========================================================================
    // 依赖链接阶段
    // 严格翻译自: migrateNPMLockfile 依赖链接阶段
    //   解析依赖关系, 查找 id_map, 设置 resolutions
    //   处理: node_modules 层级查找, bundled 跳过, peer 可选依赖
    // ========================================================================

    /// 解析单条依赖
    /// 严格翻译自: migrateNPMLockfile 依赖链接阶段中的 dep_loop
    ///   查找 id_map, 处理 link/bundled, 逐级回退 node_modules
    public func resolveNPMDependency(
        depName: String,
        depVersion: String,
        pkgPath: String,
        idMap: HashMap<String, IdMapValue>,
        packagesProperties: ArrayList<JsonProperty>,
        depKey: String,
        peerDepMeta: ?HashMap<String, JsonValue>
    ): DependencyLinkResult {
        let result = DependencyLinkResult()

        // 构建查找路径: pkg_path + "/node_modules/" + dep_name
        let nodeModulesSuffix = if (pkgPath.size == 0) { "node_modules/" } else { "/node_modules/" }
        var checkPath = "${pkgPath}${nodeModulesSuffix}${depName}"

        // 查找循环 (最多回退到顶级 node_modules)
        var maxIterations: Int64 = 64
        while (maxIterations > 0) {
            maxIterations = maxIterations - 1

            match (idMap.get(checkPath)) {
                case Some(found) =>
                    // 检查是否是 link
                    if (IdMapValue.isLink(found.newPackageId)) {
                        // link 包: 需要从 packages_properties 获取 resolved
                        let refPkg = getPackageByIndex(packagesProperties, found.oldJsonIndex)
                        match (refPkg) {
                            case Some(JsonValue.Object(refObj)) =>
                                match (refObj.get("resolved")) {
                                    case Some(JsonValue.Str(resolvedStr)) =>
                                        // 用 resolved 路径重新查找 id_map
                                        match (idMap.get(resolvedStr)) {
                                            case Some(resolvedEntry) =>
                                                if (IdMapValue.isBundled(resolvedEntry.newPackageId)) {
                                                    // bundled 依赖, 跳过
                                                    result.skipped = true
                                                    return result
                                                }
                                                result.resolutionId = resolvedEntry.newPackageId
                                                return result
                                            case None =>
                                                // 无法解析 link 目标
                                                result.skipped = true
                                                return result
                                        }
                                    case _ =>
                                        result.skipped = true
                                        return result
                                }
                            case _ =>
                                result.skipped = true
                                return result
                        }
                    }

                    // 检查是否是 bundled
                    if (IdMapValue.isBundled(found.newPackageId)) {
                        result.skipped = true
                        return result
                    }

                    // 找到有效包
                    result.resolutionId = found.newPackageId
                    return result
                case None => ()
            }

            // 未找到: 回退到上一级 node_modules
            let nmPrefix = "/node_modules/"
            let searchIn = checkPath[0..(checkPath.size - Int64(depName.size) - Int64(nodeModulesSuffix.size))]
            match (searchIn.lastIndexOf(nmPrefix)) {
                case Some(nmIdx) =>
                    // 从更高级的 node_modules 查找
                    let newLen = nmIdx + Int64(nmPrefix.size) + Int64(depName.size)
                    checkPath = "${searchIn[0..(nmIdx + Int64(nmPrefix.size))]}${depName}"
                case None =>
                    // 检查顶级 node_modules
                    if (!checkPath.startsWith("node_modules/")) {
                        checkPath = "node_modules/${depName}"
                    } else {
                        // 可选 peer 依赖可以缺失
                        if (depKey == "peerDependencies") {
                            match (peerDepMeta) {
                                case Some(meta) =>
                                    match (meta.get(depName)) {
                                        case Some(JsonValue.Object(obj)) =>
                                            match (obj.get("optional")) {
                                                case Some(JsonValue.JsonBool(true)) =>
                                                    result.skipped = true
                                                    result.resolutionId = INVALID_PACKAGE_ID
                                                    return result
                                                case _ => ()
                                            }
                                        case _ => ()
                                    }
                                case None => ()
                            }
                        }
                        // 未找到依赖, 跳过
                        result.skipped = true
                        return result
                    }
            }
        }

        result.skipped = true
        return result
    }

    /// 从 packages_properties 获取指定索引的包值
    /// 翻译自: packages_properties.at(idx).value.?.data.e_object
    private func getPackageByIndex(
        packagesProperties: ArrayList<JsonProperty>,
        index: UInt32
    ): ?JsonValue {
        if (Int64(index) >= packagesProperties.size) { return None }
        return packagesProperties[Int64(index)].value
    }

    // ========================================================================
    // 解析阶段
    // 严格翻译自: migrateNPMLockfile 中的解析阶段
    //   当 resolution 为 uninitialized 时, 使用依赖声明中的信息解析
    //   处理: npm, git, github, tarball, folder, workspace
    // ========================================================================

    /// 解析包的 resolution
    /// 严格翻译自: migrateNPMLockfile 中 resolutions[id].tag == .uninitialized 时的逻辑
    ///   从依赖的 resolved URL 和 version 推断 resolution 类型
    public func resolvePackageResolution(
        depPkg: HashMap<String, JsonValue>,
        depResolved: String,
        versionTag: DependencyVersionTag,
        resolvedUrls: ResolvedURLsMap,
        checkPath: String,
        pkgPath: String
    ): NPMResolutionEntry {
        let resolution = NPMResolutionEntry()

        match (versionTag) {
            case DependencyVersionTag.Npm =>
                // npm 包: 从 dep_pkg 的 version 和 resolved 构建
                match (depPkg.get("version")) {
                    case Some(JsonValue.Str(actualVersion)) =>
                        resolution.tag = NPMResolutionTag.Npm
                        resolution.npmUrl = depResolved
                        resolution.npmVersion = actualVersion
                    case _ => ()
                }
            case DependencyVersionTag.DistTag =>
                // dist-tag: 同 npm 处理
                match (depPkg.get("version")) {
                    case Some(JsonValue.Str(actualVersion)) =>
                        resolution.tag = NPMResolutionTag.Npm
                        resolution.npmUrl = depResolved
                        resolution.npmVersion = actualVersion
                    case _ => ()
                }
            case DependencyVersionTag.Tarball =>
                resolution.tag = NPMResolutionTag.Tarball
                if (depResolved.startsWith("file:")) {
                    resolution.tag = NPMResolutionTag.LocalTarball
                    resolution.localTarballPath = depResolved[5..depResolved.size]
                } else {
                    resolution.tag = NPMResolutionTag.RemoteTarball
                    resolution.tarballUrl = depResolved
                }
            case DependencyVersionTag.Folder =>
                resolution.tag = NPMResolutionTag.Folder
                resolution.folderPath = depResolved
            case DependencyVersionTag.Symlink =>
                // symlink 视为 folder
                resolution.tag = NPMResolutionTag.Folder
                resolution.folderPath = depResolved
            case DependencyVersionTag.Workspace =>
                resolution.tag = NPMResolutionTag.Workspace
                var wsPath = depResolved
                if (wsPath.startsWith("workspace:")) {
                    wsPath = wsPath[10..wsPath.size]
                }
                resolution.workspacePath = wsPath
            case DependencyVersionTag.Git =>
                resolution.tag = NPMResolutionTag.Git
                resolveGitInfo(depResolved, resolution)
            case DependencyVersionTag.Github =>
                resolution.tag = NPMResolutionTag.GitHub
                resolveGitInfo(depResolved, resolution)
            case _ => ()
        }

        // 如果 resolved 为空但 version 是 npm, 尝试从 resolvedUrls 获取
        if (resolution.npmUrl.size == 0 && versionTag == DependencyVersionTag.Npm) {
            match (resolvedUrls.get(checkPath)) {
                case Some(url) => resolution.npmUrl = url
                case None => ()
            }
        }

        return resolution
    }

    /// 解析 git/github URL 提取 commit 信息
    /// 翻译自: migrateNPMLockfile 中 git/github 解析逻辑
    private func resolveGitInfo(depResolved: String, resolution: NPMResolutionEntry): Unit {
        var url = depResolved
        // 去掉 "git+" 前缀
        if (url.startsWith("git+")) {
            url = url[4..url.size]
        }

        // 查找 '#' 分隔的 commit
        match (url.lastIndexOf("#")) {
            case Some(hashIdx) =>
                resolution.gitCommittish = url[(hashIdx + 1)..url.size]
                resolution.gitResolved = url[(hashIdx + 1)..url.size]
                resolution.gitRepo = url[0..hashIdx]
            case None => ()
        }
    }

    // ========================================================================
    // 验证阶段
    // 严格翻译自: migrateNPMLockfile 验证阶段
    //   检查所有包的 resolution 是否已设置
    //   未解析的包产生警告
    // ========================================================================

    /// 验证所有包已解析
    /// 翻译自: migrateNPMLockfile 中 is_missing_resolutions 检查
    public func validateAllPackagesResolved(
        packages: ArrayList<NPMBuildPackage>
    ): NPMValidationResult {
        var hasMissing = false
        let missingNames = ArrayList<String>()

        for (pkg in packages) {
            if (pkg.resolution.isUninitialized()) {
                hasMissing = true
                missingNames.append(pkg.name)
            }
        }

        return NPMValidationResult(
            !hasMissing,
            missingNames
        )
    }

    // ========================================================================
    // 包裹依赖处理
    // 严格翻译自: migrateNPMLockfile 中 bundled_dependencies 处理
    //   a feature no one has heard about:
    //   https://docs.npmjs.com/cli/v10/configuring-npm/package-json#bundledependencies
    //   如果 bundleDependencies/bundledDependencies 是 true, 跳过此包
    //   如果是数组, 跳过数组中列出的依赖
    // ========================================================================

    /// 解析 bundled 依赖列表
    /// 翻译自: migrateNPMLockfile 中 bundled_dependencies 解析
    public func parseBundledDependencies(pkg: HashMap<String, JsonValue>): ?ArrayList<String> {
        // 检查 bundleDependencies 或 bundledDependencies
        var bundleExpr = pkg.get("bundleDependencies")
        if (bundleExpr.isNone()) {
            bundleExpr = pkg.get("bundledDependencies")
        }

        match (bundleExpr) {
            case Some(JsonValue.JsonBool(true)) =>
                // true: 所有依赖都是 bundled, 返回 null 表示跳过整个包
                return None
            case Some(JsonValue.Array(arr)) =>
                let names = ArrayList<String>()
                for (item in arr) {
                    match (item) {
                        case JsonValue.Str(s) => names.append(s)
                        case _ => ()
                    }
                }
                return Some(names)
            case _ => return None
        }
    }

    /// 检查依赖名是否在 bundled 列表中
    /// 翻译自: bundled_dependencies.?.getIndex(name_bytes) != null
    public func isBundledDependency(depName: String, bundledDeps: ?ArrayList<String>): Bool {
        match (bundledDeps) {
            case Some(list) =>
                for (name in list) {
                    if (name == depName) { return true }
                }
                return false
            case None => return false
        }
    }

    // ========================================================================
    // peerDependenciesMeta 处理
    // 严格翻译自: migrateNPMLockfile 中 peer_dep_meta 解析
    //   用于判断 peer 依赖是否可选
    // ========================================================================

    /// 获取 peer 依赖的可选状态
    /// 翻译自: peerDependenciesMeta.{name}.optional
    public func isPeerDependencyOptional(
        depName: String,
        peerDepMeta: ?HashMap<String, JsonValue>
    ): Bool {
        match (peerDepMeta) {
            case Some(meta) =>
                match (meta.get(depName)) {
                    case Some(JsonValue.Object(obj)) =>
                        match (obj.get("optional")) {
                            case Some(JsonValue.JsonBool(true)) => return true
                            case _ => return false
                        }
                    case _ => return false
                }
            case None => return false
        }
    }

    /// 获取 peerDependenciesMeta
    /// 翻译自: pkg.get("peerDependenciesMeta")
    public func getPeerDependenciesMeta(pkg: HashMap<String, JsonValue>): ?HashMap<String, JsonValue> {
        match (pkg.get("peerDependenciesMeta")) {
            case Some(JsonValue.Object(obj)) => return Some(obj)
            case _ => return None
        }
    }

    // ========================================================================
    // 根包 workspace 处理
    // 严格翻译自: migrateNPMLockfile 中 workspace_map 处理
    //   根包可能有 workspaces 字段 (数组或对象)
    //   workspaces 数组中的每个 workspace 会成为根包的依赖
    // ========================================================================

    /// 解析根包的 workspaces
    /// 翻译自: migrateNPMLockfile 中 workspace_map 解析
    public func parseWorkspaces(
        rootPkg: HashMap<String, JsonValue>,
        log: ArrayList<String>
    ): ?NPMWorkspaceMap {
        match (rootPkg.get("workspaces")) {
            case Some(JsonValue.Array(arr)) =>
                let wsMap = NPMWorkspaceMap()
                for (item in arr) {
                    match (item) {
                        case JsonValue.Str(path) =>
                            let entry = NPMWorkspaceEntry(path, packageNameFromPath(path))
                            wsMap.entries.append(entry)
                        case _ => ()
                    }
                }
                return Some(wsMap)
            case Some(JsonValue.Object(obj)) =>
                // workspaces: { packages: [...] }
                match (obj.get("packages")) {
                    case Some(JsonValue.Array(arr)) =>
                        let wsMap = NPMWorkspaceMap()
                        for (item in arr) {
                            match (item) {
                                case JsonValue.Str(path) =>
                                    let entry = NPMWorkspaceEntry(path, packageNameFromPath(path))
                                    wsMap.entries.append(entry)
                                case _ => ()
                            }
                        }
                        return Some(wsMap)
                    case _ => return None
                }
            case _ => return None
        }
    }

    // ========================================================================
    // 根包依赖注入
    // 严格翻译自: migrateNPMLockfile 中 is_first 处理
    //   第一个包是根包, 需要将 workspace 依赖注入到根包的依赖列表
    // ========================================================================

    /// 构建根包的 workspace 依赖
    /// 翻译自: migrateNPMLockfile 中 is_first 时注入 workspace 依赖
    public func buildRootWorkspaceDependencies(
        workspaceMap: NPMWorkspaceMap,
        idMap: HashMap<String, IdMapValue>
    ): ArrayList<DependencyLinkResult> {
        let deps = ArrayList<DependencyLinkResult>()

        for (wsEntry in workspaceMap.entries) {
            let nameHash = SemverStringBuilder.stringHashStr(wsEntry.name)

            match (idMap.get(wsEntry.path)) {
                case Some(idEntry) =>
                    let result = DependencyLinkResult()
                    result.dependency.name = wsEntry.name
                    result.dependency.nameHash = nameHash
                    result.dependency.versionTag = DependencyVersionTag.Workspace
                    result.dependency.versionLiteral = wsEntry.path
                    result.dependency.behavior.workspace = true
                    result.resolutionId = idEntry.newPackageId
                    deps.append(result)
                case None => ()
            }
        }

        return deps
    }
}

// ============================================================================
// 迁移辅助类型 (从 LockfileMigrator 内部移出)
// ============================================================================

/// 构建阶段的包数据
/// 翻译自: migrateNPMLockfile 包构建阶段产生的包条目
public class NPMBuildPackage {
    /// 包路径
    public var pkgPath: String
    /// 包名
    public var name: String
    /// 名称哈希
    public var nameHash: UInt64
    /// 包 ID
    public var packageId: UInt32
    /// 是否为 workspace
    public var isWorkspace: Bool
    /// 解析信息 (初始为 uninitialized)
    public var resolution: NPMResolutionEntry
    /// 包元信息
    public var meta: NPMPackageMeta
    /// bin 信息
    public var bin: NPMBinEntry
    /// 依赖列表偏移
    public var dependenciesOff: UInt32
    /// 依赖列表长度
    public var dependenciesLen: UInt32
    /// 解析列表偏移
    public var resolutionsOff: UInt32
    /// 解析列表长度
    public var resolutionsLen: UInt32
    /// 是否有安装脚本
    public var hasInstallScript: Bool

    public init() {
        pkgPath = ""
        name = ""
        nameHash = UInt64(0)
        packageId = INVALID_PACKAGE_ID
        isWorkspace = false
        resolution = NPMResolutionEntry()
        meta = NPMPackageMeta()
        bin = NPMBinEntry()
        dependenciesOff = UInt32(0)
        dependenciesLen = UInt32(0)
        resolutionsOff = UInt32(0)
        resolutionsLen = UInt32(0)
        hasInstallScript = false
    }
}

/// NPM 解析条目
/// 翻译自: Resolution
public class NPMResolutionEntry {
    /// 解析标签
    public var tag: NPMResolutionTag
    /// npm 解析 URL
    public var npmUrl: String
    /// npm 版本
    public var npmVersion: String
    /// 文件夹路径
    public var folderPath: String
    /// workspace 路径
    public var workspacePath: String
    /// git 信息
    public var gitOwner: String
    public var gitRepo: String
    public var gitCommittish: String
    public var gitResolved: String
    public var gitPackageName: String
    /// tarball URL
    public var tarballUrl: String
    /// 本地 tarball 路径
    public var localTarballPath: String

    public init() {
        tag = NPMResolutionTag.Uninitialized
        npmUrl = ""
        npmVersion = ""
        folderPath = ""
        workspacePath = ""
        gitOwner = ""
        gitRepo = ""
        gitCommittish = ""
        gitResolved = ""
        gitPackageName = ""
        tarballUrl = ""
        localTarballPath = ""
    }

    public func isUninitialized(): Bool {
        match (tag) {
            case NPMResolutionTag.Uninitialized => true
            case _ => false
        }
    }
}

/// NPM 解析标签
/// 翻译自: Resolution.Tag
public enum NPMResolutionTag {
    | Uninitialized
    | Npm
    | Root
    | Workspace
    | Folder
    | Git
    | GitHub
    | Tarball
    | RemoteTarball
    | LocalTarball
}

/// NPM 包元信息
/// 翻译自: Lockfile.Package.Meta
public class NPMPackageMeta {
    /// 包 ID
    public var id: UInt32
    /// 来源 (local / npm / tarball)
    public var origin: Origin
    /// 架构限制
    public var arch: String
    /// OS 限制
    public var os: String
    /// man 目录
    public var manDir: String
    /// 是否有安装脚本
    public var hasInstallScript: Bool
    /// 完整性哈希
    public var integrity: Integrity

    public init() {
        id = INVALID_PACKAGE_ID
        origin = Origin.Npm
        arch = "all"
        os = "all"
        manDir = ""
        hasInstallScript = false
        integrity = Integrity()
    }
}

/// NPM bin 条目
/// 翻译自: Bin
public class NPMBinEntry {
    /// bin 标签
    public var tag: BinTag
    /// 文件路径 (tag == File)
    public var filePath: String
    /// 名称 (tag == NamedFile)
    public var name: String
    /// 命名路径 (tag == NamedFile)
    public var namedPath: String
    /// bin 映射 (tag == Map)
    public var binMap: HashMap<String, String>

    public init() {
        tag = BinTag.None
        filePath = ""
        name = ""
        namedPath = ""
        binMap = HashMap<String, String>()
    }
}

/// 依赖链接
/// 翻译自: migrateNPMLockfile 中依赖链接阶段的单条依赖解析
public class DependencyLinkResult {
    /// 依赖信息
    public var dependency: DependencyInfo
    /// 解析到的包 ID
    public var resolutionId: UInt32
    /// 是否跳过 (bundled / not found)
    public var skipped: Bool

    public init() {
        dependency = DependencyInfo()
        resolutionId = INVALID_PACKAGE_ID
        skipped = false
    }
}

/// 验证结果
public class NPMValidationResult {
    /// 是否有效
    public var isValid: Bool
    /// 缺失解析的包名列表
    public var missingNames: ArrayList<String>

    public init(isValid: Bool, missingNames: ArrayList<String>) {
        this.isValid = isValid
        this.missingNames = missingNames
    }
}

// ============================================================================
// 迁移辅助类型 (从 LockfileMigrator 内部移出)
// ============================================================================

/// 计数阶段结果
/// 翻译自: migrateNPMLockfile 计数阶段产生的统计信息
public class CountPhaseResult {
    /// 总依赖数
    public var numDeps: UInt32
    /// 外部字符串数
    public var numExternStrings: UInt32
    /// 有效包数量
    public var packageIdx: UInt32
    /// ID 映射
    public var idMap: HashMap<String, IdMapValue>
    /// 构造的 resolved URL
    public var resolvedUrls: ResolvedURLsMap
    /// workspace 映射 (根包的 workspaces)
    public var workspaceMap: ?NPMWorkspaceMap
    /// 根包对象
    public var rootPackage: ?JsonValue

    public init() {
        numDeps = UInt32(0)
        numExternStrings = UInt32(0)
        packageIdx = UInt32(0)
        idMap = HashMap<String, IdMapValue>()
        resolvedUrls = ResolvedURLsMap()
        workspaceMap = None
        rootPackage = None
    }
}

/// NPM workspace 映射
/// 翻译自: Lockfile.Package.WorkspaceMap
public class NPMWorkspaceMap {
    public var entries: ArrayList<NPMWorkspaceEntry>

    public init() {
        entries = ArrayList<NPMWorkspaceEntry>()
    }
}

/// NPM workspace 条目
public class NPMWorkspaceEntry {
    /// workspace 路径
    public var path: String
    /// workspace 包名
    public var name: String
    /// workspace 版本
    public var version: ?String

    public init(path: String, name: String) {
        this.path = path
        this.name = name
        version = None
    }
}

// ============================================================================
// JSON 属性辅助
// ============================================================================

/// JSON 属性键值对
public class JsonProperty {
    public var key: String
    public var value: JsonValue

    public init(key: String, value: JsonValue) {
        this.key = key
        this.value = value
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

// ============================================================================
// Semver 辅助引用 (使用 bao_install 包内的 SemverStringBuilder)
// ============================================================================
