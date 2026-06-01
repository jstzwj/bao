// 严格翻译自: src/codegen/process_windows_translate_c.zig
//   Bun 的 process_windows_translate_c 工具是一个 Zig CLI 程序，
//   对 translate-c 生成的 Windows 绑定做后处理:
//     1. 替换特定符号 (NTSTATUS -> std.os.windows.NTSTATUS 等)
//     2. 将 __MINGW_NAME_AW(...) 宏展开替换为 @compileError("Use 'XxxW' instead.")
//     3. 保留其他行不变
//
//   背景说明 (Zig 源码注释):
//     "translate-c is unable to translate the unsuffixed windows functions like
//      SetCurrentDirectory since they are defined with an odd macro that translate-c
//      doesn't handle:
//        #define SetCurrentDirectory __MINGW_NAME_AW(SetCurrentDirectory)
//      In these cases, it's better to just reference the underlying function directly:
//      SetCurrentDirectoryW. To make the error better, a post processing step is applied."
//
//   仓颉翻译说明:
//   Zig 的 std.StaticStringMap -> 仓颉使用 HashMap 或 Array<Pair>
//   Zig 的 tokenizer 手动索引 -> 仓颉使用字符串操作
//   Zig 的文件 I/O -> 仓颉使用标准库文件 API
package bao_codegen

// ============================================================================
// SymbolReplacement - 符号替换映射
// 严格翻译自: src/codegen/process_windows_translate_c.zig
//   const symbol_replacements = std.StaticStringMap([]const u8).initComptime(&.{
//       &.{ "NTSTATUS", "@import(\"std\").os.windows.NTSTATUS" },
//       &.{ "HANDLE",   "@import(\"std\").os.windows.HANDLE" },
//       &.{ "PHANDLE",  "*HANDLE" },
//   });
// ============================================================================

/// 符号替换条目。
/// 对应 Zig 中 StaticStringMap 的键值对。
public struct SymbolReplacement {
    public let symbol: String
    public let replacement: String

    public init(symbol: String, replacement: String) {
        this.symbol = symbol
        this.replacement = replacement
    }
}

/// 默认符号替换表。
/// 对应 Zig: const symbol_replacements
///
/// Zig 原文:
///   &.{ "NTSTATUS", "@import(\"std\").os.windows.NTSTATUS" },
///   &.{ "HANDLE",   "@import(\"std\").os.windows.HANDLE" },
///   &.{ "PHANDLE",  "*HANDLE" },
public let SYMBOL_REPLACEMENTS: Array<SymbolReplacement> = [
    SymbolReplacement("NTSTATUS", "@import(\"std\").os.windows.NTSTATUS"),
    SymbolReplacement("HANDLE", "@import(\"std\").os.windows.HANDLE"),
    SymbolReplacement("PHANDLE", "*HANDLE"),
]

// ============================================================================
// TranslateCProcessor - Windows translate-c 后处理器
// 严格翻译自: src/codegen/process_windows_translate_c.zig pub fn main() !void { ... }
//
// Zig 的 main 函数流程:
//   1. 读取命令行参数: args[1] = 输入文件路径, args[2] = 输出文件路径
//   2. 读取输入文件全部内容
//   3. 逐段扫描 "pub const " 声明:
//      a. 找到 "pub const " 位置
//      b. 用 Zig tokenizer 提取符号名 (identifier token)
//      c. 如果该行不以 ';' 结尾 -> 跳过 (多行声明)
//      d. 如果符号在 symbol_replacements 中 -> 替换为映射值
//      e. 如果值以 " = __MINGW_NAME_AW(" 开头 -> 替换为 @compileError
//      f. 否则保留原行
//   4. 写入输出文件
// ============================================================================

/// Windows translate-c 后处理器。
/// 对应 Zig: process_windows_translate_c.zig 的完整 main 逻辑。
///
/// 处理步骤:
///   1. 扫描输入文本中所有 "pub const " 声明
///   2. 提取每个声明的符号名
///   3. 应用符号替换或 __MINGW_NAME_AW 检测
///   4. 输出处理后的文本
public class TranslateCProcessor {

    /// 在符号替换表中查找。
    /// 对应 Zig: symbol_replacements.get(symbol_name)
    ///
    /// Zig 使用编译时 StaticStringMap (完美哈希表)。
    /// 仓颉使用线性扫描 Array。
    public static func findReplacement(symbol: String): ?SymbolReplacement {
        for (entry in SYMBOL_REPLACEMENTS) {
            if (entry.symbol == symbol) {
                return entry
            }
        }
        return None
    }

    /// 判断字符是否为标识符字符 (a-z, A-Z, 0-9, _)。
    /// 对应 Zig tokenizer 的 .identifier tag 逻辑。
    public static func isIdentifierChar(ch: Char): Bool {
        if (ch >= 'a' && ch <= 'z') {
            return true
        }
        if (ch >= 'A' && ch <= 'Z') {
            return true
        }
        if (ch >= '0' && ch <= '9') {
            return true
        }
        if (ch == '_') {
            return true
        }
        return false
    }

    /// 从 "pub const " 之后的位置提取标识符符号名。
    /// 对应 Zig:
    ///   var tokenizer = std.zig.Tokenizer.init(in)
    ///   tokenizer.index = pub_i + "pub const ".len
    ///   const symbol_name_token = tokenizer.next()
    ///   assert(symbol_name_token.tag == .identifier)
    ///   const symbol_name = in[symbol_name_token.loc.start..symbol_name_token.loc.end]
    public static func extractSymbolName(input: String, startIndex: Int64): ?String {
        var i = startIndex
        // 跳过前导空白
        while (i < input.size && input[i] == ' ') {
            i += 1
        }
        if (i >= input.size) {
            return None
        }
        let start = i
        while (i < input.size && isIdentifierChar(input[i])) {
            i += 1
        }
        if (i == start) {
            return None
        }
        return input[start..i]
    }

    /// 找到从指定位置开始的下一个换行符位置。
    /// 对应 Zig: mem.indexOfScalarPos(u8, in, pos, '\n')
    public static func findNewline(input: String, fromIndex: Int64): Int64 {
        var i = fromIndex
        while (i < input.size) {
            if (input[i] == '\n') {
                return i
            }
            i += 1
        }
        return input.size
    }

    /// 处理 translate-c 输出的核心逻辑。
    /// 对应 Zig: main() 函数的主循环
    ///
    /// Zig 原文流程 (逐行注释对应):
    ///   var i: usize = 0;
    ///   while (mem.indexOfPos(u8, in, i, "pub const ")) |pub_i| {
    ///       // 提取符号名 ...
    ///       if (in[end_of_line - 1] != ';') { continue; }  // 跳过多行
    ///       if (symbol_replacements.get(name)) |replace| {  // 符号替换
    ///       } else if (mem.startsWith(u8, in[i..], " = __MINGW_NAME_AW(")) {  // MINGW 检测
    ///       } else {  // 保留原行 }
    ///   }
    public static func process(input: String): String {
        let pubConstPrefix = "pub const "
        var output = StringBuilder()
        var pos: Int64 = 0

        // Zig: while (mem.indexOfPos(u8, in, i, "pub const ")) |pub_i|
        while (true) {
            let pubIndexOpt = input.indexOf(pubConstPrefix, pos)
            if (pubIndexOpt.isNone()) {
                break
            }
            let pubIndex = pubIndexOpt.getOrDefault({=> 0})

            let afterPubConst = pubIndex + pubConstPrefix.size

            // 提取符号名 (Zig: tokenizer.next() -> identifier token)
            let symbolNameOpt = extractSymbolName(input, afterPubConst)
            if (symbolNameOpt == None) {
                // 无法提取符号名，写入到此处并继续
                output.append(input[pos..afterPubConst])
                pos = afterPubConst
                continue
            }
            let symbolName = symbolNameOpt.get()

            // 写入 "pub const SymbolName"
            let symbolEnd = afterPubConst + symbolName.size
            output.append(input[pos..symbolEnd])
            pos = symbolEnd

            // 找到行尾 (Zig: mem.indexOfScalarPos(u8, in, symbol_name_token.loc.end, '\n'))
            let endOfLine = findNewline(input, symbolEnd)

            // 检查是否以 ';' 结尾 (Zig: if (in[end_of_line - 1] != ';'))
            // 不以分号结尾 = 多行声明，跳过
            if (endOfLine == 0 || input[endOfLine - 1] != ';') {
                // Zig: try w.writeAll(in[i..end_of_line]); i = end_of_line; continue;
                output.append(input[pos..endOfLine])
                pos = endOfLine
                continue
            }

            // end_of_line += 1 — 包含换行符 (Zig: end_of_line += 1; // include the \n)
            let endOfLineWithNewline = endOfLine + 1

            // 检查符号替换表 (Zig: if (symbol_replacements.get(symbol_name)) |replace|)
            let replacementOpt = findReplacement(symbolName)
            if (replacementOpt != None) {
                let replace = replacementOpt.get()
                // Zig: try w.print(" = {s};\n", .{replace});
                output.append(" = ")
                output.append(replace.replacement)
                output.append(";\n")
                pos = endOfLineWithNewline
                continue
            }

            // 检查 __MINGW_NAME_AW 宏 (Zig: else if (mem.startsWith(u8, in[i..], " = __MINGW_NAME_AW(")))
            if (pos < input.size && input[pos..].startsWith(" = __MINGW_NAME_AW(")) {
                // Zig: try w.print(" = @compileError(\"Use '{s}W' instead.\");\n", .{symbol_name});
                output.append(" = @compileError(\"Use '")
                output.append(symbolName)
                output.append("W' instead.\");\n")
                pos = endOfLineWithNewline
                continue
            }

            // 默认: 保留原始行 (Zig: try w.writeAll(in[i..end_of_line]))
            output.append(input[pos..endOfLineWithNewline])
            pos = endOfLineWithNewline
        }

        // Zig: try w.writeAll(in[i..]);
        output.append(input[pos..])

        return output.toString()
    }

    /// 端到端处理: 读取文件 -> 处理 -> 写入。
    /// 对应 Zig: main() 的完整流程
    ///
    /// Zig 原文:
    ///   pub fn main() !void {
    ///       const gpa = std.heap.smp_allocator;
    ///       var args = try std.process.argsWithAllocator(gpa);
    ///       assert(args.skip());  // skip argv[0]
    ///       const in = brk: { const in_path = args.next() ...; ... break :brk content; };
    ///       var out = std.array_list.Managed(u8).initCapacity(gpa, in.len);
    ///       ...处理...
    ///       try std.fs.cwd().writeFile(.{ .sub_path = args.next(), .data = out.items });
    ///   }
    ///
    /// 注意: 实际使用时需要调用方通过 BaoFile.readAllText / writeAllText 进行 I/O。
    /// 此处仅处理字符串内容，I/O 由调用方负责。
    public static func processFileContent(input: String): String {
        return process(input)
    }
}

// ============================================================================
// 辅助工具: 断言函数
// 严格翻译自: src/codegen/process_windows_translate_c.zig
//   fn assert(cond: bool) void {
//       if (!cond) @panic("unhandled");
//   }
// ============================================================================

/// 内部断言。
/// 对应 Zig: fn assert(cond: bool) void { if (!cond) @panic("unhandled"); }
internal func assert(cond: Bool): Unit {
    if (!cond) {
        throw RuntimeException("unhandled")
    }
}
