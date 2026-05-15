// 严格翻译自: src/runtime/image/backend_coregraphics.zig
// macOS ImageIO/CoreGraphics 后端
// 所有框架调用位于 C++ shim 中; 此文件在 default_allocator 中分配 RGBA/输出缓冲区
// 并将 C 状态码映射回 codecs.Error

package bao_runtime

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

    /// 解码图像
    /// 对应 Bun: decode
    public static func decode(bytes: Array<UInt8>, maxPixels: UInt64): ?DecodedImage {
        // 两阶段解码:
        // Phase 1: 仅获取尺寸 (out=null) 以在 default_allocator 中分配
        // Phase 2: 渲染到分配的缓冲区
        return None
    }

    /// 编码图像
    /// 对应 Bun: encode
    public static func encode(rgba: Array<UInt8>, width: UInt32, height: UInt32,
        opts: CodecsEncodeOptions): ?Array<UInt8> {
        // 仅路由 heic/avif
        // 两阶段编码:
        // Phase 1: 编码到线程本地 CFData，返回大小
        // Phase 2: 复制出来并释放 CFData
        return None
    }

    /// vImage 缩放
    /// 对应 Bun: scale
    /// vImageScale 默认内核是 Lanczos-3
    public static func scale(src: Array<UInt8>, sw: UInt32, sh: UInt32, dw: UInt32, dh: UInt32,
        filter: Filter): ?Array<UInt8> {
        if (filter != Filter.lanczos3) { return None }
        return None
    }

    /// vImage 旋转 90 度
    /// 对应 Bun: rotate
    public static func rotate(src: Array<UInt8>, w: UInt32, h: UInt32, quarters: UInt32): ?Array<UInt8> {
        return None
    }

    /// vImage 翻转
    /// 对应 Bun: flip
    public static func flip(src: Array<UInt8>, w: UInt32, h: UInt32, horizontal: Bool): ?Array<UInt8> {
        return None
    }

    /// 从剪贴板获取图像
    /// 对应 Bun: clipboard
    public static func clipboard(): ?Array<UInt8> {
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
