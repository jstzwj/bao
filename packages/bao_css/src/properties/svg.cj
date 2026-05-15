// bao_css - CSS Properties: SVG
// 严格翻译自: bun/src/css/properties/svg.rs
//   对应: svg.zig - SVG 绘制属性
//   对应: SVGPaint, SVGPaintFallback
//   对应: StrokeLinecap, StrokeLinejoin, StrokeDasharray, Marker
//   对应: ColorInterpolation, ColorRendering, ShapeRendering
//   对应: TextRendering, ImageRendering
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// SVGPaint
// 严格翻译自 SVGPaint
// ============================================================================

/// SVG paint 值（fill/stroke 属性）
/// 严格翻译自 SVGPaint
public enum SVGPaint {
    | Url(String, Option<SVGPaintFallback>)  // URL 引用 + 回退
    | Color(String)                          // 纯色
    | ContextFill                            // 上下文填充
    | ContextStroke                          // 上下文描边
    | None                                   // 无

    public func toCss(): String {
        match (this) {
            case Url(u, fallback) => {
                var result = "url(" + u + ")"
                match (fallback) {
                    case Some(f) => result = result + " " + f.toCss()
                    case None => ()
                }
                return result
            }
            case Color(c) => c
            case ContextFill => "context-fill"
            case ContextStroke => "context-stroke"
            case None => "none"
        }
    }
}

// ============================================================================
// SVGPaintFallback
// 严格翻译自 SVGPaintFallback
// ============================================================================

/// SVG paint 回退值
/// 严格翻译自 SVGPaintFallback
public enum SVGPaintFallback {
    | None          // 无回退
    | Color(String) // 纯色回退

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Color(c) => c
        }
    }
}

// ============================================================================
// 占位类型 (Zig 源码中为 DefineEnumProperty(@compileError(...)) 占位)
// ============================================================================

/// stroke-linecap 属性值（占位）
/// Zig 源码为 DefineEnumProperty(@compileError(...)) 占位
/// 严格翻译自 StrokeLinecap
public enum StrokeLinecap {
    | Butt
    | Round
    | Square

    public func toCss(): String {
        match (this) {
            case Butt => "butt"
            case Round => "round"
            case Square => "square"
        }
    }
}

/// stroke-linejoin 属性值（占位）
/// Zig 源码为 DefineEnumProperty(@compileError(...)) 占位
/// 严格翻译自 StrokeLinejoin
public enum StrokeLinejoin {
    | Miter
    | Round
    | Bevel

    public func toCss(): String {
        match (this) {
            case Miter => "miter"
            case Round => "round"
            case Bevel => "bevel"
        }
    }
}

// ============================================================================
// StrokeDasharray
// 严格翻译自 StrokeDasharray
// ============================================================================

/// stroke-dasharray 属性值
/// 严格翻译自 StrokeDasharray
public enum StrokeDasharray {
    | None                       // 无虚线
    | Values(ArrayList<String>)  // 虚线模式

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Values(vals) => String.join(", ", vals)
        }
    }
}

// ============================================================================
// Marker
// 严格翻译自 Marker
// ============================================================================

/// marker 属性值
/// 严格翻译自 Marker
public enum Marker {
    | None          // 无标记
    | Url(String)   // URL 引用

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Url(u) => "url(" + u + ")"
        }
    }
}

/// color-interpolation 属性值（占位）
/// 严格翻译自 ColorInterpolation
public enum ColorInterpolation {
    | Auto
    | SRGB
    | LinearRGB

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case SRGB => "sRGB"
            case LinearRGB => "linearRGB"
        }
    }
}

/// color-rendering 属性值（占位）
/// 严格翻译自 ColorRendering
public enum ColorRendering {
    | Auto
    | OptimizeSpeed
    | OptimizeQuality

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case OptimizeSpeed => "optimizeSpeed"
            case OptimizeQuality => "optimizeQuality"
        }
    }
}

/// shape-rendering 属性值（占位）
/// 严格翻译自 ShapeRendering
public enum ShapeRendering {
    | Auto
    | OptimizeSpeed
    | CrispEdges
    | GeometricPrecision

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case OptimizeSpeed => "optimizeSpeed"
            case CrispEdges => "crispEdges"
            case GeometricPrecision => "geometricPrecision"
        }
    }
}

/// text-rendering 属性值（占位）
/// 严格翻译自 TextRendering
public enum TextRendering {
    | Auto
    | OptimizeSpeed
    | OptimizeLegibility
    | GeometricPrecision

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case OptimizeSpeed => "optimizeSpeed"
            case OptimizeLegibility => "optimizeLegibility"
            case GeometricPrecision => "geometricPrecision"
        }
    }
}

/// image-rendering 属性值（占位）
/// 严格翻译自 ImageRendering
public enum ImageRendering {
    | Auto
    | Smooth
    | HighQuality
    | CrispEdges
    | Pixelated

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case Smooth => "smooth"
            case HighQuality => "high-quality"
            case CrispEdges => "crisp-edges"
            case Pixelated => "pixelated"
        }
    }
}
