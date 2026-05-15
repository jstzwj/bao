// 严格翻译自: src/jsc/codegen.zig (14行)
// JSC 代码生成辅助类型

package bao_jsc

// ========== CodegenDecl ==========
// 严格翻译自 codegen.zig CodegenDecl
// 代码生成声明结构体，用于跟踪 JSC 绑定的类型信息
public struct CodegenDecl<T> {
    // 绑定的类型
    public var theType: T
    // C++ 符号名
    public var symbolName: String
    // 本地名称
    public var localName: String
    // 父类型
    public var parent: String

    public init(theType: T, symbolName: String, localName: String, parent: String) {
        this.theType = theType
        this.symbolName = symbolName
        this.localName = localName
        this.parent = parent
    }

    // 严格翻译自 wrappedName
    // 返回包装后的名称，加上 "wrap" 前缀
    public func wrappedName() -> String {
        "wrap" + symbolName
    }

    // 严格翻译自 Decl
    // 获取声明信息（返回父类型中的声明名称）
    public func decl() -> String {
        localName
    }
}
