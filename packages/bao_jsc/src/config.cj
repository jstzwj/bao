// 严格翻译自: src/jsc/config.zig (27行)
// Bun VM 配置和转换选项

package bao_jsc

// ========== DefaultBunDefines ==========
// 严格翻译自 config.zig DefaultBunDefines
// 默认的 Bun 全局定义键值
public class DefaultBunDefines {
    // ========== Keys ==========
    public class Keys {
        public static let window: String = "window"
    }

    // ========== Values ==========
    public class Values {
        public static let window: String = "undefined"
    }

    public init() {}
}

// ========== TransformOptions ==========
// 严格翻译自 config.zig configureTransformOptionsForBunVM
// 表示 Transform 选项的配置
public class TransformOptions {
    public var target: TransformTarget = TransformTarget.Bun
    public var write: Bool = false
    public var resolve: ResolveMode = ResolveMode.Lazy

    public init() {}

    public init(target: TransformTarget, write: Bool, resolve: ResolveMode) {
        this.target = target
        this.write = write
        this.resolve = resolve
    }

    // 严格翻译自 configureTransformOptionsForBunVM
    // 为 Bun VM 配置 Transform 选项
    public static func configureForBunVM(options: TransformOptions) -> TransformOptions {
        var args = options
        args.write = false
        args.resolve = ResolveMode.Lazy
        return configureForBun(args)
    }

    // 严格翻译自 configureTransformOptionsForBun
    // 为 Bun 配置 Transform 选项（设置 target 为 bun）
    public static func configureForBun(options: TransformOptions) -> TransformOptions {
        var args = options
        args.target = TransformTarget.Bun
        return args
    }
}

// ========== TransformTarget ==========
// 转换目标平台
public enum TransformTarget <: UInt8 {
    | Bun(0)
    | Browser(1)
    | Node(2)
}

// ========== ResolveMode ==========
// 解析模式
public enum ResolveMode <: UInt8 {
    | Lazy(0)
    | Eager(1)
}
