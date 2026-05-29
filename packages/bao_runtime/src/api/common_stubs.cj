// bao_runtime.api 公共 stub 类型
// 子包隔离导致无法直接引用 bao_runtime.webcore/bao_runtime.node 中的类型
// 此文件集中定义所有需要的 stub 类型
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, CallFrame, BunVirtualMachine}
import bao_core.{Allocator, Output}
import bao_collections.{ArrayList, HashMap}

// 缺失的类型桥接
public type JsCallFrame = CallFrame
public type VirtualMachine = BunVirtualMachine
public class ArrayBufferStrong {
    public init() {}
    public func getArrayBuffer(): ArrayBufferStrong { this }
    public func byteSlice(): Array<UInt8> { [] }
    public func slice(): Array<UInt8> { [] }
    public func deinit(): Unit {}
}
public class ReadableStream {
    public init() {}
    public static func fromJS(value: JsValue, globalThis: JsGlobalObject): ?ReadableStream { None }
    public func isDisturbed(globalThis: JsGlobalObject): Bool { false }
    public func cancel(globalThis: JsGlobalObject): Unit {}
}
public class UvPipe { public init() {} }
public class Mutex {
    public init() {}
    public func lock(): Unit {}
    public func unlock(): Unit {}
}
public class WriterRefCount { public init() {} }
public class Result { public init() {} }
public class StdioPipeItem { public init() {} }
public class IPCDecodedIPCMessage { public init() {} }

public class IPCSendQueue {
    public init() {}
    public func closeSocketNextTick(nextTick: Bool): Unit {}
    public func deinit(): Unit {}
}

public class AbortSignal {
    public init() {}
    public func pendingActivityUnref(): Unit {}
    public func cleanNativeBindings(ctx: Any): Unit {}
    public func unref(): Unit {}
    public func addListener(ctx: Any, callback: Any): AbortSignal { this }
}

public class ApiStringBuilder {
    private var parts: ArrayList<String> = ArrayList<String>()
    public init() {}
    public func append(s: String): Unit {
        parts.append(s)
    }
    public func appendChar(c: UInt8): Unit {
        parts.append(String(Rune(c)))
    }
    public func appendChar(c: Rune): Unit {
        parts.append(String(c))
    }
    public func ensureUnusedCapacity(additional: Int64): Unit {}
    public func appendFormat(fmt: String, value: String): Unit {
        parts.append(value)
    }
    public func toString(globalThis: JsGlobalObject): JsValue {
        var out = ""
        for (part in parts) {
            out += part
        }
        return JsValue.jsString(out)
    }
    public func deinit(): Unit {
        parts.clear()
    }
}
