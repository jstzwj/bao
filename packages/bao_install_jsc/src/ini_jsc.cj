// 严格翻译自: src/install_jsc/ini_jsc.zig
//! Test-only host fns for `bun.ini`.
package bao_install_jsc

import bao_jsc.*
import bao_core.*
import bao_collections.*

// ============================================================================
// IniTestingAPIs - INI 测试 API
// ============================================================================

public class IniTestingAPIs {
    public static func loadNpmrcFromJS(globalThis: JSGlobalObject, callframe: CallFrame): JsValue {
        let parsed = parseIniString(callframe.argument(0).toString())
        let obj = JsObject.make()
        obj.set("default_registry_url", JsValue(valueOrDefault(parsed, "registry", "https://registry.npmjs.org/")))
        obj.set("default_registry_token", JsValue(valueOrDefault(parsed, "_authToken", "")))
        obj.set("default_registry_username", JsValue(valueOrDefault(parsed, "username", "")))
        obj.set("default_registry_password", JsValue(valueOrDefault(parsed, "_password", "")))
        obj.set("default_registry_email", JsValue(valueOrDefault(parsed, "email", "")))
        return JsValue(obj)
    }

    public static func parse(globalThis: JSGlobalObject, callframe: CallFrame): JsValue {
        let parsed = parseIniString(callframe.argument(0).toString())
        let obj = JsObject.make()
        for ((key, value) in parsed) {
            obj.set(key, JsValue(value))
        }
        return JsValue(obj)
    }

    private static func valueOrDefault(map: HashMap<String, String>, key: String, defaultValue: String): String {
        match (map.get(key)) {
            case Some(value) => value
            case None => defaultValue
        }
    }

    private static func parseIniString(input: String): HashMap<String, String> {
        let result = HashMap<String, String>()
        var start: Int64 = 0
        var i: Int64 = 0
        while (i <= input.size) {
            if (i == input.size || input[i] == UInt8(10)) {
                parseLine(input[start..i], result)
                start = i + 1
            }
            i++
        }
        return result
    }

    private static func parseLine(rawLine: String, result: HashMap<String, String>): Unit {
        var line = trim(rawLine)
        if (line.size == 0 || line.startsWith("#") || line.startsWith(";")) { return }
        if (line.startsWith("[")) { return }

        let eq = line.indexOf('=')
        if (eq < 0) { return }
        let key = trim(line[0..eq])
        var value = trim(line[eq + 1..])
        if (value.size >= 2) {
            let first = value[0]
            let last = value[value.size - 1]
            if ((first == UInt8(34) && last == UInt8(34)) || (first == UInt8(39) && last == UInt8(39))) {
                value = value[1..value.size - 1]
            }
        }
        result.put(key, value)
    }

    private static func trim(input: String): String {
        var start: Int64 = 0
        var end = input.size
        while (start < end && isWhitespace(input[start])) { start++ }
        while (end > start && isWhitespace(input[end - 1])) { end-- }
        return input[start..end]
    }

    private static func isWhitespace(ch: UInt8): Bool {
        ch == UInt8(32) || ch == UInt8(9) || ch == UInt8(13)
    }
}
