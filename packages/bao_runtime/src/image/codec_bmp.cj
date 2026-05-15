// 严格翻译自: src/runtime/image/codec_bmp.zig
// Windows DIB / BMP 仅解码。
// 支持 BITMAPINFOHEADER (40) 和 BITMAPV4/V5HEADER (108/124)，未压缩或 BI_BITFIELDS，24/32位。

package bao_runtime.image

// ============================================================================
// BMP 头部
// 对应 Bun: codec_bmp.Header
// ============================================================================

public class BmpHeader {
    public var width: UInt32 = 0
    public var height: UInt32 = 0
    // y-stride 方向: BMP 行默认自底向上，除非 biHeight < 0。
    public var topDown: Bool = false
    public var bpp: UInt16 = 24  // 24 或 32
    public var pixOff: UInt32 = 0
    // BI_BITFIELDS 掩码; BI_RGB 使用 Windows 默认值。
    public var rMask: UInt32 = 0x00FF0000
    public var gMask: UInt32 = 0x0000FF00
    public var bMask: UInt32 = 0x000000FF
    public var aMask: UInt32 = 0
}

// ============================================================================
// BMP 解码错误
// ============================================================================

public enum BmpError {
    | decodeFailed
    | outOfMemory
    | tooManyPixels
}

// ============================================================================
// BMP 解码器
// 对应 Bun: codec_bmp
// ============================================================================

public class CodecBmp {

    /// 读取 BITMAPFILEHEADER + BITMAPINFOHEADER (任何版本 >= 40)
    /// 来确定大小和像素数组位置。所有数据为小端序。
    /// 对应 Bun: parseHeader
    public static func parseHeader(b: Array<UInt8>): ?BmpHeader {
        // BITMAPFILEHEADER(14) + 至少 BITMAPINFOHEADER(40)
        if (b.size < 54) { return None }
        if (b[0] != 0x42 /* 'B' */ || b[1] != 0x4D /* 'M' */) { return None }

        let pixOff = readUInt32LE(b, 10)
        let ihSize = readUInt32LE(b, 14)

        // OS/2 BITMAPCOREHEADER (12) 和其他特殊情况
        if (ihSize < 40) { return None }
        if (14 + ihSize > UInt64(b.size)) { return None }

        let wRaw = readInt32LE(b, 18)
        let hRaw = readInt32LE(b, 22)

        // biHeight == Int32::MIN 会使 abs 溢出
        if (wRaw <= 0 || hRaw == 0 || hRaw == Int32.MinValue) { return None }

        let bpp = readUInt16LE(b, 28)
        let compression = readUInt32LE(b, 30)

        if (bpp != 24 && bpp != 32) { return None }
        // BI_RGB = 0, BI_BITFIELDS = 3
        if (compression != 0 && compression != 3) { return None }

        var h = BmpHeader()
        h.width = UInt32(wRaw)
        h.height = UInt32(if (hRaw < 0) { -hRaw } else { hRaw })
        h.topDown = (hRaw < 0)
        h.bpp = bpp
        h.pixOff = pixOff

        // BI_RGB 默认 — Windows 原生字节序是 BGR(X)
        h.rMask = 0x00FF0000
        h.gMask = 0x0000FF00
        h.bMask = 0x000000FF
        h.aMask = 0

        // BI_BITFIELDS: 掩码位于 V4/V5 头部偏移 +40 处
        if (compression == 3) {
            if (b.size < 14 + 40 + 12) { return None }
            h.rMask = readUInt32LE(b, 54)
            h.gMask = readUInt32LE(b, 58)
            h.bMask = readUInt32LE(b, 62)
            // Alpha 掩码仅 V4+ 可用（偏移 66）
            if (ihSize >= 108 && b.size >= 70) {
                h.aMask = readUInt32LE(b, 66)
            } else {
                h.aMask = 0
            }
        }

        // BITFIELDS 掩码来自文件; 检查每个掩码是否为单个连续位域且 <=8 位宽
        if (!validateMask(h.rMask)) { return None }
        if (!validateMask(h.gMask)) { return None }
        if (!validateMask(h.bMask)) { return None }
        if (!validateMask(h.aMask)) { return None }

        return h
    }

    /// 验证掩码是否为单个连续位域且 <=8 位宽
    static func validateMask(mask: UInt32): Bool {
        if (mask == 0) { return true }
        let sh = countTrailingZeros(mask)
        let run = mask >> sh
        // 连续位域检查: run 必须是 2^k - 1
        if ((run & (run + 1)) != 0) { return false }
        if (popCount(mask) > 8) { return false }
        return true
    }

    /// 一个连续位域 -> (右移位数, 位宽)
    /// 对应 Bun: shiftWidth
    public static func shiftWidth(mask: UInt32): (UInt32, UInt32) {
        if (mask == 0) { return (0, 0) }
        let sh = UInt32(countTrailingZeros(mask))
        let w = UInt32(popCount(mask))
        return (sh, w)
    }

    /// 将 width 位通道值扩展为 8 位，通过位复制
    /// 对应 Bun: to8
    public static func to8(v: UInt32, width: UInt32): UInt8 {
        if (width == 0) { return 0xFF } // 未使用通道 -> 不透明
        if (width == 8) { return UInt8(v & 0xFF) }
        let maxVal = (UInt32(1) << width) - 1
        if (maxVal == 0) { return 0 }
        return UInt8((v * 255) / maxVal)
    }

    /// 解码 BMP 图像
    /// 对应 Bun: decode
    public static func decode(bytes: Array<UInt8>, maxPixels: UInt64): ?DecodedImage {
        let hOpt = parseHeader(bytes)
        if (hOpt == None) { return None }
        let h = hOpt!

        // 像素守卫
        if (UInt64(h.width) * UInt64(h.height) > maxPixels) { return None }

        let bppBytes: UInt32 = h.bpp / 8
        // 行填充到 4 字节边界 — DWORD 对齐
        let stride: UInt64 = ((UInt64(h.width) * UInt64(bppBytes) + 3) / 4) * 4
        let need = UInt64(h.pixOff) + stride * UInt64(h.height)
        if (need > UInt64(bytes.size)) { return None }

        let (rs, rw) = shiftWidth(h.rMask)
        let (gs, gw) = shiftWidth(h.gMask)
        let (bs, bw) = shiftWidth(h.bMask)
        let (as, aw) = shiftWidth(h.aMask)

        let npix = UInt64(h.width) * UInt64(h.height)
        let outSize = npix * 4
        var out = Array<UInt8>(Int64(outSize), item: 0)

        var y: UInt32 = 0
        while (y < h.height) {
            let srcY: UInt64 = if (h.topDown) { UInt64(y) } else { UInt64(h.height) - 1 - UInt64(y) }
            let rowOff = UInt64(h.pixOff) + srcY * stride
            let dstOff = UInt64(y) * UInt64(h.width) * 4

            var x: UInt32 = 0
            while (x < h.width) {
                // 24位读三个字节; 32位读一个原生 LE u32
                var pix: UInt32 = 0
                if (bppBytes == 3) {
                    let base = Int64(rowOff + UInt64(x) * 3)
                    pix = UInt32(bytes[base]) |
                          (UInt32(bytes[base + 1]) << 8) |
                          (UInt32(bytes[base + 2]) << 16)
                } else {
                    let base = Int64(rowOff + UInt64(x) * 4)
                    pix = UInt32(bytes[base]) |
                          (UInt32(bytes[base + 1]) << 8) |
                          (UInt32(bytes[base + 2]) << 16) |
                          (UInt32(bytes[base + 3]) << 24)
                }

                let rMax = (UInt32(1) << rw) - 1
                let gMax = (UInt32(1) << gw) - 1
                let bMax = (UInt32(1) << bw) - 1
                let aMax = if (aw > 0) { (UInt32(1) << aw) - 1 } else { UInt32.MaxValue }

                let base = Int64(dstOff + UInt64(x) * 4)
                out[base + 0] = to8((pix >> Int64(rs)) & rMax, rw)
                out[base + 1] = to8((pix >> Int64(gs)) & gMax, gw)
                out[base + 2] = to8((pix >> Int64(bs)) & bMax, bw)
                out[base + 3] = if (h.aMask == 0) {
                    0xFF
                } else {
                    to8((pix >> Int64(as)) & aMax, aw)
                }
                x += 1
            }
            y += 1
        }

        var result = DecodedImage()
        result.rgba = out
        result.width = h.width
        result.height = h.height
        return result
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    static func readUInt16LE(b: Array<UInt8>, off: Int64): UInt16 {
        UInt16(b[off]) | (UInt16(b[off + 1]) << 8)
    }

    static func readUInt32LE(b: Array<UInt8>, off: Int64): UInt32 {
        UInt32(b[off]) |
        (UInt32(b[off + 1]) << 8) |
        (UInt32(b[off + 2]) << 16) |
        (UInt32(b[off + 3]) << 24)
    }

    static func readInt32LE(b: Array<UInt8>, off: Int64): Int32 {
        Int32(readUInt32LE(b, off))
    }

    static func countTrailingZeros(v: UInt32): Int32 {
        if (v == 0) { return 32 }
        var n: Int32 = 0
        var x = v
        while ((x & 1) == 0) {
            n += 1
            x >>= 1
        }
        return n
    }

    static func popCount(v: UInt32): Int32 {
        var count: Int32 = 0
        var x = v
        while (x != 0) {
            count += Int32(x & 1)
            x >>= 1
        }
        return count
    }
}
