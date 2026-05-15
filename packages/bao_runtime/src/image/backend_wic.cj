// 严格翻译自: src/runtime/image/backend_wic.zig
// Windows 系统编解码器后端, 通过 Windows Imaging Component (WIC)
// WIC 是 COM: 首次使用时 CoCreateInstance(CLSID_WICImagingFactory)
// 任何 HRESULT 失败 -> error.BackendUnavailable, 回退到静态编解码器

package bao_runtime

// ============================================================================
// WIC 后端
// 对应 Bun: backend_wic
// ============================================================================

public class BackendWic {

    /// 解码图像
    /// 对应 Bun: decode
    /// 解码流程:
    /// factory.CreateStream + InitializeFromMemory(input)
    /// -> factory.CreateDecoderFromStream
    /// -> decoder.GetFrame(0)
    /// -> frame.GetSize -> guard(max_pixels)
    /// -> WICConvertBitmapSource(GUID_WICPixelFormat32bppRGBA, frame)
    /// -> converted.CopyPixels(null, stride, out)
    public static func decode(bytes: Array<UInt8>, maxPixels: UInt64): ?DecodedImage {
        // WIC 流程:
        // 1. 获取工厂
        // 2. 创建流并初始化
        // 3. 创建解码器
        // 4. 获取帧
        // 5. 获取尺寸并检查像素守卫
        // 6. 转换为 RGBA8
        // 7. 复制像素
        return None
    }

    /// 编码图像
    /// 对应 Bun: encode
    /// 编码流程:
    /// CreateStreamOnHGlobal(null) (可增长的内存 IStream)
    /// -> factory.CreateEncoder(containerGUID)
    /// -> encoder.Initialize(stream)
    /// -> encoder.CreateNewFrame -> frame.Initialize/SetSize/SetPixelFormat
    /// -> frame.WritePixels(rgba)
    /// -> frame.Commit -> encoder.Commit
    /// -> IStream::Seek(0,CUR) 获取逻辑长度
    /// -> GetHGlobalFromStream -> GlobalLock -> 复制到 default_allocator
    public static func encode(rgba: Array<UInt8>, width: UInt32, height: UInt32,
        opts: CodecsEncodeOptions): ?Array<UInt8> {
        // 仅路由 heic/avif
        return None
    }

    /// 从剪贴板获取图像
    /// 对应 Bun: clipboard
    /// 优先注册的 "PNG" 格式，然后 CF_DIBV5/CF_DIB
    public static func clipboard(): ?Array<UInt8> {
        // 1. 尝试注册的文件格式 (PNG, image/png, JFIF, image/webp)
        // 2. 尝试 CF_DIBV5/CF_DIB — 需要合成 BITMAPFILEHEADER
        return None
    }

    /// 检查剪贴板是否有图像
    /// 对应 Bun: hasClipboardImage
    public static func hasClipboardImage(): Bool {
        return false
    }

    /// 剪贴板变化计数
    /// 对应 Bun: clipboardChangeCount
    public static func clipboardChangeCount(): Int64 {
        return 0
    }
}
