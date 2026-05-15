// ScriptExecutionContext - 脚本执行上下文
// 对应 Bun: src/runtime/webcore/ScriptExecutionContext.zig
// 严格翻译自: src/runtime/webcore/ScriptExecutionContext.zig
package bao_runtime.webcore

// ============================================================================
// ScriptExecutionContextIdentifier - 脚本执行上下文标识符
// 对应 Bun: ScriptExecutionContext.Identifier
// ============================================================================

/// 脚本执行上下文标识符
/// 安全的 JavaScript 执行环境句柄，可能已退出
/// 对应 Bun: ScriptExecutionContext.Identifier
public class ScriptExecutionContextIdentifier {
    /// 标识符值
    public var id: Int64

    public init(id: Int64) {
        this.id = id
    }

    /// 获取全局对象
    /// 对应 Bun: Identifier.globalObject()
    public func globalObject(): ?VirtualMachine {
        // 如果上下文仍存在则返回 VM
        return None  // 简化: 需要运行时支持
    }

    /// 获取 Bun VM
    /// 对应 Bun: Identifier.bunVM()
    public func bunVM(): ?VirtualMachine {
        return globalObject()
    }

    /// 是否有效
    /// 对应 Bun: Identifier.valid()
    public func valid(): Bool {
        return globalObject() != None
    }
}
