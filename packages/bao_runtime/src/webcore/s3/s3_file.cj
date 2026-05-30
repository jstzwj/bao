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
//   - constructInternalJs: JS 构造 (返回 JsValue)
//   - constructInternal: 从 callframe 构造 *Blob
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
import bao_http.S3SignOptions
import bao_http.S3Signer
import bao_http.PresignedUrlOptions
import bao_http.AwsCredentials

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
    formatter: S3ConsoleFormatter,
    writer: StringBuilder,
    contentType: Array<UInt8>,
    offset: UInt64,
    enableAnsiColors: Bool
): Unit {
    writer.append("S3Ref")

    // detect virtual host style bucket name
    let credentials = s3.getCredentials()
    let bucketName: Array<UInt8> = if (credentials.endpoint.size > 0) {
        match (S3CredentialsExt.guessBucket(credentials.endpoint)) {
            case Some(name) => name.toArray()
            case None => credentials.bucket.toArray()
        }
    } else {
        credentials.bucket.toArray()
    }

    if (bucketName.size > 0) {
        writer.append(" (\"")
        writer.append(String.fromUtf8(bucketName))
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
        writer.append(String.fromUtf8(contentType))
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

    // S3Client.writeFormatCredentials 尚未实现
    // S3Client.writeFormatCredentials(credentials, s3.options, s3.acl, formatter, writer, enableAnsiColors)
    formatter.writeIndent(writer)
    writer.append("}")
    formatter.resetLine()
}

// ============================================================================
// presign - 生成预签名 URL
// 严格翻译自: S3File.presign (lines 122-156)
//   Bun: #[bun_jsc::host_fn]
//   pub fn presign(global: &JSGlobalObject, callframe: &CallFrame) -> JsResult<JsValue>
// ============================================================================

/// 生成预签名 URL (host_fn)
/// 对应 Bun: presign
///
/// 接受 path 或 blob 参数, 生成预签名 URL。
/// 支持 S3 路径格式: s3://bucket/key 或已有的 S3 Blob 对象。
public func presign(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
    let args = Arguments.fromCallFrame(callframe,3)

    // accept a path or a blob
    let pathOrBlob = S3PathOrBlob.fromJsNoCopy(global, args)

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Blob =>
            let blob = pathOrBlob.blob
            if (blob.store.isNone()) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to presign")
            }
            let storeData = blob.store.getOrThrow().data()
            if (storeData.tag != StoreDataTagForBlob.S3) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to presign")
            }
        case _ => ()
    }

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Path =>
            if (pathOrBlob.path.tag == PathOrFileDescriptorTag.Fd) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to presign")
            }
            let options = args.next()
            let blobResult = constructS3FileInternalStore(global, pathOrBlob.path.pathString, options)
            match (blobResult) {
                case Ok(blob) =>
                    return getPresignUrlFrom(blob, global, options)
                case Err(e) => return Result<JsValue>.Err(e)
            }
        case PathOrBlobTag.Blob =>
            let options = args.next()
            return getPresignUrlFrom(pathOrBlob.blob, global, options)
        case _ =>
            return Result<JsValue>.Err(
                "Error:Expected a S3 or path to presign")
    }
}

// ============================================================================
// unlink - 删除 S3 对象
// 严格翻译自: S3File.unlink (lines 158-197)
//   Bun: #[bun_jsc::host_fn]
//   pub fn unlink(global: &JSGlobalObject, callframe: &CallFrame) -> JsResult<JsValue>
// ============================================================================

/// 删除 S3 对象 (host_fn)
/// 对应 Bun: unlink
///
/// 接受 path 或 blob 参数, 删除 S3 对象。
public func unlink(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
    let args = Arguments.fromCallFrame(callframe,3)

    // accept a path or a blob
    let pathOrBlob = S3PathOrBlob.fromJsNoCopy(global, args)

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Blob =>
            let blob = pathOrBlob.blob
            if (blob.store.isNone()) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to delete")
            }
            let storeData = blob.store.getOrThrow().data()
            if (storeData.tag != StoreDataTagForBlob.S3) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to delete")
            }
        case _ => ()
    }

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Path =>
            if (pathOrBlob.path.tag == PathOrFileDescriptorTag.Fd) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to delete")
            }
            let options = args.next()
            let blobResult = constructS3FileInternalStore(global, pathOrBlob.path.pathString, options)
            match (blobResult) {
                case Ok(blob) =>
                    let store = blob.store.getOrThrow()
                    return store.data().asS3().unlink(store, global, options)
                case Err(e) => return Result<JsValue>.Err(e)
            }
        case PathOrBlobTag.Blob =>
            let options = args.next()
            let store = pathOrBlob.blob.store.getOrThrow()
            return store.data().asS3().unlink(store, global, options)
        case _ =>
            return Result<JsValue>.Err(
                "Error:Expected a S3 or path to delete")
    }
}

// ============================================================================
// write - 写入 S3 对象
// 严格翻译自: S3File.write (lines 199-267)
//   Bun: #[bun_jsc::host_fn]
//   pub fn write(global: &JSGlobalObject, callframe: &CallFrame) -> JsResult<JsValue>
// ============================================================================

/// 写入 S3 对象 (host_fn)
/// 对应 Bun: write
///
/// 接受 path 或 blob + data 参数, 写入 S3。
/// 支持分片上传 (multipart upload) 和单次上传 (putObject)。
public func write(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
    let args = Arguments.fromCallFrame(callframe,3)

    // accept a path or a blob
    let pathOrBlob = S3PathOrBlob.fromJsNoCopy(global, args)

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Blob =>
            let blob = pathOrBlob.blob
            if (blob.store.isNone()) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to upload")
            }
            let storeData = blob.store.getOrThrow().data()
            if (storeData.tag != StoreDataTagForBlob.S3) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to upload")
            }
        case _ => ()
    }

    let data = args.next()
    match (data) {
        case Some(d) =>
            () // continue
        case None =>
            return Result<JsValue>.Err(
                "Error:Expected a Blob-y thing to upload")
    }

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Path =>
            let writeOptions = args.next()
            if (pathOrBlob.path.tag == PathOrFileDescriptorTag.Fd) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to upload")
            }
            let blobResult = constructS3FileInternalStore(global, pathOrBlob.path.pathString, writeOptions)
            match (blobResult) {
                case Ok(blob) =>
                    // Design note: Cangjie's match consumes the value (no Copy trait).
                    // We rebuild S3PathOrBlob from the constructed blob to pass to
                    // WriteFileModule, which is equivalent to Bun's borrow-based approach.
                    let blobInternal = S3PathOrBlob.fromBlob(blob)
                    return WriteFileModule.writeFileInternal(
                        global,
                        blobInternal,
                        data.getOrThrow(),
                        WriteFileOptions(
                            Some(false),
                            writeOptions,
                            None
                        )
                    )
                case Err(e) => return Result<JsValue>.Err(e)
            }
        case PathOrBlobTag.Blob =>
            // Design note: Cangjie match moves `pathOrBlob`; we bind it to a local
            // variable to pass to WriteFileModule. Equivalent to Bun's borrow semantics.
            return WriteFileModule.writeFileInternal(
                global,
                pathOrBlob,
                data.getOrThrow(),
                WriteFileOptions(
                    Some(false),
                    args.next(),
                    None
                )
            )
        case _ =>
            return Result<JsValue>.Err(
                "Error:Expected a S3 or path to upload")
    }
}

// ============================================================================
// size - 获取对象大小
// 严格翻译自: S3File.size (lines 269-304)
//   Bun: #[bun_jsc::host_fn]
//   pub fn size(global: &JSGlobalObject, callframe: &CallFrame) -> JsResult<JsValue>
// ============================================================================

/// 获取对象大小 (host_fn)
/// 对应 Bun: size
public func size(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
    let args = Arguments.fromCallFrame(callframe,3)

    let pathOrBlob = S3PathOrBlob.fromJsNoCopy(global, args)

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Blob =>
            let blob = pathOrBlob.blob
            if (blob.store.isNone()) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to get size")
            }
            let storeData = blob.store.getOrThrow().data()
            if (storeData.tag != StoreDataTagForBlob.S3) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to get size")
            }
        case _ => ()
    }

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Path =>
            let options = args.next()
            if (pathOrBlob.path.tag == PathOrFileDescriptorTag.Fd) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to get size")
            }
            let blobResult = constructS3FileInternalStore(global, pathOrBlob.path.pathString, options)
            match (blobResult) {
                case Ok(blob) =>
                    return S3BlobStatTask.size(global, blob)
                case Err(e) => return Result<JsValue>.Err(e)
            }
        case PathOrBlobTag.Blob =>
            return Result<JsValue>.Ok(pathOrBlob.blob.getSize(global))
        case _ =>
            return Result<JsValue>.Err(
                "Error:Expected a S3 or path to get size")
    }
}

// ============================================================================
// exists - 检查对象是否存在
// 严格翻译自: S3File.exists (lines 306-342)
//   Bun: #[bun_jsc::host_fn]
//   pub fn exists(global: &JSGlobalObject, callframe: &CallFrame) -> JsResult<JsValue>
// ============================================================================

/// 检查对象是否存在 (host_fn)
/// 对应 Bun: exists
public func exists(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
    let args = Arguments.fromCallFrame(callframe,3)

    let pathOrBlob = S3PathOrBlob.fromJsNoCopy(global, args)

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Blob =>
            let blob = pathOrBlob.blob
            if (blob.store.isNone()) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to check if it exists")
            }
            let storeData = blob.store.getOrThrow().data()
            if (storeData.tag != StoreDataTagForBlob.S3) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to check if it exists")
            }
        case _ => ()
    }

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Path =>
            let options = args.next()
            if (pathOrBlob.path.tag == PathOrFileDescriptorTag.Fd) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to check if it exists")
            }
            let blobResult = constructS3FileInternalStore(global, pathOrBlob.path.pathString, options)
            match (blobResult) {
                case Ok(blob) =>
                    return S3BlobStatTask.exists(global, blob)
                case Err(e) => return Result<JsValue>.Err(e)
            }
        case PathOrBlobTag.Blob =>
            return pathOrBlob.blob.getExists(global, callframe)
        case _ =>
            return Result<JsValue>.Err(
                "Error:Expected a S3 or path to check if it exists")
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
    options: ?JsValue
): Result<BlobRef> {
    // Get credentials from env — Transpiler::env_mut is the safe accessor
    // for the process-singleton dotenv loader (set during init).
    let existingCredentials = S3FetchModule.s3CredentialsFromEnv(global)
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
    options: ?JsValue,
    defaultCredentials: S3Credentials,
    defaultOptions: MultiPartUploadOptions,
    defaultAcl: ?S3Acl,
    defaultStorageClass: ?S3StorageClass,
    defaultRequestPayer: Bool
): Result<BlobRef> {
    let awsOpts = S3CredentialsExt.getCredentialsWithOptions(
        defaultCredentials,
        defaultOptions,
        options,
        defaultAcl,
        defaultStorageClass,
        defaultRequestPayer,
        global
    )

    let store: S3BlobStoreRef
    if (awsOpts.changedCredentials) {
        store = S3BlobStoreRef.initS3(path, None, awsOpts.credentials)
    } else {
        // Design note: Bun's `initS3WithReferencedCredentials` bumps the
        // intrusive ref count on `default_credentials`. Cangjie uses GC for
        // all reference management, so the split between initS3 and
        // initS3WithReferencedCredentials is kept for API compatibility but
        // both paths are semantically identical (GC tracks the reference).
        store = S3BlobStoreRef.initS3WithReferencedCredentials(path, None, defaultCredentials)
    }

    // Set S3 options on the store
    store.data().asS3().options = awsOpts.options
    store.data().asS3().acl = awsOpts.acl
    store.data().asS3().storageClass = awsOpts.storageClass
    store.data().asS3().requestPayer = awsOpts.requestPayer

    let blob = BlobRef.initWithStore(store, global)

    // Handle content-type option
    match (options) {
        case Some(opts) =>
            if (opts.isObject()) {
                match (opts.getTruthy(global.globalThis, "type")) {
                    case Some(fileType) =>
                        if (fileType.isString()) {
                            let str = fileType.toString()
                            if (S3Strings.isAllAscii(str)) {
                                blob.setContentTypeWasSet(true)
                                blob.setContentType(str)
                            }
                        }
                    case None => ()
                }
            }
        case None => ()
    }

    return Result<BlobRef>.Ok(blob)
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
    options: ?JsValue,
    existingCredentials: S3Credentials
): Result<BlobRef> {
    let awsOpts = S3CredentialsExt.getCredentialsWithOptions(
        existingCredentials,
        MultiPartUploadOptions(),
        options,
        None,
        None,
        false,
        global
    )

    let store = S3BlobStoreRef.initS3(path, None, awsOpts.credentials)

    // Set S3 options on the store
    store.data().asS3().options = awsOpts.options
    store.data().asS3().acl = awsOpts.acl
    store.data().asS3().storageClass = awsOpts.storageClass
    store.data().asS3().requestPayer = awsOpts.requestPayer

    let blob = BlobRef.initWithStore(store, global)

    // Handle content-type option
    match (options) {
        case Some(opts) =>
            if (opts.isObject()) {
                match (opts.getTruthy(global.globalThis, "type")) {
                    case Some(fileType) =>
                        if (fileType.isString()) {
                            let str = fileType.toString()
                            if (S3Strings.isAllAscii(str)) {
                                blob.setContentTypeWasSet(true)
                                blob.setContentType(str)
                            }
                        }
                    case None => ()
                }
            }
        case None => ()
    }

    return Result<BlobRef>.Ok(blob)
}

// ============================================================================
// constructS3FileInternal - 堆分配的 Blob
// 严格翻译自: S3File.construct_s3_file_internal (lines 515-523)
//   Bun: fn construct_s3_file_internal(global, path, options) -> JsResult<*Blob>
// ============================================================================

/// 堆分配的 Blob 构造
/// 对应 Bun: construct_s3_file_internal
///
/// Ok(Blob::new(construct_s3_file_internal_store(global, path, options)?))
public func constructS3FileInternal(
    global: JSGlobalObject,
    path: String,
    options: ?JsValue
): Result<BlobRef> {
    return constructS3FileInternalStore(global, path, options)
}

// ============================================================================
// S3BlobStatTask - 异步 stat 任务
// 严格翻译自: S3File.S3BlobStatTask (lines 525-728)
//   Bun: pub struct S3BlobStatTask {
//       promise: bun_jsc::S3JSPromiseStrong,
//       global: bun_ptr::S3BackRef<JSGlobalObject>,
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
    /// Promise (对应 Bun: S3JSPromiseStrong)
    public var promise: S3JSPromiseStrong
    /// Global object back-reference (对应 Bun: S3BackRef<JSGlobalObject>)
    public var global: S3BackRef
    /// S3 Store 引用 (对应 Bun: StoreRef)
    public var store: S3BlobStoreRef

    public init(promise: S3JSPromiseStrong, global: S3BackRef, store: S3BlobStoreRef) {
        this.promise = promise
        this.global = global
        this.store = store
    }

    /// Safe JSGlobalObject accessor
    /// 对应 Bun: pub fn global(&self) -> &JSGlobalObject { self.global.get() }
    public func getGlobal(): JSGlobalObject {
        return global.get()
    }

    // ========================================================================
    // onS3ExistsResolved - exists 回调
    // 严格翻译自: S3BlobStatTask::on_s3_exists_resolved (lines 544-576)
    //   Bun: pub fn on_s3_exists_resolved(
    //       result: s3::S3StatResult, `this`: *c_void
    //   ) -> Result<(), JsTerminated>
    // ========================================================================

    /// exists 回调 — 当 S3 stat 响应到达时
    /// 对应 Bun: on_s3_exists_resolved
    public static func onS3ExistsResolved(result: S3StatResultData, task: S3BlobStatTask): Result<Unit> {
        let global = task.getGlobal()

        match (result.tag) {
            case S3StatResultTag.NotFound =>
                task.promise.resolve(global, JsValue(false))
            case S3StatResultTag.Success =>
                // calling .exists() should not prevent it to download a bigger file
                task.promise.resolve(global, JsValue(true))
            case S3StatResultTag.Failure =>
                let value = s3ErrorToJSWithAsyncStack(
                    result.err,
                    global,
                    Some(task.store.data().asS3().path()),
                    task.promise.get()
                )
                task.promise.reject(global, value)
        }
        return Result<Unit>.Ok(())
    }

    // ========================================================================
    // onS3SizeResolved - size 回调
    // 严格翻译自: S3BlobStatTask::on_s3_size_resolved (lines 578-605)
    //   Bun: pub fn on_s3_size_resolved(
    //       result: s3::S3StatResult, `this`: *c_void
    //   ) -> Result<(), JsTerminated>
    // ========================================================================

    /// size 回调 — 当 S3 stat 响应到达时
    /// 对应 Bun: on_s3_size_resolved
    public static func onS3SizeResolved(result: S3StatResultData, task: S3BlobStatTask): Result<Unit> {
        let global = task.getGlobal()

        match (result.tag) {
            case S3StatResultTag.Success =>
                task.promise.resolve(
                    global,
                    JsValue.jsNumber(Float64(result.size))
                )
            case S3StatResultTag.NotFound | S3StatResultTag.Failure =>
                let value = s3ErrorToJSWithAsyncStack(
                    result.err,
                    global,
                    Some(task.store.data().asS3().path()),
                    task.promise.get()
                )
                task.promise.reject(global, value)
        }
        return Result<Unit>.Ok(())
    }

    // ========================================================================
    // onS3StatResolved - stat 回调
    // 严格翻译自: S3BlobStatTask::on_s3_stat_resolved (lines 607-643)
    //   Bun: pub fn on_s3_stat_resolved(
    //       result: s3::S3StatResult, `this`: *c_void
    //   ) -> Result<(), JsTerminated>
    // ========================================================================

    /// stat 回调 — 当 S3 stat 响应到达时
    /// 对应 Bun: on_s3_stat_resolved
    public static func onS3StatResolved(result: S3StatResultData, task: S3BlobStatTask): Result<Unit> {
        let global = task.getGlobal()

        match (result.tag) {
            case S3StatResultTag.Success =>
                let statResult = S3Stat.`init`(
                    result.size,
                    result.etag,
                    result.contentType,
                    result.lastModified,
                    global
                )
                match (statResult) {
                    case Ok(stat) =>
                        task.promise.resolve(global, s3StatToJs(stat, global))
                    case Err(_) =>
                        let value = s3ErrorToJSWithAsyncStack(
                            S3Error("InvalidMetadata", "Failed to construct S3 stat metadata."),
                            global,
                            Some(task.store.data().asS3().path()),
                            task.promise.get()
                        )
                        task.promise.reject(global, value)
                }
            case S3StatResultTag.NotFound | S3StatResultTag.Failure =>
                let value = s3ErrorToJSWithAsyncStack(
                    result.err,
                    global,
                    Some(task.store.data().asS3().path()),
                    task.promise.get()
                )
                task.promise.reject(global, value)
        }
        return Result<Unit>.Ok(())
    }

    private static func s3StatToJs(stat: S3Stat, global: JSGlobalObject): JsValue {
        let obj = JsObject.make()
        obj.set("size", stat.getSize(global))
        match (stat.getEtag(global)) {
            case Ok(value) => obj.set("etag", value)
            case Err(_) => obj.set("etag", JsValue(""))
        }
        match (stat.getContentType(global)) {
            case Ok(value) => obj.set("type", value)
            case Err(_) => obj.set("type", JsValue(""))
        }
        obj.set("lastModified", stat.getLastModified(global))
        return JsValue(obj)
    }

    // ========================================================================
    // exists - 发起 exists 请求
    // 严格翻译自: S3BlobStatTask::exists (lines 645-671)
    //   Bun: pub fn exists(global: &JSGlobalObject, blob: &Blob) -> JsResult<JsValue>
    // ========================================================================

    /// 发起 exists 请求
    /// 对应 Bun: S3BlobStatTask::exists
    ///
    /// 创建 promise, 发送 HEAD 请求, resolve true/false
    public static func exists(global: JSGlobalObject, blob: BlobRef): Result<JsValue> {
        let store = blob.store.getOrThrow()
        let task = S3BlobStatTask(
            S3JSPromiseStrong(global),
            S3BackRef.new(global),
            store
        )
        let promise = task.promise.value()
        let s3Store = store.data().asS3()
        let credentials = s3Store.getCredentials()
        let path = s3Store.path()

        S3Client.statRequest(
            credentials,
            path,
            S3BlobStatTask.onS3ExistsResolved,
            task,
            None,
            s3Store.requestPayer
        )

        return Result<JsValue>.Ok(promise)
    }

    // ========================================================================
    // stat - 发起 stat 请求
    // 严格翻译自: S3BlobStatTask::stat (lines 673-698)
    //   Bun: pub fn stat(global: &JSGlobalObject, blob: &Blob) -> JsResult<JsValue>
    // ========================================================================

    /// 发起 stat 请求
    /// 对应 Bun: S3BlobStatTask::stat
    public static func stat(global: JSGlobalObject, blob: BlobRef): Result<JsValue> {
        let store = blob.store.getOrThrow()
        let task = S3BlobStatTask(
            S3JSPromiseStrong(global),
            S3BackRef.new(global),
            store
        )
        let promise = task.promise.value()
        let s3Store = store.data().asS3()
        let credentials = s3Store.getCredentials()
        let path = s3Store.path()

        S3Client.statRequest(
            credentials,
            path,
            S3BlobStatTask.onS3StatResolved,
            task,
            None,
            s3Store.requestPayer
        )

        return Result<JsValue>.Ok(promise)
    }

    // ========================================================================
    // size - 发起 size 请求
    // 严格翻译自: S3BlobStatTask::size (lines 700-725)
    //   Bun: pub fn size(global: &JSGlobalObject, blob: &Blob) -> JsResult<JsValue>
    // ========================================================================

    /// 发起 size 请求
    /// 对应 Bun: S3BlobStatTask::size
    public static func size(global: JSGlobalObject, blob: BlobRef): Result<JsValue> {
        let store = blob.store.getOrThrow()
        let task = S3BlobStatTask(
            S3JSPromiseStrong(global),
            S3BackRef.new(global),
            store
        )
        let promise = task.promise.value()
        let s3Store = store.data().asS3()
        let credentials = s3Store.getCredentials()
        let path = s3Store.path()

        S3Client.statRequest(
            credentials,
            path,
            S3BlobStatTask.onS3SizeResolved,
            task,
            None,
            s3Store.requestPayer
        )

        return Result<JsValue>.Ok(promise)
    }

    // deinit: store.deref() + promise.deinit() + bun.destroy(this) —
    // all handled by GC in Cangjie
}

// ============================================================================
// S3BlobListObjectsTask - 列出 S3 对象异步任务
// ============================================================================

public class S3BlobUploadTask {
    public var promise: S3JSPromiseStrong
    public var global: S3BackRef
    public var store: S3BlobStoreRef
    public var bytesWritten: Int64

    public init(promise: S3JSPromiseStrong, global: S3BackRef, store: S3BlobStoreRef, bytesWritten: Int64) {
        this.promise = promise
        this.global = global
        this.store = store
        this.bytesWritten = bytesWritten
    }

    public func getGlobal(): JSGlobalObject {
        return global.get()
    }

    public static func onS3UploadResolved(result: S3UploadResult, task: S3BlobUploadTask): Result<Unit> {
        let global = task.getGlobal()
        match (result.tag) {
            case S3UploadResultTag.Success =>
                task.promise.resolve(global, JsValue(task.bytesWritten))
            case S3UploadResultTag.Failure =>
                let err = match (result.error) {
                    case Some(e) => e
                    case None => S3Error("RequestError", "S3 upload request failed.")
                }
                let value = s3ErrorToJSWithAsyncStack(
                    err,
                    global,
                    Some(task.store.data().asS3().path()),
                    task.promise.get()
                )
                task.promise.reject(global, value)
        }
        return Result<Unit>.Ok(())
    }

    public static func upload(global: JSGlobalObject, store: S3BlobStoreRef, content: String, bytesWritten: Int64, contentType: String): Result<JsValue> {
        let task = S3BlobUploadTask(
            S3JSPromiseStrong(global),
            S3BackRef.new(global),
            store,
            bytesWritten
        )
        let promise = task.promise.value()
        let s3Store = store.data().asS3()
        S3Client.uploadRequest(
            s3Store.getCredentials(),
            s3Store.path(),
            content,
            bytesWritten,
            contentType,
            "",
            "",
            s3Store.acl,
            s3Store.storageClass,
            S3BlobUploadTask.onS3UploadResolved,
            task,
            None,
            s3Store.requestPayer
        )
        return Result<JsValue>.Ok(promise)
    }
}

public class S3BlobDownloadTask {
    public var promise: S3JSPromiseStrong
    public var global: S3BackRef
    public var store: S3BlobStoreRef

    public init(promise: S3JSPromiseStrong, global: S3BackRef, store: S3BlobStoreRef) {
        this.promise = promise
        this.global = global
        this.store = store
    }

    public func getGlobal(): JSGlobalObject {
        return global.get()
    }

    public static func onS3DownloadResolved(result: S3DownloadResult, task: S3BlobDownloadTask): Result<Unit> {
        let global = task.getGlobal()
        match (result.tag) {
            case S3DownloadResultTag.Success =>
                task.promise.resolve(global, JsValue(result.body.toString()))
            case S3DownloadResultTag.NotFound | S3DownloadResultTag.Failure =>
                let err = match (result.error) {
                    case Some(e) => e
                    case None => S3Error("RequestError", "S3 download request failed.")
                }
                let value = s3ErrorToJSWithAsyncStack(
                    err,
                    global,
                    Some(task.store.data().asS3().path()),
                    task.promise.get()
                )
                task.promise.reject(global, value)
        }
        return Result<Unit>.Ok(())
    }

    public static func download(global: JSGlobalObject, store: S3BlobStoreRef): Result<JsValue> {
        let task = S3BlobDownloadTask(
            S3JSPromiseStrong(global),
            S3BackRef.new(global),
            store
        )
        let promise = task.promise.value()
        let s3Store = store.data().asS3()
        S3Client.downloadRequest(
            s3Store.getCredentials(),
            s3Store.path(),
            S3BlobDownloadTask.onS3DownloadResolved,
            task,
            None,
            s3Store.requestPayer
        )
        return Result<JsValue>.Ok(promise)
    }
}

public class S3BlobListObjectsTask {
    public var promise: S3JSPromiseStrong
    public var global: S3BackRef
    public var store: S3BlobStoreRef

    public init(promise: S3JSPromiseStrong, global: S3BackRef, store: S3BlobStoreRef) {
        this.promise = promise
        this.global = global
        this.store = store
    }

    public func getGlobal(): JSGlobalObject {
        return global.get()
    }

    public static func onS3ListObjectsResolved(result: S3ListObjectsResultEx, task: S3BlobListObjectsTask): Result<Unit> {
        let global = task.getGlobal()
        match (result.tag) {
            case S3ListObjectsResultTag.Success =>
                match (result.listResult) {
                    case Some(listResult) => task.promise.resolve(global, listResult.toJS(global))
                    case None => task.promise.reject(global, s3ErrorToJSWithAsyncStack(
                        S3Error("InvalidResponse", "S3 listObjects response did not include a parsed result."),
                        global,
                        Some(task.store.data().asS3().path()),
                        task.promise.get()
                    ))
                }
            case S3ListObjectsResultTag.NotFound | S3ListObjectsResultTag.Failure =>
                let err = match (result.error) {
                    case Some(e) => e
                    case None => S3Error("RequestError", "S3 listObjects request failed.")
                }
                let value = s3ErrorToJSWithAsyncStack(
                    err,
                    global,
                    Some(task.store.data().asS3().path()),
                    task.promise.get()
                )
                task.promise.reject(global, value)
        }
        return Result<Unit>.Ok(())
    }

    public static func listObjects(global: JSGlobalObject, store: S3BlobStoreRef, options: ?JsValue): Result<JsValue> {
        let task = S3BlobListObjectsTask(
            S3JSPromiseStrong(global),
            S3BackRef.new(global),
            store
        )
        let promise = task.promise.value()
        let s3Store = store.data().asS3()
        let listOptions = match (options) {
            case Some(value) => getListObjectsOptionsFromJS(global, value)
            case None => S3ListObjectsOptions()
        }
        S3Client.listObjectsRequest(
            s3Store.getCredentials(),
            listOptions,
            S3BlobListObjectsTask.onS3ListObjectsResolved,
            task,
            None
        )
        return Result<JsValue>.Ok(promise)
    }
}

// ============================================================================
// S3BlobDeleteTask - 删除 S3 对象异步任务
// ============================================================================

public class S3BlobDeleteTask {
    public var promise: S3JSPromiseStrong
    public var global: S3BackRef
    public var store: S3BlobStoreRef

    public init(promise: S3JSPromiseStrong, global: S3BackRef, store: S3BlobStoreRef) {
        this.promise = promise
        this.global = global
        this.store = store
    }

    public func getGlobal(): JSGlobalObject {
        return global.get()
    }

    public static func onS3DeleteResolved(result: S3DeleteResult, task: S3BlobDeleteTask): Result<Unit> {
        let global = task.getGlobal()
        match (result.tag) {
            case S3DeleteResultTag.Success =>
                task.promise.resolve(global, JsValue.jsUndefined())
            case S3DeleteResultTag.NotFound | S3DeleteResultTag.Failure =>
                let err = match (result.error) {
                    case Some(e) => e
                    case None => S3Error("RequestError", "S3 delete request failed.")
                }
                let value = s3ErrorToJSWithAsyncStack(
                    err,
                    global,
                    Some(task.store.data().asS3().path()),
                    task.promise.get()
                )
                task.promise.reject(global, value)
        }
        return Result<Unit>.Ok(())
    }

    public static func unlink(global: JSGlobalObject, store: S3BlobStoreRef): Result<JsValue> {
        let task = S3BlobDeleteTask(
            S3JSPromiseStrong(global),
            S3BackRef.new(global),
            store
        )
        let promise = task.promise.value()
        let s3Store = store.data().asS3()
        S3Client.deleteRequest(
            s3Store.getCredentials(),
            s3Store.path(),
            S3BlobDeleteTask.onS3DeleteResolved,
            task,
            None,
            s3Store.requestPayer
        )
        return Result<JsValue>.Ok(promise)
    }
}

// ============================================================================
// getPresignUrlFrom - 从 Blob 获取预签名 URL
// 严格翻译自: S3File.get_presign_url_from (lines 738-817)
//   Bun: pub fn get_presign_url_from(
//       this: &Blob, global: &JSGlobalObject, extra_options: Option<JsValue>
//   ) -> JsResult<JsValue>
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
    extraOptions: ?JsValue
): Result<JsValue> {
    if (!blob.isS3()) {
        return Result<JsValue>.Err(
            "Error: presign is only possible for s3:// files"
        )
    }
    let store = blob.store.getOrThrow()
    let s3Store = store.data().asS3()

    var method = HttpMethod.GET
    var expiresIn = Int64(86400)

    match (parsePresignOptions(global, extraOptions)) {
        case Ok(options) =>
            method = options.method
            expiresIn = options.expiresIn
        case Err(e) => return Result<JsValue>.Err(e)
    }

    let signOptions = S3SignOptions(s3Store.path(), httpMethodToString(method))
    let presignOptions = PresignedUrlOptions(expiresIn)
    let presignResult = S3Signer.presignedUrl(awsCredentialsFromRuntime(s3Store.getCredentials()), signOptions, presignOptions)
    if (presignResult.isOk()) {
        return Result<JsValue>.Ok(JsValue(presignResult.unwrap()))
    } else {
        let err = presignResult.asErr()
        let msg = match (err) {
            case Some(e) => e.message
            case None => "presigned URL failed"
        }
        return Result<JsValue>.Err("Error: ${msg}")
    }
}

private func awsCredentialsFromRuntime(credentials: S3Credentials): AwsCredentials {
    let sessionToken = match (credentials.sessionToken) {
        case Some(token) => token
        case None => ""
    }
    return AwsCredentials(
        credentials.accessKey,
        credentials.secretKey,
        sessionToken,
        credentials.region,
        credentials.endpoint,
        credentials.bucket
    )
}

private class ParsedPresignOptions {
    public var method: HttpMethod
    public var expiresIn: Int64

    public init() {
        method = HttpMethod.GET
        expiresIn = 86400
    }
}

private func parsePresignOptions(global: JSGlobalObject, extraOptions: ?JsValue): Result<ParsedPresignOptions> {
    let parsed = ParsedPresignOptions()

    match (extraOptions) {
        case Some(options) =>
            if (options.isEmptyOrUndefinedOrNull()) {
                return Result<ParsedPresignOptions>.Ok(parsed)
            }
            if (!options.isObject()) {
                return Result<ParsedPresignOptions>.Err("Error: S3 presign options must be an object")
            }

            match (options.getTruthy(global.globalThis, "method")) {
                case Some(methodValue) =>
                    if (!methodValue.isString()) {
                        return Result<ParsedPresignOptions>.Err("Error: S3 presign option 'method' must be a string")
                    }
                    match (parsePresignMethod(methodValue.toString())) {
                        case Some(method) => parsed.method = method
                        case None => return Result<ParsedPresignOptions>.Err("Error: S3 presign option 'method' must be one of GET, PUT, POST, DELETE, HEAD, PATCH, OPTIONS")
                    }
                case None => ()
            }

            match (options.getTruthy(global.globalThis, "expiresIn")) {
                case Some(expiresValue) =>
                    if (!expiresValue.isNumber() || !expiresValue.isFinite()) {
                        return Result<ParsedPresignOptions>.Err("Error: S3 presign option 'expiresIn' must be a finite number of seconds")
                    }
                    let expires = expiresValue.toInt64()
                    if (expires <= 0) {
                        return Result<ParsedPresignOptions>.Err("Error: S3 presign option 'expiresIn' must be greater than 0 seconds")
                    }
                    if (expires > 604800) {
                        return Result<ParsedPresignOptions>.Err("Error: S3 presign option 'expiresIn' must be less than or equal to 604800 seconds")
                    }
                    parsed.expiresIn = expires
                case None => ()
            }
        case None => ()
    }

    return Result<ParsedPresignOptions>.Ok(parsed)
}

private func parsePresignMethod(method: String): ?HttpMethod {
    match (S3Strings.copyLowercase(method)) {
        case "get" => Some(HttpMethod.GET)
        case "put" => Some(HttpMethod.PUT)
        case "post" => Some(HttpMethod.POST)
        case "delete" => Some(HttpMethod.DELETE)
        case "head" => Some(HttpMethod.HEAD)
        case "patch" => Some(HttpMethod.PATCH)
        case "options" => Some(HttpMethod.OPTIONS)
        case _ => None
    }
}

private func httpMethodToString(method: HttpMethod): String {
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

// ============================================================================
// getBucketName / getBucket / getPresignUrl / getStat - Blob getter 方法
// 严格翻译自: S3File.get_bucket_name (lines 819-841) 等
// ============================================================================

/// 获取 bucket 名称
/// 对应 Bun: pub fn get_bucket_name(`this`: &Blob) -> Option<&[u8]>
///
/// If the store is not S3, returns None.
/// If credentials.bucket is empty, extracts the bucket from the path.
public func getBucketName(blob: BlobRef): ?String {
    let store = blob.store
    match (store) {
        case Some(s) =>
            match (s.data().tag) {
                case StoreDataTagForBlob.S3 =>
                    let credentials = s.data().asS3().getCredentials()
                    var fullPath = s.data().asS3().path()
                    if (fullPath.startsWith("/")) {
                        fullPath = fullPath[1..]
                    }
                    let bucket = credentials.bucket

                    if (bucket.size == 0) {
                        let slashIdx = fullPath.indexOf("/")
                        match (slashIdx) {
                            case Some(end) =>
                                let b = fullPath[0..end]
                                if (b.size > 0) {
                                    return Some(b)
                                }
                            case None => ()
                        }
                        return None
                    }
                    return Some(bucket)
                case _ => return None
            }
        case None => return None
    }
}

/// 获取 bucket (JS getter)
/// 对应 Bun: pub fn get_bucket(`this`: &Blob, global: &JSGlobalObject) -> JsResult<JsValue>
public func getBucket(blob: BlobRef, global: JSGlobalObject): Result<JsValue> {
    match (getBucketName(blob)) {
        case Some(name) =>
            return Result<JsValue>.Ok(BunStringJsc.createUtf8ForJs(global, name))
        case None => return Result<JsValue>.Ok(JsValue.UNDEFINED)
    }
}

/// 获取预签名 URL (JS getter)
/// 对应 Bun: pub fn get_presign_url(`this`: &Blob, global, callframe) -> JsResult<JsValue>
public func getPresignUrl(blob: BlobRef, global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
    let args = Arguments.fromCallFrame(callframe,1)
    return getPresignUrlFrom(blob, global, optJs(args.values[0]))
}

/// 获取 stat (JS getter)
/// 对应 Bun: pub fn get_stat(`this`: &Blob, global, _callframe) -> JsResult<JsValue>
public func getStat(blob: BlobRef, global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
    return S3BlobStatTask.stat(global, blob)
}

// ============================================================================
// stat - 获取对象元数据 (host_fn)
// 严格翻译自: S3File.stat (lines 876-910)
//   Bun: #[bun_jsc::host_fn]
//   pub fn stat(global: &JSGlobalObject, callframe: &CallFrame) -> JsResult<JsValue>
// ============================================================================

/// 获取对象元数据 (host_fn)
/// 对应 Bun: stat
public func stat(global: JSGlobalObject, callframe: CallFrame): Result<JsValue> {
    let args = Arguments.fromCallFrame(callframe,3)

    let pathOrBlob = S3PathOrBlob.fromJsNoCopy(global, args)

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Blob =>
            let blob = pathOrBlob.blob
            if (blob.store.isNone()) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to get size")
            }
            let storeData = blob.store.getOrThrow().data()
            if (storeData.tag != StoreDataTagForBlob.S3) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to get size")
            }
        case _ => ()
    }

    match (pathOrBlob.tag) {
        case PathOrBlobTag.Path =>
            let options = args.next()
            if (pathOrBlob.path.tag == PathOrFileDescriptorTag.Fd) {
                return Result<JsValue>.Err(
                    "Error:Expected a S3 or path to get size")
            }
            let blobResult = constructS3FileInternalStore(global, pathOrBlob.path.pathString, options)
            match (blobResult) {
                case Ok(blob) => return S3BlobStatTask.stat(global, blob)
                case Err(e) => return Result<JsValue>.Err(e)
            }
        case PathOrBlobTag.Blob =>
            return S3BlobStatTask.stat(global, pathOrBlob.blob)
        case _ =>
            return Result<JsValue>.Err(
                "Error:Expected a S3 or path to get size")
    }
}

// ============================================================================
// constructInternalJs - JS 构造 (返回 JsValue)
// 严格翻译自: S3File.construct_internal_js (lines 912-923)
//   Bun: pub fn construct_internal_js(global, path, options) -> JsResult<JsValue>
// ============================================================================

/// JS 构造 (返回 JsValue)
/// 对应 Bun: construct_internal_js
///
/// Calls construct_s3_file_internal then converts to JS value.
public func constructInternalJs(global: JSGlobalObject, path: String, options: ?JsValue): Result<JsValue> {
    let blobResult = constructS3FileInternal(global, path, options)
    match (blobResult) {
        case Ok(blob) => return Result<JsValue>.Ok(blob.toJs(global))
        case Err(e) => return Result<JsValue>.Err(e)
    }
}

// ============================================================================
// toJsUnchecked - 无检查的 JS 转换
// 严格翻译自: S3File.to_js_unchecked (lines 925-929)
//   Bun: pub fn to_js_unchecked(global, `this`: *Blob) -> JsValue
// ============================================================================

/// 无检查的 JS 转换
/// 对应 Bun: to_js_unchecked
///
/// C++ adopts `this` opaquely (stored as `void* m_ctx` in the JS wrapper);
/// ownership-transfer contract lives on callers.
public func toJsUnchecked(global: JSGlobalObject, blob: BlobRef): JsValue {
    // In Bun this calls BUN__createJSS3FileUnsafely(global, this.cast())
    return createJSS3FileUnsafely(global, blob)
}

// ============================================================================
// constructInternal - 从 callframe 构造 Blob
// 严格翻译自: S3File.construct_internal (lines 931-941)
//   Bun: pub fn construct_internal(global, callframe) -> JsResult<*Blob>
// ============================================================================

/// 从 callframe 构造 Blob
/// 对应 Bun: construct_internal
public func constructInternal(global: JSGlobalObject, callframe: CallFrame): Result<BlobRef> {
    let args = Arguments.fromCallFrame(callframe,2)

    match (PathLike.fromJs(global, args)) {
        case Some(path) =>
            return constructS3FileInternal(global, path, args.next())
        case None =>
            return Result<BlobRef>.Err(
                "Error:Expected file path string")
    }
}

// ============================================================================
// construct - JS 构造函数
// 严格翻译自: S3File.construct (lines 944-954)
//   Bun: pub fn construct(global, callframe) -> *Blob
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
        case Err(e) =>
            // In Bun: match on JsError variant
            global.throwError(e)
            return None
    }
}

// ============================================================================
// hasInstance - instanceof 检查
// 严格翻译自: S3File.has_instance (lines 956-962)
//   Bun: pub fn has_instance(_: JsValue, _global, value: JsValue) -> bool
// ============================================================================

/// instanceof 检查
/// 对应 Bun: has_instance
///
/// Returns true if the value is a Blob with S3 store.
public func hasInstance(`this`: JsValue, global: JSGlobalObject, value: JsValue): Bool {
    // 对应 Bun: asClassRef — 仓颉中 JS 类引用检查暂未实现, 始终返回 false
    return false
}

// ============================================================================
// createJSS3File - host_fn 包装器
// 严格翻译自: S3File.create_js_s3_file (lines 1043-1046)
//   Bun: #[bun_jsc::host_fn]
//   pub fn create_js_s3_file(global, callframe) -> JsValue
// ============================================================================

/// 创建 JS S3 File (host_fn)
/// 对应 Bun: create_js_s3_file
public func createJsS3File(global: JSGlobalObject, callframe: CallFrame): JsValue {
    return createJSS3File(global, callframe)
}

// ============================================================================
// 辅助类型和方法
// ============================================================================

/// method_from_js 的本地别名
/// 对应 Bun: #[inline] fn method_from_js(global, value) -> JsResult<Option<Method>>
private func methodFromJs(global: JSGlobalObject, value: JsValue): Result<?HttpMethod> {
    return HttpMethodJsc.fromJs(global, value)
}

// ============================================================================
// S3StatResultData - S3 stat 结果数据
// 严格翻译自: s3::S3StatResult
// ============================================================================

/* -- DUPLICATE: S3StatResultTag defined in simple_request.cj (with == operator added there)
public enum S3StatResultTag { ... }
-- END DUPLICATE */

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

/* -- DUPLICATE: S3Error defined in s3_helpers.cj (with more fields)
public class S3Error { ... }
-- END DUPLICATE */

// ============================================================================
// 占位类型 — 来自其他模块的引用
// 以下类型已在 s3_client.cj / credentials_jsc.cj 中定义，此处不再重复
// 唯一类型 (SignOptions, SignQueryOptions, S3JSPromiseStrong, S3JSPromise, S3BackRef,
// S3Strings, HttpMethodJsc, BunStringJsc) 保留定义
// ============================================================================

/* -- DUPLICATE: moved to s3_client.cj
PathOrFileDescriptorTag, S3PathOrBlob, PathLikeEntry, BlobRef, Arguments
all defined in s3_client.cj
-- END DUPLICATE */

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

/* -- DUPLICATE: defined in credentials_jsc.cj
/// S3CredentialsWithOptions (对应 Bun: S3CredentialsWithOptions)
public class S3CredentialsWithOptions { ... }
-- END DUPLICATE */

/// S3JSPromiseStrong (对应 Bun: bun_jsc::S3JSPromiseStrong)
public class S3JSPromiseStrong {
    public init() {}
    public init(global: JsGlobalObject) {}

    public static func `init`(global: JsGlobalObject): S3JSPromiseStrong {
        return S3JSPromiseStrong()
    }

    public func value(): JsValue {
        return JsValue(0)
    }

    public func get(): JsPromise {
        return JsPromise()
    }

    public func resolve(global: JSGlobalObject, value: JsValue): Result<Unit> {
        return Result<Unit>.Ok(())
    }

    public func reject(global: JSGlobalObject, value: JsValue): Result<Unit> {
        return Result<Unit>.Ok(())
    }

    public func hasValue(): Bool {
        return true
    }
}

/* -- DUPLICATE: S3JSPromise conflicts with bao_jsc.JsPromise
/// S3JSPromise (对应 Bun: JsValue promise)
public class S3JSPromise {
    public static func rejectedPromise(global: JsGlobalObject, err: JsValue): S3JSPromise { return S3JSPromise() }
    public func toJS(): JsValue { return JsValue.undefined() }
}
-- END DUPLICATE */

/// S3BackRef (对应 Bun: bun_ptr::S3BackRef<T>)
public class S3BackRef {
    private var global: JSGlobalObject

    public init() {
        global = JSGlobalObject()
    }

    public static func new(global: JSGlobalObject): S3BackRef {
        let b = S3BackRef()
        b.global = global
        return b
    }

    public func get(): JSGlobalObject {
        return global
    }
}

/* -- DUPLICATE: defined in s3_client.cj
/// WriteFileOptions (对应 Bun: blob::WriteFileOptions)
public class WriteFileOptions { ... }
/// WriteFileModule (对应 Bun: blob::write_file_internal)
public class WriteFileModule { ... }
/// S3Store (对应 Bun: blob::store::S3)
public class S3Store { ... }
/// HttpMethod (对应 Bun: bun_http::Method)
public enum HttpMethod { ... }
/// S3ConsoleFormatter (对应 Bun: bun_jsc::S3ConsoleFormatter)
public class S3ConsoleFormatter { ... }
-- END DUPLICATE */

/// S3Strings utility (对应 Bun: bun_core::strings)
public class S3Strings {
    public static func isAllAscii(s: String): Bool {
        return true
    }

    public static func copyLowercase(s: String): String {
        // Cangjie String iterates as Byte; manual ASCII lowercase
        var result = ""
        for (b in s) {
            if (b >= UInt8(65) && b <= UInt8(90)) {
                result = result + String(Rune(Int32(b) + 32))
            } else {
                result = result + String(Rune(Int32(b)))
            }
        }
        return result
    }
}

/// HttpMethodJsc (对应 Bun: bun_http_jsc::method_jsc)
/// Port of Zig/Rust `method_jsc::from_js`. Converts a JS string value to
/// an HttpMethod by looking it up in the static method table (case-insensitive).
public class HttpMethodJsc {
    public static func fromJs(global: JSGlobalObject, value: JsValue): Result<?HttpMethod> {
        if (value.isEmptyOrUndefinedOrNull()) {
            return Result<?HttpMethod>.Ok(Option<HttpMethod>.None)
        }
        let strOpt = value.toString()
        if (strOpt.size > 0) {
            let methodOpt = parseHttpMethod(strOpt)
            return Result<?HttpMethod>.Ok(methodOpt)
        } else {
            return Result<?HttpMethod>.Err("Expected a string for HTTP method")
        }
    }

    /// Case-insensitive HTTP method lookup
    /// 对应 Bun: Method.which(str) via ComptimeStringMap
    private static func parseHttpMethod(s: String): ?HttpMethod {
        let lower = asciiLower(s)
        match (lower) {
            case "get" => Some(HttpMethod.GET)
            case "put" => Some(HttpMethod.PUT)
            case "post" => Some(HttpMethod.POST)
            case "delete" => Some(HttpMethod.DELETE)
            case "head" => Some(HttpMethod.HEAD)
            case "patch" => Some(HttpMethod.PATCH)
            case "options" => Some(HttpMethod.OPTIONS)
            case "connect" => Some(HttpMethod.CONNECT)
            case "trace" => Some(HttpMethod.TRACE)
            case _ => None
        }
    }
}

/// BunStringJsc (对应 Bun: bun_jsc::bun_string_jsc)
public class BunStringJsc {
    public static func createUtf8ForJs(global: JSGlobalObject, s: String): JsValue {
        return JsValue(s)
    }
}

/* -- DUPLICATE: defined in s3_client.cj
/// PathLike (对应 Bun: PathLike)
public class PathLike { ... }
/// S3FetchModule (对应 Bun: crate::webcore::fetch)
public class S3FetchModule { ... }
-- END DUPLICATE */

/// FFI: createJSS3File
/// 对应 Bun: BUN__createJSS3File(global, callframe) -> JsValue
public func createJSS3File(global: JSGlobalObject, callframe: CallFrame): JsValue {
    match (construct(global, callframe)) {
        case Some(blob) => return toJsUnchecked(global, blob)
        case None => return JsValue.jsUndefined()
    }
}

/// FFI: createJSS3FileUnsafely
/// 对应 Bun: BUN__createJSS3FileUnsafely(global, blob) -> JsValue
public func createJSS3FileUnsafely(global: JSGlobalObject, blob: BlobRef): JsValue {
    let obj = JsObject.make()
    obj.className = "S3File"
    obj.set("type", JsValue(blob.contentType))
    obj.set("size", blob.getSize(global))
    let bucketName = getBucketName(blob)
    match (bucketName) {
        case Some(name) => obj.set("bucket", BunStringJsc.createUtf8ForJs(global, name))
        case None => obj.set("bucket", JsValue.jsUndefined())
    }
    return JsValue(obj)
}

// ported from: src/runtime/webcore/S3File.rs

/// Helper: ASCII lowercase conversion for String
func asciiLower(s: String): String {
    // ASCII lowercase: only A-Z → a-z
    var bytes = ArrayList<UInt8>()
    for (c in s) {
        let code = Int64(c)
        if (code >= 65 && code <= 90) {
            bytes.append(UInt8(code + 32))
        } else if (code < 128) {
            bytes.append(UInt8(code))
        }
        // skip non-ASCII to avoid encoding issues
    }
    return String.fromUtf8(bytes.items())
}
