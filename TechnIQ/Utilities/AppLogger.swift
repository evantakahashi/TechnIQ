//
//  AppLogger.swift
//  TechnIQ
//
//  Production-ready logging system
//

import Foundation
import os.log

/// Production-ready logging system that uses OSLog
/// - In DEBUG: Logs to console
/// - In RELEASE: Only logs errors to system log (viewable in Console.app)
class AppLogger {
    static let shared = AppLogger()

    private let subsystem = Bundle.main.bundleIdentifier ?? "com.techniq.app"

    // Category-specific loggers
    private lazy var authLogger = OSLog(subsystem: subsystem, category: "Authentication")
    private lazy var dataLogger = OSLog(subsystem: subsystem, category: "CoreData")
    private lazy var networkLogger = OSLog(subsystem: subsystem, category: "Network")
    private lazy var mlLogger = OSLog(subsystem: subsystem, category: "MachineLearning")
    private lazy var uiLogger = OSLog(subsystem: subsystem, category: "UI")
    private lazy var generalLogger = OSLog(subsystem: subsystem, category: "General")

    private init() {}

    enum Category {
        case auth
        case data
        case network
        case ml
        case ui
        case general

        var emoji: String {
            switch self {
            case .auth: return "🔐"
            case .data: return "💾"
            case .network: return "🌐"
            case .ml: return "🤖"
            case .ui: return "🎨"
            case .general: return "ℹ️"
            }
        }
    }

    enum Level {
        case debug
        case info
        case warning
        case error

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            }
        }
    }

    // MARK: - Public Logging Methods

    /// Log a debug message (only in DEBUG builds)
    func debug(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(message, level: .debug, category: category, file: file, function: function, line: line)
        #endif
    }

    /// Log an info message
    func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(message, level: .info, category: category, file: file, function: function, line: line)
        #endif
    }

    /// Log a warning message
    func warning(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    /// Log an error message (always logged, even in production)
    func error(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    // MARK: - Private Implementation

    private func log(_ message: String, level: Level, category: Category, file: String, function: String, line: Int) {
        let logger = getLogger(for: category)
        let fileName = (file as NSString).lastPathComponent
        let formattedMessage = "\(category.emoji) [\(fileName):\(line)] \(function) - \(message)"

        os_log("%{public}@", log: logger, type: level.osLogType, formattedMessage)
    }

    private func getLogger(for category: Category) -> OSLog {
        switch category {
        case .auth: return authLogger
        case .data: return dataLogger
        case .network: return networkLogger
        case .ml: return mlLogger
        case .ui: return uiLogger
        case .general: return generalLogger
        }
    }
}

// MARK: - Convenience Global Functions

/// Log debug message (only in DEBUG builds)
func logDebug(_ message: String, category: AppLogger.Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.debug(message, category: category, file: file, function: function, line: line)
}

/// Log info message
func logInfo(_ message: String, category: AppLogger.Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.info(message, category: category, file: file, function: function, line: line)
}

/// Log warning message
func logWarning(_ message: String, category: AppLogger.Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.warning(message, category: category, file: file, function: function, line: line)
}

/// Log error message (always logged, even in production)
func logError(_ message: String, category: AppLogger.Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.error(message, category: category, file: file, function: function, line: line)
}
