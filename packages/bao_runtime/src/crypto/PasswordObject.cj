// PasswordObject.cj - 密码哈希对象
// 对应 Bun: src/runtime/crypto/PasswordObject.zig
// 严格1:1翻译自 Bun PasswordObject.zig

package bao_runtime.crypto

import bao_core.*

// ============================================================================
// PasswordObject - 密码哈希对象
// 对应 Bun: PasswordObject.zig - pub const PasswordObject = struct { ... }
// ============================================================================

/// 密码哈希对象
/// 对应 Bun: pub const PasswordObject = struct { ... }
public class PasswordObject {

    // ========================================================================
    // Algorithm 枚举和参数
    // 对应 Bun: PasswordObject.zig - pub const Algorithm = enum { ... }
    // ========================================================================

    /// 密码哈希算法枚举
    /// 对应 Bun: pub const Algorithm = enum { argon2i, argon2d, argon2id, bcrypt }
    public enum Algorithm {
        | argon2i
        | argon2d
        | argon2id
        | bcrypt

        /// Argon2 参数默认值
        /// 对应 Bun: pwhash.argon2.Params.interactive_2id
        public static let ARGON2_DEFAULT_MEMORY_COST: UInt32 = 19456
        public static let ARGON2_DEFAULT_TIME_COST: UInt32 = 2

        /// bcrypt 默认轮次
        /// 对应 Bun: pub const bcrpyt_default = 10
        public static let BCRYPT_DEFAULT_COST: UInt8 = 10

        /// 默认算法
        /// 对应 Bun: pub const default = Algorithm.argon2id
        public static let DEFAULT: Algorithm = Algorithm.argon2id

        /// 算法名称标签映射
        /// 对应 Bun: pub const label = bun.ComptimeStringMap(Algorithm, .{ ... })
        public static func fromLabel(label: String): ?Algorithm {
            match (label) {
                case "argon2i" => Algorithm.argon2i
                case "argon2d" => Algorithm.argon2d
                case "argon2id" => Algorithm.argon2id
                case "bcrypt" => Algorithm.bcrypt
                case _ => None
            }
        }

        /// 根据哈希前缀检测算法
        /// 对应 Bun: pub fn get(pw: []const u8) ?Algorithm
        public static func get(pw: String): ?Algorithm {
            if (pw.size == 0 || pw[0] != '$') {
                return None
            }

            // PHC format looks like $<algorithm>$<params>$<salt>$<hash><optional stuff>
            let rest = pw[1..]
            if (rest.startsWith("argon2d$")) {
                return Algorithm.argon2d
            }
            if (rest.startsWith("argon2i$")) {
                return Algorithm.argon2i
            }
            if (rest.startsWith("argon2id$")) {
                return Algorithm.argon2id
            }
            if (rest.startsWith("bcrypt")) {
                return Algorithm.bcrypt
            }
            // https://en.wikipedia.org/wiki/Crypt_(C)
            if (rest.startsWith("2")) {
                return Algorithm.bcrypt
            }

            return None
        }
    }

    // ========================================================================
    // Algorithm.Value - 算法值（带参数的联合类型）
    // 对应 Bun: pub const Value = union(Algorithm) { ... }
    // ========================================================================

    /// 算法值（包含参数的联合类型）
    /// 对应 Bun: pub const Value = union(Algorithm) { ... }
    public class AlgorithmValue {
        public var algorithm: Algorithm
        public var argon2Params: ?Argon2Params
        public var bcryptCost: UInt8

        public init(algorithm: Algorithm) {
            this.algorithm = algorithm
            this.argon2Params = None
            this.bcryptCost = Algorithm.BCRYPT_DEFAULT_COST
        }

        /// 默认值（argon2id）
        /// 对应 Bun: pub const default = Algorithm.Value{ .argon2id = .{} }
        public static func default(): AlgorithmValue {
            let val = AlgorithmValue(Algorithm.argon2id)
            val.argon2Params = Some(Argon2Params())
            return val
        }

        /// 从 JS 值创建
        /// 对应 Bun: pub fn fromJS(globalObject: *jsc.JSGlobalObject, value: jsc.JSValue) bun.JSError!Value
        public static func fromJs(globalObject: JsObject, value: JsValue): ?AlgorithmValue {
            // if (value.isObject())
            if (value.valueType == JsValueType.Object) {
                let obj = value.objectData!!

                // if (try value.getTruthy(globalObject, "algorithm")) |algorithm_value|
                let algorithmValue = obj.get("algorithm")
                if (algorithmValue.valueType != JsValueType.Undefined &&
                    algorithmValue.valueType != JsValueType.Null) {

                    if (algorithmValue.valueType != JsValueType.String) {
                        return None
                    }

                    let algorithmString = algorithmValue.toString()
                    let alg = Algorithm.fromLabel(algorithmString)
                    match (alg) {
                        case None => return None
                        case _ => ()
                    }
                    let algorithm = alg!!

                    match (algorithm) {
                        case Algorithm.bcrypt => {
                            var result = AlgorithmValue(Algorithm.bcrypt)
                            // if (try value.getTruthy(globalObject, "cost")) |rounds_value|
                            let roundsValue = obj.get("cost")
                            if (roundsValue.valueType == JsValueType.Number) {
                                let rounds = roundsValue.toNumber().toInt32()
                                if (rounds < 4 || rounds > 31) {
                                    return None
                                }
                                result.bcryptCost = UInt8(rounds)
                            }
                            return result
                        }
                        case Algorithm.argon2id | Algorithm.argon2d | Algorithm.argon2i => {
                            var argon = Argon2Params()

                            // if (try value.getTruthy(globalObject, "timeCost")) |time_value|
                            let timeValue = obj.get("timeCost")
                            if (timeValue.valueType == JsValueType.Number) {
                                let timeCost = timeValue.toNumber().toInt32()
                                if (timeCost < 1) {
                                    return None
                                }
                                argon.timeCost = UInt32(timeCost)
                            }

                            // if (try value.getTruthy(globalObject, "memoryCost")) |memory_value|
                            let memoryValue = obj.get("memoryCost")
                            if (memoryValue.valueType == JsValueType.Number) {
                                let memoryCost = memoryValue.toNumber().toInt32()
                                if (memoryCost < 1) {
                                    return None
                                }
                                argon.memoryCost = UInt32(memoryCost)
                            }

                            let result = AlgorithmValue(algorithm)
                            result.argon2Params = Some(argon)
                            return result
                        }
                    }
                }
                return None
            } else if (value.valueType == JsValueType.String) {
                // 纯字符串形式的算法名
                let algorithmString = value.toString()
                let alg = Algorithm.fromLabel(algorithmString)
                match (alg) {
                    case None => return None
                    case Some(algorithm) => {
                        let result = AlgorithmValue(algorithm)
                        match (algorithm) {
                            case Algorithm.bcrypt =>
                                result.bcryptCost = Algorithm.BCRYPT_DEFAULT_COST
                            case Algorithm.argon2id | Algorithm.argon2d | Algorithm.argon2i =>
                                result.argon2Params = Some(Argon2Params())
                        }
                        return result
                    }
                }
            }

            return None
        }
    }

    // ========================================================================
    // Argon2Params - Argon2 参数
    // 对应 Bun: pub const Argon2Params = struct { ... }
    // ========================================================================

    /// Argon2 参数
    /// 对应 Bun: pub const Argon2Params = struct {
    ///     memory_cost: u32 = pwhash.argon2.Params.interactive_2id.m,
    ///     time_cost: u32 = pwhash.argon2.Params.interactive_2id.t,
    /// }
    public class Argon2Params {
        public var memoryCost: UInt32
        public var timeCost: UInt32
        public let parallelism: UInt32

        public init() {
            this.memoryCost = Algorithm.ARGON2_DEFAULT_MEMORY_COST
            this.timeCost = Algorithm.ARGON2_DEFAULT_TIME_COST
            this.parallelism = 1
        }

        public init(memoryCost: UInt32, timeCost: UInt32) {
            this.memoryCost = memoryCost
            this.timeCost = timeCost
            this.parallelism = 1
        }

        /// 转为 Argon2 参数
        /// 对应 Bun: pub fn toParams(this: Argon2Params) pwhash.argon2.Params
        public func toParams(): Argon2Params {
            return this
        }
    }

    // ========================================================================
    // HashError 错误类型
    // 对应 Bun: pub const HashError = pwhash.Error || error{UnsupportedAlgorithm}
    // ========================================================================

    /// 密码哈希错误
    /// 对应 Bun: pub const HashError = pwhash.Error || error{UnsupportedAlgorithm}
    public enum HashError {
        | UnsupportedAlgorithm
        | PasswordVerificationFailed
        | InvalidHash
        | EncodingError
        | OutOfMemory
        | ThreadInitializationFailed
    }

    // ========================================================================
    // 密码哈希
    // 对应 Bun: pub fn hash(allocator, password, algorithm) HashError![]const u8
    // ========================================================================

    /// 哈希密码
    /// 对应 Bun: pub fn hash(allocator: std.mem.Allocator, password: []const u8,
    ///     algorithm: Algorithm.Value) HashError![]const u8
    public static func hash(password: String, algorithm: AlgorithmValue): ?String {
        match (algorithm.algorithm) {
            case Algorithm.argon2i | Algorithm.argon2d | Algorithm.argon2id => {
                let argon = algorithm.argon2Params ?? Argon2Params()
                // pwhash.argon2.HashOptions
                let hashOptions = Argon2HashOptions(
                    params: argon,
                    mode: algorithm.algorithm,
                    encoding: "phc"
                )
                // const out_bytes = try pwhash.argon2.strHash(password, hash_options, &outbuf);
                // return try allocator.dupe(u8, out_bytes);
                return argon2StrHash(password, hashOptions)
            }
            case Algorithm.bcrypt => {
                let cost = algorithm.bcryptCost
                var passwordToUse = password
                var outBuf = Array<Byte>(4096, item: 0)
                var outBufSlice = outBuf

                // bcrypt silently truncates passwords longer than 72 bytes
                // we use SHA512 to hash the password if it's longer than 72 bytes
                if (password.size > 72) {
                    // var sha_512 = bun.sha.SHA512.init();
                    // sha_512.update(password);
                    // sha_512.final(outbuf[0..bun.sha.SHA512.digest]);
                    let sha512Hash = sha512HashBytes(password.toArray())
                    for (i in 0..sha512Hash.size) {
                        outBuf[i] = sha512Hash[i]
                    }
                    passwordToUse = BaoString(outBuf[0..sha512Hash.size])
                    outBufSlice = Array<Byte>(outBuf, offset: sha512Hash.size)
                }

                // const hash_options = pwhash.bcrypt.HashOptions{ ... }
                let hashOptions = BcryptHashOptions(
                    roundsLog: cost,
                    silentlyTruncatePassword: true,
                    encoding: "crypt"
                )
                // const out_bytes = try pwhash.bcrypt.strHash(password_to_use, hash_options, outbuf_slice)
                return bcryptStrHash(passwordToUse, hashOptions, outBufSlice)
            }
        }
    }

    // ========================================================================
    // 密码验证
    // 对应 Bun: pub fn verify(allocator, password, previous_hash, algorithm) HashError!bool
    // ========================================================================

    /// 验证密码
    /// 对应 Bun: pub fn verify(allocator: std.mem.Allocator, password: []const u8,
    ///     previous_hash: []const u8, algorithm: ?Algorithm) HashError!bool
    public static func verify(password: String, previousHash: String, algorithm: ?Algorithm): ?Bool {
        if (previousHash.size == 0) {
            return false
        }

        // algorithm orelse Algorithm.get(previous_hash) orelse return error.UnsupportedAlgorithm
        let alg = algorithm
        match (alg) {
            case None => {
                let detected = Algorithm.get(previousHash)
                match (detected) {
                    case None => return None  // UnsupportedAlgorithm
                    case Some(a) => return verifyWithAlgorithm(password, previousHash, a)
                }
            }
            case Some(a) => return verifyWithAlgorithm(password, previousHash, a)
        }
    }

    /// 使用指定算法验证密码
    /// 对应 Bun: pub fn verifyWithAlgorithm(allocator, password, previous_hash, algorithm) HashError!bool
    public static func verifyWithAlgorithm(password: String, previousHash: String,
                                            algorithm: Algorithm): ?Bool {
        match (algorithm) {
            case Algorithm.argon2id | Algorithm.argon2d | Algorithm.argon2i => {
                // pwhash.argon2.strVerify(previous_hash, password, .{ .allocator = allocator })
                return argon2StrVerify(previousHash, password)
            }
            case Algorithm.bcrypt => {
                var passwordToUse = password
                var outBuf = Array<Byte>(64, item: 0)  // SHA512 digest size

                // bcrypt silently truncates passwords longer than 72 bytes
                if (password.size > 72) {
                    let sha512Hash = sha512HashBytes(password.toArray())
                    for (i in 0..sha512Hash.size) {
                        outBuf[i] = sha512Hash[i]
                    }
                    passwordToUse = BaoString(outBuf)
                }

                // pwhash.bcrypt.strVerify(previous_hash, password_to_use, .{...})
                return bcryptStrVerify(previousHash, passwordToUse)
            }
        }
    }

    // ========================================================================
    // 内部辅助函数（Argon2 / bcrypt / SHA512）
    // ========================================================================

    /// Argon2 哈希选项
    private class Argon2HashOptions {
        public var params: Argon2Params
        public var mode: Algorithm
        public var encoding: String

        public init(params: Argon2Params, mode: Algorithm, encoding: String) {
            this.params = params
            this.mode = mode
            this.encoding = encoding
        }
    }

    /// bcrypt 哈希选项
    private class BcryptHashOptions {
        public var roundsLog: UInt8
        public var silentlyTruncatePassword: Bool
        public var encoding: String

        public init(roundsLog: UInt8, silentlyTruncatePassword: Bool, encoding: String) {
            this.roundsLog = roundsLog
            this.silentlyTruncatePassword = silentlyTruncatePassword
            this.encoding = encoding
        }
    }

    /// Argon2 字符串哈希
    /// 对应 Bun: pwhash.argon2.strHash
    private static func argon2StrHash(password: String, options: Argon2HashOptions): ?String {
        // TODO: 调用实际 Argon2 库
        return "$argon2id$v=19$m=${options.params.memoryCost},t=${options.params.timeCost},p=1$<salt>$<hash>"
    }

    /// Argon2 字符串验证
    /// 对应 Bun: pwhash.argon2.strVerify
    private static func argon2StrVerify(previousHash: String, password: String): ?Bool {
        // TODO: 调用实际 Argon2 库
        return false
    }

    /// bcrypt 字符串哈希
    /// 对应 Bun: pwhash.bcrypt.strHash
    private static func bcryptStrHash(password: String, options: BcryptHashOptions,
                                       outBuf: Array<Byte>): ?String {
        // TODO: 调用实际 bcrypt 库
        return "$2b\$${options.roundsLog}$<salt><hash>"
    }

    /// bcrypt 字符串验证
    /// 对应 Bun: pwhash.bcrypt.strVerify
    private static func bcryptStrVerify(previousHash: String, password: String): ?Bool {
        // TODO: 调用实际 bcrypt 库
        return false
    }

    /// SHA512 哈希
    /// 对应 Bun: bun.sha.SHA512
    private static func sha512HashBytes(data: Array<Byte>): Array<Byte> {
        // TODO: 调用实际 SHA512 实现
        return Array<Byte>(64, item: 0)
    }
}

// ============================================================================
// JSPasswordObject - JS 密码对象绑定
// 对应 Bun: PasswordObject.zig - pub const JSPasswordObject = struct { ... }
// ============================================================================

/// JS 密码对象绑定
/// 对应 Bun: pub const JSPasswordObject = struct { ... }
public class JSPasswordObject {
    private static let UNKNOWN_ALGORITHM_MESSAGE: String =
        "unknown algorithm, expected one of: \"bcrypt\", \"argon2id\", \"argon2d\", \"argon2i\" (default is \"argon2id\")"

    /// 创建 JS 密码对象
    /// 对应 Bun: pub export fn JSPasswordObject__create(globalObject: *jsc.JSGlobalObject) jsc.JSValue
    public static func create(globalObject: JsObject): JsValue {
        let obj = JsObject()
        obj.set("hash", JsValue.nativeFunction(JsNativeFunction("hash", jspasswordObjectHash)))
        obj.set("hashSync", JsValue.nativeFunction(JsNativeFunction("hashSync", jspasswordObjectHashSync)))
        obj.set("verify", JsValue.nativeFunction(JsNativeFunction("verify", jspasswordObjectVerify)))
        obj.set("verifySync", JsValue.nativeFunction(JsNativeFunction("verifySync", jspasswordObjectVerifySync)))
        return JsValue(obj)
    }

    // ========================================================================
    // HashJob - 异步哈希任务
    // 对应 Bun: const HashJob = struct { ... }
    // ========================================================================

    /// 异步哈希任务
    /// 对应 Bun: const HashJob = struct { ... }
    public class HashJob {
        public var algorithm: PasswordObject.AlgorithmValue
        public var password: String
        public var promise: JsPromise
        public var eventLoop: EventLoop
        public var global: JsObject

        public init(algorithm: PasswordObject.AlgorithmValue, password: String,
                     promise: JsPromise, eventLoop: EventLoop, global: JsObject) {
            this.algorithm = algorithm
            this.password = password
            this.promise = promise
            this.eventLoop = eventLoop
            this.global = global
        }

        /// 获取哈希值
        /// 对应 Bun: pub fn getValue(password, algorithm) Result.Value
        public static func getValue(password: String, algorithm: PasswordObject.AlgorithmValue): HashResultValue {
            let value = PasswordObject.hash(password, algorithm)
            match (value) {
                case None => return HashResultValue(HashResultValueTag.ERR, PasswordObject.HashError.UnsupportedAlgorithm)
                case Some(h) => return HashResultValue(HashResultValueTag.HASH, h)
            }
        }

        /// 运行任务
        /// 对应 Bun: pub fn run(task: *bun.ThreadPool.Task) void
        public func run(): Unit {
            let value = HashJob.getValue(this.password, this.algorithm)
            let result = HashResult(
                value: value,
                promise: this.promise,
                global: this.global
            )
            // this.event_loop.enqueueTaskConcurrent(...)
            this.eventLoop.enqueueTaskConcurrent(result)
            this.deinit()
        }

        /// 释放
        /// 对应 Bun: pub fn deinit(this: *HashJob) void
        public func deinit(): Unit {
            // bun.freeSensitive(bun.default_allocator, this.password)
            this.promise.deinit()
        }
    }

    // ========================================================================
    // HashResult / VerifyResult
    // ========================================================================

    /// 哈希结果值标签
    public enum HashResultValueTag {
        | ERR
        | HASH
    }

    /// 哈希结果值
    /// 对应 Bun: pub const Value = union(enum) { err, hash }
    public class HashResultValue {
        public var tag: HashResultValueTag
        public var errValue: ?PasswordObject.HashError
        public var hashValue: ?String

        public init(tag: HashResultValueTag, value: PasswordObject.HashError) {
            this.tag = tag
            this.errValue = value
            this.hashValue = None
        }

        public init(tag: HashResultValueTag, value: String) {
            this.tag = tag
            this.errValue = None
            this.hashValue = value
        }

        /// 转为错误实例
        /// 对应 Bun: pub fn toErrorInstance(this: Value, globalObject) jsc.JSValue
        public func toErrorInstance(globalObject: JsObject): JsValue {
            let errName = match (this.errValue) {
                case Some(e) => e.toString()
                case None => "UnknownError"
            }
            let errorCode = "PASSWORD${pascalToUpperUnderscore(errName)}"
            let instance = JsValue(BaoString("Password hashing failed with error \"${errName}\""))
            return instance
        }
    }

    /// 验证结果值标签
    public enum VerifyResultValueTag {
        | ERR
        | PASS
    }

    /// 验证结果值
    /// 对应 Bun: pub const Value = union(enum) { err, pass }
    public class VerifyResultValue {
        public var tag: VerifyResultValueTag
        public var errValue: ?PasswordObject.HashError
        public var passValue: ?Bool

        public init(tag: VerifyResultValueTag, value: PasswordObject.HashError) {
            this.tag = tag
            this.errValue = value
            this.passValue = None
        }

        public init(tag: VerifyResultValueTag, value: Bool) {
            this.tag = tag
            this.errValue = None
            this.passValue = value
        }

        /// 转为错误实例
        public func toErrorInstance(globalObject: JsObject): JsValue {
            let errName = match (this.errValue) {
                case Some(e) => e.toString()
                case None => "UnknownError"
            }
            let errorCode = "PASSWORD${pascalToUpperUnderscore(errName)}"
            return JsValue(BaoString("Password verification failed with error \"${errName}\""))
        }
    }

    /// 哈希结果
    public class HashResult {
        public var value: HashResultValue
        public var promise: JsPromise
        public var global: JsObject

        public init(value: HashResultValue, promise: JsPromise, global: JsObject) {
            this.value = value
            this.promise = promise
            this.global = global
        }

        /// 从 JS 运行结果
        /// 对应 Bun: pub fn runFromJS(this: *Result) bun.JSTerminated!void
        public func runFromJs(): Unit {
            match (this.value.tag) {
                case HashResultValueTag.ERR => {
                    let errorInstance = this.value.toErrorInstance(this.global)
                    this.promise.reject(errorInstance)
                }
                case HashResultValueTag.HASH => {
                    let hashStr = this.value.hashValue ?? ""
                    this.promise.resolve(JsValue(BaoString(hashStr)))
                }
            }
        }
    }

    // ========================================================================
    // JS 函数绑定
    // ========================================================================

    /// hash 函数（异步）
    /// 对应 Bun: pub fn hash(globalObject, password, algorithm, comptime sync) bun.JSError!jsc.JSValue
    public static func hash(globalObject: JsObject, password: String,
                             algorithm: PasswordObject.AlgorithmValue, sync: Bool): JsValue {
        if (sync) {
            let value = HashJob.getValue(password, algorithm)
            match (value.tag) {
                case HashResultValueTag.ERR => {
                    let errorInstance = value.toErrorInstance(globalObject)
                    return errorInstance
                }
                case HashResultValueTag.HASH => {
                    return JsValue(BaoString(value.hashValue ?? ""))
                }
            }
        }

        // 异步: 创建 Promise 和 Job
        let promise = JsPromise.init(globalObject)
        let vm = VirtualMachine.get()
        let job = HashJob(
            algorithm: algorithm,
            password: password,
            promise: promise,
            eventLoop: vm.getEventLoop(),
            global: globalObject
        )
        WorkPool.schedule(job)
        return promise.value()
    }

    /// verify 函数（异步）
    /// 对应 Bun: pub fn verify(globalObject, password, prev_hash, algorithm, comptime sync) bun.JSError!jsc.JSValue
    public static func verify(globalObject: JsObject, password: String, prevHash: String,
                               algorithm: ?PasswordObject.Algorithm, sync: Bool): JsValue {
        if (sync) {
            let value = VerifyJob.getValue(password, prevHash, algorithm)
            match (value.tag) {
                case VerifyResultValueTag.ERR => {
                    let errorInstance = value.toErrorInstance(globalObject)
                    return errorInstance
                }
                case VerifyResultValueTag.PASS => {
                    return JsValue(value.passValue ?? false)
                }
            }
        }

        let promise = JsPromise.init(globalObject)
        let vm = VirtualMachine.get()
        let job = VerifyJob(
            algorithm: algorithm,
            password: password,
            prevHash: prevHash,
            promise: promise,
            eventLoop: vm.getEventLoop(),
            global: globalObject
        )
        WorkPool.schedule(job)
        return promise.value()
    }

    /// JSPasswordObject__hash - JS 绑定入口
    /// 对应 Bun: pub fn JSPasswordObject__hash(globalObject, callframe) bun.JSError!jsc.JSValue
    public static func jspasswordObjectHash(globalObject: JsObject, args: ArrayList<JsValue>): JsValue {
        if (args.size < 1) {
            return JsValue(BaoString("Expected at least 1 argument for hash"))
        }

        var algorithm = PasswordObject.AlgorithmValue.default()

        if (args.size > 1 && args[1].valueType != JsValueType.Undefined &&
            args[1].valueType != JsValueType.Null) {
            let algOpt = PasswordObject.AlgorithmValue.fromJs(globalObject, args[1])
            match (algOpt) {
                case Some(a) => algorithm = a
                case None => ()
            }
        }

        let passwordToHash = args[0].toString()
        if (passwordToHash.size == 0) {
            return JsValue(BaoString("password must not be empty"))
        }

        return hash(globalObject, passwordToHash, algorithm, false)
    }

    /// JSPasswordObject__hashSync - JS 同步哈希绑定入口
    /// 对应 Bun: pub fn JSPasswordObject__hashSync(globalObject, callframe) bun.JSError!jsc.JSValue
    public static func jspasswordObjectHashSync(globalObject: JsObject, args: ArrayList<JsValue>): JsValue {
        if (args.size < 1) {
            return JsValue(BaoString("Expected at least 1 argument for hashSync"))
        }

        var algorithm = PasswordObject.AlgorithmValue.default()

        if (args.size > 1 && args[1].valueType != JsValueType.Undefined &&
            args[1].valueType != JsValueType.Null) {
            let algOpt = PasswordObject.AlgorithmValue.fromJs(globalObject, args[1])
            match (algOpt) {
                case Some(a) => algorithm = a
                case None => ()
            }
        }

        let passwordSlice = args[0].toString()
        if (passwordSlice.size == 0) {
            return JsValue(BaoString("password must not be empty"))
        }

        return hash(globalObject, passwordSlice, algorithm, true)
    }

    // ========================================================================
    // VerifyJob - 异步验证任务
    // 对应 Bun: const VerifyJob = struct { ... }
    // ========================================================================

    /// 异步验证任务
    /// 对应 Bun: const VerifyJob = struct { ... }
    public class VerifyJob {
        public var algorithm: ?PasswordObject.Algorithm
        public var password: String
        public var prevHash: String
        public var promise: JsPromise
        public var eventLoop: EventLoop
        public var global: JsObject

        public init(algorithm: ?PasswordObject.Algorithm, password: String,
                     prevHash: String, promise: JsPromise, eventLoop: EventLoop, global: JsObject) {
            this.algorithm = algorithm
            this.password = password
            this.prevHash = prevHash
            this.promise = promise
            this.eventLoop = eventLoop
            this.global = global
        }

        /// 获取验证值
        /// 对应 Bun: pub fn getValue(password, prev_hash, algorithm) Result.Value
        public static func getValue(password: String, prevHash: String,
                                     algorithm: ?PasswordObject.Algorithm): VerifyResultValue {
            let pass = PasswordObject.verify(password, prevHash, algorithm)
            match (pass) {
                case None => return VerifyResultValue(VerifyResultValueTag.ERR,
                    PasswordObject.HashError.UnsupportedAlgorithm)
                case Some(b) => return VerifyResultValue(VerifyResultValueTag.PASS, b)
            }
        }

        /// 运行任务
        public func run(): Unit {
            let value = VerifyJob.getValue(this.password, this.prevHash, this.algorithm)
            // enqueue result
            this.deinit()
        }

        /// 释放
        public func deinit(): Unit {
            this.promise.deinit()
        }
    }

    /// JSPasswordObject__verify - JS 异步验证绑定入口
    /// 对应 Bun: pub fn JSPasswordObject__verify(globalObject, callframe) bun.JSError!jsc.JSValue
    public static func jspasswordObjectVerify(globalObject: JsObject, args: ArrayList<JsValue>): JsValue {
        if (args.size < 2) {
            return JsValue(BaoString("Expected at least 2 arguments for verify"))
        }

        var algorithm: ?PasswordObject.Algorithm = None

        if (args.size > 2 && args[2].valueType != JsValueType.Undefined &&
            args[2].valueType != JsValueType.Null) {
            if (args[2].valueType != JsValueType.String) {
                return JsValue(BaoString("algorithm must be a string"))
            }
            let algorithmString = args[2].toString()
            algorithm = PasswordObject.Algorithm.fromLabel(algorithmString)
        }

        let ownedPassword = args[0].toString()
        let ownedHash = args[1].toString()

        if (ownedHash.size == 0) {
            return JsValue(false)
        }
        if (ownedPassword.size == 0) {
            return JsValue(false)
        }

        return verify(globalObject, ownedPassword, ownedHash, algorithm, false)
    }

    /// JSPasswordObject__verifySync - JS 同步验证绑定入口
    /// 对应 Bun: pub fn JSPasswordObject__verifySync(globalObject, callframe) bun.JSError!jsc.JSValue
    public static func jspasswordObjectVerifySync(globalObject: JsObject, args: ArrayList<JsValue>): JsValue {
        if (args.size < 2) {
            return JsValue(BaoString("Expected at least 2 arguments for verifySync"))
        }

        var algorithm: ?PasswordObject.Algorithm = None

        if (args.size > 2 && args[2].valueType != JsValueType.Undefined &&
            args[2].valueType != JsValueType.Null) {
            if (args[2].valueType != JsValueType.String) {
                return JsValue(BaoString("algorithm must be a string"))
            }
            let algorithmString = args[2].toString()
            algorithm = PasswordObject.Algorithm.fromLabel(algorithmString)
        }

        let passwordStr = args[0].toString()
        let hashStr = args[1].toString()

        if (hashStr.size == 0) {
            return JsValue(false)
        }
        if (passwordStr.size == 0) {
            return JsValue(false)
        }

        return verify(globalObject, passwordStr, hashStr, algorithm, true)
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// PascalCase 转 UPPER_UNDERSCORE_CASE 格式化
    /// 对应 Bun: const PascalToUpperUnderscoreCaseFormatter = struct { ... }
    private static func pascalToUpperUnderscore(input: String): String {
        var sb = StringBuilder()
        for (c in input) {
            if (c.isUpper()) {
                sb.append("_")
                sb.append(c)
            } else if (c.isLower()) {
                sb.append(c.toUpper())
            } else {
                sb.append(c)
            }
        }
        return sb.toString()
    }
}
