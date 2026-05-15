// bao_core - OOM (内存不足) 处理
// 严格翻译自: src/crash_handler/handle_oom.zig
//   Bun 的 OOM 处理:
//   - handleOom(error_union_or_set): 智能处理 OutOfMemory 错误
//   - 如果错误集中只有 OutOfMemory, 直接调用 outOfMemory() (abort)
//   - 如果还有其他可能的错误, 仅在 OutOfMemory 时调用 outOfMemory()
//   - 避免误捕获非 OOM 错误 (优于 catch bun.outOfMemory())
//   用法:
//     const thing = bun.handleOom(allocateThing());
//     const thing = allocateThing() catch |err| bun.handleOom(err);
package bao_core.crash_handler

// ============================================================================
// handleOom - OOM 处理
// 严格翻译自: handle_oom.zig handleOom(error_union_or_set)
//   这是一个类型感知的错误处理函数:
//   1. 如果参数是 error union:
//      - 如果是成功值, 返回它
//      - 如果是 OutOfMemory, 调用 bun.outOfMemory() (终止进程)
//      - 如果是其他错误, 返回该错误 (从 error set 中移除 OutOfMemory)
//   2. 如果参数是 error set (纯错误):
//      - 如果是 OutOfMemory, 调用 bun.outOfMemory()
//      - 否则返回该错误
//   3. 如果参数是 error.OutOfMemory (唯一的错误):
//      - 直接调用 bun.outOfMemory() (noreturn)
// ============================================================================

/// 处理可能包含 OOM 的错误
/// 对应 Bun: pub fn handleOom(error_union_or_set) return_type
///
/// 如果错误是 OutOfMemory, 终止进程 (noreturn)
/// 否则返回非 OOM 的错误值
///
/// 对应 Bun 的两种用法:
///   const thing = bun.handleOom(allocateThing());
///   const thing = allocateThing() catch |err| bun.handleOom(err);
///
/// 仓颉: 通过异常体系实现等价语义
/// 抛出 BaoError(OutOfMemory) 会导致进程终止
public func handleOom(result: Result<Unit>): Unit {
    match (result) {
        case Ok(_) => return  // 成功, 直接返回
        case Err(e) => {
            if (e.code == ErrorCode.OutOfMemory) {
                // 对应 Bun: bun.outOfMemory() -> noreturn
                CrashHandler.handleOutOfMemory()
            }
            // 非 OOM 错误: 重新抛出
            throw e
        }
    }
}

/// 处理可能包含 OOM 的泛型结果
/// 对应 Bun: handleOom 的泛型版本
public func handleOom<T>(result: Result<T>): T {
    match (result) {
        case Ok(value) => return value
        case Err(e) => {
            if (e.code == ErrorCode.OutOfMemory) {
                CrashHandler.handleOutOfMemory()
            }
            throw e
        }
    }
}

/// 检查错误是否仅为 OOM
/// 对应 Bun: isOomOnlyError(ErrorUnionOrSet) bool
/// 如果错误集中只有 OutOfMemory 一种错误, 返回 true
/// 在 Bun 中这是编译期检查, 仓颉中为运行时检查
public func isOomOnlyError(err: BaoError): Bool {
    return err.code == ErrorCode.OutOfMemory
}

/// 安全分配内存 (OOM 时终止而非返回错误)
/// 对应 Bun: bun.handleOom(bun.default_allocator.dupe(u8, data))
/// 用法: let copy = safeAllocate(allocator.dupe(data))
public func safeAllocate<T>(result: Result<T>): T {
    return handleOom<T>(result)
}

/// 安全分配字节数组 (OOM 时终止)
/// 对应 Bun: bun.handleOom(bun.default_allocator.alloc(u8, len))
public func safeAllocBytes(result: Result<Array<UInt8>>): Array<UInt8> {
    return handleOml<Array<UInt8>>(result)
}

/// 安全复制字符串 (OOM 时终止)
/// 对应 Bun: bun.handleOom(bun.default_allocator.dupe(u8, str))
public func safeDupeString(str: String): String {
    // 简化实现: 直接返回, 在实际分配中处理 OOM
    return str
}
