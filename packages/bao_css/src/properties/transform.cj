// bao_css - CSS Properties: Transform
// 严格翻译自: bun/src/css/properties/transform.rs
//   对应: transform.zig - CSS 变换属性
//   对应: TransformList, Transform (21 variants)
//   对应: Matrix<T>, Matrix3d<T>
//   对应: TransformStyle, TransformBox, BackfaceVisibility
//   对应: Perspective, Translate, Rotate, Scale
//   对应: TransformHandler
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// TransformList
// 严格翻译自 TransformList
// ============================================================================

/// transform 属性值（变换列表）
/// 严格翻译自 TransformList
public class TransformList {
    public var v: ArrayList<Transform>  // 变换函数列表

    public init() {
        this.v = ArrayList<Transform>()
    }

    public init(v: ArrayList<Transform>) {
        this.v = v
    }

    public func toCss(): String {
        if (v.isEmpty()) {
            return "none"
        }
        var parts = ArrayList<String>()
        for (item in v) {
            parts.append(item.toCss())
        }
        return String.join(" ", parts)
    }
}

// ============================================================================
// Transform
// 严格翻译自 Transform (21 variants)
// ============================================================================

/// 单个变换函数
/// 严格翻译自 Transform
public enum Transform {
    | Translate(String, String)        // translate(x, y)
    | TranslateX(String)               // translateX(x)
    | TranslateY(String)               // translateY(y)
    | TranslateZ(String)               // translateZ(z)
    | Translate3d(String, String, String) // translate3d(x, y, z)
    | Scale(String, String)            // scale(x, y)
    | ScaleX(String)                   // scaleX(x)
    | ScaleY(String)                   // scaleY(y)
    | ScaleZ(String)                   // scaleZ(z)
    | Scale3d(String, String, String)  // scale3d(x, y, z)
    | Rotate(String)                   // rotate(angle)
    | RotateX(String)                  // rotateX(angle)
    | RotateY(String)                  // rotateY(angle)
    | RotateZ(String)                  // rotateZ(angle)
    | Rotate3d(Float64, Float64, Float64, String) // rotate3d(x, y, z, angle)
    | Skew(String, String)             // skew(x, y)
    | SkewX(String)                    // skewX(angle)
    | SkewY(String)                    // skewY(angle)
    | Perspective(String)              // perspective(length)
    | Matrix(Float64, Float64, Float64, Float64, Float64, Float64) // matrix(a,b,c,d,e,f)
    | Matrix3d(Float64, Float64, Float64, Float64, Float64, Float64,
               Float64, Float64, Float64, Float64, Float64, Float64,
               Float64, Float64, Float64, Float64) // matrix3d(m11..m44)

    public func toCss(): String {
        match (this) {
            case Translate(x, y) => "translate(" + x + ", " + y + ")"
            case TranslateX(x) => "translateX(" + x + ")"
            case TranslateY(y) => "translateY(" + y + ")"
            case TranslateZ(z) => "translateZ(" + z + ")"
            case Translate3d(x, y, z) => "translate3d(" + x + ", " + y + ", " + z + ")"
            case Scale(x, y) => "scale(" + x + ", " + y + ")"
            case ScaleX(x) => "scaleX(" + x + ")"
            case ScaleY(y) => "scaleY(" + y + ")"
            case ScaleZ(z) => "scaleZ(" + z + ")"
            case Scale3d(x, y, z) => "scale3d(" + x + ", " + y + ", " + z + ")"
            case Rotate(angle) => "rotate(" + angle + ")"
            case RotateX(angle) => "rotateX(" + angle + ")"
            case RotateY(angle) => "rotateY(" + angle + ")"
            case RotateZ(angle) => "rotateZ(" + angle + ")"
            case Rotate3d(x, y, z, angle) => "rotate3d(" + x.toString() + ", " + y.toString() + ", " + z.toString() + ", " + angle + ")"
            case Skew(x, y) => "skew(" + x + ", " + y + ")"
            case SkewX(angle) => "skewX(" + angle + ")"
            case SkewY(angle) => "skewY(" + angle + ")"
            case Perspective(len) => "perspective(" + len + ")"
            case Matrix(a, b, c, d, e, f) => "matrix(" + a.toString() + ", " + b.toString() + ", " + c.toString() + ", " + d.toString() + ", " + e.toString() + ", " + f.toString() + ")"
            case Matrix3d(m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34, m41, m42, m43, m44) => "matrix3d(" + m11.toString() + ", " + m12.toString() + ", " + m13.toString() + ", " + m14.toString() + ", " + m21.toString() + ", " + m22.toString() + ", " + m23.toString() + ", " + m24.toString() + ", " + m31.toString() + ", " + m32.toString() + ", " + m33.toString() + ", " + m34.toString() + ", " + m41.toString() + ", " + m42.toString() + ", " + m43.toString() + ", " + m44.toString() + ")"
        }
    }
}

// ============================================================================
// TransformStyle
// 严格翻译自 TransformStyle (DefineEnumProperty)
// ============================================================================

/// transform-style 属性值
/// 严格翻译自 TransformStyle
public enum TransformStyle {
    | Flat        // 扁平
    | Preserve3d  // 保留 3D

    public func toCss(): String {
        match (this) {
            case Flat => "flat"
            case Preserve3d => "preserve-3d"
        }
    }
}

// ============================================================================
// TransformBox
// 严格翻译自 TransformBox (DefineEnumProperty)
// ============================================================================

/// transform-box 属性值
/// 严格翻译自 TransformBox
public enum TransformBox {
    | ContentBox  // 内容盒
    | BorderBox   // 边框盒
    | FillBox     // 填充盒
    | StrokeBox   // 描边盒
    | ViewBox     // 视口盒

    public func toCss(): String {
        match (this) {
            case ContentBox => "content-box"
            case BorderBox => "border-box"
            case FillBox => "fill-box"
            case StrokeBox => "stroke-box"
            case ViewBox => "view-box"
        }
    }
}

// ============================================================================
// BackfaceVisibility
// 严格翻译自 BackfaceVisibility (DefineEnumProperty)
// ============================================================================

/// backface-visibility 属性值
/// 严格翻译自 BackfaceVisibility
public enum BackfaceVisibility {
    | Visible  // 可见
    | Hidden   // 隐藏

    public func toCss(): String {
        match (this) {
            case Visible => "visible"
            case Hidden => "hidden"
        }
    }
}

// ============================================================================
// Perspective
// 严格翻译自 Perspective
// ============================================================================

/// perspective 属性值
/// 严格翻译自 Perspective
public enum Perspective {
    | None         // 无透视
    | Length(String) // 投影距离

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Length(l) => l
        }
    }
}

// ============================================================================
// Translate
// 严格翻译自 Translate
// ============================================================================

/// translate 属性值
/// 严格翻译自 Translate
public enum Translate {
    | None                     // "none"
    | Xyz(String, String, String) // x, y, z 平移

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Xyz(x, y, z) => {
                if (z != "0") {
                    x + " " + y + " " + z
                } else if (y != "0") {
                    x + " " + y
                } else {
                    x
                }
            }
        }
    }
}

// ============================================================================
// Rotate
// 严格翻译自 Rotate
// ============================================================================

/// rotate 属性值
/// 严格翻译自 Rotate
public class Rotate {
    public var x: Float64      // X 轴
    public var y: Float64      // Y 轴
    public var z: Float64      // Z 轴
    public var angle: String   // 旋转角度

    public init(x: Float64, y: Float64, z: Float64, angle: String) {
        this.x = x
        this.y = y
        this.z = z
        this.angle = angle
    }

    public static func default(): Rotate {
        Rotate(x: 0.0, y: 0.0, z: 1.0, angle: "0deg")
    }

    public func toCss(): String {
        if (x == 0.0 && y == 0.0 && z == 1.0 && angle == "0deg") {
            return "none"
        }

        if (x == 1.0 && y == 0.0 && z == 0.0) {
            return "x " + angle
        }
        if (x == 0.0 && y == 1.0 && z == 0.0) {
            return "y " + angle
        }
        if (!(x == 0.0 && y == 0.0 && z == 1.0)) {
            return x.toString() + " " + y.toString() + " " + z.toString() + " " + angle
        }
        return angle
    }
}

// ============================================================================
// Scale
// 严格翻译自 Scale
// ============================================================================

/// scale 属性值
/// 严格翻译自 Scale
public enum Scale {
    | None                          // "none"
    | Xyz(String, String, String)   // x, y, z 缩放

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Xyz(x, y, z) => {
                if (z != "1") {
                    x + " " + y + " " + z
                } else if (y != x) {
                    x + " " + y
                } else {
                    x
                }
            }
        }
    }
}
