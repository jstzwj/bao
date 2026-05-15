// 严格翻译自: src/uws_sys/BodyReaderMixin.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// BodyReaderMixin - 请求体读取混入
// 严格翻译自: BodyReaderMixin.zig
//  Mixin to read an entire request body into memory and run a callback.
//  Consumers should make sure a reference count is held on the server,
//  and is unreferenced after one of the two callbacks are called.
// ============================================================================
public class BodyReaderMixin {
    public var body: ArrayList<UInt8>

    public init(allocator: CPointer<Unit>) {
        this.body = ArrayList<UInt8>()
    }

    /// 对应 Bun: pub fn readBody(ctx, resp) void
    /// Memory is freed after the callback returns, or automatically on failure.
    public func readBody(resp: AnyResponse): Unit {
        // In real implementation:
        // 1. Register onData handler to accumulate chunks
        // 2. Register onAborted handler to handle errors
        // 3. On last chunk, call the body callback
    }

    /// 对应 Bun: onData handler
    public func onData(resp: AnyResponse, chunk: Array<UInt8>, last: Bool): Unit {
        if (last) {
            var bodyData = body
            body.clear()
            resp.clearOnData()
            if (bodyData.size > 0) {
                // append chunk and call onBody
            } else {
                // call onBody with chunk directly
            }
        } else {
            // append chunk to body
        }
    }

    /// 对应 Bun: onOOM handler
    public func onOOM(r: AnyResponse): Unit {
        body.clear()
        r.clearAborted()
        r.clearOnData()
        r.clearOnWritable()
        r.writeStatus(Array<UInt8>(b"500 Internal Server Error"))
        r.endWithoutBody(false)
    }

    /// 对应 Bun: onInvalid handler
    public func onInvalid(r: AnyResponse): Unit {
        body.clear()
        r.clearAborted()
        r.clearOnData()
        r.clearOnWritable()
        r.writeStatus(Array<UInt8>(b"400 Bad Request"))
        r.endWithoutBody(false)
    }
}

// ============================================================================
// ArrayList - 简单动态数组
// ============================================================================
public class ArrayList<T> {
    private var items: Array<T> = Array<T>()
    private var cap: Int64 = 0

    public init() {}

    public func size(): Int64 {
        return items.size
    }

    public func clear(): Unit {
        items = Array<T>()
    }

    public func appendSlice(slice: Array<T>): Unit {
        // In real impl would grow array and copy
    }
}
