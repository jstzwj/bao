// 错误绑定模块
// 对应 Bun: src/runtime/node/node_error_binding.zig
// 严格翻译自: src/runtime/node/node_error_binding.zig
package bao_runtime.node

// ============================================================================
// 错误绑定 — 简单错误创建工厂
// 对应 Bun: src/runtime/node/node_error_binding.zig
// ============================================================================
public class NodeErrorBinding {
    // 创建无效句柄类型错误
    // 对应 Bun: src/runtime/node/node_error_binding.zig - ERR_INVALID_HANDLE_TYPE
    public static func createInvalidHandleTypeError(): NodeError {
        return NodeError(
            code: "ERR_INVALID_HANDLE_TYPE",
            message: "This handle type cannot be sent"
        )
    }

    // 创建子进程关闭错误
    // 对应 Bun: src/runtime/node/node_error_binding.zig - ERR_CHILD_CLOSED_BEFORE_REPLY
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
}

// ============================================================================
// Node.js 错误对象
// ============================================================================
public class NodeError {
    public var code: String = ""
    public var message: String = ""
    public var errno: Int32 = 0
    public var syscall: String = ""

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
}
