// 翻译自 Bun: src/runtime/bake/DevServer/SerializedFailure.zig
// 发送到浏览器中 HMR 客户端的错误是序列化的。

package bao_runtime.bake.dev_server

/// 序列化失败 - 发送到 HMR 客户端的序列化错误
public struct Packed {
    public var kind: SerializedFailureOwnerKind
    public var data: UInt32

    public init() {
        kind = SerializedFailureOwnerKind.none
        data = 0
    }
    public init(kind: SerializedFailureOwnerKind, data: UInt32) {
        this.kind = kind
        this.data = data
    }
}

/// UInt30 type alias
public type UInt30 = UInt32

public enum SerializedFailureOwnerKind {
    | none
    | route
    | client
    | server
}

public class ArrayHashContextViaSerializedFailureOwner {
    public static func hash(k: SerializedFailure): UInt32 {
        return 0
    }

    public static func eql(a: SerializedFailure, b: SerializedFailure): Bool {
        return false
    }
}

public class ArrayHashAdapter {
    public static func hash(own: SerializedFailureOwner): UInt32 {
        return 0
    }

    public static func eql(a: SerializedFailureOwner, b: SerializedFailure): Bool {
        return false
    }
}

public enum ErrorKind {
    | None
}

public enum SerializedFailureOwner {
    | none
    | route(UInt32)
    | client(UInt32)
    | server(UInt32)

    public func encode(): Packed {
        return match (this) {
            case none => Packed(SerializedFailureOwnerKind.none, 0)
            case client(d) => Packed(SerializedFailureOwnerKind.client, d)
            case server(d) => Packed(SerializedFailureOwnerKind.server, d)
            case route(d) => Packed(SerializedFailureOwnerKind.route, d)
        }
    }
}

public class SerializedFailure <: ToString {
    public func toString(): String { "SerializedFailure@${data.size}" }
    /// 序列化数据始终由 dev.allocator() 拥有
    /// 前 32 位包含所有者信息
    public var data: Array<Byte>

    public init() {
        data = Array<Byte>()
    }

    public init(data: Array<Byte>) {
        this.data = data
    }

    /// 析构
    public func deinit(dev: DevServer): Unit {
        // dev.allocator().free(data)
    }

    /// 获取所有者
    public func getSerializedFailureOwner(): SerializedFailureOwner {
        let packed: Packed = Packed()
        return match (packed.kind) {
            case SerializedFailureOwnerKind.none => SerializedFailureOwner.none
            case SerializedFailureOwnerKind.client => SerializedFailureOwner.client(packed.data)
            case SerializedFailureOwnerKind.server => SerializedFailureOwner.server(packed.data)
            case SerializedFailureOwnerKind.route => SerializedFailureOwner.route(packed.data)
        }
    }

    /// 从日志初始化
    public static func initFromLog(
        dev: DevServer,
        owner: SerializedFailureOwner,
        owner_display_name: String,
        messages: Array<LoggerMsg>
    ): SerializedFailure {
        assert(messages.size > 0)

        var payload: ArrayList<Byte> = ArrayList<Byte>()
        let w = payload.writer()

        // 写入所有者
        // w.writeInt(...)

        let result_data = payload.items
        return SerializedFailure(result_data)
    }

    /// 写入日志消息
    static func writeLogMsg(msg: LoggerMsg, w: Writer): Unit {
        writeLogData(msg.data, w)
    }

    /// 写入日志数据
    static func writeLogData(data: LoggerData, w: Writer): Unit {
        // w.writeInt(data.text.size)
        // w.writeAll(data.text)
    }

    /// 写入长度前缀字符串
    static func writeString32(data: String, w: Writer): Unit {
        // w.writeInt(data.size)
        // w.writeAll(data)
    }
}
