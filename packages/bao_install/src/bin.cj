// 严格翻译自: src/install/bin.zig
// bao_install - 二进制符号链接管理 (.bin 目录)
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_sys.*

// ============================================================================
// Bin 标签
// 严格翻译自: src/install/bin.zig - Bin.Tag
//   pub const Tag = enum(u8) {
//       none = 0,
//       file = 1,       // "bin": "./bin/foo"
//       named_file = 2, // "bin": { "babel": "./cli.js" }
//       dir = 3,        // "dirs": { "bin": "./bin" }
//       map = 4,        // "bin": { "babel": "./cli.js", "webpack": "./cli.js" }
//   }
// ============================================================================

/// Bin 类型标签
/// 翻译自: Bin.Tag
public enum BinTag {
    | None       // no bin field
    | File       // "bin": "./bin/foo"
    | NamedFile  // "bin": { "babel": "./cli.js" } (single entry)
    | Dir        // "dirs": { "bin": "./bin" }
    | Map        // "bin": { "babel": "./cli.js", ... } (multiple entries)

    public func isNone(): Bool {
        match (this) {
            case None => true
            case _ => false
        }
    }

    public operator func ==(right: BinTag): Bool {
        match (this) {
            case None => match (right) { case None => true case _ => false }
            case File => match (right) { case File => true case _ => false }
            case NamedFile => match (right) { case NamedFile => true case _ => false }
            case Dir => match (right) { case Dir => true case _ => false }
            case Map => match (right) { case Map => true case _ => false }
        }
    }

    public operator func !=(right: BinTag): Bool {
        return !(this == right)
    }
}

// ============================================================================
// Bin 信息
// 严格翻译自: src/install/bin.zig - Bin
//   pub const Bin = extern struct {
//       tag: Tag = Tag.none,
//       _padding_tag: [3]u8 = .{0} ** 3,
//       value: Value = Value{ .map = ExternalStringList{} },
//   }
// ============================================================================

/// Bin 信息
/// 翻译自: src/install/bin.zig - Bin
public class PackageBin {
    public var tag: BinTag
    /// 文件路径 (当 tag == File)
    public var filePath: ?String
    /// 名称 (当 tag == NamedFile)
    public var name: ?String
    /// 命名路径 (当 tag == NamedFile)
    public var namedPath: ?String
    /// bin 映射 (当 tag == Map)
    public var binMap: HashMap<String, String>
    /// 目录路径 (当 tag == Dir)
    public var dirPath: ?String

    public init() {
        tag = BinTag.None
        filePath = None
        name = None
        namedPath = None
        binMap = HashMap<String, String>()
        dirPath = None
    }

    public static func `init`(): PackageBin {
        return PackageBin()
    }

    // ========================================================================
    // Bin.count
    // 严格翻译自: Bin.count
    //   pub fn count(this: *const Bin, buf, extern_strings, StringBuilder, builder) u32
    //   计算 bin 字段中所有字符串的总长度
    // ========================================================================

    /// 计算 bin 条目数量
    /// 翻译自: Bin.count
    ///   返回 bin 中的条目数:
    ///   - file: 0 (只计入字符串长度)
    ///   - named_file: 0
    ///   - dir: 0
    ///   - map: 返回 map 中的条目数
    public func count(): UInt32 {
        match (tag) {
            case File => UInt32(0)
            case NamedFile => UInt32(0)
            case Dir => UInt32(0)
            case Map => UInt32(binMap.size)
            case _ => UInt32(0)
        }
    }

    // ========================================================================
    // Bin.eql
    // 严格翻译自: Bin.eql
    //   pub fn eql(l, r, l_buf, l_extern_strings, r_buf, r_extern_strings) bool
    //   判断两个 Bin 是否相等
    // ========================================================================

    /// 判断是否与另一个 Bin 相等
    /// 翻译自: Bin.eql
    public func eql(other: PackageBin): Bool {
        if (tag != other.tag) { return false }

        match (tag) {
            case None => return true
            case File =>
                match (filePath) {
                    case Some(l) =>
                        match (other.filePath) {
                            case Some(r) => return l == r
                            case None => return false
                        }
                    case None => return other.filePath.isNone()
                }
            case NamedFile =>
                if (name != other.name) { return false }
                if (namedPath != other.namedPath) { return false }
                return true
            case Dir =>
                match (dirPath) {
                    case Some(l) =>
                        match (other.dirPath) {
                            case Some(r) => return l == r
                            case None => return false
                        }
                    case None => return other.dirPath.isNone()
                }
            case Map =>
                if (binMap.size != other.binMap.size) { return false }
                // map 中的键值对需要逐一比较
                for (k in binMap.keys()) {
                    match (binMap.get(k)) {
                        case Some(v) =>
                            match (other.binMap.get(k)) {
                                case Some(otherValue) =>
                                    if (v != otherValue) { return false }
                                case None => return false
                            }
                        case None => ()
                    }
                }
                return true
        }
    }

    // ========================================================================
    // Bin.clone
    // 严格翻译自: Bin.clone
    //   pub fn clone(this, buf, prev_external_strings, all_extern_strings,
    //                extern_strings_slice, StringBuilder, builder) Bin
    // ========================================================================

    /// 克隆 Bin
    /// 翻译自: Bin.clone
    public func clone(): PackageBin {
        let result = PackageBin()
        result.tag = tag

        match (tag) {
            case None => ()
            case File =>
                match (filePath) {
                    case Some(p) => result.filePath = Some(p)
                    case None => ()
                }
            case NamedFile =>
                result.name = name
                result.namedPath = namedPath
            case Dir =>
                match (dirPath) {
                    case Some(p) => result.dirPath = Some(p)
                    case None => ()
                }
            case Map =>
                for (k in binMap.keys()) {
                    match (binMap.get(k)) {
                        case Some(v) => result.binMap.put(k, v)
                        case None => ()
                    }
                }
        }

        return result
    }

    // ========================================================================
    // Bin.parseAppend
    // 严格翻译自: Bin.parseAppend
    //   pub fn parseAppend(allocator, bin_expr, buf, extern_strings) OOM!Bin
    //   从 JSON 表达式解析 bin 字段:
    //   - e_string => file
    //   - e_object with 1 property => named_file
    //   - e_object with >1 properties => map
    // ========================================================================

    /// 从 JSON 解析 Bin
    /// 翻译自: Bin.parseAppend
    public static func parseFromJson(json: JsonValue): PackageBin {
        let result = PackageBin()

        match (json) {
            case JsonValue.Object(obj) =>
                match (obj.size) {
                    case 0 => ()
                    case 1 =>
                        // 单个属性 => named_file
                        let keys = obj.keys()
                        if (keys.size >= 1) {
                            let k = keys[0]
                            result.tag = BinTag.NamedFile
                            result.name = Some(k)
                            match (obj.get(k)) {
                                case Some(JsonValue.Str(v)) => result.namedPath = Some(v)
                                case _ => ()
                            }
                        }
                    case _ =>
                        // 多个属性 => map
                        result.tag = BinTag.Map
                        for (k in obj.keys()) {
                            match (obj.get(k)) {
                                case Some(JsonValue.Str(s)) => result.binMap.put(k, s)
                                case _ => ()
                            }
                        }
                }
            case JsonValue.Str(str) =>
                if (str.size > 0) {
                    result.tag = BinTag.File
                    result.filePath = Some(str)
                }
            case _ => ()
        }

        return result
    }

    // ========================================================================
    // Bin.parseAppendFromDirectories
    // 严格翻译自: Bin.parseAppendFromDirectories
    //   pub fn parseAppendFromDirectories(allocator, bin_expr, buf) OOM!Bin
    //   从 "dirs" 字段解析 bin 目录路径
    // ========================================================================

    /// 从 directories 字段解析 Bin
    /// 翻译自: Bin.parseAppendFromDirectories
    public static func parseFromDirectories(json: JsonValue): PackageBin {
        let result = PackageBin()
        match (json) {
            case JsonValue.Str(binStr) =>
                if (binStr.size > 0) {
                    result.tag = BinTag.Dir
                    result.dirPath = Some(binStr)
                }
            case _ => ()
        }
        return result
    }

    // ========================================================================
    // Bin.toJson
    // 严格翻译自: Bin.toJson
    //   pub fn toJson(this, style, indent, buf, extern_strings, writer, writeIndent) Error!void
    //   将 Bin 序列化为 JSON
    // ========================================================================

    /// 序列化为 JSON 字符串
    /// 翻译自: Bin.toJson (single_line 模式)
    public func toJson(): String {
        match (tag) {
            case None => return ""
            case File =>
                match (filePath) {
                    case Some(p) => return "\"${p}\""
                    case None => return "\"\""
                }
            case NamedFile =>
                let nameStr = name ?? ""
                let pathStr = namedPath ?? ""
                return "{ \"${nameStr}\": \"${pathStr}\" }"
            case Dir =>
                match (dirPath) {
                    case Some(p) => return "\"${p}\""
                    case None => return "\"\""
                }
            case Map =>
                var sb = StringBuilder()
                sb.append("{")
                var first = true
                for (k in binMap.keys()) {
                    match (binMap.get(k)) {
                        case Some(v) =>
                            if (!first) {
                                sb.append(",")
                            }
                            first = false
                            sb.append(" \"${k}\": \"${v}\"")
                        case None => ()
                    }
                }
                sb.append(" }")
                return sb.toString()
        }
    }

    /// 序列化为多行 JSON
    /// 翻译自: Bin.toJson (multi_line 模式)
    public func toJsonMultiLine(indent: Int64): String {
        match (tag) {
            case None => return ""
            case File =>
                match (filePath) {
                    case Some(p) => return "\"${p}\""
                    case None => return "\"\""
                }
            case NamedFile =>
                let nameStr = name ?? ""
                let pathStr = namedPath ?? ""
                var indentBuf = StringBuilder()
                for (_ in 0..indent) { indentBuf.append(" ") }
                let indentStr = indentBuf.toString()
                return "{\n${indentStr}${nameStr}: ${pathStr},\n}"
            case Dir =>
                match (dirPath) {
                    case Some(p) => return "\"${p}\""
                    case None => return "\"\""
                }
            case Map =>
                var sb = StringBuilder()
                sb.append("{\n")
                var indentBuf2 = StringBuilder()
                for (_ in 0..(indent + 1)) { indentBuf2.append(" ") }
                let indentStr = indentBuf2.toString()
                var first = true
                for (k in binMap.keys()) {
                    match (binMap.get(k)) {
                        case Some(v) =>
                            if (!first) {
                                sb.append(",\n")
                            }
                            first = false
                            sb.append("${indentStr}\"${k}\": \"${v}\"")
                        case None => ()
                    }
                }
                if (!first) {
                    sb.append(",\n")
                }
                var outerIndentBuf = StringBuilder()
                for (_ in 0..indent) { outerIndentBuf.append(" ") }
                let outerIndent = outerIndentBuf.toString()
                sb.append("${outerIndent}}")
                return sb.toString()
        }
    }

    // ========================================================================
    // Bin.NamesIterator
    // 严格翻译自: Bin.NamesIterator
    //   pub const NamesIterator = struct {
    //       bin: Bin,
    //       i: usize = 0,
    //       done: bool = false,
    //       dir_iterator: ?std.fs.Dir.Iterator = null,
    //       package_name: String,
    //       destination_node_modules: std.fs.Dir,
    //       buf: bun.PathBuffer,
    //       string_buffer: []const u8,
    //       extern_string_buf: []const ExternalString,
    //   }
    // ========================================================================

    /// 创建名称迭代器
    /// 翻译自: Bin.NamesIterator
    ///   返回 bin 名称列表 (不包含路径, 只有命令名)
    public func namesIterator(
        packageName: String,
        destinationNodeModules: String
    ): BinNamesIterator {
        return BinNamesIterator(this, packageName, destinationNodeModules)
    }
}

// ============================================================================
// Bin 名称迭代器
// 严格翻译自: src/install/bin.zig - Bin.NamesIterator
//   遍历 Bin 中的所有可执行文件名
// ============================================================================

/// Bin 名称迭代器
/// 翻译自: Bin.NamesIterator
public class BinNamesIterator {
    private var bin: PackageBin
    private var i: Int64
    private var done: Bool
    private var dirEntries: ArrayList<String>
    private var dirEntriesIdx: Int64
    private var packageName: String
    private var destinationNodeModules: String

    public init(bin: PackageBin, packageName: String, destinationNodeModules: String) {
        this.bin = bin
        this.i = 0
        this.done = false
        this.dirEntries = ArrayList<String>()
        this.dirEntriesIdx = 0
        this.packageName = packageName
        this.destinationNodeModules = destinationNodeModules

        // 预加载 dir 条目
        if (bin.tag == BinTag.Dir) {
            match (bin.dirPath) {
                case Some(dirRelPath) =>
                    let packageDir = Path.join([destinationNodeModules, packageName])
                    let binDir = Path.join([packageDir, dirRelPath])
                    if (BaoFile.isDirectory(binDir)) {
                        let entries = BaoFile.readdir(binDir)
                        for (entry in entries) {
                            if (entry == "." || entry == "..") { continue }
                            let entryPath = Path.join([binDir, entry])
                            if (!BaoFile.isDirectory(entryPath)) {
                                dirEntries.append(entry)
                            }
                        }
                    }
                case None => ()
            }
        }
    }

    /// 下一个 bin 名称
    /// 翻译自: NamesIterator.next
    ///   返回下一个 bin 文件名 (去除路径前缀)
    public func next(): ?String {
        if (done) { return None }

        match (bin.tag) {
            case File =>
                if (i > 0) { return None }
                i += 1
                done = true
                return Some(normalizedBinName(packageName))
            case NamedFile =>
                if (i > 0) { return None }
                i += 1
                done = true
                match (bin.name) {
                    case Some(n) => return Some(normalizedBinName(n))
                    case None => return Some(normalizedBinName(packageName))
                }
            case Dir =>
                if (dirEntriesIdx < dirEntries.size) {
                    let name = dirEntries[dirEntriesIdx]
                    dirEntriesIdx += 1
                    if (dirEntriesIdx >= dirEntries.size) {
                        done = true
                    }
                    return Some(normalizedBinName(name))
                }
                done = true
                return None
            case Map =>
                let keyList = bin.binMap.keys()
                if (i < keyList.size) {
                    let k = keyList[Int64(i)]
                    i += 1
                    if (i >= keyList.size) {
                        done = true
                    }
                    return Some(normalizedBinName(k))
                }
                done = true
                return None
            case _ =>
                done = true
                return None
        }
    }

    /// 收集所有名称
    public func collectAll(): ArrayList<String> {
        let result = ArrayList<String>()
        var nextName = next()
        while (nextName.isSome()) {
            result.append(nextName.getOrThrow())
            nextName = next()
        }
        return result
    }
}

// ============================================================================
// normalizedBinName
// 严格翻译自: src/install/bin.zig - normalizedBinName
//   pub fn normalizedBinName(name: []const u8) []const u8 {
//       if (std.mem.lastIndexOfAny(u8, name, "/\\:")) |i| {
//           return name[i + 1 ..];
//       }
//       return name;
//   }
// ============================================================================

/// 规范化 bin 名称
/// 翻译自: normalizedBinName
///   从路径中提取文件名: "scripts/foo" -> "foo", "@scope/pkg" -> "pkg"
public func normalizedBinName(name: String): String {
    // 查找最后一个路径分隔符
    var lastSlashIdx: Int64 = -1
    for (i in 0..name.size) {
        let c = name[Int64(i)]
        if (c == UInt8(47) || c == UInt8(92) || c == UInt8(58)) { // '/', '\', ':'
            lastSlashIdx = Int64(i)
        }
    }
    if (lastSlashIdx >= 0) {
        return name[lastSlashIdx + 1..]
    }
    return name
}

/// 从包名提取 bin 名 (去掉 @scope/ 前缀)
/// 翻译自: Dependency.unscopedPackageName
public func unscopedPackageName(packageName: String): String {
    if (packageName.startsWith("@")) {
        match (packageName.indexOf("/")) {
            case Some(idx) => return packageName[Int64(idx) + 1..]
            case None => return packageName
        }
    }
    return packageName
}

// ============================================================================
// Bin.Linker
// 严格翻译自: src/install/bin.zig - Bin.Linker
//   pub const Linker = struct {
//       bin: Bin,
//       target_node_modules_path: *bun.AbsPath,
//       target_package_name: strings.StringOrTinyString,
//       seen: ?*bun.StringHashMap(void),
//       node_modules_path: *bun.AbsPath,
//       package_name: strings.StringOrTinyString,
//       global_bin_path: stringZ = "",
//       string_buf: []const u8,
//       extern_string_buf: []const ExternalString,
//       abs_target_buf: []u8,
//       abs_dest_buf: []u8,
//       rel_buf: []u8,
//       err: ?anyerror = null,
//       skipped_due_to_missing_bin: bool = false,
//
//       pub var umask: bun.Mode = 0;
//       var has_set_umask = false;
//       ...
//   }
// ============================================================================

/// Bin 链接器
/// 翻译自: Bin.Linker
///   负责将 bin 条目链接到 node_modules/.bin 目录
public class BinLinker {
    /// Bin 配置
    public var bin: PackageBin
    /// 目标 node_modules 路径 (通常是包所在位置)
    public var targetNodeModulesPath: String
    /// 目标包名 (支持原生 bin 链接重定向)
    public var targetPackageName: String
    /// 已见过的目标路径 (避免重复链接)
    public var seen: HashSet<String>
    /// node_modules 路径 (链接目标目录)
    public var nodeModulesPath: String
    /// 包名
    public var packageName: String
    /// 全局 bin 路径
    public var globalBinPath: String
    /// 字符串缓冲区
    public var stringBuf: String
    /// 最后一个错误
    public var err: ?String
    /// 是否因 bin 文件不存在而跳过
    public var skippedDueToMissingBin: Bool
    /// 是否 dry-run
    public var dryRun: Bool

    public init(
        bin: PackageBin,
        targetNodeModulesPath: String,
        targetPackageName: String,
        nodeModulesPath: String,
        packageName: String,
        stringBuf: String
    ) {
        this.bin = bin
        this.targetNodeModulesPath = targetNodeModulesPath
        this.targetPackageName = targetPackageName
        this.seen = HashSet<String>()
        this.nodeModulesPath = nodeModulesPath
        this.packageName = packageName
        this.globalBinPath = ""
        this.stringBuf = stringBuf
        this.err = None
        this.skippedDueToMissingBin = false
        this.dryRun = false
    }

    // ========================================================================
    // Linker.link
    // 严格翻译自: Linker.link
    //   pub fn link(this: *Linker, global: bool) void
    //   遍历 Bin 条目, 为每个创建符号链接或 shim
    // ========================================================================

    /// 执行 bin 链接
    /// 翻译自: Linker.link
    public func link(global: Bool): Unit {
        let packageDir = buildTargetPackageDir()
        let binDirPath = buildDestinationDir(global)

        match (bin.tag) {
            case None => ()
            case File =>
                match (bin.filePath) {
                    case Some(target) =>
                        if (target.size == 0) { return }
                        let unscopedName = unscopedPackageName(packageName)
                        let absTarget = resolveBinTarget(packageDir, target, unscopedName)
                        let absDest = "${binDirPath}${unscopedName}"
                        linkBinOrCreateShim(absTarget, absDest, global)
                    case None => ()
                }
            case NamedFile =>
                let binName = bin.name ?? ""
                let normalizedName = normalizedBinName(binName)
                let target = bin.namedPath ?? ""
                if (normalizedName.size == 0 || target.size == 0) { return }
                let absTarget = resolveBinTarget(packageDir, target, normalizedName)
                let absDest = "${binDirPath}${normalizedName}"
                linkBinOrCreateShim(absTarget, absDest, global)
            case Map =>
                for (k in bin.binMap.keys()) {
                    match (bin.binMap.get(k)) {
                        case Some(v) =>
                            let binDest = normalizedBinName(k)
                            let binTarget = v
                            if (binTarget.size == 0 || binDest.size == 0) { continue }
                            let absTarget = resolveBinTarget(packageDir, binTarget, binDest)
                            let absDest = "${binDirPath}${binDest}"
                            linkBinOrCreateShim(absTarget, absDest, global)
                        case None => ()
                    }
                }
            case Dir =>
                match (bin.dirPath) {
                    case Some(target) =>
                        if (target.size == 0) { return }
                        let absTargetDir = Path.join([packageDir, target])
                        if (!BaoFile.isDirectory(absTargetDir)) {
                            // 目录不存在, 跳过 (不报错)
                            return
                        }
                        let entries = BaoFile.readdir(absTargetDir)
                        for (entry in entries) {
                            if (entry == "." || entry == "..") { continue }
                            let entryPath = Path.join([absTargetDir, entry])
                            if (BaoFile.isDirectory(entryPath)) { continue }
                            let absTarget = entryPath
                            let absDest = "${binDirPath}${entry}"
                            linkBinOrCreateShim(absTarget, absDest, global)
                        }
                    case None => ()
                }
        }
    }

    // ========================================================================
    // Linker.unlink
    // 严格翻译自: Linker.unlink
    //   pub fn unlink(this: *Linker, global: bool) void
    //   移除所有 bin 链接
    // ========================================================================

    /// 移除 bin 链接
    /// 翻译自: Linker.unlink
    public func unlink(global: Bool): Unit {
        let binDirPath = buildDestinationDir(global)

        match (bin.tag) {
            case None => ()
            case File =>
                let unscopedName = unscopedPackageName(packageName)
                let absDest = "${binDirPath}${unscopedName}"
                unlinkBinOrShim(absDest)
            case NamedFile =>
                let binName = bin.name ?? ""
                let normalizedName = normalizedBinName(binName)
                if (normalizedName.size == 0) { return }
                let absDest = "${binDirPath}${normalizedName}"
                unlinkBinOrShim(absDest)
            case Map =>
                for (k in bin.binMap.keys()) {
                    let binDest = normalizedBinName(k)
                    if (binDest.size == 0) { continue }
                    let absDest = "${binDirPath}${binDest}"
                    unlinkBinOrShim(absDest)
                }
            case Dir =>
                match (bin.dirPath) {
                    case Some(target) =>
                        if (target.size == 0) { return }
                        let absTargetDir = Path.join([buildTargetPackageDir(), target])
                        if (!BaoFile.isDirectory(absTargetDir)) {
                            err = Some("directory not found: ${absTargetDir}")
                            return
                        }
                        let entries = BaoFile.readdir(absTargetDir)
                        for (entry in entries) {
                            if (entry == "." || entry == "..") { continue }
                            let entryPath = Path.join([absTargetDir, entry])
                            if (BaoFile.isDirectory(entryPath)) { continue }
                            let absDest = "${binDirPath}${entry}"
                            unlinkBinOrShim(absDest)
                        }
                    case None => ()
                }
        }
    }

    // ========================================================================
    // Linker.linkBinOrCreateShim
    // 严格翻译自: Linker.linkBinOrCreateShim
    //   fn linkBinOrCreateShim(this, abs_target, abs_dest, global) void
    //   创建符号链接或 Windows shim:
    //   1. 跳过已见过的目标
    //   2. 跳过不存在的目标 (设置 skipped_due_to_missing_bin)
    //   3. 记录到 seen 集合
    //   4. Unix: createSymlink
    //   5. Windows: createWindowsShim
    //   6. Unix: tryNormalizeShebang
    // ========================================================================

    /// 创建 bin 链接或 shim
    /// 翻译自: Linker.linkBinOrCreateShim
    private func linkBinOrCreateShim(absTarget: String, absDest: String, global: Bool): Unit {
        // 跳过已见过的目标 (npm 兼容: 第一个出现的包优先)
        if (seen.contains(absDest)) {
            return
        }

        // 跳过不存在的目标 (避免 postinstall 中断)
        if (!BaoFile.exists(absTarget)) {
            skippedDueToMissingBin = true
            return
        }

        // 记录到 seen
        seen.put(absDest)

        if (dryRun) { return }

        // Unix: 创建符号链接
        createSymlink(absTarget, absDest, global)

        // 检查错误
        match (err) {
            case Some(_) =>
                // 清理失败的链接
                unlinkBinOrShim(absDest)
                return
            case None => ()
        }

        // Unix: 尝试规范化 shebang
        tryNormalizeShebang(absTarget)
    }

    // ========================================================================
    // Linker.createSymlink
    // 严格翻译自: Linker.createSymlink
    //   fn createSymlink(this, abs_target, abs_dest, global) void
    //   创建从 dest 到 target 的符号链接:
    //   1. 计算相对路径
    //   2. 尝试创建符号链接
    //   3. 如果 EEXIST: 删除旧的, 重新创建
    //   4. 如果 ENOENT: 创建 .bin 目录, 重新创建
    //   5. 成功后设置 chmod 0o777
    // ========================================================================

    /// 创建符号链接
    /// 翻译自: Linker.createSymlink
    private func createSymlink(absTarget: String, absDest: String, global: Bool): Unit {
        let absDestDir = Path.dirname(absDest)
        let relTarget = Path.relative(absDestDir, absTarget)

        // 确保目标以 ".." 开头 (相对路径)
        if (!relTarget.startsWith("..")) {
            err = Some("relative path does not start with ..: ${relTarget}")
            return
        }

        // 设置 umask
        UmaskHelper.ensureUmask()

        // 尝试创建符号链接
        let result = BaoFile.createSymlink(relTarget, absDest)
        if (result) {
            // 成功: chmod
            // BaoFile.chmod(absTarget, 0x1FF) // TODO: chmod not available in Cangjie
            return
        }

        // 符号链接创建失败: 可能已存在或目录不存在
        if (BaoFile.exists(absDest)) {
            // 已存在: 删除并重试
            BaoFile.remove(absDest)
            let retryResult = BaoFile.createSymlink(relTarget, absDest)
            if (!retryResult) {
                err = Some("failed to create symlink: ${absDest}")
                return
            }
            // BaoFile.chmod(absTarget, 0x1FF) // TODO: chmod not available
            return
        }

        // 目录不存在: 创建 .bin 目录
        if (!global) {
            let binDir = Path.join([nodeModulesPath, ".bin"])
            BaoFile.mkdir(binDir, true)
            let retryResult = BaoFile.createSymlink(relTarget, absDest)
            if (!retryResult) {
                err = Some("failed to create symlink after mkdir: ${absDest}")
                return
            }
            // BaoFile.chmod(absTarget, 0x1FF) // TODO: chmod not available
        } else {
            err = Some("ENOENT for global bin link: ${absDest}")
        }
    }

    // ========================================================================
    // Linker.createWindowsShim
    // 严格翻译自: Linker.createWindowsShim
    //   fn createWindowsShim(this, target, abs_target, abs_dest, global) void
    //   Windows 上创建 .bunx 和 .exe shim 文件:
    //   1. 创建 .bunx 文件 (包含自定义 shim 数据)
    //   2. 创建 .exe 文件 (嵌入可执行文件)
    //   3. 解析 shebang
    // ========================================================================

    /// 创建 Windows shim
    /// 翻译自: Linker.createWindowsShim
    private func createWindowsShim(absTarget: String, absDest: String, global: Bool): Unit {
        // .cmd shim (简化版)
        let shimContent = "@ECHO off\r\n" +
            "GOTO start\r\n" +
            ":start\r\n" +
            "@SETLOCAL\r\n" +
            "@SET PATHEXT=%PATHEXT:;.JS;=;%\r\n" +
            "\"${absTarget.replace("/", "\\")}\" %*\r\n"
        let cmdPath = absDest + ".cmd"
        BaoFile.writeAllText(cmdPath, shimContent)

        // 也创建符号链接
        let absDestDir = Path.dirname(absDest)
        let relTarget = Path.relative(absDestDir, absTarget)
        BaoFile.createSymlink(relTarget, absDest)
    }

    // ========================================================================
    // Linker.tryNormalizeShebang
    // 严格翻译自: Linker.tryNormalizeShebang
    //   fn tryNormalizeShebang(abs_target) void
    //   检查并修复 bin 文件中 Windows 风格的 shebang (\r\n):
    //   1. 读取文件前 2048 字节
    //   2. 检查 #! 开头
    //   3. 检查 \r\n 结尾
    //   4. 如果需要: 原子替换文件 (创建临时文件, 写入修正内容, 重命名)
    // ========================================================================

    /// 尝试规范化 shebang
    /// 翻译自: Linker.tryNormalizeShebang
    private func tryNormalizeShebang(absTarget: String): Unit {
        // 读取文件头部
        let contentOpt = BaoFile.readAllText(absTarget)
        var content: String = ""
        match (contentOpt) {
            case SysMaybe.Ok(v) => content = v
            case _ => return
        }
        if (content.size < 5) { return }
        if (content[Int64(0)] != UInt8(35) || content[Int64(1)] != UInt8(33)) { return } // '#', '!'

        // 查找第一个换行符
        match (content.indexOf("\n")) {
            case Some(newlineIdx) =>
                let chunkWithoutNewline = content[..Int64(newlineIdx)]
                // 检查是否有 \r\n
                if (chunkWithoutNewline.size > 0 && chunkWithoutNewline[Int64(chunkWithoutNewline.size) - 1] == UInt8(13)) { // '\r'
                    // 需要修正: 将 \r\n 替换为 \n
                    let fixed = content[..Int64(chunkWithoutNewline.size) - 1] + "\n" + content[Int64(newlineIdx) + 1..]
                    // 原子写入: 先写到临时文件, 再重命名
                    let tmpName = ".tmp_shebang_${absTarget.hashCode()}"
                    match (BaoFile.writeAllText(tmpName, fixed)) {
                        case SysMaybe.Ok(_) => BaoFile.rename(tmpName, absTarget)
                        case _ => ()
                    }
                }
            case None => ()
        }
    }

    // ========================================================================
    // Linker.resolveBinTarget
    // 严格翻译自: Linker.resolveBinTarget
    //   fn resolveBinTarget(this, package_dir, target, bin_name) [:0]const u8
    //   解析 bin 目标路径 (支持原生 bin 链接优化):
    //   1. 如果非重定向: 返回 <package_dir>/<target>
    //   2. 如果是原生 binlink 重定向: 尝试 <package_dir>/<bin_name>
    //   3. 回退到 <package_dir>/<target>
    // ========================================================================

    /// 解析 bin 目标路径
    /// 翻译自: Linker.resolveBinTarget
    private func resolveBinTarget(packageDir: String, target: String, binName: String): String {
        let primary = Path.join([packageDir, target])

        // 非原生 binlink 重定向
        if (!isNativeBinlinkRedirect()) {
            return primary
        }

        // 检查主路径是否存在
        if (BaoFile.exists(primary)) {
            return primary
        }

        // 尝试包根目录下的 bin_name
        if (binName.size > 0) {
            let atRoot = Path.join([packageDir, binName])
            if (BaoFile.exists(atRoot)) {
                return atRoot
            }
        }

        // 回退到主路径 (让 linkBinOrCreateShim 设置 skippedDueToMissingBin)
        return primary
    }

    // ========================================================================
    // Linker.isNativeBinlinkRedirect
    // 严格翻译自: Linker.isNativeBinlinkRedirect
    //   fn isNativeBinlinkRedirect(this) bool
    //   检查是否是原生 binlink 重定向
    //   (target_package_name != package_name)
    // ========================================================================

    /// 是否是原生 binlink 重定向
    /// 翻译自: Linker.isNativeBinlinkRedirect
    private func isNativeBinlinkRedirect(): Bool {
        return targetPackageName != packageName
    }

    // ========================================================================
    // Linker.buildTargetPackageDir
    // 严格翻译自: Linker.buildTargetPackageDir
    //   pub fn buildTargetPackageDir(this) []const u8
    //   构建目标包目录: <target_node_modules>/<target_package_name>
    // ========================================================================

    /// 构建目标包目录
    /// 翻译自: Linker.buildTargetPackageDir
    private func buildTargetPackageDir(): String {
        return Path.join([targetNodeModulesPath, targetPackageName])
    }

    // ========================================================================
    // Linker.buildDestinationDir
    // 严格翻译自: Linker.buildDestinationDir
    //   pub fn buildDestinationDir(this, global: bool) []u8
    //   构建目标链接目录:
    //   - global: <global_bin_path>/
    //   - local: <node_modules>/.bin/
    // ========================================================================

    /// 构建目标链接目录
    /// 翻译自: Linker.buildDestinationDir
    private func buildDestinationDir(global: Bool): String {
        if (global && globalBinPath.size > 0) {
            let base = if (globalBinPath.endsWith("/")) {
                globalBinPath
            } else {
                globalBinPath + "/"
            }
            return base
        }
        let nmBase = if (nodeModulesPath.endsWith("/")) {
            nodeModulesPath
        } else {
            nodeModulesPath + "/"
        }
        return "${nmBase}.bin/"
    }

    // ========================================================================
    // Linker.unlinkBinOrShim
    // 严格翻译自: Linker.unlinkBinOrShim
    //   fn unlinkBinOrShim(abs_dest) void
    //   删除 bin 链接和相关的 shim 文件
    //   Unix: 只删除符号链接
    //   Windows: 删除 .bunx, .exe 和链接本身
    // ========================================================================

    /// 删除 bin 链接或 shim
    /// 翻译自: Linker.unlinkBinOrShim
    private func unlinkBinOrShim(absDest: String): Unit {
        if (BaoFile.exists(absDest)) {
            BaoFile.remove(absDest)
        }
        // Windows: 删除 .cmd shim
        let cmdPath = absDest + ".cmd"
        if (BaoFile.exists(cmdPath)) {
            BaoFile.remove(cmdPath)
        }
        // Windows: 删除 .bunx shim
        let bunxPath = absDest + ".bunx"
        if (BaoFile.exists(bunxPath)) {
            BaoFile.remove(bunxPath)
        }
        // Windows: 删除 .exe shim
        let exePath = absDest + ".exe"
        if (BaoFile.exists(exePath)) {
            BaoFile.remove(exePath)
        }
    }
}

// ========================================================================
// Linker.ensureUmask
    // 严格翻译自: Linker.ensureUmask
    //   pub fn ensureUmask() void
    //   确保已设置 umask (只设置一次)
    // ========================================================================

/// 确保 umask 已设置
/// 翻译自: Linker.ensureUmask
public class UmaskHelper {
    public static var hasSetUmask: Bool = false
    public static var umaskValue: UInt32 = UInt32(0)

    public static func ensureUmask(): Unit {
        if (!hasSetUmask) {
            hasSetUmask = true
            umaskValue = UInt32(0o022) // TODO: SysFs.getUmask() not available
        }
    }
}

// ============================================================================
// Bin.Linker 优先级队列上下文
// 严格翻译自: src/install/bin.zig - Bin.PriorityQueueContext
//   pub const PriorityQueueContext = struct {
//       dependencies: *const std.ArrayListUnmanaged(Dependency),
//       string_buf: *const std.ArrayListUnmanaged(u8),
//       pub fn lessThan(this, a, b) std.math.Order
//   }
// ============================================================================

/// Bin 链接优先级排序器
/// 翻译自: Bin.PriorityQueueContext
///   用于按名称排序 bin 链接任务
public class BinPrioritySorter {
    /// 按名称对 bin 条目排序
    /// 翻译自: PriorityQueueContext.lessThan
    public static func sortByBinName(entries: ArrayList<BinLink>): ArrayList<BinLink> {
        let sorted = ArrayList<BinLink>()
        for (entry in entries) {
            sorted.append(entry)
        }
        // 简单冒泡排序 (bin 数量通常很小)
        var i: Int64 = 0
        while (i < sorted.size - 1) {
            var j: Int64 = 0
            while (j < sorted.size - 1 - i) {
                if (sorted[j].binName > sorted[j + 1].binName) {
                    let tmp = sorted[j]
                    sorted[j] = sorted[j + 1]
                    sorted[j + 1] = tmp
                }
                j += 1
            }
            i += 1
        }
        return sorted
    }
}

// ============================================================================
// Bin 链接条目
// 严格翻译自: src/install/bin.zig 中 bin 解析后的链接信息
// ============================================================================

/// Bin 链接条目
/// 严格翻译自: src/install/bin.zig 中 bin 解析后的链接信息
public class BinLink {
    /// bin 名称 (命令名)
    public var binName: String
    /// bin 源路径 (包内的相对路径)
    public var binSource: String
    /// 包名
    public var packageName: String
    /// 链接目标绝对路径 (node_modules/.bin/<name>)
    public var linkPath: String
    /// bin 源文件绝对路径
    public var sourceAbsPath: String

    public init(binName: String, binSource: String, packageName: String) {
        this.binName = binName
        this.binSource = binSource
        this.packageName = packageName
        this.linkPath = ""
        this.sourceAbsPath = ""
    }
}

// ============================================================================
// Bin 管理器
// 严格翻译自: src/install/PackageInstaller.zig 中的 bin 处理
// 核心职责:
//   1. 从 package.json 的 bin 字段读取可执行文件信息
//   2. 在 node_modules/.bin 目录中创建符号链接
//   3. 处理 Windows 上的 .cmd shim 文件
//   4. 管理全局 bin 链接
// ============================================================================

/// Bin 管理器
/// 严格翻译自: src/install/PackageInstaller.zig 中的 bin 处理
///   核心职责:
///   1. 从 package.json 的 bin 字段读取可执行文件信息
///   2. 在 node_modules/.bin 目录中创建符号链接
///   3. 处理 Windows 上的 .cmd shim 文件
///   4. 管理全局 bin 链接
public class BinManager {
    /// 项目根目录
    private var rootDir: String
    /// node_modules 路径
    private var nodeModulesPath: String
    /// .bin 目录路径
    private var binDirPath: String
    /// 已创建的 bin 链接
    private var links: ArrayList<BinLink>
    /// 是否 dry-run
    private var dryRun: Bool

    public init(rootDir: String) {
        this.rootDir = rootDir
        this.nodeModulesPath = Path.join([rootDir, "node_modules"])
        this.binDirPath = Path.join([nodeModulesPath, ".bin"])
        this.links = ArrayList<BinLink>()
        this.dryRun = false
    }

    /// 设置 dry-run
    public func setDryRun(d: Bool): BinManager {
        dryRun = d
        return this
    }

    /// 为包安装 bin 链接
    // 严格翻译自: src/install/PackageInstaller.zig installBin
    public func installBin(packageName: String, pkgJson: PackageJson): BinInstallResult {
        let result = BinInstallResult()
        let bin = pkgJson.bin

        // 确保 .bin 目录存在
        // 翻译自: std.fs.Dir.makeOpenPath(node_modules_path ++ "/.bin", .{})
        if (!dryRun) {
            BaoFile.mkdir(binDirPath, true)
        }

        match (bin.tag) {
            case BinTag.None => return result
            case BinTag.File => installBinFile(bin, packageName, result)
            case BinTag.NamedFile => installBinNamed(bin, packageName, result)
            case BinTag.Map => installBinMap(bin, packageName, result)
            case BinTag.Dir => installBinDir(bin, packageName, result, nodeModulesPath)
        }
        return result
    }

    private func installBinFile(bin: PackageBin, packageName: String, result: BinInstallResult): Unit {
        match (bin.filePath) {
            case Some(path) => linkBin(unscopedPackageName(packageName), path, packageName, result)
            case None => ()
        }
    }

    private func installBinNamed(bin: PackageBin, packageName: String, result: BinInstallResult): Unit {
        let binName = bin.name ?? packageName
        let binSource = bin.namedPath ?? ""
        if (!binName.isEmpty() && !binSource.isEmpty()) {
            linkBin(normalizedBinName(binName), binSource, packageName, result)
        }
    }

    private func installBinMap(bin: PackageBin, packageName: String, result: BinInstallResult): Unit {
        bin.binMap.forEach({ key, value =>
            linkBin(normalizedBinName(key), value, packageName, result)
        })
    }

    private func installBinDir(bin: PackageBin, packageName: String, result: BinInstallResult, nmPath: String): Unit {
        match (bin.dirPath) {
            case Some(dirRelPath) => installBinDirEntries(dirRelPath, packageName, nmPath, result)
            case None => ()
        }
    }

    private func installBinDirEntries(dirRelPath: String, packageName: String, nmPath: String, result: BinInstallResult): Unit {
        let packageDir = Path.join([nmPath, packageName])
        let binDir = Path.join([packageDir, dirRelPath])
        // 翻译自: std.fs.Dir.iterate / walker_skippable
        //   读取 bin 目录中的所有文件
        if (!BaoFile.isDirectory(binDir)) {
            return
        }
        let files = ArrayList<String>()
        let entries = BaoFile.readdir(binDir)
        for (entry in entries) {
            if (entry == "." || entry == "..") { continue }
            let entryPath = Path.join([binDir, entry])
            if (!BaoFile.isDirectory(entryPath)) {
                files.append(entry)
            }
        }
        linkBinDirFiles(files, dirRelPath, packageName, result)
    }

    private func linkBinDirFiles(files: ArrayList<String>, dirRelPath: String, packageName: String, result: BinInstallResult): Unit {
        for (file in files) {
            let binName = normalizedBinName(file)
            let binSource = Path.join([dirRelPath, file])
            linkBin(binName, binSource, packageName, result)
        }
    }

    private func linkBin(binName: String, path: String, packageName: String, result: BinInstallResult): Unit {
        let link = createBinLink(binName, path, packageName)
        match (link) {
            case Some(l) => addLinkResult(l, binName, result)
            case None => result.failed.append(binName)
        }
    }

    private func addLinkResult(link: BinLink, binName: String, result: BinInstallResult): Unit {
        result.links.append(link)
        result.installed.append(binName)
    }

    /// 创建 BinLink 对象
    // 严格翻译自: src/install/PackageInstaller.zig 中 bin link 创建
    private func createBinLink(binName: String, binSource: String, packageName: String): ?BinLink {
        let link = BinLink(binName, binSource, packageName)
        link.linkPath = Path.join([binDirPath, binName])
        link.sourceAbsPath = Path.join([nodeModulesPath, packageName, binSource])
        return Some(link)
    }

    /// 执行 bin 链接
    // 严格翻译自: src/install/PackageInstaller.zig 中 symlink bin
    //   创建从 node_modules/.bin/<name> 到源文件的符号链接
    //   如果目标已存在, 先删除再创建
    private func performBinLink(link: BinLink): Bool {
        // 翻译自: std.posix.symlinkat(sourceAbsPath, destDirFd, binName)
        //   1. 检查目标是否已存在
        //   2. 如果存在且是符号链接, 删除
        //   3. 创建新的符号链接
        if (BaoFile.exists(link.linkPath)) {
            BaoFile.remove(link.linkPath)
        }
        // 同时删除 .cmd 文件 (Windows)
        let cmdPath = link.linkPath + ".cmd"
        if (BaoFile.exists(cmdPath)) {
            BaoFile.remove(cmdPath)
        }
        return BaoFile.createSymlink(link.sourceAbsPath, link.linkPath)
    }

    /// 创建 Windows .cmd shim
    // 严格翻译自: src/install/PackageInstaller.zig Windows shim
    private func createWindowsShim(link: BinLink): Bool {
        let shimContent = "@ECHO off\r\n" +
            "GOTO start\r\n" +
            ":start\r\n" +
            "@SETLOCAL\r\n" +
            "@SET PATHEXT=%PATHEXT:;.JS;=;%\r\n" +
            "\"${link.sourceAbsPath.replace("/", "\\")}\" %*\r\n"

        let cmdPath = link.linkPath + ".cmd"
        match (BaoFile.writeAllText(cmdPath, shimContent)) {
            case _ => ()
        }

        // 也创建不带 .cmd 的符号链接
        BaoFile.createSymlink(link.sourceAbsPath, link.linkPath)

        return true
    }

    /// 从包名提取 bin 名
    // 严格翻译自: src/install/bin.zig 中的名称处理
    private func packageNameToBinName(packageName: String): String {
        return unscopedPackageName(packageName)
    }

    /// 移除包的所有 bin 链接
    // 严格翻译自: src/install/PackageInstaller.zig 中的 bin 清理
    public func removeBin(packageName: String): Unit {
        let toRemove = ArrayList<String>()
        for (link in links) {
            if (link.packageName == packageName) {
                toRemove.append(link.binName)
            }
        }
        for (binName in toRemove) {
            let linkPath = Path.join([binDirPath, binName])
            if (BaoFile.exists(linkPath)) {
                BaoFile.remove(linkPath)
            }
            // Windows .cmd
            let cmdPath = linkPath + ".cmd"
            if (BaoFile.exists(cmdPath)) {
                BaoFile.remove(cmdPath)
            }
        }
        // 从列表中移除
        var i: Int64 = 0
        while (i < links.size) {
            if (links[Int64(i)].packageName == packageName) {
                links.removeAt(Int64(i))
            } else {
                i += 1
            }
        }
    }

    /// 列出所有已安装的 bin
    public func listBins(): ArrayList<String> {
        let result = ArrayList<String>()
        let entries = BaoFile.readdir(binDirPath)
        for (entry in entries) {
            if (entry == "." || entry == "..") { continue }
            // 跳过 .cmd 文件
            if (!entry.endsWith(".cmd")) {
                result.append(entry)
            }
        }
        return result
    }

    /// 获取 bin 路径
    public func getBinPath(binName: String): ?String {
        let path = Path.join([binDirPath, binName])
        if (BaoFile.exists(path)) {
            return Some(path)
        }
        return None
    }

    /// 安装全局 bin 链接
    // 严格翻译自: src/install/PackageInstaller.zig global bin
    public func installGlobalBin(packageName: String, pkgJson: PackageJson, globalBinDir: String): BinInstallResult {
        let result = BinInstallResult()
        let bin = pkgJson.bin

        match (bin.tag) {
            case BinTag.None => return result
            case BinTag.File => installGlobalBinFile(bin, packageName, globalBinDir, result)
            case BinTag.NamedFile => installGlobalBinNamed(bin, packageName, globalBinDir, result)
            case BinTag.Map => installGlobalBinMap(bin, packageName, globalBinDir, result)
            case BinTag.Dir => ()  // 全局安装中不太常见
        }
        return result
    }

    private func installGlobalBinFile(bin: PackageBin, packageName: String, globalBinDir: String, result: BinInstallResult): Unit {
        if (let Some(path) <- bin.filePath) {
            let binName = unscopedPackageName(packageName)
            let sourcePath = Path.join([globalBinDir, "..", "lib", "node_modules", packageName, path])
            let linkPath = Path.join([globalBinDir, binName])
            BaoFile.createSymlink(sourcePath, linkPath)
            result.installed.append(binName)
        }
    }

    private func installGlobalBinNamed(bin: PackageBin, packageName: String, globalBinDir: String, result: BinInstallResult): Unit {
        let binName = bin.name ?? packageName
        let binSource = bin.namedPath ?? ""
        if (!binName.isEmpty() && !binSource.isEmpty()) {
            let sourcePath = Path.join([globalBinDir, "..", "lib", "node_modules", packageName, binSource])
            let linkPath = Path.join([globalBinDir, binName])
            BaoFile.createSymlink(sourcePath, linkPath)
            result.installed.append(binName)
        }
    }

    private func installGlobalBinMap(bin: PackageBin, packageName: String, globalBinDir: String, result: BinInstallResult): Unit {
        bin.binMap.forEach({ key, value =>
            let sourcePath = Path.join([globalBinDir, "..", "lib", "node_modules", packageName, value])
            let linkPath = Path.join([globalBinDir, key])
            BaoFile.createSymlink(sourcePath, linkPath)
            result.installed.append(key)
        })
    }

    /// 获取链接数
    public func getLinkCount(): Int64 {
        return links.size
    }

    /// 获取所有链接
    public func getLinks(): ArrayList<BinLink> {
        return links
    }
}

// ============================================================================
// Bin 安装结果
// ============================================================================

/// Bin 安装结果
public class BinInstallResult {
    /// 成功安装的 bin 名称
    public var installed: ArrayList<String>
    /// 失败的 bin 名称
    public var failed: ArrayList<String>
    /// 创建的链接详情
    public var links: ArrayList<BinLink>

    public init() {
        installed = ArrayList<String>()
        failed = ArrayList<String>()
        links = ArrayList<BinLink>()
    }

    public func hasErrors(): Bool {
        return failed.size > 0
    }
}
