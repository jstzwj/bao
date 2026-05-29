// bao_sql_jsc.shared - 共享连接类型
// 从 mysql/mysql_connection.cj 移出，供 mysql 和 postgres 共用
package bao_sql_jsc.shared

/// AnySocket
public class AnySocket {
    public init() {}
}

/// SSLConfig
public class SSLConfig {
    public init() {}
}

/// OffsetByteList
public class OffsetByteList {
    var head: Int64 = 0
    var bytes: Array<UInt8> = []

    public init() {}

    public func len(): Int64 {
        return bytes.size - head
    }

    public func remaining(): Array<UInt8> {
        if (head >= bytes.size) {
            return []
        }
        return bytes[head..]
    }

    public func consume(count: Int64): Unit {
        head += count
    }

    public func write(data: Array<UInt8>): Unit {
        bytes = bytes.concat(data)
    }

    public func clearAndFree(): Unit {
        bytes = []
        head = 0
    }

    public func reset(): Unit {
        head = 0
    }
}

/// ConnectionFlags
public class ConnectionFlags {
    public var hasBackpressure: Bool = false
    public var isProcessingData: Bool = false
    public var isReadyForQuery: Bool = true
    public var waitingToPrepare: Bool = false

    public init() {}
}
