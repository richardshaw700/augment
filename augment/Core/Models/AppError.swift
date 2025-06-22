import Foundation

// MARK: - Application Errors
enum AppError: LocalizedError {
    case pythonExecutableNotFound(path: String)
    case scriptNotFound(path: String)
    case workingDirectoryNotFound(path: String)
    case processLaunchFailed(underlying: Error)
    case jsonParsingFailed(underlying: Error, json: String)
    case dataConversionFailed(content: String)
    case fileSystemError(underlying: Error, operation: String)
    case processTimeout(duration: TimeInterval)
    case invalidInstruction(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .pythonExecutableNotFound(let path):
            return "Python executable not found at: \(path)"
        case .scriptNotFound(let path):
            return "Script not found at: \(path)"
        case .workingDirectoryNotFound(let path):
            return "Working directory not found: \(path)"
        case .processLaunchFailed(let underlying):
            return "Failed to launch Python script: \(underlying.localizedDescription)"
        case .jsonParsingFailed(let underlying, let json):
            return "JSON parsing failed: \(underlying.localizedDescription). JSON: \(String(json.prefix(100)))"
        case .dataConversionFailed(let content):
            return "Failed to convert response to data: \(String(content.prefix(100)))"
        case .fileSystemError(let underlying, let operation):
            return "File system error during \(operation): \(underlying.localizedDescription)"
        case .processTimeout(let duration):
            return "Process timed out after \(duration) seconds"
        case .invalidInstruction(let reason):
            return "Invalid instruction: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .pythonExecutableNotFound:
            return "Please ensure the Python virtual environment is set up correctly and the python3 executable exists."
        case .scriptNotFound:
            return "Please verify that the main.py script exists in the expected location."
        case .workingDirectoryNotFound:
            return "Please check that the project directory exists and is accessible."
        case .processLaunchFailed:
            return "Try restarting the application or checking system permissions."
        case .jsonParsingFailed:
            return "This appears to be a data format issue. Try running the task again."
        case .dataConversionFailed:
            return "There was an issue processing the response. Please try again."
        case .fileSystemError:
            return "Check file permissions and available disk space."
        case .processTimeout:
            return "The operation took too long. Try breaking it into smaller tasks."
        case .invalidInstruction:
            return "Please provide a clear, specific instruction for the AI assistant."
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .pythonExecutableNotFound, .scriptNotFound, .workingDirectoryNotFound:
            return false // These are configuration issues
        case .processLaunchFailed, .jsonParsingFailed, .dataConversionFailed, .processTimeout, .invalidInstruction:
            return true // These can be retried
        case .fileSystemError:
            return true // Might be temporary
        }
    }
}

// MARK: - Error Extensions
extension AppError {
    static func logAndReturn(_ error: AppError, logger: FileLogger = .shared) -> AppError {
        logger.logError(error.localizedDescription)
        return error
    }
}