// Fetch API 类型定义
// 严格翻译自:
//   src/http_types/FetchCacheMode.zig - Fetch 缓存模式
//   src/http_types/FetchRedirect.zig - Fetch 重定向策略
//   src/http_types/FetchRequestMode.zig - Fetch 请求模式
// 参考: https://developer.mozilla.org/en-US/docs/Web/API/Request
package bao_http_types

import bao_core.*

// ============================================================================
// FetchCacheMode - Fetch 缓存模式
// 严格翻译自: FetchCacheMode.zig FetchCacheMode enum(u3)
// https://developer.mozilla.org/en-US/docs/Web/API/Request/cache
// ============================================================================

/// Fetch 缓存模式枚举 - 对应 Bun FetchCacheMode
public enum FetchCacheMode {
    | Default         // 标准缓存行为
    | NoStore         // 不使用缓存
    | Reload          // 强制重新加载
    | NoCache         // 使用缓存前必须验证
    | ForceCache      // 强制使用缓存
    | OnlyIfCached    // 仅使用缓存
}

// ============================================================================
// FetchCacheModeUtil - FetchCacheMode 工具
// 严格翻译自: FetchCacheMode.zig 中的 ComptimeStringMap
// ============================================================================

/// Fetch 缓存模式工具
public class FetchCacheModeUtil {
    private static let MAP: HashMap<String, FetchCacheMode> = buildMap()

    private static func buildMap(): HashMap<String, FetchCacheMode> {
        let m = HashMap<String, FetchCacheMode>()
        m.put("default", FetchCacheMode.Default)
        m.put("no-store", FetchCacheMode.NoStore)
        m.put("reload", FetchCacheMode.Reload)
        m.put("no-cache", FetchCacheMode.NoCache)
        m.put("force-cache", FetchCacheMode.ForceCache)
        m.put("only-if-cached", FetchCacheMode.OnlyIfCached)
        return m
    }

    /// 从字符串解析缓存模式
    public static func fromString(str: String): ?FetchCacheMode {
        return MAP.get(str)
    }

    /// 缓存模式转字符串
    public static func toString(mode: FetchCacheMode): String {
        match (mode) {
            case FetchCacheMode.Default => "default"
            case FetchCacheMode.NoStore => "no-store"
            case FetchCacheMode.Reload => "reload"
            case FetchCacheMode.NoCache => "no-cache"
            case FetchCacheMode.ForceCache => "force-cache"
            case FetchCacheMode.OnlyIfCached => "only-if-cached"
        }
    }
}

// ============================================================================
// FetchRedirect - Fetch 重定向策略
// 严格翻译自: FetchRedirect.zig FetchRedirect enum(u2)
// ============================================================================

/// Fetch 重定向策略枚举 - 对应 Bun FetchRedirect
public enum FetchRedirect {
    | Follow    // 自动跟随重定向
    | Manual    // 手动处理重定向
    | Error     // 重定向时抛出错误
}

// ============================================================================
// FetchRedirectUtil - FetchRedirect 工具
// 严格翻译自: FetchRedirect.zig 中的 ComptimeStringMap
// ============================================================================

/// Fetch 重定向策略工具
public class FetchRedirectUtil {
    private static let MAP: HashMap<String, FetchRedirect> = buildMap()

    private static func buildMap(): HashMap<String, FetchRedirect> {
        let m = HashMap<String, FetchRedirect>()
        m.put("follow", FetchRedirect.Follow)
        m.put("manual", FetchRedirect.Manual)
        m.put("error", FetchRedirect.Error)
        return m
    }

    /// 从字符串解析重定向策略
    public static func fromString(str: String): ?FetchRedirect {
        return MAP.get(str)
    }

    /// 重定向策略转字符串
    public static func toString(redirect: FetchRedirect): String {
        match (redirect) {
            case FetchRedirect.Follow => "follow"
            case FetchRedirect.Manual => "manual"
            case FetchRedirect.Error => "error"
        }
    }
}

// ============================================================================
// FetchRequestMode - Fetch 请求模式
// 严格翻译自: FetchRequestMode.zig FetchRequestMode enum(u2)
// https://developer.mozilla.org/en-US/docs/Web/API/Request/mode
// ============================================================================

/// Fetch 请求模式枚举 - 对应 Bun FetchRequestMode
public enum FetchRequestMode {
    | SameOrigin   // 同源请求
    | NoCors       // 无 CORS
    | Cors         // CORS 请求
    | Navigate     // 导航请求
}

// ============================================================================
// FetchRequestModeUtil - FetchRequestMode 工具
// 严格翻译自: FetchRequestMode.zig 中的 ComptimeStringMap
// ============================================================================

/// Fetch 请求模式工具
public class FetchRequestModeUtil {
    private static let MAP: HashMap<String, FetchRequestMode> = buildMap()

    private static func buildMap(): HashMap<String, FetchRequestMode> {
        let m = HashMap<String, FetchRequestMode>()
        m.put("same-origin", FetchRequestMode.SameOrigin)
        m.put("no-cors", FetchRequestMode.NoCors)
        m.put("cors", FetchRequestMode.Cors)
        m.put("navigate", FetchRequestMode.Navigate)
        return m
    }

    /// 从字符串解析请求模式
    public static func fromString(str: String): ?FetchRequestMode {
        return MAP.get(str)
    }

    /// 请求模式转字符串
    public static func toString(mode: FetchRequestMode): String {
        match (mode) {
            case FetchRequestMode.SameOrigin => "same-origin"
            case FetchRequestMode.NoCors => "no-cors"
            case FetchRequestMode.Cors => "cors"
            case FetchRequestMode.Navigate => "navigate"
        }
    }
}
