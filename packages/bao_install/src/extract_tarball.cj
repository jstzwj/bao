// bao_install - 解压 tarball
// 严格翻译自: src/install/extract_tarball.zig
//   extract_tarball.zig 负责:
//   1. 验证 tarball 完整性
//   2. 解压 gzip 压缩的 tarball
//   3. 提取文件到临时目录
//   4. 移动到缓存目录
//   5. 创建包索引符号链接
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 解压数据
// 严格翻译自: src/install/install.zig - ExtractData
// ============================================================================

/// 解压数据
/// 对应 Bun: ExtractData
public class ExtractData {
    /// 包 URL
    public var url: String
    /// 解析后的 commit/ref
    public var resolved: String
    /// package.json 数据
    public var json: ExtractJsonData
    /// 完整性哈希
    public var integrity: Integrity

    public init() {
        url = ""
        resolved = ""
        json = ExtractJsonData()
        integrity = Integrity()
    }

    public init(url: String, resolved: String) {
        this.url = url
        this.resolved = resolved
        json = ExtractJsonData()
        integrity = Integrity()
    }
}

/// 提取的 JSON 数据
/// 对应 Bun: ExtractData.json
public class ExtractJsonData {
    /// package.json 路径
    public var path: String
    /// package.json 内容
    public var buf: String

    public init() {
        path = ""
        buf = ""
    }

    public init(path: String, buf: String) {
        this.path = path
        this.buf = buf
    }
}

// ============================================================================
// 解压 tarball
// 严格翻译自: src/install/extract_tarball.zig - ExtractTarball
//   pub const ExtractTarball = @This();
//   name: strings.StringOrTinyString,
//   resolution: Resolution,
//   cache_dir: std.fs.Dir,
//   temp_dir: std.fs.Dir,
//   dependency_id: DependencyID,
//   ...
// ============================================================================

/// 解压 tarball
/// 对应 Bun: ExtractTarball
public class ExtractTarball {
    /// 包名
    public var name: String
    /// 解析信息
    public var resolution: String
    /// 解析标签
    public var resolutionTag: DependencyVersionTag
    /// 缓存目录
    public var cacheDir: String
    /// 临时目录
    public var tempDir: String
    /// 依赖 ID
    public var dependencyId: UInt32
    /// 是否跳过验证
    public var skipVerify: Bool
    /// 完整性哈希
    public var integrity: Integrity
    /// 包 URL
    public var url: String
    /// 包管理器引用
    public var packageManager: PackageManagerRef

    public init() {
        name = ""
        resolution = ""
        resolutionTag = DependencyVersionTag.Npm
        cacheDir = ""
        tempDir = ""
        dependencyId = UInt32(0)
        skipVerify = false
        integrity = Integrity()
        url = ""
        packageManager = PackageManagerRef()
    }

    /// 运行解压
    /// 严格翻译自: ExtractTarball.run
    ///   pub inline fn run(this: *const ExtractTarball, log: *logger.Log, bytes: []const u8) !Install.ExtractData
    ///
    /// 步骤:
    /// 1. 验证完整性
    /// 2. 解压 gzip
    /// 3. 提取 tar 文件
    /// 4. 移动到缓存目录
    public func run(tarballBytes: ArrayList<Byte>, log: ArrayList<String>): ?ExtractData {
        // 1. 验证完整性
        if (!skipVerify && integrity.tag.isSupported()) {
            if (!integrity.verify(tarballBytes)) {
                log.append("Integrity check failed for tarball: ${name}")
                return None
            }
        }

        // 2. 解压 + 提取
        let result = extract(tarballBytes, log)
        match (result) {
            case Some(data) => {
                // 对于 GitHub/远程 tarball, 计算并存储完整性哈希
                match (resolutionTag) {
                    case DependencyVersionTag.GitHub =>
                    case DependencyVersionTag.RemoteTarball =>
                    case DependencyVersionTag.LocalTarball => {
                        if (integrity.tag.isSupported()) {
                            data.integrity = integrity
                        } else {
                            data.integrity = Integrity.forBytes(tarballBytes)
                        }
                    }
                    case _ => ()
                }
                return data
            }
            case None => return None
        }
    }

    /// 解压 tarball
    /// 翻译自: ExtractTarball.extract
    private func extract(tarballBytes: ArrayList<Byte>, log: ArrayList<String>): ?ExtractData {
        let displayName = getDisplayName()
        let basename = getCacheBasename()

        // 创建临时目录
        let tmpName = "${basename}-${bao_sys.SysModule.currentTimeMillis()}"
        let tmpPath = bao_path.PathModule.join(ArrayList<String>([tempDir, tmpName]))

        try {
            bao_io.File.createDirectory(tmpPath)
        } catch (e: Exception) {
            log.append("Failed to create temp directory '${tmpName}' for '${name}': ${e.message}")
            return None
        }

        // 解压 tarball 到临时目录
        // 翻译自: 使用 libarchive 解压
        let extractSuccess = try {
            bao_archive.Archive.extractTarball(tarballBytes, tmpPath)
        } catch (e: Exception) {
            log.append("Failed to extract '${name}': ${e.message}")
            // 清理
            try { bao_io.File.removeDirectory(tmpPath) } catch (_: Exception) {}
            return None
        }

        // 移动到缓存目录
        return moveToCacheDirectory(tmpName: tmpName, name: displayName, basename: basename, resolved: "", log: log)
    }

    /// 移动到缓存目录
    /// 严格翻译自: ExtractTarball.moveToCacheDirectory
    public func moveToCacheDirectory(
        tmpName: String,
        name: String,
        basename: String,
        resolved: String,
        log: ArrayList<String>
    ): ?ExtractData {
        // 构建缓存文件夹名
        let folderName = match (resolutionTag) {
            case DependencyVersionTag.Npm => "${name}@${resolution}"
            case DependencyVersionTag.GitHub => "@GH@${resolved}"
            case _ => "${basename}"
        }

        // 对于 @scope 包, 确保父目录存在
        // 翻译自: create_subdir 逻辑
        if (basename != name) {
            let parentDir = bao_path.PathModule.join(ArrayList<String>([cacheDir, name]))
            if (!bao_io.File.directoryExists(parentDir)) {
                try {
                    bao_io.File.createDirectory(parentDir)
                } catch (_: Exception) {}
            }
        }

        let sourcePath = bao_path.PathModule.join(ArrayList<String>([tempDir, tmpName]))
        let destPath = bao_path.PathModule.join(ArrayList<String>([cacheDir, folderName]))

        // 如果目标已存在, 删除旧的
        if (bao_io.File.directoryExists(destPath)) {
            try {
                bao_io.File.removeDirectory(destPath)
            } catch (_: Exception) {
                // 尝试重命名旧目录到临时位置后删除
                let oldTmpName = "${tmpName}-old"
                let oldTmpPath = bao_path.PathModule.join(ArrayList<String>([tempDir, oldTmpName]))
                try {
                    bao_io.File.rename(destPath, oldTmpPath)
                    bao_io.File.removeDirectory(oldTmpPath)
                } catch (_: Exception) {}
            }
        }

        // 重命名
        // 翻译自: bun.sys.renameatConcurrently
        try {
            bao_io.File.rename(sourcePath, destPath)
        } catch (e: Exception) {
            log.append("Failed to move '${name}' to cache dir: ${e.message}")
            return None
        }

        // 读取 package.json
        var jsonPath = ""
        var jsonBuf = ""
        let pkgJsonPath = bao_path.PathModule.join(ArrayList<String>([destPath, "package.json"]))
        if (bao_io.File.exists(pkgJsonPath)) {
            try {
                jsonBuf = bao_io.File.readTextFile(pkgJsonPath)
                jsonPath = pkgJsonPath
            } catch (_: Exception) {
                // GitHub 依赖可以没有 package.json
                if (resolutionTag != DependencyVersionTag.GitHub) {
                    log.append("Failed to read package.json for '${name}'")
                    return None
                }
            }
        }

        // 创建索引符号链接
        // 翻译自: create_index 逻辑
        createPackageIndex(name: name, folderName: folderName, destPath: destPath)

        let result = ExtractData(url: url, resolved: resolved)
        result.json = ExtractJsonData(path: jsonPath, buf: jsonBuf)
        return result
    }

    /// 创建包索引
    /// 翻译自: extract_tarball.zig 中 create_index 部分
    private func createPackageIndex(name: String, folderName: String, destPath: String): Unit {
        // 在缓存目录中创建 <name>/<version> -> 实际路径的符号链接
        // 翻译自: bun.sys.symlinkat(final_path, index_dir, dest_name)
        let nameParts = name.split("/")
        if (nameParts.size <= 1) {
            // 非 scoped 包
            let indexDir = bao_path.PathModule.join(ArrayList<String>([cacheDir, name]))
            if (!bao_io.File.directoryExists(indexDir)) {
                try { bao_io.File.createDirectory(indexDir) } catch (_: Exception) { return }
            }
            // 提取版本号部分
            let versionPart = folderName.substring(name.length + 1)
            let linkPath = bao_path.PathModule.join(ArrayList<String>([indexDir, versionPart]))
            try {
                bao_io.File.createSymlink(destPath, linkPath)
            } catch (_: Exception) {}
        }
    }

    /// 获取显示名
    /// 翻译自: ExtractTarball.nameAndBasename
    public func getDisplayName(): String {
        if (name.length > 0) { return name }
        return "unnamed-package"
    }

    /// 获取缓存基础名
    /// 翻译自: ExtractTarball.nameAndBasename 中的 basename 逻辑
    public func getCacheBasename(): String {
        var tmp = name
        if (tmp.startsWith("https://") || tmp.startsWith("http://")) {
            let lastSlash = tmp.lastIndexOf("/")
            if (lastSlash >= 0) {
                tmp = tmp.substring(lastSlash + 1)
            }
            if (tmp.endsWith(".tgz")) {
                tmp = tmp.substring(0, tmp.length - 4)
            } else if (tmp.endsWith(".tar.gz")) {
                tmp = tmp.substring(0, tmp.length - 7)
            }
        } else if (tmp.length > 0 && tmp[0] == '@') {
            let slashIdx = tmp.indexOf("/")
            if (slashIdx >= 0) {
                tmp = tmp.substring(slashIdx + 1)
            }
        }
        return tmp
    }

    /// 构建 tarball URL
    /// 严格翻译自: ExtractTarball.buildURL
    ///   pub fn buildURL(registry_, full_name_, version, string_buf) OOM!string
    ///
    /// 格式: {registry}/{full_name}/-/{name}-{version}.tgz
    public static func buildURL(
        registry: String,
        fullName: String,
        major: Int64,
        minor: Int64,
        patch: Int64,
        prerelease: ?String,
        build: ?String
    ): String {
        let reg = registry.trimEnd("/")
        var namePart = fullName
        if (namePart.length > 0 && namePart[0] == '@') {
            let slashIdx = namePart.indexOf("/")
            if (slashIdx >= 0) {
                namePart = namePart.substring(slashIdx + 1)
            }
        }

        let baseVersion = "${major}.${minor}.${patch}"

        // 带 prerelease 和/或 build
        var suffix = ""
        match (prerelease) {
            case Some(pre) => {
                suffix = suffix + "-${pre}"
            }
            case None => ()
        }
        match (build) {
            case Some(b) => {
                suffix = suffix + "+${b}"
            }
            case None => ()
        }

        return "${reg}/${fullName}/-/${namePart}-${baseVersion}${suffix}.tgz"
    }

    /// 是否使用流式解压
    /// 翻译自: ExtractTarball.usesStreamingExtraction
    public static func usesStreamingExtraction(): Bool {
        return true
    }
}
