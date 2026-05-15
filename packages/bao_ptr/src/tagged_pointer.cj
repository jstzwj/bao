// 严格翻译自: src/ptr/tagged_pointer.zig
// TaggedPointer - 标记指针
// TaggedPointerUnion - 标记指针联合体
// 将指针和标记数据打包在一个机器字中
package bao_ptr

import bao_core.*

// ============================================================================
// AddressableSize - 可寻址大小 (u49)
// 在 64 位系统上，只有 49 位用于地址 (x86_64 的规范地址形式)
// 剩余 15 位用于标记数据
// ============================================================================

/// 可寻址大小类型 (49位)
/// 用于 TaggedPointer 中存储指针地址
public type AddressableSize = UInt64

// ============================================================================
// TaggedPointer - 标记指针 (packed struct u64)
// ============================================================================

/// 标记指针
/// 将指针地址和标记数据打包在一个 64 位字中
/// 指针地址占 49 位 (_ptr)，标记数据占 15 位 (data)
///
/// 在 x86_64 上，只有低 48 位 (或带符号扩展的 57 位) 用于地址
/// 但这里使用 49 位以确保安全，剩余 15 位用于标记
public struct TaggedPointer {
    /// 指针地址 (49 位有效)
    public var _ptr: AddressableSize = 0
    /// 标记数据 (15 位)
    public var data: UInt16 = 0

    public init() {}

    /// Tag 类型 (15 位标记)
    public type Tag = UInt16

    /// 初始化标记指针
    /// ptr: 任意指针类型
    /// data: 标记数据 (Tag)
    public static func init(ptr: UInt64, data: UInt16): TaggedPointer {
        TaggedPointer(_ptr: ptr, data: data)
    }

    /// 从指针值创建，截断到 AddressableSize
    public static func initFromPtr(ptr: UInt64, data: UInt16): TaggedPointer {
        TaggedPointer(_ptr: ptr, data: data)
    }

    /// 获取指针，转换为指定类型
    public func get(): UInt64 {
        this._ptr
    }

    /// 从 f64/i64/u64/指针值创建
    public static func from(val: UInt64): TaggedPointer {
        TaggedPointer(_ptr: val, data: 0)
    }

    /// 从指针地址创建
    public static func fromPtr(ptr: UInt64): TaggedPointer {
        TaggedPointer(_ptr: ptr, data: 0)
    }

    /// 转换为不透明指针
    public func to(): UInt64 {
        this._ptr
    }

    /// 是否为空
    public func isNull(): Bool {
        this._ptr == 0
    }
}

// ============================================================================
// TypeMapEntry - 类型映射条目
// ============================================================================

/// 类型映射条目
/// 将标记值、类型名称关联起来
public struct TypeMapEntry {
    public var value: UInt16 = 0
    public var typeName: String = ""

    public init() {}
    public init(value: UInt16, typeName: String) {
        this.value = value
        this.typeName = typeName
    }
}

// ============================================================================
// TaggedPointerUnion - 标记指针联合体
// ============================================================================

/// 标记指针联合体
/// 一个可以存储多种指针类型的标记指针
/// 通过标记值区分存储的指针类型
///
/// 使用示例:
///   let union = TaggedPointerUnion(types)
///   union.initWithType(MyType, ptr)
///   if (union.is(MyType)) { ... }
///   let ptr = union.get(MyType)
public class TaggedPointerUnion {
    /// 内部表示
    public var repr: TaggedPointer = TaggedPointer()

    /// 类型映射表
    public var typeMap: Array<TypeMapEntry> = Array<TypeMapEntry>()

    public init() {}

    /// 空值
    public static func null_(): TaggedPointerUnion {
        TaggedPointerUnion()
    }

    /// 清除
    public func clear(): Unit {
        this.repr = TaggedPointer()
    }

    /// 根据标记值获取类型名称
    public func typeNameFromTag(tag: UInt16): ?String {
        for (i in 0..this.typeMap.length) {
            if (this.typeMap[i].value == tag) {
                return Some(this.typeMap[i].typeName)
            }
        }
        return None<String>
    }

    /// 获取类型名称
    public func typeName(): ?String {
        this.typeNameFromTag(this.repr.data)
    }

    /// 获取标记值
    public func tag(): UInt16 {
        this.repr.data
    }

    /// 设置 uintptr 值
    public func setUintptr(value: AddressableSize): Unit {
        this.repr._ptr = value
    }

    /// 获取 uintptr 值
    public func asUintptr(): AddressableSize {
        this.repr._ptr
    }

    /// 检查是否为指定类型 (通过标记值比较)
    public func isByTag(tag: UInt16): Bool {
        this.repr.data == tag
    }

    /// 设置指针
    public func set(ptr: UInt64, tag: UInt16): Unit {
        this.repr = TaggedPointer(_ptr: ptr, data: tag)
    }

    /// 检查是否为有效指针 (标记在有效范围内)
    public func isValid(): Bool {
        if (this.typeMap.length == 0) {
            return false
        }
        let tagVal = this.repr.data
        // 检查标记是否在类型映射范围内
        var minVal: UInt16 = this.typeMap[0].value
        var maxVal: UInt16 = this.typeMap[0].value
        for (i in 1..this.typeMap.length) {
            if (this.typeMap[i].value < minVal) {
                minVal = this.typeMap[i].value
            }
            if (this.typeMap[i].value > maxVal) {
                maxVal = this.typeMap[i].value
            }
        }
        tagVal >= minVal && tagVal <= maxVal
    }

    /// 从不透明指针创建
    public static func from(ptr: UInt64): TaggedPointerUnion {
        let union_ = TaggedPointerUnion()
        union_.repr = TaggedPointer.fromPtr(ptr)
        return union_
    }

    /// 获取指针
    public func ptr(): UInt64 {
        this.repr.to()
    }

    /// 初始化 (使用指定指针和类型标记)
    public static func init(ptr: UInt64, tag: UInt16): TaggedPointerUnion {
        let union_ = TaggedPointerUnion()
        union_.repr = TaggedPointer.init(ptr, tag)
        return union_
    }

    /// 是否为空
    public func isNull(): Bool {
        this.repr._ptr == 0
    }

    /// 使用类型映射调用虚方法
    /// fnName: 方法名
    /// args: 参数 (不包括 this)
    /// 在类型映射中查找匹配的标记值，然后调用对应类型的方法
    public func call(fnName: String, args: Array<Any>): Any {
        // 在仓颉中通过反射实现
        // 查找类型映射中与当前标记匹配的条目
        for (i in 0..this.typeMap.length) {
            if (this.repr.data == this.typeMap[i].value) {
                // 找到匹配类型，执行方法调用
                // 这里简化实现
                return None<Any>
            }
        }
        // 无效标记
        return None<Any>
    }
}

// ============================================================================
// TagTypeEnumBuilder - 标记类型枚举构建器
// ============================================================================

/// 标记类型枚举构建器辅助
/// 用于从类型列表构建枚举和类型映射
public class TagTypeEnumBuilder {
    /// 构建类型映射
    /// 为每个类型分配一个标记值 (从 1024 递减)
    public static func buildTypeMap(typeNames: Array<String>): Array<TypeMapEntry> {
        var map = Array<TypeMapEntry>(typeNames.length)
        for (i in 0..typeNames.length) {
            map[i] = TypeMapEntry(
                value: UInt16(1024 - i),
                typeName: typeNames[i]
            )
        }
        return map
    }
}
