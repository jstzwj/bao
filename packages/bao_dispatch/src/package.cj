// bao_dispatch - 跨包闭集分发机制
// 严格翻译自: src/dispatch/lib.rs
//   Bun 的 dispatch 是一个 proc_macro crate, 通过 link_interface! 和 link_impl_<Iface>! 宏
//   实现跨 crate 的无 vtable 动态分发。分发通过 match kind { ... } 实现。
//   仓颉没有过程宏, 使用泛型 + enum + 接口模式实现等价语义。
package bao_dispatch

// ============================================================================
// DispatchKind - 分发种类标签
// 严格翻译自: src/dispatch/lib.rs:298-300
//   #[repr(u8)]
//   #[derive(Copy, Clone, PartialEq, Eq, Debug)]
//   pub enum <Iface>Kind { Js, Mini, ... }
//
// 在 Bun 中, link_interface! 宏为每个接口生成一个 Kind 枚举。
// 例如: EventLoopOps -> EventLoopOpsKind { Js, Mini }
// 仓颉中定义通用枚举, 各接口复用。
// ============================================================================

/// 分发种类 - 对应 Bun <Interface>Kind
/// #[repr(u8)] #[derive(Copy, Clone, PartialEq, Eq, Debug)]
/// pub enum EventLoopOpsKind { Js, Mini }
public enum DispatchKind {
    | Js       // JavaScript 事件循环
    | Mini     // Mini 事件循环

    public operator func == (rhs: DispatchKind): Bool {
        match (this) {
            case Js => match (rhs) { case Js => true; case _ => false }
            case Mini => match (rhs) { case Mini => true; case _ => false }
        }
    }
}

// ============================================================================
// DispatchHandle - 分发句柄
// 严格翻译自: src/dispatch/lib.rs:302-306
//   #[derive(Copy, Clone)]
//   pub struct <Iface> {
//       pub kind: <Iface>Kind,
//       pub owner: *mut (),
//   }
//
// SAFETY: owner 必须是一个活着的 *mut T, 其中 T 是 kind 变体的
// link_impl 对应的具体类型, 且必须在每次分发期间保持活着。
// 这个不变量在 unsafe fn new() 中建立 —— 这是调用者编写 unsafe 的唯一位置。
// ============================================================================

/// 分发句柄 - 对应 Bun <Interface> handle
/// 包含一个分发种类标签和不透明所有者指针
public class DispatchHandle {
    /// 分发种类标签
    // 对应 Bun: pub kind: <Iface>Kind
    public var kind: DispatchKind

    /// 不透明所有者指针
    // 对应 Bun: pub owner: *mut ()
    // 指向实际实现对象的不透明指针, 通过 kind 分发到正确的实现
    public var owner: CPointer<Unit>

    public init() {
        kind = DispatchKind.Mini
        owner = CPointer<Unit>()
    }

    /// 创建分发句柄
    // 严格翻译自: src/dispatch/lib.rs:316-319
    //   #[inline]
    //   pub unsafe fn new<T: ?Sized>(kind: <Iface>Kind, owner: *mut T) -> Self {
    //       Self { kind, owner: owner as *mut () }
    //   }
    //
    // SAFETY: owner 必须是活着的 *mut T, 且 T 匹配 kind 变体的 link_impl 类型。
    // owner 必须在通过此 handle 进行的所有分发期间保持活着。
    public static func new(kind: DispatchKind, owner: CPointer<Unit>): DispatchHandle {
        let handle = DispatchHandle()
        handle.kind = kind
        handle.owner = owner
        return handle
    }

    /// 检查是否是指定种类
    // 严格翻译自: src/dispatch/lib.rs:320-321
    //   #[inline]
    //   pub fn is(&self, kind: <Iface>Kind) -> bool { self.kind == kind }
    public func is(kind: DispatchKind): Bool {
        return this.kind == kind
    }
}

// ============================================================================
// DispatchMethod - 分发方法描述
// 严格翻译自: src/dispatch/lib.rs:61-65
//   struct Method {
//       name: Ident,
//       args: Vec<(Ident, Type)>,
//       ret: ReturnType,
//   }
//
// 在 Bun 的 proc_macro 中, Method 描述接口中的方法签名。
// 仓颉中使用类来表示方法描述。
// ============================================================================

/// 分发方法参数
public class DispatchArg {
    public let name: String
    public let typeName: String

    public init(name: String, typeName: String) {
        this.name = name
        this.typeName = typeName
    }
}

/// 分发方法描述 - 对应 Bun dispatch::Method
public class DispatchMethod {
    /// 方法名
    // 对应 Bun: name: Ident
    public let name: String

    /// 参数列表
    // 对应 Bun: args: Vec<(Ident, Type)>
    public let args: ArrayList<DispatchArg>

    /// 返回类型名
    // 对应 Bun: ret: ReturnType
    public let returnType: String

    public init(name: String, args: ArrayList<DispatchArg>, returnType: String) {
        this.name = name
        this.args = args
        this.returnType = returnType
    }
}

// ============================================================================
// DispatchInterface - 分发接口声明
// 严格翻译自: src/dispatch/lib.rs:54-59
//   struct Interface {
//       vis: Visibility,
//       name: Ident,
//       variants: Vec<Ident>,
//       methods: Vec<Method>,
//   }
//
// 在 Bun 的 proc_macro 中, link_interface! 宏解析为 Interface 结构体,
// 然后生成 Kind 枚举、Handle 结构体、分发方法和 link_impl_<Name>! 宏。
// 仓颉中使用类来表示接口声明。
// ============================================================================

/// 分发接口声明 - 对应 Bun dispatch::Interface
public class DispatchInterface {
    /// 接口名称
    // 对应 Bun: name: Ident
    public let name: String

    /// 可见性
    // 对应 Bun: vis: Visibility
    public let visibility: String

    /// 变体名称列表
    // 对应 Bun: variants: Vec<Ident>
    public let variants: ArrayList<String>

    /// 方法列表
    // 对应 Bun: methods: Vec<Method>
    public let methods: ArrayList<DispatchMethod>

    public init(name: String, visibility: String) {
        this.name = name
        this.visibility = visibility
        this.variants = ArrayList<String>()
        this.methods = ArrayList<DispatchMethod>()
    }

    /// 添加变体
    public func addVariant(name: String): Unit {
        variants.append(name)
    }

    /// 添加方法
    public func addMethod(method: DispatchMethod): Unit {
        methods.append(method)
    }
}

// ============================================================================
// LinkInterface - 接口注册表
// 严格翻译自: src/dispatch/lib.rs:138-345 (link_interface proc_macro)
//
// Bun 的 link_interface! 宏在声明端完成以下工作:
//   1. 生成 #[repr(u8)] enum <Name>Kind { <variants> }
//   2. 生成 pub struct <Name> { kind: <Name>Kind, owner: *mut () }
//   3. 为每个方法生成类型别名 (pub type __<Name>__<method>__ret, ...)
//   4. 生成 extern "Rust" 声明 (fn __bun_dispatch__<Iface>__<Variant>__<method>(...))
//   5. 生成分发方法 (match kind { ... } 调用对应的 extern 函数)
//   6. 生成 #[macro_export] macro_rules! link_impl_<Name>! { ... }
//
// 在仓颉中, 通过运行时注册表 + foreign func 实现等价功能。
// ============================================================================

/// 链接接口注册表 - 管理 link_interface 声明的接口
public class LinkInterface {
    /// 已注册的接口
    private static var interfaces: HashMap<String, DispatchInterface> = HashMap<String, DispatchInterface>()

    /// 注册接口 (等价于 link_interface! 宏调用)
    public static func register(iface: DispatchInterface): Unit {
        interfaces.put(iface.name, iface)
    }

    /// 获取接口
    public static func get(name: String): ?DispatchInterface {
        interfaces.get(name)
    }

    /// 列出所有接口名
    public static func listNames(): ArrayList<String> {
        let names = ArrayList<String>()
        for ((name, _) in interfaces) {
            names.append(name)
        }
        return names
    }
}

// ============================================================================
// LinkImpl - 实现注册
// 严格翻译自: src/dispatch/lib.rs:228-295 (link_impl 生成的 entry_arms)
//
// Bun 的 link_impl_<Iface>! 宏在实现端完成:
//   1. 为每个变体生成 #[unsafe(no_mangle)] 函数
//   2. 函数将 *mut () 转型为具体类型指针
//   3. 在 unsafe 块中执行用户提供的实现体
//
// 示例 (Bun):
//   #[unsafe(no_mangle)]
//   unsafe fn __bun_dispatch__EventLoopOps__Mini__platform_loop(
//       __owner: *mut (),
//   ) -> *mut Loop {
//       let this: *mut MiniEventLoop = __owner.cast();
//       unsafe { (*this).loop_ptr() }
//   }
//
// 在仓颉中, 通过函数注册表实现:
// ============================================================================

/// 实现函数类型
public typealias DispatchFn = (CPointer<Unit>) -> Unit

/// 链接实现注册表 - 管理 link_impl 注册的实现
public class LinkImpl {
    /// 已注册的实现函数
    // key 格式: "<interface>__<variant>__<method>"
    private static var implementations: HashMap<String, DispatchFn> = HashMap<String, DispatchFn>()

    /// 注册实现函数 (等价于 link_impl_<Iface>! 宏调用)
    // 对应 Bun: #[unsafe(no_mangle)] unsafe fn __bun_dispatch__<Iface>__<Variant>__<method>(...)
    public static func register(interfaceName: String, variantName: String, methodName: String, fn: DispatchFn): Unit {
        let key = "${interfaceName}__${variantName}__${methodName}"
        implementations.put(key, fn)
    }

    /// 调用实现函数
    // 对应 Bun: match self.kind { <Variant> => unsafe { <externs>::<symbol>(self.owner, ...) } }
    public static func call(interfaceName: String, variantName: String, methodName: String, owner: CPointer<Unit>): Unit {
        let key = "${interfaceName}__${variantName}__${methodName}"
        match (implementations.get(key)) {
            case Some(fn) => fn(owner)
            case None => throw Exception("dispatch: unimplemented __bao_dispatch__${interfaceName}__${variantName}__${methodName}")
        }
    }

    /// 检查实现是否已注册
    public static func isRegistered(interfaceName: String, variantName: String, methodName: String): Bool {
        let key = "${interfaceName}__${variantName}__${methodName}"
        implementations.contains(key)
    }
}

// ============================================================================
// EventLoopOps - 事件循环操作接口 (示例接口)
// 严格翻译自: src/dispatch/lib.rs:17-22 (文档中的示例)
//   bun_dispatch::link_interface! {
//       pub EventLoopOps[Js, Mini] {
//           fn platform_loop() -> *mut Loop;
//           fn set_after_cb(cb: Option<Cb>, ctx: *mut c_void);
//       }
//   }
//
// 这是 dispatch crate 文档中展示的主要接口示例。
// 在 Bun 中由 link_interface! 宏自动生成, 仓颉中手动定义。
// ============================================================================

/// 事件循环操作接口 - 对应 Bun EventLoopOps
/// 通过 DispatchHandle 进行无 vtable 的跨 crate 分发
public class EventLoopOps {
    /// 获取平台事件循环指针
    // 严格翻译自 Bun link_interface! 中的方法声明:
    //   fn platform_loop() -> *mut Loop;
    //
    // Bun 生成的分发代码:
    //   #[inline]
    //   pub fn platform_loop(&self) -> *mut Loop {
    //       match self.kind {
    //           Js => unsafe { __EventLoopOps_externs::__bun_dispatch__EventLoopOps__Js__platform_loop(self.owner) }
    //           Mini => unsafe { __EventLoopOps_externs::__bun_dispatch__EventLoopOps__Mini__platform_loop(self.owner) }
    //       }
    //   }
    public static func platformLoop(handle: DispatchHandle): CPointer<Unit> {
        let variantName = match (handle.kind) {
            case DispatchKind.Js => "Js"
            case DispatchKind.Mini => "Mini"
        }
        return EventLoopOpsDispatch.platformLoop(variantName, handle.owner)
    }

    /// 设置回调函数
    // 严格翻译自 Bun link_interface! 中的方法声明:
    //   fn set_after_cb(cb: Option<Cb>, ctx: *mut c_void);
    public static func setAfterCb(handle: DispatchHandle, cb: ?CPointer<Unit>, ctx: CPointer<Unit>): Unit {
        let variantName = match (handle.kind) {
            case DispatchKind.Js => "Js"
            case DispatchKind.Mini => "Mini"
        }
        EventLoopOpsDispatch.setAfterCb(variantName, handle.owner, cb, ctx)
    }
}

// ============================================================================
// EventLoopOpsDispatch - 事件循环操作的外部函数声明
// 严格翻译自: src/dispatch/lib.rs:180-189 (生成的 extern 声明)
//   unsafe extern "Rust" {
//       fn __bun_dispatch__EventLoopOps__Js__platform_loop(owner: *mut ()) -> *mut Loop;
//       fn __bun_dispatch__EventLoopOps__Mini__platform_loop(owner: *mut ()) -> *mut Loop;
//       fn __bun_dispatch__EventLoopOps__Js__set_after_cb(owner: *mut (), cb: Option<Cb>, ctx: *mut c_void);
//       fn __bun_dispatch__EventLoopOps__Mini__set_after_cb(owner: *mut (), cb: Option<Cb>, ctx: *mut c_void);
//   }
//
// 在仓颉中通过 foreign func 声明对应的 C ABI 函数。
// 这些函数由高层 crate (如 bao_event_loop) 提供。
// ============================================================================

/// 事件循环分发 - 外部函数桥接
public class EventLoopOpsDispatch {

    /// 分发 platformLoop
    // 对应 Bun:
    //   match self.kind {
    //     Js => unsafe { __bun_dispatch__EventLoopOps__Js__platform_loop(self.owner) }
    //     Mini => unsafe { __bun_dispatch__EventLoopOps__Mini__platform_loop(self.owner) }
    //   }
    public static func platformLoop(variant: String, owner: CPointer<Unit>): CPointer<Unit> {
        match (variant) {
            case "Js" => platformLoopJs(owner)
            case "Mini" => platformLoopMini(owner)
            case _ => CPointer<Unit>()
        }
    }

    /// 分发 setAfterCb
    public static func setAfterCb(variant: String, owner: CPointer<Unit>, cb: ?CPointer<Unit>, ctx: CPointer<Unit>): Unit {
        match (variant) {
            case "Js" => setAfterCbJs(owner, cb, ctx)
            case "Mini" => setAfterCbMini(owner, cb, ctx)
            case _ => ()
        }
    }
}

// Js 变体的外部函数声明
// 对应 Bun: unsafe extern "Rust" { fn __bun_dispatch__EventLoopOps__Js__platform_loop(...); }
foreign func platformLoopJs(owner: CPointer<Unit>): CPointer<Unit>
foreign func setAfterCbJs(owner: CPointer<Unit>, cb: ?CPointer<Unit>, ctx: CPointer<Unit>): Unit

// Mini 变体的外部函数声明
// 对应 Bun: unsafe extern "Rust" { fn __bun_dispatch__EventLoopOps__Mini__platform_loop(...); }
foreign func platformLoopMini(owner: CPointer<Unit>): CPointer<Unit>
foreign func setAfterCbMini(owner: CPointer<Unit>, cb: ?CPointer<Unit>, ctx: CPointer<Unit>): Unit

// ============================================================================
// DispatchRegistry<T> - 泛型分发注册器
// 提供类型安全的运行时分发, 作为 link_impl 的等价机制
// ============================================================================

/// 泛型分发注册器 - 类型安全的运行时分发
public class DispatchRegistry<T> {
    private var handlers: HashMap<String, (CPointer<Unit>) -> T> = HashMap<String, (CPointer<Unit>) -> T>()

    public init() {}

    /// 注册处理器 (等价于 link_impl 中的变体实现)
    public func register(kind: String, handler: (CPointer<Unit>) -> T): Unit {
        handlers.put(kind, handler)
    }

    /// 分发调用 (等价于 match kind { ... } 分发)
    public func dispatch(kind: String, owner: CPointer<Unit>): ?T {
        match (handlers.get(kind)) {
            case Some(handler) => Some(handler(owner))
            case None => None
        }
    }

    /// 检查是否已注册
    public func has(kind: String): Bool {
        handlers.contains(kind)
    }
}
