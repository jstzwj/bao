// ModuleInfo 分析模块 - 转译模块信息收集
// 严格翻译自: src/js_printer/lib.rs:85-720 (analyze_transpiled_module 模块)
//   Bun 的 js_printer 在打印代码时收集模块信息 (ModuleInfo)
//   包括: 变量声明、导入/导出信息、请求的模块等
//   这些信息用于 JavaScriptCore 的模块分析和缓存
package bao_js_printer

import bao_core.*
import bao_collections.*

// ============================================================================
// RecordKind - 记录类型
// 严格翻译自: lib.rs:89-138
//   #[repr(u8)] enum RecordKind
// ============================================================================

/// 模块信息记录类型 - 对应 Bun RecordKind
public enum RecordKind {
    | DeclaredVariable          // var_name
    | LexicalVariable           // let_name
    | ImportInfoSingle          // module_name, import_name, local_name
    | ImportInfoSingleTypeScript // module_name, import_name, local_name
    | ImportInfoNamespace       // module_name, import_name = '*', local_name
    | ExportInfoIndirect        // export_name, import_name, module_name
    | ExportInfoLocal           // export_name, local_name, padding
    | ExportInfoNamespace       // export_name, module_name
    | ExportInfoStar            // module_name

    /// 记录中字符串数量 - 对应 RecordKind.len()
    public func len(): Int64 {
        match (this) {
            case DeclaredVariable | LexicalVariable => 1
            case ImportInfoSingle | ImportInfoSingleTypeScript |
                 ImportInfoNamespace | ExportInfoIndirect |
                 ExportInfoLocal => 3
            case ExportInfoNamespace => 2
            case ExportInfoStar => 1
        }
    }

    /// 从字节值构造 - 对应 RecordKind.try_from_u8()
    public static func tryFromU8(v: UInt8): ?RecordKind {
        match (v) {
            case 0 => DeclaredVariable
            case 1 => LexicalVariable
            case 2 => ImportInfoSingle
            case 3 => ImportInfoSingleTypeScript
            case 4 => ImportInfoNamespace
            case 5 => ExportInfoIndirect
            case 6 => ExportInfoLocal
            case 7 => ExportInfoNamespace
            case 8 => ExportInfoStar
            case _ => None
        }
    }

    /// 转为字节值
    public func toU8(): UInt8 {
        match (this) {
            case DeclaredVariable => 0
            case LexicalVariable => 1
            case ImportInfoSingle => 2
            case ImportInfoSingleTypeScript => 3
            case ImportInfoNamespace => 4
            case ExportInfoIndirect => 5
            case ExportInfoLocal => 6
            case ExportInfoNamespace => 7
            case ExportInfoStar => 8
        }
    }
}

// ============================================================================
// ModuleInfoFlags - 模块信息标志
// 严格翻译自: lib.rs:143-164
//   pub struct Flags { contains_import_meta, is_typescript, has_tla }
// ============================================================================

/// 模块信息标志 - 对应 Bun analyze_transpiled_module.Flags
public class ModuleInfoFlags {
    /// 包含 import.meta - 对应 contains_import_meta
    public var containsImportMeta: Bool
    /// 是否 TypeScript - 对应 is_typescript
    public var isTypeScript: Bool
    /// 是否有顶层 await - 对应 has_tla
    public var hasTla: Bool

    public init() {
        containsImportMeta = false
        isTypeScript = false
        hasTla = false
    }

    public init(containsImportMeta: Bool, isTypeScript: Bool, hasTla: Bool) {
        this.containsImportMeta = containsImportMeta
        this.isTypeScript = isTypeScript
        this.hasTla = hasTla
    }

    /// 转为字节 - 对应 Flags.to_byte()
    public func toByte(): UInt8 {
        var b: UInt8 = 0
        if (containsImportMeta) { b = b | 0x01 }
        if (isTypeScript) { b = b | 0x02 }
        if (hasTla) { b = b | 0x04 }
        return b
    }

    /// 从字节解析 - 对应 Flags.from_byte()
    public static func fromByte(b: UInt8): ModuleInfoFlags {
        return ModuleInfoFlags(
            containsImportMeta: (b & 0x01) != 0,
            isTypeScript: (b & 0x02) != 0,
            hasTla: (b & 0x04) != 0
        )
    }
}

// ============================================================================
// StringID - 字符串标识
// 严格翻译自: lib.rs:170-180
//   pub struct StringID(pub u32)
// ============================================================================

/// 字符串标识 - 对应 Bun StringID
/// 索引到 ModuleInfo 的字符串表
public class StringID {
    public var value: UInt32

    /// 星号默认 - 对应 StringID.STAR_DEFAULT
    public static let STAR_DEFAULT: StringID = StringID(UInt32.MAX)
    /// 星号命名空间 - 对应 StringID.STAR_NAMESPACE
    public static let STAR_NAMESPACE: StringID = StringID(UInt32.MAX - 1)

    public init(value: UInt32) {
        this.value = value
    }

    public func equals(other: StringID): Bool {
        return value == other.value
    }
}

// ============================================================================
// FetchParameters - 获取参数
// 严格翻译自: lib.rs:183-200
//   pub struct FetchParameters(pub u32)
// ============================================================================

/// 获取参数 - 对应 Bun FetchParameters
public class FetchParameters {
    public var value: UInt32

    /// 无 - 对应 FetchParameters.None
    public static let NONE: FetchParameters = FetchParameters(UInt32.MAX)
    /// JavaScript - 对应 FetchParameters.Javascript
    public static let JAVASCRIPT: FetchParameters = FetchParameters(UInt32.MAX - 1)
    /// WebAssembly - 对应 FetchParameters.Webassembly
    public static let WEBASSEMBLY: FetchParameters = FetchParameters(UInt32.MAX - 2)
    /// JSON - 对应 FetchParameters.Json
    public static let JSON: FetchParameters = FetchParameters(UInt32.MAX - 3)

    public init(value: UInt32) {
        this.value = value
    }

    /// 宿主定义 - 对应 FetchParameters.host_defined()
    public static func hostDefined(value: StringID): FetchParameters {
        return FetchParameters(value.value)
    }
}

// ============================================================================
// VarKind - 变量类型
// 严格翻译自: lib.rs:202-206
// ============================================================================

/// 变量类型 - 对应 Bun VarKind
public enum VarKind {
    | Declared  // var
    | Lexical   // let/const
}

// ============================================================================
// ModuleInfo - 模块信息
// 严格翻译自: lib.rs:467-719
//   pub struct ModuleInfo { strings_map, strings_buf, strings_lens, ... }
// ============================================================================

/// 模块信息 - 对应 Bun ModuleInfo
/// js_printer 是 ModuleInfo 记录的唯一生产者
public class ModuleInfo {
    /// 字符串映射: 字符串内容 -> 索引 - 对应 strings_map
    public var stringsMap: HashMap<Array<UInt8>, UInt32>
    /// 字符串缓冲区 (wtf-8) - 对应 strings_buf
    public var stringsBuf: ArrayList<UInt8>
    /// 字符串长度表 - 对应 strings_lens
    public var stringsLens: ArrayList<UInt32>
    /// 请求的模块 - 对应 requested_modules
    public var requestedModulesKeys: ArrayList<StringID>
    public var requestedModulesValues: ArrayList<FetchParameters>
    public var requestedModulesIndex: HashMap<StringID, Int64>
    /// 记录缓冲区 - 对应 buffer
    public var buffer: ArrayList<StringID>
    /// 记录类型列表 - 对应 record_kinds
    public var recordKinds: ArrayList<RecordKind>
    /// 标志 - 对应 flags
    public var flags: ModuleInfoFlags
    /// 已导出的名称集合 - 对应 exported_names
    public var exportedNames: HashSet<StringID>
    /// 是否已完成 - 对应 finalized
    public var finalized: Bool

    public init(isTypeScript: Bool) {
        stringsMap = HashMap<Array<UInt8>, UInt32>()
        stringsBuf = ArrayList<UInt8>()
        stringsLens = ArrayList<UInt32>()
        requestedModulesKeys = ArrayList<StringID>()
        requestedModulesValues = ArrayList<FetchParameters>()
        requestedModulesIndex = HashMap<StringID, Int64>()
        buffer = ArrayList<StringID>()
        recordKinds = ArrayList<RecordKind>()
        flags = ModuleInfoFlags(false, isTypeScript, false)
        exportedNames = HashSet<StringID>()
        finalized = false
    }

    /// 创建 - 对应 ModuleInfo.create()
    public static func create(isTypeScript: Bool): ModuleInfo {
        return ModuleInfo(isTypeScript)
    }

    /// 添加变量 - 对应 ModuleInfo.add_var()
    public func addVar(name: StringID, kind: VarKind): Unit {
        match (kind) {
            case VarKind.Declared => addDeclaredVariable(name)
            case VarKind.Lexical => addLexicalVariable(name)
        }
    }

    /// 添加记录 - 对应 add_record()
    private func addRecord(kind: RecordKind, data: Array<StringID>): Unit {
        if (finalized) {
            return
        }
        recordKinds.append(kind)
        for (d in data) {
            buffer.append(d)
        }
    }

    /// 添加声明变量 - 对应 add_declared_variable()
    public func addDeclaredVariable(id: StringID): Unit {
        addRecord(RecordKind.DeclaredVariable, [id])
    }

    /// 添加词法变量 - 对应 add_lexical_variable()
    public func addLexicalVariable(id: StringID): Unit {
        addRecord(RecordKind.LexicalVariable, [id])
    }

    /// 添加单个导入信息 - 对应 add_import_info_single()
    public func addImportInfoSingle(moduleName: StringID, importName: StringID,
                                      localName: StringID, onlyUsedAsType: Bool): Unit {
        let kind = if (onlyUsedAsType) {
            RecordKind.ImportInfoSingleTypeScript
        } else {
            RecordKind.ImportInfoSingle
        }
        addRecord(kind, [moduleName, importName, localName])
    }

    /// 添加命名空间导入 - 对应 add_import_info_namespace()
    public func addImportInfoNamespace(moduleName: StringID, localName: StringID): Unit {
        addRecord(RecordKind.ImportInfoNamespace,
                   [moduleName, StringID.STAR_NAMESPACE, localName])
    }

    /// 添加间接导出 - 对应 add_export_info_indirect()
    public func addExportInfoIndirect(exportName: StringID, importName: StringID,
                                       moduleName: StringID): Unit {
        if (hasOrAddExportedName(exportName)) {
            return
        }
        addRecord(RecordKind.ExportInfoIndirect, [exportName, importName, moduleName])
    }

    /// 添加本地导出 - 对应 add_export_info_local()
    public func addExportInfoLocal(exportName: StringID, localName: StringID): Unit {
        if (hasOrAddExportedName(exportName)) {
            return
        }
        addRecord(RecordKind.ExportInfoLocal,
                   [exportName, localName, StringID(UInt32.MAX)])
    }

    /// 添加命名空间导出 - 对应 add_export_info_namespace()
    public func addExportInfoNamespace(exportName: StringID, moduleName: StringID): Unit {
        if (hasOrAddExportedName(exportName)) {
            return
        }
        addRecord(RecordKind.ExportInfoNamespace, [exportName, moduleName])
    }

    /// 添加星号导出 - 对应 add_export_info_star()
    public func addExportInfoStar(moduleName: StringID): Unit {
        addRecord(RecordKind.ExportInfoStar, [moduleName])
    }

    /// 是否已有导出名称 - 对应 has_or_add_exported_name()
    private func hasOrAddExportedName(name: StringID): Bool {
        if (exportedNames.contains(name)) {
            return true
        }
        exportedNames.put(name)
        return false
    }

    /// 获取或创建字符串ID - 对应 str()
    public func str(value: String): StringID {
        let bytes = Array<UInt8>()
        for (c in value) {
            bytes.append(UInt8(c.value))
        }

        if (let idx = stringsMap.get(bytes)) {
            return StringID(idx)
        }

        let idx = UInt32(stringsLens.size())
        for (b in bytes) {
            stringsBuf.append(b)
        }
        stringsLens.append(UInt32(bytes.size))
        stringsMap.put(bytes, idx)
        return StringID(idx)
    }

    /// 请求模块 - 对应 request_module()
    public func requestModule(importRecordPath: StringID,
                                fetchParameters: FetchParameters): Unit {
        if (requestedModulesIndex.contains(importRecordPath)) {
            return
        }
        let idx = Int64(requestedModulesKeys.size())
        requestedModulesKeys.append(importRecordPath)
        requestedModulesValues.append(fetchParameters)
        requestedModulesIndex.put(importRecordPath, idx)
    }

    /// 替换字符串ID - 对应 replace_string_id()
    public func replaceStringId(oldId: StringID, newId: StringID): Unit {
        if (finalized) {
            return
        }
        for (i in 0..buffer.size()) {
            if (buffer[i].value == oldId.value) {
                buffer[i] = newId
            }
        }
        // 保留插入顺序
        for (i in 0..requestedModulesKeys.size()) {
            if (requestedModulesKeys[i].value == oldId.value) {
                requestedModulesKeys[i] = newId
            }
        }
    }

    /// 完成 - 对应 finalize()
    /// 查找标记为 'local' 的导出，实际上是 'indirect' 的，并修复它们
    public func finalize(): Bool {
        if (finalized) {
            return true
        }

        // 本地导入信息
        // local_name -> (module_name, import_name, is_namespace)
        let localNameToModuleName = HashMap<UInt32, LocalImportInfo>()

        var i: Int64 = 0
        for (idx in 0..recordKinds.size()) {
            let k = recordKinds[idx]
            match (k) {
                case RecordKind.ImportInfoSingle | RecordKind.ImportInfoSingleTypeScript => {
                    localNameToModuleName.put(
                        buffer[i + 2].value,
                        LocalImportInfo(
                            moduleName: buffer[i].value,
                            importName: buffer[i + 1].value,
                            isNamespace: false
                        )
                    )
                }
                case RecordKind.ImportInfoNamespace => {
                    localNameToModuleName.put(
                        buffer[i + 2].value,
                        LocalImportInfo(
                            moduleName: buffer[i].value,
                            importName: StringID.STAR_NAMESPACE.value,
                            isNamespace: true
                        )
                    )
                }
                case _ => ()
            }
            i += k.len()
        }

        // 修复 ExportInfoLocal -> ExportInfoIndirect
        var i2: Int64 = 0
        let tsFixups = ArrayList<Int64>()

        for (idx in 0..recordKinds.size()) {
            let k = recordKinds[idx]
            let klen = k.len()
            if (k == RecordKind.ExportInfoLocal) {
                if (let ip = localNameToModuleName.get(buffer[i2 + 1].value)) {
                    recordKinds[idx] = RecordKind.ExportInfoIndirect
                    buffer[i2] = buffer[i2]           // export_name 不变
                    buffer[i2 + 1] = StringID(ip.importName)
                    buffer[i2 + 2] = StringID(ip.moduleName)

                    if (!ip.isNamespace && flags.isTypeScript) {
                        tsFixups.append(idx)
                    }
                }
            }
            i2 += klen
        }

        // 修复 TypeScript 导入
        for (idx in tsFixups) {
            recordKinds[Int64(idx)] = RecordKind.ImportInfoSingleTypeScript
        }

        finalized = true
        return true
    }

    /// 获取字符串表 - 对应 strings()
    public func strings(): (ArrayList<UInt8>, ArrayList<UInt32>) {
        return (stringsBuf, stringsLens)
    }
}

/// 本地导入信息 - 内部使用
class LocalImportInfo {
    public var moduleName: UInt32
    public var importName: UInt32
    public var isNamespace: Bool

    public init(moduleName: UInt32, importName: UInt32, isNamespace: Bool) {
        this.moduleName = moduleName
        this.importName = importName
        this.isNamespace = isNamespace
    }
}

// ============================================================================
// ModuleInfoDeserialized - 反序列化视图
// 严格翻译自: lib.rs:212-256
// ============================================================================

/// 反序列化模块信息视图 - 对应 Bun ModuleInfoDeserialized
public class ModuleInfoDeserialized {
    public var stringsBuf: Array<UInt8>
    public var stringsLens: Array<UInt32>
    public var requestedModulesKeys: Array<StringID>
    public var requestedModulesValues: Array<FetchParameters>
    public var buffer: Array<StringID>
    public var recordKinds: Array<RecordKind>
    public var flags: ModuleInfoFlags

    public init() {
        stringsBuf = []
        stringsLens = []
        requestedModulesKeys = []
        requestedModulesValues = []
        buffer = []
        recordKinds = []
        flags = ModuleInfoFlags()
    }
}

// ============================================================================
// SourceMapHandler - Source Map 处理器
// 严格翻译自: lib.rs:1168-1214
// ============================================================================

/// Source Map 处理器 - 对应 Bun SourceMapHandler
public class SourceMapHandler {
    public var callback: (SourceMapChunk, LoggerSource) -> Bool

    public init(callback: (SourceMapChunk, LoggerSource) -> Bool) {
        this.callback = callback
    }

    /// 调用回调
    public func onSourceMapChunk(chunk: SourceMapChunk, source: LoggerSource): Bool {
        return callback(chunk, source)
    }
}

// ============================================================================
// RequireOrImportMetaCallback - require/import 元信息回调
// 严格翻译自: lib.rs:1383-1434
// ============================================================================

/// require/import 元信息回调 - 对应 Bun RequireOrImportMetaCallback
public class RequireOrImportMetaCallback {
    public var callback: (Int64, Bool) -> RequireOrImportMeta

    public init() {
        callback = {_: Int64, _: Bool => RequireOrImportMeta()}
    }

    public init(callback: (Int64, Bool) -> RequireOrImportMeta) {
        this.callback = callback
    }

    /// 调用回调
    public func call(id: Int64, wasUnwrappedRequire: Bool): RequireOrImportMeta {
        return callback(id, wasUnwrappedRequire)
    }
}

// ============================================================================
// PrintJsonOptions - JSON 打印选项
// 严格翻译自: lib.rs:1353-1361
// ============================================================================

/// JSON 打印选项 - 对应 Bun PrintJsonOptions
public class PrintJsonOptions {
    public var indent: Indentation
    public var mangledProps: ?HashMap<Ref, String>
    public var minifyWhitespace: Bool

    public init() {
        indent = Indentation()
        mangledProps = None
        minifyWhitespace = false
    }
}
