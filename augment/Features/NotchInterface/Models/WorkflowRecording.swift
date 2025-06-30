import Foundation
import SwiftUI

// MARK: - Simple Recording State
enum RecordingState: String, CaseIterable {
    case idle = "idle"
    case recording = "recording"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .idle: return "Record"
        case .recording: return "Stop"
        case .error: return "Record"  // Keep as Record, don't show Error
        }
    }
    
    var color: Color {
        switch self {
        case .idle: return .gray
        case .recording: return .red
        case .error: return .gray  // Keep normal color
        }
    }
    
    var icon: String {
        switch self {
        case .idle: return "record.circle"
        case .recording: return "stop.circle.fill"
        case .error: return "record.circle"  // Keep normal icon
        }
    }
}

// MARK: - Simple Recording Manager
class WorkflowRecordingManager: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var recordingState: RecordingState = .idle
    @Published var feedbackMessage: String = "Ready to record workflow"
    @Published var stepsRecorded: Int = 0
    
    private var pythonProcess: Process?
    private var outputPipe: Pipe?
    
    // MARK: - Public Methods
    func startRecording(workflowName: String) {
        guard !isRecording else { return }
        
        // Update UI immediately and force refresh
        isRecording = true
        recordingState = .recording
        feedbackMessage = "Initializing recorder..."
        stepsRecorded = 0
        
        // Force UI update
        objectWillChange.send()
        
        // Start Python workflow recorder in background
        DispatchQueue.global(qos: .userInitiated).async {
            self.startPythonRecorder(workflowName: workflowName)
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        // Update UI immediately and force refresh
        isRecording = false
        recordingState = .idle
        feedbackMessage = "Stopping recording..."
        
        // Force UI update
        objectWillChange.send()
        
        // Stop Python process in background
        DispatchQueue.global(qos: .userInitiated).async {
            self.stopPythonRecorder()
            
            DispatchQueue.main.async {
                self.feedbackMessage = "Recording stopped. \(self.stepsRecorded) steps recorded."
            }
        }
    }
    
    // MARK: - Private Methods
    private func startPythonRecorder(workflowName: String) {
        do {
            let scriptPath = getScriptPath()
            
            // Log the attempt for debugging
            print("🔍 Swift: Attempting to start Python recorder")
            print("🔍 Swift: Script path: \(scriptPath)")
            print("🔍 Swift: Project root: \(getProjectRoot())")
            
            pythonProcess = Process()
            outputPipe = Pipe()
            
            // Use the virtual environment Python
            let projectRoot = getProjectRoot()
            let pythonPath = "\(projectRoot)/venv/bin/python"
            
            // Log Python path for debugging
            print("🔍 Swift: Python path: \(pythonPath)")
            
            // Check if Python executable exists
            if !FileManager.default.fileExists(atPath: pythonPath) {
                let errorMsg = "Python executable not found at: \(pythonPath)"
                print("❌ Swift: \(errorMsg)")
                throw NSError(domain: "WorkflowRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
            
            pythonProcess?.executableURL = URL(fileURLWithPath: pythonPath)
            pythonProcess?.arguments = [
                scriptPath,
                "start"
            ]
            
            // Set working directory to the project root
            pythonProcess?.currentDirectoryURL = URL(fileURLWithPath: projectRoot)
            
            // Set up output handling
            pythonProcess?.standardOutput = outputPipe
            pythonProcess?.standardError = outputPipe
            
            // Monitor output with error handling
            if let outputPipe = outputPipe {
                outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    do {
                        let data = handle.availableData
                        if !data.isEmpty {
                            let output = String(data: data, encoding: .utf8) ?? ""
                            print("🔍 Swift: Python output: \(output)")
                            self?.processOutput(output)
                        }
                    } catch {
                        // Handle I/O errors gracefully to prevent UI error display
                        let errorMsg = "I/O error in workflow recorder: \(error.localizedDescription)"
                        print("❌ Swift: \(errorMsg)")
                        
                        // Log to Swift crash log file
                        self?.logError(errorMsg)
                        
                        DispatchQueue.main.async {
                            if let self = self, self.isRecording {
                                self.recordingState = .error
                                self.feedbackMessage = "Recording connection lost"
                                self.isRecording = false
                            }
                        }
                        // Clear the handler to prevent further errors
                        handle.readabilityHandler = nil
                    }
                }
            }
            
            print("🔍 Swift: Starting Python process...")
            try pythonProcess?.run()
            
            DispatchQueue.main.async {
                self.feedbackMessage = "Recording started..."
            }
            
        } catch {
            let errorMsg = "Error starting recorder: \(error.localizedDescription)"
            print("❌ Swift: \(errorMsg)")
            
            // Log to Swift crash log file
            logError(errorMsg)
            
            DispatchQueue.main.async {
                self.recordingState = .error
                self.feedbackMessage = errorMsg
                self.isRecording = false
            }
        }
    }
    
    private func stopPythonRecorder() {
        // Close output handler first to prevent I/O errors
        if let outputPipe = outputPipe {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            do {
                try outputPipe.fileHandleForReading.close()
            } catch {
                // Ignore close errors as the pipe may already be closed
            }
        }
        
        // Send stop command to the Python process
        if let process = pythonProcess, process.isRunning {
            // Send SIGTERM to gracefully stop the recording
            process.terminate()
            
            // Wait a bit for graceful shutdown
            DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                if process.isRunning {
                    // Force kill if still running
                    process.terminate()
                }
            }
        }
        
        pythonProcess = nil
        outputPipe = nil
    }
    
    private func processOutput(_ output: String) {
        // Process simple text output from the Python bridge
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { continue }
            
            DispatchQueue.main.async {
                // Update feedback based on output
                if trimmedLine.contains("Recording started successfully") {
                    self.recordingState = .recording
                    self.isRecording = true
                    self.feedbackMessage = "Recording workflow actions..."
                } else if trimmedLine.contains("Recording stopped successfully") {
                    self.recordingState = .idle
                    self.isRecording = false
                    self.feedbackMessage = "Recording completed"
                } else if trimmedLine.contains("Recorded:") {
                    // Extract step count from recorded events
                    self.stepsRecorded += 1
                    self.feedbackMessage = "Recording... \(self.stepsRecorded) actions captured"
                } else if trimmedLine.contains("Input Monitoring permissions") {
                    self.handlePermissionError(trimmedLine)
                } else if trimmedLine.contains("❌") || trimmedLine.contains("Error") {
                    if !trimmedLine.contains("DEBUG") { // Ignore debug messages
                        self.recordingState = .error
                        self.feedbackMessage = "Recording error - check terminal"
                        self.isRecording = false
                    }
                } else if trimmedLine.contains("✅") && trimmedLine.contains("started") {
                    self.feedbackMessage = "Recording system ready..."
                }
            }
        }
    }
    
    private func updateFromJSON(_ json: [String: Any]) {
        // This method is no longer needed with the simplified bridge
        // but keeping it for compatibility
    }
    
    private func getScriptPath() -> String {
        let projectRoot = getProjectRoot()
        return "\(projectRoot)/src/workflow_automation/workflow_recorder_bridge.py"
    }
    
    private func getProjectRoot() -> String {
        // Get the bundle path and work backwards to find project root
        let bundlePath = Bundle.main.bundlePath
        let bundleURL = URL(fileURLWithPath: bundlePath)
        
        // Go up from .app to find the project root
        var currentURL = bundleURL.deletingLastPathComponent()
        
        // Look for characteristic files that indicate project root
        let projectMarkers = ["src", "augment", "Makefile", "requirements.txt"]
        
        for _ in 0..<5 { // Don't go up more than 5 levels
            let hasMarkers = projectMarkers.allSatisfy { marker in
                FileManager.default.fileExists(atPath: currentURL.appendingPathComponent(marker).path)
            }
            
            if hasMarkers {
                return currentURL.path
            }
            
            currentURL = currentURL.deletingLastPathComponent()
        }
        
        // Fallback to current directory
        return FileManager.default.currentDirectoryPath
    }
    
    private func handlePermissionError(_ message: String) {
        // Automatically stop recording
        self.isRecording = false
        self.recordingState = .error
        
        // Show clear error message in UI and lock it in
        self.feedbackMessage = "🔐 Input Monitoring permissions required"
        
        // Force UI update immediately
        objectWillChange.send()
        
        // Stop the Python process since it can't continue
        DispatchQueue.global().async {
            self.stopPythonRecorder()
        }
        
        print("🔐 PERMISSION ERROR: \(message)")
        print("📝 Please grant input monitoring permissions in System Preferences > Privacy & Security > Input Monitoring")
        print("📱 To grant permissions:")
        print("   1. Open System Preferences")
        print("   2. Go to Privacy & Security > Input Monitoring")
        print("   3. Click the '+' button")
        print("   4. Add the Augment app")
        print("   5. Try recording again")
    }
    
    // Add logging method
    private func logError(_ message: String) {
        // Create crash log file if it doesn't exist
        let crashLogPath = AppConstants.Paths.swiftCrashLog
        let timestamp = DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] WORKFLOW_RECORDER_ERROR: \(message)\n"
        
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: crashLogPath) {
                if let fileHandle = FileHandle(forWritingAtPath: crashLogPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: crashLogPath))
            }
        }
    }
}

 