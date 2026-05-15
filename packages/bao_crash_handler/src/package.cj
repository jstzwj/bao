// bao_crash_handler - 崩溃处理包
// 严格翻译自: bun/src/crash_handler/ (CPUFeatures.zig + crash_handler.zig + handle_oom.zig)
//   CPU 特性检测、崩溃捕获与栈追踪、OOM 处理
package bao_crash_handler

// 重导出子模块
// cpu_features.cj: CPUFlags, CPUFeatures
// crash_handler.cj: CrashReason, Action, StackTrace, StackLine, StoredTrace,
//   TraceString, CrashPlatform, WriteStackTraceLimits, SourceAtAddress,
//   SourceLocationInfo, OnBeforeCrashCallback, BeforeCrashHandlerEntry, CrashHandler
// handle_oom.cj: HandleOom, outOfMemory
