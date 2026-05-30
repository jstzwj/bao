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
public class SpawnStdio { public init() {} }

public class EventLoop {
    public init() {}
    public static func enterScope(eventLoop!: EventLoop): EventLoopScope {
        EventLoopScope()
    }
}

public class EventLoopScope {
    public init() {}
    public func deinit(): Unit {}
}

public class BackRef<T> {
    public var value: ?T = None
    public init() {}
    public init(value!: T) {
        this.value = Some(value)
    }
    public static func from(value!: T): BackRef<T> {
        BackRef<T>(value: value)
    }
    public func get(): T {
        value.getOrThrow()
    }
    public func asPtr(): BackRefPtr<T> {
        BackRefPtr<T>(value: get())
    }
}

public class BackRefPtr<T> {
    public var pointee: T
    public init(value!: T) {
        pointee = value
    }
}

public class JSPromiseStrong {
    public init() {}
    public init(globalThis: JsGlobalObject) {}
    public static func default(): JSPromiseStrong { JSPromiseStrong() }
    public func getValue(): JsValue { JsValue.jsUndefined() }
}

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

public class Strings {
    public static func eqlComptime(input!: String, expected!: String): Bool {
        return input == expected
    }

    public static func hasPrefixComptime(input!: String, prefix!: String): Bool {
        return input.startsWith(prefix)
    }

    public static func withoutTrailingSlashWindowsPath(input!: String): String {
        return input
    }

    public static func trimLeft(input!: Array<UInt8>, chars!: String): Array<UInt8> {
        var start: Int64 = 0
        while (start < input.size) {
            let c = input[start]
            if (chars == "/" && c == UInt8(47)) {
                start++
                continue
            }
            break
        }
        return input[start..input.size]
    }
}

// BAO_STUB: compatibility shims for src/runtime/api/bun/spawn.zig consumers.
// TODO(bao-runtime-api): move these back into the real spawn translation once it is restored.
public class WaitPidResult {
    public var pid: Int32 = 0
    public var status: UInt32 = 0
    public init() {}
}
public class FD {
    public var value: Int32 = 0
    public init(value: Int32) { this.value = value }
    public func native(): Int32 { value }
    public func cast(): Int32 { value }
    public func close(): Unit {}
    public func toFd(): FD { this }
    public func toJS(globalThis!: JsGlobalObject): JsValue { JsValue.jsNumber(Int64(value)) }
    public func stdioTag(): ?FDStdio { FDStdio.fromInt(i: value) }
    public operator func ==(right: FD): Bool { value == right.value }
    public operator func !=(right: FD): Bool { value != right.value }
    public static let invalid: FD = FD(-1)
    public static let Stdio: FDStdioHelper = FDStdioHelper()
}

public enum FDStdio { | std_in | std_out | std_err
    public static func fromInt(i!: Int32): ?FDStdio {
        match (i) {
            case 0 => Some(FDStdio.std_in)
            case 1 => Some(FDStdio.std_out)
            case 2 => Some(FDStdio.std_err)
            case _ => None
        }
    }
    public func fd(): FD {
        match (this) {
            case std_in => FD(0)
            case std_out => FD(1)
            case std_err => FD(2)
        }
    }
}

public class FDStdioHelper {
    public init() {}
    public func fromInt(i!: Int32): ?FDStdio { FDStdio.fromInt(i: i) }
}

// BAO_STUB: compatibility shims split out from src/runtime/api/bun/Terminal.rs.
// TODO(bao-runtime-api): restore concrete event-loop handles and JS references with Terminal/process ownership.
public class EventLoopHandle {
    public init() {}
    public func ref(): Unit {}
    public func unref(): Unit {}
}

public class JsRef {
    public init() {}
    public static func empty(): JsRef { JsRef() }
    public static func initStrong(value!: JsValue, globalThis!: JsGlobalObject): JsRef { JsRef() }
    public static func initWeak(value!: JsValue, globalThis!: JsGlobalObject): JsRef { JsRef() }
    public func get(): JsValue { JsValue.jsUndefined() }
    public func tryGet(): ?JsValue { None }
    public func clear(): Unit {}
    public func finalize(): Unit {}
    public func upgrade(globalThis!: JsGlobalObject): Unit {}
    public func downgrade(): Unit {}
    public func update(globalThis!: JsGlobalObject, value!: JsValue): Unit {}
    public func ensureStillAlive(): Unit {}
}
