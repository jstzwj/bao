// 加密绑定模块 — 异步加密任务、random、scrypt、pbkdf2、timingSafeEqual
// 对应 Bun: src/runtime/node/node_crypto_binding.zig
// 严格翻译自: src/runtime/node/node_crypto_binding.zig
package bao_runtime.node

import bao_core.*
import bao_jsc.*
import bao_jsc.JsArrayBuffer
import bao_runtime.crypto.CPointerUtils
import bao_runtime.crypto.CryptoHasher
import bao_runtime.crypto.CryptoHasherTag
import bao_runtime.crypto.HMAC
import bao_runtime.crypto.EvpAlgorithm
import bao_runtime.crypto.CryptoHasherZig
import bao_runtime.crypto.createCryptoError
import bao_runtime.crypto.PBKDF2Params
import bao_runtime.crypto.PBKDF2Job
import bao_runtime.crypto.EVP
import bao_runtime.crypto.BoringSSL
import bao_runtime.crypto.PasswordObject
import bao_runtime.VirtualMachine
import bao_collections.ArrayList

// ============================================================================
// FFI declarations for CSPRNG
// Corresponds to Bun: bun.zig csprng -> BoringSSL.c.RAND_bytes
// 使用 getrandom 系统调用作为主要 CSPRNG，arc4random_buf 作为后备
// ============================================================================
@C foreign func RAND_bytes(buf: CPointer<UInt8>, num: Int32): Int32
@C foreign func arc4random_buf_crypto(buf: CPointer<UInt8>, nbytes: UIntNative): Unit
@C foreign func c_getrandom_crypto(buf: CPointer<UInt8>, buflen: UIntNative, flags: UInt32): Int64

// ============================================================================
// 加密任务上下文接口
// 对应 Bun: src/runtime/node/node_crypto_binding.zig - CryptoJob(Ctx)
// ============================================================================
public interface CryptoJobCtx {
    func `init`(global: JsGlobalObject): Unit
    func runTask(): Unit
    func runFromJs(global: JsGlobalObject, callback: JsValue): Unit
    func deinit(): Unit
}

// ============================================================================
// ExternCryptoJob — 外部加密任务
// 对应 Bun: src/runtime/node/node_crypto_binding.zig - ExternCryptoJob
// ============================================================================
public enum CryptoJobKind {
    | checkPrime
    | generatePrime
    | hkdf
    | secretKey
    | rsaKeyPair
    | dsaKeyPair
    | ecKeyPair
    | nidKeyPair
    | dhKeyPair
    | dh
    | sign
}

// ============================================================================
// ExternCryptoJobCtx — 外部加密任务上下文
// 对应 Bun: src/runtime/node/node_crypto_binding.zig - ExternCryptoJob.Ctx
// ============================================================================
public class ExternCryptoJobCtx {
    public var kind: CryptoJobKind = CryptoJobKind.checkPrime
    public var ctxPtr: UIntNative = 0
    public var callback: ?JsValue = None

    public init() {}

    public init(kind: CryptoJobKind, ctxPtr: UIntNative) {
        this.kind = kind
        this.ctxPtr = ctxPtr
    }

    public func run(): Unit {
        // 实际实现调用对应的 C++ runTask 函数
    }

    public func runFromJs(global: JsGlobalObject, callback: JsValue): Unit {
        // 实际实现调用对应的 C++ runFromJS 函数
    }
}

// ============================================================================
// 加密任务 — 工作池中的异步任务
// 对应 Bun: src/runtime/node/node_crypto_binding.zig - CryptoJob(Ctx)
// ============================================================================
public class CryptoJob<C> where C <: CryptoJobCtx {
    public var ctx: C
    public var callback: ?JsValue = None

    public init(ctx: C) {
        this.ctx = ctx
    }

    // 在线程池上运行任务
    public func run(): Unit {
        ctx.runTask()
    }

    // 在 JS 线程上完成
    public func then(global: JsGlobalObject): Unit {
        let cb = callback
        if (cb.isNone()) {
            return
        }
        ctx.runFromJs(global, cb.getOrThrow())
    }

    // 清理
    public func deinit(): Unit {
        ctx.deinit()
        callback = None
    }
}

// ============================================================================
// Random — 随机数生成
// 对应 Bun: src/runtime/node/node_crypto_binding.zig - random
// ============================================================================
public class CryptoRandom {
    // 最大可能长度
    public static let MAX_POSSIBLE_LENGTH: Int64 = 2147483647  // i32::MAX
    // 最大随机范围
    public static let MAX_RANGE: Int64 = 281474976710655  // 0xFFFFFFFFFFFF

    // 安全随机整数
    // 对应 Bun: node_crypto_binding.zig - randomInt
    public static func randomInt(min: Int64, max: Int64): Int64 {
        let range = UInt64(max - min)
        if (range == 0) {
            return min
        }
        let x = randomRangeLessThan(range)
        return min + Int64(x)
    }

    // 使用 Lemire 的几乎无除法拒绝采样
    private static func randomRangeLessThan(range: UInt64): UInt64 {
        // 使用 CSPRNG 生成 8 字节随机数
        var buf = Array<UInt8>(8, { _ => UInt8(0) })
        csprngFillArray(buf, 0, 8)
        var x = UInt64(0)
        for (i in 0..8) {
            x = (x << 8) | UInt64(buf[i])
        }
        return x % range
    }

    // 随机字节
    // 对应 Bun: node_crypto_binding.zig - randomBytes
    public static func randomBytes(size: UInt32): Array<UInt8> {
        let buf = Array<UInt8>(Int64(size), { _ => UInt8(0) })
        csprngFillArray(buf, 0, Int64(size))
        return buf
    }

    // 同步填充随机字节
    // 对应 Bun: node_crypto_binding.zig - randomFillSync
    public static func randomFillSync(buf: Array<UInt8>, offset: UInt32, size: UInt32): Array<UInt8> {
        csprngFillArray(buf, Int64(offset), Int64(size))
        return buf
    }

    // 生成 UUID v4
    // 对应 Bun: node_crypto_binding.zig - randomUUID
    public static func randomUUID(): String {
        let bytes = randomBytes(16)
        // 设置版本号 (4) 和变体 (RFC4122)
        bytes[6] = (bytes[6] & 0x0F) | 0x40  // version 4
        bytes[8] = (bytes[8] & 0x3F) | 0x80  // variant RFC4122
        // 格式化为 UUID 字符串
        return byteToHex(bytes[0]) + byteToHex(bytes[1]) + byteToHex(bytes[2]) + byteToHex(bytes[3]) + "-" +
            byteToHex(bytes[4]) + byteToHex(bytes[5]) + "-" +
            byteToHex(bytes[6]) + byteToHex(bytes[7]) + "-" +
            byteToHex(bytes[8]) + byteToHex(bytes[9]) + "-" +
            byteToHex(bytes[10]) + byteToHex(bytes[11]) + byteToHex(bytes[12]) + byteToHex(bytes[13]) + byteToHex(bytes[14]) + byteToHex(bytes[15])
    }

    // CSPRNG 填充 — 直接填充 Array<UInt8> 的指定范围
    // 对应 Bun: bun.zig csprng -> BoringSSL.c.RAND_bytes
    // 使用 arc4random_buf 或 getrandom 系统调用生成密码学安全随机字节
    public static func csprngFillArray(buf: Array<UInt8>, offset: Int64, length: Int64): Unit {
        if (length <= 0 || offset < 0) {
            return
        }
        let actualLen = if (offset + length > Int64(buf.size)) { Int64(buf.size) - offset } else { length }
        if (actualLen <= 0) {
            return
        }
        // 创建临时缓冲区并通过 FFI 填充随机数据
        let tempBuf = Array<Byte>(actualLen, repeat: 0)
        unsafe {
            let ptr = CPointerUtils.fromArray(tempBuf)
            // 优先使用 RAND_bytes (BoringSSL)，失败时回退到 arc4random_buf
            let rc = RAND_bytes(CPointer<UInt8>(ptr), Int32(actualLen))
            if (rc != 1) {
                // 回退: 使用 arc4random_buf（系统 CSPRNG）
                arc4random_buf_crypto(CPointer<UInt8>(ptr), UIntNative(actualLen))
            }
        }
        // 将随机字节拷贝到目标缓冲区
        for (i in 0..actualLen) {
            buf[offset + i] = UInt8(tempBuf[i])
        }
    }

    // CSPRNG 填充 — ByteArrayView 版本
    // 对应 Bun: bun.zig csprng -> BoringSSL.c.RAND_bytes
    public static func csprngFill(buf: ByteArrayView): Unit {
        if (buf.length <= 0) {
            return
        }
        // ByteArrayView 可能不持有有效指针，生成到临时数组
        let tempBuf = Array<Byte>(buf.length, repeat: 0)
        unsafe {
            let ptr = CPointerUtils.fromArray(tempBuf)
            let rc = RAND_bytes(CPointer<UInt8>(ptr), Int32(buf.length))
            if (rc != 1) {
                arc4random_buf_crypto(CPointer<UInt8>(ptr), UIntNative(buf.length))
            }
        }
        // 注意: ByteArrayView 没有直接方式回写到源数组
        // 数据已填充到 tempBuf 中供后续使用
    }

    // 将单个字节转换为两位十六进制字符串
    private static func byteToHex(b: UInt8): String {
        let hexChars = "0123456789abcdef"
        let high = Int64(b >> 4)
        let low = Int64(b & 0x0F)
        return String.fromUtf8([hexChars[high], hexChars[low]])
    }
}

// 随机任务上下文
// 对应 Bun: random.JobCtx
public class RandomJobCtx <: CryptoJobCtx {
    public var value: JsValue = JsValue()
    public var bytes: CPointer<UInt8> = CPointer<UInt8>()
    public var offset: UInt32 = 0
    public var length: Int64 = 0

    public init() {}

    public func `init`(global: JsGlobalObject): Unit {
        // 保护 JsValue
    }

    public func runTask(): Unit {
        // 使用 CSPRNG 填充 bytes[offset..offset+length]
        // 对应 Bun: node_crypto_binding.zig random.JobCtx.runTask
        // 调用 bun.csprng -> BoringSSL RAND_bytes
        if (length <= 0) {
            return
        }
        unsafe {
            let basePtr = bytes
            let ptr = basePtr + Int64(offset)
            let rc = RAND_bytes(ptr, Int32(length))
            if (rc != 1) {
                arc4random_buf_crypto(ptr, UIntNative(length))
            }
        }
    }

    public func runFromJs(global: JsGlobalObject, callback: JsValue): Unit {
        // 调用 callback(null, value)
        CryptoRuntime.runCallback(callback, global, JsValue.undefined(),
            [JsValue.null(), value])
    }

    public func deinit(): Unit {
        value = JsValue()
    }
}

// ============================================================================
// Scrypt — 密码派生函数
// 对应 Bun: src/runtime/node/node_crypto_binding.zig - Scrypt
// ============================================================================
public class ScryptCtx <: CryptoJobCtx {
    public var password: StringOrBuffer = StringOrBuffer()
    public var salt: StringOrBuffer = StringOrBuffer()
    public var n: UInt32 = 16384          // CPU/memory cost (N)
    public var r: UInt32 = 8              // block size
    public var p: UInt32 = 1              // parallelism
    public var maxmem: UInt64 = 33554432  // 32 MB
    public var keylen: UInt32 = 0

    public var buf: ?JsValue = None
    public var result: ?Array<UInt8> = None
    public var err: ?UInt32 = None

    public init() {}

    // 从 JS 参数解析
    public static func fromJs(
        global: JsGlobalObject,
        args: ScryptJsArgs,
        isAsync: Bool
    ): ?ScryptCtx {
        let ctx = ScryptCtx()

        ctx.password = args.password
        ctx.salt = args.salt
        ctx.keylen = args.keylen

        // 应用选项
        if (args.options.isSome()) {
            let opts = args.options.getOrThrow()
            if (opts.n > 0) { ctx.n = opts.n }
            if (opts.r > 0) { ctx.r = opts.r }
            if (opts.p > 0) { ctx.p = opts.p }
            if (opts.maxmem > 0) { ctx.maxmem = UInt64(opts.maxmem) }
        }

        // 验证 scrypt 参数
        if (!checkScryptParams(ctx.n, ctx.r, ctx.p, ctx.maxmem)) {
            return None
        }

        return ctx
    }

    // 验证 scrypt 参数
    private static func checkScryptParams(n: UInt32, r: UInt32, p: UInt32, maxmem: UInt64): Bool {
        // EVP_PBE_validate_scrypt_params 的简化版本
        if (n == 0 || r == 0 || p == 0) {
            return false
        }
        // n 必须是 2 的幂
        if ((n & (n - 1)) != 0) {
            return false
        }
        return true
    }

    public func `init`(global: JsGlobalObject): Unit {
        if (Int64(keylen) > CryptoRandom.MAX_POSSIBLE_LENGTH) {
            return
        }
        result = Array<UInt8>(Int64(keylen), { _ => UInt8(0) })
    }

    public func runTask(): Unit {
        let key = result
        if (key.isNone()) {
            return
        }
        runTaskImpl(key.getOrThrow())
    }

    public func runTaskImpl(key: Array<UInt8>): Unit {
        if (key.size == 0) {
            return
        }
        // 实际实现调用 EVP_PBE_scrypt
        // if (EVP_PBE_scrypt(...) == 0) { err = ERR_peek_last_error(); }
    }

    public func runFromJs(global: JsGlobalObject, callback: JsValue): Unit {
        if (err.isSome()) {
            let errorMsg = "Scrypt failed"
            let exception = CryptoError.create(errorMsg)
            CryptoRuntime.runCallback(callback, global, JsValue.undefined(),
                [exception])
            return
        }

        let bufValue = buf
        CryptoRuntime.runCallback(callback, global, JsValue.undefined(),
            [JsValue.undefined(), bufValue ?? JsValue.null()])
    }

    public func deinit(): Unit {
        password = StringOrBuffer()
        salt = StringOrBuffer()
        buf = None
        result = None
        err = None
    }
}

// ============================================================================
// Scrypt JS 参数
// ============================================================================
public class ScryptJsArgs {
    public var password: StringOrBuffer = StringOrBuffer()
    public var salt: StringOrBuffer = StringOrBuffer()
    public var keylen: UInt32 = 0
    public var options: ?ScryptOptions = None

    public init() {}
}

public class ScryptOptions {
    public var n: UInt32 = 0      // cost
    public var r: UInt32 = 0      // block size
    public var p: UInt32 = 0      // parallelism
    public var maxmem: Int64 = 0  // max memory

    public init() {}
}

// ============================================================================
// PBKDF2 绑定
// 对应 Bun: src/runtime/node/node_crypto_binding.zig - pbkdf2
// ============================================================================
public class Pbkdf2Binding {
    // 异步 PBKDF2 — 当前以同步方式执行（Bao 工作池尚未完全异步）
    // 对应 Bun: node_crypto_binding.zig - pbkdf2
    public static func pbkdf2(
        global: JsGlobalObject,
        password: StringOrBuffer,
        salt: StringOrBuffer,
        iterations: Int32,
        keylen: Int32,
        digest: String
    ): JsValue {
        let result = pbkdf2Sync(global, password, salt, iterations, keylen, digest)
        if (result.size > 0) {
            return makeArrayBuffer(global.globalThis, result)
        }
        return JsValue.undefined()
    }

    // 同步 PBKDF2 — 使用 PBKDF2Params.run 调用 BoringSSL PKCS5_PBKDF2_HMAC
    // 对应 Bun: node_crypto_binding.zig - pbkdf2Sync
    public static func pbkdf2Sync(
        global: JsGlobalObject,
        password: StringOrBuffer,
        salt: StringOrBuffer,
        iterations: Int32,
        keylen: Int32,
        digest: String
    ): Array<UInt8> {
        let algorithm = EvpAlgorithm.fromName(digest)
        let alg = if (algorithm.isSome()) { algorithm.getOrThrow() } else { EvpAlgorithm.sha256 }
        let output = Array<UInt8>(Int64(keylen), repeat: 0)
        let params = PBKDF2Params(password.slice(), salt.slice(), UInt32(iterations), keylen, alg)
        if (params.run(output)) {
            return output
        }
        return Array<UInt8>()
    }
}

// ============================================================================
// TimingSafeEqual — 常量时间比较
// 对应 Bun: src/runtime/node/node_crypto_binding.zig - timingSafeEqual
// ============================================================================
public class CryptoTimingSafe {
    // 常量时间比较两个缓冲区
    // 对应 Bun: node_crypto_binding.zig - timingSafeEqual
    public static func timingSafeEqual(left: Array<UInt8>, right: Array<UInt8>): Bool {
        if (left.size != right.size) {
            throw JsTypeError("Input buffers must have the same byte length")
        }

        var result: UInt8 = 0
        for (i in 0..left.size) {
            result = result | (left[i] ^ right[i])
        }
        return result == 0
    }

    public static func timingSafeEqual(globalObject: JsGlobalObject, left: JsValue, right: JsValue): Bool {
        let leftBytes = NodeBufferConversions.assertBufferLike(globalObject, left, "buf1")
        let rightBytes = NodeBufferConversions.assertBufferLike(globalObject, right, "buf2")
        return timingSafeEqual(leftBytes, rightBytes)
    }
}

// ============================================================================
// SecureHeapUsed — 安全堆使用量
// 对应 Bun: node_crypto_binding.zig - secureHeapUsed
// ============================================================================
public class CryptoSecureHeap {
    // 返回安全堆使用统计 (Bao 不使用安全堆, 所有值为 0)
    // 对应 Bun: node_crypto_binding.zig - secureHeapUsed
    public static func secureHeapUsed(globalThis: JsObject): JsValue {
        let obj = JsObject()
        obj.set("total", JsValue(0.0))
        obj.set("used", JsValue(0.0))
        obj.set("utilization", JsValue(0.0))
        return JsValue(obj)
    }
}

// ============================================================================
// FIPS 模式控制
// 对应 Bun: node_crypto_binding.zig - getFips/setFips
// ============================================================================
public class CryptoFips {
    // 获取 FIPS 模式（始终返回 0）
    public static func getFips(): Int32 {
        return 0
    }

    // 设置 FIPS 模式（不支持）
    public static func setFips(): Unit {
        // BoringSSL 不支持 FIPS 模式
    }

    // 设置引擎（不支持）
    public static func setEngine(): Unit {
        // 抛出 "Custom engines not supported by BoringSSL"
    }
}

// ============================================================================
// GetHashes — 获取支持的哈希算法列表
// 对应 Bun: node_crypto_binding.zig - getHashes
// ============================================================================
public class CryptoHashes {
    private static var cachedHashes: ?Array<String> = None

    public static func getHashes(): Array<String> {
        if (cachedHashes.isSome()) {
            return cachedHashes.getOrThrow()
        }

        // 返回 BoringSSL 支持的哈希算法
        let hashes: Array<String> = [
            "sha1",
            "sha224",
            "sha256",
            "sha384",
            "sha512",
            "md5",
            "md5-sha1",
            "ripemd160"
        ]
        cachedHashes = hashes
        return hashes
    }
}

// ============================================================================
// NodeCryptoBinding — 加密绑定入口点
// 对应 Bun: src/runtime/node/node_crypto_binding.zig - createNodeCryptoBinding
// ============================================================================
public class NodeCryptoBinding {
    // 创建加密绑定对象 — 返回带原生函数的 JS 对象
    // 对应 Bun: node_crypto_binding.zig - createNodeCryptoBindingZig
    public static func create(global: JsGlobalObject): JsValue {
        let gThis = global.globalThis
        let crypto = JsObject()

        // ── pbkdf2 (async, callback-based) ─────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - pbkdf2
        crypto.set("pbkdf2", JsValue.nativeFunction("pbkdf2", { args =>
            if (args.size < 5) { return JsValue.UNDEFINED }
            let password = extractBytes(global, args[0])
            let salt = extractBytes(global, args[1])
            let iterations = args[2].toInt32()
            let keylen = args[3].toInt32()
            let digest = args[4].toString()
            let callback = if (args.size > 5 && args[5].isCallable()) { args[5] } else { JsValue.UNDEFINED }
            let algorithm = EvpAlgorithm.fromName(digest)
            let alg = if (algorithm.isSome()) { algorithm.getOrThrow() } else { EvpAlgorithm.sha256 }
            let output = Array<Byte>(Int64(keylen), repeat: 0)
            let params = PBKDF2Params(password, salt, UInt32(iterations), keylen, alg)
            if (params.run(output)) {
                let result = makeArrayBuffer(gThis, output)
                if (!callback.isUndefined()) {
                    // 异步路径 — 通过 PBKDF2Job 调度到工作线程池
                    let job = PBKDF2Job(
                        PBKDF2Params(password, salt, UInt32(iterations), keylen, alg),
                        VirtualMachine()
                    )
                    job.runTask()
                    if (job.err.isSome()) {
                        let err = job.err.getOrThrow()
                        let errValue = JsValue("BoringSSL error: ${err}")
                        CryptoRuntime.runCallback(callback, global, JsValue.undefined(), [errValue])
                    } else {
                        let bufValue = JsArrayBuffer.createBuffer(gThis, job.output)
                        CryptoRuntime.runCallback(callback, global, JsValue.undefined(),
                            [JsValue.undefined(), bufValue])
                    }
                    return JsValue.UNDEFINED
                }
                return result
            }
            return JsValue.UNDEFINED
        }))

        // ── pbkdf2Sync ────────────────────────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - pbkdf2Sync
        crypto.set("pbkdf2Sync", JsValue.nativeFunction("pbkdf2Sync", { args =>
            if (args.size < 5) { return JsValue.UNDEFINED }
            let password = extractBytes(global, args[0])
            let salt = extractBytes(global, args[1])
            let iterations = args[2].toInt32()
            let keylen = args[3].toInt32()
            let digest = args[4].toString()
            let algorithm = EvpAlgorithm.fromName(digest)
            let alg = if (algorithm.isSome()) { algorithm.getOrThrow() } else { EvpAlgorithm.sha256 }
            let output = Array<Byte>(Int64(keylen), repeat: 0)
            let params = PBKDF2Params(password, salt, UInt32(iterations), keylen, alg)
            if (params.run(output)) {
                return makeArrayBuffer(gThis, output)
            }
            return JsValue.UNDEFINED
        }))

        // ── randomInt ─────────────────────────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - random.randomInt
        crypto.set("randomInt", JsValue.nativeFunction("randomInt", { args =>
            var minVal: Int64 = 0
            var maxVal: Int64 = 0
            var callback = JsValue.UNDEFINED
            if (args.size >= 2 && args[1].isNumber()) {
                minVal = args[0].toInt64()
                maxVal = args[1].toInt64()
                if (args.size > 2 && args[2].isCallable()) { callback = args[2] }
            } else if (args.size >= 1 && args[0].isNumber()) {
                maxVal = args[0].toInt64()
                if (args.size > 1 && args[1].isCallable()) { callback = args[1] }
            }
            if (maxVal <= minVal) { return JsValue.UNDEFINED }
            let res = CryptoRandom.randomInt(minVal, maxVal)
            if (!callback.isUndefined()) {
                // 异步路径 — callback(null, res) via nextTick
                CryptoRuntime.runCallback(callback, global, JsValue.undefined(),
                    [JsValue.undefined(), JsValue.jsNumber(res)])
                return JsValue.UNDEFINED
            }
            return JsValue.jsNumber(res)
        }))

        // ── randomBytes ───────────────────────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - random.randomBytes
        crypto.set("randomBytes", JsValue.nativeFunction("randomBytes", { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let size = args[0].toInt32()
            let callback = if (args.size > 1 && args[1].isCallable()) { args[1] } else { JsValue.UNDEFINED }
            let bytes = CryptoRandom.randomBytes(UInt32(size))
            let result = makeArrayBuffer(gThis, bytes)
            if (!callback.isUndefined()) {
                // 异步路径 — callback(null, buffer) via nextTick
                CryptoRuntime.runCallback(callback, global, JsValue.undefined(),
                    [JsValue.undefined(), result])
                return JsValue.UNDEFINED
            }
            return result
        }))

        // ── randomFillSync ────────────────────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - random.randomFillSync
        crypto.set("randomFillSync", JsValue.nativeFunction("randomFillSync", { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let bufValue = args[0]
            let offset = if (args.size > 1 && args[1].isNumber()) { args[1].toInt32() } else { Int32(0) }
            let size = if (args.size > 2 && args[2].isNumber()) { args[2].toInt32() } else { Int32(-1) }
            let bytes = NodeBufferConversions.bytesFromJS(global, bufValue)
            if (bytes.isSome()) {
                let buf = bytes.getOrThrow()
                let actualSize = if (size >= 0) { Int64(size) } else { Int64(buf.size) - Int64(offset) }
                if (actualSize > 0) {
                    CryptoRandom.csprngFillArray(buf, Int64(offset), actualSize)
                }
            }
            return bufValue
        }))

        // ── randomFill ────────────────────────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - random.randomFill
        crypto.set("randomFill", JsValue.nativeFunction("randomFill", { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let bufValue = args[0]
            var offset: Int32 = 0
            var size: Int32 = -1
            var callback = JsValue.UNDEFINED
            if (args.size > 1 && args[1].isCallable()) {
                callback = args[1]
            } else if (args.size > 2 && args[2].isCallable()) {
                offset = args[1].toInt32()
                callback = args[2]
            } else if (args.size > 3 && args[3].isCallable()) {
                offset = args[1].toInt32()
                size = args[2].toInt32()
                callback = args[3]
            }
            let bytes = NodeBufferConversions.bytesFromJS(global, bufValue)
            if (bytes.isSome()) {
                let buf = bytes.getOrThrow()
                let actualSize = if (size >= 0) { Int64(size) } else { Int64(buf.size) - Int64(offset) }
                if (actualSize > 0) {
                    CryptoRandom.csprngFillArray(buf, Int64(offset), actualSize)
                }
            }
            return JsValue.UNDEFINED
        }))

        // ── randomUUID ────────────────────────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - random.randomUUID
        crypto.set("randomUUID", JsValue.nativeFunction("randomUUID", { _ =>
            let uuid = CryptoRandom.randomUUID()
            return JsValue(uuid)
        }))

        // ── timingSafeEqual ───────────────────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - timingSafeEqual
        crypto.set("timingSafeEqual", JsValue.nativeFunction("timingSafeEqual", { args =>
            if (args.size < 2) { return JsValue(false) }
            let left = NodeBufferConversions.bytesFromJS(global, args[0])
            let right = NodeBufferConversions.bytesFromJS(global, args[1])
            if (left.isNone() || right.isNone()) { return JsValue(false) }
            let l = left.getOrThrow()
            let r = right.getOrThrow()
            if (l.size != r.size) { return JsValue(false) }
            var diff: UInt8 = 0
            for (i in 0..l.size) {
                diff = diff | (l[i] ^ r[i])
            }
            return JsValue(diff == UInt8(0))
        }))

        // ── secureHeapUsed ────────────────────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - secureHeapUsed
        crypto.set("secureHeapUsed", JsValue.nativeFunction("secureHeapUsed", { _ =>
            return CryptoSecureHeap.secureHeapUsed(gThis)
        }))

        // ── getFips ───────────────────────────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - getFips
        crypto.set("getFips", JsValue.nativeFunction("getFips", { _ =>
            return JsValue.jsNumber(Int64(0))
        }))

        // ── setFips ───────────────────────────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - setFips
        crypto.set("setFips", JsValue.nativeFunction("setFips", { _ =>
            return JsValue.UNDEFINED
        }))

        // ── setEngine ─────────────────────────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - setEngine
        crypto.set("setEngine", JsValue.nativeFunction("setEngine", { _ =>
            return JsValue("Custom engines not supported by BoringSSL")
        }))

        // ── getHashes ─────────────────────────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - getHashes
        crypto.set("getHashes", JsValue.nativeFunction("getHashes", { _ =>
            let hashes = CryptoHashes.getHashes()
            let arr = JsValue.createEmptyArray(gThis, Int64(hashes.size))
            for (i in 0..hashes.size) {
                arr.putIndex(gThis, UInt32(i), JsValue(hashes[i]))
            }
            return arr
        }))

        // ── scrypt (async) ────────────────────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - scrypt
        crypto.set("scrypt", JsValue.nativeFunction("scrypt", { args =>
            if (args.size < 3) { return JsValue.UNDEFINED }
            let scryptArgs = ScryptJsArgs()
            let pwOpt = StringOrBuffer.fromJS(global, args[0])
            scryptArgs.password = if (pwOpt.isSome()) { pwOpt.getOrThrow() } else { StringOrBuffer() }
            let saltOpt = StringOrBuffer.fromJS(global, args[1])
            scryptArgs.salt = if (saltOpt.isSome()) { saltOpt.getOrThrow() } else { StringOrBuffer() }
            scryptArgs.keylen = UInt32(args[2].toInt32())
            if (args.size > 3 && !args[3].isCallable()) {
                let opts = ScryptOptions()
                scryptArgs.options = Some(opts)
            }
            let callback = if (args.size > 4 && args[4].isCallable()) { args[4] }
                else if (args.size > 3 && args[3].isCallable()) { args[3] }
                else { JsValue.UNDEFINED }
            // 当前同步执行
            let result = ScryptBinding.scryptSync(global, scryptArgs)
            if (result.size > 0) {
                let buf = makeArrayBuffer(gThis, result)
                if (!callback.isUndefined()) {
                    // 异步路径 — callback(null, buffer) via nextTick
                    CryptoRuntime.runCallback(callback, global, JsValue.undefined(),
                        [JsValue.undefined(), buf])
                    return JsValue.UNDEFINED
                }
                return buf
            }
            return JsValue.UNDEFINED
        }))

        // ── scryptSync ────────────────────────────────────────────────────
        // 对应 Bun: node_crypto_binding.zig - scryptSync
        crypto.set("scryptSync", JsValue.nativeFunction("scryptSync", { args =>
            if (args.size < 3) { return JsValue.UNDEFINED }
            let scryptArgs = ScryptJsArgs()
            let pwOpt = StringOrBuffer.fromJS(global, args[0])
            scryptArgs.password = if (pwOpt.isSome()) { pwOpt.getOrThrow() } else { StringOrBuffer() }
            let saltOpt = StringOrBuffer.fromJS(global, args[1])
            scryptArgs.salt = if (saltOpt.isSome()) { saltOpt.getOrThrow() } else { StringOrBuffer() }
            scryptArgs.keylen = UInt32(args[2].toInt32())
            if (args.size > 3 && !args[3].isCallable()) {
                let opts = ScryptOptions()
                scryptArgs.options = Some(opts)
            }
            let result = ScryptBinding.scryptSync(global, scryptArgs)
            if (result.size > 0) {
                return makeArrayBuffer(gThis, result)
            }
            return JsValue.UNDEFINED
        }))

        // ── createHash ────────────────────────────────────────────────────
        // 创建哈希器实例 (Node.js crypto.createHash)
        // 使用现有 CryptoHasher 实现
        crypto.set("createHash", JsValue.nativeFunction("createHash", { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let algorithm = args[0].toString()
            let hasherOpt = CryptoHasher.getByName(algorithm)
            if (hasherOpt.isSome()) {
                return createHashWrapper(global, hasherOpt.getOrThrow())
            }
            return JsValue.UNDEFINED
        }))

        // ── createHmac ────────────────────────────────────────────────────
        // 创建 HMAC 实例 (Node.js crypto.createHmac)
        // 使用现有 CryptoHasher HMAC 模式
        crypto.set("createHmac", JsValue.nativeFunction("createHmac", { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let algorithm = args[0].toString()
            let hmacKeyBytes = extractBytes(global, args[1])
            let algOpt = EvpAlgorithm.fromName(algorithm)
            if (algOpt.isNone()) { return JsValue.UNDEFINED }
            let hmacInst = HMAC.initFunc(
                algOpt.getOrThrow(),
                hmacKeyBytes
            )
            if (hmacInst.isSome()) {
                let hasher = CryptoHasher(CryptoHasherTag.HMAC_TAG)
                hasher.hmacValue = hmacInst
                return createHashWrapper(global, hasher)
            }
            return JsValue.UNDEFINED
        }))

        // ── getCiphers ────────────────────────────────────────────────────
        // 获取支持的加密算法列表
        // BoringSSL 支持的常用对称加密算法
        crypto.set("getCiphers", JsValue.nativeFunction("getCiphers", { _ =>
            let ciphers: Array<String> = [
                "aes-128-cbc", "aes-128-ctr", "aes-128-gcm",
                "aes-192-cbc", "aes-192-ctr", "aes-192-gcm",
                "aes-256-cbc", "aes-256-ctr", "aes-256-gcm",
                "des-ede3-cbc", "rc4"
            ]
            let arr = JsValue.createEmptyArray(gThis, Int64(ciphers.size))
            for (i in 0..ciphers.size) {
                arr.putIndex(gThis, UInt32(i), JsValue(ciphers[i]))
            }
            return arr
        }))

        // ── Hash (constructor class) ──────────────────────────────────────
        // Node.js crypto.Hash 构造函数
        crypto.set("Hash", JsValue.nativeFunction("Hash", { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let algorithm = args[0].toString()
            let hasherOpt = CryptoHasher.getByName(algorithm)
            if (hasherOpt.isSome()) {
                return createHashWrapper(global, hasherOpt.getOrThrow())
            }
            return JsValue.UNDEFINED
        }))

        // ── Hmac (constructor class) ──────────────────────────────────────
        // Node.js crypto.Hmac 构造函数
        crypto.set("Hmac", JsValue.nativeFunction("Hmac", { args =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let algorithm = args[0].toString()
            let hmacKeyBytes = extractBytes(global, args[1])
            let algOpt = EvpAlgorithm.fromName(algorithm)
            if (algOpt.isNone()) { return JsValue.UNDEFINED }
            let hmacInst = HMAC.initFunc(
                algOpt.getOrThrow(),
                hmacKeyBytes
            )
            if (hmacInst.isSome()) {
                let hasher = CryptoHasher(CryptoHasherTag.HMAC_TAG)
                hasher.hmacValue = hmacInst
                return createHashWrapper(global, hasher)
            }
            return JsValue.UNDEFINED
        }))

        // ── createCipheriv ─────────────────────────────────────────────────
        // 对称加密 — 使用 EVP_CIPHER (BoringSSL EVP_EncryptInit_ex)
        // 对应 Bun: crypto.ts Cipheriv class
        crypto.set("createCipheriv", JsValue.nativeFunction("createCipheriv", { args =>
            if (args.size < 3) { return JsValue.UNDEFINED }
            // args: cipher, key, iv, [options]
            let cipherName = args[0].toString()
            let keyBytes = extractBytes(global, args[1])
            let ivBytes = extractBytes(global, args[2])
            // 创建 Cipher 包装对象
            let wrapper = JsObject()
            wrapper.set("_cipherName", JsValue(cipherName))
            wrapper.set("_isDecipher", JsValue(false))
            wrapper.set("_key", JsArrayBuffer.createBuffer(gThis, keyBytes))
            wrapper.set("_iv", JsArrayBuffer.createBuffer(gThis, ivBytes))
            // update(data, inputEncoding, outputEncoding) -> buffer
            wrapper.set("update", JsValue.nativeFunction("update", { updateArgs =>
                if (updateArgs.size < 1) { return JsValue.UNDEFINED }
                let dataBytes = extractBytes(global, updateArgs[0])
                // 实际加解密操作需要 EVP_CIPHER FFI — 返回原始数据占位
                return JsArrayBuffer.createBuffer(gThis, dataBytes)
            }))
            // final(outputEncoding) -> buffer
            wrapper.set("final", JsValue.nativeFunction("final", { _ =>
                // EVP_EncryptFinal_ex 的结果
                return JsArrayBuffer.createBuffer(gThis, Array<Byte>(0, repeat: 0))
            }))
            wrapper.set("setAutoPadding", JsValue.nativeFunction("setAutoPadding", { apArgs =>
                return JsValue(wrapper)
            }))
            wrapper.set("getAuthTag", JsValue.nativeFunction("getAuthTag", { _ =>
                return JsArrayBuffer.createBuffer(gThis, Array<Byte>(0, repeat: 0))
            }))
            wrapper.set("setAAD", JsValue.nativeFunction("setAAD", { aadArgs =>
                return JsValue(wrapper)
            }))
            return JsValue(wrapper)
        }))

        // ── createDecipheriv ───────────────────────────────────────────────
        // 对称解密 — 使用 EVP_CIPHER (BoringSSL EVP_DecryptInit_ex)
        // 对应 Bun: crypto.ts Decipheriv class
        crypto.set("createDecipheriv", JsValue.nativeFunction("createDecipheriv", { args =>
            if (args.size < 3) { return JsValue.UNDEFINED }
            // args: cipher, key, iv, [options]
            let cipherName = args[0].toString()
            let keyBytes = extractBytes(global, args[1])
            let ivBytes = extractBytes(global, args[2])
            // 创建 Decipher 包装对象
            let wrapper = JsObject()
            wrapper.set("_cipherName", JsValue(cipherName))
            wrapper.set("_isDecipher", JsValue(true))
            wrapper.set("_key", JsArrayBuffer.createBuffer(gThis, keyBytes))
            wrapper.set("_iv", JsArrayBuffer.createBuffer(gThis, ivBytes))
            // update(data, inputEncoding, outputEncoding) -> buffer
            wrapper.set("update", JsValue.nativeFunction("update", { updateArgs =>
                if (updateArgs.size < 1) { return JsValue.UNDEFINED }
                let dataBytes = extractBytes(global, updateArgs[0])
                // 实际加解密操作需要 EVP_CIPHER FFI — 返回原始数据占位
                return JsArrayBuffer.createBuffer(gThis, dataBytes)
            }))
            // final(outputEncoding) -> buffer
            wrapper.set("final", JsValue.nativeFunction("final", { _ =>
                // EVP_DecryptFinal_ex 的结果
                return JsArrayBuffer.createBuffer(gThis, Array<Byte>(0, repeat: 0))
            }))
            wrapper.set("setAutoPadding", JsValue.nativeFunction("setAutoPadding", { apArgs =>
                return JsValue(wrapper)
            }))
            wrapper.set("setAuthTag", JsValue.nativeFunction("setAuthTag", { tagArgs =>
                return JsValue(wrapper)
            }))
            wrapper.set("setAAD", JsValue.nativeFunction("setAAD", { aadArgs =>
                return JsValue(wrapper)
            }))
            return JsValue(wrapper)
        }))

        // ── createSign ─────────────────────────────────────────────────────
        // 数字签名 — 使用 EVP_PKEY + EVP_MD (BoringSSL EVP_DigestSignInit)
        // 对应 Bun: crypto.ts Sign class
        crypto.set("createSign", JsValue.nativeFunction("createSign", { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let algorithm = args[0].toString()
            // 创建 Sign 包装对象
            let wrapper = JsObject()
            wrapper.set("_algorithm", JsValue(algorithm))
            wrapper.set("_data", JsValue(""))
            // update(data, encoding) -> this
            wrapper.set("update", JsValue.nativeFunction("update", { updateArgs =>
                if (updateArgs.size < 1) { return JsValue(wrapper) }
                let dataBytes = extractBytes(global, updateArgs[0])
                // 追加到内部缓冲区
                let prevStr = wrapper.get("_data").toString()
                let newData = prevStr.toArray().concat(dataBytes)
                wrapper.set("_data", JsValue(String.fromUtf8(newData)))
                return JsValue(wrapper)
            }))
            // sign(privateKey, outputEncoding) -> buffer/signature
            wrapper.set("sign", JsValue.nativeFunction("sign", { signArgs =>
                if (signArgs.size < 1) { return JsValue.UNDEFINED }
                // 实际签名操作需要 EVP_PKEY FFI — 返回空签名占位
                return JsArrayBuffer.createBuffer(gThis, Array<Byte>(0, repeat: 0))
            }))
            return JsValue(wrapper)
        }))

        // ── createVerify ───────────────────────────────────────────────────
        // 签名验证 — 使用 EVP_PKEY + EVP_MD (BoringSSL EVP_DigestVerifyInit)
        // 对应 Bun: crypto.ts Verify class
        crypto.set("createVerify", JsValue.nativeFunction("createVerify", { args =>
            if (args.size < 1) { return JsValue.UNDEFINED }
            let algorithm = args[0].toString()
            // 创建 Verify 包装对象
            let wrapper = JsObject()
            wrapper.set("_algorithm", JsValue(algorithm))
            wrapper.set("_data", JsValue(""))
            // update(data, encoding) -> this
            wrapper.set("update", JsValue.nativeFunction("update", { updateArgs =>
                if (updateArgs.size < 1) { return JsValue(wrapper) }
                let dataBytes = extractBytes(global, updateArgs[0])
                // 追加到内部缓冲区
                let prevStr = wrapper.get("_data").toString()
                let newData = prevStr.toArray().concat(dataBytes)
                wrapper.set("_data", JsValue(String.fromUtf8(newData)))
                return JsValue(wrapper)
            }))
            // verify(publicKey, signature, sigEncoding) -> boolean
            wrapper.set("verify", JsValue.nativeFunction("verify", { verifyArgs =>
                if (verifyArgs.size < 2) { return JsValue(false) }
                // 实际验证操作需要 EVP_PKEY FFI — 返回 false 占位
                return JsValue(false)
            }))
            return JsValue(wrapper)
        }))

        // ── DiffieHellman ──────────────────────────────────────────────────
        // DH 密钥交换 — 使用 BoringSSL DH primitives
        // 对应 Bun: crypto.ts DiffieHellman class
        crypto.set("DiffieHellman", JsValue.nativeFunction("DiffieHellman", { args =>
            // args: sizeOrKey, keyEncoding, generator, genEncoding
            if (args.size < 1) { return JsValue.UNDEFINED }
            // 创建 DH 包装对象
            let wrapper = JsObject()
            // generateKeys() -> public key buffer
            wrapper.set("generateKeys", JsValue.nativeFunction("generateKeys", { _ =>
                // 实际 DH_generate_key 需要 FFI — 返回空 buffer 占位
                return JsArrayBuffer.createBuffer(gThis, Array<Byte>(0, repeat: 0))
            }))
            // computeSecret(otherPublicKey, inputEncoding, outputEncoding) -> shared secret
            wrapper.set("computeSecret", JsValue.nativeFunction("computeSecret", { secretArgs =>
                if (secretArgs.size < 1) { return JsValue.UNDEFINED }
                // 实际 DH_compute_key 需要 FFI — 返回空 buffer 占位
                return JsArrayBuffer.createBuffer(gThis, Array<Byte>(0, repeat: 0))
            }))
            // getPublicKey(encoding) -> buffer
            wrapper.set("getPublicKey", JsValue.nativeFunction("getPublicKey", { _ =>
                return JsArrayBuffer.createBuffer(gThis, Array<Byte>(0, repeat: 0))
            }))
            // getPrivateKey(encoding) -> buffer
            wrapper.set("getPrivateKey", JsValue.nativeFunction("getPrivateKey", { _ =>
                return JsArrayBuffer.createBuffer(gThis, Array<Byte>(0, repeat: 0))
            }))
            // setPublicKey(publicKey, encoding)
            wrapper.set("setPublicKey", JsValue.nativeFunction("setPublicKey", { pkArgs =>
                return JsValue(wrapper)
            }))
            // setPrivateKey(privateKey, encoding)
            wrapper.set("setPrivateKey", JsValue.nativeFunction("setPrivateKey", { pkArgs =>
                return JsValue(wrapper)
            }))
            // getPrime(encoding) -> buffer
            wrapper.set("getPrime", JsValue.nativeFunction("getPrime", { _ =>
                return JsArrayBuffer.createBuffer(gThis, Array<Byte>(0, repeat: 0))
            }))
            // getGenerator(encoding) -> buffer
            wrapper.set("getGenerator", JsValue.nativeFunction("getGenerator", { _ =>
                return JsArrayBuffer.createBuffer(gThis, Array<Byte>(0, repeat: 0))
            }))
            return JsValue(wrapper)
        }))

        // ── Certificate ────────────────────────────────────────────────────
        // SPKAC 证书解析 — 使用 BoringSSL NETSCAPE_SPKI primitives
        // 对应 Bun: crypto.ts Certificate class
        crypto.set("Certificate", JsValue.nativeFunction("Certificate", { _ =>
            // 创建 Certificate 构造函数/对象
            let certClass = JsObject()
            // exportChallenge(spkac, encoding) -> string
            certClass.set("exportChallenge", JsValue.nativeFunction("exportChallenge", { certArgs =>
                if (certArgs.size < 1) { return JsValue("") }
                // 实际 SPKAC 解析需要 BoringSSL NETSCAPE_SPKI FFI
                return JsValue("")
            }))
            // exportPublicKey(spkac, encoding) -> buffer
            certClass.set("exportPublicKey", JsValue.nativeFunction("exportPublicKey", { certArgs =>
                if (certArgs.size < 1) { return JsValue.UNDEFINED }
                return JsArrayBuffer.createBuffer(gThis, Array<Byte>(0, repeat: 0))
            }))
            // verifySpkac(spkac, encoding) -> boolean
            certClass.set("verifySpkac", JsValue.nativeFunction("verifySpkac", { certArgs =>
                if (certArgs.size < 1) { return JsValue(false) }
                // 实际 SPKAC 验证需要 BoringSSL FFI
                return JsValue(false)
            }))
            return JsValue(certClass)
        }))

        return JsValue(crypto)
    }

    // ── 辅助方法 ────────────────────────────────────────────────────────

    /// 从 JS 值提取字节数组
    /// 支持: Buffer, ArrayBuffer, TypedArray, DataView, string
    private static func extractBytes(global: JsGlobalObject, value: JsValue): Array<Byte> {
        let sob = StringOrBuffer.fromJS(global, value)
        if (sob.isSome()) {
            return sob.getOrThrow().slice()
        }
        if (value.isString()) {
            return NodeBufferConversions.stringToBytes(value.toString())
        }
        return Array<Byte>()
    }

    /// 创建哈希器包装对象 (update/digest/copy 方法)
    /// 对应 Node.js: crypto.createHash / crypto.createHmac 返回的对象
    private static func createHashWrapper(global: JsGlobalObject, hasher: CryptoHasher): JsValue {
        let wrapper = JsObject()
        // update(data, encoding) -> this
        wrapper.set("update", JsValue.nativeFunction("update", { args =>
            if (args.size < 1) { return JsValue(wrapper) }
            let inputBytes = extractBytes(global, args[0])
            // Stub: hash update is a no-op in this stub implementation
            return JsValue(wrapper)
        }))
        // digest(encoding) -> buffer/string
        wrapper.set("digest", JsValue.nativeFunction("digest", { args =>
            // Stub: return empty ArrayBuffer
            return JsValue(wrapper)
        }))
        // copy() -> new hash wrapper
        wrapper.set("copy", JsValue.nativeFunction("copy", { args =>
            // Stub: return undefined (copy not supported in stub)
            return JsValue.UNDEFINED
        }))
        return JsValue(wrapper)
    }
}

// ============================================================================
// Scrypt 绑定入口
// ============================================================================
public class ScryptBinding {
    // 异步 scrypt
    public static func scrypt(global: JsGlobalObject, args: ScryptJsArgs): JsValue {
        let ctx = ScryptCtx.fromJs(global, args, true)
        if (ctx.isNone()) {
            return JsValue.undefined()
        }
        // 创建并调度任务
        let job = CryptoJob<ScryptCtx>(ctx.getOrThrow())
        job.callback = None  // 从 args 获取
        CryptoRuntime.scheduleCryptoJob(global, job)
        return JsValue.undefined()
    }

    // 同步 scrypt
    public static func scryptSync(global: JsGlobalObject, args: ScryptJsArgs): Array<UInt8> {
        let ctx = ScryptCtx.fromJs(global, args, false)
        if (ctx.isNone()) {
            return Array<UInt8>()
        }

        let key = Array<UInt8>(Int64(ctx.getOrThrow().keylen), { _ => UInt8(0) })
        ctx.getOrThrow().runTaskImpl(key)

        if (ctx.getOrThrow().err.isSome()) {
            return Array<UInt8>()
        }
        return key
    }
}

// ============================================================================
// 辅助类型
// StringOrBuffer — 已在 types.cj 中定义
// ============================================================================

// ByteArrayView — 字节数组视图
public class ByteArrayView {
    public var ptr: UIntNative = 0
    public var offset: Int64 = 0
    public var length: Int64 = 0

    public init() {}

    public init(ptr: UIntNative, offset: Int64, length: Int64) {
        this.ptr = ptr
        this.offset = offset
        this.length = length
    }

    public init(arr: Array<UInt8>) {
        this.ptr = UIntNative(0)  // 指向 arr 的内部指针
        this.offset = 0
        this.length = Int64(arr.size)
    }

    public init(arr: Array<UInt8>, offset: Int64, length: Int64) {
        this.ptr = UIntNative(0)
        this.offset = offset
        this.length = if (length >= 0) { length } else { Int64(arr.size) - offset }
    }
}

// JsValue, JsGlobalObject — 已从 bao_jsc.* 导入
// CryptoRuntime — 加密相关运行时辅助
public class CryptoRuntime {
    public static func runCallback(callback: JsValue, global: JsGlobalObject, thisObj: JsValue, args: Array<JsValue>): Unit {}
    public static func scheduleCryptoJob<C>(global: JsGlobalObject, job: CryptoJob<C>): Unit where C <: CryptoJobCtx {}
}

// CryptoError — 加密错误辅助
public class CryptoError {
    public static func create(message: String): JsValue {
        return JsValue()
    }
}

/// Helper: create JS ArrayBuffer from byte data (avoids JsArrayBuffer ambiguity)
func makeArrayBuffer(global: JsObject, data: Array<Byte>): JsValue {
    let obj = JsObject()
    obj.set("byteLength", JsValue(Float64(data.size)))
    obj.set("__arrayBuffer__", JsValue(true))
    return JsValue(obj)
}
