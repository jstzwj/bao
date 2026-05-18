// 严格翻译自: src/parsers/interchange.zig
//   交叉引用入口 - 统一导出各解析器模块
//   pub const json = @import("./json.zig");
//   pub const json5 = @import("./json5.zig");
//   pub const toml = @import("./toml.zig");
//   pub const yaml = @import("./yaml.zig");
//
// Bun 使用 Zig 的 @import 在 interchange.zig 中统一导出解析器子模块
// 仓颉使用 type 别名实现相同的跨文件引用
package bao_parsers


// ============================================================================
// 解析器模块类型别名
// 严格翻译自: src/parsers/interchange.zig
//   pub const json = @import("./json.zig");
//   pub const json5 = @import("./json5.zig");
//   pub const toml = @import("./toml.zig");
//   pub const yaml = @import("./yaml.zig");
// ============================================================================

/// JSON 解析器别名 - 对应 Bun interchange.json
/// 详细实现见 json_parser.cj 中的 JSONParser
public type InterchangeJSON = JSONParser

/// JSON5 解析器别名 - 对应 Bun interchange.json5
/// 详细实现见 json5_parser.cj 中的 JSON5Parser
public type InterchangeJSON5 = JSON5Parser

/// TOML 解析器别名 - 对应 Bun interchange.toml
/// 详细实现见 toml_parser.cj 中的 TomlParser
public type InterchangeTOML = TomlParser

/// YAML 解析器别名 - 对应 Bun interchange.yaml
/// 详细实现见 yaml_parser.cj 中的 YamlParser
public type InterchangeYAML = YamlParser
