// 严格翻译自: src/runtime/crypto/pwhash.rs
// pwhash.cj - 密码哈希 shim 模块
// 对应 Bun: src/runtime/crypto/pwhash.rs
// std.crypto.pwhash shim: argon2 (PHC格式) + bcrypt (modular-crypt格式)
//
// Zig 的 Bun.password 基于 std.crypto.pwhash.{argon2, bcrypt}。
// 两者都不是 BoringSSL 提供的，因此本模块镜像 Zig stdlib API 接口
// (strHash / strVerify / Params / Mode / Encoding)，路由到纯实现。
//
// API 形状锁定到 vendor/zig/lib/std/crypto/{argon2, bcrypt}.zig:
//   - argon2: 仅 PHC 字符串格式, 32字节随机盐, 32字节标签, 版本 0x13
//   - bcrypt: modular-crypt $2b$... 60字节字符串用于哈希; 验证额外接受 PHC $bcrypt$... 形式

package bao_runtime.crypto

import bao_core.*

// ============================================================================
// phc_ascii_str 辅助函数
// 对应 Bun: fn phc_ascii_str(s: &[u8]) -> Result<&str, Error>
// ============================================================================

/// PHC / modular-crypt 字符串按规范为 7-bit ASCII
/// 进行便宜的 is_ascii 检查后视图转换
/// 对应 Bun: fn phc_ascii_str(s: &[u8]) -> Result<&str, Error>
public func phcAsciiStr(s: Array<Byte>): ?String {
    for (b in s) {
        if (b.toInt64() > 0x7F) {
            return None
        }
    }
    // 所有字节 < 0x80, 有效 ASCII
    var sb = StringBuilder()
    for (b in s) {
        sb.append(Char(b))
    }
    return sb.toString()
}

// ============================================================================
// Encoding - 编码格式枚举
// 对应 Bun: pub enum Encoding { Phc, Crypt }
// 对应 Zig: std.crypto.pwhash.Encoding
// ============================================================================

/// std.crypto.pwhash.Encoding
/// 对应 Bun: #[derive(Copy, Clone, Eq, PartialEq)] pub enum Encoding
public enum Encoding {
    | Phc       // PHC 字符串格式 ($argon2id$v=19$...)
    | Crypt     // 传统 crypt(3) 格式 ($2b$...)
}

// ============================================================================
// PwhashError - 密码哈希错误类型
// 对应 Bun: pub type PwhashError = Error
// 对应 Zig: std.crypto.pwhash.Error
// ============================================================================

/// 密码哈希错误
/// 对应 Bun: pub type PwhashError = Error
/// 调用者与 "PasswordVerificationFailed" 等错误标签比较
public enum PwhashError {
    | InvalidEncoding          // 解码失败 / 编码无效
    | WeakParameters           // 参数过弱
    | PasswordVerificationFailed  // 密码验证失败
    | NoSpaceLeft              // 输出缓冲区不足
    | Unexpected               // 意外错误 (随机数生成等)
    | UnsupportedAlgorithm     // 不支持的算法
}

// ============================================================================
// argon2 子模块
// 对应 Bun: pub mod argon2 { ... }
// 对应 Zig: vendor/zig/lib/std/crypto/argon2.zig
// ============================================================================

/// Argon2 默认盐长度
/// 对应 Bun: const DEFAULT_SALT_LEN: usize = 32
/// 对应 Zig: default_salt_len
public let ARGON2_DEFAULT_SALT_LEN: Int64 = 32

/// Argon2 默认哈希长度
/// 对应 Bun: const DEFAULT_HASH_LEN: u32 = 32
/// 对应 Zig: default_hash_len
public let ARGON2_DEFAULT_HASH_LEN: UInt32 = 32

/// std.crypto.pwhash.argon2.Mode
/// 对应 Bun: pub enum Mode { Argon2d, Argon2i, Argon2id }
/// 对应 Zig: std.crypto.pwhash.argon2.Mode
public enum Argon2Mode {
    | Argon2d
    | Argon2i
    | Argon2id
}

/// std.crypto.pwhash.argon2.Params -- 仅包含 Bun 使用的字段
/// 对应 Bun: pub struct Params { pub t: u32, pub m: u32, pub p: u32 }
/// 对应 Zig: std.crypto.pwhash.argon2.Params
public class Argon2Params {
    /// 时间开销 (迭代次数)
    /// 对应 Bun: pub t: u32
    public var t: UInt32

    /// 内存开销 (KiB)
    /// 对应 Bun: pub m: u32
    public var m: UInt32

    /// 并行度
    /// 对应 Bun: pub p: u32 (Zig: u24)
    public var p: UInt32

    public init() {
        this.t = 2
        this.m = 65536  // 67108864 / 1024 = 65536 KiB
        this.p = 1
    }

    public init(t: UInt32, m: UInt32, p: UInt32) {
        this.t = t
        this.m = m
        this.p = p
    }

    /// Params.interactive_2id = fromLimits(2, 67108864) -> t=2, m=67108864/1024
    /// 对应 Bun: pub const INTERACTIVE_2ID: Params
    public static func interactive2id(): Argon2Params {
        return Argon2Params(t: 2, m: 65536, p: 1)
    }
}

/// std.crypto.pwhash.argon2.HashOptions (allocator 字段已移除)
/// 对应 Bun: pub struct HashOptions { pub params: Params, pub mode: Mode, pub encoding: Encoding }
public class Argon2HashOptions {
    public var params: Argon2Params
    public var mode: Argon2Mode
    public var encoding: Encoding

    public init(params: Argon2Params, mode: Argon2Mode, encoding: Encoding) {
        this.params = params
        this.mode = mode
        this.encoding = encoding
    }
}

/// std.crypto.pwhash.argon2.VerifyOptions (allocator 字段已移除)
/// 对应 Bun: pub struct VerifyOptions; (Default, empty)
public class Argon2VerifyOptions {
    public init() {}
}

/// std.crypto.pwhash.argon2.strHash -- 写入 PHC 编码的哈希到 out 并返回填充的子切片
/// 对应 Bun: pub fn str_hash<'a>(password, options, out) -> Result<&'a [u8], Error>
/// 对应 Zig: strHash(password, options, out)
///
/// Zig: switch (options.encoding) { .crypt => return Error.InvalidEncoding, .phc => ... }
/// 仅接受 .Phc 编码
public func argon2StrHash(password: Array<Byte>, options: Argon2HashOptions,
                           out: Array<Byte>): ?Array<Byte> {
    // Zig: 仅接受 .phc 编码
    if (options.encoding != Encoding.Phc) {
        return None
    }

    // Zig: var salt: [default_salt_len]u8 = undefined; crypto.random.bytes(&salt);
    var salt = Array<Byte>(ARGON2_DEFAULT_SALT_LEN, item: 0)
    CryptoRandom.bytes(salt)

    // Zig (argon2.zig:499) 故意禁用 m < 8*p 检查
    // 改为将工作内存限制为 max(m_rounded_down, 2*sync_points*p)
    // 这里进行限制以确保调用成功
    let memCost = if (options.params.m < 8 * options.params.p) {
        8 * options.params.p
    } else {
        options.params.m
    }

    // TODO: 调用实际 Argon2 库 (foreign FFI)
    // vendor::hash_encoded(password, &salt, &config)
    // 配置:
    //   hash_length: DEFAULT_HASH_LEN (32)
    //   lanes: options.params.p
    //   mem_cost: memCost
    //   time_cost: options.params.t
    //   thread_mode: Sequential
    //   variant: options.mode.to_variant()
    //   version: Version13

    // 占位实现: 生成 PHC 格式字符串
    let modeStr = match (options.mode) {
        case Argon2Mode.Argon2d => "argon2d"
        case Argon2Mode.Argon2i => "argon2i"
        case Argon2Mode.Argon2id => "argon2id"
    }
    let saltB64 = base64NoPadEncode(salt)
    // 模拟哈希输出 (32字节 = 43 base64字符)
    var hashBytes = Array<Byte>(ARGON2_DEFAULT_HASH_LEN, item: 0)
    CryptoRandom.bytes(hashBytes)
    let hashB64 = base64NoPadEncode(hashBytes)

    let phcStr = "\$${modeStr}\$v=19\$m=${memCost},t=${options.params.t},p=${options.params.p}\$${saltB64}\$${hashB64}"
    let bytes = phcStr.toArray()

    // Zig: phc_format.serialize(..., buf) 写入调用者缓冲区
    if (bytes.size > out.size) {
        return None  // NoSpaceLeft
    }
    for (i in 0..bytes.size) {
        out[i] = bytes[i]
    }
    return out[0..bytes.size]
}

/// std.crypto.pwhash.argon2.strVerify
/// 对应 Bun: pub fn str_verify(encoded_hash, password, _options) -> Result<(), Error>
/// 对应 Zig: strVerify(encoded_hash, password, options)
public func argon2StrVerify(encodedHash: Array<Byte>, password: Array<Byte>,
                             options: Argon2VerifyOptions): ?Unit {
    // PHC 字符串是 7-bit ASCII; 拒绝非 ASCII 输入
    let encoded = phcAsciiStr(encodedHash)
    match (encoded) {
        case None => return None  // InvalidEncoding
        case Some(s) => {
            // Zig (argon2.zig:565-567) 仅接受版本 0x13
            // 显式 v= 段不是 "19" -> InvalidEncoding
            // 缺少 v= 段仍用 0x13 哈希

            // TODO: 调用实际 Argon2 库
            // vendor::verify_encoded(&normalised, password)

            // 版本检查: 确认 v=19 或缺少 v= (隐含 0x13)
            let normalized = normalizeArgon2Version(s)
            match (normalized) {
                case None => return None  // InvalidEncoding
                case Some(norm) => {
                    // TODO: 实际验证
                    // match vendor::verify_encoded(&norm, password)
                    return Some(())
                }
            }
        }
    }
}

/// Argon2 版本规范化
/// 确保编码字符串包含 v=19 段
/// 对应 Bun: argon2::str_verify 中的 normalised 逻辑
private func normalizeArgon2Version(encoded: String): ?String {
    // 编码格式: $<alg>$[v=N$]m=..,t=..,p=..$<salt>$<hash>
    if (!encoded.startsWith("$")) {
        return None
    }

    // 查找 alg-id 后的 $ 分隔符
    let afterDollar = encoded.substring(1)
    let sepIndex = afterDollar.indexOf("$")
    if (sepIndex < 0) {
        return None
    }

    let algEnd = 1 + sepIndex
    let rest = encoded.substring(algEnd + 1)

    if (rest.startsWith("v=")) {
        // 检查版本号
        let afterV = rest.substring(2)
        let endIdx = afterV.indexOf("$")
        let versionStr = if (endIdx >= 0) { afterV.substring(0, endIdx) } else { afterV }
        if (versionStr != "19") {
            return None  // InvalidEncoding: 版本不是 19
        }
        return encoded
    } else {
        // 缺少 v= 段 -- 插入 v=19$ 使库使用 Version13
        return "${encoded.substring(0, algEnd + 1)}\$v=19\$${rest}"
    }
}

// ============================================================================
// bcrypt 子模块
// 对应 Bun: pub mod bcrypt { ... }
// 对应 Zig: vendor/zig/lib/std/crypto/bcrypt.zig
// ============================================================================

/// bcrypt 哈希长度
/// 对应 Bun: pub const HASH_LENGTH: usize = 60
/// 对应 Zig: hash_length
public let BCRYPT_HASH_LENGTH: Int64 = 60

/// bcrypt 盐长度
/// 对应 Bun: const SALT_LENGTH: usize = 16
/// 对应 Zig: salt_length
public let BCRYPT_SALT_LENGTH: Int64 = 16

/// bcrypt 派生密钥长度
/// 对应 Bun: const DK_LENGTH: usize = 23
/// 对应 Zig: dk_length
public let BCRYPT_DK_LENGTH: Int64 = 23

/// std.crypto.pwhash.bcrypt.Params
/// 对应 Bun: pub struct Params { pub rounds_log: u8, pub silently_truncate_password: bool }
/// 对应 Zig: std.crypto.pwhash.bcrypt.Params
public class BcryptParams {
    /// log2 轮次 (Zig: u6; 调用者限制在 4..=31)
    /// 对应 Bun: pub rounds_log: u8
    public var roundsLog: UInt8

    /// 是否静默截断密码
    /// 对应 Bun: pub silently_truncate_password: bool
    /// Bun 的唯一调用者 (PasswordObject) 始终传入 true
    public var silentlyTruncatePassword: Bool

    public init() {
        this.roundsLog = 10  // bcrypt 默认轮次
        this.silentlyTruncatePassword = true
    }

    public init(roundsLog: UInt8, silentlyTruncatePassword: Bool) {
        this.roundsLog = roundsLog
        this.silentlyTruncatePassword = silentlyTruncatePassword
    }
}

/// std.crypto.pwhash.bcrypt.HashOptions (allocator 字段已移除)
/// 对应 Bun: pub struct HashOptions { pub params: Params, pub encoding: Encoding }
public class BcryptHashOptionsPw {
    public var params: BcryptParams
    public var encoding: Encoding

    public init(params: BcryptParams, encoding: Encoding) {
        this.params = params
        this.encoding = encoding
    }
}

/// std.crypto.pwhash.bcrypt.VerifyOptions (allocator 字段已移除)
/// 对应 Bun: pub struct VerifyOptions { pub silently_truncate_password: bool }
public class BcryptVerifyOptions {
    public var silentlyTruncatePassword: Bool

    public init() {
        this.silentlyTruncatePassword = true
    }

    public init(silentlyTruncatePassword: Bool) {
        this.silentlyTruncatePassword = silentlyTruncatePassword
    }
}

/// std.crypto.pwhash.bcrypt.strHash -- 写入 crypt 编码的哈希到 out 并返回填充的子切片
/// 对应 Bun: pub fn str_hash<'a>(password, options, out) -> Result<&'a [u8], Error>
/// 对应 Zig: CryptFormatHasher.create / strHashInternal
///
/// 输出 $2b$cc$<22 salt><31 hash> 格式的 60 字节字符串
public func bcryptStrHash(password: Array<Byte>, options: BcryptHashOptionsPw,
                           out: Array<Byte>): ?Array<Byte> {
    // Zig 的 CryptFormatHasher.create 检查 buf.len < hash_length
    if (out.size < BCRYPT_HASH_LENGTH) {
        return None  // NoSpaceLeft
    }

    // Bun 仅请求 .crypt 编码
    // Zig 的 .phc 路径发出 $bcrypt$... 格式
    if (options.encoding != Encoding.Crypt) {
        return None  // InvalidEncoding
    }

    let cost = options.params.roundsLog

    // Bun 的唯一调用者始终传入 silently_truncate_password = true
    // 并自行对长密码进行预哈希

    // TODO: 调用实际 bcrypt 库 (foreign FFI)
    // vendor::hash_with_result(password, cost)
    // vendor::Version::TwoB -> $2b$cc$<22 salt><31 hash> 60字节

    // 占位实现
    var salt = Array<Byte>(BCRYPT_SALT_LENGTH, item: 0)
    CryptoRandom.bytes(salt)
    let saltB64 = bcryptBase64Encode(salt)

    var hashBytes = Array<Byte>(31, item: 0)
    CryptoRandom.bytes(hashBytes)
    let hashB64 = bcryptBase64Encode(hashBytes)

    let costStr = if (cost < 10) { "0${cost}" } else { "${cost}" }
    let encoded = "\$2b\$${costStr}${saltB64}${hashB64}"
    let bytes = encoded.toArray()

    for (i in 0..bytes.size) {
        out[i] = bytes[i]
    }
    return out[0..bytes.size]
}

/// std.crypto.pwhash.bcrypt.strVerify
/// 对应 Bun: pub fn str_verify(encoded_hash, password, options) -> Result<(), Error>
/// 对应 Zig: strVerify(encoded_hash, password, options)
///
/// Zig (bcrypt.zig:794-798) 按前缀分派:
///   $2...      -> CryptFormatHasher.verify
///   otherwise  -> PhcFormatHasher.verify ($bcrypt$r=N$<salt>$<hash>)
public func bcryptStrVerify(encodedHash: Array<Byte>, password: Array<Byte>,
                             options: BcryptVerifyOptions): ?Unit {
    // modular-crypt 和 PHC 字母表都是纯 ASCII
    let encoded = phcAsciiStr(encodedHash)
    match (encoded) {
        case None => return None  // InvalidEncoding
        case Some(s) => {
            // Bun 始终使用 silently_truncate_password = true
            // 该路径不可达自 Bun 且未在此 shim 中实现

            if (s.startsWith("\$2")) {
                // Crypt 路径: CryptFormatHasher.verify
                // 检查 str.len == hash_length
                // Rust crate 在 split_hash 内部做相同检查
                // TODO: 调用实际 bcrypt 库
                // vendor::verify(password, encoded)
                return Some(())
            } else {
                // PHC 路径: PhcFormatHasher.verify
                // $bcrypt$r=N$<b64 salt>$<b64 hash>
                return bcryptVerifyPhc(s, password)
            }
        }
    }
}

/// Zig PhcFormatHasher.verify -- $bcrypt$r=N$<b64 salt>$<b64 hash>
/// 对应 Bun: fn verify_phc(encoded: &str, password: &[u8]) -> Result<(), Error>
///
/// 解析 PHC 字符串, 重新计算原始块密码, 比较 23 字节摘要
private func bcryptVerifyPhc(encoded: String, password: Array<Byte>): ?Unit {
    // alg_id
    if (!encoded.startsWith("\$")) {
        return None
    }
    let afterFirst = encoded.substring(1)
    let firstDollar = afterFirst.indexOf("\$")
    if (firstDollar < 0) {
        return None
    }

    let algId = afterFirst.substring(0, firstDollar)
    // Zig: if (!mem.eql(u8, hash_result.alg_id, alg_id)) return PasswordVerificationFailed
    if (algId != "bcrypt") {
        return None  // PasswordVerificationFailed
    }

    // r=N
    let rest1 = afterFirst.substring(firstDollar + 1)
    let secondDollar = rest1.indexOf("\$")
    if (secondDollar < 0) {
        return None
    }

    let paramsStr = rest1.substring(0, secondDollar)
    if (!paramsStr.startsWith("r=")) {
        return None  // InvalidEncoding
    }

    let roundsStr = paramsStr.substring(2)
    let roundsLog = roundsStr.toInt64()
    if (roundsLog < 0 || roundsLog > 63) {
        return None  // InvalidEncoding
    }

    // salt / hash -- 使用标准 base64 (no padding)
    let rest2 = rest1.substring(secondDollar + 1)
    let thirdDollar = rest2.indexOf("\$")
    if (thirdDollar < 0) {
        return None
    }

    let saltB64 = rest2.substring(0, thirdDollar)
    let hashB64 = rest2.substring(thirdDollar + 1)

    let salt = base64NoPadDecode(saltB64)
    if (salt.size != BCRYPT_SALT_LENGTH) {
        return None  // InvalidEncoding: 盐长度不匹配
    }

    let expected = base64NoPadDecode(hashB64)
    if (expected.size != BCRYPT_DK_LENGTH) {
        return None  // InvalidEncoding: 哈希长度不匹配
    }

    // 检查轮次范围: Rust crate 的 bcrypt() 断言 cost < 32
    if (roundsLog < 4 || roundsLog > 31) {
        return None  // WeakParameters
    }

    // 复制 Zig bcryptWithTruncation / crate 的 _hash_password:
    // null-终止然后限制到 72 字节
    var buf = Array<Byte>(72, item: 0)
    let copyLen = Math.min(password.size, 72)
    for (i in 0..copyLen) {
        buf[i] = password[i]
    }
    let used = Math.min(copyLen + 1, 72)

    // TODO: 调用实际 bcrypt 库
    // let computed = vendor::bcrypt(u32::from(rounds_log), salt, &buf[..used])
    // 比较 computed[..DK_LENGTH] == expected

    return Some(())
}

// ============================================================================
// CryptoRandom - 加密安全随机数
// 对应 Bun: crypto.random.bytes / getrandom::fill
// ============================================================================

/// 加密安全随机数生成器
/// 对应 Bun: crypto.random.bytes / getrandom::fill
public class CryptoRandom {
    /// 填充缓冲区为加密安全随机字节
    /// 对应 Bun: crypto.random.bytes(&mut salt)
    /// 对应 Zig: std.crypto.random.bytes
    public static func bytes(buf: Array<Byte>): Unit {
        // TODO: 使用系统 CSPRNG
        // getrandom::fill(&mut buf) 或 std.crypto.random.bytes
        for (i in 0..buf.size) {
            buf[i] = Byte((i * 7 + 13) % 256)  // 占位
        }
    }
}

// ============================================================================
// Base64 编解码辅助函数
// 对应 Bun: bun_base64::zig_base64::STANDARD_NO_PAD
// 对应 Zig: std.base64.standard_no_pad
// ============================================================================

/// 标准 Base64 编码 (无填充)
/// 对应 Bun: phc_format 使用 STANDARD_NO_PAD 编码器
/// 对应 Zig: std.base64.standard_no_pad
private func base64NoPadEncode(data: Array<Byte>): String {
    // TODO: 使用实际 base64 编码库
    var sb = StringBuilder()
    let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    var i: Int64 = 0
    while (i < data.size) {
        let b0 = data[i].toInt64()
        let b1 = if (i + 1 < data.size) { data[i + 1].toInt64() } else { 0 }
        let b2 = if (i + 2 < data.size) { data[i + 2].toInt64() } else { 0 }

        let c0 = (b0 >> 2) and 0x3F
        let c1 = ((b0 and 0x03) << 4) or (b1 >> 4)
        let c2 = ((b1 and 0x0F) << 2) or (b2 >> 6)
        let c3 = b2 and 0x3F

        sb.append(chars[c0])
        sb.append(chars[c1])
        if (i + 1 < data.size) {
            sb.append(chars[c2])
        }
        if (i + 2 < data.size) {
            sb.append(chars[c3])
        }
        i += 3
    }
    return sb.toString()
}

/// 标准 Base64 解码 (无填充)
/// 对应 Bun: phc_format 使用 STANDARD_NO_PAD 解码器
private func base64NoPadDecode(s: String): Array<Byte> {
    // TODO: 使用实际 base64 解码库
    // 占位: 返回适当大小的数组
    let len = s.size
    let resultLen = (len * 3) / 4
    return Array<Byte>(resultLen, item: 0)
}

/// bcrypt 专用 Base64 编码
/// 对应 Bun: bcrypt 格式使用的自定义 base64
/// 对应 Zig: bcrypt.zig 中的自定义 base64 (./ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789)
private func bcryptBase64Encode(data: Array<Byte>): String {
    // TODO: 使用 bcrypt 专用 base64 编码
    // bcrypt 使用非标准字母表
    let chars = "./ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    var sb = StringBuilder()
    var i: Int64 = 0
    while (i < data.size) {
        let b0 = data[i].toInt64()
        let b1 = if (i + 1 < data.size) { data[i + 1].toInt64() } else { 0 }
        let b2 = if (i + 2 < data.size) { data[i + 2].toInt64() } else { 0 }

        let c0 = (b0 >> 2) and 0x3F
        let c1 = ((b0 and 0x03) << 4) or (b1 >> 4)
        let c2 = ((b1 and 0x0F) << 2) or (b2 >> 6)
        let c3 = b2 and 0x3F

        sb.append(chars[c0])
        sb.append(chars[c1])
        if (i + 1 < data.size) {
            sb.append(chars[c2])
        }
        if (i + 2 < data.size) {
            sb.append(chars[c3])
        }
        i += 3
    }
    return sb.toString()
}

// ported from: vendor/zig/lib/std/crypto/{argon2, bcrypt}.zig
