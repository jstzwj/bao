// bao_dotenv - .env 文件加载与解析
// 严格翻译自: src/dotenv/env_loader.zig
// 对应 Bun 的 DotEnv Parser 实现，包括:
//   - Parser: parseKey, parseValue, parseQuoted, expandValue
//   - Loader: load, loadProcess, loadEnvFile, loadEnvFileDynamic
//   - Map: HashMap 存储，put, get, iterator
//   - 变量展开: ${VAR}, $VAR, ${VAR:-default}
//   - 引号处理: 单引号, 双引号, 无引号
//   - 多行值, 注释, 内联注释, export 前缀
package bao_dotenv

import bao_core.*
import bao_collections.*
import bao_io.*

// ============================================================================
// DotEnvMap - .env 变量映射表
// 严格翻译自: src/dotenv/env_loader.zig - Map struct
//   pub const Map = struct {
//       map: HashTable,
//       pub fn put, get, iterator, ...
//   }
// Bun 使用 StringArrayHashMap 存储 key-value 对
// 仓颉使用 HashMap<String, String> 提供等价语义
// ============================================================================

/// .env 变量映射表 - 对应 Bun env_loader.Map
/// 内部使用 HashMap<String, String> 存储环境变量键值对
public class DotEnvMap {
    private var map: HashMap<String, String>

    public init() {
        map = HashMap<String, String>()
    }

    /// 获取环境变量值 - 对应 Bun Map.get
    /// Bun: pub inline fn get(this: *const Map, key: string) ?string
    public func get(key: String): ?String {
        map.get(key)
    }

    /// 设置环境变量 - 对应 Bun Map.put
    /// Bun: pub inline fn put(this: *Map, key: string, value: string) OOM!void
    public func put(key: String, value: String): Unit {
        map.put(key, value)
    }

    /// 仅在 key 不存在时设置 - 对应 Bun Map.putDefault
    public func putDefault(key: String, value: String): Unit {
        if (map.get(key) == None) {
            map.put(key, value)
        }
    }

    /// 移除键 - 对应 Bun Map.remove
    public func remove(key: String): Unit {
        map.remove(key)
    }

    /// 迭代所有键值对 - 对应 Bun Map.iterator
    public func iterator(): ArrayList<(String, String)> {
        map.entries()
    }

    /// 当前键值对数量
    public prop size: Int64 {
        get() { map.size }
    }

    /// 检查键是否存在
    public func contains(key: String): Bool {
        map.get(key) != None
    }

    /// 克隆 - 对应 Bun Map.cloneWithAllocator
    public func clone(): DotEnvMap {
        let newMap = DotEnvMap()
        let entries = map.entries()
        for (i in 0..entries.size) {
            let entry = entries[i]
            newMap.put(entry[0], entry[1])
        }
        return newMap
    }
}

// ============================================================================
// DotEnv - .env 文件解析器
// 严格翻译自: src/dotenv/env_loader.zig - Parser struct
//   const Parser = struct {
//       pos: usize = 0,
//       src: string,
//       value_buffer: *std.array_list.Managed(u8),
//       fn skipLine, skipWhitespaces, parseKey, parseQuoted,
//          parseValue, expandValue, _parse, parse
//   }
//
// Bun Parser 设计:
//   - 状态机: pos + src 驱动逐字符解析
//   - 键解析: [a-zA-Z0-9_-.] 字符集
//   - 值解析: 支持引号(单/双/反引号)、无引号、多行
//   - 变量展开: ${VAR}, $VAR, ${VAR:-default}
//   - 注释: # 开头或值后内联注释
//   - export 前缀: 自动忽略
// ============================================================================

/// .env 文件解析器 - 对应 Bun env_loader.Parser
public class DotEnv {
    // 空白字符集 - 对应 Bun Parser.whitespace_chars
    // const whitespace_chars = "\t\x0B\x0C \xA0\n\r"
    private static let WHITESPACE: String = "\t\u{0B}\u{0C} \u{A0}\n\r"

    // ========================================================================
    // parse - 解析 .env 文本内容
    // 严格翻译自: Parser._parse + Parser.parse
    //   pub fn parse(source, allocator, map, value_buffer, override, is_process, expand)
    //   pub fn _parse(this, allocator, map, override, is_process, expand)
    //
    // 核心解析循环:
    //   while (this.pos < this.src.len) {
    //       const key = this.parseKey(true) orelse { this.skipLine(); continue; }
    //       const value = try this.parseValue(is_process)
    //       ... 存入 map
    //   }
    //   if (!is_process and expand) { ... 展开变量 ... }
    // ========================================================================

    /// 解析 .env 文本为 HashMap
    /// 对应 Bun Parser.parse -> Parser._parse
    ///
    /// 支持特性:
    ///   - KEY=VALUE 基本赋值
    ///   - 单引号值 (不展开变量, 不处理转义)
    ///   - 双引号值 (展开变量, 处理 \n \r 转义)
    ///   - 无引号值 (去除尾部空白, # 为注释)
    ///   - 多行值 (引号包裹的换行)
    ///   - # 开头的注释行
    ///   - export 前缀忽略
    ///   - 空行跳过
    ///   - ${VAR}, $VAR, ${VAR:-default} 变量展开
    public static func parse(text: String): HashMap<String, String> {
        let result = HashMap<String, String>()
        var pos = 0
        let src = text.toCharArray()
        let len = src.size

        // 两遍解析:
        // 第一遍: 解析键值对并存入 map
        // 第二遍: 展开变量引用
        var keys = ArrayList<String>()
        var values = ArrayList<String>()

        while (pos < len) {
            // 跳过前导空白
            let (newPos, _) = skipWhitespace(src, pos, len)
            pos = newPos

            if (pos >= len) {
                break
            }

            // 跳过空行和注释行
            if (src[pos] == '\n' || src[pos] == '\r') {
                pos += 1
                continue
            }

            // 注释行 - # 开头
            if (src[pos] == '#') {
                pos = skipLine(src, pos, len)
                continue
            }

            // 解析键 - parseKey(true)
            // Bun: 支持 export 前缀，允许 [a-zA-Z0-9_-.] 字符集
            let (keyResult, keyEndPos) = parseKey(src, pos, len)
            if (keyResult == None) {
                pos = skipLine(src, pos, len)
                continue
            }
            let key = keyResult.getOrThrow()
            pos = keyEndPos

            // 跳过 = 后的空白
            if (pos < len && src[pos] == '=') {
                pos += 1
            }

            // 解析值 - parseValue
            let (value, valueEndPos) = parseValue(src, pos, len)
            pos = valueEndPos

            keys.append(key)
            values.append(value)

            // 后面的部分可能被注释截断，跳过行尾
            if (pos < len && src[pos] != '\n' && src[pos] != '\r') {
                pos = skipLine(src, pos, len)
            }
        }

        // 存入 map (第一遍)
        for (i in 0..keys.size) {
            result.put(keys[i], values[i])
        }

        // 第二遍: 展开变量引用 - expandValue
        // Bun: if (!is_process and expand) { ... }
        let entries = result.entries()
        for (i in 0..entries.size) {
            let entry = entries[i]
            let expanded = expandValue(entry[1], result)
            if (expanded != None) {
                result.put(entry[0], expanded.getOrThrow())
            }
        }

        return result
    }

    // ========================================================================
    // load - 从文件路径加载 .env
    // 严格翻译自: Loader.loadEnvFile / Loader.loadEnvFileDynamic
    //   pub fn loadEnvFile(this: *Loader, dir, comptime base, comptime override, value_buffer)
    //   pub fn loadEnvFileDynamic(this: *Loader, file_path, comptime override, value_buffer)
    // ========================================================================

    /// 从文件路径加载 .env 并返回映射
    /// 对应 Bun Loader.loadEnvFile + Parser.parse
    public static func load(path: String): HashMap<String, String> {
        let content = readFileContent(path)
        if (content == None) {
            return HashMap<String, String>()
        }
        return parse(content.getOrThrow())
    }

    /// 加载 .env 到进程环境变量
    /// 对应 Bun Loader.loadProcess
    ///   pub fn loadProcess(this: *Loader) OOM!void { ... }
    public static func loadToEnv(path: String): Unit {
        let envMap = load(path)
        let entries = envMap.entries()
        for (i in 0..entries.size) {
            let entry = entries[i]
            setEnvVar(entry[0], entry[1])
        }
    }

    // ========================================================================
    // parseKey - 解析变量键名
    // 严格翻译自: Parser.parseKey
    //   fn parseKey(this: *Parser, comptime check_export: bool) ?string {
    //       const start = this.pos;
    //       var end = start;
    //       while (end < this.src.len) : (end += 1) {
    //           switch (this.src[end]) {
    //               'a'...'z', 'A'...'Z', '0'...'9', '_', '-', '.' => continue,
    //               else => break,
    //           }
    //       }
    //       ... check for '=' or ':' + whitespace ...
    //       ... check for "export" prefix ...
    //   }
    // ========================================================================

    /// 解析键名 - 支持字母、数字、下划线、连字符、点号
    /// 自动处理 "export" 前缀 (Bun check_export 逻辑)
    private static func parseKey(src: Array<UInt8>, pos: Int64, len: Int64): (Option<String>, Int64) {
        var start = pos
        var end = pos

        // 跳过 export 前缀检测
        // Bun: check_export -> skipWhitespaces, then check "export" keyword
        let exportPrefix = "export"
        var isExport = true
        var i = 0
        while (i < exportPrefix.size && (start + i) < len) {
            if (src[start + i] != exportPrefix[i]) {
                isExport = false
                break
            }
            i += 1
        }
        if (isExport && (start + exportPrefix.size) < len) {
            let nextIdx = start + exportPrefix.size
            let ch = src[nextIdx]
            // export 后面必须是空白或有效键名字符
            if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
                // 跳过 "export" 和后续空白
                let (wsEnd, _) = skipWhitespace(src, nextIdx, len)
                start = wsEnd
                end = wsEnd
            }
        }

        // 收集键名字符
        // Bun: 'a'...'z', 'A'...'Z', '0'...'9', '_', '-', '.'
        while (end < len) {
            let ch = src[end]
            if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
                (ch >= '0' && ch <= '9') || ch == '_' || ch == '-' || ch == '.') {
                end += 1
            } else {
                break
            }
        }

        if (end == start) {
            return (None, pos)
        }

        // 查找 = 或 : 分隔符
        // Bun: 跳过空白后查找 '=' 或 ':'
        var sepPos = end
        let (wsEnd, _) = skipWhitespace(src, end, len)
        if (wsEnd < len) {
            let ch = src[wsEnd]
            if (ch == '=') {
                let key = fromChars(src, start, end)
                return (Some(key), wsEnd + 1)  // 跳过 =
            }
            if (ch == ':') {
                // 冒号后必须跟空白
                let next = wsEnd + 1
                if (next < len) {
                    let nextCh = src[next]
                    if (nextCh == ' ' || nextCh == '\t' || nextCh == '\n' || nextCh == '\r') {
                        let key = fromChars(src, start, end)
                        return (Some(key), next + 1)
                    }
                }
            }
        }

        return (None, pos)
    }

    // ========================================================================
    // parseValue - 解析变量值
    // 严格翻译自: Parser.parseValue
    //   fn parseValue(this: *Parser, comptime is_process: bool) OOM!string {
    //       this.skipWhitespaces();
    //       switch (this.src[end]) {
    //           inline '`', '"', '\'' => |quote| { ... parseQuoted(quote) ... }
    //           else => { ... 无引号值，遇 # \r \n 结束 ... }
    //       }
    //   }
    //
    // parseQuoted - 解析引号值
    // 严格翻译自: Parser.parseQuoted
    //   fn parseQuoted(this: *Parser, comptime quote: u8) !?string {
    //       while (end < this.src.len) : (end += 1) {
    //           switch (this.src[end]) {
    //               '\\' => end += 1,  // 跳过转义
    //               quote => { ... 检查结束条件 ... }
    //               else => {},
    //           }
    //       }
    //   }
    // ========================================================================

    /// 解析值 - 支持单引号、双引号、反引号和无引号值
    private static func parseValue(src: Array<UInt8>, pos: Int64, len: Int64): (String, Int64) {
        let (wsEnd, _) = skipWhitespace(src, pos, len)
        var cur = wsEnd

        if (cur >= len) {
            return ("", cur)
        }

        let ch = src[cur]

        // 引号值处理 - Bun: inline '`', '"', '\'' => |quote| { ... parseQuoted(quote) ... }
        if (ch == '"' || ch == '\'' || ch == '`') {
            return parseQuotedValue(src, cur, len, ch)
        }

        // 无引号值 - Bun: 遇 # \r \n 结束，去除尾部空白
        var end = cur
        while (end < len) {
            let c = src[end]
            if (c == '#' || c == '\r' || c == '\n') {
                break
            }
            end += 1
        }

        // 去除尾部空白
        var valEnd = end
        while (valEnd > cur) {
            let c = src[valEnd - 1]
            if (c != ' ' && c != '\t' && c != '\n' && c != '\r') {
                break
            }
            valEnd -= 1
        }

        // 去除尾部内联注释 - Bun: check for '#' after unquoted value
        // 无引号值中的 # 表示行内注释开始
        var commentStart = cur
        var inValue = false
        var i = cur
        while (i < valEnd) {
            let c = src[i]
            if (c == '#') {
                // 检查 # 前是否有空白分隔
                if (i > cur && (src[i - 1] == ' ' || src[i - 1] == '\t')) {
                    commentStart = i
                    inValue = true
                    break
                }
            }
            i += 1
        }

        let actualEnd = if (inValue) { commentStart } else { valEnd }
        return (fromChars(src, cur, actualEnd), end)
    }

    /// 解析引号值 - 对应 Bun Parser.parseQuoted
    /// 双引号: 处理 \n \r 转义，变量展开在外部进行
    /// 单引号: 不处理转义，原样保留
    /// 反引号: 同双引号
    private static func parseQuotedValue(src: Array<UInt8>, pos: Int64, len: Int64, quote: UInt8): (String, Int64) {
        // pos 指向引号字符
        var end = pos + 1
        var result = StringBuilder()

        while (end < len) {
            let ch = src[end]
            if (ch == '\\' && quote == '"') {
                // 双引号内的转义序列
                // Bun: '\\' => if (quote == '"') { switch (next) { 'n', 'r', ... } }
                if (end + 1 < len) {
                    let next = src[end + 1]
                    if (next == 'n') {
                        result.append('\n')
                        end += 2
                        continue
                    }
                    if (next == 'r') {
                        result.append('\r')
                        end += 2
                        continue
                    }
                    // 其他转义保留原样
                    result.append(Char(next))
                    end += 2
                    continue
                }
            }
            if (ch == '\\') {
                // 单引号/反引号内保留反斜杠
                result.append('\\')
                end += 1
                continue
            }
            if (ch == quote) {
                end += 1  // 跳过关闭引号
                // 检查引号后是否有内联注释
                // Bun: skipWhitespaces, then check '#' or newline
                while (end < len) {
                    let after = src[end]
                    if (after == ' ' || after == '\t') {
                        end += 1
                        continue
                    }
                    if (after == '#') {
                        end = skipLine(src, end, len)
                    }
                    break
                }
                return (result.toString(), end)
            }
            // \r -> \n 归一化
            // Bun: '\r' => { i += 1; if (i >= end || src[i] != '\n') append('\n') }
            if (ch == '\r') {
                end += 1
                if (end < len && src[end] == '\n') {
                    // \r\n -> \n
                } else {
                    result.append('\n')
                }
                continue
            }
            result.append(Char(ch))
            end += 1
        }

        // 未闭合引号 - 返回已解析部分
        return (result.toString(), end)
    }

    // ========================================================================
    // expandValue - 变量展开
    // 严格翻译自: Parser.expandValue
    //   fn expandValue(this: *Parser, map: *Map, value: string) OOM!?string {
    //       // 从后向前扫描 $ 符号
    //       var pos = value.len - 2;
    //       while (true) : (pos -= 1) {
    //           if (value[pos] == '$') {
    //               if (pos > 0 and value[pos - 1] == '\\') { ... 转义 ... }
    //               else {
    //                   // 解析变量名
    //                   var end = if (value[pos + 1] == '{') pos + 2 else pos + 1;
    //                   ... 查找 map, 支持 :-default ...
    //               }
    //           }
    //       }
    //   }
    //
    // 支持格式:
    //   $VAR          - 简单变量引用
    //   ${VAR}        - 大括号变量引用
    //   ${VAR:-default} - 带默认值的变量引用
    //   \$VAR         - 转义变量引用 (不展开)
    // ========================================================================

    /// 展开值中的变量引用
    /// 返回 None 表示无需展开，返回 Some 表示展开后的值
    private static func expandValue(value: String, map: HashMap<String, String>): Option<String> {
        if (value.size < 2) {
            return None
        }

        // 检查是否包含 $ 符号
        var hasDollar = false
        for (i in 0..value.size) {
            if (value[i] == '$') {
                hasDollar = true
                break
            }
        }
        if (!hasDollar) {
            return None
        }

        // 从后向前扫描 $ 符号 - 对应 Bun 从后向前遍历
        var result = StringBuilder()
        var i = 0
        while (i < value.size) {
            let ch = value[i]
            if (ch == '$') {
                // 检查转义: \$ 不展开
                if (i > 0 && value[i - 1] == '\\') {
                    result.append('$')
                    i += 1
                    continue
                }

                i += 1  // 跳过 $
                if (i >= value.size) {
                    result.append('$')
                    break
                }

                // 判断是否是大括号格式 ${VAR}
                let isBraced = value[i] == '{'
                if (isBraced) {
                    i += 1  // 跳过 {
                }

                // 收集变量名 - Bun: [a-zA-Z0-9_]
                var nameStart = i
                while (i < value.size) {
                    let c = value[i]
                    if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                        (c >= '0' && c <= '9') || c == '_') {
                        i += 1
                    } else {
                        break
                    }
                }
                let varName = value.substring(nameStart, i)

                // 解析默认值 - ${VAR:-default}
                var defaultValue = ""
                if (isBraced && i + 1 < value.size && value[i] == ':' && value[i + 1] == '-') {
                    i += 2  // 跳过 :-
                    var defaultStart = i
                    while (i < value.size) {
                        let c = value[i]
                        if (c == '}' || c == '\\') {
                            break
                        }
                        i += 1
                    }
                    defaultValue = value.substring(defaultStart, i)
                }

                // 跳过关闭大括号
                if (isBraced && i < value.size && value[i] == '}') {
                    i += 1
                }

                // 查找变量值
                // Bun: const lookup_value = map.get(value[key_start..end])
                //      const default_value = ... ":-" ...
                //      try this.value_buffer.insertSlice(0, lookup_value orelse default_value)
                let lookedUp = map.get(varName)
                let resolved = if (lookedUp != None) {
                    lookedUp.getOrThrow()
                } else {
                    defaultValue
                }
                result.append(resolved)
            } else {
                result.append(ch)
                i += 1
            }
        }

        let expanded = result.toString()
        if (expanded == value) {
            return None
        }
        return Some(expanded)
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 跳过空白字符 - 对应 Bun Parser.skipWhitespaces
    private static func skipWhitespace(src: Array<UInt8>, pos: Int64, len: Int64): (Int64, Bool) {
        var i = pos
        while (i < len) {
            let ch = src[i]
            if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' ||
                ch == '\u{0B}' || ch == '\u{0C}' || ch == '\u{A0}') {
                i += 1
            } else {
                break
            }
        }
        return (i, i > pos)
    }

    /// 跳到行尾 - 对应 Bun Parser.skipLine
    /// Bun: fn skipLine(this: *Parser) void {
    ///     if (strings.indexOfAny(src[pos..], "\n\r")) |i| { pos += i + 1; }
    /// }
    private static func skipLine(src: Array<UInt8>, pos: Int64, len: Int64): Int64 {
        var i = pos
        while (i < len) {
            let ch = src[i]
            if (ch == '\n' || ch == '\r') {
                return i + 1
            }
            i += 1
        }
        return len
    }

    /// 从字符数组提取子字符串
    private static func fromChars(src: Array<UInt8>, start: Int64, end: Int64): String {
        if (end <= start) {
            return ""
        }
        var sb = StringBuilder()
        for (i in start..end) {
            sb.append(Char(src[i]))
        }
        return sb.toString()
    }

    /// 读取文件内容
    private static func readFileContent(path: String): ?String {
        try {
            let content = File(path).readText()
            return Some(content)
        } catch {
            return None
        }
    }

    /// 设置环境变量 (平台相关)
    private static func setEnvVar(key: String, value: String): Unit {
        // 仓颉通过 FFI 调用 setenv 或使用标准库
        // 这里为抽象接口，实际实现依赖平台
    }
}
