import Foundation
import Combine

// MARK: - GPT Service
class GPTService: ObservableObject {
    @Published var isRunning = false
    @Published var output = ""
    @Published var errorOutput = ""
    @Published var status = "Ready"
    
    private let processManager: ProcessManager
    private let logger: FileLogger
    private var currentTask: Process?
    private var outputSource: DispatchSourceRead?
    private var errorSource: DispatchSourceRead?
    
    init(processManager: ProcessManager = ProcessManager(), logger: FileLogger = .shared) {
        self.processManager = processManager
        self.logger = logger
        
        logger.logHeader("Swift Frontend Debug Log Initialized")
        logger.log("Python Path: \(AppConstants.Paths.pythonExecutable)")
        logger.log("Script Path: \(AppConstants.Paths.mainScript)")
        logger.log("Debug Log Path: \(AppConstants.Paths.swiftFrontendLog)")
    }
    
    // MARK: - Public Methods
    func executeInstruction(_ instruction: String) {
        guard !isRunning else { return }
        guard !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            handleError(.invalidInstruction(reason: "Instruction cannot be empty"))
            return
        }
        
        // Update UI state immediately on main thread
        DispatchQueue.main.async {
            self.isRunning = true
            self.status = "Starting..."
            self.output = ""
            self.errorOutput = "" // Clear any previous error messages
        }
        
        logExecutionStart(instruction)
        
        do {
            try validateEnvironment()
            executeInBackground(instruction)
        } catch let error as AppError {
            handleError(error)
        } catch {
            handleError(.processLaunchFailed(underlying: error))
        }
    }
    
    func stopExecution() {
        guard isRunning else { return }
        
        // Update UI state immediately to show stopping
        DispatchQueue.main.async {
            self.status = "Stopping..."
            self.isRunning = false
        }
        
        // Cancel dispatch sources first
        outputSource?.cancel()
        errorSource?.cancel()
        
        // Terminate the process
        if let task = currentTask {
            processManager.terminateProcess(task)
        }
        
        logger.log("⏹️ Execution stopped by user")
        
        // Final UI state update
        DispatchQueue.main.async {
            self.updateUIState(
                status: "Stopped by user",
                isRunning: false,
                currentTask: nil,
                outputSource: nil,
                errorSource: nil
            )
        }
    }
    
    // MARK: - Private Methods
    private func validateEnvironment() throws {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: AppConstants.Paths.pythonExecutable) {
            throw AppError.pythonExecutableNotFound(path: AppConstants.Paths.pythonExecutable)
        }
        
        if !fileManager.fileExists(atPath: AppConstants.Paths.mainScript) {
            throw AppError.scriptNotFound(path: AppConstants.Paths.mainScript)
        }
        
        if !fileManager.fileExists(atPath: AppConstants.Paths.projectRoot) {
            throw AppError.workingDirectoryNotFound(path: AppConstants.Paths.projectRoot)
        }
        
        logger.log("✅ All paths verified - starting process")
    }
    
    private func executeInBackground(_ instruction: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let (task, outputPipe, errorPipe) = try self.processManager.createProcess(instruction: instruction)
                self.currentTask = task
                
                self.logger.log("✅ Process started successfully (PID: \(task.processIdentifier))")
                
                // Update UI to show execution started
                DispatchQueue.main.async {
                    self.status = "Executing..."
                }
                
                self.setupRealtimeOutput(task: task, outputPipe: outputPipe, errorPipe: errorPipe)
                
                try task.run()
                task.waitUntilExit()
                
                // Cancel dispatch sources when task completes
                self.outputSource?.cancel()
                self.errorSource?.cancel()
                
            } catch {
                self.handleError(.processLaunchFailed(underlying: error))
            }
        }
    }
    
    private func setupRealtimeOutput(task: Process, outputPipe: Pipe, errorPipe: Pipe) {
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        
        var accumulatedOutput = ""
        var accumulatedError = ""
        
        // Set up real-time output reading
        outputSource = DispatchSource.makeReadSource(
            fileDescriptor: outputHandle.fileDescriptor,
            queue: DispatchQueue.global(qos: .userInitiated)
        )
        
        errorSource = DispatchSource.makeReadSource(
            fileDescriptor: errorHandle.fileDescriptor,
            queue: DispatchQueue.global(qos: .userInitiated)
        )
        
        outputSource?.setEventHandler {
            let data = outputHandle.availableData
            if !data.isEmpty, let chunk = String(data: data, encoding: .utf8) {
                accumulatedOutput += chunk
                self.logger.log("GPT Output: \(chunk.trimmingCharacters(in: .whitespacesAndNewlines))")
                DispatchQueue.main.async {
                    self.output = accumulatedOutput
                }
            }
        }
        
        errorSource?.setEventHandler {
            let errorData = errorHandle.availableData
            if !errorData.isEmpty, let errorChunk = String(data: errorData, encoding: .utf8) {
                // Filter out known warnings that shouldn't be treated as errors
                let isWarning = errorChunk.contains("NotOpenSSLWarning") || 
                               errorChunk.contains("urllib3") ||
                               errorChunk.contains("warnings.warn") ||
                               errorChunk.lowercased().contains("warning:")
                
                if isWarning {
                    // Log warnings but don't add to error output that shows in UI
                    self.logger.log("GPT Warning: \(errorChunk.trimmingCharacters(in: .whitespacesAndNewlines))")
                } else {
                    // Only treat actual errors as errors
                    accumulatedError += errorChunk
                    self.logger.log("GPT Error: \(errorChunk.trimmingCharacters(in: .whitespacesAndNewlines))")
                    DispatchQueue.main.async {
                        self.errorOutput = accumulatedError
                    }
                }
            }
        }
        
        outputSource?.setCancelHandler {
            let finalOutputData = outputHandle.readDataToEndOfFile()
            if !finalOutputData.isEmpty, let finalChunk = String(data: finalOutputData, encoding: .utf8) {
                accumulatedOutput += finalChunk
            }
            
            DispatchQueue.main.async {
                // Check if task is still running before accessing terminationStatus
                let statusMsg: String
                if task.isRunning {
                    statusMsg = "Stopped"
                    self.logger.log("⏹️ Task stopped while running")
                } else {
                    statusMsg = task.terminationStatus == 0 ? "Completed Successfully" : "Completed with Errors"
                    self.logger.log("✅ Task \(statusMsg.lowercased()) (exit code: \(task.terminationStatus))")
                }
                
                self.updateUIState(
                    status: statusMsg,
                    isRunning: false,
                    currentTask: nil,
                    outputSource: nil,
                    errorSource: nil
                )
                self.output = accumulatedOutput
            }
        }
        
        errorSource?.setCancelHandler {
            let finalErrorData = errorHandle.readDataToEndOfFile()
            if !finalErrorData.isEmpty, let finalErrorChunk = String(data: finalErrorData, encoding: .utf8) {
                // Apply the same warning filtering to final error data
                let isWarning = finalErrorChunk.contains("NotOpenSSLWarning") || 
                               finalErrorChunk.contains("urllib3") ||
                               finalErrorChunk.contains("warnings.warn") ||
                               finalErrorChunk.lowercased().contains("warning:")
                
                if !isWarning {
                    accumulatedError += finalErrorChunk
                }
            }
            
            DispatchQueue.main.async {
                self.errorOutput = accumulatedError
            }
        }
        
        outputSource?.resume()
        errorSource?.resume()
    }
    
    private func logExecutionStart(_ instruction: String) {
        logger.log("")
        logger.log("🚀 Starting GPT Computer Use")
        logger.log("📝 Task: \(instruction)")
        logger.log("🐍 Python Path: \(AppConstants.Paths.pythonExecutable)")
        logger.log("📄 Script Path: \(AppConstants.Paths.mainScript)")
        logger.log("📁 Working Directory: \(AppConstants.Paths.projectRoot)")
        logger.log("💰 Cost Mode: \(ProcessInfo.processInfo.environment["COST_OPTIMIZATION"] ?? "default")")
        logger.logSeparator()
    }
    
    private func handleError(_ error: AppError) {
        logger.logError(error.localizedDescription)
        DispatchQueue.main.async {
            self.errorOutput = error.localizedDescription
            self.isRunning = false
            self.status = "Error"
        }
    }
    
    private func updateUIState(
        status: String,
        isRunning: Bool,
        currentTask: Process?,
        outputSource: DispatchSourceRead?,
        errorSource: DispatchSourceRead?
    ) {
        self.status = status
        self.isRunning = isRunning
        self.currentTask = currentTask
        self.outputSource = outputSource
        self.errorSource = errorSource
    }
}