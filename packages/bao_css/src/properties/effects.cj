// bao_css - CSS Properties: Effects (Filter)
// 严格翻译自: bun/src/css/properties/effects.rs
//   对应: effects.zig - CSS 滤镜属性
//   对应: FilterList, Filter (11 variants), DropShadow
// ============================================================================

package bao_css.properties

import bao_core.*
import bao_collections.*

// ============================================================================
// FilterList
// 严格翻译自 FilterList
// ============================================================================

/// filter / backdrop-filter 属性值
/// 严格翻译自 FilterList
public enum FilterList {
    | NoneValue                       // "none"
    | Filters(ArrayList<Filter>) // 滤镜函数列表

    private func filtersToCss(filters: ArrayList<Filter>): String {
        if (filters.isEmpty()) {
            "none"
        } else {
            var parts = ArrayList<String>()
            for (f in filters) {
                parts.append(f.toCss())
            }
            var partArr = Array<String>(parts.size, repeat: "")
            var pi: Int64 = 0
            for (p in parts) { partArr[pi] = p; pi += 1 }
            String.join(partArr, delimiter: " ")
        }
    }

    public func toCss(): String {
        match (this) {
            case NoneValue => "none"
            case Filters(filters) => filtersToCss(filters)
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
    | DropShadowVal(DropShadow)             // drop-shadow(...)
    | UrlVal(String)                        // url(...)

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
            case DropShadowVal(ds) => ds.toCss()
            case UrlVal(u) => "url(" + u + ")"
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

        var partArr = Array<String>(parts.size, repeat: "")
        var pi: Int64 = 0
        for (p in parts) { partArr[pi] = p; pi += 1 }
        return "drop-shadow(" + String.join(partArr, delimiter: " ") + ")"
    }
}
