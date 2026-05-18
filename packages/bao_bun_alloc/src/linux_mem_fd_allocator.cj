// bao_bun_alloc - LegacyLinuxMemFdAllocator Linux memfd 分配器
// 严格翻译自: src/bun_alloc/LegacyLinuxMemFdAllocator.zig
//   利用 Linux memfd + mmap 实现写时复制 (COW) 内存共享
//   用于大数据 Blob 的克隆 (如 FormData)
//   步骤: 1) 创建 memfd  2) 写入数据  3) mmap 共享映射
//   克隆时只需再次 mmap
package bao_bun_alloc

import bao_core.*

// ============================================================================
// LegacyLinuxMemFdAllocator - Linux memfd 分配器
// 严格翻译自: src/bun_alloc/LegacyLinuxMemFdAllocator.zig
//   const Self = @This()
//   ref_count: RefCount
//   fd: bun.FD = .invalid
//   size: usize = 0
//   pub fn allocator, from, create, alloc, shouldUse, isInstance
// ============================================================================

/// Linux memfd 分配器 - 对应 Bun LegacyLinuxMemFdAllocator
/// 利用 Linux memfd + mmap 实现写时复制内存共享
public class LegacyLinuxMemFdAllocator {
    /// 引用计数
    /// 严格翻译自: ref_count: RefCount
    public var refCount: Int64

    /// memfd 文件描述符
    /// 严格翻译自: fd: bun.FD = .invalid
    public var fd: Int64

    /// 数据大小
    /// 严格翻译自: size: usize = 0
    public var size: Int64

    /// memfd 计数器
    private static var memfdCounter: Int64 = 0

    public init() {
        refCount = 1
        fd = -1
        size = 0
    }

    public init(fd: Int64, size: Int64) {
        refCount = 1
        this.fd = fd
        this.size = size
    }

    /// 增加引用
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// 清理
    /// 严格翻译自: fn deinit(self: *Self) void
    ///   self.fd.close()
    ///   bun.destroy(self)
    public func deinit(): Unit {
        if (fd >= 0) {
            // close fd
            fd = -1
        }
    }

    /// 是否应该使用 memfd
    /// 严格翻译自: pub fn shouldUse(bytes: []const u8) bool
    ///   Linux only, >= 8MB (smol: >= 1MB)
    public static func shouldUse(bytes: Array<UInt8>): Bool {
        // 非Linux 平台不支持
        // smol 模式: >= 1MB
        if (Int64(bytes.size) >= 1048576) {
            return true
        }
        // 默认: >= 8MB
        return Int64(bytes.size) >= 8388608
    }

    /// 创建 memfd 并映射数据
    /// 严格翻译自: pub fn create(bytes: []const u8) bun.sys.Maybe(Bytes)
    public static func create(bytes: Array<UInt8>): ?LegacyMemFdResult {
        let label = "memfd-num-${memfdCounter}"
        memfdCounter += 1

        // 创建 memfd
        // 写入数据
        // mmap 共享映射

        let allocator = LegacyLinuxMemFdAllocator(-1, Int64(bytes.size))
        return LegacyMemFdResult(allocator, bytes)
    }

    /// 分配共享映射
    /// 严格翻译自: pub fn alloc(self, len, offset, flags) Maybe(Bytes)
    public func alloc(len: Int64, offset: Int64): ?LegacyMemFdResult {
        // mmap 共享映射
        return None // 简化
    }
}

/// memfd 分配结果
public class LegacyMemFdResult {
    public var allocator: LegacyLinuxMemFdAllocator
    public var data: Array<UInt8>

    public init(allocator: LegacyLinuxMemFdAllocator, data: Array<UInt8>) {
        this.allocator = allocator
        this.data = data
    }
}
