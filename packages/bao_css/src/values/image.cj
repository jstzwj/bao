// bao_css - CSS 图像值类型
// 严格翻译自: bun/src/css/values/image.rs
//   对应: values/image.zig - Image, ImageSet
package bao_css.values

import bao_core.*
import bao_collections.*

// ============================================================================
// 图像
// 严格翻译自: values/image.rs Image enum
// ============================================================================

/// CSS <image> 值
/// 严格翻译自 Image enum { None, Url, Gradient, ImageSet }
public class CssImage {
    public enum CssImageKind {
        | None        // none 关键字
        | Url         // url()
        | Gradient    // 渐变
        | ImageSet    // image-set()
    }

    public var kind: CssImageKind
    /// URL
    public var url: String
    /// 渐变
    public var gradient: ?CssGradient
    /// Image-set
    public var imageSet: ?CssImageSet

    public init() {
        this.kind = CssImageKind.None
        this.url = ""
        this.gradient = None
        this.imageSet = None
    }

    public init(url: String) {
        this.kind = CssImageKind.Url
        this.url = url
        this.gradient = None
        this.imageSet = None
    }

    public init(gradient: CssGradient) {
        this.kind = CssImageKind.Gradient
        this.url = ""
        this.gradient = Some(gradient)
        this.imageSet = None
    }

    public init(imageSet: CssImageSet) {
        this.kind = CssImageKind.ImageSet
        this.url = ""
        this.gradient = None
        this.imageSet = Some(imageSet)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Image.to_css
    public func toCss(): String {
        match (kind) {
            case None => "none"
            case Url => "url(\"${url}\")"
            case Gradient => {
                match (gradient) {
                    case Some(g) => g.toCss()
                    case None => ""
                }
            }
            case ImageSet => {
                match (imageSet) {
                    case Some(s) => s.toCss()
                    case None => ""
                }
            }
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// Image-set 项
// ============================================================================

/// CSS image-set() 选项
public class CssImageSetItem {
    /// 图像
    public var image: CssImage
    /// 分辨率
    public var resolution: String

    public init(image: CssImage, resolution: String) {
        this.image = image
        this.resolution = resolution
    }

    public func toCss(): String {
        "${image.toCss()} ${resolution}"
    }
}

// ============================================================================
// Image-set
// ============================================================================

/// CSS image-set()
/// 严格翻译自 ImageSet struct
public class CssImageSet {
    /// 选项列表
    public var items: ArrayList<CssImageSetItem>

    public init(items: ArrayList<CssImageSetItem>) {
        this.items = items
    }

    public func toCss(): String {
        let parts = ArrayList<String>()
        for (item in items) {
            parts.append(item.toCss())
        }
        "image-set(${String.join(", ", parts)})"
    }

    public func toString(): String {
        toCss()
    }
}
