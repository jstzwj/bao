// ExternalShared - 外部引用计数管理的共享指针
// 严格翻译自: src/ptr/external_shared.zig
// 引用计数由外部函数管理的共享指针 (如 JavaScript GC 管理的对象)
package bao_core.ptr

// ============================================================================
// ExternalShared<T> - 外部管理的共享指针
// 对应 Bun: pub fn ExternalShared(comptime T: type) type
//
// T 必须提供 external_shared_descriptor 结构体:
//   pub const external_shared_descriptor = struct {
//       pub fn ref(T*) void;
//       pub fn deref(T*) void;
//   };
// ============================================================================

/// 外部引用计数描述符接口
// 对应 Bun: T.external_shared_descriptor 中的 ref/deref 函数
public interface ExternalSharedDescriptor {
    /// 增加引用计数
    func ref(ptr: CPointer<Unit>): Unit
    /// 减少引用计数
    func deref(ptr: CPointer<Unit>): Unit
}

/// 外部管理的共享指针 (非可选)
// 对应 Bun: ExternalShared(T) 的 NonOptional 部分
public class ExternalShared {
    private var impl: CPointer<Unit>

    public init() {
        impl = CPointer<Unit>()
    }

    private init(ptr: CPointer<Unit>) {
        this.impl = ptr
    }

    /// 接受一个已增加引用计数的原始指针
    // 对应 Bun: pub fn adopt(incremented_raw: *T) Self
    public static func adopt(incrementedRaw: CPointer<Unit>): ExternalShared {
        return ExternalShared(incrementedRaw)
    }

    /// 释放共享指针, 减少引用计数
    // 对应 Bun: pub fn deinit(self: *Self) void
    public func deinit(): Unit {
        if (!impl.isNull()) {
            getDescriptor().deref(impl)
            impl = CPointer<Unit>()
        }
    }

    /// 获取底层指针
    // 对应 Bun: pub fn get(self: Self) *T
    public func get(): CPointer<Unit> {
        return impl
    }

    /// 克隆共享指针, 增加引用计数
    // 对应 Bun: pub fn clone(self: Self) Self
    public func clone(): ExternalShared {
        if (!impl.isNull()) {
            getDescriptor().ref(impl)
        }
        return ExternalShared(impl)
    }

    /// 从原始指针克隆
    // 对应 Bun: pub fn cloneFromRaw(raw: *T) Self
    public static func cloneFromRaw(raw: CPointer<Unit>): ExternalShared {
        if (!raw.isNull()) {
            getDescriptor().ref(raw)
        }
        return ExternalShared(raw)
    }

    /// 泄漏原始指针, 不减少引用计数, 使 self 无效
    // 对应 Bun: pub fn leak(self: *Self) *T
    public func leak(): CPointer<Unit> {
        let result = impl
        impl = CPointer<Unit>()
        return result
    }

    /// 转为可选版本
    // 对应 Bun: pub fn intoOptional(self: *Self) Optional
    public func intoOptional(): ExternalSharedOptional {
        let opt = ExternalSharedOptional()
        opt.setImpl(impl)
        impl = CPointer<Unit>()
        return opt
    }

    /// 获取描述符 (子类应覆盖)
    protected static func getDescriptor(): ExternalSharedDescriptor {
        // 默认空实现, 实际使用时需提供具体描述符
        return DefaultExternalDescriptor()
    }
}

/// 外部管理的共享指针 (可选版本)
// 对应 Bun: ExternalShared(T).Optional
public class ExternalSharedOptional {
    private var impl: ?CPointer<Unit> = None

    public init() {}

    private init(ptr: ?CPointer<Unit>) {
        this.impl = ptr
    }

    /// 创建空指针
    // 对应 Bun: pub fn initNull() Optional
    public static func initNull(): ExternalSharedOptional {
        return ExternalSharedOptional()
    }

    /// 接受一个已增加引用计数的可选原始指针
    // 对应 Bun: pub fn adopt(incremented_raw: ?*T) Optional
    public static func adopt(incrementedRaw: ?CPointer<Unit>): ExternalSharedOptional {
        return ExternalSharedOptional(incrementedRaw)
    }

    /// 释放共享指针
    // 对应 Bun: pub fn deinit(self: *Optional) void
    public func deinit(): Unit {
        match (impl) {
            case Some(p) => ExternalShared.getDescriptor().deref(p)
            case None => ()
        }
        impl = None
    }

    /// 获取底层可选指针
    // 对应 Bun: pub fn get(self: Optional) ?*T
    public func get(): ?CPointer<Unit> {
        return impl
    }

    /// 取出非空指针, 设置 self 为 null
    // 对应 Bun: pub fn take(self: *Optional) ?NonOptional
    public func take(): ?ExternalShared {
        if (impl.isSome()) {
            let p = impl.getOrThrow()
            impl = None
            return ExternalShared.adopt(p)
        }
        return None
    }

    /// 克隆
    // 对应 Bun: pub fn clone(self: Optional) Optional
    public func clone(): ExternalSharedOptional {
        match (impl) {
            case Some(p) => ExternalShared.getDescriptor().ref(p)
            case None => ()
        }
        return ExternalSharedOptional(impl)
    }

    /// 从原始指针克隆
    // 对应 Bun: pub fn cloneFromRaw(raw: ?*T) Optional
    public static func cloneFromRaw(raw: ?CPointer<Unit>): ExternalSharedOptional {
        match (raw) {
            case Some(p) => ExternalShared.getDescriptor().ref(p)
            case None => ()
        }
        return ExternalSharedOptional(raw)
    }

    /// 泄漏原始指针
    // 对应 Bun: pub fn leak(self: *Optional) ?*T
    public func leak(): ?CPointer<Unit> {
        let result = impl
        impl = None
        return result
    }

    /// 内部设置 (用于 intoOptional)
    public func setImpl(ptr: CPointer<Unit>): Unit {
        if (ptr.isNull()) {
            impl = None
        } else {
            impl = ptr
        }
    }
}

/// 默认外部引用计数描述符 (空操作)
// 用于没有外部引用计数的类型
private class DefaultExternalDescriptor <: ExternalSharedDescriptor {
    public func ref(ptr: CPointer<Unit>): Unit {
        // 默认空操作
    }
    public func deref(ptr: CPointer<Unit>): Unit {
        // 默认空操作
    }
}
