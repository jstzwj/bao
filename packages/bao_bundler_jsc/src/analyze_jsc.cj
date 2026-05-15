// 严格翻译自: src/bundler_jsc/analyze_jsc.zig
//! JSC bridge for analyze_transpiled_module.zig — converts the parsed ModuleInfoDeserialized into a JSC::JSModuleRecord.
package bao_bundler_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// AnalyzeJSC - 模块分析 JSC 桥接
// 严格翻译自: src/bundler_jsc/analyze_jsc.zig:5-149
// ============================================================================

/// 渲染 diff - 严格对应 Bun zig__renderDiff
public func zigRenderDiff(expectedPtr: String, receivedPtr: String, globalThis: JSGlobalObject): Unit {
    let formatter = DiffFormatter(
        receivedString: receivedPtr,
        expectedString: expectedPtr,
        globalThis: globalThis
    )
    Output.errorWriter().print("DIFF:\n${formatter}\n")
}

/// 将 ModuleInfoDeserialized 转换为 JSModuleRecord - 严格对应 Bun zig__ModuleInfoDeserialized__toJSModuleRecord
public func moduleInfoDeserializedToJSModuleRecord(
    globalObject: JSGlobalObject,
    vm: VM,
    moduleKey: IdentifierArray,
    sourceCode: SourceCode,
    declaredVariables: VariableEnvironment,
    lexicalVariables: VariableEnvironment,
    res: ModuleInfoDeserialized
): ?JSModuleRecord {
    var identifiers = IdentifierArray.create(res.stringsLens.size)
    defer {
        identifiers.destroy()
    }
    var offset: Int64 = 0
    for (i in 0..res.stringsLens.size) {
        let len = res.stringsLens[i]
        if (res.stringsBuf.size < offset + len) {
            return None
        }
        let sub = res.stringsBuf[offset..][0..len]
        identifiers.setFromUtf8(i, vm, sub)
        offset += len
    }

    var idx: Int64 = 0
    for (k in res.recordKinds) {
        let kLen = k.len()
        if (idx + kLen > res.buffer.size) {
            return None
        }
        match (k) {
            case .declaredVariable => declaredVariables.add(vm, identifiers, res.buffer[idx])
            case .lexicalVariable => lexicalVariables.add(vm, identifiers, res.buffer[idx])
            default => {}
        }
        idx += kLen
    }

    let moduleRecord = JSModuleRecord.create(
        globalObject, vm, moduleKey, sourceCode,
        declaredVariables, lexicalVariables,
        res.flags.containsImportMeta, res.flags.isTypescript, res.flags.hasTla
    )

    for (i in 0..res.requestedModulesKeys.size) {
        let reqk = res.requestedModulesKeys[i]
        let reqv = res.requestedModulesValues[i]
        match (reqv) {
            case .none => moduleRecord.addRequestedModuleNullAttributesPtr(identifiers, reqk)
            case .javascript => moduleRecord.addRequestedModuleJavaScript(identifiers, reqk)
            case .webassembly => moduleRecord.addRequestedModuleWebAssembly(identifiers, reqk)
            case .json => moduleRecord.addRequestedModuleJSON(identifiers, reqk)
            default => uv => moduleRecord.addRequestedModuleHostDefined(identifiers, reqk, uv)
        }
    }

    idx = 0
    for (k in res.recordKinds) {
        let kLen = k.len()
        match (k) {
            case .declaredVariable, .lexicalVariable => {}
            case .importInfoSingle =>
                moduleRecord.addImportEntrySingle(identifiers, res.buffer[idx + 1], res.buffer[idx + 2], res.buffer[idx])
            case .importInfoSingleTypeScript =>
                moduleRecord.addImportEntrySingleTypeScript(identifiers, res.buffer[idx + 1], res.buffer[idx + 2], res.buffer[idx])
            case .importInfoNamespace =>
                moduleRecord.addImportEntryNamespace(identifiers, res.buffer[idx + 1], res.buffer[idx + 2], res.buffer[idx])
            case .exportInfoIndirect =>
                if (res.buffer[idx + 1] == .starNamespace) {
                    moduleRecord.addNamespaceExport(identifiers, res.buffer[idx], res.buffer[idx + 2])
                } else {
                    moduleRecord.addIndirectExport(identifiers, res.buffer[idx], res.buffer[idx + 1], res.buffer[idx + 2])
                }
            case .exportInfoLocal =>
                moduleRecord.addLocalExport(identifiers, res.buffer[idx], res.buffer[idx + 1])
            case .exportInfoNamespace =>
                moduleRecord.addNamespaceExport(identifiers, res.buffer[idx], res.buffer[idx + 1])
            case .exportInfoStar =>
                moduleRecord.addStarExport(identifiers, res.buffer[idx])
            default => {}
        }
        idx += kLen
    }

    return moduleRecord
}
