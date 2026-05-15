// bao_install - 进度字符串
// 严格翻译自: src/install/PackageManager/ProgressStrings.zig
//   pub const ProgressStrings = struct {
//       pub const download_no_emoji_ = "Resolving"
//       pub const download_emoji = "  ? "
//       ...
//   }
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 进度字符串
// 严格翻译自: src/install/PackageManager/ProgressStrings.zig - ProgressStrings
// ============================================================================

/// 进度字符串
/// 对应 Bun: PackageManager.ProgressStrings
/// 翻译自: src/install/PackageManager/ProgressStrings.zig
public class ProgressStringsFull {
    // ===== 下载 (解析) 阶段 =====

    /// 下载阶段文本 (无 emoji)
    /// 翻译自: download_no_emoji_ = "Resolving"
    public static let DOWNLOAD_NO_EMOJI_TEXT: String = "Resolving"

    /// 下载阶段文本 (无 emoji, 带换行)
    /// 翻译自: download_no_emoji = download_no_emoji_ ++ "\n"
    public static func downloadNoEmoji(): String {
        return "${DOWNLOAD_NO_EMOJI_TEXT}\n"
    }

    /// 下载阶段 emoji
    /// 翻译自: download_emoji = "  ? "
    public static let DOWNLOAD_EMOJI: String = "  ? "

    /// 下载阶段文本 (带 emoji)
    /// 翻译自: download_with_emoji = download_emoji ++ download_no_emoji_
    public static func downloadWithEmoji(): String {
        return "${DOWNLOAD_EMOJI}${DOWNLOAD_NO_EMOJI_TEXT}\n"
    }

    /// 下载阶段 (根据终端能力选择)
    /// 翻译自: ProgressStrings.download
    public static func download(): String {
        return downloadNoEmoji()
    }

    // ===== 解压阶段 =====

    /// 解压阶段文本 (无 emoji)
    /// 翻译自: extract_no_emoji_ = "Resolving & extracting"
    public static let EXTRACT_NO_EMOJI_TEXT: String = "Resolving & extracting"

    public static func extractNoEmoji(): String {
        return "${EXTRACT_NO_EMOJI_TEXT}\n"
    }

    /// 解压阶段 emoji
    /// 翻译自: extract_emoji = "  ? "
    public static let EXTRACT_EMOJI: String = "  ? "

    public static func extractWithEmoji(): String {
        return "${EXTRACT_EMOJI}${EXTRACT_NO_EMOJI_TEXT}\n"
    }

    public static func extract(): String {
        return extractNoEmoji()
    }

    // ===== 安装阶段 =====

    /// 安装阶段文本 (无 emoji)
    /// 翻译自: install_no_emoji_ = "Installing"
    public static let INSTALL_NO_EMOJI_TEXT: String = "Installing"

    public static func installNoEmoji(): String {
        return "${INSTALL_NO_EMOJI_TEXT}\n"
    }

    /// 安装阶段 emoji
    /// 翻译自: install_emoji = "  ? "
    public static let INSTALL_EMOJI: String = "  ? "

    public static func installWithEmoji(): String {
        return "${INSTALL_EMOJI}${INSTALL_NO_EMOJI_TEXT}\n"
    }

    public static func install(): String {
        return installNoEmoji()
    }

    // ===== 保存锁文件阶段 =====

    /// 保存阶段文本 (无 emoji)
    /// 翻译自: save_no_emoji_ = "Saving lockfile"
    public static let SAVE_NO_EMOJI_TEXT: String = "Saving lockfile"

    public static func saveNoEmoji(): String {
        return SAVE_NO_EMOJI_TEXT
    }

    /// 保存阶段 emoji
    /// 翻译自: save_emoji = "  ? "
    public static let SAVE_EMOJI: String = "  ? "

    public static func saveWithEmoji(): String {
        return "${SAVE_EMOJI}${SAVE_NO_EMOJI_TEXT}"
    }

    public static func save(): String {
        return saveNoEmoji()
    }

    // ===== 脚本执行阶段 =====

    /// 脚本阶段文本 (无 emoji)
    /// 翻译自: script_no_emoji_ = "Running script"
    public static let SCRIPT_NO_EMOJI_TEXT: String = "Running script"

    public static func scriptNoEmoji(): String {
        return "${SCRIPT_NO_EMOJI_TEXT}\n"
    }

    /// 脚本阶段 emoji
    /// 翻译自: script_emoji = "  ?  "
    public static let SCRIPT_EMOJI: String = "  >  "

    public static func scriptWithEmoji(): String {
        return "${SCRIPT_EMOJI}${SCRIPT_NO_EMOJI_TEXT}\n"
    }

    public static func script(): String {
        return scriptNoEmoji()
    }
}

// ============================================================================
// 进度条管理
// 严格翻译自: src/install/PackageManager/ProgressStrings.zig - setNodeName, startProgressBar, endProgressBar
// ============================================================================

/// 进度条管理器
/// 翻译自: ProgressStrings.zig 中的进度条辅助函数
public class ProgressBarManager {
    /// 启动进度条
    /// 翻译自: startProgressBar
    public static func start(manager: PackageManager): Unit {
        manager.downloadsNode = Some(ProgressNode())
        match (manager.downloadsNode) {
            case Some(node) => {
                node.name = ProgressStringsFull.download()
                node.estimatedTotalItems = manager.totalTasks + Int64(manager.extractedCount)
                node.completedItems = manager.totalTasks - manager.pendingTasks
            }
            case None => {}
        }
    }

    /// 如果没有进度条则启动
    /// 翻译自: startProgressBarIfNone
    public static func startIfNone(manager: PackageManager): Unit {
        match (manager.downloadsNode) {
            case Some(_) => {}  // 已存在
            case None => start(manager)
        }
    }

    /// 结束进度条
    /// 翻译自: endProgressBar
    public static func end(manager: PackageManager): Unit {
        match (manager.downloadsNode) {
            case Some(node) => {
                node.completedItems = node.estimatedTotalItems
                manager.downloadsNode = None
            }
            case None => {}
        }
    }

    /// 设置进度节点名称
    /// 翻译自: setNodeName
    public static func setNodeName(
        manager: PackageManager,
        node: ProgressNode,
        name: String,
        emoji: String
    ): Unit {
        node.name = "${emoji}${name}"
    }
}
