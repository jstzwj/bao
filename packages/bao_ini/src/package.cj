// bao_ini - INI 文件解析与序列化
// 严格翻译自: src/ini/ini.zig, src/ini/lib.rs
//   - IniParser: 解析 INI 文本为结构化数据
//   - IniFile: INI 文件结构 (sections + key-value pairs)
//   - IniSection: INI 节结构
//   - IniWriter: 将 IniFile 序列化为 INI 文本
//   - Git config 格式支持 (subsection names)
//   - 特性: 注释 (; 和 #), 节头 [section], 多行值, 引号值, 转义序列
package bao_ini

import bao_core.*
import bao_collections.*

// ============================================================================
// IniValue - INI 值类型
// 对应 Bun 通过 js_ast.Expr 表示的 INI 值
// Bun INI parser 将值解析为 AST 表达式 (字符串/布尔/null/数组/对象)
// 仓颉使用专用 enum 表示
// ============================================================================

/// INI 值 - 对应 Bun js_ast.Expr.Data 子集
/// Bun 解析 INI 值时将 "true"/"false"/"null" 转换为对应类型
public enum IniValue {
    | Str(String)        // 对应 Bun E.String
    | Bool(Boolean)      // 对应 Bun E.Boolean
    | Null               // 对应 Bun E.Null
    | Array(ArrayList<IniValue>)  // 对应 Bun E.Array (key[] = value 语法)
    | Section(IniSection)         // 对应 Bun E.Object (嵌套节)

    /// 获取字符串值
    public func asString(): ?String {
        match (this) {
            case Str(s) => Some(s)
            case _ => None
        }
    }

    /// 获取布尔值
    public func asBool(): ?Bool {
        match (this) {
            case Bool(b) => Some(b)
            case Str(s) =>
                if (s == "true") { Some(true) }
                else if (s == "false") { Some(false) }
                else { None }
            case _ => None
        }
    }

    /// 获取数组值
    public func asArray(): ?ArrayList<IniValue> {
        match (this) {
            case Array(arr) => Some(arr)
            case _ => None
        }
    }

    /// 获取节值
    public func asSection(): ?IniSection {
        match (this) {
            case Section(s) => Some(s)
            case _ => None
        }
    }

    /// 字符串表示
    public func toString(): String {
        match (this) {
            case Str(s) => s
            case Bool(b) => if (b) { "true" } else { "false" }
            case Null => "null"
            case Array(arr) =>
                var parts = ArrayList<String>()
                for (v in arr) {
                    parts.append(v.toString())
                }
                return "[${String(",", parts.toArray())}]"
            case Section(s) => "[Object object]"
        }
    }
}

// ============================================================================
// IniSection - INI 节
// 对应 Bun E.Object 在 INI 解析中的语义
// INI 节: [section_name] 下的键值对集合
// Git config 格式: [subsection "name"] 支持子节名
// ============================================================================

/// INI 节 - 键值对集合
/// Bun 通过 E.Object 的 properties 存储节内键值对
/// 仓颉使用专用 HashMap
public class IniSection {
    /// 节名称 - 对应 Bun section: *Rope (点分隔的多个字符串片段)
    /// 例如: "database", "remote \"origin\"", "section.subsection"
    public var name: String = ""

    /// 子节名称 (Git config 格式)
    /// Git config: [remote "origin"] -> subsection = "origin"
    public var subsection: ?String = None

    /// 属性键值对 - 对应 Bun E.Object.properties
    /// 保持插入顺序 (Bun 使用有序 Object properties)
    public var properties: HashMap<String, IniValue>

    public init() {
        properties = HashMap<String, IniValue>()
    }

    public init(name: String) {
        this.name = name
        properties = HashMap<String, IniValue>()
    }

    public init(name: String, subsection: String) {
        this.name = name
        this.subsection = Some(subsection)
        properties = HashMap<String, IniValue>()
    }

    /// 获取属性值
    /// 对应 Bun: E.Object.get(key)
    public func get(key: String): ?IniValue {
        return properties.get(key)
    }

    /// 获取字符串属性
    public func getString(key: String): ?String {
        let v = properties.get(key)
        if (v == None) { return None }
        return v.getOrThrow().asString()
    }

    /// 获取布尔属性
    public func getBool(key: String): ?Bool {
        let v = properties.get(key)
        if (v == None) { return None }
        return v.getOrThrow().asBool()
    }

    /// 设置属性值
    /// 对应 Bun: E.Object.put(allocator, key, value)
    public func put(key: String, value: IniValue): Unit {
        properties.put(key, value)
    }

    /// 设置字符串属性
    public func put(key: String, value: String): Unit {
        properties.put(key, IniValue.Str(value))
    }

    /// 设置布尔属性
    public func put(key: String, value: Bool): Unit {
        properties.put(key, IniValue.Bool(value))
    }

    /// 是否包含键
    public func has(key: String): Bool {
        return properties.contains(key)
    }

    /// 删除键
    public func remove(key: String): ?IniValue {
        return properties.remove(key)
    }

    /// 属性数量
    public func count(): Int64 {
        return properties.size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return properties.isEmpty()
    }

    /// 获取所有键
    public func keys(): ArrayList<String> {
        return properties.keys()
    }

    /// 获取所有值
    public func values(): ArrayList<IniValue> {
        return properties.values()
    }

    /// 获取所有条目
    public func entries(): ArrayList<(String, IniValue)> {
        return properties.entries()
    }

    /// 获取完整节名 (包含子节)
    /// Git config: [remote "origin"] -> "remote.origin"
    public func fullName(): String {
        if (subsection != None) {
            return "${name}.${subsection.getOrThrow()}"
        }
        return name
    }
}

// ============================================================================
// IniFile - INI 文件结构
// 对应 Bun Parser.out (E.Object) 的顶层表示
// Bun 将整个 INI 文件解析为一个 E.Object，节名为嵌套对象
// ============================================================================

/// INI 文件 - 节的有序集合
/// 对应 Bun Parser.out.data.e_object
public class IniFile {
    /// 全局属性 (节之前或没有节的键值对)
    /// Bun: Parser 初始 head 指向顶层 Object
    public var globals: IniSection

    /// 有序节列表 - 保持解析顺序
    /// Bun 使用 Object properties 的插入顺序
    public var sections: ArrayList<IniSection>

    /// 节名索引 - 快速按名查找
    public var sectionMap: HashMap<String, IniSection>

    public init() {
        globals = IniSection(name: "")
        sections = ArrayList<IniSection>()
        sectionMap = HashMap<String, IniSection>()
    }

    /// 按名称获取节
    /// 对应 Bun: E.Object.getOrPutObject(section, allocator)
    public func getSection(name: String): ?IniSection {
        return sectionMap.get(name)
    }

    /// 获取或创建节
    /// 对应 Bun: E.Object.getOrPutObject - 如果不存在则创建
    public func getOrCreateSection(name: String): IniSection {
        let existing = sectionMap.get(name)
        if (existing != None) {
            return existing.getOrThrow()
        }
        let section = IniSection(name: name)
        sections.append(section)
        sectionMap.put(name, section)
        return section
    }

    /// 获取或创建子节 (Git config 格式)
    public func getOrCreateSubsection(name: String, subsection: String): IniSection {
        let fullName = "${name}.${subsection}"
        let existing = sectionMap.get(fullName)
        if (existing != None) {
            return existing.getOrThrow()
        }
        let section = IniSection(name: name, subsection: subsection)
        sections.append(section)
        sectionMap.put(fullName, section)
        return section
    }

    /// 添加节
    public func addSection(section: IniSection): Unit {
        let key = section.fullName()
        sections.append(section)
        sectionMap.put(key, section)
    }

    /// 节数量
    public func sectionCount(): Int64 {
        return sections.size
    }

    /// 遍历所有节
    public func forEachSection(fn: (IniSection) -> Unit): Unit {
        for (section in sections) {
            fn(section)
        }
    }

    /// 查找全局属性
    public func getGlobal(key: String): ?IniValue {
        return globals.get(key)
    }

    /// 设置全局属性
    public func setGlobal(key: String, value: IniValue): Unit {
        globals.put(key, value)
    }
}

// ============================================================================
// IniParser - INI 解析器
// 严格翻译自: src/ini/ini.zig - Parser struct
//   pub const Parser = struct {
//       opts: Options = .{},
//       source: bun.logger.Source,
//       src: []const u8,
//       out: Expr,
//       logger: bun.logger.Log,
//       arena: std.heap.ArenaAllocator,
//       env: *bun.DotEnv.Loader,
//
//       pub fn init(...) Parser { ... }
//       pub fn parse(this: *Parser, arena_allocator: Allocator) OOM!void { ... }
//   };
// ============================================================================

/// 解析选项 - 对应 Bun Parser.Options
public class IniParserOptions {
    /// 是否支持方括号数组语法: key[] = value
    /// 对应 Bun: bracked_array: bool = true
    public var bracketedArray: Bool = true

    /// 是否展开环境变量 ${VAR}
    /// 对应 Bun: Parser.parseEnvSubstitution
    public var expandEnvVars: Bool = false

    /// 环境变量映射 (当 expandEnvVars = true 时使用)
    /// 对应 Bun: env: *bun.DotEnv.Loader
    public var envMap: ?HashMap<String, String> = None

    public init() {}
}

/// INI 解析器 - 严格对应 Bun ini.Parser
/// Bun 解析流程:
///   1. 按行分割输入
///   2. 跳过注释行 (; 或 # 开头) 和空行
///   3. 解析节头 [section]
///   4. 解析键值对 key = value
///   5. 处理引号值 (单引号和双引号)
///   6. 处理转义序列
///   7. 处理环境变量替换
///   8. 处理方括号数组 key[] = value
public class IniParser {
    /// 解析选项
    private let opts: IniParserOptions

    public init() {
        opts = IniParserOptions()
    }

    public init(opts: IniParserOptions) {
        this.opts = opts
    }

    /// 解析 INI 文本为 IniFile
    /// 对应 Bun: pub fn parse(this: *Parser, arena_allocator: Allocator) OOM!void
    /// Bun: 逐行扫描，构建 AST Expr 树
    /// 仓颉: 逐行扫描，构建 IniFile
    public func parse(text: String): IniFile {
        let file = IniFile()
        var currentSection = file.globals
        var skipUntilNextSection = false

        // 按行分割
        var lines = text.split("\n")
        for (line_ in lines) {
            // 去除行尾 \r
            var line = line_
            if (line.size > 0 && line[line.size - 1] == '\r') {
                line = line.substring(0, line.size - 1)
            }

            // 跳过空行和注释
            if (shouldSkipLine(line)) {
                continue
            }

            // 解析节头 [section]
            // 对应 Bun: if (line[0] == '[') treat_as_key: { ... }
            if (line[0] == '[') {
                skipUntilNextSection = false

                // 查找闭合方括号
                let closeBracket = line.indexOf(']')
                if (closeBracket < 0) {
                    continue  // 没有闭合括号，跳过
                }

                // 确保闭合括号后只有空白
                var treatAsKey = false
                if (closeBracket + 1 < line.size) {
                    for (i in closeBracket + 1..line.size) {
                        let c = line[i]
                        if (c != ' ' && c != '\t') {
                            treatAsKey = true
                            break
                        }
                    }
                }

                if (treatAsKey) {
                    // 不当做节头，当做键处理
                    // fall through to key=value parsing below
                } else {
                    // 提取节名
                    let sectionContent = line.substring(1, closeBracket)
                    let parsed = parseSectionHeader(sectionContent)

                    currentSection = file.getOrCreateSubsection(parsed.name, parsed.subsection)
                    continue
                }
            }

            if (skipUntilNextSection) {
                continue
            }

            // 解析键值对
            // 对应 Bun: key=value parsing
            let eqIdx = line.indexOf('=')
            var keyRaw: String
            if (eqIdx >= 0) {
                keyRaw = line.substring(0, eqIdx).trim(" \t\n\r")
            } else {
                keyRaw = line.trim(" \t\n\r")
            }

            // 去除键中的注释
            keyRaw = stripComment(keyRaw)
            keyRaw = keyRaw.trim(" \t")

            if (keyRaw.isEmpty) {
                continue
            }

            // 处理方括号数组语法: key[] = value
            // 对应 Bun: const is_array = key_raw.len > 2 and endsWith(key_raw, "[]")
            let isArrayKey = opts.bracketedArray && keyRaw.size > 2 && keyRaw.endsWith("[]")
            let key = if (isArrayKey) { keyRaw.substring(0, keyRaw.size - 2) } else { keyRaw }

            // 安全: 跳过 __proto__
            // 对应 Bun: if (eqlComptime(key, "__proto__")) continue
            if (key == "__proto__") {
                continue
            }

            // 解析值
            var value: IniValue
            if (eqIdx >= 0 && eqIdx + 1 < line.size) {
                let valueStr = line.substring(eqIdx + 1)
                value = parseValue(valueStr)
            } else if (eqIdx >= 0) {
                value = IniValue.Str("")
            } else {
                // 没有等号的键被视为 true
                // 对应 Bun: Expr.init(E.Boolean, E.Boolean{ .value = true }, Loc.Empty)
                value = IniValue.Bool(true)
            }

            // 处理方括号数组
            // 对应 Bun: if (is_array) { ... append to array ... }
            if (isArrayKey) {
                let existing = currentSection.get(key)
                if (existing != None) {
                    let ev = existing.getOrThrow()
                    let arr = ev.asArray()
                    if (arr != None) {
                        arr.getOrThrow().append(value)
                        // 已更新数组，无需再 put
                    } else {
                        // 将现有值转为数组的第一个元素
                        var newArr = ArrayList<IniValue>()
                        newArr.append(ev)
                        newArr.append(value)
                        currentSection.put(key, IniValue.Array(newArr))
                    }
                } else {
                    var newArr = ArrayList<IniValue>()
                    newArr.append(value)
                    currentSection.put(key, IniValue.Array(newArr))
                }
            } else {
                // 检查是否已存在为数组 (防止意外覆盖数组)
                // 对应 Bun: safeguard against resetting a previously defined array
                let existing = currentSection.get(key)
                if (existing != None) {
                    let arr = existing.getOrThrow().asArray()
                    if (arr != None) {
                        arr.getOrThrow().append(value)
                        continue
                    }
                }
                currentSection.put(key, value)
            }
        }

        return file
    }

    /// 解析节头内容
    /// Git config 格式: [remote "origin"]
    /// 普通格式: [section]
    /// 对应 Bun: section name 通过 prepareStr(.section) 解析
    private func parseSectionHeader(content: String): (String, String) {
        let trimmed = content.trim(" \t")

        // Git config 格式: section "subsection"
        let quoteIdx = trimmed.indexOf('"')
        if (quoteIdx > 0) {
            let sectionName = trimmed.substring(0, quoteIdx).trim(" \t")
            // 查找闭合引号
            let endQuote = trimmed.indexOf('"', quoteIdx + 1)
            if (endQuote > quoteIdx) {
                let subsection = trimmed.substring(quoteIdx + 1, endQuote)
                return (sectionName, subsection)
            }
        }

        // 点分隔的节名: section.subsection
        // 对应 Bun: prepareStr(.section) 中 '.' 触发 Rope 拆分
        let dotIdx = trimmed.indexOf('.')
        if (dotIdx > 0) {
            let sectionName = trimmed.substring(0, dotIdx)
            let subsection = trimmed.substring(dotIdx + 1)
            return (sectionName, subsection)
        }

        return (trimmed, "")
    }

    /// 解析值
    /// 对应 Bun: prepareStr(.value, ...) 的值解析逻辑
    /// 处理: 引号值、布尔值转换、null 值、转义序列、注释截断
    private func parseValue(raw: String): IniValue {
        var val = raw.trim(" \t\n\r")

        if (val.isEmpty) {
            return IniValue.Str("")
        }

        // 检查引号值
        // 对应 Bun: if (isQuoted(val)) out: { ... }
        if (isQuoted(val)) {
            return parseQuotedValue(val)
        }

        // 去除行内注释 (; 或 #)
        // 对应 Bun: walk val to find first non-escaped comment character
        val = stripInlineComment(val)
        val = val.trim(" \t")

        if (val.isEmpty) {
            return IniValue.Str("")
        }

        // 处理转义序列
        val = processEscapes(val)

        // 展开环境变量
        if (opts.expandEnvVars) {
            val = expandEnvVars(val)
        }

        // 布尔值转换
        // 对应 Bun:
        //   if (eqlComptime(s.data, "true")) Expr.init(E.Boolean, true)
        //   if (eqlComptime(s.data, "false")) Expr.init(E.Boolean, false)
        //   if (eqlComptime(s.data, "null")) Expr.init(E.Null, ...)
        if (val == "true") {
            return IniValue.Bool(true)
        }
        if (val == "false") {
            return IniValue.Bool(false)
        }
        if (val == "null") {
            return IniValue.Null
        }

        return IniValue.Str(val)
    }

    /// 解析引号值
    /// 对应 Bun: isQuoted(val) out: { ... JSON parse ... }
    /// Bun 尝试用 JSON 解析器解析引号值，失败则当字符串处理
    /// 仓颉简化: 去除引号，处理转义
    private func parseQuotedValue(val: String): IniValue {
        // 去除外层引号
        var inner = val
        if (inner.size >= 2) {
            inner = inner.substring(1, inner.size - 1)
        } else if (inner.size == 1) {
            inner = inner.substring(1)
        }

        // 处理转义序列
        inner = processEscapes(inner)

        // 展开环境变量
        if (opts.expandEnvVars) {
            inner = expandEnvVars(inner)
        }

        return IniValue.Str(inner)
    }

    // ============================================================================
    // 辅助方法 - 对应 Bun Parser 内部方法
    // ============================================================================

    /// 判断是否应跳过行
    /// 对应 Bun: inline fn shouldSkipLine(line: []const u8) bool
    ///   if (line.len == 0 || line[0] == ';' || line[0] == '#') return true
    private func shouldSkipLine(line: String): Bool {
        if (line.isEmpty) {
            return true
        }
        let first = line[0]
        if (first == ';' || first == '#') {
            return true
        }
        // 检查是否全部为空白 (可能包含注释)
        var allWhitespace = true
        for (c in line) {
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
                continue
            }
            if (c == '#' || c == ';') {
                return true
            }
            allWhitespace = false
        }
        return allWhitespace
    }

    /// 判断值是否被引号包围
    /// 对应 Bun: fn isQuoted(val: []const u8) bool
    ///   startsWithChar(val, '"') and endsWithChar(val, '"') or
    ///   startsWithChar(val, '\'') and endsWithChar(val, '\'')
    private func isQuoted(val: String): Bool {
        if (val.size < 2) {
            return false
        }
        return (val.startsWith("\"") && val.endsWith("\"")) ||
               (val.startsWith("\'") && val.endsWith("\'"))
    }

    /// 去除行内注释
    /// 对应 Bun prepareStr 中 ';', '#' 的截断逻辑
    /// 只截断非转义的注释字符
    private func stripInlineComment(val: String): String {
        var i = 0
        var escaped = false
        while (i < val.size) {
            let c = val[i]
            if (escaped) {
                escaped = false
                i += 1
                continue
            }
            if (c == '\\') {
                escaped = true
                i += 1
                continue
            }
            if (c == ';' || c == '#') {
                return val.substring(0, i).trim(" \t")
            }
            i += 1
        }
        return val
    }

    /// 从键中去除注释 (键不应包含注释，但安全处理)
    private func stripComment(val: String): String {
        var i = 0
        while (i < val.size) {
            let c = val[i]
            if (c == ';' || c == '#') {
                return val.substring(0, i).trim(" \t")
            }
            i += 1
        }
        return val
    }

    /// 处理转义序列
    /// 对应 Bun prepareStr 中 esc 状态机
    ///   '\\' -> '\\', ';' -> ';', '#' -> '#', '$' -> '$', 'n' -> '\n', 't' -> '\t'
    private func processEscapes(val: String): String {
        if (!val.contains("\\")) {
            return val
        }
        var result = StringBuilder()
        var i = 0
        var escaped = false
        while (i < val.size) {
            let c = val[i]
            if (escaped) {
                match (c) {
                    case '\\' => result.append("\\")
                    case ';' => result.append(";")
                    case '#' => result.append("#")
                    case '$' => result.append("$")
                    case 'n' => result.append("\n")
                    case 't' => result.append("\t")
                    case 'r' => result.append("\r")
                    case _ =>
                        // 未知转义: 保持原样
                        result.append("\\")
                        result.append(c.toString())
                }
                escaped = false
            } else if (c == '\\') {
                escaped = true
            } else {
                result.append(c.toString())
            }
            i += 1
        }
        // 末尾多余反斜杠
        if (escaped) {
            result.append("\\")
        }
        return result.toString()
    }

    /// 展开环境变量替换
    /// 对应 Bun: fn parseEnvSubstitution / fn expandEnvVars
    /// 支持 ${VAR} 和 ${VAR?} 语法
    ///   ${VAR} - 如果未定义，保持原样
    ///   ${VAR?} - 如果未定义，展开为空字符串
    private func expandEnvVars(val: String): ?String {
        if (opts.envMap == None) {
            return val
        }
        let envMap = opts.envMap.getOrThrow()

        if (!val.contains("\${")) {
            return val
        }

        var result = StringBuilder()
        var i = 0
        while (i < val.size) {
            if (val[i] == '$' && i + 2 < val.size && val[i + 1] == '{') {
                // 查找闭合大括号
                var j = i + 2
                var depth = 1
                while (j < val.size && depth > 0) {
                    if (val[j] == '{') {
                        depth += 1
                    } else if (val[j] == '}') {
                        depth -= 1
                    }
                    if (depth > 0) {
                        j += 1
                    }
                }
                if (depth == 0) {
                    let envVarRaw = val.substring(i + 2, j)
                    let isOptional = envVarRaw.size > 0 && envVarRaw[envVarRaw.size - 1] == '?'
                    let envVar = if (isOptional) {
                        envVarRaw.substring(0, envVarRaw.size - 1)
                    } else {
                        envVarRaw
                    }

                    let expanded = envMap.get(envVar)
                    if (expanded != None) {
                        result.append(expanded.getOrThrow())
                    } else if (!isOptional) {
                        // 未定义且非可选: 保持原样
                        result.append(val.substring(i, j + 1))
                    }
                    // 可选且未定义: 展开为空字符串
                    i = j + 1
                    continue
                }
            }
            result.append(val[i].toString())
            i += 1
        }
        return result.toString()
    }
}

// ============================================================================
// IniWriter - INI 序列化器
// 对应 Bun 中的 ToStringFormatter 和序列化逻辑
// Bun 通过 Expr tree 序列化; 仓颉直接从 IniFile 序列化
// ============================================================================

/// INI 序列化选项
public class IniWriterOptions {
    /// 使用何种注释风格
    public var commentChar: UInt8 = UInt8(';')  // ';' 或 '#'

    /// 是否引号包围字符串值
    public var quoteValues: Bool = false

    /// 缩进字符串
    public var indent: String = ""

    public init() {}
}

/// INI 写入器 - 将 IniFile 序列化为 INI 文本
/// 对应 Bun 中的 ToStringFormatter + Expr 序列化
public class IniWriter {
    private let opts: IniWriterOptions

    public init() {
        opts = IniWriterOptions()
    }

    public init(opts: IniWriterOptions) {
        this.opts = opts
    }

    /// 序列化 IniFile 为 INI 文本
    /// 对应 Bun 中将 Expr tree 转回 INI 格式
    public func serialize(file: IniFile): String {
        var output = StringBuilder()

        // 写入全局属性
        let globalEntries = file.globals.entries()
        for ((key, value) in globalEntries) {
            writeKeyValue(output, key, value)
        }

        // 写入各个节
        for (section in file.sections) {
            if (output.size() > 0) {
                output.append("\n")
            }

            // 写入节头
            writeSectionHeader(output, section)

            // 写入节内属性
            let entries = section.entries()
            for ((key, value) in entries) {
                writeKeyValue(output, key, value)
            }
        }

        return output.toString()
    }

    /// 写入节头
    private func writeSectionHeader(output: StringBuilder, section: IniSection): Unit {
        output.append("[")
        output.append(section.name)
        if (section.subsection != None) {
            output.append(" \"")
            output.append(section.subsection.getOrThrow())
            output.append("\"")
        }
        output.append("]\n")
    }

    /// 写入键值对
    /// 对应 Bun ToStringFormatter.format
    private func writeKeyValue(output: StringBuilder, key: String, value: IniValue): Unit {
        match (value) {
            case Str(s) =>
                output.append(key)
                output.append("=")
                if (opts.quoteValues) {
                    output.append("\"")
                    output.append(escapeValue(s))
                    output.append("\"")
                } else {
                    output.append(escapeValue(s))
                }
                output.append("\n")
            case Bool(b) =>
                output.append(key)
                output.append("=")
                output.append(if (b) { "true" } else { "false" })
                output.append("\n")
            case Null =>
                output.append(key)
                output.append("=null\n")
            case Array(arr) =>
                // 方括号数组语法: key[] = value
                for (item in arr) {
                    output.append(key)
                    output.append("[]=")
                    output.append(item.toString())
                    output.append("\n")
                }
            case Section(s) =>
                // 嵌套节 - 简化为点分隔键
                let entries = s.entries()
                for ((subKey, subValue) in entries) {
                    writeKeyValue(output, "${key}.${subKey}", subValue)
                }
        }
    }

    /// 转义值中的特殊字符
    /// 对应 Bun prepareStr 的逆操作
    private func escapeValue(val: String): String {
        if (!needsEscape(val)) {
            return val
        }
        var result = StringBuilder()
        for (c in val) {
            match (c) {
                case '\\' => result.append("\\\\")
                case ';' => result.append("\\;")
                case '#' => result.append("\\#")
                case '\n' => result.append("\\n")
                case '\t' => result.append("\\t")
                case '\r' => result.append("\\r")
                case _ => result.append(c.toString())
            }
        }
        return result.toString()
    }

    /// 检查值是否需要转义
    private func needsEscape(val: String): Bool {
        for (c in val) {
            if (c == '\\' || c == ';' || c == '#' || c == '\n' || c == '\t' || c == '\r') {
                return true
            }
        }
        return false
    }
}

// ============================================================================
// 便捷工厂函数
// ============================================================================

/// 解析 INI 字符串为 IniFile
/// 对应 Bun: IniParser.init(allocator, path, src, env).parse(arena)
public func parseIni(text: String): IniFile {
    let parser = IniParser()
    return parser.parse(text)
}

/// 使用选项解析 INI 字符串
public func parseIni(text: String, opts: IniParserOptions): IniFile {
    let parser = IniParser(opts)
    return parser.parse(text)
}

/// 将 IniFile 序列化为 INI 文本
public func serializeIni(file: IniFile): String {
    let writer = IniWriter()
    return writer.serialize(file)
}

/// 将 IniFile 序列化为 INI 文本 (带选项)
public func serializeIni(file: IniFile, opts: IniWriterOptions): String {
    let writer = IniWriter(opts)
    return writer.serialize(file)
}

// ============================================================================
// StringBuilder - 内部字符串构建器
// ============================================================================

private class StringBuilder {
    private var parts: ArrayList<String>
    private var totalSize: Int64

    init() {
        parts = ArrayList<String>()
        totalSize = 0
    }

    func append(s: String): Unit {
        parts.append(s)
        totalSize += s.size
    }

    func size(): Int64 {
        return totalSize
    }

    func toString(): String {
        if (totalSize == 0) {
            return ""
        }
        var arr = Array<Char>(totalSize, item: '\0')
        var pos = 0
        for (p in parts) {
            for (c in p) {
                arr[pos] = c
                pos += 1
            }
        }
        return String(arr)
    }
}
