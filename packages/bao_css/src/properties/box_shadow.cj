// bao_css - CSS Properties: Box Shadow
// 严格翻译自: bun/src/css/properties/box_shadow.rs
//   对应: box_shadow.zig - CSS 盒阴影属性
//   对应: BoxShadow (color/x_offset/y_offset/blur/spread/inset)
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// BoxShadow
// 严格翻译自 BoxShadow
// ============================================================================

/// box-shadow 属性值
/// 严格翻译自 BoxShadow
public class BoxShadow {
    public var color: String     // 阴影颜色
    public var xOffset: String   // X 偏移
    public var yOffset: String   // Y 偏移
    public var blur: String      // 模糊半径
    public var spread: String    // 扩展距离
    public var inset: Bool       // 是否内嵌阴影

    public init(color: String, xOffset: String, yOffset: String, blur: String, spread: String, inset: Bool) {
        this.color = color
        this.xOffset = xOffset
        this.yOffset = yOffset
        this.blur = blur
        this.spread = spread
        this.inset = inset
    }

    public static func default(): BoxShadow {
        BoxShadow(color: "currentcolor", xOffset: "0", yOffset: "0", blur: "0", spread: "0", inset: false)
    }

    public func toCss(): String {
        var parts = ArrayList<String>()

        if (inset) {
            parts.append("inset")
        }

        parts.append(xOffset)
        parts.append(yOffset)

        if (blur != "0" || spread != "0") {
            parts.append(blur)
            if (spread != "0") {
                parts.append(spread)
            }
        }

        if (color != "currentcolor") {
            parts.append(color)
        }

        return String.join(" ", parts)
    }
}
