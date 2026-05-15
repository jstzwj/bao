// GlobalCache - 全局缓存策略
// 严格翻译自: bun/src/options_types/GlobalCache.zig
//   pub const GlobalCache = enum {
//       allow_install, read_only, auto, force, fallback, disable,
//   };
package bao_options

// ============================================================================
// GlobalCache - 全局缓存策略
// 严格翻译自: GlobalCache.zig
// ============================================================================

/// 全局缓存策略 - 对应 Bun GlobalCache
public enum GlobalCache {
    | AllowInstall  // 允许安装到全局缓存
    | ReadOnly      // 只读全局缓存
    | Auto          // 自动决定
    | Force         // 强制使用全局缓存
    | Fallback      // 回退到全局缓存
    | Disable       // 禁用全局缓存

    /// 从字符串解析
    public static func fromString(slice: String): ?GlobalCache {
        match (slice) {
            case "auto" => GlobalCache.Auto
            case "force" => GlobalCache.Force
            case "disable" => GlobalCache.Disable
            case "fallback" => GlobalCache.Fallback
            case _ => None
        }
    }

    /// 是否允许版本说明符
    /// 对应 Bun GlobalCache.allowVersionSpecifier()
    public func allowVersionSpecifier(): Bool {
        this == GlobalCache.Force
    }

    /// 是否可以使用全局缓存
    /// 对应 Bun GlobalCache.canUse()
    /// 当有 node_modules 目录时，默认 false；没有时默认 true
    public func canUse(hasNodeModulesFolder: Bool): Bool {
        if (hasNodeModulesFolder) {
            match (this) {
                case Fallback => true
                case AllowInstall => true
                case Force => true
                case ReadOnly => false
                case Disable => false
                case Auto => false
            }
        } else {
            match (this) {
                case ReadOnly => true
                case Fallback => true
                case AllowInstall => true
                case Auto => true
                case Force => true
                case Disable => false
            }
        }
    }

    /// 是否启用
    /// 对应 Bun GlobalCache.isEnabled()
    public func isEnabled(): Bool {
        this != GlobalCache.Disable
    }

    /// 是否可以安装
    /// 对应 Bun GlobalCache.canInstall()
    public func canInstall(): Bool {
        match (this) {
            case Auto => true
            case AllowInstall => true
            case Force => true
            case Fallback => true
            case _ => false
        }
    }
}
