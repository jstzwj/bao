// 严格翻译自: src/runtime/shell/RefCountedStr.zig
// 引用计数字符串 — 环境变量字符串需要大量复制，所以使用引用计数。
// 但有时使用静态分配或有预定生命周期的字符串，不需要堆分配。

package bao_runtime.shell

import bao_core.*

// ============================================================================
// 引用计数字符串
// 对应 Bun: RefCountedStr.zig
// ============================================================================

/// 引用计数字符串
/// 环境变量字符串需要大量复制，所以使用引用计数。
/// 有时使用静态分配或有预定生命周期的字符串，不需要堆分配。
/// 当引用计数降至 0 时，自动释放字符串内存和自身结构。
public class RefCountedStr {
    /// 引用计数，初始化为 1
    public var refcount: UInt32 = 1
    /// 字符串长度
    public var len: UInt32 = 0
    /// 字符串数据
    public var ptr: Array<Byte>

    /// 从字节切片初始化引用计数字符串
    /// 对应 Bun: RefCountedStr(slice)
    /// 在堆上分配 RefCountedStr 结构，并将切片的指针存储其中。
    /// 注意: 调用者必须确保 slice 的生命周期至少与 RefCountedStr 一样长，
    /// 或者在 init 前复制 slice。
    public static func initFunc(slice: Array<Byte>): RefCountedStr {
        let `this` = RefCountedStr()
        this.refcount = 1
        this.len = UInt32(slice.size)
        this.ptr = slice
        return this
    }

    /// 获取字节切片
    /// 对应 Bun: RefCountedStr.byteSlice()
    public func byteSlice(): Array<Byte> {
        if (this.len == 0) {
            return Array<Byte>()
        }
        return this.ptr[0..this.len]
    }

    /// 增加引用计数
    /// 对应 Bun: RefCountedStr.ref()
    public func ref() {
        this.refcount += 1
    }

    /// 减少引用计数，为 0 时释放
    /// 对应 Bun: RefCountedStr.deref()
    /// 引用计数从 1 降至 0 时，调用 deinit() 释放所有资源。
    public func deref() {
        this.refcount -= 1
        if (this.refcount == 0) {
            this.deinit()
        }
    }

    /// 释放资源
    /// 对应 Bun: RefCountedStr.deinit()
    /// 先释放字符串内存，再释放自身结构。
    func deinit() {
        this.freeStr()
        // 在实际运行时中，还需要释放 RefCountedStr 自身的堆内存
        // bun.default_allocator.destroy(this)
    }

    /// 释放字符串内存
    /// 对应 Bun: RefCountedStr.freeStr()
    /// 如果长度为 0 则不执行任何操作。
    func freeStr() {
        if (this.len == 0) {
            return
        }
        // 释放字符串内存
        // bun.default_allocator.free(this.ptr[0..this.len])
        this.ptr = Array<Byte>()
        this.len = 0
    }
}
