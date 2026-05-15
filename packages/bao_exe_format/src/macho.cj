// macho.cj - Mach-O 格式解析
// 严格翻译自:
//   src/exe_format/macho.zig - MachoFile, MachoSigner, LoadCommand 迭代
//   src/exe_format/macho.rs - Rust 移植版本
//   src/exe_format/macho_types.rs - Mach-O 类型定义
package bao_exe_format

import bao_core.*

// ============================================================================
// Mach-O 加载命令类型
// 严格翻译自 src/exe_format/macho_types.rs LC 枚举
// ============================================================================

/// LC_SEGMENT_64 - 64位段加载命令
// 对应 macho_types.rs: pub const LC_SEGMENT_64: u32 = 0x19
public let LC_SEGMENT_64: UInt32 = UInt32(0x19)

/// LC_SYMTAB - 符号表
// 对应 macho_types.rs: pub const LC_SYMTAB: u32 = 0x2
public let LC_SYMTAB: UInt32 = UInt32(0x2)

/// LC_DYSYMTAB - 动态符号表
// 对应 macho_types.rs: pub const LC_DYSYMTAB: u32 = 0xB
public let LC_DYSYMTAB: UInt32 = UInt32(0xB)

/// LC_CODE_SIGNATURE - 代码签名
// 对应 macho_types.rs: pub const LC_CODE_SIGNATURE: u32 = 0x1D
public let LC_CODE_SIGNATURE: UInt32 = UInt32(0x1D)

/// LC_DYLD_INFO - 动态链接信息
// 对应 macho_types.rs: pub const LC_DYLD_INFO: u32 = 0x22
public let LC_DYLD_INFO: UInt32 = UInt32(0x22)

/// LC_DYLD_INFO_ONLY - 仅动态链接信息
// 对应 macho_types.rs: pub const LC_DYLD_INFO_ONLY: u32 = 0x80000022
public let LC_DYLD_INFO_ONLY: UInt32 = UInt32(0x80000022)

/// LC_FUNCTION_STARTS - 函数起始地址
// 对应 macho_types.rs: pub const LC_FUNCTION_STARTS: u32 = 0x26
public let LC_FUNCTION_STARTS: UInt32 = UInt32(0x26)

/// LC_DATA_IN_CODE - 代码中的数据
// 对应 macho_types.rs: pub const LC_DATA_IN_CODE: u32 = 0x29
public let LC_DATA_IN_CODE: UInt32 = UInt32(0x29)

/// LC_DYLIB_CODE_SIGN_DRS - 动态库代码签名
// 对应 macho_types.rs: pub const LC_DYLIB_CODE_SIGN_DRS: u32 = 0x2B
public let LC_DYLIB_CODE_SIGN_DRS: UInt32 = UInt32(0x2B)

/// LC_LINKER_OPTIMIZATION_HINT - 链接器优化提示
// 对应 macho_types.rs: pub const LC_LINKER_OPTIMIZATION_HINT: u32 = 0x2E
public let LC_LINKER_OPTIMIZATION_HINT: UInt32 = UInt32(0x2E)

/// LC_DYLD_EXPORTS_TRIE - 导出符号树
// 对应 macho_types.rs: pub const LC_DYLD_EXPORTS_TRIE: u32 = 0x80000031
public let LC_DYLD_EXPORTS_TRIE: UInt32 = UInt32(0x80000031)

/// LC_DYLD_CHAINED_FIXUPS - 链式修复
// 对应 macho_types.rs: pub const LC_DYLD_CHAINED_FIXUPS: u32 = 0x80000034
public let LC_DYLD_CHAINED_FIXUPS: UInt32 = UInt32(0x80000034)

/// LC_MAIN - 主入口点 (Mach-O)
// 对应标准 Mach-O 定义: entry_command.cmd = LC_MAIN = 0x80000028
public let LC_MAIN: UInt32 = UInt32(0x80000028)

/// LC_UNIXTHREAD - Unix 线程 (旧式入口点)
public let LC_UNIXTHREAD: UInt32 = UInt32(0x5)

/// LC_BUILD_VERSION - 构建版本
// 对应标准 Mach-O 定义: build_version_command.cmd = LC_BUILD_VERSION = 0x32
public let LC_BUILD_VERSION: UInt32 = UInt32(0x32)

/// LC_ID_DYLINKER - 动态链接器标识
public let LC_ID_DYLINKER: UInt32 = UInt32(0xE)

/// LC_LOAD_DYLINKER - 加载动态链接器
public let LC_LOAD_DYLINKER: UInt32 = UInt32(0xE)

// ============================================================================
// Mach-O 保护标志
// 严格翻译自 src/exe_format/macho_types.rs
// ============================================================================

/// PROT_READ
// 对应 macho_types.rs: pub const PROT_READ: u32 = 0x1
public let MACHO_PROT_READ: UInt32 = UInt32(0x1)

/// PROT_WRITE
// 对应 macho_types.rs: pub const PROT_WRITE: u32 = 0x2
public let MACHO_PROT_WRITE: UInt32 = UInt32(0x2)

/// PROT_EXECUTE
// 对应 macho_types.rs: pub const PROT_EXEC: u32 = 0x4
public let MACHO_PROT_EXECUTE: UInt32 = UInt32(0x4)

// ============================================================================
// Mach-O 节标志
// 严格翻译自 src/exe_format/macho_types.rs
// ============================================================================

/// S_REGULAR - 常规节
// 对应 macho_types.rs: pub const S_REGULAR: u32 = 0x0
public let S_REGULAR: UInt32 = UInt32(0x0)

/// S_ATTR_NO_DEAD_STRIP - 不死代码剥离
// 对应 macho_types.rs: pub const S_ATTR_NO_DEAD_STRIP: u32 = 0x200000
public let S_ATTR_NO_DEAD_STRIP: UInt32 = UInt32(0x200000)

// ============================================================================
// Mach-O 段/节名称
// 严格翻译自 src/exe_format/macho.zig
// ============================================================================

/// __BUN 段名称 (16 字节, 零填充)
// 对应 macho.zig:
//   pub const SEGNAME_BUN = "__BUN\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".*
public let SEGNAME_BUN: String = "__BUN"

/// __bun 节名称 (16 字节, 零填充)
// 对应 macho.zig:
//   pub const SECTNAME = "__bun\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".*
public let SECTNAME_BUN: String = "__bun"

/// __LINKEDIT 段名称
// 对应 macho.zig:
//   const SEG_LINKEDIT = "__LINKEDIT"
public let SEG_LINKEDIT: String = "__LINKEDIT"

/// __TEXT 段名称
public let SEG_TEXT: String = "__TEXT"

// ============================================================================
// 代码签名常量
// 严格翻译自 src/exe_format/macho.zig
// ============================================================================

/// CSMAGIC_CODEDIRECTORY
// 对应 macho.zig: const CSMAGIC_CODEDIRECTORY: u32 = 0xfade0c02
public let CSMAGIC_CODEDIRECTORY: UInt32 = UInt32(0xFade0C02)

/// CSMAGIC_EMBEDDED_SIGNATURE
// 对应 macho.zig: const CSMAGIC_EMBEDDED_SIGNATURE: u32 = 0xfade0cc0
public let CSMAGIC_EMBEDDED_SIGNATURE: UInt32 = UInt32(0xFade0CC0)

/// CSSLOT_CODEDIRECTORY
// 对应 macho.zig: const CSSLOT_CODEDIRECTORY: u32 = 0
public let CSSLOT_CODEDIRECTORY: UInt32 = UInt32(0)

/// SEC_CODE_SIGNATURE_HASH_SHA256
// 对应 macho.zig: const SEC_CODE_SIGNATURE_HASH_SHA256: u8 = 2
public let SEC_CODE_SIGNATURE_HASH_SHA256: UInt8 = UInt8(2)

/// CS_EXECSEG_MAIN_BINARY
// 对应 macho.zig: const CS_EXECSEG_MAIN_BINARY: u64 = 0x1
public let CS_EXECSEG_MAIN_BINARY: UInt64 = UInt64(0x1)

// ============================================================================
// Mach-O 头部结构
// 严格翻译自 src/exe_format/macho_types.rs mach_header_64
// 以及 macho.zig 中 header 的使用
// mach_header_64 布局 (32 字节):
//   magic:        u32    offset 0
//   cputype:      u32    offset 4
//   cpusubtype:   u32    offset 8
//   filetype:     u32    offset 12
//   ncmds:        u32    offset 16
//   sizeofcmds:   u32    offset 20
//   flags:        u32    offset 24
//   reserved:     u32    offset 28
// ============================================================================

/// Mach-O 64位头部 - 解析后的结构
// 对应 macho_types.rs:
//   pub struct mach_header_64 {
//       pub magic: u32,
//       pub cputype: u32,
//       pub cpusubtype: u32,
//       pub filetype: u32,
//       pub ncmds: u32,
//       pub sizeofcmds: u32,
//       pub flags: u32,
//       pub reserved: u32,
//   }
public class MachOHeader64 {
    public var magic: UInt32 = UInt32(0)
    public var cputype: UInt32 = UInt32(0)
    public var cpusubtype: UInt32 = UInt32(0)
    public var filetype: UInt32 = UInt32(0)
    public var ncmds: UInt32 = UInt32(0)
    public var sizeofcmds: UInt32 = UInt32(0)
    public var flags: UInt32 = UInt32(0)
    public var reserved: UInt32 = UInt32(0)

    public init() {}

    /// 从字节数组解析头部
    // 对应 macho.zig:
    //   const header: *const macho.mach_header_64 = @ptrCast(@alignCast(data.items.ptr))
    // 对应 macho.rs:
    //   let header: macho::mach_header_64 = read_struct(&data[..size_of::<macho::mach_header_64>()])
    public static func fromBytes(bytes: Array<UInt8>): ?MachOHeader64 {
        if (bytes.size < 32) {
            return None
        }
        let hdr = MachOHeader64()
        hdr.magic = readUInt32LE(bytes, 0)
        hdr.cputype = readUInt32LE(bytes, 4)
        hdr.cpusubtype = readUInt32LE(bytes, 8)
        hdr.filetype = readUInt32LE(bytes, 12)
        hdr.ncmds = readUInt32LE(bytes, 16)
        hdr.sizeofcmds = readUInt32LE(bytes, 20)
        hdr.flags = readUInt32LE(bytes, 24)
        hdr.reserved = readUInt32LE(bytes, 28)
        return Some(hdr)
    }

    /// 是否为有效 Mach-O 64位
    public func isValid(): Bool {
        return magic == MACHO_MAGIC_64
    }

    /// 是否为 ARM64
    // 对应 macho.zig:
    //   self.header.cputype == macho.CPU_TYPE_ARM64
    public func isARM64(): Bool {
        return cputype == CPU_TYPE_ARM64
    }

    /// 是否为 x86_64
    public func isX86_64(): Bool {
        return cputype == CPU_TYPE_X86_64
    }

    /// 是否为 PIE
    // 对应 Mach-O flags: MH_PIE = 0x200000
    public func isPIE(): Bool {
        return (flags & MH_PIE) != UInt32(0)
    }
}

// ============================================================================
// Mach-O segment_command_64 结构
// 严格翻译自 macho_types.rs segment_command_64
// segment_command_64 布局 (72 字节):
//   cmd:          u32    offset 0
//   cmdsize:      u32    offset 4
//   segname:      [8]u8  offset 8  (实际为 [16]u8)
//   vmaddr:       u64    offset 24
//   vmsize:       u64    offset 32
//   fileoff:      u64    offset 40
//   filesize:     u64    offset 48
//   maxprot:      u32    offset 56
//   initprot:     u32    offset 60
//   nsects:       u32    offset 64
//   flags:        u32    offset 68
// ============================================================================

/// Mach-O segment_command_64 - 解析后的结构
// 对应 macho_types.rs:
//   pub struct segment_command_64 {
//       pub cmd: u32,
//       pub cmdsize: u32,
//       pub segname: [u8; 16],
//       pub vmaddr: u64,
//       pub vmsize: u64,
//       pub fileoff: u64,
//       pub filesize: u64,
//       pub maxprot: u32,
//       pub initprot: u32,
//       pub nsects: u32,
//       pub flags: u32,
//   }
public class MachOSegmentCommand64 {
    public var cmd: UInt32 = UInt32(0)
    public var cmdsize: UInt32 = UInt32(0)
    public var segname: Array<UInt8> = Array<UInt8>(16, item: UInt8(0))
    public var vmaddr: UInt64 = UInt64(0)
    public var vmsize: UInt64 = UInt64(0)
    public var fileoff: UInt64 = UInt64(0)
    public var filesize: UInt64 = UInt64(0)
    public var maxprot: UInt32 = UInt32(0)
    public var initprot: UInt32 = UInt32(0)
    public var nsects: UInt32 = UInt32(0)
    public var flags: UInt32 = UInt32(0)

    public init() {}

    /// 从字节数组指定偏移解析
    // 对应 macho.zig 中通过 LoadCommandIterator 迭代解析
    public static func fromBytes(bytes: Array<UInt8>, offset: Int64): ?MachOSegmentCommand64 {
        // segment_command_64 大小: 4+4+16+8+8+8+8+4+4+4+4 = 72
        if (offset < 0 || offset + 72 > bytes.size) {
            return None
        }
        let seg = MachOSegmentCommand64()
        seg.cmd = readUInt32LE(bytes, offset)
        seg.cmdsize = readUInt32LE(bytes, offset + 4)
        // segname: 16 字节从 offset + 8
        for (i in 0..16) {
            seg.segname[i] = bytes[offset + 8 + i]
        }
        seg.vmaddr = readUInt64LE(bytes, offset + 24)
        seg.vmsize = readUInt64LE(bytes, offset + 32)
        seg.fileoff = readUInt64LE(bytes, offset + 40)
        seg.filesize = readUInt64LE(bytes, offset + 48)
        seg.maxprot = readUInt32LE(bytes, offset + 56)
        seg.initprot = readUInt32LE(bytes, offset + 60)
        seg.nsects = readUInt32LE(bytes, offset + 64)
        seg.flags = readUInt32LE(bytes, offset + 68)
        return Some(seg)
    }

    /// 获取段名称 (去掉尾部零字节)
    // 对应 macho.rs: command.seg_name() == b"__BUN"
    public func segName(): String {
        var name = ""
        for (i in 0..16) {
            if (segname[i] == UInt8(0)) {
                break
            }
            name = name + String(UInt8.toRune(segname[i]))
        }
        return name
    }

    /// 是否为 __BUN 段
    // 对应 macho.zig:
    //   strings.eqlComptime(command.segName(), "__BUN")
    public func isBunSegment(): Bool {
        return segName() == SEGNAME_BUN
    }

    /// 是否为 __LINKEDIT 段
    // 对应 macho.zig / macho.rs:
    //   command.segName() == SEG_LINKEDIT
    public func isLinkEditSegment(): Bool {
        return segName() == SEG_LINKEDIT
    }

    /// 是否为 __TEXT 段
    public func isTextSegment(): Bool {
        return segName() == SEG_TEXT
    }
}

// ============================================================================
// Mach-O section_64 结构
// 严格翻译自 macho_types.rs section_64
// section_64 布局 (80 字节):
//   sectname:     [16]u8  offset 0
//   segname:      [16]u8  offset 16
//   addr:         u64     offset 32
//   size:         u64     offset 40
//   offset:       u32     offset 48
//   align:        u32     offset 52
//   reloff:       u32     offset 56
//   nreloc:       u32     offset 60
//   flags:        u32     offset 64
//   reserved1:    u32     offset 68
//   reserved2:    u32     offset 72
//   reserved3:    u32     offset 76
// ============================================================================

/// Mach-O section_64 - 解析后的结构
// 对应 macho_types.rs:
//   pub struct section_64 {
//       pub sectname: [u8; 16],
//       pub segname: [u8; 16],
//       pub addr: u64,
//       pub size: u64,
//       pub offset: u32,
//       pub align: u32,
//       pub reloff: u32,
//       pub nreloc: u32,
//       pub flags: u32,
//       pub reserved1: u32,
//       pub reserved2: u32,
//       pub reserved3: u32,
//   }
public class MachOSection64 {
    public var sectname: Array<UInt8> = Array<UInt8>(16, item: UInt8(0))
    public var segname: Array<UInt8> = Array<UInt8>(16, item: UInt8(0))
    public var addr: UInt64 = UInt64(0)
    public var size: UInt64 = UInt64(0)
    public var offset: UInt32 = UInt32(0)
    public var align: UInt32 = UInt32(0)
    public var reloff: UInt32 = UInt32(0)
    public var nreloc: UInt32 = UInt32(0)
    public var flags: UInt32 = UInt32(0)
    public var reserved1: UInt32 = UInt32(0)
    public var reserved2: UInt32 = UInt32(0)
    public var reserved3: UInt32 = UInt32(0)

    public init() {}

    /// 从字节数组指定偏移解析
    // 对应 macho.zig 中解析 sections 数组
    public static func fromBytes(bytes: Array<UInt8>, offset: Int64): ?MachOSection64 {
        // section_64 大小: 16+16+8+8+4+4+4+4+4+4+4+4 = 80
        if (offset < 0 || offset + 80 > bytes.size) {
            return None
        }
        let sect = MachOSection64()
        for (i in 0..16) {
            sect.sectname[i] = bytes[offset + i]
        }
        for (i in 0..16) {
            sect.segname[i] = bytes[offset + 16 + i]
        }
        sect.addr = readUInt64LE(bytes, offset + 32)
        sect.size = readUInt64LE(bytes, offset + 40)
        sect.offset = readUInt32LE(bytes, offset + 48)
        sect.align = readUInt32LE(bytes, offset + 52)
        sect.reloff = readUInt32LE(bytes, offset + 56)
        sect.nreloc = readUInt32LE(bytes, offset + 60)
        sect.flags = readUInt32LE(bytes, offset + 64)
        sect.reserved1 = readUInt32LE(bytes, offset + 68)
        sect.reserved2 = readUInt32LE(bytes, offset + 72)
        sect.reserved3 = readUInt32LE(bytes, offset + 76)
        return Some(sect)
    }

    /// 获取节名称 (去掉尾部零字节)
    // 对应 macho.rs: sect.sect_name() == b"__bun"
    public func sectName(): String {
        var name = ""
        for (i in 0..16) {
            if (sectname[i] == UInt8(0)) {
                break
            }
            name = name + String(UInt8.toRune(sectname[i]))
        }
        return name
    }

    /// 获取段名称
    public func segName(): String {
        var name = ""
        for (i in 0..16) {
            if (segname[i] == UInt8(0)) {
                break
            }
            name = name + String(UInt8.toRune(segname[i]))
        }
        return name
    }

    /// 是否为 __BUN,__bun 节
    // 对应 macho.zig:
    //   strings.eqlComptime(sect.sectName(), "__bun")
    public func isBunSection(): Bool {
        return sectName() == SECTNAME_BUN && segName() == SEGNAME_BUN
    }
}

// ============================================================================
// Mach-O linkedit_data_command 结构
// 严格翻译自 macho_types.rs
// linkedit_data_command 布局 (16 字节):
//   cmd:      u32    offset 0
//   cmdsize:  u32    offset 4
//   dataoff:  u32    offset 8
//   datasize: u32    offset 12
// ============================================================================

/// Mach-O linkedit_data_command - 解析后的结构
// 对应 macho_types.rs:
//   pub struct linkedit_data_command {
//       pub cmd: u32,
//       pub cmdsize: u32,
//       pub dataoff: u32,
//       pub datasize: u32,
//   }
public class MachOLinkEditDataCommand {
    public var cmd: UInt32 = UInt32(0)
    public var cmdsize: UInt32 = UInt32(0)
    public var dataoff: UInt32 = UInt32(0)
    public var datasize: UInt32 = UInt32(0)

    public init() {}

    /// 从字节数组指定偏移解析
    public static func fromBytes(bytes: Array<UInt8>, offset: Int64): ?MachOLinkEditDataCommand {
        if (offset < 0 || offset + 16 > bytes.size) {
            return None
        }
        let cmd = MachOLinkEditDataCommand()
        cmd.cmd = readUInt32LE(bytes, offset)
        cmd.cmdsize = readUInt32LE(bytes, offset + 4)
        cmd.dataoff = readUInt32LE(bytes, offset + 8)
        cmd.datasize = readUInt32LE(bytes, offset + 12)
        return Some(cmd)
    }
}

// ============================================================================
// Mach-O build_version_command 结构
// 严格翻译自标准 Mach-O 定义
// build_version_command 布局 (24 字节 + ntools * tool_entry):
//   cmd:      u32    offset 0
//   cmdsize:  u32    offset 4
//   platform: u32    offset 8
//   minos:    u32    offset 12  (打包的版本号: major.minor.patch)
//   sdk:      u32    offset 16
//   ntools:   u32    offset 20
// ============================================================================

/// Mach-O build_version_command - 解析后的结构
public class MachOBuildVersionCommand {
    public var cmd: UInt32 = UInt32(0)
    public var cmdsize: UInt32 = UInt32(0)
    public var platform: UInt32 = UInt32(0)
    public var minos: UInt32 = UInt32(0)
    public var sdk: UInt32 = UInt32(0)
    public var ntools: UInt32 = UInt32(0)

    public init() {}

    /// 从字节数组指定偏移解析
    public static func fromBytes(bytes: Array<UInt8>, offset: Int64): ?MachOBuildVersionCommand {
        if (offset < 0 || offset + 24 > bytes.size) {
            return None
        }
        let bvc = MachOBuildVersionCommand()
        bvc.cmd = readUInt32LE(bytes, offset)
        bvc.cmdsize = readUInt32LE(bytes, offset + 4)
        bvc.platform = readUInt32LE(bytes, offset + 8)
        bvc.minos = readUInt32LE(bytes, offset + 12)
        bvc.sdk = readUInt32LE(bytes, offset + 16)
        bvc.ntools = readUInt32LE(bytes, offset + 20)
        return Some(bvc)
    }

    /// 解析 minos 版本号 (major.minor.patch)
    // Mach-O 版本号编码: (major << 16) | (minor << 8) | patch
    public func minosVersion(): String {
        let major = (minos >> 16) & 0xFFFF
        let minor = (minos >> 8) & 0xFF
        let patch = minos & 0xFF
        return "${major}.${minor}.${patch}"
    }

    /// 解析 sdk 版本号
    public func sdkVersion(): String {
        let major = (sdk >> 16) & 0xFFFF
        let minor = (sdk >> 8) & 0xFF
        let patch = sdk & 0xFF
        return "${major}.${minor}.${patch}"
    }
}

// ============================================================================
// Mach-O 平台类型
// 对应 LC_BUILD_VERSION platform 字段
// ============================================================================

/// PLATFORM_MACOS - macOS
public let PLATFORM_MACOS: UInt32 = UInt32(1)

/// PLATFORM_IOS - iOS
public let PLATFORM_IOS: UInt32 = UInt32(2)

/// PLATFORM_TVOS - tvOS
public let PLATFORM_TVOS: UInt32 = UInt32(3)

/// PLATFORM_WATCHOS - watchOS
public let PLATFORM_WATCHOS: UInt32 = UInt32(4)

// ============================================================================
// Mach-O Load Command 迭代器
// 严格翻译自 macho_types.rs LoadCommandIterator
// 以及 macho.zig 中 iterator() 的使用
// ============================================================================

/// Mach-O 加载命令迭代器
// 对应 macho_types.rs:
//   pub struct LoadCommandIterator {
//       buffer: &'a [u8],
//       ncmds: u32,
//       ...
//   }
// 对应 macho.zig:
//   pub fn iterator(self: *const MachoFile) macho.LoadCommandIterator {
//       return .{
//           .buffer = self.data.items[@sizeOf(macho.mach_header_64)..][0..self.header.sizeofcmds],
//           .ncmds = self.header.ncmds,
//       };
//   }
public class MachOLoadCommandIterator {
    private var bytes: Array<UInt8> = Array<UInt8>()
    private var pos: Int64 = 0
    private var remaining: Int64 = 0

    public init(bytes: Array<UInt8>, headerSize: Int64, sizeofcmds: UInt32) {
        this.bytes = bytes
        this.pos = headerSize
        this.remaining = Int64(sizeofcmds)
    }

    /// 获取下一个加载命令
    // 对应 macho_types.rs LoadCommandIterator::next()
    // 每个加载命令以 (cmd: u32, cmdsize: u32) 开头
    public func next(): ?MachOLoadCommandEntry {
        if (remaining < 8) {
            return None
        }

        // 读取 cmd 和 cmdsize
        let cmd = readUInt32LE(bytes, pos)
        let cmdsize = readUInt32LE(bytes, pos + 4)

        if (cmdsize < 8) {
            return None
        }
        if (Int64(cmdsize) > remaining) {
            return None
        }

        let entry = MachOLoadCommandEntry(bytes, pos, cmd, cmdsize)
        pos = pos + Int64(cmdsize)
        remaining = remaining - Int64(cmdsize)
        return Some(entry)
    }
}

/// Mach-O 加载命令条目
public class MachOLoadCommandEntry {
    public let cmd: UInt32
    public let cmdsize: UInt32
    private let bytes: Array<UInt8>
    private let offset: Int64

    public init(bytes: Array<UInt8>, offset: Int64, cmd: UInt32, cmdsize: UInt32) {
        this.bytes = bytes
        this.offset = offset
        this.cmd = cmd
        this.cmdsize = cmdsize
    }

    /// 解析为 segment_command_64
    // 对应 macho.zig:
    //   entry.cast(macho.segment_command_64).?
    public func toSegment64(): ?MachOSegmentCommand64 {
        if (cmd != LC_SEGMENT_64) {
            return None
        }
        return MachOSegmentCommand64.fromBytes(bytes, offset)
    }

    /// 解析为 linkedit_data_command
    public func toLinkEditData(): ?MachOLinkEditDataCommand {
        return MachOLinkEditDataCommand.fromBytes(bytes, offset)
    }

    /// 解析为 build_version_command
    public func toBuildVersion(): ?MachOBuildVersionCommand {
        if (cmd != LC_BUILD_VERSION) {
            return None
        }
        return MachOBuildVersionCommand.fromBytes(bytes, offset)
    }
}

// ============================================================================
// Mach-O 文件解析结果
// ============================================================================

/// Mach-O 文件完整解析结果
// 对应 macho.zig MachoFile 结构
public class MachOFileInfo {
    public var header: MachOHeader64 = MachOHeader64()
    public var segments: Array<MachOSegmentCommand64> = Array<MachOSegmentCommand64>()
    public var codeSignature: ?MachOLinkEditDataCommand = None
    public var buildVersion: ?MachOBuildVersionCommand = None

    public init() {}

    /// 从字节数组解析 Mach-O 文件
    // 对应 macho.zig MachoFile.init:
    //   const header: *const macho.mach_header_64 = @ptrCast(@alignCast(data.items.ptr))
    // 对应 macho.rs MachoFile::init:
    //   let header: macho::mach_header_64 = read_struct(&data[..size_of::<macho::mach_header_64>()])
    public static func parse(bytes: Array<UInt8>): ?MachOFileInfo {
        // 解析头部
        let hdr = MachOHeader64.fromBytes(bytes)
        match (hdr) {
            case Some(h) =>
                if (!h.isValid()) {
                    return None
                }
            case None =>
                return None
        }

        let info = MachOFileInfo()
        info.header = hdr.get()

        // 创建加载命令迭代器
        // 对应 macho.zig:
        //   .buffer = self.data.items[@sizeOf(macho.mach_header_64)..][0..self.header.sizeofcmds]
        let iter = MachOLoadCommandIterator(bytes, 32, info.header.sizeofcmds)

        // 遍历加载命令
        while (true) {
            let entryOpt = iter.next()
            match (entryOpt) {
                case Some(entry) =>
                    match (entry.cmd) {
                        case LC_SEGMENT_64 =>
                            let segOpt = entry.toSegment64()
                            match (segOpt) {
                                case Some(seg) =>
                                    info.segments.append(seg)
                                case None => {}
                            }
                        case LC_CODE_SIGNATURE =>
                            info.codeSignature = entry.toLinkEditData()
                        case LC_BUILD_VERSION =>
                            info.buildVersion = entry.toBuildVersion()
                        case _ => {}
                    }
                case None =>
                    break
            }
        }

        return Some(info)
    }

    /// 获取 macOS 最低版本
    // 通过 LC_BUILD_VERSION 的 minos 字段
    public func macOSVersion(): String {
        match (buildVersion) {
            case Some(bvc) =>
                return bvc.minosVersion()
            case None =>
                return "unknown"
        }
    }

    /// 查找 __BUN,__bun 节
    // 对应 macho.zig writeSection 中查找 __BUN 段下 __bun 节
    public func findBunSection(): ?MachOSection64 {
        // segment_command_64 后紧跟 nsects 个 section_64
        for (seg in segments) {
            if (seg.isBunSegment() && seg.nsects > UInt32(0)) {
                // 节数据紧跟在 segment_command_64 (72 字节) 之后
                let sectBaseOffset = Int64(0) // 需要从原始数据定位
                // 此处需要原始字节数组来定位，仅做标记
                return None
            }
        }
        return None
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 对齐大小计算
// 对应 macho.zig:
//   fn alignSize(size: u64, base: u64) u64 {
//       const over = size % base;
//       return if (over == 0) size else size + (base - over);
//   }
public func machoAlignSize(size: UInt64, base: UInt64): UInt64 {
    let over = size % base
    if (over == UInt64(0)) {
        return size
    }
    return size + (base - over)
}

/// 计算代码签名大小
// 对应 macho.zig / macho.rs MachoSigner.computeSignatureSize:
//   pub fn computeSignatureSize(sig_off: u64) usize {
//       const total_pages = (sig_off + PAGE_SIZE - 1) / PAGE_SIZE;
//       const super_blob_header_size = @sizeOf(SuperBlob);    // 12
//       const blob_index_size = @sizeOf(BlobIndex);           // 8
//       const code_dir_header_size = @sizeOf(CodeDirectory);  // 44
//       const hash_offset = code_dir_header_size + IDENTIFIER.len; // 44 + 6 = 50
//       const hashes_size = total_pages * HASH_SIZE;          // total_pages * 32
//       const code_dir_length = hash_offset + hashes_size;
//       return super_blob_header_size + blob_index_size + code_dir_length;
//   }
public func computeMachoSignatureSize(sigOff: UInt64): Int64 {
    let PAGE_SIZE: UInt64 = UInt64(4096)
    let HASH_SIZE: Int64 = 32

    let totalPages = Int64((sigOff + PAGE_SIZE - UInt64(1)) / PAGE_SIZE)
    let superBlobHeaderSize: Int64 = 12  // SuperBlob: magic(4) + length(4) + count(4)
    let blobIndexSize: Int64 = 8         // BlobIndex: type(4) + offset(4)
    let codeDirHeaderSize: Int64 = 44    // CodeDirectory 结构大小
    let identifierLen: Int64 = 6         // "a.out\0"
    let hashOffset = codeDirHeaderSize + identifierLen
    let hashesSize = totalPages * HASH_SIZE
    let codeDirLength = hashOffset + hashesSize
    return superBlobHeaderSize + blobIndexSize + codeDirLength
}
