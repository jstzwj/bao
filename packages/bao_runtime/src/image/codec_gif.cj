// 严格翻译自: src/runtime/image/codec_gif.zig
// GIF89a/87a 首帧解码器
// LZW 本质上是串行的 — 每个码的扩展依赖于所有先前码构建的字典
// 范围: 单图像, 首帧; 支持隔行和 GCE 透明索引

package bao_runtime.image

// ============================================================================
// 位读取器
// 对应 Bun: codec_gif.Bits
// ============================================================================

/// 子块感知位读取器。GIF 将 LZW 比特流包装在长度前缀的子块中
class GifBits {
    var src: Array<UInt8>
    var i: Int64 = 0
    // 当前子块中剩余的字节数。0 = 需要读取长度
    var block: Int64 = 0
    var acc: UInt32 = 0
    var nbits: UInt32 = 0
    var eof: Bool = false

    init(src: Array<UInt8>, offset: Int64) {
        this.src = src
        this.i = offset
    }

    public func read(n: UInt32): UInt16 {
        while (this.nbits < n && !this.eof) {
            if (this.block == 0) {
                if (this.i >= this.src.size) {
                    this.eof = true
                    break
                }
                this.block = Int64(this.src[this.i])
                this.i += 1
                if (this.block == 0) {
                    this.eof = true
                    break
                }
            }
            if (this.i >= this.src.size) {
                this.eof = true
                break
            }
            this.acc = this.acc | (UInt32(this.src[this.i]) << Int64(this.nbits))
            this.i += 1
            this.block -= 1
            this.nbits += 8
        }
        let mask: UInt32 = if (n >= 32) { UInt32.MaxValue } else { (UInt32(1) << n) - 1 }
        let v: UInt16 = UInt16(this.acc & mask)
        this.acc >>= n
        if (this.nbits >= n) {
            this.nbits -= n
        } else {
            this.nbits = 0
        }
        return v
    }

    /// 跳过此图像的其余子块
    public func drain(): Unit {
        var ii = this.i + this.block
        while (ii < this.src.size) {
            let n: Int64 = Int64(this.src[ii])
            ii += 1 + n
            if (n == 0) { break }
        }
        this.i = if (ii < this.src.size) { ii } else { this.src.size }
    }
}

// ============================================================================
// LZW 字典
// 对应 Bun: codec_gif.Dict
// ============================================================================

/// 每个字典条目一个节点。4096 码是 GIF 硬上限（12 位码）
class GifDict {
    var prefix: Array<UInt16>
    var suffix: Array<UInt8>

    init() {
        prefix = Array<UInt16>(4096, item: 0)
        suffix = Array<UInt8>(4096, item: 0)
    }

    /// 沿前缀链走到 scratch（反转），然后正向复制到 out
    /// 返回 (写入字节数, 字符串的首字节)
    public func emit(code: UInt16, clear: UInt16, out: Array<UInt8>, outOff: Int64, scratch: Array<UInt8>): (Int64, UInt8) {
        var c = code
        var n: Int64 = 0
        while (c >= clear) {
            if (n >= 4096) { break }
            scratch[Int64(n)] = this.suffix[Int64(c)]
            n += 1
            c = this.prefix[Int64(c)]
        }
        scratch[Int64(n)] = UInt8(c) // 根: 字面字节
        n += 1
        let first: UInt8 = scratch[Int64(n - 1)]
        var k: Int64 = 0
        while (k < n && k + outOff < out.size) {
            out[outOff + k] = scratch[Int64(n - 1 - k)]
            k += 1
        }
        return (k, first)
    }
}

// ============================================================================
// GIF 解码器
// 对应 Bun: codec_gif
// ============================================================================

public class CodecGif {

    /// 解码 GIF 图像
    /// 对应 Bun: decode
    public static func decode(bytes: Array<UInt8>, maxPixels: UInt64): ?DecodedImage {
        // 头部 + LSD
        if (bytes.size < 13) { return None }
        let sig = substring(bytes, 0, 6)
        if (!equalsStr(sig, "GIF89a") && !equalsStr(sig, "GIF87a")) { return None }

        let lsdPacked = bytes[10]
        let hasGct = (lsdPacked & 0x80) != 0
        let gctSize: UInt16 = if (hasGct) {
            UInt16(1) << Int64((lsdPacked & 7) + 1)
        } else {
            0
        }

        var ii: Int64 = 13 + Int64(gctSize) * 3
        if (ii > bytes.size) { return None }

        let gct: Array<UInt8> = if (hasGct) {
            sliceArray(bytes, 13, Int64(gctSize) * 3)
        } else {
            Array<UInt8>(0, item: 0)
        }

        var trns: Int64 = -1 // 透明索引

        // 块流: 跳过扩展, 取第一个图像描述符
        while (ii < bytes.size) {
            let b = bytes[ii]
            if (b == 0x3B) { return None } // 尾部标记在图像之前
            if (b == 0x21) { // 扩展引入符
                if (ii + 2 > bytes.size) { return None }
                let label = bytes[ii + 1]
                ii += 2
                // 图形控制扩展
                if (label == 0xF9 && ii + 6 <= bytes.size && bytes[ii] == 4) {
                    if ((bytes[ii + 1] & 1) != 0) {
                        trns = Int64(bytes[ii + 4])
                    }
                }
                // 跳过子块
                while (ii < bytes.size) {
                    let n: Int64 = Int64(bytes[ii])
                    ii += 1 + n
                    if (n == 0) { break }
                }
            } else if (b == 0x2C) { // 图像描述符
                if (ii + 10 > bytes.size) { return None }
                let w: UInt32 = UInt32(bytes[ii + 5]) | (UInt32(bytes[ii + 6]) << 8)
                let h: UInt32 = UInt32(bytes[ii + 7]) | (UInt32(bytes[ii + 8]) << 8)
                let ipacked = bytes[ii + 9]
                let interlace = (ipacked & 0x40) != 0
                let hasLct = (ipacked & 0x80) != 0
                let lctSize: Int64 = if (hasLct) { Int64(1) << Int64((ipacked & 7) + 1) } else { 0 }
                ii += 10
                if (w == 0 || h == 0) { return None }
                if (UInt64(w) * UInt64(h) > maxPixels) { return None }

                // 本地颜色表
                let ct: Array<UInt8> = if (hasLct) {
                    if (ii + lctSize * 3 > bytes.size) { return None }
                    let ctSlice = sliceArray(bytes, ii, lctSize * 3)
                    ii += lctSize * 3
                    ctSlice
                } else {
                    gct
                }
                if (ct.size == 0) { return None }

                if (ii >= bytes.size) { return None }
                var minCode: Int32 = Int32(bytes[ii])
                if (minCode < 2) { minCode = 2 }
                if (minCode > 11) { minCode = 11 }
                ii += 1

                return decodeFrame(bytes, ii, w, h, interlace, ct, UInt32(minCode), trns)
            } else {
                return None
            }
        }
        return None
    }

    /// 解码 LZW 帧
    static func decodeFrame(bytes: Array<UInt8>, lzwOff: Int64, w: UInt32, h: UInt32,
        interlace: Bool, ct: Array<UInt8>, minCode: UInt32, trns: Int64): ?DecodedImage {

        let npix: Int64 = Int64(w) * Int64(h)

        let clear: UInt16 = UInt16(1) << Int32(minCode)
        let eoi: UInt16 = clear + 1
        var size: UInt32 = minCode + 1
        var avail: UInt16 = eoi + 1
        var prev: Int64 = -1

        var dict = GifDict()
        var scratch = Array<UInt8>(4096, item: 0)

        let idx = Array<UInt8>(Int64(npix), item: 0)
        var written: Int64 = 0

        var bits = GifBits(bytes, lzwOff)

        while (written < npix) {
            let code = bits.read(size)
            if (bits.eof && code == 0) { break }
            if (code == clear) {
                size = minCode + 1
                avail = eoi + 1
                prev = -1
                continue
            }
            if (code == eoi) { break }

            var first: UInt8 = 0
            if (code < avail) {
                let (n, f) = dict.emit(code, clear, idx, written, scratch)
                written += n
                first = f
            } else if (code == avail && prev >= 0) {
                let (n, f) = dict.emit(UInt16(prev), clear, idx, written, scratch)
                written += n
                first = f
                if (written < npix) {
                    idx[written] = first
                    written += 1
                }
            } else {
                return None // 超出范围的码
            }

            // 将 prev+first 添加到字典
            if (prev >= 0 && Int64(avail) < 4096) {
                dict.prefix[Int64(avail)] = UInt16(prev)
                dict.suffix[Int64(avail)] = first
                avail = avail + 1
                let limit: UInt16 = UInt16(1) << Int32(size)
                if (avail == limit && size < 12) {
                    size += 1
                }
            }
            prev = Int64(code)
        }
        bits.drain()

        // 短流或截断流填充透明
        if (written < npix) {
            let fillVal: UInt8 = if (trns >= 0) { UInt8(trns) } else { 0 }
            while (written < npix) {
                idx[written] = fillVal
                written += 1
            }
        }

        // 隔行重排
        let out = Array<UInt8>(Int64(npix) * 4, item: 0)

        // 构建调色板
        var pal = Array<UInt8>(256 * 4, item: 0)
        var ci: Int64 = 0
        while (ci < ct.size / 3) {
            pal[ci * 4 + 0] = ct[Int64(ci * 3 + 0)]
            pal[ci * 4 + 1] = ct[Int64(ci * 3 + 1)]
            pal[ci * 4 + 2] = ct[Int64(ci * 3 + 2)]
            pal[ci * 4 + 3] = 255
            ci += 1
        }
        if (trns >= 0 && trns < 256) {
            pal[Int64(trns) * 4 + 0] = 0
            pal[Int64(trns) * 4 + 1] = 0
            pal[Int64(trns) * 4 + 2] = 0
            pal[Int64(trns) * 4 + 3] = 0
        }

        if (interlace) {
            // 4 个通过
            let passes: Array<(UInt32, UInt32)> = [
                (0, 8), (4, 8), (2, 4), (1, 2)
            ]
            var srcY: UInt32 = 0
            for (pass in passes) {
                var y: UInt32 = pass[0]
                while (y < h) {
                    expandRow(idx, Int64(srcY) * Int64(w), out, Int64(y) * Int64(w) * 4, w, pal)
                    y += pass[1]
                    srcY += 1
                }
            }
        } else {
            var y: UInt32 = 0
            while (y < h) {
                expandRow(idx, Int64(y) * Int64(w), out, Int64(y) * Int64(w) * 4, w, pal)
                y += 1
            }
        }

        var result = DecodedImage()
        result.rgba = out
        result.width = w
        result.height = h
        return result
    }

    /// 一行调色板索引 -> RGBA
    static func expandRow(idx: Array<UInt8>, idxOff: Int64, out: Array<UInt8>, outOff: Int64, w: UInt32, pal: Array<UInt8>): Unit {
        var x: UInt32 = 0
        while (x < w) {
            let c = idx[Int64(idxOff) + Int64(x)]
            let pOff = Int64(c) * 4
            let oOff = Int64(outOff) + Int64(x) * 4
            out[oOff + 0] = pal[pOff + 0]
            out[oOff + 1] = pal[pOff + 1]
            out[oOff + 2] = pal[pOff + 2]
            out[oOff + 3] = pal[pOff + 3]
            x += 1
        }
    }

    // 辅助函数
    static func substring(b: Array<UInt8>, start: Int64, end: Int64): String {
        var s = ""
        var i = start
        while (i < end && i < b.size) {
            s.append(Char(b[i]))
            i += 1
        }
        return s
    }

    static func equalsStr(s: String, target: String): Bool {
        if (s.size != target.size) { return false }
        var i: Int64 = 0
        while (i < s.size) {
            if (s[i] != target[i]) { return false }
            i += 1
        }
        return true
    }

    static func sliceArray(b: Array<UInt8>, start: Int64, len: Int64): Array<UInt8> {
        var result = Array<UInt8>(len, item: 0)
        var i: Int64 = 0
        while (i < len && start + i < b.size) {
            result[i] = b[start + i]
            i += 1
        }
        return result
    }
}
