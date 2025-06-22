import Foundation
import Combine

// MARK: - Chat View Model
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    
    private var lastProcessedLength = 0
    private let logger: FileLogger
    private var cancellables = Set<AnyCancellable>()
    
    init(logger: FileLogger = .shared) {
        self.logger = logger
    }
    
    // MARK: - Public Methods
    func processGPTOutput(_ output: String) {
        // Reset if output is empty (new task starting)
        if output.isEmpty {
            lastProcessedLength = 0
            return
        }
        
        // Only process new content
        guard output.count > lastProcessedLength else { return }
        
        let newContent = String(output.suffix(output.count - lastProcessedLength))
        lastProcessedLength = output.count
        
        parseAndUpdateMessages(newContent)
    }
    
    func clearMessages() {
        messages.removeAll()
        lastProcessedLength = 0
    }
    
    func addUserMessage(_ content: String) {
        let message = ChatMessage.userMessage(content)
        messages.append(message)
    }
    
    func addSystemMessage(_ content: String) {
        let message = ChatMessage.systemMessage(content)
        messages.append(message)
    }
    
    func addErrorMessage(_ content: String) {
        let message = ChatMessage.errorMessage(content)
        messages.append(message)
    }
    
    // MARK: - Private Methods
    private func parseAndUpdateMessages(_ rawContent: String) {
        logDebugInfo(rawContent)
        
        let lines = rawContent.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let contentWithoutTimestamp = extractContentAfterTimestamp(trimmed)
            
            // Skip duplicates
            if isDuplicate(contentWithoutTimestamp) {
                continue
            }
            
            // Process GPT responses
            if contentWithoutTimestamp.hasPrefix("🤖 GPT Response:") {
                processGPTResponse(contentWithoutTimestamp)
            }
        }
    }
    
    private func extractContentAfterTimestamp(_ text: String) -> String {
        let timestampPattern = #"^\[\d{2}:\d{2}:\d{2}\.\d{3}\]\s*"#
        return text.replacingOccurrences(of: timestampPattern, with: "", options: .regularExpression)
    }
    
    private func isDuplicate(_ content: String) -> Bool {
        let preview = String(content.prefix(AppConstants.Debug.contentMatchLength))
        return messages.contains { $0.content.contains(preview) }
    }
    
    private func processGPTResponse(_ content: String) {
        let response = content.replacingOccurrences(of: "🤖 GPT Response: ", with: "")
        
        do {
            guard let data = response.data(using: .utf8),
                  let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let reasoning = jsonObject["reasoning"] as? String,
                  !reasoning.isEmpty else {
                
                addFallbackMessage()
                return
            }
            
            let message = ChatMessage.gptMessage(reasoning)
            messages.append(message)
            
        } catch {
            logger.logError("JSON parsing error: \(error.localizedDescription), JSON: \(response)")
            addFallbackMessage()
        }
    }
    
    private func addFallbackMessage() {
        let message = ChatMessage.gptMessage("Thinking...", type: .thinking)
        messages.append(message)
    }
    
    private func logDebugInfo(_ content: String) {
        let preview = String(content.prefix(AppConstants.Debug.contentPreviewLength))
        logger.logDebug("Parsing new content (\(content.count) chars): \(preview)...", to: .chatDebug)
        logger.logDebug("Total messages before: \(messages.count)", to: .chatDebug)
    }
}

// MARK: - Chat Parser
struct ChatParser {
    static func extractReasoningFromJSON(_ jsonString: String) -> String? {
        do {
            guard let data = jsonString.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let reasoning = json["reasoning"] as? String,
                  !reasoning.isEmpty else {
                return nil
            }
            return reasoning
        } catch {
            return nil
        }
    }
    
    static func isValidGPTResponse(_ line: String) -> Bool {
        let content = line.replacingOccurrences(
            of: #"^\[\d{2}:\d{2}:\d{2}\.\d{3}\]\s*"#,
            with: "",
            options: .regularExpression
        )
        return content.hasPrefix("🤖 GPT Response:")
    }
    
    static func extractToolAction(_ input: [String: Any]) -> String {
        guard let action = input["action"] as? String else {
            return "Performing action..."
        }
        
        switch action {
        case "screenshot":
            return "📸 Taking a screenshot..."
        case "left_click", "right_click":
            return "🖱️ Clicking..."
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
}