// 翻译自 Bun: src/runtime/bake/enums.ts
// 消息日志级别枚举

package bao_runtime.bake

/// Bundler 消息级别
/// 对应 Bun: enums.ts BundlerMessageLevel
public enum BundlerMessageLevel <: UInt8 {
    | err = 0
    | warn = 1
    | note = 2
    | debug = 3
    | verbose = 4
}
