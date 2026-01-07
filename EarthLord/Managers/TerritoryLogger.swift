//
//  TerritoryLogger.swift
//  EarthLord
//
//  Created by Claude Code on 2026/1/7.
//

import Foundation
import SwiftUI
import Combine

/// 圈地功能日志管理器
/// 用于在真机测试时查看圈地模块的运行状态
class TerritoryLogger: ObservableObject {
    /// 单例
    static let shared = TerritoryLogger()

    // MARK: - Published Properties

    /// 日志条目数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于显示）
    @Published var logText: String = ""

    // MARK: - Private Properties

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 200

    /// 日期格式化器（显示用）
    private let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// 日期格式化器（导出用）
    private let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // MARK: - Initialization

    private init() {
        log("日志系统已初始化", type: .info)
    }

    // MARK: - Public Methods

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型
    func log(_ message: String, type: LogType = .info) {
        // 确保在主线程更新
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 创建日志条目
            let entry = LogEntry(message: message, type: type)

            // 添加到数组
            self.logs.append(entry)

            // 限制最大条数
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst()
            }

            // 更新格式化文本
            self.updateLogText()

            // 打印到控制台（方便调试）
            print("[\(type.emoji)] \(message)")
        }
    }

    /// 清空所有日志
    func clear() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.logs.removeAll()
            self.logText = ""
            print("🗑️ 日志已清空")
        }
    }

    /// 导出日志为文本
    /// - Returns: 包含头信息和所有日志的文本
    func export() -> String {
        var result = ""

        // 添加头信息
        result += "=== 圈地功能测试日志 ===\n"
        result += "导出时间: \(exportDateFormatter.string(from: Date()))\n"
        result += "日志条数: \(logs.count)\n"
        result += "\n"

        // 添加日志内容
        for entry in logs {
            let timeString = exportDateFormatter.string(from: entry.timestamp)
            result += "[\(timeString)] [\(entry.type.rawValue.uppercased())] \(entry.message)\n"
        }

        return result
    }

    // MARK: - Private Methods

    /// 更新格式化的日志文本
    private func updateLogText() {
        var text = ""

        for entry in logs {
            let timeString = displayDateFormatter.string(from: entry.timestamp)
            let typeString = entry.type.displayString
            text += "[\(timeString)] \(typeString) \(entry.message)\n"
        }

        logText = text
    }
}

// MARK: - Log Entry

/// 日志条目
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let message: String
    let type: LogType
}

// MARK: - Log Type

/// 日志类型
enum LogType: String {
    case info = "info"
    case success = "success"
    case warning = "warning"
    case error = "error"

    /// 显示字符串
    var displayString: String {
        switch self {
        case .info:
            return "[INFO]"
        case .success:
            return "[✅ SUCCESS]"
        case .warning:
            return "[⚠️ WARNING]"
        case .error:
            return "[❌ ERROR]"
        }
    }

    /// emoji 表情（用于控制台打印）
    var emoji: String {
        switch self {
        case .info:
            return "ℹ️"
        case .success:
            return "✅"
        case .warning:
            return "⚠️"
        case .error:
            return "❌"
        }
    }

    /// 颜色（用于 UI 显示）
    var color: Color {
        switch self {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
