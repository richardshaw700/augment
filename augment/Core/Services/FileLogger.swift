import Foundation

// MARK: - File Logger Service
class FileLogger {
    static let shared = FileLogger()
    
    private let dateFormatter: DateFormatter
    private let fileManager = FileManager.default
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = AppConstants.Debug.timestampFormat
        
        // Ensure debug directory exists
        ensureDebugDirectoryExists()
    }
    
    // MARK: - Public Methods
    func log(_ message: String, to logType: LogType = .frontend, level: LogLevel = .info) {
        let timestamp = dateFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] \(level.prefix) \(message)\n"
        
        // Print to console
        print(logEntry, terminator: "")
        
        // Write to file asynchronously
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.writeToFile(logEntry, logType: logType)
        }
    }
    
    func logError(_ message: String, to logType: LogType = .crashLog) {
        log("🚨 CRASH PREVENTION: \(message)", to: logType, level: .error)
    }
    
    func logDebug(_ message: String, to logType: LogType = .chatDebug) {
        log("🔍 DEBUG: \(message)", to: logType, level: .debug)
    }
    
    func logSeparator(to logType: LogType = .frontend) {
        let separator = "─────────────────────────────────────────────────"
        log(separator, to: logType, level: .info)
    }
    
    func logHeader(_ title: String, to logType: LogType = .frontend) {
        let header = """
        
        === \(title) ===
        Timestamp: \(dateFormatter.string(from: Date()))
        ================================================
        """
        log(header, to: logType, level: .info)
    }
    
    // MARK: - Private Methods
    private func ensureDebugDirectoryExists() {
        let debugDir = URL(fileURLWithPath: AppConstants.Paths.debugOutputDirectory)
        try? fileManager.createDirectory(at: debugDir, withIntermediateDirectories: true)
    }
    
    private func writeToFile(_ content: String, logType: LogType) {
        guard let data = content.data(using: .utf8) else { return }
        
        let filePath = logType.filePath
        
        if fileManager.fileExists(atPath: filePath) {
            // Append to existing file
            if let fileHandle = FileHandle(forWritingAtPath: filePath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            // Create new file
            do {
                try data.write(to: URL(fileURLWithPath: filePath))
            } catch {
                print("Failed to write log to \(filePath): \(error)")
            }
        }
    }
}

// MARK: - Log Types
extension FileLogger {
    enum LogType {
        case frontend
        case crashLog
        case chatDebug
        
        var filePath: String {
            switch self {
            case .frontend:
                return AppConstants.Paths.swiftFrontendLog
            case .crashLog:
                return AppConstants.Paths.swiftCrashLog
            case .chatDebug:
                return AppConstants.Paths.chatDebugLog
            }
        }
    }
    
    enum LogLevel {
        case info
        case debug
        case warning
        case error
        
        var prefix: String {
            switch self {
            case .info: return ""
            case .debug: return "[DEBUG]"
            case .warning: return "[WARNING]"
            case .error: return "[ERROR]"
            }
        }
    }
}