// 严格翻译自: src/css/targets.zig
package bao.css

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

    /// 从字符串列表解析浏览器版本
    /// 严格翻译自 Browsers.convertFromString
    /// 支持 esXXXX 和 browser+version 格式
    public static func convertFromString(esbuild_targets: Array<String>): CssBrowsers {
        var browsers = CssBrowsers()

        for (str in esbuild_targets) {
            var entries = parseEntries(str)
            for (entry in entries) {
                if (entry == "esnext") {
                    continue
                }
                // 查找数字开始的位置
                var idx: ?Int64 = None
                var i: Int64 = 0
                while (i < entry.size) {
                    var c = entry[Int64(i)]
                    if (c >= '0' && c <= '9') {
                        idx = i
                        break
                    }
                    i++
                }

                if (let Some(num_idx) = idx) {
                    let browser_name = entry.substring(0, num_idx)
                    let version_str = entry.substring(num_idx)

                    // 解析 major.minor
                    var major: UInt32 = 0
                    var minor: UInt32 = 0
                    let dot_index = version_str.indexOf('.')
                    if (let Some(dot) = dot_index) {
                        major = UInt32.parseUInt32(version_str.substring(0, dot)) ?? UInt32(0)
                        let minor_str = version_str.substring(dot + 1)
                        minor = UInt32.parseUInt32(minor_str) ?? UInt32(0)
                    } else {
                        major = UInt32.parseUInt32(version_str) ?? UInt32(0)
                    }

                    let version: UInt32 = (major << UInt32(16)) | (minor << UInt32(8))

                    // 映射浏览器名到字段
                    match (browser_name) {
                        case "chrome" =>
                            if (browsers.chrome == None || version < browsers.chrome.getOrThrow()) {
                                browsers.chrome = version
                            }
                        case "edge" =>
                            if (browsers.edge == None || version < browsers.edge.getOrThrow()) {
                                browsers.edge = version
                            }
                        case "firefox" =>
                            if (browsers.firefox == None || version < browsers.firefox.getOrThrow()) {
                                browsers.firefox = version
                            }
                        case "ie" =>
                            if (browsers.ie == None || version < browsers.ie.getOrThrow()) {
                                browsers.ie = version
                            }
                        case "ios" =>
                            if (browsers.ios_saf == None || version < browsers.ios_saf.getOrThrow()) {
                                browsers.ios_saf = version
                            }
                        case "opera" =>
                            if (browsers.opera == None || version < browsers.opera.getOrThrow()) {
                                browsers.opera = version
                            }
                        case "safari" =>
                            if (browsers.safari == None || version < browsers.safari.getOrThrow()) {
                                browsers.safari = version
                            }
                        case _ => () // hermes, node, rhino 等无映射
                    }
                }
            }
        }

        return browsers
    }

    /// 解析单个目标字符串为浏览器条目列表
    /// 严格翻译自 convertFromString 内部逻辑
    /// 支持 es2015..es2023 映射到具体浏览器版本
    static func parseEntries(str: String): Array<String> {
        // 检查是否是 esXXXX 格式
        if (str.size > 2 && str[0] == 'e' && str[1] == 's') {
            let number_part = str.substring(2)
            let year = Int64.parse(number_part)
            match (year) {
                case Some(2015) => return ["chrome49", "edge13", "safari10", "firefox44", "opera36"]
                case Some(2016) => return ["chrome50", "edge13", "safari10", "firefox43", "opera37"]
                case Some(2017) => return ["chrome58", "edge15", "safari11", "firefox52", "opera45"]
                case Some(2018) => return ["chrome63", "edge79", "safari12", "firefox58", "opera50"]
                case Some(2019) => return ["chrome73", "edge79", "safari12.1", "firefox64", "opera60"]
                case Some(2020) => return ["chrome80", "edge80", "safari14.1", "firefox80", "opera67"]
                case Some(2021) => return ["chrome85", "edge85", "safari14.1", "firefox80", "opera71"]
                case Some(2022) => return ["chrome94", "edge94", "safari16.4", "firefox93", "opera80"]
                case Some(2023) => return ["chrome110", "edge110", "safari16.4", "opera96"]
                case _ => return [str]
            }
        }
        return [str]
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
        return CssTargets(None, CssFeatures(), CssFeatures())
    }

    /// 获取指定特性所需的前缀
    /// 严格翻译自 Targets.prefixes()
    public func prefixes(prefix: VendorPrefix, feature: PrefixFeature): VendorPrefix {
        if (prefix.isNone() && !exclude.vendor_prefixes) {
            if (include.vendor_prefixes) {
                return VendorPrefix.all()
            } else {
                match (browsers) {
                    case Some(b) => return feature.prefixesFor(b)
                    case None => return prefix
                }
            }
        } else {
            return prefix
        }
    }

    /// 是否需要编译逻辑属性
    /// 严格翻译自 Targets.shouldCompileLogical()
    public func shouldCompileLogical(feature: CompatFeature): Bool {
        return shouldCompile(feature, CssFeatures()..logical_properties = true)
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
        var flag = CssFeatures()
        // 根据兼容性特性设置对应的标志
        match (compat_feature) {
            case CompatFeature.nesting => flag.nesting = true
            case CompatFeature.not_selector_list => flag.not_selector_list = true
            case CompatFeature.dir_selector => flag.dir_selector = true
            case CompatFeature.lang_selector_list => flag.lang_selector_list = true
            case CompatFeature.is_selector => flag.is_selector = true
            case CompatFeature.media_interval_syntax => flag.media_interval_syntax = true
            case CompatFeature.media_range_syntax => flag.media_range_syntax = true
            case CompatFeature.custom_media_queries => flag.custom_media_queries = true
            case CompatFeature.text_decoration_thickness_percent => flag.text_decoration_thickness_percent = true
            case CompatFeature.clamp_function => flag.clamp_function = true
            case CompatFeature.color_function => flag.color_function = true
            case CompatFeature.oklab_colors => flag.oklab_colors = true
            case CompatFeature.lab_colors => flag.lab_colors = true
            case CompatFeature.p3_colors => flag.p3_colors = true
            case CompatFeature.hex_alpha_colors => flag.hex_alpha_colors = true
            case CompatFeature.space_separated_color_notation => flag.space_separated_color_notation = true
            case CompatFeature.font_family_system_ui => flag.font_family_system_ui = true
            case CompatFeature.double_position_gradients => flag.double_position_gradients = true
            case CompatFeature.logical_properties => flag.logical_properties = true
            case _ => ()
        }
        return shouldCompile(compat_feature, flag)
    }

    /// 是否需要编译选择器
    /// 严格翻译自 Targets.shouldCompileSelectors()
    public func shouldCompileSelectors(): Bool {
        return include.intersectsSelectors() ||
               (!exclude.intersectsSelectors() && browsers != None)
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

/// 兼容特性 (从 compat.zig 引用)
/// 简单声明以避免循环依赖
public enum CompatFeature {
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
        return VendorPrefix.none()
    }
}
