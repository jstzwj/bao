// Stats 和 BigIntStats 文件状态类
// 对应 Bun: src/runtime/node/Stat.zig
// 严格翻译自: src/runtime/node/Stat.zig
package bao_runtime.node

// ============================================================================
// Stats 类 — 文件状态信息（使用浮点时间）
// 对应 Bun: src/runtime/node/Stat.zig - StatType(false) - StatsSmall
// ============================================================================
public class Stats {
    public var dev: UInt64 = 0       // 设备 ID
    public var ino: UInt64 = 0       // inode 号
    public var mode: UInt64 = 0      // 文件模式
    public var nlink: UInt64 = 0     // 硬链接数
    public var uid: UInt64 = 0       // 用户 ID
    public var gid: UInt64 = 0       // 组 ID
    public var rdev: UInt64 = 0      // 特殊设备 ID
    public var size: UInt64 = 0      // 文件大小（字节）
    public var blksize: UInt64 = 0   // 块大小
    public var blocks: UInt64 = 0    // 分配的块数
    public var atimeMs: Float64 = 0  // 最后访问时间（毫秒）
    public var mtimeMs: Float64 = 0  // 最后修改时间（毫秒）
    public var ctimeMs: Float64 = 0  // 最后状态变更时间（毫秒）
    public var birthtimeMs: Float64 = 0 // 创建时间（毫秒）

    public init() {}

    public init(dev: UInt64, ino: UInt64, mode: UInt64, nlink: UInt64,
                uid: UInt64, gid: UInt64, rdev: UInt64, size: UInt64,
                blksize: UInt64, blocks: UInt64,
                atimeMs: Float64, mtimeMs: Float64, ctimeMs: Float64, birthtimeMs: Float64) {
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
        this.atimeMs = atimeMs
        this.mtimeMs = mtimeMs
        this.ctimeMs = ctimeMs
        this.birthtimeMs = birthtimeMs
    }

    // 文件类型判断方法
    public func isFile(): Bool {
        return (mode & 0xF000) == 0x8000  // S_IFREG
    }

    public func isDirectory(): Bool {
        return (mode & 0xF000) == 0x4000  // S_IFDIR
    }

    public func isSymbolicLink(): Bool {
        return (mode & 0xF000) == 0xA000  // S_IFLNK
    }

    public func isBlockDevice(): Bool {
        return (mode & 0xF000) == 0x6000  // S_IFBLK
    }

    public func isCharacterDevice(): Bool {
        return (mode & 0xF000) == 0x2000  // S_IFCHR
    }

    public func isFIFO(): Bool {
        return (mode & 0xF000) == 0x1000  // S_IFIFO
    }

    public func isSocket(): Bool {
        return (mode & 0xF000) == 0xC000  // S_IFSOCK
    }
}

// ============================================================================
// BigIntStats 类 — 文件状态信息（使用整数时间）
// 对应 Bun: src/runtime/node/Stat.zig - StatType(true) - StatsBig
// ============================================================================
public class BigIntStats {
    public var dev: UInt64 = 0
    public var ino: UInt64 = 0
    public var mode: UInt64 = 0
    public var nlink: UInt64 = 0
    public var uid: UInt64 = 0
    public var gid: UInt64 = 0
    public var rdev: UInt64 = 0
    public var size: UInt64 = 0
    public var blksize: UInt64 = 0
    public var blocks: UInt64 = 0
    public var atimeMs: Int64 = 0
    public var mtimeMs: Int64 = 0
    public var ctimeMs: Int64 = 0
    public var birthtimeMs: Int64 = 0
    public var atimeNs: UInt64 = 0
    public var mtimeNs: UInt64 = 0
    public var ctimeNs: UInt64 = 0
    public var birthtimeNs: UInt64 = 0

    public init() {}

    public init(dev: UInt64, ino: UInt64, mode: UInt64, nlink: UInt64,
                uid: UInt64, gid: UInt64, rdev: UInt64, size: UInt64,
                blksize: UInt64, blocks: UInt64,
                atimeMs: Int64, mtimeMs: Int64, ctimeMs: Int64, birthtimeMs: Int64,
                atimeNs: UInt64, mtimeNs: UInt64, ctimeNs: UInt64, birthtimeNs: UInt64) {
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
        this.atimeMs = atimeMs
        this.mtimeMs = mtimeMs
        this.ctimeMs = ctimeMs
        this.birthtimeMs = birthtimeMs
        this.atimeNs = atimeNs
        this.mtimeNs = mtimeNs
        this.ctimeNs = ctimeNs
        this.birthtimeNs = birthtimeNs
    }

    public func isFile(): Bool {
        return (mode & 0xF000) == 0x8000
    }

    public func isDirectory(): Bool {
        return (mode & 0xF000) == 0x4000
    }

    public func isSymbolicLink(): Bool {
        return (mode & 0xF000) == 0xA000
    }

    public func isBlockDevice(): Bool {
        return (mode & 0xF000) == 0x6000
    }

    public func isCharacterDevice(): Bool {
        return (mode & 0xF000) == 0x2000
    }

    public func isFIFO(): Bool {
        return (mode & 0xF000) == 0x1000
    }

    public func isSocket(): Bool {
        return (mode & 0xF000) == 0xC000
    }
}

// ============================================================================
// Stats 工厂 — 根据是否使用 BigInt 创建对应类型
// 对应 Bun: src/runtime/node/Stat.zig - Stats union
// ============================================================================
public class StatsFactory {
    // 从 POSIX stat 创建 Stats 或 BigIntStats
    public static func create(bigint: Bool, dev: UInt64, ino: UInt64, mode: UInt64,
                              nlink: UInt64, uid: UInt64, gid: UInt64, rdev: UInt64,
                              size: UInt64, blksize: UInt64, blocks: UInt64,
                              atimeMs: Float64, mtimeMs: Float64, ctimeMs: Float64,
                              birthtimeMs: Float64): Stats {
        return Stats(dev: dev, ino: ino, mode: mode, nlink: nlink,
                     uid: uid, gid: gid, rdev: rdev, size: size,
                     blksize: blksize, blocks: blocks,
                     atimeMs: atimeMs, mtimeMs: mtimeMs, ctimeMs: ctimeMs, birthtimeMs: birthtimeMs)
    }

    public static func createBigInt(dev: UInt64, ino: UInt64, mode: UInt64,
                                     nlink: UInt64, uid: UInt64, gid: UInt64, rdev: UInt64,
                                     size: UInt64, blksize: UInt64, blocks: UInt64,
                                     atimeMs: Int64, mtimeMs: Int64, ctimeMs: Int64,
                                     birthtimeMs: Int64,
                                     atimeNs: UInt64, mtimeNs: UInt64, ctimeNs: UInt64,
                                     birthtimeNs: UInt64): BigIntStats {
        return BigIntStats(dev: dev, ino: ino, mode: mode, nlink: nlink,
                          uid: uid, gid: gid, rdev: rdev, size: size,
                          blksize: blksize, blocks: blocks,
                          atimeMs: atimeMs, mtimeMs: mtimeMs, ctimeMs: ctimeMs, birthtimeMs: birthtimeMs,
                          atimeNs: atimeNs, mtimeNs: mtimeNs, ctimeNs: ctimeNs, birthtimeNs: birthtimeNs)
    }
}
