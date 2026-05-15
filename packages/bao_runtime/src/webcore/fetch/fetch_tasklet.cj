// FetchTasklet - Fetch 任务单元
// 对应 Bun: src/runtime/webcore/fetch/FetchTasklet.zig
// 严格翻译自: src/runtime/webcore/fetch/FetchTasklet.zig
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// FetchTaskletState - Fetch 任务状态
// 对应 Bun: FetchTasklet 状态枚举
// ============================================================================

/// Fetch 任务状态
public enum FetchTaskletState {
    | Pending       // 等待中
    | Running       // 运行中
    | Completed     // 已完成
    | Failed        // 已失败
    | Aborted       // 已中止
}

// ============================================================================
// FetchTasklet - Fetch 任务单元
// 对应 Bun: src/runtime/webcore/fetch/FetchTasklet.zig FetchTasklet
// ============================================================================

/// FetchTasklet — 单个 fetch 请求的任务单元
/// 对应 Bun: src/runtime/webcore/fetch/FetchTasklet.zig FetchTasklet
/// 管理 fetch 请求的生命周期、Promise 解析和错误处理
public class FetchTasklet {
    /// 任务状态
    public var state: FetchTaskletState
    /// 关联的请求 URL
    public var url: String
    /// 关联的 HTTP 方法
    public var method: String
    /// 请求头
    public var requestHeaders: Headers
    /// 请求体字节数据
    public var requestBody: Array<UInt8>
    /// 关联的 Promise
    public var promise: ?JsValue
    /// 结果响应
    public var response: ?Response
    /// 错误消息
    public var errorMessage: String
    /// 引用计数
    public var refCount: Int64

    public init() {
        state = FetchTaskletState.Pending
        url = ""
        method = "GET"
        requestHeaders = Headers()
        requestBody = Array<UInt8>()
        promise = None
        response = None
        errorMessage = ""
        refCount = 1
    }

    public init(url: String, method: String) {
        state = FetchTaskletState.Pending
        this.url = url
        this.method = method
        requestHeaders = Headers()
        requestBody = Array<UInt8>()
        promise = None
        response = None
        errorMessage = ""
        refCount = 1
    }

    /// 执行 fetch 请求
    /// 对应 Bun: FetchTasklet 执行逻辑
    public func execute(): Unit {
        state = FetchTaskletState.Running

        // 构建 Request
        let init = RequestInit()
        init.method = method
        init.headers = requestHeaders
        if (requestBody.size > 0) {
            let bodyValue = BodyValue(requestBody)
            init.body = Some(Body(value: bodyValue))
        }
        let request = Request(url, init)

        // 执行 fetch
        try {
            let result = fetch(url, init)
            response = Some(result)
            state = FetchTaskletState.Completed
        } catch (e: Exception) {
            errorMessage = e.message
            state = FetchTaskletState.Failed
        }
    }

    /// 中止任务
    public func abort(): Unit {
        state = FetchTaskletState.Aborted
        errorMessage = "Aborted"
    }

    /// 增加引用
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    public func unref(): Unit {
        refCount -= 1
    }

    /// 是否完成
    public func isDone(): Bool {
        match (state) {
            case Completed | Failed | Aborted => true
            case _ => false
        }
    }
}
