// 严格翻译自: src/cli/pm_view_command.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// PmViewCommand — 查看包元数据命令
// 严格翻译自: src/cli/pm_view_command.zig
//
// 从 npm registry 查看 package 元数据, 支持 HTTP 请求和属性路径查找
// ============================================================================

/// pm view 命令: 查看包的元数据
/// 对应 Bun: pm_view_command
public class PmViewCommand {
    /// 执行 view 命令
    /// 对应 Bun: PmViewCommand.exec()
    public static func exec(ctx: CommandContext, pm: PackageManager): Unit {
        val positionals = ctx.positionals
        if (positionals.size < 1) {
            Output.errGeneric("Package name required")
            return
        }

        val packageSpec = positionals[0]
        val propertyPath = if (positionals.size > 1) positionals[1] else None

        // 解析包名和版本
        val (packageName, version) = parsePackageSpec(packageSpec)

        // 从 registry 获取元数据
        val metadata = fetchPackageMetadata(pm, packageName, version)
        if (metadata == None) {
            Output.errGeneric("Package not found: ${packageName}")
            return
        }

        // 打印结果
        if (propertyPath != None) {
            val value = PackageManagerCommand.resolveJsonPath(metadata!!, propertyPath!!)
            if (value != None) {
                Output.println(formatJsonValue(value!!))
            } else {
                Output.errGeneric("Property not found: ${propertyPath!!}")
            }
        } else {
            Output.println(formatJsonValue(metadata!!))
        }
    }

    /// 解析包规格 (name@version)
    /// 对应 Bun: parsePackageSpec()
    private static func parsePackageSpec(spec: String): (String, ?String) {
        // 处理 @scope/package@version 格式
        val atCount = spec.countChars('@')
        if (spec[0] == '@' && atCount > 1) {
            // @scope/package@version
            val secondAt = spec.indexOf('@', 1)
            if (secondAt >= 0) {
                val name = spec.substring(0, secondAt)
                val version = spec.substring(secondAt + 1)
                return (name, Some(version))
            }
        } else if (atCount == 1 && spec[0] != '@') {
            // package@version
            val atIdx = spec.indexOf('@')
            if (atIdx >= 0) {
                val name = spec.substring(0, atIdx)
                val version = spec.substring(atIdx + 1)
                return (name, Some(version))
            }
        }

        return (spec, None)
    }

    /// 从 registry 获取包元数据
    /// 对应 Bun: fetchPackageMetadata (HTTP GET)
    private static func fetchPackageMetadata(pm: PackageManager, packageName: String, version: ?String): ?JsonValue {
        val scope = pm.scopeForPackageName(packageName)
        var url = "${Strings.withoutTrailingSlash(scope.url)}/${packageName}"
        if (version != None) {
            url += "/${version!!}"
        }

        val headers = HashMap<String, String>()
        headers.put("accept", "application/json")
        if (scope.token.length > 0) {
            headers.put("authorization", "Bearer ${scope.token}")
        }

        val response = HttpClient.getSynchronous(url, headers)
        if (response == None) {
            return None
        }

        return JsonParser.parse(response!!)
    }

    /// 格式化 JSON 值
    private static func formatJsonValue(value: JsonValue): String {
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
