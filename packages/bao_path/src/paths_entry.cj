// 严格翻译自: src/paths/paths.zig
//   Bun paths 模块入口文件
//   pub const Path = paths.Path;
//   pub const AbsPath = paths.AbsPath;
//   pub const AutoAbsPath = paths.AutoAbsPath;
//   pub const RelPath = paths.RelPath;
//   pub const AutoRelPath = paths.AutoRelPath;
//   pub const EnvPath = @import("./EnvPath.zig").EnvPath;
//   pub const path_buffer_pool = pools.path_buffer_pool;
//   pub const MAX_PATH_BYTES: usize = ...
//   pub const PathBuffer = [MAX_PATH_BYTES]u8;
//   pub const PATH_MAX_WIDE = ...
//   pub const WPathBuffer = [PATH_MAX_WIDE]u16;
//   pub const OSPathChar = if (Environment.isWindows) u16 else u8;
//   pub const OSPathSliceZ = [:0]const OSPathChar;
//   pub const OSPathSlice = []const OSPathChar;
//   pub const OSPathBuffer = if (Environment.isWindows) WPathBuffer else PathBuffer;
//
// 本文件提供 paths 模块的类型别名和入口
package bao_path

import bao_core.*

// ============================================================================
// 路径类型别名
// 严格翻译自: src/paths/paths.zig
//   pub const Path = paths.Path;
//   pub const AbsPath = paths.AbsPath;
//   pub const AutoAbsPath = paths.AutoAbsPath;
//   pub const RelPath = paths.RelPath;
//   pub const AutoRelPath = paths.AutoRelPath;
// ============================================================================

/// 路径类型别名 - 对应 Bun paths.Path
/// Bun: Path 是 Path(opts) 的编译时特化，此处使用 PathImpl
public type AbsPath = PathImpl
public type AutoAbsPath = PathImpl
public type RelPath = PathImpl
public type AutoRelPath = PathImpl

// ============================================================================
// OS 路径类型
// 严格翻译自: src/paths/paths.zig
//   pub const OSPathChar = if (Environment.isWindows) u16 else u8;
//   pub const OSPathSliceZ = [:0]const OSPathChar;
//   pub const OSPathSlice = []const OSPathChar;
//   pub const OSPathBuffer = if (Environment.isWindows) WPathBuffer else PathBuffer;
// ============================================================================

/// OS 路径字符类型 - 对应 Bun OSPathChar
/// POSIX: UInt8, Windows: UInt16
/// 仓颉目标平台为 POSIX，使用 UInt8
public type OSPathChar = UInt8

/// OS 路径缓冲区类型 - 对应 Bun OSPathBuffer
/// POSIX: PathBuffer, Windows: WPathBuffer
/// 仓颉目标平台为 POSIX，使用 PathBuffer
public type OSPathBuffer = PathBuffer

// ============================================================================
// 路径缓冲区池类型别名
// 严格翻译自: src/paths/paths.zig
//   pub const path_buffer_pool = pools.path_buffer_pool;
//   pub const w_path_buffer_pool = pools.w_path_buffer_pool;
//   pub const os_path_buffer_pool = pools.os_path_buffer_pool;
// ============================================================================

/// 路径缓冲区池 - 对应 Bun path_buffer_pool
public type OSPathBufferPool = PathBufferPoolT
