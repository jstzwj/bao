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

package bao_runtime.image

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
    public static func cgDecode(bytes: CPointer<Unit>, len: UInt64, maxPixels: UInt64,
        outW: CPointer<UInt32>, outH: CPointer<UInt32>, out: CPointer<Unit>): Int32 {
        // FFI: bun_coregraphics_decode
        return CG_UNAVAILABLE
    }

    /// C shim: 两阶段编码。Phase 1 (out=null) 编码到线程本地 CFData，返回大小;
    /// Phase 2 复制出来并释放 CFData。
    public static func cgEncode(rgba: CPointer<Unit>, width: UInt32, height: UInt32,
        format: Int32, quality: Int32, out: CPointer<Unit>, outLen: CPointer<UInt64>): Int32 {
        // FFI: bun_coregraphics_encode
        return CG_UNAVAILABLE
    }

    /// C shim: vImage 缩放
    public static func cgScale(src: CPointer<Unit>, sw: UInt32, sh: UInt32,
        dst: CPointer<Unit>, dw: UInt32, dh: UInt32): Int32 {
        // FFI: bun_coregraphics_scale
        return CG_UNAVAILABLE
    }

    /// C shim: vImage 旋转 90 度
    public static func cgRotate90(src: CPointer<Unit>, w: UInt32, h: UInt32,
        dst: CPointer<Unit>, quarters: UInt32): Int32 {
        // FFI: bun_coregraphics_rotate90
        return CG_UNAVAILABLE
    }

    /// C shim: vImage 翻转
    public static func cgReflect(src: CPointer<Unit>, w: UInt32, h: UInt32,
        dst: CPointer<Unit>, horizontal: Int32): Int32 {
        // FFI: bun_coregraphics_reflect
        return CG_UNAVAILABLE
    }

    /// C shim: 剪贴板读取
    public static func cgClipboard(out: CPointer<Unit>, outLen: CPointer<UInt64>, probeOnly: Int32): Int32 {
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
        let bytesPtr = CPointer<Unit>()
        let rc1 = cgDecode(bytesPtr, UInt64(bytes.size), maxPixels,
                            CPointer<UInt32>(), CPointer<UInt32>(),
                            CPointer<Unit>())
        if (rc1 != CG_OK) { return None }

        // 分配 RGBA 缓冲区
        let outLen = UInt64(w) * UInt64(h) * 4
        var out = Array<UInt8>(Int64(outLen), { _: Int64 => 0 })

        // Phase 2: 渲染
        let outPtr = CPointer<Unit>()
        let rc2 = cgDecode(bytesPtr, UInt64(bytes.size), maxPixels,
                            CPointer<UInt32>(), CPointer<UInt32>(),
                            outPtr)
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
    public static func encode(rgba: Array<UInt8>, width: UInt32, height: UInt32,
        opts: CodecsEncodeOptions): ?Array<UInt8> {

        // 格式映射为 Int32 (枚举序号)
        let fmt: Int32 = match (opts.format) {
            case ImageFormat.heic => 4
            case ImageFormat.avif => 5
            case _ => 4
        }

        // Phase 1: 编码到线程本地 CFData，获取大小
        var len: UInt64 = 0
        let rgbaPtr = CPointer<Unit>()
        let rc1 = cgEncode(rgbaPtr, width, height, fmt, Int32(opts.quality),
                            CPointer<Unit>(), CPointer<UInt64>())
        if (rc1 != CG_OK) { return None }

        // 分配输出缓冲区
        var out = Array<UInt8>(Int64(len), { _: Int64 => 0 })

        // Phase 2: 复制出来并释放 CFData
        let outPtr = CPointer<Unit>()
        let rc2 = cgEncode(rgbaPtr, width, height, fmt, Int32(opts.quality),
                            outPtr, CPointer<UInt64>())
        if (rc2 != CG_OK) { return None }

        return out
    }

    // ========================================================================
    // vImage 几何操作
    // ========================================================================

    /// vImage 缩放
    public static func scale(src: Array<UInt8>, sw: UInt32, sh: UInt32, dw: UInt32, dh: UInt32,
        filter: Filter): ?Array<UInt8> {
        if (match (filter) { case Filter.lanczos3 => false case _ => true }) { return None }

        let outLen = UInt64(dw) * UInt64(dh) * 4
        var out = Array<UInt8>(Int64(outLen), { _: Int64 => 0 })

        let srcPtr = CPointer<Unit>()
        let dstPtr = CPointer<Unit>()
        if (cgScale(srcPtr, sw, sh, dstPtr, dw, dh) != CG_OK) {
            return None
        }
        return out
    }

    /// vImage 旋转 90 度
    public static func rotate(src: Array<UInt8>, w: UInt32, h: UInt32, quarters: UInt32): ?Array<UInt8> {
        let outLen = UInt64(w) * UInt64(h) * 4
        var out = Array<UInt8>(Int64(outLen), { _: Int64 => 0 })

        let srcPtr = CPointer<Unit>()
        let dstPtr = CPointer<Unit>()
        if (cgRotate90(srcPtr, w, h, dstPtr, quarters) != CG_OK) {
            return None
        }
        return out
    }

    /// vImage 翻转
    public static func flip(src: Array<UInt8>, w: UInt32, h: UInt32, horizontal: Bool): ?Array<UInt8> {
        let outLen = UInt64(w) * UInt64(h) * 4
        var out = Array<UInt8>(Int64(outLen), { _: Int64 => 0 })

        let srcPtr = CPointer<Unit>()
        let dstPtr = CPointer<Unit>()
        if (cgReflect(srcPtr, w, h, dstPtr, if (horizontal) { 1 } else { 0 }) != CG_OK) {
            return None
        }
        return out
    }

    // ========================================================================
    // NSPasteboard 剪贴板
    // ========================================================================

    /// 从剪贴板获取图像
    public static func clipboard(): ?Array<UInt8> {
        var len: UInt64 = 0
        if (cgClipboard(CPointer<Unit>(), CPointer<UInt64>(), 0) != CG_OK) {
            return None
        }
        if (len == 0) { return None }

        var out = Array<UInt8>(Int64(len), { _: Int64 => 0 })
        let outPtr = CPointer<Unit>()
        if (cgClipboard(outPtr, CPointer<UInt64>(), 0) != CG_OK) {
            return None
        }
        return out
    }

    /// 检查剪贴板是否有图像
    public static func hasClipboardImage(): Bool {
        var len: UInt64 = 0
        return cgClipboard(CPointer<Unit>(), CPointer<UInt64>(), 1) == CG_OK && len > 0
    }

    /// 剪贴板变化计数
    public static func clipboardChangeCount(): Int64 {
        return cgClipboardChangeCount()
    }
}

// ============================================================================
// CoreGraphics 后端错误
// ============================================================================

public enum CGBackendError {
    | backendUnavailable
    | decodeFailed
    | encodeFailed
    | tooManyPixels
    | outOfMemory
}
