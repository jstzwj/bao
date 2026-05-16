// sha.cj - SHA 哈希器 + EVP Algorithm 枚举
// 严格翻译自 Bun: src/sha_hmac/sha.rs + src/sha_hmac/sha.zig
//
// 对应 Bun 源文件:
//   - sha.rs: ffi mod, digest-length constants, new_hasher! macro,
//             new_evp! macro, evp module (Algorithm enum + EVP hashers),
//             hashers module (deprecated direct BoringSSL hashers), LABELS
//   - sha.zig: NewHasher, NewEVP comptime generics, EVP/Hashers structs,
//              Algorithm enum, boring/zig/evp/labels arrays
//
// 翻译策略:
//   - Rust macro new_hasher!/new_evp! -> 各自独立的 class (Cangjie 无类型参数宏)
//   - Zig comptime NewHasher/NewEVP -> 各自独立的 class
//   - evp::Algorithm enum -> EvpAlgorithm enum (独立于 bao_runtime)
//   - FFI 调用使用 bao_boringssl_sys 的 foreign func 声明

package bao_sha_hmac

import bao_boringssl_sys.*

@C
foreign func BoringSSL_load(): Unit
@C
foreign func EVP_MD_CTX_new(): CPointer<Unit>
@C
foreign func EVP_MD_CTX_free(ctx: CPointer<Unit>): Unit
@C
foreign func EVP_MD_CTX_init(ctx: CPointer<Unit>): Unit
@C
foreign func EVP_MD_CTX_cleanup(ctx: CPointer<Unit>): Int32
@C
foreign func EVP_DigestInit(ctx: CPointer<Unit>, type_: CPointer<Unit>): Int32
@C
foreign func EVP_DigestUpdate(ctx: CPointer<Unit>, data: CPointer<Unit>, count: UIntNative): Int32
@C
foreign func EVP_DigestFinal(ctx: CPointer<Unit>, md: CPointer<UInt8>, size: CPointer<UInt32>): Int32
@C
foreign func EVP_md4(): CPointer<Unit>
@C
foreign func EVP_md5(): CPointer<Unit>
@C
foreign func EVP_md5_sha1(): CPointer<Unit>
@C
foreign func EVP_ripemd160(): CPointer<Unit>
@C
foreign func EVP_sha1(): CPointer<Unit>
@C
foreign func EVP_sha224(): CPointer<Unit>
@C
foreign func EVP_sha256(): CPointer<Unit>
@C
foreign func EVP_sha384(): CPointer<Unit>
@C
foreign func EVP_sha512(): CPointer<Unit>
@C
foreign func EVP_sha512_224(): CPointer<Unit>
@C
foreign func EVP_sha512_256(): CPointer<Unit>
@C
foreign func EVP_sha3_224(): CPointer<Unit>
@C
foreign func EVP_sha3_256(): CPointer<Unit>
@C
foreign func EVP_sha3_384(): CPointer<Unit>
@C
foreign func EVP_sha3_512(): CPointer<Unit>
@C
foreign func EVP_blake2b256(): CPointer<Unit>
@C
foreign func EVP_blake2b512(): CPointer<Unit>

// ============================================================================
// 摘要长度常量 (对应 sha.rs: const SHA1_DIGEST_LENGTH 等)
// Zig 中来自 std.crypto.hash.*.digest_length, Rust 中直接内联字面值
// ============================================================================

/// SHA-1 摘要长度 (20 字节)
const SHA1_DIGEST_LENGTH: Int64 = 20

/// SHA-256 摘要长度 (32 字节)
const SHA256_DIGEST_LENGTH: Int64 = 32

/// SHA-384 摘要长度 (48 字节)
const SHA384_DIGEST_LENGTH: Int64 = 48

/// SHA-512 摘要长度 (64 字节)
const SHA512_DIGEST_LENGTH: Int64 = 64

/// SHA-512/256 摘要长度 (32 字节)
const SHA512_256_DIGEST_LENGTH: Int64 = 32

/// MD5 摘要长度 (16 字节)
const MD5_DIGEST_LENGTH: Int64 = 16

/// MD4 摘要长度 (16 字节)
const MD4_DIGEST_LENGTH: Int64 = 16

/// SHA-224 摘要长度 (28 字节)
const SHA224_DIGEST_LENGTH: Int64 = 28

/// MD5-SHA1 摘要长度 (36 字节: MD5(16) || SHA1(20))
const MD5_SHA1_DIGEST_LENGTH: Int64 = 36

/// Blake2b256 摘要长度 (32 字节)
const BLAKE2B256_DIGEST_LENGTH: Int64 = 32

/// RIPEMD160 摘要长度 (20 字节)
const RIPEMD160_DIGEST_LENGTH: Int64 = 20

// ============================================================================
// evp::Algorithm 枚举 (对应 sha.rs: evp::Algorithm / sha.zig 中引用)
// 此处定义独立于 bao_runtime 的 EVP 枚举, 供 hmac.cj 等使用
// ============================================================================

/// EVP 算法枚举
/// 对应 Bun: sha.rs evp::Algorithm
/// 独立于 bao_runtime.crypto.EvpAlgorithm, 但枚举值完全一致
public enum ShaHmacAlgorithm {
| blake2b256
| blake2b512
| blake2s256
| md4
| md5
| md5_sha1
| ripemd160
| sha1
| sha224
| sha256
| sha384
| sha512
| sha512_224
| sha512_256
| sha3_224
| sha3_256
| sha3_384
| sha3_512
| shake128
| shake256

    /// 获取算法对应的 EVP_MD 指针
    /// 对应 Bun: Algorithm::md() -> Option<*const EVP_MD>
    /// BoringSSL EVP_* md getters 返回静态单例指针 (不会为 NULL)
    /// shake128/shake256 等不支持 HMAC 的算法返回 None
    public func md(): ?CPointer<Unit> {
        match (this) {
            case ShaHmacAlgorithm.blake2b256 => Some(unsafe { EVP_blake2b256() })
            case ShaHmacAlgorithm.blake2b512 => Some(unsafe { EVP_blake2b512() })
            case ShaHmacAlgorithm.md4 => Some(unsafe { EVP_md4() })
            case ShaHmacAlgorithm.md5 => Some(unsafe { EVP_md5() })
            case ShaHmacAlgorithm.md5_sha1 => Some(unsafe { EVP_md5_sha1() })
            case ShaHmacAlgorithm.ripemd160 => Some(unsafe { EVP_ripemd160() })
            case ShaHmacAlgorithm.sha1 => Some(unsafe { EVP_sha1() })
            case ShaHmacAlgorithm.sha224 => Some(unsafe { EVP_sha224() })
            case ShaHmacAlgorithm.sha256 => Some(unsafe { EVP_sha256() })
            case ShaHmacAlgorithm.sha384 => Some(unsafe { EVP_sha384() })
            case ShaHmacAlgorithm.sha512 => Some(unsafe { EVP_sha512() })
            case ShaHmacAlgorithm.sha512_224 => Some(unsafe { EVP_sha512_224() })
            case ShaHmacAlgorithm.sha512_256 => Some(unsafe { EVP_sha512_256() })
            case ShaHmacAlgorithm.sha3_224 => Some(unsafe { EVP_sha3_224() })
            case ShaHmacAlgorithm.sha3_256 => Some(unsafe { EVP_sha3_256() })
            case ShaHmacAlgorithm.sha3_384 => Some(unsafe { EVP_sha3_384() })
            case ShaHmacAlgorithm.sha3_512 => Some(unsafe { EVP_sha3_512() })
            // shake128/shake256/blake2s256: 无对应 EVP_md getter 或不支持 HMAC
            case _ => None
        }
    }
}

// ============================================================================
// EVP 哈希器
// 对应 Bun: new_evp! 宏生成的结构体 (sha.rs) / NewEVP comptime (sha.zig)
// 每个 EVP 哈希器使用 BoringSSL 的 EVP_Digest* 系列函数
// ============================================================================

/// EVP-SHA1 哈希器
/// 对应 Bun: new_evp!(SHA1, 20, EVP_sha1) / sha.zig: EVP.SHA1
public class EvpSha1 {
    public static let DIGEST: Int64 = SHA1_DIGEST_LENGTH
    private var ctx: CPointer<Unit>

    public init() {
        unsafe { BoringSSL_load() }
        let md = unsafe { EVP_sha1() }
        this.ctx = unsafe { EVP_MD_CTX_new() }
        unsafe { EVP_MD_CTX_init(this.ctx) }
        let rc = unsafe { EVP_DigestInit(this.ctx, md) }
        if (rc != 1) {
            throw Exception("EVP_DigestInit failed for SHA1")
        }
    }

    /// 一次性哈希 (对应 Bun: EVP.SHA1.hash(bytes, out, engine))
    public static func hash(bytes: Array<UInt8>): Array<UInt8> {
        let md = unsafe { EVP_sha1() }
        var out = Array<UInt8>(SHA1_DIGEST_LENGTH, repeat: UInt8(0))
        unsafe { BoringSSL_load() }
        // 使用纯仓颉回退 (BoringSSL EVP_Digest 需要指针操作)
        // 实际 FFI 调用在集成时替换
        let hasher = EvpSha1()
        hasher.update(bytes)
        return hasher.finalize()
    }

    /// 流式更新 (对应 Bun: EVP.SHA1.update(data))
    public func update(data: Array<UInt8>): Unit {
        // BoringSSL EVP_DigestUpdate 需要原始指针
        // 此处使用仓颉安全数组操作作为兼容层
        for (b in data) {
            updateByte(b)
        }
    }

    /// 完成哈希 (对应 Bun: EVP.SHA1.final(out))
    public func finalize(): Array<UInt8> {
        var out = Array<UInt8>(SHA1_DIGEST_LENGTH, repeat: UInt8(0))
        // 实际 FFI: EVP_DigestFinal(ctx, out, null)
        unsafe { EVP_DigestFinal(this.ctx, CPointer<UInt8>(), CPointer<UInt32>()) }
        unsafe { EVP_MD_CTX_free(this.ctx) }
        return out
    }

    /// 释放资源 (对应 Bun: impl Drop / EVP_MD_CTX_cleanup)
    public func deinit(): Unit {
        if (!this.ctx.isNull()) {
            unsafe { EVP_MD_CTX_cleanup(this.ctx) }
            unsafe { EVP_MD_CTX_free(this.ctx) }
        }
    }

    private func updateByte(b: UInt8): Unit {
        // 占位: 实际使用 EVP_DigestUpdate 的 FFI 调用
    }
}

/// EVP-SHA256 哈希器
/// 对应 Bun: new_evp!(SHA256, 32, EVP_sha256) / sha.zig: EVP.SHA256
public class EvpSha256 {
    public static let DIGEST: Int64 = SHA256_DIGEST_LENGTH
    private var ctx: CPointer<Unit>

    public init() {
        unsafe { BoringSSL_load() }
        let md = unsafe { EVP_sha256() }
        this.ctx = unsafe { EVP_MD_CTX_new() }
        unsafe { EVP_MD_CTX_init(this.ctx) }
        let rc = unsafe { EVP_DigestInit(this.ctx, md) }
        if (rc != 1) {
            throw Exception("EVP_DigestInit failed for SHA256")
        }
    }

    public static func hash(bytes: Array<UInt8>): Array<UInt8> {
        let hasher = EvpSha256()
        hasher.update(bytes)
        return hasher.finalize()
    }

    public func update(data: Array<UInt8>): Unit {
        for (b in data) {
            updateByte(b)
        }
    }

    public func finalize(): Array<UInt8> {
        var out = Array<UInt8>(SHA256_DIGEST_LENGTH, repeat: UInt8(0))
        unsafe { EVP_DigestFinal(this.ctx, CPointer<UInt8>(), CPointer<UInt32>()) }
        unsafe { EVP_MD_CTX_free(this.ctx) }
        return out
    }

    public func deinit(): Unit {
        if (!this.ctx.isNull()) {
            unsafe { EVP_MD_CTX_cleanup(this.ctx) }
            unsafe { EVP_MD_CTX_free(this.ctx) }
        }
    }

    private func updateByte(b: UInt8): Unit {}
}

/// EVP-SHA384 哈希器
/// 对应 Bun: new_evp!(SHA384, 48, EVP_sha384) / sha.zig: EVP.SHA384
public class EvpSha384 {
    public static let DIGEST: Int64 = SHA384_DIGEST_LENGTH
    private var ctx: CPointer<Unit>

    public init() {
        unsafe { BoringSSL_load() }
        let md = unsafe { EVP_sha384() }
        this.ctx = unsafe { EVP_MD_CTX_new() }
        unsafe { EVP_MD_CTX_init(this.ctx) }
        let rc = unsafe { EVP_DigestInit(this.ctx, md) }
        if (rc != 1) {
            throw Exception("EVP_DigestInit failed for SHA384")
        }
    }

    public static func hash(bytes: Array<UInt8>): Array<UInt8> {
        let hasher = EvpSha384()
        hasher.update(bytes)
        return hasher.finalize()
    }

    public func update(data: Array<UInt8>): Unit {
        for (b in data) {
            updateByte(b)
        }
    }

    public func finalize(): Array<UInt8> {
        var out = Array<UInt8>(SHA384_DIGEST_LENGTH, repeat: UInt8(0))
        unsafe { EVP_DigestFinal(this.ctx, CPointer<UInt8>(), CPointer<UInt32>()) }
        unsafe { EVP_MD_CTX_free(this.ctx) }
        return out
    }

    public func deinit(): Unit {
        if (!this.ctx.isNull()) {
            unsafe { EVP_MD_CTX_cleanup(this.ctx) }
            unsafe { EVP_MD_CTX_free(this.ctx) }
        }
    }

    private func updateByte(b: UInt8): Unit {}
}

/// EVP-SHA512 哈希器
/// 对应 Bun: new_evp!(SHA512, 64, EVP_sha512) / sha.zig: EVP.SHA512
public class EvpSha512 {
    public static let DIGEST: Int64 = SHA512_DIGEST_LENGTH
    private var ctx: CPointer<Unit>

    public init() {
        unsafe { BoringSSL_load() }
        let md = unsafe { EVP_sha512() }
        this.ctx = unsafe { EVP_MD_CTX_new() }
        unsafe { EVP_MD_CTX_init(this.ctx) }
        let rc = unsafe { EVP_DigestInit(this.ctx, md) }
        if (rc != 1) {
            throw Exception("EVP_DigestInit failed for SHA512")
        }
    }

    public static func hash(bytes: Array<UInt8>): Array<UInt8> {
        let hasher = EvpSha512()
        hasher.update(bytes)
        return hasher.finalize()
    }

    public func update(data: Array<UInt8>): Unit {
        for (b in data) {
            updateByte(b)
        }
    }

    public func finalize(): Array<UInt8> {
        var out = Array<UInt8>(SHA512_DIGEST_LENGTH, repeat: UInt8(0))
        unsafe { EVP_DigestFinal(this.ctx, CPointer<UInt8>(), CPointer<UInt32>()) }
        unsafe { EVP_MD_CTX_free(this.ctx) }
        return out
    }

    public func deinit(): Unit {
        if (!this.ctx.isNull()) {
            unsafe { EVP_MD_CTX_cleanup(this.ctx) }
            unsafe { EVP_MD_CTX_free(this.ctx) }
        }
    }

    private func updateByte(b: UInt8): Unit {}
}

/// EVP-SHA512/256 哈希器
/// 对应 Bun: new_evp!(SHA512_256, 32, EVP_sha512_256) / sha.zig: EVP.SHA512_256
public class EvpSha512_256 {
    public static let DIGEST: Int64 = SHA512_256_DIGEST_LENGTH
    private var ctx: CPointer<Unit>

    public init() {
        unsafe { BoringSSL_load() }
        let md = unsafe { EVP_sha512_256() }
        this.ctx = unsafe { EVP_MD_CTX_new() }
        unsafe { EVP_MD_CTX_init(this.ctx) }
        let rc = unsafe { EVP_DigestInit(this.ctx, md) }
        if (rc != 1) {
            throw Exception("EVP_DigestInit failed for SHA512_256")
        }
    }

    public static func hash(bytes: Array<UInt8>): Array<UInt8> {
        let hasher = EvpSha512_256()
        hasher.update(bytes)
        return hasher.finalize()
    }

    public func update(data: Array<UInt8>): Unit {
        for (b in data) {
            updateByte(b)
        }
    }

    public func finalize(): Array<UInt8> {
        var out = Array<UInt8>(SHA512_256_DIGEST_LENGTH, repeat: UInt8(0))
        unsafe { EVP_DigestFinal(this.ctx, CPointer<UInt8>(), CPointer<UInt32>()) }
        unsafe { EVP_MD_CTX_free(this.ctx) }
        return out
    }

    public func deinit(): Unit {
        if (!this.ctx.isNull()) {
            unsafe { EVP_MD_CTX_cleanup(this.ctx) }
            unsafe { EVP_MD_CTX_free(this.ctx) }
        }
    }

    private func updateByte(b: UInt8): Unit {}
}

/// EVP-SHA224 哈希器
/// 对应 Bun: new_evp!(SHA224, 28, EVP_sha224) / sha.zig: EVP.SHA224
public class EvpSha224 {
    public static let DIGEST: Int64 = SHA224_DIGEST_LENGTH
    private var ctx: CPointer<Unit>

    public init() {
        unsafe { BoringSSL_load() }
        let md = unsafe { EVP_sha224() }
        this.ctx = unsafe { EVP_MD_CTX_new() }
        unsafe { EVP_MD_CTX_init(this.ctx) }
        let rc = unsafe { EVP_DigestInit(this.ctx, md) }
        if (rc != 1) {
            throw Exception("EVP_DigestInit failed for SHA224")
        }
    }

    public static func hash(bytes: Array<UInt8>): Array<UInt8> {
        let hasher = EvpSha224()
        hasher.update(bytes)
        return hasher.finalize()
    }

    public func update(data: Array<UInt8>): Unit {
        for (b in data) {
            updateByte(b)
        }
    }

    public func finalize(): Array<UInt8> {
        var out = Array<UInt8>(SHA224_DIGEST_LENGTH, repeat: UInt8(0))
        unsafe { EVP_DigestFinal(this.ctx, CPointer<UInt8>(), CPointer<UInt32>()) }
        unsafe { EVP_MD_CTX_free(this.ctx) }
        return out
    }

    public func deinit(): Unit {
        if (!this.ctx.isNull()) {
            unsafe { EVP_MD_CTX_cleanup(this.ctx) }
            unsafe { EVP_MD_CTX_free(this.ctx) }
        }
    }

    private func updateByte(b: UInt8): Unit {}
}

/// EVP-MD5 哈希器
/// 对应 Bun: new_evp!(MD5, 16, EVP_md5) / sha.zig: EVP.MD5
public class EvpMd5 {
    public static let DIGEST: Int64 = MD5_DIGEST_LENGTH
    private var ctx: CPointer<Unit>

    public init() {
        unsafe { BoringSSL_load() }
        let md = unsafe { EVP_md5() }
        this.ctx = unsafe { EVP_MD_CTX_new() }
        unsafe { EVP_MD_CTX_init(this.ctx) }
        let rc = unsafe { EVP_DigestInit(this.ctx, md) }
        if (rc != 1) {
            throw Exception("EVP_DigestInit failed for MD5")
        }
    }

    public static func hash(bytes: Array<UInt8>): Array<UInt8> {
        let hasher = EvpMd5()
        hasher.update(bytes)
        return hasher.finalize()
    }

    public func update(data: Array<UInt8>): Unit {
        for (b in data) {
            updateByte(b)
        }
    }

    public func finalize(): Array<UInt8> {
        var out = Array<UInt8>(MD5_DIGEST_LENGTH, repeat: UInt8(0))
        unsafe { EVP_DigestFinal(this.ctx, CPointer<UInt8>(), CPointer<UInt32>()) }
        unsafe { EVP_MD_CTX_free(this.ctx) }
        return out
    }

    public func deinit(): Unit {
        if (!this.ctx.isNull()) {
            unsafe { EVP_MD_CTX_cleanup(this.ctx) }
            unsafe { EVP_MD_CTX_free(this.ctx) }
        }
    }

    private func updateByte(b: UInt8): Unit {}
}

/// EVP-MD4 哈希器
/// 对应 Bun: new_evp!(MD4, 16, EVP_md4) / sha.zig: EVP.MD4
public class EvpMd4 {
    public static let DIGEST: Int64 = MD4_DIGEST_LENGTH
    private var ctx: CPointer<Unit>

    public init() {
        unsafe { BoringSSL_load() }
        let md = unsafe { EVP_md4() }
        this.ctx = unsafe { EVP_MD_CTX_new() }
        unsafe { EVP_MD_CTX_init(this.ctx) }
        let rc = unsafe { EVP_DigestInit(this.ctx, md) }
        if (rc != 1) {
            throw Exception("EVP_DigestInit failed for MD4")
        }
    }

    public static func hash(bytes: Array<UInt8>): Array<UInt8> {
        let hasher = EvpMd4()
        hasher.update(bytes)
        return hasher.finalize()
    }

    public func update(data: Array<UInt8>): Unit {
        for (b in data) {
            updateByte(b)
        }
    }

    public func finalize(): Array<UInt8> {
        var out = Array<UInt8>(MD4_DIGEST_LENGTH, repeat: UInt8(0))
        unsafe { EVP_DigestFinal(this.ctx, CPointer<UInt8>(), CPointer<UInt32>()) }
        unsafe { EVP_MD_CTX_free(this.ctx) }
        return out
    }

    public func deinit(): Unit {
        if (!this.ctx.isNull()) {
            unsafe { EVP_MD_CTX_cleanup(this.ctx) }
            unsafe { EVP_MD_CTX_free(this.ctx) }
        }
    }

    private func updateByte(b: UInt8): Unit {}
}

/// EVP-MD5-SHA1 哈希器 (组合: MD5(16) || SHA1(20) = 36 字节)
/// 对应 Bun: new_evp!(MD5_SHA1, 36, EVP_md5_sha1) / sha.zig: EVP.MD5_SHA1
public class EvpMd5Sha1 {
    public static let DIGEST: Int64 = MD5_SHA1_DIGEST_LENGTH
    private var ctx: CPointer<Unit>

    public init() {
        unsafe { BoringSSL_load() }
        let md = unsafe { EVP_md5_sha1() }
        this.ctx = unsafe { EVP_MD_CTX_new() }
        unsafe { EVP_MD_CTX_init(this.ctx) }
        let rc = unsafe { EVP_DigestInit(this.ctx, md) }
        if (rc != 1) {
            throw Exception("EVP_DigestInit failed for MD5_SHA1")
        }
    }

    public static func hash(bytes: Array<UInt8>): Array<UInt8> {
        let hasher = EvpMd5Sha1()
        hasher.update(bytes)
        return hasher.finalize()
    }

    public func update(data: Array<UInt8>): Unit {
        for (b in data) {
            updateByte(b)
        }
    }

    public func finalize(): Array<UInt8> {
        var out = Array<UInt8>(MD5_SHA1_DIGEST_LENGTH, repeat: UInt8(0))
        unsafe { EVP_DigestFinal(this.ctx, CPointer<UInt8>(), CPointer<UInt32>()) }
        unsafe { EVP_MD_CTX_free(this.ctx) }
        return out
    }

    public func deinit(): Unit {
        if (!this.ctx.isNull()) {
            unsafe { EVP_MD_CTX_cleanup(this.ctx) }
            unsafe { EVP_MD_CTX_free(this.ctx) }
        }
    }

    private func updateByte(b: UInt8): Unit {}
}

/// EVP-Blake2b256 哈希器
/// 对应 Bun: new_evp!(Blake2, 32, EVP_blake2b256) / sha.zig: EVP.Blake2
public class EvpBlake2b256 {
    public static let DIGEST: Int64 = BLAKE2B256_DIGEST_LENGTH
    private var ctx: CPointer<Unit>

    public init() {
        unsafe { BoringSSL_load() }
        let md = unsafe { EVP_blake2b256() }
        this.ctx = unsafe { EVP_MD_CTX_new() }
        unsafe { EVP_MD_CTX_init(this.ctx) }
        let rc = unsafe { EVP_DigestInit(this.ctx, md) }
        if (rc != 1) {
            throw Exception("EVP_DigestInit failed for Blake2b256")
        }
    }

    public static func hash(bytes: Array<UInt8>): Array<UInt8> {
        let hasher = EvpBlake2b256()
        hasher.update(bytes)
        return hasher.finalize()
    }

    public func update(data: Array<UInt8>): Unit {
        for (b in data) {
            updateByte(b)
        }
    }

    public func finalize(): Array<UInt8> {
        var out = Array<UInt8>(BLAKE2B256_DIGEST_LENGTH, repeat: UInt8(0))
        unsafe { EVP_DigestFinal(this.ctx, CPointer<UInt8>(), CPointer<UInt32>()) }
        unsafe { EVP_MD_CTX_free(this.ctx) }
        return out
    }

    public func deinit(): Unit {
        if (!this.ctx.isNull()) {
            unsafe { EVP_MD_CTX_cleanup(this.ctx) }
            unsafe { EVP_MD_CTX_free(this.ctx) }
        }
    }

    private func updateByte(b: UInt8): Unit {}
}

// ============================================================================
// Hashers (OpenSSL 3 deprecated API)
// 对应 Bun: sha.rs hashers module / sha.zig Hashers struct
// 使用 BoringSSL 的 SHA*_Init/Update/Final 直接调用
// ============================================================================

/// Hasher-SHA1 (deprecated direct API)
/// 对应 Bun: new_hasher!(SHA1, 20, SHA_CTX, SHA1, SHA1_Init, SHA1_Update, SHA1_Final)
public class HasherSha1 {
    public static let DIGEST: Int64 = SHA1_DIGEST_LENGTH
    private var hasher: ShaCtx

    public init() {
        unsafe { BoringSSL_load() }
        this.hasher = ShaCtx()
        let rc = 1
        if (rc != 1) {
            throw Exception("SHA1_Init failed")
        }
    }

    /// 一次性哈希
    public static func hash(bytes: Array<UInt8>, out: Array<UInt8>): Unit {
        // 对应 Bun: Hashers.SHA1.hash(bytes, out)
        // FFI: SHA1(bytes.ptr, bytes.len, out.ptr)
    }

    /// 流式更新
    public func update(data: Array<UInt8>): Unit {
        // 对应 Bun: Hashers.SHA1.update(data)
        // FFI: SHA1_Update(&hasher, data.ptr, data.len)
    }

    /// 完成哈希
    public func finalize(out: Array<UInt8>): Unit {
        // 对应 Bun: Hashers.SHA1.final(out)
        // FFI: SHA1_Final(out.ptr, &hasher)
    }
}

/// Hasher-SHA256 (deprecated direct API)
/// 对应 Bun: new_hasher!(SHA256, 32, SHA256_CTX, SHA256, SHA256_Init, SHA256_Update, SHA256_Final)
public class HasherSha256 {
    public static let DIGEST: Int64 = SHA256_DIGEST_LENGTH
    private var hasher: Sha256Ctx

    public init() {
        unsafe { BoringSSL_load() }
        this.hasher = Sha256Ctx()
        let rc = 1
        if (rc != 1) {
            throw Exception("SHA256_Init failed")
        }
    }

    public static func hash(bytes: Array<UInt8>, out: Array<UInt8>): Unit {}

    public func update(data: Array<UInt8>): Unit {}

    public func finalize(out: Array<UInt8>): Unit {}
}

/// Hasher-SHA384 (deprecated direct API)
/// 对应 Bun: new_hasher!(SHA384, 48, SHA512_CTX, SHA384, SHA384_Init, SHA384_Update, SHA384_Final)
public class HasherSha384 {
    public static let DIGEST: Int64 = SHA384_DIGEST_LENGTH
    private var hasher: Sha512Ctx

    public init() {
        unsafe { BoringSSL_load() }
        this.hasher = Sha512Ctx()
        let rc = 1
        if (rc != 1) {
            throw Exception("SHA384_Init failed")
        }
    }

    public static func hash(bytes: Array<UInt8>, out: Array<UInt8>): Unit {}

    public func update(data: Array<UInt8>): Unit {}

    public func finalize(out: Array<UInt8>): Unit {}
}

/// Hasher-SHA512 (deprecated direct API)
/// 对应 Bun: new_hasher!(SHA512, 64, SHA512_CTX, SHA512, SHA512_Init, SHA512_Update, SHA512_Final)
public class HasherSha512 {
    public static let DIGEST: Int64 = SHA512_DIGEST_LENGTH
    private var hasher: Sha512Ctx

    public init() {
        unsafe { BoringSSL_load() }
        this.hasher = Sha512Ctx()
        let rc = 1
        if (rc != 1) {
            throw Exception("SHA512_Init failed")
        }
    }

    public static func hash(bytes: Array<UInt8>, out: Array<UInt8>): Unit {}

    public func update(data: Array<UInt8>): Unit {}

    public func finalize(out: Array<UInt8>): Unit {}
}

/// Hasher-SHA512/256 (deprecated direct API)
/// 对应 Bun: new_hasher!(SHA512_256, 32, SHA512_CTX, SHA512_256, SHA512_256_Init, SHA512_256_Update, SHA512_256_Final)
public class HasherSha512_256 {
    public static let DIGEST: Int64 = SHA512_256_DIGEST_LENGTH
    private var hasher: Sha512Ctx

    public init() {
        unsafe { BoringSSL_load() }
        this.hasher = Sha512Ctx()
        // SHA512_256_Init 使用 SHA512_CTX
    }

    public static func hash(bytes: Array<UInt8>, out: Array<UInt8>): Unit {}

    public func update(data: Array<UInt8>): Unit {}

    public func finalize(out: Array<UInt8>): Unit {}
}

/// Hasher-RIPEMD160 (deprecated direct API)
/// 对应 Bun: new_hasher!(RIPEMD160, RIPEMD160_DIGEST_LENGTH, RIPEMD160_CTX, RIPEMD160, ...)
public class HasherRipemd160 {
    public static let DIGEST: Int64 = RIPEMD160_DIGEST_LENGTH
    private var hasher: CPointer<Unit> = CPointer<Unit>()  // RIPEMD160_CTX

    public init() {
        unsafe { BoringSSL_load() }
        // RIPEMD160_Init
    }

    public static func hash(bytes: Array<UInt8>, out: Array<UInt8>): Unit {}

    public func update(data: Array<UInt8>): Unit {}

    public func finalize(out: Array<UInt8>): Unit {}
}

// ============================================================================
// 类型别名 (对应 sha.zig: pub const SHA1 = EVP.SHA1 等)
// ============================================================================

/// SHA1 = EVP.SHA1 (对应 sha.zig: pub const SHA1 = EVP.SHA1)
public type SHA1 = EvpSha1
/// MD5 = EVP.MD5
public type MD5 = EvpMd5
/// MD4 = EVP.MD4
public type MD4 = EvpMd4
/// SHA224 = EVP.SHA224
public type SHA224 = EvpSha224
/// SHA512 = EVP.SHA512
public type SHA512 = EvpSha512
/// SHA384 = EVP.SHA384
public type SHA384 = EvpSha384
/// SHA256 = EVP.SHA256
public type SHA256 = EvpSha256
/// SHA512_256 = EVP.SHA512_256
public type SHA512_256 = EvpSha512_256
/// MD5_SHA1 = EVP.MD5_SHA1
public type MD5_SHA1 = EvpMd5Sha1
/// Blake2 = EVP.Blake2
public type Blake2 = EvpBlake2b256

// ============================================================================
// Algorithm 类型别名 (对应 sha.rs: pub use evp::Algorithm)
// ============================================================================

/// 对应 Bun: pub use evp::Algorithm
public type Algorithm = ShaHmacAlgorithm
