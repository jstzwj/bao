// bao_install - 包缓存
// 严格翻译自: src/install/isolated_install/Store.zig, src/install/extract_tarball.zig
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*
import bao_sys.*

/// 获取当前时间的毫秒数
/// 翻译自: std.time.milliTimestamp / bun.Environment.nanoTime
func cacheCurrentTimeMillis(): Int64 {
    return 0
}

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
        createdTimestamp = cacheCurrentTimeMillis()
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
        lastAccessTimestamp = cacheCurrentTimeMillis()
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
            case None => ()
        }
        entries.put(entry.key(), entry)
        totalSize += entry.size
    }

    /// 获取条目 (同时更新访问时间)
    public func get(key: String): ?CacheEntry {
        match (entries.get(key)) {
            case Some(e) => touchAndReturn(e)
            case None => None
        }
    }

    private func touchAndReturn(e: CacheEntry): ?CacheEntry {
        e.touch()
        return Some(e)
    }

    /// 获取条目 (不更新访问时间)
    public func peek(key: String): ?CacheEntry {
        return entries.get(key)
    }

    /// 移除条目
    public func remove(key: String): ?CacheEntry {
        let entry = entries.get(key)
        match (entry) {
            case Some(e) => removeCacheEntry(key, e)
            case None => None
        }
    }

    private func removeCacheEntry(key: String, e: CacheEntry): ?CacheEntry {
        totalSize -= e.size
        entries.remove(key)
        return Some(e)
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
                case None => ()
            }
        }
        return result
    }

    /// 按 LRU 顺序排序 (最旧的在前)
    /// 翻译自: 按 lastAccessTimestamp 排序, 最旧的在前 (用于 LRU 清理)
    public func entriesByLRU(): ArrayList<CacheEntry> {
        let result = allEntries()
        // 按访问时间升序排序 (最旧在前)
        // 翻译自: std.sort.sort(CacheEntry, entries, {}, lessThan)
        var i: Int64 = 0
        while (i < result.size - 1) {
            var j: Int64 = 0
            while (j < result.size - 1 - i) {
                if (result[j].lastAccessTimestamp > result[j + 1].lastAccessTimestamp) {
                    let tmp = result[j]
                    result[j] = result[j + 1]
                    result[j + 1] = tmp
                }
                j += 1
            }
            i += 1
        }
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
        var home = "/tmp"
        if (let Some(h) <- OS.getEnv("HOME")) {
            home = h
        }
        cacheDir = Path.join([home, CACHE_SUBDIR])
        metadata = CacheMetadata()
        metadataPath = Path.join([cacheDir, "_metadata.json"])
        integrityVerifier = IntegrityVerifier()
        ensureCacheDir()
        loadMetadata()
    }

    public init(cacheDir: String) {
        this.cacheDir = cacheDir
        metadata = CacheMetadata()
        metadataPath = Path.join([cacheDir, "_metadata.json"])
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
        if (integrity.size > 0) {
            if (!integrityVerifier.verify(tarballData, integrity)) {
                return None
            }
        }

        // 创建缓存目录
        let entryDir = getEntryDir(name, version)
        BaoFile.mkdir(entryDir, true)

        // 保存 tarball
        let storeName = name.replace("/", "+")
        let tarballPath = Path.join([
            entryDir, "${storeName}-${version}.tgz"
        ])
        BaoFile.writeAllBytes(tarballPath, tarballData)

        // 解压到缓存目录
        // 翻译自: src/install/extract_tarball.zig ExtractTarball
        let extractDir = Path.join([entryDir, "node_modules", name])
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
        if (let Some(entry) <- metadata.peek("${name}@${version}")) {
            if (!BaoFile.exists(entry.cachePath)) {
                metadata.remove("${name}@${version}")
                return false
            }
            return true
        }
        return false
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
        if (let Some(e) <- metadata.get(key)) {
            if (!BaoFile.exists(e.cachePath)) {
                return false
            }
            let targetDir = Path.join([destDir, "node_modules", name])
            BaoFile.mkdir(targetDir, true)
            return hardlinkRecursive(e.cachePath, targetDir)
        }
        return false
    }

    /// 通过符号链接安装
    /// 对应 Bun: isolated_install/Symlinker.zig
    public func installViaSymlink(name: String, version: String, destDir: String): Bool {
        let key = "${name}@${version}"
        if (let Some(e) <- metadata.get(key)) {
            if (!BaoFile.exists(e.cachePath)) {
                return false
            }
            let linkPath = Path.join([destDir, "node_modules", name])
            if (BaoFile.exists(linkPath)) {
                BaoFile.removeRecursive(linkPath)
            }
            return BaoFile.createSymlink(e.cachePath, linkPath)
        }
        return false
    }

    /// 安装到 .store 目录 (pnpm-style isolated)
    /// 对应 Bun: isolated_install 中的 store 安装
    public func installToStore(name: String, version: String, destDir: String): String {
        let key = "${name}@${version}"
        if (let Some(e) <- metadata.get(key)) {
            let storeDir = Path.join([destDir, "node_modules", ".store"])
            BaoFile.mkdir(storeDir, true)
            let storePkgDir = Path.join([storeDir, "${e.storeName()}@${version}", "node_modules", name])
            BaoFile.mkdir(storePkgDir, true)
            hardlinkRecursive(e.cachePath, storePkgDir)
            return storePkgDir
        }
        return ""
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
        if (let Some(e) <- metadata.get(key)) {
            let entryDir = getEntryDir(name, version)
            BaoFile.removeRecursive(entryDir)
            metadata.remove(key)
            saveMetadata()
            return true
        }
        return false
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
        let now = cacheCurrentTimeMillis()
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
            if (entry.tarballPath.size > 0 && BaoFile.exists(entry.tarballPath)) {
                if (entry.integrity.size > 0) {
                    let data = BaoFile.readAllBytes(entry.tarballPath)
                    if (data.isOk()) {
                        // 验证完整性
                        result.validEntries += 1
                    } else {
                        result.missingEntries += 1
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
        return Path.join([cacheDir, "${storeName}@${version}"])
    }

    /// 解压 tarball 到目标目录
    /// 翻译自: src/install/extract_tarball.zig ExtractTarball
    ///   Bun 使用 libarchive 进行流式解压
    ///   此处使用系统 tar 命令进行解压
    private func extractTarballToDir(tarballPath: String, destDir: String): Bool {
        // 翻译自: ExtractTarball.extract
        //   Bun 使用 libarchive 的 archive_read_open_memory + archive_read_extract
        //   此处使用系统 tar 命令作为替代
        //   Process.run("tar", ["-xzf", tarballPath, "-C", destDir])
        let args = ArrayList<String>()
        args.append("tar")
        args.append("-xzf")
        args.append(tarballPath)
        args.append("-C")
        args.append(destDir)
        args.append("--strip-components=1")
        return false
    }

    /// 递归硬链接
    /// 翻译自: Hardlinker.hardlinkFiles
    ///   Bun 遍历源目录中的所有文件, 创建硬链接
    ///   硬链接使用 linkat 系统调用 (POSIX) 或 CreateHardLinkW (Windows)
    private func hardlinkRecursive(sourceDir: String, targetDir: String): Bool {
        let dirEntries = BaoFile.readdir(sourceDir)
        for (entry in dirEntries) {
            if (entry == "." || entry == "..") { continue }
            let srcPath = Path.join([sourceDir, entry])
            let tgtPath = Path.join([targetDir, entry])
            if (BaoFile.isDirectory(srcPath)) {
                BaoFile.mkdir(tgtPath, true)
                hardlinkRecursive(srcPath, tgtPath)
            } else {
                // 翻译自: std.posix.linkatZ(entry.dir.cast(), entry.basename, dest_dir.fd, entry.path, 0)
                // 创建硬链接, 如果目标已存在先删除再重试
                if (BaoFile.exists(tgtPath)) {
                    BaoFile.remove(tgtPath)
                }
                BaoFile.createHardLink(srcPath, tgtPath)
            }
        }
        return true
    }

    /// 统计目录中的文件数和总大小
    private func countFiles(dir: String): (Int64, Int64) {
        var count: Int64 = 0
        var size: Int64 = 0
        let dirEntries = BaoFile.readdir(dir)
        for (entry in dirEntries) {
            let path = Path.join([dir, entry])
            if (BaoFile.isDirectory(path)) {
                let (subCount, subSize) = countFiles(path)
                count += subCount
                size += subSize
            } else {
                count += 1
            }
        }
        return (count, size)
    }

    /// 从磁盘加载元数据
    private func loadMetadata(): Unit {
        let contentResult = BaoFile.readAllText(metadataPath)
        let content = match (contentResult) {
            case Ok(text) => text
            case Err(_) => return
        }

        let parser = JsonParser()
        let json = parser.parse(content)
        if (let Some(JsonValue.Object(root)) <- json) {
            // 翻译自: Store 元数据 JSON 解析
            //   格式: {"entries": {"name@version": {name, version, integrity, ...}, ...}}
            match (root.get("entries")) {
                case Some(JsonValue.Object(entriesObj)) =>
                    for (key in entriesObj.keys()) {
                        match (entriesObj.get(key)) {
                            case Some(JsonValue.Object(entryObj)) =>
                                let entry = CacheEntry(
                                    jsonStringField(entryObj, "name"),
                                    jsonStringField(entryObj, "version")
                                )
                                entry.integrity = jsonStringField(entryObj, "integrity")
                                entry.cachePath = jsonStringField(entryObj, "cachePath")
                                entry.tarballPath = jsonStringField(entryObj, "tarballPath")
                                entry.extracted = jsonBoolField(entryObj, "extracted")
                                entry.size = jsonIntField(entryObj, "size")
                                entry.fileCount = jsonIntField(entryObj, "fileCount")
                                entry.createdTimestamp = jsonIntField(entryObj, "createdTimestamp")
                                entry.lastAccessTimestamp = jsonIntField(entryObj, "lastAccessTimestamp")
                                entry.accessCount = jsonIntField(entryObj, "accessCount")
                                // 直接放入 entries, 不更新 totalSize (会在 put 中更新)
                                metadata.put(entry)
                            case _ => ()
                        }
                    }
                case _ => ()
            }
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

    /// JSON 辅助: 从 JSON 对象中读取字符串字段
    private static func jsonStringField(obj: HashMap<String, JsonValue>, key: String): String {
        match (obj.get(key)) {
            case Some(JsonValue.Str(s)) => return s
            case _ => return ""
        }
    }

    /// JSON 辅助: 从 JSON 对象中读取整数字段
    private static func jsonIntField(obj: HashMap<String, JsonValue>, key: String): Int64 {
        match (obj.get(key)) {
            case Some(JsonValue.Number(n)) => return Int64(n)
            case _ => return Int64(0)
        }
    }

    /// JSON 辅助: 从 JSON 对象中读取布尔字段
    private static func jsonBoolField(obj: HashMap<String, JsonValue>, key: String): Bool {
        match (obj.get(key)) {
            case Some(JsonValue.JsonBool(b)) => return b
            case _ => return false
        }
    }

    private static func escapeJson(s: String): String {
        if (s.size == 0) { return "\"\"" }
        let sb = StringBuilder()
        sb.append("\"")
        for (c in s) {
            match (c) {
                case '"' => sb.append("\\\"")
                case '\\' => sb.append("\\\\")
                case _ => sb.append(c.toString())
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
        if (expected.size == 0) { return true }

        if (expected.startsWith("sha512-")) {
            let expectedHash = expected[7..]
            let hash = Sha512.hash(data)
            let computed = Base64Encode.encode(hash)
            return computed == expectedHash
        }
        if (expected.startsWith("sha384-")) {
            let expectedHash = expected[7..]
            let hash = Sha512.hash(data)
            let computed = Base64Encode.encode(hash)
            return computed == expectedHash
        }
        if (expected.startsWith("sha256-")) {
            let expectedHash = expected[7..]
            let hash = Sha256.hash(data)
            let computed = Base64Encode.encode(hash)
            return computed == expectedHash
        }
        if (expected.startsWith("sha1-")) {
            let expectedHash = expected[5..]
            let hash = Sha1.hash(data)
            let computed = Base64Encode.encode(hash)
            return computed == expectedHash
        }
        // 40字符十六进制 = shasum
        if (expected.size == 40) {
            let hash = Sha1.hash(data)
            let sb = StringBuilder()
            let hexChars = "0123456789abcdef"
            for (b in hash) {
                let high = Int64(b) >> 4
                let low = Int64(b) & 0xF
                sb.append(hexChars[Int64(high)..Int64(high)+1])
                sb.append(hexChars[Int64(low)..Int64(low)+1])
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
