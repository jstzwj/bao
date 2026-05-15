// 严格翻译自: src/bun_alloc/memory.zig
// memory.cj - 基础内存操作工具
// 分配、释放、重基址、切片操作等

package bao_bun_alloc

import bao_core.*

// ============================================================================
// MemoryUtils - 内存工具函数
// 对应 Zig: src/bun_alloc/memory.zig 中的所有函数
// ============================================================================

/// 内存工具函数
/// 对应 Zig: memory.zig 中的 pub fn 函数
public class MemoryUtils {

    // ========================================================================
    // create - 在堆上创建类型实例
    // 对应 Zig: pub fn create(comptime T: type, allocator: std.mem.Allocator, value: T) bun.OOM!*T
    // ========================================================================

    /// 在堆上分配类型 T 的内存，并用 value 初始化
    /// 对应 Zig: pub fn create(comptime T: type, allocator: std.mem.Allocator, value: T) bun.OOM!*T
    public static func create<T>(allocator: Allocator, value: T): ?CPointer<T> {
        if (Environment.allowAssert && AllocatorUtils.isDefault(allocator)) {
            return MemoryUtils.tryNew<T>(value)
        }
        let ptr = allocator.create<T>()
        if (ptr == None) {
            return None
        }
        MemoryUtils.writeTyped<T>(ptr.getOrThrow(), value)
        return ptr
    }

    /// tryNew 尝试在默认分配器上创建
    /// 对应 Zig: bun.tryNew(T, value)
    private static func tryNew<T>(value: T): ?CPointer<T> {
        let allocator = Allocator.default()
        let ptr = allocator.create<T>()
        if (ptr == None) {
            return None
        }
        MemoryUtils.writeTyped<T>(ptr.getOrThrow(), value)
        return ptr
    }

    // ========================================================================
    // destroy - 释放 create 创建的内存
    // 对应 Zig: pub fn destroy(allocator: std.mem.Allocator, ptr: anytype) void
    // ========================================================================

    /// 释放由 create 分配的内存
    /// 对应 Zig: pub fn destroy(allocator: std.mem.Allocator, ptr: anytype) void
    public static func destroy<T>(allocator: Allocator, ptr: CPointer<T>): Unit {
        if (Environment.allowAssert && AllocatorUtils.isDefault(allocator)) {
            MemoryUtils.destroyDefault(ptr)
        } else {
            allocator.destroy<T>(ptr)
        }
    }

    /// 默认分配器的销毁
    private static func destroyDefault<T>(ptr: CPointer<T>): Unit {
        Allocator.default().destroy<T>(ptr)
    }

    // ========================================================================
    // initDefault - 默认初始化类型 T
    // 对应 Zig: pub fn initDefault(comptime T: type) T
    // ========================================================================

    /// 默认初始化类型 T 的值
    /// 对应 Zig: pub fn initDefault(comptime T: type) T
    /// 尝试顺序:
    ///   1. .initDefault() 如果存在
    ///   2. .init() 如果存在
    ///   3. 零值初始化
    public static func initDefault<T>(): T {
        if (Reflection.hasMethod<T>("initDefault")) {
            return Reflection.callStatic<T, T>("initDefault")
        } else if (Reflection.hasMethod<T>("init")) {
            return Reflection.callStatic<T, T>("init")
        } else {
            return ZeroValue<T>()
        }
    }

    // ========================================================================
    // deinit - 递归清理
    // 对应 Zig: pub fn deinit(ptr_or_slice: anytype) void
    // ========================================================================

    /// 递归清理指针或切片
    /// 对应 Zig: pub fn deinit(ptr_or_slice: anytype) void
    ///
    /// 如果是切片，对每个元素递归调用 deinit
    /// 如果是单指针:
    ///   - 对于基本类型 (void, bool, int, float): 不做任何事
    ///   - 对于数组: 递归 deinit 每个元素
    ///   - 对于结构体: 调用其 deinit 方法
    ///   - 对于可选类型: 如果非空，递归 deinit 载荷
    /// 不释放 ptr_or_slice 本身
    public static func deinit<T>(ptr: CPointer<T>): Unit {
        let typeInfo = TypeInfo.of<T>()
        switch (typeInfo.kind) {
            case TypeKind.void_ =>
                return
            case TypeKind.bool_ =>
                return
            case TypeKind.int8 => return
            case TypeKind.int16 => return
            case TypeKind.int32 => return
            case TypeKind.int64 => return
            case TypeKind.uint8 => return
            case TypeKind.uint16 => return
            case TypeKind.uint32 => return
            case TypeKind.uint64 => return
            case TypeKind.float32 => return
            case TypeKind.float64 => return
            case TypeKind.pointer => return
            case TypeKind.enum_ => return
            case TypeKind.vector => return
            case TypeKind.array =>
                // 对数组中的每个元素递归 deinit
                let arr = CPointer<T>.toArray(ptr)
                for (i in 0..arr.size) {
                    MemoryUtils.deinitElem(arr[i])
                }
                return
            case TypeKind.struct_ =>
                // 如果有 deinit 方法且不是 void，调用它
                if (Reflection.hasMethod<T>("deinit")) {
                    Reflection.call<T, Unit>(CPointer<T>.deref(ptr), "deinit")
                }
                return
            case TypeKind.optional =>
                // 如果可选值非空，递归 deinit 载荷
                // (仓颉中用 Option 类型处理)
                return
            default =>
                return
        }
    }

    /// 递归清理切片
    /// 对应 Zig: deinit 中 .slice 分支
    public static func deinitSlice<T>(slice: Array<T>): Unit {
        for (i in 0..slice.size) {
            MemoryUtils.deinitElem(slice[i])
        }
    }

    /// 递归清理单个元素
    private static func deinitElem<T>(elem: T): Unit {
        // 简化处理: 基本类型不操作，结构体尝试调用 deinit
        if (Reflection.hasMethod<T>("deinit")) {
            Reflection.callRef<T, Unit>(elem, "deinit")
        }
    }

    // ========================================================================
    // rebaseSlice - 重基址切片
    // 对应 Zig: pub fn rebaseSlice(slice: []const u8, old_base: [*]const u8, new_base: [*]const u8) []const u8
    // ========================================================================

    /// 将切片从一个内存缓冲区重基址到另一个
    ///
    /// 给定指向基址为 old_base 的内存缓冲区的切片，
    /// 返回指向基址为 new_base 的新内存缓冲区中相同偏移的切片，
    /// 保持切片长度不变
    ///
    /// 对应 Zig: pub fn rebaseSlice
    public static func rebaseSlice(
        slice: Array<Byte>,
        oldBase: CPointer<Byte>,
        newBase: CPointer<Byte>
    ): Array<Byte> {
        let offset = CPointer<Byte>.pointerToInt(slice.getPointer()) -
                     CPointer<Byte>.pointerToInt(oldBase)
        return Array<Byte>.fromPointer(
            newBase + offset,
            slice.size
        )
    }

    // ========================================================================
    // dropSentinel - 移除哨兵
    // 对应 Zig: pub fn dropSentinel(ptr: anytype, allocator: std.mem.Allocator) ...
    // ========================================================================

    /// 移除哨兵终止的切片的哨兵
    /// 对应 Zig: pub fn dropSentinel
    /// 产生的非哨兵终止切片可以用 allocator.free 释放
    ///
    /// 大多数分配器无需分配额外内存即可完成此操作，
    /// 但不同于简单类型转换，此函数不会对需要知道确切分配大小才能释放的分配器造成问题
    public static func dropSentinel(
        slice: Array<Byte>,
        allocator: Allocator
    ): ?Array<Byte> {
        // 尝试 remap 到相同长度 (去掉哨兵)
        let remapResult = allocator.remap(slice, UInt64(slice.size))
        if (let newSlice = remapResult) {
            return newSlice
        }
        // remap 失败，回退到 dup 然后 free
        let duped = allocator.dupe(slice)
        allocator.free(slice)
        return duped
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 向类型指针写入值
    private static func writeTyped<T>(ptr: CPointer<T>, value: T): Unit {
        CPointer<T>.write(ptr, value)
    }

    /// 页大小
    public static func pageSize(): UInt64 {
        return ForeignFunc.sysconf(ForeignFunc.SC_PAGESIZE)
    }

    /// 向前对齐
    public static func alignForward(addr: UInt64, alignment: UInt64): UInt64 {
        let mask = alignment - 1
        return (addr + mask) & ~mask
    }
}
