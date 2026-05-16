// 严格翻译自: src/sql/shared/Data.zig
// 数据包装类型 - 可以是拥有的、临时的、内联存储的或空的
package bao_sql.shared

import std.collection.*

/// 数据种类
public enum DataKind {
    | owned
    | temporary
    | inline_storage
    | empty
}

/// 表示可以是拥有、临时、内联存储或空的数据
/// 对应 Bun: Data (union enum)
public class Data {
    /// 数据种类
    public var kind: DataKind

    /// 底层字节存储
    public var bytes: ArrayList<UInt8>

    /// 内联存储最大字节数
    public static let INLINE_STORAGE_MAX: Int64 = 15

    public init() {
        kind = DataKind.empty
        bytes = ArrayList<UInt8>()
    }

    public init(kind: DataKind, bytes: ArrayList<UInt8>) {
        this.kind = kind
        this.bytes = bytes
    }

    /// 创建空数据
    public static func emptyData(): Data {
        return Data(DataKind.empty, ArrayList<UInt8>())
    }

    /// 拷贝字节到新的ArrayList
    private static func copyBytes(src: ArrayList<UInt8>): ArrayList<UInt8> {
        let copy = ArrayList<UInt8>()
        for (i in 0..src.size) {
            copy.add(src[Int64(i)])
        }
        return copy
    }

    /// 创建数据 - 短数据使用内联存储，长数据使用堆分配
    /// 对应 Bun: Data.create
    public static func create(bytes: Array<UInt8>): Data {
        if (bytes.size == 0) {
            return Data.emptyData()
        }

        if (Int64(bytes.size) <= Data.INLINE_STORAGE_MAX) {
            return Data(DataKind.inline_storage, copyBytesFromArray(bytes))
        }

        return Data(DataKind.owned, copyBytesFromArray(bytes))
    }

    /// 从数组拷贝字节
    private static func copyBytesFromArray(src: Array<UInt8>): ArrayList<UInt8> {
        let list = ArrayList<UInt8>()
        for (i in 0..src.size) {
            list.add(src[i])
        }
        return list
    }

    /// 从ArrayList创建拥有数据
    public static func fromOwned(bytes: ArrayList<UInt8>): Data {
        return Data(DataKind.owned, bytes)
    }

    /// 从ArrayList创建临时数据
    public static func fromTemporary(bytes: ArrayList<UInt8>): Data {
        return Data(DataKind.temporary, bytes)
    }

    /// 从ArrayList创建内联存储数据
    public static func fromInlineStorage(bytes: ArrayList<UInt8>): Data {
        return Data(DataKind.inline_storage, bytes)
    }

    /// 从数组创建拥有数据
    public static func ownedFromArray(bytes: Array<UInt8>): Data {
        return Data(DataKind.owned, copyBytesFromArray(bytes))
    }

    /// 将数据转为拥有形式 (深拷贝)
    /// 对应 Bun: Data.toOwned
    public func toOwned(): Data {
        match (kind) {
            case DataKind.owned => Data(DataKind.owned, bytes)
            case DataKind.temporary => Data(DataKind.owned, Data.copyBytes(bytes))
            case DataKind.empty => Data.emptyData()
            case DataKind.inline_storage => Data(DataKind.owned, Data.copyBytes(bytes))
        }
    }

    /// 释放数据
    /// 对应 Bun: Data.deinit
    public func release(): Unit {
        match (kind) {
            case DataKind.owned => releaseOwned()
            case DataKind.temporary => ()
            case DataKind.empty => ()
            case DataKind.inline_storage => ()
        }
    }

    private func releaseOwned(): Unit {
        bytes.clear()
        kind = DataKind.empty
    }

    /// 安全清零后释放 (用于密码等敏感数据)
    /// 对应 Bun: Data.zdeinit
    public func secureRelease(): Unit {
        match (kind) {
            case DataKind.owned => secureReleaseOwned()
            case DataKind.temporary => ()
            case DataKind.empty => ()
            case DataKind.inline_storage => ()
        }
    }

    private func secureReleaseOwned(): Unit {
        for (i in 0..bytes.size) {
            bytes[Int64(i)] = 0
        }
        bytes.clear()
        kind = DataKind.empty
    }

    /// 获取字节切片
    /// 对应 Bun: Data.slice
    public func slice(): Array<UInt8> {
        return bytes.toArray()
    }

    /// 获取子串
    /// 对应 Bun: Data.substring
    public func substring(startIndex: Int64, endIndex: Int64): Data {
        let subBytes = ArrayList<UInt8>()
        for (i in startIndex..endIndex) {
            if (Int64(i) < bytes.size) {
                subBytes.add(bytes[Int64(i)])
            }
        }
        return Data(DataKind.temporary, subBytes)
    }

    /// 获取数据长度
    public func len(): Int64 {
        return Int64(bytes.size)
    }
}
