// 严格翻译自: src/css/logical.zig
package bao.css

// ============================================================================
// PropertyCategory - 属性类别 (逻辑属性 vs 物理属性)
// 严格翻译自: logical.zig PropertyCategory
// ============================================================================

/// 属性类别枚举
/// 严格翻译自 PropertyCategory enum
public enum PropertyCategory {
    | logical
    | physical

    /// 默认值 (物理属性)
    /// 严格翻译自 PropertyCategory.default()
    public static func default(): PropertyCategory {
        physical
    }
}

// ============================================================================
// LogicalGroup - 逻辑属性分组
// 严格翻译自: logical.zig LogicalGroup
// ============================================================================

/// 逻辑属性分组枚举
/// 严格翻译自 LogicalGroup enum
/// 每个分组代表一组可以以逻辑方向 (inline/block/start/end) 声明的 CSS 属性
public enum LogicalGroup {
    | border_color       // 边框颜色
    | border_style       // 边框样式
    | border_width       // 边框宽度
    | border_radius      // 边框圆角
    | margin             // 外边距
    | scroll_margin      // 滚动外边距
    | padding            // 内边距
    | scroll_padding     // 滚动内边距
    | inset              // 定位偏移
    | size               // 尺寸
    | min_size           // 最小尺寸
    | max_size           // 最大尺寸
}
