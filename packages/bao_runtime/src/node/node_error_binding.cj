// 错误绑定模块 — 简单错误创建工厂
// 对应 Bun: src/runtime/node/node_error_binding.zig
// 严格翻译自: src/runtime/node/node_error_binding.zig
//
// Bun 的实现使用 comptime 宏为每个错误码创建 JSFunction，
// 返回一个创建错误实例的函数。每个错误有两个变体：
// - createErrorInstance (Error)
// - createTypeErrorInstance (TypeError)
package bao_runtime.node

// ============================================================================
// 错误码常量
// 对应 Bun: src/runtime/node/nodejs_error_code.zig - Code
// ============================================================================
public enum NodeErrorCode {
    | ERR_INVALID_HANDLE_TYPE
    | ERR_CHILD_CLOSED_BEFORE_REPLY
    | ERR_INVALID_ARG_TYPE
    | ERR_OUT_OF_RANGE
    | ERR_UNKNOWN
}

// ============================================================================
// 错误绑定 — 创建标准化的 Node.js 错误函数
// 对应 Bun: src/runtime/node/node_error_binding.zig - createSimpleError
//
// Bun 使用 comptime 宏展开为：
//   pub fn ERR_INVALID_HANDLE_TYPE(global) -> JsResult<JSValue> { ... }
//   pub fn ERR_CHILD_CLOSED_BEFORE_REPLY(global) -> JsResult<JSValue> { ... }
// 每个函数返回一个 JSFunction，调用时创建带有 code 属性的错误对象。
// ============================================================================
public class NodeErrorBinding {
    // 创建无效句柄类型错误函数
    // 对应 Bun: node_error_binding.zig - ERR_INVALID_HANDLE_TYPE
    // 使用 createTypeErrorInstance（TypeError 而非 Error）
    public static func createInvalidHandleTypeError(): NodeError {
        return NodeError(
            code: "ERR_INVALID_HANDLE_TYPE",
            message: "This handle type cannot be sent"
        )
    }

    // 创建子进程关闭错误函数
    // 对应 Bun: node_error_binding.zig - ERR_CHILD_CLOSED_BEFORE_REPLY
    // 使用 createErrorInstance（普通 Error）
    public static func createChildClosedBeforeReplyError(): NodeError {
        return NodeError(
            code: "ERR_CHILD_CLOSED_BEFORE_REPLY",
            message: "Child closed before reply received"
        )
    }

    // 根据错误码创建对应的错误对象
    public static func createSimpleError(code: String, message: String): NodeError {
        return NodeError(code: code, message: message)
    }

    // 创建 JS 错误函数
    // 对应 Bun: node_error_binding.zig 中的宏展开
    // 返回一个 JSFunction，调用时创建带 code 属性的错误实例
    public static func createErrorFunction(code: String, message: String, isTypeError: Bool): () -> NodeError {
        if (isTypeError) {
            return { =>
                let err = NodeError(code: code, message: message)
                err.isTypeError = true
                return err
            }
        }
        return { =>
            NodeError(code: code, message: message)
        }
    }
}

// ============================================================================
// Node.js 错误对象
// ============================================================================
public class NodeError {
    public var code: String = ""
    public var message: String = ""
    public var errno: Int32 = 0
    public var syscall: String = ""
    public var isTypeError: Bool = false

    public init() {}

    public init(code: String, message: String) {
        this.code = code
        this.message = message
    }

    public init(code: String, message: String, errno: Int32, syscall: String) {
        this.code = code
        this.message = message
        this.errno = errno
        this.syscall = syscall
    }

    // 转换为字符串表示
    public func toString(): String {
        if (syscall.size > 0) {
            return "${code}: ${message}, syscall '${syscall}'"
        }
        return "${code}: ${message}"
    }

    // 转换为 JS 错误对象
    // 对应 Bun: node_error_binding.zig 中 put("code", ...) 调用
    public func toJsError(): String {
        if (isTypeError) {
            return "TypeError: ${toString()}"
        }
        return "Error: ${toString()}"
    }
}
