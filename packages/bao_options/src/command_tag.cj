// CommandTag - CLI 命令标签
// 严格翻译自: bun/src/options_types/CommandTag.zig
//   pub const Tag = enum { AddCommand, AutoCommand, BuildCommand, ... };
package bao_options

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
            case AddCommand => UInt8(73)
            case AutoCommand => UInt8(97)
            case BuildCommand => UInt8(98)
            case BunxCommand => UInt8(66)
            case CreateCommand => UInt8(99)
            case DiscordCommand => UInt8(68)
            case GetCompletionsCommand => UInt8(103)
            case HelpCommand => UInt8(104)
            case InitCommand => UInt8(106)
            case InfoCommand => UInt8(118)
            case InstallCommand => UInt8(105)
            case InstallCompletionsCommand => UInt8(67)
            case LinkCommand => UInt8(108)
            case PackageManagerCommand => UInt8(80)
            case RemoveCommand => UInt8(82)
            case RunCommand => UInt8(114)
            case RunAsNodeCommand => UInt8(110)
            case TestCommand => UInt8(116)
            case UnlinkCommand => UInt8(85)
            case UpdateCommand => UInt8(117)
            case UpgradeCommand => UInt8(112)
            case ReplCommand => UInt8(71)
            case ReservedCommand => UInt8(119)
            case ExecCommand => UInt8(101)
            case PatchCommand => UInt8(120)
            case PatchCommitCommand => UInt8(122)
            case OutdatedCommand => UInt8(111)
            case UpdateInteractiveCommand => UInt8(85)
            case PublishCommand => UInt8(107)
            case AuditCommand => UInt8(65)
            case WhyCommand => UInt8(87)
            case FuzzilliCommand => UInt8(70)
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
