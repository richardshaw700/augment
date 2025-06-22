import Foundation

// MARK: - Task Status Model
enum TaskStatus: String, CaseIterable, Equatable {
    case ready = "Ready"
    case executing = "Executing..."
    case thinking = "Thinking..."
    case completedSuccessfully = "Completed Successfully"
    case completedWithErrors = "Completed with Errors"
    case error = "Error"
    case stoppedByUser = "Stopped by user"
    case timeout = "Timeout"
    
    // MARK: - Properties
    var isActive: Bool {
        switch self {
        case .executing, .thinking:
            return true
        case .ready, .completedSuccessfully, .completedWithErrors, .error, .stoppedByUser, .timeout:
            return false
        }
    }
    
    var isCompleted: Bool {
        switch self {
        case .completedSuccessfully, .completedWithErrors:
            return true
        case .ready, .executing, .thinking, .error, .stoppedByUser, .timeout:
            return false
        }
    }
    
    var isError: Bool {
        switch self {
        case .error, .timeout:
            return true
        case .ready, .executing, .thinking, .completedSuccessfully, .completedWithErrors, .stoppedByUser:
            return false
        }
    }
    
    var isSuccess: Bool {
        self == .completedSuccessfully
    }
    
    var colorName: String {
        switch self {
        case .ready, .completedSuccessfully:
            return "green"
        case .executing, .thinking:
            return "orange"
        case .error, .timeout:
            return "red"
        case .completedWithErrors, .stoppedByUser:
            return "yellow"
        }
    }
    
    var icon: String {
        switch self {
        case .ready:
            return "checkmark.circle"
        case .executing:
            return "hourglass"
        case .thinking:
            return "brain.head.profile"
        case .completedSuccessfully:
            return "checkmark.circle.fill"
        case .completedWithErrors:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .stoppedByUser:
            return "stop.circle.fill"
        case .timeout:
            return "clock.badge.exclamationmark"
        }
    }
    
    // MARK: - Factory Methods
    static func from(terminationStatus: Int32) -> TaskStatus {
        switch terminationStatus {
        case 0:
            return .completedSuccessfully
        default:
            return .completedWithErrors
        }
    }
    
    static func from(errorMessage: String?) -> TaskStatus {
        guard let error = errorMessage, !error.isEmpty else {
            return .ready
        }
        
        if error.lowercased().contains("timeout") {
            return .timeout
        } else if error.lowercased().contains("stopped") {
            return .stoppedByUser
        } else {
            return .error
        }
    }
}

// MARK: - Task Progress Model
struct TaskProgress {
    let status: TaskStatus
    let message: String?
    let progress: Double? // 0.0 to 1.0
    let startTime: Date?
    let endTime: Date?
    
    init(status: TaskStatus, message: String? = nil, progress: Double? = nil, startTime: Date? = nil, endTime: Date? = nil) {
        self.status = status
        self.message = message
        self.progress = progress
        self.startTime = startTime
        self.endTime = endTime
    }
    
    var duration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }
    
    var isRunning: Bool {
        status.isActive && endTime == nil
    }
    
    var displayMessage: String {
        message ?? status.rawValue
    }
}

// MARK: - Task Result Model
struct TaskResult {
    let status: TaskStatus
    let output: String
    let errorOutput: String
    let duration: TimeInterval?
    let timestamp: Date
    
    init(status: TaskStatus, output: String = "", errorOutput: String = "", duration: TimeInterval? = nil, timestamp: Date = Date()) {
        self.status = status
        self.output = output
        self.errorOutput = errorOutput
        self.duration = duration
        self.timestamp = timestamp
    }
    
    var hasOutput: Bool {
        !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var hasErrors: Bool {
        !errorOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var isSuccessful: Bool {
        status.isSuccess && !hasErrors
    }
    
    var summary: String {
        var parts: [String] = []
        
        if hasOutput {
            parts.append("Output: \(output.count) chars")
        }
        
        if hasErrors {
            parts.append("Errors: \(errorOutput.count) chars")
        }
        
        if let duration = duration {
            parts.append("Duration: \(String(format: "%.2f", duration))s")
        }
        
        return parts.joined(separator: ", ")
    }
}