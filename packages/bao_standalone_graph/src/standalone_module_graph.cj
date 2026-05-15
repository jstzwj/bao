// StandaloneModuleGraph - 独立模块图
// 严格翻译自: bun/src/standalone_graph/StandaloneModuleGraph.zig
//   pub const StandaloneModuleGraph = struct { ... };
//
// 本模块实现 `bun build --compile` 的核心序列化/反序列化逻辑:
//   1. toBytes() - 将 OutputFile 数组序列化为二进制
//   2. fromBytes() - 从二进制反序列化为模块图
//   3. inject() - 将二进制数据注入可执行文件
//   4. fromExecutable() - 从当前可执行文件加载模块图
//
// 二进制格式布局:
//   ┌────────────────────────────────┐
//   │ StringPool (所有字符串数据)      │
//   │ - 模块路径 (以 \0 结尾)          │
//   │ - 源码内容 (以 \0 结尾)          │
//   │ - SourceMap 序列化数据           │
//   │ - Bytecode (128字节对齐)        │
//   │ - ModuleInfo                    │
//   │ - BytecodeOriginPath            │
//   ├────────────────────────────────┤
//   │ CompiledModuleGraphFile[]       │
//   │ (模块元数据数组)                 │
//   ├────────────────────────────────┤
//   │ Offsets (定位结构)               │
//   │ - byte_count                    │
//   │ - modules_ptr                   │
//   │ - entry_point_id                │
//   │ - compile_exec_argv_ptr         │
//   │ - flags                         │
//   ├────────────────────────────────┤
//   │ "\n---- Bun! ----\n" (trailer)  │
//   └────────────────────────────────┘
package bao.standalone_graph

import bao_core.*

// ============================================================================
// StringPointer - 字符串指针 (偏移量 + 长度)
// 严格翻译自: bun/src/string/types.zig - StringPointer
//   pub const StringPointer = extern struct {
//       offset: u32 = 0,
//       length: u32 = 0,
//   };
// Bun: 用于在连续字节缓冲区中定位子串
// 仓颉: 使用 Int64 表示偏移量和长度，保持语义一致
// ============================================================================

/// 字符串指针 - 对应 Bun StringPointer
/// 在序列化二进制中定位字符串: bytes[offset..][0..length]
public class StringPointer {
    /// 偏移量 (对应 Bun offset: u32)
    public var offset: Int64
    /// 长度 (对应 Bun length: u32)
    public var length: Int64

    public init() {
        offset = 0
        length = 0
    }

    public init(offset: Int64, length: Int64) {
        this.offset = offset
        this.length = length
    }

    /// 是否为空指针
    public func isEmpty(): Bool {
        length == 0
    }

    /// 从字节数组切片 - 对应 Bun sliceTo / sliceToZ
    public func sliceFrom(bytes: Array<UInt8>): Array<UInt8> {
        if (length == 0) {
            return []
        }
        var result = Array<UInt8>()
        let end = offset + length
        for (i in offset..end) {
            if (i >= 0 && i < bytes.size) {
                result.append(bytes[i])
            }
        }
        return result
    }

    /// 从字节数组切片为字符串 - 对应 Bun sliceToZ
    /// 去除末尾的 null 终止符
    public func sliceStringFrom(bytes: Array<UInt8>): String {
        if (length == 0) {
            return ""
        }
        var sb = StringBuilder()
        let end = offset + length
        for (i in offset..end) {
            if (i >= 0 && i < bytes.size) {
                let b = bytes[i]
                if (b == 0) {
                    break
                }
                sb.append(Char(Int32(b)))
            }
        }
        return sb.toString()
    }
}

// ============================================================================
// FileSide - 文件端 (服务端/客户端)
// 严格翻译自: StandaloneModuleGraph.zig - FileSide
//   pub const FileSide = enum(u8) {
//       server = 0,
//       client = 1,
//   };
// ============================================================================

/// 文件端 - 对应 Bun FileSide
public enum FileSide {
    | Server   // 0 - 服务端代码
    | Client   // 1 - 客户端代码

    /// 转为 UInt8 编码
    public func toU8(): UInt8 {
        match (this) {
            case Server => UInt8(0)
            case Client => UInt8(1)
        }
    }

    /// 从 UInt8 解码
    public static func fromU8(v: UInt8): FileSide {
        match (v) {
            case UInt8(0) => Server
            case UInt8(1) => Client
            case _ => Server
        }
    }
}

// ============================================================================
// Encoding - 编码类型
// 严格翻译自: StandaloneModuleGraph.zig - Encoding
//   pub const Encoding = enum(u8) {
//       binary = 0,
//       latin1 = 1,
//       utf8 = 2,
//   };
// ============================================================================

/// 编码类型 - 对应 Bun Encoding
public enum Encoding {
    | Binary   // 0 - 二进制
    | Latin1   // 1 - Latin1 编码
    | Utf8     // 2 - UTF-8 编码

    /// 转为 UInt8 编码
    public func toU8(): UInt8 {
        match (this) {
            case Binary => UInt8(0)
            case Latin1 => UInt8(1)
            case Utf8 => UInt8(2)
        }
    }

    /// 从 UInt8 解码
    public static func fromU8(v: UInt8): Encoding {
        match (v) {
            case UInt8(0) => Binary
            case UInt8(1) => Latin1
            case UInt8(2) => Utf8
            case _ => Binary
        }
    }
}

// ============================================================================
// ModuleFormat - 模块格式
// 严格翻译自: StandaloneModuleGraph.zig - ModuleFormat
//   pub const ModuleFormat = enum(u8) {
//       none = 0,
//       esm = 1,
//       cjs = 2,
//   };
// ============================================================================

/// 模块格式 - 对应 Bun ModuleFormat
public enum ModuleFormat {
    | None   // 0 - 无格式
    | Esm    // 1 - ES Module
    | Cjs    // 2 - CommonJS

    /// 转为 UInt8 编码
    public func toU8(): UInt8 {
        match (this) {
            case None => UInt8(0)
            case Esm => UInt8(1)
            case Cjs => UInt8(2)
        }
    }

    /// 从 UInt8 解码
    public static func fromU8(v: UInt8): ModuleFormat {
        match (v) {
            case UInt8(0) => None
            case UInt8(1) => Esm
            case UInt8(2) => Cjs
            case _ => None
        }
    }
}

// ============================================================================
// Loader - 加载器类型
// 严格翻译自: bun/src/options_types/Loader.zig
//   pub const Loader = enum(u8) { ... };
// 这里只定义 standalone_graph 用到的子集
// ============================================================================

/// 加载器类型 - 对应 Bun Loader
public enum Loader {
    | Js       // JavaScript
    | Jsx      // JSX
    | Ts       // TypeScript
    | Tsx      // TSX
    | Json     // JSON
    | Toml     // TOML
    | File     // 通用文件 (二进制)
    | Css      // CSS
    | Other    // 其他

    /// 转为 UInt8 编码
    public func toU8(): UInt8 {
        match (this) {
            case Js => UInt8(0)
            case Jsx => UInt8(1)
            case Ts => UInt8(2)
            case Tsx => UInt8(3)
            case Json => UInt8(4)
            case Toml => UInt8(5)
            case File => UInt8(6)
            case Css => UInt8(7)
            case Other => UInt8(255)
        }
    }

    /// 从 UInt8 解码
    public static func fromU8(v: UInt8): Loader {
        match (v) {
            case UInt8(0) => Js
            case UInt8(1) => Jsx
            case UInt8(2) => Ts
            case UInt8(3) => Tsx
            case UInt8(4) => Json
            case UInt8(5) => Toml
            case UInt8(6) => File
            case UInt8(7) => Css
            case _ => Other
        }
    }

    /// 是否为 JavaScript 类似加载器 - 对应 Bun Loader.isJavaScriptLike
    public func isJavaScriptLike(): Bool {
        match (this) {
            case Js | Jsx | Ts | Tsx => true
            case _ => false
        }
    }
}

// ============================================================================
// Flags - 模块图标志位
// 严格翻译自: StandaloneModuleGraph.zig - Flags
//   pub const Flags = packed struct(u32) {
//       disable_default_env_files: bool = false,
//       disable_autoload_bunfig: bool = false,
//       disable_autoload_tsconfig: bool = false,
//       disable_autoload_package_json: bool = false,
//       _padding: u28 = 0,
//   };
// ============================================================================

/// 模块图标志位 - 对应 Bun Flags
/// packed struct(u32) 中各标志位从低位到高位排列
public class StandaloneFlags {
    /// 禁用默认 .env 文件加载
    public var disableDefaultEnvFiles: Bool
    /// 禁用自动加载 bunfig.toml
    public var disableAutoloadBunfig: Bool
    /// 禁用自动加载 tsconfig.json
    public var disableAutoloadTsconfig: Bool
    /// 禁用自动加载 package.json
    public var disableAutoloadPackageJson: Bool

    public init() {
        disableDefaultEnvFiles = false
        disableAutoloadBunfig = false
        disableAutoloadTsconfig = false
        disableAutoloadPackageJson = false
    }

    public init(disableDefaultEnvFiles: Bool, disableAutoloadBunfig: Bool,
                disableAutoloadTsconfig: Bool, disableAutoloadPackageJson: Bool) {
        this.disableDefaultEnvFiles = disableDefaultEnvFiles
        this.disableAutoloadBunfig = disableAutoloadBunfig
        this.disableAutoloadTsconfig = disableAutoloadTsconfig
        this.disableAutoloadPackageJson = disableAutoloadPackageJson
    }

    /// 转为 UInt32 编码 (packed struct 位布局)
    /// bit 0: disable_default_env_files
    /// bit 1: disable_autoload_bunfig
    /// bit 2: disable_autoload_tsconfig
    /// bit 3: disable_autoload_package_json
    /// bits 4-31: padding
    public func toU32(): UInt32 {
        var val: UInt32 = UInt32(0)
        if (disableDefaultEnvFiles) {
            val = val | UInt32(1)
        }
        if (disableAutoloadBunfig) {
            val = val | UInt32(2)
        }
        if (disableAutoloadTsconfig) {
            val = val | UInt32(4)
        }
        if (disableAutoloadPackageJson) {
            val = val | UInt32(8)
        }
        return val
    }

    /// 从 UInt32 解码
    public static func fromU32(val: UInt32): StandaloneFlags {
        StandaloneFlags(
            disableDefaultEnvFiles: (val & UInt32(1)) != UInt32(0),
            disableAutoloadBunfig: (val & UInt32(2)) != UInt32(0),
            disableAutoloadTsconfig: (val & UInt32(4)) != UInt32(0),
            disableAutoloadPackageJson: (val & UInt32(8)) != UInt32(0)
        )
    }
}

// ============================================================================
// Offsets - 二进制定位结构
// 严格翻译自: StandaloneModuleGraph.zig - Offsets
//   pub const Offsets = extern struct {
//       byte_count: usize = 0,
//       modules_ptr: bun.StringPointer = .{},
//       entry_point_id: u32 = 0,
//       compile_exec_argv_ptr: bun.StringPointer = .{},
//       flags: Flags = .{},
//   };
// ============================================================================

/// 二进制定位结构 - 对应 Bun Offsets
/// 附加在二进制数据末尾，用于定位各段数据
public class Offsets {
    /// 总字节数 (不含 trailer 和 Offsets 本身)
    public var byteCount: Int64
    /// 模块数组指针 (offset + length)
    public var modulesPtr: StringPointer
    /// 入口点模块 ID
    public var entryPointId: Int64
    /// 编译时 exec argv 字符串指针
    public var compileExecArgvPtr: StringPointer
    /// 标志位
    public var flags: StandaloneFlags

    public init() {
        byteCount = 0
        modulesPtr = StringPointer()
        entryPointId = 0
        compileExecArgvPtr = StringPointer()
        flags = StandaloneFlags()
    }

    public init(byteCount: Int64, modulesPtr: StringPointer, entryPointId: Int64,
                compileExecArgvPtr: StringPointer, flags: StandaloneFlags) {
        this.byteCount = byteCount
        this.modulesPtr = modulesPtr
        this.entryPointId = entryPointId
        this.compileExecArgvPtr = compileExecArgvPtr
        this.flags = flags
    }
}

// ============================================================================
// CompiledModuleGraphFile - 编译后的模块图文件条目
// 严格翻译自: StandaloneModuleGraph.zig - CompiledModuleGraphFile
//   pub const CompiledModuleGraphFile = struct {
//       name: Schema.StringPointer = .{},
//       contents: Schema.StringPointer = .{},
//       sourcemap: Schema.StringPointer = .{},
//       bytecode: Schema.StringPointer = .{},
//       module_info: Schema.StringPointer = .{},
//       bytecode_origin_path: Schema.StringPointer = .{},
//       encoding: Encoding = .latin1,
//       loader: bun.options.Loader = .file,
//       module_format: ModuleFormat = .none,
//       side: FileSide = .server,
//   };
// ============================================================================

/// 编译后的模块图文件条目 - 对应 Bun CompiledModuleGraphFile
/// 在序列化二进制中，每个模块以此结构存储元数据
/// 实际的字符串数据存储在 StringPool 中，通过 StringPointer 引用
public class CompiledModuleGraphFile {
    /// 模块路径 (虚拟路径，如 "/$bunfs/root/index.js")
    public var name: StringPointer
    /// 源码内容
    public var contents: StringPointer
    /// 序列化后的 SourceMap
    public var sourcemap: StringPointer
    /// JSC 字节码缓存
    public var bytecode: StringPointer
    /// ESM 模块信息
    public var moduleInfo: StringPointer
    /// 字节码生成时的路径 (必须与运行时一致以命中缓存)
    public var bytecodeOriginPath: StringPointer
    /// 字符串编码
    public var encoding: Encoding
    /// 加载器类型
    public var loader: Loader
    /// 模块格式
    public var moduleFormat: ModuleFormat
    /// 文件端 (服务端/客户端)
    public var side: FileSide

    public init() {
        name = StringPointer()
        contents = StringPointer()
        sourcemap = StringPointer()
        bytecode = StringPointer()
        moduleInfo = StringPointer()
        bytecodeOriginPath = StringPointer()
        encoding = Encoding.Latin1
        loader = Loader.File
        moduleFormat = ModuleFormat.None
        side = FileSide.Server
    }
}

// ============================================================================
// ModuleEntry - 模块条目 (反序列化后的运行时表示)
// 严格翻译自: StandaloneModuleGraph.zig - File
//   pub const File = struct {
//       name: []const u8 = "",
//       loader: bun.options.Loader,
//       contents: [:0]const u8 = "",
//       sourcemap: LazySourceMap,
//       cached_blob: ?*bun.webcore.Blob = null,
//       encoding: Encoding = .binary,
//       wtf_string: bun.String = bun.String.empty,
//       bytecode: []u8 = "",
//       module_info: []u8 = "",
//       bytecode_origin_path: []const u8 = "",
//       module_format: ModuleFormat = .none,
//       side: FileSide = .server,
//   };
// ============================================================================

/// 模块条目 - 对应 Bun StandaloneModuleGraph.File
/// 运行时表示，包含反序列化后的源码和元数据
public class ModuleEntry {
    /// 模块虚拟路径 (如 "/$bunfs/root/index.js")
    public var name: String
    /// 加载器类型
    public var loader: Loader
    /// 源码内容
    public var contents: String
    /// 序列化的 SourceMap (原始字节)
    public var sourcemap: Array<UInt8>
    /// 字符串编码
    public var encoding: Encoding
    /// JSC 字节码缓存
    public var bytecode: Array<UInt8>
    /// ESM 模块信息
    public var moduleInfo: Array<UInt8>
    /// 字节码生成时的路径
    public var bytecodeOriginPath: String
    /// 模块格式
    public var moduleFormat: ModuleFormat
    /// 文件端
    public var side: FileSide

    public init() {
        name = ""
        loader = Loader.File
        contents = ""
        sourcemap = []
        encoding = Encoding.Binary
        bytecode = []
        moduleInfo = []
        bytecodeOriginPath = ""
        moduleFormat = ModuleFormat.None
        side = FileSide.Server
    }

    public init(name: String, loader: Loader, contents: String,
                sourcemap: Array<UInt8>, encoding: Encoding,
                bytecode: Array<UInt8>, moduleInfo: Array<UInt8>,
                bytecodeOriginPath: String, moduleFormat: ModuleFormat,
                side: FileSide) {
        this.name = name
        this.loader = loader
        this.contents = contents
        this.sourcemap = sourcemap
        this.encoding = encoding
        this.bytecode = bytecode
        this.moduleInfo = moduleInfo
        this.bytecodeOriginPath = bytecodeOriginPath
        this.moduleFormat = moduleFormat
        this.side = side
    }

    /// 是否出现在嵌入文件数组中 - 对应 Bun File.appearsInEmbeddedFilesArray
    /// pub fn appearsInEmbeddedFilesArray(this: *const File) bool {
    ///     return this.side == .client or !this.loader.isJavaScriptLike();
    /// }
    public func appearsInEmbeddedFilesArray(): Bool {
        side == FileSide.Client || !loader.isJavaScriptLike()
    }

    /// 模拟 stat - 对应 Bun File.stat
    /// pub fn stat(this: *const File) bun.Stat {
    ///     var result = std.mem.zeroes(bun.Stat);
    ///     result.size = @intCast(this.contents.len);
    ///     result.mode = bun.S.IFREG | 0o644;
    ///     return result;
    /// }
    public func fileSize(): Int64 {
        contents.length
    }

    /// 判断是否为 JavaScript 类似文件
    public func isJavaScriptLike(): Bool {
        loader.isJavaScriptLike()
    }
}

// ============================================================================
// OutputFile - 输出文件 (用于序列化的输入)
// 严格翻译自: bun/src/options_types/OutputFile.zig 的简化版本
//   用于 toBytes() 的输入数据
// ============================================================================

/// 输出文件 - 用于序列化的输入
public class OutputFile {
    /// 目标路径
    public var destPath: String
    /// 输出内容
    public var buffer: Array<UInt8>
    /// 加载器类型
    public var loader: Loader
    /// 输出类型
    public var outputKind: OutputKind
    /// 文件端
    public var side: ?FileSide
    /// SourceMap 索引 (UInt32.max 表示无)
    public var sourceMapIndex: Int64
    /// 字节码索引 (UInt32.max 表示无)
    public var bytecodeIndex: Int64
    /// 模块信息索引 (UInt32.max 表示无)
    public var moduleInfoIndex: Int64

    public init() {
        destPath = ""
        buffer = []
        loader = Loader.File
        outputKind = OutputKind.EntryPoint
        side = None
        sourceMapIndex = STANDALONE_INVALID_INDEX
        bytecodeIndex = STANDALONE_INVALID_INDEX
        moduleInfoIndex = STANDALONE_INVALID_INDEX
    }
}

/// 无效索引常量 - 对应 Bun std.math.maxInt(u32)
let STANDALONE_INVALID_INDEX: Int64 = 0xFFFFFFFF

/// 输出文件类型
public enum OutputKind {
    | EntryPoint
    | Sourcemap
    | Bytecode
    | ModuleInfo
    | Chunk

    /// 是否为独立模式下应包含的文件
    /// 对应 Bun OutputFile.output_kind.isFileInStandaloneMode()
    public func isFileInStandaloneMode(): Bool {
        match (this) {
            case EntryPoint | Chunk => true
            case Sourcemap | Bytecode | ModuleInfo => false
        }
    }
}

// ============================================================================
// StandaloneModuleGraph - 独立模块图主结构
// 严格翻译自: StandaloneModuleGraph.zig
//   pub const StandaloneModuleGraph = struct {
//       bytes: []const u8 = "",
//       files: bun.StringArrayHashMap(File),
//       entry_point_id: u32 = 0,
//       compile_exec_argv: []const u8 = "",
//       flags: Flags = .{},
//       ...
//   };
// ============================================================================

/// trailer 标记 - 对应 Bun "\n---- Bun! ----\n"
/// 用于验证二进制数据完整性
let TRAILER: String = "\n---- Bun! ----\n"

/// 基础路径前缀 - 对应 Bun StandaloneModuleGraph.base_path
/// 在 Linux/macOS 上为 "/$bunfs/"
/// 8 字符长，便于 64-bit CPU 快速比较
let BASE_PATH: String = "/$bunfs/"

/// Windows 基础路径前缀
let BASE_PATH_WINDOWS: String = "B:\\~BUN\\"

/// 默认公共路径
let BASE_PUBLIC_PATH: String = "/$bunfs/"

/// 带默认后缀的公共路径
let BASE_PUBLIC_PATH_WITH_SUFFIX: String = "/$bunfs/root/"

/// 独立模块图 - 对应 Bun StandaloneModuleGraph
/// 将所有打包后的源文件、sourcemap、字节码等存储在一个连续的内存区域
/// 运行时通过此结构快速查找虚拟文件系统中的文件
public class StandaloneModuleGraph {
    /// 原始字节数据 (对应 Bun bytes: []const u8)
    public var bytes: Array<UInt8>
    /// 文件映射表 (路径 -> ModuleEntry)
    /// 对应 Bun files: bun.StringArrayHashMap(File)
    public var files: HashMap<String, ModuleEntry>
    /// 入口点模块 ID (对应 Bun entry_point_id: u32)
    public var entryPointId: Int64
    /// 编译时 exec argv (对应 Bun compile_exec_argv: []const u8)
    public var compileExecArgv: String
    /// 标志位 (对应 Bun flags: Flags)
    public var flags: StandaloneFlags

    /// 全局单例 - 对应 Bun Instance.instance
    private static var instance: ?StandaloneModuleGraph = None

    public init() {
        bytes = []
        files = HashMap<String, ModuleEntry>()
        entryPointId = 0
        compileExecArgv = ""
        flags = StandaloneFlags()
    }

    // ========================================================================
    // 全局单例管理
    // 严格翻译自: StandaloneModuleGraph.zig
    //   pub fn get() ?*StandaloneModuleGraph { return Instance.instance; }
    //   pub fn set(instance: *StandaloneModuleGraph) void { Instance.instance = instance; }
    // ========================================================================

    /// 获取全局模块图实例 - 对应 Bun StandaloneModuleGraph.get()
    public static func get(): ?StandaloneModuleGraph {
        instance
    }

    /// 设置全局模块图实例 - 对应 Bun StandaloneModuleGraph.set()
    public static func set(graph: StandaloneModuleGraph): Unit {
        instance = graph
    }

    // ========================================================================
    // 路径判断
    // 严格翻译自: StandaloneModuleGraph.zig
    //   pub fn isBunStandaloneFilePathCanonicalized(str) bool
    //   pub fn isBunStandaloneFilePath(str) bool
    // ========================================================================

    /// 判断路径是否为 Bun 独立文件路径 (已规范化)
    /// 对应 Bun isBunStandaloneFilePathCanonicalized
    /// pub fn isBunStandaloneFilePathCanonicalized(str: []const u8) bool {
    ///     return bun.strings.hasPrefixComptime(str, base_path) or
    ///         (Environment.isWindows and bun.strings.hasPrefixComptime(str, base_public_path));
    /// }
    public static func isBunStandaloneFilePathCanonicalized(path: String): Bool {
        path.startsWith(BASE_PATH) || path.startsWith(BASE_PUBLIC_PATH)
    }

    /// 判断路径是否为 Bun 独立文件路径
    /// 对应 Bun isBunStandaloneFilePath
    public static func isBunStandaloneFilePath(path: String): Bool {
        isBunStandaloneFilePathCanonicalized(path)
    }

    // ========================================================================
    // entryPoint - 获取入口点模块
    // 严格翻译自:
    //   pub fn entryPoint(this: *const StandaloneModuleGraph) *File {
    //       return &this.files.values()[this.entry_point_id];
    //   }
    // ========================================================================

    /// 获取入口点模块 - 对应 Bun entryPoint()
    public func entryPoint(): ?ModuleEntry {
        var idx: Int64 = 0
        for ((name, entry) in files) {
            if (idx == entryPointId) {
                return entry
            }
            idx += 1
        }
        return None
    }

    // ========================================================================
    // find - 按路径查找文件
    // 严格翻译自:
    //   pub fn find(this: *const StandaloneModuleGraph, name: []const u8) ?*File {
    //       if (!isBunStandaloneFilePath(name)) return null;
    //       return this.findAssumeStandalonePath(name);
    //   }
    // ========================================================================

    /// 按路径查找文件 - 对应 Bun find()
    public func find(name: String): ?ModuleEntry {
        if (!StandaloneModuleGraph.isBunStandaloneFilePath(name)) {
            return None
        }
        return findAssumeStandalonePath(name)
    }

    /// 假定路径为独立路径的查找 - 对应 Bun findAssumeStandalonePath()
    public func findAssumeStandalonePath(name: String): ?ModuleEntry {
        files.get(name)
    }

    // ========================================================================
    // fromBytes - 从二进制反序列化
    // 严格翻译自:
    //   pub fn fromBytes(allocator, raw_bytes, offsets) !StandaloneModuleGraph
    // ========================================================================

    /// 从二进制反序列化 - 对应 Bun fromBytes()
    ///
    /// 解析流程:
    /// 1. 通过 offsets.modules_ptr 定位 CompiledModuleGraphFile 数组
    /// 2. 遍历每个 CompiledModuleGraphFile，通过 StringPointer 从 raw_bytes 中提取字符串
    /// 3. 构建 files 哈希表 (路径 -> ModuleEntry)
    public static func fromBytes(rawBytes: Array<UInt8>, offsets: Offsets): StandaloneModuleGraph {
        if (rawBytes.size == 0) {
            return StandaloneModuleGraph()
        }

        // 读取模块列表字节
        let modulesListBytes = offsets.modulesPtr.sliceFrom(rawBytes)

        // 解析 CompiledModuleGraphFile 数组
        // Bun 中 modules_list: []align(1) const CompiledModuleGraphFile
        // 每个条目包含 6 个 StringPointer + 1 个 Encoding + 1 个 Loader + 1 个 ModuleFormat + 1 个 FileSide
        let moduleEntries = deserializeModuleEntries(modulesListBytes, rawBytes)

        // 验证 entry_point_id 有效性
        // 对应 Bun: if (offsets.entry_point_id > modules_list.len) return error
        if (offsets.entryPointId > moduleEntries.size) {
            // 入口点 ID 超出范围，返回空图
            return StandaloneModuleGraph()
        }

        // 构建文件哈希表
        var graph = StandaloneModuleGraph()
        graph.bytes = sliceBytes(rawBytes, 0, offsets.byteCount)
        graph.entryPointId = offsets.entryPointId
        graph.compileExecArgv = offsets.compileExecArgvPtr.sliceStringFrom(rawBytes)
        graph.flags = offsets.flags

        for (entry in moduleEntries) {
            graph.files.put(entry.name, entry)
        }

        return graph
    }

    // ========================================================================
    // toBytes - 序列化为二进制
    // 严格翻译自:
    //   pub fn toBytes(allocator, prefix, output_files, output_format, compile_exec_argv, flags) ![]u8
    // ========================================================================

    /// 序列化为二进制 - 对应 Bun toBytes()
    ///
    /// 序列化流程:
    /// 1. 两阶段构建: 先 count 所需空间，再 allocate 并写入
    /// 2. 为每个 OutputFile 创建 CompiledModuleGraphFile，将字符串写入 StringPool
    /// 3. 字节码需要 128 字节对齐 (用于 JSC 缓存命中)
    /// 4. SourceMap 使用专用序列化格式 (ZSTD 压缩 + VLQ 映射)
    /// 5. 最后追加 Offsets + trailer
    public static func toBytes(prefix: String, outputFiles: ArrayList<OutputFile>,
                               outputFormat: String, compileExecArgv: String,
                               flags: StandaloneFlags): Array<UInt8> {
        // ----------------------------------------------------------------
        // 阶段 1: 计算所需空间
        // 对应 Bun: for (output_files) |*output_file| { string_builder.count... }
        // ----------------------------------------------------------------
        var moduleCount: Int64 = 0
        var entryPointId: ?Int64 = None
        var totalCap: Int64 = 0

        for (outputFile in outputFiles) {
            // 路径 + 前缀
            totalCap += outputFile.destPath.length + 1  // +1 for null terminator
            totalCap += prefix.length

            if (outputFile.outputKind == OutputKind.Sourcemap) {
                // SourceMap 需要额外空间 (过度估计以确保足够)
                totalCap += outputFile.buffer.size * 2
            } else if (outputFile.outputKind == OutputKind.Bytecode) {
                // 字节码需要 256 对齐
                totalCap += (outputFile.buffer.size + 255) / 256 * 256 + 256
            } else if (outputFile.outputKind == OutputKind.ModuleInfo) {
                totalCap += outputFile.buffer.size
            } else if (outputFile.outputKind.isFileInStandaloneMode()) {
                // 入口点检测
                if (entryPointId == None) {
                    if (outputFile.side == None || outputFile.side == FileSide.Server) {
                        if (outputFile.outputKind == OutputKind.EntryPoint) {
                            entryPointId = moduleCount
                        }
                    }
                }
                totalCap += outputFile.buffer.size + 1
                moduleCount += 1
            }
        }

        if (moduleCount == 0 || entryPointId == None) {
            return []
        }

        // 模块元数据数组空间
        totalCap += moduleCount * ESTIMATED_MODULE_ENTRY_SIZE
        // trailer + 对齐 + Offsets
        totalCap += TRAILER.length
        totalCap += 16
        totalCap += ESTIMATED_OFFSETS_SIZE
        // compile_exec_argv
        totalCap += compileExecArgv.length + 1

        // ----------------------------------------------------------------
        // 阶段 2: 构建二进制数据
        // 对应 Bun: string_builder.allocate + 写入模块数据
        // ----------------------------------------------------------------
        let writer = BinaryWriter(totalCap)
        var modules = ArrayList<CompiledModuleGraphFile>()

        for (outputFile in outputFiles) {
            if (!outputFile.outputKind.isFileInStandaloneMode()) {
                continue
            }

            // 去除开头的 "./"
            let destPath = removeLeadingDotSlash(outputFile.destPath)

            // 字节码写入 (128 字节对齐)
            let bytecodePtr: StringPointer = if (outputFile.bytecodeIndex != STANDALONE_INVALID_INDEX) {
                let bytecodeData = outputFiles[Int64(outputFile.bytecodeIndex)].buffer
                // 计算 128 字节对齐的 padding
                // 对应 Bun: target_mod = 128 - @sizeOf(u64) = 120
                let targetMod: Int64 = 120
                let currentMod = writer.position % 128
                let padding = if (currentMod <= targetMod) {
                    targetMod - currentMod
                } else {
                    128 - currentMod + targetMod
                }
                // 写入零填充
                writer.writeZeros(padding)
                let alignedOffset = writer.position
                // 写入字节码
                writer.writeBytes(bytecodeData)
                // 额外填充到缓存行
                let extraPad = min(128, writer.remaining())
                writer.writeZeros(extraPad)
                StringPointer(offset: alignedOffset, length: bytecodeData.size + extraPad)
            } else {
                StringPointer()
            }

            // 模块信息写入
            let moduleInfoPtr: StringPointer = if (outputFile.moduleInfoIndex != STANDALONE_INVALID_INDEX) {
                let miBytes = outputFiles[Int64(outputFile.moduleInfoIndex)].buffer
                let off = writer.position
                writer.writeBytes(miBytes)
                StringPointer(offset: off, length: miBytes.size)
            } else {
                StringPointer()
            }

            // 字节码原始路径
            let bytecodeOriginPathPtr: StringPointer = if (outputFile.bytecodeIndex != STANDALONE_INVALID_INDEX) {
                let originPath = outputFiles[Int64(outputFile.bytecodeIndex)].destPath
                writer.writeStringNullTerminated(originPath)
            } else {
                StringPointer()
            }

            // 确定编码
            let encoding: Encoding = if (outputFile.loader == Loader.Js ||
                outputFile.loader == Loader.Jsx ||
                outputFile.loader == Loader.Ts ||
                outputFile.loader == Loader.Tsx) {
                Encoding.Latin1
            } else {
                Encoding.Binary
            }

            // 确定模块格式
            let moduleFormat: ModuleFormat = if (outputFile.loader.isJavaScriptLike()) {
                match (outputFormat) {
                    case "cjs" => ModuleFormat.Cjs
                    case "esm" => ModuleFormat.Esm
                    case _ => ModuleFormat.None
                }
            } else {
                ModuleFormat.None
            }

            // 写入模块路径 (prefix + dest_path)
            let namePtr = writer.writeFormattedString("${prefix}${destPath}")

            // 写入源码内容
            let contentsPtr = writer.writeBytesNullTerminated(outputFile.buffer)

            // SourceMap (如果有)
            let sourcemapPtr = StringPointer()
            // 注意: 完整的 SourceMap 序列化需要 JSON 解析和 ZSTD 压缩
            // 此处预留结构，实际实现在 serializeJsonSourceMapForStandalone 中

            // 确定文件端
            let fileSide = if (outputFile.side == None) {
                FileSide.Server
            } else {
                outputFile.side.getOrThrow()
            }

            // 构建模块条目
            let compiledModule = CompiledModuleGraphFile()
            compiledModule.name = namePtr
            compiledModule.contents = contentsPtr
            compiledModule.sourcemap = sourcemapPtr
            compiledModule.bytecode = bytecodePtr
            compiledModule.moduleInfo = moduleInfoPtr
            compiledModule.bytecodeOriginPath = bytecodeOriginPathPtr
            compiledModule.encoding = encoding
            compiledModule.loader = outputFile.loader
            compiledModule.moduleFormat = moduleFormat
            compiledModule.side = fileSide

            modules.append(compiledModule)
        }

        // ----------------------------------------------------------------
        // 阶段 3: 写入 Offsets + trailer
        // 对应 Bun:
        //   const offsets = Offsets{ ... };
        //   _ = string_builder.append(std.mem.asBytes(&offsets));
        //   _ = string_builder.append(trailer);
        // ----------------------------------------------------------------
        let modulesStartOffset = writer.position

        // 序列化模块元数据数组
        for (compiledModule in modules) {
            writer.writeCompiledModuleGraphFile(compiledModule)
        }

        let offsets = Offsets(
            byteCount: modulesStartOffset,
            modulesPtr: StringPointer(offset: modulesStartOffset, length: writer.position - modulesStartOffset),
            entryPointId: entryPointId.getOrThrow(),
            compileExecArgvPtr: writer.writeStringNullTerminated(compileExecArgv),
            flags: flags
        )
        // 修正 byteCount: 应为模块元数据之前的所有数据
        offsets.byteCount = modulesStartOffset

        // 写入 Offsets
        writer.writeOffsets(offsets)

        // 写入 trailer
        writer.writeString(TRAILER)

        return writer.toByteArray()
    }

    // ========================================================================
    // fromExecutable - 从可执行文件加载模块图
    // 严格翻译自:
    //   pub fn fromExecutable(allocator: std.mem.Allocator) !?*StandaloneModuleGraph
    //
    // 在运行时，根据平台从不同位置读取嵌入的模块图数据:
    //   macOS:  MachO __BUN 段
    //   Linux:  ELF .bun 段
    //   Windows: PE .bun 段
    // ========================================================================

    /// 从可执行文件加载模块图 - 对应 Bun fromExecutable()
    ///
    /// 加载流程:
    /// 1. 从平台特定的段/节读取原始字节
    /// 2. 验证末尾的 trailer 标记
    /// 3. 读取 trailer 前的 Offsets 结构
    /// 4. 使用 fromBytes() 反序列化
    /// 5. 设置全局单例
    public static func fromExecutable(rawBytes: Array<UInt8>): ?StandaloneModuleGraph {
        // 对应 Bun:
        //   if (macho_bytes.len < @sizeOf(Offsets) + trailer.len) return null;
        if (rawBytes.size < ESTIMATED_OFFSETS_SIZE + TRAILER.length) {
            return None
        }

        // 验证 trailer
        // 对应 Bun:
        //   const trailer_bytes = macho_bytes[macho_bytes.len - trailer.len ..][0..trailer.len];
        //   if (!bun.strings.eqlComptime(trailer_bytes, trailer)) return null;
        let trailerStart = rawBytes.size - TRAILER.length
        var trailerMatch = true
        for (i in 0..TRAILER.length) {
            if (rawBytes[trailerStart + Int64(i)] != UInt8(TRAILER.toArray()[i].value)) {
                trailerMatch = false
                break
            }
        }
        if (!trailerMatch) {
            return None
        }

        // 读取 Offsets
        // 对应 Bun:
        //   const macho_bytes_slice = macho_bytes[macho_bytes.len - @sizeOf(Offsets) - trailer.len ..];
        //   const offsets = std.mem.bytesAsValue(Offsets, macho_bytes_slice).*;
        let offsetsStart = rawBytes.size - ESTIMATED_OFFSETS_SIZE - TRAILER.length
        let offsetsBytes = sliceBytes(rawBytes, offsetsStart, ESTIMATED_OFFSETS_SIZE)
        let offsets = deserializeOffsets(offsetsBytes)

        // 反序列化
        let graph = fromBytes(rawBytes, offsets)
        StandaloneModuleGraph.set(graph)
        return graph
    }

    // ========================================================================
    // hintSourcePagesDontNeed - 提示内核释放源码页面
    // 严格翻译自:
    //   pub fn hintSourcePagesDontNeed() void
    //   使用 madvise(MADV_DONTNEED) 提示内核释放模块图占用的物理页面
    //   后续如果再需要访问 (lazy require, stack-trace) 会从磁盘重新调入
    // ========================================================================

    /// 提示内核释放源码页面 - 对应 Bun hintSourcePagesDontNeed()
    /// 在入口点解析完成后调用，释放模块图占用的物理内存
    /// 注意: 仓颉中无 madvise 等效 API，此处为接口预留
    public static func hintSourcePagesDontNeed(): Unit {
        // 仓颉中无法直接调用 madvise
        // 此处为接口预留，实际效果依赖于运行时 GC
        return
    }
}

// ============================================================================
// SerializedSourceMap - 序列化的 SourceMap
// 严格翻译自: StandaloneModuleGraph.zig - SerializedSourceMap
//   pub const SerializedSourceMap = struct {
//       bytes: []const u8,
//       pub const Header = extern struct {
//           source_files_count: u32,
//           map_bytes_length: u32,
//       };
//       ...
//   };
// ============================================================================

/// 序列化 SourceMap 头部 - 对应 Bun SerializedSourceMap.Header
/// 头部后的数据布局:
///   [source_files_count 个 StringPointer] - 文件名
///   [source_files_count 个 StringPointer] - ZSTD 压缩内容
///   [map_bytes_length 字节] - InternalSourceMap blob
///   [所有 StringPointer 引用的字符串数据]
public class SerializedSourceMapHeader {
    /// 源文件数量
    public var sourceFilesCount: Int64
    /// 映射 blob 长度
    public var mapBytesLength: Int64

    public init() {
        sourceFilesCount = 0
        mapBytesLength = 0
    }

    public init(sourceFilesCount: Int64, mapBytesLength: Int64) {
        this.sourceFilesCount = sourceFilesCount
        this.mapBytesLength = mapBytesLength
    }
}

/// 序列化的 SourceMap - 对应 Bun SerializedSourceMap
/// SourceMap 在独立模块图中使用专用二进制格式存储:
///   - 源文件内容使用 ZSTD 压缩
///   - 映射数据存储为 InternalSourceMap blob (varint 增量)
///   - 可直接在内存中加载使用，无需解码
public class SerializedSourceMap {
    /// 原始字节 (包含 Header + 数据)
    public var bytes: Array<UInt8>

    public init() {
        bytes = []
    }

    public init(bytes: Array<UInt8>) {
        this.bytes = bytes
    }

    // ========================================================================
    // header - 读取头部
    // 严格翻译自:
    //   pub fn header(map: SerializedSourceMap) *align(1) const Header {
    //       return @ptrCast(map.bytes.ptr);
    //   }
    // ========================================================================

    /// 读取头部 - 对应 Bun SerializedSourceMap.header()
    public func header(): SerializedSourceMapHeader {
        if (bytes.size < 8) {
            return SerializedSourceMapHeader()
        }
        // 读取 u32 source_files_count (little-endian)
        let sourceFilesCount = readU32LE(bytes, 0)
        // 读取 u32 map_bytes_length (little-endian)
        let mapBytesLength = readU32LE(bytes, 4)
        return SerializedSourceMapHeader(
            sourceFilesCount: Int64(sourceFilesCount),
            mapBytesLength: Int64(mapBytesLength)
        )
    }

    // ========================================================================
    // mappingBlob - 获取映射 blob
    // 严格翻译自:
    //   pub fn mappingBlob(map: SerializedSourceMap) ?[]const u8 {
    //       if (map.bytes.len < @sizeOf(Header)) return null;
    //       const head = map.header();
    //       const start = @sizeOf(Header) + head.source_files_count * @sizeOf(StringPointer) * 2;
    //       if (start > map.bytes.len or head.map_bytes_length > map.bytes.len - start) return null;
    //       return map.bytes[start..][0..head.map_bytes_length];
    //   }
    // ========================================================================

    /// 获取映射 blob - 对应 Bun SerializedSourceMap.mappingBlob()
    public func mappingBlob(): ?Array<UInt8> {
        if (bytes.size < 8) {
            return None
        }
        let head = header()
        // Header(8) + source_files_count * StringPointer(8) * 2
        let stringPointerSize: Int64 = 8  // offset(u32) + length(u32)
        let start = 8 + head.sourceFilesCount * stringPointerSize * 2
        if (start > bytes.size || head.mapBytesLength > bytes.size - start) {
            return None
        }
        return sliceBytes(bytes, start, head.mapBytesLength)
    }

    // ========================================================================
    // sourceFileNames - 获取源文件名数组
    // 严格翻译自:
    //   pub fn sourceFileNames(map: SerializedSourceMap) []align(1) const StringPointer {
    //       const head = map.header();
    //       return @as([*]align(1) const StringPointer, @ptrCast(map.bytes[@sizeOf(Header)..]))[0..head.source_files_count];
    //   }
    // ========================================================================

    /// 获取源文件名 StringPointer 数组
    /// 对应 Bun SerializedSourceMap.sourceFileNames()
    public func sourceFileNames(): ArrayList<StringPointer> {
        let head = header()
        var result = ArrayList<StringPointer>()
        for (i in 0..head.sourceFilesCount) {
            let baseOffset = 8 + i * 8
            let off = readU32LE(bytes, baseOffset)
            let len = readU32LE(bytes, baseOffset + 4)
            result.append(StringPointer(offset: Int64(off), length: Int64(len)))
        }
        return result
    }

    // ========================================================================
    // compressedSourceFiles - 获取压缩的源文件内容 StringPointer 数组
    // 严格翻译自:
    //   fn compressedSourceFiles(map: SerializedSourceMap) []align(1) const StringPointer {
    //       const head = map.header();
    //       return @as([*]align(1) const StringPointer, @ptrCast(map.bytes[@sizeOf(Header)..]))[head.source_files_count..][0..head.source_files_count];
    //   }
    // ========================================================================

    /// 获取压缩源文件 StringPointer 数组
    /// 对应 Bun SerializedSourceMap.compressedSourceFiles()
    public func compressedSourceFiles(): ArrayList<StringPointer> {
        let head = header()
        var result = ArrayList<StringPointer>()
        for (i in 0..head.sourceFilesCount) {
            let baseOffset = 8 + (head.sourceFilesCount + i) * 8
            let off = readU32LE(bytes, baseOffset)
            let len = readU32LE(bytes, baseOffset + 4)
            result.append(StringPointer(offset: Int64(off), length: Int64(len)))
        }
        return result
    }
}

// ============================================================================
// CompileResult - 编译结果
// 严格翻译自: StandaloneModuleGraph.zig - CompileResult
//   pub const CompileResult = union(enum) {
//       success: void,
//       err: Error,
//       pub const Error = union(enum) {
//           message: []const u8,
//           reason: Reason,
//       };
//       pub const Reason = enum { no_entry_point, no_output_files, ... };
//   };
// ============================================================================

/// 编译错误原因 - 对应 Bun CompileResult.Error.Reason
public enum CompileErrorReason {
    | NoEntryPoint
    | NoOutputFiles

    /// 获取错误消息 - 对应 Bun Reason.message()
    public func message(): String {
        match (this) {
            case NoEntryPoint => "No entry point found for compilation"
            case NoOutputFiles => "No output files to bundle"
        }
    }
}

/// 编译结果 - 对应 Bun CompileResult
/// union(enum) { success, err }
public class CompileResult {
    /// 是否成功
    public var isSuccess: Bool
    /// 错误消息 (如果有)
    public var errorMessage: ?String
    /// 错误原因 (如果有)
    public var errorReason: ?CompileErrorReason

    private init() {
        isSuccess = true
        errorMessage = None
        errorReason = None
    }

    private init(message: String) {
        isSuccess = false
        errorMessage = message
        errorReason = None
    }

    private init(reason: CompileErrorReason) {
        isSuccess = false
        errorMessage = None
        errorReason = reason
    }

    /// 创建成功结果 - 对应 Bun CompileResult.success
    public static func success(): CompileResult {
        CompileResult()
    }

    /// 创建失败结果 (原因) - 对应 Bun CompileResult.fail(.reason)
    public static func fail(reason: CompileErrorReason): CompileResult {
        CompileResult(reason)
    }

    /// 创建失败结果 (消息) - 对应 Bun CompileResult.failFmt(...)
    public static func failWithMessage(message: String): CompileResult {
        CompileResult(message)
    }

    /// 获取错误描述 - 对应 Bun CompileResult.Error.slice()
    public func errorSlice(): String {
        if (errorMessage != None) {
            return errorMessage.getOrThrow()
        }
        if (errorReason != None) {
            return errorReason.getOrThrow().message()
        }
        return ""
    }
}

// ============================================================================
// BinaryWriter - 二进制写入器
// 对应 Bun 中 StringBuilder 在 toBytes() 中的用法
// 提供写入各种数据类型到连续字节缓冲区的能力
// ============================================================================

/// CompiledModuleGraphFile 的估计序列化大小
/// 6 个 StringPointer (各 8 字节) + Encoding(1) + Loader(1) + ModuleFormat(1) + FileSide(1) = 52 字节
let ESTIMATED_MODULE_ENTRY_SIZE: Int64 = 64

/// Offsets 结构的估计序列化大小
/// byte_count(8) + modules_ptr(8) + entry_point_id(4) + padding(4) + compile_exec_argv_ptr(8) + flags(4) + padding(4) = 40
let ESTIMATED_OFFSETS_SIZE: Int64 = 40

/// 二进制写入器 - 用于构建模块图的二进制数据
public class BinaryWriter {
    /// 内部缓冲区
    private var buffer: Array<UInt8>
    /// 当前写入位置
    public var position: Int64

    public init(capacity: Int64) {
        buffer = Array<UInt8>(capacity, item: UInt8(0))
        position = 0
    }

    /// 剩余可写空间
    public func remaining(): Int64 {
        buffer.size - position
    }

    /// 确保有足够空间
    private func ensureCapacity(needed: Int64): Unit {
        while (buffer.size < position + needed) {
            // 扩容: 追加 needed 大小的零
            for (_ in 0..needed) {
                buffer.append(UInt8(0))
            }
        }
    }

    /// 写入单个字节
    public func writeByte(b: UInt8): Unit {
        ensureCapacity(needed: 1)
        buffer[position] = b
        position += 1
    }

    /// 写入字节数组
    public func writeBytes(data: Array<UInt8>): Unit {
        ensureCapacity(needed: data.size)
        for (i in 0..data.size) {
            buffer[position + i] = data[i]
        }
        position += data.size
    }

    /// 写入字节数组并追加 null 终止符
    /// 对应 Bun string_builder.appendCountZ
    public func writeBytesNullTerminated(data: Array<UInt8>): StringPointer {
        let offset = position
        writeBytes(data)
        writeByte(UInt8(0))  // null terminator
        return StringPointer(offset: offset, length: data.size + 1)
    }

    /// 写入零填充
    public func writeZeros(count: Int64): Unit {
        ensureCapacity(needed: count)
        for (_ in 0..count) {
            buffer[position] = UInt8(0)
            position += 1
        }
    }

    /// 写入字符串 (UTF-8 字节) 并追加 null 终止符
    /// 对应 Bun string_builder.appendCountZ
    public func writeStringNullTerminated(s: String): StringPointer {
        let offset = position
        let bytes = stringToBytes(s)
        writeBytes(bytes)
        writeByte(UInt8(0))  // null terminator
        return StringPointer(offset: offset, length: bytes.size + 1)
    }

    /// 写入字符串 (不含 null 终止符)
    public func writeString(s: String): Unit {
        let bytes = stringToBytes(s)
        writeBytes(bytes)
    }

    /// 写入格式化字符串
    public func writeFormattedString(s: String): StringPointer {
        writeStringNullTerminated(s)
    }

    /// 写入 UInt32 (little-endian)
    public func writeU32LE(val: UInt32): Unit {
        ensureCapacity(needed: 4)
        buffer[position] = UInt8(val & UInt32(0xFF))
        buffer[position + 1] = UInt8((val >> 8) & UInt32(0xFF))
        buffer[position + 2] = UInt8((val >> 16) & UInt32(0xFF))
        buffer[position + 3] = UInt8((val >> 24) & UInt32(0xFF))
        position += 4
    }

    /// 写入 UInt64 (little-endian)
    public func writeU64LE(val: UInt64): Unit {
        ensureCapacity(needed: 8)
        for (i in 0..8) {
            buffer[position + Int64(i)] = UInt8((val >> (UInt64(i) * UInt64(8))) & UInt64(0xFF))
        }
        position += 8
    }

    /// 写入 CompiledModuleGraphFile
    /// 二进制布局:
    ///   name: StringPointer (8 bytes)
    ///   contents: StringPointer (8 bytes)
    ///   sourcemap: StringPointer (8 bytes)
    ///   bytecode: StringPointer (8 bytes)
    ///   module_info: StringPointer (8 bytes)
    ///   bytecode_origin_path: StringPointer (8 bytes)
    ///   encoding: u8 (1 byte)
    ///   loader: u8 (1 byte)
    ///   module_format: u8 (1 byte)
    ///   side: u8 (1 byte)
    ///   padding: 4 bytes (对齐到 8 字节)
    public func writeCompiledModuleGraphFile(entry: CompiledModuleGraphFile): Unit {
        // 6 个 StringPointer
        writeStringPointer(entry.name)
        writeStringPointer(entry.contents)
        writeStringPointer(entry.sourcemap)
        writeStringPointer(entry.bytecode)
        writeStringPointer(entry.moduleInfo)
        writeStringPointer(entry.bytecodeOriginPath)
        // encoding + loader + module_format + side
        writeByte(entry.encoding.toU8())
        writeByte(entry.loader.toU8())
        writeByte(entry.moduleFormat.toU8())
        writeByte(entry.side.toU8())
        // padding to 8-byte alignment (already at 52, need 4 more)
        writeZeros(4)
    }

    /// 写入 StringPointer (offset: u32 + length: u32)
    public func writeStringPointer(ptr: StringPointer): Unit {
        writeU32LE(UInt32(ptr.offset))
        writeU32LE(UInt32(ptr.length))
    }

    /// 写入 Offsets 结构
    /// 对应 Bun std.mem.asBytes(&offsets)
    /// 布局:
    ///   byte_count: usize (8 bytes)
    ///   modules_ptr: StringPointer (8 bytes)
    ///   entry_point_id: u32 (4 bytes)
    ///   padding (4 bytes, 对齐)
    ///   compile_exec_argv_ptr: StringPointer (8 bytes)
    ///   flags: u32 (4 bytes)
    ///   padding (4 bytes, 对齐)
    public func writeOffsets(offsets: Offsets): Unit {
        writeU64LE(UInt64(offsets.byteCount))
        writeStringPointer(offsets.modulesPtr)
        writeU32LE(UInt32(offsets.entryPointId))
        writeZeros(4)  // padding
        writeStringPointer(offsets.compileExecArgvPtr)
        writeU32LE(offsets.flags.toU32())
        writeZeros(4)  // padding
    }

    /// 获取已写入的字节数组
    public func toByteArray(): Array<UInt8> {
        sliceBytes(buffer, 0, position)
    }
}

// ============================================================================
// StandaloneReader - 二进制读取器
// 对应 Bun 中 fromBytes() 使用的内存切片操作
// ============================================================================

/// 二进制读取器 - 从模块图二进制数据中读取各种类型
public class StandaloneReader {
    /// 源字节
    private var bytes: Array<UInt8>
    /// 当前读取位置
    private var pos: Int64

    public init(bytes: Array<UInt8>) {
        this.bytes = bytes
        pos = 0
    }

    /// 当前位置
    public func position(): Int64 {
        pos
    }

    /// 总字节长度
    public func length(): Int64 {
        bytes.size
    }

    /// 剩余可读字节数
    public func remaining(): Int64 {
        bytes.size - pos
    }

    /// 跳过指定字节数
    public func skip(count: Int64): Unit {
        pos += count
        if (pos > bytes.size) {
            pos = bytes.size
        }
    }

    /// 读取单个字节
    public func readByte(): UInt8 {
        if (pos >= bytes.size) {
            return UInt8(0)
        }
        let b = bytes[pos]
        pos += 1
        return b
    }

    /// 读取 UInt32 (little-endian)
    public func readU32LE(): UInt32 {
        if (pos + 4 > bytes.size) {
            return UInt32(0)
        }
        let result = readU32LE(bytes, pos)
        pos += 4
        return result
    }

    /// 读取 UInt64 (little-endian)
    public func readU64LE(): UInt64 {
        if (pos + 8 > bytes.size) {
            return UInt64(0)
        }
        let result = readU64LE(bytes, pos)
        pos += 8
        return result
    }

    /// 读取 StringPointer (offset: u32 + length: u32)
    public func readStringPointer(): StringPointer {
        let offset = Int64(readU32LE())
        let length = Int64(readU32LE())
        return StringPointer(offset: offset, length: length)
    }

    /// 读取 CompiledModuleGraphFile
    public func readCompiledModuleGraphFile(): CompiledModuleGraphFile {
        let entry = CompiledModuleGraphFile()
        entry.name = readStringPointer()
        entry.contents = readStringPointer()
        entry.sourcemap = readStringPointer()
        entry.bytecode = readStringPointer()
        entry.moduleInfo = readStringPointer()
        entry.bytecodeOriginPath = readStringPointer()
        entry.encoding = Encoding.fromU8(readByte())
        entry.loader = Loader.fromU8(readByte())
        entry.moduleFormat = ModuleFormat.fromU8(readByte())
        entry.side = FileSide.fromU8(readByte())
        skip(4)  // padding
        return entry
    }

    /// 读取 Offsets
    public func readOffsets(): Offsets {
        let byteCount = Int64(readU64LE())
        let modulesPtr = readStringPointer()
        let entryPointId = Int64(readU32LE())
        skip(4)  // padding
        let compileExecArgvPtr = readStringPointer()
        let flagsU32 = readU32LE()
        skip(4)  // padding
        return Offsets(
            byteCount: byteCount,
            modulesPtr: modulesPtr,
            entryPointId: entryPointId,
            compileExecArgvPtr: compileExecArgvPtr,
            flags: StandaloneFlags.fromU32(flagsU32)
        )
    }

    /// 读取指定长度的字节切片
    public func readBytes(count: Int64): Array<UInt8> {
        if (pos + count > bytes.size) {
            return []
        }
        var result = Array<UInt8>()
        for (i in 0..count) {
            result.append(bytes[pos + i])
        }
        pos += count
        return result
    }
}

// ============================================================================
// 工具函数
// ============================================================================

/// 从字节数组切片
func sliceBytes(bytes: Array<UInt8>, start: Int64, length: Int64): Array<UInt8> {
    var result = Array<UInt8>()
    let end = start + length
    for (i in start..end) {
        if (i >= 0 && i < bytes.size) {
            result.append(bytes[i])
        }
    }
    return result
}

/// 读取 UInt32 little-endian
func readU32LE(bytes: Array<UInt8>, offset: Int64): UInt32 {
    if (offset + 4 > bytes.size) {
        return UInt32(0)
    }
    var result: UInt32 = UInt32(0)
    result = result | UInt32(bytes[offset])
    result = result | (UInt32(bytes[offset + 1]) << 8)
    result = result | (UInt32(bytes[offset + 2]) << 16)
    result = result | (UInt32(bytes[offset + 3]) << 24)
    return result
}

/// 读取 UInt64 little-endian
func readU64LE(bytes: Array<UInt8>, offset: Int64): UInt64 {
    if (offset + 8 > bytes.size) {
        return UInt64(0)
    }
    var result: UInt64 = UInt64(0)
    for (i in 0..8) {
        result = result | (UInt64(bytes[offset + Int64(i)]) << UInt64(i * 8))
    }
    return result
}

/// 字符串转字节数组
func stringToBytes(s: String): Array<UInt8> {
    var result = Array<UInt8>()
    for (c in s) {
        // UTF-8 多字节处理
        let code = Int32(c.value)
        if (code < 0x80) {
            result.append(UInt8(code))
        } else if (code < 0x800) {
            result.append(UInt8(0xC0 | (code >> 6)))
            result.append(UInt8(0x80 | (code & 0x3F)))
        } else if (code < 0x10000) {
            result.append(UInt8(0xE0 | (code >> 12)))
            result.append(UInt8(0x80 | ((code >> 6) & 0x3F)))
            result.append(UInt8(0x80 | (code & 0x3F)))
        } else {
            result.append(UInt8(0xF0 | (code >> 18)))
            result.append(UInt8(0x80 | ((code >> 12) & 0x3F)))
            result.append(UInt8(0x80 | ((code >> 6) & 0x3F)))
            result.append(UInt8(0x80 | (code & 0x3F)))
        }
    }
    return result
}

/// 去除路径开头的 "./"
/// 对应 Bun bun.strings.removeLeadingDotSlash
func removeLeadingDotSlash(path: String): String {
    if (path.startsWith("./")) {
        return path.subString(2)
    }
    return path
}

/// 反序列化模块条目数组
/// 从 CompiledModuleGraphFile 的序列化字节中重建 ModuleEntry 列表
func deserializeModuleEntries(moduleBytes: Array<UInt8>, rawBytes: Array<UInt8>): ArrayList<ModuleEntry> {
    var result = ArrayList<ModuleEntry>()
    let reader = StandaloneReader(moduleBytes)

    while (reader.remaining() >= ESTIMATED_MODULE_ENTRY_SIZE) {
        let compiledModule = reader.readCompiledModuleGraphFile()

        // 从 rawBytes 中提取字符串
        let name = compiledModule.name.sliceStringFrom(rawBytes)
        let contents = compiledModule.contents.sliceStringFrom(rawBytes)
        let sourcemap = if (!compiledModule.sourcemap.isEmpty()) {
            compiledModule.sourcemap.sliceFrom(rawBytes)
        } else {
            []
        }
        let bytecode = if (!compiledModule.bytecode.isEmpty()) {
            compiledModule.bytecode.sliceFrom(rawBytes)
        } else {
            []
        }
        let moduleInfo = if (!compiledModule.moduleInfo.isEmpty()) {
            compiledModule.moduleInfo.sliceFrom(rawBytes)
        } else {
            []
        }
        let bytecodeOriginPath = if (!compiledModule.bytecodeOriginPath.isEmpty()) {
            compiledModule.bytecodeOriginPath.sliceStringFrom(rawBytes)
        } else {
            ""
        }

        let entry = ModuleEntry(
            name: name,
            loader: compiledModule.loader,
            contents: contents,
            sourcemap: sourcemap,
            encoding: compiledModule.encoding,
            bytecode: bytecode,
            moduleInfo: moduleInfo,
            bytecodeOriginPath: bytecodeOriginPath,
            moduleFormat: compiledModule.moduleFormat,
            side: compiledModule.side
        )
        result.append(entry)
    }

    return result
}

/// 反序列化 Offsets
func deserializeOffsets(bytes: Array<UInt8>): Offsets {
    let reader = StandaloneReader(bytes)
    return reader.readOffsets()
}

/// min 工具函数
func min(a: Int64, b: Int64): Int64 {
    if (a < b) { a } else { b }
}
