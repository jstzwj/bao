// bao_css - CSS Properties: Border Radius
// 严格翻译自: bun/src/css/properties/border_radius.rs
//   对应: border_radius.zig - CSS 圆角边框属性
//   对应: BorderRadius, BorderRadiusHandler
// ============================================================================

package bao.css

import bao_core.*

// ============================================================================
// BorderRadius
// 严格翻译自 BorderRadius
// ============================================================================

/// border-radius 属性值
/// 严格翻译自 BorderRadius
public class BorderRadius {
    /// 左上角的 x 和 y 半径
    public var topLeftX: String
    public var topLeftY: String
    /// 右上角的 x 和 y 半径
    public var topRightX: String
    public var topRightY: String
    /// 右下角的 x 和 y 半径
    public var bottomRightX: String
    public var bottomRightY: String
    /// 左下角的 x 和 y 半径
    public var bottomLeftX: String
    public var bottomLeftY: String

    public init(
        topLeftX: String, topLeftY: String,
        topRightX: String, topRightY: String,
        bottomRightX: String, bottomRightY: String,
        bottomLeftX: String, bottomLeftY: String
    ) {
        this.topLeftX = topLeftX
        this.topLeftY = topLeftY
        this.topRightX = topRightX
        this.topRightY = topRightY
        this.bottomRightX = bottomRightX
        this.bottomRightY = bottomRightY
        this.bottomLeftX = bottomLeftX
        this.bottomLeftY = bottomLeftY
    }

    public static func default(): BorderRadius {
        BorderRadius(
            topLeftX: "0", topLeftY: "0",
            topRightX: "0", topRightY: "0",
            bottomRightX: "0", bottomRightY: "0",
            bottomLeftX: "0", bottomLeftY: "0"
        )
    }

    public func toCss(): String {
        // 写入宽度 (水平半径)
        let widthCss = serializeRadiusRect(
            topLeftX, topRightX, bottomRightX, bottomLeftX
        )

        // 检查水平和垂直半径是否相同
        let sameRadii = topLeftX == topLeftY &&
                        topRightX == topRightY &&
                        bottomRightX == bottomRightY &&
                        bottomLeftX == bottomLeftY

        if (sameRadii) {
            return widthCss
        }

        // 写入高度 (垂直半径)
        let heightCss = serializeRadiusRect(
            topLeftY, topRightY, bottomRightY, bottomLeftY
        )

        return widthCss + " / " + heightCss
    }
}

/// 序列化四个半径值为 Rect 格式
func serializeRadiusRect(tl: String, tr: String, br: String, bl: String): String {
    let sameVertical = tl == br
    let sameHorizontal = tr == bl
    if (sameVertical && sameHorizontal && tl == tr) {
        return tl
    }
    if (sameVertical && sameHorizontal) {
        return tl + " " + tr
    }
    if (sameHorizontal) {
        return tl + " " + tr + " " + br
    }
    return tl + " " + tr + " " + br + " " + bl
}
