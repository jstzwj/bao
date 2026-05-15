// bao_unicode - Unicode 15.0 处理包
// 严格翻译自: src/unicode/ (Bun uucode library)
//   Bun 使用 uucode 库提供 Unicode 属性查询、编码解码、规范化等功能
//   仓颉实现严格对应 Bun 的 uucode_lib 架构
package bao_unicode

// ============================================================================
// 模块重导出
// ============================================================================

// UTF-8 编解码 - 严格翻译自 src/unicode/uucode_lib/src/utf8.zig
public import bao_unicode.utf8.*

// Unicode 字符表 - 严格翻译自 src/unicode/uucode_lib/src/config.zig + types.zig
public import bao_unicode.tables.*

// Unicode 通用类别 - 严格翻译自 src/unicode/uucode_lib/src/types.zig GeneralCategory
public import bao_unicode.category.*

// 大小写转换与折叠 - 严格翻译自 UnicodeData.txt + CaseFolding.txt
public import bao_unicode.case_folding.*

// Unicode 规范化 - 严格翻译自 UAX #15 NFC/NFD/NFKC/NFKD
public import bao_unicode.normalize.*

// 东亚宽度 - 严格翻译自 src/unicode/uucode_lib/src/x/config_x/wcwidth.zig
public import bao_unicode.width.*

// 字素簇分割 - 严格翻译自 src/unicode/uucode_lib/src/grapheme.zig
public import bao_unicode.grapheme.*

// 标识符判断 - 严格翻译自 Unicode 15.0 ID_Start/ID_Continue
public import bao_unicode.identifier.*
