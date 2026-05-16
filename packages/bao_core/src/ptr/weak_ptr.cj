// WeakPtr - 弱引用指针
// 严格翻译自: src/ptr/weak_ptr.zig
// 允许对类型进行弱引用, 保持引用计数
// 当对象被销毁时释放内部内容, 但对象本身在所有 WeakPtr 释放前不被销毁
package bao_core.ptr

// ============================================================================
// WeakPtrData - 弱引用数据
// ============================================================================
public class WeakPtrData {
    /// 弱引用计数 (31 位)
    public var referenceCount: UInt32
    /// 是否已终结
    public var finalized: Bool

    /// 空数据常量
    public static let empty: WeakPtrData = WeakPtrData()

    public init() {
        referenceCount = 0
        finalized = false
    }

    /// 终结时调用, 返回是否可以销毁 (ref count == 0)
    public func onFinalize(): Bool {
        if (finalized) {
            throw Exception("WeakPtrData.onFinalize: already finalized")
        }
        finalized = true
        return referenceCount == 0
    }
}

// ============================================================================
// WeakPtr<T> - 弱引用指针
// T: 指向的数据类型
// 使用 ?T 代替 CPointer<T> 以避免 CType 约束问题
// ============================================================================
public class WeakPtr<T> {
    /// 原始引用
    private var rawPtr: ?T = None

    /// 空指针常量
    public static func empty(): WeakPtr<T> {
        return WeakPtr<T>()
    }

    public init() {}

    /// 创建一个弱引用 (增加引用计数)
    public static func initRef(req: T, getWeakData: (T) -> WeakPtrData): WeakPtr<T> {
        let weakData = getWeakData(req)
        if (weakData.finalized) {
            throw Exception("WeakPtr.initRef: object already finalized")
        }
        weakData.referenceCount += 1
        let wp = WeakPtr<T>()
        wp.rawPtr = req
        return wp
    }

    /// 减少弱引用
    public func deref(getWeakData: (T) -> WeakPtrData, destroy: (T) -> Unit): Unit {
        if (rawPtr.isSome()) {
            derefInternal(rawPtr.getOrThrow(), getWeakData, destroy)
        }
    }

    /// 获取底层引用 (如果已终结则返回 null)
    public func get(getWeakData: (T) -> WeakPtrData, destroy: (T) -> Unit): ?T {
        if (rawPtr.isSome()) {
            let value = rawPtr.getOrThrow()
            let weakData = getWeakData(value)
            if (!weakData.finalized) {
                return value
            }
            derefInternal(value, getWeakData, destroy)
            return None
        }
        return None
    }

    /// 内部: 减少弱引用计数
    private func derefInternal(
        value: T,
        getWeakData: (T) -> WeakPtrData,
        destroy: (T) -> Unit
    ): Unit {
        let weakData = getWeakData(value)
        rawPtr = None
        let count = weakData.referenceCount - 1
        weakData.referenceCount = count
        if (weakData.finalized && count == 0) {
            destroy(value)
        }
    }

    /// 获取原始引用 (不检查终结状态)
    public func rawPointer(): ?T {
        return rawPtr
    }

    /// 是否为空
    public func isNull(): Bool {
        return !rawPtr.isSome()
    }
}
