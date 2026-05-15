// PBKDF2.cj - 基于密码的密钥派生函数2
// 对应 Bun: src/runtime/crypto/PBKDF2.zig
// 严格1:1翻译自 Bun PBKDF2.zig

package bao_runtime

import bao_core.*

// ============================================================================
// PBKDF2 - 基于密码的密钥派生函数2
// 对应 Bun: PBKDF2.zig - const PBKDF2 = @This()
// ============================================================================

/// PBKDF2 密钥派生参数
/// 对应 Bun: const PBKDF2 = @This()
///
/// password: jsc.Node.StringOrBuffer = jsc.Node.StringOrBuffer.empty,
/// salt: jsc.Node.StringOrBuffer = jsc.Node.StringOrBuffer.empty,
/// iteration_count: u32 = 1,
/// length: i32 = 0,
/// algorithm: EVP.Algorithm,
public class PBKDF2Params {
    public var password: Array<Byte>
    public var salt: Array<Byte>
    public var iterationCount: UInt32
    public var length: Int32
    public var algorithm: EVP.Algorithm

    public init() {
        password = Array<Byte>()
        salt = Array<Byte>()
        iterationCount = 1
        length = 0
        algorithm = EVP.Algorithm.sha256
    }

    public init(password: Array<Byte>, salt: Array<Byte>, iterationCount: UInt32,
                length: Int32, algorithm: EVP.Algorithm) {
        this.password = password
        this.salt = salt
        this.iterationCount = iterationCount
        this.length = length
        this.algorithm = algorithm
    }

    /// 运行 PBKDF2 派生
    /// 对应 Bun: pub fn run(this: *PBKDF2, output: []u8) bool
    public func run(output: Array<Byte>): Bool {
        // @memset(output, 0);
        for (i in 0..output.size) {
            output[i] = 0
        }

        // BoringSSL.ERR_clear_error();
        BoringSSL.errClearError()

        // const rc = BoringSSL.PKCS5_PBKDF2_HMAC(
        //     if (password.len > 0) password.ptr else null,
        //     @intCast(password.len),
        //     salt.ptr, @intCast(salt.len),
        //     @intCast(iteration_count),
        //     algorithm.md().?,
        //     @intCast(length),
        //     output.ptr,
        // );
        let md = this.algorithm.md()
        if (md.isNone()) {
            return false
        }

        let passwordPtr: ?Array<Byte> = if (this.password.size > 0) { this.password } else { None }
        let rc = BoringSSL.pkcs5Pbkdf2Hmac(
            passwordPtr,
            this.password.size.toInt64(),
            this.salt,
            this.salt.size.toInt64(),
            this.iterationCount,
            md!!,
            this.length.toInt64(),
            output
        )

        // if (rc <= 0) return false;
        if (rc <= 0) {
            return false
        }

        // return true;
        return true
    }

    /// 释放并清除敏感数据
    /// 对应 Bun: pub fn deinitAndUnprotect(this: *PBKDF2) void
    public func deinitAndUnprotect(): Unit {
        // this.password.deinitAndUnprotect();
        // this.salt.deinitAndUnprotect();
        freeSensitive(this.password)
        freeSensitive(this.salt)
    }

    /// 释放
    /// 对应 Bun: pub fn deinit(this: *PBKDF2) void
    public func deinit(): Unit {
        // this.password.deinit();
        // this.salt.deinit();
    }

    /// 清除敏感数据
    private func freeSensitive(data: Array<Byte>): Unit {
        for (i in 0..data.size) {
            data[i] = 0
        }
    }
}

// ============================================================================
// PBKDF2.Job - 异步任务
// 对应 Bun: PBKDF2.zig - pub const Job = struct { ... }
// ============================================================================

/// PBKDF2 异步任务
/// 对应 Bun: pub const Job = struct { ... }
public class PBKDF2Job {
    public var pbkdf2: PBKDF2Params
    public var output: Array<Byte>
    public var promise: JsPromise
    public var vm: VirtualMachine
    public var err: ?UInt32

    public init(pbkdf2: PBKDF2Params, vm: VirtualMachine) {
        this.pbkdf2 = pbkdf2
        this.output = Array<Byte>()
        this.vm = vm
        this.err = None
        this.promise = JsPromise()
    }

    /// 运行任务（在线程池中执行）
    /// 对应 Bun: pub fn runTask(task: *jsc.WorkPoolTask) void
    public func runTask(): Unit {
        // job.output = bun.default_allocator.alloc(u8, @as(usize, @intCast(job.pbkdf2.length))) catch {
        //     job.err = BoringSSL.EVP_R_MEMORY_LIMIT_EXCEEDED;
        //     return;
        // };
        this.output = Array<Byte>(this.pbkdf2.length.toInt64(), item: 0)

        // if (!job.pbkdf2.run(job.output))
        if (!this.pbkdf2.run(this.output)) {
            // job.err = BoringSSL.ERR_get_error();
            this.err = BoringSSL.errGetError()
            // BoringSSL.ERR_clear_error();
            BoringSSL.errClearError()
            // bun.default_allocator.free(job.output);
            this.output = Array<Byte>()
        }
    }

    /// 从 JS 运行（任务完成后回调）
    /// 对应 Bun: pub fn runFromJS(this: *Job) bun.JSTerminated!void
    public func runFromJs(): Unit {
        defer(this.deinit())

        // if (this.vm.isShuttingDown()) return;
        if (this.vm.isShuttingDown()) {
            return
        }

        let globalThis = this.vm.getGlobal()

        // if (this.err) |err|
        match (this.err) {
            case Some(err) => {
                // try promise.rejectWithAsyncStack(globalThis, createCryptoError(globalThis, err));
                this.promise.reject(createCryptoError(globalThis, err))
                return
            }
            case None => {}
        }

        // const output_slice = this.output;
        // const buffer_value = jsc.JSValue.createBuffer(globalThis, output_slice);
        // this.output = &[_]u8{};
        // try promise.resolve(globalThis, buffer_value);
        let bufferValue = JsArrayBuffer.createBuffer(globalThis, this.output)
        this.output = Array<Byte>()
        this.promise.resolve(bufferValue)
    }

    /// 释放任务
    /// 对应 Bun: pub fn deinit(this: *Job) void
    public func deinit(): Unit {
        // this.poll.unref(this.vm);
        // this.pbkdf2.deinitAndUnprotect();
        this.pbkdf2.deinitAndUnprotect()
        // this.promise.deinit();
        // bun.default_allocator.free(this.output);
    }

    /// 创建异步 PBKDF2 Job
    /// 对应 Bun: pub fn create(vm: *jsc.VirtualMachine, globalThis: *jsc.JSGlobalObject, data: *const PBKDF2) *Job
    public static func create(vm: VirtualMachine, globalThis: JsObject, data: PBKDF2Params): PBKDF2Job {
        let job = PBKDF2Job(data, vm)
        // job.promise = jsc.JSPromise.Strong.init(globalThis);
        job.promise = JsPromise.init(globalThis)

        // jsc.WorkPool.schedule(&job.task);
        WorkPool.schedule(job)

        return job
    }
}

// ============================================================================
// PBKDF2 便捷函数
// 对应 Bun: pub fn pbkdf2(output, password, salt, iteration_count, algorithm) ?[]const u8
// ============================================================================

/// PBKDF2 密钥派生便捷函数
/// 对应 Bun: pub fn pbkdf2(output: []u8, password: []const u8, salt: []const u8,
///     iteration_count: u32, algorithm: Algorithm) ?[]const u8
public func pbkdf2(output: Array<Byte>, password: Array<Byte>, salt: Array<Byte>,
                   iterationCount: UInt32, algorithm: EVP.Algorithm): ?Array<Byte> {
    var pbk = PBKDF2Params(
        password: password,
        salt: salt,
        iterationCount: iterationCount,
        length: output.size.toInt32(),
        algorithm: algorithm
    )

    if (!pbk.run(output)) {
        return None
    }

    return output
}
