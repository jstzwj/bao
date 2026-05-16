// 翻译自 Bun: src/runtime/bake/DevServer.bind.ts
// DevServer bindgen 声明文件。Bun 源文件当前仅保留注释中的字典草案，未导出运行时代码。

package bao_runtime.bake

/// React Fast Refresh 配置字典草案。
/// 对应 Bun 注释: ReactFastRefresh = t.dictionary({ importSource: t.UTF8String })
public class ReactFastRefreshBindConfig {
    public var importSource: String

    public init(importSource: String) {
        this.importSource = importSource
    }
}

/// Framework 配置字典草案。
/// 对应 Bun 注释: FrameworkConfig = t.dictionary({ reactFastRefresh: t.oneOf(t.boolean, ReactFastRefresh).default(false) })
public enum FrameworkReactFastRefreshOption {
    | disabled
    | enabled
    | config(ReactFastRefreshBindConfig)
}

public class FrameworkBindConfig {
    public var reactFastRefresh: FrameworkReactFastRefreshOption = FrameworkReactFastRefreshOption.disabled
}
