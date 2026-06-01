// bao_base64 - Base64 编码/解码
// 严格翻译自: src/base64/base64.zig
// 对应 Bun 的 Base64 实现，包括:
//   - 标准 Base64 编码/解码 (带 padding)
//   - URL-safe Base64 编码/解码 (无 padding, +/ → -_)
//   - 标准 Base64 字母表: ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/
//   - URL-safe Base64 字母表: ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_
//   - Padding 处理 (=)
//   - 字符到索引查找表 (256 字节, 非法字符 = 0xFF)
package bao_base64

import bao_core.*
import std.collection.*
