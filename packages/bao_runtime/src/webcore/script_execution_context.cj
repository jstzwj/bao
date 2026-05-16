// ScriptExecutionContext - 脚本执行上下文
// 严格翻译自: src/runtime/webcore/ScriptExecutionContext.rs
//   Bun 的 ScriptExecutionContext 模块:
//   - Identifier: 安全的 JavaScript 执行环境句柄 (定义在 bun_jsc 中, 此处 re-export)
//   - IdentifierExt: 运行时便捷扩展 (bun_vm_ref, valid)
//   仓颉: 提供兼容的脚本执行上下文接口
package bao_runtime.webcore

import bao_core.*
import bao_jsc.*

// ============================================================================
// ScriptExecutionContextIdentifier - 脚本执行上下文标识符
// 严格翻译自: src/runtime/webcore/ScriptExecutionContext.rs
//   LAYERING: the `Identifier` newtype + `global_object()`/`bun_vm()` accessors
//   were moved DOWN into `bun_jsc` so that `JSGlobalObject::script_execution_context_identifier`
//   can return the concrete type without `bun_jsc -> bun_runtime` (a cycle).
//   Re-exported here so `webcore::script_execution_context::Identifier` keeps resolving.
// ============================================================================

/// 脚本执行上下文标识符
/// 安全的 JavaScript 执行环境句柄, 可能已退出
/// 对应 Bun: pub use bun_jsc::js_global_object::ScriptExecutionContextIdentifier as Identifier
///
/// Identifier 是一个 newtype, 包装一个指针/ID, 指向 JSGlobalObject 所在的 VM。
/// 当 VM 退出时, global_object() 返回 None。
public class ScriptExecutionContextIdentifier {
    /// 标识符值
    /// 对应 Bun: 内部的 JSGlobalObject 指针或索引
    public var id: Int64

    public init(id: Int64) {
        this.id = id
    }

    /// 获取全局对象
    /// 对应 Bun: Identifier.globalObject() -> ?*JSGlobalObject
    ///   返回 Some 仅当上下文仍存活
    public func globalObject(): ?JSGlobalObject {
        // 简化: 需要运行时 VM 注册表支持
        return None
    }

    /// 获取 Bun VM 指针
    /// 对应 Bun: Identifier.bunVM() -> ?*VirtualMachine
    ///   定义在 bun_jsc 中
    public func bunVM(): ?VirtualMachine {
        let global = globalObject()
        match (global) {
            case Some(g) => return g.bunVM()
            case None => return None
        }
    }

    /// 是否有效 (上下文是否仍存活)
    /// 对应 Bun: Identifier.valid() -> bool
    ///   global_object().is_some()
    public func valid(): Bool {
        return globalObject() != None
    }
}

// ============================================================================
// IdentifierExt - 运行时便捷扩展
// 严格翻译自: ScriptExecutionContext.rs 中的 IdentifierExt trait
//   pub trait IdentifierExt {
//       fn bun_vm_ref(self) -> Option<&'static VirtualMachine>;
//       fn valid(self) -> bool;
//   }
// ============================================================================

/// Identifier 扩展方法
/// 对应 Bun: pub trait IdentifierExt
///
/// Runtime-tier convenience: typed `&VirtualMachine` view of Identifier::bun_vm
/// (the bun_jsc method returns `*mut VirtualMachine` to avoid lifetime claims).
public class IdentifierExt {
    /// 获取 VM 的类型化引用
    /// 对应 Bun: fn bun_vm_ref(self) -> Option<&'static VirtualMachine>
    ///   SAFETY: the VM outlives all ScriptExecutionContexts it owns; pointer is
    ///   non-null when global_object() is Some.
    public static func bunVMRef(identifier: ScriptExecutionContextIdentifier): ?VirtualMachine {
        let vmPtr = identifier.bunVM()
        match (vmPtr) {
            case Some(vm) => return vm  // VM outlives all contexts
            case None => return None
        }
    }

    /// 检查标识符是否有效
    /// 对应 Bun: fn valid(self) -> bool
    ///   self.global_object().is_some()
    public static func valid(identifier: ScriptExecutionContextIdentifier): Bool {
        return identifier.valid()
    }
}
