//
//  TerritoryLogger.swift
//  EarthLord
//
//  圈地功能日志管理器 - 用于真机测试时查看调试日志
//

import Foundation
import Combine

/// 日志类型枚举
enum LogType: String {
    case info = "INFO"
    case success = "SUCCESS"
    case warning = "WARNING"
    case error = "ERROR"
}

/// 日志条目结构
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType
}

/// 圈地功能日志管理器
/// 单例模式 + ObservableObject，用于在 App 内显示调试日志
class TerritoryLogger: ObservableObject {

    // MARK: - 单例

    static let shared = TerritoryLogger()

    // MARK: - Published Properties

    /// 日志数组
    @Published var logs: [LogEntry] = []

    /// 格式化的日志文本（用于 UI 显示）
    @Published var logText: String = ""

    // MARK: - Private Properties

    /// 最大日志条数（防止内存溢出）
    private let maxLogCount = 200

    /// 显示格式的时间格式化器
    private let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    /// 导出格式的时间格式化器
    private let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 添加日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - type: 日志类型（默认 .info）
    func log(_ message: String, type: LogType = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, type: type)

        // 确保在主线程更新
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 添加新日志
            self.logs.append(entry)

            // 限制最大条数，移除最旧的日志
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst(self.logs.count - self.maxLogCount)
            }

            // 更新格式化文本
            self.updateLogText()
        }

        // 同时输出到控制台（方便 Xcode 调试）
        print("[\(type.rawValue)] \(message)")
    }

    /// 清空所有日志
    func clear() {
        DispatchQueue.main.async { [weak self] in
            self?.logs.removeAll()
            self?.logText = ""
        }
    }

    /// 导出日志为文本
    /// - Returns: 包含头信息的完整日志文本
    func export() -> String {
        var output = "=== 圈地功能测试日志 ===\n"
        output += "导出时间: \(exportFormatter.string(from: Date()))\n"
        output += "日志条数: \(logs.count)\n"
        output += "\n"

        for entry in logs {
            let time = exportFormatter.string(from: entry.timestamp)
            output += "[\(time)] [\(entry.type.rawValue)] \(entry.message)\n"
        }

        return output
    }

    // MARK: - Private Methods

    /// 更新格式化的日志文本
    private func updateLogText() {
        var text = ""
        for entry in logs {
            let time = displayFormatter.string(from: entry.timestamp)
            text += "[\(time)] [\(entry.type.rawValue)] \(entry.message)\n"
        }
        logText = text
    }
}
