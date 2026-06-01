// FetchTasklet - Fetch 任务单元
// 严格翻译自: src/runtime/webcore/fetch/FetchTasklet.rs (Rust port of FetchTasklet.zig)
// 包含: FetchTasklet 完整实现, HTTPRequestBody, FetchOptions, 回调方法等
package bao_runtime.webcore.fetch

import bao_core.*
import bao_collections.*
import bao_runtime.*
import bao_runtime.webcore.*
import bao_http_types.*
import bao_jsc.*
import bao_collections.ArrayList
import bao_boringssl.*

// ============================================================================
// 类型定义 — 用于消歧义和缺失类型补充
// ============================================================================

public class BlobStore {
    public init() {}
}
public class JsValue {
    public static let ZERO = JsValue()
    public static let UNDEFINED = JsValue()
    public init() {}
    public func isEmptyOrUndefinedOrNull(): Bool { true }
    public func isAnyError(): Bool { false }
    public func isUndefinedOrNull(): Bool { true }
    public func isEmpty(): Bool { true }
    public func asResponse(): ?Response { None }
    public func asAnyPromise(): ?AnyPromise { None }
    public func ensureStillAlive(): Unit {}
    public func call(g: JsGlobalObject, t: JsValue, a: Array<JsValue>): JsValue { JsValue.ZERO }
}
public class VirtualMachine {
    public init() {}
    public func isShuttingDown(): Bool { false }
    public func jscVm(): VirtualMachine { this }
    public func eventLoopShared(): EventLoopShared { EventLoopShared() }
    public func bunVm(): VirtualMachine { this }
    public func transpiler(): Transpiler { Transpiler() }
    public func drainMicrotasks(): Unit {}
    public func getOrThrow(): VirtualMachine { this }
}
public class Response {
    public init() {}
    public init(i: ResponseInit, b: Body, u: BunString, r: Bool) {}
    public static func makeMaybePooled(g: JsGlobalObject, r: Response): JsValue { JsValue.ZERO }
    public static func ref(r: Response): Response { r }
    public static func unref(r: Response): Unit {}
    public func getBodyValue(): BodyValue { BodyValue() }
    public func getFetchHeaders(): FetchHeaders { FetchHeaders() }
    public func setSizeHint(h: Int64): Unit {}
    public func getBodyReadableStream(g: JsGlobalObject): ?ReadableStream { None }
    public func detachReadableStream(g: JsGlobalObject): Unit {}
}
public class AbortSignal {
    public init() {}
    public func aborted(): Bool { false }
    public func reasonIfAborted(g: JsGlobalObject): ?JsValue { None }
    public func pendingActivityRef(): Unit {}
    public func pendingActivityUnref(): Unit {}
    public func unref(): Unit {}
    public func cleanNativeBindings(c: FetchTasklet): Unit {}
    public func addListener(c: FetchTasklet, l: (FetchTasklet, JsValue) -> Unit): Unit {}
}
public class Signals {
    public var certErrors: ?CertificateInfo = None
    public init() {}
}
public class Headers {
    public init() {}
    public func get(n: String): ?String { None }
}
public enum HttpMethod { | GET | POST | PUT | DELETE | HEAD | PATCH | OPTIONS | CONNECT | TRACE }
public enum FetchRedirect {
    | Follow | Error | Manual
    public operator func ==(r: FetchRedirect): Bool { match (this) { case Follow => match (r) { case Follow => true case _ => false } case Error => match (r) { case Error => true case _ => false } case Manual => match (r) { case Manual => true case _ => false } } }
    public operator func !=(r: FetchRedirect): Bool { !(this == r) }
}
public enum BodySize {
    | Unknown | ContentLength(Int64) | TotalReceived(Int64)
    public static func unknown(): BodySize { Unknown }
}
public enum HTTPVerboseLevel { | None | Headers | Text }
public enum WriteMessageType { | Data | End }
public class CertificateInfo {
    public init() {}
    public var cert: Array<UInt8> = Array<UInt8>()
    public var hostname: String = ""
}
public type BlobSizeType = Int64
public class JSResult<T> {
    public var value: ?T = None
    public var error: ?JsValue = None
    public init() {}
    public static func ok(v: T): JSResult<T> { let r = JSResult<T>(); r.value = Some(v); return r }
    public static func err(e: JsValue): JSResult<T> { let r = JSResult<T>(); r.error = Some(e); return r }
}
public class GlobalRef {
    public init() {}
    public static func from(g: JsGlobalObject): GlobalRef { GlobalRef() }
    public func get(): JsGlobalObject { JsGlobalObject() }
}
public class AsyncHTTP {
    public init() {}
    public init(m: HttpMethod, u: URL, h: Headers, b: MutableString, bd: Array<UInt8>, cb: (FetchTasklet, AsyncHTTP, HTTPClientResult) -> Unit, rd: FetchRedirect, o: AsyncHTTPOptions) {}
    public func schedule(): Unit {}
    public func client(): HTTPClient { HTTPClient() }
    public func clearData(): Unit {}
    public func syncProgressFrom(o: AsyncHTTP): Unit {}
    public func enableResponseBodyStreaminging(): Unit {}
    public var url: URL = URL()
    public var requestBody: Any = ()
    public var asyncHttpId: Int64 = 0
}
public class HTTPClientResult {
    public init() {}
    public var hasMore: Bool = false
    public var canStream: Bool = false
    public var redirected: Bool = false
    public var bodySize: BodySize = Unknown
    public var certificateInfo: ?CertificateInfo = None
    public var metadata: ?HTTPResponseMetadata = None
    public var fail: ?BunError = None
    public func isSuccess(): Bool { true }
    public func isHttp2(): Bool { false }
    public func detachLifetime(): HTTPClientResult { HTTPClientResult() }
    public func abortReason(): ?JsValue { None }
}
public class HTTPResponseMetadata {
    public init() {}
    public var response: HTTPResponse = HTTPResponse()
    public var url: BunString = BunString()
}
public class HTTPResponse {
    public init() {}
    public var statusCode: Int64 = 0
    public var status: String = ""
    public var headers: HTTPResponseHeaders = HTTPResponseHeaders()
}
public class HTTPResponseHeaders {
    public init() {}
    public var list: Array<UInt8> = Array<UInt8>()
}
public class HTTPClient {
    public init() {}
    public func flags(): HTTPClientFlags { HTTPClientFlags() }
    public var remainingRedirectCount: Int64 = 0
}
public class HTTPClientFlags {
    public init() {}
    public var isStreamingRequestBody: Bool = false
    public var forceHttp2: Bool = false
    public var forceHttp3: Bool = false
    public var forceHttp1: Bool = false
}
public class AsyncHTTPOptions {
    public init() {}
    public init(p: ?URL, h: ?ArrayList<UInt8>, s: Signals, r: Bool, v: HTTPVerboseLevel, ss: ?SslConfigSharedPtr) {}
}
public class HTTPThread {
    public init() {}
    public static func initDefault(): Unit {}
    public static func schedule(h: AsyncHTTP): Unit {}
    public static func scheduleShutdown(h: AsyncHTTP): Unit {}
    public static func scheduleRequestWrite(h: AsyncHTTP, m: WriteMessageType): Unit {}
    public static func scheduleResponseBodyDrain(i: Int64): Unit {}
}
public class ThreadSafeStreamBuffer {
    public init() {}
    public func setDrainCallback(c: (FetchTasklet) -> Unit, x: FetchTasklet): Unit {}
    public func clearDrainCallback(): Unit {}
    public static func deref(b: ThreadSafeStreamBuffer): Unit {}
    public func isEmpty(): Bool { true }
    public func write(d: Array<UInt8>): Unit {}
    public func writeAssumeCapacity(d: Array<UInt8>): Unit {}
    public func size(): Int64 { 0 }
    public func lock(): Mutex { Mutex() }
}
public class HTTPRequestBodyStream {
    public var buffer: ThreadSafeStreamBuffer
    public var ended: Bool
    public init(b: ThreadSafeStreamBuffer, e: Bool) { buffer = b; ended = e }
}
public class HTTPRequestBodySendfile {
    public var sendfile: SendFile
    public init(s: SendFile) { sendfile = s }
}
public class SslConfigSharedPtr { public init() {} }
public class BunError {
    public var errorName: String
    public init(n: String) { errorName = n }
    public func name(): String { errorName }
    public operator func ==(r: String): Bool { errorName == r }
    public operator func !=(r: String): Bool { errorName != r }
}
public class EventLoopShared { public init() {}; public func enqueueTaskConcurrent(t: ConcurrentTask): Unit {} }
public class Transpiler { public init() {}; public func envMut(): Environment { Environment() } }
public class Environment { public init() {}; public func isNoProxy(h: String, host: String): Bool { false }; public func getHttpProxyFor(u: URL): ?URL { None } }
public class JsGlobalObject { public init() {}; public func err(c: JSErrorCode, m: String): JsValue { JsValue.ZERO }; public func bunVm(): VirtualMachine { VirtualMachine() } }
public class AnyPromise { public init() {}; public func rejectWithAsyncStack(g: JsGlobalObject, v: JsValue): Unit {}; public func resolve(g: JsGlobalObject, v: JsValue): Unit {} }
public enum JSErrorCode { | BODY_ALREADY_USED | TypeError | RangeError | Other }
public class Mutex { public init() {}; public func lock(): Unit {}; public func unlock(): Unit {}; public func write(d: Array<UInt8>): Unit {} }
public class BunString { public init() {}; public static func cloneUtf8(s: String): BunString { BunString() }; public func toJS(g: JsGlobalObject): JsValue { JsValue.ZERO }; public func slice(): String { "" } }
public class SystemError {
    public var errno: Int64; public var code: String; public var message: String; public var path: String; public var syscall: String; public var hostname: String; public var fd: Int64; public var dest: String
    public init(e: Int64, c: String, m: String, p: String, s: String, h: String, f: Int64, d: String) { errno = e; code = c; message = m; path = p; syscall = s; hostname = h; fd = f; dest = d }
    public init() { errno = 0; code = ""; message = ""; path = ""; syscall = ""; hostname = ""; fd = -1; dest = "" }
}
public class OwnedString { public init() {}; public static func cloneUtf8(s: String): OwnedString { OwnedString() }; public func toJS(g: JsGlobalObject): JsValue { JsValue.ZERO } }
public class JsWeak { public init() {}; public static func create(v: JsValue, g: JsGlobalObject, r: JsWeakRefType, c: FetchTasklet): JsWeak { JsWeak() }; public func get(): ?JsValue { None }; public func clear(): Unit {} }
public class JSPromiseStrong { public init() {}; public static func empty(): JSPromiseStrong { JSPromiseStrong() }; public func valueOrEmpty(): JsValue { JsValue.ZERO }; public func take(): JSPromiseStrong { JSPromiseStrong() }; public func isEmptyOrUndefinedOrNull(): Bool { true } }
public class ReadableStreamStrong { public init() {}; public init(s: ReadableStream, g: JsGlobalObject) {}; public func get(g: JsGlobalObject): ?ReadableStream { None }; public func has(): Bool { false }; public func deinit(): Unit {} }
public class ReadableStream { public init() {}; public var value: JsValue = JsValue.ZERO; public func ptr(): ReadableStreamPtr { ReadableStreamPtr() }; public func abort(g: JsGlobalObject): Unit {}; public func cancelWithReason(g: JsGlobalObject, r: JsValue): Unit {} }
public class ReadableStreamPtr { public init() {}; public func bytes(): ?StreamBytes { None } }
public class StreamBytes { public init() {}; public var sizeHint: SizeHint = SizeHint(); public func onData(r: StreamResult): Unit {}; public func parentConst(): StreamSource { StreamSource() } }
public class SizeHint { public init() {}; public func set(n: Int64): Unit {} }
public class StreamSource { public init() {}; public var cancelHandler: ?Any = None; public var cancelCtx: ?Any = None }
public class X509 { public init() {}; public static func toJS(x: ?Any, g: JsGlobalObject): ?JsValue { None } }
public func d2iX509(d: Any): ?Any { None }
public class AnyBlob { public init() {}; public func store(): ?BlobStore { None }; public func slice(): Array<UInt8> { Array<UInt8>() }; public func detach(): Unit {}; public func needsToReadFile(): Bool { false }; public func isS3(): Bool { false }; public func hasContentTypeFromUser(): Bool { false }; public func size(): Int64 { 0 } }
public class HeadersRef { public init() {}; public static func adopt(h: FetchHeaders): HeadersRef { HeadersRef() } }
public class ResponseInit { public init() {}; public init(h: HeadersRef, s: Int64, t: String) {} }
public class Body { public init() {}; public init(v: BodyValue) {} }
public class URL {
    public init() {}
    public static func parse(d: Array<UInt8>): URL { URL() }
    public var href: String = ""
    public var hostname: String = ""
    public var host: String = ""
    public func isEmpty(): Bool { true }
}
public class ZigStringSlice { public static let EMPTY = ZigStringSlice(); public init() {} }
public class SSLConfig { public init() {} }
public enum JsWeakRefType { | FetchResponse | Other }
public enum BodyValueError {
    | JsVal(StrongOptional) | AbortReason(StrongOptional) | SysErr(SystemError) | TypeError(String) | Message(String)
    public static func jsValue(v: StrongOptional): BodyValueError { JsVal(v) }
    public static func abortReason(r: JsValue): BodyValueError { Message("abort") }
    public static func fromAbortReason(r: JsValue): BodyValueError { Message("abort") }
    public static func systemError(e: SystemError): BodyValueError { SysErr(e) }
    public static func typeError(m: String): BodyValueError { TypeError(m) }
    public func toJS(g: JsGlobalObject): JsValue { JsValue.ZERO }
    public func reset(): Unit {}
    public func dupe(): BodyValueError { Message("") }
    public func takeJSValue(): JsValue { JsValue.ZERO }
}
public enum BodyValueTag {
    | Used | Locked | Blob | Empty
    public operator func ==(r: BodyValueTag): Bool { match (this) { case Used => match (r) { case Used => true case _ => false } case Locked => match (r) { case Locked => true case _ => false } case Blob => match (r) { case Blob => true case _ => false } case Empty => match (r) { case Empty => true case _ => false } } }
    public operator func !=(r: BodyValueTag): Bool { !(this == r) }
}
public class BodyValue {
    public init() {}
    public var tag: BodyValueTag = Empty
    public var lockedValue: LockedBodyValue = LockedBodyValue()
    public static func error(e: BodyValueError): BodyValue { BodyValue() }
    public static func locked(p: BodyPendingValue): BodyValue { BodyValue() }
    public static func internalBlob(b: InternalBlob): BodyValue { BodyValue() }
    public static func fromJS(g: JsGlobalObject, v: JsValue): BodyValue { BodyValue() }
    public func isLocked(): Bool { false }
    public func resolve(g: JsGlobalObject, h: FetchHeaders): Unit {}
    public func setInternalBlob(b: InternalBlob): Unit {}
    public func toErrorInstance(e: BodyValueError, g: JsGlobalObject): Unit {}
    public func useAsAnyBlob(): AnyBlob { AnyBlob() }
    public func toReadableStream(g: JsGlobalObject): JsValue { JsValue.ZERO }
}
public class LockedBodyValue {
    public init() {}
    public var readable: ReadableStreamStrong = ReadableStreamStrong()
    public var promise: ?JSPromiseStrong = None
}
public class InternalBlob {
    public var bytes: ArrayList<UInt8>
    public var wasString: Bool
    public init(b: ArrayList<UInt8>, w: Bool) { bytes = b; wasString = w }
    public init() { bytes = ArrayList<UInt8>(); wasString = false }
    public func asSlice(): Array<UInt8> { bytes.items() }
}
public class ResumableFetchSink {
    public init() {}
    public static func initExactRefs(g: JsGlobalObject, s: ReadableStream, t: FetchTasklet, r: Int64): ResumableFetchSink { ResumableFetchSink() }
    public func detachJs(): Unit {}
    public static func deref(s: ResumableFetchSink): Unit {}
    public func drain(): Unit {}
    public func cancel(v: JsValue): Unit {}
    public func highWaterMark(): Int64 { 16384 }
}
public class StrongOptional {
    public init() {}
    public static func empty(): StrongOptional { StrongOptional() }
    public static func create(v: JsValue, g: JsGlobalObject): StrongOptional { StrongOptional() }
    public func has(): Bool { false }
    public func get(): ?JsValue { None }
    public func set(g: JsGlobalObject, v: JsValue): Unit {}
    public func swap(): JsValue { JsValue.ZERO }
    public func deinit(): Unit {}
    public func takeJSValue(): JsValue { JsValue.ZERO }
    public func toJS(g: JsGlobalObject): JsValue { JsValue.ZERO }
    public func reset(): Unit {}
}
public class SignalsStore {
    public var headerProgress: Bool = false
    public var certErrors: Bool = false
    public var aborted: Bool = false
    public init() {}
    public func toSignals(): Signals { Signals() }
}
public class FetchHeaders { public init() {}; public static func createFromPicoHeaders(h: Array<UInt8>): FetchHeaders { FetchHeaders() } }
/// StreamResult 标签 — 流式传输结果类型
/// 对应 Bun: StreamResult union tag
public enum StreamResultTag {
    | Temporary         // 临时数据块 (流未结束)
    | TemporaryAndDone  // 临时数据块 + 流已结束
    | Err               // 错误
}

/// StreamResult — 流式传输结果
/// 对应 Bun: StreamResult union { .temporary = ByteList, .temporary_and_done = ByteList, .err = Error }
/// 携带从 HTTP 响应体接收到的数据块以及流完成状态
public class StreamResult {

    /// 结果标签
    public var tag: StreamResultTag
    /// 数据块 (borrowed from scheduled_response_buffer)
    public var chunk: Array<UInt8>
    /// 错误 (仅 Err 标签时有效)
    public var error: ?StreamError

    public init() {
        tag = StreamResultTag.Temporary
        chunk = Array<UInt8>()
        error = None
    }

    /// 创建临时数据块 (流未结束)
    /// 对应 Bun: StreamResult{ .temporary = byte_list }
    public static func temporary(chunk: Array<UInt8>): StreamResult {
        let r = StreamResult()
        r.tag = StreamResultTag.Temporary
        r.chunk = chunk
        return r
    }

    /// 创建临时数据块 (流已结束)
    /// 对应 Bun: StreamResult{ .temporary_and_done = byte_list }
    public static func temporaryAndDone(chunk: Array<UInt8>): StreamResult {
        let r = StreamResult()
        r.tag = StreamResultTag.TemporaryAndDone
        r.chunk = chunk
        return r
    }

    /// 创建错误结果
    /// 对应 Bun: StreamResult{ .err = error }
    public static func err(e: StreamError): StreamResult {
        let r = StreamResult()
        r.tag = StreamResultTag.Err
        r.error = Some(e)
        return r
    }

    /// 是否有数据
    public func hasData(): Bool {
        match (tag) {
            case StreamResultTag.Temporary => true
            case StreamResultTag.TemporaryAndDone => true
            case _ => false
        }
    }

    /// 流是否已结束
    public func isDone(): Bool {
        match (tag) {
            case StreamResultTag.TemporaryAndDone => true
            case StreamResultTag.Err => true
            case _ => false
        }
    }
}
/// StreamError — 流传输错误
/// 对应 Bun: ByteStream.Source.Error union { .JSValue = JSValue }
public class StreamError {
    /// 错误值
    public var jsValue: ?JsValue

    public init() {
        jsValue = None
    }

    /// 从 JS 值创建流错误
    /// 对应 Bun: Error{ .JSValue = value }
    public static func fromJsValue(v: JsValue): StreamError {
        let e = StreamError()
        e.jsValue = Some(v)
        return e
    }

    /// 获取 JS 值
    public func getJSValue(): JsValue {
        if (jsValue.isSome()) {
            let v = jsValue.getOrThrow()
            return v
        }
        JsValue.UNDEFINED
    }
}
public class AnyTask { public init() {} }
public class ConcurrentTask { public init() {}; public func from(t: FetchTasklet): ConcurrentTask { ConcurrentTask() }; public static func fromCallback(t: FetchTasklet, c: (FetchTasklet) -> Unit): ConcurrentTask { ConcurrentTask() } }
public class AsyncTaskTracker { public init() {}; public func didSchedule(g: JsGlobalObject): Unit {}; public func didDispatch(g: JsGlobalObject): Unit {}; public func willDispatch(g: JsGlobalObject): Unit {}; public func didCancel(g: JsGlobalObject): Unit {} }
public class KeepAlive { public init() {}; public func ref(): Unit {}; public func unref(): Unit {} }
public let END_OF_CHUNKED_HTTP1_1_ENCODING_RESPONSE_BODY: Array<UInt8> = [UInt8(48), UInt8(13), UInt8(10), UInt8(13), UInt8(10)]
public class BodyPendingValue {
    public var sizeHint: BlobSizeType = 0
    public var task: FetchTasklet = FetchTasklet()
    public var onStartStreaming: () -> DrainResult = { => DrainResult.EstimatedSize(0) }
    public var onReadableStreamAvailable: (JsGlobalObject, ReadableStream) -> Unit = { _, _ => }
    public var onStreamCancelled: () -> Unit = { => }
    public init(g: JsGlobalObject) {}
}
public class MutableString {
    public var list: ArrayList<UInt8>
    public init() { list = ArrayList<UInt8>() }
    public func isEmpty(): Bool { list.isEmpty() }
    public func reset(): Unit { list = ArrayList<UInt8>() }
    public func write(d: Array<UInt8>): Unit { for (b in d) { list.append(b) } }
}

// ============================================================================
// HTTPRequestBody - HTTP 请求体
// 严格翻译自 FetchTasklet.rs HTTPRequestBody
// ============================================================================

/// HTTP 请求体类型
/// 严格翻译自 HTTPRequestBody
public enum HTTPRequestBodyTag {
    | AnyBlob
    | Sendfile
    | ReadableStream
    public operator func ==(r: HTTPRequestBodyTag): Bool { match (this) { case AnyBlob => match (r) { case AnyBlob => true case _ => false } case Sendfile => match (r) { case Sendfile => true case _ => false } case ReadableStream => match (r) { case ReadableStream => true case _ => false } } }
    public operator func !=(r: HTTPRequestBodyTag): Bool { !(this == r) }
}

/// HTTP 请求体
/// 严格翻译自 FetchTasklet.rs HTTPRequestBody
public class HTTPRequestBody {
    public var tag: HTTPRequestBodyTag
    /// AnyBlob 数据
    public var anyBlob: AnyBlob
    /// Sendfile 信息
    public var sendfile: SendFile
    /// ReadableStream 引用
    public var readableStream: ReadableStreamStrong

    public init() {
        tag = HTTPRequestBodyTag.AnyBlob
        anyBlob = AnyBlob()
        sendfile = SendFile()
        readableStream = ReadableStreamStrong()
    }

    /// 获取 Blob 存储
    /// 严格翻译自 HTTPRequestBody.store()
    public func store(): ?BlobStore {
        match (tag) {
            case HTTPRequestBodyTag.AnyBlob => anyBlob.store()
            case _ => None
        }
    }

    /// 获取数据切片
    /// 严格翻译自 HTTPRequestBody.slice()
    public func slice(): Array<UInt8> {
        match (tag) {
            case HTTPRequestBodyTag.AnyBlob => anyBlob.slice()
            case _ => Array<UInt8>()
        }
    }

    /// 分离请求体
    /// 严格翻译自 HTTPRequestBody.detach()
    public func detach(): Unit {
        match (tag) {
            case HTTPRequestBodyTag.AnyBlob => anyBlob.detach()
            case HTTPRequestBodyTag.ReadableStream =>
                readableStream.deinit()
            case HTTPRequestBodyTag.Sendfile =>
                if (sendfile.offset > 0 || sendfile.remain > 0) {
                    sendfile.close()
                }
                sendfile.offset = 0
                sendfile.remain = 0
        }
    }

    /// 从 JS 值创建请求体
    /// 严格翻译自 HTTPRequestBody.from_js()
    public static func fromJS(globalThis: JsGlobalObject, value: JsValue): JSResult<HTTPRequestBody> {
        var bodyValue = BodyValue.fromJS(globalThis, value)
        match (bodyValue.tag) {
            case BodyValueTag.Used =>
                return JSResult.err(globalThis.err(JSErrorCode.BODY_ALREADY_USED, "body already used"))
            case BodyValueTag.Locked =>
                if (bodyValue.lockedValue.readable.has()) {
                    let result = HTTPRequestBody()
                    result.tag = HTTPRequestBodyTag.ReadableStream
                    result.readableStream = bodyValue.lockedValue.readable
                    return JSResult.ok(result)
                }
            case _ => ()
        }

        // 尝试转换为 ReadableStream
        if (bodyValue.tag == BodyValueTag.Locked) {
            let readable = bodyValue.toReadableStream(globalThis)
            if (!readable.isEmptyOrUndefinedOrNull()) {
                if (bodyValue.tag == BodyValueTag.Locked) {
                    if (bodyValue.lockedValue.readable.has()) {
                        let result = HTTPRequestBody()
                        result.tag = HTTPRequestBodyTag.ReadableStream
                        result.readableStream = bodyValue.lockedValue.readable
                        return JSResult.ok(result)
                    }
                }
            }
        }

        let result = HTTPRequestBody()
        result.tag = HTTPRequestBodyTag.AnyBlob
        result.anyBlob = bodyValue.useAsAnyBlob()
        return JSResult.ok(result)
    }

    /// 是否需要读取文件
    /// 严格翻译自 HTTPRequestBody.needs_to_read_file()
    public func needsToReadFile(): Bool {
        match (tag) {
            case HTTPRequestBodyTag.AnyBlob => anyBlob.needsToReadFile()
            case _ => false
        }
    }

    /// 是否为 S3
    /// 严格翻译自 HTTPRequestBody.is_s3()
    public func isS3(): Bool {
        match (tag) {
            case HTTPRequestBodyTag.AnyBlob => anyBlob.isS3()
            case _ => false
        }
    }

    /// 是否有用户提供的 content-type
    /// 严格翻译自 HTTPRequestBody.has_content_type_from_user()
    public func hasContentTypeFromUser(): Bool {
        match (tag) {
            case HTTPRequestBodyTag.AnyBlob => anyBlob.hasContentTypeFromUser()
            case _ => false
        }
    }

    /// 获取 AnyBlob
    /// 严格翻译自 HTTPRequestBody.get_any_blob()
    public func getAnyBlob(): ?AnyBlob {
        match (tag) {
            case HTTPRequestBodyTag.AnyBlob => Some(anyBlob)
            case _ => None
        }
    }

    /// 是否有请求体
    /// 严格翻译自 HTTPRequestBody.has_body()
    public func hasBody(): Bool {
        match (tag) {
            case HTTPRequestBodyTag.AnyBlob => anyBlob.size() > 0
            case HTTPRequestBodyTag.ReadableStream => readableStream.has()
            case HTTPRequestBodyTag.Sendfile => true
        }
    }
}

// ============================================================================
// FetchTasklet - Fetch 任务单元
// 严格翻译自 FetchTasklet.rs FetchTasklet
// ============================================================================

/// FetchTasklet — 单个 fetch 请求的任务单元
/// 严格翻译自 FetchTasklet.rs FetchTasklet
/// 管理 fetch 请求的生命周期、HTTP 回调、Promise 解析和错误处理
public class FetchTasklet {
    /// 可恢复 Sink (用于上传流式请求体)
    /// 严格翻译自 FetchTasklet.sink
    public var sink: ?ResumableFetchSink
    /// AsyncHTTP 实例
    /// 严格翻译自 FetchTasklet.http
    public var http: ?AsyncHTTP
    /// HTTP 客户端结果
    /// 严格翻译自 FetchTasklet.result
    public var result: HTTPClientResult
    /// HTTP 响应元数据
    /// 严格翻译自 FetchTasklet.metadata
    public var metadata: ?HTTPResponseMetadata
    /// JavaScript 虚拟机引用
    /// 严格翻译自 FetchTasklet.javascript_vm
    public var javascriptVm: ?VirtualMachine
    /// 全局对象引用
    /// 严格翻译自 FetchTasklet.global_this
    public var globalThis: JsGlobalObject
    /// 请求体
    /// 严格翻译自 FetchTasklet.request_body
    public var requestBody: HTTPRequestBody
    /// 请求体流式缓冲区
    /// 严格翻译自 FetchTasklet.request_body_streaming_buffer
    public var requestBodyStreamingBuffer: ?ThreadSafeStreamBuffer
    /// 响应缓冲区 (AsyncHTTP 使用)
    /// 严格翻译自 FetchTasklet.response_buffer
    public var responseBuffer: MutableString
    /// 调度响应缓冲区 (流式传输给 JS)
    /// 严格翻译自 FetchTasklet.scheduled_response_buffer
    public var scheduledResponseBuffer: MutableString
    /// 响应弱引用 (跟踪 JS 生命周期)
    /// 严格翻译自 FetchTasklet.response
    public var response: JsWeak
    /// 原生响应引用 (JS 丢弃后仍需访问时使用)
    /// 严格翻译自 FetchTasklet.native_response
    public var nativeResponse: ?Response
    /// 是否忽略数据
    /// 严格翻译自 FetchTasklet.ignore_data
    public var ignoreData: Bool
    /// 可读流强引用
    /// 严格翻译自 FetchTasklet.readable_stream_ref
    public var readableStreamRef: ReadableStreamStrong
    /// 请求头
    /// 严格翻译自 FetchTasklet.request_headers
    public var requestHeaders: Headers
    /// JS Promise 强引用
    /// 严格翻译自 FetchTasklet.promise
    public var promise: JSPromiseStrong
    /// 并发任务
    /// 严格翻译自 FetchTasklet.concurrent_task
    public var concurrentTask: ConcurrentTask
    /// 轮询引用 (保持进程活跃)
    /// 严格翻译自 FetchTasklet.poll_ref
    public var pollRef: KeepAlive
    /// Body 大小
    /// 严格翻译自 FetchTasklet.body_size
    public var bodySize: BodySize
    /// URL + proxy 内存缓冲区
    /// 严格翻译自 FetchTasklet.url_proxy_buffer
    public var urlProxyBuffer: ArrayList<UInt8>
    /// 中止信号
    /// 严格翻译自 FetchTasklet.signal
    public var signal: ?AbortSignal
    /// HTTP 信号
    /// 严格翻译自 FetchTasklet.signals
    public var signals: Signals
    /// 信号存储
    /// 严格翻译自 FetchTasklet.signal_store
    public var signalStore: SignalsStore
    /// 是否已调度回调
    /// 严格翻译自 FetchTasklet.has_schedule_callback
    public var hasScheduleCallback: Bool
    /// 中止原因
    /// 严格翻译自 FetchTasklet.abort_reason
    public var abortReason: StrongOptional
    /// 自定义 checkServerIdentity
    /// 严格翻译自 FetchTasklet.check_server_identity
    public var checkServerIdentity: StrongOptional
    /// 是否拒绝未授权
    /// 严格翻译自 FetchTasklet.reject_unauthorized
    public var rejectUnauthorized: Bool
    /// 是否已升级连接
    /// 严格翻译自 FetchTasklet.upgraded_connection
    public var upgradedConnection: Bool
    /// 自定义主机名
    /// 严格翻译自 FetchTasklet.hostname
    public var hostname: ?ArrayList<UInt8>
    /// 是否正在等待 body
    /// 严格翻译自 FetchTasklet.is_waiting_body
    public var isWaitingBody: Bool
    /// 是否正在等待中止
    /// 严格翻译自 FetchTasklet.is_waiting_abort
    public var isWaitingAbort: Bool
    /// 是否正在等待请求流启动
    /// 严格翻译自 FetchTasklet.is_waiting_request_stream_start
    public var isWaitingRequestStreamStart: Bool
    /// 互斥锁
    /// 严格翻译自 FetchTasklet.mutex
    public var mutex: Mutex
    /// 异步任务追踪器
    /// 严格翻译自 FetchTasklet.tracker
    public var tracker: AsyncTaskTracker
    /// 引用计数
    /// 严格翻译自 FetchTasklet.ref_count
    public var refCount: Int64

    public init() {
        sink = None
        http = None
        result = HTTPClientResult()
        metadata = None
        javascriptVm = None
        globalThis = JsGlobalObject()
        requestBody = HTTPRequestBody()
        requestBodyStreamingBuffer = None
        responseBuffer = MutableString()
        scheduledResponseBuffer = MutableString()
        response = JsWeak()
        nativeResponse = None
        ignoreData = false
        readableStreamRef = ReadableStreamStrong()
        requestHeaders = Headers()
        promise = JSPromiseStrong()
        concurrentTask = ConcurrentTask()
        pollRef = KeepAlive()
        bodySize = BodySize.unknown()
        urlProxyBuffer = ArrayList<UInt8>()
        signal = None
        signals = Signals()
        signalStore = SignalsStore()
        hasScheduleCallback = false
        abortReason = StrongOptional.empty()
        checkServerIdentity = StrongOptional.empty()
        rejectUnauthorized = true
        upgradedConnection = false
        hostname = None
        isWaitingBody = false
        isWaitingAbort = false
        isWaitingRequestStreamStart = false
        mutex = Mutex()
        tracker = AsyncTaskTracker()
        refCount = 1
    }

    // ========================================================================
    // 引用计数
    // ========================================================================

    /// 增加引用
    /// 严格翻译自 FetchTasklet.ref_()
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    /// 严格翻译自 FetchTasklet.deref()
    public static func deref(task: FetchTasklet): Unit {
        task.refCount -= 1
        if (task.refCount <= 0) {
            FetchTasklet.deinit(task)
        }
    }

    /// 从其他线程减少引用
    /// 严格翻译自 FetchTasklet.deref_from_thread()
    public static func derefFromThread(task: FetchTasklet): Unit {
        task.refCount -= 1
        if (task.refCount <= 0) {
            let vm = task.javascriptVm
            if (vm.isSome()) {
                let v = vm.getOrThrow()
                if (v.isShuttingDown()) {
                    FetchTasklet.deinit(task)
                } else {
                    // 在主线程上执行 deinit
                    FetchTasklet.enqueueConcurrent(v, ConcurrentTask.fromCallback(task, FetchTasklet.deinitCallback))
                }
            } else {
                FetchTasklet.deinit(task)
            }
        }
    }

    /// deinit 回调 (用于并发任务)
    /// 严格翻译自 FetchTasklet.deinit_callback()
    public static func deinitCallback(task: FetchTasklet): Unit {
        FetchTasklet.deinit(task)
    }

    // ========================================================================
    // 创建和初始化
    // ========================================================================

    /// 入队并发任务
    /// 严格翻译自 FetchTasklet.enqueue_concurrent()
    public static func enqueueConcurrent(vm: VirtualMachine, task: ConcurrentTask): Unit {
        vm.eventLoopShared().enqueueTaskConcurrent(task)
    }

    /// 获取 FetchTasklet 实例
    /// 严格翻译自 FetchTasklet.get()
    public static func get(globalThis: JsGlobalObject, fetchOptions: FetchOptions, promise: JSPromiseStrong): ?FetchTasklet {
        let jscVm = globalThis.bunVm()
        let tasklet = FetchTasklet()
        tasklet.javascriptVm = jscVm
        tasklet.globalThis = globalThis
        tasklet.requestBody = fetchOptions.body
        tasklet.requestHeaders = fetchOptions.headers
        tasklet.promise = promise
        tasklet.bodySize = BodySize.unknown()
        tasklet.urlProxyBuffer = fetchOptions.urlProxyBuffer
        tasklet.signal = fetchOptions.signal
        tasklet.checkServerIdentity = fetchOptions.checkServerIdentity
        tasklet.rejectUnauthorized = fetchOptions.rejectUnauthorized
        tasklet.upgradedConnection = fetchOptions.upgradedConnection
        tasklet.hostname = fetchOptions.hostname

        // 设置信号
        tasklet.signals = tasklet.signalStore.toSignals()

        // 追踪器调度
        tasklet.tracker.didSchedule(globalThis)

        // URL 和代理处理
        var url = fetchOptions.url
        var proxy: ?URL = fetchOptions.proxy

        if (proxy.isSome()) {
            let proxyUrl = proxy.getOrThrow()
            if (!proxyUrl.isEmpty()) {
                // 检查 NO_PROXY
                let env = jscVm.getOrThrow().transpiler().envMut()
                if (!env.isNoProxy(url.hostname, url.host)) {
                    // 保留显式代理
                } else {
                    proxy = None
                }
            } else {
                proxy = None
            }
        } else {
            // 使用默认代理解析
            let env = jscVm.getOrThrow().transpiler().envMut()
            let envProxy = env.getHttpProxyFor(url)
            if (envProxy.isSome()) {
                let proxyUrl = envProxy.getOrThrow()
                if (!proxyUrl.href.isEmpty()) {
                    let oldUrlLen = url.href.size
                    // 扩展 urlProxyBuffer
                    tasklet.urlProxyBuffer.appendSlice(Array<UInt8>())
                    // 更新 URL 引用
                    url = URL.parse(tasklet.urlProxyBuffer.items()[0..oldUrlLen])
                    proxy = Some(URL.parse(tasklet.urlProxyBuffer.items()[oldUrlLen..]))
                } else {
                    proxy = Some(proxyUrl)
                }
            }
        }

        // checkServerIdentity 和证书错误
        if (tasklet.checkServerIdentity.has() && tasklet.rejectUnauthorized) {
            tasklet.signalStore.certErrors = true
        } else {
            tasklet.signals.certErrors = None
        }

        // 创建 AsyncHTTP
        let httpInstance = AsyncHTTP(
            fetchOptions.method,
            url,
            tasklet.requestHeaders,
            tasklet.responseBuffer,
            tasklet.requestBody.slice(),
            FetchTasklet.callback,
            fetchOptions.redirectType,
            AsyncHTTPOptions(
                proxy,
                tasklet.hostname,
                tasklet.signals,
                fetchOptions.rejectUnauthorized,
                fetchOptions.verbose,
                fetchOptions.sslConfig
            )
        )
        tasklet.http = Some(httpInstance)

        // 流式请求体
        let isStream = tasklet.requestBody.tag == HTTPRequestBodyTag.ReadableStream
        let httpClient = httpInstance
        httpClient.client().flags().isStreamingRequestBody = isStream
        httpClient.client().flags().forceHttp2 = fetchOptions.forceHttp2
        httpClient.client().flags().forceHttp3 = fetchOptions.forceHttp3
        httpClient.client().flags().forceHttp1 = fetchOptions.forceHttp1
        tasklet.isWaitingRequestStreamStart = isStream

        if (isStream) {
            let buffer = ThreadSafeStreamBuffer()
            buffer.setDrainCallback(FetchTasklet.onWriteRequestDataDrain, tasklet)
            tasklet.requestBodyStreamingBuffer = Some(buffer)
            httpClient.requestBody = HTTPRequestBodyStream(buffer, false)
        }

        // 重定向类型
        if (fetchOptions.redirectType != FetchRedirect.Follow) {
            httpClient.client().remainingRedirectCount = 0
        }

        // 启用 header 进度
        tasklet.signalStore.headerProgress = true

        // Sendfile 请求体
        if (tasklet.requestBody.tag == HTTPRequestBodyTag.Sendfile) {
            httpClient.requestBody = HTTPRequestBodySendfile(tasklet.requestBody.sendfile)
        }

        // AbortSignal 监听
        if (tasklet.signal.isSome()) {
            let sig = tasklet.signal.getOrThrow()
            sig.pendingActivityRef()
            sig.addListener(tasklet, FetchTasklet.abortListener)
        }

        return tasklet
    }

    /// 入队 FetchTasklet
    /// 严格翻译自 FetchTasklet.queue()
    public static func queue(global: JsGlobalObject, fetchOptions: FetchOptions, promise: JSPromiseStrong): ?FetchTasklet {
        HTTPThread.initDefault()
        let node = FetchTasklet.get(global, fetchOptions, promise)
        if (node.isSome()) {
            let n = node.getOrThrow()
            let httpInst = n.http.getOrThrow()
            httpInst.schedule()
            n.pollRef.ref()
            n.ref()
            HTTPThread.schedule(httpInst)
            return n
        }
        return None
    }

    // ========================================================================
    // 清理
    // ========================================================================

    /// 清除 Sink
    /// 严格翻译自 FetchTasklet.clear_sink()
    public func clearSink(): Unit {
        if (sink.isSome()) {
            let s = sink.getOrThrow()
            s.detachJs()
            ResumableFetchSink.deref(s)
            sink = None
        }
        if (requestBodyStreamingBuffer.isSome()) {
            let buffer = requestBodyStreamingBuffer.getOrThrow()
            buffer.clearDrainCallback()
            ThreadSafeStreamBuffer.deref(buffer)
            requestBodyStreamingBuffer = None
        }
    }

    /// 清除数据
    /// 严格翻译自 FetchTasklet.clear_data()
    public func clearData(): Unit {
        if (!urlProxyBuffer.isEmpty()) {
            urlProxyBuffer.clear()
        }

        hostname = None

        if (result.certificateInfo.isSome()) {
            result.certificateInfo = None
        }

        requestHeaders = Headers()

        if (http.isSome()) {
            let h = http.getOrThrow()
            h.clearData()
        }

        metadata = None

        responseBuffer = MutableString()
        response.clear()

        if (nativeResponse.isSome()) {
            let r = nativeResponse.getOrThrow()
            Response.unref(r)
            nativeResponse = None
        }

        clearStreamCancelHandler()
        readableStreamRef.deinit()

        scheduledResponseBuffer = MutableString()
        requestBody.detach()

        abortReason.deinit()
        checkServerIdentity.deinit()
        clearAbortSignal()
        // 最后清除 sink
        clearSink()
    }

    /// 释放资源
    /// 严格翻译自 FetchTasklet.deinit()
    public static func deinit(task: FetchTasklet): Unit {
        task.clearData()
        // http 由 GC 回收
        task.http = None
    }

    // ========================================================================
    // 响应获取
    // ========================================================================

    /// 获取当前响应
    /// 严格翻译自 FetchTasklet.get_current_response()
    public func getCurrentResponse(): ?Response {
        if (nativeResponse.isSome()) {
            let r = nativeResponse.getOrThrow()
            return Some(r)
        }

        // 检查弱引用
        let responseJs = response.get()
        if (responseJs.isSome()) {
            let jsVal = responseJs.getOrThrow()
            let resp = jsVal.asResponse()
            if (resp.isSome()) {
                let r = resp.getOrThrow()
                return Some(r)
            }
        }

        return None
    }

    /// 获取当前可变响应
    /// 严格翻译自 FetchTasklet.current_response_mut()
    public func currentResponseMut(): ?Response {
        return getCurrentResponse()
    }

    // ========================================================================
    // 请求体流
    // ========================================================================

    /// 启动请求流
    /// 严格翻译自 FetchTasklet.start_request_stream()
    public func startRequestStream(): Unit {
        isWaitingRequestStreamStart = false
        if (requestBody.tag != HTTPRequestBodyTag.ReadableStream) {
            return
        }

        let streamRef = requestBody.readableStream
        if (streamRef.get(globalThis).isSome()) {
            let stream = streamRef.get(globalThis).getOrThrow()
            if (signalAborted()) {
                stream.abort(globalThis)
                return
            }

            ref() // 在 sink 完成之前保持引用
            let sinkInstance = ResumableFetchSink.initExactRefs(globalThis, stream, this, 2)
            sink = Some(sinkInstance)
        }
    }

    // ========================================================================
    // 进度更新
    // ========================================================================

    /// 进度更新回调
    /// 严格翻译自 FetchTasklet.on_progress_update()
    public func onProgressUpdate(): Unit {
        mutex.lock()
        hasScheduleCallback = false
        let isDone = !result.hasMore

        let vm = javascriptVm
        if (vm.isSome()) {
            let v = vm.getOrThrow()
            if (v.isShuttingDown()) {
                mutex.unlock()
                if (isDone) {
                    FetchTasklet.deref(this)
                }
                return
            }
        }

        // 启动请求流
        if (isWaitingRequestStreamStart && result.canStream) {
            startRequestStream()
            if (metadata.isSome() && !isWaitingBody) {
                if (vm.isSome()) {
                    let v = vm.getOrThrow()
                    v.jscVm().drainMicrotasks()
                }
            }
        }

        // 等待 body
        if (isWaitingBody) {
            // 过期任务防护
            if (scheduledResponseBuffer.isEmpty() && result.hasMore && result.isSuccess()) {
                mutex.unlock()
                return
            }
            onBodyReceived()
            mutex.unlock()
            if (isDone) {
                // 取消残留 sink
                if (sink.isSome()) {
                    let s = sink.getOrThrow()
                    s.cancel(JsValue.UNDEFINED)
                }
                pollRef.unref()
                FetchTasklet.deref(this)
            }
            return
        }

        // 没有元数据且成功
        if (metadata.isNone() && result.isSuccess()) {
            mutex.unlock()
            if (isDone) {
                FetchTasklet.deref(this)
            }
            return
        }

        // 等待中止
        if (isWaitingAbort) {
            mutex.unlock()
            if (isDone) {
                FetchTasklet.deref(this)
            }
            return
        }

        let promiseValue = promise.valueOrEmpty()

        if (promiseValue.isEmptyOrUndefinedOrNull()) {
            promise = JSPromiseStrong.empty()
            mutex.unlock()
            if (isDone) {
                FetchTasklet.deref(this)
            }
            return
        }

        // 证书信息
        if (result.certificateInfo.isSome()) {
            let certInfo = result.certificateInfo.getOrThrow()
            if (rejectUnauthorized && !checkServerIdentityFn(certInfo)) {
                // 中止请求
                let prom = promiseValue.asAnyPromise()
                if (prom.isSome()) {
                    let p = prom.getOrThrow()
                    let rejectResult = onReject()
                    p.rejectWithAsyncStack(globalThis, rejectResult.toJS(globalThis))
                    rejectResult.reset()
                }
                tracker.didDispatch(globalThis)
                promise = JSPromiseStrong.empty()
                mutex.unlock()
                if (isDone) {
                    FetchTasklet.deref(this)
                }
                return
            }
        }

        // 中止原因优先级高于成功
        if (result.isSuccess() && abortReason.has()) {
            let prom = promiseValue.asAnyPromise()
            if (prom.isSome()) {
                let p = prom.getOrThrow()
                let err = getAbortError()
                if (err.isSome()) {
                    let e = err.getOrThrow()
                    p.rejectWithAsyncStack(globalThis, e.toJS(globalThis))
                    e.reset()
                }
            }
            tracker.didDispatch(globalThis)
            promise = JSPromiseStrong.empty()
            mutex.unlock()
            if (isDone) {
                FetchTasklet.deref(this)
            }
            return
        }

        // resolve 或 reject
        tracker.willDispatch(globalThis)

        let success = result.isSuccess()
        let resolveResult: StrongOptional = if (success) {
            StrongOptional.create(onResolve(), globalThis)
        } else {
            let rejectValue = onReject()
            let errJs = rejectValue.toJS(globalThis)
            if (sink.isSome()) {
                let s = sink.getOrThrow()
                s.cancel(errJs)
            }
            StrongOptional.create(rejectValue.takeJSValue(), globalThis)
        }

        promiseValue.ensureStillAlive()

        // 通过 AnyTask 调度 Promise resolve/reject
        let holder = PromiseHolder(
            resolveResult,
            promise.take(),
            globalThis
        )

        if (success) {
            holder.resolve()
        } else {
            holder.reject()
        }

        tracker.didDispatch(globalThis)
        promise = JSPromiseStrong.empty()
        mutex.unlock()
        if (isDone) {
            if (sink.isSome()) {
                let s = sink.getOrThrow()
                s.cancel(JsValue.UNDEFINED)
            }
            pollRef.unref()
            FetchTasklet.deref(this)
        }
    }

    /// body 接收回调
    /// 严格翻译自 FetchTasklet.on_body_received()
    public func onBodyReceived(): Unit {
        let success = result.isSuccess()
        var bufferReset = true

        if (!success) {
            var err = onReject()
            var jsErr = JsValue.ZERO

            // 如果正在流式传输, 更新错误
            if (readableStreamRef.get(globalThis).isSome()) {
                let readable = readableStreamRef.get(globalThis).getOrThrow()
                if (readable.ptr().bytes().isSome()) {
                    let bytes = readable.ptr().bytes().getOrThrow()
                    jsErr = err.toJS(globalThis)
                    jsErr.ensureStillAlive()
                    bytes.onData(StreamResult.err(StreamError.fromJsValue(jsErr)))
                }
            }

            if (sink.isSome()) {
                let s = sink.getOrThrow()
                if (jsErr.isEmpty()) {
                    jsErr = err.toJS(globalThis)
                    jsErr.ensureStillAlive()
                }
                s.cancel(jsErr)
                return
            }

            // 缓冲模式下 resolve Promise
            if (currentResponseMut().isSome()) {
                let response = currentResponseMut().getOrThrow()
                let body = response.getBodyValue()
                body.toErrorInstance(err, globalThis)
            }
            return
        }

        // 可读流
        if (readableStreamRef.get(globalThis).isSome()) {
            let readable = readableStreamRef.get(globalThis).getOrThrow()
            if (readable.ptr().bytes().isSome()) {
                let bytes = readable.ptr().bytes().getOrThrow()
                bytes.sizeHint.set(getSizeHint())
                if (result.hasMore) {
                    let chunk = scheduledResponseBuffer.list.items()
                    bytes.onData(FetchTasklet.temporaryChunk(chunk, false))
                } else {
                    clearStreamCancelHandler()
                    readableStreamRef = ReadableStreamStrong()
                    bufferReset = false
                    let chunk = scheduledResponseBuffer.list.items()
                    bytes.onData(FetchTasklet.temporaryChunk(chunk, true))
                }
                return
            }
        }

        // 当前响应
        if (currentResponseMut().isSome()) {
            let response = currentResponseMut().getOrThrow()
            let sizeHint = getSizeHint()
            response.setSizeHint(sizeHint)

            // 可读流 body
            if (response.getBodyReadableStream(globalThis).isSome()) {
                let readable = response.getBodyReadableStream(globalThis).getOrThrow()
                if (readable.ptr().bytes().isSome()) {
                    let bytes = readable.ptr().bytes().getOrThrow()
                    let chunk = scheduledResponseBuffer.list.items()
                    if (result.hasMore) {
                        bytes.onData(FetchTasklet.temporaryChunk(chunk, false))
                    } else {
                        readable.value.ensureStillAlive()
                        response.detachReadableStream(globalThis)
                        bytes.onData(FetchTasklet.temporaryChunk(chunk, true))
                    }
                    return
                }
            }

            // 非流式 — 保存缓冲
            bufferReset = false
            if (!result.hasMore) {
                let scheduledBuffer = scheduledResponseBuffer.list
                let body = response.getBodyValue()
                body.setInternalBlob(InternalBlob(scheduledBuffer, false))
                scheduledResponseBuffer = MutableString()

                // 解析 body 值
                if (body.isLocked()) {
                    let headers = response.getFetchHeaders()
                    body.resolve(globalThis, headers)
                }
            }
        }
    }

    // ========================================================================
    // Resolve / Reject
    // ========================================================================

    /// Resolve 回调
    /// 严格翻译自 FetchTasklet.on_resolve()
    public func onResolve(): JsValue {
        let resp = toResponse()
        let responseJs = Response.makeMaybePooled(globalThis, resp)
        responseJs.ensureStillAlive()
        response = JsWeak.create(responseJs, globalThis, JsWeakRefType.FetchResponse, this)
        nativeResponse = Some(Response.ref(resp))
        return responseJs
    }

    /// Reject 回调
    /// 严格翻译自 FetchTasklet.on_reject()
    public func onReject(): BodyValueError {
        // 检查中止错误
        if (getAbortError().isSome()) {
            let abortErr = getAbortError().getOrThrow()
            return abortErr
        }

        // 检查中止原因
        if (result.abortReason().isSome()) {
            let reason = result.abortReason().getOrThrow()
            return BodyValueError.abortReason(reason)
        }

        let fail = result.fail
        if (fail.isSome()) {
            let f = fail.getOrThrow()
            // 请求体不可重用
            if (f == BUN_ERROR.REQUEST_BODY_NOT_REUSABLE) {
                return BodyValueError.typeError("Request body is a ReadableStream and cannot be replayed for this redirect")
            }

            // 获取路径
            let path = getPathForError()

            // 获取错误码
            let code = if (f == BUN_ERROR.CONNECTION_CLOSED) {
                "ECONNRESET"
            } else {
                f.name()
            }

            // 获取错误消息
            let message = getErrorMessage(f, path)

            // 构造系统错误
            let fetchError = SystemError(
                0,
                code,
                message,
                path,
                "",
                "",
                -1,
                ""
            )

            return BodyValueError.systemError(fetchError)
        }

        return BodyValueError.typeError("Unknown fetch error")
    }

    // ========================================================================
    // 中止信号
    // ========================================================================

    /// 获取中止错误
    /// 严格翻译自 FetchTasklet.get_abort_error()
    public func getAbortError(): ?BodyValueError {
        if (abortReason.has()) {
            let out = abortReason
            abortReason = StrongOptional.empty()
            clearAbortSignal()
            return Some(BodyValueError.jsValue(out))
        }

        if (signal.isSome()) {
            let sig = signal.getOrThrow()
            if (sig.reasonIfAborted(globalThis).isSome()) {
                let reason = sig.reasonIfAborted(globalThis).getOrThrow()
                let out = BodyValueError.fromAbortReason(reason)
                clearAbortSignal()
                return Some(out)
            }
        }

        return None
    }

    /// 清除中止信号
    /// 严格翻译自 FetchTasklet.clear_abort_signal()
    public func clearAbortSignal(): Unit {
        if (signal.isSome()) {
            let sig = signal.getOrThrow()
            sig.cleanNativeBindings(this)
            sig.pendingActivityUnref()
            sig.unref()
            signal = None
        }
    }

    /// 是否已中止
    /// 严格翻译自 FetchTasklet.signal_aborted()
    public func signalAborted(): Bool {
        if (signal.isSome()) {
            let sig = signal.getOrThrow()
            return sig.aborted()
        }
        return false
    }

    /// 中止监听器
    /// 严格翻译自 FetchTasklet.abort_listener()
    public static func abortListener(task: FetchTasklet, reason: JsValue): Unit {
        reason.ensureStillAlive()
        task.abortReason.set(task.globalThis, reason)
        task.abortTask()

        if (task.sink.isSome()) {
            let s = task.sink.getOrThrow()
            s.cancel(reason)
            return
        }

        // 直接取消 ReadableStream
        if (task.isWaitingRequestStreamStart) {
            if (task.requestBody.tag == HTTPRequestBodyTag.ReadableStream) {
                task.isWaitingRequestStreamStart = false
                if (task.requestBody.readableStream.get(task.globalThis).isSome()) {
                    let stream = task.requestBody.readableStream.get(task.globalThis).getOrThrow()
                    stream.cancelWithReason(task.globalThis, reason)
                }
            }
        }
    }

    // ========================================================================
    // 证书验证
    // ========================================================================

    /// 检查服务器身份
    /// 严格翻译自 FetchTasklet.check_server_identity()
    public func checkServerIdentityFn(certInfo: CertificateInfo): Bool {
        if (checkServerIdentity.get().isSome()) {
            let checkFn = checkServerIdentity.get().getOrThrow()
            checkFn.ensureStillAlive()
            if (!certInfo.cert.isEmpty()) {
                let cert = certInfo.cert
                // 解析 X509 证书
                let x509 = d2iX509(cert)
                if (x509.isSome()) {
                    let globalObject = globalThis
                    let jsCert = X509.toJS(x509, globalObject)
                    if (jsCert.isSome()) {
                        let jsCertVal = jsCert.getOrThrow()
                        jsCertVal.ensureStillAlive()
                        let hostname = OwnedString.cloneUtf8(certInfo.hostname)
                        let jsHostname = hostname.toJS(globalObject)
                        jsHostname.ensureStillAlive()
                        let checkResult = checkFn.call(globalObject, JsValue.UNDEFINED, [jsHostname, jsCertVal])

                        if (checkResult.isAnyError()) {
                            // 标记等待中止
                            isWaitingAbort = result.hasMore
                            abortReason.set(globalObject, checkResult)
                            signalStore.aborted = true
                            tracker.didCancel(globalThis)
                            // 中止 HTTP 请求
                            if (http.isSome()) {
                                let h = http.getOrThrow()
                                HTTPThread.scheduleShutdown(h)
                            }
                            result.fail = Some(BunError("ERR_TLS_CERT_ALTNAME_INVALID"))
                            return false
                        }
                        // 成功
                        return true
                    }
                }
            }
        }

        result.fail = Some(BunError("ERR_TLS_CERT_ALTNAME_INVALID"))
        return false
    }

    // ========================================================================
    // HTTP 回调
    // ========================================================================

    /// HTTP 回调 (从 HTTP 线程调用)
    /// 严格翻译自 FetchTasklet.callback()
    public static func callback(task: FetchTasklet, asyncHttp: AsyncHTTP, result: HTTPClientResult): Unit {
        let isDone = !result.hasMore

        task.mutex.lock()

        // 同步进度
        if (task.http.isSome()) {
            let h = task.http.getOrThrow()
            h.syncProgressFrom(asyncHttp)
        }

        // 保存之前的元数据
        let prevMetadata = task.result.metadata
        let prevCertInfo = task.result.certificateInfo
        let prevCanStream = task.result.canStream

        // 更新结果
        task.result = result.detachLifetime()
        task.result.canStream = task.result.canStream || prevCanStream

        // 保留证书信息
        if (task.result.certificateInfo.isNone()) {
            task.result.certificateInfo = prevCertInfo
        }

        // 元数据只提供一次
        if (task.result.metadata.isSome()) {
            let meta = task.result.metadata.getOrThrow()
            if (task.metadata.isNone()) {
                task.metadata = Some(meta)
            }
            task.result.metadata = None
        } else {
            if (task.metadata.isNone()) {
                task.metadata = prevMetadata
            }
        }

        task.bodySize = task.result.bodySize

        let success = task.result.isSuccess()

        // 忽略数据
        if (task.ignoreData) {
            task.responseBuffer.reset()

            if (task.scheduledResponseBuffer.list.capacity() > 0) {
                task.scheduledResponseBuffer = MutableString()
            }
            if (success && task.result.hasMore) {
                task.mutex.unlock()
                if (isDone) {
                    FetchTasklet.derefFromThread(task)
                }
                return
            }
        } else {
            if (success) {
                task.scheduledResponseBuffer.write(task.responseBuffer.list.items())
            }
            task.responseBuffer.reset()
        }

        // 检查是否已调度
        if (task.hasScheduleCallback) {
            task.mutex.unlock()
            if (isDone) {
                FetchTasklet.derefFromThread(task)
            }
            return
        }
        task.hasScheduleCallback = true

        // VM 关闭中
        if (task.javascriptVm.isSome()) {
            let vm = task.javascriptVm.getOrThrow()
            if (vm.isShuttingDown()) {
                task.mutex.unlock()
                if (isDone) {
                    FetchTasklet.derefFromThread(task)
                }
                return
            }
        }

        // 入队并发任务
        let ct = task.concurrentTask.from(task)
        if (task.javascriptVm.isSome()) {
            let vm = task.javascriptVm.getOrThrow()
            FetchTasklet.enqueueConcurrent(vm, ct)
        }

        task.mutex.unlock()
        if (isDone) {
            FetchTasklet.derefFromThread(task)
        }
    }

    /// 请求体数据排空回调 (从 HTTP 线程调用)
    /// 严格翻译自 FetchTasklet.on_write_request_data_drain()
    public static func onWriteRequestDataDrain(task: FetchTasklet): Unit {
        if (task.javascriptVm.isSome()) {
            let vm = task.javascriptVm.getOrThrow()
            if (vm.isShuttingDown()) {
                return
            }
            task.ref()
            FetchTasklet.enqueueConcurrent(vm, ConcurrentTask.fromCallback(task, FetchTasklet.resumeRequestDataStream))
        }
    }

    /// 恢复请求数据流 (从主线程调用)
    /// 严格翻译自 FetchTasklet.resume_request_data_stream()
    public static func resumeRequestDataStream(task: FetchTasklet): Unit {
        if (!task.signalAborted()) {
            if (task.sink.isSome()) {
                let s = task.sink.getOrThrow()
                s.drain()
            }
        }
        FetchTasklet.deref(task)
    }

    // ========================================================================
    // 写入请求体
    // ========================================================================

    /// 写入请求数据
    /// 严格翻译自 FetchTasklet.write_request_data()
    public func writeRequestData(data: Array<UInt8>): ResumableSinkBackpressure {
        if (signalAborted()) {
            return ResumableSinkBackpressure.Done
        }

        let highWaterMark: Int64 = if (sink.isSome()) {
            let s = sink.getOrThrow()
            s.highWaterMark()
        } else {
            Int64(16384)
        }

        if (requestBodyStreamingBuffer.isSome()) {
            let buffer = requestBodyStreamingBuffer.getOrThrow()
            var needsSchedule = buffer.isEmpty()

            if (skipChunkedFraming()) {
                buffer.write(data)
            } else {
                // chunked 编码
                let sizeHex = data.size.toString()
                let chunk = "${sizeHex}\r\n${data}\r\n"
                buffer.writeAssumeCapacity(Array<UInt8>())
            }

            let result = if (buffer.size() >= highWaterMark) {
                ResumableSinkBackpressure.Backpressure
            } else {
                ResumableSinkBackpressure.WantMore
            }

            if (needsSchedule) {
                if (http.isSome()) {
                    let h = http.getOrThrow()
                    HTTPThread.scheduleRequestWrite(h, WriteMessageType.Data)
                }
            }

            return result
        } else {
            return ResumableSinkBackpressure.Done
        }
    }

    /// 写入结束请求
    /// 严格翻译自 FetchTasklet.write_end_request()
    public func writeEndRequest(err: ?JsValue): Unit {
        if (err.isSome()) {
            let jsError = err.getOrThrow()
            if (signalStore.aborted || abortReason.has()) {
                FetchTasklet.deref(this)
                return
            }
            if (!jsError.isUndefinedOrNull()) {
                abortReason.set(globalThis, jsError)
            }
            abortTask()
        } else {
            if (!skipChunkedFraming()) {
                if (requestBodyStreamingBuffer.isSome()) {
                    let buffer = requestBodyStreamingBuffer.getOrThrow()
                    buffer.lock().write(END_OF_CHUNKED_HTTP1_1_ENCODING_RESPONSE_BODY)
                } else {
                    FetchTasklet.deref(this)
                    return
                }
            }
            if (http.isSome()) {
                let h = http.getOrThrow()
                HTTPThread.scheduleRequestWrite(h, WriteMessageType.End)
            }
        }
        FetchTasklet.deref(this)
    }

    /// 是否跳过 chunked 帧
    /// 严格翻译自 FetchTasklet.skip_chunked_framing()
    public func skipChunkedFraming(): Bool {
        if (upgradedConnection) { return true }
        if (result.isHttp2()) { return true }
        if (requestHeaders.get("content-length").isSome() && requestHeaders.get("transfer-encoding").isNone()) { return true }
        return false
    }

    /// 中止任务
    /// 严格翻译自 FetchTasklet.abort_task()
    public func abortTask(): Unit {
        signalStore.aborted = true
        tracker.didCancel(globalThis)

        if (http.isSome()) {
            let h = http.getOrThrow()
            HTTPThread.scheduleShutdown(h)
        }
    }

    // ========================================================================
    // 可读流回调
    // ========================================================================

    /// 可读流可用回调
    /// 严格翻译自 FetchTasklet.on_readable_stream_available()
    public func onReadableStreamAvailable(globalThis: JsGlobalObject, readable: ReadableStream): Unit {
        readableStreamRef = ReadableStreamStrong(readable, globalThis)
    }

    /// 开始流式 HTTP 响应体回调
    /// 严格翻译自 FetchTasklet.on_start_streaming_http_response_body_callback()
    public func onStartStreamingHTTPResponseBodyCallback(): DrainResult {
        if (signalStore.aborted) {
            return DrainResult.Aborted
        }

        if (http.isSome()) {
            let h = http.getOrThrow()
            h.enableResponseBodyStreaminging()
            HTTPThread.scheduleResponseBodyDrain(h.asyncHttpId)
        }

        mutex.lock()
        let sizeHint = getSizeHint()

        if (!scheduledResponseBuffer.list.isEmpty()) {
            let buffer = scheduledResponseBuffer
            scheduledResponseBuffer = MutableString()
            mutex.unlock()
            return DrainResult.Owned(buffer, sizeHint)
        }

        mutex.unlock()
        return DrainResult.EstimatedSize(sizeHint)
    }

    // ========================================================================
    // 流取消
    // ========================================================================

    /// 清除流取消处理器
    /// 严格翻译自 FetchTasklet.clear_stream_cancel_handler()
    public func clearStreamCancelHandler(): Unit {
        if (readableStreamRef.get(globalThis).isSome()) {
            let readable = readableStreamRef.get(globalThis).getOrThrow()
            if (readable.ptr().bytes().isSome()) {
                let bytes = readable.ptr().bytes().getOrThrow()
                let source = bytes.parentConst()
                source.cancelHandler = None
                source.cancelCtx = None
            }
        }
    }

    /// 流取消回调
    /// 严格翻译自 FetchTasklet.on_stream_cancelled_callback()
    public func onStreamCancelledCallback(): Unit {
        if (ignoreData) {
            return
        }
        ignoreRemainingResponseBody()
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 创建临时块
    /// 严格翻译自 FetchTasklet.temporary_chunk()
    public static func temporaryChunk(chunk: Array<UInt8>, done: Bool): StreamResult {
        if (done) {
            return StreamResult.temporaryAndDone(chunk)
        } else {
            return StreamResult.temporary(chunk)
        }
    }

    /// 获取大小提示
    /// 严格翻译自 FetchTasklet.get_size_hint()
    public func getSizeHint(): BlobSizeType {
        // Workaround for Cangjie FirstLetter pattern match issue
        match (bodySize) {
            case BodySize.Unknown => 0
            case BodySize.ContentLength(val) =>
                let result: Int64 = val
                return result
            case BodySize.TotalReceived(val) =>
                let result: Int64 = val
                return result
        }
    }

    /// 转换为 body 值
    /// 严格翻译自 FetchTasklet.to_body_value()
    public func toBodyValue(): BodyValue {
        if (getAbortError().isSome()) {
            let abortErr = getAbortError().getOrThrow()
            return BodyValue.error(abortErr)
        }

        if (isWaitingBody) {
            let pending = BodyPendingValue(globalThis)
            pending.sizeHint = getSizeHint()
            pending.task = this
            pending.onStartStreaming = { => onStartStreamingHTTPResponseBodyCallback() }
            pending.onReadableStreamAvailable = { g, r => onReadableStreamAvailable(g, r) }
            pending.onStreamCancelled = { => onStreamCancelledCallback() }
            return BodyValue.locked(pending)
        }

        let scheduledBuffer = scheduledResponseBuffer.list
        let response = BodyValue.internalBlob(InternalBlob(scheduledBuffer, false))
        scheduledResponseBuffer = MutableString()

        return response
    }

    /// 转换为 Response
    /// 严格翻译自 FetchTasklet.to_response()
    public func toResponse(): Response {
        let meta = metadata.getOrThrow()
        let httpResponse = meta.response
        isWaitingBody = result.hasMore

        let headers = FetchHeaders.createFromPicoHeaders(httpResponse.headers.list)
        let statusCode = httpResponse.statusCode
        // 不使用 atomized string (可能在非 JS 线程释放)
        let statusText = httpResponse.status
        let url = BunString.cloneUtf8(meta.url.slice())
        let redirected = result.redirected

        return Response(
            ResponseInit(
                HeadersRef.adopt(headers),
                statusCode,
                statusText
            ),
            Body(toBodyValue()),
            url,
            redirected
        )
    }

    /// 忽略剩余响应体
    /// 严格翻译自 FetchTasklet.ignore_remaining_response_body()
    public func ignoreRemainingResponseBody(): Unit {
        // 分离 sink JS 包装
        if (sink.isSome()) {
            let s = sink.getOrThrow()
            s.detachJs()
        }

        // 启用流式传输
        if (http.isSome()) {
            let h = http.getOrThrow()
            h.enableResponseBodyStreaminging()
        }

        pollRef.unref()
        clearStreamCancelHandler()
        readableStreamRef.deinit()
        response.clear()

        if (nativeResponse.isSome()) {
            let r = nativeResponse.getOrThrow()
            Response.unref(r)
            nativeResponse = None
        }

        ignoreData = true
    }

    /// 响应 finalize 回调
    /// 严格翻译自 FetchTasklet.on_response_finalize()
    public func onResponseFinalize(): Unit {
        if (nativeResponse.isSome()) {
            let response = nativeResponse.getOrThrow()
            let body = response.getBodyValue()
            // 场景分析:
            // 1. 正在流式传输 → 不忽略
            // 2. 缓冲中:
            //    2a. 没有 promise → 忽略
            //    2b. 有 promise → 继续加载
            // 3. 从未开始缓冲 → 忽略
            if (!body.isLocked() || readableStreamRef.has()) {
                return
            }

            if (body.isLocked()) {
                let locked = body.lockedValue
                if (locked.promise.isSome()) {
                    let promise = locked.promise.getOrThrow()
                    if (promise.isEmptyOrUndefinedOrNull()) {
                        ignoreRemainingResponseBody()
                    }
                } else {
                    ignoreRemainingResponseBody()
                }
            }
        }
    }

    /// 获取错误路径
    private func getPathForError(): String {
        if (metadata.isSome()) {
            let meta = metadata.getOrThrow()
            return meta.url.slice()
        }
        if (http.isSome()) {
            let h = http.getOrThrow()
            return h.url.href
        }
        return ""
    }

    /// 获取错误消息
    private func getErrorMessage(fail: BunError, path: String): String {
        // 网络和连接错误
        if (fail == BUN_ERROR.CONNECTION_CLOSED) {
            return "The socket connection was closed unexpectedly. For more information, pass `verbose: true` in the second argument to fetch()"
        }
        if (fail == BUN_ERROR.FAILED_TO_OPEN_SOCKET) {
            return "Was there a typo in the url or port?"
        }
        if (fail == BUN_ERROR.TOO_MANY_REDIRECTS) {
            return "The response redirected too many times. For more information, pass `verbose: true` in the second argument to fetch()"
        }
        if (fail == BUN_ERROR.CONNECTION_REFUSED) {
            return "Unable to connect. Is the computer able to access the url?"
        }
        if (fail == BUN_ERROR.REDIRECT_URL_INVALID) {
            return "Redirect URL in Location header is invalid."
        }

        // TLS/SSL 证书错误
        if (fail == BUN_ERROR.UNABLE_TO_GET_ISSUER_CERT) {
            return "unable to get issuer certificate"
        }
        if (fail == BUN_ERROR.UNABLE_TO_GET_CRL) {
            return "unable to get certificate CRL"
        }
        if (fail == BUN_ERROR.UNABLE_TO_DECRYPT_CERT_SIGNATURE) {
            return "unable to decrypt certificate's signature"
        }
        if (fail == BUN_ERROR.UNABLE_TO_DECRYPT_CRL_SIGNATURE) {
            return "unable to decrypt CRL's signature"
        }
        if (fail == BUN_ERROR.UNABLE_TO_DECODE_ISSUER_PUBLIC_KEY) {
            return "unable to decode issuer public key"
        }
        if (fail == BUN_ERROR.CERT_SIGNATURE_FAILURE) {
            return "certificate signature failure"
        }
        if (fail == BUN_ERROR.CRL_SIGNATURE_FAILURE) {
            return "CRL signature failure"
        }
        if (fail == BUN_ERROR.CERT_NOT_YET_VALID) {
            return "certificate is not yet valid"
        }
        if (fail == BUN_ERROR.CRL_NOT_YET_VALID) {
            return "CRL is not yet valid"
        }
        if (fail == BUN_ERROR.CERT_HAS_EXPIRED) {
            return "certificate has expired"
        }
        if (fail == BUN_ERROR.CRL_HAS_EXPIRED) {
            return "CRL has expired"
        }
        if (fail == BUN_ERROR.ERROR_IN_CERT_NOT_BEFORE_FIELD) {
            return "format error in certificate's notBefore field"
        }
        if (fail == BUN_ERROR.ERROR_IN_CERT_NOT_AFTER_FIELD) {
            return "format error in certificate's notAfter field"
        }
        if (fail == BUN_ERROR.ERROR_IN_CRL_LAST_UPDATE_FIELD) {
            return "format error in CRL's lastUpdate field"
        }
        if (fail == BUN_ERROR.ERROR_IN_CRL_NEXT_UPDATE_FIELD) {
            return "format error in CRL's nextUpdate field"
        }
        if (fail == BUN_ERROR.OUT_OF_MEM) {
            return "out of memory"
        }
        if (fail == BUN_ERROR.DEPTH_ZERO_SELF_SIGNED_CERT) {
            return "self signed certificate"
        }
        if (fail == BUN_ERROR.SELF_SIGNED_CERT_IN_CHAIN) {
            return "self signed certificate in certificate chain"
        }
        if (fail == BUN_ERROR.UNABLE_TO_GET_ISSUER_CERT_LOCALLY) {
            return "unable to get local issuer certificate"
        }
        if (fail == BUN_ERROR.UNABLE_TO_VERIFY_LEAF_SIGNATURE) {
            return "unable to verify the first certificate"
        }
        if (fail == BUN_ERROR.CERT_CHAIN_TOO_LONG) {
            return "certificate chain too long"
        }
        if (fail == BUN_ERROR.CERT_REVOKED) {
            return "certificate revoked"
        }
        if (fail == BUN_ERROR.INVALID_CA) {
            return "invalid CA certificate"
        }
        if (fail == BUN_ERROR.INVALID_NON_CA) {
            return "invalid non-CA certificate (has CA markings)"
        }
        if (fail == BUN_ERROR.PATH_LENGTH_EXCEEDED) {
            return "path length constraint exceeded"
        }
        if (fail == BUN_ERROR.PROXY_PATH_LENGTH_EXCEEDED) {
            return "proxy path length constraint exceeded"
        }
        if (fail == BUN_ERROR.PROXY_CERTIFICATES_NOT_ALLOWED) {
            return "proxy certificates not allowed, please set the appropriate flag"
        }
        if (fail == BUN_ERROR.INVALID_PURPOSE) {
            return "unsupported certificate purpose"
        }
        if (fail == BUN_ERROR.CERT_UNTRUSTED) {
            return "certificate not trusted"
        }
        if (fail == BUN_ERROR.CERT_REJECTED) {
            return "certificate rejected"
        }
        if (fail == BUN_ERROR.APPLICATION_VERIFICATION) {
            return "application verification failure"
        }
        if (fail == BUN_ERROR.SUBJECT_ISSUER_MISMATCH) {
            return "subject issuer mismatch"
        }
        if (fail == BUN_ERROR.AKID_SKID_MISMATCH) {
            return "authority and subject key identifier mismatch"
        }
        if (fail == BUN_ERROR.AKID_ISSUER_SERIAL_MISMATCH) {
            return "authority and issuer serial number mismatch"
        }
        if (fail == BUN_ERROR.KEYUSAGE_NO_CERTSIGN) {
            return "key usage does not include certificate signing"
        }
        if (fail == BUN_ERROR.UNABLE_TO_GET_CRL_ISSUER) {
            return "unable to get CRL issuer certificate"
        }
        if (fail == BUN_ERROR.UNHANDLED_CRITICAL_EXTENSION) {
            return "unhandled critical extension"
        }
        if (fail == BUN_ERROR.KEYUSAGE_NO_CRL_SIGN) {
            return "key usage does not include CRL signing"
        }
        if (fail == BUN_ERROR.KEYUSAGE_NO_DIGITAL_SIGNATURE) {
            return "key usage does not include digital signature"
        }
        if (fail == BUN_ERROR.UNHANDLED_CRITICAL_CRL_EXTENSION) {
            return "unhandled critical CRL extension"
        }
        if (fail == BUN_ERROR.INVALID_EXTENSION) {
            return "invalid or inconsistent certificate extension"
        }
        if (fail == BUN_ERROR.INVALID_POLICY_EXTENSION) {
            return "invalid or inconsistent certificate policy extension"
        }
        if (fail == BUN_ERROR.NO_EXPLICIT_POLICY) {
            return "no explicit policy"
        }
        if (fail == BUN_ERROR.DIFFERENT_CRL_SCOPE) {
            return "Different CRL scope"
        }
        if (fail == BUN_ERROR.UNSUPPORTED_EXTENSION_FEATURE) {
            return "Unsupported extension feature"
        }
        if (fail == BUN_ERROR.UNNESTED_RESOURCE) {
            return "RFC 3779 resource not subset of parent's resources"
        }
        if (fail == BUN_ERROR.PERMITTED_VIOLATION) {
            return "permitted subtree violation"
        }
        if (fail == BUN_ERROR.EXCLUDED_VIOLATION) {
            return "excluded subtree violation"
        }
        if (fail == BUN_ERROR.SUBTREE_MINMAX) {
            return "name constraints minimum and maximum not supported"
        }
        if (fail == BUN_ERROR.UNSUPPORTED_CONSTRAINT_TYPE) {
            return "unsupported name constraint type"
        }
        if (fail == BUN_ERROR.UNSUPPORTED_CONSTRAINT_SYNTAX) {
            return "unsupported or invalid name constraint syntax"
        }
        if (fail == BUN_ERROR.UNSUPPORTED_NAME_SYNTAX) {
            return "unsupported or invalid name syntax"
        }
        if (fail == BUN_ERROR.CRL_PATH_VALIDATION_ERROR) {
            return "CRL path validation error"
        }
        if (fail == BUN_ERROR.SUITE_B_INVALID_VERSION) {
            return "Suite B: certificate version invalid"
        }
        if (fail == BUN_ERROR.SUITE_B_INVALID_ALGORITHM) {
            return "Suite B: invalid public key algorithm"
        }
        if (fail == BUN_ERROR.SUITE_B_INVALID_CURVE) {
            return "Suite B: invalid ECC curve"
        }
        if (fail == BUN_ERROR.SUITE_B_INVALID_SIGNATURE_ALGORITHM) {
            return "Suite B: invalid signature algorithm"
        }
        if (fail == BUN_ERROR.SUITE_B_LOS_NOT_ALLOWED) {
            return "Suite B: curve not allowed for this LOS"
        }
        if (fail == BUN_ERROR.SUITE_B_CANNOT_SIGN_P_384_WITH_P_256) {
            return "Suite B: cannot sign P-384 with P-256"
        }
        if (fail == BUN_ERROR.HOSTNAME_MISMATCH) {
            return "Hostname mismatch"
        }
        if (fail == BUN_ERROR.EMAIL_MISMATCH) {
            return "Email address mismatch"
        }
        if (fail == BUN_ERROR.IP_ADDRESS_MISMATCH) {
            return "IP address mismatch"
        }
        if (fail == BUN_ERROR.INVALID_CALL) {
            return "Invalid certificate verification context"
        }
        if (fail == BUN_ERROR.STORE_LOOKUP) {
            return "Issuer certificate lookup error"
        }
        if (fail == BUN_ERROR.NAME_CONSTRAINTS_WITHOUT_SANS) {
            return "Issuer has name constraints but leaf has no SANs"
        }
        if (fail == BUN_ERROR.UNKNOWN_CERTIFICATE_VERIFICATION_ERROR) {
            return "unknown certificate verification error"
        }

        // 默认错误消息
        return "${fail.name()} fetching \"${path}\". For more information, pass `verbose: true` in the second argument to fetch()"
    }
}

// ============================================================================
// FetchOptions - Fetch 请求选项
// 严格翻译自 FetchTasklet.rs FetchOptions
// ============================================================================

/// Fetch 请求选项
/// 严格翻译自 FetchOptions
public class FetchOptions {
    /// HTTP 方法
    /// 严格翻译自 FetchOptions.method
    public var method: HttpMethod
    /// 请求头
    /// 严格翻译自 FetchOptions.headers
    public var headers: Headers
    /// 请求体
    /// 严格翻译自 FetchOptions.body
    public var body: HTTPRequestBody
    /// 是否禁用超时
    /// 严格翻译自 FetchOptions.disable_timeout
    public var disableTimeout: Bool
    /// 是否禁用 keepalive
    /// 严格翻译自 FetchOptions.disable_keepalive
    public var disableKeepalive: Bool
    /// 是否禁用解压
    /// 严格翻译自 FetchOptions.disable_decompression
    public var disableDecompression: Bool
    /// 是否拒绝未授权
    /// 严格翻译自 FetchOptions.reject_unauthorized
    public var rejectUnauthorized: Bool
    /// 请求 URL
    /// 严格翻译自 FetchOptions.url
    public var url: URL
    /// 详细级别
    /// 严格翻译自 FetchOptions.verbose
    public var verbose: HTTPVerboseLevel
    /// 重定向类型
    /// 严格翻译自 FetchOptions.redirect_type
    public var redirectType: FetchRedirect
    /// 代理 URL
    /// 严格翻译自 FetchOptions.proxy
    public var proxy: ?URL
    /// 代理头
    /// 严格翻译自 FetchOptions.proxy_headers
    public var proxyHeaders: ?Headers
    /// URL + 代理缓冲区
    /// 严格翻译自 FetchOptions.url_proxy_buffer
    public var urlProxyBuffer: ArrayList<UInt8>
    /// 中止信号
    /// 严格翻译自 FetchOptions.signal
    public var signal: ?AbortSignal
    /// 全局对象
    /// 严格翻译自 FetchOptions.global_this
    public var globalThis: ?JsGlobalObject
    /// 自定义主机名
    /// 严格翻译自 FetchOptions.hostname
    public var hostname: ?ArrayList<UInt8>
    /// checkServerIdentity
    /// 严格翻译自 FetchOptions.check_server_identity
    public var checkServerIdentity: StrongOptional
    /// Unix socket 路径
    /// 严格翻译自 FetchOptions.unix_socket_path
    public var unixSocketPath: ZigStringSlice
    /// SSL 配置
    /// 严格翻译自 FetchOptions.ssl_config
    public var sslConfig: ?SslConfigSharedPtr
    /// 是否升级连接
    /// 严格翻译自 FetchOptions.upgraded_connection
    public var upgradedConnection: Bool
    /// 强制 HTTP/2
    /// 严格翻译自 FetchOptions.force_http2
    public var forceHttp2: Bool
    /// 强制 HTTP/3
    /// 严格翻译自 FetchOptions.force_http3
    public var forceHttp3: Bool
    /// 强制 HTTP/1
    /// 严格翻译自 FetchOptions.force_http1
    public var forceHttp1: Bool

    public init() {
        method = HttpMethod.GET
        headers = Headers()
        body = HTTPRequestBody()
        disableTimeout = false
        disableKeepalive = false
        disableDecompression = false
        rejectUnauthorized = true
        url = URL()
        verbose = HTTPVerboseLevel.None
        redirectType = FetchRedirect.Follow
        proxy = None
        proxyHeaders = None
        urlProxyBuffer = ArrayList<UInt8>()
        signal = None
        globalThis = None
        hostname = None
        checkServerIdentity = StrongOptional.empty()
        unixSocketPath = ZigStringSlice.EMPTY
        sslConfig = None
        upgradedConnection = false
        forceHttp2 = false
        forceHttp3 = false
        forceHttp1 = false
    }
}

// ============================================================================
// ResumableSinkBackpressure - 可恢复 Sink 背压
// 严格翻译自 ResumableSinkBackpressure
// ============================================================================

/// 可恢复 Sink 背压
public enum ResumableSinkBackpressure {
    | Done          // 完成
    | Backpressure  // 背压 (暂停流)
    | WantMore      // 需要更多数据
}

// ============================================================================
// DrainResult - 排空结果
// 严格翻译自 DrainResult
// ============================================================================

/// 排空结果
public enum DrainResult {
    | Aborted
    | Owned(MutableString, Int64)
    | EstimatedSize(Int64)
}

// ============================================================================
// PromiseHolder - Promise 持有者 (用于 resolve/reject 调度)
// 严格翻译自 FetchTasklet.rs Holder
// ============================================================================

/// Promise 持有者
/// 严格翻译自 Holder
public class PromiseHolder {
    public var held: StrongOptional
    public var promise: JSPromiseStrong
    public var globalObject: JsGlobalObject

    public init(held: StrongOptional, promise: JSPromiseStrong, globalObject: JsGlobalObject) {
        this.held = held
        this.promise = promise
        this.globalObject = globalObject
    }

    /// Resolve
    /// 严格翻译自 Holder.resolve()
    public func resolve(): Unit {
        let prom = promise.valueOrEmpty().asAnyPromise()
        if (prom.isSome()) {
            let p = prom.getOrThrow()
            let res = held.swap()
            res.ensureStillAlive()
            p.resolve(globalObject, res)
        }
        held.deinit()
        promise = JSPromiseStrong.empty()
    }

    /// Reject
    /// 严格翻译自 Holder.reject()
    public func reject(): Unit {
        let prom = promise.valueOrEmpty().asAnyPromise()
        if (prom.isSome()) {
            let p = prom.getOrThrow()
            let res = held.swap()
            res.ensureStillAlive()
            p.rejectWithAsyncStack(globalObject, res)
        }
        held.deinit()
        promise = JSPromiseStrong.empty()
    }
}

// ============================================================================
// 相关类型 (桥接 bao_runtime.webcore 已有类型)
// ============================================================================

/// SendFile 结构
public class SendFile {
    public var fd: Int64
    public var offset: Int64
    public var remain: Int64

    public init() {
        fd = -1
        offset = 0
        remain = 0
    }

    public func close(): Unit {
        fd = -1
    }
}

/// BUN_ERROR 常量
/// 严格翻译自 bun_core Error 标签
public class BUN_ERROR {
    public static let CONNECTION_CLOSED = "ConnectionClosed"
    public static let FAILED_TO_OPEN_SOCKET = "FailedToOpenSocket"
    public static let TOO_MANY_REDIRECTS = "TooManyRedirects"
    public static let CONNECTION_REFUSED = "ConnectionRefused"
    public static let REDIRECT_URL_INVALID = "RedirectURLInvalid"
    public static let REQUEST_BODY_NOT_REUSABLE = "RequestBodyNotReusable"
    public static let UNABLE_TO_GET_ISSUER_CERT = "UNABLE_TO_GET_ISSUER_CERT"
    public static let UNABLE_TO_GET_CRL = "UNABLE_TO_GET_CRL"
    public static let UNABLE_TO_DECRYPT_CERT_SIGNATURE = "UNABLE_TO_DECRYPT_CERT_SIGNATURE"
    public static let UNABLE_TO_DECRYPT_CRL_SIGNATURE = "UNABLE_TO_DECRYPT_CRL_SIGNATURE"
    public static let UNABLE_TO_DECODE_ISSUER_PUBLIC_KEY = "UNABLE_TO_DECODE_ISSUER_PUBLIC_KEY"
    public static let CERT_SIGNATURE_FAILURE = "CERT_SIGNATURE_FAILURE"
    public static let CRL_SIGNATURE_FAILURE = "CRL_SIGNATURE_FAILURE"
    public static let CERT_NOT_YET_VALID = "CERT_NOT_YET_VALID"
    public static let CRL_NOT_YET_VALID = "CRL_NOT_YET_VALID"
    public static let CERT_HAS_EXPIRED = "CERT_HAS_EXPIRED"
    public static let CRL_HAS_EXPIRED = "CRL_HAS_EXPIRED"
    public static let ERROR_IN_CERT_NOT_BEFORE_FIELD = "ERROR_IN_CERT_NOT_BEFORE_FIELD"
    public static let ERROR_IN_CERT_NOT_AFTER_FIELD = "ERROR_IN_CERT_NOT_AFTER_FIELD"
    public static let ERROR_IN_CRL_LAST_UPDATE_FIELD = "ERROR_IN_CRL_LAST_UPDATE_FIELD"
    public static let ERROR_IN_CRL_NEXT_UPDATE_FIELD = "ERROR_IN_CRL_NEXT_UPDATE_FIELD"
    public static let OUT_OF_MEM = "OUT_OF_MEM"
    public static let DEPTH_ZERO_SELF_SIGNED_CERT = "DEPTH_ZERO_SELF_SIGNED_CERT"
    public static let SELF_SIGNED_CERT_IN_CHAIN = "SELF_SIGNED_CERT_IN_CHAIN"
    public static let UNABLE_TO_GET_ISSUER_CERT_LOCALLY = "UNABLE_TO_GET_ISSUER_CERT_LOCALLY"
    public static let UNABLE_TO_VERIFY_LEAF_SIGNATURE = "UNABLE_TO_VERIFY_LEAF_SIGNATURE"
    public static let CERT_CHAIN_TOO_LONG = "CERT_CHAIN_TOO_LONG"
    public static let CERT_REVOKED = "CERT_REVOKED"
    public static let INVALID_CA = "INVALID_CA"
    public static let INVALID_NON_CA = "INVALID_NON_CA"
    public static let PATH_LENGTH_EXCEEDED = "PATH_LENGTH_EXCEEDED"
    public static let PROXY_PATH_LENGTH_EXCEEDED = "PROXY_PATH_LENGTH_EXCEEDED"
    public static let PROXY_CERTIFICATES_NOT_ALLOWED = "PROXY_CERTIFICATES_NOT_ALLOWED"
    public static let INVALID_PURPOSE = "INVALID_PURPOSE"
    public static let CERT_UNTRUSTED = "CERT_UNTRUSTED"
    public static let CERT_REJECTED = "CERT_REJECTED"
    public static let APPLICATION_VERIFICATION = "APPLICATION_VERIFICATION"
    public static let SUBJECT_ISSUER_MISMATCH = "SUBJECT_ISSUER_MISMATCH"
    public static let AKID_SKID_MISMATCH = "AKID_SKID_MISMATCH"
    public static let AKID_ISSUER_SERIAL_MISMATCH = "AKID_ISSUER_SERIAL_MISMATCH"
    public static let KEYUSAGE_NO_CERTSIGN = "KEYUSAGE_NO_CERTSIGN"
    public static let UNABLE_TO_GET_CRL_ISSUER = "UNABLE_TO_GET_CRL_ISSUER"
    public static let UNHANDLED_CRITICAL_EXTENSION = "UNHANDLED_CRITICAL_EXTENSION"
    public static let KEYUSAGE_NO_CRL_SIGN = "KEYUSAGE_NO_CRL_SIGN"
    public static let KEYUSAGE_NO_DIGITAL_SIGNATURE = "KEYUSAGE_NO_DIGITAL_SIGNATURE"
    public static let UNHANDLED_CRITICAL_CRL_EXTENSION = "UNHANDLED_CRITICAL_CRL_EXTENSION"
    public static let INVALID_EXTENSION = "INVALID_EXTENSION"
    public static let INVALID_POLICY_EXTENSION = "INVALID_POLICY_EXTENSION"
    public static let NO_EXPLICIT_POLICY = "NO_EXPLICIT_POLICY"
    public static let DIFFERENT_CRL_SCOPE = "DIFFERENT_CRL_SCOPE"
    public static let UNSUPPORTED_EXTENSION_FEATURE = "UNSUPPORTED_EXTENSION_FEATURE"
    public static let UNNESTED_RESOURCE = "UNNESTED_RESOURCE"
    public static let PERMITTED_VIOLATION = "PERMITTED_VIOLATION"
    public static let EXCLUDED_VIOLATION = "EXCLUDED_VIOLATION"
    public static let SUBTREE_MINMAX = "SUBTREE_MINMAX"
    public static let UNSUPPORTED_CONSTRAINT_TYPE = "UNSUPPORTED_CONSTRAINT_TYPE"
    public static let UNSUPPORTED_CONSTRAINT_SYNTAX = "UNSUPPORTED_CONSTRAINT_SYNTAX"
    public static let UNSUPPORTED_NAME_SYNTAX = "UNSUPPORTED_NAME_SYNTAX"
    public static let CRL_PATH_VALIDATION_ERROR = "CRL_PATH_VALIDATION_ERROR"
    public static let SUITE_B_INVALID_VERSION = "SUITE_B_INVALID_VERSION"
    public static let SUITE_B_INVALID_ALGORITHM = "SUITE_B_INVALID_ALGORITHM"
    public static let SUITE_B_INVALID_CURVE = "SUITE_B_INVALID_CURVE"
    public static let SUITE_B_INVALID_SIGNATURE_ALGORITHM = "SUITE_B_INVALID_SIGNATURE_ALGORITHM"
    public static let SUITE_B_LOS_NOT_ALLOWED = "SUITE_B_LOS_NOT_ALLOWED"
    public static let SUITE_B_CANNOT_SIGN_P_384_WITH_P_256 = "SUITE_B_CANNOT_SIGN_P_384_WITH_P_256"
    public static let HOSTNAME_MISMATCH = "HOSTNAME_MISMATCH"
    public static let EMAIL_MISMATCH = "EMAIL_MISMATCH"
    public static let IP_ADDRESS_MISMATCH = "IP_ADDRESS_MISMATCH"
    public static let INVALID_CALL = "INVALID_CALL"
    public static let STORE_LOOKUP = "STORE_LOOKUP"
    public static let NAME_CONSTRAINTS_WITHOUT_SANS = "NAME_CONSTRAINTS_WITHOUT_SANS"
    public static let UNKNOWN_CERTIFICATE_VERIFICATION_ERROR = "UNKNOWN_CERTIFICATE_VERIFICATION_ERROR"
}
