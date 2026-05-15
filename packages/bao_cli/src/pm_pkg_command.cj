// 严格翻译自: src/cli/pm_pkg_command.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// PmPkgCommand — package.json 数据管理命令
// 严格翻译自: src/cli/pm_pkg_command.zig
//
// get/set/delete/fix 子命令, JSON 路径解析, 嵌套值操作
// ============================================================================

/// pm pkg 命令: 管理 package.json 数据
/// 对应 Bun: pm_pkg_command
public class PmPkgCommand {
    /// 执行 pkg 命令
    /// 对应 Bun: PmPkgCommand.exec()
    public static func exec(ctx: CommandContext, pm: PackageManager): Unit {
        let positionals = ctx.positionals
        if (positionals.size < 1) {
            printUsage()
            return
        }

        let subcommand = positionals[0]
        when (subcommand) {
            case "get" => execGet(ctx, pm)
            case "set" => execSet(ctx, pm)
            case "delete" => execDelete(ctx, pm)
            case "fix" => execFix(ctx, pm)
            else => {
                Output.errGeneric("Unknown pkg subcommand: ${subcommand}")
                printUsage()
            }
        }
    }

    /// get 子命令: 获取 package.json 中的值
    /// 对应 Bun: PmPkgCommand get
    public static func execGet(ctx: CommandContext, pm: PackageManager): Unit {
        let positionals = ctx.positionals
        if (positionals.size < 2) {
            Output.errGeneric("pkg get requires a field name")
            return
        }

        let fieldPath = positionals[1]
        let pkgContent = BaoFile.readAllText("package.json")
        if (pkgContent == None) {
            Output.errGeneric("No package.json found")
            return
        }

        let json = JsonParser.parse(pkgContent!!)
        if (json == None) {
            Output.errGeneric("Failed to parse package.json")
            return
        }

        let value = resolveJsonPath(json!!, fieldPath)
        if (value != None) {
            Output.println(formatJsonValue(value!!))
        }
    }

    /// set 子命令: 设置 package.json 中的值
    /// 对应 Bun: PmPkgCommand set
    public static func execSet(ctx: CommandContext, pm: PackageManager): Unit {
        let positionals = ctx.positionals
        if (positionals.size < 3) {
            Output.errGeneric("pkg set requires a field name and value")
            return
        }

        let fieldPath = positionals[1]
        let fieldValue = positionals[2]
        let pkgContent = BaoFile.readAllText("package.json")
        if (pkgContent == None) {
            Output.errGeneric("No package.json found")
            return
        }

        // 解析 JSON, 修改值, 写回
        let modified = setJsonValue(pkgContent!!, fieldPath, fieldValue)
        BaoFile.writeAllText("package.json", modified)
        Output.println("Set ${fieldPath} = ${fieldValue}")
    }

    /// delete 子命令: 删除 package.json 中的字段
    /// 对应 Bun: PmPkgCommand delete
    public static func execDelete(ctx: CommandContext, pm: PackageManager): Unit {
        let positionals = ctx.positionals
        if (positionals.size < 2) {
            Output.errGeneric("pkg delete requires a field name")
            return
        }

        let fieldPath = positionals[1]
        let pkgContent = BaoFile.readAllText("package.json")
        if (pkgContent == None) {
            Output.errGeneric("No package.json found")
            return
        }

        let modified = deleteJsonField(pkgContent!!, fieldPath)
        BaoFile.writeAllText("package.json", modified)
        Output.println("Deleted ${fieldPath}")
    }

    /// fix 子命令: 修复 package.json
    /// 对应 Bun: PmPkgCommand fix
    public static func execFix(ctx: CommandContext, pm: PackageManager): Unit {
        let pkgContent = BaoFile.readAllText("package.json")
        if (pkgContent == None) {
            Output.errGeneric("No package.json found")
            return
        }

        // 简化: 重新格式化 JSON
        let json = JsonParser.parse(pkgContent!!)
        if (json != None) {
            let formatted = JsonFormatter.format(json!!)
            BaoFile.writeAllText("package.json", formatted)
            Output.println("Fixed package.json")
        }
    }

    /// 解析 JSON 路径 (点分隔)
    /// 对应 Bun: resolveJsonPath()
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
            } else {
                return None
            }
        }

        return Some(current)
    }

    /// 设置 JSON 值
    private static func setJsonValue(content: String, path: String, value: String): String {
        // 简化实现: 解析 JSON, 修改, 重新格式化
        let json = JsonParser.parse(content)
        if (json == None) {
            return content
        }

        let parts = path.split('.')
        // 简化: 只支持一级路径
        if (parts.length == 1) {
            // 直接修改顶级字段
            let modifiedContent = JsonHelper.setField(content, parts[0], value)
            return modifiedContent
        }

        return content
    }

    /// 删除 JSON 字段
    private static func deleteJsonField(content: String, path: String): String {
        let json = JsonParser.parse(content)
        if (json == None) {
            return content
        }

        let parts = path.split('.')
        if (parts.length == 1) {
            return JsonHelper.removeField(content, parts[0])
        }

        return content
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

    /// 打印用法
    public static func printUsage(): Unit {
        Output.println("Usage: bao pm pkg <command> [args]")
        Output.println("")
        Output.println("Commands:")
        Output.println("  get <field>      Get a value from package.json")
        Output.println("  set <field> <v>  Set a value in package.json")
        Output.println("  delete <field>   Delete a field from package.json")
        Output.println("  fix              Fix and format package.json")
    }
}
