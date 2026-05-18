// S3File - S3 文件对象
// 严格翻译自: src/runtime/webcore/S3File.rs (1048 lines)
//   Bun 的 S3File 模块:
//   - writeFormat: 格式化 S3Ref 输出 (endpoint, bucket, path, contentType, offset)
//   - presign: 生成预签名 URL (path/blob -> presigned URL)
//   - unlink: 删除 S3 对象 (path/blob -> delete)
//   - write: 写入 S3 对象 (path/blob + data -> upload)
//   - size: 获取对象大小 (path/blob -> size)
//   - exists: 检查对象是否存在 (path/blob -> bool)
//   - stat: 获取对象元数据 (path/blob -> S3Stat)
//   - constructS3FileWithS3CredentialsAndOptions: 带 credentials+options 构造 S3 Blob
//   - constructS3FileWithS3Credentials: 带 credentials 构造 S3 Blob
//   - constructS3FileInternalStore: 从 env 构造 S3 Blob
//   - constructS3FileInternal: 堆分配的 Blob
//   - constructInternalJs: JS 构造 (返回 JSValue)
//   - constructInternal: 从 callframe 构造 *mut Blob
//   - construct: JS 构造函数 (处理 JsError)
//   - hasInstance: instanceof 检查
//   - S3BlobStatTask: 异步 stat 任务 (exists/size/stat)
//   - getPresignUrlFrom: 从 Blob 获取预签名 URL
//   - getBucketName / getBucket / getPresignUrl / getStat: Blob getter 方法
//   - exports 模块: JSS3File__hasInstance, JSS3File__construct, JSS3File__bucket, JSS3File__presign, JSS3File__stat
//   - BUN__createJSS3File / BUN__createJSS3FileUnsafely: C++ ABI 函数
//   - createJsS3File: host_fn 包装器
//   仓颉: 提供兼容的 S3 文件操作接口
package bao_runtime.webcore.s3

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_http_types.*

// ============================================================================
// S3Ref 格式化输出
// 严格翻译自: S3File.write_format (lines 34-119)
//   Bun: pub fn write_format<F, W, const ENABLE_ANSI_COLORS: bool>(
//       s3: &blob::store::S3, formatter, writer, content_type, offset
//   ) -> fmt::Result
// ============================================================================

/// 格式化 S3Ref 输出
/// 对应 Bun: write_format
///
/// 输出格式:
///   S3Ref ("bucket/path") {
///     type: "content-type",
///     offset: N,
///     endpoint: "...",
///     region: "...",
///     accessKeyId: "[REDACTED]",
///     ...
///   }
public func writeFormat(
    s3: S3Store,
    formatter: ConsoleFormatter,
    writer: StringBuilder,
    contentType: Array<UInt8>,
    offset: UInt64,
    enableAnsiColors: Bool
): Unit {
    writer.append("S3Ref")

    // detect virtual host style bucket name
    let credentials = s3.getCredentials()
    let bucketName: Array<UInt8> = if (credentials.virtualHostedStyle && credentials.endpoint.size > 0) {
        match (S3CredentialsExt.guessBucket(credentials.endpoint)) {
            case Some(name) => name.toUtf8Array()
            case None => credentials.bucket.toUtf8Array()
        }
    } else {
        credentials.bucket.toUtf8Array()
    }

    if (bucketName.size > 0) {
        writer.append(" (\"")
        writer.append(String.fromUtf8Array(bucketName))
        writer.append("/")
        writer.append(s3.path())
        writer.append("\") {")
    } else {
        writer.append(" (\"")
        writer.append(s3.path())
        writer.append("\") {")
    }

    if (contentType.size > 0) {
        writer.append("\n")
        let indented = formatter.indented()
        indented.writeIndent(writer)
        writer.append("type: \"")
        writer.append(String.fromUtf8Array(contentType))
        writer.append("\"")
        indented.printComma(writer, enableAnsiColors)
        if (offset > 0) {
            writer.append("\n")
        }
    }

    if (offset > 0) {
        let indented = formatter.indented()
        indented.writeIndent(writer)
        writer.append("offset: ${offset}")
        indented.printComma(writer, enableAnsiColors)
    }

    S3Client.writeFormatCredentials(credentials, s3.options, s3.acl, formatter, writer, enableAnsiColors)
    formatter.writeIndent(writer)
    writer.append("}")
    formatter.resetLine()
}

// ============================================================================
// presign - 生成预签名 URL
// 严格翻译自: S3File.presign (lines 122-156)
//   Bun: #[bun_jsc::host_fn]
//   pub fn presign(global: &JSGlobalObject, callframe: &CallFrame) -> JsResult<JSValue>
// ============================================================================

/// 生成预签名 URL (host_fn)
/// 对应 Bun: presign
///
/// 接受 path 或 blob 参数, 生成预签名 URL。
/// 支持 S3 路径格式: s3://bucket/key 或已有的 S3 Blob 对象。
public func presign(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
    let args = callframe.arguments(3)

    // accept a path or a blob
    let pathOrBlob = PathOrBlob.fromJsNoCopy(global, args)

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Blob => {
            let blob = pathOrBlob.blob
            if (blob.store.isNone()) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to presign")
                )
            }
            let storeData = blob.store.getOrThrow().data()
            if (storeData.tag != StoreDataTagForBlob.S3) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to presign")
                )
            }
        }
        case _ => ()
    }

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Path => {
            if (pathOrBlob.path.tag == PathOrFileDescriptorTag.Fd) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to presign")
                )
            }
            let options = args.next()
            let blobResult = constructS3FileInternalStore(global, pathOrBlob.path.pathString, options)
            match (blobResult) {
                case Ok(mut blob) => {
                    return getPresignUrlFrom(blob, global, options)
                }
                case Err(e) => return Result<JSValue>.Err(e)
            }
        }
        case PathOrBlobTag.Blob => {
            let options = args.next()
            return getPresignUrlFrom(pathOrBlob.blob, global, options)
        }
        case _ => {
            return Result<JSValue>.Err(
                BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to presign")
            )
        }
    }
}

// ============================================================================
// unlink - 删除 S3 对象
// 严格翻译自: S3File.unlink (lines 158-197)
//   Bun: #[bun_jsc::host_fn]
//   pub fn unlink(global: &JSGlobalObject, callframe: &CallFrame) -> JsResult<JSValue>
// ============================================================================

/// 删除 S3 对象 (host_fn)
/// 对应 Bun: unlink
///
/// 接受 path 或 blob 参数, 删除 S3 对象。
public func unlink(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
    let args = callframe.arguments(3)

    // accept a path or a blob
    let pathOrBlob = PathOrBlob.fromJsNoCopy(global, args)

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Blob => {
            let blob = pathOrBlob.blob
            if (blob.store.isNone()) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to delete")
                )
            }
            let storeData = blob.store.getOrThrow().data()
            if (storeData.tag != StoreDataTagForBlob.S3) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to delete")
                )
            }
        }
        case _ => ()
    }

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Path => {
            if (pathOrBlob.path.tag == PathOrFileDescriptorTag.Fd) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to delete")
                )
            }
            let options = args.next()
            let blobResult = constructS3FileInternalStore(global, pathOrBlob.path.pathString, options)
            match (blobResult) {
                case Ok(blob) => {
                    let store = blob.store.getOrThrow()
                    return store.data.asS3().unlink(store, global, options)
                }
                case Err(e) => return Result<JSValue>.Err(e)
            }
        }
        case PathOrBlobTag.Blob => {
            let options = args.next()
            let store = pathOrBlob.blob.store.getOrThrow()
            return store.data.asS3().unlink(store, global, options)
        }
        case _ => {
            return Result<JSValue>.Err(
                BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to delete")
            )
        }
    }
}

// ============================================================================
// write - 写入 S3 对象
// 严格翻译自: S3File.write (lines 199-267)
//   Bun: #[bun_jsc::host_fn]
//   pub fn write(global: &JSGlobalObject, callframe: &CallFrame) -> JsResult<JSValue>
// ============================================================================

/// 写入 S3 对象 (host_fn)
/// 对应 Bun: write
///
/// 接受 path 或 blob + data 参数, 写入 S3。
/// 支持分片上传 (multipart upload) 和单次上传 (putObject)。
public func write(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
    let args = callframe.arguments(3)

    // accept a path or a blob
    let pathOrBlob = PathOrBlob.fromJsNoCopy(global, args)

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Blob => {
            let blob = pathOrBlob.blob
            if (blob.store.isNone()) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to upload")
                )
            }
            let storeData = blob.store.getOrThrow().data()
            if (storeData.tag != StoreDataTagForBlob.S3) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to upload")
                )
            }
        }
        case _ => ()
    }

    let data = args.next()
    match (data) {
        case Some(d) => {
            // continue
        }
        case None => {
            return Result<JSValue>.Err(
                BaoError(ErrorCode.MissingArgs, "Expected a Blob-y thing to upload")
            )
        }
    }

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Path => {
            let writeOptions = args.next()
            if (pathOrBlob.path.tag == PathOrFileDescriptorTag.Fd) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to upload")
                )
            }
            let blobResult = constructS3FileInternalStore(global, pathOrBlob.path.pathString, writeOptions)
            match (blobResult) {
                case Ok(blob) => {
                    // PORT NOTE: reshaped for borrowck — match consumes pathOrBlob;
                    // rebuild to pass PathOrBlob
                    let mut blobInternal = PathOrBlob.fromBlob(blob)
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
                }
                case Err(e) => return Result<JSValue>.Err(e)
            }
        }
        case PathOrBlobTag.Blob => {
            // PORT NOTE: reshaped for borrowck
            let mut pob = pathOrBlob
            return WriteFileModule.writeFileInternal(
                global,
                pob,
                data.getOrThrow(),
                WriteFileOptions(
                    mkdirpIfExists: Some(false),
                    extraOptions: args.next(),
                    mode: None
                )
            )
        }
        case _ => {
            return Result<JSValue>.Err(
                BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to upload")
            )
        }
    }
}

// ============================================================================
// size - 获取对象大小
// 严格翻译自: S3File.size (lines 269-304)
//   Bun: #[bun_jsc::host_fn]
//   pub fn size(global: &JSGlobalObject, callframe: &CallFrame) -> JsResult<JSValue>
// ============================================================================

/// 获取对象大小 (host_fn)
/// 对应 Bun: size
public func size(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
    let args = callframe.arguments(3)

    let pathOrBlob = PathOrBlob.fromJsNoCopy(global, args)

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Blob => {
            let blob = pathOrBlob.blob
            if (blob.store.isNone()) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to get size")
                )
            }
            let storeData = blob.store.getOrThrow().data()
            if (storeData.tag != StoreDataTagForBlob.S3) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to get size")
                )
            }
        }
        case _ => ()
    }

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Path => {
            let options = args.next()
            if (pathOrBlob.path.tag == PathOrFileDescriptorTag.Fd) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to get size")
                )
            }
            let blobResult = constructS3FileInternalStore(global, pathOrBlob.path.pathString, options)
            match (blobResult) {
                case Ok(mut blob) => {
                    return S3BlobStatTask.size(global, blob)
                }
                case Err(e) => return Result<JSValue>.Err(e)
            }
        }
        case PathOrBlobTag.Blob => {
            return Result<JSValue>.Ok(pathOrBlob.blob.getSize(global))
        }
        case _ => {
            return Result<JSValue>.Err(
                BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to get size")
            )
        }
    }
}

// ============================================================================
// exists - 检查对象是否存在
// 严格翻译自: S3File.exists (lines 306-342)
//   Bun: #[bun_jsc::host_fn]
//   pub fn exists(global: &JSGlobalObject, callframe: &CallFrame) -> JsResult<JSValue>
// ============================================================================

/// 检查对象是否存在 (host_fn)
/// 对应 Bun: exists
public func exists(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
    let args = callframe.arguments(3)

    let pathOrBlob = PathOrBlob.fromJsNoCopy(global, args)

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Blob => {
            let blob = pathOrBlob.blob
            if (blob.store.isNone()) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to check if it exists")
                )
            }
            let storeData = blob.store.getOrThrow().data()
            if (storeData.tag != StoreDataTagForBlob.S3) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to check if it exists")
                )
            }
        }
        case _ => ()
    }

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Path => {
            let options = args.next()
            if (pathOrBlob.path.tag == PathOrFileDescriptorTag.Fd) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to check if it exists")
                )
            }
            let blobResult = constructS3FileInternalStore(global, pathOrBlob.path.pathString, options)
            match (blobResult) {
                case Ok(mut blob) => {
                    return S3BlobStatTask.exists(global, blob)
                }
                case Err(e) => return Result<JSValue>.Err(e)
            }
        }
        case PathOrBlobTag.Blob => {
            return pathOrBlob.blob.getExists(global, callframe)
        }
        case _ => {
            return Result<JSValue>.Err(
                BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to check if it exists")
            )
        }
    }
}

// ============================================================================
// constructS3FileInternalStore - 从环境变量构造 S3 Blob
// 严格翻译自: S3File.construct_s3_file_internal_store (lines 344-360)
//   Bun: fn construct_s3_file_internal_store(global, path, options) -> JsResult<Blob>
// ============================================================================

/// 从环境变量构造 S3 Blob (内部存储)
/// 对应 Bun: construct_s3_file_internal_store
///
/// 步骤:
///   1. 从 Transpiler.env_mut 获取环境变量中的 S3 凭证
///   2. 调用 constructS3FileWithS3Credentials 构造 Blob
public func constructS3FileInternalStore(
    global: JSGlobalObject,
    path: String,
    options: ?JSValue
): Result<BlobRef> {
    // Get credentials from env — Transpiler::env_mut is the safe accessor
    // for the process-singleton dotenv loader (set during init).
    let existingCredentials = FetchModule.s3CredentialsFromEnv(global)
    return constructS3FileWithS3Credentials(global, path, options, existingCredentials)
}

// ============================================================================
// constructS3FileWithS3CredentialsAndOptions - 带 credentials+options 构造 S3 Blob
// 严格翻译自: S3File.construct_s3_file_with_s3_credentials_and_options (lines 363-446)
//   Bun: pub fn construct_s3_file_with_s3_credentials_and_options(
//       global, path, options, default_credentials, default_options,
//       default_acl, default_storage_class, default_request_payer
//   ) -> JsResult<Blob>
// ============================================================================

/// 带 credentials+options 构造 S3 Blob
/// 对应 Bun: construct_s3_file_with_s3_credentials_and_options
///
/// if the credentials have changed, we need to clone it, if not we can just ref/deref it
///
/// 步骤:
///   1. 从 JS 参数解析凭证和选项 (getCredentialsWithOptions)
///   2. 如果凭证改变，创建新的 Store; 否则复用现有凭证
///   3. 设置 S3 选项 (options/acl/storageClass/requestPayer)
///   4. 处理 content-type 选项
public func constructS3FileWithS3CredentialsAndOptions(
    global: JSGlobalObject,
    path: String,
    options: ?JSValue,
    defaultCredentials: S3Credentials,
    defaultOptions: MultiPartUploadOptions,
    defaultAcl: ?S3Acl,
    defaultStorageClass: ?S3StorageClass,
    defaultRequestPayer: Bool
): Result<BlobRef> {
    let awsOptions = S3CredentialsExt.getCredentialsWithOptions(
        defaultCredentials,
        defaultOptions,
        options,
        defaultAcl,
        defaultStorageClass,
        defaultRequestPayer,
        global
    )

    match (awsOptions) {
        case Err(e) => return Result<BlobRef>.Err(e)
        case Ok(awsOpts) => {
            let store: BlobStoreRef
            if (awsOpts.changedCredentials) {
                store = BlobStoreRef.initS3(path, None, awsOpts.credentials)
            } else {
                // PORT NOTE: Zig `initS3WithReferencedCredentials` bumps the
                // intrusive ref on `default_credentials`. The Rust deep-clones
                // the value instead and lets init_s3 Arc::new it.
                store = BlobStoreRef.initS3(path, None, defaultCredentials.clone())
            }

            // Set S3 options on the store
            store.data.asS3().options = awsOpts.options
            store.data.asS3().acl = awsOpts.acl
            store.data.asS3().storageClass = awsOpts.storageClass
            store.data.asS3().requestPayer = awsOpts.requestPayer

            let blob = BlobRef.initWithStore(store, global)

            // Handle content-type option
            match (options) {
                case Some(opts) => {
                    if (opts.isObject()) {
                        match (opts.getTruthy(global, "type")) {
                            case Some(fileType) => {
                                if (fileType.isString()) {
                                    let str = fileType.toSlice(global)
                                    if (Strings.isAllAscii(str)) {
                                        blob.setContentTypeWasSet(true)
                                        // Look up MIME type
                                        match (global.mimeType(str)) {
                                            case Some(entry) => {
                                                blob.setContentType(entry.value)
                                            }
                                            case None => {
                                                // Lowercase the content type
                                                let contentBuf = Strings.copyLowercase(str)
                                                blob.setContentType(contentBuf)
                                                blob.setContentTypeAllocated(true)
                                            }
                                        }
                                    }
                                }
                            }
                            case None => ()
                        }
                    }
                }
                case None => ()
            }

            return Result<BlobRef>.Ok(blob)
        }
    }
}

// ============================================================================
// constructS3FileWithS3Credentials - 带 credentials 构造 S3 Blob
// 严格翻译自: S3File.construct_s3_file_with_s3_credentials (lines 448-513)
//   Bun: pub fn construct_s3_file_with_s3_credentials(
//       global, path, options, existing_credentials
//   ) -> JsResult<Blob>
// ============================================================================

/// 带 credentials 构造 S3 Blob
/// 对应 Bun: construct_s3_file_with_s3_credentials
///
/// 步骤:
///   1. 从 JS 参数解析凭证 (使用默认 options)
///   2. 创建 S3 Store
///   3. 设置 S3 选项
///   4. 处理 content-type 选项
public func constructS3FileWithS3Credentials(
    global: JSGlobalObject,
    path: String,
    options: ?JSValue,
    existingCredentials: S3Credentials
): Result<BlobRef> {
    let awsOptions = S3CredentialsExt.getCredentialsWithOptions(
        existingCredentials,
        MultiPartUploadOptions.default(),
        options,
        None,
        None,
        false,
        global
    )

    match (awsOptions) {
        case Err(e) => return Result<BlobRef>.Err(e)
        case Ok(awsOpts) => {
            let store = BlobStoreRef.initS3(path, None, awsOpts.credentials)

            // Set S3 options on the store
            store.data.asS3().options = awsOpts.options
            store.data.asS3().acl = awsOpts.acl
            store.data.asS3().storageClass = awsOpts.storageClass
            store.data.asS3().requestPayer = awsOpts.requestPayer

            let blob = BlobRef.initWithStore(store, global)

            // Handle content-type option
            match (options) {
                case Some(opts) => {
                    if (opts.isObject()) {
                        match (opts.getTruthy(global, "type")) {
                            case Some(fileType) => {
                                if (fileType.isString()) {
                                    let str = fileType.toSlice(global)
                                    if (Strings.isAllAscii(str)) {
                                        blob.setContentTypeWasSet(true)
                                        match (global.mimeType(str)) {
                                            case Some(entry) => {
                                                blob.setContentType(entry.value)
                                            }
                                            case None => {
                                                let contentBuf = Strings.copyLowercase(str)
                                                blob.setContentType(contentBuf)
                                                blob.setContentTypeAllocated(true)
                                            }
                                        }
                                    }
                                }
                            }
                            case None => ()
                        }
                    }
                }
                case None => ()
            }

            return Result<BlobRef>.Ok(blob)
        }
    }
}

// ============================================================================
// constructS3FileInternal - 堆分配的 Blob
// 严格翻译自: S3File.construct_s3_file_internal (lines 515-523)
//   Bun: fn construct_s3_file_internal(global, path, options) -> JsResult<*mut Blob>
// ============================================================================

/// 堆分配的 Blob 构造
/// 对应 Bun: construct_s3_file_internal
///
/// Ok(Blob::new(construct_s3_file_internal_store(global, path, options)?))
public func constructS3FileInternal(
    global: JSGlobalObject,
    path: String,
    options: ?JSValue
): Result<BlobRef> {
    return constructS3FileInternalStore(global, path, options)
}

// ============================================================================
// S3BlobStatTask - 异步 stat 任务
// 严格翻译自: S3File.S3BlobStatTask (lines 525-728)
//   Bun: pub struct S3BlobStatTask {
//       promise: bun_jsc::JSPromiseStrong,
//       global: bun_ptr::BackRef<JSGlobalObject>,
//       store: StoreRef,
//   }
// ============================================================================

/// S3 Blob Stat 异步任务
/// 对应 Bun: S3BlobStatTask
///
/// Handles async S3 stat operations (exists, size, stat).
/// Each method creates a promise, sends the stat request, and resolves
/// the promise when the response arrives.
public class S3BlobStatTask {
    /// Promise (对应 Bun: JSPromiseStrong)
    public var promise: JSPromiseStrong
    /// Global object back-reference (对应 Bun: BackRef<JSGlobalObject>)
    public var global: BackRef
    /// S3 Store 引用 (对应 Bun: StoreRef)
    public var store: BlobStoreRef

    public init(promise: JSPromiseStrong, global: BackRef, store: BlobStoreRef) {
        this.promise = promise
        this.global = global
        this.store = store
    }

    /// Safe JSGlobalObject accessor
    /// 对应 Bun: pub fn global(&self) -> &JSGlobalObject { self.global.get() }
    public func global(): JSGlobalObject {
        return global.get()
    }

    // ========================================================================
    // onS3ExistsResolved - exists 回调
    // 严格翻译自: S3BlobStatTask::on_s3_exists_resolved (lines 544-576)
    //   Bun: pub fn on_s3_exists_resolved(
    //       result: s3::S3StatResult, this: *mut c_void
    //   ) -> Result<(), JsTerminated>
    // ========================================================================

    /// exists 回调 — 当 S3 stat 响应到达时
    /// 对应 Bun: on_s3_exists_resolved
    public static func onS3ExistsResolved(result: S3StatResultData, task: S3BlobStatTask): Result<Unit> {
        let global = task.global()

        match (result.tag) {
            case S3StatResultTag.NotFound => {
                task.promise.resolve(global, JSValue.FALSE)
            }
            case S3StatResultTag.Success => {
                // calling .exists() should not prevent it to download a bigger file
                task.promise.resolve(global, JSValue.TRUE)
            }
            case S3StatResultTag.Failure => {
                let value = s3ErrorToJSWithAsyncStack(
                    result.err,
                    global,
                    Some(task.store.data.asS3().path()),
                    task.promise.get()
                )
                task.promise.reject(global, value)
            }
        }
        return Result<Unit>.Ok(())
    }

    // ========================================================================
    // onS3SizeResolved - size 回调
    // 严格翻译自: S3BlobStatTask::on_s3_size_resolved (lines 578-605)
    //   Bun: pub fn on_s3_size_resolved(
    //       result: s3::S3StatResult, this: *mut c_void
    //   ) -> Result<(), JsTerminated>
    // ========================================================================

    /// size 回调 — 当 S3 stat 响应到达时
    /// 对应 Bun: on_s3_size_resolved
    public static func onS3SizeResolved(result: S3StatResultData, task: S3BlobStatTask): Result<Unit> {
        let global = task.global()

        match (result.tag) {
            case S3StatResultTag.Success => {
                task.promise.resolve(
                    global,
                    JSValue.jsNumber(Float64(result.size))
                )
            }
            case S3StatResultTag.NotFound | S3StatResultTag.Failure => {
                let value = s3ErrorToJSWithAsyncStack(
                    result.err,
                    global,
                    Some(task.store.data.asS3().path()),
                    task.promise.get()
                )
                task.promise.reject(global, value)
            }
        }
        return Result<Unit>.Ok(())
    }

    // ========================================================================
    // onS3StatResolved - stat 回调
    // 严格翻译自: S3BlobStatTask::on_s3_stat_resolved (lines 607-643)
    //   Bun: pub fn on_s3_stat_resolved(
    //       result: s3::S3StatResult, this: *mut c_void
    //   ) -> Result<(), JsTerminated>
    // ========================================================================

    /// stat 回调 — 当 S3 stat 响应到达时
    /// 对应 Bun: on_s3_stat_resolved
    public static func onS3StatResolved(result: S3StatResultData, task: S3BlobStatTask): Result<Unit> {
        let global = task.global()

        match (result.tag) {
            case S3StatResultTag.Success => {
                let s3StatResult = S3Stat.init(
                    result.size,
                    result.etag,
                    result.contentType,
                    result.lastModified,
                    global
                )
                match (s3StatResult) {
                    case Ok(stat) => {
                        task.promise.resolve(global, stat.toJs(global))
                    }
                    case Err(_) => {
                        task.promise.reject(global, JSValue.ZERO)
                    }
                }
            }
            case S3StatResultTag.NotFound | S3StatResultTag.Failure => {
                let value = s3ErrorToJSWithAsyncStack(
                    result.err,
                    global,
                    Some(task.store.data.asS3().path()),
                    task.promise.get()
                )
                task.promise.reject(global, value)
            }
        }
        return Result<Unit>.Ok(())
    }

    // ========================================================================
    // exists - 发起 exists 请求
    // 严格翻译自: S3BlobStatTask::exists (lines 645-671)
    //   Bun: pub fn exists(global: &JSGlobalObject, blob: &Blob) -> JsResult<JSValue>
    // ========================================================================

    /// 发起 exists 请求
    /// 对应 Bun: S3BlobStatTask::exists
    ///
    /// 创建 promise, 发送 HEAD 请求, resolve true/false
    public static func exists(global: JSGlobalObject, blob: BlobRef): Result<JSValue> {
        let store = blob.store.getOrThrow()
        let task = S3BlobStatTask(
            promise: JSPromiseStrong.init(global),
            global: BackRef.new(global),
            store: store
        )
        let promise = task.promise.value()
        let s3Store = store.data.asS3()
        let credentials = s3Store.getCredentials()
        let path = s3Store.path()

        S3Client.stat(
            credentials,
            path,
            S3BlobStatTask::onS3ExistsResolved,
            task,
            global.getHttpProxy(),
            s3Store.requestPayer
        )

        return Result<JSValue>.Ok(promise)
    }

    // ========================================================================
    // stat - 发起 stat 请求
    // 严格翻译自: S3BlobStatTask::stat (lines 673-698)
    //   Bun: pub fn stat(global: &JSGlobalObject, blob: &Blob) -> JsResult<JSValue>
    // ========================================================================

    /// 发起 stat 请求
    /// 对应 Bun: S3BlobStatTask::stat
    public static func stat(global: JSGlobalObject, blob: BlobRef): Result<JSValue> {
        let store = blob.store.getOrThrow()
        let task = S3BlobStatTask(
            promise: JSPromiseStrong.init(global),
            global: BackRef.new(global),
            store: store
        )
        let promise = task.promise.value()
        let s3Store = store.data.asS3()
        let credentials = s3Store.getCredentials()
        let path = s3Store.path()

        S3Client.stat(
            credentials,
            path,
            S3BlobStatTask::onS3StatResolved,
            task,
            global.getHttpProxy(),
            s3Store.requestPayer
        )

        return Result<JSValue>.Ok(promise)
    }

    // ========================================================================
    // size - 发起 size 请求
    // 严格翻译自: S3BlobStatTask::size (lines 700-725)
    //   Bun: pub fn size(global: &JSGlobalObject, blob: &mut Blob) -> JsResult<JSValue>
    // ========================================================================

    /// 发起 size 请求
    /// 对应 Bun: S3BlobStatTask::size
    public static func size(global: JSGlobalObject, blob: BlobRef): Result<JSValue> {
        let store = blob.store.getOrThrow()
        let task = S3BlobStatTask(
            promise: JSPromiseStrong.init(global),
            global: BackRef.new(global),
            store: store
        )
        let promise = task.promise.value()
        let s3Store = store.data.asS3()
        let credentials = s3Store.getCredentials()
        let path = s3Store.path()

        S3Client.stat(
            credentials,
            path,
            S3BlobStatTask::onS3SizeResolved,
            task,
            global.getHttpProxy(),
            s3Store.requestPayer
        )

        return Result<JSValue>.Ok(promise)
    }

    // deinit: store.deref() + promise.deinit() + bun.destroy(this) —
    // all handled by GC in Cangjie
}

// ============================================================================
// getPresignUrlFrom - 从 Blob 获取预签名 URL
// 严格翻译自: S3File.get_presign_url_from (lines 738-817)
//   Bun: pub fn get_presign_url_from(
//       this: &mut Blob, global: &JSGlobalObject, extra_options: Option<JSValue>
//   ) -> JsResult<JSValue>
// ============================================================================

/// 从 Blob 获取预签名 URL
/// 对应 Bun: get_presign_url_from
///
/// 步骤:
///   1. 验证是 S3 blob
///   2. 获取凭证 (支持 extra_options 覆盖)
///   3. 解析 method 和 expiresIn 选项
///   4. 调用 credentials.sign_request 生成签名 URL
///   5. 返回 URL 字符串
public func getPresignUrlFrom(
    blob: BlobRef,
    global: JSGlobalObject,
    extraOptions: ?JSValue
): Result<JSValue> {
    if (!blob.isS3()) {
        return Result<JSValue>.Err(
            BaoError(ErrorCode.InvalidThis, "presign is only possible for s3:// files")
        )
    }

    var method: HttpMethod = HttpMethod.GET
    var expires: Int64 = 86400 // 1 day default

    let s3 = blob.store.getOrThrow().data.asS3()
    // Zig: `.{ .credentials = s3.getCredentials().*, .request_payer = s3.request_payer }`.
    // acl/storage_class/content_* deliberately stay at their None defaults here —
    // they are only seeded from the store when extra_options is provided.
    var credentialsWithOptions = S3CredentialsWithOptions.withDefaults(
        credentials: s3.getCredentials().clone(),
        requestPayer: s3.requestPayer
    )

    match (extraOptions) {
        case Some(options) => {
            if (options.isObject()) {
                match (options.getTruthy(global, "method")) {
                    case Some(methodVal) => {
                        match (methodFromJs(global, methodVal)) {
                            case Ok(Some(m)) => method = m
                            case Ok(None) => {
                                return Result<JSValue>.Err(
                                    BaoError(ErrorCode.InvalidArgument, "method must be GET, PUT, DELETE or HEAD when using s3 protocol")
                                )
                            }
                            case Err(e) => return Result<JSValue>.Err(e)
                        }
                    }
                    case None => ()
                }

                match (options.getOptionalInt(global, "expiresIn")) {
                    case Ok(Some(expiresVal)) => {
                        if (expiresVal <= 0) {
                            return Result<JSValue>.Err(
                                BaoError(ErrorCode.InvalidArgument, "expiresIn must be greater than 0")
                            )
                        }
                        expires = expiresVal
                    }
                    case Ok(None) => ()
                    case Err(e) => return Result<JSValue>.Err(e)
                }
            }
            let newCreds = s3.getCredentialsWithOptions(Some(options), global)
            match (newCreds) {
                case Ok(creds) => credentialsWithOptions = creds
                case Err(e) => return Result<JSValue>.Err(e)
            }
        }
        case None => ()
    }

    let path = s3.path()

    let signResult = credentialsWithOptions.credentials.signRequest(
        SignOptions(
            path: path,
            method: method,
            acl: credentialsWithOptions.acl,
            storageClass: credentialsWithOptions.storageClass,
            requestPayer: credentialsWithOptions.requestPayer,
            contentDisposition: credentialsWithOptions.contentDisposition,
            contentType: credentialsWithOptions.contentType,
            contentHash: None,
            contentMd5: None,
            searchParams: None,
            contentEncoding: None
        ),
        Some(SignQueryOptions(expires: expires))
    )

    match (signResult) {
        case Ok(r) => {
            return Result<JSValue>.Ok(
                BunStringJsc.createUtf8ForJs(blob.globalThis(), r.url)
            )
        }
        case Err(signErr) => {
            return Result<JSValue>.Err(throwSignError(signErr, global))
        }
    }
}

// ============================================================================
// getBucketName / getBucket / getPresignUrl / getStat - Blob getter 方法
// 严格翻译自: S3File.get_bucket_name (lines 819-841) 等
// ============================================================================

/// 获取 bucket 名称
/// 对应 Bun: pub fn get_bucket_name(this: &Blob) -> Option<&[u8]>
///
/// If the store is not S3, returns None.
/// If credentials.bucket is empty, extracts the bucket from the path.
public func getBucketName(blob: BlobRef): ?String {
    let store = blob.store
    match (store) {
        case Some(s) => {
            match (s.data().tag) {
                case StoreDataTagForBlob.S3 => {
                    let credentials = s.data().asS3().getCredentials()
                    var fullPath = s.data().asS3().path()
                    if (fullFull startsWith "/") {
                        fullPath = fullPath[1..]
                    }
                    let bucket = credentials.bucket

                    if (bucket.size == 0) {
                        let slashIdx = fullPath.indexOf("/")
                        match (slashIdx) {
                            case Some(end) => {
                                let b = fullPath[0..end]
                                if (b.size > 0) {
                                    return Some(b)
                                }
                            }
                            case None => ()
                        }
                        return None
                    }
                    return Some(bucket)
                }
                case _ => return None
            }
        }
        case None => return None
    }
}

/// 获取 bucket (JS getter)
/// 对应 Bun: pub fn get_bucket(this: &Blob, global: &JSGlobalObject) -> JsResult<JSValue>
public func getBucket(blob: BlobRef, global: JSGlobalObject): Result<JSValue> {
    match (getBucketName(blob)) {
        case Some(name) => {
            return Result<JSValue>.Ok(BunStringJsc.createUtf8ForJs(global, name))
        }
        case None => return Result<JSValue>.Ok(JSValue.UNDEFINED)
    }
}

/// 获取预签名 URL (JS getter)
/// 对应 Bun: pub fn get_presign_url(this: &mut Blob, global, callframe) -> JsResult<JSValue>
public func getPresignUrl(blob: BlobRef, global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
    let args = callframe.arguments(1)
    let options = if (args.size > 0) {
        Some(args[0])
    } else {
        None
    }
    return getPresignUrlFrom(blob, global, options)
}

/// 获取 stat (JS getter)
/// 对应 Bun: pub fn get_stat(this: &Blob, global, _callframe) -> JsResult<JSValue>
public func getStat(blob: BlobRef, global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
    return S3BlobStatTask.stat(global, blob)
}

// ============================================================================
// stat - 获取对象元数据 (host_fn)
// 严格翻译自: S3File.stat (lines 876-910)
//   Bun: #[bun_jsc::host_fn]
//   pub fn stat(global: &JSGlobalObject, callframe: &CallFrame) -> JsResult<JSValue>
// ============================================================================

/// 获取对象元数据 (host_fn)
/// 对应 Bun: stat
public func stat(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
    let args = callframe.arguments(3)

    let pathOrBlob = PathOrBlob.fromJsNoCopy(global, args)

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Blob => {
            let blob = pathOrBlob.blob
            if (blob.store.isNone()) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to get size")
                )
            }
            let storeData = blob.store.getOrThrow().data()
            if (storeData.tag != StoreDataTagForBlob.S3) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to get size")
                )
            }
        }
        case _ => ()
    }

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Path => {
            let options = args.next()
            if (pathOrBlob.path.tag == PathOrFileDescriptorTag.Fd) {
                return Result<JSValue>.Err(
                    BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to get size")
                )
            }
            let blobResult = constructS3FileInternalStore(global, pathOrBlob.path.pathString, options)
            match (blobResult) {
                case Ok(mut blob) => {
                    return S3BlobStatTask.stat(global, blob)
                }
                case Err(e) => return Result<JSValue>.Err(e)
            }
        }
        case PathOrBlobTag.Blob => {
            return S3BlobStatTask.stat(global, pathOrBlob.blob)
        }
        case _ => {
            return Result<JSValue>.Err(
                BaoError(ErrorCode.InvalidArgument, "Expected a S3 or path to get size")
            )
        }
    }
}

// ============================================================================
// constructInternalJs - JS 构造 (返回 JSValue)
// 严格翻译自: S3File.construct_internal_js (lines 912-923)
//   Bun: pub fn construct_internal_js(global, path, options) -> JsResult<JSValue>
// ============================================================================

/// JS 构造 (返回 JSValue)
/// 对应 Bun: construct_internal_js
///
/// Calls construct_s3_file_internal then converts to JS value.
public func constructInternalJs(global: JSGlobalObject, path: String, options: ?JSValue): Result<JSValue> {
    let blobResult = constructS3FileInternal(global, path, options)
    match (blobResult) {
        case Ok(blob) => return Result<JSValue>.Ok(blob.toJs(global))
        case Err(e) => return Result<JSValue>.Err(e)
    }
}

// ============================================================================
// toJsUnchecked - 无检查的 JS 转换
// 严格翻译自: S3File.to_js_unchecked (lines 925-929)
//   Bun: pub fn to_js_unchecked(global, this: *mut Blob) -> JSValue
// ============================================================================

/// 无检查的 JS 转换
/// 对应 Bun: to_js_unchecked
///
/// C++ adopts `this` opaquely (stored as `void* m_ctx` in the JS wrapper);
/// ownership-transfer contract lives on callers.
public func toJsUnchecked(global: JSGlobalObject, blob: BlobRef): JSValue {
    // In Bun this calls BUN__createJSS3FileUnsafely(global, this.cast())
    return createJSS3FileUnsafely(global, blob)
}

// ============================================================================
// constructInternal - 从 callframe 构造 Blob
// 严格翻译自: S3File.construct_internal (lines 931-941)
//   Bun: pub fn construct_internal(global, callframe) -> JsResult<*mut Blob>
// ============================================================================

/// 从 callframe 构造 Blob
/// 对应 Bun: construct_internal
public func constructInternal(global: JSGlobalObject, callframe: CallFrame): Result<BlobRef> {
    let args = callframe.arguments(2)

    match (PathLike.fromJs(global, args)) {
        case Some(path) => {
            return constructS3FileInternal(global, path, args.next())
        }
        case None => {
            return Result<BlobRef>.Err(
                BaoError(ErrorCode.InvalidArgument, "Expected file path string")
            )
        }
    }
}

// ============================================================================
// construct - JS 构造函数
// 严格翻译自: S3File.construct (lines 944-954)
//   Bun: pub fn construct(global, callframe) -> *mut Blob
// ============================================================================

/// JS 构造函数
/// 对应 Bun: construct
///
/// Handles JsError outcomes:
///   - Thrown: return null
///   - OutOfMemory: throw OOM
///   - Terminated: return null
public func construct(global: JSGlobalObject, callframe: CallFrame): ?BlobRef {
    match (constructInternal(global, callframe)) {
        case Ok(blob) => return Some(blob)
        case Err(e) => {
            // In Bun: match on JsError variant
            global.throwError(e)
            return None
        }
    }
}

// ============================================================================
// hasInstance - instanceof 检查
// 严格翻译自: S3File.has_instance (lines 956-962)
//   Bun: pub fn has_instance(_: JSValue, _global, value: JSValue) -> bool
// ============================================================================

/// instanceof 检查
/// 对应 Bun: has_instance
///
/// Returns true if the value is a Blob with S3 store.
public func hasInstance(this: JSValue, global: JSGlobalObject, value: JSValue): Bool {
    let blob = value.asClassRef(BlobRef)
    match (blob) {
        case Some(b) => return b.isS3()
        case None => return false
    }
}

// ============================================================================
// createJSS3File - host_fn 包装器
// 严格翻译自: S3File.create_js_s3_file (lines 1043-1046)
//   Bun: #[bun_jsc::host_fn]
//   pub fn create_js_s3_file(global, callframe) -> JSValue
// ============================================================================

/// 创建 JS S3 File (host_fn)
/// 对应 Bun: create_js_s3_file
public func createJsS3File(global: JSGlobalObject, callframe: CallFrame): JSValue {
    return createJSS3File(global, callframe)
}

// ============================================================================
// 辅助类型和方法
// ============================================================================

/// method_from_js 的本地别名
/// 对应 Bun: #[inline] fn method_from_js(global, value) -> JsResult<Option<Method>>
private func methodFromJs(global: JSGlobalObject, value: JSValue): Result<?HttpMethod> {
    return HttpMethodJsc.fromJs(global, value)
}

// ============================================================================
// S3StatResultData - S3 stat 结果数据
// 严格翻译自: s3::S3StatResult
// ============================================================================

/// S3 stat 结果标签
public enum S3StatResultTag {
    | Success
    | NotFound
    | Failure

    public operator func ==(right: Self): Bool {
        match (this, right) {
            case (Success, Success) => true
            case (NotFound, NotFound) => true
            case (Failure, Failure) => true
            case _ => false
        }
    }
}

/// S3 stat 结果数据
/// 对应 Bun: s3::S3StatResult
public class S3StatResultData {
    public var tag: S3StatResultTag
    public var size: UInt64
    public var etag: Array<UInt8>
    public var contentType: Array<UInt8>
    public var lastModified: Array<UInt8>
    public var err: S3Error

    public init() {
        tag = S3StatResultTag.Success
        size = 0
        etag = Array<UInt8>()
        contentType = Array<UInt8>()
        lastModified = Array<UInt8>()
        err = S3Error()
    }

    public static func success(size: UInt64, etag: Array<UInt8>, contentType: Array<UInt8>, lastModified: Array<UInt8>): S3StatResultData {
        let r = S3StatResultData()
        r.tag = S3StatResultTag.Success
        r.size = size
        r.etag = etag
        r.contentType = contentType
        r.lastModified = lastModified
        return r
    }

    public static func notFound(err: S3Error): S3StatResultData {
        let r = S3StatResultData()
        r.tag = S3StatResultTag.NotFound
        r.err = err
        return r
    }

    public static func failure(err: S3Error): S3StatResultData {
        let r = S3StatResultData()
        r.tag = S3StatResultTag.Failure
        r.err = err
        return r
    }
}

/// S3 Error (对应 Bun: s3::S3Error)
public class S3Error {
    public var code: String
    public var message: String

    public init() {
        code = ""
        message = ""
    }

    public init(code: String, message: String) {
        this.code = code
        this.message = message
    }
}

// ============================================================================
// 占位类型 — 来自其他模块的引用
// ============================================================================

/// PathOrBlob (path 或 blob 参数)
/// 对应 Bun: PathOrBlob
public enum PathOrBlobTag {
    | Path
    | Blob
}

/// PathOrFileDescriptor tag
public enum PathOrFileDescriptorTag {
    | Fd
    | Path
}

/// StoreData tag for blob
public enum StoreDataTagForBlob {
    | None
    | S3
    | File
    | Bytes
}

/// PathOrBlob 容器
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
        // In Bun: parses JS args into path or blob
        return PathOrBlob()
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

/// BlobRef (对应 Bun: *mut Blob)
public class BlobRef {
    public var store: ?BlobStoreRef
    public var contentType: String
    public var contentTypeAllocated: Bool
    public var contentTypeWasSet: Bool
    public var globalThisPtr: UIntPtr

    public init() {
        store = None
        contentType = ""
        contentTypeAllocated = false
        contentTypeWasSet = false
        globalThisPtr = 0
    }

    public func isS3(): Bool {
        match (store) {
            case Some(s) => return s.data().tag == StoreDataTagForBlob.S3
            case None => return false
        }
    }

    public func toJs(global: JSGlobalObject): JSValue {
        // In Bun: creates JSS3File wrapper
        return JSValue.ZERO
    }

    public func getSize(global: JSGlobalObject): JSValue {
        return JSValue.ZERO
    }

    public func getExists(global: JSGlobalObject, callframe: CallFrame): Result<JSValue> {
        return Result<JSValue>.Ok(JSValue.TRUE)
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

/// Arguments (对应 Bun: call_frame::ArgumentsSlice)
public class Arguments {
    public var values: Array<JSValue>
    public var pos: Int64

    public init() {
        values = Array<JSValue>()
        pos = 0
    }

    public func next(): ?JSValue {
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

/// SignOptions (对应 Bun: bun_s3_signing::SignOptions)
public class SignOptions {
    public var path: String
    public var method: HttpMethod
    public var acl: ?S3Acl
    public var storageClass: ?S3StorageClass
    public var requestPayer: Bool
    public var contentDisposition: String
    public var contentType: String
    public var contentHash: ?String
    public var contentMd5: ?String
    public var searchParams: ?String
    public var contentEncoding: String

    public init() {
        path = ""
        method = HttpMethod.GET
        acl = None
        storageClass = None
        requestPayer = false
        contentDisposition = ""
        contentType = ""
        contentHash = None
        contentMd5 = None
        searchParams = None
        contentEncoding = ""
    }
}

/// SignQueryOptions (对应 Bun: bun_s3_signing::SignQueryOptions)
public class SignQueryOptions {
    public var expires: Int64

    public init() {
        expires = 86400
    }

    public init(expires: Int64) {
        this.expires = expires
    }
}

/// S3CredentialsWithOptions (对应 Bun: S3CredentialsWithOptions)
public class S3CredentialsWithOptions {
    public var credentials: S3Credentials
    public var options: MultiPartUploadOptions
    public var acl: ?S3Acl
    public var storageClass: ?S3StorageClass
    public var requestPayer: Bool
    public var contentDisposition: String
    public var contentType: String
    public var contentEncoding: String
    public var changedCredentials: Bool

    public init() {
        credentials = S3Credentials()
        options = MultiPartUploadOptions()
        acl = None
        storageClass = None
        requestPayer = false
        contentDisposition = ""
        contentType = ""
        contentEncoding = ""
        changedCredentials = false
    }

    public static func withDefaults(credentials: S3Credentials, requestPayer: Bool): S3CredentialsWithOptions {
        let o = S3CredentialsWithOptions()
        o.credentials = credentials
        o.requestPayer = requestPayer
        return o
    }
}

/// JSPromiseStrong (对应 Bun: bun_jsc::JSPromiseStrong)
public class JSPromiseStrong {
    public init() {}

    public static func init(global: JSGlobalObject): JSPromiseStrong {
        return JSPromiseStrong()
    }

    public func value(): JSValue {
        return JSValue.ZERO
    }

    public func get(): JSPromise {
        return JSPromise()
    }

    public func resolve(global: JSGlobalObject, value: JSValue): Result<Unit> {
        return Result<Unit>.Ok(())
    }

    public func reject(global: JSGlobalObject, value: JSValue): Result<Unit> {
        return Result<Unit>.Ok(())
    }
}

/// JSPromise (对应 Bun: JSValue promise)
public class JSPromise {}

/// BackRef (对应 Bun: bun_ptr::BackRef<T>)
public class BackRef {
    private var global: JSGlobalObject

    public init() {
        global = JSGlobalObject()
    }

    public static func new(global: JSGlobalObject): BackRef {
        let b = BackRef()
        b.global = global
        return b
    }

    public func get(): JSGlobalObject {
        return global
    }
}

/// WriteFileOptions (对应 Bun: blob::WriteFileOptions)
public class WriteFileOptions {
    public var mkdirpIfExists: ?Bool
    public var extraOptions: ?JSValue
    public var mode: ?Int64

    public init() {
        mkdirpIfExists = None
        extraOptions = None
        mode = None
    }

    public init(mkdirpIfExists: ?Bool, extraOptions: ?JSValue, mode: ?Int64) {
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
        data: JSValue,
        options: WriteFileOptions
    ): Result<JSValue> {
        return Result<JSValue>.Ok(JSValue.ZERO)
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

    public init() {
        options = MultiPartUploadOptions()
        acl = None
        storageClass = None
        requestPayer = false
        credentials = S3Credentials()
        pathStr = ""
    }

    public func getCredentials(): S3Credentials {
        return credentials
    }

    public func path(): String {
        return pathStr
    }

    public func getCredentialsWithOptions(options: ?JSValue, global: JSGlobalObject): Result<S3CredentialsWithOptions> {
        return Result<S3CredentialsWithOptions>.Ok(S3CredentialsWithOptions())
    }

    public func listObjects(store: BlobStoreRef, global: JSGlobalObject, objectKeys: JSValue, options: ?JSValue): Result<JSValue> {
        return Result<JSValue>.Ok(JSValue.ZERO)
    }

    public func unlink(store: BlobStoreRef, global: JSGlobalObject, options: ?JSValue): Result<JSValue> {
        return Result<JSValue>.Ok(JSValue.ZERO)
    }
}

/// S3Acl (对应 Bun: ACL)
public enum S3Acl {
    | Private
    | PublicRead
    | PublicReadWrite
    | AwsExecRead
    | AuthenticatedRead
    | BucketOwnerRead
    | BucketOwnerFullControl
    | LogDeliveryWrite
}

/// S3StorageClass (对应 Bun: StorageClass)
public enum S3StorageClass {
    | Standard
    | ReducedRedundancy
    | StandardIa
    | OnezoneIa
    | IntelligentTiering
    | Glacier
    | DeepArchive
    | Outposts
    | GlacierIr
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

/// Strings utility (对应 Bun: bun_core::strings)
public class Strings {
    public static func isAllAscii(s: String): Bool {
        return true
    }

    public static func copyLowercase(s: String): String {
        return s.toLower()
    }
}

/// HttpMethodJsc (对应 Bun: bun_http_jsc::method_jsc)
public class HttpMethodJsc {
    public static func fromJs(global: JSGlobalObject, value: JSValue): Result<?HttpMethod> {
        return Result<?HttpMethod>.Ok(None)
    }
}

/// BunStringJsc (对应 Bun: bun_jsc::bun_string_jsc)
public class BunStringJsc {
    public static func createUtf8ForJs(global: JSGlobalObject, s: String): JSValue {
        return JSValue.ZERO
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

/// FetchModule (对应 Bun: crate::webcore::fetch)
public class FetchModule {
    public static func s3CredentialsFromEnv(global: JSGlobalObject): S3Credentials {
        return S3Credentials()
    }
}

/// FFI: createJSS3File
/// 对应 Bun: BUN__createJSS3File(global, callframe) -> JSValue
public func createJSS3File(global: JSGlobalObject, callframe: CallFrame): JSValue {
    return JSValue.ZERO
}

/// FFI: createJSS3FileUnsafely
/// 对应 Bun: BUN__createJSS3FileUnsafely(global, blob) -> JSValue
public func createJSS3FileUnsafely(global: JSGlobalObject, blob: BlobRef): JSValue {
    return JSValue.ZERO
}

// ported from: src/runtime/webcore/S3File.rs
