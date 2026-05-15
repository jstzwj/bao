// 严格翻译自: src/runtime/image/quantize.zig
// 中位切颜色量化器
// 用于 .png({ palette: true, colors: N })
// Heckbert '82 算法: 将 RGBA 像素视为 4-D 空间中的点
// 重复分割最大通道范围的盒子到该通道的中位数
// 直到有 N 个盒子，每个盒子的均值成为调色板条目

package bao_runtime.image

// ============================================================================
// 量化结果
// 对应 Bun: quantize.Result
// ============================================================================

public class QuantizeResult {
    /// [colors][4]u8 RGBA 调色板
    public var palette: Array<UInt8>
    /// 每个输入像素一个调色板索引
    public var indices: Array<UInt8>
    /// 实际调色板长度 (<= 请求的 colors)
    public var colors: UInt16
    /// 是否有任何调色板条目的 alpha < 255
    public var hasAlpha: Bool

    public init(palette: Array<UInt8>, indices: Array<UInt8>, colors: UInt16, hasAlpha: Bool) {
        this.palette = palette
        this.indices = indices
        this.colors = colors
        this.hasAlpha = hasAlpha
    }

    public func deinit(): Unit {
        // 由分配器释放
    }
}

// ============================================================================
// 量化盒子
// 对应 Bun: quantize.Box
// ============================================================================

class QuantizeBox {
    var lo: UInt32 = 0
    var hi: UInt32 = 0
    var min: Array<UInt8>  // [4]
    var max: Array<UInt8>  // [4]

    init() {
        min = Array<UInt8>(4, item: 255)
        max = Array<UInt8>(4, item: 0)
    }

    /// 找到最宽的通道
    func widestChannel(): Int32 {
        var best: Int32 = 0
        var span: Int32 = -1
        var c: Int64 = 0
        while (c < 4) {
            let s = Int32(max[Int64(c)]) - Int32(min[Int64(c)])
            if (s > span) {
                span = s
                best = Int32(c)
            }
            c += 1
        }
        return best
    }
}

// ============================================================================
// 量化选项
// 对应 Bun: quantize.Options
// ============================================================================

public class QuantizeOptions {
    public var maxColors: UInt16
    public var dither: Bool = false

    public init(maxColors: UInt16) {
        this.maxColors = maxColors
    }
}

// ============================================================================
// 量化器
// 对应 Bun: quantize
// ============================================================================

public class Quantize {

    /// 量化 RGBA 图像
    /// 对应 Bun: quantize
    public static func quantize(rgba: Array<UInt8>, w: UInt32, h: UInt32, opts: QuantizeOptions): ?QuantizeResult {
        let n: UInt32 = UInt32(rgba.size / 4)
        let want: UInt16 = max(UInt16(1), min(opts.maxColors, UInt16(256)))

        // order 是像素索引的排列，我们在原地分区
        var order = Array<UInt32>(Int64(n), item: 0)
        var ii: UInt32 = 0
        while (ii < n) {
            order[Int64(ii)] = ii
            ii += 1
        }

        // 盒子列表
        var boxes = Array<QuantizeBox>(Int64(want), item: QuantizeBox())
        var boxCount: Int64 = 1
        boxes[0] = shrink(rgba, order, 0, n)

        while (boxCount < Int64(want)) {
            // 选择单通道范围最大的盒子
            var pick: Int64 = 0
            var best: Int32 = -1
            var bi: Int64 = 0
            while (bi < boxCount) {
                let c = boxes[bi].widestChannel()
                let s = Int32(boxes[bi].max[Int64(c)]) - Int32(boxes[bi].min[Int64(c)])
                if (s > best) {
                    best = s
                    pick = bi
                }
                bi += 1
            }
            if (best <= 0) { break } // 每个剩余盒子都是单色
            let b = boxes[pick]
            if (b.hi - b.lo < 2) { break }

            let ch = b.widestChannel()
            // 部分排序按选定通道，然后在中点切割
            sortPartial(rgba, order, b.lo, b.hi, Int64(ch))
            let mid = b.lo + (b.hi - b.lo) / 2
            boxes[pick] = shrink(rgba, order, b.lo, mid)
            boxes[boxCount] = shrink(rgba, order, mid, b.hi)
            boxCount += 1
        }

        let k: UInt16 = UInt16(boxCount)
        var palette = Array<UInt8>(Int64(k) * 4, item: 0)
        var hasAlpha = false

        var i: Int64 = 0
        while (i < boxCount) {
            var sum = Array<UInt64>(4, item: 0)
            let b = boxes[i]
            var j: UInt32 = b.lo
            while (j < b.hi) {
                let px = Int64(order[Int64(j)])
                var c: Int64 = 0
                while (c < 4) {
                    sum[c] += UInt64(rgba[px * 4 + c])
                    c += 1
                }
                j += 1
            }
            let cnt: UInt64 = UInt64(b.hi - b.lo)
            if (cnt > 0) {
                var c: Int64 = 0
                while (c < 4) {
                    palette[i * 4 + c] = UInt8((sum[c] + cnt / 2) / cnt)
                    c += 1
                }
            }
            if (palette[i * 4 + 3] < 255) { hasAlpha = true }
            i += 1
        }

        var indices = Array<UInt8>(Int64(n), item: 0)
        if (opts.dither) {
            mapFloydSteinberg(rgba, w, h, palette, k, indices)
        } else {
            // 直接最近条目映射
            var px: Int64 = 0
            while (px < Int64(n)) {
                indices[px] = nearestPalette(palette, k,
                    Int32(rgba[px * 4 + 0]),
                    Int32(rgba[px * 4 + 1]),
                    Int32(rgba[px * 4 + 2]),
                    Int32(rgba[px * 4 + 3]))
                px += 1
            }
        }

        return QuantizeResult(palette: palette, indices: indices, colors: k, hasAlpha: hasAlpha)
    }

    /// Floyd-Steinberg 误差扩散
    /// 对应 Bun: mapFloydSteinberg
    static func mapFloydSteinberg(rgba: Array<UInt8>, w: UInt32, h: UInt32,
        palette: Array<UInt8>, k: UInt16, indices: Array<UInt8>): Unit {

        let stride = Int64(w) * 4
        var cur = Array<Int32>(stride, item: 0)
        var nxt = Array<Int32>(stride, item: 0)

        var y: UInt32 = 0
        while (y < h) {
            let ltr = (y & 1) == 0
            var x: Int64 = if (ltr) { 0 } else { Int64(w) - 1 }
            let step: Int64 = if (ltr) { 1 } else { -1 }

            while (x >= 0 && x < Int64(w)) {
                let px: Int64 = Int64(y) * Int64(w) + x
                let off: Int64 = x * 4

                var cand = Array<Int32>(4, item: 0)
                var c: Int64 = 0
                while (c < 4) {
                    cand[c] = Int32(rgba[px * 4 + c]) + cur[off + c]
                    c += 1
                }

                let idx: UInt8 = nearestPalette(palette, k,
                    clamp255(cand[0]), clamp255(cand[1]),
                    clamp255(cand[2]), clamp255(cand[3]))
                indices[px] = idx

                c = 0
                while (c < 4) {
                    let err: Int32 = cand[c] - Int32(palette[Int64(idx) * 4 + c])
                    let dir = step
                    let xr = x + dir
                    let xl = x - dir
                    if (xr >= 0 && xr < Int64(w)) {
                        cur[xr * 4 + c] += (err * 7) >> 4
                    }
                    if (xl >= 0 && xl < Int64(w)) {
                        nxt[xl * 4 + c] += (err * 3) >> 4
                    }
                    nxt[off + c] += (err * 5) >> 4
                    if (xr >= 0 && xr < Int64(w)) {
                        nxt[xr * 4 + c] += err >> 4
                    }
                    c += 1
                }
                x += step
            }
            // 交换: 下一行的误差变为当前
            var tmp = cur
            cur = nxt
            nxt = tmp
            var z: Int64 = 0
            while (z < stride) {
                nxt[z] = 0
                z += 1
            }
            y += 1
        }
    }

    /// 找最近调色板条目
    static func nearestPalette(palette: Array<UInt8>, k: UInt16, r: Int32, g: Int32, b: Int32, a: Int32): UInt8 {
        var bestDist: Int64 = Int64.MaxValue
        var bestIdx: UInt8 = 0
        var i: Int64 = 0
        while (i < Int64(k)) {
            let dr = r - Int32(palette[i * 4 + 0])
            let dg = g - Int32(palette[i * 4 + 1])
            let db = b - Int32(palette[i * 4 + 2])
            let da = a - Int32(palette[i * 4 + 3])
            let dist: Int64 = Int64(dr) * Int64(dr) + Int64(dg) * Int64(dg) +
                              Int64(db) * Int64(db) + Int64(da) * Int64(da)
            if (dist < bestDist) {
                bestDist = dist
                bestIdx = UInt8(i)
            }
            i += 1
        }
        return bestIdx
    }

    static func clamp255(v: Int32): Int32 {
        if (v < 0) { return 0 }
        if (v > 255) { return 255 }
        return v
    }

    /// 重新计算盒子的紧密 min/max
    static func shrink(rgba: Array<UInt8>, order: Array<UInt32>, lo: UInt32, hi: UInt32): QuantizeBox {
        var box = QuantizeBox()
        box.lo = lo
        box.hi = hi
        var c: Int64 = 0
        while (c < 4) {
            box.min[c] = 255
            box.max[c] = 0
            c += 1
        }
        var j: UInt32 = lo
        while (j < hi) {
            let px = Int64(order[Int64(j)])
            c = 0
            while (c < 4) {
                let v = rgba[px * 4 + c]
                if (v < box.min[c]) { box.min[c] = v }
                if (v > box.max[c]) { box.max[c] = v }
                c += 1
            }
            j += 1
        }
        return box
    }

    /// 按选定通道部分排序
    static func sortPartial(rgba: Array<UInt8>, order: Array<UInt32>, lo: UInt32, hi: UInt32, ch: Int64): Unit {
        // 简单选择排序（对于盒子大小足够用）
        var i: UInt32 = lo
        while (i < hi) {
            var minIdx = i
            var j: UInt32 = i + 1
            while (j < hi) {
                let pxA = Int64(order[Int64(j)]) * 4 + ch
                let pxB = Int64(order[Int64(minIdx)]) * 4 + ch
                if (rgba[pxA] < rgba[pxB]) {
                    minIdx = j
                }
                j += 1
            }
            if (minIdx != i) {
                let tmp = order[Int64(i)]
                order[Int64(i)] = order[Int64(minIdx)]
                order[Int64(minIdx)] = tmp
            }
            i += 1
        }
    }

    static func max(a: UInt16, b: UInt16): UInt16 {
        if (a > b) { a } else { b }
    }

    static func min(a: UInt16, b: UInt16): UInt16 {
        if (a < b) { a } else { b }
    }
}
