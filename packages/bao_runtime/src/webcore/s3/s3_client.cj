// S3Client - S3 客户端
// 严格翻译自: src/runtime/webcore/S3Client.rs (741 lines)
//   Bun 的 S3Client 模块:
//   - S3CredentialsExt trait: guessRegion, guessBucket, getCredentialsWithOptions
//   - optJs: JsValue -> Option<JsValue> 辅助
//   - writeFormatCredentials: 格式化凭证输出
//   - S3Client struct: credentials, this.options, acl, storageClass, requestPayer
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
import bao_http.AsyncHTTP as BaoAsyncHTTP
import bao_http.AsyncHTTPOptions as BaoAsyncHTTPOptions
import bao_http.AwsCredentials as BaoAwsCredentials
import bao_http.FetchRedirect as BaoFetchRedirect
import bao_http.HTTPClient as BaoHTTPClient
import bao_http.HTTPClientResult as BaoHTTPClientResult
import bao_http.HTTPClientResultCallback as BaoHTTPClientResultCallback
import bao_http.HTTPResponseMetadata as BaoHTTPResponseMetadata
import bao_http.HeaderEntryList as BaoHeaderEntryList
import bao_http.HttpMethod as BaoHttpMethod
import bao_http.ParsedUrl as BaoParsedUrl
import bao_http.S3Acl as BaoHttpS3Acl
import bao_http.S3SignOptions as BaoS3SignOptions
import bao_http.S3Signer as BaoS3Signer
import bao_http.S3StorageClass as BaoHttpS3StorageClass
import bao_http.ThreadPoolBatch as BaoThreadPoolBatch
import bao_http.httpThread as baoHttpThread

// ============================================================================
// Local S3Credentials - shadows the empty stub from bao_jsc
// Adds accessKey, secretKey, sessionToken, region, endpoint, bucket fields
// ============================================================================

/// S3Credentials with all fields needed by credentials_jsc.cj
/// Shadows the empty stub from bao_jsc.webcore_types
public class S3Credentials {
    public var accessKey: String
    public var secretKey: String
    public var sessionToken: ?String
    public var region: String
    public var endpoint: String
    public var bucket: String
    public var insecureHttp: Bool
    public var virtualHostedStyle: Bool

    public init() {
        accessKey = ""
        secretKey = ""
        sessionToken = None
        region = ""
        endpoint = ""
        bucket = ""
        insecureHttp = false
        virtualHostedStyle = false
    }
    public func estimatedSize(): Int64 { return 0 }
}

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
    } else if (false) {
        // stub: virtualHostedStyle not supported
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
    if (credentials.accessKey.size > 0) {
        indented.writeIndent(writer)
        writer.append("accessKeyId: \"[REDACTED]\"")
        indented.printComma(writer, enableAnsiColors)
        writer.append("\n")
    }

    // secretAccessKey — [REDACTED]
    if (credentials.secretKey.size > 0) {
        indented.writeIndent(writer)
        writer.append("secretAccessKey: \"[REDACTED]\"")
        indented.printComma(writer, enableAnsiColors)
        writer.append("\n")
    }

    // sessionToken — [REDACTED]
    if (credentials.sessionToken.isSome() && credentials.sessionToken.getOrThrow().size > 0) {
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
        // stub: credentials.deref() - no deref needed in Cangjie
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
        let args = Arguments.fromCallFrame(callframe,1)

        // Get credentials from env — Transpiler::env_mut is the safe accessor
        // for the process-singleton dotenv loader (set during init).
        // get_s3_credentials takes &self only to lazily memoize —
        // single-threaded JS event-loop discipline applies.
        let envCreds = FetchModule.s3CredentialsFromEnv(global)

        // Parse credentials from JS arguments
        let awsOptions = S3CredentialsExt.getCredentialsWithOptions(
            envCreds,
            MultiPartUploadOptions(),
            args.values[0],
            None,
            None,
            false,
            global
        )

        match (awsOptions) {
            case Ok(opts) =>
                let client = S3Client(
                    opts.credentials,  // stub: no dupe() needed in Cangjie
                    opts.options,
                    opts.acl,
                    opts.storageClass,
                    opts.requestPayer
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
        let bucketName: String = if (credentials.endpoint.size > 0) {
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
        let args = Arguments.fromCallFrame(callframe,2)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                let options = args.values[1]
                let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
                    global, path, options,
                    credentials, this.options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) =>
                        return Result<JsValue>.Ok(blob.toJs(global))
                    case Err(e) => return Result<JsValue>.Err(e)
                }
            case None =>
                if (args.size() == 0) {
                    return Result<JsValue>.Err(
                        "Expected a path")
                }
                return Result<JsValue>.Err(
                    "Expected a path")
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
        let args = Arguments.fromCallFrame(callframe,2)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                let options = args.values[1]
                let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
                    global, path, options,
                    credentials, this.options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) =>
                        return getPresignUrlFrom(blob, global, optJs(options))
                    case Err(e) => return Result<JsValue>.Err(e)
                }
            case None =>
                if (args.size() == 0) {
                    return Result<JsValue>.Err(
                        "Expected a path to presign")
                }
                return Result<JsValue>.Err(
                    "Expected a path to presign")
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
        let args = Arguments.fromCallFrame(callframe,2)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                let options = args.values[1]
                let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
                    global, path, options,
                    credentials, this.options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) =>
                        return S3BlobStatTask.exists(global, blob)
                    case Err(e) => return Result<JsValue>.Err(e)
                }
            case None =>
                if (args.size() == 0) {
                    return Result<JsValue>.Err(
                        "Expected a path to check if it exists")
                }
                return Result<JsValue>.Err(
                    "Expected a path to check if it exists")
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
        let args = Arguments.fromCallFrame(callframe,2)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                let options = args.values[1]
                let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
                    global, path, options,
                    credentials, this.options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) =>
                        return S3BlobStatTask.size(global, blob)
                    case Err(e) => return Result<JsValue>.Err(e)
                }
            case None =>
                if (args.size() == 0) {
                    return Result<JsValue>.Err(
                        "Expected a path to check the size of")
                }
                return Result<JsValue>.Err(
                    "Expected a path to check the size of")
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
        let args = Arguments.fromCallFrame(callframe,2)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                let options = args.values[1]
                let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
                    global, path, options,
                    credentials, this.options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) =>
                        return S3BlobStatTask.stat(global, blob)
                    case Err(e) => return Result<JsValue>.Err(e)
                }
            case None =>
                if (args.size() == 0) {
                    return Result<JsValue>.Err(
                        "Expected a path to check the stat of")
                }
                return Result<JsValue>.Err(
                    "Expected a path to check the stat of")
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
        let args = Arguments.fromCallFrame(callframe,3)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                () // continue
            case None =>
                return Result<JsValue>.Err(
                    "Expected a path to write to")
        }

        let data = args.values[1]
        if (data.isUndefined()) {
            return Result<JsValue>.Err(
                "Expected a Blob-y thing to write")
        }

        let writeOptions = args.values[2]
        let path2 = PathLike.fromJs(global, Arguments.fromCallFrame(callframe,3))
        match (path2) {
            case Some(p) =>
                let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
                    global, p, writeOptions,
                    credentials, this.options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) =>
                        let blobInternal = PathOrBlob.fromBlob(blob)
                        return WriteFileModule.writeFileInternal(
                            global,
                            blobInternal,
                            data,
                            WriteFileOptions(
                                Some(false),
                                writeOptions,
                                None
                            )
                        )
                    case Err(e) => return Result<JsValue>.Err(e)
                }
            case None =>
                return Result<JsValue>.Err(
                    "Expected a path to write to")
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
        let args = Arguments.fromCallFrame(callframe,2)

        let objectKeys = args.values[0]
        let options = optJs(args.values[1])

        let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
            global, PathLike.default(), options,
            credentials, this.options, None, None, requestPayer
        )
        match (blobResult) {
            case Ok(blob) =>
                let store = blob.store.getOrThrow()
                return store.data().asS3().listObjects(store, global, objectKeys, options)
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
        let args = Arguments.fromCallFrame(callframe,2)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                let options = args.values[1]
                let blobResult = S3FileModule.constructS3FileWithS3CredentialsAndOptions(
                    global, path, options,
                    credentials, this.options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) =>
                        let store = blob.store.getOrThrow()
                        return store.data().asS3().unlink(store, global, optJs(options))
                    case Err(e) => return Result<JsValue>.Err(e)
                }
            case None =>
                return Result<JsValue>.Err(
                    "Expected a path to unlink")
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
        let args = Arguments.fromCallFrame(callframe,2)

        match (PathLike.fromJs(global, args)) {
            case Some(path) =>
                return S3FileModule.constructInternalJs(global, path, args.values[1])
            case None =>
                return Result<JsValue>.Err(
                    "Expected file path string")
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
        let args = Arguments.fromCallFrame(callframe,2)
        let objectKeys = args.values[0]
        let options = optJs(args.values[1])

        // Get credentials from env — Transpiler::env_mut is the safe accessor
        // for the process-singleton dotenv loader (set during init).
        let existingCredentials = FetchModule.s3CredentialsFromEnv(global)

        let blobResult = S3FileModule.constructS3FileWithS3Credentials(
            global, PathLike.default(), options, existingCredentials
        )
        match (blobResult) {
            case Ok(blob) =>
                let store = blob.store.getOrThrow()
                return store.data().asS3().listObjects(store, global, objectKeys, options)
            case Err(e) => return Result<JsValue>.Err(e)
        }
    }

    // ========================================================================
    // S3 stat (static) — 对应 Bun: s3::stat
    // ========================================================================

    /// 发送 S3 stat 请求
    /// 对应 Bun: s3::stat(credentials, path, callback, ctx, proxy, request_payer)
    public static func statRequest(
        credentials: S3Credentials,
        path: String,
        callback: (S3StatResultData, S3BlobStatTask) -> Result<Unit>,
        task: S3BlobStatTask,
        proxy: ?String,
        requestPayer: Bool
    ): Unit {
        let proxyUrl = match (proxy) {
            case Some(value) => value
            case None => ""
        }
        s3Stat(
            credentials,
            path,
            { result: S3StatResult, _: UIntNative =>
                let data = s3StatResultToData(result)
                let _ = callback(data, task)
            },
            UIntNative(0),
            proxyUrl,
            requestPayer
        )
    }

    public static func deleteRequest(
        credentials: S3Credentials,
        path: String,
        callback: (S3DeleteResult, S3BlobDeleteTask) -> Result<Unit>,
        task: S3BlobDeleteTask,
        proxy: ?String,
        requestPayer: Bool
    ): Unit {
        let proxyUrl = match (proxy) {
            case Some(value) => value
            case None => ""
        }
        s3Delete(
            credentials,
            path,
            { result: S3DeleteResult, _: UIntNative =>
                let _ = callback(result, task)
            },
            UIntNative(0),
            proxyUrl,
            requestPayer
        )
    }

    public static func downloadRequest(
        credentials: S3Credentials,
        path: String,
        callback: (S3DownloadResult, S3BlobDownloadTask) -> Result<Unit>,
        task: S3BlobDownloadTask,
        proxy: ?String,
        requestPayer: Bool
    ): Unit {
        let proxyUrl = match (proxy) {
            case Some(value) => value
            case None => ""
        }
        s3Download(
            credentials,
            path,
            { result: S3DownloadResult, _: UIntNative =>
                let _ = callback(result, task)
            },
            UIntNative(0),
            proxyUrl,
            requestPayer
        )
    }

    public static func listObjectsRequest(
        credentials: S3Credentials,
        listOptions: S3ListObjectsOptions,
        callback: (S3ListObjectsResultEx, S3BlobListObjectsTask) -> Result<Unit>,
        task: S3BlobListObjectsTask,
        proxy: ?String
    ): Unit {
        let proxyUrl = match (proxy) {
            case Some(value) => value
            case None => ""
        }
        s3ListObjects(
            credentials,
            listOptions,
            { result: S3ListObjectsResultEx, _: UIntNative =>
                let _ = callback(result, task)
            },
            UIntNative(0),
            proxyUrl
        )
    }

    public static func uploadRequest(
        credentials: S3Credentials,
        path: String,
        content: String,
        bytesWritten: Int64,
        contentType: String,
        contentDisposition: String,
        contentEncoding: String,
        acl: ?S3Acl,
        storageClass: ?S3StorageClass,
        callback: (S3UploadResult, S3BlobUploadTask) -> Result<Unit>,
        task: S3BlobUploadTask,
        proxy: ?String,
        requestPayer: Bool
    ): Unit {
        task.bytesWritten = bytesWritten
        let proxyUrl = match (proxy) {
            case Some(value) => value
            case None => ""
        }
        s3Upload(
            credentials,
            path,
            content,
            contentType,
            contentDisposition,
            contentEncoding,
            acl,
            proxyUrl,
            storageClass,
            requestPayer,
            { result: S3UploadResult, _: UIntNative =>
                let _ = callback(result, task)
            },
            UIntNative(0)
        )
    }
}

private func s3StatResultToData(result: S3StatResult): S3StatResultData {
    match (result.tag) {
        case S3StatResultTag.Success =>
            if (result.size < 0) {
                return S3StatResultData.failure(S3Error("InvalidContentLength", "S3 stat response contained a negative content-length."))
            }
            return S3StatResultData.success(
                UInt64(result.size),
                result.etag.toArray(),
                result.contentType.toArray(),
                result.lastModified.toArray()
            )
        case S3StatResultTag.NotFound =>
            let err = match (result.error) {
                case Some(e) => e
                case None => S3Error("NoSuchKey", "The specified key does not exist.")
            }
            return S3StatResultData.notFound(err)
        case S3StatResultTag.Failure =>
            let err = match (result.error) {
                case Some(e) => e
                case None => S3Error("RequestError", "S3 stat request failed.")
            }
            return S3StatResultData.failure(err)
    }
}

// ============================================================================
// 占位类型 — 来自其他模块的引用
// ============================================================================

/// S3Signing (对应 Bun: bun_s3_signing)
public class S3Signing {
    public static func guessRegion(endpoint: String): String {
        return BaoS3Signer.guessRegion(endpoint)
    }

    public static func guessBucket(endpoint: String): ?String {
        return BaoS3Signer.guessBucket(endpoint)
    }

    public static func signRequestFull(
        path: String,
        method: HttpMethod,
        searchParams: String,
        contentDisposition: String,
        contentType: String,
        contentHash: ?String,
        contentMd5: ?String,
        requestPayer: Bool,
        acl: ?S3Acl,
        storageClass: ?S3StorageClass,
        credentials: S3Credentials
    ): S3SignResult {
        let signOptions = BaoS3SignOptions(path, httpMethodToSigningString(method))
        if (searchParams.size > 0) { signOptions.searchParams = Some(searchParams) }
        if (contentDisposition.size > 0) { signOptions.contentDisposition = Some(contentDisposition) }
        if (contentType.size > 0) { signOptions.contentType = Some(contentType) }
        signOptions.contentHash = contentHash
        signOptions.contentMd5 = contentMd5
        signOptions.requestPayer = requestPayer
        signOptions.acl = toBaoHttpAcl(acl)
        signOptions.storageClass = toBaoHttpStorageClass(storageClass)

        match (BaoS3Signer.signRequest(toBaoAwsCredentials(credentials), signOptions)) {
            case Ok(signed) =>
                let r = S3SignResult()
                r.url = signed.url
                r.method = signOptions.method
                for ((name, value) in signed.headers.iterator()) {
                    r.headers.set(name, value)
                }
                return r
            case Err(err) =>
                throw Exception(err.message)
        }
    }

    private static func toBaoAwsCredentials(credentials: S3Credentials): BaoAwsCredentials {
        let sessionToken = match (credentials.sessionToken) {
            case Some(token) => token
            case None => ""
        }
        let awsCredentials = BaoAwsCredentials(
            credentials.accessKey,
            credentials.secretKey,
            sessionToken,
            credentials.region,
            credentials.endpoint,
            credentials.bucket
        )
        awsCredentials.insecureHttp = credentials.insecureHttp
        awsCredentials.virtualHostedStyle = credentials.virtualHostedStyle
        return awsCredentials
    }

    private static func httpMethodToSigningString(method: HttpMethod): String {
        match (method) {
            case HttpMethod.GET => "GET"
            case HttpMethod.PUT => "PUT"
            case HttpMethod.POST => "POST"
            case HttpMethod.DELETE => "DELETE"
            case HttpMethod.HEAD => "HEAD"
            case HttpMethod.PATCH => "PATCH"
            case HttpMethod.OPTIONS => "OPTIONS"
            case HttpMethod.CONNECT => "CONNECT"
            case HttpMethod.TRACE => "TRACE"
        }
    }

    private static func toBaoHttpAcl(acl: ?S3Acl): ?BaoHttpS3Acl {
        match (acl) {
            case Some(value) =>
                match (value) {
                    case S3Acl.Private => return Some(BaoHttpS3Acl.Private)
                    case S3Acl.PublicRead => return Some(BaoHttpS3Acl.PublicRead)
                    case S3Acl.PublicReadWrite => return Some(BaoHttpS3Acl.PublicReadWrite)
                    case S3Acl.AuthenticatedRead => return Some(BaoHttpS3Acl.AuthenticatedRead)
                    case S3Acl.AwsExecRead => return Some(BaoHttpS3Acl.AwsExecRead)
                    case S3Acl.BucketOwnerRead => return Some(BaoHttpS3Acl.BucketOwnerRead)
                    case S3Acl.BucketOwnerFullControl => return Some(BaoHttpS3Acl.BucketOwnerFullControl)
                    case S3Acl.LogDeliveryWrite => return None
                }
            case None => return None
        }
    }

    private static func toBaoHttpStorageClass(storageClass: ?S3StorageClass): ?BaoHttpS3StorageClass {
        match (storageClass) {
            case Some(value) =>
                match (value) {
                    case S3StorageClass.Standard => return Some(BaoHttpS3StorageClass.Standard)
                    case S3StorageClass.ReducedRedundancy => return Some(BaoHttpS3StorageClass.ReducedRedundancy)
                    case S3StorageClass.StandardIa => return Some(BaoHttpS3StorageClass.StandardIa)
                    case S3StorageClass.OnezoneIa => return Some(BaoHttpS3StorageClass.OnezoneIa)
                    case S3StorageClass.IntelligentTiering => return Some(BaoHttpS3StorageClass.IntelligentTiering)
                    case S3StorageClass.Glacier => return Some(BaoHttpS3StorageClass.Glacier)
                    case S3StorageClass.DeepArchive => return Some(BaoHttpS3StorageClass.DeepArchive)
                    case S3StorageClass.Outposts => return Some(BaoHttpS3StorageClass.Outposts)
                    case S3StorageClass.GlacierIr => return None
                }
            case None => return None
        }
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
        return Result<S3CredentialsWithOptions>.Ok(getCredentialsWithOptions(
            defaultCredentials,
            defaultOptions,
            options,
            defaultAcl,
            defaultStorageClass,
            defaultRequestPayer,
            global
        ))
    }
}

/// PathLike (对应 Bun: PathLike)
public class PathLike {
    public static func fromJs(global: JSGlobalObject, args: Arguments): ?String {
        match (args.next()) {
            case Some(value) =>
                if (value.isUndefinedOrNull()) {
                    return None
                }
                if (value.isString()) {
                    return Some(value.toString())
                }
                return None
            case None => return None
        }
    }

    public static func default(): String {
        return ""
    }
}

private func s3FileConstructWithOptions(
    global: JSGlobalObject,
    path: String,
    options: ?JsValue,
    defaultCredentials: S3Credentials,
    defaultOptions: MultiPartUploadOptions,
    defaultAcl: ?S3Acl,
    defaultStorageClass: ?S3StorageClass,
    defaultRequestPayer: Bool
): Result<BlobRef> {
    return constructS3FileWithS3CredentialsAndOptions(
        global,
        path,
        options,
        defaultCredentials,
        defaultOptions,
        defaultAcl,
        defaultStorageClass,
        defaultRequestPayer
    )
}

private func s3FileConstructWithCredentials(
    global: JSGlobalObject,
    path: String,
    options: ?JsValue,
    existingCredentials: S3Credentials
): Result<BlobRef> {
    return constructS3FileWithS3Credentials(global, path, options, existingCredentials)
}

private func s3FileConstructInternalJs(global: JSGlobalObject, path: String, options: ?JsValue): Result<JsValue> {
    return constructInternalJs(global, path, options)
}

private func s3FileWrite(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
    return write(global, callframe)
}

/// S3FileModule — 对 S3File 模块自由函数的引用
/// 对应 Bun: super::s3_file (S3File.rs)
public class S3FileModule {
    public static func constructS3FileWithS3CredentialsAndOptions(
        global: JSGlobalObject,
        path: String,
        options: ?JsValue,
        defaultCredentials: S3Credentials,
        defaultOptions: MultiPartUploadOptions,
        defaultAcl: ?S3Acl,
        defaultStorageClass: ?S3StorageClass,
        defaultRequestPayer: Bool
    ): Result<BlobRef> {
        return s3FileConstructWithOptions(
            global,
            path,
            options,
            defaultCredentials,
            defaultOptions,
            defaultAcl,
            defaultStorageClass,
            defaultRequestPayer
        )
    }

    public static func constructS3FileWithS3Credentials(
        global: JSGlobalObject,
        path: String,
        options: ?JsValue,
        existingCredentials: S3Credentials
    ): Result<BlobRef> {
        return s3FileConstructWithCredentials(global, path, options, existingCredentials)
    }

    public static func constructInternalJs(global: JSGlobalObject, path: String, options: ?JsValue): Result<JsValue> {
        return s3FileConstructInternalJs(global, path, options)
    }

    public static func getPresignUrlFrom(blob: BlobRef, global: JSGlobalObject, options: ?JsValue): Result<JsValue> {
        return getPresignUrlFrom(blob, global, options)
    }

    public static func presign(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return presign(global, callframe)
    }

    public static func unlink(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return unlink(global, callframe)
    }

    public static func write(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return s3FileWrite(global, callframe)
    }

    public static func size(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return size(global, callframe)
    }

    public static func exists(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return exists(global, callframe)
    }

    public static func stat(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        return stat(global, callframe)
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

    public init(values: Array<JsValue>) {
        this.values = values
        this.pos = 0
    }

    public static func fromCallFrame(callframe: CallFrame, maxArgs: Int64): Arguments {
        let arr = callframe.argumentsAsArray(maxArgs)
        return Arguments(arr)
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
    public var contentType: String
    public var contentTypeAllocated: Bool
    public var contentTypeWasSet: Bool
    public var globalThisPtr: UIntNative

    public init() {
        store = None
        contentType = ""
        contentTypeAllocated = false
        contentTypeWasSet = false
        globalThisPtr = 0
    }

    public func toJs(global: JSGlobalObject): JsValue {
        return createJSS3FileUnsafely(global, this)
    }

    public func isS3(): Bool {
        match (store) {
            case Some(s) => return s.data().tag == StoreDataTagForBlob.S3
            case None => return false
        }
    }

    public func getSize(global: JSGlobalObject): JsValue {
        return JsValue(0)
    }

    public func getExists(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
        if (!isS3()) {
            return Result<JsValue>.Err("S3 exists is only possible for s3:// files")
        }
        return S3BlobStatTask.exists(global, this)
    }

    public func setContentTypeWasSet(v: Bool): Unit {
        contentTypeWasSet = v
    }

    public func setContentType(v: String): Unit {
        contentType = v
    }

    public func setContentTypeAllocated(v: Bool): Unit {
        contentTypeAllocated = v
    }

    public func globalThis(): JSGlobalObject {
        // In Bun: returns the stored globalThis back-ref
        return JSGlobalObject()
    }

    public static func initWithStore(store: BlobStoreRef, global: JSGlobalObject): BlobRef {
        let b = BlobRef()
        b.store = Some(store)
        return b
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

    public static func initS3(path: String, range: ?String, credentials: S3Credentials): BlobStoreRef {
        let s = BlobStoreRef()
        s.dataTag = StoreDataTagForBlob.S3
        s.s3Data = Some(S3Store(path, range, credentials))
        return s
    }

    public static func initS3WithReferencedCredentials(path: String, range: ?String, credentials: S3Credentials): BlobStoreRef {
        return BlobStoreRef.initS3(path, range, credentials)
    }

    public func data(): StoreDataForBlob {
        let d = StoreDataForBlob()
        d.tag = dataTag
        d.s3 = s3Data
        return d
    }
}

/// StoreDataTagForBlob
public enum StoreDataTagForBlob {
    | None
    | S3
    | File
    | Bytes

    public operator func == (other: StoreDataTagForBlob): Bool {
        match (this) {
            case None => match (other) { case None => true case _ => false }
            case S3 => match (other) { case S3 => true case _ => false }
            case File => match (other) { case File => true case _ => false }
            case Bytes => match (other) { case Bytes => true case _ => false }
        }
    }
    public operator func != (other: StoreDataTagForBlob): Bool {
        return !(this == other)
    }
}

/// StoreDataForBlob
public class StoreDataForBlob {
    public var tag: StoreDataTagForBlob
    public var s3: ?S3Store

    public init() {
        tag = StoreDataTagForBlob.None
        s3 = None
    }

    public func asS3(): S3Store {
        match (s3) {
            case Some(store) => return store
            case None => return S3Store()
        }
    }
}

/// S3Store (对应 Bun: blob::store::S3)
public class S3Store {
    public var options: MultiPartUploadOptions
    public var acl: ?S3Acl
    public var storageClass: ?S3StorageClass
    public var requestPayer: Bool
    private var credentials: S3Credentials
    private var pathStr: String
    public var range: ?String

    public init() {
        options = MultiPartUploadOptions()
        acl = None
        storageClass = None
        requestPayer = false
        credentials = S3Credentials()
        pathStr = ""
        range = None
    }

    public init(path: String, range: ?String, credentials: S3Credentials) {
        options = MultiPartUploadOptions()
        acl = None
        storageClass = None
        requestPayer = false
        this.credentials = credentials
        this.pathStr = normalizeS3Path(path)
        this.range = range
    }

    public func getCredentials(): S3Credentials {
        return credentials
    }

    public func path(): String {
        return pathStr
    }

    private static func normalizeS3Path(path: String): String {
        var normalized = path
        while (normalized.startsWith("/")) {
            normalized = normalized[1..]
        }
        while (normalized.endsWith("/") || normalized.endsWith("\\")) {
            normalized = normalized[0..(normalized.size - 1)]
        }
        return normalized
    }

    public func getCredentialsWithOptions(options: ?JsValue, global: JSGlobalObject): Result<S3CredentialsWithOptions> {
        return Result<S3CredentialsWithOptions>.Ok(S3CredentialsWithOptions(S3Credentials(), MultiPartUploadOptions()))
    }

    public func listObjects(store: BlobStoreRef, global: JSGlobalObject, objectKeys: JsValue, options: ?JsValue): Result<JsValue> {
        return S3BlobListObjectsTask.listObjects(global, store, options)
    }

    public func unlink(store: BlobStoreRef, global: JSGlobalObject, options: ?JsValue): Result<JsValue> {
        return S3BlobDeleteTask.unlink(global, store)
    }

    public func download(store: BlobStoreRef, global: JSGlobalObject): Result<JsValue> {
        return S3BlobDownloadTask.download(global, store)
    }

    public func upload(store: BlobStoreRef, global: JSGlobalObject, content: String, bytesWritten: Int64, contentType: String): Result<JsValue> {
        return S3BlobUploadTask.upload(global, store, content, bytesWritten, contentType)
    }
}

/// PathOrBlob (对应 Bun: PathOrBlob)
public enum PathOrBlobTag {
    | Path
    | Blob
}

/// PathOrFileDescriptor tag
public enum PathOrFileDescriptorTag {
    | Fd
    | Path

    public operator func == (other: PathOrFileDescriptorTag): Bool {
        match (this) {
            case Fd => match (other) { case Fd => true case _ => false }
            case Path => match (other) { case Path => true case _ => false }
        }
    }
    public operator func != (other: PathOrFileDescriptorTag): Bool {
        return !(this == other)
    }
}

/// PathLikeEntry (对应 Bun: PathLike)
public class PathLikeEntry {
    public var tag: PathOrFileDescriptorTag
    public var pathString: String
    public var fd: Int64

    public init() {
        tag = PathOrFileDescriptorTag.Path
        pathString = ""
        fd = -1
    }
}

public class PathOrBlob {
    public var tag: PathOrBlobTag
    public var path: PathLikeEntry
    public var blob: BlobRef

    public init() {
        tag = PathOrBlobTag.Path
        path = PathLikeEntry()
        blob = BlobRef()
    }

    public static func fromBlob(blob: BlobRef): PathOrBlob {
        let p = PathOrBlob()
        p.tag = PathOrBlobTag.Blob
        p.blob = blob
        return p
    }

    public static func fromJsNoCopy(global: JSGlobalObject, args: Arguments): PathOrBlob {
        match (args.next()) {
            case Some(value) =>
                if (let blob <- value.asBlob()) {
                    return PathOrBlob.fromBlob(blob)
                }
                if (value.isString()) {
                    let p = PathOrBlob()
                    p.tag = PathOrBlobTag.Path
                    p.path.tag = PathOrFileDescriptorTag.Path
                    p.path.pathString = value.toString()
                    return p
                }
                return PathOrBlob()
            case None => return PathOrBlob()
        }
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

private class S3WriteBody {
    public var content: String
    public var bytesWritten: Int64

    public init(content: String, bytesWritten: Int64) {
        this.content = content
        this.bytesWritten = bytesWritten
    }
}

private func s3WriteBodyFromJs(global: JSGlobalObject, data: JsValue): ?S3WriteBody {
    if (data.isString()) {
        let content = data.toString()
        return Some(S3WriteBody(content, Int64(content.toArray().size)))
    }

    if (let blob <- data.asBlob()) {
        let bytes = blob.sharedView()
        return Some(S3WriteBody(String.fromUtf8(bytes), Int64(bytes.size)))
    }

    if (let arrayBuffer <- data.asArrayBuffer(global)) {
        let bytes = arrayBuffer.slice()
        return Some(S3WriteBody(String.fromUtf8(bytes), Int64(bytes.size)))
    }

    return None
}

/// WriteFileModule (对应 Bun: blob::write_file_internal)
public class WriteFileModule {
    public static func writeFileInternal(
        global: JSGlobalObject,
        pathOrBlob: PathOrBlob,
        data: JsValue,
        options: WriteFileOptions
    ): Result<JsValue> {
        if (pathOrBlob.tag != PathOrBlobTag.Blob || !pathOrBlob.blob.isS3()) {
            return Result<JsValue>.Err("S3 writeFileInternal requires an S3 destination blob")
        }
        let body = match (s3WriteBodyFromJs(global, data)) {
            case Some(value) => value
            case None => return Result<JsValue>.Err("S3 writeFileInternal supports string, Buffer, ArrayBuffer, DataView, TypedArray, or in-memory Blob uploads")
        }
        let store = pathOrBlob.blob.store.getOrThrow()
        let contentType = pathOrBlob.blob.contentType
        return store.data().asS3().upload(store, global, body.content, body.bytesWritten, contentType)
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

/// S3SignResult - S3 签名结果 (对应 Bun: bun_s3_signing::SignResult)
public class S3SignResult {
    public var url: String
    public var method: String
    public var headers: HttpHeaders

    public init() {
        url = ""
        method = ""
        headers = HttpHeaders()
    }

    public func toHttpHeaders(): HttpHeaders {
        return headers
    }

    public func mixWithHeader(key: String, value: String): HttpHeaders {
        let mixed = headers.clone()
        mixed.set(key, value)
        return mixed
    }

    public func deinit(): Unit {}
}

/// ResumableS3UploadSink - S3 上传流 Sink (对应 Bun: ResumableSink)
public class ResumableS3UploadSink {
    public var global: GlobalRef
    public var refCount: Int32

    public init() {
        global = GlobalRef()
        refCount = 0
    }

    public init(global: GlobalRef, stream: ReadableStream, wrapper: S3UploadStreamWrapper, count: Int32) {
        this.global = global
        this.refCount = count
    }

    public func deref(): ResumableS3UploadSink { return this }
    public func drain(): Unit {}
    public func cancel(err: JsValue): Unit {}
}

/// ReadableStream (对应 Bun: bun ReadableStream)
/// ReadableStream (对应 Bun: bun ReadableStream)
public class ReadableStream {
    public var _ptr: ReadableStreamPtr
    public var _value: JsValue

    public init() {
        _ptr = ReadableStreamPtr.INVALID
        _value = JsValue.undefined()
    }
    public init(ptr: ReadableStreamPtr, value: JsValue) {
        _ptr = ptr
        _value = value
    }
    public func isDisturbed(globalThis: JsGlobalObject): Bool { return false }
    public func ptr(): ?ReadableStreamPtr { return Some(_ptr) }
    public func getByteStream(): ?ByteStream {
        match (_ptr) {
            case ReadableStreamPtr.BYTES(bs) => return Some(bs)
            case ReadableStreamPtr.INVALID => return None
        }
    }
}

/// ReadableStreamPtr
public enum ReadableStreamPtr {
    | BYTES(ByteStream)
    | INVALID
}

/// GlobalRef (对应 Bun: jsc.GlobalRef)
public class GlobalRef {
    private var global: JsGlobalObject

    public init() {
        global = JsGlobalObject()
    }

    public init(global: JsGlobalObject) {
        this.global = global
    }

    public static func from(global: JsGlobalObject): GlobalRef {
        return GlobalRef(global)
    }

    public func get(): JsGlobalObject {
        return global
    }
}

// ported from: src/runtime/webcore/S3Client.rs

// ============================================================================
// 占位类型 — 来自其他模块的引用 (external types used in download_stream, client, etc.)
// ============================================================================

/// HttpHeaders (对应 Bun: bun.http.Headers)
public class HttpHeaders {
    private var entries: ArrayList<HttpHeaderEntry>
    public var response: HttpResponse = HttpResponse()

    public init() {
        entries = ArrayList<HttpHeaderEntry>()
    }

    public func deinit(): Unit {
        entries.clear()
    }

    public func set(name: String, value: String): Unit {
        let lower = name.toLower()
        for (i in 0..entries.size) {
            if (entries[i].name == lower) {
                entries[i].value = value
                return
            }
        }
        entries.append(HttpHeaderEntry(lower, value))
    }

    public func get(name: String): ?String {
        let lower = name.toLower()
        for (entry in entries) {
            if (entry.name == lower) {
                return Some(entry.value)
            }
        }
        return None
    }

    public func toBaoHeaderEntryList(): BaoHeaderEntryList {
        let list = BaoHeaderEntryList()
        for (entry in entries) {
            list.append(entry.name, entry.value)
        }
        return list
    }

    public func clone(): HttpHeaders {
        let cloned = HttpHeaders()
        cloned.response.statusCode = response.statusCode
        for (entry in entries) {
            cloned.set(entry.name, entry.value)
        }
        return cloned
    }

    public static func fromBaoHttpMetadata(metadata: BaoHTTPResponseMetadata): HttpHeaders {
        let headers = HttpHeaders()
        match (metadata.response) {
            case Some(response) =>
                headers.response.statusCode = UInt32(response.statusCode)
                for (entry in response.headers) {
                    headers.set(entry.name, entry.value)
                }
            case None => ()
        }
        return headers
    }
}

public class HttpHeaderEntry {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

/// HttpResponse (stub for response metadata)
public class HttpResponse {
    public init() {}
    public var statusCode: UInt32 = 0
}

/// AsyncHttp (对应 Bun: bun.http.AsyncHTTP)
public class AsyncHttp {
    public init() {}
    public init(method: HttpMethod, url: String, headers: HttpHeaders, body: String, proxyUrl: String, signalStore: SignalStore, signals: HttpSignals) {}
    public func schedule(batch: ThreadPoolBatch): Unit {}
    public func enableResponseBodyStreaming(): Unit {}
    public func clearData(): Unit {}
}

/// VirtualMachine (对应 Bun: jsc.VirtualMachine)
public class VirtualMachine {
    public init() {}
    public static func get(): VirtualMachine { return VirtualMachine() }
    public func getVerboseFetch(): Bool { return false }
    public func getTlsRejectUnauthorized(): Bool { return true }
    public func eventLoop(): EventLoop { return EventLoop() }
}

/// UrlParser (对应 Bun: URL parser)
public class UrlParser {
    public static func parse(url: String): Url { return Url() }
    public static func hostWithPath(url: String): String { return url }
}

/// Url (对应 Bun: URL)
public class Url {
    public init() {}
    public var href: String = ""
    public func toString(): String { return href }
}

/// HTTPThread (对应 Bun: HTTPThread)
public class HTTPThread {
    public init() {}
    public static func schedule(batch: ThreadPoolBatch): Unit {}
}

/// ThreadPoolBatch (对应 Bun: ThreadPoolBatch)
public class ThreadPoolBatch {
    public init() {}
}

/// NetworkSink (对应 Bun: NetworkSink)
public class NetworkSink {
    public var task: ?MultiPartUpload
    public var globalThis: ?GlobalRef
    public var highWaterMark: Int64
    public var signal: SinkSignal

    public init() {
        task = None
        globalThis = None
        highWaterMark = 0
        signal = SinkSignal()
    }
    public static func fromOpaque(ctx: UIntNative): NetworkSink { return NetworkSink() }
    public func toOpaque(): UIntNative { return 0 }
    public func toJS(globalThis: JsGlobalObject): JsValue { return JsValue(0) }
    public static func onWritable(task: MultiPartUpload, sink: NetworkSink, flushed: UInt64): Unit {}
}

/// SinkSignal (对应 Bun: SinkSignal)
public class SinkSignal {
    public init() {}
    public func clear(): Unit {}
}

/// S3ErrorCodeAndMessage
public class S3ErrorCodeAndMessage {
    public var code: String
    public var message: String
    public init() { code = ""; message = "" }
    public init(code: String, message: String) { this.code = code; this.message = message }
}

/// ReadableStreamStrong (对应 Bun: ReadableStream strong ref)
public class ReadableStreamStrong {
    private var stream: ?ReadableStream
    private var global: ?JsGlobalObject

    public init() {
        stream = None
        global = None
    }
    public init(stream: ReadableStream, globalThis: JsGlobalObject) {
        this.stream = Some(stream)
        this.global = Some(globalThis)
    }
    public func get(ref: GlobalRef): ?ReadableStream {
        return stream
    }
    public func deinit(): Unit {
        stream = None
        global = None
    }
}

/// SignalStore (对应 Bun: bun.http.Signals.Store)
public class SignalStore {
    public init() {}
}

/// HttpSignals (对应 Bun: bun.http.Signals)
public class HttpSignals {
    public init() {}
}

/// KeepAlive (对应 Bun: bun.Async.KeepAlive)
public class KeepAlive {
    public init() {}
    public func ref(vm: VirtualMachine): Unit {}
    public func unref(vm: VirtualMachine): Unit {}
}

/// ConcurrentTask (对应 Bun: jsc.ConcurrentTask)
public class ConcurrentTask {
    public init() {}
    public func from(obj: Object): ConcurrentTask { return this }
}

/// EventLoop (stub)
public class EventLoop {
    public init() {}
    public func enqueueTaskConcurrent(task: ConcurrentTask): Unit {}
}

/// ByteStream (对应 Bun: ByteStream)
public class ByteStream {
    public init() {}
    public func onData(data: ArrayList<UInt8>, done: Bool): Unit {}
    public func setup(): Unit {}
}

/// ByteStreamSource (stub for bao_runtime.webcore.ByteStreamSource)
public class ByteStreamSource {
    public var context: ByteStream
    public var globalThis: ?JsGlobalObject
    public var cancelHandler: ?((?UIntNative) -> Unit)
    public var cancelCtx: ?UIntNative

    public init() {
        context = ByteStream()
        globalThis = None
        cancelHandler = None
        cancelCtx = None
    }
    public func toReadableStream(globalThis: JsGlobalObject): JsValue {
        return JsValue.undefined()
    }
}

/// Mutex (对应 Bun: bun.Mutex)
public class Mutex {
    public init() {}
    public func lock(): Unit {}
    public func unlock(): Unit {}
}

/// HttpClientResult (对应 Bun: bun.http.HTTPClientResult)
public class HttpClientResult {
    public init() {}
    public var hasMore: Bool = true
    public var fail: Bool = false
    public var metadata: ?HttpHeaders = None
    public var body: ?MutableString = None

    public static func fromBaoHttp(result: BaoHTTPClientResult): HttpClientResult {
        let converted = HttpClientResult()
        converted.hasMore = result.hasMore
        converted.fail = result.fail.isSome()
        converted.body = result.body
        match (result.metadata) {
            case Some(metadata) => converted.metadata = Some(HttpHeaders.fromBaoHttpMetadata(metadata))
            case None => converted.metadata = None
        }
        return converted
    }
}

/// HttpMethod (对应 Bun: bun_http::Method)
public enum HttpMethod {
    | GET
    | PUT
    | POST
    | DELETE
    | HEAD
    | PATCH
    | OPTIONS
    | CONNECT
    | TRACE

    public func toBaoHttpMethod(): BaoHttpMethod {
        match (this) {
            case GET => BaoHttpMethod.GET
            case PUT => BaoHttpMethod.PUT
            case POST => BaoHttpMethod.POST
            case DELETE => BaoHttpMethod.DELETE
            case HEAD => BaoHttpMethod.HEAD
            case PATCH => BaoHttpMethod.PATCH
            case OPTIONS => BaoHttpMethod.OPTIONS
            case CONNECT => BaoHttpMethod.CONNECT
            case TRACE => BaoHttpMethod.TRACE
        }
    }
}

// ============================================================================
// Disambiguation types - shadows conflicting imports from bao_core and bao_jsc
// These are local to this package and override the wildcard imports
// ============================================================================

/// Result<T> - shadows bao_jsc.Result<T> and bao_core.Result<T, E>
public enum Result<T> {
    | Ok(T)
    | Err(String)

    public static func ok(value: T): Result<T> {
        Result<T>.Ok(value)
    }

    public static func err(msg: String): Result<T> {
        Result<T>.Err(msg)
    }

    public func isOk(): Bool {
        match (this) {
            case Ok(_) => true
            case Err(_) => false
        }
    }

    public func isErr(): Bool {
        match (this) {
            case Ok(_) => false
            case Err(_) => true
        }
    }
}

/// StringBuilder - shadows bao_jsc.StringBuilder
public class StringBuilder {
    private var buf: String
    public init() { buf = "" }
    public func append(s: String): StringBuilder { buf = buf + s; return this }
    public func toString(): String { buf }
}
