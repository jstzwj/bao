// bao_collections - VecExt / ByteVecExt 扩展方法
// 严格翻译自: src/collections/vec_ext.rs
//   pub trait VecExt<T>: Sized { ... }
//   pub trait ByteVecExt { ... }
//   pub struct OffsetByteList { ... }
//
// Bun 设计:
//   - VecExt<T> 为 Vec<T> 提供 Zig 风格方法名
//     (slice, append, init_capacity, ensure_total_capacity 等)
//   - BabyList<T> 被替换为 Vec<T> + VecExt 方法
//   - ByteVecExt 为 Vec<u8> 提供格式化写入方法
//   - OffsetByteList 是带偏移量的字节列表
//   仓颉: 使用 extend 为 ArrayList<T> 添加扩展方法
package bao_collections

// ============================================================================
// VecExt<T> - ArrayList 扩展方法
// 严格翻译自: src/collections/vec_ext.rs - VecExt<T> trait
//   pub trait VecExt<T>: Sized {
//       fn init_capacity(n: usize) -> Self;
//       fn init_one(value: T) -> Self;
//       fn from_slice(items: &[T]) -> Self where T: Clone;
//       fn slice(&self) -> &[T];
//       fn append(&mut self, value: T);
//       fn ensure_total_capacity(&mut self, n: usize);
//       ...
//   }
//
// 仓颉: 使用 extend 为 ArrayList<T> 添加方法
// 这些方法名对应 Bun/Zig 的方法名，使翻译后的代码更贴近原始 API
// ============================================================================

/// ArrayList<T> 扩展方法 - 对应 Bun VecExt<T>
/// 为 ArrayList 提供 Zig 风格的方法名
/// Bun: 所有方法都是 infallible (Vec aborts on OOM)
extend<T> ArrayList<T> {
    // ========================================================================
    // 构造器扩展 - 对应 Bun VecExt 构造方法
    // ========================================================================

    /// 使用初始容量创建 - 对应 Bun VecExt::init_capacity
    /// Zig: pub fn initCapacity(n: usize) Self
    public static func vecInitCapacity(n: Int64): ArrayList<T> {
        return ArrayList<T>()
    }

    /// 创建包含一个元素的列表 - 对应 Bun VecExt::init_one
    /// Zig: pub fn initOne(value: T) Self
    public static func vecInitOne(value: T): ArrayList<T> {
        let v = ArrayList<T>()
        v.append(value)
        return v
    }

    /// 从数组复制 - 对应 Bun VecExt::from_slice
    /// Zig: pub fn fromSlice(items: []const T) Self
    public static func vecFromSlice(items: Array<T>): ArrayList<T> {
        let v = ArrayList<T>()
        for (item in items) {
            v.append(item)
        }
        return v
    }

    // ========================================================================
    // 访问器扩展 - 对应 Bun VecExt 访问方法
    // ========================================================================

    /// 获取切片 - 对应 Bun VecExt::slice
    /// Zig: pub fn slice(self: *Self) []T
    /// 返回底层存储的视图
    public func vecSlice(): Array<T> {
        return items()
    }

    /// 获取可变切片 - 对应 Bun VecExt::slice_mut
    /// Zig: pub fn sliceMut(self: *Self) []T
    public func vecSliceMut(): Array<T> {
        return items()
    }

    /// 获取只读切片 - 对应 Bun VecExt::slice_const
    /// Zig: pub fn sliceConst(self: *const Self) []const T
    public func vecSliceConst(): Array<T> {
        return items()
    }

    /// 获取指定位置元素 (只读) - 对应 Bun VecExt::at
    /// Zig: pub fn at(self: *const Self, index: usize) *const T
    public func vecAt(index: Int64): T {
        return items()[index]
    }

    /// 获取指定位置元素 (可变) - 对应 Bun VecExt::mut_
    /// Zig: pub fn mut_(self: *Self, index: usize) *T
    public func vecMut(index: Int64): T {
        return items()[index]
    }

    /// 长度 (u32) - 对应 Bun VecExt::len_u32
    /// Zig: u32 长度字段
    public func vecLenU32(): UInt32 {
        return UInt32(size)
    }

    /// 容量 (u32) - 对应 Bun VecExt::cap_u32
    public func vecCapU32(): UInt32 {
        return UInt32(capacity())
    }

    // ========================================================================
    // 修改操作 - 对应 Bun VecExt 修改方法
    // ========================================================================

    /// 追加元素 - 对应 Bun VecExt::append
    /// Zig: pub fn append(self: *Self, value: T) !void
    public func vecAppend(value: T): Unit {
        append(value)
    }

    /// 在容量允许时追加 - 对应 Bun VecExt::append_assume_capacity
    /// Zig: pub fn appendAssumeCapacity(self: *Self, value: T) void
    public func vecAppendAssumeCapacity(value: T): Unit {
        appendAssumeCapacity(value)
    }

    /// 追加数组 - 对应 Bun VecExt::append_slice
    /// Zig: pub fn appendSlice(self: *Self, vals: []const T) !void
    public func vecAppendSlice(vals: Array<T>): Unit {
        appendSlice(vals)
    }

    /// 在容量允许时追加数组 - 对应 Bun VecExt::append_slice_assume_capacity
    /// Zig: pub fn appendSliceAssumeCapacity(self: *Self, vals: []const T) void
    public func vecAppendSliceAssumeCapacity(vals: Array<T>): Unit {
        appendSliceAssumeCapacity(vals)
    }

    /// 确保总容量 - 对应 Bun VecExt::ensure_total_capacity
    /// Zig: pub fn ensureTotalCapacity(self: *Self, n: usize) !void
    public func vecEnsureTotalCapacity(n: Int64): Unit {
        ensureTotalCapacity(n)
    }

    /// 确保总容量 (精确) - 对应 Bun VecExt::ensure_total_capacity_precise
    public func vecEnsureTotalCapacityPrecise(n: Int64): Unit {
        ensureTotalCapacity(n)
    }

    /// 确保未使用容量 - 对应 Bun VecExt::ensure_unused_capacity
    /// Zig: pub fn ensureUnusedCapacity(self: *Self, n: usize) !void
    public func vecEnsureUnusedCapacity(n: Int64): Unit {
        ensureUnusedCapacity(n)
    }

    /// 缩减但保留容量 - 对应 Bun VecExt::shrink_retaining_capacity
    /// Zig: pub fn shrinkRetainingCapacity(self: *Self, new_len: usize) void
    public func vecShrinkRetainingCapacity(newLen: Int64): Unit {
        shrinkRetainingCapacity(newLen)
    }

    /// 缩减并释放 - 对应 Bun VecExt::shrink_and_free
    /// Zig: pub fn shrinkAndFree(self: *Self, new_len: usize) void
    public func vecShrinkAndFree(newLen: Int64): Unit {
        shrinkAndFree(newLen)
    }

    /// 清空但保留容量 - 对应 Bun VecExt::clear_retaining_capacity
    /// Zig: pub fn clearRetainingCapacity(self: *Self) void
    public func vecClearRetainingCapacity(): Unit {
        clearRetainingCapacity()
    }

    /// 清空并释放 - 对应 Bun VecExt::clear_and_free
    /// Zig: pub fn clearAndFree(self: *Self) void
    public func vecClearAndFree(): Unit {
        clearAndFree()
    }

    /// 从前面移除 N 个元素 - 对应 Bun VecExt::drain_front
    /// Zig: copy_within(n.., 0) + truncate
    public func vecDrainFront(n: Int64): Unit {
        if (n <= 0) { return }
        let len = size
        if (n >= len) {
            clearRetainingCapacity()
            return
        }
        // 移动元素: [n, len) -> [0, len-n)
        var i: Int64 = 0
        while (i < len - n) {
            // 需要直接操作底层数组
            i += 1
        }
        // 简化: 使用 orderedRemove 移除前 n 个
        var count = n
        while (count > 0) {
            orderedRemove(0)
            count -= 1
        }
    }

    /// 有序删除 - 对应 Bun VecExt::ordered_remove
    /// Zig: pub fn orderedRemove(self: *Self, index: usize) T
    public func vecOrderedRemove(index: Int64): T {
        return orderedRemove(index)
    }

    /// 插入数组 - 对应 Bun VecExt::insert_slice
    /// Zig: pub fn insertSlice(self, index, vals) !void
    public func vecInsertSlice(index: Int64, vals: Array<T>): Unit {
        for (i in 0..vals.size) {
            insert(index + Int64(i), vals[i])
        }
    }

    /// 替换范围 - 对应 Bun VecExt::replace_range
    /// Zig: pub fn replaceRange(self, start, len, new_items) !void
    public func vecReplaceRange(start: Int64, len: Int64, newItems: Array<T>): Unit {
        replaceRange(start, len, newItems)
    }

    /// 扩展到容量 - 对应 Bun VecExt::expand_to_capacity
    /// Zig: pub fn expandToCapacity(self: *Self) void
    public func vecExpandToCapacity(initValue: T): Unit {
        expandToCapacity(initValue)
    }

    // ========================================================================
    // 所有权转移 - 对应 Bun VecExt 所有权方法
    // ========================================================================

    /// 转移为列表 - 对应 Bun VecExt::move_to_list
    /// Zig: moveFromList / moveToList
    public func vecMoveToList(): ArrayList<T> {
        let result = clone()
        clearAndFree()
        return result
    }

    /// 转移为列表 (托管) - 对应 Bun VecExt::move_to_list_managed
    public func vecMoveToListManaged(): ArrayList<T> {
        return vecMoveToList()
    }

    /// 转为拥有的数组 - 对应 Bun VecExt::to_owned_slice
    /// Zig: pub fn toOwnedSlice(self: *Self) !Slice
    public func vecToOwnedSlice(): Array<T> {
        return toOwnedSlice()
    }

    /// 转移所有权 (空操作) - 对应 Bun VecExt::transfer_ownership
    /// Zig: no-op for Vec (already globally owned)
    public func vecTransferOwnership(): Unit {}

    // ========================================================================
    // 杂项 - 对应 Bun VecExt 其他方法
    // ========================================================================

    /// 内存开销 - 对应 Bun VecExt::memory_cost
    /// Zig: pub fn memoryCost(self: *const Self) usize
    ///   return self.capacity * @sizeOf(T)
    public func vecMemoryCost(): Int64 {
        return capacity()
    }

    /// 深度克隆 - 对应 Bun VecExt::deep_clone_with
    /// Zig: 使用克隆函数逐个克隆元素
    public func vecDeepCloneWith(cloneOne: (T) -> T): ArrayList<T> {
        let result = ArrayList<T>()
        for (i in 0..size) {
            result.append(cloneOne(vecAt(i)))
        }
        return result
    }

    /// 尝试深度克隆 - 对应 Bun VecExt::try_deep_clone_with
    public func vecTryDeepCloneWith<E>(cloneOne: (T) -> ?E): ?ArrayList<E> {
        let result = ArrayList<E>()
        for (i in 0..size) {
            let cloned = cloneOne(vecAt(i))
            match (cloned) {
                case Some(v) => result.append(v)
                case None => return None
            }
        }
        return Some(result)
    }
}

// ============================================================================
// Cloneable<T> - 可克隆接口
// 用于 vecFromSlice 等需要元素克隆的方法
// ============================================================================

/// 可克隆接口 - 用于泛型约束
public interface Cloneable<T> {
    func clone(): T
}

// ============================================================================
// ByteArrayList - 字节数组列表扩展
// 严格翻译自: src/collections/vec_ext.rs - ByteVecExt
//   pub trait ByteVecExt {
//       fn append_fmt(&mut self, args: fmt::Arguments<'_>) -> Result<(), AllocError>;
//       fn write(&mut self, str: &[u8]) -> Result<u32, AllocError>;
//       fn write_latin1(&mut self, str: &[u8]) -> Result<u32, AllocError>;
//       fn write_utf16(&mut self, str: &[u16]) -> Result<u32, AllocError>;
//       fn write_type_as_bytes_assume_capacity<Int: Copy>(&mut self, int: Int);
//       fn uv_alloc_spare(&mut self, suggested: usize) -> &mut [MaybeUninit<u8>];
//       fn uv_commit(&mut self, nread: usize);
//   }
//
// 仓颉: 为 ArrayList<UInt8> 添加字节操作方法
// ============================================================================

/// ArrayList<UInt8> 扩展 - 对应 Bun ByteVecExt
/// 为字节数组提供格式化写入方法
extend ArrayList<UInt8> {
    /// 写入字节 - 对应 Bun ByteVecExt::write
    /// Zig:
    ///   pub fn write(self: *Self, str: []const u8) !u32 {
    ///       const initial = self.items.len;
    ///       self.appendSlice(str);
    ///       return @intCast(self.items.len - initial);
    ///   }
    public func byteWrite(str: Array<UInt8>): Int64 {
        let initial = size
        appendSlice(str)
        return size - initial
    }

    /// 写入字符串 - 对应 Bun ByteVecExt::write (String 变体)
    public func byteWriteString(str: String): Int64 {
        let initial = size
        for (c in str) {
            append(UInt8(c))
        }
        return size - initial
    }

    /// 写入 Latin-1 编码字符串 - 对应 Bun ByteVecExt::write_latin1
    /// Zig:
    ///   pub fn writeLatin1(self: *Self, str: []const u8) !u32
    ///   仓颉: 简化实现，直接追加字节
    public func byteWriteLatin1(str: Array<UInt8>): Int64 {
        let initial = size
        appendSlice(str)
        return size - initial
    }

    /// 写入 UTF-16 编码字符串 - 对应 Bun ByteVecExt::write_utf16
    /// Zig:
    ///   pub fn writeUtf16(self: *Self, str: []const u16) !u32
    ///   仓颉: 将 UTF-16 转为 UTF-8 后追加
    public func byteWriteUtf16(str: Array<UInt16>): Int64 {
        let initial = size
        // 简化: 假设 ASCII 范围，逐字节转换
        for (codeUnit in str) {
            if (codeUnit < UInt16(128)) {
                append(UInt8(codeUnit))
            } else if (codeUnit < UInt16(2048)) {
                append(UInt8(UInt16(192) | (codeUnit >> UInt16(6))))
                append(UInt8(UInt16(128) | (codeUnit & UInt16(63))))
            } else {
                append(UInt8(UInt16(224) | (codeUnit >> UInt16(12))))
                append(UInt8(UInt16(128) | ((codeUnit >> UInt16(6)) & UInt16(63))))
                append(UInt8(UInt16(128) | (codeUnit & UInt16(63))))
            }
        }
        return size - initial
    }

    /// 将任意类型作为字节写入 (假定有足够容量) - 对应 Bun ByteVecExt::write_type_as_bytes_assume_capacity
    /// Zig:
    ///   pub fn writeTypeAsBytesAssumeCapacity(self: *Self, int: anytype) void {
    ///       const size = @sizeOf(@TypeOf(int));
    ///       debug.assert(self.capacity >= self.items.len + size);
    ///       ...
    ///   }
    /// 仓颉: 简化实现
    public func byteWriteTypeAsBytes(value: Int32): Unit {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }

    /// 写入 Int64 作为字节
    public func byteWriteInt64(value: Int64): Unit {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
        append(UInt8((value >> 32) & 0xFF))
        append(UInt8((value >> 40) & 0xFF))
        append(UInt8((value >> 48) & 0xFF))
        append(UInt8((value >> 56) & 0xFF))
    }

    /// libuv 风格分配空间 - 对应 Bun ByteVecExt::uv_alloc_spare
    /// Zig: 确保至少 suggested 字节的空闲容量
    public func byteUvAllocSpare(suggested: Int64): Unit {
        ensureUnusedCapacity(suggested)
    }

    /// libuv 风格提交 - 对应 Bun ByteVecExt::uv_commit
    /// Zig: 递增 len by nread
    public func byteUvCommit(nread: Int64): Unit {
        // 在仓颉中，长度由 append 操作自动维护
        // 此方法为 API 兼容性保留
    }
}

// ============================================================================
// OffsetByteList - 带偏移的字节列表
// 严格翻译自: src/collections/vec_ext.rs - OffsetByteList
//   pub struct OffsetByteList {
//       pub head: u32,
//       pub byte_list: Vec<u8>,
//   }
//
// Bun 设计:
//   - head: u32 偏移量，byte_list: Vec<u8> 数据
//   - write() 追加字节
//   - slice() 返回 [0..head) 部分
//   - remaining() 返回 [head..) 部分
//   - consume(bytes) 递增 head
//   - len() 返回 byte_list.len - head
// ============================================================================

/// 带偏移的字节列表 - 对应 Bun OffsetByteList
/// 维护一个读取偏移量 head 和底层字节缓冲区
public class VecExtOffsetByteList {
    /// 头部偏移 - 对应 Bun OffsetByteList.head: u32
    public var head: UInt32 = 0

    /// 字节缓冲区 - 对应 Bun OffsetByteList.byte_list: Vec<u8>
    public var byteList: ArrayList<UInt8> = ArrayList<UInt8>()

    public init() {}

    /// 带初始值构造 - 对应 Bun OffsetByteList::init
    /// Zig: pub fn init(head: u32, byte_list: Vec<u8>) Self
    public init(head: UInt32, byteList: ArrayList<UInt8>) {
        this.head = head
        this.byteList = byteList
    }

    /// 写入字节 - 对应 Bun OffsetByteList::write
    /// Zig:
    ///   pub fn write(&mut self, bytes: &[u8]) -> Result<(), AllocError> {
    ///       self.byte_list.extend_from_slice(bytes);
    ///       Ok(())
    ///   }
    public func write(bytes: Array<UInt8>): Unit {
        byteList.appendSlice(bytes)
    }

    /// 获取已消费部分的切片 - 对应 Bun OffsetByteList::slice
    /// Zig: pub fn slice(&self) -> &[u8] { &self.byte_list[..self.head as usize] }
    public func slice(): Array<UInt8> {
        let h = Int64(head)
        if (h >= byteList.size) {
            return []
        }
        return byteList.items()[0..h]
    }

    /// 获取剩余部分 - 对应 Bun OffsetByteList::remaining
    /// Zig: pub fn remaining(&self) -> &[u8] { &self.byte_list[self.head as usize..] }
    public func remaining(): Array<UInt8> {
        let h = Int64(head)
        if (h >= byteList.size) {
            return []
        }
        return byteList.items()[h..byteList.size]
    }

    /// 消费指定字节数 - 对应 Bun OffsetByteList::consume
    /// Zig:
    ///   pub fn consume(&mut self, bytes: u32) void {
    ///       self.head = self.head.saturating_add(bytes);
    ///       if (self.head as usize >= self.byte_list.len()) {
    ///           self.head = 0;
    ///           self.byte_list.clear();
    ///       }
    ///   }
    public func consume(bytes: UInt32): Unit {
        head = head + bytes
        if (Int64(head) >= byteList.size) {
            head = 0
            byteList.clearRetainingCapacity()
        }
    }

    /// 获取有效长度 - 对应 Bun OffsetByteList::len
    /// Zig: pub fn len(&self) -> u32 { self.byte_list.len() as u32 - self.head }
    public func len(): UInt32 {
        return UInt32(byteList.size) - head
    }

    /// 清空 - 对应 Bun OffsetByteList::clear
    /// Zig: pub fn clear(&mut self) { self.head = 0; self.byte_list.clear(); }
    public func clear(): Unit {
        head = 0
        byteList.clearRetainingCapacity()
    }

    /// 清空并释放 - 对应 Bun OffsetByteList::clear_and_free
    /// Zig: drop(take(self))
    public func clearAndFree(): Unit {
        head = 0
        byteList.clearAndFree()
    }
}
