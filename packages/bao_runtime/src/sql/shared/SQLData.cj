// SQL 共享数据类型
// 严格翻译自: src/sql/shared/Data.zig
package bao_runtime.sql.shared

import bao_core.*
import bao_collections.*

/// SQL 数据存储模式
/// 对应 Bun: Data (union enum) 的标签
public enum SQLStorageMode {
    | owned          // 自有堆内存
    | temporary      // 临时引用 (不拥有)
    | inlineStorage  // 内联存储 (<= 15 字节)
    | empty          // 空

    public operator func ==(right: SQLStorageMode): Bool {
        match (this) {
            case owned => match (right) { case owned => true case _ => false }
            case temporary => match (right) { case temporary => true case _ => false }
            case inlineStorage => match (right) { case inlineStorage => true case _ => false }
            case empty => match (right) { case empty => true case _ => false }
        }
    }

    public operator func !=(right: SQLStorageMode): Bool {
        !(this == right)
    }
}

/// SQL 协议中可变数据
/// 对应 Bun: Data (union enum)
/// 支持四种存储方式: 自有堆内存、临时引用、内联存储、空
public class SQLData {
    /// 存储模式
    public var mode: SQLStorageMode
    /// 自有数据
    public var ownedData: Array<UInt8>
    /// 临时引用 (起始索引和长度, 指向外部 buffer)
    public var tempRef: Array<UInt8>
    /// 内联存储
    public var inlineBuf: Array<UInt8>
    /// 内联长度
    public var inlineLen: Int64

    public init() {
        mode = SQLStorageMode.empty
        ownedData = Array<UInt8>()
        tempRef = Array<UInt8>()
        inlineBuf = Array<UInt8>(15, repeat: 0)
        inlineLen = 0
    }

    /// 创建空数据
    public static func empty(): SQLData {
        return SQLData()
    }

    /// 从字节数组创建 (自有拷贝)
    public static func fromOwned(bytes: Array<UInt8>): SQLData {
        let d = SQLData()
        d.mode = SQLStorageMode.owned
        d.ownedData = bytes
        return d
    }

    /// 创建临时引用 (不拷贝, 不拥有)
    public static func fromTemporary(bytes: Array<UInt8>): SQLData {
        let d = SQLData()
        if (bytes.size == 0) {
            d.mode = SQLStorageMode.empty
        } else {
            d.mode = SQLStorageMode.temporary
            d.tempRef = bytes
        }
        return d
    }

    /// 从字符串创建自有数据
    public static func fromString(s: String): SQLData {
        if (s.isEmpty()) {
            return SQLData.empty()
        }
        let bytes = s.toArray()
        let d = SQLData()
        if (bytes.size <= 15) {
            d.mode = SQLStorageMode.inlineStorage
            for (i in 0..bytes.size) {
                d.inlineBuf[i] = bytes[i]
            }
            d.inlineLen = bytes.size
        } else {
            d.mode = SQLStorageMode.owned
            d.ownedData = bytes
        }
        return d
    }

    /// 创建可能使用内联存储的数据
    /// 对应 Bun: Data.create
    public static func create(bytes: Array<UInt8>): SQLData {
        if (bytes.size == 0) {
            return SQLData.empty()
        }
        if (bytes.size <= 15) {
            let d = SQLData()
            d.mode = SQLStorageMode.inlineStorage
            for (i in 0..bytes.size) {
                d.inlineBuf[i] = bytes[i]
            }
            d.inlineLen = bytes.size
            return d
        }
        // 拷贝为自有
        let d = SQLData()
        d.mode = SQLStorageMode.owned
        let buf = ArrayList<UInt8>()
        for (b in bytes) {
            buf.append(b)
        }
        d.ownedData = buf.items()
        return d
    }

    /// 释放资源
    /// 对应 Bun: Data.deinit
    public func deinit(): Unit {
        match (mode) {
            case SQLStorageMode.owned =>
                ownedData = Array<UInt8>()
            case SQLStorageMode.temporary => ()
            case SQLStorageMode.empty => ()
            case SQLStorageMode.inlineStorage => ()
        }
        mode = SQLStorageMode.empty
    }

    /// 安全清零后释放 (用于密码等敏感数据)
    /// 对应 Bun: Data.zdeinit
    public func zdeinit(): Unit {
        match (mode) {
            case SQLStorageMode.owned =>
                for (i in 0..ownedData.size) {
                    ownedData[i] = 0
                }
                ownedData = Array<UInt8>()
            case SQLStorageMode.temporary => ()
            case SQLStorageMode.empty => ()
            case SQLStorageMode.inlineStorage =>
                for (i in 0..inlineLen) {
                    inlineBuf[i] = 0
                }
                inlineLen = 0
        }
        mode = SQLStorageMode.empty
    }

    /// 获取数据的字节切片
    /// 对应 Bun: Data.slice
    public func slice(): Array<UInt8> {
        match (mode) {
            case SQLStorageMode.owned => ownedData
            case SQLStorageMode.temporary => tempRef
            case SQLStorageMode.empty => Array<UInt8>()
            case SQLStorageMode.inlineStorage =>
                let result = ArrayList<UInt8>()
                for (i in 0..inlineLen) {
                    result.append(inlineBuf[i])
                }
                return result.items()
        }
    }

    /// 获取子切片
    /// 对应 Bun: Data.substring
    public func substring(startIndex: Int64, endIndex: Int64): SQLData {
        match (mode) {
            case SQLStorageMode.owned =>
                let sub = ArrayList<UInt8>()
                for (i in startIndex..endIndex) {
                    if (i < ownedData.size) {
                        sub.append(ownedData[i])
                    }
                }
                return SQLData.fromTemporary(sub.items())
            case SQLStorageMode.temporary =>
                let sub = ArrayList<UInt8>()
                for (i in startIndex..endIndex) {
                    if (i < tempRef.size) {
                        sub.append(tempRef[i])
                    }
                }
                return SQLData.fromTemporary(sub.items())
            case SQLStorageMode.empty => SQLData.empty()
            case SQLStorageMode.inlineStorage =>
                let sub = ArrayList<UInt8>()
                for (i in startIndex..endIndex) {
                    if (i < inlineLen) {
                        sub.append(inlineBuf[i])
                    }
                }
                return SQLData.fromTemporary(sub.items())
        }
    }

    /// 数据长度
    public func len(): Int64 {
        match (mode) {
            case SQLStorageMode.owned => ownedData.size
            case SQLStorageMode.temporary => tempRef.size
            case SQLStorageMode.empty => 0
            case SQLStorageMode.inlineStorage => inlineLen
        }
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return mode == SQLStorageMode.empty || len() == 0
    }

    /// 转为自有数据 (拷贝)
    /// 对应 Bun: Data.toOwned
    public func toOwned(): SQLData {
        let bytes = slice()
        let d = SQLData()
        d.mode = SQLStorageMode.owned
        let buf = ArrayList<UInt8>()
        for (b in bytes) {
            buf.append(b)
        }
        d.ownedData = buf.items()
        return d
    }
}
