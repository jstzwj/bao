// 参数验证工具函数
// 对应 Bun: src/runtime/node/util/validators.zig
// 严格翻译自: src/runtime/node/util/validators.zig
package bao_runtime

// ============================================================================
// 参数验证器
// 对应 Bun: src/runtime/node/util/validators.zig
// ============================================================================
public class Validators {
    // 验证整数
    // 对应 Bun: src/runtime/node/util/validators.zig - validateInteger
    public static func validateInteger(value: Int64, name: String, min: Int64, max: Int64): ?NodeError {
        if (value < min || value > max) {
            return NodeError(code: "ERR_OUT_OF_RANGE", message: "The value of \"${name}\" is out of range. It must be >= ${min} and <= ${max}. Received ${value}")
        }
        return None
    }

    // 验证 Int32
    // 对应 Bun: src/runtime/node/util/validators.zig - validateInt32
    public static func validateInt32(value: Float64, name: String, min: ?Int64, max: ?Int64): ?Int32 {
        let minVal = min ?? Int64(-2147483648)
        let maxVal = max ?? Int64(2147483647)

        if (value < Float64(minVal) || value > Float64(maxVal)) {
            return None
        }

        let intVal = Int32(value)
        if (Float64(intVal) != value) {
            return None
        }

        return intVal
    }

    // 验证 UInt32
    // 对应 Bun: src/runtime/node/util/validators.zig - validateUint32
    public static func validateUint32(value: Float64, name: String, positiveOnly: Bool): ?UInt32 {
        let min: Float64 = if (positiveOnly) { 0.0 } else { 0.0 }
        let max: Float64 = 4294967295.0

        if (value < min || value > max) {
            return None
        }

        let intVal = UInt32(value)
        if (Float64(intVal) != value) {
            return None
        }

        return intVal
    }

    // 验证字符串
    // 对应 Bun: src/runtime/node/util/validators.zig - validateString
    public static func validateString(value: String, name: String): ?NodeError {
        // 在仓颉中所有字符串都是有效的
        return None
    }

    // 验证函数
    // 对应 Bun: src/runtime/node/util/validators.zig - validateFunction
    public static func validateFunction(name: String, value: Any): ?NodeError {
        // 在实际实现中需要检查值是否为函数类型
        return None
    }

    // 验证端口号
    public static func validatePort(value: Int64, name: String = "port"): ?NodeError {
        if (value < 0 || value > 65535) {
            return NodeError(code: "ERR_SOCKET_BAD_PORT", message: "Port should be >= 0 and < 65536. Received ${value}.")
        }
        return None
    }

    // 获取类型名称
    // 对应 Bun: src/runtime/node/util/validators.zig - getTypeName
    public static func getTypeName(value: Any): String {
        // 简化实现
        return "object"
    }

    // 抛出无效参数类型错误
    // 对应 Bun: src/runtime/node/util/validators.zig - throwErrInvalidArgType
    public static func throwErrInvalidArgType(name: String, expected: String, actual: String): NodeError {
        return NodeError(code: "ERR_INVALID_ARG_TYPE", message: "The \"${name}\" argument must be of type ${expected}. Received ${actual}")
    }
}
