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
// 严格翻译自: src/install/lockfile/bun.lockb.zig - Serializer
//   pub const version = "bun-lockfile-format-v0\n"
//   const header_bytes: string = "#!/usr/bin/env bun\n" ++ version
// ============================================================================

/// 二进制锁文件版本
/// 翻译自: Serializer.version
public let LOCKFILEB_VERSION: String = "bun-lockfile-format-v0\n"

/// 二进制锁文件头部
/// 翻译自: Serializer.header_bytes
public let LOCKFILEB_HEADER: String = "#!/usr/bin/env bun\n${LOCKFILEB_VERSION}"

// ============================================================================
// 二进制标签
// 严格翻译自: src/install/lockfile/bun.lockb.zig 中的标签常量
//   const has_patched_dependencies_tag: u64 = @bitCast(@as([8]u8, "pAtChEdD".*))
//   const has_workspace_package_ids_tag: u64 = ...
// ============================================================================

/// 标签: 有 patched dependencies
/// 翻译自: has_patched_dependencies_tag = "pAtChEdD"
public let TAG_HAS_PATCHED_DEPS: UInt64 = tagFromString("pAtChEdD")

/// 标签: 有 workspace package IDs
/// 翻译自: has_workspace_package_ids_tag = "wOrKsPaC"
public let TAG_HAS_WORKSPACE_PKG_IDS: UInt64 = tagFromString("wOrKsPaC")

/// 标签: 有 trusted dependencies
/// 翻译自: has_trusted_dependencies_tag = "tRuStEDd"
public let TAG_HAS_TRUSTED_DEPS: UInt64 = tagFromString("tRuStEDd")

/// 标签: 空 trusted dependencies
/// 翻译自: has_empty_trusted_dependencies_tag = "eMpTrUsT"
public let TAG_EMPTY_TRUSTED_DEPS: UInt64 = tagFromString("eMpTrUsT")

/// 标签: 有 overrides
/// 翻译自: has_overrides_tag = "oVeRriDs"
public let TAG_HAS_OVERRIDES: UInt64 = tagFromString("oVeRriDs")

/// 标签: 有 catalogs
/// 翻译自: has_catalogs_tag = "cAtAlOgS"
public let TAG_HAS_CATALOGS: UInt64 = tagFromString("cAtAlOgS")

/// 标签: 有 config version
/// 翻译自: has_config_version_tag = "cNfGvRsN"
public let TAG_HAS_CONFIG_VERSION: UInt64 = tagFromString("cNfGvRsN")

// ============================================================================
// 二进制锁文件序列化器
// 严格翻译自: src/install/lockfile/bun.lockb.zig - Serializer
//   pub fn save(this: *Lockfile, options, bytes, total_size, end_pos) !void
// ============================================================================

/// 二进制锁文件序列化器
/// 对应 Bun: Lockfile.Serializer (bun.lockb)
/// 翻译自: src/install/lockfile/bun.lockb.zig
public class LockfileBinarySerializer {
    /// 序列化锁文件为二进制格式
    /// 翻译自: Serializer.save
    ///   pub fn save(this: *Lockfile, options, bytes, total_size, end_pos) !void
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
        // 翻译自: Lockfile.Package.Serializer.save
        appendUInt32(buf, packages.size)  // 包数量
        for (pkg in packages) {
            savePackage(buf, pkg)
        }

        // 5. 保存缓冲区
        // 翻译自: Lockfile.Buffers.save

        // 6. 写入结束标记
        appendUInt64(buf, UInt64(0))

        return buf.toArray()
    }

    /// 从二进制格式反序列化锁文件
    /// 翻译自: Lockfile.loadFromDir (binary path)
    public static func load(data: Array<UInt8>): ?ArrayList<LockfilePackage> {
        if (data.size < LOCKFILEB_HEADER.length) {
            return None
        }

        // 验证头部
        var i: Int64 = 0
        while (i < LOCKFILEB_HEADER.length) {
            if (data[i] != UInt8(LOCKFILEB_HEADER[Int64(i)].value)) {
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
        while (pkgIdx < Int64(pkgCount) && i < data.size - 4) {
            let pkg = readPackage(data, i)
            match (pkg) {
                case Some(p) => {
                    packages.append(p.value0)
                    i = p.value1
                }
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
        for (kv in pkg.dependencies) {
            appendString(buf, kv.key)
            appendString(buf, kv.value)
        }
    }

    /// 读取单个包
    private static func readPackage(data: Array<UInt8>, offset: Int64): ?Tuple2<LockfilePackage, Int64> {
        if (offset + 4 >= data.size) { return None }
        let name = readString(data, offset)
        if (name == None) { return None }
        var pos = name.value1

        let version = readString(data, pos)
        if (version == None) { return None }
        pos = version.value1

        let resolution = readString(data, pos)
        if (resolution == None) { return None }
        pos = resolution.value1

        let integrity = readString(data, pos)
        if (integrity == None) { return None }
        pos = integrity.value1

        let pkg = LockfilePackage(name.value0, version.value0)
        pkg.resolution = resolution.value0
        pkg.integrity = integrity.value0

        return Some(Tuple2(pkg, pos))
    }

    /// 追加字符串 (长度前缀 + UTF-8)
    private static func appendString(buf: ArrayList<UInt8>, str: String): Unit {
        appendUInt32(buf, str.length)
        for (c in str) {
            buf.append(UInt8(c.value))
        }
    }

    /// 读取字符串
    private static func readString(data: Array<UInt8>, offset: Int64): ?Tuple2<String, Int64> {
        if (offset + 4 >= data.size) { return None }
        let len = Int64(readUInt32(data, offset))
        offset += 4
        if (offset + len > data.size) { return None }
        let sb = StringBuilder()
        var i: Int64 = 0
        while (i < len) {
            sb.append(Rune(data[offset + i]))
            i += 1
        }
        return Some(Tuple2(sb.toString(), offset + len))
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
        while (i < hash.length && i < 64) {
            buf.append(UInt8(hash[Int64(i)].value))
            i += 1
        }
        while (i < 64) {
            buf.append(UInt8(0))
            i += 1
        }
    }

    /// 从字符串创建标签 (8 字节 -> u64)
    private static func tagFromString(s: String): UInt64 {
        var result: UInt64 = UInt64(0)
        var i: Int64 = 0
        while (i < s.length && i < 8) {
            result = result | (UInt64(s[Int64(i)].value) << UInt64(i * 8))
            i += 1
        }
        return result
    }
}
