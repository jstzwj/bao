// EVP.cj - 高级加密接口 (Envelope)
// 对应 Bun: src/runtime/crypto/EVP.zig
// 严格1:1翻译自 Bun EVP.zig + EVP.rs

package bao_runtime.crypto

import bao_core.*

// ============================================================================
// EVP - 高级加密接口
// 对应 Bun: EVP.zig - const EVP = @This()
// ============================================================================

/// EVP 高级加密接口
/// 对应 Bun: const EVP = @This()
///
/// ctx: BoringSSL.EVP_MD_CTX = undefined,
/// md: *const BoringSSL.EVP_MD = undefined,
/// algorithm: Algorithm,
public class EVP {
    public var ctx: EvpMdCtx
    public var md: EvpMd
    public var algorithm: Algorithm

    /// EVP_MAX_MD_SIZE 摘要最大长度
    /// 对应 Bun: pub const Digest = [BoringSSL.EVP_MAX_MD_SIZE]u8
    public static let MAX_MD_SIZE: Int64 = 64

    public init(algorithm: Algorithm, md: EvpMd, engine: ?Engine) {
        // bun.BoringSSL.load();
        BoringSSL.load()

        // var ctx: BoringSSL.EVP_MD_CTX = undefined;
        // BoringSSL.EVP_MD_CTX_init(&ctx);
        this.ctx = EvpMdCtx()
        BoringSSL.evpMdCtxInit(this.ctx)

        // _ = BoringSSL.EVP_DigestInit_ex(&ctx, md, engine);
        BoringSSL.evpDigestInitEx(this.ctx, md, engine)

        this.md = md
        this.algorithm = algorithm
    }

    // ========================================================================
    // Algorithm 算法枚举
    // 对应 Bun: EVP.zig - pub const Algorithm = enum
    // ========================================================================

    /// 加密算法枚举
    /// 对应 Bun: pub const Algorithm = enum { ... }
    public enum Algorithm {
        | blake2b256
        | blake2b512
        | blake2s256
        | md4
        | md5
        | ripemd160
        | sha1
        | sha224
        | sha256
        | sha384
        | sha512
        | sha512_224    // 对应 Bun: @"sha512-224"
        | sha512_256    // 对应 Bun: @"sha512-256"
        | sha3_224      // 对应 Bun: @"sha3-224"
        | sha3_256      // 对应 Bun: @"sha3-256"
        | sha3_384      // 对应 Bun: @"sha3-384"
        | sha3_512      // 对应 Bun: @"sha3-512"
        | shake128
        | shake256

        /// 获取算法对应的 EVP_MD
        /// 对应 Bun: pub fn md(this: Algorithm) ?*const BoringSSL.EVP_MD
        public func md(): ?EvpMd {
            match (this) {
                case Algorithm.blake2b256 => BoringSSL.evpBlake2b256()
                case Algorithm.blake2b512 => BoringSSL.evpBlake2b512()
                case Algorithm.md4 => BoringSSL.evpMd4()
                case Algorithm.md5 => BoringSSL.evpMd5()
                case Algorithm.ripemd160 => BoringSSL.evpRipemd160()
                case Algorithm.sha1 => BoringSSL.evpSha1()
                case Algorithm.sha224 => BoringSSL.evpSha224()
                case Algorithm.sha256 => BoringSSL.evpSha256()
                case Algorithm.sha384 => BoringSSL.evpSha384()
                case Algorithm.sha512 => BoringSSL.evpSha512()
                case Algorithm.sha512_224 => BoringSSL.evpSha512224()
                case Algorithm.sha512_256 => BoringSSL.evpSha512256()
                case Algorithm.sha3_224 => BoringSSL.evpSha3_224()
                case Algorithm.sha3_256 => BoringSSL.evpSha3_256()
                case Algorithm.sha3_384 => BoringSSL.evpSha3_384()
                case Algorithm.sha3_512 => BoringSSL.evpSha3_512()
                case _ => None  // blake2s256, shake128, shake256
            }
        }

        /// 获取算法名称
        /// 对应 Bun: Algorithm.names 中的 tagName
        public func name(): String {
            match (this) {
                case Algorithm.blake2b256 => "blake2b256"
                case Algorithm.blake2b512 => "blake2b512"
                case Algorithm.blake2s256 => "blake2s256"
                case Algorithm.md4 => "md4"
                case Algorithm.md5 => "md5"
                case Algorithm.ripemd160 => "ripemd160"
                case Algorithm.sha1 => "sha1"
                case Algorithm.sha224 => "sha224"
                case Algorithm.sha256 => "sha256"
                case Algorithm.sha384 => "sha384"
                case Algorithm.sha512 => "sha512"
                case Algorithm.sha512_224 => "sha512-224"
                case Algorithm.sha512_256 => "sha512-256"
                case Algorithm.sha3_224 => "sha3-224"
                case Algorithm.sha3_256 => "sha3-256"
                case Algorithm.sha3_384 => "sha3-384"
                case Algorithm.sha3_512 => "sha3-512"
                case Algorithm.shake128 => "shake128"
                case Algorithm.shake256 => "shake256"
            }
        }

        /// 算法名称映射表
        /// 对应 Bun: pub const map = bun.ComptimeStringMap(Algorithm, .{...})
        public static func fromName(name: String): ?Algorithm {
            let nameLower = name.toLowerCase()
            // 对应 Bun 中的 Algorithm.map 条目
            match (nameLower) {
                case "blake2b256" => Algorithm.blake2b256
                case "blake2b512" => Algorithm.blake2b512
                case "blake2s256" => Algorithm.blake2s256
                case "ripemd160" => Algorithm.ripemd160
                case "rmd160" => Algorithm.ripemd160
                case "md4" => Algorithm.md4
                case "md5" => Algorithm.md5
                case "sha1" => Algorithm.sha1
                case "sha128" => Algorithm.sha1
                case "sha224" => Algorithm.sha224
                case "sha256" => Algorithm.sha256
                case "sha384" => Algorithm.sha384
                case "sha512" => Algorithm.sha512
                case "sha-1" => Algorithm.sha1
                case "sha-224" => Algorithm.sha224
                case "sha-256" => Algorithm.sha256
                case "sha-384" => Algorithm.sha384
                case "sha-512" => Algorithm.sha512
                case "sha-512/224" => Algorithm.sha512_224
                case "sha-512_224" => Algorithm.sha512_224
                case "sha-512224" => Algorithm.sha512_224
                case "sha512-224" => Algorithm.sha512_224
                case "sha-512/256" => Algorithm.sha512_256
                case "sha-512_256" => Algorithm.sha512_256
                case "sha-512256" => Algorithm.sha512_256
                case "sha512-256" => Algorithm.sha512_256
                case "sha3-224" => Algorithm.sha3_224
                case "sha3-256" => Algorithm.sha3_256
                case "sha3-384" => Algorithm.sha3_384
                case "sha3-512" => Algorithm.sha3_512
                case "shake128" => Algorithm.shake128
                case "shake256" => Algorithm.shake256
                case _ => None
            }
        }

        /// 所有算法名称列表
        /// 对应 Bun: pub const names: std.EnumArray(Algorithm, bun.String)
        /// 对应 Bun Rust: fn names() -> &'static [BunString]
        public static func allNames(): ArrayList<String> {
            return ArrayList<String>([
                "blake2b256", "blake2b512", "blake2s256", "ripemd160",
                "md4", "md5", "sha1", "sha224", "sha256", "sha384", "sha512",
                "sha512-224", "sha512-256", "sha3-224", "sha3-256",
                "sha3-384", "sha3-512", "shake128", "shake256"
            ])
        }

        /// 所有算法值列表 (声明顺序)
        /// 对应 Bun Rust: const ALL: [Algorithm; 19]
        public static func allAlgorithms(): ArrayList<Algorithm> {
            return ArrayList<Algorithm>([
                Algorithm.blake2b256, Algorithm.blake2b512, Algorithm.blake2s256,
                Algorithm.md4, Algorithm.md5, Algorithm.ripemd160,
                Algorithm.sha1, Algorithm.sha224, Algorithm.sha256,
                Algorithm.sha384, Algorithm.sha512, Algorithm.sha512_224,
                Algorithm.sha512_256, Algorithm.sha3_224, Algorithm.sha3_256,
                Algorithm.sha3_384, Algorithm.sha3_512, Algorithm.shake128,
                Algorithm.shake256
            ])
        }
    }

    // ========================================================================
    // lookup - 高效名称查找
    // 对应 Bun Rust: pub fn lookup(bytes: &[u8]) -> Option<Algorithm>
    // 对应 Bun Zig: Algorithm.map.get(name)
    //
    // 长度分派的精确匹配 (区分大小写)
    // 替代 phf::Map; 32 个键分布在长度 3..=11
    // ========================================================================

    /// 区分大小写的算法名称查找
    /// 对应 Bun Rust: pub fn lookup(bytes: &[u8]) -> Option<Algorithm>
    /// 高效的按长度分派匹配
    public static func lookup(bytes: Array<Byte>): ?Algorithm {
        let len = bytes.size
        match (len) {
            case 3 => {
                if (byteEqualsStr(bytes, "md4")) { return Algorithm.md4 }
                if (byteEqualsStr(bytes, "md5")) { return Algorithm.md5 }
                return None
            }
            case 4 => {
                if (byteEqualsStr(bytes, "sha1")) { return Algorithm.sha1 }
                return None
            }
            case 5 => {
                if (byteEqualsStr(bytes, "sha-1")) { return Algorithm.sha1 }
                return None
            }
            case 6 => {
                let first = bytes[0]
                if (first == Byte('s')) {
                    if (byteEqualsStr(bytes, "sha128")) { return Algorithm.sha1 }
                    if (byteEqualsStr(bytes, "sha224")) { return Algorithm.sha224 }
                    if (byteEqualsStr(bytes, "sha256")) { return Algorithm.sha256 }
                    if (byteEqualsStr(bytes, "sha384")) { return Algorithm.sha384 }
                    if (byteEqualsStr(bytes, "sha512")) { return Algorithm.sha512 }
                }
                if (first == Byte('r')) {
                    if (byteEqualsStr(bytes, "rmd160")) { return Algorithm.ripemd160 }
                }
                return None
            }
            case 7 => {
                if (byteEqualsStr(bytes, "sha-224")) { return Algorithm.sha224 }
                if (byteEqualsStr(bytes, "sha-256")) { return Algorithm.sha256 }
                if (byteEqualsStr(bytes, "sha-384")) { return Algorithm.sha384 }
                if (byteEqualsStr(bytes, "sha-512")) { return Algorithm.sha512 }
                return None
            }
            case 8 => {
                if (byteEqualsStr(bytes, "sha3-224")) { return Algorithm.sha3_224 }
                if (byteEqualsStr(bytes, "sha3-256")) { return Algorithm.sha3_256 }
                if (byteEqualsStr(bytes, "sha3-384")) { return Algorithm.sha3_384 }
                if (byteEqualsStr(bytes, "sha3-512")) { return Algorithm.sha3_512 }
                if (byteEqualsStr(bytes, "shake128")) { return Algorithm.shake128 }
                if (byteEqualsStr(bytes, "shake256")) { return Algorithm.shake256 }
                return None
            }
            case 9 => {
                if (byteEqualsStr(bytes, "ripemd160")) { return Algorithm.ripemd160 }
                return None
            }
            case 10 => {
                let first = bytes[0]
                if (first == Byte('b')) {
                    if (byteEqualsStr(bytes, "blake2b256")) { return Algorithm.blake2b256 }
                    if (byteEqualsStr(bytes, "blake2b512")) { return Algorithm.blake2b512 }
                    if (byteEqualsStr(bytes, "blake2s256")) { return Algorithm.blake2s256 }
                }
                if (first == Byte('s')) {
                    if (byteEqualsStr(bytes, "sha-512224")) { return Algorithm.sha512_224 }
                    if (byteEqualsStr(bytes, "sha512-224")) { return Algorithm.sha512_224 }
                    if (byteEqualsStr(bytes, "sha-512256")) { return Algorithm.sha512_256 }
                    if (byteEqualsStr(bytes, "sha512-256")) { return Algorithm.sha512_256 }
                }
                return None
            }
            case 11 => {
                if (byteEqualsStr(bytes, "sha-512/224")) { return Algorithm.sha512_224 }
                if (byteEqualsStr(bytes, "sha-512_224")) { return Algorithm.sha512_224 }
                if (byteEqualsStr(bytes, "sha-512/256")) { return Algorithm.sha512_256 }
                if (byteEqualsStr(bytes, "sha-512_256")) { return Algorithm.sha512_256 }
                return None
            }
            case _ => None
        }
    }

    /// 不区分大小写的算法名称查找
    /// 对应 Bun Rust: pub fn lookup_ignore_case(bytes: &[u8]) -> Option<Algorithm>
    /// 对应 Bun Zig: Algorithm.map.getWithEql(name, strings.eqlCaseInsensitiveASCIIIgnoreLength)
    public static func lookupIgnoreCase(bytes: Array<Byte>): ?Algorithm {
        // 将字节转为小写后查找
        var lowerBytes = Array<Byte>(bytes.size, item: 0)
        for (i in 0..bytes.size) {
            let b = bytes[i]
            if (b >= 0x41 && b <= 0x5A) {  // A-Z
                lowerBytes[i] = b + 0x20
            } else {
                lowerBytes[i] = b
            }
        }
        return lookup(lowerBytes)
    }

    /// 算法名称 "one of" 描述字符串
    /// 对应 Bun Rust: pub const ALGORITHM_ONE_OF: &str
    /// 用于 JS 端错误消息中列出所有支持的算法名
    public static let ALGORITHM_ONE_OF: String =
        "'blake2b256', 'blake2b512', 'blake2s256', 'md4', 'md5', " +
        "'ripemd160', 'sha1', 'sha224', 'sha256', 'sha384', 'sha512', 'sha512-224', 'sha512-256', " +
        "'sha3-224', 'sha3-256', 'sha3-384', 'sha3-512', 'shake128' or 'shake256'"

    // ========================================================================
    // EVP 方法
    // 对应 Bun: EVP.zig 中的方法
    // ========================================================================

    /// 重置 EVP 状态
    /// 对应 Bun: pub fn reset(this: *EVP, engine: *BoringSSL.ENGINE) void
    public func reset(engine: ?Engine): Unit {
        // BoringSSL.ERR_clear_error();
        BoringSSL.errClearError()
        // _ = BoringSSL.EVP_DigestInit_ex(&this.ctx, this.md, engine);
        BoringSSL.evpDigestInitEx(this.ctx, this.md, engine)
    }

    /// 一次性哈希计算
    /// 对应 Bun: pub fn hash(this: *EVP, engine: *BoringSSL.ENGINE, input: []const u8, output: []u8) ?u32
    public func hash(engine: ?Engine, input: Array<Byte>, output: Array<Byte>): ?UInt32 {
        // BoringSSL.ERR_clear_error();
        BoringSSL.errClearError()

        // var outsize: c_uint = @min(@as(u16, @truncate(output.len)), this.size());
        var outSize: UInt32 = Math.min(output.size.toInt64(), this.size().toInt64()).toUInt32()

        // if (BoringSSL.EVP_Digest(input.ptr, input.len, output.ptr, &outsize, this.md, engine) != 1)
        //     return null;
        if (BoringSSL.evpDigest(input, input.size.toInt64(), output,
                Array<UInt32>([outSize]), this.md, engine) != 1) {
            return None
        }

        return outSize
    }

    /// 最终哈希并获取结果
    /// 对应 Bun: pub fn final(this: *EVP, engine: *BoringSSL.ENGINE, output: []u8) []u8
    public func final(engine: ?Engine, output: Array<Byte>): Array<Byte> {
        // BoringSSL.ERR_clear_error();
        BoringSSL.errClearError()

        // var outsize: u32 = @min(@as(u16, @truncate(output.len)), this.size());
        var outSize: UInt32 = Math.min(output.size.toInt64(), this.size().toInt64()).toUInt32()
        var outSizeArr = Array<UInt32>([outSize])

        // if (BoringSSL.EVP_DigestFinal_ex(&this.ctx, output.ptr, &outsize) != 1)
        //     return "";
        if (BoringSSL.evpDigestFinalEx(this.ctx, output, outSizeArr) != 1) {
            return Array<Byte>()
        }

        // this.reset(engine);
        this.reset(engine)

        // return output[0..outsize];
        let finalSize = outSizeArr[0].toInt64()
        if (finalSize > 0 && finalSize <= output.size) {
            return output[0..finalSize]
        }
        return Array<Byte>()
    }

    /// 更新哈希数据
    /// 对应 Bun: pub fn update(this: *EVP, input: []const u8) void
    public func update(input: Array<Byte>): Unit {
        // BoringSSL.ERR_clear_error();
        BoringSSL.errClearError()
        // _ = BoringSSL.EVP_DigestUpdate(&this.ctx, input.ptr, input.len);
        BoringSSL.evpDigestUpdate(this.ctx, input, input.size.toInt64())
    }

    /// 获取摘要大小
    /// 对应 Bun: pub fn size(this: *const EVP) u16
    public func size(): UInt16 {
        // return @as(u16, @truncate(BoringSSL.EVP_MD_CTX_size(&this.ctx)));
        return UInt16(BoringSSL.evpMdCtxSize(this.ctx))
    }

    /// 复制 EVP
    /// 对应 Bun: pub fn copy(this: *const EVP, engine: *BoringSSL.ENGINE) error{OutOfMemory}!EVP
    public func copy(engine: ?Engine): ?EVP {
        // BoringSSL.ERR_clear_error();
        BoringSSL.errClearError()

        // var new = init(this.algorithm, this.md, engine);
        var newEvp = EVP(this.algorithm, this.md, engine)

        // if (BoringSSL.EVP_MD_CTX_copy_ex(&new.ctx, &this.ctx) == 0)
        //     return error.OutOfMemory;
        if (BoringSSL.evpMdCtxCopyEx(newEvp.ctx, this.ctx) == 0) {
            return None
        }

        return newEvp
    }

    /// 根据名称和引擎获取 EVP
    /// 对应 Bun: pub fn byNameAndEngine(engine: *BoringSSL.ENGINE, name: []const u8) ?EVP
    public static func byNameAndEngine(engine: ?Engine, name: String): ?EVP {
        // if (Algorithm.map.getWithEql(name, strings.eqlCaseInsensitiveASCIIIgnoreLength)) |algorithm|
        let algorithm = Algorithm.fromName(name)
        match (algorithm) {
            case Some(alg) => {
                // if (algorithm.md()) |md|
                let md = alg.md()
                match (md) {
                    case Some(mdVal) => {
                        // return EVP.init(algorithm, md, engine);
                        return EVP(alg, mdVal, engine)
                    }
                    case None => {
                        // if (BoringSSL.EVP_get_digestbyname(@tagName(algorithm))) |md|
                        let mdByName = BoringSSL.evpGetDigestByName(alg.name())
                        match (mdByName) {
                            case Some(mdVal2) => return EVP(alg, mdVal2, engine)
                            case None => ()
                        }
                    }
                }
            }
            case None => ()
        }
        return None
    }

    /// 根据名称获取 EVP
    /// 对应 Bun: pub fn byName(name: ZigString, global: *jsc.JSGlobalObject) ?EVP
    public static func byName(name: String, globalThis: JsObject): ?EVP {
        // return byNameAndEngine(global.bunVM().rareData().boringEngine(), name_str.slice());
        let engine = RareData.getBoringEngine(globalThis)
        return byNameAndEngine(engine, name)
    }

    /// 释放 EVP
    /// 对应 Bun: pub fn deinit(this: *EVP) void
    public func deinit(): Unit {
        // _ = BoringSSL.EVP_MD_CTX_cleanup(&this.ctx);
        BoringSSL.evpMdCtxCleanup(this.ctx)
    }

    /// PBKDF2 子模块引用
    /// 对应 Bun: pub const PBKDF2 = @import("./PBKDF2.zig")
    /// pub const pbkdf2 = PBKDF2.pbkdf2
}

// ============================================================================
// Digest - 摘要缓冲区类型
// 对应 Bun: pub type Digest = [u8; EVP_MAX_MD_SIZE]
// 对应 Bun Zig: pub const Digest = [BoringSSL.EVP_MAX_MD_SIZE]u8
// ============================================================================

/// 摘要缓冲区类型别名
/// 对应 Bun: pub type Digest = [u8; EVP_MAX_MD_SIZE as usize]
/// 大小为 EVP_MAX_MD_SIZE (64) 字节的固定数组
public typealias Digest = Array<Byte>
