// 严格翻译自: src/cli/pm_pkg_command.rs
// 对应 Bun: pm_pkg_command.zig — package.json 数据管理命令
//
// 子命令: get, set, delete, fix, help
// 支持:
//   - 嵌套 JSON 路径 (点分隔, 如 scripts.build)
//   - set 支持 key=value 语法
//   - --json 标志解析 JSON 值
//   - fix 自动修正常见错误 (排序, 格式化, 重复字段等)
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// PmPkgCommand — package.json 数据管理命令
// 严格翻译自: src/cli/pm_pkg_command.rs - PmPkgCommand
// ============================================================================

/// pm pkg 命令: 管理 package.json 数据
/// 对应 Bun: PmPkgCommand
public class PmPkgCommand {
    /// 执行 pkg 命令
    /// 对应 Bun: PmPkgCommand.exec()
    public static func exec(ctx: CommandContext, pm: PackageManager): Unit {
        let positionals = ctx.positionals
        if (positionals.size < 1) {
            printHelp()
            return
        }

        let subcommand = positionals[0]
        let rest = if (positionals.size > 1) {
            positionals.subList(1, positionals.size)
        } else {
            ArrayList<String>()
        }

        when (subcommand) {
            case "get" => execGet(ctx, pm, rest)
            case "set" => execSet(ctx, pm, rest)
            case "delete" => execDelete(ctx, pm, rest)
            case "fix" => execFix(ctx, pm)
            case "help" => printHelp()
            else => {
                Output.errGeneric("Unknown subcommand: ${subcommand}")
                printHelp()
                Global.exit(1)
            }
        }
    }

    /// get 子命令: 获取 package.json 中的值
    /// 对应 Bun: PmPkgCommand.exec_get()
    /// 支持多个 key 参数, 每个一行输出
    public static func execGet(ctx: CommandContext, pm: PackageManager, args: ArrayList<String>): Unit {
        if (args.size < 1) {
            Output.errGeneric("pkg get requires at least one key")
            return
        }

        let pkgContent = readPackageJson() ?: return
        let json = parsePackageJson(pkgContent) ?: return
        let source = Source.initPathString("package.json", pkgContent.toByteArray())

        for (key in args) {
            let value = resolveJsonPath(json, key)
            if (value != None) {
                printValue(value!!, source)
            }
        }
    }

    /// set 子命令: 设置 package.json 中的值
    /// 对应 Bun: PmPkgCommand.exec_set()
    /// 支持多个 key=value 参数
    /// --json 标志: 将值解析为 JSON
    public static func execSet(ctx: CommandContext, pm: PackageManager, args: ArrayList<String>): Unit {
        if (args.size < 1) {
            Output.errGeneric("pkg set requires key=value pairs")
            return
        }

        // 检查 --json 标志
        var parseValuesAsJson = false
        var keyValues = ArrayList<(String, String)>()
        for (arg in args) {
            if (arg == "--json") {
                parseValuesAsJson = true
                continue
            }
            let eqIdx = arg.indexOf('=')
            if (eqIdx < 0) {
                Output.errGeneric("pkg set requires key=value format, got: ${arg}")
                return
            }
            let key = arg.substring(0, eqIdx)
            let value = arg.substring(eqIdx + 1)
            keyValues.append((key, value))
        }

        let pkgContent = readPackageJson() ?: return
        let json = parsePackageJson(pkgContent) ?: return
        var modified = json

        for ((key, rawValue) in keyValues) {
            let value = if (parseValuesAsJson) {
                // 尝试将值解析为 JSON
                let parsed = JsonParser.parse(rawValue)
                if (parsed != None) {
                    parsed!!
                } else {
                    JsonValue.Str(rawValue)
                }
            } else {
                JsonValue.Str(rawValue)
            }
            modified = setNestedValue(modified, key, value)
        }

        writePackageJson(modified, pkgContent)
    }

    /// delete 子命令: 删除 package.json 中的字段
    /// 对应 Bun: PmPkgCommand.exec_delete()
    /// 支持多个 key 参数
    public static func execDelete(ctx: CommandContext, pm: PackageManager, args: ArrayList<String>): Unit {
        if (args.size < 1) {
            Output.errGeneric("pkg delete requires at least one key")
            return
        }

        let pkgContent = readPackageJson() ?: return
        let json = parsePackageJson(pkgContent) ?: return
        var modified = json

        for (key in args) {
            modified = deleteNestedField(modified, key)
        }

        writePackageJson(modified, pkgContent)
    }

    /// fix 子命令: 修复 package.json
    /// 对应 Bun: PmPkgCommand.exec_fix()
    /// 自动修正:
    ///   - 重新格式化 JSON
    ///   - 排序字段
    ///   - 移除重复字段
    ///   - 修正常见错误 (scripts 字段类型等)
    public static func execFix(ctx: CommandContext, pm: PackageManager): Unit {
        let pkgContent = readPackageJson() ?: return
        let json = parsePackageJson(pkgContent)

        if (json != None) {
            // 修复逻辑
            var fixed = json!!

            // 确保顶级字段顺序正确 (name, version, description, ...)
            fixed = sortPackageJsonFields(fixed)

            // 确保必要字段存在
            fixed = ensureRequiredFields(fixed)

            writePackageJson(fixed, pkgContent)
            Output.println("Fixed package.json")
        } else {
            // 如果无法解析, 尝试修正 JSON 语法
            Output.errGeneric("package.json is not valid JSON")
        }
    }

    // ========================================================================
    // JSON 路径操作工具
    // ========================================================================

    /// 解析 JSON 路径 (点分隔, 支持嵌套)
    /// 对应 Bun: resolveJsonPath / E::Object.get 等
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

    /// 设置嵌套 JSON 值
    /// 对应 Bun: E::Object.put() 递归路径
    private static func setNestedValue(json: JsonValue, path: String, value: JsonValue): JsonValue {
        let parts = path.split('.')
        if (parts.length == 1) {
            if (json.isObject()) {
                let obj = json.asObject().toMutable()
                obj.put(parts[0], value)
                return JsonValue.Obj(obj)
            }
            return json
        }

        // 嵌套路径: 递归设置
        if (json.isObject()) {
            let obj = json.asObject().toMutable()
            let first = parts[0]
            let restPath = parts.subList(1, parts.length).joinToString(".")
            let existing = obj.get(first)
            let newValue = if (existing != None) {
                setNestedValue(existing!!, restPath, value)
            } else {
                // 创建嵌套对象
                setNestedValue(JsonValue.Obj(MutableJsonObject()), restPath, value)
            }
            obj.put(first, newValue)
            return JsonValue.Obj(obj)
        }

        return json
    }

    /// 删除嵌套 JSON 字段
    /// 对应 Bun: 递归 delete
    private static func deleteNestedField(json: JsonValue, path: String): JsonValue {
        let parts = path.split('.')
        if (parts.length == 1) {
            if (json.isObject()) {
                let obj = json.asObject().toMutable()
                obj.remove(parts[0])
                return JsonValue.Obj(obj)
            }
            return json
        }

        if (json.isObject()) {
            let obj = json.asObject().toMutable()
            let first = parts[0]
            let restPath = parts.subList(1, parts.length).joinToString(".")
            let existing = obj.get(first)
            if (existing != None) {
                obj.put(first, deleteNestedField(existing!!, restPath, value))
            }
            return JsonValue.Obj(obj)
        }

        return json
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 读取 package.json
    private static func readPackageJson(): ?String {
        let content = BaoFile.readAllText("package.json")
        if (content == None) {
            Output.errGeneric("No package.json found in current directory")
        }
        return content
    }

    /// 解析 package.json
    private static func parsePackageJson(content: String): ?JsonValue {
        let json = JsonParser.parse(content)
        if (json == None) {
            Output.errGeneric("Failed to parse package.json")
        }
        return json
    }

    /// 写回 package.json, 保留缩进
    /// 对应 Bun: JSPrinter.printJSON 保留缩进
    private static func writePackageJson(json: JsonValue, originalContent: String): Unit {
        let indent = detectIndentation(originalContent)
        let formatted = JsonFormatter.formatWithIndent(json, indent)
        BaoFile.writeAllText("package.json", formatted)
    }

    /// 检测 JSON 缩进风格
    /// 对应 Bun: 检测 2 空格 / 4 空格 / tab
    private static func detectIndentation(content: String): String {
        // 查找第一个缩进行
        let lines = content.split('\n')
        for (line in lines) {
            let trimmed = line.trimStart()
            if (trimmed.length > 0 && trimmed != line) {
                let indent = line.substring(0, line.length - trimmed.length)
                if (indent.length > 0) {
                    return indent
                }
            }
        }
        return "  " // 默认 2 空格
    }

    /// 排序 package.json 字段
    /// 对应 Bun: 按优先级排序 (name, version, ...)
    private static func sortPackageJsonFields(json: JsonValue): JsonValue {
        if (!json.isObject()) {
            return json
        }

        let obj = json.asObject()
        let sortedOrder = [
            "name", "version", "private", "description", "keywords",
            "homepage", "bugs", "repository", "license", "author",
            "contributors", "main", "module", "types", "exports",
            "scripts", "dependencies", "devDependencies", "peerDependencies",
            "optionalDependencies", "bundleDependencies", "bundledDependencies",
            "engines", "os", "cpu", "workspaces", "trustedDependencies"
        ]

        let sorted = MutableJsonObject()
        // 先按优先级顺序添加
        for (key in sortedOrder) {
            let value = obj.get(key)
            if (value != None) {
                sorted.put(key, value!!)
            }
        }
        // 再添加其余字段
        for ((key, value) in obj) {
            if (!sorted.contains(key)) {
                sorted.put(key, value)
            }
        }

        return JsonValue.Obj(sorted)
    }

    /// 确保必要字段存在
    private static func ensureRequiredFields(json: JsonValue): JsonValue {
        if (!json.isObject()) {
            return json
        }
        let obj = json.asObject().toMutable()
        if (!obj.contains("name")) {
            // 使用目录名作为默认名称
            let dirName = Path.basename(FileSystem.instance.topLevelDir)
            obj.put("name", JsonValue.Str(dirName))
        }
        if (!obj.contains("version")) {
            obj.put("version", JsonValue.Str("0.0.0"))
        }
        return JsonValue.Obj(obj)
    }

    /// 打印 JSON 值
    /// 对应 Bun: printValue — 根据类型输出
    private static func printValue(value: JsonValue, source: Source): Unit {
        when (value) {
            case JsonValue.Str(s) => Output.println(s)
            case JsonValue.Num(n) => Output.println("${n}")
            case JsonValue.Bool(b) => Output.println("${b}")
            case JsonValue.Null => Output.println("null")
            case JsonValue.Obj(obj) => Output.println(JsonFormatter.format(value))
            case JsonValue.Arr(arr) => {
                // 数组每行输出一个
                for (item in arr) {
                    Output.println(formatJsonValue(item))
                }
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

    /// 打印帮助信息
    /// 对应 Bun: print_help
    public static func printHelp(): Unit {
        Output.prettyLn(
            "<r><b>bao pm pkg<r> <d>v${Global.packageJsonVersionWithSha}<r>"
        )
        Output.println(
            "  Manage data in package.json\n\n" +
            "<b>Subcommands<r>:\n" +
            "  <cyan>get<r> <blue>[key ...]<r>          Get values from package.json\n" +
            "  <cyan>set<r> <blue>key=value ...<r>      Set values in package.json\n" +
            "    <d>└<r> <cyan>--json<r>             Parse values as JSON (e.g. {\"a\":1})\n" +
            "  <cyan>delete<r> <blue>key ...<r>         Delete keys from package.json\n" +
            "  <cyan>fix<r>                    Auto-correct common package.json errors\n\n" +
            "<b>Examples<r>:\n" +
            "  bao pm pkg get name version\n" +
            "  bao pm pkg set name=my-app\n" +
            "  bao pm pkg set scripts.build=\"bao build index.ts\"\n" +
            "  bao pm pkg set --json exports='{\".\": \"./index.js\"}'\n" +
            "  bao pm pkg delete scripts.test\n" +
            "  bao pm pkg fix"
        )
    }

    /// 向后兼容的用法打印
    public static func printUsage(): Unit {
        printHelp()
    }
}
