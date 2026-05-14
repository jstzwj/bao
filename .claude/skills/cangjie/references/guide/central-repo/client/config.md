# 中心仓客户端配置

仓颉项目管理工具 `cjpm` 集成了中心仓客户端功能，因此需要在本地安装仓颉 `SDK` 并进行中心仓相关配置。

## 安装仓颉工具链

请参阅[仓颉 SDK 安装指南](https://gitcode.com/Cangjie/cangjie_docs/blob/dev/docs/dev-guide/source_zh_cn/first_understanding/install.md)安装并验证本地仓颉环境。

## 仓库配置

`cjpm` 通过配置文件 `cangjie-repo.toml` 进行中心仓相关配置，其格式如下：

```toml
[repository.cache]
  path = "/path/to/repository/cache"              # 本地存放路径

[repository.home]
  registry = "https://pkg.cangjie-lang.cn/cjpm"   # 中心仓 url
  token = "user-token"                            # 用户个人 token
```

其中，各配置字段含义如下：

- `repository.cache.path`: 配置本地缓存路径，用于存放从中心仓下载的制品包源码：
    - 配置的路径可以为绝对路径或相对路径，若为相对路径，则为相对当前 `cangjie-repo.toml` 的路径；
    - 若配置项为空，则 `Linux/macOS` 上最终生效的路径为 `$HOME/.cjpm`，`Windows` 上最终生效的路径为 `%USERPROFILE%\.cjpm`；
    - 假设最终生效的路径为 `CACHE_PATH`，则从中心仓下载的制品包源码及其他中心仓相关内容会存放在 `${CACHE_PATH}/repository` 目录下。
- `repository.home.registry`: 配置中心仓仓库地址 (https://pkg.cangjie-lang.cn/cjpm)，用于与中心仓进行上传下载相关的通信。
- `repository.home.token`: 配置用户个人 token，用于在上传制品包时进行用户认证。

用户可在如下三个位置配置 `cangjie-repo.toml`，在用户执行 `cjpm` 相关指令后，`cjpm` 将按照如下的顺序依次搜索对应位置是否存在 `cangjie-repo.toml`，直到找到为止：

1. 模块内与 `cjpm.toml` 同级目录的 `cangjie-repo.toml`；
2. 用户目录下 `.cjpm` 目录内的 `cangjie-repo.toml`，`Linux/macOS` 上为 `$HOME/.cjpm/cangjie-repo.toml`，`Windows` 上为 `%USERPROFILE%\.cjpm\cangjie-repo.toml`；
3. 仓颉 `SDK` 中 `tools/config` 目录下的 `cangjie-repo.toml`，仓颉 `SDK` 中默认存在该文件，其中所有配置为默认值。