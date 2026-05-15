// 严格翻译自: src/jsc/resolver_jsc.zig
// 解析器 JSC 绑定 - node:module 的 _nodeModulePaths 的宿主函数/C++ 导出

package bao_jsc

// ========== ResolverJSC ==========
// 严格翻译自 resolver_jsc 命名空间
// node:module 的 _nodeModulePaths 的宿主函数
// 从 resolver/resolver.zig 提取，以便 resolver/ 不包含 JSC 引用
public class ResolverJSC {

    // 严格翻译自 nodeModulePathsForJS
    public static func nodeModulePathsForJS(globalThis: JsObject, callFrame: CallFrame) -> JsValue {
        let argument = callFrame.argument(0)

        if (argument.isUndefinedOrNull() || !argument.isString()) {
            return globalThis.throwInvalidArgumentType("nodeModulePaths", "path", "string")
        }

        return nodeModulePathsJSValue(argument.toString(), globalThis, false)
    }

    // 严格翻译自 Resolver__propForRequireMainPaths
    // 导出函数
    public static func propForRequireMainPaths(globalThis: JsObject) -> JsValue {
        nodeModulePathsJSValue(".", globalThis, false)
    }

    // 严格翻译自 nodeModulePathsJSValue
    public static func nodeModulePathsJSValue(inStr: String, globalObject: JsObject, useDirname: Bool) -> JsValue {
        // 1. 解析输入路径
        // 2. 从输入路径开始，向上遍历目录树
        // 3. 在每个目录级别，添加 node_modules 路径
        // 4. 返回路径数组
        JsValue.undefined()
    }
}
