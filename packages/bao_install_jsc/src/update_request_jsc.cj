// 严格翻译自: src/install_jsc/update_request_jsc.zig
//! JSC bridge for `bun.install.PackageManager.UpdateRequest`.
package bao_install_jsc

import bao_jsc.*
import bao_core.*
import bao_collections.*
import bao_install.*

// ============================================================================
// UpdateRequestJSC - UpdateRequest 的 JSC 桥接
// ============================================================================

public func updateRequestFromJS(globalThis: JSGlobalObject, input: JsValue): JsValue {
    let positionals = collectPositionals(globalThis, input)
    if (positionals.size == 0) { return JsValue.jsUndefined() }

    let first = positionals[0]
    if (first.size == 0) { return JsValue.jsUndefined() }

    let pair = parseNameVersion(first)
    let obj = JsObject.make()
    obj.set("name", JsValue(pair.name))
    obj.set("version", JsValue(dependencyVersionObject(globalThis, pair.version)))
    obj.set("input", JsValue(first))
    obj.set("failed", JsValue(false))
    return JsValue(obj)
}

private func collectPositionals(globalThis: JSGlobalObject, input: JsValue): ArrayList<String> {
    let list = ArrayList<String>()
    if (input.isString()) {
        list.append(input.toString())
        return list
    }
    if (input.isUndefinedOrNull()) { return list }

    let len = input.getLength(globalThis.globalThis)
    var i: UInt64 = 0
    while (i < len) {
        let value = input.getIndex(globalThis.globalThis, UInt32(i))
        if (value.isString() && value.toString().size > 0) {
            list.append(value.toString())
        }
        i += UInt64(1)
    }
    return list
}

private class NameVersionPair {
    public var name: String = ""
    public var version: String = "latest"
    public init(name: String, version: String) {
        this.name = name
        this.version = version
    }
}

private func parseNameVersion(input: String): NameVersionPair {
    if (input.startsWith("@")) {
        let slash = input.indexOf('/')
        if (slash >= 0) {
            let at = input[slash + 1..].lastIndexOf('@')
            match (at) {
                case Some(idx) =>
                    let split = slash + 1 + idx
                    return NameVersionPair(input[0..split], input[split + 1..])
                case None => return NameVersionPair(input, "latest")
            }
        }
    }

    match (input.lastIndexOf('@')) {
        case Some(idx) =>
            if (idx > 0) { return NameVersionPair(input[0..idx], input[idx + 1..]) }
            return NameVersionPair(input, "latest")
        case None => NameVersionPair(input, "latest")
    }
}

private func dependencyVersionObject(globalThis: JSGlobalObject, version: String): JsValue {
    let obj = JsObject.make()
    obj.set("literal", JsValue(version))
    obj.set("type", JsValue(dependencyTagToString(DependencyVersionTag.infer(version))))
    return JsValue(obj)
}

private func dependencyTagToString(tag: DependencyVersionTag): String {
    match (tag) {
        case DependencyVersionTag.Uninitialized => "uninitialized"
        case DependencyVersionTag.Npm => "npm"
        case DependencyVersionTag.DistTag => "dist_tag"
        case DependencyVersionTag.Tarball => "tarball"
        case DependencyVersionTag.Folder => "folder"
        case DependencyVersionTag.Symlink => "symlink"
        case DependencyVersionTag.Workspace => "workspace"
        case DependencyVersionTag.Git => "git"
        case DependencyVersionTag.Github => "github"
        case DependencyVersionTag.Catalog => "catalog"
        case DependencyVersionTag.Root => "root"
    }
}
