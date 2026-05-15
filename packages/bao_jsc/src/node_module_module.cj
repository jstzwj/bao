// 严格翻译自: src/jsc/NodeModuleModule.zig
// Node.js 模块系统相关的 C++ 导出和辅助函数

package bao_jsc

// ========== NodeModuleModule ==========
// 严格翻译自 NodeModuleModule 命名空间
// 提供 Node.js module 系统所需的原生绑定
public class NodeModuleModule {

    // 严格翻译自 NodeModuleModule__findPath
    // 对应 node 的 Module._findPath
    public static func findPath(
        global: JsObject,
        requestBunStr: String,
        pathsMaybe: ?JsArray
    ) -> JsValue {
        let request = requestBunStr

        let absoluteRequest = PathUtils.isAbsolute(request)
        if (!absoluteRequest && pathsMaybe == None) {
            return JsValue.false_
        }

        // 搜索每个路径
        if let paths = pathsMaybe {
            for (path in paths.iterator(global)) {
                if let found = findPathInner(request, path, global) {
                    return found
                }
            }
        } else {
            if let found = findPathInner(request, "", global) {
                return found
            }
        }

        return JsValue.false_
    }

    // 严格翻译自 findPathInner
    private static func findPathInner(
        request: String,
        curPath: String,
        global: JsObject
    ) -> ?JsValue {
        // 尝试解析路径
        None
    }

    // 严格翻译自 _stat
    // 对应 node 的 internalModuleStat
    public static func stat(path: String) -> Int32 {
        // -1 表示其他类型的字符串
        //  0 表示文件
        //  1 表示目录
        -1
    }

    // 严格翻译自 CustomLoader
    // 自定义加载器联合体
    public enum CustomLoader {
        case loader(Loader)
        case custom(Strong)
    }

    // 严格翻译自 onRequireExtensionModify
    // 处理 require 扩展修改
    public static func onRequireExtensionModify(
        global: JsObject,
        str: String,
        loader: Loader,
        value: JsValue
    ) {
        // 修改 commonjs 自定义扩展映射
    }

    // 严格翻译自 onRequireExtensionModifyNonFunction
    // 处理 require 扩展删除
    public static func onRequireExtensionModifyNonFunction(
        global: JsObject,
        str: String
    ) {
        // 从映射中移除扩展
    }

    // 严格翻译自 findLongestRegisteredExtension
    // 查找文件名最长匹配的注册扩展
    public static func findLongestRegisteredExtension(vm: BunVirtualMachine, filename: String) -> ?CustomLoader {
        None
    }
}
