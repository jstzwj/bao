// 严格翻译自: src/jsc/bindgen.zig (255行)
// JSC 绑定代码生成 - FFI 类型转换基础设施
// 提供从 C/C++ 外部类型到仓颉内部类型的桥接转换

package bao_jsc

import bao_collections.*

// ========== BindgenTrivial<T> ==========
// 严格翻译自 bindgen.zig BindgenTrivial
// 平凡类型的 FFI 桥接，ExternType 和 ZigType 相同
public class BindgenTrivial<T> {
    public var externValue: T

    public init(value: T) {
        this.externValue = value
    }

    // 严格翻译自 BindgenTrivial.convertFromExtern
    public func convertFromExtern(): T {
        externValue
    }
}

// ========== 具体的平凡类型桥接 ==========
// 严格翻译自 bindgen.zig 的各个 BindgenXxx 常量
public type BindgenBool = BindgenTrivial<Bool>
public type BindgenU8 = BindgenTrivial<UInt8>
public type BindgenI8 = BindgenTrivial<Int8>
public type BindgenU16 = BindgenTrivial<UInt16>
public type BindgenI16 = BindgenTrivial<Int16>
public type BindgenU32 = BindgenTrivial<UInt32>
public type BindgenI32 = BindgenTrivial<Int32>
public type BindgenU64 = BindgenTrivial<UInt64>
public type BindgenI64 = BindgenTrivial<Int64>
public type BindgenF64 = BindgenTrivial<Float64>
public type BindgenRawAny = BindgenTrivial<JsValue>

// ========== BindgenStrongAny ==========
// 严格翻译自 bindgen.zig BindgenStrongAny
// 强引用类型的 FFI 桥接
public class BindgenStrongAny {
    // 严格翻译自 BindgenStrongAny.convertFromExtern
    public static func convertFromExtern(externValue: ?StrongImpl): Strong<JsValue> {
        let strong = Strong<JsValue>()
        if (let Some(impl) <- externValue) {
            strong.impl = impl
        }
        strong
    }

    // 严格翻译自 BindgenStrongAny.convertOptionalFromExtern
    public static func convertOptionalFromExtern(externValue: ?StrongImpl): StrongOptional<JsValue> {
        let strong = StrongOptional<JsValue>()
        if (let Some(impl) <- externValue) {
            strong.impl = impl
        }
        strong
    }
}

// ========== BindgenNull ==========
// 严格翻译自 bindgen.zig BindgenNull
// 表示 IDLNull 和 IDLMonostateUndefined
public class BindgenNull {
    public let tag: UInt8 = 0

    public init() {}

    // 严格翻译自 BindgenNull.convertFromExtern
    public static func convertFromExtern(externValue: UInt8): Unit {
        // 丢弃外部值，返回 void
    }
}

// ========== BindgenOptional<Child> ==========
// 严格翻译自 bindgen.zig BindgenOptional
// 可选值的 FFI 桥接
public class BindgenOptional<T> {
    public var value: ?T = None
    public var tag: UInt8 = 0

    public init() {}

    public init(value: T) {
        this.value = value
        this.tag = 1
    }

    // 严格翻译自 BindgenOptional.convertFromExtern
    public static func convertFromExtern<T>(externValue: BindgenExternOptional<T>): ?T {
        if (externValue.tag == 0) {
            return None
        }
        Some(externValue.data)
    }
}

// 外部可选值表示
public class BindgenExternOptional<T> {
    public var data: T
    public var tag: UInt8 = 0

    public init(data: T, tag: UInt8) {
        this.data = data
        this.tag = tag
    }
}

// ========== BindgenString ==========
// 严格翻译自 bindgen.zig BindgenString
// 字符串类型的 FFI 桥接
public class BindgenString {
    // 严格翻译自 BindgenString.convertFromExtern
    // 外部字符串表示为 UTF-8 字节切片
    public static func convertFromExtern(ptr: CPointer<UInt8>, len: Int64): String {
        if (len == 0 || ptr.isNull()) {
            return ""
        }
        // 从 C 指针构造字符串: 将指定长度的字节读取为仓颉 String
        var bytes = Array<UInt8>(Int64(len), { _ => UInt8(0) })
        unsafe {
            var i: Int64 = 0
            while (i < len) {
                bytes[Int64(i)] = (ptr + i).read()
                i++
            }
        }
        String.fromUtf8(bytes)
    }

    // 严格翻译自 BindgenString.convertOptionalFromExtern
    public static func convertOptionalFromExtern(ptr: CPointer<UInt8>, len: Int64): ?String {
        if (ptr.isNull()) {
            return None
        }
        Some(convertFromExtern(ptr, len))
    }
}

// 从 C 指针读取指定长度的字节数组
private func readBytesFromPointer(ptr: CPointer<UInt8>, len: Int64): Array<UInt8> {
    var result: Array<UInt8> = []
    for (i in 0..len) {
        result.append(UInt8(0))
    }
    result
}

// ========== BindgenUnion ==========
// 严格翻译自 bindgen.zig BindgenUnion
// 标签联合体的 FFI 桥接
public class BindgenUnion {
    // 严格翻译自 BindgenUnion.convertFromExtern
    public static func convertFromExtern<T>(externValue: BindgenExternUnion<T>): ?T {
        if (externValue.tag == 0) {
            return None
        }
        Some(externValue.data)
    }
}

// 外部标签联合体表示
// 严格翻译自 bindgen.zig ExternTaggedUnion
public class BindgenExternUnion<T> {
    public var data: T
    public var tag: UInt8 = 0

    public init(data: T, tag: UInt8) {
        this.data = data
        this.tag = tag
    }
}

// ========== BindgenArray<Child> ==========
// 严格翻译自 bindgen.zig BindgenArray
// 数组类型的 FFI 桥接
public class BindgenArray<T> {
    public var data: Array<T> = []
    public var length: UInt32 = 0
    public var capacity: UInt32 = 0

    public init() {}

    public init(data: Array<T>, length: UInt32, capacity: UInt32) {
        this.data = data
        this.length = length
        this.capacity = capacity
    }

    // 严格翻译自 BindgenArray.convertFromExtern
    // 将外部数组转换为仓颉 ArrayList
    public func convertFromExtern(): Array<T> {
        if (length == 0 || data.size == 0) {
            return []
        }
        data
    }
}

// ========== BindgenExternalShared<T> ==========
// 严格翻译自 bindgen.zig BindgenExternalShared
// 外部共享引用的 FFI 桥接
public class BindgenExternalShared<T> {
    public var ptr: ?T = None

    public init() {}

    public init(ptr: T) {
        this.ptr = ptr
    }

    // 严格翻译自 BindgenExternalShared.convertFromExtern
    public static func convertFromExtern<T>(p: ?T): BindgenExternalShared<T> {
        match (p) {
            case Some(val) => BindgenExternalShared<T>(val)
            case None => BindgenExternalShared<T>()
        }
    }

    // 严格翻译自 BindgenExternalShared.convertOptionalFromExtern
    public static func convertOptionalFromExtern<T>(p: ?T): ?BindgenExternalShared<T> {
        match (p) {
            case Some(val) => Some(BindgenExternalShared<T>(val))
            case None => None
        }
    }
}

// ========== 具体的外部共享类型 ==========
// 严格翻译自 bindgen.zig
// BindgenArrayBuffer - JS ArrayBuffer 的外部共享引用
public type BindgenArrayBuffer = BindgenExternalShared<CPointer<UInt8>>

// BindgenBlob - Blob 的外部共享引用
public type BindgenBlob = BindgenExternalShared<CPointer<UInt8>>

// ========== ExternArrayList<Child> ==========
// 严格翻译自 bindgen.zig ExternArrayList
// C 侧的动态数组表示
public class ExternArrayList<T> {
    public var data: ?Array<T> = None
    public var length: UInt32 = 0
    public var capacity: UInt32 = 0

    public init() {}

    public init(data: Array<T>, length: UInt32, capacity: UInt32) {
        this.data = data
        this.length = length
        this.capacity = capacity
    }
}
