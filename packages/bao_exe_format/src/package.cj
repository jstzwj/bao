// bao_exe_format - 可执行文件格式解析
// 严格翻译自: src/exe_format/lib.rs, src/exe_format/elf.rs, src/exe_format/elf.zig
//              src/exe_format/macho.zig, src/exe_format/macho.rs
//              src/exe_format/pe.zig, src/exe_format/pe.rs
//
// 本模块解析可执行文件格式 (ELF, Mach-O, PE) 以确定:
//   - 文件是否为有效可执行文件
//   - 目标架构 (x86_64, arm64 等)
//   - 目标操作系统
//   - 是否为位置无关可执行文件 (PIE)
//   - 入口点偏移量
package bao_exe_format

import bao_core.*

// ============================================================================
// 模块重导出
// ============================================================================

// 可执行文件格式检测 - 严格翻译自 src/exe_format/macho.zig utils + src/exe_format/pe.zig utils
public import bao_exe_format.exe_format.*

// Mach-O 格式解析 - 严格翻译自 src/exe_format/macho.zig + macho.rs
public import bao_exe_format.macho.*

// PE/COFF 格式解析 - 严格翻译自 src/exe_format/pe.zig + pe.rs
public import bao_exe_format.pe.*
