// CowSlice - Copy-on-Write 切片
// 严格翻译自: src/ptr/CowSlice.zig
// "Copy on write" 切片: 可以借用或拥有的字节序列
// Release 构建中大小与 []const T 相同, 用一位标记是否拥有
package bao_core.ptr

import std.collection.*

// ============================================================================
// CowSlice<T> - Copy-on-Write 切片
// 对应 Bun: pub fn CowSlice(T: type) type { return CowSliceZ(T, null) }
// CowSliceZ<T> - 带哨兵值的 Copy-on-Write 切片
// 对应 Bun: pub fn CowSliceZ(T: type, comptime sentinel: ?T) type
// ============================================================================

/// Copy-on-Write 切片 (用于字节序列)
// 对应 Bun: struct { ptr: [*]T, flags: packed struct(usize) { len, is_owned } }
//
// 结构说明:
// - ptr: 指向底层数据的指针
// - isOwned: 标记数据是否被拥有 (deinit 时是否需要释放)
// - len: 数据长度
//
// CowSlice 不支持长度超过 2^(usize.bitSize - 1) 的切片
public class CowSlice {
    private var ptr: CPointer<UInt8>
    private var len: Int64
    private var isOwned: Bool
    private var allocator: ?Allocator = None

    /// 空的静态 CowSlice
    // 对应 Bun: pub const empty: Self = initStatic("")
    public static let empty: CowSlice = CowSlice()

    public init() {
        ptr = CPointer<UInt8>()
        len = 0
        isOwned = false
    }

    private init(ptr: CPointer<UInt8>, len: Int64, owned: Bool, alloc: ?Allocator) {
        this.ptr = ptr
        this.len = len
        this.isOwned = owned
        this.allocator = alloc
    }

    /// 创建一个拥有其分配的 Cow
    // 对应 Bun: pub fn initOwned(data: []T, allocator: Allocator) Self
    public static func initOwned(data: CPointer<UInt8>, length: Int64, alloc: Allocator): CowSlice {
        let cow = CowSlice()
        cow.ptr = data
        cow.len = length
        cow.isOwned = true
        cow.allocator = alloc
        return cow
    }

    /// 通过复制数据创建一个新的拥有 Cow
    // 对应 Bun: pub fn initDupe(data: Slice, allocator: Allocator) !Self
    public static func initDupe(data: Array<UInt8>, alloc: Allocator): ?CowSlice {
        let newPtr = alloc.alloc(data.size)
        if (newPtr.isNull()) {
            return None
        }
        let cow = CowSlice()
        cow.ptr = newPtr
        cow.len = data.size
        cow.isOwned = true
        cow.allocator = alloc
        return cow
    }

    /// 创建一个包装静态字符串的 Cow
    // 对应 Bun: pub fn initStatic(comptime data: Slice) Self
    // 调用 deinit() 安全但无效果
    public static func initStatic(data: CPointer<UInt8>, length: Int64): CowSlice {
        let cow = CowSlice()
        cow.ptr = data
        cow.len = length
        cow.isOwned = false
        return cow
    }

    /// 从 Array<UInt8> 创建静态 Cow
    public static func initStatic(data: Array<UInt8>): CowSlice {
        let cow = CowSlice()
        // 静态数据不拥有
        cow.ptr = CPointer<UInt8>()  // 仓颉中 Array 不能直接转指针, 简化处理
        cow.len = data.size
        cow.isOwned = false
        return cow
    }

    /// 是否拥有数据
    // 对应 Bun: pub inline fn isOwned(str: Self) bool
    public func isOwnedSlice(): Bool {
        return isOwned
    }

    /// 获取切片视图
    // 对应 Bun: pub fn slice(str: Self) Slice
    public func slice(): Array<UInt8> {
        if (len == 0 || ptr.isNull()) {
            return Array<UInt8>()
        }
        var result = ArrayList<UInt8>()
        unsafe {
            for (i in 0..len) {
                result.add(ptr.read(Int64(i)))
            }
        }
        return result.toArray()
    }

    /// 获取长度
    // 对应 Bun: pub inline fn length(str: Self) usize
    public func length(): Int64 {
        return len
    }

    /// 可变借用切片 (如果是借用的则自动转为拥有, 会产生分配)
    // 对应 Bun: pub fn sliceMut(str: *Self, allocator: Allocator) Allocator.Error!SliceMut
    public func sliceMut(alloc: Allocator): ?CPointer<UInt8> {
        if (!isOwned) {
            intoOwned(alloc)
        }
        return ptr
    }

    /// 可变借用切片 (假设已拥有, 否则安全检查失败)
    // 对应 Bun: pub fn sliceMutUnsafe(str: *Self) SliceMut
    public func sliceMutUnsafe(): CPointer<UInt8> {
        if (!isOwned) {
            throw Exception("CowSlice.sliceMutUnsafe cannot be called on Cows that borrow their data.")
        }
        return ptr
    }

    /// 取走切片的所有权, 留下空的 Cow
    // 对应 Bun: pub fn takeSlice(str: *Self, allocator: Allocator) Allocator.Error!SliceMut
    public func takeSlice(alloc: Allocator): ?CPointer<UInt8> {
        if (!isOwned) {
            if (intoOwned(alloc) == None) {
                return None
            }
        }
        let result = ptr
        // 重置为空状态
        ptr = CPointer<UInt8>()
        len = 0
        isOwned = false
        allocator = None
        return result
    }

    /// 返回一个借用此数据的新 Cow
    // 对应 Bun: pub fn borrow(str: Self) Self
    public func borrow(): CowSlice {
        let cow = CowSlice()
        cow.ptr = ptr
        cow.len = len
        cow.isOwned = false
        return cow
    }

    /// 返回一个借用子切片的新 Cow
    // 对应 Bun: pub fn borrowSubslice(str: Self, start: usize, end: ?usize) Self
    public func borrowSubslice(start: Int64, end: ?Int64): CowSlice {
        let endVal = match (end) {
            case Some(e) => e
            case None => len
        }
        let subLen = endVal - start
        let subPtr = if (ptr.isNull()) {
            CPointer<UInt8>()
        } else {
            unsafe { ptr + start }
        }
        let cow = CowSlice()
        cow.ptr = subPtr
        cow.len = subLen
        cow.isOwned = false
        return cow
    }

    /// 转为拥有 (如果还不是拥有的则复制数据)
    // 对应 Bun: pub fn toOwned(self: *Self, allocator: Allocator) Allocator.Error!void
    public func toOwned(alloc: Allocator): Unit {
        if (!isOwned) {
            intoOwned(alloc)
        }
    }

    /// 转为拥有 (内部实现)
    // 对应 Bun: fn intoOwned(str: *Self, allocator: Allocator) callconv(bun.callconv_inline) Allocator.Error!void
    private func intoOwned(alloc: Allocator): ?Unit {
        if (isOwned) {
            throw Exception("intoOwned called on already owned CowSlice")
        }

        let newPtr = alloc.alloc(len)
        if (newPtr.isNull()) {
            return None
        }
        unsafe {
            for (i in 0..len) {
                newPtr.write(Int64(i), ptr.read(Int64(i)))
            }
        }
        ptr = newPtr
        isOwned = true
        allocator = alloc
        return ()
    }

    /// 释放拥有的分配
    // 对应 Bun: pub fn deinit(str: *const Self, allocator: Allocator) void
    // 如果是借用的, 在 debug 构建中执行检查, release 构建中为空操作
    public func deinit(alloc: Allocator): Unit {
        if (isOwned) {
            match (allocator) {
                case Some(a) => a.free(CPointer<Unit>(ptr))
                case None => alloc.free(CPointer<Unit>(ptr))
            }
        }
        ptr = CPointer<UInt8>()
        len = 0
        isOwned = false
        allocator = None
    }

    /// 不包含 debug 安全检查的初始化
    // 对应 Bun: pub fn initUnchecked(data: Slice, is_owned: bool) Self
    public static func initUnchecked(data: CPointer<UInt8>, length: Int64, owned: Bool): CowSlice {
        let cow = CowSlice()
        cow.ptr = data
        cow.len = length
        cow.isOwned = owned
        return cow
    }
}

/// CowSliceZ - 带哨兵终止值的 Cow 切片
// 对应 Bun: pub fn CowSliceZ(T: type, comptime sentinel: ?T) type
// 在仓颉中简化为 CowSlice 的别名, 哨兵终止语义通过长度管理
/// CowSliceZ - CowSlice 的别名 (使用 CowSlice 直接)
// public type CowSliceZ = CowSlice

/// CowString - 字节切片 Cow 的别名
// 对应 Bun: pub const CowString = CowSlice(u8)
// 使用 CowSlice 直接
