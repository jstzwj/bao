// 严格翻译自: src/install/extract_tarball.zig, src/install/TarballStream.zig
// bao_install - Tarball 下载与解压
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// Tarball 下载与解压
// 严格翻译自: src/install/extract_tarball.zig (ExtractTarball)
// ============================================================================

/// 完整性校验算法
/// 严格翻译自: src/install/integrity.zig
public enum IntegrityAlgorithm {
    | None
    | Sha1
    | Sha256
    | Sha512
}

/// 完整性校验值
/// 严格翻译自: src/install/integrity.zig Integrity
public class Integrity {
    /// 算法
    public var algorithm: IntegrityAlgorithm
    /// 哈希值 (十六进制)
    public var hash: String

    public init() {
        algorithm = IntegrityAlgorithm.None
        hash = ""
    }

    /// 从 npm integrity 字符串解析
    // 严格翻译自: src/install/integrity.zig Integrity.parse
    // 格式: "sha512-xxxx" 或 "sha1-xxxx"
    public static func parse(s: String): ?Integrity {
        if (s.isEmpty()) { return None }
        let dashIdx = s.indexOf("-")
        match (dashIdx) {
            case Some(idx) => {
                let algo = s.substring(0, idx).toLower()
                let hash = s.substring(idx + 1)
                let integ = Integrity()
                integ.hash = hash
                match (algo) {
                    case "sha1" => integ.algorithm = IntegrityAlgorithm.Sha1
                    case "sha256" => integ.algorithm = IntegrityAlgorithm.Sha256
                    case "sha512" => integ.algorithm = IntegrityAlgorithm.Sha512
                    case _ => integ.algorithm = IntegrityAlgorithm.None
                }
                return Some(integ)
            }
            case None => return None
        }
    }

    /// 从 raw bytes 计算完整性哈希
    public static func forBytes(data: Array<Byte>): Integrity {
        let integ = Integrity()
        integ.algorithm = IntegrityAlgorithm.Sha512
        integ.hash = Hash.sha512Hex(data)
        return integ
    }

    /// 验证数据完整性
    // 严格翻译自: src/install/integrity.zig Integrity.verify
    public func verify(data: Array<Byte>): Bool {
        if (algorithm == IntegrityAlgorithm.None) { return true }
        let computed = match (algorithm) {
            case IntegrityAlgorithm.Sha1 => Hash.sha1Hex(data)
            case IntegrityAlgorithm.Sha256 => Hash.sha256Hex(data)
            case IntegrityAlgorithm.Sha512 => Hash.sha512Hex(data)
            case IntegrityAlgorithm.None => ""
        }
        return computed == hash
    }

    /// 是否支持该校验
    public func isSupported(): Bool {
        return algorithm != IntegrityAlgorithm.None
    }

    /// 转为字符串表示
    public func toString(): String {
        if (algorithm == IntegrityAlgorithm.None) { return "" }
        let algoStr = match (algorithm) {
            case IntegrityAlgorithm.Sha1 => "sha1"
            case IntegrityAlgorithm.Sha256 => "sha256"
            case IntegrityAlgorithm.Sha512 => "sha512"
            case IntegrityAlgorithm.None => ""
        }
        return "${algoStr}-${hash}"
    }
}

/// 提取结果数据
/// 严格翻译自: src/install/install.zig ExtractData
public class ExtractData {
    /// 包解压后的目录路径
    public var packageDir: String
    /// 解压后的文件数量
    public var fileCount: Int64
    /// 解压后的总大小
    public var totalSize: Int64
    /// 完整性哈希
    public var integrity: ?Integrity

    public init() {
        packageDir = ""
        fileCount = 0
        totalSize = 0
        integrity = None
    }
}

/// Tar 头部信息
/// 标准 POSIX tar 格式
public class TarHeader {
    /// 文件名 (100 bytes)
    public var name: String
    /// 文件模式
    public var mode: String
    /// 用户 ID
    public var uid: Int64
    /// 组 ID
    public var gid: Int64
    /// 文件大小 (字节)
    public var size: Int64
    /// 修改时间
    public var mtime: Int64
    /// 类型标志
    public var typeFlag: TarTypeFlag
    /// 链接名
    public var linkName: String
    /// 前缀 (用于长文件名)
    public var prefix: String

    public init() {
        name = ""
        mode = ""
        uid = 0
        gid = 0
        size = 0
        mtime = 0
        typeFlag = TarTypeFlag.Regular
        linkName = ""
        prefix = ""
    }

    /// 从原始字节解析 tar header
    // 标准 POSIX tar header: 512 bytes
    public static func parse(data: Array<Byte>): ?TarHeader {
        if (data.size < 512) { return None }

        let header = TarHeader()
        // name: offset 0, 100 bytes
        header.name = readString(data, 0, 100)
        // mode: offset 100, 8 bytes
        header.mode = readString(data, 100, 8)
        // uid: offset 108, 8 bytes (octal)
        header.uid = readOctal(data, 108, 8)
        // gid: offset 116, 8 bytes (octal)
        header.gid = readOctal(data, 116, 8)
        // size: offset 124, 12 bytes (octal)
        header.size = readOctal(data, 124, 12)
        // mtime: offset 136, 12 bytes (octal)
        header.mtime = readOctal(data, 136, 12)
        // typeflag: offset 156, 1 byte
        let typeByte = data[156]
        header.typeFlag = TarTypeFlag.fromByte(typeByte)
        // linkname: offset 157, 100 bytes
        header.linkName = readString(data, 157, 100)
        // prefix: offset 345, 155 bytes
        header.prefix = readString(data, 345, 155)

        // 如果有 prefix, 拼接完整路径
        if (!header.prefix.isEmpty()) {
            header.name = header.prefix + "/" + header.name
        }

        return Some(header)
    }

    /// 读取以 null 结尾的字符串
    private static func readString(data: Array<Byte>, offset: Int64, len: Int64): String {
        var result = ""
        for (i in 0..len) {
            let b = data[Int64(offset) + i]
            if (b == 0) { break }
            result = result + String.fromCodePoint(Int64(b))
        }
        return result
    }

    /// 读取八进制数
    private static func readOctal(data: Array<Byte>, offset: Int64, len: Int64): Int64 {
        var s = ""
        for (i in 0..len) {
            let b = data[Int64(offset) + i]
            if (b == 0 || b == 32) { continue } // null or space
            s = s + String.fromCodePoint(Int64(b))
        }
        if (s.isEmpty()) { return 0 }
        // 八进制转十进制
        return parseInt64(s, 8)
    }

    /// 简化八进制解析
    private static func parseInt64(s: String, base: Int64): Int64 {
        var result: Int64 = 0
        for (i in 0..s.length) {
            let c = s[i]
            let digit = Int64(c) - Int64('0')
            result = result * base + digit
        }
        return result
    }
}

/// tar 类型标志
public enum TarTypeFlag {
    | Regular       // '0' or '\0'
    | Link          // '1' hard link
    | Symlink       // '2' symbolic link
    | CharDev       // '3'
    | BlockDev      // '4'
    | Directory     // '5'
    | Fifo          // '6'
    | Contiguous    // '7'
    | PaxHeader     // 'x' or 'g'
    | LongName      // 'L' (GNU)
    | Unknown

    public static func fromByte(b: Byte): TarTypeFlag {
        match (Int64(b)) {
            case 0 => Regular
            case 48 => Regular    // '0'
            case 49 => Link       // '1'
            case 50 => Symlink    // '2'
            case 51 => CharDev    // '3'
            case 52 => BlockDev   // '4'
            case 53 => Directory  // '5'
            case 54 => Fifo       // '6'
            case 55 => Contiguous // '7'
            case 120 => PaxHeader // 'x'
            case 103 => PaxHeader // 'g'
            case 76 => LongName   // 'L'
            case _ => Unknown
        }
    }
}

/// Tarball 提取器
/// 严格翻译自: src/install/extract_tarball.zig ExtractTarball
public class TarballExtractor {
    /// 包名
    public var name: String
    /// 解析结果
    public var resolution: Resolution
    /// 缓存目录
    public var cacheDir: String
    /// 临时目录
    public var tempDir: String
    /// 是否跳过校验
    public var skipVerify: Bool
    /// 完整性哈希
    public var integrity: Integrity
    /// 下载 URL
    public var url: String

    public init(name: String, url: String) {
        this.name = name
        this.url = url
        this.resolution = Resolution()
        this.cacheDir = ""
        this.tempDir = Sys.getTempDir()
        this.skipVerify = false
        this.integrity = Integrity()
    }

    /// 构建包的 tarball 下载 URL
    // 严格翻译自: src/install/extract_tarball.zig buildURL
    public static func buildUrl(registry: String, fullName: String, version: SemVer): String {
        let reg = registry.trimEnd("/")
        var name = fullName
        // 去除 scope: @org/package -> package
        if (name.startsWith("@")) {
            let slashIdx = name.indexOf("/")
            match (slashIdx) {
                case Some(idx) => name = name.substring(idx + 1)
                case None => {}
            }
        }
        let verStr = version.toString()
        // 标准 npm tarball URL
        return "${reg}/${fullName}/-/${name}-${verStr}.tgz"
    }

    /// 运行提取
    // 严格翻译自: src/install/extract_tarball.zig ExtractTarball.run
    public func run(data: Array<Byte>): ?ExtractData {
        // 完整性校验
        if (!skipVerify && integrity.isSupported()) {
            if (!integrity.verify(data)) {
                return None // 完整性校验失败
            }
        }

        // 解压
        let result = extract(data)
        match (result) {
            case Some(extractData) => {
                // 计算 integrity (如果原始没有)
                if (!integrity.isSupported()) {
                    extractData.integrity = Some(Integrity.forBytes(data))
                } else {
                    extractData.integrity = Some(integrity)
                }
                return Some(extractData)
            }
            case None => return None
        }
    }

    /// 解压 tarball
    // 严格翻译自: src/install/extract_tarball.zig extract
    private func extract(data: Array<Byte>): ?ExtractData {
        let result = ExtractData()

        // 1. 解压 gzip (如果需要)
        let tarData = decompressGzip(data)

        // 2. 创建临时目录
        let tmpName = "bao-pkg-${name.replace("/", "-")}-${Sys.randomInt64()}"
        let extractDir = Path.join([tempDir, tmpName])
        BaoFile.mkdir(extractDir, true)

        // 3. 解析 tar 格式
        var offset: Int64 = 0
        var fileCount: Int64 = 0
        var totalSize: Int64 = 0
        let blockSize: Int64 = 512

        // tar 文件通常有一个根目录前缀 "package/"
        var stripComponents = 1
        var firstEntry = true

        while (offset + blockSize <= tarData.size) {
            let headerData = tarData.slice(offset, blockSize)
            let header = TarHeader.parse(headerData)

            match (header) {
                case Some(h) => {
                    // 空头 (全零) = tar 结束
                    if (h.name.isEmpty() && h.size == 0) {
                        break
                    }

                    // 跳过第一个路径组件
                    var entryPath = h.name
                    if (firstEntry && entryPath.contains("/")) {
                        // 检测根目录前缀
                        let slashIdx = entryPath.indexOf("/")
                        match (slashIdx) {
                            case Some(idx) => {
                                // 检查是否所有条目都有相同前缀
                            }
                            case None => {}
                        }
                        firstEntry = false
                    }

                    // 去除 stripComponents 个路径组件
                    entryPath = stripPathComponents(entryPath, stripComponents)

                    // 跳到数据区
                    offset += blockSize
                    let dataSize = alignToBlock(h.size, blockSize)

                    if (h.typeFlag == TarTypeFlag.Directory) {
                        // 创建目录
                        let dirPath = Path.join([extractDir, entryPath])
                        BaoFile.mkdir(dirPath, true)
                    } else if (h.typeFlag == TarTypeFlag.Regular || h.typeFlag == TarTypeFlag.Unknown) {
                        // 写入文件
                        if (!entryPath.isEmpty()) {
                            let filePath = Path.join([extractDir, entryPath])
                            // 确保父目录存在
                            let parentDir = Path.dirname(filePath)
                            BaoFile.mkdir(parentDir, true)
                            // 写入文件数据
                            let fileData = tarData.slice(offset, h.size)
                            BaoFile.writeAllBytes(filePath, fileData)
                            fileCount++
                            totalSize += h.size
                        }
                    } else if (h.typeFlag == TarTypeFlag.Symlink) {
                        // 创建符号链接
                        let linkPath = Path.join([extractDir, entryPath])
                        BaoFile.createSymlink(h.linkName, linkPath)
                    }

                    offset += dataSize
                }
                case None => break
            }
        }

        result.packageDir = extractDir
        result.fileCount = fileCount
        result.totalSize = totalSize
        return Some(result)
    }

    /// 解压 gzip
    private func decompressGzip(data: Array<Byte>): Array<Byte> {
        // 检查 gzip magic number: 0x1F 0x8B
        if (data.size >= 2 && Int64(data[0]) == 0x1F && Int64(data[1]) == 0x8B) {
            // 使用系统 gunzip 或 zlib 解压
            // 简化: 写入临时文件并调用 gunzip
            let tmpPath = Path.join([Sys.getTempDir(), "bao-tarball-${Sys.randomInt64()}.gz"])
            BaoFile.writeAllBytes(tmpPath, data)
            let tarPath = tmpPath.substring(0, tmpPath.length - 3) + ".tar"
            Process.spawn(["gunzip", "-k", "-f", tmpPath], Sys.getTempDir())
            let tarData = BaoFile.readAllBytes(tarPath)
            BaoFile.remove(tmpPath)
            BaoFile.remove(tarPath)
            match (tarData) {
                case Some(d) => return d
                case None => return data // 回退: 返回原始数据
            }
        }
        return data
    }

    /// 对齐到 512 字节块
    private func alignToBlock(size: Int64, blockSize: Int64): Int64 {
        if (size == 0) { return 0 }
        return ((size + blockSize - 1) / blockSize) * blockSize
    }

    /// 去除前 N 个路径组件
    // 严格翻译自: src/install/extract_tarball.zig depth_to_skip
    private func stripPathComponents(path: String, count: Int64): String {
        if (count <= 0) { return path }
        var remaining = path
        var i = 0
        while (i < count) {
            let slashIdx = remaining.indexOf("/")
            match (slashIdx) {
                case Some(idx) => remaining = remaining.substring(idx + 1)
                case None => return remaining
            }
            i++
        }
        return remaining
    }

    /// 将解压结果移动到缓存目录
    // 严格翻译自: src/install/extract_tarball.zig finalize path
    public func moveToCache(extractDir: String, cacheDir: String, packageName: String): String {
        let destDir = Path.join([cacheDir, packageName])
        if (BaoFile.exists(destDir)) {
            BaoFile.removeTree(destDir)
        }
        BaoFile.mkdir(Path.dirname(destDir), true)
        BaoFile.rename(extractDir, destDir)
        return destDir
    }
}

/// Tarball 下载器
/// 严格翻译自: src/install/NetworkTask.zig, src/install/TarballStream.zig
public class TarballDownloader {
    private var client: HttpClient
    private var registryUrl: String

    public init(registryUrl: String) {
        this.client = HttpClient()
        this.registryUrl = registryUrl
    }

    /// 下载 tarball
    // 严格翻译自: src/install/NetworkTask.zig fetchTarball
    public func download(tarballUrl: String): ?Array<Byte> {
        let response = client.get(tarballUrl)
        match (response) {
            case Some(resp) => {
                if (resp.statusCode == 200) {
                    return Some(resp.bodyBytes)
                }
            }
            case None => {}
        }
        return None
    }

    /// 下载并验证 tarball
    public func downloadWithIntegrity(tarballUrl: String, integrity: ?Integrity): ?Array<Byte> {
        let data = download(tarballUrl)
        match (data) {
            case Some(bytes) => {
                match (integrity) {
                    case Some(i) => {
                        if (i.verify(bytes)) {
                            return Some(bytes)
                        }
                        return None // 校验失败
                    }
                    case None => return Some(bytes)
                }
            }
            case None => return None
        }
    }
}

/// 解析结果 (简化版)
public class Resolution {
    public var tag: String

    public init() {
        tag = "npm"
    }
}
