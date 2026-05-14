// bao_sys - 内存映射文件
// 严格翻译自: src/sys/mmap.zig
//   Bun 使用 mmap 将文件映射到内存以实现高效文件读取
//   仓颉通过 C FFI 调用 mmap/munmap/madvise
package bao_sys

import bao_core.*

// ============================================================================
// mmap C FFI 声明
// ============================================================================

@C
foreign func mmap(addr: CPointer<Unit>, length: UIntNative, prot: Int32,
                   flags: Int32, fd: Int32, offset: Int64): CPointer<Unit>
@C
foreign func munmap(addr: CPointer<Unit>, length: UIntNative): Int32
@C
foreign func mprotect(addr: CPointer<Unit>, length: UIntNative, prot: Int32): Int32
@C
foreign func madvise(addr: CPointer<Unit>, length: UIntNative, advice: Int32): Int32
@C
foreign func msync(addr: CPointer<Unit>, length: UIntNative, flags: Int32): Int32

// ============================================================================
// mmap 常量
// ============================================================================

/// 内存保护常量 - 对应 PROT_*
public class MmapProt {
    public static let PROT_NONE: Int32 = 0
    public static let PROT_READ: Int32 = 1
    public static let PROT_WRITE: Int32 = 2
    public static let PROT_EXEC: Int32 = 4
}

/// mmap 标志 - 对应 MAP_*
public class MmapFlags {
    public static let MAP_SHARED: Int32 = 0x01
    public static let MAP_PRIVATE: Int32 = 0x02
    public static let MAP_FIXED: Int32 = 0x10
    public static let MAP_ANONYMOUS: Int32 = 0x20
    public static let MAP_POPULATE: Int32 = 0x8000
}

/// madvise 建议 - 对应 MADV_*
public class MmapAdvice {
    public static let MADV_NORMAL: Int32 = 0
    public static let MADV_RANDOM: Int32 = 1
    public static let MADV_SEQUENTIAL: Int32 = 2
    public static let MADV_WILLNEED: Int32 = 3
    public static let MADV_DONTNEED: Int32 = 4
    public static let MADV_HUGEPAGE: Int32 = 14
}

/// msync 标志 - 对应 MS_*
public class MsyncFlags {
    public static let MS_SYNC: Int32 = 4
    public static let MS_ASYNC: Int32 = 1
    public static let MS_INVALIDATE: Int32 = 2
}

// ============================================================================
// MmapFile - 内存映射文件
// 严格翻译自: src/sys/mmap.zig BaoMmapFile
// ============================================================================

/// 内存映射文件 - 对应 Bun MmapFile
/// 将整个文件映射到内存中进行高效读取
public class MmapFile {
    /// 映射内存指针
    private var ptr: CPointer<Unit>
    /// 映射大小
    private var mapSize: Int64
    /// 文件描述符
    private var fd: Int64
    /// 是否已取消映射
    private var unmapped: Bool

    private init(ptr: CPointer<Unit>, size: Int64, fd: Int64) {
        this.ptr = ptr
        this.mapSize = size
        this.fd = fd
        this.unmapped = false
    }

    /// 从文件路径创建映射
    /// 对应 Bun: MmapFile.open(path)
    public static func open(path: String): SysMaybe<MmapFile> {
        // 1. 获取文件大小
        let sizeResult = SysFs.getFileSize(path)
        match (sizeResult) {
            case Err(e) => return SysMaybe<MmapFile>.Err(e)
            case Ok(size) =>
                if (size == 0) {
                    return SysMaybe<MmapFile>.Err(
                        SysError(22, SysTag.Open, path))  // EINVAL
                }
                // 2. 打开文件
                let fdResult = SysFs.openRead(path)
                match (fdResult) {
                    case Err(e) => return SysMaybe<MmapFile>.Err(e)
                    case Ok(fd) =>
                        // 3. mmap
                        unsafe {
                            let mapped = mmap(CPointer<Unit>(),
                                               UIntNative(size),
                                               MmapProt.PROT_READ,
                                               MmapFlags.MAP_PRIVATE,
                                               Int32(fd), Int64(0))
                            if (mapped.isNull()) {
                                SysFs.close(fd)
                                return SysMaybe<MmapFile>.Err(
                                    SysError(UInt16(Int64(OS.errno())), SysTag.Open, path))
                            }
                            return SysMaybe<MmapFile>.Ok(MmapFile(mapped, Int64(size), fd))
                        }
                }
        }
    }

    /// 获取映射大小
    public func size(): Int64 {
        return mapSize
    }

    /// 读取指定位置的字节
    /// 对应 Bun: MmapFile.slice(offset, len)
    public func readByte(offset: Int64): UInt8 {
        if (offset >= mapSize || unmapped) {
            return UInt8(0)
        }
        unsafe {
            let bytePtr = CPointer<UInt8>(ptr) + IntNative(offset)
            return bytePtr.read()
        }
    }

    /// 读取一段数据
    public func readBytes(offset: Int64, length: Int64): Array<UInt8> {
        var result = Array<UInt8>()
        if (unmapped) { return result }
        let end = if (offset + length > mapSize) { mapSize } else { offset + length }
        unsafe {
            for (i in offset..end) {
                let bytePtr = CPointer<UInt8>(ptr) + IntNative(i)
                result.append(bytePtr.read())
            }
        }
        return result
    }

    /// 获取原始指针
    public func ptr(): CPointer<Unit> {
        return ptr
    }

    /// 给出内存访问建议
    /// 对应 Bun: madvise(addr, len, MADV_SEQUENTIAL)
    public func advise(advice: Int32): Unit {
        if (!unmapped && mapSize > 0) {
            madvise(ptr, UIntNative(mapSize), advice)
        }
    }

    /// 同步到磁盘 (如果 MAP_SHARED)
    public func sync(flags: Int32): SysMaybe<Unit> {
        if (unmapped) {
            return SysMaybe<Unit>.Err(SysError(9, SysTag.Fsync))
        }
        let rc = msync(ptr, UIntNative(mapSize), flags)
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.Fsync))
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 取消映射并关闭文件
    /// 对应 Bun: MmapFile.close()
    public func close(): Unit {
        if (!unmapped) {
            if (!ptr.isNull() && mapSize > 0) {
                munmap(ptr, UIntNative(mapSize))
            }
            SysFs.close(fd)
            unmapped = true
        }
    }
}

/// mmap 工具函数
public class MmapUtils {
    /// 创建匿名内存映射
    /// 对应 Bun: 用于大型缓冲区分配
    public static func allocAnonymous(size: Int64): ?CPointer<Unit> {
        unsafe {
            let ptr = mmap(CPointer<Unit>(), UIntNative(size),
                           MmapProt.PROT_READ | MmapProt.PROT_WRITE,
                           MmapFlags.MAP_PRIVATE | MmapFlags.MAP_ANONYMOUS,
                           Int32(-1), Int64(0))
            if (ptr.isNull()) {
                return None
            }
            return Some(ptr)
        }
    }

    /// 释放匿名映射
    public static func free(ptr: CPointer<Unit>, size: Int64): Unit {
        munmap(ptr, UIntNative(size))
    }
}
