package bao_runtime
import bao_core.*
import bao_collections.*

public class WhyCommand {
    public static func execFromPm(ctx: CommandContext, pm: PackageManager, positionals: ArrayList<String>): Unit {
        Output.prettyln("bao pm why - not yet implemented")
    }
}
