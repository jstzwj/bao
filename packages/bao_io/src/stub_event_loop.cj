// bao_io - 桩事件循环 (Stub Event Loop)
// 严格翻译自: src/io/stub_event_loop.zig
//   Bun 使用此文件作为无事件循环平台的桩实现
//   定义了 Loop, KeepAlive, FilePoll 的空类型
//   仓颉实现提供等价的桩实现
package bao_io

// ============================================================================
// Stub Event Loop - 桩实现
// 严格翻译自: src/io/stub_event_loop.zig
//   pub const Loop = opaque {}
//   pub const KeepAlive = opaque {}
//   pub const FilePoll = opaque {}
//   在不支持事件循环的平台上使用这些空类型
// ============================================================================

/// 桩事件循环 - 不支持事件循环的平台的空实现
/// 翻译自: pub const Loop = opaque {}
public class StubLoop {}

/// 桩 KeepAlive - 空实现
/// 翻译自: pub const KeepAlive = opaque {}
public class StubKeepAlive {}

/// 桩 FilePoll - 空实现
/// 翻译自: pub const FilePoll = opaque {}
public class StubFilePoll {}
