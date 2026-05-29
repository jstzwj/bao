// bao_runtime.api 公共 stub 类型
// 子包隔离导致无法直接引用 bao_runtime.webcore/bao_runtime.node 中的类型
// 此文件集中定义所有需要的 stub 类型
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}
import bao_core.{Allocator, Output}
import bao_collections.{ArrayList, HashMap}

// 缺失的类型 stub
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
public class EnumSet { public init() {} }
public class FileSink { public init() {} }
public class EventLoopTimer { public init() {} }
public class IPCDecodedIPCMessage { public init() {} }
