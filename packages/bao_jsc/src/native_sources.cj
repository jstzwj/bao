// Bao JSC native source manifest.
// The Bun JSC bindings/headergen/modules sources remain native C/C++/header files
// under ../native and are not mechanically translated into Cangjie sources.

package bao_jsc

public class JscNativeSources {
    public let nativeRoot: String = "native"
    public let bindingsPath: String = "native/bindings"
    public let headergenPath: String = "native/headergen"
    public let modulesPath: String = "native/modules"

    public let bindingsFileCount: Int64 = 1274
    public let headergenFileCount: Int64 = 1
    public let modulesFileCount: Int64 = 19
    public let totalFileCount: Int64 = 1294

    public let purpose: String = "Original Bun src/jsc native C/C++/header sources used by Bao JSC wrappers. These files are kept outside src so cjpm does not compile them as Cangjie."

    public init() {}
}
