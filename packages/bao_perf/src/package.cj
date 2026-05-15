// bao_perf - 性能追踪、性能分析和硬件计时器
// 严格翻译自: bun/src/perf/
//   包含以下模块:
//     - generated_perf_trace_events: 自动生成的性能追踪事件枚举
//     - hw_timer: 无屏障硬件时间戳计数器
//     - perf: 系统级性能追踪 (macOS Instruments / Linux perf)
//     - system_timer: 系统计时器抽象
//     - tracy: Tracy 性能分析器集成
//
//   Zig 版本通过 comptime、内联汇编和 extern "c" 实现高性能计时
//   仓颉版本使用仓颉 FFI 和平台 API 实现等价功能
package bao_perf
