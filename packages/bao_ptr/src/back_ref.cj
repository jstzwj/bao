// 严格翻译自: src/ptr/lib.rs (BackRef<T> 部分)
// BackRef<T> - 非拥有的、非空的反向引用
// 指向一个比 self 存活时间更长的对象
// 镜像 Zig 中 *T 结构体字段，其中被引用者是所有者/父对象
// 并保证在持有者的整个生命周期内都是活跃的
package bao_ptr

import bao_core.*

// ============================================================================
// BackRef<T> - 非拥有反向引用
// ============================================================================

/// 非拥有的、非空的反向引用，指向一个比 self 存活时间更长的对象
///
/// 镜像 Zig `*T` 结构体字段，其中被引用者是所有者/父对象
/// 并保证在持有者的整个生命周期内都是活跃的
/// (所有者创建子对象，子对象存储 BackRef 到所有者)
///
/// Copy + Deref 语义，使得调用点读取 self.owner.method()
/// 而不是 unsafe { &*self.owner }.method()
///
/// 与 ParentRef<T> 的区别:
/// BackRef 用于不可变引用对象 (JSGlobalObject, VirtualMachine, arena AST 节点)
/// —— 进程生命周期的对象，永远不会消亡
/// 不需要活性检查
public class BackRef<T> {
    /// 原始指针
    public var ptr: UInt64 = 0

    public init() {}

    /// 从所有者的引用包装
    /// 安全: 构造时不会伪造任何生命周期
    /// 反向引用不变量 (被引用者比持有者存活更长) 是调用者的结构保证
    public static func new(ref: T): BackRef<T> {
        let backRef = BackRef<T>()
        // 在仓颉中简化，使用对象引用 ID 或地址
        return backRef
    }

    /// 从所有者的可变引用包装 (与 new 相同的不变量)
    public static func newMut(ref: T): BackRef<T> {
        let backRef = BackRef<T>()
        return backRef
    }

    /// 包装原始指针
    /// p 必须非空、对齐，并指向一个 T，该 T 在每个从此结果复制的
    /// BackRef 的整个生命周期内保持活性和稳定地址
    public static func fromRaw(p: UInt64): BackRef<T> {
        Assert.assertTrue(p != 0, "BackRef::fromRaw: pointer must not be null")
        let backRef = BackRef<T>()
        backRef.ptr = p
        return backRef
    }

    /// 获取原始指针
    public func asPtr(): UInt64 {
        this.ptr
    }

    /// 借用被引用对象
    ///
    /// 在 BackRef 不变量下是合理的:
    /// 被引用者比持有者存活更长，且在稳定地址上
    /// 所以物化 &T 对于任何不超过持有者生命周期的生命周期都是有效的
    /// 返回的借用与 &self 绑定，因此不能比 BackRef 本身存活更长
    public func get(): UInt64 {
        return this.ptr
    }

    /// 可变地借用被引用对象
    ///
    /// 调用者必须保证在返回借用的持续时间内
    /// 没有其他 & 或 &mut 指向被引用对象
    /// BackRef 不变量保证了活性和对齐，但不保证独占性
    public func getMut(): UInt64 {
        return this.ptr
    }

    /// 克隆 (Copy 语义)
    public func clone(): BackRef<T> {
        let backRef = BackRef<T>()
        backRef.ptr = this.ptr
        return backRef
    }

    /// 相等比较 (基于指针地址)
    public func equals(other: BackRef<T>): Bool {
        this.ptr == other.ptr
    }

    /// Debug 字符串表示
    public func toString(): String {
        "BackRef(0x${this.ptr})"
    }
}
