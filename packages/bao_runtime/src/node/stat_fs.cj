// StatFS 和 BigIntStatFS 文件系统状态类
// 对应 Bun: src/runtime/node/StatFS.zig
// 严格翻译自: src/runtime/node/StatFS.zig
package bao_runtime

// ============================================================================
// StatFS 类 — 文件系统统计信息
// 对应 Bun: src/runtime/node/StatFS.zig - StatFSType(false) - StatFSSmall
// ============================================================================
public class StatFS {
    public var fstype: Int32 = 0   // 文件系统类型
    public var bsize: Int32 = 0    // 块大小
    public var blocks: Int32 = 0   // 总块数
    public var bfree: Int32 = 0    // 空闲块数
    public var bavail: Int32 = 0   // 可用块数
    public var files: Int32 = 0    // 总文件节点数
    public var ffree: Int32 = 0    // 空闲文件节点数

    public init() {}

    public init(fstype: Int32, bsize: Int32, blocks: Int32, bfree: Int32,
                bavail: Int32, files: Int32, ffree: Int32) {
        this.fstype = fstype
        this.bsize = bsize
        this.blocks = blocks
        this.bfree = bfree
        this.bavail = bavail
        this.files = files
        this.ffree = ffree
    }
}

// ============================================================================
// BigIntStatFS 类 — 文件系统统计信息（64位）
// 对应 Bun: src/runtime/node/StatFS.zig - StatFSType(true) - StatFSBig
// ============================================================================
public class BigIntStatFS {
    public var fstype: Int64 = 0
    public var bsize: Int64 = 0
    public var blocks: Int64 = 0
    public var bfree: Int64 = 0
    public var bavail: Int64 = 0
    public var files: Int64 = 0
    public var ffree: Int64 = 0

    public init() {}

    public init(fstype: Int64, bsize: Int64, blocks: Int64, bfree: Int64,
                bavail: Int64, files: Int64, ffree: Int64) {
        this.fstype = fstype
        this.bsize = bsize
        this.blocks = blocks
        this.bfree = bfree
        this.bavail = bavail
        this.files = files
        this.ffree = ffree
    }
}

// ============================================================================
// StatFS 工厂
// 对应 Bun: src/runtime/node/StatFS.zig - StatFS union
// ============================================================================
public class StatFSFactory {
    // 从平台 statfs 数据创建 StatFS
    public static func create(bigint: Bool, ftype: Int64, bsize: Int64, blocks: Int64,
                              bfree: Int64, bavail: Int64, files: Int64, ffree: Int64): StatFS {
        return StatFS(fstype: Int32(ftype), bsize: Int32(bsize), blocks: Int32(blocks),
                      bfree: Int32(bfree), bavail: Int32(bavail), files: Int32(files), ffree: Int32(ffree))
    }

    public static func createBigInt(ftype: Int64, bsize: Int64, blocks: Int64,
                                     bfree: Int64, bavail: Int64, files: Int64, ffree: Int64): BigIntStatFS {
        return BigIntStatFS(fstype: ftype, bsize: bsize, blocks: blocks,
                           bfree: bfree, bavail: bavail, files: files, ffree: ffree)
    }
}
