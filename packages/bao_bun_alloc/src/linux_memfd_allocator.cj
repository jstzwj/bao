// 严格翻译自: src/bun_alloc/LinuxMemFdAllocator.zig
// linux_memfd_allocator.cj - Linux memfd 分配器
// 使用 copy-on-write 内存避免实际复制大数据

package bao_bun_alloc

import bao_core.*

// ============================================================================
// LinuxMemFdAllocator - Linux memfd 分配器
// 对应 Zig: src/bun_alloc/LinuxMemFdAllocator.zig
// 利用 Linux memfd 实现写时复制 (copy-on-write)
// 步骤:
//   1. 创建 memfd
//   2. 将数据写入 memfd
//   3. 将 memfd 映射到内存
// 然后，克隆数据只需再次调用 mmap
// ============================================================================

/// memfd 计数器 (原子变量)
/// 对应 Zig: var memfd_counter = std.atomic.Value(usize).init(0)
private var memfdCounter: AtomicUInt64 = AtomicUInt64(0)

/// Linux memfd 分配器
/// 对应 Zig: const Self = @This()
public class LinuxMemFdAllocator {

    /// 引用计数
    /// 对应 Zig: ref_count: RefCount
    private var refCount: AtomicInt32 = AtomicInt32(1)

    /// 文件描述符
    /// 对应 Zig: fd: bun.FD = .invalid
    private var fd: FileDescriptor = FileDescriptor.invalid()

    /// 数据大小
    /// 对应 Zig: size: usize = 0
    private var size: UInt64 = 0

    /// 增加引用计数
    /// 对应 Zig: pub const ref = RefCount.ref
    public func ref(): Unit {
        this.refCount.fetchAdd(1, MemoryOrder.relaxed)
    }

    /// 减少引用计数
    /// 对应 Zig: pub const deref = RefCount.deref
    public func deref(): Unit {
        if (this.refCount.fetchSub(1, MemoryOrder.acqRel) == 1) {
            this.deinit()
        }
    }

    /// 销毁
    /// 对应 Zig: fn deinit(self: *Self) void
    private func deinit(): Unit {
        this.fd.close()
    }

    /// 获取分配器接口
    /// 对应 Zig: pub fn allocator(self: *Self) std.mem.Allocator
    public func allocator(): Allocator {
        return Allocator.fromContext(
            CPointer<Byte>.fromObject(this),
            MemFdAllocatorVTable.get()
        )
    }

    /// 从分配器获取 LinuxMemFdAllocator
    /// 对应 Zig: pub fn from(allocator_: std.mem.Allocator) ?*Self
    public static func from(allocator: Allocator): ?LinuxMemFdAllocator {
        if (allocator.getBackend() == AllocatorBackend.linuxMemFd) {
            return LinuxMemFdAllocator.fromPointer(allocator.getContext())
        }
        return None
    }

    /// 分配内存 (mmap)
    /// 对应 Zig: pub fn alloc(self: *Self, len: usize, offset: usize, flags: std.posix.MAP) bun.sys.Maybe(bun.webcore.Blob.Store.Bytes)
    public func alloc(len: UInt64, offset: UInt64, flags: MMapFlags): SyscallResult<MemFdBytes> {
        var size = len

        // 向上对齐到页大小
        size = MemoryUtils.alignForward(size, MemoryUtils.pageSize())

        // 确保 MAP_SHARED 标志
        var flagsMut = flags
        flagsMut.setTypeShared()

        let result = Syscall.mmap(
            CPointer<Byte>.null(),
            Math.min(size, this.size),
            MMapProt.readWrite(),
            flagsMut,
            this.fd,
            offset
        )

        switch (result) {
            case .result(let slice) =>
                return SyscallResult.result(MemFdBytes(
                    cap: UInt32(slice.size),
                    ptr: CPointer<Byte>.fromArray(slice),
                    len: UInt32(len),
                    allocator: this.allocator()
                ))
            case .err(let errno) =>
                return SyscallResult.err(errno)
        }
    }

    /// 判断是否应使用 memfd
    /// 对应 Zig: pub fn shouldUse(bytes: []const u8) bool
    public static func shouldUse(bytes: Array<Byte>): Bool {
        if (!Environment.isLinux) {
            return false
        }

        if (!Syscall.canUseMemfd()) {
            return false
        }

        if (VirtualMachine.isSmolMode) {
            return UInt64(bytes.size) >= 1024 * 1024 * 1
        }

        // 对于 new Blob([huge]) 来说是 2x-4x 的净减速
        // 所以必须小心
        return UInt64(bytes.size) >= 1024 * 1024 * 8
    }

    /// 创建 memfd 并写入数据
    /// 对应 Zig: pub fn create(bytes: []const u8) bun.sys.Maybe(bun.webcore.Blob.Store.Bytes)
    public static func create(bytes: Array<Byte>): SyscallResult<MemFdBytes> {
        if (!Environment.isLinux) {
            panic("unreachable: LinuxMemFdAllocator.create on non-Linux")
        }

        let counter = memfdCounter.fetchAdd(1, MemoryOrder.monotonic)
        let label = "memfd-num-${counter}"

        // 使用 huge pages 更慢
        let fdResult = Syscall.memfdCreate(label, MemFdCreateFlags.nonExecutable())
        let fd = switch (fdResult) {
            case .result(let f) => f
            case .err(let err) => return SyscallResult.err(SyscallError.fromCode(err.getErrno(), SyscallOperation.open))
        }

        if (bytes.size > 0) {
            // 提示文件大小
            _ = Syscall.ftruncate(fd, UInt64(bytes.size))
        }

        // 将所有字节写入 memfd
        var written: Int64 = 0
        var remainStart: Int64 = 0
        var remainLen: Int64 = bytes.size

        while (remainLen > 0) {
            let remainSlice = bytes.slice(remainStart, remainLen)
            let writeResult = Syscall.pwrite(fd, remainSlice, written)
            switch (writeResult) {
                case .err(let err) =>
                    if (err.getErrno() == Errno.AGAIN) {
                        continue
                    }
                    Output.debugWarn("Failed to write to memfd: ${err}", [])
                    fd.close()
                    return SyscallResult.err(err)
                case .result(let result) =>
                    if (result == 0) {
                        Output.debugWarn("Failed to write to memfd: EOF", [])
                        fd.close()
                        return SyscallResult.err(SyscallError.fromCode(Errno.NOMEM, SyscallOperation.write))
                    }
                    written += result
                    remainStart += result
                    remainLen -= result
            }
        }

        let linuxMemFdAllocator = LinuxMemFdAllocator()
        linuxMemFdAllocator.fd = fd
        linuxMemFdAllocator.refCount = AtomicInt32(1)
        linuxMemFdAllocator.size = UInt64(bytes.size)

        let allocResult = linuxMemFdAllocator.alloc(UInt64(bytes.size), 0, MMapFlags.shared())
        switch (allocResult) {
            case .result(let res) =>
                return SyscallResult.result(res)
            case .err(let err) =>
                linuxMemFdAllocator.deref()
                return SyscallResult.err(err)
        }
    }

    /// 检查是否为 LinuxMemFdAllocator 实例
    /// 对应 Zig: pub fn isInstance(allocator_: std.mem.Allocator) bool
    public static func isInstance(allocator: Allocator): Bool {
        return allocator.getBackend() == AllocatorBackend.linuxMemFd
    }
}

// ============================================================================
// MemFdAllocatorVTable - memfd 分配器虚表
// 对应 Zig: const AllocatorInterface = struct { ... }
// ============================================================================

/// memfd 分配器虚表
/// 对应 Zig: AllocatorInterface
/// 此分配器不执行实际分配或 resize
/// free 会执行 munmap
public class MemFdAllocatorVTable {
    private static let instance: MemFdAllocatorVTable = MemFdAllocatorVTable()

    public static func get(): MemFdAllocatorVTable {
        return instance
    }

    /// 分配 (不执行实际分配)
    /// 对应 Zig: fn alloc(...) ?[*]u8 { return null }
    public static func vtableAlloc(ctx: CPointer<Byte>, len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        // 不执行分配或 resize
        return None
    }

    /// resize (不支持)
    /// 对应 Zig: .resize = &std.mem.Allocator.noResize
    public static func vtableResize(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): Bool {
        return false
    }

    /// remap (不支持)
    /// 对应 Zig: .remap = &std.mem.Allocator.noRemap
    public static func vtableRemap(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): ?Array<Byte> {
        return None
    }

    /// 释放 (执行 munmap)
    /// 对应 Zig: fn free(...) void
    public static func vtableFree(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        let self: LinuxMemFdAllocator = LinuxMemFdAllocator.fromPointer(ctx)
        defer {
            self.deref()
        }
        let munmapResult = Syscall.munmap(CPointer<Byte>.fromArray(buf))
        switch (munmapResult) {
            case .err(let err) =>
                Output.debugWarn("Failed to munmap memfd: ${err}", [])
            case .result => ()
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// memfd 分配的字节结果
/// 对应 Zig: bun.webcore.Blob.Store.Bytes
public struct MemFdBytes {
    /// 容量
    public var cap: UInt32
    /// 指针
    public var ptr: CPointer<Byte>
    /// 长度
    public var len: UInt32
    /// 分配器
    public var allocator: Allocator
}

/// MMap 标志
public struct MMapFlags {
    private var value: UInt64

    public init(value: UInt64) {
        this.value = value
    }

    /// 设置为 SHARED 类型
    public mutating func setTypeShared(): Unit {
        this.value = this.value | MMapFlags.MAP_SHARED
    }

    /// 创建共享映射标志
    public static func shared(): MMapFlags {
        return MMapFlags(value: MAP_SHARED)
    }

    /// MAP_SHARED 常量
    public static let MAP_SHARED: UInt64 = 0x01
    /// MAP_PRIVATE 常量
    public static let MAP_PRIVATE: UInt64 = 0x02
}

/// MMap 保护标志
public struct MMapProt {
    private var value: UInt64

    public init(value: UInt64) {
        this.value = value
    }

    /// 读写保护
    public static func readWrite(): MMapProt {
        return MMapProt(value: PROT_READ | PROT_WRITE)
    }

    /// PROT_READ
    public static let PROT_READ: UInt64 = 0x1
    /// PROT_WRITE
    public static let PROT_WRITE: UInt64 = 0x2
}

/// memfd_create 标志
public struct MemFdCreateFlags {
    private var value: UInt64

    /// 不可执行标志
    public static func nonExecutable(): MemFdCreateFlags {
        return MemFdCreateFlags(value: MFD_CLOEXEC | MFD_NOEXEC_SEAL)
    }

    /// MFD_CLOEXEC
    public static let MFD_CLOEXEC: UInt64 = 0x0001
    /// MFD_NOEXEC_SEAL
    public static let MFD_NOEXEC_SEAL: UInt64 = 0x0008
}
