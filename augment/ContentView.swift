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

class ClaudeComputerUseManager: ObservableObject {
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
        // Get the project directory path - for development, use a fixed path
        let projectPath = "/Users/richardshaw/augment"
        self.pythonPath = "\(projectPath)/claude-computer-use-macos/venv/bin/python3"
        self.scriptPath = "\(projectPath)/claude-computer-use-macos/main.py"
    }
    
    func executeInstruction(_ instruction: String) {
        guard !isRunning else { return }
        
        isRunning = true
        status = "Executing..."
        output = ""
        errorOutput = ""
        
        // Print to console when starting
        let timestamp = getCurrentTimestamp()
        print("\n[\(timestamp)] 🚀 Starting Claude Computer Use")
        print("[\(timestamp)] 📝 Instruction: \(instruction)")
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
            task.arguments = [self.scriptPath, instruction]
            
            // Set the working directory to the claude-computer-use-macos folder
            task.currentDirectoryURL = URL(fileURLWithPath: "/Users/richardshaw/augment/claude-computer-use-macos")
            
            // Set environment variables
            var environment = ProcessInfo.processInfo.environment
            environment["PYTHONPATH"] = "/Users/richardshaw/augment/claude-computer-use-macos"
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
                            print("[\(timestamp)] Claude Output: \(chunk)", terminator: "")
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
                            print("[\(timestamp)] Claude Error: \(errorChunk)", terminator: "")
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
    @StateObject private var claudeManager = ClaudeComputerUseManager()
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
                    Text("Claude Computer Use")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(claudeManager.status)
                        .font(.caption)
                        .foregroundColor(claudeManager.isRunning ? .orange : 
                                       claudeManager.status.contains("Error") ? .red : .green)
                }
                .padding()
                
                // Input Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter your instruction for Claude:")
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
                            claudeManager.executeInstruction(instruction)
                        }) {
                            HStack {
                                Image(systemName: claudeManager.isRunning ? "hourglass" : "play.circle")
                                Text(claudeManager.isRunning ? "Running..." : "Execute")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(claudeManager.isRunning ? Color.orange : Color.blue)
                            .cornerRadius(8)
                        }
                        .disabled(instruction.isEmpty || claudeManager.isRunning)
                        
                        Spacer()
                    }
                }
                .padding()
                
                // Error section (if any)
                if !claudeManager.errorOutput.isEmpty {
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
                            Text(claudeManager.errorOutput)
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
                        Text("Claude Assistant")
                            .font(.headline)
                        Text("Real-time computer automation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Emergency Stop Button
                    if claudeManager.isRunning {
                        Button(action: {
                            claudeManager.stopExecution()
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
                ChatView(messages: $chatMessages, content: claudeManager.output)
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
                instruction = "Open Safari and search for 'Anthropic'"
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
                        Text("Waiting for Claude to respond...")
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
        
        // Parse new content sections
        let newSections = newContent.components(separatedBy: "---------------")
        
        // Helper function to extract content after timestamp
        func extractContentAfterTimestamp(_ text: String) -> String {
            // Remove timestamp pattern [HH:MM:SS.mmm] from the beginning
            let timestampPattern = #"^\[\d{2}:\d{2}:\d{2}\.\d{3}\]\s*"#
            return text.replacingOccurrences(of: timestampPattern, with: "", options: .regularExpression)
        }
        
        // Process only new sections
        for section in newSections {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            // Extract content without timestamp for pattern matching
            let contentWithoutTimestamp = extractContentAfterTimestamp(trimmed)
            
            // Skip if we've already processed this content
            if messages.contains(where: { $0.content.contains(String(contentWithoutTimestamp.prefix(50))) }) {
                continue
            }
            
            if contentWithoutTimestamp.hasPrefix("Starting Claude") {
                // System messages
                messages.append(ChatMessage(
                    content: contentWithoutTimestamp,
                    isUser: false,
                    timestamp: Date(),
                    type: .system
                ))
            } else if contentWithoutTimestamp.hasPrefix("Instructions provided:") {
                // User instruction echo
                let instruction = contentWithoutTimestamp.replacingOccurrences(of: "Instructions provided: ", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                messages.append(ChatMessage(
                    content: instruction,
                    isUser: true,
                    timestamp: Date(),
                    type: .text
                ))
            } else if contentWithoutTimestamp.hasPrefix("API Response:") {
                // Parse Claude's responses
                let responseContent = contentWithoutTimestamp.replacingOccurrences(of: "API Response:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                
                if let data = responseContent.data(using: .utf8),
                   let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    
                    for item in jsonArray {
                        if let type = item["type"] as? String {
                            if type == "text", let text = item["text"] as? String {
                                messages.append(ChatMessage(
                                    content: text,
                                    isUser: false,
                                    timestamp: Date(),
                                    type: .text
                                ))
                            } else if type == "tool_use", let name = item["name"] as? String {
                                if let input = item["input"] as? [String: Any] {
                                    let toolDescription = formatToolUse(name: name, input: input)
                                    messages.append(ChatMessage(
                                        content: toolDescription,
                                        isUser: false,
                                        timestamp: Date(),
                                        type: .tool
                                    ))
                                }
                            }
                        }
                    }
                }
            } else if contentWithoutTimestamp.hasPrefix("### Running bash command:") {
                // Bash command execution
                let command = contentWithoutTimestamp.replacingOccurrences(of: "### Running bash command: ", with: "")
                messages.append(ChatMessage(
                    content: "💻 Running: \(command)",
                    isUser: false,
                    timestamp: Date(),
                    type: .tool
                ))
            } else if contentWithoutTimestamp.hasPrefix("### Performing action:") {
                // Computer action execution
                let action = contentWithoutTimestamp.replacingOccurrences(of: "### Performing action: ", with: "")
                let actionIcon = getActionIcon(action)
                messages.append(ChatMessage(
                    content: "\(actionIcon) \(action)",
                    isUser: false,
                    timestamp: Date(),
                    type: .tool
                ))
            } else if contentWithoutTimestamp.hasPrefix("> Tool Output") {
                // Tool output results
                messages.append(ChatMessage(
                    content: "✅ " + contentWithoutTimestamp,
                    isUser: false,
                    timestamp: Date(),
                    type: .tool
                ))
            } else if contentWithoutTimestamp.hasPrefix("!!! Tool Error") {
                // Tool errors
                messages.append(ChatMessage(
                    content: "❌ " + contentWithoutTimestamp,
                    isUser: false,
                    timestamp: Date(),
                    type: .error
                ))
            } else if contentWithoutTimestamp.hasPrefix("Took screenshot") {
                // Screenshot notifications
                messages.append(ChatMessage(
                    content: "📸 " + contentWithoutTimestamp,
                    isUser: false,
                    timestamp: Date(),
                    type: .tool
                ))
            } else if contentWithoutTimestamp.hasPrefix("Assistant:") {
                // Direct assistant messages
                let assistantText = contentWithoutTimestamp.replacingOccurrences(of: "Assistant: ", with: "")
                messages.append(ChatMessage(
                    content: assistantText,
                    isUser: false,
                    timestamp: Date(),
                    type: .text
                ))
            } else if contentWithoutTimestamp.hasPrefix("Cost optimization:") {
                // Cost optimization info
                messages.append(ChatMessage(
                    content: "⚙️ " + contentWithoutTimestamp,
                    isUser: false,
                    timestamp: Date(),
                    type: .system
                ))
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
                    Text(message.isUser ? "You" : "Claude")
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
