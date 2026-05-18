// 严格翻译自: src/paths/path_char.rs
//   PathChar trait - 路径代码单元抽象 (u8/u16)
//   PathByte supertrait - 基础字节操作
//   提供对 u8 (UTF-8/WTF-8) 和 u16 (WTF-16) 的统一操作接口
//
// Bun 使用 comptime T: type 实现对 u8/u16 的泛型路径操作
// Rust 使用 trait PathChar + PathByte 实现同样的抽象
// 仓颉使用 interface 提供类似功能
package bao_path

import bao_core.*

// ============================================================================
// PathByte - 路径字节基础接口
// 严格翻译自: src/paths/path_char.rs - PathByte (bun_core::strings::PathByte)
//   trait PathByte: Copy + Eq + 'static {
//       fn from_u8(b: u8) -> Self;
//   }
// ============================================================================

/// 路径字节 - 对应 Bun PathByte
/// 提供从 u8 构造和基本比较操作
public interface PathByte <: Equatable<PathByte> & Hashable {
    /// 从 u8 构造
    func fromU8(b: UInt8): PathByte

    /// 转为 UInt8
    func toU8(): UInt8

    /// 是否为 ASCII
    func isAscii(): Bool
}

// ============================================================================
// PathUnit - 路径代码单元
// 严格翻译自: src/paths/path_char.rs - PathChar trait
//   pub trait PathChar: PathByte + Ord {
//       const IS_U16: bool;
//       fn as_u32(self) -> u32;
//       fn to_ascii(self) -> Option<u8>;
//       fn eq_ascii(self, c: u8) -> bool;
//       fn to_ascii_upper(self) -> Self;
//       fn is_ascii_alphabetic(self) -> bool;
//       fn lit(s: &'static [u8]) -> &'static [Self];
//       fn write_u8_part(dest: &mut [Self], part: &[u8]) -> usize;
//   }
//
// 仓颉当前只支持 POSIX (u8 路径)，不使用 u16 路径
// ============================================================================

/// 路径代码单元 - 对应 Bun PathChar
/// 封装对 u8/u16 路径代码单元的操作
public enum PathUnit {
    | U8(UInt8)
    | U16(UInt16)

    /// 是否为 U16 编码 (Windows WTF-16)
    /// 对应 Bun: const IS_U16: bool
    public func isU16(): Bool {
        match (this) {
            case U16(_) => true
            case U8(_) => false
        }
    }

    /// 扩展为 u32 (用于范围检查)
    /// 对应 Bun: fn as_u32(self) -> u32
    public func asU32(): UInt32 {
        match (this) {
            case U8(b) => UInt32(b)
            case U16(w) => UInt32(w)
        }
    }

    /// 转为 ASCII (如果不在 ASCII 范围则返回 None)
    /// 对应 Bun: fn to_ascii(self) -> Option<u8>
    public func toAscii(): ?UInt8 {
        match (this) {
            case U8(b) => Some(b)
            case U16(w) =>
                if (w < UInt16(128)) {
                    Some(UInt8(w))
                } else {
                    None
                }
        }
    }

    /// 与 ASCII 字节比较
    /// 对应 Bun: fn eq_ascii(self, c: u8) -> bool
    public func eqAscii(c: UInt8): Bool {
        match (this) {
            case U8(b) => b == c
            case U16(w) => w == UInt16(c)
        }
    }

    /// ASCII 大写转换
    /// 对应 Bun: fn to_ascii_upper(self) -> Self
    ///   match self.to_ascii() {
    ///       Some(b @ b'a'..=b'z') => Self::from_u8(b - 32),
    ///       _ => self,
    ///   }
    public func toAsciiUpper(): PathUnit {
        match (toAscii()) {
            case Some(b) =>
                if (b >= UInt8(97) && b <= UInt8(122)) {
                    PathUnit.U8(UInt8(b - UInt8(32)))
                } else {
                    this
                }
            case None => this
        }
    }

    /// 是否为 ASCII 字母
    /// 对应 Bun: fn is_ascii_alphabetic(self) -> bool
    public func isAsciiAlphabetic(): Bool {
        match (toAscii()) {
            case Some(b) =>
                (b >= UInt8(65) && b <= UInt8(90)) || (b >= UInt8(97) && b <= UInt8(122))
            case None => false
        }
    }

    /// 是否为数字
    /// 对应 Bun 中的 isDigit 辅助
    public func isDigit(): Bool {
        match (toAscii()) {
            case Some(b) => b >= UInt8(48) && b <= UInt8(57)
            case None => false
        }
    }

    /// 是否为字母或数字
    public func isAlphaNumeric(): Bool {
        isAsciiAlphabetic() || isDigit()
    }

    /// 从 u8 构造
    public static func fromU8(b: UInt8): PathUnit {
        PathUnit.U8(b)
    }

    /// 从 u16 构造
    public static func fromU16(w: UInt16): PathUnit {
        PathUnit.U16(w)
    }

    /// 转为字节 (如果可能)
    public func toByte(): ?UInt8 {
        match (this) {
            case U8(b) => Some(b)
            case U16(_) => None
        }
    }

    public func toString(): String {
        match (this) {
            case U8(b) => String(Rune(Int32(b)))
            case U16(w) => String(Rune(Int32(w)))
        }
    }
}

// ============================================================================
// PathChar 辅助函数
// 严格翻译自: src/paths/path_char.rs 中的 u8/u16 impl
// ============================================================================

/// 判断路径代码单元是否为路径分隔符
/// 对应 Bun 中 PathChar 的分隔符判断
public func pathUnitIsSeparator(unit: PathUnit, platform: Platform): Bool {
    match (unit) {
        case PathUnit.U8(b) => platform.isSeparator(b)
        case PathUnit.U16(w) =>
            let b = UInt8(if (w < UInt16(256)) { w } else { UInt16(0) })
            platform.isSeparator(b)
    }
}

/// 将路径代码单元转为大写
/// 对应 Bun PathChar::to_ascii_upper
public func pathUnitToUpper(unit: PathUnit): PathUnit {
    unit.toAsciiUpper()
}
