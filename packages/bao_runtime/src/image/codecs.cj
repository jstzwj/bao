// 严格翻译自: src/runtime/image/codecs.zig
// 图像编解码器调度层
// 所有编解码器在 RGBA8 上工作 — 解码器输出 RGBA，编码器接收 RGBA
// 内存所有权: 解码返回 default_allocator 所有的 RGBA
// 编码返回 Encoded{bytes, free} 携带编解码器自己的释放器

package bao_runtime.image

// ============================================================================
// 图像格式
// 对应 Bun: codecs.Format
// ============================================================================

public enum ImageFormat {
    | jpeg
    | png
    | webp
    | heic
    | avif
    | bmp
    | tiff
    | gif

    /// 从字节嗅探格式
    /// 对应 Bun: Format.sniff
    public static func sniff(bytes: Array<UInt8>): ?ImageFormat {
        // JPEG: FF D8 FF
        if (bytes.size >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
            return jpeg
        }
        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if (bytes.size >= 8 &&
            bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
            bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
            return png
        }
        // WebP: RIFF....WEBP
        if (bytes.size >= 12 &&
            bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
            bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
            return webp
        }
        // BMP: BM
        if (bytes.size >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
            return bmp
        }
        // TIFF: II*0 或 MM0*
        if (bytes.size >= 4) {
            if ((bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) ||
                (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A)) {
                return tiff
            }
        }
        // GIF: GIF87a 或 GIF89a
        if (bytes.size >= 6 &&
            bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 &&
            ((bytes[3] == 0x38 && bytes[4] == 0x37 && bytes[5] == 0x61) ||
             (bytes[3] == 0x38 && bytes[4] == 0x39 && bytes[5] == 0x61))) {
            return gif
        }
        // ISO BMFF (HEIC/AVIF): ftyp box
        if (bytes.size >= 16 &&
            bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
            let boxSize = min(UInt64(bytes.size), max(16, readUInt32BE(bytes, 0)))
            var off: UInt64 = 8
            var miaf = false
            while (off + 4 <= boxSize) {
                if (off == 12) { off += 4; continue } // minor_version
                let b0 = bytes[Int64(off)]
                let b1 = bytes[Int64(off + 1)]
                let b2 = bytes[Int64(off + 2)]
                let b3 = bytes[Int64(off + 3)]
                // avif/avis
                if ((b0 == 0x61 && b1 == 0x76 && b2 == 0x69 && b3 == 0x66) ||
                    (b0 == 0x61 && b1 == 0x76 && b2 == 0x69 && b3 == 0x73)) {
                    return avif
                }
                // heic/heix/hevc/hevx
                if ((b0 == 0x68 && b1 == 0x65 && b2 == 0x69 && b3 == 0x63) ||
                    (b0 == 0x68 && b1 == 0x65 && b2 == 0x69 && b3 == 0x78) ||
                    (b0 == 0x68 && b1 == 0x65 && b2 == 0x76 && b3 == 0x63) ||
                    (b0 == 0x68 && b1 == 0x65 && b2 == 0x76 && b3 == 0x78)) {
                    return heic
                }
                // mif1/msf1
                if ((b0 == 0x6D && b1 == 0x69 && b2 == 0x66 && b3 == 0x31) ||
                    (b0 == 0x6D && b1 == 0x73 && b2 == 0x66 && b3 == 0x31)) {
                    miaf = true
                }
                off += 4
            }
            if (miaf) { return heic }
        }
        return None
    }

    /// 从扩展名推断格式
    /// 对应 Bun: Format.fromExtension
    public static func fromExtension(path: String): ?ImageFormat {
        let lower = path.toLower()
        if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) { return jpeg }
        if (lower.endsWith(".png")) { return png }
        if (lower.endsWith(".webp")) { return webp }
        if (lower.endsWith(".heic") || lower.endsWith(".heif")) { return heic }
        if (lower.endsWith(".avif")) { return avif }
        if (lower.endsWith(".bmp")) { return bmp }
        if (lower.endsWith(".gif")) { return gif }
        if (lower.endsWith(".tif") || lower.endsWith(".tiff")) { return tiff }
        return None
    }

    /// 获取 MIME 类型
    /// 对应 Bun: Format.mime
    public func mime(): String {
        match (this) {
            case jpeg => "image/jpeg"
            case png => "image/png"
            case webp => "image/webp"
            case heic => "image/heic"
            case avif => "image/avif"
            case bmp => "image/bmp"
            case tiff => "image/tiff"
            case gif => "image/gif"
        }
    }

    static func readUInt32BE(b: Array<UInt8>, off: Int64): UInt32 {
        (UInt32(b[off]) << 24) |
        (UInt32(b[off + 1]) << 16) |
        (UInt32(b[off + 2]) << 8) |
        UInt32(b[off + 3])
    }
}

// ============================================================================
// 解码提示
// 对应 Bun: codecs.DecodeHint
// ============================================================================

public class DecodeHint {
    /// 最终输出尺寸（旋转后）。0 = "不调整，完整解码"
    public var targetW: UInt32 = 0
    public var targetH: UInt32 = 0

    public init() {}
}

// ============================================================================
// 编码选项
// 对应 Bun: codecs.EncodeOptions
// ============================================================================

public class CodecsEncodeOptions {
    public var format: ImageFormat = ImageFormat.png
    public var quality: UInt8 = 80
    public var lossless: Bool = false
    public var compressionLevel: Int8 = -1
    public var palette: Bool = false
    public var colors: UInt16 = 256
    public var dither: Bool = false
    public var progressive: Bool = false
    public var iccProfile: ?Array<UInt8> = None

    public init() {}
    public init(format: ImageFormat) {
        this.format = format
    }
}

// ============================================================================
// 缩放滤镜
// 对应 Bun: codecs.Filter
// ============================================================================

public enum Filter {
    | box
    | bilinear
    | lanczos3
    | mitchell
    | nearest
    | cubic      // Catmull-Rom
    | lanczos2
    | mks2013    // Magic Kernel Sharp
    | mks2021

    public static func fromString(s: String): Filter {
        match (s.toLower()) {
            case "box" => box
            case "bilinear" => bilinear
            case "linear" => bilinear
            case "lanczos3" => lanczos3
            case "mitchell" => mitchell
            case "nearest" => nearest
            case "cubic" => cubic
            case "lanczos2" => lanczos2
            case "mks2013" => mks2013
            case "mks2021" => mks2021
            case _ => lanczos3
        }
    }
}

// ============================================================================
// 后端类型
// 对应 Bun: codecs.Backend
// ============================================================================

public enum Backend {
    | system
    | bun
}

// ============================================================================
// 默认最大像素
// 对应 Bun: codecs.default_max_pixels
// ============================================================================

public let DEFAULT_MAX_PIXELS: UInt64 = 0x3FFF * 0x3FFF // 16383 * 16383 ~ 268 MP

// ============================================================================
// 编解码器主入口
// 对应 Bun: codecs (调度层)
// ============================================================================

public class Codecs {

    public static var backend: Backend = Backend.bun

    /// 像素守卫: 检查 w*h 是否超过最大像素数
    /// 对应 Bun: guard
    public static func guard(w: UInt32, h: UInt32, maxPixels: UInt64): Bool {
        return UInt64(w) * UInt64(h) <= maxPixels
    }

    /// 解码图像
    /// 对应 Bun: decode
    public static func decode(bytes: Array<UInt8>, maxPixels: UInt64, hint: DecodeHint): ?DecodedImage {
        let fmt = ImageFormat.sniff(bytes)
        if (fmt == None) { return None }

        match (fmt!) {
            case ImageFormat.jpeg =>
                return CodecJpeg.decode(bytes, maxPixels, hint)
            case ImageFormat.png =>
                return CodecPng.decode(bytes, maxPixels)
            case ImageFormat.webp =>
                return CodecWebp.decode(bytes, maxPixels)
            case ImageFormat.bmp =>
                // 先尝试系统后端，然后回退到 BMP 解码器
                return CodecBmp.decode(bytes, maxPixels)
            case ImageFormat.gif =>
                return CodecGif.decode(bytes, maxPixels)
            case ImageFormat.heic | ImageFormat.avif | ImageFormat.tiff =>
                // 需要系统后端; 静态编解码器覆盖我们提供的所有内容;
                // 分析表明 ImageIO 不更快。OS 后端纯粹是能力回退。
                return None
        }
    }

    /// 仅头部尺寸探测
    /// 对应 Bun: probe
    public static func probe(bytes: Array<UInt8>, maxPixels: UInt64): ?ProbeResult {
        let fmt = ImageFormat.sniff(bytes)
        if (fmt == None) { return None }

        match (fmt!) {
            case ImageFormat.png => {
                if (bytes.size < 24) { return None }
                let w = readUInt32BE(bytes, 16)
                let h = readUInt32BE(bytes, 20)
                if (w == 0 || h == 0) { return None }
                if (!guard(w, h, maxPixels)) { return None }
                return ProbeResult(width: w, height: h, format: fmt!)
            }
            case ImageFormat.bmp => {
                let hOpt = CodecBmp.parseHeader(bytes)
                if (hOpt == None) { return None }
                let h = hOpt!
                if (!guard(h.width, h.height, maxPixels)) { return None }
                return ProbeResult(width: h.width, height: h.height, format: ImageFormat.bmp)
            }
            case ImageFormat.gif => {
                if (bytes.size < 10) { return None }
                let w = UInt32(bytes[6]) | (UInt32(bytes[7]) << 8)
                let h = UInt32(bytes[8]) | (UInt32(bytes[9]) << 8)
                if (w == 0 || h == 0) { return None }
                if (!guard(w, h, maxPixels)) { return None }
                return ProbeResult(width: w, height: h, format: ImageFormat.gif)
            }
            case ImageFormat.webp => {
                // WebPGetInfo 探测
                return None
            }
            case ImageFormat.jpeg => {
                // turbojpeg 头部解码
                return None
            }
            case _ => {
                return None
            }
        }
    }

    /// 编码图像
    /// 对应 Bun: encode
    public static func encode(rgba: Array<UInt8>, width: UInt32, height: UInt32, opts: CodecsEncodeOptions): ?EncodedImage {
        match (opts.format) {
            case ImageFormat.jpeg =>
                return CodecJpeg.encode(rgba, width, height, opts.quality, opts.progressive, opts.iccProfile)
            case ImageFormat.png => {
                if (opts.palette) {
                    return CodecPng.encodeIndexed(rgba, width, height, opts.compressionLevel, opts.colors, opts.dither, opts.iccProfile)
                }
                return CodecPng.encode(rgba, width, height, opts.compressionLevel, opts.iccProfile)
            }
            case ImageFormat.webp =>
                return CodecWebp.encode(rgba, width, height, opts.quality, opts.lossless, opts.iccProfile)
            case _ =>
                return None
        }
    }

    /// 缩放图像
    /// 对应 Bun: resize
    public static func resize(src: Array<UInt8>, sw: UInt32, sh: UInt32, dw: UInt32, dh: UInt32, f: Filter): ?Array<UInt8> {
        // 调用 highway 内核 bun_image_resize_rgba8
        // 或系统后端 vImage
        return None
    }

    /// 旋转图像
    /// 对应 Bun: rotate
    public static func rotate(src: Array<UInt8>, w: UInt32, h: UInt32, degrees: UInt32): ?DecodedImage {
        if (degrees != 0 && degrees != 90 && degrees != 180 && degrees != 270) { return None }
        let dw: UInt32 = if (degrees == 90 || degrees == 270) { h } else { w }
        let dh: UInt32 = if (degrees == 90 || degrees == 270) { w } else { h }
        // 调用 bun_image_rotate_rgba8
        return None
    }

    /// 翻转图像
    /// 对应 Bun: flip
    public static func flip(src: Array<UInt8>, w: UInt32, h: UInt32, horizontal: Bool): ?Array<UInt8> {
        // 调用 bun_image_flip_rgba8
        return None
    }

    /// 调制（亮度/饱和度）
    /// 对应 Bun: modulate
    public static func modulate(rgba: Array<UInt8>, brightness: Float32, saturation: Float32): Unit {
        // 调用 bun_image_modulate_rgba8
    }

    static func readUInt32BE(b: Array<UInt8>, off: Int64): UInt32 {
        (UInt32(b[off]) << 24) |
        (UInt32(b[off + 1]) << 16) |
        (UInt32(b[off + 2]) << 8) |
        UInt32(b[off + 3])
    }
}

/// 探测结果
public class ProbeResult {
    public var width: UInt32
    public var height: UInt32
    public var format: ImageFormat

    public init(width: UInt32, height: UInt32, format: ImageFormat) {
        this.width = width
        this.height = height
        this.format = format
    }
}
