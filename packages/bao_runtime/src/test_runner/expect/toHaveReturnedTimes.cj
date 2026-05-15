// toHaveReturnedTimes.cj - 检查mock函数返回的次数
// 严格翻译自 bun/src/runtime/test_runner/expect/toHaveReturnedTimes.zig
// 注意: 原始Zig文件是 toHaveReturned.zig 中 toHaveReturnedTimes 的别名

package bao_runtime

/// toHaveReturnedTimes() - 检查mock函数返回的次数
/// 用法: expect(received).toHaveReturnedTimes(expected)
public typealias toHaveReturnedTimes = toHaveReturned.toHaveReturnedTimes
