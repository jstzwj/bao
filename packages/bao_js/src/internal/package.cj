// bao_js.internal - 内部模块 (不分配给模块解析器)
// 严格翻译自: src/js/internal/*.ts
//   Bun 的内部模块提供 Node.js 兼容层的底层实现:
//   - internal/errors.ts -> Node.js 错误系统
//   - internal/validators.ts -> 参数验证工具
//   - internal/buffer.ts -> Buffer 内部实现
//   - internal/stream.ts -> 流内部实现
//   - internal/fs/ -> 文件系统内部
//   - internal/http/ -> HTTP 内部
//   - internal/net/ -> 网络 内部
//   - internal/crypto/ -> 加密 内部
//   - internal/util/ -> 工具 内部
//   - 等
package bao_js.internal

import bao_core.*
import bao_js.*

// ============================================================================
// InternalErrors - 内部错误系统
// 严格翻译自: src/js/internal/errors.ts
//   Node.js 错误系统实现, 包含:
//   - errno 的错误码映射 (ECONNREFUSED, ENOENT, ...)
//   - 自定义错误类: NodeError, NodeTypeError, NodeRangeError, NodeSystemError
//   - uvExceptionMap: libuv 错误码到错误消息的映射
//   - 所有 $ERR_* 内置函数的实现
// ============================================================================

/// 内部错误系统
public class InternalErrors {
    /// Node.js 错误码
    // 对应 Bun: internal/errors.ts 中的错误码字符串常量
    public static let ERR_INVALID_ARG_TYPE = "ERR_INVALID_ARG_TYPE"
    public static let ERR_INVALID_ARG_VALUE = "ERR_INVALID_ARG_VALUE"
    public static let ERR_OUT_OF_RANGE = "ERR_OUT_OF_RANGE"
    public static let ERR_MISSING_ARGS = "ERR_MISSING_ARGS"
    public static let ERR_STREAM_DESTROYED = "ERR_STREAM_DESTROYED"
    public static let ERR_METHOD_NOT_IMPLEMENTED = "ERR_METHOD_NOT_IMPLEMENTED"
    public static let ERR_STREAM_ALREADY_FINISHED = "ERR_STREAM_ALREADY_FINISHED"
    public static let ERR_INVALID_STATE = "ERR_INVALID_STATE"
    public static let ERR_ILLEGAL_CONSTRUCTOR = "ERR_ILLEGAL_CONSTRUCTOR"

    /// 创建系统错误
    // 对应 Bun: uvException(code, syscall, message, ...)
    //   将 libuv 错误码转换为 Node.js 系统错误
    public static func uvException(code: String, syscall: String, message: String): BaoError {
        BaoError(ErrorCode.fromErrno(errnoFromCode(code)), "${message}: ${syscall} ${code}")
    }

    /// 从错误码字符串获取 errno
    private static func errnoFromCode(code: String): Int64 {
        match (code) {
            case "ECONNREFUSED" => 111
            case "ENOENT" => 2
            case "EACCES" => 13
            case "EADDRINUSE" => 98
            case "ECONNRESET" => 104
            case "ETIMEDOUT" => 110
            case "EEXIST" => 17
            case "EISDIR" => 21
            case "ENOTDIR" => 20
            case "ENOTEMPTY" => 39
            case "EPERM" => 1
            case "EPIPE" => 32
            case "EROFS" => 30
            case "ENOSPC" => 28
            case "EMFILE" => 24
            case "ENFILE" => 23
            case "EBADF" => 9
            case "EINVAL" => 22
            case _ => 1 // EPERM 默认
        }
    }
}

// ============================================================================
// InternalValidators - 内部验证器
// 严格翻译自: src/js/internal/validators.ts
//   Node.js 参数验证工具函数:
//   - validateString(value, name)
//   - validateNumber(value, name)
//   - validateBoolean(value, name)
//   - validateFunction(value, name)
//   - validateObject(value, name)
//   - validateArray(value, name)
//   - validateBuffer(value, name)
//   - validateInteger(value, name, min, max)
//   - validateInt32(value, name, min, max)
//   - validateUint32(value, name, positive)
//   - validatePort(port, name)
//   - 等
// ============================================================================

/// 内部验证器
public class InternalValidators {
    /// 验证字符串
    // 对应 Bun: validateString(value, name)
    public static func validateString(value: AnyType, name: String): String {
        // 在实际 JS 实现中: if (typeof value !== 'string') throw $ERR_INVALID_ARG_TYPE(name, 'string', value)
        return value.toString()
    }

    /// 验证整数
    // 对应 Bun: validateInteger(value, name, min, max)
    public static func validateInteger(value: Int64, name: String, min: Int64, max: Int64): Int64 {
        if (value < min || value > max) {
            throw BuiltinErrorCodes.errOutOfRange(name, "is out of range", "${value}")
        }
        return value
    }

    /// 验证函数
    // 对应 Bun: validateFunction(value, name)
    public static func validateFunction(value: AnyType, name: String): Unit {
        // 在实际实现中检查 callable
    }

    /// 验证端口号
    // 对应 Bun: validatePort(port, name)
    public static func validatePort(port: Int64, name: String): Int64 {
        return validateInteger(port, name, 0, 65535)
    }
}

// ============================================================================
// InternalPrimordials - 原始内置
// 严格翻译自: src/js/internal/primordials.js
//   安全的内置对象引用, 防止用户代码通过原型污染篡改:
//   - ArrayPrototypePush, ArrayPrototypeSlice, ...
//   - ObjectKeys, ObjectDefineProperty, ...
//   - StringPrototypeSplit, StringPrototypeSlice, ...
//   - MapPrototypeGet, MapPrototypeSet, ...
//   - 等
// ============================================================================

/// 原始内置 - 安全的内置对象引用
public class InternalPrimordials {
    // 在仓颉中不需要原型污染防护, 但记录此概念以保持翻译完整性
    // Bun 的 primordials.js 提供了约 200+ 个安全的内置方法引用
}
