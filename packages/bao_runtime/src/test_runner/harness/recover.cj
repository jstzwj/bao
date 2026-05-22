// recover.cj - 测试恢复工具
// 严格翻译自 bun/src/runtime/test_runner/harness/recover.zig
// Panic recover - 从panic中恢复并继续执行测试

package bao_runtime.test_runner.harness

import bao_jsc.*
import bao_core.*

// ========== Recover - 测试恢复 ==========

/// 恢复上下文 - 保存执行状态
public class RecoverContext {
    public var hasRecovered: Bool = false
    public var errorMessage: ?String = None

    public init() {}
}

/// 测试恢复工具，用于从错误中恢复并继续执行测试
public class Recover {
    /// 从错误中恢复
    /// - Param globalThis: 全局对象
    /// - Param error: 错误值
    /// - Return: 是否成功恢复
    public static func recover(globalThis: JsObject, error: JsValue): Bool {
        let ctx = RecoverContext()
        ctx.hasRecovered = true

        // 提取错误消息
        let errOpt = error.toError()
        if (errOpt.isSome()) {
            let err = errOpt.getOrThrow()
            let nameOpt = err.getTruthy(globalThis, "name")
            let name: JsValue = if (nameOpt.isSome()) { nameOpt.getOrThrow() } else { JsValue.jsUndefined() }
            let messageOpt = err.getTruthy(globalThis, "message")
            let message: JsValue = if (messageOpt.isSome()) { messageOpt.getOrThrow() } else { JsValue.jsUndefined() }
            let nameStrOpt = name.toSliceOrNull(globalThis)
            let nameStr = if (nameStrOpt.isSome()) { nameStrOpt.getOrThrow() } else { "" }
            let messageStrOpt = message.toSliceOrNull(globalThis)
            let messageStr = if (messageStrOpt.isSome()) { messageStrOpt.getOrThrow() } else { "" }
            ctx.errorMessage = "${nameStr}: ${messageStr}"
        } else {
            let msgOpt = error.toSliceOrNull(globalThis)
            ctx.errorMessage = if (msgOpt.isSome()) { msgOpt.getOrThrow() } else { "unknown error" }
        }

        return ctx.hasRecovered
    }

    /// 包装测试函数执行, 捕获panic并恢复
    /// - Param testFunc: 测试函数
    /// - Return: 测试结果
    public static func callForTest(testFunc: () -> Unit): ?String {
        try {
            testFunc()
            return None
        } catch (e: Exception) {
            return e.message
        }
    }

    /// 包装函数执行, 捕获panic并恢复
    /// - Param func: 被包装的函数
    /// - Param args: 函数参数
    /// - Return: 函数返回值或错误
    public static func call<T>(`func`: () -> T): Option<T> {
        try {
            return Some(`func`())
        } catch (e: Exception) {
            return None
        }
    }
}
