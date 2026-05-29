// 严格翻译自: src/css/targets.zig
package bao_css

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
        var browsers = CssBrowsers()
        for (str in esbuild_targets) {
            let entries = parseEntries(str)
            for (entry in entries) {
                if (entry == "esnext") { continue }
                // 找到浏览器名称和版本的分界点
                var idx: Int64 = -1
                let chars = entry.toArray()
                for (i in 0..chars.size) {
                    let c = chars[i]
                    if (c >= UInt8(48) && c <= UInt8(57)) {
                        idx = i
                        break
                    }
                }
                if (idx < 0) { continue }

                let browserName = entry[0..idx]
                let versionStr = entry[idx..]

                // 解析主版本号和次版本号
                var major: UInt32 = 0
                var minor: UInt32 = 0
                let dotIdx = versionStr.indexOf(".")
                if (dotIdx.isSome()) {
                    let di = dotIdx.getOrThrow()
                    major = parseVersionPart(versionStr[0..di])
                    minor = parseVersionPart(versionStr[(di + 1)..])
                } else {
                    major = parseVersionPart(versionStr)
                }

                let version: UInt32 = (major << 16) | (minor << 8)

                // 根据浏览器名称设置版本 (取最小值)
                if (browserName == "chrome") {
                    match (browsers.chrome) {
                        case Some(v) => if (version < v) { browsers.chrome = Some(version) }
                        case None => browsers.chrome = Some(version)
                    }
                } else if (browserName == "edge") {
                    match (browsers.edge) {
                        case Some(v) => if (version < v) { browsers.edge = Some(version) }
                        case None => browsers.edge = Some(version)
                    }
                } else if (browserName == "firefox") {
                    match (browsers.firefox) {
                        case Some(v) => if (version < v) { browsers.firefox = Some(version) }
                        case None => browsers.firefox = Some(version)
                    }
                } else if (browserName == "ie") {
                    match (browsers.ie) {
                        case Some(v) => if (version < v) { browsers.ie = Some(version) }
                        case None => browsers.ie = Some(version)
                    }
                } else if (browserName == "ios") {
                    match (browsers.ios_saf) {
                        case Some(v) => if (version < v) { browsers.ios_saf = Some(version) }
                        case None => browsers.ios_saf = Some(version)
                    }
                } else if (browserName == "opera") {
                    match (browsers.opera) {
                        case Some(v) => if (version < v) { browsers.opera = Some(version) }
                        case None => browsers.opera = Some(version)
                    }
                } else if (browserName == "safari") {
                    match (browsers.safari) {
                        case Some(v) => if (version < v) { browsers.safari = Some(version) }
                        case None => browsers.safari = Some(version)
                    }
                }
            }
        }
        browsers
    }

    /// 解析版本号部分字符串为 UInt32
    static func parseVersionPart(s: String): UInt32 {
        if (s.isEmpty()) { return UInt32(0) }
        var result: UInt32 = 0
        for (c in s) {
            if (c >= UInt8(48) && c <= UInt8(57)) {
                result = result * UInt32(10) + UInt32(c - UInt8(48))
            }
        }
        result
    }

    /// 解析单个目标字符串为浏览器条目列表
    /// 严格翻译自 convertFromString 内部逻辑
    /// 支持 es2015..es2023 映射到具体浏览器版本
    static func parseEntries(str: String): Array<String> {
        // 检查是否为 esXXXX 格式
        if (str.size > 2 && str[0] == UInt8(101) && str[1] == UInt8(115)) {
            // "es" prefix
            let yearStr = str[2..]
            let year = parseVersionPart(yearStr)
            if (year == 2015) {
                return ["chrome49", "edge13", "safari10", "firefox44", "opera36"]
            } else if (year == 2016) {
                return ["chrome50", "edge13", "safari10", "firefox43", "opera37"]
            } else if (year == 2017) {
                return ["chrome58", "edge15", "safari11", "firefox52", "opera45"]
            } else if (year == 2018) {
                return ["chrome63", "edge79", "safari12", "firefox58", "opera50"]
            } else if (year == 2019) {
                return ["chrome73", "edge79", "safari12.1", "firefox64", "opera60"]
            } else if (year == 2020) {
                return ["chrome80", "edge80", "safari14.1", "firefox80", "opera67"]
            } else if (year == 2021) {
                return ["chrome85", "edge85", "safari14.1", "firefox80", "opera71"]
            } else if (year == 2022) {
                return ["chrome94", "edge94", "safari16.4", "firefox93", "opera80"]
            } else if (year == 2023) {
                return ["chrome110", "edge110", "safari16.4", "opera96"]
            }
            // 未知的 ES 版本, 返回原始字符串
            return [str]
        }
        // 非 es 前缀, 直接返回
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
        return CssTargets(Option<CssBrowsers>.None, CssFeatures(), CssFeatures())
    }

    /// 获取指定特性所需的前缀
    /// 严格翻译自 Targets.prefixes()
    /// 如果 prefix.none 且 exclude 中不包含 vendor_prefixes, 则查询特性所需前缀
    /// 如果 include 中包含 vendor_prefixes, 则返回所有前缀 (.all)
    public func prefixes(prefix: VendorPrefix, feature: CssFeature): VendorPrefix {
        if (prefix.none && !exclude.vendor_prefixes) {
            if (include.vendor_prefixes) {
                return VendorPrefix.all()
            } else {
                return match (browsers) {
                    case Some(b) =>
                        let bt = convertToBrowserTargets(b)
                        CssPrefixLookup.prefixesFor(feature, bt)
                    case None => prefix
                }
            }
        } else {
            return prefix
        }
    }

    /// 将 CssBrowsers 转换为 CssBrowserTargets
    private static func convertToBrowserTargets(b: CssBrowsers): CssBrowserTargets {
        let bt = CssBrowserTargets()
        match (b.android) { case Some(v) => bt.android = Some(Int64(v)) case None => () }
        match (b.chrome) { case Some(v) => bt.chrome = Some(Int64(v)) case None => () }
        match (b.edge) { case Some(v) => bt.edge = Some(Int64(v)) case None => () }
        match (b.firefox) { case Some(v) => bt.firefox = Some(Int64(v)) case None => () }
        match (b.ie) { case Some(v) => bt.ie = Some(Int64(v)) case None => () }
        match (b.ios_saf) { case Some(v) => bt.iosSaf = Some(Int64(v)) case None => () }
        match (b.opera) { case Some(v) => bt.opera = Some(Int64(v)) case None => () }
        match (b.safari) { case Some(v) => bt.safari = Some(Int64(v)) case None => () }
        match (b.samsung) { case Some(v) => bt.samsung = Some(Int64(v)) case None => () }
        bt
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
    /// 创建一个只包含指定特性标志的 Features, 然后调用 shouldCompile
    public func shouldCompileSame(compat_feature: CompatFeature): Bool {
        var flag = CssFeatures()
        // 根据 compat_feature 设置对应的标志
        match (compat_feature) {
            case CompatFeature.nesting => flag.nesting = true
            case CompatFeature.not_selector_list => flag.not_selector_list = true
            case CompatFeature.dir_selector => flag.dir_selector = true
            case CompatFeature.lang_selector_list => flag.lang_selector_list = true
            case CompatFeature.is_selector => flag.is_selector = true
            case CompatFeature.text_decoration_thickness_percent => flag.text_decoration_thickness_percent = true
            case CompatFeature.media_interval_syntax => flag.media_interval_syntax = true
            case CompatFeature.media_range_syntax => flag.media_range_syntax = true
            case CompatFeature.custom_media_queries => flag.custom_media_queries = true
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
        include.intersectsSelectors() ||
            (!exclude.intersectsSelectors() && match (browsers) { case Some(_) => true case None => false })
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
/// 使用 CssFeature 枚举作为前缀特性标识符
public class PrefixFeature {
    public var feature: CssFeature

    public init(feature: CssFeature) {
        this.feature = feature
    }

    public func prefixesFor(browsers: CssBrowsers): VendorPrefix {
        CssPrefixLookup.prefixesFor(feature, browsers)
    }
}
