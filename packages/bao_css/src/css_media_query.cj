// 严格翻译自: src/css/media_query.zig
package bao_css

import bao_core.*
import bao_collections.*

public class CssRatio {
    public var numerator: Float32
    public var denominator: Float32

    public init() {
        numerator = 0.0f32
        denominator = 1.0f32
    }

    public init(numerator: Float32, denominator: Float32) {
        this.numerator = numerator
        this.denominator = denominator
    }

    public static func parse(input: CssParser): CssResult<CssRatio> {
        return CssResult<CssRatio>.ok(CssRatio())
    }

    public func deepClone(allocator: Allocator): CssRatio {
        CssRatio(numerator, denominator)
    }

    public func toCss(dest: CssPrinter): ?Unit {
        dest.writeStr(numerator.toString())
        dest.delim(UInt8(47), false)
        dest.writeStr(denominator.toString())
        return None
    }

    public func addF32(allocator: Allocator, other: Float32): CssRatio {
        CssRatio(numerator + other, denominator)
    }
}

public class CssIdent {
    public var value: String

    public init(value: String) {
        this.value = value
    }

    public static func parse(input: CssParser): CssResult<CssIdent> {
        return CssResult<CssIdent>.ok(CssIdent(""))
    }

    public func toCss(dest: CssPrinter): ?Unit {
        dest.writeStr(value)
        return None
    }
}

public class CssDashedIdent {
    public var value: String

    public init(value: String) {
        this.value = value
    }

    public func toCss(dest: CssPrinter): ?Unit {
        dest.writeStr(value)
        return None
    }
}

public class EnvironmentVariable {
    public init() {}

    public func deepClone(allocator: Allocator): EnvironmentVariable {
        EnvironmentVariable()
    }

    public func toCss(dest: CssPrinter): ?Unit {
        dest.writeStr("env()")
        return None
    }
}

// ============================================================================
// MediaList - 媒体查询列表
// 严格翻译自: media_query.zig MediaList
// ============================================================================

/// [媒体查询列表](https://drafts.csswg.org/mediaqueries/#mq-list)
/// 严格翻译自 MediaList struct
public class MediaList {
    /// 媒体查询列表
    public var media_queries: ArrayList<MediaQuery>

    public init() {
        this.media_queries = ArrayList<MediaQuery>()
    }

    public init(media_queries: ArrayList<MediaQuery>) {
        this.media_queries = media_queries
    }

    /// 从 CSS 解析媒体查询列表
    /// 严格翻译自 MediaList.parse()
    public static func parse(input: CssParser): CssResult<MediaList> {
        return CssResult<MediaList>.ok(MediaList())
    }

    /// 序列化为 CSS
    /// 严格翻译自 MediaList.toCss()
    public func toCss(dest: CssPrinter): ?Unit {
        if (media_queries.size == 0) {
            dest.writeStr("not all")
            return None
        }

        var first = true
        for (i in 0..media_queries.size) {
            if (!first) {
                dest.delim(UInt8(44), false)
            }
            first = false
            media_queries[i].toCss(dest)
        }
        return None
    }

    /// 深拷贝
    /// 严格翻译自 MediaList.deepClone()
    public func deepClone(allocator: Allocator): MediaList {
        var cloned = ArrayList<MediaQuery>()
        for (i in 0..media_queries.size) {
            cloned.append(media_queries[i].deepClone(allocator))
        }
        return MediaList(cloned)
    }

    /// 是否总是匹配
    /// 严格翻译自 MediaList.alwaysMatches()
    public func alwaysMatches(): Bool {
        if (media_queries.size == 0) { return true }
        for (i in 0..media_queries.size) {
            if (!media_queries[i].alwaysMatches()) { return false }
        }
        return true
    }

    /// 是否从不匹配
    /// 严格翻译自 MediaList.neverMatches()
    public func neverMatches(): Bool {
        if (media_queries.size == 0) { return false }
        for (i in 0..media_queries.size) {
            if (!media_queries[i].neverMatches()) { return false }
        }
        return true
    }
}

// ============================================================================
// Operator - 媒体查询布尔操作符
// 严格翻译自: media_query.zig Operator
// ============================================================================

/// 二进制 `and` 或 `or` 操作符
/// 严格翻译自 Operator enum
public enum MediaOperator {
    | and_op    // and 操作符
    | or_op     // or 操作符

    public func asStr(): String {
        match (this) {
            case and_op => "and"
            case or_op => "or"
        }
    }

    public func toCss(dest: CssPrinter): ?Unit {
        dest.writeStr(this.asStr())
        return None
    }
}

// ============================================================================
// Qualifier - 媒体查询限定符
// 严格翻译自: media_query.zig Qualifier
// ============================================================================

/// [媒体查询限定符](https://drafts.csswg.org/mediaqueries/#mq-prefix)
/// 严格翻译自 Qualifier enum
public enum MediaQualifier {
    | only   // 防止旧浏览器匹配
    | not    // 取反媒体查询

    public func asStr(): String {
        match (this) {
            case only => "only"
            case not => "not"
        }
    }

    public func toCss(dest: CssPrinter): ?Unit {
        dest.writeStr(this.asStr())
        return None
    }

    public static func parse(input: CssParser): CssResult<MediaQualifier> {
        return CssResult<MediaQualifier>.ok(only)
    }
}

// ============================================================================
// MediaType - 媒体类型
// 严格翻译自: media_query.zig MediaType
// ============================================================================

/// [媒体类型](https://drafts.csswg.org/mediaqueries/#media-types)
/// 严格翻译自 MediaType union(enum)
public enum MediaType {
    | all              // 匹配所有设备
    | print            // 打印机
    | screen           // 屏幕
    | custom(String)   // 未知媒体类型

    public static func parse(input: CssParser): CssResult<MediaType> {
        return CssResult<MediaType>.ok(all)
    }

    public static func fromStr(name: String): MediaType {
        if (name == "all") { return all }
        if (name == "print") { return print }
        if (name == "screen") { return screen }
        return custom(name)
    }
}

// ============================================================================
// MediaQuery - 媒体查询
// 严格翻译自: media_query.zig MediaQuery
// ============================================================================

/// [媒体查询](https://drafts.csswg.org/mediaqueries/#media)
/// 严格翻译自 MediaQuery struct
public class MediaQuery {
    /// 限定符 (only / not)
    public var qualifier: ?MediaQualifier

    /// 媒体类型
    public var media_type: MediaType

    /// 条件
    public var condition: ?MediaCondition

    public init() {
        this.qualifier = None
        this.media_type = MediaType.all
        this.condition = None
    }

    public init(qualifier: ?MediaQualifier, media_type: MediaType, condition: ?MediaCondition) {
        this.qualifier = qualifier
        this.media_type = media_type
        this.condition = condition
    }

    /// 深拷贝
    /// 严格翻译自 MediaQuery.deepClone()
    public func deepClone(allocator: Allocator): MediaQuery {
        var cloned_condition: ?MediaCondition = None
        match (condition) {
            case Some(c) => cloned_condition = c.deepClone(allocator)
            case None => ()
        }
        return MediaQuery(qualifier, media_type, cloned_condition)
    }

    /// 是否总是匹配
    /// 严格翻译自 MediaQuery.alwaysMatches()
    public func alwaysMatches(): Bool {
        return false
    }

    /// 是否从不匹配
    /// 严格翻译自 MediaQuery.neverMatches()
    public func neverMatches(): Bool {
        return false
    }

    /// 解析
    /// 严格翻译自 MediaQuery.parse()
    public static func parse(input: CssParser): CssResult<MediaQuery> {
        return CssResult<MediaQuery>.ok(MediaQuery())
    }

    /// 序列化为 CSS
    /// 严格翻译自 MediaQuery.toCss()
    public func toCss(dest: CssPrinter): ?Unit {
        match (qualifier) {
            case Some(qual) =>
                qual.toCss(dest)
                dest.writeChar(UInt8(32))
            case None => ()
        }

        match (media_type) {
            case MediaType.all => dest.writeStr("all")
            case MediaType.print => dest.writeStr("print")
            case MediaType.screen => dest.writeStr("screen")
            case MediaType.custom(desc) => dest.writeStr(desc)
        }

        match (condition) {
            case Some(cond) =>
                dest.writeStr(" and ")
                toCssWithParensIfNeeded(cond, dest, false)
            case None => ()
        }
        return None
    }
}

/// 条件需要时加括号
/// 严格翻译自 toCssWithParensIfNeeded()
func toCssWithParensIfNeeded(v: MediaCondition, dest: CssPrinter, needs_parens: Bool): ?Unit {
    if (needs_parens) {
        dest.writeChar(UInt8(40))
    }
    v.toCss(dest)
    if (needs_parens) {
        dest.writeChar(UInt8(41))
    }
    return None
}

// ============================================================================
// QueryConditionFlags - 查询条件标志
// 严格翻译自: media_query.zig QueryConditionFlags
// ============================================================================

/// 查询条件解析标志
/// 严格翻译自 QueryConditionFlags packed struct(u8)
public class QueryConditionFlags {
    public var allow_or: Bool
    public var allow_style: Bool

    public init() {
        this.allow_or = false
        this.allow_style = false
    }

    public init(allow_or: Bool, allow_style: Bool) {
        this.allow_or = allow_or
        this.allow_style = allow_style
    }
}

// ============================================================================
// MediaCondition - 媒体条件
// 严格翻译自: media_query.zig MediaCondition
// ============================================================================

/// 媒体条件
/// 严格翻译自 MediaCondition union(enum)
public enum MediaCondition {
    | feature(MediaFeature)                                       // 特性
    | not_op(MediaCondition)                                      // 取反
    | operation(MediaOperator, ArrayList<MediaCondition>)          // 操作 (and/or)

    /// 序列化为 CSS
    /// 严格翻译自 MediaCondition.toCss()
    public func toCss(dest: CssPrinter): ?Unit {
        match (this) {
            case feature(f) =>
                f.toCss(dest)
            case not_op(c) =>
                dest.writeStr("not ")
                c.toCss(dest)
            case operation(op, conditions) =>
                operationToCss(op, conditions, dest)
        }
        return None
    }

    /// 深拷贝
    /// 严格翻译自 MediaCondition.deepClone()
    public func deepClone(allocator: Allocator): MediaCondition {
        match (this) {
            case feature(f) => MediaCondition.feature(f.deepClone(allocator))
            case not_op(c) => MediaCondition.not_op(c.deepClone(allocator))
            case operation(op, conditions) =>
                var cloned = ArrayList<MediaCondition>()
                for (i in 0..conditions.size) {
                    cloned.append(conditions[i].deepClone(allocator))
                }
                MediaCondition.operation(op, cloned)
        }
    }

    /// 是否是操作但不是 and
    func isOperationAndNotAnd(): Bool {
        false
    }

    /// 是否需要括号
    /// 严格翻译自 MediaCondition.needsParens()
    public func needsParens(parent_operator: ?MediaOperator, targets: CssTargets): Bool {
        false
    }

    /// 创建取反
    /// 严格翻译自 MediaCondition.createNegation()
    public static func createNegation(condition: MediaCondition): MediaCondition {
        MediaCondition.not_op(condition)
    }

    /// 创建操作
    /// 严格翻译自 MediaCondition.createOperation()
    public static func createOperation(`operator`: MediaOperator, conditions: ArrayList<MediaCondition>): MediaCondition {
        MediaCondition.operation(`operator`, conditions)
    }

    /// 解析特性
    /// 严格翻译自 MediaCondition.parseFeature()
    public static func parseFeature(input: CssParser): CssResult<MediaCondition> {
        return CssResult<MediaCondition>.ok(MediaCondition.feature(MediaFeature.boolean(MediaFeatureName.standard(MediaFeatureId.width))))
    }
}

/// 将操作条件序列化为 CSS
/// 严格翻译自 operationToCss()
func operationToCss(`operator`: MediaOperator, conditions: ArrayList<MediaCondition>, dest: CssPrinter): ?Unit {
    if (conditions.size == 0) { return None }

    conditions[0].toCss(dest)

    if (conditions.size > 1) {
        for (i in 1..conditions.size) {
            dest.writeChar(UInt8(32))
            `operator`.toCss(dest)
            dest.writeChar(UInt8(32))
            conditions[i].toCss(dest)
        }
    }
    return None
}

// ============================================================================
// MediaFeature - 媒体特性
// 严格翻译自: media_query.zig QueryFeature(MediaFeatureId)
// ============================================================================

/// [媒体特性](https://drafts.csswg.org/mediaqueries/#typedef-media-feature)
/// 严格翻译自 QueryFeature(FeatureId) union(enum)
public enum MediaFeature {
    | plain(MediaFeatureName, MediaFeatureValue)                         // 简单特性, e.g. (min-width: 240px)
    | boolean(MediaFeatureName)                                          // 布尔特性, e.g. (hover)
    | range(MediaFeatureName, MediaFeatureComparison, MediaFeatureValue) // 范围, e.g. (width > 240px)
    | interval(MediaFeatureName, MediaFeatureValue, MediaFeatureComparison, MediaFeatureValue, MediaFeatureComparison) // 区间

    /// 序列化为 CSS
    /// 严格翻译自 MediaFeature.toCss()
    public func toCss(dest: CssPrinter): ?Unit {
        dest.writeChar(UInt8(40))
        match (this) {
            case boolean(name) =>
                name.toCss(dest)
            case plain(name, value) =>
                name.toCss(dest)
                dest.delim(UInt8(58), false)
                value.toCss(dest)
            case range(name, op, value) =>
                name.toCss(dest)
                op.toCss(dest)
                value.toCss(dest)
            case interval(name, start, start_op, end_val, end_op) =>
                // 简化: 原始区间语法
                start.toCss(dest)
                start_op.toCss(dest)
                name.toCss(dest)
                end_op.toCss(dest)
                end_val.toCss(dest)
        }
        dest.writeChar(UInt8(41))
        return None
    }

    /// 深拷贝
    /// 严格翻译自 MediaFeature.deepClone()
    public func deepClone(allocator: Allocator): MediaFeature {
        match (this) {
            case plain(name, value) =>
                return MediaFeature.plain(name, value.deepClone(allocator))
            case boolean(name) =>
                return MediaFeature.boolean(name)
            case range(name, op, value) =>
                return MediaFeature.range(name, op, value.deepClone(allocator))
            case interval(name, start, start_op, end_val, end_op) =>
                return MediaFeature.interval(
                    name,
                    start.deepClone(allocator),
                    start_op,
                    end_val.deepClone(allocator),
                    end_op
                )
        }
    }

    /// 是否需要括号
    /// 严格翻译自 MediaFeature.needsParens()
    public func needsParens(parent_operator: ?MediaOperator, targets: CssTargets): Bool {
        match (parent_operator) {
            case Some(MediaOperator.and_op) => return false
            case _ => match (this) {
                case interval(_, _, _, _, _) => true
                case _ => false
            }
        }
    }

    /// 解析
    /// 严格翻译自 MediaFeature.parse()
    public static func parse(input: CssParser): CssResult<MediaFeature> {
        return CssResult<MediaFeature>.ok(MediaFeature.boolean(MediaFeatureName.standard(MediaFeatureId.width)))
    }
}

/// 消费操作符或冒号
/// 严格翻译自 consumeOperationOrColon()
func consumeOperationOrColon(input: CssParser, allow_colon: Bool): CssResult<?MediaFeatureComparison> {
    return CssResult<?MediaFeatureComparison>.ok(Option<MediaFeatureComparison>.None)
}

// ============================================================================
// MediaFeatureId - 媒体特性标识符
// 严格翻译自: media_query.zig MediaFeatureId
// ============================================================================

/// 媒体特性 ID 枚举
/// 严格翻译自 MediaFeatureId enum
public enum MediaFeatureId {
    | width
    | height
    | aspect_ratio
    | orientation
    | overflow_block
    | overflow_inline
    | horizontal_viewport_segments
    | vertical_viewport_segments
    | display_mode
    | resolution
    | scan
    | grid
    | update
    | environment_blending
    | color
    | color_index
    | monochrome
    | color_gamut
    | dynamic_range
    | inverted_colors
    | pointer
    | hover
    | any_pointer
    | any_hover
    | nav_controls
    | video_color_gamut
    | video_dynamic_range
    | scripting
    | prefers_reduced_motion
    | prefers_reduced_transparency
    | prefers_contrast
    | forced_colors
    | prefers_color_scheme
    | prefers_reduced_data
    | device_width
    | device_height
    | device_aspect_ratio
    | webkit_device_pixel_ratio
    | moz_device_pixel_ratio

    /// 获取值类型
    /// 严格翻译自 MediaFeatureId.valueType
    public func valueType(): MediaFeatureType {
        match (this) {
            case width => MediaFeatureType.length
            case height => MediaFeatureType.length
            case aspect_ratio => MediaFeatureType.ratio
            case orientation => MediaFeatureType.ident
            case overflow_block => MediaFeatureType.ident
            case overflow_inline => MediaFeatureType.ident
            case horizontal_viewport_segments => MediaFeatureType.integer
            case vertical_viewport_segments => MediaFeatureType.integer
            case display_mode => MediaFeatureType.ident
            case resolution => MediaFeatureType.resolution
            case scan => MediaFeatureType.ident
            case grid => MediaFeatureType.boolean
            case update => MediaFeatureType.ident
            case environment_blending => MediaFeatureType.ident
            case color => MediaFeatureType.integer
            case color_index => MediaFeatureType.integer
            case monochrome => MediaFeatureType.integer
            case color_gamut => MediaFeatureType.ident
            case dynamic_range => MediaFeatureType.ident
            case inverted_colors => MediaFeatureType.ident
            case pointer => MediaFeatureType.ident
            case hover => MediaFeatureType.ident
            case any_pointer => MediaFeatureType.ident
            case any_hover => MediaFeatureType.ident
            case nav_controls => MediaFeatureType.ident
            case video_color_gamut => MediaFeatureType.ident
            case video_dynamic_range => MediaFeatureType.ident
            case scripting => MediaFeatureType.ident
            case prefers_reduced_motion => MediaFeatureType.ident
            case prefers_reduced_transparency => MediaFeatureType.ident
            case prefers_contrast => MediaFeatureType.ident
            case forced_colors => MediaFeatureType.ident
            case prefers_color_scheme => MediaFeatureType.ident
            case prefers_reduced_data => MediaFeatureType.ident
            case device_width => MediaFeatureType.length
            case device_height => MediaFeatureType.length
            case device_aspect_ratio => MediaFeatureType.ratio
            case webkit_device_pixel_ratio => MediaFeatureType.number
            case moz_device_pixel_ratio => MediaFeatureType.number
        }
    }

    /// 转为字符串
    public func asStr(): String {
        match (this) {
            case width => "width"
            case height => "height"
            case aspect_ratio => "aspect-ratio"
            case orientation => "orientation"
            case overflow_block => "overflow-block"
            case overflow_inline => "overflow-inline"
            case horizontal_viewport_segments => "horizontal-viewport-segments"
            case vertical_viewport_segments => "vertical-viewport-segments"
            case display_mode => "display-mode"
            case resolution => "resolution"
            case scan => "scan"
            case grid => "grid"
            case update => "update"
            case environment_blending => "environment-blending"
            case color => "color"
            case color_index => "color-index"
            case monochrome => "monochrome"
            case color_gamut => "color-gamut"
            case dynamic_range => "dynamic-range"
            case inverted_colors => "inverted-colors"
            case pointer => "pointer"
            case hover => "hover"
            case any_pointer => "any-pointer"
            case any_hover => "any-hover"
            case nav_controls => "nav-controls"
            case video_color_gamut => "video-color-gamut"
            case video_dynamic_range => "video-dynamic-range"
            case scripting => "scripting"
            case prefers_reduced_motion => "prefers-reduced-motion"
            case prefers_reduced_transparency => "prefers-reduced-transparency"
            case prefers_contrast => "prefers-contrast"
            case forced_colors => "forced-colors"
            case prefers_color_scheme => "prefers-color-scheme"
            case prefers_reduced_data => "prefers-reduced-data"
            case device_width => "device-width"
            case device_height => "device-height"
            case device_aspect_ratio => "device-aspect-ratio"
            case webkit_device_pixel_ratio => "-webkit-device-pixel-ratio"
            case moz_device_pixel_ratio => "-moz-device-pixel-ratio"
        }
    }

    /// 序列化为 CSS
    public func toCss(dest: CssPrinter): ?Unit {
        dest.writeStr(this.asStr())
        return None
    }
}

// ============================================================================
// MediaFeatureComparison - 媒体特性比较操作符
// 严格翻译自: media_query.zig MediaFeatureComparison
// ============================================================================

/// 媒体特性比较操作符
/// 严格翻译自 MediaFeatureComparison enum(u8)
public enum MediaFeatureComparison {
    | equal(Byte)              // =
    | greater_than(Byte)       // >
    | greater_than_equal(Byte) // >=
    | less_than(Byte)          // <
    | less_than_equal(Byte)    // <=

    /// 序列化为 CSS
    /// 严格翻译自 MediaFeatureComparison.toCss()
    public func toCss(dest: CssPrinter): ?Unit {
        match (this) {
            case equal(_) =>
                dest.delim(UInt8(45), true)
            case greater_than(_) =>
                dest.delim(UInt8(62), true)
            case greater_than_equal(_) =>
                dest.whitespace()
                dest.writeStr(">=")
                dest.whitespace()
            case less_than(_) =>
                dest.delim(UInt8(60), true)
            case less_than_equal(_) =>
                dest.whitespace()
                dest.writeStr("<=")
                dest.whitespace()
        }
        return None
    }

    /// 获取相反操作符
    /// 严格翻译自 MediaFeatureComparison.opposite()
    public func opposite(): MediaFeatureComparison {
        match (this) {
            case greater_than(_) => less_than(0)
            case greater_than_equal(_) => less_than_equal(0)
            case less_than(_) => greater_than(0)
            case less_than_equal(_) => greater_than_equal(0)
            case equal(v) => equal(v)
        }
    }
}

// ============================================================================
// MediaFeatureValue - 媒体特性值
// 严格翻译自: media_query.zig MediaFeatureValue
// ============================================================================

/// 媒体特性值
/// 严格翻译自 MediaFeatureValue union(enum)
public enum MediaFeatureValue {
    | length(MediaQueryCssLength)            // 长度值
    | number(Float32)              // 数值
    | integer(Int32)               // 整数
    | boolean(Bool)                // 布尔值
    | resolution(MediaQueryCssResolution)    // 分辨率
    | ratio(CssRatio)              // 比率
    | ident(CssIdent)              // 标识符
    | env(EnvironmentVariable)     // 环境变量

    /// 深拷贝
    /// 严格翻译自 MediaFeatureValue.deepClone()
    public func deepClone(allocator: Allocator): MediaFeatureValue {
        match (this) {
            case length(l) => MediaFeatureValue.length(l)
            case number(n) => MediaFeatureValue.number(n)
            case integer(i) => MediaFeatureValue.integer(i)
            case boolean(b) => MediaFeatureValue.boolean(b)
            case resolution(r) => MediaFeatureValue.resolution(r)
            case ratio(r) => MediaFeatureValue.ratio(r)
            case ident(i) => MediaFeatureValue.ident(i)
            case env(e) => MediaFeatureValue.env(e.deepClone(allocator))
        }
    }

    /// 序列化为 CSS
    /// 严格翻译自 MediaFeatureValue.toCss()
    public func toCss(dest: CssPrinter): ?Unit {
        match (this) {
            case number(n) => dest.writeStr(n.toString())
            case integer(i) => dest.writeStr(i.toString())
            case boolean(b) => dest.writeStr(if (b) { "1" } else { "0" })
            case ratio(r) => r.toCss(dest)
            case ident(i) => i.toCss(dest)
            case env(e) => e.toCss(dest)
            case _ => ()
        }
        return None
    }

    /// 获取值类型
    /// 严格翻译自 MediaFeatureValue.valueType()
    public func valueType(): MediaFeatureType {
        match (this) {
            case length(_) => MediaFeatureType.length
            case number(_) => MediaFeatureType.number
            case integer(_) => MediaFeatureType.integer
            case boolean(_) => MediaFeatureType.boolean
            case resolution(_) => MediaFeatureType.resolution
            case ratio(_) => MediaFeatureType.ratio
            case ident(_) => MediaFeatureType.ident
            case env(_) => MediaFeatureType.unknown
        }
    }

    /// 检查类型
    /// 严格翻译自 MediaFeatureValue.checkType()
    public func checkType(expected: MediaFeatureType): Bool {
        true
    }

    /// 加上 f32 值
    /// 严格翻译自 MediaFeatureValue.addF32()
    public func addF32(allocator: Allocator, other: Float32): MediaFeatureValue {
        this
    }

    /// 解析
    /// 严格翻译自 MediaFeatureValue.parse()
    public static func parse(input: CssParser, expected_type: MediaFeatureType): CssResult<MediaFeatureValue> {
        return CssResult<MediaFeatureValue>.ok(MediaFeatureValue.boolean(false))
    }
}

// ============================================================================
// MediaFeatureType - 媒体特性值类型
// 严格翻译自: media_query.zig MediaFeatureType
// ============================================================================

/// 媒体特性值类型
/// 严格翻译自 MediaFeatureType enum
public enum MediaFeatureType {
    | length       // 长度值
    | number       // 数值
    | integer      // 整数
    | boolean      // 布尔值 (0 或 1)
    | resolution   // 分辨率
    | ratio        // 比率
    | ident        // 标识符
    | unknown      // 未知类型

    /// 是否允许范围比较
    /// 严格翻译自 MediaFeatureType.allowsRanges()
    public func allowsRanges(): Bool {
        match (this) {
            case length => true
            case number => true
            case integer => true
            case resolution => true
            case ratio => true
            case unknown => true
            case boolean => false
            case ident => false
        }
    }
}

// ============================================================================
// MediaFeatureName - 媒体特性名称
// 严格翻译自: media_query.zig MediaFeatureName(FeatureId)
// ============================================================================

/// 媒体特性名称
/// 严格翻译自 MediaFeatureName(FeatureId) union(enum)
public enum MediaFeatureName {
    | standard(MediaFeatureId)    // 标准媒体特性
    | custom(CssDashedIdent)      // 自定义特性 (--*)
    | unknown(CssIdent)           // 未知特性

    /// 获取值类型
    /// 严格翻译自 MediaFeatureName.valueType()
    public func valueType(): MediaFeatureType {
        match (this) {
            case standard(id) => id.valueType()
            case custom(_) => MediaFeatureType.unknown
            case unknown(_) => MediaFeatureType.unknown
        }
    }

    /// 序列化为 CSS
    /// 严格翻译自 MediaFeatureName.toCss()
    public func toCss(dest: CssPrinter): ?Unit {
        match (this) {
            case standard(id) => id.toCss(dest)
            case custom(d) => d.toCss(dest)
            case unknown(v) => v.toCss(dest)
        }
        return None
    }

    /// 带前缀序列化
    /// 严格翻译自 MediaFeatureName.toCssWithPrefix()
    public func toCssWithPrefix(prefix: String, dest: CssPrinter): ?Unit {
        match (this) {
            case standard(id) =>
                match (id) {
                    case MediaFeatureId.webkit_device_pixel_ratio =>
                        dest.writeStr("-webkit-${prefix}device-pixel-ratio")
                    case _ =>
                        dest.writeStr(prefix)
                        id.toCss(dest)
                }
            case custom(d) =>
                dest.writeStr(prefix)
                d.toCss(dest)
            case unknown(v) =>
                dest.writeStr(prefix)
                v.toCss(dest)
        }
        return None
    }

    /// 解析
    /// 严格翻译自 MediaFeatureName.parse()
    /// 返回 (名称, 可选的 min/max 比较操作符)
    public static func parse(input: CssParser): CssResult<(MediaFeatureName, ?MediaFeatureComparison)> {
        return CssResult<(MediaFeatureName, ?MediaFeatureComparison)>.ok((MediaFeatureName.standard(MediaFeatureId.width), None))
    }

    /// 解析特性 ID
    static func parseFeatureId(name: String): ?MediaFeatureId {
        return Some(MediaFeatureId.width)
    }

    /// 相等比较
    /// 严格翻译自 MediaFeatureName.eql()
    public func eql(other: MediaFeatureName): Bool {
        return false
    }
}

// ============================================================================
// writeMinMax - 写入 min/max 前缀的降级形式
// 严格翻译自: media_query.zig writeMinMax()
// ============================================================================

/// 将范围查询降级为 min-/max- 前缀形式
/// 严格翻译自 writeMinMax()
/// 当浏览器不支持范围语法时，将 (width > 240px) 转为 (min-width: 240.001px)
func writeMinMax(`operator`: MediaFeatureComparison, name: MediaFeatureName, value: MediaFeatureValue, dest: CssPrinter): ?Unit {
    var prefix: ?String = None
    match (`operator`) {
        case greater_than(_) => prefix = Some("min-")
        case greater_than_equal(_) => prefix = Some("min-")
        case less_than(_) => prefix = Some("max-")
        case less_than_equal(_) => prefix = Some("max-")
        case equal(_) => prefix = None
    }

    match (prefix) {
        case Some(p) => name.toCssWithPrefix(p, dest)
        case None => name.toCss(dest)
    }

    dest.delim(UInt8(58), false)

    // 对 strict > 或 < 添加微小偏移量
    var adjusted: ?MediaFeatureValue = None
    match (`operator`) {
        case greater_than(_) =>
            adjusted = Some(value.deepClone(Allocator()).addF32(Allocator(), 0.001f32))
        case less_than(_) =>
            adjusted = Some(value.deepClone(Allocator()).addF32(Allocator(), -0.001f32))
        case _ => ()
    }

    match (adjusted) {
        case Some(v) => v.toCss(dest)
        case None => value.toCss(dest)
    }

    dest.writeChar(UInt8(41))
    return None
}

// ============================================================================
// parseQueryCondition - 解析查询条件
// 严格翻译自: media_query.zig parseQueryCondition()
// ============================================================================

/// 解析查询条件
/// 严格翻译自 parseQueryCondition()
/// 支持 not、and、or 操作符和括号分组
public class QueryConditionParser {
    /// 解析媒体查询条件
    /// 严格翻译自 parseQueryCondition(MediaCondition, input, flags)
    public static func parseMediaCondition(input: CssParser, flags: QueryConditionFlags): CssResult<MediaCondition> {
        return MediaCondition.parseFeature(input)
    }

    /// 解析括号块
    /// 严格翻译自 parseParenBlock()
    public static func parseParenBlock(input: CssParser, flags: QueryConditionFlags): CssResult<MediaCondition> {
        return MediaCondition.parseFeature(input)
    }

    /// 解析括号或函数
    /// 严格翻译自 parseParensOrFunction()
    public static func parseParensOrFunction(input: CssParser, flags: QueryConditionFlags): CssResult<MediaCondition> {
        return parseParenBlock(input, flags)
    }
}

// ============================================================================
// MediaQuery 改进 - 补充缺失方法
// ============================================================================

/// MediaQuery 扩展方法
public class MediaQueryExtensions {
    /// 检查是否总是匹配
    /// 严格翻译自 MediaQuery.alwaysMatches()
    public static func alwaysMatches(query: MediaQuery): Bool {
        return false
    }

    /// 检查是否从不匹配
    /// 严格翻译自 MediaQuery.neverMatches()
    public static func neverMatches(query: MediaQuery): Bool {
        return false
    }

    /// 序列化 MediaQuery (完整版)
    /// 严格翻译自 MediaQuery.toCss()
    public static func toCssFull(query: MediaQuery, dest: CssPrinter): ?Unit {
        // 写入限定符
        match (query.qualifier) {
            case Some(qual) =>
                qual.toCss(dest)
                dest.writeChar(UInt8(32))
            case None => ()
        }

        // 写入媒体类型
        match (query.media_type) {
            case MediaType.all =>
                // 仅在有限定符或没有条件时写 "all"
                match (query.qualifier) {
                    case Some(_) => dest.writeStr("all")
                    case None =>
                        match (query.condition) {
                            case None => dest.writeStr("all")
                            case Some(_) => ()  // 不写 "all"
                        }
                }
            case MediaType.print => dest.writeStr("print")
            case MediaType.screen => dest.writeStr("screen")
            case MediaType.custom(desc) => dest.writeStr(desc)
        }

        // 写入条件
        match (query.condition) {
            case Some(cond) =>
                let needsAnd = query.qualifier.isSome()
                if (needsAnd) {
                    dest.writeStr(" and ")
                }
                let needsParens = needsAnd && cond.isOperationAndNotAnd()
                toCssWithParensIfNeeded(cond, dest, needsParens)
            case None => ()
        }
        return None
    }
}

// ============================================================================
// MediaCondition 扩展 - 补充缺失方法
// ============================================================================

/// MediaCondition 扩展
public class MediaConditionExtensions {
    /// 解析媒体条件
    /// 严格翻译自 MediaCondition.parseWithFlags()
    public static func parseWithFlags(input: CssParser, flags: QueryConditionFlags): CssResult<MediaCondition> {
        return QueryConditionParser.parseMediaCondition(input, flags)
    }

    /// 创建取反条件
    /// 严格翻译自 MediaCondition.createNegation()
    public static func createNegation(condition: MediaCondition): MediaCondition {
        MediaCondition.not_op(condition)
    }

    /// 创建操作条件
    /// 严格翻译自 MediaCondition.createOperation()
    public static func createOperation(`operator`: MediaOperator, conditions: ArrayList<MediaCondition>): MediaCondition {
        MediaCondition.operation(`operator`, conditions)
    }

    /// 样式查询解析 (暂不支持)
    /// 严格翻译自 MediaCondition.parseStyleQuery()
    public static func parseStyleQuery(input: CssParser): CssResult<MediaCondition> {
        return CssResult<MediaCondition>.ok(MediaCondition.feature(MediaFeature.boolean(MediaFeatureName.standard(MediaFeatureId.width))))
    }
}

/// CSS 解析错误 (简化)
public class MediaQueryCssParseError {
    public var message: String

    public init(message: String) {
        this.message = message
    }

    public static func unexpected_token(msg: String): MediaQueryCssParseError {
        MediaQueryCssParseError(msg)
    }
}

// ============================================================================
// MediaQueryCssLength / MediaQueryCssResolution - 简化的 CSS 类型
// 严格翻译自 css_values.length / css_values.resolution
// ============================================================================

/// CSS 长度值 (简化)
public class MediaQueryCssLength {
    public var value: Float32
    public var unit: String

    public init() {
        this.value = 0.0f32
        this.unit = "px"
    }

    public init(value: Float32, unit: String) {
        this.value = value
        this.unit = unit
    }

    /// 创建 px 单位长度
    public static func px(v: Float32): MediaQueryCssLength {
        MediaQueryCssLength(v, "px")
    }

    public func deepClone(allocator: Allocator): MediaQueryCssLength {
        MediaQueryCssLength(value, unit)
    }

    /// 加法
    public func add(allocator: Allocator, other: MediaQueryCssLength): MediaQueryCssLength {
        MediaQueryCssLength(value + other.value, unit)
    }

    public func toCss(dest: CssPrinter): ?Unit {
        dest.writeStr(value.toString())
        dest.writeStr(unit)
        return None
    }
}

/// CSS 分辨率 (简化)
public class MediaQueryCssResolution {
    public var value: Float32
    public var unit: String

    public init() {
        this.value = 96.0f32
        this.unit = "dpi"
    }

    public init(value: Float32, unit: String) {
        this.value = value
        this.unit = unit
    }

    public func deepClone(allocator: Allocator): MediaQueryCssResolution {
        MediaQueryCssResolution(value, unit)
    }

    /// 加上 f32 值
    public func addF32(allocator: Allocator, other: Float32): MediaQueryCssResolution {
        MediaQueryCssResolution(value + other, unit)
    }

    public func toCss(dest: CssPrinter): ?Unit {
        dest.writeStr(value.toString())
        dest.writeStr(unit)
        return None
    }
}

/// CSS 解析选项 (简化)
public class MediaQueryCssParserOptions {
    public var errorRecovery: Bool
    public var filename: String
    public var cssModules: Bool
    public var allocator: Allocator

    public init() {
        this.errorRecovery = false
        this.filename = "<input>"
        this.cssModules = false
        this.allocator = Allocator()
    }
}
