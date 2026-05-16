// S3Client - S3 客户端
// 严格翻译自: src/runtime/webcore/S3Client.rs
//   Bun 的 S3Client 模块:
//   - S3Client: JS 类, 包装 S3Credentials + options
//   - constructor: 从 JS 参数解析凭证
//   - file(): 创建 S3File 引用
//   - presign(): 生成预签名 URL
//   - exists()/size()/stat(): 对象元数据查询
//   - write(): 写入对象
//   - listObjects(): 列出对象
//   - unlink(): 删除对象
//   - writeFormatCredentials: 格式化凭证输出
//   - static_*: 静态方法 (无需实例化)
//   仓颉: 提供兼容的 S3 客户端接口
package bao_runtime.webcore.s3

import bao_core.*
import bao_jsc.*

// ============================================================================
// S3Client - S3 客户端
// 严格翻译自: src/runtime/webcore/S3Client.rs
//   #[bun_jsc::JsClass]
//   pub struct S3Client {
//       pub credentials: IntrusiveRc<S3Credentials>,
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
    /// 对应 Bun: pub credentials: IntrusiveRc<S3Credentials>
    public var credentials: S3Credentials

    /// 分片上传选项
    /// 对应 Bun: pub options: MultiPartUploadOptions
    public var options: MultiPartUploadOptions

    /// ACL (访问控制列表)
    /// 对应 Bun: pub acl: Option<ACL>
    public var acl: ?ACL

    /// 存储类型
    /// 对应 Bun: pub storage_class: Option<StorageClass>
    public var storageClass: ?StorageClass

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
                acl: ?ACL, storageClass: ?StorageClass, requestPayer: Bool) {
        this.credentials = credentials
        this.options = options
        this.acl = acl
        this.storageClass = storageClass
        this.requestPayer = requestPayer
    }

    /// 释放资源
    /// 对应 Bun: impl Drop for S3Client { fn drop() { self.credentials.deref() } }
    ///   IntrusiveRc<T> is RefPtr<T>, the +1 taken by dupe() in constructor
    ///   must be released explicitly.
    public func deinit(): Unit {
        credentials.deref()
    }

    // ========================================================================
    // JS 构造函数
    // 严格翻译自: S3Client::constructor
    // ========================================================================

    /// JS 构造函数
    /// 对应 Bun: pub fn constructor(global, callframe) -> JsResult<Box<Self>>
    ///
    /// 步骤:
    ///   1. 获取环境变量中的默认凭证
    ///   2. 从 JS 参数解析凭证和选项
    ///   3. 构建 S3Client 实例
    public static func constructor(global: JSGlobalObject, callframe: CallFrame): Result<S3Client> {
        let args = callframe.arguments(1)

        // 获取环境变量中的默认凭证
        let envCreds = FetchModule.s3CredentialsFromEnv(global)

        // 从 JS 参数解析凭证和选项
        let awsOptions = S3Credentials.getCredentialsWithOptions(
            envCreds,
            MultiPartUploadOptions.default(),
            args.next(),
            None,
            None,
            false,
            global
        )

        match (awsOptions) {
            case Ok(opts) => {
                let client = S3Client(
                    credentials: opts.credentials.dupe(),
                    options: opts.options,
                    acl: opts.acl,
                    storageClass: opts.storageClass,
                    requestPayer: opts.requestPayer
                )
                return Result<S3Client>.Ok(client)
            }
            case Err(e) => return Result<S3Client>.Err(e)
        }
    }

    // ========================================================================
    // 实例方法
    // 严格翻译自: S3Client 的 host_fn(method)
    // ========================================================================

    /// 创建 S3File 引用
    /// 对应 Bun: pub fn file(ptr, global, callframe) -> JsResult<JSValue>
    ///
    /// 创建一个指向 S3 路径的 S3File (Blob) 对象。
    /// S3File 延迟加载 — 只在需要时才发起网络请求。
    public func file(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        let args = callframe.arguments(2)
        let path = PathLike.fromJs(global, args)
        match (path) {
            case Some(p) => {
                let options = args.next()
                let blob = S3File.constructS3FileWithS3CredentialsAndOptions(
                    global, p, options,
                    credentials, options, acl, storageClass, requestPayer
                )
                match (blob) {
                    case Ok(b) => return Result<JSValue>.Ok(b.toJs(global))
                    case Err(e) => return Result<JSValue>.Err(e)
                }
            }
            case None => {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.MissingArgs, "Expected a path")
                )
            }
        }
    }

    /// 生成预签名 URL
    /// 对应 Bun: pub fn presign(ptr, global, callframe) -> JsResult<JSValue>
    public func presign(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        let args = callframe.arguments(2)
        let path = PathLike.fromJs(global, args)
        match (path) {
            case Some(p) => {
                let options = args.next()
                let blobResult = S3File.constructS3FileWithS3CredentialsAndOptions(
                    global, p, options,
                    credentials, options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(mut blob) => {
                        return S3File.getPresignUrlFrom(blob, global, options)
                    }
                    case Err(e) => return Result<JSValue>.Err(e)
                }
            }
            case None => {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.MissingArgs, "Expected a path to presign")
                )
            }
        }
    }

    /// 检查对象是否存在
    /// 对应 Bun: pub fn exists(ptr, global, callframe) -> JsResult<JSValue>
    public func exists(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        let args = callframe.arguments(2)
        let path = PathLike.fromJs(global, args)
        match (path) {
            case Some(p) => {
                let options = args.next()
                let blobResult = S3File.constructS3FileWithS3CredentialsAndOptions(
                    global, p, options,
                    credentials, options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(mut blob) => {
                        return S3BlobStatTask.exists(global, blob)
                    }
                    case Err(e) => return Result<JSValue>.Err(e)
                }
            }
            case None => {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.MissingArgs, "Expected a path to check if it exists")
                )
            }
        }
    }

    /// 获取对象大小
    /// 对应 Bun: pub fn size(ptr, global, callframe) -> JsResult<JSValue>
    public func size(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        let args = callframe.arguments(2)
        let path = PathLike.fromJs(global, args)
        match (path) {
            case Some(p) => {
                let options = args.next()
                let blobResult = S3File.constructS3FileWithS3CredentialsAndOptions(
                    global, p, options,
                    credentials, options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(mut blob) => {
                        return S3BlobStatTask.size(global, blob)
                    }
                    case Err(e) => return Result<JSValue>.Err(e)
                }
            }
            case None => {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.MissingArgs, "Expected a path to check the size of")
                )
            }
        }
    }

    /// 获取对象元数据
    /// 对应 Bun: pub fn stat(ptr, global, callframe) -> JsResult<JSValue>
    public func stat(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        let args = callframe.arguments(2)
        let path = PathLike.fromJs(global, args)
        match (path) {
            case Some(p) => {
                let options = args.next()
                let blobResult = S3File.constructS3FileWithS3CredentialsAndOptions(
                    global, p, options,
                    credentials, options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(mut blob) => {
                        return S3BlobStatTask.stat(global, blob)
                    }
                    case Err(e) => return Result<JSValue>.Err(e)
                }
            }
            case None => {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.MissingArgs, "Expected a path to check the stat of")
                )
            }
        }
    }

    /// 写入对象
    /// 对应 Bun: pub fn write(ptr, global, callframe) -> JsResult<JSValue>
    ///
    /// 将 Blob 数据写入 S3 路径。
    /// 支持分片上传 (multipart upload) 和单次上传 (putObject)。
    public func write(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        let args = callframe.arguments(3)
        let path = PathLike.fromJs(global, args)
        match (path) {
            case Some(p) => {
                let data = args.next()
                match (data) {
                    case Some(d) => {
                        let writeOptions = args.next()
                        let blobResult = S3File.constructS3FileWithS3CredentialsAndOptions(
                            global, p, writeOptions,
                            credentials, options, acl, storageClass, requestPayer
                        )
                        match (blobResult) {
                            case Ok(blob) => {
                                let mut blobInternal = PathOrBlob.Blob(blob)
                                return WriteFileModule.writeFileInternal(
                                    global,
                                    blobInternal,
                                    d,
                                    WriteFileOptions(
                                        mkdirpIfExists: Some(false),
                                        extraOptions: writeOptions,
                                        mode: None
                                    )
                                )
                            }
                            case Err(e) => return Result<JSValue>.Err(e)
                        }
                    }
                    case None => {
                        return Result<JSValue>.Err(
                            BaoError(ErrorCode.MissingArgs, "Expected a Blob-y thing to write")
                        )
                    }
                }
            }
            case None => {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.MissingArgs, "Expected a path to write to")
                )
            }
        }
    }

    /// 列出对象
    /// 对应 Bun: pub fn list_objects(ptr, global, callframe) -> JsResult<JSValue>
    public func listObjects(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        let args = callframe.argumentsAsArray(2)
        let objectKeys = args[0]
        let options = optJs(args[1])

        let blobResult = S3File.constructS3FileWithS3CredentialsAndOptions(
            global, PathLike.default(), options,
            credentials, options, None, None, requestPayer
        )
        match (blobResult) {
            case Ok(blob) => {
                let store = blob.store.get()
                match (store) {
                    case Some(s) => {
                        return s.data.asS3().listObjects(s, global, objectKeys, options)
                    }
                    case None => {
                        return Result<JSValue>.Err(
                            BaoError(ErrorCode.Unexpected, "S3 store not available")
                        )
                    }
                }
            }
            case Err(e) => return Result<JSValue>.Err(e)
        }
    }

    /// 删除对象
    /// 对应 Bun: pub fn unlink(ptr, global, callframe) -> JsResult<JSValue>
    public func unlink(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        let args = callframe.arguments(2)
        let path = PathLike.fromJs(global, args)
        match (path) {
            case Some(p) => {
                let options = args.next()
                let blobResult = S3File.constructS3FileWithS3CredentialsAndOptions(
                    global, p, options,
                    credentials, options, acl, storageClass, requestPayer
                )
                match (blobResult) {
                    case Ok(blob) => {
                        let store = blob.store.get()
                        match (store) {
                            case Some(s) => {
                                return s.data.asS3().unlink(s, global, options)
                            }
                            case None => {
                                return Result<JSValue>.Err(
                                    BaoError(ErrorCode.Unexpected, "S3 store not available")
                                )
                            }
                        }
                    }
                    case Err(e) => return Result<JSValue>.Err(e)
                }
            }
            case None => {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.MissingArgs, "Expected a path to unlink")
                )
            }
        }
    }

    // ========================================================================
    // 格式化输出
    // 严格翻译自: S3Client::write_format / write_format_credentials
    // ========================================================================

    /// 格式化 S3Client 输出
    /// 对应 Bun: pub fn write_format<F, W, const ENABLE_ANSI_COLORS: bool>(
    ///     &self, formatter, writer) -> fmt::Result
    public func writeFormat(formatter: ConsoleFormatter, writer: StringBuilder, enableAnsiColors: Bool): Unit {
        let bucketName: String = getBucketName()
        if (bucketName.size > 0) {
            writer.append("S3Client (\"${bucketName}\") {\n")
        } else {
            writer.append("S3Client {\n")
        }

        writeFormatCredentials(credentials, options, acl, formatter, writer, enableAnsiColors)
        writer.append("}")
    }

    /// 格式化凭证输出
    /// 对应 Bun: pub fn write_format_credentials<F, W, const ENABLE_ANSI_COLORS: bool>(
    ///     credentials, options, acl, formatter, writer) -> fmt::Result
    public static func writeFormatCredentials(
        credentials: S3Credentials,
        options: MultiPartUploadOptions,
        acl: ?ACL,
        formatter: ConsoleFormatter,
        writer: StringBuilder,
        enableAnsiColors: Bool
    ): Unit {
        writer.append("\n")

        // endpoint
        let endpoint: String = if (credentials.endpoint.size > 0) {
            credentials.endpoint
        } else if (credentials.virtualHostedStyle) {
            "https://<bucket>.s3.<region>.amazonaws.com"
        } else {
            "https://s3.<region>.amazonaws.com"
        }
        formatter.writeIndent(writer)
        writer.append("endpoint: \"${endpoint}\",\n")

        // region
        let region: String = if (credentials.region.size > 0) {
            credentials.region
        } else {
            S3Credentials.guessRegion(credentials.endpoint)
        }
        formatter.writeIndent(writer)
        writer.append("region: \"${region}\",\n")

        // accessKeyId — 不打印实际值, 只显示 [REDACTED]
        if (credentials.accessKeyId.size > 0) {
            formatter.writeIndent(writer)
            writer.append("accessKeyId: \"[REDACTED]\",\n")
        }

        // secretAccessKey — 不打印实际值, 只显示 [REDACTED]
        if (credentials.secretAccessKey.size > 0) {
            formatter.writeIndent(writer)
            writer.append("secretAccessKey: \"[REDACTED]\",\n")
        }

        // sessionToken — 不打印实际值, 只显示 [REDACTED]
        if (credentials.sessionToken.size > 0) {
            formatter.writeIndent(writer)
            writer.append("sessionToken: \"[REDACTED]\",\n")
        }

        // acl
        match (acl) {
            case Some(aclValue) => {
                formatter.writeIndent(writer)
                writer.append("acl: \"${aclValue.toString()}\",\n")
            }
            case None => ()
        }

        // partSize
        formatter.writeIndent(writer)
        writer.append("partSize: ${Float64(options.partSize)},\n")

        // queueSize
        formatter.writeIndent(writer)
        writer.append("queueSize: ${Float64(options.queueSize)},\n")

        // retry
        formatter.writeIndent(writer)
        writer.append("retry: ${Float64(options.retry)},\n")
    }

    /// 获取 bucket 名称 (检测 virtual-hosted-style)
    private func getBucketName(): String {
        if (credentials.virtualHostedStyle && credentials.endpoint.size > 0) {
            let guessed = S3Credentials.guessBucket(credentials.endpoint)
            match (guessed) {
                Some(name) => return name
                None => ()
            }
        }
        return credentials.bucket
    }

    // ========================================================================
    // 静态方法
    // 严格翻译自: S3Client 的 static_* 方法
    //   Codegen emits S3ClientClass__static* extern wrappers that call these.
    // ========================================================================

    /// 静态 write
    /// 对应 Bun: pub fn static_write(global, callframe) -> JsResult<JSValue>
    public static func staticWrite(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        return S3File.write(global, callframe)
    }

    /// 静态 presign
    /// 对应 Bun: pub fn static_presign(global, callframe) -> JsResult<JSValue>
    public static func staticPresign(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        return S3File.presign(global, callframe)
    }

    /// 静态 exists
    /// 对应 Bun: pub fn static_exists(global, callframe) -> JsResult<JSValue>
    public static func staticExists(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        return S3File.exists(global, callframe)
    }

    /// 静态 size
    /// 对应 Bun: pub fn static_size(global, callframe) -> JsResult<JSValue>
    public static func staticSize(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        return S3File.size(global, callframe)
    }

    /// 静态 unlink
    /// 对应 Bun: pub fn static_unlink(global, callframe) -> JsResult<JSValue>
    public static func staticUnlink(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        return S3File.unlink(global, callframe)
    }

    /// 静态 file
    /// 对应 Bun: pub fn static_file(global, callframe) -> JsResult<JSValue>
    public static func staticFile(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        let args = callframe.arguments(2)
        let path = PathLike.fromJs(global, args)
        match (path) {
            case Some(p) => {
                return S3File.constructInternalJs(global, p, args.next())
            }
            case None => {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected file path string")
                )
            }
        }
    }

    /// 静态 stat
    /// 对应 Bun: pub fn static_stat(global, callframe) -> JsResult<JSValue>
    public static func staticStat(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        return S3File.stat(global, callframe)
    }

    /// 静态 listObjects
    /// 对应 Bun: pub fn static_list_objects(global, callframe) -> JsResult<JSValue>
    public static func staticListObjects(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        let args = callframe.argumentsAsArray(2)
        let objectKeys = args[0]
        let options = optJs(args[1])

        // 从环境变量获取凭证
        let existingCredentials = FetchModule.s3CredentialsFromEnv(global)

        let blobResult = S3File.constructS3FileWithS3Credentials(
            global, PathLike.default(), options, existingCredentials
        )
        match (blobResult) {
            case Ok(blob) => {
                let store = blob.store.get()
                match (store) {
                    case Some(s) => {
                        return s.data.asS3().listObjects(s, global, objectKeys, options)
                    }
                    case None => {
                        return Result<JSValue>.Err(
                            BaoError(ErrorCode.Unexpected, "S3 store not available")
                        )
                    }
                }
            }
            case Err(e) => return Result<JSValue>.Err(e)
        }
    }

    // ========================================================================
    // S3CredentialsExt 扩展 trait
    // 严格翻译自: S3Client.rs 中的 S3CredentialsExt trait
    // ========================================================================

    /// 辅助: 检查 JSValue 是否为空/undefined/null
    /// 对应 Bun: fn opt_js(v: JSValue) -> Option<JSValue>
    private static func optJs(v: JSValue): ?JSValue {
        if (v.isEmptyOrUndefinedOrNull()) {
            return None
        }
        return Some(v)
    }
}

// ============================================================================
// S3CredentialsExt - S3Credentials 扩展
// 严格翻译自: S3Client.rs 中的 S3CredentialsExt trait
//   Surface guessRegion/guessBucket/getCredentialsWithOptions as associated fns
//   so call sites keep their Zig shape (S3Credentials.guessRegion(...)).
// ============================================================================

/// S3Credentials 的扩展方法
/// 对应 Bun: pub trait S3CredentialsExt
public class S3CredentialsExt {
    /// 猜测 region
    /// 对应 Bun: fn guess_region(endpoint: &[u8]) -> &[u8]
    public static func guessRegion(endpoint: String): String {
        return S3Signing.guessRegion(endpoint)
    }

    /// 猜测 bucket
    /// 对应 Bun: fn guess_bucket(endpoint: &[u8]) -> Option<&[u8]>
    public static func guessBucket(endpoint: String): ?String {
        return S3Signing.guessBucket(endpoint)
    }

    /// 从 JS 参数获取凭证和选项
    /// 对应 Bun: fn get_credentials_with_options(...)
    public static func getCredentialsWithOptions(
        defaultCredentials: S3Credentials,
        defaultOptions: MultiPartUploadOptions,
        options: ?JSValue,
        defaultAcl: ?ACL,
        defaultStorageClass: ?StorageClass,
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
