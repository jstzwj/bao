// 严格翻译自: src/runtime/api/NativePromiseContext.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*

// ============================================================================
// NativePromiseContext - 用于 Promise .then() 链的原生上下文
// 对应 Bun: src/runtime/api/NativePromiseContext.zig
// ============================================================================

/// NativePromiseContext - GC 管理的原生上下文包装器
///
/// 当原生代码 .then() 一个用户 Promise 并需要上下文指针时,
/// 使用此 GC 管理的单元格包装指针, 而不是传递原始指针。
/// 如果 Promise 从未解决, GC 会回收单元格, 析构函数会释放引用。
public class NativePromiseContext {

    // ========================================================================
    // Tag - 上下文类型标签
    // ========================================================================

    /// Tag - 每个具体原生类型对应一个标签
    /// 通过 CompactPointerTuple 打包到指针的高位
    public enum Tag: UInt8 {
        case httpServerRequestContext
        case httpsServerRequestContext
        case debugHttpServerRequestContext
        case debugHttpsServerRequestContext
        case bodyValueBufferer
        case httpsServerH3RequestContext
        case debugHttpsServerH3RequestContext

        /// 从类型推断标签
        public static func fromType<T>(type: T.Type): Tag {
            match (type) {
                case HTTPServerRequestContext => .httpServerRequestContext
                case HTTPSServerRequestContext => .httpsServerRequestContext
                case DebugHTTPServerRequestContext => .debugHttpServerRequestContext
                case DebugHTTPSServerRequestContext => .debugHttpsServerRequestContext
                case H3RequestContext => .httpsServerH3RequestContext
                case DebugH3RequestContext => .debugHttpsServerH3RequestContext
                case ValueBufferer => .bodyValueBufferer
                default => throw CompileError("NativePromiseContext.Tag: unsupported type")
            }
        }
    }

    // ========================================================================
    // 外部函数
    // ========================================================================

    /// 创建 NativePromiseContext (C++ 实现)
    public static func create(global: JsGlobalObject, ctx: Any, tag: UInt8): JsValue {
        return Bun__NativePromiseContext__create(global, ctx, tag)
    }

    /// 外部声明: C++ 创建函数
    @Extern
    public static func Bun__NativePromiseContext__create(global: JsGlobalObject, ctx: Any, tag: UInt8): JsValue

    /// take - 转移引用回调用者, 置空单元格
    /// 返回 null 如果已经被取走
    public static func take<T>(cell: JsValue): ?T {
        let ptr = Bun__NativePromiseContext__take(cell)
        if (ptr == null) { return none }
        return unsafeBitCast(ptr, T)
    }

    /// 外部声明: C++ take 函数
    @Extern
    public static func Bun__NativePromiseContext__take(value: JsValue): ?Any

    // ========================================================================
    // DeferredDerefTask - 延迟释放任务
    // ========================================================================

    /// DeferredDerefTask - 将 GC 触发的 deref 延迟到下一个事件循环 tick
    /// 零分配: ctx 指针和 Tag 打包到任务的 _ptr 插槽中
    public class DeferredDerefTask {
        public static let tagMask: UInt64 = 0b111

        /// 调度延迟释放
        public static func schedule(ctx: Any, tag: Tag): Unit {
            let vm = VirtualMachine.get()
            if (vm.isShuttingDown()) { return }

            let addr = Int.fromPtr(ctx)
            var task = JsTask.init()
            task.setUintptr(UInt64(addr) | UInt64(tag.rawValue))
            vm.eventLoop().enqueueTask(task)
        }

        /// 从 JS 线程运行
        public static func runFromJSThread(packedPtr: UInt64): Unit {
            let tag: Tag = Tag(rawValue: UInt8(packedPtr & tagMask))
            let ctx: Any = UnsafeMutableRawPointer(bitPattern: UInt(packedPtr & ~tagMask))

            match (tag) {
                case .httpServerRequestContext =>
                    (ctx as! HTTPServerRequestContext).deref()
                case .httpsServerRequestContext =>
                    (ctx as! HTTPSServerRequestContext).deref()
                case .debugHttpServerRequestContext =>
                    (ctx as! DebugHTTPServerRequestContext).deref()
                case .debugHttpsServerRequestContext =>
                    (ctx as! DebugHTTPSServerRequestContext).deref()
                case .bodyValueBufferer =>
                    let bufferer = ctx as! ValueBufferer
                    (bufferer.ctx as! HTMLRewriterBufferOutputSink).deref()
                case .httpsServerH3RequestContext =>
                    (ctx as! H3RequestContext).deref()
                case .debugHttpsServerH3RequestContext =>
                    (ctx as! DebugH3RequestContext).deref()
            }
        }
    }
}
