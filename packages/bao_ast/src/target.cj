// 编译目标平台
// 严格翻译自: src/ast/target.rs (112行)
//   bundler/options.zig Target — bundle target platform.
//   包含:
//     - Target: 目标平台枚举 (Browser, Bun, Node, ...)
//     - 默认 main 字段顺序
//     - 默认条件映射
package bao_ast

import bao_core.*

// ============================================================================
// Target - 编译目标平台
// 严格翻译自: target.rs:12-21
//   pub enum Target { Browser, Bun, BunMacro, Node, BakeServerComponentsSsr }
// ============================================================================

/// 编译目标平台 - 对应 Bun Target
/// Zig 默认值为 .browser
public enum Target {
    | Browser
    | Bun
    | BunMacro
    | Node
    | BakeServerComponentsSsr

    public operator func ==(right: Target): Bool {
        ordinal() == right.ordinal()
    }

    public operator func !=(right: Target): Bool {
        !(this == right)
    }

    public func ordinal(): Int64 {
        match (this) {
            case Browser => 0
            case Bun => 1
            case BunMacro => 2
            case Node => 3
            case BakeServerComponentsSsr => 4
        }
    }

    /// 是否为服务端 - 对应 Target.is_server_side()
    public func isServerSide(): Bool {
        match (this) {
            case BunMacro | Node | Bun | BakeServerComponentsSsr => true
            case Browser => false
        }
    }

    /// 是否为 Bun - 对应 Target.is_bun()
    public func isBun(): Bool {
        match (this) {
            case BunMacro | Bun | BakeServerComponentsSsr => true
            case _ => false
        }
    }

    /// 是否为 Node - 对应 Target.is_node()
    public func isNode(): Bool {
        match (this) {
            case Node => true
            case _ => false
        }
    }

    /// 浏览器 define 值 - 对应 Target.process_browser_define_value()
    public func processBrowserDefineValue(): ?String {
        match (this) {
            case Browser => Some("true")
            case _ => Some("false")
        }
    }

    /// 默认 main 字段顺序 - 对应 Target.default_main_fields()
    ///
    /// Node: "main" > "module"
    ///   注意: 这意味着 tree shaking 在 node 环境下不工作
    ///   原因: 某些包错误地将 "module" 字段当作 "浏览器代码"
    ///
    /// Browser: "browser" > "module" > "jsnext:main" > "main"
    ///   注意: "browser" 优先于 "module"，与 webpack 行为一致
    ///
    /// Bun: "module" > "main" > "jsnext:main"
    public func defaultMainFields(): Array<String> {
        match (this) {
            case Node => ["main", "module"]
            case Browser => ["browser", "module", "jsnext:main", "main"]
            case Bun | BunMacro | BakeServerComponentsSsr => ["module", "main", "jsnext:main"]
        }
    }

    /// 默认条件 - 对应 Target.default_conditions()
    public func defaultConditions(): Array<String> {
        match (this) {
            case Node => ["node"]
            case Browser => ["browser", "module"]
            case Bun => ["bun", "node"]
            case BakeServerComponentsSsr => ["bun", "node"]
            case BunMacro => ["macro", "bun", "node"]
        }
    }
}

/// 目标平台名称映射 - 对应 Target.MAP
public let TARGET_MAP: HashMap<String, Target> = {
    let m = HashMap<String, Target>()
    m.put("browser", Target.Browser)
    m.put("bun", Target.Bun)
    m.put("bun_macro", Target.BunMacro)
    m.put("macro", Target.BunMacro)
    m.put("node", Target.Node)
    m
}()
