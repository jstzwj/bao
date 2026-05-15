// bao_css - CSS Properties: Background
// 严格翻译自: bun/src/css/properties/background.rs
//   对应: background.zig - CSS 背景属性
//   对应: Background, BackgroundSize, BackgroundPosition, BackgroundRepeat
//   对应: BackgroundAttachment, BackgroundOrigin, BackgroundClip
//   对应: BackgroundProperty, BackgroundHandler
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// BackgroundRepeatKeyword
// 严格翻译自 BackgroundRepeatKeyword (DefineEnumProperty)
// ============================================================================

/// <repeat-style> 单方向值
/// 严格翻译自 BackgroundRepeatKeyword
public enum BackgroundRepeatKeyword {
    | Repeat   // 重复
    | Space    // 均匀间距重复
    | Round    // 缩放后重复
    | NoRepeat // 不重复

    public func toCss(): String {
        match (this) {
            case Repeat => "repeat"
            case Space => "space"
            case Round => "round"
            case NoRepeat => "no-repeat"
        }
    }
}

// ============================================================================
// BackgroundAttachment
// 严格翻译自 BackgroundAttachment (DefineEnumProperty)
// ============================================================================

/// background-attachment 属性值
/// 严格翻译自 BackgroundAttachment
public enum BackgroundAttachment {
    | Scroll  // 随容器滚动
    | Fixed   // 固定到视口
    | Local   // 固定到元素内容

    public func toCss(): String {
        match (this) {
            case Scroll => "scroll"
            case Fixed => "fixed"
            case Local => "local"
        }
    }

    public static func default(): BackgroundAttachment {
        BackgroundAttachment.Scroll
    }
}

// ============================================================================
// BackgroundOrigin
// 严格翻译自 BackgroundOrigin (DefineEnumProperty)
// ============================================================================

/// background-origin 属性值
/// 严格翻译自 BackgroundOrigin
public enum BackgroundOrigin {
    | BorderBox   // 相对于边框盒
    | PaddingBox  // 相对于内边距盒
    | ContentBox  // 相对于内容盒

    public func toCss(): String {
        match (this) {
            case BorderBox => "border-box"
            case PaddingBox => "padding-box"
            case ContentBox => "content-box"
        }
    }
}

// ============================================================================
// BackgroundClip
// 严格翻译自 BackgroundClip (DefineEnumProperty)
// ============================================================================

/// background-clip 属性值
/// 严格翻译自 BackgroundClip
public enum BackgroundClip {
    | BorderBox   // 裁剪到边框盒
    | PaddingBox  // 裁剪到内边距盒
    | ContentBox  // 裁剪到内容盒
    | Border      // 裁剪到边框绘制区域
    | Text        // 裁剪到文本内容

    public func toCss(): String {
        match (this) {
            case BorderBox => "border-box"
            case PaddingBox => "padding-box"
            case ContentBox => "content-box"
            case Border => "border"
            case Text => "text"
        }
    }

    public static func default(): BackgroundClip {
        BackgroundClip.BorderBox
    }
}

// ============================================================================
// BackgroundSize
// 严格翻译自 BackgroundSize
// ============================================================================

/// background-size 属性值
/// 严格翻译自 BackgroundSize
public enum BackgroundSize {
    | Explicit(ExplicitBackgroundSize)  // 显式尺寸
    | Cover                             // 覆盖
    | Contain                           // 包含

    public func toCss(): String {
        match (this) {
            case Explicit(e) => e.toCss()
            case Cover => "cover"
            case Contain => "contain"
        }
    }

    public static func default(): BackgroundSize {
        BackgroundSize.Explicit(ExplicitBackgroundSize(width: "auto", height: "auto"))
    }
}

/// 显式背景尺寸
/// 严格翻译自 ExplicitBackgroundSize
public class ExplicitBackgroundSize {
    public var width: String   // 宽度
    public var height: String  // 高度

    public init(width: String, height: String) {
        this.width = width
        this.height = height
    }

    public func toCss(): String {
        if (height == "auto") {
            return width
        }
        return width + " " + height
    }
}

// ============================================================================
// BackgroundRepeat
// 严格翻译自 BackgroundRepeat
// ============================================================================

/// background-repeat 属性值
/// 严格翻译自 BackgroundRepeat
public class BackgroundRepeat {
    public var x: BackgroundRepeatKeyword  // X 方向重复方式
    public var y: BackgroundRepeatKeyword  // Y 方向重复方式

    public init(x: BackgroundRepeatKeyword, y: BackgroundRepeatKeyword) {
        this.x = x
        this.y = y
    }

    public static func default(): BackgroundRepeat {
        BackgroundRepeat(x: BackgroundRepeatKeyword.Repeat, y: BackgroundRepeatKeyword.Repeat)
    }

    public func toCss(): String {
        if (x == BackgroundRepeatKeyword.Repeat && y == BackgroundRepeatKeyword.NoRepeat) {
            return "repeat-x"
        }
        if (x == BackgroundRepeatKeyword.NoRepeat && y == BackgroundRepeatKeyword.Repeat) {
            return "repeat-y"
        }
        if (y == x) {
            return x.toCss()
        }
        return x.toCss() + " " + y.toCss()
    }
}

// ============================================================================
// BackgroundPosition
// 严格翻译自 BackgroundPosition
// ============================================================================

/// background-position 属性值
/// 严格翻译自 BackgroundPosition
public class BackgroundPosition {
    public var x: String  // X 位置
    public var y: String  // Y 位置

    public init(x: String, y: String) {
        this.x = x
        this.y = y
    }

    public static func default(): BackgroundPosition {
        BackgroundPosition(x: "0%", y: "0%")
    }

    public func toCss(): String {
        if (x == "0%" && y == "0%") {
            return "0% 0%"
        }
        return x + " " + y
    }
}

// ============================================================================
// Background
// 严格翻译自 Background
// ============================================================================

/// background 简写属性值
/// 严格翻译自 Background
public class Background {
    public var image: String                    // 背景图片
    public var color: String                    // 背景颜色
    public var position: BackgroundPosition     // 背景位置
    public var repeat: BackgroundRepeat         // 重复方式
    public var size: BackgroundSize             // 背景尺寸
    public var attachment: BackgroundAttachment  // 附件方式
    public var origin: BackgroundOrigin         // 原点
    public var clip: BackgroundClip             // 裁剪

    public init() {
        this.image = "none"
        this.color = "transparent"
        this.position = BackgroundPosition.default()
        this.repeat = BackgroundRepeat.default()
        this.size = BackgroundSize.default()
        this.attachment = BackgroundAttachment.default()
        this.origin = BackgroundOrigin.PaddingBox
        this.clip = BackgroundClip.default()
    }

    public init(image: String, color: String, position: BackgroundPosition,
                repeat: BackgroundRepeat, size: BackgroundSize,
                attachment: BackgroundAttachment, origin: BackgroundOrigin,
                clip: BackgroundClip) {
        this.image = image
        this.color = color
        this.position = position
        this.repeat = repeat
        this.size = size
        this.attachment = attachment
        this.origin = origin
        this.clip = clip
    }

    public func toCss(): String {
        var parts = ArrayList<String>()

        if (color != "transparent") {
            parts.append(color)
        }

        if (image != "none") {
            parts.append(image)
        }

        let posCss = position.toCss()
        if (posCss != "0% 0%" || size != BackgroundSize.default()) {
            parts.append(posCss)
            if (size != BackgroundSize.default()) {
                parts.append("/" + size.toCss())
            }
        }

        if (repeat != BackgroundRepeat.default()) {
            parts.append(repeat.toCss())
        }

        if (attachment != BackgroundAttachment.default()) {
            parts.append(attachment.toCss())
        }

        if (origin != BackgroundOrigin.PaddingBox || clip != BackgroundClip.BorderBox) {
            parts.append(origin.toCss())
        }

        if (clip != BackgroundClip.BorderBox) {
            parts.append(clip.toCss())
        }

        if (parts.isEmpty()) {
            return "none"
        }

        return String.join(" ", parts)
    }
}
