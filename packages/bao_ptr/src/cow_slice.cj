// 严格翻译自: src/ptr/CowSlice.zig
// CowSlice / CowSliceZ - Copy-on-Write 切片
// 在 release 构建中与 []const T 大小相同，但存储一位标记是否拥有内存
package bao_ptr

import bao_core.*
import bao_threading.*

// ============================================================================
// CowSliceFlags - CowSlice 的标志位 (packed struct)
// ============================================================================

/// 标志位结构体
/// len 占用 usize 的 bitSize-1 位，is_owned 占用 1 位
public struct CowSliceFlags {
    public var len: UInt64 = 0
    public var is_owned: Bool = false

    public init() {}
    public init(len: UInt64, isOwned: Bool) {
        this.len = len
        this.is_owned = isOwned
    }
}

// ============================================================================
// DebugData - 调试数据 (仅 debug 构建使用)
// ============================================================================

/// 调试数据，用于跟踪借用情况
class DebugData {
    var mutex: Mutex = Mutex()
    var allocator: Allocator
    /// 活跃借用数量
    var borrows: UInt64 = 0

    init(allocator: Allocator) {
        this.allocator = allocator
    }
}

// ============================================================================
// CowSlice - Copy-on-Write 切片 (非哨兵终止)
// ============================================================================

/// Copy-on-Write 切片
/// 有很多情况下需要重用切片，但不确定该切片是否应该被释放
/// 在 release 构建中，与普通切片大小相同
/// 在 debug 构建中，有激进的断言以防止意外释放
///
/// CowSlice 不支持长度超过 2^(UInt64.bitSize-1) 的切片
public class CowSlice<T> {
    /// 底层数据指针
    public var ptr: Array<T> = Array<T>()
    /// 标志位
    public var flags: CowSliceFlags = CowSliceFlags()
    /// 调试数据 (仅 debug 构建)
    var debug: ?DebugData = None<DebugData>

    public init() {}

    /// 从拥有的数据创建新的 CowSlice
    /// data 被转移到返回的字符串中，必须在使用完毕后调用 .deinit() 释放
    public static func initOwned(data: Array<T>, allocator: Allocator): CowSlice<T> {
        let cow = CowSlice<T>()
        cow.ptr = data
        cow.flags = CowSliceFlags(UInt64(data.size),true)
        if (Environment.IS_DEBUG) {
            cow.debug = DebugData(allocator)
        }
        return cow
    }

    /// 复制 data 到新分配中创建 CowSlice
    public static func initDupe(data: Array<T>, allocator: Allocator): CowSlice<T> {
        var copied = Array<T>(data.size, { i => data[i] })
        for (i in 0..data.size) {
            copied[i] = data[i]
        }
        return initOwned(copied, allocator)
    }

    /// 从静态数据创建 CowSlice
    /// 调用 .deinit() 是安全的，但不会有任何效果
    public static func initStatic(data: Array<T>): CowSlice<T> {
        let cow = CowSlice<T>()
        cow.ptr = data
        cow.flags = CowSliceFlags(UInt64(data.size),false)
        if (Environment.IS_DEBUG) {
            cow.debug = None<DebugData>
        }
        return cow
    }

    /// 创建空 CowSlice
    public static func empty(): CowSlice<T> {
        return CowSlice<T>()
    }

    /// 返回 true 如果此字符串拥有其数据
    public func isOwned(): Bool {
        this.flags.is_owned
    }

    /// 借用此 CowSlice 的切片
    public func slice(): Array<T> {
        if (this.flags.len == 0) {
            return Array<T>()
        }
        let len = Int64(this.flags.len)
        if (len <= this.ptr.size) {
            return this.ptr[0..len]
        }
        return this.ptr
    }

    /// 获取长度
    public func length(): UInt64 {
        this.flags.len
    }

    /// 可变借用此 CowSlice 的切片
    /// 借用的 CowSlice 会被自动转换为拥有的，会产生一次分配
    public func sliceMut(allocator: Allocator): Array<T> {
        if (!this.isOwned()) {
            this.intoOwned(allocator)
        }
        return this.slice()
    }

    /// 可变借用此 CowSlice 的切片，假设它已拥有其数据
    /// 在借用的 CowSlice 上调用此方法会触发断言错误
    public func sliceMutUnsafe(): Array<T> {
        Assert.assertTrue(this.isOwned(), "CowSlice.sliceMutUnsafe cannot be called on Cows that borrow their data.")
        return this.slice()
    }

    /// 获取此字符串分配的所有权。str 被置为有效的空状态
    /// 调用者拥有返回的内存，必须在使用完毕后释放
    public func takeSlice(allocator: Allocator): Array<T> {
        if (!this.isOwned()) {
            this.intoOwned(allocator)
        }
        let result = this.slice()
        // 重置为空状态
        this.ptr = Array<T>()
        this.flags = CowSliceFlags(0,false)
        if (Environment.IS_DEBUG) {
            this.debug = None<DebugData>
        }
        return result
    }

    /// 返回借用此字符串数据的新 CowSlice
    /// 借用的字符串应该被 deinit 以便执行 debug 断言检查
    public func borrow(): CowSlice<T> {
        if (Environment.IS_DEBUG) {
            match (this.debug) {
                case Some(debug) =>
                    debug.mutex.lock()
                    debug.borrows += 1
                    debug.mutex.unlock()
                case None => ()
            }
        }
        let result = CowSlice<T>()
        result.ptr = this.ptr
        result.flags = CowSliceFlags(this.flags.len,false)
        result.debug = this.debug
        return result
    }

    /// 返回借用此字符串子切片的新 CowSlice
    /// 这相当于 str[start..end]
    /// 当 end 为 null 时，子切片会延伸到字符串末尾
    public func borrowSubslice(start: UInt64, end: ?UInt64): CowSlice<T> {
        let end_ = end ?? this.flags.len
        let startIdx = Int64(start)
        let endIdx = Int64(end_)

        var result = this.borrow()
        if (startIdx < this.ptr.size && endIdx <= this.ptr.size && startIdx <= endIdx) {
            result.ptr = this.ptr[startIdx..endIdx]
            result.flags = CowSliceFlags(UInt64(endIdx - startIdx),false)
        }
        return result
    }

    /// 将此 CowSlice 设为 'owned'，通过复制其借用数据
    /// 如果已经是拥有的，什么都不做
    public func toOwned(allocator: Allocator): Unit {
        if (!this.isOwned()) {
            this.intoOwned(allocator)
        }
    }

    /// 将此 CowSlice 设为 'owned'，通过复制其借用数据
    /// 如果已经是拥有的，会 panic
    func intoOwned(allocator: Allocator): Unit {
        Assert.assertTrue(!this.isOwned())

        // 复制数据
        let currentSlice = this.slice()
        var bytes = Array<T>(currentSlice.size, { i => currentSlice[i] })
        for (i in 0..currentSlice.size) {
            bytes[i] = currentSlice[i]
        }
        this.ptr = bytes
        this.flags.is_owned = true

        if (Environment.IS_DEBUG) {
            match (this.debug) {
                case Some(debug) =>
                    debug.mutex.lock()
                    Assert.assertTrue(debug.borrows > 0)
                    debug.borrows -= 1
                    debug.mutex.unlock()
                    this.debug = None<DebugData>
                case None => ()
            }
            this.debug = DebugData(allocator)
        }
    }

    /// 释放此 CowSlice 的分配（如果是拥有的）
    /// 在 debug 构建中，deinit 借用的字符串会执行 debug 检查
    /// 在 release 构建中是 no-op
    public func deinit(allocator: Allocator): Unit {
        if (Environment.IS_DEBUG) {
            match (this.debug) {
                case Some(debug) =>
                    debug.mutex.lock()
                    if (this.isOwned()) {
                        // 活跃借用变为无效数据
                        Assert.assertTrue(debug.borrows == 0, "Cannot deinit() a CowSlice with active borrows.")
                        debug.mutex.unlock()
                    } else {
                        debug.borrows -= 1  // 借用字符串的双重 deinit
                        debug.mutex.unlock()
                    }
                case None => ()
            }
        }
        if (this.flags.is_owned) {
            // 释放内存
            this.ptr = Array<T>()
        }
    }

    /// 不包含 debug 安全检查的初始化
    public static func initUnchecked(data: Array<T>, isOwned: Bool): CowSlice<T> {
        let cow = CowSlice<T>()
        cow.ptr = data
        cow.flags = CowSliceFlags(UInt64(data.size), isOwned)
        if (Environment.IS_DEBUG) {
            cow.debug = None<DebugData>
        }
        return cow
    }
}

// ============================================================================
// CowString - CowSlice<Byte> 的类型别名
// ============================================================================

/// CowString 类型 - CowSlice(u8) 的别名
public type CowString = CowSlice<Byte>
