// bao_css - CSS Properties: Grid
// 严格翻译自: bun/src/css/properties/grid.rs
//   对应: grid.zig - CSS 网格布局属性
//   对应: TrackSizing, TrackList, TrackListItem, TrackSize
//   对应: TrackBreadth, TrackRepeat, RepeatCount
//   对应: TrackSizeList, GridTemplateAreas
// ============================================================================

package bao.css

import bao_core.*

// ============================================================================
// TrackSizing
// 严格翻译自 TrackSizing
// ============================================================================

/// grid-template-rows/columns 属性值
/// 严格翻译自 TrackSizing
public enum TrackSizing {
    | None               // 无显式轨道
    | Tracklist(TrackList) // 轨道列表

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Tracklist(tl) => tl.toCss()
        }
    }
}

// ============================================================================
// TrackList
// 严格翻译自 TrackList
// ============================================================================

/// <track-list> 值
/// 严格翻译自 TrackList
public class TrackList {
    public var lineNames: ArrayList<ArrayList<String>>  // 线名列表
    public var items: ArrayList<TrackListItem>          // 轨道项列表

    public init(lineNames: ArrayList<ArrayList<String>>, items: ArrayList<TrackListItem>) {
        this.lineNames = lineNames
        this.items = items
    }

    public func toCss(): String {
        var parts = ArrayList<String>()
        var itemsIndex = 0
        var first = true

        for (i in 0..lineNames.size) {
            let names = lineNames[i]
            if (!names.isEmpty()) {
                var nameStr = "["
                for (j in 0..names.size) {
                    if (j > 0) {
                        nameStr = nameStr + " "
                    }
                    nameStr = nameStr + names[j]
                }
                nameStr = nameStr + "]"
                parts.append(nameStr)
            }

            if (itemsIndex < items.size) {
                let item = items[itemsIndex]
                itemsIndex = itemsIndex + 1

                if (!names.isEmpty()) {
                    parts.append(" ")
                } else if (!first) {
                    parts.append(" ")
                }

                parts.append(item.toCss())
            }

            first = false
        }

        return String.join("", parts)
    }
}

// ============================================================================
// TrackListItem
// 严格翻译自 TrackListItem
// ============================================================================

/// 轨道列表项（轨道尺寸或 repeat()）
/// 严格翻译自 TrackListItem
public enum TrackListItem {
    | TrackSize(TrackSize)         // 轨道尺寸
    | TrackRepeat(TrackRepeat)     // repeat() 函数

    public func toCss(): String {
        match (this) {
            case TrackSize(ts) => ts.toCss()
            case TrackRepeat(tr) => tr.toCss()
        }
    }
}

// ============================================================================
// TrackSize
// 严格翻译自 TrackSize
// ============================================================================

/// <track-size> 值
/// 严格翻译自 TrackSize
public enum TrackSize {
    | TrackBreadth(TrackBreadth)   // 显式轨道宽度
    | MinMax(TrackBreadth, TrackBreadth) // minmax() 函数
    | FitContent(String)           // fit-content() 函数

    public func toCss(): String {
        match (this) {
            case TrackBreadth(tb) => tb.toCss()
            case MinMax(min, max) => "minmax(" + min.toCss() + ", " + max.toCss() + ")"
            case FitContent(lp) => "fit-content(" + lp + ")"
        }
    }

    public static func default(): TrackSize {
        TrackSize.TrackBreadth(TrackBreadth.Auto)
    }
}

// ============================================================================
// TrackBreadth
// 严格翻译自 TrackBreadth
// ============================================================================

/// <track-breadth> 值
/// 严格翻译自 TrackBreadth
public enum TrackBreadth {
    | Length(String)   // 显式长度
    | Flex(Float64)    // flex 因子 (fr)
    | MinContent       // min-content
    | MaxContent       // max-content
    | Auto             // auto

    public func toCss(): String {
        match (this) {
            case Length(l) => l
            case Flex(f) => f.toString() + "fr"
            case MinContent => "min-content"
            case MaxContent => "max-content"
            case Auto => "auto"
        }
    }
}

// ============================================================================
// TrackSizeList
// 严格翻译自 TrackSizeList
// ============================================================================

/// 轨道尺寸列表
/// 严格翻译自 TrackSizeList
public class TrackSizeList {
    public var v: ArrayList<TrackSize>  // 轨道尺寸列表

    public init() {
        this.v = ArrayList<TrackSize>()
    }

    public init(v: ArrayList<TrackSize>) {
        this.v = v
    }

    public func toCss(): String {
        if (v.isEmpty()) {
            return "auto"
        }
        var parts = ArrayList<String>()
        for (item in v) {
            parts.append(item.toCss())
        }
        return String.join(" ", parts)
    }
}

// ============================================================================
// TrackRepeat
// 严格翻译自 TrackRepeat
// ============================================================================

/// repeat() 函数
/// 严格翻译自 TrackRepeat
public class TrackRepeat {
    public var count: RepeatCount                      // 重复次数
    public var lineNames: ArrayList<ArrayList<String>> // 线名列表
    public var trackSizes: ArrayList<TrackSize>        // 轨道尺寸列表

    public init(count: RepeatCount, lineNames: ArrayList<ArrayList<String>>, trackSizes: ArrayList<TrackSize>) {
        this.count = count
        this.lineNames = lineNames
        this.trackSizes = trackSizes
    }

    public func toCss(): String {
        var parts = ArrayList<String>()
        parts.append("repeat(")
        parts.append(count.toCss())
        parts.append(",")

        var trackIndex = 0
        var first = true
        for (i in 0..lineNames.size) {
            let names = lineNames[i]
            if (!names.isEmpty()) {
                var nameStr = " ["
                for (j in 0..names.size) {
                    if (j > 0) {
                        nameStr = nameStr + " "
                    }
                    nameStr = nameStr + names[j]
                }
                nameStr = nameStr + "]"
                parts.append(nameStr)
            }

            if (trackIndex < trackSizes.size) {
                if (!names.isEmpty()) {
                    parts.append(" ")
                } else if (!first) {
                    parts.append(" ")
                }
                parts.append(trackSizes[trackIndex].toCss())
                trackIndex = trackIndex + 1
            }

            first = false
        }

        parts.append(")")
        return String.join("", parts)
    }
}

// ============================================================================
// RepeatCount
// 严格翻译自 RepeatCount
// ============================================================================

/// <repeat-count> 值
/// 严格翻译自 RepeatCount
public enum RepeatCount {
    | Number(Int64)   // 固定次数
    | AutoFill        // auto-fill
    | AutoFit         // auto-fit

    public func toCss(): String {
        match (this) {
            case Number(n) => n.toString()
            case AutoFill => "auto-fill"
            case AutoFit => "auto-fit"
        }
    }
}

// ============================================================================
// GridTemplateAreas
// 严格翻译自 GridTemplateAreas
// ============================================================================

/// grid-template-areas 属性值
/// 严格翻译自 GridTemplateAreas
public enum GridTemplateAreas {
    | None                                    // 无命名区域
    | Areas(UInt32, ArrayList<Option<String>>) // 列数 + 扁平化区域名称列表

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Areas(columns, areas) => {
                var parts = ArrayList<String>()
                var rowStr = ""
                var col = 0
                for (i in 0..areas.size) {
                    let area = areas[i]
                    let name = match (area) {
                        case Some(s) => s
                        case None => "."
                    }
                    if (col == 0) {
                        rowStr = "\""
                    } else {
                        rowStr = rowStr + " "
                    }
                    rowStr = rowStr + name
                    col = col + 1
                    if (col == columns) {
                        rowStr = rowStr + "\""
                        parts.append(rowStr)
                        rowStr = ""
                        col = 0
                    }
                }
                return String.join(" ", parts)
            }
        }
    }
}
