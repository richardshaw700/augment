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
            self.errorOutput = ""
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
                accumulatedError += errorChunk
                self.logger.log("GPT Error: \(errorChunk.trimmingCharacters(in: .whitespacesAndNewlines))")
                
                // Write Python errors to debug output as well
                self.writePythonErrorToDebugOutput(errorChunk)
                
                DispatchQueue.main.async {
                    self.errorOutput = accumulatedError
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
                accumulatedError += finalErrorChunk
                
                // Write final Python errors to debug output as well
                self.writePythonErrorToDebugOutput(finalErrorChunk)
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
        let fullErrorMessage = error.localizedDescription
        logger.logError(fullErrorMessage)
        
        // Write full error details to debug_output
        writeFullErrorToDebugOutput(fullErrorMessage)
        
        DispatchQueue.main.async {
            self.errorOutput = fullErrorMessage
            self.isRunning = false
            self.status = "Error"
        }
    }
    
    private func writeFullErrorToDebugOutput(_ errorMessage: String) {
        let timestamp = DateFormatter().string(from: Date())
        let fullErrorEntry = """
        =====================================
        ERROR LOGGED AT: \(timestamp)
        =====================================
        \(errorMessage)
        =====================================
        
        """
        
        // Ensure debug output directory exists
        let debugDir = AppConstants.Paths.debugOutputDirectory
        do {
            try FileManager.default.createDirectory(atPath: debugDir, withIntermediateDirectories: true, attributes: nil)
            
            // Write to error details file
            let errorLogPath = AppConstants.Debug.fullErrorLogPath
            if let errorData = fullErrorEntry.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: errorLogPath) {
                    if let fileHandle = FileHandle(forWritingAtPath: errorLogPath) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(errorData)
                        fileHandle.closeFile()
                    }
                } else {
                    FileManager.default.createFile(atPath: errorLogPath, contents: errorData, attributes: nil)
                }
            }
        } catch {
            logger.logError("Failed to write error to debug output: \(error.localizedDescription)")
        }
    }
    
    private func writePythonErrorToDebugOutput(_ errorMessage: String) {
        let timestamp = DateFormatter().string(from: Date())
        let pythonErrorEntry = """
        =====================================
        PYTHON ERROR LOGGED AT: \(timestamp)
        =====================================
        \(errorMessage)
        =====================================
        
        """
        
        // Ensure debug output directory exists
        let debugDir = AppConstants.Paths.debugOutputDirectory
        do {
            try FileManager.default.createDirectory(atPath: debugDir, withIntermediateDirectories: true, attributes: nil)
            
            // Write to Python error details file
            let pythonErrorLogPath = AppConstants.Debug.pythonErrorLogPath
            if let pythonErrorData = pythonErrorEntry.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: pythonErrorLogPath) {
                    if let fileHandle = FileHandle(forWritingAtPath: pythonErrorLogPath) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(pythonErrorData)
                        fileHandle.closeFile()
                    }
                } else {
                    FileManager.default.createFile(atPath: pythonErrorLogPath, contents: pythonErrorData, attributes: nil)
                }
            }
        } catch {
            logger.logError("Failed to write Python error to debug output: \(error.localizedDescription)")
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