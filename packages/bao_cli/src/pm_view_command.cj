// 严格翻译自: src/cli/pm_view_command.rs
// 对应 Bun: pm_view_command.zig — 从 npm registry 查看 package 元数据
//
// 支持:
//   - 包名解析 (name@version, @scope/name, "." / "" 为当前包)
//   - HTTP GET registry 元数据
//   - 属性路径查找 (dot-separated)
//   --json 输出模式
package bao_cli

import bao_core.*
import bao_install.*
import bao_http.*

// ============================================================================
// PmViewCommand — 查看包元数据命令
// 严格翻译自: src/cli/pm_view_command.rs - view()
// ============================================================================

/// pm view 命令: 查看包的元数据
/// 对应 Bun: pm_view_command view()
public class PmViewCommand {
    /// 执行 view 命令
    /// 对应 Bun: view(manager, spec_, property_path, json_output)
    public static func exec(ctx: CommandContext, pm: PackageManager): Unit {
        let positionals = ctx.positionals
        if (positionals.size < 1) {
            Output.errGeneric("Package name required")
            return
        }

        let packageSpec = positionals[0]
        let propertyPath = if (positionals.size > 1) Some(positionals[1]) else None

        // 解析包名和版本
        // 对应 Bun: dependency.split_name_and_version_or_latest
        var name = packageSpec
        var version: ?String = None

        // 特殊处理 "." 和 "" — 当前包
        if (packageSpec == "." || packageSpec == "") {
            // 尝试从 package.json 获取包名
            let pkgName = readCurrentPackageName(pm)
            if (pkgName != None) {
                name = pkgName!!
            } else {
                name = Path.basename(FileSystem.instance.topLevelDir)
            }
        } else {
            val (parsedName, parsedVersion) = parsePackageSpec(packageSpec)
            name = parsedName
            version = parsedVersion
        }

        // 从 registry 获取元数据
        // 对应 Bun: scope_for_package_name + URL::parse + HTTP GET
        let metadata = fetchPackageMetadata(pm, name, version)
        if (metadata == None) {
            Output.errGeneric("Package not found: ${name}")
            return
        }

        // 打印结果
        if (propertyPath != None) {
            let value = resolveJsonPath(metadata!!, propertyPath!!)
            if (value != None) {
                // 检查是否为数组 (多值输出, 每行一个)
                if (value!!.isArray()) {
                    let arr = value!!.asArray()
                    for (item in arr) {
                        Output.println(formatJsonValue(item))
                    }
                } else {
                    Output.println(formatJsonValue(value!!))
                }
            } else {
                Output.errGeneric("Property not found: ${propertyPath!!}")
            }
        } else {
            printPackageInfo(metadata!!)
        }
    }

    /// view 函数的完整版本 (支持 json 输出模式)
    /// 对应 Bun: view(manager, spec_, property_path, json_output)
    public static func view(pm: PackageManager, spec: String, propertyPath: ?String, jsonOutput: Bool): Unit {
        var name = spec
        var version: ?String = None

        if (spec == "." || spec == "") {
            let pkgName = readCurrentPackageName(pm)
            if (pkgName != None) {
                name = pkgName!!
            } else {
                name = Path.basename(FileSystem.instance.topLevelDir)
            }
        } else {
            val (parsedName, parsedVersion) = parsePackageSpec(spec)
            name = parsedName
            version = parsedVersion
        }

        let metadata = fetchPackageMetadata(pm, name, version)
        if (metadata == None) {
            Output.errGeneric("Package not found: ${name}")
            return
        }

        if (propertyPath != None) {
            let value = resolveJsonPath(metadata!!, propertyPath!!)
            if (value != None) {
                if (jsonOutput) {
                    Output.println(JsonFormatter.format(value!!))
                } else {
                    if (value!!.isArray()) {
                        for (item in value!!.asArray()) {
                            Output.println(formatJsonValue(item))
                        }
                    } else {
                        Output.println(formatJsonValue(value!!))
                    }
                }
            } else {
                Output.errGeneric("Property not found: ${propertyPath!!}")
            }
        } else {
            if (jsonOutput) {
                Output.println(JsonFormatter.format(metadata!!))
            } else {
                printPackageInfo(metadata!!)
            }
        }
    }

    /// 读取当前 package.json 中的 name 字段
    /// 对应 Bun: 尝试从 package.json 读取 name
    private static func readCurrentPackageName(pm: PackageManager): ?String {
        let pkgContent = BaoFile.readAllText("package.json")
        if (pkgContent == None) {
            return None
        }
        let json = JsonParser.parse(pkgContent!!)
        if (json != None && json!!.isObject()) {
            let name = json!!.asObject().get("name")
            if (name != None && name!!.isString()) {
                let nameStr = name!!.asString()
                if (nameStr.length > 0) {
                    return nameStr
                }
            }
        }
        return None
    }

    /// 解析包规格 (name@version)
    /// 对应 Bun: dependency.split_name_and_version_or_latest
    private static func parsePackageSpec(spec: String): (String, ?String) {
        // 处理 @scope/package@version 格式
        let atCount = spec.countChars('@')
        if (spec[0] == '@' && atCount > 1) {
            // @scope/package@version
            let secondAt = spec.indexOf('@', 1)
            if (secondAt >= 0) {
                let name = spec.substring(0, secondAt)
                let version = spec.substring(secondAt + 1)
                return (name, Some(version))
            }
        } else if (atCount == 1 && spec[0] != '@') {
            // package@version
            let atIdx = spec.indexOf('@')
            if (atIdx >= 0) {
                let name = spec.substring(0, atIdx)
                let version = spec.substring(atIdx + 1)
                return (name, Some(version))
            }
        }

        return (spec, None)
    }

    /// 从 registry 获取包元数据
    /// 对应 Bun: HTTP GET + JSON parse
    /// 对应 Bun 的 URL 构建:
    ///   scope.url + "/" + dependencyUrl(name)
    private static func fetchPackageMetadata(pm: PackageManager, packageName: String, version: ?String): ?JsonValue {
        let scope = pm.scopeForPackageName(packageName)
        let encodedName = DependencyUrl.encode(packageName)
        var url = "${Strings.withoutTrailingSlash(scope.url.href)}/${encodedName}"

        // 获取完整 manifest (不限定版本)
        let headers = HashMap<String, String>()
        headers.put("accept", "application/json")
        if (scope.token.length > 0) {
            headers.put("authorization", "Bearer ${scope.token}")
        }

        // HTTP 代理和 TLS 配置
        // 对应 Bun: manager.http_proxy / manager.tls_reject_unauthorized
        let response = HttpClient.getSynchronous(url, headers)
        if (response == None) {
            return None
        }

        return JsonParser.parse(response!!)
    }

    /// 解析 JSON 路径 (点分隔)
    /// 对应 Bun: resolveJsonPath
    public static func resolveJsonPath(json: JsonValue, path: String): ?JsonValue {
        let parts = path.split('.')
        var current: JsonValue = json

        for (part in parts) {
            if (current.isObject()) {
                let obj = current.asObject()
                if (obj.contains(part)) {
                    current = obj.get(part)!!
                } else {
                    return None
                }
            } else if (current.isArray()) {
                // 支持数组索引: versions.0, versions[0]
                let idx = Int64.parse(part)
                if (idx != None) {
                    let arr = current.asArray()
                    if (idx!! >= 0 && idx!! < arr.length) {
                        current = arr[idx!!]
                    } else {
                        return None
                    }
                } else {
                    return None
                }
            } else {
                return None
            }
        }

        return Some(current)
    }

    /// 打印包信息 (格式化输出)
    /// 对应 Bun: 打印 registry 返回的 manifest
    private static func printPackageInfo(metadata: JsonValue): Unit {
        if (!metadata.isObject()) {
            Output.println(formatJsonValue(metadata))
            return
        }

        let obj = metadata.asObject()

        // 打印关键字段
        printField(obj, "name")
        printField(obj, "description")
        printField(obj, "version")
        printField(obj, "license")

        // 打印关键词
        let keywords = obj.get("keywords")
        if (keywords != None && keywords!!.isArray()) {
            let kw = keywords!!.asArray().map { it.asString() }.joinToString(" ")
            Output.println("keywords: ${kw}")
        }

        // 打印依赖
        printDependencies(obj, "dependencies")
        printDependencies(obj, "devDependencies")
        printDependencies(obj, "peerDependencies")

        // 打印可用版本
        let versions = obj.get("versions")
        if (versions != None && versions!!.isObject()) {
            let versionList = versions!!.asObject().keys()
            Output.println("versions: ${versionList.length} versions available")
            // 显示最近的 5 个版本
            let recentCount = Math.min(5, versionList.length)
            Output.print("  (latest: ")
            for (i in 0..recentCount) {
                if (i > 0) {
                    Output.print(", ")
                }
                Output.print(versionList[versionList.length - 1 - i])
            }
            Output.println(")")
        }

        // 打印 dist-tags
        let distTags = obj.get("dist-tags")
        if (distTags != None && distTags!!.isObject()) {
            Output.println("dist-tags:")
            for ((tag, ver) in distTags!!.asObject()) {
                Output.println("  ${tag}: ${ver.asString()}")
            }
        }
    }

    private static func printField(obj: JsonObject, field: String): Unit {
        let value = obj.get(field)
        if (value != None) {
            Output.println("${field}: ${formatJsonValue(value!!)}")
        }
    }

    private static func printDependencies(obj: JsonObject, field: String): Unit {
        let deps = obj.get(field)
        if (deps != None && deps!!.isObject() && deps!!.asObject().size > 0) {
            Output.println("${field}:")
            for ((name, version) in deps!!.asObject()) {
                Output.println("  ${name}: ${version.asString()}")
            }
        }
    }

    /// 格式化 JSON 值
    public static func formatJsonValue(value: JsonValue): String {
        when (value) {
            case JsonValue.Str(s) => return s
            case JsonValue.Num(n) => return "${n}"
            case JsonValue.Bool(b) => return "${b}"
            case JsonValue.Null => return "null"
            case JsonValue.Obj(obj) => return JsonFormatter.format(value)
            case JsonValue.Arr(arr) => return JsonFormatter.format(value)
        }
    }
}
