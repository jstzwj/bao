// 严格翻译自: src/bun_core/output.rs:2399-2443 + src/bun_core/output.zig:1111-1144
//   fn print_command(argv: CommandArgv<'_>, destination: Destination) void { ... }
//   pub fn command_out(argv: CommandArgv<'_>) { print_command(argv, .stdout); }
//   pub fn command(argv: CommandArgv<'_>) { print_command(argv, .stderr); }
package bao_output

import bao_core.*
import bao_core.Output
import bao_core.Destination

// ============================================================================
// CommandArgv - 命令参数
// 严格翻译自: src/bun_core/output.rs:2403-2406
//   pub enum CommandArgv<'a> {
//       List(&'a [&'a [u8]]),
//       Single(&'a [u8]),
//   }
// ============================================================================

/// 命令参数 - 对应 Bun CommandArgv
/// pub enum CommandArgv<'a> { List(&'a [&'a [u8]]), Single(&'a [u8]) }
public enum CommandArgv {
    | List(Array<String>)
    | Single(String)
}

// ============================================================================
// CommandPrint - 命令打印
// 严格翻译自: src/bun_core/output.zig:1111-1144
//   fn printCommand(argv: anytype, comptime destination: Destination) void {
//       const prettyFn = if (destination == .stdout) pretty else prettyError;
//       const printFn = if (destination == .stdout) print else printError;
//       switch (@TypeOf(argv)) {
//           [][:0]const u8, ... => {
//               prettyFn("<r><d><magenta>$<r> <d><b>", .{});
//               printFn("{s}", .{argv[0]});
//               for (argv[1..]) |arg| { printFn(" {s}", .{arg}); }
//               prettyFn("<r>\n", .{});
//           },
//           []const u8, ... => {
//               prettyFn("<r><d><magenta>$<r> <d><b>{s}<r>\n", .{argv});
//           },
//       }
//       flush();
//   }
// ============================================================================

/// 命令打印 - 对应 Bun printCommand
public class CommandPrint {

    /// 打印命令到指定目标 - 对应 Bun printCommand()
    public static func printCommand(argv: CommandArgv, destination: Destination): Unit {
        match (argv) {
            case List(arr) =>
                prettyTo("<r><d><magenta>$<r> <d><b>", destination)
                match (destination) {
                    case Stdout => Output.print(arr[0])
                    case Stderr => Output.printError(arr[0])
                }
                for (i in 1..arr.size) {
                    match (destination) {
                        case Stdout => Output.print(" ${arr[i]}")
                        case Stderr => Output.printError(" ${arr[i]}")
                    }
                }
                prettyTo("<r>\n", destination)
            case Single(cmd) =>
                prettyTo("<r><d><magenta>$<r> <d><b>${cmd}<r>\n", destination)
        }
        Output.flush()
    }

    /// 打印命令到 stderr - 对应 Bun Output.command()
    public static func command(argv: CommandArgv): Unit {
        printCommand(argv, Destination.Stderr)
    }

    /// 打印命令到 stdout - 对应 Bun Output.commandOut()
    public static func commandOut(argv: CommandArgv): Unit {
        printCommand(argv, Destination.Stdout)
    }

    /// Pretty 打印到指定目标
    private static func prettyTo(fmt: String, dest: Destination): Unit {
        match (dest) {
            case Stdout => Output.pretty(fmt)
            case Stderr => Output.prettyError(fmt)
        }
    }
}
