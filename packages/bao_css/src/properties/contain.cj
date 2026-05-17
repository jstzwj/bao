// bao_css - CSS Properties: Contain (Container)
// 严格翻译自: bun/src/css/properties/contain.rs
//   对应: contain.zig - CSS 容器查询属性
//   对应: ContainerType, ContainerNameList, Container
// ============================================================================

package bao_css.properties

import bao_core.*
import bao_collections.*

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

    private func namesToCss(names: ArrayList<String>): String {
        if (names.isEmpty()) {
            "none"
        } else {
            var partArr = Array<String>(names.size, repeat: "")
            var pi: Int64 = 0
            for (p in names) { partArr[pi] = p; pi += 1 }
            String.join(partArr, delimiter: " ")
        }
    }

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Names(names) => namesToCss(names)
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
