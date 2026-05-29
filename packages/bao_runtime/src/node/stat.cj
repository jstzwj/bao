// Stats 和 BigIntStats 文件状态类
// 对应 Bun: src/runtime/node/Stat.zig
// 严格翻译自: src/runtime/node/Stat.zig
package bao_runtime.node

import bao_jsc.*

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
    public var atimeMs: Float64 = 0.0  // 最后访问时间（毫秒）
    public var mtimeMs: Float64 = 0.0  // 最后修改时间（毫秒）
    public var ctimeMs: Float64 = 0.0  // 最后状态变更时间（毫秒）
    public var birthtimeMs: Float64 = 0.0 // 创建时间（毫秒）

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

    // 转换为 JS 对象
    // 对应 Bun: Stat.zig - StatType(false).toJS
    public func toJS(globalObject: JsGlobalObject): JsValue {
        let obj = JsObject()
        obj.set("dev", JsValue(Int64(dev)))
        obj.set("ino", JsValue(Int64(ino)))
        obj.set("mode", JsValue(Int64(mode)))
        obj.set("nlink", JsValue(Int64(nlink)))
        obj.set("uid", JsValue(Int64(uid)))
        obj.set("gid", JsValue(Int64(gid)))
        obj.set("rdev", JsValue(Int64(rdev)))
        obj.set("size", JsValue(Int64(size)))
        obj.set("blksize", JsValue(Int64(blksize)))
        obj.set("blocks", JsValue(Int64(blocks)))
        obj.set("atimeMs", JsValue(atimeMs))
        obj.set("mtimeMs", JsValue(mtimeMs))
        obj.set("ctimeMs", JsValue(ctimeMs))
        obj.set("birthtimeMs", JsValue(birthtimeMs))
        obj.set("atime", JsValue(atimeMs))
        obj.set("mtime", JsValue(mtimeMs))
        obj.set("ctime", JsValue(ctimeMs))
        obj.set("birthtime", JsValue(birthtimeMs))
        // 文件类型判断方法 — 使用 nativeFunction 绑定为可调用函数
        // 对应 Bun: Stat.zig - Bun__createJSStatsObject (C++ creates native methods)
        let capturedMode = this.mode
        obj.set("isFile", JsValue.nativeFunction("isFile", { _ =>
            JsValue((capturedMode & 0xF000) == 0x8000)
        }))
        obj.set("isDirectory", JsValue.nativeFunction("isDirectory", { _ =>
            JsValue((capturedMode & 0xF000) == 0x4000)
        }))
        obj.set("isSymbolicLink", JsValue.nativeFunction("isSymbolicLink", { _ =>
            JsValue((capturedMode & 0xF000) == 0xA000)
        }))
        obj.set("isBlockDevice", JsValue.nativeFunction("isBlockDevice", { _ =>
            JsValue((capturedMode & 0xF000) == 0x6000)
        }))
        obj.set("isCharacterDevice", JsValue.nativeFunction("isCharacterDevice", { _ =>
            JsValue((capturedMode & 0xF000) == 0x2000)
        }))
        obj.set("isFIFO", JsValue.nativeFunction("isFIFO", { _ =>
            JsValue((capturedMode & 0xF000) == 0x1000)
        }))
        obj.set("isSocket", JsValue.nativeFunction("isSocket", { _ =>
            JsValue((capturedMode & 0xF000) == 0xC000)
        }))
        return JsValue(obj)
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

    // 转换为 JS 对象
    // 对应 Bun: Stat.zig - StatType(true).toJS
    public func toJS(globalObject: JsGlobalObject): JsValue {
        let obj = JsObject()
        obj.set("dev", JsValue(Int64(dev)))
        obj.set("ino", JsValue(Int64(ino)))
        obj.set("mode", JsValue(Int64(mode)))
        obj.set("nlink", JsValue(Int64(nlink)))
        obj.set("uid", JsValue(Int64(uid)))
        obj.set("gid", JsValue(Int64(gid)))
        obj.set("rdev", JsValue(Int64(rdev)))
        obj.set("size", JsValue(Int64(size)))
        obj.set("blksize", JsValue(Int64(blksize)))
        obj.set("blocks", JsValue(Int64(blocks)))
        obj.set("atimeMs", JsValue(atimeMs))
        obj.set("mtimeMs", JsValue(mtimeMs))
        obj.set("ctimeMs", JsValue(ctimeMs))
        obj.set("birthtimeMs", JsValue(birthtimeMs))
        obj.set("atimeNs", JsValue(Int64(atimeNs)))
        obj.set("mtimeNs", JsValue(Int64(mtimeNs)))
        obj.set("ctimeNs", JsValue(Int64(ctimeNs)))
        obj.set("birthtimeNs", JsValue(Int64(birthtimeNs)))
        // 文件类型判断方法 — 使用 nativeFunction 绑定为可调用函数
        // 对应 Bun: Stat.zig - Bun__createJSBigIntStatsObject (C++ creates native methods)
        let capturedMode = this.mode
        obj.set("isFile", JsValue.nativeFunction("isFile", { _ =>
            JsValue((capturedMode & 0xF000) == 0x8000)
        }))
        obj.set("isDirectory", JsValue.nativeFunction("isDirectory", { _ =>
            JsValue((capturedMode & 0xF000) == 0x4000)
        }))
        obj.set("isSymbolicLink", JsValue.nativeFunction("isSymbolicLink", { _ =>
            JsValue((capturedMode & 0xF000) == 0xA000)
        }))
        obj.set("isBlockDevice", JsValue.nativeFunction("isBlockDevice", { _ =>
            JsValue((capturedMode & 0xF000) == 0x6000)
        }))
        obj.set("isCharacterDevice", JsValue.nativeFunction("isCharacterDevice", { _ =>
            JsValue((capturedMode & 0xF000) == 0x2000)
        }))
        obj.set("isFIFO", JsValue.nativeFunction("isFIFO", { _ =>
            JsValue((capturedMode & 0xF000) == 0x1000)
        }))
        obj.set("isSocket", JsValue.nativeFunction("isSocket", { _ =>
            JsValue((capturedMode & 0xF000) == 0xC000)
        }))
        return JsValue(obj)
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
        return Stats(dev, ino, mode, nlink,
                     uid, gid, rdev, size,
                     blksize, blocks,
                     atimeMs, mtimeMs, ctimeMs, birthtimeMs)
    }

    public static func createBigInt(dev: UInt64, ino: UInt64, mode: UInt64,
                                     nlink: UInt64, uid: UInt64, gid: UInt64, rdev: UInt64,
                                     size: UInt64, blksize: UInt64, blocks: UInt64,
                                     atimeMs: Int64, mtimeMs: Int64, ctimeMs: Int64,
                                     birthtimeMs: Int64,
                                     atimeNs: UInt64, mtimeNs: UInt64, ctimeNs: UInt64,
                                     birthtimeNs: UInt64): BigIntStats {
        return BigIntStats(dev, ino, mode, nlink,
                          uid, gid, rdev, size,
                          blksize, blocks,
                          atimeMs, mtimeMs, ctimeMs, birthtimeMs,
                          atimeNs, mtimeNs, ctimeNs, birthtimeNs)
    }
}
