// bao_core - 指针工具
// 对应 Bun: src/ptr/
package bao_core
import std.collection.*

// ============================================================================
// 指针工具类
// 对应 Bun: src/ptr/ 中的指针操作
// ============================================================================

/// 指针工具 - 简化版，不使用泛型 CPointer
public class PtrUtils {
    /// 判断指针是否为空
    public static func isNull(ptr: CPointer<UInt8>): Bool {
        unsafe {
            return ptr.isNull()
        }
    }

    /// 从指针读取值
    public static func readByte(ptr: CPointer<UInt8>): UInt8 {
        unsafe {
            return ptr.read()
        }
    }

    /// 向指针写入值
    public static func writeByte(ptr: CPointer<UInt8>, value: UInt8): Unit {
        unsafe {
            ptr.write(value)
        }
    }

    /// 指针偏移
    public static func offset(ptr: CPointer<UInt8>, off: Int64): CPointer<UInt8> {
        unsafe {
            return ptr + off
        }
    }
}

/// 原始字节缓冲区
/// 对应 Bun 的 PathBuffer / 固定大小缓冲区
public class ByteBuffer {
    private var data: Array<UInt8>
    private var pos: Int64

    public init(capacity: Int64) {
        data = Array<UInt8>(capacity, { _ => UInt8(0) })
        pos = 0
    }

    public init(bytes: Array<UInt8>) {
        data = bytes
        pos = bytes.size
    }

    /// 获取容量
    public func capacity(): Int64 {
        return data.size
    }

    /// 获取当前位置
    public func position(): Int64 {
        return pos
    }

    /// 获取剩余空间
    public func remaining(): Int64 {
        return data.size - pos
    }

    /// 写入字节
    public func writeByte(b: UInt8): Unit {
        if (pos < data.size) {
            data[pos] = b
            pos += 1
        }
    }

    /// 写入字节数组
    public func writeBytes(bytes: Array<UInt8>): Unit {
        for (b in bytes) {
            writeByte(b)
        }
    }

    /// 读取一个字节
    public func readByte(): UInt8 {
        if (pos < data.size) {
            let b = data[pos]
            pos += 1
            return b
        }
        return 0
    }

    /// 读取指定长度字节
    public func readBytes(len: Int64): Array<UInt8> {
        var result = ArrayList<UInt8>()
        for (i in 0..len) {
            if (pos < data.size) {
                result.add(data[pos])
                pos += 1
            }
        }
        return result.toArray()
    }

    /// 获取底层字节数组
    public func bytes(): Array<UInt8> {
        return data
    }

    /// 获取有效数据的切片
    public func slice(): Array<UInt8> {
        var result = ArrayList<UInt8>()
        for (i in 0..pos) {
            result.add(data[i])
        }
        return result.toArray()
    }

    /// 重置位置
    public func reset(): Unit {
        pos = 0
    }

    /// 清空
    public func clear(): Unit {
        for (i in 0..data.size) {
            data[i] = 0
        }
        pos = 0
    }
}
