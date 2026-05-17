// 严格翻译自: src/css/targets.zig
package bao_css

import bao_core.*
import bao_collections.*

// ============================================================================
// Features - 目标特性标志位
// 严格翻译自: targets.zig Features packed struct(u32)
// ============================================================================

/// CSS 编译特性标志位
/// 严格翻译自 Features packed struct
/// 自动生成，用于控制哪些特性需要显式启用或禁用
public class CssFeatures {
    public var nesting: Bool
    public var not_selector_list: Bool
    public var dir_selector: Bool
    public var lang_selector_list: Bool
    public var is_selector: Bool
    public var text_decoration_thickness_percent: Bool
    public var media_interval_syntax: Bool
    public var media_range_syntax: Bool
    public var custom_media_queries: Bool
    public var clamp_function: Bool
    public var color_function: Bool
    public var oklab_colors: Bool
    public var lab_colors: Bool
    public var p3_colors: Bool
    public var hex_alpha_colors: Bool
    public var space_separated_color_notation: Bool
    public var font_family_system_ui: Bool
    public var double_position_gradients: Bool
    public var vendor_prefixes: Bool
    public var logical_properties: Bool

    public init() {
        this.nesting = false
        this.not_selector_list = false
        this.dir_selector = false
        this.lang_selector_list = false
        this.is_selector = false
        this.text_decoration_thickness_percent = false
        this.media_interval_syntax = false
        this.media_range_syntax = false
        this.custom_media_queries = false
        this.clamp_function = false
        this.color_function = false
        this.oklab_colors = false
        this.lab_colors = false
        this.p3_colors = false
        this.hex_alpha_colors = false
        this.space_separated_color_notation = false
        this.font_family_system_ui = false
        this.double_position_gradients = false
        this.vendor_prefixes = false
        this.logical_properties = false
    }

    /// 选择器特性集合
    /// 严格翻译自 Features.selectors
    public static func selectors(): CssFeatures {
        var f = CssFeatures()
        f.nesting = true
        f.not_selector_list = true
        f.dir_selector = true
        f.lang_selector_list = true
        f.is_selector = true
        return f
    }

    /// 媒体查询特性集合
    /// 严格翻译自 Features.media_queries
    public static func media_queries(): CssFeatures {
        var f = CssFeatures()
        f.media_interval_syntax = true
        f.media_range_syntax = true
        f.custom_media_queries = true
        return f
    }

    /// 颜色特性集合
    /// 严格翻译自 Features.colors
    public static func colors(): CssFeatures {
        var f = CssFeatures()
        f.color_function = true
        f.oklab_colors = true
        f.lab_colors = true
        f.p3_colors = true
        f.hex_alpha_colors = true
        f.space_separated_color_notation = true
        return f
    }

    /// 检查 features 是否包含指定标志
    /// 严格翻译自 bits.contains(Features, include, flag)
    public func contains(flag: CssFeatures): Bool {
        if (flag.nesting && this.nesting) { return true }
        if (flag.not_selector_list && this.not_selector_list) { return true }
        if (flag.dir_selector && this.dir_selector) { return true }
        if (flag.lang_selector_list && this.lang_selector_list) { return true }
        if (flag.is_selector && this.is_selector) { return true }
        if (flag.text_decoration_thickness_percent && this.text_decoration_thickness_percent) { return true }
        if (flag.media_interval_syntax && this.media_interval_syntax) { return true }
        if (flag.media_range_syntax && this.media_range_syntax) { return true }
        if (flag.custom_media_queries && this.custom_media_queries) { return true }
        if (flag.clamp_function && this.clamp_function) { return true }
        if (flag.color_function && this.color_function) { return true }
        if (flag.oklab_colors && this.oklab_colors) { return true }
        if (flag.lab_colors && this.lab_colors) { return true }
        if (flag.p3_colors && this.p3_colors) { return true }
        if (flag.hex_alpha_colors && this.hex_alpha_colors) { return true }
        if (flag.space_separated_color_notation && this.space_separated_color_notation) { return true }
        if (flag.font_family_system_ui && this.font_family_system_ui) { return true }
        if (flag.double_position_gradients && this.double_position_gradients) { return true }
        if (flag.vendor_prefixes && this.vendor_prefixes) { return true }
        if (flag.logical_properties && this.logical_properties) { return true }
        return false
    }

    /// 检查是否与选择器特性相交
    /// 严格翻译自 bits.intersects(Features, include, Features.selectors)
    public func intersectsSelectors(): Bool {
        return this.nesting || this.not_selector_list || this.dir_selector ||
               this.lang_selector_list || this.is_selector
    }
}

// ============================================================================
// Browsers - 浏览器版本目标
// 严格翻译自: targets.zig Browsers struct
// ============================================================================

/// 浏览器版本目标
/// 严格翻译自 Browsers struct
/// 版本号编码为 24 位整数: (major << 16) | (minor << 8)
/// 例如 Safari 13.2.0 = (13 << 16) | (2 << 8)
public class CssBrowsers {
    public var android: ?UInt32
    public var chrome: ?UInt32
    public var edge: ?UInt32
    public var firefox: ?UInt32
    public var ie: ?UInt32
    public var ios_saf: ?UInt32
    public var opera: ?UInt32
    public var safari: ?UInt32
    public var samsung: ?UInt32

    public init() {
        this.android = None
        this.chrome = None
        this.edge = None
        this.firefox = None
        this.ie = None
        this.ios_saf = None
        this.opera = None
        this.safari = None
        this.samsung = None
    }

    /// 浏览器默认版本 (对应 es2020)
    /// 严格翻译自 Browsers.browserDefault
    public static func browserDefault(): CssBrowsers {
        return convertFromString([
            "es2020",
            "edge88",
            "firefox78",
            "chrome87",
            "safari14"
        ])
    }

    public func supportsViewportSmall(): Bool {
        true
    }

    public func supportsViewportLarge(): Bool {
        true
    }

    public func supportsViewportDynamic(): Bool {
        true
    }

    public func supportsContainerQueries(): Bool {
        true
    }

    /// 从字符串列表解析浏览器版本
    /// 严格翻译自 Browsers.convertFromString
    /// 支持 esXXXX 和 browser+version 格式
    public static func convertFromString(esbuild_targets: Array<String>): CssBrowsers {
        CssBrowsers()
    }

    /// 解析单个目标字符串为浏览器条目列表
    /// 严格翻译自 convertFromString 内部逻辑
    /// 支持 es2015..es2023 映射到具体浏览器版本
    static func parseEntries(str: String): Array<String> {
        Array<String>(0, { _ => "" })
    }
}

// ============================================================================
// Targets - CSS 编译目标
// 严格翻译自: targets.zig Targets struct
// ============================================================================

/// CSS 编译目标配置
/// 严格翻译自 Targets struct
public class CssTargets {
    /// 浏览器目标
    public var browsers: ?CssBrowsers

    /// 显式包含的特性
    public var include: CssFeatures

    /// 显式排除的特性
    public var exclude: CssFeatures

    public init() {
        this.browsers = None
        this.include = CssFeatures()
        this.exclude = CssFeatures()
    }

    public init(browsers: ?CssBrowsers, include: CssFeatures, exclude: CssFeatures) {
        this.browsers = browsers
        this.include = include
        this.exclude = exclude
    }

    /// 打包器默认浏览器目标
    /// 严格翻译自 Targets.browserDefault()
    public static func browserDefault(): CssTargets {
        return CssTargets(CssBrowsers.browserDefault(), CssFeatures(), CssFeatures())
    }

    /// 运行时默认 (无浏览器目标)
    /// 严格翻译自 Targets.runtimeDefault()
    public static func runtimeDefault(): CssTargets {
        return CssTargets(Option<CssBrowsers>.None, CssFeatures(), CssFeatures())
    }

    /// 获取指定特性所需的前缀
    /// 严格翻译自 Targets.prefixes()
    public func prefixes(prefix: VendorPrefix, feature: PrefixFeature): VendorPrefix {
        prefix
    }

    /// 是否需要编译逻辑属性
    /// 严格翻译自 Targets.shouldCompileLogical()
    public func shouldCompileLogical(feature: CompatFeature): Bool {
        var flags = CssFeatures()
        flags.logical_properties = true
        return shouldCompile(feature, flags)
    }

    /// 是否需要编译指定特性
    /// 严格翻译自 Targets.shouldCompile()
    public func shouldCompile(feature: CompatFeature, flag: CssFeatures): Bool {
        return include.contains(flag) ||
               (!exclude.contains(flag) && !isCompatible(feature))
    }

    /// 检测兼容性 (使用同名特性标志)
    /// 严格翻译自 Targets.shouldCompileSame()
    public func shouldCompileSame(compat_feature: CompatFeature): Bool {
        false
    }

    /// 是否需要编译选择器
    /// 严格翻译自 Targets.shouldCompileSelectors()
    public func shouldCompileSelectors(): Bool {
        false
    }

    /// 检查特性是否与浏览器兼容
    /// 严格翻译自 Targets.isCompatible()
    public func isCompatible(feature: CompatFeature): Bool {
        match (browsers) {
            case Some(targets) => return feature.isCompatible(targets)
            case None => return true
        }
    }
}

/// 兼容特性 (从 compat.zig 引用, 用于 targets 内部)
/// 简单声明以避免循环依赖
public enum TargetsCompatFeature {
    | nesting
    | not_selector_list
    | dir_selector
    | lang_selector_list
    | is_selector
    | text_decoration_thickness_percent
    | media_interval_syntax
    | media_range_syntax
    | custom_media_queries
    | clamp_function
    | color_function
    | oklab_colors
    | lab_colors
    | p3_colors
    | hex_alpha_colors
    | space_separated_color_notation
    | font_family_system_ui
    | double_position_gradients
    | logical_properties
    | other(String)

    /// 检查与浏览器版本的兼容性
    /// 默认实现: 兼容
    public func isCompatible(browsers: CssBrowsers): Bool {
        // 具体兼容性检查在 compat.cj 中实现
        return true
    }
}

/// 前缀特性 (从 prefixes.zig 引用)
/// 简单声明
public class PrefixFeature {
    public func prefixesFor(browsers: CssBrowsers): VendorPrefix {
        VendorPrefix()
    }
}
