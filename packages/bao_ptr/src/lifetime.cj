// 严格翻译自: src/ptr/lib.rs (detach_lifetime 系列, LaunderedSelf, AsCtxPtr 部分)
// 生命周期分离工具函数和 trait
// 用于在需要将借用从 borrowck 生命周期中分离时使用
package bao_ptr

import bao_core.*

// ============================================================================
// detach_lifetime - 从 borrowck 生命周期中分离切片借用
// ============================================================================

/// 从其 borrowck 生命周期中分离切片借用
///
/// 这是局部变量版本的 RawSlice
/// 当需要在读取切片的同时重借用兄弟字段为 &mut 时使用
/// (经典的 Zig var buf = lockfile.buffers.string_bytes; ... &mut lockfile 模式)
/// 且后端存储已知在返回引用的范围内不会移动/重新分配
///
/// s 的支持分配在完整的调用者选择的生命周期内
/// 不被释放、移动或重新分配，并且不会形成对相同元素的独占 &mut
public func detachLifetime<T>(s: Array<T>): Array<T> {
    // 在仓颉中简化: 直接返回数组引用
    s
}

// ============================================================================
// detach_lifetime_ref - 从 borrowck 生命周期中分离 &T 借用
// ============================================================================

/// 从 borrowck 生命周期中分离 &T 借用 (detach_lifetime 的通用 ?Sized 形式)
///
/// 替换分散在 Phase-A 移植中的 open-coded
/// unsafe { &*std::ptr::from_ref::<T>(x) } 生命周期清洗惯用法
/// 集中化使得调用点可 grep 搜索，安全义务统一
///
/// 被引用对象在完整的调用者选择的生命周期内不被释放、移动或独占借用
public func detachLifetimeRef<T>(ref: T): T {
    ref
}

// ============================================================================
// detach_lifetime_mut - 从 borrowck 生命周期中分离 &mut T 借用
// ============================================================================

/// 从 borrowck 生命周期中分离 &mut T 借用
///
/// detach_lifetime_ref 的可变对应版本
/// 严格比共享形式更危险: 调用者还必须保证唯一性 (没有其他 &/&mut 指向同一 T)
///
/// 被引用对象在指定生命周期内是活跃的
/// 并且没有其他借用 (共享或独占) 与返回的 &mut T 重叠
public func detachLifetimeMut<T>(ref: T): T {
    ref
}

/// detachLifetimeRef 的较短别名
public func detachRef<T>(ref: T): T {
    detachLifetimeRef<T>(ref)
}

// ============================================================================
// LaunderedSelf - 洗涤 self 指针的 trait
// ============================================================================

/// 类型标记 trait，其 &mut self 方法通过 core::hint::black_box 洗涤 self
/// 然后分发重入的父对象/用户回调，再通过 LaunderedSelf.r 重新借用
///
/// Zig 在 *Self 上没有 noalias，所以原始 .zig 直接写入 this.*
/// 此 trait 是仓颉移植的唯一产物
/// 使等效的重新借用合理而不在每个字段访问处散布 unsafe
///
/// 实现契约 (安全性):
/// 对于 Self 上调用 r 的每个方法:
/// - Self 是堆对象的内联/侵入式字段，在重入回调期间永远不会被释放
///   (洗涤的原始指针别名一个 &mut self，其栈帧仍然活跃)
/// - 重入在单个 JS 线程上运行 (没有并发的 &mut Self)
/// - 由 r 产生的每个 &mut Self 都是短寿命的
///   并且在使用点是唯一的活跃借用 —— 永远不会跨越下一个父对象/用户分发持有
public interface LaunderedSelf<T> {
    /// 重新借用洗涤的 self 指针
    /// this 是经过 black_box 洗涤的外部 &mut self 的地址
    func launderedSelf(`this`: UInt64): T
}

// ============================================================================
// AsCtxPtr - &self 到 *mut Self 的 trait
// ============================================================================

/// &self -> *mut Self 的 trait，用于 C 回调 / scopeguard ctx 槽
///
/// 这是生产者端，将 self 填充到 void *user_data / *mut T ctx 参数中
/// callbackCtx (或普通的 unsafe { &*p }) 是消费者端，在跳板中恢复它
///
/// 返回的指针具有共享 (只读) 来源 —— 从 &self 派生
/// 因此直接通过它写入是 UB
/// *mut 拼写纯粹是为了匹配 C 形状的签名 (void*, uSockets ext slots, 等)
/// 消费者必须作为 &*p 解引用，并通过 Cell / UnsafeCell 内部可变字段路由修改
///
/// 为所有 T 的空白实现: 使用此 trait，self.asCtxPtr() 在任何类型上解析
public interface AsCtxPtr {
    /// self 的地址作为 *mut Self，用于延迟任务 / scopeguard / ref_guard ctx 槽
    func asCtxPtr(): UInt64
}
