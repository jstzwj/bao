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
    | `Nothing`
    | Function
    | Undefined
    | Null
    | Boolean
    | AnyInt
    | Number
    | String
    | Object
    | Symbol
    | BigInt
    | Unknown

    public func toUInt16(): UInt16 {
        match (this) {
            case `Nothing` => return UInt16(0)
            case Function => return UInt16(1)
            case Undefined => return UInt16(2)
            case Null => return UInt16(4)
            case Boolean => return UInt16(8)
            case AnyInt => return UInt16(16)
            case Number => return UInt16(32)
            case String => return UInt16(64)
            case Object => return UInt16(128)
            case Symbol => return UInt16(256)
            case BigInt => return UInt16(512)
            case Unknown => return UInt16(65535)
        }
    }

    public func isNothing(): Bool { this == `Nothing` }
    public func isFunction(): Bool { this == Function }
    public func isUndefined(): Bool { this == Undefined }
    public func isNull(): Bool { this == Null }
    public func isBoolean(): Bool { this == Boolean }
    public func isNumber(): Bool { this == Number || this == AnyInt }
    public func isString(): Bool { this == String }
    public func isObject(): Bool { this == Object }
    public func isPrimitive(): Bool { this != Object && this != Function }
}
