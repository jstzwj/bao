// 严格翻译自: src/ptr/external_shared.zig
// ExternalShared - 引用计数由外部函数管理的共享指针
package bao_ptr

import bao_core.*

// ============================================================================
// ExternalSharedDescriptor - 外部共享指针描述符接口
// ============================================================================

/// 外部共享指针的描述符接口
/// T 必须实现此接口以定义 ref/deref 操作
public interface ExternalSharedDescriptor<T> {
    func ref(ptr: T): Unit
    func deref(ptr: T): Unit
}

// ============================================================================
// ExternalShared - 外部管理的共享指针
// ============================================================================

/// 引用计数由外部管理的共享指针
/// 例如通过 extern 函数管理
///
/// T 必须有 external_shared_descriptor 属性，包含 ref 和 deref 方法
public class ExternalShared<T> where T <: ExternalSharedDescriptor<T> {
    var _impl: ?T = None<T>

    public init() {}

    /// 采用已增加引用计数的原始指针
    /// incremented_raw 应该已经将其引用计数增加了 1
    public static func adopt(incrementedRaw: T): ExternalShared<T> {
        let es = ExternalShared<T>()
        es._impl = Some(incrementedRaw)
        return es
    }

    /// 反初始化共享指针，减少引用计数
    public func deinit(): Unit {
        match (this._impl) {
            case Some(impl) =>
                impl.deref(impl)
            case None => ()
        }
        this._impl = None<T>
    }

    /// 获取底层指针
    /// 此指针在 self deinit 后可能无效
    public func get(): ?T {
        this._impl
    }

    /// 克隆共享指针，增加引用计数
    public func clone(): ExternalShared<T> {
        match (this._impl) {
            case Some(impl) =>
                impl.ref(impl)
                let result = ExternalShared<T>()
                result._impl = this._impl
                return result
            case None =>
                return ExternalShared<T>()
        }
    }

    /// 从原始指针克隆
    public static func cloneFromRaw(raw: T): ExternalShared<T> {
        raw.ref(raw)
        let es = ExternalShared<T>()
        es._impl = Some(raw)
        return es
    }

    /// 返回原始指针但不减少引用计数。使 self 失效
    public func leak(): ?T {
        let result = this._impl
        this._impl = None<T>
        return result
    }

    /// 转换为 Optional 版本
    public func intoOptional(): ExternalSharedOptional<T> {
        let opt = ExternalSharedOptional<T>()
        opt._impl = this._impl
        this._impl = None<T>
        return opt
    }
}

// ============================================================================
// ExternalSharedOptional - ExternalShared 的 Optional 版本
// ============================================================================

/// ExternalShared 的可选版本，可以持有 null
public class ExternalSharedOptional<T> where T <: ExternalSharedDescriptor<T> {
    var _impl: ?T = None<T>

    public init() {}

    /// 创建空 Optional
    public static func initNull(): ExternalSharedOptional<T> {
        ExternalSharedOptional<T>()
    }

    /// 采用已增加引用计数的原始指针
    public static func adopt(incrementedRaw: ?T): ExternalSharedOptional<T> {
        let opt = ExternalSharedOptional<T>()
        opt._impl = incrementedRaw
        return opt
    }

    /// 反初始化，减少引用计数
    public func deinit(): Unit {
        match (this._impl) {
            case Some(impl) =>
                impl.deref(impl)
            case None => ()
        }
        this._impl = None<T>
    }

    /// 获取底层指针
    public func get(): ?T {
        this._impl
    }

    /// 取出值，将 self 设为 null
    public func take(): ?ExternalShared<T> {
        match (this._impl) {
            case Some(impl) =>
                let nonOpt = ExternalShared<T>()
                nonOpt._impl = Some(impl)
                this._impl = None<T>
                return Some(nonOpt)
            case None =>
                return None<ExternalShared<T>>
        }
    }

    /// 克隆
    public func clone(): ExternalSharedOptional<T> {
        match (this._impl) {
            case Some(impl) =>
                impl.ref(impl)
                let result = ExternalSharedOptional<T>()
                result._impl = this._impl
                return result
            case None =>
                return ExternalSharedOptional<T>()
        }
    }

    /// 从原始指针克隆
    public static func cloneFromRaw(raw: ?T): ExternalSharedOptional<T> {
        match (raw) {
            case Some(someRaw) =>
                someRaw.ref(someRaw)
                let opt = ExternalSharedOptional<T>()
                opt._impl = raw
                return opt
            case None =>
                return ExternalSharedOptional<T>()
        }
    }

    /// 返回原始指针但不减少引用计数。使 self 失效
    public func leak(): ?T {
        let result = this._impl
        this._impl = None<T>
        return result
    }
}
