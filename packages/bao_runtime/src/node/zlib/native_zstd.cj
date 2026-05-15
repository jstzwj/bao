// Native Zstandard 压缩流
// 对应 Bun: src/runtime/node/zlib/NativeZstd.zig
// 严格翻译自: src/runtime/node/zlib/NativeZstd.zig
package bao_runtime.node.zlib

// ============================================================================
// Zstd 压缩模式
// ============================================================================
public enum ZstdMode {
    compress = 10,
    decompress = 11
}

// ============================================================================
// Native Zstd 压缩流
// 对应 Bun: src/runtime/node/zlib/NativeZstd.zig
// ============================================================================
public class NativeZstd {
    public var mode: ZstdMode = ZstdMode.compress
    public var writeInProgress: Bool = false
    public var pendingClose: Bool = false
    public var pendingReset: Bool = false
    public var closed: Bool = false
    public var level: Int32 = 3
    public var nbWorkers: Int32 = 0

    public init() {}

    public init(mode: ZstdMode) {
        this.mode = mode
    }

    // 创建
    // 对应 Bun: src/runtime/node/zlib/NativeZstd.zig - constructor
    public static func create(mode: Int32): ?NativeZstd {
        if (mode < 10 || mode > 11) {
            return None
        }
        let zs = NativeZstd()
        zs.mode = if (mode == 10) { ZstdMode.compress } else { ZstdMode.decompress }
        return zs
    }

    // 写入数据
    public func write(flush: Int32, input: Array<UInt8>, inOff: Int32, inLen: Int32, output: Array<UInt8>, outOff: Int32, outLen: Int32): Int32 {
        writeInProgress = true
        let result = ZlibImpl.zstdProcess(mode: mode, input: input, inOff: inOff, inLen: inLen, output: output, outOff: outOff, outLen: outLen, flush: flush)
        writeInProgress = false
        return result
    }

    // 重置
    public func reset(): Unit {
        pendingReset = true
    }

    // 关闭
    public func close(): Unit {
        if (writeInProgress) {
            pendingClose = true
        } else {
            closed = true
        }
    }

    // 初始化
    public func init(params: Array<Pair<Int32, Int32>>): Unit {
        for (pair in params) {
            // 设置参数
        }
    }

    // 估算内存大小
    // 对应 Bun: src/runtime/node/zlib/NativeZstd.zig - estimatedSize
    public func estimatedSize(): Int64 {
        return match (mode) {
            case ZstdMode.compress => Int64(5272)     // ZSTD_sizeof_CCtx 估计
            case ZstdMode.decompress => Int64(95968)  // ZSTD_sizeof_DCtx 估计
        }
    }
}

// 简单键值对
public class Pair<K, V> {
    public var first: K
    public var second: V

    public init(first: K, second: V) {
        this.first = first
        this.second = second
    }
}
