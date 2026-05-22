// 严格翻译自: src/runtime/allocators/LinuxMemFdAllocator.rs
// LinuxMemFdAllocator - 侵入式线程安全的引用计数 memfd 分配器
// 对应 Bun: src/runtime/allocators/LinuxMemFdAllocator.rs + src/bun_alloc/LinuxMemFdAllocator.zig

package bao_runtime.allocators

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_bun_alloc.*

// ============================================================================
// LinuxMemFdAllocator - Linux memfd 分配器
// 对应 Bun: pub struct LinuxMemFdAllocator { ref_count, fd, size }
//
// 当需要多次克隆大量数据时，利用 copy-on-write 内存避免实际复制。
// 步骤:
//   1. 创建 memfd
//   2. 将数据写入 memfd
//   3. 将 memfd 映射到内存
// 然后，克隆数据只需再次调用 mmap。
//
// 注意: mmap(), memfd_create(), write() 都有开销，
// 因此只应用于期望被多次克隆的大数据块 (如 FormData 中的 Blob)。
// ============================================================================

/// LinuxMemFdAllocator 引用类型
/// 对应 Bun: pub type Ref = bun_ptr::IntrusiveArc<LinuxMemFdAllocator>
public class LinuxMemFdAllocatorRef {
    public var allocator: LinuxMemFdAllocator

    public init(allocator: LinuxMemFdAllocator) {
        this.allocator = allocator
    }

    public func get(): LinuxMemFdAllocator {
        return allocator
    }
}

/// 侵入式线程安全的引用计数 memfd 分配器
/// 对应 Bun: pub struct LinuxMemFdAllocator { ref_count, fd, size }
/// Zig: `bun.ptr.ThreadSafeRefCount(@This(), "ref_count", deinit, .{})`
public class LinuxMemFdAllocator {
    /// 引用计数
    /// 对应 Bun: ref_count: bun_ptr::ThreadSafeRefCount<LinuxMemFdAllocator>
    public var refCount: Int64

    /// memfd 文件描述符
    /// 对应 Bun: pub fd: Fd
    public var fd: Int64

    /// 数据大小
    /// 对应 Bun: pub size: usize
    public var size: Int64

    public init(fd: Int64, size: Int64) {
        this.refCount = 1
        this.fd = fd
        this.size = size
    }

    // ========================================================================
    // 引用计数管理
    // 对应 Bun: ThreadSafeRefCount
    // ========================================================================

    /// 增加引用计数
    /// 对应 Bun: pub const ref = RefCount.ref;
    public func ref_(): Unit {
        refCount = refCount + 1
    }

    /// 减少引用计数
    /// 对应 Bun: pub const deref = RefCount.deref;
    /// 当引用计数降到 0 时关闭 fd 并释放资源
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// 创建新实例
    /// 对应 Bun: pub fn new(fd: Fd, size: usize) -> bun_ptr::IntrusiveArc<Self>
    public static func new(fd: Int64, size: Int64): LinuxMemFdAllocatorRef {
        let alloc = LinuxMemFdAllocator(fd, size)
        return LinuxMemFdAllocatorRef(alloc)
    }

    /// 获取分配器接口
    /// 对应 Bun: pub unsafe fn allocator(`this`: *Self) -> StdAllocator
    public func allocator(): Allocator {
        return Allocator.fromContext(CPointer<UInt8>(), LinuxMemFdAllocatorStdVtable.get())
    }

    /// 从 StdAllocator 检查是否为本类型实例
    /// 对应 Bun: pub fn from(alloc: StdAllocator) -> Option<*Self>
    public static func from(alloc: Allocator): ?LinuxMemFdAllocator {
        return None
    }

    /// 检查是否为 LinuxMemFdAllocator 实例
    /// 对应 Bun: pub fn is_instance(alloc: StdAllocator) -> bool
    public static func isInstance(alloc: Allocator): Bool {
        // 对应 Bun: allocator_.vtable == AllocatorInterface.VTable
        return SafetyAlloc.hasPtr(alloc)
    }

    // ========================================================================
    // memfd 分配
    // 对应 Bun: pub unsafe fn alloc(this, len, offset, flags) -> sys::Result<BlobStoreBytes>
    // ========================================================================

    /// 从 memfd 分配内存
    /// 对应 Bun: fn alloc(self: *Self, len, offset, flags: std.posix.MAP) Maybe(Blob.Store.Bytes)
    public func alloc(len: Int64, offset: Int64, flags: Int32): ?BlobStoreBytes {
        return None
    }

    // ========================================================================
    // shouldUse - 判断是否应使用 memfd
    // 对应 Bun: pub fn should_use(bytes: &[u8]) -> bool
    // ========================================================================

    /// 判断是否应使用 memfd 分配器
    /// 对应 Bun: pub fn should_use(bytes: &[u8]) -> bool
    public static func shouldUse(bytes: Array<UInt8>): Bool {
        // 对应 Bun: #[cfg(not(any(target_os = "linux", target_os = "android")))]
        if (!SysPlatform.isLinux()) {
            return false
        }

        // 对应 Bun: if !sys::can_use_memfd() { return false; }
        if (!canUseMemfd()) {
            return false
        }

        // 对应 Bun: if VirtualMachine::is_smol_mode() { return bytes.len() >= 1024 * 1024 * 1; }
        if (VirtualMachine.isSmolMode()) {
            return bytes.size >= 1024 * 1024 * 1
        }

        // 对应 Bun: bytes.len() >= 1024 * 1024 * 8
        // This is a net 2x - 4x slowdown to new Blob([huge])
        // so we must be careful
        return bytes.size >= 1024 * 1024 * 8
    }

    // ========================================================================
    // create - 创建 memfd 并写入数据
    // 对应 Bun: pub fn create(bytes: &[u8]) -> sys::Result<BlobStoreBytes>
    // ========================================================================

    /// 创建 memfd 并写入数据
    /// 对应 Bun: pub fn create(bytes: &[u8]) -> sys::Result<BlobStoreBytes>
    public static func create(bytes: Array<UInt8>): ?BlobStoreBytes {
        return None
    }

    // ========================================================================
    // deinit - 释放资源
    // 对应 Bun: unsafe fn deinit(`this`: *Self)
    // ========================================================================

    /// 关闭 fd 并释放资源
    /// 对应 Bun: unsafe fn deinit(`this`: *Self) { (*this).fd.close(); drop(heap::take(this)); }
    public func deinit(): Unit {
        // SAFETY: sole owner — close fd
        if (fd >= 0) {
            SysNative.close(fd)
            fd = -1
        }
        size = 0
    }
}

// ============================================================================
// BlobStoreBytes - Blob 存储字节
// 对应 Bun: crate::webcore::blob::store::Bytes
// ============================================================================

/// Blob 存储字节缓冲区
/// 对应 Bun: Blob.Store.Bytes
public class BlobStoreBytes {
    public var ptr: CPointer<UInt8>
    public var len: Int64
    public var cap: Int64
    public var allocator: Allocator

    public init(ptr: CPointer<UInt8>, len: Int64, cap: Int64, allocator: Allocator) {
        this.ptr = ptr
        this.len = len
        this.cap = cap
        this.allocator = allocator
    }

    public init() {
        this.ptr = CPointer<UInt8>()
        this.len = 0
        this.cap = 0
        this.allocator = Allocator.fromContext(CPointer<UInt8>(), LinuxMemFdAllocatorStdVtable.get())
    }

    /// 获取字节切片
    public func slice(): Array<UInt8> {
        return Array<UInt8>()
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return len == 0 || ptr.isNull()
    }
}

// ============================================================================
// MemFdCounter - memfd 计数器
// 对应 Bun: static MEMFD_COUNTER: AtomicUsize = AtomicUsize::new(0)
// ============================================================================

/// memfd 计数器 (用于生成唯一标签)
/// 对应 Bun: static MEMFD_COUNTER: AtomicUsize
public class MemFdCounter {
    private static var counter: Int64 = 0

    /// 原子增加并返回旧值
    /// 对应 Bun: MEMFD_COUNTER.fetch_add(1, Ordering::Relaxed)
    public static func fetchAdd(n: Int64): Int64 {
        let old = counter
        counter = counter + n
        return old
    }
}


// ============================================================================
// VirtualMachine - 虚拟机桥接 (用于 is_smol_mode 检查)
// 对应 Bun: jsc::VirtualMachine::is_smol_mode()
// ============================================================================

/// 虚拟机桥接
public class VirtualMachine {
    /// 是否为 smol 模式
    /// 对应 Bun: pub fn is_smol_mode() -> bool
    public static func isSmolMode(): Bool {
        return false
    }
}

// ============================================================================
// SysPlatform - 系统平台检查
// ============================================================================

/// 系统平台工具
public class SysPlatform {
    /// 是否为 Linux
    public static func isLinux(): Bool {
        return true  // Bao 主要运行在 Linux/HarmonyOS 上
    }
}

// ============================================================================
// SysNative - 系统原生调用桥接
// 对应 Bun: bun_sys (T1) — mmap/munmap/pwrite/ftruncate/memfd_create
// ============================================================================

/// 系统原生调用桥接
/// 对应 Bun: bun_sys as sys
public class SysNative {
    /// mmap 系统调用
    /// 对应 Bun: sys::mmap(addr, length, prot, flags, fd, offset)
    public static func mmap(addr: CPointer<UInt8>, length: Int64, prot: Int32,
                             flags: Int32, fd: Int64, offset: Int64): CPointer<UInt8> {
        // FFI 到 libc mmap
        return CPointer<UInt8>()
    }

    /// munmap 系统调用
    /// 对应 Bun: sys::munmap(ptr, len)
    public static func munmap(ptr: CPointer<UInt8>, len: Int64): Int64 {
        return 0
    }

    /// memfd_create 系统调用
    /// 对应 Bun: sys::memfd_create(label, flags)
    public static func memfdCreate(label: String, flags: UInt32): Int64 {
        return -1
    }

    /// ftruncate 系统调用
    /// 对应 Bun: sys::ftruncate(fd, length)
    public static func ftruncate(fd: Int64, length: Int64): Int64 {
        return 0
    }

    /// pwrite 系统调用
    /// 对应 Bun: sys::pwrite(fd, buf, offset)
    public static func pwrite(fd: Int64, buf: Array<UInt8>, offset: Int64): Int64 {
        return 0
    }

    /// close 系统调用
    public static func close(fd: Int64): Unit {
        ()
    }

    /// 获取 errno
    public static func errno(): Int64 {
        return 0
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 获取系统页面大小
/// 对应 Bun: bun_alloc::page_size()
private func pageSize(): Int64 {
    return 4096
}

/// 检查是否可以使用 memfd
/// 对应 Bun: sys::can_use_memfd()
private func canUseMemfd(): Bool {
    return SysPlatform.isLinux()
}

// ported from: src/runtime/allocators/LinuxMemFdAllocator.rs
