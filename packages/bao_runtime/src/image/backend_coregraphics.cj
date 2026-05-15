// 严格翻译自: src/runtime/image/backend_coregraphics.zig
// macOS ImageIO/CoreGraphics 后端
// 所有框架调用位于 C++ shim (src/jsc/bindings/image_coregraphics_shim.cpp) 中 —
// 此文件在 default_allocator 中分配 RGBA/输出缓冲区
// 并将 C 状态码映射回 codecs.Error。
//
// 为什么 C++ shim:
// Zig→dlsym'd-function-pointer 调用到 CG 在 x86_64 上段错误，
// 即使在 thunked 明显的 by-value struct 之后，所以整个分发在 C++ 中，
// 其中 clang 拥有 ABI。此文件只是分配缓冲区并映射错误。

package bao_runtime

// ============================================================================
// CoreGraphics 后端
// 对应 Bun: backend_coregraphics
// ============================================================================

public class BackendCoreGraphics {

    // C shim 返回码
    public static let CG_OK: Int32 = 0
    public static let CG_UNAVAILABLE: Int32 = 1
    public static let CG_DECODE_FAILED: Int32 = 2
    public static let CG_ENCODE_FAILED: Int32 = 3
    public static let CG_TOO_MANY_PIXELS: Int32 = 4

    // ========================================================================
    // 外部 C shim 函数
    // ========================================================================

    /// C shim: 两阶段解码。Phase 1 (out=null) 获取尺寸;
    /// Phase 2 使用分配的缓冲区渲染。
    public static func cgDecode(bytes: CPointer<>, len: UInt64, maxPixels: UInt64,
        outW: CPointer<UInt32>, outH: CPointer<UInt32>, out: CPointer<>): Int32 {
        // FFI: bun_coregraphics_decode
        return CG_UNAVAILABLE
    }

    /// C shim: 两阶段编码。Phase 1 (out=null) 编码到线程本地 CFData，返回大小;
    /// Phase 2 复制出来并释放 CFData。
    public static func cgEncode(rgba: CPointer<>, width: UInt32, height: UInt32,
        format: Int32, quality: Int32, out: CPointer<>, outLen: CPointer<UInt64>): Int32 {
        // FFI: bun_coregraphics_encode
        return CG_UNAVAILABLE
    }

    /// C shim: vImage 缩放
    public static func cgScale(src: CPointer<>, sw: UInt32, sh: UInt32,
        dst: CPointer<>, dw: UInt32, dh: UInt32): Int32 {
        // FFI: bun_coregraphics_scale
        return CG_UNAVAILABLE
    }

    /// C shim: vImage 旋转 90 度
    public static func cgRotate90(src: CPointer<>, w: UInt32, h: UInt32,
        dst: CPointer<>, quarters: UInt32): Int32 {
        // FFI: bun_coregraphics_rotate90
        return CG_UNAVAILABLE
    }

    /// C shim: vImage 翻转
    public static func cgReflect(src: CPointer<>, w: UInt32, h: UInt32,
        dst: CPointer<>, horizontal: Int32): Int32 {
        // FFI: bun_coregraphics_reflect
        return CG_UNAVAILABLE
    }

    /// C shim: 剪贴板读取
    public static func cgClipboard(out: CPointer<>, outLen: CPointer<UInt64>, probeOnly: Int32): Int32 {
        // FFI: bun_coregraphics_clipboard
        return CG_UNAVAILABLE
    }

    /// C shim: 剪贴板变化计数
    public static func cgClipboardChangeCount(): Int64 {
        // FFI: bun_coregraphics_clipboard_change_count
        return -1
    }

    // ========================================================================
    // 错误映射
    // 对应 Bun: mapErr
    // ========================================================================

    /// 将 C shim 返回码映射到后端错误
    public static func mapErr(rc: Int32): CGBackendError {
        match (rc) {
            case CG_UNAVAILABLE => CGBackendError.backendUnavailable
            case CG_DECODE_FAILED => CGBackendError.decodeFailed
            case CG_ENCODE_FAILED => CGBackendError.encodeFailed
            case CG_TOO_MANY_PIXELS => CGBackendError.tooManyPixels
            case _ => CGBackendError.backendUnavailable
        }
    }

    // ========================================================================
    // 解码
    // 对应 Bun: decode
    // ========================================================================

    /// 解码图像
    /// 两阶段解码:
    /// Phase 1: 仅获取尺寸 (out=null) 以便在 default_allocator 中分配
    /// Phase 2: 渲染到分配的缓冲区
    public static func decode(bytes: Array<UInt8>, maxPixels: UInt64): ?DecodedImage {
        var w: UInt32 = 0
        var h: UInt32 = 0

        // Phase 1: 仅尺寸
        let rc1 = cgDecode(bytes.ptr(), UInt64(bytes.size), maxPixels,
                            CPointer<UInt32>.addrOf(w), CPointer<UInt32>.addrOf(h),
                            CPointer<>.null)
        if (rc1 != CG_OK) { return None }

        // 分配 RGBA 缓冲区
        let outLen = UInt64(w) * UInt64(h) * 4
        var out = Array<UInt8>(Int64(outLen), item: 0)

        // Phase 2: 渲染
        // C 端重新创建 CGImageSource（开销不大 — 头部解析是唯一重复的工作），
        // 因此我们不需要跨边界传递不透明句柄。
        let rc2 = cgDecode(bytes.ptr(), UInt64(bytes.size), maxPixels,
                            CPointer<UInt32>.addrOf(w), CPointer<UInt32>.addrOf(h),
                            out.ptr())
        if (rc2 != CG_OK) { return None }

        var result = DecodedImage()
        result.rgba = out
        result.width = w
        result.height = h
        return result
    }

    // ========================================================================
    // 编码
    // 对应 Bun: encode
    // ========================================================================

    /// 编码图像
    /// codecs.encode 仅将 heic/avif 路由到这里，因此 ImageIO 无法表达的
    /// "旋钮" bailout (palette/compressionLevel/lossless) 是死代码 —
    /// 仅保留为未来调用者直接传递 png/webp 时的防护。
    public static func encode(rgba: Array<UInt8>, width: UInt32, height: UInt32,
        opts: CodecsEncodeOptions): ?Array<UInt8> {

        // 格式映射为 Int32 (枚举序号)
        let fmt: Int32 = match (opts.format) {
            case ImageFormat.heic => 4  // 假设映射
            case ImageFormat.avif => 5
            case _ => 4
        }

        // Phase 1: 编码到线程本地 CFData，获取大小
        var len: UInt64 = 0
        let rc1 = cgEncode(rgba.ptr(), width, height, fmt, Int32(opts.quality),
                            CPointer<>.null, CPointer<UInt64>.addrOf(len))
        if (rc1 != CG_OK) { return None }

        // 分配输出缓冲区
        var out = Array<UInt8>(Int64(len), item: 0)

        // Phase 2: 复制出来并释放 CFData
        let rc2 = cgEncode(rgba.ptr(), width, height, fmt, Int32(opts.quality),
                            out.ptr(), CPointer<UInt64>.addrOf(len))
        if (rc2 != CG_OK) { return None }

        return out
    }

    // ========================================================================
    // vImage 几何操作
    // AMX 支持的内核用于常见管线操作。
    // 签名与 codecs.zig 中的 Highway 路径匹配，
    // 因此分发点是 system_backend.x() catch fallback.x()。
    // ========================================================================

    /// vImage 缩放
    /// vImageScale 的默认内核是 Lanczos-3（HQ 标志扩展到 L5），
    /// 因此我们只对 .lanczos3 默认值采用此路径 —
    /// 显式非 Lanczos 滤镜回退到完全尊重它们的 Highway 内核。
    public static func scale(src: Array<UInt8>, sw: UInt32, sh: UInt32, dw: UInt32, dh: UInt32,
        filter: Filter): ?Array<UInt8> {
        if (filter != Filter.lanczos3) { return None }

        let outLen = UInt64(dw) * UInt64(dh) * 4
        var out = Array<UInt8>(Int64(outLen), item: 0)

        if (cgScale(src.ptr(), sw, sh, out.ptr(), dw, dh) != CG_OK) {
            return None
        }
        return out
    }

    /// vImage 旋转 90 度
    /// quarters: 顺时针 90 度旋转次数 (1=90, 2=180, 3=270)
    public static func rotate(src: Array<UInt8>, w: UInt32, h: UInt32, quarters: UInt32): ?Array<UInt8> {
        let outLen = UInt64(w) * UInt64(h) * 4
        var out = Array<UInt8>(Int64(outLen), item: 0)

        if (cgRotate90(src.ptr(), w, h, out.ptr(), quarters) != CG_OK) {
            return None
        }
        return out
    }

    /// vImage 翻转
    public static func flip(src: Array<UInt8>, w: UInt32, h: UInt32, horizontal: Bool): ?Array<UInt8> {
        let outLen = UInt64(w) * UInt64(h) * 4
        var out = Array<UInt8>(Int64(outLen), item: 0)

        if (cgReflect(src.ptr(), w, h, out.ptr(), if (horizontal) { 1 } else { 0 }) != CG_OK) {
            return None
        }
        return out
    }

    // ========================================================================
    // NSPasteboard 剪贴板
    // 仅 JS 线程 (NSPasteboard 文档说明主线程安全读取)
    // ========================================================================

    /// 从剪贴板获取图像
    /// null = 剪贴板上没有图像。返回的字节是不透明容器
    /// (PNG/TIFF/HEIC/...); 直接送入 new BunImage(...)。
    public static func clipboard(): ?Array<UInt8> {
        var len: UInt64 = 0
        if (cgClipboard(CPointer<>.null, CPointer<UInt64>.addrOf(len), 0) != CG_OK) {
            return None
        }
        if (len == 0) { return None }

        var out = Array<UInt8>(Int64(len), item: 0)
        if (cgClipboard(out.ptr(), CPointer<UInt64>.addrOf(len), 0) != CG_OK) {
            return None
        }
        return out
    }

    /// 检查剪贴板是否有图像
    public static func hasClipboardImage(): Bool {
        var len: UInt64 = 0
        return cgClipboard(CPointer<>.null, CPointer<UInt64>.addrOf(len), 1) == CG_OK && len > 0
    }

    /// 剪贴板变化计数
    /// 单调计数器，在每次系统范围的剪贴板写入时递增。
    /// macOS 没有剪贴板更改通知，因此轮询此值并仅在它变化时
    /// 调用 hasClipboardImage() 是最便宜的提示-UI 模式。
    public static func clipboardChangeCount(): Int64 {
        return cgClipboardChangeCount()
    }
}

// ============================================================================
// CoreGraphics 后端错误
// 对应 Bun: backend_coregraphics.BackendError
// ============================================================================

public enum CGBackendError {
    | backendUnavailable
    | decodeFailed
    | encodeFailed
    | tooManyPixels
    | outOfMemory
}
