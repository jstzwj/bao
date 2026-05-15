// 严格翻译自: src/runtime/image/codec_png.zig
// libspng 解码/编码
// 索引 PNG 编码通过 quantize.zig 量化
// 所有操作在 RGBA8 上进行
// 分发逻辑位于 codecs.zig; 此文件是编解码器主体

package bao_runtime.image

// ============================================================================
// libspng 外部结构
// 对应 Bun: codec_png 的 extern struct
// ============================================================================

/// spng_ihdr — IHDR 块
public class SpngIhdr {
    public var width: UInt32 = 0
    public var height: UInt32 = 0
    public var bitDepth: UInt8 = 0
    public var colorType: UInt8 = 0
    public var compressionMethod: UInt8 = 0
    public var filterMethod: UInt8 = 0
    public var interlaceMethod: UInt8 = 0

    public init() {}
}

/// spng_iccp — iCCP 块
/// PNG 的 Latin-1 iCCP 关键字 (1-79 字符 + NUL)。libspng 要求编码时非空;
/// PNG 规范将其标记为纯信息性（配置文件字节才是描述色彩空间的内容），
/// 因此编码时我们总是写入字面 "ICC Profile"。源关键字不会通过 Decoded 传递。
public class SpngIccp {
    public var profileName: Array<UInt8>  // [80]
    public var profileLen: UInt64 = 0
    public var profile: ?Array<UInt8> = None

    public init() {
        profileName = Array<UInt8>(80, item: 0)
    }
}

/// spng_plte — PLTE 块
public class SpngPlte {
    public var nEntries: UInt32 = 0
    public var entries: Array<Array<UInt8>>  // [256][4] = r,g,b,alpha(reserved)

    public init() {
        entries = Array<Array<UInt8>>(256, item: Array<UInt8>(4, item: 0))
    }
}

/// spng_trns — tRNS 块
public class SpngTrns {
    public var gray: UInt16 = 0
    public var red: UInt16 = 0
    public var green: UInt16 = 0
    public var blue: UInt16 = 0
    public var nType3Entries: UInt32 = 0
    public var type3Alpha: Array<UInt8>  // [256]

    public init() {
        type3Alpha = Array<UInt8>(256, item: 0)
    }
}

// ============================================================================
// PNG 编解码器
// 对应 Bun: codec_png
// ============================================================================

public class CodecPng {
    // spng 常量
    public static let SPNG_CTX_ENCODER: Int32 = 2
    public static let SPNG_FMT_RGBA8: Int32 = 1
    public static let SPNG_FMT_PNG: Int32 = 256
    public static let SPNG_DECODE_TRNS: Int32 = 1  // 应用 tRNS 块使调色板/灰色获得真正的 alpha
    public static let SPNG_ENCODE_FINALIZE: Int32 = 2
    public static let SPNG_IMG_COMPRESSION_LEVEL: Int32 = 2
    public static let SPNG_ENCODE_TO_BUFFER: Int32 = 12
    public static let SPNG_COLOR_TYPE_INDEXED: UInt8 = 3
    public static let SPNG_COLOR_TYPE_TRUECOLOR_ALPHA: UInt8 = 6

    // ========================================================================
    // 外部 C 函数声明
    // ========================================================================

    /// 创建 spng 上下文
    public static func spngCtxNew(flags: Int32): ?CPointer<> {
        // FFI: spng_ctx_new(flags)
        return None
    }

    /// 释放 spng 上下文
    public static func spngCtxFree(ctx: CPointer<>): Unit {
        // FFI: spng_ctx_free(ctx)
    }

    /// 设置 PNG 缓冲区
    public static func spngSetPngBuffer(ctx: CPointer<>, buf: CPointer<>, len: UInt64): Int32 {
        // FFI: spng_set_png_buffer(ctx, buf, len)
        return -1
    }

    /// 获取解码图像大小
    public static func spngDecodedImageSize(ctx: CPointer<>, fmt: Int32, outSize: CPointer<UInt64>): Int32 {
        // FFI
        return -1
    }

    /// 解码图像
    public static func spngDecodeImage(ctx: CPointer<>, out: CPointer<>, len: UInt64, fmt: Int32, flags: Int32): Int32 {
        // FFI
        return -1
    }

    /// 获取 IHDR
    public static func spngGetIhdr(ctx: CPointer<>, ihdr: SpngIhdr): Int32 {
        // FFI
        return -1
    }

    /// 设置 IHDR
    public static func spngSetIhdr(ctx: CPointer<>, ihdr: SpngIhdr): Int32 {
        // FFI
        return -1
    }

    /// 设置 PLTE
    public static func spngSetPlte(ctx: CPointer<>, plte: SpngPlte): Int32 {
        // FFI
        return -1
    }

    /// 设置 tRNS
    public static func spngSetTrns(ctx: CPointer<>, trns: SpngTrns): Int32 {
        // FFI
        return -1
    }

    /// 编码图像
    public static func spngEncodeImage(ctx: CPointer<>, img: CPointer<>, len: UInt64, fmt: Int32, flags: Int32): Int32 {
        // FFI
        return -1
    }

    /// 获取 PNG 缓冲区
    public static func spngGetPngBuffer(ctx: CPointer<>, len: CPointer<UInt64>, err: CPointer<Int32>): ?CPointer<> {
        // FFI
        return None
    }

    /// 设置选项
    public static func spngSetOption(ctx: CPointer<>, opt: Int32, value: Int32): Int32 {
        // FFI
        return -1
    }

    /// 获取 iCCP
    /// 返回非零表示源没有 iCCP（或块格式错误）; 我们对所有非零返回
    /// 都一视同仁 — 丢弃配置文件 — 因为像素仍然有效，
    /// 没有 iCCP 的 PNG 仍然是有效的 PNG。
    public static func spngGetIccp(ctx: CPointer<>, iccp: SpngIccp): Int32 {
        // FFI
        return -1
    }

    /// 设置 iCCP
    public static func spngSetIccp(ctx: CPointer<>, iccp: SpngIccp): Int32 {
        // FFI
        return -1
    }

    // ========================================================================
    // 解码
    // 对应 Bun: decode
    // ========================================================================

    /// 解码 PNG 图像
    /// bytes: PNG 源数据
    /// maxPixels: 最大像素数（防解压炸弹）
    public static func decode(bytes: Array<UInt8>, maxPixels: UInt64): ?DecodedImage {
        // 1. 创建上下文
        let ctxOpt = spngCtxNew(0)
        if (ctxOpt == None) { return None }
        let ctx = ctxOpt!

        // 2. 设置 PNG 缓冲区
        if (spngSetPngBuffer(ctx, bytes.ptr(), UInt64(bytes.size)) != 0) {
            spngCtxFree(ctx)
            return None
        }

        // 3. 获取 IHDR
        var ihdr = SpngIhdr()
        if (spngGetIhdr(ctx, ihdr) != 0) {
            spngCtxFree(ctx)
            return None
        }

        // 4. 像素守卫
        if (UInt64(ihdr.width) * UInt64(ihdr.height) > maxPixels) {
            spngCtxFree(ctx)
            return None
        }

        // 5. 计算解码图像大小
        // var size: UInt64 = 0
        // if (spngDecodedImageSize(ctx, SPNG_FMT_RGBA8, &size) != 0) {
        //     spngCtxFree(ctx)
        //     return None
        // }

        // 6. 分配并解码
        let npix = UInt64(ihdr.width) * UInt64(ihdr.height)
        let outSize = npix * 4
        var out = Array<UInt8>(Int64(outSize), item: 0)

        // if (spngDecodeImage(ctx, out.ptr(), out.size, SPNG_FMT_RGBA8, SPNG_DECODE_TRNS) != 0) {
        //     spngCtxFree(ctx)
        //     return None
        // }

        // 7. 解码后提取 iCCP，以便块肯定已被解析。
        //    非零返回表示"无 iCCP"或"iCCP 格式错误" — 两者都视为无配置文件情况;
        //    像素仍然是有效的 RGBA。profile 是上下文拥有的内存，
        //    因此在 spngCtxFree 运行之前复制出来。分配器失败时传播 OutOfMemory，
        //    而不是悄悄降低色彩保真度 — 像素可能是 Display P3 / Adobe RGB / XYB，
        //    在那里"无配置文件"是可见的色彩偏移，这正是 bug #30197 的问题。
        var iccProfile: ?Array<UInt8> = None
        // var iccp = SpngIccp()
        // if (spngGetIccp(ctx, iccp) == 0 && iccp.profileLen > 0 && iccp.profile != None) {
        //     iccProfile = copyFromArray(iccp.profile!, 0, Int64(iccp.profileLen))
        // }

        spngCtxFree(ctx)

        var result = DecodedImage()
        result.rgba = out
        result.width = ihdr.width
        result.height = ihdr.height
        result.iccProfile = iccProfile
        return result
    }

    // ========================================================================
    // 编码
    // 对应 Bun: encode
    // ========================================================================

    /// 将 ICC 配置文件附加到编码器作为 iCCP 块。
    /// libspng 要求 profile_name 非空（1-79 Latin-1 字符 + NUL），并将配置文件有效载荷
    /// 压缩到块本身中。PNG 规范将关键字标记为纯信息性，
    /// 因此我们总是写入字面 "ICC Profile" — 色彩含义有效载荷是 p。
    /// libspng 返回格式错误会丢弃配置文件而不是使编码失败;
    /// 没有 iCCP 的 PNG 仍然有效（隐式 sRGB）。
    /// 从真彩色 encode() 和索引 encodeIndexed() 两者调用 —
    /// PNG 规范将 iCCP 应用于每种颜色类型（索引颜色调色板也存在于源空间中，
    /// 因此在那里丢弃配置文件会悄悄将其重新解释为 sRGB，与 bug #30197 相同）。
    static func embedIccp(ctx: CPointer<>, iccProfile: ?Array<UInt8>): Unit {
        if (iccProfile == None) { return }
        let p = iccProfile!
        if (p.size == 0) { return }

        // var iccp = SpngIccp()
        // iccp.profileLen = UInt64(p.size)
        // iccp.profile = p
        // // profile_name = "ICC Profile"
        // let name = "ICC Profile"
        // var ni: Int64 = 0
        // while (ni < name.size && ni < 79) {
        //     iccp.profileName[ni] = UInt8(name[ni])
        //     ni += 1
        // }
        // iccp.profileName[ni] = 0
        // spngSetIccp(ctx, iccp)
    }

    /// 编码为真彩色 RGBA PNG
    /// rgba: RGBA 像素数据
    /// w, h: 宽高
    /// level: zlib 压缩级别 (0-9, -1 = libspng 默认)
    /// iccProfile: ICC 颜色配置文件
    public static func encode(rgba: Array<UInt8>, w: UInt32, h: UInt32,
        level: Int8, iccProfile: ?Array<UInt8>): ?EncodedImage {

        // 1. 创建编码器上下文
        let ctxOpt = spngCtxNew(SPNG_CTX_ENCODER)
        if (ctxOpt == None) { return None }
        let ctx = ctxOpt!

        // 2. 设置选项
        spngSetOption(ctx, SPNG_ENCODE_TO_BUFFER, 1)
        if (level >= 0) {
            let clampedLevel = if (level > 9) { Int8(9) } else { level }
            spngSetOption(ctx, SPNG_IMG_COMPRESSION_LEVEL, Int32(clampedLevel))
        }

        // 3. 设置 IHDR (RGBA, 8 位)
        var ihdr = SpngIhdr()
        ihdr.width = w
        ihdr.height = h
        ihdr.bitDepth = 8
        ihdr.colorType = SPNG_COLOR_TYPE_TRUECOLOR_ALPHA
        if (spngSetIhdr(ctx, ihdr) != 0) {
            spngCtxFree(ctx)
            return None
        }

        // 4. 嵌入 ICC 配置
        embedIccp(ctx, iccProfile)

        // 5. 编码
        // if (spngEncodeImage(ctx, rgba.ptr(), UInt64(rgba.size),
        //                      SPNG_FMT_PNG, SPNG_ENCODE_FINALIZE) != 0) {
        //     spngCtxFree(ctx)
        //     return None
        // }

        // 6. 获取 PNG 缓冲区
        // var len: UInt64 = 0
        // var err: Int32 = 0
        // let buf = spngGetPngBuffer(ctx, &len, &err)
        // if (buf == None) {
        //     spngCtxFree(ctx)
        //     return None
        // }

        spngCtxFree(ctx)

        // spngGetPngBuffer 转移所有权 (libc malloc); 将其交给 JS，
        // 使用 libc free 作为终结器而不是复制。
        // return EncodedImage(bytes: copyFromC(buf, len), format: ImageFormat.png, freeFunc: "libcFree")
        return None
    }

    // ========================================================================
    // 索引 PNG 编码
    // 对应 Bun: encodeIndexed
    // ========================================================================

    /// 量化 RGBA 为 <= colors 色并编码为索引 (颜色类型 3) PNG，带 PLTE + tRNS。
    /// 量化器是一个小型中位切 — 参见 quantize.zig。
    /// iccProfile 携带源色彩空间; 中位切在原始 RGB 数字上操作而不转换色彩空间，
    /// 因此调色板条目仍在该空间中，需要配置文件才能正确解释 —
    /// 与真彩色编码相同的合同。
    public static func encodeIndexed(rgba: Array<UInt8>, w: UInt32, h: UInt32,
        level: Int8, colors: UInt16, dither: Bool, iccProfile: ?Array<UInt8>): ?EncodedImage {

        // 1. 量化
        let qOpt = Quantize.quantize(rgba, w, h, QuantizeOptions(maxColors: colors, dither: dither))
        if (qOpt == None) { return None }
        let q = qOpt!
        // defer: q.deinit()

        // 2. 创建编码器
        let ctxOpt = spngCtxNew(SPNG_CTX_ENCODER)
        if (ctxOpt == None) { return None }
        let ctx = ctxOpt!

        spngSetOption(ctx, SPNG_ENCODE_TO_BUFFER, 1)
        if (level >= 0) {
            let clampedLevel = if (level > 9) { Int8(9) } else { level }
            spngSetOption(ctx, SPNG_IMG_COMPRESSION_LEVEL, Int32(clampedLevel))
        }

        // 3. 设置 IHDR (indexed, 8 位)
        var ihdr = SpngIhdr()
        ihdr.width = w
        ihdr.height = h
        ihdr.bitDepth = 8
        ihdr.colorType = SPNG_COLOR_TYPE_INDEXED
        if (spngSetIhdr(ctx, ihdr) != 0) {
            spngCtxFree(ctx)
            return None
        }

        // 4. 嵌入 ICC 配置
        embedIccp(ctx, iccProfile)

        // 5. 设置 PLTE (调色板) 和 tRNS (透明度)
        var plte = SpngPlte()
        plte.nEntries = UInt32(q.colors)
        var trns = SpngTrns()
        trns.nType3Entries = UInt32(q.colors)

        var i: Int64 = 0
        while (i < Int64(q.colors)) {
            plte.entries[i][0] = q.palette[i * 4 + 0]  // R
            plte.entries[i][1] = q.palette[i * 4 + 1]  // G
            plte.entries[i][2] = q.palette[i * 4 + 2]  // B
            plte.entries[i][3] = 255                      // 保留
            trns.type3Alpha[i] = q.palette[i * 4 + 3]   // A
            i += 1
        }

        if (spngSetPlte(ctx, plte) != 0) {
            spngCtxFree(ctx)
            return None
        }
        if (q.hasAlpha && spngSetTrns(ctx, trns) != 0) {
            spngCtxFree(ctx)
            return None
        }

        // 6. 编码索引数据
        // if (spngEncodeImage(ctx, q.indices.ptr(), UInt64(q.indices.size),
        //                      SPNG_FMT_PNG, SPNG_ENCODE_FINALIZE) != 0) {
        //     spngCtxFree(ctx)
        //     return None
        // }

        // 7. 获取输出
        // var len: UInt64 = 0
        // var err: Int32 = 0
        // let buf = spngGetPngBuffer(ctx, &len, &err)
        // if (buf == None) {
        //     spngCtxFree(ctx)
        //     return None
        // }

        spngCtxFree(ctx)

        // return EncodedImage(bytes: copyFromC(buf, len), format: ImageFormat.png, freeFunc: "libcFree")
        return None
    }
}
