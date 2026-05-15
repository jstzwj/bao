// bao_css - CSS Properties: Contain (Container)
// 严格翻译自: bun/src/css/properties/contain.rs
//   对应: contain.zig - CSS 容器查询属性
//   对应: ContainerType, ContainerNameList, Container
// ============================================================================

package bao.css

import bao_core.*

// ============================================================================
// ContainerType
// 严格翻译自 ContainerType (占位)
// ============================================================================

/// container-type 属性值（占位）
/// Zig 源码为 DefineEnumProperty(@compileError(...)) 占位
/// 严格翻译自 ContainerType
public struct ContainerType {
}

// ============================================================================
// ContainerNameList
// 严格翻译自 ContainerNameList
// ============================================================================

/// container-name 属性值
/// 严格翻译自 ContainerNameList
public enum ContainerNameList {
    | None                          // "none"
    | Names(ArrayList<String>)      // 容器名称列表

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Names(names) => {
                if (names.isEmpty()) {
                    return "none"
                }
                return String.join(" ", names)
            }
        }
    }
}

// ============================================================================
// Container
// 严格翻译自 Container (占位)
// ============================================================================

/// container 属性值（占位）
/// Zig 源码为 DefineEnumProperty(@compileError(...)) 占位
/// 严格翻译自 Container
public struct Container {
}
