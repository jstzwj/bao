// 翻译自: src/runtime/api/bun/spawn.zig
//   BunSpawn — Bun 自定义 spawn 实现 (posix_spawn_bun 后端)
//   PosixSpawn — posix_spawn 系统调用包装器
package bao_runtime.api

import bao_collections.ArrayList
import bao_jsc.{JsGlobalObject, JsValue}
import bao_sys.*

// ============================================================================
// BunSpawn — Bun 自定义 spawn 实现
// 翻译自: src/runtime/api/bun/spawn.zig:1-126
//   pub const BunSpawn = struct { ... }
// ============================================================================

/// BunSpawn — Bun 自定义 spawn 实现
/// 翻译自: src/runtime/api/bun/spawn.zig:1-126
///   包含 Action, Actions, Attr 子类型用于 posix_spawn_bun
public class BunSpawn {
    // Action 类型已在 posix_spawn.cj (bao_spawn_sys) 中定义为 SpawnAction
    // Actions 类型已在 posix_spawn.cj 中定义为 Actions
    // Attr 类型已在 posix_spawn.cj 中定义为 Attr
    public init() {}
}

// ============================================================================
// PosixSpawn — posix_spawn 包装器
// 翻译自: src/runtime/api/bun/spawn.zig:128-566
//   pub const PosixSpawn = struct { ... }
// ============================================================================

/// PosixSpawn — posix_spawn 包装器
/// 翻译自: src/runtime/api/bun/spawn.zig:128-566
///   包含 WaitPidResult, spawnZ, waitpid, wait4 等
public class PosixSpawn {
    // Process/SpawnOptions/Status/sync 等已在 process.cj 中定义
    // Stdio 已在 stdio.cj 中定义

    /// waitpid — 等待子进程
    /// 翻译自: src/runtime/api/bun/spawn.zig:500-517
    ///   pub fn waitpid(pid: pid_t, flags: u32) -> Maybe(WaitPidResult)
    public static func waitpid(pid: PidT, flags: UInt32): SysMaybe<WaitPidResult> {
        var done = false
        while (!done) {
            let rc = unsafe { posixWaitpid(pid, Int32(flags)) }
            if (rc == -1) {
                let err = Int64(OS.errno())
                if (err == 4) {  // EINTR
                    // continue
                } else {
                    return SysMaybe<WaitPidResult>.Err(SysError(UInt16(err), SysTag.Waitpid))
                }
            } else {
                return SysMaybe<WaitPidResult>.Ok(WaitPidResult())
            }
        }
        return SysMaybe<WaitPidResult>.Err(SysError(UInt16(0), SysTag.Waitpid))
    }

    /// wait4 — waitpid + rusage
    /// 翻译自: src/runtime/api/bun/spawn.zig:520-537
    ///   pub fn wait4(pid: pid_t, flags: u32, usage: ?*process.Rusage) -> Maybe(WaitPidResult)
    public static func wait4(pid: PidT, flags: UInt32, usage: ?Rusage): SysMaybe<WaitPidResult> {
        // 使用 waitpid 实现 (不获取 rusage)
        return waitpid(pid, flags)
    }
}

// ============================================================================
// FFI 声明
// ============================================================================

/// waitpid FFI
@C
foreign func posixWaitpid(pid: Int32, options: Int32): Int32
