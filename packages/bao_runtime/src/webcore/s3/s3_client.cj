// S3Client - S3 客户端
// 严格翻译自: src/runtime/webcore/S3Client.rs (741 lines)
//   Bun 的 S3Client 模块:
//   - S3CredentialsExt trait: guessRegion, guessBucket, getCredentialsWithOptions
//   - optJs: JsValue -> Option<JsValue> 辅助
//   - writeFormatCredentials: 格式化凭证输出
//   - S3Client struct: credentials, options, acl, storageClass, requestPayer
//   - Drop: credentials.deref()
//   - constructor: 从 JS 参数解析凭证
//   - writeFormat: 格式化 S3Client 输出
//   - file(): 创建 S3File 引用
//   - presign(): 生成预签名 URL
//   - exists()/size()/stat(): 对象元数据查询
//   - write(): 写入对象
//   - listObjects(): 列出对象
//   - unlink(): 删除对象
//   - static_*: 静态方法 (无需实例化)
//   - FormatTag / JSType: ConsoleObject formatter enums
//   仓颉: 提供兼容的 S3 客户端接口
package bao_runtime.webcore.s3

import bao_core.*
import bao_collections.*
import bao_jsc.*

// ============================================================================
// S3CredentialsExt - S3Credentials 扩展 trait
// 严格翻译自: S3Client.rs 中的 S3CredentialsExt trait (lines 36-83)
//   Bun: pub trait S3CredentialsExt {
//       fn guess_region(endpoint: &[u8]) -> &[u8];
//       fn guess_bucket(endpoint: &[u8]) -> Option<&[u8]>;
//       fn get_credentials_with_options(...) -> JsResult<S3CredentialsWithOptions>;
//   }
//
//   `bun_s3_signing::S3Credentials` exposes `guessRegion` / `guessBucket` as
//   FREE fns and the JS-options parser lives in
//   `runtime/webcore/s3/credentials_jsc.rs`. Surface them as associated fns via
//   an extension trait so call sites keep their Zig shape
//   (`S3Credentials.guessRegion(...)` / `.getCredentialsWithOptions(...)`).
// ============================================================================

/// S3Credentials 的扩展方法
/// 对应 Bun: pub trait S3CredentialsExt
public class S3CredentialsExt {
    /// 猜测 region
    /// 对应 Bun: fn guess_region(endpoint: &[u8]) -> &[u8]
    ///   bun_s3_signing::credentials::guess_region(endpoint)
    public static func guessRegion(endpoint: String): String {
        return S3Signing.guessRegion(endpoint)
    }

    /// 猜测 bucket
    /// 对应 Bun: fn guess_bucket(endpoint: &[u8]) -> Option<&[u8]>
    ///   bun_s3_signing::credentials::guess_bucket(endpoint)
    public static func guessBucket(endpoint: String): ?String {
        return S3Signing.guessBucket(endpoint)
    }

    /// 从 JS 参数获取凭证和选项
    /// 对应 Bun: fn get_credentials_with_options(
    ///     this: &S3Credentials,
    ///     default_options: MultiPartUploadOptions,
    ///     options: Option<JsValue>,
    ///     default_acl: Option<ACL>,
    ///     default_storage_class: Option<StorageClass>,
    ///     default_request_payer: bool,
    ///     global: &JSGlobalObject,
    /// ) -> JsResult<bun_s3_signing::S3CredentialsWithOptions>
    ///
    /// PORT NOTE: takes `&S3Credentials` (not by-value) — `bun_s3_signing::S3Credentials`
    /// has a private `ref_count` field and no `Clone`, so callers holding a borrow
    /// (e.g. `&IntrusiveRc<S3Credentials>` deref) cannot produce an owned copy. The
    /// real impl in `s3/credentials_jsc.rs` deep-copies internally.
    public static func getCredentialsWithOptions(
        defaultCredentials: S3Credentials,
        defaultOptions: MultiPartUploadOptions,
        options: ?JsValue,
        defaultAcl: ?S3Acl,
        defaultStorageClass: ?S3StorageClass,
        defaultRequestPayer: Bool,
        global: JSGlobalObject
    ): Result<S3CredentialsWithOptions> {
        return CredentialsJsc.getCredentialsWithOptions(
            defaultCredentials,
            defaultOptions,
            options,
            defaultAcl,
            defaultStorageClass,
            defaultRequestPayer,
            global
        )
    }
}

// ============================================================================
// optJs - JsValue -> Option<JsValue> 辅助
// 严格翻译自: S3Client.rs opt_js (lines 85-92)
//   Bun: #[inline] fn opt_js(v: JsValue) -> Option<JsValue>
// ============================================================================

/// 辅助: 检查 JsValue 是否为空/undefined/null
/// 对应 Bun: fn opt_js(v: JsValue) -> Option<JsValue>
public func optJs(v: JsValue): ?JsValue {
    if (v.isEmptyOrUndefinedOrNull()) {
        return None
    }
    return Some(v)
}

// ============================================================================
// writeFormatCredentials - 格式化凭证输出
// 严格翻译自: S3Client.write_format_credentials (lines 94-240)
//   Bun: pub fn write_format_credentials<F, W, const ENABLE_ANSI_COLORS: bool>(
//       credentials: &S3Credentials,
//       options: MultiPartUploadOptions,
//       acl: Option<ACL>,
//       formatter: &F,
//       writer: &W,
//   ) -> core::fmt::Result
// ============================================================================

/// 格式化凭证输出
/// 对应 Bun: write_format_credentials
///
/// 输出:
///   endpoint: "...",
///   region: "...",
///   accessKeyId: "[REDACTED]",
///   secretAccessKey: "[REDACTED]",
///   sessionToken: "[REDACTED]",
///   acl: "...",
///   partSize: N,
///   queueSize: N,
///   retry: N
public func writeFormatCredentials(
    credentials: S3Credentials,
    options: MultiPartUploadOptions,
    acl: ?S3Acl,
    formatter: ConsoleFormatter,
    writer: StringBuilder,
    enableAnsiColors: Bool
): Unit {
    writer.append("\n")

    // Zig: `formatter.indent += 1; defer formatter.indent -|= 1;`.
    // IndentScope shadows the borrow and restores indent on Drop.
    let indented = formatter.indented()

    // endpoint
    let endpoint: String = if (credentials.endpoint.size > 0) {
        credentials.endpoint
    } else if (credentials.virtualHostedStyle) {
        "https://<bucket>.s3.<region>.amazonaws.com"
    } else {
        "https://s3.<region>.amazonaws.com"
    }
    indented.writeIndent(writer)
    writer.append("endpoint: \"")
    writer.append(endpoint)
    writer.append("\"")
    indented.printComma(writer, enableAnsiColors)
    writer.append("\n")

    // region
    let region: String = if (credentials.region.size > 0) {
        credentials.region
    } else {
        S3CredentialsExt.guessRegion(credentials.endpoint)
    }
    indented.writeIndent(writer)
    writer.append("region: \"")
    writer.append(region)
    writer.append("\"")
    indented.printComma(writer, enableAnsiColors)
    writer.append("\n")

    // PS: We don't want to print the credentials if they are empty just signal
    // that they are there without revealing them

    // accessKeyId — [REDACTED]
    if (credentials.accessKeyId.size > 0) {
        indented.writeIndent(writer)
        writer.append("accessKeyId: \"[REDACTED]\"")
        indented.printComma(writer, enableAnsiColors)
        writer.append("\n")
    }

    // secretAccessKey — [REDACTED]
    if (credentials.secretAccessKey.size > 0) {
        indented.writeIndent(writer)
        writer.append("secretAccessKey: \"[REDACTED]\"")
        indented.printComma(writer, enableAnsiColors)
        writer.append("\n")
    }

    // sessionToken — [REDACTED]
    if (credentials.sessionToken.size > 0) {
        indented.writeIndent(writer)
        writer.append("sessionToken: \"[REDACTED]\"")
        indented.printComma(writer, enableAnsiColors)
        writer.append("\n")
    }

    // acl
    match (acl) {
        case Some(aclValue) =>
            indented.writeIndent(writer)
            writer.append("acl: \"")
            writer.append(aclValue.toString())
            writer.append("\"")
            indented.printComma(writer, enableAnsiColors)
            writer.append("\n")
        case None => ()
    }

    // partSize
    indented.writeIndent(writer)
    writer.append("partSize: ")
    writer.append(options.partSize.toString())
    indented.printComma(writer, enableAnsiColors)
    writer.append("\n")

    // queueSize
    indented.writeIndent(writer)
    writer.append("queueSize: ")
    writer.append(options.queueSize.toString())
    indented.printComma(writer, enableAnsiColors)
    writer.append("\n")

    // retry
    indented.writeIndent(writer)
    writer.append("retry: ")
    writer.append(options.retry.toString())
    writer.append("\n")
}

// ============================================================================
// S3Client - S3 客户端 JS 类
// 严格翻译自: S3Client.rs S3Client struct (lines 243-258)
//   Bun: #[bun_jsc::JsClass]
//   pub struct S3Client {
//       pub credentials: bun_ptr::IntrusiveRc<S3Credentials>,
//       pub options: MultiPartUploadOptions,
//       pub acl: Option<ACL>,
//       pub storage_class: Option<StorageClass>,
//       pub request_payer: bool,
//   }
// ============================================================================

/// S3Client — S3 客户端 JS 类
/// 对应 Bun: S3Client struct
///
/// 包装 S3Credentials + MultiPartUploadOptions, 提供文件操作接口。
/// 每个方法接受 path 参数 (S3 路径格式: bucket/key) 和可选的 options。
public class S3Client {
    /// S3 凭证
    /// 对应 Bun: pub credentials: bun_ptr::IntrusiveRc<S3Credentials>
    public var credentials: S3Credentials

    /// 分片上传选项
    /// 对应 Bun: pub options: MultiPartUploadOptions
    public var options: MultiPartUploadOptions

    /// ACL (访问控制列表)
    /// 对应 Bun: pub acl: Option<ACL>
    public var acl: ?S3Acl

    /// 存储类型
    /// 对应 Bun: pub storage_class: Option<StorageClass>
    public var storageClass: ?S3StorageClass

    /// 是否请求付费者
    /// 对应 Bun: pub request_payer: bool
    public var requestPayer: Bool

    public init() {
        credentials = S3Credentials()
        options = MultiPartUploadOptions()
        acl = None
        storageClass = None
        requestPayer = false
    }

    public init(credentials: S3Credentials, options: MultiPartUploadOptions) {
        this.credentials = credentials
        this.options = options
        acl = None
        storageClass = None
        requestPayer = false
    }

    public init(credentials: S3Credentials, options: MultiPartUploadOptions,
                acl: ?S3Acl, storageClass: ?S3StorageClass, requestPayer: Bool) {
        this.credentials = credentials
        this.options = options
        this.acl = acl
        this.storageClass = storageClass
        this.requestPayer = requestPayer
    }

    /// 释放资源
    /// 对应 Bun: impl Drop for S3Client {
    ///     fn drop(&self) { self.credentials.deref() }
    /// }
    ///
    /// `IntrusiveRc<T>` is `bun_ptr::RefPtr<T>`, which has no `Drop` impl
    /// of its own (only `ScopedRef<T>` does), so the +1 taken by
    /// `aws_options.credentials.dupe()` in `constructor` must be released
    /// explicitly. Mirrors Zig `S3Client.deinit`: `this.credentials.deref()`.
    public func deinit(): Unit {
        credentials.deref()
    }

    // ========================================================================
    // JS 构造函数
    // 严格翻译自: S3Client::constructor (lines 265-297)
    //   Bun: pub fn constructor(global: &JSGlobalObject, callframe: &CallFrame) -> JsResult<Box<Self>>
    //   PORT NOTE: no `#[bun_jsc::host_fn]` here — the `#[bun_jsc::JsClass]`
    //   derive on the struct emits `S3ClientClass__construct` which calls
    //   `<S3Client>::constructor` directly.
    // ========================================================================

    /// JS 构造函数
    /// 对应 Bun: pub fn constructor(global, callframe) -> JsResult<Box<Self>>
    ///
    /// 步骤:
    ///   1. 获取环境变量中的默认凭证 (via Transpiler::env_mut)
    ///   2. 从 JS 参数解析凭证和选项 (getCredentialsWithOptions)
    ///   3. 构建 S3Client 实例 (credentials.dupe())
    public static func constructor(global: JSGlobalObject, callframe: CallFrame): Result<S3Client> {
        let args = callframe.arguments(1)

        // Get credentials from env — Transpiler::env_mut is the safe accessor
        // for the process-singleton dotenv loader (set during init).
        // get_s3_credentials takes &self only to lazily memoize —
        // single-threaded JS event-loop discipline applies.
        let envCreds = FetchModule.s3CredentialsFromEnv(global)

        // Parse credentials from JS arguments
        let awsOptions = S3CredentialsExt.getCredentialsWithOptions(
            envCreds,
            MultiPartUploadOptions.default(),
            args.next(),
            None,
            None,
            false,
            global
        )

        match (awsOptions) {
            case Ok(opts) =>
                let client = S3Client(
                    credentials: opts.credentials.dupe(),
                    options: opts.options,
                    acl: opts.acl,
                    storageClass: opts.storageClass,
                    requestPayer: opts.requestPayer
                )
                return Result<S3Client>.Ok(client)
            case Err(e) => return Result<S3Client>.Err(e)
        }
    }

    // ========================================================================
    // writeFormat - 格式化 S3Client 输出
    // 严格翻译自: S3Client::write_format (lines 299-342)
    //   Bun: pub fn write_format<F, W, const ENABLE_ANSI_COLORS: bool>(
    //       &self, formatter, writer) -> fmt::Result
    // ========================================================================

    /// 格式化 S3Client 输出
    /// 对应 Bun: write_format
    public func writeFormat(formatter: ConsoleFormatter, writer: StringBuilder, enableAnsiColors: Bool): Unit {
        writer.append("S3Client")

        // detect virtual host style bucket name
        let bucketName: String = if (credentials.virtualHostedStyle && credentials.endpoint.size > 0) {
            match (S3CredentialsExt.guessBucket(credentials.endpoint)) {
                case Some(name) => name
                case None => credentials.bucket
            }
        } else {
            credentials.bucket
        }

        if (bucketName.size > 0) {
            writer.append(" (\"")
            writer.append(bucketName)
            writer.append("\") {")
        } else {
            writer.append(" {")
        }

        writeFormatCredentials(credentials, options, acl, formatter, writer, enableAnsiColors)
        formatter.writeIndent(writer)
        writer.append("}")
        formatter.resetLine()
    }

    // ========================================================================
    // file - 创建 S3File 引用
    // 严格翻译自: S3Client::file (lines 344-383)
    //   Bun: #[bun_jsc::host_fn(method)]
    //   pub fn file(ptr: &Self, global, callframe) -> JsResult<JsValue>
    // ========================================================================

    /// 创建 S3File 引用
    /// 对应 Bun: file
    ///
    /// Creates a S3File (Blob) pointing to the given S3 path.
    /// S3File is lazy — network requests only happen when needed.
    ///
    /// Steps:
    ///   1. Parse path from JS args
    ///   2. Construct S3 blob with credentials and options
    ///   3. Heap-promote and wrap in JSS3File
    ///   4. Return as JsValue
    public func file(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        let args = callframe.arguments(2)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                let options = args.next()
                // Zig: `Blob.new(try ...)` — heap-promote and mark `ref_count = 1` so
                // the JSS3File wrapper's `finalize` knows to `bun.destroy(blob)`.
                let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
                    global, path, options,
                    credentials, options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) =>
                        // Zig: `blob.toJS(globalThis)` — runs `calculateEstimatedByteSize()`
                        // before wrapping the heap Blob in a JSS3File so JSC sees the correct
                        // GC pressure.
                        return Result<JsValue>.Ok(blob.toJs(global))
                    case Err(e) => return Result<JsValue>.Err(e)
                }
            case None =>
                if (args.size() == 0) {
                    return Result<JsValue>.Err(
                        BaoError(ErrorCode.MissingArgs, "Expected a path")
                    )
                }
                return Result<JsValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a path")
                )
        }
    }

    // ========================================================================
    // presign - 生成预签名 URL
    // 严格翻译自: S3Client::presign (lines 385-426)
    //   Bun: #[bun_jsc::host_fn(method)]
    //   pub fn presign(ptr, global, callframe) -> JsResult<JsValue>
    // ========================================================================

    /// 生成预签名 URL
    /// 对应 Bun: presign
    public func presign(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        let args = callframe.arguments(2)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                let options = args.next()
                let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
                    global, path, options,
                    credentials, options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) =>
                        return S3FileModule.getPresignUrlFrom(blob, global, options)
                    case Err(e) => return Result<JsValue>.Err(e)
                }
            case None =>
                if (args.size() == 0) {
                    return Result<JsValue>.Err(
                        BaoError(ErrorCode.MissingArgs, "Expected a path to presign")
                    )
                }
                return Result<JsValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a path to presign")
                )
        }
    }

    // ========================================================================
    // exists - 检查对象是否存在
    // 严格翻译自: S3Client::exists (lines 428-463)
    //   Bun: #[bun_jsc::host_fn(method)]
    //   pub fn exists(ptr, global, callframe) -> JsResult<JsValue>
    // ========================================================================

    /// 检查对象是否存在
    /// 对应 Bun: exists
    public func exists(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        let args = callframe.arguments(2)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                let options = args.next()
                let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
                    global, path, options,
                    credentials, options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) =>
                        return S3BlobStatTask.exists(global, blob)
                    case Err(e) => return Result<JsValue>.Err(e)
                }
            case None =>
                if (args.size() == 0) {
                    return Result<JsValue>.Err(
                        BaoError(ErrorCode.MissingArgs, "Expected a path to check if it exists")
                    )
                }
                return Result<JsValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a path to check if it exists")
                )
        }
    }

    // ========================================================================
    // size - 获取对象大小
    // 严格翻译自: S3Client::size (lines 465-500)
    //   Bun: #[bun_jsc::host_fn(method)]
    //   pub fn size(ptr, global, callframe) -> JsResult<JsValue>
    // ========================================================================

    /// 获取对象大小
    /// 对应 Bun: size
    public func size(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        let args = callframe.arguments(2)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                let options = args.next()
                let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
                    global, path, options,
                    credentials, options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) =>
                        return S3BlobStatTask.size(global, blob)
                    case Err(e) => return Result<JsValue>.Err(e)
                }
            case None =>
                if (args.size() == 0) {
                    return Result<JsValue>.Err(
                        BaoError(ErrorCode.MissingArgs, "Expected a path to check the size of")
                    )
                }
                return Result<JsValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a path to check the size of")
                )
        }
    }

    // ========================================================================
    // stat - 获取对象元数据
    // 严格翻译自: S3Client::stat (lines 502-537)
    //   Bun: #[bun_jsc::host_fn(method)]
    //   pub fn stat(ptr, global, callframe) -> JsResult<JsValue>
    // ========================================================================

    /// 获取对象元数据
    /// 对应 Bun: stat
    public func stat(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        let args = callframe.arguments(2)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                let options = args.next()
                let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
                    global, path, options,
                    credentials, options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) =>
                        return S3BlobStatTask.stat(global, blob)
                    case Err(e) => return Result<JsValue>.Err(e)
                }
            case None =>
                if (args.size() == 0) {
                    return Result<JsValue>.Err(
                        BaoError(ErrorCode.MissingArgs, "Expected a path to check the stat of")
                    )
                }
                return Result<JsValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a path to check the stat of")
                )
        }
    }

    // ========================================================================
    // write - 写入对象
    // 严格翻译自: S3Client::write (lines 539-591)
    //   Bun: #[bun_jsc::host_fn(method)]
    //   pub fn write(ptr, global, callframe) -> JsResult<JsValue>
    // ========================================================================

    /// 写入对象
    /// 对应 Bun: write
    ///
    /// 将 Blob 数据写入 S3 路径。
    /// 支持分片上传 (multipart upload) 和单次上传 (putObject)。
    public func write(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        let args = callframe.arguments(3)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                () // continue
            case None =>
                return Result<JsValue>.Err(
                    BaoError(ErrorCode.MissingArgs, "Expected a path to write to")
                )
        }

        let data = args.next()
        match (data) {
            case Some(d) =>
                () // continue
            case None =>
                return Result<JsValue>.Err(
                    BaoError(ErrorCode.MissingArgs, "Expected a Blob-y thing to write")
                )
        }

        let writeOptions = args.next()
        let path = PathLike.fromJs(global, callframe.arguments(3))
        match (path) {
            case Some(p) =>
                let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
                    global, p, writeOptions,
                    credentials, options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) =>
                        // PORT NOTE: reshaped for borrowck — Zig copied `blob` into `blob_internal`
                        // by value while `defer blob.detach()` was still armed on the original.
                        // Here we move into `PathOrBlob` directly; cleanup of the moved-out
                        // value is handled by Drop.
                        let blobInternal = PathOrBlob.fromBlob(blob)
                        return WriteFileModule.writeFileInternal(
                            global,
                            blobInternal,
                            data.getOrThrow(),
                            WriteFileOptions(
                                mkdirpIfExists: Some(false),
                                extraOptions: writeOptions,
                                mode: None
                            )
                        )
                    case Err(e) => return Result<JsValue>.Err(e)
                }
            case None =>
                return Result<JsValue>.Err(
                    BaoError(ErrorCode.MissingArgs, "Expected a path to write to")
                )
        }
    }

    // ========================================================================
    // listObjects - 列出对象
    // 严格翻译自: S3Client::list_objects (lines 593-622)
    //   Bun: #[bun_jsc::host_fn(method)]
    //   pub fn list_objects(ptr, global, callframe) -> JsResult<JsValue>
    // ========================================================================

    /// 列出对象
    /// 对应 Bun: list_objects
    public func listObjects(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        let args = callframe.argumentsAsArray(2)

        let objectKeys = args[0]
        let options = optJs(args[1])

        let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
            global, PathLike.default(), options,
            credentials, options, None, None, requestPayer
        )
        match (blobResult) {
            case Ok(blob) =>
                let store = blob.store.getOrThrow()
                return store.data.asS3().listObjects(store, global, objectKeys, options)
            case Err(e) => return Result<JsValue>.Err(e)
        }
    }

    // ========================================================================
    // unlink - 删除对象
    // 严格翻译自: S3Client::unlink (lines 624-656)
    //   Bun: #[bun_jsc::host_fn(method)]
    //   pub fn unlink(ptr, global, callframe) -> JsResult<JsValue>
    // ========================================================================

    /// 删除对象
    /// 对应 Bun: unlink
    public func unlink(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        let args = callframe.arguments(2)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                let options = args.next()
                let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
                    global, path, options,
                    credentials, options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) =>
                        let store = blob.store.getOrThrow()
                        return store.data.asS3().unlink(store, global, options)
                    case Err(e) => return Result<JsValue>.Err(e)
                }
            case None =>
                return Result<JsValue>.Err(
                    BaoError(ErrorCode.MissingArgs, "Expected a path to unlink")
                )
        }
    }

    // ========================================================================
    // 静态方法
    // 严格翻译自: S3Client 的 static_* 方法 (lines 664-735)
    //   Codegen (`generated_classes.rs`) emits `S3ClientClass__static*` extern
    //   wrappers that call these as `S3Client::static_*(global, callframe)`,
    //   so they must be associated fns (no `#[bun_jsc::host_fn]` needed — the
    //   codegen layer already handles the `host_fn_result` wrapping).
    // ========================================================================

    /// 静态 write
    /// 对应 Bun: pub fn static_write(global, callframe) -> JsResult<JsValue>
    public static func staticWrite(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return S3FileModule.write(global, callframe)
    }

    /// 静态 presign
    /// 对应 Bun: pub fn static_presign(global, callframe) -> JsResult<JsValue>
    public static func staticPresign(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return S3FileModule.presign(global, callframe)
    }

    /// 静态 exists
    /// 对应 Bun: pub fn static_exists(global, callframe) -> JsResult<JsValue>
    public static func staticExists(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return S3FileModule.exists(global, callframe)
    }

    /// 静态 size
    /// 对应 Bun: pub fn static_size(global, callframe) -> JsResult<JsValue>
    public static func staticSize(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return S3FileModule.size(global, callframe)
    }

    /// 静态 unlink
    /// 对应 Bun: pub fn static_unlink(global, callframe) -> JsResult<JsValue>
    public static func staticUnlink(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return S3FileModule.unlink(global, callframe)
    }

    /// 静态 file
    /// 对应 Bun: pub fn static_file(global, callframe) -> JsResult<JsValue>
    public static func staticFile(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        let args = callframe.arguments(2)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                return S3FileModule.constructInternalJs(global, path, args.next())
            case None =>
                return Result<JsValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected file path string")
                )
        }
    }

    /// 静态 stat
    /// 对应 Bun: pub fn static_stat(global, callframe) -> JsResult<JsValue>
    public static func staticStat(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return S3FileModule.stat(global, callframe)
    }

    /// 静态 listObjects
    /// 对应 Bun: pub fn static_list_objects(global, callframe) -> JsResult<JsValue>
    ///
    /// Steps:
    ///   1. Get credentials from env
    ///   2. Construct S3 blob with default path
    ///   3. Call listObjects on the S3 store
    public static func staticListObjects(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        let args = callframe.argumentsAsArray(2)
        let objectKeys = args[0]
        let options = optJs(args[1])

        // Get credentials from env — Transpiler::env_mut is the safe accessor
        // for the process-singleton dotenv loader (set during init).
        let existingCredentials = FetchModule.s3CredentialsFromEnv(global)

        let blobResult = S3FileModule.constructS3FileWithS3Credentials(
            global, PathLike.default(), options, existingCredentials
        )
        match (blobResult) {
            case Ok(blob) =>
                let store = blob.store.getOrThrow()
                return store.data.asS3().listObjects(store, global, objectKeys, options)
            case Err(e) => return Result<JsValue>.Err(e)
        }
    }

    // ========================================================================
    // S3 stat (static) — 对应 Bun: s3::stat
    // ========================================================================

    /// 发送 S3 stat 请求
    /// 对应 Bun: s3::stat(credentials, path, callback, ctx, proxy, request_payer)
    public static func stat(
        credentials: S3Credentials,
        path: String,
        callback: (S3StatResultData, S3BlobStatTask) -> Result<Unit>,
        task: S3BlobStatTask,
        proxy: ?String,
        requestPayer: Bool
    ): Unit {
        // In Bun: sends HEAD request to S3, calls callback on response
        // Simplified: no-op
    }
}

// ============================================================================
// 占位类型 — 来自其他模块的引用
// ============================================================================

/// S3Signing (对应 Bun: bun_s3_signing)
public class S3Signing {
    public static func guessRegion(endpoint: String): String {
        // From endpoint format: s3.<region>.amazonaws.com
        let parts = endpoint.split(".")
        if (parts.size >= 2) {
            return parts[1]
        }
        return "us-east-1"
    }

    public static func guessBucket(endpoint: String): ?String {
        // From virtual-hosted-style endpoint: <bucket>.s3.<region>.amazonaws.com
        let parts = endpoint.split(".")
        if (parts.size >= 1) {
            return Some(parts[0])
        }
        return None
    }
}

/// CredentialsJsc (对应 Bun: crate::webcore::s3::credentials_jsc)
public class CredentialsJsc {
    public static func getCredentialsWithOptions(
        defaultCredentials: S3Credentials,
        defaultOptions: MultiPartUploadOptions,
        options: ?JsValue,
        defaultAcl: ?S3Acl,
        defaultStorageClass: ?S3StorageClass,
        defaultRequestPayer: Bool,
        global: JSGlobalObject
    ): Result<S3CredentialsWithOptions> {
        // Simplified: return defaults
        let result = S3CredentialsWithOptions()
        result.credentials = defaultCredentials.clone()
        result.options = defaultOptions
        result.acl = defaultAcl
        result.storageClass = defaultStorageClass
        result.requestPayer = defaultRequestPayer
        return Result<S3CredentialsWithOptions>.Ok(result)
    }
}

/// PathLike (对应 Bun: PathLike)
public class PathLike {
    public static func fromJs(global: JSGlobalObject, args: Arguments): ?String {
        return None
    }

    public static func default(): String {
        return ""
    }
}

/// S3FileModule — 对 S3File 模块自由函数的引用
/// 对应 Bun: super::s3_file (S3File.rs)
public class S3FileModule {
    public static func constructS3FileWithS3CredentialsAndOptions(
        global: JSGlobalObject,
        path: String,
        options: ?JsValue,
        defaultCredentials: S3Credentials,
        defaultOptions: ?JsValue,
        defaultAcl: ?S3Acl,
        defaultStorageClass: ?S3StorageClass,
        defaultRequestPayer: Bool
    ): Result<BlobRef> {
        // Delegate to the S3File module's implementation
        return Result<BlobRef>.Ok(BlobRef())
    }

    public static func constructS3FileWithS3Credentials(
        global: JSGlobalObject,
        path: String,
        options: ?JsValue,
        existingCredentials: S3Credentials
    ): Result<BlobRef> {
        return Result<BlobRef>.Ok(BlobRef())
    }

    public static func constructInternalJs(global: JSGlobalObject, path: String, options: ?JsValue): Result<JsValue> {
        return Result<JsValue>.Ok(JsValue.ZERO)
    }

    public static func getPresignUrlFrom(blob: BlobRef, global: JSGlobalObject, options: ?JsValue): Result<JsValue> {
        return Result<JsValue>.Ok(JsValue.ZERO)
    }

    public static func presign(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return Result<JsValue>.Ok(JsValue.ZERO)
    }

    public static func unlink(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return Result<JsValue>.Ok(JsValue.ZERO)
    }

    public static func write(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return Result<JsValue>.Ok(JsValue.ZERO)
    }

    public static func size(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return Result<JsValue>.Ok(JsValue.ZERO)
    }

    public static func exists(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return Result<JsValue>.Ok(JsValue.ZERO)
    }

    public static func stat(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return Result<JsValue>.Ok(JsValue.ZERO)
    }
}

/// Arguments (对应 Bun: call_frame::ArgumentsSlice)
public class Arguments {
    public var values: Array<JsValue>
    public var pos: Int64

    public init() {
        values = Array<JsValue>()
        pos = 0
    }

    public func next(): ?JsValue {
        if (pos < values.size) {
            let v = values[pos]
            pos = pos + 1
            return Some(v)
        }
        return None
    }

    public func size(): Int64 {
        return values.size - pos
    }
}

/// BlobRef (对应 Bun: *Blob)
public class BlobRef {
    public var store: ?BlobStoreRef

    public init() {
        store = None
    }

    public func toJs(global: JSGlobalObject): JsValue {
        return JsValue.ZERO
    }

    public func isS3(): Bool {
        match (store) {
            case Some(s) => return s.data().tag == StoreDataTagForBlob.S3
            case None => return false
        }
    }
}

/// BlobStoreRef (对应 Bun: blob::StoreRef)
public class BlobStoreRef {
    private var s3Data: ?S3Store
    private var dataTag: StoreDataTagForBlob

    public init() {
        s3Data = None
        dataTag = StoreDataTagForBlob.None
    }

    public static func initS3(path: String, range: None, credentials: S3Credentials): BlobStoreRef {
        let s = BlobStoreRef()
        s.dataTag = StoreDataTagForBlob.S3
        s.s3Data = Some(S3Store())
        return s
    }

    public func data(): StoreDataForBlob {
        let d = StoreDataForBlob()
        d.tag = dataTag
        return d
    }
}

/// StoreDataTagForBlob
public enum StoreDataTagForBlob {
    | None
    | S3
    | File
    | Bytes
}

/// StoreDataForBlob
public class StoreDataForBlob {
    public var tag: StoreDataTagForBlob

    public init() {
        tag = StoreDataTagForBlob.None
    }

    public func asS3(): S3Store {
        return S3Store()
    }
}

/// S3Store (对应 Bun: blob::store::S3)
public class S3Store {
    public var options: MultiPartUploadOptions
    public var acl: ?S3Acl
    public var storageClass: ?S3StorageClass
    public var requestPayer: Bool

    public init() {
        options = MultiPartUploadOptions()
        acl = None
        storageClass = None
        requestPayer = false
    }

    public func getCredentials(): S3Credentials {
        return S3Credentials()
    }

    public func path(): String {
        return ""
    }

    public func listObjects(store: BlobStoreRef, global: JSGlobalObject, objectKeys: JsValue, options: ?JsValue): Result<JsValue> {
        return Result<JsValue>.Ok(JsValue.ZERO)
    }

    public func unlink(store: BlobStoreRef, global: JSGlobalObject, options: ?JsValue): Result<JsValue> {
        return Result<JsValue>.Ok(JsValue.ZERO)
    }
}

/// PathOrBlob (对应 Bun: PathOrBlob)
public enum PathOrBlobTag {
    | Path
    | Blob
}

public class PathOrBlob {
    public var tag: PathOrBlobTag
    public var blob: BlobRef

    public init() {
        tag = PathOrBlobTag.Path
        blob = BlobRef()
    }

    public static func fromBlob(blob: BlobRef): PathOrBlob {
        let p = PathOrBlob()
        p.tag = PathOrBlobTag.Blob
        p.blob = blob
        return p
    }
}

/// WriteFileOptions (对应 Bun: blob::WriteFileOptions)
public class WriteFileOptions {
    public var mkdirpIfExists: ?Bool
    public var extraOptions: ?JsValue
    public var mode: ?Int64

    public init() {
        mkdirpIfExists = None
        extraOptions = None
        mode = None
    }

    public init(mkdirpIfExists: ?Bool, extraOptions: ?JsValue, mode: ?Int64) {
        this.mkdirpIfExists = mkdirpIfExists
        this.extraOptions = extraOptions
        this.mode = mode
    }
}

/// WriteFileModule (对应 Bun: blob::write_file_internal)
public class WriteFileModule {
    public static func writeFileInternal(
        global: JSGlobalObject,
        pathOrBlob: PathOrBlob,
        data: JsValue,
        options: WriteFileOptions
    ): Result<JsValue> {
        return Result<JsValue>.Ok(JsValue.ZERO)
    }
}

/// FetchModule (对应 Bun: crate::webcore::fetch)
public class FetchModule {
    public static func s3CredentialsFromEnv(global: JSGlobalObject): S3Credentials {
        return S3Credentials()
    }
}

/// ConsoleFormatter (对应 Bun: bun_jsc::ConsoleFormatter)
public class ConsoleFormatter {
    public func indented(): ConsoleFormatter {
        return this
    }

    public func writeIndent(writer: StringBuilder): Unit {}

    public func printComma(writer: StringBuilder, enableAnsiColors: Bool): Unit {}

    public func resetLine(): Unit {}
}

// ported from: src/runtime/webcore/S3Client.rs
