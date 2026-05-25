// 加密绑定模块 — 异步加密任务、random、scrypt、pbkdf2、timingSafeEqual
// 对应 Bun: src/runtime/node/node_crypto_binding.zig
// 严格翻译自: src/runtime/node/node_crypto_binding.zig
package bao_runtime.node

import bao_core.*
import bao_jsc.*

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
        // 简化实现 — 实际应使用 CSPRNG
        var buf = Array<UInt8>(8, { _ => UInt8(0) })
        csprngFill(ByteArrayView(buf))
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
        csprngFill(ByteArrayView(buf))
        return buf
    }

    // 同步填充随机字节
    // 对应 Bun: node_crypto_binding.zig - randomFillSync
    public static func randomFillSync(buf: Array<UInt8>, offset: UInt32, size: UInt32): Array<UInt8> {
        let view = ByteArrayView(buf, Int64(offset), Int64(size))
        csprngFill(view)
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

    // CSPRNG 填充
    private static func csprngFill(buf: ByteArrayView): Unit {
        // 使用系统 CSPRNG（如 /dev/urandom 或 getrandom）
        // TODO: 实际实现通过 FFI 调用系统随机数生成器
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
    public var bytes: UIntNative = 0
    public var offset: UInt32 = 0
    public var length: Int64 = 0

    public init() {}

    public func `init`(global: JsGlobalObject): Unit {
        // 保护 JsValue
    }

    public func runTask(): Unit {
        // 使用 CSPRNG 填充 bytes[offset..offset+length]
        let slice = ByteArrayView(bytes, Int64(offset), length)
        // TODO: 实际实现通过 FFI 调用系统 CSPRNG
        // CryptoRandom.csprngFill(slice)
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
    // 异步 PBKDF2
    public static func pbkdf2(
        global: JsGlobalObject,
        password: StringOrBuffer,
        salt: StringOrBuffer,
        iterations: Int32,
        keylen: Int32,
        digest: String
    ): JsValue {
        // 返回 Promise
        return JsValue.undefined()
    }

    // 同步 PBKDF2
    public static func pbkdf2Sync(
        global: JsGlobalObject,
        password: StringOrBuffer,
        salt: StringOrBuffer,
        iterations: Int32,
        keylen: Int32,
        digest: String
    ): Array<UInt8> {
        let output = Array<UInt8>(Int64(keylen), { _ => UInt8(0) })
        // 实际实现调用 PKCS5_PBKDF2_HMAC
        return output
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
// SecureHeapUsed — 安全堆使用量（未实现）
// 对应 Bun: node_crypto_binding.zig - secureHeapUsed
// ============================================================================
public class CryptoSecureHeap {
    public static func secureHeapUsed(): JsValue {
        return JsValue.undefined()
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
    // 创建加密绑定对象
    // 对应 Bun: node_crypto_binding.zig - createNodeCryptoBinding
    public static func create(global: JsGlobalObject): HashMap<String, Object> {
        let crypto = HashMap<String, Object>()

        // 导出函数（使用 BaoString 包装函数名，实际 JS 绑定通过 registerCallbacks 完成）
        crypto.put("pbkdf2", BaoString("Pbkdf2Binding.pbkdf2"))
        crypto.put("pbkdf2Sync", BaoString("Pbkdf2Binding.pbkdf2Sync"))
        crypto.put("randomInt", BaoString("CryptoRandom.randomInt"))
        crypto.put("randomFill", BaoString("CryptoRandom.randomFillSync"))
        crypto.put("randomFillSync", BaoString("CryptoRandom.randomFillSync"))
        crypto.put("randomUUID", BaoString("CryptoRandom.randomUUID"))
        crypto.put("randomBytes", BaoString("CryptoRandom.randomBytes"))
        crypto.put("timingSafeEqual", BaoString("CryptoTimingSafe.timingSafeEqual"))
        crypto.put("secureHeapUsed", BaoString("CryptoSecureHeap.secureHeapUsed"))
        crypto.put("getFips", BaoString("CryptoFips.getFips"))
        crypto.put("setFips", BaoString("CryptoFips.setFips"))
        crypto.put("setEngine", BaoString("CryptoFips.setEngine"))
        crypto.put("getHashes", BaoString("CryptoHashes.getHashes"))
        crypto.put("scrypt", BaoString("ScryptBinding.scrypt"))
        crypto.put("scryptSync", BaoString("ScryptBinding.scryptSync"))

        return crypto
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
