// TimeLike — 时间值类型及转换
// 对应 Bun: src/runtime/node/time_like.zig
// 严格翻译自: src/runtime/node/time_like.zig
package bao_runtime.node

// ============================================================================
// TimeLike — 时间表示
// 对应 Bun: src/runtime/node/time_like.zig - TimeLike
// Unix 上为 timespec（秒 + 纳秒），Windows 上为 f64 秒
// ============================================================================
public class TimeLike {
    public var sec: Int64 = 0
    public var nsec: Int64 = 0

    public init() {}

    public init(sec: Int64, nsec: Int64) {
        this.sec = sec
        this.nsec = nsec
    }

    // 从秒数创建 TimeLike
    public static func fromSeconds(seconds: Float64): TimeLike {
        let tl = TimeLike()
        tl.sec = Int64(seconds)
        tl.nsec = Int64((seconds - Float64(Int64(seconds))) * 1000000000.0)
        return tl
    }

    // 从毫秒创建 TimeLike
    public static func fromMilliseconds(milliseconds: Float64): TimeLike {
        var sec: Float64 = Float64(Int64(milliseconds / 1000.0))
        var nsec: Float64 = (milliseconds % 1000.0) * 1000000.0

        if (nsec < 0.0) {
            nsec = nsec + 1000000000.0
            sec = sec - 1.0
        }

        let tl = TimeLike()
        tl.sec = Int64(sec)
        tl.nsec = Int64(nsec)
        return tl
    }

    // 创建表示"当前时间"的 TimeLike
    // 对应 Bun: src/runtime/node/time_like.zig - fromNow
    // 在 Linux 上使用 UTIME_NOW 语义（sec=0, nsec=UTIME_NOW）
    public static func fromNow(): TimeLike {
        let tl = TimeLike()
        tl.sec = 0
        // UTIME_NOW = (1 << 30) - 1 on Linux
        tl.nsec = 1073741823
        return tl
    }

    // 转换为毫秒
    public func toMilliseconds(): Float64 {
        return Float64(sec) * 1000.0 + Float64(nsec) / 1000000.0
    }

    // 转换为秒
    public func toSeconds(): Float64 {
        return Float64(sec) + Float64(nsec) / 1000000000.0
    }
}
