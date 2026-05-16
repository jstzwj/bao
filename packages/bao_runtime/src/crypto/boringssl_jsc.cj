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
    /// 对应 Bun: pub fn ERR_toJS(*jsc.JSGlobalObject, err_code: u32) jsc.JSValue
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
    private static func sliceTo(arr: Array<Byte>, terminator: Byte): String {
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
// BoringSSL FFI 声明 - foreign func 声明
// 对应 Bun: bun.BoringSSL.c 中的 C 函数
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs
// ============================================================================

// ── C 兼容结构体 (opaque 或 by-value layout) ─────────────────────────────
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:74-178

/// 对应 BoringSSL C: struct engine_st (opaque)
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:76
@C
struct EngineStruct {
    var _opaque: UInt64
}

/// 对应 BoringSSL C: struct env_md_st (opaque, 返回静态单例指针)
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:79
@C
struct EvpMdStruct {
    var _opaque: UInt64
}

/// 对应 BoringSSL C: struct env_md_ctx_st (by-value layout)
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:160-165
@C
struct EvpMdCtxStruct {
    var md_data: Array<Byte>   // union { uint8[240]; uint64 alignment; }
    var digest: CPointer<EvpMdStruct>
    var pctx: CPointer<Byte>   // *mut EVP_PKEY_CTX (opaque)
    var pctx_ops: CPointer<Byte> // *const evp_md_pctx_ops (opaque)
}

/// 对应 BoringSSL C: struct hmac_ctx_st (by-value layout)
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:173-178
@C
struct HmacCtxStruct {
    var md: CPointer<EvpMdStruct>
    var md_ctx: EvpMdCtxStruct
    var i_ctx: EvpMdCtxStruct
    var o_ctx: EvpMdCtxStruct
}

// ── BoringSSL C 函数声明 (foreign func) ─────────────────────────────────
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:308-803

// ── crypto / err ────────────────────────────────────────────────────────
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:311-315, 737-738
@C
foreign func CRYPTO_library_init(): Unit

@C
foreign func OpenSSL_add_all_algorithms(): Unit

@C
foreign func ERR_error_string_n(packed_error: UInt32, buf: CPointer<Byte>, len: UIntNative): CPointer<Byte>

@C
foreign func ERR_get_error(): UInt32

@C
foreign func ERR_clear_error(): Unit

// ── EVP digest getters (返回静态单例指针) ───────────────────────────────
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:322-338
@C
foreign func EVP_md4(): CPointer<EvpMdStruct>

@C
foreign func EVP_md5(): CPointer<EvpMdStruct>

@C
foreign func EVP_ripemd160(): CPointer<EvpMdStruct>

@C
foreign func EVP_sha1(): CPointer<EvpMdStruct>

@C
foreign func EVP_sha224(): CPointer<EvpMdStruct>

@C
foreign func EVP_sha256(): CPointer<EvpMdStruct>

@C
foreign func EVP_sha384(): CPointer<EvpMdStruct>

@C
foreign func EVP_sha512(): CPointer<EvpMdStruct>

@C
foreign func EVP_sha512_224(): CPointer<EvpMdStruct>

@C
foreign func EVP_sha512_256(): CPointer<EvpMdStruct>

@C
foreign func EVP_sha3_224(): CPointer<EvpMdStruct>

@C
foreign func EVP_sha3_256(): CPointer<EvpMdStruct>

@C
foreign func EVP_sha3_384(): CPointer<EvpMdStruct>

@C
foreign func EVP_sha3_512(): CPointer<EvpMdStruct>

@C
foreign func EVP_blake2b256(): CPointer<EvpMdStruct>

@C
foreign func EVP_blake2b512(): CPointer<EvpMdStruct>

// ── EVP digest ctx ──────────────────────────────────────────────────────
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:343-372
@C
foreign func EVP_MD_CTX_init(ctx: CPointer<EvpMdCtxStruct>): Unit

@C
foreign func EVP_MD_CTX_cleanup(ctx: CPointer<EvpMdCtxStruct>): Int32

@C
foreign func EVP_MD_CTX_copy_ex(out: CPointer<EvpMdCtxStruct>, in_: CPointer<EvpMdCtxStruct>): Int32

@C
foreign func EVP_MD_CTX_size(ctx: CPointer<EvpMdCtxStruct>): UIntNative

@C
foreign func EVP_DigestInit_ex(ctx: CPointer<EvpMdCtxStruct>, type_: CPointer<EvpMdStruct>, engine: CPointer<EngineStruct>): Int32

@C
foreign func EVP_DigestUpdate(ctx: CPointer<EvpMdCtxStruct>, data: CPointer<Byte>, len: UIntNative): Int32

@C
foreign func EVP_DigestFinal_ex(ctx: CPointer<EvpMdCtxStruct>, md_out: CPointer<Byte>, out_size: CPointer<UInt32>): Int32

@C
foreign func EVP_get_digestbyname(name: CPointer<Byte>): CPointer<EvpMdStruct>

@C
foreign func EVP_Digest(data: CPointer<Byte>, len: UIntNative, md_out: CPointer<Byte>, md_out_size: CPointer<UInt32>, type_: CPointer<EvpMdStruct>, impl_: CPointer<EngineStruct>): Int32

// ── HMAC (streaming) ────────────────────────────────────────────────────
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:753-765
@C
foreign func HMAC_CTX_init(ctx: CPointer<HmacCtxStruct>): Unit

@C
foreign func HMAC_CTX_cleanup(ctx: CPointer<HmacCtxStruct>): Unit

@C
foreign func HMAC_CTX_copy(dest: CPointer<HmacCtxStruct>, src: CPointer<HmacCtxStruct>): Int32

@C
foreign func HMAC_Init_ex(ctx: CPointer<HmacCtxStruct>, key: CPointer<Byte>, key_len: UIntNative, md: CPointer<EvpMdStruct>, impl_: CPointer<EngineStruct>): Int32

@C
foreign func HMAC_Update(ctx: CPointer<HmacCtxStruct>, data: CPointer<Byte>, data_len: UIntNative): Int32

@C
foreign func HMAC_Final(ctx: CPointer<HmacCtxStruct>, out: CPointer<Byte>, out_len: CPointer<UInt32>): Int32

@C
foreign func HMAC_size(ctx: CPointer<HmacCtxStruct>): UIntNative

// ── PBKDF2 ──────────────────────────────────────────────────────────────
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:794-803
@C
foreign func PKCS5_PBKDF2_HMAC(password: CPointer<Byte>, password_len: UIntNative, salt: CPointer<Byte>, salt_len: UIntNative, iterations: UInt32, digest: CPointer<EvpMdStruct>, key_len: UIntNative, out_key: CPointer<Byte>): Int32


// ============================================================================
// BoringSSL C接口封装 (高级封装层)
// 对应 Bun: bun.BoringSSL.c
// ============================================================================

/// BoringSSL C接口封装
/// 对应 Bun: bun.BoringSSL.c
public class BoringSSL {

    /// BoringSSL 初始化加载
    /// 对应 Bun: bun.BoringSSL.load() / boringssl::load()
    /// 确保所有必要的 BoringSSL 内部表和算法已注册
    /// 通常在第一次使用 EVP 之前调用
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:311,315
    public static func load(): Unit {
        // CRYPTO_library_init() + OpenSSL_add_all_algorithms()
        // 对应 Bun: boringssl::load()
        CRYPTO_library_init()
        OpenSSL_add_all_algorithms()
    }

    /// ERR_error_string_n - 获取错误描述字符串
    /// 对应 Bun: BoringSSL.ERR_error_string_n
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:313
    public static func errErrorStringN(n: UInt32, buf: Array<Byte>, bufLen: Int64): Unit {
        // FFI 调用: ERR_error_string_n(err_code, buf, len)
        // 将 Array<Byte> 转为 CPointer<Byte> 传递给 C 函数
        let bufPtr = unsafe { CPointerUtils.fromArray(buf) }
        ERR_error_string_n(errCode, bufPtr, UIntNative(bufLen))
    }

    /// ERR_get_error - 获取错误码
    /// 对应 Bun: BoringSSL.ERR_get_error
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:738
    public static func errGetError(): UInt32 {
        return ERR_get_error()
    }

    /// ERR_clear_error - 清除错误
    /// 对应 Bun: BoringSSL.ERR_clear_error
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:737
    public static func errClearError(): Unit {
        ERR_clear_error()
    }

    // ========================================================================
    // EVP 相关 FFI
    // ========================================================================

    /// EVP_MAX_MD_SIZE 常量
    /// 对应 Bun: BoringSSL.EVP_MAX_MD_SIZE
    public static let EVP_MAX_MD_SIZE: Int64 = 64

    /// EVP_blake2b256
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:337
    public static func evpBlake2b256(): EvpMd {
        let ptr = EVP_blake2b256()
        return EvpMd.fromPtr(ptr, EvpMdType.BLAKE2B256)
    }

    /// EVP_blake2b512
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:338
    public static func evpBlake2b512(): EvpMd {
        let ptr = EVP_blake2b512()
        return EvpMd.fromPtr(ptr, EvpMdType.BLAKE2B512)
    }

    /// EVP_md4
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:322
    public static func evpMd4(): EvpMd {
        let ptr = EVP_md4()
        return EvpMd.fromPtr(ptr, EvpMdType.MD4)
    }

    /// EVP_md5
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:323
    public static func evpMd5(): EvpMd {
        let ptr = EVP_md5()
        return EvpMd.fromPtr(ptr, EvpMdType.MD5)
    }

    /// EVP_ripemd160
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:325
    public static func evpRipemd160(): EvpMd {
        let ptr = EVP_ripemd160()
        return EvpMd.fromPtr(ptr, EvpMdType.RIPEMD160)
    }

    /// EVP_sha1
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:326
    public static func evpSha1(): EvpMd {
        let ptr = EVP_sha1()
        return EvpMd.fromPtr(ptr, EvpMdType.SHA1)
    }

    /// EVP_sha224
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:327
    public static func evpSha224(): EvpMd {
        let ptr = EVP_sha224()
        return EvpMd.fromPtr(ptr, EvpMdType.SHA224)
    }

    /// EVP_sha256
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:328
    public static func evpSha256(): EvpMd {
        let ptr = EVP_sha256()
        return EvpMd.fromPtr(ptr, EvpMdType.SHA256)
    }

    /// EVP_sha384
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:329
    public static func evpSha384(): EvpMd {
        let ptr = EVP_sha384()
        return EvpMd.fromPtr(ptr, EvpMdType.SHA384)
    }

    /// EVP_sha512
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:330
    public static func evpSha512(): EvpMd {
        let ptr = EVP_sha512()
        return EvpMd.fromPtr(ptr, EvpMdType.SHA512)
    }

    /// EVP_sha512_224
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:331
    public static func evpSha512224(): EvpMd {
        let ptr = EVP_sha512_224()
        return EvpMd.fromPtr(ptr, EvpMdType.SHA512_224)
    }

    /// EVP_sha512_256
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:332
    public static func evpSha512256(): EvpMd {
        let ptr = EVP_sha512_256()
        return EvpMd.fromPtr(ptr, EvpMdType.SHA512_256)
    }

    /// EVP_sha3_224
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:333
    public static func evpSha3_224(): EvpMd {
        let ptr = EVP_sha3_224()
        return EvpMd.fromPtr(ptr, EvpMdType.SHA3_224)
    }

    /// EVP_sha3_256
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:334
    public static func evpSha3_256(): EvpMd {
        let ptr = EVP_sha3_256()
        return EvpMd.fromPtr(ptr, EvpMdType.SHA3_256)
    }

    /// EVP_sha3_384
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:335
    public static func evpSha3_384(): EvpMd {
        let ptr = EVP_sha3_384()
        return EvpMd.fromPtr(ptr, EvpMdType.SHA3_384)
    }

    /// EVP_sha3_512
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:336
    public static func evpSha3_512(): EvpMd {
        let ptr = EVP_sha3_512()
        return EvpMd.fromPtr(ptr, EvpMdType.SHA3_512)
    }

    /// EVP_get_digestbyname
    /// 对应 Bun: BoringSSL.EVP_get_digestbyname
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:360
    public static func evpGetDigestByName(s: String): ?EvpMd {
        // FFI 调用: EVP_get_digestbyname(name)
        // 将名称字符串转为 C 指针传递
        let nameBytes = name.toArray()
        // 需要添加 null 终止符
        var cName = Array<Byte>(name.size + 1, repeat: 0)
        for (i in 0..name.size) {
            cName[i] = nameBytes[i]
        }
        cName[name.size] = 0
        let namePtr = unsafe { CPointerUtils.fromArray(cName) }
        let result = EVP_get_digestbyname(namePtr)
        if (unsafe { CPointerUtils.isNull(result) }) {
            return None
        }
        return Some(EvpMd.fromForeignPtr(result))
    }

    /// EVP_DigestInit_ex
    /// 对应 Bun: BoringSSL.EVP_DigestInit_ex
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:348-352
    public static func evpDigestInitEx(ctx: EvpMdCtx, md: EvpMd, engine: ?Engine): Int32 {
        // FFI 调用: EVP_DigestInit_ex(ctx, md, engine)
        let ctxPtr = ctx.getPtr()
        let mdPtr = md.getPtr()
        let enginePtr = match (engine) {
            case Some(e) => e.getPtr()
            case None => unsafe { CPointerUtils<EngineStruct>.null() }
        }
        return EVP_DigestInit_ex(ctxPtr, mdPtr, enginePtr)
    }

    /// EVP_DigestUpdate
    /// 对应 Bun: BoringSSL.EVP_DigestUpdate
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:353
    public static func evpDigestUpdate(ctx: EvpMdCtx, data: Array<Byte>, dataLen: Int64): Int32 {
        // FFI 调用: EVP_DigestUpdate(ctx, data, dataLen)
        let ctxPtr = ctx.getPtr()
        let dataPtr = unsafe { CPointerUtils.fromArray(data) }
        return EVP_DigestUpdate(ctxPtr, dataPtr, UIntNative(dataLen))
    }

    /// EVP_DigestFinal_ex
    /// 对应 Bun: BoringSSL.EVP_DigestFinal_ex
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:355-359
    public static func evpDigestFinalEx(ctx: EvpMdCtx, output: Array<Byte>, outSize: Array<UInt32>): Int32 {
        // FFI 调用: EVP_DigestFinal_ex(ctx, output, outSize)
        let ctxPtr = ctx.getPtr()
        let outPtr = unsafe { CPointerUtils.fromArray(output) }
        let outSizePtr = unsafe { CPointerUtils.fromArray(outSize) }
        return EVP_DigestFinal_ex(ctxPtr, outPtr, outSizePtr)
    }

    /// EVP_Digest
    /// 对应 Bun: BoringSSL.EVP_Digest
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:365-372
    public static func evpDigest(input: Array<Byte>, dataLen: Int64, output: Array<Byte>,
                                  outSize: Array<UInt32>, md: EvpMd, engine: ?Engine): Int32 {
        // FFI 调用: EVP_Digest(data, dataLen, output, outSize, md, engine)
        let dataPtr = unsafe { CPointerUtils.fromArray(input) }
        let outPtr = unsafe { CPointerUtils.fromArray(output) }
        let outSizePtr = unsafe { CPointerUtils.fromArray(outSize) }
        let mdPtr = md.getPtr()
        let enginePtr = match (engine) {
            case Some(e) => e.getPtr()
            case None => unsafe { CPointerUtils<EngineStruct>.null() }
        }
        return EVP_Digest(dataPtr, UIntNative(dataLen), outPtr, outSizePtr, mdPtr, enginePtr)
    }

    /// EVP_MD_CTX_init
    /// 对应 Bun: BoringSSL.EVP_MD_CTX_init
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:343
    public static func evpMdCtxInit(ctx: EvpMdCtx): Unit {
        // FFI 调用: EVP_MD_CTX_init(ctx)
        let ctxPtr = ctx.getPtr()
        EVP_MD_CTX_init(ctxPtr)
    }

    /// EVP_MD_CTX_cleanup
    /// 对应 Bun: BoringSSL.EVP_MD_CTX_cleanup
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:344
    public static func evpMdCtxCleanup(ctx: EvpMdCtx): Int32 {
        // FFI 调用: EVP_MD_CTX_cleanup(ctx)
        let ctxPtr = ctx.getPtr()
        return EVP_MD_CTX_cleanup(ctxPtr)
    }

    /// EVP_MD_CTX_size
    /// 对应 Bun: BoringSSL.EVP_MD_CTX_size
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:346
    public static func evpMdCtxSize(ctx: EvpMdCtx): Int64 {
        // FFI 调用: EVP_MD_CTX_size(ctx)
        let ctxPtr = ctx.getPtr()
        let size = EVP_MD_CTX_size(ctxPtr)
        return Int64(size)
    }

    /// EVP_MD_CTX_copy_ex
    /// 对应 Bun: BoringSSL.EVP_MD_CTX_copy_ex
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:345
    public static func evpMdCtxCopyEx(ctx: EvpMdCtx, src: EvpMdCtx): Int32 {
        // FFI 调用: EVP_MD_CTX_copy_ex(dst, src)
        let dstPtr = dst.getPtr()
        let srcPtr = src.getPtr()
        return EVP_MD_CTX_copy_ex(dstPtr, srcPtr)
    }

    // ========================================================================
    // HMAC 相关 FFI
    // ========================================================================

    /// HMAC_CTX_init
    /// 对应 Bun: BoringSSL.HMAC_CTX_init
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:753
    public static func hmacCtxInit(ctx: HmacCtx): Unit {
        // FFI 调用: HMAC_CTX_init(ctx)
        let ctxPtr = ctx.getPtr()
        HMAC_CTX_init(ctxPtr)
    }

    /// HMAC_CTX_cleanup
    /// 对应 Bun: BoringSSL.HMAC_CTX_cleanup
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:754
    public static func hmacCtxCleanup(ctx: HmacCtx): Unit {
        // FFI 调用: HMAC_CTX_cleanup(ctx)
        let ctxPtr = ctx.getPtr()
        HMAC_CTX_cleanup(ctxPtr)
    }

    /// HMAC_Init_ex
    /// 对应 Bun: BoringSSL.HMAC_Init_ex
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:756-762
    public static func hmacInitEx(ctx: HmacCtx, key: Array<Byte>, keyLen: Int64,
                                   md: EvpMd, engine: ?Engine): Int32 {
        // FFI 调用: HMAC_Init_ex(ctx, key, keyLen, md, engine)
        let ctxPtr = ctx.getPtr()
        let keyPtr = unsafe { CPointerUtils.fromArray(key) }
        let mdPtr = md.getPtr()
        let enginePtr = match (engine) {
            case Some(e) => e.getPtr()
            case None => unsafe { CPointerUtils<EngineStruct>.null() }
        }
        return HMAC_Init_ex(ctxPtr, keyPtr, UIntNative(keyLen), mdPtr, enginePtr)
    }

    /// HMAC_Update
    /// 对应 Bun: BoringSSL.HMAC_Update
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:763
    public static func hmacUpdate(ctx: HmacCtx, data: Array<Byte>, dataLen: Int64): Int32 {
        // FFI 调用: HMAC_Update(ctx, data, dataLen)
        let ctxPtr = ctx.getPtr()
        let dataPtr = unsafe { CPointerUtils.fromArray(data) }
        return HMAC_Update(ctxPtr, dataPtr, UIntNative(dataLen))
    }

    /// HMAC_Final
    /// 对应 Bun: BoringSSL.HMAC_Final
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:764
    public static func hmacFinal(ctx: HmacCtx, output: Array<Byte>, outLen: Array<UInt32>): Int32 {
        // FFI 调用: HMAC_Final(ctx, output, outLen)
        let ctxPtr = ctx.getPtr()
        let outPtr = unsafe { CPointerUtils.fromArray(output) }
        let outLenPtr = unsafe { CPointerUtils.fromArray(outLen) }
        return HMAC_Final(ctxPtr, outPtr, outLenPtr)
    }

    /// HMAC_size
    /// 对应 Bun: BoringSSL.HMAC_size
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:765
    public static func hmacSize(ctx: HmacCtx): Int64 {
        // FFI 调用: HMAC_size(ctx)
        let ctxPtr = ctx.getPtr()
        let size = HMAC_size(ctxPtr)
        return Int64(size)
    }

    /// HMAC_CTX_copy
    /// 对应 Bun: BoringSSL.HMAC_CTX_copy
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:755
    public static func hmacCtxCopy(ctx: HmacCtx, src: HmacCtx): Int32 {
        // FFI 调用: HMAC_CTX_copy(dst, src)
        let dstPtr = dst.getPtr()
        let srcPtr = src.getPtr()
        return HMAC_CTX_copy(dstPtr, srcPtr)
    }

    // ========================================================================
    // PBKDF2 相关 FFI
    // ========================================================================

    /// PKCS5_PBKDF2_HMAC
    /// 对应 Bun: BoringSSL.PKCS5_PBKDF2_HMAC
    // 严格翻译自: Bun src/boringssl_sys/boringssl.rs:794-803
    public static func pkcs5Pbkdf2Hmac(password: ?Array<Byte>, passwordLen: Int64,
                                        salt: Array<Byte>, saltLen: Int64,
                                        iterations: UInt32, md: EvpMd,
                                        keyLen: Int64, output: Array<Byte>): Int32 {
        // FFI 调用: PKCS5_PBKDF2_HMAC(password, passwordLen, salt, saltLen, iterations, md, keyLen, output)
        // 对应 Bun: if (password.len > 0) password.ptr else null
        let passwordPtr = match (password) {
            case Some(pwd) => unsafe { CPointerUtils.fromArray(pwd) }
            case None => unsafe { CPointerUtils<Byte>.null() }
        }
        let saltPtr = unsafe { CPointerUtils.fromArray(salt) }
        let mdPtr = md.getPtr()
        let outPtr = unsafe { CPointerUtils.fromArray(output) }
        return PKCS5_PBKDF2_HMAC(
            passwordPtr, UIntNative(passwordLen),
            saltPtr, UIntNative(saltLen),
            iterations, mdPtr,
            UIntNative(keyLen), outPtr
        )
    }

    /// EVP_R_MEMORY_LIMIT_EXCEEDED 错误码
    /// 对应 Bun: BoringSSL.EVP_R_MEMORY_LIMIT_EXCEEDED
    public static let EVP_R_MEMORY_LIMIT_EXCEEDED: UInt32 = 107
}

// ============================================================================
// BoringSSL 类型封装
// 对应 Bun: BoringSSL C 结构体
// 这些类封装 C 指针, 通过 getPtr() 暴露给 foreign func
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:74-178
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
/// 对应 Bun: *const BoringSSL.EVP_MD (opaque pointer)
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:79 (opaque EVP_MD)
public class EvpMd {
    public let mdType: EvpMdType
    private var nativePtr: CPointer<EvpMdStruct>

    public init(mdType: EvpMdType) {
        this.mdType = mdType
        this.nativePtr = unsafe { CPointerUtils<EvpMdStruct>.null() }
    }

    /// 从 foreign func 返回指针创建
    public init(fromPtr: CPointer<EvpMdStruct>, mdType: EvpMdType) {
        this.nativePtr = fromPtr
        this.mdType = mdType
    }

    /// 从 foreign func 返回指针创建(不指定类型)
    public static func fromForeignPtr(ptr: CPointer<EvpMdStruct>): EvpMd {
        // 尝试根据指针推断类型, 回退到使用 SHA256 作为默认
        return EvpMd(fromPtr: ptr, mdType: EvpMdType.SHA256)
    }

    /// 供 BoringSSL 封装层使用: 从已知类型指针创建
    public static func fromPtr(ptr: CPointer<EvpMdStruct>, evpMdType: EvpMdType): EvpMd {
        return EvpMd(fromPtr: ptr, mdType: mdType)
    }

    /// 获取底层 C 指针, 用于传递给 foreign func
    public func getPtr(): CPointer<EvpMdStruct> {
        return this.nativePtr
    }
}

/// EVP_MD_CTX 结构封装
/// 对应 Bun: BoringSSL.EVP_MD_CTX (by-value layout)
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:160-165
public class EvpMdCtx {
    public var algorithm: ?EvpMdType
    // 底层 C 结构体分配在本机内存, 通过指针操作
    private var nativePtr: CPointer<EvpMdCtxStruct>

    public init() {
        algorithm = None
        // 分配本机内存用于 EvpMdCtxStruct
        // 对应 Bun: var ctx: BoringSSL.EVP_MD_CTX = undefined;
        this.nativePtr = unsafe { CPointerUtils<EvpMdCtxStruct>.alloc(1) }
    }

    /// 获取底层 C 指针, 用于传递给 foreign func
    public func getPtr(): CPointer<EvpMdCtxStruct> {
        return this.nativePtr
    }

    /// 析构时释放本机内存
    protected func finalize(): Unit {
        unsafe { CPointerUtils<EvpMdCtxStruct>.free(this.nativePtr) }
    }
}

/// ENGINE 结构封装
/// 对应 Bun: *BoringSSL.ENGINE (opaque pointer)
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:76 (opaque ENGINE)
public class Engine {
    private var nativePtr: CPointer<EngineStruct>

    public init() {
        this.nativePtr = unsafe { CPointerUtils<EngineStruct>.null() }
    }

    /// 从现有指针创建
    public init(fromPtr: CPointer<EngineStruct>) {
        this.nativePtr = fromPtr
    }

    /// 获取底层 C 指针, 用于传递给 foreign func
    public func getPtr(): CPointer<EngineStruct> {
        return this.nativePtr
    }
}

/// HMAC_CTX 结构封装
/// 对应 Bun: BoringSSL.HMAC_CTX (by-value layout)
// 严格翻译自: Bun src/boringssl_sys/boringssl.rs:173-178
public class HmacCtx {
    public var md: ?EvpMd
    public var key: Array<Byte>
    // 底层 C 结构体分配在本机内存, 通过指针操作
    private var nativePtr: CPointer<HmacCtxStruct>

    public init() {
        md = None
        key = Array<Byte>()
        // 分配本机内存用于 HmacCtxStruct
        // 对应 Bun: var ctx: BoringSSL.HMAC_CTX = undefined;
        this.nativePtr = unsafe { CPointerUtils<HmacCtxStruct>.alloc(1) }
    }

    /// 获取底层 C 指针, 用于传递给 foreign func
    public func getPtr(): CPointer<HmacCtxStruct> {
        return this.nativePtr
    }

    /// 析构时释放本机内存
    protected func finalize(): Unit {
        unsafe { CPointerUtils<HmacCtxStruct>.free(this.nativePtr) }
    }
}

// ============================================================================
// 字节数组比较辅助
// 用于 lookup 函数中的字面量字节比较
// ============================================================================

/// 字节数组相等比较
/// 对应 Rust/Zig: bytes == b"literal"
public func byteEquals(arr: Array<Byte>, b: Array<Byte>): Bool {
    if (a.size != b.size) {
        return false
    }
    for (i in 0..a.size) {
        if (a[i] != b[i]) {
            return false
        }
    }
    return true
}

/// 字节字面量比较辅助
/// 将字符串转为字节数组并比较
public func byteEqualsStr(arr: Array<Byte>, b: String): Bool {
    if (a.size != b.size) {
        return false
    }
    let bBytes = b.toArray()
    for (i in 0..a.size) {
        if (a[i] != bBytes[i]) {
            return false
        }
    }
    return true
}
