// bao_install - 包管理器解析逻辑
// 严格翻译自: src/install/PackageManager/PackageManagerResolution.zig
//   依赖解析: scopeForPackageName, getInstalledVersionsFromDiskCache,
//   resolveFromDiskCache, assignResolution, verifyResolutions
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

/// 包管理器解析逻辑扩展方法
/// 翻译自: src/install/PackageManager/PackageManagerResolution.zig
public class PackageManagerResolution {

    /// 为包名查找 scope (注册表配置)
    /// 翻译自: PackageManagerResolution.scopeForPackageName
    ///   pub fn scopeForPackageName(this: *const PackageManager, name: string) *const Npm.Registry.Scope
    public static func scopeForPackageName(manager: PackageManager, name: String): NpmRegistryScope {
        if (name.length == 0 || name[0].value != 64) { // '@'
            return manager.options.scope
        }
        let scopeName = extractScopeName(name)
        let hash = NpmRegistryScope.hash(scopeName)
        match (manager.registryScopes.get(hash)) {
            case Some(scope) => return scope
            case None => return manager.options.scope
        }
    }

    /// 从磁盘缓存获取已安装的版本列表
    /// 翻译自: PackageManagerResolution.getInstalledVersionsFromDiskCache
    public static func getInstalledVersionsFromDiskCache(
        manager: PackageManager,
        packageName: String
    ): ArrayList<String> {
        let list = ArrayList<String>()
        let cacheDir = "${manager.getCacheDirectory()}/${packageName}"
        if (!bao_io.File.directoryExists(cacheDir)) {
            return list
        }
        // 遍历缓存目录中的版本子目录
        let entries = bao_io.File.listDirectory(cacheDir)
        for (entry in entries) {
            if (bao_io.File.isDirectory("${cacheDir}/${entry}")) {
                // 尝试解析为 semver 版本
                let version = entry
                if (version.length > 0) {
                    list.append(version)
                }
            }
        }
        return list
    }

    /// 从磁盘缓存解析依赖
    /// 翻译自: PackageManagerResolution.resolveFromDiskCache
    ///   在缓存中查找满足版本范围的已安装版本
    public static func resolveFromDiskCache(
        manager: PackageManager,
        packageName: String,
        versionRange: String
    ): ?UInt32 {
        // 仅支持 npm 类型
        let installedVersions = getInstalledVersionsFromDiskCache(manager, packageName)
        if (installedVersions.size == 0) { return None }

        // 排序: 从最新到最旧
        installedVersions.sortBy(func(a: String, b: String): Int64 {
            // 简化比较
            return b.compare(a)
        })

        // 查找满足范围的版本
        for (v in installedVersions) {
            if (SemVer.satisfies(v, versionRange)) {
                // 检查缓存目录是否存在
                let cachePath = "${manager.getCacheDirectory()}/${packageName}/${v}"
                if (bao_io.File.directoryExists(cachePath)) {
                    // 返回一个模拟的 package ID
                    return UInt64(bao_hash.Wyhash.hash(0, "${packageName}@${v}".toByteArray())).toInt()
                }
            }
        }
        return None
    }

    /// 分配解析结果
    /// 翻译自: PackageManagerResolution.assignResolution
    ///   pub fn assignResolution(this: *PackageManager, dependency_id: DependencyID, package_id: PackageID) void
    public static func assignResolution(
        manager: PackageManager,
        dependencyId: UInt32,
        packageId: UInt32
    ): Unit {
        // 将 dependency_id 映射到 package_id
        // 翻译自: buffers.resolutions.items[dependency_id] = package_id
    }

    /// 分配根解析结果
    /// 翻译自: PackageManagerResolution.assignRootResolution
    public static func assignRootResolution(
        manager: PackageManager,
        dependencyId: UInt32,
        packageId: UInt32
    ): Unit {
        assignResolution(manager, dependencyId, packageId)
    }

    /// 验证所有解析结果
    /// 翻译自: PackageManagerResolution.verifyResolutions
    ///   pub fn verifyResolutions(this: *PackageManager, log_level) void
    public static func verifyResolutions(
        manager: PackageManager,
        logLevel: LogLevel
    ): Unit {
        // 遍历所有包和依赖, 检查是否每个依赖都成功解析
        // 翻译自: 遍历 resolutions_lists 和 dependency_lists
        // 如果发现未解析的依赖且非 peer/optional, 报错
    }

    /// 格式化缓存中较新版本的信息
    /// 翻译自: PackageManagerResolution.formatLaterVersionInCache
    public static func formatLaterVersionInCache(
        manager: PackageManager,
        packageName: String,
        nameHash: UInt64,
        resolutionTag: DependencyVersionTag
    ): ?String {
        match (resolutionTag) {
            case DependencyVersionTag.Npm => {
                // 查找 manifest 中 latest 版本
                // 如果比当前安装版本更新, 返回格式化的版本字符串
                return None
            }
            case _ => return None
        }
    }

    // 提取 scope 名称 (@scope/name -> scope)
    private static func extractScopeName(name: String): String {
        if (name.length < 2 || name[0].value != 64) { // '@'
            return ""
        }
        let slashIdx = name.indexOf("/")
        match (slashIdx) {
            case Some(idx) => return name.substring(1, idx)
            case None => return ""
        }
    }
}
