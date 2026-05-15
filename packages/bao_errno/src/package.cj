// bao_errno - 系统错误码
// 严格翻译自: bun/src/errno/
//   linux_errno.zig, darwin_errno.zig, freebsd_errno.zig, windows_errno.zig
//
// 模块拆分:
//   linux_errno.cj   - Linux 系统错误码 (翻译自 linux_errno.zig)
//   darwin_errno.cj   - macOS/Darwin 系统错误码 (翻译自 darwin_errno.zig)
//   freebsd_errno.cj  - FreeBSD 系统错误码 (翻译自 freebsd_errno.zig)
//   windows_errno.cj  - Windows 系统错误码 (翻译自 windows_errno.zig)
package bao_errno

// 重导出所有子模块
// 各平台的 SystemErrno 和 UV_E 定义在对应的文件中
