// bao_safety - 安全检查与断言工具
// 严格翻译自: bun/src/safety/ (safety.zig + alloc.zig + CriticalSection.zig +
//   ThreadLock.zig + asan.zig + thread_id.zig, ~625行)
//   分配器检查、临界区、线程锁、地址消毒器接口
//
// 模块拆分:
//   thread_id.cj         - 线程 ID 工具 (翻译自 thread_id.zig)
//   alloc.cj             - 已检查的分配器 (翻译自 alloc.zig)
//   asan.cj              - 地址消毒器接口 (翻译自 asan.zig)
//   critical_section.cj  - 临界区数据竞争检测 (翻译自 CriticalSection.zig)
//   thread_lock.cj       - 线程锁单线程断言 (翻译自 ThreadLock.zig)
//   safety.cj            - 安全上下文配置 (翻译自 safety.zig)
package bao_safety

// 重导出所有子模块
// 对应 Zig safety.zig:
//   pub const alloc = @import("./alloc.zig");
//   pub const CheckedAllocator = alloc.CheckedAllocator;
//   pub const CriticalSection = @import("./CriticalSection.zig");
//   pub const ThreadLock = @import("./ThreadLock.zig");
