// bao_css - CSS Properties: Effects (Filter)
// 严格翻译自: bun/src/css/properties/effects.rs
//   对应: effects.zig - CSS 滤镜属性
//   对应: FilterList, Filter (11 variants), DropShadow
// ============================================================================

package bao.css

import bao_core.*

// ============================================================================
// FilterList
// 严格翻译自 FilterList
// ============================================================================

/// filter / backdrop-filter 属性值
/// 严格翻译自 FilterList
public enum FilterList {
    | None                       // "none"
    | Filters(ArrayList<Filter>) // 滤镜函数列表

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Filters(filters) => {
                if (filters.isEmpty()) {
                    return "none"
                }
                var parts = ArrayList<String>()
                for (f in filters) {
                    parts.append(f.toCss())
                }
                return String.join(" ", parts)
            }
        }
    }
}

// ============================================================================
// Filter
// 严格翻译自 Filter (11 variants)
// ============================================================================

/// 单个滤镜函数
/// 严格翻译自 Filter
public enum Filter {
    | Blur(String)                          // blur(radius)
    | Brightness(String)                    // brightness(value)
    | Contrast(String)                      // contrast(value)
    | Grayscale(String)                     // grayscale(value)
    | HueRotate(String)                     // hue-rotate(angle)
    | Invert(String)                        // invert(value)
    | Opacity(String)                       // opacity(value)
    | Saturate(String)                      // saturate(value)
    | Sepia(String)                         // sepia(value)
    | DropShadow(DropShadow)                // drop-shadow(...)
    | Url(String)                           // url(...)

    public func toCss(): String {
        match (this) {
            case Blur(r) => "blur(" + r + ")"
            case Brightness(v) => "brightness(" + v + ")"
            case Contrast(v) => "contrast(" + v + ")"
            case Grayscale(v) => "grayscale(" + v + ")"
            case HueRotate(a) => "hue-rotate(" + a + ")"
            case Invert(v) => "invert(" + v + ")"
            case Opacity(v) => "opacity(" + v + ")"
            case Saturate(v) => "saturate(" + v + ")"
            case Sepia(v) => "sepia(" + v + ")"
            case DropShadow(ds) => ds.toCss()
            case Url(u) => "url(" + u + ")"
        }
    }
}

// ============================================================================
// DropShadow
// 严格翻译自 DropShadow
// ============================================================================

/// drop-shadow() 滤镜函数值
/// 严格翻译自 DropShadow
public class DropShadow {
    public var color: String     // 阴影颜色
    public var xOffset: String   // X 偏移
    public var yOffset: String   // Y 偏移
    public var blur: String      // 模糊半径

    public init(color: String, xOffset: String, yOffset: String, blur: String) {
        this.color = color
        this.xOffset = xOffset
        this.yOffset = yOffset
        this.blur = blur
    }

    public func toCss(): String {
        var parts = ArrayList<String>()
        parts.append(xOffset)
        parts.append(yOffset)

        if (blur != "0") {
            parts.append(blur)
        }

        if (color != "currentcolor") {
            parts.append(color)
        }

        return "drop-shadow(" + String.join(" ", parts) + ")"
    }
}
