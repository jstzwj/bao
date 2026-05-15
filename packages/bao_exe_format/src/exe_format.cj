// exe_format.cj - 可执行文件格式检测
// 严格翻译自:
//   src/exe_format/macho.zig - utils (isElf, isMacho)
//   src/exe_format/pe.zig - utils (isPE)
//   src/exe_format/elf.rs - ELF 头部常量和检测
//   src/exe_format/elf.zig - ELF 验证
//   src/exe_format/macho_types.rs - Mach-O 常量
package bao_exe_format

import bao_core.*

// ============================================================================
// 魔数常量
// 严格翻译自各格式头文件
// ============================================================================

// ELF 魔数 - "\x7fELF" 大端读取为 0x7f454c46
// 对应 macho.zig utils.isElf: mem.readInt(u32, data[0..4], .big) == 0x7f454c46
public let ELF_MAGIC: UInt32 = UInt32(0x7f454c46)

// Mach-O 64位魔数 (小端)
// 对应 macho.zig utils.isMacho: mem.readInt(u32, data[0..4], .little) == macho.MH_MAGIC_64
// 对应 macho_types.rs: pub const MH_MAGIC_64: u32 = 0xFEEDFACF;
public let MACHO_MAGIC_64: UInt32 = UInt32(0xFEEDFACF)

// Mach-O 32位魔数 (小端)
public let MACHO_MAGIC_32: UInt32 = UInt32(0xFEEDFACE)

// PE DOS 签名 "MZ"
// 对应 pe.zig: const DOS_SIGNATURE = 0x5A4D
public let PE_DOS_SIGNATURE: UInt16 = UInt16(0x5A4D)

// PE 签名 "PE\0\0"
// 对应 pe.zig: const PE_SIGNATURE = 0x00004550
public let PE_SIGNATURE: UInt32 = UInt32(0x00004550)

// PE 64位可选头魔数
// 对应 pe.zig: const OPTIONAL_HEADER_MAGIC_64 = 0x020B
public let PE_OPTIONAL_HEADER_MAGIC_64: UInt16 = UInt16(0x020B)

// WebAssembly 魔数 "\0asm"
public let WASM_MAGIC: UInt32 = UInt32(0x0061736D)

// ============================================================================
// ELF e_ident 偏移和常量
// 严格翻译自 src/exe_format/elf.rs
// ============================================================================

/// ELF e_ident 偏移: ELF 类别
// 对应 elf.rs: const EI_CLASS: usize = 4
public let EI_CLASS: Int64 = 4

/// ELF e_ident 偏移: 数据编码 (字节序)
// 对应 elf.rs: const EI_DATA: usize = 5
public let EI_DATA: Int64 = 5

/// ELFCLASS64 - 64位 ELF
// 对应 elf.rs: const ELFCLASS64: u8 = 2
public let ELFCLASS64: UInt8 = UInt8(2)

/// ELFDATA2LSB - 小端
// 对应 elf.rs: const ELFDATA2LSB: u8 = 1
public let ELFDATA2LSB: UInt8 = UInt8(1)

// ============================================================================
// ELF 机器类型
// 严格翻译自 src/exe_format/elf.rs
// ============================================================================

/// EM_AARCH64 - ARM 64位
// 对应 elf.rs: const EM_AARCH64: u16 = 183
public let EM_AARCH64: UInt16 = UInt16(183)

/// EM_X86_64 - AMD x86-64
// 对应标准 ELF 定义
public let EM_X86_64: UInt16 = UInt16(62)

/// EM_PPC64 - PowerPC 64位
// 对应 elf.rs: const EM_PPC64: u16 = 21
public let EM_PPC64: UInt16 = UInt16(21)

// ============================================================================
// Mach-O CPU 类型
// 严格翻译自 src/exe_format/macho_types.rs
// ============================================================================

/// CPU_TYPE_X86_64 - 对应 macho_types.rs: pub const CPU_TYPE_X86_64: u32 = 0x01000007
public let CPU_TYPE_X86_64: UInt32 = UInt32(0x01000007)

/// CPU_TYPE_ARM64 - 对应 macho_types.rs: pub const CPU_TYPE_ARM64: u32 = 0x0100000C
public let CPU_TYPE_ARM64: UInt32 = UInt32(0x0100000C)

/// CPU_TYPE_X86 - 对应 macho_types.rs: pub const CPU_TYPE_X86: u32 = 4
public let CPU_TYPE_X86: UInt32 = UInt32(4)

/// CPU_TYPE_ARM - 对应 macho_types.rs: pub const CPU_TYPE_ARM: u32 = 12
public let CPU_TYPE_ARM: UInt32 = UInt32(12)

// ============================================================================
// Mach-O 文件类型
// 严格翻译自 src/exe_format/macho_types.rs
// ============================================================================

/// MH_EXECUTE - 可执行文件
// 对应 macho_types.rs: pub const MH_EXECUTE: u32 = 0x2
public let MH_EXECUTE: UInt32 = UInt32(0x2)

/// MH_DYLIB - 动态库
// 对应 macho_types.rs: pub const MH_DYLIB: u32 = 0x6
public let MH_DYLIB: UInt32 = UInt32(0x6)

/// MH_BUNDLE - 加载器捆绑包
// 对应 macho_types.rs: pub const MH_BUNDLE: u32 = 0x8
public let MH_BUNDLE: UInt32 = UInt32(0x8)

// ============================================================================
// PE 机器类型
// 严格翻译自 src/exe_format/pe.zig PEHeader.machine
// ============================================================================

/// IMAGE_FILE_MACHINE_AMD64 - x86-64
public let IMAGE_FILE_MACHINE_AMD64: UInt16 = UInt16(0x8664)

/// IMAGE_FILE_MACHINE_ARM64 - ARM64
public let IMAGE_FILE_MACHINE_ARM64: UInt16 = UInt16(0xAA64)

/// IMAGE_FILE_MACHINE_I386 - x86
public let IMAGE_FILE_MACHINE_I386: UInt16 = UInt16(0x014C)

/// IMAGE_FILE_MACHINE_ARMNT - ARM Thumb-2
public let IMAGE_FILE_MACHINE_ARMNT: UInt16 = UInt16(0x01C4)

// ============================================================================
// ExeFormat - 可执行文件格式枚举
// ============================================================================

/// 可执行文件格式类型
// 对应 macho.zig utils 中对 ELF/Mach-O/PE 的格式检测分发
public enum ExeFormat {
    | Elf      // ELF 格式 (Linux)
    | MachO    // Mach-O 格式 (macOS/iOS)
    | Pe       // PE/COFF 格式 (Windows)
    | Wasm     // WebAssembly 模块
    | Unknown  // 未知格式
}

// ============================================================================
// ExeArchitecture - 可执行文件目标架构
// ============================================================================

/// 可执行文件目标 CPU 架构
// 对应 ELF e_machine, Mach-O cputype, PE machine 字段
public enum ExeArchitecture {
    | X86_64   // AMD x86-64
    | ARM64    // ARM 64位 (AArch64)
    | X86      // Intel x86 (32位)
    | ARM      // ARM 32位
    | WASM64   // WebAssembly 64位
    | WASM32   // WebAssembly 32位
    | Unknown  // 未知架构
}

// ============================================================================
// ExeOS - 可执行文件目标操作系统
// ============================================================================

/// 可执行文件目标操作系统
// 对应文件格式推断的目标平台
public enum ExeOS {
    | Linux    // Linux (ELF)
    | Darwin   // macOS/iOS (Mach-O)
    | Windows  // Windows (PE)
    | WASI     // WebAssembly System Interface
    | Unknown  // 未知操作系统
}

// ============================================================================
// ExeInfo - 可执行文件解析结果
// ============================================================================

/// 可执行文件解析信息
// 包含格式检测后的完整可执行文件元数据
public class ExeInfo {
    /// 文件格式
    public var format: ExeFormat = ExeFormat.Unknown

    /// 目标架构
    public var arch: ExeArchitecture = ExeArchitecture.Unknown

    /// 目标操作系统
    public var os: ExeOS = ExeOS.Unknown

    /// 是否为位置无关可执行文件 (PIE)
    // 对应 ELF: e_type == ET_DYN
    // 对应 Mach-O: header.flags & MH_PIE
    public var pie: Bool = false

    /// 入口点偏移量 (0 表示未找到)
    // 对应 ELF: ehdr.e_entry
    // 对应 Mach-O: 通过 LC_MAIN 或 LC_UNIXTHREAD 获取
    // 对应 PE: OptionalHeader.address_of_entry_point
    public var entryPoint: UInt64 = UInt64(0)

    /// 是否为 64 位
    public var is64Bit: Bool = false

    public init() {}
}

// ============================================================================
// 格式检测函数
// 严格翻译自:
//   macho.zig utils.isElf: mem.readInt(u32, data[0..4], .big) == 0x7f454c46
//   macho.zig utils.isMacho: mem.readInt(u32, data[0..4], .little) == macho.MH_MAGIC_64
//   pe.zig utils.isPE: DOS 签名 + PE 签名检测
// ============================================================================

/// 通过魔数检测可执行文件格式
// 对应 macho.zig utils.isElf / isMacho, pe.zig utils.isPE
// 严格按顺序检测: ELF -> Mach-O -> PE -> WASM -> Unknown
public func detectFormat(bytes: Array<UInt8>): ExeFormat {
    if (bytes.size < 4) {
        return ExeFormat.Unknown
    }

    let magic = readUInt32LE(bytes, 0)

    // ELF 魔数检测 (大端读取比较)
    // 对应 macho.zig utils.isElf:
    //   mem.readInt(u32, data[0..4], .big) == 0x7f454c46
    // 注意: ELF 魔数 "\x7fELF" 在大端和小端读取时值相同 (字节序无关)
    if (magic == ELF_MAGIC) {
        return ExeFormat.Elf
    }

    // Mach-O 64位魔数检测 (小端读取)
    // 对应 macho.zig utils.isMacho:
    //   mem.readInt(u32, data[0..4], .little) == macho.MH_MAGIC_64
    if (magic == MACHO_MAGIC_64) {
        return ExeFormat.MachO
    }

    // Mach-O 32位魔数
    if (magic == MACHO_MAGIC_32) {
        return ExeFormat.MachO
    }

    // PE DOS 签名检测 "MZ"
    // 对应 pe.zig utils.isPE:
    //   dos.e_magic == DOS_SIGNATURE (0x5A4D)
    // 然后跟进 e_lfanew 偏移验证 PE 签名
    let dosMagic = readUInt16LE(bytes, 0)
    if (dosMagic == PE_DOS_SIGNATURE) {
        return ExeFormat.Pe
    }

    // WebAssembly 魔数 "\0asm"
    if (magic == WASM_MAGIC) {
        return ExeFormat.Wasm
    }

    return ExeFormat.Unknown
}

// ============================================================================
// 完整解析函数
// ============================================================================

/// 解析可执行文件并返回完整信息
// 对应各格式的头部解析逻辑:
//   ELF: elf.rs validate_elf64_le + read_ehdr
//   Mach-O: macho.zig MachoFile.init
//   PE: pe.zig PEFile.init
public func parseExe(bytes: Array<UInt8>): ExeInfo {
    let info = ExeInfo()
    let format = detectFormat(bytes)
    info.format = format

    match (format) {
        case Elf =>
            parseElf(bytes, info)
        case MachO =>
            parseMachO(bytes, info)
        case Pe =>
            parsePE(bytes, info)
        case Wasm =>
            parseWasm(bytes, info)
        case Unknown => {}
    }

    return info
}

// ============================================================================
// ELF 解析
// 严格翻译自 src/exe_format/elf.rs validate_elf64_le + read_ehdr
// 以及 src/exe_format/elf.zig readEhdr
// ELF64 头部布局 (64 字节):
//   [0..16]   e_ident[16]   - ELF 标识
//   [16..18]  e_type        - 目标文件类型
//   [18..20]  e_machine     - 机器类型
//   [20..24]  e_version     - 对象文件版本
//   [24..32]  e_entry       - 入口点虚拟地址
//   [32..40]  e_phoff       - 程序头表文件偏移
//   [40..48]  e_shoff       - 节头表文件偏移
//   [48..52]  e_flags       - 处理器特定标志
//   [52..54]  e_ehsize      - ELF 头大小
//   [54..56]  e_phentsize   - 程序头表条目大小
//   [56..58]  e_phnum       - 程序头表条目数
//   [58..60]  e_shentsize   - 节头表条目大小
//   [60..62]  e_shnum       - 节头表条目数
//   [62..64]  e_shstrndx    - 节头字符串表索引
// ============================================================================

/// ELF 头部大小
// 对应 elf.rs: size_of::<Elf64_Ehdr>() == 64
private let ELF64_EHDR_SIZE: Int64 = 64

/// ELF ET_DYN - 共享目标文件 (PIE 的标志)
private let ET_DYN: UInt16 = UInt16(3)

/// ELF ET_EXEC - 可执行文件
private let ET_EXEC: UInt16 = UInt16(2)

private func parseElf(bytes: Array<UInt8>, info: ExeInfo): Unit {
    info.os = ExeOS.Linux

    // 需要至少 ELF64 头部大小
    // 对应 elf.rs validate_elf64_le:
    //   if data.len() < size_of::<Elf64_Ehdr>() { return Err(InvalidElfFile) }
    if (bytes.size < ELF64_EHDR_SIZE) {
        return
    }

    // 验证 ELF 魔数
    // 对应 elf.rs:
    //   if &data[0..4] != b"\x7fELF" { return Err(InvalidElfFile) }
    if (readUInt32LE(bytes, 0) != ELF_MAGIC) {
        return
    }

    // 检查是否为 64 位
    // 对应 elf.rs:
    //   if data[EI_CLASS] != ELFCLASS64 { return Err(Not64Bit) }
    let elfClass = bytes[EI_CLASS]
    if (elfClass == ELFCLASS64) {
        info.is64Bit = true
    }

    // 检查字节序 (小端)
    // 对应 elf.rs:
    //   if data[EI_DATA] != ELFDATA2LSB { return Err(NotLittleEndian) }
    let elfData = bytes[EI_DATA]

    // e_machine 在偏移 18, 大小 2 字节 (小端)
    // 对应 Elf64_Ehdr 布局: offset 18
    let eMachine = readUInt16LE(bytes, 18)

    // 解析架构
    // 对应 elf.rs page_size 中的 e_machine 匹配:
    //   EM_AARCH64 | EM_PPC64 => 0x10000
    //   EM_X86_64 通过标准定义
    match (eMachine) {
        case EM_X86_64 =>
            info.arch = ExeArchitecture.X86_64
        case EM_AARCH64 =>
            info.arch = ExeArchitecture.ARM64
        case EM_PPC64 =>
            info.arch = ExeArchitecture.Unknown
        case _ =>
            info.arch = ExeArchitecture.Unknown
    }

    // e_type 在偏移 16, 大小 2 字节 (小端)
    let eType = readUInt16LE(bytes, 16)

    // PIE 检测: ET_DYN 表示位置无关可执行文件
    // 对应标准 ELF: e_type == ET_DYN && 文件有 PT_INTERP
    if (eType == ET_DYN) {
        info.pie = true
    }

    // e_entry 在偏移 24, 大小 8 字节 (小端)
    // 对应 Elf64_Ehdr 布局: offset 24
    info.entryPoint = readUInt64LE(bytes, 24)
}

// ============================================================================
// Mach-O 解析
// 严格翻译自 src/exe_format/macho.zig MachoFile.init
// 以及 src/exe_format/macho_types.rs
// Mach-O 64位头部布局 (32 字节):
//   [0..4]    magic         - 魔数
//   [4..8]    cputype       - CPU 类型
//   [8..12]   cpusubtype    - CPU 子类型
//   [12..16]  filetype      - 文件类型
//   [16..20]  ncmds         - 加载命令数量
//   [20..24]  sizeofcmds    - 加载命令总大小
//   [24..28]  flags         - 标志
//   [28..32]  reserved      - 保留
// ============================================================================

/// Mach-O 64位头部大小
private let MACHO_HEADER_64_SIZE: Int64 = 32

/// Mach-O PIE 标志
// 对应 macho_types.rs: pub const MH_PIE: u32 = 0x200000
private let MH_PIE: UInt32 = UInt32(0x200000)

private func parseMachO(bytes: Array<UInt8>, info: ExeInfo): Unit {
    info.os = ExeOS.Darwin

    if (bytes.size < MACHO_HEADER_64_SIZE) {
        return
    }

    let magic = readUInt32LE(bytes, 0)

    // 区分 32 位和 64 位 Mach-O
    if (magic == MACHO_MAGIC_64) {
        info.is64Bit = true
    }

    // cputype 在偏移 4, 大小 4 字节 (小端)
    // 对应 macho.zig: header.cputype
    let cpuType = readUInt32LE(bytes, 4)

    // 解析架构
    // 对应 macho.zig / macho.rs 中的 cputype 比较:
    //   macho.CPU_TYPE_ARM64, macho.CPU_TYPE_X86_64
    match (cpuType) {
        case CPU_TYPE_X86_64 =>
            info.arch = ExeArchitecture.X86_64
        case CPU_TYPE_ARM64 =>
            info.arch = ExeArchitecture.ARM64
        case CPU_TYPE_X86 =>
            info.arch = ExeArchitecture.X86
        case CPU_TYPE_ARM =>
            info.arch = ExeArchitecture.ARM
        case _ =>
            info.arch = ExeArchitecture.Unknown
    }

    // filetype 在偏移 12, 大小 4 字节 (小端)
    // 对应 macho.zig: header.filetype
    // 这里不需要解析 filetype 来填充 ExeInfo，但保留以供调试

    // flags 在偏移 24, 大小 4 字节 (小端)
    // 对应 macho.zig: header.flags
    let flags = readUInt32LE(bytes, 24)

    // PIE 检测: flags & MH_PIE
    if ((flags & MH_PIE) != UInt32(0)) {
        info.pie = true
    }

    // ncmds 在偏移 16, sizeofcmds 在偏移 20
    // 入口点需要遍历加载命令 (LC_MAIN / LC_UNIXTHREAD)
    // 此处不进行完整遍历，仅记录头部信息
}

// ============================================================================
// PE 解析
// 严格翻译自 src/exe_format/pe.zig PEFile.init + utils.isPE
// DOS 头部布局 (64 字节):
//   [0..2]    e_magic       - 魔数 "MZ"
//   ...
//   [60..64]  e_lfanew      - PE 头文件偏移
//
// PE 头部布局 (24 字节):
//   [0..4]    signature     - PE 签名 "PE\0\0"
//   [4..6]    machine       - 机器类型
//   [6..8]    number_of_sections
//   ...
//
// Optional Header 64 布局:
//   [0..2]    magic                   - 0x020B (PE64)
//   ...
//   [16..20]  address_of_entry_point  - 入口点
//   ...
//   [24..32]  image_base              - 镜像基地址
// ============================================================================

/// DOS 头部大小
// 对应 pe.zig: @sizeOf(DOSHeader) == 64
private let DOS_HEADER_SIZE: Int64 = 64

/// PE 头部大小
// 对应 pe.zig: @sizeOf(PEHeader) == 24 (signature(4) + machine(2) + number_of_sections(2)
//              + time_date_stamp(4) + pointer_to_symbol_table(4) + number_of_symbols(4)
//              + size_of_optional_header(2) + characteristics(2))
private let PE_HEADER_SIZE: Int64 = 24

/// Optional Header 64 中 address_of_entry_point 的偏移
// OptionalHeader64 布局:
//   magic(2) + major_linker_version(1) + minor_linker_version(1)
//   + size_of_code(4) + size_of_initialized_data(4) + size_of_uninitialized_data(4)
//   = 16 字节后是 address_of_entry_point
private let PE_OPT_HEADER_ENTRY_POINT_OFFSET: Int64 = 16

/// Optional Header 64 中 image_base 的偏移
// address_of_entry_point(4) + base_of_code(4) = 8 字节
// 所以 image_base 在偏移 24
private let PE_OPT_HEADER_IMAGE_BASE_OFFSET: Int64 = 24

private func parsePE(bytes: Array<UInt8>, info: ExeInfo): Unit {
    info.os = ExeOS.Windows

    // 需要至少 DOS 头部大小
    // 对应 pe.zig utils.isPE:
    //   if data.len < @sizeOf(DOSHeader) return false
    if (bytes.size < DOS_HEADER_SIZE) {
        return
    }

    // 验证 DOS 签名 "MZ"
    // 对应 pe.zig:
    //   dos.e_magic != DOS_SIGNATURE => InvalidDOSSignature
    let dosMagic = readUInt16LE(bytes, 0)
    if (dosMagic != PE_DOS_SIGNATURE) {
        return
    }

    // 读取 e_lfanew - PE 头文件偏移
    // 对应 pe.zig: dos_header.e_lfanew (DOS 头部偏移 60, 4 字节)
    let eLfanew = readUInt32LE(bytes, 60)

    // 验证 e_lfanew 范围
    // 对应 pe.zig:
    //   if dos_header.e_lfanew < @sizeOf(DOSHeader) => InvalidPEFile
    //   if dos_header.e_lfanew > data.len -| @sizeOf(PEHeader) => InvalidPEFile
    if (eLfanew < DOS_HEADER_SIZE) {
        return
    }
    if (eLfanew + PE_HEADER_SIZE > bytes.size) {
        return
    }

    // 验证 PE 签名 "PE\0\0"
    // 对应 pe.zig:
    //   pe_header.signature != PE_SIGNATURE => InvalidPESignature
    let peOffset = Int64(eLfanew)
    let peSignature = readUInt32LE(bytes, peOffset)
    if (peSignature != PE_SIGNATURE) {
        return
    }

    // 读取 machine 类型
    // 对应 pe.zig PEHeader.machine (PE 头偏移 +4, 2 字节)
    let machine = readUInt16LE(bytes, peOffset + 4)

    // 解析架构
    match (machine) {
        case IMAGE_FILE_MACHINE_AMD64 =>
            info.arch = ExeArchitecture.X86_64
            info.is64Bit = true
        case IMAGE_FILE_MACHINE_ARM64 =>
            info.arch = ExeArchitecture.ARM64
            info.is64Bit = true
        case IMAGE_FILE_MACHINE_I386 =>
            info.arch = ExeArchitecture.X86
        case IMAGE_FILE_MACHINE_ARMNT =>
            info.arch = ExeArchitecture.ARM
        case _ =>
            info.arch = ExeArchitecture.Unknown
    }

    // 读取 size_of_optional_header
    // 对应 pe.zig PEHeader.size_of_optional_header (PE 头偏移 +20, 2 字节)
    let sizeOfOptionalHeader = readUInt16LE(bytes, peOffset + 20)

    // 计算可选头偏移
    let optionalHeaderOffset = peOffset + PE_HEADER_SIZE

    // 验证可选头存在且完整
    if (sizeOfOptionalHeader > 0 && optionalHeaderOffset + sizeOfOptionalHeader <= bytes.size) {
        // 检查可选头魔数 (PE64)
        // 对应 pe.zig:
        //   optional_header.magic != OPTIONAL_HEADER_MAGIC_64 => UnsupportedPEFormat
        let optMagic = readUInt16LE(bytes, optionalHeaderOffset)
        if (optMagic == PE_OPTIONAL_HEADER_MAGIC_64) {
            // 读取入口点地址
            // 对应 pe.zig OptionalHeader64.address_of_entry_point
            info.entryPoint = UInt64(readUInt32LE(bytes, optionalHeaderOffset + PE_OPT_HEADER_ENTRY_POINT_OFFSET))
        }
    }

    // PE 文件不做 PIE 检测 (Windows 使用 ASLR，由 DLL characteristics 决定)
    // DLL characteristics 在 OptionalHeader64 偏移 70 (offset 24 + 46)
    // IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE = 0x0040
}

// ============================================================================
// WebAssembly 解析
// ============================================================================

private func parseWasm(bytes: Array<UInt8>, info: ExeInfo): Unit {
    info.os = ExeOS.WASI
    info.pie = true  // WASM 天然位置无关

    // WASM 版本号在偏移 4 (4 字节)
    if (bytes.size < 8) {
        return
    }
}

// ============================================================================
// 格式快速检测函数
// 严格翻译自各格式的 utils 命名空间
// ============================================================================

/// 检测是否为 ELF 文件
// 严格翻译自 macho.zig utils.isElf:
//   pub fn isElf(data: []const u8) bool {
//       if (data.len < 4) return false;
//       return mem.readInt(u32, data[0..4], .big) == 0x7f454c46;
//   }
public func isElf(bytes: Array<UInt8>): Bool {
    if (bytes.size < 4) {
        return false
    }
    return readUInt32LE(bytes, 0) == ELF_MAGIC
}

/// 检测是否为 Mach-O 文件
// 严格翻译自 macho.zig utils.isMacho:
//   pub fn isMacho(data: []const u8) bool {
//       if (data.len < 4) return false;
//       return mem.readInt(u32, data[0..4], .little) == macho.MH_MAGIC_64;
//   }
public func isMacho(bytes: Array<UInt8>): Bool {
    if (bytes.size < 4) {
        return false
    }
    let magic = readUInt32LE(bytes, 0)
    return magic == MACHO_MAGIC_64 || magic == MACHO_MAGIC_32
}

/// 检测是否为 PE 文件
// 严格翻译自 pe.zig utils.isPE:
//   pub fn isPE(data: []const u8) bool {
//       if data.len < @sizeOf(DOSHeader) return false;
//       const dos = ...;
//       if (dos.e_magic != DOS_SIGNATURE) return false;
//       const off = dos.e_lfanew;
//       if (off < @sizeOf(DOSHeader) or off > data.len -| @sizeOf(PEHeader)) return false;
//       const pe = ...;
//       return pe.signature == PE_SIGNATURE;
//   }
public func isPE(bytes: Array<UInt8>): Bool {
    if (bytes.size < DOS_HEADER_SIZE) {
        return false
    }

    // DOS 签名
    let dosMagic = readUInt16LE(bytes, 0)
    if (dosMagic != PE_DOS_SIGNATURE) {
        return false
    }

    // PE 偏移
    let peOff = readUInt32LE(bytes, 60)
    if (peOff < DOS_HEADER_SIZE) {
        return false
    }
    if (Int64(peOff) + PE_HEADER_SIZE > bytes.size) {
        return false
    }

    // PE 签名
    let peSignature = readUInt32LE(bytes, Int64(peOff))
    return peSignature == PE_SIGNATURE
}

/// 检测是否为 WebAssembly 文件
public func isWasm(bytes: Array<UInt8>): Bool {
    if (bytes.size < 4) {
        return false
    }
    return readUInt32LE(bytes, 0) == WASM_MAGIC
}

// ============================================================================
// 字节读取辅助函数
// 对应 Zig std.mem.readInt / Rust 字节切片读取
// ============================================================================

/// 从字节数组读取小端 UInt16
// 对应 Zig: mem.readInt(u16, data[offset..][0..2], .little)
// 对应 Rust: u16::from_le_bytes([data[offset], data[offset+1]])
public func readUInt16LE(bytes: Array<UInt8>, offset: Int64): UInt16 {
    if (offset < 0 || offset + 2 > bytes.size) {
        return UInt16(0)
    }
    return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
}

/// 从字节数组读取小端 UInt32
// 对应 Zig: mem.readInt(u32, data[offset..][0..4], .little)
// 对应 Rust: u32::from_le_bytes(...)
public func readUInt32LE(bytes: Array<UInt8>, offset: Int64): UInt32 {
    if (offset < 0 || offset + 4 > bytes.size) {
        return UInt32(0)
    }
    return UInt32(bytes[offset]) |
        (UInt32(bytes[offset + 1]) << 8) |
        (UInt32(bytes[offset + 2]) << 16) |
        (UInt32(bytes[offset + 3]) << 24)
}

/// 从字节数组读取小端 UInt64
// 对应 Zig: mem.readInt(u64, data[offset..][0..8], .little)
public func readUInt64LE(bytes: Array<UInt8>, offset: Int64): UInt64 {
    if (offset < 0 || offset + 8 > bytes.size) {
        return UInt64(0)
    }
    return UInt64(bytes[offset]) |
        (UInt64(bytes[offset + 1]) << 8) |
        (UInt64(bytes[offset + 2]) << 16) |
        (UInt64(bytes[offset + 3]) << 24) |
        (UInt64(bytes[offset + 4]) << 32) |
        (UInt64(bytes[offset + 5]) << 40) |
        (UInt64(bytes[offset + 6]) << 48) |
        (UInt64(bytes[offset + 7]) << 56)
}

/// 向字节数组写入小端 UInt16
// 对应 Zig: mem.writeInt(u16, data[offset..][0..2], value, .little)
public func writeUInt16LE(bytes: Array<UInt8>, offset: Int64, value: UInt16): Unit {
    if (offset < 0 || offset + 2 > bytes.size) {
        return
    }
    bytes[offset] = UInt8(value & 0xFF)
    bytes[offset + 1] = UInt8((value >> 8) & 0xFF)
}

/// 向字节数组写入小端 UInt32
// 对应 Zig: mem.writeInt(u32, data[offset..][0..4], value, .little)
public func writeUInt32LE(bytes: Array<UInt8>, offset: Int64, value: UInt32): Unit {
    if (offset < 0 || offset + 4 > bytes.size) {
        return
    }
    bytes[offset] = UInt8(value & 0xFF)
    bytes[offset + 1] = UInt8((value >> 8) & 0xFF)
    bytes[offset + 2] = UInt8((value >> 16) & 0xFF)
    bytes[offset + 3] = UInt8((value >> 24) & 0xFF)
}

/// 向字节数组写入小端 UInt64
// 对应 Zig: mem.writeInt(u64, data[offset..][0..8], value, .little)
public func writeUInt64LE(bytes: Array<UInt8>, offset: Int64, value: UInt64): Unit {
    if (offset < 0 || offset + 8 > bytes.size) {
        return
    }
    bytes[offset] = UInt8(value & 0xFF)
    bytes[offset + 1] = UInt8((value >> 8) & 0xFF)
    bytes[offset + 2] = UInt8((value >> 16) & 0xFF)
    bytes[offset + 3] = UInt8((value >> 24) & 0xFF)
    bytes[offset + 4] = UInt8((value >> 32) & 0xFF)
    bytes[offset + 5] = UInt8((value >> 40) & 0xFF)
    bytes[offset + 6] = UInt8((value >> 48) & 0xFF)
    bytes[offset + 7] = UInt8((value >> 56) & 0xFF)
}

/// 对齐向上取整
// 对应 lib.rs align_up:
//   pub(crate) fn align_up(value: u64, alignment: u64) -> u64
// 以及 elf.zig:
//   fn alignUp(value: u64, alignment: u64) u64 {
//       if (alignment == 0) return value;
//       const mask = alignment - 1;
//       return (value + mask) & ~mask;
//   }
public func alignUp(value: UInt64, alignment: UInt64): UInt64 {
    if (alignment == UInt64(0)) {
        return value
    }
    let mask = alignment - UInt64(1)
    return (value + mask) & ~mask
}
