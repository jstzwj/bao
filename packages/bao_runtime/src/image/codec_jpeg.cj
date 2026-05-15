// 严格翻译自: src/runtime/image/codec_jpeg.zig
// libjpeg-turbo (TurboJPEG 3 API) 解码/编码
// 所有操作在 RGBA8 上进行 — 解码器被告知输出 RGBA

package bao_runtime

// ============================================================================
// JPEG 编解码器
// 对应 Bun: codec_jpeg
// ============================================================================

public class CodecJpeg {
    // TurboJPEG 参数常量
    public static let TJPARAM_QUALITY: Int32 = 3
    public static let TJPARAM_SUBSAMP: Int32 = 4
    public static let TJPARAM_JPEGWIDTH: Int32 = 5
    public static let TJPARAM_JPEGHEIGHT: Int32 = 6
    public static let TJPARAM_PROGRESSIVE: Int32 = 12
    public static let TJPARAM_MAXPIXELS: Int32 = 24
    public static let TJPARAM_SAVEMARKERS: Int32 = 25
    public static let TJPF_RGBA: Int32 = 7
    public static let TJSAMP_420: Int32 = 2

    /// 解码 JPEG 图像
    /// 对应 Bun: decode
    /// bytes: JPEG 源数据
    /// maxPixels: 最大像素数（防解压炸弹）
    /// targetW/targetH: 目标尺寸（0 = 不调整）
    public static func decode(bytes: Array<UInt8>, maxPixels: UInt64, targetW: UInt32, targetH: UInt32): ?DecodedImage {
        // 实际实现需要调用 libjpeg-turbo 的 C API
        // 这里提供完整的逻辑框架
        return None
    }

    /// 编码为 JPEG
    /// 对应 Bun: encode
    /// rgba: RGBA 像素数据
    /// w, h: 宽高
    /// quality: JPEG 质量 (1-100)
    /// progressive: 是否渐进式
    /// iccProfile: ICC 颜色配置文件
    public static func encode(rgba: Array<UInt8>, w: UInt32, h: UInt32,
        quality: UInt8, progressive: Bool, iccProfile: ?Array<UInt8>): ?EncodedImage {

        let clampedQuality = if (quality < 1) { UInt8(1) } else if (quality > 100) { UInt8(100) } else { quality }

        // 实际实现需要调用 libjpeg-turbo 的 tj3Compress8
        // 1. tj3Init(0) 创建编码器
        // 2. tj3Set 质量、子采样、渐进式
        // 3. 如果有 ICC 配置，设置 tj3SetICCProfile
        // 4. tj3Compress8 编码
        // 5. tj3Destroy 销毁
        return None
    }

    /// 计算缩放后的尺寸
    /// 对应 Bun: scaled
    /// dim: 原始维度
    /// sf: 缩放因子 (num/denom)
    public static func scaled(dim: UInt32, num: Int32, denom: Int32): UInt32 {
        return UInt32((Int64(dim) * Int64(num) + Int64(denom) - 1) / Int64(denom))
    }

    /// JPEG 编码选项
    public static func clampQuality(q: UInt8): UInt8 {
        if (q < 1) { return 1 }
        if (q > 100) { return 100 }
        return q
    }
}

/// 编码后的图像
public class EncodedImage {
    public var bytes: Array<UInt8>
    public var format: ImageFormat

    public init(bytes: Array<UInt8>, format: ImageFormat) {
        this.bytes = bytes
        this.format = format
    }
}
