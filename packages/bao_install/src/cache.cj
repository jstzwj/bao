// bao_install - 包缓存
// 严格翻译自: src/install/isolated_install/Store.zig, src/install/extract_tarball.zig
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 缓存元数据
// 严格翻译自: src/install/isolated_install/Store.zig - Store.Entry
//   Bun 的 Store 维护全局缓存, 每个包版本对应一个缓存条目
//   路径格式: ~/.bun/install/cache/{name}@{version}/
//   翻译自: Store.Entry 包含 id, resolution, integrity, file_count, etc.
// ============================================================================

/// 缓存条目元数据
/// 对应 Bun: Store.Entry
public class CacheEntry {
    /// 包名
    public let name: String
    /// 版本
    public let version: String
    /// 完整性哈希
    public var integrity: String
    /// 缓存路径 (解压后的包目录)
    public var cachePath: String
    /// tarball 路径
    public var tarballPath: String
    /// 是否已解压
    public var extracted: Bool
    /// 包大小 (字节)
    public var size: Int64
    /// 文件数量
    public var fileCount: Int64
    /// 缓存创建时间戳
    public var createdTimestamp: Int64
    /// 最后访问时间戳 (用于 LRU)
    public var lastAccessTimestamp: Int64
    /// 访问次数
    public var accessCount: Int64

    public init(name: String, version: String) {
        this.name = name
        this.version = version
        integrity = ""
        cachePath = ""
        tarballPath = ""
        extracted = false
        size = 0
        fileCount = 0
        createdTimestamp = bao_sys.SysModule.currentTimeMillis()
        lastAccessTimestamp = createdTimestamp
        accessCount = 0
    }

    /// 缓存键 name@version
    public func key(): String {
        return "${name}@${version}"
    }

    /// 格式化存储名称 (将 / 替换为 +)
    /// 对应 Bun: StorePathFormatter
    /// 翻译自: isolated_install 中包名到缓存路径的转换
    public func storeName(): String {
        // scoped packages: @foo/bar -> @foo+bar
        return name.replace("/", "+")
    }

    /// 更新访问时间
    public func touch(): Unit {
        lastAccessTimestamp = bao_sys.SysModule.currentTimeMillis()
        accessCount += 1
    }
}

/// 缓存元数据索引
/// 对应 Bun: Store 的内存索引
public class CacheMetadata {
    /// name@version -> CacheEntry
    private var entries: HashMap<String, CacheEntry>
    /// 总缓存大小
    private var totalSize: Int64

    public init() {
        entries = HashMap<String, CacheEntry>()
        totalSize = 0
    }

    /// 添加条目
    public func put(entry: CacheEntry): Unit {
        match (entries.get(entry.key())) {
            case Some(old) => totalSize -= old.size
            case None => {}
        }
        entries.put(entry.key(), entry)
        totalSize += entry.size
    }

    /// 获取条目 (同时更新访问时间)
    public func get(key: String): ?CacheEntry {
        let entry = entries.get(key)
        match (entry) {
            case Some(e) => {
                e.touch()
                return Some(e)
            }
            case None => return None
        }
    }

    /// 获取条目 (不更新访问时间)
    public func peek(key: String): ?CacheEntry {
        return entries.get(key)
    }

    /// 移除条目
    public func remove(key: String): ?CacheEntry {
        let entry = entries.get(key)
        match (entry) {
            case Some(e) => {
                totalSize -= e.size
                entries.remove(key)
                return Some(e)
            }
            case None => return None
        }
    }

    /// 缓存条目数
    public prop size: Int64 {
        get() { entries.size }
    }

    /// 总缓存大小
    public func getTotalSize(): Int64 {
        return totalSize
    }

    /// 所有条目
    public func allEntries(): ArrayList<CacheEntry> {
        let result = ArrayList<CacheEntry>()
        for (key in entries.keys()) {
            match (entries.get(key)) {
                case Some(e) => result.append(e)
                case None => {}
            }
        }
        return result
    }

    /// 按 LRU 顺序排序 (最旧的在前)
    public func entriesByLRU(): ArrayList<CacheEntry> {
        let result = allEntries()
        result.sortBy(func(a: CacheEntry, b: CacheEntry): Int64 {
            return a.lastAccessTimestamp - b.lastAccessTimestamp
        })
        return result
    }
}

// ============================================================================
// 包缓存管理器
// 严格翻译自: src/install/isolated_install/Store.zig
//   Bun 维护全局缓存目录 (~/.bun/install/cache/)
//   使用硬链接安装到 node_modules 以节省磁盘空间
//
// 关键翻译来源:
//   - Store.installPackageFromTarball: 安装包到缓存
//   - Store.allocatePackage: 分配缓存空间
//   - Hardlinker.hardlinkFiles: 硬链接安装
//   - Symlinker: 符号链接安装
//   - Store 的路径格式: ~/.bun/install/cache/{name}@{version}/
// ============================================================================

/// 包缓存管理器
/// 对应 Bun: Store (全局包缓存)
public class PackageCache {
    /// 缓存根目录
    /// 对应 Bun: bun.pm.getCacheDirectory() -> ~/.bun/install/cache/
    private var cacheDir: String
    /// 元数据索引
    private var metadata: CacheMetadata
    /// 元数据文件路径
    private var metadataPath: String
    /// 完整性验证器
    private var integrityVerifier: IntegrityVerifier

    /// 默认缓存子目录
    /// 翻译自: Bun 的缓存路径格式
    private static let CACHE_SUBDIR: String = ".bao/install/cache"

    public init() {
        let home = bao_sys.SysModule.getEnv("HOME").getOrElse(() => "/tmp")
        cacheDir = bao_path.PathModule.join(ArrayList<String>([home, CACHE_SUBDIR]))
        metadata = CacheMetadata()
        metadataPath = bao_path.PathModule.join(ArrayList<String>([cacheDir, "_metadata.json"]))
        integrityVerifier = IntegrityVerifier()
        ensureCacheDir()
        loadMetadata()
    }

    public init(cacheDir: String) {
        this.cacheDir = cacheDir
        metadata = CacheMetadata()
        metadataPath = bao_path.PathModule.join(ArrayList<String>([cacheDir, "_metadata.json"]))
        integrityVerifier = IntegrityVerifier()
        ensureCacheDir()
        loadMetadata()
    }

    /// 获取缓存目录
    public func getCacheDir(): String {
        return cacheDir
    }

    // ========================================================================
    // 存储包到缓存
    // 严格翻译自: src/install/isolated_install/Store.zig installPackageFromTarball
    //   1. 验证完整性
    //   2. 创建缓存目录
    //   3. 保存 tarball
    //   4. 解压到缓存目录
    //   5. 更新元数据
    // ========================================================================

    /// 存储包到缓存
    /// 对应 Bun: Store.installPackageFromTarball
    public func storePackage(
        name: String,
        version: String,
        tarballData: Array<UInt8>,
        integrity: String
    ): ?CacheEntry {
        // 验证完整性
        if (integrity.length > 0) {
            if (!integrityVerifier.verify(tarballData, integrity)) {
                return None
            }
        }

        // 创建缓存目录
        let entryDir = getEntryDir(name, version)
        BaoFile.mkdir(entryDir, true)

        // 保存 tarball
        let storeName = name.replace("/", "+")
        let tarballPath = bao_path.PathModule.join(ArrayList<String>([
            entryDir, "${storeName}-${version}.tgz"
        ]))
        BaoFile.writeAllBytes(tarballPath, tarballData)

        // 解压到缓存目录
        // 翻译自: src/install/extract_tarball.zig ExtractTarball
        let extractDir = bao_path.PathModule.join(ArrayList<String>([entryDir, "node_modules", name]))
        BaoFile.mkdir(extractDir, true)

        // 解压 tar.gz
        // Bun 使用 libarchive 进行流式解压
        // 此处调用系统 tar 命令进行解压
        let extractResult = extractTarballToDir(tarballPath, extractDir)

        // 计算文件数量和总大小
        let (fileCount, totalSize) = countFiles(extractDir)

        // 创建缓存条目
        let entry = CacheEntry(name, version)
        entry.integrity = integrity
        entry.cachePath = extractDir
        entry.tarballPath = tarballPath
        entry.extracted = extractResult
        entry.size = if (totalSize > 0) { totalSize } else { Int64(tarballData.size) }
        entry.fileCount = fileCount

        // 更新元数据
        metadata.put(entry)
        saveMetadata()

        return Some(entry)
    }

    /// 从缓存获取包
    /// 对应 Bun: Store 中查找已缓存包
    public func retrievePackage(name: String, version: String): ?CacheEntry {
        let key = "${name}@${version}"
        return metadata.get(key)
    }

    /// 检查缓存中是否有某个包
    /// 对应 Bun: Store.containsPackage
    public func hasPackage(name: String, version: String): Bool {
        match (metadata.peek("${name}@${version}")) {
            case Some(entry) => {
                // 验证缓存文件是否仍然存在
                if (!BaoFile.exists(entry.cachePath)) {
                    // 缓存文件丢失, 清除条目
                    metadata.remove("${name}@${version}")
                    return false
                }
                return true
            }
            case None => return false
        }
    }

    // ========================================================================
    // 安装到 node_modules
    // 严格翻译自: src/install/isolated_install 中的安装逻辑
    //   Bun 支持两种安装模式:
    //   1. 硬链接 (isolated install): Store -> node_modules/.cache/... (Hardlinker)
    //   2. 符号链接 (isolated install): Store -> node_modules/.store/... -> node_modules/name (Symlinker)
    // ========================================================================

    /// 通过硬链接安装到目标目录
    /// 对应 Bun: isolated_install/Hardlinker.zig
    /// 使用硬链接而非复制以节省磁盘空间
    public func installViaHardlink(name: String, version: String, destDir: String): Bool {
        let key = "${name}@${version}"
        let entry = metadata.get(key)
        match (entry) {
            case Some(e) => {
                if (!BaoFile.exists(e.cachePath)) {
                    return false
                }

                let targetDir = bao_path.PathModule.join(ArrayList<String>([
                    destDir, "node_modules", name
                ]))

                // 确保 @scope 目录存在
                if (name.startsWith("@")) {
                    let slashIdx = name.indexOf("/")
                    match (slashIdx) {
                        case Some(idx) => {
                            let scopeDir = bao_path.PathModule.join(ArrayList<String>([
                                destDir, "node_modules", name.substring(0, idx)
                            ]))
                            BaoFile.mkdir(scopeDir, true)
                        }
                        case None => {}
                    }
                }

                BaoFile.mkdir(targetDir, true)

                // 创建硬链接
                // 翻译自: Hardlinker.hardlinkFiles
                //   Bun 遍历源目录中的所有文件, 为每个文件创建硬链接
                return hardlinkRecursive(e.cachePath, targetDir)
            }
            case None => return false
        }
    }

    /// 通过符号链接安装
    /// 对应 Bun: isolated_install/Symlinker.zig
    public func installViaSymlink(name: String, version: String, destDir: String): Bool {
        let key = "${name}@${version}"
        let entry = metadata.get(key)
        match (entry) {
            case Some(e) => {
                if (!BaoFile.exists(e.cachePath)) {
                    return false
                }

                // 确保 @scope 目录存在
                if (name.startsWith("@")) {
                    let slashIdx = name.indexOf("/")
                    match (slashIdx) {
                        case Some(idx) => {
                            let scopeDir = bao_path.PathModule.join(ArrayList<String>([
                                destDir, "node_modules", name.substring(0, idx)
                            ]))
                            BaoFile.mkdir(scopeDir, true)
                        }
                        case None => {}
                    }
                }

                let linkPath = bao_path.PathModule.join(ArrayList<String>([
                    destDir, "node_modules", name
                ]))
                // 移除旧链接
                if (BaoFile.exists(linkPath)) {
                    BaoFile.removeRecursive(linkPath)
                }
                return BaoFile.createSymlink(e.cachePath, linkPath)
            }
            case None => return false
        }
    }

    /// 安装到 .store 目录 (pnpm-style isolated)
    /// 对应 Bun: isolated_install 中的 store 安装
    public func installToStore(name: String, version: String, destDir: String): String {
        let key = "${name}@${version}"
        let entry = metadata.get(key)
        match (entry) {
            case Some(e) => {
                // 创建 .store 目录
                let storeDir = bao_path.PathModule.join(ArrayList<String>([
                    destDir, "node_modules", ".store"
                ]))
                BaoFile.mkdir(storeDir, true)

                // 硬链接到 .store
                let storePkgDir = bao_path.PathModule.join(ArrayList<String>([
                    storeDir, e.storeName() + "@${version}", "node_modules", name
                ]))
                BaoFile.mkdir(storePkgDir, true)
                hardlinkRecursive(e.cachePath, storePkgDir)

                return storePkgDir
            }
            case None => return ""
        }
    }

    // ========================================================================
    // 缓存管理
    // ========================================================================

    /// 清除整个缓存
    /// 对应 Bun: bun pm cache rm
    public func clearCache(): Bool {
        BaoFile.removeRecursive(cacheDir)
        metadata = CacheMetadata()
        ensureCacheDir()
        return true
    }

    /// 清除单个包的缓存
    public func clearPackage(name: String, version: String): Bool {
        let key = "${name}@${version}"
        let entry = metadata.get(key)
        match (entry) {
            case Some(e) => {
                let entryDir = getEntryDir(name, version)
                BaoFile.removeRecursive(entryDir)
                metadata.remove(key)
                saveMetadata()
                return true
            }
            case None => return false
        }
    }

    /// 获取缓存统计信息
    public func getStats(): String {
        let entries = metadata.allEntries()
        let totalSize = metadata.getTotalSize()
        let sizeMB = totalSize / (1024 * 1024)
        return "Cache: ${entries.size} packages, ${sizeMB} MB"
    }

    /// 清理过期缓存 (LRU)
    /// 对应 Bun: 缓存清理策略
    /// 翻译自: Store 中基于访问时间的 LRU 清理
    public func prune(maxSizeMB: Int64): Int64 {
        let entries = metadata.entriesByLRU()
        let maxSizeBytes = maxSizeMB * 1024 * 1024
        var removedCount: Int64 = 0

        var currentSize = metadata.getTotalSize()
        for (entry in entries) {
            if (currentSize <= maxSizeBytes) {
                break
            }
            let entryDir = getEntryDir(entry.name, entry.version)
            BaoFile.removeRecursive(entryDir)
            currentSize -= entry.size
            metadata.remove(entry.key())
            removedCount += 1
        }

        if (removedCount > 0) {
            saveMetadata()
        }
        return removedCount
    }

    /// 按时间清理过期缓存
    /// 翻译自: 基于时间戳的缓存过期
    public func pruneOlderThan(maxAgeMs: Int64): Int64 {
        let now = bao_sys.SysModule.currentTimeMillis()
        let entries = metadata.allEntries()
        var removedCount: Int64 = 0

        for (entry in entries) {
            if (now - entry.lastAccessTimestamp > maxAgeMs) {
                let entryDir = getEntryDir(entry.name, entry.version)
                BaoFile.removeRecursive(entryDir)
                metadata.remove(entry.key())
                removedCount += 1
            }
        }

        if (removedCount > 0) {
            saveMetadata()
        }
        return removedCount
    }

    /// 验证所有缓存条目的完整性
    /// 对应 Bun: bun pm cache verify
    public func verifyAll(): CacheVerifyResult {
        let result = CacheVerifyResult()
        let entries = metadata.allEntries()

        for (entry in entries) {
            result.totalChecked += 1

            // 检查缓存目录是否存在
            if (!BaoFile.exists(entry.cachePath)) {
                result.missingEntries += 1
                metadata.remove(entry.key())
                continue
            }

            // 检查 tarball 是否存在
            if (entry.tarballPath.length > 0 && BaoFile.exists(entry.tarballPath)) {
                if (entry.integrity.length > 0) {
                    let data = BaoFile.readAllBytes(entry.tarballPath)
                    match (data) {
                        case Some(bytes) => {
                            if (!integrityVerifier.verify(bytes, entry.integrity)) {
                                result.corruptedEntries += 1
                                // 删除损坏的缓存
                                let entryDir = getEntryDir(entry.name, entry.version)
                                BaoFile.removeRecursive(entryDir)
                                metadata.remove(entry.key())
                            } else {
                                result.validEntries += 1
                            }
                        }
                        case None => result.missingEntries += 1
                    }
                } else {
                    result.validEntries += 1
                }
            } else {
                result.validEntries += 1
            }
        }

        if (result.missingEntries > 0 || result.corruptedEntries > 0) {
            saveMetadata()
        }

        return result
    }

    // ==================== 私有方法 ====================

    /// 确保缓存目录存在
    private func ensureCacheDir(): Unit {
        BaoFile.mkdir(cacheDir, true)
    }

    /// 获取包缓存目录
    /// 对应 Bun: Store 的路径格式
    /// 翻译自: ~/.bun/install/cache/{name}@{version}/
    private func getEntryDir(name: String, version: String): String {
        let storeName = name.replace("/", "+")
        return bao_path.PathModule.join(ArrayList<String>([cacheDir, "${storeName}@${version}"]))
    }

    /// 解压 tarball 到目标目录
    /// 翻译自: src/install/extract_tarball.zig ExtractTarball
    ///   Bun 使用 libarchive 进行流式解压
    ///   此处使用系统 tar 命令
    private func extractTarballToDir(tarballPath: String, destDir: String): Bool {
        // 尝试使用系统 tar 解压
        let args = ArrayList<String>(["tar", "-xzf", tarballPath, "-C", destDir, "--strip-components=1"])
        let result = bao_sys.Process.run(
            command: args,
            cwd: destDir,
            env: ArrayList<String>(),
            timeout: 30000
        )
        match (result) {
            case Some(exitCode) => return exitCode == 0
            case None => return false
        }
    }

    /// 递归硬链接
    /// 翻译自: Hardlinker.hardlinkFiles
    ///   Bun 遍历源目录中的所有文件, 创建硬链接
    private func hardlinkRecursive(sourceDir: String, targetDir: String): Bool {
        let entries = BaoFile.readDir(sourceDir)
        match (entries) {
            case Some(dirEntries) => {
                for (entry in dirEntries) {
                    let srcPath = bao_path.PathModule.join(ArrayList<String>([sourceDir, entry]))
                    let tgtPath = bao_path.PathModule.join(ArrayList<String>([targetDir, entry]))

                    if (BaoFile.isDirectory(srcPath)) {
                        BaoFile.mkdir(tgtPath, true)
                        if (!hardlinkRecursive(srcPath, tgtPath)) {
                            return false
                        }
                    } else {
                        // 尝试硬链接, 失败则复制
                        if (!BaoFile.hardlink(tgtPath, srcPath)) {
                            // 回退到文件复制
                            if (!BaoFile.copy(srcPath, tgtPath)) {
                                return false
                            }
                        }
                    }
                }
                return true
            }
            case None => return false
        }
    }

    /// 统计目录中的文件数和总大小
    private func countFiles(dir: String): (Int64, Int64) {
        var count: Int64 = 0
        var size: Int64 = 0
        let entries = BaoFile.readDir(dir)
        match (entries) {
            case Some(dirEntries) => {
                for (entry in dirEntries) {
                    let path = bao_path.PathModule.join(ArrayList<String>([dir, entry]))
                    if (BaoFile.isDirectory(path)) {
                        let (subCount, subSize) = countFiles(path)
                        count += subCount
                        size += subSize
                    } else {
                        count += 1
                        let fileSize = BaoFile.getFileSize(path)
                        match (fileSize) {
                            case Some(s) => size += s
                            case None => {}
                        }
                    }
                }
            }
            case None => {}
        }
        return (count, size)
    }

    /// 从磁盘加载元数据
    private func loadMetadata(): Unit {
        let content = try {
            BaoFile.readAllText(metadataPath)
        } catch (_: Exception) {
            return
        }

        let parser = JsonParser()
        let json = parser.parse(content)
        match (json) {
            case Some(JsonValue.Object(root)) => {
                match (JsonHelper.getField(root, "entries")) {
                    case Some(JsonValue.Object(obj)) => {
                        for (key in obj.keys()) {
                            match (obj.get(key)) {
                                case Some(JsonValue.Object(entryObj)) => {
                                    let name = match (JsonHelper.getString(entryObj, "name")) {
                                        case Some(n) => n
                                        case None => continue
                                    }
                                    let version = match (JsonHelper.getString(entryObj, "version")) {
                                        case Some(v) => v
                                        case None => continue
                                    }
                                    let entry = CacheEntry(name, version)
                                    entry.integrity = match (JsonHelper.getString(entryObj, "integrity")) {
                                        case Some(i) => i
                                        case None => ""
                                    }
                                    entry.cachePath = match (JsonHelper.getString(entryObj, "cachePath")) {
                                        case Some(p) => p
                                        case None => ""
                                    }
                                    entry.tarballPath = match (JsonHelper.getString(entryObj, "tarballPath")) {
                                        case Some(p) => p
                                        case None => ""
                                    }
                                    entry.extracted = match (JsonHelper.getField(entryObj, "extracted")) {
                                        case Some(JsonValue.Bool(b)) => b
                                        case _ => false
                                    }
                                    entry.size = match (JsonHelper.getField(entryObj, "size")) {
                                        case Some(JsonValue.Number(n)) => Int64(n)
                                        case _ => 0
                                    }
                                    entry.fileCount = match (JsonHelper.getField(entryObj, "fileCount")) {
                                        case Some(JsonValue.Number(n)) => Int64(n)
                                        case _ => 0
                                    }
                                    entry.createdTimestamp = match (JsonHelper.getField(entryObj, "createdTimestamp")) {
                                        case Some(JsonValue.Number(n)) => Int64(n)
                                        case _ => 0
                                    }
                                    entry.lastAccessTimestamp = match (JsonHelper.getField(entryObj, "lastAccessTimestamp")) {
                                        case Some(JsonValue.Number(n)) => Int64(n)
                                        case _ => 0
                                    }
                                    entry.accessCount = match (JsonHelper.getField(entryObj, "accessCount")) {
                                        case Some(JsonValue.Number(n)) => Int64(n)
                                        case _ => 0
                                    }
                                    metadata.put(entry)
                                }
                                case _ => {}
                            }
                        }
                    }
                    case _ => {}
                }
            }
            case _ => {}
        }
    }

    /// 保存元数据到磁盘
    private func saveMetadata(): Unit {
        let sb = StringBuilder()
        sb.append("{\"entries\":{\n")
        let entries = metadata.allEntries()
        for (i in 0..entries.size) {
            let e = entries[i]
            sb.append("  ${escapeJson(e.key())}: {")
            sb.append("\"name\":${escapeJson(e.name)},")
            sb.append("\"version\":${escapeJson(e.version)},")
            sb.append("\"integrity\":${escapeJson(e.integrity)},")
            sb.append("\"cachePath\":${escapeJson(e.cachePath)},")
            sb.append("\"tarballPath\":${escapeJson(e.tarballPath)},")
            sb.append("\"extracted\":${e.extracted},")
            sb.append("\"size\":${e.size},")
            sb.append("\"fileCount\":${e.fileCount},")
            sb.append("\"createdTimestamp\":${e.createdTimestamp},")
            sb.append("\"lastAccessTimestamp\":${e.lastAccessTimestamp},")
            sb.append("\"accessCount\":${e.accessCount}")
            sb.append("}")
            if (i < entries.size - 1) { sb.append(",") }
            sb.append("\n")
        }
        sb.append("}}\n")
        BaoFile.writeAllText(metadataPath, sb.toString())
    }

    private static func escapeJson(s: String): String {
        if (s.length == 0) { return "\"\"" }
        let sb = StringBuilder()
        sb.append("\"")
        for (c in s) {
            match (c) {
                case '"' => sb.append("\\\"")
                case '\\' => sb.append("\\\\")
                case _ => sb.append(c)
            }
        }
        sb.append("\"")
        return sb.toString()
    }
}

// ============================================================================
// 完整性验证器
// 严格翻译自: src/install/integrity.zig
//   Integrity struct: tag (sha1/sha256/sha384/sha512) + value
//   Integrity.verify: 比较计算哈希与预期哈希
//   Integrity.forBytes: 从原始字节计算 sha512
// ============================================================================

/// 完整性验证器
public class IntegrityVerifier {
    /// 验证数据完整性
    /// 翻译自: Integrity.verify
    public func verify(data: Array<UInt8>, expected: String): Bool {
        if (expected.length == 0) { return true }

        if (expected.startsWith("sha512-")) {
            let expectedHash = expected.substring(7)
            let hash = bao_hash.Sha512.hash(data)
            let computed = bao_hash.Base64.encode(hash)
            return computed == expectedHash
        }
        if (expected.startsWith("sha384-")) {
            let expectedHash = expected.substring(7)
            let hash = bao_hash.Sha384.hash(data)
            let computed = bao_hash.Base64.encode(hash)
            return computed == expectedHash
        }
        if (expected.startsWith("sha256-")) {
            let expectedHash = expected.substring(7)
            let hash = bao_hash.Sha256.hash(data)
            let computed = bao_hash.Base64.encode(hash)
            return computed == expectedHash
        }
        if (expected.startsWith("sha1-")) {
            let expectedHash = expected.substring(5)
            let hash = bao_hash.Sha1.hash(data)
            let computed = bao_hash.Base64.encode(hash)
            return computed == expectedHash
        }
        // 40字符十六进制 = shasum
        if (expected.length == 40) {
            let hash = bao_hash.Sha1.hash(data)
            let sb = StringBuilder()
            for (b in hash) {
                let hex = Int64(b).toString(16)
                if (hex.length < 2) { sb.append("0") }
                sb.append(hex)
            }
            return sb.toString() == expected
        }
        return true  // 未知格式, 跳过
    }
}

/// 缓存验证结果
public class CacheVerifyResult {
    public var totalChecked: Int64
    public var validEntries: Int64
    public var missingEntries: Int64
    public var corruptedEntries: Int64

    public init() {
        totalChecked = 0
        validEntries = 0
        missingEntries = 0
        corruptedEntries = 0
    }

    public func hasProblems(): Bool {
        return missingEntries > 0 || corruptedEntries > 0
    }

    public func toString(): String {
        return "Cache verify: ${totalChecked} checked, ${validEntries} valid, ${missingEntries} missing, ${corruptedEntries} corrupted"
    }
}
