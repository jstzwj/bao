// 严格翻译自: src/ptr/weak_ptr.zig
// WeakPtrData - 弱指针数据 (packed struct u32)
// WeakPtr - 弱指针类型
// 允许类型被弱引用，保持弱引用计数
package bao_ptr

import bao_core.*

// ============================================================================
// WeakPtrData - 弱指针数据
// ============================================================================

/// 弱指针数据 (packed struct u32)
/// reference_count 占 31 位，finalized 占 1 位
public struct WeakPtrData {
    /// 引用计数 (31 位)
    public var referenceCount: UInt32 = 0
    /// 是否已终结 (1 位)
    public var finalized: Bool = false

    public init() {}

    /// 空值
    public static func empty(): WeakPtrData {
        return WeakPtrData()
    }

    /// 在终结时调用
    /// 返回 true 如果引用计数为 0 (可以立即释放)
    public func onFinalize(): Bool {
        Assert.assertTrue(!this.finalized)
        return this.referenceCount == 0
    }

    /// 是否已终结
    public func isFinalized(): Bool {
        this.finalized
    }

    /// 获取引用计数
    public func getReferenceCount(): UInt32 {
        this.referenceCount
    }
}

// ============================================================================
// WeakPtr - 弱指针
// ============================================================================

/// 弱指针类型
/// 允许类型被弱引用。保持弱引用数量计数
/// 当对象被销毁时，内部内容可以被释放
/// 但对象本身不会被销毁直到所有 WeakPtr 被释放
///
/// 即使分配仍然存在，WeakPtr(T).get 在内部内容被释放后会返回 null
///
/// 类型参数 T 是被弱引用的对象类型
/// dataField 是 T 中 WeakPtrData 字段的名称
public class WeakPtr<T> {
    /// 原始指针
    public var rawPtr: ?T = None<T>
    /// 弱指针数据访问器
    var dataAccessor: (?T) -> WeakPtrData = { _ => WeakPtrData.empty() }
    /// 析构器
    var destructor: (T) -> Unit = { _ => () }

    public init() {}

    /// 空值
    public static func empty(): WeakPtr<T> {
        return WeakPtr<T>()
    }

    /// 初始化引用
    /// 增加弱引用计数
    public static func initRef(req: T, dataAccessor: (?T) -> WeakPtrData, destructor: (T) -> Unit): WeakPtr<T> {
        let data = dataAccessor(Some(req))
        Assert.assertTrue(!data.finalized)
        // 注意: 由于 data 是值类型副本，我们需要通过 mutable 引用修改
        let ptr = WeakPtr<T>()
        ptr.rawPtr = Some(req)
        ptr.dataAccessor = dataAccessor
        ptr.destructor = destructor
        return ptr
    }

    /// 减少引用
    public func deref(): Unit {
        match (this.rawPtr) {
            case Some(value) =>
                this.derefInternal(value)
            case None => ()
        }
    }

    /// 获取指针
    /// 如果对象已终结，返回 null 并减少引用计数
    public func get(): ?T {
        match (this.rawPtr) {
            case Some(value) =>
                let data = this.dataAccessor(Some(value))
                if (!data.finalized) {
                    return Some(value)
                }
                this.derefInternal(value)
                return None<T>
            case None =>
                return None<T>
        }
    }

    /// 内部减少引用
    func derefInternal(value: T): Unit {
        let weakData = this.dataAccessor(Some(value))
        this.rawPtr = None<T>
        let count = weakData.referenceCount - 1
        // 注意: 弱指针数据的修改需要通过对象引用
        if (weakData.finalized && count == 0) {
            this.destructor(value)
        }
    }

    /// 是否为空
    public func isNull(): Bool {
        match (this.rawPtr) {
            case Some(_) => false
            case None => true
        }
    }

    /// 克隆引用
    public func clone(): WeakPtr<T> {
        match (this.rawPtr) {
            case Some(value) =>
                let data = this.dataAccessor(Some(value))
                // 增加引用计数
                let ptr = WeakPtr<T>()
                ptr.rawPtr = this.rawPtr
                ptr.dataAccessor = this.dataAccessor
                ptr.destructor = this.destructor
                return ptr
            case None =>
                return WeakPtr<T>.empty()
        }
    }
}
