// pe.cj - PE/COFF 格式解析 (Windows 可执行文件)
// 严格翻译自:
//   src/exe_format/pe.zig - PEFile 结构, DOS/PE/Optional 头部解析
//   src/exe_format/pe.rs - Rust 移植版本
package bao_exe_format

import bao_core.*

// ============================================================================
// PE 常量
// 严格翻译自 src/exe_format/pe.zig
// ============================================================================

/// PE 签名 "PE\0\0"
// 对应 pe.zig: const PE_SIGNATURE = 0x00004550
public let PE_SIG: UInt32 = UInt32(0x00004550)

/// DOS 签名 "MZ"
// 对应 pe.zig: const DOS_SIGNATURE = 0x5A4D
public let DOS_SIG: UInt16 = UInt16(0x5A4D)

/// PE64 可选头魔数
// 对应 pe.zig: const OPTIONAL_HEADER_MAGIC_64 = 0x020B
public let PE_OPT_MAGIC_64: UInt16 = UInt16(0x020B)

/// PE32 可选头魔数
public let PE_OPT_MAGIC_32: UInt16 = UInt16(0x010B)

// ============================================================================
// PE Section 特征常量
// 严格翻译自 src/exe_format/pe.zig
// ============================================================================

/// IMAGE_SCN_CNT_CODE - 节包含代码
// 对应 pe.zig: const IMAGE_SCN_CNT_CODE = 0x00000020
public let IMAGE_SCN_CNT_CODE: UInt32 = UInt32(0x00000020)

/// IMAGE_SCN_CNT_INITIALIZED_DATA - 节包含已初始化数据
// 对应 pe.zig: const IMAGE_SCN_CNT_INITIALIZED_DATA = 0x00000040
public let IMAGE_SCN_CNT_INITIALIZED_DATA: UInt32 = UInt32(0x00000040)

/// IMAGE_SCN_MEM_READ - 节可读
// 对应 pe.zig: const IMAGE_SCN_MEM_READ = 0x40000000
public let IMAGE_SCN_MEM_READ: UInt32 = UInt32(0x40000000)

/// IMAGE_SCN_MEM_WRITE - 节可写
// 对应 pe.zig: const IMAGE_SCN_MEM_WRITE = 0x80000000
public let IMAGE_SCN_MEM_WRITE: UInt32 = UInt32(0x80000000)

/// IMAGE_SCN_MEM_EXECUTE - 节可执行
// 对应 pe.zig: const IMAGE_SCN_MEM_EXECUTE = 0x20000000
public let IMAGE_SCN_MEM_EXECUTE: UInt32 = UInt32(0x20000000)

// ============================================================================
// PE 目录索引和 DLL 特征
// 严格翻译自 src/exe_format/pe.zig
// ============================================================================

/// IMAGE_DIRECTORY_ENTRY_SECURITY - 安全目录索引
// 对应 pe.zig: const IMAGE_DIRECTORY_ENTRY_SECURITY: usize = 4
public let IMAGE_DIRECTORY_ENTRY_SECURITY: Int64 = 4

/// IMAGE_DLLCHARACTERISTICS_FORCE_INTEGRITY
// 对应 pe.zig: const IMAGE_DLLCHARACTERISTICS_FORCE_INTEGRITY: u16 = 0x0080
public let IMAGE_DLLCHARACTERISTICS_FORCE_INTEGRITY: UInt16 = UInt16(0x0080)

/// IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE - ASLR/PIE
public let IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE: UInt16 = UInt16(0x0040)

// ============================================================================
// PE 机器类型 (重导出以便外部使用)
// ============================================================================

/// IMAGE_FILE_MACHINE_AMD64
// 对应 pe.zig PEHeader 中 machine 字段的标准值
public let PE_MACHINE_AMD64: UInt16 = UInt16(0x8664)

/// IMAGE_FILE_MACHINE_ARM64
public let PE_MACHINE_ARM64: UInt16 = UInt16(0xAA64)

/// IMAGE_FILE_MACHINE_I386
public let PE_MACHINE_I386: UInt16 = UInt16(0x014C)

/// IMAGE_FILE_MACHINE_ARMNT
public let PE_MACHINE_ARMNT: UInt16 = UInt16(0x01C4)

// ============================================================================
// PE DOS 头部结构
// 严格翻译自 src/exe_format/pe.zig DOSHeader
// DOSHeader 布局 (64 字节):
//   e_magic:     u16   offset 0
//   e_cblp:      u16   offset 2
//   e_cp:        u16   offset 4
//   e_crlc:      u16   offset 6
//   e_cparhdr:   u16   offset 8
//   e_minalloc:  u16   offset 10
//   e_maxalloc:  u16   offset 12
//   e_ss:        u16   offset 14
//   e_sp:        u16   offset 16
//   e_csum:      u16   offset 18
//   e_ip:        u16   offset 20
//   e_cs:        u16   offset 22
//   e_lfarlc:    u16   offset 24
//   e_ovno:      u16   offset 26
//   e_res:       [4]u16 offset 28
//   e_oemid:     u16   offset 36
//   e_oeminfo:   u16   offset 38
//   e_res2:      [10]u16 offset 40
//   e_lfanew:    u32   offset 60
// ============================================================================

/// PE DOS 头部 - 解析后的结构
// 对应 pe.zig:
//   const DOSHeader = extern struct {
//       e_magic: u16,
//       e_cblp: u16,
//       ...
//       e_lfanew: u32,
//   }
public class PEDOSHeader {
    public var eMagic: UInt16 = UInt16(0)
    public var eCblp: UInt16 = UInt16(0)
    public var eCp: UInt16 = UInt16(0)
    public var eCrlc: UInt16 = UInt16(0)
    public var eCparhdr: UInt16 = UInt16(0)
    public var eMinalloc: UInt16 = UInt16(0)
    public var eMaxalloc: UInt16 = UInt16(0)
    public var eSs: UInt16 = UInt16(0)
    public var eSp: UInt16 = UInt16(0)
    public var eCsum: UInt16 = UInt16(0)
    public var eIp: UInt16 = UInt16(0)
    public var eCs: UInt16 = UInt16(0)
    public var eLfarlc: UInt16 = UInt16(0)
    public var eOvno: UInt16 = UInt16(0)
    public var eOemid: UInt16 = UInt16(0)
    public var eOeminfo: UInt16 = UInt16(0)
    public var eLfanew: UInt32 = UInt32(0)

    public init() {}

    /// 从字节数组解析 DOS 头部
    // 对应 pe.zig:
    //   const dos_header = try viewAtConst(DOSHeader, data.items, 0)
    public static func fromBytes(bytes: Array<UInt8>): ?PEDOSHeader {
        // DOSHeader 大小: 64 字节
        if (bytes.size < 64) {
            return None
        }
        let hdr = PEDOSHeader()
        hdr.eMagic = readUInt16LE(bytes, 0)
        hdr.eCblp = readUInt16LE(bytes, 2)
        hdr.eCp = readUInt16LE(bytes, 4)
        hdr.eCrlc = readUInt16LE(bytes, 6)
        hdr.eCparhdr = readUInt16LE(bytes, 8)
        hdr.eMinalloc = readUInt16LE(bytes, 10)
        hdr.eMaxalloc = readUInt16LE(bytes, 12)
        hdr.eSs = readUInt16LE(bytes, 14)
        hdr.eSp = readUInt16LE(bytes, 16)
        hdr.eCsum = readUInt16LE(bytes, 18)
        hdr.eIp = readUInt16LE(bytes, 20)
        hdr.eCs = readUInt16LE(bytes, 22)
        hdr.eLfarlc = readUInt16LE(bytes, 24)
        hdr.eOvno = readUInt16LE(bytes, 26)
        hdr.eOemid = readUInt16LE(bytes, 36)
        hdr.eOeminfo = readUInt16LE(bytes, 38)
        hdr.eLfanew = readUInt32LE(bytes, 60)
        return Some(hdr)
    }

    /// 是否为有效 DOS 头
    // 对应 pe.zig:
    //   dos_header.e_magic != DOS_SIGNATURE => InvalidDOSSignature
    public func isValid(): Bool {
        return eMagic == DOS_SIG
    }
}

// ============================================================================
// PE 头部结构
// 严格翻译自 src/exe_format/pe.zig PEHeader
// PEHeader 布局 (24 字节):
//   signature:              u32   offset 0
//   machine:                u16   offset 4
//   numberOfSections:       u16   offset 6
//   timeDateStamp:          u32   offset 8
//   pointerToSymbolTable:   u32   offset 12
//   numberOfSymbols:        u32   offset 16
//   sizeOfOptionalHeader:   u16   offset 20
//   characteristics:        u16   offset 22
// ============================================================================

/// PE 头部 - 解析后的结构
// 对应 pe.zig:
//   const PEHeader = extern struct {
//       signature: u32,
//       machine: u16,
//       number_of_sections: u16,
//       time_date_stamp: u32,
//       pointer_to_symbol_table: u32,
//       number_of_symbols: u32,
//       size_of_optional_header: u16,
//       characteristics: u16,
//   }
public class PEHeader {
    public var signature: UInt32 = UInt32(0)
    public var machine: UInt16 = UInt16(0)
    public var numberOfSections: UInt16 = UInt16(0)
    public var timeDateStamp: UInt32 = UInt32(0)
    public var pointerToSymbolTable: UInt32 = UInt32(0)
    public var numberOfSymbols: UInt32 = UInt32(0)
    public var sizeOfOptionalHeader: UInt16 = UInt16(0)
    public var characteristics: UInt16 = UInt16(0)

    public init() {}

    /// 从字节数组指定偏移解析 PE 头部
    // 对应 pe.zig:
    //   const pe_header = try viewAtMut(PEHeader, data.items, pe_off)
    public static func fromBytes(bytes: Array<UInt8>, offset: Int64): ?PEHeader {
        // PEHeader 大小: 24 字节
        if (offset < 0 || offset + 24 > bytes.size) {
            return None
        }
        let hdr = PEHeader()
        hdr.signature = readUInt32LE(bytes, offset)
        hdr.machine = readUInt16LE(bytes, offset + 4)
        hdr.numberOfSections = readUInt16LE(bytes, offset + 6)
        hdr.timeDateStamp = readUInt32LE(bytes, offset + 8)
        hdr.pointerToSymbolTable = readUInt32LE(bytes, offset + 12)
        hdr.numberOfSymbols = readUInt32LE(bytes, offset + 16)
        hdr.sizeOfOptionalHeader = readUInt16LE(bytes, offset + 20)
        hdr.characteristics = readUInt16LE(bytes, offset + 22)
        return Some(hdr)
    }

    /// 是否为有效 PE 头
    // 对应 pe.zig:
    //   pe_header.signature != PE_SIGNATURE => InvalidPESignature
    public func isValid(): Bool {
        return signature == PE_SIG
    }
}

// ============================================================================
// PE Optional Header 64 结构
// 严格翻译自 src/exe_format/pe.zig OptionalHeader64
// OptionalHeader64 布局 (240 字节，最小):
//   magic:                          u16   offset 0
//   majorLinkerVersion:             u8    offset 2
//   minorLinkerVersion:             u8    offset 3
//   sizeOfCode:                     u32   offset 4
//   sizeOfInitializedData:          u32   offset 8
//   sizeOfUninitializedData:        u32   offset 12
//   addressOfEntryPoint:            u32   offset 16
//   baseOfCode:                     u32   offset 20
//   imageBase:                      u64   offset 24
//   sectionAlignment:               u32   offset 32
//   fileAlignment:                  u32   offset 36
//   majorOperatingSystemVersion:    u16   offset 40
//   minorOperatingSystemVersion:    u16   offset 42
//   majorImageVersion:              u16   offset 44
//   minorImageVersion:              u16   offset 46
//   majorSubsystemVersion:          u16   offset 48
//   minorSubsystemVersion:          u16   offset 50
//   win32VersionValue:              u32   offset 52
//   sizeOfImage:                    u32   offset 56
//   sizeOfHeaders:                  u32   offset 60
//   checksum:                       u32   offset 64
//   subsystem:                      u16   offset 68
//   dllCharacteristics:             u16   offset 70
//   sizeOfStackReserve:             u64   offset 72
//   sizeOfStackCommit:              u64   offset 80
//   sizeOfHeapReserve:              u64   offset 88
//   sizeOfHeapCommit:               u64   offset 96
//   loaderFlags:                    u32   offset 104
//   numberOfRvaAndSizes:            u32   offset 108
//   dataDirectories:                [16]DataDirectory offset 112
//     每项: virtualAddress(u32) + size(u32) = 8 字节
//     共 16 * 8 = 128 字节
// ============================================================================

/// PE 数据目录条目
// 对应 pe.zig:
//   const DataDirectory = extern struct {
//       virtual_address: u32,
//       size: u32,
//   }
public class PEDataDirectory {
    public var virtualAddress: UInt32 = UInt32(0)
    public var size: UInt32 = UInt32(0)

    public init() {}

    public init(virtualAddress: UInt32, size: UInt32) {
        this.virtualAddress = virtualAddress
        this.size = size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return virtualAddress == UInt32(0) && size == UInt32(0)
    }
}

/// PE Optional Header 64 - 解析后的结构
// 对应 pe.zig:
//   const OptionalHeader64 = extern struct {
//       magic: u16,
//       major_linker_version: u8,
//       ...
//       data_directories: [16]DataDirectory,
//   }
public class PEOptHeader64 {
    public var magic: UInt16 = UInt16(0)
    public var majorLinkerVersion: UInt8 = UInt8(0)
    public var minorLinkerVersion: UInt8 = UInt8(0)
    public var sizeOfCode: UInt32 = UInt32(0)
    public var sizeOfInitializedData: UInt32 = UInt32(0)
    public var sizeOfUninitializedData: UInt32 = UInt32(0)
    public var addressOfEntryPoint: UInt32 = UInt32(0)
    public var baseOfCode: UInt32 = UInt32(0)
    public var imageBase: UInt64 = UInt64(0)
    public var sectionAlignment: UInt32 = UInt32(0)
    public var fileAlignment: UInt32 = UInt32(0)
    public var majorOperatingSystemVersion: UInt16 = UInt16(0)
    public var minorOperatingSystemVersion: UInt16 = UInt16(0)
    public var majorImageVersion: UInt16 = UInt16(0)
    public var minorImageVersion: UInt16 = UInt16(0)
    public var majorSubsystemVersion: UInt16 = UInt16(0)
    public var minorSubsystemVersion: UInt16 = UInt16(0)
    public var win32VersionValue: UInt32 = UInt32(0)
    public var sizeOfImage: UInt32 = UInt32(0)
    public var sizeOfHeaders: UInt32 = UInt32(0)
    public var checksum: UInt32 = UInt32(0)
    public var subsystem: UInt16 = UInt16(0)
    public var dllCharacteristics: UInt16 = UInt16(0)
    public var sizeOfStackReserve: UInt64 = UInt64(0)
    public var sizeOfStackCommit: UInt64 = UInt64(0)
    public var sizeOfHeapReserve: UInt64 = UInt64(0)
    public var sizeOfHeapCommit: UInt64 = UInt64(0)
    public var loaderFlags: UInt32 = UInt32(0)
    public var numberOfRvaAndSizes: UInt32 = UInt32(0)
    public var dataDirectories: Array<PEDataDirectory> = Array<PEDataDirectory>()

    public init() {}

    /// 从字节数组指定偏移解析 Optional Header 64
    // 对应 pe.zig:
    //   const optional_header = try viewAtMut(OptionalHeader64, data.items, optional_header_offset)
    public static func fromBytes(bytes: Array<UInt8>, offset: Int64): ?PEOptHeader64 {
        // OptionalHeader64 最小大小: 112 + 128 = 240 字节
        let minSize: Int64 = 112
        if (offset < 0 || offset + minSize > bytes.size) {
            return None
        }
        let hdr = PEOptHeader64()
        hdr.magic = readUInt16LE(bytes, offset)
        hdr.majorLinkerVersion = bytes[offset + 2]
        hdr.minorLinkerVersion = bytes[offset + 3]
        hdr.sizeOfCode = readUInt32LE(bytes, offset + 4)
        hdr.sizeOfInitializedData = readUInt32LE(bytes, offset + 8)
        hdr.sizeOfUninitializedData = readUInt32LE(bytes, offset + 12)
        hdr.addressOfEntryPoint = readUInt32LE(bytes, offset + 16)
        hdr.baseOfCode = readUInt32LE(bytes, offset + 20)
        hdr.imageBase = readUInt64LE(bytes, offset + 24)
        hdr.sectionAlignment = readUInt32LE(bytes, offset + 32)
        hdr.fileAlignment = readUInt32LE(bytes, offset + 36)
        hdr.majorOperatingSystemVersion = readUInt16LE(bytes, offset + 40)
        hdr.minorOperatingSystemVersion = readUInt16LE(bytes, offset + 42)
        hdr.majorImageVersion = readUInt16LE(bytes, offset + 44)
        hdr.minorImageVersion = readUInt16LE(bytes, offset + 46)
        hdr.majorSubsystemVersion = readUInt16LE(bytes, offset + 48)
        hdr.minorSubsystemVersion = readUInt16LE(bytes, offset + 50)
        hdr.win32VersionValue = readUInt32LE(bytes, offset + 52)
        hdr.sizeOfImage = readUInt32LE(bytes, offset + 56)
        hdr.sizeOfHeaders = readUInt32LE(bytes, offset + 60)
        hdr.checksum = readUInt32LE(bytes, offset + 64)
        hdr.subsystem = readUInt16LE(bytes, offset + 68)
        hdr.dllCharacteristics = readUInt16LE(bytes, offset + 70)
        hdr.sizeOfStackReserve = readUInt64LE(bytes, offset + 72)
        hdr.sizeOfStackCommit = readUInt64LE(bytes, offset + 80)
        hdr.sizeOfHeapReserve = readUInt64LE(bytes, offset + 88)
        hdr.sizeOfHeapCommit = readUInt64LE(bytes, offset + 96)
        hdr.loaderFlags = readUInt32LE(bytes, offset + 104)
        hdr.numberOfRvaAndSizes = readUInt32LE(bytes, offset + 108)

        // 解析数据目录 (16 项，每项 8 字节)
        // 对应 pe.zig: data_directories: [16]DataDirectory
        let dataDirOffset = offset + 112
        if (dataDirOffset + 128 <= bytes.size) {
            for (i in 0..16) {
                let ddOffset = dataDirOffset + i * 8
                let va = readUInt32LE(bytes, ddOffset)
                let sz = readUInt32LE(bytes, ddOffset + 4)
                hdr.dataDirectories.append(PEDataDirectory(va, sz))
            }
        }

        return Some(hdr)
    }

    /// 是否为 PE64 可选头
    // 对应 pe.zig:
    //   optional_header.magic != OPTIONAL_HEADER_MAGIC_64 => UnsupportedPEFormat
    public func is64Bit(): Bool {
        return magic == PE_OPT_MAGIC_64
    }

    /// 是否启用了 ASLR (等价于 PIE)
    // 对应 Windows IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE
    public func isDynamicBase(): Bool {
        return (dllCharacteristics & IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE) != UInt16(0)
    }

    /// 获取安全目录 (索引 4)
    // 对应 pe.zig:
    //   const dd_ptr = &opt.data_directories[IMAGE_DIRECTORY_ENTRY_SECURITY]
    public func getSecurityDirectory(): PEDataDirectory {
        if (IMAGE_DIRECTORY_ENTRY_SECURITY < dataDirectories.size) {
            return dataDirectories[IMAGE_DIRECTORY_ENTRY_SECURITY]
        }
        return PEDataDirectory()
    }

    /// 验证对齐参数
    // 对应 pe.zig:
    //   if (!isPow2(optional_header.file_alignment) or !isPow2(optional_header.section_alignment))
    //       return error.BadAlignment
    public func validateAlignment(): Bool {
        return isPow2(fileAlignment) && isPow2(sectionAlignment)
    }
}

// ============================================================================
// PE Section Header 结构
// 严格翻译自 src/exe_format/pe.zig SectionHeader
// SectionHeader 布局 (40 字节):
//   name:                     [8]u8  offset 0
//   virtualSize:              u32    offset 8
//   virtualAddress:           u32    offset 12
//   sizeOfRawData:            u32    offset 16
//   pointerToRawData:         u32    offset 20
//   pointerToRelocations:     u32    offset 24
//   pointerToLineNumbers:     u32    offset 28
//   numberOfRelocations:      u16    offset 32
//   numberOfLineNumbers:      u16    offset 34
//   characteristics:          u32    offset 36
// ============================================================================

/// PE Section 头部 - 解析后的结构
// 对应 pe.zig:
//   const SectionHeader = extern struct {
//       name: [8]u8,
//       virtual_size: u32,
//       virtual_address: u32,
//       ...
//       characteristics: u32,
//   }
public class PESectionHeader {
    public var name: Array<UInt8> = Array<UInt8>(8, item: UInt8(0))
    public var virtualSize: UInt32 = UInt32(0)
    public var virtualAddress: UInt32 = UInt32(0)
    public var sizeOfRawData: UInt32 = UInt32(0)
    public var pointerToRawData: UInt32 = UInt32(0)
    public var pointerToRelocations: UInt32 = UInt32(0)
    public var pointerToLineNumbers: UInt32 = UInt32(0)
    public var numberOfRelocations: UInt16 = UInt16(0)
    public var numberOfLineNumbers: UInt16 = UInt16(0)
    public var characteristics: UInt32 = UInt32(0)

    public init() {}

    /// 从字节数组指定偏移解析 Section Header
    // 对应 pe.zig 中 getSectionHeaders 的解析逻辑
    public static func fromBytes(bytes: Array<UInt8>, offset: Int64): ?PESectionHeader {
        // SectionHeader 大小: 40 字节
        if (offset < 0 || offset + 40 > bytes.size) {
            return None
        }
        let sect = PESectionHeader()
        for (i in 0..8) {
            sect.name[i] = bytes[offset + i]
        }
        sect.virtualSize = readUInt32LE(bytes, offset + 8)
        sect.virtualAddress = readUInt32LE(bytes, offset + 12)
        sect.sizeOfRawData = readUInt32LE(bytes, offset + 16)
        sect.pointerToRawData = readUInt32LE(bytes, offset + 20)
        sect.pointerToRelocations = readUInt32LE(bytes, offset + 24)
        sect.pointerToLineNumbers = readUInt32LE(bytes, offset + 28)
        sect.numberOfRelocations = readUInt16LE(bytes, offset + 32)
        sect.numberOfLineNumbers = readUInt16LE(bytes, offset + 34)
        sect.characteristics = readUInt32LE(bytes, offset + 36)
        return Some(sect)
    }

    /// 获取节名称 (去掉尾部零字节)
    // 对应 pe.zig:
    //   std.mem.eql(u8, section.name[0..8], &BUN_SECTION_NAME)
    public func sectionName(): String {
        var n = ""
        for (i in 0..8) {
            if (name[i] == UInt8(0)) {
                break
            }
            n = n + String(UInt8.toRune(name[i]))
        }
        return n
    }

    /// 是否为 .bun 节
    // 对应 pe.zig:
    //   const BUN_SECTION_NAME = [_]u8{ '.', 'b', 'u', 'n', 0, 0, 0, 0 }
    public func isBunSection(): Bool {
        return sectionName() == ".bun"
    }
}

// ============================================================================
// PE 文件完整解析结果
// 对应 pe.zig PEFile 结构 (仅解析部分，不包含修改功能)
// ============================================================================

/// PE 文件完整解析结果
// 对应 pe.zig PEFile 的初始化阶段:
//   pub fn init(allocator: Allocator, pe_data: []const u8) !*PEFile
public class PEFileInfo {
    public var dosHeader: PEDOSHeader = PEDOSHeader()
    public var peHeader: PEHeader = PEHeader()
    public var optHeader: PEOptHeader64 = PEOptHeader64()
    public var sections: Array<PESectionHeader> = Array<PESectionHeader>()
    public var peHeaderOffset: Int64 = Int64(0)
    public var optHeaderOffset: Int64 = Int64(0)
    public var sectionHeadersOffset: Int64 = Int64(0)

    public init() {}

    /// 从字节数组解析 PE 文件
    // 严格翻译自 pe.zig PEFile.init:
    //   1. 验证 DOS header (e_magic == DOS_SIGNATURE)
    //   2. 读取 e_lfanew 并验证 PE header (signature == PE_SIGNATURE)
    //   3. 读取 Optional header (magic == OPTIONAL_HEADER_MAGIC_64)
    //   4. 读取 Section headers
    public static func parse(bytes: Array<UInt8>): ?PEFileInfo {
        // 1. 验证 DOS header
        // 对应 pe.zig:
        //   if (data.items.len < @sizeOf(DOSHeader)) return error.InvalidPEFile
        //   const dos_header = try viewAtConst(DOSHeader, data.items, 0)
        //   if (dos_header.e_magic != DOS_SIGNATURE) return error.InvalidDOSSignature
        let dosOpt = PEDOSHeader.fromBytes(bytes)
        match (dosOpt) {
            case Some(dos) =>
                if (!dos.isValid()) {
                    return None
                }
            case None =>
                return None
        }

        let info = PEFileInfo()
        info.dosHeader = dosOpt.get()

        // 2. 读取 e_lfanew 并验证范围
        // 对应 pe.zig:
        //   if (dos_header.e_lfanew < @sizeOf(DOSHeader)) return error.InvalidPEFile
        //   if (dos_header.e_lfanew > data.items.len -| @sizeOf(PEHeader)) return error.InvalidPEFile
        let eLfanew = Int64(info.dosHeader.eLfanew)
        if (eLfanew < 64) {
            return None
        }
        if (eLfanew + 24 > bytes.size) {
            return None
        }

        // 3. 读取 PE header
        // 对应 pe.zig:
        //   const pe_header = try viewAtMut(PEHeader, data.items, pe_off)
        //   if (pe_header.signature != PE_SIGNATURE) return error.InvalidPESignature
        info.peHeaderOffset = eLfanew
        let peOpt = PEHeader.fromBytes(bytes, eLfanew)
        match (peOpt) {
            case Some(pe) =>
                if (!pe.isValid()) {
                    return None
                }
            case None =>
                return None
        }
        info.peHeader = peOpt.get()

        // 4. 计算可选头偏移并读取
        // 对应 pe.zig:
        //   const optional_header_offset = pe_off + @sizeOf(PEHeader)
        //   if (data.items.len < optional_header_offset + pe_header.size_of_optional_header)
        //       return error.InvalidPEFile
        //   if (pe_header.size_of_optional_header < @sizeOf(OptionalHeader64))
        //       return error.InvalidPEFile
        info.optHeaderOffset = eLfanew + 24
        let optSize = Int64(info.peHeader.sizeOfOptionalHeader)
        if (optSize < 240) {
            return None
        }
        if (info.optHeaderOffset + optSize > bytes.size) {
            return None
        }

        // 5. 读取 Optional header
        // 对应 pe.zig:
        //   const optional_header = try viewAtMut(OptionalHeader64, data.items, optional_header_offset)
        //   if (optional_header.magic != OPTIONAL_HEADER_MAGIC_64) return error.UnsupportedPEFormat
        let optHdrOpt = PEOptHeader64.fromBytes(bytes, info.optHeaderOffset)
        match (optHdrOpt) {
            case Some(optHdr) =>
                if (!optHdr.is64Bit()) {
                    return None
                }
                info.optHeader = optHdr
            case None =>
                return None
        }

        // 6. 验证对齐
        // 对应 pe.zig:
        //   if (!isPow2(optional_header.file_alignment) or !isPow2(optional_header.section_alignment))
        //       return error.BadAlignment
        if (!info.optHeader.validateAlignment()) {
            return None
        }

        // 7. 读取 Section headers
        // 对应 pe.zig:
        //   const section_headers_offset = optional_header_offset + pe_header.size_of_optional_header
        //   const num_sections = pe_header.number_of_sections
        info.sectionHeadersOffset = info.optHeaderOffset + optSize
        let numSections = Int64(info.peHeader.numberOfSections)
        if (numSections > 96) {
            return None
        }
        if (info.sectionHeadersOffset + numSections * 40 > bytes.size) {
            return None
        }

        for (i in 0..numSections) {
            let sectOffset = info.sectionHeadersOffset + i * 40
            let sectOpt = PESectionHeader.fromBytes(bytes, sectOffset)
            match (sectOpt) {
                case Some(sect) =>
                    info.sections.append(sect)
                case None => ()
            }
        }

        return Some(info)
    }

    /// 查找 .bun 节
    // 对应 pe.zig:
    //   pub fn getBunSectionData(self: *const PEFile) ![]const u8 {
    //       const section_headers = try self.getSectionHeaders()
    //       for (section_headers) |section| {
    //           if (std.mem.eql(u8, section.name[0..8], &BUN_SECTION_NAME)) { ... }
    //       }
    //       return error.BunSectionNotFound
    //   }
    public func findBunSection(): ?PESectionHeader {
        for (sect in sections) {
            if (sect.isBunSection()) {
                return Some(sect)
            }
        }
        return None
    }

    /// 读取 .bun 节数据
    // 对应 pe.zig getBunSectionData:
    //   const section_data = self.data.items[section.pointer_to_raw_data..][0..section.size_of_raw_data]
    //   const data_size = std.mem.readInt(u64, section_data[0..8], .little)
    //   return section_data[8..][0..data_size]
    public func readBunSectionData(bytes: Array<UInt8>): ?Array<UInt8> {
        let sectOpt = findBunSection()
        match (sectOpt) {
            case Some(sect) =>
                if (sect.sizeOfRawData < 8) {
                    return None
                }
                let rawOffset = Int64(sect.pointerToRawData)
                let rawSize = Int64(sect.sizeOfRawData)
                if (rawOffset < 0 || rawOffset + rawSize > bytes.size) {
                    return None
                }
                // 读取 u64 长度前缀
                let dataSize = Int64(readUInt64LE(bytes, rawOffset))
                if (dataSize + 8 > rawSize) {
                    return None
                }
                // 提取数据 (跳过 8 字节长度前缀)
                var result = Array<UInt8>()
                for (i in 0..dataSize) {
                    result.append(bytes[rawOffset + 8 + i])
                }
                return Some(result)
            case None =>
                return None
        }
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 判断是否为 2 的幂
// 对应 pe.zig:
//   fn isPow2(x: u32) bool {
//       return x != 0 and (x & (x - 1) == 0)
//   }
public func isPow2(x: UInt32): Bool {
    return x != UInt32(0) && (x & (x - UInt32(1))) == UInt32(0)
}

/// 向上对齐 (UInt32)
// 对应 pe.zig:
//   fn alignUpU32(v: u32, a: u32) !u32 {
//       if (a == 0) return v;
//       if (!isPow2(a)) return error.BadAlignment
//       const add = a - 1
//       if (v > std.math.maxInt(u32) - add) return error.Overflow
//       return (v + add) & ~add
//   }
public func peAlignUpU32(v: UInt32, a: UInt32): UInt32 {
    if (a == UInt32(0)) {
        return v
    }
    if (!isPow2(a)) {
        return v
    }
    let add = a - UInt32(1)
    return (v + add) & ~add
}

/// 计算 PE 校验和
// 对应 pe.zig:
//   fn recomputePEChecksum(self: *PEFile) !void {
//       const data = self.data.items
//       const checksum_off = self.optional_header_offset + @offsetOf(OptionalHeader64, "checksum")
//       @memset(self.data.items[checksum_off .. checksum_off + 4], 0)
//       var sum: u64 = 0
//       var i: usize = 0
//       while (i + 1 < data.len) : (i += 2) {
//           const w: u16 = @as(u16, data[i]) | (@as(u16, data[i + 1]) << 8)
//           sum += w
//           sum = (sum & 0xffff) + (sum >> 16)
//       }
//       if ((data.len & 1) != 0) { sum += data[data.len - 1] }
//       sum = (sum & 0xffff) + (sum >> 16)
//       sum = (sum & 0xffff) + (sum >> 16)
//       sum += @as(u64, @intCast(data.len))
//       sum = (sum & 0xffff) + (sum >> 16)
//       const final_sum: u32 = @intCast((sum & 0xffff) + (sum >> 16))
//   }
public func computePEChecksum(bytes: Array<UInt8>, checksumOffset: Int64): UInt32 {
    var sum: UInt64 = UInt64(0)
    var i: Int64 = 0

    while (i + 1 < bytes.size) {
        let w: UInt16 = UInt16(bytes[i]) | (UInt16(bytes[i + 1]) << 8)
        sum = sum + UInt64(w)
        sum = (sum & UInt64(0xFFFF)) + (sum >> UInt64(16))
        i = i + 2
    }

    // 奇数尾部字节
    if ((bytes.size % 2) != 0) {
        sum = sum + UInt64(bytes[bytes.size - 1])
    }

    // 最终折叠 + 加长度
    sum = (sum & UInt64(0xFFFF)) + (sum >> UInt64(16))
    sum = (sum & UInt64(0xFFFF)) + (sum >> UInt64(16))
    sum = sum + UInt64(bytes.size)
    sum = (sum & UInt64(0xFFFF)) + (sum >> UInt64(16))
    return UInt32((sum & UInt64(0xFFFF)) + (sum >> UInt64(16)))
}

// ============================================================================
// BUN 编译节名称
// 对应 pe.zig:
//   pub const BUN_COMPILED_SECTION_NAME = ".bun"
//   const BUN_SECTION_NAME = [_]u8{ '.', 'b', 'u', 'n', 0, 0, 0, 0 }
// ============================================================================

/// Bao/Bun 编译节名称常量
public let BUN_COMPILED_SECTION_NAME: String = ".bun"
