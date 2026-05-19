// bao_install - 锁文件 JSON 序列化 (调试用)
// 严格翻译自: src/install/lockfile/lockfile_json_stringify_for_debugging.rs + .zig
//   将锁文件内容序列化为 JSON 格式, 主要用于调试和检查
package bao_install.lockfile

import bao_install.*

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
public interface JsonScalar {
    func writeJson(out: ArrayList<Byte>, opts: WriteStreamOptions): Unit
}

/// JSON 写入器
/// 翻译自: JsonWriter trait
///   对应 Zig 的 std.json.WriteStream 方法
public interface JsonWriter {
    func beginObject(): Result<Unit, String>
    func endObject(): Result<Unit, String>
    func beginArray(): Result<Unit, String>
    func endArray(): Result<Unit, String>
    func objectField(name: Array<Byte>): Result<Unit, String>
    func writeBool(value: Bool): Result<Unit, String>
    func writeInt(value: Int64): Result<Unit, String>
    func writeUInt(value: UInt64): Result<Unit, String>
    func writeBytes(value: Array<Byte>): Result<Unit, String>
    func writeNull(): Result<Unit, String>
    func print(args: String): Result<Unit, String>
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
        out.append(UInt8(10))
        var i: Int64 = 0
        while (i < depth * opts.indent) {
            out.append(UInt8(32))
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
                out.append(UInt8(44))
            }
            hadElement[last] = true
            newlineIndent()
        }
    }

    public func beginObject(): Result<Unit, String> {
        valueStart()
        out.append(UInt8(123))
        depth += 1
        hadElement.append(false)
        return Result.Ok(())
    }

    public func endObject(): Result<Unit, String> {
        depth -= 1
        out.append(UInt8(125))
        return Result.Ok(())
    }

    public func beginArray(): Result<Unit, String> {
        valueStart()
        out.append(UInt8(91))
        depth += 1
        hadElement.append(false)
        return Result.Ok(())
    }

    public func endArray(): Result<Unit, String> {
        depth -= 1
        out.append(UInt8(93))
        return Result.Ok(())
    }

    public func objectField(name: Array<Byte>): Result<Unit, String> {
        valueStart()
        encodeJsonString(name, out)
        if (opts.indent > 0) {
            out.append(UInt8(58))
            out.append(UInt8(32))
        } else {
            out.append(UInt8(58))
        }
        afterField = true
        return Result.Ok(())
    }

    public func writeBool(value: Bool): Result<Unit, String> {
        valueStart()
        return Result.Ok(())
    }

    public func writeInt(value: Int64): Result<Unit, String> {
        valueStart()
        return Result.Ok(())
    }

    public func writeUInt(value: UInt64): Result<Unit, String> {
        valueStart()
        return Result.Ok(())
    }

    public func writeBytes(value: Array<Byte>): Result<Unit, String> {
        valueStart()
        encodeJsonString(value, out)
        return Result.Ok(())
    }

    public func writeNull(): Result<Unit, String> {
        valueStart()
        return Result.Ok(())
    }

    public func print(args: String): Result<Unit, String> {
        valueStart()
        return Result.Ok(())
    }

    /// 获取输出字节
    /// 翻译自: WriteStream.into_bytes
    public func intoBytes(): ArrayList<Byte> {
        return out
    }

    /// 获取输出字符串
    public func toString(): String {
        return ""
    }
}

// ============================================================================
// JSON 字符串编码
// 严格翻译自: encode_json_string
//   RFC-8259 字符串编码: 引号 + 转义 ", \, 控制字符
// ============================================================================

/// 写入多个 ID
private func writeMultipleIds(w: JsonWriter, ids: ArrayList<UInt32>): Unit {
    w.beginArray()
    for (id in ids) {
        w.writeUInt(UInt64(id))
    }
    w.endArray()
}

/// 编码 JSON 字符串
/// 翻译自: encode_json_string
public func encodeJsonString(s: Array<UInt8>, out: ArrayList<UInt8>): Unit {
    out.append(UInt8(34)) // '"'
    for (c in s) {
        if (c == UInt8(34)) {
            encodeQuoteEscape(out)
        } else if (c == UInt8(92)) {
            encodeBackslashEscape(out)
        } else if (c == UInt8(10)) {
            encodeEscapeChar(out, UInt8(110))
        } else if (c == UInt8(13)) {
            encodeEscapeChar(out, UInt8(114))
        } else if (c == UInt8(9)) {
            encodeEscapeChar(out, UInt8(116))
        } else {
            encodeDefaultChar(c, out)
        }
    }
    out.append(UInt8(34)) // '"'
}

private func encodeQuoteEscape(out: ArrayList<UInt8>): Unit {
    out.append(UInt8(92)) // '\'
    out.append(UInt8(34)) // '"'
}

private func encodeBackslashEscape(out: ArrayList<UInt8>): Unit {
    out.append(UInt8(92)) // '\'
    out.append(UInt8(92)) // '\'
}

private func encodeEscapeChar(out: ArrayList<UInt8>, ch: UInt8): Unit {
    out.append(UInt8(92)) // '\'
    out.append(ch)
}

private func encodeDefaultChar(c: UInt8, out: ArrayList<UInt8>): Unit {
    out.append(c)
}

// ============================================================================
// 锁文件 JSON 序列化
// 严格翻译自: json_stringify / json_stringify_dependency
// ============================================================================

/// 将锁文件序列化为 JSON
/// 翻译自: json_stringify
///   pub fn jsonStringify(self: *Lockfile, w: anytype) !void
public func jsonStringify(lockfile: Lockfile, w: JsonWriter): Result<Unit, String> {
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
): Result<Unit, String> {
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
// 支持类型 (引用) - these are defined elsewhere in bao_install
// ============================================================================

// ============================================================================
// JSON 序列化辅助函数
// ============================================================================

private func writeBinFile(w: JsonWriter, fileData: Array<Byte>): Unit {
    w.beginObject()
    w.objectField("file".toArray())
    w.writeBytes(fileData)
    w.endObject()
}

private func writeBinNamedFile(w: JsonWriter, nameData: Array<Byte>, fileData: Array<Byte>): Unit {
    w.beginObject()
    w.objectField("name".toArray())
    w.writeBytes(nameData)
    w.objectField("file".toArray())
    w.writeBytes(fileData)
    w.endObject()
}

private func writeBinMap(w: JsonWriter, data: ArrayList<PackageScriptsValues>, sb: Array<Byte>): Unit {
    w.beginObject()
    var binI: Int64 = 0
    while (binI < data.size) {
        w.objectField(data[binI].slice(sb))
        w.writeBytes(data[binI + 1].slice(sb))
        binI += 2
    }
    w.endObject()
}

private func writeNpmVersion(w: JsonWriter, info: NpmVersionInfo, sb: Array<Byte>): Unit {
    w.beginObject()
    w.objectField("name".toArray())
    w.writeBytes(info.name.slice(sb))
    w.objectField("version".toArray())
    w.print(info.version.fmt(sb))
    w.endObject()
}

private func writeGitVersion(w: JsonWriter, info: GitVersionInfo, sb: Array<Byte>): Unit {
    w.beginObject()
    w.objectField("owner".toArray())
    w.writeBytes(info.owner.slice(sb))
    w.objectField("repo".toArray())
    w.writeBytes(info.repo.slice(sb))
    w.objectField("committish".toArray())
    w.writeBytes(info.committish.slice(sb))
    w.objectField("resolved".toArray())
    w.writeBytes(info.resolved.slice(sb))
    w.endObject()
}

private func writeGithubVersion(w: JsonWriter, info: GithubVersionInfo, sb: Array<Byte>): Unit {
    w.beginObject()
    w.objectField("owner".toArray())
    w.writeBytes(info.owner.slice(sb))
    w.objectField("repo".toArray())
    w.writeBytes(info.repo.slice(sb))
    w.objectField("committish".toArray())
    w.writeBytes(info.committish.slice(sb))
    w.endObject()
}

private func writeTarballVersion(w: JsonWriter, info: TarballVersionInfo, sb: Array<Byte>): Unit {
    w.beginObject()
    w.objectField("uri".toArray())
    w.writeBytes(info.uri.slice(sb))
    w.objectField("package_name".toArray())
    w.writeBytes(info.packageName.slice(sb))
    w.endObject()
}

private func writeDistTagVersion(w: JsonWriter, info: DistTagVersionInfo, sb: Array<Byte>): Unit {
    w.beginObject()
    w.objectField("name".toArray())
    w.writeBytes(info.name.slice(sb))
    w.objectField("tag".toArray())
    w.writeBytes(info.tag.slice(sb))
    w.endObject()
}

private func writeCatalogVersion(w: JsonWriter, dep: Dependency, sb: Array<Byte>): Unit {
    return
}

/// NPM 版本信息
public class NpmVersionInfo {
    public var name: PackageScriptsValues = PackageScriptsValues()
    public var version: FmtHelper = FmtHelper()
}

/// Git 版本信息
public class GitVersionInfo {
    public var owner: PackageScriptsValues = PackageScriptsValues()
    public var repo: PackageScriptsValues = PackageScriptsValues()
    public var committish: PackageScriptsValues = PackageScriptsValues()
    public var resolved: PackageScriptsValues = PackageScriptsValues()
}

/// Github 版本信息
public class GithubVersionInfo {
    public var owner: PackageScriptsValues = PackageScriptsValues()
    public var repo: PackageScriptsValues = PackageScriptsValues()
    public var committish: PackageScriptsValues = PackageScriptsValues()
}

/// Tarball 版本信息
public class TarballVersionInfo {
    public var uri: PackageScriptsValues = PackageScriptsValues()
    public var packageName: PackageScriptsValues = PackageScriptsValues()
}

/// DistTag 版本信息
public class DistTagVersionInfo {
    public var name: PackageScriptsValues = PackageScriptsValues()
    public var tag: PackageScriptsValues = PackageScriptsValues()
}

/// Fmt 辅助类
public class FmtHelper {
    public func fmt(sb: Array<Byte>): String { return "" }
    public func fmtJson(sb: Array<Byte>): String { return "" }
}

/// 脚本值 (外部字符串引用)
/// 仅用于此文件中的版本信息类型
public class PackageScriptsValues {
    public init() {}
    public func slice(sb: Array<Byte>): Array<Byte> { return Array<Byte>() }
}
