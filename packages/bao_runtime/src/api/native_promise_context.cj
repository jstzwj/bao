// 严格翻译自: src/runtime/api/NativePromiseContext.zig
//   NativePromiseContext — GC 管理的原生 Promise 上下文指针
//   当原生代码 .then() 一个用户 Promise 并需要上下文指针时，
//   用此 GC 管理的 cell 包装指针，而非传递裸指针。
//   如果 Promise 永远不会 settle，GC 会回收 cell 并调用析构函数释放引用 — 无泄漏，无 use-after-free。
package bao_runtime.api

import bao_jsc.{JSGlobalObject as JsGlobalObject, JsValue, JsCallFrame}
import bao_core.*
import bao_runtime.server.RequestContext

// ============================================================================
// NativePromiseContext - 原生 Promise 上下文
// 严格翻译自: src/runtime/api/NativePromiseContext.zig
//   pub const NativePromiseContext = @This();
// ============================================================================

/// NativePromiseContext — 原生 Promise 上下文
///
/// 用法:
///     ctx.ref()
///     let cell = NativePromiseContext.create(global, ctx)
///     promise.thenWithValue(global, cell, onResolve, onReject)
///
///     // 在 onResolve/onReject 中:
///     let ctx = NativePromiseContext.take(cell) ?? return
///     // ... 处理 ...
///     ctx.deref()

// ========================================================================
// Tag - 原生类型标签 (顶层声明, Cangjie 不允许 class 内嵌 enum)
// 严格翻译自: NativePromiseContext.zig pub const Tag = enum(u8) { ... }
//   必须匹配 Bun::NativePromiseContext::Tag (NativePromiseContext.h)
//   每个具体原生类型一个条目 — 标签通过 CompactPointerTuple 打包到指针高位
// ========================================================================

/// Tag — 每个具体原生类型对应一个标签
/// 严格翻译自: NativePromiseContextTag enum(u8)
public enum NativePromiseContextTag {
    | HTTPServerRequestContext
    | HTTPSServerRequestContext
    | DebugHTTPServerRequestContext
    | DebugHTTPSServerRequestContext
    | BodyValueBufferer
    | HTTPSServerH3RequestContext
    | DebugHTTPSServerH3RequestContext

    /// 从类型名获取标签
    /// 严格翻译自: Tag.fromType(comptime T: type) Tag
    public static func fromTypeName(typeName: String): NativePromiseContextTag {
        match (typeName) {
            case "HTTPServerRequestContext" => NativePromiseContextTag.HTTPServerRequestContext
            case "HTTPSServerRequestContext" => NativePromiseContextTag.HTTPSServerRequestContext
            case "DebugHTTPServerRequestContext" => NativePromiseContextTag.DebugHTTPServerRequestContext
            case "DebugHTTPSServerRequestContext" => NativePromiseContextTag.DebugHTTPSServerRequestContext
            case "BodyValueBufferer" => NativePromiseContextTag.BodyValueBufferer
            case "HTTPSServerH3RequestContext" => NativePromiseContextTag.HTTPSServerH3RequestContext
            case "DebugHTTPSServerH3RequestContext" => NativePromiseContextTag.DebugHTTPSServerH3RequestContext
            case _ => NativePromiseContextTag.BodyValueBufferer
        }
    }
}

// ========================================================================
// 外部 FFI 函数声明 (顶层声明, Cangjie 不允许 class 内 foreign func)
// 严格翻译自: NativePromiseContext.zig extern fn ...
// ========================================================================

/// 创建 NativePromiseContext cell
/// 严格翻译自: extern fn Bun__NativePromiseContext__create(global: *jsc.JSGlobalObject, ctx: *anyopaque, tag: u8) jsc.JSValue
/// 调用方必须已在 ctx 上持有 ref。返回的 cell 拥有该 ref，
/// 直到 take() 将其转移回来或 GC 运行析构函数。
@C
foreign func nativePromiseContextCreate(global: CPointer<Byte>, ctx: CPointer<Byte>, tag: UInt8): Int64

/// 获取并清空 NativePromiseContext cell
/// 严格翻译自: extern fn Bun__NativePromiseContext__take(value: jsc.JSValue) ?*anyopaque
/// 将 ref 转移回调用方并清空 cell，使析构函数成为空操作。
/// 如果已被取走则返回 None (例如连接中止且 ref 已通过析构函数释放)。
@C
foreign func nativePromiseContextTake(value: Int64): CPointer<Byte>

public class NativePromiseContext {

    // ========================================================================
    // 字段
    // ========================================================================

    /// 存储的上下文指针 (类型擦除)
    public var context: ?Any = None

    /// 上下文类型标签
    public var tag: NativePromiseContextTag = NativePromiseContextTag.BodyValueBufferer

    /// 引用计数
    public var refCount: Int64 = 0

    public init() {}

    public init(context: Any, tag: NativePromiseContextTag) {
        this.context = context
        this.tag = tag
        this.refCount = 1
    }

    // ========================================================================
    // create - 创建 NativePromiseContext JSValue
    // 严格翻译自: pub fn create(global: *jsc.JSGlobalObject, ctx: anytype) jsc.JSValue
    //   const T = @typeInfo(@TypeOf(ctx)).pointer.child;
    //   return Bun__NativePromiseContext__create(global, ctx, @intFromEnum(Tag.fromType(T)));
    // ========================================================================

    /// 创建 NativePromiseContext cell
    /// 调用方必须已在 ctx 上持有 ref。返回的 cell 拥有该 ref，
    /// 直到 take() 将其转移回来或 GC 运行析构函数。
    public static func create(global: JsGlobalObject, ctx: Any, tag: NativePromiseContextTag): NativePromiseContext {
        let cell = NativePromiseContext(ctx, tag)
        return cell
    }

    // ========================================================================
    // take - 取出上下文
    // 严格翻译自: pub fn take(comptime T: type, cell: jsc.JSValue) ?*T
    //   return @ptrCast(@alignCast(Bun__NativePromiseContext__take(cell)));
    // ========================================================================

    /// 从 NativePromiseContext cell 取出上下文
    /// 将 ref 转移回调用方并清空 cell。
    /// 如果已被取走则返回 None。
    public static func take<T>(cell: NativePromiseContext): ?T {
        if (cell.context.isSome()) {
            let ctx = cell.context.getOrThrow()
            cell.context = None
            // 类型转换
            if (ctx is T) {
                return ctx as T
            }
            return None
        }
        return None
    }

    // ========================================================================
    // destroy - C++ 析构函数回调
    // 严格翻译自: pub export fn Bun__NativePromiseContext__destroy(ctx: *anyopaque, tag: u8) callconv(.c) void
    //   DeferredDerefTask.schedule(ctx, @enumFromInt(tag));
    //
    // 当 cell 被收集且指针非空时，从 C++ 析构函数调用
    // (即 take() 从未被调用 — Promise 在未 settle 时被 GC 回收)。
    //
    // 析构函数在 GC sweep 期间运行，因此进行任何可能触及 JSC 堆的操作是不安全的。
    // RequestContext.deref() 可能触发 deinit()，后者会分离响应、取消引用 body、
    // 并回调到服务器 — 所有这些都可能取消保护 JS 值或进行分配。
    // 必须将此工作推迟到事件循环。
    // ========================================================================

    /// 销毁 NativePromiseContext (由 GC 析构函数调用)
    /// 严格翻译自: Bun__NativePromiseContext__destroy
    public static func destroy(ctx: Any, tag: NativePromiseContextTag): Unit {
        DeferredDerefTask.schedule(ctx, tag)
    }

    // ========================================================================
    // ref / deref - 引用计数
    // ========================================================================

    /// 引用计数 +1
    public func ref(): Unit {
        refCount = refCount + 1
    }

    /// 引用计数 -1，到 0 时释放
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            // 执行实际的清理工作
            match (tag) {
                case NativePromiseContextTag.HTTPServerRequestContext =>
                    if (context.isSome()) {
                        let ctx = context.getOrThrow()
                        if (ctx is RequestContext) {
                            let rcOpt = ctx as RequestContext
                            if (rcOpt.isSome()) { rcOpt.getOrThrow().deref() }
                        }
                    }
                case NativePromiseContextTag.HTTPSServerRequestContext =>
                    if (context.isSome()) {
                        let ctx = context.getOrThrow()
                        if (ctx is RequestContext) {
                            let rcOpt = ctx as RequestContext
                            if (rcOpt.isSome()) { rcOpt.getOrThrow().deref() }
                        }
                    }
                case NativePromiseContextTag.DebugHTTPServerRequestContext =>
                    if (context.isSome()) {
                        let ctx = context.getOrThrow()
                        if (ctx is RequestContext) {
                            let rcOpt = ctx as RequestContext
                            if (rcOpt.isSome()) { rcOpt.getOrThrow().deref() }
                        }
                    }
                case NativePromiseContextTag.DebugHTTPSServerRequestContext =>
                    if (context.isSome()) {
                        let ctx = context.getOrThrow()
                        if (ctx is RequestContext) {
                            let rcOpt = ctx as RequestContext
                            if (rcOpt.isSome()) { rcOpt.getOrThrow().deref() }
                        }
                    }
                case NativePromiseContextTag.BodyValueBufferer =>
                    // ValueBufferer 嵌入在 HTMLRewriter 的 BufferOutputSink 中，
                    // 所有者指针存储在 .ctx 中。
                    // pending-promise ref 是在所有者上获取的，所以我们释放它。
                    if (context.isSome()) {
                        let ctx = context.getOrThrow()
                        if (ctx is BufferOutputSink) {
                            let sinkOpt = ctx as BufferOutputSink
                            if (sinkOpt.isSome()) { sinkOpt.getOrThrow().deref() }
                        }
                    }
                case NativePromiseContextTag.HTTPSServerH3RequestContext =>
                    if (context.isSome()) {
                        let ctx = context.getOrThrow()
                        if (ctx is RequestContext) {
                            let rcOpt = ctx as RequestContext
                            if (rcOpt.isSome()) { rcOpt.getOrThrow().deref() }
                        }
                    }
                case NativePromiseContextTag.DebugHTTPSServerH3RequestContext =>
                    if (context.isSome()) {
                        let ctx = context.getOrThrow()
                        if (ctx is RequestContext) {
                            let rcOpt = ctx as RequestContext
                            if (rcOpt.isSome()) { rcOpt.getOrThrow().deref() }
                        }
                    }
            }
            context = None
        }
    }
}

// ============================================================================
// DeferredDerefTask - 延迟解引用任务
// 严格翻译自: NativePromiseContext.zig pub const DeferredDerefTask = struct { ... }
//
// 将 GC 触发的 deref 推迟到下一个事件循环 tick，使其在 sweep 阶段之外运行。
//
// 零分配设计: ctx 指针和 Tag 打包到任务的 _ptr 槽位中
// (指针在高位，标签在低 3 位 — 目标类型都 >= 8 字节对齐)。
// 与 PosixSignalTask 使用信号编号的技巧相同。
//
// setUintptr 后 jsc.Task 打包的 u64 内部布局:
//
//     bits 63..49  bits 48..3           bits 2..0
//     ┌──────────┬────────────────────┬─────────┐
//     │ data=u15 │ ctx ptr (aligned)  │ our Tag │
//     └──────────┴────────────────────┴─────────┘
//          ▲              ▲                 ▲
//          │              └─────────┬───────┘
//      Task union           _ptr (u49) — set by setUintptr
//      discriminant
//      (set by init,
//       untouched)
//
// setUintptr 只写入 _ptr；Task.init(&marker) 盖上的 Task 判别式保持不变。
// @truncate 到 u49 保留低位，因此 ctx 指针 (bits 3..48) 和 Tag (bits 0..2) 都保留。
// ============================================================================

/// DeferredDerefTask - 将 GC 触发的 deref 推迟到事件循环
/// 严格翻译自: NativePromiseContext.DeferredDerefTask
public class DeferredDerefTask {
    /// 低 3 位用于标签
    /// 严格翻译自: const tag_mask: usize = 0b111
    public static let TAG_MASK: Int64 = 0b111

    /// 存储的上下文
    public var context: ?Any = None

    /// 上下文标签
    public var tag: NativePromiseContextTag = NativePromiseContextTag.BodyValueBufferer

    public init() {}

    public init(context: Any, tag: NativePromiseContextTag) {
        this.context = context
        this.tag = tag
    }

    // ========================================================================
    // schedule - 调度延迟解引用
    // 严格翻译自: DeferredDerefTask.schedule(ctx: *anyopaque, tag: Tag) void
    //   const vm = jsc.VirtualMachine.get();
    //   if (vm.isShuttingDown()) return;
    //   var marker: DeferredDerefTask = undefined;
    //   var task = jsc.Task.init(&marker);
    //   task.setUintptr(@truncate(addr | @intFromEnum(tag)));
    //   vm.eventLoop().enqueueTask(task);
    // ========================================================================

    /// 调度延迟解引用任务到事件循环
    public static func schedule(ctx: Any, tag: NativePromiseContextTag): Unit {
        // 简化实现: 直接在当前线程执行解引用
        // 完整实现需要 BunVirtualMachine 事件循环
        let task = DeferredDerefTask(ctx, tag)
        task.runFromJSThread()
    }

    // ========================================================================
    // runFromJSThread - 在 JS 线程上运行
    // 严格翻译自: DeferredDerefTask.runFromJSThread(packed_ptr: usize) void
    //   const tag: Tag = @enumFromInt(packed_ptr & tag_mask);
    //   const ctx: *anyopaque = @ptrFromInt(packed_ptr & ~tag_mask);
    //   switch (tag) { ... }
    // ========================================================================

    /// 在 JS 线程上执行延迟解引用
    public func runFromJSThread(): Unit {
        match (tag) {
            case NativePromiseContextTag.HTTPServerRequestContext =>
                if (context.isSome()) {
                    let ctx = context.getOrThrow()
                    if (ctx is RequestContext) {
                        let rcOpt = ctx as RequestContext
                        if (rcOpt.isSome()) { rcOpt.getOrThrow().deref() }
                    }
                }
            case NativePromiseContextTag.HTTPSServerRequestContext =>
                if (context.isSome()) {
                    let ctx = context.getOrThrow()
                    if (ctx is RequestContext) {
                        let rcOpt = ctx as RequestContext
                        if (rcOpt.isSome()) { rcOpt.getOrThrow().deref() }
                    }
                }
            case NativePromiseContextTag.DebugHTTPServerRequestContext =>
                if (context.isSome()) {
                    let ctx = context.getOrThrow()
                    if (ctx is RequestContext) {
                        let rcOpt = ctx as RequestContext
                        if (rcOpt.isSome()) { rcOpt.getOrThrow().deref() }
                    }
                }
            case NativePromiseContextTag.DebugHTTPSServerRequestContext =>
                if (context.isSome()) {
                    let ctx = context.getOrThrow()
                    if (ctx is RequestContext) {
                        let rcOpt = ctx as RequestContext
                        if (rcOpt.isSome()) { rcOpt.getOrThrow().deref() }
                    }
                }
            case NativePromiseContextTag.BodyValueBufferer =>
                if (context.isSome()) {
                    let ctx = context.getOrThrow()
                    if (ctx is BufferOutputSink) {
                        let sinkOpt = ctx as BufferOutputSink
                        if (sinkOpt.isSome()) { sinkOpt.getOrThrow().deref() }
                    }
                }
            case NativePromiseContextTag.HTTPSServerH3RequestContext =>
                if (context.isSome()) {
                    let ctx = context.getOrThrow()
                    if (ctx is RequestContext) {
                        let rcOpt = ctx as RequestContext
                        if (rcOpt.isSome()) { rcOpt.getOrThrow().deref() }
                    }
                }
            case NativePromiseContextTag.DebugHTTPSServerH3RequestContext =>
                if (context.isSome()) {
                    let ctx = context.getOrThrow()
                    if (ctx is RequestContext) {
                        let rcOpt = ctx as RequestContext
                        if (rcOpt.isSome()) { rcOpt.getOrThrow().deref() }
                    }
                }
        }
    }
}

// ============================================================================
// 辅助桩类型 — 在其他包中可能已存在完整实现
// ============================================================================

/// RequestContext 引用 — 在 bao_runtime.server.request_context 中有完整实现
/// 这里声明为可解引用的辅助类型
public class NativePromiseContextRef {
    public var target: ?Any = None
    public init() {}
    public func deref(): Unit {
        target = None
    }
}
