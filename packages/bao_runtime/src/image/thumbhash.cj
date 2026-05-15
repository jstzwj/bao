// 严格翻译自: src/runtime/image/thumbhash.zig
// ThumbHash — Evan Wallace 的小型 LQIP 编码（公共领域）
// ~21-25 字节编码 <=100x100 图像的低阶 DCT 系数
// 解码给出 <=32px 模糊图像，具有正确的平均颜色、宽高比和大致结构

package bao_runtime

import std.math.*

// ============================================================================
// ThumbHash 最大长度
// 对应 Bun: thumbhash.max_len
// ============================================================================

public let THUMBHASH_MAX_LEN: Int64 = 25

// ============================================================================
// DCT 通道
// 对应 Bun: thumbhash.Channel
// ============================================================================

class ThumbHashChannel {
    var dc: Float32 = 0.0f
    var scale: Float32 = 0.0f
    var ac: Array<Float32>  // 最多 49 个
    var n: Int64 = 0

    init() {
        ac = Array<Float32>(49, item: 0.0f)
    }
}

// ============================================================================
// 半字节读取器
// 对应 Bun: thumbhash.NibbleReader
// ============================================================================

class NibbleReader {
    var src: Array<UInt8>
    var i: Int64 = 0
    var hi: Bool = false

    init(src: Array<UInt8>, offset: Int64) {
        this.src = src
        this.i = offset
    }

    public func next(): ?UInt8 {
        if (this.i >= this.src.size) { return None }
        let v: UInt8 = if (this.hi) {
            UInt8(this.src[this.i] >> 4)
        } else {
            UInt8(this.src[this.i] & 15)
        }
        if (this.hi) { this.i += 1 }
        this.hi = !this.hi
        return v
    }

    public func channel(out: Array<Float32>, nx: UInt32, ny: UInt32, scale: Float32): ?Int64 {
        var n: Int64 = 0
        var cy: UInt32 = 0
        while (cy < ny) {
            var cx: UInt32 = if (cy > 0) { 0 } else { 1 }
            while (cx * ny < nx * (ny - cy)) {
                let nib = next()
                if (nib == None) { return None }
                out[n] = (Float32(nib!) / 7.5 - 1.0f) * scale
                n += 1
                cx += 1
            }
            cy += 1
        }
        return n
    }
}

// ============================================================================
// ThumbHash 编解码器
// 对应 Bun: thumbhash
// ============================================================================

public class ThumbHash {

    /// 编码图像为 ThumbHash
    /// 对应 Bun: encode
    /// out: 输出缓冲区 (至少 25 字节)
    /// w, h: 宽高 (1-100)
    /// rgba: RGBA 像素数据
    public static func encode(w: UInt32, h: UInt32, rgba: Array<UInt8>): ?Array<UInt8> {
        if (w == 0 || w > 100 || h == 0 || h > 100) { return None }
        if (rgba.size != Int64(w) * Int64(h) * 4) { return None }

        var out = Array<UInt8>(THUMBHASH_MAX_LEN, item: 0)

        // 平均颜色 (alpha 加权)
        var avg = Array<Float32>(4, item: 0.0f)
        var ii: Int64 = 0
        while (ii < rgba.size) {
            let a: Float32 = Float32(rgba[ii + 3]) / 255.0f
            avg[0] += a / 255.0f * Float32(rgba[ii + 0])
            avg[1] += a / 255.0f * Float32(rgba[ii + 1])
            avg[2] += a / 255.0f * Float32(rgba[ii + 2])
            avg[3] += a
            ii += 4
        }
        if (avg[3] > 0) {
            avg[0] /= avg[3]
            avg[1] /= avg[3]
            avg[2] /= avg[3]
        }

        let npix: Float32 = Float32(w * h)
        let hasAlpha = avg[3] < npix
        let lLimit: Float32 = if (hasAlpha) { 5.0f } else { 7.0f }
        let maxDim: Float32 = Float32(max(w, h))
        let lx = max(1, UInt32(round(lLimit * Float32(w) / maxDim)))
        let ly = max(1, UInt32(round(lLimit * Float32(h) / maxDim)))

        // RGBA -> LPQA
        let pixCount = Int64(w) * Int64(h)
        var l = Array<Float32>(pixCount, item: 0.0f)
        var p = Array<Float32>(pixCount, item: 0.0f)
        var q = Array<Float32>(pixCount, item: 0.0f)
        var a = Array<Float32>(pixCount, item: 0.0f)

        ii = 0
        var px: Int64 = 0
        while (ii < rgba.size) {
            let al: Float32 = Float32(rgba[ii + 3]) / 255.0f
            let r = avg[0] * (1 - al) + al / 255.0f * Float32(rgba[ii + 0])
            let g = avg[1] * (1 - al) + al / 255.0f * Float32(rgba[ii + 1])
            let b = avg[2] * (1 - al) + al / 255.0f * Float32(rgba[ii + 2])
            l[px] = (r + g + b) / 3.0f
            p[px] = (r + g) / 2.0f - b
            q[px] = r - g
            a[px] = al
            ii += 4
            px += 1
        }

        let lc = dct(l, px, w, h, max(lx, 3), max(ly, 3))
        let pc = dct(p, px, w, h, 3, 3)
        let qc = dct(q, px, w, h, 3, 3)
        let ac = if (hasAlpha) { dct(a, px, w, h, 5, 5) } else {
            let c = ThumbHashChannel()
            c.dc = 1.0f
            c.scale = 1.0f
            c
        }

        let land = w > h
        let h24: UInt32 = UInt32(round(63 * lc.dc)) |
                          (UInt32(round(31.5 + 31.5 * pc.dc)) << 6) |
                          (UInt32(round(31.5 + 31.5 * qc.dc)) << 12) |
                          (UInt32(round(31 * lc.scale)) << 18) |
                          (if (hasAlpha) { UInt32(1) << 23 } else { 0 })
        let h16: UInt16 = UInt16(if (land) { ly } else { lx }) |
                          (UInt16(round(63 * pc.scale)) << 3) |
                          (UInt16(round(63 * qc.scale)) << 9) |
                          (if (land) { UInt16(1) << 15 } else { 0 })

        out[0] = UInt8(h24 & 0xFF)
        out[1] = UInt8((h24 >> 8) & 0xFF)
        out[2] = UInt8((h24 >> 16) & 0xFF)
        out[3] = UInt8(h16 & 0xFF)
        out[4] = UInt8((h16 >> 8) & 0xFF)
        var n: Int64 = 5
        if (hasAlpha) {
            out[5] = UInt8(round(15 * ac.dc)) | (UInt8(round(15 * ac.scale)) << 4)
            n = 6
        }

        var odd = false
        var channels: Array<ThumbHashChannel> = [lc, pc, qc, ac]
        for (ch in channels) {
            var ci: Int64 = 0
            while (ci < ch.n) {
                let u: UInt8 = UInt8(round(15 * ch.ac[ci]))
                if (odd) {
                    out[n - 1] = out[n - 1] | (u << 4)
                } else {
                    out[n] = u
                    n += 1
                }
                odd = !odd
                ci += 1
            }
        }

        return sliceArray(out, 0, n)
    }

    /// 解码 ThumbHash 为 RGBA 图像
    /// 对应 Bun: decode
    public static func decode(hash: Array<UInt8>): ?DecodedImage {
        if (hash.size < 5) { return None }

        let h24: UInt32 = UInt32(hash[0]) | (UInt32(hash[1]) << 8) | (UInt32(hash[2]) << 16)
        let h16: UInt16 = UInt16(hash[3]) | (UInt16(hash[4]) << 8)

        let lDc: Float32 = Float32(h24 & 63) / 63.0f
        let pDc: Float32 = Float32((h24 >> 6) & 63) / 31.5f - 1.0f
        let qDc: Float32 = Float32((h24 >> 12) & 63) / 31.5f - 1.0f
        let lScale: Float32 = Float32((h24 >> 18) & 31) / 31.0f
        let hasAlpha = (h24 >> 23) != 0
        let pScale: Float32 = Float32((h16 >> 3) & 63) / 63.0f
        let qScale: Float32 = Float32((h16 >> 9) & 63) / 63.0f
        let land = (h16 >> 15) != 0
        let lMax: UInt16 = if (hasAlpha) { 5 } else { 7 }
        let lx = max(3, if (land) { lMax } else { h16 & 7 })
        let ly = max(3, if (land) { h16 & 7 } else { lMax })

        var aDc: Float32 = 1.0f
        var aScale: Float32 = 1.0f
        var off: Int64 = 5
        if (hasAlpha) {
            if (hash.size < 6) { return None }
            aDc = Float32(hash[5] & 15) / 15.0f
            aScale = Float32(hash[5] >> 4) / 15.0f
            off = 6
        }

        let nibbles = NibbleReader(hash, off)
        var lAc = Array<Float32>(49, item: 0.0f)
        var pAc = Array<Float32>(5, item: 0.0f)
        var qAc = Array<Float32>(5, item: 0.0f)
        var aAc = Array<Float32>(14, item: 0.0f)

        let ln = nibbles.channel(lAc, lx, ly, lScale)
        if (ln == None) { return None }
        // 1.25x 饱和度提升补偿 4 位量化
        let pn = nibbles.channel(pAc, 3, 3, pScale * 1.25f)
        if (pn == None) { return None }
        let qn = nibbles.channel(qAc, 3, 3, qScale * 1.25f)
        if (qn == None) { return None }
        let an = if (hasAlpha) { nibbles.channel(aAc, 5, 5, aScale) } else { Int64(0) }
        if (hasAlpha && an == None) { return None }

        let ratio = Float32(lx) / Float32(ly)
        let w: UInt32 = if (ratio > 1) { 32 } else { UInt32(round(32 * ratio)) }
        let h: UInt32 = if (ratio > 1) { UInt32(round(32 / ratio)) } else { 32 }
        let rgba = Array<UInt8>(Int64(w) * Int64(h) * 4, item: 0)

        var fx = Array<Float32>(7, item: 0.0f)
        var fy = Array<Float32>(7, item: 0.0f)

        var y: UInt32 = 0
        while (y < h) {
            var x: UInt32 = 0
            while (x < w) {
                var lv = lDc
                var pv = pDc
                var qv = qDc
                var av = aDc

                let nf = max(lx, if (hasAlpha) { UInt32(5) } else { UInt32(3) })
                var cc: UInt32 = 0
                while (cc < nf) {
                    fx[Int64(cc)] = cos(Float32.pi / Float32(w) * (Float32(x) + 0.5f) * Float32(cc))
                    cc += 1
                }
                let nfY = max(ly, if (hasAlpha) { UInt32(5) } else { UInt32(3) })
                cc = 0
                while (cc < nfY) {
                    fy[Int64(cc)] = cos(Float32.pi / Float32(h) * (Float32(y) + 0.5f) * Float32(cc))
                    cc += 1
                }

                lv += idct(lAc, ln!, lx, ly, fx, fy)
                pv += idct(pAc, pn!, 3, 3, fx, fy)
                qv += idct(qAc, qn!, 3, 3, fx, fy)
                if (hasAlpha) { av += idct(aAc, an!, 5, 5, fx, fy) }

                let b = lv - 2.0f / 3.0f * pv
                let r = (3 * lv - b + qv) / 2
                let g = r - qv
                let o = Int64((y * w + x) * 4)
                rgba[o + 0] = clamp8(r)
                rgba[o + 1] = clamp8(g)
                rgba[o + 2] = clamp8(b)
                rgba[o + 3] = clamp8(av)
                x += 1
            }
            y += 1
        }

        var result = DecodedImage()
        result.rgba = rgba
        result.width = w
        result.height = h
        return result
    }

    // ========================================================================
    // DCT/IDCT 辅助函数
    // ========================================================================

    /// 三角 DCT-II
    static func dct(chan: Array<Float32>, pixCount: Int64, w: UInt32, h: UInt32, nx: UInt32, ny: UInt32): ThumbHashChannel {
        var c = ThumbHashChannel()
        var fx = Array<Float32>(100, item: 0.0f)
        var cy: UInt32 = 0
        while (cy < ny) {
            var cx: UInt32 = 0
            while (cx * ny < nx * (ny - cy)) {
                var xi: UInt32 = 0
                while (xi < w) {
                    fx[Int64(xi)] = cos(Float32.pi / Float32(w) * Float32(cx) * (Float32(xi) + 0.5f))
                    xi += 1
                }
                var f: Float32 = 0.0f
                var yi: UInt32 = 0
                while (yi < h) {
                    let fyVal = cos(Float32.pi / Float32(h) * Float32(cy) * (Float32(yi) + 0.5f))
                    xi = 0
                    while (xi < w) {
                        f += chan[Int64(xi + yi * w)] * fx[Int64(xi)] * fyVal
                        xi += 1
                    }
                    yi += 1
                }
                f /= Float32(w * h)
                if (cx == 0 && cy == 0) {
                    c.dc = f
                } else {
                    c.ac[c.n] = f
                    c.n += 1
                    c.scale = max(c.scale, abs(f))
                }
                cx += 1
            }
            cy += 1
        }
        if (c.scale > 0) {
            var i: Int64 = 0
            while (i < c.n) {
                c.ac[i] = 0.5f + 0.5f / c.scale * c.ac[i]
                i += 1
            }
        }
        return c
    }

    /// 逆 DCT
    static func idct(ac: Array<Float32>, n: Int64, nx: UInt32, ny: UInt32,
        fx: Array<Float32>, fy: Array<Float32>): Float32 {
        var v: Float32 = 0.0f
        var j: Int64 = 0
        var cy: UInt32 = 0
        while (cy < ny) {
            var cx: UInt32 = if (cy > 0) { 0 } else { 1 }
            let fy2 = fy[Int64(cy)] * 2.0f
            while (cx * ny < nx * (ny - cy)) {
                v += ac[j] * fx[Int64(cx)] * fy2
                j += 1
                cx += 1
            }
            cy += 1
        }
        return v
    }

    static func clamp8(v: Float32): UInt8 {
        if (v < 0.0f) { return 0 }
        if (v > 1.0f) { return 255 }
        return UInt8(v * 255.0f)
    }

    static func max(a: UInt32, b: UInt32): UInt32 {
        if (a > b) { a } else { b }
    }

    static func max(a: Float32, b: Float32): Float32 {
        if (a > b) { a } else { b }
    }

    static func abs(v: Float32): Float32 {
        if (v < 0) { -v } else { v }
    }

    static func round(v: Float32): Int64 {
        Int64(v + 0.5f)
    }

    static func cos(v: Float32): Float32 {
        // 依赖标准库的 cos
        Float32(Math.cos(Float64(v)))
    }

    static func sliceArray(b: Array<UInt8>, start: Int64, end: Int64): Array<UInt8> {
        let len = end - start
        if (len <= 0) { return Array<UInt8>(0, item: 0) }
        var result = Array<UInt8>(len, item: 0)
        var i: Int64 = 0
        while (i < len) {
            result[i] = b[start + i]
            i += 1
        }
        return result
    }
}
