package bao_bun_alloc

public enum MemoryOrder {
    | relaxed
    | monotonic
    | acqRel
}

public class Mutex {
    public init() {}
    public func lock(): Unit {}
    public func unlock(): Unit {}
}

public class AtomicInt16 {
    private var value: Int16

    public init(value: Int16) {
        this.value = value
    }

    public func fetchAdd(delta: Int16, order: MemoryOrder): Int16 {
        let old = value
        value = Int16(Int64(value) + Int64(delta))
        return old
    }
}

public class AtomicInt32 {
    private var value: Int32

    public init(value: Int32) {
        this.value = value
    }

    public func fetchAdd(delta: Int32, order: MemoryOrder): Int32 {
        let old = value
        value = Int32(Int64(value) + Int64(delta))
        return old
    }

    public func fetchSub(delta: Int32, order: MemoryOrder): Int32 {
        let old = value
        value = Int32(Int64(value) - Int64(delta))
        return old
    }
}

public class AtomicUInt64 {
    private var value: UInt64

    public init(value: UInt64) {
        this.value = value
    }

    public func fetchAdd(delta: UInt64, order: MemoryOrder): UInt64 {
        let old = value
        value += delta
        return old
    }
}

public type UIntPtr = UInt64

public type Byte = UInt8

public enum AllocatorBackend {
    | default
    | libc
    | zeroInitialized
    | singleAllocation
    | maxHeap
    | allocationScope
    | heapZone
    | linuxMemFd
}

public class AllocatorVTable {
    public init() {}
}

public class Allocator {
    private var context: CPointer<Byte>
    private var vtable: Any
    private var backend: AllocatorBackend

    public init() {
        context = CPointer<Byte>()
        vtable = AllocatorVTable()
        backend = AllocatorBackend.default
    }

    public init(context: CPointer<Byte>, vtable: Any, backend: AllocatorBackend) {
        this.context = context
        this.vtable = vtable
        this.backend = backend
    }

    public static func fromContext(context: CPointer<Byte>, vtable: Any): Allocator {
        return Allocator(context, vtable, AllocatorBackend.default)
    }

    public static func default(): Allocator {
        return Allocator()
    }

    public static func libc(): Allocator {
        return Allocator(CPointer<Byte>(), AllocatorVTable(), AllocatorBackend.libc)
    }

    public static func zeroInitialized(): Allocator {
        return Allocator(CPointer<Byte>(), AllocatorVTable(), AllocatorBackend.zeroInitialized)
    }

    public func getContext(): CPointer<Byte> {
        return context
    }

    public func getVTable(): Any {
        return vtable
    }

    public func getBackend(): AllocatorBackend {
        return backend
    }

    public func rawAlloc(len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        return Some(Array<Byte>(Int64(len), repeat: UInt8(0)))
    }

    public func rawResize(buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): Bool {
        return UInt64(buf.size) >= newLen
    }

    public func rawFree(buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {}

    public func free(buf: Array<Byte>): Unit {}
}

public enum Alignment {
    | Byte1
    | Byte2
    | Byte4
    | Byte8
    | Byte16
    | Byte32
    | Byte64
    | Page

    public func toByteUnits(): UInt64 {
        match (this) {
            case Byte1 => 1
            case Byte2 => 2
            case Byte4 => 4
            case Byte8 => 8
            case Byte16 => 16
            case Byte32 => 32
            case Byte64 => 64
            case Page => 4096
        }
    }

    public static func fromByteUnits(bytes: UInt64): Alignment {
        if (bytes <= 1) { return Alignment.Byte1 }
        if (bytes <= 2) { return Alignment.Byte2 }
        if (bytes <= 4) { return Alignment.Byte4 }
        if (bytes <= 8) { return Alignment.Byte8 }
        if (bytes <= 16) { return Alignment.Byte16 }
        if (bytes <= 32) { return Alignment.Byte32 }
        if (bytes <= 64) { return Alignment.Byte64 }
        return Alignment.Page
    }
}

public class FileDescriptor {
    public var value: Int64

    public init(value: Int64) {
        this.value = value
    }

    public static func invalid(): FileDescriptor {
        return FileDescriptor(-1)
    }

    public func close(): Unit {}
}

public enum Errno {
    | AGAIN
    | NOMEM
}

public enum SyscallOperation {
    | open
    | write
    | mmap
    | munmap
}

public class SyscallError {
    private var errno: Errno
    private var operation: SyscallOperation

    public init(errno: Errno, operation: SyscallOperation) {
        this.errno = errno
        this.operation = operation
    }

    public static func fromCode(errno: Errno, operation: SyscallOperation): SyscallError {
        return SyscallError(errno, operation)
    }

    public func getErrno(): Errno {
        return errno
    }
}

public enum SyscallResult<T> {
    | result(T)
    | err(SyscallError)
}

public class Syscall {
    public static func canUseMemfd(): Bool { return false }

    public static func mmap(addr: CPointer<Byte>, len: UInt64, prot: MMapProt, flags: MMapFlags, fd: FileDescriptor, offset: UInt64): SyscallResult<Array<Byte>> {
        return SyscallResult.result(Array<Byte>(Int64(len), repeat: UInt8(0)))
    }

    public static func munmap(ptr: CPointer<Byte>): SyscallResult<Unit> {
        return SyscallResult.result(())
    }

    public static func memfdCreate(label: String, flags: MemFdCreateFlags): SyscallResult<FileDescriptor> {
        return SyscallResult.result(FileDescriptor.invalid())
    }

    public static func ftruncate(fd: FileDescriptor, size: UInt64): SyscallResult<Unit> {
        return SyscallResult.result(())
    }

    public static func pwrite(fd: FileDescriptor, bytes: Array<Byte>, offset: Int64): SyscallResult<Int64> {
        return SyscallResult.result(bytes.size)
    }
}

public class MimallocHeap {
    private var ptr: CPointer<Byte>

    public init() {
        ptr = CPointer<Byte>()
    }

    public init(ptr: CPointer<Byte>) {
        this.ptr = ptr
    }

    public static func fromPointer(ptr: CPointer<Byte>): MimallocHeap {
        return MimallocHeap(ptr)
    }

    public func assertThreadLock(): Unit {}
}

public class MimallocLib {
    public static func miHeapMain(): MimallocHeap { return MimallocHeap() }
    public static func miHeapCollect(heap: MimallocHeap, force: Bool): Unit {}
    public static func miCollect(force: Bool): Unit {}
    public static func miHeapContains(heap: MimallocHeap, ptr: CPointer<Byte>): Bool { return false }
    public static func mustUseAlignedAlloc(alignment: Alignment): Bool { return alignment.toByteUnits() > 8 }
    public static func miHeapMallocAligned(heap: MimallocHeap, len: UInt64, alignment: UInt64): ?CPointer<Byte> { return None }
    public static func miHeapMalloc(heap: MimallocHeap, len: UInt64): ?CPointer<Byte> { return None }
    public static func miMallocUsableSize(ptr: CPointer<Byte>): UInt64 { return 0 }
    public static func miHeapNew(): ?MimallocHeap { return Some(MimallocHeap()) }
    public static func miHeapDestroy(heap: MimallocHeap): Unit {}
    public static func miThreadStatsPrintOut(): Unit {}
    public static func miStatsPrintOut(): Unit {}
    public static func miExpand(buf: Array<Byte>, newLen: UInt64): ?Array<Byte> { return None }
    public static func miHeapReallocAligned(heap: MimallocHeap, buf: Array<Byte>, newLen: UInt64, alignment: UInt64): ?CPointer<Byte> { return None }
    public static func miFreeSizeAligned(buf: Array<Byte>, size: Int64, alignment: UInt64): Unit {}
    public static func miFreeSize(buf: Array<Byte>, size: Int64): Unit {}
    public static func miFree(buf: Array<Byte>): Unit {}
    public static func miMallocAligned(len: UInt64, alignment: UInt64): ?CPointer<Byte> { return None }
    public static func miMalloc(len: UInt64): ?CPointer<Byte> { return None }
    public static func miReallocAligned(buf: Array<Byte>, newLen: UInt64, alignment: UInt64): ?CPointer<Byte> { return None }
    public static func miZallocAligned(len: UInt64, alignment: UInt64): ?CPointer<Byte> { return None }
    public static func miZalloc(len: UInt64): ?CPointer<Byte> { return None }
    public static func miMallocSize(ptr: Array<Byte>): UInt64 { return UInt64(ptr.size) }
    public static func miFreeNullable(ptr: ?CPointer<Byte>): Unit {}
    public static func miIsInHeapRegion(buf: Array<Byte>): Bool { return true }
}

public class FeatureFlags {
    public static let helpCatchMemoryIssues: Bool = false
}

public class VirtualMachine {
    public static let isSmolMode: Bool = false
}

public class SizeOf {
    public static let USIZE: Int64 = 8
}

