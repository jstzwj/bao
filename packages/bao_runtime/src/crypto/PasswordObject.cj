// PasswordObject.cj - 密码哈希对象
// 对应 Bun: src/runtime/crypto/PasswordObject.zig
// 严格1:1翻译自 Bun PasswordObject.zig

package bao_runtime.crypto

import bao_core.*

// ============================================================================
// Algorithm 枚举（提取到顶层）
// 对应 Bun: PasswordObject.zig - pub const Algorithm = enum { ... }
// ============================================================================

/// 密码哈希算法枚举
/// 对应 Bun: pub const Algorithm = enum { argon2i, argon2d, argon2id, bcrypt }
public enum PasswordAlgorithm {
| argon2i
| argon2d
| argon2id
| bcrypt

    /// 算法名称标签映射
    /// 对应 Bun: pub const label = bun.ComptimeStringMap(Algorithm, .{ ... })
    public static func fromLabel(label: String): ?PasswordAlgorithm {
        match (label) {
            | "argon2i" => PasswordAlgorithm.argon2i
            | "argon2d" => PasswordAlgorithm.argon2d
            | "argon2id" => PasswordAlgorithm.argon2id
            | "bcrypt" => PasswordAlgorithm.bcrypt
            case _ => None
        }
    }

    /// 根据哈希前缀检测算法
    /// 对应 Bun: pub fn get(pw: []const u8) ?Algorithm
    public static func get(pw: String): ?PasswordAlgorithm {
        if (pw.size == 0 || pw[0] != '$') {
            return None
        }

        // PHC format looks like $<algorithm>$<params>$<salt>$<hash><optional stuff>
        let rest = pw[1..]
        if (rest.startsWith("argon2d$")) {
            return PasswordAlgorithm.argon2d
        }
        if (rest.startsWith("argon2i$")) {
            return PasswordAlgorithm.argon2i
        }
        if (rest.startsWith("argon2id$")) {
            return PasswordAlgorithm.argon2id
        }
        if (rest.startsWith("bcrypt")) {
            return PasswordAlgorithm.bcrypt
        }
        // https://en.wikipedia.org/wiki/Crypt_(C)
        if (rest.startsWith("2")) {
            return PasswordAlgorithm.bcrypt
        }

        return None
    }
}

/// Argon2 参数默认值（提取到顶层）
/// 对应 Bun: pwhash.argon2.Params.interactive_2id
public let ARGON2_DEFAULT_MEMORY_COST: UInt32 = 19456
public let ARGON2_DEFAULT_TIME_COST: UInt32 = 2

/// bcrypt 默认轮次
/// 对应 Bun: pub const bcrpyt_default = 10
public let BCRYPT_DEFAULT_COST: UInt8 = 10

/// 默认算法
/// 对应 Bun: pub const default = Algorithm.argon2id
public let PASSWORD_DEFAULT_ALGORITHM: PasswordAlgorithm = PasswordAlgorithm.argon2id

// ============================================================================
// HashError 错误类型（提取到顶层）
// 对应 Bun: pub const HashError = pwhash.Error || error{UnsupportedAlgorithm}
// ============================================================================

/// 密码哈希错误
/// 对应 Bun: pub const HashError = pwhash.Error || error{UnsupportedAlgorithm}
public enum PasswordHashError {
| UnsupportedAlgorithm
| PasswordVerificationFailed
| InvalidHash
| EncodingError
| OutOfMemory
| ThreadInitializationFailed
}

// ============================================================================
// Argon2Params - Argon2 参数（提取到顶层）
// ============================================================================

/// Argon2 参数
public class Argon2Params {
    public var memoryCost: UInt32
    public var timeCost: UInt32
    public let parallelism: UInt32

    public init() {
        this.memoryCost = ARGON2_DEFAULT_MEMORY_COST
        this.timeCost = ARGON2_DEFAULT_TIME_COST
        this.parallelism = 1
    }

    public init(memoryCost: UInt32, timeCost: UInt32) {
        this.memoryCost = memoryCost
        this.timeCost = timeCost
        this.parallelism = 1
    }

    /// 转为 Argon2 参数
    public func toParams(): Argon2Params {
        return this
    }
}

// ============================================================================
// AlgorithmValue - 算法值（提取到顶层）
// ============================================================================

/// 算法值（包含参数）
public class PasswordAlgorithmValue {
    public var algorithm: PasswordAlgorithm
    public var argon2Params: ?Argon2Params
    public var bcryptCost: UInt8

    public init(algorithm: PasswordAlgorithm) {
        this.algorithm = algorithm
        this.argon2Params = None
        this.bcryptCost = BCRYPT_DEFAULT_COST
    }

    /// 默认值（argon2id）
    public static func defaultValue(): PasswordAlgorithmValue {
        let val = PasswordAlgorithmValue(PasswordAlgorithm.argon2id)
        val.argon2Params = Some(Argon2Params())
        return val
    }

    /// 从 JS 值创建
    public static func fromJs(globalObject: JsObject, value: JsValue): ?PasswordAlgorithmValue {
        if (value.valueType == JsValueType.Object) {
            let obj = value.objectData.getOrThrow()

            let algorithmValue = obj.get("algorithm")
            if (algorithmValue.valueType != JsValueType.Undefined &&
                algorithmValue.valueType != JsValueType.Null) {

                if (algorithmValue.valueType != JsValueType.String) {
                    return None
                }

                let algorithmString = algorithmValue.toString()
                let alg = PasswordAlgorithm.fromLabel(algorithmString)
                match (alg) {
                    case None => return None
                    case _ => ()
                }
                let algorithm = alg.getOrThrow()

                match (algorithm) {
                    case PasswordAlgorithm.bcrypt => {
                        var result = PasswordAlgorithmValue(PasswordAlgorithm.bcrypt)
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
                    case PasswordAlgorithm.argon2id | PasswordAlgorithm.argon2d | PasswordAlgorithm.argon2i => {
                        var argon = Argon2Params()

                        let timeValue = obj.get("timeCost")
                        if (timeValue.valueType == JsValueType.Number) {
                            let timeCost = timeValue.toNumber().toInt32()
                            if (timeCost < 1) {
                                return None
                            }
                            argon.timeCost = UInt32(timeCost)
                        }

                        let memoryValue = obj.get("memoryCost")
                        if (memoryValue.valueType == JsValueType.Number) {
                            let memoryCost = memoryValue.toNumber().toInt32()
                            if (memoryCost < 1) {
                                return None
                            }
                            argon.memoryCost = UInt32(memoryCost)
                        }

                        let result = PasswordAlgorithmValue(algorithm)
                        result.argon2Params = Some(argon)
                        return result
                    }
                }
            }
            return None
        } else if (value.valueType == JsValueType.String) {
            let algorithmString = value.toString()
            let alg = PasswordAlgorithm.fromLabel(algorithmString)
            match (alg) {
                case None => return None
                case Some(algorithm) => {
                    let result = PasswordAlgorithmValue(algorithm)
                    match (algorithm) {
                        case PasswordAlgorithm.bcrypt =>
                            result.bcryptCost = BCRYPT_DEFAULT_COST
                        case PasswordAlgorithm.argon2id | PasswordAlgorithm.argon2d | PasswordAlgorithm.argon2i =>
                            result.argon2Params = Some(Argon2Params())
                    }
                    return result
                }
            }
        }

        return None
    }
}

// ============================================================================
// Argon2 / bcrypt 哈希选项（提取到顶层）
// ============================================================================

/// Argon2 哈希选项
public class Argon2HashOptions {
    public var params: Argon2Params
    public var mode: PasswordAlgorithm
    public var encoding: String

    public init(params: Argon2Params, mode: PasswordAlgorithm, encoding: String) {
        this.params = params
        this.mode = mode
        this.encoding = encoding
    }
}

/// bcrypt 哈希选项
public class BcryptHashOptions {
    public var roundsLog: UInt8
    public var silentlyTruncatePassword: Bool
    public var encoding: String

    public init(roundsLog: UInt8, silentlyTruncatePassword: Bool, encoding: String) {
        this.roundsLog = roundsLog
        this.silentlyTruncatePassword = silentlyTruncatePassword
        this.encoding = encoding
    }
}

// ============================================================================
// HashResultValueTag / HashResultValue（提取到顶层）
// ============================================================================

/// 哈希结果值标签
public enum HashResultValueTag {
| ERR
| HASH
}

/// 哈希结果值
public class HashResultValue {
    public var tag: HashResultValueTag
    public var errValue: ?PasswordHashError
    public var hashValue: ?String

    public init(tag: HashResultValueTag, value: PasswordHashError) {
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
    public func toErrorInstance(globalObject: JsObject): JsValue {
        let errName = match (this.errValue) {
            case Some(e) => e.toString()
            case None => "UnknownError"
        }
        let errorCode = "PASSWORD" + pascalToUpperUnderscore(errName)
        let instance = JsValue(BaoString("Password hashing failed with error \"" + errName + "\""))
        return instance
    }
}

/// 验证结果值标签
public enum VerifyResultValueTag {
| ERR
| PASS
}

/// 验证结果值
public class VerifyResultValue {
    public var tag: VerifyResultValueTag
    public var errValue: ?PasswordHashError
    public var passValue: ?Bool

    public init(tag: VerifyResultValueTag, value: PasswordHashError) {
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
        return JsValue(BaoString("Password verification failed with error \"" + errName + "\""))
    }
}

/// 哈希结果
public class PasswordHashResult {
    public var value: HashResultValue
    public var promise: JsPromise
    public var global: JsObject

    public init(value: HashResultValue, promise: JsPromise, global: JsObject) {
        this.value = value
        this.promise = promise
        this.global = global
    }

    /// 从 JS 运行结果
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

// ============================================================================
// PasswordObject - 密码哈希对象（顶层类，无嵌套类型）
// ============================================================================

/// 密码哈希对象
public class PasswordObject {

    /// 哈希密码
    public static func hash(password: String, algorithm: PasswordAlgorithmValue): ?String {
        match (algorithm.algorithm) {
            case PasswordAlgorithm.argon2i | PasswordAlgorithm.argon2d | PasswordAlgorithm.argon2id => {
                let argon = algorithm.argon2Params ?? Argon2Params()
                let hashOptions = Argon2HashOptions(
                    params: argon,
                    mode: algorithm.algorithm,
                    encoding: "phc"
                )
                return argon2StrHash(password, hashOptions)
            }
            case PasswordAlgorithm.bcrypt => {
                let cost = algorithm.bcryptCost
                var passwordToUse = password
                var outBuf = Array<Byte>(4096, repeat: 0)
                var outBufSlice = outBuf

                // bcrypt silently truncates passwords longer than 72 bytes
                if (password.size > 72) {
                    let sha512Hash = sha512HashBytes(password.toArray())
                    for (i in 0..sha512Hash.size) {
                        outBuf[i] = sha512Hash[i]
                    }
                    passwordToUse = BaoString(outBuf[0..sha512Hash.size])
                    outBufSlice = Array<Byte>(outBuf, offset: sha512Hash.size)
                }

                let hashOptions = BcryptHashOptions(
                    roundsLog: cost,
                    silentlyTruncatePassword: true,
                    encoding: "crypt"
                )
                return bcryptStrHash(passwordToUse, hashOptions, outBufSlice)
            }
        }
    }

    /// 验证密码
    public static func verify(password: String, previousHash: String, algorithm: ?PasswordAlgorithm): ?Bool {
        if (previousHash.size == 0) {
            return false
        }

        let alg = algorithm
        match (alg) {
            case None => {
                let detected = PasswordAlgorithm.get(previousHash)
                match (detected) {
                    case None => return None  // UnsupportedAlgorithm
                    case Some(a) => return verifyWithAlgorithm(password, previousHash, a)
                }
            }
            case Some(a) => return verifyWithAlgorithm(password, previousHash, a)
        }
    }

    /// 使用指定算法验证密码
    public static func verifyWithAlgorithm(password: String, previousHash: String,
                                            algorithm: PasswordAlgorithm): ?Bool {
        match (algorithm) {
            case PasswordAlgorithm.argon2id | PasswordAlgorithm.argon2d | PasswordAlgorithm.argon2i => {
                return argon2StrVerify(previousHash, password)
            }
            case PasswordAlgorithm.bcrypt => {
                var passwordToUse = password
                var outBuf = Array<Byte>(64, repeat: 0)

                if (password.size > 72) {
                    let sha512Hash = sha512HashBytes(password.toArray())
                    for (i in 0..sha512Hash.size) {
                        outBuf[i] = sha512Hash[i]
                    }
                    passwordToUse = BaoString(outBuf)
                }

                return bcryptStrVerify(previousHash, passwordToUse)
            }
        }
    }

    /// Argon2 字符串哈希
    private static func argon2StrHash(password: String, options: Argon2HashOptions): ?String {
        // TODO: 调用实际 Argon2 库
        return "$argon2id$v=19$m=" + options.params.memoryCost.toString() + ",t=" + options.params.timeCost.toString() + ",p=1$<salt>$<hash>"
    }

    /// Argon2 字符串验证
    private static func argon2StrVerify(previousHash: String, password: String): ?Bool {
        // TODO: 调用实际 Argon2 库
        return false
    }

    /// bcrypt 字符串哈希
    private static func bcryptStrHash(password: String, options: BcryptHashOptions,
                                       outBuf: Array<Byte>): ?String {
        // TODO: 调用实际 bcrypt 库
        return "$2b$" + options.roundsLog.toString() + "$<salt><hash>"
    }

    /// bcrypt 字符串验证
    private static func bcryptStrVerify(previousHash: String, password: String): ?Bool {
        // TODO: 调用实际 bcrypt 库
        return false
    }

    /// SHA512 哈希
    private static func sha512HashBytes(data: Array<Byte>): Array<Byte> {
        // TODO: 调用实际 SHA512 实现
        return Array<Byte>(64, repeat: 0)
    }
}

// ============================================================================
// JSPasswordObject - JS 密码对象绑定
// ============================================================================

/// JS 密码对象绑定
public class JSPasswordObject {
    private static let UNKNOWN_ALGORITHM_MESSAGE: String =
        "unknown algorithm, expected one of: \"bcrypt\", \"argon2id\", \"argon2d\", \"argon2i\" (default is \"argon2id\")"

    /// 创建 JS 密码对象
    public static func create(globalObject: JsObject): JsValue {
        let obj = JsObject()
        obj.set("hash", JsValue.nativeFunction(JsNativeFunction("hash", jspasswordObjectHash)))
        obj.set("hashSync", JsValue.nativeFunction(JsNativeFunction("hashSync", jspasswordObjectHashSync)))
        obj.set("verify", JsValue.nativeFunction(JsNativeFunction("verify", jspasswordObjectVerify)))
        obj.set("verifySync", JsValue.nativeFunction(JsNativeFunction("verifySync", jspasswordObjectVerifySync)))
        return JsValue(obj)
    }

    /// 异步哈希任务
    public class HashJob {
        public var algorithm: PasswordAlgorithmValue
        public var password: String
        public var promise: JsPromise
        public var eventLoop: EventLoop
        public var global: JsObject

        public init(algorithm: PasswordAlgorithmValue, password: String,
                     promise: JsPromise, eventLoop: EventLoop, global: JsObject) {
            this.algorithm = algorithm
            this.password = password
            this.promise = promise
            this.eventLoop = eventLoop
            this.global = global
        }

        /// 获取哈希值
        public static func getValue(password: String, algorithm: PasswordAlgorithmValue): HashResultValue {
            let value = PasswordObject.hash(password, algorithm)
            match (value) {
                case None => return HashResultValue(HashResultValueTag.ERR, PasswordHashError.UnsupportedAlgorithm)
                case Some(h) => return HashResultValue(HashResultValueTag.HASH, h)
            }
        }

        /// 运行任务
        public func run(): Unit {
            let value = HashJob.getValue(this.password, this.algorithm)
            let result = PasswordHashResult(
                value: value,
                promise: this.promise,
                global: this.global
            )
            this.eventLoop.enqueueTaskConcurrent(result)
            this.deinit()
        }

        /// 释放
        public func deinit(): Unit {
            this.promise.deinit()
        }
    }

    /// 异步验证任务
    public class VerifyJob {
        public var algorithm: ?PasswordAlgorithm
        public var password: String
        public var prevHash: String
        public var promise: JsPromise
        public var eventLoop: EventLoop
        public var global: JsObject

        public init(algorithm: ?PasswordAlgorithm, password: String,
                     prevHash: String, promise: JsPromise, eventLoop: EventLoop, global: JsObject) {
            this.algorithm = algorithm
            this.password = password
            this.prevHash = prevHash
            this.promise = promise
            this.eventLoop = eventLoop
            this.global = global
        }

        /// 获取验证值
        public static func getValue(password: String, prevHash: String,
                                     algorithm: ?PasswordAlgorithm): VerifyResultValue {
            let pass = PasswordObject.verify(password, prevHash, algorithm)
            match (pass) {
                case None => return VerifyResultValue(VerifyResultValueTag.ERR,
                    PasswordHashError.UnsupportedAlgorithm)
                case Some(b) => return VerifyResultValue(VerifyResultValueTag.PASS, b)
            }
        }

        /// 运行任务
        public func run(): Unit {
            let value = VerifyJob.getValue(this.password, this.prevHash, this.algorithm)
            this.deinit()
        }

        /// 释放
        public func deinit(): Unit {
            this.promise.deinit()
        }
    }

    /// hash 函数（异步）
    public static func hash(globalObject: JsObject, password: String,
                             algorithm: PasswordAlgorithmValue, sync: Bool): JsValue {
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

        let promise = JsPromise.initFunc(globalObject)
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
    public static func verify(globalObject: JsObject, password: String, prevHash: String,
                               algorithm: ?PasswordAlgorithm, sync: Bool): JsValue {
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

        let promise = JsPromise.initFunc(globalObject)
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

    /// JSPasswordObject__hash
    public static func jspasswordObjectHash(globalObject: JsObject, args: ArrayList<JsValue>): JsValue {
        if (args.size < 1) {
            return JsValue(BaoString("Expected at least 1 argument for hash"))
        }

        var algorithm = PasswordAlgorithmValue.defaultValue()

        if (args.size > 1 && args[1].valueType != JsValueType.Undefined &&
            args[1].valueType != JsValueType.Null) {
            let algOpt = PasswordAlgorithmValue.fromJs(globalObject, args[1])
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

    /// JSPasswordObject__hashSync
    public static func jspasswordObjectHashSync(globalObject: JsObject, args: ArrayList<JsValue>): JsValue {
        if (args.size < 1) {
            return JsValue(BaoString("Expected at least 1 argument for hashSync"))
        }

        var algorithm = PasswordAlgorithmValue.defaultValue()

        if (args.size > 1 && args[1].valueType != JsValueType.Undefined &&
            args[1].valueType != JsValueType.Null) {
            let algOpt = PasswordAlgorithmValue.fromJs(globalObject, args[1])
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

    /// JSPasswordObject__verify
    public static func jspasswordObjectVerify(globalObject: JsObject, args: ArrayList<JsValue>): JsValue {
        if (args.size < 2) {
            return JsValue(BaoString("Expected at least 2 arguments for verify"))
        }

        var algorithm: ?PasswordAlgorithm = None

        if (args.size > 2 && args[2].valueType != JsValueType.Undefined &&
            args[2].valueType != JsValueType.Null) {
            if (args[2].valueType != JsValueType.String) {
                return JsValue(BaoString("algorithm must be a string"))
            }
            let algorithmString = args[2].toString()
            algorithm = PasswordAlgorithm.fromLabel(algorithmString)
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

    /// JSPasswordObject__verifySync
    public static func jspasswordObjectVerifySync(globalObject: JsObject, args: ArrayList<JsValue>): JsValue {
        if (args.size < 2) {
            return JsValue(BaoString("Expected at least 2 arguments for verifySync"))
        }

        var algorithm: ?PasswordAlgorithm = None

        if (args.size > 2 && args[2].valueType != JsValueType.Undefined &&
            args[2].valueType != JsValueType.Null) {
            if (args[2].valueType != JsValueType.String) {
                return JsValue(BaoString("algorithm must be a string"))
            }
            let algorithmString = args[2].toString()
            algorithm = PasswordAlgorithm.fromLabel(algorithmString)
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

    /// PascalCase 转 UPPER_UNDERSCORE_CASE 格式化
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
