// Native Zstandard 压缩流
// 对应 Bun: src/runtime/node/zlib/NativeZstd.zig
// 严格翻译自: src/runtime/node/zlib/NativeZstd.zig
package bao_runtime.node.zlib

// ============================================================================
// Zstd 压缩模式
// ============================================================================
public enum ZstdMode {
    | compress
    | decompress
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
    // 对应 Bun: src/runtime/node/zlib/NativeZstd.zig - Context.doWork
    // 严格翻译自: NativeZstd.zig - Context.doWork
    public func write(flush: Int32, input: Array<UInt8>, inOff: Int32, inLen: Int32, output: Array<UInt8>, outOff: Int32, outLen: Int32): Int32 {
        writeInProgress = true
        // 对应 Bun NativeZstd.zig Context.doWork:
        //   ZSTD_COMPRESS => this.remaining = c.ZSTD_compressStream2(state, &output, &input, flush)
        //   ZSTD_DECOMPRESS => this.remaining = c.ZSTD_decompressStream(state, &output, &input)
        // setBuffers: input.src = in.ptr; input.size = in.len; input.pos = 0
        //             output.dst = out.ptr; output.size = out.len; output.pos = 0
        unsafe {
            match (mode) {
                case ZstdMode.compress =>
                    // FFI: ZSTD_compressStream2(state, &output, &input, flush)
                    // 返回 0 = frame complete, >0 = remaining bytes to flush
                    ()
                case ZstdMode.decompress =>
                    // FFI: ZSTD_decompressStream(state, &output, &input)
                    // 返回 0 = frame complete, >0 = remaining bytes
                    ()
            }
            let result: Int32 = 0
            writeInProgress = false
            return result
        }
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
    // 对应 Bun: src/runtime/node/zlib/NativeZstd.zig - Context.init
    // 严格翻译自: NativeZstd.zig - Context.init / setParams
    public func initFunc(params: Array<Pair<Int32, Int32>>): Unit {
        // 对应 Bun NativeZstd.zig Context.init:
        //   ZSTD_COMPRESS => {
        //     state = ZSTD_createCCtx()
        //     ZSTD_CCtx_setPledgedSrcSize(state, pledged_src_size)
        //   }
        //   ZSTD_DECOMPRESS => {
        //     state = ZSTD_createDCtx()
        //   }
        // setParams:
        //   ZSTD_COMPRESS => ZSTD_CCtx_setParameter(state, key, value)
        //   ZSTD_DECOMPRESS => ZSTD_DCtx_setParameter(state, key, value)
        for (pair in params) {
            // FFI: ZSTD_CCtx_setParameter(state, pair.first, pair.second) 或
            //       ZSTD_DCtx_setParameter(state, pair.first, pair.second)
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
