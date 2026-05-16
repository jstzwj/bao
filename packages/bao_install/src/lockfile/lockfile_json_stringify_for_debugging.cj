// bao_install - 锁文件 JSON 序列化 (调试用)
// 严格翻译自: src/install/lockfile/lockfile_json_stringify_for_debugging.rs + .zig
//   将锁文件内容序列化为 JSON 格式, 主要用于调试和检查
package bao_install.lockfile

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_semver.*

// ============================================================================
// JSON 写入器接口
// 严格翻译自: JsonWriter trait
//   替代 Zig 的 std.json.WriteStream (anytype writer)
// ============================================================================

/// JSON 标量值
/// 翻译自: JsonScalar trait
public protocol JsonScalar {
    func writeJson(out: ArrayList<Byte>, opts: WriteStreamOptions): Unit
}

/// JSON 写入器
/// 翻译自: JsonWriter trait
///   对应 Zig 的 std.json.WriteStream 方法
public protocol JsonWriter {
    func beginObject(): Result<Unit>
    func endObject(): Result<Unit>
    func beginArray(): Result<Unit>
    func endArray(): Result<Unit>
    func objectField(name: Array<Byte>): Result<Unit>
    func writeBool(value: Bool): Result<Unit>
    func writeInt(value: Int64): Result<Unit>
    func writeUInt(value: UInt64): Result<Unit>
    func writeBytes(value: Array<Byte>): Result<Unit>
    func writeNull(): Result<Unit>
    func print(args: String): Result<Unit>
}

// ============================================================================
// 写入流选项
// 严格翻译自: WriteStreamOptions
// ============================================================================

/// 写入流选项
/// 翻译自: WriteStreamOptions
public class WriteStreamOptions {
    /// 缩进空格数
    public var indent: Int64
    /// 是否将不可移植的数字用字符串包裹
    public var emitNonportableNumbersAsStrings: Bool
    /// 是否为 null 可选字段输出 null
    public var emitNullOptionalFields: Bool

    public init(indent: Int64, emitNonportableNumbersAsStrings: Bool, emitNullOptionalFields: Bool) {
        this.indent = indent
        this.emitNonportableNumbersAsStrings = emitNonportableNumbersAsStrings
        this.emitNullOptionalFields = emitNullOptionalFields
    }

    public init() {
        indent = 2
        emitNonportableNumbersAsStrings = false
        emitNullOptionalFields = false
    }
}

// ============================================================================
// 写入流实现
// 严格翻译自: WriteStream struct
//   内存中的 JSON 写入器
// ============================================================================

/// JSON 写入流
/// 翻译自: WriteStream
public class WriteStream <: JsonWriter {
    public var out: ArrayList<Byte>
    public var opts: WriteStreamOptions
    public var depth: Int64
    /// 每个开放容器: 是否已发射 >=1 个元素
    public var hadElement: ArrayList<Bool>
    /// object_field 设置后下一个 write 跳过分隔符
    public var afterField: Bool

    public init(opts: WriteStreamOptions) {
        this.out = ArrayList<Byte>()
        this.opts = opts
        this.depth = 0
        this.hadElement = ArrayList<Bool>()
        this.afterField = false
    }

    /// 换行并缩进
    /// 翻译自: WriteStream.newline_indent
    private func newlineIndent(): Unit {
        if (opts.indent == 0) {
            return
        }
        out.append(Byte('\n'))
        var i: Int64 = 0
        while (i < depth * opts.indent) {
            out.append(Byte(' '))
            i += 1
        }
    }

    /// 发射值前的分隔符
    /// 翻译自: WriteStream.value_start
    private func valueStart(): Unit {
        if (afterField) {
            afterField = false
            return
        }
        if (hadElement.size > 0) {
            let last = hadElement.size - 1
            if (hadElement[last]) {
                out.append(Byte(','))
            }
            hadElement[last] = true
            newlineIndent()
        }
    }

    public func beginObject(): Result<Unit> {
        valueStart()
        out.append(Byte('{'))
        depth += 1
        hadElement.append(false)
        return Result.Ok(())
    }

    public func endObject(): Result<Unit> {
        let had = hadElement.removeLast()
        depth -= 1
        if (had) {
            newlineIndent()
        }
        out.append(Byte('}'))
        return Result.Ok(())
    }

    public func beginArray(): Result<Unit> {
        valueStart()
        out.append(Byte('['))
        depth += 1
        hadElement.append(false)
        return Result.Ok(())
    }

    public func endArray(): Result<Unit> {
        let had = hadElement.removeLast()
        depth -= 1
        if (had) {
            newlineIndent()
        }
        out.append(Byte(']'))
        return Result.Ok(())
    }

    public func objectField(name: Array<Byte>): Result<Unit> {
        valueStart()
        encodeJsonString(name, out)
        if (opts.indent > 0) {
            out.append(Byte(':'))
            out.append(Byte(' '))
        } else {
            out.append(Byte(':'))
        }
        afterField = true
        return Result.Ok(())
    }

    public func writeBool(value: Bool): Result<Unit> {
        valueStart()
        if (value) {
            out.appendAll("true".toByteArray())
        } else {
            out.appendAll("false".toByteArray())
        }
        return Result.Ok(())
    }

    public func writeInt(value: Int64): Result<Unit> {
        valueStart()
        out.appendAll("${value}".toByteArray())
        return Result.Ok(())
    }

    public func writeUInt(value: UInt64): Result<Unit> {
        valueStart()
        out.appendAll("${value}".toByteArray())
        return Result.Ok(())
    }

    public func writeBytes(value: Array<Byte>): Result<Unit> {
        valueStart()
        encodeJsonString(value, out)
        return Result.Ok(())
    }

    public func writeNull(): Result<Unit> {
        valueStart()
        out.appendAll("null".toByteArray())
        return Result.Ok(())
    }

    public func print(args: String): Result<Unit> {
        valueStart()
        out.appendAll(args.toByteArray())
        return Result.Ok(())
    }

    /// 获取输出字节
    /// 翻译自: WriteStream.into_bytes
    public func intoBytes(): ArrayList<Byte> {
        return out
    }

    /// 获取输出字符串
    public func toString(): String {
        return String.fromBytes(out)
    }
}

// ============================================================================
// JSON 字符串编码
// 严格翻译自: encode_json_string
//   RFC-8259 字符串编码: 引号 + 转义 ", \, 控制字符
// ============================================================================

/// 编码 JSON 字符串
/// 翻译自: encode_json_string
public func encodeJsonString(s: Array<Byte>, out: ArrayList<Byte>): Unit {
    out.append(Byte('"'))
    for (c in s) {
        match (c) {
            case Byte('"') => {
                out.appendAll("\\\\".toByteArray()) // \"
                // 实际是 \"
                out.removeAt(out.size - 1) // 移除多余的 \
                out.append(Byte('"'))
                out.insert(out.size - 1, Byte('\\'))
            }
            case Byte('\\') => out.appendAll("\\\\".toByteArray())
            case Byte('\n') => out.appendAll("\\n".toByteArray())
            case Byte('\r') => out.appendAll("\\r".toByteArray())
            case Byte('\t') => out.appendAll("\\t".toByteArray())
            case _ => {
                let v = c.toInt()
                if (v >= 0x00 && v <= 0x1F) {
                    out.appendAll("\\u00".toByteArray())
                    out.appendAll(bao_core.Fmt.hexByteLower(c))
                } else {
                    out.append(c)
                }
            }
        }
    }
    out.append(Byte('"'))
}

// ============================================================================
// 锁文件 JSON 序列化
// 严格翻译自: json_stringify / json_stringify_dependency
// ============================================================================

/// 将锁文件序列化为 JSON
/// 翻译自: json_stringify
///   pub fn jsonStringify(self: *Lockfile, w: anytype) !void
public func jsonStringify(lockfile: Lockfile, w: JsonWriter): Result<Unit> {
    let sb = lockfile.buffers.stringBytes

    w.beginObject()

    // format 字段
    w.objectField("format".toByteArray())
    w.writeBytes(formatVersionName(lockfile.format).toByteArray())

    // meta_hash 字段
    w.objectField("meta_hash".toByteArray())
    let hex = bao_core.Fmt.bytesToHexLower(lockfile.metaHash)
    w.writeBytes(hex)

    // package_index 字段
    w.objectField("package_index".toByteArray())
    w.beginObject()
    for (entry in lockfile.packageIndex) {
        let firstName = entry.value.name
        w.objectField(firstName.toByteArray())
        match (entry.value.ids) {
            case PackageIndexEntry.SingleId(id) => w.writeUInt(UInt64(id))
            case PackageIndexEntry.MultipleIds(ids) => {
                w.beginArray()
                for (id in ids) {
                    w.writeUInt(UInt64(id))
                }
                w.endArray()
            }
        }
    }
    w.endObject()

    // trees 字段
    w.objectField("trees".toByteArray())
    w.beginArray()
    let dependencies = lockfile.buffers.dependencies
    let hoistedDeps = lockfile.buffers.hoistedDependencies
    let resolutions = lockfile.buffers.resolutions
    for (treeId in 0..lockfile.buffers.trees.size) {
        w.beginObject()
        w.objectField("id".toByteArray())
        w.writeUInt(UInt64(treeId))

        let tree = lockfile.buffers.trees[treeId]
        w.objectField("dependencies".toByteArray())
        w.beginObject()
        for (depId in tree.dependencies.get(hoistedDeps)) {
            let dep = dependencies[depId]
            let packageId = resolutions[depId]

            w.objectField(dep.name.slice(sb))
            w.beginObject()
            w.objectField("id".toByteArray())
            w.writeUInt(UInt64(depId))
            w.objectField("package_id".toByteArray())
            w.writeUInt(UInt64(packageId))
            w.endObject()
        }
        w.endObject()
        w.endObject()
    }
    w.endArray()

    // dependencies 字段
    w.objectField("dependencies".toByteArray())
    w.beginArray()
    for (depId in 0..dependencies.size) {
        let dep = dependencies[depId]
        let res = resolutions[depId]
        jsonStringifyDependency(lockfile, w, depId, dep, res)
    }
    w.endArray()

    // packages 字段
    w.objectField("packages".toByteArray())
    w.beginArray()
    for (i in 0..lockfile.packages.len()) {
        let pkg = lockfile.packages.get(i)
        w.beginObject()

        w.objectField("id".toByteArray())
        w.writeUInt(UInt64(i))

        w.objectField("name".toByteArray())
        w.writeBytes(pkg.name.slice(sb))

        w.objectField("name_hash".toByteArray())
        w.writeUInt(pkg.nameHash)

        w.objectField("resolution".toByteArray())
        w.beginObject()
        w.objectField("tag".toByteArray())
        w.writeBytes(pkg.resolution.tag.name().toByteArray())
        w.objectField("value".toByteArray())
        w.print(pkg.resolution.fmt(sb))
        w.endObject()

        w.objectField("dependencies".toByteArray())
        w.beginArray()
        for (depIdx in pkg.dependencies.off..(pkg.dependencies.off + pkg.dependencies.len)) {
            w.writeUInt(UInt64(depIdx))
        }
        w.endArray()

        w.objectField("integrity".toByteArray())
        match (pkg.meta.integrity.tag) {
            case IntegrityTag.Unknown => w.writeNull()
            case _ => w.print(pkg.meta.integrity.toString())
        }

        w.objectField("bin".toByteArray())
        match (pkg.bin.tag) {
            case BinTag.None => w.writeNull()
            case BinTag.File => {
                w.beginObject()
                w.objectField("file".toByteArray())
                w.writeBytes(pkg.bin.file.slice(sb))
                w.endObject()
            }
            case BinTag.NamedFile => {
                w.beginObject()
                w.objectField("name".toByteArray())
                w.writeBytes(pkg.bin.namedFile[0].slice(sb))
                w.objectField("file".toByteArray())
                w.writeBytes(pkg.bin.namedFile[1].slice(sb))
                w.endObject()
            }
            case BinTag.Dir => {
                w.writeBytes(pkg.bin.dir.slice(sb))
            }
            case BinTag.Map => {
                w.beginObject()
                let data = pkg.bin.map.get(lockfile.buffers.externStrings)
                var binI: Int64 = 0
                while (binI < data.size) {
                    w.objectField(data[binI].slice(sb))
                    w.writeBytes(data[binI + 1].slice(sb))
                    binI += 2
                }
                w.endObject()
            }
        }

        w.objectField("scripts".toByteArray())
        w.beginObject()
        for (field in PackageScripts.fieldNames) {
            let script = field.getter(pkg.scripts).slice(sb)
            if (script.length > 0) {
                w.objectField(field.name.toByteArray())
                w.writeBytes(script)
            }
        }
        w.endObject()

        w.endObject()
    }
    w.endArray()

    // workspace_paths 字段
    w.objectField("workspace_paths".toByteArray())
    w.beginObject()
    for (entry in lockfile.workspacePaths) {
        w.objectField("${entry.key}".toByteArray())
        w.writeBytes(entry.value.slice(sb))
    }
    w.endObject()

    // workspace_versions 字段
    w.objectField("workspace_versions".toByteArray())
    w.beginObject()
    for (entry in lockfile.workspaceVersions) {
        w.objectField("${entry.key}".toByteArray())
        w.print(entry.value.fmt(sb))
    }
    w.endObject()

    w.endObject()
    return Result.Ok(())
}

/// 序列化单个依赖
/// 翻译自: json_stringify_dependency
public func jsonStringifyDependency(
    lockfile: Lockfile,
    w: JsonWriter,
    depId: Int64,
    dep: Dependency,
    res: UInt32
): Result<Unit> {
    let sb = lockfile.buffers.stringBytes

    w.beginObject()

    w.objectField("name".toByteArray())
    w.writeBytes(dep.name.slice(sb))

    // 版本标签
    w.objectField(dep.version.tag.name().toByteArray())
    match (dep.version.tag) {
        case DependencyVersionTag.Uninitialized => w.writeNull()
        case DependencyVersionTag.Npm => {
            w.beginObject()
            let info = dep.version.npm
            w.objectField("name".toByteArray())
            w.writeBytes(info.name.slice(sb))
            w.objectField("version".toByteArray())
            w.print(info.version.fmt(sb))
            w.endObject()
        }
        case DependencyVersionTag.Git => {
            w.beginObject()
            let info = dep.version.git
            w.objectField("owner".toByteArray())
            w.writeBytes(info.owner.slice(sb))
            w.objectField("repo".toByteArray())
            w.writeBytes(info.repo.slice(sb))
            w.objectField("committish".toByteArray())
            w.writeBytes(info.committish.slice(sb))
            w.objectField("resolved".toByteArray())
            w.writeBytes(info.resolved.slice(sb))
            w.endObject()
        }
        case DependencyVersionTag.Github => {
            w.beginObject()
            let info = dep.version.github
            w.objectField("owner".toByteArray())
            w.writeBytes(info.owner.slice(sb))
            w.objectField("repo".toByteArray())
            w.writeBytes(info.repo.slice(sb))
            w.objectField("committish".toByteArray())
            w.writeBytes(info.committish.slice(sb))
            w.endObject()
        }
        case DependencyVersionTag.Folder => {
            w.writeBytes(dep.version.folder.slice(sb))
        }
        case DependencyVersionTag.Symlink => {
            w.writeBytes(dep.version.symlink.slice(sb))
        }
        case DependencyVersionTag.Workspace => {
            w.writeBytes(dep.version.workspace.slice(sb))
        }
        case DependencyVersionTag.Tarball => {
            w.beginObject()
            let info = dep.version.tarball
            w.objectField("uri".toByteArray())
            w.writeBytes(info.uri.slice(sb))
            w.objectField("package_name".toByteArray())
            w.writeBytes(info.packageName.slice(sb))
            w.endObject()
        }
        case DependencyVersionTag.DistTag => {
            w.beginObject()
            let info = dep.version.distTag
            w.objectField("name".toByteArray())
            w.writeBytes(info.name.slice(sb))
            w.objectField("tag".toByteArray())
            w.writeBytes(info.tag.slice(sb))
            w.endObject()
        }
        case DependencyVersionTag.Catalog => {
            w.beginObject()
            w.objectField("name".toByteArray())
            w.writeBytes(dep.name.slice(sb))
            w.objectField("version".toByteArray())
            w.print("catalog:${dep.version.catalog.fmtJson(sb)}")
            w.endObject()
        }
    }

    w.objectField("package_id".toByteArray())
    if (res == InvalidPackageId) {
        w.writeNull()
    } else {
        w.writeUInt(UInt64(res))
    }

    w.objectField("behavior".toByteArray())
    w.beginObject()
    for (flag in Behavior.namedFlags) {
        if (flag.getter(dep.behavior)) {
            w.objectField(flag.name.toByteArray())
            w.writeBool(true)
        }
    }
    w.endObject()

    w.objectField("id".toByteArray())
    w.writeUInt(UInt64(depId))

    w.endObject()
    return Result.Ok(())
}

// ============================================================================
// 格式版本名称
// 严格翻译自: format_version_name
// ============================================================================

/// 获取格式版本名称
/// 翻译自: formatVersionName
public func formatVersionName(v: FormatVersion): String {
    match (v) {
        case FormatVersion.V0 => "v0"
        case FormatVersion.V1 => "v1"
        case FormatVersion.V2 => "v2"
        case FormatVersion.V3 => "v3"
        case _ => ""
    }
}

/// 格式版本
public enum FormatVersion {
    | V0
    | V1
    | V2
    | V3
}

// ============================================================================
// 支持类型 (引用)
// ============================================================================

/// 包索引条目
public enum PackageIndexEntry {
    | SingleId(UInt32)
    | MultipleIds(ArrayList<UInt32>)
}

/// 无效包 ID
/// 翻译自: INVALID_PACKAGE_ID
public let INVALID_PACKAGE_ID: UInt32 = UInt32.MAX

/// 无效包 ID 别名
public let InvalidPackageId: UInt32 = UInt32.MAX

/// Bin 标签
public enum BinTag {
    | None
    | File
    | NamedFile
    | Dir
    | Map
}

/// Integrity 标签
public enum IntegrityTag {
    | Unknown
    | SHA256
    | SHA512
    | SHA1
}

/// 依赖版本标签
public enum DependencyVersionTag {
    | Uninitialized
    | Npm
    | DistTag
    | Tarball
    | Folder
    | Symlink
    | Workspace
    | Git
    | Github
    | Catalog
}

/// 包脚本
public class PackageScripts {
    public static let fieldNames: ArrayList<ScriptField> = ArrayList<ScriptField>()

    public init() {}
}

/// 脚本字段
public class ScriptField {
    public var name: String
    public var getter: (PackageScriptsValues) -> String

    public init(name: String, getter: (PackageScriptsValues) -> String) {
        this.name = name
        this.getter = getter
    }
}

/// 包脚本值
public class PackageScriptsValues {
    public init() {}

    public func slice(sb: Array<Byte>): Array<Byte> {
        return Array<Byte>()
    }
}

/// 行为标志
public class Behavior {
    public var value: UInt32

    public init(value: UInt32) {
        this.value = value
    }

    public static let namedFlags: ArrayList<BehaviorFlag> = ArrayList<BehaviorFlag>()
}

/// 行为标志定义
public class BehaviorFlag {
    public var name: String
    public var getter: (Behavior) -> Bool

    public init(name: String, getter: (Behavior) -> Bool) {
        this.name = name
        this.getter = getter
    }
}
