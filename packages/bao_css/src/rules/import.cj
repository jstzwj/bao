// bao_css - CSS @import 导入规则
// 严格翻译自: bun/src/css/rules/import.rs
//   对应: rules/import.zig - ImportRule, ImportConditions, Layer
package bao_css.rules

import bao_core.*
import bao_collections.*

// ============================================================================
// Layer (层)
// 严格翻译自: rules/import.rs Layer struct
// ============================================================================

/// 导入条件中的层信息
/// 严格翻译自 Layer struct { v: Option<LayerName> }
/// v 为 None 表示匿名层
public class CssImportLayer {
    /// 层名称，None 表示匿名层
    public var name: ?String

    public init(name: ?String) {
        this.name = name
    }

    public init() {
        this.name = None
    }

    /// 深拷贝
    public func deepClone(): CssImportLayer {
        CssImportLayer(name)
    }

    /// 相等比较
    public func eql(other: CssImportLayer): Bool {
        match (name, other.name) {
            case (None, None) => true
            case (Some(a), Some(b)) => a == b
            case _ => false
        }
    }

    /// 是否为匿名层
    /// 严格翻译自 ImportConditions.has_anonymous_layer
    public func isAnonymous(): Bool {
        name == None
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (name) {
            case Some(n) => " layer(${n})"
            case None => " layer"
        }
    }
}

// ============================================================================
// ImportConditions (导入条件)
// 严格翻译自: rules/import.rs ImportConditions struct
// ============================================================================

/// CSS @import 规则条件
/// 严格翻译自 ImportConditions struct { layer, supports, media }
/// 包含层、supports 条件和媒体查询
public class CssImportConditions {
    /// 可选层名
    public var layer: ?CssImportLayer
    /// 可选 supports 条件
    public var supports: ?String
    /// 媒体查询
    public var media: String

    public init(layer: ?CssImportLayer, supports: ?String, media: String) {
        this.layer = layer
        this.supports = supports
        this.media = media
    }

    public init() {
        this.layer = None
        this.supports = None
        this.media = ""
    }

    /// 是否有条件
    /// 严格翻译自 ImportRule.has_conditions
    public func hasConditions(): Bool {
        layer != None || supports != None || media.length > 0
    }

    /// 转为 CSS 文本
    /// 严格翻译自 ImportConditions.to_css
    public func toCss(): String {
        let sb = StringBuilder()
        match (layer) {
            case Some(l) => sb.append(l.toCss())
            case None => {}
        }
        match (supports) {
            case Some(s) => {
                sb.append(" supports(${s})")
            }
            case None => {}
        }
        if (media.length > 0) {
            sb.append(" ${media}")
        }
        return sb.toString()
    }
}

// ============================================================================
// @import 规则
// 严格翻译自: rules/import.rs ImportRule struct
// ============================================================================

/// CSS @import 规则
/// 严格翻译自 ImportRule struct { url, layer, supports, media, import_record_idx, loc }
/// 表示一个 @import 规则
public class CssImportRuleFull {
    /// 导入 URL
    public var url: String
    /// 可选层
    public var layer: ?CssImportLayer
    /// 可选 supports 条件
    public var supports: ?String
    /// 媒体查询
    public var media: String
    /// 导入记录索引 (打包时使用)
    public var importRecordIdx: UInt32
    /// 位置信息
    public var loc: CssLocation

    public init(url: String) {
        this.url = url
        this.layer = None
        this.supports = None
        this.media = ""
        this.importRecordIdx = UInt32.MAX
        this.loc = CssLocation()
    }

    public init(url: String, conditions: CssImportConditions) {
        this.url = url
        this.layer = conditions.layer
        this.supports = conditions.supports
        this.media = conditions.media
        this.importRecordIdx = UInt32.MAX
        this.loc = CssLocation()
    }

    /// 获取导入条件
    /// 严格翻译自 ImportRule.conditions()
    public func conditions(): CssImportConditions {
        CssImportConditions(layer, supports, media)
    }

    /// 是否有条件
    /// 严格翻译自 ImportRule.has_conditions
    public func hasConditions(): Bool {
        layer != None || supports != None || media.length > 0
    }

    /// 深拷贝
    /// 严格翻译自 ImportRule.deep_clone
    public func deepClone(): CssImportRuleFull {
        let rule = CssImportRuleFull(url)
        rule.layer = layer
        rule.supports = supports
        rule.media = media
        rule.importRecordIdx = importRecordIdx
        rule.loc = loc
        return rule
    }

    /// 转为 CSS 文本
    /// 严格翻译自 ImportRule.to_css
    public func toCss(): String {
        let sb = StringBuilder()
        sb.append("@import \"${url}\"")

        // 层条件
        match (layer) {
            case Some(l) => sb.append(l.toCss())
            case None => {}
        }

        // supports 条件
        match (supports) {
            case Some(s) => {
                sb.append(" supports(${s})")
            }
            case None => {}
        }

        // 媒体查询
        if (media.length > 0) {
            sb.append(" ${media}")
        }

        sb.append(";")
        return sb.toString()
    }

    public func toString(): String {
        toCss()
    }
}
