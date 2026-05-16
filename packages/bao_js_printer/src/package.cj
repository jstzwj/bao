// bao_js_printer - JavaScript code printer
// 严格翻译自 Bun 的 src/js_printer/ 模块
//   Bun 的 js_printer 模块将 AST 节点生成 JavaScript 源代码
//
// Bun 源文件对应关系:
//   src/js_printer/js_printer.zig -> js_printer.cj (核心打印器)
//   src/js_printer/js_printer.zig -> js_printer_expr.cj (表达式打印)
//   src/js_printer/js_printer.zig -> js_printer_stmt.cj (语句打印)
//   src/js_printer/js_printer.zig -> js_printer_writer.cj (Writer 和入口函数)
//   src/js_printer/renamer.zig    -> renamer.cj (符号重命名器)
//   src/js_printer/lib.rs         -> module_info.cj (ModuleInfo 分析)
//
// 仓颉翻译说明:
//   - Zig 的 comptime 泛型 (NewPrinter) 在仓颉中用类字段代替
//   - Writer 类型参数化用 PrinterWriter 接口代替
//   - ExprFlag.Set (EnumSet) 用位标志类代替
//   - Whitespacer 的 comptime 计算改为运行时处理
package bao_js_printer

import bao_core.*
import bao_collections.*
