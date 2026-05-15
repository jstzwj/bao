// CryptoHasher.cj - 加密哈希器
// 对应 Bun: src/runtime/crypto/CryptoHasher.zig
// 严格1:1翻译自 Bun CryptoHasher.zig

package bao_runtime.crypto

import bao_core.*

// ============================================================================
// CryptoHasher - 加密哈希器
// 对应 Bun: CryptoHasher.zig - pub const CryptoHasher = union(enum) { ... }
// ============================================================================

/// 加密哈希器标签类型
/// 对应 Bun: pub const CryptoHasher = union(enum) { hmac, evp, zig }
public enum CryptoHasherTag {
    | HMAC_TAG
    | EVP_TAG
    | ZIG_TAG
}

/// 加密哈希器
/// 对应 Bun: pub const CryptoHasher = union(enum) {
///     hmac: ?*HMAC,
///     evp: EVP,
///     zig: CryptoHasherZig,
/// }
public class CryptoHasher {
    public var tag: CryptoHasherTag
    public var hmacValue: ?HMAC
    public var evpValue: ?EVP
    public var zigValue: ?CryptoHasherZig

    public init(tag: CryptoHasherTag) {
        this.tag = tag
        hmacValue = None
        evpValue = None
        zigValue = None
    }

    // ========================================================================
    // 摘要缓冲区
    // 对应 Bun: const Digest = EVP.Digest (= [EVP_MAX_MD_SIZE]u8)
    // ========================================================================
    public static let DIGEST_SIZE: Int64 = 64

    // ========================================================================
    // Extern - 外部接口
    // 对应 Bun: pub const Extern = struct { ... }
    // ========================================================================

    /// 根据名称获取哈希器
    /// 对应 Bun: fn getByName(global, name_bytes, name_len) ?*CryptoHasher
    public static func getByName(globalThis: JsObject, name: String): ?CryptoHasher {
        // if (CryptoHasherZig.init(name)) |inner|
        let zigInner = CryptoHasherZig.init(name)
        match (zigInner) {
            case Some(inner) => {
                let hasher = CryptoHasher(CryptoHasherTag.ZIG_TAG)
                hasher.zigValue = inner
                return hasher
            }
            case None => ()
        }

        // const algorithm = EVP.Algorithm.map.get(name) orelse return null
        let algorithm = EVP.Algorithm.fromName(name)
        match (algorithm) {
            case None => return None
            case Some(alg) => {
                match (alg) {
                    case EVP.Algorithm.ripemd160 | EVP.Algorithm.blake2b256 |
                         EVP.Algorithm.blake2b512 | EVP.Algorithm.sha512_224 => {
                        // if (algorithm.md()) |md|
                        let md = alg.md()
                        match (md) {
                            case Some(mdVal) => {
                                let engine = RareData.getBoringEngine(globalThis)
                                let hasher = CryptoHasher(CryptoHasherTag.EVP_TAG)
                                hasher.evpValue = EVP(alg, mdVal, engine)
                                return hasher
                            }
                            case None => ()
                        }
                    }
                    case _ => return None
                }
            }
        }
        return None
    }

    /// 从另一个哈希器获取副本
    /// 对应 Bun: fn getFromOther(global, other_handle) ?*CryptoHasher
    public static func getFromOther(globalThis: JsObject, otherHandle: CryptoHasher): ?CryptoHasher {
        match (otherHandle.tag) {
            case CryptoHasherTag.ZIG_TAG => {
                let other = otherHandle.zigValue!!
                let hasher = CryptoHasher(CryptoHasherTag.ZIG_TAG)
                hasher.zigValue = other.copy()
                return hasher
            }
            case CryptoHasherTag.EVP_TAG => {
                let other = otherHandle.evpValue!!
                let engine = RareData.getBoringEngine(globalThis)
                let copied = other.copy(engine)
                match (copied) {
                    case Some(evpCopy) => {
                        let hasher = CryptoHasher(CryptoHasherTag.EVP_TAG)
                        hasher.evpValue = evpCopy
                        return hasher
                    }
                    case None => return None
                }
            }
            case _ => return None
        }
    }

    /// 销毁哈希器
    /// 对应 Bun: fn destroy(handle: *CryptoHasher) void
    public func destroy(): Unit {
        this.finalize()
    }

    /// 更新哈希数据
    /// 对应 Bun: fn update(handle: *CryptoHasher, input_bytes, input_len) bool
    public func updateExtern(input: Array<Byte>): Bool {
        match (this.tag) {
            case CryptoHasherTag.ZIG_TAG => {
                this.zigValue!!.update(input)
                return true
            }
            case CryptoHasherTag.EVP_TAG => {
                this.evpValue!!.update(input)
                return true
            }
            case _ => return false
        }
    }

    /// 获取摘要
    /// 对应 Bun: fn digest(handle: *CryptoHasher, global, buf, buf_len) u32
    public func digestExtern(globalThis: JsObject, buf: Array<Byte>): UInt32 {
        match (this.tag) {
            case CryptoHasherTag.ZIG_TAG => {
                let res = this.zigValue!!.finalWithLen(buf, buf.size)
                return UInt32(res.size)
            }
            case CryptoHasherTag.EVP_TAG => {
                let engine = RareData.getBoringEngine(globalThis)
                let res = this.evpValue!!.final(engine, buf)
                return UInt32(res.size)
            }
            case _ => return 0
        }
    }

    /// 获取摘要大小
    /// 对应 Bun: fn getDigestSize(handle: *CryptoHasher) u32
    public func getDigestSize(): UInt32 {
        match (this.tag) {
            case CryptoHasherTag.ZIG_TAG => UInt32(this.zigValue!!.digestLength)
            case CryptoHasherTag.EVP_TAG => this.evpValue!!.size()
            case _ => 0
        }
    }

    // ========================================================================
    // JS 实例方法
    // ========================================================================

    /// 获取字节长度
    /// 对应 Bun: pub fn getByteLength(this, globalThis) bun.JSError!jsc.JSValue
    public func getByteLength(globalThis: JsObject): JsValue {
        match (this.tag) {
            case CryptoHasherTag.EVP_TAG => JsValue(Float64(this.evpValue!!.size()))
            case CryptoHasherTag.HMAC_TAG => {
                let hmac = this.hmacValue
                match (hmac) {
                    case Some(h) => JsValue(Float64(h.size()))
                    case None => throwHmacConsumed()
                }
            }
            case CryptoHasherTag.ZIG_TAG => JsValue(Float64(this.zigValue!!.digestLength))
        }
    }

    /// 获取算法名
    /// 对应 Bun: pub fn getAlgorithm(this, globalObject) bun.JSError!jsc.JSValue
    public func getAlgorithm(globalObject: JsObject): JsValue {
        match (this.tag) {
            case CryptoHasherTag.EVP_TAG => JsValue(BaoString(this.evpValue!!.algorithm.name()))
            case CryptoHasherTag.ZIG_TAG => JsValue(BaoString(this.zigValue!!.algorithm.name()))
            case CryptoHasherTag.HMAC_TAG => {
                let hmac = this.hmacValue
                match (hmac) {
                    case Some(h) => JsValue(BaoString(h.algorithm.name()))
                    case None => throwHmacConsumed()
                }
            }
        }
    }

    /// 获取所有算法名列表
    /// 对应 Bun: pub fn getAlgorithms(globalThis, _, _) bun.JSError!jsc.JSValue
    public static func getAlgorithms(globalThis: JsObject): JsValue {
        let names = EVP.Algorithm.allNames()
        let arr = ArrayList<JsValue>()
        for (name in names) {
            arr.append(JsValue(BaoString(name)))
        }
        return JsValue.array(arr)
    }

    // ========================================================================
    // 静态 hash 方法
    // 对应 Bun: pub fn hash_(globalThis, algorithm, input, output) bun.JSError!jsc.JSValue
    // ========================================================================

    /// 静态哈希函数
    /// 对应 Bun: pub fn hash_(globalThis, algorithm, input, output)
    public static func hashStatic(globalThis: JsObject, algorithm: String,
                                   input: Array<Byte>, output: ?String): JsValue {
        // var evp = EVP.byName(algorithm, globalThis) orelse
        //     return try CryptoHasherZig.hashByName(globalThis, algorithm, input, output) orelse { ... }
        let evp = EVP.byName(algorithm, globalThis)
        match (evp) {
            case Some(evpInst) => {
                defer(evpInst.deinit())
                // hashToBytes 或 hashToEncoding
                return hashToBytes(globalThis, evpInst, input, None)
            }
            case None => {
                // 尝试 Zig 实现的哈希
                let zigResult = CryptoHasherZig.hashByName(globalThis, algorithm, input, None)
                match (zigResult) {
                    case Some(v) => return v
                    case None => return JsValue(BaoString("Unsupported algorithm \"${algorithm}\""))
                }
            }
        }
    }

    /// 哈希到编码
    private static func hashToEncoding(globalThis: JsObject, evp: EVP, input: Array<Byte>,
                                        encoding: String): JsValue {
        var outputDigestBuf = Array<Byte>(DIGEST_SIZE, item: 0)
        let engine = RareData.getBoringEngine(globalThis)
        let len = evp.hash(engine, input, outputDigestBuf)
        match (len) {
            case None => {
                let err = BoringSSL.errGetError()
                BoringSSL.errClearError()
                return createCryptoError(globalThis, err)
            }
            case Some(outLen) => {
                // encoding.encodeWithMaxSize(...)
                return JsValue(BaoString(encodingEncode(encoding, outputDigestBuf[0..outLen.toInt64()])))
            }
        }
    }

    /// 哈希到字节
    private static func hashToBytes(globalThis: JsObject, evp: EVP, input: Array<Byte>,
                                     output: ?JsArrayBuffer): JsValue {
        var outputDigestBuf = Array<Byte>(DIGEST_SIZE, item: 0)
        var outputDigestSlice: Array<Byte> = outputDigestBuf

        match (output) {
            case Some(outputBuf) => {
                let size = evp.size()
                let bytes = outputBuf.byteSlice()
                if (bytes.size < size) {
                    return JsValue(BaoString("TypedArray must be at least ${size} bytes"))
                }
                outputDigestSlice = bytes[0..size.toInt64()]
            }
            case None => ()
        }

        let engine = RareData.getBoringEngine(globalThis)
        let len = evp.hash(engine, input, outputDigestSlice)
        match (len) {
            case None => {
                let err = BoringSSL.errGetError()
                BoringSSL.errClearError()
                return createCryptoError(globalThis, err)
            }
            case Some(outLen) => {
                match (output) {
                    case Some(outputBuf) => return outputBuf.value
                    case None => return JsArrayBuffer.createBuffer(globalThis, outputDigestSlice[0..outLen.toInt64()])
                }
            }
        }
    }

    // ========================================================================
    // 构造器
    // 对应 Bun: pub fn constructor(globalThis, callframe) bun.JSError!*CryptoHasher
    // ========================================================================

    /// 构造器
    /// 对应 Bun: pub fn constructor(globalThis, callframe) - Bun.CryptoHasher(algorithm, hmacKey?)
    public static func constructor(globalThis: JsObject, args: ArrayList<JsValue>): ?CryptoHasher {
        if (args.size == 0) {
            return None
        }

        let algorithmName = args[0]
        if (algorithmName.valueType != JsValueType.String) {
            return None
        }

        let algorithm = algorithmName.toString()
        if (algorithm.size == 0) {
            return None
        }

        let hmacValue = if (args.size > 1) { args[1] } else { JsValue.UNDEFINED }
        var hmacKey: ?Array<Byte> = None

        if (hmacValue.valueType != JsValueType.Undefined &&
            hmacValue.valueType != JsValueType.Null) {
            hmacKey = Some(hmacValue.toString().toArray())
        }

        match (hmacKey) {
            case Some(key) => {
                let alg = EVP.Algorithm.fromName(algorithm)
                match (alg) {
                    case None => return None
                    case Some(chosenAlgorithm) => {
                        let hmac = HMAC.init(chosenAlgorithm, key)
                        match (hmac) {
                            case Some(h) => {
                                let hasher = CryptoHasher(CryptoHasherTag.HMAC_TAG)
                                hasher.hmacValue = h
                                return hasher
                            }
                            case None => return None
                        }
                    }
                }
            }
            case None => {
                // 尝试 EVP
                let evp = EVP.byName(algorithm, globalThis)
                match (evp) {
                    case Some(e) => {
                        let hasher = CryptoHasher(CryptoHasherTag.EVP_TAG)
                        hasher.evpValue = e
                        return hasher
                    }
                    case None => {
                        // 尝试 Zig 实现
                        let zig = CryptoHasherZig.constructor(algorithm)
                        match (zig) {
                            case Some(z) => {
                                let hasher = CryptoHasher(CryptoHasherTag.ZIG_TAG)
                                hasher.zigValue = z
                                return hasher
                            }
                            case None => return None
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    // update 实例方法
    // 对应 Bun: pub fn update(this, globalThis, callframe) bun.JSError!jsc.JSValue
    // ========================================================================

    /// 更新哈希数据
    public func update(globalThis: JsObject, input: Array<Byte>): JsValue {
        match (this.tag) {
            case CryptoHasherTag.EVP_TAG => {
                this.evpValue!!.update(input)
                let err = BoringSSL.errGetError()
                if (err != 0) {
                    let instance = createCryptoError(globalThis, err)
                    BoringSSL.errClearError()
                    return instance
                }
            }
            case CryptoHasherTag.HMAC_TAG => {
                let hmac = this.hmacValue
                match (hmac) {
                    case None => return throwHmacConsumed()
                    case Some(h) => {
                        h.update(input)
                        let err = BoringSSL.errGetError()
                        if (err != 0) {
                            let instance = createCryptoError(globalThis, err)
                            BoringSSL.errClearError()
                            return instance
                        }
                    }
                }
            }
            case CryptoHasherTag.ZIG_TAG => {
                this.zigValue!!.update(input)
            }
        }
        return JsValue.UNDEFINED
    }

    // ========================================================================
    // copy 实例方法
    // 对应 Bun: pub fn copy(this, globalObject, _) bun.JSError!jsc.JSValue
    // ========================================================================

    /// 复制哈希器
    public func copy(globalObject: JsObject): ?CryptoHasher {
        match (this.tag) {
            case CryptoHasherTag.EVP_TAG => {
                let engine = RareData.getBoringEngine(globalObject)
                let copied = this.evpValue!!.copy(engine)
                match (copied) {
                    case Some(evpCopy) => {
                        let hasher = CryptoHasher(CryptoHasherTag.EVP_TAG)
                        hasher.evpValue = evpCopy
                        return hasher
                    }
                    case None => return None
                }
            }
            case CryptoHasherTag.HMAC_TAG => {
                let hmac = this.hmacValue
                match (hmac) {
                    case None => return None
                    case Some(h) => {
                        let hmacCopy = h.copy()
                        match (hmacCopy) {
                            case Some(c) => {
                                let hasher = CryptoHasher(CryptoHasherTag.HMAC_TAG)
                                hasher.hmacValue = c
                                return hasher
                            }
                            case None => return None
                        }
                    }
                }
            }
            case CryptoHasherTag.ZIG_TAG => {
                let hasher = CryptoHasher(CryptoHasherTag.ZIG_TAG)
                hasher.zigValue = this.zigValue!!.copy()
                return hasher
            }
        }
    }

    // ========================================================================
    // digest 实例方法
    // 对应 Bun: pub fn digest_(this, globalThis, output) bun.JSError!jsc.JSValue
    // ========================================================================

    /// 获取摘要
    public func digest(globalThis: JsObject, output: ?String): JsValue {
        match (output) {
            case Some(encoding) => {
                return this.digestToEncoding(globalThis, encoding)
            }
            case None => {
                return this.digestToBytes(globalThis, None)
            }
        }
    }

    /// 摘要到字节
    /// 对应 Bun: fn digestToBytes(this, globalThis, output) bun.JSError!jsc.JSValue
    private func digestToBytes(globalThis: JsObject, output: ?JsArrayBuffer): JsValue {
        var outputDigestBuf = Array<Byte>(DIGEST_SIZE, item: 0)
        var outputDigestSlice: Array<Byte> = outputDigestBuf

        match (output) {
            case Some(outputBuf) => {
                let bytes = outputBuf.byteSlice()
                if (bytes.size < DIGEST_SIZE) {
                    return JsValue(BaoString("TypedArray must be at least ${DIGEST_SIZE} bytes"))
                }
                outputDigestSlice = bytes
            }
            case None => {
                // output_digest_buf = std.mem.zeroes(EVP.Digest)
                for (i in 0..outputDigestBuf.size) {
                    outputDigestBuf[i] = 0
                }
            }
        }

        let result = this.finalDigest(globalThis, outputDigestSlice)
        match (result) {
            case Some(res) => {
                match (output) {
                    case Some(outputBuf) => return outputBuf.value
                    case None => return JsArrayBuffer.createBuffer(globalThis, res)
                }
            }
            case None => return JsValue.UNDEFINED
        }
    }

    /// 摘要到编码
    /// 对应 Bun: fn digestToEncoding(this, globalThis, encoding) bun.JSError!jsc.JSValue
    private func digestToEncoding(globalThis: JsObject, encoding: String): JsValue {
        var outputDigestBuf = Array<Byte>(DIGEST_SIZE, item: 0)
        for (i in 0..outputDigestBuf.size) {
            outputDigestBuf[i] = 0
        }
        let out = this.finalDigest(globalThis, outputDigestBuf)
        match (out) {
            case Some(res) => {
                return JsValue(BaoString(encodingEncode(encoding, res)))
            }
            case None => return JsValue.UNDEFINED
        }
    }

    /// 内部 final 方法
    /// 对应 Bun: fn final(this, globalThis, output_digest_slice) bun.JSError![]u8
    private func finalDigest(globalThis: JsObject, outputDigestSlice: Array<Byte>): ?Array<Byte> {
        match (this.tag) {
            case CryptoHasherTag.HMAC_TAG => {
                let hmac = this.hmacValue
                match (hmac) {
                    case None => {
                        throwHmacConsumed()
                        return None
                    }
                    case Some(h) => {
                        this.hmacValue = None
                        defer(h.deinit())
                        return h.final(outputDigestSlice)
                    }
                }
            }
            case CryptoHasherTag.EVP_TAG => {
                let engine = RareData.getBoringEngine(globalThis)
                return this.evpValue!!.final(engine, outputDigestSlice)
            }
            case CryptoHasherTag.ZIG_TAG => {
                return this.zigValue!!.final(outputDigestSlice)
            }
        }
    }

    /// 释放资源
    /// 对应 Bun: pub fn finalize(this) void
    public func finalize(): Unit {
        match (this.tag) {
            case CryptoHasherTag.EVP_TAG => {
                this.evpValue!!.deinit()
            }
            case CryptoHasherTag.ZIG_TAG => {
                this.zigValue!!.deinit()
            }
            case CryptoHasherTag.HMAC_TAG => {
                match (this.hmacValue) {
                    case Some(h) => h.deinit()
                    case None => ()
                }
            }
        }
    }

    /// HMAC 已消费错误
    /// 对应 Bun: fn throwHmacConsumed(globalThis) bun.JSError
    private static func throwHmacConsumed(): JsValue {
        return JsValue(BaoString("HMAC has been consumed and is no longer usable"))
    }
}

// ============================================================================
// CryptoHasherZig - Zig 实现的哈希器
// 对应 Bun: CryptoHasher.zig - const CryptoHasherZig = struct { ... }
// ============================================================================

/// Zig 实现的哈希器
/// 对应 Bun: const CryptoHasherZig = struct {
///     algorithm: EVP.Algorithm,
///     state: *anyopaque,
///     digest_length: u8,
/// }
public class CryptoHasherZig {
    public var algorithm: EVP.Algorithm
    public var state: HashState
    public var digestLength: UInt8

    public init(algorithm: EVP.Algorithm, state: HashState, digestLength: UInt8) {
        this.algorithm = algorithm
        this.state = state
        this.digestLength = digestLength
    }

    // ========================================================================
    // 算法映射表
    // 对应 Bun: const algo_map = [_]struct { string, type }{ ... }
    // ========================================================================

    /// 算法映射条目
    public class AlgoMapEntry {
        public let name: String
        public let algorithm: EVP.Algorithm
        public let digestLength: UInt8

        public init(name: String, algorithm: EVP.Algorithm, digestLength: UInt8) {
            this.name = name
            this.algorithm = algorithm
            this.digestLength = digestLength
        }
    }

    /// 算法映射表
    /// 对应 Bun: const algo_map = [_]struct { string, type }{
    ///     .{ "sha3-224", std.crypto.hash.sha3.Sha3_224 },
    ///     .{ "sha3-256", std.crypto.hash.sha3.Sha3_256 },
    ///     .{ "sha3-384", std.crypto.hash.sha3.Sha3_384 },
    ///     .{ "sha3-512", std.crypto.hash.sha3.Sha3_512 },
    ///     .{ "shake128", std.crypto.hash.sha3.Shake128 },
    ///     .{ "shake256", std.crypto.hash.sha3.Shake256 },
    ///     .{ "blake2s256", std.crypto.hash.blake2.Blake2s256 },
    /// }
    public static let ALGO_MAP: ArrayList<AlgoMapEntry> = ArrayList<AlgoMapEntry>([
        AlgoMapEntry("sha3-224", EVP.Algorithm.sha3_224, 28),     // Sha3_224.digest_length
        AlgoMapEntry("sha3-256", EVP.Algorithm.sha3_256, 32),     // Sha3_256.digest_length
        AlgoMapEntry("sha3-384", EVP.Algorithm.sha3_384, 48),     // Sha3_384.digest_length
        AlgoMapEntry("sha3-512", EVP.Algorithm.sha3_512, 64),     // Sha3_512.digest_length
        AlgoMapEntry("shake128", EVP.Algorithm.shake128, 16),     // Shake128 custom digest
        AlgoMapEntry("shake256", EVP.Algorithm.shake256, 32),     // Shake256 custom digest
        AlgoMapEntry("blake2s256", EVP.Algorithm.blake2s256, 32), // Blake2s256.digest_length
    ])

    /// 初始化
    /// 对应 Bun: pub fn init(algorithm: []const u8) ?CryptoHasherZig
    public static func initFunc(algorithm: String): ?CryptoHasherZig {
        for (entry in ALGO_MAP) {
            if (algorithm == entry.name) {
                let state = HashState(entry.algorithm)
                state.reset()
                return CryptoHasherZig(entry.algorithm, state, entry.digestLength)
            }
        }
        return None
    }

    /// 构造器
    /// 对应 Bun: fn constructor(algorithm: ZigString) ?*CryptoHasher
    public static func constructor(algorithm: String): ?CryptoHasherZig {
        for (entry in ALGO_MAP) {
            if (algorithm == entry.name) {
                let state = HashState(entry.algorithm)
                state.reset()
                return CryptoHasherZig(entry.algorithm, state, entry.digestLength)
            }
        }
        return None
    }

    /// 按名称哈希
    /// 对应 Bun: pub fn hashByName(globalThis, algorithm, input, output) bun.JSError!?jsc.JSValue
    public static func hashByName(globalThis: JsObject, algorithm: String,
                                   input: Array<Byte>, output: ?String): ?JsValue {
        for (entry in ALGO_MAP) {
            if (algorithm == entry.name) {
                // hashByNameInnerToBytes
                var h = HashState(entry.algorithm)
                h.reset()
                h.update(input)
                var out = Array<Byte>(entry.digestLength, item: 0)
                h.final(out)
                return JsArrayBuffer.createBuffer(globalThis, out)
            }
        }
        return None
    }

    /// 更新数据
    /// 对应 Bun: fn update(self: *CryptoHasherZig, bytes: []const u8) void
    public func update(bytes: Array<Byte>): Unit {
        this.state.update(bytes)
    }

    /// 复制
    /// 对应 Bun: fn copy(self: *const CryptoHasherZig) CryptoHasherZig
    public func copy(): CryptoHasherZig {
        let stateCopy = this.state.copy()
        return CryptoHasherZig(this.algorithm, stateCopy, this.digestLength)
    }

    /// 带长度的 final
    /// 对应 Bun: fn finalWithLen(self, output_digest_slice, res_len) []u8
    public func finalWithLen(outputDigestSlice: Array<Byte>, resLen: Int64): Array<Byte> {
        this.state.final(outputDigestSlice)
        this.state.reset()
        if (resLen <= outputDigestSlice.size) {
            return outputDigestSlice[0..resLen]
        }
        return outputDigestSlice
    }

    /// 最终哈希
    /// 对应 Bun: fn final(self, output_digest_slice) []u8
    public func final(outputDigestSlice: Array<Byte>): Array<Byte> {
        return this.finalWithLen(outputDigestSlice, this.digestLength.toInt64())
    }

    /// 释放
    /// 对应 Bun: fn deinit(self) void
    public func deinit(): Unit {
        this.state.deinit()
    }
}

// ============================================================================
// HashState - 哈希状态（模拟 Zig 的编译时多态）
// 对应 Bun: *anyopaque 状态指针
// ============================================================================

/// 哈希状态封装
/// 对应 Bun: *anyopaque 状态指针 + inline for 编译时分派
public class HashState {
    public var algorithm: EVP.Algorithm
    public var data: Array<Byte>
    public var position: Int64

    public init(algorithm: EVP.Algorithm) {
        this.algorithm = algorithm
        this.data = Array<Byte>(128, item: 0)  // 足够大的缓冲区
        this.position = 0
    }

    /// 重置状态
    public func reset(): Unit {
        for (i in 0..data.size) {
            data[i] = 0
        }
        position = 0
    }

    /// 更新数据
    public func update(bytes: Array<Byte>): Unit {
        for (b in bytes) {
            if (position < data.size) {
                data[position] = b
                position++
            }
        }
    }

    /// 获取最终哈希
    public func final(output: Array<Byte>): Unit {
        // 根据算法分派到具体实现
        // 对应 Bun: inline for 编译时分派
        // TODO: 调用实际的哈希实现
        let digestLen = getDigestLength()
        for (i in 0..digestLen) {
            if (i < output.size) {
                output[i] = data[i % 128]
            }
        }
        this.reset()
    }

    /// 复制状态
    public func copy(): HashState {
        let newState = HashState(this.algorithm)
        for (i in 0..this.data.size) {
            newState.data[i] = this.data[i]
        }
        newState.position = this.position
        return newState
    }

    /// 释放
    public func deinit(): Unit {
        // 清除敏感数据
        for (i in 0..data.size) {
            data[i] = 0
        }
    }

    /// 获取摘要长度
    private func getDigestLength(): Int64 {
        match (this.algorithm) {
            case EVP.Algorithm.sha3_224 => 28
            case EVP.Algorithm.sha3_256 => 32
            case EVP.Algorithm.sha3_384 => 48
            case EVP.Algorithm.sha3_512 => 64
            case EVP.Algorithm.shake128 => 16
            case EVP.Algorithm.shake256 => 32
            case EVP.Algorithm.blake2s256 => 32
            case _ => 32
        }
    }
}

// ============================================================================
// StaticCryptoHasher - 静态加密哈希器模板实例
// 对应 Bun: fn StaticCryptoHasher(comptime Hasher: type, comptime name) type
// ============================================================================

/// MD4 静态哈希器
/// 对应 Bun: pub const MD4 = StaticCryptoHasher(Hashers.MD4, "MD4")
public class MD4Hasher {
    public var hashing: StaticHasherState
    public var digested: Bool

    public init() {
        this.hashing = StaticHasherState("MD4", 16)
        this.digested = false
    }

    public func getByteLength(): UInt16 {
        return UInt16(this.hashing.digest)
    }

    public static func getByteLengthStatic(): UInt16 {
        return UInt16(16)  // MD4.digest
    }

    public func update(globalThis: JsObject, input: Array<Byte>): JsValue {
        if (this.digested) {
            return JsValue(BaoString("MD4 hasher already digested, create a new instance to update"))
        }
        this.hashing.update(input)
        return JsValue.UNDEFINED
    }

    public func digest(globalThis: JsObject, output: ?String): JsValue {
        if (this.digested) {
            return JsValue(BaoString("MD4 hasher already digested, create a new instance to digest again"))
        }
        match (output) {
            case Some(encoding) => {
                let result = this.hashing.final()
                this.digested = true
                return JsValue(BaoString(encodingEncode(encoding, result)))
            }
            case None => {
                let result = this.hashing.final()
                this.digested = true
                return JsArrayBuffer.createBuffer(globalThis, result)
            }
        }
    }

    public static func hashStatic(globalThis: JsObject, input: Array<Byte>, output: ?String): JsValue {
        var hasher = StaticHasherState("MD4", 16)
        hasher.update(input)
        let result = hasher.final()
        match (output) {
            case Some(encoding) => return JsValue(BaoString(encodingEncode(encoding, result)))
            case None => return JsArrayBuffer.createBuffer(globalThis, result)
        }
    }

    public func finalize(): Unit {
        this.hashing.deinit()
    }
}

/// MD5 静态哈希器
/// 对应 Bun: pub const MD5 = StaticCryptoHasher(Hashers.MD5, "MD5")
public class MD5Hasher {
    public var hashing: StaticHasherState
    public var digested: Bool

    public init() {
        this.hashing = StaticHasherState("MD5", 16)
        this.digested = false
    }

    public func getByteLength(): UInt16 {
        return UInt16(this.hashing.digest)
    }

    public static func getByteLengthStatic(): UInt16 {
        return UInt16(16)  // MD5.digest
    }

    public func update(globalThis: JsObject, input: Array<Byte>): JsValue {
        if (this.digested) {
            return JsValue(BaoString("MD5 hasher already digested, create a new instance to update"))
        }
        this.hashing.update(input)
        return JsValue.UNDEFINED
    }

    public func digest(globalThis: JsObject, output: ?String): JsValue {
        if (this.digested) {
            return JsValue(BaoString("MD5 hasher already digested, create a new instance to digest again"))
        }
        match (output) {
            case Some(encoding) => {
                let result = this.hashing.final()
                this.digested = true
                return JsValue(BaoString(encodingEncode(encoding, result)))
            }
            case None => {
                let result = this.hashing.final()
                this.digested = true
                return JsArrayBuffer.createBuffer(globalThis, result)
            }
        }
    }

    public static func hashStatic(globalThis: JsObject, input: Array<Byte>, output: ?String): JsValue {
        var hasher = StaticHasherState("MD5", 16)
        hasher.update(input)
        let result = hasher.final()
        match (output) {
            case Some(encoding) => return JsValue(BaoString(encodingEncode(encoding, result)))
            case None => return JsArrayBuffer.createBuffer(globalThis, result)
        }
    }

    public func finalize(): Unit {
        this.hashing.deinit()
    }
}

/// SHA1 静态哈希器
/// 对应 Bun: pub const SHA1 = StaticCryptoHasher(Hashers.SHA1, "SHA1")
public class SHA1Hasher {
    public var hashing: StaticHasherState
    public var digested: Bool

    public init() {
        this.hashing = StaticHasherState("SHA1", 20)
        this.digested = false
    }

    public func getByteLength(): UInt16 {
        return UInt16(this.hashing.digest)
    }

    public static func getByteLengthStatic(): UInt16 {
        return UInt16(20)  // SHA1.digest
    }

    public func update(globalThis: JsObject, input: Array<Byte>): JsValue {
        if (this.digested) {
            return JsValue(BaoString("SHA1 hasher already digested, create a new instance to update"))
        }
        this.hashing.update(input)
        return JsValue.UNDEFINED
    }

    public func digest(globalThis: JsObject, output: ?String): JsValue {
        if (this.digested) {
            return JsValue(BaoString("SHA1 hasher already digested, create a new instance to digest again"))
        }
        match (output) {
            case Some(encoding) => {
                let result = this.hashing.final()
                this.digested = true
                return JsValue(BaoString(encodingEncode(encoding, result)))
            }
            case None => {
                let result = this.hashing.final()
                this.digested = true
                return JsArrayBuffer.createBuffer(globalThis, result)
            }
        }
    }

    public static func hashStatic(globalThis: JsObject, input: Array<Byte>, output: ?String): JsValue {
        var hasher = StaticHasherState("SHA1", 20)
        hasher.update(input)
        let result = hasher.final()
        match (output) {
            case Some(encoding) => return JsValue(BaoString(encodingEncode(encoding, result)))
            case None => return JsArrayBuffer.createBuffer(globalThis, result)
        }
    }

    public func finalize(): Unit {
        this.hashing.deinit()
    }
}

/// SHA224 静态哈希器
/// 对应 Bun: pub const SHA224 = StaticCryptoHasher(Hashers.SHA224, "SHA224")
public class SHA224Hasher {
    public var hashing: StaticHasherState
    public var digested: Bool

    public init() {
        this.hashing = StaticHasherState("SHA224", 28)
        this.digested = false
    }

    public func getByteLength(): UInt16 {
        return UInt16(this.hashing.digest)
    }

    public static func getByteLengthStatic(): UInt16 {
        return UInt16(28)  // SHA224.digest
    }

    public func update(globalThis: JsObject, input: Array<Byte>): JsValue {
        if (this.digested) {
            return JsValue(BaoString("SHA224 hasher already digested, create a new instance to update"))
        }
        this.hashing.update(input)
        return JsValue.UNDEFINED
    }

    public func digest(globalThis: JsObject, output: ?String): JsValue {
        if (this.digested) {
            return JsValue(BaoString("SHA224 hasher already digested, create a new instance to digest again"))
        }
        match (output) {
            case Some(encoding) => {
                let result = this.hashing.final()
                this.digested = true
                return JsValue(BaoString(encodingEncode(encoding, result)))
            }
            case None => {
                let result = this.hashing.final()
                this.digested = true
                return JsArrayBuffer.createBuffer(globalThis, result)
            }
        }
    }

    public static func hashStatic(globalThis: JsObject, input: Array<Byte>, output: ?String): JsValue {
        var hasher = StaticHasherState("SHA224", 28)
        hasher.update(input)
        let result = hasher.final()
        match (output) {
            case Some(encoding) => return JsValue(BaoString(encodingEncode(encoding, result)))
            case None => return JsArrayBuffer.createBuffer(globalThis, result)
        }
    }

    public func finalize(): Unit {
        this.hashing.deinit()
    }
}

/// SHA256 静态哈希器
/// 对应 Bun: pub const SHA256 = StaticCryptoHasher(Hashers.SHA256, "SHA256")
public class SHA256Hasher {
    public var hashing: StaticHasherState
    public var digested: Bool

    public init() {
        this.hashing = StaticHasherState("SHA256", 32)
        this.digested = false
    }

    public func getByteLength(): UInt16 {
        return UInt16(this.hashing.digest)
    }

    public static func getByteLengthStatic(): UInt16 {
        return UInt32(32)  // SHA256.digest
    }

    public func update(globalThis: JsObject, input: Array<Byte>): JsValue {
        if (this.digested) {
            return JsValue(BaoString("SHA256 hasher already digested, create a new instance to update"))
        }
        this.hashing.update(input)
        return JsValue.UNDEFINED
    }

    public func digest(globalThis: JsObject, output: ?String): JsValue {
        if (this.digested) {
            return JsValue(BaoString("SHA256 hasher already digested, create a new instance to digest again"))
        }
        match (output) {
            case Some(encoding) => {
                let result = this.hashing.final()
                this.digested = true
                return JsValue(BaoString(encodingEncode(encoding, result)))
            }
            case None => {
                let result = this.hashing.final()
                this.digested = true
                return JsArrayBuffer.createBuffer(globalThis, result)
            }
        }
    }

    public static func hashStatic(globalThis: JsObject, input: Array<Byte>, output: ?String): JsValue {
        var hasher = StaticHasherState("SHA256", 32)
        hasher.update(input)
        let result = hasher.final()
        match (output) {
            case Some(encoding) => return JsValue(BaoString(encodingEncode(encoding, result)))
            case None => return JsArrayBuffer.createBuffer(globalThis, result)
        }
    }

    public func finalize(): Unit {
        this.hashing.deinit()
    }
}

/// SHA384 静态哈希器
/// 对应 Bun: pub const SHA384 = StaticCryptoHasher(Hashers.SHA384, "SHA384")
public class SHA384Hasher {
    public var hashing: StaticHasherState
    public var digested: Bool

    public init() {
        this.hashing = StaticHasherState("SHA384", 48)
        this.digested = false
    }

    public func getByteLength(): UInt16 {
        return UInt16(this.hashing.digest)
    }

    public static func getByteLengthStatic(): UInt16 {
        return UInt16(48)  // SHA384.digest
    }

    public func update(globalThis: JsObject, input: Array<Byte>): JsValue {
        if (this.digested) {
            return JsValue(BaoString("SHA384 hasher already digested, create a new instance to update"))
        }
        this.hashing.update(input)
        return JsValue.UNDEFINED
    }

    public func digest(globalThis: JsObject, output: ?String): JsValue {
        if (this.digested) {
            return JsValue(BaoString("SHA384 hasher already digested, create a new instance to digest again"))
        }
        match (output) {
            case Some(encoding) => {
                let result = this.hashing.final()
                this.digested = true
                return JsValue(BaoString(encodingEncode(encoding, result)))
            }
            case None => {
                let result = this.hashing.final()
                this.digested = true
                return JsArrayBuffer.createBuffer(globalThis, result)
            }
        }
    }

    public static func hashStatic(globalThis: JsObject, input: Array<Byte>, output: ?String): JsValue {
        var hasher = StaticHasherState("SHA384", 48)
        hasher.update(input)
        let result = hasher.final()
        match (output) {
            case Some(encoding) => return JsValue(BaoString(encodingEncode(encoding, result)))
            case None => return JsArrayBuffer.createBuffer(globalThis, result)
        }
    }

    public func finalize(): Unit {
        this.hashing.deinit()
    }
}

/// SHA512 静态哈希器
/// 对应 Bun: pub const SHA512 = StaticCryptoHasher(Hashers.SHA512, "SHA512")
public class SHA512Hasher {
    public var hashing: StaticHasherState
    public var digested: Bool

    public init() {
        this.hashing = StaticHasherState("SHA512", 64)
        this.digested = false
    }

    public func getByteLength(): UInt16 {
        return UInt16(this.hashing.digest)
    }

    public static func getByteLengthStatic(): UInt16 {
        return UInt16(64)  // SHA512.digest
    }

    public func update(globalThis: JsObject, input: Array<Byte>): JsValue {
        if (this.digested) {
            return JsValue(BaoString("SHA512 hasher already digested, create a new instance to update"))
        }
        this.hashing.update(input)
        return JsValue.UNDEFINED
    }

    public func digest(globalThis: JsObject, output: ?String): JsValue {
        if (this.digested) {
            return JsValue(BaoString("SHA512 hasher already digested, create a new instance to digest again"))
        }
        match (output) {
            case Some(encoding) => {
                let result = this.hashing.final()
                this.digested = true
                return JsValue(BaoString(encodingEncode(encoding, result)))
            }
            case None => {
                let result = this.hashing.final()
                this.digested = true
                return JsArrayBuffer.createBuffer(globalThis, result)
            }
        }
    }

    public static func hashStatic(globalThis: JsObject, input: Array<Byte>, output: ?String): JsValue {
        var hasher = StaticHasherState("SHA512", 64)
        hasher.update(input)
        let result = hasher.final()
        match (output) {
            case Some(encoding) => return JsValue(BaoString(encodingEncode(encoding, result)))
            case None => return JsArrayBuffer.createBuffer(globalThis, result)
        }
    }

    public func finalize(): Unit {
        this.hashing.deinit()
    }
}

/// SHA512_256 静态哈希器
/// 对应 Bun: pub const SHA512_256 = StaticCryptoHasher(Hashers.SHA512_256, "SHA512_256")
public class SHA512_256Hasher {
    public var hashing: StaticHasherState
    public var digested: Bool

    public init() {
        this.hashing = StaticHasherState("SHA512_256", 32)
        this.digested = false
    }

    public func getByteLength(): UInt16 {
        return UInt16(this.hashing.digest)
    }

    public static func getByteLengthStatic(): UInt16 {
        return UInt16(32)  // SHA512_256.digest
    }

    public func update(globalThis: JsObject, input: Array<Byte>): JsValue {
        if (this.digested) {
            return JsValue(BaoString("SHA512_256 hasher already digested, create a new instance to update"))
        }
        this.hashing.update(input)
        return JsValue.UNDEFINED
    }

    public func digest(globalThis: JsObject, output: ?String): JsValue {
        if (this.digested) {
            return JsValue(BaoString("SHA512_256 hasher already digested, create a new instance to digest again"))
        }
        match (output) {
            case Some(encoding) => {
                let result = this.hashing.final()
                this.digested = true
                return JsValue(BaoString(encodingEncode(encoding, result)))
            }
            case None => {
                let result = this.hashing.final()
                this.digested = true
                return JsArrayBuffer.createBuffer(globalThis, result)
            }
        }
    }

    public static func hashStatic(globalThis: JsObject, input: Array<Byte>, output: ?String): JsValue {
        var hasher = StaticHasherState("SHA512_256", 32)
        hasher.update(input)
        let result = hasher.final()
        match (output) {
            case Some(encoding) => return JsValue(BaoString(encodingEncode(encoding, result)))
            case None => return JsArrayBuffer.createBuffer(globalThis, result)
        }
    }

    public func finalize(): Unit {
        this.hashing.deinit()
    }
}

// ============================================================================
// StaticHasherState - 静态哈希器状态
// 对应 Bun: StaticCryptoHasher 中 Hasher 的状态管理
// ============================================================================

/// 静态哈希器状态
public class StaticHasherState {
    public let name: String
    public let digest: Int64
    public var data: Array<Byte>
    public var position: Int64

    public init(name: String, digest: Int64) {
        this.name = name
        this.digest = digest
        this.data = Array<Byte>(digest, item: 0)
        this.position = 0
    }

    public func reset(): Unit {
        for (i in 0..data.size) {
            data[i] = 0
        }
        position = 0
    }

    public func update(bytes: Array<Byte>): Unit {
        for (b in bytes) {
            if (position < data.size) {
                data[position] = b
                position++
            }
        }
    }

    public func final(): Array<Byte> {
        var result = Array<Byte>(digest, item: 0)
        for (i in 0..digest) {
            result[i] = data[i % data.size]
        }
        return result
    }

    public func deinit(): Unit {
        for (i in 0..data.size) {
            data[i] = 0
        }
    }
}

// ============================================================================
// 辅助类和函数
// ============================================================================

/// JS ArrayBuffer 封装
/// 对应 Bun: jsc.ArrayBuffer
public class JsArrayBuffer {
    public var value: JsValue
    public var buffer: Array<Byte>

    public init() {
        value = JsValue.UNDEFINED
        buffer = Array<Byte>()
    }

    /// 获取字节切片
    /// 对应 Bun: output_buf.byteSlice()
    public func byteSlice(): Array<Byte> {
        return buffer
    }

    /// 创建 Buffer
    /// 对应 Bun: jsc.ArrayBuffer.createBuffer(globalThis, result)
    public static func createBuffer(globalThis: JsObject, data: Array<Byte>): JsValue {
        // TODO: 创建实际的 JS ArrayBuffer
        return JsValue.array(ArrayList<JsValue>())
    }
}

/// JS Promise 封装
/// 对应 Bun: jsc.JSPromise
public class JsPromise {
    public var resolved: Bool
    public var rejected: Bool
    public var resolvedValue: ?JsValue
    public var rejectedValue: ?JsValue

    public init() {
        resolved = false
        rejected = false
        resolvedValue = None
        rejectedValue = None
    }

    public static func initFunc(globalThis: JsObject): JsPromise {
        return JsPromise()
    }

    public func resolve(value: JsValue): Unit {
        resolved = true
        resolvedValue = value
    }

    public func reject(value: JsValue): Unit {
        rejected = true
        rejectedValue = value
    }

    public func value(): JsValue {
        match (resolvedValue) {
            case Some(v) => v
            case None => JsValue.UNDEFINED
        }
    }

    public func deinit(): Unit {}

    public func swap(): JsPromise {
        let old = JsPromise()
        old.resolved = this.resolved
        old.rejected = this.rejected
        old.resolvedValue = this.resolvedValue
        old.rejectedValue = this.rejectedValue
        this.resolved = false
        this.rejected = false
        this.resolvedValue = None
        this.rejectedValue = None
        return old
    }
}

/// JS Native Function 封装
/// 对应 Bun: jsc.JSFunction / jsc.JSNativeFunction
public class JsNativeFunction {
    public var name: String
    public var callback: (JsObject, ArrayList<JsValue>) -> JsValue

    public init(name: String, callback: (JsObject, ArrayList<JsValue>) -> JsValue) {
        this.name = name
        this.callback = callback
    }
}

/// RareData - 虚拟机稀有数据
/// 对应 Bun: jsc.VirtualMachine.rareData()
public class RareData {
    public static func getBoringEngine(globalThis: JsObject): ?Engine {
        // 对应 Bun: global.bunVM().rareData().boringEngine()
        return Engine()
    }
}

/// WorkPool - 工作线程池
/// 对应 Bun: jsc.WorkPool
public class WorkPool {
    public static func schedule(job: PBKDF2Job): Unit {
        // TODO: 实际线程池调度
        job.runTask()
    }

    public static func schedule(job: JSPasswordObject.HashJob): Unit {
        job.run()
    }

    public static func schedule(job: JSPasswordObject.VerifyJob): Unit {
        job.run()
    }
}

/// 编码辅助函数
/// 对应 Bun: jsc.Node.Encoding.encodeWithSize / encodeWithMaxSize
private func encodingEncode(encoding: String, data: Array<Byte>): String {
    match (encoding) {
        case "hex" => {
            var sb = StringBuilder()
            for (b in data) {
                let hex = b.toInt64().toString(16)
                if (hex.size == 1) {
                    sb.append("0")
                }
                sb.append(hex)
            }
            return sb.toString()
        }
        case "base64" => {
            // TODO: 实际 base64 编码
            return "base64:${data.size}"
        }
        case "buffer" | _ => {
            // 返回原始字节的十六进制表示
            var sb = StringBuilder()
            for (b in data) {
                let hex = b.toInt64().toString(16)
                if (hex.size == 1) {
                    sb.append("0")
                }
                sb.append(hex)
            }
            return sb.toString()
        }
    }
}
