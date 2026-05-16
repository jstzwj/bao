// EVP.cj - 高级加密接口 (Envelope)
// 对应 Bun: src/runtime/crypto/EVP.zig
// 严格1:1翻译自 Bun EVP.zig + EVP.rs

package bao_runtime.crypto

import bao_core.*
import std.collection.*

// ============================================================================
// EVP Algorithm 算法枚举（提取到顶层）
// 对应 Bun: EVP.zig - pub const Algorithm = enum
// ============================================================================

/// 加密算法枚举
public enum EvpAlgorithm {
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
| sha512_224
| sha512_256
| sha3_224
| sha3_256
| sha3_384
| sha3_512
| shake128
| shake256

    /// 获取算法对应的 EVP_MD
    public func md(): ?EvpMd {
        match (this) {
            case EvpAlgorithm.blake2b256 => BoringSSL.evpBlake2b256()
            case EvpAlgorithm.blake2b512 => BoringSSL.evpBlake2b512()
            case EvpAlgorithm.md4 => BoringSSL.evpMd4()
            case EvpAlgorithm.md5 => BoringSSL.evpMd5()
            case EvpAlgorithm.ripemd160 => BoringSSL.evpRipemd160()
            case EvpAlgorithm.sha1 => BoringSSL.evpSha1()
            case EvpAlgorithm.sha224 => BoringSSL.evpSha224()
            case EvpAlgorithm.sha256 => BoringSSL.evpSha256()
            case EvpAlgorithm.sha384 => BoringSSL.evpSha384()
            case EvpAlgorithm.sha512 => BoringSSL.evpSha512()
            case EvpAlgorithm.sha512_224 => BoringSSL.evpSha512224()
            case EvpAlgorithm.sha512_256 => BoringSSL.evpSha512256()
            case EvpAlgorithm.sha3_224 => BoringSSL.evpSha3_224()
            case EvpAlgorithm.sha3_256 => BoringSSL.evpSha3_256()
            case EvpAlgorithm.sha3_384 => BoringSSL.evpSha3_384()
            case EvpAlgorithm.sha3_512 => BoringSSL.evpSha3_512()
            case _ => None
        }
    }

    /// 获取算法名称
    public func name(): String {
        match (this) {
            case EvpAlgorithm.blake2b256 => "blake2b256"
            case EvpAlgorithm.blake2b512 => "blake2b512"
            case EvpAlgorithm.blake2s256 => "blake2s256"
            case EvpAlgorithm.md4 => "md4"
            case EvpAlgorithm.md5 => "md5"
            case EvpAlgorithm.ripemd160 => "ripemd160"
            case EvpAlgorithm.sha1 => "sha1"
            case EvpAlgorithm.sha224 => "sha224"
            case EvpAlgorithm.sha256 => "sha256"
            case EvpAlgorithm.sha384 => "sha384"
            case EvpAlgorithm.sha512 => "sha512"
            case EvpAlgorithm.sha512_224 => "sha512-224"
            case EvpAlgorithm.sha512_256 => "sha512-256"
            case EvpAlgorithm.sha3_224 => "sha3-224"
            case EvpAlgorithm.sha3_256 => "sha3-256"
            case EvpAlgorithm.sha3_384 => "sha3-384"
            case EvpAlgorithm.sha3_512 => "sha3-512"
            case EvpAlgorithm.shake128 => "shake128"
            case EvpAlgorithm.shake256 => "shake256"
        }
    }

    /// 算法名称映射表
    public static func fromName(s: String): ?EvpAlgorithm {
        let nameLower = name.toLowerCase()
        match (nameLower) {
            case "blake2b256" => EvpAlgorithm.blake2b256
            case "blake2b512" => EvpAlgorithm.blake2b512
            case "blake2s256" => EvpAlgorithm.blake2s256
            case "ripemd160" => EvpAlgorithm.ripemd160
            case "rmd160" => EvpAlgorithm.ripemd160
            case "md4" => EvpAlgorithm.md4
            case "md5" => EvpAlgorithm.md5
            case "sha1" => EvpAlgorithm.sha1
            case "sha128" => EvpAlgorithm.sha1
            case "sha224" => EvpAlgorithm.sha224
            case "sha256" => EvpAlgorithm.sha256
            case "sha384" => EvpAlgorithm.sha384
            case "sha512" => EvpAlgorithm.sha512
            case "sha-1" => EvpAlgorithm.sha1
            case "sha-224" => EvpAlgorithm.sha224
            case "sha-256" => EvpAlgorithm.sha256
            case "sha-384" => EvpAlgorithm.sha384
            case "sha-512" => EvpAlgorithm.sha512
            case "sha-512/224" => EvpAlgorithm.sha512_224
            case "sha-512_224" => EvpAlgorithm.sha512_224
            case "sha-512224" => EvpAlgorithm.sha512_224
            case "sha512-224" => EvpAlgorithm.sha512_224
            case "sha-512/256" => EvpAlgorithm.sha512_256
            case "sha-512_256" => EvpAlgorithm.sha512_256
            case "sha-512256" => EvpAlgorithm.sha512_256
            case "sha512-256" => EvpAlgorithm.sha512_256
            case "sha3-224" => EvpAlgorithm.sha3_224
            case "sha3-256" => EvpAlgorithm.sha3_256
            case "sha3-384" => EvpAlgorithm.sha3_384
            case "sha3-512" => EvpAlgorithm.sha3_512
            case "shake128" => EvpAlgorithm.shake128
            case "shake256" => EvpAlgorithm.shake256
            case _ => None
        }
    }

    /// 所有算法名称列表
    public static func allNames(): ArrayList<String> {
        return ArrayList<String>([
            "blake2b256", "blake2b512", "blake2s256", "ripemd160",
            "md4", "md5", "sha1", "sha224", "sha256", "sha384", "sha512",
            "sha512-224", "sha512-256", "sha3-224", "sha3-256",
            "sha3-384", "sha3-512", "shake128", "shake256"
        ])
    }

    /// 所有算法值列表
    public static func allAlgorithms(): ArrayList<EvpAlgorithm> {
        return ArrayList<EvpAlgorithm>([
            EvpAlgorithm.blake2b256, EvpAlgorithm.blake2b512, EvpAlgorithm.blake2s256,
            EvpAlgorithm.md4, EvpAlgorithm.md5, EvpAlgorithm.ripemd160,
            EvpAlgorithm.sha1, EvpAlgorithm.sha224, EvpAlgorithm.sha256,
            EvpAlgorithm.sha384, EvpAlgorithm.sha512, EvpAlgorithm.sha512_224,
            EvpAlgorithm.sha512_256, EvpAlgorithm.sha3_224, EvpAlgorithm.sha3_256,
            EvpAlgorithm.sha3_384, EvpAlgorithm.sha3_512, EvpAlgorithm.shake128,
            EvpAlgorithm.shake256
        ])
    }
}

// ============================================================================
// EVP - 高级加密接口
// ============================================================================

/// EVP 高级加密接口
public class EVP {
    public var ctx: EvpMdCtx
    public var md: EvpMd
    public var algorithm: EvpAlgorithm

    /// EVP_MAX_MD_SIZE 摘要最大长度
    public static let MAX_MD_SIZE: Int64 = 64

    public init(algorithm: EvpAlgorithm, md: EvpMd, engine: ?Engine) {
        BoringSSL.load()

        this.ctx = EvpMdCtx()
        BoringSSL.evpMdCtxInit(this.ctx)

        BoringSSL.evpDigestInitEx(this.ctx, md, engine)

        this.md = md
        this.algorithm = algorithm
    }

    /// 区分大小写的算法名称查找
    public static func lookup(arr: Array<Byte>): ?EvpAlgorithm {
        let name = String.fromUtf8(arr)
        match (name) {
            case "md4" => return EvpAlgorithm.md4
            case "md5" => return EvpAlgorithm.md5
            case "sha1" => return EvpAlgorithm.sha1
            case "sha-1" => return EvpAlgorithm.sha1
            case "sha128" => return EvpAlgorithm.sha1
            case "sha224" => return EvpAlgorithm.sha224
            case "sha256" => return EvpAlgorithm.sha256
            case "sha384" => return EvpAlgorithm.sha384
            case "sha512" => return EvpAlgorithm.sha512
            case "rmd160" => return EvpAlgorithm.ripemd160
            case "sha-224" => return EvpAlgorithm.sha224
            case "sha-256" => return EvpAlgorithm.sha256
            case "sha-384" => return EvpAlgorithm.sha384
            case "sha-512" => return EvpAlgorithm.sha512
            case "sha3-224" => return EvpAlgorithm.sha3_224
            case "sha3-256" => return EvpAlgorithm.sha3_256
            case "sha3-384" => return EvpAlgorithm.sha3_384
            case "sha3-512" => return EvpAlgorithm.sha3_512
            case "shake128" => return EvpAlgorithm.shake128
            case "shake256" => return EvpAlgorithm.shake256
            case "ripemd160" => return EvpAlgorithm.ripemd160
            case "blake2b256" => return EvpAlgorithm.blake2b256
            case "blake2b512" => return EvpAlgorithm.blake2b512
            case "blake2s256" => return EvpAlgorithm.blake2s256
            case "sha-512224" => return EvpAlgorithm.sha512_224
            case "sha512-224" => return EvpAlgorithm.sha512_224
            case "sha-512256" => return EvpAlgorithm.sha512_256
            case "sha512-256" => return EvpAlgorithm.sha512_256
            case "sha-512/224" => return EvpAlgorithm.sha512_224
            case "sha-512_224" => return EvpAlgorithm.sha512_224
            case "sha-512/256" => return EvpAlgorithm.sha512_256
            case "sha-512_256" => return EvpAlgorithm.sha512_256
            case _ => return None
        }
    }

    private static func lookupOld(arr: Array<Byte>): ?EvpAlgorithm {
        return None
    }

    

    /// 不区分大小写的算法名称查找
    public static func lookupIgnoreCase(arr: Array<Byte>): ?EvpAlgorithm {
        var lowerBytes = Array<Byte>(bytes.size, repeat: 0)
        for (i in 0..bytes.size) {
            let b = bytes[i]
            if (b >= 0x41 && b <= 0x5A) {
                lowerBytes[i] = b + 0x20
            } else {
                lowerBytes[i] = b
            }
        }
        return lookup(lowerBytes)
    }

    /// 算法名称 "one of" 描述字符串
    public static let ALGORITHM_ONE_OF: String =
        "'blake2b256', 'blake2b512', 'blake2s256', 'md4', 'md5', " +
        "'ripemd160', 'sha1', 'sha224', 'sha256', 'sha384', 'sha512', 'sha512-224', 'sha512-256', " +
        "'sha3-224', 'sha3-256', 'sha3-384', 'sha3-512', 'shake128' or 'shake256'"

    /// 重置 EVP 状态
    public func reset(engine: ?Engine): Unit {
        BoringSSL.errClearError()
        BoringSSL.evpDigestInitEx(this.ctx, this.md, engine)
    }

    /// 一次性哈希计算
    public func hash(engine: ?Engine, input: Array<Byte>, output: Array<Byte>): ?UInt32 {
        BoringSSL.errClearError()

        var outSize: UInt32 = Math.min(output.size.toInt64(), this.size().toInt64()).toUInt32()

        if (BoringSSL.evpDigest(input, input.size.toInt64(), output,
                Array<UInt32>([outSize]), this.md, engine) != 1) {
            return None
        }

        return outSize
    }

    /// 最终哈希并获取结果
    public func final(engine: ?Engine, output: Array<Byte>): Array<Byte> {
        BoringSSL.errClearError()

        var outSize: UInt32 = Math.min(output.size.toInt64(), this.size().toInt64()).toUInt32()
        var outSizeArr = Array<UInt32>([outSize])

        if (BoringSSL.evpDigestFinalEx(this.ctx, output, outSizeArr) != 1) {
            return Array<Byte>()
        }

        this.reset(engine)

        let finalSize = outSizeArr[0].toInt64()
        if (finalSize > 0 && finalSize <= output.size) {
            return output[0..finalSize]
        }
        return Array<Byte>()
    }

    /// 更新哈希数据
    public func update(arr: Array<Byte>): Unit {
        BoringSSL.errClearError()
        BoringSSL.evpDigestUpdate(this.ctx, input, input.size.toInt64())
    }

    /// 获取摘要大小
    public func size(): UInt16 {
        return UInt16(BoringSSL.evpMdCtxSize(this.ctx))
    }

    /// 复制 EVP
    public func copy(engine: ?Engine): ?EVP {
        BoringSSL.errClearError()

        var newEvp = EVP(this.algorithm, this.md, engine)

        if (BoringSSL.evpMdCtxCopyEx(newEvp.ctx, this.ctx) == 0) {
            return None
        }

        return newEvp
    }

    /// 根据名称和引擎获取 EVP
    public static func byNameAndEngine(engine: ?Engine, name: String): ?EVP {
        let algorithm = EvpAlgorithm.fromName(name)
        match (algorithm) {
            case Some(alg) =>
                let md = alg.md()
                match (md) {
                    case Some(mdVal) =>
                        return EVP(alg, mdVal, engine)
                    case None =>
                        let mdByName = BoringSSL.evpGetDigestByName(alg.name())
                        match (mdByName) {
                            case Some(mdVal2) => return EVP(alg, mdVal2, engine)
                            case None => ()
                        }
                }
            case None => ()
        }
        return None
    }

    /// 根据名称获取 EVP
    public static func byName(s: String, globalThis: JsObject): ?EVP {
        let engine = RareData.getBoringEngine(globalThis)
        return byNameAndEngine(engine, name)
    }

    /// 释放 EVP
    public func deinit(): Unit {
        BoringSSL.evpMdCtxCleanup(this.ctx)
    }
}

// ============================================================================
// Digest - 摘要缓冲区类型（使用 public type 替代 typealias）
// ============================================================================

/// 摘要缓冲区类型别名
public type Digest = Array<Byte>
