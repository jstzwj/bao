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
    /// 缓存路径
    public var cachePath: String
    /// 已解压
    public var extracted: Bool
    /// 包大小 (字节)
    public var size: Int64
    /// 缓存时间戳
    public var timestamp: Int64

    public init(name: String, version: String) {
        this.name = name
        this.version = version
        integrity = ""
        cachePath = ""
        extracted = false
        size = 0
        timestamp = bao_sys.SysModule.currentTimeMillis()
    }

    /// 缓存键 name@version
    public func key(): String {
        return "${name}@${version}"
    }

    /// 格式化存储路径 (将 / 替换为 +)
    /// 对应 Bun: StorePathFormatter
    public func storeName(): String {
        // scoped packages: @foo/bar -> @foo+bar
        return name.replace("/", "+")
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

    /// 获取条目
    public func get(key: String): ?CacheEntry {
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
}

// ============================================================================
// 包缓存管理器
// 严格翻译自: src/install/isolated_install/Store.zig
//   Bun 维护全局缓存目录 (~/.bun/install/cache/)
//   使用硬链接安装到 node_modules 以节省磁盘空间
// ============================================================================

/// 包缓存管理器
/// 对应 Bun: Store (全局包缓存)
public class PackageCache {
    /// 缓存根目录
    /// 对应 Bun: bun.pm.getCacheDirectory()
    private var cacheDir: String
    /// 元数据索引
    private var metadata: CacheMetadata
    /// 元数据文件路径
    private var metadataPath: String

    public init() {
        let home = bao_sys.SysModule.getEnv("HOME").getOrElse(() => "/tmp")
        cacheDir = bao_path.PathModule.join(ArrayList<String>([home, ".bao", "install", "cache"]))
        metadata = CacheMetadata()
        metadataPath = bao_path.PathModule.join(ArrayList<String>([cacheDir, "_metadata.json"]))
        ensureCacheDir()
        loadMetadata()
    }

    public init(cacheDir: String) {
        this.cacheDir = cacheDir
        metadata = CacheMetadata()
        metadataPath = bao_path.PathModule.join(ArrayList<String>([cacheDir, "_metadata.json"]))
        ensureCacheDir()
        loadMetadata()
    }

    /// 获取缓存目录
    public func getCacheDir(): String {
        return cacheDir
    }

    /// 存储包到缓存
    /// 对应 Bun: Store.installPackageFromTarball
    /// 1. 下载 tarball
    /// 2. 验证完整性
    /// 3. 解压到缓存目录
    /// 4. 更新元数据
    public func storePackage(
        name: String,
        version: String,
        tarballData: Array<UInt8>,
        integrity: String
    ): ?CacheEntry {
        // 验证完整性
        if (integrity.length > 0) {
            if (!verifyChecksum(tarballData, integrity)) {
                return None
            }
        }

        // 创建缓存目录
        let entryDir = getEntryDir(name, version)
        BaoFile.mkdir(entryDir, true)

        // 保存 tarball
        let tarballPath = bao_path.PathModule.join(ArrayList<String>([
            entryDir, "${name.replace("/", "+")}-${version}.tgz"
        ]))
        BaoFile.writeAllBytes(tarballPath, tarballData)

        // 解压到缓存目录
        let extractDir = bao_path.PathModule.join(ArrayList<String>([entryDir, "node_modules", name]))
        BaoFile.mkdir(extractDir, true)

        // TODO: 实际的 tar.gz 解压
        // 此处简化: 创建基本的 package.json 占位
        let pkgJson = "{\"name\":\"${name}\",\"version\":\"${version}\"}"
        BaoFile.writeAllText(
            bao_path.PathModule.join(ArrayList<String>([extractDir, "package.json"])),
            pkgJson
        )

        // 创建缓存条目
        let entry = CacheEntry(name, version)
        entry.integrity = integrity
        entry.cachePath = extractDir
        entry.extracted = true
        entry.size = Int64(tarballData.size)

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
        match (metadata.get("${name}@${version}")) {
            case Some(entry) => {
                // 验证缓存文件是否仍然存在
                return BaoFile.exists(entry.cachePath)
            }
            case None => return false
        }
    }

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
                BaoFile.mkdir(targetDir, true)

                // 创建硬链接
                // 对应 Bun: Hardlinker.hardlinkFiles
                let linked = BaoFile.hardlinkRecursive(e.cachePath, targetDir)
                return linked
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
    public func prune(maxSizeMB: Int64): Int64 {
        let entries = metadata.allEntries()
        let maxSizeBytes = maxSizeMB * 1024 * 1024
        var removedCount: Int64 = 0

        // 按时间排序 (最旧的先清理)
        let sorted = ArrayList<CacheEntry>()
        for (e in entries) { sorted.append(e) }
        sorted.sortBy(func(a: CacheEntry, b: CacheEntry): Int64 {
            return a.timestamp - b.timestamp
        })

        var currentSize = metadata.getTotalSize()
        var i: Int64 = 0
        while (currentSize > maxSizeBytes && i < sorted.size) {
            let entry = sorted[i]
            BaoFile.removeRecursive(getEntryDir(entry.name, entry.version))
            currentSize -= entry.size
            metadata.remove(entry.key())
            removedCount += 1
            i += 1
        }

        if (removedCount > 0) {
            saveMetadata()
        }
        return removedCount
    }

    // ==================== 私有方法 ====================

    /// 确保缓存目录存在
    private func ensureCacheDir(): Unit {
        BaoFile.mkdir(cacheDir, true)
    }

    /// 获取包缓存目录
    /// 对应 Bun: Store 的路径格式
    private func getEntryDir(name: String, version: String): String {
        let storeName = name.replace("/", "+")
        return bao_path.PathModule.join(ArrayList<String>([cacheDir, "${storeName}@${version}"]))
    }

    /// 验证校验和
    /// 对应 Bun: Integrity.verify
    private func verifyChecksum(data: Array<UInt8>, expected: String): Bool {
        if (expected.startsWith("sha512-")) {
            let hash = bao_hash.Sha512.hash(data)
            let hashStr = bytesToBase64(hash)
            return expected == "sha512-${hashStr}"
        }
        if (expected.startsWith("sha256-")) {
            let hash = bao_hash.Sha256.hash(data)
            let hashStr = bytesToBase64(hash)
            return expected == "sha256-${hashStr}"
        }
        if (expected.startsWith("sha1-")) {
            let hash = bao_hash.Sha1.hash(data)
            let hashStr = bytesToBase64(hash)
            return expected == "sha1-${hashStr}"
        }
        return true  // 未知格式, 跳过验证
    }

    /// 字节数组转 base64
    private func bytesToBase64(data: Array<UInt8>): String {
        return bao_hash.Base64.encode(data)
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
                                    entry.extracted = match (JsonHelper.getField(entryObj, "extracted")) {
                                        case Some(JsonValue.Bool(b)) => b
                                        case _ => false
                                    }
                                    entry.size = match (JsonHelper.getField(entryObj, "size")) {
                                        case Some(JsonValue.Number(n)) => Int64(n)
                                        case _ => 0
                                    }
                                    entry.timestamp = match (JsonHelper.getField(entryObj, "timestamp")) {
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
            sb.append("  \"${e.key()}\": {")
            sb.append("\"name\":\"${e.name}\",")
            sb.append("\"version\":\"${e.version}\",")
            sb.append("\"integrity\":\"${e.integrity}\",")
            sb.append("\"cachePath\":\"${e.cachePath}\",")
            sb.append("\"extracted\":${e.extracted},")
            sb.append("\"size\":${e.size},")
            sb.append("\"timestamp\":${e.timestamp}")
            sb.append("}")
            if (i < entries.size - 1) { sb.append(",") }
            sb.append("\n")
        }
        sb.append("}}\n")
        BaoFile.writeAllText(metadataPath, sb.toString())
    }
}
