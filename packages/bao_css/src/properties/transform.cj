// bao_css - CSS Properties: Transform
// 严格翻译自: bun/src/css/properties/transform.zig
//   对应: TransformList, Transform (21 variants)
//   对应: Matrix<T>, Matrix3d<T>
//   对应: TransformStyle, TransformBox, BackfaceVisibility
//   对应: Perspective, Translate, Rotate, Scale
//   对应: TransformHandler
// ============================================================================

package bao_css.properties

import bao_core.*
import bao_collections.*

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

    /// 严格翻译自 TransformList.eql
    public func eql(other: TransformList): Bool {
        if (v.size != other.v.size) { return false }
        for (i in 0..v.size) {
            if (!v[i].eql(other.v[i])) { return false }
        }
        return true
    }

    /// 严格翻译自 TransformList.deepClone
    public func deepClone(): TransformList {
        let copy = ArrayList<Transform>()
        for (item in v) { copy.append(item.deepClone()) }
        TransformList(copy)
    }

    public func toCss(): String {
        if (v.isEmpty()) {
            return "none"
        }
        var parts = ArrayList<String>()
        for (item in v) {
            parts.append(item.toCss())
        }
        var result = ""
        for (i in 0..parts.size) {
            if (i > 0) { result = result + " " }
            result = result + parts[Int64(i)]
        }
        return result
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// Transform
// 严格翻译自 Transform (21 variants)
// ============================================================================

/// 单个变换函数
/// 严格翻译自 Transform union(enum)
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

    /// 严格翻译自 Transform.eql
    public func eql(other: Transform): Bool {
        this.toCss() == other.toCss()
    }

    /// 严格翻译自 Transform.deepClone
    public func deepClone(): Transform {
        this  // enum 值不可变，直接返回
    }

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
// Matrix (2D)
// 严格翻译自 Matrix(T) struct
// ============================================================================

/// 2D 矩阵 (6 个值)
/// 严格翻译自 Matrix(T) struct { a, b, c, d, e, f }
public class CssMatrix {
    public var a: Float64
    public var b: Float64
    public var c: Float64
    public var d: Float64
    public var e: Float64
    public var f: Float64

    public init(a!: Float64, b!: Float64, c!: Float64, d!: Float64, e!: Float64, f!: Float64) {
        this.a = a
        this.b = b
        this.c = c
        this.d = d
        this.e = e
        this.f = f
    }

    /// 严格翻译自 Matrix.eql
    public func eql(other: CssMatrix): Bool {
        a == other.a && b == other.b && c == other.c &&
        d == other.d && e == other.e && f == other.f
    }

    /// 严格翻译自 Matrix.deepClone
    public func deepClone(): CssMatrix {
        CssMatrix(a, b, c, d, e, f)
    }

    public func toCss(): String {
        "matrix(${a}, ${b}, ${c}, ${d}, ${e}, ${f})"
    }
}

// ============================================================================
// Matrix3d
// 严格翻译自 Matrix3d(T) struct
// ============================================================================

/// 3D 矩阵 (4x4 = 16 个值)
/// 严格翻译自 Matrix3d(T) struct { m11..m44 }
public class CssMatrix3d {
    public var m11: Float64
    public var m12: Float64
    public var m13: Float64
    public var m14: Float64
    public var m21: Float64
    public var m22: Float64
    public var m23: Float64
    public var m24: Float64
    public var m31: Float64
    public var m32: Float64
    public var m33: Float64
    public var m34: Float64
    public var m41: Float64
    public var m42: Float64
    public var m43: Float64
    public var m44: Float64

    public init(m11!: Float64, m12!: Float64, m13!: Float64, m14!: Float64,
                m21!: Float64, m22!: Float64, m23!: Float64, m24!: Float64,
                m31!: Float64, m32!: Float64, m33!: Float64, m34!: Float64,
                m41!: Float64, m42!: Float64, m43!: Float64, m44!: Float64) {
        this.m11 = m11; this.m12 = m12; this.m13 = m13; this.m14 = m14
        this.m21 = m21; this.m22 = m22; this.m23 = m23; this.m24 = m24
        this.m31 = m31; this.m32 = m32; this.m33 = m33; this.m34 = m34
        this.m41 = m41; this.m42 = m42; this.m43 = m43; this.m44 = m44
    }

    /// 严格翻译自 Matrix3d.eql
    public func eql(other: CssMatrix3d): Bool {
        m11 == other.m11 && m12 == other.m12 && m13 == other.m13 && m14 == other.m14 &&
        m21 == other.m21 && m22 == other.m22 && m23 == other.m23 && m24 == other.m24 &&
        m31 == other.m31 && m32 == other.m32 && m33 == other.m33 && m34 == other.m34 &&
        m41 == other.m41 && m42 == other.m42 && m43 == other.m43 && m44 == other.m44
    }

    /// 严格翻译自 Matrix3d.deepClone
    public func deepClone(): CssMatrix3d {
        CssMatrix3d(
            m11, m12, m13, m14,
            m21, m22, m23, m24,
            m31, m32, m33, m34,
            m41, m42, m43, m44
        )
    }

    public func toCss(): String {
        "matrix3d(${m11}, ${m12}, ${m13}, ${m14}, ${m21}, ${m22}, ${m23}, ${m24}, ${m31}, ${m32}, ${m33}, ${m34}, ${m41}, ${m42}, ${m43}, ${m44})"
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
/// 严格翻译自 Perspective union(enum) { none, length }
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
/// 严格翻译自 Translate union(enum) { none, xyz }
public enum Translate {
    | None                     // "none"
    | Xyz(String, String, String) // x, y, z 平移

    private func xyzTranslateToCss(x: String, y: String, z: String): String {
        if (z != "0") {
            x + " " + y + " " + z
        } else if (y != "0") {
            x + " " + y
        } else {
            x
        }
    }

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Xyz(x, y, z) => xyzTranslateToCss(x, y, z)
        }
    }

    /// 严格翻译自 Translate.toTransform
    /// 将 translate 属性转为 Transform 函数
    public func toTransform(): Transform {
        match (this) {
            case None => Transform.Translate3d("0", "0", "0")
            case Xyz(x, y, z) => Transform.Translate3d(x, y, z)
        }
    }

    /// 严格翻译自 Translate.eql
    public func eql(other: Translate): Bool {
        this.toCss() == other.toCss()
    }

    /// 严格翻译自 Translate.deepClone
    public func deepClone(): Translate {
        match (this) {
            case None => Translate.None
            case Xyz(x, y, z) => Translate.Xyz(x, y, z)
        }
    }
}

// ============================================================================
// Rotate
// 严格翻译自 Rotate
// ============================================================================

/// rotate 属性值
/// 严格翻译自 Rotate struct { x, y, z, angle }
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
        Rotate(0.0, 0.0, 1.0, "0deg")
    }

    /// 严格翻译自 Rotate.toCss
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

    /// 严格翻译自 Rotate.toTransform
    /// 将 rotate 属性转为 Transform 函数
    public func toTransform(): Transform {
        Transform.Rotate3d(x, y, z, angle)
    }

    /// 严格翻译自 Rotate.eql
    public func eql(other: Rotate): Bool {
        x == other.x && y == other.y && z == other.z && angle == other.angle
    }

    /// 严格翻译自 Rotate.deepClone
    public func deepClone(): Rotate {
        Rotate(x, y, z, angle)
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// Scale
// 严格翻译自 Scale
// ============================================================================

/// scale 属性值
/// 严格翻译自 Scale union(enum) { none, xyz }
public enum Scale {
    | None                          // "none"
    | Xyz(String, String, String)   // x, y, z 缩放

    private func xyzScaleToCss(x: String, y: String, z: String): String {
        if (z != "1") {
            x + " " + y + " " + z
        } else if (y != x) {
            x + " " + y
        } else {
            x
        }
    }

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Xyz(x, y, z) => xyzScaleToCss(x, y, z)
        }
    }

    /// 严格翻译自 Scale.toTransform
    /// 将 scale 属性转为 Transform 函数
    public func toTransform(): Transform {
        match (this) {
            case None => Transform.Scale3d("1", "1", "1")
            case Xyz(x, y, z) => Transform.Scale3d(x, y, z)
        }
    }

    /// 严格翻译自 Scale.eql
    public func eql(other: Scale): Bool {
        this.toCss() == other.toCss()
    }

    /// 严格翻译自 Scale.deepClone
    public func deepClone(): Scale {
        match (this) {
            case None => Scale.None
            case Xyz(x, y, z) => Scale.Xyz(x, y, z)
        }
    }
}

// ============================================================================
// TransformHandler
// 严格翻译自 TransformHandler struct
// ============================================================================

/// Transform 属性处理器
/// 严格翻译自 TransformHandler
/// 管理 transform, translate, rotate, scale 属性之间的交互
public class TransformHandler {
    /// transform 列表和供应商前缀
    public var transform: ?TransformHandlerTransformEntry
    /// translate 属性
    public var translate: ?Translate
    /// rotate 属性
    public var rotate: ?Rotate
    /// scale 属性
    public var scale: ?Scale
    /// 是否有任一属性被设置
    public var hasAny: Bool

    public init() {
        this.transform = None
        this.translate = None
        this.rotate = None
        this.scale = None
        this.hasAny = false
    }

    // ========================================================================
    // handleProperty
    // 严格翻译自 TransformHandler.handleProperty
    // ========================================================================

    /// 处理 transform 相关属性
    /// 严格翻译自 TransformHandler.handleProperty
    /// 返回 true 表示已处理该属性
    public func handleProperty(propertyName: String, propertyValue: Any, dest: ArrayList<String>): Bool {
        match (propertyName) {
            case "transform" =>
                match (propertyValue) {
                    case tl: TransformList =>
                        // 如果已有 transform 且值不同，先 flush
                        match (transform) {
                            case Some(existing) =>
                                if (!existing.transform.eql(tl)) {
                                    flush(dest)
                                }
                            case None => ()
                        }
                        // 更新 transform
                        this.transform = Some(TransformHandlerTransformEntry(tl.deepClone(), ""))
                        this.hasAny = true
                        // 设置 transform 时清除单独的 translate/rotate/scale
                        this.translate = None
                        this.rotate = None
                        this.scale = None
                    case _ => ()
                }
            case "translate" =>
                match (propertyValue) {
                    case v: Translate =>
                        individualProperty("translate", v.deepClone())
                    case _ => ()
                }
            case "rotate" =>
                match (propertyValue) {
                    case v: Rotate =>
                        individualProperty("rotate", v.deepClone())
                    case _ => ()
                }
            case "scale" =>
                match (propertyValue) {
                    case v: Scale =>
                        individualProperty("scale", v.deepClone())
                    case _ => ()
                }
            case _ => return false
        }
        return true
    }

    /// 处理单独的 translate/rotate/scale 属性
    /// 严格翻译自 TransformHandler 中的 individualProperty 闭包
    private func individualProperty(field: String, val: Any): Unit {
        match (field) {
            case "translate" =>
                match (transform) {
                    case Some(t) =>
                        // 如果有 transform，将 translate 转为 transform 函数追加到列表
                        match (val) {
                            case v: Translate => t.transform.v.append(v.toTransform())
                            case _ => ()
                        }
                    case None =>
                        match (val) {
                            case v: Translate => translate = Some(v)
                            case _ => ()
                        }
                        hasAny = true
                }
            case "rotate" =>
                match (transform) {
                    case Some(t) =>
                        match (val) {
                            case v: Rotate => t.transform.v.append(v.toTransform())
                            case _ => ()
                        }
                    case None =>
                        match (val) {
                            case v: Rotate => rotate = Some(v)
                            case _ => ()
                        }
                        hasAny = true
                }
            case "scale" =>
                match (transform) {
                    case Some(t) =>
                        match (val) {
                            case v: Scale => t.transform.v.append(v.toTransform())
                            case _ => ()
                        }
                    case None =>
                        match (val) {
                            case v: Scale => scale = Some(v)
                            case _ => ()
                        }
                        hasAny = true
                }
            case _ => ()
        }
    }

    // ========================================================================
    // finalize
    // 严格翻译自 TransformHandler.finalize
    // ========================================================================

    /// 最终化输出
    /// 严格翻译自 TransformHandler.finalize
    public func finalize(dest: ArrayList<String>): Unit {
        flush(dest)
    }

    // ========================================================================
    // flush
    // 严格翻译自 TransformHandler.flush
    // ========================================================================

    /// 将属性状态输出为 CSS 声明
    /// 严格翻译自 TransformHandler.flush
    public func flush(dest: ArrayList<String>): Unit {
        if (!hasAny) { return }
        hasAny = false

        // 输出 transform
        match (transform) {
            case Some(t) =>
                dest.append("transform: ${t.transform.toCss()}")
                transform = None
            case None => ()
        }

        // 输出 translate
        match (translate) {
            case Some(t) =>
                dest.append("translate: ${t.toCss()}")
                translate = None
            case None => ()
        }

        // 输出 rotate
        match (rotate) {
            case Some(r) =>
                dest.append("rotate: ${r.toCss()}")
                rotate = None
            case None => ()
        }

        // 输出 scale
        match (scale) {
            case Some(s) =>
                dest.append("scale: ${s.toCss()}")
                scale = None
            case None => ()
        }
    }
}

// ============================================================================
// TransformHandlerTransformEntry
// 严格翻译自 TransformHandler 中 transform 字段的结构
// ============================================================================

/// Transform 条目 (TransformList + VendorPrefix)
/// 严格翻译自 TransformHandler 中 struct { TransformList, VendorPrefix }
public class TransformHandlerTransformEntry {
    public var transform: TransformList
    public var vendorPrefix: String

    public init(transform: TransformList, vendorPrefix: String) {
        this.transform = transform
        this.vendorPrefix = vendorPrefix
    }
}
