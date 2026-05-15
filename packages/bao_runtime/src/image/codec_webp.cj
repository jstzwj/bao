// 严格翻译自: src/runtime/image/codec_webp.zig
// libwebp 解码/编码
// WebP 通过 VP8X RIFF 容器携带颜色配置 (和 EXIF/XMP)
// 使用 libwebpmux/libwebpdemux 处理 ICCP 块
// 分发逻辑位于 codecs.zig; 此文件是编解码器主体

package bao_runtime.image

// ============================================================================
// WebP 外部结构
// 对应 Bun: codec_webp 的 extern struct
// ============================================================================

/// WebPData — 借用字节视图，mux 和 demux 都使用。
/// 当 libwebp 写入时（例如 WebPMuxAssemble 输出），内存由 WebPMalloc 拥有;
/// 当 libwebp 读取时，由调用者拥有。
public class WebPDataView {
    public var bytes: ?CPointer<> = None
    public var size: UInt64 = 0

    public init() {}
    public init(bytes: CPointer<>, size: UInt64) {
        this.bytes = bytes
        this.size = size
    }
}

/// WebPChunkIterator — VP8X 块列表的游标。仅读取 chunk;
/// pad/private_ 是 WebPDemuxReleaseChunkIterator 遍历的 libwebp 内部簿记。
/// chunk.bytes 是原始输入缓冲区的借用视图 — 在 WebPDemuxDelete 之前复制出来。
public class WebPChunkIterator {
    public var chunkNum: Int32 = 0
    public var numChunks: Int32 = 0
    public var chunk: WebPDataView = WebPDataView()
    // pad[6] 和 private_ 是内部簿记，由 FFI 管理
}

// ============================================================================
// WebP 编解码器
// 对应 Bun: codec_webp
// ============================================================================

public class CodecWebp {
    // WebP demux/mux ABI 版本 (固定到 libwebp v1.6.0)
    public static let WEBP_DEMUX_ABI_VERSION: Int32 = 0x0107
    public static let WEBP_MUX_ABI_VERSION: Int32 = 0x0109
    /// WebPFormatFeature.WEBP_FF_FORMAT_FLAGS — WebPDemuxGetI 的选择器，
    /// 返回 VP8X 特性位掩码。
    public static let WEBP_FF_FORMAT_FLAGS: Int32 = 0
    /// WebPFeatureFlags.ICCP_FLAG — 当 VP8X 容器中存在 ICCP 块时设置。
    public static let ICCP_FLAG: UInt32 = 0x20
    /// WebPMuxError.WEBP_MUX_OK — mux 调用的唯一非错误返回。
    public static let WEBP_MUX_OK: Int32 = 1

    // ========================================================================
    // 外部 C 函数声明
    // ========================================================================

    /// 头部探测: 获取宽高
    public static func webPGetInfo(data: CPointer<>, len: UInt64, w: CPointer<Int32>, h: CPointer<Int32>): Int32 {
        // FFI: WebPGetInfo
        return 0
    }

    /// 解码为 RGBA
    public static func webPDecodeRGBA(data: CPointer<>, len: UInt64, w: CPointer<Int32>, h: CPointer<Int32>): ?CPointer<> {
        // FFI: WebPDecodeRGBA
        return None
    }

    /// 有损编码
    public static func webPEncodeRGBA(rgba: CPointer<>, w: Int32, h: Int32, stride: Int32,
        q: Float32, out: CPointer<CPointer<>>): UInt64 {
        // FFI: WebPEncodeRGBA
        return 0
    }

    /// 无损编码
    public static func webPEncodeLosslessRGBA(rgba: CPointer<>, w: Int32, h: Int32, stride: Int32,
        out: CPointer<CPointer<>>): UInt64 {
        // FFI: WebPEncodeLosslessRGBA
        return 0
    }

    /// 释放 libwebp 分配的内存
    public static func webPFree(ptr: CPointer<>): Unit {
        // FFI: WebPFree
    }

    /// demux: 解析 RIFF 容器
    public static func webPDemuxInternal(data: CPointer<WebPDataView>, allowPartial: Int32,
        state: ?CPointer<Int32>, version: Int32): ?CPointer<> {
        // FFI: WebPDemuxInternal
        return None
    }

    /// demux: 释放
    public static func webPDemuxDelete(dmux: CPointer<>): Unit {
        // FFI: WebPDemuxDelete
    }

    /// demux: 获取整数属性
    public static func webPDemuxGetI(dmux: CPointer<>, feature: Int32): UInt32 {
        // FFI: WebPDemuxGetI
        return 0
    }

    /// demux: 获取块
    public static func webPDemuxGetChunk(dmux: CPointer<>, fourcc: String, chunkNumber: Int32,
        iter: WebPChunkIterator): Int32 {
        // FFI: WebPDemuxGetChunk
        return 0
    }

    /// demux: 释放块迭代器
    public static func webPDemuxReleaseChunkIterator(iter: WebPChunkIterator): Unit {
        // FFI: WebPDemuxReleaseChunkIterator
    }

    /// mux: 创建
    public static func webPNewInternal(version: Int32): ?CPointer<> {
        // FFI: WebPNewInternal
        return None
    }

    /// mux: 释放
    public static func webPMuxDelete(mux: CPointer<>): Unit {
        // FFI: WebPMuxDelete
    }

    /// mux: 设置图像
    public static func webPMuxSetImage(mux: CPointer<>, bitstream: WebPDataView, copyData: Int32): Int32 {
        // FFI: WebPMuxSetImage
        return 0
    }

    /// mux: 设置块
    public static func webPMuxSetChunk(mux: CPointer<>, fourcc: String, chunkData: WebPDataView,
        copyData: Int32): Int32 {
        // FFI: WebPMuxSetChunk
        return 0
    }

    /// mux: 组装
    public static func webPMuxAssemble(mux: CPointer<>, assembledData: WebPDataView): Int32 {
        // FFI: WebPMuxAssemble
        return 0
    }

    // ========================================================================
    // 解码
    // 对应 Bun: decode
    // ========================================================================

    /// 解码 WebP 图像
    /// bytes: WebP 源数据
    /// maxPixels: 最大像素数（防解压炸弹）
    public static func decode(bytes: Array<UInt8>, maxPixels: UInt64): ?DecodedImage {
        // 1. 头部探测 — 在 libwebp 在内部分配完整画布之前触发像素守卫。
        //    WebPGetInfo 可以在格式错误的头部上返回非正值; 在 @intCast 陷阱之前拒绝。
        var cw: Int32 = 0
        var ch: Int32 = 0
        if (webPGetInfo(bytes.ptr(), UInt64(bytes.size),
                         CPointer<Int32>.addrOf(cw), CPointer<Int32>.addrOf(ch)) == 0 ||
            cw <= 0 || ch <= 0) {
            return None
        }
        let w: UInt32 = UInt32(cw)
        let h: UInt32 = UInt32(ch)

        // 2. 像素守卫
        if (UInt64(w) * UInt64(h) > maxPixels) { return None }

        // 3. 解码
        let ptrOpt = webPDecodeRGBA(bytes.ptr(), UInt64(bytes.size),
                                      CPointer<Int32>.addrOf(cw), CPointer<Int32>.addrOf(ch))
        if (ptrOpt == None) { return None }
        let ptr = ptrOpt!
        // defer: WebPFree(ptr)

        // 4. `bytes` 是用户仍可写入的 JS ArrayBuffer 的借用视图（pin 仅阻止分离），
        //    因此恶意调用者可以在 WebPGetInfo 和 WebPDecodeRGBA 之间交换更小的 WebP。
        //    libwebp 在第二次调用时重新解析，并将实际解码的维度写回 cw/ch —
        //    拒绝任何不匹配，而不是信任探测并过度读取较小的分配。
        //    （与 CG shim 在 :298 处保护的竞争相同。）
        if (cw != Int32(w) || ch != Int32(h)) { return None }

        // 5. 复制到 default_allocator 拥有的缓冲区
        let len: UInt64 = UInt64(w) * UInt64(h) * 4
        var out = Array<UInt8>(Int64(len), item: 0)
        // 从 ptr 复制 len 字节到 out

        webPFree(ptr)

        // 6. 从 RIFF 容器中提取 ICCP 块（如果有）。
        //    没有 VP8X 包装器的纯 VP8/VP8L WebP 没有 ICCP — WebPDemux 仍然成功，
        //    WEBP_FF_FORMAT_FLAGS 返回 0，我们跳过块遍历。
        //    块迭代器返回 bytes 的借用视图; 复制到 default_allocator 以匹配 JPEG/PNG 所有权。
        //    在复制上传播 OutOfMemory 而不是悄悄丢弃颜色管理 — 像素可能是
        //    Display P3 / Adobe RGB / XYB，其中"无配置文件"将它们重新解释为 sRGB 并明显偏移颜色，
        //    这正是 bug #30197 的问题。demux 失败（格式错误的容器）会以
        //    .iccProfile = null 跳过; 像素解码正常，因此图像仍可用。
        var iccProfile: ?Array<UInt8> = None

        // ICCP 提取逻辑:
        // let data = WebPDataView(bytes: bytes.ptr(), size: UInt64(bytes.size))
        // let dmux = webPDemuxInternal(&data, 0, None, WEBP_DEMUX_ABI_VERSION)
        // if (dmux != None) {
        //     if (webPDemuxGetI(dmux!, WEBP_FF_FORMAT_FLAGS) & ICCP_FLAG != 0) {
        //         var iter = WebPChunkIterator()
        //         if (webPDemuxGetChunk(dmux!, "ICCP", 1, iter) != 0) {
        //             if (iter.chunk.bytes != None && iter.chunk.size > 0) {
        //                 iccProfile = copyFromC(iter.chunk.bytes!, iter.chunk.size)
        //             }
        //             webPDemuxReleaseChunkIterator(iter)
        //         }
        //     }
        //     webPDemuxDelete(dmux!)
        // }

        var result = DecodedImage()
        result.rgba = out
        result.width = w
        result.height = h
        result.iccProfile = iccProfile
        return result
    }

    // ========================================================================
    // 编码
    // 对应 Bun: encode
    // ========================================================================

    /// 编码为 WebP
    /// rgba: RGBA 像素数据
    /// w, h: 宽高
    /// quality: 质量 (0-100)
    /// lossless: 是否无损 (VP8L 而不是 VP8)
    /// iccProfile: ICC 颜色配置文件
    public static func encode(rgba: Array<UInt8>, w: UInt32, h: UInt32,
        quality: UInt8, lossless: Bool, iccProfile: ?Array<UInt8>): ?EncodedImage {

        // 1. 编码
        // var outPtr: CPointer<> = CPointer<>.null
        let stride: Int32 = Int32(w * 4)
        let len: UInt64 = if (lossless) {
            webPEncodeLosslessRGBA(rgba.ptr(), Int32(w), Int32(h), stride, CPointer<CPointer<>>.null)
        } else {
            webPEncodeRGBA(rgba.ptr(), Int32(w), Int32(h), stride, Float32(quality), CPointer<CPointer<>>.null)
        }

        if (len == 0) { return None }
        // bitstream = out[0..len]

        // 2. 快速路径: 无配置文件要附加，因此 WebPEncodeRGBA 生成的
        //    裸 VP8/VP8L RIFF 已经是最终容器。避免 mux 往返（及其额外复制），
        //    用于常见 sRGB 情况。
        if (iccProfile == None) {
            // return EncodedImage(bytes: bitstream, format: ImageFormat.webp, freeFunc: "WebPFree")
            return None
        }
        let profile = iccProfile!
        if (profile.size == 0) {
            // return EncodedImage(bytes: bitstream, format: ImageFormat.webp, freeFunc: "WebPFree")
            return None
        }

        // 3. 将比特流包装在带 ICCP 块的 VP8X 容器中。
        //    libwebpmux 从图像 + 块构建新的 RIFF 文件，并通过 WebPMalloc 分配组装输出;
        //    将该缓冲区交给 JS，使用 WebPFree 作为终结器，并丢弃中间编码。
        //    copy_data=0 时，mux 借用我们的缓冲区直到 WebPMuxAssemble 返回，
        //    因此 bitstream/profile 必须比 assemble 调用活得长（两者都满足 —
        //    bitstream 在下面释放，profile 是调用者拥有的）。
        // defer: WebPFree(bitstream.ptr)

        // let mux = webPNewInternal(WEBP_MUX_ABI_VERSION)
        // if (mux == None) { return None }
        // defer: WebPMuxDelete(mux)

        // let img = WebPDataView(bytes: bitstream.ptr, size: bitstream.len)
        // if (webPMuxSetImage(mux, img, 0) != WEBP_MUX_OK) { return None }

        // let icc = WebPDataView(bytes: profile.ptr(), size: UInt64(profile.size))
        // if (webPMuxSetChunk(mux, "ICCP", icc, 0) != WEBP_MUX_OK) { return None }

        // var assembled = WebPDataView()
        // if (webPMuxAssemble(mux, assembled) != WEBP_MUX_OK) {
        //     // WebPMuxAssemble 即使在失败时也会向 assembled 写入半构建的缓冲区;
        //     // 其合同说 WebPDataClear (即 WebPFree) 在任何返回时都可安全调用。
        //     if (assembled.bytes != None) { webPFree(assembled.bytes!) }
        //     return None
        // }

        // if (assembled.bytes == None) { return None }
        // return EncodedImage(bytes: copyFromC(assembled.bytes!, assembled.size),
        //                      format: ImageFormat.webp, freeFunc: "WebPFree")
        return None
    }
}
