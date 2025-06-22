import Foundation

// MARK: - Process Manager
class ProcessManager {
    private let logger: FileLogger
    
    init(logger: FileLogger = .shared) {
        self.logger = logger
    }
    
    // MARK: - Process Creation
    func createProcess(instruction: String) throws -> (Process, Pipe, Pipe) {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        // Configure process
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.executableURL = URL(fileURLWithPath: AppConstants.Paths.pythonExecutable)
        task.arguments = [
            AppConstants.Process.pythonUnbufferedFlag,
            AppConstants.Paths.mainScript,
            AppConstants.Process.taskArgumentFlag,
            instruction
        ]
        
        // Set working directory
        task.currentDirectoryURL = URL(fileURLWithPath: AppConstants.Paths.projectRoot)
        
        // Configure environment
        var environment = Foundation.ProcessInfo.processInfo.environment
        environment["PYTHONPATH"] = AppConstants.Paths.pythonPath
        task.environment = environment
        
        // Log process configuration
        logProcessConfiguration(task: task, environment: environment)
        
        return (task, outputPipe, errorPipe)
    }
    
    // MARK: - Process Management
    func terminateProcess(_ process: Process) {
        guard process.isRunning else { return }
        
        logger.log("🛑 Terminating process (PID: \(process.processIdentifier))")
        
        // Graceful termination
        process.terminate()
        
        // Force kill if needed
        DispatchQueue.global().asyncAfter(deadline: .now() + AppConstants.Process.terminationGraceTime) {
            if process.isRunning {
                self.logger.log("🔪 Force killing process (PID: \(process.processIdentifier))")
                process.interrupt()
            }
        }
    }
    
    // MARK: - Validation
    func validateExecutionEnvironment() throws {
        let fileManager = FileManager.default
        
        // Check Python executable
        guard fileManager.fileExists(atPath: AppConstants.Paths.pythonExecutable) else {
            throw AppError.pythonExecutableNotFound(path: AppConstants.Paths.pythonExecutable)
        }
        
        // Check script
        guard fileManager.fileExists(atPath: AppConstants.Paths.mainScript) else {
            throw AppError.scriptNotFound(path: AppConstants.Paths.mainScript)
        }
        
        // Check working directory
        guard fileManager.fileExists(atPath: AppConstants.Paths.projectRoot) else {
            throw AppError.workingDirectoryNotFound(path: AppConstants.Paths.projectRoot)
        }
        
        // Verify Python executable is actually executable
        guard fileManager.isExecutableFile(atPath: AppConstants.Paths.pythonExecutable) else {
            throw AppError.pythonExecutableNotFound(path: AppConstants.Paths.pythonExecutable)
        }
    }
    
    // MARK: - Utility Methods
    func getProcessInfo(for process: Process) -> ProcessStatus {
        return ProcessStatus(
            pid: process.processIdentifier,
            isRunning: process.isRunning,
            terminationStatus: process.isRunning ? nil : process.terminationStatus,
            terminationReason: process.isRunning ? nil : process.terminationReason
        )
    }
    
    // MARK: - Private Methods
    private func logProcessConfiguration(task: Process, environment: [String: String]) {
        logger.log("🚀 About to start process with arguments: \(task.arguments ?? [])")
        logger.log("🔧 Environment PYTHONPATH: \(environment["PYTHONPATH"] ?? "not set")")
        logger.log("🔧 Working Directory: \(task.currentDirectoryURL?.path ?? "not set")")
    }
}

// MARK: - Process Status Structure
struct ProcessStatus {
    let pid: Int32
    let isRunning: Bool
    let terminationStatus: Int32?
    let terminationReason: Process.TerminationReason?
    
    var description: String {
        if isRunning {
            return "Running (PID: \(pid))"
        } else {
            let status = terminationStatus ?? -1
            let reason = terminationReason?.description ?? "unknown"
            return "Terminated (PID: \(pid), Status: \(status), Reason: \(reason))"
        }
    }
}

// MARK: - Process Extensions
extension Process.TerminationReason {
    var description: String {
        switch self {
        case .exit:
            return "exit"
        case .uncaughtSignal:
            return "uncaught signal"
        @unknown default:
            return "unknown"
        }
    }
}