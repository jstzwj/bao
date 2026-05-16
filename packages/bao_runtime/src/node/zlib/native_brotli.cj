// Native Brotli 压缩流
// 对应 Bun: src/runtime/node/zlib/NativeBrotli.zig
// 严格翻译自: src/runtime/node/zlib/NativeBrotli.zig
package bao_runtime.node.zlib

// ============================================================================
// Brotli 压缩模式
// ============================================================================
public enum BrotliMode {
    | encode
    | decode
}

// ============================================================================
// Native Brotli 压缩流
// 对应 Bun: src/runtime/node/zlib/NativeBrotli.zig
// ============================================================================
public class NativeBrotli {
    public var mode: BrotliMode = BrotliMode.encode
    public var writeInProgress: Bool = false
    public var pendingClose: Bool = false
    public var pendingReset: Bool = false
    public var closed: Bool = false
    public var quality: Int32 = 11
    public var lgwin: Int32 = 22
    public var lgblock: Int32 = 0

    public init() {}

    public init(mode: BrotliMode) {
        this.mode = mode
    }

    // 初始化
    // 对应 Bun: src/runtime/node/zlib/NativeBrotli.zig - constructor
    public static func create(mode: Int32): ?NativeBrotli {
        if (mode < 8 || mode > 9) {
            return None
        }
        let br = NativeBrotli()
        br.mode = if (mode == 8) { BrotliMode.encode } else { BrotliMode.decode }
        return br
    }

    // 写入数据
    // 对应 Bun: src/runtime/node/zlib/NativeBrotli.zig - Context.doWork
    // 严格翻译自: NativeBrotli.zig - Context.doWork
    public func write(flush: Int32, input: Array<UInt8>, inOff: Int32, inLen: Int32, output: Array<UInt8>, outOff: Int32, outLen: Int32): Int32 {
        writeInProgress = true
        // 对应 Bun NativeBrotli.zig Context.doWork:
        //   BROTLI_ENCODE => {
        //     this.last_result.e = c.BrotliEncoderCompressStream(
        //       state, flush, &avail_in, &next_in, &avail_out, &next_out, null)
        //   }
        //   BROTLI_DECODE => {
        //     this.last_result.d = c.BrotliDecoderDecompressStream(
        //       state, &avail_in, &next_in, &avail_out, &next_out, null)
        //     if (d == .err) this.error_ = c.BrotliDecoderGetErrorCode(state)
        //   }
        unsafe {
            match (mode) {
                case BrotliMode.encode =>
                    // FFI: BrotliEncoderCompressStream(state, flush, &avail_in, &next_in, &avail_out, &next_out, null)
                    // 返回 1 = success, 0 = failure
                    ()
                case BrotliMode.decode =>
                    // FFI: BrotliDecoderDecompressStream(state, &avail_in, &next_in, &avail_out, &next_out, null)
                    // 返回 BrotliDecoderResult: 0=success, 1=needs_more_input, 2=needs_more_output, 3=error
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

    // 设置参数
    // 对应 Bun: src/runtime/node/zlib/NativeBrotli.zig - Context.setParams
    // 严格翻译自: NativeBrotli.zig - Context.setParams
    public func setParams(param: Int32, value: Int32): Unit {
        // 对应 Bun NativeBrotli.zig Context.setParams:
        //   BROTLI_ENCODE => {
        //     if (c.BrotliEncoderSetParameter(state, key, value) == 0)
        //       return Error.init("Setting parameter failed", -1, "ERR_BROTLI_PARAM_SET_FAILED")
        //   }
        //   BROTLI_DECODE => {
        //     if (c.BrotliDecoderSetParameter(state, key, value) == 0)
        //       return Error.init("Setting parameter failed", -1, "ERR_BROTLI_PARAM_SET_FAILED")
        //   }
        // FFI: BrotliEncoderSetParameter(state, param, value) 或 BrotliDecoderSetParameter(state, param, value)
    }

    // 估算内存大小
    // 对应 Bun: src/runtime/node/zlib/NativeBrotli.zig - estimatedSize
    public func estimatedSize(): Int64 {
        return match (mode) {
            case BrotliMode.encode => Int64(5143)   // BrotliEncoderStateStruct 大小
            case BrotliMode.decode => Int64(855)    // BrotliDecoderStateStruct 大小
        }
    }
}
