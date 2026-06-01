// 严格翻译自: src/libarchive/libarchive.zig
// libarchive C 库的仓颉绑定 - tar.gz 归档读取/写入/解压
// 注意: ArchiveResult, BufferReadStream, ExtractOptions, Archiver, Plucker
//       已在 package.cj 中声明, 此文件仅包含额外类型

package bao_libarchive

import std.collection.*

// ============================================================================
// Seek - 文件定位方式
// 严格翻译自: libarchive.zig:5-9
//   pub const Seek = enum(c_int) { set, current, end }
// ============================================================================

/// 文件定位方式
public enum Seek {
    | Set       // SEEK_SET = 0
    | Current   // SEEK_CUR = 1
    | End       // SEEK_END = 2

    public operator func == (rhs: Seek): Bool {
        match (this) {
            case Set => match (rhs) { case Set => true; case _ => false }
            case Current => match (rhs) { case Current => true; case _ => false }
            case End => match (rhs) { case End => true; case _ => false }
        }
    }
    public operator func != (rhs: Seek): Bool {
        !(this == rhs)
    }
}
