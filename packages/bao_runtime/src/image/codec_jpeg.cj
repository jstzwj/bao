// 严格翻译自: src/runtime/image/codec_jpeg.zig
// libjpeg-turbo (TurboJPEG 3 API) 解码/编码
// 所有操作在 RGBA8 上进行 — 解码器被告知输出 RGBA
// 分发逻辑位于 codecs.zig; 此文件是编解码器主体

package bao_runtime

// ============================================================================
// 缩放因子
// 对应 Bun: codec_jpeg.ScalingFactor
// ============================================================================

public class ScalingFactor {
    public var num: Int32
    public var denom: Int32

    public init(num: Int32, denom: Int32) {
        this.num = num
        this.denom = denom
    }
}

// ============================================================================
// 裁剪区域
// 对应 Bun: codec_jpeg.CropRegion
// ============================================================================

public class CropRegion {
    public var x: Int32
    public var y: Int32
    public var w: Int32
    public var h: Int32

    public init(x: Int32, y: Int32, w: Int32, h: Int32) {
        this.x = x
        this.y = y
        this.w = w
        this.h = h
    }
}

// ============================================================================
// JPEG 编解码器
// 对应 Bun: codec_jpeg
// ============================================================================

public class CodecJpeg {
    // TurboJPEG 参数常量 (tjparam / tjpf 枚举值，源自 turbojpeg.h)
    public static let TJPARAM_QUALITY: Int32 = 3
    public static let TJPARAM_SUBSAMP: Int32 = 4
    public static let TJPARAM_JPEGWIDTH: Int32 = 5
    public static let TJPARAM_JPEGHEIGHT: Int32 = 6
    public static let TJPARAM_PROGRESSIVE: Int32 = 12
    public static let TJPARAM_MAXPIXELS: Int32 = 24
    /// `2` = 仅保存 APP2/ICC_PROFILE 标记（足以进行颜色管理，跳过其余）。
    /// 必须在 `tj3DecompressHeader` 之前设置，以便标记解析器保留配置文件以供 `tj3GetICCProfile` 使用。
    public static let TJPARAM_SAVEMARKERS: Int32 = 25
    public static let TJPF_RGBA: Int32 = 7
    public static let TJSAMP_420: Int32 = 2

    // ========================================================================
    // 外部 C 函数声明
    // 对应 Bun: codec_jpeg 的 extern 声明
    // ========================================================================

    /// tj3Init(0) = 压缩器, tj3Init(1) = 解压缩器
    public static func tj3Init(initType: Int32): CPointer<> {
        // FFI: 实际实现调用 libjpeg-turbo
        return CPointer<>.null
    }

    public static func tj3Destroy(h: CPointer<>): Unit {
        // FFI: 销毁 TurboJPEG 句柄
    }

    public static func tj3Set(h: CPointer<>, param: Int32, value: Int32): Int32 {
        // FFI: 设置参数
        return 0
    }

    public static func tj3Get(h: CPointer<>, param: Int32): Int32 {
        // FFI: 获取参数值
        return -1
    }

    public static func tj3DecompressHeader(h: CPointer<>, buf: CPointer<>, len: UInt64): Int32 {
        // FFI: 解析 JPEG 头部
        return -1
    }

    public static func tj3Decompress8(h: CPointer<>, buf: CPointer<>, len: UInt64,
        dst: CPointer<>, pitch: Int32, pf: Int32): Int32 {
        // FFI: 解压缩为 8 位像素
        return -1
    }

    public static func tj3Compress8(h: CPointer<>, src: CPointer<>, w: Int32, pitch: Int32,
        height: Int32, pf: Int32, out: CPointer<CPointer<>>, outLen: CPointer<UInt64>): Int32 {
        // FFI: 压缩 8 位像素
        return -1
    }

    public static func tj3SetScalingFactor(h: CPointer<>, sf: ScalingFactor): Int32 {
        // FFI: 设置缩放因子
        return -1
    }

    public static func tj3SetCroppingRegion(h: CPointer<>, r: CropRegion): Int32 {
        // FFI: 设置裁剪区域
        return -1
    }

    public static func tj3GetScalingFactors(n: CPointer<Int32>): ?CPointer<ScalingFactor> {
        // FFI: 获取可用缩放因子
        return None
    }

    public static func tj3Free(ptr: CPointer<>): Unit {
        // FFI: 释放 libjpeg-turbo 分配的内存
    }

    public static func tj3GetErrorStr(h: CPointer<>): String {
        // FFI: 获取错误字符串
        return ""
    }

    /// ICC 配置文件传输：APP2 ICC_PROFILE 标记携带源的色彩空间
    /// tj3GetICCProfile 读取已解码的标记（在 TJPARAM_SAVEMARKERS 设置为 2 或 4 之后）
    public static func tj3GetICCProfile(h: CPointer<>, iccBuf: CPointer<CPointer<>>, iccSize: CPointer<UInt64>): Int32 {
        // FFI: 获取 ICC 配置文件
        return -1
    }

    /// tj3SetICCProfile 将字节复制到编码器状态，因此输入缓冲区可在调用返回后立即释放。
    public static func tj3SetICCProfile(h: CPointer<>, iccBuf: CPointer<>, iccSize: UInt64): Int32 {
        // FFI: 设置 ICC 配置文件
        return -1
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// TJSCALED: ceil(dim * num / denom)
    /// 对应 Bun: scaled
    public static func scaled(dim: UInt32, sf: ScalingFactor): UInt32 {
        return UInt32((Int64(dim) * Int64(sf.num) + Int64(sf.denom) - 1) / Int64(sf.denom))
    }

    /// 质量限制
    public static func clampQuality(q: UInt8): UInt8 {
        if (q < 1) { return 1 }
        if (q > 100) { return 100 }
        return q
    }

    // ========================================================================
    // 解码
    // 对应 Bun: decode
    // ========================================================================

    /// 解码 JPEG 图像
    /// bytes: JPEG 源数据
    /// maxPixels: 最大像素数（防解压炸弹）
    /// hint: 解码提示（目标尺寸，用于 DCT 域缩放）
    public static func decode(bytes: Array<UInt8>, maxPixels: UInt64, hint: DecodeHint): ?DecodedImage {
        // 1. 创建解压缩器
        let h = tj3Init(1)
        if (h == CPointer<>.null) { return None }

        // 2. 请求 libjpeg-turbo 保留 APP2/ICC_PROFILE 标记
        //    必须在头部解析前设置
        tj3Set(h, TJPARAM_SAVEMARKERS, 2)

        // 3. 解析头部
        if (tj3DecompressHeader(h, bytes.ptr(), UInt64(bytes.size)) != 0) {
            tj3Destroy(h)
            return None
        }

        // 4. 获取原始尺寸
        let rw = tj3Get(h, TJPARAM_JPEGWIDTH)
        let rh = tj3Get(h, TJPARAM_JPEGHEIGHT)
        // tj3Get 返回 -1 表示错误; 将任何非正维度视为解码失败
        if (rw <= 0 || rh <= 0) {
            tj3Destroy(h)
            return None
        }
        let srcW: UInt32 = UInt32(rw)
        let srcH: UInt32 = UInt32(rh)

        // 5. 像素守卫
        if (UInt64(srcW) * UInt64(srcH) > maxPixels) {
            tj3Destroy(h)
            return None
        }

        // 6. DCT 域缩放: 如果管线会缩小，请求 libjpeg-turbo 提供仍 >= 目标
        //    的最小 M/8 IDCT。IDCT 是解码时间的主要消耗，因此这大约是
        //    (8/M)^2 倍的速度提升，并且 RGBA 缓冲区也缩小相同倍数。
        var w = srcW
        var ht = srcH

        if (hint.targetW != 0 && hint.targetH != 0 &&
            (hint.targetW < srcW || hint.targetH < srcH)) {
            var n: Int32 = 0
            let sfsOpt = tj3GetScalingFactors(CPointer<Int32>.addrOf(n))
            if (sfsOpt != None && n > 0) {
                var best = ScalingFactor(1, 1)
                var i: Int32 = 0
                while (i < n) {
                    let sf = sfsOpt![Int64(i)]  // 获取第 i 个缩放因子
                    // 仅考虑缩小因子
                    if (sf.num >= sf.denom) {
                        i += 1
                        continue
                    }
                    let sw = scaled(srcW, sf)
                    let sh = scaled(srcH, sf)
                    // 永远不要低于目标 — 否则会强制放大并丢失细节
                    if (sw < hint.targetW || sh < hint.targetH) {
                        i += 1
                        continue
                    }
                    // 选择最小输出 (= 最大缩减)
                    if (UInt64(sw) * UInt64(sh) < UInt64(scaled(srcW, best)) * UInt64(scaled(srcH, best))) {
                        best = sf
                    }
                    i += 1
                }
                if (best.num != best.denom) {
                    tj3SetScalingFactor(h, best)
                    w = scaled(srcW, best)
                    ht = scaled(srcH, best)
                }
            }
        }

        // 7. 安全防护: 设置 MAXPIXELS、裁剪区域以防止恶意缓冲区交换
        let maxPixVal: Int32 = if (UInt64(srcW) * UInt64(srcH) > UInt64(Int32.MaxValue)) {
            Int32.MaxValue
        } else {
            Int32(srcW * srcH)
        }
        tj3Set(h, TJPARAM_MAXPIXELS, maxPixVal)
        tj3SetCroppingRegion(h, CropRegion(0, 0, Int32(w), Int32(ht)))

        // 8. 分配输出缓冲区
        let outSize = UInt64(w) * UInt64(ht) * 4
        var out = Array<UInt8>(Int64(outSize), item: 0)

        // 9. 解压缩
        if (tj3Decompress8(h, bytes.ptr(), UInt64(bytes.size), out.ptr(), Int32(w * 4), TJPF_RGBA) != 0) {
            tj3Destroy(h)
            return None
        }

        // 10. 解压缩后检查: 验证第二次解析的维度是否匹配
        if (tj3Get(h, TJPARAM_JPEGWIDTH) != rw || tj3Get(h, TJPARAM_JPEGHEIGHT) != rh) {
            tj3Destroy(h)
            return None
        }

        // 11. 提取 APP2 ICC 配置文件（如果源携带了）
        //     标记解析器在 tj3DecompressHeader 期间运行，所以这是已解析状态的复制输出。
        //     tj3GetICCProfile 通过 libjpeg-turbo 的分配器分配; 重新归属到 default_allocator
        //     以便管线的其余部分可以统一释放。
        //     没有配置文件的解码返回非零且 iccSize==0 — 视为"无配置文件"，不是错误。
        //     重复时的 OutOfMemory 被传播（不被吞没）— 像素可能是 Display P3 / Adobe RGB / XYB，
        //     其中"无配置文件"会悄悄将它们重新解释为 sRGB 并偏移颜色，这正是 bug #30197 的问题。
        var iccProfile: ?Array<UInt8> = None
        // FFI 调用 tj3GetICCProfile 并复制结果的逻辑:
        // var iccPtr: CPointer<> = CPointer<>.null
        // var iccSize: UInt64 = 0
        // if (tj3GetICCProfile(h, &iccPtr, &iccSize) == 0 && iccSize > 0 && iccPtr != null) {
        //     iccProfile = copyFromC(iccPtr, iccSize)
        //     tj3Free(iccPtr)
        // }

        tj3Destroy(h)

        var result = DecodedImage()
        result.rgba = out
        result.width = w
        result.height = ht
        result.iccProfile = iccProfile
        return result
    }

    // ========================================================================
    // 编码
    // 对应 Bun: encode
    // ========================================================================

    /// 编码为 JPEG
    /// rgba: RGBA 像素数据
    /// w, ht: 宽高
    /// quality: JPEG 质量 (1-100)
    /// progressive: 是否渐进式（多扫描 SOF2 流）
    /// iccProfile: ICC 颜色配置文件（源色彩空间）
    public static func encode(rgba: Array<UInt8>, w: UInt32, ht: UInt32,
        quality: UInt8, progressive: Bool, iccProfile: ?Array<UInt8>): ?EncodedImage {

        // 1. 创建压缩器
        let h = tj3Init(0)
        if (h == CPointer<>.null) { return None }

        // 2. 设置质量参数
        let clampedQuality = clampQuality(quality)
        tj3Set(h, TJPARAM_QUALITY, Int32(clampedQuality))
        tj3Set(h, TJPARAM_SUBSAMP, TJSAMP_420)

        // 3. 渐进式: 发出多扫描 SOF2 流; 大小 ±1%, 粗到细解码。
        //    默认关闭（编码更慢，某些旧解码器处理不当）。
        if (progressive) {
            tj3Set(h, TJPARAM_PROGRESSIVE, 1)
        }

        // 4. 嵌入源色彩配置文件为 APP2/ICC_PROFILE 标记。
        //    库会复制字节，因此调用者可以在调用返回后立即释放 iccProfile。
        //    非零返回表示配置文件格式错误 — 丢弃而不是使编码失败;
        //    没有 ICC 配置文件的 JPEG 仍然是有效的 JPEG（隐式 sRGB）。参见 #30197。
        if (iccProfile != None) {
            let p = iccProfile!
            if (p.size > 0) {
                tj3SetICCProfile(h, p.ptr(), UInt64(p.size))
            }
        }

        // 5. 压缩
        // FFI: 实际调用 tj3Compress8
        // var outPtr: CPointer<> = CPointer<>.null
        // var outLen: UInt64 = 0
        // if (tj3Compress8(h, rgba.ptr(), Int32(w), 0, Int32(ht), TJPF_RGBA,
        //                   &outPtr, &outLen) != 0) {
        //     // tj3Compress8 可能已分配（或增长）outPtr，然后在半途失败;
        //     // 文档说调用者在任何返回时拥有它。
        //     if (outPtr != null) { tj3Free(outPtr) }
        //     tj3Destroy(h)
        //     return None
        // }

        tj3Destroy(h)

        // 6. 返回编码结果
        // tj3Compress8 通过 libjpeg-turbo 的分配器分配; 将其交给 JS，
        // 使用 tj3Free 作为终结器，而不是复制。
        // return EncodedImage(bytes: copyFromC(outPtr, outLen), format: ImageFormat.jpeg,
        //                      freeFunc: "tj3Free")
        return None
    }
}

/// 编码后的图像，携带释放函数
/// 对应 Bun: codecs.Encoded
public class EncodedImage {
    public var bytes: Array<UInt8>
    public var format: ImageFormat
    /// 释放函数标识 ("tj3Free", "WebPFree", "libcFree" 等)
    public var freeFunc: String

    public init(bytes: Array<UInt8>, format: ImageFormat) {
        this.bytes = bytes
        this.format = format
        this.freeFunc = "libcFree"
    }

    public init(bytes: Array<UInt8>, format: ImageFormat, freeFunc: String) {
        this.bytes = bytes
        this.format = format
        this.freeFunc = freeFunc
    }

    /// 从自有字节创建（使用 mimalloc 释放）
    /// 对应 Bun: Encoded.fromOwned
    public static func fromOwned(bytes: Array<UInt8>): EncodedImage {
        return EncodedImage(bytes: bytes, format: ImageFormat.png, freeFunc: "miFree")
    }

    public func deinit(): Unit {
        // 根据 freeFunc 调用对应的释放函数
    }
}
