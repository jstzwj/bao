// 严格翻译自: src/bundler_jsc/options_jsc.zig
//! `fromJS` bridges for `bun.options.{Target,Format,Loader}` and `CompileTarget`.
package bao_bundler_jsc

import bao_jsc.*
import bao_core.*
import bao_bundler.*

// ============================================================================
// OptionsJSC - Bundler 选项的 JSC 桥接
// ============================================================================

/// 从 JS 获取 Target
public func targetFromJS(global: JSGlobalObject, value: JsValue): JsValue {
    match (targetValueFromJS(global, value)) {
        case Some(target) => JsValue(target.toAPI())
        case None => JsValue.jsUndefined()
    }
}

public func targetValueFromJS(global: JSGlobalObject, value: JsValue): ?Target {
    if (!value.isString()) {
        global.throwInvalidArguments("target must be a string")
        return None
    }

    let target = value.toString()
    match (target) {
        case "browser" => Some(Target.Browser)
        case "bun" => Some(Target.Bun)
        case "node" => Some(Target.Node)
        case "bun_macro" | "macro" => Some(Target.BunMacro)
        case _ =>
            global.throwInvalidArguments("Invalid target - must be browser, bun, node, or bun_macro")
            None
    }
}

/// 从 JS 获取 Format
public func formatFromJS(global: JSGlobalObject, format: JsValue): JsValue {
    match (formatValueFromJS(global, format)) {
        case Some(value) => JsValue(outputFormatToString(value))
        case None => JsValue.jsUndefined()
    }
}

public func formatValueFromJS(global: JSGlobalObject, format: JsValue): ?OutputFormat {
    if (format.isUndefinedOrNull()) { return None }
    if (!format.isString()) {
        global.throwInvalidArguments("format must be a string")
        return None
    }

    match (format.toString()) {
        case "esm" => Some(OutputFormat.ESM)
        case "cjs" => Some(OutputFormat.CJS)
        case "iife" => Some(OutputFormat.IIFE)
        case _ =>
            global.throwInvalidArguments("Invalid format - must be esm, cjs, or iife")
            None
    }
}

/// 从 JS 获取 Loader
public func loaderFromJS(global: JSGlobalObject, loader: JsValue): JsValue {
    match (loaderValueFromJS(global, loader)) {
        case Some(value) => JsValue(loaderToString(value))
        case None => JsValue.jsUndefined()
    }
}

public func loaderValueFromJS(global: JSGlobalObject, loader: JsValue): ?Loader {
    if (loader.isUndefinedOrNull()) { return None }
    if (!loader.isString()) {
        global.throwInvalidArguments("loader must be a string")
        return None
    }

    let loaderName = loader.toString()
    if (loaderName.size == 0) { return None }

    match (Loader.fromString(loaderName)) {
        case Some(value) => Some(value)
        case None =>
            global.throwInvalidArguments("invalid loader - must be js, jsx, tsx, ts, css, file, toml, yaml, wasm, bunsh, json, or md")
            None
    }
}

public func compileTargetFromJS(global: JSGlobalObject, value: JsValue): JsValue {
    if (!value.isString()) {
        global.throwInvalidArguments("compile target must be a string")
        return JsValue.jsUndefined()
    }

    match (compileTargetFromSlice(global, value.toString())) {
        case Some(target) => JsValue(target)
        case None => JsValue.jsUndefined()
    }
}

public func compileTargetFromSlice(global: JSGlobalObject, value: String): ?String {
    if (!value.startsWith("bun-")) {
        global.throwInvalidArguments("Expected compile target to start with 'bun-'")
        return None
    }

    let target = value[4..]
    match (target) {
        case "linux-x64" | "linux-arm64" | "darwin-x64" | "darwin-arm64" | "windows-x64" => Some(value)
        case _ =>
            global.throwInvalidArguments("Unknown compile target")
            None
    }
}

private func outputFormatToString(format: OutputFormat): String {
    match (format) {
        case OutputFormat.ESM => "esm"
        case OutputFormat.CJS => "cjs"
        case OutputFormat.IIFE => "iife"
        case OutputFormat.InternalBakeDev => "internal_bake_dev"
    }
}

private func loaderToString(loader: Loader): String {
    match (loader) {
        case Loader.Jsx => "jsx"
        case Loader.Js => "js"
        case Loader.Ts => "ts"
        case Loader.Tsx => "tsx"
        case Loader.Css => "css"
        case Loader.File => "file"
        case Loader.Json => "json"
        case Loader.Jsonc => "jsonc"
        case Loader.Toml => "toml"
        case Loader.Wasm => "wasm"
        case Loader.Napi => "napi"
        case Loader.Base64 => "base64"
        case Loader.DataUrl => "dataurl"
        case Loader.Text => "text"
        case Loader.Bunsh => "bunsh"
        case Loader.Sqlite => "sqlite"
        case Loader.SqliteEmbedded => "sqlite_embedded"
        case Loader.Html => "html"
        case Loader.Yaml => "yaml"
        case Loader.Json5 => "json5"
        case Loader.Md => "md"
    }
}
