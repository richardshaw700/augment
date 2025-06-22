//
//  ContentView.swift
//  augment
//
//  Created by Richard Shaw on 2025-06-19.
//

import SwiftUI
import Foundation

// Helper function to generate timestamps with milliseconds
func getCurrentTimestamp() -> String {
    let now = Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter.string(from: now)
}

class GPTComputerUseManager: ObservableObject {
    @Published var isRunning = false
    @Published var output = ""
    @Published var errorOutput = ""
    @Published var status = "Ready"
    
    private let pythonPath: String
    private let scriptPath: String
    private var currentTask: Process?
    private var outputSource: DispatchSourceRead?
    private var errorSource: DispatchSourceRead?
    
    init() {
        // Get the project directory path - updated to use new GPT system
        let projectPath = "/Users/richardshaw/augment"
        self.pythonPath = "\(projectPath)/venv/bin/python3"  // Use virtual environment python
        self.scriptPath = "\(projectPath)/src/main.py"  // Use main.py which has proper LLM configuration
    }
    
    func executeInstruction(_ instruction: String) {
        guard !isRunning else { return }
        
        isRunning = true
        status = "Executing..."
        output = ""
        errorOutput = ""
        
        // Print to console when starting
        let timestamp = getCurrentTimestamp()
        print("\n[\(timestamp)] 🚀 Starting GPT Computer Use")
        print("[\(timestamp)] 📝 Task: \(instruction)")
        print("[\(timestamp)] 💰 Cost Mode: \(ProcessInfo.processInfo.environment["COST_OPTIMIZATION"] ?? "default")")
        print("[\(timestamp)] ─────────────────────────────────────────────────")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            task.executableURL = URL(fileURLWithPath: self.pythonPath)
            task.arguments = ["-u", self.scriptPath, "--task", instruction]
            
            // Set the working directory to the project root
            task.currentDirectoryURL = URL(fileURLWithPath: "/Users/richardshaw/augment")
            
            // Set environment variables
            var environment = ProcessInfo.processInfo.environment
            environment["PYTHONPATH"] = "/Users/richardshaw/augment/src"
            task.environment = environment
            
            // Store the task reference for stopping
            self.currentTask = task
            
            do {
                try task.run()
                
                // Read output in real-time using notifications
                let outputHandle = outputPipe.fileHandleForReading
                let errorHandle = errorPipe.fileHandleForReading
                
                // Set up real-time output reading
                var accumulatedOutput = ""
                var accumulatedError = ""
                
                // Set up notification-based reading for real-time updates
                let outputSource = DispatchSource.makeReadSource(fileDescriptor: outputPipe.fileHandleForReading.fileDescriptor, queue: DispatchQueue.global(qos: .userInitiated))
                let errorSource = DispatchSource.makeReadSource(fileDescriptor: errorPipe.fileHandleForReading.fileDescriptor, queue: DispatchQueue.global(qos: .userInitiated))
                
                // Store source references for cleanup
                self.outputSource = outputSource
                self.errorSource = errorSource
                
                outputSource.setEventHandler {
                    let data = outputHandle.availableData
                    if !data.isEmpty {
                        if let chunk = String(data: data, encoding: .utf8) {
                            accumulatedOutput += chunk
                            // Print to console with timestamp
                            let timestamp = getCurrentTimestamp()
                            print("[\(timestamp)] GPT Output: \(chunk)", terminator: "")
                            DispatchQueue.main.async {
                                self.output = accumulatedOutput
                            }
                        }
                    }
                }
                
                errorSource.setEventHandler {
                    let errorData = errorHandle.availableData
                    if !errorData.isEmpty {
                        if let errorChunk = String(data: errorData, encoding: .utf8) {
                            accumulatedError += errorChunk
                            // Print errors to console with timestamp
                            let timestamp = getCurrentTimestamp()
                            print("[\(timestamp)] GPT Error: \(errorChunk)", terminator: "")
                            DispatchQueue.main.async {
                                self.errorOutput = accumulatedError
                            }
                        }
                    }
                }
                
                outputSource.setCancelHandler {
                    // Final read after process completes
                    let finalOutputData = outputHandle.readDataToEndOfFile()
                    if !finalOutputData.isEmpty {
                        if let finalChunk = String(data: finalOutputData, encoding: .utf8) {
                            accumulatedOutput += finalChunk
                        }
                    }
                    
                    DispatchQueue.main.async {
                        let timestamp = getCurrentTimestamp()
                        let statusMsg = task.terminationStatus == 0 ? "Completed Successfully" : "Completed with Errors"
                        print("[\(timestamp)] ✅ Task \(statusMsg.lowercased()) (exit code: \(task.terminationStatus))")
                        
                        self.output = accumulatedOutput
                        self.isRunning = false
                        self.status = statusMsg
                        self.currentTask = nil
                        self.outputSource = nil
                        self.errorSource = nil
                    }
                }
                
                errorSource.setCancelHandler {
                    let finalErrorData = errorHandle.readDataToEndOfFile()
                    if !finalErrorData.isEmpty {
                        if let finalErrorChunk = String(data: finalErrorData, encoding: .utf8) {
                            accumulatedError += finalErrorChunk
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.errorOutput = accumulatedError
                    }
                }
                
                outputSource.resume()
                errorSource.resume()
                
                task.waitUntilExit()
                
                // Cancel the dispatch sources when task completes
                outputSource.cancel()
                errorSource.cancel()
                
            } catch {
                DispatchQueue.main.async {
                    self.errorOutput = "Failed to launch Python script: \(error.localizedDescription)"
                    self.isRunning = false
                    self.status = "Error"
                    self.currentTask = nil
                    self.outputSource = nil
                    self.errorSource = nil
                }
            }
        }
    }
    
    func stopExecution() {
        guard isRunning else { return }
        
        // Cancel dispatch sources first
        outputSource?.cancel()
        errorSource?.cancel()
        
        // Terminate the process
        if let task = currentTask {
            if task.isRunning {
                task.terminate()
                // Force kill if terminate doesn't work within 2 seconds
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                    if task.isRunning {
                        task.interrupt()
                    }
                }
            }
        }
        
        // Update UI immediately
        DispatchQueue.main.async {
            let timestamp = getCurrentTimestamp()
            print("[\(timestamp)] ⏹️ Execution stopped by user")
            self.status = "Stopped by user"
            self.isRunning = false
            self.currentTask = nil
            self.outputSource = nil
            self.errorSource = nil
        }
    }
}

struct ContentView: View {
    @StateObject private var gptManager = GPTComputerUseManager()
    @State private var instruction = ""
    @State private var selectedTab = 0
    @State private var chatMessages: [ChatMessage] = []
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Panel - Controls
            VStack(spacing: 20) {
                // Header
                VStack {
                    Image(systemName: "brain.head.profile")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                        .font(.system(size: 40))
                    Text("GPT Computer Use")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(gptManager.status)
                        .font(.caption)
                        .foregroundColor(gptManager.isRunning ? .orange : 
                                       gptManager.status.contains("Error") ? .red : .green)
                }
                .padding()
                
                // Input Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter your instruction for GPT:")
                        .font(.headline)
                    
                    TextEditor(text: $instruction)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                    
                    HStack {
                        Button(action: {
                            gptManager.executeInstruction(instruction)
                        }) {
                            HStack {
                                Image(systemName: gptManager.isRunning ? "hourglass" : "play.circle")
                                Text(gptManager.isRunning ? "Running..." : "Execute")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(gptManager.isRunning ? Color.orange : Color.blue)
                            .cornerRadius(8)
                        }
                        .disabled(instruction.isEmpty || gptManager.isRunning)
                        
                        Spacer()
                    }
                }
                .padding()
                
                // Error section (if any)
                if !gptManager.errorOutput.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text("Errors")
                                .font(.headline)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        
                        ScrollView {
                            Text(gptManager.errorOutput)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .frame(maxHeight: 100)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .frame(minWidth: 350, maxWidth: 450)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            
            // Divider
            Divider()
            
            // Right Panel - Chat
            VStack(spacing: 0) {
                // Chat Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("GPT Assistant")
                            .font(.headline)
                        Text("Real-time computer automation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Emergency Stop Button
                    if gptManager.isRunning {
                        Button(action: {
                            gptManager.stopExecution()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.circle.fill")
                                Text("EMERGENCY STOP")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Button("Clear Chat") {
                        chatMessages.removeAll()
                    }
                    .font(.caption)
                    .disabled(chatMessages.isEmpty)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                // Chat Messages
                ChatView(messages: $chatMessages, content: gptManager.output)
            }
            .frame(minWidth: 400)
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                EmptyView()
            }
        }
        .onAppear {
            // Set some example instructions
            if instruction.isEmpty {
                instruction = "Open Safari and go to Apple website"
            }
        }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let type: MessageType
    
    enum MessageType {
        case text
        case tool
        case error
        case system
    }
}


struct ChatView: View {
    @Binding var messages: [ChatMessage]
    let content: String
    @State private var lastProcessedLength = 0
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty && content.isEmpty {
                        Text("Waiting for GPT to respond...")
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                    
                    ForEach(messages) { message in
                        ChatMessageView(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: content) { _, newValue in
                // Reset parsing state if content is empty (new task starting)
                if newValue.isEmpty {
                    lastProcessedLength = 0
                }
                
                parseAndUpdateMessages(newValue)
                
                // Auto-scroll to bottom when new content appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let lastMessage = messages.last {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: messages.count) { _, _ in
                // Also scroll when message count changes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let lastMessage = messages.last {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .cornerRadius(8)
    }
    
    private func parseAndUpdateMessages(_ rawContent: String) {
        // Only process new content since last update
        if rawContent.count <= lastProcessedLength {
            return
        }
        
        let newContent = String(rawContent.suffix(rawContent.count - lastProcessedLength))
        lastProcessedLength = rawContent.count
        
        // Debug: Write chat parsing debug info
        let debugLogPath = "/Users/richardshaw/augment/src/debug_output/chat_debug.txt"
        let timestamp = DateFormatter().string(from: Date())
        let debugContent = """
        
        [\(timestamp)] 🔍 DEBUG: Parsing new content (\(newContent.count) chars)
        📝 Content: \(String(newContent.prefix(200)))...
        📊 Total messages before: \(messages.count)
        
        """
        
        if let data = debugContent.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: debugLogPath) {
                if let fileHandle = FileHandle(forWritingAtPath: debugLogPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: debugLogPath))
            }
        }
        
        // Split content by lines for GPT format parsing
        let lines = newContent.components(separatedBy: .newlines)
        
        // Helper function to extract content after timestamp
        func extractContentAfterTimestamp(_ text: String) -> String {
            // Remove timestamp pattern [HH:MM:SS.mmm] from the beginning
            let timestampPattern = #"^\[\d{2}:\d{2}:\d{2}\.\d{3}\]\s*"#
            return text.replacingOccurrences(of: timestampPattern, with: "", options: .regularExpression)
        }
        
        // Process each line
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            // Extract content without timestamp for pattern matching
            let contentWithoutTimestamp = extractContentAfterTimestamp(trimmed)
            
            // Debug: Log line processing
            let lineDebug = """
            🔍 Processing line: '\(String(contentWithoutTimestamp.prefix(100)))'
            """
            if let data = lineDebug.data(using: .utf8) {
                if let fileHandle = FileHandle(forWritingAtPath: debugLogPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.write("\n".data(using: .utf8)!)
                    fileHandle.closeFile()
                }
            }
            
            // Skip if we've already processed this content
            if messages.contains(where: { $0.content.contains(String(contentWithoutTimestamp.prefix(30))) }) {
                let skipDebug = "⏭️ Skipping duplicate content\n"
                if let data = skipDebug.data(using: .utf8) {
                    if let fileHandle = FileHandle(forWritingAtPath: debugLogPath) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                }
                continue
            }
            
            // Parse GPT system output format
            if contentWithoutTimestamp.hasPrefix("🚀 Starting GPT Computer Use") || 
               contentWithoutTimestamp.hasPrefix("🤖 Computer Use initialized") {
                // System startup message
                let addDebug = "✅ Adding system startup message\n"
                if let data = addDebug.data(using: .utf8) {
                    if let fileHandle = FileHandle(forWritingAtPath: debugLogPath) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                }
                messages.append(ChatMessage(
                    content: "🚀 GPT Computer Use Started",
                    isUser: false,
                    timestamp: Date(),
                    type: .system
                ))
            } else if contentWithoutTimestamp.hasPrefix("📝 Task:") ||
                      contentWithoutTimestamp.hasPrefix("[TASK] Task:") {
                // Extract and show user task
                var task = contentWithoutTimestamp.replacingOccurrences(of: "📝 Task: ", with: "")
                task = task.replacingOccurrences(of: "[TASK] Task: ", with: "")
                let taskDebug = "✅ Adding user task: \(task)\n"
                if let data = taskDebug.data(using: .utf8) {
                    if let fileHandle = FileHandle(forWritingAtPath: debugLogPath) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                }
                messages.append(ChatMessage(
                    content: task,
                    isUser: true,
                    timestamp: Date(),
                    type: .text
                ))
            } else if contentWithoutTimestamp.hasPrefix("🔄 Iteration") {
                // Iteration counter
                messages.append(ChatMessage(
                    content: contentWithoutTimestamp,
                    isUser: false,
                    timestamp: Date(),
                    type: .system
                ))
            } else if contentWithoutTimestamp.hasPrefix("🤖 GPT Response:") {
                // GPT's reasoning response
                let response = contentWithoutTimestamp.replacingOccurrences(of: "🤖 GPT Response: ", with: "")
                
                // Try to extract reasoning from JSON response
                if let data = response.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    if let reasoning = jsonObject["reasoning"] as? String {
                        messages.append(ChatMessage(
                            content: "💭 " + reasoning,
                            isUser: false,
                            timestamp: Date(),
                            type: .text
                        ))
                    }
                    
                    if let action = jsonObject["action"] as? String {
                        let actionIcon = getActionIcon(action)
                        var actionText = "\(actionIcon) \(action)"
                        
                        // Add parameters if available
                        if let params = jsonObject["parameters"] as? [String: Any] {
                            let paramStrings = params.compactMap { key, value in
                                "\(key): \(value)"
                            }
                            if !paramStrings.isEmpty {
                                actionText += " (\(paramStrings.joined(separator: ", ")))"
                            }
                        }
                        
                        messages.append(ChatMessage(
                            content: actionText,
                            isUser: false,
                            timestamp: Date(),
                            type: .tool
                        ))
                    }
                } else {
                    // Fallback: show the raw response if not JSON
                    messages.append(ChatMessage(
                        content: "🤖 " + response,
                        isUser: false,
                        timestamp: Date(),
                        type: .text
                    ))
                }
            } else if contentWithoutTimestamp.hasPrefix("✅ Success:") {
                // Successful action result
                let result = contentWithoutTimestamp.replacingOccurrences(of: "✅ Success: ", with: "")
                messages.append(ChatMessage(
                    content: "✅ " + result,
                    isUser: false,
                    timestamp: Date(),
                    type: .tool
                ))
            } else if contentWithoutTimestamp.hasPrefix("❌ Error:") {
                // Error result
                let error = contentWithoutTimestamp.replacingOccurrences(of: "❌ Error: ", with: "")
                messages.append(ChatMessage(
                    content: "❌ " + error,
                    isUser: false,
                    timestamp: Date(),
                    type: .error
                ))
            } else if contentWithoutTimestamp.hasPrefix("🎉 Task") {
                // Task completion
                messages.append(ChatMessage(
                    content: contentWithoutTimestamp,
                    isUser: false,
                    timestamp: Date(),
                    type: .system
                ))
            } else if contentWithoutTimestamp.hasPrefix("📊 Task") {
                // Task summary or classification
                messages.append(ChatMessage(
                    content: contentWithoutTimestamp,
                    isUser: false,
                    timestamp: Date(),
                    type: .system
                ))
            } else if contentWithoutTimestamp.hasPrefix("[TASK] Task Classification:") {
                // New Smart LLM task classification
                let classification = contentWithoutTimestamp.replacingOccurrences(of: "[TASK] Task Classification: ", with: "")
                messages.append(ChatMessage(
                    content: "📊 Task Classification: " + classification,
                    isUser: false,
                    timestamp: Date(),
                    type: .system
                ))
            } else if contentWithoutTimestamp.hasPrefix("[TASK] Reasoning:") {
                // Task classification reasoning
                let reasoning = contentWithoutTimestamp.replacingOccurrences(of: "[TASK] Reasoning: ", with: "")
                messages.append(ChatMessage(
                    content: "💭 " + reasoning,
                    isUser: false,
                    timestamp: Date(),
                    type: .text
                ))
            } else if contentWithoutTimestamp.hasPrefix("[TASK] Routing to") {
                // Routing information
                let routing = contentWithoutTimestamp.replacingOccurrences(of: "[TASK] Routing to ", with: "")
                messages.append(ChatMessage(
                    content: "🔄 Routing to " + routing,
                    isUser: false,
                    timestamp: Date(),
                    type: .system
                ))
            } else if contentWithoutTimestamp.hasPrefix("🎯 Executing smart task:") {
                // Smart task execution
                let task = contentWithoutTimestamp.replacingOccurrences(of: "🎯 Executing smart task: ", with: "")
                messages.append(ChatMessage(
                    content: "🎯 " + task,
                    isUser: false,
                    timestamp: Date(),
                    type: .system
                ))
            } else if contentWithoutTimestamp.hasPrefix("🔀 Handling hybrid task:") {
                // Hybrid task handling
                messages.append(ChatMessage(
                    content: "🔀 Processing hybrid task...",
                    isUser: false,
                    timestamp: Date(),
                    type: .system
                ))
            } else if contentWithoutTimestamp.hasPrefix("📤 Submitted query") {
                // LLM query submission
                messages.append(ChatMessage(
                    content: "📤 Querying LLM for guidance...",
                    isUser: false,
                    timestamp: Date(),
                    type: .tool
                ))
            } else if contentWithoutTimestamp.hasPrefix("📥 LLM result received") {
                // LLM result received
                messages.append(ChatMessage(
                    content: "📥 LLM guidance received",
                    isUser: false,
                    timestamp: Date(),
                    type: .tool
                ))
            } else if contentWithoutTimestamp.hasPrefix("🌐 Navigating to") {
                // URL navigation
                let navigation = contentWithoutTimestamp.replacingOccurrences(of: "🌐 Navigating to ", with: "")
                messages.append(ChatMessage(
                    content: "🌐 " + navigation,
                    isUser: false,
                    timestamp: Date(),
                    type: .tool
                ))
            } else if contentWithoutTimestamp.hasPrefix("🌐 Smart navigating to:") {
                // Smart navigation
                let url = contentWithoutTimestamp.replacingOccurrences(of: "🌐 Smart navigating to: ", with: "")
                messages.append(ChatMessage(
                    content: "🌐 Opening: " + url,
                    isUser: false,
                    timestamp: Date(),
                    type: .tool
                ))
            } else if contentWithoutTimestamp.hasPrefix("🔄") && contentWithoutTimestamp.contains("recovery") {
                // Recovery attempts
                messages.append(ChatMessage(
                    content: contentWithoutTimestamp,
                    isUser: false,
                    timestamp: Date(),
                    type: .tool
                ))
            } else if contentWithoutTimestamp.hasPrefix("💰 Cost Mode:") {
                // Cost optimization info
                messages.append(ChatMessage(
                    content: "⚙️ " + contentWithoutTimestamp,
                    isUser: false,
                    timestamp: Date(),
                    type: .system
                ))
            }
        }
        
        // Debug: Final summary
        let summaryDebug = """
        📊 Total messages after: \(messages.count)
        ═══════════════════════════════════════
        
        """
        if let data = summaryDebug.data(using: .utf8) {
            if let fileHandle = FileHandle(forWritingAtPath: debugLogPath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        }
    }
    
    
    private func getActionIcon(_ action: String) -> String {
        if action.contains("screenshot") {
            return "📸"
        } else if action.contains("mouse_move") {
            return "🖱️"
        } else if action.contains("click") {
            return "👆"
        } else if action.contains("type") {
            return "⌨️"
        } else if action.contains("key") {
            return "🔘"
        } else if action.contains("scroll") {
            return "📜"
        } else {
            return "🔧"
        }
    }
    
    private func formatToolUse(name: String, input: [String: Any]) -> String {
        switch name {
        case "computer":
            if let action = input["action"] as? String {
                switch action {
                case "screenshot":
                    return "📸 Taking a screenshot..."
                case "left_click":
                    return "🖱️ Clicking..."
                case "right_click":
                    return "🖱️ Right-clicking..."
                case "mouse_move":
                    if let coord = input["coordinate"] as? [Int] {
                        return "🖱️ Moving mouse to (\(coord[0]), \(coord[1]))..."
                    }
                    return "🖱️ Moving mouse..."
                case "type":
                    if let text = input["text"] as? String {
                        return "⌨️ Typing: \"\(text)\""
                    }
                    return "⌨️ Typing..."
                case "key":
                    if let key = input["text"] as? String {
                        return "⌨️ Pressing \(key)"
                    }
                    return "⌨️ Pressing key..."
                default:
                    return "🖥️ Performing \(action)..."
                }
            }
            return "🖥️ Using computer..."
        case "bash":
            if let command = input["command"] as? String {
                return "💻 Running: \(command)"
            }
            return "💻 Running bash command..."
        default:
            return "🔧 Using \(name)..."
        }
    }
}

struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar/Icon
            Circle()
                .fill(message.isUser ? Color.blue : avatarColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(message.isUser ? "U" : icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // Header
                HStack {
                    Text(message.isUser ? "You" : "GPT")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Message content
                Text(message.content)
                    .font(message.type == .tool ? .system(.body, design: .monospaced) : .body)
                    .foregroundColor(textColor)
                    .padding(12)
                    .background(backgroundColor)
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer(minLength: 40) // Ensure messages don't extend to full width
        }
    }
    
    private var avatarColor: Color {
        switch message.type {
        case .text: return .green
        case .tool: return .orange
        case .error: return .red
        case .system: return .gray
        }
    }
    
    private var icon: String {
        switch message.type {
        case .text: return "🤖"
        case .tool: return "🔧"
        case .error: return "⚠️"
        case .system: return "ℹ️"
        }
    }
    
    private var backgroundColor: Color {
        switch message.type {
        case .text: return Color(NSColor.controlBackgroundColor)
        case .tool: return Color.orange.opacity(0.1)
        case .error: return Color.red.opacity(0.1)
        case .system: return Color.gray.opacity(0.1)
        }
    }
    
    private var textColor: Color {
        switch message.type {
        case .text: return .primary
        case .tool: return .orange
        case .error: return .red
        case .system: return .secondary
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
}

#Preview {
    ContentView()
}
