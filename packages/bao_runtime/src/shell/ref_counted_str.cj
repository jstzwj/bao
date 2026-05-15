// ref_counted_str.cj - 引用计数字符串
// 对应 Bun: src/runtime/shell/RefCountedStr.zig
// 严格翻译Bun引用计数字符串到仓颉

package bao_runtime.shell

import bao_core.*

// ============================================================================
// 引用计数字符串
// ============================================================================

/// 引用计数字符串
/// 环境变量字符串需要大量复制，所以使用引用计数
/// 有时使用静态分配或有预定生命周期的字符串，不需要堆分配
public class RefCountedStr {
    /// 引用计数
    public var refcount: UInt32 = 1
    /// 字符串长度
    public var len: UInt32 = 0
    /// 字符串指针
    public var ptr: Array<Byte>

    /// 从切片初始化
    public static func initFunc(slice: Array<Byte>): RefCountedStr {
        let this = RefCountedStr()
        this.refcount = 1
        this.len = UInt32(slice.length)
        this.ptr = slice
        return this
    }

    /// 获取字节切片
    public func byteSlice(): Array<Byte> {
        if (this.len == 0) {
            return Array<Byte>()
        }
        return this.ptr[0..this.len]
    }

    /// 增加引用计数
    public func ref() {
        this.refcount += 1
    }

    /// 减少引用计数，为0时释放
    public func deref() {
        this.refcount -= 1
        if (this.refcount == 0) {
            this.deinit()
        }
    }

    /// 释放资源
    func deinit() {
        this.freeStr()
    }

    /// 释放字符串内存
    func freeStr() {
        if (this.len == 0) {
            return
        }
        // 释放字符串内存
    }
}
