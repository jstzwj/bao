// 翻译自 Bun: src/runtime/bake/debug.ts
// 调试断言工具

package bao_runtime.bake

/// DEBUG 工具对象
/// 对应 Bun: debug.ts — 在开发模式下提供断言功能
public class Debug {
    /// 断言条件为真，否则打印错误消息
    /// 对应 Bun: DEBUG.ASSERT(condition, message?)
    public static func ASSERT(condition: Bool, message: String = ""): Unit {
        if (!condition) {
            let msg: String = if (message.isEmpty()) {
                "ASSERTION FAILED"
            } else {
                "ASSERTION FAILED: ${message}"
            }
            Output.errGeneric(msg)
        }
    }

    /// 断言条件为真，否则触发 panic
    public static func ASSERT_STRICT(condition: Bool, message: String = ""): Unit {
        if (!condition) {
            let msg: String = if (message.isEmpty()) {
                "ASSERTION FAILED"
            } else {
                "ASSERTION FAILED: ${message}"
            }
            panic(msg)
        }
    }
}

/// 是否为开发模式
public let IS_BUN_DEVELOPMENT: Bool = true // 默认为开发模式
