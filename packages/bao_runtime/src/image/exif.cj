// 严格翻译自: src/runtime/image/exif.zig
// EXIF 方向读取器
// 仅解析方向标签 (0x0112) — 这是唯一改变像素含义的 EXIF 数据
// JPEG 专用，因为手机相机是旋转图像的主要来源

package bao_runtime.image

// ============================================================================
// EXIF 方向
// 对应 Bun: exif.Orientation
// ============================================================================

public enum ExifOrientation {
    | normal        // 1
    | flop          // 2 - 水平镜像
    | rotate180     // 3
    | flip          // 4 - 垂直镜像
    | flopRotate90  // 5
    | rotate90      // 6
    | flopRotate270 // 7
    | rotate270     // 8

    /// 将存储的像素转正所需的 (flop?, flip?, 顺时针度数)
    /// 对应 Bun: Orientation.transform
    public func transform(): (Bool, Bool, UInt16) {
        match (this) {
            case normal => (false, false, 0)
            case flop => (true, false, 0)
            case rotate180 => (false, false, 180)
            case flip => (false, true, 0)
            case flopRotate90 => (true, false, 270)
            case rotate90 => (false, false, 90)
            case flopRotate270 => (true, false, 90)
            case rotate270 => (false, false, 270)
        }
    }

    public static func fromValue(v: UInt8): ?ExifOrientation {
        match (v) {
            case 1 => normal
            case 2 => flop
            case 3 => rotate180
            case 4 => flip
            case 5 => flopRotate90
            case 6 => rotate90
            case 7 => flopRotate270
            case 8 => rotate270
            case _ => None
        }
    }
}

// ============================================================================
// EXIF 读取器
// 对应 Bun: exif
// ============================================================================

public class Exif {

    /// 遍历 JPEG 标记直到 SOS，查找 APP1/Exif 段
    /// 然后读取 IFD0 标签 0x0112
    /// 对应 Bun: readJpeg
    public static func readJpeg(bytes: Array<UInt8>): ExifOrientation {
        if (bytes.size < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
            return ExifOrientation.normal
        }
        var ii: Int64 = 2
        while (ii + 4 <= bytes.size) {
            if (bytes[Int64(ii)] != 0xFF) { return ExifOrientation.normal }
            let marker = bytes[Int64(ii + 1)]

            // 填充/重启标记没有长度字段
            if (marker == 0xFF) {
                ii += 1
                continue
            }
            if (marker >= 0xD0 && marker <= 0xD8) {
                ii += 2
                continue
            }
            // SOS/EOI: 扫描数据开始; EXIF 应该在更早的位置
            if (marker == 0xDA || marker == 0xD9) { return ExifOrientation.normal }

            let segLen = (UInt32(bytes[Int64(ii + 2)]) << 8) | UInt32(bytes[Int64(ii + 3)])
            if (segLen < 2 || ii + 2 + Int64(segLen) > bytes.size) { return ExifOrientation.normal }

            if (marker == 0xE1 && segLen >= 8) {
                let segStart = ii + 4
                let segEnd = ii + 2 + Int64(segLen)
                if (segEnd <= bytes.size && segEnd - segStart >= 6) {
                    // 检查 "Exif\0\0"
                    if (bytes[Int64(segStart)] == 0x45 && bytes[Int64(segStart + 1)] == 0x78 &&
                        bytes[Int64(segStart + 2)] == 0x69 && bytes[Int64(segStart + 3)] == 0x66 &&
                        bytes[Int64(segStart + 4)] == 0x00 && bytes[Int64(segStart + 5)] == 0x00) {
                        let tiffSlice = sliceArray(bytes, segStart + 6, segEnd)
                        let result = parseTiff(tiffSlice)
                        if (result != None) { return result.getOrThrow() }
                    }
                }
            }
            ii = ii + 2 + Int64(segLen)
        }
        return ExifOrientation.normal
    }

    /// 解析 TIFF IFD0 中的方向标签
    static func parseTiff(tiff: Array<UInt8>): ?ExifOrientation {
        if (tiff.size < 8) { return None }

        let big = (tiff[0] == 0x4D && tiff[1] == 0x4D) // "MM"
        if (!big && !(tiff[0] == 0x49 && tiff[1] == 0x49)) { return None } // "II"

        let magic = rd16(tiff, 2, big)
        if (magic != None && magic.getOrThrow() != 42) { return None }

        let ifd0 = rd32(tiff, 4, big)
        if (ifd0 == None) { return None }

        let count = rd16(tiff, ifd0.getOrThrow(), big)
        if (count == None) { return None }

        var e: Int64 = ifd0.getOrThrow() + 2
        var n: UInt16 = 0
        while (n < count.getOrThrow()) {
            let tag = rd16(tiff, e, big)
            if (tag == None) { return None }
            if (tag.getOrThrow() == 0x0112) {
                // Type 3 (SHORT), count 1
                let ty = rd16(tiff, e + 2, big)
                let cnt = rd32(tiff, e + 4, big)
                if (ty == None || cnt == None) { return None }
                if (ty.getOrThrow() != 3 || cnt.getOrThrow() != 1) { return None }
                let v = rd16(tiff, e + 8, big)
                if (v == None) { return None }
                if (v.getOrThrow() >= 1 && v.getOrThrow() <= 8) {
                    return ExifOrientation.fromValue(UInt8(v.getOrThrow()))
                }
                return None
            }
            n += 1
            e += 12
        }
        return None
    }

    static func rd16(b: Array<UInt8>, off: Int64, big: Bool): ?UInt16 {
        if (off + 2 > b.size) { return None }
        if (big) {
            return (UInt16(b[off]) << 8) | UInt16(b[off + 1])
        } else {
            return UInt16(b[off]) | (UInt16(b[off + 1]) << 8)
        }
    }

    static func rd32(b: Array<UInt8>, off: Int64, big: Bool): ?UInt32 {
        if (off + 4 > b.size) { return None }
        if (big) {
            return (UInt32(b[off]) << 24) | (UInt32(b[off + 1]) << 16) |
                   (UInt32(b[off + 2]) << 8) | UInt32(b[off + 3])
        } else {
            return UInt32(b[off]) | (UInt32(b[off + 1]) << 8) |
                   (UInt32(b[off + 2]) << 16) | (UInt32(b[off + 3]) << 24)
        }
    }

    static func sliceArray(b: Array<UInt8>, start: Int64, end: Int64): Array<UInt8> {
        let len = end - start
        if (len <= 0) { return Array<UInt8>(0, item: 0) }
        var result = Array<UInt8>(len, item: 0)
        var i: Int64 = 0
        while (i < len && start + i < b.size) {
            result[i] = b[start + i]
            i += 1
        }
        return result
    }
}
