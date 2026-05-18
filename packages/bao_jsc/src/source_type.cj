// 严格翻译自: src/jsc/SourceType.zig
// 源代码类型枚举（来自 WebKit SourceProvider.h）

package bao_jsc

// ========== SourceType ==========
// 严格翻译自 SourceType.zig SourceType
// 源代码类型枚举，来自 WebKit SourceProvider.h
// 用于标识 JavaScript 源代码是普通脚本、ES 模块还是 WebAssembly
// Bun 原始类型: enum(u8) { Program = 0, Module = 1, WebAssembly = 2 }
public enum SourceType <: UInt8 {
    | Program(0)
    | Module(1)
    | WebAssembly(2)
}
