// 严格翻译自: src/jsc/EventType.zig (33行)
// 事件类型枚举

package bao_jsc

// ========== EventType ==========
// 严格翻译自 EventType.zig EventType
// 事件类型枚举，用于 WebSocket 和其他事件系统
public enum EventType {
    | None
}
    }

    // 从字符串解析事件类型
    public static func fromString(name: String) -> EventType {
        if (name == "event") {
            Event
        } else if (name == "message") {
            MessageEvent
        } else if (name == "close") {
            CloseEvent
        } else if (name == "error") {
            ErrorEvent
        } else if (name == "open") {
            OpenEvent
        } else {
            Unknown
        }
    }
}
