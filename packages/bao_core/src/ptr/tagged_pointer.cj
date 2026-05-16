// TaggedPointer / TaggedPointerUnion - 标记指针
// 严格翻译自: src/ptr/tagged_pointer.zig
// 64位中存储指针(49位)和标记(15位), 用于高效类型分发
package bao_core.ptr

import std.collection.ArrayList
import std.collection.*

// ============================================================================
// Tag type alias - 标记类型 (15位), 使用 UInt16 模拟 u15
// ============================================================================
public class Tag {
    public var value: UInt16
    public init(v: UInt16) { value = v }
}

// ============================================================================
// TaggedPointer - 标记指针
// 用 UInt64 模拟 packed struct: 低49位指针, 高15位标记
// ============================================================================
public class TaggedPointer {
    /// 内部存储 (64 位)
    private var repr: UInt64

    public init() {
        repr = 0
    }

    /// 获取原始表示
    public func rawRepr(): UInt64 {
        return repr
    }

    /// 设置原始表示 (内部使用)
    public func setRaw(val: UInt64): Unit {
        repr = val
    }

    /// 从指针地址值和标记创建 TaggedPointer
    public static func newFromPtr(address: UInt64, data: UInt16): TaggedPointer {
        let truncatedPtr = address & 0x1FFFFFFFFFFFF
        let tagged = truncatedPtr | (UInt64(data) << 49)
        let tp = TaggedPointer()
        tp.setRaw(tagged)
        return tp
    }

    /// 从 null 和标记创建
    public static func initNull(data: UInt16): TaggedPointer {
        let tp = TaggedPointer()
        tp.setRaw(UInt64(data) << 49)
        return tp
    }

    /// 获取指针地址值
    public func getAddress(): UInt64 {
        return repr & 0x1FFFFFFFFFFFF
    }

    /// 获取标记
    public func getData(): UInt16 {
        return UInt16((repr >> 49) & 0x7FFF)
    }

    /// 从原始值创建
    public static func fromRaw(val: UInt64): TaggedPointer {
        let tp = TaggedPointer()
        tp.setRaw(val)
        return tp
    }

    /// 从指针地址创建
    public static func fromAddress(address: UInt64): TaggedPointer {
        let tp = TaggedPointer()
        tp.setRaw(address)
        return tp
    }

    /// 是否为空
    public func isNull(): Bool {
        return repr == 0
    }
}

// ============================================================================
// TypeMapEntry - 类型映射条目
// ============================================================================
public class TypeMapEntry {
    public let value: UInt16
    public let typeName: String

    public init(value: UInt16, name: String) {
        this.value = value
        this.typeName = name
    }
}

// ============================================================================
// TaggedPointerUnion - 标记指针联合体
// 通过标记数据确定指针的实际类型
// ============================================================================
public class TaggedPointerUnion {
    /// 内部标记指针
    private var repr: TaggedPointer

    /// 类型映射表
    private var typeMap: ArrayList<TypeMapEntry>

    /// 空指针常量
    public static let Null: TaggedPointerUnion = TaggedPointerUnion()

    public init() {
        repr = TaggedPointer()
        typeMap = ArrayList<TypeMapEntry>()
    }

    /// 清空
    public func clear(): Unit {
        repr = TaggedPointer()
    }

    /// 根据标记获取类型名
    public func typeNameFromTag(tag: UInt16): ?String {
        for (entry in typeMap) {
            if (entry.value == tag) {
                return entry.typeName
            }
        }
        return None
    }

    /// 获取标记
    public func tag(): UInt16 {
        return repr.getData()
    }

    /// 检查是否是指定类型
    public func `is`(tag: UInt16): Bool {
        return repr.getData() == tag
    }

    /// 获取地址
    public func address(): UInt64 {
        return repr.rawRepr()
    }

    /// 从地址创建
    public static func from(addr: UInt64, map: ArrayList<TypeMapEntry>): TaggedPointerUnion {
        let tpu = TaggedPointerUnion()
        tpu.repr = TaggedPointer.fromAddress(addr)
        tpu.typeMap = map
        return tpu
    }

    /// 初始化指定类型的标记指针
    public static func newFromPtr(addr: UInt64, tag: UInt16, map: ArrayList<TypeMapEntry>): TaggedPointerUnion {
        let tagged = TaggedPointer.newFromPtr(addr, tag)
        let tpu = TaggedPointerUnion()
        tpu.repr = tagged
        tpu.typeMap = map
        return tpu
    }

    /// 是否为空
    public func isNull(): Bool {
        return repr.rawRepr() == 0
    }

    /// 检查标记是否有效
    public func isValid(): Bool {
        let data = repr.getData()
        if (data == 0) {
            return false
        }
        for (entry in typeMap) {
            if (entry.value == data) {
                return true
            }
        }
        return false
    }

    /// 获取底层标记指针
    public func getRepr(): TaggedPointer {
        return repr
    }

    /// 获取指针地址部分
    public func asUintptr(): UInt64 {
        return repr.rawRepr() & 0x1FFFFFFFFFFFF
    }

    /// 设置指针地址部分
    public func setUintptr(value: UInt64): Unit {
        let data = UInt64(repr.getData())
        repr = TaggedPointer.fromRaw((value & 0x1FFFFFFFFFFFF) | (data << 49))
    }
}
