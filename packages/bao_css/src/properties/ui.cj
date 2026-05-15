// bao_css - CSS Properties: UI
// 严格翻译自: bun/src/css/properties/ui.rs
//   对应: ui.zig - CSS 用户界面属性
//   对应: ColorScheme (bitflags), Cursor, CursorImage
//   对应: ColorOrAuto, Appearance
//   对应: Resize, CursorKeyword, CaretShape, Caret, UserSelect (占位)
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// ColorScheme
// 严格翻译自 ColorScheme (bitflags)
// ============================================================================

/// color-scheme 属性值
/// 严格翻译自 ColorScheme
public enum ColorSchemeFlag {
    | Light    // 浅色方案
    | Dark     // 深色方案
    | Only     // 禁止 UA 覆盖
}

/// color-scheme 属性值组合
/// 严格翻译自 ColorScheme
public class ColorScheme {
    public var light: Bool  // 支持浅色
    public var dark: Bool   // 支持深色
    public var only: Bool   // 禁止覆盖

    public init(light: Bool, dark: Bool, only: Bool) {
        this.light = light
        this.dark = dark
        this.only = only
    }

    public static func default(): ColorScheme {
        ColorScheme(light: false, dark: false, only: false)
    }

    public static func normal(): ColorScheme {
        ColorScheme(light: false, dark: false, only: false)
    }

    public func toCss(): String {
        if (!light && !dark && !only) {
            return "normal"
        }
        var parts = ArrayList<String>()
        if (light) {
            parts.append("light")
        }
        if (dark) {
            parts.append("dark")
        }
        if (only) {
            parts.append("only")
        }
        return String.join(" ", parts)
    }
}

// ============================================================================
// ColorSchemeKeyword
// 严格翻译自 ColorSchemeKeyword (内部辅助枚举)
// ============================================================================

/// color-scheme 解析辅助关键字
/// 严格翻译自 ColorSchemeKeyword
public enum ColorSchemeKeyword {
    | Normal
    | Only
    | Light
    | Dark
}

// ============================================================================
// Resize (占位)
// 严格翻译自 Resize
// ============================================================================

/// resize 属性值（占位）
/// Zig 源码为 DefineEnumProperty(@compileError(...)) 占位
/// 严格翻译自 Resize
public enum Resize {
    | None
    | Both
    | Horizontal
    | Vertical
    | Block
    | Inline

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Both => "both"
            case Horizontal => "horizontal"
            case Vertical => "vertical"
            case Block => "block"
            case Inline => "inline"
        }
    }
}

// ============================================================================
// Cursor
// 严格翻译自 Cursor
// ============================================================================

/// cursor 属性值
/// 严格翻译自 Cursor
public class Cursor {
    public var images: ArrayList<CursorImage>  // 光标图像列表
    public var keyword: String                  // 预定义光标关键字

    public init(images: ArrayList<CursorImage>, keyword: String) {
        this.images = images
        this.keyword = keyword
    }

    public static func default(): Cursor {
        Cursor(images: ArrayList<CursorImage>(), keyword: "auto")
    }

    public func toCss(): String {
        var parts = ArrayList<String>()
        for (img in images) {
            parts.append(img.toCss())
        }
        if (keyword != "" && keyword != "auto") {
            parts.append(keyword)
        }
        if (parts.isEmpty()) {
            return "auto"
        }
        return String.join(", ", parts) + " " + keyword
    }
}

// ============================================================================
// CursorImage
// 严格翻译自 CursorImage
// ============================================================================

/// 光标图像值
/// 严格翻译自 CursorImage
public class CursorImage {
    public var url: String                // 图像 URL
    public var hotspot: Option<ArrayList<Float64>> // 热点坐标

    public init(url: String, hotspot: Option<ArrayList<Float64>>) {
        this.url = url
        this.hotspot = hotspot
    }

    public func toCss(): String {
        match (hotspot) {
            Some(coords) => {
                if (coords.size >= 2) {
                    return "url(" + url + ") " + coords[0].toString() + " " + coords[1].toString()
                }
                return "url(" + url + ")"
            }
            None => "url(" + url + ")"
        }
    }
}

// ============================================================================
// ColorOrAuto
// 严格翻译自 ColorOrAuto
// ============================================================================

/// caret-color 属性值
/// 严格翻译自 ColorOrAuto
public enum ColorOrAuto {
    | Auto          // 自动
    | Color(String) // 显式颜色

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case Color(c) => c
        }
    }
}

// ============================================================================
// Appearance
// 严格翻译自 Appearance
// ============================================================================

/// appearance 属性值
/// 严格翻译自 Appearance
public enum Appearance {
    | None                // 无
    | Auto                // 自动
    | Textfield           // 文本字段
    | MenulistButton      // 菜单列表按钮
    | Button              // 按钮
    | Checkbox            // 复选框
    | Listbox             // 列表框
    | Menulist            // 菜单列表
    | Meter               // 计量器
    | ProgressBar         // 进度条
    | PushButton          // 按压按钮
    | Radio               // 单选按钮
    | Searchfield         // 搜索字段
    | SliderHorizontal    // 水平滑块
    | SquareButton        // 方形按钮
    | Textarea            // 文本区域
    | NonStandard(String) // 非标准值

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Auto => "auto"
            case Textfield => "textfield"
            case MenulistButton => "menulist-button"
            case Button => "button"
            case Checkbox => "checkbox"
            case Listbox => "listbox"
            case Menulist => "menulist"
            case Meter => "meter"
            case ProgressBar => "progress-bar"
            case PushButton => "push-button"
            case Radio => "radio"
            case Searchfield => "searchfield"
            case SliderHorizontal => "slider-horizontal"
            case SquareButton => "square-button"
            case Textarea => "textarea"
            case NonStandard(s) => s
        }
    }
}

// ============================================================================
// 占位类型 (Zig 源码中为 DefineEnumProperty(@compileError(...)) 占位)
// ============================================================================

/// caret-shape 属性值（占位）
/// 严格翻译自 CaretShape
public enum CaretShape {
    | Auto
    | Bar
    | Block
    | Underscore

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case Bar => "bar"
            case Block => "block"
            case Underscore => "underscore"
        }
    }
}

/// caret 属性值（占位）
/// 严格翻译自 Caret
public struct Caret {
}

/// user-select 属性值（占位）
/// 严格翻译自 UserSelect
public enum UserSelect {
    | Auto
    | Text
    | None
    | Contain
    | All

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case Text => "text"
            case None => "none"
            case Contain => "contain"
            case All => "all"
        }
    }
}
