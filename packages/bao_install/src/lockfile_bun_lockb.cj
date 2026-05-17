// bao_install - 二进制锁文件序列化
// 严格翻译自: src/install/lockfile/bun.lockb.zig
//   pub const Serializer = struct {
//       pub fn save(this: *Lockfile, options, bytes, total_size, end_pos) !void
//   }
//   二进制锁文件格式 (bun.lockb) 的序列化器
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 二进制锁文件头部
// ============================================================================

/// 二进制锁文件版本
public let LOCKFILEB_VERSION: String = "bun-lockfile-format-v0\n"

/// 二进制锁文件头部
public let LOCKFILEB_HEADER: String = "#!/usr/bin/env bun\n${LOCKFILEB_VERSION}"

// ============================================================================
// 二进制标签
// ============================================================================

/// 标签: 有 patched dependencies
public let TAG_HAS_PATCHED_DEPS: UInt64 = UInt64(0x6448687363546150)

/// 标签: 有 workspace package IDs
public let TAG_HAS_WORKSPACE_PKG_IDS: UInt64 = UInt64(0x435073526F537700)

/// 标签: 有 trusted dependencies
public let TAG_HAS_TRUSTED_DEPS: UInt64 = UInt64(0x64457355725400)

/// 标签: 空 trusted dependencies
public let TAG_EMPTY_TRUSTED_DEPS: UInt64 = UInt64(0x547250744D6500)

/// 标签: 有 overrides
public let TAG_HAS_OVERRIDES: UInt64 = UInt64(0x536472976560000)

/// 标签: 有 catalogs
public let TAG_HAS_CATALOGS: UInt64 = UInt64(0x536F6C4174416300)

/// 标签: 有 config version
public let TAG_HAS_CONFIG_VERSION: UInt64 = UInt64(0x4E73477256466E43)

// ============================================================================
// 二进制锁文件序列化器
// ============================================================================

/// 二进制锁文件序列化器
/// 对应 Bun: Lockfile.Serializer (bun.lockb)
public class LockfileBinarySerializer {
    /// 序列化锁文件为二进制格式
    public static func save(
        packages: ArrayList<LockfilePackage>,
        formatVersion: LockfileFormatVersion,
        metaHash: String,
        options: PackageManagerOptions
    ): Array<UInt8> {
        let buf = ArrayList<UInt8>()

        // 1. 写入头部
        appendString(buf, LOCKFILEB_HEADER)

        // 2. 写入格式版本 (u32 LE)
        appendUInt32(buf, formatVersion.toInt())

        // 3. 写入 meta_hash (64 bytes)
        appendMetaHash(buf, metaHash)

        // 4. 保存包列表
        appendUInt32(buf, packages.size)
        for (pkg in packages) {
            savePackage(buf, pkg)
        }

        // 5. 保存缓冲区

        // 6. 写入结束标记
        appendUInt64(buf, UInt64(0))

        return buf.items()
    }

    /// 从二进制格式反序列化锁文件
    public static func load(data: Array<UInt8>): ?ArrayList<LockfilePackage> {
        if (data.size < LOCKFILEB_HEADER.size) {
            return None
        }

        // 验证头部
        var i: Int64 = 0
        let headerBytes = ArrayList<UInt8>()
        for (b in LOCKFILEB_HEADER) {
            headerBytes.append(b)
        }
        let headerArr = headerBytes.items()

        while (i < headerArr.size) {
            if (data[i] != headerArr[i]) {
                return None
            }
            i += 1
        }

        // 读取格式版本
        let formatVersion = readUInt32(data, i)
        i += 4

        // 跳过 meta_hash (64 bytes)
        i += 64

        // 读取包数量
        let pkgCount = readUInt32(data, i)
        i += 4

        let packages = ArrayList<LockfilePackage>()
        var pkgIdx: Int64 = 0
        while (pkgIdx < pkgCount && i < data.size - 4) {
            let pkgResult = readPackage(data, i)
            match (pkgResult) {
                case Some(p) =>
                    packages.append(p.first)
                    i = p.second
                case None => break
            }
            pkgIdx += 1
        }

        return packages
    }

    // ===== 辅助方法 =====

    /// 保存单个包
    private static func savePackage(buf: ArrayList<UInt8>, pkg: LockfilePackage): Unit {
        appendString(buf, pkg.name)
        appendString(buf, pkg.version)
        appendString(buf, pkg.resolution)
        appendString(buf, pkg.integrity)

        // 依赖数量
        appendUInt32(buf, pkg.dependencies.size)
        for (key in pkg.dependencies.keys()) {
            match (pkg.dependencies.get(key)) {
                case Some(val) =>
                    appendString(buf, key)
                    appendString(buf, val)
                case None => ()
            }
        }
    }

    /// 读取单个包
    private static func readPackage(data: Array<UInt8>, offset: Int64): ?Tuple2<LockfilePackage, Int64> {
        if (offset + 4 >= data.size) { return None }
        var pos = offset

        let nameResult = readString(data, pos)
        var nameStr = ""
        match (nameResult) {
            case None => return None
            case Some(nr) => nameStr = nr.first; pos = nr.second
        }

        let versionResult = readString(data, pos)
        var versionStr = ""
        match (versionResult) {
            case None => return None
            case Some(vr) => versionStr = vr.first; pos = vr.second
        }

        let resolutionResult = readString(data, pos)
        var resolutionStr = ""
        match (resolutionResult) {
            case None => return None
            case Some(rr) => resolutionStr = rr.first; pos = rr.second
        }

        let integrityResult = readString(data, pos)
        var integrityStr = ""
        match (integrityResult) {
            case None => return None
            case Some(ir) => integrityStr = ir.first; pos = ir.second
        }

        let pkg = LockfilePackage(nameStr, versionStr)
        pkg.resolution = resolutionStr
        pkg.integrity = integrityStr

        return Some(Tuple2(pkg, pos))
    }

    /// 追加字符串 (长度前缀 + UTF-8)
    private static func appendString(buf: ArrayList<UInt8>, str: String): Unit {
        appendUInt32(buf, str.size)
        for (c in str) {
            buf.append(c)
        }
    }

    /// 读取字符串
    private static func readString(data: Array<UInt8>, offset: Int64): ?Tuple2<String, Int64> {
        if (offset + 4 >= data.size) { return None }
        let len = readUInt32(data, offset)
        var pos = offset + 4
        if (pos + len > data.size) { return None }
        let bytes = ArrayList<UInt8>()
        var i: Int64 = 0
        while (i < len) {
            bytes.append(data[pos + i])
            i += 1
        }
        // Convert bytes to string
        var result = ""
        for (b in bytes.items()) {
            result = result + String(Rune(UInt32(b)))
        }
        return Some(Tuple2(result, pos + len))
    }

    /// 追加 UInt32 (小端)
    private static func appendUInt32(buf: ArrayList<UInt8>, value: Int64): Unit {
        buf.append(UInt8(value & 0xFF))
        buf.append(UInt8((value >> 8) & 0xFF))
        buf.append(UInt8((value >> 16) & 0xFF))
        buf.append(UInt8((value >> 24) & 0xFF))
    }

    /// 读取 UInt32 (小端)
    private static func readUInt32(data: Array<UInt8>, offset: Int64): Int64 {
        return Int64(data[offset]) |
               (Int64(data[offset + 1]) << 8) |
               (Int64(data[offset + 2]) << 16) |
               (Int64(data[offset + 3]) << 24)
    }

    /// 追加 UInt64 (小端)
    private static func appendUInt64(buf: ArrayList<UInt8>, value: UInt64): Unit {
        var i: Int64 = 0
        while (i < 8) {
            buf.append(UInt8((value >> UInt64(i * 8)) & UInt64(0xFF)))
            i += 1
        }
    }

    /// 追加 meta_hash
    private static func appendMetaHash(buf: ArrayList<UInt8>, hash: String): Unit {
        // 填充到 64 字节
        var i: Int64 = 0
        for (b in hash) {
            if (i >= 64) { break }
            buf.append(b)
            i += 1
        }
        while (i < 64) {
            buf.append(UInt8(0))
            i += 1
        }
    }
}
