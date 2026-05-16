// 严格翻译自: src/ptr/lib.rs (ThisPtr<T> 部分)
// ThisPtr<T> - 回调分发 self 指针
// uSockets / C++ FFI 分发给每个 socket 事件处理器一个原始 *mut Self
// 从 userdata 槽恢复。ThisPtr 将此模式集中在一个构造函数安全契约下
package bao_ptr

import bao_core.*

// ============================================================================
// ThisPtr<T> - 回调分发 self 指针
// ============================================================================

/// 非拥有的、Copy 的 self 指针，用于 uSockets / FFI 回调分发
///
/// 与 BackRef<T> (所有者比持有者存活更长的反向引用) 不同，
/// ThisPtr 用于 *被调用者就是分配本身* 的情况:
/// 被引用对象是一个侵入式引用计数的堆对象，可能在调用期间被释放
/// (一个重入的 deref() 使引用计数达到零)
///
/// 因此 ThisPtr:
///   - 是 Copy 的，不持有自己的引用 —— 它纯粹是传入 *mut Self 的类型化视图
///   - 只产生新的短生命周期 &T (没有 DerefMut):
///     通过同一 userdata 指针重入的处理器会别名一个持有的 &mut T
///     修改通过 asPtr() 和每站点 unsafe { (*p).field } 进行
public class ThisPtr<T> {
    /// 原始指针
    public var ptr: UInt64 = 0

    public init() {}

    /// 包装从 uWS / FFI 回调传入的原始 *mut Self
    ///
    /// p 必须非空，并指向一个活跃的 T
    /// (通过 heap::alloc 分配，侵入式引用计数)
    /// 在此 ThisPtr 及其副本的每次后续访问期间保持活跃
    public static func new(p: UInt64): ThisPtr<T> {
        Assert.assertTrue(p != 0, "ThisPtr::new: null callback self-pointer")
        let thisPtr = ThisPtr<T>()
        thisPtr.ptr = p
        return thisPtr
    }

    /// 恢复原始指针 (根来源)，用于修改或转发到另一个原始指针处理器
    public func asPtr(): UInt64 {
        this.ptr
    }

    /// 被引用对象的新鲜共享借用
    ///
    /// 在 new 不变量下是合理的:
    /// 被引用对象是活跃的，且没有 &mut T 与返回的 &T 重叠
    /// 每次调用物化一个新的短生命周期 &T (仅自动引用范围)
    /// 不要在可能形成对同一分配的 &mut T 的调用期间持有结果
    public func get(): UInt64 {
        return this.ptr
    }

    /// 克隆 (Copy 语义)
    public func clone(): ThisPtr<T> {
        let thisPtr = ThisPtr<T>()
        thisPtr.ptr = this.ptr
        return thisPtr
    }

    /// Debug 字符串表示
    public func toString(): String {
        "ThisPtr(0x${this.ptr.toString(16)})"
    }
}
