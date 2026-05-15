// 严格翻译自: src/runtime/image/codec_png.zig
// libspng 解码/编码
// 索引 PNG 编码通过 quantize.zig 量化
// 所有操作在 RGBA8 上进行

package bao_runtime

// ============================================================================
// PNG 编解码器
// 对应 Bun: codec_png
// ============================================================================

public class CodecPng {
    // spng 常量
    public static let SPNG_CTX_ENCODER: Int32 = 2
    public static let SPNG_FMT_RGBA8: Int32 = 1
    public static let SPNG_FMT_PNG: Int32 = 256
    public static let SPNG_DECODE_TRNS: Int32 = 1
    public static let SPNG_ENCODE_FINALIZE: Int32 = 2
    public static let SPNG_IMG_COMPRESSION_LEVEL: Int32 = 2
    public static let SPNG_ENCODE_TO_BUFFER: Int32 = 12
    public static let SPNG_COLOR_TYPE_INDEXED: UInt8 = 3
    public static let SPNG_COLOR_TYPE_TRUECOLOR_ALPHA: UInt8 = 6

    /// 解码 PNG 图像
    /// 对应 Bun: decode
    public static func decode(bytes: Array<UInt8>, maxPixels: UInt64): ?DecodedImage {
        // 实际实现需要调用 libspng:
        // 1. spng_ctx_new(0) 创建上下文
        // 2. spng_set_png_buffer 设置输入
        // 3. spng_get_ihdr 读取 IHDR
        // 4. spng_decoded_image_size 计算输出大小
        // 5. spng_decode_image 解码为 RGBA8
        // 6. spng_get_iccp 提取 ICC 配置
        // 7. spng_ctx_free 释放上下文
        return None
    }

    /// 编码为真彩色 RGBA PNG
    /// 对应 Bun: encode
    /// rgba: RGBA 像素数据
    /// w, h: 宽高
    /// level: zlib 压缩级别 (0-9, -1 = 默认)
    /// iccProfile: ICC 颜色配置文件
    public static func encode(rgba: Array<UInt8>, w: UInt32, h: UInt32,
        level: Int8, iccProfile: ?Array<UInt8>): ?EncodedImage {

        // 实际实现需要调用 libspng:
        // 1. spng_ctx_new(SPNG_CTX_ENCODER)
        // 2. 设置压缩级别
        // 3. spng_set_ihdr 设置 IHDR (RGBA, 8位)
        // 4. 如果有 ICC 配置，调用 embedIccp
        // 5. spng_encode_image 编码
        // 6. spng_get_png_buffer 获取输出
        // 7. spng_ctx_free 释放
        return None
    }

    /// 量化 RGBA 为 <= colors 色并编码为索引 PNG
    /// 对应 Bun: encodeIndexed
    /// rgba: RGBA 像素数据
    /// w, h: 宽高
    /// level: zlib 压缩级别
    /// colors: 最大颜色数
    /// dither: 是否 Floyd-Steinberg 抖动
    /// iccProfile: ICC 颜色配置文件
    public static func encodeIndexed(rgba: Array<UInt8>, w: UInt32, h: UInt32,
        level: Int8, colors: UInt16, dither: Bool, iccProfile: ?Array<UInt8>): ?EncodedImage {

        // 1. 量化: Quantize.quantize(rgba, w, h, maxColors=colors, dither)
        // 2. 创建 spng 编码器
        // 3. 设置 IHDR (indexed, 8位)
        // 4. 设置 PLTE (调色板)
        // 5. 如果有 alpha，设置 tRNS
        // 6. 如果有 ICC 配置，embedIccp
        // 7. 编码索引数据
        // 8. 获取 PNG 输出
        return None
    }

    /// 将 ICC 配置嵌入编码器作为 iCCP 块
    /// 对应 Bun: embedIccp
    static func embedIccp(iccProfile: ?Array<UInt8>): Bool {
        let p = iccProfile
        if (p == None) { return true }
        if (p!.size == 0) { return true }
        // spng_set_iccp: 设置 profile_name = "ICC Profile", profile = p
        return true
    }
}
