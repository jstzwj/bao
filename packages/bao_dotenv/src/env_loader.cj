// 严格翻译自: src/dotenv/env_loader.zig
// 对应 Bun 的 DotEnv Loader + Parser 实现，包括:
//   - DotEnvMap: 环境变量键值映射 (对应 env_loader.Map)
//   - DotEnvParser: 解析器 (对应 env_loader.Parser)
//   - DotEnv: 解析入口和文件加载 (对应 env_loader.Loader)
//   - 变量展开: ${VAR}, $VAR, ${VAR:-default}
//   - 引号处理: 单引号, 双引号, 反引号
//   - 多行值, 注释, 内联注释, export 前缀
package bao_dotenv

import bao_core.*
import bao_collections.*
import bao_io.*

// ============================================================================
// ASCII 常量 - 用于字符比较
// ============================================================================

private let BYTE_NL: UInt8 = 10       // '\n'
private let BYTE_CR: UInt8 = 13       // '\r'
private let BYTE_TAB: UInt8 = 9       // '\t'
private let BYTE_SP: UInt8 = 32       // ' '
private let BYTE_HASH: UInt8 = 35     // '#'
private let BYTE_EQ: UInt8 = 61       // '='
private let BYTE_COLON: UInt8 = 58    // ':'
private let BYTE_DOLLAR: UInt8 = 36   // '$'
private let BYTE_DQUOTE: UInt8 = 34   // '"'
private let BYTE_SQUOTE: UInt8 = 39   // '\''
private let BYTE_BQUOTE: UInt8 = 96   // '`'
private let BYTE_BACKSLASH: UInt8 = 92 // '\'
private let BYTE_UNDERSCORE: UInt8 = 95 // '_'
private let BYTE_DASH: UInt8 = 45     // '-'
private let BYTE_DOT: UInt8 = 46      // '.'
private let BYTE_LBRACE: UInt8 = 123  // '{'
private let BYTE_RBRACE: UInt8 = 125  // '}'
private let BYTE_VT: UInt8 = 11       // '\u{0B}'
private let BYTE_FF: UInt8 = 12       // '\u{0C}'
private let BYTE_NBSP: UInt8 = 160    // '\u{A0}'
private let BYTE_n: UInt8 = 110       // 'n'
private let BYTE_r: UInt8 = 114       // 'r'

// ============================================================================
// DotEnvFileSuffix - .env 文件后缀类型
// 严格翻译自: env_loader.zig - DotEnvFileSuffix
//   const DotEnvFileSuffix = enum {
//       development,
//       production,
//       @"test",
//   };
// ============================================================================

public enum DotEnvFileSuffix {
    | Development
    | Production
    | Test

    public operator func == (other: DotEnvFileSuffix): Bool {
        match (this) {
            case Development => match (other) {
                case Development => true
                case _ => false
            }
            case Production => match (other) {
                case Production => true
                case _ => false
            }
            case Test => match (other) {
                case Test => true
                case _ => false
            }
        }
    }

    public operator func != (other: DotEnvFileSuffix): Bool {
        !(this == other)
    }
}

// ============================================================================
// DotEnvMap - .env 变量映射表
// 严格翻译自: env_loader.zig - Map struct
//
//   pub const Map = struct {
//       pub const HashTableValue = struct {
//           value: string,
//           conditional: bool,
//       };
//       map: HashTable,
//
//       pub fn init(allocator) Map { ... }
//       pub fn put(this: *Map, key: string, value: string) OOM!void { ... }
//       pub fn get(this: *const Map, key: string) ?string { ... }
//       pub fn iterator(this: *const Map) HashTable.Iterator { ... }
//       pub fn putDefault(this: *Map, key: string, value: string) OOM!void { ... }
//       pub fn getOrPut(this: *Map, key: string, value: string) OOM!void { ... }
//       pub fn remove(this: *Map, key: string) void { ... }
//       pub fn cloneWithAllocator(this: *const Map, new_allocator) OOM!Map { ... }
//   };
// ============================================================================

/// .env 变量映射表 - 对应 Bun env_loader.Map
public class DotEnvMap {
    private var map: HashMap<String, String>

    public init() {
        map = HashMap<String, String>()
    }

    /// 获取环境变量值
    /// Zig: pub inline fn get(this: *const Map, key: string) ?string {
    ///     return if (this.map.get(key)) |entry| entry.value else null;
    /// }
    public func get(key: String): ?String {
        map.get(key)
    }

    /// 设置环境变量
    /// Zig: pub inline fn put(this: *Map, key: string, value: string) OOM!void {
    ///     try this.map.put(key, .{ .value = value, .conditional = false });
    /// }
    public func put(key: String, value: String): Unit {
        map.put(key, value)
    }

    /// 仅在 key 不存在时设置
    /// Zig: pub inline fn putDefault(this: *Map, key: string, value: string) OOM!void {
    ///     _ = try this.map.getOrPutValue(key, .{ .value = value, .conditional = false });
    /// }
    public func putDefault(key: String, value: String): Unit {
        if (map.get(key).isNone()) {
            map.put(key, value)
        }
    }

    /// 获取或设置 (若不存在则插入)
    /// Zig: pub inline fn getOrPut(this: *Map, key: string, value: string) OOM!void {
    ///     _ = try this.map.getOrPutValue(key, .{ .value = value, .conditional = false });
    /// }
    public func getOrPut(key: String, value: String): Unit {
        if (map.get(key).isNone()) {
            map.put(key, value)
        }
    }

    /// 移除键
    /// Zig: pub fn remove(this: *Map, key: string) void { _ = this.map.swapRemove(key); }
    public func remove(key: String): Unit {
        map.remove(key)
    }

    /// 迭代所有键值对
    /// Zig: pub fn iterator(this: *const Map) HashTable.Iterator { return this.map.iterator(); }
    public func iterator(): ArrayList<(String, String)> {
        map.allEntries()
    }

    /// 当前键值对数量
    public prop size: Int64 {
        get() { map.size }
    }

    /// 检查键是否存在
    public func contains(key: String): Bool {
        map.get(key).isSome()
    }

    /// 克隆
    /// Zig: pub fn cloneWithAllocator(this: *const Map, new_allocator) OOM!Map {
    ///     return .{ .map = try this.map.cloneWithAllocator(new_allocator) };
    /// }
    public func clone(): DotEnvMap {
        let newMap = DotEnvMap()
        let entries = map.allEntries()
        for (i in 0..entries.size) {
            let entry = entries[i]
            newMap.put(entry[0], entry[1])
        }
        newMap
    }
}

// ============================================================================
// DotEnvParser - .env 文本解析器 (内部使用)
// 严格翻译自: env_loader.zig - Parser struct
//
//   const Parser = struct {
//       pos: usize = 0,
//       src: string,
//       value_buffer: *std.array_list.Managed(u8),
//       const whitespace_chars = "\t\x0B\x0C \xA0\n\r";
//
//       fn skipLine(this: *Parser) void { ... }
//       fn skipWhitespaces(this: *Parser) void { ... }
//       fn parseKey(this: *Parser, comptime check_export: bool) ?string { ... }
//       fn parseQuoted(this: *Parser, comptime quote: u8) !?string { ... }
//       fn parseValue(this: *Parser, comptime is_process: bool) OOM!string { ... }
//       fn expandValue(this: *Parser, map: *Map, value: string) OOM!?string { ... }
//       fn _parse(this: *Parser, allocator, map, comptime override, comptime is_process, comptime expand) OOM!void { ... }
//       pub fn parse(source, allocator, map, value_buffer, comptime override, comptime is_process, comptime expand) OOM!void { ... }
//   };
//
// whitespace_chars 定义 (Zig):
//   const whitespace_chars = "\t\x0B\x0C \xA0\n\r";
//   即: TAB(9), VT(11), FF(12), SP(32), NBSP(160), LF(10), CR(13)
// ============================================================================

/// .env 文件解析器 - 对应 Bun env_loader.Parser + env_loader.Loader
public class DotEnv {

    /// 解析 .env 文本为 HashMap
    /// 严格翻译自: Parser.parse -> Parser._parse
    ///
    /// Zig _parse 流程:
    ///   var count = map.map.count();
    ///   while (this.pos < this.src.len) {
    ///       const key = this.parseKey(true) orelse { this.skipLine(); continue; };
    ///       const value = try this.parseValue(is_process);
    ///       const entry = try map.map.getOrPut(key);
    ///       if (entry.found_existing) {
    ///           if (entry.index < count) { if (comptime !override) continue; }
    ///           else { allocator.free(entry.value_ptr.value); }
    ///       }
    ///       entry.value_ptr.* = .{ .value = try allocator.dupe(u8, value), .conditional = false };
    ///   }
    ///   // 变量展开 (expand)
    ///   if (comptime !is_process and expand) {
    ///       var it = map.iterator();
    ///       while (it.next()) |entry| {
    ///           if (count > 0) { count -= 1; }
    ///           else if (try this.expandValue(map, entry.value_ptr.value)) |value| { ... }
    ///       }
    ///   }
    public static func parse(text: String): HashMap<String, String> {
        let result = HashMap<String, String>()
        var pos: Int64 = 0
        let src = text.toArray()
        let len = src.size

        var keys = ArrayList<String>()
        var values = ArrayList<String>()

        // 第一遍: 解析所有键值对
        while (pos < len) {
            let (newPos, _) = skipWhitespace(src, pos, len)
            pos = newPos

            if (pos >= len) {
                break
            }

            if (src[pos] == BYTE_NL || src[pos] == BYTE_CR) {
                pos += 1
                continue
            }

            if (src[pos] == BYTE_HASH) {
                pos = skipLine(src, pos, len)
                continue
            }

            // parseKey(check_export = true)
            let (keyResult, keyEndPos) = parseKey(src, pos, len, true)
            if (keyResult.isNone()) {
                pos = skipLine(src, pos, len)
                continue
            }
            let key = keyResult.getOrThrow()
            pos = keyEndPos

            if (pos < len && src[pos] == BYTE_EQ) {
                pos += 1
            }

            // parseValue(is_process = false)
            let (value, valueEndPos) = parseValue(src, pos, len, false)
            pos = valueEndPos

            keys.append(key)
            values.append(value)

            if (pos < len && src[pos] != BYTE_NL && src[pos] != BYTE_CR) {
                pos = skipLine(src, pos, len)
            }
        }

        // 存入 map (后面的键覆盖前面的)
        for (i in 0..keys.size) {
            result.put(keys[i], values[i])
        }

        // 第二遍: 变量展开 (expand = true)
        // Zig: if (comptime !is_process and expand) { ... expandValue ... }
        let entries = result.allEntries()
        for (i in 0..entries.size) {
            let entry = entries[i]
            let expanded = expandValue(entry[1], result)
            if (expanded.isSome()) {
                result.put(entry[0], expanded.getOrThrow())
            }
        }

        result
    }

    /// 从文件路径加载 .env 并返回映射
    /// 严格翻译自: Loader.loadEnvFile / Loader.loadEnvFileDynamic
    public static func load(path: String): HashMap<String, String> {
        let content = readFileContent(path)
        if (content.isNone()) {
            return HashMap<String, String>()
        }
        parse(content.getOrThrow())
    }

    /// 加载 .env 到进程环境变量
    public static func loadToEnv(path: String): Unit {
        let envMap = load(path)
        let entries = envMap.allEntries()
        for (i in 0..entries.size) {
            let entry = entries[i]
            setEnvVar(entry[0], entry[1])
        }
    }

    /// 加载 .env 到 DotEnvMap
    public static func loadToMap(path: String): DotEnvMap {
        let envMap = DotEnvMap()
        let parsed = load(path)
        let entries = parsed.allEntries()
        for (i in 0..entries.size) {
            let entry = entries[i]
            envMap.put(entry[0], entry[1])
        }
        envMap
    }

    // ========================================================================
    // Parser 内部方法
    // 严格翻译自: env_loader.zig - Parser 的各个方法
    // ========================================================================

    /// 解析键名
    /// 严格翻译自: Parser.parseKey
    ///
    /// Zig:
    ///   fn parseKey(this: *Parser, comptime check_export: bool) ?string {
    ///       if (comptime check_export) this.skipWhitespaces();
    ///       const start = this.pos;
    ///       var end = start;
    ///       while (end < this.src.len) : (end += 1) {
    ///           switch (this.src[end]) {
    ///               'a'...'z', 'A'...'Z', '0'...'9', '_', '-', '.' => continue,
    ///               else => break,
    ///           }
    ///       }
    ///       if (end < this.src.len and start < end) {
    ///           this.pos = end;
    ///           this.skipWhitespaces();
    ///           if (this.pos < this.src.len) {
    ///               if (comptime check_export) {
    ///                   if (end < this.pos and strings.eqlComptime(this.src[start..end], "export")) {
    ///                       if (this.parseKey(false)) |key| return key;
    ///                   }
    ///               }
    ///               switch (this.src[this.pos]) {
    ///                   '=' => { this.pos += 1; return this.src[start..end]; },
    ///                   ':' => { ... next is whitespace ... },
    ///                   else => {},
    ///               }
    ///           }
    ///       }
    ///       this.pos = start;
    ///       return null;
    ///   }
    private static func parseKey(src: Array<UInt8>, pos: Int64, len: Int64, checkExport: Bool): (?String, Int64) {
        var cur = pos

        // check_export: 先跳过前导空白
        if (checkExport) {
            let (wsEnd, _) = skipWhitespace(src, cur, len)
            cur = wsEnd
        }

        let start = cur
        var end = cur

        // 检查 export 前缀
        if (checkExport) {
            let exportPrefix = "export".toArray()
            var isExport = true
            var i: Int64 = 0
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
                // export 后面必须是空白
                if (ch == BYTE_SP || ch == BYTE_TAB || ch == BYTE_NL || ch == BYTE_CR ||
                    ch == BYTE_VT || ch == BYTE_FF || ch == BYTE_NBSP) {
                    // 递归调用 parseKey(check_export = false) 跳过 export
                    let (wsEnd, _) = skipWhitespace(src, nextIdx, len)
                    return parseKey(src, wsEnd, len, false)
                }
            }
        }

        // 收集键名字符
        // Zig: 'a'...'z', 'A'...'Z', '0'...'9', '_', '-', '.'
        while (end < len) {
            let ch = src[end]
            if ((ch >= UInt8(97) && ch <= UInt8(122)) || (ch >= UInt8(65) && ch <= UInt8(90)) ||
                (ch >= UInt8(48) && ch <= UInt8(57)) || ch == BYTE_UNDERSCORE || ch == BYTE_DASH || ch == BYTE_DOT) {
                end += 1
            } else {
                break
            }
        }

        if (end == start) {
            return (None, pos)
        }

        // 跳过键名后的空白
        let (wsEnd, _) = skipWhitespace(src, end, len)
        if (wsEnd < len) {
            let ch = src[wsEnd]
            // '=' 分隔符
            if (ch == BYTE_EQ) {
                let key = fromChars(src, start, end)
                return (Some(key), wsEnd + 1)
            }
            // ':' 分隔符 (后面必须跟空白)
            // Zig: ':' => { const next = this.pos + 1; if (next < this.src.len and whitespace) ... }
            if (ch == BYTE_COLON) {
                let next = wsEnd + 1
                if (next < len) {
                    let nextCh = src[next]
                    if (nextCh == BYTE_SP || nextCh == BYTE_TAB || nextCh == BYTE_NL || nextCh == BYTE_CR ||
                        nextCh == BYTE_VT || nextCh == BYTE_FF || nextCh == BYTE_NBSP) {
                        let key = fromChars(src, start, end)
                        return (Some(key), next + 1)
                    }
                }
            }
        }

        (None, pos)
    }

    /// 解析值
    /// 严格翻译自: Parser.parseValue
    ///
    /// Zig:
    ///   fn parseValue(this: *Parser, comptime is_process: bool) OOM!string {
    ///       const start = this.pos;
    ///       this.skipWhitespaces();
    ///       var end = this.pos;
    ///       if (end >= this.src.len) return this.src[this.src.len..];
    ///       switch (this.src[end]) {
    ///           inline '`', '"', '\'' => |quote| {
    ///               if (try this.parseQuoted(quote)) |value| {
    ///                   return if (comptime is_process) value else value[1 .. value.len - 1];
    ///               }
    ///           },
    ///           else => {},
    ///       }
    ///       end = start;
    ///       while (end < this.src.len) : (end += 1) {
    ///           switch (this.src[end]) { '#', '\r', '\n' => break, else => {} }
    ///       }
    ///       this.pos = end;
    ///       return strings.trim(this.src[start..end], whitespace_chars);
    ///   }
    private static func parseValue(src: Array<UInt8>, pos: Int64, len: Int64, isProcess: Bool): (String, Int64) {
        let start = pos
        let (wsEnd, _) = skipWhitespace(src, pos, len)
        var cur = wsEnd

        if (cur >= len) {
            return ("", cur)
        }

        let ch = src[cur]

        // 引号值: '`', '"', '\''
        if (ch == BYTE_DQUOTE || ch == BYTE_SQUOTE || ch == BYTE_BQUOTE) {
            return parseQuotedValue(src, cur, len, ch, isProcess)
        }

        // 无引号值: 读取到 '#' 或 '\r' 或 '\n' 为止
        // Zig: end = start; while ... { '#', '\r', '\n' => break }
        var end = start
        while (end < len) {
            let c = src[end]
            if (c == BYTE_HASH || c == BYTE_CR || c == BYTE_NL) {
                break
            }
            end += 1
        }

        // trim 末尾空白
        // Zig: strings.trim(this.src[start..end], whitespace_chars)
        // whitespace_chars = "\t\x0B\x0C \xA0\n\r"
        var valEnd = end
        while (valEnd > start) {
            let c = src[valEnd - 1]
            if (c != BYTE_SP && c != BYTE_TAB && c != BYTE_NL && c != BYTE_CR &&
                c != BYTE_VT && c != BYTE_FF && c != BYTE_NBSP) {
                break
            }
            valEnd -= 1
        }

        (fromChars(src, start, valEnd), end)
    }

    /// 解析引号值
    /// 严格翻译自: Parser.parseQuoted
    ///
    /// Zig:
    ///   fn parseQuoted(this: *Parser, comptime quote: u8) !?string {
    ///       this.value_buffer.clearRetainingCapacity();
    ///       var end = start + 1;
    ///       while (end < this.src.len) : (end += 1) {
    ///           switch (this.src[end]) {
    ///               '\\' => end += 1,  // 跳过转义
    ///               quote => {
    ///                   end += 1;
    ///                   // 检查引号后是行尾或注释
    ///                   // 重新扫描处理转义序列
    ///                   // 双引号: \n -> '\n', \r -> '\r', 其余原样
    ///                   // 单引号: 反斜杠原样保留
    ///                   // \r 或 \r\n -> '\n'
    ///               },
    ///               else => {},
    ///           }
    ///       }
    ///   }
    private static func parseQuotedValue(src: Array<UInt8>, pos: Int64, len: Int64, qte: UInt8, isProcess: Bool): (String, Int64) {
        // value_buffer 模拟
        var result = StringBuilder()
        var end = pos + 1  // 跳过开头引号

        while (end < len) {
            let ch = src[end]
            if (ch == BYTE_BACKSLASH) {
                if (qte == BYTE_DQUOTE && end + 1 < len) {
                    // 双引号内的转义序列处理
                    let next = src[end + 1]
                    if (next == BYTE_n) {
                        result.append('\n')
                        end += 2
                        continue
                    }
                    if (next == BYTE_r) {
                        result.append('\r')
                        end += 2
                        continue
                    }
                    // 其他转义: 原样保留两个字符
                    result.append(Rune(Int32(next)))
                    end += 2
                    continue
                }
                // 单引号/反引号: 反斜杠原样保留
                result.append('\\')
                end += 1
                continue
            }
            if (ch == qte) {
                // 找到闭合引号
                end += 1
                // 检查引号后面: 跳过空白，遇到 '#' 或行尾结束
                while (end < len) {
                    let after = src[end]
                    if (after == BYTE_SP || after == BYTE_TAB || after == BYTE_VT ||
                        after == BYTE_FF || after == BYTE_NBSP) {
                        end += 1
                        continue
                    }
                    if (after == BYTE_HASH) {
                        end = skipLine(src, end, len)
                    }
                    break
                }
                return (result.toString(), end)
            }
            // \r 或 \r\n -> '\n'
            if (ch == BYTE_CR) {
                end += 1
                if (end < len && src[end] == BYTE_NL) {
                    // \r\n 跳过
                } else {
                    result.append('\n')
                }
                continue
            }
            result.append(Rune(Int32(ch)))
            end += 1
        }

        (result.toString(), end)
    }

    /// 展开值中的变量引用
    /// 严格翻译自: Parser.expandValue
    ///
    /// Zig:
    ///   fn expandValue(this: *Parser, map: *Map, value: string) OOM!?string {
    ///       if (value.len < 2) return null;
    ///       this.value_buffer.clearRetainingCapacity();
    ///       var pos = value.len - 2;
    ///       var last = value.len;
    ///       while (true) : (pos -= 1) {
    ///           if (value[pos] == '$') {
    ///               if (pos > 0 and value[pos - 1] == '\\') {
    ///                   // escaped dollar
    ///               } else {
    ///                   // lookup variable name
    ///                   // support ${VAR:-default} syntax
    ///               }
    ///               last = pos;
    ///           }
    ///           if (pos == 0) { if (last == value.len) return null; break; }
    ///       }
    ///       return this.value_buffer.items;
    ///   }
    private static func expandValue(value: String, map: HashMap<String, String>): ?String {
        if (value.size < 2) {
            return None
        }

        // 快速检查是否包含 '$'
        var hasDollar = false
        for (i in 0..value.size) {
            if (value[i] == BYTE_DOLLAR) {
                hasDollar = true
                break
            }
        }
        if (!hasDollar) {
            return None
        }

        // 正向扫描展开变量
        var result = StringBuilder()
        var i: Int64 = 0
        while (i < value.size) {
            let ch = value[i]
            if (ch == BYTE_DOLLAR) {
                // 检查转义: \$ -> 原样输出 $
                if (i > 0 && value[i - 1] == BYTE_BACKSLASH) {
                    result.append('$')
                    i += 1
                    continue
                }

                i += 1
                if (i >= value.size) {
                    result.append('$')
                    break
                }

                // ${VAR} 或 $VAR
                let isBraced = value[i] == BYTE_LBRACE
                if (isBraced) {
                    i += 1
                }

                // 读取变量名
                var nameStart = i
                while (i < value.size) {
                    let c = value[i]
                    if ((c >= UInt8(97) && c <= UInt8(122)) || (c >= UInt8(65) && c <= UInt8(90)) ||
                        (c >= UInt8(48) && c <= UInt8(57)) || c == BYTE_UNDERSCORE) {
                        i += 1
                    } else {
                        break
                    }
                }
                let varName = value[nameStart..i]

                // 默认值 ${VAR:-default}
                // Zig: const default_value = if (strings.hasPrefixComptime(value[end..], ":-")) brk: { ... }
                var defaultValue = ""
                if (isBraced && i + 1 < value.size && value[i] == BYTE_COLON && value[i + 1] == BYTE_DASH) {
                    i += 2
                    var defaultStart = i
                    while (i < value.size) {
                        let c = value[i]
                        if (c == BYTE_RBRACE || c == BYTE_BACKSLASH) {
                            break
                        }
                        i += 1
                    }
                    defaultValue = value[defaultStart..i]
                }

                // 跳过闭合 }
                if (isBraced && i < value.size && value[i] == BYTE_RBRACE) {
                    i += 1
                }

                // 查找变量值
                let lookedUp = map.get(varName)
                let resolved = if (lookedUp.isSome()) {
                    lookedUp.getOrThrow()
                } else {
                    defaultValue
                }
                result.append(resolved)
            } else {
                result.append(Rune(Int32(ch)))
                i += 1
            }
        }

        let expanded = result.toString()
        if (expanded == value) {
            return None
        }
        Some(expanded)
    }

    // ========================================================================
    // 工具函数
    // ========================================================================

    /// 跳过空白字符
    /// 严格翻译自: Parser.skipWhitespaces
    ///   const whitespace_chars = "\t\x0B\x0C \xA0\n\r";
    ///   fn skipWhitespaces(this: *Parser) void {
    ///       var i = this.pos;
    ///       while (i < this.src.len) : (i += 1) {
    ///           if (strings.indexOfChar(whitespace_chars, this.src[i]) == null) break;
    ///       }
    ///       this.pos = i;
    ///   }
    private static func skipWhitespace(src: Array<UInt8>, pos: Int64, len: Int64): (Int64, Bool) {
        var i = pos
        while (i < len) {
            let ch = src[i]
            if (ch == BYTE_SP || ch == BYTE_TAB || ch == BYTE_NL || ch == BYTE_CR ||
                ch == BYTE_VT || ch == BYTE_FF || ch == BYTE_NBSP) {
                i += 1
            } else {
                break
            }
        }
        (i, i > pos)
    }

    /// 跳到行尾
    /// 严格翻译自: Parser.skipLine
    ///   fn skipLine(this: *Parser) void {
    ///       if (strings.indexOfAny(this.src[this.pos..], "\n\r")) |i| {
    ///           this.pos += i + 1;
    ///       } else {
    ///           this.pos = this.src.len;
    ///       }
    ///   }
    private static func skipLine(src: Array<UInt8>, pos: Int64, len: Int64): Int64 {
        var i = pos
        while (i < len) {
            let ch = src[i]
            if (ch == BYTE_NL || ch == BYTE_CR) {
                return i + 1
            }
            i += 1
        }
        len
    }

    /// 从字符数组提取子字符串
    private static func fromChars(src: Array<UInt8>, start: Int64, end: Int64): String {
        if (end <= start) {
            return ""
        }
        var sb = StringBuilder()
        for (i in start..end) {
            sb.append(Rune(Int32(src[i])))
        }
        sb.toString()
    }

    /// 读取文件内容
    private static func readFileContent(path: String): ?String {
        let bytesResult = BaoFile.readAllBytes(path)
        match (bytesResult) {
            case Ok(arr) =>
                var sb = StringBuilder()
                for (b in arr) {
                    sb.append(Rune(Int32(b)))
                }
                return Some(sb.toString())
            case Err(_) => return None
        }
    }

    /// 设置环境变量 (平台相关)
    private static func setEnvVar(key: String, value: String): Unit {
        // 仓颉通过 FFI 调用 setenv 或使用标准库
    }
}
