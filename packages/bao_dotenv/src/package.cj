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
