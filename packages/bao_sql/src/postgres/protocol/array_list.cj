// 严格翻译自: src/sql/postgres/protocol/ArrayList.zig
// PostgreSQL 协议 ArrayList 写入器
package bao_sql.postgres.protocol

import std.collection.ArrayList as StdArrayList


/// ArrayList 写入器 - 用于构建 PostgreSQL 协议消息
/// 对应 Bun: ArrayList
public class ArrayList {
    public var array: StdArrayList<UInt8>

    public init() {
        array = StdArrayList<UInt8>()
    }

    /// 获取当前偏移量
    /// 对应 Bun: ArrayList.offset
    public func offset(): Int64 {
        return array.size
    }

    /// 写入字节
    /// 对应 Bun: ArrayList.write
    public func write(bytes: Array<UInt8>): Unit {
        for (i in 0..bytes.size) {
            array.add(bytes[Int64(i)])
        }
    }

    /// 在指定位置写入字节
    /// 对应 Bun: ArrayList.pwrite
    public func pwrite(bytes: Array<UInt8>, pos: Int64): Unit {
        for (i in 0..bytes.size) {
            array[Int64(pos + Int64(i))] = bytes[Int64(i)]
        }
    }
}
