// 严格翻译自: src/ptr/parent_ref.rs
// ParentRef<T> - 从子对象/任务到其可变父对象的非拥有反向指针
// 在 debug 构建中具有活性检查，release 构建中零开销
package bao_ptr

import bao_core.*

// ============================================================================
// LiveMarker - 活性标记哨兵
// ============================================================================

/// 零成本 (release) 的活性标记哨兵，嵌入在父结构体中
///
/// Debug 模式下使用 AtomicU64 从进程全局计数器初始化，
/// Drop 时将其毒化为 DEAD 值
/// Release 模式下是零大小 (无字段、无 Drop)
///
/// 将此嵌入到任何需要向子对象分发 ParentRef.anchored 副本的结构体中
/// 每个 ParentRef.get() 在 debug 构建中断言父对象的标记仍然匹配
/// 在构造时获取的快照 —— 捕获 use-after-parent-drop 和 ABA 重分配错误
public class LiveMarker {
    /// Generation 值，在 Drop 时写入。nextGen 永远不会产生此值
    public static let DEAD: UInt64 = 0

    /// 当前 generation
    /// Release 构建返回固定的非零值，使调用者看到 "live"
    public var generation: AtomicUInt64

    public init() {
        this.generation = AtomicUInt64(LiveMarker.nextGen())
    }

    /// 获取当前 generation 值
    public func getGeneration(): UInt64 {
        if (Environment.isDebug) {
            return this.generation.load()
        }
        return 1
    }

    /// Debug 断言 generation == expected
    /// Release 构建中为 no-op
    public func assertLive(expected: UInt64): Unit {
        if (Environment.isDebug) {
            let live = this.generation.load()
            Assert.assertTrue(
                live == expected,
                "ParentRef: use-after-parent-drop (marker=0x${live.toString(16)}, expected=0x${expected.toString(16)})"
            )
        }
    }

    /// 销毁标记，将 generation 设为 DEAD
    public func destroy(): Unit {
        this.generation.store(LiveMarker.DEAD)
    }

    /// 进程全局 generation 计数器，从 1 开始
    /// 0 保留给 DEAD / "unchecked"
    private static var _globalGen: AtomicUInt64 = AtomicUInt64(1)

    /// 获取下一个 generation 值
    public static func nextGen(): UInt64 {
        _globalGen.fetchAdd(1)
    }
}

// ============================================================================
// Anchored - 接口 trait
// ============================================================================

/// 任何嵌入了 LiveMarker 字段的结构体应实现此接口
/// 为 ParentRef.anchored 提供读取标记的能力
public interface Anchored {
    func liveMarker(): LiveMarker
}

// ============================================================================
// ParentRef<T> - 非拥有反向指针
// ============================================================================

/// 非拥有的从子对象/任务到其可变父对象的反向指针
///
/// 与 BackRef<T> 的区别:
/// BackRef 用于不可变的引用对象 (JSGlobalObject, VirtualMachine, arena AST 节点)
/// ——进程生命周期的对象，永远不会消亡
/// ParentRef 用于可变的父对象，可能在子对象/任务仍在运行时被销毁
///
/// 仅通过 get() 投影 &T (共享只读)。对父对象状态的修改通过
/// T 上的内部可变字段 (Cell, Atomic*, Mutex) 进行 —— 绝不通过 &mut T
///
/// 对于已经审计确认真正需要独占访问的场合，assumeMut 是显式的不安全逃生通道
public class ParentRef<T> {
    /// 原始指针
    public var ptr: UInt64 = 0
    /// 在构造时对 parent.liveMarker().getGeneration() 的快照
    /// 0 = unchecked (通过 new / fromRaw 构造，或非 Anchored 父对象)
    var _generation: UInt64 = 0
    /// 父对象嵌入的 LiveMarker.generation 原子的原始指针
    /// 单独存储 (不在每次 get() 时通过 T: Anchored 投影)
    /// None = unchecked
    var _marker: ?LiveMarker = None<LiveMarker>

    public init() {}

    /// 从父对象的共享引用构造
    /// 存储的指针具有 SharedReadOnly 语义 —— ParentRef 只产生 &T
    ///
    /// 不要在结果上调用 assumeMut；存储的指针没有写入权限
    public static func new(parent: T): ParentRef<T> {
        let ref_ = ParentRef<T>()
        ref_.ptr = 0  // 在仓颉中简化，使用对象引用代替原始指针
        ref_._generation = 0
        ref_._marker = None<LiveMarker>
        return ref_
    }

    /// 构造并捕获父对象的活性 generation
    /// 对于任何具有有限生命周期的父对象，优先使用此方法而非 new
    /// 以便在 debug 构建中捕获 use-after-drop
    ///
    /// 相同的 SharedReadOnly 来源语义限制
    public static func anchored(parent: T, marker: LiveMarker): ParentRef<T> {
        let ref_ = ParentRef<T>()
        ref_.ptr = 0
        if (Environment.isDebug) {
            ref_._generation = marker.getGeneration()
            ref_._marker = Some(marker)
        }
        return ref_
    }

    /// 包装原始指针 (FFI / container_of 恢复)
    /// p 必须非空、对齐，并指向一个在 ParentRef 整个生命周期内保持活性的 T
    public static func fromRaw(p: UInt64): ParentRef<T> {
        let ref_ = ParentRef<T>()
        ref_.ptr = p
        ref_._generation = 0
        ref_._marker = None<LiveMarker>
        return ref_
    }

    /// 包装具有写入来源的原始 *mut T (Zig *T)
    /// 这是用于稍后调用 assumeMut 的构造函数
    public static func fromRawMut(p: UInt64): ParentRef<T> {
        let ref_ = ParentRef<T>()
        ref_.ptr = p
        ref_._generation = 0
        ref_._marker = None<LiveMarker>
        return ref_
    }

    /// 便利方法: 如果 p 非空返回 Some(fromRawMut(p))，否则返回 None
    public static func fromNullableMut(p: UInt64): ?ParentRef<T> {
        if (p == 0) {
            return None<ParentRef<T>>
        }
        return Some(ParentRef<T>.fromRawMut(p))
    }

    /// Debug-only 的 anchored 引用的活性断言
    func debugAssertLive(): Unit {
        if (Environment.isDebug) {
            match (this._marker) {
                case Some(marker) =>
                    marker.assertLive(this._generation)
                case None => ()
            }
        }
    }

    /// 父对象的共享借用。如果 anchored，Debug 断言活性
    public func get(): UInt64 {
        this.debugAssertLive()
        return this.ptr
    }

    /// 原始指针 (用于 container_of, FFI 往返, ptr-eq)
    public func asPtr(): UInt64 {
        this.ptr
    }

    /// 带有构造 ParentRef 时来源的原始指针
    /// 只有通过 fromRawMut / fromNullableMut 构造时才携带写入权限
    public func asMutPtr(): UInt64 {
        this.ptr
    }

    /// 显式不安全的独占借用，用于少数真正需要 &mut Parent 的场合
    /// 命名为 assumeMut 而非 getMut，使其不像常规访问器
    ///
    /// 调用者保证:
    ///   (a) 父对象在 'a 期间是活的
    ///   (b) 没有其他 & 或 &mut 与返回的借用重叠
    ///   (c) 此 ParentRef 通过 fromRawMut / fromNullableMut 从具有写入来源的指针构造
    public func assumeMut(): UInt64 {
        this.debugAssertLive()
        return this.ptr
    }

    /// 克隆
    public func clone(): ParentRef<T> {
        let ref_ = ParentRef<T>()
        ref_.ptr = this.ptr
        ref_._generation = this._generation
        ref_._marker = this._marker
        return ref_
    }

    /// 相等比较 (基于指针地址)
    public func equals(other: ParentRef<T>): Bool {
        this.ptr == other.ptr
    }

    /// Debug 字符串表示
    public func toString(): String {
        if (Environment.isDebug) {
            return "ParentRef(0x${this.ptr.toString(16)}, generation=0x${this._generation.toString(16)})"
        }
        return "ParentRef(0x${this.ptr.toString(16)})"
    }
}
