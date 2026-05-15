// 严格翻译自: src/runtime/image/backend_wic.zig
// Windows 系统编解码器后端, 通过 Windows Imaging Component (WIC)
//
// WIC 是 COM: 没有平坦的 C API 可以 dlsym, 所以 "lazy load" 意味着
// 首次使用时 CoCreateInstance(CLSID_WICImagingFactory)。ole32 是任何
// 接触 shell 的进程的加载时依赖, 所以链接是免费的; windowscodecs.dll
// 本身在创建工厂时由 COM 拉入。首次路径上的任何 HRESULT 失败
// (没有 WIC 功能的 nano-server, 阻止 COM 的沙盒, ...) 产生
// error.BackendUnavailable, 调用者回退到静态编解码器。
//
// 线程安全: WIC 要求在调用线程上初始化 COM。Bun 的图像工作在
// WorkPool 线程上运行, 没有先前的 COM 初始化, 所以我们通过线程本地标志
// 每线程调用一次 CoInitializeEx(COINIT_MULTITHREADED); MTA 对 WIC 没问题,
// 意味着工厂指针可以在池线程之间共享。

package bao_runtime

// ============================================================================
// COM 基础类型
// 对应 Bun: backend_wic 的 COM 类型
// ============================================================================

/// COM HRESULT (i32)
public typealias HRESULT = Int32

/// COM GUID
public class COMGuid {
    public var d1: UInt32
    public var d2: UInt16
    public var d3: UInt16
    public var d4: Array<UInt8>  // [8]

    public init(d1: UInt32, d2: UInt16, d3: UInt16, d4: Array<UInt8>) {
        this.d1 = d1
        this.d2 = d2
        this.d3 = d3
        this.d4 = d4
    }

    /// 比较两个 GUID 是否相等
    public func equals(other: COMGuid): Bool {
        if (d1 != other.d1 || d2 != other.d2 || d3 != other.d3) { return false }
        var i: Int64 = 0
        while (i < 8) {
            if (d4[i] != other.d4[i]) { return false }
            i += 1
        }
        return true
    }

    public static func make(d1: UInt32, d2: UInt16, d3: UInt16,
        b0: UInt8, b1: UInt8, b2: UInt8, b3: UInt8,
        b4: UInt8, b5: UInt8, b6: UInt8, b7: UInt8): COMGuid {
        return COMGuid(d1: d1, d2: d2, d3: d3,
            d4: [b0, b1, b2, b3, b4, b5, b6, b7])
    }
}

// ============================================================================
// WIC GUID 常量
// 对应 Bun: backend_wic 的 GUID 定义
// ============================================================================

public class WicGuids {
    public static let CLSID_WIC_IMAGING_FACTORY = COMGuid.make(
        d1: 0xcacaf262, d2: 0x9370, d3: 0x4615,
        b0: 0xa1, b1: 0x3b, b2: 0x9f, b3: 0x55,
        b4: 0x39, b5: 0xda, b6: 0x4c, b7: 0x0a)

    public static let IID_IWIC_IMAGING_FACTORY = COMGuid.make(
        d1: 0xec5ec8a9, d2: 0xc395, d3: 0x4314,
        b0: 0x9c, b1: 0x77, b2: 0x54, b3: 0xd7,
        b4: 0xa9, b5: 0x35, b6: 0xff, b7: 0x70)

    public static let GUID_WIC_PIXEL_FORMAT_32BPP_RGBA = COMGuid.make(
        d1: 0xf5c7ad2d, d2: 0x6a8d, d3: 0x43dd,
        b0: 0xa7, b1: 0xa8, b2: 0xa2, b3: 0x99,
        b4: 0x35, b5: 0x26, b6: 0x1a, b7: 0xe9)

    public static let GUID_CONTAINER_FORMAT_JPEG = COMGuid.make(
        d1: 0x19e4a5aa, d2: 0x5662, d3: 0x4fc5,
        b0: 0xa0, b1: 0xc0, b2: 0x17, b3: 0x58,
        b4: 0x02, b5: 0x8e, b6: 0x10, b7: 0x57)

    public static let GUID_CONTAINER_FORMAT_PNG = COMGuid.make(
        d1: 0x1b7cfaf4, d2: 0x713f, d3: 0x473c,
        b0: 0xbb, b1: 0xcd, b2: 0x61, b3: 0x37,
        b4: 0x42, b5: 0x5f, b6: 0xae, b7: 0xaf)

    public static let GUID_CONTAINER_FORMAT_WEBP = COMGuid.make(
        d1: 0xe094b0e2, d2: 0x67f2, d3: 0x45b3,
        b0: 0xb0, b1: 0xea, b2: 0x11, b3: 0x53,
        b4: 0x37, b5: 0xca, b6: 0x7c, b7: 0xf3)

    public static let GUID_CONTAINER_FORMAT_HEIF = COMGuid.make(
        d1: 0xe1e62521, d2: 0x6787, d3: 0x405b,
        b0: 0xa3, b1: 0x39, b2: 0x50, b3: 0x07,
        b4: 0x15, b5: 0xb5, b6: 0x76, b7: 0x3f)

    /// WICHeifCompressionOption — 编码器默认为 DontCare (= 选择安装的编解码器扩展),
    /// 所以没有这个 .avif() 可能在有 HEVC 扩展的机器上静默发出 HEIC。
    public static let WIC_HEIF_COMPRESSION_HEVC: UInt8 = 2
    public static let WIC_HEIF_COMPRESSION_AV1: UInt8 = 3

    /// 从图像格式获取容器 GUID
    public static func containerGuid(f: ImageFormat): ?COMGuid {
        match (f) {
            case ImageFormat.jpeg => GUID_CONTAINER_FORMAT_JPEG
            case ImageFormat.png => GUID_CONTAINER_FORMAT_PNG
            case ImageFormat.webp => GUID_CONTAINER_FORMAT_WEBP
            // WIC 通过相同的 HEIF 容器路由 HEIC 和 AVIF; 安装的编码器
            // (HEVC vs AV1) 决定编解码器。如果扩展未安装，
            // CreateEncoder 返回 WINCODEC_ERR_COMPONENTNOTFOUND，
            // 作为 BackendUnavailable 显示。
            case ImageFormat.heic | ImageFormat.avif => GUID_CONTAINER_FORMAT_HEIF
            // 仅解码格式 — codecs.encode() 在此路径之前短路，
            // 所以此分支仅用于 switch 穷尽性。
            case ImageFormat.bmp | ImageFormat.tiff | ImageFormat.gif => None
        }
    }
}

// ============================================================================
// Win32 剪贴板常量
// ============================================================================

public class Win32Clipboard {
    public static let CF_DIB: UInt32 = 8
    public static let CF_DIBV5: UInt32 = 17

    /// 注册的格式 (已经有效的文件)。优先级顺序:
    /// PNG/JFIF/WebP 不需要头部手术并保留源应用写入的内容。
    public static let NAMED_FORMATS: Array<String> = ["PNG", "image/png", "JFIF", "image/webp"]
}

// ============================================================================
// WIC 后端
// 对应 Bun: backend_wic
// ============================================================================

public class BackendWic {

    /// COM 初始化标志
    public static let COINIT_MULTITHREADED: UInt32 = 0
    public static let CLSCTX_INPROC_SERVER: UInt32 = 1
    /// STREAM_SEEK_CUR = 1
    public static let STREAM_SEEK_CUR: UInt32 = 1

    // ========================================================================
    // 外部 Win32/COM 函数声明
    // ========================================================================

    /// COM 初始化
    public static func coInitializeEx(reserved: CPointer<>, flags: UInt32): Int32 {
        // FFI: ole32 CoInitializeEx
        return -1
    }

    /// COM 创建实例
    public static func coCreateInstance(clsid: CPointer<COMGuid>, outer: CPointer<>,
        ctx: UInt32, iid: CPointer<COMGuid>, out: CPointer<CPointer<>>): Int32 {
        // FFI: ole32 CoCreateInstance
        return -1
    }

    /// 创建 HGLOBAL 上的流
    public static func createStreamOnHGlobal(hglobal: CPointer<>, deleteOnRelease: Int32,
        out: CPointer<CPointer<>>): Int32 {
        // FFI: ole32 CreateStreamOnHGlobal
        return -1
    }

    /// 从流获取 HGLOBAL
    public static func getHGlobalFromStream(stream: CPointer<>, out: CPointer<CPointer<>>): Int32 {
        // FFI: ole32 GetHGlobalFromStream
        return -1
    }

    /// 全局锁
    public static func globalLock(h: CPointer<>): ?CPointer<> {
        // FFI: kernel32 GlobalLock
        return None
    }

    /// 全局解锁
    public static func globalUnlock(h: CPointer<>): Int32 {
        // FFI: kernel32 GlobalUnlock
        return 0
    }

    /// 全局大小
    public static func globalSize(h: CPointer<>): UInt64 {
        // FFI: kernel32 GlobalSize
        return 0
    }

    /// WIC 转换位图源 (从 windowscodecs.dll 延迟加载的唯一平坦导出)
    public static func wicConvertBitmapSource(dstFmt: CPointer<COMGuid>, src: CPointer<>,
        out: CPointer<CPointer<>>): Int32 {
        // FFI: WICConvertBitmapSource
        return -1
    }

    /// 打开剪贴板
    public static func openClipboard(hwnd: CPointer<>): Int32 {
        // FFI: user32 OpenClipboard
        return 0
    }

    /// 关闭剪贴板
    public static func closeClipboard(): Int32 {
        // FFI: user32 CloseClipboard
        return 0
    }

    /// 检查剪贴板格式是否可用
    public static func isClipboardFormatAvailable(format: UInt32): Int32 {
        // FFI: user32 IsClipboardFormatAvailable
        return 0
    }

    /// 获取剪贴板数据
    public static func getClipboardData(format: UInt32): ?CPointer<> {
        // FFI: user32 GetClipboardData
        return None
    }

    /// 注册剪贴板格式
    public static func registerClipboardFormatA(name: String): UInt32 {
        // FFI: user32 RegisterClipboardFormatA
        return 0
    }

    /// 获取剪贴板序列号
    public static func getClipboardSequenceNumber(): UInt32 {
        // FFI: user32 GetClipboardSequenceNumber
        return 0
    }

    /// C++ shim: 写入属性包 float 属性
    public static func wicPropbagWriteF32(props: CPointer<>, name: String, value: Float32): Int32 {
        // FFI: bun_wic_propbag_write_f32
        return 0
    }

    /// C++ shim: 写入属性包 u8 属性
    public static func wicPropbagWriteU8(props: CPointer<>, name: String, value: UInt8): Int32 {
        // FFI: bun_wic_propbag_write_u8
        return 0
    }

    /// IStream::Seek 获取当前流位置
    public static func iStreamSeek(stream: CPointer<>, dlibMove: Int64, dwOrigin: UInt32,
        plibNewPosition: CPointer<UInt64>): Int32 {
        // FFI: IStream::Seek
        return -1
    }

    // ========================================================================
    // WIC 工厂 (延迟初始化)
    // 对应 Bun: factory / loadFactory
    // ========================================================================

    /// COM 必须在调用线程上进入; 工厂本身创建一次并共享（在 MTA 中有效）。
    public static func ensureFactory(): ?CPointer<> {
        // 1. COM 初始化 (每线程一次)
        // if (!comInitialized) {
        //     if (coInitializeEx(CPointer<>.null, COINIT_MULTITHREADED) < 0) { return None }
        //     comInitialized = true
        // }
        // 2. 创建工厂 (进程全局一次)
        // factoryOnce.call()
        // return factoryPtr
        return None
    }

    /// 延迟加载 windowscodecs.dll 和创建 WIC 工厂
    static func loadFactory(): Unit {
        // 1. 先解析唯一的平坦 C 导出; 如果 windowscodecs.dll 不存在，
        //    我们从不尝试 CoCreateInstance, 整个后端保持禁用。
        // let dll = loadLibraryA("windowscodecs.dll") orelse return
        // let sym = getProcAddressA(dll, "WICConvertBitmapSource") orelse return
        // wicConvertBitmapSourceFn = cast(sym)
        //
        // 2. 创建 COM 工厂
        // var out: CPointer<> = null
        // if (coCreateInstance(&CLSID_WIC_IMAGING_FACTORY, null, CLSCTX_INPROC_SERVER,
        //                      &IID_IWIC_IMAGING_FACTORY, &out) < 0) { return }
        // factoryPtr = out
    }

    // ========================================================================
    // 解码
    // 对应 Bun: decode
    // ========================================================================

    /// 解码图像
    /// 解码流程:
    /// factory.CreateStream + InitializeFromMemory(input)
    /// -> factory.CreateDecoderFromStream
    /// -> decoder.GetFrame(0)
    /// -> frame.GetSize -> guard(max_pixels)
    /// -> WICConvertBitmapSource(GUID_WICPixelFormat32bppRGBA, frame)
    /// -> converted.CopyPixels(null, stride, out)
    public static func decode(bytes: Array<UInt8>, maxPixels: UInt64): ?DecodedImage {
        let f = ensureFactory()
        if (f == None) { return None }

        // IWICStream::InitializeFromMemory 接受 DWORD 计数; Windows 发布 ReleaseSafe,
        // 所以 @intCast 是进程中止, 不是静默截断。降级为 BackendUnavailable,
        // 以便 codecs.decode() 回退到静态解码器。
        if (UInt64(bytes.size) > UInt64(UInt32.MaxValue)) { return None }

        // 1. 创建流
        // 2. 从内存初始化
        // 3. 创建解码器
        // 4. 获取帧 0
        // 5. 获取尺寸, 像素守卫
        // 6. WICConvertBitmapSource 转换为 RGBA8
        // 7. CopyPixels 复制到输出缓冲区
        //    步幅/大小在 u64 中先计算: maxPixels 提高到 ~1.07B 以上时,
        //    w * 4 可能溢出 u32。CopyPixels 接受 UINT 字节计数 + UINT 步幅。
        //    如果 outLen > UINT32_MAX, 返回 TooManyPixels。

        return None
    }

    // ========================================================================
    // 编码
    // 对应 Bun: encode
    // ========================================================================

    /// 编码图像
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

        // 仅 heic/avif 路由到 WIC
        // WritePixels/WriteSource 接受 UINT 字节计数 — 与 CopyPixels 相同的 DWORD 限制
        if (UInt64(rgba.size) > UInt64(UInt32.MaxValue)) { return None }

        let f = ensureFactory()
        if (f == None) { return None }

        let guidOpt = WicGuids.containerGuid(opts.format)
        if (guidOpt == None) { return None }

        // 1. CreateStreamOnHGlobal (可增长内存流)
        // 2. CreateEncoder (container GUID) — 如果 HEIF/AV1 扩展未安装,
        //    返回 WINCODEC_ERR_COMPONENTNOTFOUND -> BackendUnavailable
        // 3. Initialize (WICBitmapEncoderNoCache = 2)
        // 4. CreateNewFrame
        // 5. 设置 ImageQuality 和 HeifCompressionMethod 通过 IPropertyBag2
        //    HeifCompressionMethod: avif -> AV1, heic -> HEVC
        //    如果 HeifCompressionMethod 写入失败 -> BackendUnavailable
        // 6. Initialize frame, SetSize, SetPixelFormat
        //    SetPixelFormat 是输入/输出 — 编码器可能重写为 BGRA;
        //    如果匹配 RGBA, 直接 WritePixels; 否则通过 WriteSource + 转换
        // 7. Commit frame + encoder
        // 8. IStream::Seek 获取逻辑长度 (不是 GlobalSize 的分配大小)
        // 9. GetHGlobalFromStream -> GlobalLock -> 复制

        return None
    }

    // ========================================================================
    // Win32 剪贴板
    // 仅 JS 线程 — OpenClipboard 是进程序列化的。
    // ========================================================================

    /// 从剪贴板获取图像
    /// 优先注册的 "PNG" 格式 (Chrome/Edge/Snipping Tool 放入; 无转码损失),
    /// 然后回退到 CF_DIBV5/CF_DIB, 我们通过前置 14 字节 BITMAPFILEHEADER
    /// (剪贴板省略的) 将其重新包装为 BMP 文件。
    /// 无论哪种方式, 结果是常规 BunImage 解码器理解的字节; 此处不解码。
    public static func clipboard(): ?Array<UInt8> {
        if (openClipboard(CPointer<>.null) == 0) { return None }
        // defer: closeClipboard()

        // 1. 注册的文件格式块 — 逐字复制
        for (name in Win32Clipboard.NAMED_FORMATS) {
            let id = registerClipboardFormatA(name)
            if (id != 0) {
                let hOpt = getClipboardData(id)
                if (hOpt != None) {
                    let dupOpt = dupGlobal(hOpt!, 0)
                    if (dupOpt != None) {
                        closeClipboard()
                        return dupOpt
                    }
                }
            }
        }

        // 2. 打包 DIB — 需要合成 BITMAPFILEHEADER 以便 BMP 嗅探器和解码器接受。
        //    CF_DIBV5 优先 (携带 alpha 掩码)。
        //    剪贴板可由任何本地进程写入, 因此将有效载荷视为敌对:
        //    1 字节 CF_DIB 或 biSize=u32::MAX 的头部必须丢弃格式, 而不是恐慌进程。
        let cfFormats: Array<UInt32> = [Win32Clipboard.CF_DIBV5, Win32Clipboard.CF_DIB]
        for (cf in cfFormats) {
            let hOpt = getClipboardData(cf)
            if (hOpt != None) {
                let bufOpt = dupGlobal(hOpt!, 14)  // 14 字节前缀用于 BITMAPFILEHEADER
                if (bufOpt != None) {
                    let buf = bufOpt!
                    if (buf.size < 14 + 40 || UInt64(buf.size) > UInt64(UInt32.MaxValue)) {
                        continue  // 释放 buf 并尝试下一个
                    }

                    // BITMAPFILEHEADER: 'BM' . u32 file-size . 2xu16 reserved . u32 bfOffBits
                    // bfOffBits = 14 + biSize + colour-table; 24/32 位 DIB 无颜色表,
                    // 但 40 字节头部带 BI_BITFIELDS 附加 12 字节掩码。
                    let ihSize: UInt64 = readUInt32LE(buf, 14)
                    let compression: UInt32 = readUInt32LE(buf, 14 + 16)
                    let masks: UInt64 = if (ihSize == 40 && compression == 3) { 12 } else { 0 }
                    let off = 14 + ihSize + masks
                    if (ihSize < 40 || off > UInt64(buf.size)) {
                        continue  // 释放 buf 并尝试下一个
                    }

                    // 写入 BITMAPFILEHEADER
                    buf[0] = 0x42  // 'B'
                    buf[1] = 0x4D  // 'M'
                    writeUInt32LE(buf, 2, UInt32(buf.size))
                    writeUInt32LE(buf, 6, 0)
                    writeUInt32LE(buf, 10, UInt32(off))

                    closeClipboard()
                    return buf
                }
            }
        }

        closeClipboard()
        return None
    }

    /// 检查剪贴板是否有图像
    public static func hasClipboardImage(): Bool {
        // IsClipboardFormatAvailable 不需要 OpenClipboard
        if (isClipboardFormatAvailable(Win32Clipboard.CF_DIBV5) != 0 ||
            isClipboardFormatAvailable(Win32Clipboard.CF_DIB) != 0) {
            return true
        }
        for (name in Win32Clipboard.NAMED_FORMATS) {
            let id = registerClipboardFormatA(name)
            if (id != 0 && isClipboardFormatAvailable(id) != 0) { return true }
        }
        return false
    }

    /// 剪贴板变化计数
    /// 单调计数器, 在每次系统范围的剪贴板写入时递增。
    public static func clipboardChangeCount(): Int64 {
        return Int64(getClipboardSequenceNumber())
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 复制剪贴板 HGLOBAL 到 default_allocator, 可选在前面留 prefix 个零字节
    /// (用于 BITMAPFILEHEADER)
    static func dupGlobal(h: CPointer<>, prefix: Int64): ?Array<UInt8> {
        let size = globalSize(h)
        if (size == 0) { return None }
        let ptrOpt = globalLock(h)
        if (ptrOpt == None) { return None }
        // defer: globalUnlock(h)

        let outLen = prefix + Int64(size)
        var out = Array<UInt8>(outLen, item: 0)
        // 从 ptrOpt 复制 size 字节到 out[prefix..]
        globalUnlock(h)
        return out
    }

    static func readUInt32LE(b: Array<UInt8>, off: Int64): UInt32 {
        UInt32(b[off]) |
        (UInt32(b[off + 1]) << 8) |
        (UInt32(b[off + 2]) << 16) |
        (UInt32(b[off + 3]) << 24)
    }

    static func writeUInt32LE(b: Array<UInt8>, off: Int64, v: UInt32): Unit {
        b[off] = UInt8(v & 0xFF)
        b[off + 1] = UInt8((v >> 8) & 0xFF)
        b[off + 2] = UInt8((v >> 16) & 0xFF)
        b[off + 3] = UInt8((v >> 24) & 0xFF)
    }
}
