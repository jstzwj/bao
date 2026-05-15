// 严格翻译自: src/install_jsc/dependency_jsc.zig
//! JSC bridges for `bun.install.Dependency`. Aliased back into dependency.zig.
package bao_install_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// DependencyJSC - Dependency 的 JSC 桥接
// 严格翻译自: src/install_jsc/dependency_jsc.zig:4-137
// ============================================================================

/// 将 Dependency.Version 转换为 JS 值 - 严格对应 Bun versionToJS
/// Zig: pub fn versionToJS(dep, buf, globalThis) bun.JSError!jsc.JSValue
public func dependencyVersionToJS(dep: DependencyVersion, buf: Array<Byte>, globalThis: JSGlobalObject): JSValue {
    let object = JSValue.createEmptyObject(globalThis, 0)
    object.put(globalThis, "type", BaoString.static(dep.tag.toString()).toJS(globalThis))

    match (dep.tag) {
        case .distTag =>
            object.put(globalThis, "name", dep.value.distTag.name.toJS(buf, globalThis))
            object.put(globalThis, "tag", dep.value.distTag.tag.toJS(buf, globalThis))
        case .folder =>
            object.put(globalThis, "folder", dep.value.folder.toJS(buf, globalThis))
        case .git =>
            object.put(globalThis, "owner", dep.value.git.owner.toJS(buf, globalThis))
            object.put(globalThis, "repo", dep.value.git.repo.toJS(buf, globalThis))
            object.put(globalThis, "ref", dep.value.git.committish.toJS(buf, globalThis))
        case .github =>
            object.put(globalThis, "owner", dep.value.github.owner.toJS(buf, globalThis))
            object.put(globalThis, "repo", dep.value.github.repo.toJS(buf, globalThis))
            object.put(globalThis, "ref", dep.value.github.committish.toJS(buf, globalThis))
        case .npm =>
            object.put(globalThis, "name", dep.value.npm.name.toJS(buf, globalThis))
            let versionStr = BaoString.createFormat("${dep.value.npm.version.fmt(buf)}")
            object.put(globalThis, "version", versionStr.transferToJS(globalThis))
            object.put(globalThis, "alias", JSValue.jsBoolean(dep.value.npm.isAlias))
        case .symlink =>
            object.put(globalThis, "path", dep.value.symlink.toJS(buf, globalThis))
        case .workspace =>
            object.put(globalThis, "name", dep.value.workspace.toJS(buf, globalThis))
        case .tarball =>
            object.put(globalThis, "name", dep.value.tarball.packageName.toJS(buf, globalThis))
            match (dep.value.tarball.uri) {
                case .local => local =>
                    object.put(globalThis, "path", local.toJS(buf, globalThis))
                case .remote => remote =>
                    object.put(globalThis, "url", remote.toJS(buf, globalThis))
            }
        default =>
            globalThis.throwTODO("Unsupported dependency type")
    }

    return object
}

/// 从 JS 推断 tag 类型 - 严格对应 Bun tagInferFromJS
public func tagInferFromJS(globalObject: JSGlobalObject, callframe: CallFrame): JSValue {
    let arguments = callframe.argumentsOld(1).slice()
    if (arguments.size == 0 || !arguments[0].isString) {
        return JSValue.jsUndefined
    }

    let dependencyStr = arguments[0].toBunString(globalObject)
    var asUtf8 = dependencyStr.toUTF8(Allocator.default)

    let tag = DependencyVersionTag.infer(asUtf8.slice())
    var str = BaoString.init(tag.toString())
    return str.transferToJS(globalObject)
}

/// 从 JS 创建 Dependency - 严格对应 Bun dependencyFromJS
public func dependencyFromJS(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
    let arguments = callframe.argumentsOld(2).slice()
    if (arguments.size == 1) {
        return PackageManagerUpdateRequest.fromJS(globalThis, arguments[0])
    }

    let arena = ArenaAllocator(Allocator.default)
    let allocator = arena.allocator()

    let aliasValue: JSValue = if (arguments.size > 0) arguments[0] else JSValue.jsUndefined
    if (!aliasValue.isString) {
        return JSValue.jsUndefined
    }
    let aliasSlice = aliasValue.toSlice(globalThis, allocator)

    if (aliasSlice.size == 0) {
        return JSValue.jsUndefined
    }

    let nameValue: JSValue = if (arguments.size > 1) arguments[1] else JSValue.jsUndefined
    let nameSlice = nameValue.toSlice(globalThis, allocator)

    var name = aliasSlice.slice()
    var alias = aliasSlice.slice()
    var buf = alias

    if (nameValue.isString) {
        let builder = StringBuilder(nameSlice.size + aliasSlice.size)
        name = builder.append(nameSlice.slice())
        alias = builder.append(aliasSlice.slice())
        buf = builder.allocatedSlice()
    }

    let log = Logger.Log.init(allocator)
    let sliced = SlicedString.init(buf, name)

    let dep = Dependency.parse(allocator, SlicedString.init(buf, alias).value(), None, buf, sliced, log, None)
    if (dep == None) {
        if (log.msgs.size > 0) {
            globalThis.throwValue(log.toJS(globalThis, Allocator.default, "Failed to parse dependency"))
        }
        return JSValue.jsUndefined
    }

    if (log.msgs.size > 0) {
        globalThis.throwValue(log.toJS(globalThis, Allocator.default, "Failed to parse dependency"))
        return JSValue.zero
    }

    return dependencyVersionToJS(dep, buf, globalThis)
}
