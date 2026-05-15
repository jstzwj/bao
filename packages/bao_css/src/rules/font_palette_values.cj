// bao_css - CSS @font-palette-values 字体调色板值规则
// 严格翻译自: bun/src/css/rules/font_palette_values.rs
//   对应: rules/font_palette_values.zig - FontPaletteValuesRule,
//     FontPaletteValuesProperty, OverrideColors, BasePalette
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// 基础调色板
// 严格翻译自: rules/font_palette_values.rs BasePalette enum
// ============================================================================

/// CSS @font-palette-values 基础调色板值
/// 严格翻译自 BasePalette enum { Light, Dark, Integer(u16) }
public class CssBasePalette {
    public enum CssBasePaletteKind {
        | Light      // light 关键字
        | Dark       // dark 关键字
        | Integer    // 调色板索引
    }

    public var kind: CssBasePaletteKind
    public var index: UInt16

    public init(kind: CssBasePaletteKind) {
        this.kind = kind
        this.index = 0
    }

    public init(index: UInt16) {
        this.kind = CssBasePaletteKind.Integer
        this.index = index
    }

    /// 深拷贝
    public func deepClone(): CssBasePalette {
        CssBasePalette(kind)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 BasePalette.to_css
    public func toCss(): String {
        match (kind) {
            case Light => "light"
            case Dark => "dark"
            case Integer => "${index}"
        }
    }
}

// ============================================================================
// 覆盖颜色
// 严格翻译自: rules/font_palette_values.rs OverrideColors struct
// ============================================================================

/// CSS @font-palette-values 覆盖颜色
/// 严格翻译自 OverrideColors struct { index: u16, color: CssColor }
/// 表示调色板中要覆盖的颜色
public class CssOverrideColors {
    /// 调色板中的颜色索引
    public var index: UInt16
    /// 替换颜色
    public var color: String

    public init(index: UInt16, color: String) {
        this.index = index
        this.color = color
    }

    /// 深拷贝
    public func deepClone(): CssOverrideColors {
        CssOverrideColors(index, color)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 OverrideColors.to_css
    public func toCss(): String {
        "${index} ${color}"
    }
}

// ============================================================================
// @font-palette-values 属性
// 严格翻译自: rules/font_palette_values.rs FontPaletteValuesProperty enum
// ============================================================================

/// CSS @font-palette-values 属性
/// 严格翻译自 FontPaletteValuesProperty enum { FontFamily, BasePalette, OverrideColors, Custom }
public class CssFontPaletteValuesProperty {
    public enum CssFontPaletteValuesPropertyKind {
        | FontFamily       // font-family 属性
        | BasePalette      // base-palette 属性
        | OverrideColors   // override-colors 属性
        | Custom           // 自定义属性
    }

    public var kind: CssFontPaletteValuesPropertyKind
    /// 字体族
    public var fontFamily: String
    /// 基础调色板
    public var basePalette: CssBasePalette
    /// 覆盖颜色列表
    public var overrideColors: ArrayList<CssOverrideColors>
    /// 自定义属性名
    public var customName: String
    /// 自定义属性值
    public var customValue: String

    public init(fontFamily: String) {
        this.kind = CssFontPaletteValuesPropertyKind.FontFamily
        this.fontFamily = fontFamily
        this.basePalette = CssBasePalette(CssBasePaletteKind.Light)
        this.overrideColors = ArrayList<CssOverrideColors>()
        this.customName = ""
        this.customValue = ""
    }

    public init(basePalette: CssBasePalette) {
        this.kind = CssFontPaletteValuesPropertyKind.BasePalette
        this.fontFamily = ""
        this.basePalette = basePalette
        this.overrideColors = ArrayList<CssOverrideColors>()
        this.customName = ""
        this.customValue = ""
    }

    public init(overrideColors: ArrayList<CssOverrideColors>) {
        this.kind = CssFontPaletteValuesPropertyKind.OverrideColors
        this.fontFamily = ""
        this.basePalette = CssBasePalette(CssBasePaletteKind.Light)
        this.overrideColors = overrideColors
        this.customName = ""
        this.customValue = ""
    }

    public init(customName: String, customValue: String) {
        this.kind = CssFontPaletteValuesPropertyKind.Custom
        this.fontFamily = ""
        this.basePalette = CssBasePalette(CssBasePaletteKind.Light)
        this.overrideColors = ArrayList<CssOverrideColors>()
        this.customName = customName
        this.customValue = customValue
    }

    /// 转为 CSS 文本
    /// 严格翻译自 FontPaletteValuesProperty.to_css
    public func toCss(): String {
        match (kind) {
            case FontFamily => "font-family: ${fontFamily}"
            case BasePalette => "base-palette: ${basePalette.toCss()}"
            case OverrideColors => {
                let parts = ArrayList<String>()
                for (c in overrideColors) {
                    parts.append(c.toCss())
                }
                "override-colors: ${String.join(", ", parts)}"
            }
            case Custom => "${customName}: ${customValue}"
        }
    }
}

// ============================================================================
// @font-palette-values 规则
// 严格翻译自: rules/font_palette_values.rs FontPaletteValuesRule struct
// ============================================================================

/// CSS @font-palette-values 规则
/// 严格翻译自 FontPaletteValuesRule struct { name: DashedIdent, properties: ArrayList<...>, loc }
public class CssFontPaletteValuesRule {
    /// 调色板名称
    public var name: String
    /// 属性列表
    public var properties: ArrayList<CssFontPaletteValuesProperty>
    /// 位置信息
    public var loc: CssLocation

    public init(name: String, properties: ArrayList<CssFontPaletteValuesProperty>) {
        this.name = name
        this.properties = properties
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 FontPaletteValuesRule.deep_clone
    public func deepClone(): CssFontPaletteValuesRule {
        CssFontPaletteValuesRule(name, properties)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 FontPaletteValuesRule.to_css
    public func toCss(indent: String, minify: Bool): String {
        let sb = StringBuilder()
        sb.append("${indent}@font-palette-values ${name} {\n")
        for (i in 0..properties.size) {
            sb.append("${indent}  ${properties[i].toCss()}")
            if (i != properties.size - 1 || !minify) {
                sb.append(";")
            }
            sb.append("\n")
        }
        sb.append("${indent}}")
        return sb.toString()
    }

    public func toString(): String {
        toCss("", false)
    }
}
