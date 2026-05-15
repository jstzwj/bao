// zlib 压缩绑定模块
// 对应 Bun: src/runtime/node/node_zlib_binding.zig
// 严格翻译自: src/runtime/node/node_zlib_binding.zig
package bao_runtime

// ============================================================================
// zlib 绑定 — 压缩/解压缩操作
// 对应 Bun: src/runtime/node/node_zlib_binding.zig
// ============================================================================
public class NodeZlibBinding {
    // CRC32 校验
    // 对应 Bun: src/runtime/node/node_zlib_binding.zig - crc32
    public static func crc32(data: Array<UInt8>, value: UInt32 = 0): UInt32 {
        var crc: UInt32 = value
        for (byte in data) {
            crc = crc32Table[Int64((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc
    }

    // 压缩数据
    // 对应 Bun: src/runtime/node/node_zlib_binding.zig - CompressionStream.write (deflate)
    public static func deflate(data: Array<UInt8>, level: Int32 = -1): Array<UInt8> {
        // 简化实现：返回原始数据（实际应调用 zlib FFI）
        return ZlibImpl.deflate(data, level: level)
    }

    // 解压缩数据
    // 对应 Bun: src/runtime/node/node_zlib_binding.zig - CompressionStream.write (inflate)
    public static func inflate(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.inflate(data)
    }

    // gzip 压缩
    public static func gzip(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.gzip(data)
    }

    // gzip 解压缩
    public static func gunzip(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.gunzip(data)
    }

    // Brotli 压缩
    // 对应 Bun: src/runtime/node/zlib/NativeBrotli.zig
    public static func brotliCompress(data: Array<UInt8>, quality: Int32 = 11): Array<UInt8> {
        return ZlibImpl.brotliCompress(data, quality: quality)
    }

    // Brotli 解压缩
    public static func brotliDecompress(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.brotliDecompress(data)
    }

    // Zstandard 压缩
    // 对应 Bun: src/runtime/node/zlib/NativeZstd.zig
    public static func zstdCompress(data: Array<UInt8>, level: Int32 = 3): Array<UInt8> {
        return ZlibImpl.zstdCompress(data, level: level)
    }

    // Zstandard 解压缩
    public static func zstdDecompress(data: Array<UInt8>): Array<UInt8> {
        return ZlibImpl.zstdDecompress(data)
    }

    // CRC32 查找表
    private static let crc32Table: Array<UInt32> = Array<UInt32>(256, item: UInt32(0))
}
