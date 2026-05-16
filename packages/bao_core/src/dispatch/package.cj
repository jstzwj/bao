// dispatch - 任务调度接口
// 严格翻译自: src/dispatch/lib.rs
// 跨 crate 的闭集分发, 通过 link-time 符号实现无 vtable 的动态分发
package bao_core.dispatch

import std.collection.*

// ============================================================================
// dispatch 模块 - 跨 crate 分发机制
// 对应 Bun: src/dispatch/lib.rs
//
// 在 Bun (Rust) 中, dispatch 是一个 proc_macro crate:
// - link_interface! 宏定义接口和 handle 类型
// - link_impl_<Iface>! 宏在高层 crate 中实现具体变体
// - 分发通过 match kind { ... } 实现, 无 vtable 开销
//
// 在仓颉中, 仓颉没有过程宏, 使用泛型 + enum 模式实现等价语义
// ============================================================================

/// 分发种类标签
// 对应 Bun: #[repr(u8)] #[derive(Copy, Clone, PartialEq, Eq, Debug)] pub enum <Iface>Kind
public enum DispatchKind {
    | Js      // JavaScript 事件循环
    | Mini    // Mini 事件循环

    public operator func ==(right: DispatchKind): Bool {
        match (this) {
            case Js => match (right) {
                case Js => true
                case Mini => false
            }
            case Mini => match (right) {
                case Js => false
                case Mini => true
            }
        }
    }
}

/// 分发句柄
// 对应 Bun: #[derive(Copy, Clone)] pub struct <Iface> { pub kind: Kind, pub owner: *mut () }
//
/// SAFETY: owner 必须是一个活着的 *mut T, 其中 T 是 kind 变体的 link_impl 对应的具体类型
/// 此不变量在 unsafe fn new() 中建立
public class DispatchHandle {
    /// 分发种类
    public var kind: DispatchKind
    /// 不透明所有者指针
    // 对应 Bun: pub owner: *mut ()
    public var owner: CPointer<Unit>

    public init() {
        kind = DispatchKind.Mini
        owner = CPointer<Unit>()
    }

    /// 创建分发句柄
    // 对应 Bun: pub unsafe fn new<T: ?Sized>(kind: Kind, owner: *mut T) -> Self
    //
    // SAFETY: owner 必须是活着的 *mut T, 且 T 匹配 kind 变体的 link_impl 类型
    // owner 必须在通过此 handle 进行的所有分发期间保持活着
    // 这是调用者编写 unsafe 的唯一地方
    public static func new(kind: DispatchKind, owner: CPointer<Unit>): DispatchHandle {
        let handle = DispatchHandle()
        handle.kind = kind
        handle.owner = owner
        return handle
    }

    /// 检查是否是指定种类
    // 对应 Bun: pub fn is(&self, kind: Kind) -> bool
    public func `is`(kind: DispatchKind): Bool {
        return this.kind == kind
    }
}

// ============================================================================
// 分发方法接口
// 对应 Bun: link_interface! 中定义的方法签名
//
// 在 Bun 中通过 proc_macro 生成 extern "Rust" 函数声明
// 在仓颉中通过 foreign func 和 match kind 实现
// ============================================================================

/// 分发接口 - 事件循环操作
// 对应 Bun: link_interface! { pub EventLoopOps[Js, Mini] { ... } }
//
// 示例接口:
//   fn platform_loop() -> *mut Loop;
//   fn set_after_cb(cb: Option<Cb>, ctx: *mut c_void);
//
// 在仓颉中, 每个方法通过 match kind 分发到具体实现
public class EventLoopOps {
    /// 平台循环的分发实现
    // 对应 Bun: fn platform_loop() -> *mut Loop
    //
    // 在 Bun 中:
    //   match self.kind {
    //     Js => unsafe { __EventLoopOps_externs::__bun_dispatch__EventLoopOps__Js__platform_loop(self.owner) }
    //     Mini => unsafe { __EventLoopOps_externs::__bun_dispatch__EventLoopOps__Mini__platform_loop(self.owner) }
    //   }
    public static func platformLoop(handle: DispatchHandle): CPointer<Unit> {
        unsafe {
            match (handle.kind) {
                case DispatchKind.Js => platformLoopJs(handle.owner)
                case DispatchKind.Mini => platformLoopMini(handle.owner)
            }
        }
    }

    /// 设置回调的分发实现
    // 对应 Bun: fn set_after_cb(cb: Option<Cb>, ctx: *mut c_void)
    public static func setAfterCb(handle: DispatchHandle, cb: CPointer<Unit>, ctx: CPointer<Unit>): Unit {
        unsafe {
            match (handle.kind) {
                case DispatchKind.Js => setAfterCbJs(handle.owner, cb, ctx)
                case DispatchKind.Mini => setAfterCbMini(handle.owner, cb, ctx)
            }
        }
    }
}

// ============================================================================
// 外部函数声明 (对应 Bun 的 extern "Rust" 声明)
// 对应 Bun: unsafe extern "Rust" { fn __bun_dispatch__<Iface>__<Variant>__<method>(...) }
//
// 这些函数由高层 crate 通过 link_impl_<Iface>! 宏生成
// 在仓颉中通过 foreign func 声明
// ============================================================================

// Js 变体的实现
@C
foreign func platformLoopJs(owner: CPointer<Unit>): CPointer<Unit>
@C
foreign func setAfterCbJs(owner: CPointer<Unit>, cb: CPointer<Unit>, ctx: CPointer<Unit>): Unit

// Mini 变体的实现
@C
foreign func platformLoopMini(owner: CPointer<Unit>): CPointer<Unit>
@C
foreign func setAfterCbMini(owner: CPointer<Unit>, cb: CPointer<Unit>, ctx: CPointer<Unit>): Unit

// ============================================================================
// link_impl 宏的仓颉等价
// 对应 Bun: link_impl_<Iface>! { Mini for MiniEventLoop<'static> => |this| { ... } }
//
// 在 Bun 中, link_impl 宏生成 #[unsafe(no_mangle)] 函数:
//
//   #[unsafe(no_mangle)]
//   unsafe fn __bun_dispatch__EventLoopOps__Mini__platform_loop(
//       __owner: *mut (),
//   ) -> *mut Loop {
//       let this: *mut MiniEventLoop = __owner.cast();
//       unsafe { (*this).loop_ptr() }
//   }
//
// 在仓颉中, 实现通过具体函数提供, 通过 foreign func 链接
// ============================================================================

/// 分发注册器
// 辅助类型, 用于在运行时注册分发实现
public class DispatchRegistry<T> {
    private var handlers: HashMap<String, (CPointer<Unit>) -> T> = HashMap<String, (CPointer<Unit>) -> T>()

    public init() {}

    /// 注册处理器
    public func register(kind: String, handler: (CPointer<Unit>) -> T): Unit {
        handlers.add(kind, handler)
    }

    /// 分发调用
    public func dispatch(kind: String, owner: CPointer<Unit>): ?T {
        match (handlers.get(kind)) {
            case Some(handler) => Some(handler(owner))
            case None => None
        }
    }
}
