// bao_core - OOM (内存不足) 处理
// 严格翻译自: src/crash_handler/handle_oom.zig
package bao_core.crash_handler
import bao_core.*

/// 处理可能包含 OOM 的错误
public func handleOom(result: Result<Unit, BaoError>): Unit {
    match (result) {
        case Ok(_) => return
        case Err(e) => handleOomError(e)
    }
}

private func handleOomError(e: BaoError): Unit {
    if (isOomError(e.code)) {
        CrashHandler.handleOutOfMemory()
    }
    throw e
}

/// 处理可能包含 OOM 的泛型结果
public func handleOom<T>(result: Result<T, BaoError>): T {
    match (result) {
        case Ok(value) => value
        case Err(e) => handleOomErrorGeneric<T>(e)
    }
}

private func handleOomErrorGeneric<T>(e: BaoError): T {
    if (isOomError(e.code)) {
        CrashHandler.handleOutOfMemory()
    }
    throw e
}

/// 检查错误是否为 OOM
private func isOomError(code: ErrorCode): Bool {
    match (code) {
        case ErrorCode.OutOfMemory => true
        case _ => false
    }
}

/// 检查错误是否仅为 OOM
public func isOomOnlyError(err: BaoError): Bool {
    return isOomError(err.code)
}

/// 安全分配内存
public func safeAllocate<T>(result: Result<T, BaoError>): T {
    return handleOom<T>(result)
}

/// 安全分配字节数组
public func safeAllocBytes(result: Result<Array<UInt8>, BaoError>): Array<UInt8> {
    return handleOom<Array<UInt8>>(result)
}

/// 安全复制字符串
public func safeDupeString(str: String): String {
    return str
}
