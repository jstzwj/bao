// 严格翻译自: src/install_jsc/dependency_jsc.zig
//! JSC bridges for `bun.install.Dependency`.
package bao_install_jsc

import bao_jsc.*
import bao_core.*
import bao_install.*

// ============================================================================
// DependencyJSC - Dependency 的 JSC 桥接
// ============================================================================

/// 将 Dependency.Version 转换为 JS 值
public func dependencyVersionToJS(dep: DependencyVersion, buf: Array<Byte>, globalThis: JSGlobalObject): JsValue {
    let object = JsObject.make()
    object.set("literal", JsValue(dep.literal))
    object.set("tag", JsValue(dependencyTagToString(dep.tag)))
    object.set("tagValue", JsValue(dep.tag.toInt()))
    setOptionalString(object, "distTagName", dep.distTagName)
    setOptionalString(object, "npmName", dep.npmName)
    setOptionalString(object, "gitUrl", dep.gitUrl)
    setOptionalString(object, "githubRepo", dep.githubRepo)
    setOptionalString(object, "tarballUrl", dep.tarballUrl)
    setOptionalString(object, "filePath", dep.filePath)
    setOptionalString(object, "linkPath", dep.linkPath)
    return JsValue(object)
}

/// 从 JS 推断 tag 类型
public func tagInferFromJS(globalObject: JSGlobalObject, callframe: CallFrame): JsValue {
    let value = callframe.argument(0)
    if (!value.isString()) {
        globalObject.throwInvalidArguments("Dependency.Version.Tag.infer expects a string")
        return JsValue.jsUndefined()
    }

    let tag = DependencyVersionTag.infer(value.toString())
    let object = JsObject.make()
    object.set("tag", JsValue(dependencyTagToString(tag)))
    object.set("tagValue", JsValue(tag.toInt()))
    return JsValue(object)
}

/// 从 JS 创建 Dependency
public func dependencyFromJS(globalThis: JSGlobalObject, callframe: CallFrame): JsValue {
    let nameValue = callframe.argument(0)
    let versionValue = callframe.argument(1)
    if (!nameValue.isString()) {
        globalThis.throwInvalidArguments("dependencyFromJS expects a dependency name string")
        return JsValue.jsUndefined()
    }

    let version = if (versionValue.isString()) { versionValue.toString() } else { "latest" }
    let dep = DependencyVersion.parse(nameValue.toString(), version)
    return dependencyVersionToJS(dep, Array<Byte>(), globalThis)
}

private func setOptionalString(object: JsObject, key: String, value: ?String): Unit {
    match (value) {
        case Some(v) => object.set(key, JsValue(v))
        case None => object.set(key, JsValue.jsUndefined())
    }
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
