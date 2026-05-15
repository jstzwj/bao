// 严格翻译自: src/jsc/JSRuntimeType.zig (16行)
// JavaScriptCore JSRuntimeType - JavaScript 运行时值类型枚举

package bao_jsc

// ========== JSRuntimeType ==========
// 严格翻译自 JSRuntimeType.zig
// 表示 JavaScript 运行时值类型
// 这些标志位用于描述 JSValue 的运行时类型
//
// 原始 Zig 代码:
//   pub const JSRuntimeType = enum(u16) {
//       Nothing = 0x0,
//       Function = 0x1,
//       Undefined = 0x2,
//       Null = 0x4,
//       Boolean = 0x8,
//       AnyInt = 0x10,
//       Number = 0x20,
//       String = 0x40,
//       Object = 0x80,
//       Symbol = 0x100,
//       BigInt = 0x200,
//       _,
//   };
public enum JSRuntimeType {
}
    }

    // 获取原始值
    public func toUInt16() -> UInt16 {
        match (this) {
            | Nothing => 0x0000
            | Function => 0x0001
            | Undefined => 0x0002
            | Null => 0x0004
            | Boolean => 0x0008
            | AnyInt => 0x0010
            | Number => 0x0020
            | String => 0x0040
            | Object => 0x0080
            | Symbol => 0x0100
            | BigInt => 0x0200
            | Unknown => 0xFFFF
        }
    }

    // 是否为 Nothing
    public func isNothing() -> Bool {
        this == Nothing
    }

    // 是否为函数类型
    public func isFunction() -> Bool {
        this == Function
    }

    // 是否为 undefined
    public func isUndefined() -> Bool {
        this == Undefined
    }

    // 是否为 null
    public func isNull() -> Bool {
        this == Null
    }

    // 是否为布尔类型
    public func isBoolean() -> Bool {
        this == Boolean
    }

    // 是否为数字类型 (包含 AnyInt 和 Number)
    public func isNumber() -> Bool {
        this == Number || this == AnyInt
    }

    // 是否为字符串类型
    public func isString() -> Bool {
        this == String
    }

    // 是否为对象类型
    public func isObject() -> Bool {
        this == Object
    }

    // 是否为 Symbol 类型
    public func isSymbol() -> Bool {
        this == Symbol
    }

    // 是否为 BigInt 类型
    public func isBigInt() -> Bool {
        this == BigInt
    }
}
