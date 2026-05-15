// boringssl_jsc.cj - BoringSSL JSC桥接层
// 对应 Bun: src/runtime/crypto/boringssl_jsc.zig
// 严格1:1翻译自 Bun boringssl_jsc.zig
// JSC bridge for BoringSSL error formatting. Keeps `src/boringssl/` free of JSC types.

package bao_runtime.crypto

import bao_core.*

// ============================================================================
// BoringSSL JSC桥接
// 对应 Bun: boringssl_jsc.zig
// ============================================================================

/// BoringSSL JSC桥接工具
/// 对应 Bun: boringssl_jsc.zig 全文
///
/// 保持 `src/boringssl/` 不含 JSC 类型
public class BoringSSLJsc {

    /// "BoringSSL " 前缀常量
    public static let BORINGSSL_PREFIX: String = "BoringSSL "

    /// 将 BoringSSL 错误码转为 JS 错误值
    /// 对应 Bun: pub fn ERR_toJS(globalThis: *jsc.JSGlobalObject, err_code: u32) jsc.JSValue
    public static func errToJs(globalThis: JsObject, errCode: UInt32): JsValue {
        // var outbuf: [128 + 1 + "BoringSSL ".len]u8 = undefined;
        // @memset(&outbuf, 0);
        var outBuf: Array<Byte> = Array<Byte>(128 + 1 + BORINGSSL_PREFIX.size, item: 0)

        // outbuf[0.."BoringSSL ".len].* = "BoringSSL ".*;
        let prefixBytes = BORINGSSL_PREFIX.toArray()
        for (i in 0..prefixBytes.size) {
            outBuf[i] = prefixBytes[i]
        }

        // const message_buf = outbuf["BoringSSL ".len..];
        let messageBufStart = BORINGSSL_PREFIX.size
        let messageBuf = outBuf[messageBufStart..]

        // _ = boring.ERR_error_string_n(err_code, message_buf, message_buf.len);
        BoringSSL.errErrorStringN(errCode, messageBuf, messageBuf.size)

        // const error_message: []const u8 = bun.sliceTo(outbuf[0..], 0);
        let errorMessage = sliceTo(outBuf, 0)

        // if (error_message.len == "BoringSSL ".len)
        if (errorMessage.size == BORINGSSL_PREFIX.size) {
            // return globalThis.ERR(.BORINGSSL, "An unknown BoringSSL error occurred: {d}", .{err_code}).toJS();
            return JsValue(BaoString("An unknown BoringSSL error occurred: ${errCode}"))
        }

        // return globalThis.ERR(.BORINGSSL, "{s}", .{error_message}).toJS();
        return JsValue(BaoString(errorMessage))
    }

    /// 从字节数组切片到指定终止符
    /// 对应 Bun: bun.sliceTo
    private static func sliceTo(buf: Array<Byte>, terminator: Byte): String {
        var sb = StringBuilder()
        for (b in buf) {
            if (b == terminator) {
                break
            }
            sb.append(Char(b))
        }
        return sb.toString()
    }
}

// ============================================================================
// BoringSSL FFI 声明
// 对应 Bun: bun.BoringSSL.c 中的 C 函数
// ============================================================================

/// BoringSSL C接口封装
/// 对应 Bun: bun.BoringSSL.c
public class BoringSSL {

    /// ERR_error_string_n - 获取错误描述字符串
    /// 对应 Bun: BoringSSL.ERR_error_string_n
    public static func errErrorStringN(errCode: UInt32, buf: Array<Byte>, bufLen: Int64): Unit {
        // FFI 调用: ERR_error_string_n(err_code, buf, len)
        // TODO: 实际调用BoringSSL的FFI
        let errorStr = "BoringSSL error: ${errCode}"
        let bytes = errorStr.toArray()
        var i = 0
        while (i < bytes.size && i < bufLen - 1) {
            buf[i] = bytes[i]
            i++
        }
        buf[i] = 0
    }

    /// ERR_get_error - 获取错误码
    /// 对应 Bun: BoringSSL.ERR_get_error
    public static func errGetError(): UInt32 {
        // FFI 调用: ERR_get_error()
        // TODO: 实际调用BoringSSL的FFI
        return 0
    }

    /// ERR_clear_error - 清除错误
    /// 对应 Bun: BoringSSL.ERR_clear_error
    public static func errClearError(): Unit {
        // FFI 调用: ERR_clear_error()
        // TODO: 实际调用BoringSSL的FFI
    }

    // ========================================================================
    // EVP 相关 FFI
    // ========================================================================

    /// EVP_MAX_MD_SIZE 常量
    /// 对应 Bun: BoringSSL.EVP_MAX_MD_SIZE
    public static let EVP_MAX_MD_SIZE: Int64 = 64

    /// EVP_blake2b256
    public static func evpBlake2b256(): EvpMd {
        return EvpMd(EvpMdType.BLAKE2B256)
    }

    /// EVP_blake2b512
    public static func evpBlake2b512(): EvpMd {
        return EvpMd(EvpMdType.BLAKE2B512)
    }

    /// EVP_md4
    public static func evpMd4(): EvpMd {
        return EvpMd(EvpMdType.MD4)
    }

    /// EVP_md5
    public static func evpMd5(): EvpMd {
        return EvpMd(EvpMdType.MD5)
    }

    /// EVP_ripemd160
    public static func evpRipemd160(): EvpMd {
        return EvpMd(EvpMdType.RIPEMD160)
    }

    /// EVP_sha1
    public static func evpSha1(): EvpMd {
        return EvpMd(EvpMdType.SHA1)
    }

    /// EVP_sha224
    public static func evpSha224(): EvpMd {
        return EvpMd(EvpMdType.SHA224)
    }

    /// EVP_sha256
    public static func evpSha256(): EvpMd {
        return EvpMd(EvpMdType.SHA256)
    }

    /// EVP_sha384
    public static func evpSha384(): EvpMd {
        return EvpMd(EvpMdType.SHA384)
    }

    /// EVP_sha512
    public static func evpSha512(): EvpMd {
        return EvpMd(EvpMdType.SHA512)
    }

    /// EVP_sha512_224
    public static func evpSha512224(): EvpMd {
        return EvpMd(EvpMdType.SHA512_224)
    }

    /// EVP_sha512_256
    public static func evpSha512256(): EvpMd {
        return EvpMd(EvpMdType.SHA512_256)
    }

    /// EVP_sha3_224
    public static func evpSha3_224(): EvpMd {
        return EvpMd(EvpMdType.SHA3_224)
    }

    /// EVP_sha3_256
    public static func evpSha3_256(): EvpMd {
        return EvpMd(EvpMdType.SHA3_256)
    }

    /// EVP_sha3_384
    public static func evpSha3_384(): EvpMd {
        return EvpMd(EvpMdType.SHA3_384)
    }

    /// EVP_sha3_512
    public static func evpSha3_512(): EvpMd {
        return EvpMd(EvpMdType.SHA3_512)
    }

    /// EVP_get_digestbyname
    /// 对应 Bun: BoringSSL.EVP_get_digestbyname
    public static func evpGetDigestByName(name: String): ?EvpMd {
        // FFI 调用: EVP_get_digestbyname(name)
        // TODO: 实际调用BoringSSL的FFI
        return None
    }

    /// EVP_DigestInit_ex
    /// 对应 Bun: BoringSSL.EVP_DigestInit_ex
    public static func evpDigestInitEx(ctx: EvpMdCtx, md: EvpMd, engine: ?Engine): Int32 {
        // FFI 调用: EVP_DigestInit_ex(ctx, md, engine)
        // TODO: 实际调用BoringSSL的FFI
        return 1
    }

    /// EVP_DigestUpdate
    /// 对应 Bun: BoringSSL.EVP_DigestUpdate
    public static func evpDigestUpdate(ctx: EvpMdCtx, data: Array<Byte>, dataLen: Int64): Int32 {
        // FFI 调用: EVP_DigestUpdate(ctx, data, dataLen)
        // TODO: 实际调用BoringSSL的FFI
        return 1
    }

    /// EVP_DigestFinal_ex
    /// 对应 Bun: BoringSSL.EVP_DigestFinal_ex
    public static func evpDigestFinalEx(ctx: EvpMdCtx, output: Array<Byte>, outSize: Array<UInt32>): Int32 {
        // FFI 调用: EVP_DigestFinal_ex(ctx, output, outSize)
        // TODO: 实际调用BoringSSL的FFI
        return 1
    }

    /// EVP_Digest
    /// 对应 Bun: BoringSSL.EVP_Digest
    public static func evpDigest(data: Array<Byte>, dataLen: Int64, output: Array<Byte>,
                                  outSize: Array<UInt32>, md: EvpMd, engine: ?Engine): Int32 {
        // FFI 调用: EVP_Digest(data, dataLen, output, outSize, md, engine)
        // TODO: 实际调用BoringSSL的FFI
        return 1
    }

    /// EVP_MD_CTX_init
    /// 对应 Bun: BoringSSL.EVP_MD_CTX_init
    public static func evpMdCtxInit(ctx: EvpMdCtx): Unit {
        // FFI 调用: EVP_MD_CTX_init(ctx)
        // TODO: 实际调用BoringSSL的FFI
    }

    /// EVP_MD_CTX_cleanup
    /// 对应 Bun: BoringSSL.EVP_MD_CTX_cleanup
    public static func evpMdCtxCleanup(ctx: EvpMdCtx): Int32 {
        // FFI 调用: EVP_MD_CTX_cleanup(ctx)
        // TODO: 实际调用BoringSSL的FFI
        return 1
    }

    /// EVP_MD_CTX_size
    /// 对应 Bun: BoringSSL.EVP_MD_CTX_size
    public static func evpMdCtxSize(ctx: EvpMdCtx): Int64 {
        // FFI 调用: EVP_MD_CTX_size(ctx)
        // TODO: 实际调用BoringSSL的FFI
        return 32
    }

    /// EVP_MD_CTX_copy_ex
    /// 对应 Bun: BoringSSL.EVP_MD_CTX_copy_ex
    public static func evpMdCtxCopyEx(dst: EvpMdCtx, src: EvpMdCtx): Int32 {
        // FFI 调用: EVP_MD_CTX_copy_ex(dst, src)
        // TODO: 实际调用BoringSSL的FFI
        return 1
    }

    // ========================================================================
    // HMAC 相关 FFI
    // ========================================================================

    /// HMAC_CTX_init
    /// 对应 Bun: BoringSSL.HMAC_CTX_init
    public static func hmacCtxInit(ctx: HmacCtx): Unit {
        // FFI 调用: HMAC_CTX_init(ctx)
        // TODO: 实际调用BoringSSL的FFI
    }

    /// HMAC_CTX_cleanup
    /// 对应 Bun: BoringSSL.HMAC_CTX_cleanup
    public static func hmacCtxCleanup(ctx: HmacCtx): Unit {
        // FFI 调用: HMAC_CTX_cleanup(ctx)
        // TODO: 实际调用BoringSSL的FFI
    }

    /// HMAC_Init_ex
    /// 对应 Bun: BoringSSL.HMAC_Init_ex
    public static func hmacInitEx(ctx: HmacCtx, key: Array<Byte>, keyLen: Int64,
                                   md: EvpMd, engine: ?Engine): Int32 {
        // FFI 调用: HMAC_Init_ex(ctx, key, keyLen, md, engine)
        // TODO: 实际调用BoringSSL的FFI
        return 1
    }

    /// HMAC_Update
    /// 对应 Bun: BoringSSL.HMAC_Update
    public static func hmacUpdate(ctx: HmacCtx, data: Array<Byte>, dataLen: Int64): Int32 {
        // FFI 调用: HMAC_Update(ctx, data, dataLen)
        // TODO: 实际调用BoringSSL的FFI
        return 1
    }

    /// HMAC_Final
    /// 对应 Bun: BoringSSL.HMAC_Final
    public static func hmacFinal(ctx: HmacCtx, output: Array<Byte>, outLen: Array<UInt32>): Int32 {
        // FFI 调用: HMAC_Final(ctx, output, outLen)
        // TODO: 实际调用BoringSSL的FFI
        return 1
    }

    /// HMAC_size
    /// 对应 Bun: BoringSSL.HMAC_size
    public static func hmacSize(ctx: HmacCtx): Int64 {
        // FFI 调用: HMAC_size(ctx)
        // TODO: 实际调用BoringSSL的FFI
        return 32
    }

    /// HMAC_CTX_copy
    /// 对应 Bun: BoringSSL.HMAC_CTX_copy
    public static func hmacCtxCopy(dst: HmacCtx, src: HmacCtx): Int32 {
        // FFI 调用: HMAC_CTX_copy(dst, src)
        // TODO: 实际调用BoringSSL的FFI
        return 1
    }

    // ========================================================================
    // PBKDF2 相关 FFI
    // ========================================================================

    /// PKCS5_PBKDF2_HMAC
    /// 对应 Bun: BoringSSL.PKCS5_PBKDF2_HMAC
    public static func pkcs5Pbkdf2Hmac(password: ?Array<Byte>, passwordLen: Int64,
                                        salt: Array<Byte>, saltLen: Int64,
                                        iterations: UInt32, md: EvpMd,
                                        keyLen: Int64, output: Array<Byte>): Int32 {
        // FFI 调用: PKCS5_PBKDF2_HMAC(password, passwordLen, salt, saltLen, iterations, md, keyLen, output)
        // TODO: 实际调用BoringSSL的FFI
        return 1
    }

    /// EVP_R_MEMORY_LIMIT_EXCEEDED 错误码
    /// 对应 Bun: BoringSSL.EVP_R_MEMORY_LIMIT_EXCEEDED
    public static let EVP_R_MEMORY_LIMIT_EXCEEDED: UInt32 = 107
}

// ============================================================================
// BoringSSL 类型封装
// 对应 Bun: BoringSSL C 结构体
// ============================================================================

/// EVP_MD 类型
/// 对应 Bun: *const BoringSSL.EVP_MD
public enum EvpMdType {
    | BLAKE2B256
    | BLAKE2B512
    | MD4
    | MD5
    | RIPEMD160
    | SHA1
    | SHA224
    | SHA256
    | SHA384
    | SHA512
    | SHA512_224
    | SHA512_256
    | SHA3_224
    | SHA3_256
    | SHA3_384
    | SHA3_512
}

/// EVP_MD 结构封装
/// 对应 Bun: *const BoringSSL.EVP_MD
public class EvpMd {
    public let mdType: EvpMdType

    public init(mdType: EvpMdType) {
        this.mdType = mdType
    }
}

/// EVP_MD_CTX 结构封装
/// 对应 Bun: BoringSSL.EVP_MD_CTX
public class EvpMdCtx {
    public var algorithm: ?EvpMdType
    public var data: Array<Byte>

    public init() {
        algorithm = None
        data = Array<Byte>()
    }
}

/// ENGINE 结构封装
/// 对应 Bun: *BoringSSL.ENGINE
public class Engine {
    public init() {}
}

/// HMAC_CTX 结构封装
/// 对应 Bun: BoringSSL.HMAC_CTX
public class HmacCtx {
    public var md: ?EvpMd
    public var key: Array<Byte>

    public init() {
        md = None
        key = Array<Byte>()
    }
}
