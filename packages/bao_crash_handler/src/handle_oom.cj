// bao_crash_handler - 内存溢出处理
// 严格翻译自: bun/src/crash_handler/handle_oom.zig
//   处理 OutOfMemory 错误: 如果是唯一的错误则直接触发 OOM
//   如果有其他错误则过滤掉 OOM 重新抛出
package bao_crash_handler

import bao_core.*

// ============================================================================
// HandleOom - 内存溢出处理器
// 严格翻译自: bun/src/crash_handler/handle_oom.zig
//   pub fn handleOom(error_union_or_set: anytype) return_type: { ... }
//
//   如果 error_union_or_set 是 error.OutOfMemory，调用 bun.outOfMemory()。
//   如果那是唯一可能的错误，返回非错误的 payload (error union) 或 noreturn (error set)。
//   如果可能有其他错误，返回相同的 error union 或 set，但不包含 OutOfMemory。
//
//   两种用法:
//     1. const thing = bun.handleOom(allocateThing());
//     2. const thing = allocateThing() catch |err| bun.handleOom(err);
//
//   注意: Zig 的 comptime 类型系统检查在仓颉中无法完全复制
//   使用运行时 Result 类型实现等价语义
// ============================================================================

/// 内存溢出处理器 - 对应 Bun bun.handleOom
/// 处理可能包含 OutOfMemory 错误的 Result
///
/// 对应 Zig 代码:
///   pub fn handleOom(error_union_or_set: anytype) return_type: {
///       const ArgType = @TypeOf(error_union_or_set);
///       const arg_info = @typeInfo(ArgType);
///       break :return_type if (isOomOnlyError(ArgType)) switch (arg_info) {
///           .error_union => |union_info| union_info.payload,
///           .error_set => noreturn,
///           else => unreachable,
///       } else @TypeOf(blk: { ... });
///   }
///
/// 如果 Result 是 OutOfMemory，调用 outOfMemory() 终止进程
/// 如果有其他错误，返回该错误
/// 如果成功，返回成功值
public class HandleOom {
    /// 处理 Result<T>，如果是 OutOfMemory 则终止
    /// 对应: const thing = bun.handleOom(allocateThing());
    ///
    /// 用法 1: 直接传递 Result
    /// 对应 Zig: const thing = bun.handleOom(allocateThing());
    public static func handle<T>(result: Result<T, Exception>): T {
        match (result) {
            case Ok(value) => value
            case Err(err) =>
                if (err is BaoError) {
                    let baoErr = (err as BaoError).getOrThrow()
                    if (baoErr.code.toU16() == ErrorCode.OutOfMemory.toU16()) {
                        outOfMemory()
                    }
                }
                throw err
        }
    }

    /// 处理错误码 - 如果是 OutOfMemory 则终止，否则抛出
    /// 对应: const thing = allocateThing() catch |err| bun.handleOom(err);
    ///
    /// 用法 2: 在 catch 中传递错误
    /// 对应 Zig: const thing = allocateThing() catch |err| bun.handleOom(err);
    public static func handleError(err: Exception): Nothing {
        if (err is BaoError) {
            let baoErr = (err as BaoError).getOrThrow()
            if (baoErr.code.toU16() == ErrorCode.OutOfMemory.toU16()) {
                outOfMemory()
            }
        }
        throw err
    }

    /// 检查错误是否仅为 OutOfMemory
    /// 对应: fn isOomOnlyError(comptime ErrorUnionOrSet: type) bool
    ///
    /// 在 Zig 中这是一个编译时函数，遍历错误集的所有错误
    /// 在仓颉中简化为运行时检查
    public static func isOomOnlyError(err: Exception): Bool {
        if (err is BaoError) {
            let baoErr = (err as BaoError).getOrThrow()
            baoErr.code.toU16() == ErrorCode.OutOfMemory.toU16()
        } else {
            false
        }
    }
}

/// 触发内存溢出终止
/// 对应: bun.outOfMemory()
/// 在 Bun 中这会触发一个特殊的 OOM panic
public func outOfMemory(): Nothing {
    // 对应 Bun 的 bun.outOfMemory() 行为
    // 打印 OOM 消息并终止
    println("Bao has run out of memory.")
    exit(1)
}
