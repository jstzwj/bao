// JSC 执行引擎 — JscRuntime 数据持有类
// 仅持有 JSC 上下文指针（CPointer<Unit>），不声明任何 @C foreign func。
// 所有 FFI 调用在 bao_cli/src_min/package.cj 中完成。
package bao_jsc

/// JSC 运行时 — 持有 JSGlobalContextRef 指针
/// ctx 是 CPointer<Unit>（对应 C 的 void*）
public class JscRuntime {
    private var ctx: CPointer<Unit>
    private var initialized: Bool

    public init(externalCtx: CPointer<Unit>) {
        ctx = externalCtx
        initialized = !ctx.isNull()
    }

    public func deinit(): Unit {
        initialized = false
        ctx = CPointer<Unit>()
    }

    public func isAvailable(): Bool {
        initialized && !ctx.isNull()
    }

    public func getCtx(): CPointer<Unit> {
        ctx
    }

    public func getContext(): CPointer<Unit> {
        ctx
    }
}
