// CommandTag - CLI 命令标签
// 严格翻译自: bun/src/options_types/CommandTag.zig
//   pub const Tag = enum { AddCommand, AutoCommand, BuildCommand, ... };
package bao.options

// ============================================================================
// CommandTag - CLI 命令标签枚举
// 严格翻译自: CommandTag.zig - Tag
//   CLI 子命令判别式，提取到 options_types/ 以便下层模块
//   (install/, bundler/) 可以判断当前执行的命令而无需导入 cli/
// ============================================================================

/// CLI 命令标签 - 对应 Bun Command.Tag
public enum CommandTag {
    | AddCommand
    | AutoCommand
    | BuildCommand
    | BunxCommand
    | CreateCommand
    | DiscordCommand
    | GetCompletionsCommand
    | HelpCommand
    | InitCommand
    | InfoCommand
    | InstallCommand
    | InstallCompletionsCommand
    | LinkCommand
    | PackageManagerCommand
    | RemoveCommand
    | RunCommand
    | RunAsNodeCommand    // arg0 == 'node'
    | TestCommand
    | UnlinkCommand
    | UpdateCommand
    | UpgradeCommand
    | ReplCommand
    | ReservedCommand
    | ExecCommand
    | PatchCommand
    | PatchCommitCommand
    | OutdatedCommand
    | UpdateInteractiveCommand
    | PublishCommand
    | AuditCommand
    | WhyCommand
    | FuzzilliCommand

    /// 崩溃报告用标识字符
    /// 对应 Bun Tag.char()
    public func char(): UInt8 {
        match (this) {
            case AddCommand => 'I'
            case AutoCommand => 'a'
            case BuildCommand => 'b'
            case BunxCommand => 'B'
            case CreateCommand => 'c'
            case DiscordCommand => 'D'
            case GetCompletionsCommand => 'g'
            case HelpCommand => 'h'
            case InitCommand => 'j'
            case InfoCommand => 'v'
            case InstallCommand => 'i'
            case InstallCompletionsCommand => 'C'
            case LinkCommand => 'l'
            case PackageManagerCommand => 'P'
            case RemoveCommand => 'R'
            case RunCommand => 'r'
            case RunAsNodeCommand => 'n'
            case TestCommand => 't'
            case UnlinkCommand => 'U'
            case UpdateCommand => 'u'
            case UpgradeCommand => 'p'
            case ReplCommand => 'G'
            case ReservedCommand => 'w'
            case ExecCommand => 'e'
            case PatchCommand => 'x'
            case PatchCommitCommand => 'z'
            case OutdatedCommand => 'o'
            case UpdateInteractiveCommand => 'U'
            case PublishCommand => 'k'
            case AuditCommand => 'A'
            case WhyCommand => 'W'
            case FuzzilliCommand => 'F'
        }
    }

    /// 是否需要读取全局配置
    /// 对应 Bun Tag.readGlobalConfig()
    public func readGlobalConfig(): Bool {
        match (this) {
            case BunxCommand => true
            case PackageManagerCommand => true
            case InstallCommand => true
            case AddCommand => true
            case RemoveCommand => true
            case UpdateCommand => true
            case PatchCommand => true
            case PatchCommitCommand => true
            case OutdatedCommand => true
            case PublishCommand => true
            case AuditCommand => true
            case _ => false
        }
    }

    /// 是否为 NPM 相关命令
    /// 对应 Bun Tag.isNPMRelated()
    public func isNPMRelated(): Bool {
        match (this) {
            case BunxCommand => true
            case LinkCommand => true
            case UnlinkCommand => true
            case PackageManagerCommand => true
            case InstallCommand => true
            case AddCommand => true
            case RemoveCommand => true
            case UpdateCommand => true
            case PatchCommand => true
            case PatchCommitCommand => true
            case OutdatedCommand => true
            case PublishCommand => true
            case AuditCommand => true
            case _ => false
        }
    }

    /// 是否加载配置文件
    /// 对应 Bun Tag.loads_config
    public func loadsConfig(): Bool {
        match (this) {
            case BuildCommand => true
            case TestCommand => true
            case InstallCommand => true
            case AddCommand => true
            case RemoveCommand => true
            case UpdateCommand => true
            case PatchCommand => true
            case PatchCommitCommand => true
            case PackageManagerCommand => true
            case BunxCommand => true
            case AutoCommand => true
            case RunCommand => true
            case RunAsNodeCommand => true
            case OutdatedCommand => true
            case UpdateInteractiveCommand => true
            case PublishCommand => true
            case AuditCommand => true
            case _ => false
        }
    }

    /// 是否始终加载配置
    /// 对应 Bun Tag.always_loads_config
    public func alwaysLoadsConfig(): Bool {
        match (this) {
            case BuildCommand => true
            case TestCommand => true
            case InstallCommand => true
            case AddCommand => true
            case RemoveCommand => true
            case UpdateCommand => true
            case PatchCommand => true
            case PatchCommitCommand => true
            case PackageManagerCommand => true
            case BunxCommand => true
            case OutdatedCommand => true
            case UpdateInteractiveCommand => true
            case PublishCommand => true
            case AuditCommand => true
            case _ => false
        }
    }
}
