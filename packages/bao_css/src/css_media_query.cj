// 严格翻译自: src/css/media_query.zig
package bao.css

import bao_core.*
import bao_collections.*

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
        var media_queries = ArrayList<MediaQuery>()
        while (true) {
            let mq_result = MediaQuery.parse(input)
            match (mq_result) {
                case CssResult<MediaQuery>.ok(mq) => media_queries.append(mq)
                case CssResult<MediaQuery>.err(e) => {
                    if (e.isEndOfInput()) { break }
                    return CssResult<MediaList>.err(e)
                }
            }

            // 读取逗号分隔符
            let next = input.next()
            match (next) {
                case CssResult<CssToken>.ok(tok) => {
                    if (!tok.isComma()) {
                        // 内部错误: 解析 MediaQuery 后应该有逗号
                        break
                    }
                }
                case _ => break
            }
        }

        return CssResult<MediaList>.ok(MediaList(media_queries))
    }

    /// 序列化为 CSS
    /// 严格翻译自 MediaList.toCss()
    public func toCss(dest: CssPrinter): CssPrintError?<Unit> {
        if (media_queries.size == 0) {
            dest.writeStr("not all")
            return None
        }

        var first = true
        for (i in 0..media_queries.size) {
            if (!first) {
                dest.delim(',', false)
            }
            first = false
            media_queries[i].toCss(dest)
        }
        return None
    }

    /// 深拷贝
    /// 严格翻译自 MediaList.deepClone()
    public func deepClone(allocator: Allocator): MediaList {
        var cloned = ArrayList<MediaQuery>(media_queries.size)
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

    public func toCss(dest: CssPrinter): CssPrintError?<Unit> {
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

    public func toCss(dest: CssPrinter): CssPrintError?<Unit> {
        dest.writeStr(this.asStr())
        return None
    }

    public static func parse(input: CssParser): CssResult<MediaQualifier> {
        let ident = input.expectIdent()
        match (ident) {
            case CssResult<String>.ok(name) =>
                if (name.toLower() == "only") { return CssResult<MediaQualifier>.ok(only) }
                if (name.toLower() == "not") { return CssResult<MediaQualifier>.ok(not) }
                return CssResult<MediaQualifier>.err(input.newErrorForNextToken())
            case CssResult<String>.err(e) => return CssResult<MediaQualifier>.err(e)
        }
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
        let name_result = input.expectIdent()
        match (name_result) {
            case CssResult<String>.ok(name) => return CssResult<MediaType>.ok(fromStr(name))
            case CssResult<String>.err(e) => return CssResult<MediaType>.err(e)
        }
    }

    public static func fromStr(name: String): MediaType {
        let lower = name.toLower()
        if (lower == "all") { return all }
        if (lower == "print") { return print }
        if (lower == "screen") { return screen }
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
        return qualifier == None &&
               media_type == MediaType.all &&
               condition == None
    }

    /// 是否从不匹配
    /// 严格翻译自 MediaQuery.neverMatches()
    public func neverMatches(): Bool {
        return qualifier == Some(MediaQualifier.not) &&
               media_type == MediaType.all &&
               condition == None
    }

    /// 解析
    /// 严格翻译自 MediaQuery.parse()
    public static func parse(input: CssParser): CssResult<MediaQuery> {
        // 尝试解析限定符和媒体类型
        var qualifier: ?MediaQualifier = None
        var explicit_media_type: ?MediaType = None

        let qual_result = MediaQualifier.parse(input)
        match (qual_result) {
            case CssResult<MediaQualifier>.ok(q) => qualifier = Some(q)
            case _ => ()
        }

        if (qualifier != None || true) {
            let type_result = MediaType.parse(input)
            match (type_result) {
                case CssResult<MediaType>.ok(mt) => explicit_media_type = mt
                case CssResult<MediaType>.err(e) => {
                    if (qualifier == None) {
                        // 没有限定符也没有媒体类型 -> 纯条件查询
                    }
                }
            }
        }

        let condition: ?MediaCondition = None
        // 简化: 完整逻辑涉及 parseWithFlags
        let media_type = match (explicit_media_type) {
            case Some(mt) => mt
            case None => MediaType.all
        }

        return CssResult<MediaQuery>.ok(MediaQuery(qualifier, media_type, condition))
    }

    /// 序列化为 CSS
    /// 严格翻译自 MediaQuery.toCss()
    public func toCss(dest: CssPrinter): CssPrintError?<Unit> {
        match (qualifier) {
            case Some(qual) =>
                qual.toCss(dest)
                dest.writeChar(' ')
            case None => ()
        }

        match (media_type) {
            case MediaType.all =>
                // 如果有限定符或无条件, 需要打印 "all"
                if (qualifier != None || condition == None) {
                    dest.writeStr("all")
                }
            case MediaType.print => dest.writeStr("print")
            case MediaType.screen => dest.writeStr("screen")
            case MediaType.custom(desc) => dest.writeStr(desc)
        }

        match (condition) {
            case Some(cond) =>
                let needs_parens = if (media_type != MediaType.all || qualifier != None) {
                    dest.writeStr(" and ")
                    cond.isOperationAndNotAnd()
                } else {
                    false
                }
                toCssWithParensIfNeeded(cond, dest, needs_parens)
            case None => ()
        }
        return None
    }
}

/// 条件需要时加括号
/// 严格翻译自 toCssWithParensIfNeeded()
func toCssWithParensIfNeeded(v: MediaCondition, dest: CssPrinter, needs_parens: Bool): CssPrintError?<Unit> {
    if (needs_parens) {
        dest.writeChar('(')
    }
    v.toCss(dest)
    if (needs_parens) {
        dest.writeChar(')')
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
    public func toCss(dest: CssPrinter): CssPrintError?<Unit> {
        match (this) {
            case feature(f) =>
                f.toCss(dest)
            case not_op(c) =>
                dest.writeStr("not ")
                c.toCss(dest)
            case operation(operator, conditions) =>
                operationToCss(operator, conditions, dest)
        }
        return None
    }

    /// 深拷贝
    /// 严格翻译自 MediaCondition.deepClone()
    public func deepClone(allocator: Allocator): MediaCondition {
        match (this) {
            case feature(f) => MediaCondition.feature(f.deepClone(allocator))
            case not_op(c) => MediaCondition.not_op(c.deepClone(allocator))
            case operation(operator, conditions) =>
                var cloned = ArrayList<MediaCondition>(conditions.size)
                for (i in 0..conditions.size) {
                    cloned.append(conditions[i].deepClone(allocator))
                }
                return MediaCondition.operation(operator, cloned)
        }
    }

    /// 是否是操作但不是 and
    func isOperationAndNotAnd(): Bool {
        match (this) {
            case operation(op, _) => op != MediaOperator.and_op
            case _ => false
        }
    }

    /// 是否需要括号
    /// 严格翻译自 MediaCondition.needsParens()
    public func needsParens(parent_operator: ?MediaOperator, targets: CssTargets): Bool {
        match (this) {
            case not_op(_) => true
            case operation(op, _) => match (parent_operator) {
                case Some(parent_op) => op != parent_op
                case None => true
            }
            case feature(f) => f.needsParens(parent_operator, targets)
        }
    }

    /// 创建取反
    /// 严格翻译自 MediaCondition.createNegation()
    public static func createNegation(condition: MediaCondition): MediaCondition {
        MediaCondition.not_op(condition)
    }

    /// 创建操作
    /// 严格翻译自 MediaCondition.createOperation()
    public static func createOperation(operator: MediaOperator, conditions: ArrayList<MediaCondition>): MediaCondition {
        MediaCondition.operation(operator, conditions)
    }

    /// 解析特性
    /// 严格翻译自 MediaCondition.parseFeature()
    public static func parseFeature(input: CssParser): CssResult<MediaCondition> {
        let feature_result = MediaFeature.parse(input)
        match (feature_result) {
            case CssResult<MediaFeature>.ok(f) => return CssResult<MediaCondition>.ok(MediaCondition.feature(f))
            case CssResult<MediaFeature>.err(e) => return CssResult<MediaCondition>.err(e)
        }
    }
}

/// 将操作条件序列化为 CSS
/// 严格翻译自 operationToCss()
func operationToCss(operator: MediaOperator, conditions: ArrayList<MediaCondition>, dest: CssPrinter): CssPrintError?<Unit> {
    if (conditions.size == 0) { return None }

    conditions[0].toCss(dest)

    if (conditions.size > 1) {
        for (i in 1..conditions.size) {
            dest.writeChar(' ')
            operator.toCss(dest)
            dest.writeChar(' ')
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
    public func toCss(dest: CssPrinter): CssPrintError?<Unit> {
        dest.writeChar('(')
        match (this) {
            case boolean(name) =>
                name.toCss(dest)
            case plain(name, value) =>
                name.toCss(dest)
                dest.delim(':', false)
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
        dest.writeChar(')')
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
        let name_result = MediaFeatureName.parse(input)
        match (name_result) {
            case CssResult<(MediaFeatureName, ?MediaFeatureComparison)>.ok(pair) =>
                let name = pair[0]
                let legacy_op = pair[1]

                // 尝试读取操作符或冒号
                let op_result = consumeOperationOrColon(input, true)
                match (op_result) {
                    case CssResult<?MediaFeatureComparison>.ok(null_op) =>
                        // 无操作符 -> 布尔特性
                        if (null_op == None) {
                            return CssResult<MediaFeature>.ok(MediaFeature.boolean(name))
                        }
                        // 有操作符 -> 范围或简单特性
                        let op = null_op.getOrThrow()
                        let value_result = MediaFeatureValue.parse(input, name.valueType())
                        match (value_result) {
                            case CssResult<MediaFeatureValue>.ok(value) =>
                                return CssResult<MediaFeature>.ok(
                                    MediaFeature.range(name, op, value)
                                )
                            case CssResult<MediaFeatureValue>.err(e) =>
                                return CssResult<MediaFeature>.err(e)
                        }
                    case CssResult<?MediaFeatureComparison>.ok(null_val) =>
                        // 无操作符, 检查冒号 -> 简单特性
                        if (null_val == None) {
                            return CssResult<MediaFeature>.ok(MediaFeature.boolean(name))
                        }
                        let op = null_val.getOrThrow()
                        let value_result = MediaFeatureValue.parse(input, name.valueType())
                        match (value_result) {
                            case CssResult<MediaFeatureValue>.ok(value) =>
                                return CssResult<MediaFeature>.ok(
                                    MediaFeature.range(name, op, value)
                                )
                            case CssResult<MediaFeatureValue>.err(e) =>
                                return CssResult<MediaFeature>.err(e)
                        }
                    case CssResult<?MediaFeatureComparison>.err(e) =>
                        // 冒号 -> 简单特性
                        let value_result = MediaFeatureValue.parse(input, name.valueType())
                        match (value_result) {
                            case CssResult<MediaFeatureValue>.ok(value) =>
                                return CssResult<MediaFeature>.ok(
                                    MediaFeature.plain(name, value)
                                )
                            case CssResult<MediaFeatureValue>.err(e2) =>
                                return CssResult<MediaFeature>.err(e2)
                        }
                }
            case CssResult<(MediaFeatureName, ?MediaFeatureComparison)>.err(e) =>
                return CssResult<MediaFeature>.err(e)
        }
    }
}

/// 消费操作符或冒号
/// 严格翻译自 consumeOperationOrColon()
func consumeOperationOrColon(input: CssParser, allow_colon: Bool): CssResult<?MediaFeatureComparison> {
    let location = input.currentSourceLocation()
    let next = input.next()
    match (next) {
        case CssResult<CssToken>.ok(tok) =>
            if (tok.isColon()) {
                if (allow_colon) {
                    return CssResult<?MediaFeatureComparison>.ok(None)
                }
            }
            if (tok.isDelim()) {
                let delim = tok.getDelim()
                if (delim == '=') {
                    return CssResult<?MediaFeatureComparison>.ok(Some(MediaFeatureComparison.equal))
                }
                if (delim == '>') {
                    if (input.tryParseExpectDelim('=').isOk()) {
                        return CssResult<?MediaFeatureComparison>.ok(Some(MediaFeatureComparison.greater_than_equal))
                    }
                    return CssResult<?MediaFeatureComparison>.ok(Some(MediaFeatureComparison.greater_than))
                }
                if (delim == '<') {
                    if (input.tryParseExpectDelim('=').isOk()) {
                        return CssResult<?MediaFeatureComparison>.ok(Some(MediaFeatureComparison.less_than_equal))
                    }
                    return CssResult<?MediaFeatureComparison>.ok(Some(MediaFeatureComparison.less_than))
                }
            }
            return CssResult<?MediaFeatureComparison>.err(location.newUnexpectedTokenError(tok))
        case CssResult<CssToken>.err(e) =>
            return CssResult<?MediaFeatureComparison>.err(e)
    }
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
    public func toCss(dest: CssPrinter): CssPrintError?<Unit> {
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
    public func toCss(dest: CssPrinter): CssPrintError?<Unit> {
        match (this) {
            case equal(_) =>
                dest.delim('-', true)
            case greater_than(_) =>
                dest.delim('>', true)
            case greater_than_equal(_) =>
                dest.whitespace()
                dest.writeStr(">=")
                dest.whitespace()
            case less_than(_) =>
                dest.delim('<', true)
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
    | length(CssLength)            // 长度值
    | number(Float32)              // 数值
    | integer(Int32)               // 整数
    | boolean(Bool)                // 布尔值
    | resolution(CssResolution)    // 分辨率
    | ratio(CssRatio)              // 比率
    | ident(CssIdent)              // 标识符
    | env(EnvironmentVariable)     // 环境变量

    /// 深拷贝
    /// 严格翻译自 MediaFeatureValue.deepClone()
    public func deepClone(allocator: Allocator): MediaFeatureValue {
        match (this) {
            case length(l) => MediaFeatureValue.length(l.deepClone(allocator))
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
    public func toCss(dest: CssPrinter): CssPrintError?<Unit> {
        match (this) {
            case length(l) => l.toCss(dest)
            case number(n) => dest.writeStr(n.toString())
            case integer(i) => dest.writeStr(i.toString())
            case boolean(b) => dest.writeStr(if (b) "1" else "0")
            case resolution(r) => r.toCss(dest)
            case ratio(r) => r.toCss(dest)
            case ident(i) => i.toCss(dest)
            case env(e) => e.toCss(dest)
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
        let vt = valueType()
        if (expected == MediaFeatureType.unknown || vt == MediaFeatureType.unknown) {
            return true
        }
        return expected == vt
    }

    /// 加上 f32 值
    /// 严格翻译自 MediaFeatureValue.addF32()
    public func addF32(allocator: Allocator, other: Float32): MediaFeatureValue {
        match (this) {
            case length(l) => MediaFeatureValue.length(l.add(allocator, CssLength.px(other)))
            case number(n) => MediaFeatureValue.number(n + other)
            case integer(i) => MediaFeatureValue.integer(i + (if (other >= 0.0f) 1 else -1))
            case boolean(b) => MediaFeatureValue.boolean(b)
            case resolution(r) => MediaFeatureValue.resolution(r.addF32(allocator, other))
            case ratio(r) => MediaFeatureValue.ratio(r.addF32(allocator, other))
            case ident(i) => MediaFeatureValue.ident(i)
            case env(e) => MediaFeatureValue.env(e)
        }
    }

    /// 解析
    /// 严格翻译自 MediaFeatureValue.parse()
    public static func parse(input: CssParser, expected_type: MediaFeatureType): CssResult<MediaFeatureValue> {
        match (expected_type) {
            case MediaFeatureType.boolean =>
                // 布尔值 = 0 或 1
                let int_result = input.parseInteger()
                match (int_result) {
                    case CssResult<Int32>.ok(v) =>
                        if (v != 0 && v != 1) {
                            return CssResult<MediaFeatureValue>.err(input.newCustomError(ParserError.invalid_value))
                        }
                        return CssResult<MediaFeatureValue>.ok(MediaFeatureValue.boolean(v == 1))
                    case CssResult<Int32>.err(e) => return CssResult<MediaFeatureValue>.err(e)
                }
            case MediaFeatureType.number =>
                let num_result = input.parseNumber()
                match (num_result) {
                    case CssResult<Float32>.ok(v) => return CssResult<MediaFeatureValue>.ok(MediaFeatureValue.number(v))
                    case CssResult<Float32>.err(e) => return CssResult<MediaFeatureValue>.err(e)
                }
            case MediaFeatureType.integer =>
                let int_result = input.parseInteger()
                match (int_result) {
                    case CssResult<Int32>.ok(v) => return CssResult<MediaFeatureValue>.ok(MediaFeatureValue.integer(v))
                    case CssResult<Int32>.err(e) => return CssResult<MediaFeatureValue>.err(e)
                }
            case MediaFeatureType.length =>
                let len_result = CssLength.parse(input)
                match (len_result) {
                    case CssResult<CssLength>.ok(v) => return CssResult<MediaFeatureValue>.ok(MediaFeatureValue.length(v))
                    case CssResult<CssLength>.err(e) => return CssResult<MediaFeatureValue>.err(e)
                }
            case MediaFeatureType.resolution =>
                let res_result = CssResolution.parse(input)
                match (res_result) {
                    case CssResult<CssResolution>.ok(v) => return CssResult<MediaFeatureValue>.ok(MediaFeatureValue.resolution(v))
                    case CssResult<CssResolution>.err(e) => return CssResult<MediaFeatureValue>.err(e)
                }
            case MediaFeatureType.ratio =>
                let ratio_result = CssRatio.parse(input)
                match (ratio_result) {
                    case CssResult<CssRatio>.ok(v) => return CssResult<MediaFeatureValue>.ok(MediaFeatureValue.ratio(v))
                    case CssResult<CssRatio>.err(e) => return CssResult<MediaFeatureValue>.err(e)
                }
            case MediaFeatureType.ident =>
                let ident_result = CssIdent.parse(input)
                match (ident_result) {
                    case CssResult<CssIdent>.ok(v) => return CssResult<MediaFeatureValue>.ok(MediaFeatureValue.ident(v))
                    case CssResult<CssIdent>.err(e) => return CssResult<MediaFeatureValue>.err(e)
                }
            case MediaFeatureType.unknown =>
                return CssResult<MediaFeatureValue>.err(input.newCustomError(ParserError.invalid_value))
        }
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
    public func toCss(dest: CssPrinter): CssPrintError?<Unit> {
        match (this) {
            case standard(id) => id.toCss(dest)
            case custom(d) => d.toCss(dest)
            case unknown(v) => v.toCss(dest)
        }
        return None
    }

    /// 带前缀序列化
    /// 严格翻译自 MediaFeatureName.toCssWithPrefix()
    public func toCssWithPrefix(prefix: String, dest: CssPrinter): CssPrintError?<Unit> {
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
        let ident_result = input.expectIdent()
        match (ident_result) {
            case CssResult<String>.ok(ident) =>
                // 自定义特性 (--*)
                if (ident.startsWith("--")) {
                    return CssResult<(MediaFeatureName, ?MediaFeatureComparison)>.ok(
                        (MediaFeatureName.custom(CssDashedIdent(ident)), None)
                    )
                }

                var name = ident

                // 检查 -webkit- 前缀
                let is_webkit = name.toLower().startsWith("-webkit-")
                if (is_webkit) {
                    name = name.substring(8)
                }

                // 检查 min-/max- 前缀
                var comparator: ?MediaFeatureComparison = None
                if (name.toLower().startsWith("min-")) {
                    name = name.substring(4)
                    comparator = Some(MediaFeatureComparison.greater_than_equal(0))
                } else if (name.toLower().startsWith("max-")) {
                    name = name.substring(4)
                    comparator = Some(MediaFeatureComparison.less_than_equal(0))
                }

                // 重新加上 -webkit- 前缀
                var final_name = name
                if (is_webkit) {
                    final_name = "-webkit-${name}"
                }

                // 尝试解析为标准特性 ID
                let standard_id = parseFeatureId(final_name)
                match (standard_id) {
                    case Some(id) =>
                        return CssResult<(MediaFeatureName, ?MediaFeatureComparison)>.ok(
                            (MediaFeatureName.standard(id), comparator)
                        )
                    case None =>
                        return CssResult<(MediaFeatureName, ?MediaFeatureComparison)>.ok(
                            (MediaFeatureName.unknown(CssIdent(ident)), None)
                        )
                }
            case CssResult<String>.err(e) =>
                return CssResult<(MediaFeatureName, ?MediaFeatureComparison)>.err(e)
        }
    }

    /// 解析特性 ID
    static func parseFeatureId(name: String): ?MediaFeatureId {
        let lower = name.toLower()
        match (lower) {
            case "width" => Some(MediaFeatureId.width)
            case "height" => Some(MediaFeatureId.height)
            case "aspect-ratio" => Some(MediaFeatureId.aspect_ratio)
            case "orientation" => Some(MediaFeatureId.orientation)
            case "overflow-block" => Some(MediaFeatureId.overflow_block)
            case "overflow-inline" => Some(MediaFeatureId.overflow_inline)
            case "horizontal-viewport-segments" => Some(MediaFeatureId.horizontal_viewport_segments)
            case "vertical-viewport-segments" => Some(MediaFeatureId.vertical_viewport_segments)
            case "display-mode" => Some(MediaFeatureId.display_mode)
            case "resolution" => Some(MediaFeatureId.resolution)
            case "scan" => Some(MediaFeatureId.scan)
            case "grid" => Some(MediaFeatureId.grid)
            case "update" => Some(MediaFeatureId.update)
            case "environment-blending" => Some(MediaFeatureId.environment_blending)
            case "color" => Some(MediaFeatureId.color)
            case "color-index" => Some(MediaFeatureId.color_index)
            case "monochrome" => Some(MediaFeatureId.monochrome)
            case "color-gamut" => Some(MediaFeatureId.color_gamut)
            case "dynamic-range" => Some(MediaFeatureId.dynamic_range)
            case "inverted-colors" => Some(MediaFeatureId.inverted_colors)
            case "pointer" => Some(MediaFeatureId.pointer)
            case "hover" => Some(MediaFeatureId.hover)
            case "any-pointer" => Some(MediaFeatureId.any_pointer)
            case "any-hover" => Some(MediaFeatureId.any_hover)
            case "nav-controls" => Some(MediaFeatureId.nav_controls)
            case "video-color-gamut" => Some(MediaFeatureId.video_color_gamut)
            case "video-dynamic-range" => Some(MediaFeatureId.video_dynamic_range)
            case "scripting" => Some(MediaFeatureId.scripting)
            case "prefers-reduced-motion" => Some(MediaFeatureId.prefers_reduced_motion)
            case "prefers-reduced-transparency" => Some(MediaFeatureId.prefers_reduced_transparency)
            case "prefers-contrast" => Some(MediaFeatureId.prefers_contrast)
            case "forced-colors" => Some(MediaFeatureId.forced_colors)
            case "prefers-color-scheme" => Some(MediaFeatureId.prefers_color_scheme)
            case "prefers-reduced-data" => Some(MediaFeatureId.prefers_reduced_data)
            case "device-width" => Some(MediaFeatureId.device_width)
            case "device-height" => Some(MediaFeatureId.device_height)
            case "device-aspect-ratio" => Some(MediaFeatureId.device_aspect_ratio)
            case "-webkit-device-pixel-ratio" => Some(MediaFeatureId.webkit_device_pixel_ratio)
            case "-moz-device-pixel-ratio" => Some(MediaFeatureId.moz_device_pixel_ratio)
            case _ => None
        }
    }
}
