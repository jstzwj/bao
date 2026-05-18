// 严格翻译自: src/sys/PosixStat.zig
//   POSIX-like stat structure with birthtime support for node:fs
//   Mirrors libuv's uv_stat_t (all uint64_t fields)
package bao_sys

import bao_core.*

// ============================================================================
// Timespec - 时间规格
// 严格翻译自: bun.timespec
//   pub const timespec = extern struct { sec: isize, nsec: isize }
// ============================================================================

/// 时间规格 - 对应 Bun bun.timespec / POSIX struct timespec
public class Timespec {
    /// 秒 - tv_sec
    public var sec: Int64
    /// 纳秒 - tv_nsec
    public var nsec: Int64

    public init() {
        sec = 0
        nsec = 0
    }

    public init(sec: Int64, nsec: Int64) {
        this.sec = sec
        this.nsec = nsec
    }

    /// Epoch (零值) - 对应 Bun timespec.epoch
    public static let epoch: Timespec = Timespec(0, 0)

    /// 转为毫秒
    public func toMillis(): Int64 {
        return sec * 1000 + nsec / 1000000
    }

    /// 转为秒 (浮点, 含纳秒部分)
    public func toSeconds(): Float64 {
        return Float64(sec) + Float64(nsec) / 1000000000.0
    }
}

// ============================================================================
// StatxField - Linux statx 字段掩码
// 严格翻译自: src/sys/sys.zig:614-627
//   pub const StatxField = enum(comptime_int) { type, mode, nlink, ... }
// ============================================================================

/// statx 字段掩码 - 对应 Linux STATX_* 常量
/// Bun: pub const StatxField = enum(comptime_int) { ... }
public class StatxField {
    public static let TYPE: UInt32 = 0x00000001     // STATX_TYPE
    public static let MODE: UInt32 = 0x00000002     // STATX_MODE
    public static let NLINK: UInt32 = 0x00000004    // STATX_NLINK
    public static let UID: UInt32 = 0x00000008      // STATX_UID
    public static let GID: UInt32 = 0x00000010      // STATX_GID
    public static let ATIME: UInt32 = 0x00000020    // STATX_ATIME
    public static let MTIME: UInt32 = 0x00000040    // STATX_MTIME
    public static let CTIME: UInt32 = 0x00000080    // STATX_CTIME
    public static let BTIME: UInt32 = 0x00000100    // STATX_BTIME
    public static let INO: UInt32 = 0x00000200      // STATX_INO
    public static let SIZE: UInt32 = 0x00000400     // STATX_SIZE
    public static let BLOCKS: UInt32 = 0x00000800   // STATX_BLOCKS

    /// 常用字段集
    public static let BASIC_STATS: UInt32 = TYPE | MODE | NLINK |
        UID | GID | ATIME | MTIME |
        CTIME | INO | SIZE | BLOCKS

    /// 全部字段
    public static let ALL: UInt32 = BASIC_STATS | BTIME
}

// ============================================================================
// StatxTimestamp - statx 时间戳
// 严格翻译自: Linux struct statx_timestamp
//   struct statx_timestamp { __s64 tv_sec; __u32 tv_nsec; ... }
// ============================================================================

/// statx 时间戳 - 对应 Linux struct statx_timestamp
public class StatxTimestamp {
    public var sec: Int64
    public var nsec: UInt32

    public init() {
        sec = 0
        nsec = 0
    }

    public init(sec: Int64, nsec: UInt32) {
        this.sec = sec
        this.nsec = nsec
    }

    public func toTimespec(): Timespec {
        return Timespec(sec, Int64(nsec))
    }
}

// ============================================================================
// PosixStat - POSIX stat 结构 (增强版)
// 严格翻译自: src/sys/PosixStat.zig:4-77
//   pub const PosixStat = extern struct {
//       dev, ino, mode, nlink, uid, gid, rdev, size, blksize, blocks,
//       atim, mtim, ctim, birthtim
//   }
//
//   注意: package.cj 中已有简化版 PosixStat 类,
//   此文件提供完整版本, 包含 birthtime (创建时间) 和 statx 相关功能
//   对应 libuv 的 uv_stat_t (全部 uint64_t 字段)
// ============================================================================

/// POSIX stat 结构 (增强版) - 严格对应 Bun PosixStat
/// Bun: extern struct, 所有字段为 u64
/// Mirrors libuv's uv_stat_t so native -> JS conversion matches Node.js exactly
public class PosixStatFull {
    /// 设备 ID - st_dev
    public var dev: UInt64
    /// inode 号 - st_ino
    public var ino: UInt64
    /// 文件模式 (包含类型位) - st_mode
    public var mode: UInt64
    /// 硬链接数 - st_nlink
    public var nlink: UInt64
    /// 用户 ID - st_uid
    public var uid: UInt64
    /// 组 ID - st_gid
    public var gid: UInt64
    /// 设备 ID (特殊文件) - st_rdev
    public var rdev: UInt64
    /// 文件大小 (字节) - st_size
    public var size: UInt64
    /// 块大小 - st_blksize
    public var blksize: UInt64
    /// 块数 - st_blocks
    public var blocks: UInt64

    /// 访问时间 - st_atim
    public var atim: Timespec
    /// 修改时间 - st_mtim
    public var mtim: Timespec
    /// 元数据改变时间 - st_ctim
    public var ctim: Timespec
    /// 创建时间 (birth time) - 可能为零 (不支持时)
    public var birthtim: Timespec

    public init() {
        dev = 0
        ino = 0
        mode = 0
        nlink = 0
        uid = 0
        gid = 0
        rdev = 0
        size = 0
        blksize = 0
        blocks = 0
        atim = Timespec()
        mtim = Timespec()
        ctim = Timespec()
        birthtim = Timespec()
    }

    /// 完整构造
    public init(dev: UInt64, ino: UInt64, mode: UInt64, nlink: UInt64,
                uid: UInt64, gid: UInt64, rdev: UInt64, size: UInt64,
                blksize: UInt64, blocks: UInt64,
                atim: Timespec, mtim: Timespec, ctim: Timespec, birthtim: Timespec) {
        this.dev = dev
        this.ino = ino
        this.mode = mode
        this.nlink = nlink
        this.uid = uid
        this.gid = gid
        this.rdev = rdev
        this.size = size
        this.blksize = blksize
        this.blocks = blocks
        this.atim = atim
        this.mtim = mtim
        this.ctim = ctim
        this.birthtim = birthtim
    }

    /// 从 statx 数据构建 (Linux)
    /// 对应 Bun: statxImpl 中从 linux.Statx buf 构建 PosixStat
    /// 以及 makedev 编码: (major << 8) | (minor & 0xFF) | ((minor & 0xFFF00) << 12)
    public static func fromStatx(devMajor: UInt32, devMinor: UInt32,
                                  ino: UInt64, mode: UInt32, nlink: UInt32,
                                  uid: UInt32, gid: UInt32,
                                  rdevMajor: UInt32, rdevMinor: UInt32,
                                  size: UInt64, blksize: UInt32, blocks: UInt64,
                                  atime: StatxTimestamp, mtime: StatxTimestamp,
                                  ctime: StatxTimestamp, btime: StatxTimestamp,
                                  mask: UInt32): PosixStatFull {
        return PosixStatFull(
            makedev(devMajor, devMinor),
            ino,
            UInt64(mode),
            UInt64(nlink),
            UInt64(uid),
            UInt64(gid),
            makedev(rdevMajor, rdevMinor),
            size,
            UInt64(blksize),
            blocks,
            atime.toTimespec(),
            mtime.toTimespec(),
            ctime.toTimespec(),
            if ((mask & StatxField.BTIME) != 0) { btime.toTimespec() } else { Timespec() }
        )
    }

    /// 访问时间
    /// 对应 Bun: pub fn atime(self: *const PosixStat) bun.timespec
    public func atime(): Timespec {
        return atim
    }

    /// 修改时间
    /// 对应 Bun: pub fn mtime(self: *const PosixStat) bun.timespec
    public func mtime(): Timespec {
        return mtim
    }

    /// 元数据改变时间
    /// 对应 Bun: pub fn ctime(self: *const PosixStat) bun.timespec
    public func ctime(): Timespec {
        return ctim
    }

    /// 创建时间
    /// 对应 Bun: pub fn birthtime(self: *const PosixStat) bun.timespec
    public func birthtime(): Timespec {
        return birthtim
    }

    /// 是否为普通文件 - S_ISREG
    public func isFile(): Bool {
        return (mode & 0xF000) == 0x8000
    }

    /// 是否为目录 - S_ISDIR
    public func isDirectory(): Bool {
        return (mode & 0xF000) == 0x4000
    }

    /// 是否为符号链接 - S_ISLNK
    public func isSymlink(): Bool {
        return (mode & 0xF000) == 0xA000
    }

    /// 是否为 FIFO - S_ISFIFO
    public func isFifo(): Bool {
        return (mode & 0xF000) == 0x1000
    }

    /// 是否为 socket - S_ISSOCK
    public func isSocket(): Bool {
        return (mode & 0xF000) == 0xC000
    }

    /// 是否为字符设备 - S_ISCHR
    public func isCharDevice(): Bool {
        return (mode & 0xF000) == 0x2000
    }

    /// 是否为块设备 - S_ISBLK
    public func isBlockDevice(): Bool {
        return (mode & 0xF000) == 0x6000
    }
}

// ============================================================================
// makedev - Linux 设备号编码
// 严格翻译自: src/sys/sys.zig:674-678
//   inline fn makedev(major: u32, minor: u32) u64
//   From glibc sys/sysmacros.h and Linux kernel <linux/kdev_t.h>
//   dev_t layout (64 bits):
//     Bits 31-20: major high (12 bits)
//     Bits 19-8:  minor high (12 bits)
//     Bits 7-0:   minor low (8 bits)
// ============================================================================

/// Linux makedev 编码 - 对应 Bun sys.makedev
/// 从 major/minor 设备号合成 dev_t
public func makedev(major: UInt32, minor: UInt32): UInt64 {
    let maj: UInt64 = UInt64(major) & 0xFFF
    let min: UInt64 = UInt64(minor) & 0xFFFFF
    return (maj << 8) | (min & 0xFF) | ((min & 0xFFF00) << 12)
}
