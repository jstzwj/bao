// bao_css - CSS @font-face 字体规则
// 严格翻译自: bun/src/css/rules/font_face.rs
//   对应: rules/font_face.zig - FontFaceRule, FontFaceProperty, Source,
//     FontStyle, FontFormat, FontTechnology, UnicodeRange, UrlSource
package bao_css.rules

import bao_core.*
import bao_collections.*

// ============================================================================
// Unicode 范围
// 严格翻译自: rules/font_face.rs UnicodeRange struct
// ============================================================================

/// CSS Unicode 范围
/// 严格翻译自 UnicodeRange struct { start: u32, end: u32 }
/// 连续的 Unicode 码点范围
public class CssUnicodeRange {
    /// 起始码点 (含)
    public var start: UInt32
    /// 结束码点 (含)
    public var end: UInt32

    public init(start: UInt32, end: UInt32) {
        this.start = start
        this.end = end
    }

    /// 转为 CSS 文本
    /// 严格翻译自 UnicodeRange.to_css
    /// 尝试优化为问号语法
    public func toCss(): String {
        if (start != end) {
            // 找到第一个不同的十六进制位
            var shift: UInt32 = 24
            var mask: UInt32 = 0xFu32 << shift
            while (shift > 0) {
                let c1 = start && mask
                let c2 = end && mask
                if (c1 != c2) {
                    break
                }
                mask = mask >> 4
                shift = shift - 4
            }

            // 获取余数
            shift = shift + 4
            let remainderMask: UInt32 = (1u32 << shift) - 1u32
            let startRemainder = start && remainderMask
            let endRemainder = end && remainderMask

            if (startRemainder == 0 && endRemainder == remainderMask) {
                let startVal = (start && ~remainderMask) >> shift
                var result = ""
                if (startVal != 0) {
                    result = "U+${startVal}"
                } else {
                    result = "U+"
                }
                var s = shift
                while (s > 0) {
                    result = "${result}?"
                    s = s - 4
                }
                return result
            }
        }

        var result = "U+${start}"
        if (end != start) {
            result = "${result}-${end}"
        }
        return result
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 字体样式
// 严格翻译自: rules/font_face.rs FontStyle enum
// ============================================================================

/// CSS @font-face 字体样式
/// 严格翻译自 FontStyle enum { Normal, Italic, Oblique(Size2D<Angle>) }
public class CssFontFaceStyle {
    public enum CssFontFaceStyleKind {
        | Normal
        | Italic
        | Oblique
    }

    public var kind: CssFontFaceStyleKind
    /// Oblique 角度值 (度数)
    public var obliqueAngle: Float64

    public init(kind: CssFontFaceStyleKind) {
        this.kind = kind
        this.obliqueAngle = 14.0  // 默认倾斜角度
    }

    public init(obliqueAngle: Float64) {
        this.kind = CssFontFaceStyleKind.Oblique
        this.obliqueAngle = obliqueAngle
    }

    /// 深拷贝
    public func deepClone(): CssFontFaceStyle {
        let s = CssFontFaceStyle(kind)
        s.obliqueAngle = obliqueAngle
        return s
    }

    /// 转为 CSS 文本
    /// 严格翻译自 FontStyle.to_css
    public func toCss(): String {
        match (kind) {
            case Normal => "normal"
            case Italic => "italic"
            case Oblique => {
                if (obliqueAngle == 14.0) {
                    "oblique"
                } else {
                    "oblique ${obliqueAngle}deg"
                }
            }
        }
    }
}

// ============================================================================
// 字体格式
// 严格翻译自: rules/font_face.rs FontFormat enum
// ============================================================================

/// CSS 字体格式关键字
/// 严格翻译自 FontFormat enum { Woff, Woff2, Truetype, Opentype, EmbeddedOpentype, Collection, Svg, String }
public enum CssFontFormat {
    | Woff               // WOFF 1.0
    | Woff2              // WOFF 2.0
    | Truetype           // TrueType
    | Opentype           // OpenType
    | EmbeddedOpentype   // Embedded OpenType (.eot)
    | Collection         // OpenType Collection
    | Svg                // SVG 字体

    public func toCss(): String {
        match (this) {
            case Woff => "woff"
            case Woff2 => "woff2"
            case Truetype => "truetype"
            case Opentype => "opentype"
            case EmbeddedOpentype => "embedded-opentype"
            case Collection => "collection"
            case Svg => "svg"
        }
    }
}

// ============================================================================
// 字体技术
// 严格翻译自: rules/font_face.rs FontTechnology enum
// ============================================================================

/// CSS 字体技术描述符
/// 严格翻译自 FontTechnology enum
public enum CssFontTechnology {
    | FeaturesOpentype   // OpenType 特性
    | FeaturesAat        // Apple Advanced Typography
    | FeaturesGraphite   // Graphite 表格
    | ColorColrv0        // COLR v0
    | ColorColrv1        // COLR v1
    | ColorSvg           // SVG 表格
    | ColorSbix          // sbix 表格
    | ColorCbdt          // CBDT 表格
    | Variations         // 可变字体
    | Palettes           // 字体调色板
    | Incremental        // 增量加载

    public func toCss(): String {
        match (this) {
            case FeaturesOpentype => "features-opentype"
            case FeaturesAat => "features-aat"
            case FeaturesGraphite => "features-graphite"
            case ColorColrv0 => "color-colrv0"
            case ColorColrv1 => "color-colrv1"
            case ColorSvg => "color-svg"
            case ColorSbix => "color-sbix"
            case ColorCbdt => "color-cbdt"
            case Variations => "variations"
            case Palettes => "palettes"
            case Incremental => "incremental"
        }
    }
}

// ============================================================================
// URL 源
// 严格翻译自: rules/font_face.rs UrlSource struct
// ============================================================================

/// CSS @font-face URL 源
/// 严格翻译自 UrlSource struct { url: Url, format: Option<FontFormat>, tech: ArrayList<FontTechnology> }
public class CssUrlSource {
    /// URL
    public var url: String
    /// 可选格式
    public var format: ?CssFontFormat
    /// 技术列表
    public var tech: ArrayList<CssFontTechnology>

    public init(url: String, format: ?CssFontFormat, tech: ArrayList<CssFontTechnology>) {
        this.url = url
        this.format = format
        this.tech = tech
    }

    /// 深拷贝
    public func deepClone(): CssUrlSource {
        let newTech = ArrayList<CssFontTechnology>()
        for (t in tech) {
            newTech.append(t)
        }
        CssUrlSource(url, format, newTech)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 UrlSource.to_css
    public func toCss(): String {
        let sb = StringBuilder()
        sb.append("url(${url})")
        match (format) {
            case Some(f) => sb.append(" format(${f.toCss()})")
            case None => ()
        }
        if (tech.size > 0) {
            let techStrs = ArrayList<String>()
            for (t in tech) {
                techStrs.append(t.toCss())
            }
            sb.append(" tech(${String.join(", ", techStrs)})")
        }
        return sb.toString()
    }
}

// ============================================================================
// 字体源
// 严格翻译自: rules/font_face.rs Source enum
// ============================================================================

/// CSS @font-face 字体源
/// 严格翻译自 Source enum { Url(UrlSource), Local(FontFamily) }
public class CssFontSource {
    public enum CssFontSourceKind {
        | Url
        | Local
    }

    public var kind: CssFontSourceKind
    /// URL 源
    public var urlSource: ?CssUrlSource
    /// 本地字体族名称
    public var localName: String

    public init(urlSource: CssUrlSource) {
        this.kind = CssFontSourceKind.Url
        this.urlSource = Some(urlSource)
        this.localName = ""
    }

    public init(localName: String) {
        this.kind = CssFontSourceKind.Local
        this.urlSource = None
        this.localName = localName
    }

    /// 深拷贝
    public func deepClone(): CssFontSource {
        match (kind) {
            case Url => {
                match (urlSource) {
                    case Some(u) => CssFontSource(u.deepClone())
                    case None => CssFontSource("")
                }
            }
            case Local => CssFontSource(localName)
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Source.to_css
    public func toCss(): String {
        match (kind) {
            case Url => {
                match (urlSource) {
                    case Some(u) => u.toCss()
                    case None => ""
                }
            }
            case Local => "local(${localName})"
        }
    }
}

// ============================================================================
// @font-face 属性
// 严格翻译自: rules/font_face.rs FontFaceProperty enum
// ============================================================================

/// CSS @font-face 属性
/// 严格翻译自 FontFaceProperty enum { Source, FontFamily, FontStyle, FontWeight, FontStretch, UnicodeRange, Custom }
public class CssFontFaceProperty {
    public enum CssFontFacePropertyKind {
        | Source        // src 属性
        | FontFamily    // font-family 属性
        | FontStyle     // font-style 属性
        | FontWeight    // font-weight 属性
        | FontStretch   // font-stretch 属性
        | UnicodeRange  // unicode-range 属性
        | Custom        // 自定义属性
    }

    public var kind: CssFontFacePropertyKind
    /// 源列表 (Source)
    public var sources: ArrayList<CssFontSource>
    /// 字体族名称 (FontFamily)
    public var fontFamily: String
    /// 字体样式 (FontStyle)
    public var fontStyle: CssFontFaceStyle
    /// 字重值 (FontWeight)
    public var fontWeight: String
    /// 字体拉伸值 (FontStretch)
    public var fontStretch: String
    /// Unicode 范围列表 (UnicodeRange)
    public var unicodeRanges: ArrayList<CssUnicodeRange>
    /// 自定义属性名
    public var customName: String
    /// 自定义属性值
    public var customValue: String

    public init(sources: ArrayList<CssFontSource>) {
        this.kind = CssFontFacePropertyKind.Source
        this.sources = sources
        this.fontFamily = ""
        this.fontStyle = CssFontFaceStyle(CssFontFaceStyleKind.Normal)
        this.fontWeight = ""
        this.fontStretch = ""
        this.unicodeRanges = ArrayList<CssUnicodeRange>()
        this.customName = ""
        this.customValue = ""
    }

    public init(fontFamily: String) {
        this.kind = CssFontFacePropertyKind.FontFamily
        this.sources = ArrayList<CssFontSource>()
        this.fontFamily = fontFamily
        this.fontStyle = CssFontFaceStyle(CssFontFaceStyleKind.Normal)
        this.fontWeight = ""
        this.fontStretch = ""
        this.unicodeRanges = ArrayList<CssUnicodeRange>()
        this.customName = ""
        this.customValue = ""
    }

    public init(fontStyle: CssFontFaceStyle) {
        this.kind = CssFontFacePropertyKind.FontStyle
        this.sources = ArrayList<CssFontSource>()
        this.fontFamily = ""
        this.fontStyle = fontStyle
        this.fontWeight = ""
        this.fontStretch = ""
        this.unicodeRanges = ArrayList<CssUnicodeRange>()
        this.customName = ""
        this.customValue = ""
    }

    public init(fontWeight: String, kind: CssFontFacePropertyKind) {
        this.kind = CssFontFacePropertyKind.FontWeight
        this.sources = ArrayList<CssFontSource>()
        this.fontFamily = ""
        this.fontStyle = CssFontFaceStyle(CssFontFaceStyleKind.Normal)
        this.fontWeight = fontWeight
        this.fontStretch = ""
        this.unicodeRanges = ArrayList<CssUnicodeRange>()
        this.customName = ""
        this.customValue = ""
    }

    public init(fontStretch: String) {
        this.kind = CssFontFacePropertyKind.FontStretch
        this.sources = ArrayList<CssFontSource>()
        this.fontFamily = ""
        this.fontStyle = CssFontFaceStyle(CssFontFaceStyleKind.Normal)
        this.fontWeight = ""
        this.fontStretch = fontStretch
        this.unicodeRanges = ArrayList<CssUnicodeRange>()
        this.customName = ""
        this.customValue = ""
    }

    public init(unicodeRanges: ArrayList<CssUnicodeRange>) {
        this.kind = CssFontFacePropertyKind.UnicodeRange
        this.sources = ArrayList<CssFontSource>()
        this.fontFamily = ""
        this.fontStyle = CssFontFaceStyle(CssFontFaceStyleKind.Normal)
        this.fontWeight = ""
        this.fontStretch = ""
        this.unicodeRanges = unicodeRanges
        this.customName = ""
        this.customValue = ""
    }

    public init(customName: String, customValue: String) {
        this.kind = CssFontFacePropertyKind.Custom
        this.sources = ArrayList<CssFontSource>()
        this.fontFamily = ""
        this.fontStyle = CssFontFaceStyle(CssFontFaceStyleKind.Normal)
        this.fontWeight = ""
        this.fontStretch = ""
        this.unicodeRanges = ArrayList<CssUnicodeRange>()
        this.customName = customName
        this.customValue = customValue
    }

    /// 转为 CSS 文本
    /// 严格翻译自 FontFaceProperty.to_css
    public func toCss(): String {
        match (kind) {
            case Source => {
                let parts = ArrayList<String>()
                for (s in sources) {
                    parts.append(s.toCss())
                }
                "src: ${String.join(", ", parts)}"
            }
            case FontFamily => "font-family: ${fontFamily}"
            case FontStyle => "font-style: ${fontStyle.toCss()}"
            case FontWeight => "font-weight: ${fontWeight}"
            case FontStretch => "font-stretch: ${fontStretch}"
            case UnicodeRange => {
                let parts = ArrayList<String>()
                for (r in unicodeRanges) {
                    parts.append(r.toCss())
                }
                "unicode-range: ${String.join(", ", parts)}"
            }
            case Custom => "${customName}: ${customValue}"
        }
    }
}

// ============================================================================
// @font-face 规则
// 严格翻译自: rules/font_face.rs FontFaceRule struct
// ============================================================================

/// CSS @font-face 规则
/// 严格翻译自 FontFaceRule struct { properties: ArrayList<FontFaceProperty>, loc: Location }
/// 表示一个 @font-face 规则
public class CssFontFaceRuleFull {
    /// 属性列表
    public var properties: ArrayList<CssFontFaceProperty>
    /// 位置信息
    public var loc: CssLocation

    public init(properties: ArrayList<CssFontFaceProperty>) {
        this.properties = properties
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 FontFaceRule.deep_clone
    public func deepClone(): CssFontFaceRuleFull {
        let newProps = ArrayList<CssFontFaceProperty>()
        // 属性引用拷贝 (内部字段均为值类型或字符串)
        for (p in properties) {
            newProps.append(p)
        }
        return CssFontFaceRuleFull(newProps)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 FontFaceRule.to_css
    public func toCss(indent: String, minify: Bool): String {
        let sb = StringBuilder()
        sb.append("${indent}@font-face {\n")
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
