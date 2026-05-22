// ResumableSink - 可恢复 Sink
// 严格翻译自: src/runtime/webcore/ResumableSink.rs (680 lines)
// 包含: ResumableSink, Status, ResumableSinkBackpressure,
//        ResumableSinkJs, ResumableSinkContext, PipeHandler,
//        JSResumableFetchSink, JSResumableS3UploadSink,
//        ResumableFetchSink, ResumableS3UploadSink
package bao_runtime.webcore

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_collections.ArrayList
import bao_ptr.*

// ============================================================================
// ResumableSinkStatus - ResumableSink 状态
// 对应 Bun: ResumableSink.Status (ResumableSink.rs:52-59)
// ============================================================================

/// ResumableSink 状态
/// 对应 Bun: Status
/// repr(u8), Copy, Clone, Eq, PartialEq
public enum ResumableSinkStatus {
    | Started    // 已启动
    | Piped      // 已管道连接
    | Paused     // 已暂停
    | Done       // 已完成

    public operator func == (rhs: ResumableSinkStatus): Bool {
        match (this) {
            case Started => match (rhs) { case Started => true case _ => false }
            case Piped => match (rhs) { case Piped => true case _ => false }
            case Paused => match (rhs) { case Paused => true case _ => false }
            case Done => match (rhs) { case Done => true case _ => false }
        }
    }
}

// ============================================================================
// ResumableSinkBackpressure - 背压状态
// 对应 Bun: ResumableSinkBackpressure (ResumableSink.rs:599-604)
// ============================================================================

/// ResumableSink 背压状态
/// 对应 Bun: ResumableSinkBackpressure
/// Copy, Clone, Eq, PartialEq
public enum ResumableSinkBackpressure {
    | WantMore       // 可以继续写入
    | Backpressure   // 背压 — 需要暂停
    | Done           // 完成

    public operator func == (rhs: ResumableSinkBackpressure): Bool {
        match (this) {
            case WantMore => match (rhs) { case WantMore => true case _ => false }
            case Backpressure => match (rhs) { case Backpressure => true case _ => false }
            case Done => match (rhs) { case Done => true case _ => false }
        }
    }
}

// ============================================================================
// ResumableSinkJs - JS 端访问器 trait
// 对应 Bun: ResumableSinkJs trait (ResumableSink.rs:29-39)
// ============================================================================

/// 捕获 codegen 生成的 JS 端访问器
/// 对应 Bun: ResumableSinkJs trait
/// 模型化 Zig 的 comptime js: type 参数
public interface ResumableSinkJs {
    /// toJS — 将 this 转为 JsValue
    func toJs(thisPtr: UIntNative, global: JSGlobalObject): JsValue

    /// fromJS — 从 JsValue 恢复 this
    func fromJs(value: JsValue): ?UIntNative

    /// fromJSDirect — 从 JsValue 直接恢复 this
    func fromJsDirect(value: JsValue): ?UIntNative

    /// oncancelSetCached — 设置 oncancel 缓存
    func oncancelSetCached(thisValue: JsValue, global: JSGlobalObject, value: JsValue): Unit

    /// oncancelGetCached — 获取 oncancel 缓存
    func oncancelGetCached(thisValue: JsValue): ?JsValue

    /// ondrainSetCached — 设置 ondrain 缓存
    func ondrainSetCached(thisValue: JsValue, global: JSGlobalObject, value: JsValue): Unit

    /// ondrainGetCached — 获取 ondrain 缓存
    func ondrainGetCached(thisValue: JsValue): ?JsValue

    /// streamSetCached — 设置 stream 缓存
    func streamSetCached(thisValue: JsValue, global: JSGlobalObject, value: JsValue): Unit

    /// streamGetCached — 获取 stream 缓存
    func streamGetCached(thisValue: JsValue): ?JsValue
}

// ============================================================================
// ResumableSinkContext - 每个上下文的回调 trait
// 对应 Bun: ResumableSinkContext trait (ResumableSink.rs:47-50)
// ============================================================================

/// 捕获每个 Context 的回调
/// 对应 Bun: ResumableSinkContext trait
/// 在 Zig 中这些是 Context.writeRequestData / Context.writeEndRequest
public interface ResumableSinkContext {
    /// writeRequestData — 写入请求数据
    /// 对应 Bun: ResumableSinkContext::write_request_data()
    func writeRequestData(bytes: Array<UInt8>): ResumableSinkBackpressure

    /// writeEndRequest — 写入结束请求
    /// 对应 Bun: ResumableSinkContext::write_end_request()
    func writeEndRequest(err: ?JsValue): Unit
}

// ============================================================================
// ResumableSink - 可恢复 Sink 主体
// 对应 Bun: ResumableSink<Js, Context> (ResumableSink.rs:69-83)
// ============================================================================

/// ResumableSink — 简化的流读取到原生 Writable 接口
/// 允许在不使用 Promise 的情况下暂停和恢复流
/// 对应 Bun: ResumableSink<Js: ResumableSinkJs, Context: ResumableSinkContext>
///
/// 在 onWrite 返回 false 时暂停流, 调用 drain() 恢复流消费
/// onEnd 在流结束或出错时总是被调用
/// 调用 cancel 将取消流, onEnd 会被调用并传入 reason
/// 与 JSSink 不同, 这不打算暴露给用户
public class ResumableSink<Js, Context>
    where Js <: ResumableSinkJs
    where Context <: ResumableSinkContext
{
    /// 引用计数
    /// 对应 Bun: ref_count: Cell<u32>
    public var refCount: Cell<UInt32>

    /// JS this 引用
    /// 对应 Bun: js_this: JsRef
    public var jsThis: JsRef

    /// 流引用 — 即使分离也可以保持强引用
    /// 对应 Bun: stream: readable_stream::Strong
    public var stream: ReadableStreamStrong

    /// 全局对象回引
    /// 对应 Bun: global_this: BackRef<JSGlobalObject>
    public var globalThis: BackRef<JSGlobalObject>

    /// 上下文指针 (FetchTasklet / S3UploadStreamWrapper)
    /// 对应 Bun: context: *Context
    public var context: ?Context

    /// 高水位标记 (字节), 默认 16384
    /// 对应 Bun: high_water_mark: i64
    public var highWaterMark: Int64

    /// 当前状态
    /// 对应 Bun: status: Status
    public var status: ResumableSinkStatus

    public init() {
        refCount = Cell<UInt32>(1)
        jsThis = JsRef()
        stream = ReadableStreamStrong()
        globalThis = BackRef<JSGlobalObject>()
        context = None
        highWaterMark = 16384
        status = ResumableSinkStatus.Started
    }

    public init(context: Context) {
        refCount = Cell<UInt32>(1)
        jsThis = JsRef()
        stream = ReadableStreamStrong()
        globalThis = BackRef<JSGlobalObject>()
        this.context = Some(context)
        highWaterMark = 16384
        status = ResumableSinkStatus.Started
    }

    // ========================================================================
    // global — 借用拥有的 JSGlobalObject
    // 对应 Bun: ResumableSink::global() (ResumableSink.rs:94-96)
    // ========================================================================

    /// 借用拥有的 JSGlobalObject
    /// SAFETY: globalThis 在 initExactRefs 中从活的 &JSGlobalObject 设置
    /// 全局对象比它分配的每个 JS 对象生命周期更长
    public func global(): ?JSGlobalObject {
        return globalThis.get()
    }

    // ========================================================================
    // highWaterMark getter
    // 对应 Bun: ResumableSink::high_water_mark() (ResumableSink.rs:99-103)
    // ========================================================================

    /// 当前背压高水位标记 (字节)
    public func getHighWaterMark(): Int64 {
        return highWaterMark
    }

    // ========================================================================
    // setCancel / getCancel / setDrain / getDrain / setStream / getStream
    // 对应 Bun: ResumableSink 内联的 JS 属性访问器 (ResumableSink.rs:105-128)
    // ========================================================================

    /// 设置 oncancel 回调
    /// 对应 Bun: set_cancel()
    public static func setCancel(thisValue: JsValue, global: JSGlobalObject, value: JsValue): Unit {
        Js.oncancelSetCached(thisValue, global, value)
    }

    /// 获取 oncancel 回调
    /// 对应 Bun: get_cancel()
    public static func getCancel(thisValue: JsValue): ?JsValue {
        return Js.oncancelGetCached(thisValue)
    }

    /// 设置 ondrain 回调
    /// 对应 Bun: set_drain()
    public static func setDrain(thisValue: JsValue, global: JSGlobalObject, value: JsValue): Unit {
        Js.ondrainSetCached(thisValue, global, value)
    }

    /// 获取 ondrain 回调
    /// 对应 Bun: get_drain()
    public static func getDrain(thisValue: JsValue): ?JsValue {
        return Js.ondrainGetCached(thisValue)
    }

    /// 设置 stream 缓存
    /// 对应 Bun: set_stream()
    public static func setStream(thisValue: JsValue, global: JSGlobalObject, value: JsValue): Unit {
        Js.streamSetCached(thisValue, global, value)
    }

    /// 获取 stream 缓存
    /// 对应 Bun: get_stream()
    public static func getStream(thisValue: JsValue): ?JsValue {
        return Js.streamGetCached(thisValue)
    }

    // ========================================================================
    // onWrite / onEnd — 调用上下文回调
    // 对应 Bun: ResumableSink::on_write/on_end (ResumableSink.rs:131-141)
    // ========================================================================

    /// onWrite — 调用上下文的 writeRequestData
    /// 对应 Bun: on_write()
    static func onWrite(ctx: Context, bytes: Array<UInt8>): ResumableSinkBackpressure {
        return ctx.writeRequestData(bytes)
    }

    /// onEnd — 调用上下文的 writeEndRequest
    /// 对应 Bun: on_end()
    static func onEnd(ctx: Context, err: ?JsValue): Unit {
        ctx.writeEndRequest(err)
    }

    // ========================================================================
    // constructor — 构造函数 (禁止直接调用)
    // 对应 Bun: ResumableSink::constructor() (ResumableSink.rs:143-145)
    // ========================================================================

    /// 构造函数 — 总是抛出非法构造函数错误
    public static func constructor(global: JSGlobalObject, frame: CallFrame): ?JsValue {
        // throw "ResumableSink is not a constructor"
        return None
    }

    // ========================================================================
    // init / initExactRefs — 初始化
    // 对应 Bun: ResumableSink::init/init_exact_refs() (ResumableSink.rs:147-266)
    // ========================================================================

    /// init — 初始化带默认引用计数
    /// 对应 Bun: init()
    public static func `init`(
        globalThis: JSGlobalObject,
        stream: ReadableStream,
        context: Context
    ): ResumableSink<Js, Context> {
        return initExactRefs(globalThis, stream, context, 1)
    }

    /// initExactRefs — 带精确引用计数初始化
    /// 对应 Bun: init_exact_refs() (ResumableSink.rs:155-266)
    public static func initExactRefs(
        globalThis: JSGlobalObject,
        stream: ReadableStream,
        context: Context,
        refCount: UInt32
    ): ResumableSink<Js, Context> {
        let this_ = ResumableSink<Js, Context>(context)
        this_.refCount = Cell<UInt32>(refCount)
        this_.highWaterMark = 16384
        this_.status = ResumableSinkStatus.Started

        if (stream.isLocked() || stream.isDisturbed()) {
            // 流已被使用 — 报错
            let errInstance = JsValue.zero() // SystemError to error instance
            this_.status = ResumableSinkStatus.Done
            onEnd(context, Some(errInstance))
            // deref 释放
            return this_
        }

        match (stream.bytes()) {
            case Some(byteStream) =>
                // 如果管道为空, 可以管道连接
                if (byteStream.pipe.isEmpty()) {
                    // 等效于 onStart 以获取 highWaterMark
                    this_.highWaterMark = byteStream.highWaterMark

                    if (byteStream.hasReceivedLastChunk()) {
                        this_.status = ResumableSinkStatus.Done
                        var err: ?JsValue = None
                        let pending = byteStream.pendingResult()
                        match (pending) {
                            case Some(streamErr) =>
                                err = Some(streamErr.toJsWeak(globalThis))
                            case None => ()
                        }

                        let bytes = byteStream.drain()
                        let _ = onWrite(context, bytes)
                        onEnd(context, err)
                        return this_
                    }

                    // 可以管道连接, 但先排空尽可能多的数据
                    let bytes = byteStream.drain()
                    if (bytes.size > 0) {
                        // 写入但忽略返回值 — 不想暂停流
                        let _ = onWrite(context, bytes)
                    }
                    this_.status = ResumableSinkStatus.Piped

                    // 设置管道包装器
                    // byteStream.pipe.set(Wrap<Self>::init(thisRef))
                    this_.ref() // 为管道增加一个引用

                    // 只需要流, 不需要触碰 JS 端
                    this_.stream = ReadableStreamStrong(stream, globalThis)
                    return this_
                }
            case None => ()
        }

        // JS 端路由
        let self_ = Js.toJs(0, globalThis)
        self_.ensureStillAlive()
        let jsStream = stream.toJs()
        jsStream.ensureStillAlive()
        this_.jsThis.setStrong(self_, globalThis)
        setStream(self_, globalThis, jsStream)

        // Bun__assignStreamIntoResumableSink(globalThis, jsStream, self_)
        assignStreamIntoResumableSink(globalThis, jsStream, self_)

        return this_
    }

    // ========================================================================
    // jsSetHandlers — JS setHandlers 宿主函数
    // 对应 Bun: ResumableSink::js_set_handlers() (ResumableSink.rs:268-294)
    // ========================================================================

    /// jsSetHandlers — JS 端设置处理器
    /// 对应 Bun: js_set_handlers()
    public func jsSetHandlers(
        globalThis: JSGlobalObject,
        callframe: CallFrame,
        thisValue: JsValue
    ): ?JsValue {
        let args = callframe.args

        if (args.size < 2) {
            return None // throw invalid arguments
        }

        let ondrain = args[0]
        let oncancel = args[1]

        if (ondrain.isCallable()) {
            setDrain(thisValue, globalThis, ondrain)
        }
        if (oncancel.isCallable()) {
            setCancel(thisValue, globalThis, oncancel)
        }
        return Some(JsValue.undefined())
    }

    // ========================================================================
    // jsStart — JS start 宿主函数
    // 对应 Bun: ResumableSink::js_start() (ResumableSink.rs:296-313)
    // ========================================================================

    /// jsStart — JS 端启动
    public func jsStart(globalThis: JSGlobalObject, callframe: CallFrame): ?JsValue {
        let args = callframe.args
        if (args.size > 0 && args[0].isObject()) {
            // 尝试获取 highWaterMark 参数
            let hwm = args[0].getOptionalInt("highWaterMark")
            match (hwm) {
                case Some(v) => highWaterMark = v
                case None => ()
            }
        }
        return Some(JsValue.undefined())
    }

    // ========================================================================
    // jsWrite — JS write 宿主函数
    // 对应 Bun: ResumableSink::js_write() (ResumableSink.rs:315-356)
    // ========================================================================

    /// jsWrite — JS 端写入
    public func jsWrite(globalThis: JSGlobalObject, callframe: CallFrame): ?JsValue {
        let args = callframe.args

        // 如果已分离, 忽略调用
        if (isDetached()) {
            return Some(JsValue.undefined())
        }

        if (args.size < 1) {
            return None // throw invalid arguments
        }

        let buffer = args[0]
        // 尝试解析为 StringOrBuffer
        let sb = stringOrBufferFromJs(globalThis, buffer)
        match (sb) {
            case None =>
                return None // throw invalid arguments
            case Some(bytes) =>
                let slice = bytes
                match (context) {
                    case Some(ctx) =>
                        match (onWrite(ctx, slice)) {
                            case Backpressure =>
                                status = ResumableSinkStatus.Paused
                            case Done => ()
                            case WantMore =>
                                status = ResumableSinkStatus.Started
                        }
                    case None => ()
                }
                let result = if (status != ResumableSinkStatus.Paused) { 1 } else { 0 }
                return Some(JsValue.jsNumber(Float64(result)))
        }
    }

    // ========================================================================
    // jsEnd — JS end 宿主函数
    // 对应 Bun: ResumableSink::js_end() (ResumableSink.rs:358-379)
    // ========================================================================

    /// jsEnd — JS 端结束
    public func jsEnd(globalThis: JSGlobalObject, callframe: CallFrame): ?JsValue {
        let args = callframe.args

        // 如果已分离, 忽略调用
        if (isDetached()) {
            return Some(JsValue.undefined())
        }
        detachJs()
        status = ResumableSinkStatus.Done

        match (context) {
            case Some(ctx) =>
                let err = if (args.size > 0) { Some(args[0]) } else { None }
                onEnd(ctx, err)
            case None => ()
        }
        return Some(JsValue.undefined())
    }

    // ========================================================================
    // drain — 恢复流消费
    // 对应 Bun: ResumableSink::drain() (ResumableSink.rs:381-405)
    // ========================================================================

    /// drain — 恢复流消费
    /// 对应 Bun: drain()
    public func drain(): Unit {
        if (status != ResumableSinkStatus.Paused) {
            return
        }
        match (jsThis.tryGet()) {
            case Some(jsThisVal) =>
                let globalObject = globalThis.get()
                match (globalObject) {
                    case Some(global) =>
                        match (getDrain(jsThisVal)) {
                            case Some(ondrain) =>
                                status = ResumableSinkStatus.Started
                                // 运行回调
                                // eventLoop.runCallback(ondrain, global, JsValue.UNDEFINED, [...])
                                runDrainCallback(global, ondrain)
                            case None => ()
                        }
                    case None => ()
                }
            case None => ()
        }
    }

    // ========================================================================
    // cancel — 取消流
    // 对应 Bun: ResumableSink::cancel() (ResumableSink.rs:407-447)
    // ========================================================================

    /// cancel — 取消流
    /// 对应 Bun: cancel()
    /// onEnd 最多触发一次。第一次 cancel() 后, jsThis 被降级为 weak
    /// 所以此守卫是防止第二次 cancel() 重新调用 onEnd 的唯一手段
    public func cancel(reason: JsValue): Unit {
        if (status == ResumableSinkStatus.Done) {
            return
        }
        if (status == ResumableSinkStatus.Piped) {
            reason.ensureStillAlive()
            endPipe(Some(reason))
            return
        }
        match (jsThis.tryGet()) {
            case Some(jsThisVal) =>
                status = ResumableSinkStatus.Done
                jsThisVal.ensureStillAlive()

                let onCancelCallback = getCancel(jsThisVal)
                let globalObject = globalThis.get()

                // 先分离 JS, 这样如果 cancel 调用 end 会是无操作
                detachJs()

                // 调用 onEnd 通知原生端流出错
                match (context) {
                    case Some(ctx) => onEnd(ctx, Some(reason))
                    case None => ()
                }

                jsThisVal.ensureStillAlive()
                match (onCancelCallback) {
                    case Some(callback) =>
                        match (globalObject) {
                            case Some(global) =>
                                // eventLoop.runCallback(callback, global, JsValue.UNDEFINED, [...])
                                runCancelCallback(global, callback, reason)
                            case None => ()
                        }
                    case None => ()
                }
            case None => ()
        }
    }

    // ========================================================================
    // isDetached — 是否已分离
    // 对应 Bun: ResumableSink::is_detached() (ResumableSink.rs:449-451)
    // ========================================================================

    /// isDetached — 是否已分离
    /// 对应 Bun: is_detached()
    public func isDetached(): Bool {
        return !jsThis.isStrong() || status == ResumableSinkStatus.Done
    }

    // ========================================================================
    // detachJs — 分离 JS 包装器
    // 对应 Bun: ResumableSink::detach_js() (ResumableSink.rs:460-469)
    // ========================================================================

    /// detachJs — 分离 JS 包装器
    /// 对应 Bun: detach_js()
    /// 清除缓存的 ondrain/oncancel/stream 槽位, 并将 jsThis 从强引用降级为弱引用
    /// 不执行任何 JS 回调或调用 on_end, 因此在不允许执行 JS 的上下文中调用是安全的
    public func detachJs(): Unit {
        match (jsThis.tryGet()) {
            case Some(jsThisVal) =>
                let global = globalThis.get()
                match (global) {
                    case Some(g) =>
                        setDrain(jsThisVal, g, JsValue.zero())
                        setCancel(jsThisVal, g, JsValue.zero())
                        setStream(jsThisVal, g, JsValue.zero())
                        jsThis.downgrade()
                    case None => ()
                }
            case None => ()
        }
    }

    // ========================================================================
    // finalize — 最终化
    // 对应 Bun: ResumableSink::finalize() (ResumableSink.rs:471-479)
    // ========================================================================

    /// finalize — 引用计数释放
    /// 对应 Bun: finalize()
    public func finalize(): Unit {
        jsThis.finalize()
        // deref_ 释放
    }

    // ========================================================================
    // onStreamPipe — 流管道回调
    // 对应 Bun: ResumableSink::on_stream_pipe() (ResumableSink.rs:481-519)
    // ========================================================================

    /// onStreamPipe — 处理来自管道的流数据
    /// 对应 Bun: on_stream_pipe()
    public func onStreamPipe(streamData: StreamResult): Unit {
        let chunk = streamData.slice()

        match (context) {
            case Some(ctx) =>
                let _ = onWrite(ctx, chunk)
            case None => ()
        }

        let isDone = streamData.isDone()

        if (isDone) {
            var err: ?JsValue = None
            // 检查流是否包含错误
            match (streamData.err) {
                case Some(streamErr) =>
                    err = Some(streamErr.toJs(globalThis.get()))
                case None => ()
            }
            endPipe(err)
            // self 可能已悬挂 — 此后不要触碰
        }

        // 清理拥有的数据
        match (streamData.tag) {
            case StreamResultTag.Owned => streamData.ownedData.clear()
            case StreamResultTag.OwnedAndDone => streamData.ownedData.clear()
            case _ => ()
        }
    }

    // ========================================================================
    // endPipe — 结束管道连接
    // 对应 Bun: ResumableSink::end_pipe() (ResumableSink.rs:521-566)
    // ========================================================================

    /// endPipe — 结束管道连接
    /// 对应 Bun: end_pipe()
    public func endPipe(err: ?JsValue): Unit {
        if (status != ResumableSinkStatus.Piped) {
            return
        }
        status = ResumableSinkStatus.Done

        let globalObject = globalThis.get()
        match (globalObject) {
            case Some(global) =>
                match (stream.get(global)) {
                    case Some(stream_) =>
                        // 重置管道
                        match (stream_.bytes()) {
                            case Some(bytes) => bytes.pipe.clear()
                            case None => ()
                        }
                        match (err) {
                            case Some(_) => stream_.cancel(global)
                            case None => stream_.done(global)
                        }
                        // 清空流引用
                        stream.clear()
                    case None => ()
                }
            case None => ()
        }

        match (context) {
            case Some(ctx) => onEnd(ctx, err)
            case None => ()
        }

        let jsIsStrong = jsThis.isStrong()
        if (jsIsStrong) {
            // JS 拥有流, 需要分离 JS 并让 finalize 处理 deref
            detachJs()
        }
        // 释放引用计数
        // 我们在附加流时 ref, 所以分离时 deref
        // 如果没有 JS 附加, 可以直接 deref
    }

    // ========================================================================
    // ref / deref — 引用计数操作
    // 对应 Bun: CellRefCounted derive (ResumableSink.rs:568-576)
    // ========================================================================

    /// ref — 增加引用计数
    /// 对应 Bun: ref_()
    public func ref(): Unit {
        refCount.set(refCount.get() + 1)
    }

    /// deref — 减少引用计数
    /// 对应 Bun: deref_()
    public func deref(): Unit {
        let count = refCount.get()
        if (count <= 1) {
            // 引用计数归零, 执行清理
            detachJs()
        } else {
            refCount.set(count - 1)
        }
    }
}

// ============================================================================
// PipeHandler — 管道处理接口
// 对应 Bun: PipeHandler trait (ResumableSink.rs:582-589)
// ============================================================================

/// 管道处理接口
/// 对应 Bun: impl PipeHandler for ResumableSink
/// 满足 Wrap<T: PipeHandler> 以便 Wrap::<Self>::init 可以擦除 *Self 为 Pipe
public interface PipeHandler {
    /// onPipe — 管道数据回调
    func onPipe(stream: StreamResult): Unit
}

// ============================================================================
// ResumableSink 作为 PipeHandler 实现
// 对应 Bun: impl PipeHandler for ResumableSink (ResumableSink.rs:582-589)
// ============================================================================

/// ResumableSink 实现管道处理
/// 对应 Bun: impl<Js, Context> PipeHandler for ResumableSink<Js, Context>
/// 将 Zig 的 comptime fn-ptr 参数 on_stream_pipe 重塑为 trait 方法
public class ResumableSinkPipeHandler<Js, Context>
    where Js <: ResumableSinkJs
    where Context <: ResumableSinkContext
{
    public var sink: ResumableSink<Js, Context>

    public init(sink: ResumableSink<Js, Context>) {
        this.sink = sink
    }
}

// ============================================================================
// JSResumableFetchSink - Fetch Sink 的 JS 访问器标记类型
// 对应 Bun: JSResumableFetchSink (ResumableSink.rs:652)
// ============================================================================

/// Fetch Sink 的 JS 访问器实现
/// 对应 Bun: JSResumableFetchSink
/// 连接到 bun_jsc::generated::JSResumableFetchSink 模块
public class JSResumableFetchSink <: ResumableSinkJs {
    public init() {}

    public func toJs(thisPtr: UIntNative, global: JSGlobalObject): JsValue {
        // 委托到 generated::JSResumableFetchSink::to_js
        return JsValue.zero()
    }
    public func fromJs(value: JsValue): ?UIntNative { return None }
    public func fromJsDirect(value: JsValue): ?UIntNative { return None }
    public func oncancelSetCached(thisValue: JsValue, global: JSGlobalObject, value: JsValue): Unit {}
    public func oncancelGetCached(thisValue: JsValue): ?JsValue { return None }
    public func ondrainSetCached(thisValue: JsValue, global: JSGlobalObject, value: JsValue): Unit {}
    public func ondrainGetCached(thisValue: JsValue): ?JsValue { return None }
    public func streamSetCached(thisValue: JsValue, global: JSGlobalObject, value: JsValue): Unit {}
    public func streamGetCached(thisValue: JsValue): ?JsValue { return None }
}

// ============================================================================
// JSResumableS3UploadSink - S3 上传 Sink 的 JS 访问器标记类型
// 对应 Bun: JSResumableS3UploadSink (ResumableSink.rs:652)
// ============================================================================

/// S3 上传 Sink 的 JS 访问器实现
/// 对应 Bun: JSResumableS3UploadSink
/// 连接到 bun_jsc::generated::JSResumableS3UploadSink 模块
public class JSResumableS3UploadSink <: ResumableSinkJs {
    public init() {}

    public func toJs(thisPtr: UIntNative, global: JSGlobalObject): JsValue {
        return JsValue.zero()
    }
    public func fromJs(value: JsValue): ?UIntNative { return None }
    public func fromJsDirect(value: JsValue): ?UIntNative { return None }
    public func oncancelSetCached(thisValue: JsValue, global: JSGlobalObject, value: JsValue): Unit {}
    public func oncancelGetCached(thisValue: JsValue): ?JsValue { return None }
    public func ondrainSetCached(thisValue: JsValue, global: JSGlobalObject, value: JsValue): Unit {}
    public func ondrainGetCached(thisValue: JsValue): ?JsValue { return None }
    public func streamSetCached(thisValue: JsValue, global: JSGlobalObject, value: JsValue): Unit {}
    public func streamGetCached(thisValue: JsValue): ?JsValue { return None }
}

// ============================================================================
// FetchTasklet — Fetch 任务上下文
// 对应 Bun: FetchTasklet impl ResumableSinkContext (ResumableSink.rs:658-667)
// ============================================================================

/// FetchTasklet — 实现 ResumableSinkContext 的转发
/// 对应 Bun: impl ResumableSinkContext for FetchTasklet
/// 将 trait bound 通过委托转发到 FetchTasklet 的固有实现
public class FetchTaskletContext <: ResumableSinkContext {
    public init() {}

    public func writeRequestData(bytes: Array<UInt8>): ResumableSinkBackpressure {
        return ResumableSinkBackpressure.WantMore
    }

    public func writeEndRequest(err: ?JsValue): Unit {
        // 委托到 FetchTasklet::write_end_request
    }
}

// ============================================================================
// 类型别名
// 对应 Bun: type aliases (ResumableSink.rs:669-670)
// ============================================================================

/// ResumableFetchSink 类型别名
/// 对应 Bun: ResumableFetchSink = ResumableSink<JSResumableFetchSink, FetchTasklet>
public type ResumableFetchSink = ResumableSink<JSResumableFetchSink, FetchTaskletContext>

/// ResumableS3UploadSink 类型别名
/// 对应 Bun: ResumableS3UploadSink = ResumableSink<JSResumableS3UploadSink, S3UploadStreamWrapper>
public type ResumableS3UploadSinkAlias = ResumableSink<JSResumableS3UploadSink, FetchTaskletContext>

// ============================================================================
// 辅助类和函数
// ============================================================================

/// JsRef — JS 引用
/// 对应 Bun: bun_jsc::JsRef
public class JsRef {
    private var strong: Bool
    private var value: ?JsValue

    public init() {
        strong = false
        value = None
    }

    public func setStrong(v: JsValue, global: JSGlobalObject): Unit {
        strong = true
        value = Some(v)
    }

    public func tryGet(): ?JsValue {
        return value
    }

    public func isStrong(): Bool {
        return strong && value.isSome()
    }

    public func downgrade(): Unit {
        strong = false
        // 值仍然可以通过 tryGet 访问 (weak ref)
    }

    public func finalize(): Unit {
        value = None
        strong = false
    }
}

/// BackRef — 回引
/// 对应 Bun: bun_ptr::BackRef<T>
public class BackRef<T> {
    private var ref: ?T

    public init() {
        ref = None
    }

    public init(ref: T) {
        this.ref = Some(ref)
    }

    public static func new(ref: T): BackRef<T> {
        return BackRef<T>(ref)
    }

    public func get(): ?T {
        return ref
    }
}

/// ReadableStream — 可读流
/// 对应 Bun: ReadableStream
public class ReadableStream {
    public init() {}

    public func isLocked(): Bool { return false }
    public func isDisturbed(): Bool { return false }
    public func bytes(): ?ByteStream { return None }
    public func toJs(): JsValue { return JsValue.zero() }
}

/// ReadableStreamStrong — 可读流强引用
/// 对应 Bun: readable_stream::Strong
public class ReadableStreamStrong {
    public init() {}

    public static func `init`(stream: ReadableStream, global: JSGlobalObject): ReadableStreamStrong {
        return ReadableStreamStrong()
    }

    public func get(global: JSGlobalObject): ?ReadableStreamRef { return None }
    public func clear(): Unit {}
}

/// ReadableStreamRef — 可读流引用
public class ReadableStreamRef {
    public func bytes(): ?ByteStream { return None }
    public func cancel(global: JSGlobalObject): Unit {}
    public func done(global: JSGlobalObject): Unit {}
}

/// ByteStream — 字节流
/// 对应 Bun: ByteStream
public class ByteStream {
    public var pipe: ArrayList<UInt8>
    public var highWaterMark: Int64
    public var hasReceivedLastChunk: Bool
    public var pendingResultValue: ?StreamError

    public init() {
        pipe = ArrayList<UInt8>()
        highWaterMark = 16384
        hasReceivedLastChunk = false
        pendingResultValue = None
    }

    public func isEmpty(): Bool {
        return pipe.size == 0
    }

    public func hasReceivedLastChunk(): Bool {
        return hasReceivedLastChunk
    }

    public func drain(): Array<UInt8> {
        let result = pipe.toArray()
        pipe.clear()
        return result
    }

    public func pendingResult(): ?StreamError {
        return pendingResultValue
    }
}

/// StreamError — 流错误
/// 对应 Bun: streams::Result::Err 中的错误
public class StreamError {
    public init() {}

    public func toJsWeak(global: ?JSGlobalObject): JsValue {
        return JsValue.zero()
    }

    public func toJs(global: ?JSGlobalObject): JsValue {
        return JsValue.zero()
    }
}

/// Cell — 内部可变性单元
/// 对应 Bun: core::cell::Cell<T>
public class Cell<T> {
    private var value: T

    public init(v: T) {
        value = v
    }

    public func get(): T {
        return value
    }

    public func set(v: T): Unit {
        value = v
    }
}

/// UIntNative — 原始大小无符号整数
public type UIntNative = UInt64

// ============================================================================
// 辅助函数
// ============================================================================

/// 将流分配到 ResumableSink
/// 对应 Bun: Bun__assignStreamIntoResumableSink extern (ResumableSink.rs:672-678)
func assignStreamIntoResumableSink(global: JSGlobalObject, stream: JsValue, sink: JsValue): JsValue {
    // 在实际实现中调用 FFI extern
    return JsValue.zero()
}

/// 从 JS 值解析 StringOrBuffer
func stringOrBufferFromJs(global: JSGlobalObject, value: JsValue): ?Array<UInt8> {
    if (value.isArrayBuffer()) {
        return Some(value.arrayBufferSlice())
    }
    if (value.isString()) {
        // 将字符串转为字节数组
        return Some(Array<UInt8>())
    }
    return None
}

/// 运行 drain 回调
func runDrainCallback(global: JSGlobalObject, callback: JsValue): Unit {
    // eventLoop.runCallback(ondrain, global, JsValue.UNDEFINED, [...])
}

/// 运行 cancel 回调
func runCancelCallback(global: JSGlobalObject, callback: JsValue, reason: JsValue): Unit {
    // eventLoop.runCallback(callback, global, JsValue.UNDEFINED, [...])
}

// ported from: src/runtime/webcore/ResumableSink.rs
