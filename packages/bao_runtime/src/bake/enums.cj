// 翻译自 Bun: src/runtime/bake/enums.ts
// 消息日志级别枚举

package bao_runtime.bake

/// Bundler 消息级别
/// 对应 Bun: enums.ts BundlerMessageLevel
public enum BundlerMessageLevel {
    | err
    | warn
    | note
    | debug
    | verbose

    public func value(): UInt8 {
        match (this) {
            case err => 0
            case warn => 1
            case note => 2
            case debug => 3
            case verbose => 4
        }
    }
}
